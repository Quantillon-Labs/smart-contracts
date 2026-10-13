# ExecutionPricingLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/083874330beb67c980851f48832ef5faa68973d3/src/libraries/ExecutionPricingLibrary.sol)

**Title:**
ExecutionPricingLibrary

Linked vault integration for volume pricing, preserving reference accounting.


## Functions
### version

Linked library semantic version.

Uses the documented units and preserves reference-price accounting.

**Notes:**
- security: Uses explicit contract access boundaries and checked arithmetic.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: None.

- events: None.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: No state changes.

- access: Public read access.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
function version() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|result Calculated result in the units described by this operation.|


### mint

Calculate and consume a mint quote, reverting below the user's floor.

Uses the documented units and preserves reference-price accounting.

**Notes:**
- security: Called by delegatecall from the guarded vault flow.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: Applies the effects described above.

- events: Emits the events described above when applicable.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: Vault settlement is nonReentrant; publisher and reporter methods have no external state-changing callbacks.

- access: Called from the guarded vault flow.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
function mint(IExecutionPricing module, uint256 input, uint256 feeRate, uint256 ref, uint256 minimum)
    external
    returns (uint256 fee, uint256 backing, uint256 q);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`module`|`IExecutionPricing`|Configured pricing module, or zero before activation.|
|`input`|`uint256`|Gross USDC input.|
|`feeRate`|`uint256`|Protocol fee fraction in 18 decimals.|
|`ref`|`uint256`|Reference EUR/USD price in 18 decimals.|
|`minimum`|`uint256`|Minimum QEURO output in 18 decimals.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`fee`|`uint256`|Protocol fee in USDC.|
|`backing`|`uint256`|Net reference backing in USDC.|
|`q`|`uint256`|QEURO output.|


### redeem

Calculate and consume a normal redemption quote.

Uses the documented units and preserves reference-price accounting.

**Notes:**
- security: No execution cost is charged twice; gross = net + fee + spread.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: Applies the effects described above.

- events: Emits the events described above when applicable.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: Vault settlement is nonReentrant; publisher and reporter methods have no external state-changing callbacks.

- access: Called from the guarded vault flow.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
function redeem(IExecutionPricing module, uint256 q, uint256 feeRate, uint256 ref, uint256 minimum)
    external
    returns (uint256 gross, uint256 net, uint256 fee);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`module`|`IExecutionPricing`|Configured pricing module, or zero before activation.|
|`q`|`uint256`|QEURO input in 18 decimals.|
|`feeRate`|`uint256`|Protocol fee fraction in 18 decimals.|
|`ref`|`uint256`|Reference EUR/USD price in 18 decimals.|
|`minimum`|`uint256`|Minimum USDC output in 6 decimals.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`gross`|`uint256`|Reference-valued collateral removed.|
|`net`|`uint256`|User payout after execution spread and protocol fee.|
|`fee`|`uint256`|Protocol fee in USDC.|


### validateConfiguration

Check a governance module transition without discarding pending exposure.

Read-only contract interface.

**Notes:**
- security: The vault enforces governance and pause requirements before delegation.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: None.

- events: None.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: No state changes.

- access: Public read access.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
function validateConfiguration(IExecutionPricing previous, address next)
    external
    view
    returns (bool signedExecution);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`previous`|`IExecutionPricing`|Previous configured module.|
|`next`|`address`|Proposed module, or zero to deactivate.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`signedExecution`|`bool`|Whether the validated module requires signed settlement contexts.|


### routeFees

Route protocol fees independently of execution spreads.

Uses the documented units and preserves reference-price accounting.

**Notes:**
- security: Delegatecalled within the vault's guarded settlement flow.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: Applies the effects described above.

- events: Emits the events described above when applicable.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: Vault settlement is nonReentrant; publisher and reporter methods have no external state-changing callbacks.

- access: Called from the guarded vault flow.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
function routeFees(
    IERC20 token,
    uint256 fee,
    uint256 split,
    IHedgerPool hedger,
    address collector,
    string memory source
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`IERC20`|USDC token.|
|`fee`|`uint256`|Protocol fee amount.|
|`split`|`uint256`|Hedger reward fraction in 18 decimals.|
|`hedger`|`IHedgerPool`|Hedger reward pool.|
|`collector`|`address`|Protocol fee collector.|
|`source`|`string`|Accounting source tag.|


### enforceDeviation

Enforce the vault's existing reference-price deviation policy.

Uses the documented units and preserves reference-price accounting.

**Notes:**
- security: Preserves the 200 bps and one-block policy independently of execution pricing.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: Applies the effects described above.

- events: Emits the events described above when applicable.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: Vault settlement is nonReentrant; publisher and reporter methods have no external state-changing callbacks.

- access: Called from the guarded vault flow.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
function enforceDeviation(uint256 price, uint256 previous, uint256 lastBlock) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|Live reference price.|
|`previous`|`uint256`|Cached reference price.|
|`lastBlock`|`uint256`|Block of the previous cache update.|


### enforceCollateralization

Validate projected reference-valued collateralization.

Uses the documented units and preserves reference-price accounting.

**Notes:**
- security: Execution spread reserves are excluded by the caller.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: None.

- events: None.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: No state changes.

- access: Public read access.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
function enforceCollateralization(uint256 collateral, uint256 supply, uint256 price, uint256 minimum)
    external
    pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`collateral`|`uint256`|Projected collateral in USDC units.|
|`supply`|`uint256`|Projected QEURO supply.|
|`price`|`uint256`|Reference price.|
|`minimum`|`uint256`|Minimum collateralization percentage scaled by 1e18.|


### collateralizationRatio

Compute the reference-valued collateralization ratio for the calling vault.

Uses the documented units and preserves reference-price accounting.

**Notes:**
- security: Reads collateral only after nonzero reference backing is established.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: None.

- events: None.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: No state changes.

- access: Public read access.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
function collateralizationRatio(IERC20 token, uint256 price) public view returns (uint256 ratio);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`IERC20`|QEURO token used for total circulating supply.|
|`price`|`uint256`|Reference USD per EUR price.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ratio`|`uint256`|Percentage scaled by 1e18, or zero for absent backing.|


### enforceYieldEligibility

Validates yield conversion independently of the public mint gate.

No dust-supply bootstrap exemption applies to yield conversion.

**Notes:**
- security: Requires CR strictly above max(101%, critical).

- validation: Requires initialized pricing and an active hedger.

- state-changes: None.

- events: None.

- errors: NotInitialized, NoActiveHedgerLiquidity, InsufficientCollateralization.

- reentrancy: Static reads only.

- access: Linked vault library.

- oracle: Uses the validated price supplied by the vault.


```solidity
function enforceYieldEligibility(IERC20 token, IHedgerPool hedger, uint256 cached, uint256 price, uint256 critical)
    external
    view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`IERC20`|QEURO token.|
|`hedger`|`IHedgerPool`|Active hedger pool.|
|`cached`|`uint256`|Initialized cached price.|
|`price`|`uint256`|Validated current price.|
|`critical`|`uint256`|Liquidation threshold in percentage scaled by 1e18.|


### enforceMintEligibility

Enforce initialized pricing, active hedging and the live mint floor.

Read-only contract interface.

**Notes:**
- security: Preserves the vault's bounded dust-supply bootstrap behavior.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: None.

- events: None.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: No state changes.

- access: Public read access.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
function enforceMintEligibility(IERC20 token, IHedgerPool hedger, uint256 cached, uint256 price, uint256 minimum)
    external
    view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`IERC20`|QEURO token.|
|`hedger`|`IHedgerPool`|Configured hedger pool.|
|`cached`|`uint256`|Previously initialized reference price.|
|`price`|`uint256`|Live reference price.|
|`minimum`|`uint256`|Minimum collateralization percentage scaled by 1e18.|


## Events
### ProtocolFeeRouted

```solidity
event ProtocolFeeRouted(string sourceType, uint256 totalFee, uint256 hedgerReserveShare, uint256 collectorShare);
```

### PriceDeviationDetected

```solidity
event PriceDeviationDetected(
    uint256 currentPrice, uint256 lastValidPrice, uint256 deviationBps, uint256 blockNumber
);
```
