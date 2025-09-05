# ReserveData
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/07b6c9d21c3d2b99aa95cee2e6cc9c3f00f0009a/src/core/vaults/AaveVault.sol)


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

