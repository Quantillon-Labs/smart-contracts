# IChainlinkOracle
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/d9b318c983e96e686dbdeddf2128adc1d9fdfb49/src/interfaces/IChainlinkOracle.sol)

**Author:**
Quantillon Labs

Interface for the Quantillon Chainlink-based oracle

*Exposes read methods for prices and health, plus admin/emergency controls*

**Note:**
security-contact: team@quantillon.money


## Functions
### initialize

Initializes the oracle with admin and feed addresses


```solidity
function initialize(address admin, address _eurUsdPriceFeed, address _usdcUsdPriceFeed) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address that receives admin and manager roles|
|`_eurUsdPriceFeed`|`address`|Chainlink EUR/USD feed address|
|`_usdcUsdPriceFeed`|`address`|Chainlink USDC/USD feed address|


### getEurUsdPrice

Gets the current EUR/USD price with validation


```solidity
function getEurUsdPrice() external view returns (uint256 price, bool isValid);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|EUR/USD price in 18 decimals|
|`isValid`|`bool`|True if fresh and within acceptable bounds|


### getUsdcUsdPrice

Gets the current USDC/USD price with validation


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


```solidity
function getOracleHealth() external view returns (bool isHealthy, bool eurUsdFresh, bool usdcUsdFresh);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isHealthy`|`bool`|True if both feeds are fresh, circuit breaker is off, and not paused|
|`eurUsdFresh`|`bool`|True if EUR/USD feed is fresh|
|`usdcUsdFresh`|`bool`|True if USDC/USD feed is fresh|


### getEurUsdDetails

Detailed information about the EUR/USD price


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
|`lastUpdate`|`uint256`|Timestamp of last successful update|
|`isStale`|`bool`|True if the feed data is stale|
|`withinBounds`|`bool`|True if within configured min/max bounds|


### getOracleConfig

Current configuration and circuit breaker state


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


### testPriceFeedConnectivity

Connectivity check for both feeds


```solidity
function testPriceFeedConnectivity()
    external
    view
    returns (bool eurUsdConnected, bool usdcUsdConnected, uint80 eurUsdLatestRound, uint80 usdcUsdLatestRound);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`eurUsdConnected`|`bool`|True if EUR/USD feed responds|
|`usdcUsdConnected`|`bool`|True if USDC/USD feed responds|
|`eurUsdLatestRound`|`uint80`|Latest round ID for EUR/USD|
|`usdcUsdLatestRound`|`uint80`|Latest round ID for USDC/USD|


### updatePriceBounds

Updates EUR/USD min and max acceptable prices


```solidity
function updatePriceBounds(uint256 _minPrice, uint256 _maxPrice) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_minPrice`|`uint256`|New minimum price (18 decimals)|
|`_maxPrice`|`uint256`|New maximum price (18 decimals)|


### updateUsdcTolerance

Updates the allowed USDC deviation from $1.00 in basis points


```solidity
function updateUsdcTolerance(uint256 newToleranceBps) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newToleranceBps`|`uint256`|New tolerance (e.g., 200 = 2%)|


### updatePriceFeeds

Updates Chainlink feed addresses


```solidity
function updatePriceFeeds(address _eurUsdFeed, address _usdcUsdFeed) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_eurUsdFeed`|`address`|New EUR/USD feed|
|`_usdcUsdFeed`|`address`|New USDC/USD feed|


### resetCircuitBreaker

Clears circuit breaker and attempts to resume live prices


```solidity
function resetCircuitBreaker() external;
```

### triggerCircuitBreaker

Manually triggers circuit breaker to use fallback prices


```solidity
function triggerCircuitBreaker() external;
```

### pause

Pauses all oracle operations


```solidity
function pause() external;
```

### unpause

Unpauses oracle operations


```solidity
function unpause() external;
```

### recoverToken

Recovers ERC20 tokens sent to the oracle contract by mistake


```solidity
function recoverToken(address token, address to, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address to recover|
|`to`|`address`|Recipient address|
|`amount`|`uint256`|Amount to transfer|


### recoverETH

Recovers ETH sent to the oracle contract by mistake


```solidity
function recoverETH(address payable to) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address payable`|Recipient address|


