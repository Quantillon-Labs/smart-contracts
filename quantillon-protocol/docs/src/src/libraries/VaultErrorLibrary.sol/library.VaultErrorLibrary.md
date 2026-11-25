# VaultErrorLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/4b0ba41d0f77c5b737916e7f78951237651c4bdb/quantillon-protocol/src/libraries/VaultErrorLibrary.sol)

**Title:**
VaultErrorLibrary

Vault-specific errors for QuantillonVault and related operations

Main characteristics:
- Errors specific to vault operations
- Fee validation errors

**Note:**
security-contact: team@quantillon.money


## Constants
### VERSION
Library version (semver); see deployments/{chainId}/versions.json for provenance.


```solidity
string internal constant VERSION = "1.0.0"
```


## Errors
### FeeTooHigh

```solidity
error FeeTooHigh();
```
