# PublicationBatcher
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/54366a1075ba6db39540a3d83709a310c26d1723/src/oracle/PublicationBatcher.sol)

**Inherits:**
[IVersioned](/src/interfaces/IVersioned.sol/interface.IVersioned.md)

**Title:**
PublicationBatcher

Publishes market summaries and execution depth in one transaction.

Immutable, non-upgradeable forwarding contract. Existing target validation
and events are preserved, including SlippageStorage's per-source skips.
Governance must grant this contract WRITER_ROLE on both destinations.

**Notes:**
- security: Only the fixed writer can call the two fixed publication selectors.

- security-contact: team@quantillon.money


## Constants
### writer
Account authorized to submit combined publications.


```solidity
address public immutable writer
```


### priceStore
SlippageStorage destination for market summaries.


```solidity
address public immutable priceStore
```


### depthStore
ExecutionPricing destination for executable order books.


```solidity
address public immutable depthStore
```


### PRICE_SELECTOR
The sole allowed SlippageStorage entry point.


```solidity
bytes4 private constant PRICE_SELECTOR =
    bytes4(keccak256("updateSlippageBatch((uint8,uint128,uint128,uint16,uint16,uint16[5])[])"))
```


### DEPTH_SELECTOR
The sole allowed ExecutionPricing entry point.


```solidity
bytes4 private constant DEPTH_SELECTOR =
    bytes4(keccak256("publish(uint256,(uint128,uint128)[],(uint128,uint128)[])"))
```


## Functions
### constructor

Fix the writer and both publication destinations for this deployment.

The writer cannot be either destination, preventing target callbacks.

**Notes:**
- security: Targets must contain code and be distinct from the writer and each other.

- validation: Nonzero writer, deployed and distinct destinations.

- state-changes: Sets immutable deployment bindings.

- events: None.

- errors: InvalidAddress on invalid bindings.

- reentrancy: No external calls.

- access: Deployment only.

- oracle: No oracle reads.


```solidity
constructor(address publisher, address price, address depth) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`publisher`|`address`|Authorized publication account.|
|`price`|`address`|SlippageStorage contract.|
|`depth`|`address`|ExecutionPricing contract.|


### publishTogether

Forward both reports atomically, market summaries first.

Revert data is propagated unchanged. No ETH, delegatecall, generic calls
or role management is exposed. A target revert rolls back both calls;
a source silently skipped by SlippageStorage remains skipped.

**Notes:**
- security: Fixed caller, targets and selectors; callbacks from targets cannot reenter.

- validation: Caller and selectors here; report validation in each destination.

- state-changes: Updates destination reports; no local storage writes.

- events: Destination SlippageSourceUpdated and BookPublished events.

- errors: NotAuthorized, InvalidParameter, and unmodified destination errors.

- reentrancy: Target callbacks fail the immutable writer check.

- access: Only the immutable writer.

- oracle: Preserves both destinations' oracle and freshness validation.


```solidity
function publishTogether(bytes calldata priceCall, bytes calldata depthCall) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`priceCall`|`bytes`|ABI-encoded updateSlippageBatch call.|
|`depthCall`|`bytes`|ABI-encoded publish call.|


### version

Return the semantic version of this contract.

Compile-time constant for deployment provenance.

**Notes:**
- security: Read-only metadata.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: No external calls.

- access: Public.

- oracle: None.


```solidity
function version() external pure override returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Semantic version string.|
