# IPool
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/0e00532d7586178229ff1180b9b225e8c7a432fb/src/core/vaults/AaveVault.sol)

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

