# IStorkOracle
**Inherits:**
[IOracle](/src/interfaces/IOracle.sol/interface.IOracle.md)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Interface for the Quantillon Stork-based oracle

*Extends IOracle with Stork-specific functions
This interface is specific to StorkOracle implementation*

**Note:**
team@quantillon.money


## Functions
### initialize

Initializes the oracle with admin and Stork feed addresses

*Sets up the oracle with initial configuration and assigns roles to admin*

**Notes:**
- Validates all addresses are non-zero, grants admin roles

- Validates all input addresses are not address(0)

- Initializes all state variables, sets default price bounds

- Emits PriceUpdated during initial price update

- Throws "Oracle: Admin cannot be zero" if admin is address(0)

- Protected by initializer modifier

- Public - only callable once during deployment

- Initializes Stork price feed interfaces


```solidity
function initialize(
    address admin,
    address _storkFeedAddress,
    bytes32 _eurUsdFeedId,
    bytes32 _usdcUsdFeedId,
    address _treasury
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address that receives admin and manager roles|
|`_storkFeedAddress`|`address`|Stork feed contract address|
|`_eurUsdFeedId`|`bytes32`|Stork EUR/USD feed ID (bytes32)|
|`_usdcUsdFeedId`|`bytes32`|Stork USDC/USD feed ID (bytes32)|
|`_treasury`|`address`|Treasury address|


### updatePriceBounds

Updates EUR/USD min and max acceptable prices

*Updates the price bounds for EUR/USD validation with security checks*

**Notes:**
- Validates min < max and reasonable bounds

- Validates price bounds are within acceptable range

- Updates minPrice and maxPrice state variables

- Emits PriceBoundsUpdated event

- Throws if minPrice >= maxPrice or invalid bounds

- Protected by reentrancy guard

- Restricted to ORACLE_MANAGER_ROLE

- No oracle dependency - configuration update only


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

*Updates the USDC price tolerance for validation with security checks*

**Notes:**
- Validates tolerance is within reasonable limits

- Validates tolerance is not zero and within max bounds

- Updates usdcTolerance state variable

- Emits UsdcToleranceUpdated event

- Throws if tolerance is invalid or out of bounds

- Protected by reentrancy guard

- Restricted to ORACLE_MANAGER_ROLE

- No oracle dependency - configuration update only


```solidity
function updateUsdcTolerance(uint256 newToleranceBps) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newToleranceBps`|`uint256`|New tolerance (e.g., 200 = 2%)|


### updatePriceFeeds

Updates Stork feed addresses and feed IDs

*Updates the addresses and feed IDs of both Stork price feeds with validation*

**Notes:**
- Validates feed address is non-zero and contract exists

- Validates all addresses are not address(0)

- Updates eurUsdPriceFeed, usdcUsdPriceFeed, and feed IDs

- Emits PriceFeedsUpdated event

- Throws if feed address is zero or invalid

- Protected by reentrancy guard

- Restricted to ORACLE_MANAGER_ROLE

- Updates Stork feed contract references


```solidity
function updatePriceFeeds(address _storkFeedAddress, bytes32 _eurUsdFeedId, bytes32 _usdcUsdFeedId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_storkFeedAddress`|`address`|New Stork feed contract address|
|`_eurUsdFeedId`|`bytes32`|New EUR/USD feed ID|
|`_usdcUsdFeedId`|`bytes32`|New USDC/USD feed ID|


### resetCircuitBreaker

Clears circuit breaker and attempts to resume live prices

*Resets the circuit breaker state to allow normal price operations*

**Notes:**
- Resets circuit breaker after manual intervention

- Validates circuit breaker was previously triggered

- Resets circuitBreakerTriggered flag

- Emits CircuitBreakerReset event

- No errors thrown

- Protected by reentrancy guard

- Restricted to ORACLE_MANAGER_ROLE

- Resumes normal oracle price queries


```solidity
function resetCircuitBreaker() external;
```

### triggerCircuitBreaker

Manually triggers circuit breaker to use fallback prices

*Activates circuit breaker to switch to fallback price mode for safety*

**Notes:**
- Manually activates circuit breaker for emergency situations

- No validation - emergency function

- Sets circuitBreakerTriggered flag to true

- Emits CircuitBreakerTriggered event

- No errors thrown

- Protected by reentrancy guard

- Restricted to ORACLE_MANAGER_ROLE

- Switches to fallback prices instead of live oracle queries


```solidity
function triggerCircuitBreaker() external;
```

### pause

Pauses all oracle operations

*Pauses the oracle contract to halt all price operations*

**Notes:**
- Emergency pause to halt all oracle operations

- No validation - emergency function

- Sets paused state to true

- Emits Paused event

- No errors thrown

- Protected by reentrancy guard

- Restricted to EMERGENCY_ROLE

- Halts all oracle price queries


```solidity
function pause() external;
```

### unpause

Unpauses oracle operations

*Resumes oracle operations after being paused*

**Notes:**
- Resumes oracle operations after pause

- Validates contract was previously paused

- Sets paused state to false

- Emits Unpaused event

- No errors thrown

- Protected by reentrancy guard

- Restricted to EMERGENCY_ROLE

- Resumes normal oracle price queries


```solidity
function unpause() external;
```

### recoverToken

Recovers ERC20 tokens sent to the oracle contract by mistake

*Allows recovery of ERC20 tokens accidentally sent to the oracle contract*

**Notes:**
- Transfers tokens to treasury, prevents accidental loss

- Validates token and amount are non-zero

- Transfers tokens from contract to treasury

- Emits TokenRecovered event

- Throws if token is zero address or transfer fails

- Protected by reentrancy guard

- Restricted to DEFAULT_ADMIN_ROLE

- No oracle dependency


```solidity
function recoverToken(address token, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address to recover|
|`amount`|`uint256`|Amount to transfer|


### recoverETH

Recovers ETH sent to the oracle contract by mistake

*Allows recovery of ETH accidentally sent to the oracle contract*

**Notes:**
- Transfers ETH to treasury, prevents accidental loss

- Validates contract has ETH balance

- Transfers ETH from contract to treasury

- Emits ETHRecovered event

- Throws if transfer fails

- Protected by reentrancy guard

- Restricted to DEFAULT_ADMIN_ROLE

- No oracle dependency


```solidity
function recoverETH() external;
```

