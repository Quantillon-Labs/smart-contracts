# IYieldShift
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/91f7ed3e8a496e9d369dc182e8f549ec75449a6b/src/interfaces/IYieldShift.sol)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Interface for YieldShift dynamic yield redistribution

**Note:**
security-contact: team@quantillon.money


## Functions
### initialize

Initializes the YieldShift contract

*Sets up the yield shift contract with initial configuration and assigns roles to admin*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

*Recalculates and updates yield distribution based on current pool balances*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function updateYieldDistribution() external;
```

### addYield

Add new yield to be distributed

*Adds new yield from various sources to the distribution pool*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

*Claims all pending yield for a specific user from the user pool*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

*Claims all pending yield for a specific hedger from the hedger pool*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

*Returns the current yield shift percentage in basis points*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function getCurrentYieldShift() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Current yield shift percentage in basis points|


### getUserPendingYield

Pending yield amounts

*Returns the amount of pending yield for a specific user*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function getUserPendingYield(address user) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Pending yield amount for the user|


### getHedgerPendingYield

Pending yield amounts

*Returns the amount of pending yield for a specific hedger*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function getHedgerPendingYield(address hedger) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Pending yield amount for the hedger|


### getTotalYieldGenerated

Total yield generated to date

*Returns the total amount of yield generated since inception*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function getTotalYieldGenerated() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total yield generated amount|


### getYieldDistributionBreakdown

Yield distribution breakdown

*Returns the current yield allocation breakdown between users and hedgers*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

*Returns current pool size metrics and ratios*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

*Calculates the optimal yield shift based on current pool metrics*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

*Returns yield amounts from different sources*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

*Returns historical yield shift statistics for a specified time period*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

*Returns comprehensive yield performance metrics*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

*Allows governance to update yield shift configuration parameters*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

*Sets the target ratio between user and hedger pools*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function setTargetPoolRatio(uint256 _targetPoolRatio) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_targetPoolRatio`|`uint256`|Target ratio|


### authorizeYieldSource

Authorize a yield source for specific yield type

*Authorizes a yield source for a specific type of yield*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

*Revokes authorization for a yield source*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function revokeYieldSource(address source) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`source`|`address`|Address of the yield source to revoke|


### isYieldSourceAuthorized

Check if an address is authorized for a specific yield type

*Checks if an address is authorized for a specific yield type*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

*Updates yield allocation for a specific participant*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

*Performs emergency manual yield distribution bypassing normal logic*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

*Emergency function to pause all yield distribution operations*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function pauseYieldDistribution() external;
```

### resumeYieldDistribution

Resume yield distribution operations

*Resumes yield distribution operations after emergency pause*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function resumeYieldDistribution() external;
```

### getYieldShiftConfig

YieldShift configuration snapshot

*Returns current yield shift configuration parameters*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

*Returns true if yield distribution is not paused and operations are active*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function isYieldDistributionActive() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if yield distribution is active|


### checkAndUpdateYieldDistribution

Check if an update to yield distribution is needed and apply if so

*Checks if yield distribution needs updating and applies changes if necessary*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function checkAndUpdateYieldDistribution() external;
```

### updateLastDepositTime

Update the last deposit time for a user (for TWAP calculations)

*Updates the last deposit time for a user, called by user pool on deposits*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function forceUpdateYieldDistribution() external;
```

### hasRole

Checks if an account has a specific role

*Returns true if the account has been granted the role*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function hasRole(bytes32 role, address account) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to check|
|`account`|`address`|The account to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the account has the role|


### getRoleAdmin

Gets the admin role for a given role

*Returns the role that is the admin of the given role*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function getRoleAdmin(bytes32 role) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to get admin for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The admin role|


### grantRole

Grants a role to an account

*Can only be called by an account with the admin role*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function grantRole(bytes32 role, address account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to grant|
|`account`|`address`|The account to grant the role to|


### revokeRole

Revokes a role from an account

*Can only be called by an account with the admin role*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function revokeRole(bytes32 role, address account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to revoke|
|`account`|`address`|The account to revoke the role from|


### renounceRole

Renounces a role from the caller

*The caller gives up their own role*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function renounceRole(bytes32 role, address callerConfirmation) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to renounce|
|`callerConfirmation`|`address`|Confirmation that the caller is renouncing their own role|


### paused

Checks if the contract is paused

*Returns true if the contract is currently paused*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function paused() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if paused, false otherwise|


### upgradeTo

Upgrades the contract to a new implementation

*Can only be called by accounts with UPGRADER_ROLE*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function upgradeTo(address newImplementation) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation contract|


### upgradeToAndCall

Upgrades the contract to a new implementation and calls a function

*Can only be called by accounts with UPGRADER_ROLE*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation contract|
|`data`|`bytes`|Encoded function call data|


### recoverToken

Recovers ERC20 tokens sent by mistake

*Allows governance to recover accidentally sent ERC20 tokens*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function recoverToken(address token, address to, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address|
|`to`|`address`|Recipient address|
|`amount`|`uint256`|Amount to transfer|


### recoverETH

Recovers ETH sent by mistake

*Allows governance to recover accidentally sent ETH*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function recoverETH() external;
```

