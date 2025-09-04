# IPool
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/7a38080e43ad67d1bf394347f3ca09d4cbbceb2e/src/core/vaults/AaveVault.sol)

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

