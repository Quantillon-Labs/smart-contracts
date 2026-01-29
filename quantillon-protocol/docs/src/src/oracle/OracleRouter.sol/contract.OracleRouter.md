# OracleRouter
**Inherits:**
[IOracle](/src/interfaces/IOracle.sol/interface.IOracle.md), Initializable, AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Router contract that allows admin to switch between Chainlink and Stork oracles

*Key features:
- Holds references to both ChainlinkOracle and StorkOracle
- Routes all IOracle calls to the currently active oracle
- Admin can switch between oracles via switchOracle()
- Implements IOracle interface (generic, oracle-agnostic)
- Protocol contracts use IOracle interface for oracle-agnostic integration*

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


### chainlinkOracle
Chainlink oracle contract reference


```solidity
IChainlinkOracle public chainlinkOracle;
```


### storkOracle
Stork oracle contract reference


```solidity
IStorkOracle public storkOracle;
```


### activeOracle
Currently active oracle type


```solidity
OracleType public activeOracle;
```


### treasury
Treasury address for ETH recovery


```solidity
address public treasury;
```


## Functions
### initialize

Initializes the router contract with both oracle addresses

*Sets up all core dependencies, roles, and default oracle selection*

**Notes:**
- Validates all addresses are not zero, grants admin roles

- Validates all input addresses are not address(0)

- Initializes all state variables, sets default oracle

- Emits OracleSwitched during initialization

- Throws validation errors if addresses are zero

- Protected by initializer modifier

- Public - only callable once during deployment

- Initializes references to ChainlinkOracle and StorkOracle contracts


```solidity
function initialize(
    address admin,
    address _chainlinkOracle,
    address _storkOracle,
    address _treasury,
    OracleType _defaultOracle
) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address with administrator privileges|
|`_chainlinkOracle`|`address`|ChainlinkOracle contract address|
|`_storkOracle`|`address`|StorkOracle contract address|
|`_treasury`|`address`|Treasury address for ETH recovery|
|`_defaultOracle`|`OracleType`|Default oracle to use (CHAINLINK or STORK)|


### updateTreasury

Update treasury address

*Only admin can update treasury address*


```solidity
function updateTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_treasury`|`address`|New treasury address|


### unpause

Removes pause and resumes oracle operations

*Only emergency role can unpause the router*


```solidity
function unpause() external onlyRole(EMERGENCY_ROLE);
```

### _getActiveOracle

Gets the currently active oracle contract


```solidity
function _getActiveOracle() internal view returns (IOracle);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IOracle`|The active oracle contract implementing IOracle|


### getActiveOracle

Gets the currently active oracle type


```solidity
function getActiveOracle() external view returns (OracleType);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`OracleType`|The active oracle type (CHAINLINK or STORK)|


### getOracleAddresses

Gets the addresses of both oracle contracts


```solidity
function getOracleAddresses() external view returns (address chainlinkAddress, address storkAddress);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`chainlinkAddress`|`address`|Address of ChainlinkOracle contract|
|`storkAddress`|`address`|Address of StorkOracle contract|


### _authorizeUpgrade

Authorizes router contract upgrades


```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|


### recoverToken

Recovers tokens accidentally sent to the contract to treasury only


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


```solidity
function recoverETH() external onlyRole(DEFAULT_ADMIN_ROLE);
```

### pause

Pauses all oracle operations


```solidity
function pause() external onlyRole(EMERGENCY_ROLE);
```

### switchOracle

Switches the active oracle between Chainlink and Stork


```solidity
function switchOracle(OracleType newOracle) external onlyRole(ORACLE_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newOracle`|`OracleType`|The new oracle type to activate (CHAINLINK or STORK)|


### updateOracleAddresses

Updates the oracle contract addresses


```solidity
function updateOracleAddresses(address _chainlinkOracle, address _storkOracle) external onlyRole(ORACLE_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_chainlinkOracle`|`address`|New ChainlinkOracle address|
|`_storkOracle`|`address`|New StorkOracle address|


### getEurUsdPrice

Retrieves the current EUR/USD price with full validation


```solidity
function getEurUsdPrice() external override returns (uint256 price, bool isValid);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|EUR/USD price in 18 decimals|
|`isValid`|`bool`|True if the price is fresh and within acceptable bounds|


### getUsdcUsdPrice

Retrieves the USDC/USD price with validation


```solidity
function getUsdcUsdPrice() external view override returns (uint256 price, bool isValid);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|USDC/USD price in 18 decimals|
|`isValid`|`bool`|True if USDC remains close to $1.00|


### getOracleHealth

Returns overall oracle health signals


```solidity
function getOracleHealth() external override returns (bool isHealthy, bool eurUsdFresh, bool usdcUsdFresh);
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
    override
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
    override
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
    override
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


```solidity
function checkPriceFeedConnectivity()
    external
    view
    override
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
function updatePriceBounds(uint256 _minPrice, uint256 _maxPrice) external onlyRole(ORACLE_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_minPrice`|`uint256`|New minimum price (18 decimals)|
|`_maxPrice`|`uint256`|New maximum price (18 decimals)|


### updateUsdcTolerance

Updates the allowed USDC deviation from $1.00 in basis points


```solidity
function updateUsdcTolerance(uint256 newToleranceBps) external onlyRole(ORACLE_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newToleranceBps`|`uint256`|New tolerance (e.g., 200 = 2%)|


### updatePriceFeeds

Updates price feed addresses (Chainlink only)

*Reverts for Stork oracle - use oracle-specific methods instead*


```solidity
function updatePriceFeeds(address _eurUsdFeed, address _usdcUsdFeed) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_eurUsdFeed`|`address`|New EUR/USD feed address|
|`_usdcUsdFeed`|`address`|New USDC/USD feed address|


### resetCircuitBreaker

Clears circuit breaker and attempts to resume live prices


```solidity
function resetCircuitBreaker() external;
```

### triggerCircuitBreaker

Manually triggers circuit breaker to use fallback prices


```solidity
function triggerCircuitBreaker() external onlyRole(ORACLE_MANAGER_ROLE);
```

## Events
### OracleSwitched
Emitted when the active oracle is switched

*OPTIMIZED: Indexed oracle type for efficient filtering*


```solidity
event OracleSwitched(OracleType indexed oldOracle, OracleType indexed newOracle, address indexed caller);
```

### OracleAddressesUpdated
Emitted when oracle addresses are updated


```solidity
event OracleAddressesUpdated(address newChainlinkOracle, address newStorkOracle);
```

### TreasuryUpdated
Emitted when treasury address is updated


```solidity
event TreasuryUpdated(address indexed newTreasury);
```

### ETHRecovered
Emitted when ETH is recovered from the contract


```solidity
event ETHRecovered(address indexed to, uint256 amount);
```

## Enums
### OracleType
Enum for oracle type selection


```solidity
enum OracleType {
    CHAINLINK,
    STORK
}
```

