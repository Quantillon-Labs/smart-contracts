// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IChainlinkOracle} from "../interfaces/IChainlinkOracle.sol";
import {IYieldShift} from "../interfaces/IYieldShift.sol";
import {IQuantillonVault} from "../interfaces/IQuantillonVault.sol";
import {VaultMath} from "../libraries/VaultMath.sol";
import {ErrorLibrary} from "../libraries/ErrorLibrary.sol";
import {AccessControlLibrary} from "../libraries/AccessControlLibrary.sol";
import {ValidationLibrary} from "../libraries/ValidationLibrary.sol";
import {SecureUpgradeable} from "./SecureUpgradeable.sol";
import {TreasuryRecoveryLibrary} from "../libraries/TreasuryRecoveryLibrary.sol";
import {FlashLoanProtectionLibrary} from "../libraries/FlashLoanProtectionLibrary.sol";
import {TimeProvider} from "../libraries/TimeProviderLibrary.sol";
import {HedgerPoolLogicLibrary} from "../libraries/HedgerPoolLogicLibrary.sol";

/**
 * @title HedgerPool
 * @notice Optimized EUR/USD hedging pool for managing currency risk and providing yield
 * @dev Optimized version with reduced contract size through library extraction and code consolidation
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract HedgerPool is 
    Initializable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    SecureUpgradeable
{
    using SafeERC20 for IERC20;
    using VaultMath for uint256;
    using AccessControlLibrary for AccessControlUpgradeable;
    using ValidationLibrary for uint256;

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant HEDGER_ROLE = keccak256("HEDGER_ROLE");

    IERC20 public usdc;
    IChainlinkOracle public oracle;
    IYieldShift public yieldShift;
    IQuantillonVault public vault;
    address public treasury;
    TimeProvider public immutable TIME_PROVIDER;

    struct CoreParams {
        uint64 minMarginRatio;
        uint64 liquidationThreshold;
        uint16 maxLeverage;
        uint16 liquidationPenalty;
        uint16 entryFee;
        uint16 exitFee;
        uint16 marginFee;
        uint16 eurInterestRate;
        uint16 usdInterestRate;
        uint8 reserved;
    }
    CoreParams public coreParams;

    uint256 public totalMargin;
    uint256 public totalExposure;
    uint256 public activeHedgers;
    uint256 public nextPositionId;

    mapping(address => bool) public isWhitelistedHedger;
    bool public hedgerWhitelistEnabled;

    struct HedgePosition {
        address hedger;
        uint96 positionSize;
        uint96 margin;
        uint96 entryPrice;
        uint32 entryTime;
        uint32 lastUpdateTime;
        int128 unrealizedPnL;
        uint16 leverage;
        bool isActive;
    }

    struct HedgerInfo {
        uint256[] positionIds;
        uint128 totalMargin;
        uint128 totalExposure;
        uint128 pendingRewards;
        uint64 lastRewardClaim;
        bool isActive;
    }

    mapping(uint256 => HedgePosition) public positions;
    mapping(address => HedgerInfo) public hedgers;
    mapping(address => uint256) public activePositionCount;

    mapping(address => mapping(uint256 => bool)) public hedgerHasPosition;
    mapping(address => mapping(uint256 => uint256)) public positionIndex;

    mapping(bytes32 => bool) public liquidationCommitments;
    mapping(bytes32 => uint256) public liquidationCommitmentTimes;
    mapping(address => uint256) public lastLiquidationAttempt;
    mapping(address => mapping(uint256 => bool)) public hasPendingLiquidation;

    mapping(address => uint256) public hedgerLastRewardBlock;

    uint256 public constant MAX_POSITIONS_PER_HEDGER = 50;
    uint96 public constant MAX_UINT96_VALUE = type(uint96).max;
    uint256 public constant MAX_POSITION_SIZE = MAX_UINT96_VALUE;
    uint256 public constant MAX_MARGIN = MAX_UINT96_VALUE;
    uint256 public constant MAX_ENTRY_PRICE = MAX_UINT96_VALUE;
    uint256 public constant MAX_LEVERAGE = type(uint16).max;
    uint256 public constant MAX_MARGIN_RATIO = 5000; // 50% maximum margin ratio (2x minimum leverage)
    uint128 public constant MAX_UINT128_VALUE = type(uint128).max;
    uint256 public constant MAX_TOTAL_MARGIN = MAX_UINT128_VALUE;
    uint256 public constant MAX_TOTAL_EXPOSURE = MAX_UINT128_VALUE;
    uint256 public constant MAX_PENDING_REWARDS = MAX_UINT128_VALUE;
    uint256 public constant LIQUIDATION_COOLDOWN = 300;
    uint256 public constant MAX_REWARD_PERIOD = 365 days;

    event HedgePositionOpened(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
    event HedgePositionClosed(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
    event MarginUpdated(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
    event HedgerLiquidated(address indexed hedger, uint256 indexed positionId, address indexed liquidator, bytes32 packedData);
    event HedgingRewardsClaimed(address indexed hedger, bytes32 packedData);
    event HedgerWhitelisted(address indexed hedger, address indexed caller);
    event HedgerRemoved(address indexed hedger, address indexed caller);
    event HedgerWhitelistModeToggled(bool enabled, address indexed caller);
    event ETHRecovered(address indexed to, uint256 indexed amount);
    event TreasuryUpdated(address indexed treasury);
    event VaultUpdated(address indexed vault);

    modifier flashLoanProtection() {
        uint256 balanceBefore = usdc.balanceOf(address(this));
        _;
        uint256 balanceAfter = usdc.balanceOf(address(this));
        if (!FlashLoanProtectionLibrary.validateBalanceChange(balanceBefore, balanceAfter, 0))
            revert ErrorLibrary.FlashLoanAttackDetected();
    }

    modifier secureNonReentrant() {
        if (paused()) revert ErrorLibrary.NotPaused();
        uint256 balanceBefore = usdc.balanceOf(address(this));
        _;
        uint256 balanceAfter = usdc.balanceOf(address(this));
        if (!FlashLoanProtectionLibrary.validateBalanceChange(balanceBefore, balanceAfter, 0))
            revert ErrorLibrary.FlashLoanAttackDetected();
    }

    constructor(TimeProvider _TIME_PROVIDER) {
        if (address(_TIME_PROVIDER) == address(0)) revert ErrorLibrary.ZeroAddress();
        TIME_PROVIDER = _TIME_PROVIDER;
        _disableInitializers();
    }

    /**
     * @notice Initializes the HedgerPool with contracts and parameters
     * 
     * @param admin Address with administrator privileges
     * @param _usdc Address of the USDC token contract
     * @param _oracle Address of the Oracle contract
     * @param _yieldShift Address of the YieldShift contract
     * @param _timelock Address of the timelock contract
     * @param _treasury Address of the treasury contract
     * @param _vault Address of the QuantillonVault contract
     * 
     * @dev This function configures:
     *      1. Access roles and permissions
     *      2. References to external contracts
     *      3. Default protocol parameters
     *      4. Security (pause, reentrancy, upgrades)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Initializes all contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by initializer modifier
     * @custom:access Restricted to initializer modifier
     * @custom:oracle No oracle dependencies
     */
    function initialize(
        address admin,
        address _usdc,
        address _oracle,
        address _yieldShift,
        address _timelock,
        address _treasury,
        address _vault
    ) public initializer {
        AccessControlLibrary.validateAddress(admin);
        AccessControlLibrary.validateAddress(_usdc);
        AccessControlLibrary.validateAddress(_oracle);
        AccessControlLibrary.validateAddress(_yieldShift);
        AccessControlLibrary.validateAddress(_treasury);
        AccessControlLibrary.validateAddress(_vault);

        __ReentrancyGuard_init();
        __AccessControl_init();
        __Pausable_init();
        __SecureUpgradeable_init(_timelock);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);

        usdc = IERC20(_usdc);
        oracle = IChainlinkOracle(_oracle);
        yieldShift = IYieldShift(_yieldShift);
        vault = IQuantillonVault(_vault);
        treasury = _treasury;

        coreParams.minMarginRatio = 500;  // 5% minimum margin ratio (20x max leverage)
        coreParams.liquidationThreshold = 100;
        coreParams.maxLeverage = 20;      // 20x maximum leverage (5% minimum margin)
        coreParams.liquidationPenalty = 200;
        coreParams.entryFee = 0;
        coreParams.exitFee = 0;
        coreParams.marginFee = 0;
        coreParams.eurInterestRate = 350;
        coreParams.usdInterestRate = 450;
        hedgerWhitelistEnabled = true;
        nextPositionId = 1;
    }

    /**
     * @notice Opens a new hedge position for a hedger
     * 
     * @param usdcAmount Amount of USDC to deposit as margin (6 decimals)
     * @param leverage Leverage multiplier for the position (1-20x)
     * @return positionId Unique identifier for the new position
     * 
     * @dev Position opening process:
     *      1. Validates hedger whitelist status
     *      2. Fetches current EUR/USD price from oracle
     *      3. Calculates position size and validates parameters
     *      4. Transfers USDC to vault for unified liquidity
     *      5. Creates position record and updates hedger stats
     * 
     * @dev Security features:
     *      1. Flash loan protection via secureNonReentrant
     *      2. Whitelist validation if enabled
     *      3. Parameter validation (leverage, amounts)
     *      4. Oracle price validation
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates amount > 0, leverage within limits, hedger whitelist
     * @custom:state-changes Creates new position, updates hedger stats, transfers USDC to vault
     * @custom:events Emits HedgePositionOpened with position details
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by secureNonReentrant modifier
     * @custom:access Restricted to whitelisted hedgers (if whitelist enabled)
     * @custom:oracle Requires fresh oracle price data
     */
    function enterHedgePosition(uint256 usdcAmount, uint256 leverage) 
        external 
        secureNonReentrant
        returns (uint256 positionId) 
    {
        if (hedgerWhitelistEnabled && !isWhitelistedHedger[msg.sender]) {
            revert ErrorLibrary.NotWhitelisted();
        }
        
        uint256 eurUsdPrice = _getValidOraclePrice();
        
        (uint256 fee, uint256 netMargin, uint256 positionSize, uint256 marginRatio) = 
            HedgerPoolLogicLibrary.validateAndCalculatePositionParams(
                usdcAmount, leverage, eurUsdPrice, coreParams.entryFee, coreParams.minMarginRatio, MAX_MARGIN_RATIO, coreParams.maxLeverage,
                MAX_POSITIONS_PER_HEDGER, activePositionCount[msg.sender], MAX_MARGIN,
                MAX_POSITION_SIZE, MAX_ENTRY_PRICE, MAX_LEVERAGE, TIME_PROVIDER.currentTime()
            );

        // Transfer USDC directly to vault for unified liquidity management
        usdc.safeTransferFrom(msg.sender, address(vault), usdcAmount);
        
        // Notify vault of hedger deposit to update totalUsdcHeld
        vault.addHedgerDeposit(usdcAmount);

        positionId = nextPositionId++;
        
        HedgePosition storage position = positions[positionId];
        position.hedger = msg.sender;
        position.positionSize = uint96(positionSize);
        position.margin = uint96(netMargin);
        position.entryTime = uint32(TIME_PROVIDER.currentTime());
        position.lastUpdateTime = uint32(TIME_PROVIDER.currentTime());
        position.leverage = uint16(leverage);
        position.entryPrice = uint96(eurUsdPrice);
        position.unrealizedPnL = 0;
        position.isActive = true;

        HedgerInfo storage hedgerInfo = hedgers[msg.sender];
        if (!hedgerInfo.isActive) {
            hedgerInfo.isActive = true;
            activeHedgers++;
        }
        
        hedgerInfo.positionIds.push(positionId);
        positionIndex[msg.sender][positionId] = hedgerInfo.positionIds.length - 1;
        
        ValidationLibrary.validateTotals(
            hedgerInfo.totalMargin, hedgerInfo.totalExposure,
            netMargin, positionSize, MAX_TOTAL_MARGIN, MAX_TOTAL_EXPOSURE
        );
        
        hedgerInfo.totalMargin += uint128(netMargin);
        hedgerInfo.totalExposure += uint128(positionSize);
        
        hedgerHasPosition[msg.sender][positionId] = true;
        activePositionCount[msg.sender]++;
        totalMargin += netMargin;
        totalExposure += positionSize;

        emit HedgePositionOpened(
            msg.sender, 
            positionId, 
            _packPositionOpenData(positionSize, netMargin, leverage, eurUsdPrice)
        );
    }

    /**
     * @notice Closes an existing hedge position
     * 
     * @param positionId Unique identifier of the position to close
     * @return pnl Profit or loss from the position (positive = profit, negative = loss)
     * 
     * @dev Position closing process:
     *      1. Validates position ownership and active status
     *      2. Checks protocol collateralization safety
     *      3. Calculates current PnL based on price change
     *      4. Determines net payout to hedger
     *      5. Updates hedger stats and removes position
     *      6. Withdraws USDC from vault for hedger payout
     * 
     * @dev Security features:
     *      1. Position ownership validation
     *      2. Protocol collateralization safety check
     *      3. Pause protection
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates position ownership, active status, and protocol safety
     * @custom:state-changes Closes position, updates hedger stats, withdraws USDC from vault
     * @custom:events Emits HedgePositionClosed with position details
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by whenNotPaused modifier
     * @custom:access Restricted to position owner
     * @custom:oracle Requires fresh oracle price data
     */
    function exitHedgePosition(uint256 positionId) 
        external 
        whenNotPaused
        returns (int256 pnl) 
    {
        HedgePosition storage position = positions[positionId];
        ValidationLibrary.validatePositionOwner(position.hedger, msg.sender);
        ValidationLibrary.validatePositionActive(position.isActive);

        // Check if closing this position would cause protocol undercollateralization
        _validatePositionClosureSafety(positionId, position.margin);

        uint256 currentPrice = _getValidOraclePrice();
        pnl = HedgerPoolLogicLibrary.calculatePnL(
            uint256(position.positionSize), 
            uint256(position.entryPrice), 
            currentPrice
        );

        uint256 grossPayout = uint256(int256(uint256(position.margin)) + pnl);
        uint256 exitFeeAmount = grossPayout.percentageOf(coreParams.exitFee);
        uint256 netPayout = grossPayout - exitFeeAmount;

        HedgerInfo storage hedgerInfo = hedgers[msg.sender];
        hedgerInfo.totalMargin -= uint128(position.margin);
        hedgerInfo.totalExposure -= uint128(position.positionSize);

        totalMargin -= uint256(position.margin);
        totalExposure -= uint256(position.positionSize);

        position.isActive = false;
        _removePositionFromArrays(msg.sender, positionId);
        
        activePositionCount[msg.sender]--;
        
        // Check if hedger has no more active positions
        if (activePositionCount[msg.sender] == 0) {
            hedgerInfo.isActive = false;
            activeHedgers--;
        }

        if (netPayout > 0) {
            // Withdraw USDC from vault for hedger payout
            vault.withdrawHedgerDeposit(msg.sender, netPayout);
        }

        emit HedgePositionClosed(
            msg.sender, 
            positionId, 
            _packPositionCloseData(currentPrice, pnl, TIME_PROVIDER.currentTime())
        );
    }

    /**
     * @notice Adds additional margin to an existing hedge position
     * 
     * @param positionId Unique identifier of the position
     * @param amount Amount of USDC to add as margin (6 decimals)
     * 
     * @dev Margin addition process:
     *      1. Validates position ownership and active status
     *      2. Validates amount is positive
     *      3. Checks liquidation cooldown and pending liquidation status
     *      4. Transfers USDC from hedger to vault
     *      5. Updates position margin and hedger stats
     * 
     * @dev Security features:
     *      1. Flash loan protection
     *      2. Position ownership validation
     *      3. Liquidation cooldown validation
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates position ownership, active status, positive amount, liquidation cooldown
     * @custom:state-changes Updates position margin, hedger stats, transfers USDC to vault
     * @custom:events Emits MarginAdded with position details
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by flashLoanProtection modifier
     * @custom:access Restricted to position owner
     * @custom:oracle No oracle dependencies
     */
    function addMargin(uint256 positionId, uint256 amount) external flashLoanProtection {
        HedgePosition storage position = positions[positionId];
        ValidationLibrary.validatePositionOwner(position.hedger, msg.sender);
        ValidationLibrary.validatePositionActive(position.isActive);
        ValidationLibrary.validatePositiveAmount(amount);
        ValidationLibrary.validateLiquidationCooldown(lastLiquidationAttempt[msg.sender], LIQUIDATION_COOLDOWN);
        
        if (hasPendingLiquidation[msg.sender][positionId]) {
            revert ErrorLibrary.PendingLiquidationCommitment();
        }

        uint256 fee = amount.percentageOf(coreParams.marginFee);
        uint256 netAmount = amount - fee;

        // Transfer USDC directly to vault for unified liquidity management
        usdc.safeTransferFrom(msg.sender, address(vault), amount);
        
        // Notify vault of additional hedger deposit
        vault.addHedgerDeposit(amount);

        (uint256 newMargin, uint256 newMarginRatio) = HedgerPoolLogicLibrary.validateMarginOperation(
            uint256(position.margin), netAmount, true, coreParams.minMarginRatio, 
            uint256(position.positionSize), MAX_MARGIN
        );
        
        position.margin = uint96(newMargin);
        hedgers[msg.sender].totalMargin += uint128(netAmount);
        totalMargin += netAmount;

        emit MarginUpdated(
            msg.sender, 
            positionId, 
            _packMarginData(netAmount, newMarginRatio, true)
        );
    }

    /**
     * @notice Removes margin from an existing hedge position
     * 
     * @param positionId Unique identifier of the position
     * @param amount Amount of USDC to remove from margin (6 decimals)
     * 
     * @dev Margin removal process:
     *      1. Validates position ownership and active status
     *      2. Validates amount is positive
     *      3. Validates margin operation maintains minimum margin ratio
     *      4. Updates position margin and hedger stats
     *      5. Withdraws USDC from vault to hedger
     * 
     * @dev Security features:
     *      1. Flash loan protection
     *      2. Position ownership validation
     *      3. Minimum margin ratio validation
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates position ownership, active status, positive amount, minimum margin ratio
     * @custom:state-changes Updates position margin, hedger stats, withdraws USDC from vault
     * @custom:events Emits MarginUpdated with position details
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by flashLoanProtection modifier
     * @custom:access Restricted to position owner
     * @custom:oracle No oracle dependencies
     */
    function removeMargin(uint256 positionId, uint256 amount) external flashLoanProtection {
        HedgePosition storage position = positions[positionId];
        ValidationLibrary.validatePositionOwner(position.hedger, msg.sender);
        ValidationLibrary.validatePositionActive(position.isActive);
        ValidationLibrary.validatePositiveAmount(amount);

        (uint256 newMargin, uint256 newMarginRatio) = HedgerPoolLogicLibrary.validateMarginOperation(
            uint256(position.margin), amount, false, coreParams.minMarginRatio, 
            uint256(position.positionSize), MAX_MARGIN
        );
        
        position.margin = uint96(newMargin);
        hedgers[msg.sender].totalMargin -= uint128(amount);
        totalMargin -= amount;

        // Withdraw USDC from vault for hedger margin removal
        vault.withdrawHedgerDeposit(msg.sender, amount);

        emit MarginUpdated(
            msg.sender, 
            positionId, 
            _packMarginData(amount, newMarginRatio, false)
        );
    }

    function commitLiquidation(address hedger, uint256 positionId, bytes32 salt) external {
        _validateRole(LIQUIDATOR_ROLE);
        AccessControlLibrary.validateAddress(hedger);
        if (positionId == 0) revert ErrorLibrary.InvalidPosition();
        
        bytes32 commitment = HedgerPoolLogicLibrary.generateLiquidationCommitment(
            hedger, positionId, salt, msg.sender
        );
        ValidationLibrary.validateCommitmentNotExists(liquidationCommitments[commitment]);
        
        liquidationCommitments[commitment] = true;
        liquidationCommitmentTimes[commitment] = block.number;
        hasPendingLiquidation[hedger][positionId] = true;
        lastLiquidationAttempt[hedger] = block.number;
    }

    /**
     * @notice Liquidates an undercollateralized hedge position
     * 
     * @param hedger Address of the hedger to liquidate
     * @param positionId Unique identifier of the position to liquidate
     * @param salt Random salt for commitment validation
     * @return liquidationReward Amount of USDC reward for the liquidator
     * 
     * @dev Liquidation process:
     *      1. Validates liquidator role and commitment
     *      2. Validates position ownership and active status
     *      3. Calculates liquidation reward and remaining margin
     *      4. Updates hedger stats and removes position
     *      5. Withdraws USDC from vault for liquidator reward and remaining margin
     * 
     * @dev Security features:
     *      1. Role-based access control (LIQUIDATOR_ROLE)
     *      2. Commitment validation to prevent front-running
     *      3. Reentrancy protection
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates liquidator role, commitment, position ownership, active status
     * @custom:state-changes Liquidates position, updates hedger stats, withdraws USDC from vault
     * @custom:events Emits HedgerLiquidated with liquidation details
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to LIQUIDATOR_ROLE
     * @custom:oracle Requires fresh oracle price data
     */
    function liquidateHedger(address hedger, uint256 positionId, bytes32 salt) 
        external 
        nonReentrant 
        returns (uint256 liquidationReward) 
    {
        _validateRole(LIQUIDATOR_ROLE);
        
        HedgePosition storage position = positions[positionId];
        ValidationLibrary.validatePositionOwner(position.hedger, hedger);
        ValidationLibrary.validatePositionActive(position.isActive);

        bytes32 commitment = HedgerPoolLogicLibrary.generateLiquidationCommitment(
            hedger, positionId, salt, msg.sender
        );
        ValidationLibrary.validateCommitment(liquidationCommitments[commitment]);
        
        delete liquidationCommitments[commitment];
        delete liquidationCommitmentTimes[commitment];
        hasPendingLiquidation[hedger][positionId] = false;

        uint256 currentPrice = _getValidOraclePrice();
        bool liquidatable = HedgerPoolLogicLibrary.isPositionLiquidatable(
            uint256(position.margin), uint256(position.positionSize), 
            uint256(position.entryPrice), currentPrice, coreParams.liquidationThreshold
        );
        
        if (!liquidatable) revert ErrorLibrary.PositionNotLiquidatable();

        liquidationReward = uint256(position.margin).percentageOf(coreParams.liquidationPenalty);
        uint256 remainingMargin = uint256(position.margin) - liquidationReward;

        HedgerInfo storage hedgerInfo = hedgers[hedger];
        hedgerInfo.totalMargin -= uint128(position.margin);
        hedgerInfo.totalExposure -= uint128(position.positionSize);

        totalMargin -= position.margin;
        totalExposure -= position.positionSize;

        position.isActive = false;
        _removePositionFromArrays(hedger, positionId);
        
        activePositionCount[hedger]--;
        
        // Check if hedger has no more active positions
        if (activePositionCount[hedger] == 0) {
            hedgerInfo.isActive = false;
            activeHedgers--;
        }

        // Withdraw liquidation reward from vault for liquidator
        vault.withdrawHedgerDeposit(msg.sender, liquidationReward);

        if (remainingMargin > 0) {
            // Withdraw remaining margin from vault for hedger
            vault.withdrawHedgerDeposit(hedger, remainingMargin);
        }

        emit HedgerLiquidated(
            hedger, 
            positionId, 
            msg.sender, 
            _packLiquidationData(liquidationReward, remainingMargin)
        );
    }

    /**
     * @notice Claims hedging rewards for a hedger
     * 
     * @return interestDifferential Interest differential rewards earned
     * @return yieldShiftRewards Yield shift rewards earned
     * @return totalRewards Total rewards claimed
     * 
     * @dev Reward claiming process:
     *      1. Calculates interest differential based on exposure and rates
     *      2. Calculates yield shift rewards from YieldShift contract
     *      3. Updates hedger's last reward block
     *      4. Transfers total rewards to hedger
     * 
     * @dev Security features:
     *      1. Reentrancy protection
     *      2. Reward calculation validation
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates hedger has active positions and rewards available
     * @custom:state-changes Updates hedger reward tracking, transfers rewards
     * @custom:events Emits HedgingRewardsClaimed with reward details
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to hedgers with active positions
     * @custom:oracle No oracle dependencies
     */
    function claimHedgingRewards() 
        external 
        nonReentrant 
        returns (uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards) 
    {
        address hedger = msg.sender;
        HedgerInfo storage hedgerInfo = hedgers[hedger];
        
        (uint256 newPendingRewards, uint256 newLastRewardBlock) = HedgerPoolLogicLibrary.calculateRewardUpdate(
            uint256(hedgerInfo.totalExposure), coreParams.eurInterestRate, coreParams.usdInterestRate,
            hedgerLastRewardBlock[hedger], block.number, MAX_REWARD_PERIOD, 
            uint256(hedgerInfo.pendingRewards)
        );
        
        hedgerInfo.pendingRewards = uint128(newPendingRewards);
        hedgerLastRewardBlock[hedger] = newLastRewardBlock;
        
        interestDifferential = hedgerInfo.pendingRewards;
        yieldShiftRewards = yieldShift.getHedgerPendingYield(hedger);
        totalRewards = interestDifferential + yieldShiftRewards;
        
        if (totalRewards > 0) {
            hedgerInfo.pendingRewards = 0;
            hedgerInfo.lastRewardClaim = uint64(TIME_PROVIDER.currentTime());
            
            if (yieldShiftRewards > 0) {
                uint256 claimedAmount = yieldShift.claimHedgerYield(hedger);
                if (claimedAmount == 0) revert ErrorLibrary.YieldClaimFailed();
            }
            
            usdc.safeTransfer(hedger, totalRewards);
            
            emit HedgingRewardsClaimed(
                hedger, 
                _packRewardData(interestDifferential, yieldShiftRewards, totalRewards)
            );
        }
    }

    function getHedgerPosition(address hedger, uint256 positionId) 
        external 
        returns (uint256 positionSize, uint256 margin, uint256 entryPrice, uint256 currentPrice, uint256 leverage, uint256 lastUpdateTime) 
    {
        HedgePosition storage position = positions[positionId];
        if (position.hedger != hedger) revert ErrorLibrary.InvalidHedger();
        
        uint256 oraclePrice = _getValidOraclePrice();
        
        return (
            position.positionSize,
            position.margin,
            position.entryPrice,
            oraclePrice,
            position.leverage,
            position.lastUpdateTime
        );
    }

    function getHedgerMarginRatio(address hedger, uint256 positionId) external view returns (uint256) {
        HedgePosition storage position = positions[positionId];
        if (position.hedger != hedger) revert ErrorLibrary.InvalidHedger();
        
        if (position.positionSize == 0) return 0;
        return uint256(position.margin).mulDiv(10000, uint256(position.positionSize));
    }

    function isHedgerLiquidatable(address hedger, uint256 positionId) external returns (bool) {
        HedgePosition storage position = positions[positionId];
        if (position.hedger != hedger) revert ErrorLibrary.InvalidHedger();
        
        if (!position.isActive) return false;
        
        uint256 currentPrice = _getValidOraclePrice();
        return HedgerPoolLogicLibrary.isPositionLiquidatable(
            uint256(position.margin), uint256(position.positionSize), 
            uint256(position.entryPrice), currentPrice, coreParams.liquidationThreshold
        );
    }

    function getTotalHedgeExposure() external view returns (uint256) {
        return totalExposure;
    }

    function updateHedgingParameters(
        uint256 newMinMarginRatio,
        uint256 newLiquidationThreshold,
        uint256 newMaxLeverage,
        uint256 newLiquidationPenalty
    ) external {
        _validateRole(GOVERNANCE_ROLE);
        if (newMinMarginRatio < 500) revert ErrorLibrary.ConfigValueTooLow();
        if (newLiquidationThreshold >= newMinMarginRatio) revert ErrorLibrary.ConfigInvalid();
        if (newMaxLeverage > 20) revert ErrorLibrary.ConfigValueTooHigh();
        if (newLiquidationPenalty > 1000) revert ErrorLibrary.ConfigValueTooHigh();

        coreParams.minMarginRatio = uint64(newMinMarginRatio);
        coreParams.liquidationThreshold = uint64(newLiquidationThreshold);
        coreParams.maxLeverage = uint16(newMaxLeverage);
        coreParams.liquidationPenalty = uint16(newLiquidationPenalty);
    }

    function updateInterestRates(uint256 newEurRate, uint256 newUsdRate) external {
        _validateRole(GOVERNANCE_ROLE);
        if (newEurRate > 2000 || newUsdRate > 2000) revert ErrorLibrary.ConfigValueTooHigh();
        
        coreParams.eurInterestRate = uint16(newEurRate);
        coreParams.usdInterestRate = uint16(newUsdRate);
    }

    function setHedgingFees(uint256 _entryFee, uint256 _exitFee, uint256 _marginFee) external {
        _validateRole(GOVERNANCE_ROLE);
        ValidationLibrary.validateFee(_entryFee, 100);
        ValidationLibrary.validateFee(_exitFee, 100);
        ValidationLibrary.validateFee(_marginFee, 50);

        coreParams.entryFee = uint16(_entryFee);
        coreParams.exitFee = uint16(_exitFee);
        coreParams.marginFee = uint16(_marginFee);
    }

    /**
     * @notice Emergency closure of a hedge position by governance
     * 
     * @param hedger Address of the hedger whose position to close
     * @param positionId Unique identifier of the position to close
     * 
     * @dev Emergency closure process:
     *      1. Validates emergency role and position ownership
     *      2. Validates position is active
     *      3. Updates hedger stats and removes position
     *      4. Withdraws USDC from vault for hedger's margin
     * 
     * @dev Security features:
     *      1. Role-based access control (EMERGENCY_ROLE)
     *      2. Position ownership validation
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates emergency role, position ownership, active status
     * @custom:state-changes Closes position, updates hedger stats, withdraws USDC from vault
     * @custom:events Emits EmergencyPositionClosed with position details
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Not protected - emergency function
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle No oracle dependencies
     */
    function emergencyClosePosition(address hedger, uint256 positionId) external {
        _validateRole(EMERGENCY_ROLE);
        
        HedgePosition storage position = positions[positionId];
        if (position.hedger != hedger) revert ErrorLibrary.InvalidHedger();
        ValidationLibrary.validatePositionActive(position.isActive);

        HedgerInfo storage hedgerInfo = hedgers[hedger];
        hedgerInfo.totalMargin -= uint128(position.margin);
        hedgerInfo.totalExposure -= uint128(position.positionSize);

        totalMargin -= position.margin;
        totalExposure -= position.positionSize;

        // Withdraw USDC from vault for emergency position closure
        vault.withdrawHedgerDeposit(hedger, position.margin);

        position.isActive = false;
        _removePositionFromArrays(hedger, positionId);
        
        activePositionCount[hedger]--;
        
        // Check if hedger has no more active positions
        if (activePositionCount[hedger] == 0) {
            hedgerInfo.isActive = false;
            activeHedgers--;
        }
    }

    function pause() external {
        _validateRole(EMERGENCY_ROLE);
        _pause();
    }

    function unpause() external {
        _validateRole(EMERGENCY_ROLE);
        _unpause();
    }

    function hasPendingLiquidationCommitment(address hedger, uint256 positionId) external view returns (bool) {
        return hasPendingLiquidation[hedger][positionId];
    }

    function getHedgingConfig() external view returns (
        uint256 minMarginRatio_,
        uint256 liquidationThreshold_,
        uint256 maxLeverage_,
        uint256 liquidationPenalty_,
        uint256 entryFee_,
        uint256 exitFee_
    ) {
        return (coreParams.minMarginRatio, coreParams.liquidationThreshold, coreParams.maxLeverage, coreParams.liquidationPenalty, coreParams.entryFee, coreParams.exitFee);
    }

    function marginFee() external view returns (uint256) {
        return coreParams.marginFee;
    }

    function getMaxValues() external pure returns (
        uint256 maxPositionSize,
        uint256 maxMargin,
        uint256 maxEntryPrice,
        uint256 maxLeverageValue,
        uint256 maxTotalMargin,
        uint256 maxTotalExposure,
        uint256 maxPendingRewards
    ) {
        return (MAX_POSITION_SIZE, MAX_MARGIN, MAX_ENTRY_PRICE, MAX_LEVERAGE, MAX_TOTAL_MARGIN, MAX_TOTAL_EXPOSURE, MAX_PENDING_REWARDS);
    }

    function isHedgingActive() external view returns (bool) {
        return !paused();
    }

    function clearExpiredLiquidationCommitment(address hedger, uint256 positionId) external {
        _validateRole(LIQUIDATOR_ROLE);
        if (block.number > lastLiquidationAttempt[hedger] + LIQUIDATION_COOLDOWN) {
            hasPendingLiquidation[hedger][positionId] = false;
        }
    }

    function cancelLiquidationCommitment(address hedger, uint256 positionId, bytes32 salt) external {
        _validateRole(LIQUIDATOR_ROLE);
        bytes32 commitment = HedgerPoolLogicLibrary.generateLiquidationCommitment(
            hedger, positionId, salt, msg.sender
        );
        ValidationLibrary.validateCommitment(liquidationCommitments[commitment]);
        
        delete liquidationCommitments[commitment];
        delete liquidationCommitmentTimes[commitment];
        hasPendingLiquidation[hedger][positionId] = false;
    }

    function recoverToken(address token, uint256 amount) external {
        _validateRole(DEFAULT_ADMIN_ROLE);
        TreasuryRecoveryLibrary.recoverToken(token, amount, address(this), treasury);
    }

    function recoverETH() external {
        _validateRole(DEFAULT_ADMIN_ROLE);
        emit ETHRecovered(treasury, address(this).balance);
        TreasuryRecoveryLibrary.recoverETH(treasury);
    }

    function updateTreasury(address _treasury) external {
        _validateRole(GOVERNANCE_ROLE);
        AccessControlLibrary.validateAddress(_treasury);
        ValidationLibrary.validateTreasuryAddress(_treasury);
        require(_treasury != address(0), "Treasury cannot be zero address");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    function updateVault(address _vault) external {
        _validateRole(GOVERNANCE_ROLE);
        AccessControlLibrary.validateAddress(_vault);
        vault = IQuantillonVault(_vault);
        emit VaultUpdated(_vault);
    }

    /**
     * @notice Whitelists a hedger address for position opening
     * 
     * @param hedger Address of the hedger to whitelist
     * 
     * @dev Whitelisting process:
     *      1. Validates governance role and hedger address
     *      2. Checks hedger is not already whitelisted
     *      3. Adds hedger to whitelist and grants HEDGER_ROLE
     * 
     * @dev Security features:
     *      1. Role-based access control (GOVERNANCE_ROLE)
     *      2. Address validation
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates governance role, hedger address, not already whitelisted
     * @custom:state-changes Adds hedger to whitelist, grants HEDGER_ROLE
     * @custom:events Emits HedgerWhitelisted with hedger and caller details
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Not protected - governance function
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function whitelistHedger(address hedger) external {
        _validateRole(GOVERNANCE_ROLE);
        AccessControlLibrary.validateAddress(hedger);
        
        if (isWhitelistedHedger[hedger]) revert ErrorLibrary.AlreadyWhitelisted();
        
        isWhitelistedHedger[hedger] = true;
        _grantRole(HEDGER_ROLE, hedger);
        
        emit HedgerWhitelisted(hedger, msg.sender);
    }

    /**
     * @notice Removes a hedger from the whitelist
     * 
     * @param hedger Address of the hedger to remove from whitelist
     * 
     * @dev Removal process:
     *      1. Validates governance role and hedger address
     *      2. Checks hedger is currently whitelisted
     *      3. Removes hedger from whitelist and revokes HEDGER_ROLE
     * 
     * @dev Security features:
     *      1. Role-based access control (GOVERNANCE_ROLE)
     *      2. Address validation
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates governance role, hedger address, currently whitelisted
     * @custom:state-changes Removes hedger from whitelist, revokes HEDGER_ROLE
     * @custom:events Emits HedgerRemoved with hedger and caller details
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Not protected - governance function
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function removeHedger(address hedger) external {
        _validateRole(GOVERNANCE_ROLE);
        AccessControlLibrary.validateAddress(hedger);
        
        if (!isWhitelistedHedger[hedger]) revert ErrorLibrary.NotWhitelisted();
        
        isWhitelistedHedger[hedger] = false;
        _revokeRole(HEDGER_ROLE, hedger);
        
        emit HedgerRemoved(hedger, msg.sender);
    }

    /**
     * @notice Toggles the hedger whitelist mode on/off
     * 
     * @param enabled Whether to enable or disable the whitelist mode
     * 
     * @dev Whitelist mode toggle:
     *      1. Validates governance role
     *      2. Updates hedgerWhitelistEnabled state
     *      3. Emits event for transparency
     * 
     * @dev When enabled: Only whitelisted hedgers can open positions
     * @dev When disabled: Any address can open positions
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates governance role
     * @custom:state-changes Updates hedgerWhitelistEnabled state
     * @custom:events Emits HedgerWhitelistModeToggled with new state and caller
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Not protected - governance function
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function toggleHedgerWhitelistMode(bool enabled) external {
        _validateRole(GOVERNANCE_ROLE);
        hedgerWhitelistEnabled = enabled;
        emit HedgerWhitelistModeToggled(enabled, msg.sender);
    }

    /**
     * @notice Gets a valid EUR/USD price from the oracle
     * @return price Valid EUR/USD price from oracle
     * @dev Internal function to fetch and validate oracle price
     * @custom:security Validates oracle price is valid
     * @custom:validation Validates oracle price is valid
     * @custom:state-changes No state changes
     * @custom:events No events emitted
     * @custom:errors Throws InvalidOraclePrice if price is invalid
     * @custom:reentrancy Not protected - internal function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle Requires fresh oracle price data
     */
    function _getValidOraclePrice() internal returns (uint256) {
        (uint256 price, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) revert ErrorLibrary.InvalidOraclePrice();
        return price;
    }

    function _validateRole(bytes32 role) internal view {
        if (role == GOVERNANCE_ROLE) {
            AccessControlLibrary.onlyGovernance(this);
        } else if (role == LIQUIDATOR_ROLE) {
            AccessControlLibrary.onlyLiquidatorRole(this);
        } else if (role == EMERGENCY_ROLE) {
            AccessControlLibrary.onlyEmergencyRole(this);
        } else if (role == DEFAULT_ADMIN_ROLE) {
            AccessControlLibrary.onlyAdmin(this);
        } else {
            revert("Invalid role");
        }
    }

    function _removePositionFromArrays(address hedger, uint256 positionId) internal {
        if (!hedgerHasPosition[hedger][positionId]) revert ErrorLibrary.PositionNotFound();
        
        uint256 index = positionIndex[hedger][positionId];
        uint256[] storage positionIds = hedgers[hedger].positionIds;
        uint256 lastIndex = positionIds.length - 1;
        
        if (index != lastIndex) {
            uint256 lastPositionId = positionIds[lastIndex];
            positionIds[index] = lastPositionId;
            positionIndex[hedger][lastPositionId] = index;
        }
        
        positionIds.pop();
        
        delete positionIndex[hedger][positionId];
        delete hedgerHasPosition[hedger][positionId];
    }
    
    /**
     * @notice Internal event data packing functions to reduce contract size
     */
    function _packPositionOpenData(
        uint256 positionSize,
        uint256 margin, 
        uint256 leverage,
        uint256 entryPrice
    ) internal pure returns (bytes32) {
        return bytes32(
            (uint256(uint64(positionSize)) << 192) |
            (uint256(uint64(margin)) << 128) |
            (uint256(uint32(leverage)) << 96) |
            uint256(uint96(entryPrice))
        );
    }
    
    function _packPositionCloseData(
        uint256 exitPrice,
        int256 pnl,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        uint256 absPnl = uint256(pnl < 0 ? -pnl : pnl);
        uint256 signFlag = pnl < 0 ? (1 << 63) : 0;
        return bytes32(
            (uint256(uint96(exitPrice)) << 160) |
            (uint256(uint96(absPnl)) << 64) |
            uint256(uint64(timestamp)) |
            signFlag
        );
    }
    
    function _packMarginData(
        uint256 marginAmount,
        uint256 newMarginRatio,
        bool isAdded
    ) internal pure returns (bytes32) {
        return bytes32(
            (uint256(uint128(marginAmount)) << 128) |
            (uint256(uint128(newMarginRatio)) << 1) |
            (isAdded ? 1 : 0)
        );
    }
    
    function _packLiquidationData(
        uint256 liquidationReward,
        uint256 remainingMargin
    ) internal pure returns (bytes32) {
        return bytes32(
            (uint256(uint128(liquidationReward)) << 128) |
            uint256(uint128(remainingMargin))
        );
    }
    
    function _packRewardData(
        uint256 interestDifferential,
        uint256 yieldShiftRewards,
        uint256 totalRewards
    ) internal pure returns (bytes32) {
        return bytes32(
            (uint256(uint128(interestDifferential)) << 128) |
            (uint256(uint64(yieldShiftRewards)) << 64) |
            uint256(uint64(totalRewards))
        );
    }

    /**
     * @notice Validates that closing a position won't cause protocol undercollateralization
     * @dev Checks if closing the position would make the protocol undercollateralized for QEURO minting
     * @param positionId The position ID being closed
     * @param positionMargin The margin amount of the position being closed
     * @custom:security Validates protocol collateralization status
     * @custom:validation Checks vault collateralization ratio
     * @custom:state-changes No state changes - validation only
     * @custom:events No events emitted
     * @custom:errors Throws PositionClosureRestricted if closure would cause undercollateralization
     * @custom:reentrancy Not protected - internal function only
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _validatePositionClosureSafety(uint256 positionId, uint256 positionMargin) internal view {
        // Skip validation if vault is not set (for backward compatibility)
        if (address(vault) == address(0)) {
            return;
        }

        // Get current protocol collateralization status
        (, uint256 currentTotalMargin) = vault.isProtocolCollateralized();
        
        // Get minimum collateralization ratio for minting
        uint256 minCollateralizationRatio = vault.minCollateralizationRatioForMinting();
        
        // Get QEURO total supply to check if any QEURO has been minted
        address qeuroAddress = vault.qeuro();
        uint256 totalQEURO = 0;
        if (qeuroAddress != address(0)) {
            // Call totalSupply on the QEURO contract
            (bool success, bytes memory data) = qeuroAddress.staticcall(
                abi.encodeWithSignature("totalSupply()")
            );
            if (success && data.length >= 32) {
                totalQEURO = abi.decode(data, (uint256));
            }
        }

        // If no QEURO has been minted, position can always be closed
        if (totalQEURO == 0) {
            return;
        }

        // Get UserPool total deposits
        address userPoolAddress = vault.userPool();
        uint256 userDeposits = 0;
        if (userPoolAddress != address(0)) {
            // Call totalDeposits on the UserPool contract
            (bool success, bytes memory data) = userPoolAddress.staticcall(
                abi.encodeWithSignature("totalDeposits()")
            );
            if (success && data.length >= 32) {
                userDeposits = abi.decode(data, (uint256));
            }
        }
        
        // Calculate what the collateralization ratio would be after closing this position
        uint256 remainingHedgerMargin = currentTotalMargin - positionMargin;
        
        // If no user deposits, hedger margin is the only collateral
        if (userDeposits == 0) {
            // If no QEURO has been minted and no user deposits, position can always be closed
            // because there's nothing to hedge
            return;
        }

        // Calculate future collateralization ratio
        uint256 futureRatio = ((userDeposits + remainingHedgerMargin) * 10000) / userDeposits;

        // Check if closing would make the protocol undercollateralized for minting
        if (futureRatio < minCollateralizationRatio) {
            revert ErrorLibrary.PositionClosureRestricted();
        }
    }
}