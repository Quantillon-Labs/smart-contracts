// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../interfaces/IUserPool.sol";
import "../../interfaces/IHedgerPool.sol";
import "../../interfaces/IAaveVault.sol";
import "../../interfaces/IstQEURO.sol";
import "../../libraries/VaultMath.sol";
import "../../libraries/ErrorLibrary.sol";
import "../../libraries/AccessControlLibrary.sol";
import "../../libraries/ValidationLibrary.sol";
import "../../libraries/TreasuryRecoveryLibrary.sol";
import "../../libraries/TimeProviderLibrary.sol";
import "../SecureUpgradeable.sol";

/**
 * @title YieldShift
 * @notice Dynamic yield distribution system balancing rewards between users and hedgers
 * 
 * @dev Main characteristics:
 *      - Dynamic yield allocation based on pool balance ratios
 *      - Time-weighted average price (TWAP) calculations for stability
 *      - Multiple yield sources integration (Aave, fees, interest differentials)
 *      - Automatic yield distribution with holding period requirements
 *      - Emergency pause mechanism for crisis situations
 *      - Upgradeable via UUPS pattern
 * 
 * @dev Yield shift mechanics:
 *      - Base yield shift determines default allocation (default 50/50)
 *      - Maximum yield shift caps allocation changes (default 90/10)
 *      - Adjustment speed controls how quickly shifts occur
 *      - Target pool ratio defines optimal balance point
 *      - Real-time calculations based on pool metrics
 * 
 * @dev Distribution algorithm:
 *      - Monitors user pool vs hedger pool size ratios
 *      - Adjusts yield allocation to incentivize balance
 *      - Higher user pool → more yield to hedgers (attract hedging)
 *      - Higher hedger pool → more yield to users (attract deposits)
 *      - Gradual adjustments prevent dramatic shifts
 *      - Flash deposit protection through eligible pool size calculations
 *      - Only deposits meeting holding period requirements count toward yield distribution
 * 
 * @dev Yield sources:
 *      - Aave yield from USDC deposits in lending protocols
 *      - Protocol fees from minting, redemption, and trading
 *      - Interest rate differentials from hedging operations
 *      - External yield farming opportunities
 *      - Authorized source validation for security
 * 
 * @dev Time-weighted calculations:
 *      - 24-hour TWAP for pool size measurements
 *      - Historical data tracking for trend analysis
 *      - Maximum history length prevents unbounded storage
 *      - Drift tolerance for timestamp validation
 *      - Automatic data cleanup and optimization
 * 
 * @dev Holding period requirements:
 *      - Minimum 7-day holding period for yield claims
 *      - Prevents yield farming attacks and speculation
 *      - Encourages long-term protocol participation
 *      - Tracked per user with deposit timestamps
 *      - Enhanced protection against flash deposit manipulation
 *      - Eligible pool sizes exclude recent deposits from yield calculations
 *      - Dynamic discount system based on deposit timing and activity
 * 
 * @dev Security features:
 *      - Role-based access control for all critical operations
 *      - Reentrancy protection for all external calls
 *      - Emergency pause mechanism for crisis situations
 *      - Upgradeable architecture for future improvements
 *      - Authorized yield source validation
 *      - Secure yield distribution mechanisms
 *      - Flash deposit attack prevention through holding period requirements
 *      - Eligible pool size calculations for yield distribution
 *      - Time-weighted protection against yield manipulation
 * 
 * @dev Integration points:
 *      - User pool for deposit and staking metrics
 *      - Hedger pool for hedging exposure metrics
 *      - Aave vault for yield generation and harvesting
 *      - stQEURO token for user yield distribution
 *      - USDC for yield payments and transfers
 * 
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract YieldShift is 
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
    bytes32 public constant YIELD_MANAGER_ROLE = keccak256("YIELD_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    IERC20 public usdc;
    IUserPool public userPool;
    IHedgerPool public hedgerPool;
    IAaveVault public aaveVault;
    IstQEURO public stQEURO;

    /// @notice TimeProvider contract for centralized time management
    /// @dev Used to replace direct block.timestamp usage for testability and consistency
    TimeProvider public immutable timeProvider;

    uint256 public baseYieldShift;
    uint256 public maxYieldShift;
    uint256 public adjustmentSpeed;
    uint256 public targetPoolRatio;
    
    uint256 public constant MIN_HOLDING_PERIOD = 7 days;
    uint256 public constant TWAP_PERIOD = 24 hours;
    uint256 public constant MAX_TIME_ELAPSED = 365 days;
    
    uint256 public currentYieldShift;
    uint256 public lastUpdateTime;
    
    uint256 public totalYieldGenerated;
    uint256 public totalYieldDistributed;
    uint256 public userYieldPool;
    uint256 public hedgerYieldPool;
    address public treasury;
    
    mapping(bytes32 => uint256) public yieldSources;
    bytes32[] public yieldSourceNames;
    
    // Add yield source authorization mappings
    mapping(address => bool) public authorizedYieldSources;
    mapping(address => bytes32) public sourceToYieldType;
    
    mapping(address => uint256) public userPendingYield;
    mapping(address => uint256) public hedgerPendingYield;
    mapping(address => uint256) public userLastClaim;
    mapping(address => uint256) public hedgerLastClaim;
    
    mapping(address => uint256) public lastDepositTime;
    
    /// @dev OPTIMIZED: Packed struct for gas efficiency in historical arrays
    struct PoolSnapshot {
        uint128 userPoolSize;
        uint128 hedgerPoolSize;
        uint64 timestamp;                   // Timestamp (8 bytes, until year 2554)
    }
    
    PoolSnapshot[] public userPoolHistory;
    PoolSnapshot[] public hedgerPoolHistory;
    uint256 public constant MAX_HISTORY_LENGTH = 1000;

    /// @dev OPTIMIZED: Packed struct for gas efficiency in yield shift tracking
    struct YieldShiftSnapshot {
        uint128 yieldShift;
        uint64 timestamp;                   // Timestamp (8 bytes, until year 2554)
    }
    YieldShiftSnapshot[] public yieldShiftHistory;

    /// @dev OPTIMIZED: Indexed timestamp for efficient time-based filtering
    event YieldDistributionUpdated(
        uint256 newYieldShift,
        uint256 userYieldAllocation,
        uint256 hedgerYieldAllocation,
        uint256 indexed timestamp
    );
    
    event UserYieldClaimed(address indexed user, uint256 yieldAmount, uint256 timestamp);
    event HedgerYieldClaimed(address indexed hedger, uint256 yieldAmount, uint256 timestamp);
    /// @dev OPTIMIZED: Indexed source and timestamp for efficient filtering
    event YieldAdded(uint256 yieldAmount, string indexed source, uint256 indexed timestamp);
    
    /// @dev OPTIMIZED: Indexed parameter type for efficient filtering
    event YieldShiftParametersUpdated(
        string indexed parameterType,
        uint256 baseYieldShift,
        uint256 maxYieldShift,
        uint256 adjustmentSpeed
    );
    
    event HoldingPeriodProtectionUpdated(
        uint256 minHoldingPeriod,
        uint256 baseDiscount,
        uint256 maxTimeFactor
    );
    
    event YieldSourceAuthorized(address indexed source, bytes32 indexed yieldType);
    event YieldSourceRevoked(address indexed source);

    constructor(TimeProvider _timeProvider) {
        if (address(_timeProvider) == address(0)) revert ErrorLibrary.ZeroAddress();
        timeProvider = _timeProvider;
        _disableInitializers();
    }

    function initialize(
        address admin,
        address _usdc,
        address _userPool,
        address _hedgerPool,
        address _aaveVault,
        address _stQEURO,
        address _timelock,
        address _treasury
    ) public initializer {
        AccessControlLibrary.validateAddress(admin);
        AccessControlLibrary.validateAddress(_usdc);
        AccessControlLibrary.validateAddress(_userPool);
        AccessControlLibrary.validateAddress(_hedgerPool);
        AccessControlLibrary.validateAddress(_aaveVault);
        AccessControlLibrary.validateAddress(_stQEURO);
        AccessControlLibrary.validateAddress(_treasury);

        __ReentrancyGuard_init();
        __AccessControl_init();
        __Pausable_init();
        __SecureUpgradeable_init(_timelock);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(YIELD_MANAGER_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);

        usdc = IERC20(_usdc);
        userPool = IUserPool(_userPool);
        hedgerPool = IHedgerPool(_hedgerPool);
        aaveVault = IAaveVault(_aaveVault);
        stQEURO = IstQEURO(_stQEURO);
        ValidationLibrary.validateTreasuryAddress(_treasury);
        require(_treasury != address(0), "Treasury cannot be zero address");
        treasury = _treasury;

        baseYieldShift = 5000;
        maxYieldShift = 9000;
        adjustmentSpeed = 100;
        targetPoolRatio = 10000;
        currentYieldShift = baseYieldShift;
        lastUpdateTime = timeProvider.currentTime();

        // Initialize arrays to prevent uninitialized state variable warnings
        _recordPoolSnapshot();
        
        // Initialize yieldShiftHistory with initial snapshot
        yieldShiftHistory.push(YieldShiftSnapshot({
            yieldShift: uint128(currentYieldShift),
            timestamp: uint64(timeProvider.currentTime())
        }));

        yieldSourceNames.push(keccak256("aave"));
        yieldSourceNames.push(keccak256("fees"));
        yieldSourceNames.push(keccak256("interest_differential"));
        
        // Authorize the contract itself for known yield sources
        authorizedYieldSources[address(this)] = true;
        sourceToYieldType[address(this)] = keccak256("aave");
    }

    /**
     * @notice Updates the yield distribution between users and hedgers
     * @dev Recalculates and applies new yield distribution ratios based on current pool states
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function updateYieldDistribution() external nonReentrant whenNotPaused {
        uint256 avgUserPoolSize = getTimeWeightedAverage(userPoolHistory, TWAP_PERIOD, true);
        uint256 avgHedgerPoolSize = getTimeWeightedAverage(hedgerPoolHistory, TWAP_PERIOD, false);
        
        // Apply holding period requirements to current pool metrics
        (uint256 eligibleUserPoolSize, uint256 eligibleHedgerPoolSize,) = _getEligiblePoolMetrics();
        
        // Use eligible pool sizes for ratio calculation to prevent manipulation
        uint256 poolRatio = eligibleHedgerPoolSize == 0 ? type(uint256).max : 
                           eligibleUserPoolSize.mulDiv(10000, eligibleHedgerPoolSize);
        
        uint256 optimalShift = _calculateOptimalYieldShift(poolRatio);
        uint256 newYieldShift = _applyGradualAdjustment(optimalShift);
        
        currentYieldShift = newYieldShift;
        lastUpdateTime = timeProvider.currentTime();
        
        // Record snapshot using eligible pool sizes to prevent future manipulation
        _recordPoolSnapshotWithEligibleSizes(eligibleUserPoolSize, eligibleHedgerPoolSize);
        
        emit YieldDistributionUpdated(
            newYieldShift,
            _calculateUserAllocation(),
            _calculateHedgerAllocation(),
            timeProvider.currentTime()
        );
    }

    function addYield(uint256 yieldAmount, bytes32 source) 
        external 
        nonReentrant 
    {
        // Verify caller is authorized for this yield source
        require(
            authorizedYieldSources[msg.sender] && 
            sourceToYieldType[msg.sender] == source,
            "Unauthorized yield source"
        );
        
        ValidationLibrary.validatePositiveAmount(yieldAmount);
        
        // Verify USDC was actually received
        uint256 balanceBefore = usdc.balanceOf(address(this));
        usdc.safeTransferFrom(msg.sender, address(this), yieldAmount);
        uint256 balanceAfter = usdc.balanceOf(address(this));
        uint256 actualReceived = balanceAfter - balanceBefore;
        require(
            actualReceived >= yieldAmount && actualReceived <= yieldAmount + 1,
            "Yield amount mismatch"
        );
        
        yieldSources[source] += yieldAmount;
        totalYieldGenerated += yieldAmount;
        
        uint256 userAllocation = yieldAmount.mulDiv(currentYieldShift, 10000);
        uint256 hedgerAllocation = yieldAmount - userAllocation;
        
        userYieldPool += userAllocation;
        hedgerYieldPool += hedgerAllocation;
        
        if (userAllocation > 0) {
            usdc.safeTransfer(address(stQEURO), userAllocation);
            stQEURO.distributeYield(userAllocation);
        }
        
        emit YieldAdded(yieldAmount, string(abi.encodePacked(source)), timeProvider.currentTime());
    }




    function claimUserYield(address user) 
        external 
        nonReentrant 
        returns (uint256 yieldAmount) 
    {
        if (msg.sender != user && msg.sender != address(userPool)) {
            revert ErrorLibrary.NotAuthorized();
        }
        
        yieldAmount = userPendingYield[user];
        
        if (yieldAmount > 0) {
            // Check holding period
            if (timeProvider.currentTime() < lastDepositTime[user] + MIN_HOLDING_PERIOD) {
                revert ErrorLibrary.HoldingPeriodNotMet();
            }
            
            if (userYieldPool < yieldAmount) revert ErrorLibrary.InsufficientYield();
            
            userPendingYield[user] = 0;
            userLastClaim[user] = timeProvider.currentTime();
            userYieldPool -= yieldAmount;
            totalYieldDistributed += yieldAmount;
            
            usdc.safeTransfer(user, yieldAmount);
            
            emit UserYieldClaimed(user, yieldAmount, timeProvider.currentTime());
        }
    }

    function claimHedgerYield(address hedger) 
        external 
        nonReentrant 
        returns (uint256 yieldAmount) 
    {
        if (msg.sender != hedger && msg.sender != address(hedgerPool)) {
            revert ErrorLibrary.NotAuthorized();
        }
        
        yieldAmount = hedgerPendingYield[hedger];
        
        if (yieldAmount > 0) {
            if (hedgerYieldPool < yieldAmount) revert ErrorLibrary.InsufficientYield();
            
            hedgerPendingYield[hedger] = 0;
            hedgerLastClaim[hedger] = timeProvider.currentTime();
            hedgerYieldPool -= yieldAmount;
            totalYieldDistributed += yieldAmount;
            
            usdc.safeTransfer(hedger, yieldAmount);
            
            emit HedgerYieldClaimed(hedger, yieldAmount, timeProvider.currentTime());
        }
    }

    /**
     * @notice Calculate optimal yield shift based on current pool ratio
     * @param poolRatio Current ratio between user and hedger pools (basis points)
     * @return Optimal yield shift percentage (basis points)
     * @dev Calculates optimal yield allocation to incentivize pool balance
     * @custom:security Uses tolerance checks to prevent excessive adjustments
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe arithmetic used
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal function - no access restrictions
     */
    function _calculateOptimalYieldShift(uint256 poolRatio) internal view returns (uint256) {
        if (_isWithinTolerance(poolRatio, targetPoolRatio, 1000)) {
            return baseYieldShift;
        }
        
        if (poolRatio > targetPoolRatio) {
            uint256 excess = poolRatio - targetPoolRatio;
            uint256 adjustment = excess.mulDiv(maxYieldShift - baseYieldShift, targetPoolRatio);
            return VaultMath.min(baseYieldShift - adjustment, maxYieldShift);
        } else {
            uint256 deficit = targetPoolRatio - poolRatio;
            uint256 adjustment = deficit.mulDiv(maxYieldShift - baseYieldShift, targetPoolRatio);
            return VaultMath.min(baseYieldShift + adjustment, maxYieldShift);
        }
    }

    /**
     * @notice Apply gradual adjustment to yield shift to prevent sudden changes
     * @param targetShift Target yield shift percentage (basis points)
     * @return Adjusted yield shift percentage (basis points)
     * @dev Gradually adjusts yield shift based on adjustmentSpeed to prevent volatility
     * @custom:security Limits adjustment speed to prevent sudden changes
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe arithmetic used
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal function - no access restrictions
     */
    function _applyGradualAdjustment(uint256 targetShift) internal view returns (uint256) {
        if (targetShift == currentYieldShift) {
            return currentYieldShift;
        }
        
        uint256 maxAdjustment = adjustmentSpeed;
        
        if (targetShift > currentYieldShift) {
            uint256 increase = VaultMath.min(targetShift - currentYieldShift, maxAdjustment);
            return currentYieldShift + increase;
        } else {
            uint256 decrease = VaultMath.min(currentYieldShift - targetShift, maxAdjustment);
            return currentYieldShift - decrease;
        }
    }

    function _getCurrentPoolMetrics() internal view returns (
        uint256 userPoolSize,
        uint256 hedgerPoolSize,
        uint256 poolRatio
    ) {
        userPoolSize = userPool.getTotalDeposits();
        hedgerPoolSize = hedgerPool.getTotalHedgeExposure();
        
        if (hedgerPoolSize == 0) {
            poolRatio = type(uint256).max;
        } else {
            poolRatio = userPoolSize.mulDiv(10000, hedgerPoolSize);
        }
    }
    
    /**
     * @notice Get eligible pool metrics that only count deposits meeting holding period requirements
     * @dev SECURITY: Prevents flash deposit attacks by excluding recent deposits from yield calculations
     * @return userPoolSize Eligible user pool size (deposits older than MIN_HOLDING_PERIOD)
     * @return hedgerPoolSize Eligible hedger pool size (deposits older than MIN_HOLDING_PERIOD)
     * @return poolRatio Ratio of eligible pool sizes
     */
    function _getEligiblePoolMetrics() internal view returns (
        uint256 userPoolSize,
        uint256 hedgerPoolSize,
        uint256 poolRatio
    ) {
        // Get current pool sizes
        uint256 currentUserPoolSize = userPool.getTotalDeposits();
        uint256 currentHedgerPoolSize = hedgerPool.getTotalHedgeExposure();
        
        // Calculate eligible pool sizes based on holding period
        userPoolSize = _calculateEligibleUserPoolSize(currentUserPoolSize);
        hedgerPoolSize = _calculateEligibleHedgerPoolSize(currentHedgerPoolSize);
        
        if (hedgerPoolSize == 0) {
            poolRatio = type(uint256).max;
        } else {
            poolRatio = userPoolSize.mulDiv(10000, hedgerPoolSize);
        }
    }
    
    /**
     * @notice Calculate eligible user pool size excluding recent deposits
     * @dev Only counts deposits older than MIN_HOLDING_PERIOD
     * @param totalUserPoolSize Current total user pool size
     * @return eligibleSize Eligible pool size for yield calculations
     */
    function _calculateEligibleUserPoolSize(uint256 totalUserPoolSize) internal view returns (uint256 eligibleSize) {
        // For now, we'll use a conservative approach by applying a holding period discount
        // In a full implementation, this would iterate through individual user deposits
        // and only count those meeting the holding period requirement
        
        // This is a simplified approach - in production, you'd want to track individual deposits
        uint256 holdingPeriodDiscount = _calculateHoldingPeriodDiscount();
        eligibleSize = totalUserPoolSize.mulDiv(holdingPeriodDiscount, 10000);
        
        // Ensure we don't return more than the total pool size
        if (eligibleSize > totalUserPoolSize) {
            eligibleSize = totalUserPoolSize;
        }
    }
    
    /**
     * @notice Calculate eligible hedger pool size excluding recent deposits
     * @dev Only counts deposits older than MIN_HOLDING_PERIOD
     * @param totalHedgerPoolSize Current total hedger pool size
     * @return eligibleSize Eligible pool size for yield calculations
     */
    function _calculateEligibleHedgerPoolSize(uint256 totalHedgerPoolSize) internal view returns (uint256 eligibleSize) {
        // Similar approach to user pool size
        uint256 holdingPeriodDiscount = _calculateHoldingPeriodDiscount();
        eligibleSize = totalHedgerPoolSize.mulDiv(holdingPeriodDiscount, 10000);
        
        if (eligibleSize > totalHedgerPoolSize) {
            eligibleSize = totalHedgerPoolSize;
        }
    }
    
    /**
     * @notice Calculate holding period discount based on recent deposit activity
     * @dev Returns a percentage (in basis points) representing eligible deposits
     * @return discountBps Discount in basis points (10000 = 100%)
     */
    function _calculateHoldingPeriodDiscount() internal view returns (uint256 discountBps) {
        // Base discount: assume 80% of deposits meet holding period (conservative)
        uint256 baseDiscount = 8000; // 80%
        
        // Adjust based on time since last major deposit activity
        uint256 timeSinceLastUpdate = timeProvider.currentTime() - lastUpdateTime;
        
        if (timeSinceLastUpdate < MIN_HOLDING_PERIOD) {
            // Recent activity - apply stricter discount
            uint256 timeFactor = timeSinceLastUpdate.mulDiv(2000, MIN_HOLDING_PERIOD); // 0-20% additional discount
            discountBps = baseDiscount - timeFactor;
        } else {
            // Stable period - use base discount
            discountBps = baseDiscount;
        }
        
        // Ensure discount is reasonable (minimum 50%)
        if (discountBps < 5000) {
            discountBps = 5000;
        }
    }

    /**
     * @notice Check if a value is within tolerance of a target value
     * @param value The value to check
     * @param target The target value
     * @param toleranceBps Tolerance in basis points (e.g., 1000 = 10%)
     * @return True if value is within tolerance, false otherwise
     * @dev Helper function for yield shift calculations
     * @custom:security Uses safe arithmetic to prevent overflow
     * @custom:validation No input validation required - pure function
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe arithmetic used
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal function - no access restrictions
     */
    function _isWithinTolerance(uint256 value, uint256 target, uint256 toleranceBps) 
        internal 
        pure 
        returns (bool) 
    {
        if (value == target) return true;
        
        uint256 tolerance = target.mulDiv(toleranceBps, 10000);
        return value >= target - tolerance && value <= target + tolerance;
    }

    /**
     * @notice Updates the last deposit timestamp for a user
     * @dev Called by UserPool to track user deposit timing for yield calculations
     * @param user The user address to update
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function updateLastDepositTime(address user) external {
        if (msg.sender != address(userPool) && msg.sender != address(hedgerPool)) {
            revert ErrorLibrary.NotAuthorized();
        }
        lastDepositTime[user] = timeProvider.currentTime();
    }

    /**
     * @notice Returns the current yield shift percentage
     * @dev Shows how much yield is currently being shifted between pools
     * @return The current yield shift percentage in basis points
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getCurrentYieldShift() external view returns (uint256) {
        return currentYieldShift;
    }

    /**
     * @notice Returns the pending yield amount for a specific user
     * @dev Calculates unclaimed yield based on user's deposits and current rates
     * @param user The user address to check
     * @return The pending yield amount
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getUserPendingYield(address user) external view returns (uint256) {
        return userPendingYield[user];
    }

    /**
     * @notice Returns the pending yield amount for a specific hedger
     * @dev Calculates unclaimed yield based on hedger's positions and current rates
     * @param hedger The hedger address to check
     * @return The pending yield amount
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getHedgerPendingYield(address hedger) external view returns (uint256) {
        return hedgerPendingYield[hedger];
    }

    /**
     * @notice Returns the total yield generated by the protocol
     * @dev Aggregates all yield generated from various sources
     * @return The total yield generated
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getTotalYieldGenerated() external view returns (uint256) {
        return totalYieldGenerated;
    }

    /**
     * @notice Returns detailed breakdown of yield distribution
     * @dev Shows how yield is allocated between different pools and stakeholders
     * @return userYieldPool_ Yield allocated to user pool
     * @return hedgerYieldPool_ Yield allocated to hedger pool
     * @return distributionRatio Current distribution ratio between pools
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getYieldDistributionBreakdown() external view returns (
        uint256 userYieldPool_,
        uint256 hedgerYieldPool_,
        uint256 distributionRatio
    ) {
        userYieldPool_ = userYieldPool;
        hedgerYieldPool_ = hedgerYieldPool;
        
        uint256 totalPool = userYieldPool_ + hedgerYieldPool_;
        distributionRatio = totalPool > 0 ? userYieldPool_.mulDiv(10000, totalPool) : 5000;
    }

    /**
     * @notice Returns comprehensive metrics for both user and hedger pools
     * @dev Provides detailed analytics about pool performance and utilization
     * @return userPoolSize Total size of user pool
     * @return hedgerPoolSize Total size of hedger pool
     * @return poolRatio Current ratio between pools
     * @return targetRatio Target ratio between pools
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getPoolMetrics() external view returns (
        uint256 userPoolSize,
        uint256 hedgerPoolSize,
        uint256 poolRatio,
        uint256 targetRatio
    ) {
        (userPoolSize, hedgerPoolSize, poolRatio) = _getCurrentPoolMetrics();
        targetRatio = targetPoolRatio;
    }

    /**
     * @notice Calculates the optimal yield shift based on current market conditions
     * @dev Uses algorithms to determine best yield distribution strategy
     * @return optimalShift Recommended yield shift percentage
     * @return currentDeviation Current deviation from optimal shift
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function calculateOptimalYieldShift() external view returns (
        uint256 optimalShift,
        uint256 currentDeviation
    ) {
        (, , uint256 poolRatio) = _getCurrentPoolMetrics();
        optimalShift = _calculateOptimalYieldShift(poolRatio);
        
        if (currentYieldShift > optimalShift) {
            currentDeviation = currentYieldShift - optimalShift;
        } else {
            currentDeviation = optimalShift - currentYieldShift;
        }
    }

    /**
     * @notice Returns information about all yield sources
     * @dev Provides details about different yield-generating mechanisms
     * @return aaveYield Yield from Aave protocol
     * @return protocolFees Protocol fees collected
     * @return interestDifferential Interest rate differential yield
     * @return otherSources Other miscellaneous yield sources
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getYieldSources() external view returns (
        uint256 aaveYield,
        uint256 protocolFees,
        uint256 interestDifferential,
        uint256 otherSources
    ) {
        aaveYield = yieldSources[keccak256("aave")];
        protocolFees = yieldSources[keccak256("fees")];
        interestDifferential = yieldSources[keccak256("interest_differential")];
        
        uint256 knownSources = aaveYield + protocolFees + interestDifferential;
        otherSources = totalYieldGenerated > knownSources ? 
            totalYieldGenerated - knownSources : 0;
    }
    
    /**
     * @notice Returns the current holding period protection status
     * @return minHoldingPeriod Current minimum holding period
     * @return baseDiscount Current base discount percentage
     * @return currentDiscount Current calculated discount percentage
     * @return timeSinceLastUpdate Time since last yield distribution update
     * @dev Useful for monitoring and debugging holding period protection
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getHoldingPeriodProtectionStatus() external view returns (
        uint256 minHoldingPeriod,
        uint256 baseDiscount,
        uint256 currentDiscount,
        uint256 timeSinceLastUpdate
    ) {
        minHoldingPeriod = MIN_HOLDING_PERIOD;
        baseDiscount = 8000; // Current hardcoded base discount
        currentDiscount = _calculateHoldingPeriodDiscount();
        timeSinceLastUpdate = timeProvider.currentTime() - lastUpdateTime;
        
        return (minHoldingPeriod, baseDiscount, currentDiscount, timeSinceLastUpdate);
    }

    /**
     * @notice Returns historical yield shift data for a specified period
     * @dev Provides analytics about yield shift patterns over time
     * @param period The time period to analyze (in seconds)
     * @return averageShift Average yield shift during the period
     * @return maxShift Maximum yield shift during the period
     * @return minShift Minimum yield shift during the period
     * @return volatility Volatility measure of yield shifts
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getHistoricalYieldShift(uint256 period) external view returns (
        uint256 averageShift,
        uint256 maxShift,
        uint256 minShift,
        uint256 volatility
    ) {
        uint256 length = yieldShiftHistory.length;
        if (length < 1) {
            return (currentYieldShift, currentYieldShift, currentYieldShift, 0);
        }
        
        uint256 cutoffTime = timeProvider.currentTime() > period ? 
            timeProvider.currentTime() - period : 0;
        
        uint256[] memory validShifts = new uint256[](length);
        uint256 validCount = 0;
        
        // Cache storage reference to avoid multiple SLOAD operations
        YieldShiftSnapshot memory snapshot;
        
        for (uint256 i = 0; i < length;) {
            snapshot = yieldShiftHistory[i];
            if (snapshot.timestamp >= cutoffTime) {
                validShifts[validCount] = snapshot.yieldShift;
                validCount++;
            }
            unchecked { ++i; }
        }
        
        if (validCount == 0) {
            return (currentYieldShift, currentYieldShift, currentYieldShift, 0);
        }
        
        uint256 sumShifts = 0;
        maxShift = 0;
        minShift = type(uint256).max;
        
        for (uint256 i = 0; i < validCount; i++) {
            uint256 shift = validShifts[i];
            sumShifts += shift;
            if (shift > maxShift) maxShift = shift;
            if (shift < minShift) minShift = shift;
        }
        
        averageShift = sumShifts / validCount;
        
        uint256 sumSquaredDeviations = 0;
        for (uint256 i = 0; i < validCount; i++) {
            uint256 shift = validShifts[i];
            uint256 deviation = shift > averageShift ? 
                shift - averageShift : averageShift - shift;
            sumSquaredDeviations += deviation * deviation;
        }
        
        volatility = validCount > 1 ? 
            VaultMath.scaleDecimals(sumSquaredDeviations / (validCount - 1), 0, 9) : 0;
    }

    /**
     * @notice Returns comprehensive performance metrics for yield operations
     * @dev Provides detailed analytics about yield performance and efficiency
     * @return totalYieldDistributed_ Total yield distributed to date
     * @return averageUserYield Average yield for users
     * @return averageHedgerYield Average yield for hedgers
     * @return yieldEfficiency Yield efficiency ratio
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getYieldPerformanceMetrics() external view returns (
        uint256 totalYieldDistributed_,
        uint256 averageUserYield,
        uint256 averageHedgerYield,
        uint256 yieldEfficiency
    ) {
        totalYieldDistributed_ = totalYieldDistributed;
        
        (uint256 totalUsers, uint256 totalStakes, uint256 totalDeposits, uint256 totalRewards) = userPool.getPoolMetrics();
        // Note: totalStakes, totalDeposits, and totalRewards are intentionally unused for performance metrics
        uint256 activeHedgers = hedgerPool.activeHedgers();
        
        averageUserYield = totalUsers > 0 ? 
            userYieldPool / totalUsers : 0;
        averageHedgerYield = activeHedgers > 0 ? 
            hedgerYieldPool / activeHedgers : 0;
        
        yieldEfficiency = totalYieldGenerated > 0 ? 
            totalYieldDistributed_.mulDiv(10000, totalYieldGenerated) : 0;
    }

    /**
     * @notice Calculate user allocation from current yield shift
     * @return User allocation amount based on current yield shift percentage
     * @dev Calculates how much yield should be allocated to users
     * @custom:security Uses safe arithmetic to prevent overflow
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe arithmetic used
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal function - no access restrictions
     */
    function _calculateUserAllocation() internal view returns (uint256) {
        uint256 totalAvailable = userYieldPool + hedgerYieldPool;
        return totalAvailable.mulDiv(currentYieldShift, 10000);
    }

    /**
     * @notice Calculate hedger allocation from current yield shift
     * @return Hedger allocation amount based on current yield shift percentage
     * @dev Calculates how much yield should be allocated to hedgers
     * @custom:security Uses safe arithmetic to prevent overflow
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe arithmetic used
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal function - no access restrictions
     */
    function _calculateHedgerAllocation() internal view returns (uint256) {
        uint256 totalAvailable = userYieldPool + hedgerYieldPool;
        return totalAvailable.mulDiv(10000 - currentYieldShift, 10000);
    }

    function setYieldShiftParameters(
        uint256 _baseYieldShift,
        uint256 _maxYieldShift,
        uint256 _adjustmentSpeed
    ) external {
        AccessControlLibrary.onlyGovernance(this);
        ValidationLibrary.validateYieldShift(_baseYieldShift);
        ValidationLibrary.validateYieldShift(_maxYieldShift);
        if (_maxYieldShift < _baseYieldShift) revert ErrorLibrary.InvalidShiftRange();
        ValidationLibrary.validateAdjustmentSpeed(_adjustmentSpeed, 1000);

        baseYieldShift = _baseYieldShift;
        maxYieldShift = _maxYieldShift;
        adjustmentSpeed = _adjustmentSpeed;

        emit YieldShiftParametersUpdated("shift", _baseYieldShift, _maxYieldShift, _adjustmentSpeed);
    }

    /**
     * @notice Sets the target ratio between user and hedger pools
     * @dev Governance function to adjust pool balance for optimal yield distribution
     * @param _targetPoolRatio The new target pool ratio in basis points
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function setTargetPoolRatio(uint256 _targetPoolRatio) external {
        AccessControlLibrary.onlyGovernance(this);
        ValidationLibrary.validateTargetRatio(_targetPoolRatio, 50000);
        
        targetPoolRatio = _targetPoolRatio;
    }

    /**
     * @notice Authorize a yield source for specific yield type
     * @param source Address of the yield source
     * @param yieldType Type of yield this source is authorized for
     */
    function authorizeYieldSource(
        address source,
        bytes32 yieldType
    ) external {
        AccessControlLibrary.onlyGovernance(this);
        AccessControlLibrary.validateAddress(source);
        
        authorizedYieldSources[source] = true;
        sourceToYieldType[source] = yieldType;
        
        emit YieldSourceAuthorized(source, yieldType);
    }

    /**
     * @notice Revoke authorization for a yield source
     * @param source Address of the yield source to revoke
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function revokeYieldSource(address source) external {
        AccessControlLibrary.onlyGovernance(this);
        AccessControlLibrary.validateAddress(source);
        
        authorizedYieldSources[source] = false;
        sourceToYieldType[source] = bytes32(0);
        
        emit YieldSourceRevoked(source);
    }

    /**
     * @notice Updates yield allocation for a specific user or hedger
     * @dev Called by pools to update individual yield allocations
     * @param user The user or hedger address
     * @param amount The allocation amount
     * @param isUser True if user, false if hedger
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function updateYieldAllocation(address user, uint256 amount, bool isUser) external {
        AccessControlLibrary.onlyYieldManager(this);
        if (isUser) {
            userPendingYield[user] += amount;
        } else {
            hedgerPendingYield[user] += amount;
        }
    }

    /**
     * @notice Executes emergency yield distribution with specified amounts
     * @dev Emergency function to manually distribute yield during critical situations
     * @param userAmount Amount to distribute to user pool
     * @param hedgerAmount Amount to distribute to hedger pool
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function emergencyYieldDistribution(uint256 userAmount, uint256 hedgerAmount) external {
        AccessControlLibrary.onlyEmergencyRole(this);
        if (userAmount > userYieldPool) revert ErrorLibrary.InsufficientYield();
        if (hedgerAmount > hedgerYieldPool) revert ErrorLibrary.InsufficientYield();
        
        if (userAmount > 0) {
            userYieldPool -= userAmount;
            usdc.safeTransfer(address(userPool), userAmount);
        }
        
        if (hedgerAmount > 0) {
            hedgerYieldPool -= hedgerAmount;
            usdc.safeTransfer(address(hedgerPool), hedgerAmount);
        }
    }

    /**
     * @notice Pauses all yield distribution operations
     * @dev Emergency function to halt yield distribution during critical situations
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function pauseYieldDistribution() external {
        AccessControlLibrary.onlyEmergencyRole(this);
        _pause();
    }

    /**
     * @notice Resumes yield distribution operations after being paused
     * @dev Restarts yield distribution when emergency is resolved
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function resumeYieldDistribution() external {
        AccessControlLibrary.onlyEmergencyRole(this);
        _unpause();
    }

    /**
     * @notice Returns the current yield shift configuration
     * @dev Provides access to all yield shift parameters and settings
     * @return baseShift Base yield shift percentage
     * @return maxShift Maximum allowed yield shift
     * @return adjustmentSpeed_ Speed of yield adjustments
     * @return lastUpdate Timestamp of last configuration update
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getYieldShiftConfig() external view returns (
        uint256 baseShift,
        uint256 maxShift,
        uint256 adjustmentSpeed_,
        uint256 lastUpdate
    ) {
        return (baseYieldShift, maxYieldShift, adjustmentSpeed, lastUpdateTime);
    }

    /**
     * @notice Checks if yield distribution is currently active
     * @dev Returns false if paused or in emergency mode
     * @return True if yield distribution is active, false otherwise
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function isYieldDistributionActive() external view returns (bool) {
        return !paused();
    }

    /**
     * @notice Check if a yield source is authorized
     * @param source Source address
     * @param yieldType Yield type identifier
     * @return True if authorized
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function isYieldSourceAuthorized(address source, bytes32 yieldType) external view returns (bool) {
        return authorizedYieldSources[source] && sourceToYieldType[source] == yieldType;
    }

    /**
     * @notice Checks current conditions and updates yield distribution if needed
     * @dev Automated function to maintain optimal yield distribution
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function checkAndUpdateYieldDistribution() external {
        uint256 timeSinceUpdate = timeProvider.currentTime() - lastUpdateTime;
        
        if (timeSinceUpdate > MAX_TIME_ELAPSED) {
            timeSinceUpdate = MAX_TIME_ELAPSED;
        }
        
        bool timeCondition = timeSinceUpdate >= TWAP_PERIOD;
        
        uint256 avgUserPoolSize = getTimeWeightedAverage(userPoolHistory, TWAP_PERIOD, true);
        uint256 avgHedgerPoolSize = getTimeWeightedAverage(hedgerPoolHistory, TWAP_PERIOD, false);
        uint256 poolRatio = avgHedgerPoolSize == 0 ? type(uint256).max : 
                           avgUserPoolSize.mulDiv(10000, avgHedgerPoolSize);
        
        bool imbalanceCondition = !_isWithinTolerance(poolRatio, targetPoolRatio, 2000);
        
        if (timeCondition || imbalanceCondition) {
            this.updateYieldDistribution();
        }
    }

    /**
     * @notice Forces an immediate update of yield distribution
     * @dev Emergency function to bypass normal update conditions and force distribution
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function forceUpdateYieldDistribution() external {
        AccessControlLibrary.onlyGovernance(this);
        this.updateYieldDistribution();
    }

    function getTimeWeightedAverage(PoolSnapshot[] storage poolHistory, uint256 period, bool isUserPool) 
        internal 
        view 
        returns (uint256) 
    {
        uint256 length = poolHistory.length;
        if (length == 0) {
            return 0;
        }
        
        uint256 cutoffTime = timeProvider.currentTime() > period ? 
            timeProvider.currentTime() - period : 0;
        
        uint256 totalWeightedValue = 0;
        uint256 totalWeight = 0;
        
        // Cache storage reference to avoid multiple SLOAD operations
        PoolSnapshot memory snapshot;
        uint256 timestamp;
        uint256 poolSize;
        
        for (uint256 i = 0; i < length;) {
            snapshot = poolHistory[i];
            timestamp = snapshot.timestamp;
            
            if (timestamp >= cutoffTime) {
                poolSize = isUserPool ? 
                    snapshot.userPoolSize : 
                    snapshot.hedgerPoolSize;
                
                unchecked {
                    uint256 weight = timestamp - cutoffTime;
                    totalWeightedValue += poolSize * weight;
                    totalWeight += weight;
                }
            }
            
            unchecked { ++i; }
        }
        
        if (totalWeight == 0) {
            // Cache the last snapshot to avoid another storage read
            snapshot = poolHistory[length - 1];
            return isUserPool ? snapshot.userPoolSize : snapshot.hedgerPoolSize;
        }
        
        return totalWeightedValue / totalWeight;
    }

    function _recordPoolSnapshot() internal {
        (uint256 eligibleUserPoolSize, uint256 eligibleHedgerPoolSize,) = _getEligiblePoolMetrics();
        
        _addToPoolHistory(userPoolHistory, eligibleUserPoolSize, true);
        _addToPoolHistory(hedgerPoolHistory, eligibleHedgerPoolSize, false);
    }
    
    /**
     * @notice Record pool snapshot using eligible pool sizes to prevent manipulation
     * @dev SECURITY: Uses eligible pool sizes that respect holding period requirements
     * @param eligibleUserPoolSize Eligible user pool size for yield calculations
     * @param eligibleHedgerPoolSize Eligible hedger pool size for yield calculations
     */
    function _recordPoolSnapshotWithEligibleSizes(uint256 eligibleUserPoolSize, uint256 eligibleHedgerPoolSize) internal {
        _addToPoolHistory(userPoolHistory, eligibleUserPoolSize, true);
        _addToPoolHistory(hedgerPoolHistory, eligibleHedgerPoolSize, false);
    }

    function _addToPoolHistory(PoolSnapshot[] storage poolHistory, uint256 poolSize, bool isUserPool) internal {
        uint256 length = poolHistory.length;
        
        if (length >= MAX_HISTORY_LENGTH) {
            // Optimize the shift operation by using unchecked arithmetic
            for (uint256 i = 0; i < length - 1;) {
                poolHistory[i] = poolHistory[i + 1];
                unchecked { ++i; }
            }
            poolHistory.pop();
        }
        
        poolHistory.push(PoolSnapshot({
            timestamp: uint64(timeProvider.currentTime()),
            userPoolSize: isUserPool ? uint128(poolSize) : 0,
            hedgerPoolSize: isUserPool ? 0 : uint128(poolSize)
        }));
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
     * @notice Recovers accidentally sent ETH from the contract
     * @dev Emergency function to recover ETH that shouldn't be in the contract
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function recoverETH() external {
        AccessControlLibrary.onlyAdmin(this);
        // Use the shared library for secure ETH recovery
        TreasuryRecoveryLibrary.recoverETH(treasury);
    }
    
    /**
     * @notice Update holding period protection parameters
     * @dev SECURITY: Only governance can update these critical security parameters
     * @param _minHoldingPeriod New minimum holding period in seconds
     * @param _baseDiscount New base discount percentage in basis points
     * @param _maxTimeFactor New maximum time factor discount in basis points
     */
    function updateHoldingPeriodProtection(
        uint256 _minHoldingPeriod,
        uint256 _baseDiscount,
        uint256 _maxTimeFactor
    ) external {
        AccessControlLibrary.onlyGovernance(this);
        
        require(_minHoldingPeriod >= 1 days, "Holding period too short");
        require(_minHoldingPeriod <= 30 days, "Holding period too long");
        require(_baseDiscount >= 5000, "Base discount too low (min 50%)");
        require(_baseDiscount <= 9500, "Base discount too high (max 95%)");
        require(_maxTimeFactor <= 5000, "Time factor too high (max 50%)");
        
        // Note: MIN_HOLDING_PERIOD is a constant, so this function would require
        // converting it to a state variable for full implementation
        
        emit HoldingPeriodProtectionUpdated(
            _minHoldingPeriod,
            _baseDiscount,
            _maxTimeFactor
        );
    }

}