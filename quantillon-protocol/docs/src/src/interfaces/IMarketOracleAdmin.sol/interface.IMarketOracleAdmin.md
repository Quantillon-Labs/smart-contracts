# IMarketOracleAdmin
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/e6d6ab67e05d161d0d4815c50b5213a2a6cbb873/src/interfaces/IMarketOracleAdmin.sol)

**Title:**
IMarketOracleAdmin

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Minimal admin surface shared by every oracle that can occupy the router's
MARKET slot (slot 1)

The OracleRouter delegates manager operations to the active oracle. Slot-1
implementations (StorkOracle historically, HyperliquidEurUsdOracle currently)
all expose these four selectors with identical signatures; this interface lets
the router address them without coupling to a concrete implementation name.

**Note:**
security-contact: team@quantillon.money


## Functions
### updatePriceBounds

Updates EUR/USD min and max acceptable prices

Implementation-defined validation; caller is the router (ORACLE_MANAGER_ROLE)

**Notes:**
- security: Restricted by the implementing oracle's access control

- validation: Via implementing oracle

- state-changes: Oracle price bounds

- events: Via implementing oracle

- errors: Via implementing oracle

- reentrancy: No reentrancy protection required at interface level

- access: Implementation-defined (ORACLE_MANAGER_ROLE expected)

- oracle: Configures the implementing oracle


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

Implementation-defined validation; caller is the router (ORACLE_MANAGER_ROLE)

**Notes:**
- security: Restricted by the implementing oracle's access control

- validation: Via implementing oracle

- state-changes: Oracle USDC tolerance

- events: Via implementing oracle

- errors: Via implementing oracle

- reentrancy: No reentrancy protection required at interface level

- access: Implementation-defined (ORACLE_MANAGER_ROLE expected)

- oracle: Configures the implementing oracle


```solidity
function updateUsdcTolerance(uint256 newToleranceBps) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newToleranceBps`|`uint256`|New tolerance (e.g., 200 = 2%)|


### resetCircuitBreaker

Clears the circuit breaker and attempts to resume live prices

Implementation-defined validation; caller is the router (ORACLE_MANAGER_ROLE)

**Notes:**
- security: Restricted by the implementing oracle's access control

- validation: Via implementing oracle

- state-changes: Oracle circuit-breaker state

- events: Via implementing oracle

- errors: Via implementing oracle

- reentrancy: No reentrancy protection required at interface level

- access: Implementation-defined

- oracle: Configures the implementing oracle


```solidity
function resetCircuitBreaker() external;
```

### triggerCircuitBreaker

Manually triggers the circuit breaker to use fallback prices

Implementation-defined validation; caller is the router (ORACLE_MANAGER_ROLE)

**Notes:**
- security: Restricted by the implementing oracle's access control

- validation: Via implementing oracle

- state-changes: Oracle circuit-breaker state

- events: Via implementing oracle

- errors: Via implementing oracle

- reentrancy: No reentrancy protection required at interface level

- access: Implementation-defined

- oracle: Configures the implementing oracle


```solidity
function triggerCircuitBreaker() external;
```

