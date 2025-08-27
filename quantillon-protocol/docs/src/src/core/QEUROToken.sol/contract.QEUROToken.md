# QEUROToken
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/fdfa9b97a216b9d7d0aa6ab6f91d4d59eb78a4cf/src/core/QEUROToken.sol)

**Inherits:**
Initializable, ERC20Upgradeable, AccessControlUpgradeable, PausableUpgradeable, [SecureUpgradeable](/src/core/SecureUpgradeable.sol/abstract.SecureUpgradeable.md)

**Author:**
Quantillon Labs

Euro-pegged stablecoin token for the Quantillon protocol

*Main characteristics:
- Standard ERC20 with 18 decimals
- Mint/Burn controlled only by the vault
- Emergency pause in case of issues
- Upgradeable via UUPS pattern
- Dynamic supply cap for governance flexibility
- Blacklist/whitelist functionality for compliance
- Rate limiting for mint/burn operations
- Decimal precision handling for external price feeds*

*Security features:
- Role-based access control for all critical operations
- Emergency pause mechanism for crisis situations
- Rate limiting to prevent abuse
- Blacklist/whitelist for regulatory compliance
- Upgradeable architecture for future improvements*

*Tokenomics:
- Initial supply: 0 (all tokens minted through vault operations)
- Maximum supply: Configurable by governance (default 100M QEURO)
- Decimals: 18 (standard for ERC20 tokens)
- Peg: 1:1 with Euro (managed by vault operations)*

**Note:**
security-contact: team@quantillon.money


## State Variables
### MINTER_ROLE
Role for minting tokens (assigned to QuantillonVault only)

*keccak256 hash avoids role collisions with other contracts*

*Only the vault should have this role to maintain tokenomics*


```solidity
bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
```


### BURNER_ROLE
Role for burning tokens (assigned to QuantillonVault only)

*keccak256 hash avoids role collisions with other contracts*

*Only the vault should have this role to maintain tokenomics*


```solidity
bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
```


### PAUSER_ROLE
Role for pausing the contract in emergency situations

*keccak256 hash avoids role collisions with other contracts*

*Should be assigned to governance or emergency multisig*


```solidity
bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
```


### COMPLIANCE_ROLE
Role for managing blacklist/whitelist for compliance

*keccak256 hash avoids role collisions with other contracts*

*Should be assigned to compliance team or governance*


```solidity
bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
```


### DEFAULT_MAX_SUPPLY
Default maximum supply limit (100 million QEURO)

*Can be updated by governance through updateMaxSupply()*

*Value: 100,000,000 * 10^18 = 100,000,000 QEURO*


```solidity
uint256 public constant DEFAULT_MAX_SUPPLY = 100_000_000 * 1e18;
```


### MAX_RATE_LIMIT
Maximum rate limit for mint/burn operations (per hour)

*Prevents abuse and provides time for emergency response*

*Value: 10,000,000 * 10^18 = 10,000,000 QEURO per hour*


```solidity
uint256 public constant MAX_RATE_LIMIT = 10_000_000 * 1e18;
```


### PRECISION
Precision for decimal calculations (18 decimals)

*Standard precision used throughout the protocol*

*Value: 10^18*


```solidity
uint256 public constant PRECISION = 1e18;
```


### maxSupply
Current maximum supply limit (updatable by governance)

*Initialized to DEFAULT_MAX_SUPPLY, can be changed by governance*

*Prevents infinite minting and maintains tokenomics*


```solidity
uint256 public maxSupply;
```


### mintRateLimit
Rate limit for mint operations (per hour)

*Prevents rapid minting that could destabilize the protocol*

*Can be updated by governance through updateRateLimits()*


```solidity
uint256 public mintRateLimit;
```


### burnRateLimit
Rate limit for burn operations (per hour)

*Prevents rapid burning that could destabilize the protocol*

*Can be updated by governance through updateRateLimits()*


```solidity
uint256 public burnRateLimit;
```


### rateLimitInfo

```solidity
RateLimitInfo public rateLimitInfo;
```


### isBlacklisted
Blacklist mapping for compliance and security

*Blacklisted addresses cannot transfer or receive tokens*

*Can be managed by addresses with COMPLIANCE_ROLE*


```solidity
mapping(address => bool) public isBlacklisted;
```


### isWhitelisted
Whitelist mapping for compliance (if enabled)

*When whitelistEnabled is true, only whitelisted addresses can transfer*

*Can be managed by addresses with COMPLIANCE_ROLE*


```solidity
mapping(address => bool) public isWhitelisted;
```


### whitelistEnabled
Whether whitelist mode is enabled

*When true, only whitelisted addresses can transfer tokens*

*Can be toggled by addresses with COMPLIANCE_ROLE*


```solidity
bool public whitelistEnabled;
```


### minPricePrecision
Minimum precision for external price feeds

*Used to validate price feed precision for accurate calculations*

*Can be updated by governance through updateMinPricePrecision()*


```solidity
uint256 public minPricePrecision;
```


## Functions
### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### initialize

Initializes the QEURO token (called only once at deployment)

*This function replaces the constructor. It:
1. Initializes the ERC20 token with name and symbol
2. Configures the role system
3. Assigns appropriate roles
4. Configures pause and upgrade system
5. Sets initial rate limits and precision settings*

*Security considerations:
- Only callable once (initializer modifier)
- Validates input parameters
- Sets up proper role hierarchy
- Initializes all state variables*


```solidity
function initialize(address admin, address vault, address timelock) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address that will have the DEFAULT_ADMIN_ROLE|
|`vault`|`address`|Address of the QuantillonVault (will get MINTER_ROLE and BURNER_ROLE)|
|`timelock`|`address`||


### mint

Mints QEURO tokens to a specified address

*Implemented securities:
- Only the vault can call this function (MINTER_ROLE)
- The contract must not be paused
- Respect for maximum supply cap
- Input parameter validation
- Rate limiting
- Blacklist/whitelist checks
Usage example: vault.mint(user, 1000 * 1e18) for 1000 QEURO*

*Security considerations:
- Only MINTER_ROLE can mint
- Pause check
- Rate limiting
- Blacklist/whitelist checks
- Supply cap verification
- Secure minting using OpenZeppelin*


```solidity
function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Address that will receive the tokens|
|`amount`|`uint256`|Amount of tokens to mint (in wei, 18 decimals)|


### burn

Burns QEURO tokens from a specified address

*Implemented securities:
- Only the vault can call this function (BURNER_ROLE)
- The contract must not be paused
- Sufficient balance verification
- Parameter validation
- Rate limiting
Note: The vault must have an allowance or be authorized otherwise*

*Security considerations:
- Only BURNER_ROLE can burn
- Pause check
- Rate limiting
- Secure burning using OpenZeppelin*


```solidity
function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Address from which to burn tokens|
|`amount`|`uint256`|Amount of tokens to burn|


### _checkAndUpdateMintRateLimit

Checks and updates mint rate limit

*Internal function to enforce rate limiting*

*Security considerations:
- Resets rate limit if an hour has passed
- Checks if the new amount would exceed the rate limit
- Updates the current hour minted amount
- Throws an error if rate limit is exceeded
- Includes bounds checking to prevent timestamp manipulation*


```solidity
function _checkAndUpdateMintRateLimit(uint256 amount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount being minted|


### _checkAndUpdateBurnRateLimit

Checks and updates burn rate limit

*Internal function to enforce rate limiting*

*Security considerations:
- Resets rate limit if an hour has passed
- Checks if the new amount would exceed the rate limit
- Updates the current hour burned amount
- Throws an error if rate limit is exceeded
- Includes bounds checking to prevent timestamp manipulation*


```solidity
function _checkAndUpdateBurnRateLimit(uint256 amount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount being burned|


### updateRateLimits

Updates rate limits for mint and burn operations

*Only callable by admin*

*Security considerations:
- Validates new limits
- Ensures new limits are not zero
- Ensures new limits are not too high
- Updates mintRateLimit and burnRateLimit
- Emits RateLimitsUpdated event*


```solidity
function updateRateLimits(uint256 newMintLimit, uint256 newBurnLimit) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMintLimit`|`uint256`|New mint rate limit per hour|
|`newBurnLimit`|`uint256`|New burn rate limit per hour|


### blacklistAddress

Blacklists an address

*Only callable by compliance role*

*Security considerations:
- Validates input parameters
- Prevents blacklisting of zero address
- Prevents blacklisting of already blacklisted addresses
- Updates isBlacklisted mapping
- Emits AddressBlacklisted event*


```solidity
function blacklistAddress(address account, string memory reason) external onlyRole(COMPLIANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to blacklist|
|`reason`|`string`|Reason for blacklisting|


### unblacklistAddress

Removes an address from blacklist

*Only callable by compliance role*

*Security considerations:
- Validates input parameter
- Prevents unblacklisting of non-blacklisted addresses
- Updates isBlacklisted mapping
- Emits AddressUnblacklisted event*


```solidity
function unblacklistAddress(address account) external onlyRole(COMPLIANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to remove from blacklist|


### whitelistAddress

Whitelists an address

*Only callable by compliance role*

*Security considerations:
- Validates input parameters
- Prevents whitelisting of zero address
- Prevents whitelisting of already whitelisted addresses
- Updates isWhitelisted mapping
- Emits AddressWhitelisted event*


```solidity
function whitelistAddress(address account) external onlyRole(COMPLIANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to whitelist|


### unwhitelistAddress

Removes an address from whitelist

*Only callable by compliance role*

*Security considerations:
- Validates input parameter
- Prevents unwhitelisting of non-whitelisted addresses
- Updates isWhitelisted mapping
- Emits AddressUnwhitelisted event*


```solidity
function unwhitelistAddress(address account) external onlyRole(COMPLIANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to remove from whitelist|


### toggleWhitelistMode

Toggles whitelist mode

*Only callable by compliance role*

*Security considerations:
- Validates input parameter
- Updates whitelistEnabled state
- Emits WhitelistModeToggled event*


```solidity
function toggleWhitelistMode(bool enabled) external onlyRole(COMPLIANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`enabled`|`bool`|Whether to enable whitelist mode|


### updateMinPricePrecision

Updates minimum price precision for external feeds

*Only callable by admin*

*Security considerations:
- Validates input parameter
- Prevents setting precision to zero
- Prevents setting precision higher than PRECISION
- Updates minPricePrecision
- Emits MinPricePrecisionUpdated event*


```solidity
function updateMinPricePrecision(uint256 newPrecision) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newPrecision`|`uint256`|New minimum precision (e.g., 1e6 for 6 decimals)|


### normalizePrice

Normalizes a price value to 18 decimals

*Helper function for external integrations*

*Security considerations:
- Validates input parameters
- Prevents too many decimals
- Prevents zero price
- Handles normalization correctly*


```solidity
function normalizePrice(uint256 price, uint8 feedDecimals) external pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|Price value from external feed|
|`feedDecimals`|`uint8`|Number of decimals in the price feed|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Normalized price with 18 decimals|


### validatePricePrecision

Validates price precision from external feed

*Helper function for external integrations*

*Security considerations:
- Validates input parameters
- Handles normalization if feedDecimals is not 18
- Returns true if price is above or equal to minPricePrecision*


```solidity
function validatePricePrecision(uint256 price, uint8 feedDecimals) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|Price value from external feed|
|`feedDecimals`|`uint8`|Number of decimals in the price feed|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the price meets minimum precision requirements|


### pause

Pauses all token operations (emergency only)

*When paused:
- No transfers possible
- No mint/burn possible
- Only read functions work
Used in case of:
- Critical bug discovered
- Ongoing attack
- Emergency protocol maintenance*

*Security considerations:
- Only PAUSER_ROLE can pause
- Pauses all token operations
- Prevents any state changes*


```solidity
function pause() external onlyRole(PAUSER_ROLE);
```

### unpause

Removes pause and restores normal operations

*Can only be called by a PAUSER_ROLE
Used after resolving the issue that caused the pause*

*Security considerations:
- Only PAUSER_ROLE can unpause
- Unpauses all token operations
- Allows normal state changes*


```solidity
function unpause() external onlyRole(PAUSER_ROLE);
```

### decimals

Returns the number of decimals for the token (always 18)

*Security considerations:
- Always returns 18
- No input validation
- No state changes*


```solidity
function decimals() public pure override returns (uint8);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|Number of decimals (18 for DeFi compatibility)|


### isMinter

Checks if an address has the minter role

*Security considerations:
- Checks if account has MINTER_ROLE
- No input validation
- No state changes*


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
|`<none>`|`bool`|true if the address can mint|


### isBurner

Checks if an address has the burner role

*Security considerations:
- Checks if account has BURNER_ROLE
- No input validation
- No state changes*


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
|`<none>`|`bool`|true if the address can burn|


### getSupplyUtilization

Calculates the percentage of maximum supply utilization

*Useful for monitoring:
- 0 = 0% used
- 5000 = 50% used
- 10000 = 100% used (maximum supply reached)*

*Security considerations:
- Calculates percentage based on totalSupply and maxSupply
- Handles division by zero
- Returns 0 if totalSupply is 0*


```solidity
function getSupplyUtilization() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Percentage in basis points (0-10000, where 10000 = 100%)|


### _update

Calculates remaining space for minting new tokens

Gets current rate limit status

Hook called before each token transfer

*Security considerations:
- Calculates remaining capacity by subtracting currentSupply from maxSupply
- Handles case where currentSupply >= maxSupply
- Returns 0 if no more minting is possible*

*Security considerations:
- Returns current hour amounts if within the hour
- Returns zeros if an hour has passed
- Returns current limits and next reset time
- Includes bounds checking to prevent timestamp manipulation*

*Adds pause verification and blacklist checks to standard OpenZeppelin transfers*

*Security considerations:
- Checks if transfer is from a blacklisted address
- Checks if transfer is to a blacklisted address
- If whitelist is enabled, checks if recipient is whitelisted
- Prevents transfers if any checks fail
- Calls super._update for standard ERC20 logic*


```solidity
function _update(address from, address to, uint256 amount) internal override whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Source address (address(0) for mint)|
|`to`|`address`|Destination address (address(0) for burn)|
|`amount`|`uint256`|Amount transferred|


### recoverToken

Recovers tokens accidentally sent to the contract

*Securities:
- Only admin can recover
- Cannot recover own QEURO tokens
- Recipient cannot be zero address
- Uses SafeERC20 for secure transfers
Use cases:
- A user accidentally sends USDC to the QEURO contract
- Admin can recover them and return them*

*Security considerations:
- Only DEFAULT_ADMIN_ROLE can recover
- Prevents recovery of own QEURO tokens
- Validates input parameters
- Uses SafeERC20 for secure transfers*


```solidity
function recoverToken(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Address of the token contract to recover|
|`to`|`address`|Address to send recovered tokens to|
|`amount`|`uint256`|Amount to recover|


### recoverETH

Recovers ETH accidentally sent

*Security considerations:
- Only DEFAULT_ADMIN_ROLE can recover
- Prevents sending to zero address
- Validates balance before attempting transfer
- Uses call() for reliable ETH transfers to any contract*


```solidity
function recoverETH(address payable to) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address payable`|ETH recipient|


### updateMaxSupply

Updates the maximum supply limit (governance only)

*Function to adjust supply cap if necessary
Requires governance and must be used with caution*

*IMPROVEMENT: Now functional with dynamic supply cap*

*Security considerations:
- Only DEFAULT_ADMIN_ROLE can update
- Validates newMaxSupply
- Prevents setting cap below current supply
- Prevents setting cap to zero
- Emits SupplyCapUpdated event*


```solidity
function updateMaxSupply(uint256 newMaxSupply) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMaxSupply`|`uint256`|New supply limit|


### getTokenInfo

Complete token information (for monitoring)

*Security considerations:
- Returns current state of the token
- No input validation
- No state changes*


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
|`decimals_`|`uint8`|Number of decimals|
|`totalSupply_`|`uint256`|Current total supply|
|`maxSupply_`|`uint256`|Maximum authorized supply|
|`isPaused_`|`bool`|Pause state|
|`whitelistEnabled_`|`bool`|Whether whitelist mode is enabled|
|`mintRateLimit_`|`uint256`|Current mint rate limit|
|`burnRateLimit_`|`uint256`|Current burn rate limit|


## Events
### TokensMinted
Emitted when tokens are minted

*Indexed parameters allow efficient filtering of events*


```solidity
event TokensMinted(address indexed to, uint256 amount, address indexed minter);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Recipient of the tokens|
|`amount`|`uint256`|Amount minted in wei (18 decimals)|
|`minter`|`address`|Address that performed the mint (vault)|

### TokensBurned
Emitted when tokens are burned

*Indexed parameters allow efficient filtering of events*


```solidity
event TokensBurned(address indexed from, uint256 amount, address indexed burner);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Address from which tokens are burned|
|`amount`|`uint256`|Amount burned in wei (18 decimals)|
|`burner`|`address`|Address that performed the burn (vault)|

### SupplyCapUpdated
Emitted when the supply limit is modified

*Emitted when governance updates the maximum supply*


```solidity
event SupplyCapUpdated(uint256 oldCap, uint256 newCap);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldCap`|`uint256`|Old supply limit in wei (18 decimals)|
|`newCap`|`uint256`|New supply limit in wei (18 decimals)|

### RateLimitsUpdated
Emitted when rate limits are updated

*Emitted when governance updates rate limits*


```solidity
event RateLimitsUpdated(uint256 mintLimit, uint256 burnLimit);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mintLimit`|`uint256`|New mint rate limit in wei per hour (18 decimals)|
|`burnLimit`|`uint256`|New burn rate limit in wei per hour (18 decimals)|

### AddressBlacklisted
Emitted when an address is blacklisted

*Emitted when COMPLIANCE_ROLE blacklists an address*


```solidity
event AddressBlacklisted(address indexed account, string reason);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address that was blacklisted|
|`reason`|`string`|Reason for blacklisting (for compliance records)|

### AddressUnblacklisted
Emitted when an address is removed from blacklist

*Emitted when COMPLIANCE_ROLE removes an address from blacklist*


```solidity
event AddressUnblacklisted(address indexed account);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address that was removed from blacklist|

### AddressWhitelisted
Emitted when an address is whitelisted

*Emitted when COMPLIANCE_ROLE whitelists an address*


```solidity
event AddressWhitelisted(address indexed account);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address that was whitelisted|

### AddressUnwhitelisted
Emitted when an address is removed from whitelist

*Emitted when COMPLIANCE_ROLE removes an address from whitelist*


```solidity
event AddressUnwhitelisted(address indexed account);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address that was removed from whitelist|

### WhitelistModeToggled
Emitted when whitelist mode is toggled

*Emitted when COMPLIANCE_ROLE toggles whitelist mode*


```solidity
event WhitelistModeToggled(bool enabled);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`enabled`|`bool`|Whether whitelist mode is enabled|

### MinPricePrecisionUpdated
Emitted when minimum price precision is updated

*Emitted when governance updates minimum price precision*


```solidity
event MinPricePrecisionUpdated(uint256 oldPrecision, uint256 newPrecision);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldPrecision`|`uint256`|Old minimum precision value|
|`newPrecision`|`uint256`|New minimum precision value|

### RateLimitReset
Emitted when rate limit is reset

*Emitted when rate limits are reset (hourly or manual)*


```solidity
event RateLimitReset(uint256 timestamp);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timestamp`|`uint256`|Timestamp of reset|

## Structs
### RateLimitInfo
Rate limiting information - OPTIMIZED: Packed for storage efficiency

*Resets every hour or when rate limits are updated*

*Used to enforce mintRateLimit and burnRateLimit*


```solidity
struct RateLimitInfo {
    uint96 currentHourMinted;
    uint96 currentHourBurned;
    uint64 lastRateLimitReset;
}
```

