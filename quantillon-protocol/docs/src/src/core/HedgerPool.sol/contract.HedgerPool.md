# HedgerPool
**Inherits:**
Initializable, ReentrancyGuardUpgradeable, AccessControlUpgradeable, PausableUpgradeable, [SecureUpgradeable](/src/core/SecureUpgradeable.sol/abstract.SecureUpgradeable.md)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Optimized EUR/USD hedging pool for managing currency risk and providing yield

*Optimized version with reduced contract size through library extraction and code consolidation*

**Note:**
team@quantillon.money


## State Variables
### GOVERNANCE_ROLE

```solidity
bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
```


### LIQUIDATOR_ROLE

```solidity
bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
```


### EMERGENCY_ROLE

```solidity
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
```


### HEDGER_ROLE

```solidity
bytes32 public constant HEDGER_ROLE = keccak256("HEDGER_ROLE");
```


### usdc

```solidity
IERC20 public usdc;
```


### oracle

```solidity
IChainlinkOracle public oracle;
```


### yieldShift

```solidity
IYieldShift public yieldShift;
```


### vault

```solidity
IQuantillonVault public vault;
```


### treasury

```solidity
address public treasury;
```


### TIME_PROVIDER

```solidity
TimeProvider public immutable TIME_PROVIDER;
```


### coreParams

```solidity
CoreParams public coreParams;
```


### totalMargin

```solidity
uint256 public totalMargin;
```


### totalExposure

```solidity
uint256 public totalExposure;
```


### totalFilledExposure

```solidity
uint256 public totalFilledExposure;
```


### activeHedgers

```solidity
uint256 public activeHedgers;
```


### nextPositionId

```solidity
uint256 public nextPositionId;
```


### isWhitelistedHedger

```solidity
mapping(address => bool) public isWhitelistedHedger;
```


### hedgerWhitelistEnabled

```solidity
bool public hedgerWhitelistEnabled;
```


### positions

```solidity
mapping(uint256 => HedgePosition) public positions;
```


### hedgerBalances

```solidity
mapping(address => HedgerBalance) private hedgerBalances;
```


### hedgerRewards

```solidity
mapping(address => HedgerRewardState) private hedgerRewards;
```


### hedgerPositionCounts

```solidity
mapping(address => uint256) private hedgerPositionCounts;
```


### liquidationCommitments

```solidity
mapping(bytes32 => uint256) private liquidationCommitments;
```


### pendingLiquidations

```solidity
mapping(address => mapping(uint256 => uint32)) private pendingLiquidations;
```


### activePositions

```solidity
uint256[] private activePositions;
```


### activePositionIndex

```solidity
mapping(uint256 => uint256) private activePositionIndex;
```


### lastLiquidationAttempt

```solidity
mapping(address => uint256) public lastLiquidationAttempt;
```


### hedgerLastRewardBlock

```solidity
mapping(address => uint256) public hedgerLastRewardBlock;
```


### MAX_POSITIONS_PER_HEDGER

```solidity
uint256 public constant MAX_POSITIONS_PER_HEDGER = 50;
```


### MAX_UINT96_VALUE

```solidity
uint96 public constant MAX_UINT96_VALUE = type(uint96).max;
```


### MAX_POSITION_SIZE

```solidity
uint256 public constant MAX_POSITION_SIZE = MAX_UINT96_VALUE;
```


### MAX_MARGIN

```solidity
uint256 public constant MAX_MARGIN = MAX_UINT96_VALUE;
```


### MAX_ENTRY_PRICE

```solidity
uint256 public constant MAX_ENTRY_PRICE = MAX_UINT96_VALUE;
```


### MAX_LEVERAGE

```solidity
uint256 public constant MAX_LEVERAGE = type(uint16).max;
```


### MAX_MARGIN_RATIO

```solidity
uint256 public constant MAX_MARGIN_RATIO = 5000;
```


### MAX_UINT128_VALUE

```solidity
uint128 public constant MAX_UINT128_VALUE = type(uint128).max;
```


### MAX_TOTAL_MARGIN

```solidity
uint256 public constant MAX_TOTAL_MARGIN = MAX_UINT128_VALUE;
```


### MAX_TOTAL_EXPOSURE

```solidity
uint256 public constant MAX_TOTAL_EXPOSURE = MAX_UINT128_VALUE;
```


### LIQUIDATION_COOLDOWN

```solidity
uint256 public constant LIQUIDATION_COOLDOWN = 300;
```


### MAX_REWARD_PERIOD

```solidity
uint256 public constant MAX_REWARD_PERIOD = 365 days;
```


## Functions
### onlyVault


```solidity
modifier onlyVault();
```

### constructor

Initializes the HedgerPool contract with a time provider

*Constructor that sets up the time provider and disables initializers for upgrade safety*

**Notes:**
- Validates that the time provider is not zero address

- Ensures TIME_PROVIDER is a valid contract address

- Sets TIME_PROVIDER and disables initializers

- None

- Throws ZeroAddress if _TIME_PROVIDER is address(0)

- Not applicable - constructor

- Public constructor

- Not applicable


```solidity
constructor(TimeProvider _TIME_PROVIDER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_TIME_PROVIDER`|`TimeProvider`|The time provider contract for timestamp management|


### initialize

Initializes the HedgerPool with contracts and parameters

*This function configures:
1. Access roles and permissions
2. References to external contracts
3. Default protocol parameters
4. Security (pause, reentrancy, upgrades)*

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

*Position opening process:
1. Validates hedger whitelist status
2. Fetches current EUR/USD price from oracle
3. Calculates position size and validates parameters
4. Transfers USDC to vault for unified liquidity
5. Creates position record and updates hedger stats*

*Security features:
1. Flash loan protection via secureNonReentrant
2. Whitelist validation if enabled
3. Parameter validation (leverage, amounts)
4. Oracle price validation*

**Notes:**
- Validates input parameters and enforces security checks

- Validates amount > 0, leverage within limits, hedger whitelist

- Creates new position, updates hedger stats, transfers USDC to vault

- Emits HedgePositionOpened with position details

- Throws custom errors for invalid conditions

- Protected by secureNonReentrant modifier and proper CEI pattern

- Restricted to whitelisted hedgers (if whitelist enabled)

- Requires fresh oracle price data


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

*Position closing process:
1. Validates position ownership and active status
2. Checks protocol collateralization safety
3. Calculates current PnL based on price change
4. Determines net payout to hedger
5. Updates hedger stats and removes position
6. Withdraws USDC from vault for hedger payout*

*Security features:
1. Position ownership validation
2. Protocol collateralization safety check
3. Pause protection*

**Notes:**
- Validates input parameters and enforces security checks

- Validates position ownership, active status, and protocol safety

- Closes position, updates hedger stats, withdraws USDC from vault

- Emits HedgePositionClosed with position details

- Throws custom errors for invalid conditions

- Protected by nonReentrant modifier

- Restricted to position owner

- Requires fresh oracle price data


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

*Margin addition process:
1. Validates position ownership and active status
2. Validates amount is positive
3. Checks liquidation cooldown and pending liquidation status
4. Transfers USDC from hedger to vault
5. Updates position margin and hedger stats*

*Security features:
1. Flash loan protection
2. Position ownership validation
3. Liquidation cooldown validation*

**Notes:**
- Validates input parameters and enforces security checks

- Validates position ownership, active status, positive amount, liquidation cooldown

- Updates position margin, hedger stats, transfers USDC to vault

- Emits MarginAdded with position details

- Throws custom errors for invalid conditions

- Protected by flashLoanProtection modifier

- Restricted to position owner

- No oracle dependencies


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

*Margin removal process:
1. Validates position ownership and active status
2. Validates amount is positive
3. Validates margin operation maintains minimum margin ratio
4. Updates position margin and hedger stats
5. Withdraws USDC from vault to hedger*

*Security features:
1. Flash loan protection
2. Position ownership validation
3. Minimum margin ratio validation*

**Notes:**
- Validates input parameters and enforces security checks

- Validates position ownership, active status, positive amount, minimum margin ratio

- Updates position margin, hedger stats, withdraws USDC from vault

- Emits MarginUpdated with position details

- Throws custom errors for invalid conditions

- Protected by flashLoanProtection modifier

- Restricted to position owner

- No oracle dependencies


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

*Callable only by QuantillonVault to sync hedger exposure with user activity*

**Notes:**
- Only callable by the vault; amount must be positive

- Validates the amount and price are greater than zero

- Updates total filled exposure and per-position fills

- Emits `HedgerFillUpdated` for every position receiving fill

- Reverts with `InvalidAmount`, `InvalidOraclePrice`, `NoActiveHedgerLiquidity`, or `InsufficientHedgerCapacity`

- Not applicable (no external calls besides trusted helpers)

- Restricted to `QuantillonVault`

- Uses provided price to avoid duplicate oracle calls


```solidity
function recordUserMint(uint256 usdcAmount, uint256 fillPrice, uint256 qeuroAmount) external onlyVault whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Net USDC amount that was minted into QEURO (6 decimals)|
|`fillPrice`|`uint256`|EUR/USD oracle price (18 decimals) observed by the vault|
|`qeuroAmount`|`uint256`|QEURO amount that was minted (18 decimals)|


### recordUserRedeem

Records a user redemption and releases hedger fills proportionally

*Callable only by QuantillonVault to sync hedger exposure with user activity*

**Notes:**
- Only callable by the vault; amount must be positive

- Validates the amount and price are greater than zero

- Reduces total filled exposure and per-position fills

- Emits `HedgerFillUpdated` for every position releasing fill

- Reverts with `InvalidAmount`, `InvalidOraclePrice`, or `InsufficientHedgerCapacity`

- Not applicable (no external calls besides trusted helpers)

- Restricted to `QuantillonVault`

- Uses provided price to avoid duplicate oracle calls


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


### commitLiquidation

Commits to liquidating a position (first step of two-phase liquidation)

*Creates a commitment hash to prevent front-running of liquidation attempts*

**Notes:**
- Requires LIQUIDATOR_ROLE, validates position ownership and active status

- Validates hedger address, position ID, position is active, hedger matches position owner

- Creates liquidation commitment, increments pending liquidation count, updates last liquidation attempt

- None - commitment phase doesn't emit events

- Reverts with InvalidPosition if positionId is 0, InvalidHedger if hedger doesn't match, or if commitment already exists

- Protected by secureNonReentrant modifier (if called externally)

- Restricted to LIQUIDATOR_ROLE

- Not applicable - commitment phase doesn't require oracle


```solidity
function commitLiquidation(address hedger, uint256 positionId, bytes32 salt) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger whose position will be liquidated|
|`positionId`|`uint256`|Unique identifier of the position to liquidate|
|`salt`|`bytes32`|Random salt value to prevent commitment collisions|


### liquidateHedger

Liquidates an undercollateralized hedge position

*Liquidation process:
1. Validates liquidator role and commitment
2. Validates position ownership and active status
3. Calculates liquidation reward and remaining margin
4. Updates hedger stats and removes position
5. Withdraws USDC from vault for liquidator reward and remaining margin*

*Security features:
1. Role-based access control (LIQUIDATOR_ROLE)
2. Commitment validation to prevent front-running
3. Reentrancy protection*

**Notes:**
- Validates input parameters and enforces security checks

- Validates liquidator role, commitment, position ownership, active status

- Liquidates position, updates hedger stats, withdraws USDC from vault

- Emits HedgerLiquidated with liquidation details

- Throws custom errors for invalid conditions

- Protected by nonReentrant modifier

- Restricted to LIQUIDATOR_ROLE

- Requires fresh oracle price data


```solidity
function liquidateHedger(address hedger, uint256 positionId, bytes32 salt)
    external
    nonReentrant
    returns (uint256 liquidationReward);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger to liquidate|
|`positionId`|`uint256`|Unique identifier of the position to liquidate|
|`salt`|`bytes32`|Random salt for commitment validation|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`liquidationReward`|`uint256`|Amount of USDC reward for the liquidator|


### claimHedgingRewards

Claims hedging rewards for a hedger

*Reward claiming process:
1. Calculates interest differential based on exposure and rates
2. Calculates yield shift rewards from YieldShift contract
3. Updates hedger's last reward block
4. Transfers total rewards to hedger*

*Security features:
1. Reentrancy protection
2. Reward calculation validation*

**Notes:**
- Validates input parameters and enforces security checks

- Validates hedger has active positions and rewards available

- Updates hedger reward tracking, transfers rewards

- Emits HedgingRewardsClaimed with reward details

- Throws custom errors for invalid conditions

- Protected by nonReentrant modifier

- Restricted to hedgers with active positions

- No oracle dependencies


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

Calculates total effective hedger collateral (margin + P&L) across all active positions

*Used by vault to determine protocol collateralization ratio*

**Notes:**
- View-only helper - no state changes

- Requires valid oracle price

- None - view function

- None

- Reverts if oracle price is invalid

- Not applicable - view function

- Public - anyone can query effective collateral

- Requires fresh oracle price data


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


### updateHedgingParameters

Updates core hedging parameters for risk management

*Allows governance to adjust risk parameters based on market conditions*

**Notes:**
- Validates governance role and parameter constraints

- Validates minRatio >= 500, liqThreshold < minRatio, maxLev <= 20, liqPenalty <= 1000

- Updates all hedging parameter state variables

- No events emitted for parameter updates

- Throws ConfigValueTooLow, ConfigInvalid, ConfigValueTooHigh

- Not protected - no external calls

- Restricted to GOVERNANCE_ROLE

- No oracle dependencies for parameter updates


```solidity
function updateHedgingParameters(uint256 minRatio, uint256 liqThreshold, uint256 maxLev, uint256 liqPenalty) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minRatio`|`uint256`|New minimum margin ratio in basis points (e.g., 500 = 5%)|
|`liqThreshold`|`uint256`|New liquidation threshold in basis points (e.g., 100 = 1%)|
|`maxLev`|`uint256`|New maximum leverage multiplier (e.g., 20 = 20x)|
|`liqPenalty`|`uint256`|New liquidation penalty in basis points (e.g., 200 = 2%)|


### updateInterestRates

Updates interest rates for EUR and USD

*Allows governance to adjust interest rates used for reward calculations*

**Notes:**
- Validates governance role and rate limits

- Validates eurRate <= 2000 and usdRate <= 2000

- Updates coreParams.eurInterestRate and coreParams.usdInterestRate

- No events emitted for rate updates

- Throws ConfigValueTooHigh if rates exceed 2000

- Not protected - no external calls

- Restricted to GOVERNANCE_ROLE

- No oracle dependencies


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

*Allows governance to adjust fee rates for position operations*

**Notes:**
- Validates governance role and fee limits

- Validates entry <= 100, exit <= 100, margin <= 50

- Updates coreParams.entryFee, coreParams.exitFee, coreParams.marginFee

- No events emitted for fee updates

- Throws validation errors if fees exceed limits

- Not protected - no external calls

- Restricted to GOVERNANCE_ROLE

- No oracle dependencies


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

*Emergency closure process:
1. Validates emergency role and position ownership
2. Validates position is active
3. Updates hedger stats and removes position
4. Withdraws USDC from vault for hedger's margin*

*Security features:
1. Role-based access control (EMERGENCY_ROLE)
2. Position ownership validation*

**Notes:**
- Validates input parameters and enforces security checks

- Validates emergency role, position ownership, active status

- Closes position, updates hedger stats, withdraws USDC from vault

- Emits EmergencyPositionClosed with position details

- Throws custom errors for invalid conditions

- Protected by nonReentrant modifier

- Restricted to EMERGENCY_ROLE

- Requires oracle price for _unwindFilledVolume


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

*Emergency function to halt all user interactions*

**Notes:**
- Requires EMERGENCY_ROLE

- None required

- Sets contract to paused state

- Emits Paused event

- Throws InvalidRole if caller lacks EMERGENCY_ROLE

- Not applicable

- Restricted to EMERGENCY_ROLE

- Not applicable


```solidity
function pause() external;
```

### unpause

Unpauses all contract operations after emergency pause

*Emergency function to resume all user interactions*

**Notes:**
- Requires EMERGENCY_ROLE

- None required

- Sets contract to unpaused state

- Emits Unpaused event

- Throws InvalidRole if caller lacks EMERGENCY_ROLE

- Not applicable

- Restricted to EMERGENCY_ROLE

- Not applicable


```solidity
function unpause() external;
```

### hasPendingLiquidationCommitment

Checks if there's a pending liquidation commitment for a position

*Used to prevent margin operations during liquidation process*

**Notes:**
- View-only function - no state changes

- None required for view function

- None - view function

- None

- None

- Not applicable - view function

- Public - anyone can check commitment status

- Not applicable


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
|`<none>`|`bool`|True if there's a pending liquidation commitment|


### clearExpiredLiquidationCommitment

Clears expired liquidation commitments after cooldown period

*Allows liquidators to clean up expired commitments*

**Notes:**
- Requires LIQUIDATOR_ROLE, checks cooldown period

- Ensures cooldown period has passed

- Clears pending liquidation flag if expired

- None

- Throws InvalidRole if caller lacks LIQUIDATOR_ROLE

- Protected by nonReentrant modifier

- Restricted to LIQUIDATOR_ROLE

- Not applicable


```solidity
function clearExpiredLiquidationCommitment(address hedger, uint256 positionId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger whose commitment to clear|
|`positionId`|`uint256`|ID of the position whose commitment to clear|


### cancelLiquidationCommitment

Cancels a liquidation commitment before execution

*Allows liquidators to cancel their own commitments*

**Notes:**
- Requires LIQUIDATOR_ROLE, validates commitment exists

- Ensures commitment exists and belongs to caller

- Deletes commitment data and clears pending liquidation flag

- None

- Throws InvalidRole or CommitmentNotFound

- Protected by nonReentrant modifier

- Restricted to LIQUIDATOR_ROLE

- Not applicable


```solidity
function cancelLiquidationCommitment(address hedger, uint256 positionId, bytes32 salt) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger whose position was committed for liquidation|
|`positionId`|`uint256`|ID of the position whose commitment to cancel|
|`salt`|`bytes32`|Salt used in the original commitment|


### recover

Recovers tokens (token != 0) or ETH (token == 0) to treasury

*Emergency function to recover accidentally sent tokens or ETH*

**Notes:**
- Requires DEFAULT_ADMIN_ROLE

- Validates treasury address is set

- Transfers tokens/ETH to treasury

- None

- Throws InvalidRole if caller lacks DEFAULT_ADMIN_ROLE

- Protected by AdminFunctionsLibrary

- Restricted to DEFAULT_ADMIN_ROLE

- Not applicable


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

*Allows governance to update critical contract addresses*

**Notes:**
- Validates governance role and non-zero address

- Validates slot is valid (0-3) and addr != address(0)

- Updates treasury, vault, oracle, or yieldShift address

- Emits TreasuryUpdated or VaultUpdated for slots 0 and 1

- Throws ZeroAddress if addr is zero, InvalidPosition if slot is invalid

- Not protected - no external calls

- Restricted to GOVERNANCE_ROLE

- Updates oracle address if slot == 2


```solidity
function updateAddress(uint8 slot, address addr) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`slot`|`uint8`|Address slot to update (0=treasury, 1=vault, 2=oracle, 3=yieldShift)|
|`addr`|`address`|New address for the slot|


### setHedgerWhitelist

Whitelists or removes a hedger address for position opening

*Whitelisting process:
1. Validates governance role and hedger address
2. Checks hedger is not already whitelisted (if adding)
3. Adds hedger to whitelist and grants HEDGER_ROLE (if adding)
4. Removes hedger from whitelist and revokes HEDGER_ROLE (if removing)*

**Notes:**
- Validates input parameters and enforces security checks

- Validates governance role, hedger address, not already whitelisted (if adding)

- Adds/removes hedger to/from whitelist, grants/revokes HEDGER_ROLE

- Emits HedgerWhitelisted or HedgerRemovedFromWhitelist

- Throws AlreadyWhitelisted if adding already whitelisted hedger

- Not protected - governance function

- Restricted to GOVERNANCE_ROLE

- No oracle dependencies


```solidity
function setHedgerWhitelist(address hedger, bool add) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger to whitelist or remove|
|`add`|`bool`|True to whitelist, false to remove from whitelist|


### toggleHedgerWhitelistMode

Toggles the hedger whitelist mode on/off

*Whitelist mode toggle:
1. Validates governance role
2. Updates hedgerWhitelistEnabled state
3. Emits event for transparency*

*When enabled: Only whitelisted hedgers can open positions*

*When disabled: Any address can open positions*

**Notes:**
- Validates input parameters and enforces security checks

- Validates governance role

- Updates hedgerWhitelistEnabled state

- Emits HedgerWhitelistModeToggled with new state and caller

- Throws custom errors for invalid conditions

- Not protected - governance function

- Restricted to GOVERNANCE_ROLE

- No oracle dependencies


```solidity
function toggleHedgerWhitelistMode(bool enabled) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`enabled`|`bool`|Whether to enable or disable the whitelist mode|


### _getValidOraclePrice

Gets a valid EUR/USD price from the oracle

*Internal function to fetch and validate oracle price*

**Notes:**
- Validates oracle price is valid

- Validates oracle price is valid

- No state changes

- No events emitted

- Throws InvalidOraclePrice if price is invalid

- Not protected - internal function

- Internal function - no access restrictions

- Requires fresh oracle price data


```solidity
function _getValidOraclePrice() internal returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|price Valid EUR/USD price from oracle|


### _validateRole

Validates that the caller has the required role

*Internal function to check role-based access control*

**Notes:**
- Validates caller has the specified role

- Checks role against AccessControlLibrary

- None (view function)

- None

- Throws InvalidRole if caller lacks required role

- Not applicable - view function

- Internal function

- Not applicable


```solidity
function _validateRole(bytes32 role) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to validate against|


### _trackActivePosition

Removes a position from the hedger's position arrays

Tracks a newly opened position for global fill allocation

*Internal function to maintain position tracking arrays*

*Stores the index of the position in `activePositions` for O(1) removals*

**Notes:**
- Validates position exists before removal

- Ensures position exists in hedger's array

- Removes position from arrays and updates indices

- None

- Throws PositionNotFound if position doesn't exist

- Not applicable - internal function

- Internal function

- Not applicable

- Caller must ensure position is valid and unique

- Assumes positionId is not already tracked

- Updates `activePositionIndex` and `activePositions`

- None

- None

- Not applicable - internal function

- Internal helper

- Not applicable


```solidity
function _trackActivePosition(uint256 positionId) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|ID of the position to remove|


### _untrackActivePosition

Removes a position from the active tracking arrays

*Swaps-and-pops to keep the array compact while updating indices*

**Notes:**
- Caller must ensure positionId is currently tracked

- Assumes the active set is non-empty

- Modifies `activePositions` and `activePositionIndex`

- None

- None

- Not applicable - internal function

- Internal helper

- Not applicable


```solidity
function _untrackActivePosition(uint256 positionId) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|ID of the position to untrack|


### _finalizePosition

Finalizes position closure by updating hedger and protocol totals

*Internal helper to clean up position state and update aggregate statistics*

**Notes:**
- Internal function - assumes all validations done by caller

- Assumes marginDelta and exposureDelta are valid and don't exceed current totals

- Decrements hedger margin/exposure, protocol totals, marks position inactive, removes from active tracking, updates hedger position count

- None - events emitted by caller

- None - assumes valid inputs from caller

- Not applicable - internal function, no external calls

- Internal - only callable within contract

- Not applicable


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
|`hedger`|`address`|Address of the hedger whose position is being finalized|
|`positionId`|`uint256`|Unique identifier of the position being finalized|
|`position`|`HedgePosition`|Storage reference to the position being finalized|
|`marginDelta`|`uint256`|Amount of margin being removed from the position|
|`exposureDelta`|`uint256`|Amount of exposure being removed from the position|


### _unwindFilledVolume

Unwinds filled volume from a position and redistributes it

*Clears position's filled volume and redistributes it to other active positions*

**Notes:**
- Internal function - assumes position is valid and active

- Validates totalFilledExposure >= cachedFilledVolume before decrementing

- Clears position filledVolume, decrements totalFilledExposure, redistributes volume to other positions

- Emits HedgerFillUpdated with positionId, old filled volume, and 0

- Reverts with InsufficientHedgerCapacity if totalFilledExposure < cachedFilledVolume

- Protected by nonReentrant on all public entry points

- Internal - only callable within contract

- Requires fresh oracle price data


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
|`cachedPrice`|`uint256`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`freedVolume`|`uint256`|Amount of filled volume that was freed and redistributed|


### _decrementPendingCommitment

Decrements pending liquidation commitment count for a position

*Internal helper to manage liquidation commitment tracking*

**Notes:**
- Internal function - no external access

- None required for internal function

- Decrements pendingLiquidations count if > 0

- None

- None

- Not applicable - internal function

- Internal helper only

- Not applicable


```solidity
function _decrementPendingCommitment(address hedger, uint256 positionId) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger|
|`positionId`|`uint256`|ID of the position|


### _isPositionHealthyForFill

Checks if position is healthy enough for new fills

*Validates position has sufficient margin ratio after considering unrealized P&L*

**Notes:**
- Internal function - validates position health

- Checks effective margin > 0 and margin ratio >= minMarginRatio

- None - view function

- None

- None

- Not applicable - view function

- Internal helper only

- Uses provided price parameter


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

Allocates user mint exposure across active hedger positions

*Distributes `usdcAmount` proportionally to available capacity of HEALTHY positions only*

**Notes:**
- Caller must ensure hedger sets are consistent before invocation

- Validates liquidity availability and capacity before allocation

- Updates `filledVolume` per position and `totalFilledExposure`

- Emits `HedgerFillUpdated` for every adjusted position

- Reverts if capacity is insufficient or liquidity is absent

- Not applicable - internal function

- Internal helper

- Requires current oracle price to check position health


```solidity
function _increaseFilledVolume(uint256 usdcAmount, uint256 currentPrice, uint256 qeuroAmount, uint256 skipPositionId)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC exposure to allocate (6 decimals)|
|`currentPrice`|`uint256`|Current EUR/USD oracle price supplied by the caller (18 decimals)|
|`qeuroAmount`|`uint256`|QEURO amount that was minted (18 decimals)|
|`skipPositionId`|`uint256`|Position ID to exclude (e.g., the exiting position)|


### _decreaseFilledVolume

Releases exposure across hedger positions following a user redeem

*Proportionally decreases fills based on filled volume share*

**Notes:**
- Internal function - validates price and amounts

- Validates usdcAmount > 0, redeemPrice > 0, and sufficient filled exposure

- Decreases filledVolume per position, updates totalFilledExposure, calculates realized P&L

- Emits HedgerFillUpdated and RealizedPnLRecorded for each position

- Reverts with InvalidOraclePrice, NoActiveHedgerLiquidity, or InsufficientHedgerCapacity

- Not applicable - internal function

- Internal helper only

- Uses provided redeemPrice parameter


```solidity
function _decreaseFilledVolume(uint256 usdcAmount, uint256 redeemPrice, uint256 qeuroAmount, uint256 skipPositionId)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC to release (at redeem price) (6 decimals)|
|`redeemPrice`|`uint256`|Current EUR/USD oracle price (18 decimals) for P&L calculation|
|`qeuroAmount`|`uint256`|QEURO amount that was redeemed (18 decimals)|
|`skipPositionId`|`uint256`|Position ID to exclude from the release cycle|


### _applyFillChange

Applies a fill delta to a single position and emits an event

*Handles both increases and decreases while enforcing capacity constraints*

**Notes:**
- Caller must ensure the storage reference is valid

- Validates capacity or availability before applying the delta

- Updates the position’s `filledVolume`

- Emits `HedgerFillUpdated`

- Reverts with `InsufficientHedgerCapacity` on invalid operations

- Not applicable - internal function

- Internal helper

- Not applicable


```solidity
function _applyFillChange(uint256 positionId, HedgePosition storage position, uint256 delta, bool increase) internal;
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

*Calculates new weighted average entry price when position receives new fills*

**Notes:**
- Internal function - validates price is valid

- Validates price > 0 and price <= type(uint96).max

- Updates pos.entryPrice with weighted average

- None

- Throws InvalidOraclePrice if price is invalid

- Not applicable - internal function

- Internal helper only

- Uses provided price parameter


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

*New formula: RealizedP&L = QEUROQuantitySold * (entryPrice - OracleCurrentPrice)
Hedgers are SHORT EUR, so they profit when EUR price decreases*

**Notes:**
- Internal function - calculates and records realized P&L

- Validates entry price > 0 and qeuroAmount > 0

- Updates pos.realizedPnL and decreases filled volume

- Emits RealizedPnLRecorded and HedgerFillUpdated

- None

- Not applicable - internal function

- Internal helper only

- Uses provided price parameter


```solidity
function _processRedeem(
    uint256 posId,
    HedgePosition storage pos,
    uint256 share,
    uint256,
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
|`<none>`|`uint256`||
|`price`|`uint256`|Current EUR/USD oracle price for redemption (18 decimals)|
|`qeuroAmount`|`uint256`|QEURO amount being redeemed (18 decimals)|


### _validatePositionClosureSafety

Validates that closing a position won't cause protocol undercollateralization

*Checks if protocol remains collateralized after removing this position's margin*

**Notes:**
- Internal function - prevents protocol undercollateralization from position closures

- Checks vault is set, protocol is collateralized, and remaining margin > positionMargin

- None - view function

- None

- Reverts with PositionClosureRestricted if closing would cause undercollateralization

- Not applicable - view function, no state changes

- Internal - only callable within contract

- Not applicable - uses vault's collateralization check


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

### HedgerLiquidated

```solidity
event HedgerLiquidated(
    address indexed hedger, uint256 indexed positionId, address indexed liquidator, bytes32 packedData
);
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

## Structs
### CoreParams

```solidity
struct CoreParams {
    uint64 minMarginRatio;
    uint64 liquidationThreshold;
    uint16 maxLeverage;
    uint16 liquidationPenalty;
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
    int128 realizedPnL;
    uint16 leverage;
    bool isActive;
    uint128 qeuroBacked;
}
```

### HedgerBalance

```solidity
struct HedgerBalance {
    uint128 totalMargin;
    uint128 totalExposure;
}
```

### HedgerRewardState

```solidity
struct HedgerRewardState {
    uint128 pendingRewards;
    uint64 lastRewardClaim;
}
```

