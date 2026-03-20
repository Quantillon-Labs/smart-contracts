# MorphoStakingVaultAdapter
**Inherits:**
AccessControl, ReentrancyGuard, [IExternalStakingVault](/src/interfaces/IExternalStakingVault.sol/interface.IExternalStakingVault.md)

**Title:**
MorphoStakingVaultAdapter

Generic external vault adapter for Morpho-like third-party vaults.


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


### morphoVault

```solidity
IMockMorphoVault public morphoVault
```


### yieldShift

```solidity
IYieldShift public yieldShift
```


### yieldVaultId

```solidity
uint256 public yieldVaultId
```


### principalDeposited

```solidity
uint256 public principalDeposited
```


## Functions
### constructor


```solidity
constructor(address admin, address usdc_, address morphoVault_, address yieldShift_, uint256 yieldVaultId_) ;
```

### depositUnderlying


```solidity
function depositUnderlying(uint256 usdcAmount)
    external
    override
    onlyRole(VAULT_MANAGER_ROLE)
    nonReentrant
    returns (uint256 sharesReceived);
```

### withdrawUnderlying


```solidity
function withdrawUnderlying(uint256 usdcAmount)
    external
    override
    onlyRole(VAULT_MANAGER_ROLE)
    nonReentrant
    returns (uint256 usdcWithdrawn);
```

### harvestYield


```solidity
function harvestYield()
    external
    override
    onlyRole(VAULT_MANAGER_ROLE)
    nonReentrant
    returns (uint256 harvestedYield);
```

### totalUnderlying


```solidity
function totalUnderlying() external view override returns (uint256 underlyingBalance);
```

### setMorphoVault


```solidity
function setMorphoVault(address newMorphoVault) external onlyRole(GOVERNANCE_ROLE);
```

### setYieldShift


```solidity
function setYieldShift(address newYieldShift) external onlyRole(GOVERNANCE_ROLE);
```

### setYieldVaultId


```solidity
function setYieldVaultId(uint256 newYieldVaultId) external onlyRole(GOVERNANCE_ROLE);
```

## Events
### MorphoVaultUpdated

```solidity
event MorphoVaultUpdated(address indexed oldVault, address indexed newVault);
```

### YieldShiftUpdated

```solidity
event YieldShiftUpdated(address indexed oldYieldShift, address indexed newYieldShift);
```

### YieldVaultIdUpdated

```solidity
event YieldVaultIdUpdated(uint256 indexed oldVaultId, uint256 indexed newVaultId);
```

