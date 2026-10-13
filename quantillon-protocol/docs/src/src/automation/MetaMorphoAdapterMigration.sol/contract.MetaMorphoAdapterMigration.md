# MetaMorphoAdapterMigration
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/083874330beb67c980851f48832ef5faa68973d3/src/automation/MetaMorphoAdapterMigration.sol)

**Inherits:**
[IVersioned](/src/interfaces/IVersioned.sol/interface.IVersioned.md), ReentrancyGuard

**Title:**
MetaMorphoAdapterMigration

Moves one configured adapter's principal and uncredited yield atomically.

Grant temporary manager roles on both adapters and governance on the paused vault,
then revoke them in the same Safe transaction. No user tokens are minted or burned.


## Constants
### safe

```solidity
address public immutable safe
```


### vault

```solidity
IMigrationVault public immutable vault
```


### oldAdapter

```solidity
IMigrationAdapter public immutable oldAdapter
```


### newAdapter

```solidity
IMigrationAdapter public immutable newAdapter
```


### usdc

```solidity
IERC20 public immutable usdc
```


### vaultId

```solidity
uint256 public immutable vaultId
```


## State Variables
### completed

```solidity
bool public completed
```


## Functions
### constructor

Binds this one-use operation to a Safe, vault and adapter pair.


```solidity
constructor(address safe_, address vault_, uint256 id_, address old_, address next_) ;
```

### version

Identifies the immutable migration implementation.


```solidity
function version() external pure override returns (string memory);
```

### migrate

Migrates current balances without embedding an amount that can become stale.

Leaves yield uncredited as idle USDC at the replacement adapter. A legacy adapter
can retain fractional shares worth zero USDC base units; no valued assets may remain.
Any failure rolls back the withdrawals, deposits, registry change and completion flag.


```solidity
function migrate() external nonReentrant;
```

## Events
### Migrated

```solidity
event Migrated(
    uint256 indexed vaultId,
    address indexed oldAdapter,
    address indexed newAdapter,
    uint256 principal,
    uint256 uncreditedYield
);
```

## Errors
### Unauthorized

```solidity
error Unauthorized();
```

### InvalidConfiguration

```solidity
error InvalidConfiguration();
```

### InvalidState

```solidity
error InvalidState();
```

### BalanceMismatch

```solidity
error BalanceMismatch();
```
