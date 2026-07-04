# StakingYieldLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/fdf5f8f6194f4b414785cf5d6e2e583cb790646c/src/libraries/StakingYieldLibrary.sol)

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


### harvestAndSplit

Harvests adapter yield and splits it: hedger funding first, residual by staked ratio,
remainder to treasury; routes the hedger and treasury shares in USDC.

The caller (vault) credits `userShare` into stQEURO and emits the distribution event.

**Notes:**
- security: Runs under the vault's `nonReentrant`/pause guards via delegatecall.

- validation: Caller validates vault id, adapter, and access control.

- state-changes: Moves USDC out of the vault to hedger recipient and treasury.

- events: None; the vault emits `VaultYieldDistributed`.

- errors: Reverts on adapter or transfer failures.

- reentrancy: Caller-guarded.

- access: Internal protocol use (linked library).

- oracle: No oracle dependency in this library.


```solidity
function harvestAndSplit(DistributeParams memory p)
    external
    returns (uint256 realizedYield, uint256 hedgerShare, uint256 userShare, uint256 treasuryShare);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`p`|`DistributeParams`|Distribution inputs read from vault storage.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`realizedYield`|`uint256`|Total USDC yield realized from the adapter (6 decimals).|
|`hedgerShare`|`uint256`|USDC routed to the hedger recipient (6 decimals).|
|`userShare`|`uint256`|USDC the vault must credit into stQEURO (6 decimals).|
|`treasuryShare`|`uint256`|USDC routed to the treasury (6 decimals).|


## Structs
### DistributeParams
Inputs for `harvestAndSplit`, read from vault storage by the caller.


```solidity
struct DistributeParams {
    address adapter;
    address stToken;
    address qeuro;
    address usdc;
    address treasury;
    address hedgerRecipient;
    uint256 principalUsdc;
    uint256 fundingRateAnnualBps;
    uint256 lastHarvest;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`adapter`|`address`|External staking vault adapter for the vault id.|
|`stToken`|`address`|stQEURO share token for the vault id (zero if unregistered).|
|`qeuro`|`address`|QEURO token (for circulating supply).|
|`usdc`|`address`|USDC token used for hedger/treasury routing.|
|`treasury`|`address`|Protocol treasury (treasury share + hedger fallback recipient).|
|`hedgerRecipient`|`address`|Hedger funding recipient (falls back to treasury when zero).|
|`principalUsdc`|`uint256`|Tracked principal deployed to the vault (hedger notional, 6 decimals).|
|`fundingRateAnnualBps`|`uint256`|Annualized hedger funding rate in basis points.|
|`lastHarvest`|`uint256`|Timestamp of the previous distribution (0 = first call, no hedger accrual).|

