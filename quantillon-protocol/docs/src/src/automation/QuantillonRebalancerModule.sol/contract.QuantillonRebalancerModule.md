# QuantillonRebalancerModule
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/083874330beb67c980851f48832ef5faa68973d3/src/automation/QuantillonRebalancerModule.sol)

**Inherits:**
ReentrancyGuard

**Title:**
QuantillonRebalancerModule

A Safe-owned, non-upgradeable permission to add/remove margin on one position.

No arbitrary execution, transfers, delegatecalls, position entry/exit or bridging.
The operator pays gas; USDC always moves between the Safe and HedgerPool's vault.
Install only after independent review. Policy changes require a call from the Safe.

**Note:**
security-contact: team@quantillon.money


## Constants
### safe

```solidity
address public immutable safe
```


### hedgerPool

```solidity
IHedgerPool public immutable hedgerPool
```


### usdc

```solidity
IERC20 public immutable usdc
```


### vault

```solidity
IQuantillonVault public immutable vault
```


### positionId

```solidity
uint256 public immutable positionId
```


## State Variables
### operator

```solidity
address public operator
```


### paused

```solidity
bool public paused = true
```


### limits

```solidity
Limits public limits
```


### nonce

```solidity
uint256 public nonce
```


### lastExecution

```solidity
uint256 public lastExecution
```


### usageDay

```solidity
uint256 public usageDay
```


### currentDayUsage

```solidity
uint256 public currentDayUsage
```


### previousDayUsage

```solidity
uint256 public previousDayUsage
```


## Functions
### constructor


```solidity
constructor(address safe_, address pool_, uint256 positionId_, address operator_, Limits memory limits_) ;
```

### version

Reports this standalone module's release version.


```solidity
function version() external pure returns (string memory);
```

### configure

Changes the operator and policy; existing usage and cooldown are preserved.


```solidity
function configure(address operator_, Limits calldata limits_) external nonReentrant;
```

### setPaused

Lets the Safe pause or resume automation without blocking its owner transactions.


```solidity
function setPaused(bool paused_) external nonReentrant;
```

### addMargin

Adds margin using an exact, atomic Safe approval and preserves its reserve.

Deposits remain possible with an invalid oracle to allow collateral recovery.


```solidity
function addMargin(uint256 amount, uint256 expectedNonce, uint256 deadline) external nonReentrant;
```

### removeMargin

Removes margin to the Safe, then checks fresh position and protocol solvency atomically.


```solidity
function removeMargin(uint256 amount, uint256 expectedNonce, uint256 deadline) external nonReentrant;
```

### windowUsage

Conservative rolling-day usage: sum of the current and previous UTC day.

This bounds every rolling 24h period, but can retain usage for almost 48h.


```solidity
function windowUsage() public view returns (uint256);
```

### _configure


```solidity
function _configure(address operator_, Limits memory limits_) private;
```

### _authorize


```solidity
function _authorize(uint256 amount, uint256 expectedNonce, uint256 deadline) private;
```

### _checkWithdrawalFloors


```solidity
function _checkWithdrawalFloors() private;
```

### _approve


```solidity
function _approve(uint256 amount) private;
```

### _execute


```solidity
function _execute(address target, bytes memory data) private returns (bytes memory result);
```

## Events
### Configured

```solidity
event Configured(address indexed operator, Limits limits);
```

### PauseChanged

```solidity
event PauseChanged(bool paused);
```

### MarginRebalanced

```solidity
event MarginRebalanced(uint256 indexed nonce, uint256 indexed positionId, bool increase, uint256 amount);
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

### ModulePaused

```solidity
error ModulePaused();
```

### InvalidRequest

```solidity
error InvalidRequest();
```

### WrongPositionOwner

```solidity
error WrongPositionOwner();
```

### DependenciesChanged

```solidity
error DependenciesChanged();
```

### LimitExceeded

```solidity
error LimitExceeded();
```

### CooldownActive

```solidity
error CooldownActive();
```

### InvalidOracle

```solidity
error InvalidOracle();
```

### PositionFloorBreached

```solidity
error PositionFloorBreached();
```

### VaultFloorBreached

```solidity
error VaultFloorBreached();
```

### SafeReserveBreached

```solidity
error SafeReserveBreached();
```

### SafeExecutionFailed

```solidity
error SafeExecutionFailed();
```

### TokenOperationFailed

```solidity
error TokenOperationFailed();
```

### UnexpectedBalanceChange

```solidity
error UnexpectedBalanceChange();
```

## Structs
### Limits

```solidity
struct Limits {
    uint256 maxActionUsdc;
    uint256 maxWindowUsdc;
    uint256 cooldownSeconds;
    uint256 minSafeReserveUsdc;
    uint256 minMarginBps;
    uint256 marginBufferBps;
    uint256 vaultCrBufferBps;
}
```
