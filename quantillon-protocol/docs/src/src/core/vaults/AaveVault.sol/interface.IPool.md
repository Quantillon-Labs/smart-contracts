# IPool
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/e5c3f7e74d800a0a930892672bba2f0c381c0a8d/src/core/vaults/AaveVault.sol)

**Author:**
Quantillon Labs

**Note:**
team@quantillon.money


## Functions
### supply


```solidity
function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
```

### withdraw


```solidity
function withdraw(address asset, uint256 amount, address to) external returns (uint256);
```

### getReserveData


```solidity
function getReserveData(address asset) external view returns (ReserveData memory);
```

