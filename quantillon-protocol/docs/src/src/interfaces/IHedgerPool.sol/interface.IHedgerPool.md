# IHedgerPool
Interface for the Quantillon HedgerPool contract

*Provides EUR/USD hedging functionality with leverage and margin management*

**Note:**
team@quantillon.money


## Functions
### initialize

Initializes the HedgerPool with contracts and parameters

*Sets up the HedgerPool with initial configuration and assigns roles to admin*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Initializes all contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by initializer modifier

- Restricted to initializer modifier

- No oracle dependencies


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


### recordUserMint

Synchronizes hedger fills with a user mint

*Callable only by QuantillonVault to allocate fills proportionally*

**Notes:**
- Restricted to the vault; validates amount > 0

- Amount and price must be positive

- Updates per-position fills and total exposure

- Emits `HedgerFillUpdated`

- Reverts with capacity-related errors when overfilled

- Implementations must guard state before external calls

- Vault-only

- Uses provided fill price


```solidity
function recordUserMint(uint256 usdcAmount, uint256 fillPrice, uint256 qeuroAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Net USDC amount minted into QEURO (6 decimals)|
|`fillPrice`|`uint256`|EUR/USD oracle price (18 decimals) used for the mint|
|`qeuroAmount`|`uint256`|QEURO amount that was minted (18 decimals)|


### recordUserRedeem

Synchronizes hedger fills with a user redemption

*Callable only by QuantillonVault to release fills proportionally*

**Notes:**
- Restricted to the vault; validates amount > 0

- Amount and price must be positive

- Reduces per-position fills and total exposure

- Emits `HedgerFillUpdated`

- Reverts if insufficient filled exposure remains

- Implementations must guard state before external calls

- Vault-only

- Uses provided redeem price


```solidity
function recordUserRedeem(uint256 usdcAmount, uint256 redeemPrice, uint256 qeuroAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Gross USDC amount returned to the user (6 decimals)|
|`redeemPrice`|`uint256`|EUR/USD oracle price (18 decimals) observed by the vault|
|`qeuroAmount`|`uint256`|QEURO amount that was redeemed (18 decimals)|


### claimHedgingRewards

Claims accrued hedging rewards for the caller

*Combines interest differential and YieldShift rewards*

**Notes:**
- Validates caller has accrued rewards, transfers USDC tokens

- Checks reward amounts are positive and don't exceed accrued balances

- Resets hedger reward accumulators, transfers USDC to caller

- Emits HedgingRewardsClaimed with reward details

- Reverts if no rewards available or transfer fails

- Protected by reentrancy guard

- Public - any hedger can claim their rewards

- Not applicable


```solidity
function claimHedgingRewards()
    external
    returns (uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`interestDifferential`|`uint256`|Rewards from interest spread|
|`yieldShiftRewards`|`uint256`|Rewards distributed by YieldShift|
|`totalRewards`|`uint256`|Sum of all rewards transferred|


### getTotalEffectiveHedgerCollateral

Claims accumulated hedging rewards for the caller

Calculates total effective hedger collateral (deposits + P&L) across all active positions

*Combines interest rate differential rewards and yield shift rewards*

*Used by vault to determine protocol collateralization ratio*

**Notes:**
- Validates hedger has active positions, updates reward calculations

- Validates hedger exists and has pending rewards

- Resets pending rewards, updates last claim timestamp

- Emits HedgingRewardsClaimed with reward breakdown

- Throws YieldClaimFailed if yield shift claim fails

- Protected by nonReentrant modifier

- Public - any hedger can claim their rewards

- No oracle dependencies for reward claiming

- Read-only helper - no state changes

- Requires valid oracle price

- None - read-only function (not view due to oracle call)

- None

- Reverts if oracle price is invalid

- Not applicable - read-only function

- Public - anyone can query effective collateral

- Requires fresh oracle price data


```solidity
function getTotalEffectiveHedgerCollateral(uint256 currentPrice) external returns (uint256 totalEffectiveCollateral);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currentPrice`|`uint256`|Current EUR/USD oracle price (18 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalEffectiveCollateral`|`uint256`|Total effective collateral in USDC (6 decimals)|


### updateHedgingParameters

Updates core hedging parameters for risk management

*Allows governance to adjust risk parameters based on market conditions*

**Notes:**
- Validates governance role and parameter constraints

- Validates minMarginRatio >= 500, maxLeverage <= 20

- Updates minMarginRatio and maxLeverage state variables

- No events emitted for parameter updates

- Throws ConfigValueTooLow, ConfigValueTooHigh

- Not protected - no external calls

- Restricted to GOVERNANCE_ROLE

- No oracle dependencies for parameter updates


```solidity
function updateHedgingParameters(uint256 newMinMarginRatio, uint256 newMaxLeverage) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMinMarginRatio`|`uint256`|New minimum margin ratio in basis points (e.g., 500 = 5%)|
|`newMaxLeverage`|`uint256`|New maximum leverage multiplier (e.g., 20 = 20x)|


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

### recover

Recovers tokens accidentally sent to the contract

*Emergency function to recover ERC20 tokens that are not part of normal operations*

**Notes:**
- Validates admin role and uses secure recovery library

- No input validation required - library handles validation

- Transfers tokens from contract to treasury

- Emits TokenRecovered or ETHRecovered event

- No errors thrown - library handles error cases

- Not protected - library handles reentrancy

- Restricted to DEFAULT_ADMIN_ROLE

- No oracle dependencies for token recovery


```solidity
function recover(address token, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Address of the token to recover|
|`amount`|`uint256`|Amount of tokens to recover|


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


### hasActiveHedger

Returns whether there is an active hedger with open positions

*Returns true if the single hedger has active positions*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query active hedger status

- No oracle dependencies


```solidity
function hasActiveHedger() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if there is an active hedger|


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
        uint256 filledVolume,
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
|`filledVolume`|`uint256`|Currently matched volume in USDC|
|`margin`|`uint256`|Current margin amount in USDC (6 decimals)|
|`entryPrice`|`uint256`|EUR/USD price when position was opened|
|`leverage`|`uint256`|Leverage multiplier used for the position|
|`entryTime`|`uint256`|Timestamp when position was opened|
|`lastUpdateTime`|`uint256`|Timestamp of last position update|
|`unrealizedPnL`|`int256`|Current unrealized profit or loss|
|`isActive`|`bool`|Whether the position is currently active|


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


### singleHedger

Returns the address of the single hedger

*Returns the address that is authorized to open hedge positions*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query the single hedger address

- No oracle dependencies


```solidity
function singleHedger() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|address The address of the single hedger|


### setSingleHedger

Sets the single hedger address

*Only governance can set the single hedger address*

**Notes:**
- Validates governance role and hedger address

- Validates hedger is not address(0)

- Updates singleHedger state variable

- Emits SingleHedgerUpdated with hedger and caller addresses

- Throws ZeroAddress if hedger is address(0)

- Not protected - no external calls

- Restricted to GOVERNANCE_ROLE

- No oracle dependencies


```solidity
function setSingleHedger(address hedger) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the single hedger|


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

### HedgingRewardsClaimed

```solidity
event HedgingRewardsClaimed(
    address indexed hedger, uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards
);
```

### SingleHedgerUpdated

```solidity
event SingleHedgerUpdated(address indexed hedger, address indexed caller);
```

### HedgerFillUpdated

```solidity
event HedgerFillUpdated(uint256 indexed positionId, uint256 previousFilled, uint256 newFilled);
```

