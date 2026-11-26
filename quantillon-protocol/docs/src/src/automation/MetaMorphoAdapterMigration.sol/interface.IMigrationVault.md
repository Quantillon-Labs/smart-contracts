# IMigrationVault
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/8d2039e2823d486678a185b0e5630b0a7677bddc/quantillon-protocol/src/automation/MetaMorphoAdapterMigration.sol)


## Functions
### paused


```solidity
function paused() external view returns (bool);
```

### usdc


```solidity
function usdc() external view returns (address);
```

### getVaultExposure


```solidity
function getVaultExposure(uint256 id) external view returns (address, bool, uint256, uint256);
```

### setStakingVault


```solidity
function setStakingVault(uint256 id, address adapter, bool active) external;
```
