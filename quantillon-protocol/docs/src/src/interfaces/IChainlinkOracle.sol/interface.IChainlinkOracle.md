# IChainlinkOracle
**Inherits:**
[IOracle](/src/interfaces/IOracle.sol/interface.IOracle.md)

**Title:**
IChainlinkOracle

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Interface for the Quantillon Chainlink-based oracle

Extends IOracle with Chainlink-specific functions
This interface is specific to ChainlinkOracle implementation

**Note:**
security-contact: team@quantillon.money


## Functions
### initialize

Initializes the oracle with admin and feed addresses

Sets up the oracle with initial configuration and assigns roles to admin

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function initialize(address admin, address _eurUsdPriceFeed, address _usdcUsdPriceFeed, address _treasury) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address that receives admin and manager roles|
|`_eurUsdPriceFeed`|`address`|Chainlink EUR/USD feed address|
|`_usdcUsdPriceFeed`|`address`|Chainlink USDC/USD feed address|
|`_treasury`|`address`|Treasury address|


### updatePriceBounds

Updates EUR/USD min and max acceptable prices

Updates the price bounds for EUR/USD validation with security checks

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function updateUsdcTolerance(uint256 newToleranceBps) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newToleranceBps`|`uint256`|New tolerance (e.g., 200 = 2%)|


### updatePriceFeeds

Updates Chainlink feed addresses

Updates the addresses of both Chainlink price feeds with validation

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function updatePriceFeeds(address _eurUsdFeed, address _usdcUsdFeed) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_eurUsdFeed`|`address`|New EUR/USD feed|
|`_usdcUsdFeed`|`address`|New USDC/USD feed|


### resetCircuitBreaker

Clears circuit breaker and attempts to resume live prices

Resets the circuit breaker state to allow normal price operations

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function resetCircuitBreaker() external;
```

### triggerCircuitBreaker

Manually triggers circuit breaker to use fallback prices

Activates circuit breaker to switch to fallback price mode for safety

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function triggerCircuitBreaker() external;
```

### pause

Pauses all oracle operations

Pauses the oracle contract to halt all price operations

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function pause() external;
```

### unpause

Unpauses oracle operations

Resumes oracle operations after being paused

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function unpause() external;
```

### recoverToken

Recovers ERC20 tokens sent to the oracle contract by mistake

Allows recovery of ERC20 tokens accidentally sent to the oracle contract

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function recoverETH() external;
```

