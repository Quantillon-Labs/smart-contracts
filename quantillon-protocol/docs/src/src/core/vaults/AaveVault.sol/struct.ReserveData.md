# ReserveData
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/a616e9423dc69fc1960f3a480a5300eaa5fe80e0/src/core/vaults/AaveVault.sol)


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

