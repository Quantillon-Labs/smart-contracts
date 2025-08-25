// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// =============================================================================
// IMPORTS - OpenZeppelin libraries and protocol interfaces
// =============================================================================

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IChainlinkOracle.sol";
import "../interfaces/IYieldShift.sol";
import "../libraries/VaultMath.sol";

/**
 * @title HedgerPool
 * @notice Manages EUR/USD hedging positions, margin, and hedger rewards
 * 
 * @dev Main characteristics:
 *      - Dual-pool mechanism for EUR/USD hedging
 *      - Margin-based position management
 *      - Liquidation mechanisms for risk management
 *      - Dynamic fee structure for protocol sustainability
 *      - Interest rate differential handling
 *      - Hedger reward distribution system
 *      - Emergency pause mechanism for crisis situations
 *      - Upgradeable via UUPS pattern
 * 
 * @dev Hedging mechanics:
 *      - Hedgers provide USDC margin to open EUR/USD positions
 *      - Positions are leveraged based on margin and market conditions
 *      - P&L is calculated based on EUR/USD price movements
 *      - Liquidation occurs when margin ratio falls below threshold
 *      - Hedgers earn rewards for providing liquidity and taking risk
 * 
 * @dev Risk management:
 *      - Minimum margin ratio requirements
 *      - Liquidation thresholds and penalties
 *      - Maximum leverage limits
 *      - Position size limits
 *      - Real-time P&L tracking
 *      - Emergency pause capabilities
 * 
 * @dev Fee structure:
 *      - Entry fees for opening positions
 *      - Exit fees for closing positions
 *      - Margin fees for margin operations
 *      - Liquidation penalties for risk management
 *      - Dynamic fee adjustment based on market conditions
 * 
 * @dev Security features:
 *      - Role-based access control for all critical operations
 *      - Reentrancy protection for all external calls
 *      - Emergency pause mechanism for crisis situations
 *      - Upgradeable architecture for future improvements
 *      - Secure margin and position management
 *      - Oracle price validation
 * 
 * @dev Integration points:
 *      - Chainlink oracle for EUR/USD price feeds
 *      - Yield shift mechanism for interest rate management
 *      - Vault math library for calculations
 *      - USDC for margin and settlement
 * 
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract HedgerPool is 
    Initializable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;
    using VaultMath for uint256;

    // =============================================================================
    // CONSTANTS AND ROLES - Protocol roles and limits
    // =============================================================================
    
    /// @notice Role for governance operations (parameter updates, emergency actions)
    /// @dev keccak256 hash avoids role collisions with other contracts
    /// @dev Should be assigned to governance multisig or DAO
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    
    /// @notice Role for liquidating undercollateralized positions
    /// @dev keccak256 hash avoids role collisions with other contracts
    /// @dev Should be assigned to trusted liquidators or automated systems
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    
    /// @notice Role for emergency operations (pause, emergency liquidations)
    /// @dev keccak256 hash avoids role collisions with other contracts
    /// @dev Should be assigned to emergency multisig
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    /// @notice Role for performing contract upgrades via UUPS pattern
    /// @dev keccak256 hash avoids role collisions with other contracts
    /// @dev Should be assigned to governance or upgrade multisig
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // =============================================================================
    // STATE VARIABLES - External contracts and configuration
    // =============================================================================
    
    /// @notice USDC token contract for margin and settlement
    /// @dev Used for all margin deposits, withdrawals, and fee payments
    /// @dev Should be the official USDC contract on the target network
    IERC20 public usdc;
    
    /// @notice Chainlink oracle contract for EUR/USD price feeds
    /// @dev Provides real-time EUR/USD exchange rates for position calculations
    /// @dev Used for P&L calculations and liquidation checks
    IChainlinkOracle public oracle;
    
    /// @notice Yield shift mechanism for interest rate management
    /// @dev Handles interest rate differentials between EUR and USD
    /// @dev Used for funding rate calculations and yield distribution
    IYieldShift public yieldShift;

    // Pool configuration parameters
    /// @notice Minimum margin ratio required for positions (in basis points)
    /// @dev Example: 1000 = 10% minimum margin ratio
    /// @dev Used to prevent excessive leverage and manage risk
    uint256 public minMarginRatio;          // Minimum margin ratio (e.g., 10% = 1000 bps)
    
    /// @notice Liquidation threshold below which positions can be liquidated (in basis points)
    /// @dev Example: 500 = 5% liquidation threshold
    /// @dev Must be lower than minMarginRatio to provide buffer
    uint256 public liquidationThreshold;    // Liquidation threshold (e.g., 5% = 500 bps)
    
    /// @notice Maximum allowed leverage for positions
    /// @dev Example: 10 = 10x maximum leverage
    /// @dev Used to limit risk exposure and prevent excessive speculation
    uint256 public maxLeverage;             // Maximum allowed leverage (e.g., 10x)
    
    /// @notice Penalty charged during liquidations (in basis points)
    /// @dev Example: 200 = 2% liquidation penalty
    /// @dev Incentivizes hedgers to maintain adequate margin
    uint256 public liquidationPenalty;      // Liquidation penalty (e.g., 2% = 200 bps)
    
    // Position limits to prevent DoS
    uint256 public constant MAX_POSITIONS_PER_HEDGER = 50;
    mapping(address => uint256) public activePositionCount;

    // Fee configuration parameters
    /// @notice Fee charged when opening positions (in basis points)
    /// @dev Example: 50 = 0.5% entry fee
    /// @dev Revenue source for the protocol
    uint256 public entryFee;                // Fee for entering positions (bps)
    
    /// @notice Fee charged when closing positions (in basis points)
    /// @dev Example: 30 = 0.3% exit fee
    /// @dev Revenue source for the protocol
    uint256 public exitFee;                 // Fee for exiting positions (bps)
    
    /// @notice Fee charged for margin operations (in basis points)
    /// @dev Example: 10 = 0.1% margin fee
    /// @dev Revenue source for the protocol
    uint256 public marginFee;               // Fee for margin operations (bps)

    // Pool state variables
    /// @notice Total margin deposited across all active positions
    /// @dev Sum of all margin amounts across all hedgers
    /// @dev Used for pool analytics and risk management
    uint256 public totalMargin;             // Total margin across all positions
    
    /// @notice Total EUR/USD exposure across all positions
    /// @dev Net exposure of the pool to EUR/USD price movements
    /// @dev Used for risk management and hedging calculations
    uint256 public totalExposure;           // Total EUR/USD exposure
    
    /// @notice Number of active hedgers with open positions
    /// @dev Count of unique addresses with active positions
    /// @dev Used for protocol analytics and governance
    uint256 public activeHedgers;           // Number of active hedgers
    
    /// @notice Next position ID to be assigned
    /// @dev Auto-incremented for each new position
    /// @dev Used to generate unique position identifiers
    uint256 public nextPositionId;          // Next position ID counter

    // Interest rate configuration
    /// @notice EUR interest rate (in basis points)
    /// @dev Example: 400 = 4% EUR interest rate
    /// @dev Used for funding rate calculations
    uint256 public eurInterestRate;         // EUR interest rate (bps)
    
    /// @notice USD interest rate (in basis points)
    /// @dev Example: 500 = 5% USD interest rate
    /// @dev Used for funding rate calculations
    uint256 public usdInterestRate;         // USD interest rate (bps)

    // =============================================================================
    // DATA STRUCTURES - Position and hedger information
    // =============================================================================
    
    /// @notice Hedge position data structure
    /// @dev Stores all information about a single hedging position
    /// @dev Used for position management and P&L calculations
    struct HedgePosition {
        address hedger;                     // Address of the hedger who owns the position
        uint256 positionSize;               // Position size in QEURO equivalent (18 decimals)
        uint256 margin;                     // Current margin in USDC (6 decimals)
        uint256 entryPrice;                 // EUR/USD price when position was opened (8 decimals)
        uint256 leverage;                   // Position leverage (e.g., 5 = 5x leverage)
        uint256 entryTime;                  // Timestamp when position was created
        uint256 lastUpdateTime;             // Timestamp of last position update
        int256 unrealizedPnL;               // Current unrealized profit/loss in USDC
        bool isActive;                      // Whether the position is currently active
    }

    /// @notice Hedger information data structure
    /// @dev Stores aggregated information about a hedger's activity
    /// @dev Used for reward calculations and risk management
    struct HedgerInfo {
        uint256[] positionIds;              // Array of position IDs owned by the hedger
        uint256 totalMargin;                // Total margin across all positions in USDC
        uint256 totalExposure;              // Total exposure across positions
        uint256 pendingRewards;             // Pending hedging rewards
        uint256 lastRewardClaim;            // Last reward claim timestamp
        bool isActive;                      // Hedger status
    }

    // Storage mappings
    /// @notice Positions by position ID
    /// @dev Maps position IDs to position data
    /// @dev Used to store and retrieve position information
    mapping(uint256 => HedgePosition) public positions;
    
    /// @notice Hedger information by address
    /// @dev Maps hedger addresses to their aggregated information
    /// @dev Used to track hedger activity and rewards
    mapping(address => HedgerInfo) public hedgers;
    mapping(address => uint256[]) public hedgerPositions;

    // Yield tracking
    /// @notice Total yield earned by hedgers in QTI tokens
    /// @dev Sum of interest differential rewards and yield shift rewards
    uint256 public totalYieldEarned;        // Total yield earned by hedgers
    /// @notice Pool of interest differential rewards
    /// @dev Rewards distributed to hedgers based on their exposure to interest rate differentials
    uint256 public interestDifferentialPool; // Pool of interest differential rewards

    // User and Hedger yield tracking
    mapping(address => uint256) public userPendingYield;
    mapping(address => uint256) public hedgerPendingYield;
    mapping(address => uint256) public userLastClaim;
    mapping(address => uint256) public hedgerLastClaim;
    
    // Block-based tracking to prevent timestamp manipulation
    mapping(address => uint256) public hedgerLastRewardBlock;
    uint256 public constant BLOCKS_PER_DAY = 7200; // Assuming 12 second blocks
    uint256 public constant MAX_REWARD_PERIOD = 365 days; // Maximum reward period

    // =============================================================================
    // EVENTS
    // =============================================================================
    
    event HedgePositionOpened(
        address indexed hedger,
        uint256 indexed positionId,
        uint256 positionSize,
        uint256 margin,
        uint256 leverage,
        uint256 entryPrice
    );
    
    event HedgePositionClosed(
        address indexed hedger,
        uint256 indexed positionId,
        uint256 exitPrice,
        int256 pnl,
        uint256 timestamp
    );
    
    event MarginAdded(
        address indexed hedger,
        uint256 indexed positionId,
        uint256 marginAdded,
        uint256 newMarginRatio
    );
    
    event MarginRemoved(
        address indexed hedger,
        uint256 indexed positionId,
        uint256 marginRemoved,
        uint256 newMarginRatio
    );
    
    event HedgerLiquidated(
        address indexed hedger,
        uint256 indexed positionId,
        address indexed liquidator,
        uint256 liquidationReward,
        uint256 remainingMargin
    );
    
    event HedgingRewardsClaimed(
        address indexed hedger,
        uint256 interestDifferential,
        uint256 yieldShiftRewards,
        uint256 totalRewards
    );

    // =============================================================================
    // INITIALIZER
    // =============================================================================

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin,
        address _usdc,
        address _oracle,
        address _yieldShift
    ) public initializer {
        require(admin != address(0), "HedgerPool: Admin cannot be zero");
        require(_usdc != address(0), "HedgerPool: USDC cannot be zero");
        require(_oracle != address(0), "HedgerPool: Oracle cannot be zero");
        require(_yieldShift != address(0), "HedgerPool: YieldShift cannot be zero");

        __ReentrancyGuard_init();
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        usdc = IERC20(_usdc);
        oracle = IChainlinkOracle(_oracle);
        yieldShift = IYieldShift(_yieldShift);

        // Default parameters
        minMarginRatio = 1000;          // 10% minimum margin
        liquidationThreshold = 100;     // 1% liquidation threshold (per spec)
        maxLeverage = 10;               // 10x maximum leverage
        liquidationPenalty = 200;       // 2% liquidation penalty
        
        entryFee = 20;                  // 0.2% entry fee
        exitFee = 20;                   // 0.2% exit fee
        marginFee = 10;                 // 0.1% margin fee

        // Default interest rates (updated by governance)
        eurInterestRate = 350;          // 3.5% EUR rate
        usdInterestRate = 450;          // 4.5% USD rate

        nextPositionId = 1;
    }

    // =============================================================================
    // CORE HEDGING FUNCTIONS
    // =============================================================================

    /**
     * @notice Enter a new EUR/USD hedging position (short EUR/USD)
     * 
     * @dev This function allows hedgers to open a new EUR/USD hedging position.
     *      - Hedgers provide USDC margin.
     *      - A fee is charged based on the entry fee percentage.
     *      - The position size is calculated based on the net margin and leverage.
     *      - The margin ratio is checked against the minimum required.
     *      - The USDC margin is transferred from the hedger to the contract.
     *      - A new position is created and stored.
     *      - Hedger info and pool totals are updated.
     *      - An event is emitted.
     * 

     */
    function enterHedgePosition(uint256 usdcAmount, uint256 leverage) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256 positionId) 
    {
        require(usdcAmount > 0, "HedgerPool: Amount must be positive");
        require(leverage <= maxLeverage, "HedgerPool: Leverage too high");
        require(leverage > 0, "HedgerPool: Leverage must be positive");

        // SECURITY FIX: Check position limits to prevent DoS
        require(
            activePositionCount[msg.sender] < MAX_POSITIONS_PER_HEDGER,
            "HedgerPool: Too many active positions"
        );

        // Get current EUR/USD price
        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "HedgerPool: Invalid EUR/USD price");

        // Calculate entry fee
        uint256 fee = usdcAmount.percentageOf(entryFee);
        uint256 netMargin = usdcAmount - fee;

        // Calculate position size based on leverage
        uint256 positionSize = netMargin.mulDiv(leverage, 1);

        // Validate margin ratio
        uint256 marginRatio = netMargin.mulDiv(10000, positionSize);
        require(marginRatio >= minMarginRatio, "HedgerPool: Insufficient margin ratio");

        // Transfer USDC from hedger
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);

        // Create new position
        positionId = nextPositionId++;
        
        HedgePosition storage position = positions[positionId];
        position.hedger = msg.sender;
        position.positionSize = positionSize;
        position.margin = netMargin;
        position.entryPrice = eurUsdPrice;
        position.leverage = leverage;
        position.entryTime = block.timestamp;
        position.lastUpdateTime = block.timestamp;
        position.unrealizedPnL = 0;
        position.isActive = true;

        // Update hedger info
        HedgerInfo storage hedger = hedgers[msg.sender];
        if (!hedger.isActive) {
            hedger.isActive = true;
            activeHedgers++;
        }
        
        hedger.positionIds.push(positionId);
        hedger.totalMargin += netMargin;
        hedger.totalExposure += positionSize;
        hedgerPositions[msg.sender].push(positionId);

        // SECURITY FIX: Update active position count
        activePositionCount[msg.sender]++;

        // Update pool totals
        totalMargin += netMargin;
        totalExposure += positionSize;

        emit HedgePositionOpened(
            msg.sender,
            positionId,
            positionSize,
            netMargin,
            leverage,
            eurUsdPrice
        );
    }

    /**
     * @notice Exit an existing hedging position
     * 
     * @dev This function allows hedgers to close an existing EUR/USD hedging position.
     *      - The hedger must be the owner of the position.
     *      - The position must be active.
     *      - The current EUR/USD price is fetched.
     *      - The P&L is calculated based on the current price.
     *      - An exit fee is charged.
     *      - Hedger info and pool totals are updated.
     *      - The position is deactivated and removed from arrays.
     *      - The payout is transferred to the hedger.
     *      - An event is emitted.
     */
    function exitHedgePosition(uint256 positionId) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (int256 pnl) 
    {
        HedgePosition storage position = positions[positionId];
        require(position.hedger == msg.sender, "HedgerPool: Not position owner");
        require(position.isActive, "HedgerPool: Position not active");

        // Get current EUR/USD price
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "HedgerPool: Invalid EUR/USD price");

        // Calculate P&L (short position benefits from EUR/USD decline)
        pnl = _calculatePnL(position, currentPrice);

        // Calculate exit fee
        uint256 grossPayout = uint256(int256(position.margin) + pnl);
        uint256 exitFeeAmount = grossPayout.percentageOf(exitFee);
        uint256 netPayout = grossPayout - exitFeeAmount;

        // Update hedger info
        HedgerInfo storage hedger = hedgers[msg.sender];
        hedger.totalMargin -= position.margin;
        hedger.totalExposure -= position.positionSize;

        // Update pool totals
        totalMargin -= position.margin;
        totalExposure -= position.positionSize;

        // Deactivate position and remove from arrays
        position.isActive = false;
        _removePositionFromArrays(msg.sender, positionId);
        
        // Update active position count
        activePositionCount[msg.sender]--;

        // Transfer payout to hedger
        if (netPayout > 0) {
            usdc.safeTransfer(msg.sender, netPayout);
        }

        emit HedgePositionClosed(msg.sender, positionId, currentPrice, pnl, block.timestamp);
    }

    /**
     * @notice Remove position from hedger arrays to prevent DoS
     * @param hedger Address of the hedger
     * @param positionId Position ID to remove
     * 

     */
    function _removePositionFromArrays(address hedger, uint256 positionId) internal {
        // Remove from hedger.positionIds array
        uint256[] storage positionIds = hedgers[hedger].positionIds;
        uint256 positionIdsLength = positionIds.length; // Cache length
        for (uint256 i = 0; i < positionIdsLength; i++) {
            if (positionIds[i] == positionId) {
                // SECURITY FIX: Replace with last element and pop for efficient cleanup
                positionIds[i] = positionIds[positionIdsLength - 1];
                positionIds.pop();
                break;
            }
        }
        
        // Remove from hedgerPositions array
        uint256[] storage hedgerPos = hedgerPositions[hedger];
        uint256 hedgerPosLength = hedgerPos.length; // Cache length
        for (uint256 i = 0; i < hedgerPosLength; i++) {
            if (hedgerPos[i] == positionId) {
                // SECURITY FIX: Replace with last element and pop for efficient cleanup
                hedgerPos[i] = hedgerPos[hedgerPosLength - 1];
                hedgerPos.pop();
                break;
            }
        }
    }

    /**
     * @notice Partially close a hedging position
     * 
     * @dev This function allows hedgers to partially close an existing EUR/USD hedging position.
     *      - The hedger must be the owner of the position.
     *      - The position must be active.
     *      - The current EUR/USD price is fetched.
     *      - Partial amounts are calculated based on the percentage.
     *      - The P&L for the partial position is calculated.
     *      - The payout is calculated.
     *      - The position is updated.
     *      - Hedger info and pool totals are updated.
     *      - The payout is transferred to the hedger.
     *      - The partial P&L is returned.
     */
    function partialClosePosition(uint256 positionId, uint256 percentage) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (int256 pnl) 
    {
        require(percentage > 0 && percentage <= 10000, "HedgerPool: Invalid percentage");
        
        HedgePosition storage position = positions[positionId];
        require(position.hedger == msg.sender, "HedgerPool: Not position owner");
        require(position.isActive, "HedgerPool: Position not active");

        // Get current EUR/USD price
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "HedgerPool: Invalid EUR/USD price");

        // Calculate partial amounts
        uint256 partialSize = position.positionSize.percentageOf(percentage);
        uint256 partialMargin = position.margin.percentageOf(percentage);

        // Calculate P&L for partial position
        pnl = _calculatePnL(position, currentPrice);
        int256 partialPnL = pnl * int256(percentage) / 10000;

        // Calculate payout
        uint256 grossPayout = uint256(int256(partialMargin) + partialPnL);
        uint256 exitFeeAmount = grossPayout.percentageOf(exitFee);
        uint256 netPayout = grossPayout - exitFeeAmount;

        // Update position
        position.positionSize -= partialSize;
        position.margin -= partialMargin;

        // Update hedger info
        HedgerInfo storage hedger = hedgers[msg.sender];
        hedger.totalMargin -= partialMargin;
        hedger.totalExposure -= partialSize;

        // Update pool totals
        totalMargin -= partialMargin;
        totalExposure -= partialSize;

        // Transfer payout to hedger
        if (netPayout > 0) {
            usdc.safeTransfer(msg.sender, netPayout);
        }

        pnl = partialPnL;
    }

    // =============================================================================
    // MARGIN MANAGEMENT
    // =============================================================================

    /**
     * @notice Add margin to an existing position
     * 
     * @param positionId Position ID to add margin to
     * @param amount Amount of USDC to add as margin
     * 
     * @dev This function allows hedgers to add margin to an existing EUR/USD hedging position.
     *      - The hedger must be the owner of the position.
     *      - The position must be active.
     *      - The amount of margin to add must be positive.
     *      - A margin fee is charged.
     *      - The USDC margin is transferred from the hedger to the contract.
     *      - The position margin is updated.
     *      - Hedger and pool totals are updated.
     *      - A new margin ratio is calculated.
     *      - An event is emitted.
     * 
     * @dev Front-running protection:
     *      - Cannot add margin during liquidation cooldown period
     *      - Cannot add margin if there are pending liquidation commitments
     *      - Prevents hedgers from front-running liquidation attempts
     * 

     */
    function addMargin(uint256 positionId, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        HedgePosition storage position = positions[positionId];
        require(position.hedger == msg.sender, "HedgerPool: Not position owner");
        require(position.isActive, "HedgerPool: Position not active");
        require(amount > 0, "HedgerPool: Amount must be positive");
        
        // SECURITY FIX: Prevent front-running liquidation attempts
        require(
            block.timestamp >= lastLiquidationAttempt[msg.sender] + LIQUIDATION_COOLDOWN,
            "HedgerPool: Cannot add margin during liquidation cooldown"
        );
        
        // SECURITY FIX: Check for pending liquidation commitments
        require(
            !_hasPendingLiquidationCommitment(msg.sender, positionId),
            "HedgerPool: Cannot add margin with pending liquidation commitment"
        );

        // Calculate margin fee
        uint256 fee = amount.percentageOf(marginFee);
        uint256 netAmount = amount - fee;

        // Transfer USDC from hedger
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        // Update position margin
        position.margin += netAmount;

        // Update hedger and pool totals
        hedgers[msg.sender].totalMargin += netAmount;
        totalMargin += netAmount;

        // Calculate new margin ratio
        uint256 newMarginRatio = position.margin.mulDiv(10000, position.positionSize);

        emit MarginAdded(msg.sender, positionId, netAmount, newMarginRatio);
    }

    /**
     * @notice Remove excess margin from a position
     * 
     * @dev This function allows hedgers to remove margin from an existing EUR/USD hedging position.
     *      - The hedger must be the owner of the position.
     *      - The position must be active.
     *      - The amount of margin to remove must be positive.
     *      - The position must have sufficient margin.
     *      - The new margin ratio is checked against the minimum required.
     *      - The position margin is updated.
     *      - Hedger and pool totals are updated.
     *      - The USDC margin is transferred back to the hedger.
     *      - An event is emitted.
     */
    function removeMargin(uint256 positionId, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        HedgePosition storage position = positions[positionId];
        require(position.hedger == msg.sender, "HedgerPool: Not position owner");
        require(position.isActive, "HedgerPool: Position not active");
        require(amount > 0, "HedgerPool: Amount must be positive");
        require(position.margin >= amount, "HedgerPool: Insufficient margin");

        // Check if removal maintains minimum margin ratio
        uint256 newMargin = position.margin - amount;
        uint256 newMarginRatio = newMargin.mulDiv(10000, position.positionSize);
        require(newMarginRatio >= minMarginRatio, "HedgerPool: Would breach minimum margin");

        // Update position margin
        position.margin = newMargin;

        // Update hedger and pool totals
        hedgers[msg.sender].totalMargin -= amount;
        totalMargin -= amount;

        // Transfer USDC to hedger
        usdc.safeTransfer(msg.sender, amount);

        emit MarginRemoved(msg.sender, positionId, amount, newMarginRatio);
    }

    // =============================================================================
    // LIQUIDATION SYSTEM
    // =============================================================================

    // Cooldown period after liquidation attempts (1 hour)
    uint256 public constant LIQUIDATION_COOLDOWN = 1 hours;
    
    // Liquidation commitments to prevent front-running
    mapping(bytes32 => bool) public liquidationCommitments;
    mapping(bytes32 => uint256) public liquidationCommitmentTimes;
    
    // Track liquidation attempts to prevent front-running
    mapping(address => uint256) public lastLiquidationAttempt;
    
    // SECURITY FIX: Track pending liquidation commitments by hedger and position
    // This prevents front-running by allowing us to check if a specific hedger/position
    // has any pending liquidation commitments
    mapping(address => mapping(uint256 => bool)) public hasPendingLiquidation;

    /**
     * @notice Commit to a liquidation to prevent front-running
     * @param hedger Address of the hedger to liquidate
     * @param positionId Position ID to liquidate
     * @param salt Random salt for commitment
     */
    function commitLiquidation(
        address hedger,
        uint256 positionId,
        bytes32 salt
    ) external onlyRole(LIQUIDATOR_ROLE) {
        require(hedger != address(0), "HedgerPool: Invalid hedger address");
        require(positionId > 0, "HedgerPool: Invalid position ID");
        
        bytes32 commitment = keccak256(abi.encodePacked(hedger, positionId, salt, msg.sender));
        require(!liquidationCommitments[commitment], "HedgerPool: Commitment already exists");
        
        liquidationCommitments[commitment] = true;
        liquidationCommitmentTimes[commitment] = block.timestamp;
        
        // SECURITY FIX: Mark this hedger/position as having a pending liquidation
        hasPendingLiquidation[hedger][positionId] = true;
        
        // Track liquidation attempt for cooldown
        lastLiquidationAttempt[hedger] = block.timestamp;
    }

    /**
     * @notice Liquidate an undercollateralized hedger position with immediate execution
     * 
     * @param hedger Address of the hedger to liquidate
     * @param positionId Position ID to liquidate
     * @param salt Salt used in the commitment
     * @return liquidationReward Amount of liquidation reward
     * 
     * @dev This function allows liquidators to liquidate an undercollateralized hedger position.
     *      - The liquidator must have the LIQUIDATOR_ROLE.
     *      - The hedger must be the owner of the position.
     *      - The position must be active.
     *      - The position must be liquidatable.
     *      - The current EUR/USD price is fetched.
     *      - The liquidation reward is calculated.
     *      - The remaining margin is calculated.
     *      - Hedger info and pool totals are updated.
     *      - The position is deactivated and removed from arrays.
     *      - The liquidation reward is transferred to the liquidator.
     *      - The remaining margin is transferred back to the hedger if any.
     *      - An event is emitted.
     *      - Front-running protection via immediate execution after commitment.
     * 

     */
    function liquidateHedger(
        address hedger, 
        uint256 positionId,
        bytes32 salt
    ) external onlyRole(LIQUIDATOR_ROLE) nonReentrant returns (uint256 liquidationReward) {
        HedgePosition storage position = positions[positionId];
        require(position.hedger == hedger, "HedgerPool: Invalid hedger");
        require(position.isActive, "HedgerPool: Position not active");

        // SECURITY FIX: Verify commitment exists (no delay required)
        bytes32 commitment = keccak256(abi.encodePacked(hedger, positionId, salt, msg.sender));
        require(liquidationCommitments[commitment], "HedgerPool: No valid commitment");
        
        // Clear the commitment to prevent replay
        delete liquidationCommitments[commitment];
        delete liquidationCommitmentTimes[commitment];
        
        // SECURITY FIX: Clear the pending liquidation flag
        hasPendingLiquidation[hedger][positionId] = false;

        require(_isPositionLiquidatable(positionId), "HedgerPool: Position not liquidatable");

        // Get current EUR/USD price (only need to validate it's available)
        (, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "HedgerPool: Invalid EUR/USD price");

        // Calculate liquidation reward
        liquidationReward = position.margin.percentageOf(liquidationPenalty);
        uint256 remainingMargin = position.margin - liquidationReward;

        // Update hedger info
        HedgerInfo storage hedgerInfo = hedgers[hedger];
        hedgerInfo.totalMargin -= position.margin;
        hedgerInfo.totalExposure -= position.positionSize;

        // Update pool totals
        totalMargin -= position.margin;
        totalExposure -= position.positionSize;

        // Deactivate position and remove from arrays
        position.isActive = false;
        _removePositionFromArrays(hedger, positionId);
        
        // Update active position count
        activePositionCount[hedger]--;

        // Transfer liquidation reward to liquidator
        usdc.safeTransfer(msg.sender, liquidationReward);

        // Return remaining margin to hedger if any
        if (remainingMargin > 0) {
            usdc.safeTransfer(hedger, remainingMargin);
        }

        emit HedgerLiquidated(hedger, positionId, msg.sender, liquidationReward, remainingMargin);
    }

    // =============================================================================
    // YIELD AND REWARDS
    // =============================================================================

    /**
     * @notice Claim hedging rewards (interest differential + yield shift)
     * 
     * @dev This function allows hedgers to claim their accumulated hedging rewards.
     *      - Only the hedger themselves can call this function.
     *      - The pending rewards are updated using block-based calculations.
     *      - The interest differential reward is calculated.
     *      - The yield shift rewards are fetched from the yield shift mechanism.
     *      - The total rewards are summed.
     *      - If total rewards are greater than zero, they are transferred to the hedger.
     *      - The last reward claim timestamp is updated.
     *      - The yield shift rewards are claimed if applicable.
     *      - An event is emitted.    
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
        address hedger = msg.sender; // SECURITY: Only claim own rewards
        
        HedgerInfo storage hedgerInfo = hedgers[hedger];
        
        // Update pending rewards using block-based calculations
        _updateHedgerRewards(hedger);
        
        interestDifferential = hedgerInfo.pendingRewards;
        yieldShiftRewards = yieldShift.getHedgerPendingYield(hedger);
        
        totalRewards = interestDifferential + yieldShiftRewards;
        
        if (totalRewards > 0) {
            hedgerInfo.pendingRewards = 0;
            hedgerInfo.lastRewardClaim = block.timestamp;
            
            // Claim yield shift rewards
            if (yieldShiftRewards > 0) {
                yieldShift.claimHedgerYield(hedger);
            }
            
            // Transfer USDC rewards
            usdc.safeTransfer(hedger, totalRewards);
            
            emit HedgingRewardsClaimed(hedger, interestDifferential, yieldShiftRewards, totalRewards);
        }
    }

    /**
     * @notice Update hedger rewards based on interest rate differential
     * 
     * @dev This internal function calculates and updates the pending hedging rewards
     *      for a given hedger based on their total exposure and the interest rate differential.
     *      - It calculates the interest differential reward.
     *      - It calculates the reward amount based on the hedger's total exposure,
     *        the interest differential, and the time elapsed since the last claim.
     *      - The pending rewards are incremented with overflow protection.
     *      - Uses block-based calculations to prevent timestamp manipulation.
     * 

     */
    function _updateHedgerRewards(address hedger) internal {
        HedgerInfo storage hedgerInfo = hedgers[hedger];
        
        if (hedgerInfo.totalExposure > 0) {
            // SECURITY FIX: Use block numbers instead of timestamps to prevent manipulation
            uint256 currentBlock = block.number;
            uint256 lastRewardBlock = hedgerLastRewardBlock[hedger];
            
            if (lastRewardBlock == 0) {
                // First time claiming, set initial block
                hedgerLastRewardBlock[hedger] = currentBlock;
                return;
            }
            
            uint256 blocksElapsed = currentBlock - lastRewardBlock;
            
            // Convert blocks to time (assuming 12 second blocks)
            uint256 timeElapsed = blocksElapsed * 12; // seconds
            
            // SECURITY FIX: Sanity check to cap time elapsed and prevent manipulation
            if (timeElapsed > MAX_REWARD_PERIOD) {
                timeElapsed = MAX_REWARD_PERIOD;
            }
            
            // Calculate interest differential reward
            // Hedgers earn the difference between USD and EUR rates
            uint256 interestDifferential = usdInterestRate > eurInterestRate ? 
                usdInterestRate - eurInterestRate : 0;
            
            uint256 reward = hedgerInfo.totalExposure
                .mulDiv(interestDifferential, 10000)
                .mulDiv(timeElapsed, 365 days);
            
            // Add overflow protection for pending rewards
            uint256 newPendingRewards = hedgerInfo.pendingRewards + reward;
            require(newPendingRewards >= hedgerInfo.pendingRewards, "HedgerPool: Reward overflow");
            hedgerInfo.pendingRewards = newPendingRewards;
            
            // Update last reward block
            hedgerLastRewardBlock[hedger] = currentBlock;
        }
    }

    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================

    /**
     * @notice Get detailed information about a specific hedger's position
     * 
     * @dev This function allows external contracts to query a hedger's position by ID.
     *      - It fetches the position data from storage.
     *      - It validates that the hedger is the owner of the position.
     *      - It fetches the current EUR/USD price from the oracle.
     *      - It returns the position size, margin, entry price, current price, leverage,
     *        and last update time.
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
        require(position.hedger == hedger, "HedgerPool: Invalid hedger");
        
        (currentPrice, ) = oracle.getEurUsdPrice();
        
        return (
            position.positionSize,
            position.margin,
            position.entryPrice,
            currentPrice,
            position.leverage,
            position.lastUpdateTime
        );
    }

    /**
     * @notice Get the margin ratio of a specific hedger's position
     * 
     * @dev This function allows external contracts to query the margin ratio of a hedger's position.
     *      - It fetches the position data from storage.
     *      - It validates that the hedger is the owner of the position.
     *      - It returns the margin ratio in basis points.
     */
    function getHedgerMarginRatio(address hedger, uint256 positionId) 
        external 
        view 
        returns (uint256) 
    {
        HedgePosition storage position = positions[positionId];
        require(position.hedger == hedger, "HedgerPool: Invalid hedger");
        
        if (position.positionSize == 0) return 0;
        return position.margin.mulDiv(10000, position.positionSize);
    }

    /**
     * @notice Check if a hedger's position is liquidatable
     * 
     * @dev This function allows external contracts to query if a hedger's position is at risk of liquidation.
     *      - It fetches the position data from storage.
     *      - It validates that the hedger is the owner of the position.
     *      - It checks if the position is active.
     *      - It fetches the current EUR/USD price from the oracle.
     *      - It calculates the effective margin including unrealized P&L.
     *      - It checks if the effective margin is less than or equal to zero.
     *      - It returns true if liquidatable, false otherwise.
     */
    function isHedgerLiquidatable(address hedger, uint256 positionId) 
        external 
        view 
        returns (bool) 
    {
        HedgePosition storage position = positions[positionId];
        require(position.hedger == hedger, "HedgerPool: Invalid hedger");
        
        return _isPositionLiquidatable(positionId);
    }

    /**
     * @notice Internal function to check if a position is liquidatable
     * 
     * @dev This function is used by the liquidation system to determine if a position
     *      is at risk of liquidation.
     *      - It fetches the position data from storage.
     *      - It checks if the position is active.
     *      - It fetches the current EUR/USD price from the oracle.
     *      - It calculates the effective margin including unrealized P&L.
     *      - It checks if the effective margin is less than or equal to zero.
     *      - It returns true if liquidatable, false otherwise.
     */
    function _isPositionLiquidatable(uint256 positionId) internal view returns (bool) {
        HedgePosition storage position = positions[positionId];
        if (!position.isActive) return false;
        
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) return false;
        
        // Calculate current margin ratio including unrealized P&L
        int256 pnl = _calculatePnL(position, currentPrice);
        int256 effectiveMargin = int256(position.margin) + pnl;
        
        if (effectiveMargin <= 0) return true;
        
        uint256 marginRatio = uint256(effectiveMargin).mulDiv(10000, position.positionSize);
        return marginRatio < liquidationThreshold;
    }

    /**
     * @notice Internal function to calculate P&L for a hedging position
     * 
     * @dev This function calculates the profit or loss of a hedging position based on
     *      the current EUR/USD price and the position's entry price.
     *      - For a short EUR/USD position, profit is made when EUR/USD falls.
     *      - The P&L is calculated as the difference between the current price and entry price,
     *        multiplied by the position size and divided by the entry price.
     *      - Uses safe arithmetic operations to prevent overflow.
     * 

     */
    function _calculatePnL(HedgePosition storage position, uint256 currentPrice) 
        internal 
        view 
        returns (int256) 
    {
        // For short EUR/USD position: profit when EUR/USD falls
        int256 priceChange = int256(position.entryPrice) - int256(currentPrice);
        
        // SECURITY FIX: Use safe arithmetic to prevent overflow
        // First multiply position size by price change, then divide by entry price
        // This prevents overflow by doing the division first when possible
        
        if (priceChange >= 0) {
            // Positive price change (profit for short position)
            // Use uint256 for intermediate calculations to avoid overflow
            uint256 absPriceChange = uint256(priceChange);
            uint256 intermediate = position.positionSize.mulDiv(absPriceChange, position.entryPrice);
            return int256(intermediate);
        } else {
            // Negative price change (loss for short position)
            uint256 absPriceChange = uint256(-priceChange);
            uint256 intermediate = position.positionSize.mulDiv(absPriceChange, position.entryPrice);
            return -int256(intermediate);
        }
    }

    /**
     * @notice Get the total EUR/USD exposure of the hedger pool
     * 
     * @dev This function allows external contracts to query the total EUR/USD exposure
     *      of the hedger pool.
     *      - It returns the totalExposure variable.
     */
    function getTotalHedgeExposure() external view returns (uint256) {
        return totalExposure;
    }

    /**
     * @notice Get statistics about the hedger pool
     * 
     * @dev This function allows external contracts to query various statistics
     *      about the hedger pool, such as the number of active hedgers, total positions,
     *      average position size, total margin, and pool utilization.
     */
    function getPoolStatistics() external view returns (
        uint256 activeHedgers_,
        uint256 totalPositions,
        uint256 averagePosition,
        uint256 totalMargin_,
        uint256 poolUtilization
    ) {
        activeHedgers_ = activeHedgers;
        totalPositions = nextPositionId - 1;
        averagePosition = totalPositions > 0 ? totalExposure / totalPositions : 0;
        totalMargin_ = totalMargin;
        poolUtilization = totalMargin > 0 ? (totalExposure * 10000) / totalMargin : 0;
    }

    /**
     * @notice Get pending hedging rewards for a specific hedger
     * 
     * @dev This function allows external contracts to query the pending hedging rewards
     *      for a specific hedger, including interest differential and yield shift rewards.
     *      - It calculates the pending interest differential using block-based calculations.
     *      - It fetches the pending yield shift rewards from the yield shift mechanism.
     *      - It sums up the total pending rewards.
     */
    function getPendingHedgingRewards(address hedger) external view returns (
        uint256 interestDifferential,
        uint256 yieldShiftRewards,
        uint256 totalPending
    ) {
        HedgerInfo storage hedgerInfo = hedgers[hedger];
        
        // Calculate pending interest differential using block-based calculations
        if (hedgerInfo.totalExposure > 0) {
            uint256 currentBlock = block.number;
            uint256 lastRewardBlock = hedgerLastRewardBlock[hedger];
            
            if (lastRewardBlock > 0) {
                uint256 blocksElapsed = currentBlock - lastRewardBlock;
                uint256 timeElapsed = blocksElapsed * 12; // seconds
                
                // Sanity check: cap time elapsed to prevent manipulation
                if (timeElapsed > MAX_REWARD_PERIOD) {
                    timeElapsed = MAX_REWARD_PERIOD;
                }
                
                uint256 rateDiff = usdInterestRate > eurInterestRate ? 
                    usdInterestRate - eurInterestRate : 0;
                
                interestDifferential = hedgerInfo.pendingRewards + 
                    hedgerInfo.totalExposure.mulDiv(rateDiff, 10000).mulDiv(timeElapsed, 365 days);
            } else {
                interestDifferential = hedgerInfo.pendingRewards;
            }
        }
        
        yieldShiftRewards = yieldShift.getHedgerPendingYield(hedger);
        totalPending = interestDifferential + yieldShiftRewards;
    }

    // =============================================================================
    // GOVERNANCE FUNCTIONS
    // =============================================================================

    /**
     * @notice Update hedging parameters (margin ratio, liquidation, leverage, fees)
     * 
     * @dev This function allows governance to update critical parameters of the hedging mechanism.
     *      - It requires new values to be within reasonable bounds.
     *      - It updates the minMarginRatio, liquidationThreshold, maxLeverage, and liquidationPenalty.
     */
    function updateHedgingParameters(
        uint256 newMinMarginRatio,
        uint256 newLiquidationThreshold,
        uint256 newMaxLeverage,
        uint256 newLiquidationPenalty
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(newMinMarginRatio >= 500, "HedgerPool: Min margin too low"); // Min 5%
        require(newLiquidationThreshold < newMinMarginRatio, "HedgerPool: Invalid thresholds");
        require(newMaxLeverage <= 20, "HedgerPool: Max leverage too high");
        require(newLiquidationPenalty <= 1000, "HedgerPool: Penalty too high"); // Max 10%

        minMarginRatio = newMinMarginRatio;
        liquidationThreshold = newLiquidationThreshold;
        maxLeverage = newMaxLeverage;
        liquidationPenalty = newLiquidationPenalty;
    }

    /**
     * @notice Update interest rates for EUR and USD
     * 
     * @dev This function allows governance to update the interest rates for EUR and USD.
     *      - It requires new rates to be within reasonable bounds.
     *      - It updates the eurInterestRate and usdInterestRate.
     */
    function updateInterestRates(uint256 newEurRate, uint256 newUsdRate) 
        external 
        onlyRole(GOVERNANCE_ROLE) 
    {
        require(newEurRate <= 2000 && newUsdRate <= 2000, "HedgerPool: Rates too high"); // Max 20%
        
        eurInterestRate = newEurRate;
        usdInterestRate = newUsdRate;
    }

    /**
     * @notice Set hedging fees (entry, exit, margin)
     * 
     * @dev This function allows governance to set the fees for entering, exiting, and margin operations.
     *      - It requires new fees to be within reasonable bounds.
     *      - It updates the entryFee, exitFee, and marginFee.
     */
    function setHedgingFees(
        uint256 _entryFee,
        uint256 _exitFee,
        uint256 _marginFee
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(_entryFee <= 100, "HedgerPool: Entry fee too high"); // Max 1%
        require(_exitFee <= 100, "HedgerPool: Exit fee too high"); // Max 1%
        require(_marginFee <= 50, "HedgerPool: Margin fee too high"); // Max 0.5%

        entryFee = _entryFee;
        exitFee = _exitFee;
        marginFee = _marginFee;
    }

    /**
     * @notice Get position statistics for a hedger
     * @param hedger Address of the hedger
     * @return totalPositions Total number of positions (active + inactive)
     * @return activePositions Number of active positions
     * @return totalMargin_ Total margin across all positions
     * @return totalExposure_ Total exposure across all positions
     */
    function getHedgerPositionStats(address hedger) external view returns (
        uint256 totalPositions,
        uint256 activePositions,
        uint256 totalMargin_,
        uint256 totalExposure_
    ) {
        HedgerInfo storage hedgerInfo = hedgers[hedger];
        totalPositions = hedgerInfo.positionIds.length;
        activePositions = activePositionCount[hedger];
        totalMargin_ = hedgerInfo.totalMargin;
        totalExposure_ = hedgerInfo.totalExposure;
    }

    // =============================================================================
    // EMERGENCY FUNCTIONS
    // =============================================================================

    /**
     * @notice Emergency close a hedger's position
     * 
     * @dev This function allows emergency roles to forcibly close a hedger's position
     *      in case of emergency.
     *      - The hedger must be the owner of the position.
     *      - The position must be active.
     *      - Hedger info and pool totals are updated.
     *      - The margin is returned to the hedger.
     *      - The position is deactivated and removed from arrays.
     */
    function emergencyClosePosition(address hedger, uint256 positionId) 
        external 
        onlyRole(EMERGENCY_ROLE) 
    {
        HedgePosition storage position = positions[positionId];
        require(position.hedger == hedger, "HedgerPool: Invalid hedger");
        require(position.isActive, "HedgerPool: Position not active");

        // Update hedger info
        HedgerInfo storage hedgerInfo = hedgers[hedger];
        hedgerInfo.totalMargin -= position.margin;
        hedgerInfo.totalExposure -= position.positionSize;

        // Update pool totals
        totalMargin -= position.margin;
        totalExposure -= position.positionSize;

        // Return margin to hedger
        usdc.safeTransfer(hedger, position.margin);

        // Deactivate position and remove from arrays
        position.isActive = false;
        _removePositionFromArrays(hedger, positionId);
        
        // Update active position count
        activePositionCount[hedger]--;
    }

    /**
     * @notice Pause the hedger pool
     * 
     * @dev This function allows emergency roles to pause the hedger pool in case of crisis.
     */
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the hedger pool
     * 
     * @dev This function allows emergency roles to unpause the hedger pool after a crisis.
     */
    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }

    /**
     * @notice Check if a hedger has pending liquidation commitments
     * @param hedger Address of the hedger
     * @param positionId Position ID to check
     * @return bool True if there are pending liquidation commitments
     * 

     */
    function hasPendingLiquidationCommitment(address hedger, uint256 positionId) 
        external 
        view 
        returns (bool) 
    {
        return hasPendingLiquidation[hedger][positionId];
    }

    /**
     * @notice Get current hedging configuration parameters
     * 
     * @dev This function allows external contracts to query the current hedging configuration
     *      parameters, such as minimum margin ratio, liquidation threshold, max leverage,
     *      liquidation penalty, entry fee, and exit fee.
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
     * @notice Check if hedging is currently active
     * 
     * @dev This function allows external contracts to query if the hedger pool is
     *      currently active (not paused).
     */
    function isHedgingActive() external view returns (bool) {
        return !paused();
    }

    /**
     * @notice Internal function for UUPS upgrade authorization
     * 
     * @dev This function is called by the UUPS upgrade mechanism to authorize
     *      the upgrade to a new implementation.
     *      - It requires the caller to have the UPGRADER_ROLE.
     */
    /**
     * @notice Clear expired liquidation commitments for a hedger/position
     * @param hedger Address of the hedger
     * @param positionId Position ID
     * @dev This function allows clearing of expired commitments that were never executed
     * @dev Only callable by liquidators or governance
     * @dev Note: With immediate execution, this is mainly for cleanup of stale commitments
     */
    function clearExpiredLiquidationCommitment(address hedger, uint256 positionId) 
        external 
        onlyRole(LIQUIDATOR_ROLE) 
    {
        // Check if the commitment has expired (1 hour buffer after last attempt)
        if (block.timestamp > lastLiquidationAttempt[hedger] + 1 hours) {
            hasPendingLiquidation[hedger][positionId] = false;
        }
    }

    /**
     * @notice Cancel a liquidation commitment (only by the liquidator who created it)
     * @param hedger Address of the hedger
     * @param positionId Position ID
     * @param salt Salt used in the original commitment
     * @dev This function allows liquidators to cancel their own commitments
     * @dev Only callable by the liquidator who created the commitment
     */
    function cancelLiquidationCommitment(address hedger, uint256 positionId, bytes32 salt) 
        external 
        onlyRole(LIQUIDATOR_ROLE) 
    {
        bytes32 commitment = keccak256(abi.encodePacked(hedger, positionId, salt, msg.sender));
        require(liquidationCommitments[commitment], "HedgerPool: Commitment does not exist");
        
        // Clear the commitment
        delete liquidationCommitments[commitment];
        delete liquidationCommitmentTimes[commitment];
        hasPendingLiquidation[hedger][positionId] = false;
    }

    function _authorizeUpgrade(address newImplementation) 
        internal 
        override 
        onlyRole(UPGRADER_ROLE) 
    {}

    /**
     * @notice Check if a hedger has any pending liquidation commitments
     * @param hedger Address of the hedger
     * @param positionId Position ID to check
     * @return bool True if any commitment exists for this hedger/position, false otherwise
     * 

     */
    function _hasPendingLiquidationCommitment(address hedger, uint256 positionId) internal view returns (bool) {
        // SECURITY FIX: Direct check using the pending liquidation mapping
        return hasPendingLiquidation[hedger][positionId];
    }
}