# IHedgerPool
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/a616e9423dc69fc1960f3a480a5300eaa5fe80e0/src/interfaces/IHedgerPool.sol)

Interface for the Quantillon HedgerPool contract

*Provides EUR/USD hedging functionality with leverage and margin management*

**Note:**
team@quantillon.money


## Functions
### enterHedgePosition

Opens a new hedge position with specified USDC amount and leverage

*Creates a new hedge position with margin requirements and leverage validation*

**Notes:**
- Validates oracle price freshness, enforces margin ratios and leverage limits

- Validates usdcAmount > 0, leverage <= maxLeverage, position count limits

- Creates new HedgePosition, updates hedger totals, increments position counters

- Emits HedgePositionOpened with position details

- Throws InvalidAmount if amount is 0, LeverageTooHigh if exceeds max

- Protected by secureNonReentrant modifier

- Public - no access restrictions

- Requires fresh EUR/USD price for position entry


```solidity
function enterHedgePosition(uint256 usdcAmount, uint256 leverage) external returns (uint256 positionId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|The amount of USDC to use for the position (6 decimals)|
|`leverage`|`uint256`|The leverage multiplier for the position (e.g., 5 for 5x leverage)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|The unique ID of the created position|


### exitHedgePosition

Closes an existing hedge position

*Closes a hedge position and calculates PnL based on current EUR/USD price*

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
function exitHedgePosition(uint256 positionId) external returns (int256 pnl);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|The ID of the position to close|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`pnl`|`int256`|The profit or loss from the position (positive for profit, negative for loss)|


### addMargin

Adds additional margin to an existing position

*Adds USDC margin to an existing hedge position to improve margin ratio*

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
function addMargin(uint256 positionId, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|The ID of the position to add margin to|
|`amount`|`uint256`|The amount of USDC to add as margin|


### removeMargin

Removes margin from an existing position

*Removes USDC margin from an existing hedge position, subject to minimum margin requirements*

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
function removeMargin(uint256 positionId, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|The ID of the position to remove margin from|
|`amount`|`uint256`|The amount of USDC margin to remove|


### commitLiquidation

Commits to liquidating a position (first step of two-phase liquidation)

*Commits to liquidating an undercollateralized position using a two-phase commit-reveal scheme*

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
function commitLiquidation(address hedger, uint256 positionId, bytes32 salt) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|The address of the hedger whose position will be liquidated|
|`positionId`|`uint256`|The ID of the position to liquidate|
|`salt`|`bytes32`|A random value to prevent front-running|


### liquidateHedger

Executes the liquidation of a position (second step of two-phase liquidation)

*Executes liquidation after valid commitment, transfers rewards and remaining margin*

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
function liquidateHedger(address hedger, uint256 positionId, bytes32 salt)
    external
    returns (uint256 liquidationReward);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|The address of the hedger whose position is being liquidated|
|`positionId`|`uint256`|The ID of the position to liquidate|
|`salt`|`bytes32`|The same salt value used in the commitment|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`liquidationReward`|`uint256`|The reward paid to the liquidator|


### hasPendingLiquidationCommitment

Checks if there's a pending liquidation commitment for a position

*Used to prevent margin operations during liquidation process*

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
function hasPendingLiquidationCommitment(address hedger, uint256 positionId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|The address of the hedger|
|`positionId`|`uint256`|The ID of the position|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if there's a pending liquidation commitment|


### clearExpiredLiquidationCommitment

Clears expired liquidation commitments

*Removes liquidation commitments that have expired beyond the commitment window*

**Notes:**
- Validates liquidator role and commitment expiration

- Validates commitment exists and has expired

- Removes expired liquidation commitment

- No events emitted for commitment clearing

- Throws CommitmentNotFound if commitment doesn't exist

- Not protected - no external calls

- Restricted to LIQUIDATOR_ROLE

- No oracle dependencies


```solidity
function clearExpiredLiquidationCommitment(address hedger, uint256 positionId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|The address of the hedger|
|`positionId`|`uint256`|The ID of the position|


### cancelLiquidationCommitment

Cancels a pending liquidation commitment

*Allows hedgers to cancel their liquidation commitment before execution*

**Notes:**
- Validates liquidator role and commitment exists

- Validates commitment hash matches stored commitment

- Deletes liquidation commitment and pending liquidation flag

- No events emitted for commitment cancellation

- Throws CommitmentNotFound if commitment doesn't exist

- Not protected - no external calls

- Restricted to LIQUIDATOR_ROLE

- No oracle dependencies


```solidity
function cancelLiquidationCommitment(address hedger, uint256 positionId, bytes32 salt) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|The hedger address|
|`positionId`|`uint256`|The position ID to cancel liquidation for|
|`salt`|`bytes32`|Same salt used in commitLiquidation for commitment verification|


### claimHedgingRewards

Claims accumulated hedging rewards for the caller

*Combines interest rate differential rewards and yield shift rewards*

**Notes:**
- Validates hedger has active positions, updates reward calculations

- Validates hedger exists and has pending rewards

- Resets pending rewards, updates last claim timestamp

- Emits HedgingRewardsClaimed with reward breakdown

- Throws YieldClaimFailed if yield shift claim fails

- Protected by nonReentrant modifier

- Public - any hedger can claim their rewards

- No oracle dependencies for reward claiming


```solidity
function claimHedgingRewards()
    external
    returns (uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`interestDifferential`|`uint256`|USDC rewards from interest rate differential (6 decimals)|
|`yieldShiftRewards`|`uint256`|USDC rewards from yield shift mechanism (6 decimals)|
|`totalRewards`|`uint256`|Total USDC rewards claimed (6 decimals)|


### getHedgerPosition

Returns detailed information about a specific hedge position

*Provides comprehensive position data including current market price*

**Notes:**
- Validates position ownership and oracle price validity

- Validates hedger owns the position

- No state changes - view function only

- No events emitted

- Throws InvalidHedger, InvalidOraclePrice

- Not applicable - view function

- Public - anyone can query position data

- Requires fresh EUR/USD price from Chainlink oracle


```solidity
function getHedgerPosition(address hedger, uint256 positionId)
    external
    view
    returns (
        uint256 positionSize,
        uint256 margin,
        uint256 entryPrice,
        uint256 currentPrice,
        uint256 leverage,
        uint256 lastUpdateTime
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger who owns the position|
|`positionId`|`uint256`|Unique identifier of the position to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`positionSize`|`uint256`|Total position size in USD equivalent|
|`margin`|`uint256`|Current margin amount in USDC (6 decimals)|
|`entryPrice`|`uint256`|EUR/USD price when position was opened|
|`currentPrice`|`uint256`|Current EUR/USD price from oracle|
|`leverage`|`uint256`|Leverage multiplier used for the position|
|`lastUpdateTime`|`uint256`|Timestamp of last position update|


### getHedgerMarginRatio

Returns the current margin ratio for a specific hedge position

*Calculates margin ratio as (margin / positionSize) * 10000 (in basis points)*

**Notes:**
- Validates position ownership

- Validates hedger owns the position

- No state changes - view function only

- No events emitted

- Throws InvalidHedger if hedger doesn't own position

- Not applicable - view function

- Public - anyone can query margin ratio

- No oracle dependencies for margin ratio calculation


```solidity
function getHedgerMarginRatio(address hedger, uint256 positionId) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger who owns the position|
|`positionId`|`uint256`|Unique identifier of the position to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|marginRatio Current margin ratio in basis points (10000 = 100%)|


### isHedgerLiquidatable

Checks if a hedge position is eligible for liquidation

*Determines if position margin ratio is below liquidation threshold*

**Notes:**
- Validates position ownership and oracle price validity

- Validates hedger owns the position

- No state changes - view function only

- No events emitted

- Throws InvalidHedger if hedger doesn't own position

- Not applicable - view function

- Public - anyone can check liquidation status

- Requires fresh EUR/USD price for liquidation calculation


```solidity
function isHedgerLiquidatable(address hedger, uint256 positionId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger who owns the position|
|`positionId`|`uint256`|Unique identifier of the position to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|liquidatable True if position can be liquidated, false otherwise|


### getTotalHedgeExposure

Returns the total hedge exposure across all active positions

*Calculates sum of all active position sizes in USD equivalent*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query total exposure

- No oracle dependencies for exposure calculation


```solidity
function getTotalHedgeExposure() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|totalExposure Total exposure across all hedge positions in USD|


### updateHedgingParameters

Updates core hedging parameters for risk management

*Allows governance to adjust risk parameters based on market conditions*

**Notes:**
- Validates governance role and parameter constraints

- Validates minMarginRatio >= 500, liquidationThreshold < minMarginRatio, maxLeverage <= 20, liquidationPenalty <= 1000

- Updates all hedging parameter state variables

- No events emitted for parameter updates

- Throws ConfigValueTooLow, ConfigInvalid, ConfigValueTooHigh

- Not protected - no external calls

- Restricted to GOVERNANCE_ROLE

- No oracle dependencies for parameter updates


```solidity
function updateHedgingParameters(
    uint256 newMinMarginRatio,
    uint256 newLiquidationThreshold,
    uint256 newMaxLeverage,
    uint256 newLiquidationPenalty
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMinMarginRatio`|`uint256`|New minimum margin ratio in basis points (e.g., 1000 = 10%)|
|`newLiquidationThreshold`|`uint256`|New liquidation threshold in basis points (e.g., 100 = 1%)|
|`newMaxLeverage`|`uint256`|New maximum leverage multiplier (e.g., 10 = 10x)|
|`newLiquidationPenalty`|`uint256`|New liquidation penalty in basis points (e.g., 200 = 2%)|


### updateInterestRates

Updates interest rates for EUR and USD

*Allows governance to adjust interest rates for reward calculations*

**Notes:**
- Validates governance role and rate constraints

- Validates rates are within reasonable bounds (0-10000 basis points)

- Updates eurInterestRate and usdInterestRate

- No events emitted for rate updates

- Throws ConfigValueTooHigh if rates exceed maximum limits

- Not protected - no external calls

- Restricted to GOVERNANCE_ROLE

- No oracle dependencies for rate updates


```solidity
function updateInterestRates(uint256 newEurRate, uint256 newUsdRate) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newEurRate`|`uint256`|New EUR interest rate in basis points (e.g., 350 = 3.5%)|
|`newUsdRate`|`uint256`|New USD interest rate in basis points (e.g., 450 = 4.5%)|


### setHedgingFees

Updates hedging fee parameters for protocol revenue

*Allows governance to adjust fees based on market conditions and protocol needs*

**Notes:**
- Validates governance role and fee constraints

- Validates entryFee <= 100, exitFee <= 100, marginFee <= 50

- Updates entryFee, exitFee, and marginFee state variables

- No events emitted for fee updates

- Throws ConfigValueTooHigh if fees exceed maximum limits

- Not protected - no external calls

- Restricted to GOVERNANCE_ROLE

- No oracle dependencies for fee updates


```solidity
function setHedgingFees(uint256 _entryFee, uint256 _exitFee, uint256 _marginFee) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_entryFee`|`uint256`|New entry fee in basis points (e.g., 20 = 0.2%, max 100 = 1%)|
|`_exitFee`|`uint256`|New exit fee in basis points (e.g., 20 = 0.2%, max 100 = 1%)|
|`_marginFee`|`uint256`|New margin fee in basis points (e.g., 10 = 0.1%, max 50 = 0.5%)|


### getHedgingConfig

Get hedging configuration parameters

*Returns all key hedging configuration parameters for risk management*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query hedging configuration

- No oracle dependencies


```solidity
function getHedgingConfig()
    external
    view
    returns (
        uint256 _minMarginRatio,
        uint256 _liquidationThreshold,
        uint256 _maxLeverage,
        uint256 _liquidationPenalty,
        uint256 _entryFee,
        uint256 _exitFee
    );
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_minMarginRatio`|`uint256`|Minimum margin ratio in basis points|
|`_liquidationThreshold`|`uint256`|Liquidation threshold in basis points|
|`_maxLeverage`|`uint256`|Maximum leverage multiplier|
|`_liquidationPenalty`|`uint256`|Liquidation penalty in basis points|
|`_entryFee`|`uint256`|Entry fee in basis points|
|`_exitFee`|`uint256`|Exit fee in basis points|


### emergencyClosePosition

Emergency close position function

*Allows emergency role to force close a position in emergency situations*

**Notes:**
- Validates emergency role authorization

- Validates position exists and is active

- Closes position, transfers remaining margin to hedger

- Emits HedgePositionClosed event

- Throws InvalidPosition if position doesn't exist

- Protected by nonReentrant modifier

- Restricted to EMERGENCY_ROLE

- Requires fresh EUR/USD price for PnL calculation


```solidity
function emergencyClosePosition(address hedger, uint256 positionId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger whose position to close|
|`positionId`|`uint256`|ID of the position to close|


### pause

Pauses all hedging operations

*Emergency function to pause the hedger pool in case of critical issues*

**Notes:**
- Validates emergency role authorization

- No input validation required

- Sets pause state, stops all hedging operations

- Emits Paused event from OpenZeppelin

- No errors thrown - safe pause operation

- Not protected - no external calls

- Restricted to EMERGENCY_ROLE

- No oracle dependencies for pause


```solidity
function pause() external;
```

### unpause

Unpauses hedging operations

*Allows emergency role to unpause the hedger pool after resolving issues*

**Notes:**
- Validates emergency role authorization

- No input validation required

- Removes pause state, resumes hedging operations

- Emits Unpaused event from OpenZeppelin

- No errors thrown - safe unpause operation

- Not protected - no external calls

- Restricted to EMERGENCY_ROLE

- No oracle dependencies for unpause


```solidity
function unpause() external;
```

### isHedgingActive

Checks if hedging is currently active

*Returns true if the hedger pool is not paused and operational*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can check hedging status

- No oracle dependencies


```solidity
function isHedgingActive() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|isActive True if hedging is active, false if paused|


### recoverToken

Recovers tokens accidentally sent to the contract

*Emergency function to recover ERC20 tokens that are not part of normal operations*

**Notes:**
- Validates admin role and uses secure recovery library

- No input validation required - library handles validation

- Transfers tokens from contract to specified address

- Emits TokenRecovered event

- No errors thrown - library handles error cases

- Not protected - library handles reentrancy

- Restricted to DEFAULT_ADMIN_ROLE

- No oracle dependencies for token recovery


```solidity
function recoverToken(address token, address to, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Address of the token to recover|
|`to`|`address`|Address to send recovered tokens to|
|`amount`|`uint256`|Amount of tokens to recover|


### recoverETH

Recovers ETH accidentally sent to the contract

*Emergency function to recover ETH that was accidentally sent to the contract*

**Notes:**
- Validates admin role and emits recovery event

- No input validation required - transfers all ETH

- Transfers all contract ETH balance to treasury

- Emits ETHRecovered with amount and treasury address

- No errors thrown - safe ETH transfer

- Not protected - no external calls

- Restricted to DEFAULT_ADMIN_ROLE

- No oracle dependencies


```solidity
function recoverETH() external;
```

### usdc

Returns the USDC token contract interface

*USDC token used for margin deposits and withdrawals (6 decimals)*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query USDC contract

- No oracle dependencies


```solidity
function usdc() external view returns (IERC20);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IERC20`|IERC20 USDC token contract interface|


### oracle

Returns the oracle contract address

*Chainlink oracle for EUR/USD price feeds*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query oracle address

- No oracle dependencies


```solidity
function oracle() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|address Oracle contract address|


### yieldShift

Returns the yield shift contract address

*YieldShift contract for reward distribution*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query yield shift address

- No oracle dependencies


```solidity
function yieldShift() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|address YieldShift contract address|


### minMarginRatio

Returns the minimum margin ratio in basis points

*Minimum margin ratio required for positions (e.g., 1000 = 10%)*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query minimum margin ratio

- No oracle dependencies


```solidity
function minMarginRatio() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Minimum margin ratio in basis points|


### liquidationThreshold

Returns the liquidation threshold in basis points

*Margin ratio below which positions can be liquidated (e.g., 100 = 1%)*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query liquidation threshold

- No oracle dependencies


```solidity
function liquidationThreshold() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Liquidation threshold in basis points|


### maxLeverage

Returns the maximum leverage multiplier

*Maximum leverage allowed for hedge positions (e.g., 10 = 10x)*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query maximum leverage

- No oracle dependencies


```solidity
function maxLeverage() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Maximum leverage multiplier|


### liquidationPenalty

Returns the liquidation penalty in basis points

*Penalty applied to liquidated positions (e.g., 200 = 2%)*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query liquidation penalty

- No oracle dependencies


```solidity
function liquidationPenalty() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Liquidation penalty in basis points|


### entryFee

Returns the entry fee in basis points

*Fee charged when opening hedge positions (e.g., 20 = 0.2%)*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query entry fee

- No oracle dependencies


```solidity
function entryFee() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Entry fee in basis points|


### exitFee

Returns the exit fee in basis points

*Fee charged when closing hedge positions (e.g., 20 = 0.2%)*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query exit fee

- No oracle dependencies


```solidity
function exitFee() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Exit fee in basis points|


### marginFee

Returns the margin fee in basis points

*Fee charged when adding/removing margin (e.g., 10 = 0.1%)*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query margin fee

- No oracle dependencies


```solidity
function marginFee() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Margin fee in basis points|


### totalMargin

Returns the total margin across all positions

*Total USDC margin held across all active hedge positions (6 decimals)*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query total margin

- No oracle dependencies


```solidity
function totalMargin() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Total margin in USDC|


### totalExposure

Returns the total exposure across all positions

*Total USD exposure across all active hedge positions*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query total exposure

- No oracle dependencies


```solidity
function totalExposure() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Total exposure in USD|


### activeHedgers

Returns the number of active hedgers

*Count of unique addresses with active hedge positions*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query active hedger count

- No oracle dependencies


```solidity
function activeHedgers() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Number of active hedgers|


### nextPositionId

Returns the next position ID to be assigned

*Counter for generating unique position IDs*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query next position ID

- No oracle dependencies


```solidity
function nextPositionId() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Next position ID|


### eurInterestRate

Returns the EUR interest rate in basis points

*Interest rate for EUR-denominated positions (e.g., 350 = 3.5%)*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query EUR interest rate

- No oracle dependencies


```solidity
function eurInterestRate() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 EUR interest rate in basis points|


### usdInterestRate

Returns the USD interest rate in basis points

*Interest rate for USD-denominated positions (e.g., 450 = 4.5%)*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query USD interest rate

- No oracle dependencies


```solidity
function usdInterestRate() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 USD interest rate in basis points|


### totalYieldEarned

Returns the total yield earned across all positions

*Total yield earned from interest rate differentials (6 decimals)*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query total yield earned

- No oracle dependencies


```solidity
function totalYieldEarned() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Total yield earned in USDC|


### interestDifferentialPool

Returns the interest differential pool balance

*Pool of funds available for interest rate differential rewards (6 decimals)*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query interest differential pool

- No oracle dependencies


```solidity
function interestDifferentialPool() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Interest differential pool balance in USDC|


### activePositionCount

Returns the active position count for a hedger

*Number of active positions owned by a specific hedger*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query position count

- No oracle dependencies


```solidity
function activePositionCount(address hedger) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Number of active positions for the hedger|


### positions

Returns position details by position ID

*Returns comprehensive position information for a specific position ID*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query position details

- No oracle dependencies for position data


```solidity
function positions(uint256 positionId)
    external
    view
    returns (
        address hedger,
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
|`positionId`|`uint256`|The ID of the position to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger who owns the position|
|`positionSize`|`uint256`|Total position size in USD equivalent|
|`margin`|`uint256`|Current margin amount in USDC (6 decimals)|
|`entryPrice`|`uint256`|EUR/USD price when position was opened|
|`leverage`|`uint256`|Leverage multiplier used for the position|
|`entryTime`|`uint256`|Timestamp when position was opened|
|`lastUpdateTime`|`uint256`|Timestamp of last position update|
|`unrealizedPnL`|`int256`|Current unrealized profit or loss|
|`isActive`|`bool`|Whether the position is currently active|


### hedgers

Get hedger information

*Returns comprehensive information about a hedger's positions and rewards*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query hedger information

- No oracle dependencies


```solidity
function hedgers(address hedger)
    external
    view
    returns (
        uint256[] memory positionIds,
        uint256 _totalMargin,
        uint256 _totalExposure,
        uint256 pendingRewards,
        uint256 lastRewardClaim,
        bool isActive
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`positionIds`|`uint256[]`|Array of position IDs owned by the hedger|
|`_totalMargin`|`uint256`|Total margin across all positions (6 decimals)|
|`_totalExposure`|`uint256`|Total exposure across all positions in USD|
|`pendingRewards`|`uint256`|Pending rewards available for claim (6 decimals)|
|`lastRewardClaim`|`uint256`|Timestamp of last reward claim|
|`isActive`|`bool`|Whether hedger has active positions|


### hedgerPositions

Returns array of position IDs for a hedger

*Returns all position IDs owned by a specific hedger*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query hedger positions

- No oracle dependencies


```solidity
function hedgerPositions(address hedger) external view returns (uint256[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256[]`|uint256[] Array of position IDs owned by the hedger|


### userPendingYield

Returns pending yield for a user

*Returns pending yield rewards for a specific user address*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query user pending yield

- No oracle dependencies


```solidity
function userPendingYield(address user) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Pending yield amount in USDC (6 decimals)|


### hedgerPendingYield

Returns pending yield for a hedger

*Returns pending yield rewards for a specific hedger address*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query hedger pending yield

- No oracle dependencies


```solidity
function hedgerPendingYield(address hedger) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Pending yield amount in USDC (6 decimals)|


### userLastClaim

Returns last claim time for a user

*Returns timestamp of last yield claim for a specific user*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query user last claim time

- No oracle dependencies


```solidity
function userLastClaim(address user) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Timestamp of last yield claim|


### hedgerLastClaim

Returns last claim time for a hedger

*Returns timestamp of last yield claim for a specific hedger*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query hedger last claim time

- No oracle dependencies


```solidity
function hedgerLastClaim(address hedger) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Timestamp of last yield claim|


### hedgerLastRewardBlock

Returns last reward block for a hedger

*Returns block number of last reward calculation for a specific hedger*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query hedger last reward block

- No oracle dependencies


```solidity
function hedgerLastRewardBlock(address hedger) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Block number of last reward calculation|


### liquidationCommitments

Returns liquidation commitment status

*Returns whether a specific liquidation commitment exists*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query commitment status

- No oracle dependencies


```solidity
function liquidationCommitments(bytes32 commitment) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`commitment`|`bytes32`|Hash of the liquidation commitment|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if commitment exists, false otherwise|


### liquidationCommitmentTimes

Returns liquidation commitment timestamp

*Returns block number when liquidation commitment was created*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query commitment timestamp

- No oracle dependencies


```solidity
function liquidationCommitmentTimes(bytes32 commitment) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`commitment`|`bytes32`|Hash of the liquidation commitment|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Block number when commitment was created|


### lastLiquidationAttempt

Returns last liquidation attempt block

*Returns block number of last liquidation attempt for a hedger*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query last liquidation attempt

- No oracle dependencies


```solidity
function lastLiquidationAttempt(address hedger) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Block number of last liquidation attempt|


### hasPendingLiquidation

Returns pending liquidation status

*Returns whether a position has a pending liquidation commitment*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query pending liquidation status

- No oracle dependencies


```solidity
function hasPendingLiquidation(address hedger, uint256 positionId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger|
|`positionId`|`uint256`|ID of the position|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if liquidation is pending, false otherwise|


### MAX_POSITIONS_PER_HEDGER

Returns the maximum positions per hedger

*Maximum number of positions a single hedger can have open simultaneously*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query maximum positions per hedger

- No oracle dependencies


```solidity
function MAX_POSITIONS_PER_HEDGER() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Maximum positions per hedger|


### BLOCKS_PER_DAY

Returns the number of blocks per day

*Used for time-based calculations and reward periods*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query blocks per day

- No oracle dependencies


```solidity
function BLOCKS_PER_DAY() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Number of blocks per day|


### MAX_REWARD_PERIOD

Returns the maximum reward period

*Maximum time period for reward calculations in blocks*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query maximum reward period

- No oracle dependencies


```solidity
function MAX_REWARD_PERIOD() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Maximum reward period in blocks|


### LIQUIDATION_COOLDOWN

Returns the liquidation cooldown period

*Minimum blocks between liquidation attempts for the same hedger*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query liquidation cooldown

- No oracle dependencies


```solidity
function LIQUIDATION_COOLDOWN() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Liquidation cooldown in blocks|


## Events
### HedgePositionOpened

```solidity
event HedgePositionOpened(
    address indexed hedger,
    uint256 indexed positionId,
    uint256 positionSize,
    uint256 margin,
    uint256 leverage,
    uint256 entryPrice
);
```

### HedgePositionClosed

```solidity
event HedgePositionClosed(
    address indexed hedger, uint256 indexed positionId, uint256 exitPrice, int256 pnl, uint256 timestamp
);
```

### MarginAdded

```solidity
event MarginAdded(address indexed hedger, uint256 indexed positionId, uint256 marginAdded, uint256 newMarginRatio);
```

### MarginRemoved

```solidity
event MarginRemoved(address indexed hedger, uint256 indexed positionId, uint256 marginRemoved, uint256 newMarginRatio);
```

### HedgerLiquidated

```solidity
event HedgerLiquidated(
    address indexed hedger,
    uint256 indexed positionId,
    address indexed liquidator,
    uint256 liquidationReward,
    uint256 remainingMargin
);
```

### HedgingRewardsClaimed

```solidity
event HedgingRewardsClaimed(
    address indexed hedger, uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards
);
```

