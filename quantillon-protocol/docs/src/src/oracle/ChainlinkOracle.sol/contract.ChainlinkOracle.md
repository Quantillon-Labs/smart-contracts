# ChainlinkOracle
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/daf8385bca354b97ae7c7df1c5a1c4bdeadbab9f/src/oracle/ChainlinkOracle.sol)

**Inherits:**
[IChainlinkOracle](/src/interfaces/IChainlinkOracle.sol/interface.IChainlinkOracle.md), Initializable, AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

EUR/USD and USDC/USD price manager for Quantillon Protocol

*Key features:
- Fetch EUR/USD price from Chainlink
- Validate USDC/USD (should remain close to $1.00)
- Circuit breakers against outlier prices
- Fallbacks in case of oracle outage
- Data freshness checks*

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


### BLOCKS_PER_HOUR
Blocks per hour for block-based staleness checks

*~12 second blocks on Ethereum, ~2 second blocks on L2s*


```solidity
uint256 public constant BLOCKS_PER_HOUR = 300;
```


### eurUsdPriceFeed
Interface to Chainlink EUR/USD price feed


```solidity
AggregatorV3Interface public eurUsdPriceFeed;
```


### usdcUsdPriceFeed
Interface to Chainlink USDC/USD price feed

*Used for USDC price validation and cross-checking*

*Should be the official USDC/USD Chainlink feed*


```solidity
AggregatorV3Interface public usdcUsdPriceFeed;
```


### treasury
Treasury address for ETH recovery

*SECURITY: Only this address can receive ETH from recoverETH function*


```solidity
address public treasury;
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


### TIME_PROVIDER
TimeProvider contract for centralized time management

*Used to replace direct block.timestamp usage for testability and consistency*


```solidity
TimeProvider public immutable TIME_PROVIDER;
```


## Functions
### constructor

Constructor for ChainlinkOracle contract

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

Initializes the oracle contract with Chainlink price feeds

*Sets up all core dependencies, roles, and default configuration parameters*

**Notes:**
- Validates all addresses are not zero, grants admin roles

- Validates all input addresses are not address(0)

- Initializes all state variables, sets default price bounds

- Emits PriceUpdated during initial price update

- Throws "Oracle: Admin cannot be zero" if admin is address(0)

- Protected by initializer modifier

- Public - only callable once during deployment

- Initializes Chainlink price feed interfaces


```solidity
function initialize(address admin, address _eurUsdPriceFeed, address _usdcUsdPriceFeed, address _treasury)
    public
    initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address with administrator privileges|
|`_eurUsdPriceFeed`|`address`|Chainlink EUR/USD price feed address on Base|
|`_usdcUsdPriceFeed`|`address`|Chainlink USDC/USD price feed address on Base|
|`_treasury`|`address`|Treasury address for ETH recovery|


### updateTreasury

Update treasury address

*SECURITY: Only admin can update treasury address*

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
- Validates emergency role authorization

- No input validation required

- Removes pause state, resumes oracle operations

- Emits Unpaused event from OpenZeppelin

- No errors thrown - safe unpause operation

- Not protected - no external calls

- Restricted to EMERGENCY_ROLE

- No oracle dependencies for unpause


```solidity
function unpause() external onlyRole(EMERGENCY_ROLE);
```

### _divRound

Performs division with proper rounding to nearest integer

*Adds half the divisor before division to achieve proper rounding*

**Notes:**
- Validates denominator is not zero to prevent division by zero

- Validates b > 0

- No state changes - pure function

- No events emitted

- Throws "Oracle: Division by zero" if b is 0

- Not applicable - pure function

- Internal function - no access restrictions

- No oracle dependencies


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
- Validates timestamp is not in future and within acceptable age

- Validates reportedTime <= currentTime and within MAX_PRICE_STALENESS + MAX_TIMESTAMP_DRIFT

- No state changes - view function

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Internal function - no access restrictions

- No oracle dependencies for timestamp validation


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

*Internal function called during initialization and resets, fetches fresh prices from Chainlink*

**Notes:**
- Validates price data integrity, circuit breaker bounds, and deviation limits

- Validates roundId == answeredInRound, startedAt <= updatedAt, price > 0

- Updates lastValidEurUsdPrice, lastPriceUpdateTime, lastPriceUpdateBlock

- Emits PriceUpdated with current prices or CircuitBreakerTriggered if invalid

- Throws "EUR/USD price data is stale" if roundId != answeredInRound

- Not protected - internal function only

- Internal function - no access restrictions

- Fetches fresh prices from Chainlink EUR/USD and USDC/USD feeds


```solidity
function _updatePrices() internal;
```

### _scalePrice

Scale price to 18 decimals for consistency

*Converts Chainlink price from its native decimals to 18 decimals with proper rounding*

**Notes:**
- Validates rawPrice > 0 and handles decimal conversion safely

- Validates rawPrice > 0, returns 0 if invalid

- No state changes - pure function

- No events emitted

- No errors thrown - safe arithmetic used

- Not applicable - pure function

- Internal function - no access restrictions

- No oracle dependencies for price scaling


```solidity
function _scalePrice(int256 rawPrice, uint8 decimals) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rawPrice`|`int256`|Raw price from Chainlink|
|`decimals`|`uint8`|Number of decimals in raw price|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Scaled price with 18 decimals|


### getOracleHealth

Retrieves the oracle global health status

*Checks freshness of both price feeds and overall system health*

**Notes:**
- Validates price feed connectivity and data integrity

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function with try/catch

- Not applicable - view function

- Public - anyone can check oracle health

- Checks connectivity to Chainlink EUR/USD and USDC/USD feeds


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

*Provides comprehensive EUR/USD price data including staleness and bounds checks*

**Notes:**
- Validates price feed data integrity and circuit breaker status

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function with try/catch

- Not applicable - view function

- Public - anyone can query EUR/USD details

- Fetches fresh data from Chainlink EUR/USD price feed


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
|`lastValidPrice`|`uint256`|Last validated price|
|`lastUpdate`|`uint256`|Timestamp of last update|
|`isStale`|`bool`|true if the price is stale|
|`withinBounds`|`bool`|true if within acceptable bounds|


### getOracleConfig

Retrieves current configuration parameters

*Returns all key configuration values for oracle operations*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query configuration

- No oracle dependencies for configuration query


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

Retrieves addresses of the Chainlink price feeds used

*Returns feed addresses and their decimal configurations*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query feed addresses

- Queries decimal configuration from Chainlink feeds


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

Tests connectivity to the Chainlink price feeds

*Tests if both price feeds are responding and returns latest round information*

**Notes:**
- Validates price feed connectivity and data integrity

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function with try/catch

- Not applicable - view function

- Public - anyone can test feed connectivity

- Tests connectivity to Chainlink EUR/USD and USDC/USD feeds


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
|`eurUsdLatestRound`|`uint80`|Latest round ID for EUR/USD|
|`usdcUsdLatestRound`|`uint80`|Latest round ID for USDC/USD|


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
- Validates admin role and uses secure recovery library

- No input validation required - library handles validation

- Transfers tokens from contract to treasury

- No events emitted - library handles events

- No errors thrown - library handles error cases

- Not protected - library handles reentrancy

- Restricted to DEFAULT_ADMIN_ROLE

- No oracle dependencies for token recovery


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

*Security considerations:
- Only DEFAULT_ADMIN_ROLE can recover
- Prevents sending to zero address
- Validates balance before attempting transfer
- Uses call() for reliable ETH transfers to any contract*

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
function recoverETH() external onlyRole(DEFAULT_ADMIN_ROLE);
```

### resetCircuitBreaker

Resets the circuit breaker and resumes oracle usage

*Emergency action after resolving an incident.
Restarts price updates and disables fallback mode.*

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
function resetCircuitBreaker() external onlyRole(EMERGENCY_ROLE);
```

### triggerCircuitBreaker

Manually triggers the circuit breaker

*Used when the team detects an issue with the oracles.
Forces the use of the last known valid price.*

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
function triggerCircuitBreaker() external onlyRole(EMERGENCY_ROLE);
```

### pause

Pauses all oracle operations

*Emergency function to pause oracle in case of critical issues*

**Notes:**
- Validates emergency role authorization

- No input validation required

- Sets pause state, stops oracle operations

- Emits Paused event from OpenZeppelin

- No errors thrown - safe pause operation

- Not protected - no external calls

- Restricted to EMERGENCY_ROLE

- No oracle dependencies for pause


```solidity
function pause() external onlyRole(EMERGENCY_ROLE);
```

### getEurUsdPrice

Retrieves the current EUR/USD price with full validation

*Validation process:
1. Check circuit breaker status
2. Fetch from Chainlink
3. Freshness check (< 1 hour)
4. Convert to 18 decimals
5. Check min/max bounds
6. Return valid price or fallback*

**Notes:**
- Validates timestamp freshness, circuit breaker status, price bounds

- Checks price > 0, timestamp < 1 hour old, within min/max bounds

- No state changes - view function only

- No events emitted

- No errors thrown - returns fallback price if invalid

- Not applicable - view function

- Public - no access restrictions

- Requires fresh Chainlink EUR/USD price feed data


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
- Validates timestamp freshness, USDC tolerance bounds

- Checks price > 0, timestamp < 1 hour old, within USDC tolerance

- No state changes - view function only

- No events emitted

- No errors thrown - returns $1.00 fallback if invalid

- Not applicable - view function

- Public - no access restrictions

- Requires fresh Chainlink USDC/USD price feed data


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
- Validates oracle manager role and price bounds constraints

- Validates _minPrice > 0, _maxPrice > _minPrice, _maxPrice < 10e18

- Updates minEurUsdPrice and maxEurUsdPrice

- Emits PriceBoundsUpdated with new bounds

- Throws "Oracle: Min price must be positive" if _minPrice <= 0

- Not protected - no external calls

- Restricted to ORACLE_MANAGER_ROLE

- No oracle dependencies for bounds update


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
- Validates oracle manager role and tolerance constraints

- Validates newToleranceBps <= 1000 (max 10%)

- Updates usdcToleranceBps

- No events emitted for tolerance update

- Throws "Oracle: Tolerance too high" if newToleranceBps > 1000

- Not protected - no external calls

- Restricted to ORACLE_MANAGER_ROLE

- No oracle dependencies for tolerance update


```solidity
function updateUsdcTolerance(uint256 newToleranceBps) external onlyRole(ORACLE_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newToleranceBps`|`uint256`|New tolerance in basis points (e.g., 200 = 2%)|


### updatePriceFeeds

Updates the Chainlink price feed addresses

*Allows oracle manager to update price feed addresses for maintenance or upgrades*

**Notes:**
- Validates oracle manager role and feed address constraints

- Validates both feed addresses are not address(0)

- Updates eurUsdPriceFeed and usdcUsdPriceFeed interfaces

- Emits PriceFeedsUpdated with new feed addresses

- Throws "Oracle: EUR/USD feed cannot be zero" if _eurUsdFeed is address(0)

- Not protected - no external calls

- Restricted to ORACLE_MANAGER_ROLE

- Updates Chainlink price feed interface addresses


```solidity
function updatePriceFeeds(address _eurUsdFeed, address _usdcUsdFeed) external onlyRole(ORACLE_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_eurUsdFeed`|`address`|New EUR/USD feed address|
|`_usdcUsdFeed`|`address`|New USDC/USD feed address|


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
event PriceFeedsUpdated(address newEurUsdFeed, address newUsdcUsdFeed);
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

