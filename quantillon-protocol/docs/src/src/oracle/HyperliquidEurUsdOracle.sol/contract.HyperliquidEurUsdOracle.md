# HyperliquidEurUsdOracle
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/9c66decc017650bbed0d0184c123aef0af402eaf/src/oracle/HyperliquidEurUsdOracle.sol)

**Inherits:**
[IHyperliquidOracle](/src/interfaces/IHyperliquidOracle.sol/interface.IHyperliquidOracle.md), Initializable, AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable, [IVersioned](/src/interfaces/IVersioned.sol/interface.IVersioned.md)

**Title:**
HyperliquidEurUsdOracle

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

EUR/USD oracle for Quantillon that mirrors the Hyperliquid xyz:EUR perp mid used to
execute the protocol hedge, so QEURO mint/redeem prices align with the hedge venue.

Design:
- EUR/USD source: the Hyperliquid xyz:EUR mid published on-chain by the off-chain Slippage
Monitor into SlippageStorage (getSlippageBySource(SOURCE_HYPERLIQUID).midPrice, 18 decimals).
The snapshot timestamp is the on-chain write time, used for staleness.
- USDC/USD source: delegated to the existing ChainlinkOracle (the hedge does not change USDC
valuation), kept decoupled so a USDC feed issue cannot block EUR/USD reads.
- Safety: configurable staleness, [min,max] price bounds, per-update deviation circuit
breaker and a last-valid-price fallback — mirroring StorkOracle so the failure modes and
the OracleRouter wiring are identical.
Slots into the OracleRouter's Stork position: the router reads via IOracle and delegates
updatePriceBounds / updateUsdcTolerance / resetCircuitBreaker / triggerCircuitBreaker, all of
which are implemented here with matching selectors. No OracleRouter change is required.

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


### MAX_PRICE_DEVIATION
Maximum allowed deviation from previous price (5% = 500 bps)


```solidity
uint256 public constant MAX_PRICE_DEVIATION = 500
```


### BASIS_POINTS
Basis for basis points calculations


```solidity
uint256 public constant BASIS_POINTS = 10000
```


### HARD_MAX_STALENESS
Hard upper bound for the configurable staleness window (1 hour)


```solidity
uint256 public constant HARD_MAX_STALENESS = 3600
```


### MID_DECIMALS
Published mid decimals (SlippageStorage stores midPrice in 18 decimals)


```solidity
uint8 public constant MID_DECIMALS = 18
```


### TIME_PROVIDER
TimeProvider contract for centralized, testable time


```solidity
TimeProvider public immutable TIME_PROVIDER
```


## State Variables
### slippageStorage
SlippageStorage contract holding the published Hyperliquid mid


```solidity
ISlippageMidSource public slippageStorage
```


### usdcSource
USDC/USD source oracle (the existing ChainlinkOracle)


```solidity
IOracle public usdcSource
```


### sourceId
Slippage source id to read (SOURCE_HYPERLIQUID = 1)


```solidity
uint8 public sourceId
```


### treasury
Treasury address for ETH/token recovery


```solidity
address public treasury
```


### minEurUsdPrice
Minimum accepted EUR/USD price (lower circuit breaker, 18 decimals)


```solidity
uint256 public minEurUsdPrice
```


### maxEurUsdPrice
Maximum accepted EUR/USD price (upper circuit breaker, 18 decimals)


```solidity
uint256 public maxEurUsdPrice
```


### lastValidEurUsdPrice
Last valid EUR/USD price recorded (18 decimals) - used as fallback


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


```solidity
uint256 public lastPriceUpdateBlock
```


### circuitBreakerTriggered
Circuit breaker status (true = triggered, use last valid price)


```solidity
bool public circuitBreakerTriggered
```


### usdcToleranceBps
Reported USDC/USD tolerance in basis points (validation lives in usdcSource)


```solidity
uint256 public usdcToleranceBps
```


### maxPriceStaleness
Maximum accepted staleness of the published mid, in seconds


```solidity
uint256 public maxPriceStaleness
```


## Functions
### version

Returns the semantic version of this implementation.

Pure getter read through the proxy; bump per semver on any change.

**Notes:**
- security: No security implications - compile-time constant.

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

Constructor sets the TimeProvider and disables initializers for the proxy pattern

Stores the immutable TimeProvider and disables initializers on the implementation (UUPS pattern).

**Notes:**
- security: Validates TimeProvider is non-zero

- validation: Validates _TIME_PROVIDER != address(0)

- state-changes: Sets TIME_PROVIDER immutable and disables initializers

- events: No events emitted

- errors: Reverts "Zero address" if _TIME_PROVIDER is zero

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
|`_TIME_PROVIDER`|`TimeProvider`|Address of the TimeProvider contract|


### initialize

Initializes the adapter with its price sources and treasury

Grants admin/manager/emergency/upgrader roles to admin, sets default bounds, tolerance
and staleness, then attempts a best-effort initial seed from SlippageStorage.

**Notes:**
- security: Validates all addresses non-zero, grants roles to admin

- validation: Validates admin/_slippageStorage/_usdcSource/_treasury != address(0)

- state-changes: Initializes sources, roles, default bounds/staleness/tolerance, seeds price

- events: Emits PriceUpdated if an initial mid is available

- errors: Reverts if any address is zero

- reentrancy: Protected by initializer modifier

- access: Public - only callable once during proxy deployment

- oracle: Reads the initial mid from SlippageStorage if present


```solidity
function initialize(
    address admin,
    address _slippageStorage,
    uint8 _sourceId,
    address _usdcSource,
    address _treasury
) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address with administrator privileges|
|`_slippageStorage`|`address`|SlippageStorage contract holding the published Hyperliquid mid|
|`_sourceId`|`uint8`|Slippage source id to read (SOURCE_HYPERLIQUID = 1)|
|`_usdcSource`|`address`|Oracle providing USDC/USD (the existing ChainlinkOracle)|
|`_treasury`|`address`|Treasury address for ETH/token recovery|


### _divRound

Division with rounding to the nearest integer

Half-up integer division used for deviation-bps rounding.

**Notes:**
- security: Validates denominator is positive

- validation: Validates b > 0

- state-changes: None - pure function

- events: No events emitted

- errors: Reverts if denominator is zero

- reentrancy: Not protected - pure function

- access: Internal

- oracle: No oracle dependency


```solidity
function _divRound(uint256 a, uint256 b) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`a`|`uint256`|Numerator|
|`b`|`uint256`|Denominator (must be > 0)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Rounded result of a / b|


### _validateTimestamp

Validates the published mid timestamp against future-dating and staleness

SlippageStorage timestamps are on-chain write times, so they cannot be in the future
except under clock skew; rejects zero (never published) and anything older than maxPriceStaleness.

**Notes:**
- security: Bounds acceptable data age for valuation reads

- validation: Rejects zero, future, or stale timestamps

- state-changes: None - view function

- events: No events emitted

- errors: No errors thrown - returns false on failure

- reentrancy: Not protected - view function

- access: Internal

- oracle: Uses TimeProvider for current time


```solidity
function _validateTimestamp(uint256 reportedTime) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`reportedTime`|`uint256`|The snapshot timestamp to validate|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the timestamp is fresh and not future-dated|


### _readMid

Reads the latest Hyperliquid mid and its timestamp from SlippageStorage

try/catch read of the per-source snapshot; returns (0, 0) when SlippageStorage reverts.

**Notes:**
- security: Single external view read of the trusted SlippageStorage

- validation: No validation here - caller validates freshness/bounds

- state-changes: None - view function

- events: No events emitted

- errors: Reverts only if SlippageStorage reverts (fail-safe for callers that bubble it)

- reentrancy: Not protected - external staticcall only

- access: Internal

- oracle: Reads SlippageStorage.getSlippageBySource(sourceId)


```solidity
function _readMid() internal view returns (uint256 price, uint256 timestamp);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|EUR/USD mid in 18 decimals (0 if unavailable)|
|`timestamp`|`uint256`|On-chain write timestamp of the snapshot|


### _validateEurUsd

Validates a candidate EUR/USD price against freshness, bounds and deviation

Single validation path combining staleness/zero, min/max bounds, and deviation-vs-baseline checks.

**Notes:**
- security: Enforces staleness, bounds and per-update deviation limits

- validation: Returns isValid=false on stale, zero, out-of-bounds or over-deviation input

- state-changes: None - view function

- events: No events emitted

- errors: No errors thrown - signals via (price, false)

- reentrancy: Not protected - view function

- access: Internal

- oracle: Reads cached bounds/baseline only


```solidity
function _validateEurUsd(uint256 price, uint256 timestamp) internal view returns (uint256 outPrice, bool isValid);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|Candidate price (18 decimals)|
|`timestamp`|`uint256`|Snapshot timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`outPrice`|`uint256`|The candidate price echoed back (0 if it fails freshness)|
|`isValid`|`bool`|True if the price can advance the baseline|


### _readUsdcForEvent

Reads USDC/USD from the delegated source for event enrichment only

try/catch so a failing USDC source never blocks an EUR/USD commit.

**Notes:**
- security: Isolates USDC-source failures from the EUR/USD path

- validation: Falls back to 1e18 when the source reverts or returns invalid

- state-changes: None - view function

- events: No events emitted

- errors: No errors thrown - falls back to 1e18

- reentrancy: Not protected - external staticcall only

- access: Internal

- oracle: Reads usdcSource.getUsdcUsdPrice()


```solidity
function _readUsdcForEvent() internal view returns (uint256 usdcUsdPrice);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`usdcUsdPrice`|`uint256`|USDC/USD price (18 decimals); $1.00 on any failure|


### _commitEurUsdPrice

Commits an accepted EUR/USD price as the new baseline

One TimeProvider read shared by the stored timestamp and the emitted event.

**Notes:**
- security: Reached only after validation; advances the deviation baseline

- validation: Assumes the caller validated the price

- state-changes: Sets lastValidEurUsdPrice, lastPriceUpdateTime, lastPriceUpdateBlock

- events: Emits PriceUpdated

- errors: No errors thrown

- reentrancy: Not protected - one external staticcall for event enrichment

- access: Internal

- oracle: Reads usdcSource for the emitted event only


```solidity
function _commitEurUsdPrice(uint256 eurUsdPrice) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`eurUsdPrice`|`uint256`|Accepted EUR/USD price (18 decimals)|


### _seedInitialPrice

Best-effort initial/reset seed of the baseline from SlippageStorage

Never reverts and never trips the breaker: if no fresh, in-bounds mid is published yet,
the baseline is left as-is and the first successful read seeds it.

**Notes:**
- security: Avoids bricking init/reset when no data has been published yet

- validation: Applies bounds (deviation is skipped while no baseline exists)

- state-changes: May set lastValidEurUsdPrice/time/block via _commitEurUsdPrice

- events: Emits PriceUpdated if a seed price is accepted

- errors: No errors thrown

- reentrancy: Not protected - external staticcall only

- access: Internal

- oracle: Reads SlippageStorage


```solidity
function _seedInitialPrice() internal;
```

### getEurUsdPrice

Retrieves the current EUR/USD price with full validation

Reads the Hyperliquid mid from SlippageStorage; on circuit breaker, pause, staleness,
out-of-bounds or over-deviation, returns the last valid price with isValid=false so the
vault fails safe. A valid price advances the baseline.

**Notes:**
- security: Validates freshness, bounds, deviation and breaker state

- validation: Returns isValid=false for any invalid condition

- state-changes: Updates baseline (lastValid*) when a valid price is accepted

- events: Emits PriceUpdated when the baseline advances

- errors: No errors thrown unless SlippageStorage itself reverts (fail-safe)

- reentrancy: Not protected - external staticcall only

- access: Public - no access restrictions

- oracle: Reads SlippageStorage mid; reads usdcSource for the event only


```solidity
function getEurUsdPrice() external override returns (uint256 price, bool isValid);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|EUR/USD price in 18 decimals|
|`isValid`|`bool`|True if fresh and within bounds/deviation|


### getUsdcUsdPrice

Retrieves the USDC/USD price with validation, delegated to the USDC source

Delegates to the configured USDC source; falls back to ($1.00, false) when the source reverts.

**Notes:**
- security: Delegates to the trusted USDC source; falls back to $1.00 on failure

- validation: Validation performed by usdcSource

- state-changes: No state changes - view function

- events: No events emitted

- errors: No errors thrown - falls back to (1e18, false) on revert

- reentrancy: Not protected - external staticcall only

- access: Public - no access restrictions

- oracle: Reads usdcSource.getUsdcUsdPrice()


```solidity
function getUsdcUsdPrice() external view override returns (uint256 price, bool isValid);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|USDC/USD price in 18 decimals (≈ 1e18)|
|`isValid`|`bool`|True if USDC remains within the source's tolerance|


### getOracleHealth

Returns overall oracle health signals

Aggregates mid freshness, USDC-source validity, circuit breaker and pause state for monitoring.

**Notes:**
- security: Health view for monitoring and watchdog decisions

- validation: Checks freshness, breaker and pause state

- state-changes: No state changes - view function

- events: No events emitted

- errors: No errors thrown - degraded sources report false

- reentrancy: Not protected - external staticcalls only

- access: Public - no access restrictions

- oracle: Reads SlippageStorage and usdcSource


```solidity
function getOracleHealth() external view override returns (bool isHealthy, bool eurUsdFresh, bool usdcUsdFresh);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isHealthy`|`bool`|True if both feeds are fresh, breaker is off and not paused|
|`eurUsdFresh`|`bool`|True if the Hyperliquid mid is fresh and positive|
|`usdcUsdFresh`|`bool`|True if the USDC source reports a valid price|


### getEurUsdDetails

Detailed information about the EUR/USD price

View-only variant of the read path; reuses _validateEurUsd for bounds/deviation.

**Notes:**
- security: Detailed view for debugging and monitoring

- validation: Checks freshness, bounds and deviation

- state-changes: No state changes - view function

- events: No events emitted

- errors: No errors thrown - returns fallback on source revert

- reentrancy: Not protected - external staticcall only

- access: Public - no access restrictions

- oracle: Reads SlippageStorage


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
|`currentPrice`|`uint256`|Current price (may be the fallback)|
|`lastValidPrice`|`uint256`|Last validated price stored|
|`lastUpdate`|`uint256`|Snapshot timestamp reported by SlippageStorage|
|`isStale`|`bool`|True if the published mid is stale|
|`withinBounds`|`bool`|True if currentPrice is within configured bounds|


### getOracleConfig

Current configuration and circuit breaker state

Returns the configured bounds, staleness window, USDC tolerance and breaker state in one call.

**Notes:**
- security: Configuration view for monitoring

- validation: No validation - read-only

- state-changes: No state changes - view function

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not protected - view function

- access: Public - no access restrictions

- oracle: No oracle dependency


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
|`maxStaleness`|`uint256`|Maximum accepted staleness in seconds|
|`usdcTolerance`|`uint256`|Reported USDC tolerance in basis points|
|`circuitBreakerActive`|`bool`|True if the circuit breaker is triggered|


### getPriceFeedAddresses

Addresses and decimals of the underlying sources

Reports the SlippageStorage and delegated USDC-source addresses currently wired.

**Notes:**
- security: Returns source addresses for verification

- validation: No validation - read-only

- state-changes: No state changes - view function

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not protected - view function

- access: Public - no access restrictions

- oracle: No oracle dependency


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
|`eurUsdFeedAddress`|`address`|EUR/USD source address (SlippageStorage)|
|`usdcUsdFeedAddress`|`address`|USDC/USD source address (ChainlinkOracle)|
|`eurUsdDecimals`|`uint8`|EUR/USD decimals (18)|
|`usdcUsdDecimals`|`uint8`|USDC/USD decimals (18)|


### checkPriceFeedConnectivity

Connectivity check for both sources

Best-effort staticcalls to both sources; never reverts.

**Notes:**
- security: Connectivity view for monitoring

- validation: No validation - connectivity test only

- state-changes: No state changes - view function

- events: No events emitted

- errors: No errors thrown - degraded sources report false

- reentrancy: Not protected - external staticcalls only

- access: Public - no access restrictions

- oracle: Reads SlippageStorage and usdcSource


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
|`eurUsdConnected`|`bool`|True if SlippageStorage returns a fresh, positive mid|
|`usdcUsdConnected`|`bool`|True if the USDC source returns a valid price|
|`eurUsdLatestRound`|`uint80`|Always 0 (not round-based)|
|`usdcUsdLatestRound`|`uint80`|Always 0 (not round-based)|


### updatePriceBounds

Updates EUR/USD min and max acceptable prices

The bounds gate _validateEurUsd; both must be nonzero with min below max.

**Notes:**
- security: Validates min < max and a sane upper bound

- validation: Validates _minPrice > 0, _maxPrice > _minPrice, _maxPrice <= 10e18

- state-changes: Updates minEurUsdPrice and maxEurUsdPrice

- events: Emits PriceBoundsUpdated

- errors: Reverts on invalid bounds

- reentrancy: Not protected - no external calls

- access: Restricted to ORACLE_MANAGER_ROLE

- oracle: No oracle dependency


```solidity
function updatePriceBounds(uint256 _minPrice, uint256 _maxPrice) external override onlyRole(ORACLE_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_minPrice`|`uint256`|Minimum accepted EUR/USD price (18 decimals)|
|`_maxPrice`|`uint256`|Maximum accepted EUR/USD price (18 decimals)|


### updateUsdcTolerance

Updates the reported USDC tolerance (validation lives in the USDC source)

Reported via getOracleConfig only — USDC validation itself is delegated to the USDC source.

**Notes:**
- security: Validates tolerance within 10%

- validation: Validates newToleranceBps <= 1000

- state-changes: Updates usdcToleranceBps

- events: No events emitted

- errors: Reverts if tolerance is out of bounds

- reentrancy: Not protected - no external calls

- access: Restricted to ORACLE_MANAGER_ROLE

- oracle: No oracle dependency


```solidity
function updateUsdcTolerance(uint256 newToleranceBps) external override onlyRole(ORACLE_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newToleranceBps`|`uint256`|New tolerance in basis points (e.g., 200 = 2%)|


### resetCircuitBreaker

Clears the circuit breaker and attempts to re-seed the baseline

Clears the breaker and attempts to re-seed the deviation baseline from the current mid.

**Notes:**
- security: Re-enables live prices after manual intervention

- validation: None

- state-changes: Clears circuitBreakerTriggered and may re-seed the baseline

- events: Emits CircuitBreakerReset (and PriceUpdated if re-seeded)

- errors: No errors thrown

- reentrancy: Not protected - external staticcall only

- access: Restricted to EMERGENCY_ROLE

- oracle: Reads SlippageStorage to re-seed


```solidity
function resetCircuitBreaker() external override onlyRole(EMERGENCY_ROLE);
```

### triggerCircuitBreaker

Manually triggers the circuit breaker (use last valid price)

Forces reads onto the last valid price until reset.

**Notes:**
- security: Forces fallback pricing during incidents

- validation: None

- state-changes: Sets circuitBreakerTriggered to true

- events: Emits CircuitBreakerTriggered

- errors: No errors thrown

- reentrancy: Not protected - no external calls

- access: Restricted to EMERGENCY_ROLE

- oracle: No oracle dependency


```solidity
function triggerCircuitBreaker() external override onlyRole(EMERGENCY_ROLE);
```

### setMaxPriceStaleness

Updates the maximum accepted staleness of the published mid

Gates _validateTimestamp; capped by MAX_STALENESS_CAP.

**Notes:**
- security: Bounds the staleness window to a safe maximum

- validation: Validates 0 < newMaxStaleness <= HARD_MAX_STALENESS

- state-changes: Updates maxPriceStaleness

- events: Emits MaxStalenessUpdated

- errors: Reverts if out of bounds

- reentrancy: Not protected - no external calls

- access: Restricted to ORACLE_MANAGER_ROLE

- oracle: No oracle dependency


```solidity
function setMaxPriceStaleness(uint256 newMaxStaleness) external override onlyRole(ORACLE_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMaxStaleness`|`uint256`|New staleness window in seconds (1..HARD_MAX_STALENESS)|


### updateSlippageSource

Updates the SlippageStorage source contract and source id

Points the adapter at a new SlippageStorage deployment and/or source id.

**Notes:**
- security: Validates non-zero source address

- validation: Validates _slippageStorage != address(0)

- state-changes: Updates slippageStorage and sourceId

- events: Emits SlippageSourceUpdated

- errors: Reverts if source address is zero

- reentrancy: Not protected - no external calls

- access: Restricted to ORACLE_MANAGER_ROLE

- oracle: Updates the SlippageStorage reference


```solidity
function updateSlippageSource(address _slippageStorage, uint8 _sourceId)
    external
    override
    onlyRole(ORACLE_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_slippageStorage`|`address`|New SlippageStorage contract address|
|`_sourceId`|`uint8`|New slippage source id (SOURCE_HYPERLIQUID = 1)|


### updateUsdcSource

Updates the USDC/USD source oracle

Swaps the delegated USDC/USD oracle.

**Notes:**
- security: Validates non-zero source address

- validation: Validates _usdcSource != address(0)

- state-changes: Updates usdcSource

- events: Emits UsdcSourceUpdated

- errors: Reverts if source address is zero

- reentrancy: Not protected - no external calls

- access: Restricted to ORACLE_MANAGER_ROLE

- oracle: Updates the USDC source reference


```solidity
function updateUsdcSource(address _usdcSource) external override onlyRole(ORACLE_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_usdcSource`|`address`|New USDC/USD source (ChainlinkOracle)|


### updateTreasury

Updates the treasury address

The treasury receives recovered tokens/ETH from the recovery functions.

**Notes:**
- security: Validates non-zero treasury

- validation: Validates _treasury != address(0)

- state-changes: Updates treasury

- events: Emits TreasuryUpdated

- errors: Reverts if treasury is zero

- reentrancy: Not protected - no external calls

- access: Restricted to DEFAULT_ADMIN_ROLE

- oracle: No oracle dependency


```solidity
function updateTreasury(address _treasury) external override onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_treasury`|`address`|New treasury address|


### pause

Pauses all oracle reads

While paused, price reads return the last valid price with isValid=false.

**Notes:**
- security: Emergency halt of price reads

- validation: None

- state-changes: Sets paused = true

- events: Emits Paused

- errors: No errors thrown

- reentrancy: Not protected - no external calls

- access: Restricted to EMERGENCY_ROLE

- oracle: Halts oracle price reads


```solidity
function pause() external override onlyRole(EMERGENCY_ROLE);
```

### unpause

Unpauses oracle reads

Re-enables live price reads.

**Notes:**
- security: Resumes normal operation

- validation: None

- state-changes: Sets paused = false

- events: Emits Unpaused

- errors: No errors thrown

- reentrancy: Not protected - no external calls

- access: Restricted to EMERGENCY_ROLE

- oracle: Resumes oracle price reads


```solidity
function unpause() external override onlyRole(EMERGENCY_ROLE);
```

### recoverToken

Recovers ERC20 tokens accidentally sent to the contract, to treasury only

Routed through TreasuryRecoveryLibrary; funds always go to the treasury.

**Notes:**
- security: Sends recovered tokens to treasury only

- validation: Validated by the recovery library

- state-changes: Transfers token balance to treasury

- events: Emits TokenRecovered via library

- errors: Reverts if token is zero or transfer fails

- reentrancy: Protected by library

- access: Restricted to DEFAULT_ADMIN_ROLE

- oracle: No oracle dependency


```solidity
function recoverToken(address token, uint256 amount) external override onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address to recover|
|`amount`|`uint256`|Amount to transfer|


### recoverETH

Recovers ETH accidentally sent to the contract, to treasury only

Routed through TreasuryRecoveryLibrary; funds always go to the treasury.

**Notes:**
- security: Sends recovered ETH to treasury only

- validation: Validates treasury is set and balance is non-zero

- state-changes: Transfers ETH balance to treasury

- events: Emits ETHRecovered

- errors: Reverts if treasury is zero or there is no ETH

- reentrancy: Uses sendValue to a trusted treasury

- access: Restricted to DEFAULT_ADMIN_ROLE

- oracle: No oracle dependency


```solidity
function recoverETH() external override onlyRole(DEFAULT_ADMIN_ROLE);
```

### _authorizeUpgrade

Authorizes contract upgrades

**Notes:**
- security: Restricted to UPGRADER_ROLE

- validation: None beyond role check

- state-changes: None directly

- events: No events emitted

- errors: Reverts if caller lacks UPGRADER_ROLE

- reentrancy: Not protected - no external calls

- access: Restricted to UPGRADER_ROLE

- oracle: No oracle dependency


```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|


## Events
### PriceUpdated
Emitted on each valid price update


```solidity
event PriceUpdated(uint256 eurUsdPrice, uint256 usdcUsdPrice, uint256 indexed timestamp);
```

### CircuitBreakerTriggered
Emitted when the circuit breaker is triggered


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


```solidity
event PriceBoundsUpdated(string indexed boundType, uint256 newMinPrice, uint256 newMaxPrice);
```

### SlippageSourceUpdated
Emitted when the slippage source contract or source id is updated


```solidity
event SlippageSourceUpdated(address indexed newSlippageStorage, uint8 newSourceId);
```

### UsdcSourceUpdated
Emitted when the USDC/USD source oracle is updated


```solidity
event UsdcSourceUpdated(address indexed newUsdcSource);
```

### MaxStalenessUpdated
Emitted when the maximum staleness window is updated


```solidity
event MaxStalenessUpdated(uint256 oldStaleness, uint256 newStaleness);
```

### TreasuryUpdated
Emitted when the treasury address is updated


```solidity
event TreasuryUpdated(address indexed newTreasury);
```

### ETHRecovered
Emitted when ETH is recovered from the contract


```solidity
event ETHRecovered(address indexed to, uint256 amount);
```

