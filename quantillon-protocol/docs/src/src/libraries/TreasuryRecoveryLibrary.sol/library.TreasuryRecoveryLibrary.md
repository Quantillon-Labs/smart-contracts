# TreasuryRecoveryLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/fdf5f8f6194f4b414785cf5d6e2e583cb790646c/src/libraries/TreasuryRecoveryLibrary.sol)

**Title:**
TreasuryRecoveryLibrary

**Author:**
Quantillon Protocol Team

Library for secure token and ETH recovery to treasury addresses

This library factorizes the recoverToken and recoverETH functionality used across all contracts
to save gas, reduce bytecode, and ensure consistent security implementation

**Note:**
security-contact: team@quantillon.money


## Functions
### version

Returns the semantic version of this linked library.

On-chain version of the standalone deployed library; bump per semver on any change.
See deployments/{chainId}/versions.json for deployed-address provenance.

**Notes:**
- security: No security implications - returns a compile-time constant.

- validation: No input validation required.

- state-changes: None - pure function.

- events: None.

- errors: None.

- reentrancy: Not applicable - pure function.

- access: Public - anyone can read the version.

- oracle: No oracle dependencies.


```solidity
function version() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Semantic version string (e.g. "1.0.0").|


### recoverToken

Recover tokens accidentally sent to the contract to treasury only

SECURITY: Prevents recovery of own tokens and sends only to treasury

Gas optimization: Uses library function to avoid code duplication

Security: Prevents recovery of own tokens and ensures treasury-only recovery

Error handling: Uses custom errors for gas efficiency

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Not protected by a reentrancy guard

- access: Restricted to authorized roles

- oracle: Not applicable - no oracle dependency


```solidity
function recoverToken(address token, uint256 amount, address contractAddress, address treasury) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address to recover|
|`amount`|`uint256`|Amount to recover|
|`contractAddress`|`address`|Address of the calling contract (for own token check)|
|`treasury`|`address`|Treasury address to send recovered tokens to|


