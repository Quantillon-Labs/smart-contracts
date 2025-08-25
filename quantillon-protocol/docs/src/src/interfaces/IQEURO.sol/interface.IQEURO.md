# IQEURO
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/3fa8735be1e0018ea2f65aad14e741e4059d788f/src/interfaces/IQEURO.sol)

**Author:**
Quantillon Labs

Minimal interface for the QEURO token used by the vault

*Exposes only the functions the vault needs (mint/burn) and basic views*

**Note:**
security-contact: team@quantillon.money


## Functions
### mint

Mints QEURO to an address


```solidity
function mint(address to, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Recipient address|
|`amount`|`uint256`|Amount to mint (18 decimals)|


### burn

Burns QEURO from an address


```solidity
function burn(address from, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Address to burn from|
|`amount`|`uint256`|Amount to burn (18 decimals)|


### totalSupply

Total token supply


```solidity
function totalSupply() external view returns (uint256);
```

### balanceOf

Balance of an account


```solidity
function balanceOf(address account) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to query|


### decimals

Token decimals (should be 18)


```solidity
function decimals() external view returns (uint8);
```

### transfer

Transfer tokens to another address


```solidity
function transfer(address to, uint256 amount) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Recipient address|
|`amount`|`uint256`|Amount to transfer|


### transferFrom

Transfer tokens from one address to another (requires allowance)


```solidity
function transferFrom(address from, address to, uint256 amount) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Source address|
|`to`|`address`|Recipient address|
|`amount`|`uint256`|Amount to transfer|


