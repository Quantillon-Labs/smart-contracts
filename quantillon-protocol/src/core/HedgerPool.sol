// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IOracle} from "../interfaces/IOracle.sol";
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
 * 
 * P&L Calculation Model:
 * 
 * Hedgers are SHORT EUR (they owe QEURO to users). When EUR/USD price rises, hedgers lose.
 * 
 * 1. TOTAL UNREALIZED P&L (mark-to-market of current position):
 *    totalUnrealizedPnL = FilledVolume - (QEUROBacked × OraclePrice / 1e30)
 * 
 * 2. NET UNREALIZED P&L (used when margin already reflects realized P&L):
 *    netUnrealizedPnL = totalUnrealizedPnL - realizedPnL
 * 
 * 3. EFFECTIVE MARGIN (true economic value):
 *    effectiveMargin = margin + netUnrealizedPnL
 * 
 * 4. REALIZED P&L (during partial redemptions):
 *    When users redeem QEURO, a portion of net unrealized P&L is realized.
 *    realizedDelta = (qeuroAmount / qeuroBacked) × netUnrealizedPnL
 *    - If positive (profit): margin increases
 *    - If negative (loss): margin decreases
 * 
 * 5. LIQUIDATION MODE (CR ≤ 101%):
 *    In liquidation mode, unrealizedPnL = -margin (all margin at risk).
 *    effectiveMargin = 0, hedger absorbs pro-rata losses on redemptions.
 * 
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
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant HEDGER_ROLE = keccak256("HEDGER_ROLE");

    IERC20 public usdc;
    IOracle public oracle;
    IYieldShift public yieldShift;
    IQuantillonVault public vault;
    address public treasury;
    TimeProvider public immutable TIME_PROVIDER;

    struct CoreParams {
        uint64 minMarginRatio;
        uint16 maxLeverage;
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

    /// @notice Address of the single hedger allowed to open positions
    /// @dev This replaces the previous multi-hedger whitelist model
    address public singleHedger;

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

    struct HedgerRewardState {
        uint128 pendingRewards;
        uint64 lastRewardClaim;
    }

    mapping(uint256 => HedgePosition) public positions;
    mapping(address => HedgerRewardState) private hedgerRewards;

    /// @notice Maps hedger address to their active position ID (0 = no active position)
    /// @dev Used to track the single hedger's position in single hedger model
    mapping(address => uint256) private hedgerActivePositionId;

    mapping(address => uint256) public hedgerLastRewardBlock;
    uint96 public constant MAX_UINT96_VALUE = type(uint96).max;
    uint256 public constant MAX_POSITION_SIZE = MAX_UINT96_VALUE;
    uint256 public constant MAX_MARGIN = MAX_UINT96_VALUE;
    uint256 public constant MAX_ENTRY_PRICE = MAX_UINT96_VALUE;
    uint256 public constant MAX_LEVERAGE = type(uint16).max;
    uint256 public constant MAX_MARGIN_RATIO = 5000; // 50% maximum margin ratio (2x minimum leverage)
    uint256 public constant DEFAULT_MIN_MARGIN_RATIO_BPS = 500; // 5% minimum margin ratio (20x max leverage) - basis points
    uint128 public constant MAX_UINT128_VALUE = type(uint128).max;
    uint256 public constant MAX_TOTAL_MARGIN = MAX_UINT128_VALUE;
    uint256 public constant MAX_TOTAL_EXPOSURE = MAX_UINT128_VALUE;
    uint256 public constant MAX_REWARD_PERIOD = 365 days;

    event HedgePositionOpened(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
    event HedgePositionClosed(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
    event MarginUpdated(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
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
        _onlyVault();
        _;
    }

    function _onlyVault() internal view {
        if (msg.sender != address(vault)) revert HedgerPoolErrorLibrary.OnlyVault();
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
        oracle = IOracle(_oracle);
        yieldShift = IYieldShift(_yieldShift);
        vault = IQuantillonVault(_vault);
        
        if (_treasury == address(0)) revert CommonErrorLibrary.ZeroAddress();
        treasury = _treasury;

        // forge-lint: disable-next-line(unsafe-typecast)
        coreParams.minMarginRatio = uint64(DEFAULT_MIN_MARGIN_RATIO_BPS);  // 5% minimum margin ratio (20x max leverage)
        coreParams.maxLeverage = 20;      // 20x maximum leverage (5% minimum margin)
        coreParams.entryFee = 0;
        coreParams.exitFee = 0;
        coreParams.marginFee = 0;
        coreParams.eurInterestRate = 350;
        coreParams.usdInterestRate = 450;
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
    // slither-disable-start reentrancy-no-eth
    // slither-disable-start reentrancy-benign
    // SECURITY: Protected by nonReentrant modifier; external call to trusted Oracle contract
    function enterHedgePosition(uint256 usdcAmount, uint256 leverage) 
        external 
        whenNotPaused
        nonReentrant
        returns (uint256 positionId) 
    {
        // CHECKS
        // Single hedger model: only the configured hedger address can open positions
        if (msg.sender != singleHedger) revert CommonErrorLibrary.NotAuthorized();
        
        // Ensure hedger doesn't already have an active position
        if (hedgerActivePositionId[msg.sender] != 0) {
            HedgePosition storage existingPosition = positions[hedgerActivePositionId[msg.sender]];
            if (existingPosition.isActive) {
                revert HedgerPoolErrorLibrary.HedgerHasActivePosition();
            }
        }
        
        uint256 currentTime = TIME_PROVIDER.currentTime();
        
        // Get oracle price first to prevent reentrancy
        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        CommonValidationLibrary.validateCondition(isValid, "oracle");
        
        // Calculate position parameters using actual oracle price
        (uint256 fee, uint256 netMargin, uint256 positionSize, uint256 marginRatio) = 
            HedgerPoolLogicLibrary.validateAndCalculatePositionParams(
                usdcAmount,
                leverage,
                eurUsdPrice,
                coreParams.entryFee,
                coreParams.minMarginRatio,
                MAX_MARGIN_RATIO,
                coreParams.maxLeverage,
                MAX_MARGIN,
                MAX_POSITION_SIZE,
                MAX_ENTRY_PRICE,
                MAX_LEVERAGE,
                currentTime
            );
        // Explicitly use all return values to avoid unused-return warning
        // fee and marginRatio are validated by the library function, no additional checks needed
        if (fee > usdcAmount || marginRatio == 0) revert HedgerPoolErrorLibrary.InvalidPosition();
        
        // Use fixed position ID 1 for single position model
        positionId = 1;
        HedgePosition storage position = positions[positionId];
        position.hedger = msg.sender;
        // forge-lint: disable-next-line(unsafe-typecast)
        position.positionSize = uint96(positionSize);
        position.filledVolume = 0;
        // forge-lint: disable-next-line(unsafe-typecast)
        position.margin = uint96(netMargin);
        // forge-lint: disable-next-line(unsafe-typecast)
        position.entryTime = uint32(currentTime);
        // forge-lint: disable-next-line(unsafe-typecast)
        position.lastUpdateTime = uint32(currentTime);
        // forge-lint: disable-next-line(unsafe-typecast)
        position.leverage = uint16(leverage);
        // forge-lint: disable-next-line(unsafe-typecast)
        position.entryPrice = uint96(eurUsdPrice);
        position.unrealizedPnL = 0;
        position.isActive = true;
        hedgerActivePositionId[msg.sender] = positionId;

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
    // slither-disable-end reentrancy-no-eth
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
    // slither-disable-start reentrancy-no-eth
    // slither-disable-start reentrancy-benign
    // SECURITY: Protected by nonReentrant modifier; external call to trusted Oracle contract
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
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 grossPayout = uint256(int256(cachedMargin) + pnl);
        uint256 exitFeeAmount = grossPayout.percentageOf(coreParams.exitFee);
        uint256 netPayout = grossPayout - exitFeeAmount;

        // INTERACTIONS - All external calls after state updates
        if (netPayout > 0) {
            // Withdraw USDC from vault for hedger payout
            vault.withdrawHedgerDeposit(msg.sender, netPayout);
        }
    }
    // slither-disable-end reentrancy-no-eth
    // slither-disable-end reentrancy-benign

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
        // forge-lint: disable-next-line(unsafe-typecast)
        position.margin = uint96(newMargin);
        // forge-lint: disable-next-line(unsafe-typecast)
        position.positionSize = uint96(newPositionSize);

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
    // slither-disable-start reentrancy-no-eth
    // slither-disable-start reentrancy-benign
    // SECURITY: Protected by nonReentrant modifier; external call to trusted Oracle contract
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
        uint256 deltaPositionSize = currentPositionSize - newPositionSize;

        // Validate that position won't become liquidatable after margin removal
        // Get current price for liquidation check
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid || currentPrice == 0) revert CommonErrorLibrary.InvalidOraclePrice();
        
        // Check if position would become unhealthy after margin removal
        // Uses minMarginRatio as threshold to ensure position maintains minimum collateralization
        // This is the primary safety check - it ensures the position has sufficient collateral
        // to cover its exposure even after margin removal
        bool wouldBeUnhealthy = HedgerPoolLogicLibrary.isPositionLiquidatable(
            newMargin,
            uint256(position.filledVolume),
            uint256(position.entryPrice),
            currentPrice,
            coreParams.minMarginRatio,
            position.qeuroBacked,
            position.realizedPnL
        );
        
        if (wouldBeUnhealthy) {
            revert HedgerPoolErrorLibrary.InsufficientMargin();
        }

        // Validate margin ratio after removal (based on new position size)
        // This ensures the position maintains proper leverage structure
        uint256 newMarginRatio = newPositionSize > 0
            ? newMargin.mulDiv(10000, newPositionSize)
            : 0;
        HedgerPoolValidationLibrary.validateMarginRatio(newMarginRatio, coreParams.minMarginRatio);
        HedgerPoolValidationLibrary.validateMaxMarginRatio(newMarginRatio, MAX_MARGIN_RATIO);

        // forge-lint: disable-next-line(unsafe-typecast)
        position.margin = uint96(newMargin);
        // forge-lint: disable-next-line(unsafe-typecast)
        position.positionSize = uint96(newPositionSize);

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
    // slither-disable-end reentrancy-no-eth
    // slither-disable-end reentrancy-benign

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
        _increaseFilledVolume(usdcAmount, fillPrice, qeuroAmount);
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
        _decreaseFilledVolume(usdcAmount, redeemPrice, qeuroAmount);
    }

    /**
     * @notice Records a liquidation mode redemption - directly reduces hedger margin proportionally
     * @dev Called by vault when protocol is in liquidation mode (CR ≤ 101%)
     * 
     * In liquidation mode, the ENTIRE hedger margin is considered at risk (unrealized P&L = -margin).
     * When users redeem, the hedger absorbs a pro-rata loss:
     * 
     * Formula: hedgerLoss = (qeuroAmount / totalQeuroSupply) × currentMargin
     * 
     * This loss is recorded as realized P&L and reduces the hedger's margin.
     * The qeuroBacked and filledVolume are also reduced proportionally.
     * 
     * @param qeuroAmount Amount of QEURO being redeemed (18 decimals)
     * @param totalQeuroSupply Total QEURO supply before redemption (18 decimals)
     * @custom:security Vault-only access prevents unauthorized calls
     * @custom:validation Validates qeuroAmount > 0, totalQeuroSupply > 0, position exists and is active
     * @custom:state-changes Reduces hedger margin, records realized P&L, reduces qeuroBacked and filledVolume
     * @custom:events Emits RealizedPnLRecorded
     * @custom:errors None (early returns for invalid states)
     * @custom:reentrancy Protected by whenNotPaused modifier
     * @custom:access Restricted to QuantillonVault via onlyVault modifier
     * @custom:oracle No oracle dependency - uses provided parameters
     */
    function recordLiquidationRedeem(uint256 qeuroAmount, uint256 totalQeuroSupply) external onlyVault whenNotPaused {
        if (qeuroAmount == 0 || totalQeuroSupply == 0) return;
        if (singleHedger == address(0)) return;
        
        uint256 positionId = hedgerActivePositionId[singleHedger];
        if (positionId == 0) return;
        
        HedgePosition storage pos = positions[positionId];
        if (!pos.isActive) return;
        
        uint256 currentMargin = uint256(pos.margin);
        if (currentMargin == 0) return;
        
        // Calculate hedger's proportional loss: (qeuroAmount / totalSupply) * margin
        // qeuroAmount (18 dec) * margin (6 dec) / totalSupply (18 dec) = 6 dec
        uint256 hedgerLoss = qeuroAmount.mulDiv(currentMargin, totalQeuroSupply);
        if (hedgerLoss > currentMargin) hedgerLoss = currentMargin;
        
        // Update margin (reduce by loss amount)
        uint256 newMargin = currentMargin - hedgerLoss;
        // forge-lint: disable-next-line(unsafe-typecast)
        pos.margin = uint96(newMargin);
        totalMargin -= hedgerLoss;

        // Record as realized P&L (loss is negative)
        // forge-lint: disable-next-line(unsafe-typecast)
        int256 realizedDelta = -int256(hedgerLoss);
        // forge-lint: disable-next-line(unsafe-typecast)
        pos.realizedPnL += int128(realizedDelta);
        emit RealizedPnLRecorded(positionId, realizedDelta, int256(pos.realizedPnL));

        // Reduce qeuroBacked proportionally
        uint256 qeuroShare = qeuroAmount;
        if (qeuroShare > uint256(pos.qeuroBacked)) qeuroShare = uint256(pos.qeuroBacked);
        // forge-lint: disable-next-line(unsafe-typecast)
        pos.qeuroBacked = pos.qeuroBacked - uint128(qeuroShare);

        // Reduce filledVolume proportionally
        // filledVolume reduction = (qeuroAmount / totalSupply) * filledVolume
        uint256 currentFilled = uint256(pos.filledVolume);
        if (currentFilled > 0) {
            uint256 filledReduction = qeuroAmount.mulDiv(currentFilled, totalQeuroSupply);
            if (filledReduction > currentFilled) filledReduction = currentFilled;
            // forge-lint: disable-next-line(unsafe-typecast)
            pos.filledVolume = uint96(currentFilled - filledReduction);
            totalFilledExposure -= filledReduction;
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
        HedgerRewardState storage rewardState = hedgerRewards[hedger];

        // In single-hedger mode we use the protocol-wide exposure as reward base
        (uint256 newPendingRewards, uint256 newLastRewardBlock) = HedgerPoolLogicLibrary.calculateRewardUpdate(
            totalExposure, coreParams.eurInterestRate, coreParams.usdInterestRate,
            hedgerLastRewardBlock[hedger], block.number, MAX_REWARD_PERIOD, 
            uint256(rewardState.pendingRewards)
        );
        
        // forge-lint: disable-next-line(unsafe-typecast)
        rewardState.pendingRewards = uint128(newPendingRewards);
        hedgerLastRewardBlock[hedger] = newLastRewardBlock;

        interestDifferential = rewardState.pendingRewards;
        yieldShiftRewards = yieldShift.getHedgerPendingYield(hedger);
        totalRewards = interestDifferential + yieldShiftRewards;

        if (totalRewards > 0) {
            rewardState.pendingRewards = 0;
            // forge-lint: disable-next-line(unsafe-typecast)
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
     * @notice Calculates total effective hedger collateral (margin + P&L) for the hedger position
     * @dev Used by vault to determine protocol collateralization ratio
     * 
     * Formula breakdown:
     * 1. totalUnrealizedPnL = FilledVolume - (QEUROBacked × price / 1e30)
     * 2. netUnrealizedPnL = totalUnrealizedPnL - realizedPnL
     *    (margin already reflects realized P&L, so we use net unrealized to avoid double-counting)
     * 3. effectiveCollateral = margin + netUnrealizedPnL
     * 
     * @param price Current EUR/USD oracle price (18 decimals)
     * @return t Total effective collateral in USDC (6 decimals)
     * @custom:security View-only helper - no state changes, safe for external calls
     * @custom:validation Validates price > 0, position exists and is active
     * @custom:state-changes None - view function
     * @custom:events None - view function
     * @custom:errors None - returns 0 for invalid states
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query effective collateral
     * @custom:oracle Requires fresh oracle price data
     */
    function getTotalEffectiveHedgerCollateral(uint256 price) external view returns (uint256 t) {
        if (singleHedger == address(0)) return 0;
        uint256 positionId = hedgerActivePositionId[singleHedger];
        if (positionId == 0) return 0;
        
        HedgePosition storage position = positions[positionId];
        if (!position.isActive) return 0;
        
        // Calculate total unrealized P&L (mark-to-market of current position)
        int256 totalUnrealizedPnL = HedgerPoolLogicLibrary.calculatePnL(uint256(position.filledVolume), uint256(position.qeuroBacked), price);
        
        // Special case: When all QEURO is redeemed (qeuroBacked == 0, filledVolume == 0),
        // calculatePnL returns 0. In this state, the position has no active exposure,
        // so effective margin equals the remaining margin after all P&L was realized.
        // Set unrealizedPnL = -margin so effectiveMargin = 0 (conservative approach).
        if (position.qeuroBacked == 0 && position.filledVolume == 0 && totalUnrealizedPnL == 0) {
            totalUnrealizedPnL = -int256(uint256(position.margin));
        }
        
        // Calculate NET unrealized P&L = totalUnrealizedPnL - realizedPnL
        // The margin has already been adjusted by realized P&L during redemptions,
        // so we subtract realizedPnL to avoid double-counting.
        int256 netUnrealizedPnL = totalUnrealizedPnL - int256(position.realizedPnL);

        // Effective collateral = margin + net unrealized P&L
        // forge-lint: disable-next-line(unsafe-typecast)
        int256 e = int256(uint256(position.margin)) + netUnrealizedPnL;
        // forge-lint: disable-next-line(unsafe-typecast)
        if (e > 0) t = uint256(e);
    }

    /**
     * @notice Checks if there is an active hedger with an active position
     * @dev Returns true if the single hedger has an active position
     * @return True if hedger has an active position, false otherwise
     * @custom:security View-only helper - no state changes
     * @custom:validation None
     * @custom:state-changes None - view function
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query
     * @custom:oracle Not applicable
     */
    function hasActiveHedger() external view returns (bool) {
        if (singleHedger == address(0)) return false;
        uint256 activePositionId = hedgerActivePositionId[singleHedger];
        if (activePositionId == 0) return false;
        HedgePosition storage position = positions[activePositionId];
        return position.isActive;
    }

    /**
     * @notice Updates core hedging parameters for risk management
     * @dev Allows governance to adjust risk parameters based on market conditions
     * @param minRatio New minimum margin ratio in basis points (e.g., 500 = 5%)
     * @param maxLev New maximum leverage multiplier (e.g., 20 = 20x)
     * @custom:security Validates governance role and parameter constraints
     * @custom:validation Validates minRatio >= DEFAULT_MIN_MARGIN_RATIO_BPS, maxLev <= 20
     * @custom:state-changes Updates minMarginRatio and maxLeverage state variables
     * @custom:events No events emitted for parameter updates
     * @custom:errors Throws ConfigValueTooLow, ConfigValueTooHigh
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies for parameter updates
     */
    function updateHedgingParameters(uint256 minRatio, uint256 maxLev) external {
        _validateRole(GOVERNANCE_ROLE);
        if (minRatio < DEFAULT_MIN_MARGIN_RATIO_BPS) revert CommonErrorLibrary.ConfigValueTooLow();
        if (maxLev > 20) revert CommonErrorLibrary.ConfigValueTooHigh();
        // forge-lint: disable-next-line(unsafe-typecast)
        coreParams.minMarginRatio = uint64(minRatio);
        // forge-lint: disable-next-line(unsafe-typecast)
        coreParams.maxLeverage = uint16(maxLev);
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
        // forge-lint: disable-next-line(unsafe-typecast)
        coreParams.eurInterestRate = uint16(eurRate);
        // forge-lint: disable-next-line(unsafe-typecast)
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
        // forge-lint: disable-next-line(unsafe-typecast)
        coreParams.entryFee = uint16(entry);
        // forge-lint: disable-next-line(unsafe-typecast)
        coreParams.exitFee = uint16(exit);
        // forge-lint: disable-next-line(unsafe-typecast)
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
    // slither-disable-start reentrancy-no-eth
    // slither-disable-start reentrancy-benign
    // SECURITY: Protected by nonReentrant modifier; external call to trusted Oracle contract
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
    // slither-disable-end reentrancy-no-eth
    // slither-disable-end reentrancy-benign

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
        else if (slot == 2) oracle = IOracle(addr);
        else if (slot == 3) yieldShift = IYieldShift(addr);
        else revert HedgerPoolErrorLibrary.InvalidPosition();
    }

    /**
     * @notice Sets the single hedger address allowed to open positions
     * @dev Replaces the previous multi-hedger whitelist model with a single hedger
     * @param hedger Address of the single hedger
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates governance role and non-zero hedger address
     * @custom:state-changes Updates singleHedger address
     * @custom:events None
     * @custom:errors Throws ZeroAddress if hedger is zero
     * @custom:reentrancy Not protected - governance function
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function setSingleHedger(address hedger) external {
        _validateRole(GOVERNANCE_ROLE);
        // Explicit zero address check to satisfy static analysis
        if (hedger == address(0)) revert CommonErrorLibrary.InvalidAddress();
        singleHedger = hedger;
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
     * @notice Finalizes position closure by updating hedger and protocol totals
     * @dev Internal helper to clean up position state and update aggregate statistics
     * @param hedger Address of the hedger whose position is being finalized
     * @param positionId Unique identifier of the position being finalized
     * @param position Storage reference to the position being finalized
     * @param marginDelta Amount of margin being removed from the position
     * @param exposureDelta Amount of exposure being removed from the position
     * @custom:security Internal function - assumes all validations done by caller
     * @custom:validation Assumes marginDelta and exposureDelta are valid and don't exceed current totals
     * @custom:state-changes Decrements hedger margin/exposure, protocol totals, marks position inactive, updates hedger position tracking
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
        totalMargin -= marginDelta;
        totalExposure -= exposureDelta;

        position.isActive = false;
        
        // Reset hedger's active position tracking
        if (hedgerActivePositionId[hedger] == positionId) {
            hedgerActivePositionId[hedger] = 0;
        }

    }

    /**
     * @notice Unwinds filled volume from a position
     * @dev Clears position's filled volume (no redistribution needed with single position)
     * @param positionId Unique identifier of the position being unwound
     * @param position Storage reference to the position being unwound
     * @param cachedPrice Cached EUR/USD price to avoid reentrancy (18 decimals)
     * @return freedVolume Amount of filled volume that was freed and redistributed
     * @custom:security Internal function - assumes position is valid and active
     * @custom:validation Validates totalFilledExposure >= cachedFilledVolume before decrementing
     * @custom:state-changes Clears position filledVolume, decrements totalFilledExposure
     * @custom:events Emits HedgerFillUpdated with positionId, old filled volume, and 0
     * @custom:errors Reverts with InsufficientHedgerCapacity if totalFilledExposure < cachedFilledVolume
     * @custom:reentrancy Protected by nonReentrant on all public entry points
     * @custom:access Internal - only callable within contract
     * @custom:oracle Requires fresh oracle price data
     */
    // slither-disable-start reentrancy-no-eth
    // slither-disable-start reentrancy-benign
    // SECURITY: Internal function called from nonReentrant context; no untrusted external calls
    function _unwindFilledVolume(uint256 positionId, HedgePosition storage position, uint256 cachedPrice) internal returns (uint256 freedVolume) {
        uint256 cachedFilledVolume = uint256(position.filledVolume);
        if (cachedFilledVolume == 0) {
            return 0;
        }

        // Require valid cached price to avoid reentrancy issues (caller must provide valid price)
        if (cachedPrice == 0) revert CommonErrorLibrary.InvalidOraclePrice();

        // Update state - clear filled volume (no redistribution needed with single position)
        position.filledVolume = 0;
        position.qeuroBacked = 0;
        emit HedgerFillUpdated(positionId, cachedFilledVolume, 0);
        if (totalFilledExposure < cachedFilledVolume) revert HedgerPoolErrorLibrary.InsufficientHedgerCapacity();
        totalFilledExposure -= cachedFilledVolume;
        
        return cachedFilledVolume;
    }
    // slither-disable-end reentrancy-no-eth
    // slither-disable-end reentrancy-benign

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
        // forge-lint: disable-next-line(unsafe-typecast)
        int256 eff = int256(uint256(p.margin)) + HedgerPoolLogicLibrary.calculatePnL(uint256(p.filledVolume), uint256(p.qeuroBacked), price);
        // forge-lint: disable-next-line(unsafe-typecast)
        return eff > 0 && uint256(eff).mulDiv(10000, uint256(p.filledVolume)) >= coreParams.minMarginRatio;
    }

    /**
     * @notice Allocates user mint exposure to the hedger position
     * @dev Allocates `usdcAmount` to the single hedger position if healthy
     * @param usdcAmount Amount of USDC exposure to allocate (6 decimals)
     * @param currentPrice Current EUR/USD oracle price supplied by the caller (18 decimals)
     * @param qeuroAmount QEURO amount that was minted (18 decimals)
     * @custom:security Caller must ensure hedger position exists
     * @custom:validation Validates liquidity availability and capacity before allocation
     * @custom:state-changes Updates `filledVolume` and `totalFilledExposure`
     * @custom:events Emits `HedgerFillUpdated` for the position
     * @custom:errors Reverts if capacity is insufficient or liquidity is absent
     * @custom:reentrancy Not applicable - internal function
     * @custom:access Internal helper
     * @custom:oracle Requires current oracle price to check position health
     */
    function _increaseFilledVolume(uint256 usdcAmount, uint256 currentPrice, uint256 qeuroAmount) internal {
        if (usdcAmount == 0) return;
        if (currentPrice == 0) revert CommonErrorLibrary.InvalidOraclePrice();
        
        if (singleHedger == address(0)) revert HedgerPoolErrorLibrary.NoActiveHedgerLiquidity();
        uint256 positionId = hedgerActivePositionId[singleHedger];
        if (positionId == 0) revert HedgerPoolErrorLibrary.NoActiveHedgerLiquidity();
        
        HedgePosition storage position = positions[positionId];
        if (!position.isActive) revert HedgerPoolErrorLibrary.NoActiveHedgerLiquidity();
        if (!_isPositionHealthyForFill(position, currentPrice)) revert HedgerPoolErrorLibrary.NoActiveHedgerLiquidity();

        uint256 minMarginRatio = coreParams.minMarginRatio;
        uint256 availableCapacity = HedgerPoolLogicLibrary.calculateCollateralCapacity(
            uint256(position.margin), uint256(position.filledVolume),
            uint256(position.entryPrice), currentPrice, minMarginRatio, position.realizedPnL, position.qeuroBacked
        );

        if (availableCapacity == 0) revert HedgerPoolErrorLibrary.NoActiveHedgerLiquidity();
        if (availableCapacity < usdcAmount) revert HedgerPoolErrorLibrary.InsufficientHedgerCapacity();

        // Allocate to single position (100% of usdcAmount)
        uint256 prevFilled = uint256(position.filledVolume);
        _applyFillChange(positionId, position, usdcAmount, true);
        _updateEntryPriceAfterFill(position, prevFilled, usdcAmount, currentPrice);
        // forge-lint: disable-next-line(unsafe-typecast)
        position.qeuroBacked += uint128(qeuroAmount);
        totalFilledExposure += usdcAmount;
    }

    /**
     * @notice Releases exposure from the hedger position following a user redeem
     * @dev Decreases fills from the single hedger position
     * @param usdcAmount Amount of USDC to release (at redeem price) (6 decimals)
     * @param redeemPrice Current EUR/USD oracle price (18 decimals) for P&L calculation
     * @param qeuroAmount QEURO amount that was redeemed (18 decimals)
     * @custom:security Internal function - validates price and amounts
     * @custom:validation Validates usdcAmount > 0, redeemPrice > 0, and sufficient filled exposure
     * @custom:state-changes Decreases filledVolume, updates totalFilledExposure, calculates realized P&L
     * @custom:events Emits HedgerFillUpdated and RealizedPnLRecorded
     * @custom:errors Reverts with InvalidOraclePrice, NoActiveHedgerLiquidity, or InsufficientHedgerCapacity
     * @custom:reentrancy Not applicable - internal function
     * @custom:access Internal helper only
     * @custom:oracle Uses provided redeemPrice parameter
     */
    function _decreaseFilledVolume(uint256 usdcAmount, uint256 redeemPrice, uint256 qeuroAmount) internal {
        if (usdcAmount == 0) return;
        if (redeemPrice == 0) revert CommonErrorLibrary.InvalidOraclePrice();

        if (singleHedger == address(0)) revert HedgerPoolErrorLibrary.NoActiveHedgerLiquidity();
        uint256 positionId = hedgerActivePositionId[singleHedger];
        if (positionId == 0) revert HedgerPoolErrorLibrary.NoActiveHedgerLiquidity();
        
        HedgePosition storage pos = positions[positionId];
        if (!pos.isActive) revert HedgerPoolErrorLibrary.NoActiveHedgerLiquidity();
        
        uint256 filled = uint256(pos.filledVolume);
        if (filled == 0) revert HedgerPoolErrorLibrary.NoActiveHedgerLiquidity();
        
        // With single position, all qeuroAmount goes to this position (100%)
        uint256 qeuroShare = qeuroAmount;
        if (qeuroShare > uint256(pos.qeuroBacked)) qeuroShare = uint256(pos.qeuroBacked);
        if (qeuroShare == 0) return;
        
        // Calculate share (USDC to decrease from filledVolume) based on qeuroShare being redeemed
        // share = qeuroShare * redeemPrice / 1e30 (convert QEURO to USDC at current price)
        // Cap share to filled to avoid underflow, but this doesn't affect P&L calculation
        uint256 share = qeuroShare.mulDiv(redeemPrice, 1e30);
        if (share > usdcAmount) share = usdcAmount;
        if (share > filled) share = filled;
        if (share == 0) return;
        
        // Emit event for debugging qeuroShare calculation
        emit QeuroShareCalculated(positionId, qeuroShare, uint256(pos.qeuroBacked), uint256(pos.qeuroBacked));
        
        // Process redemption with new realized P&L formula
        // Use qeuroShare (full amount) for P&L calculation to realize all remaining unrealized P&L
        // This ensures we realize P&L for ALL QEURO being redeemed, regardless of filledVolume
        _processRedeem(positionId, pos, share, filled, redeemPrice, qeuroShare);

        // Decrease qeuroBacked
        // forge-lint: disable-next-line(unsafe-typecast)
        pos.qeuroBacked = qeuroShare <= uint256(pos.qeuroBacked) ? pos.qeuroBacked - uint128(qeuroShare) : 0;
        totalFilledExposure -= share;
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
        // forge-lint: disable-next-line(unsafe-typecast)
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
        // forge-lint: disable-next-line(unsafe-typecast)
        if (prevFilled == 0 || pos.filledVolume == 0) { pos.entryPrice = uint96(price); return; }
        // Weighted average: newEntry = totalUSDC * oldEntry * price / (prevUSDC * price + delta * oldEntry)
        uint256 old = uint256(pos.entryPrice);
        // forge-lint: disable-next-line(unsafe-typecast)
        pos.entryPrice = uint96((uint256(pos.filledVolume) * old * price) / (prevFilled * price + delta * old));
    }

    /**
     * @notice Processes redemption for a single position - calculates realized P&L
     * @dev New formula: RealizedP&L = QEUROQuantitySold * (entryPrice - OracleCurrentPrice)
     *      Hedgers are SHORT EUR, so they profit when EUR price decreases
     * @param posId ID of the position being processed
     * @param pos Storage pointer to the position struct
     * @param share Amount of USDC exposure being released (6 decimals)
     * @param filledBefore Filled volume before redemption (used for P&L calculation)
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
    /**
     * @notice Calculates and records realized P&L during QEURO redemption
     * @dev Called by _decreaseFilledVolume for normal (non-liquidation) redemptions
     * 
     * P&L Calculation Formula:
     * 1. totalUnrealizedPnL = filledVolume - (qeuroBacked × price / 1e30)
     * 2. netUnrealizedPnL = totalUnrealizedPnL - realizedPnL
     *    (avoids double-counting since margin already reflects realized P&L)
     * 3. realizedDelta = (qeuroAmount / qeuroBacked) × netUnrealizedPnL
     * 
     * After calculation:
     * - If realizedDelta > 0 (profit): margin increases
     * - If realizedDelta < 0 (loss): margin decreases
     * - realizedPnL accumulates the realized portion
     * 
     * @param posId Position ID being processed
     * @param pos Storage reference to the position
     * @param share Amount of filledVolume being released (6 decimals)
     * @param filledBefore filledVolume BEFORE this redemption (6 decimals)
     * @param price Current EUR/USD oracle price (18 decimals)
     * @param qeuroAmount QEURO amount being redeemed (18 decimals)
     * @custom:security Internal function - updates position state and margin
     * @custom:validation Validates share > 0, qeuroAmount > 0, price > 0, qeuroBacked > 0
     * @custom:state-changes Updates pos.realizedPnL, pos.margin, totalMargin, pos.positionSize
     * @custom:events Emits RealizedPnLRecorded, RealizedPnLCalculation, MarginUpdated, HedgerFillUpdated
     * @custom:errors None - early returns for invalid states
     * @custom:reentrancy Not applicable - internal function, no external calls
     * @custom:access Internal helper only - called by _decreaseFilledVolume
     * @custom:oracle Uses provided price parameter (must be fresh oracle data)
     */
    function _processRedeem(uint256 posId, HedgePosition storage pos, uint256 share, uint256 filledBefore, uint256 price, uint256 qeuroAmount) internal {
        if (share > 0 && qeuroAmount > 0 && price > 0) {
            uint256 currentQeuroBacked = uint256(pos.qeuroBacked);

            if (currentQeuroBacked > 0 && filledBefore > 0) {
                // Calculate P&L values
                (int256 totalUnrealizedPnL, int256 realizedDelta) = _calculateRedeemPnL(
                    currentQeuroBacked, filledBefore, price, qeuroAmount, pos.realizedPnL
                );

                // Record realized P&L
                // forge-lint: disable-next-line(unsafe-typecast)
                pos.realizedPnL += int128(realizedDelta);
                emit RealizedPnLRecorded(posId, realizedDelta, int256(pos.realizedPnL));
                emit RealizedPnLCalculation(posId, qeuroAmount, currentQeuroBacked, filledBefore, price, totalUnrealizedPnL, realizedDelta);

                // Apply P&L to margin
                _applyRealizedPnLToMargin(posId, pos, realizedDelta);
            }
        }
        _applyFillChange(posId, pos, share, false);
        // Note: unrealized P&L will be updated in _decreaseFilledVolume after qeuroBacked is updated
    }

    /**
     * @notice Calculates unrealized and realized P&L for redemption
     * @param currentQeuroBacked Current QEURO backed by position
     * @param filledBefore Filled volume before redemption
     * @param price Current EUR/USD price
     * @param qeuroAmount Amount of QEURO being redeemed
     * @param previousRealizedPnL Previously realized P&L
     * @return totalUnrealizedPnL Total unrealized P&L (mark-to-market)
     * @return realizedDelta Realized P&L delta for this redemption
     */
    function _calculateRedeemPnL(
        uint256 currentQeuroBacked,
        uint256 filledBefore,
        uint256 price,
        uint256 qeuroAmount,
        int128 previousRealizedPnL
    ) internal pure returns (int256 totalUnrealizedPnL, int256 realizedDelta) {
        // Step 1: Calculate total unrealized P&L (mark-to-market)
        uint256 qeuroValueInUSDC = currentQeuroBacked.mulDiv(price, 1e30);
        // forge-lint: disable-next-line(unsafe-typecast)
        totalUnrealizedPnL = filledBefore >= qeuroValueInUSDC
            ? int256(filledBefore - qeuroValueInUSDC)
            : -int256(qeuroValueInUSDC - filledBefore);

        // Step 2: Calculate NET unrealized P&L (subtract already-realized portion)
        int256 netUnrealizedPnL = totalUnrealizedPnL - int256(previousRealizedPnL);

        // Step 3: Calculate the realized P&L delta for this redemption
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 absNetPnL = netUnrealizedPnL >= 0 ? uint256(netUnrealizedPnL) : uint256(-netUnrealizedPnL);
        uint256 pnlShare = qeuroAmount.mulDiv(absNetPnL, currentQeuroBacked);
        // forge-lint: disable-next-line(unsafe-typecast)
        realizedDelta = netUnrealizedPnL >= 0 ? int256(pnlShare) : -int256(pnlShare);
    }

    /**
     * @notice Applies realized P&L to position margin
     * @param posId Position ID
     * @param pos Position storage reference
     * @param realizedDelta Realized P&L amount (positive = profit, negative = loss)
     */
    function _applyRealizedPnLToMargin(uint256 posId, HedgePosition storage pos, int256 realizedDelta) internal {
        if (realizedDelta > 0) {
            _applyProfitToMargin(posId, pos, realizedDelta);
        } else if (realizedDelta < 0) {
            _applyLossToMargin(posId, pos, realizedDelta);
        }
    }

    /**
     * @notice Applies profit to hedger margin
     * @param posId Position ID
     * @param pos Position storage reference
     * @param realizedDelta Positive realized P&L amount
     */
    function _applyProfitToMargin(uint256 posId, HedgePosition storage pos, int256 realizedDelta) internal {
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 profitAmount = uint256(realizedDelta);
        uint256 currentMargin = uint256(pos.margin);
        uint256 newMargin = currentMargin + profitAmount;

        // Update margin (cap at max uint96)
        if (newMargin > type(uint96).max) {
            pos.margin = type(uint96).max;
            totalMargin = totalMargin - currentMargin + type(uint96).max;
        } else {
            // forge-lint: disable-next-line(unsafe-typecast)
            pos.margin = uint96(newMargin);
            totalMargin += profitAmount;
        }

        // Recalculate positionSize to maintain leverage ratio
        _updatePositionSize(pos);

        // Emit margin update event
        uint256 newMarginRatio = _calculateMarginRatio(pos);
        emit MarginUpdated(
            pos.hedger,
            posId,
            HedgerPoolOptimizationLibrary.packMarginData(profitAmount, newMarginRatio, true)
        );
    }

    /**
     * @notice Applies loss to hedger margin
     * @param posId Position ID
     * @param pos Position storage reference
     * @param realizedDelta Negative realized P&L amount
     */
    function _applyLossToMargin(uint256 posId, HedgePosition storage pos, int256 realizedDelta) internal {
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 lossAmount = uint256(-realizedDelta);
        uint256 currentMargin = uint256(pos.margin);

        // Reduce margin by loss amount, but don't go below zero
        if (lossAmount > currentMargin) {
            // If loss exceeds margin, reduce margin to zero
            totalMargin -= currentMargin;
            pos.margin = 0;
            pos.positionSize = 0;
        } else {
            // Normal case: reduce margin by loss amount
            uint256 newMargin = currentMargin - lossAmount;
            // forge-lint: disable-next-line(unsafe-typecast)
            pos.margin = uint96(newMargin);
            totalMargin -= lossAmount;

            // Recalculate positionSize to maintain leverage ratio
            _updatePositionSize(pos);
        }

        // Emit margin update event
        uint256 newMarginRatio = _calculateMarginRatio(pos);
        emit MarginUpdated(
            pos.hedger,
            posId,
            HedgerPoolOptimizationLibrary.packMarginData(lossAmount, newMarginRatio, false)
        );
    }

    /**
     * @notice Updates position size based on current margin and leverage
     * @param pos Position storage reference
     */
    function _updatePositionSize(HedgePosition storage pos) internal {
        uint256 leverageValue = uint256(pos.leverage);
        uint256 newPositionSize = uint256(pos.margin) * leverageValue;
        if (newPositionSize > type(uint96).max) {
            pos.positionSize = type(uint96).max;
        } else {
            // forge-lint: disable-next-line(unsafe-typecast)
            pos.positionSize = uint96(newPositionSize);
        }
    }

    /**
     * @notice Calculates margin ratio for a position
     * @param pos Position storage reference
     * @return Margin ratio in basis points (0 if position has no size)
     */
    function _calculateMarginRatio(HedgePosition storage pos) internal view returns (uint256) {
        if (pos.margin == 0 || pos.positionSize == 0) return 0;
        return (uint256(pos.margin) * 10000) / uint256(pos.positionSize);
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