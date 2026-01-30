# HedgerPool
**Inherits:**
Initializable, ReentrancyGuardUpgradeable, AccessControlUpgradeable, PausableUpgradeable, [SecureUpgradeable](/src/core/SecureUpgradeable.sol/abstract.SecureUpgradeable.md)

**Title:**
HedgerPool

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Optimized EUR/USD hedging pool for managing currency risk and providing yield

Optimized version with reduced contract size through library extraction and code consolidation
P&L Calculation Model:
Hedgers are SHORT EUR (they owe QEURO to users). When EUR/USD price rises, hedgers lose.
1. TOTAL UNREALIZED P&L (mark-to-market of current position):
totalUnrealizedPnL = FilledVolume - (QEUROBacked × OraclePrice / 1e30)
2. NET UNREALIZED P&L (used when margin already reflects realized P&L):
netUnrealizedPnL = totalUnrealizedPnL - realizedPnL
3. EFFECTIVE MARGIN (true economic value):
effectiveMargin = margin + netUnrealizedPnL
4. REALIZED P&L (during partial redemptions):
When users redeem QEURO, a portion of net unrealized P&L is realized.
realizedDelta = (qeuroAmount / qeuroBacked) × netUnrealizedPnL
- If positive (profit): margin increases
- If negative (loss): margin decreases
5. LIQUIDATION MODE (CR ≤ 101%):
In liquidation mode, unrealizedPnL = -margin (all margin at risk).
effectiveMargin = 0, hedger absorbs pro-rata losses on redemptions.

**Note:**
security-contact: team@quantillon.money


## State Variables
### GOVERNANCE_ROLE

```solidity
bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE")
```


### EMERGENCY_ROLE

```solidity
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE")
```


### HEDGER_ROLE

```solidity
bytes32 public constant HEDGER_ROLE = keccak256("HEDGER_ROLE")
```


### usdc

```solidity
IERC20 public usdc
```


### oracle

```solidity
IOracle public oracle
```


### yieldShift

```solidity
IYieldShift public yieldShift
```


### vault

```solidity
IQuantillonVault public vault
```


### treasury

```solidity
address public treasury
```


### TIME_PROVIDER

```solidity
TimeProvider public immutable TIME_PROVIDER
```


### coreParams

```solidity
CoreParams public coreParams
```


### totalMargin

```solidity
uint256 public totalMargin
```


### totalExposure

```solidity
uint256 public totalExposure
```


### totalFilledExposure

```solidity
uint256 public totalFilledExposure
```


### singleHedger
Address of the single hedger allowed to open positions

This replaces the previous multi-hedger whitelist model


```solidity
address public singleHedger
```


### positions

```solidity
mapping(uint256 => HedgePosition) public positions
```


### hedgerRewards

```solidity
mapping(address => HedgerRewardState) private hedgerRewards
```


### hedgerActivePositionId
Maps hedger address to their active position ID (0 = no active position)

Used to track the single hedger's position in single hedger model


```solidity
mapping(address => uint256) private hedgerActivePositionId
```


### hedgerLastRewardBlock

```solidity
mapping(address => uint256) public hedgerLastRewardBlock
```


### MAX_UINT96_VALUE

```solidity
uint96 public constant MAX_UINT96_VALUE = type(uint96).max
```


### MAX_POSITION_SIZE

```solidity
uint256 public constant MAX_POSITION_SIZE = MAX_UINT96_VALUE
```


### MAX_MARGIN

```solidity
uint256 public constant MAX_MARGIN = MAX_UINT96_VALUE
```


### MAX_ENTRY_PRICE

```solidity
uint256 public constant MAX_ENTRY_PRICE = MAX_UINT96_VALUE
```


### MAX_LEVERAGE

```solidity
uint256 public constant MAX_LEVERAGE = type(uint16).max
```


### MAX_MARGIN_RATIO

```solidity
uint256 public constant MAX_MARGIN_RATIO = 5000
```


### DEFAULT_MIN_MARGIN_RATIO_BPS

```solidity
uint256 public constant DEFAULT_MIN_MARGIN_RATIO_BPS = 500
```


### MAX_UINT128_VALUE

```solidity
uint128 public constant MAX_UINT128_VALUE = type(uint128).max
```


### MAX_TOTAL_MARGIN

```solidity
uint256 public constant MAX_TOTAL_MARGIN = MAX_UINT128_VALUE
```


### MAX_TOTAL_EXPOSURE

```solidity
uint256 public constant MAX_TOTAL_EXPOSURE = MAX_UINT128_VALUE
```


### MAX_REWARD_PERIOD

```solidity
uint256 public constant MAX_REWARD_PERIOD = 365 days
```


## Functions
### onlyVault


```solidity
modifier onlyVault() ;
```

### _onlyVault

Reverts if caller is not the vault contract

Used by onlyVault modifier; restricts vault-only callbacks (e.g. realized P&L)

**Notes:**
- security: Access control for vault callbacks

- validation: msg.sender must equal vault

- state-changes: None

- events: None

- errors: OnlyVault if caller not vault

- reentrancy: No external calls

- access: Internal; used by modifier

- oracle: None


```solidity
function _onlyVault() internal view;
```

### constructor

Initializes the HedgerPool contract with a time provider

Constructor that sets up the time provider and disables initializers for upgrade safety

**Notes:**
- security: Validates that the time provider is not zero address

- validation: Ensures TIME_PROVIDER is a valid contract address

- state-changes: Sets TIME_PROVIDER and disables initializers

- events: None

- errors: Throws ZeroAddress if _TIME_PROVIDER is address(0)

- reentrancy: Not applicable - constructor

- access: Public constructor

- oracle: Not applicable


```solidity
constructor(TimeProvider _TIME_PROVIDER) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_TIME_PROVIDER`|`TimeProvider`|The time provider contract for timestamp management|


### initialize

Initializes the HedgerPool with contracts and parameters

This function configures:
1. Access roles and permissions
2. References to external contracts
3. Default protocol parameters
4. Security (pause, reentrancy, upgrades)

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
) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address with administrator privileges|
|`_usdc`|`address`|Address of the USDC token contract|
|`_oracle`|`address`|Address of the Oracle contract|
|`_yieldShift`|`address`|Address of the YieldShift contract|
|`_timelock`|`address`|Address of the timelock contract|
|`_treasury`|`address`|Address of the treasury contract|
|`_vault`|`address`|Address of the QuantillonVault contract|


### enterHedgePosition

Opens a new hedge position for a hedger

Position opening process:
1. Validates hedger whitelist status
2. Fetches current EUR/USD price from oracle
3. Calculates position size and validates parameters
4. Transfers USDC to vault for unified liquidity
5. Creates position record and updates hedger stats

Security features:
1. Flash loan protection via secureNonReentrant
2. Whitelist validation if enabled
3. Parameter validation (leverage, amounts)
4. Oracle price validation

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates amount > 0, leverage within limits, hedger whitelist

- state-changes: Creates new position, updates hedger stats, transfers USDC to vault

- events: Emits HedgePositionOpened with position details

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by secureNonReentrant modifier and proper CEI pattern

- access: Restricted to whitelisted hedgers (if whitelist enabled)

- oracle: Requires fresh oracle price data


```solidity
function enterHedgePosition(uint256 usdcAmount, uint256 leverage)
    external
    whenNotPaused
    nonReentrant
    returns (uint256 positionId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC to deposit as margin (6 decimals)|
|`leverage`|`uint256`|Leverage multiplier for the position (1-20x)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|Unique identifier for the new position|


### exitHedgePosition

Closes an existing hedge position

Position closing process:
1. Validates position ownership and active status
2. Checks protocol collateralization safety
3. Calculates current PnL based on price change
4. Determines net payout to hedger
5. Updates hedger stats and removes position
6. Withdraws USDC from vault for hedger payout

Security features:
1. Position ownership validation
2. Protocol collateralization safety check
3. Pause protection

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates position ownership, active status, and protocol safety

- state-changes: Closes position, updates hedger stats, withdraws USDC from vault

- events: Emits HedgePositionClosed with position details

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by nonReentrant modifier

- access: Restricted to position owner

- oracle: Requires fresh oracle price data


```solidity
function exitHedgePosition(uint256 positionId) external whenNotPaused nonReentrant returns (int256 pnl);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|Unique identifier of the position to close|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`pnl`|`int256`|Profit or loss from the position (positive = profit, negative = loss)|


### addMargin

Adds additional margin to an existing hedge position

Margin addition process:
1. Validates position ownership and active status
2. Validates amount is positive
3. Checks liquidation cooldown and pending liquidation status
4. Transfers USDC from hedger to vault
5. Updates position margin and hedger stats

Security features:
1. Flash loan protection
2. Position ownership validation
3. Liquidation cooldown validation

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates position ownership, active status, positive amount, liquidation cooldown

- state-changes: Updates position margin, hedger stats, transfers USDC to vault

- events: Emits MarginAdded with position details

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by flashLoanProtection modifier

- access: Restricted to position owner

- oracle: No oracle dependencies


```solidity
function addMargin(uint256 positionId, uint256 amount) external whenNotPaused nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|Unique identifier of the position|
|`amount`|`uint256`|Amount of USDC to add as margin (6 decimals)|


### removeMargin

Removes margin from an existing hedge position

Margin removal process:
1. Validates position ownership and active status
2. Validates amount is positive
3. Validates margin operation maintains minimum margin ratio
4. Updates position margin and hedger stats
5. Withdraws USDC from vault to hedger

Security features:
1. Flash loan protection
2. Position ownership validation
3. Minimum margin ratio validation

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates position ownership, active status, positive amount, minimum margin ratio

- state-changes: Updates position margin, hedger stats, withdraws USDC from vault

- events: Emits MarginUpdated with position details

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by flashLoanProtection modifier

- access: Restricted to position owner

- oracle: No oracle dependencies


```solidity
function removeMargin(uint256 positionId, uint256 amount) external whenNotPaused nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|Unique identifier of the position|
|`amount`|`uint256`|Amount of USDC to remove from margin (6 decimals)|


### recordUserMint

Records a user mint and allocates hedger fills proportionally

Callable only by QuantillonVault to sync hedger exposure with user activity

**Notes:**
- security: Only callable by the vault; amount must be positive

- validation: Validates the amount and price are greater than zero

- state-changes: Updates total filled exposure and per-position fills

- events: Emits `HedgerFillUpdated` for every position receiving fill

- errors: Reverts with `InvalidAmount`, `InvalidOraclePrice`, `NoActiveHedgerLiquidity`, or `InsufficientHedgerCapacity`

- reentrancy: Not applicable (no external calls besides trusted helpers)

- access: Restricted to `QuantillonVault`

- oracle: Uses provided price to avoid duplicate oracle calls


```solidity
function recordUserMint(uint256 usdcAmount, uint256 fillPrice, uint256 qeuroAmount)
    external
    onlyVault
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Net USDC amount that was minted into QEURO (6 decimals)|
|`fillPrice`|`uint256`|EUR/USD oracle price (18 decimals) observed by the vault|
|`qeuroAmount`|`uint256`|QEURO amount that was minted (18 decimals)|


### recordUserRedeem

Records a user redemption and releases hedger fills proportionally

Callable only by QuantillonVault to sync hedger exposure with user activity

**Notes:**
- security: Only callable by the vault; amount must be positive

- validation: Validates the amount and price are greater than zero

- state-changes: Reduces total filled exposure and per-position fills

- events: Emits `HedgerFillUpdated` for every position releasing fill

- errors: Reverts with `InvalidAmount`, `InvalidOraclePrice`, or `InsufficientHedgerCapacity`

- reentrancy: Not applicable (no external calls besides trusted helpers)

- access: Restricted to `QuantillonVault`

- oracle: Uses provided price to avoid duplicate oracle calls


```solidity
function recordUserRedeem(uint256 usdcAmount, uint256 redeemPrice, uint256 qeuroAmount)
    external
    onlyVault
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Gross USDC amount redeemed from QEURO burn (6 decimals)|
|`redeemPrice`|`uint256`|EUR/USD oracle price (18 decimals) observed by the vault|
|`qeuroAmount`|`uint256`|QEURO amount that was redeemed (18 decimals)|


### recordLiquidationRedeem

Records a liquidation mode redemption - directly reduces hedger margin proportionally

Called by vault when protocol is in liquidation mode (CR ≤ 101%)
In liquidation mode, the ENTIRE hedger margin is considered at risk (unrealized P&L = -margin).
When users redeem, the hedger absorbs a pro-rata loss:
Formula: hedgerLoss = (qeuroAmount / totalQeuroSupply) × currentMargin
This loss is recorded as realized P&L and reduces the hedger's margin.
The qeuroBacked and filledVolume are also reduced proportionally.

**Notes:**
- security: Vault-only access prevents unauthorized calls

- validation: Validates qeuroAmount > 0, totalQeuroSupply > 0, position exists and is active

- state-changes: Reduces hedger margin, records realized P&L, reduces qeuroBacked and filledVolume

- events: Emits RealizedPnLRecorded

- errors: None (early returns for invalid states)

- reentrancy: Protected by whenNotPaused modifier

- access: Restricted to QuantillonVault via onlyVault modifier

- oracle: No oracle dependency - uses provided parameters


```solidity
function recordLiquidationRedeem(uint256 qeuroAmount, uint256 totalQeuroSupply) external onlyVault whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount of QEURO being redeemed (18 decimals)|
|`totalQeuroSupply`|`uint256`|Total QEURO supply before redemption (18 decimals)|


### claimHedgingRewards

Claims hedging rewards for a hedger

Reward claiming process:
1. Calculates interest differential based on exposure and rates
2. Calculates yield shift rewards from YieldShift contract
3. Updates hedger's last reward block
4. Transfers total rewards to hedger

Security features:
1. Reentrancy protection
2. Reward calculation validation

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates hedger has active positions and rewards available

- state-changes: Updates hedger reward tracking, transfers rewards

- events: Emits HedgingRewardsClaimed with reward details

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by nonReentrant modifier

- access: Restricted to hedgers with active positions

- oracle: No oracle dependencies


```solidity
function claimHedgingRewards()
    external
    nonReentrant
    returns (uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`interestDifferential`|`uint256`|Interest differential rewards earned|
|`yieldShiftRewards`|`uint256`|Yield shift rewards earned|
|`totalRewards`|`uint256`|Total rewards claimed|


### getTotalEffectiveHedgerCollateral

Calculates total effective hedger collateral (margin + P&L) for the hedger position

Used by vault to determine protocol collateralization ratio
Formula breakdown:
1. totalUnrealizedPnL = FilledVolume - (QEUROBacked × price / 1e30)
2. netUnrealizedPnL = totalUnrealizedPnL - realizedPnL
(margin already reflects realized P&L, so we use net unrealized to avoid double-counting)
3. effectiveCollateral = margin + netUnrealizedPnL

**Notes:**
- security: View-only helper - no state changes, safe for external calls

- validation: Validates price > 0, position exists and is active

- state-changes: None - view function

- events: None - view function

- errors: None - returns 0 for invalid states

- reentrancy: Not applicable - view function

- access: Public - anyone can query effective collateral

- oracle: Requires fresh oracle price data


```solidity
function getTotalEffectiveHedgerCollateral(uint256 price) external view returns (uint256 t);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|Current EUR/USD oracle price (18 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`t`|`uint256`|Total effective collateral in USDC (6 decimals)|


### hasActiveHedger

Checks if there is an active hedger with an active position

Returns true if the single hedger has an active position

**Notes:**
- security: View-only helper - no state changes

- validation: None

- state-changes: None - view function

- events: None

- errors: None

- reentrancy: Not applicable - view function

- access: Public - anyone can query

- oracle: Not applicable


```solidity
function hasActiveHedger() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if hedger has an active position, false otherwise|


### updateHedgingParameters

Updates core hedging parameters for risk management

Allows governance to adjust risk parameters based on market conditions

**Notes:**
- security: Validates governance role and parameter constraints

- validation: Validates minRatio >= DEFAULT_MIN_MARGIN_RATIO_BPS, maxLev <= 20

- state-changes: Updates minMarginRatio and maxLeverage state variables

- events: No events emitted for parameter updates

- errors: Throws ConfigValueTooLow, ConfigValueTooHigh

- reentrancy: Not protected - no external calls

- access: Restricted to GOVERNANCE_ROLE

- oracle: No oracle dependencies for parameter updates


```solidity
function updateHedgingParameters(uint256 minRatio, uint256 maxLev) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minRatio`|`uint256`|New minimum margin ratio in basis points (e.g., 500 = 5%)|
|`maxLev`|`uint256`|New maximum leverage multiplier (e.g., 20 = 20x)|


### updateInterestRates

Updates interest rates for EUR and USD

Allows governance to adjust interest rates used for reward calculations

**Notes:**
- security: Validates governance role and rate limits

- validation: Validates eurRate <= 2000 and usdRate <= 2000

- state-changes: Updates coreParams.eurInterestRate and coreParams.usdInterestRate

- events: No events emitted for rate updates

- errors: Throws ConfigValueTooHigh if rates exceed 2000

- reentrancy: Not protected - no external calls

- access: Restricted to GOVERNANCE_ROLE

- oracle: No oracle dependencies


```solidity
function updateInterestRates(uint256 eurRate, uint256 usdRate) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`eurRate`|`uint256`|EUR interest rate in basis points (max 2000 = 20%)|
|`usdRate`|`uint256`|USD interest rate in basis points (max 2000 = 20%)|


### setHedgingFees

Sets hedge position fees (entry, exit, margin)

Allows governance to adjust fee rates for position operations

**Notes:**
- security: Validates governance role and fee limits

- validation: Validates entry <= 100, exit <= 100, margin <= 50

- state-changes: Updates coreParams.entryFee, coreParams.exitFee, coreParams.marginFee

- events: No events emitted for fee updates

- errors: Throws validation errors if fees exceed limits

- reentrancy: Not protected - no external calls

- access: Restricted to GOVERNANCE_ROLE

- oracle: No oracle dependencies


```solidity
function setHedgingFees(uint256 entry, uint256 exit, uint256 margin) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`entry`|`uint256`|Entry fee rate in basis points (max 100 = 1%)|
|`exit`|`uint256`|Exit fee rate in basis points (max 100 = 1%)|
|`margin`|`uint256`|Margin operation fee rate in basis points (max 50 = 0.5%)|


### emergencyClosePosition

Emergency closure of a hedge position by governance

Emergency closure process:
1. Validates emergency role and position ownership
2. Validates position is active
3. Updates hedger stats and removes position
4. Withdraws USDC from vault for hedger's margin

Security features:
1. Role-based access control (EMERGENCY_ROLE)
2. Position ownership validation

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates emergency role, position ownership, active status

- state-changes: Closes position, updates hedger stats, withdraws USDC from vault

- events: Emits EmergencyPositionClosed with position details

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by nonReentrant modifier

- access: Restricted to EMERGENCY_ROLE

- oracle: Requires oracle price for _unwindFilledVolume


```solidity
function emergencyClosePosition(address hedger, uint256 positionId) external nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger whose position to close|
|`positionId`|`uint256`|Unique identifier of the position to close|


### pause

Pauses all contract operations in case of emergency

Emergency function to halt all user interactions

**Notes:**
- security: Requires EMERGENCY_ROLE

- validation: None required

- state-changes: Sets contract to paused state

- events: Emits Paused event

- errors: Throws InvalidRole if caller lacks EMERGENCY_ROLE

- reentrancy: Not applicable

- access: Restricted to EMERGENCY_ROLE

- oracle: Not applicable


```solidity
function pause() external;
```

### unpause

Unpauses all contract operations after emergency pause

Emergency function to resume all user interactions

**Notes:**
- security: Requires EMERGENCY_ROLE

- validation: None required

- state-changes: Sets contract to unpaused state

- events: Emits Unpaused event

- errors: Throws InvalidRole if caller lacks EMERGENCY_ROLE

- reentrancy: Not applicable

- access: Restricted to EMERGENCY_ROLE

- oracle: Not applicable


```solidity
function unpause() external;
```

### recover

Recovers tokens (token != 0) or ETH (token == 0) to treasury

Emergency function to recover accidentally sent tokens or ETH

**Notes:**
- security: Requires DEFAULT_ADMIN_ROLE

- validation: Validates treasury address is set

- state-changes: Transfers tokens/ETH to treasury

- events: None

- errors: Throws InvalidRole if caller lacks DEFAULT_ADMIN_ROLE

- reentrancy: Protected by AdminFunctionsLibrary

- access: Restricted to DEFAULT_ADMIN_ROLE

- oracle: Not applicable


```solidity
function recover(address token, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Address of token to recover (address(0) for ETH)|
|`amount`|`uint256`|Amount of tokens to recover (0 for all ETH)|


### updateAddress

Updates contract addresses (0=treasury, 1=vault, 2=oracle, 3=yieldShift)

Allows governance to update critical contract addresses

**Notes:**
- security: Validates governance role and non-zero address

- validation: Validates slot is valid (0-3) and addr != address(0)

- state-changes: Updates treasury, vault, oracle, or yieldShift address

- events: Emits TreasuryUpdated or VaultUpdated for slots 0 and 1

- errors: Throws ZeroAddress if addr is zero, InvalidPosition if slot is invalid

- reentrancy: Not protected - no external calls

- access: Restricted to GOVERNANCE_ROLE

- oracle: Updates oracle address if slot == 2


```solidity
function updateAddress(uint8 slot, address addr) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`slot`|`uint8`|Address slot to update (0=treasury, 1=vault, 2=oracle, 3=yieldShift)|
|`addr`|`address`|New address for the slot|


### setSingleHedger

Sets the single hedger address allowed to open positions

Replaces the previous multi-hedger whitelist model with a single hedger

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates governance role and non-zero hedger address

- state-changes: Updates singleHedger address

- events: None

- errors: Throws ZeroAddress if hedger is zero

- reentrancy: Not protected - governance function

- access: Restricted to GOVERNANCE_ROLE

- oracle: No oracle dependencies


```solidity
function setSingleHedger(address hedger) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the single hedger|


### _getValidOraclePrice

Gets a valid EUR/USD price from the oracle

Internal function to fetch and validate oracle price

**Notes:**
- security: Validates oracle price is valid

- validation: Validates oracle price is valid

- state-changes: No state changes

- events: No events emitted

- errors: Throws InvalidOraclePrice if price is invalid

- reentrancy: Not protected - internal function

- access: Internal function - no access restrictions

- oracle: Requires fresh oracle price data


```solidity
function _getValidOraclePrice() internal returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|price Valid EUR/USD price from oracle|


### _validateRole

Validates that the caller has the required role

Internal function to check role-based access control

**Notes:**
- security: Validates caller has the specified role

- validation: Checks role against AccessControlLibrary

- state-changes: None (view function)

- events: None

- errors: Throws InvalidRole if caller lacks required role

- reentrancy: Not applicable - view function

- access: Internal function

- oracle: Not applicable


```solidity
function _validateRole(bytes32 role) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to validate against|


### _finalizePosition

Removes a position from the hedger's position arrays

Finalizes position closure by updating hedger and protocol totals

Internal function to maintain position tracking arrays

Internal helper to clean up position state and update aggregate statistics

**Notes:**
- security: Validates position exists before removal

- validation: Ensures position exists in hedger's array

- state-changes: Removes position from arrays and updates indices

- events: None

- errors: Throws PositionNotFound if position doesn't exist

- reentrancy: Not applicable - internal function

- access: Internal function

- oracle: Not applicable

- security: Internal function - assumes all validations done by caller

- validation: Assumes marginDelta and exposureDelta are valid and don't exceed current totals

- state-changes: Decrements hedger margin/exposure, protocol totals, marks position inactive, updates hedger position tracking

- events: None - events emitted by caller

- errors: None - assumes valid inputs from caller

- reentrancy: Not applicable - internal function, no external calls

- access: Internal - only callable within contract

- oracle: Not applicable


```solidity
function _finalizePosition(
    address hedger,
    uint256 positionId,
    HedgePosition storage position,
    uint256 marginDelta,
    uint256 exposureDelta
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger whose position to remove|
|`positionId`|`uint256`|ID of the position to remove|
|`position`|`HedgePosition`|Storage reference to the position being finalized|
|`marginDelta`|`uint256`|Amount of margin being removed from the position|
|`exposureDelta`|`uint256`|Amount of exposure being removed from the position|


### _unwindFilledVolume

Unwinds filled volume from a position

Clears position's filled volume (no redistribution needed with single position)

**Notes:**
- security: Internal function - assumes position is valid and active

- validation: Validates totalFilledExposure >= cachedFilledVolume before decrementing

- state-changes: Clears position filledVolume, decrements totalFilledExposure

- events: Emits HedgerFillUpdated with positionId, old filled volume, and 0

- errors: Reverts with InsufficientHedgerCapacity if totalFilledExposure < cachedFilledVolume

- reentrancy: Protected by nonReentrant on all public entry points

- access: Internal - only callable within contract

- oracle: Requires fresh oracle price data


```solidity
function _unwindFilledVolume(uint256 positionId, HedgePosition storage position, uint256 cachedPrice)
    internal
    returns (uint256 freedVolume);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|Unique identifier of the position being unwound|
|`position`|`HedgePosition`|Storage reference to the position being unwound|
|`cachedPrice`|`uint256`|Cached EUR/USD price to avoid reentrancy (18 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`freedVolume`|`uint256`|Amount of filled volume that was freed and redistributed|


### _isPositionHealthyForFill

Checks if position is healthy enough for new fills

Validates position has sufficient margin ratio after considering unrealized P&L

**Notes:**
- security: Internal function - validates position health

- validation: Checks effective margin > 0 and margin ratio >= minMarginRatio

- state-changes: None - view function

- events: None

- errors: None

- reentrancy: Not applicable - view function

- access: Internal helper only

- oracle: Uses provided price parameter


```solidity
function _isPositionHealthyForFill(HedgePosition storage p, uint256 price) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`p`|`HedgePosition`|Storage pointer to the position struct|
|`price`|`uint256`|Current EUR/USD oracle price (18 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if position is healthy and can accept new fills|


### _increaseFilledVolume

Allocates user mint exposure to the hedger position

Allocates `usdcAmount` to the single hedger position if healthy

**Notes:**
- security: Caller must ensure hedger position exists

- validation: Validates liquidity availability and capacity before allocation

- state-changes: Updates `filledVolume` and `totalFilledExposure`

- events: Emits `HedgerFillUpdated` for the position

- errors: Reverts if capacity is insufficient or liquidity is absent

- reentrancy: Not applicable - internal function

- access: Internal helper

- oracle: Requires current oracle price to check position health


```solidity
function _increaseFilledVolume(uint256 usdcAmount, uint256 currentPrice, uint256 qeuroAmount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC exposure to allocate (6 decimals)|
|`currentPrice`|`uint256`|Current EUR/USD oracle price supplied by the caller (18 decimals)|
|`qeuroAmount`|`uint256`|QEURO amount that was minted (18 decimals)|


### _decreaseFilledVolume

Releases exposure from the hedger position following a user redeem

Decreases fills from the single hedger position

**Notes:**
- security: Internal function - validates price and amounts

- validation: Validates usdcAmount > 0, redeemPrice > 0, and sufficient filled exposure

- state-changes: Decreases filledVolume, updates totalFilledExposure, calculates realized P&L

- events: Emits HedgerFillUpdated and RealizedPnLRecorded

- errors: Reverts with InvalidOraclePrice, NoActiveHedgerLiquidity, or InsufficientHedgerCapacity

- reentrancy: Not applicable - internal function

- access: Internal helper only

- oracle: Uses provided redeemPrice parameter


```solidity
function _decreaseFilledVolume(uint256 usdcAmount, uint256 redeemPrice, uint256 qeuroAmount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC to release (at redeem price) (6 decimals)|
|`redeemPrice`|`uint256`|Current EUR/USD oracle price (18 decimals) for P&L calculation|
|`qeuroAmount`|`uint256`|QEURO amount that was redeemed (18 decimals)|


### _applyFillChange

Applies a fill delta to a single position and emits an event

Handles both increases and decreases while enforcing capacity constraints

**Notes:**
- security: Caller must ensure the storage reference is valid

- validation: Validates capacity or availability before applying the delta

- state-changes: Updates the position’s `filledVolume`

- events: Emits `HedgerFillUpdated`

- errors: Reverts with `InsufficientHedgerCapacity` on invalid operations

- reentrancy: Not applicable - internal function

- access: Internal helper

- oracle: Not applicable


```solidity
function _applyFillChange(uint256 positionId, HedgePosition storage position, uint256 delta, bool increase)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|ID of the position being updated|
|`position`|`HedgePosition`|Storage pointer to the position struct|
|`delta`|`uint256`|Amount of fill change to apply|
|`increase`|`bool`|True to increase fill, false to decrease|


### _updateEntryPriceAfterFill

Updates weighted-average entry price after new fills

Calculates new weighted average entry price when position receives new fills

**Notes:**
- security: Internal function - validates price is valid

- validation: Validates price > 0 and price <= type(uint96).max

- state-changes: Updates pos.entryPrice with weighted average

- events: None

- errors: Throws InvalidOraclePrice if price is invalid

- reentrancy: Not applicable - internal function

- access: Internal helper only

- oracle: Uses provided price parameter


```solidity
function _updateEntryPriceAfterFill(HedgePosition storage pos, uint256 prevFilled, uint256 delta, uint256 price)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pos`|`HedgePosition`|Storage pointer to the position struct|
|`prevFilled`|`uint256`|Previous filled volume before the new fill|
|`delta`|`uint256`|Amount of new fill being added|
|`price`|`uint256`|Current EUR/USD oracle price for the new fill (18 decimals)|


### _processRedeem

Processes redemption for a single position - calculates realized P&L

Calculates and records realized P&L during QEURO redemption

New formula: RealizedP&L = QEUROQuantitySold * (entryPrice - OracleCurrentPrice)
Hedgers are SHORT EUR, so they profit when EUR price decreases

Called by _decreaseFilledVolume for normal (non-liquidation) redemptions
P&L Calculation Formula:
1. totalUnrealizedPnL = filledVolume - (qeuroBacked × price / 1e30)
2. netUnrealizedPnL = totalUnrealizedPnL - realizedPnL
(avoids double-counting since margin already reflects realized P&L)
3. realizedDelta = (qeuroAmount / qeuroBacked) × netUnrealizedPnL
After calculation:
- If realizedDelta > 0 (profit): margin increases
- If realizedDelta < 0 (loss): margin decreases
- realizedPnL accumulates the realized portion

**Notes:**
- security: Internal function - calculates and records realized P&L

- validation: Validates entry price > 0 and qeuroAmount > 0

- state-changes: Updates pos.realizedPnL and decreases filled volume

- events: Emits RealizedPnLRecorded and HedgerFillUpdated

- errors: None

- reentrancy: Not applicable - internal function

- access: Internal helper only

- oracle: Uses provided price parameter

- security: Internal function - updates position state and margin

- validation: Validates share > 0, qeuroAmount > 0, price > 0, qeuroBacked > 0

- state-changes: Updates pos.realizedPnL, pos.margin, totalMargin, pos.positionSize

- events: Emits RealizedPnLRecorded, RealizedPnLCalculation, MarginUpdated, HedgerFillUpdated

- errors: None - early returns for invalid states

- reentrancy: Not applicable - internal function, no external calls

- access: Internal helper only - called by _decreaseFilledVolume

- oracle: Uses provided price parameter (must be fresh oracle data)


```solidity
function _processRedeem(
    uint256 posId,
    HedgePosition storage pos,
    uint256 share,
    uint256 filledBefore,
    uint256 price,
    uint256 qeuroAmount
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`posId`|`uint256`|ID of the position being processed|
|`pos`|`HedgePosition`|Storage pointer to the position struct|
|`share`|`uint256`|Amount of USDC exposure being released (6 decimals)|
|`filledBefore`|`uint256`|Filled volume before redemption (used for P&L calculation)|
|`price`|`uint256`|Current EUR/USD oracle price for redemption (18 decimals)|
|`qeuroAmount`|`uint256`|QEURO amount being redeemed (18 decimals)|


### _calculateRedeemPnL

Calculates unrealized and realized P&L for redemption

Mark-to-market total unrealized P&L, subtract previous realized, then pro-rata share for qeuroAmount

**Notes:**
- security: Pure math; no external calls

- validation: Caller must pass consistent position data

- state-changes: None (pure)

- events: None

- errors: None

- reentrancy: N/A pure

- access: Internal

- oracle: Price passed in; no live oracle call


```solidity
function _calculateRedeemPnL(
    uint256 currentQeuroBacked,
    uint256 filledBefore,
    uint256 price,
    uint256 qeuroAmount,
    int128 previousRealizedPnL
) internal pure returns (int256 totalUnrealizedPnL, int256 realizedDelta);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currentQeuroBacked`|`uint256`|Current QEURO backed by position|
|`filledBefore`|`uint256`|Filled volume before redemption|
|`price`|`uint256`|Current EUR/USD price|
|`qeuroAmount`|`uint256`|Amount of QEURO being redeemed|
|`previousRealizedPnL`|`int128`|Previously realized P&L|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalUnrealizedPnL`|`int256`|Total unrealized P&L (mark-to-market)|
|`realizedDelta`|`int256`|Realized P&L delta for this redemption|


### _applyRealizedPnLToMargin

Applies realized P&L to position margin

Delegates to _applyProfitToMargin or _applyLossToMargin based on sign of realizedDelta

**Notes:**
- security: Internal; updates margin and totalMargin

- validation: Sign of realizedDelta determines path

- state-changes: pos.margin, totalMargin, positionSize; may emit MarginUpdated

- events: MarginUpdated via _applyProfitToMargin/_applyLossToMargin

- errors: None

- reentrancy: No external calls

- access: Internal

- oracle: None


```solidity
function _applyRealizedPnLToMargin(uint256 posId, HedgePosition storage pos, int256 realizedDelta) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`posId`|`uint256`|Position ID|
|`pos`|`HedgePosition`|Position storage reference|
|`realizedDelta`|`int256`|Realized P&L amount (positive = profit, negative = loss)|


### _applyProfitToMargin

Applies profit to hedger margin

Increases pos.margin and totalMargin; caps at uint96.max; updates positionSize and emits MarginUpdated

**Notes:**
- security: Margin capped at type(uint96).max

- validation: realizedDelta > 0 assumed by caller

- state-changes: pos.margin, totalMargin, pos.positionSize

- events: MarginUpdated

- errors: None

- reentrancy: No external calls

- access: Internal

- oracle: None


```solidity
function _applyProfitToMargin(uint256 posId, HedgePosition storage pos, int256 realizedDelta) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`posId`|`uint256`|Position ID|
|`pos`|`HedgePosition`|Position storage reference|
|`realizedDelta`|`int256`|Positive realized P&L amount|


### _applyLossToMargin

Applies loss to hedger margin

Decreases pos.margin and totalMargin; margin never goes below zero; may zero positionSize

**Notes:**
- security: Margin floor at zero

- validation: realizedDelta < 0 assumed by caller

- state-changes: pos.margin, totalMargin, pos.positionSize

- events: MarginUpdated

- errors: None

- reentrancy: No external calls

- access: Internal

- oracle: None


```solidity
function _applyLossToMargin(uint256 posId, HedgePosition storage pos, int256 realizedDelta) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`posId`|`uint256`|Position ID|
|`pos`|`HedgePosition`|Position storage reference|
|`realizedDelta`|`int256`|Negative realized P&L amount|


### _updatePositionSize

Updates position size based on current margin and leverage

positionSize = margin * leverage; capped at type(uint96).max

**Notes:**
- security: Caps positionSize at uint96.max

- validation: Uses current pos.margin and pos.leverage

- state-changes: pos.positionSize

- events: None

- errors: None

- reentrancy: No external calls

- access: Internal

- oracle: None


```solidity
function _updatePositionSize(HedgePosition storage pos) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pos`|`HedgePosition`|Position storage reference|


### _calculateMarginRatio

Calculates margin ratio for a position

(margin * 10000) / positionSize in basis points; 0 if margin or positionSize is 0

**Notes:**
- security: View only

- validation: Division by zero avoided by early return

- state-changes: None

- events: None

- errors: None

- reentrancy: No external calls

- access: Internal

- oracle: None


```solidity
function _calculateMarginRatio(HedgePosition storage pos) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pos`|`HedgePosition`|Position storage reference|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Margin ratio in basis points (0 if position has no size)|


### _validatePositionClosureSafety

Validates that closing a position won't cause protocol undercollateralization

Checks if protocol remains collateralized after removing this position's margin

**Notes:**
- security: Internal function - prevents protocol undercollateralization from position closures

- validation: Checks vault is set, protocol is collateralized, and remaining margin > positionMargin

- state-changes: None - view function

- events: None

- errors: Reverts with PositionClosureRestricted if closing would cause undercollateralization

- reentrancy: Not applicable - view function, no state changes

- access: Internal - only callable within contract

- oracle: Not applicable - uses vault's collateralization check


```solidity
function _validatePositionClosureSafety(uint256 positionMargin) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionMargin`|`uint256`|Amount of margin in the position being closed|


## Events
### HedgePositionOpened

```solidity
event HedgePositionOpened(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
```

### HedgePositionClosed

```solidity
event HedgePositionClosed(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
```

### MarginUpdated

```solidity
event MarginUpdated(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
```

### HedgingRewardsClaimed

```solidity
event HedgingRewardsClaimed(address indexed hedger, bytes32 packedData);
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

### ETHRecovered

```solidity
event ETHRecovered(address indexed to, uint256 indexed amount);
```

### TreasuryUpdated

```solidity
event TreasuryUpdated(address indexed treasury);
```

### VaultUpdated

```solidity
event VaultUpdated(address indexed vault);
```

### HedgerFillUpdated

```solidity
event HedgerFillUpdated(uint256 indexed positionId, uint256 previousFilled, uint256 newFilled);
```

### RealizedPnLRecorded

```solidity
event RealizedPnLRecorded(uint256 indexed positionId, int256 pnlDelta, int256 totalRealizedPnL);
```

### QeuroShareCalculated

```solidity
event QeuroShareCalculated(
    uint256 indexed positionId, uint256 qeuroShare, uint256 qeuroBacked, uint256 totalQeuroBacked
);
```

### RealizedPnLCalculation

```solidity
event RealizedPnLCalculation(
    uint256 indexed positionId,
    uint256 qeuroAmount,
    uint256 qeuroBacked,
    uint256 filledBefore,
    uint256 price,
    int256 totalUnrealizedPnL,
    int256 realizedDelta
);
```

## Structs
### CoreParams

```solidity
struct CoreParams {
    uint64 minMarginRatio;
    uint16 maxLeverage;
    uint16 entryFee;
    uint16 exitFee;
    uint16 marginFee;
    uint16 eurInterestRate;
    uint16 usdInterestRate;
    uint8 reserved;
}
```

### HedgePosition

```solidity
struct HedgePosition {
    address hedger;
    uint96 positionSize;
    uint96 filledVolume;
    uint96 margin;
    uint96 entryPrice;
    uint32 entryTime;
    uint32 lastUpdateTime;
    int128 unrealizedPnL;
    int128 realizedPnL; // Cumulative realized P&L from closed portions
    uint16 leverage;
    bool isActive;
    uint128 qeuroBacked; // Exact QEURO amount backed by this position (18 decimals)
}
```

### HedgerRewardState

```solidity
struct HedgerRewardState {
    uint128 pendingRewards;
    uint64 lastRewardClaim;
}
```

