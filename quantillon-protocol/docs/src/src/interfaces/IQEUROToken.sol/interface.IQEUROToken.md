# IQEUROToken
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/3fa8735be1e0018ea2f65aad14e741e4059d788f/src/interfaces/IQEUROToken.sol)

**Author:**
Quantillon Labs

Read-only interface for the QEURO token

*Exposes ERC20 metadata and helper views used by integrators*

**Note:**
security-contact: team@quantillon.money


## Functions
### name

Token name


```solidity
function name() external view returns (string memory);
```

### symbol

Token symbol


```solidity
function symbol() external view returns (string memory);
```

### decimals

Token decimals (always 18)


```solidity
function decimals() external view returns (uint8);
```

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


### isMinter

Whether an address has the minter role


```solidity
function isMinter(address account) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to check|


### isBurner

Whether an address has the burner role


```solidity
function isBurner(address account) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to check|


### getSupplyUtilization

Percentage of max supply utilized (basis points)


```solidity
function getSupplyUtilization() external view returns (uint256);
```

### getRemainingMintCapacity

Remaining mint capacity before reaching max supply


```solidity
function getRemainingMintCapacity() external view returns (uint256);
```

### getRateLimitStatus

Current rate limit status


```solidity
function getRateLimitStatus()
    external
    view
    returns (
        uint256 mintedThisHour,
        uint256 burnedThisHour,
        uint256 mintLimit,
        uint256 burnLimit,
        uint256 nextResetTime
    );
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`mintedThisHour`|`uint256`|Amount minted in the current hour|
|`burnedThisHour`|`uint256`|Amount burned in the current hour|
|`mintLimit`|`uint256`|Mint rate limit per hour|
|`burnLimit`|`uint256`|Burn rate limit per hour|
|`nextResetTime`|`uint256`|Timestamp when limits reset|


### getTokenInfo

Aggregated token information snapshot


```solidity
function getTokenInfo()
    external
    view
    returns (
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        uint256 maxSupply_,
        bool isPaused_,
        bool whitelistEnabled_,
        uint256 mintRateLimit_,
        uint256 burnRateLimit_
    );
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`name_`|`string`|Token name|
|`symbol_`|`string`|Token symbol|
|`decimals_`|`uint8`|Token decimals|
|`totalSupply_`|`uint256`|Current total supply|
|`maxSupply_`|`uint256`|Maximum supply cap|
|`isPaused_`|`bool`|Whether the token is paused|
|`whitelistEnabled_`|`bool`|Whether whitelist mode is active|
|`mintRateLimit_`|`uint256`|Current mint rate limit per hour|
|`burnRateLimit_`|`uint256`|Current burn rate limit per hour|


