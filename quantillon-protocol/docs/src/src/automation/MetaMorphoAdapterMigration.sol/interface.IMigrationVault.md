# IMigrationVault
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/083874330beb67c980851f48832ef5faa68973d3/src/automation/MetaMorphoAdapterMigration.sol)


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
