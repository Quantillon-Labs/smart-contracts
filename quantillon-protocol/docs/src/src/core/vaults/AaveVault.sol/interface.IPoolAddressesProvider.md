# IPoolAddressesProvider
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/91f7ed3e8a496e9d369dc182e8f549ec75449a6b/src/core/vaults/AaveVault.sol)


## Functions
### getPool

Get the pool address

*Returns the address of the Aave pool*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function getPool() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|address Address of the Aave pool|


