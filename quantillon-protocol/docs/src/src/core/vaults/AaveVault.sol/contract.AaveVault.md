# AaveVault
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/5aee937988a17532c1c3fcdcebf45d2f03a0c08d/src/core/vaults/AaveVault.sol)

**Inherits:**
Initializable, ReentrancyGuardUpgradeable, AccessControlUpgradeable, PausableUpgradeable, [SecureUpgradeable](/src/core/SecureUpgradeable.sol/abstract.SecureUpgradeable.md)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

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

Constructor for AaveVault implementation

*Disables initialization on implementation for security*

**Notes:**
- security: Disables initialization on implementation for security

- validation: No input validation required

- state-changes: Disables initializers

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not protected - constructor only

- access: Public constructor

- oracle: No oracle dependencies


```solidity
constructor();
```

### initialize

Initialize the AaveVault contract

*Sets up the contract with all required addresses and roles*

**Notes:**
- security: Validates all addresses are not zero

- validation: Validates all input addresses

- state-changes: Initializes ReentrancyGuard, AccessControl, and Pausable

- events: Emits initialization events

- errors: Throws if any address is zero

- reentrancy: Protected by initializer modifier

- access: Public initializer

- oracle: No oracle dependencies


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
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address of the admin role|
|`_usdc`|`address`|Address of the USDC token contract|
|`_aaveProvider`|`address`|Address of the Aave pool addresses provider|
|`_rewardsController`|`address`|Address of the Aave rewards controller|
|`_yieldShift`|`address`|Address of the yield shift contract|
|`_timelock`|`address`|Address of the timelock contract|
|`_treasury`|`address`|Address of the treasury|


### deployToAave

Deploy USDC to Aave V3 pool to earn yield

*Supplies USDC to Aave protocol and receives aUSDC tokens representing the deposit*

**Notes:**
- security: Validates oracle price freshness, enforces exposure limits and health checks

- validation: Validates amount > 0, checks max exposure limits, verifies Aave pool health

- state-changes: Updates principalDeposited, transfers USDC from caller, receives aUSDC

- events: Emits DeployedToAave with operation details

- errors: Throws WouldExceedLimit if exceeds maxAaveExposure, AavePoolNotHealthy if pool unhealthy

- reentrancy: Protected by nonReentrant modifier

- access: Restricted to VAULT_MANAGER_ROLE

- oracle: Requires fresh EUR/USD price for health validation


```solidity
function deployToAave(uint256 amount) external nonReentrant whenNotPaused returns (uint256 aTokensReceived);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|USDC amount to supply (6 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`aTokensReceived`|`uint256`|Amount of aUSDC received (6 decimals)|


### withdrawFromAave

Withdraw USDC from Aave V3 pool

*Withdraws USDC from Aave protocol, validates slippage and updates principal tracking*

**Notes:**
- security: Validates withdrawal constraints, enforces minimum balance requirements

- validation: Validates amount > 0, checks sufficient aUSDC balance, validates slippage

- state-changes: Updates principalDeposited, withdraws aUSDC, receives USDC

- events: Emits WithdrawnFromAave with withdrawal details

- errors: Throws InsufficientBalance if not enough aUSDC, WouldBreachMinimum if below threshold

- reentrancy: Protected by nonReentrant modifier

- access: Restricted to VAULT_MANAGER_ROLE

- oracle: No oracle dependency for withdrawals


```solidity
function withdrawFromAave(uint256 amount) external nonReentrant returns (uint256 usdcWithdrawn);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of aUSDC to withdraw (6 decimals, use type(uint256).max for all)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`usdcWithdrawn`|`uint256`|Amount of USDC actually withdrawn (6 decimals)|


### _validateAndCalculateWithdrawAmount

Validates and calculates the actual withdrawal amount

*Internal function to validate withdrawal parameters and calculate actual amount*

**Notes:**
- security: Validates sufficient balance and handles max withdrawal requests

- validation: Validates aaveBalance > 0, amount <= aaveBalance

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws InsufficientBalance if balance too low

- reentrancy: Not applicable - pure function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function _validateAndCalculateWithdrawAmount(uint256 amount, uint256 aaveBalance)
    internal
    pure
    returns (uint256 withdrawAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Requested withdrawal amount (6 decimals)|
|`aaveBalance`|`uint256`|Current aUSDC balance (6 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`withdrawAmount`|`uint256`|Actual amount to withdraw (6 decimals)|


### _validateWithdrawalConstraints

Validates withdrawal constraints (emergency mode, minimum balance)

*Internal function to validate withdrawal constraints and minimum balance requirements*

**Notes:**
- security: Enforces minimum balance requirements unless in emergency mode

- validation: Validates remaining balance >= minimum threshold

- state-changes: No state changes - view function

- events: No events emitted

- errors: Throws WouldBreachMinimum if below minimum balance threshold

- reentrancy: Not applicable - view function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function _validateWithdrawalConstraints(uint256 withdrawAmount, uint256 aaveBalance) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`withdrawAmount`|`uint256`|Amount to withdraw (6 decimals)|
|`aaveBalance`|`uint256`|Current aUSDC balance (6 decimals)|


### _validateExpectedWithdrawal

Validates expected withdrawal amounts before external call

*Validates expected withdrawal amounts before external call*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function _validateExpectedWithdrawal(uint256 withdrawAmount) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`withdrawAmount`|`uint256`|Amount to withdraw|


### _executeAaveWithdrawal

Executes the Aave withdrawal with proper error handling

*Executes the Aave withdrawal with proper error handling*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function _executeAaveWithdrawal(uint256 originalAmount, uint256 withdrawAmount, uint256 usdcBefore)
    internal
    returns (uint256 usdcWithdrawn);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`originalAmount`|`uint256`|Original amount requested|
|`withdrawAmount`|`uint256`|Amount to withdraw from Aave|
|`usdcBefore`|`uint256`|USDC balance before withdrawal|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`usdcWithdrawn`|`uint256`|Actual amount withdrawn|


### _validateWithdrawalResult

Validates the withdrawal result and slippage

*Validates the withdrawal result and slippage*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function _validateWithdrawalResult(
    uint256 originalAmount,
    uint256 withdrawAmount,
    uint256 usdcBefore,
    uint256 usdcWithdrawn
) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`originalAmount`|`uint256`|Original amount requested|
|`withdrawAmount`|`uint256`|Amount to withdraw from Aave|
|`usdcBefore`|`uint256`|USDC balance before withdrawal|
|`usdcWithdrawn`|`uint256`|Actual amount withdrawn|


### claimAaveRewards

Claim Aave rewards (if any)

*Claims any available Aave protocol rewards for the vault's aUSDC position*

**Notes:**
- security: No additional security checks required - Aave handles reward validation

- validation: No input validation required - view function checks pending rewards

- state-changes: Claims rewards to vault address, updates reward tracking

- events: Emits AaveRewardsClaimed with reward details

- errors: No errors thrown - safe to call even with no rewards

- reentrancy: Protected by nonReentrant modifier

- access: Restricted to VAULT_MANAGER_ROLE

- oracle: No oracle dependency for reward claims


```solidity
function claimAaveRewards() external nonReentrant returns (uint256 rewardsClaimed);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rewardsClaimed`|`uint256`|Claimed reward amount (18 decimals)|


### harvestAaveYield

Harvest Aave yield and distribute via YieldShift

*Harvests available yield from Aave lending, charges protocol fees, distributes net yield*

**Notes:**
- security: Uses CEI pattern, validates slippage, enforces harvest threshold

- validation: Validates available yield >= harvestThreshold before harvesting

- state-changes: Updates lastHarvestTime, totalFeesCollected, totalYieldHarvested

- events: Emits AaveYieldHarvested with harvest details

- errors: Throws BelowThreshold if yield < harvestThreshold, ExcessiveSlippage if slippage too high

- reentrancy: Protected by nonReentrant modifier

- access: Restricted to VAULT_MANAGER_ROLE

- oracle: No oracle dependency for yield harvesting


```solidity
function harvestAaveYield() external nonReentrant returns (uint256 yieldHarvested);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`yieldHarvested`|`uint256`|Amount harvested (6 decimals)|


### getAvailableYield

Returns the total available yield from Aave lending

*Calculates yield based on current aToken balance vs principal deposited*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

Check if Aave protocol is healthy

*Checks if Aave protocol is functioning properly by verifying reserve data*

**Notes:**
- security: Uses try-catch to handle potential failures gracefully

- validation: No input validation required

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - uses try-catch

- reentrancy: Not applicable - view function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function _isAaveHealthy() internal view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if Aave is healthy, false otherwise|


### autoRebalance

Automatically rebalance the vault allocation

*Rebalances the vault allocation based on optimal allocation calculations*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function autoRebalance() external returns (bool rebalanced, uint256 newAllocation, uint256 expectedYield);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rebalanced`|`bool`|True if rebalancing occurred, false otherwise|
|`newAllocation`|`uint256`|New allocation percentage after rebalancing|
|`expectedYield`|`uint256`|Expected yield from the new allocation|


### calculateOptimalAllocation

Calculates the optimal allocation of funds to Aave

*Determines best allocation strategy based on current market conditions*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function setMaxAaveExposure(uint256 _maxExposure) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_maxExposure`|`uint256`|Maximum amount that can be deposited to Aave|


### emergencyWithdrawFromAave

Emergency withdrawal from Aave protocol

*Emergency function to withdraw all funds from Aave protocol*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function emergencyWithdrawFromAave() external nonReentrant returns (uint256 amountWithdrawn);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amountWithdrawn`|`uint256`|Amount of USDC withdrawn from Aave|


### getRiskMetrics

Returns comprehensive risk metrics for the Aave position

*Provides detailed risk analysis including concentration and volatility metrics*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

Update Aave parameters

*Updates harvest threshold, yield fee, and rebalance threshold*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function updateAaveParameters(uint256 newHarvestThreshold, uint256 newYieldFee, uint256 newRebalanceThreshold)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newHarvestThreshold`|`uint256`|New harvest threshold in USDC|
|`newYieldFee`|`uint256`|New yield fee in basis points|
|`newRebalanceThreshold`|`uint256`|New rebalance threshold in basis points|


### getAaveConfig

Returns the current Aave integration configuration

*Provides access to all configuration parameters for Aave integration*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function pause() external;
```

### unpause

Unpauses Aave vault operations

*Resumes normal vault operations after emergency is resolved*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function unpause() external;
```

### recoverToken

Recovers accidentally sent ERC20 tokens from the vault

*Emergency function to recover tokens that are not part of normal operations*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

