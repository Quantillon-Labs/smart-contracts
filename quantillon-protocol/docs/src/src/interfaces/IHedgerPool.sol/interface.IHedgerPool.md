# IHedgerPool
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/fe414bc17d9f44041055fc158bb99f01c5c5476e/src/interfaces/IHedgerPool.sol)

**Author:**
Quantillon Labs

Interface for the HedgerPool managing hedging positions and rewards

**Note:**
team@quantillon.money


## Functions
### initialize

Initializes the hedger pool


```solidity
function initialize(address admin, address _usdc, address _oracle, address _yieldShift) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Admin address|
|`_usdc`|`address`|USDC token address|
|`_oracle`|`address`|Oracle contract address|
|`_yieldShift`|`address`|YieldShift contract address|


### enterHedgePosition

Enter a new hedging position


```solidity
function enterHedgePosition(uint256 usdcAmount, uint256 leverage) external returns (uint256 positionId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Margin amount in USDC|
|`leverage`|`uint256`|Desired leverage (<= max)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|New position ID|


### exitHedgePosition

Exit an existing hedging position fully


```solidity
function exitHedgePosition(uint256 positionId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|Position identifier|


### partialClosePosition

Close part of a hedging position


```solidity
function partialClosePosition(uint256 positionId, uint256 percentage) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|Position identifier|
|`percentage`|`uint256`|Percentage (bps) to close|


### addMargin

Add margin to a position


```solidity
function addMargin(uint256 positionId, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|Position identifier|
|`amount`|`uint256`|Amount of USDC to add|


### removeMargin

Remove margin from a position if safe


```solidity
function removeMargin(uint256 positionId, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|Position identifier|
|`amount`|`uint256`|Amount of USDC to remove|


### liquidateHedger

Liquidate an unsafe position


```solidity
function liquidateHedger(address hedger, uint256 positionId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Owner of the position|
|`positionId`|`uint256`|Position identifier|


### claimHedgingRewards

Claim accumulated hedging rewards


```solidity
function claimHedgingRewards(address hedger)
    external
    returns (uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Hedger address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`interestDifferential`|`uint256`|Interest differential amount|
|`yieldShiftRewards`|`uint256`|Rewards from YieldShift|
|`totalRewards`|`uint256`|Total rewards claimed|


### getHedgerPosition

Get a hedger position details


```solidity
function getHedgerPosition(address hedger, uint256 positionId)
    external
    view
    returns (
        uint256 positionSize,
        uint256 margin,
        uint256 entryPrice,
        uint256 leverage,
        uint256 entryTime,
        uint256 lastUpdateTime,
        int256 unrealizedPnL,
        bool isActive
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Hedger address|
|`positionId`|`uint256`|Position identifier|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`positionSize`|`uint256`|Current position size|
|`margin`|`uint256`|Current margin|
|`entryPrice`|`uint256`|Entry price|
|`leverage`|`uint256`|Leverage|
|`entryTime`|`uint256`|Entry timestamp|
|`lastUpdateTime`|`uint256`|Last update timestamp|
|`unrealizedPnL`|`int256`|Current unrealized PnL|
|`isActive`|`bool`|Active flag|


### getHedgerMarginRatio

Get current margin ratio for a position


```solidity
function getHedgerMarginRatio(address hedger, uint256 positionId) external view returns (uint256 marginRatio);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Hedger address|
|`positionId`|`uint256`|Position identifier|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`marginRatio`|`uint256`|Margin ratio in bps|


### isHedgerLiquidatable

Check if a hedger position is liquidatable


```solidity
function isHedgerLiquidatable(address hedger, uint256 positionId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Hedger address|
|`positionId`|`uint256`|Position identifier|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if liquidatable|


### getTotalHedgeExposure

Total hedge exposure in the pool


```solidity
function getTotalHedgeExposure() external view returns (uint256);
```

### getPoolStatistics

Pool statistics snapshot


```solidity
function getPoolStatistics()
    external
    view
    returns (
        uint256 activeHedgers_,
        uint256 totalPositions,
        uint256 averagePosition,
        uint256 totalMargin_,
        uint256 poolUtilization
    );
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`activeHedgers_`|`uint256`|Number of active hedgers|
|`totalPositions`|`uint256`|Total number of positions|
|`averagePosition`|`uint256`|Average position size|
|`totalMargin_`|`uint256`|Total margin|
|`poolUtilization`|`uint256`|Pool utilization ratio (bps)|


### getPendingHedgingRewards

Pending hedging rewards for a hedger


```solidity
function getPendingHedgingRewards(address hedger)
    external
    view
    returns (uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Hedger address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`interestDifferential`|`uint256`|Pending interest differential|
|`yieldShiftRewards`|`uint256`|Pending YieldShift rewards|
|`totalRewards`|`uint256`|Total pending rewards|


### updateHedgingParameters

Update hedging parameters


```solidity
function updateHedgingParameters(
    uint256 _minMarginRatio,
    uint256 _liquidationThreshold,
    uint256 _maxLeverage,
    uint256 _liquidationPenalty
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_minMarginRatio`|`uint256`|Minimum margin ratio (bps)|
|`_liquidationThreshold`|`uint256`|Liquidation threshold (bps)|
|`_maxLeverage`|`uint256`|Maximum leverage|
|`_liquidationPenalty`|`uint256`|Liquidation penalty (bps)|


### updateInterestRates

Update interest rates


```solidity
function updateInterestRates(uint256 newEurRate, uint256 newUsdRate) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newEurRate`|`uint256`|EUR rate (bps)|
|`newUsdRate`|`uint256`|USD rate (bps)|


### setHedgingFees

Set hedging fees


```solidity
function setHedgingFees(uint256 _entryFee, uint256 _exitFee, uint256 _marginFee) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_entryFee`|`uint256`|Entry fee (bps)|
|`_exitFee`|`uint256`|Exit fee (bps)|
|`_marginFee`|`uint256`|Margin fee (bps)|


### emergencyClosePosition

Emergency close a position by admin


```solidity
function emergencyClosePosition(address hedger, uint256 positionId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Hedger address|
|`positionId`|`uint256`|Position identifier|


### pause

Pause hedger pool operations


```solidity
function pause() external;
```

### unpause

Unpause hedger pool operations


```solidity
function unpause() external;
```

### getHedgingConfig

Hedging configuration snapshot


```solidity
function getHedgingConfig()
    external
    view
    returns (
        uint256 minMarginRatio,
        uint256 liquidationThreshold,
        uint256 maxLeverage,
        uint256 liquidationPenalty,
        uint256 entryFee,
        uint256 exitFee,
        uint256 marginFee
    );
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`minMarginRatio`|`uint256`|Minimum margin ratio (bps)|
|`liquidationThreshold`|`uint256`|Liquidation threshold (bps)|
|`maxLeverage`|`uint256`|Maximum leverage|
|`liquidationPenalty`|`uint256`|Liquidation penalty (bps)|
|`entryFee`|`uint256`|Entry fee (bps)|
|`exitFee`|`uint256`|Exit fee (bps)|
|`marginFee`|`uint256`|Margin fee (bps)|


### isHedgingActive

Whether hedging operations are active (not paused)


```solidity
function isHedgingActive() external view returns (bool);
```

