# IQEUROToken
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/5aee937988a17532c1c3fcdcebf45d2f03a0c08d/src/interfaces/IQEUROToken.sol)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Read-only interface for the QEURO token

*Exposes ERC20 metadata and helper views used by integrators*

**Note:**
security-contact: team@quantillon.money


## Functions
### name

Token name

*Returns the name of the QEURO token*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function name() external view returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|name The token name string|


### symbol

Token symbol

*Returns the symbol of the QEURO token*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function symbol() external view returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|symbol The token symbol string|


### decimals

Token decimals (always 18)

*Returns the number of decimals used by the token*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function decimals() external view returns (uint8);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|decimals The number of decimals (always 18)|


### totalSupply

Total token supply

*Returns the total supply of QEURO tokens*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function totalSupply() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|totalSupply The total supply (18 decimals)|


### balanceOf

Balance of an account

*Returns the token balance of the specified account*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function balanceOf(address account) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|balance The token balance (18 decimals)|


### isMinter

Whether an address has the minter role

*Checks if the specified account has the MINTER_ROLE*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function isMinter(address account) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|isMinter True if the account has the minter role|


### isBurner

Whether an address has the burner role

*Checks if the specified account has the BURNER_ROLE*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function isBurner(address account) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|isBurner True if the account has the burner role|


### getSupplyUtilization

Percentage of max supply utilized (basis points)

*Returns the percentage of maximum supply currently in circulation*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function getSupplyUtilization() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|utilization Percentage of max supply utilized (basis points)|


### getTokenInfo

Aggregated token information snapshot

*Returns comprehensive token information in a single call*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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


### initialize

Initialize the QEURO token contract

*Sets up initial roles and configuration for the token*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function initialize(address admin, address vault, address timelock, address treasury) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address of the admin role|
|`vault`|`address`|Address of the vault contract|
|`timelock`|`address`|Address of the timelock contract|
|`treasury`|`address`|Treasury address|


### mint

Mint new QEURO tokens to an address

*Creates new tokens and adds them to the specified address*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function mint(address to, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Address to receive the minted tokens|
|`amount`|`uint256`|Amount of tokens to mint (18 decimals)|


### burn

Burn QEURO tokens from an address

*Destroys tokens from the specified address*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function burn(address from, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Address to burn tokens from|
|`amount`|`uint256`|Amount of tokens to burn (18 decimals)|


### batchMint

Mint new QEURO tokens to multiple addresses

*Creates new tokens and distributes them to multiple recipients*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function batchMint(address[] calldata recipients, uint256[] calldata amounts) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipients`|`address[]`|Array of addresses to receive the minted tokens|
|`amounts`|`uint256[]`|Array of amounts to mint for each recipient (18 decimals)|


### batchBurn

Burn QEURO tokens from multiple addresses

*Destroys tokens from multiple addresses*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function batchBurn(address[] calldata froms, uint256[] calldata amounts) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`froms`|`address[]`|Array of addresses to burn tokens from|
|`amounts`|`uint256[]`|Array of amounts to burn from each address (18 decimals)|


### batchTransfer

Transfer QEURO tokens to multiple addresses

*Transfers tokens from the caller to multiple recipients*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipients`|`address[]`|Array of addresses to receive the tokens|
|`amounts`|`uint256[]`|Array of amounts to transfer to each recipient (18 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|success True if all transfers were successful|


### updateRateLimits

Update rate limits for minting and burning operations

*Modifies the maximum amount of tokens that can be minted or burned per hour*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function updateRateLimits(uint256 newMintLimit, uint256 newBurnLimit) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMintLimit`|`uint256`|New maximum amount of tokens that can be minted per hour (18 decimals)|
|`newBurnLimit`|`uint256`|New maximum amount of tokens that can be burned per hour (18 decimals)|


### blacklistAddress

Add an address to the blacklist with a reason

*Prevents the specified address from participating in token operations*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function blacklistAddress(address account, string memory reason) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to blacklist|
|`reason`|`string`|Reason for blacklisting the address|


### unblacklistAddress

Remove an address from the blacklist

*Allows the specified address to participate in token operations again*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function unblacklistAddress(address account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to remove from blacklist|


### whitelistAddress

Add an address to the whitelist

*Allows the specified address to participate in token operations when whitelist mode is enabled*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function whitelistAddress(address account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to whitelist|


### unwhitelistAddress

Remove an address from the whitelist

*Prevents the specified address from participating in token operations when whitelist mode is enabled*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function unwhitelistAddress(address account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to remove from whitelist|


### toggleWhitelistMode

Toggle whitelist mode on or off

*When enabled, only whitelisted addresses can participate in token operations*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function toggleWhitelistMode(bool enabled) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`enabled`|`bool`|True to enable whitelist mode, false to disable|


### batchBlacklistAddresses

Add multiple addresses to the blacklist with reasons

*Batch operation to blacklist multiple addresses efficiently*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function batchBlacklistAddresses(address[] calldata accounts, string[] calldata reasons) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accounts`|`address[]`|Array of addresses to blacklist|
|`reasons`|`string[]`|Array of reasons for blacklisting each address|


### batchUnblacklistAddresses

Remove multiple addresses from the blacklist

*Batch operation to unblacklist multiple addresses efficiently*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function batchUnblacklistAddresses(address[] calldata accounts) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accounts`|`address[]`|Array of addresses to remove from blacklist|


### batchWhitelistAddresses

Add multiple addresses to the whitelist

*Batch operation to whitelist multiple addresses efficiently*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function batchWhitelistAddresses(address[] calldata accounts) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accounts`|`address[]`|Array of addresses to whitelist|


### batchUnwhitelistAddresses

Remove multiple addresses from the whitelist

*Batch operation to unwhitelist multiple addresses efficiently*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function batchUnwhitelistAddresses(address[] calldata accounts) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accounts`|`address[]`|Array of addresses to remove from whitelist|


### updateMinPricePrecision

Update the minimum price precision for oracle feeds

*Sets the minimum number of decimal places required for price feeds*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function updateMinPricePrecision(uint256 newPrecision) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newPrecision`|`uint256`|New minimum precision value (number of decimal places)|


### normalizePrice

Normalize price from different decimal precisions to 18 decimals

*Converts price from source feed decimals to standard 18 decimal format*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function normalizePrice(uint256 price, uint8 feedDecimals) external pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|Price value to normalize|
|`feedDecimals`|`uint8`|Number of decimal places in the source feed|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|normalizedPrice Price normalized to 18 decimals|


### validatePricePrecision

Validate if price precision meets minimum requirements

*Checks if the price feed has sufficient decimal precision*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function validatePricePrecision(uint256 price, uint8 feedDecimals) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|Price value to validate|
|`feedDecimals`|`uint8`|Number of decimal places in the price feed|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|isValid True if precision meets minimum requirements|


### pause

Pause all token operations

*Emergency function to halt all token transfers, minting, and burning*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function pause() external;
```

### unpause

Unpause all token operations

*Resumes normal token operations after emergency pause*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function unpause() external;
```

### recoverToken

Recover accidentally sent tokens

*Allows recovery of ERC20 tokens sent to the contract by mistake*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function recoverToken(address token, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Address of the token to recover|
|`amount`|`uint256`|Amount of tokens to recover|


### recoverETH

Recover accidentally sent ETH

*Allows recovery of ETH sent to the contract by mistake*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function recoverETH() external;
```

### updateMaxSupply

Update the maximum supply of QEURO tokens

*Sets a new maximum supply limit for the token*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function updateMaxSupply(uint256 newMaxSupply) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMaxSupply`|`uint256`|New maximum supply limit (18 decimals)|


### transfer

Transfer QEURO tokens to another address

*Standard ERC20 transfer function with compliance checks*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function transfer(address to, uint256 amount) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Address to transfer tokens to|
|`amount`|`uint256`|Amount of tokens to transfer (18 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|success True if transfer was successful|


### allowance

Get the allowance for a spender

*Returns the amount of tokens that a spender is allowed to transfer*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function allowance(address owner, address spender) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|Address of the token owner|
|`spender`|`address`|Address of the spender|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|allowance Amount of tokens the spender can transfer (18 decimals)|


### approve

Approve a spender to transfer tokens

*Sets the allowance for a spender to transfer tokens on behalf of the caller*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function approve(address spender, uint256 amount) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`spender`|`address`|Address of the spender to approve|
|`amount`|`uint256`|Amount of tokens to approve (18 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|success True if approval was successful|


### transferFrom

Transfer tokens from one address to another

*Standard ERC20 transferFrom function with compliance checks*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function transferFrom(address from, address to, uint256 amount) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Address to transfer tokens from|
|`to`|`address`|Address to transfer tokens to|
|`amount`|`uint256`|Amount of tokens to transfer (18 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|success True if transfer was successful|


### hasRole

Check if an address has a specific role

*Returns true if the account has the specified role*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function hasRole(bytes32 role, address account) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|Role to check for|
|`account`|`address`|Address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|hasRole True if the account has the role|


### getRoleAdmin

Get the admin role for a specific role

*Returns the role that is the admin of the given role*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function getRoleAdmin(bytes32 role) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|Role to get admin for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|adminRole The admin role|


### grantRole

Grant a role to an address

*Assigns the specified role to the given account*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function grantRole(bytes32 role, address account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|Role to grant|
|`account`|`address`|Address to grant the role to|


### revokeRole

Revoke a role from an address

*Removes the specified role from the given account*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function revokeRole(bytes32 role, address account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|Role to revoke|
|`account`|`address`|Address to revoke the role from|


### renounceRole

Renounce a role

*Removes the specified role from the caller*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function renounceRole(bytes32 role, address callerConfirmation) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|Role to renounce|
|`callerConfirmation`|`address`|Address of the caller (for security)|


### paused

Check if the contract is paused

*Returns true if all token operations are paused*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function paused() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|isPaused True if the contract is paused|


### upgradeTo

Upgrade the contract implementation

*Upgrades to a new implementation address*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function upgradeTo(address newImplementation) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|


### upgradeToAndCall

Upgrade the contract implementation and call a function

*Upgrades to a new implementation and executes a function call*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|
|`data`|`bytes`|Encoded function call data|


### MINTER_ROLE

Get the MINTER_ROLE constant

*Returns the role hash for minters*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function MINTER_ROLE() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|role The MINTER_ROLE bytes32 value|


### BURNER_ROLE

Get the BURNER_ROLE constant

*Returns the role hash for burners*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function BURNER_ROLE() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|role The BURNER_ROLE bytes32 value|


### PAUSER_ROLE

Get the PAUSER_ROLE constant

*Returns the role hash for pausers*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function PAUSER_ROLE() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|role The PAUSER_ROLE bytes32 value|


### UPGRADER_ROLE

Get the UPGRADER_ROLE constant

*Returns the role hash for upgraders*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function UPGRADER_ROLE() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|role The UPGRADER_ROLE bytes32 value|


### COMPLIANCE_ROLE

Get the COMPLIANCE_ROLE constant

*Returns the role hash for compliance officers*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function COMPLIANCE_ROLE() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|role The COMPLIANCE_ROLE bytes32 value|


### DEFAULT_MAX_SUPPLY

Get the DEFAULT_MAX_SUPPLY constant

*Returns the default maximum supply limit*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function DEFAULT_MAX_SUPPLY() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|maxSupply The default maximum supply (18 decimals)|


### MAX_RATE_LIMIT

Get the MAX_RATE_LIMIT constant

*Returns the maximum rate limit value*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function MAX_RATE_LIMIT() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|maxLimit The maximum rate limit (18 decimals)|


### PRECISION

Get the PRECISION constant

*Returns the precision value used for calculations*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function PRECISION() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|precision The precision value (18 decimals)|


### maxSupply

Get the current maximum supply limit

*Returns the maximum number of tokens that can be minted*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function maxSupply() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|maxSupply Current maximum supply limit (18 decimals)|


### mintRateLimit

Get the current mint rate limit

*Returns the maximum amount of tokens that can be minted per hour*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function mintRateLimit() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|mintLimit Current mint rate limit (18 decimals)|


### burnRateLimit

Get the current burn rate limit

*Returns the maximum amount of tokens that can be burned per hour*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function burnRateLimit() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|burnLimit Current burn rate limit (18 decimals)|


### currentHourMinted

Get the amount minted in the current hour

*Returns the total amount of tokens minted in the current rate limit window*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function currentHourMinted() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|minted Current hour minted amount (18 decimals)|


### currentHourBurned

Get the amount burned in the current hour

*Returns the total amount of tokens burned in the current rate limit window*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function currentHourBurned() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|burned Current hour burned amount (18 decimals)|


### lastRateLimitReset

Get the timestamp of the last rate limit reset

*Returns when the rate limit counters were last reset*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function lastRateLimitReset() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|resetTime Timestamp of last rate limit reset|


### isBlacklisted

Check if an address is blacklisted

*Returns true if the address is on the blacklist*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function isBlacklisted(address account) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|isBlacklisted True if the address is blacklisted|


### isWhitelisted

Check if an address is whitelisted

*Returns true if the address is on the whitelist*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function isWhitelisted(address account) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|isWhitelisted True if the address is whitelisted|


### whitelistEnabled

Check if whitelist mode is enabled

*Returns true if whitelist mode is active*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function whitelistEnabled() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|enabled True if whitelist mode is enabled|


### minPricePrecision

Get the minimum price precision requirement

*Returns the minimum number of decimal places required for price feeds*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function minPricePrecision() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|precision Minimum price precision value|


