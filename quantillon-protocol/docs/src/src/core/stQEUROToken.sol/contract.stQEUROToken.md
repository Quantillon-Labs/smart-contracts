# stQEUROToken
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/46b18a17495388ad54b171836fd31a58ac76ca7b/src/core/stQEUROToken.sol)

**Inherits:**
Initializable, ERC20Upgradeable, AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, [SecureUpgradeable](/src/core/SecureUpgradeable.sol/abstract.SecureUpgradeable.md)

**Author:**
Quantillon Labs

Yield-bearing wrapper for QEURO tokens (yield accrual mechanism)

*Main characteristics:
- Yield-bearing wrapper token for QEURO
- Exchange rate increases over time as yield accrues
- Similar to stETH (Lido's staked ETH token)
- Automatic yield distribution to all stQEURO holders
- Fee structure for protocol sustainability
- Emergency pause mechanism for crisis situations
- Upgradeable via UUPS pattern*

*Staking mechanics:
- Users stake QEURO to receive stQEURO
- Exchange rate starts at 1:1 and increases over time
- Yield is distributed proportionally to all stQEURO holders
- Users can unstake at any time to receive QEURO + accrued yield
- No lock-up period or cooldown requirements*

*Yield distribution:
- Yield is distributed from protocol fees and yield shift mechanisms
- Exchange rate increases as yield accrues
- All stQEURO holders benefit from yield automatically
- Yield fees charged for protocol sustainability
- Real-time yield tracking and distribution*

*Exchange rate mechanism:
- Exchange rate = (totalUnderlying + totalYieldEarned) / totalSupply
- Increases over time as yield is earned
- Updated periodically or when yield is distributed
- Minimum yield threshold prevents frequent updates
- Maximum update frequency prevents excessive gas costs*

*Fee structure:
- Yield fees on distributed yield
- Treasury receives fees for protocol sustainability
- Dynamic fee adjustment based on market conditions
- Transparent fee structure for users*

*Security features:
- Role-based access control for all critical operations
- Reentrancy protection for all external calls
- Emergency pause mechanism for crisis situations
- Upgradeable architecture for future improvements
- Secure yield distribution mechanisms
- Exchange rate validation*

*Integration points:
- QEURO token for staking and unstaking
- USDC for yield payments
- Yield shift mechanism for yield management
- Treasury for fee collection
- Vault math library for calculations*

**Note:**
security-contact: team@quantillon.money


## State Variables
### GOVERNANCE_ROLE
Role for governance operations (parameter updates, emergency actions)

*keccak256 hash avoids role collisions with other contracts*

*Should be assigned to governance multisig or DAO*


```solidity
bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
```


### YIELD_MANAGER_ROLE
Role for yield management operations (distribution, updates)

*keccak256 hash avoids role collisions with other contracts*

*Should be assigned to yield management system or governance*


```solidity
bytes32 public constant YIELD_MANAGER_ROLE = keccak256("YIELD_MANAGER_ROLE");
```


### EMERGENCY_ROLE
Role for emergency operations (pause, emergency actions)

*keccak256 hash avoids role collisions with other contracts*

*Should be assigned to emergency multisig*


```solidity
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
```


### qeuro
Role for performing contract upgrades via UUPS pattern

QEURO token contract for staking and unstaking

*Used for all QEURO staking and unstaking operations*

*Should be the official QEURO token contract*


```solidity
IQEUROToken public qeuro;
```


### yieldShift
YieldShift contract for yield distribution

*Handles yield distribution and management*

*Used for yield calculations and distributions*


```solidity
IYieldShift public yieldShift;
```


### usdc
USDC token for yield payments

*Used for yield distributions to stQEURO holders*

*Should be the official USDC contract on the target network*


```solidity
IERC20 public usdc;
```


### treasury
Treasury address for fee collection

*Receives yield fees for protocol sustainability*

*Should be a secure multisig or DAO treasury*


```solidity
address public treasury;
```


### timeProvider
TimeProvider contract for centralized time management

*Used to replace direct block.timestamp usage for testability and consistency*


```solidity
TimeProvider public immutable timeProvider;
```


### exchangeRate
Exchange rate between QEURO and stQEURO (18 decimals)

*Increases over time as yield accrues (like stETH)*

*Formula: (totalUnderlying + totalYieldEarned) / totalSupply*


```solidity
uint256 public exchangeRate;
```


### lastUpdateTime
Timestamp of last exchange rate update

*Used to track when exchange rate was last updated*

*Used for yield calculation intervals*


```solidity
uint256 public lastUpdateTime;
```


### totalUnderlying
Total QEURO underlying the stQEURO supply

*Sum of all QEURO staked by users*

*Used for exchange rate calculations*


```solidity
uint256 public totalUnderlying;
```


### totalYieldEarned
Total yield earned by stQEURO holders

*Sum of all yield distributed to stQEURO holders*

*Used for exchange rate calculations and analytics*


```solidity
uint256 public totalYieldEarned;
```


### yieldFee
Fee charged on yield distributions (in basis points)

*Example: 200 = 2% yield fee*

*Revenue source for the protocol*


```solidity
uint256 public yieldFee;
```


### minYieldThreshold
Minimum yield amount to trigger exchange rate update

*Prevents frequent updates for small yield amounts*

*Reduces gas costs and improves efficiency*


```solidity
uint256 public minYieldThreshold;
```


### maxUpdateFrequency
Maximum time between exchange rate updates (in seconds)

*Ensures regular updates even with low yield*

*Example: 1 day = 86400 seconds*


```solidity
uint256 public maxUpdateFrequency;
```


### VIRTUAL_SHARES
Virtual shares to prevent exchange rate manipulation

*Prevents donation attacks by maintaining minimum share value*


```solidity
uint256 private constant VIRTUAL_SHARES = 1e8;
```


### VIRTUAL_ASSETS
Virtual assets to prevent exchange rate manipulation

*Prevents donation attacks by maintaining minimum asset value*


```solidity
uint256 private constant VIRTUAL_ASSETS = 1e8;
```


### MAX_BATCH_SIZE
Maximum batch size for staking operations to prevent DoS

*Prevents out-of-gas attacks through large arrays*


```solidity
uint256 public constant MAX_BATCH_SIZE = 100;
```


## Functions
### flashLoanProtection

Modifier to protect against flash loan attacks

*Checks that the contract's total underlying QEURO doesn't decrease during execution*

*This prevents flash loans that would drain QEURO from the contract*


```solidity
modifier flashLoanProtection();
```

### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor(TimeProvider _timeProvider);
```

### initialize


```solidity
function initialize(
    address admin,
    address _qeuro,
    address _yieldShift,
    address _usdc,
    address _treasury,
    address _timelock
) public initializer;
```

### stake

Stake QEURO to receive stQEURO


```solidity
function stake(uint256 qeuroAmount)
    external
    nonReentrant
    whenNotPaused
    flashLoanProtection
    returns (uint256 stQEUROAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount of QEURO to stake|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`stQEUROAmount`|`uint256`|Amount of stQEURO received|


### unstake

Unstake QEURO by burning stQEURO


```solidity
function unstake(uint256 stQEUROAmount) external nonReentrant whenNotPaused returns (uint256 qeuroAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`stQEUROAmount`|`uint256`|Amount of stQEURO to burn|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount of QEURO received|


### batchStake

Batch stake QEURO to receive stQEURO for multiple amounts


```solidity
function batchStake(uint256[] calldata qeuroAmounts)
    external
    nonReentrant
    whenNotPaused
    returns (uint256[] memory stQEUROAmounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmounts`|`uint256[]`|Array of QEURO amounts to stake|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`stQEUROAmounts`|`uint256[]`|Array of stQEURO amounts received|


### batchUnstake

Batch unstake QEURO by burning stQEURO for multiple amounts


```solidity
function batchUnstake(uint256[] calldata stQEUROAmounts)
    external
    nonReentrant
    whenNotPaused
    returns (uint256[] memory qeuroAmounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`stQEUROAmounts`|`uint256[]`|Array of stQEURO amounts to burn|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmounts`|`uint256[]`|Array of QEURO amounts received|


### batchTransfer

Batch transfer stQEURO tokens to multiple addresses


```solidity
function batchTransfer(address[] calldata recipients, uint256[] calldata amounts)
    external
    whenNotPaused
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipients`|`address[]`|Array of recipient addresses|
|`amounts`|`uint256[]`|Array of amounts to transfer|


### distributeYield

Distribute yield to stQEURO holders (increases exchange rate)


```solidity
function distributeYield(uint256 yieldAmount) external onlyRole(YIELD_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`yieldAmount`|`uint256`|Amount of yield in USDC|


### claimYield

Claim accumulated yield for a user (in USDC)


```solidity
function claimYield() public returns (uint256 yieldAmount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`yieldAmount`|`uint256`|Amount of yield claimed|


### getPendingYield

Get pending yield for a user (in USDC)


```solidity
function getPendingYield(address user) public view returns (uint256 yieldAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`yieldAmount`|`uint256`|Pending yield amount|


### getExchangeRate

Get current exchange rate between QEURO and stQEURO


```solidity
function getExchangeRate() external view returns (uint256);
```

### getTVL

Get total value locked in stQEURO


```solidity
function getTVL() external view returns (uint256);
```

### getQEUROEquivalent

Get user's QEURO equivalent balance


```solidity
function getQEUROEquivalent(address user) external view returns (uint256 qeuroEquivalent);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`qeuroEquivalent`|`uint256`|QEURO equivalent of stQEURO balance|


### getStakingStats

Get staking statistics


```solidity
function getStakingStats()
    external
    view
    returns (
        uint256 totalStQEUROSupply,
        uint256 totalQEUROUnderlying,
        uint256 currentExchangeRate,
        uint256 totalYieldEarned_,
        uint256 apy
    );
```

### _updateExchangeRate

Update exchange rate based on time elapsed


```solidity
function _updateExchangeRate() internal;
```

### _calculateCurrentExchangeRate

Calculate current exchange rate including accrued yield


```solidity
function _calculateCurrentExchangeRate() internal view returns (uint256);
```

### updateYieldParameters

Update yield parameters


```solidity
function updateYieldParameters(uint256 _yieldFee, uint256 _minYieldThreshold, uint256 _maxUpdateFrequency)
    external
    onlyRole(GOVERNANCE_ROLE);
```

### updateTreasury

Update treasury address


```solidity
function updateTreasury(address _treasury) external onlyRole(GOVERNANCE_ROLE);
```

### decimals

Returns the number of decimals used by the token

*Always returns 18 to match QEURO token standard*


```solidity
function decimals() public pure override returns (uint8);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|The number of decimals (18)|


### pause

Pauses all token transfers and minting/burning operations

*Can only be called by addresses with EMERGENCY_ROLE during emergencies*


```solidity
function pause() external onlyRole(EMERGENCY_ROLE);
```

### unpause

Unpauses all token transfers and minting/burning operations

*Can only be called by addresses with EMERGENCY_ROLE to resume normal operations*


```solidity
function unpause() external onlyRole(EMERGENCY_ROLE);
```

### emergencyWithdraw

Emergency withdrawal of QEURO (only in emergency)


```solidity
function emergencyWithdraw(address user) external onlyRole(EMERGENCY_ROLE);
```

### recoverToken

Recover accidentally sent tokens to treasury only


```solidity
function recoverToken(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE);
```

### recoverETH

Recover ETH to treasury address only

*SECURITY: Restricted to treasury to prevent arbitrary ETH transfers*


```solidity
function recoverETH() external onlyRole(DEFAULT_ADMIN_ROLE);
```

### getVirtualProtectionStatus

Returns the current virtual protection status

*Useful for monitoring and debugging virtual protection*


```solidity
function getVirtualProtectionStatus()
    external
    view
    returns (uint256 virtualShares, uint256 virtualAssets, uint256 effectiveSupply, uint256 effectiveAssets);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`virtualShares`|`uint256`|Current virtual shares amount|
|`virtualAssets`|`uint256`|Current virtual assets amount|
|`effectiveSupply`|`uint256`|Effective supply including virtual shares|
|`effectiveAssets`|`uint256`|Effective assets including virtual assets|


## Events
### QEUROStaked
Emitted when QEURO is staked to receive stQEURO

*Indexed parameters allow efficient filtering of events*


```solidity
event QEUROStaked(address indexed user, uint256 qeuroAmount, uint256 stQEUROAmount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user who staked|
|`qeuroAmount`|`uint256`|Amount of QEURO staked (18 decimals)|
|`stQEUROAmount`|`uint256`|Amount of stQEURO received (18 decimals)|

### QEUROUnstaked
Emitted when stQEURO is unstaked to receive QEURO

*Indexed parameters allow efficient filtering of events*


```solidity
event QEUROUnstaked(address indexed user, uint256 stQEUROAmount, uint256 qeuroAmount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user who unstaked|
|`stQEUROAmount`|`uint256`|Amount of stQEURO burned (18 decimals)|
|`qeuroAmount`|`uint256`|Amount of QEURO received (18 decimals)|

### ExchangeRateUpdated
Emitted when exchange rate is updated

*Used to track exchange rate changes over time*


```solidity
event ExchangeRateUpdated(uint256 oldRate, uint256 newRate, uint256 timestamp);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldRate`|`uint256`|Previous exchange rate (18 decimals)|
|`newRate`|`uint256`|New exchange rate (18 decimals)|
|`timestamp`|`uint256`|Timestamp of the update|

### YieldDistributed
Emitted when yield is distributed to stQEURO holders

*Used to track yield distributions and their impact*

*OPTIMIZED: Indexed exchange rate for efficient filtering*


```solidity
event YieldDistributed(uint256 yieldAmount, uint256 indexed newExchangeRate);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`yieldAmount`|`uint256`|Amount of yield distributed (18 decimals)|
|`newExchangeRate`|`uint256`|New exchange rate after distribution (18 decimals)|

### YieldClaimed
Emitted when a user claims yield

*Indexed parameters allow efficient filtering of events*


```solidity
event YieldClaimed(address indexed user, uint256 yieldAmount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user who claimed yield|
|`yieldAmount`|`uint256`|Amount of yield claimed (18 decimals)|

### YieldParametersUpdated
Emitted when yield parameters are updated

*Used to track parameter changes by governance*

*OPTIMIZED: Indexed parameter type for efficient filtering*


```solidity
event YieldParametersUpdated(
    string indexed parameterType, uint256 yieldFee, uint256 minYieldThreshold, uint256 maxUpdateFrequency
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`parameterType`|`string`||
|`yieldFee`|`uint256`|New yield fee in basis points|
|`minYieldThreshold`|`uint256`|New minimum yield threshold|
|`maxUpdateFrequency`|`uint256`|New maximum update frequency|

### ETHRecovered
Emitted when ETH is recovered to the treasury


```solidity
event ETHRecovered(address indexed to, uint256 indexed amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Address to which ETH was recovered|
|`amount`|`uint256`|Amount of ETH recovered|

