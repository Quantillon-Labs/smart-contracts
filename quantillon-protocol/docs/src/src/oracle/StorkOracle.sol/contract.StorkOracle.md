# StorkOracle
**Inherits:**
[IStorkOracle](/src/interfaces/IStorkOracle.sol/interface.IStorkOracle.md), Initializable, AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

EUR/USD and USDC/USD price manager for Quantillon Protocol using Stork Network

*Key features:
- Fetch EUR/USD price from Stork Network
- Validate USDC/USD (should remain close to $1.00)
- Circuit breakers against outlier prices
- Fallbacks in case of oracle outage
- Data freshness checks*

*DEPLOYMENT REQUIREMENTS:
Before deploying, you must obtain the following from Stork Network:
1. Stork contract address on Base mainnet (the main Stork oracle contract)
2. EUR/USD feed ID (bytes32 identifier for EUR/USD price feed)
3. USDC/USD feed ID (bytes32 identifier for USDC/USD price feed)
How to obtain:
- Visit Stork's data feeds: https://data.stork.network/
- Search for "EUR/USD" and "USDC/USD" feeds
- Contact Stork support for Base mainnet contract addresses:
Discord: https://discord.com (Stork Network)
Documentation: https://docs.stork.network/
Email: support at stork.network (if available)
ALTERNATIVE: Consider using Stork's Chainlink adapter for easier integration:
- GitHub: https://github.com/Stork-Oracle/stork-external
- This would allow using Chainlink's familiar interface with Stork data*

**Note:**
team@quantillon.money


## State Variables
### ORACLE_MANAGER_ROLE
Role to manage oracle configurations


```solidity
bytes32 public constant ORACLE_MANAGER_ROLE = keccak256("ORACLE_MANAGER_ROLE");
```


### EMERGENCY_ROLE
Role for emergency actions


```solidity
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
```


### UPGRADER_ROLE
Role for contract upgrades


```solidity
bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
```


### MAX_PRICE_STALENESS
Maximum duration before a price is considered stale (1 hour)

*3600 seconds = reasonable limit for real-time DeFi*


```solidity
uint256 public constant MAX_PRICE_STALENESS = 3600;
```


### MAX_PRICE_DEVIATION
Maximum allowed deviation from previous price (5%)

*500 basis points = 5% in basis points (500/10000)*


```solidity
uint256 public constant MAX_PRICE_DEVIATION = 500;
```


### BASIS_POINTS
Basis for basis points calculations


```solidity
uint256 public constant BASIS_POINTS = 10000;
```


### MAX_TIMESTAMP_DRIFT
Maximum timestamp drift tolerance (15 minutes)

*Prevents timestamp manipulation attacks by miners*


```solidity
uint256 public constant MAX_TIMESTAMP_DRIFT = 900;
```


### eurUsdPriceFeed
Interface to Stork EUR/USD price feed


```solidity
IStorkFeed public eurUsdPriceFeed;
```


### usdcUsdPriceFeed
Interface to Stork USDC/USD price feed

*Used for USDC price validation and cross-checking*


```solidity
IStorkFeed public usdcUsdPriceFeed;
```


### STORK_FEED_DECIMALS
Stork price feed decimals (constant)

*Stork feeds use 18 decimals precision (value is multiplied by 10^18)
This is verified based on Stork's documentation*


```solidity
uint8 public constant STORK_FEED_DECIMALS = 18;
```


### treasury
Treasury address for ETH recovery

*SECURITY: Only this address can receive ETH from recoverETH function*


```solidity
address public treasury;
```


### eurUsdFeedId
EUR/USD feed ID for Stork


```solidity
bytes32 public eurUsdFeedId;
```


### usdcUsdFeedId
USDC/USD feed ID for Stork


```solidity
bytes32 public usdcUsdFeedId;
```


### minEurUsdPrice
Minimum accepted EUR/USD price (lower circuit breaker)

*Initialized to 0.80 USD per EUR (extreme crisis)*


```solidity
uint256 public minEurUsdPrice;
```


### maxEurUsdPrice
Maximum accepted EUR/USD price (upper circuit breaker)

*Initialized to 1.40 USD per EUR (extreme scenario)*


```solidity
uint256 public maxEurUsdPrice;
```


### lastValidEurUsdPrice
Last valid EUR/USD price recorded (18 decimals)

*Used as fallback if oracle is down*


```solidity
uint256 public lastValidEurUsdPrice;
```


### lastPriceUpdateTime
Timestamp of the last valid price update


```solidity
uint256 public lastPriceUpdateTime;
```


### lastPriceUpdateBlock
Block number of the last valid price update

*Used for block-based staleness checks to prevent timestamp manipulation*


```solidity
uint256 public lastPriceUpdateBlock;
```


### circuitBreakerTriggered
Circuit breaker status (true = triggered, fixed prices)


```solidity
bool public circuitBreakerTriggered;
```


### usdcToleranceBps
USDC/USD tolerance (USDC should remain close to $1.00)

*200 basis points = 2% (USDC can vary between 0.98 and 1.02)*


```solidity
uint256 public usdcToleranceBps;
```


### devModeEnabled
Dev mode flag to disable spread deviation checks

*When enabled, price deviation checks are skipped (dev/testing only)*


```solidity
bool public devModeEnabled;
```


### TIME_PROVIDER
TimeProvider contract for centralized time management

*Used to replace direct block.timestamp usage for testability and consistency*


```solidity
TimeProvider public immutable TIME_PROVIDER;
```


## Functions
### constructor

Constructor for StorkOracle contract

*Initializes the TimeProvider and disables initializers for proxy pattern*

**Notes:**
- Validates TimeProvider address is not zero

- Validates _TIME_PROVIDER is not address(0)

- Sets TIME_PROVIDER immutable variable and disables initializers

- No events emitted

- Throws "Zero address" if _TIME_PROVIDER is address(0)

- Not applicable - constructor

- Public - anyone can deploy

- No oracle dependencies

- constructor


```solidity
constructor(TimeProvider _TIME_PROVIDER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_TIME_PROVIDER`|`TimeProvider`|Address of the TimeProvider contract for centralized time management|


### initialize

Initializes the oracle contract with Stork price feeds

*Sets up all core dependencies, roles, and default configuration parameters*

**Notes:**
- Validates all addresses are not zero, grants admin roles

- Validates all input addresses are not address(0)

- Initializes all state variables, sets default price bounds

- Emits PriceUpdated during initial price update

- Throws "Oracle: Admin cannot be zero" if admin is address(0)

- Protected by initializer modifier

- Public - only callable once during deployment

- Initializes Stork price feed interfaces


```solidity
function initialize(
    address admin,
    address _storkFeedAddress,
    bytes32 _eurUsdFeedId,
    bytes32 _usdcUsdFeedId,
    address _treasury
) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address with administrator privileges|
|`_storkFeedAddress`|`address`|Stork feed contract address on Base (single contract for all feeds)|
|`_eurUsdFeedId`|`bytes32`|Stork EUR/USD feed ID (bytes32)|
|`_usdcUsdFeedId`|`bytes32`|Stork USDC/USD feed ID (bytes32)|
|`_treasury`|`address`|Treasury address for ETH recovery|


### updateTreasury

Update treasury address

*SECURITY: Only admin can update treasury address*

**Notes:**
- Validates treasury address is non-zero

- Validates _treasury is not address(0)

- Updates treasury state variable

- Emits TreasuryUpdated event

- Throws if treasury is zero address

- Not protected - no external calls

- Restricted to DEFAULT_ADMIN_ROLE

- No oracle dependency


```solidity
function updateTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_treasury`|`address`|New treasury address|


### unpause

Removes pause and resumes oracle operations

*Allows emergency role to unpause the oracle after resolving issues*

**Notes:**
- Resumes oracle operations after emergency pause

- Validates contract was previously paused

- Sets paused state to false

- Emits Unpaused event

- No errors thrown

- Not protected - no external calls

- Restricted to EMERGENCY_ROLE

- Resumes normal oracle price queries


```solidity
function unpause() external onlyRole(EMERGENCY_ROLE);
```

### _divRound

Performs division with proper rounding to nearest integer

*Adds half the divisor before division to achieve proper rounding*

**Notes:**
- Validates denominator is non-zero

- Validates b > 0 to prevent division by zero

- No state changes - pure function

- No events emitted

- Throws if denominator is zero

- Not protected - pure function

- Internal - only callable within contract

- No oracle dependency


```solidity
function _divRound(uint256 a, uint256 b) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`a`|`uint256`|Numerator|
|`b`|`uint256`|Denominator|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Result of division with rounding to nearest|


### _validateTimestamp

Validates if a timestamp is recent enough to prevent manipulation attacks

*Checks timestamp is not in future and not too old beyond staleness + drift limits*

**Notes:**
- Prevents timestamp manipulation attacks by miners

- Checks timestamp is not in future and within staleness limits

- No state changes - view function

- No events emitted

- No errors thrown, returns false for invalid timestamps

- Not protected - view function

- Internal - only callable within contract

- Uses TimeProvider for current time validation


```solidity
function _validateTimestamp(uint256 reportedTime) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`reportedTime`|`uint256`|The timestamp to validate|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if the timestamp is valid, false otherwise|


### _updatePrices

Updates and validates internal prices

*Internal function called during initialization and resets, fetches fresh prices from Stork*

**Notes:**
- Validates prices, checks bounds, and triggers circuit breaker if needed

- Validates timestamp freshness, price bounds, and deviation limits

- Updates lastValidEurUsdPrice, lastPriceUpdateTime, and circuitBreakerTriggered

- Emits PriceUpdated or CircuitBreakerTriggered events

- No errors thrown, uses circuit breaker for invalid prices

- Not protected - internal function

- Internal - only callable within contract

- Fetches prices from Stork feed contracts for EUR/USD and USDC/USD


```solidity
function _updatePrices() internal;
```

### _scalePrice

Scale price to 18 decimals for consistency

*Converts Stork price from its native decimals to 18 decimals with proper rounding*

**Notes:**
- Handles negative prices by returning 0

- Validates rawPrice is positive before scaling

- No state changes - pure function

- No events emitted

- No errors thrown, returns 0 for negative prices

- Not protected - pure function

- Internal - only callable within contract

- Scales Stork price data to 18 decimals standard


```solidity
function _scalePrice(int256 rawPrice, uint8 decimals) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rawPrice`|`int256`|Raw price from Stork|
|`decimals`|`uint8`|Number of decimals in raw price|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Scaled price with 18 decimals|


### getOracleHealth

Retrieves the oracle global health status

*Checks freshness of both price feeds and overall system health*

**Notes:**
- Provides health status for monitoring and circuit breaker decisions

- Checks feed freshness, circuit breaker state, and pause status

- No state changes - view function

- No events emitted

- No errors thrown, returns false for unhealthy feeds

- Not protected - view function

- Public - no access restrictions

- Queries Stork feed contracts for EUR/USD and USDC/USD health status


```solidity
function getOracleHealth() external view returns (bool isHealthy, bool eurUsdFresh, bool usdcUsdFresh);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isHealthy`|`bool`|true if everything operates normally|
|`eurUsdFresh`|`bool`|true if EUR/USD price is fresh|
|`usdcUsdFresh`|`bool`|true if USDC/USD price is fresh|


### getEurUsdDetails

Retrieves detailed information about the EUR/USD price

*Provides comprehensive EUR/USD price information including validation status*

**Notes:**
- Provides detailed price information for debugging and monitoring

- Checks price freshness and bounds validation

- No state changes - view function

- No events emitted

- No errors thrown

- Not protected - view function

- Public - no access restrictions

- Queries Stork feed contract for detailed EUR/USD price information


```solidity
function getEurUsdDetails()
    external
    view
    returns (uint256 currentPrice, uint256 lastValidPrice, uint256 lastUpdate, bool isStale, bool withinBounds);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`currentPrice`|`uint256`|Current price (may be fallback)|
|`lastValidPrice`|`uint256`|Last validated price stored|
|`lastUpdate`|`uint256`|Timestamp of last update|
|`isStale`|`bool`|True if the feed data is stale|
|`withinBounds`|`bool`|True if within configured min/max bounds|


### getOracleConfig

Retrieves current configuration parameters

*Returns all key configuration values for oracle operations*

**Notes:**
- Returns configuration for security monitoring

- No validation - read-only configuration

- No state changes - view function

- No events emitted

- No errors thrown

- Not protected - view function

- Public - no access restrictions

- Returns configuration parameters for Stork oracle


```solidity
function getOracleConfig()
    external
    view
    returns (uint256 minPrice, uint256 maxPrice, uint256 maxStaleness, uint256 usdcTolerance, bool circuitBreakerActive);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`minPrice`|`uint256`|Minimum EUR/USD price|
|`maxPrice`|`uint256`|Maximum EUR/USD price|
|`maxStaleness`|`uint256`|Maximum duration before staleness|
|`usdcTolerance`|`uint256`|USDC tolerance in basis points|
|`circuitBreakerActive`|`bool`|Circuit breaker status|


### getPriceFeedAddresses

Retrieves addresses of the Stork price feeds used

*Returns feed addresses and their decimal configurations*

**Notes:**
- Returns feed addresses for verification

- No validation - read-only information

- No state changes - view function

- No events emitted

- No errors thrown

- Not protected - view function

- Public - no access restrictions

- Returns Stork feed contract addresses and decimals (18 for both)


```solidity
function getPriceFeedAddresses()
    external
    view
    returns (address eurUsdFeedAddress, address usdcUsdFeedAddress, uint8 eurUsdDecimals, uint8 usdcUsdDecimals);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`eurUsdFeedAddress`|`address`|EUR/USD feed address|
|`usdcUsdFeedAddress`|`address`|USDC/USD feed address|
|`eurUsdDecimals`|`uint8`|Number of decimals for the EUR/USD feed|
|`usdcUsdDecimals`|`uint8`|Number of decimals for the USDC/USD feed|


### checkPriceFeedConnectivity

Tests connectivity to the Stork price feeds

*Tests if both price feeds are responding and returns latest round information*

**Notes:**
- Tests feed connectivity for health monitoring

- No validation - connectivity test only

- No state changes - view function

- No events emitted

- No errors thrown, returns false for disconnected feeds

- Not protected - view function

- Public - no access restrictions

- Tests connectivity to Stork feed contracts for both feeds


```solidity
function checkPriceFeedConnectivity()
    external
    view
    returns (bool eurUsdConnected, bool usdcUsdConnected, uint80 eurUsdLatestRound, uint80 usdcUsdLatestRound);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`eurUsdConnected`|`bool`|true if the EUR/USD feed responds|
|`usdcUsdConnected`|`bool`|true if the USDC/USD feed responds|
|`eurUsdLatestRound`|`uint80`|Latest round ID for EUR/USD (always 0 for Stork)|
|`usdcUsdLatestRound`|`uint80`|Latest round ID for USDC/USD (always 0 for Stork)|


### _authorizeUpgrade

Authorizes oracle contract upgrades


```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|


### recoverToken

Recovers tokens accidentally sent to the contract to treasury only

*Emergency function to recover ERC20 tokens that are not part of normal operations*

**Notes:**
- Transfers tokens to treasury, prevents accidental loss

- Validates token and amount are non-zero

- Transfers tokens from contract to treasury

- Emits TokenRecovered event (via library)

- Throws if token is zero address or transfer fails

- Protected by library reentrancy guard

- Restricted to DEFAULT_ADMIN_ROLE

- No oracle dependency


```solidity
function recoverToken(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Address of the token to recover|
|`amount`|`uint256`|Amount to recover|


### recoverETH

Recover ETH to treasury address only

*SECURITY: Restricted to treasury to prevent arbitrary ETH transfers*

**Notes:**
- Transfers ETH to treasury, prevents accidental loss

- Validates contract has ETH balance

- Transfers ETH from contract to treasury

- Emits ETHRecovered event

- Throws if transfer fails

- Protected by library reentrancy guard

- Restricted to DEFAULT_ADMIN_ROLE

- No oracle dependency


```solidity
function recoverETH() external onlyRole(DEFAULT_ADMIN_ROLE);
```

### resetCircuitBreaker

Resets the circuit breaker and resumes oracle usage

*Emergency action after resolving an incident.
Restarts price updates and disables fallback mode.*

**Notes:**
- Resets circuit breaker after manual intervention

- Validates circuit breaker was previously triggered

- Resets circuitBreakerTriggered flag and updates prices

- Emits CircuitBreakerReset event

- No errors thrown

- Protected by reentrancy guard

- Restricted to EMERGENCY_ROLE

- Resumes normal Stork oracle price queries


```solidity
function resetCircuitBreaker() external onlyRole(EMERGENCY_ROLE);
```

### triggerCircuitBreaker

Manually triggers the circuit breaker

*Used when the team detects an issue with the oracles.
Forces the use of the last known valid price.*

**Notes:**
- Manually activates circuit breaker for emergency situations

- No validation - emergency function

- Sets circuitBreakerTriggered flag to true

- Emits CircuitBreakerTriggered event

- No errors thrown

- Not protected - no external calls

- Restricted to EMERGENCY_ROLE

- Switches to fallback prices instead of live Stork oracle queries


```solidity
function triggerCircuitBreaker() external onlyRole(EMERGENCY_ROLE);
```

### pause

Pauses all oracle operations

*Emergency function to pause oracle in case of critical issues*

**Notes:**
- Emergency pause to halt all oracle operations

- No validation - emergency function

- Sets paused state to true

- Emits Paused event

- No errors thrown

- Not protected - no external calls

- Restricted to EMERGENCY_ROLE

- Halts all Stork oracle price queries


```solidity
function pause() external onlyRole(EMERGENCY_ROLE);
```

### getEurUsdPrice

Retrieves the current EUR/USD price with full validation

*Validation process:
1. Check circuit breaker status
2. Fetch from Stork
3. Freshness check (< 1 hour)
4. Convert to 18 decimals
5. Check min/max bounds
6. Return valid price or fallback*

**Notes:**
- Validates price freshness and bounds before returning

- Checks price staleness, circuit breaker state, and bounds

- No state changes - view function

- No events emitted

- No errors thrown, returns isValid=false for invalid prices

- Not protected - view function

- Public - no access restrictions

- Queries Stork feed contract for EUR/USD price


```solidity
function getEurUsdPrice() external view returns (uint256 price, bool isValid);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|EUR/USD price in 18 decimals (e.g., 1.10e18 = 1.10 USD per EUR)|
|`isValid`|`bool`|true if the price is fresh and within acceptable bounds|


### getUsdcUsdPrice

Retrieves the USDC/USD price with validation

*USDC is expected to maintain parity with USD.
A large deviation indicates a systemic issue.*

**Notes:**
- Validates price is within tolerance of $1.00

- Checks price staleness and deviation from $1.00

- No state changes - view function

- No events emitted

- No errors thrown, returns isValid=false for invalid prices

- Not protected - view function

- Public - no access restrictions

- Queries Stork feed contract for USDC/USD price


```solidity
function getUsdcUsdPrice() external view returns (uint256 price, bool isValid);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|USDC/USD price in 18 decimals (should be close to 1.0e18)|
|`isValid`|`bool`|true if USDC remains close to $1.00|


### updatePriceBounds

Updates price bounds for the circuit breaker

*Allows oracle manager to adjust price thresholds based on market conditions*

**Notes:**
- Validates min < max and reasonable bounds

- Validates price bounds are within acceptable range

- Updates minEurUsdPrice and maxEurUsdPrice state variables

- Emits PriceBoundsUpdated event

- Throws if minPrice >= maxPrice or invalid bounds

- Protected by reentrancy guard

- Restricted to ORACLE_MANAGER_ROLE

- No oracle dependency - configuration update only


```solidity
function updatePriceBounds(uint256 _minPrice, uint256 _maxPrice) external onlyRole(ORACLE_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_minPrice`|`uint256`|Minimum accepted EUR/USD price (18 decimals)|
|`_maxPrice`|`uint256`|Maximum accepted EUR/USD price (18 decimals)|


### updateUsdcTolerance

Updates the tolerance for USDC/USD

*Allows oracle manager to adjust USDC price tolerance around $1.00*

**Notes:**
- Validates tolerance is within reasonable limits

- Validates tolerance is not zero and within max bounds (10%)

- Updates usdcToleranceBps state variable

- No events emitted

- Throws if tolerance is invalid or out of bounds

- Protected by reentrancy guard

- Restricted to ORACLE_MANAGER_ROLE

- No oracle dependency - configuration update only


```solidity
function updateUsdcTolerance(uint256 newToleranceBps) external onlyRole(ORACLE_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newToleranceBps`|`uint256`|New tolerance in basis points (e.g., 200 = 2%)|


### updatePriceFeeds

Updates the Stork feed address and feed IDs

*Allows oracle manager to update feed address and feed IDs for maintenance or upgrades
Note: Stork uses a single contract address with different feed IDs*

**Notes:**
- Validates feed address is non-zero and contract exists

- Validates all addresses are not address(0)

- Updates eurUsdPriceFeed, usdcUsdPriceFeed, and feed IDs

- Emits PriceFeedsUpdated event

- Throws if feed address is zero or invalid

- Protected by reentrancy guard

- Restricted to ORACLE_MANAGER_ROLE

- Updates Stork feed contract references


```solidity
function updatePriceFeeds(address _storkFeedAddress, bytes32 _eurUsdFeedId, bytes32 _usdcUsdFeedId)
    external
    onlyRole(ORACLE_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_storkFeedAddress`|`address`|New Stork feed contract address|
|`_eurUsdFeedId`|`bytes32`|New EUR/USD feed ID|
|`_usdcUsdFeedId`|`bytes32`|New USDC/USD feed ID|


### setDevMode

Toggles dev mode to disable spread deviation checks

Toggles dev mode to disable price deviation checks

*DEV ONLY: When enabled, price deviation checks are skipped for testing*

*Dev mode allows testing with price deviations that would normally trigger circuit breaker*

**Notes:**
- Disables price deviation checks - use only for testing

- No validation - admin function

- Updates devModeEnabled flag

- Emits DevModeToggled event

- No errors thrown

- Not protected - no external calls

- Restricted to DEFAULT_ADMIN_ROLE

- No oracle dependency - configuration update only


```solidity
function setDevMode(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`enabled`|`bool`|True to enable dev mode, false to disable|


## Events
### PriceUpdated
Emitted on each valid price update

*OPTIMIZED: Indexed timestamp for efficient time-based filtering*


```solidity
event PriceUpdated(uint256 eurUsdPrice, uint256 usdcUsdPrice, uint256 indexed timestamp);
```

### CircuitBreakerTriggered
Emitted when the circuit breaker is triggered

*OPTIMIZED: Indexed reason for efficient filtering by trigger type*


```solidity
event CircuitBreakerTriggered(uint256 attemptedPrice, uint256 lastValidPrice, string indexed reason);
```

### CircuitBreakerReset
Emitted when the circuit breaker is reset


```solidity
event CircuitBreakerReset(address indexed admin);
```

### PriceBoundsUpdated
Emitted when price bounds are modified

*OPTIMIZED: Indexed bound type for efficient filtering*


```solidity
event PriceBoundsUpdated(string indexed boundType, uint256 newMinPrice, uint256 newMaxPrice);
```

### PriceFeedsUpdated
Emitted when price feed addresses are updated


```solidity
event PriceFeedsUpdated(
    address newEurUsdFeed, address newUsdcUsdFeed, bytes32 newEurUsdFeedId, bytes32 newUsdcUsdFeedId
);
```

### TreasuryUpdated
Emitted when treasury address is updated


```solidity
event TreasuryUpdated(address indexed newTreasury);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newTreasury`|`address`|New treasury address|

### ETHRecovered
Emitted when ETH is recovered from the contract


```solidity
event ETHRecovered(address indexed to, uint256 amount);
```

### DevModeToggled
Emitted when dev mode is toggled


```solidity
event DevModeToggled(bool enabled, address indexed caller);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`enabled`|`bool`|Whether dev mode is enabled or disabled|
|`caller`|`address`|Address that triggered the toggle|

