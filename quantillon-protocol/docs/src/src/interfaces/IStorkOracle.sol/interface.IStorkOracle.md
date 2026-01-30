# IStorkOracle
**Inherits:**
[IOracle](/src/interfaces/IOracle.sol/interface.IOracle.md)

**Title:**
IStorkOracle

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Interface for the Quantillon Stork-based oracle

Extends IOracle with Stork-specific functions
This interface is specific to StorkOracle implementation

**Note:**
security-contact: team@quantillon.money


## Functions
### initialize

Initializes the oracle with admin and Stork feed addresses

Sets up the oracle with initial configuration and assigns roles to admin

**Notes:**
- security: Validates all addresses are non-zero, grants admin roles

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

Updates the price bounds for EUR/USD validation with security checks

**Notes:**
- security: Validates min < max and reasonable bounds

- validation: Validates price bounds are within acceptable range

- state-changes: Updates minPrice and maxPrice state variables

- events: Emits PriceBoundsUpdated event

- errors: Throws if minPrice >= maxPrice or invalid bounds

- reentrancy: Protected by reentrancy guard

- access: Restricted to ORACLE_MANAGER_ROLE

- oracle: No oracle dependency - configuration update only


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

Updates the USDC price tolerance for validation with security checks

**Notes:**
- security: Validates tolerance is within reasonable limits

- validation: Validates tolerance is not zero and within max bounds

- state-changes: Updates usdcTolerance state variable

- events: Emits UsdcToleranceUpdated event

- errors: Throws if tolerance is invalid or out of bounds

- reentrancy: Protected by reentrancy guard

- access: Restricted to ORACLE_MANAGER_ROLE

- oracle: No oracle dependency - configuration update only


```solidity
function updateUsdcTolerance(uint256 newToleranceBps) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newToleranceBps`|`uint256`|New tolerance (e.g., 200 = 2%)|


### updatePriceFeeds

Updates Stork feed addresses and feed IDs

Updates the addresses and feed IDs of both Stork price feeds with validation

**Notes:**
- security: Validates feed address is non-zero and contract exists

- validation: Validates all addresses are not address(0)

- state-changes: Updates eurUsdPriceFeed, usdcUsdPriceFeed, and feed IDs

- events: Emits PriceFeedsUpdated event

- errors: Throws if feed address is zero or invalid

- reentrancy: Protected by reentrancy guard

- access: Restricted to ORACLE_MANAGER_ROLE

- oracle: Updates Stork feed contract references


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

Resets the circuit breaker state to allow normal price operations

**Notes:**
- security: Resets circuit breaker after manual intervention

- validation: Validates circuit breaker was previously triggered

- state-changes: Resets circuitBreakerTriggered flag

- events: Emits CircuitBreakerReset event

- errors: No errors thrown

- reentrancy: Protected by reentrancy guard

- access: Restricted to ORACLE_MANAGER_ROLE

- oracle: Resumes normal oracle price queries


```solidity
function resetCircuitBreaker() external;
```

### triggerCircuitBreaker

Manually triggers circuit breaker to use fallback prices

Activates circuit breaker to switch to fallback price mode for safety

**Notes:**
- security: Manually activates circuit breaker for emergency situations

- validation: No validation - emergency function

- state-changes: Sets circuitBreakerTriggered flag to true

- events: Emits CircuitBreakerTriggered event

- errors: No errors thrown

- reentrancy: Protected by reentrancy guard

- access: Restricted to ORACLE_MANAGER_ROLE

- oracle: Switches to fallback prices instead of live oracle queries


```solidity
function triggerCircuitBreaker() external;
```

### pause

Pauses all oracle operations

Pauses the oracle contract to halt all price operations

**Notes:**
- security: Emergency pause to halt all oracle operations

- validation: No validation - emergency function

- state-changes: Sets paused state to true

- events: Emits Paused event

- errors: No errors thrown

- reentrancy: Protected by reentrancy guard

- access: Restricted to EMERGENCY_ROLE

- oracle: Halts all oracle price queries


```solidity
function pause() external;
```

### unpause

Unpauses oracle operations

Resumes oracle operations after being paused

**Notes:**
- security: Resumes oracle operations after pause

- validation: Validates contract was previously paused

- state-changes: Sets paused state to false

- events: Emits Unpaused event

- errors: No errors thrown

- reentrancy: Protected by reentrancy guard

- access: Restricted to EMERGENCY_ROLE

- oracle: Resumes normal oracle price queries


```solidity
function unpause() external;
```

### recoverToken

Recovers ERC20 tokens sent to the oracle contract by mistake

Allows recovery of ERC20 tokens accidentally sent to the oracle contract

**Notes:**
- security: Transfers tokens to treasury, prevents accidental loss

- validation: Validates token and amount are non-zero

- state-changes: Transfers tokens from contract to treasury

- events: Emits TokenRecovered event

- errors: Throws if token is zero address or transfer fails

- reentrancy: Protected by reentrancy guard

- access: Restricted to DEFAULT_ADMIN_ROLE

- oracle: No oracle dependency


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

Allows recovery of ETH accidentally sent to the oracle contract

**Notes:**
- security: Transfers ETH to treasury, prevents accidental loss

- validation: Validates contract has ETH balance

- state-changes: Transfers ETH from contract to treasury

- events: Emits ETHRecovered event

- errors: Throws if transfer fails

- reentrancy: Protected by reentrancy guard

- access: Restricted to DEFAULT_ADMIN_ROLE

- oracle: No oracle dependency


```solidity
function recoverETH() external;
```

