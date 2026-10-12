# HedgerPoolMigrationLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/54366a1075ba6db39540a3d83709a310c26d1723/src/libraries/HedgerPoolMigrationLibrary.sol)

**Title:**
HedgerPoolMigrationLibrary

Three-party ownership transfer preserving the live single-hedger position.

Linked library operating in the pool's storage through delegatecall. Proposal state
occupies a dedicated hashed namespace; existing HedgerPool slots are unchanged.


## Constants
### STORAGE_SLOT

```solidity
bytes32 private constant STORAGE_SLOT = keccak256("quantillon.storage.HedgerMigration.v1")
```


## Functions
### version

Reports the first release of the migration library.

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


### proposal

Returns the current migration proposal, or an empty proposal after completion/cancellation.

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
function proposal() external view returns (Proposal memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Proposal`|pending Current proposal or a zeroed struct.|


### manage

Proposes, accepts, executes or cancels a transfer using the caller's distinct authority.

Moves pool rewards and their accrual timestamp; external YieldShift entitlements
remain with their original beneficiary and remain directly claimable at YieldShift.

**Notes:**
- security: Enforces owner proposal, recipient acceptance and paused governance execution.

- validation: Binds chain, pool, nonce, parties, expiry and position; rejects dirty recipients.

- state-changes: Changes proposal state or transfers ownership, rewards, clocks and escrow atomically.

- events: HedgerMigrationProposed, HedgerMigrationAccepted, HedgerMigrationCancelled, HedgerMigrationExecuted, SingleHedgerRotationApplied.

- errors: MigrationUnauthorized, InvalidMigration, MigrationExpired, MigrationNotAccepted, RecipientHasHedgerState, MigrationRequiresPause.

- reentrancy: Called from nonReentrant pool wrapper; no external calls.

- access: Linked library invoked by HedgerPool through delegatecall.

- oracle: No oracle lookup; prices, where present, are supplied by the caller.


```solidity
function manage(
    Request calldata request,
    address singleHedger,
    bool governance,
    bool paused,
    HedgerPool.HedgePosition storage position,
    mapping(address => HedgerPool.HedgerRewardState) storage rewards,
    mapping(address => uint256) storage activePositions,
    mapping(address => uint256) storage rewardTimes,
    mapping(address => uint256) storage pendingWithdrawals
) external returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`request`|`Request`|Action and exact proposal fields.|
|`singleHedger`|`address`|Current configured hedger.|
|`governance`|`bool`|Whether caller holds governance role.|
|`paused`|`bool`|Whether the pool is paused.|
|`position`|`HedgerPool.HedgePosition`|Active single position storage.|
|`rewards`|`mapping(address => HedgerPool.HedgerRewardState)`|Per-hedger reward state.|
|`activePositions`|`mapping(address => uint256)`|Per-hedger active position IDs.|
|`rewardTimes`|`mapping(address => uint256)`|Per-hedger accrual clocks.|
|`pendingWithdrawals`|`mapping(address => uint256)`|Per-hedger withdrawal escrow.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|hedger Configured hedger after this action.|


### invalidate

Invalidates consent whenever the active position closes, including same-block reopenings.

Called by the pool's common position finalization path.

**Notes:**
- security: Revokes prior consent when a position closes.

- validation: No-op without a pending proposal.

- state-changes: Deletes the current proposal, preserving the nonce.

- events: HedgerMigrationCancelled when a proposal existed.

- errors: None.

- reentrancy: No external calls.

- access: Linked library invoked by HedgerPool through delegatecall.

- oracle: No oracle lookup; prices, where present, are supplied by the caller.


```solidity
function invalidate() external;
```

### _state

Returns the dedicated migration storage namespace.

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
function _state() private pure returns (State storage state);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`state`|`State`|Namespaced migration state storage pointer.|


## Events
### HedgerMigrationProposed

```solidity
event HedgerMigrationProposed(
    bytes32 indexed proposalId, address indexed previousHedger, address indexed newHedger, uint64 expiresAt
);
```

### HedgerMigrationAccepted

```solidity
event HedgerMigrationAccepted(bytes32 indexed proposalId);
```

### HedgerMigrationCancelled

```solidity
event HedgerMigrationCancelled(bytes32 indexed proposalId);
```

### HedgerMigrationExecuted

```solidity
event HedgerMigrationExecuted(
    bytes32 indexed proposalId, address indexed previousHedger, address indexed newHedger
);
```

### SingleHedgerRotationApplied

```solidity
event SingleHedgerRotationApplied(address indexed previousHedger, address indexed newHedger);
```

## Errors
### MigrationUnauthorized

```solidity
error MigrationUnauthorized();
```

### InvalidMigration

```solidity
error InvalidMigration();
```

### MigrationExpired

```solidity
error MigrationExpired();
```

### MigrationNotAccepted

```solidity
error MigrationNotAccepted();
```

### RecipientHasHedgerState

```solidity
error RecipientHasHedgerState();
```

### MigrationRequiresPause

```solidity
error MigrationRequiresPause();
```

## Structs
### Request

```solidity
struct Request {
    Action action;
    address newHedger;
    uint64 expiresAt;
    bytes32 proposalId;
}
```

### Proposal

```solidity
struct Proposal {
    bytes32 id;
    address previousHedger;
    address newHedger;
    uint64 expiresAt;
    uint64 openBlock;
    bool accepted;
}
```

### State

```solidity
struct State {
    uint256 nonce;
    Proposal proposal;
}
```

## Enums
### Action

```solidity
enum Action {
    Propose,
    Accept,
    Execute,
    Cancel
}
```
