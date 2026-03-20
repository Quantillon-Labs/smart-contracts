# MockMorphoVault
**Title:**
MockMorphoVault

Localhost-only mock that emulates a third-party Morpho-like USDC vault.

Tracks principal-like balances by account and supports synthetic yield injection.


## State Variables
### USDC

```solidity
IERC20 public immutable USDC
```


### shareBalanceOf

```solidity
mapping(address => uint256) public shareBalanceOf
```


### totalShares

```solidity
uint256 public totalShares
```


## Functions
### constructor


```solidity
constructor(address usdc_) ;
```

### depositUnderlying


```solidity
function depositUnderlying(uint256 assets, address onBehalfOf) external returns (uint256 shares);
```

### withdrawUnderlying


```solidity
function withdrawUnderlying(uint256 assets, address to) external returns (uint256 withdrawn);
```

### injectYield


```solidity
function injectYield(uint256 amount) external;
```

### totalAssets


```solidity
function totalAssets() public view returns (uint256);
```

### totalUnderlyingOf


```solidity
function totalUnderlyingOf(address account) external view returns (uint256);
```

## Events
### Deposited

```solidity
event Deposited(address indexed caller, address indexed onBehalfOf, uint256 assets);
```

### Withdrawn

```solidity
event Withdrawn(address indexed caller, address indexed to, uint256 assets);
```

### YieldInjected

```solidity
event YieldInjected(address indexed from, uint256 amount);
```

