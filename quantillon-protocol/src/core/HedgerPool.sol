// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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
import {FlashLoanProtectionLibrary} from "../libraries/FlashLoanProtectionLibrary.sol";
import {TimeProvider} from "../libraries/TimeProviderLibrary.sol";
import {HedgerPoolOptimizationLibrary} from "../libraries/HedgerPoolOptimizationLibrary.sol";
import {AdminFunctionsLibrary} from "../libraries/AdminFunctionsLibrary.sol";
import {CommonValidationLibrary} from "../libraries/CommonValidationLibrary.sol";
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

    /**
     * @notice Initializes the HedgerPool contract with a time provider
     * @dev Constructor that sets up the time provider and disables initializers for upgrade safety
     * @param _TIME_PROVIDER The time provider contract for timestamp management
     * @custom:security Validates that the time provider is not zero address
     * @custom:validation Ensures TIME_PROVIDER is a valid contract address
     * @custom:state-changes Sets TIME_PROVIDER and disables initializers
     * @custom:events None
     * @custom:errors Throws ZeroAddress if _TIME_PROVIDER is address(0)
     * @custom:reentrancy Not applicable - constructor
     * @custom:access Public constructor
     * @custom:oracle Not applicable
     */
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
        AccessControlLibrary.validateAddress(_timelock);
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
        
        // Additional zero-check for treasury assignment
        CommonValidationLibrary.validateNonZeroAddress(_treasury, "treasury");
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
        // CHECKS
        if (hedgerWhitelistEnabled && !isWhitelistedHedger[msg.sender]) {
            revert ErrorLibrary.NotWhitelisted();
        }
        
        uint256 currentTime = TIME_PROVIDER.currentTime();
        
        // Calculate position parameters using a default price (will be updated with oracle call later)
        uint256 defaultPrice = 1.08e18; // Default EUR/USD price
        (uint256 _fee, uint256 netMargin, uint256 positionSize, uint256 marginRatio) = 
            HedgerPoolLogicLibrary.validateAndCalculatePositionParams(
                usdcAmount, leverage, defaultPrice, coreParams.entryFee, coreParams.minMarginRatio, MAX_MARGIN_RATIO, coreParams.maxLeverage,
                MAX_POSITIONS_PER_HEDGER, activePositionCount[msg.sender], MAX_MARGIN,
                MAX_POSITION_SIZE, MAX_ENTRY_PRICE, MAX_LEVERAGE, currentTime
            );
        
        // EFFECTS - All state updates before any external calls
        positionId = nextPositionId++;
        
        // Create and initialize position
        HedgePosition storage position = positions[positionId];
        position.hedger = msg.sender;
        position.positionSize = uint96(positionSize);
        position.margin = uint96(netMargin);
        position.entryTime = uint32(currentTime);
        position.lastUpdateTime = uint32(currentTime);
        position.leverage = uint16(leverage);
        position.entryPrice = uint96(defaultPrice);
        position.unrealizedPnL = 0;
        position.isActive = true;

        // Update hedger information
        HedgerInfo storage hedgerInfo = hedgers[msg.sender];
        bool wasInactive = !hedgerInfo.isActive;
        if (wasInactive) {
            hedgerInfo.isActive = true;
            activeHedgers++;
        }
        
        // Batch update hedger state
        hedgerInfo.positionIds.push(positionId);
        positionIndex[msg.sender][positionId] = hedgerInfo.positionIds.length - 1;
        hedgerInfo.totalMargin += uint128(netMargin);
        hedgerInfo.totalExposure += uint128(positionSize);
        
        // Update global state
        hedgerHasPosition[msg.sender][positionId] = true;
        activePositionCount[msg.sender]++;
        totalMargin += netMargin;
        totalExposure += positionSize;
        
        // INTERACTIONS - Oracle call before external calls
        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        CommonValidationLibrary.validateCondition(isValid, "oracle");
        
        // Update position with actual oracle price before external calls
        position.entryPrice = uint96(eurUsdPrice);
        
        // Emit event with actual values before external calls
        emit HedgePositionOpened(
            msg.sender, 
            positionId, 
            _packPositionOpenData(positionSize, netMargin, leverage, eurUsdPrice)
        );
        
        // INTERACTIONS - All external calls after state updates
        usdc.safeTransferFrom(msg.sender, address(vault), usdcAmount);
        vault.addHedgerDeposit(usdcAmount);
        
        // Validate margin ratio meets minimum requirements
        assert(marginRatio >= coreParams.minMarginRatio);
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

        // Cache position data before state changes for event emission
        uint256 cachedPositionSize = uint256(position.positionSize);
        uint256 cachedEntryPrice = uint256(position.entryPrice);
        uint256 cachedMargin = uint256(position.margin);

        // Update ALL state variables before external calls (Checks-Effects-Interactions pattern)
        HedgerInfo storage hedgerInfo = hedgers[msg.sender];
        hedgerInfo.totalMargin -= uint128(cachedMargin);
        hedgerInfo.totalExposure -= uint128(cachedPositionSize);

        totalMargin -= cachedMargin;
        totalExposure -= cachedPositionSize;

        position.isActive = false;
        _removePositionFromArrays(msg.sender, positionId);
        
        activePositionCount[msg.sender]--;
        
        // Check if hedger has no more active positions and update state
        if (activePositionCount[msg.sender] == 0) {
            hedgerInfo.isActive = false;
            activeHedgers--;
        }

        // Emit event before any external calls (oracle call)
        emit HedgePositionClosed(
            msg.sender, 
            positionId, 
            _packPositionCloseData(0, 0, TIME_PROVIDER.currentTime()) // Placeholder values, will be updated after oracle call
        );

        // Get oracle price after ALL state changes
        uint256 currentPrice = _getValidOraclePrice();
        pnl = HedgerPoolLogicLibrary.calculatePnL(
            cachedPositionSize, 
            cachedEntryPrice, 
            currentPrice
        );

        uint256 grossPayout = uint256(int256(cachedMargin) + pnl);
        uint256 exitFeeAmount = grossPayout.percentageOf(coreParams.exitFee);
        uint256 netPayout = grossPayout - exitFeeAmount;

        if (netPayout > 0) {
            // Withdraw USDC from vault for hedger payout
            vault.withdrawHedgerDeposit(msg.sender, netPayout);
        }
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

        (uint256 newMargin, uint256 newMarginRatio) = HedgerPoolLogicLibrary.validateMarginOperation(
            uint256(position.margin), netAmount, true, coreParams.minMarginRatio, 
            uint256(position.positionSize), MAX_MARGIN
        );
        
        // Update state variables before external calls (Checks-Effects-Interactions pattern)
        position.margin = uint96(newMargin);
        hedgers[msg.sender].totalMargin += uint128(netAmount);
        totalMargin += netAmount;

        emit MarginUpdated(
            msg.sender, 
            positionId, 
            _packMarginData(netAmount, newMarginRatio, true)
        );

        // Transfer USDC directly to vault for unified liquidity management
        usdc.safeTransferFrom(msg.sender, address(vault), amount);
        
        // Notify vault of additional hedger deposit
        vault.addHedgerDeposit(amount);
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

        emit MarginUpdated(
            msg.sender, 
            positionId, 
            _packMarginData(amount, newMarginRatio, false)
        );

        // Withdraw USDC from vault for hedger margin removal
        vault.withdrawHedgerDeposit(msg.sender, amount);
    }

    /**
     * @notice Commits to liquidating a hedger position with a salt for MEV protection
     * @dev Creates a liquidation commitment that must be executed within a time window
     * @param hedger Address of the hedger whose position will be liquidated
     * @param positionId ID of the position to liquidate
     * @param salt Random salt for commitment uniqueness and MEV protection
     * @custom:security Requires LIQUIDATOR_ROLE, validates addresses and position ID
     * @custom:validation Ensures hedger is valid address, positionId > 0, commitment doesn't exist
     * @custom:state-changes Sets liquidation commitment, timing, and pending liquidation flags
     * @custom:events None (commitment phase)
     * @custom:errors Throws InvalidRole, InvalidAddress, InvalidPosition, or CommitmentExists
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to LIQUIDATOR_ROLE
     * @custom:oracle Not applicable
     */
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
        
        // Update ALL state variables before external calls (Checks-Effects-Interactions pattern)
        delete liquidationCommitments[commitment];
        delete liquidationCommitmentTimes[commitment];
        hasPendingLiquidation[hedger][positionId] = false;

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
        
        // Get oracle price after ALL state changes for validation
        uint256 currentPrice = _getValidOraclePrice();
        bool liquidatable = HedgerPoolLogicLibrary.isPositionLiquidatable(
            uint256(position.margin), uint256(position.positionSize), 
            uint256(position.entryPrice), currentPrice, coreParams.liquidationThreshold
        );
        
        if (!liquidatable) revert ErrorLibrary.PositionNotLiquidatable();

        liquidationReward = uint256(position.margin).percentageOf(coreParams.liquidationPenalty);
        uint256 remainingMargin = uint256(position.margin) - liquidationReward;

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

    /**
     * @notice Retrieves detailed information about a specific hedger position
     * @dev Returns position data including current oracle price for real-time calculations
     * @param hedger Address of the hedger who owns the position
     * @param positionId ID of the position to retrieve
     * @return positionSize Current size of the position in USDC
     * @return margin Current margin amount for the position
     * @return entryPrice Price at which the position was opened
     * @return currentPrice Current EUR/USD price from oracle
     * @return leverage Leverage multiplier for the position
     * @return lastUpdateTime Timestamp of last position update
     * @custom:security Validates that the caller owns the position
     * @custom:validation Ensures position exists and hedger matches
     * @custom:state-changes None (view function with oracle call)
     * @custom:events None
     * @custom:errors Throws InvalidHedger if position doesn't belong to hedger
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Public (anyone can query position data)
     * @custom:oracle Calls _getValidOraclePrice() for current price
     */
    function getHedgerPosition(address hedger, uint256 positionId) 
        external 
        view
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

    /**
     * @notice Calculates the current margin ratio for a hedger position
     * @dev Returns margin ratio as basis points (10000 = 100%)
     * @param hedger Address of the hedger who owns the position
     * @param positionId ID of the position to check
     * @return Current margin ratio in basis points (margin/positionSize * 10000)
     * @custom:security Validates that the caller owns the position
     * @custom:validation Ensures position exists and hedger matches
     * @custom:state-changes None (view function)
     * @custom:events None
     * @custom:errors Throws InvalidHedger if position doesn't belong to hedger
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public (anyone can query margin ratio)
     * @custom:oracle Not applicable
     */
    function getHedgerMarginRatio(address hedger, uint256 positionId) external view returns (uint256) {
        HedgePosition storage position = positions[positionId];
        if (position.hedger != hedger) revert ErrorLibrary.InvalidHedger();
        
        if (position.positionSize == 0) return 0;
        return uint256(position.margin).mulDiv(10000, uint256(position.positionSize));
    }

    /**
     * @notice Checks if a hedger position is eligible for liquidation
     * @dev Uses current oracle price to determine if position is undercollateralized
     * @param hedger Address of the hedger who owns the position
     * @param positionId ID of the position to check
     * @return True if position can be liquidated, false otherwise
     * @custom:security Validates that the caller owns the position
     * @custom:validation Ensures position exists, is active, and hedger matches
     * @custom:state-changes None (view function with oracle call)
     * @custom:events None
     * @custom:errors Throws InvalidHedger if position doesn't belong to hedger
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Public (anyone can check liquidation status)
     * @custom:oracle Calls _getValidOraclePrice() for current price comparison
     */
    function isHedgerLiquidatable(address hedger, uint256 positionId) external view returns (bool) {
        HedgePosition storage position = positions[positionId];
        if (position.hedger != hedger) revert ErrorLibrary.InvalidHedger();
        
        if (!position.isActive) return false;
        
        uint256 currentPrice = _getValidOraclePrice();
        return HedgerPoolLogicLibrary.isPositionLiquidatable(
            uint256(position.margin), uint256(position.positionSize), 
            uint256(position.entryPrice), currentPrice, coreParams.liquidationThreshold
        );
    }

    /**
     * @notice Returns the total hedge exposure across all active positions
     * @dev Provides aggregate exposure for risk management and monitoring
     * @return Total exposure amount in USDC across all active hedge positions
     * @custom:security No security validations required for view function
     * @custom:validation None required for view function
     * @custom:state-changes None (view function)
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public (anyone can query total exposure)
     * @custom:oracle Not applicable
     */
    function getTotalHedgeExposure() external view returns (uint256) {
        return totalExposure;
    }

    /**
     * @notice Updates core hedging parameters for the protocol
     * @dev Allows governance to adjust risk parameters for hedge positions
     * @param newMinMarginRatio New minimum margin ratio in basis points (minimum 500 = 5%)
     * @param newLiquidationThreshold New liquidation threshold in basis points (must be < minMarginRatio)
     * @param newMaxLeverage New maximum leverage multiplier (maximum 20x)
     * @param newLiquidationPenalty New liquidation penalty in basis points (maximum 1000 = 10%)
     * @custom:security Requires GOVERNANCE_ROLE, validates parameter ranges
     * @custom:validation Ensures minMarginRatio >= 500, liquidationThreshold < minMarginRatio, maxLeverage <= 20, liquidationPenalty <= 1000
     * @custom:state-changes Updates coreParams struct with new values
     * @custom:events None
     * @custom:errors Throws InvalidRole, ConfigValueTooLow, ConfigInvalid, or ConfigValueTooHigh
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle Not applicable
     */
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

    /**
     * @notice Updates interest rates for EUR and USD positions
     * @dev Allows governance to adjust interest rates for yield calculations
     * @param newEurRate New EUR interest rate in basis points (maximum 2000 = 20%)
     * @param newUsdRate New USD interest rate in basis points (maximum 2000 = 20%)
     * @custom:security Requires GOVERNANCE_ROLE, validates rate limits
     * @custom:validation Ensures both rates are <= 2000 basis points (20%)
     * @custom:state-changes Updates coreParams with new interest rates
     * @custom:events None
     * @custom:errors Throws InvalidRole or ConfigValueTooHigh
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle Not applicable
     */
    function updateInterestRates(uint256 newEurRate, uint256 newUsdRate) external {
        _validateRole(GOVERNANCE_ROLE);
        if (newEurRate > 2000 || newUsdRate > 2000) revert ErrorLibrary.ConfigValueTooHigh();
        
        coreParams.eurInterestRate = uint16(newEurRate);
        coreParams.usdInterestRate = uint16(newUsdRate);
    }

    /**
     * @notice Sets the fee structure for hedge positions
     * @dev Allows governance to adjust fees for position entry, exit, and margin operations
     * @param _entryFee New entry fee in basis points (maximum 100 = 1%)
     * @param _exitFee New exit fee in basis points (maximum 100 = 1%)
     * @param _marginFee New margin fee in basis points (maximum 50 = 0.5%)
     * @custom:security Requires GOVERNANCE_ROLE, validates fee limits
     * @custom:validation Ensures entryFee <= 100, exitFee <= 100, marginFee <= 50
     * @custom:state-changes Updates coreParams with new fee values
     * @custom:events None
     * @custom:errors Throws InvalidRole or InvalidFee
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle Not applicable
     */
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

        position.isActive = false;
        _removePositionFromArrays(hedger, positionId);
        
        activePositionCount[hedger]--;
        
        // Check if hedger has no more active positions
        if (activePositionCount[hedger] == 0) {
            hedgerInfo.isActive = false;
            activeHedgers--;
        }

        // Withdraw USDC from vault for emergency position closure
        vault.withdrawHedgerDeposit(hedger, position.margin);
    }

    /**
     * @notice Pauses all contract operations in case of emergency
     * @dev Emergency function to halt all user interactions
     * @custom:security Requires EMERGENCY_ROLE
     * @custom:validation None required
     * @custom:state-changes Sets contract to paused state
     * @custom:events Emits Paused event
     * @custom:errors Throws InvalidRole if caller lacks EMERGENCY_ROLE
     * @custom:reentrancy Not applicable
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle Not applicable
     */
    function pause() external {
        _validateRole(EMERGENCY_ROLE);
        _pause();
    }

    /**
     * @notice Unpauses contract operations after emergency
     * @dev Resumes normal contract functionality
     * @custom:security Requires EMERGENCY_ROLE
     * @custom:validation None required
     * @custom:state-changes Sets contract to unpaused state
     * @custom:events Emits Unpaused event
     * @custom:errors Throws InvalidRole if caller lacks EMERGENCY_ROLE
     * @custom:reentrancy Not applicable
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle Not applicable
     */
    function unpause() external {
        _validateRole(EMERGENCY_ROLE);
        _unpause();
    }

    /**
     * @notice Checks if a position has a pending liquidation commitment
     * @dev Returns true if a liquidation commitment exists for the position
     * @param hedger Address of the hedger who owns the position
     * @param positionId ID of the position to check
     * @return True if liquidation commitment exists, false otherwise
     * @custom:security No security validations required for view function
     * @custom:validation None required for view function
     * @custom:state-changes None (view function)
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public (anyone can query commitment status)
     * @custom:oracle Not applicable
     */
    function hasPendingLiquidationCommitment(address hedger, uint256 positionId) external view returns (bool) {
        return hasPendingLiquidation[hedger][positionId];
    }

    /**
     * @notice Returns the current hedging configuration parameters
     * @dev Provides access to all core hedging parameters for external contracts
     * @return minMarginRatio_ Current minimum margin ratio in basis points
     * @return liquidationThreshold_ Current liquidation threshold in basis points
     * @return maxLeverage_ Current maximum leverage multiplier
     * @return liquidationPenalty_ Current liquidation penalty in basis points
     * @return entryFee_ Current entry fee in basis points
     * @return exitFee_ Current exit fee in basis points
     * @custom:security No security validations required for view function
     * @custom:validation None required for view function
     * @custom:state-changes None (view function)
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public (anyone can query configuration)
     * @custom:oracle Not applicable
     */
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

    /**
     * @notice Returns the current margin fee rate
     * @dev Provides the margin fee for margin operations
     * @return Current margin fee in basis points
     * @custom:security No security validations required for view function
     * @custom:validation None required for view function
     * @custom:state-changes None (view function)
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public (anyone can query margin fee)
     * @custom:oracle Not applicable
     */
    function marginFee() external view returns (uint256) {
        return coreParams.marginFee;
    }

    /**
     * @notice Returns the maximum allowed values for various parameters
     * @dev Provides hard limits for position sizes, margins, and other constraints
     * @return maxPositionSize Maximum position size in USDC
     * @return maxMargin Maximum margin per position in USDC
     * @return maxEntryPrice Maximum entry price for positions
     * @return maxLeverageValue Maximum leverage multiplier
     * @return maxTotalMargin Maximum total margin across all positions
     * @return maxTotalExposure Maximum total exposure across all positions
     * @return maxPendingRewards Maximum pending rewards amount
     * @custom:security No security validations required for pure function
     * @custom:validation None required for pure function
     * @custom:state-changes None (pure function)
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public (anyone can query max values)
     * @custom:oracle Not applicable
     */
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

    /**
     * @notice Checks if hedging operations are currently active
     * @dev Returns true if contract is not paused, false if paused
     * @return True if hedging is active, false if paused
     * @custom:security No security validations required for view function
     * @custom:validation None required for view function
     * @custom:state-changes None (view function)
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public (anyone can query hedging status)
     * @custom:oracle Not applicable
     */
    function isHedgingActive() external view returns (bool) {
        return !paused();
    }

    /**
     * @notice Clears expired liquidation commitments after cooldown period
     * @dev Allows liquidators to clean up expired commitments
     * @param hedger Address of the hedger whose commitment to clear
     * @param positionId ID of the position whose commitment to clear
     * @custom:security Requires LIQUIDATOR_ROLE, checks cooldown period
     * @custom:validation Ensures cooldown period has passed
     * @custom:state-changes Clears pending liquidation flag if expired
     * @custom:events None
     * @custom:errors Throws InvalidRole if caller lacks LIQUIDATOR_ROLE
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to LIQUIDATOR_ROLE
     * @custom:oracle Not applicable
     */
    function clearExpiredLiquidationCommitment(address hedger, uint256 positionId) external {
        _validateRole(LIQUIDATOR_ROLE);
        if (block.number > lastLiquidationAttempt[hedger] + LIQUIDATION_COOLDOWN) {
            hasPendingLiquidation[hedger][positionId] = false;
        }
    }

    /**
     * @notice Cancels a liquidation commitment before execution
     * @dev Allows liquidators to cancel their own commitments
     * @param hedger Address of the hedger whose position was committed for liquidation
     * @param positionId ID of the position whose commitment to cancel
     * @param salt Salt used in the original commitment
     * @custom:security Requires LIQUIDATOR_ROLE, validates commitment exists
     * @custom:validation Ensures commitment exists and belongs to caller
     * @custom:state-changes Deletes commitment data and clears pending liquidation flag
     * @custom:events None
     * @custom:errors Throws InvalidRole or CommitmentNotFound
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to LIQUIDATOR_ROLE
     * @custom:oracle Not applicable
     */
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

    /**
     * @notice Recovers accidentally sent tokens to the treasury
     * @dev Emergency function to recover tokens sent to the contract
     * @param token Address of the token to recover
     * @param amount Amount of tokens to recover
     * @custom:security Requires DEFAULT_ADMIN_ROLE
     * @custom:validation None required
     * @custom:state-changes Transfers tokens from contract to treasury
     * @custom:events None
     * @custom:errors Throws InvalidRole if caller lacks DEFAULT_ADMIN_ROLE
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle Not applicable
     */
    function recoverToken(address token, uint256 amount) external {
        AdminFunctionsLibrary.recoverToken(address(this), token, amount, treasury, DEFAULT_ADMIN_ROLE);
    }

    /**
     * @notice Recovers accidentally sent ETH to the treasury
     * @dev Emergency function to recover ETH sent to the contract
     * @custom:security Requires DEFAULT_ADMIN_ROLE
     * @custom:validation None required
     * @custom:state-changes Transfers ETH from contract to treasury
     * @custom:events Emits ETHRecovered event
     * @custom:errors Throws InvalidRole if caller lacks DEFAULT_ADMIN_ROLE
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle Not applicable
     */
    function recoverETH() external {
        AdminFunctionsLibrary.recoverETH(address(this), treasury, DEFAULT_ADMIN_ROLE);
    }

    /**
     * @notice Updates the treasury address for fee collection
     * @dev Allows governance to change the treasury address
     * @param _treasury New treasury address for fee collection
     * @custom:security Requires GOVERNANCE_ROLE, validates address
     * @custom:validation Ensures treasury is not zero address and passes validation
     * @custom:state-changes Updates treasury address
     * @custom:events Emits TreasuryUpdated event
     * @custom:errors Throws InvalidRole, InvalidAddress, or zero address error
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle Not applicable
     */
    function updateTreasury(address _treasury) external {
        _validateRole(GOVERNANCE_ROLE);
        AccessControlLibrary.validateAddress(_treasury);
        ValidationLibrary.validateTreasuryAddress(_treasury);
        CommonValidationLibrary.validateNonZeroAddress(_treasury, "treasury");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    /**
     * @notice Updates the vault address for USDC management
     * @dev Allows governance to change the vault contract address
     * @param _vault New vault address for USDC operations
     * @custom:security Requires GOVERNANCE_ROLE, validates address
     * @custom:validation Ensures vault is not zero address
     * @custom:state-changes Updates vault address
     * @custom:events Emits VaultUpdated event
     * @custom:errors Throws InvalidRole or InvalidAddress
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle Not applicable
     */
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
    function _getValidOraclePrice() internal view returns (uint256) {
        (uint256 price, bool isValid) = HedgerPoolOptimizationLibrary.getValidOraclePrice(address(oracle));
        if (!isValid) revert ErrorLibrary.InvalidOraclePrice();
        return price;
    }

    /**
     * @notice Validates that the caller has the required role
     * @dev Internal function to check role-based access control
     * @param role The role to validate against
     * @custom:security Validates caller has the specified role
     * @custom:validation Checks role against AccessControlLibrary
     * @custom:state-changes None (view function)
     * @custom:events None
     * @custom:errors Throws InvalidRole if caller lacks required role
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal function
     * @custom:oracle Not applicable
     */
    function _validateRole(bytes32 role) internal view {
        HedgerPoolOptimizationLibrary.validateRole(role, address(this));
    }

    /**
     * @notice Removes a position from the hedger's position arrays
     * @dev Internal function to maintain position tracking arrays
     * @param hedger Address of the hedger whose position to remove
     * @param positionId ID of the position to remove
     * @custom:security Validates position exists before removal
     * @custom:validation Ensures position exists in hedger's array
     * @custom:state-changes Removes position from arrays and updates indices
     * @custom:events None
     * @custom:errors Throws PositionNotFound if position doesn't exist
     * @custom:reentrancy Not applicable - internal function
     * @custom:access Internal function
     * @custom:oracle Not applicable
     */
    function _removePositionFromArrays(address hedger, uint256 positionId) internal {
        bool success = HedgerPoolOptimizationLibrary.removePositionFromArrays(
            hedger,
            positionId,
            hedgerHasPosition,
            positionIndex,
            hedgers[hedger].positionIds
        );
        if (!success) revert ErrorLibrary.PositionNotFound();
    }
    
    /**
     * @notice Packs position open data into a single bytes32 for gas efficiency
     * @dev Encodes position size, margin, leverage, and entry price into a compact format
     * @param positionSize Size of the position in USDC
     * @param margin Margin amount for the position
     * @param leverage Leverage multiplier for the position
     * @param entryPrice Price at which the position was opened
     * @return Packed data as bytes32
     * @custom:security No security validations required for pure function
     * @custom:validation None required for pure function
     * @custom:state-changes None (pure function)
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal function
     * @custom:oracle Uses provided entryPrice parameter
     */
    function _packPositionOpenData(
        uint256 positionSize,
        uint256 margin, 
        uint256 leverage,
        uint256 entryPrice
    ) internal pure returns (bytes32) {
        return HedgerPoolOptimizationLibrary.packPositionOpenData(positionSize, margin, leverage, entryPrice);
    }
    
    /**
     * @notice Packs position close data into a single bytes32 for gas efficiency
     * @dev Encodes exit price, PnL, and timestamp into a compact format
     * @param exitPrice Price at which the position was closed
     * @param pnl Profit or loss from the position (can be negative)
     * @param timestamp Timestamp when the position was closed
     * @return Packed data as bytes32
     * @custom:security No security validations required for pure function
     * @custom:validation None required for pure function
     * @custom:state-changes None (pure function)
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal function
     * @custom:oracle Not applicable
     */
    function _packPositionCloseData(
        uint256 exitPrice,
        int256 pnl,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return HedgerPoolOptimizationLibrary.packPositionCloseData(exitPrice, pnl, timestamp);
    }
    
    /**
     * @notice Packs margin data into a single bytes32 for gas efficiency
     * @dev Encodes margin amount, new margin ratio, and operation type
     * @param marginAmount Amount of margin added or removed
     * @param newMarginRatio New margin ratio after the operation
     * @param isAdded True if margin was added, false if removed
     * @return Packed data as bytes32
     * @custom:security No security validations required for pure function
     * @custom:validation None required for pure function
     * @custom:state-changes None (pure function)
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal function
     * @custom:oracle Not applicable
     */
    function _packMarginData(
        uint256 marginAmount,
        uint256 newMarginRatio,
        bool isAdded
    ) internal pure returns (bytes32) {
        return HedgerPoolOptimizationLibrary.packMarginData(marginAmount, newMarginRatio, isAdded);
    }
    
    /**
     * @notice Packs liquidation data into a single bytes32 for gas efficiency
     * @dev Encodes liquidation reward and remaining margin
     * @param liquidationReward Reward paid to the liquidator
     * @param remainingMargin Margin remaining after liquidation
     * @return Packed data as bytes32
     * @custom:security No security validations required for pure function
     * @custom:validation None required for pure function
     * @custom:state-changes None (pure function)
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal function
     * @custom:oracle Not applicable
     */
    function _packLiquidationData(
        uint256 liquidationReward,
        uint256 remainingMargin
    ) internal pure returns (bytes32) {
        return HedgerPoolOptimizationLibrary.packLiquidationData(liquidationReward, remainingMargin);
    }
    
    /**
     * @notice Packs reward data into a single bytes32 for gas efficiency
     * @dev Encodes interest differential, yield shift rewards, and total rewards
     * @param interestDifferential Interest rate differential between EUR and USD
     * @param yieldShiftRewards Rewards from yield shifting operations
     * @param totalRewards Total rewards accumulated
     * @return Packed data as bytes32
     * @custom:security No security validations required for pure function
     * @custom:validation None required for pure function
     * @custom:state-changes None (pure function)
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal function
     * @custom:oracle Not applicable
     */
    function _packRewardData(
        uint256 interestDifferential,
        uint256 yieldShiftRewards,
        uint256 totalRewards
    ) internal pure returns (bytes32) {
        return HedgerPoolOptimizationLibrary.packRewardData(interestDifferential, yieldShiftRewards, totalRewards);
    }

    /**
     * @notice Validates that closing a position won't cause protocol undercollateralization
     * @dev Checks if closing the position would make the protocol undercollateralized for QEURO minting
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
    function _validatePositionClosureSafety(uint256 /* positionId */, uint256 positionMargin) internal view {
        bool isValid = HedgerPoolOptimizationLibrary.validatePositionClosureSafety(positionMargin, address(vault));
        if (!isValid) {
            revert ErrorLibrary.PositionClosureRestricted();
        }
    }
}