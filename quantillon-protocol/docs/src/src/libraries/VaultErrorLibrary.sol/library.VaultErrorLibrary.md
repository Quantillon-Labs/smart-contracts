# VaultErrorLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/e6d6ab67e05d161d0d4815c50b5213a2a6cbb873/src/libraries/VaultErrorLibrary.sol)

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

