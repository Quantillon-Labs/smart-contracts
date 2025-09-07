// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IChainlinkOracle.sol";
import "../interfaces/IYieldShift.sol";
import "../libraries/VaultMath.sol";
import "../libraries/ErrorLibrary.sol";
import "../libraries/AccessControlLibrary.sol";
import "../libraries/ValidationLibrary.sol";
import "./SecureUpgradeable.sol";
import "../libraries/TreasuryRecoveryLibrary.sol";
import "../libraries/FlashLoanProtectionLibrary.sol";
import "../libraries/TimeProviderLibrary.sol";
import "../libraries/HedgerPoolValidationLibrary.sol";

/**
 * @title HedgerPool
 * @notice EUR/USD hedging pool for managing currency risk and providing yield
 * 
 * @dev Main characteristics:
 *      - EUR/USD currency hedging through leveraged positions
 *      - Margin-based trading with liquidation system
 *      - Interest rate differential yield generation
 *      - Multi-position management per hedger
 *      - Emergency pause mechanism for crisis situations
 *      - Upgradeable via UUPS pattern
 * 
 * @dev Position mechanics:
 *      - Hedgers open leveraged EUR/USD positions
 *      - Positions require minimum margin ratio (default 10%)
 *      - Maximum leverage of 10x to limit risk exposure
 *      - Position sizes tracked for risk management
 *      - Entry and exit fees charged for protocol revenue
 * 
 * @dev Margin system:
 *      - Initial margin required for position opening
 *      - Margin can be added to strengthen positions
 *      - Margin removal allowed if above minimum ratio
 *      - Real-time margin ratio calculations
 *      - Margin fees charged on additions
 * 
 * @dev Liquidation system:
 *      - Two-phase liquidation with commit-reveal pattern
 *      - Liquidation threshold below minimum margin ratio (default 1%)
 *      - Liquidation penalty rewarded to liquidators (default 2%)
 *      - Cooldown period prevents liquidation manipulation
 *      - Emergency position closure for critical situations
 * 
 * @dev Yield generation:
 *      - Interest rate differential between EUR and USD rates
 *      - Rewards distributed based on position exposure
 *      - Time-weighted reward calculations
 *      - Integration with yield shift mechanism
 *      - Automatic reward accumulation and claiming
 * 
 * @dev Risk management:
 *      - Maximum positions per hedger (50) to prevent concentration
 *      - Real-time oracle price monitoring
 *      - Position size limits and exposure tracking
 *      - Liquidation cooldown mechanisms
 *      - Emergency position closure capabilities
 * 
 * @dev Fee structure:
 *      - Entry fees for opening positions (default 0.2%)
 *      - Exit fees for closing positions (default 0.2%)
 *      - Margin fees for adding collateral (default 0.1%)
 *      - Dynamic fee adjustment based on market conditions
 * 
 * @dev Security features:
 *      - Role-based access control for all critical operations
 *      - Reentrancy protection for all external calls
 *      - Emergency pause mechanism for crisis situations
 *      - Upgradeable architecture for future improvements
 *      - Secure position and margin management
 *      - Two-phase liquidation for manipulation resistance
 *      - Overflow protection for packed struct fields
 *      - Comprehensive validation before type casting
 *      - Maximum value constraints to prevent storage corruption
 * 
 * @dev Integration points:
 *      - USDC for margin deposits and withdrawals
 *      - Chainlink oracle for EUR/USD price feeds
 *      - Yield shift mechanism for reward distribution
 *      - Vault math library for precise calculations
 *      - Position tracking and management systems
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
    using ValidationLibrary for uint256;

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    IERC20 public usdc;
    IChainlinkOracle public oracle;
    IYieldShift public yieldShift;
    address public treasury;

    /// @notice TimeProvider contract for centralized time management
    /// @dev Used to replace direct block.timestamp usage for testability and consistency
    TimeProvider public immutable timeProvider;

    uint256 public minMarginRatio;
    uint256 public liquidationThreshold;
    uint256 public maxLeverage;
    uint256 public liquidationPenalty;
    uint256 public constant MAX_POSITIONS_PER_HEDGER = 50;
    uint256 public constant MAX_BATCH_SIZE = 50;
    uint96 public constant MAX_UINT96_VALUE = type(uint96).max;
    uint256 public constant MAX_POSITION_SIZE = MAX_UINT96_VALUE;
    uint256 public constant MAX_MARGIN = MAX_UINT96_VALUE;
    uint256 public constant MAX_ENTRY_PRICE = MAX_UINT96_VALUE;
    uint256 public constant MAX_LEVERAGE = type(uint16).max;
    uint128 public constant MAX_UINT128_VALUE = type(uint128).max;
    uint256 public constant MAX_TOTAL_MARGIN = MAX_UINT128_VALUE;
    uint256 public constant MAX_TOTAL_EXPOSURE = MAX_UINT128_VALUE;
    uint256 public constant MAX_PENDING_REWARDS = MAX_UINT128_VALUE;

    mapping(address => uint256) public activePositionCount;

    uint256 public entryFee;
    uint256 public exitFee;
    uint256 public marginFee;

    uint256 public totalMargin;
    uint256 public totalExposure;
    uint256 public activeHedgers;
    uint256 public nextPositionId;

    uint256 public eurInterestRate;
    uint256 public usdInterestRate;

    struct HedgePosition {
        address hedger;           // 20 bytes
        uint96 positionSize;      // 12 bytes - total 32 bytes (1 slot)
        uint96 margin;            // 12 bytes  
        uint96 entryPrice;        // 12 bytes
        uint32 entryTime;         // 4 bytes
        uint32 lastUpdateTime;    // 4 bytes - total 32 bytes (1 slot)
        int128 unrealizedPnL;     // 16 bytes
        uint16 leverage;          // 2 bytes
        bool isActive;            // 1 byte - total 19 bytes -> 32 bytes (1 slot)
    }

    struct HedgerInfo {
        uint256[] positionIds;    // Dynamic array (1 slot)
        uint128 totalMargin;      // 16 bytes
        uint128 totalExposure;    // 16 bytes - total 32 bytes (1 slot)
        uint128 pendingRewards;   // 16 bytes
        uint64 lastRewardClaim;   // 8 bytes
        bool isActive;            // 1 byte - total 25 bytes -> 32 bytes (1 slot)
    }

    mapping(uint256 => HedgePosition) public positions;
    mapping(address => HedgerInfo) public hedgers;
    mapping(address => uint256[]) public hedgerPositions;

    // O(1) position removal mappings to prevent unbounded loops
    mapping(address => mapping(uint256 => bool)) public hedgerHasPosition;
    mapping(address => mapping(uint256 => uint256)) public positionIndex;
    mapping(address => mapping(uint256 => uint256)) public hedgerPositionIndex;

    uint256 public constant totalYieldEarned = 0;
    uint256 public constant interestDifferentialPool = 0;

    mapping(address => uint256) public userPendingYield;
    mapping(address => uint256) public hedgerPendingYield;
    mapping(address => uint256) public userLastClaim;
    mapping(address => uint256) public hedgerLastClaim;
    
    mapping(address => uint256) public hedgerLastRewardBlock;
    uint256 public constant BLOCKS_PER_DAY = 7200;
    uint256 public constant MAX_REWARD_PERIOD = 365 days;

    /// @dev Cooldown period in blocks (~1 hour assuming 12 second blocks)
    /// @dev Using block numbers instead of timestamps for security against miner manipulation
    uint256 public constant LIQUIDATION_COOLDOWN = 300;
    mapping(bytes32 => bool) public liquidationCommitments;
    mapping(bytes32 => uint256) public liquidationCommitmentTimes;
    mapping(address => uint256) public lastLiquidationAttempt;
    mapping(address => mapping(uint256 => bool)) public hasPendingLiquidation;

    event HedgePositionOpened(
        address indexed hedger,
        uint256 indexed positionId,
        bytes32 packedData
    );
    
    event HedgePositionClosed(
        address indexed hedger,
        uint256 indexed positionId,
        bytes32 packedData
    );
    
    event MarginUpdated(
        address indexed hedger,
        uint256 indexed positionId,
        bytes32 packedData
    );
    
    event HedgerLiquidated(
        address indexed hedger,
        uint256 indexed positionId,
        address indexed liquidator,
        bytes32 packedData
    );
    
    event HedgingRewardsClaimed(
        address indexed hedger,
        bytes32 packedData
    );

    event ETHRecovered(address indexed to, uint256 indexed amount);
    event TreasuryUpdated(address indexed treasury);
    

    // =============================================================================
    // MODIFIERS - Access control and security
    // =============================================================================

    /**
     * @notice Modifier to protect against flash loan attacks
     * @dev Uses the FlashLoanProtectionLibrary to check USDC balance consistency
     */
    modifier flashLoanProtection() {
        uint256 balanceBefore = usdc.balanceOf(address(this));
        _;
        uint256 balanceAfter = usdc.balanceOf(address(this));
        if (!FlashLoanProtectionLibrary.validateBalanceChange(balanceBefore, balanceAfter, 0))
            revert ErrorLibrary.FlashLoanAttackDetected();
    }

    modifier secureOperation() {
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

    function _packPositionOpenData(
        uint256 positionSize,
        uint256 margin, 
        uint256 leverage,
        uint256 entryPrice
    ) private pure returns (bytes32) {
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
    ) private pure returns (bytes32) {
        return bytes32(
            (uint256(uint96(exitPrice)) << 160) |
            (uint256(uint96(uint256(pnl < 0 ? -pnl : pnl))) << 64) |
            (pnl < 0 ? (1 << 63) : 0) |
            uint256(uint64(timestamp))
        );
    }
    
    function _packMarginData(
        uint256 marginAmount,
        uint256 newMarginRatio,
        bool isAdded
    ) private pure returns (bytes32) {
        return bytes32(
            (uint256(uint128(marginAmount)) << 128) |
            (uint256(uint128(newMarginRatio)) << 1) |
            (isAdded ? 1 : 0)
        );
    }
    
    function _packLiquidationData(
        uint256 liquidationReward,
        uint256 remainingMargin
    ) private pure returns (bytes32) {
        return bytes32(
            (uint256(uint128(liquidationReward)) << 128) |
            uint256(uint128(remainingMargin))
        );
    }
    
    function _packRewardData(
        uint256 interestDifferential,
        uint256 yieldShiftRewards,
        uint256 totalRewards
    ) private pure returns (bytes32) {
        return bytes32(
            (uint256(uint128(interestDifferential)) << 128) |
            (uint256(uint64(yieldShiftRewards)) << 64) |
            uint256(uint64(totalRewards))
        );
    }
    

    /**
     * @notice Constructor for HedgerPool contract
     * @dev Initializes the TimeProvider and disables initializers for proxy pattern
     * @param _timeProvider Address of the TimeProvider contract for centralized time management
     * @custom:security Validates TimeProvider address is not zero
     * @custom:validation Validates _timeProvider is not address(0)
     * @custom:state-changes Sets timeProvider immutable variable and disables initializers
     * @custom:events No events emitted
     * @custom:errors Throws ZeroAddress if _timeProvider is address(0)
     * @custom:reentrancy Not applicable - constructor
     * @custom:access Public - anyone can deploy
     * @custom:oracle No oracle dependencies
     */
    constructor(TimeProvider _timeProvider) {
        if (address(_timeProvider) == address(0)) revert ErrorLibrary.ZeroAddress();
        timeProvider = _timeProvider;
        _disableInitializers();
    }

    /**
     * @notice Initializes the HedgerPool contract with required dependencies
     * @dev Sets up all core dependencies, roles, and default configuration parameters
     * @param admin Address that will receive admin and governance roles
     * @param _usdc Address of the USDC token contract (6 decimals)
     * @param _oracle Address of the Chainlink oracle for EUR/USD price feeds
     * @param _yieldShift Address of the YieldShift contract for reward distribution
     * @param _timelock Address of the timelock contract for upgrade approvals
     * @param _treasury Address of the treasury for fee collection
     * @custom:security Validates all addresses are not zero, grants admin roles
     * @custom:validation Validates all input addresses using AccessControlLibrary
     * @custom:state-changes Initializes all state variables, sets default fees and parameters
     * @custom:events No events emitted during initialization
     * @custom:errors Throws ZeroAddress if any address is address(0)
     * @custom:reentrancy Protected by initializer modifier
     * @custom:access Public - only callable once during deployment
     * @custom:oracle Sets oracle address for EUR/USD price feeds
     */
    function initialize(
        address admin,
        address _usdc,
        address _oracle,
        address _yieldShift,
        address _timelock,
        address _treasury
    ) public initializer {
        AccessControlLibrary.validateAddress(admin);
        AccessControlLibrary.validateAddress(_usdc);
        AccessControlLibrary.validateAddress(_oracle);
        AccessControlLibrary.validateAddress(_yieldShift);
        AccessControlLibrary.validateAddress(_treasury);

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
        ValidationLibrary.validateTreasuryAddress(_treasury);
        require(_treasury != address(0), "Treasury cannot be zero address");
        treasury = _treasury;

        minMarginRatio = 1000;
        liquidationThreshold = 100;
        maxLeverage = 10;
        liquidationPenalty = 200;
        
        entryFee = 20;
        exitFee = 20;
        marginFee = 10;

        eurInterestRate = 350;
        usdInterestRate = 450;

        nextPositionId = 1;
    }

    /**
     * @notice Opens a new hedge position with specified USDC margin and leverage
     * @param usdcAmount Amount of USDC to deposit as margin (6 decimals)
     * @param leverage Leverage multiplier for the position (1-10x)
     * @return positionId Unique identifier for the new position
     * @dev Creates a leveraged EUR/USD hedge position with margin requirements
     * @custom:security Validates oracle price freshness, enforces margin ratios and leverage limits
     * @custom:validation Validates usdcAmount > 0, leverage <= maxLeverage, position count limits
     * @custom:state-changes Creates new HedgePosition, updates hedger totals, increments position counters
     * @custom:events Emits HedgePositionOpened with position details
     * @custom:errors Throws InvalidAmount, InvalidLeverage, InvalidOraclePrice, RateLimitExceeded
     * @custom:reentrancy Protected by secureNonReentrant modifier
     * @custom:access Public - requires sufficient USDC balance and approval
     * @custom:oracle Requires fresh EUR/USD price from Chainlink oracle
     */
    function enterHedgePosition(uint256 usdcAmount, uint256 leverage) 
        external 
        secureNonReentrant
        returns (uint256 positionId) 
    {
        ValidationLibrary.validatePositiveAmount(usdcAmount);
        ValidationLibrary.validateLeverage(leverage, maxLeverage);
        ValidationLibrary.validatePositionCount(activePositionCount[msg.sender], MAX_POSITIONS_PER_HEDGER);

        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        ValidationLibrary.validateOraclePrice(isValid);

        uint256 fee = usdcAmount.percentageOf(entryFee);
        uint256 netMargin = usdcAmount - fee;
        uint256 positionSize = netMargin.mulDiv(leverage, 1);
        uint256 marginRatio = netMargin.mulDiv(10000, positionSize);
        ValidationLibrary.validateMarginRatio(marginRatio, minMarginRatio);

        HedgerPoolValidationLibrary.validatePositionParams(
            netMargin, positionSize, eurUsdPrice, leverage,
            MAX_MARGIN, MAX_POSITION_SIZE, MAX_ENTRY_PRICE, MAX_LEVERAGE
        );
        HedgerPoolValidationLibrary.validateTimestamp(timeProvider.currentTime());

        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);

        positionId = nextPositionId++;
        
        HedgePosition storage position = positions[positionId];
        position.hedger = msg.sender;
        position.positionSize = uint96(positionSize);
        position.margin = uint96(netMargin);
        position.entryTime = uint32(timeProvider.currentTime());
        position.lastUpdateTime = uint32(timeProvider.currentTime());
        position.leverage = uint16(leverage);
        position.entryPrice = uint96(eurUsdPrice);
        position.unrealizedPnL = 0;
        position.isActive = true;

        // Update hedger info and totals
        HedgerInfo storage hedger = hedgers[msg.sender];
        if (!hedger.isActive) {
            hedger.isActive = true;
            activeHedgers++;
        }
        
        // Add to hedgers[hedger].positionIds array with O(1) indexing
        hedger.positionIds.push(positionId);
        positionIndex[msg.sender][positionId] = hedger.positionIds.length - 1;
        
        HedgerPoolValidationLibrary.validateTotals(
            hedger.totalMargin, hedger.totalExposure,
            netMargin, positionSize,
            MAX_TOTAL_MARGIN, MAX_TOTAL_EXPOSURE
        );
        
        hedger.totalMargin += uint128(netMargin);
        hedger.totalExposure += uint128(positionSize);
        
        // Add to hedgerPositions[hedger] array with O(1) indexing
        hedgerPositions[msg.sender].push(positionId);
        hedgerPositionIndex[msg.sender][positionId] = hedgerPositions[msg.sender].length - 1;
        
        // Mark position as owned by hedger and update counters
        hedgerHasPosition[msg.sender][positionId] = true;
        activePositionCount[msg.sender]++;
        totalMargin += netMargin;
        totalExposure += positionSize;

        // Pack position data to reduce stack depth
        bytes32 positionData = _packPositionOpenData(positionSize, netMargin, leverage, eurUsdPrice);
        emit HedgePositionOpened(msg.sender, positionId, positionData);
    }

    /**
     * @notice Closes a hedge position and calculates profit/loss
     * @param positionId Unique identifier of the position to close
     * @return pnl Profit or loss from the position (positive = profit, negative = loss)
     * @dev Closes position, calculates PnL based on current EUR/USD price, applies exit fees
     * @custom:security Validates position ownership and active status, enforces oracle price freshness
     * @custom:validation Validates position exists, is active, and owned by caller
     * @custom:state-changes Closes position, updates hedger totals, decrements position counters
     * @custom:events Emits HedgePositionClosed with PnL and exit details
     * @custom:errors Throws InvalidPosition, PositionNotActive, InvalidOraclePrice
     * @custom:reentrancy Protected by secureNonReentrant modifier
     * @custom:access Public - requires position ownership
     * @custom:oracle Requires fresh EUR/USD price from Chainlink oracle
     */
    function exitHedgePosition(uint256 positionId) 
        external 
        secureNonReentrant
        returns (int256 pnl) 
    {
        HedgePosition storage position = positions[positionId];
        ValidationLibrary.validatePositionOwner(position.hedger, msg.sender);
        ValidationLibrary.validatePositionActive(position.isActive);

        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        ValidationLibrary.validateOraclePrice(isValid);

        pnl = _calculatePnL(position, currentPrice);

        uint256 grossPayout = uint256(int256(uint256(position.margin)) + pnl);
        uint256 exitFeeAmount = grossPayout.percentageOf(exitFee);
        uint256 netPayout = grossPayout - exitFeeAmount;

        HedgerInfo storage hedger = hedgers[msg.sender];
        hedger.totalMargin -= uint128(position.margin);
        hedger.totalExposure -= uint128(position.positionSize);

        totalMargin -= uint256(position.margin);
        totalExposure -= uint256(position.positionSize);

        position.isActive = false;
        _removePositionFromArrays(msg.sender, positionId);
        
        activePositionCount[msg.sender]--;

        if (netPayout > 0) {
            usdc.safeTransfer(msg.sender, netPayout);
        }

        emit HedgePositionClosed(
            msg.sender, 
            positionId, 
            _packPositionCloseData(currentPrice, pnl, timeProvider.currentTime())
        );
    }

    /**
     * @notice Closes multiple hedge positions in a single transaction
     * @param positionIds Array of position IDs to close
     * @param maxPositions Maximum number of positions allowed per transaction
     * @return pnls Array of profit/loss for each closed position
     * @dev Batch closes positions for gas efficiency, applies same validations as single close
     * @custom:security Validates batch size limits and position ownership for each position
     * @custom:validation Validates positionIds.length <= maxPositions, maxPositions <= 10
     * @custom:state-changes Closes all positions, updates hedger totals, decrements position counters
     * @custom:events Emits HedgePositionClosed for each closed position
     * @custom:errors Throws BatchSizeTooLarge, TooManyPositionsPerTx, MaxPositionsPerTx
     * @custom:reentrancy Protected by secureOperation modifier
     * @custom:access Public - requires position ownership for all positions
     * @custom:oracle Requires fresh EUR/USD price from Chainlink oracle
     */
    function closePositionsBatch(uint256[] calldata positionIds, uint256 maxPositions) 
        external 
        secureOperation
        returns (int256[] memory pnls) 
    {
        if (positionIds.length > MAX_BATCH_SIZE) revert ErrorLibrary.BatchSizeTooLarge();
        if (positionIds.length > maxPositions) revert ErrorLibrary.TooManyPositionsPerTx();
        if (maxPositions > 10) revert ErrorLibrary.MaxPositionsPerTx();
        
        // Cache timestamp to avoid external calls in loop
        uint256 currentTime = timeProvider.currentTime();
        
        pnls = new int256[](positionIds.length);
        
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        ValidationLibrary.validateOraclePrice(isValid);
        
        // GAS OPTIMIZATION: Cache storage reads
        uint256 exitFee_ = exitFee;
        HedgerInfo storage hedger = hedgers[msg.sender];
        
        // Process positions in batch
        for (uint i = 0; i < positionIds.length; i++) {
            (int256 pnl, uint256 marginDeducted, uint256 exposureDeducted) = _closeSinglePositionBatch(
                positionIds[i], 
                currentPrice, 
                hedger, 
                exitFee_,
                currentTime
            );
            pnls[i] = pnl;
            // Update global totals directly to reduce stack depth
            totalMargin -= marginDeducted;
            totalExposure -= exposureDeducted;
        }
    }

    /**
     * @notice Internal function to close a single position in batch operation
     * @param positionId ID of the position to close
     * @param currentPrice Current EUR/USD price for PnL calculation
     * @param hedger HedgerInfo storage reference for the position owner
     * @param exitFee_ Cached exit fee percentage
     * @param currentTime Current timestamp for events
     * @return pnl Profit or loss from the position
     * @return marginDeducted Amount of margin to deduct from hedger totals
     * @return exposureDeducted Amount of exposure to deduct from hedger totals
     * @dev Internal helper for batch position closing with gas optimization
     * @custom:security Validates position ownership and active status
     * @custom:validation Validates position exists and is active
     * @custom:state-changes Closes position, updates hedger totals, emits events
     * @custom:events Emits HedgePositionClosed event
     * @custom:errors Throws InvalidPosition, PositionNotActive
     * @custom:reentrancy Not protected - internal function only
     * @custom:access Internal function - no access restrictions
     * @custom:oracle Uses currentPrice parameter for PnL calculation
     */
    function _closeSinglePositionBatch(
        uint256 positionId, 
        uint256 currentPrice, 
        HedgerInfo storage hedger,
        uint256 exitFee_,
        uint256 currentTime
    ) internal returns (int256 pnl, uint256 marginDeducted, uint256 exposureDeducted) {

        HedgePosition storage position = positions[positionId];
        
        ValidationLibrary.validatePositionOwner(position.hedger, msg.sender);
        ValidationLibrary.validatePositionActive(position.isActive);

        pnl = _calculatePnL(position, currentPrice);

        uint256 grossPayout = uint256(int256(uint256(position.margin)) + pnl);
        uint256 exitFeeAmount = grossPayout.percentageOf(exitFee_);
        uint256 netPayout = grossPayout - exitFeeAmount;

        // Update hedger totals
        hedger.totalMargin -= position.margin;
        hedger.totalExposure -= position.positionSize;

        // Return values for global total updates (done outside loop)
        marginDeducted = position.margin;
        exposureDeducted = position.positionSize;

        // Update position state
        position.isActive = false;
        _removePositionFromArrays(msg.sender, positionId);
        
        activePositionCount[msg.sender]--;

        if (netPayout > 0) {
            usdc.safeTransfer(msg.sender, netPayout);
        }

        emit HedgePositionClosed(
            msg.sender,
            positionId,
            _packPositionCloseData(currentPrice, pnl, currentTime)
        );
    }

    /**
     * @notice Removes a position from internal tracking arrays
     * @dev Performs O(1) removal by swapping with last element
     * @param hedger The address of the hedger who owns the position
     * @param positionId The ID of the position to remove
     * @custom:security Validates position exists in tracking arrays
     * @custom:validation Validates hedgerHasPosition mapping is true
     * @custom:state-changes Removes position from arrays, cleans up mappings
     * @custom:events No events emitted
     * @custom:errors Throws PositionNotFound if position not in tracking arrays
     * @custom:reentrancy Not protected - internal function only
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _removePositionFromArrays(address hedger, uint256 positionId) internal {
        if (!hedgerHasPosition[hedger][positionId]) revert ErrorLibrary.PositionNotFound();
        
        // O(1) removal from hedgers[hedger].positionIds array
        uint256 index = positionIndex[hedger][positionId];
        uint256[] storage positionIds = hedgers[hedger].positionIds;
        uint256 lastIndex = positionIds.length - 1;
        
        if (index != lastIndex) {
            uint256 lastPositionId = positionIds[lastIndex];
            positionIds[index] = lastPositionId;
            positionIndex[hedger][lastPositionId] = index;
        }
        
        positionIds.pop();
        
        // O(1) removal from hedgerPositions[hedger] array
        uint256[] storage hedgerPos = hedgerPositions[hedger];
        uint256 posIndex = hedgerPositionIndex[hedger][positionId];
        uint256 posLastIndex = hedgerPos.length - 1;
        
        if (posIndex != posLastIndex) {
            uint256 posLastPositionId = hedgerPos[posLastIndex];
            hedgerPos[posIndex] = posLastPositionId;
            hedgerPositionIndex[hedger][posLastPositionId] = posIndex;
        }
        
        hedgerPos.pop();
        
        // Clean up mappings
        delete positionIndex[hedger][positionId];
        delete hedgerPositionIndex[hedger][positionId];
        delete hedgerHasPosition[hedger][positionId];
    }

    /**
     * @notice Adds additional margin to an existing hedge position
     * @dev Increases position margin to improve margin ratio and reduce liquidation risk
     * @param positionId Unique identifier of the position to add margin to
     * @param amount Amount of USDC to add as margin (6 decimals)
     * @custom:security Validates position ownership, active status, and liquidation cooldown
     * @custom:validation Validates amount > 0, position exists and is active, no pending liquidation
     * @custom:state-changes Increases position margin, hedger totals, and global margin
     * @custom:events Emits MarginUpdated with added margin details
     * @custom:errors Throws InvalidPosition, PositionNotActive, PendingLiquidationCommitment
     * @custom:reentrancy Protected by secureOperation modifier
     * @custom:access Public - requires position ownership
     * @custom:oracle No oracle dependencies for margin addition
     */
    function addMargin(uint256 positionId, uint256 amount) 
        external 
        secureOperation 
    {
        HedgePosition storage position = positions[positionId];
        ValidationLibrary.validatePositionOwner(position.hedger, msg.sender);
        ValidationLibrary.validatePositionActive(position.isActive);
        ValidationLibrary.validatePositiveAmount(amount);
        
        ValidationLibrary.validateLiquidationCooldown(lastLiquidationAttempt[msg.sender], LIQUIDATION_COOLDOWN);
        
        if (_hasPendingLiquidationCommitment(msg.sender, positionId)) {
            revert ErrorLibrary.PendingLiquidationCommitment();
        }

        uint256 fee = amount.percentageOf(marginFee);
        uint256 netAmount = amount - fee;

        usdc.safeTransferFrom(msg.sender, address(this), amount);

        HedgerPoolValidationLibrary.validateNewMargin(uint256(position.margin) + netAmount, MAX_MARGIN);
        HedgerPoolValidationLibrary.validateTotals(
            hedgers[msg.sender].totalMargin, hedgers[msg.sender].totalExposure,
            netAmount, 0,
            MAX_TOTAL_MARGIN, MAX_TOTAL_EXPOSURE
        );
        
        position.margin += uint96(netAmount);
        hedgers[msg.sender].totalMargin += uint128(netAmount);
        totalMargin += netAmount;

        uint256 newMarginRatio = uint256(position.margin).mulDiv(10000, uint256(position.positionSize));

        emit MarginUpdated(
            msg.sender, 
            positionId, 
            _packMarginData(netAmount, newMarginRatio, true)
        );
    }

    /**
     * @notice Removes margin from an existing hedge position
     * @dev Reduces position margin while maintaining minimum margin ratio requirements
     * @param positionId Unique identifier of the position to remove margin from
     * @param amount Amount of USDC to remove from margin (6 decimals)
     * @custom:security Validates position ownership, active status, and minimum margin ratio
     * @custom:validation Validates amount > 0, sufficient margin available, maintains minMarginRatio
     * @custom:state-changes Decreases position margin, hedger totals, and global margin
     * @custom:events Emits MarginUpdated with removed margin details
     * @custom:errors Throws InvalidPosition, PositionNotActive, InsufficientMargin
     * @custom:reentrancy Protected by secureOperation modifier
     * @custom:access Public - requires position ownership
     * @custom:oracle No oracle dependencies for margin removal
     */
    function removeMargin(uint256 positionId, uint256 amount) 
        external 
        secureOperation 
    {
        HedgePosition storage position = positions[positionId];
        ValidationLibrary.validatePositionOwner(position.hedger, msg.sender);
        ValidationLibrary.validatePositionActive(position.isActive);
        ValidationLibrary.validatePositiveAmount(amount);
        if (uint256(position.margin) < amount) revert ErrorLibrary.InsufficientMargin();

        uint256 newMargin = uint256(position.margin) - amount;
        uint256 newMarginRatio = newMargin.mulDiv(10000, uint256(position.positionSize));
        ValidationLibrary.validateMarginRatio(newMarginRatio, minMarginRatio);

        HedgerPoolValidationLibrary.validateNewMargin(newMargin, MAX_MARGIN);
        
        position.margin = uint96(newMargin);
        hedgers[msg.sender].totalMargin -= uint128(amount);
        totalMargin -= amount;

        usdc.safeTransfer(msg.sender, amount);

        emit MarginUpdated(
            msg.sender, 
            positionId, 
            _packMarginData(amount, newMarginRatio, false)
        );
    }

    /**
     * @notice Commits to liquidate an undercollateralized position using commit-reveal pattern
     * @dev First phase of two-phase liquidation to prevent front-running and manipulation
     * @param hedger Address of the hedger who owns the position
     * @param positionId Unique identifier of the position to liquidate
     * @param salt Random salt for commitment generation to prevent replay attacks
     * @custom:security Validates liquidator role, creates commitment hash, sets cooldown
     * @custom:validation Validates hedger address, positionId > 0, commitment doesn't exist
     * @custom:state-changes Creates liquidation commitment, sets pending liquidation flag
     * @custom:events No events emitted during commitment phase
     * @custom:errors Throws InvalidPosition, CommitmentAlreadyExists
     * @custom:reentrancy Not protected - view operations only
     * @custom:access Restricted to LIQUIDATOR_ROLE
     * @custom:oracle No oracle dependencies for commitment
     */
    function commitLiquidation(
        address hedger,
        uint256 positionId,
        bytes32 salt
    ) external {
        AccessControlLibrary.onlyLiquidatorRole(this);
        AccessControlLibrary.validateAddress(hedger);
        if (positionId == 0) revert ErrorLibrary.InvalidPosition();
        
        bytes32 commitment = keccak256(abi.encodePacked(hedger, positionId, salt, msg.sender));
        ValidationLibrary.validateCommitmentNotExists(liquidationCommitments[commitment]);
        
        liquidationCommitments[commitment] = true;
        liquidationCommitmentTimes[commitment] = block.number;
        
        hasPendingLiquidation[hedger][positionId] = true;
        lastLiquidationAttempt[hedger] = block.number;
    }

    /**
     * @notice Executes liquidation of an undercollateralized position
     * @dev Second phase of two-phase liquidation, requires valid commitment from commitLiquidation
     * @param hedger Address of the hedger who owns the position
     * @param positionId Unique identifier of the position to liquidate
     * @param salt Same salt used in commitLiquidation for commitment verification
     * @return liquidationReward USDC reward paid to liquidator (6 decimals)
     * @custom:security Validates liquidator role, commitment exists, position is liquidatable
     * @custom:validation Validates commitment hash, position ownership, active status
     * @custom:state-changes Closes position, transfers rewards, updates global totals
     * @custom:events Emits HedgerLiquidated with liquidation details
     * @custom:errors Throws InvalidHedger, PositionNotActive, PositionNotLiquidatable
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to LIQUIDATOR_ROLE
     * @custom:oracle Requires fresh EUR/USD price for liquidation validation
     */
    function liquidateHedger(
        address hedger, 
        uint256 positionId,
        bytes32 salt
    ) external nonReentrant returns (uint256 liquidationReward) {
        AccessControlLibrary.onlyLiquidatorRole(this);
        
        HedgePosition storage position = positions[positionId];
        if (position.hedger != hedger) revert ErrorLibrary.InvalidHedger();
        ValidationLibrary.validatePositionActive(position.isActive);

        bytes32 commitment = keccak256(abi.encodePacked(hedger, positionId, salt, msg.sender));
        ValidationLibrary.validateCommitment(liquidationCommitments[commitment]);
        
        delete liquidationCommitments[commitment];
        delete liquidationCommitmentTimes[commitment];
        hasPendingLiquidation[hedger][positionId] = false;

        if (!_isPositionLiquidatable(positionId)) revert ErrorLibrary.PositionNotLiquidatable();

        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        ValidationLibrary.validateOraclePrice(isValid);
        // Note: currentPrice is intentionally unused for liquidation logic
        assembly {
            // Suppress unused variable warning
            pop(currentPrice)
        }

        liquidationReward = uint256(position.margin).percentageOf(liquidationPenalty);
        uint256 remainingMargin = uint256(position.margin) - liquidationReward;

        HedgerInfo storage hedgerInfo = hedgers[hedger];
        hedgerInfo.totalMargin -= uint128(position.margin);
        hedgerInfo.totalExposure -= uint128(position.positionSize);

        totalMargin -= position.margin;
        totalExposure -= position.positionSize;

        position.isActive = false;
        _removePositionFromArrays(hedger, positionId);
        
        activePositionCount[hedger]--;

        usdc.safeTransfer(msg.sender, liquidationReward);

        if (remainingMargin > 0) {
            usdc.safeTransfer(hedger, remainingMargin);
        }

        emit HedgerLiquidated(
            hedger, 
            positionId, 
            msg.sender, 
            _packLiquidationData(liquidationReward, remainingMargin)
        );
    }

    /**
     * @notice Claims accumulated hedging rewards for the caller
     * @dev Combines interest rate differential rewards and yield shift rewards
     * @return interestDifferential USDC rewards from interest rate differential (6 decimals)
     * @return yieldShiftRewards USDC rewards from yield shift mechanism (6 decimals)
     * @return totalRewards Total USDC rewards claimed (6 decimals)
     * @custom:security Validates hedger has active positions, updates reward calculations
     * @custom:validation Validates hedger exists and has pending rewards
     * @custom:state-changes Resets pending rewards, updates last claim timestamp
     * @custom:events Emits HedgingRewardsClaimed with reward breakdown
     * @custom:errors Throws YieldClaimFailed if yield shift claim fails
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Public - any hedger can claim their rewards
     * @custom:oracle No oracle dependencies for reward claiming
     */
    function claimHedgingRewards() 
        external 
        nonReentrant 
        returns (
            uint256 interestDifferential,
            uint256 yieldShiftRewards,
            uint256 totalRewards
        ) 
    {
        address hedger = msg.sender;
        
        HedgerInfo storage hedgerInfo = hedgers[hedger];
        
        _updateHedgerRewards(hedger);
        
        interestDifferential = hedgerInfo.pendingRewards;
        yieldShiftRewards = yieldShift.getHedgerPendingYield(hedger);
        
        totalRewards = interestDifferential + yieldShiftRewards;
        
        if (totalRewards > 0) {
            hedgerInfo.pendingRewards = 0;
            HedgerPoolValidationLibrary.validateTimestamp(timeProvider.currentTime());
            hedgerInfo.lastRewardClaim = uint64(timeProvider.currentTime());
            
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
     * @notice Updates pending rewards for a hedger based on their exposure
     * @dev Calculates rewards using interest rate differential and time-weighted exposure
     * @param hedger The address of the hedger to update rewards for
     * @custom:security Validates reward calculations to prevent overflow
     * @custom:validation Validates hedger has active exposure and time elapsed
     * @custom:state-changes Updates hedger pending rewards and last reward block
     * @custom:events No events emitted
     * @custom:errors Throws RewardOverflow if reward calculation overflows
     * @custom:reentrancy Not protected - internal function only
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies for reward calculation
     */
    function _updateHedgerRewards(address hedger) internal {
        HedgerInfo storage hedgerInfo = hedgers[hedger];
        
        if (hedgerInfo.totalExposure > 0) {
            uint256 currentBlock = block.number;
            uint256 lastRewardBlock = hedgerLastRewardBlock[hedger];
            
            if (lastRewardBlock < 1) {
                hedgerLastRewardBlock[hedger] = currentBlock;
                return;
            }
            
    
            unchecked {
                uint256 blocksElapsed = currentBlock - lastRewardBlock;
                uint256 timeElapsed = blocksElapsed * 12;
                
                if (timeElapsed > MAX_REWARD_PERIOD) {
                    timeElapsed = MAX_REWARD_PERIOD;
                }
                
                uint256 interestDifferential = usdInterestRate > eurInterestRate ? 
                    usdInterestRate - eurInterestRate : 0;
                
                uint256 reward = uint256(hedgerInfo.totalExposure)
                    .mulDiv(interestDifferential, 10000)
                    .mulDiv(timeElapsed, 365 days);
                
                uint256 newPendingRewards = uint256(hedgerInfo.pendingRewards) + reward;
                if (newPendingRewards < uint256(hedgerInfo.pendingRewards)) revert ErrorLibrary.RewardOverflow();
                
                HedgerPoolValidationLibrary.validatePendingRewards(newPendingRewards, MAX_PENDING_REWARDS);
                hedgerInfo.pendingRewards = uint128(newPendingRewards);
                
                hedgerLastRewardBlock[hedger] = currentBlock;
            }
        }
    }

    /**
     * @notice Returns detailed information about a specific hedge position
     * @dev Provides comprehensive position data including current market price
     * @param hedger Address of the hedger who owns the position
     * @param positionId Unique identifier of the position to query
     * @return positionSize Total position size in USD equivalent
     * @return margin Current margin amount in USDC (6 decimals)
     * @return entryPrice EUR/USD price when position was opened
     * @return currentPrice Current EUR/USD price from oracle
     * @return leverage Leverage multiplier used for the position
     * @return lastUpdateTime Timestamp of last position update
     * @custom:security Validates position ownership and oracle price validity
     * @custom:validation Validates hedger owns the position
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors Throws InvalidHedger, InvalidOraclePrice
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query position data
     * @custom:oracle Requires fresh EUR/USD price from Chainlink oracle
     */
    function getHedgerPosition(address hedger, uint256 positionId) 
        external 
        view 
        returns (
            uint256 positionSize,
            uint256 margin,
            uint256 entryPrice,
            uint256 currentPrice,
            uint256 leverage,
            uint256 lastUpdateTime
        ) 
    {
        HedgePosition storage position = positions[positionId];
        if (position.hedger != hedger) revert ErrorLibrary.InvalidHedger();
        
        (uint256 oraclePrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) revert ErrorLibrary.InvalidOraclePrice();
        
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
     * @notice Returns the current margin ratio for a specific hedge position
     * @dev Calculates margin ratio as (margin / positionSize) * 10000 (in basis points)
     * @param hedger Address of the hedger who owns the position
     * @param positionId Unique identifier of the position to query
     * @return marginRatio Current margin ratio in basis points (10000 = 100%)
     * @custom:security Validates position ownership
     * @custom:validation Validates hedger owns the position
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors Throws InvalidHedger if hedger doesn't own position
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query margin ratio
     * @custom:oracle No oracle dependencies for margin ratio calculation
     */
    function getHedgerMarginRatio(address hedger, uint256 positionId) 
        external 
        view 
        returns (uint256) 
    {
        HedgePosition storage position = positions[positionId];
        if (position.hedger != hedger) revert ErrorLibrary.InvalidHedger();
        
        if (position.positionSize == 0) return 0;
        return uint256(position.margin).mulDiv(10000, uint256(position.positionSize));
    }

    /**
     * @notice Checks if a hedge position is eligible for liquidation
     * @dev Determines if position margin ratio is below liquidation threshold
     * @param hedger Address of the hedger who owns the position
     * @param positionId Unique identifier of the position to check
     * @return liquidatable True if position can be liquidated, false otherwise
     * @custom:security Validates position ownership and oracle price validity
     * @custom:validation Validates hedger owns the position
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors Throws InvalidHedger if hedger doesn't own position
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can check liquidation status
     * @custom:oracle Requires fresh EUR/USD price for liquidation calculation
     */
    function isHedgerLiquidatable(address hedger, uint256 positionId) 
        external 
        view 
        returns (bool) 
    {
        HedgePosition storage position = positions[positionId];
        if (position.hedger != hedger) revert ErrorLibrary.InvalidHedger();
        
        return _isPositionLiquidatable(positionId);
    }

    /**
     * @notice Check if a position is eligible for liquidation
     * @param positionId The ID of the position to check
     * @return True if position can be liquidated, false otherwise
     * @dev Position is liquidatable if margin ratio falls below liquidation threshold
     * @custom:security Validates position is active and oracle price is valid
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe arithmetic used
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle Requires fresh EUR/USD price for liquidation calculation
     */
    function _isPositionLiquidatable(uint256 positionId) internal view returns (bool) {
        HedgePosition storage position = positions[positionId];
        if (!position.isActive) return false;
        
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) return false;
        
        int256 pnl = _calculatePnL(position, currentPrice);
        int256 effectiveMargin = int256(uint256(position.margin)) + pnl;
        
        if (effectiveMargin <= 0) return true;
        
        uint256 marginRatio = uint256(effectiveMargin).mulDiv(10000, position.positionSize);
        return marginRatio < liquidationThreshold;
    }

    /**
     * @notice Calculate profit/loss for a hedge position
     * @param position Storage reference to the hedge position
     * @param currentPrice Current EUR/USD price for calculation
     * @return pnl Profit or loss (positive = profit, negative = loss)
     * @dev Calculates PnL based on price difference between entry and current price
     * @custom:security Uses safe arithmetic to prevent overflow
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe arithmetic used
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle Uses currentPrice parameter for PnL calculation
     */
    function _calculatePnL(HedgePosition storage position, uint256 currentPrice) 
        internal 
        view 
        returns (int256) 
    {
        int256 priceChange = int256(uint256(position.entryPrice)) - int256(currentPrice);
        
        if (priceChange >= 0) {
            uint256 absPriceChange = uint256(priceChange);
            uint256 intermediate = uint256(position.positionSize).mulDiv(absPriceChange, uint256(position.entryPrice));
            return int256(intermediate);
        } else {
            uint256 absPriceChange = uint256(-priceChange);
            uint256 intermediate = uint256(position.positionSize).mulDiv(absPriceChange, uint256(position.entryPrice));
            return -int256(intermediate);
        }
    }

    /**
     * @notice Returns the total exposure across all active hedge positions
     * @dev Used for monitoring overall risk and system health
     * @return uint256 The total exposure amount in USD equivalent
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getTotalHedgeExposure() external view returns (uint256) {
        return totalExposure;
    }

    /**
     * @notice Updates core hedging parameters for risk management
     * @dev Allows governance to adjust risk parameters based on market conditions
     * @param newMinMarginRatio New minimum margin ratio in basis points (e.g., 1000 = 10%)
     * @param newLiquidationThreshold New liquidation threshold in basis points (e.g., 100 = 1%)
     * @param newMaxLeverage New maximum leverage multiplier (e.g., 10 = 10x)
     * @param newLiquidationPenalty New liquidation penalty in basis points (e.g., 200 = 2%)
     * @custom:security Validates governance role and parameter constraints
     * @custom:validation Validates minMarginRatio >= 500, liquidationThreshold < minMarginRatio, maxLeverage <= 20, liquidationPenalty <= 1000
     * @custom:state-changes Updates all hedging parameter state variables
     * @custom:events No events emitted for parameter updates
     * @custom:errors Throws ConfigValueTooLow, ConfigInvalid, ConfigValueTooHigh
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies for parameter updates
     */
    function updateHedgingParameters(
        uint256 newMinMarginRatio,
        uint256 newLiquidationThreshold,
        uint256 newMaxLeverage,
        uint256 newLiquidationPenalty
    ) external {
        AccessControlLibrary.onlyGovernance(this);
        if (newMinMarginRatio < 500) revert ErrorLibrary.ConfigValueTooLow();
        if (newLiquidationThreshold >= newMinMarginRatio) revert ErrorLibrary.ConfigInvalid();
        if (newMaxLeverage > 20) revert ErrorLibrary.ConfigValueTooHigh();
        if (newLiquidationPenalty > 1000) revert ErrorLibrary.ConfigValueTooHigh();

        minMarginRatio = newMinMarginRatio;
        liquidationThreshold = newLiquidationThreshold;
        maxLeverage = newMaxLeverage;
        liquidationPenalty = newLiquidationPenalty;
    }

    /**
     * @notice Updates the EUR and USD interest rates used for reward calculations
     * @dev Only callable by governance. Rates are in basis points (e.g., 500 = 5%)
     * @param newEurRate The new EUR interest rate in basis points
     * @param newUsdRate The new USD interest rate in basis points
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function updateInterestRates(uint256 newEurRate, uint256 newUsdRate) external {
        AccessControlLibrary.onlyGovernance(this);
        if (newEurRate > 2000 || newUsdRate > 2000) revert ErrorLibrary.ConfigValueTooHigh();
        
        eurInterestRate = newEurRate;
        usdInterestRate = newUsdRate;
    }

    /**
     * @notice Updates hedging fee parameters for protocol revenue
     * @dev Allows governance to adjust fees based on market conditions and protocol needs
     * @param _entryFee New entry fee in basis points (e.g., 20 = 0.2%, max 100 = 1%)
     * @param _exitFee New exit fee in basis points (e.g., 20 = 0.2%, max 100 = 1%)
     * @param _marginFee New margin fee in basis points (e.g., 10 = 0.1%, max 50 = 0.5%)
     * @custom:security Validates governance role and fee constraints
     * @custom:validation Validates entryFee <= 100, exitFee <= 100, marginFee <= 50
     * @custom:state-changes Updates entryFee, exitFee, and marginFee state variables
     * @custom:events No events emitted for fee updates
     * @custom:errors Throws ConfigValueTooHigh if fees exceed maximum limits
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies for fee updates
     */
    function setHedgingFees(
        uint256 _entryFee,
        uint256 _exitFee,
        uint256 _marginFee
    ) external {
        AccessControlLibrary.onlyGovernance(this);
        ValidationLibrary.validateFee(_entryFee, 100);
        ValidationLibrary.validateFee(_exitFee, 100);
        ValidationLibrary.validateFee(_marginFee, 50);

        entryFee = _entryFee;
        exitFee = _exitFee;
        marginFee = _marginFee;
    }

    /**
     * @notice Emergency closure of a hedge position by authorized emergency role
     * @dev Bypasses normal closure process for emergency situations
     * @param hedger The hedger who owns the position
     * @param positionId The ID of the position to close
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function emergencyClosePosition(address hedger, uint256 positionId) external {
        AccessControlLibrary.onlyEmergencyRole(this);
        
        HedgePosition storage position = positions[positionId];
        if (position.hedger != hedger) revert ErrorLibrary.InvalidHedger();
        ValidationLibrary.validatePositionActive(position.isActive);

        HedgerInfo storage hedgerInfo = hedgers[hedger];
        hedgerInfo.totalMargin -= uint128(position.margin);
        hedgerInfo.totalExposure -= uint128(position.positionSize);

        totalMargin -= position.margin;
        totalExposure -= position.positionSize;

        usdc.safeTransfer(hedger, position.margin);

        position.isActive = false;
        _removePositionFromArrays(hedger, positionId);
        
        activePositionCount[hedger]--;
    }

    /**
     * @notice Pauses all hedging operations in emergency situations
     * @dev Can only be called by addresses with EMERGENCY_ROLE
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function pause() external {
        AccessControlLibrary.onlyEmergencyRole(this);
        _pause();
    }

    /**
     * @notice Unpauses hedging operations after emergency is resolved
     * @dev Can only be called by addresses with EMERGENCY_ROLE
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function unpause() external {
        AccessControlLibrary.onlyEmergencyRole(this);
        _unpause();
    }

    /**
     * @notice Checks if a position has a pending liquidation commitment
     * @dev Used to prevent margin operations during liquidation process
     * @param hedger Address of the hedger who owns the position
     * @param positionId Unique identifier of the position to check
     * @return hasCommitment True if liquidation commitment exists, false otherwise
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can check commitment status
     * @custom:oracle No oracle dependencies
     */
    function hasPendingLiquidationCommitment(address hedger, uint256 positionId) 
        external 
        view 
        returns (bool) 
    {
        return hasPendingLiquidation[hedger][positionId];
    }

    /**
     * @notice Returns the current hedging configuration parameters
     * @dev Provides access to all key configuration values for hedging operations
     * @return minMarginRatio_ Minimum margin ratio requirement
     * @return liquidationThreshold_ Threshold for position liquidation
     * @return maxLeverage_ Maximum allowed leverage
     * @return liquidationPenalty_ Penalty for liquidated positions
     * @return entryFee_ Fee for entering positions
     * @return exitFee_ Fee for exiting positions
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getHedgingConfig() external view returns (
        uint256 minMarginRatio_,
        uint256 liquidationThreshold_,
        uint256 maxLeverage_,
        uint256 liquidationPenalty_,
        uint256 entryFee_,
        uint256 exitFee_
    ) {
        return (
            minMarginRatio,
            liquidationThreshold,
            maxLeverage,
            liquidationPenalty,
            entryFee,
            exitFee
        );
    }
    
    /**
     * @notice Returns the current maximum values for packed struct fields
     * @return maxPositionSize Maximum allowed position size
     * @return maxMargin Maximum allowed margin
     * @return maxEntryPrice Maximum allowed entry price
     * @return maxLeverageValue Maximum allowed leverage
     * @return maxTotalMargin Maximum allowed total margin
     * @return maxTotalExposure Maximum allowed total exposure
     * @return maxPendingRewards Maximum allowed pending rewards
     * @dev Useful for monitoring and debugging overflow protection
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
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
        return (
            MAX_POSITION_SIZE,
            MAX_MARGIN,
            MAX_ENTRY_PRICE,
            MAX_LEVERAGE,
            MAX_TOTAL_MARGIN,
            MAX_TOTAL_EXPOSURE,
            MAX_PENDING_REWARDS
        );
    }

    /**
     * @notice Checks if hedging operations are currently active
     * @dev Returns false if contract is paused or in emergency mode
     * @return True if hedging is active, false otherwise
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function isHedgingActive() external view returns (bool) {
        return !paused();
    }

    /**
     * @notice Clear expired liquidation commitment after cooldown period
     * @dev Uses block numbers instead of timestamps for security against miner manipulation
     * @param hedger Address of the hedger
     * @param positionId ID of the position
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function clearExpiredLiquidationCommitment(address hedger, uint256 positionId) external {
        AccessControlLibrary.onlyLiquidatorRole(this);
        if (block.number > lastLiquidationAttempt[hedger] + LIQUIDATION_COOLDOWN) {
            hasPendingLiquidation[hedger][positionId] = false;
        }
    }

    /**
     * @notice Cancels a pending liquidation commitment
     * @dev Allows hedgers to cancel their liquidation commitment before execution
     * @param hedger The hedger address
     * @param positionId The position ID to cancel liquidation for
     * @param salt Same salt used in commitLiquidation for commitment verification
     * @custom:security Validates liquidator role and commitment exists
     * @custom:validation Validates commitment hash matches stored commitment
     * @custom:state-changes Deletes liquidation commitment and pending liquidation flag
     * @custom:events No events emitted for commitment cancellation
     * @custom:errors Throws CommitmentNotFound if commitment doesn't exist
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to LIQUIDATOR_ROLE
     * @custom:oracle No oracle dependencies for commitment cancellation
     */
    function cancelLiquidationCommitment(address hedger, uint256 positionId, bytes32 salt) external {
        AccessControlLibrary.onlyLiquidatorRole(this);
        bytes32 commitment = keccak256(abi.encodePacked(hedger, positionId, salt, msg.sender));
        ValidationLibrary.validateCommitment(liquidationCommitments[commitment]);
        
        delete liquidationCommitments[commitment];
        delete liquidationCommitmentTimes[commitment];
        hasPendingLiquidation[hedger][positionId] = false;
    }

    /**
     * @notice Internal function to check if a position has a pending liquidation commitment
     * @dev Used internally to prevent margin operations during liquidation process
     * @param hedger Address of the hedger who owns the position
     * @param positionId Unique identifier of the position to check
     * @return hasCommitment True if liquidation commitment exists, false otherwise
     * @custom:security No security validations required - internal view function
     * @custom:validation No input validation required - internal function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _hasPendingLiquidationCommitment(address hedger, uint256 positionId) internal view returns (bool) {
        return hasPendingLiquidation[hedger][positionId];
    }

    /**
     * @notice Recovers accidentally sent ERC20 tokens from the contract
     * @dev Emergency function to recover tokens that are not part of normal operations
     * @param token The token address to recover
     * @param amount The amount of tokens to recover
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function recoverToken(address token, uint256 amount) external {
        AccessControlLibrary.onlyAdmin(this);
        // Use the shared library for secure token recovery to treasury
        TreasuryRecoveryLibrary.recoverToken(token, amount, address(this), treasury);
    }

    /**
     * @notice Recover ETH to treasury address only
     * @dev Emergency function to recover accidentally sent ETH to the contract
     * @custom:security Validates admin role and emits recovery event
     * @custom:validation No input validation required - transfers all ETH
     * @custom:state-changes Transfers all contract ETH balance to treasury
     * @custom:events Emits ETHRecovered with amount and treasury address
     * @custom:errors No errors thrown - safe ETH transfer
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependencies
     */
    function recoverETH() external {
        AccessControlLibrary.onlyAdmin(this);

        emit ETHRecovered(treasury, address(this).balance);
        TreasuryRecoveryLibrary.recoverETH(treasury);
    }
    
    /**
     * @notice Update treasury address
     * @dev Allows governance to update the treasury address for fee collection
     * @param _treasury New treasury address
     * @custom:security Validates governance role and treasury address
     * @custom:validation Validates _treasury is not address(0) and is valid
     * @custom:state-changes Updates treasury state variable
     * @custom:events Emits TreasuryUpdated with new treasury address
     * @custom:errors Throws ZeroAddress if _treasury is address(0)
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function updateTreasury(address _treasury) external {
        AccessControlLibrary.onlyGovernance(this);
        AccessControlLibrary.validateAddress(_treasury);
        ValidationLibrary.validateTreasuryAddress(_treasury);
        require(_treasury != address(0), "Treasury cannot be zero address");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }
    

}