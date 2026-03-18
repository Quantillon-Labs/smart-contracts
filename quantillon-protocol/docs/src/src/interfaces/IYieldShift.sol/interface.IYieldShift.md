# IYieldShift

## Functions
### initialize

Initializes the YieldShift contract.

Sets up core roles, USDC token and optional initial dependencies.

**Notes:**
- security: Validates non‑zero admin and USDC address, sets up access control.

- validation: Reverts on invalid addresses; optional dependencies may be zero.

- state-changes: Initializes roles, references and scalar defaults.

- events: Emits implementation‑specific initialization events.

- errors: Reverts with protocol‑specific validation errors.

- reentrancy: Protected by initializer modifier in implementation.

- access: External initializer; callable once.

- oracle: No direct oracle dependency.


```solidity
function initialize(
    address admin,
    address _usdc,
    address _userPool,
    address _hedgerPool,
    address _aaveVault,
    address _stQEUROFactory,
    address _timelock,
    address _treasury
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address receiving admin and governance roles.|
|`_usdc`|`address`|USDC token address used for yield accounting.|
|`_userPool`|`address`|UserPool contract address (optional at deploy time).|
|`_hedgerPool`|`address`|HedgerPool contract address (optional at deploy time).|
|`_aaveVault`|`address`|AaveVault contract address (optional at deploy time).|
|`_stQEUROFactory`|`address`|stQEURO factory contract address (optional at deploy time).|
|`_timelock`|`address`|Timelock contract used for SecureUpgradeable.|
|`_treasury`|`address`|Treasury address for recovery flows.|


### bootstrapDefaults

Governance bootstrap to set initial histories and default sources.

Lazily initializes TWAP histories and default yield source metadata after `initialize`.

**Notes:**
- security: Restricted to governance; reads only already‑validated state.

- validation: Reverts if caller lacks governance role.

- state-changes: Records initial snapshots and default yield source mappings.

- events: Emits no external events beyond those in implementation.

- errors: Reverts with access‑control errors on unauthorized callers.

- reentrancy: Not applicable – configuration only.

- access: Governance‑only.

- oracle: No oracle dependency.


```solidity
function bootstrapDefaults() external;
```

### updateYieldDistribution

Updates the yield distribution between user and hedger pools.

Recomputes `currentYieldShift` using eligible pool metrics and updates history.

**Notes:**
- security: Callable by authorized roles; uses holding‑period protection against flash deposits.

- validation: Reverts if dependencies are misconfigured.

- state-changes: Updates `currentYieldShift`, `lastUpdateTime` and pool snapshots.

- events: Emits `YieldDistributionUpdated`.

- errors: Reverts with protocol‑specific config or math errors.

- reentrancy: Protected by nonReentrant modifier in implementation.

- access: Typically callable by anyone or scheduled keeper, per implementation.

- oracle: No direct oracle reads; relies on pool metrics.


```solidity
function updateYieldDistribution() external;
```

### addYield

Adds yield from an authorized source and allocates it between users and hedgers.

Transfers USDC from `msg.sender`, checks authorization and updates yield pools.

**Notes:**
- security: Only authorized yield sources may call; validates source mapping.

- validation: Reverts if transferred amount does not match `yieldAmount` within 1 wei.

- state-changes: Updates `yieldSources`, `totalYieldGenerated`, `userYieldPool`, `hedgerYieldPool`.

- events: Emits `YieldAdded`.

- errors: Reverts with authorization or amount‑mismatch errors.

- reentrancy: Protected by nonReentrant modifier in implementation.

- access: Restricted to whitelisted yield source contracts.

- oracle: No direct oracle dependency.


```solidity
function addYield(uint256 vaultId, uint256 yieldAmount, bytes32 source) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vaultId`|`uint256`|Target vault id receiving user-yield routing.|
|`yieldAmount`|`uint256`|Yield amount in USDC (6 decimals).|
|`source`|`bytes32`|Logical yield source identifier (e.g. `keccak256("aave")`).|


### claimUserYield

Claims accumulated user yield for a specific address.

Enforces holding period via `lastDepositTime` before releasing USDC yield.

**Notes:**
- security: Callable by user or UserPool; checks holding period and pool balances.

- validation: Reverts if holding period not met or pool has insufficient yield.

- state-changes: Updates `userPendingYield`, `userLastClaim`, `userYieldPool`, `totalYieldDistributed`.

- events: Emits `UserYieldClaimed`.

- errors: Reverts with holding‑period or insufficient‑yield errors.

- reentrancy: Protected by nonReentrant modifier in implementation.

- access: Restricted to `user` or UserPool contract.

- oracle: No direct oracle dependency.


```solidity
function claimUserYield(address user) external returns (uint256 yieldAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address whose yield is being claimed.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`yieldAmount`|`uint256`|Amount of USDC yield transferred to `user`.|


### claimHedgerYield

Claims accumulated hedger yield for a specific hedger.

Transfers pending hedger yield from `hedgerYieldPool` to `hedger`.

**Notes:**
- security: Callable by hedger or HedgerPool; enforces authorization.

- validation: Reverts if pool has insufficient yield.

- state-changes: Updates `hedgerPendingYield`, `hedgerLastClaim`, `hedgerYieldPool`, `totalYieldDistributed`.

- events: Emits `HedgerYieldClaimed`.

- errors: Reverts with insufficient‑yield or access errors.

- reentrancy: Protected by nonReentrant modifier in implementation.

- access: Restricted to `hedger` or HedgerPool.

- oracle: No direct oracle dependency.


```solidity
function claimHedgerYield(address hedger) external returns (uint256 yieldAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`yieldAmount`|`uint256`|Amount of USDC yield transferred.|


### updateLastDepositTime

Updates the last deposit timestamp for a user.

Called by UserPool / HedgerPool so holding‑period logic can be enforced.

**Notes:**
- security: Only callable by UserPool or HedgerPool contracts.

- validation: Reverts on unauthorized caller.

- state-changes: Updates `lastDepositTime[user]`.

- events: None.

- errors: Reverts with authorization error.

- reentrancy: Not applicable – simple storage write.

- access: Restricted to pools.

- oracle: No oracle dependency.


```solidity
function updateLastDepositTime(address user) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address whose last deposit time is updated.|


### updateYieldAllocation

Updates per‑user or per‑hedger yield allocation.

Called by pool logic to adjust individual pending yield balances.

**Notes:**
- security: Restricted to yield‑manager roles via `AccessControlLibrary`.

- validation: Reverts on unauthorized caller.

- state-changes: Updates `userPendingYield` or `hedgerPendingYield`.

- events: None.

- errors: Reverts with access‑control errors.

- reentrancy: Not applicable – simple storage updates.

- access: Restricted to YieldManager role.

- oracle: No oracle dependency.


```solidity
function updateYieldAllocation(address user, uint256 amount, bool isUser) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User or hedger address.|
|`amount`|`uint256`|Allocation delta amount.|
|`isUser`|`bool`|True if `user` is a UserPool participant, false if hedger.|


### configureYieldModel

Batch‑updates all yield model parameters.

See `YieldShift.configureYieldModel` for implementation semantics.

**Notes:**
- security: Restricted to governance.

- validation: Reverts when parameters are out of allowed bounds.

- state-changes: Updates scalar configuration in storage.

- events: None.

- errors: Protocol‑specific config errors.

- reentrancy: Not applicable.

- access: Governance‑only.

- oracle: No oracle dependency.


```solidity
function configureYieldModel(YieldModelConfig calldata cfg) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`cfg`|`YieldModelConfig`|New yield model configuration.|


### configureDependencies

Batch‑updates core dependency addresses.

See `YieldShift.configureDependencies` for implementation semantics.

**Notes:**
- security: Restricted to governance; validates non‑zero addresses.

- validation: Reverts on invalid or zero addresses.

- state-changes: Updates pool, vault, stQEURO and treasury references.

- events: None.

- errors: Protocol‑specific config errors.

- reentrancy: Not applicable.

- access: Governance‑only.

- oracle: No oracle dependency.


```solidity
function configureDependencies(YieldDependencyConfig calldata cfg) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`cfg`|`YieldDependencyConfig`|New dependency configuration.|


### setYieldSourceAuthorization

Sets authorization status and yield type for a yield source.

See `YieldShift.setYieldSourceAuthorization` for implementation semantics.

**Notes:**
- security: Restricted to governance; prevents arbitrary contracts from adding yield.

- validation: Reverts on zero `source` address.

- state-changes: Updates authorization and source‑type mappings.

- events: None.

- errors: Protocol‑specific validation errors.

- reentrancy: Not applicable.

- access: Governance‑only.

- oracle: No oracle dependency.


```solidity
function setYieldSourceAuthorization(address source, bytes32 yieldType, bool authorized) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`source`|`address`|Address of the yield source.|
|`yieldType`|`bytes32`|Type/category of yield generated by the source.|
|`authorized`|`bool`|True to authorize, false to deauthorize.|


### emergencyYieldDistribution

Executes an emergency yield distribution with explicit pool amounts.

Transfers specified portions of yield pool balances to UserPool and HedgerPool.

**Notes:**
- security: Restricted to emergency role; validates pool sufficiency.

- validation: Reverts if requested amounts exceed available pools.

- state-changes: Decreases internal pools and transfers USDC to pools.

- events: Emits implementation‑specific emergency distribution events.

- errors: Reverts with insufficient‑yield errors.

- reentrancy: Protected by nonReentrant modifier in implementation.

- access: Emergency‑only.

- oracle: No oracle dependency.


```solidity
function emergencyYieldDistribution(uint256 userAmount, uint256 hedgerAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`userAmount`|`uint256`|Amount to distribute to user pool.|
|`hedgerAmount`|`uint256`|Amount to distribute to hedger pool.|


### pauseYieldDistribution

Pauses yield distribution operations.

Emergency function to halt yield‑related state changes.

**Notes:**
- security: Restricted to emergency role.

- validation: None.

- state-changes: Sets paused state to true.

- events: Emits `Paused`.

- errors: None.

- reentrancy: Not applicable.

- access: Emergency‑only.

- oracle: No oracle dependency.


```solidity
function pauseYieldDistribution() external;
```

### resumeYieldDistribution

Resumes yield distribution operations after a pause.

Clears the paused state to restore normal operation.

**Notes:**
- security: Restricted to emergency role.

- validation: None.

- state-changes: Sets paused state to false.

- events: Emits `Unpaused`.

- errors: None.

- reentrancy: Not applicable.

- access: Emergency‑only.

- oracle: No oracle dependency.


```solidity
function resumeYieldDistribution() external;
```

### isYieldSourceAuthorized

Checks if a yield source is authorized for a given yield type.

Reads the authorization and yield‑type mapping configured by governance.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function isYieldSourceAuthorized(address source, bytes32 yieldType) external view returns (bool authorized);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`source`|`address`|Address of the yield source.|
|`yieldType`|`bytes32`|Yield type identifier.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`authorized`|`bool`|True if `source` is authorized for `yieldType`.|


### checkAndUpdateYieldDistribution

Checks current conditions and updates yield distribution if required.

Uses TWAP metrics and tolerance thresholds to decide whether to call `updateYieldDistribution`.

**Notes:**
- security: Public keeper function; guarded by internal conditions.

- validation: None.

- state-changes: May update `currentYieldShift`, snapshots and timestamps indirectly.

- events: Emits `YieldDistributionUpdated` when distribution is adjusted.

- errors: None when conditions are not met; may revert on configuration errors.

- reentrancy: Protected by nonReentrant modifier in implementation.

- access: Public/keeper‑triggered.

- oracle: No oracle dependency.


```solidity
function checkAndUpdateYieldDistribution() external;
```

### forceUpdateYieldDistribution

Forces an immediate yield‑distribution update regardless of conditions.

Governance escape hatch calling `updateYieldDistribution` via `this` to preserve modifiers.

**Notes:**
- security: Restricted to governance; overrides normal TWAP/tolerance checks.

- validation: None beyond access‑control.

- state-changes: Same as `updateYieldDistribution`.

- events: Emits `YieldDistributionUpdated`.

- errors: Reverts with configuration or math errors.

- reentrancy: Protected by nonReentrant modifier in implementation.

- access: Governance‑only.

- oracle: No oracle dependency.


```solidity
function forceUpdateYieldDistribution() external;
```

### getYieldDistributionBreakdown

Returns a breakdown of yield between user and hedger pools.

Aggregates `userYieldPool` and `hedgerYieldPool` into a distribution ratio.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public – for dashboards and analytics.

- oracle: No oracle dependency.


```solidity
function getYieldDistributionBreakdown()
    external
    view
    returns (uint256 userYieldPool_, uint256 hedgerYieldPool_, uint256 distributionRatio);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`userYieldPool_`|`uint256`|Current user yield pool balance.|
|`hedgerYieldPool_`|`uint256`|Current hedger yield pool balance.|
|`distributionRatio`|`uint256`|User share of total yield pool in basis points.|


### getPoolMetrics

Returns current pool metrics for user and hedger pools.

Exposes pool sizes, current ratio and target ratio for monitoring.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function getPoolMetrics()
    external
    view
    returns (uint256 userPoolSize, uint256 hedgerPoolSize, uint256 poolRatio, uint256 targetRatio);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`userPoolSize`|`uint256`|Current user pool size.|
|`hedgerPoolSize`|`uint256`|Current hedger pool size.|
|`poolRatio`|`uint256`|Ratio of user to hedger pools.|
|`targetRatio`|`uint256`|Target pool ratio configured in the model.|


### calculateOptimalYieldShift

Calculates the optimal yield shift based on current pool metrics.

Purely view‑based recommendation; does not update state.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public – off‑chain controllers may act on it.

- oracle: No oracle dependency.


```solidity
function calculateOptimalYieldShift() external view returns (uint256 optimalShift, uint256 currentDeviation);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`optimalShift`|`uint256`|Recommended yield shift in basis points.|
|`currentDeviation`|`uint256`|Absolute deviation between current and optimal shifts.|


### getYieldSources

Returns aggregated yield amounts by source category.

Splits `yieldSources` into Aave, protocol fees, interest differential and other.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public – for analytics.

- oracle: No oracle dependency.


```solidity
function getYieldSources()
    external
    view
    returns (uint256 aaveYield, uint256 protocolFees, uint256 interestDifferential, uint256 otherSources);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`aaveYield`|`uint256`|Yield attributed to Aave.|
|`protocolFees`|`uint256`|Yield attributed to protocol fees.|
|`interestDifferential`|`uint256`|Yield attributed to interest‑rate differential.|
|`otherSources`|`uint256`|Residual yield not in the known categories.|


### getHistoricalYieldShift

Returns a compact summary of yield‑shift behavior over a period.

Implementation currently returns a representative single value for the window.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public – for historical analytics.

- oracle: No oracle dependency.


```solidity
function getHistoricalYieldShift(uint256 period)
    external
    view
    returns (uint256 averageShift, uint256 maxShift, uint256 minShift, uint256 volatility);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`period`|`uint256`|Look‑back period in seconds.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`averageShift`|`uint256`|Representative shift in the period.|
|`maxShift`|`uint256`|Same as `averageShift` in compact mode.|
|`minShift`|`uint256`|Same as `averageShift` in compact mode.|
|`volatility`|`uint256`|Always 0 in compact summary mode.|


### getYieldPerformanceMetrics

Returns compact performance metrics for yield operations.

Aggregates total distributed yield, current pools and efficiency ratio.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public – for dashboards and reporting.

- oracle: No oracle dependency.


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
|`totalYieldDistributed_`|`uint256`|Total yield distributed so far.|
|`averageUserYield`|`uint256`|Current user yield pool balance.|
|`averageHedgerYield`|`uint256`|Current hedger yield pool balance.|
|`yieldEfficiency`|`uint256`|Distributed/generate ratio in basis points.|


### currentYieldShift

Returns the current yield shift between users and hedgers.

This value drives how new yield is split between `userYieldPool` and `hedgerYieldPool`.

**Notes:**
- security: View‑only.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function currentYieldShift() external view returns (uint256 shift);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shift`|`uint256`|Current shift value in basis points.|


### totalYieldGenerated

Returns total yield generated across all sources.

Monotonically increasing counter of all yield ever added via `addYield`.

**Notes:**
- security: View‑only.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function totalYieldGenerated() external view returns (uint256 total);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`total`|`uint256`|Total generated yield.|


### totalYieldDistributed

Returns total yield distributed so far.

Tracks how much of `totalYieldGenerated` has actually been paid out.

**Notes:**
- security: View‑only.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function totalYieldDistributed() external view returns (uint256 total);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`total`|`uint256`|Total distributed yield.|


### userYieldPool

Returns current user yield pool balance.

Amount of yield currently earmarked for users but not yet claimed.

**Notes:**
- security: View‑only.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function userYieldPool() external view returns (uint256 pool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`pool`|`uint256`|User yield pool amount.|


### hedgerYieldPool

Returns current hedger yield pool balance.

Amount of yield currently earmarked for hedgers but not yet claimed.

**Notes:**
- security: View‑only.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function hedgerYieldPool() external view returns (uint256 pool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`pool`|`uint256`|Hedger yield pool amount.|


### userPendingYield

Returns pending yield for a user.

Reads per‑user pending yield that can be claimed via `claimUserYield`.

**Notes:**
- security: View‑only.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function userPendingYield(address user) external view returns (uint256 amount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Pending yield amount.|


### hedgerPendingYield

Returns pending yield for a hedger.

Reads per‑hedger pending yield that can be claimed via `claimHedgerYield`.

**Notes:**
- security: View‑only.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function hedgerPendingYield(address hedger) external view returns (uint256 amount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Hedger address.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Pending yield amount.|


### userLastClaim

Returns last claim timestamp for a user.

Used together with `lastDepositTime` to enforce holding‑period rules.

**Notes:**
- security: View‑only.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function userLastClaim(address user) external view returns (uint256 timestamp);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`timestamp`|`uint256`|Last claim time.|


### hedgerLastClaim

Returns last claim timestamp for a hedger.

Used to monitor hedger reward activity and potential abuse.

**Notes:**
- security: View‑only.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function hedgerLastClaim(address hedger) external view returns (uint256 timestamp);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Hedger address.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`timestamp`|`uint256`|Last claim time.|


### baseYieldShift

Returns the base yield shift configuration parameter.

Baseline user share when pools are perfectly balanced.

**Notes:**
- security: View‑only.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function baseYieldShift() external view returns (uint256 base);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`base`|`uint256`|Base shift value (bps).|


### maxYieldShift

Returns the maximum yield shift configuration parameter.

Upper bound for how far `currentYieldShift` may move away from the base.

**Notes:**
- security: View‑only.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function maxYieldShift() external view returns (uint256 maxShift);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`maxShift`|`uint256`|Maximum shift value (bps).|


### adjustmentSpeed

Returns the adjustment speed configuration parameter.

Controls how quickly `currentYieldShift` moves toward the optimal shift.

**Notes:**
- security: View‑only.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function adjustmentSpeed() external view returns (uint256 speed);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`speed`|`uint256`|Adjustment speed in basis points.|


### targetPoolRatio

Returns the target pool ratio configuration parameter.

Ideal ratio of user‑pool size to hedger‑pool size used in shift calculations.

**Notes:**
- security: View‑only.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function targetPoolRatio() external view returns (uint256 ratio);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ratio`|`uint256`|Target user/hedger pool ratio in basis points.|


### lastUpdateTime

Returns the last time yield distribution was updated.

Timestamp used to enforce minimum intervals and TWAP windows between updates.

**Notes:**
- security: View‑only.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function lastUpdateTime() external view returns (uint256 timestamp);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`timestamp`|`uint256`|Last update time.|


### paused

Returns whether yield distribution is currently paused.

When true, state‑changing yield operations are halted by `Pausable`.

**Notes:**
- security: View‑only.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function paused() external view returns (bool isPaused);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isPaused`|`bool`|True if paused, false otherwise.|


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
    address stQEUROFactory;
    address treasury;
}
```

