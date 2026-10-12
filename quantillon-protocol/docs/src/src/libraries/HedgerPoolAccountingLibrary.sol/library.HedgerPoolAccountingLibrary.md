# HedgerPoolAccountingLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/54366a1075ba6db39540a3d83709a310c26d1723/src/libraries/HedgerPoolAccountingLibrary.sol)

**Title:**
HedgerPoolAccountingLibrary

Existing pool accounting extracted to keep HedgerPool deployable.

Delegatecalled with explicit storage references; correction replay protection uses a dedicated hashed namespace.


## Constants
### LEGACY_CORRECTION_SLOT

```solidity
bytes32 private constant LEGACY_CORRECTION_SLOT = keccak256("quantillon.storage.LegacyMarginCorrection.20260701")
```


### LEGACY_CORRECTION_ID

```solidity
bytes32 private constant LEGACY_CORRECTION_ID = keccak256("base:48054036:hedger-profit:388448")
```


### LEGACY_POOL

```solidity
address private constant LEGACY_POOL = 0xff5D7cE5c7671B2EA805Ee752B4f8eC9Ecf2975A
```


### LEGACY_SAFE

```solidity
address private constant LEGACY_SAFE = 0x1d7fF432a93d0085Fb69474c7E567f859829e6cd
```


### LEGACY_CREDIT

```solidity
uint256 private constant LEGACY_CREDIT = 388448
```


## Functions
### routeFee

Routes collected fees between the reward reserve and collector.

Reserve amounts remain in the calling pool.

**Notes:**
- security: Caller validates the configured split and recipient.

- validation: A zero fee is a no-op.

- state-changes: Transfers the collector portion and updates allowance.

- events: RewardReserveFunded and collector events.

- errors: Propagates token and collector failures.

- reentrancy: Calling pool holds its reentrancy guard.

- access: Linked library.

- oracle: None.


```solidity
function routeFee(
    IERC20 usdc,
    address collector,
    uint256 split,
    address funder,
    uint256 fee,
    string memory sourceType
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdc`|`IERC20`|Collateral token.|
|`collector`|`address`|Fee collector address.|
|`split`|`uint256`|Reserve fraction scaled by 1e18.|
|`funder`|`address`|Account credited with funding the reserve.|
|`fee`|`uint256`|Collected fee in USDC units.|
|`sourceType`|`string`|Collector accounting category.|


### assignSingleHedger

Assigns the configured owner with the existing inactive-position restriction.

Extracted unchanged to preserve EIP-170 headroom for the correction entry point.

**Notes:**
- security: Helper enforces the existing governance role.

- validation: Nonzero recipient and no active position when replacing an owner.

- state-changes: None; wrapper stores returned owner.

- events: SingleHedgerRotationApplied.

- errors: InvalidAddress, HedgerHasActivePosition.

- reentrancy: No external calls.

- access: Linked library only.

- oracle: No oracle dependency.


```solidity
function assignSingleHedger(HedgerPool.HedgePosition storage position, address next) external returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`position`|`HedgerPool.HedgePosition`|Fixed position one, used only to read its active flag.|
|`next`|`address`|Requested owner.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Configured owner after assignment.|


### correctLegacyMargin

Reclassifies exactly the verified historical residue as current Safe margin once.

No deposit, withdrawal, mint, cost-basis change or realized-PnL adjustment occurs.
Exact surplus and opening-block checks reject drift or reuse for another position.

**Notes:**
- security: Fixed chain/pool/owner/position and governance, pause and replay guards.

- validation: Verifies global totals, supply/backing dust and exact existing surplus.

- state-changes: Updates margin, position size and namespaced one-time marker.

- events: LegacyMarginCorrected.

- errors: LegacyCorrectionUnauthorized, LegacyCorrectionStateMismatch, LegacyCorrectionAlreadyApplied.

- reentrancy: Pool wrapper is nonReentrant; external calls are static reads.

- access: Linked library invoked by the fixed Base pool through delegatecall.

- oracle: Independent of oracle price and cached valuation.


```solidity
function correctLegacyMargin(HedgerPool.HedgePosition storage position)
    external
    returns (uint256 nextTotalMargin, uint256 nextTotalExposure);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`position`|`HedgerPool.HedgePosition`|The pool's fixed active position one.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`nextTotalMargin`|`uint256`|Global margin after correction.|
|`nextTotalExposure`|`uint256`|Global nominal exposure after correction.|


### validateClosure

Preserves the pool's existing restriction on closing while users remain exposed.

Extracted unchanged; bounded QEURO dust is treated as an empty supply.

**Notes:**
- security: Read-only closure guard.

- validation: Requires sufficient remaining hedger margin when QEURO is outstanding.

- state-changes: None.

- events: None.

- errors: PositionClosureRestricted.

- reentrancy: External static reads only.

- access: Linked library invoked by HedgerPool.

- oracle: No price dependency.


```solidity
function validateClosure(IQuantillonVault vault, uint256 positionMargin) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`IQuantillonVault`|Configured vault.|
|`positionMargin`|`uint256`|Closing position's recorded margin.|


### configure

Validates and applies the existing risk and fee configuration.

Scalar settings outside CoreParams remain assigned by the pool.

**Notes:**
- security: Pool wrappers enforce caller authority and storage references.

- validation: Uses the pool's existing validation rules.

- state-changes: Updates only the explicitly supplied accounting storage.

- events: None.

- errors: Propagates accounting, validation and trusted integration errors.

- reentrancy: State-changing pool wrappers are nonReentrant except governance configuration.

- access: Linked library invoked by HedgerPool through delegatecall.

- oracle: No oracle lookup; prices, where present, are supplied by the caller.


```solidity
function configure(
    HedgerPool.CoreParams storage params,
    HedgerPool.HedgerRiskConfig calldata cfg,
    HedgerPool.HedgePosition storage position
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params`|`HedgerPool.CoreParams`|Pool core parameters in storage.|
|`cfg`|`HedgerPool.HedgerRiskConfig`|Requested complete risk and fee configuration.|
|`position`|`HedgerPool.HedgePosition`|Active position used to bound the margin-ratio setting.|


### effectiveCollateral

Values the active position using remaining cost and the caller's price.

Floors negative effective collateral at zero; realized history is already in margin.

**Notes:**
- security: Read-only helper.

- validation: No input validation required unless described above.

- state-changes: None.

- events: None.

- errors: None beyond checked arithmetic.

- reentrancy: No state-changing external calls.

- access: Linked library helper.

- oracle: No oracle lookup.


```solidity
function effectiveCollateral(HedgerPool.HedgePosition storage position, uint256 price)
    external
    view
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`position`|`HedgerPool.HedgePosition`|Active position storage.|
|`price`|`uint256`|EUR/USD price with 18 decimals.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|collateral Effective USDC collateral, floored at zero.|


### version

Reports the initial library release.

Uses no additional sequential storage slots.

**Notes:**
- security: Read-only helper.

- validation: No input validation required unless described above.

- state-changes: None.

- events: None.

- errors: None beyond checked arithmetic.

- reentrancy: No state-changing external calls.

- access: Linked library helper.

- oracle: No oracle lookup.


```solidity
function version() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|release Semantic version string.|


### checkpoint

Books interest earned up to the current exposure change.

Checkpointing before every exposure mutation prevents a later, larger
exposure from being applied retroactively to an earlier accrual period.

**Notes:**
- security: Uses only explicitly supplied storage and accounting inputs.

- validation: Rejects reward overflow through the shared error library.

- state-changes: Updates the hedger's pending reward and accrual clock.

- events: None.

- errors: RewardOverflow on uint128 overflow.

- reentrancy: No external calls.

- access: Linked library invoked by HedgerPool.

- oracle: No oracle dependency.


```solidity
function checkpoint(
    HedgerPool.HedgerRewardState storage rewardState,
    mapping(address => uint256) storage rewardTimes,
    HedgerPool.CoreParams storage params,
    uint256 totalExposure,
    uint256 currentTime,
    uint256 maxRewardPeriod,
    address hedger
) external returns (uint256 pendingRewards);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardState`|`HedgerPool.HedgerRewardState`|Hedger reward state.|
|`rewardTimes`|`mapping(address => uint256)`|Per-hedger accrual clocks.|
|`params`|`HedgerPool.CoreParams`|Pool interest-rate configuration.|
|`totalExposure`|`uint256`|Exposure that was active during the elapsed period.|
|`currentTime`|`uint256`|Canonical protocol time.|
|`maxRewardPeriod`|`uint256`|Maximum accrual duration.|
|`hedger`|`address`|Hedger whose clock is being checkpointed.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`pendingRewards`|`uint256`|Updated pending interest reward.|


### claim

Accrues interest into withdrawal escrow and claims external yield.

Preserves the pool's legacy-clock migration, narrowing casts and pull settlement.

**Notes:**
- security: Pool wrappers enforce caller authority and storage references.

- validation: Uses the pool's existing validation rules.

- state-changes: Updates only the explicitly supplied accounting storage.

- events: None.

- errors: Propagates accounting, validation and trusted integration errors.

- reentrancy: State-changing pool wrappers are nonReentrant except governance configuration.

- access: Linked library invoked by HedgerPool through delegatecall.

- oracle: No oracle lookup; prices, where present, are supplied by the caller.


```solidity
function claim(
    HedgerPool.HedgerRewardState storage rewardState,
    mapping(address => uint256) storage rewardTimes,
    mapping(address => uint256) storage pendingWithdrawals,
    HedgerPool.CoreParams storage params,
    uint256 totalExposure,
    uint256 currentTime,
    uint256 maxRewardPeriod,
    IYieldShift yieldShift
) external returns (uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardState`|`HedgerPool.HedgerRewardState`|Current hedger reward state.|
|`rewardTimes`|`mapping(address => uint256)`|Per-hedger accrual clocks.|
|`pendingWithdrawals`|`mapping(address => uint256)`|Per-hedger withdrawal escrow.|
|`params`|`HedgerPool.CoreParams`|Pool interest rate configuration.|
|`totalExposure`|`uint256`|Pool notional exposure.|
|`currentTime`|`uint256`|Canonical protocol time.|
|`maxRewardPeriod`|`uint256`|Maximum accrual duration.|
|`yieldShift`|`IYieldShift`|Trusted yield distributor.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`interestDifferential`|`uint256`|Interest queued for withdrawal.|
|`yieldShiftRewards`|`uint256`|Yield paid by YieldShift.|
|`totalRewards`|`uint256`|Sum of both reward sources.|


### withdraw

Pays the caller's funded escrow balance to their chosen recipient.

Leaves any unfunded remainder available for a later withdrawal.

**Notes:**
- security: Pool wrappers enforce caller authority and storage references.

- validation: Uses the pool's existing validation rules.

- state-changes: Reduces caller escrow by funded amount and transfers USDC.

- events: None.

- errors: Propagates accounting, validation and trusted integration errors.

- reentrancy: Invoked from the nonReentrant withdrawal wrapper.

- access: Linked library invoked by HedgerPool through delegatecall.

- oracle: No oracle lookup; prices, where present, are supplied by the caller.


```solidity
function withdraw(mapping(address => uint256) storage pendingWithdrawals, IERC20 usdc, address recipient) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pendingWithdrawals`|`mapping(address => uint256)`|Per-hedger withdrawal escrow.|
|`usdc`|`IERC20`|Pool collateral token.|
|`recipient`|`address`|Caller-selected payout recipient.|


### applyMarginTransition

Applies realized profit or loss to margin and notional exposure.

Keeps aggregate exposure aligned with the resulting position size.

**Notes:**
- security: Caller checkpoints rewards before changing exposure.

- validation: Shared math validates position bounds.

- state-changes: Updates position margin and size.

- events: None.

- errors: Propagates checked arithmetic errors.

- reentrancy: No external state-changing calls.

- access: Linked library.

- oracle: Caller supplies settled profit or loss.


```solidity
function applyMarginTransition(
    HedgerPool.HedgePosition storage pos,
    uint256 totalMargin,
    uint256 totalExposure,
    int256 realizedDelta
) external returns (uint256 nextMargin, uint256 nextExposure);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pos`|`HedgerPool.HedgePosition`|Position to update.|
|`totalMargin`|`uint256`|Aggregate margin before the transition.|
|`totalExposure`|`uint256`|Aggregate exposure before the transition.|
|`realizedDelta`|`int256`|Realized USDC profit or loss.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`nextMargin`|`uint256`|Aggregate margin after settlement.|
|`nextExposure`|`uint256`|Aggregate exposure after settlement.|


## Events
### LegacyMarginCorrected

```solidity
event LegacyMarginCorrected(bytes32 indexed correctionId, address indexed hedger, uint256 amount);
```

### SingleHedgerRotationApplied

```solidity
event SingleHedgerRotationApplied(address indexed previousHedger, address indexed newHedger);
```

### RewardReserveFunded

```solidity
event RewardReserveFunded(address indexed funder, uint256 amount);
```

## Errors
### LegacyCorrectionUnauthorized

```solidity
error LegacyCorrectionUnauthorized();
```

### LegacyCorrectionStateMismatch

```solidity
error LegacyCorrectionStateMismatch();
```

### LegacyCorrectionAlreadyApplied

```solidity
error LegacyCorrectionAlreadyApplied();
```
