# ReportPublicationBatcher
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/54366a1075ba6db39540a3d83709a310c26d1723/src/oracle/ReportPublicationBatcher.sol)

**Inherits:**
[IVersioned](/src/interfaces/IVersioned.sol/interface.IVersioned.md)

**Title:**
ReportPublicationBatcher

Publishes any combination of market price, depth and reconciled capacity.

Fixed destinations and selectors. Reports fail independently; target events
determine accepted data, since a successful price call can skip a source.

**Notes:**
- security: Only the immutable writer can publish. Each subcall has a fixed
gas budget, reserved before execution so estimation cannot starve later reports.

- security-contact: team@quantillon.money


## Constants
### writer
Authorized publisher account.


```solidity
address public immutable writer
```


### priceStore
Market summary storage.


```solidity
address public immutable priceStore
```


### depthStore
Execution depth and hedge capacity storage.


```solidity
address public immutable depthStore
```


### PRICE_GAS
Upper gas allocation for at most two market sources.


```solidity
uint256 public constant PRICE_GAS = 200_000
```


### DEPTH_GAS
Allocation covers the publisher's ten levels per side, including cold storage.


```solidity
uint256 public constant DEPTH_GAS = 1_100_000
```


### CAPACITY_GAS
Upper gas allocation for a capacity acknowledgment.


```solidity
uint256 public constant CAPACITY_GAS = 150_000
```


### PRICE_SELECTOR

```solidity
bytes4 private constant PRICE_SELECTOR =
    bytes4(keccak256("updateSlippageBatch((uint8,uint128,uint128,uint16,uint16,uint16[5])[])"))
```


### DEPTH_SELECTOR

```solidity
bytes4 private constant DEPTH_SELECTOR =
    bytes4(keccak256("publish(uint256,(uint128,uint128)[],(uint128,uint128)[])"))
```


### CAPACITY_SELECTOR

```solidity
bytes4 private constant CAPACITY_SELECTOR = bytes4(keccak256("acknowledge(uint256,uint256,uint256,uint256)"))
```


## State Variables
### lastPublicationAt
Block time of the last batch with a successful destination call.


```solidity
uint256 public lastPublicationAt
```


## Functions
### constructor

Set permanent publisher and target addresses.

Constructor wiring is immutable and rejects overlapping publisher and destination addresses.

**Notes:**
- security: No role grants or arbitrary targets are exposed.

- validation: Rejects zero, non-contract, or overlapping addresses.

- state-changes: Stores immutable writer and destination addresses.

- events: None.

- errors: InvalidAddress for invalid wiring.

- reentrancy: No external calls.

- access: Deployment only.

- oracle: None.


```solidity
constructor(address publisher, address price, address depth) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`publisher`|`address`|Publisher account, distinct from both destinations.|
|`price`|`address`|Deployed price storage.|
|`depth`|`address`|Deployed execution pricing contract.|


### publishReports

Submit one, two or three independently validated reports.

Price then depth then capacity preserves the existing combined-publication order.
Capacity never resets consumed depth; a later fresh book applies the target's rules.

**Notes:**
- security: Rejects invalid selectors before any effects. Reverting reports do not
undo valid reports. All-failed batches revert so preflight estimation rejects them.

- validation: Requires at least one supported call and enough gas for the selected reports.

- state-changes: Updates successful target reports and the publication timestamp.

- events: Emits ReportsPublished and ReportRejected for failed subcalls.

- errors: NotAuthorized, InvalidParameter, InsufficientReportGas, or NoSuccessfulReports.

- reentrancy: Uses bounded low-level calls to immutable targets.

- access: Restricted to the immutable writer.

- oracle: Reads no oracle directly; forwards validated report calls.


```solidity
function publishReports(bytes calldata priceCall, bytes calldata depthCall, bytes calldata capacityCall)
    external
    returns (uint8 succeeded);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`priceCall`|`bytes`|Encoded updateSlippageBatch, or empty to omit.|
|`depthCall`|`bytes`|Encoded publish, or empty to omit.|
|`capacityCall`|`bytes`|Encoded acknowledge, or empty to omit.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`succeeded`|`uint8`|Destination-call success mask; inspect target events for accepted reports.|


### _selector


```solidity
function _selector(bytes calldata data, bytes4 expected) private pure;
```

### _call


```solidity
function _call(address target, bytes calldata data, uint256 budget, uint8 report) private returns (bool ok);
```

### version

Semantic version of this separately deployed, non-upgradeable contract.

The value is embedded in bytecode for release traceability.

**Notes:**
- security: No security implications; this is a pure constant getter.

- validation: No input validation.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: None.


```solidity
function version() external pure override returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Semantic version string.|


## Events
### ReportsPublished
Masks use price=1, depth=2, capacity=4. Success denotes call success, not source acceptance.


```solidity
event ReportsPublished(uint8 attempted, uint8 succeeded);
```

### ReportRejected
First four revert bytes for a failed report; no unbounded return data is copied.


```solidity
event ReportRejected(uint8 indexed report, bytes4 reason);
```

## Errors
### InsufficientReportGas

```solidity
error InsufficientReportGas();
```

### NoSuccessfulReports

```solidity
error NoSuccessfulReports();
```
