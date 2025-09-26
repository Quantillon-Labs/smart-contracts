# HedgerPoolOptimizationLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/486f19261aef0b99ac5330b56bb5ad5bbdda41eb/src/libraries/HedgerPoolOptimizationLibrary.sol)

**Author:**
Quantillon Labs

Library for HedgerPool data packing, validation, and utility functions

*Extracts utility functions from HedgerPool to reduce contract size*


## Functions
### packPositionOpenData

Packs position open data into a single bytes32 for gas efficiency

*Encodes position size, margin, leverage, and entry price into a compact format*

**Notes:**
- security: No security implications - pure data packing function

- validation: Input validation handled by calling contract

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No errors thrown - pure function

- reentrancy: Not applicable - pure function

- access: Public function

- oracle: No oracle dependencies


```solidity
function packPositionOpenData(uint256 positionSize, uint256 margin, uint256 leverage, uint256 entryPrice)
    external
    pure
    returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionSize`|`uint256`|Size of the position in USDC|
|`margin`|`uint256`|Margin amount for the position|
|`leverage`|`uint256`|Leverage multiplier for the position|
|`entryPrice`|`uint256`|Price at which the position was opened|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Packed data as bytes32|


### packPositionCloseData

Packs position close data into a single bytes32 for gas efficiency

*Encodes exit price, PnL, and timestamp into a compact format*

**Notes:**
- security: No security implications - pure data packing function

- validation: Input validation handled by calling contract

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No errors thrown - pure function

- reentrancy: Not applicable - pure function

- access: Public function

- oracle: No oracle dependencies


```solidity
function packPositionCloseData(uint256 exitPrice, int256 pnl, uint256 timestamp) external pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`exitPrice`|`uint256`|Price at which the position was closed|
|`pnl`|`int256`|Profit or loss from the position (can be negative)|
|`timestamp`|`uint256`|Timestamp when the position was closed|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Packed data as bytes32|


### packMarginData

Packs margin data into a single bytes32 for gas efficiency

*Encodes margin amount, new margin ratio, and operation type*

**Notes:**
- security: No security implications - pure data packing function

- validation: Input validation handled by calling contract

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No errors thrown - pure function

- reentrancy: Not applicable - pure function

- access: Public function

- oracle: No oracle dependencies


```solidity
function packMarginData(uint256 marginAmount, uint256 newMarginRatio, bool isAdded) external pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`marginAmount`|`uint256`|Amount of margin added or removed|
|`newMarginRatio`|`uint256`|New margin ratio after the operation|
|`isAdded`|`bool`|True if margin was added, false if removed|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Packed data as bytes32|


### packLiquidationData

Packs liquidation data into a single bytes32 for gas efficiency

*Encodes liquidation reward and remaining margin*

**Notes:**
- security: No security implications - pure data packing function

- validation: Input validation handled by calling contract

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No errors thrown - pure function

- reentrancy: Not applicable - pure function

- access: Public function

- oracle: No oracle dependencies


```solidity
function packLiquidationData(uint256 liquidationReward, uint256 remainingMargin) external pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`liquidationReward`|`uint256`|Reward paid to the liquidator|
|`remainingMargin`|`uint256`|Margin remaining after liquidation|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Packed data as bytes32|


### packRewardData

Packs reward data into a single bytes32 for gas efficiency

*Encodes interest differential, yield shift rewards, and total rewards*

**Notes:**
- security: No security implications - pure data packing function

- validation: Input validation handled by calling contract

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No errors thrown - pure function

- reentrancy: Not applicable - pure function

- access: Public function

- oracle: No oracle dependencies


```solidity
function packRewardData(uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards)
    external
    pure
    returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`interestDifferential`|`uint256`|Interest rate differential between EUR and USD|
|`yieldShiftRewards`|`uint256`|Rewards from yield shifting operations|
|`totalRewards`|`uint256`|Total rewards accumulated|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Packed data as bytes32|


### validateRole

Validates that the caller has the required role

*Internal function to check role-based access control*

**Notes:**
- security: Prevents unauthorized access to protected functions

- validation: Ensures proper role-based access control

- state-changes: No state changes - view function

- events: No events emitted

- errors: Throws NotAuthorized if caller lacks required role

- reentrancy: Not applicable - view function

- access: External function with role validation

- oracle: No oracle dependencies


```solidity
function validateRole(bytes32 role, address contractInstance) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to validate against|
|`contractInstance`|`address`|The contract instance to check roles on|


### validatePositionClosureSafety

Validates that closing a position won't cause protocol undercollateralization

*Checks if closing the position would make the protocol undercollateralized for QEURO minting*

**Notes:**
- security: Prevents protocol undercollateralization from position closures

- validation: Ensures protocol remains properly collateralized

- state-changes: No state changes - view function

- events: No events emitted

- errors: No errors thrown - returns boolean result

- reentrancy: Not applicable - view function

- access: External function

- oracle: No oracle dependencies


```solidity
function validatePositionClosureSafety(uint256 positionMargin, address vaultAddress)
    external
    view
    returns (bool isValid);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionMargin`|`uint256`|The margin amount of the position being closed|
|`vaultAddress`|`address`|Address of the vault contract|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isValid`|`bool`|True if position can be safely closed|


### removePositionFromArrays

Removes a position from the hedger's position arrays

*Internal function to maintain position tracking arrays*

**Notes:**
- security: Maintains data integrity of position tracking arrays

- validation: Ensures position exists before removal

- state-changes: Modifies storage mappings and arrays

- events: No events emitted

- errors: No errors thrown - returns boolean result

- reentrancy: Not applicable - no external calls

- access: External function

- oracle: No oracle dependencies


```solidity
function removePositionFromArrays(
    address hedger,
    uint256 positionId,
    mapping(address => mapping(uint256 => bool)) storage hedgerHasPosition,
    mapping(address => mapping(uint256 => uint256)) storage positionIndex,
    uint256[] storage positionIds
) external returns (bool success);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger whose position to remove|
|`positionId`|`uint256`|ID of the position to remove|
|`hedgerHasPosition`|`mapping(address => mapping(uint256 => bool))`|Mapping of hedger to position existence|
|`positionIndex`|`mapping(address => mapping(uint256 => uint256))`|Mapping of hedger to position index|
|`positionIds`|`uint256[]`|Array of position IDs for the hedger|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`success`|`bool`|True if position was successfully removed|


### getValidOraclePrice

Gets a valid EUR/USD price from the oracle

*Retrieves and validates price data from the oracle contract*

**Notes:**
- security: Ensures oracle price data is valid before use

- validation: Validates oracle response format and data

- state-changes: No state changes - view function

- events: No events emitted

- errors: No errors thrown - returns boolean result

- reentrancy: Not applicable - view function

- access: External function

- oracle: Depends on oracle contract for price data


```solidity
function getValidOraclePrice(address oracleAddress) external view returns (uint256 price, bool isValid);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oracleAddress`|`address`|Address of the oracle contract|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|Valid EUR/USD price from oracle|
|`isValid`|`bool`|True if price is valid|


