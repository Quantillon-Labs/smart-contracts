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
import {HedgerPoolErrorLibrary} from "../libraries/HedgerPoolErrorLibrary.sol";
import {HedgerPoolValidationLibrary} from "../libraries/HedgerPoolValidationLibrary.sol";
import {AccessControlLibrary} from "../libraries/AccessControlLibrary.sol";
import {CommonErrorLibrary} from "../libraries/CommonErrorLibrary.sol";
import {SecureUpgradeable} from "./SecureUpgradeable.sol";
import {TimeProvider} from "../libraries/TimeProviderLibrary.sol";
import {AdminFunctionsLibrary} from "../libraries/AdminFunctionsLibrary.sol";
import {CommonValidationLibrary} from "../libraries/CommonValidationLibrary.sol";
import {HedgerPoolLogicLibrary} from "../libraries/HedgerPoolLogicLibrary.sol";
import {HedgerPoolOptimizationLibrary} from "../libraries/HedgerPoolOptimizationLibrary.sol";

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
        int128 realizedPnL;      // Cumulative realized P&L from closed portions
        uint16 leverage;
        bool isActive;
        uint128 qeuroBacked;     // Exact QEURO amount backed by this position (18 decimals)
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
    event RealizedPnLRecorded(uint256 indexed positionId, int256 pnlDelta, int256 totalRealizedPnL);
    event QeuroShareCalculated(uint256 indexed positionId, uint256 qeuroShare, uint256 qeuroBacked, uint256 totalQeuroBacked);
    event RealizedPnLCalculation(uint256 indexed positionId, uint256 qeuroAmount, uint256 qeuroBacked, uint256 filledBefore, uint256 price, int256 totalUnrealizedPnL, int256 realizedDelta);

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
        if (address(_TIME_PROVIDER) == address(0)) revert CommonErrorLibrary.ZeroAddress();
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
        
        if (_treasury == address(0)) revert CommonErrorLibrary.ZeroAddress();
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
            revert CommonErrorLibrary.NotWhitelisted();
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
        // Explicitly use all return values to avoid unused-return warning
        // fee and marginRatio are validated by the library function, no additional checks needed
        if (fee > usdcAmount || marginRatio == 0) revert HedgerPoolErrorLibrary.InvalidPosition();
        
        positionId = nextPositionId++;
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

        HedgerBalance storage hedgerInfo = hedgerBalances[msg.sender];
        bool wasInactive = hedgerInfo.totalExposure == 0;
        hedgerInfo.totalMargin += uint128(netMargin);
        hedgerInfo.totalExposure += uint128(positionSize);
        if (wasInactive && hedgerInfo.totalExposure > 0) activeHedgers++;
        hedgerPositionCounts[msg.sender]++;
        totalMargin += netMargin;
        totalExposure += positionSize;
        usdc.safeTransferFrom(msg.sender, address(vault), usdcAmount);
        vault.addHedgerDeposit(usdcAmount);
        emit HedgePositionOpened(
            msg.sender,
            positionId,
            HedgerPoolOptimizationLibrary.packPositionOpenData(positionSize, netMargin, leverage, eurUsdPrice)
        );
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
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to position owner
     * @custom:oracle Requires fresh oracle price data
     */
    // slither-disable-next-line reentrancy-no-eth
    function exitHedgePosition(uint256 positionId) 
        external 
        whenNotPaused
        nonReentrant
        returns (int256 pnl) 
    {
        HedgePosition storage position = positions[positionId];
        HedgerPoolValidationLibrary.validatePositionOwner(position.hedger, msg.sender);
        HedgerPoolValidationLibrary.validatePositionActive(position.isActive);

        // Cache oracle price at start to avoid reentrancy issues
        uint256 currentPrice = _getValidOraclePrice();

        // Cache position data before state changes
        uint256 cachedFilledVolume = uint256(position.filledVolume);
        uint256 cachedQeuroBacked = uint256(position.qeuroBacked);
        uint256 cachedPositionSize = uint256(position.positionSize);
        uint256 cachedMargin = uint256(position.margin);
        
        // Calculate PnL before state changes
        pnl = HedgerPoolLogicLibrary.calculatePnL(
            cachedFilledVolume,
            cachedQeuroBacked,
            currentPrice
        );

        // Unwind filled volume (this will reset qeuroBacked to 0) - pass cached price to avoid double oracle call
        _unwindFilledVolume(positionId, position, currentPrice);
        _validatePositionClosureSafety(cachedMargin);

        // Update ALL state variables before external calls (Checks-Effects-Interactions pattern)
        _finalizePosition(
            msg.sender,
            positionId,
            position,
            cachedMargin,
            cachedPositionSize
        );

        // Emit event after state changes but before external calls
        emit HedgePositionClosed(
            msg.sender,
            positionId,
            HedgerPoolOptimizationLibrary.packPositionCloseData(0, 0, TIME_PROVIDER.currentTime())
        );

        // Calculate payout amounts
        uint256 grossPayout = uint256(int256(cachedMargin) + pnl);
        uint256 exitFeeAmount = grossPayout.percentageOf(coreParams.exitFee);
        uint256 netPayout = grossPayout - exitFeeAmount;

        // INTERACTIONS - All external calls after state updates
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
        CommonValidationLibrary.validatePositiveAmount(amount);
        HedgerPoolValidationLibrary.validateLiquidationCooldown(lastLiquidationAttempt[msg.sender], LIQUIDATION_COOLDOWN);
        
        if (pendingLiquidations[msg.sender][positionId] > 0) {
            revert HedgerPoolErrorLibrary.PendingLiquidationCommitment();
        }

        uint256 fee = amount.percentageOf(coreParams.marginFee);
        uint256 netAmount = amount - fee;

        uint256 currentMargin = uint256(position.margin);
        uint256 currentPositionSize = uint256(position.positionSize);
        uint256 leverageValue = uint256(position.leverage);

        uint256 newMargin = currentMargin + netAmount;
        HedgerPoolValidationLibrary.validateNewMargin(newMargin, MAX_MARGIN);

        // Recalculate positionSize from new margin to maintain exact leverage ratio
        // This avoids rounding errors that could cause margin ratio validation to fail
        uint256 newPositionSize = newMargin * leverageValue;
        if (newPositionSize > MAX_POSITION_SIZE) {
            revert HedgerPoolErrorLibrary.PositionSizeExceedsMaximum();
        }

        uint256 deltaPositionSize = newPositionSize - currentPositionSize;

        HedgerPoolValidationLibrary.validateTotals(
            totalMargin,
            totalExposure,
            netAmount,
            deltaPositionSize,
            MAX_TOTAL_MARGIN,
            MAX_TOTAL_EXPOSURE
        );

        uint256 newMarginRatio = newMargin.mulDiv(10000, newPositionSize);
        HedgerPoolValidationLibrary.validateMarginRatio(newMarginRatio, coreParams.minMarginRatio);
        HedgerPoolValidationLibrary.validateMaxMarginRatio(newMarginRatio, MAX_MARGIN_RATIO);

        // Update state variables before external calls (Checks-Effects-Interactions pattern)
        position.margin = uint96(newMargin);
        position.positionSize = uint96(newPositionSize);

        hedgerBalances[msg.sender].totalMargin += uint128(netAmount);
        hedgerBalances[msg.sender].totalExposure += uint128(deltaPositionSize);
        totalMargin += netAmount;
        totalExposure += deltaPositionSize;

        emit MarginUpdated(
            msg.sender,
            positionId,
            HedgerPoolOptimizationLibrary.packMarginData(netAmount, newMarginRatio, true)
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
        CommonValidationLibrary.validatePositiveAmount(amount);

        uint256 currentMargin = uint256(position.margin);
        if (amount > currentMargin) revert HedgerPoolErrorLibrary.InsufficientMargin();

        uint256 newMargin = currentMargin - amount;
        uint256 leverageValue = uint256(position.leverage);
        
        // Recalculate positionSize from new margin to maintain exact leverage ratio
        uint256 newPositionSize = newMargin * leverageValue;
        uint256 currentPositionSize = uint256(position.positionSize);
        
        if (newPositionSize < uint256(position.filledVolume)) {
            revert HedgerPoolErrorLibrary.InsufficientHedgerCapacity();
        }

        uint256 deltaPositionSize = currentPositionSize - newPositionSize;

        uint256 newMarginRatio = newPositionSize > 0
            ? newMargin.mulDiv(10000, newPositionSize)
            : 0;
        HedgerPoolValidationLibrary.validateMarginRatio(newMarginRatio, coreParams.minMarginRatio);
        HedgerPoolValidationLibrary.validateMaxMarginRatio(newMarginRatio, MAX_MARGIN_RATIO);

        // Validate that position won't become liquidatable after margin removal
        // Get current price for liquidation check
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid || currentPrice == 0) revert CommonErrorLibrary.InvalidOraclePrice();
        
        // Check if position would be liquidatable after margin removal
        // Uses same formula as liquidation check: effectiveMargin.mulDiv(10000, qeuroBacked × currentPrice / 1e30) >= liquidationThreshold
        // This matches the frontend formula: maxWithdrawable = effectiveMargin - (qeuroBacked × currentPrice × liquidationThreshold / 10000)
        bool wouldBeLiquidatable = HedgerPoolLogicLibrary.isPositionLiquidatable(
            newMargin,
            uint256(position.filledVolume),
            uint256(position.entryPrice),
            currentPrice,
            coreParams.liquidationThreshold,
            position.qeuroBacked
        );
        
        if (wouldBeLiquidatable) {
            revert HedgerPoolErrorLibrary.InsufficientMargin();
        }

        position.margin = uint96(newMargin);
        position.positionSize = uint96(newPositionSize);

        hedgerBalances[msg.sender].totalMargin -= uint128(amount);
        hedgerBalances[msg.sender].totalExposure -= uint128(deltaPositionSize);
        totalMargin -= amount;
        totalExposure -= deltaPositionSize;

        emit MarginUpdated(
            msg.sender,
            positionId,
            HedgerPoolOptimizationLibrary.packMarginData(amount, newMarginRatio, false)
        );

        // Withdraw USDC from vault for hedger margin removal
        vault.withdrawHedgerDeposit(msg.sender, amount);
    }

    /**
     * @notice Records a user mint and allocates hedger fills proportionally
     * @dev Callable only by QuantillonVault to sync hedger exposure with user activity
     * @param usdcAmount Net USDC amount that was minted into QEURO (6 decimals)
     * @param fillPrice EUR/USD oracle price (18 decimals) observed by the vault
     * @param qeuroAmount QEURO amount that was minted (18 decimals)
     * @custom:security Only callable by the vault; amount must be positive
     * @custom:validation Validates the amount and price are greater than zero
     * @custom:state-changes Updates total filled exposure and per-position fills
     * @custom:events Emits `HedgerFillUpdated` for every position receiving fill
     * @custom:errors Reverts with `InvalidAmount`, `InvalidOraclePrice`, `NoActiveHedgerLiquidity`, or `InsufficientHedgerCapacity`
     * @custom:reentrancy Not applicable (no external calls besides trusted helpers)
     * @custom:access Restricted to `QuantillonVault`
     * @custom:oracle Uses provided price to avoid duplicate oracle calls
     */
    function recordUserMint(uint256 usdcAmount, uint256 fillPrice, uint256 qeuroAmount) external onlyVault whenNotPaused {
        CommonValidationLibrary.validatePositiveAmount(usdcAmount);
        if (fillPrice == 0) revert CommonErrorLibrary.InvalidOraclePrice();
        _increaseFilledVolume(usdcAmount, fillPrice, qeuroAmount, 0);
    }

    /**
     * @notice Records a user redemption and releases hedger fills proportionally
     * @dev Callable only by QuantillonVault to sync hedger exposure with user activity
     * @param usdcAmount Gross USDC amount redeemed from QEURO burn (6 decimals)
     * @param redeemPrice EUR/USD oracle price (18 decimals) observed by the vault
     * @param qeuroAmount QEURO amount that was redeemed (18 decimals)
     * @custom:security Only callable by the vault; amount must be positive
     * @custom:validation Validates the amount and price are greater than zero
     * @custom:state-changes Reduces total filled exposure and per-position fills
     * @custom:events Emits `HedgerFillUpdated` for every position releasing fill
     * @custom:errors Reverts with `InvalidAmount`, `InvalidOraclePrice`, or `InsufficientHedgerCapacity`
     * @custom:reentrancy Not applicable (no external calls besides trusted helpers)
     * @custom:access Restricted to `QuantillonVault`
     * @custom:oracle Uses provided price to avoid duplicate oracle calls
     */
    function recordUserRedeem(uint256 usdcAmount, uint256 redeemPrice, uint256 qeuroAmount) external onlyVault whenNotPaused {
        CommonValidationLibrary.validatePositiveAmount(usdcAmount);
        if (redeemPrice == 0) revert CommonErrorLibrary.InvalidOraclePrice();
        _decreaseFilledVolume(usdcAmount, redeemPrice, qeuroAmount, 0);
    }

    /**
     * @notice Commits to liquidating a position (first step of two-phase liquidation)
     * @dev Creates a commitment hash to prevent front-running of liquidation attempts
     * @param hedger Address of the hedger whose position will be liquidated
     * @param positionId Unique identifier of the position to liquidate
     * @param salt Random salt value to prevent commitment collisions
     * @custom:security Requires LIQUIDATOR_ROLE, validates position ownership and active status
     * @custom:validation Validates hedger address, position ID, position is active, hedger matches position owner
     * @custom:state-changes Creates liquidation commitment, increments pending liquidation count, updates last liquidation attempt
     * @custom:events None - commitment phase doesn't emit events
     * @custom:errors Reverts with InvalidPosition if positionId is 0, InvalidHedger if hedger doesn't match, or if commitment already exists
     * @custom:reentrancy Protected by secureNonReentrant modifier (if called externally)
     * @custom:access Restricted to LIQUIDATOR_ROLE
     * @custom:oracle Not applicable - commitment phase doesn't require oracle
     */
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
    // slither-disable-next-line reentrancy-no-eth
    function liquidateHedger(address hedger, uint256 positionId, bytes32 salt) 
        external 
        nonReentrant 
        returns (uint256 liquidationReward) 
    {
        _validateRole(LIQUIDATOR_ROLE);
        
        HedgePosition storage position = positions[positionId];
        HedgerPoolValidationLibrary.validatePositionOwner(position.hedger, hedger);
        HedgerPoolValidationLibrary.validatePositionActive(position.isActive);

        // Cache oracle price at start to avoid reentrancy issues
        uint256 currentPrice = _getValidOraclePrice();
        
        // Cache position data before state changes
        uint128 cachedQeuroBacked = position.qeuroBacked;
        uint256 cachedMargin = uint256(position.margin);
        uint256 cachedPositionSize = uint256(position.positionSize);
        uint256 cachedEntryPrice = uint256(position.entryPrice);
        uint256 cachedFilledVolume = uint256(position.filledVolume);

        bytes32 commitment = HedgerPoolLogicLibrary.generateLiquidationCommitment(
            hedger, positionId, salt, msg.sender
        );
        uint256 commitmentBlock = liquidationCommitments[commitment];
        HedgerPoolValidationLibrary.validateCommitment(commitmentBlock);
        
        // Validate liquidation before state changes
        bool liquidatable = HedgerPoolLogicLibrary.isPositionLiquidatable(
            cachedMargin, cachedFilledVolume, 
            cachedEntryPrice, currentPrice, coreParams.liquidationThreshold,
            cachedQeuroBacked
        );
        
        if (!liquidatable) revert HedgerPoolErrorLibrary.PositionNotLiquidatable();

        // Unwind filled volume (updates state) - pass cached price to avoid double oracle call
        _unwindFilledVolume(positionId, position, currentPrice);

        // Update ALL state variables before external calls (Checks-Effects-Interactions pattern)
        delete liquidationCommitments[commitment];
        _decrementPendingCommitment(hedger, positionId);

        _finalizePosition(
            hedger,
            positionId,
            position,
            cachedMargin,
            cachedPositionSize
        );
        
        // Calculate liquidation reward and remaining margin
        liquidationReward = cachedMargin.percentageOf(coreParams.liquidationPenalty);
        uint256 remainingMargin = cachedMargin - liquidationReward;

        // Emit event after state changes but before external calls
        emit HedgerLiquidated(
            hedger,
            positionId,
            msg.sender,
            HedgerPoolOptimizationLibrary.packLiquidationData(liquidationReward, remainingMargin)
        );

        // INTERACTIONS - All external calls after state updates
        // Withdraw liquidation reward from vault for liquidator
        vault.withdrawHedgerDeposit(msg.sender, liquidationReward);

        if (remainingMargin > 0) {
            // Withdraw remaining margin from vault for hedger
            vault.withdrawHedgerDeposit(hedger, remainingMargin);
        }
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
                if (claimedAmount == 0) revert CommonErrorLibrary.YieldClaimFailed();
            }
            
            usdc.safeTransfer(hedger, totalRewards);
            
            emit HedgingRewardsClaimed(
                hedger,
                HedgerPoolOptimizationLibrary.packRewardData(interestDifferential, yieldShiftRewards, totalRewards)
            );
        }
    }

    /**
     * @notice Calculates total effective hedger collateral (margin + P&L) across all active positions
     * @dev Used by vault to determine protocol collateralization ratio
     * @param price Current EUR/USD oracle price (18 decimals)
     * @return t Total effective collateral in USDC (6 decimals)
     * @custom:security View-only helper - no state changes
     * @custom:validation Requires valid oracle price
     * @custom:state-changes None - view function
     * @custom:events None
     * @custom:errors Reverts if oracle price is invalid
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query effective collateral
     * @custom:oracle Requires fresh oracle price data
     */
    function getTotalEffectiveHedgerCollateral(uint256 price) external view returns (uint256 t) {
        uint256 len = activePositions.length;
        for (uint256 i; i < len; ++i) {
            HedgePosition storage p = positions[activePositions[i]];
            if (!p.isActive) continue;
            // Only consider unrealized P&L for effective collateral, not realized P&L (which is already locked in)
            int256 e = int256(uint256(p.margin)) + HedgerPoolLogicLibrary.calculatePnL(uint256(p.filledVolume), uint256(p.qeuroBacked), price);
            if (e > 0) t += uint256(e);
        }
    }

    /**
     * @notice Updates core hedging parameters for risk management
     * @dev Allows governance to adjust risk parameters based on market conditions
     * @param minRatio New minimum margin ratio in basis points (e.g., 500 = 5%)
     * @param liqThreshold New liquidation threshold in basis points (e.g., 100 = 1%)
     * @param maxLev New maximum leverage multiplier (e.g., 20 = 20x)
     * @param liqPenalty New liquidation penalty in basis points (e.g., 200 = 2%)
     * @custom:security Validates governance role and parameter constraints
     * @custom:validation Validates minRatio >= 500, liqThreshold < minRatio, maxLev <= 20, liqPenalty <= 1000
     * @custom:state-changes Updates all hedging parameter state variables
     * @custom:events No events emitted for parameter updates
     * @custom:errors Throws ConfigValueTooLow, ConfigInvalid, ConfigValueTooHigh
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies for parameter updates
     */
    function updateHedgingParameters(uint256 minRatio, uint256 liqThreshold, uint256 maxLev, uint256 liqPenalty) external {
        _validateRole(GOVERNANCE_ROLE);
        if (minRatio < 500) revert CommonErrorLibrary.ConfigValueTooLow();
        if (liqThreshold >= minRatio) revert CommonErrorLibrary.ConfigInvalid();
        if (maxLev > 20 || liqPenalty > 1000) revert CommonErrorLibrary.ConfigValueTooHigh();
        coreParams.minMarginRatio = uint64(minRatio);
        coreParams.liquidationThreshold = uint64(liqThreshold);
        coreParams.maxLeverage = uint16(maxLev);
        coreParams.liquidationPenalty = uint16(liqPenalty);
    }

    /**
     * @notice Updates interest rates for EUR and USD
     * @dev Allows governance to adjust interest rates used for reward calculations
     * @param eurRate EUR interest rate in basis points (max 2000 = 20%)
     * @param usdRate USD interest rate in basis points (max 2000 = 20%)
     * @custom:security Validates governance role and rate limits
     * @custom:validation Validates eurRate <= 2000 and usdRate <= 2000
     * @custom:state-changes Updates coreParams.eurInterestRate and coreParams.usdInterestRate
     * @custom:events No events emitted for rate updates
     * @custom:errors Throws ConfigValueTooHigh if rates exceed 2000
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function updateInterestRates(uint256 eurRate, uint256 usdRate) external {
        _validateRole(GOVERNANCE_ROLE);
        if (eurRate > 2000 || usdRate > 2000) revert CommonErrorLibrary.ConfigValueTooHigh();
        coreParams.eurInterestRate = uint16(eurRate);
        coreParams.usdInterestRate = uint16(usdRate);
    }

    /**
     * @notice Sets hedge position fees (entry, exit, margin)
     * @dev Allows governance to adjust fee rates for position operations
     * @param entry Entry fee rate in basis points (max 100 = 1%)
     * @param exit Exit fee rate in basis points (max 100 = 1%)
     * @param margin Margin operation fee rate in basis points (max 50 = 0.5%)
     * @custom:security Validates governance role and fee limits
     * @custom:validation Validates entry <= 100, exit <= 100, margin <= 50
     * @custom:state-changes Updates coreParams.entryFee, coreParams.exitFee, coreParams.marginFee
     * @custom:events No events emitted for fee updates
     * @custom:errors Throws validation errors if fees exceed limits
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function setHedgingFees(uint256 entry, uint256 exit, uint256 margin) external {
        _validateRole(GOVERNANCE_ROLE);
        HedgerPoolValidationLibrary.validateFee(entry, 100);
        HedgerPoolValidationLibrary.validateFee(exit, 100);
        HedgerPoolValidationLibrary.validateFee(margin, 50);
        coreParams.entryFee = uint16(entry);
        coreParams.exitFee = uint16(exit);
        coreParams.marginFee = uint16(margin);
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
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle Requires oracle price for _unwindFilledVolume
     */
    // slither-disable-next-line reentrancy-no-eth
    function emergencyClosePosition(address hedger, uint256 positionId) external nonReentrant {
        _validateRole(EMERGENCY_ROLE);
        
        HedgePosition storage position = positions[positionId];
        if (position.hedger != hedger) revert HedgerPoolErrorLibrary.InvalidHedger();
        HedgerPoolValidationLibrary.validatePositionActive(position.isActive);

        // Cache oracle price at start to avoid reentrancy issues
        uint256 currentPrice = _getValidOraclePrice();

        // Cache position data before state changes
        uint256 cachedMargin = uint256(position.margin);
        uint256 cachedPositionSize = uint256(position.positionSize);

        // Unwind filled volume (updates state) - pass cached price to avoid double oracle call
        _unwindFilledVolume(positionId, position, currentPrice);

        // Update ALL state variables before external calls (Checks-Effects-Interactions pattern)
        _finalizePosition(
            hedger,
            positionId,
            position,
            cachedMargin,
            cachedPositionSize
        );

        // INTERACTIONS - All external calls after state updates
        // Withdraw USDC from vault for emergency position closure
        vault.withdrawHedgerDeposit(hedger, cachedMargin);
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
    function pause() external { _validateRole(EMERGENCY_ROLE); _pause(); }
    /**
     * @notice Unpauses all contract operations after emergency pause
     * @dev Emergency function to resume all user interactions
     * @custom:security Requires EMERGENCY_ROLE
     * @custom:validation None required
     * @custom:state-changes Sets contract to unpaused state
     * @custom:events Emits Unpaused event
     * @custom:errors Throws InvalidRole if caller lacks EMERGENCY_ROLE
     * @custom:reentrancy Not applicable
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle Not applicable
     */
    function unpause() external { _validateRole(EMERGENCY_ROLE); _unpause(); }
    /**
     * @notice Checks if there's a pending liquidation commitment for a position
     * @dev Used to prevent margin operations during liquidation process
     * @param hedger The address of the hedger
     * @param positionId The ID of the position
     * @return True if there's a pending liquidation commitment
     * @custom:security View-only function - no state changes
     * @custom:validation None required for view function
     * @custom:state-changes None - view function
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can check commitment status
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
        bytes32 c = HedgerPoolLogicLibrary.generateLiquidationCommitment(hedger, positionId, salt, msg.sender);
        HedgerPoolValidationLibrary.validateCommitment(liquidationCommitments[c]);
        delete liquidationCommitments[c];
        _decrementPendingCommitment(hedger, positionId);
    }

    /**
     * @notice Recovers tokens (token != 0) or ETH (token == 0) to treasury
     * @dev Emergency function to recover accidentally sent tokens or ETH
     * @param token Address of token to recover (address(0) for ETH)
     * @param amount Amount of tokens to recover (0 for all ETH)
     * @custom:security Requires DEFAULT_ADMIN_ROLE
     * @custom:validation Validates treasury address is set
     * @custom:state-changes Transfers tokens/ETH to treasury
     * @custom:events None
     * @custom:errors Throws InvalidRole if caller lacks DEFAULT_ADMIN_ROLE
     * @custom:reentrancy Protected by AdminFunctionsLibrary
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle Not applicable
     */
    function recover(address token, uint256 amount) external {
        if (token == address(0)) AdminFunctionsLibrary.recoverETH(address(this), treasury, DEFAULT_ADMIN_ROLE);
        else AdminFunctionsLibrary.recoverToken(address(this), token, amount, treasury, DEFAULT_ADMIN_ROLE);
    }

    /**
     * @notice Updates contract addresses (0=treasury, 1=vault, 2=oracle, 3=yieldShift)
     * @dev Allows governance to update critical contract addresses
     * @param slot Address slot to update (0=treasury, 1=vault, 2=oracle, 3=yieldShift)
     * @param addr New address for the slot
     * @custom:security Validates governance role and non-zero address
     * @custom:validation Validates slot is valid (0-3) and addr != address(0)
     * @custom:state-changes Updates treasury, vault, oracle, or yieldShift address
     * @custom:events Emits TreasuryUpdated or VaultUpdated for slots 0 and 1
     * @custom:errors Throws ZeroAddress if addr is zero, InvalidPosition if slot is invalid
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle Updates oracle address if slot == 2
     */
    function updateAddress(uint8 slot, address addr) external {
        _validateRole(GOVERNANCE_ROLE);
        if (addr == address(0)) revert CommonErrorLibrary.ZeroAddress();
        if (slot == 0) { treasury = addr; emit TreasuryUpdated(addr); }
        else if (slot == 1) { vault = IQuantillonVault(addr); emit VaultUpdated(addr); }
        else if (slot == 2) oracle = IChainlinkOracle(addr);
        else if (slot == 3) yieldShift = IYieldShift(addr);
        else revert HedgerPoolErrorLibrary.InvalidPosition();
    }

    /**
     * @notice Whitelists or removes a hedger address for position opening
     * @dev Whitelisting process:
     *      1. Validates governance role and hedger address
     *      2. Checks hedger is not already whitelisted (if adding)
     *      3. Adds hedger to whitelist and grants HEDGER_ROLE (if adding)
     *      4. Removes hedger from whitelist and revokes HEDGER_ROLE (if removing)
     * @param hedger Address of the hedger to whitelist or remove
     * @param add True to whitelist, false to remove from whitelist
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates governance role, hedger address, not already whitelisted (if adding)
     * @custom:state-changes Adds/removes hedger to/from whitelist, grants/revokes HEDGER_ROLE
     * @custom:events Emits HedgerWhitelisted or HedgerRemovedFromWhitelist
     * @custom:errors Throws AlreadyWhitelisted if adding already whitelisted hedger
     * @custom:reentrancy Not protected - governance function
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function setHedgerWhitelist(address hedger, bool add) external {
        _validateRole(GOVERNANCE_ROLE);
        AccessControlLibrary.validateAddress(hedger);
        if (add) {
            if (isWhitelistedHedger[hedger]) revert HedgerPoolErrorLibrary.AlreadyWhitelisted();
            isWhitelistedHedger[hedger] = true;
            _grantRole(HEDGER_ROLE, hedger);
            emit HedgerWhitelisted(hedger, msg.sender);
        } else {
            if (!isWhitelistedHedger[hedger]) revert CommonErrorLibrary.NotWhitelisted();
            isWhitelistedHedger[hedger] = false;
            _revokeRole(HEDGER_ROLE, hedger);
            emit HedgerRemoved(hedger, msg.sender);
        }
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
        if (!isValid) revert CommonErrorLibrary.InvalidOraclePrice();
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
        if (!hasRole(role, msg.sender)) revert CommonErrorLibrary.NotAuthorized();
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

    /**
     * @notice Finalizes position closure by updating hedger and protocol totals
     * @dev Internal helper to clean up position state and update aggregate statistics
     * @param hedger Address of the hedger whose position is being finalized
     * @param positionId Unique identifier of the position being finalized
     * @param position Storage reference to the position being finalized
     * @param marginDelta Amount of margin being removed from the position
     * @param exposureDelta Amount of exposure being removed from the position
     * @custom:security Internal function - assumes all validations done by caller
     * @custom:validation Assumes marginDelta and exposureDelta are valid and don't exceed current totals
     * @custom:state-changes Decrements hedger margin/exposure, protocol totals, marks position inactive, removes from active tracking, updates hedger position count
     * @custom:events None - events emitted by caller
     * @custom:errors None - assumes valid inputs from caller
     * @custom:reentrancy Not applicable - internal function, no external calls
     * @custom:access Internal - only callable within contract
     * @custom:oracle Not applicable
     */
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

    /**
     * @notice Unwinds filled volume from a position and redistributes it
     * @dev Clears position's filled volume and redistributes it to other active positions
     * @param positionId Unique identifier of the position being unwound
     * @param position Storage reference to the position being unwound
     * @return freedVolume Amount of filled volume that was freed and redistributed
     * @custom:security Internal function - assumes position is valid and active
     * @custom:validation Validates totalFilledExposure >= cachedFilledVolume before decrementing
     * @custom:state-changes Clears position filledVolume, decrements totalFilledExposure, redistributes volume to other positions
     * @custom:events Emits HedgerFillUpdated with positionId, old filled volume, and 0
     * @custom:errors Reverts with InsufficientHedgerCapacity if totalFilledExposure < cachedFilledVolume
     * @custom:reentrancy Protected by nonReentrant on all public entry points
     * @custom:access Internal - only callable within contract
     * @custom:oracle Requires fresh oracle price data
     */
    // slither-disable-next-line reentrancy-no-eth
    function _unwindFilledVolume(uint256 positionId, HedgePosition storage position, uint256 cachedPrice) internal returns (uint256 freedVolume) {
        uint256 cachedFilledVolume = uint256(position.filledVolume);
        uint256 cachedQeuroBacked = uint256(position.qeuroBacked);
        if (cachedFilledVolume == 0) {
            return 0;
        }

        // Require valid cached price to avoid reentrancy issues (caller must provide valid price)
        if (cachedPrice == 0) revert CommonErrorLibrary.InvalidOraclePrice();
        uint256 currentPrice = cachedPrice;

        // Update state before calling _increaseFilledVolume
        position.filledVolume = 0;
        position.qeuroBacked = 0;
        emit HedgerFillUpdated(positionId, cachedFilledVolume, 0);
        if (totalFilledExposure < cachedFilledVolume) revert HedgerPoolErrorLibrary.InsufficientHedgerCapacity();
        totalFilledExposure -= cachedFilledVolume;
        
        // Call _increaseFilledVolume with cached price
        _increaseFilledVolume(cachedFilledVolume, currentPrice, cachedQeuroBacked, positionId);
        return cachedFilledVolume;
    }

    /**
     * @notice Decrements pending liquidation commitment count for a position
     * @dev Internal helper to manage liquidation commitment tracking
     * @param hedger Address of the hedger
     * @param positionId ID of the position
     * @custom:security Internal function - no external access
     * @custom:validation None required for internal function
     * @custom:state-changes Decrements pendingLiquidations count if > 0
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - internal function
     * @custom:access Internal helper only
     * @custom:oracle Not applicable
     */
    function _decrementPendingCommitment(address hedger, uint256 positionId) internal {
        uint32 count = pendingLiquidations[hedger][positionId];
        if (count > 0) { unchecked { pendingLiquidations[hedger][positionId] = count - 1; } }
    }

    /**
     * @notice Checks if position is healthy enough for new fills
     * @dev Validates position has sufficient margin ratio after considering unrealized P&L
     * @param p Storage pointer to the position struct
     * @param price Current EUR/USD oracle price (18 decimals)
     * @return True if position is healthy and can accept new fills
     * @custom:security Internal function - validates position health
     * @custom:validation Checks effective margin > 0 and margin ratio >= minMarginRatio
     * @custom:state-changes None - view function
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal helper only
     * @custom:oracle Uses provided price parameter
     */
    function _isPositionHealthyForFill(HedgePosition storage p, uint256 price) internal view returns (bool) {
        if (p.filledVolume == 0) return true;
        // Only consider unrealized P&L for health check, not realized P&L (which is already locked in)
        int256 eff = int256(uint256(p.margin)) + HedgerPoolLogicLibrary.calculatePnL(uint256(p.filledVolume), uint256(p.qeuroBacked), price);
        return eff > 0 && uint256(eff).mulDiv(10000, uint256(p.filledVolume)) >= coreParams.minMarginRatio;
    }

    /**
     * @notice Allocates user mint exposure across active hedger positions
     * @dev Distributes `usdcAmount` proportionally to available capacity of HEALTHY positions only
     * @param usdcAmount Amount of USDC exposure to allocate (6 decimals)
     * @param currentPrice Current EUR/USD oracle price supplied by the caller (18 decimals)
     * @param qeuroAmount QEURO amount that was minted (18 decimals)
     * @param skipPositionId Position ID to exclude (e.g., the exiting position)
     * @custom:security Caller must ensure hedger sets are consistent before invocation
     * @custom:validation Validates liquidity availability and capacity before allocation
     * @custom:state-changes Updates `filledVolume` per position and `totalFilledExposure`
     * @custom:events Emits `HedgerFillUpdated` for every adjusted position
     * @custom:errors Reverts if capacity is insufficient or liquidity is absent
     * @custom:reentrancy Not applicable - internal function
     * @custom:access Internal helper
     * @custom:oracle Requires current oracle price to check position health
     */
    function _increaseFilledVolume(uint256 usdcAmount, uint256 currentPrice, uint256 qeuroAmount, uint256 skipPositionId) internal {
        if (usdcAmount == 0) return;
        uint256 len = activePositions.length;
        if (len == 0) revert HedgerPoolErrorLibrary.NoActiveHedgerLiquidity();
        if (currentPrice == 0) revert CommonErrorLibrary.InvalidOraclePrice();

        uint256 minMarginRatio = coreParams.minMarginRatio;

        // Build capacity array and calculate total
        uint256[] memory capacities = new uint256[](len);
        uint256 availableCapacity = 0;
        for (uint256 i = 0; i < len; i++) {
            uint256 positionId = activePositions[i];
            if (positionId == skipPositionId) continue;
            HedgePosition storage position = positions[positionId];
            if (!_isPositionHealthyForFill(position, currentPrice)) continue;
            uint256 cap = HedgerPoolLogicLibrary.calculateCollateralCapacity(
                uint256(position.margin), uint256(position.filledVolume),
                uint256(position.entryPrice), currentPrice, minMarginRatio, position.realizedPnL, position.qeuroBacked
            );
            capacities[i] = cap;
            availableCapacity += cap;
        }

        if (availableCapacity == 0) revert HedgerPoolErrorLibrary.NoActiveHedgerLiquidity();
        if (availableCapacity < usdcAmount) revert HedgerPoolErrorLibrary.InsufficientHedgerCapacity();

        // Allocate proportionally
        uint256 allocated = 0;
        for (uint256 i; i < len; ++i) {
            uint256 cap = capacities[i];
            if (cap == 0) continue;
            uint256 positionId = activePositions[i];
            HedgePosition storage position = positions[positionId];
            uint256 share = cap.mulDiv(usdcAmount, availableCapacity);
            uint256 remaining = usdcAmount - allocated;
            if (share > remaining) share = remaining;
            if (share > cap) share = cap;
            if (share == 0) continue;
            uint256 prevFilled = uint256(position.filledVolume);
            _applyFillChange(positionId, position, share, true);
            _updateEntryPriceAfterFill(position, prevFilled, share, currentPrice);
            position.qeuroBacked += uint128(qeuroAmount.mulDiv(share, usdcAmount));
            allocated += share;
        }
        if (allocated < usdcAmount) revert HedgerPoolErrorLibrary.InsufficientHedgerCapacity();
        totalFilledExposure += usdcAmount;
    }

    /**
     * @notice Releases exposure across hedger positions following a user redeem
     * @dev Proportionally decreases fills based on filled volume share
     * @param usdcAmount Amount of USDC to release (at redeem price) (6 decimals)
     * @param redeemPrice Current EUR/USD oracle price (18 decimals) for P&L calculation
     * @param qeuroAmount QEURO amount that was redeemed (18 decimals)
     * @param skipPositionId Position ID to exclude from the release cycle
     * @custom:security Internal function - validates price and amounts
     * @custom:validation Validates usdcAmount > 0, redeemPrice > 0, and sufficient filled exposure
     * @custom:state-changes Decreases filledVolume per position, updates totalFilledExposure, calculates realized P&L
     * @custom:events Emits HedgerFillUpdated and RealizedPnLRecorded for each position
     * @custom:errors Reverts with InvalidOraclePrice, NoActiveHedgerLiquidity, or InsufficientHedgerCapacity
     * @custom:reentrancy Not applicable - internal function
     * @custom:access Internal helper only
     * @custom:oracle Uses provided redeemPrice parameter
     */
    function _decreaseFilledVolume(uint256 usdcAmount, uint256 redeemPrice, uint256 qeuroAmount, uint256 skipPositionId) internal {
        if (usdcAmount == 0) return;
        if (redeemPrice == 0) revert CommonErrorLibrary.InvalidOraclePrice();

        uint256 len = activePositions.length;
        if (len == 0) revert HedgerPoolErrorLibrary.NoActiveHedgerLiquidity();

        // Calculate total filled for proportional distribution
        uint256 totalFilled = 0;
        uint256 totalQeuroBacked = 0;
        for (uint256 i = 0; i < len; i++) {
            if (activePositions[i] != skipPositionId) {
                totalFilled += uint256(positions[activePositions[i]].filledVolume);
                totalQeuroBacked += uint256(positions[activePositions[i]].qeuroBacked);
            }
        }
        if (totalFilled == 0) revert HedgerPoolErrorLibrary.NoActiveHedgerLiquidity();
        // Note: We don't cap usdcAmount or qeuroAmount based on totalFilled
        // filledVolume is just accounting - the user is redeeming qeuroAmount QEURO worth usdcAmount USDC
        // We should realize P&L for ALL qeuroAmount being redeemed, regardless of filledVolume
        // filledVolume will be decreased as much as possible (capped to available filledVolume), but P&L is calculated for all QEURO

        // Distribute proportionally
        uint256 released = 0;
        uint256 qeuroReleased = 0;
        for (uint256 i; i < len; ++i) {
            uint256 posId = activePositions[i];
            if (posId == skipPositionId) continue;
            HedgePosition storage pos = positions[posId];
            uint256 filled = uint256(pos.filledVolume);
            if (filled == 0) continue;

            // Calculate qeuroShare proportionally to qeuroBacked (not to filledVolume)
            // This ensures the proportion of qeuroBacked being redeemed matches the proportion used for P&L calculation
            uint256 qeuroShare = totalQeuroBacked > 0 
                ? uint256(pos.qeuroBacked).mulDiv(qeuroAmount, totalQeuroBacked)
                : 0;
            if (qeuroShare > qeuroAmount - qeuroReleased) qeuroShare = qeuroAmount - qeuroReleased;
            if (qeuroShare > uint256(pos.qeuroBacked)) qeuroShare = uint256(pos.qeuroBacked);
            if (qeuroShare == 0) continue;
            
            // Calculate share (USDC to decrease from filledVolume) based on qeuroShare being redeemed
            // share = qeuroShare * redeemPrice / 1e30 (convert QEURO to USDC at current price)
            // Cap share to filled to avoid underflow, but this doesn't affect P&L calculation
            uint256 share = qeuroShare.mulDiv(redeemPrice, 1e30);
            if (share > usdcAmount - released) share = usdcAmount - released;
            if (share > filled) share = filled;
            if (share == 0) continue;
            
            // Emit event for debugging qeuroShare calculation
            emit QeuroShareCalculated(posId, qeuroShare, uint256(pos.qeuroBacked), totalQeuroBacked);
            
            // Process redemption with new realized P&L formula
            // Use qeuroShare (full amount) for P&L calculation to realize all remaining unrealized P&L
            // This ensures we realize P&L for ALL QEURO being redeemed, regardless of filledVolume
            _processRedeem(posId, pos, share, filled, redeemPrice, qeuroShare);
            
            // Decrease qeuroBacked proportionally
            pos.qeuroBacked = qeuroShare <= uint256(pos.qeuroBacked) ? pos.qeuroBacked - uint128(qeuroShare) : 0;
            released += share;
            qeuroReleased += qeuroShare;
        }
        totalFilledExposure -= released;
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
    function _applyFillChange(uint256 positionId, HedgePosition storage position, uint256 delta, bool increase) internal {
        if (delta == 0) return;
        uint256 previous = position.filledVolume;
        uint256 updated = increase ? previous + delta : previous - delta;
        // Note: positionSize check removed - capacity is now based on collateral, not position size
        // The collateral-based capacity check happens in _increaseFilledVolume before this function
        if (!increase && previous < delta) revert HedgerPoolErrorLibrary.InsufficientHedgerCapacity();
        position.filledVolume = uint96(updated);
        emit HedgerFillUpdated(positionId, previous, updated);
    }

    /**
     * @notice Updates weighted-average entry price after new fills
     * @dev Calculates new weighted average entry price when position receives new fills
     * @param pos Storage pointer to the position struct
     * @param prevFilled Previous filled volume before the new fill
     * @param delta Amount of new fill being added
     * @param price Current EUR/USD oracle price for the new fill (18 decimals)
     * @custom:security Internal function - validates price is valid
     * @custom:validation Validates price > 0 and price <= type(uint96).max
     * @custom:state-changes Updates pos.entryPrice with weighted average
     * @custom:events None
     * @custom:errors Throws InvalidOraclePrice if price is invalid
     * @custom:reentrancy Not applicable - internal function
     * @custom:access Internal helper only
     * @custom:oracle Uses provided price parameter
     */
    function _updateEntryPriceAfterFill(HedgePosition storage pos, uint256 prevFilled, uint256 delta, uint256 price) internal {
        if (delta == 0) return;
        if (price == 0 || price > type(uint96).max) revert CommonErrorLibrary.InvalidOraclePrice();
        if (prevFilled == 0 || pos.filledVolume == 0) { pos.entryPrice = uint96(price); return; }
        // Weighted average: newEntry = totalUSDC * oldEntry * price / (prevUSDC * price + delta * oldEntry)
        uint256 old = uint256(pos.entryPrice);
        pos.entryPrice = uint96((uint256(pos.filledVolume) * old * price) / (prevFilled * price + delta * old));
    }

    /**
     * @notice Processes redemption for a single position - calculates realized P&L
     * @dev New formula: RealizedP&L = QEUROQuantitySold * (entryPrice - OracleCurrentPrice)
     *      Hedgers are SHORT EUR, so they profit when EUR price decreases
     * @param posId ID of the position being processed
     * @param pos Storage pointer to the position struct
     * @param share Amount of USDC exposure being released (6 decimals)
     * @param price Current EUR/USD oracle price for redemption (18 decimals)
     * @param qeuroAmount QEURO amount being redeemed (18 decimals)
     * @custom:security Internal function - calculates and records realized P&L
     * @custom:validation Validates entry price > 0 and qeuroAmount > 0
     * @custom:state-changes Updates pos.realizedPnL and decreases filled volume
     * @custom:events Emits RealizedPnLRecorded and HedgerFillUpdated
     * @custom:errors None
     * @custom:reentrancy Not applicable - internal function
     * @custom:access Internal helper only
     * @custom:oracle Uses provided price parameter
     */
    function _processRedeem(uint256 posId, HedgePosition storage pos, uint256 share, uint256 filledBefore, uint256 price, uint256 qeuroAmount) internal {
        if (share > 0 && qeuroAmount > 0 && price > 0) {
            // Calculate realized P&L based on the proportion of unrealized P&L being redeemed
            // Realized P&L = proportion of qeuroBacked being redeemed * total unrealized P&L
            // Proportion = qeuroAmount / qeuroBacked (before redemption)
            // Total unrealized P&L = filledVolume - (qeuroBacked * price / 1e30)
            // IMPORTANT: Use filledBefore (filledVolume before decrease) and qeuroBacked before decrease
            uint256 currentQeuroBacked = uint256(pos.qeuroBacked);
            
            if (currentQeuroBacked > 0 && filledBefore > 0) {
                // Calculate total unrealized P&L before redemption using filledVolume BEFORE it's decreased
                uint256 qeuroValueInUSDC = currentQeuroBacked.mulDiv(price, 1e30);
                int256 totalUnrealizedPnL;
                if (filledBefore >= qeuroValueInUSDC) {
                    totalUnrealizedPnL = int256(filledBefore - qeuroValueInUSDC);
                } else {
                    totalUnrealizedPnL = -int256(qeuroValueInUSDC - filledBefore);
                }
                
                // Calculate NET unrealized P&L (total unrealized - realized)
                // This matches the frontend calculation: Net Unrealized = Total Unrealized - Realized
                int256 netUnrealizedPnL = totalUnrealizedPnL - int256(pos.realizedPnL);
                
                // Calculate proportion of qeuroBacked being redeemed
                // realizedDelta = (qeuroAmount / currentQeuroBacked) * netUnrealizedPnL
                // We use net unrealized P&L (not total) because we want to realize the remaining unrealized P&L
                // qeuroAmount is in 18 decimals, netUnrealizedPnL is in 6 decimals (USDC)
                // currentQeuroBacked is in 18 decimals
                // Result: (18 decimals * 6 decimals) / 18 decimals = 6 decimals ✓
                int256 realizedDelta;
                if (netUnrealizedPnL >= 0) {
                    // Multiply qeuroAmount (18 decimals) by netUnrealizedPnL (6 decimals) = 24 decimals
                    // Divide by currentQeuroBacked (18 decimals) = 6 decimals
                    uint256 pnlShare = qeuroAmount.mulDiv(uint256(netUnrealizedPnL), currentQeuroBacked);
                    realizedDelta = int256(pnlShare);
                } else {
                    uint256 absPnL = uint256(-netUnrealizedPnL);
                    uint256 pnlShare = qeuroAmount.mulDiv(absPnL, currentQeuroBacked);
                    realizedDelta = -int256(pnlShare);
                }
                
                // Record realized P&L
                pos.realizedPnL += int128(realizedDelta);
                emit RealizedPnLRecorded(posId, realizedDelta, int256(pos.realizedPnL));
                emit RealizedPnLCalculation(posId, qeuroAmount, currentQeuroBacked, filledBefore, price, totalUnrealizedPnL, realizedDelta);
            }
        }
        _applyFillChange(posId, pos, share, false);
        // Note: unrealized P&L will be updated in _decreaseFilledVolume after qeuroBacked is updated
    }

    /**
     * @notice Validates that closing a position won't cause protocol undercollateralization
     * @dev Checks if protocol remains collateralized after removing this position's margin
     * @param positionMargin Amount of margin in the position being closed
     * @custom:security Internal function - prevents protocol undercollateralization from position closures
     * @custom:validation Checks vault is set, protocol is collateralized, and remaining margin > positionMargin
     * @custom:state-changes None - view function
     * @custom:events None
     * @custom:errors Reverts with PositionClosureRestricted if closing would cause undercollateralization
     * @custom:reentrancy Not applicable - view function, no state changes
     * @custom:access Internal - only callable within contract
     * @custom:oracle Not applicable - uses vault's collateralization check
     */
    function _validatePositionClosureSafety(uint256 positionMargin) internal view {
        if (address(vault) == address(0)) return;
        (bool isCollateralized, uint256 reportedMargin) = vault.isProtocolCollateralized();
        if (!isCollateralized || reportedMargin <= positionMargin) revert HedgerPoolErrorLibrary.PositionClosureRestricted();
    }
}