# MockStorkOracle
**Inherits:**
[IStorkOracle](/src/interfaces/IStorkOracle.sol/interface.IStorkOracle.md), Initializable, AccessControlUpgradeable, PausableUpgradeable

**Title:**
MockStorkOracle

**Author:**
Quantillon Labs

Mock oracle that implements IStorkOracle interface but uses mock data

Used for localhost testing - provides same interface as StorkOracle


## State Variables
### EMERGENCY_ROLE

```solidity
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE")
```


### ORACLE_MANAGER_ROLE

```solidity
bytes32 public constant ORACLE_MANAGER_ROLE = keccak256("ORACLE_MANAGER_ROLE")
```


### treasury

```solidity
address public treasury
```


### originalAdmin

```solidity
address private originalAdmin
```


### MIN_EUR_USD_PRICE

```solidity
uint256 public constant MIN_EUR_USD_PRICE = 0.5e18
```


### MAX_EUR_USD_PRICE

```solidity
uint256 public constant MAX_EUR_USD_PRICE = 2.0e18
```


### MIN_USDC_USD_PRICE

```solidity
uint256 public constant MIN_USDC_USD_PRICE = 0.95e18
```


### MAX_USDC_USD_PRICE

```solidity
uint256 public constant MAX_USDC_USD_PRICE = 1.05e18
```


### MAX_PRICE_DEVIATION

```solidity
uint256 public constant MAX_PRICE_DEVIATION = 500
```


### lastValidEurUsdPrice

```solidity
uint256 public lastValidEurUsdPrice
```


### lastValidUsdcUsdPrice

```solidity
uint256 public lastValidUsdcUsdPrice
```


### lastPriceUpdateBlock

```solidity
uint256 public lastPriceUpdateBlock
```


### MIN_BLOCKS_BETWEEN_UPDATES

```solidity
uint256 public constant MIN_BLOCKS_BETWEEN_UPDATES = 1
```


### circuitBreakerTriggered

```solidity
bool public circuitBreakerTriggered
```


### devModeEnabled

```solidity
bool public devModeEnabled
```


## Functions
### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor() ;
```

### initialize

Initializes the mock oracle


```solidity
function initialize(
    address admin,
    address _storkFeedAddress,
    bytes32 _eurUsdFeedId,
    bytes32 _usdcUsdFeedId,
    address _treasury
) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Admin address|
|`_storkFeedAddress`|`address`|Mock Stork feed address (unused, kept for interface compatibility)|
|`_eurUsdFeedId`|`bytes32`|Mock EUR/USD feed ID (unused, kept for interface compatibility)|
|`_usdcUsdFeedId`|`bytes32`|Mock USDC/USD feed ID (unused, kept for interface compatibility)|
|`_treasury`|`address`|Treasury address|


### getEurUsdPrice

Gets the current EUR/USD price with validation


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


### updateTreasury

Updates treasury address


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

Only sends ETH to the original admin address to prevent arbitrary sends


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
function getOracleHealth() external view override returns (bool isHealthy, bool eurUsdFresh, bool usdcUsdFresh);
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
    returns (
        uint256 minPrice,
        uint256 maxPrice,
        uint256 maxStaleness,
        uint256 usdcTolerance,
        bool circuitBreakerActive
    );
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
function updatePriceBounds(uint256 _minPrice, uint256 _maxPrice) external override onlyRole(ORACLE_MANAGER_ROLE);
```

### updateUsdcTolerance

Mock implementation of updateUsdcTolerance


```solidity
function updateUsdcTolerance(uint256 newToleranceBps) external override onlyRole(ORACLE_MANAGER_ROLE);
```

### updatePriceFeeds

Mock implementation of updatePriceFeeds


```solidity
function updatePriceFeeds(address _storkFeedAddress, bytes32 _eurUsdFeedId, bytes32 _usdcUsdFeedId)
    external
    view
    override
    onlyRole(ORACLE_MANAGER_ROLE);
```

### recoverToken

Mock implementation of recoverToken


```solidity
function recoverToken(address token, uint256 amount) external view override onlyRole(DEFAULT_ADMIN_ROLE);
```

### setPrice

Set the EUR/USD price for testing purposes

Only available in mock oracle for testing


```solidity
function setPrice(uint256 _price) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_price`|`uint256`|The new EUR/USD price in 18 decimals|


### setUsdcUsdPrice

Set the USDC/USD price for testing purposes

Only available in mock oracle for testing


```solidity
function setUsdcUsdPrice(uint256 _price) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_price`|`uint256`|The new USDC/USD price in 18 decimals|


### setPrices

Set both EUR/USD and USDC/USD prices for testing purposes

Only available in mock oracle for testing


```solidity
function setPrices(uint256 _eurUsdPrice, uint256 _usdcUsdPrice) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_eurUsdPrice`|`uint256`|The new EUR/USD price in 18 decimals|
|`_usdcUsdPrice`|`uint256`|The new USDC/USD price in 18 decimals|


### setDevMode

Toggles dev mode to disable spread deviation checks

DEV ONLY: When enabled, price deviation checks are skipped for testing


```solidity
function setDevMode(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`enabled`|`bool`|True to enable dev mode, false to disable|


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

### DevModeToggled

```solidity
event DevModeToggled(bool enabled, address indexed caller);
```

