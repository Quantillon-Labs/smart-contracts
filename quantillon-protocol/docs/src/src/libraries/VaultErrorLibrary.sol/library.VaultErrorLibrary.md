# VaultErrorLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/54366a1075ba6db39540a3d83709a310c26d1723/src/libraries/VaultErrorLibrary.sol)

**Title:**
VaultErrorLibrary

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

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
