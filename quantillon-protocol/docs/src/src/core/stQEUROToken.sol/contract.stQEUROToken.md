# stQEUROToken
**Inherits:**
Initializable, ERC4626Upgradeable, AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, [SecureUpgradeable](/src/core/SecureUpgradeable.sol/abstract.SecureUpgradeable.md)

**Title:**
stQEUROToken

ERC-4626 vault over QEURO used for per-vault staking series.


## State Variables
### GOVERNANCE_ROLE

```solidity
bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE")
```


### EMERGENCY_ROLE

```solidity
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE")
```


### qeuro

```solidity
IQEUROToken public qeuro
```


### treasury

```solidity
address public treasury
```


### vaultName

```solidity
string public vaultName
```


### yieldFee

```solidity
uint256 public yieldFee
```


### TIME_PROVIDER

```solidity
TimeProvider public immutable TIME_PROVIDER
```


## Functions
### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor(TimeProvider _TIME_PROVIDER) ;
```

### initialize


```solidity
function initialize(address admin, address _qeuro, address, address, address _treasury, address _timelock)
    public
    initializer;
```

### initialize


```solidity
function initialize(address admin, address _qeuro, address _treasury, address _timelock, string calldata _vaultName)
    public
    initializer;
```

### _initializeStQEURODependencies


```solidity
function _initializeStQEURODependencies(
    address admin,
    address qeuroAddress,
    address treasuryAddress,
    address timelockAddress
) internal;
```

### maxDeposit


```solidity
function maxDeposit(address receiver) public view override returns (uint256);
```

### maxMint


```solidity
function maxMint(address receiver) public view override returns (uint256);
```

### maxWithdraw


```solidity
function maxWithdraw(address owner) public view override returns (uint256);
```

### maxRedeem


```solidity
function maxRedeem(address owner) public view override returns (uint256);
```

### deposit


```solidity
function deposit(uint256 assets, address receiver)
    public
    override
    nonReentrant
    whenNotPaused
    returns (uint256 shares);
```

### mint


```solidity
function mint(uint256 shares, address receiver)
    public
    override
    nonReentrant
    whenNotPaused
    returns (uint256 assets);
```

### withdraw


```solidity
function withdraw(uint256 assets, address receiver, address owner)
    public
    override
    nonReentrant
    whenNotPaused
    returns (uint256 shares);
```

### redeem


```solidity
function redeem(uint256 shares, address receiver, address owner)
    public
    override
    nonReentrant
    whenNotPaused
    returns (uint256 assets);
```

### transfer


```solidity
function transfer(address to, uint256 value)
    public
    override(ERC20Upgradeable, IERC20)
    whenNotPaused
    returns (bool);
```

### transferFrom


```solidity
function transferFrom(address from, address to, uint256 value)
    public
    override(ERC20Upgradeable, IERC20)
    whenNotPaused
    returns (bool);
```

### updateYieldParameters


```solidity
function updateYieldParameters(uint256 _yieldFee) external onlyRole(GOVERNANCE_ROLE);
```

### updateTreasury


```solidity
function updateTreasury(address _treasury) external onlyRole(GOVERNANCE_ROLE);
```

### pause


```solidity
function pause() external onlyRole(EMERGENCY_ROLE);
```

### unpause


```solidity
function unpause() external onlyRole(EMERGENCY_ROLE);
```

### emergencyWithdraw


```solidity
function emergencyWithdraw(address user) external onlyRole(EMERGENCY_ROLE) nonReentrant;
```

### recoverToken


```solidity
function recoverToken(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE);
```

### recoverETH


```solidity
function recoverETH() external onlyRole(DEFAULT_ADMIN_ROLE);
```

## Events
### YieldParametersUpdated

```solidity
event YieldParametersUpdated(uint256 yieldFee);
```

### TreasuryUpdated

```solidity
event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury, address indexed caller);
```

### ETHRecovered

```solidity
event ETHRecovered(address indexed to, uint256 indexed amount);
```

