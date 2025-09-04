# IPool
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/8586bf0c799c78a35c463b66cf8c6beb85e48666/src/core/vaults/AaveVault.sol)

**Author:**
Quantillon Labs

**Note:**
security-contact: team@quantillon.money


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

