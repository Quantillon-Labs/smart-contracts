# AdminFunctionsLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/973bc7b9b5281df753b9c9569aff01d589239043/src/libraries/AdminFunctionsLibrary.sol)

**Title:**
AdminFunctionsLibrary

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Library for rarely used admin functions to reduce contract size

Main characteristics:
- Consolidates admin functions like recoverToken
- Reduces contract size by moving rarely used functions to library
- Maintains same API and behavior
- Uses custom errors for gas efficiency

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

Recover tokens to treasury address

Emergency function to recover ERC20 tokens sent to the contract

**Notes:**
- security: Requires admin role

- validation: None required

- state-changes: Transfers tokens from contract to treasury

- events: Emits TokenRecovered event

- errors: Throws NotAuthorized if caller lacks admin role

- reentrancy: Not protected - library handles reentrancy

- access: Restricted to admin role

- oracle: Not applicable


```solidity
function recoverToken(address contractInstance, address token, uint256 amount, address treasury, bytes32 adminRole)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`contractInstance`|`address`|The contract instance calling this function|
|`token`|`address`|Address of the token to recover|
|`amount`|`uint256`|Amount of tokens to recover|
|`treasury`|`address`|The treasury address to send tokens to|
|`adminRole`|`bytes32`|The admin role required for this operation|


