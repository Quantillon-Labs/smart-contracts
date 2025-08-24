# IAaveVault
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/fe414bc17d9f44041055fc158bb99f01c5c5476e/src/interfaces/IAaveVault.sol)

**Author:**
Quantillon Labs

Interface for the AaveVault (Aave V3 USDC yield vault)

*Mirrors the external/public API of `src/core/vaults/AaveVault.sol`*

**Note:**
team@quantillon.money


## Functions
### initialize

Initializes the Aave vault


```solidity
function initialize(
    address admin,
    address _usdc,
    address _aaveProvider,
    address _rewardsController,
    address _yieldShift
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Admin address|
|`_usdc`|`address`|USDC token address|
|`_aaveProvider`|`address`|Aave PoolAddressesProvider|
|`_rewardsController`|`address`|Aave RewardsController address|
|`_yieldShift`|`address`|YieldShift contract address|


### deployToAave

Deploy USDC to Aave V3 pool to earn yield


```solidity
function deployToAave(uint256 amount) external returns (uint256 aTokensReceived);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|USDC amount to supply|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`aTokensReceived`|`uint256`|Amount of aUSDC received|


### withdrawFromAave

Withdraw USDC from Aave V3 pool


```solidity
function withdrawFromAave(uint256 amount) external returns (uint256 usdcWithdrawn);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of aUSDC to withdraw (use type(uint256).max for all)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`usdcWithdrawn`|`uint256`|Amount of USDC actually withdrawn|


### claimAaveRewards

Claim Aave rewards (if any)


```solidity
function claimAaveRewards() external returns (uint256 rewardsClaimed);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rewardsClaimed`|`uint256`|Claimed reward amount|


### harvestAaveYield

Harvest Aave yield and distribute via YieldShift


```solidity
function harvestAaveYield() external returns (uint256 yieldHarvested);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`yieldHarvested`|`uint256`|Amount harvested|


### getAvailableYield

Calculate available yield for harvest


```solidity
function getAvailableYield() external view returns (uint256 available);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`available`|`uint256`|Amount of yield available|


### getYieldDistribution

Get yield distribution breakdown for current state


```solidity
function getYieldDistribution() external view returns (uint256 protocolYield, uint256 userYield, uint256 hedgerYield);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`protocolYield`|`uint256`|Protocol fee portion|
|`userYield`|`uint256`|Allocation to users|
|`hedgerYield`|`uint256`|Allocation to hedgers|


### getAaveBalance

Current aUSDC balance of the vault


```solidity
function getAaveBalance() external view returns (uint256);
```

### getAccruedInterest

Accrued interest (same as available yield)


```solidity
function getAccruedInterest() external view returns (uint256);
```

### getAaveAPY

Current Aave APY in basis points


```solidity
function getAaveAPY() external view returns (uint256);
```

### getAavePositionDetails

Aave position details snapshot


```solidity
function getAavePositionDetails()
    external
    view
    returns (uint256 principalDeposited_, uint256 currentBalance, uint256 aTokenBalance, uint256 lastUpdateTime);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`principalDeposited_`|`uint256`|Principal USDC supplied|
|`currentBalance`|`uint256`|Current aUSDC balance (1:1 underlying + interest)|
|`aTokenBalance`|`uint256`|Alias for aUSDC balance|
|`lastUpdateTime`|`uint256`|Timestamp of last harvest|


### getAaveMarketData

Aave market data snapshot


```solidity
function getAaveMarketData()
    external
    view
    returns (uint256 supplyRate, uint256 utilizationRate, uint256 totalSupply, uint256 availableLiquidity);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`supplyRate`|`uint256`|Current supply rate (bps)|
|`utilizationRate`|`uint256`|Utilization rate (bps)|
|`totalSupply`|`uint256`|USDC total supply|
|`availableLiquidity`|`uint256`|Available USDC liquidity in Aave pool|


### checkAaveHealth

Basic Aave pool health and pause state


```solidity
function checkAaveHealth() external view returns (bool isHealthy, bool pauseStatus, uint256 lastUpdate);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isHealthy`|`bool`|True if pool considered healthy|
|`pauseStatus`|`bool`|Whether vault is paused|
|`lastUpdate`|`uint256`|Last harvest time|


### autoRebalance

Attempt auto-rebalancing allocation


```solidity
function autoRebalance() external returns (bool rebalanced, uint256 newAllocation);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rebalanced`|`bool`|Whether a rebalance decision was made|
|`newAllocation`|`uint256`|New target allocation (bps)|


### calculateOptimalAllocation

Compute optimal allocation and expected yield


```solidity
function calculateOptimalAllocation() external view returns (uint256 optimalAllocation, uint256 expectedYield);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`optimalAllocation`|`uint256`|Target allocation (bps)|
|`expectedYield`|`uint256`|Expected yield proxy|


### setMaxAaveExposure

Update max exposure to Aave


```solidity
function setMaxAaveExposure(uint256 _maxExposure) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_maxExposure`|`uint256`|New max USDC exposure|


### emergencyWithdrawFromAave

Emergency: withdraw all from Aave


```solidity
function emergencyWithdrawFromAave() external returns (uint256 amountWithdrawn);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amountWithdrawn`|`uint256`|Amount withdrawn|


### getRiskMetrics

Risk metrics snapshot


```solidity
function getRiskMetrics()
    external
    view
    returns (uint256 exposureRatio, uint256 concentrationRisk, uint256 liquidityRisk);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`exposureRatio`|`uint256`|% of assets in Aave (bps)|
|`concentrationRisk`|`uint256`|Heuristic risk score (1-3)|
|`liquidityRisk`|`uint256`|Heuristic risk score (1-3)|


### updateAaveParameters

Update vault parameters


```solidity
function updateAaveParameters(uint256 newHarvestThreshold, uint256 newYieldFee, uint256 newRebalanceThreshold)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newHarvestThreshold`|`uint256`|Min yield to harvest|
|`newYieldFee`|`uint256`|Protocol fee on yield (bps)|
|`newRebalanceThreshold`|`uint256`|Rebalance threshold (bps)|


### getAaveConfig

Aave config snapshot


```solidity
function getAaveConfig()
    external
    view
    returns (address aavePool_, address aUSDC_, uint256 harvestThreshold_, uint256 yieldFee_, uint256 maxExposure_);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`aavePool_`|`address`|Aave Pool address|
|`aUSDC_`|`address`|aUSDC token address|
|`harvestThreshold_`|`uint256`|Current harvest threshold|
|`yieldFee_`|`uint256`|Current yield fee (bps)|
|`maxExposure_`|`uint256`|Max Aave exposure|


### toggleEmergencyMode

Toggle emergency mode


```solidity
function toggleEmergencyMode(bool enabled, string calldata reason) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`enabled`|`bool`|New emergency flag|
|`reason`|`string`|Reason string|


### pause

Pause the vault


```solidity
function pause() external;
```

### unpause

Unpause the vault


```solidity
function unpause() external;
```

### recoverToken

Recover ERC20 tokens sent by mistake


```solidity
function recoverToken(address token, address to, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address|
|`to`|`address`|Recipient|
|`amount`|`uint256`|Amount to transfer|


