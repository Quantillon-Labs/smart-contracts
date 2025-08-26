# ChainlinkOracle
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/0f0dbb121f43b13af9ae20daf5712ecd7ace5cc7/src/oracle/ChainlinkOracle.sol)

**Inherits:**
Initializable, AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable

**Author:**
Quantillon Labs

EUR/USD and USDC/USD price manager for Quantillon Protocol

*Key features:
- Fetch EUR/USD price from Chainlink
- Validate USDC/USD (should remain close to $1.00)
- Circuit breakers against outlier prices
- Fallbacks in case of oracle outage
- Data freshness checks*

**Note:**
security-contact: team@quantillon.money


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


### eurUsdPriceFeed
Interface to Chainlink EUR/USD price feed


```solidity
AggregatorV3Interface public eurUsdPriceFeed;
```


### usdcUsdPriceFeed
Interface to Chainlink USDC/USD price feed


```solidity
AggregatorV3Interface public usdcUsdPriceFeed;
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


## Functions
### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### initialize

Initializes the oracle contract with Chainlink price feeds

*This function:
1. Configures access roles
2. Initializes Chainlink interfaces
3. Sets default price bounds
4. Performs an initial price update*


```solidity
function initialize(address admin, address _eurUsdPriceFeed, address _usdcUsdPriceFeed) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address with administrator privileges|
|`_eurUsdPriceFeed`|`address`|Chainlink EUR/USD price feed address on Base|
|`_usdcUsdPriceFeed`|`address`|Chainlink USDC/USD price feed address on Base|


### unpause

Removes pause and resumes oracle operations


```solidity
function unpause() external onlyRole(EMERGENCY_ROLE);
```

### _divRound

Performs division with proper rounding to nearest integer


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


### _updatePrices

Updates and validates internal prices

*Internal function called during initialization and resets*

*FIXED: No longer calls external functions on itself during initialization*


```solidity
function _updatePrices() internal;
```

### _scalePrice

Scale price to 18 decimals for consistency

*FIXED: Now scales to 18 decimals instead of 8 to match contract expectations*


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

*Used by UI and monitoring systems to display real-time status*

*FIXED: No longer calls external functions on itself*


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

Recovers tokens accidentally sent to the contract


```solidity
function recoverToken(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Address of the token to recover|
|`to`|`address`|Recipient address|
|`amount`|`uint256`|Amount to recover|


### recoverETH

Recovers ETH accidentally sent to the oracle contract

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
|`to`|`address payable`|Recipient address|


### resetCircuitBreaker

Resets the circuit breaker and resumes oracle usage

*Emergency action after resolving an incident.
Restarts price updates and disables fallback mode.*


```solidity
function resetCircuitBreaker() external onlyRole(EMERGENCY_ROLE);
```

### triggerCircuitBreaker

Manually triggers the circuit breaker

*Used when the team detects an issue with the oracles.
Forces the use of the last known valid price.*


```solidity
function triggerCircuitBreaker() external onlyRole(EMERGENCY_ROLE);
```

### pause

Pauses all oracle operations


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

*Used to adjust thresholds according to market conditions.
Example: widen the range during a crisis.*


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


```solidity
function updateUsdcTolerance(uint256 newToleranceBps) external onlyRole(ORACLE_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newToleranceBps`|`uint256`|New tolerance in basis points|


### updatePriceFeeds

Updates the Chainlink price feed addresses

*Used if Chainlink updates its contracts or to switch to newer, more precise feeds*


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


```solidity
event PriceUpdated(uint256 eurUsdPrice, uint256 usdcUsdPrice, uint256 timestamp);
```

### CircuitBreakerTriggered
Emitted when the circuit breaker is triggered


```solidity
event CircuitBreakerTriggered(uint256 attemptedPrice, uint256 lastValidPrice, string reason);
```

### CircuitBreakerReset
Emitted when the circuit breaker is reset


```solidity
event CircuitBreakerReset(address indexed admin);
```

### PriceBoundsUpdated
Emitted when price bounds are modified


```solidity
event PriceBoundsUpdated(uint256 newMinPrice, uint256 newMaxPrice);
```

### PriceFeedsUpdated
Emitted when price feed addresses are updated


```solidity
event PriceFeedsUpdated(address newEurUsdFeed, address newUsdcUsdFeed);
```

