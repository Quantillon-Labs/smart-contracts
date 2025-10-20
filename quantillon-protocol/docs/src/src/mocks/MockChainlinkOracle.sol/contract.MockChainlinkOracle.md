# MockChainlinkOracle
**Inherits:**
[IChainlinkOracle](/src/interfaces/IChainlinkOracle.sol/interface.IChainlinkOracle.md), Initializable, AccessControlUpgradeable, PausableUpgradeable

**Author:**
Quantillon Labs

Mock oracle that implements IChainlinkOracle interface but uses mock feeds

*Used for localhost testing - provides same interface as ChainlinkOracle*


## State Variables
### EMERGENCY_ROLE

```solidity
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
```


### eurUsdPriceFeed

```solidity
AggregatorV3Interface public eurUsdPriceFeed;
```


### usdcUsdPriceFeed

```solidity
AggregatorV3Interface public usdcUsdPriceFeed;
```


### treasury

```solidity
address public treasury;
```


### originalAdmin

```solidity
address private originalAdmin;
```


### MIN_EUR_USD_PRICE

```solidity
uint256 public constant MIN_EUR_USD_PRICE = 0.5e18;
```


### MAX_EUR_USD_PRICE

```solidity
uint256 public constant MAX_EUR_USD_PRICE = 2.0e18;
```


### MIN_USDC_USD_PRICE

```solidity
uint256 public constant MIN_USDC_USD_PRICE = 0.95e18;
```


### MAX_USDC_USD_PRICE

```solidity
uint256 public constant MAX_USDC_USD_PRICE = 1.05e18;
```


### MAX_PRICE_DEVIATION

```solidity
uint256 public constant MAX_PRICE_DEVIATION = 500;
```


### lastValidEurUsdPrice

```solidity
uint256 public lastValidEurUsdPrice;
```


### lastValidUsdcUsdPrice

```solidity
uint256 public lastValidUsdcUsdPrice;
```


### lastPriceUpdateBlock

```solidity
uint256 public lastPriceUpdateBlock;
```


### MIN_BLOCKS_BETWEEN_UPDATES

```solidity
uint256 public constant MIN_BLOCKS_BETWEEN_UPDATES = 1;
```


### circuitBreakerTriggered

```solidity
bool public circuitBreakerTriggered;
```


## Functions
### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### initialize

Initializes the mock oracle


```solidity
function initialize(address admin, address _eurUsdPriceFeed, address _usdcUsdPriceFeed, address) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Admin address|
|`_eurUsdPriceFeed`|`address`|Mock EUR/USD feed address|
|`_usdcUsdPriceFeed`|`address`|Mock USDC/USD feed address|
|`<none>`|`address`||


### getEurUsdPrice

Gets the current EUR/USD price with validation and auto-updates lastValidEurUsdPrice


```solidity
function getEurUsdPrice() external view override returns (uint256 price, bool isValid);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|EUR/USD price in 18 decimals|
|`isValid`|`bool`|True if price is valid and fresh|


### getUsdcUsdPrice

Gets the current USDC/USD price with validation


```solidity
function getUsdcUsdPrice() external view override returns (uint256 price, bool isValid);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|USDC/USD price in 18 decimals|
|`isValid`|`bool`|True if price is valid and fresh|


### _updatePrices

Updates prices and validates them

*Internal function to update and validate current prices*


```solidity
function _updatePrices() internal;
```

### _calculateEurUsdPrice

Internal function to calculate EUR/USD price

*Avoids external calls to prevent reentrancy*


```solidity
function _calculateEurUsdPrice() internal pure returns (uint256);
```

### _calculateUsdcUsdPrice

Internal function to calculate USDC/USD price

*Avoids external calls to prevent reentrancy*


```solidity
function _calculateUsdcUsdPrice() internal pure returns (uint256);
```

### _scalePrice

Scales price from feed decimals to 18 decimals


```solidity
function _scalePrice(int256 price, uint8 feedDecimals) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`price`|`int256`|Price from feed|
|`feedDecimals`|`uint8`|Number of decimals in the feed|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Scaled price in 18 decimals|


### _divRound

Divides with rounding


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
|`<none>`|`uint256`|Result with rounding|


### updateTreasury

Updates treasury address

*Treasury can only be updated to the original admin address to prevent arbitrary sends*


```solidity
function updateTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_treasury`|`address`|New treasury address|


### unpause

Unpauses the contract


```solidity
function unpause() external onlyRole(EMERGENCY_ROLE);
```

### recoverETH

Recovers ETH sent to the contract

*Only sends ETH to the original admin address to prevent arbitrary sends*


```solidity
function recoverETH() external onlyRole(DEFAULT_ADMIN_ROLE);
```

### resetCircuitBreaker

Resets the circuit breaker


```solidity
function resetCircuitBreaker() external onlyRole(EMERGENCY_ROLE);
```

### triggerCircuitBreaker

Triggers the circuit breaker


```solidity
function triggerCircuitBreaker() external onlyRole(EMERGENCY_ROLE);
```

### pause

Pauses the contract


```solidity
function pause() external onlyRole(EMERGENCY_ROLE);
```

### receive


```solidity
receive() external payable;
```

### getOracleHealth

Mock implementation of getOracleHealth


```solidity
function getOracleHealth() external pure override returns (bool isHealthy, bool eurUsdFresh, bool usdcUsdFresh);
```

### getEurUsdDetails

Mock implementation of getEurUsdDetails


```solidity
function getEurUsdDetails()
    external
    view
    override
    returns (uint256 currentPrice, uint256 lastValidPrice, uint256 lastUpdate, bool isStale, bool withinBounds);
```

### getOracleConfig

Mock implementation of getOracleConfig


```solidity
function getOracleConfig()
    external
    view
    override
    returns (uint256 minPrice, uint256 maxPrice, uint256 maxStaleness, uint256 usdcTolerance, bool circuitBreakerActive);
```

### getPriceFeedAddresses

Mock implementation of getPriceFeedAddresses


```solidity
function getPriceFeedAddresses()
    external
    view
    override
    returns (address eurUsdFeedAddress, address usdcUsdFeedAddress, uint8 eurUsdDecimals, uint8 usdcUsdDecimals);
```

### checkPriceFeedConnectivity

Mock implementation of checkPriceFeedConnectivity


```solidity
function checkPriceFeedConnectivity()
    external
    view
    override
    returns (bool eurUsdConnected, bool usdcUsdConnected, uint80 eurUsdLatestRound, uint80 usdcUsdLatestRound);
```

### updatePriceBounds

Mock implementation of updatePriceBounds


```solidity
function updatePriceBounds(uint256 _minPrice, uint256 _maxPrice) external override onlyRole(DEFAULT_ADMIN_ROLE);
```

### updateUsdcTolerance

Mock implementation of updateUsdcTolerance


```solidity
function updateUsdcTolerance(uint256 newToleranceBps) external override onlyRole(DEFAULT_ADMIN_ROLE);
```

### updatePriceFeeds

Mock implementation of updatePriceFeeds


```solidity
function updatePriceFeeds(address _eurUsdFeed, address _usdcUsdFeed) external override onlyRole(DEFAULT_ADMIN_ROLE);
```

### recoverToken

Mock implementation of recoverToken


```solidity
function recoverToken(address token, uint256 amount) external view override onlyRole(DEFAULT_ADMIN_ROLE);
```

### setPrice

Set the EUR/USD price for testing purposes

*Only available in mock oracle for testing*


```solidity
function setPrice(uint256 _price) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_price`|`uint256`|The new EUR/USD price in 18 decimals|


### setUsdcUsdPrice

Set the USDC/USD price for testing purposes

*Only available in mock oracle for testing*


```solidity
function setUsdcUsdPrice(uint256 _price) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_price`|`uint256`|The new USDC/USD price in 18 decimals|


### setPrices

Set both EUR/USD and USDC/USD prices for testing purposes

*Only available in mock oracle for testing*


```solidity
function setPrices(uint256 _eurUsdPrice, uint256 _usdcUsdPrice) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_eurUsdPrice`|`uint256`|The new EUR/USD price in 18 decimals|
|`_usdcUsdPrice`|`uint256`|The new USDC/USD price in 18 decimals|


### setUpdatedAt

Set the updated timestamp for testing purposes

*Only available in mock oracle for testing*


```solidity
function setUpdatedAt(uint256 _updatedAt) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_updatedAt`|`uint256`|The new timestamp|


## Events
### PriceDeviationDetected

```solidity
event PriceDeviationDetected(uint256 newPrice, uint256 lastPrice, uint256 deviationBps, uint256 blockNumber);
```

### CircuitBreakerTriggered

```solidity
event CircuitBreakerTriggered(uint256 blockNumber, string reason);
```

### CircuitBreakerReset

```solidity
event CircuitBreakerReset(uint256 blockNumber);
```

### ETHRecovered

```solidity
event ETHRecovered(address indexed treasury, uint256 amount);
```

