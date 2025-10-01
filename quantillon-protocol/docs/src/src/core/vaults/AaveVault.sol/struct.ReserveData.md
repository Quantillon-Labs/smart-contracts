# ReserveData
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/5aee937988a17532c1c3fcdcebf45d2f03a0c08d/src/core/vaults/AaveVault.sol)


```solidity
struct ReserveData {
    uint256 configuration;
    uint128 liquidityIndex;
    uint128 currentLiquidityRate;
    uint128 variableBorrowIndex;
    uint128 currentVariableBorrowRate;
    uint128 currentStableBorrowRate;
    uint40 lastUpdateTimestamp;
    uint16 id;
    address aTokenAddress;
    address stableDebtTokenAddress;
    address variableDebtTokenAddress;
    address interestRateStrategyAddress;
    uint128 accruedToTreasury;
    uint128 unbacked;
    uint128 isolationModeTotalDebt;
}
```

