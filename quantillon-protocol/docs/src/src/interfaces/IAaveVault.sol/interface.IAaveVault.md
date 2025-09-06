# IAaveVault
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/e665b137b9c124a3a0f62fb142df5c259e29a6fb/src/interfaces/IAaveVault.sol)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Interface for the AaveVault (Aave V3 USDC yield vault)

*Mirrors the external/public API of `src/core/vaults/AaveVault.sol`*

**Note:**
team@quantillon.money


## Functions
### initialize

Initializes the Aave vault

*Initializes the AaveVault contract with required addresses*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

*Deploys USDC to Aave V3 pool to earn yield*

**Notes:**
- Validates oracle price freshness, enforces exposure limits

- Validates amount > 0, checks max exposure limits

- Updates principalDeposited, transfers USDC, receives aUSDC

- Emits DeployedToAave with operation details

- Throws WouldExceedLimit if exceeds maxAaveExposure

- Protected by nonReentrant modifier

- Restricted to VAULT_MANAGER_ROLE

- Requires fresh EUR/USD price for health validation


```solidity
function deployToAave(uint256 amount) external returns (uint256 aTokensReceived);
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

*Withdraws USDC from Aave V3 pool*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

*Claims Aave rewards if any are available*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function claimAaveRewards() external returns (uint256 rewardsClaimed);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rewardsClaimed`|`uint256`|Claimed reward amount|


### harvestAaveYield

Harvest Aave yield and distribute via YieldShift

*This function calls YieldShift.harvestAndDistributeAaveYield() to handle distribution*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function harvestAaveYield() external returns (uint256 yieldHarvested);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`yieldHarvested`|`uint256`|Amount harvested|


### getAvailableYield

Calculate available yield for harvest

*Calculates the amount of yield available for harvest*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function getAvailableYield() external view returns (uint256 available);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`available`|`uint256`|Amount of yield available|


### getYieldDistribution

Get yield distribution breakdown for current state

*Returns the breakdown of yield distribution for current state*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

*Returns the current aUSDC balance of the vault*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function getAaveBalance() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The current aUSDC balance|


### getAccruedInterest

Accrued interest (same as available yield)

*Returns the accrued interest (same as available yield)*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function getAccruedInterest() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The accrued interest amount|


### getAaveAPY

Current Aave APY in basis points

*Returns the current Aave APY in basis points*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function getAaveAPY() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Current APY in basis points|


### getAavePositionDetails

Aave position details snapshot

*Returns a snapshot of Aave position details*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

*Returns Aave market data snapshot*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

*Returns basic Aave pool health and pause state*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

*Automatically rebalances allocation based on current market conditions and yield opportunities*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

*Calculates the optimal allocation percentage and expected yield based on current market conditions*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

*Sets the maximum USDC exposure limit for Aave protocol interactions*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function setMaxAaveExposure(uint256 _maxExposure) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_maxExposure`|`uint256`|New max USDC exposure|


### emergencyWithdrawFromAave

Emergency: withdraw all from Aave

*Emergency function to withdraw all funds from Aave protocol in case of emergency*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function emergencyWithdrawFromAave() external returns (uint256 amountWithdrawn);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amountWithdrawn`|`uint256`|Amount withdrawn|


### getRiskMetrics

Risk metrics snapshot

*Returns current risk metrics including exposure ratio and risk scores*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

*Updates key vault parameters including harvest threshold, yield fee, and rebalance threshold*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

*Returns current Aave configuration including pool address, token address, and key parameters*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

*Enables or disables emergency mode with a reason for the action*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

*Pauses all vault operations for emergency situations*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function pause() external;
```

### unpause

Unpause the vault

*Resumes vault operations after being paused*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function unpause() external;
```

### recoverToken

Recover ERC20 tokens sent by mistake

*Allows recovery of ERC20 tokens accidentally sent to the contract*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function recoverToken(address token, address to, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address|
|`to`|`address`|Recipient|
|`amount`|`uint256`|Amount to transfer|


### recoverETH

Recover ETH sent by mistake

*Allows recovery of ETH accidentally sent to the contract*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function recoverETH() external;
```

### hasRole

Check if an account has a specific role

*Returns true if the account has the specified role*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function hasRole(bytes32 role, address account) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to check|
|`account`|`address`|The account to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if the account has the role, false otherwise|


### getRoleAdmin

Get the admin role for a specific role

*Returns the admin role that controls the specified role*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function getRoleAdmin(bytes32 role) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to get the admin for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|bytes32 The admin role|


### grantRole

Grant a role to an account

*Grants the specified role to the account*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function grantRole(bytes32 role, address account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to grant|
|`account`|`address`|The account to grant the role to|


### revokeRole

Revoke a role from an account

*Revokes the specified role from the account*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function revokeRole(bytes32 role, address account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to revoke|
|`account`|`address`|The account to revoke the role from|


### renounceRole

Renounce a role

*Renounces the specified role from the caller*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function renounceRole(bytes32 role, address callerConfirmation) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to renounce|
|`callerConfirmation`|`address`|Confirmation that the caller is renouncing the role|


### paused

Check if the contract is paused

*Returns true if the contract is paused, false otherwise*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function paused() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if paused, false otherwise|


### upgradeTo

Upgrade the contract implementation

*Upgrades the contract to a new implementation*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function upgradeTo(address newImplementation) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|


### upgradeToAndCall

Upgrade the contract implementation and call a function

*Upgrades the contract to a new implementation and calls a function*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|
|`data`|`bytes`|Data to call on the new implementation|


### GOVERNANCE_ROLE

Get the governance role identifier

*Returns the governance role identifier*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function GOVERNANCE_ROLE() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|bytes32 The governance role identifier|


### VAULT_MANAGER_ROLE

Get the vault manager role identifier

*Returns the vault manager role identifier*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function VAULT_MANAGER_ROLE() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|bytes32 The vault manager role identifier|


### EMERGENCY_ROLE

Get the emergency role identifier

*Returns the emergency role identifier*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function EMERGENCY_ROLE() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|bytes32 The emergency role identifier|


### UPGRADER_ROLE

Get the upgrader role identifier

*Returns the upgrader role identifier*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function UPGRADER_ROLE() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|bytes32 The upgrader role identifier|


### usdc

Get the USDC token address

*Returns the address of the USDC token contract*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function usdc() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|address The USDC token address|


### aUSDC

Get the aUSDC token address

*Returns the address of the aUSDC token contract*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function aUSDC() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|address The aUSDC token address|


### aavePool

Get the Aave pool address

*Returns the address of the Aave pool contract*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function aavePool() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|address The Aave pool address|


### aaveProvider

Get the Aave provider address

*Returns the address of the Aave provider contract*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function aaveProvider() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|address The Aave provider address|


### rewardsController

Get the rewards controller address

*Returns the address of the rewards controller contract*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function rewardsController() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|address The rewards controller address|


### yieldShift

Get the yield shift address

*Returns the address of the yield shift contract*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function yieldShift() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|address The yield shift address|


### maxAaveExposure

Get the maximum Aave exposure

*Returns the maximum amount that can be deposited to Aave*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function maxAaveExposure() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The maximum Aave exposure|


### harvestThreshold

Get the harvest threshold

*Returns the minimum amount required to trigger a harvest*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function harvestThreshold() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The harvest threshold|


### yieldFee

Get the yield fee

*Returns the fee percentage charged on harvested yield*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function yieldFee() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The yield fee in basis points|


### rebalanceThreshold

Get the rebalance threshold

*Returns the threshold for triggering rebalancing*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function rebalanceThreshold() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The rebalance threshold|


### principalDeposited

Get the principal deposited amount

*Returns the total amount of principal deposited to Aave*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function principalDeposited() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The principal deposited amount|


### lastHarvestTime

Get the last harvest time

*Returns the timestamp of the last harvest*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function lastHarvestTime() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The last harvest time|


### totalYieldHarvested

Get the total yield harvested

*Returns the total amount of yield harvested from Aave*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function totalYieldHarvested() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The total yield harvested|


### totalFeesCollected

Get the total fees collected

*Returns the total amount of fees collected*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function totalFeesCollected() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The total fees collected|


### utilizationLimit

Get the utilization limit

*Returns the maximum utilization rate allowed*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function utilizationLimit() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The utilization limit|


### emergencyExitThreshold

Get the emergency exit threshold

*Returns the threshold for triggering emergency exit*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function emergencyExitThreshold() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The emergency exit threshold|


### emergencyMode

Get the emergency mode status

*Returns true if the contract is in emergency mode*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function emergencyMode() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if in emergency mode, false otherwise|


