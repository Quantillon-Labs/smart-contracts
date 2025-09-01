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
import "../../libraries/VaultLibrary.sol";
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
 * 
 * @dev Security features:
 *      - Role-based access control for all critical operations
 *      - Reentrancy protection for all external calls
 *      - Emergency pause mechanism for crisis situations
 *      - Upgradeable architecture for future improvements
 *      - Authorized yield source validation
 *      - Secure yield distribution mechanisms
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
    using VaultLibrary for address;

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant YIELD_MANAGER_ROLE = keccak256("YIELD_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    IERC20 public usdc;
    IUserPool public userPool;
    IHedgerPool public hedgerPool;
    IAaveVault public aaveVault;
    IstQEURO public stQEURO;

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
        uint128 userPoolSize;               // User pool size (16 bytes, max ~340B)
        uint128 hedgerPoolSize;             // Hedger pool size (16 bytes, max ~340B)
        uint64 timestamp;                   // Timestamp (8 bytes, until year 2554)
        // Total: 16+16+8 = 40 bytes (2 slots vs 3 slots = 33% gas savings)
    }
    
    PoolSnapshot[] public userPoolHistory;
    PoolSnapshot[] public hedgerPoolHistory;
    uint256 public constant MAX_HISTORY_LENGTH = 1000;

    /// @dev OPTIMIZED: Packed struct for gas efficiency in yield shift tracking
    struct YieldShiftSnapshot {
        uint128 yieldShift;                 // Yield shift percentage (16 bytes, max ~340B)
        uint64 timestamp;                   // Timestamp (8 bytes, until year 2554)
        // Total: 16+8 = 24 bytes (1 slot vs 2 slots = 50% gas savings)
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
    
    event YieldSourceAuthorized(address indexed source, bytes32 indexed yieldType);
    event YieldSourceRevoked(address indexed source);

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin,
        address _usdc,
        address _userPool,
        address _hedgerPool,
        address _aaveVault,
        address _stQEURO,
        address timelock
    ) public initializer {
        AccessControlLibrary.validateAddress(admin);
        AccessControlLibrary.validateAddress(_usdc);
        AccessControlLibrary.validateAddress(_userPool);
        AccessControlLibrary.validateAddress(_hedgerPool);
        AccessControlLibrary.validateAddress(_aaveVault);
        AccessControlLibrary.validateAddress(_stQEURO);

        __ReentrancyGuard_init();
        __AccessControl_init();
        __Pausable_init();
        __SecureUpgradeable_init(timelock);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(YIELD_MANAGER_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);

        usdc = IERC20(_usdc);
        userPool = IUserPool(_userPool);
        hedgerPool = IHedgerPool(_hedgerPool);
        aaveVault = IAaveVault(_aaveVault);
        stQEURO = IstQEURO(_stQEURO);

        baseYieldShift = 5000;
        maxYieldShift = 9000;
        adjustmentSpeed = 100;
        targetPoolRatio = 10000;
        currentYieldShift = baseYieldShift;
        lastUpdateTime = block.timestamp;

        _recordPoolSnapshot();

        yieldSourceNames.push(keccak256("aave"));
        yieldSourceNames.push(keccak256("fees"));
        yieldSourceNames.push(keccak256("interest_differential"));
        
        // Authorize the contract itself for known yield sources
        authorizedYieldSources[address(this)] = true;
        sourceToYieldType[address(this)] = keccak256("aave");
    }

    function updateYieldDistribution() external nonReentrant whenNotPaused {
        uint256 avgUserPoolSize = getTimeWeightedAverage(userPoolHistory, TWAP_PERIOD, true);
        uint256 avgHedgerPoolSize = getTimeWeightedAverage(hedgerPoolHistory, TWAP_PERIOD, false);
        
        uint256 poolRatio = avgHedgerPoolSize == 0 ? type(uint256).max : 
                           avgUserPoolSize.mulDiv(10000, avgHedgerPoolSize);
        
        uint256 optimalShift = _calculateOptimalYieldShift(poolRatio);
        uint256 newYieldShift = _applyGradualAdjustment(optimalShift);
        
        currentYieldShift = newYieldShift;
        lastUpdateTime = block.timestamp;
        
        _recordPoolSnapshot();
        
        emit YieldDistributionUpdated(
            newYieldShift,
            _calculateUserAllocation(),
            _calculateHedgerAllocation(),
            block.timestamp
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
        require(
            balanceAfter - balanceBefore == yieldAmount,
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
        
        emit YieldAdded(yieldAmount, string(abi.encodePacked(source)), block.timestamp);
    }

    /**
     * @notice Internal function to add yield (bypasses authorization for internal calls)
     * @param yieldAmount Amount of yield to add
     * @param source Source identifier
     */
    function _addYieldInternal(uint256 yieldAmount, bytes32 source) internal {
        ValidationLibrary.validatePositiveAmount(yieldAmount);
        
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
        
        emit YieldAdded(yieldAmount, string(abi.encodePacked(source)), block.timestamp);
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
            if (block.timestamp < lastDepositTime[user] + MIN_HOLDING_PERIOD) {
                revert ErrorLibrary.HoldingPeriodNotMet();
            }
            
            if (userYieldPool < yieldAmount) revert ErrorLibrary.InsufficientYield();
            
            userPendingYield[user] = 0;
            userLastClaim[user] = block.timestamp;
            userYieldPool -= yieldAmount;
            totalYieldDistributed += yieldAmount;
            
            usdc.safeTransfer(user, yieldAmount);
            
            emit UserYieldClaimed(user, yieldAmount, block.timestamp);
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
            hedgerLastClaim[hedger] = block.timestamp;
            hedgerYieldPool -= yieldAmount;
            totalYieldDistributed += yieldAmount;
            
            usdc.safeTransfer(hedger, yieldAmount);
            
            emit HedgerYieldClaimed(hedger, yieldAmount, block.timestamp);
        }
    }

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

    function _isWithinTolerance(uint256 value, uint256 target, uint256 toleranceBps) 
        internal 
        pure 
        returns (bool) 
    {
        if (value == target) return true;
        
        uint256 tolerance = target.mulDiv(toleranceBps, 10000);
        return value >= target - tolerance && value <= target + tolerance;
    }

    function updateLastDepositTime(address user) external {
        if (msg.sender != address(userPool) && msg.sender != address(hedgerPool)) {
            revert ErrorLibrary.NotAuthorized();
        }
        lastDepositTime[user] = block.timestamp;
    }

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
        aaveYield = yieldSources[keccak256("aave")];
        protocolFees = yieldSources[keccak256("fees")];
        interestDifferential = yieldSources[keccak256("interest_differential")];
        
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
        uint256 length = yieldShiftHistory.length;
        if (length == 0) {
            return (currentYieldShift, currentYieldShift, currentYieldShift, 0);
        }
        
        uint256 cutoffTime = block.timestamp > period ? 
            block.timestamp - period : 0;
        
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

    function getYieldPerformanceMetrics() external view returns (
        uint256 totalYieldDistributed_,
        uint256 averageUserYield,
        uint256 averageHedgerYield,
        uint256 yieldEfficiency
    ) {
        totalYieldDistributed_ = totalYieldDistributed;
        
        (uint256 totalUsers, , , ) = userPool.getPoolMetrics();
        uint256 activeHedgers = hedgerPool.activeHedgers();
        
        averageUserYield = totalUsers > 0 ? 
            userYieldPool / totalUsers : 0;
        averageHedgerYield = activeHedgers > 0 ? 
            hedgerYieldPool / activeHedgers : 0;
        
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
     */
    function revokeYieldSource(address source) external {
        AccessControlLibrary.onlyGovernance(this);
        AccessControlLibrary.validateAddress(source);
        
        authorizedYieldSources[source] = false;
        sourceToYieldType[source] = bytes32(0);
        
        emit YieldSourceRevoked(source);
    }

    function updateYieldAllocation(address user, uint256 amount, bool isUser) external {
        AccessControlLibrary.onlyYieldManager(this);
        if (isUser) {
            userPendingYield[user] += amount;
        } else {
            hedgerPendingYield[user] += amount;
        }
    }

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

    function pauseYieldDistribution() external {
        AccessControlLibrary.onlyEmergencyRole(this);
        _pause();
    }

    function resumeYieldDistribution() external {
        AccessControlLibrary.onlyEmergencyRole(this);
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

    /**
     * @notice Check if an address is authorized for a specific yield type
     * @param source Address to check
     * @param yieldType Yield type to check
     * @return True if authorized
     */
    function isYieldSourceAuthorized(address source, bytes32 yieldType) external view returns (bool) {
        return authorizedYieldSources[source] && sourceToYieldType[source] == yieldType;
    }

    function harvestAndDistributeAaveYield() external nonReentrant {
        uint256 yieldHarvested = aaveVault.harvestAaveYield();
        
        if (yieldHarvested > 0) {
            usdc.safeTransferFrom(address(aaveVault), address(this), yieldHarvested);
            // Directly call addYield since this contract is authorized for "aave" yield
            _addYieldInternal(yieldHarvested, keccak256("aave"));
            this.updateYieldDistribution();
        }
    }

    function checkAndUpdateYieldDistribution() external {
        uint256 timeSinceUpdate = block.timestamp - lastUpdateTime;
        
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
        
        uint256 cutoffTime = block.timestamp > period ? 
            block.timestamp - period : 0;
        
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
        (uint256 userPoolSize, uint256 hedgerPoolSize,) = _getCurrentPoolMetrics();
        
        _addToPoolHistory(userPoolHistory, userPoolSize, true);
        _addToPoolHistory(hedgerPoolHistory, hedgerPoolSize, false);
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
            timestamp: uint64(block.timestamp),
            userPoolSize: isUserPool ? uint128(poolSize) : 0,
            hedgerPoolSize: isUserPool ? 0 : uint128(poolSize)
        }));
    }

    function recoverToken(address token, address to, uint256 amount) external {
        AccessControlLibrary.onlyAdmin(this);
        if (token == address(usdc)) revert ErrorLibrary.CannotRecoverUSDC();
        AccessControlLibrary.validateAddress(to);
        
        IERC20(token).safeTransfer(to, amount);
    }

    function recoverETH(address payable to) external {
        AccessControlLibrary.onlyAdmin(this);
        AccessControlLibrary.validateAddress(to);
        uint256 balance = address(this).balance;
        if (balance == 0) revert ErrorLibrary.NoETHToRecover();
        
        (bool success, ) = to.call{value: balance}("");
        if (!success) revert ErrorLibrary.ETHTransferFailed();
    }
}