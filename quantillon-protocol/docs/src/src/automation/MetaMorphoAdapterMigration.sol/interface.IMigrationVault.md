# IMigrationVault
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/4b0ba41d0f77c5b737916e7f78951237651c4bdb/quantillon-protocol/src/automation/MetaMorphoAdapterMigration.sol)


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
