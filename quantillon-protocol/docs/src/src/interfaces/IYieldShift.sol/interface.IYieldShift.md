# IYieldShift
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/46b18a17495388ad54b171836fd31a58ac76ca7b/src/interfaces/IYieldShift.sol)

**Author:**
Quantillon Labs

Interface for YieldShift dynamic yield redistribution

**Note:**
security-contact: team@quantillon.money


## Functions
### initialize

Initializes the YieldShift contract


```solidity
function initialize(
    address admin,
    address _usdc,
    address _userPool,
    address _hedgerPool,
    address _aaveVault,
    address _stQEURO
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Admin address|
|`_usdc`|`address`|USDC token address|
|`_userPool`|`address`|UserPool address|
|`_hedgerPool`|`address`|HedgerPool address|
|`_aaveVault`|`address`|Aave vault address|
|`_stQEURO`|`address`|stQEURO token address|


### updateYieldDistribution

Update yield distribution according to pool balances


```solidity
function updateYieldDistribution() external;
```

### addYield

Add new yield to be distributed


```solidity
function addYield(uint256 yieldAmount, bytes32 source) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`yieldAmount`|`uint256`|Yield amount in USDC equivalent|
|`source`|`bytes32`|Source identifier (e.g., "aave", "fees")|


### claimUserYield

Claim pending yield for a user


```solidity
function claimUserYield(address user) external returns (uint256 yieldAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`yieldAmount`|`uint256`|Yield amount claimed|


### claimHedgerYield

Claim pending yield for a hedger


```solidity
function claimHedgerYield(address hedger) external returns (uint256 yieldAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`yieldAmount`|`uint256`|Yield amount claimed|


### getCurrentYieldShift

Current yield shift percentage (bps)


```solidity
function getCurrentYieldShift() external view returns (uint256);
```

### getUserPendingYield

Pending yield amounts


```solidity
function getUserPendingYield(address user) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user|


### getHedgerPendingYield

Pending yield amounts


```solidity
function getHedgerPendingYield(address hedger) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger|


### getTotalYieldGenerated

Total yield generated to date


```solidity
function getTotalYieldGenerated() external view returns (uint256);
```

### getYieldDistributionBreakdown

Yield distribution breakdown


```solidity
function getYieldDistributionBreakdown() external view returns (uint256 userAllocation, uint256 hedgerAllocation);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`userAllocation`|`uint256`|Current allocation to users|
|`hedgerAllocation`|`uint256`|Current allocation to hedgers|


### getPoolMetrics

Current pool metrics


```solidity
function getPoolMetrics() external view returns (uint256 userPoolSize, uint256 hedgerPoolSize, uint256 poolRatio);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`userPoolSize`|`uint256`|User pool size|
|`hedgerPoolSize`|`uint256`|Hedger pool size|
|`poolRatio`|`uint256`|Ratio (bps) user/hedger|


### calculateOptimalYieldShift

Calculate optimal yield shift based on current metrics


```solidity
function calculateOptimalYieldShift() external view returns (uint256 optimalShift, uint256 currentDeviation);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`optimalShift`|`uint256`|Optimal shift (bps)|
|`currentDeviation`|`uint256`|Current deviation from optimal|


### getYieldSources

Yield source amounts


```solidity
function getYieldSources()
    external
    view
    returns (uint256 aaveYield, uint256 protocolFees, uint256 interestDifferential, uint256 otherSources);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`aaveYield`|`uint256`|Aave yield amount|
|`protocolFees`|`uint256`|Protocol fees amount|
|`interestDifferential`|`uint256`|Interest differential amount|
|`otherSources`|`uint256`|Other sources amount|


### getHistoricalYieldShift

Historical yield shift statistics for a period


```solidity
function getHistoricalYieldShift(uint256 period)
    external
    view
    returns (uint256 averageShift, uint256 maxShift, uint256 minShift, uint256 volatility);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`period`|`uint256`|Time period in seconds|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`averageShift`|`uint256`|Average shift over period|
|`maxShift`|`uint256`|Maximum shift over period|
|`minShift`|`uint256`|Minimum shift over period|
|`volatility`|`uint256`|Volatility measure|


### getYieldPerformanceMetrics

Yield performance metrics


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
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalYieldDistributed_`|`uint256`|Total distributed|
|`averageUserYield`|`uint256`|Average user yield|
|`averageHedgerYield`|`uint256`|Average hedger yield|
|`yieldEfficiency`|`uint256`|Yield efficiency percentage|


### setYieldShiftParameters

Update yield shift parameters


```solidity
function setYieldShiftParameters(uint256 _baseYieldShift, uint256 _maxYieldShift, uint256 _adjustmentSpeed) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_baseYieldShift`|`uint256`|Base allocation (bps)|
|`_maxYieldShift`|`uint256`|Max allocation (bps)|
|`_adjustmentSpeed`|`uint256`|Adjustment speed (bps)|


### setTargetPoolRatio

Set the target pool ratio (bps)


```solidity
function setTargetPoolRatio(uint256 _targetPoolRatio) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_targetPoolRatio`|`uint256`|Target ratio|


### authorizeYieldSource

Authorize a yield source for specific yield type


```solidity
function authorizeYieldSource(address source, bytes32 yieldType) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`source`|`address`|Address of the yield source|
|`yieldType`|`bytes32`|Type of yield this source is authorized for|


### revokeYieldSource

Revoke authorization for a yield source


```solidity
function revokeYieldSource(address source) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`source`|`address`|Address of the yield source to revoke|


### isYieldSourceAuthorized

Check if an address is authorized for a specific yield type


```solidity
function isYieldSourceAuthorized(address source, bytes32 yieldType) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`source`|`address`|Address to check|
|`yieldType`|`bytes32`|Yield type to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if authorized|


### updateYieldAllocation

Update yield allocation for a participant


```solidity
function updateYieldAllocation(address user, uint256 amount, bool isUser) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of participant|
|`amount`|`uint256`|Amount to add/subtract|
|`isUser`|`bool`|True if user pool, false if hedger pool|


### emergencyYieldDistribution

Emergency manual yield distribution


```solidity
function emergencyYieldDistribution(uint256 userAmount, uint256 hedgerAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`userAmount`|`uint256`|Amount to users|
|`hedgerAmount`|`uint256`|Amount to hedgers|


### pauseYieldDistribution

Pause yield distribution operations


```solidity
function pauseYieldDistribution() external;
```

### resumeYieldDistribution

Resume yield distribution operations


```solidity
function resumeYieldDistribution() external;
```

### getYieldShiftConfig

YieldShift configuration snapshot


```solidity
function getYieldShiftConfig()
    external
    view
    returns (uint256 baseShift, uint256 maxShift, uint256 adjustmentSpeed_, uint256 lastUpdate);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`baseShift`|`uint256`|Base shift (bps)|
|`maxShift`|`uint256`|Max shift (bps)|
|`adjustmentSpeed_`|`uint256`|Adjustment speed (bps)|
|`lastUpdate`|`uint256`|Last update timestamp|


### isYieldDistributionActive

Whether yield distribution is active (not paused)


```solidity
function isYieldDistributionActive() external view returns (bool);
```

### checkAndUpdateYieldDistribution

Check if an update to yield distribution is needed and apply if so


```solidity
function checkAndUpdateYieldDistribution() external;
```

### updateLastDepositTime

Update the last deposit time for a user (for TWAP calculations)

*This function is called by the user pool when users deposit*

*Used for time-weighted average calculations*


```solidity
function updateLastDepositTime(address user) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user|


### forceUpdateYieldDistribution

Force update yield distribution (governance only)

*This function allows governance to force an update to yield distribution*

*Only callable by governance role*


```solidity
function forceUpdateYieldDistribution() external;
```

### hasRole


```solidity
function hasRole(bytes32 role, address account) external view returns (bool);
```

### getRoleAdmin


```solidity
function getRoleAdmin(bytes32 role) external view returns (bytes32);
```

### grantRole


```solidity
function grantRole(bytes32 role, address account) external;
```

### revokeRole


```solidity
function revokeRole(bytes32 role, address account) external;
```

### renounceRole


```solidity
function renounceRole(bytes32 role, address callerConfirmation) external;
```

### paused


```solidity
function paused() external view returns (bool);
```

### upgradeTo


```solidity
function upgradeTo(address newImplementation) external;
```

### upgradeToAndCall


```solidity
function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
```

### recoverToken


```solidity
function recoverToken(address token, address to, uint256 amount) external;
```

### recoverETH


```solidity
function recoverETH() external;
```

