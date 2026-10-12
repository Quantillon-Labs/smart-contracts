# SignedReferenceSource
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/54366a1075ba6db39540a3d83709a310c26d1723/src/oracle/SignedReferenceSource.sol)

**Inherits:**
AccessControl, EIP712

**Title:**
SignedReferenceSource

Pull-delivered market reference compatible with HyperliquidEurUsdOracle's snapshot reader.

The existing oracle retains price bounds, deviation checks, USDC validation and router semantics.


## Constants
### REFERENCE_SIGNER_ROLE

```solidity
bytes32 public constant REFERENCE_SIGNER_ROLE = keccak256("REFERENCE_SIGNER_ROLE")
```


### EMERGENCY_CONTROLLER_ROLE

```solidity
bytes32 public constant EMERGENCY_CONTROLLER_ROLE = keccak256("EMERGENCY_CONTROLLER_ROLE")
```


### REPORT_TYPEHASH

```solidity
bytes32 public constant REPORT_TYPEHASH =
    keccak256("ReferenceReport(uint256 price,uint256 observedAt,uint256 sequence,uint256 epoch)")
```


### independentReference

```solidity
ISignedIndependentReference public immutable independentReference
```


### maxAge

```solidity
uint256 public immutable maxAge
```


### maxReferenceAge

```solidity
uint256 public immutable maxReferenceAge
```


### normalDivergenceBps

```solidity
uint256 public immutable normalDivergenceBps
```


### offHoursDivergenceBps

```solidity
uint256 public immutable offHoursDivergenceBps
```


## State Variables
### epoch

```solidity
uint256 public epoch = 1
```


### sequence

```solidity
uint256 public sequence
```


### observedAt

```solidity
uint256 public observedAt
```


### price

```solidity
uint256 public price
```


### reportHash

```solidity
bytes32 public reportHash
```


### emergency

```solidity
bool public emergency
```


## Functions
### constructor

Bind the reference authority and immutable freshness and divergence limits.

Binds the EIP-712 domain and immutable safety limits at deployment.

**Notes:**
- security: Validates domain-specific permissions and configured risk bounds.

- validation: Rejects zero or incompatible dependencies and out-of-range safety parameters.

- state-changes: Sets immutable policy, initial mode and administrator role.

- events: RoleGranted for the initial administrator.

- errors: Reverts on invalid inputs, permissions or failed downstream calls.

- reentrancy: Independent price reads use static calls.

- access: Public.

- oracle: Independent EUR/USD validation; accepted reports preserve original market timestamps.


```solidity
constructor(
    address admin,
    address independent,
    uint256 age,
    uint256 referenceAge,
    uint256 normalBps,
    uint256 offHoursBps
) EIP712("Quantillon Reference", "1");
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Authority administering roles and operating parameters.|
|`independent`|`address`|Contract supplying independently validated EUR/USD observations.|
|`age`|`uint256`|Maximum accepted report age in seconds.|
|`referenceAge`|`uint256`|Maximum independent-reference age in seconds.|
|`normalBps`|`uint256`|Reference divergence bound during normal trading hours.|
|`offHoursBps`|`uint256`|Reference divergence bound outside normal trading hours.|


### version

Return the semantic version of this implementation.

Returns the declared configuration or derived value without updating state.

**Notes:**
- security: Read-only; does not authorize settlement.

- validation: Uses the declared input types; target interface calls may revert.

- state-changes: None.

- events: None.

- errors: Propagates invalid input or target read failures.

- reentrancy: Read-only.

- access: Public.

- oracle: No fresh observation is created; reference getters expose existing source data.


```solidity
function version() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Value defined by this accessor or calculation.|


### digest

Hash a market-reference report using this chain and source's EIP-712 domain.

Returns the declared configuration or derived value without updating state.

**Notes:**
- security: Read-only; does not authorize settlement.

- validation: Uses the declared input types; target interface calls may revert.

- state-changes: None.

- events: None.

- errors: Propagates invalid input or target read failures.

- reentrancy: Read-only.

- access: Public.

- oracle: No fresh observation is created; reference getters expose existing source data.


```solidity
function digest(T.ReferenceReport calldata r) public view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`r`|`T.ReferenceReport`|Signed report containing its original observation, sequence and epoch.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Value defined by this accessor or calculation.|


### submit

Authenticate a reference report, updating the cache only for newer observations.

Original observation timestamps remain authoritative; signature replay never refreshes them.

**Notes:**
- security: Validates domain-specific permissions and configured risk bounds.

- validation: Enforces the checks described for this operation; invalid authorization reverts.

- state-changes: Stores price, original observation, sequence and digest.

- events: ReferenceAccepted for a new observation.

- errors: Reverts on invalid inputs, permissions or failed downstream calls.

- reentrancy: Independent price reads use static calls.

- access: Anyone may relay a valid reference signature.

- oracle: Independent EUR/USD validation; accepted reports preserve original market timestamps.


```solidity
function submit(T.ReferenceReport calldata r, bytes calldata signature) external returns (bytes32 hash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`r`|`T.ReferenceReport`|Signed report containing its original observation, sequence and epoch.|
|`signature`|`bytes`|EIP-712 signature by the corresponding authorized signer.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`hash`|`bytes32`|EIP-712 digest of the accepted report.|


### setEmergency

Change reference mode and invalidate prior reference authorizations.

Original observation timestamps remain authoritative; signature replay never refreshes them.

**Notes:**
- security: Validates domain-specific permissions and configured risk bounds.

- validation: Enforces the checks described for this operation; invalid authorization reverts.

- state-changes: Updates emergency state and reference epoch.

- events: ReferenceEpochChanged when the mode changes.

- errors: Reverts on invalid inputs, permissions or failed downstream calls.

- reentrancy: Independent price reads use static calls.

- access: Emergency-controller role only.

- oracle: Independent EUR/USD validation; accepted reports preserve original market timestamps.


```solidity
function setEmergency(bool enabled) external onlyRole(EMERGENCY_CONTROLLER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`enabled`|`bool`|Enabled-vault mapping, or requested emergency state for the reference source.|


### getSlippageBySource

Read a compatible snapshot with its original market or independent-reference timestamp.

Returns the declared configuration or derived value without updating state.

**Notes:**
- security: Read-only; does not authorize settlement.

- validation: Uses the declared input types; target interface calls may revert.

- state-changes: None.

- events: None.

- errors: Propagates invalid input or target read failures.

- reentrancy: Read-only.

- access: Public.

- oracle: No fresh observation is created; reference getters expose existing source data.


```solidity
function getSlippageBySource(uint8 source)
    external
    view
    returns (ISlippageStorage.SlippageSnapshot memory snapshot);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`source`|`uint8`|Reference-source address, or snapshot source ID for the snapshot reader.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`snapshot`|`ISlippageStorage.SlippageSnapshot`|Price and original timestamp in the snapshot interface.|


### _independent


```solidity
function _independent() private view returns (uint256 p, uint256 time);
```

### _validateIndependent


```solidity
function _validateIndependent(uint256 candidate) private view;
```

## Events
### ReferenceAccepted

```solidity
event ReferenceAccepted(bytes32 indexed digest, uint256 price, uint256 observedAt, uint256 sequence);
```

### ReferenceEpochChanged

```solidity
event ReferenceEpochChanged(uint256 epoch, bool emergency);
```
