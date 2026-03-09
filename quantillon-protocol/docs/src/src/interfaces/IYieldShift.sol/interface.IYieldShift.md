# IYieldShift

## Functions
### initialize


```solidity
function initialize(
    address admin,
    address _usdc,
    address _userPool,
    address _hedgerPool,
    address _aaveVault,
    address _stQEURO,
    address _timelock,
    address _treasury
) external;
```

### bootstrapDefaults


```solidity
function bootstrapDefaults() external;
```

### updateYieldDistribution


```solidity
function updateYieldDistribution() external;
```

### addYield


```solidity
function addYield(uint256 yieldAmount, bytes32 source) external;
```

### claimUserYield


```solidity
function claimUserYield(address user) external returns (uint256 yieldAmount);
```

### claimHedgerYield


```solidity
function claimHedgerYield(address hedger) external returns (uint256 yieldAmount);
```

### updateLastDepositTime


```solidity
function updateLastDepositTime(address user) external;
```

### updateYieldAllocation


```solidity
function updateYieldAllocation(address user, uint256 amount, bool isUser) external;
```

### configureYieldModel


```solidity
function configureYieldModel(YieldModelConfig calldata cfg) external;
```

### configureDependencies


```solidity
function configureDependencies(YieldDependencyConfig calldata cfg) external;
```

### setYieldSourceAuthorization


```solidity
function setYieldSourceAuthorization(address source, bytes32 yieldType, bool authorized) external;
```

### emergencyYieldDistribution


```solidity
function emergencyYieldDistribution(uint256 userAmount, uint256 hedgerAmount) external;
```

### pauseYieldDistribution


```solidity
function pauseYieldDistribution() external;
```

### resumeYieldDistribution


```solidity
function resumeYieldDistribution() external;
```

### isYieldSourceAuthorized


```solidity
function isYieldSourceAuthorized(address source, bytes32 yieldType) external view returns (bool);
```

### checkAndUpdateYieldDistribution


```solidity
function checkAndUpdateYieldDistribution() external;
```

### forceUpdateYieldDistribution


```solidity
function forceUpdateYieldDistribution() external;
```

### getYieldDistributionBreakdown


```solidity
function getYieldDistributionBreakdown()
    external
    view
    returns (uint256 userYieldPool_, uint256 hedgerYieldPool_, uint256 distributionRatio);
```

### getPoolMetrics


```solidity
function getPoolMetrics()
    external
    view
    returns (uint256 userPoolSize, uint256 hedgerPoolSize, uint256 poolRatio, uint256 targetRatio);
```

### calculateOptimalYieldShift


```solidity
function calculateOptimalYieldShift() external view returns (uint256 optimalShift, uint256 currentDeviation);
```

### getYieldSources


```solidity
function getYieldSources()
    external
    view
    returns (uint256 aaveYield, uint256 protocolFees, uint256 interestDifferential, uint256 otherSources);
```

### getHistoricalYieldShift


```solidity
function getHistoricalYieldShift(uint256 period)
    external
    view
    returns (uint256 averageShift, uint256 maxShift, uint256 minShift, uint256 volatility);
```

### getYieldPerformanceMetrics


```solidity
function getYieldPerformanceMetrics()
    external
    view
    returns (
        uint256 totalYieldDistributed_,
        uint256 averageUserYield,
        uint256 averageHedgerYield,
        uint256 yieldEfficiency
    );
```

### currentYieldShift


```solidity
function currentYieldShift() external view returns (uint256);
```

### totalYieldGenerated


```solidity
function totalYieldGenerated() external view returns (uint256);
```

### totalYieldDistributed


```solidity
function totalYieldDistributed() external view returns (uint256);
```

### userYieldPool


```solidity
function userYieldPool() external view returns (uint256);
```

### hedgerYieldPool


```solidity
function hedgerYieldPool() external view returns (uint256);
```

### userPendingYield


```solidity
function userPendingYield(address user) external view returns (uint256);
```

### hedgerPendingYield


```solidity
function hedgerPendingYield(address hedger) external view returns (uint256);
```

### userLastClaim


```solidity
function userLastClaim(address user) external view returns (uint256);
```

### hedgerLastClaim


```solidity
function hedgerLastClaim(address hedger) external view returns (uint256);
```

### baseYieldShift


```solidity
function baseYieldShift() external view returns (uint256);
```

### maxYieldShift


```solidity
function maxYieldShift() external view returns (uint256);
```

### adjustmentSpeed


```solidity
function adjustmentSpeed() external view returns (uint256);
```

### targetPoolRatio


```solidity
function targetPoolRatio() external view returns (uint256);
```

### lastUpdateTime


```solidity
function lastUpdateTime() external view returns (uint256);
```

### paused


```solidity
function paused() external view returns (bool);
```

## Structs
### YieldModelConfig

```solidity
struct YieldModelConfig {
    uint256 baseYieldShift;
    uint256 maxYieldShift;
    uint256 adjustmentSpeed;
    uint256 targetPoolRatio;
}
```

### YieldDependencyConfig

```solidity
struct YieldDependencyConfig {
    address userPool;
    address hedgerPool;
    address aaveVault;
    address stQEURO;
    address treasury;
}
```

