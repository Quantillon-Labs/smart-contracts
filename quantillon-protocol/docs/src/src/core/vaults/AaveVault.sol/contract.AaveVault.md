# AaveVault
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/a0c4605b79826572de49aa1618715c7e4813adad/src/core/vaults/AaveVault.sol)

**Inherits:**
Initializable, ReentrancyGuardUpgradeable, AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable


## State Variables
### GOVERNANCE_ROLE

```solidity
bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
```


### VAULT_MANAGER_ROLE

```solidity
bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");
```


### EMERGENCY_ROLE

```solidity
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
```


### UPGRADER_ROLE

```solidity
bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
```


### usdc
USDC token contract


```solidity
IERC20 public usdc;
```


### aUSDC
aUSDC token contract (Aave interest-bearing USDC)


```solidity
IERC20 public aUSDC;
```


### aavePool
Aave V3 Pool contract


```solidity
IPool public aavePool;
```


### aaveProvider
Aave V3 Pool Addresses Provider


```solidity
IPoolAddressesProvider public aaveProvider;
```


### rewardsController
Aave Rewards Controller


```solidity
IRewardsController public rewardsController;
```


### yieldShift
Yield Shift mechanism


```solidity
IYieldShift public yieldShift;
```


### maxAaveExposure

```solidity
uint256 public maxAaveExposure;
```


### harvestThreshold

```solidity
uint256 public harvestThreshold;
```


### yieldFee

```solidity
uint256 public yieldFee;
```


### rebalanceThreshold

```solidity
uint256 public rebalanceThreshold;
```


### principalDeposited

```solidity
uint256 public principalDeposited;
```


### lastHarvestTime

```solidity
uint256 public lastHarvestTime;
```


### totalYieldHarvested

```solidity
uint256 public totalYieldHarvested;
```


### totalFeesCollected

```solidity
uint256 public totalFeesCollected;
```


### utilizationLimit

```solidity
uint256 public utilizationLimit;
```


### emergencyExitThreshold

```solidity
uint256 public emergencyExitThreshold;
```


### emergencyMode

```solidity
bool public emergencyMode;
```


### yieldHistory

```solidity
YieldSnapshot[] public yieldHistory;
```


### MAX_YIELD_HISTORY

```solidity
uint256 public constant MAX_YIELD_HISTORY = 365;
```


### MAX_TIME_ELAPSED

```solidity
uint256 public constant MAX_TIME_ELAPSED = 365 days;
```


## Functions
### constructor


```solidity
constructor();
```

### initialize


```solidity
function initialize(
    address admin,
    address _usdc,
    address _aaveProvider,
    address _rewardsController,
    address _yieldShift
) public initializer;
```

### deployToAave

Deploy USDC to Aave V3 pool to earn yield


```solidity
function deployToAave(uint256 amount)
    external
    onlyRole(VAULT_MANAGER_ROLE)
    nonReentrant
    whenNotPaused
    returns (uint256 aTokensReceived);
```

### withdrawFromAave

Withdraw USDC from Aave V3 pool

*Includes comprehensive validation and proper accounting of actual amounts received*


```solidity
function withdrawFromAave(uint256 amount)
    external
    onlyRole(VAULT_MANAGER_ROLE)
    nonReentrant
    returns (uint256 usdcWithdrawn);
```

### claimAaveRewards

Claim Aave rewards (if any)


```solidity
function claimAaveRewards() external onlyRole(VAULT_MANAGER_ROLE) nonReentrant returns (uint256 rewardsClaimed);
```

### harvestAaveYield

Harvest Aave yield and distribute to protocol

*Includes slippage protection for yield withdrawals*


```solidity
function harvestAaveYield() external onlyRole(VAULT_MANAGER_ROLE) nonReentrant returns (uint256 yieldHarvested);
```

### getAvailableYield

Calculate available yield for harvest


```solidity
function getAvailableYield() public view returns (uint256);
```

### getYieldDistribution

Get yield distribution breakdown


```solidity
function getYieldDistribution() external view returns (uint256 protocolYield, uint256 userYield, uint256 hedgerYield);
```

### getAaveBalance


```solidity
function getAaveBalance() external view returns (uint256);
```

### getAccruedInterest


```solidity
function getAccruedInterest() external view returns (uint256);
```

### getAaveAPY


```solidity
function getAaveAPY() external view returns (uint256);
```

### getAavePositionDetails


```solidity
function getAavePositionDetails()
    external
    view
    returns (uint256 principalDeposited_, uint256 currentBalance, uint256 aTokenBalance, uint256 lastUpdateTime);
```

### getAaveMarketData


```solidity
function getAaveMarketData()
    external
    view
    returns (uint256 supplyRate, uint256 utilizationRate, uint256 totalSupply, uint256 availableLiquidity);
```

### checkAaveHealth


```solidity
function checkAaveHealth() external view returns (bool isHealthy, bool pauseStatus, uint256 lastUpdate);
```

### _isAaveHealthy


```solidity
function _isAaveHealthy() internal view returns (bool);
```

### autoRebalance


```solidity
function autoRebalance() external onlyRole(VAULT_MANAGER_ROLE) returns (bool rebalanced, uint256 newAllocation);
```

### calculateOptimalAllocation


```solidity
function calculateOptimalAllocation() external view returns (uint256 optimalAllocation, uint256 expectedYield);
```

### setMaxAaveExposure


```solidity
function setMaxAaveExposure(uint256 _maxExposure) external onlyRole(GOVERNANCE_ROLE);
```

### emergencyWithdrawFromAave

Emergency withdrawal from Aave

*Includes proper accounting of actual amounts received during emergency*


```solidity
function emergencyWithdrawFromAave() external onlyRole(EMERGENCY_ROLE) returns (uint256 amountWithdrawn);
```

### getRiskMetrics


```solidity
function getRiskMetrics()
    external
    view
    returns (uint256 exposureRatio, uint256 concentrationRisk, uint256 liquidityRisk);
```

### updateAaveParameters


```solidity
function updateAaveParameters(uint256 newHarvestThreshold, uint256 newYieldFee, uint256 newRebalanceThreshold)
    external
    onlyRole(GOVERNANCE_ROLE);
```

### getAaveConfig


```solidity
function getAaveConfig()
    external
    view
    returns (address aavePool_, address aUSDC_, uint256 harvestThreshold_, uint256 yieldFee_, uint256 maxExposure_);
```

### toggleEmergencyMode


```solidity
function toggleEmergencyMode(bool enabled, string calldata reason) external onlyRole(EMERGENCY_ROLE);
```

### _recordYieldSnapshot


```solidity
function _recordYieldSnapshot() internal;
```

### getHistoricalYield


```solidity
function getHistoricalYield(uint256 period)
    external
    view
    returns (uint256 averageYield, uint256 maxYield, uint256 minYield, uint256 yieldVolatility);
```

### pause


```solidity
function pause() external onlyRole(EMERGENCY_ROLE);
```

### unpause


```solidity
function unpause() external onlyRole(EMERGENCY_ROLE);
```

### _authorizeUpgrade


```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE);
```

### recoverToken

Recover accidentally sent tokens


```solidity
function recoverToken(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE);
```

## Events
### DeployedToAave

```solidity
event DeployedToAave(uint256 amount, uint256 aTokensReceived, uint256 newBalance);
```

### WithdrawnFromAave

```solidity
event WithdrawnFromAave(uint256 amountRequested, uint256 amountWithdrawn, uint256 newBalance);
```

### AaveYieldHarvested

```solidity
event AaveYieldHarvested(uint256 yieldHarvested, uint256 protocolFee, uint256 netYield);
```

### AaveRewardsClaimed

```solidity
event AaveRewardsClaimed(address indexed rewardToken, uint256 rewardAmount, address recipient);
```

### PositionRebalanced

```solidity
event PositionRebalanced(uint256 oldAllocation, uint256 newAllocation, string reason);
```

### AaveParameterUpdated

```solidity
event AaveParameterUpdated(string parameter, uint256 oldValue, uint256 newValue);
```

### EmergencyWithdrawal

```solidity
event EmergencyWithdrawal(uint256 amountWithdrawn, string reason, uint256 timestamp);
```

### EmergencyModeToggled

```solidity
event EmergencyModeToggled(bool enabled, string reason);
```

## Structs
### YieldSnapshot

```solidity
struct YieldSnapshot {
    uint256 timestamp;
    uint256 aaveBalance;
    uint256 yieldEarned;
    uint256 aaveAPY;
}
```

