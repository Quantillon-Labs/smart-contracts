# TreasuryRecoveryLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/bbddbedca72271d4260ea804101124f3dc71302c/src/libraries/TreasuryRecoveryLibrary.sol)

**Author:**
Quantillon Protocol Team

Library for secure token and ETH recovery to treasury addresses

*This library factorizes the recoverToken and recoverETH functionality used across all contracts
to save gas, reduce bytecode, and ensure consistent security implementation*

**Note:**
team@quantillon.money


## Functions
### recoverToken

Recover tokens accidentally sent to the contract to treasury only

*SECURITY: Prevents recovery of own tokens and sends only to treasury*

*Gas optimization: Uses library function to avoid code duplication*

*Security: Prevents recovery of own tokens and ensures treasury-only recovery*

*Error handling: Uses custom errors for gas efficiency*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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


### recoverETH

Recover ETH to treasury address only

*SECURITY: Restricted to treasury to prevent arbitrary ETH transfers*

*Gas optimization: Uses library function to avoid code duplication*

*Security: Prevents arbitrary ETH transfers that could be exploited*

*Error handling: Uses custom errors for gas efficiency*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function recoverETH(address treasury) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`treasury`|`address`|The contract's treasury address|


