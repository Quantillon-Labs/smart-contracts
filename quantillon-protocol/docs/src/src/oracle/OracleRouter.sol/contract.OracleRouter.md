# OracleRouter
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/02318f592f770a9d926016c8576b44854e674b9a/src/oracle/OracleRouter.sol)

**Inherits:**
[IOracle](/src/interfaces/IOracle.sol/interface.IOracle.md), Initializable, AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable, [IVersioned](/src/interfaces/IVersioned.sol/interface.IVersioned.md)

**Title:**
OracleRouter

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Router contract that lets governance switch the protocol between two oracle slots

Key features:
- Holds references to two oracle slots (enum OracleType { CHAINLINK, MARKET }); the
MARKET slot can host any IOracle implementation (StorkOracle pre-2026-06-25,
HyperliquidEurUsdOracle since)
- Routes all IOracle calls to the currently active oracle
- Admin can switch between oracles via switchOracle()
- v1.1.0: slot 1 renamed STORK -> MARKET / storkOracle -> marketOracle; the
pre-1.1.0 storkOracle() getter is kept as a deprecated ABI-compatible alias
- Implements IOracle interface (generic, oracle-agnostic)
- Protocol contracts use IOracle interface for oracle-agnostic integration

**Note:**
security-contact: team@quantillon.money


## Constants
### ORACLE_MANAGER_ROLE
Role to manage oracle configurations


```solidity
bytes32 public constant ORACLE_MANAGER_ROLE = keccak256("ORACLE_MANAGER_ROLE")
```


### EMERGENCY_ROLE
Role for emergency actions


```solidity
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE")
```


### UPGRADER_ROLE
Role for contract upgrades


```solidity
bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE")
```


## State Variables
### chainlinkOracle
Chainlink oracle contract reference


```solidity
IChainlinkOracle public chainlinkOracle
```


### marketOracle
Market oracle contract reference (slot 1)

The swappable market-price oracle: StorkOracle pre-2026-06-25, currently
HyperliquidEurUsdOracle. Named `storkOracle` before v1.1.0 (same slot/encoding).


```solidity
IOracle public marketOracle
```


### activeOracle
Currently active oracle type


```solidity
OracleType public activeOracle
```


### treasury
Treasury address for ETH recovery


```solidity
address public treasury
```


## Functions
### version

Returns the semantic version of this implementation.

Pure getter (no storage slot) read through the proxy, so it reflects the deployed
implementation. Bump per semver on any change; enforced by `make check-version-bump`.
See deployments/{chainId}/versions.json for the deployed impl/commit provenance.

**Notes:**
- security: No security implications - returns a compile-time constant.

- validation: No input validation required.

- state-changes: None - pure function.

- events: None.

- errors: None.

- reentrancy: Not applicable - pure function.

- access: Public - anyone can read the version.

- oracle: No oracle dependencies.


```solidity
function version() external pure virtual override returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Semantic version string (e.g. "1.0.0").|


### constructor

Locks the implementation so it cannot be initialized directly

Disables initializers on the implementation contract; only proxies may be
initialized. Brings OracleRouter in line with the other core/oracle
contracts, which all call _disableInitializers().

**Notes:**
- security: Prevents implementation-contract initialization

- validation: No input validation required - constructor

- state-changes: Disables initializers on the implementation

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not applicable - constructor

- access: No access restrictions

- oracle: No oracle dependencies

- oz-upgrades-unsafe-allow: constructor


```solidity
constructor() ;
```

### initialize

Initializes the router contract with both oracle addresses

Sets up all core dependencies, roles, and default oracle selection

**Notes:**
- security: Validates all addresses are not zero, grants admin roles

- validation: Validates all input addresses are not address(0)

- state-changes: Initializes all state variables, sets default oracle

- events: Emits OracleSwitched during initialization

- errors: Throws validation errors if addresses are zero

- reentrancy: Protected by initializer modifier

- access: Public - only callable once during deployment

- oracle: Initializes references to the chainlink and market oracle contracts


```solidity
function initialize(
    address admin,
    address _chainlinkOracle,
    address _marketOracle,
    address _treasury,
    OracleType _defaultOracle
) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address with administrator privileges|
|`_chainlinkOracle`|`address`|ChainlinkOracle contract address|
|`_marketOracle`|`address`|Market oracle contract address (slot 1)|
|`_treasury`|`address`|Treasury address for ETH recovery|
|`_defaultOracle`|`OracleType`|Default oracle to use (CHAINLINK or MARKET)|


### updateTreasury

Update treasury address

Only admin can update treasury address

**Notes:**
- security: Restricted to DEFAULT_ADMIN_ROLE

- validation: _treasury not zero

- state-changes: treasury

- events: TreasuryUpdated

- errors: InvalidAddress if zero

- reentrancy: No external calls

- access: DEFAULT_ADMIN_ROLE

- oracle: None


```solidity
function updateTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_treasury`|`address`|New treasury address|


### unpause

Removes pause and resumes oracle operations

Only emergency role can unpause the router

**Notes:**
- security: Restricted to EMERGENCY_ROLE

- validation: None

- state-changes: Pausable state

- events: Unpaused

- errors: None

- reentrancy: No external calls

- access: EMERGENCY_ROLE

- oracle: None


```solidity
function unpause() external onlyRole(EMERGENCY_ROLE);
```

### _getActiveOracle

Gets the currently active oracle contract

Returns chainlinkOracle or marketOracle based on activeOracle enum

**Notes:**
- security: View only

- validation: None

- state-changes: None

- events: None

- errors: None

- reentrancy: No external calls

- access: Internal

- oracle: Returns oracle reference


```solidity
function _getActiveOracle() internal view returns (IOracle);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IOracle`|The active oracle contract implementing IOracle|


### getActiveOracle

Gets the currently active oracle type

Returns activeOracle enum value

**Notes:**
- security: View only

- validation: None

- state-changes: None

- events: None

- errors: None

- reentrancy: No external calls

- access: Anyone

- oracle: None


```solidity
function getActiveOracle() external view returns (OracleType);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`OracleType`|The active oracle type (CHAINLINK or MARKET)|


### getOracleAddresses

Gets the addresses of both oracle contracts

Returns chainlinkOracle and marketOracle addresses

**Notes:**
- security: View only

- validation: None

- state-changes: None

- events: None

- errors: None

- reentrancy: No external calls

- access: Anyone

- oracle: None


```solidity
function getOracleAddresses() external view returns (address chainlinkAddress, address marketAddress);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`chainlinkAddress`|`address`|Address of ChainlinkOracle contract|
|`marketAddress`|`address`|Address of the market oracle contract (slot 1)|


### storkOracle

Deprecated alias for the slot-1 (market) oracle address

Before v1.1.0 the slot-1 state variable was named `storkOracle`; this function
preserves the auto-generated getter's selector and return type for ABI
compatibility. New integrations must use `marketOracle()` instead.

**Notes:**
- security: View only

- validation: None

- state-changes: None

- events: None

- errors: None

- reentrancy: No external calls

- access: Anyone

- oracle: Returns the market oracle reference


```solidity
function storkOracle() external view returns (IStorkOracle);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IStorkOracle`|The slot-1 oracle, typed as IStorkOracle for ABI compatibility|


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

Delegates to TreasuryRecoveryLibrary.recoverToken

**Notes:**
- security: DEFAULT_ADMIN_ROLE; sends to treasury only

- validation: Treasury and amount

- state-changes: Token balance of treasury

- events: Via TreasuryRecoveryLibrary

- errors: Via library

- reentrancy: External call to token and treasury

- access: DEFAULT_ADMIN_ROLE

- oracle: None


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

Delegates to TreasuryRecoveryLibrary.recoverETH; emits ETHRecovered

**Notes:**
- security: DEFAULT_ADMIN_ROLE; sends to treasury only

- validation: Treasury not zero

- state-changes: ETH balance of treasury

- events: ETHRecovered

- errors: Via library

- reentrancy: External call to treasury

- access: DEFAULT_ADMIN_ROLE

- oracle: None


```solidity
function recoverETH() external onlyRole(DEFAULT_ADMIN_ROLE);
```

### pause

Pauses all oracle operations

Calls _pause(); only EMERGENCY_ROLE

**Notes:**
- security: EMERGENCY_ROLE only

- validation: None

- state-changes: Pausable state

- events: Paused

- errors: None

- reentrancy: No external calls

- access: EMERGENCY_ROLE

- oracle: None


```solidity
function pause() external onlyRole(EMERGENCY_ROLE);
```

### switchOracle

Switches the active oracle between the two slots

Validates newOracle != activeOracle and oracle address not zero; emits OracleSwitched

**Notes:**
- security: ORACLE_MANAGER_ROLE only

- validation: newOracle != activeOracle; oracle address not zero

- state-changes: activeOracle

- events: OracleSwitched

- errors: Require message if same oracle

- reentrancy: No external calls

- access: ORACLE_MANAGER_ROLE

- oracle: None


```solidity
function switchOracle(OracleType newOracle) external onlyRole(ORACLE_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newOracle`|`OracleType`|The new oracle type to activate (CHAINLINK or MARKET)|


### updateOracleAddresses

Updates the oracle contract addresses

Validates both addresses; updates chainlinkOracle and marketOracle; emits OracleAddressesUpdated

**Notes:**
- security: ORACLE_MANAGER_ROLE only

- validation: Both addresses not zero

- state-changes: chainlinkOracle, marketOracle

- events: OracleAddressesUpdated

- errors: InvalidOracle if zero

- reentrancy: No external calls

- access: ORACLE_MANAGER_ROLE

- oracle: None


```solidity
function updateOracleAddresses(address _chainlinkOracle, address _marketOracle)
    external
    onlyRole(ORACLE_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_chainlinkOracle`|`address`|New ChainlinkOracle address|
|`_marketOracle`|`address`|New market oracle address (slot 1)|


### getEurUsdPrice

Retrieves the current EUR/USD price with full validation

Delegates to active oracle getEurUsdPrice()

**Notes:**
- security: Delegates to trusted oracle

- validation: Via oracle

- state-changes: May update oracle state (e.g. last price)

- events: None

- errors: Via oracle

- reentrancy: External call to oracle

- access: Anyone

- oracle: Delegates to active oracle


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

Delegates to active oracle getUsdcUsdPrice()

**Notes:**
- security: View; delegates to oracle

- validation: Via oracle

- state-changes: None

- events: None

- errors: Via oracle

- reentrancy: External call to oracle (view)

- access: Anyone

- oracle: Delegates to active oracle


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

Delegates to active oracle getOracleHealth()

**Notes:**
- security: Delegates to oracle

- validation: Via oracle

- state-changes: May update oracle state

- events: None

- errors: Via oracle

- reentrancy: External call to oracle

- access: Anyone

- oracle: Delegates to active oracle


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

Delegates to active oracle getEurUsdDetails()

**Notes:**
- security: Delegates to oracle

- validation: Via oracle

- state-changes: No state changes - view function only

- events: None

- errors: Via oracle

- reentrancy: External call to oracle

- access: Anyone

- oracle: Delegates to active oracle


```solidity
function getEurUsdDetails()
    external
    view
    override
    returns (uint256 currentPrice, uint256 lastValidPrice, uint256 lastUpdate, bool isStale, bool withinBounds);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`currentPrice`|`uint256`|Current price (may be fallback)|
|`lastValidPrice`|`uint256`|Last validated price stored|
|`lastUpdate`|`uint256`|Timestamp reported by the underlying EUR/USD feed|
|`isStale`|`bool`|True if the feed data is stale|
|`withinBounds`|`bool`|True if within configured min/max bounds|


### getOracleConfig

Current configuration and circuit breaker state

Delegates to active oracle getOracleConfig()

**Notes:**
- security: View; delegates to oracle

- validation: Via oracle

- state-changes: None

- events: None

- errors: Via oracle

- reentrancy: External call to oracle (view)

- access: Anyone

- oracle: Delegates to active oracle


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

Delegates to active oracle getPriceFeedAddresses()

**Notes:**
- security: View; delegates to oracle

- validation: Via oracle

- state-changes: None

- events: None

- errors: Via oracle

- reentrancy: External call to oracle (view)

- access: Anyone

- oracle: Delegates to active oracle


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

Delegates to active oracle checkPriceFeedConnectivity()

**Notes:**
- security: View; delegates to oracle

- validation: Via oracle

- state-changes: None

- events: None

- errors: Via oracle

- reentrancy: External call to oracle (view)

- access: Anyone

- oracle: Delegates to active oracle


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

Delegates to active oracle updatePriceBounds

**Notes:**
- security: ORACLE_MANAGER_ROLE only

- validation: Via oracle

- state-changes: Oracle state

- events: Via oracle

- errors: Via oracle

- reentrancy: External call to oracle

- access: ORACLE_MANAGER_ROLE

- oracle: Delegates to active oracle


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

Delegates to active oracle updateUsdcTolerance

**Notes:**
- security: ORACLE_MANAGER_ROLE only

- validation: Via oracle

- state-changes: Oracle state

- events: Via oracle

- errors: Via oracle

- reentrancy: External call to oracle

- access: ORACLE_MANAGER_ROLE

- oracle: Delegates to active oracle


```solidity
function updateUsdcTolerance(uint256 newToleranceBps) external onlyRole(ORACLE_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newToleranceBps`|`uint256`|New tolerance (e.g., 200 = 2%)|


### updatePriceFeeds

Updates price feed addresses (Chainlink only)

Reverts when the MARKET slot is active - use oracle-specific methods instead

**Notes:**
- security: Only Chainlink path; reverts for the MARKET slot

- validation: Via ChainlinkOracle

- state-changes: Oracle feed addresses

- events: Via oracle

- errors: Reverts for the MARKET slot

- reentrancy: External call to ChainlinkOracle

- access: ORACLE_MANAGER_ROLE

- oracle: Delegates to ChainlinkOracle only


```solidity
function updatePriceFeeds(address _eurUsdFeed, address _usdcUsdFeed) external onlyRole(ORACLE_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_eurUsdFeed`|`address`|New EUR/USD feed address|
|`_usdcUsdFeed`|`address`|New USDC/USD feed address|


### resetCircuitBreaker

Clears circuit breaker and attempts to resume live prices

Delegates to active oracle resetCircuitBreaker()

**Notes:**
- security: Anyone can reset (oracle may restrict)

- validation: Via oracle

- state-changes: Oracle circuit breaker state

- events: Via oracle

- errors: Via oracle

- reentrancy: External call to oracle

- access: ORACLE_MANAGER_ROLE

- oracle: Delegates to active oracle


```solidity
function resetCircuitBreaker() external onlyRole(ORACLE_MANAGER_ROLE);
```

### triggerCircuitBreaker

Manually triggers circuit breaker to use fallback prices

Delegates to active oracle triggerCircuitBreaker()

**Notes:**
- security: ORACLE_MANAGER_ROLE only

- validation: Via oracle

- state-changes: Oracle circuit breaker state

- events: Via oracle

- errors: Via oracle

- reentrancy: External call to oracle

- access: ORACLE_MANAGER_ROLE

- oracle: Delegates to active oracle


```solidity
function triggerCircuitBreaker() external onlyRole(ORACLE_MANAGER_ROLE);
```

## Events
### OracleSwitched
Emitted when the active oracle is switched

OPTIMIZED: Indexed oracle type for efficient filtering


```solidity
event OracleSwitched(OracleType indexed oldOracle, OracleType indexed newOracle, address indexed caller);
```

### OracleAddressesUpdated
Emitted when oracle addresses are updated


```solidity
event OracleAddressesUpdated(address newChainlinkOracle, address newMarketOracle);
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

Slot 1 was named STORK before v1.1.0; renamed to MARKET (the swappable
market-price oracle slot). Enum values are unchanged (CHAINLINK=0, MARKET=1).


```solidity
enum OracleType {
    CHAINLINK,
    MARKET
}
```

