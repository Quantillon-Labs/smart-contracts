# IPool
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/d9b318c983e96e686dbdeddf2128adc1d9fdfb49/src/core/vaults/AaveVault.sol)

**Author:**
Quantillon Labs

Manages Aave V3 integration for yield-bearing USDC deposits

*Implements the aQEURO variant - QEURO backed by yield-bearing Aave deposits*

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

### getUserAccountData


```solidity
function getUserAccountData(address user)
    external
    view
    returns (
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 availableBorrowsBase,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    );
```

