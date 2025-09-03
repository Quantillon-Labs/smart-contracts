# IQEUROToken
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/3822e8b8c39dab806b39c3963ee691f29eecba69/src/interfaces/IQEUROToken.sol)

**Author:**
Quantillon Labs

Read-only interface for the QEURO token

*Exposes ERC20 metadata and helper views used by integrators*

**Note:**
team@quantillon.money


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


### initialize


```solidity
function initialize(address admin, address vault, address timelock) external;
```

### mint


```solidity
function mint(address to, uint256 amount) external;
```

### burn


```solidity
function burn(address from, uint256 amount) external;
```

### batchMint


```solidity
function batchMint(address[] calldata recipients, uint256[] calldata amounts) external;
```

### batchBurn


```solidity
function batchBurn(address[] calldata froms, uint256[] calldata amounts) external;
```

### batchTransfer


```solidity
function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) external returns (bool);
```

### updateRateLimits


```solidity
function updateRateLimits(uint256 newMintLimit, uint256 newBurnLimit) external;
```

### blacklistAddress


```solidity
function blacklistAddress(address account, string memory reason) external;
```

### unblacklistAddress


```solidity
function unblacklistAddress(address account) external;
```

### whitelistAddress


```solidity
function whitelistAddress(address account) external;
```

### unwhitelistAddress


```solidity
function unwhitelistAddress(address account) external;
```

### toggleWhitelistMode


```solidity
function toggleWhitelistMode(bool enabled) external;
```

### batchBlacklistAddresses


```solidity
function batchBlacklistAddresses(address[] calldata accounts, string[] calldata reasons) external;
```

### batchUnblacklistAddresses


```solidity
function batchUnblacklistAddresses(address[] calldata accounts) external;
```

### batchWhitelistAddresses


```solidity
function batchWhitelistAddresses(address[] calldata accounts) external;
```

### batchUnwhitelistAddresses


```solidity
function batchUnwhitelistAddresses(address[] calldata accounts) external;
```

### updateMinPricePrecision


```solidity
function updateMinPricePrecision(uint256 newPrecision) external;
```

### normalizePrice


```solidity
function normalizePrice(uint256 price, uint8 feedDecimals) external pure returns (uint256);
```

### validatePricePrecision


```solidity
function validatePricePrecision(uint256 price, uint8 feedDecimals) external view returns (bool);
```

### pause


```solidity
function pause() external;
```

### unpause


```solidity
function unpause() external;
```

### recoverToken


```solidity
function recoverToken(address token, address to, uint256 amount) external;
```

### recoverETH


```solidity
function recoverETH() external;
```

### updateMaxSupply


```solidity
function updateMaxSupply(uint256 newMaxSupply) external;
```

### transfer


```solidity
function transfer(address to, uint256 amount) external returns (bool);
```

### allowance


```solidity
function allowance(address owner, address spender) external view returns (uint256);
```

### approve


```solidity
function approve(address spender, uint256 amount) external returns (bool);
```

### transferFrom


```solidity
function transferFrom(address from, address to, uint256 amount) external returns (bool);
```

### hasRole


```solidity
function hasRole(bytes32 role, address account) external view returns (bool);
```

### getRoleAdmin


```solidity
function getRoleAdmin(bytes32 role) external view returns (bytes32);
```

### grantRole


```solidity
function grantRole(bytes32 role, address account) external;
```

### revokeRole


```solidity
function revokeRole(bytes32 role, address account) external;
```

### renounceRole


```solidity
function renounceRole(bytes32 role, address callerConfirmation) external;
```

### paused


```solidity
function paused() external view returns (bool);
```

### upgradeTo


```solidity
function upgradeTo(address newImplementation) external;
```

### upgradeToAndCall


```solidity
function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
```

### MINTER_ROLE


```solidity
function MINTER_ROLE() external view returns (bytes32);
```

### BURNER_ROLE


```solidity
function BURNER_ROLE() external view returns (bytes32);
```

### PAUSER_ROLE


```solidity
function PAUSER_ROLE() external view returns (bytes32);
```

### UPGRADER_ROLE


```solidity
function UPGRADER_ROLE() external view returns (bytes32);
```

### COMPLIANCE_ROLE


```solidity
function COMPLIANCE_ROLE() external view returns (bytes32);
```

### DEFAULT_MAX_SUPPLY


```solidity
function DEFAULT_MAX_SUPPLY() external view returns (uint256);
```

### MAX_RATE_LIMIT


```solidity
function MAX_RATE_LIMIT() external view returns (uint256);
```

### PRECISION


```solidity
function PRECISION() external view returns (uint256);
```

### maxSupply


```solidity
function maxSupply() external view returns (uint256);
```

### mintRateLimit


```solidity
function mintRateLimit() external view returns (uint256);
```

### burnRateLimit


```solidity
function burnRateLimit() external view returns (uint256);
```

### currentHourMinted


```solidity
function currentHourMinted() external view returns (uint256);
```

### currentHourBurned


```solidity
function currentHourBurned() external view returns (uint256);
```

### lastRateLimitReset


```solidity
function lastRateLimitReset() external view returns (uint256);
```

### isBlacklisted


```solidity
function isBlacklisted(address) external view returns (bool);
```

### isWhitelisted


```solidity
function isWhitelisted(address) external view returns (bool);
```

### whitelistEnabled


```solidity
function whitelistEnabled() external view returns (bool);
```

### minPricePrecision


```solidity
function minPricePrecision() external view returns (uint256);
```

