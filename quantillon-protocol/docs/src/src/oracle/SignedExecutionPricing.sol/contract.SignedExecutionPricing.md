# SignedExecutionPricing
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/083874330beb67c980851f48832ef5faa68973d3/src/oracle/SignedExecutionPricing.sol)

**Inherits:**
AccessControl, EIP712, [IExecutionPricing](/src/interfaces/IExecutionPricing.sol/interface.IExecutionPricing.md)

**Title:**
SignedExecutionPricing

Exact quotes with independently certified capacity and persistent admission accounting.

Non-upgradeable, vault-bound replacement. A settlement context must begin and end in one vault call.


## Constants
### QUOTE_SIGNER_ROLE

```solidity
bytes32 public constant QUOTE_SIGNER_ROLE = keccak256("QUOTE_SIGNER_ROLE")
```


### CAPACITY_SIGNER_ROLE

```solidity
bytes32 public constant CAPACITY_SIGNER_ROLE = keccak256("CAPACITY_SIGNER_ROLE")
```


### EMERGENCY_ROLE

```solidity
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE")
```


### QUOTE_TYPEHASH

```solidity
bytes32 public constant QUOTE_TYPEHASH = keccak256(
    "Quote(address user,address caller,uint8 action,uint256 amountIn,uint256 amountOut,uint256 observedAt,uint256 validAfter,uint256 validUntil,uint256 nonce,uint256 epoch,bytes32 callHash,bytes32 referenceHash)"
)
```


### CAPACITY_TYPEHASH

```solidity
bytes32 public constant CAPACITY_TYPEHASH = keccak256(
    "CapacityReport(uint256 acknowledgedBuy,uint256 acknowledgedSell,uint256 capacity,uint256 observedAt,uint256 sequence,uint256 epoch,uint256 canonicalBlock,bytes32 canonicalBlockHash)"
)
```


### vault

```solidity
address public immutable override vault
```


### reserveRecipient

```solidity
address public immutable reserveRecipient
```


### referenceSource

```solidity
SignedReferenceSource public immutable referenceSource
```


### maxImpactBps

```solidity
uint256 public immutable maxImpactBps
```


### maxOutstanding

```solidity
uint256 public immutable maxOutstanding
```


### maxAge

```solidity
uint256 public immutable maxAge
```


### degradedHaircutBps

```solidity
uint256 public immutable degradedHaircutBps
```


## State Variables
### mode

```solidity
T.Mode public mode
```


### epoch

```solidity
uint256 public epoch = 1
```


### admittedBuy

```solidity
uint256 public admittedBuy
```


### admittedSell

```solidity
uint256 public admittedSell
```


### acknowledgedBuy

```solidity
uint256 public acknowledgedBuy
```


### acknowledgedSell

```solidity
uint256 public acknowledgedSell
```


### marginCapacity

```solidity
uint256 public marginCapacity
```


### capacityObservedAt

```solidity
uint256 public capacityObservedAt
```


### capacitySequence

```solidity
uint256 public capacitySequence
```


### capacityHash

```solidity
bytes32 public capacityHash
```


### emergencyBudget

```solidity
uint256 public emergencyBudget
```


### usedNonces

```solidity
mapping(address => mapping(uint256 => bool)) public usedNonces
```


### activeQuote

```solidity
T.Quote private activeQuote
```


### active

```solidity
bool public active
```


### consumed

```solidity
bool private consumed
```


### emergencySettlement

```solidity
bool private emergencySettlement
```


### activeReference

```solidity
uint256 private activeReference
```


### activeDigest

```solidity
bytes32 private activeDigest
```


## Functions
### constructor

Bind the vault, reference source and immutable execution risk limits.

Binds the EIP-712 domain and immutable safety limits at deployment.

**Notes:**
- security: Validates domain-specific permissions and configured risk bounds.

- validation: Rejects zero or incompatible dependencies and out-of-range safety parameters.

- state-changes: Sets immutable policy, initial mode and administrator role.

- events: RoleGranted for the initial administrator.

- errors: Reverts on invalid inputs, permissions or failed downstream calls.

- reentrancy: Vault-only settlement and active-context checks constrain callbacks.

- access: Public.

- oracle: Signed reference and reconciled capacity for normal conversion; separate emergency policy.


```solidity
constructor(
    address admin,
    address boundVault,
    address source,
    address reserve,
    uint256 impact,
    uint256 outstandingLimit,
    uint256 age,
    uint256 haircut
) EIP712("Quantillon Execution", "1");
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Authority administering roles and operating parameters.|
|`boundVault`|`address`|Vault allowed to prepare and consume execution contexts.|
|`source`|`address`|Reference-source address, or snapshot source ID for the snapshot reader.|
|`reserve`|`address`|Immutable recipient of execution spread withdrawals.|
|`impact`|`uint256`|Maximum permitted execution impact in basis points.|
|`outstandingLimit`|`uint256`|Maximum gross unacknowledged QEURO exposure.|
|`age`|`uint256`|Maximum accepted report age in seconds.|
|`haircut`|`uint256`|Emergency redemption haircut in basis points.|


### onlyVault


```solidity
modifier onlyVault() ;
```

### supportsSignedExecution

Identify this module as requiring signed execution contexts.

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
function supportsSignedExecution() external pure returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Value defined by this accessor or calculation.|


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


### quoteDigest

Hash an execution quote using this chain and module's EIP-712 domain.

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
function quoteDigest(T.Quote calldata q) public view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`q`|`T.Quote`|Execution quote to hash.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Value defined by this accessor or calculation.|


### capacityDigest

Hash a capacity report using this chain and module's EIP-712 domain.

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
function capacityDigest(T.CapacityReport calldata r) public view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`r`|`T.CapacityReport`|Signed report containing its original observation, sequence and epoch.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Value defined by this accessor or calculation.|


### outstanding

Return unresolved admitted buys plus unresolved admitted sells in QEURO units.

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
function outstanding() public view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Value defined by this accessor or calculation.|


### submitCapacity

Accept monotonic fill acknowledgments bound to canonical Base state.

Execution contexts are single-use and cannot replace the vault's accounting guards.

**Notes:**
- security: Validates domain-specific permissions and configured risk bounds.

- validation: Enforces the checks described for this operation; invalid authorization reverts.

- state-changes: Updates acknowledged exposure, capacity, sequence and original observation time.

- events: HedgeAcknowledged.

- errors: Reverts on invalid inputs, permissions or failed downstream calls.

- reentrancy: Vault-only settlement and active-context checks constrain callbacks.

- access: Anyone may relay a valid capacity signature.

- oracle: Signed reference and reconciled capacity for normal conversion; separate emergency policy.


```solidity
function submitCapacity(T.CapacityReport calldata r, bytes calldata signature) public;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`r`|`T.CapacityReport`|Signed report containing its original observation, sequence and epoch.|
|`signature`|`bytes`|EIP-712 signature by the corresponding authorized signer.|


### prepare

Validate and prepare the operation before settlement.

Execution contexts are single-use and cannot replace the vault's accounting guards.

**Notes:**
- security: Validates domain-specific permissions and configured risk bounds.

- validation: Enforces the checks described for this operation; invalid authorization reverts.

- state-changes: Stores the active quote and consumes its nonce after report validation.

- events: Underlying operation and token events when applicable.

- errors: Reverts on invalid inputs, permissions or failed downstream calls.

- reentrancy: Vault-only settlement and active-context checks constrain callbacks.

- access: Configured vault only.

- oracle: Signed reference and reconciled capacity for normal conversion; separate emergency policy.


```solidity
function prepare(address user, address caller, bytes calldata callData, T.Authorization calldata auth)
    external
    onlyVault;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Original payer whose nonce and settlement are bound.|
|`caller`|`address`|Executor that must match the active quote.|
|`callData`|`bytes`|Complete ABI-encoded operation, including route and output bounds.|
|`auth`|`T.Authorization`|Complete execution, reference and capacity authorization.|


### prepareEmergency

Reserve the emergency budget for one redemption.

Execution contexts are single-use and cannot replace the vault's accounting guards.

**Notes:**
- security: Validates domain-specific permissions and configured risk bounds.

- validation: Enforces the checks described for this operation; invalid authorization reverts.

- state-changes: Decrements the emergency budget and initializes one redemption context.

- events: Underlying operation and token events when applicable.

- errors: Reverts on invalid inputs, permissions or failed downstream calls.

- reentrancy: Vault-only settlement and active-context checks constrain callbacks.

- access: Configured vault only.

- oracle: Signed reference and reconciled capacity for normal conversion; separate emergency policy.


```solidity
function prepareEmergency(address caller, uint256 amount) external onlyVault;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`caller`|`address`|Executor that must match the active quote.|
|`amount`|`uint256`|Amount in the token units of the selected operation.|


### requireContext

Require the active settlement to belong to the specified executor.

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
function requireContext(address caller) external view onlyVault;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`caller`|`address`|Executor that must match the active quote.|


### finish

Close a consumed settlement or a permitted zero-yield harvest.

Execution contexts are single-use and cannot replace the vault's accounting guards.

**Notes:**
- security: Validates domain-specific permissions and configured risk bounds.

- validation: Enforces the checks described for this operation; invalid authorization reverts.

- state-changes: Clears the active settlement context.

- events: Underlying operation and token events when applicable.

- errors: Reverts on invalid inputs, permissions or failed downstream calls.

- reentrancy: Vault-only settlement and active-context checks constrain callbacks.

- access: Configured vault only.

- oracle: Signed reference and reconciled capacity for normal conversion; separate emergency policy.


```solidity
function finish(bool allowNoConversion) external onlyVault;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`allowNoConversion`|`bool`|Whether an authorized zero-yield harvest may finish without minting.|


### consumeMint

Consume the exact mint or bounded yield authorization and admit its hedge exposure.

Execution contexts are single-use and cannot replace the vault's accounting guards.

**Notes:**
- security: Validates domain-specific permissions and configured risk bounds.

- validation: Enforces the checks described for this operation; invalid authorization reverts.

- state-changes: Increments admitted buy exposure and marks the quote consumed.

- events: QuoteSettled.

- errors: Reverts on invalid inputs, permissions or failed downstream calls.

- reentrancy: Vault-only settlement and active-context checks constrain callbacks.

- access: Configured vault only.

- oracle: Signed reference and reconciled capacity for normal conversion; separate emergency policy.


```solidity
function consumeMint(uint256 netUsdc, uint256 referencePrice)
    external
    override
    onlyVault
    returns (uint256 q, uint256 backing);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`netUsdc`|`uint256`|USDC available for conversion after protocol fees.|
|`referencePrice`|`uint256`|Validated EUR/USD reference in 1e18 precision.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`q`|`uint256`|Authorized QEURO output in eighteen-decimal units.|
|`backing`|`uint256`|Reference-valued backing in six-decimal USDC units.|


### consumeRedeem

Consume a redemption authorization while enforcing reference fees and spread limits.

Execution contexts are single-use and cannot replace the vault's accounting guards.

**Notes:**
- security: Validates domain-specific permissions and configured risk bounds.

- validation: Enforces the checks described for this operation; invalid authorization reverts.

- state-changes: Increments admitted sell exposure and marks the quote consumed.

- events: QuoteSettled.

- errors: Reverts on invalid inputs, permissions or failed downstream calls.

- reentrancy: Vault-only settlement and active-context checks constrain callbacks.

- access: Configured vault only.

- oracle: Signed reference and reconciled capacity for normal conversion; separate emergency policy.


```solidity
function consumeRedeem(uint256 qeuroIn, uint256 referencePrice)
    external
    override
    onlyVault
    returns (uint256 executionUsdc);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroIn`|`uint256`|QEURO input in eighteen-decimal units.|
|`referencePrice`|`uint256`|Validated EUR/USD reference in 1e18 precision.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`executionUsdc`|`uint256`|Execution-valued USDC before protocol redemption fees.|


### consumeLiquidation

Account for the admitted sell exposure of a budgeted liquidation redemption.

Execution contexts are single-use and cannot replace the vault's accounting guards.

**Notes:**
- security: Validates domain-specific permissions and configured risk bounds.

- validation: Enforces the checks described for this operation; invalid authorization reverts.

- state-changes: Increments admitted sell exposure and marks the emergency conversion consumed.

- events: Underlying operation and token events when applicable.

- errors: Reverts on invalid inputs, permissions or failed downstream calls.

- reentrancy: Vault-only settlement and active-context checks constrain callbacks.

- access: Configured vault only.

- oracle: Signed reference and reconciled capacity for normal conversion; separate emergency policy.


```solidity
function consumeLiquidation(uint256 qeuroIn) external onlyVault;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroIn`|`uint256`|QEURO input in eighteen-decimal units.|


### setMode

Change operating mode and invalidate outstanding execution authorizations.

Execution contexts are single-use and cannot replace the vault's accounting guards.

**Notes:**
- security: Validates domain-specific permissions and configured risk bounds.

- validation: Enforces the checks described for this operation; invalid authorization reverts.

- state-changes: Updates mode and epoch, invalidates capacity freshness and selects reference mode.

- events: ModeChanged and reference-mode events when changed.

- errors: Reverts on invalid inputs, permissions or failed downstream calls.

- reentrancy: Vault-only settlement and active-context checks constrain callbacks.

- access: Admin to enable Signed mode; admin or emergency role to stop normal execution.

- oracle: Signed reference and reconciled capacity for normal conversion; separate emergency policy.


```solidity
function setMode(T.Mode next) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`next`|`T.Mode`|Requested operating mode.|


### configureEmergencyBudget

Set an emergency budget only while paused and with no unacknowledged exposure.

Execution contexts are single-use and cannot replace the vault's accounting guards.

**Notes:**
- security: Validates domain-specific permissions and configured risk bounds.

- validation: Enforces the checks described for this operation; invalid authorization reverts.

- state-changes: Replaces the explicitly configured emergency budget.

- events: EmergencyBudgetConfigured.

- errors: Reverts on invalid inputs, permissions or failed downstream calls.

- reentrancy: Vault-only settlement and active-context checks constrain callbacks.

- access: Default admin only.

- oracle: Signed reference and reconciled capacity for normal conversion; separate emergency policy.


```solidity
function configureEmergencyBudget(uint256 budget) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`budget`|`uint256`|Maximum emergency QEURO redemption amount in eighteen-decimal units.|


### withdrawReserve

Transfer execution spread to the immutable reserve recipient.

Execution contexts are single-use and cannot replace the vault's accounting guards.

**Notes:**
- security: Validates domain-specific permissions and configured risk bounds.

- validation: Enforces the checks described for this operation; invalid authorization reverts.

- state-changes: Transfers module-held USDC to the configured recipient.

- events: Underlying operation and token events when applicable.

- errors: Reverts on invalid inputs, permissions or failed downstream calls.

- reentrancy: Vault-only settlement and active-context checks constrain callbacks.

- access: Default admin only.

- oracle: Signed reference and reconciled capacity for normal conversion; separate emergency policy.


```solidity
function withdrawReserve(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount in the token units of the selected operation.|


### _checkContext


```solidity
function _checkContext(uint256 referencePrice) private view;
```

### _admit


```solidity
function _admit(uint256 quantity, bool buy) private;
```

### _validateSelector


```solidity
function _validateSelector(bytes4 selector, T.Action action) private pure;
```

## Events
### QuoteSettled

```solidity
event QuoteSettled(
    bytes32 indexed quoteId, address indexed caller, T.Action action, uint256 amountIn, uint256 amountOut
);
```

### HedgeAcknowledged

```solidity
event HedgeAcknowledged(uint256 admittedBuy, uint256 admittedSell, uint256 capacity, uint256 observedAt);
```

### ModeChanged

```solidity
event ModeChanged(T.Mode mode, uint256 epoch);
```

### EmergencyBudgetConfigured

```solidity
event EmergencyBudgetConfigured(uint256 budget);
```
