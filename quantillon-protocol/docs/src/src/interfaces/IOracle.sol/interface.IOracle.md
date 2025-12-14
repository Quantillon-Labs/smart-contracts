# IOracle
**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Generic interface for Quantillon Protocol oracle contracts

*This interface is oracle-agnostic and can work with Chainlink, Stork, or any other oracle implementation
The OracleRouter implements this interface and delegates to the active oracle (Chainlink or Stork)*

**Note:**
team@quantillon.money


## Functions
### getEurUsdPrice

Gets the current EUR/USD price with validation

*Retrieves and validates EUR/USD price from the active oracle with freshness checks*

**Notes:**
- Validates price freshness and bounds before returning

- Checks price staleness and circuit breaker state

- May update lastValidPrice if price is valid

- No events emitted

- No errors thrown, returns isValid=false for invalid prices

- Not protected - read-only operation

- Public - no access restrictions

- Queries active oracle (Chainlink or Stork) for EUR/USD price


```solidity
function getEurUsdPrice() external returns (uint256 price, bool isValid);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|EUR/USD price in 18 decimals|
|`isValid`|`bool`|True if fresh and within acceptable bounds|


### getUsdcUsdPrice

Gets the current USDC/USD price with validation

*Retrieves and validates USDC/USD price from the active oracle with tolerance checks*

**Notes:**
- Validates price is within tolerance of $1.00

- Checks price staleness and deviation from $1.00

- No state changes - view function

- No events emitted

- No errors thrown, returns isValid=false for invalid prices

- Not protected - view function

- Public - no access restrictions

- Queries active oracle (Chainlink or Stork) for USDC/USD price


```solidity
function getUsdcUsdPrice() external view returns (uint256 price, bool isValid);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|USDC/USD price in 18 decimals (should be ~1e18)|
|`isValid`|`bool`|True if fresh and within tolerance|


### getOracleHealth

Returns overall oracle health signals

*Checks the health status of both price feeds and overall oracle state*

**Notes:**
- Provides health status for monitoring and circuit breaker decisions

- Checks feed freshness, circuit breaker state, and pause status

- May update internal state during health check

- No events emitted

- No errors thrown

- Not protected - read-only operation

- Public - no access restrictions

- Queries active oracle health status for both feeds


```solidity
function getOracleHealth() external returns (bool isHealthy, bool eurUsdFresh, bool usdcUsdFresh);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isHealthy`|`bool`|True if both feeds are fresh, circuit breaker is off, and not paused|
|`eurUsdFresh`|`bool`|True if EUR/USD feed is fresh|
|`usdcUsdFresh`|`bool`|True if USDC/USD feed is fresh|


### getEurUsdDetails

Detailed information about the EUR/USD price

*Provides comprehensive EUR/USD price information including validation status*

**Notes:**
- Provides detailed price information for debugging and monitoring

- Checks price freshness and bounds validation

- May update internal state during price check

- No events emitted

- No errors thrown

- Not protected - read-only operation

- Public - no access restrictions

- Queries active oracle for detailed EUR/USD price information


```solidity
function getEurUsdDetails()
    external
    returns (uint256 currentPrice, uint256 lastValidPrice, uint256 lastUpdate, bool isStale, bool withinBounds);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`currentPrice`|`uint256`|Current price (may be fallback)|
|`lastValidPrice`|`uint256`|Last validated price stored|
|`lastUpdate`|`uint256`|Timestamp of last successful update|
|`isStale`|`bool`|True if the feed data is stale|
|`withinBounds`|`bool`|True if within configured min/max bounds|


### getOracleConfig

Current configuration and circuit breaker state

*Returns current oracle configuration parameters and circuit breaker status*

**Notes:**
- Returns configuration for security monitoring

- No validation - read-only configuration

- No state changes - view function

- No events emitted

- No errors thrown

- Not protected - view function

- Public - no access restrictions

- Returns configuration from active oracle


```solidity
function getOracleConfig()
    external
    view
    returns (uint256 minPrice, uint256 maxPrice, uint256 maxStaleness, uint256 usdcTolerance, bool circuitBreakerActive);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`minPrice`|`uint256`|Minimum accepted EUR/USD price|
|`maxPrice`|`uint256`|Maximum accepted EUR/USD price|
|`maxStaleness`|`uint256`|Maximum allowed staleness in seconds|
|`usdcTolerance`|`uint256`|USDC tolerance in basis points|
|`circuitBreakerActive`|`bool`|True if circuit breaker is triggered|


### getPriceFeedAddresses

Addresses and decimals of the underlying feeds

*Returns the addresses and decimal precision of both price feeds*

**Notes:**
- Returns feed addresses for verification

- No validation - read-only information

- No state changes - view function

- No events emitted

- No errors thrown

- Not protected - view function

- Public - no access restrictions

- Returns feed addresses from active oracle


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
|`eurUsdDecimals`|`uint8`|EUR/USD feed decimals|
|`usdcUsdDecimals`|`uint8`|USDC/USD feed decimals|


### checkPriceFeedConnectivity

Connectivity check for both feeds

*Tests connectivity to both price feeds and returns latest round information*

**Notes:**
- Tests feed connectivity for health monitoring

- No validation - connectivity test only

- No state changes - view function

- No events emitted

- No errors thrown, returns false for disconnected feeds

- Not protected - view function

- Public - no access restrictions

- Tests connectivity to active oracle feeds


```solidity
function checkPriceFeedConnectivity()
    external
    view
    returns (bool eurUsdConnected, bool usdcUsdConnected, uint80 eurUsdLatestRound, uint80 usdcUsdLatestRound);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`eurUsdConnected`|`bool`|True if EUR/USD feed responds|
|`usdcUsdConnected`|`bool`|True if USDC/USD feed responds|
|`eurUsdLatestRound`|`uint80`|Latest round ID for EUR/USD (0 for non-round-based oracles)|
|`usdcUsdLatestRound`|`uint80`|Latest round ID for USDC/USD (0 for non-round-based oracles)|


