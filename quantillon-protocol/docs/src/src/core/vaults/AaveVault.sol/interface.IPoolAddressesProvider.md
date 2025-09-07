# IPoolAddressesProvider
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/33d218e93a34affdd8776e90bfbc756888be6ca6/src/core/vaults/AaveVault.sol)


## Functions
### getPool

Get the pool address

*Returns the address of the Aave pool*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function getPool() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|address Address of the Aave pool|


