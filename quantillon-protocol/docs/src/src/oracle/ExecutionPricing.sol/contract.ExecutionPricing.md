# ExecutionPricing
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/083874330beb67c980851f48832ef5faa68973d3/src/oracle/ExecutionPricing.sol)

**Inherits:**
AccessControl, [IExecutionPricing](/src/interfaces/IExecutionPricing.sol/interface.IExecutionPricing.md)

**Title:**
ExecutionPricing

Bounded, directional order-book pricing with persistent admission accounting.

Non-upgradeable module. Governance configures it on a paused vault after publishing depth.
Reporter acknowledgments attest completed hedges; publishing alone never releases exposure.


## Constants
### SCALE

```solidity
uint256 private constant SCALE = 1e30
```


### BPS

```solidity
uint256 private constant BPS = 10_000
```


### MAX_LEVELS
Maximum number of executable price levels on each side.


```solidity
uint256 public constant MAX_LEVELS = 20
```


### WRITER_ROLE
Role authorized to publish observed Hyperliquid depth.


```solidity
bytes32 public constant WRITER_ROLE = keccak256("WRITER_ROLE")
```


### REPORTER_ROLE
Role authorized to acknowledge hedged exposure and margin capacity.


```solidity
bytes32 public constant REPORTER_ROLE = keccak256("REPORTER_ROLE")
```


### vault
Vault authorized to consume liquidity.


```solidity
address public immutable override vault
```


### venueOracle
Hyperliquid oracle required in the router's active market slot.


```solidity
address public immutable venueOracle
```


### reserveRecipient
Recipient of execution spread reserves.


```solidity
address public immutable reserveRecipient
```


## State Variables
### maxAge
Maximum book and capacity observation age in seconds.


```solidity
uint256 public maxAge
```


### maxImpactBps
Maximum per-level deviation from the reference price in basis points.


```solidity
uint256 public maxImpactBps
```


### bufferBps
Venue fee and timing allowance incorporated into each execution rate.


```solidity
uint256 public bufferBps
```


### maxOutstanding
Governance ceiling on net directional unacknowledged EUR exposure.


```solidity
uint256 public maxOutstanding
```


### degradedHaircutBps
Haircut applied to reference-priced redemptions when execution data is unavailable.


```solidity
uint256 public degradedHaircutBps = 25
```


### riskLimitsUpdatedAt
Governance-update timestamp; subsequent reports must be observed after this time.


```solidity
uint256 public riskLimitsUpdatedAt
```


### asks

```solidity
Level[] private asks
```


### bids

```solidity
Level[] private bids
```


### observedAt
Original source observation time; never replaced by publication time.


```solidity
uint256 public observedAt
```


### sequence
Monotonic accepted snapshot revision.


```solidity
uint256 public sequence
```


### usedBuy
Buy-side quantity consumed from the current admission epoch.


```solidity
uint256 public usedBuy
```


### usedSell
Sell-side quantity consumed from the current admission epoch.


```solidity
uint256 public usedSell
```


### admittedBuy
Lifetime admitted quantities, used as replay-safe acknowledgment cursors.


```solidity
uint256 public admittedBuy
```


### admittedSell

```solidity
uint256 public admittedSell
```


### acknowledgedBuy
Lifetime hedge-acknowledged quantities.


```solidity
uint256 public acknowledgedBuy
```


### acknowledgedSell

```solidity
uint256 public acknowledgedSell
```


### acknowledgedAt
Time of the last complete hedge acknowledgment.


```solidity
uint256 public acknowledgedAt
```


### lastConsumptionBlock
Last block in which exposure was consumed.


```solidity
uint256 public lastConsumptionBlock
```


### marginCapacity
Reporter-certified additional margin capacity in EUR and its observation time.


```solidity
uint256 public marginCapacity
```


### capacityObservedAt

```solidity
uint256 public capacityObservedAt
```


## Functions
### constructor

Deploy a vault-bound pricing module with explicit initial risk ceilings.

Uses the documented units and preserves reference-price accounting.

**Notes:**
- security: Explicit role separation; no default economic limits are inferred.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: Applies the effects described above.

- events: Emits the events described above when applicable.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: Vault settlement is nonReentrant; publisher and reporter methods have no external state-changing callbacks.

- access: Deployment only; explicit role recipients are required.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
constructor(address[6] memory addresses, uint256[4] memory limits) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`addresses`|`address[6]`|Vault, Hyperliquid oracle, governance, depth writer, hedge reporter, reserve recipient.|
|`limits`|`uint256[4]`|Maximum age (seconds), maximum impact (bps), rate buffer (bps), max outstanding EUR (18 decimals).|


### version

Implementation semantic version.

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


### setDegradedHaircutBps

Sets the bounded haircut used by the redemption liveness fallback.

The setting applies only when a fresh coherent execution book cannot settle a redemption.

**Notes:**
- security: Governance-only and only while the vault is paused.

- validation: Rejects haircuts above the hard safety cap.

- state-changes: Updates the fallback payout parameter.

- events: Emits `DegradedHaircutUpdated`.

- errors: InvalidCondition or InvalidParameter.

- reentrancy: Only a read-only vault pause check.

- access: DEFAULT_ADMIN_ROLE.

- oracle: No oracle dependency.


```solidity
function setDegradedHaircutBps(uint256 haircutBps) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`haircutBps`|`uint256`|Haircut in basis points, at most 1000 (10%).|


### updateRiskLimits

Update pricing limits on a paused vault after all admitted hedges are acknowledged.

Invalidates depth and capacity so subsequent quotes require newly observed reports.

**Notes:**
- security: Governance only; cannot change the terms of pending admission.

- validation: Requires paused settlement, zero outstanding admission and bounded limits.

- state-changes: Updates limits, invalidates reports and clears consumed depth.

- events: RiskLimitsUpdated.

- errors: InvalidCondition for unsettled/unpaused vault; InvalidParameter for invalid limits.

- reentrancy: Only a read-only call to the immutable vault.

- access: DEFAULT_ADMIN_ROLE.

- oracle: Fresh reports observed after the change are required before quoting.


```solidity
function updateRiskLimits(uint256 age, uint256 impact, uint256 buffer, uint256 outstandingLimit)
    external
    onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`age`|`uint256`|Maximum source age in seconds, from 1 to 300.|
|`impact`|`uint256`|Maximum total per-level execution impact in bps, from 1 to 500.|
|`buffer`|`uint256`|Execution-rate buffer in bps, no greater than impact.|
|`outstandingLimit`|`uint256`|Aggregate unacknowledged EUR ceiling in 18 decimals.|


### _validateRiskLimits

Validate pricing risk limits.

Applies the same bounds during deployment and governance updates.

**Notes:**
- security: Caps source age and per-level impact.

- validation: Age 1–300, impact 1–500, buffer at most impact, positive exposure limit.

- state-changes: None.

- events: None.

- errors: InvalidParameter.

- reentrancy: None.

- access: Internal.

- oracle: None.


```solidity
function _validateRiskLimits(uint256 age, uint256 impact, uint256 buffer, uint256 outstandingLimit) private pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`age`|`uint256`|Maximum source age in seconds.|
|`impact`|`uint256`|Maximum total execution impact in bps.|
|`buffer`|`uint256`|Execution-rate buffer in bps.|
|`outstandingLimit`|`uint256`|Unacknowledged EUR limit in 18 decimals.|


### publish

Publish strictly ordered book levels with the original exchange timestamp.

Uses the documented units and preserves reference-price accounting.

**Notes:**
- security: A newer observation cannot clear outstanding exposure or reset used depth prematurely.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: Applies the effects described above.

- events: Emits the events described above when applicable.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: Vault settlement is nonReentrant; publisher and reporter methods have no external state-changing callbacks.

- access: WRITER_ROLE only.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
function publish(uint256 sourceTime, Level[] calldata buy, Level[] calldata sell) external onlyRole(WRITER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sourceTime`|`uint256`|Source observation timestamp in seconds.|
|`buy`|`Level[]`|Asks ordered by ascending price.|
|`sell`|`Level[]`|Bids ordered by descending price.|


### acknowledge

Acknowledge all currently admitted exposure after canonical fills are reconciled.

Uses the documented units and preserves reference-price accounting.

**Notes:**
- security: Trusted reporter must reconcile fills and Base finality before calling; timestamps alone are not evidence.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: Applies the effects described above.

- events: Emits the events described above when applicable.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: Vault settlement is nonReentrant; publisher and reporter methods have no external state-changing callbacks.

- access: REPORTER_ROLE only.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
function acknowledge(uint256 buy, uint256 sell, uint256 capacity, uint256 sourceTime)
    external
    onlyRole(REPORTER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`buy`|`uint256`|Expected lifetime admitted buy quantity; rejects concurrent consumption.|
|`sell`|`uint256`|Expected lifetime admitted sell quantity; rejects concurrent consumption.|
|`capacity`|`uint256`|Additional EUR capacity supported by currently available venue margin.|
|`sourceTime`|`uint256`|Original account observation time in seconds.|


### reconcileAdmission

Reconcile admitted exposure during a governance-controlled pause.

Invalidates all reports; new depth and capacity must be observed after reconciliation.

**Notes:**
- security: Governance must verify venue settlement before reconciling.

- validation: Requires the immutable vault to be paused.

- state-changes: Advances cursors and clears depth and capacity.

- events: AdmissionReconciled.

- errors: InvalidCondition if settlement is not paused.

- reentrancy: Only a view call to the vault.

- access: DEFAULT_ADMIN_ROLE.

- oracle: Fresh reports required before further admission.


```solidity
function reconcileAdmission() external onlyRole(DEFAULT_ADMIN_ROLE);
```

### pendingExposure

Pending buy, sell, gross and absolute net exposure in QEURO units.

Net exposure is informational; opposite admissions do not release gross capacity.

**Notes:**
- security: Read only.

- validation: Cursors cannot exceed admission totals.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: None.

- access: Public.

- oracle: None.


```solidity
function pendingExposure() public view returns (uint256 buy, uint256 sell, uint256 gross, uint256 net);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`buy`|`uint256`|Unacknowledged buy quantity.|
|`sell`|`uint256`|Unacknowledged sell quantity.|
|`gross`|`uint256`|Sum of pending quantities.|
|`net`|`uint256`|Absolute difference of pending quantities.|


### outstanding

Unacknowledged exposure across both directions, without speculative netting.

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
function outstanding() public view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|result Calculated result in the units described by this operation.|


### availableCapacity

Remaining executable EUR capacity on each side, including outstanding exposure limits.

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
function availableCapacity() external view returns (uint256 buy, uint256 sell);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`buy`|`uint256`|Buy capacity in 18-decimal EUR units.|
|`sell`|`uint256`|Sell capacity in 18-decimal EUR units.|


### previewMint

Exact-USDC-input mint preview, after the vault's protocol fee.

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
function previewMint(uint256 usdcInput) external view returns (Quote memory quote);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcInput`|`uint256`|Value supplied to this operation.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`quote`|`Quote`|Calculated result in the units described by this operation.|


### previewRedeem

Exact-QEURO-input normal-redemption preview, after the reference-valued protocol fee.

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
function previewRedeem(uint256 qeuroInput) external view returns (Quote memory quote);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroInput`|`uint256`|Value supplied to this operation.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`quote`|`Quote`|Calculated result in the units described by this operation.|


### consumeMint

Consume buy liquidity and return minted quantity and reference backing.

Uses the documented units and preserves reference-price accounting.

**Notes:**
- security: Uses explicit contract access boundaries and checked arithmetic.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: Updates consumed liquidity counters.

- events: LiquidityConsumed.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: Vault settlement is nonReentrant; publisher and reporter methods have no external state-changing callbacks.

- access: Configured vault only.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
function consumeMint(uint256 netUsdc, uint256 ref) external override returns (uint256 q, uint256 backing);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`netUsdc`|`uint256`|Net USDC input in 6 decimals.|
|`ref`|`uint256`|Reference USD per EUR price in 18 decimals.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`q`|`uint256`|Calculated result in the units described by this operation.|
|`backing`|`uint256`|Calculated result in the units described by this operation.|


### consumeRedeem

Consume sell liquidity and return the execution-valued payout.

Uses the documented units and preserves reference-price accounting.

**Notes:**
- security: Uses explicit contract access boundaries and checked arithmetic.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: Updates consumed liquidity counters.

- events: LiquidityConsumed.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: Vault settlement is nonReentrant; publisher and reporter methods have no external state-changing callbacks.

- access: Configured vault only.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
function consumeRedeem(uint256 q, uint256 ref) external override returns (uint256 payout);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`q`|`uint256`|QEURO quantity in 18 decimals.|
|`ref`|`uint256`|Reference USD per EUR price in 18 decimals.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`payout`|`uint256`|Calculated result in the units described by this operation.|


### withdrawReserve

Transfer collected execution spreads to the immutable hedge reserve recipient.

Uses the documented units and preserves reference-price accounting.

**Notes:**
- security: Governance cannot redirect the reserve to an arbitrary recipient.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: Applies the effects described above.

- events: Emits the events described above when applicable.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: Vault settlement is nonReentrant; publisher and reporter methods have no external state-changing callbacks.

- access: DEFAULT_ADMIN_ROLE only.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
function withdrawReserve(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|USDC amount in 6 decimals.|


### _checkLevels

Validate nonzero strictly ordered executable book levels.

Uses the documented units and preserves reference-price accounting.

**Notes:**
- security: Uses explicit contract access boundaries and checked arithmetic.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: None.

- events: None.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: No state changes.

- access: Private helper.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
function _checkLevels(Level[] calldata levels, bool buy) private pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`levels`|`Level[]`|Ordered executable price and quantity levels.|
|`buy`|`bool`|True for the buy side, false for the sell side.|


### _reference

Read a valid reference price for execution previews.

Uses the documented units and preserves reference-price accounting.

**Notes:**
- security: Uses explicit contract access boundaries and checked arithmetic.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: None.

- events: None.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: No state changes.

- access: Private helper.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
function _reference() private view returns (uint256 ref);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ref`|`uint256`|Calculated result in the units described by this operation.|


### _validate

Validate reference coherence, venue and observation freshness.

Uses the documented units and preserves reference-price accounting.

**Notes:**
- security: Uses explicit contract access boundaries and checked arithmetic.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: None.

- events: None.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: No state changes.

- access: Private helper.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
function _validate(uint256 ref) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ref`|`uint256`|Reference USD per EUR price in 18 decimals.|


### _bookCanExecuteRedeem

Checks whether published depth can price this redemption.

Missing capacity allows reference fallback; coherent fresh venue books must stay in bounds.

**Notes:**
- security: Fresh divergent venue prices fail closed.

- validation: Requires nonzero reference and quantity.

- state-changes: None.

- events: None.

- errors: InvalidAmount or InvalidPrice.

- reentrancy: Read-only router calls.

- access: Private.

- oracle: Uses the validated reference supplied by the vault.


```solidity
function _bookCanExecuteRedeem(uint256 q, uint256 ref) private view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`q`|`uint256`|Requested QEURO quantity.|
|`ref`|`uint256`|Validated reference price.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the normal book path can execute.|


### _degradedPayout

Applies the configured haircut to a reference redemption.

Rounds the payout down in USDC units.

**Notes:**
- security: Cannot pay more than reference backing.

- validation: Rejects zero payout.

- state-changes: None.

- events: None.

- errors: InvalidAmount.

- reentrancy: None.

- access: Private.

- oracle: Caller validates reference.


```solidity
function _degradedPayout(uint256 q, uint256 ref) private view returns (uint256 payout);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`q`|`uint256`|QEURO input.|
|`ref`|`uint256`|Validated EUR/USD price.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`payout`|`uint256`|Payout before protocol fees.|


### _degradedHaircut

Returns the fallback haircut for the current observation state.

Fresh depth exhaustion uses at least the maximum book impact, preventing a better fallback quote.

**Notes:**
- security: A fresh book cannot be bypassed for a better execution rate.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: None.

- access: Private.

- oracle: Uses publication age only.


```solidity
function _degradedHaircut() private view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Haircut in basis points.|


### _rate

Calculate a conservative per-level execution rate.

Uses the documented units and preserves reference-price accounting.

**Notes:**
- security: Uses explicit contract access boundaries and checked arithmetic.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: None.

- events: None.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: No state changes.

- access: Private helper.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
function _rate(uint256 price, bool buy, uint256 ref) private view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|USD per EUR price in 18 decimals.|
|`buy`|`bool`|True for the buy side, false for the sell side.|
|`ref`|`uint256`|Reference USD per EUR price in 18 decimals.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|result Calculated result in the units described by this operation.|


### _capacity

Calculate remaining admitted capacity at the configured price limit.

Uses the documented units and preserves reference-price accounting.

**Notes:**
- security: Uses explicit contract access boundaries and checked arithmetic.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: None.

- events: None.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: No state changes.

- access: Private helper.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
function _capacity(bool buy, uint256 ref) private view returns (uint256 capacity);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`buy`|`bool`|True for the buy side, false for the sell side.|
|`ref`|`uint256`|Reference USD per EUR price in 18 decimals.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`capacity`|`uint256`|Calculated result in the units described by this operation.|


### _admissionRoom

Returns remaining net admission room for one execution side.

Opposite pending exposure may be offset before reaching the configured directional limit.

**Notes:**
- security: Applies the governance and reporter capacity ceilings to every admission path.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: None.

- access: Private helper.

- oracle: Uses the last reported margin capacity, including during degraded execution.


```solidity
function _admissionRoom(bool buy) private view returns (uint256 sideRoom);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`buy`|`bool`|True for buy-side admission, false for sell-side admission.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`sideRoom`|`uint256`|Remaining quantity that can be admitted on the selected side.|


### _mint

Invert cumulative buy cost for an exact USDC input.

Uses the documented units and preserves reference-price accounting.

**Notes:**
- security: Uses explicit contract access boundaries and checked arithmetic.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: None.

- events: None.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: No state changes.

- access: Private helper.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
function _mint(uint256 budget, uint256 ref) private view returns (uint256 q, uint256 backing);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`budget`|`uint256`|Net USDC input in 6 decimals.|
|`ref`|`uint256`|Reference USD per EUR price in 18 decimals.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`q`|`uint256`|Calculated result in the units described by this operation.|
|`backing`|`uint256`|Calculated result in the units described by this operation.|


### _redeem

Calculate cumulative sell proceeds for a QEURO input.

Uses the documented units and preserves reference-price accounting.

**Notes:**
- security: Uses explicit contract access boundaries and checked arithmetic.

- validation: Validates the documented preconditions; view interface reads delegate to the target contract.

- state-changes: None.

- events: None.

- errors: Propagates invalid input, freshness, capacity or downstream contract errors as applicable.

- reentrancy: No state changes.

- access: Private helper.

- oracle: Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.


```solidity
function _redeem(uint256 q, uint256 ref) private view returns (uint256 payout);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`q`|`uint256`|QEURO quantity in 18 decimals.|
|`ref`|`uint256`|Reference USD per EUR price in 18 decimals.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`payout`|`uint256`|Calculated result in the units described by this operation.|


## Events
### BookPublished

```solidity
event BookPublished(uint256 indexed sequence, uint256 observedAt, uint256 usedBuy, uint256 usedSell);
```

### LiquidityConsumed

```solidity
event LiquidityConsumed(
    bool indexed mint,
    uint256 quantity,
    uint256 referencePrice,
    uint256 executionUsdc,
    uint256 admittedBuy,
    uint256 admittedSell
);
```

### HedgeAcknowledged

```solidity
event HedgeAcknowledged(uint256 admittedBuy, uint256 admittedSell, uint256 capacity, uint256 observedAt);
```

### ReserveWithdrawn

```solidity
event ReserveWithdrawn(address indexed recipient, uint256 amount);
```

### RiskLimitsUpdated

```solidity
event RiskLimitsUpdated(uint256 maxAge, uint256 maxImpactBps, uint256 bufferBps, uint256 maxOutstanding);
```

### AdmissionReconciled

```solidity
event AdmissionReconciled(uint256 admittedBuy, uint256 admittedSell);
```

### DegradedHaircutUpdated

```solidity
event DegradedHaircutUpdated(uint256 previousBps, uint256 newBps);
```

### DegradedRedemption

```solidity
event DegradedRedemption(uint256 quantity, uint256 referencePrice, uint256 payout, uint256 haircutBps);
```

## Structs
### Level
A price level with USD/EUR price and EUR quantity, both in 18 decimals.


```solidity
struct Level {
    uint128 price;
    uint128 quantity;
}
```

### Quote
Contract preview, including user output after protocol fees.


```solidity
struct Quote {
    uint256 amountOut;
    uint256 executionRate;
    uint256 referenceRate;
    uint256 capacityQeuro;
    uint256 observedAt;
    uint256 sequence;
}
```
