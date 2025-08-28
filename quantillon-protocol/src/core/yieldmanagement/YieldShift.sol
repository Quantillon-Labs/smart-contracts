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
import "../SecureUpgradeable.sol";

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
    
    mapping(string => uint256) public yieldSources;
    string[] public yieldSourceNames;
    
    mapping(address => uint256) public userPendingYield;
    mapping(address => uint256) public hedgerPendingYield;
    mapping(address => uint256) public userLastClaim;
    mapping(address => uint256) public hedgerLastClaim;
    
    mapping(address => uint256) public lastDepositTime;
    
    struct PoolSnapshot {
        uint256 timestamp;
        uint256 userPoolSize;
        uint256 hedgerPoolSize;
    }
    
    PoolSnapshot[] public userPoolHistory;
    PoolSnapshot[] public hedgerPoolHistory;
    uint256 public constant MAX_HISTORY_LENGTH = 1000;

    struct YieldShiftSnapshot {
        uint256 timestamp;
        uint256 yieldShift;
    }
    YieldShiftSnapshot[] public yieldShiftHistory;

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

        yieldSourceNames.push("aave");
        yieldSourceNames.push("fees");
        yieldSourceNames.push("interest_differential");
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

    function addYield(uint256 yieldAmount, string calldata source) 
        external 
        nonReentrant 
    {
        AccessControlLibrary.onlyYieldManager(this);
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
        
        emit YieldAdded(yieldAmount, source, block.timestamp);
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
        aaveYield = yieldSources["aave"];
        protocolFees = yieldSources["fees"];
        interestDifferential = yieldSources["interest_differential"];
        
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
        
        uint256 cutoffTime = block.timestamp - period;
        
        if (cutoffTime > block.timestamp) {
            cutoffTime = 0;
        }
        
        uint256[] memory validShifts = new uint256[](length);
        uint256 validCount = 0;
        
        for (uint256 i = 0; i < length; i++) {
            YieldShiftSnapshot memory snapshot = yieldShiftHistory[i];
            if (snapshot.timestamp >= cutoffTime) {
                validShifts[validCount] = snapshot.yieldShift;
                validCount++;
            }
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

        emit YieldShiftParametersUpdated(_baseYieldShift, _maxYieldShift, _adjustmentSpeed);
    }

    function setTargetPoolRatio(uint256 _targetPoolRatio) external {
        AccessControlLibrary.onlyGovernance(this);
        ValidationLibrary.validateTargetRatio(_targetPoolRatio, 50000);
        
        targetPoolRatio = _targetPoolRatio;
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

    function harvestAndDistributeAaveYield() external nonReentrant {
        uint256 yieldHarvested = aaveVault.harvestAaveYield();
        
        if (yieldHarvested > 0) {
            usdc.safeTransferFrom(address(aaveVault), address(this), yieldHarvested);
            this.addYield(yieldHarvested, "aave");
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
        
        uint256 cutoffTime = block.timestamp - period;
        
        if (cutoffTime > block.timestamp) {
            cutoffTime = 0;
        }
        
        uint256 totalWeightedValue = 0;
        uint256 totalWeight = 0;
        
        for (uint256 i = 0; i < length; i++) {
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
                poolHistory[length - 1].userPoolSize : 
                poolHistory[length - 1].hedgerPoolSize;
            return lastPoolSize;
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
            for (uint256 i = 0; i < length - 1; i++) {
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