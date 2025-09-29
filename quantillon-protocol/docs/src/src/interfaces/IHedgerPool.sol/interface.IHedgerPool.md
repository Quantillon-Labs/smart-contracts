# IHedgerPool
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/03f8f2db069e4fe5f129cc3e28526efe7b1f6f49/src/interfaces/IHedgerPool.sol)

Interface for the Quantillon HedgerPool contract

*Provides EUR/USD hedging functionality with leverage and margin management*

**Note:**
security-contact: team@quantillon.money


## Functions
### initialize

Initializes the HedgerPool with contracts and parameters

*Sets up the HedgerPool with initial configuration and assigns roles to admin*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Initializes all contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by initializer modifier

- access: Restricted to initializer modifier

- oracle: No oracle dependencies


```solidity
function initialize(
    address admin,
    address _usdc,
    address _oracle,
    address _yieldShift,
    address _timelock,
    address _treasury,
    address _vault
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Admin address receiving roles|
|`_usdc`|`address`|USDC token address|
|`_oracle`|`address`|Oracle contract address|
|`_yieldShift`|`address`|YieldShift contract address|
|`_timelock`|`address`|Timelock contract address|
|`_treasury`|`address`|Treasury address|
|`_vault`|`address`|QuantillonVault contract address|


### enterHedgePosition

Opens a new hedge position with specified USDC amount and leverage

*Creates a new hedge position with margin requirements and leverage validation*

**Notes:**
- security: Validates oracle price freshness, enforces margin ratios and leverage limits

- validation: Validates usdcAmount > 0, leverage <= maxLeverage, position count limits

- state-changes: Creates new HedgePosition, updates hedger totals, increments position counters

- events: Emits HedgePositionOpened with position details

- errors: Throws InvalidAmount if amount is 0, LeverageTooHigh if exceeds max

- reentrancy: Protected by secureNonReentrant modifier

- access: Public - no access restrictions

- oracle: Requires fresh EUR/USD price for position entry


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Validates liquidator role and commitment expiration

- validation: Validates commitment exists and has expired

- state-changes: Removes expired liquidation commitment

- events: No events emitted for commitment clearing

- errors: Throws CommitmentNotFound if commitment doesn't exist

- reentrancy: Not protected - no external calls

- access: Restricted to LIQUIDATOR_ROLE

- oracle: No oracle dependencies


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
- security: Validates liquidator role and commitment exists

- validation: Validates commitment hash matches stored commitment

- state-changes: Deletes liquidation commitment and pending liquidation flag

- events: No events emitted for commitment cancellation

- errors: Throws CommitmentNotFound if commitment doesn't exist

- reentrancy: Not protected - no external calls

- access: Restricted to LIQUIDATOR_ROLE

- oracle: No oracle dependencies


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
- security: Validates hedger has active positions, updates reward calculations

- validation: Validates hedger exists and has pending rewards

- state-changes: Resets pending rewards, updates last claim timestamp

- events: Emits HedgingRewardsClaimed with reward breakdown

- errors: Throws YieldClaimFailed if yield shift claim fails

- reentrancy: Protected by nonReentrant modifier

- access: Public - any hedger can claim their rewards

- oracle: No oracle dependencies for reward claiming


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
- security: Validates position ownership and oracle price validity

- validation: Validates hedger owns the position

- state-changes: No state changes - view function only

- events: No events emitted

- errors: Throws InvalidHedger, InvalidOraclePrice

- reentrancy: Not applicable - view function

- access: Public - anyone can query position data

- oracle: Requires fresh EUR/USD price from Chainlink oracle


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
- security: Validates position ownership

- validation: Validates hedger owns the position

- state-changes: No state changes - view function only

- events: No events emitted

- errors: Throws InvalidHedger if hedger doesn't own position

- reentrancy: Not applicable - view function

- access: Public - anyone can query margin ratio

- oracle: No oracle dependencies for margin ratio calculation


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
- security: Validates position ownership and oracle price validity

- validation: Validates hedger owns the position

- state-changes: No state changes - view function only

- events: No events emitted

- errors: Throws InvalidHedger if hedger doesn't own position

- reentrancy: Not applicable - view function

- access: Public - anyone can check liquidation status

- oracle: Requires fresh EUR/USD price for liquidation calculation


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query total exposure

- oracle: No oracle dependencies for exposure calculation


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
- security: Validates governance role and parameter constraints

- validation: Validates minMarginRatio >= 500, liquidationThreshold < minMarginRatio, maxLeverage <= 20, liquidationPenalty <= 1000

- state-changes: Updates all hedging parameter state variables

- events: No events emitted for parameter updates

- errors: Throws ConfigValueTooLow, ConfigInvalid, ConfigValueTooHigh

- reentrancy: Not protected - no external calls

- access: Restricted to GOVERNANCE_ROLE

- oracle: No oracle dependencies for parameter updates


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
|`newMinMarginRatio`|`uint256`|New minimum margin ratio in basis points (e.g., 500 = 5%)|
|`newLiquidationThreshold`|`uint256`|New liquidation threshold in basis points (e.g., 100 = 1%)|
|`newMaxLeverage`|`uint256`|New maximum leverage multiplier (e.g., 20 = 20x)|
|`newLiquidationPenalty`|`uint256`|New liquidation penalty in basis points (e.g., 200 = 2%)|


### updateInterestRates

Updates interest rates for EUR and USD

*Allows governance to adjust interest rates for reward calculations*

**Notes:**
- security: Validates governance role and rate constraints

- validation: Validates rates are within reasonable bounds (0-10000 basis points)

- state-changes: Updates eurInterestRate and usdInterestRate

- events: No events emitted for rate updates

- errors: Throws ConfigValueTooHigh if rates exceed maximum limits

- reentrancy: Not protected - no external calls

- access: Restricted to GOVERNANCE_ROLE

- oracle: No oracle dependencies for rate updates


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
- security: Validates governance role and fee constraints

- validation: Validates entryFee <= 100, exitFee <= 100, marginFee <= 50

- state-changes: Updates entryFee, exitFee, and marginFee state variables

- events: No events emitted for fee updates

- errors: Throws ConfigValueTooHigh if fees exceed maximum limits

- reentrancy: Not protected - no external calls

- access: Restricted to GOVERNANCE_ROLE

- oracle: No oracle dependencies for fee updates


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query hedging configuration

- oracle: No oracle dependencies


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
- security: Validates emergency role authorization

- validation: Validates position exists and is active

- state-changes: Closes position, transfers remaining margin to hedger

- events: Emits HedgePositionClosed event

- errors: Throws InvalidPosition if position doesn't exist

- reentrancy: Protected by nonReentrant modifier

- access: Restricted to EMERGENCY_ROLE

- oracle: Requires fresh EUR/USD price for PnL calculation


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
- security: Validates emergency role authorization

- validation: No input validation required

- state-changes: Sets pause state, stops all hedging operations

- events: Emits Paused event from OpenZeppelin

- errors: No errors thrown - safe pause operation

- reentrancy: Not protected - no external calls

- access: Restricted to EMERGENCY_ROLE

- oracle: No oracle dependencies for pause


```solidity
function pause() external;
```

### unpause

Unpauses hedging operations

*Allows emergency role to unpause the hedger pool after resolving issues*

**Notes:**
- security: Validates emergency role authorization

- validation: No input validation required

- state-changes: Removes pause state, resumes hedging operations

- events: Emits Unpaused event from OpenZeppelin

- errors: No errors thrown - safe unpause operation

- reentrancy: Not protected - no external calls

- access: Restricted to EMERGENCY_ROLE

- oracle: No oracle dependencies for unpause


```solidity
function unpause() external;
```

### isHedgingActive

Checks if hedging is currently active

*Returns true if the hedger pool is not paused and operational*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can check hedging status

- oracle: No oracle dependencies


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
- security: Validates admin role and uses secure recovery library

- validation: No input validation required - library handles validation

- state-changes: Transfers tokens from contract to treasury

- events: Emits TokenRecovered event

- errors: No errors thrown - library handles error cases

- reentrancy: Not protected - library handles reentrancy

- access: Restricted to DEFAULT_ADMIN_ROLE

- oracle: No oracle dependencies for token recovery


```solidity
function recoverToken(address token, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Address of the token to recover|
|`amount`|`uint256`|Amount of tokens to recover|


### recoverETH

Recovers ETH accidentally sent to the contract

*Emergency function to recover ETH that was accidentally sent to the contract*

**Notes:**
- security: Validates admin role and emits recovery event

- validation: No input validation required - transfers all ETH

- state-changes: Transfers all contract ETH balance to treasury

- events: Emits ETHRecovered with amount and treasury address

- errors: No errors thrown - safe ETH transfer

- reentrancy: Not protected - no external calls

- access: Restricted to DEFAULT_ADMIN_ROLE

- oracle: No oracle dependencies


```solidity
function recoverETH() external;
```

### usdc

Returns the USDC token contract interface

*USDC token used for margin deposits and withdrawals (6 decimals)*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query USDC contract

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query oracle address

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query yield shift address

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query minimum margin ratio

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query liquidation threshold

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query maximum leverage

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query liquidation penalty

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query entry fee

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query exit fee

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query margin fee

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query total margin

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query total exposure

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query active hedger count

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query next position ID

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query EUR interest rate

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query USD interest rate

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query total yield earned

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query interest differential pool

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query position count

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query position details

- oracle: No oracle dependencies for position data


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query hedger information

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query hedger positions

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query user pending yield

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query hedger pending yield

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query user last claim time

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query hedger last claim time

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query hedger last reward block

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query commitment status

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query commitment timestamp

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query last liquidation attempt

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query pending liquidation status

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query maximum positions per hedger

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query blocks per day

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query maximum reward period

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query liquidation cooldown

- oracle: No oracle dependencies


```solidity
function LIQUIDATION_COOLDOWN() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Liquidation cooldown in blocks|


### whitelistHedger

Whitelists a hedger address

*Allows the specified address to open hedge positions when whitelist is enabled*

**Notes:**
- security: Validates governance role and hedger address

- validation: Validates hedger is not address(0) and not already whitelisted

- state-changes: Updates isWhitelistedHedger mapping and grants HEDGER_ROLE

- events: Emits HedgerWhitelisted with hedger and caller addresses

- errors: Throws ZeroAddress if hedger is address(0), AlreadyWhitelisted if already whitelisted

- reentrancy: Not protected - no external calls

- access: Restricted to GOVERNANCE_ROLE

- oracle: No oracle dependencies


```solidity
function whitelistHedger(address hedger) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address to whitelist as a hedger|


### removeHedger

Removes a hedger from the whitelist

*Prevents the specified address from opening new hedge positions*

**Notes:**
- security: Validates governance role and hedger address

- validation: Validates hedger is not address(0) and is currently whitelisted

- state-changes: Updates isWhitelistedHedger mapping and revokes HEDGER_ROLE

- events: Emits HedgerRemoved with hedger and caller addresses

- errors: Throws ZeroAddress if hedger is address(0), NotWhitelisted if not whitelisted

- reentrancy: Not protected - no external calls

- access: Restricted to GOVERNANCE_ROLE

- oracle: No oracle dependencies


```solidity
function removeHedger(address hedger) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address to remove from hedger whitelist|


### toggleHedgerWhitelistMode

Toggles hedger whitelist mode

*When enabled, only whitelisted addresses can open hedge positions*

**Notes:**
- security: Validates governance role

- validation: No input validation required - boolean parameter

- state-changes: Updates hedgerWhitelistEnabled state variable

- events: Emits HedgerWhitelistModeToggled with enabled status and caller

- errors: No errors thrown - safe boolean toggle

- reentrancy: Not protected - no external calls

- access: Restricted to GOVERNANCE_ROLE

- oracle: No oracle dependencies


```solidity
function toggleHedgerWhitelistMode(bool enabled) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`enabled`|`bool`|Whether to enable hedger whitelist mode|


### isWhitelistedHedger

Check if an address is whitelisted as a hedger

*Returns true if the address is on the hedger whitelist*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query hedger whitelist status

- oracle: No oracle dependencies


```solidity
function isWhitelistedHedger(address hedger) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|isWhitelisted True if the address is whitelisted as a hedger|


### hedgerWhitelistEnabled

Check if hedger whitelist mode is enabled

*Returns true if hedger whitelist mode is active*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query hedger whitelist mode status

- oracle: No oracle dependencies


```solidity
function hedgerWhitelistEnabled() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|enabled True if hedger whitelist mode is enabled|


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

### HedgerWhitelisted

```solidity
event HedgerWhitelisted(address indexed hedger, address indexed caller);
```

### HedgerRemoved

```solidity
event HedgerRemoved(address indexed hedger, address indexed caller);
```

### HedgerWhitelistModeToggled

```solidity
event HedgerWhitelistModeToggled(bool enabled, address indexed caller);
```

