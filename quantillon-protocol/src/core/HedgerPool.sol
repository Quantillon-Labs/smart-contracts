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
import {HedgerPoolErrorLibrary} from "../libraries/HedgerPoolErrorLibrary.sol";
import {HedgerPoolValidationLibrary} from "../libraries/HedgerPoolValidationLibrary.sol";
import {AccessControlLibrary} from "../libraries/AccessControlLibrary.sol";
import {SecureUpgradeable} from "./SecureUpgradeable.sol";
import {TimeProvider} from "../libraries/TimeProviderLibrary.sol";
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
    using HedgerPoolValidationLibrary for uint256;

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
    uint256 public totalFilledExposure;
    uint256 public activeHedgers;
    uint256 public nextPositionId;

    mapping(address => bool) public isWhitelistedHedger;
    bool public hedgerWhitelistEnabled;

    struct HedgePosition {
        address hedger;
        uint96 positionSize;
        uint96 filledVolume;
        uint96 margin;
        uint96 entryPrice;
        uint32 entryTime;
        uint32 lastUpdateTime;
        int128 unrealizedPnL;
        uint16 leverage;
        bool isActive;
    }

    struct HedgerBalance {
        uint128 totalMargin;
        uint128 totalExposure;
    }

    struct HedgerRewardState {
        uint128 pendingRewards;
        uint64 lastRewardClaim;
    }

    mapping(uint256 => HedgePosition) public positions;
    mapping(address => HedgerBalance) private hedgerBalances;
    mapping(address => HedgerRewardState) private hedgerRewards;
    mapping(address => uint256) private hedgerPositionCounts;
    mapping(bytes32 => uint256) private liquidationCommitments;
    mapping(address => mapping(uint256 => uint32)) private pendingLiquidations;

    uint256[] private activePositions;
    mapping(uint256 => uint256) private activePositionIndex;

    mapping(address => uint256) public lastLiquidationAttempt;

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
    event HedgerFillUpdated(uint256 indexed positionId, uint256 previousFilled, uint256 newFilled);

    modifier onlyVault() {
        if (msg.sender != address(vault)) revert HedgerPoolErrorLibrary.OnlyVault();
        _;
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
        if (address(_TIME_PROVIDER) == address(0)) revert HedgerPoolErrorLibrary.ZeroAddress();
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
        // Oracle and YieldShift can be zero during phased deployment, set via setters later
        if (_oracle != address(0)) AccessControlLibrary.validateAddress(_oracle);
        if (_yieldShift != address(0)) AccessControlLibrary.validateAddress(_yieldShift);
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
        require(_treasury != address(0), "Treasury cannot be zero address");
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
     * @custom:reentrancy Protected by secureNonReentrant modifier and proper CEI pattern
     * @custom:access Restricted to whitelisted hedgers (if whitelist enabled)
     * @custom:oracle Requires fresh oracle price data
     */
    // slither-disable-next-line reentrancy-benign
    // slither-disable-start reentrancy-benign
    function enterHedgePosition(uint256 usdcAmount, uint256 leverage) 
        external 
        whenNotPaused
        nonReentrant
        returns (uint256 positionId) 
    {
        // CHECKS
        if (hedgerWhitelistEnabled && !isWhitelistedHedger[msg.sender]) {
            revert HedgerPoolErrorLibrary.NotWhitelisted();
        }
        
        uint256 currentTime = TIME_PROVIDER.currentTime();
        
        // Get oracle price first to prevent reentrancy
        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        CommonValidationLibrary.validateCondition(isValid, "oracle");
        
        // Calculate position parameters using actual oracle price
        (uint256 fee, uint256 netMargin, uint256 positionSize, uint256 marginRatio) = 
            HedgerPoolLogicLibrary.validateAndCalculatePositionParams(
                usdcAmount, leverage, eurUsdPrice, coreParams.entryFee, coreParams.minMarginRatio, MAX_MARGIN_RATIO, coreParams.maxLeverage,
                MAX_POSITIONS_PER_HEDGER, hedgerPositionCounts[msg.sender], MAX_MARGIN,
                MAX_POSITION_SIZE, MAX_ENTRY_PRICE, MAX_LEVERAGE, currentTime
            );
        
        // Fee is calculated but not used in this function as it's handled by the fee collection mechanism
        // This prevents Slither from flagging unused return value
        fee; // Explicitly acknowledge the fee value to avoid unused variable warning
        
        // EFFECTS - All state updates before any external calls
        positionId = nextPositionId++;
        
        // Create and initialize position
        HedgePosition storage position = positions[positionId];
        position.hedger = msg.sender;
        position.positionSize = uint96(positionSize);
        position.filledVolume = 0;
        position.margin = uint96(netMargin);
        position.entryTime = uint32(currentTime);
        position.lastUpdateTime = uint32(currentTime);
        position.leverage = uint16(leverage);
        position.entryPrice = uint96(eurUsdPrice);
        position.unrealizedPnL = 0;
        position.isActive = true;
        _trackActivePosition(positionId);

        // Update hedger information
        HedgerBalance storage hedgerInfo = hedgerBalances[msg.sender];
        bool wasInactive = hedgerInfo.totalExposure == 0;
        
        // Batch update hedger state
        hedgerInfo.totalMargin += uint128(netMargin);
        hedgerInfo.totalExposure += uint128(positionSize);
        if (wasInactive && hedgerInfo.totalExposure > 0) {
            activeHedgers++;
        }
        
        // Update global state
        hedgerPositionCounts[msg.sender]++;
        totalMargin += netMargin;
        totalExposure += positionSize;
        
        // INTERACTIONS - All external calls after state updates
        usdc.safeTransferFrom(msg.sender, address(vault), usdcAmount);
        vault.addHedgerDeposit(usdcAmount);
        
        // Emit event after all external calls to prevent reentrancy issues
        // This follows the Checks-Effects-Interactions pattern properly
        emit HedgePositionOpened(
            msg.sender, 
            positionId, 
            _packPositionOpenData(positionSize, netMargin, leverage, eurUsdPrice)
        );
        
        // Validate margin ratio meets minimum requirements
        assert(marginRatio >= coreParams.minMarginRatio);
    }
    // slither-disable-end reentrancy-benign

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
        HedgerPoolValidationLibrary.validatePositionOwner(position.hedger, msg.sender);
        HedgerPoolValidationLibrary.validatePositionActive(position.isActive);

        uint256 cachedFilledVolume = _unwindFilledVolume(positionId, position);
        _validatePositionClosureSafety(position.margin);

        // Cache position data before state changes for event emission
        uint256 cachedPositionSize = uint256(position.positionSize);
        uint256 cachedEntryPrice = uint256(position.entryPrice);
        uint256 cachedMargin = uint256(position.margin);

        // Update ALL state variables before external calls (Checks-Effects-Interactions pattern)
        _finalizePosition(
            msg.sender,
            positionId,
            position,
            cachedMargin,
            cachedPositionSize
        );

        // Emit event before any external calls (oracle call)
        emit HedgePositionClosed(
            msg.sender, 
            positionId, 
            _packPositionCloseData(0, 0, TIME_PROVIDER.currentTime()) // Placeholder values, will be updated after oracle call
        );

        // Get oracle price after ALL state changes
        uint256 currentPrice = _getValidOraclePrice();
        pnl = HedgerPoolLogicLibrary.calculatePnL(
            cachedFilledVolume,
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
    function addMargin(uint256 positionId, uint256 amount) external whenNotPaused nonReentrant {
        HedgePosition storage position = positions[positionId];
        HedgerPoolValidationLibrary.validatePositionOwner(position.hedger, msg.sender);
        HedgerPoolValidationLibrary.validatePositionActive(position.isActive);
        HedgerPoolValidationLibrary.validatePositiveAmount(amount);
        HedgerPoolValidationLibrary.validateLiquidationCooldown(lastLiquidationAttempt[msg.sender], LIQUIDATION_COOLDOWN);
        
        if (pendingLiquidations[msg.sender][positionId] > 0) {
            revert HedgerPoolErrorLibrary.PendingLiquidationCommitment();
        }

        uint256 fee = amount.percentageOf(coreParams.marginFee);
        uint256 netAmount = amount - fee;

        (uint256 newMargin, uint256 newMarginRatio) = HedgerPoolLogicLibrary.validateMarginOperation(
            uint256(position.margin), netAmount, true, coreParams.minMarginRatio, 
            uint256(position.positionSize), MAX_MARGIN
        );
        
        // Update state variables before external calls (Checks-Effects-Interactions pattern)
        position.margin = uint96(newMargin);
        hedgerBalances[msg.sender].totalMargin += uint128(netAmount);
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
    function removeMargin(uint256 positionId, uint256 amount) external whenNotPaused nonReentrant {
        HedgePosition storage position = positions[positionId];
        HedgerPoolValidationLibrary.validatePositionOwner(position.hedger, msg.sender);
        HedgerPoolValidationLibrary.validatePositionActive(position.isActive);
        HedgerPoolValidationLibrary.validatePositiveAmount(amount);

        (uint256 newMargin, uint256 newMarginRatio) = HedgerPoolLogicLibrary.validateMarginOperation(
            uint256(position.margin), amount, false, coreParams.minMarginRatio, 
            uint256(position.positionSize), MAX_MARGIN
        );
        
        position.margin = uint96(newMargin);
        hedgerBalances[msg.sender].totalMargin -= uint128(amount);
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
     * @notice Records a user mint and allocates hedger fills proportionally
     * @dev Callable only by QuantillonVault to sync hedger exposure with user activity
     * @param usdcAmount Net USDC amount that was minted into QEURO
     * @custom:security Only callable by the vault; amount must be positive
     * @custom:validation Validates the amount is greater than zero
     * @custom:state-changes Updates total filled exposure and per-position fills
     * @custom:events Emits `HedgerFillUpdated` for every position receiving fill
     * @custom:errors Reverts with `InvalidAmount`, `NoActiveHedgerLiquidity`, or `InsufficientHedgerCapacity`
     * @custom:reentrancy Not applicable (no external calls besides trusted helpers)
     * @custom:access Restricted to `QuantillonVault`
     * @custom:oracle Not applicable
     */
    function recordUserMint(uint256 usdcAmount) external onlyVault whenNotPaused {
        HedgerPoolValidationLibrary.validatePositiveAmount(usdcAmount);
        _increaseFilledVolume(usdcAmount);
    }

    /**
     * @notice Records a user redemption and releases hedger fills proportionally
     * @dev Callable only by QuantillonVault to sync hedger exposure with user activity
     * @param usdcAmount Gross USDC amount redeemed from QEURO burn
     * @custom:security Only callable by the vault; amount must be positive
     * @custom:validation Validates the amount is greater than zero
     * @custom:state-changes Reduces total filled exposure and per-position fills
     * @custom:events Emits `HedgerFillUpdated` for every position releasing fill
     * @custom:errors Reverts with `InvalidAmount` or `InsufficientHedgerCapacity`
     * @custom:reentrancy Not applicable (no external calls besides trusted helpers)
     * @custom:access Restricted to `QuantillonVault`
     * @custom:oracle Not applicable
     */
    function recordUserRedeem(uint256 usdcAmount) external onlyVault whenNotPaused {
        HedgerPoolValidationLibrary.validatePositiveAmount(usdcAmount);
        _decreaseFilledVolume(usdcAmount, 0);
    }

    function commitLiquidation(address hedger, uint256 positionId, bytes32 salt) external {
        _validateRole(LIQUIDATOR_ROLE);
        AccessControlLibrary.validateAddress(hedger);
        if (positionId == 0) revert HedgerPoolErrorLibrary.InvalidPosition();

        HedgePosition storage position = positions[positionId];
        HedgerPoolValidationLibrary.validatePositionActive(position.isActive);
        if (position.hedger != hedger) revert HedgerPoolErrorLibrary.InvalidHedger();

        bytes32 commitment = HedgerPoolLogicLibrary.generateLiquidationCommitment(
            hedger, positionId, salt, msg.sender
        );
        HedgerPoolValidationLibrary.validateCommitmentNotExists(liquidationCommitments[commitment]);

        liquidationCommitments[commitment] = block.number;
        pendingLiquidations[hedger][positionId] += 1;
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
        HedgerPoolValidationLibrary.validatePositionOwner(position.hedger, hedger);
        HedgerPoolValidationLibrary.validatePositionActive(position.isActive);

        uint256 cachedFilledVolume = _unwindFilledVolume(positionId, position);

        bytes32 commitment = HedgerPoolLogicLibrary.generateLiquidationCommitment(
            hedger, positionId, salt, msg.sender
        );
        uint256 commitmentBlock = liquidationCommitments[commitment];
        HedgerPoolValidationLibrary.validateCommitment(commitmentBlock);
        
        // Update ALL state variables before external calls (Checks-Effects-Interactions pattern)
        delete liquidationCommitments[commitment];
        _decrementPendingCommitment(hedger, positionId);

        _finalizePosition(
            hedger,
            positionId,
            position,
            position.margin,
            position.positionSize
        );
        
        // Get oracle price after ALL state changes for validation
        uint256 currentPrice = _getValidOraclePrice();
        bool liquidatable = HedgerPoolLogicLibrary.isPositionLiquidatable(
            uint256(position.margin), cachedFilledVolume, 
            uint256(position.entryPrice), currentPrice, coreParams.liquidationThreshold
        );
        
        if (!liquidatable) revert HedgerPoolErrorLibrary.PositionNotLiquidatable();

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
        HedgerBalance storage hedgerInfo = hedgerBalances[hedger];
        HedgerRewardState storage rewardState = hedgerRewards[hedger];

        (uint256 newPendingRewards, uint256 newLastRewardBlock) = HedgerPoolLogicLibrary.calculateRewardUpdate(
            uint256(hedgerInfo.totalExposure), coreParams.eurInterestRate, coreParams.usdInterestRate,
            hedgerLastRewardBlock[hedger], block.number, MAX_REWARD_PERIOD, 
            uint256(rewardState.pendingRewards)
        );
        
        rewardState.pendingRewards = uint128(newPendingRewards);
        hedgerLastRewardBlock[hedger] = newLastRewardBlock;
        
        interestDifferential = rewardState.pendingRewards;
        yieldShiftRewards = yieldShift.getHedgerPendingYield(hedger);
        totalRewards = interestDifferential + yieldShiftRewards;
        
        if (totalRewards > 0) {
            rewardState.pendingRewards = 0;
            rewardState.lastRewardClaim = uint64(TIME_PROVIDER.currentTime());
            
            if (yieldShiftRewards > 0) {
                uint256 claimedAmount = yieldShift.claimHedgerYield(hedger);
                if (claimedAmount == 0) revert HedgerPoolErrorLibrary.YieldClaimFailed();
            }
            
            usdc.safeTransfer(hedger, totalRewards);
            
            emit HedgingRewardsClaimed(
                hedger, 
                _packRewardData(interestDifferential, yieldShiftRewards, totalRewards)
            );
        }
    }

    /**
     * @notice Returns the list of currently active position IDs
     * @dev Provides a snapshot of all active hedger positions for analytics and monitoring
     * @return activePositionIds Array of active position IDs
     * @custom:security View-only helper - no state changes
     * @custom:validation No additional validation beyond internal state
     * @custom:state-changes None - view function
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query active positions
     * @custom:oracle No oracle dependencies
     */
    function getActivePositionIds() external view returns (uint256[] memory activePositionIds) {
        uint256 len = activePositions.length;
        activePositionIds = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            activePositionIds[i] = activePositions[i];
        }
    }

    /**
     * @notice Returns aggregate fill metrics across all positions
     * @dev Helps off-chain services monitor hedger capacity usage
     * @return totalHedgeExposure Current aggregate position exposure in USDC
     * @return totalMatchedExposure Current aggregate filled exposure in USDC
     * @custom:security View-only helper - no state changes
     * @custom:validation No additional validation beyond internal state
     * @custom:state-changes None - view function
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query fill metrics
     * @custom:oracle No oracle dependencies
     */
    function getFillMetrics() external view returns (uint256 totalHedgeExposure, uint256 totalMatchedExposure) {
        totalHedgeExposure = totalExposure;
        totalMatchedExposure = totalFilledExposure;
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
        if (newMinMarginRatio < 500) revert HedgerPoolErrorLibrary.ConfigValueTooLow();
        if (newLiquidationThreshold >= newMinMarginRatio) revert HedgerPoolErrorLibrary.ConfigInvalid();
        if (newMaxLeverage > 20) revert HedgerPoolErrorLibrary.ConfigValueTooHigh();
        if (newLiquidationPenalty > 1000) revert HedgerPoolErrorLibrary.ConfigValueTooHigh();

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
        if (newEurRate > 2000 || newUsdRate > 2000) revert HedgerPoolErrorLibrary.ConfigValueTooHigh();
        
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
        HedgerPoolValidationLibrary.validateFee(_entryFee, 100);
        HedgerPoolValidationLibrary.validateFee(_exitFee, 100);
        HedgerPoolValidationLibrary.validateFee(_marginFee, 50);

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
        if (position.hedger != hedger) revert HedgerPoolErrorLibrary.InvalidHedger();
        HedgerPoolValidationLibrary.validatePositionActive(position.isActive);

        _unwindFilledVolume(positionId, position);

        _finalizePosition(
            hedger,
            positionId,
            position,
            position.margin,
            position.positionSize
        );

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
        return pendingLiquidations[hedger][positionId] > 0;
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
            pendingLiquidations[hedger][positionId] = 0;
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
        uint256 commitmentBlock = liquidationCommitments[commitment];
        HedgerPoolValidationLibrary.validateCommitment(commitmentBlock);
        
        delete liquidationCommitments[commitment];
        _decrementPendingCommitment(hedger, positionId);
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
        require(_treasury != address(0), "Treasury cannot be zero address");
        AccessControlLibrary.validateAddress(_treasury);
        HedgerPoolValidationLibrary.validateTreasuryAddress(_treasury);
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
     * @notice Updates the oracle address
     * @dev Governance-only setter to allow phased wiring after minimal initialization
     * @param _oracle New oracle address
     * @custom:security Restricted to GOVERNANCE_ROLE and validates non-zero address
     * @custom:validation Ensures `_oracle` is not the zero address
     * @custom:state-changes Updates the `oracle` reference used for price checks
     * @custom:events Emits `VaultUpdated`? (no) -> None
     * @custom:errors Reverts with `InvalidAddress`
     * @custom:reentrancy Not applicable
     * @custom:access Governance-only
     * @custom:oracle Establishes new oracle dependency
     */
    function updateOracle(address _oracle) external {
        _validateRole(GOVERNANCE_ROLE);
        AccessControlLibrary.validateAddress(_oracle);
        oracle = IChainlinkOracle(_oracle);
    }

    /**
     * @notice Updates the YieldShift address
     * @dev Governance-only setter to allow phased wiring after minimal initialization
     * @param _yieldShift New YieldShift address
     * @custom:security Restricted to GOVERNANCE_ROLE and validates non-zero address
     * @custom:validation Ensures `_yieldShift` is not the zero address
     * @custom:state-changes Updates the `yieldShift` reference used for reward sync
     * @custom:events None
     * @custom:errors Reverts with `InvalidAddress`
     * @custom:reentrancy Not applicable
     * @custom:access Governance-only
     * @custom:oracle Not applicable
     */
    function updateYieldShift(address _yieldShift) external {
        _validateRole(GOVERNANCE_ROLE);
        AccessControlLibrary.validateAddress(_yieldShift);
        yieldShift = IYieldShift(_yieldShift);
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
        
        if (isWhitelistedHedger[hedger]) revert HedgerPoolErrorLibrary.AlreadyWhitelisted();
        
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
        
        if (!isWhitelistedHedger[hedger]) revert HedgerPoolErrorLibrary.NotWhitelisted();
        
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
        (bool success, bytes memory data) = address(oracle).staticcall(
            abi.encodeWithSelector(IChainlinkOracle.getEurUsdPrice.selector)
        );
        if (!success || data.length < 64) revert HedgerPoolErrorLibrary.InvalidOraclePrice();
        (uint256 price, bool isValid) = abi.decode(data, (uint256, bool));
        if (!isValid) revert HedgerPoolErrorLibrary.InvalidOraclePrice();
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
        if (!hasRole(role, msg.sender)) revert HedgerPoolErrorLibrary.NotAuthorized();
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
    /**
     * @notice Tracks a newly opened position for global fill allocation
     * @dev Stores the index of the position in `activePositions` for O(1) removals
     * @param positionId ID of the position being tracked
     * @custom:security Caller must ensure position is valid and unique
     * @custom:validation Assumes positionId is not already tracked
     * @custom:state-changes Updates `activePositionIndex` and `activePositions`
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - internal function
     * @custom:access Internal helper
     * @custom:oracle Not applicable
     */
    function _trackActivePosition(uint256 positionId) internal {
        activePositionIndex[positionId] = activePositions.length;
        activePositions.push(positionId);
    }

    /**
     * @notice Removes a position from the active tracking arrays
     * @dev Swaps-and-pops to keep the array compact while updating indices
     * @param positionId ID of the position to untrack
     * @custom:security Caller must ensure positionId is currently tracked
     * @custom:validation Assumes the active set is non-empty
     * @custom:state-changes Modifies `activePositions` and `activePositionIndex`
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - internal function
     * @custom:access Internal helper
     * @custom:oracle Not applicable
     */
    function _untrackActivePosition(uint256 positionId) internal {
        uint256 index = activePositionIndex[positionId];
        uint256 lastIndex = activePositions.length - 1;
        if (index != lastIndex) {
            uint256 lastId = activePositions[lastIndex];
            activePositions[index] = lastId;
            activePositionIndex[lastId] = index;
        }
        activePositions.pop();
        delete activePositionIndex[positionId];
    }

    function _finalizePosition(
        address hedger,
        uint256 positionId,
        HedgePosition storage position,
        uint256 marginDelta,
        uint256 exposureDelta
    ) internal {
        HedgerBalance storage hedgerInfo = hedgerBalances[hedger];
        bool wasActive = hedgerInfo.totalExposure > 0;

        hedgerInfo.totalMargin -= uint128(marginDelta);
        hedgerInfo.totalExposure -= uint128(exposureDelta);

        totalMargin -= marginDelta;
        totalExposure -= exposureDelta;

        position.isActive = false;
        _untrackActivePosition(positionId);

        uint256 newCount = --hedgerPositionCounts[hedger];
        if (wasActive && hedgerInfo.totalExposure == 0 && newCount == 0) {
            activeHedgers--;
        }
    }

    function _unwindFilledVolume(uint256 positionId, HedgePosition storage position) internal returns (uint256 freedVolume) {
        uint256 cachedFilledVolume = uint256(position.filledVolume);
        if (cachedFilledVolume == 0) {
            return 0;
        }

        position.filledVolume = 0;
        emit HedgerFillUpdated(positionId, cachedFilledVolume, 0);
        if (totalFilledExposure < cachedFilledVolume) revert HedgerPoolErrorLibrary.InsufficientHedgerCapacity();
        totalFilledExposure -= cachedFilledVolume;
        _increaseFilledVolume(cachedFilledVolume, positionId);
        return cachedFilledVolume;
    }

    function _decrementPendingCommitment(address hedger, uint256 positionId) internal {
        uint32 count = pendingLiquidations[hedger][positionId];
        if (count > 0) {
            unchecked {
                pendingLiquidations[hedger][positionId] = count - 1;
            }
        }
    }

    /**
     * @notice Convenience overload to increase fills without skipping any position
     * @dev Forwards to the full allocator with a zero skip identifier
     * @param usdcAmount Amount of USDC exposure to allocate
     * @custom:security Caller must ensure `usdcAmount` is sanitized
     * @custom:validation No additional validation beyond delegated call
     * @custom:state-changes See `_increaseFilledVolume(uint256,uint256)`
     * @custom:events Emits `HedgerFillUpdated` via delegated call
     * @custom:errors See delegated allocator
     * @custom:reentrancy Not applicable
     * @custom:access Internal helper
     * @custom:oracle Not applicable
     */
    function _increaseFilledVolume(uint256 usdcAmount) internal {
        _increaseFilledVolume(usdcAmount, 0);
    }

    /**
     * @notice Allocates user mint exposure across active hedger positions
     * @dev Distributes `usdcAmount` proportionally to available capacity
     * @param usdcAmount Amount of USDC exposure to allocate
     * @param skipPositionId Position ID to exclude (e.g., the exiting position)
     * @custom:security Caller must ensure hedger sets are consistent before invocation
     * @custom:validation Validates liquidity availability and capacity before allocation
     * @custom:state-changes Updates `filledVolume` per position and `totalFilledExposure`
     * @custom:events Emits `HedgerFillUpdated` for every adjusted position
     * @custom:errors Reverts if capacity is insufficient or liquidity is absent
     * @custom:reentrancy Not applicable - internal function
     * @custom:access Internal helper
     * @custom:oracle Not applicable
     */
    function _increaseFilledVolume(uint256 usdcAmount, uint256 skipPositionId) internal {
        if (usdcAmount == 0) {
            return;
        }
        if (activePositions.length == 0) revert HedgerPoolErrorLibrary.NoActiveHedgerLiquidity();

        uint256 availableCapacity = totalExposure - totalFilledExposure;
        if (skipPositionId != 0) {
            HedgePosition storage skipPosition = positions[skipPositionId];
            uint256 skipCapacity = uint256(skipPosition.positionSize) - uint256(skipPosition.filledVolume);
            if (availableCapacity <= skipCapacity) {
                availableCapacity = 0;
            } else {
                availableCapacity -= skipCapacity;
            }
        }

        if (availableCapacity < usdcAmount) revert HedgerPoolErrorLibrary.InsufficientHedgerCapacity();
        if (availableCapacity == 0) revert HedgerPoolErrorLibrary.NoActiveHedgerLiquidity();

        uint256 allocated = 0;
        uint256 len = activePositions.length;
        for (uint256 i = 0; i < len; i++) {
            uint256 positionId = activePositions[i];
            if (positionId == skipPositionId) continue;
            HedgePosition storage position = positions[positionId];
            uint256 capacity = uint256(position.positionSize) - uint256(position.filledVolume);
            if (capacity == 0) continue;
            uint256 share = capacity.mulDiv(usdcAmount, availableCapacity);
            if (share > capacity) {
                share = capacity;
            }
            if (share == 0) continue;
            _applyFillChange(positionId, position, share, true);
            allocated += share;
        }

        uint256 remaining = usdcAmount - allocated;
        if (remaining > 0) {
            for (uint256 i = 0; i < len && remaining > 0; i++) {
                uint256 positionId = activePositions[i];
                if (positionId == skipPositionId) continue;
                HedgePosition storage position = positions[positionId];
                uint256 capacity = uint256(position.positionSize) - uint256(position.filledVolume);
                if (capacity == 0) continue;
                uint256 delta = capacity >= remaining ? remaining : capacity;
                if (delta == 0) continue;
                _applyFillChange(positionId, position, delta, true);
                remaining -= delta;
            }
        }

        if (remaining != 0) revert HedgerPoolErrorLibrary.InsufficientHedgerCapacity();

        totalFilledExposure += usdcAmount;
    }

    /**
     * @notice Releases exposure across hedger positions following a user redeem
     * @dev Proportionally decreases fills (optionally skipping one position)
     * @param usdcAmount Amount of USDC exposure to release
     * @param skipPositionId Position ID to exclude from the release cycle
     * @custom:security Caller must ensure inputs keep invariants consistent
     * @custom:validation Ensures sufficient filled exposure exists for release
     * @custom:state-changes Decreases per-position `filledVolume` and `totalFilledExposure`
     * @custom:events Emits `HedgerFillUpdated` for every adjusted position
     * @custom:errors Reverts if exposure is insufficient or no active liquidity is present
     * @custom:reentrancy Not applicable - internal function
     * @custom:access Internal helper
     * @custom:oracle Not applicable
     */
    function _decreaseFilledVolume(uint256 usdcAmount, uint256 skipPositionId) internal {
        if (usdcAmount == 0) {
            return;
        }
        if (totalFilledExposure < usdcAmount) revert HedgerPoolErrorLibrary.InsufficientHedgerCapacity();

        uint256 distributable = totalFilledExposure;
        if (skipPositionId != 0) {
            distributable -= positions[skipPositionId].filledVolume;
        }
        if (distributable < usdcAmount) revert HedgerPoolErrorLibrary.InsufficientHedgerCapacity();
        if (distributable == 0) revert HedgerPoolErrorLibrary.NoActiveHedgerLiquidity();

        uint256 released = 0;
        uint256 len = activePositions.length;
        for (uint256 i = 0; i < len; i++) {
            uint256 positionId = activePositions[i];
            if (positionId == skipPositionId) continue;
            HedgePosition storage position = positions[positionId];
            uint256 filled = uint256(position.filledVolume);
            if (filled == 0) continue;
            uint256 share = filled.mulDiv(usdcAmount, distributable);
            if (share > filled) {
                share = filled;
            }
            if (share == 0) continue;
            _applyFillChange(positionId, position, share, false);
            released += share;
        }

        uint256 remaining = usdcAmount - released;
        if (remaining > 0) {
            for (uint256 i = 0; i < len && remaining > 0; i++) {
                uint256 positionId = activePositions[i];
                if (positionId == skipPositionId) continue;
                HedgePosition storage position = positions[positionId];
                uint256 filled = uint256(position.filledVolume);
                if (filled == 0) continue;
                uint256 delta = filled >= remaining ? remaining : filled;
                if (delta == 0) continue;
                _applyFillChange(positionId, position, delta, false);
                remaining -= delta;
            }
        }

        if (remaining != 0) revert HedgerPoolErrorLibrary.InsufficientHedgerCapacity();
        totalFilledExposure -= usdcAmount;
    }

    /**
     * @notice Applies a fill delta to a single position and emits an event
     * @dev Handles both increases and decreases while enforcing capacity constraints
     * @param positionId ID of the position being updated
     * @param position Storage pointer to the position struct
     * @param delta Amount of fill change to apply
     * @param increase True to increase fill, false to decrease
     * @custom:security Caller must ensure the storage reference is valid
     * @custom:validation Validates capacity or availability before applying the delta
     * @custom:state-changes Updates the position’s `filledVolume`
     * @custom:events Emits `HedgerFillUpdated`
     * @custom:errors Reverts with `InsufficientHedgerCapacity` on invalid operations
     * @custom:reentrancy Not applicable - internal function
     * @custom:access Internal helper
     * @custom:oracle Not applicable
     */
    function _applyFillChange(
        uint256 positionId,
        HedgePosition storage position,
        uint256 delta,
        bool increase
    ) internal {
        if (delta == 0) return;
        uint256 previous = position.filledVolume;
        uint256 updated;
        if (increase) {
            updated = previous + delta;
            if (updated > position.positionSize) revert HedgerPoolErrorLibrary.InsufficientHedgerCapacity();
            position.filledVolume = uint96(updated);
        } else {
            if (previous < delta) revert HedgerPoolErrorLibrary.InsufficientHedgerCapacity();
            updated = previous - delta;
            position.filledVolume = uint96(updated);
        }
        emit HedgerFillUpdated(positionId, previous, updated);
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
        return keccak256(abi.encode(positionSize, margin, leverage, entryPrice));
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
        return keccak256(abi.encode(exitPrice, pnl, timestamp));
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
        return keccak256(abi.encode(marginAmount, newMarginRatio, isAdded));
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
        return keccak256(abi.encode(liquidationReward, remainingMargin));
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
        return keccak256(abi.encode(interestDifferential, yieldShiftRewards, totalRewards));
    }

    function _validatePositionClosureSafety(uint256 positionMargin) internal view {
        if (address(vault) == address(0)) {
            return;
        }

        (bool isCollateralized, uint256 reportedMargin) = vault.isProtocolCollateralized();
        if (!isCollateralized || reportedMargin <= positionMargin) {
            revert HedgerPoolErrorLibrary.PositionClosureRestricted();
        }
    }
}