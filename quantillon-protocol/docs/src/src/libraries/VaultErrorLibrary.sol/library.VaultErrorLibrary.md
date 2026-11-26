# VaultErrorLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/8d2039e2823d486678a185b0e5630b0a7677bddc/quantillon-protocol/src/libraries/VaultErrorLibrary.sol)

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
