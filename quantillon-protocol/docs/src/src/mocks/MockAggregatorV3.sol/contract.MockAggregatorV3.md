# MockAggregatorV3
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/02318f592f770a9d926016c8576b44854e674b9a/src/mocks/MockAggregatorV3.sol)

**Inherits:**
AggregatorV3Interface

**Title:**
MockAggregatorV3

Mock Chainlink price feed for testing

Implements AggregatorV3Interface with configurable behavior to simulate:
- Price updates with variable decimals
- Revert scenarios and invalid price outputs
- Stale timestamps and round progression

**Note:**
security-contact: team@quantillon.money


## State Variables
### price

```solidity
int256 public price
```


### decimals_

```solidity
uint8 public decimals_
```


### updatedAt

```solidity
uint256 public updatedAt
```


### shouldRevert

```solidity
bool public shouldRevert
```


### shouldReturnInvalidPrice

```solidity
bool public shouldReturnInvalidPrice
```


### roundId

```solidity
uint80 public roundId = 1
```


## Functions
### constructor

Constructor for MockPriceFeed

Mock function for testing purposes

**Notes:**
- security: No security validations - test mock

- validation: No input validation - test mock

- state-changes: Initializes decimals and updatedAt timestamp

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not protected - test mock

- access: Public - test mock

- oracle: No oracle dependencies


```solidity
constructor(uint8 _decimals) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_decimals`|`uint8`|The number of decimals for the price feed|


### setPrice

Sets the price for the mock price feed

Mock function for testing purposes

**Notes:**
- security: No security validations - test mock

- validation: No input validation - test mock

- state-changes: Updates price and increments roundId

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not protected - test mock

- access: Public - test mock

- oracle: No oracle dependencies


```solidity
function setPrice(int256 _price) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_price`|`int256`|The price to set|


### setShouldRevert

Sets whether the mock price feed should revert

Mock function for testing purposes

**Notes:**
- security: No security validations - test mock

- validation: No input validation - test mock

- state-changes: Updates shouldRevert flag

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not protected - test mock

- access: Public - test mock

- oracle: No oracle dependencies


```solidity
function setShouldRevert(bool _shouldRevert) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_shouldRevert`|`bool`|Whether the price feed should revert|


### setShouldReturnInvalidPrice

Sets whether the mock price feed should return invalid price

Mock function for testing purposes

**Notes:**
- security: No security validations - test mock

- validation: No input validation - test mock

- state-changes: Updates shouldReturnInvalidPrice flag

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not protected - test mock

- access: Public - test mock

- oracle: No oracle dependencies


```solidity
function setShouldReturnInvalidPrice(bool _shouldReturnInvalidPrice) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_shouldReturnInvalidPrice`|`bool`|Whether the price feed should return invalid price|


### setUpdatedAt

Sets the updated timestamp for the mock price feed

Test helper function to control price feed timestamps

**Notes:**
- security: No security implications - test helper function

- validation: No input validation required - test helper

- state-changes: Updates the updatedAt timestamp for testing

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not applicable - simple state update

- access: Public - no access restrictions

- oracle: No oracle dependency - mock function


```solidity
function setUpdatedAt(uint256 _updatedAt) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_updatedAt`|`uint256`|The timestamp to set as the last update time|


### latestRoundData

Returns the latest round data for the mock price feed

Mock implementation of Chainlink's latestRoundData function for testing

**Notes:**
- security: No security implications - test function

- validation: No input validation required - test function

- state-changes: No state changes - test function

- events: No events emitted - test function

- errors: No errors thrown - test function

- reentrancy: Not applicable - test function

- access: Public - no access restrictions

- oracle: No oracle dependency for test function


```solidity
function latestRoundData()
    external
    view
    returns (uint80 _roundId, int256 _answer, uint256 _startedAt, uint256 _updatedAt, uint80 _answeredInRound);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_roundId`|`uint80`|The round ID|
|`_answer`|`int256`|The price answer|
|`_startedAt`|`uint256`|The timestamp when the round started|
|`_updatedAt`|`uint256`|The timestamp when the round was last updated|
|`_answeredInRound`|`uint80`|The round ID in which the answer was computed|


### getRoundData

Gets round data for the mock price feed

Mock function for testing purposes

**Notes:**
- security: No security validations - test mock

- validation: No input validation - test mock

- state-changes: No state changes - view function

- events: No events emitted

- errors: Throws "MockAggregator: Simulated failure" if shouldRevert is true

- reentrancy: Not protected - test mock

- access: Public - test mock

- oracle: No oracle dependencies


```solidity
function getRoundData(
    uint80 /* _id */
)
    external
    view
    returns (uint80 _roundId, int256 _answer, uint256 _startedAt, uint256 _updatedAt, uint80 _answeredInRound);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_roundId`|`uint80`|The round ID|
|`_answer`|`int256`|The price answer|
|`_startedAt`|`uint256`|The timestamp when the round started|
|`_updatedAt`|`uint256`|The timestamp when the round was updated|
|`_answeredInRound`|`uint80`|The round ID when the answer was provided|


### decimals

Gets the number of decimals for the mock price feed

Mock function for testing purposes

**Notes:**
- security: No security validations - test mock

- validation: No input validation - test mock

- state-changes: No state changes - view function

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not protected - test mock

- access: Public - test mock

- oracle: No oracle dependencies


```solidity
function decimals() external view returns (uint8);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|The number of decimals|


### description

Gets the description of the mock price feed

Mock function for testing purposes

**Notes:**
- security: No security validations - test mock

- validation: No input validation - test mock

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not protected - test mock

- access: Public - test mock

- oracle: No oracle dependencies


```solidity
function description() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The description string|


### version

Gets the version of the mock price feed

Mock function for testing purposes

**Notes:**
- security: No security validations - test mock

- validation: No input validation - test mock

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not protected - test mock

- access: Public - test mock

- oracle: No oracle dependencies


```solidity
function version() external pure returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The version number|


