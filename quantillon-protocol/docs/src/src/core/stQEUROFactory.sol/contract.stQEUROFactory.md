# stQEUROFactory
**Inherits:**
Initializable, AccessControlUpgradeable, [SecureUpgradeable](/src/core/SecureUpgradeable.sol/abstract.SecureUpgradeable.md)

**Title:**
stQEUROFactory

Deploys and registers one stQEURO token proxy per staking vault.


## State Variables
### GOVERNANCE_ROLE

```solidity
bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE")
```


### VAULT_FACTORY_ROLE

```solidity
bytes32 public constant VAULT_FACTORY_ROLE = keccak256("VAULT_FACTORY_ROLE")
```


### tokenImplementation
stQEUROToken implementation used by newly deployed ERC1967 proxies.


```solidity
address public tokenImplementation
```


### qeuro

```solidity
address public qeuro
```


### yieldShift

```solidity
address public yieldShift
```


### usdc

```solidity
address public usdc
```


### treasury

```solidity
address public treasury
```


### oracle

```solidity
address public oracle
```


### tokenAdmin

```solidity
address public tokenAdmin
```


### stQEUROByVaultId

```solidity
mapping(uint256 => address) public stQEUROByVaultId
```


### stQEUROByVault

```solidity
mapping(address => address) public stQEUROByVault
```


### vaultById

```solidity
mapping(uint256 => address) public vaultById
```


### vaultIdByStQEURO

```solidity
mapping(address => uint256) public vaultIdByStQEURO
```


### _vaultNamesById

```solidity
mapping(uint256 => string) private _vaultNamesById
```


### _vaultNameHashUsed

```solidity
mapping(bytes32 => bool) private _vaultNameHashUsed
```


## Functions
### constructor

Disables initializers on the implementation contract.

Prevents direct initialization of the logic contract in proxy deployments.

**Notes:**
- security: Locks implementation initialization to prevent takeover.

- validation: No input parameters.

- state-changes: Sets initializer state to disabled.

- events: No events emitted.

- errors: No custom errors expected.

- reentrancy: Not applicable during construction.

- access: Constructor executes once at deployment.

- oracle: No oracle dependencies.


```solidity
constructor() ;
```

### initialize

Initializes the stQEURO factory configuration and roles.

Sets deployment dependencies and grants admin/governance/factory roles to `admin`.

**Notes:**
- security: Validates all critical addresses before storing configuration.

- validation: Reverts on zero addresses for required dependencies.

- state-changes: Initializes access control and stores factory dependencies.

- events: Emits role grant events from AccessControl initialization.

- errors: Reverts with custom invalid-address errors for bad inputs.

- reentrancy: Protected by initializer pattern; no external untrusted flow.

- access: Callable once via `initializer`.

- oracle: Stores oracle configuration address; no live price reads.


```solidity
function initialize(
    address admin,
    address _tokenImplementation,
    address _qeuro,
    address _yieldShift,
    address _usdc,
    address _treasury,
    address _timelock,
    address _oracle
) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address receiving admin and governance privileges.|
|`_tokenImplementation`|`address`|ERC1967 implementation used for new stQEURO proxies.|
|`_qeuro`|`address`|QEURO token address.|
|`_yieldShift`|`address`|YieldShift contract address.|
|`_usdc`|`address`|USDC token address.|
|`_treasury`|`address`|Treasury address used by deployed tokens.|
|`_timelock`|`address`|Timelock contract used by SecureUpgradeable.|
|`_oracle`|`address`|Oracle address referenced by the factory configuration.|


### registerVault

Strict self-registration entrypoint. Caller vault deploys its own stQEURO.

Computes deterministic proxy address, commits registry state, then deploys proxy with CREATE2.

**Notes:**
- security: Restricts calls to `VAULT_FACTORY_ROLE` and enforces single-registration invariants.

- validation: Validates non-zero vault id, caller uniqueness, and vault name format.

- state-changes: Writes vault/token registry mappings and vault name tracking.

- events: Emits `VaultRegistered` on successful registration.

- errors: Reverts on invalid input, duplicate registration, or unexpected deployment address.

- reentrancy: Uses deterministic CEI ordering; critical state is committed before proxy deployment.

- access: Restricted to `VAULT_FACTORY_ROLE`.

- oracle: No oracle dependencies.


```solidity
function registerVault(uint256 vaultId, string calldata vaultName)
    external
    onlyRole(VAULT_FACTORY_ROLE)
    returns (address stQEUROToken_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vaultId`|`uint256`|Unique vault identifier in factory registry.|
|`vaultName`|`string`|Uppercase alphanumeric vault label used for token metadata.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`stQEUROToken_`|`address`|Deterministic stQEURO proxy address registered for the vault.|


### previewVaultToken

Previews the deterministic stQEURO token address for a vault registration.

Computes the CREATE2 address using current factory configuration and provided vault metadata.

**Notes:**
- security: Read-only helper for deterministic address binding before registration.

- validation: Reverts for zero vault address, zero vault id, or invalid vault name.

- state-changes: No state changes; pure preview path.

- events: No events emitted.

- errors: Reverts on invalid vault metadata.

- reentrancy: Not applicable for view function.

- access: Public view helper.

- oracle: No oracle dependencies.


```solidity
function previewVaultToken(address vault, uint256 vaultId, string calldata vaultName)
    external
    view
    returns (address stQEUROToken_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|Vault contract address that will call `registerVault`.|
|`vaultId`|`uint256`|Target vault identifier.|
|`vaultName`|`string`|Uppercase alphanumeric vault label.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`stQEUROToken_`|`address`|Predicted stQEURO proxy address for this registration tuple.|


### getStQEUROByVaultId

Returns registered stQEURO token by vault id.

Reads factory mapping for vault-id-to-token resolution.

**Notes:**
- security: Read-only lookup with no privileged behavior.

- validation: No additional validation; returns zero for unknown ids.

- state-changes: No state changes.

- events: No events emitted.

- errors: No errors expected.

- reentrancy: Not applicable for view function.

- access: Public view.

- oracle: No oracle dependencies.


```solidity
function getStQEUROByVaultId(uint256 vaultId) external view returns (address stQEUROToken_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vaultId`|`uint256`|Vault identifier in factory registry.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`stQEUROToken_`|`address`|Registered stQEURO token address (or zero if unset).|


### getStQEUROByVault

Returns registered stQEURO token by vault address.

Reads factory mapping for vault-to-token resolution.

**Notes:**
- security: Read-only lookup with no privileged behavior.

- validation: No additional validation; returns zero for unknown vaults.

- state-changes: No state changes.

- events: No events emitted.

- errors: No errors expected.

- reentrancy: Not applicable for view function.

- access: Public view.

- oracle: No oracle dependencies.


```solidity
function getStQEUROByVault(address vault) external view returns (address stQEUROToken_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|Vault contract address.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`stQEUROToken_`|`address`|Registered stQEURO token address (or zero if unset).|


### getVaultById

Returns vault address bound to a vault id.

Reads registry mapping populated during registration.

**Notes:**
- security: Read-only lookup.

- validation: No additional validation; returns zero for unknown ids.

- state-changes: No state changes.

- events: No events emitted.

- errors: No errors expected.

- reentrancy: Not applicable for view function.

- access: Public view.

- oracle: No oracle dependencies.


```solidity
function getVaultById(uint256 vaultId) external view returns (address vault);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vaultId`|`uint256`|Vault identifier in factory registry.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|Vault address associated with the id (or zero if unset).|


### getVaultIdByStQEURO

Returns vault id bound to an stQEURO token.

Reads reverse registry mapping from token address to vault id.

**Notes:**
- security: Read-only lookup.

- validation: No additional validation; returns zero for unknown tokens.

- state-changes: No state changes.

- events: No events emitted.

- errors: No errors expected.

- reentrancy: Not applicable for view function.

- access: Public view.

- oracle: No oracle dependencies.


```solidity
function getVaultIdByStQEURO(address stQEUROToken_) external view returns (uint256 vaultId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`stQEUROToken_`|`address`|Registered stQEURO token address.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`vaultId`|`uint256`|Vault identifier associated with the token (or zero if unset).|


### getVaultName

Returns vault name string for a vault id.

Reads the stored canonical vault label registered at creation time.

**Notes:**
- security: Read-only lookup.

- validation: No additional validation; returns empty value for unknown ids.

- state-changes: No state changes.

- events: No events emitted.

- errors: No errors expected.

- reentrancy: Not applicable for view function.

- access: Public view.

- oracle: No oracle dependencies.


```solidity
function getVaultName(uint256 vaultId) external view returns (string memory vaultName);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vaultId`|`uint256`|Vault identifier in factory registry.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`vaultName`|`string`|Stored vault name (empty string if unset).|


### updateYieldShift

Updates YieldShift dependency for future token deployments.

Governance-only setter for the factory-level YieldShift address.

**Notes:**
- security: Restricted to governance role.

- validation: Reverts if `_yieldShift` is zero address.

- state-changes: Updates `yieldShift` configuration.

- events: Emits `FactoryConfigUpdated`.

- errors: Reverts with `InvalidToken` for zero address.

- reentrancy: No external calls beyond event emission.

- access: Restricted to `GOVERNANCE_ROLE`.

- oracle: No oracle dependencies.


```solidity
function updateYieldShift(address _yieldShift) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_yieldShift`|`address`|New YieldShift contract address.|


### updateTokenImplementation

Updates stQEURO implementation used for new proxies.

Governance-only setter for proxy implementation address.

**Notes:**
- security: Restricted to governance role.

- validation: Reverts if `_tokenImplementation` is zero address.

- state-changes: Updates `tokenImplementation` configuration.

- events: Emits `FactoryConfigUpdated`.

- errors: Reverts with `InvalidToken` for zero address.

- reentrancy: No external calls beyond event emission.

- access: Restricted to `GOVERNANCE_ROLE`.

- oracle: No oracle dependencies.


```solidity
function updateTokenImplementation(address _tokenImplementation) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenImplementation`|`address`|New implementation contract address.|


### updateOracle

Updates oracle dependency address for factory configuration.

Governance-only setter for oracle address used by future deployments.

**Notes:**
- security: Restricted to governance role.

- validation: Reverts if `_oracle` is zero address.

- state-changes: Updates `oracle` configuration.

- events: Emits `FactoryConfigUpdated`.

- errors: Reverts with `InvalidOracle` for zero address.

- reentrancy: No external calls beyond event emission.

- access: Restricted to `GOVERNANCE_ROLE`.

- oracle: Updates oracle reference; no live price reads.


```solidity
function updateOracle(address _oracle) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_oracle`|`address`|New oracle contract address.|


### updateTreasury

Updates treasury address propagated to new token deployments.

Governance-only setter for factory treasury configuration.

**Notes:**
- security: Restricted to governance role.

- validation: Reverts if `_treasury` is zero address.

- state-changes: Updates `treasury` configuration.

- events: Emits `FactoryConfigUpdated`.

- errors: Reverts with `InvalidTreasury` for zero address.

- reentrancy: No external calls beyond event emission.

- access: Restricted to `GOVERNANCE_ROLE`.

- oracle: No oracle dependencies.


```solidity
function updateTreasury(address _treasury) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_treasury`|`address`|New treasury address.|


### updateTokenAdmin

Updates token admin propagated to new token deployments.

Governance-only setter for default token admin address.

**Notes:**
- security: Restricted to governance role.

- validation: Reverts if `_tokenAdmin` is zero address.

- state-changes: Updates `tokenAdmin` configuration.

- events: Emits `FactoryConfigUpdated`.

- errors: Reverts with `InvalidAdmin` for zero address.

- reentrancy: No external calls beyond event emission.

- access: Restricted to `GOVERNANCE_ROLE`.

- oracle: No oracle dependencies.


```solidity
function updateTokenAdmin(address _tokenAdmin) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenAdmin`|`address`|New admin address for newly deployed stQEURO proxies.|


### _validateVaultName

Validates vault name format used by the registry.

Accepts only uppercase letters and digits with length in range 1..12.

**Notes:**
- security: Prevents malformed identifiers from entering registry state.

- validation: Reverts for empty, oversized, or non-alphanumeric-uppercase names.

- state-changes: No state changes.

- events: No events emitted.

- errors: Reverts with `InvalidParameter` on invalid name format.

- reentrancy: Not applicable for pure validation helper.

- access: Internal helper.

- oracle: No oracle dependencies.


```solidity
function _validateVaultName(string calldata vaultName) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vaultName`|`string`|Candidate vault label to validate.|


### _vaultSalt

Computes deterministic CREATE2 salt for vault registration.

Hashes vault identity tuple to ensure unique deterministic deployment address.

**Notes:**
- security: Deterministic salt prevents accidental collisions across registrations.

- validation: Expects validated inputs from caller functions.

- state-changes: No state changes.

- events: No events emitted.

- errors: No errors expected.

- reentrancy: Not applicable for pure helper.

- access: Internal helper.

- oracle: No oracle dependencies.


```solidity
function _vaultSalt(address vault, uint256 vaultId, string calldata vaultName)
    internal
    pure
    returns (bytes32 salt);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|Vault contract address.|
|`vaultId`|`uint256`|Vault identifier.|
|`vaultName`|`string`|Vault name string.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`salt`|`bytes32`|CREATE2 salt derived from vault tuple.|


### _buildInitData

Builds initializer calldata for stQEURO proxy deployment.

Encodes token metadata and dependency addresses for the stQEURO `initialize` call.

**Notes:**
- security: Uses factory-stored trusted dependency addresses.

- validation: Expects validated vault name input from caller.

- state-changes: No state changes.

- events: No events emitted.

- errors: No custom errors expected.

- reentrancy: Not applicable for view helper.

- access: Internal helper.

- oracle: Uses stored oracle address indirectly through configuration.


```solidity
function _buildInitData(string calldata vaultName) internal view returns (bytes memory initData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vaultName`|`string`|Vault name used to derive token display name and symbol.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`initData`|`bytes`|ABI-encoded initializer payload for proxy constructor.|


### _predictProxyAddress

Predicts CREATE2 proxy address for a vault registration.

Recreates ERC1967Proxy creation bytecode hash and computes deterministic deployment address.

**Notes:**
- security: Enables pre-commit address binding to mitigate registration race inconsistencies.

- validation: Expects valid creation inputs from caller.

- state-changes: No state changes.

- events: No events emitted.

- errors: No custom errors expected.

- reentrancy: Not applicable for view helper.

- access: Internal helper.

- oracle: No oracle dependencies.


```solidity
function _predictProxyAddress(bytes32 salt, bytes memory initData) internal view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`salt`|`bytes32`|CREATE2 salt for deployment.|
|`initData`|`bytes`|ABI-encoded initializer payload.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Predicted proxy address for the given deployment inputs.|


## Events
### VaultRegistered

```solidity
event VaultRegistered(
    uint256 indexed vaultId, address indexed vault, address indexed stQEUROToken, string vaultName
);
```

### FactoryConfigUpdated

```solidity
event FactoryConfigUpdated(string indexed key, address oldValue, address newValue);
```

