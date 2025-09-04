# AaveVault
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/8586bf0c799c78a35c463b66cf8c6beb85e48666/src/core/vaults/AaveVault.sol)

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


### treasury

```solidity
address public treasury;
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
    address _timelock,
    address _treasury
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

### _validateAndCalculateWithdrawAmount

*Validates and calculates the actual withdrawal amount*


```solidity
function _validateAndCalculateWithdrawAmount(uint256 amount, uint256 aaveBalance)
    internal
    pure
    returns (uint256 withdrawAmount);
```

### _validateWithdrawalConstraints

*Validates withdrawal constraints (emergency mode, minimum balance)*


```solidity
function _validateWithdrawalConstraints(uint256 withdrawAmount, uint256 aaveBalance) internal view;
```

### _validateExpectedWithdrawal

*Validates expected withdrawal amounts before external call*


```solidity
function _validateExpectedWithdrawal(uint256 withdrawAmount) internal view;
```

### _executeAaveWithdrawal

*Executes the Aave withdrawal with proper error handling*


```solidity
function _executeAaveWithdrawal(uint256 originalAmount, uint256 withdrawAmount, uint256 usdcBefore)
    internal
    returns (uint256 usdcWithdrawn);
```

### _validateWithdrawalResult

*Validates the withdrawal result and slippage*


```solidity
function _validateWithdrawalResult(
    uint256 originalAmount,
    uint256 withdrawAmount,
    uint256 usdcBefore,
    uint256 usdcWithdrawn
) internal view;
```

### _updatePrincipalAfterWithdrawal

*Updates principal deposited after successful withdrawal*


```solidity
function _updatePrincipalAfterWithdrawal(uint256 actualReceived) internal;
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

Returns the total available yield from Aave lending

*Calculates yield based on current aToken balance vs principal deposited*


```solidity
function getAvailableYield() public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of yield available for distribution|


### getYieldDistribution

Returns the breakdown of yield distribution between users and protocol

*Shows how yield is allocated according to current distribution parameters*


```solidity
function getYieldDistribution() external view returns (uint256 protocolYield, uint256 userYield, uint256 hedgerYield);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`protocolYield`|`uint256`|Amount of yield allocated to protocol fees|
|`userYield`|`uint256`|Amount of yield allocated to users|
|`hedgerYield`|`uint256`|Amount of yield allocated to hedgers|


### getAaveBalance

Returns the current balance of aTokens held by this vault

*Represents the total amount deposited in Aave plus accrued interest*


```solidity
function getAaveBalance() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current aToken balance|


### getAccruedInterest

Returns the total interest accrued from Aave lending

*Calculates interest as current balance minus principal deposited*


```solidity
function getAccruedInterest() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of interest accrued|


### getAaveAPY

Returns the current APY offered by Aave for the deposited asset

*Fetches the supply rate from Aave's reserve data*


```solidity
function getAaveAPY() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current APY in basis points|


### getAavePositionDetails

Returns detailed information about the Aave position

*Provides comprehensive data about the vault's Aave lending position*


```solidity
function getAavePositionDetails()
    external
    view
    returns (uint256 principalDeposited_, uint256 currentBalance, uint256 aTokenBalance, uint256 lastUpdateTime);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`principalDeposited_`|`uint256`|Total amount originally deposited|
|`currentBalance`|`uint256`|Current aToken balance including interest|
|`aTokenBalance`|`uint256`|Current aToken balance|
|`lastUpdateTime`|`uint256`|Timestamp of last position update|


### getAaveMarketData

Returns current Aave market data for the deposited asset

*Fetches real-time market information from Aave protocol*


```solidity
function getAaveMarketData()
    external
    view
    returns (uint256 supplyRate, uint256 utilizationRate, uint256 totalSupply, uint256 availableLiquidity);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`supplyRate`|`uint256`|Current supply rate for the asset|
|`utilizationRate`|`uint256`|Current utilization rate of the reserve|
|`totalSupply`|`uint256`|Total supply of the underlying asset|
|`availableLiquidity`|`uint256`|Available liquidity in the reserve|


### checkAaveHealth

Performs health checks on the Aave position

*Validates that the Aave position is healthy and functioning properly*


```solidity
function checkAaveHealth() external view returns (bool isHealthy, bool pauseStatus, uint256 lastUpdate);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isHealthy`|`bool`|True if position is healthy, false if issues detected|
|`pauseStatus`|`bool`|Current pause status of the contract|
|`lastUpdate`|`uint256`|Timestamp of last health check update|


### _isAaveHealthy


```solidity
function _isAaveHealthy() internal view returns (bool);
```

### autoRebalance


```solidity
function autoRebalance() external returns (bool rebalanced, uint256 newAllocation, uint256 expectedYield);
```

### calculateOptimalAllocation

Calculates the optimal allocation of funds to Aave

*Determines best allocation strategy based on current market conditions*


```solidity
function calculateOptimalAllocation() external view returns (uint256 optimalAllocation, uint256 expectedYield);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`optimalAllocation`|`uint256`|Recommended amount to allocate to Aave|
|`expectedYield`|`uint256`|Expected yield from the recommended allocation|


### setMaxAaveExposure

Sets the maximum exposure limit for Aave deposits

*Governance function to control risk by limiting Aave exposure*


```solidity
function setMaxAaveExposure(uint256 _maxExposure) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_maxExposure`|`uint256`|Maximum amount that can be deposited to Aave|


### emergencyWithdrawFromAave


```solidity
function emergencyWithdrawFromAave() external nonReentrant returns (uint256 amountWithdrawn);
```

### getRiskMetrics

Returns comprehensive risk metrics for the Aave position

*Provides detailed risk analysis including concentration and volatility metrics*


```solidity
function getRiskMetrics()
    external
    view
    returns (uint256 exposureRatio, uint256 concentrationRisk, uint256 liquidityRisk);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`exposureRatio`|`uint256`|Percentage of total assets exposed to Aave|
|`concentrationRisk`|`uint256`|Risk level due to concentration in Aave (1-3 scale)|
|`liquidityRisk`|`uint256`|Risk level based on Aave liquidity conditions (1-3 scale)|


### updateAaveParameters


```solidity
function updateAaveParameters(uint256 newHarvestThreshold, uint256 newYieldFee, uint256 newRebalanceThreshold)
    external;
```

### getAaveConfig

Returns the current Aave integration configuration

*Provides access to all configuration parameters for Aave integration*


```solidity
function getAaveConfig()
    external
    view
    returns (address aavePool_, address aUSDC_, uint256 harvestThreshold_, uint256 yieldFee_, uint256 maxExposure_);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`aavePool_`|`address`|Address of the Aave pool contract|
|`aUSDC_`|`address`|Address of the aUSDC token contract|
|`harvestThreshold_`|`uint256`|Minimum yield threshold for harvesting|
|`yieldFee_`|`uint256`|Fee percentage charged on yield|
|`maxExposure_`|`uint256`|Maximum allowed exposure to Aave|


### toggleEmergencyMode

Toggles emergency mode for the Aave vault

*Emergency function to enable/disable emergency mode during critical situations*


```solidity
function toggleEmergencyMode(bool enabled, string calldata reason) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`enabled`|`bool`|Whether to enable or disable emergency mode|
|`reason`|`string`|Human-readable reason for the change|


### pause

Pauses all Aave vault operations

*Emergency function to halt all vault operations when needed*


```solidity
function pause() external;
```

### unpause

Unpauses Aave vault operations

*Resumes normal vault operations after emergency is resolved*


```solidity
function unpause() external;
```

### recoverToken

Recovers accidentally sent ERC20 tokens from the vault

*Emergency function to recover tokens that are not part of normal operations*


```solidity
function recoverToken(address token, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The token address to recover|
|`amount`|`uint256`|The amount of tokens to recover|


### recoverETH

Recovers accidentally sent ETH from the vault

*Emergency function to recover ETH that shouldn't be in the vault*


```solidity
function recoverETH() external;
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

