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

*Allows emergency role to unpause the router after resolving issues*

**Notes:**
- Resumes router operations after emergency pause

- Validates contract was previously paused

- Sets paused state to false

- Emits Unpaused event

- No errors thrown

- Not protected - no external calls

- Restricted to EMERGENCY_ROLE

- Resumes oracle queries through active oracle


```solidity
function unpause() external onlyRole(EMERGENCY_ROLE);
```

### _getActiveOracle

Gets the currently active oracle contract

*Returns the oracle contract based on activeOracle state*

**Notes:**
- Internal function - no security implications

- No validation - read-only operation

- No state changes - view function

- No events emitted

- No errors thrown

- Not protected - view function

- Internal - only callable within contract

- Returns reference to active oracle (Chainlink or Stork)


```solidity
function _getActiveOracle() internal view returns (IOracle);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IOracle`|The active oracle contract implementing IOracle|


### getActiveOracle

Gets the currently active oracle type

*Returns the enum value of the active oracle*

**Notes:**
- Returns current oracle selection for monitoring

- No validation - read-only operation

- No state changes - view function

- No events emitted

- No errors thrown

- Not protected - view function

- Public - no access restrictions

- Returns which oracle (Chainlink or Stork) is currently active


```solidity
function getActiveOracle() external view returns (OracleType);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`OracleType`|The active oracle type (CHAINLINK or STORK)|


### getOracleAddresses

Gets the addresses of both oracle contracts

*Returns both oracle addresses for reference*

**Notes:**
- Returns oracle addresses for verification

- No validation - read-only operation

- No state changes - view function

- No events emitted

- No errors thrown

- Not protected - view function

- Public - no access restrictions

- Returns addresses of both Chainlink and Stork oracle contracts


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

### pause

Pauses all oracle operations

*Emergency function to pause router in case of critical issues*

**Notes:**
- Emergency pause to halt all router operations

- No validation - emergency function

- Sets paused state to true

- Emits Paused event

- No errors thrown

- Not protected - no external calls

- Restricted to EMERGENCY_ROLE

- Halts all oracle queries through router


```solidity
function pause() external onlyRole(EMERGENCY_ROLE);
```

### switchOracle

Switches the active oracle between Chainlink and Stork

*Allows oracle manager to change which oracle is actively used*

**Notes:**
- Only ORACLE_MANAGER_ROLE can switch oracles

- Validates newOracle is different from current activeOracle

- Updates activeOracle state variable

- Emits OracleSwitched event

- Throws if newOracle is same as current activeOracle

- Not protected - no external calls that could reenter

- Restricted to ORACLE_MANAGER_ROLE

- Switches active oracle between Chainlink and Stork


```solidity
function switchOracle(OracleType newOracle) external onlyRole(ORACLE_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newOracle`|`OracleType`|The new oracle type to activate (CHAINLINK or STORK)|


### updateOracleAddresses

Updates the oracle contract addresses

*Allows oracle manager to update oracle addresses for maintenance or upgrades*

**Notes:**
- Validates both oracle addresses are non-zero

- Validates all addresses are not address(0)

- Updates chainlinkOracle and storkOracle references

- Emits OracleAddressesUpdated event

- Throws if oracle addresses are zero

- Not protected - no external calls

- Restricted to ORACLE_MANAGER_ROLE

- Updates references to Chainlink and Stork oracle contracts


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

*Delegates to the currently active oracle*

**Notes:**
- Validates price freshness and bounds before returning

- Checks price staleness and circuit breaker state

- May update lastValidPrice if price is valid

- No events emitted

- No errors thrown, returns isValid=false for invalid prices

- Not protected - delegates to active oracle

- Public - no access restrictions

- Queries active oracle (Chainlink or Stork) for EUR/USD price


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

*Delegates to the currently active oracle*

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
function getUsdcUsdPrice() external view override returns (uint256 price, bool isValid);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|USDC/USD price in 18 decimals|
|`isValid`|`bool`|True if USDC remains close to $1.00|


### getOracleHealth

Returns overall oracle health signals

*Delegates to the currently active oracle*

**Notes:**
- Provides health status for monitoring and circuit breaker decisions

- Checks feed freshness, circuit breaker state, and pause status

- May update internal state during health check

- No events emitted

- No errors thrown

- Not protected - delegates to active oracle

- Public - no access restrictions

- Queries active oracle health status for both feeds


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

*Delegates to the currently active oracle*

**Notes:**
- Provides detailed price information for debugging and monitoring

- Checks price freshness and bounds validation

- May update internal state during price check

- No events emitted

- No errors thrown

- Not protected - delegates to active oracle

- Public - no access restrictions

- Queries active oracle for detailed EUR/USD price information


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

*Delegates to the currently active oracle*

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

*Delegates to the currently active oracle*

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

*Delegates to the currently active oracle*

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

*Delegates to the currently active oracle (requires casting to specific interface)
Requires ORACLE_MANAGER_ROLE on the router*

**Notes:**
- Validates min < max and reasonable bounds

- Validates price bounds are within acceptable range

- Updates minPrice and maxPrice in active oracle

- Emits PriceBoundsUpdated event (via active oracle)

- Throws if minPrice >= maxPrice or invalid bounds

- Protected by active oracle's reentrancy guard

- Restricted to ORACLE_MANAGER_ROLE

- Delegates to active oracle (Chainlink or Stork) to update price bounds


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

*Delegates to the currently active oracle (requires casting to specific interface)
Requires ORACLE_MANAGER_ROLE on the router*

**Notes:**
- Validates tolerance is within reasonable limits

- Validates tolerance is not zero and within max bounds

- Updates usdcTolerance in active oracle

- Emits UsdcToleranceUpdated event (via active oracle)

- Throws if tolerance is invalid or out of bounds

- Protected by active oracle's reentrancy guard

- Restricted to ORACLE_MANAGER_ROLE

- Delegates to active oracle (Chainlink or Stork) to update USDC tolerance


```solidity
function updateUsdcTolerance(uint256 newToleranceBps) external onlyRole(ORACLE_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newToleranceBps`|`uint256`|New tolerance (e.g., 200 = 2%)|


### updatePriceFeeds

Updates price feed addresses

*Delegates to the currently active oracle (requires casting to specific interface)
Note: Chainlink uses addresses, Stork uses address + feed IDs*

**Notes:**
- Validates feed address is non-zero and contract exists

- Validates all addresses are not address(0)

- Updates feed addresses in active oracle (Chainlink only)

- Emits PriceFeedsUpdated event (via active oracle)

- Throws if feed address is zero, invalid, or Stork oracle is active

- Protected by active oracle's reentrancy guard

- Restricted to ORACLE_MANAGER_ROLE (via active oracle)

- Delegates to active Chainlink oracle to update feed addresses (reverts for Stork)


```solidity
function updatePriceFeeds(address _eurUsdFeed, address _usdcUsdFeed) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_eurUsdFeed`|`address`|New EUR/USD feed address (for Chainlink) or Stork feed address (for Stork)|
|`_usdcUsdFeed`|`address`|New USDC/USD feed address (for Chainlink) or unused (for Stork)|


### resetCircuitBreaker

Clears circuit breaker and attempts to resume live prices

*Delegates to the currently active oracle (requires casting to specific interface)*

**Notes:**
- Resets circuit breaker after manual intervention

- Validates circuit breaker was previously triggered

- Resets circuitBreakerTriggered flag in active oracle

- Emits CircuitBreakerReset event (via active oracle)

- No errors thrown

- Protected by active oracle's reentrancy guard

- Restricted to ORACLE_MANAGER_ROLE

- Delegates to active oracle (Chainlink or Stork) to reset circuit breaker


```solidity
function resetCircuitBreaker() external;
```

### triggerCircuitBreaker

Manually triggers circuit breaker to use fallback prices

*Delegates to the currently active oracle (requires casting to specific interface)*

**Notes:**
- Manually activates circuit breaker for emergency situations

- No validation - emergency function

- Sets circuitBreakerTriggered flag to true in active oracle

- Emits CircuitBreakerTriggered event (via active oracle)

- No errors thrown

- Protected by active oracle's reentrancy guard

- Restricted to ORACLE_MANAGER_ROLE

- Delegates to active oracle (Chainlink or Stork) to trigger circuit breaker


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

