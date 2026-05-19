# MetaMorphoStakingVaultAdapter
**Inherits:**
AccessControl, ReentrancyGuard, [IExternalStakingVault](/src/interfaces/IExternalStakingVault.sol/interface.IExternalStakingVault.md)

**Title:**
MetaMorphoStakingVaultAdapter

Adapter for MetaMorpho ERC-4626 vaults such as 0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2.


## State Variables
### GOVERNANCE_ROLE

```solidity
bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE")
```


### VAULT_MANAGER_ROLE

```solidity
bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE")
```


### USDC

```solidity
IERC20 public immutable USDC
```


### metaMorphoVault

```solidity
IERC4626 public metaMorphoVault
```


### yieldShift

```solidity
IYieldShift public yieldShift
```


### yieldVaultId

```solidity
uint256 public yieldVaultId
```


### yieldSource

```solidity
bytes32 public yieldSource
```


### principalDeposited

```solidity
uint256 public principalDeposited
```


## Functions
### constructor


```solidity
constructor(
    address admin,
    address usdc_,
    address metaMorphoVault_,
    address yieldShift_,
    uint256 yieldVaultId_,
    bytes32 yieldSource_
) ;
```

### depositUnderlying

Deposits USDC into the MetaMorpho ERC-4626 vault and tracks principal.


```solidity
function depositUnderlying(uint256 usdcAmount)
    external
    override
    onlyRole(VAULT_MANAGER_ROLE)
    nonReentrant
    returns (uint256 sharesReceived);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC to deposit.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`sharesReceived`|`uint256`|MetaMorpho shares minted to this adapter.|


### withdrawUnderlying

Withdraws tracked principal from MetaMorpho and returns USDC to the caller.


```solidity
function withdrawUnderlying(uint256 usdcAmount)
    external
    override
    onlyRole(VAULT_MANAGER_ROLE)
    nonReentrant
    returns (uint256 usdcWithdrawn);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Requested USDC amount.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`usdcWithdrawn`|`uint256`|Actual USDC amount withdrawn.|


### harvestYield

Harvests accrued ERC-4626 share yield and routes it to YieldShift.


```solidity
function harvestYield()
    external
    override
    onlyRole(VAULT_MANAGER_ROLE)
    nonReentrant
    returns (uint256 harvestedYield);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`harvestedYield`|`uint256`|Yield harvested in USDC.|


### totalUnderlying

Returns the USDC value of this adapter's MetaMorpho shares.


```solidity
function totalUnderlying() external view override returns (uint256 underlyingBalance);
```

### setMetaMorphoVault


```solidity
function setMetaMorphoVault(address newMetaMorphoVault) external onlyRole(GOVERNANCE_ROLE);
```

### setYieldShift


```solidity
function setYieldShift(address newYieldShift) external onlyRole(GOVERNANCE_ROLE);
```

### setYieldVaultId


```solidity
function setYieldVaultId(uint256 newYieldVaultId) external onlyRole(GOVERNANCE_ROLE);
```

### setYieldSource


```solidity
function setYieldSource(bytes32 newYieldSource) external onlyRole(GOVERNANCE_ROLE);
```

### _totalUnderlying


```solidity
function _totalUnderlying() internal view returns (uint256);
```

## Events
### MetaMorphoVaultUpdated

```solidity
event MetaMorphoVaultUpdated(address indexed oldVault, address indexed newVault);
```

### YieldShiftUpdated

```solidity
event YieldShiftUpdated(address indexed oldYieldShift, address indexed newYieldShift);
```

### YieldVaultIdUpdated

```solidity
event YieldVaultIdUpdated(uint256 indexed oldVaultId, uint256 indexed newVaultId);
```

### YieldSourceUpdated

```solidity
event YieldSourceUpdated(bytes32 indexed oldSource, bytes32 indexed newSource);
```

