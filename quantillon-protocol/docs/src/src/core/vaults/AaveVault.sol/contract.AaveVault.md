# AaveVault
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/0e00532d7586178229ff1180b9b225e8c7a432fb/src/core/vaults/AaveVault.sol)

**Inherits:**
Initializable, ReentrancyGuardUpgradeable, AccessControlUpgradeable, PausableUpgradeable, [SecureUpgradeable](/src/core/SecureUpgradeable.sol/abstract.SecureUpgradeable.md)

**Author:**
Quantillon Labs

Aave integration vault for yield generation through USDC lending

*Main characteristics:
- USDC deposits into Aave lending protocol for yield generation
- Automatic yield harvesting and distribution
- Risk management with exposure limits and health monitoring
- Emergency withdrawal capabilities for crisis situations
- Dynamic allocation based on market conditions
- Upgradeable via UUPS pattern*

*Deposit mechanics:
- USDC supplied to Aave protocol for lending
- Receives aUSDC tokens representing interest-bearing deposits
- Principal tracking for yield calculation
- Maximum exposure limits for risk management
- Health checks before deposits*

*Yield harvesting:
- Automatic detection of accrued interest
- Threshold-based harvesting to optimize gas costs
- Protocol fees charged on harvested yield
- Net yield distributed to yield shift mechanism
- Real-time yield tracking and reporting*

*Risk management:
- Maximum Aave exposure limits (default 50M USDC)
- Utilization rate monitoring for liquidity risk
- Emergency mode for immediate withdrawals
- Health monitoring of Aave protocol status
- Slippage protection on withdrawals*

*Allocation strategy:
- Dynamic allocation based on Aave APY
- Rebalancing thresholds for optimal yield
- Market condition adjustments
- Liquidity availability considerations
- Expected yield calculations*

*Fee structure:
- Yield fees charged on harvested interest (default 10%)
- Protocol fees for sustainability
- Dynamic fee adjustment based on performance
- Fee collection and distribution tracking*

*Security features:
- Role-based access control for all critical operations
- Reentrancy protection for all external calls
- Emergency pause mechanism for crisis situations
- Upgradeable architecture for future improvements
- Secure withdrawal validation
- Health monitoring and circuit breakers*

*Integration points:
- Aave lending protocol for yield generation
- USDC for deposits and withdrawals
- aUSDC tokens for interest accrual tracking
- Yield shift mechanism for yield distribution
- Rewards controller for additional incentives*

**Note:**
security-contact: team@quantillon.money


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


### usdc

```solidity
IERC20 public usdc;
```


### aUSDC

```solidity
IERC20 public aUSDC;
```


### aavePool

```solidity
IPool public aavePool;
```


### aaveProvider

```solidity
IPoolAddressesProvider public aaveProvider;
```


### rewardsController

```solidity
IRewardsController public rewardsController;
```


### yieldShift

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
    address _yieldShift,
    address timelock
) public initializer;
```

### deployToAave


```solidity
function deployToAave(uint256 amount) external nonReentrant whenNotPaused returns (uint256 aTokensReceived);
```

### withdrawFromAave


```solidity
function withdrawFromAave(uint256 amount) external nonReentrant returns (uint256 usdcWithdrawn);
```

### claimAaveRewards


```solidity
function claimAaveRewards() external nonReentrant returns (uint256 rewardsClaimed);
```

### harvestAaveYield


```solidity
function harvestAaveYield() external nonReentrant returns (uint256 yieldHarvested);
```

### getAvailableYield


```solidity
function getAvailableYield() public view returns (uint256);
```

### getYieldDistribution


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
function autoRebalance() external returns (bool rebalanced, uint256 newAllocation);
```

### calculateOptimalAllocation


```solidity
function calculateOptimalAllocation() external view returns (uint256 optimalAllocation, uint256 expectedYield);
```

### setMaxAaveExposure


```solidity
function setMaxAaveExposure(uint256 _maxExposure) external;
```

### emergencyWithdrawFromAave


```solidity
function emergencyWithdrawFromAave() external returns (uint256 amountWithdrawn);
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
    external;
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
function toggleEmergencyMode(bool enabled, string calldata reason) external;
```

### pause


```solidity
function pause() external;
```

### unpause


```solidity
function unpause() external;
```

### recoverToken


```solidity
function recoverToken(address token, address to, uint256 amount) external;
```

### recoverETH


```solidity
function recoverETH(address payable to) external;
```

## Events
### DeployedToAave
*OPTIMIZED: Indexed operation type for efficient filtering*


```solidity
event DeployedToAave(string indexed operationType, uint256 amount, uint256 aTokensReceived, uint256 newBalance);
```

### WithdrawnFromAave

```solidity
event WithdrawnFromAave(
    string indexed operationType, uint256 amountRequested, uint256 amountWithdrawn, uint256 newBalance
);
```

### AaveYieldHarvested

```solidity
event AaveYieldHarvested(string indexed harvestType, uint256 yieldHarvested, uint256 protocolFee, uint256 netYield);
```

### AaveRewardsClaimed

```solidity
event AaveRewardsClaimed(address indexed rewardToken, uint256 rewardAmount, address recipient);
```

### PositionRebalanced
*OPTIMIZED: Indexed reason and parameter for efficient filtering*


```solidity
event PositionRebalanced(string indexed reason, uint256 oldAllocation, uint256 newAllocation);
```

### AaveParameterUpdated

```solidity
event AaveParameterUpdated(string indexed parameter, uint256 oldValue, uint256 newValue);
```

### EmergencyWithdrawal

```solidity
event EmergencyWithdrawal(string indexed reason, uint256 amountWithdrawn, uint256 timestamp);
```

### EmergencyModeToggled

```solidity
event EmergencyModeToggled(string indexed reason, bool enabled);
```

