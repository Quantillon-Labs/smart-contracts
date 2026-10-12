# StakingYieldLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/54366a1075ba6db39540a3d83709a310c26d1723/src/libraries/StakingYieldLibrary.sol)

**Title:**
StakingYieldLibrary

External (linked) library holding the stQEURO yield-distribution split, extracted from
QuantillonVault to keep that contract under the EIP-170 24,576-byte runtime limit.

Called via delegatecall from QuantillonVault, so external calls (adapter harvest, USDC
transfers) execute in the vault's context (`address(this)` == vault). The vault performs the
stQEURO credit and event emission; this library realizes the yield, computes the hedger /
staker / treasury split, and routes the hedger and treasury shares.


## Constants
### BPS_DENOMINATOR

```solidity
uint256 private constant BPS_DENOMINATOR = 10000
```


## Functions
### setPriority

Replaces the withdrawal priority with unique configured adapter ids.

Prevents duplicate principal accounting in priority-dependent views.

**Notes:**
- security: Caller enforces governance authorization.

- validation: Rejects inactive, duplicate, zero, or unconfigured ids.

- state-changes: Replaces priority storage.

- events: RedemptionPriorityUpdated.

- errors: InvalidVault or ZeroAddress.

- reentrancy: No external calls.

- access: Linked library.

- oracle: None.


```solidity
function setPriority(
    mapping(uint256 => IExternalStakingVault) storage adapters,
    mapping(uint256 => bool) storage active,
    uint256[] storage priority,
    uint256[] calldata ids
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`adapters`|`mapping(uint256 => IExternalStakingVault)`|Adapter registry.|
|`active`|`mapping(uint256 => bool)`|Active flags.|
|`priority`|`uint256[]`|Existing priority storage.|
|`ids`|`uint256[]`|Requested ids.|


### validateRedemptionCoverage

Requires the effective redemption set to cover all tracked external principal.

The priority setter guarantees unique ids; an empty list selects only the default.

**Notes:**
- security: Prevents configuration from omitting funded collateral.

- validation: Sum of included principal must equal the aggregate tracker.

- state-changes: None.

- events: None.

- errors: InvalidCondition or arithmetic overflow.

- reentrancy: No external calls.

- access: Linked library; caller enforces governance authorization.

- oracle: None.


```solidity
function validateRedemptionCoverage(
    mapping(uint256 => uint256) storage principal,
    uint256[] storage priority,
    uint256 defaultId,
    uint256 totalPrincipal
) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`principal`|`mapping(uint256 => uint256)`|Tracked principal by vault id.|
|`priority`|`uint256[]`|Unique ordered redemption ids.|
|`defaultId`|`uint256`|Fallback id when priority is empty.|
|`totalPrincipal`|`uint256`|Aggregate tracked external principal.|


### configureAdapter

Configures an external adapter while preserving tracked collateral.

Funded replacements require a paused vault, empty old adapter, and funded new adapter.

**Notes:**
- security: Caller enforces governance authorization.

- validation: Rejects disabling funded adapters and unfunded replacements.

- state-changes: Updates registry and active flag.

- events: StakingVaultConfigured.

- errors: InvalidVault, ZeroAddress, InvalidCondition.

- reentrancy: External adapter calls are view-only.

- access: Linked library.

- oracle: None.


```solidity
function configureAdapter(
    mapping(uint256 => IExternalStakingVault) storage adapters,
    mapping(uint256 => bool) storage active,
    mapping(uint256 => uint256) storage principal,
    uint256 id,
    address next,
    bool enabled,
    bool isPaused
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`adapters`|`mapping(uint256 => IExternalStakingVault)`|Adapter registry.|
|`active`|`mapping(uint256 => bool)`|Active adapter flags.|
|`principal`|`mapping(uint256 => uint256)`|Tracked principal by vault.|
|`id`|`uint256`|Vault id.|
|`next`|`address`|New adapter.|
|`enabled`|`bool`|Requested active flag.|
|`isPaused`|`bool`|Vault pause state.|


### realizeLoss

Records reduced external collateral without changing hedger margin.

The caller deducts the returned loss from aggregate external principal.

**Notes:**
- security: Caller enforces governance authorization.

- validation: Adapter must exist and report less underlying than tracked principal.

- state-changes: Reduces per-vault principal.

- events: ExternalVaultLossRealized.

- errors: InvalidVault or InvalidCondition.

- reentrancy: View-only adapter call.

- access: Linked library.

- oracle: None.


```solidity
function realizeLoss(
    mapping(uint256 => IExternalStakingVault) storage adapters,
    mapping(uint256 => uint256) storage principal,
    uint256 id
) external returns (uint256 loss);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`adapters`|`mapping(uint256 => IExternalStakingVault)`|Adapter registry.|
|`principal`|`mapping(uint256 => uint256)`|Tracked principal by vault.|
|`id`|`uint256`|Vault id.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`loss`|`uint256`|USDC principal loss recognized.|


### registerToken

Registers and verifies a deterministic per-vault staking token.

Preserves registry binding before the external factory call.

**Notes:**
- security: Vault wrapper enforces governance and nonReentrant.

- validation: Requires a fresh valid binding and matching preview.

- state-changes: Stores token binding.

- events: Factory emits registration events; caller emits local registration.

- errors: InvalidToken, InvalidVault, AlreadyInitialized, InvalidAddress.

- reentrancy: Caller holds the guard.

- access: Linked library.

- oracle: None.


```solidity
function registerToken(
    mapping(uint256 => address) storage tokens,
    address factory,
    uint256 id,
    string calldata name
) external returns (address token);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokens`|`mapping(uint256 => address)`|Per-vault staking token registry.|
|`factory`|`address`|Factory address.|
|`id`|`uint256`|Vault identifier.|
|`name`|`string`|Vault name.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Registered staking token.|


### withdrawPrincipal

Sources an exact aggregate payout from priority-ordered adapters.

Requires every adapter to return the exact requested amount and verifies the balance
delta. Adapters must absorb any rounding dust internally before returning.

**Notes:**
- security: Delegatecalled from guarded vault settlement.

- validation: Requires exact aggregate liquidity and verifies adapter balance deltas.

- state-changes: Reduces per-adapter principal; caller reduces aggregate principal.

- events: UsdcWithdrawnFromExternalVault.

- errors: InvalidAmount or InsufficientBalance.

- reentrancy: Caller holds nonReentrant guard.

- access: Linked library.

- oracle: None.


```solidity
function withdrawPrincipal(
    mapping(uint256 => IExternalStakingVault) storage adapters,
    mapping(uint256 => bool) storage active,
    mapping(uint256 => uint256) storage principal,
    uint256[] memory priority,
    uint256 amount,
    IERC20 usdc
) external returns (uint256 withdrawn);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`adapters`|`mapping(uint256 => IExternalStakingVault)`|Adapter registry.|
|`active`|`mapping(uint256 => bool)`|Active adapter flags.|
|`principal`|`mapping(uint256 => uint256)`|Per-adapter tracked principal.|
|`priority`|`uint256[]`|Ordered source identifiers.|
|`amount`|`uint256`|Exact USDC deficit to source.|
|`usdc`|`IERC20`|Collateral token.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`withdrawn`|`uint256`|Aggregate transferred USDC.|


### version

Returns the semantic version of this linked library.

On-chain version of the standalone deployed library; bump per semver on any change.
See deployments/{chainId}/versions.json for deployed-address provenance.

**Notes:**
- security: No security implications - returns a compile-time constant.

- validation: No input validation required.

- state-changes: None - pure function.

- events: None.

- errors: None.

- reentrancy: Not applicable - pure function.

- access: Public - anyone can read the version.

- oracle: No oracle dependencies.


```solidity
function version() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Semantic version string (e.g. "1.0.0").|


### calculateSplit

Calculate conserved staking-ratio allocations of realized yield.

Floors gross staker yield and the haircut; staking-ratio dust goes to treasury and haircut dust to stakers.

**Notes:**
- security: Never deducts principal; allocations sum to yieldUsdc.

- validation: Haircut cannot exceed 100%.

- state-changes: None.

- events: None.

- errors: AboveLimit for an invalid haircut.

- reentrancy: No external calls.

- access: Public library calculation.

- oracle: No price used in allocation.


```solidity
function calculateSplit(uint256 yieldUsdc, Capital memory c, uint256 haircutBps)
    public
    pure
    returns (Split memory s);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`yieldUsdc`|`uint256`|Realized USDC yield.|
|`c`|`Capital`|Staking ownership snapshot; retired capital fields are ignored.|
|`haircutBps`|`uint256`|Percentage of gross staker yield, in basis points.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`s`|`Split`|Distribution before execution costs.|


### _params

Resolve the calling vault's configuration before taking a staking snapshot.

Only called by delegatecall entrypoints; external self-calls read public vault getters.


```solidity
function _params(uint256 vaultId) private view returns (DistributeParams memory p);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vaultId`|`uint256`|Selected strategy.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`p`|`DistributeParams`|Validated configuration.|


### _snapshot

Snapshot staking ownership and enforce the single-funded-strategy distribution boundary.

Registered token balances include credited unvested QEURO when shareholders exist.

**Notes:**
- security: Fails closed on unsupported strategies or invalid accounting reads.

- validation: All external principal and all outstanding staking shares must belong to this series.

- state-changes: None.

- events: None.

- errors: InvalidCondition, InvalidVault, or propagated external errors.

- reentrancy: Caller holds its reentrancy guard.

- access: Internal library helper.

- oracle: None; conversion validates prices separately.


```solidity
function _snapshot(DistributeParams memory p) private view returns (Capital memory c);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`p`|`DistributeParams`|Calling vault configuration.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`c`|`Capital`|Economic ownership before harvest and minting.|


### previewSplit

Preview the next distribution with the same ownership calculation as execution.

Call through eth_call. Actual realized yield may differ due to available withdrawal liquidity.

**Notes:**
- security: Shares execution validation and requires a recipient for nonzero hedger payments.

- validation: Validates the strategy boundary and any nonzero hedger recipient.

- state-changes: None.

- events: None.

- errors: Propagates snapshot errors; ZeroAddress for a missing hedger recipient.

- reentrancy: Caller holds its reentrancy guard.

- access: Linked library.

- oracle: None; conversion validates prices separately.


```solidity
function previewSplit(uint256 vaultId) external returns (Split memory s);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vaultId`|`uint256`|Selected strategy.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`s`|`Split`|Estimated USDC allocations before execution costs.|


### harvestAndSplit

Harvest and allocate yield by the staking ratio, with a haircut on gross staking yield.

The vault credits userShare via its existing QEURO mint path. Failure rolls back the whole harvest.

**Notes:**
- security: Principal is untouched; no fallback recipient silently captures hedger yield.

- validation: Same staking validation as preview; nonzero hedger payout requires a recipient.

- state-changes: Harvests adapter yield and transfers hedger/treasury USDC.

- events: Adapter/token events; the vault emits distribution events.

- errors: Propagates snapshot/adapter/token errors; ZeroAddress for missing recipient.

- reentrancy: Caller holds its reentrancy guard.

- access: Linked library.

- oracle: No price used for allocation; ownership is sampled before harvesting and minting.


```solidity
function harvestAndSplit(uint256 vaultId, mapping(uint256 => uint256) storage lastHarvest)
    external
    returns (uint256 userShare);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vaultId`|`uint256`|Selected strategy.|
|`lastHarvest`|`mapping(uint256 => uint256)`|Keeper timestamps updated atomically with distribution.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`userShare`|`uint256`|USDC allocation to credit through the existing QEURO mint path.|


## Events
### UsdcWithdrawnFromExternalVault

```solidity
event UsdcWithdrawnFromExternalVault(uint256 indexed vaultId, uint256 indexed usdcAmount, uint256 principalAfter);
```

### StakingVaultConfigured

```solidity
event StakingVaultConfigured(uint256 indexed vaultId, address indexed adapter, bool active);
```

### ExternalVaultLossRealized

```solidity
event ExternalVaultLossRealized(uint256 indexed vaultId, uint256 previousPrincipal, uint256 currentUnderlying);
```

### RedemptionPriorityUpdated

```solidity
event RedemptionPriorityUpdated(uint256[] vaultIds);
```

### VaultYieldDistributed

```solidity
event VaultYieldDistributed(
    uint256 indexed vaultId, uint256 realizedYield, uint256 hedgerShare, uint256 userShare, uint256 treasuryShare
);
```

### VaultYieldBreakdown

```solidity
event VaultYieldBreakdown(uint256 indexed vaultId, uint256 hedgerBase, uint256 stakingYieldHaircut);
```

## Structs
### DistributeParams
Configuration and strategy registries supplied by the calling vault.


```solidity
struct DistributeParams {
    address adapter;
    address stToken;
    address qeuro;
    address usdc;
    address treasury;
    address hedgerRecipient;
    uint256 principalUsdc;
    uint256 totalPrincipalUsdc;
    uint256 haircutBps;
    address factory;
    address hedgerPool;
    address oracle;
    uint256 vaultId;
}
```

### Split
USDC allocations before execution costs; hedgerBase is retired and always zero.


```solidity
struct Split {
    uint256 realizedYield;
    uint256 hedgerBase;
    uint256 haircut;
    uint256 hedgerShare;
    uint256 userShare;
    uint256 treasuryShare;
}
```

### Capital
Harvest-time staking snapshot; hedger and userBacking are retired ABI fields.


```solidity
struct Capital {
    uint256 hedger;
    uint256 userBacking;
    uint256 staked;
    uint256 supply;
}
```
