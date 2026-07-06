# StorkOracle
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/e6d6ab67e05d161d0d4815c50b5213a2a6cbb873/src/oracle/StorkOracle.sol)

**Inherits:**
[IStorkOracle](/src/interfaces/IStorkOracle.sol/interface.IStorkOracle.md), Initializable, AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable, [IVersioned](/src/interfaces/IVersioned.sol/interface.IVersioned.md)

**Title:**
StorkOracle

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

EUR/USD and USDC/USD price manager for Quantillon Protocol using Stork Network

Key features:
- Fetch EUR/USD price from Stork Network
- Validate USDC/USD (should remain close to $1.00)
- Circuit breakers against outlier prices
- Fallbacks in case of oracle outage
- Data freshness checks

DEPLOYMENT REQUIREMENTS:
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
- This would allow using Chainlink's familiar interface with Stork data

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


### MAX_PRICE_STALENESS
Maximum duration before a price is considered stale (1 hour)

3600 seconds = reasonable limit for real-time DeFi


```solidity
uint256 public constant MAX_PRICE_STALENESS = 3600
```


### MAX_PRICE_DEVIATION
Maximum allowed deviation from previous price (5%)

500 basis points = 5% in basis points (500/10000)


```solidity
uint256 public constant MAX_PRICE_DEVIATION = 500
```


### BASIS_POINTS
Basis for basis points calculations


```solidity
uint256 public constant BASIS_POINTS = 10000
```


### MAX_TIMESTAMP_DRIFT
Maximum timestamp drift tolerance (15 minutes)

Prevents timestamp manipulation attacks by miners


```solidity
uint256 public constant MAX_TIMESTAMP_DRIFT = 900
```


### STORK_FEED_DECIMALS
Stork price feed decimals (constant)

Stork feeds use 18 decimals precision (value is multiplied by 10^18)
This is verified based on Stork's documentation


```solidity
uint8 public constant STORK_FEED_DECIMALS = 18
```


### DEV_MODE_DELAY
MED-1: Minimum delay before a proposed dev-mode change takes effect


```solidity
uint256 public constant DEV_MODE_DELAY = 48 hours
```


### TIME_PROVIDER
TimeProvider contract for centralized time management

Used to replace direct block.timestamp usage for testability and consistency


```solidity
TimeProvider public immutable TIME_PROVIDER
```


## State Variables
### eurUsdPriceFeed
Interface to Stork EUR/USD price feed


```solidity
IStorkFeed public eurUsdPriceFeed
```


### usdcUsdPriceFeed
Interface to Stork USDC/USD price feed

Used for USDC price validation and cross-checking


```solidity
IStorkFeed public usdcUsdPriceFeed
```


### treasury
Treasury address for ETH recovery

SECURITY: Only this address can receive ETH from recoverETH function


```solidity
address public treasury
```


### eurUsdFeedId
EUR/USD feed ID for Stork


```solidity
bytes32 public eurUsdFeedId
```


### usdcUsdFeedId
USDC/USD feed ID for Stork


```solidity
bytes32 public usdcUsdFeedId
```


### minEurUsdPrice
Minimum accepted EUR/USD price (lower circuit breaker)

Initialized to 0.80 USD per EUR (extreme crisis)


```solidity
uint256 public minEurUsdPrice
```


### maxEurUsdPrice
Maximum accepted EUR/USD price (upper circuit breaker)

Initialized to 1.40 USD per EUR (extreme scenario)


```solidity
uint256 public maxEurUsdPrice
```


### lastValidEurUsdPrice
Last valid EUR/USD price recorded (18 decimals)

Used as fallback if oracle is down


```solidity
uint256 public lastValidEurUsdPrice
```


### lastPriceUpdateTime
Timestamp of the last valid price update


```solidity
uint256 public lastPriceUpdateTime
```


### lastPriceUpdateBlock
Block number of the last valid price update

Used for block-based staleness checks to prevent timestamp manipulation


```solidity
uint256 public lastPriceUpdateBlock
```


### circuitBreakerTriggered
Circuit breaker status (true = triggered, fixed prices)


```solidity
bool public circuitBreakerTriggered
```


### usdcToleranceBps
USDC/USD tolerance (USDC should remain close to $1.00)

200 basis points = 2% (USDC can vary between 0.98 and 1.02)


```solidity
uint256 public usdcToleranceBps
```


### devModeEnabled
Dev mode flag to disable spread deviation checks

When enabled, price deviation checks are skipped (dev/testing only)


```solidity
bool public devModeEnabled
```


### pendingDevMode
MED-1: Pending dev-mode value awaiting the timelock delay


```solidity
bool public pendingDevMode
```


### devModePendingAt
MED-1: Timestamp at which pendingDevMode may be applied (0 = no pending proposal)


```solidity
uint256 public devModePendingAt
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

Constructor for StorkOracle contract

Initializes the TimeProvider and disables initializers for proxy pattern

**Notes:**
- security: Validates TimeProvider address is not zero

- validation: Validates _TIME_PROVIDER is not address(0)

- state-changes: Sets TIME_PROVIDER immutable variable and disables initializers

- events: No events emitted

- errors: Throws "Zero address" if _TIME_PROVIDER is address(0)

- reentrancy: Not applicable - constructor

- access: Public - anyone can deploy

- oracle: No oracle dependencies

- oz-upgrades-unsafe-allow: constructor


```solidity
constructor(TimeProvider _TIME_PROVIDER) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_TIME_PROVIDER`|`TimeProvider`|Address of the TimeProvider contract for centralized time management|


### initialize

Initializes the oracle contract with Stork price feeds

Sets up all core dependencies, roles, and default configuration parameters

**Notes:**
- security: Validates all addresses are not zero, grants admin roles

- validation: Validates all input addresses are not address(0)

- state-changes: Initializes all state variables, sets default price bounds

- events: Emits PriceUpdated during initial price update

- errors: Throws "Oracle: Admin cannot be zero" if admin is address(0)

- reentrancy: Protected by initializer modifier

- access: Public - only callable once during deployment

- oracle: Initializes Stork price feed interfaces


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

SECURITY: Only admin can update treasury address

**Notes:**
- security: Validates treasury address is non-zero

- validation: Validates _treasury is not address(0)

- state-changes: Updates treasury state variable

- events: Emits TreasuryUpdated event

- errors: Throws if treasury is zero address

- reentrancy: Not protected - no external calls

- access: Restricted to DEFAULT_ADMIN_ROLE

- oracle: No oracle dependency


```solidity
function updateTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_treasury`|`address`|New treasury address|


### unpause

Removes pause and resumes oracle operations

Allows emergency role to unpause the oracle after resolving issues

**Notes:**
- security: Resumes oracle operations after emergency pause

- validation: Validates contract was previously paused

- state-changes: Sets paused state to false

- events: Emits Unpaused event

- errors: No errors thrown

- reentrancy: Not protected - no external calls

- access: Restricted to EMERGENCY_ROLE

- oracle: Resumes normal oracle price queries


```solidity
function unpause() external onlyRole(EMERGENCY_ROLE);
```

### _divRound

Performs division with proper rounding to nearest integer

Adds half the divisor before division to achieve proper rounding

**Notes:**
- security: Validates denominator is non-zero

- validation: Validates b > 0 to prevent division by zero

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws if denominator is zero

- reentrancy: Not protected - pure function

- access: Internal - only callable within contract

- oracle: No oracle dependency


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

Checks timestamp is not in future and not too old beyond staleness + drift limits

**Notes:**
- security: Prevents timestamp manipulation attacks by miners

- validation: Checks timestamp is not in future and within staleness limits

- state-changes: No state changes - view function

- events: No events emitted

- errors: No errors thrown, returns false for invalid timestamps

- reentrancy: Not protected - view function

- access: Internal - only callable within contract

- oracle: Uses TimeProvider for current time validation


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


### _validateEurUsdPriceData

Validates a raw EUR/USD Stork value against freshness, bounds, and deviation policy.

Checks freshness via _validateTimestamp, scales by STORK_FEED_DECIMALS, enforces the
[minEurUsdPrice, maxEurUsdPrice] band, and (unless devModeEnabled) rejects a price deviating
more than MAX_PRICE_DEVIATION bps from lastValidEurUsdPrice.

**Notes:**
- security: Enforces staleness, circuit-breaker bounds, and deviation limits before acceptance.

- validation: Returns isValid=false on stale, non-positive, out-of-bounds, or over-deviation input.

- state-changes: None - view function.

- events: None.

- errors: None - signals failure via the (0, false) return.

- reentrancy: Not applicable - view function.

- access: Internal - no access restrictions.

- oracle: Reads cached bounds/baseline; does not call the Stork feed.


```solidity
function _validateEurUsdPriceData(int256 rawPrice, uint256 timestamp)
    internal
    view
    returns (uint256 price, bool isValid);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rawPrice`|`int256`|Raw EUR/USD price from Stork.|
|`timestamp`|`uint256`|Stork update timestamp.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|Scaled EUR/USD price, or 0 if validation fails before scaling.|
|`isValid`|`bool`|True when the price can be accepted as the next oracle baseline.|


### _normalizeUsdcUsdPrice

Normalizes USDC/USD for PriceUpdated events, falling back to $1.00 if invalid.

Returns $1.00 (1e18) unless the Stork value is fresh, positive, and within usdcToleranceBps
of $1.00, in which case the value scaled by STORK_FEED_DECIMALS is returned.

**Notes:**
- security: Bounds USDC to a tolerance band so a depegged/stale USDC feed cannot distort events.

- validation: Falls back to 1e18 on stale, non-positive, or out-of-tolerance input.

- state-changes: None - view function.

- events: None.

- errors: None - falls back to 1e18.

- reentrancy: Not applicable - view function.

- access: Internal - no access restrictions.

- oracle: Used only to enrich PriceUpdated events; does not gate EUR/USD reads.


```solidity
function _normalizeUsdcUsdPrice(int256 rawPrice, uint256 timestamp) internal view returns (uint256 usdcUsdPrice);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rawPrice`|`int256`|Raw USDC/USD price from Stork.|
|`timestamp`|`uint256`|Stork update timestamp.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`usdcUsdPrice`|`uint256`|Normalized USDC/USD price (18 decimals); $1.00 on any failure.|


### _readUsdcUsdPriceForEvent

Reads USDC/USD for update events without making EUR/USD reads depend on USDC health.

try/catch reads usdcUsdPriceFeed.getTemporalNumericValueV1(usdcUsdFeedId); returns $1.00 if
the call reverts, otherwise delegates to _normalizeUsdcUsdPrice. Decoupled so a failing USDC
feed can never block an EUR/USD read.

**Notes:**
- security: Isolates USDC-feed failures from the EUR/USD path via try/catch.

- validation: Delegates range/tolerance checks to _normalizeUsdcUsdPrice.

- state-changes: None - view function.

- events: None.

- errors: None - all failures fall back to 1e18.

- reentrancy: Not applicable - view function (external staticcall only).

- access: Internal - no access restrictions.

- oracle: Reads the USDC/USD Stork feed; result used only for events.


```solidity
function _readUsdcUsdPriceForEvent() internal view returns (uint256 usdcUsdPrice);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`usdcUsdPrice`|`uint256`|USDC/USD price (18 decimals) for event enrichment; $1.00 on any failure.|


### _commitEurUsdPrice

Commits an accepted EUR/USD price as the new oracle deviation baseline.

Stores the accepted EUR/USD price as the new baseline, records update time/block, and emits
PriceUpdated. Called only after a value passes _validateEurUsdPriceData.

**Notes:**
- security: Reached only after validation; advances the deviation baseline used by later reads.

- validation: Assumes the caller validated the price; performs no checks itself.

- state-changes: Sets lastValidEurUsdPrice, lastPriceUpdateTime, lastPriceUpdateBlock.

- events: Emits PriceUpdated(eurUsdPrice, usdcUsdPrice, timestamp).

- errors: None.

- reentrancy: Not applicable - no external calls.

- access: Internal - no access restrictions.

- oracle: Updates the cached oracle baseline; does not call the Stork feed.


```solidity
function _commitEurUsdPrice(uint256 eurUsdPrice, uint256 usdcUsdPrice) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`eurUsdPrice`|`uint256`|Accepted EUR/USD price to store as the new baseline (18 decimals).|
|`usdcUsdPrice`|`uint256`|USDC/USD price included in the emitted event (18 decimals).|


### _updatePrices

Updates and validates internal prices

Internal function called during initialization and resets, fetches fresh prices from Stork

**Notes:**
- security: Validates prices, checks bounds, and triggers circuit breaker if needed

- validation: Validates timestamp freshness, price bounds, and deviation limits

- state-changes: Updates lastValidEurUsdPrice, lastPriceUpdateTime, and circuitBreakerTriggered

- events: Emits PriceUpdated or CircuitBreakerTriggered events

- errors: No errors thrown, uses circuit breaker for invalid prices

- reentrancy: Not protected - internal function

- access: Internal - only callable within contract

- oracle: Fetches prices from Stork feed contracts for EUR/USD and USDC/USD


```solidity
function _updatePrices() internal;
```

### _scalePrice

Scale price to 18 decimals for consistency

Converts Stork price from its native decimals to 18 decimals with proper rounding

**Notes:**
- security: Handles negative prices by returning 0

- validation: Validates rawPrice is positive before scaling

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No errors thrown, returns 0 for negative prices

- reentrancy: Not protected - pure function

- access: Internal - only callable within contract

- oracle: Scales Stork price data to 18 decimals standard


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

Checks freshness of both price feeds and overall system health

**Notes:**
- security: Provides health status for monitoring and circuit breaker decisions

- validation: Checks feed freshness, circuit breaker state, and pause status

- state-changes: No state changes - view function

- events: No events emitted

- errors: No errors thrown, returns false for unhealthy feeds

- reentrancy: Not protected - view function

- access: Public - no access restrictions

- oracle: Queries Stork feed contracts for EUR/USD and USDC/USD health status


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

Provides comprehensive EUR/USD price information including validation status

**Notes:**
- security: Provides detailed price information for debugging and monitoring

- validation: Checks price freshness and bounds validation

- state-changes: No state changes - view function

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not protected - view function

- access: Public - no access restrictions

- oracle: Queries Stork feed contract for detailed EUR/USD price information


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
|`lastUpdate`|`uint256`|Timestamp reported by the underlying EUR/USD feed|
|`isStale`|`bool`|True if the feed data is stale|
|`withinBounds`|`bool`|True if within configured min/max bounds|


### getOracleConfig

Retrieves current configuration parameters

Returns all key configuration values for oracle operations

**Notes:**
- security: Returns configuration for security monitoring

- validation: No validation - read-only configuration

- state-changes: No state changes - view function

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not protected - view function

- access: Public - no access restrictions

- oracle: Returns configuration parameters for Stork oracle


```solidity
function getOracleConfig()
    external
    view
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
|`minPrice`|`uint256`|Minimum EUR/USD price|
|`maxPrice`|`uint256`|Maximum EUR/USD price|
|`maxStaleness`|`uint256`|Maximum duration before staleness|
|`usdcTolerance`|`uint256`|USDC tolerance in basis points|
|`circuitBreakerActive`|`bool`|Circuit breaker status|


### getPriceFeedAddresses

Retrieves addresses of the Stork price feeds used

Returns feed addresses and their decimal configurations

**Notes:**
- security: Returns feed addresses for verification

- validation: No validation - read-only information

- state-changes: No state changes - view function

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not protected - view function

- access: Public - no access restrictions

- oracle: Returns Stork feed contract addresses and decimals (18 for both)


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

Tests if both price feeds are responding and returns latest round information

**Notes:**
- security: Tests feed connectivity for health monitoring

- validation: No validation - connectivity test only

- state-changes: No state changes - view function

- events: No events emitted

- errors: No errors thrown, returns false for disconnected feeds

- reentrancy: Not protected - view function

- access: Public - no access restrictions

- oracle: Tests connectivity to Stork feed contracts for both feeds


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

Emergency function to recover ERC20 tokens that are not part of normal operations

**Notes:**
- security: Transfers tokens to treasury, prevents accidental loss

- validation: Validates token and amount are non-zero

- state-changes: Transfers tokens from contract to treasury

- events: Emits TokenRecovered event (via library)

- errors: Throws if token is zero address or transfer fails

- reentrancy: Protected by library reentrancy guard

- access: Restricted to DEFAULT_ADMIN_ROLE

- oracle: No oracle dependency


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

SECURITY: Restricted to treasury to prevent arbitrary ETH transfers

**Notes:**
- security: Transfers ETH to treasury, prevents accidental loss

- validation: Validates contract has ETH balance

- state-changes: Transfers ETH from contract to treasury

- events: Emits ETHRecovered event

- errors: Throws if transfer fails

- reentrancy: Protected by library reentrancy guard

- access: Restricted to DEFAULT_ADMIN_ROLE

- oracle: No oracle dependency


```solidity
function recoverETH() external onlyRole(DEFAULT_ADMIN_ROLE);
```

### resetCircuitBreaker

Resets the circuit breaker and resumes oracle usage

Emergency action after resolving an incident.
Restarts price updates and disables fallback mode.

**Notes:**
- security: Resets circuit breaker after manual intervention

- validation: Validates circuit breaker was previously triggered

- state-changes: Resets circuitBreakerTriggered flag and updates prices

- events: Emits CircuitBreakerReset event

- errors: No errors thrown

- reentrancy: Not protected by a reentrancy guard

- access: Restricted to EMERGENCY_ROLE

- oracle: Resumes normal Stork oracle price queries


```solidity
function resetCircuitBreaker() external onlyRole(EMERGENCY_ROLE);
```

### triggerCircuitBreaker

Manually triggers the circuit breaker

Used when the team detects an issue with the oracles.
Forces the use of the last known valid price.

**Notes:**
- security: Manually activates circuit breaker for emergency situations

- validation: No validation - emergency function

- state-changes: Sets circuitBreakerTriggered flag to true

- events: Emits CircuitBreakerTriggered event

- errors: No errors thrown

- reentrancy: Not protected - no external calls

- access: Restricted to EMERGENCY_ROLE

- oracle: Switches to fallback prices instead of live Stork oracle queries


```solidity
function triggerCircuitBreaker() external onlyRole(EMERGENCY_ROLE);
```

### pause

Pauses all oracle operations

Emergency function to pause oracle in case of critical issues

**Notes:**
- security: Emergency pause to halt all oracle operations

- validation: No validation - emergency function

- state-changes: Sets paused state to true

- events: Emits Paused event

- errors: No errors thrown

- reentrancy: Not protected - no external calls

- access: Restricted to EMERGENCY_ROLE

- oracle: Halts all Stork oracle price queries


```solidity
function pause() external onlyRole(EMERGENCY_ROLE);
```

### getEurUsdPrice

Retrieves the current EUR/USD price with full validation

Validation process:
1. Check circuit breaker status
2. Fetch from Stork
3. Freshness check (< 1 hour)
4. Convert to 18 decimals
5. Check min/max bounds
6. Return valid price or fallback

SECURITY NOTE: Stork is a pull oracle — on-chain prices are updated by keeper transactions.
An attacker monitoring the off-chain Stork stream can front-run a pending price update by
opening a HedgerPool position at the stale price before the update lands. Existing mitigations:
(1) MAX_PRICE_DEVIATION circuit breaker caps the per-update magnitude;
(2) minPositionHoldBlocks in HedgerPool enforces a minimum hold period after entry.
For stronger guarantees, consider a commit-reveal entry scheme or using Stork's push model.

**Notes:**
- security: Validates price freshness and bounds before returning

- validation: Checks price staleness, circuit breaker state, and bounds

- state-changes: Updates lastValidEurUsdPrice, lastPriceUpdateTime, and lastPriceUpdateBlock when valid

- events: Emits PriceUpdated when a valid price advances the baseline

- errors: No errors thrown, returns isValid=false for invalid prices

- reentrancy: Not protected - external oracle read only

- access: Public - no access restrictions

- oracle: Queries Stork feed contract for EUR/USD price


```solidity
function getEurUsdPrice() external returns (uint256 price, bool isValid);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|EUR/USD price in 18 decimals (e.g., 1.10e18 = 1.10 USD per EUR)|
|`isValid`|`bool`|true if the price is fresh and within acceptable bounds|


### getUsdcUsdPrice

Retrieves the USDC/USD price with validation

USDC is expected to maintain parity with USD.
A large deviation indicates a systemic issue.

**Notes:**
- security: Validates price is within tolerance of $1.00

- validation: Checks price staleness and deviation from $1.00

- state-changes: No state changes - view function

- events: No events emitted

- errors: No errors thrown, returns isValid=false for invalid prices

- reentrancy: Not protected - view function

- access: Public - no access restrictions

- oracle: Queries Stork feed contract for USDC/USD price


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

Allows oracle manager to adjust price thresholds based on market conditions

**Notes:**
- security: Validates min < max and reasonable bounds

- validation: Validates price bounds are within acceptable range

- state-changes: Updates minEurUsdPrice and maxEurUsdPrice state variables

- events: Emits PriceBoundsUpdated event

- errors: Throws if minPrice >= maxPrice or invalid bounds

- reentrancy: Not protected by a reentrancy guard

- access: Restricted to ORACLE_MANAGER_ROLE

- oracle: No oracle dependency - configuration update only


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

Allows oracle manager to adjust USDC price tolerance around $1.00

**Notes:**
- security: Validates tolerance is within reasonable limits

- validation: Validates tolerance is not zero and within max bounds (10%)

- state-changes: Updates usdcToleranceBps state variable

- events: No events emitted

- errors: Throws if tolerance is invalid or out of bounds

- reentrancy: Not protected by a reentrancy guard

- access: Restricted to ORACLE_MANAGER_ROLE

- oracle: No oracle dependency - configuration update only


```solidity
function updateUsdcTolerance(uint256 newToleranceBps) external onlyRole(ORACLE_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newToleranceBps`|`uint256`|New tolerance in basis points (e.g., 200 = 2%)|


### updatePriceFeeds

Updates the Stork feed address and feed IDs

Allows oracle manager to update feed address and feed IDs for maintenance or upgrades
Note: Stork uses a single contract address with different feed IDs

**Notes:**
- security: Validates feed address is non-zero and contract exists

- validation: Validates all addresses are not address(0)

- state-changes: Updates eurUsdPriceFeed, usdcUsdPriceFeed, and feed IDs

- events: Emits PriceFeedsUpdated event

- errors: Throws if feed address is zero or invalid

- reentrancy: Not protected by a reentrancy guard

- access: Restricted to ORACLE_MANAGER_ROLE

- oracle: Updates Stork feed contract references


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


### proposeDevMode

Toggles dev mode to disable spread deviation checks

MED-1: Propose a dev-mode change; enforces a 48-hour timelock before it can be applied.

DEV ONLY: When enabled, price deviation checks are skipped for testing

Records a desired value for `devModeEnabled` in `pendingDevMode` and sets
`devModePendingAt` to `block.timestamp + DEV_MODE_DELAY`. This does not affect
current deviation checks until `applyDevMode` is executed after the delay.

**Notes:**
- security: Only callable by `DEFAULT_ADMIN_ROLE`; separates intent from effect
to avoid rushed enabling/disabling of deviation checks.

- validation: Accepts both `true` and `false`; applies a fixed delay in all cases.

- state-changes: Updates `pendingDevMode` and `devModePendingAt`.

- events: Emits `DevModeProposed(enabled, devModePendingAt)`.

- errors: None – proposals are always recorded.

- reentrancy: Not applicable – no external calls after state updates.

- access: Restricted to `DEFAULT_ADMIN_ROLE`.

- oracle: No direct oracle dependency; controls deviation checks in price paths.


```solidity
function proposeDevMode(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`enabled`|`bool`|True to enable dev mode, false to disable|


### applyDevMode

MED-1: Apply a previously proposed dev-mode change after the timelock has elapsed.

Checks that `devModePendingAt` is non-zero and that the current block timestamp
has reached or passed `devModePendingAt`. If so, copies `pendingDevMode` into
`devModeEnabled` and clears `devModePendingAt`.

**Notes:**
- security: Only callable by `DEFAULT_ADMIN_ROLE`; enforces the configured delay.

- validation: Reverts when there is no pending proposal or the delay window is not met.

- state-changes: Updates `devModeEnabled` and resets `devModePendingAt` to 0.

- events: Emits `DevModeToggled(devModeEnabled, msg.sender)`.

- errors: InvalidAmount if no pending proposal; NotActive if called before delay elapses.

- reentrancy: Not applicable – no external calls after state updates.

- access: Restricted to `DEFAULT_ADMIN_ROLE`.

- oracle: No direct oracle dependency; influences later deviation checks.


```solidity
function applyDevMode() external onlyRole(DEFAULT_ADMIN_ROLE);
```

## Events
### PriceUpdated
Emitted on each valid price update

OPTIMIZED: Indexed timestamp for efficient time-based filtering


```solidity
event PriceUpdated(uint256 eurUsdPrice, uint256 usdcUsdPrice, uint256 indexed timestamp);
```

### CircuitBreakerTriggered
Emitted when the circuit breaker is triggered

OPTIMIZED: Indexed reason for efficient filtering by trigger type


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

OPTIMIZED: Indexed bound type for efficient filtering


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

### DevModeProposed
MED-1: Emitted when a dev-mode change is proposed


```solidity
event DevModeProposed(bool pending, uint256 activatesAt);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pending`|`bool`|The proposed dev-mode value|
|`activatesAt`|`uint256`|Timestamp at which the change can be applied|

