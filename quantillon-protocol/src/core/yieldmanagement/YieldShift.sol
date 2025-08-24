// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../interfaces/IUserPool.sol";
import "../../interfaces/IHedgerPool.sol";
import "../../interfaces/IAaveVault.sol";
import "../../interfaces/IstQEURO.sol";
import "../../libraries/VaultMath.sol";

/**
 * @title YieldShift
 * @notice Dynamic yield redistribution mechanism between Users and Hedgers
 * @dev Core innovation of Quantillon Protocol - balances pools via yield incentives
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract YieldShift is 
    Initializable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;
    using VaultMath for uint256;

    // =============================================================================
    // CONSTANTS AND ROLES
    // =============================================================================
    
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant YIELD_MANAGER_ROLE = keccak256("YIELD_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // =============================================================================
    // STATE VARIABLES
    // =============================================================================
    
    /// @notice USDC token contract
    IERC20 public usdc;
    
    /// @notice User pool contract
    IUserPool public userPool;
    
    /// @notice Hedger pool contract
    IHedgerPool public hedgerPool;
    
    /// @notice Aave vault contract
    IAaveVault public aaveVault;
    
    /// @notice stQEURO token contract (primary yield-bearing token)
    IstQEURO public stQEURO;

    // Yield Shift Configuration
    uint256 public baseYieldShift;          // Base yield shift percentage (bps)
    uint256 public maxYieldShift;           // Maximum yield shift (bps) 
    uint256 public adjustmentSpeed;         // Speed of yield shift adjustments
    uint256 public targetPoolRatio;        // Target user/hedger pool ratio
    
    // Time-weighted average protection
    uint256 public constant MIN_HOLDING_PERIOD = 7 days;
    uint256 public constant TWAP_PERIOD = 24 hours;
    
    // Current State
    uint256 public currentYieldShift;       // Current yield shift percentage
    uint256 public lastUpdateTime;          // Last yield shift update time
    
    // Yield Tracking
    uint256 public totalYieldGenerated;     // Total yield generated
    uint256 public totalYieldDistributed;   // Total yield distributed
    uint256 public userYieldPool;           // Yield allocated to users
    uint256 public hedgerYieldPool;         // Yield allocated to hedgers
    
    // Yield Sources
    mapping(string => uint256) public yieldSources; // Track yield by source
    string[] public yieldSourceNames;       // Array of yield source names
    
    // User and Hedger yield tracking
    mapping(address => uint256) public userPendingYield;
    mapping(address => uint256) public hedgerPendingYield;
    mapping(address => uint256) public userLastClaim;
    mapping(address => uint256) public hedgerLastClaim;
    
    // Time-weighted average tracking
    mapping(address => uint256) public lastDepositTime;
    
    // Pool history for TWAP calculations
    struct PoolSnapshot {
        uint256 timestamp;
        uint256 userPoolSize;
        uint256 hedgerPoolSize;
    }
    
    PoolSnapshot[] public userPoolHistory;
    PoolSnapshot[] public hedgerPoolHistory;
    uint256 public constant MAX_HISTORY_LENGTH = 1000;

    // =============================================================================
    // EVENTS
    // =============================================================================
    
    event YieldDistributionUpdated(
        uint256 newYieldShift,
        uint256 userYieldAllocation,
        uint256 hedgerYieldAllocation,
        uint256 timestamp
    );
    
    event UserYieldClaimed(address indexed user, uint256 yieldAmount, uint256 timestamp);
    event HedgerYieldClaimed(address indexed hedger, uint256 yieldAmount, uint256 timestamp);
    event YieldAdded(uint256 yieldAmount, string source, uint256 timestamp);
    
    event YieldShiftParametersUpdated(
        uint256 baseYieldShift,
        uint256 maxYieldShift,
        uint256 adjustmentSpeed
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
        address _userPool,
        address _hedgerPool,
        address _aaveVault,
        address _stQEURO
    ) public initializer {
        require(admin != address(0), "YieldShift: Admin cannot be zero");
        require(_usdc != address(0), "YieldShift: USDC cannot be zero");
        require(_userPool != address(0), "YieldShift: UserPool cannot be zero");
        require(_hedgerPool != address(0), "YieldShift: HedgerPool cannot be zero");
        require(_aaveVault != address(0), "YieldShift: AaveVault cannot be zero");
        require(_stQEURO != address(0), "YieldShift: stQEURO cannot be zero");

        __ReentrancyGuard_init();
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(YIELD_MANAGER_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        usdc = IERC20(_usdc);
        userPool = IUserPool(_userPool);
        hedgerPool = IHedgerPool(_hedgerPool);
        aaveVault = IAaveVault(_aaveVault);
        stQEURO = IstQEURO(_stQEURO);

        // Default configuration
        baseYieldShift = 5000;          // 50% base allocation to each pool
        maxYieldShift = 9000;           // Max 90% to one side
        adjustmentSpeed = 100;          // 1% adjustment per update
        targetPoolRatio = 10000;        // 1:1 target ratio (100%)
        currentYieldShift = baseYieldShift;
        lastUpdateTime = block.timestamp;

        // Initialize pool history for TWAP calculations
        _recordPoolSnapshot();

        // Initialize yield source tracking
        yieldSourceNames.push("aave");
        yieldSourceNames.push("fees");
        yieldSourceNames.push("interest_differential");
    }

    // =============================================================================
    // CORE YIELD DISTRIBUTION FUNCTIONS
    // =============================================================================

    /**
     * @notice Update yield distribution based on time-weighted average pool balances
     * @dev Uses TWAP to prevent gaming by large actors
     */
    function updateYieldDistribution() external nonReentrant whenNotPaused {
        // Use time-weighted average instead of spot values
        uint256 avgUserPoolSize = getTimeWeightedAverage(userPoolHistory, TWAP_PERIOD, true);
        uint256 avgHedgerPoolSize = getTimeWeightedAverage(hedgerPoolHistory, TWAP_PERIOD, false);
        
        uint256 poolRatio = avgHedgerPoolSize == 0 ? type(uint256).max : 
                           avgUserPoolSize.mulDiv(10000, avgHedgerPoolSize);
        
        // Calculate optimal yield shift
        uint256 optimalShift = _calculateOptimalYieldShift(poolRatio);
        
        // Apply gradual adjustment
        uint256 newYieldShift = _applyGradualAdjustment(optimalShift);
        
        // Update current yield shift
        currentYieldShift = newYieldShift;
        lastUpdateTime = block.timestamp;
        
        // Record current pool sizes in history
        _recordPoolSnapshot();
        
        emit YieldDistributionUpdated(
            newYieldShift,
            _calculateUserAllocation(),
            _calculateHedgerAllocation(),
            block.timestamp
        );
    }

    /**
     * @notice Add new yield from protocol operations
     */
    function addYield(uint256 yieldAmount, string calldata source) 
        external 
        onlyRole(YIELD_MANAGER_ROLE) 
        nonReentrant 
    {
        require(yieldAmount > 0, "YieldShift: Yield amount must be positive");
        
        // Track yield by source
        yieldSources[source] += yieldAmount;
        totalYieldGenerated += yieldAmount;
        
        // Distribute yield based on current shift
        uint256 userAllocation = yieldAmount.mulDiv(currentYieldShift, 10000);
        uint256 hedgerAllocation = yieldAmount - userAllocation;
        
        userYieldPool += userAllocation;
        hedgerYieldPool += hedgerAllocation;
        
        // Send yield to stQEURO contract (primary yield-bearing token)
        if (userAllocation > 0) {
            // Transfer USDC to stQEURO for yield distribution
            usdc.safeTransfer(address(stQEURO), userAllocation);
            // Notify stQEURO to distribute yield
            stQEURO.distributeYield(userAllocation);
        }
        
        emit YieldAdded(yieldAmount, source, block.timestamp);
    }

    /**
     * @notice Claim pending yield for a user
     */
    function claimUserYield(address user) 
        external 
        nonReentrant 
        checkHoldingPeriod
        returns (uint256 yieldAmount) 
    {
        require(msg.sender == user || msg.sender == address(userPool), "YieldShift: Unauthorized");
        
        yieldAmount = userPendingYield[user];
        
        if (yieldAmount > 0) {
            require(userYieldPool >= yieldAmount, "YieldShift: Insufficient user yield pool");
            
            userPendingYield[user] = 0;
            userLastClaim[user] = block.timestamp;
            userYieldPool -= yieldAmount;
            totalYieldDistributed += yieldAmount;
            
            // Transfer USDC yield to user
            usdc.safeTransfer(user, yieldAmount);
            
            emit UserYieldClaimed(user, yieldAmount, block.timestamp);
        }
    }

    /**
     * @notice Claim pending yield for a hedger
     */
    function claimHedgerYield(address hedger) 
        external 
        nonReentrant 
        checkHoldingPeriod
        returns (uint256 yieldAmount) 
    {
        require(msg.sender == hedger || msg.sender == address(hedgerPool), "YieldShift: Unauthorized");
        
        yieldAmount = hedgerPendingYield[hedger];
        
        if (yieldAmount > 0) {
            require(hedgerYieldPool >= yieldAmount, "YieldShift: Insufficient hedger yield pool");
            
            hedgerPendingYield[hedger] = 0;
            hedgerLastClaim[hedger] = block.timestamp;
            hedgerYieldPool -= yieldAmount;
            totalYieldDistributed += yieldAmount;
            
            // Transfer USDC yield to hedger
            usdc.safeTransfer(hedger, yieldAmount);
            
            emit HedgerYieldClaimed(hedger, yieldAmount, block.timestamp);
        }
    }

    // =============================================================================
    // YIELD CALCULATION FUNCTIONS
    // =============================================================================

    /**
     * @notice Calculate optimal yield shift based on pool ratio
     */
    function _calculateOptimalYieldShift(uint256 poolRatio) internal view returns (uint256) {
        // If pools are balanced (ratio near target), use base shift
        if (_isWithinTolerance(poolRatio, targetPoolRatio, 1000)) { // 10% tolerance
            return baseYieldShift;
        }
        
        // If user pool is too large (ratio > target), shift more yield to hedgers
        if (poolRatio > targetPoolRatio) {
            uint256 excess = poolRatio - targetPoolRatio;
            uint256 adjustment = excess.mulDiv(maxYieldShift - baseYieldShift, targetPoolRatio);
            return VaultMath.min(baseYieldShift - adjustment, maxYieldShift);
        }
        
        // If hedger pool is too large (ratio < target), shift more yield to users
        else {
            uint256 deficit = targetPoolRatio - poolRatio;
            uint256 adjustment = deficit.mulDiv(maxYieldShift - baseYieldShift, targetPoolRatio);
            return VaultMath.min(baseYieldShift + adjustment, maxYieldShift);
        }
    }

    /**
     * @notice Apply gradual adjustment to avoid sudden shifts
     */
    function _applyGradualAdjustment(uint256 targetShift) internal view returns (uint256) {
        if (targetShift == currentYieldShift) {
            return currentYieldShift;
        }
        
        uint256 maxAdjustment = adjustmentSpeed; // Basis points per update
        
        if (targetShift > currentYieldShift) {
            uint256 increase = VaultMath.min(targetShift - currentYieldShift, maxAdjustment);
            return currentYieldShift + increase;
        } else {
            uint256 decrease = VaultMath.min(currentYieldShift - targetShift, maxAdjustment);
            return currentYieldShift - decrease;
        }
    }

    /**
     * @notice Get current pool metrics for yield shift calculation
     */
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
     * @notice Check if value is within tolerance of target
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
     * @notice Update last deposit time for a user
     * @param user User address
     */
    function updateLastDepositTime(address user) external {
        require(
            msg.sender == address(userPool) || msg.sender == address(hedgerPool),
            "YieldShift: Unauthorized"
        );
        lastDepositTime[user] = block.timestamp;
    }

    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================

    function getCurrentYieldShift() external view returns (uint256) {
        return currentYieldShift;
    }

    function getUserPendingYield(address user) external view returns (uint256) {
        return userPendingYield[user];
    }

    function getHedgerPendingYield(address hedger) external view returns (uint256) {
        return hedgerPendingYield[hedger];
    }

    function getTotalYieldGenerated() external view returns (uint256) {
        return totalYieldGenerated;
    }

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

    function getPoolMetrics() external view returns (
        uint256 userPoolSize,
        uint256 hedgerPoolSize,
        uint256 poolRatio,
        uint256 targetRatio
    ) {
        (userPoolSize, hedgerPoolSize, poolRatio) = _getCurrentPoolMetrics();
        targetRatio = targetPoolRatio;
    }

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

    function getYieldSources() external view returns (
        uint256 aaveYield,
        uint256 protocolFees,
        uint256 interestDifferential,
        uint256 otherSources
    ) {
        aaveYield = yieldSources["aave"];
        protocolFees = yieldSources["fees"];
        interestDifferential = yieldSources["interest_differential"];
        
        // Calculate other sources
        uint256 knownSources = aaveYield + protocolFees + interestDifferential;
        otherSources = totalYieldGenerated > knownSources ? 
            totalYieldGenerated - knownSources : 0;
    }

    function getHistoricalYieldShift(uint256 period) external view returns (
        uint256 averageShift,
        uint256 maxShift,
        uint256 minShift,
        uint256 volatility
    ) {
        if (yieldShiftHistory.length == 0) {
            return (currentYieldShift, currentYieldShift, currentYieldShift, 0);
        }
        
        uint256 cutoffTime = block.timestamp - period;
        uint256 validSnapshots = 0;
        uint256 sumShifts = 0;
        uint256 sumSquaredDeviations = 0;
        
        maxShift = 0;
        minShift = type(uint256).max;
        
        // Calculate statistics for snapshots within the period
        for (uint256 i = 0; i < yieldShiftHistory.length; i++) {
            if (yieldShiftHistory[i].timestamp >= cutoffTime) {
                uint256 shift = yieldShiftHistory[i].yieldShift;
                sumShifts += shift;
                validSnapshots++;
                
                if (shift > maxShift) maxShift = shift;
                if (shift < minShift) minShift = shift;
            }
        }
        
        if (validSnapshots == 0) {
            return (currentYieldShift, currentYieldShift, currentYieldShift, 0);
        }
        
        averageShift = sumShifts / validSnapshots;
        
        // Calculate volatility (standard deviation)
        for (uint256 i = 0; i < yieldShiftHistory.length; i++) {
            if (yieldShiftHistory[i].timestamp >= cutoffTime) {
                uint256 shift = yieldShiftHistory[i].yieldShift;
                uint256 deviation = shift > averageShift ? 
                    shift - averageShift : averageShift - shift;
                sumSquaredDeviations += deviation * deviation;
            }
        }
        
        volatility = validSnapshots > 1 ? 
            VaultMath.scaleDecimals(sumSquaredDeviations / (validSnapshots - 1), 0, 9) : 0;
    }

    function getYieldPerformanceMetrics() external view returns (
        uint256 totalYieldDistributed_,
        uint256 averageUserYield,
        uint256 averageHedgerYield,
        uint256 yieldEfficiency
    ) {
        totalYieldDistributed_ = totalYieldDistributed;
        
        // Get pool statistics for averages
        (uint256 totalUsers, , , ) = userPool.getPoolMetrics();
        (uint256 activeHedgers, , , , ) = hedgerPool.getPoolStatistics();
        
        averageUserYield = totalUsers > 0 ? 
            userYieldPool / totalUsers : 0;
        averageHedgerYield = activeHedgers > 0 ? 
            hedgerYieldPool / activeHedgers : 0;
        
        // Yield efficiency: percentage of generated yield that's been distributed
        yieldEfficiency = totalYieldGenerated > 0 ? 
            totalYieldDistributed_.mulDiv(10000, totalYieldGenerated) : 0;
    }

    function _calculateUserAllocation() internal view returns (uint256) {
        uint256 totalAvailable = userYieldPool + hedgerYieldPool;
        return totalAvailable.mulDiv(currentYieldShift, 10000);
    }

    function _calculateHedgerAllocation() internal view returns (uint256) {
        uint256 totalAvailable = userYieldPool + hedgerYieldPool;
        return totalAvailable.mulDiv(10000 - currentYieldShift, 10000);
    }

    // =============================================================================
    // GOVERNANCE FUNCTIONS
    // =============================================================================

    function setYieldShiftParameters(
        uint256 _baseYieldShift,
        uint256 _maxYieldShift,
        uint256 _adjustmentSpeed
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(_baseYieldShift <= 10000, "YieldShift: Base shift too high");
        require(_maxYieldShift <= 10000, "YieldShift: Max shift too high");
        require(_maxYieldShift >= _baseYieldShift, "YieldShift: Invalid shift range");
        require(_adjustmentSpeed <= 1000, "YieldShift: Adjustment speed too high"); // Max 10% per update

        baseYieldShift = _baseYieldShift;
        maxYieldShift = _maxYieldShift;
        adjustmentSpeed = _adjustmentSpeed;

        emit YieldShiftParametersUpdated(_baseYieldShift, _maxYieldShift, _adjustmentSpeed);
    }

    function setTargetPoolRatio(uint256 _targetPoolRatio) 
        external 
        onlyRole(GOVERNANCE_ROLE) 
    {
        require(_targetPoolRatio > 0, "YieldShift: Target ratio must be positive");
        require(_targetPoolRatio <= 50000, "YieldShift: Target ratio too high"); // Max 5:1
        
        targetPoolRatio = _targetPoolRatio;
    }

    function updateYieldAllocation(address user, uint256 amount, bool isUser) 
        external 
        onlyRole(YIELD_MANAGER_ROLE) 
    {
        if (isUser) {
            userPendingYield[user] += amount;
        } else {
            hedgerPendingYield[user] += amount;
        }
    }

    // =============================================================================
    // EMERGENCY FUNCTIONS
    // =============================================================================

    function emergencyYieldDistribution(uint256 userAmount, uint256 hedgerAmount) 
        external 
        onlyRole(EMERGENCY_ROLE) 
    {
        require(userAmount <= userYieldPool, "YieldShift: Insufficient user yield");
        require(hedgerAmount <= hedgerYieldPool, "YieldShift: Insufficient hedger yield");
        
        if (userAmount > 0) {
            userYieldPool -= userAmount;
            usdc.safeTransfer(address(userPool), userAmount);
        }
        
        if (hedgerAmount > 0) {
            hedgerYieldPool -= hedgerAmount;
            usdc.safeTransfer(address(hedgerPool), hedgerAmount);
        }
    }

    function pauseYieldDistribution() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    function resumeYieldDistribution() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }

    function getYieldShiftConfig() external view returns (
        uint256 baseShift,
        uint256 maxShift,
        uint256 adjustmentSpeed_,
        uint256 lastUpdate
    ) {
        return (baseYieldShift, maxYieldShift, adjustmentSpeed, lastUpdateTime);
    }

    function isYieldDistributionActive() external view returns (bool) {
        return !paused();
    }

    // =============================================================================
    // AUTOMATED FUNCTIONS
    // =============================================================================

    /**
     * @notice Harvest yield from Aave and distribute automatically
     */
    function harvestAndDistributeAaveYield() external nonReentrant {
        uint256 yieldHarvested = aaveVault.harvestAaveYield();
        
        if (yieldHarvested > 0) {
            // Transfer harvested yield to this contract
            usdc.safeTransferFrom(address(aaveVault), address(this), yieldHarvested);
            
            // Add to yield pool
            this.addYield(yieldHarvested, "aave");
            
            // Update yield distribution
            this.updateYieldDistribution();
        }
    }

    /**
     * @notice Update yield distribution if conditions are met
     * @dev Uses TWAP and includes holding period checks
     */
    function checkAndUpdateYieldDistribution() external {
        // Only update if significant time has passed or pool imbalance is high
        bool timeCondition = block.timestamp >= lastUpdateTime + TWAP_PERIOD;
        
        // Use TWAP for pool ratio calculation
        uint256 avgUserPoolSize = getTimeWeightedAverage(userPoolHistory, TWAP_PERIOD, true);
        uint256 avgHedgerPoolSize = getTimeWeightedAverage(hedgerPoolHistory, TWAP_PERIOD, false);
        uint256 poolRatio = avgHedgerPoolSize == 0 ? type(uint256).max : 
                           avgUserPoolSize.mulDiv(10000, avgHedgerPoolSize);
        
        bool imbalanceCondition = !_isWithinTolerance(poolRatio, targetPoolRatio, 2000); // 20% tolerance
        
        if (timeCondition || imbalanceCondition) {
            this.updateYieldDistribution();
        }
    }

    /**
     * @notice Force update yield distribution (governance only)
     * @dev Emergency function to update yield distribution when normal conditions aren't met
     */
    function forceUpdateYieldDistribution() external onlyRole(GOVERNANCE_ROLE) {
        this.updateYieldDistribution();
    }

    function _authorizeUpgrade(address newImplementation) 
        internal 
        override 
        onlyRole(UPGRADER_ROLE) 
    {}

    /**
     * @notice Modifier to check minimum holding period
     */
    modifier checkHoldingPeriod() {
        require(
            block.timestamp >= lastDepositTime[msg.sender] + MIN_HOLDING_PERIOD,
            "YieldShift: Holding period not met"
        );
        _;
    }

    /**
     * @notice Calculate time-weighted average pool size over a specified period
     * @param poolHistory Array of pool snapshots
     * @param period Time period to calculate average over
     * @param isUserPool Whether this is for user pool (true) or hedger pool (false)
     * @return Time-weighted average pool size
     */
    function getTimeWeightedAverage(PoolSnapshot[] storage poolHistory, uint256 period, bool isUserPool) 
        internal 
        view 
        returns (uint256) 
    {
        if (poolHistory.length == 0) {
            return 0;
        }
        
        uint256 cutoffTime = block.timestamp - period;
        uint256 totalWeightedValue = 0;
        uint256 totalWeight = 0;
        
        for (uint256 i = 0; i < poolHistory.length; i++) {
            PoolSnapshot memory snapshot = poolHistory[i];
            
            if (snapshot.timestamp >= cutoffTime) {
                uint256 weight = snapshot.timestamp - cutoffTime;
                uint256 poolSize = isUserPool ? snapshot.userPoolSize : snapshot.hedgerPoolSize;
                totalWeightedValue += poolSize * weight;
                totalWeight += weight;
            }
        }
        
        if (totalWeight == 0) {
            uint256 lastPoolSize = isUserPool ? 
                poolHistory[poolHistory.length - 1].userPoolSize : 
                poolHistory[poolHistory.length - 1].hedgerPoolSize;
            return lastPoolSize;
        }
        
        return totalWeightedValue / totalWeight;
    }

    /**
     * @notice Record current pool sizes in history for TWAP calculations
     */
    function _recordPoolSnapshot() internal {
        (uint256 userPoolSize, uint256 hedgerPoolSize,) = _getCurrentPoolMetrics();
        
        // Add to user pool history
        _addToPoolHistory(userPoolHistory, userPoolSize, true);
        
        // Add to hedger pool history
        _addToPoolHistory(hedgerPoolHistory, hedgerPoolSize, false);
    }

    /**
     * @notice Add snapshot to pool history array
     * @param poolHistory Array to add snapshot to
     * @param poolSize Current pool size
     * @param isUserPool Whether this is for user pool (true) or hedger pool (false)
     */
    function _addToPoolHistory(PoolSnapshot[] storage poolHistory, uint256 poolSize, bool isUserPool) internal {
        // Remove oldest snapshot if at capacity
        if (poolHistory.length >= MAX_HISTORY_LENGTH) {
            // Shift array left to remove first element
            for (uint256 i = 0; i < poolHistory.length - 1; i++) {
                poolHistory[i] = poolHistory[i + 1];
            }
            poolHistory.pop();
        }
        
        poolHistory.push(PoolSnapshot({
            timestamp: block.timestamp,
            userPoolSize: isUserPool ? poolSize : 0,
            hedgerPoolSize: isUserPool ? 0 : poolSize
        }));
    }
}