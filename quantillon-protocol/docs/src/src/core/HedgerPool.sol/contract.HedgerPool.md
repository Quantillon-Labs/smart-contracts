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


### MAX_PENDING_REWARDS

```solidity
uint256 public constant MAX_PENDING_REWARDS = MAX_UINT128_VALUE;
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

- Protected by whenNotPaused modifier

- Restricted to position owner

- Requires fresh oracle price data


```solidity
function exitHedgePosition(uint256 positionId) external whenNotPaused returns (int256 pnl);
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

- Validates the amount is greater than zero

- Updates total filled exposure and per-position fills

- Emits `HedgerFillUpdated` for every position receiving fill

- Reverts with `InvalidAmount`, `NoActiveHedgerLiquidity`, or `InsufficientHedgerCapacity`

- Not applicable (no external calls besides trusted helpers)

- Restricted to `QuantillonVault`

- Not applicable


```solidity
function recordUserMint(uint256 usdcAmount) external onlyVault whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Net USDC amount that was minted into QEURO|


### recordUserRedeem

Records a user redemption and releases hedger fills proportionally

*Callable only by QuantillonVault to sync hedger exposure with user activity*

**Notes:**
- Only callable by the vault; amount must be positive

- Validates the amount is greater than zero

- Reduces total filled exposure and per-position fills

- Emits `HedgerFillUpdated` for every position releasing fill

- Reverts with `InvalidAmount` or `InsufficientHedgerCapacity`

- Not applicable (no external calls besides trusted helpers)

- Restricted to `QuantillonVault`

- Not applicable


```solidity
function recordUserRedeem(uint256 usdcAmount) external onlyVault whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Gross USDC amount redeemed from QEURO burn|


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


### getActivePositionIds

Returns the list of currently active position IDs

*Provides a snapshot of all active hedger positions for analytics and monitoring*

**Notes:**
- View-only helper - no state changes

- No additional validation beyond internal state

- None - view function

- None

- None

- Not applicable - view function

- Public - anyone can query active positions

- No oracle dependencies


```solidity
function getActivePositionIds() external view returns (uint256[] memory activePositionIds);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`activePositionIds`|`uint256[]`|Array of active position IDs|


### getFillMetrics

Returns aggregate fill metrics across all positions

*Helps off-chain services monitor hedger capacity usage*

**Notes:**
- View-only helper - no state changes

- No additional validation beyond internal state

- None - view function

- None

- None

- Not applicable - view function

- Public - anyone can query fill metrics

- No oracle dependencies


```solidity
function getFillMetrics() external view returns (uint256 totalHedgeExposure, uint256 totalMatchedExposure);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalHedgeExposure`|`uint256`|Current aggregate position exposure in USDC|
|`totalMatchedExposure`|`uint256`|Current aggregate filled exposure in USDC|


### getTotalEffectiveHedgerCollateral

Calculates total effective hedger collateral (deposits + P&L) across all active positions

*Used by vault to determine protocol collateralization ratio*

**Notes:**
- Read-only helper - no state changes

- Requires valid oracle price

- None - read-only function (not view due to oracle call)

- None

- Reverts if oracle price is invalid

- Not applicable - read-only function

- Public - anyone can query effective collateral

- Requires fresh oracle price data


```solidity
function getTotalEffectiveHedgerCollateral() external returns (uint256 totalEffectiveCollateral);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalEffectiveCollateral`|`uint256`|Total effective collateral in USDC (6 decimals)|


### updateHedgingParameters

Updates core hedging parameters for the protocol

*Allows governance to adjust risk parameters for hedge positions*

**Notes:**
- Requires GOVERNANCE_ROLE, validates parameter ranges

- Ensures minMarginRatio >= 500, liquidationThreshold < minMarginRatio, maxLeverage <= 20, liquidationPenalty <= 1000

- Updates coreParams struct with new values

- None

- Throws InvalidRole, ConfigValueTooLow, ConfigInvalid, or ConfigValueTooHigh

- Protected by nonReentrant modifier

- Restricted to GOVERNANCE_ROLE

- Not applicable


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
|`newMinMarginRatio`|`uint256`|New minimum margin ratio in basis points (minimum 500 = 5%)|
|`newLiquidationThreshold`|`uint256`|New liquidation threshold in basis points (must be < minMarginRatio)|
|`newMaxLeverage`|`uint256`|New maximum leverage multiplier (maximum 20x)|
|`newLiquidationPenalty`|`uint256`|New liquidation penalty in basis points (maximum 1000 = 10%)|


### updateInterestRates

Updates interest rates for EUR and USD positions

*Allows governance to adjust interest rates for yield calculations*

**Notes:**
- Requires GOVERNANCE_ROLE, validates rate limits

- Ensures both rates are <= 2000 basis points (20%)

- Updates coreParams with new interest rates

- None

- Throws InvalidRole or ConfigValueTooHigh

- Protected by nonReentrant modifier

- Restricted to GOVERNANCE_ROLE

- Not applicable


```solidity
function updateInterestRates(uint256 newEurRate, uint256 newUsdRate) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newEurRate`|`uint256`|New EUR interest rate in basis points (maximum 2000 = 20%)|
|`newUsdRate`|`uint256`|New USD interest rate in basis points (maximum 2000 = 20%)|


### setHedgingFees

Sets the fee structure for hedge positions

*Allows governance to adjust fees for position entry, exit, and margin operations*

**Notes:**
- Requires GOVERNANCE_ROLE, validates fee limits

- Ensures entryFee <= 100, exitFee <= 100, marginFee <= 50

- Updates coreParams with new fee values

- None

- Throws InvalidRole or InvalidFee

- Protected by nonReentrant modifier

- Restricted to GOVERNANCE_ROLE

- Not applicable


```solidity
function setHedgingFees(uint256 _entryFee, uint256 _exitFee, uint256 _marginFee) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_entryFee`|`uint256`|New entry fee in basis points (maximum 100 = 1%)|
|`_exitFee`|`uint256`|New exit fee in basis points (maximum 100 = 1%)|
|`_marginFee`|`uint256`|New margin fee in basis points (maximum 50 = 0.5%)|


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

- Not protected - emergency function

- Restricted to EMERGENCY_ROLE

- No oracle dependencies


```solidity
function emergencyClosePosition(address hedger, uint256 positionId) external;
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

Unpauses contract operations after emergency

*Resumes normal contract functionality*

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

Checks if a position has a pending liquidation commitment

*Returns true if a liquidation commitment exists for the position*

**Notes:**
- No security validations required for view function

- None required for view function

- None (view function)

- None

- None

- Not applicable - view function

- Public (anyone can query commitment status)

- Not applicable


```solidity
function hasPendingLiquidationCommitment(address hedger, uint256 positionId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger who owns the position|
|`positionId`|`uint256`|ID of the position to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if liquidation commitment exists, false otherwise|


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


### recoverToken

Recovers accidentally sent tokens to the treasury

*Emergency function to recover tokens sent to the contract*

**Notes:**
- Requires DEFAULT_ADMIN_ROLE

- None required

- Transfers tokens from contract to treasury

- None

- Throws InvalidRole if caller lacks DEFAULT_ADMIN_ROLE

- Protected by nonReentrant modifier

- Restricted to DEFAULT_ADMIN_ROLE

- Not applicable


```solidity
function recoverToken(address token, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Address of the token to recover|
|`amount`|`uint256`|Amount of tokens to recover|


### recoverETH

Recovers accidentally sent ETH to the treasury

*Emergency function to recover ETH sent to the contract*

**Notes:**
- Requires DEFAULT_ADMIN_ROLE

- None required

- Transfers ETH from contract to treasury

- Emits ETHRecovered event

- Throws InvalidRole if caller lacks DEFAULT_ADMIN_ROLE

- Protected by nonReentrant modifier

- Restricted to DEFAULT_ADMIN_ROLE

- Not applicable


```solidity
function recoverETH() external;
```

### updateTreasury

Updates the treasury address for fee collection

*Allows governance to change the treasury address*

**Notes:**
- Requires GOVERNANCE_ROLE, validates address

- Ensures treasury is not zero address and passes validation

- Updates treasury address

- Emits TreasuryUpdated event

- Throws InvalidRole, InvalidAddress, or zero address error

- Protected by nonReentrant modifier

- Restricted to GOVERNANCE_ROLE

- Not applicable


```solidity
function updateTreasury(address _treasury) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_treasury`|`address`|New treasury address for fee collection|


### updateVault

Updates the vault address for USDC management

*Allows governance to change the vault contract address*

**Notes:**
- Requires GOVERNANCE_ROLE, validates address

- Ensures vault is not zero address

- Updates vault address

- Emits VaultUpdated event

- Throws InvalidRole or InvalidAddress

- Protected by nonReentrant modifier

- Restricted to GOVERNANCE_ROLE

- Not applicable


```solidity
function updateVault(address _vault) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_vault`|`address`|New vault address for USDC operations|


### updateOracle

Updates the oracle address

*Governance-only setter to allow phased wiring after minimal initialization*

**Notes:**
- Restricted to GOVERNANCE_ROLE and validates non-zero address

- Ensures `_oracle` is not the zero address

- Updates the `oracle` reference used for price checks

- Emits `VaultUpdated`? (no) -> None

- Reverts with `InvalidAddress`

- Not applicable

- Governance-only

- Establishes new oracle dependency


```solidity
function updateOracle(address _oracle) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_oracle`|`address`|New oracle address|


### updateYieldShift

Updates the YieldShift address

*Governance-only setter to allow phased wiring after minimal initialization*

**Notes:**
- Restricted to GOVERNANCE_ROLE and validates non-zero address

- Ensures `_yieldShift` is not the zero address

- Updates the `yieldShift` reference used for reward sync

- None

- Reverts with `InvalidAddress`

- Not applicable

- Governance-only

- Not applicable


```solidity
function updateYieldShift(address _yieldShift) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_yieldShift`|`address`|New YieldShift address|


### whitelistHedger

Whitelists a hedger address for position opening

*Whitelisting process:
1. Validates governance role and hedger address
2. Checks hedger is not already whitelisted
3. Adds hedger to whitelist and grants HEDGER_ROLE*

*Security features:
1. Role-based access control (GOVERNANCE_ROLE)
2. Address validation*

**Notes:**
- Validates input parameters and enforces security checks

- Validates governance role, hedger address, not already whitelisted

- Adds hedger to whitelist, grants HEDGER_ROLE

- Emits HedgerWhitelisted with hedger and caller details

- Throws custom errors for invalid conditions

- Not protected - governance function

- Restricted to GOVERNANCE_ROLE

- No oracle dependencies


```solidity
function whitelistHedger(address hedger) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger to whitelist|


### removeHedger

Removes a hedger from the whitelist

*Removal process:
1. Validates governance role and hedger address
2. Checks hedger is currently whitelisted
3. Removes hedger from whitelist and revokes HEDGER_ROLE*

*Security features:
1. Role-based access control (GOVERNANCE_ROLE)
2. Address validation*

**Notes:**
- Validates input parameters and enforces security checks

- Validates governance role, hedger address, currently whitelisted

- Removes hedger from whitelist, revokes HEDGER_ROLE

- Emits HedgerRemoved with hedger and caller details

- Throws custom errors for invalid conditions

- Not protected - governance function

- Restricted to GOVERNANCE_ROLE

- No oracle dependencies


```solidity
function removeHedger(address hedger) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger to remove from whitelist|


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
function _getValidOraclePrice() internal view returns (uint256);
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

- Not applicable - internal function, no external calls

- Internal - only callable within contract

- Not applicable


```solidity
function _unwindFilledVolume(uint256 positionId, HedgePosition storage position)
    internal
    returns (uint256 freedVolume);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|Unique identifier of the position being unwound|
|`position`|`HedgePosition`|Storage reference to the position being unwound|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`freedVolume`|`uint256`|Amount of filled volume that was freed and redistributed|


### _decrementPendingCommitment

Decrements the pending liquidation commitment count for a position

*Internal helper to clean up liquidation commitments after execution or cancellation*

**Notes:**
- Internal function - assumes valid hedger and positionId

- Validates count > 0 before decrementing to prevent underflow

- Decrements pendingLiquidations[hedger][positionId] if count > 0

- None

- None - uses unchecked arithmetic with validation

- Not applicable - internal function, no external calls

- Internal - only callable within contract

- Not applicable


```solidity
function _decrementPendingCommitment(address hedger, uint256 positionId) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger whose position commitment is being decremented|
|`positionId`|`uint256`|Unique identifier of the position whose commitment is being decremented|


### _increaseFilledVolume

Convenience overload to increase fills without skipping any position

*Forwards to the full allocator with a zero skip identifier*

**Notes:**
- Caller must ensure `usdcAmount` is sanitized

- No additional validation beyond delegated call

- See `_increaseFilledVolume(uint256,uint256)`

- Emits `HedgerFillUpdated` via delegated call

- See delegated allocator

- Not applicable

- Internal helper

- Not applicable


```solidity
function _increaseFilledVolume(uint256 usdcAmount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC exposure to allocate|


### _increaseFilledVolume

Allocates user mint exposure across active hedger positions

*Distributes `usdcAmount` proportionally to available capacity*

**Notes:**
- Caller must ensure hedger sets are consistent before invocation

- Validates liquidity availability and capacity before allocation

- Updates `filledVolume` per position and `totalFilledExposure`

- Emits `HedgerFillUpdated` for every adjusted position

- Reverts if capacity is insufficient or liquidity is absent

- Not applicable - internal function

- Internal helper

- Not applicable


```solidity
function _increaseFilledVolume(uint256 usdcAmount, uint256 skipPositionId) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC exposure to allocate|
|`skipPositionId`|`uint256`|Position ID to exclude (e.g., the exiting position)|


### _decreaseFilledVolume

Releases exposure across hedger positions following a user redeem

*Proportionally decreases fills (optionally skipping one position)*

**Notes:**
- Caller must ensure inputs keep invariants consistent

- Ensures sufficient filled exposure exists for release

- Decreases per-position `filledVolume` and `totalFilledExposure`

- Emits `HedgerFillUpdated` for every adjusted position

- Reverts if exposure is insufficient or no active liquidity is present

- Not applicable - internal function

- Internal helper

- Not applicable


```solidity
function _decreaseFilledVolume(uint256 usdcAmount, uint256 skipPositionId) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC exposure to release|
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


### _packPositionOpenData

Packs position open data into a single bytes32 for gas efficiency

*Encodes position size, margin, leverage, and entry price into a compact format*

**Notes:**
- No security validations required for pure function

- None required for pure function

- None (pure function)

- None

- None

- Not applicable - pure function

- Internal function

- Uses provided entryPrice parameter


```solidity
function _packPositionOpenData(uint256 positionSize, uint256 margin, uint256 leverage, uint256 entryPrice)
    internal
    pure
    returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionSize`|`uint256`|Size of the position in USDC|
|`margin`|`uint256`|Margin amount for the position|
|`leverage`|`uint256`|Leverage multiplier for the position|
|`entryPrice`|`uint256`|Price at which the position was opened|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Packed data as bytes32|


### _packPositionCloseData

Packs position close data into a single bytes32 for gas efficiency

*Encodes exit price, PnL, and timestamp into a compact format*

**Notes:**
- No security validations required for pure function

- None required for pure function

- None (pure function)

- None

- None

- Not applicable - pure function

- Internal function

- Not applicable


```solidity
function _packPositionCloseData(uint256 exitPrice, int256 pnl, uint256 timestamp) internal pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`exitPrice`|`uint256`|Price at which the position was closed|
|`pnl`|`int256`|Profit or loss from the position (can be negative)|
|`timestamp`|`uint256`|Timestamp when the position was closed|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Packed data as bytes32|


### _packMarginData

Packs margin data into a single bytes32 for gas efficiency

*Encodes margin amount, new margin ratio, and operation type*

**Notes:**
- No security validations required for pure function

- None required for pure function

- None (pure function)

- None

- None

- Not applicable - pure function

- Internal function

- Not applicable


```solidity
function _packMarginData(uint256 marginAmount, uint256 newMarginRatio, bool isAdded) internal pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`marginAmount`|`uint256`|Amount of margin added or removed|
|`newMarginRatio`|`uint256`|New margin ratio after the operation|
|`isAdded`|`bool`|True if margin was added, false if removed|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Packed data as bytes32|


### _packLiquidationData

Packs liquidation data into a single bytes32 for gas efficiency

*Encodes liquidation reward and remaining margin*

**Notes:**
- No security validations required for pure function

- None required for pure function

- None (pure function)

- None

- None

- Not applicable - pure function

- Internal function

- Not applicable


```solidity
function _packLiquidationData(uint256 liquidationReward, uint256 remainingMargin) internal pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`liquidationReward`|`uint256`|Reward paid to the liquidator|
|`remainingMargin`|`uint256`|Margin remaining after liquidation|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Packed data as bytes32|


### _packRewardData

Packs reward data into a single bytes32 for gas efficiency

*Encodes interest differential, yield shift rewards, and total rewards*

**Notes:**
- No security validations required for pure function

- None required for pure function

- None (pure function)

- None

- None

- Not applicable - pure function

- Internal function

- Not applicable


```solidity
function _packRewardData(uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards)
    internal
    pure
    returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`interestDifferential`|`uint256`|Interest rate differential between EUR and USD|
|`yieldShiftRewards`|`uint256`|Rewards from yield shifting operations|
|`totalRewards`|`uint256`|Total rewards accumulated|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Packed data as bytes32|


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
    uint16 leverage;
    bool isActive;
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

