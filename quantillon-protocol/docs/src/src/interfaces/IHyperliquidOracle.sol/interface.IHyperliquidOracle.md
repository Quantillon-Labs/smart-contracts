# IHyperliquidOracle
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/9c66decc017650bbed0d0184c123aef0af402eaf/src/interfaces/IHyperliquidOracle.sol)

**Inherits:**
[IOracle](/src/interfaces/IOracle.sol/interface.IOracle.md)

**Title:**
IHyperliquidOracle

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Interface for the Quantillon Hyperliquid EUR/USD oracle adapter

Extends IOracle with the management functions the OracleRouter delegates to the
active oracle (updatePriceBounds / updateUsdcTolerance / resetCircuitBreaker /
triggerCircuitBreaker) plus adapter-specific configuration. The EUR/USD price is the
Hyperliquid xyz:EUR perp mid published on-chain by the off-chain Slippage Monitor into
SlippageStorage; USDC/USD validation is delegated to the existing ChainlinkOracle.
The OracleRouter stores the active oracle as `IStorkOracle` and casts it unchecked, so an
implementation only needs to expose the IOracle reads plus the four delegated management
selectors above to slot into the Stork position via updateOracleAddresses + switchOracle.

**Note:**
security-contact: team@quantillon.money


## Functions
### initialize

Initializes the adapter with its price sources and treasury

Callable once via the proxy. Grants admin/manager/emergency/upgrader roles to `admin`.

**Notes:**
- security: Validates all addresses are non-zero and grants roles to admin

- validation: Validates admin/_slippageStorage/_usdcSource/_treasury != address(0)

- state-changes: Initializes sources, roles, default bounds, staleness and tolerance

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
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address that receives admin and management roles|
|`_slippageStorage`|`address`|SlippageStorage contract that holds the published Hyperliquid mid|
|`_sourceId`|`uint8`|Slippage source id to read (SOURCE_HYPERLIQUID = 1)|
|`_usdcSource`|`address`|Oracle providing USDC/USD (the existing ChainlinkOracle)|
|`_treasury`|`address`|Treasury address for ETH/token recovery|


### updatePriceBounds

Updates EUR/USD min and max acceptable prices (18 decimals)

The bounds gate the validation path; both must be nonzero with min below max.

**Notes:**
- security: Misconfigured bounds can force fallback pricing

- validation: Reverts unless 0 < _minPrice < _maxPrice

- events: Emits a bounds-updated event in the implementation

- errors: Reverts on invalid bounds

- reentrancy: No external calls

- access: Restricted to ORACLE_MANAGER_ROLE

- state-changes: Updates minEurUsdPrice / maxEurUsdPrice

- oracle: Affects EUR/USD validation only


```solidity
function updatePriceBounds(uint256 _minPrice, uint256 _maxPrice) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_minPrice`|`uint256`|Minimum accepted EUR/USD price (18 decimals)|
|`_maxPrice`|`uint256`|Maximum accepted EUR/USD price (18 decimals)|


### updateUsdcTolerance

Updates the reported USDC tolerance in basis points

Reported via getOracleConfig only — USDC validation itself is delegated to the USDC source.

**Notes:**
- security: Reporting-only; does not change validation behavior

- validation: Bounded by the implementation's tolerance cap

- events: Emits a tolerance-updated event in the implementation

- errors: Reverts when above the cap

- reentrancy: No external calls

- access: Restricted to ORACLE_MANAGER_ROLE

- state-changes: Updates the stored tolerance

- oracle: No effect on price reads


```solidity
function updateUsdcTolerance(uint256 newToleranceBps) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newToleranceBps`|`uint256`|New tolerance in basis points|


### resetCircuitBreaker

Clears the circuit breaker and attempts to re-seed the price

Re-seeds the deviation baseline from the current published mid when it is valid.

**Notes:**
- security: Re-enables live pricing after an incident review

- validation: None beyond role check

- events: Emits a breaker-reset event in the implementation

- errors: None

- reentrancy: Reads SlippageStorage

- access: Restricted to EMERGENCY_ROLE

- state-changes: Clears circuitBreakerTriggered; may update the baseline

- oracle: Reads the published mid to re-seed


```solidity
function resetCircuitBreaker() external;
```

### triggerCircuitBreaker

Manually triggers the circuit breaker (use last valid price)

Forces reads onto the last valid price with isValid=false until reset.

**Notes:**
- security: Emergency lever to freeze pricing on a bad feed

- validation: None beyond role check

- events: Emits a breaker-triggered event in the implementation

- errors: None

- reentrancy: No external calls

- access: Restricted to EMERGENCY_ROLE

- state-changes: Sets circuitBreakerTriggered

- oracle: Live reads are suspended until reset


```solidity
function triggerCircuitBreaker() external;
```

### setMaxPriceStaleness

Updates the maximum accepted staleness (seconds) of the published mid

Gates the timestamp validation; capped by the implementation's hard maximum.

**Notes:**
- security: Too-large windows accept outdated prices

- validation: Reverts above the hard cap

- events: Emits a staleness-updated event in the implementation

- errors: Reverts on zero or above-cap values

- reentrancy: No external calls

- access: Restricted to ORACLE_MANAGER_ROLE

- state-changes: Updates the staleness window

- oracle: Affects freshness validation of the published mid


```solidity
function setMaxPriceStaleness(uint256 newMaxStaleness) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMaxStaleness`|`uint256`|New staleness window in seconds|


### updateSlippageSource

Updates the SlippageStorage source contract and source id

Points the adapter at a new SlippageStorage deployment and/or source id.

**Notes:**
- security: The new source becomes the EUR/USD price authority

- validation: Reverts on zero address

- events: Emits a source-updated event in the implementation

- errors: Reverts on zero address

- reentrancy: No external calls

- access: Restricted to ORACLE_MANAGER_ROLE

- state-changes: Updates slippageStorage and sourceId

- oracle: Changes where the EUR/USD mid is read from


```solidity
function updateSlippageSource(address _slippageStorage, uint8 _sourceId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_slippageStorage`|`address`|New SlippageStorage contract address|
|`_sourceId`|`uint8`|New slippage source id to read|


### updateUsdcSource

Updates the USDC/USD source oracle (ChainlinkOracle)

Swaps the delegated USDC/USD oracle.

**Notes:**
- security: The new source becomes the USDC/USD validation authority

- validation: Reverts on zero address

- events: Emits a source-updated event in the implementation

- errors: Reverts on zero address

- reentrancy: No external calls

- access: Restricted to ORACLE_MANAGER_ROLE

- state-changes: Updates usdcSource

- oracle: Changes the delegated USDC/USD feed


```solidity
function updateUsdcSource(address _usdcSource) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_usdcSource`|`address`|New USDC/USD oracle address|


### updateTreasury

Updates the treasury address

The treasury receives recovered tokens/ETH from the recovery functions.

**Notes:**
- security: Recovery destination changes with this address

- validation: Reverts on zero address

- events: Emits TreasuryUpdated

- errors: Reverts on zero address

- reentrancy: No external calls

- access: Restricted to DEFAULT_ADMIN_ROLE

- state-changes: Updates treasury

- oracle: No oracle dependency


```solidity
function updateTreasury(address _treasury) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_treasury`|`address`|New treasury address|


### pause

Pauses oracle reads

While paused, price reads return the last valid price with isValid=false.

**Notes:**
- security: Emergency stop for live pricing

- validation: None beyond role check

- events: Emits Paused

- errors: Reverts when already paused

- reentrancy: No external calls

- access: Restricted to EMERGENCY_ROLE

- state-changes: Sets the paused flag

- oracle: Live reads suspended


```solidity
function pause() external;
```

### unpause

Unpauses oracle reads

Re-enables live price reads.

**Notes:**
- security: Restores live pricing

- validation: None beyond role check

- events: Emits Unpaused

- errors: Reverts when not paused

- reentrancy: No external calls

- access: Restricted to EMERGENCY_ROLE

- state-changes: Clears the paused flag

- oracle: Live reads resume


```solidity
function unpause() external;
```

### recoverToken

Recovers ERC20 tokens to treasury

Routed through TreasuryRecoveryLibrary; funds always go to the treasury.

**Notes:**
- security: Funds can only reach the configured treasury

- validation: Validated by TreasuryRecoveryLibrary

- events: Emits a recovery event in the implementation

- errors: Reverts on invalid token or amount

- reentrancy: Token transfer to the treasury

- access: Restricted to DEFAULT_ADMIN_ROLE

- state-changes: Transfers the token balance

- oracle: No oracle dependency


```solidity
function recoverToken(address token, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token contract address to recover|
|`amount`|`uint256`|Amount of tokens to recover|


### recoverETH

Recovers ETH to treasury

Routed through TreasuryRecoveryLibrary; funds always go to the treasury.

**Notes:**
- security: Funds can only reach the configured treasury

- validation: Validated by TreasuryRecoveryLibrary

- events: Emits a recovery event in the implementation

- errors: Reverts when there is no ETH balance

- reentrancy: ETH send to the treasury

- access: Restricted to DEFAULT_ADMIN_ROLE

- state-changes: Transfers the ETH balance

- oracle: No oracle dependency


```solidity
function recoverETH() external;
```

