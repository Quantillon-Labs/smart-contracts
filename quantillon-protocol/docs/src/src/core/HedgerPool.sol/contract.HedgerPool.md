# HedgerPool
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/91f7ed3e8a496e9d369dc182e8f549ec75449a6b/src/core/HedgerPool.sol)

**Inherits:**
Initializable, ReentrancyGuardUpgradeable, AccessControlUpgradeable, PausableUpgradeable, [SecureUpgradeable](/src/core/SecureUpgradeable.sol/abstract.SecureUpgradeable.md)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

EUR/USD hedging pool for managing currency risk and providing yield

*Main characteristics:
- EUR/USD currency hedging through leveraged positions
- Margin-based trading with liquidation system
- Interest rate differential yield generation
- Multi-position management per hedger
- Emergency pause mechanism for crisis situations
- Upgradeable via UUPS pattern*

*Position mechanics:
- Hedgers open leveraged EUR/USD positions
- Positions require minimum margin ratio (default 5%)
- Maximum leverage of 20x to limit risk exposure
- Position sizes tracked for risk management
- Entry and exit fees charged for protocol revenue*

*Margin system:
- Initial margin required for position opening (minimum 5%)
- Margin can be added to strengthen positions
- Margin removal allowed if above minimum ratio
- Real-time margin ratio calculations
- Margin fees charged on additions*

*Liquidation system:
- Two-phase liquidation with commit-reveal pattern
- Liquidation threshold below minimum margin ratio (default 1%)
- Liquidation penalty rewarded to liquidators (default 2%)
- Cooldown period prevents liquidation manipulation
- Emergency position closure for critical situations*

*Yield generation:
- Interest rate differential between EUR and USD rates
- Rewards distributed based on position exposure
- Time-weighted reward calculations
- Integration with yield shift mechanism
- Automatic reward accumulation and claiming*

*Risk management:
- Maximum positions per hedger (50) to prevent concentration
- Real-time oracle price monitoring
- Position size limits and exposure tracking
- Liquidation cooldown mechanisms
- Emergency position closure capabilities*

*Fee structure:
- Entry fees for opening positions (default 0.2%)
- Exit fees for closing positions (default 0.2%)
- Margin fees for adding collateral (default 0.1%)
- Dynamic fee adjustment based on market conditions*

*Security features:
- Role-based access control for all critical operations
- Reentrancy protection for all external calls
- Emergency pause mechanism for crisis situations
- Upgradeable architecture for future improvements
- Secure position and margin management
- Two-phase liquidation for manipulation resistance
- Overflow protection for packed struct fields
- Comprehensive validation before type casting
- Maximum value constraints to prevent storage corruption*

*Integration points:
- USDC for margin deposits and withdrawals
- Chainlink oracle for EUR/USD price feeds
- Yield shift mechanism for reward distribution
- Vault math library for precise calculations
- Position tracking and management systems*

**Note:**
security-contact: team@quantillon.money


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


### treasury

```solidity
address public treasury;
```


### TIME_PROVIDER
TimeProvider contract for centralized time management

*Used to replace direct block.timestamp usage for testability and consistency*


```solidity
TimeProvider public immutable TIME_PROVIDER;
```


### minMarginRatio

```solidity
uint256 public minMarginRatio;
```


### liquidationThreshold

```solidity
uint256 public liquidationThreshold;
```


### maxLeverage

```solidity
uint256 public maxLeverage;
```


### liquidationPenalty

```solidity
uint256 public liquidationPenalty;
```


### MAX_POSITIONS_PER_HEDGER

```solidity
uint256 public constant MAX_POSITIONS_PER_HEDGER = 50;
```


### MAX_BATCH_SIZE

```solidity
uint256 public constant MAX_BATCH_SIZE = 50;
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


### activePositionCount

```solidity
mapping(address => uint256) public activePositionCount;
```


### isWhitelistedHedger
Whitelist mapping for hedger addresses

*When hedgerWhitelistEnabled is true, only whitelisted addresses can open positions*


```solidity
mapping(address => bool) public isWhitelistedHedger;
```


### hedgerWhitelistEnabled
Whether hedger whitelist mode is enabled

*When true, only whitelisted addresses can open hedge positions*


```solidity
bool public hedgerWhitelistEnabled;
```


### entryFee

```solidity
uint256 public entryFee;
```


### exitFee

```solidity
uint256 public exitFee;
```


### marginFee

```solidity
uint256 public marginFee;
```


### totalMargin

```solidity
uint256 public totalMargin;
```


### totalExposure

```solidity
uint256 public totalExposure;
```


### activeHedgers

```solidity
uint256 public activeHedgers;
```


### nextPositionId

```solidity
uint256 public nextPositionId;
```


### eurInterestRate

```solidity
uint256 public eurInterestRate;
```


### usdInterestRate

```solidity
uint256 public usdInterestRate;
```


### positions

```solidity
mapping(uint256 => HedgePosition) public positions;
```


### hedgers

```solidity
mapping(address => HedgerInfo) public hedgers;
```


### hedgerPositions

```solidity
mapping(address => uint256[]) public hedgerPositions;
```


### hedgerHasPosition

```solidity
mapping(address => mapping(uint256 => bool)) public hedgerHasPosition;
```


### positionIndex

```solidity
mapping(address => mapping(uint256 => uint256)) public positionIndex;
```


### hedgerPositionIndex

```solidity
mapping(address => mapping(uint256 => uint256)) public hedgerPositionIndex;
```


### TOTAL_YIELD_EARNED

```solidity
uint256 public constant TOTAL_YIELD_EARNED = 0;
```


### INTEREST_DIFFERENTIAL_POOL

```solidity
uint256 public constant INTEREST_DIFFERENTIAL_POOL = 0;
```


### userPendingYield

```solidity
mapping(address => uint256) public userPendingYield;
```


### hedgerPendingYield

```solidity
mapping(address => uint256) public hedgerPendingYield;
```


### userLastClaim

```solidity
mapping(address => uint256) public userLastClaim;
```


### hedgerLastClaim

```solidity
mapping(address => uint256) public hedgerLastClaim;
```


### hedgerLastRewardBlock

```solidity
mapping(address => uint256) public hedgerLastRewardBlock;
```


### BLOCKS_PER_DAY

```solidity
uint256 public constant BLOCKS_PER_DAY = 7200;
```


### MAX_REWARD_PERIOD

```solidity
uint256 public constant MAX_REWARD_PERIOD = 365 days;
```


### LIQUIDATION_COOLDOWN
*Cooldown period in blocks (~1 hour assuming 12 second blocks)*

*Using block numbers instead of timestamps for security against miner manipulation*


```solidity
uint256 public constant LIQUIDATION_COOLDOWN = 300;
```


### liquidationCommitments

```solidity
mapping(bytes32 => bool) public liquidationCommitments;
```


### liquidationCommitmentTimes

```solidity
mapping(bytes32 => uint256) public liquidationCommitmentTimes;
```


### lastLiquidationAttempt

```solidity
mapping(address => uint256) public lastLiquidationAttempt;
```


### hasPendingLiquidation

```solidity
mapping(address => mapping(uint256 => bool)) public hasPendingLiquidation;
```


## Functions
### flashLoanProtection

Modifier to protect against flash loan attacks

*Uses the FlashLoanProtectionLibrary to check USDC balance consistency*


```solidity
modifier flashLoanProtection();
```

### secureOperation


```solidity
modifier secureOperation();
```

### secureNonReentrant


```solidity
modifier secureNonReentrant();
```

### _packData

Consolidated data packing function for event emissions

*Packs multiple values into a single bytes32 for gas-efficient event logging*


```solidity
function _packData(
    uint256 v1,
    uint256 s1,
    uint256 v2,
    uint256 s2,
    uint256 v3,
    uint256 s3,
    uint256 v4,
    uint256 s4,
    uint256 flags
) private pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`v1`|`uint256`|First value|
|`s1`|`uint256`|Bit shift for first value|
|`v2`|`uint256`|Second value (optional, 0 if not used)|
|`s2`|`uint256`|Bit shift for second value (optional, 0 if not used)|
|`v3`|`uint256`|Third value (optional, 0 if not used)|
|`s3`|`uint256`|Bit shift for third value (optional, 0 if not used)|
|`v4`|`uint256`|Fourth value (optional, 0 if not used)|
|`s4`|`uint256`|Bit shift for fourth value (optional, 0 if not used)|
|`flags`|`uint256`|Additional flags (for bool values, etc.)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Packed bytes32 data|


### _packPositionOpenData


```solidity
function _packPositionOpenData(uint256 positionSize, uint256 margin, uint256 leverage, uint256 entryPrice)
    private
    pure
    returns (bytes32);
```

### _packPositionCloseData


```solidity
function _packPositionCloseData(uint256 exitPrice, int256 pnl, uint256 timestamp) private pure returns (bytes32);
```

### _packMarginData


```solidity
function _packMarginData(uint256 marginAmount, uint256 newMarginRatio, bool isAdded) private pure returns (bytes32);
```

### _packLiquidationData


```solidity
function _packLiquidationData(uint256 liquidationReward, uint256 remainingMargin) private pure returns (bytes32);
```

### _packRewardData


```solidity
function _packRewardData(uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards)
    private
    pure
    returns (bytes32);
```

### _validatePositionOwnership

Consolidated position validation function

*Validates position ownership and returns the position for further use*

**Notes:**
- security: Validates position ownership to prevent unauthorized access

- validation: Validates hedger address and positionId > 0

- state-changes: No state changes - view function only

- events: No events emitted

- errors: Throws InvalidHedger if hedger doesn't own the position

- reentrancy: Not applicable - view function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function _validatePositionOwnership(address hedger, uint256 positionId) internal view returns (HedgePosition storage);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger claiming ownership|
|`positionId`|`uint256`|ID of the position to validate|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`HedgePosition`|position The validated position storage reference|


### _getValidOraclePrice

Consolidated oracle price validation function

*Gets and validates oracle price, reverts if invalid*

**Notes:**
- security: Validates oracle price freshness and validity

- validation: Validates oracle price is valid and not stale

- state-changes: No state changes - view function only

- events: No events emitted

- errors: Throws InvalidOraclePrice if oracle price is invalid

- reentrancy: Not applicable - view function

- access: Internal function - no access restrictions

- oracle: Requires fresh EUR/USD price from Chainlink oracle


```solidity
function _getValidOraclePrice() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|price The validated EUR/USD price|


### _validateRole

Consolidated role validation function

*Validates that caller has the required role*

**Notes:**
- security: Validates caller has the required role for access control

- validation: Validates role parameter is a valid role constant

- state-changes: No state changes - view function only

- events: No events emitted

- errors: Throws "Invalid role" if role is not recognized

- reentrancy: Not applicable - view function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function _validateRole(bytes32 role) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to validate (GOVERNANCE_ROLE, LIQUIDATOR_ROLE, etc.)|


### constructor

Constructor for HedgerPool contract

*Initializes the TimeProvider and disables initializers for proxy pattern*

**Notes:**
- security: Validates TimeProvider address is not zero

- validation: Validates _TIME_PROVIDER is not address(0)

- state-changes: Sets TIME_PROVIDER immutable variable and disables initializers

- events: No events emitted

- errors: Throws ZeroAddress if _TIME_PROVIDER is address(0)

- reentrancy: Not applicable - constructor

- access: Public - anyone can deploy

- oracle: No oracle dependencies


```solidity
constructor(TimeProvider _TIME_PROVIDER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_TIME_PROVIDER`|`TimeProvider`|Address of the TimeProvider contract for centralized time management|


### initialize

Initializes the HedgerPool contract with required dependencies

*Sets up all core dependencies, roles, and default configuration parameters*

**Notes:**
- security: Validates all addresses are not zero, grants admin roles

- validation: Validates all input addresses using AccessControlLibrary

- state-changes: Initializes all state variables, sets default fees and parameters

- events: No events emitted during initialization

- errors: Throws ZeroAddress if any address is address(0)

- reentrancy: Protected by initializer modifier

- access: Public - only callable once during deployment

- oracle: Sets oracle address for EUR/USD price feeds


```solidity
function initialize(
    address admin,
    address _usdc,
    address _oracle,
    address _yieldShift,
    address _timelock,
    address _treasury
) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address that will receive admin and governance roles|
|`_usdc`|`address`|Address of the USDC token contract (6 decimals)|
|`_oracle`|`address`|Address of the Chainlink oracle for EUR/USD price feeds|
|`_yieldShift`|`address`|Address of the YieldShift contract for reward distribution|
|`_timelock`|`address`|Address of the timelock contract for upgrade approvals|
|`_treasury`|`address`|Address of the treasury for fee collection|


### enterHedgePosition

Opens a new hedge position with specified USDC margin and leverage

*Creates a leveraged EUR/USD hedge position with margin requirements*

**Notes:**
- security: Validates oracle price freshness, enforces margin ratios and leverage limits

- validation: Validates usdcAmount > 0, leverage <= maxLeverage, position count limits

- state-changes: Creates new HedgePosition, updates hedger totals, increments position counters

- events: Emits HedgePositionOpened with position details

- errors: Throws InvalidAmount, InvalidLeverage, InvalidOraclePrice, RateLimitExceeded

- reentrancy: Protected by secureNonReentrant modifier

- access: Public - requires sufficient USDC balance and approval

- oracle: Requires fresh EUR/USD price from Chainlink oracle


```solidity
function enterHedgePosition(uint256 usdcAmount, uint256 leverage)
    external
    secureNonReentrant
    returns (uint256 positionId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC to deposit as margin (6 decimals)|
|`leverage`|`uint256`|Leverage multiplier for the position (1-10x)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|Unique identifier for the new position|


### exitHedgePosition

Closes a hedge position and calculates profit/loss

*Closes position, calculates PnL based on current EUR/USD price, applies exit fees*

**Notes:**
- security: Validates position ownership and active status, enforces oracle price freshness

- validation: Validates position exists, is active, and owned by caller

- state-changes: Closes position, updates hedger totals, decrements position counters

- events: Emits HedgePositionClosed with PnL and exit details

- errors: Throws InvalidPosition, PositionNotActive, InvalidOraclePrice

- reentrancy: Protected by secureNonReentrant modifier

- access: Public - requires position ownership

- oracle: Requires fresh EUR/USD price from Chainlink oracle


```solidity
function exitHedgePosition(uint256 positionId) external secureNonReentrant returns (int256 pnl);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|Unique identifier of the position to close|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`pnl`|`int256`|Profit or loss from the position (positive = profit, negative = loss)|


### _removePositionFromArrays

Removes a position from internal tracking arrays

*Performs O(1) removal by swapping with last element*

**Notes:**
- security: Validates position exists in tracking arrays

- validation: Validates hedgerHasPosition mapping is true

- state-changes: Removes position from arrays, cleans up mappings

- events: No events emitted

- errors: Throws PositionNotFound if position not in tracking arrays

- reentrancy: Not protected - internal function only

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function _removePositionFromArrays(address hedger, uint256 positionId) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|The address of the hedger who owns the position|
|`positionId`|`uint256`|The ID of the position to remove|


### addMargin

Adds additional margin to an existing hedge position

*Increases position margin to improve margin ratio and reduce liquidation risk*

**Notes:**
- security: Validates position ownership, active status, and liquidation cooldown

- validation: Validates amount > 0, position exists and is active, no pending liquidation

- state-changes: Increases position margin, hedger totals, and global margin

- events: Emits MarginUpdated with added margin details

- errors: Throws InvalidPosition, PositionNotActive, PendingLiquidationCommitment

- reentrancy: Protected by secureOperation modifier

- access: Public - requires position ownership

- oracle: No oracle dependencies for margin addition


```solidity
function addMargin(uint256 positionId, uint256 amount) external secureOperation;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|Unique identifier of the position to add margin to|
|`amount`|`uint256`|Amount of USDC to add as margin (6 decimals)|


### removeMargin

Removes margin from an existing hedge position

*Reduces position margin while maintaining minimum margin ratio requirements*

**Notes:**
- security: Validates position ownership, active status, and minimum margin ratio

- validation: Validates amount > 0, sufficient margin available, maintains minMarginRatio

- state-changes: Decreases position margin, hedger totals, and global margin

- events: Emits MarginUpdated with removed margin details

- errors: Throws InvalidPosition, PositionNotActive, InsufficientMargin

- reentrancy: Protected by secureOperation modifier

- access: Public - requires position ownership

- oracle: No oracle dependencies for margin removal


```solidity
function removeMargin(uint256 positionId, uint256 amount) external secureOperation;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|Unique identifier of the position to remove margin from|
|`amount`|`uint256`|Amount of USDC to remove from margin (6 decimals)|


### commitLiquidation

Commits to liquidate an undercollateralized position using commit-reveal pattern

*First phase of two-phase liquidation to prevent front-running and manipulation*

**Notes:**
- security: Validates liquidator role, creates commitment hash, sets cooldown

- validation: Validates hedger address, positionId > 0, commitment doesn't exist

- state-changes: Creates liquidation commitment, sets pending liquidation flag

- events: No events emitted during commitment phase

- errors: Throws InvalidPosition, CommitmentAlreadyExists

- reentrancy: Not protected - view operations only

- access: Restricted to LIQUIDATOR_ROLE

- oracle: No oracle dependencies for commitment


```solidity
function commitLiquidation(address hedger, uint256 positionId, bytes32 salt) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger who owns the position|
|`positionId`|`uint256`|Unique identifier of the position to liquidate|
|`salt`|`bytes32`|Random salt for commitment generation to prevent replay attacks|


### liquidateHedger

Executes liquidation of an undercollateralized position

*Second phase of two-phase liquidation, requires valid commitment from commitLiquidation*

**Notes:**
- security: Validates liquidator role, commitment exists, position is liquidatable

- validation: Validates commitment hash, position ownership, active status

- state-changes: Closes position, transfers rewards, updates global totals

- events: Emits HedgerLiquidated with liquidation details

- errors: Throws InvalidHedger, PositionNotActive, PositionNotLiquidatable

- reentrancy: Protected by nonReentrant modifier

- access: Restricted to LIQUIDATOR_ROLE

- oracle: Requires fresh EUR/USD price for liquidation validation


```solidity
function liquidateHedger(address hedger, uint256 positionId, bytes32 salt)
    external
    nonReentrant
    returns (uint256 liquidationReward);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger who owns the position|
|`positionId`|`uint256`|Unique identifier of the position to liquidate|
|`salt`|`bytes32`|Same salt used in commitLiquidation for commitment verification|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`liquidationReward`|`uint256`|USDC reward paid to liquidator (6 decimals)|


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
    nonReentrant
    returns (uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`interestDifferential`|`uint256`|USDC rewards from interest rate differential (6 decimals)|
|`yieldShiftRewards`|`uint256`|USDC rewards from yield shift mechanism (6 decimals)|
|`totalRewards`|`uint256`|Total USDC rewards claimed (6 decimals)|


### _updateHedgerRewards

Updates pending rewards for a hedger based on their exposure

*Calculates rewards using interest rate differential and time-weighted exposure*

**Notes:**
- security: Validates reward calculations to prevent overflow

- validation: Validates hedger has active exposure and time elapsed

- state-changes: Updates hedger pending rewards and last reward block

- events: No events emitted

- errors: Throws RewardOverflow if reward calculation overflows

- reentrancy: Not protected - internal function only

- access: Internal function - no access restrictions

- oracle: No oracle dependencies for reward calculation


```solidity
function _updateHedgerRewards(address hedger) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|The address of the hedger to update rewards for|


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


### _isPositionLiquidatable

Check if a position is eligible for liquidation

*Position is liquidatable if margin ratio falls below liquidation threshold*

**Notes:**
- security: Validates position is active and oracle price is valid

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe arithmetic used

- reentrancy: Not applicable - view function

- access: Internal function - no access restrictions

- oracle: Requires fresh EUR/USD price for liquidation calculation


```solidity
function _isPositionLiquidatable(uint256 positionId) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|The ID of the position to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if position can be liquidated, false otherwise|


### _calculatePnL

Calculate profit/loss for a hedge position

*Calculates PnL based on price difference between entry and current price*

**Notes:**
- security: Uses safe arithmetic to prevent overflow

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe arithmetic used

- reentrancy: Not applicable - view function

- access: Internal function - no access restrictions

- oracle: Uses currentPrice parameter for PnL calculation


```solidity
function _calculatePnL(HedgePosition storage position, uint256 currentPrice) internal view returns (int256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`position`|`HedgePosition`|Storage reference to the hedge position|
|`currentPrice`|`uint256`|Current EUR/USD price for calculation|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|pnl Profit or loss (positive = profit, negative = loss)|


### getTotalHedgeExposure

Returns the total exposure across all active hedge positions

*Used for monitoring overall risk and system health*

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
function getTotalHedgeExposure() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The total exposure amount in USD equivalent|


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
|`newMinMarginRatio`|`uint256`|New minimum margin ratio in basis points (e.g., 1000 = 10%)|
|`newLiquidationThreshold`|`uint256`|New liquidation threshold in basis points (e.g., 100 = 1%)|
|`newMaxLeverage`|`uint256`|New maximum leverage multiplier (e.g., 10 = 10x)|
|`newLiquidationPenalty`|`uint256`|New liquidation penalty in basis points (e.g., 200 = 2%)|


### updateInterestRates

Updates the EUR and USD interest rates used for reward calculations

*Only callable by governance. Rates are in basis points (e.g., 500 = 5%)*

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
function updateInterestRates(uint256 newEurRate, uint256 newUsdRate) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newEurRate`|`uint256`|The new EUR interest rate in basis points|
|`newUsdRate`|`uint256`|The new USD interest rate in basis points|


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


### emergencyClosePosition

Emergency closure of a hedge position by authorized emergency role

*Bypasses normal closure process for emergency situations*

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
function emergencyClosePosition(address hedger, uint256 positionId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|The hedger who owns the position|
|`positionId`|`uint256`|The ID of the position to close|


### pause

Pauses all hedging operations in emergency situations

*Can only be called by addresses with EMERGENCY_ROLE*

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

Unpauses hedging operations after emergency is resolved

*Can only be called by addresses with EMERGENCY_ROLE*

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

### hasPendingLiquidationCommitment

Checks if a position has a pending liquidation commitment

*Used to prevent margin operations during liquidation process*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can check commitment status

- oracle: No oracle dependencies


```solidity
function hasPendingLiquidationCommitment(address hedger, uint256 positionId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger who owns the position|
|`positionId`|`uint256`|Unique identifier of the position to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|hasCommitment True if liquidation commitment exists, false otherwise|


### getHedgingConfig

Returns the current hedging configuration parameters

*Provides access to all key configuration values for hedging operations*

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
function getHedgingConfig()
    external
    view
    returns (
        uint256 minMarginRatio_,
        uint256 liquidationThreshold_,
        uint256 maxLeverage_,
        uint256 liquidationPenalty_,
        uint256 entryFee_,
        uint256 exitFee_
    );
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`minMarginRatio_`|`uint256`|Minimum margin ratio requirement|
|`liquidationThreshold_`|`uint256`|Threshold for position liquidation|
|`maxLeverage_`|`uint256`|Maximum allowed leverage|
|`liquidationPenalty_`|`uint256`|Penalty for liquidated positions|
|`entryFee_`|`uint256`|Fee for entering positions|
|`exitFee_`|`uint256`|Fee for exiting positions|


### getMaxValues

Returns the current maximum values for packed struct fields

*Useful for monitoring and debugging overflow protection*

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
function getMaxValues()
    external
    pure
    returns (
        uint256 maxPositionSize,
        uint256 maxMargin,
        uint256 maxEntryPrice,
        uint256 maxLeverageValue,
        uint256 maxTotalMargin,
        uint256 maxTotalExposure,
        uint256 maxPendingRewards
    );
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`maxPositionSize`|`uint256`|Maximum allowed position size|
|`maxMargin`|`uint256`|Maximum allowed margin|
|`maxEntryPrice`|`uint256`|Maximum allowed entry price|
|`maxLeverageValue`|`uint256`|Maximum allowed leverage|
|`maxTotalMargin`|`uint256`|Maximum allowed total margin|
|`maxTotalExposure`|`uint256`|Maximum allowed total exposure|
|`maxPendingRewards`|`uint256`|Maximum allowed pending rewards|


### isHedgingActive

Checks if hedging operations are currently active

*Returns false if contract is paused or in emergency mode*

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
function isHedgingActive() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if hedging is active, false otherwise|


### clearExpiredLiquidationCommitment

Clear expired liquidation commitment after cooldown period

*Uses block numbers instead of timestamps for security against miner manipulation*

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
function clearExpiredLiquidationCommitment(address hedger, uint256 positionId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger|
|`positionId`|`uint256`|ID of the position|


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

- oracle: No oracle dependencies for commitment cancellation


```solidity
function cancelLiquidationCommitment(address hedger, uint256 positionId, bytes32 salt) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|The hedger address|
|`positionId`|`uint256`|The position ID to cancel liquidation for|
|`salt`|`bytes32`|Same salt used in commitLiquidation for commitment verification|


### _hasPendingLiquidationCommitment

Internal function to check if a position has a pending liquidation commitment

*Used internally to prevent margin operations during liquidation process*

**Notes:**
- security: No security validations required - internal view function

- validation: No input validation required - internal function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function _hasPendingLiquidationCommitment(address hedger, uint256 positionId) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger who owns the position|
|`positionId`|`uint256`|Unique identifier of the position to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|hasCommitment True if liquidation commitment exists, false otherwise|


### recoverToken

Recovers accidentally sent ERC20 tokens from the contract

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

Recover ETH to treasury address only

*Emergency function to recover accidentally sent ETH to the contract*

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

### updateTreasury

Update treasury address

*Allows governance to update the treasury address for fee collection*

**Notes:**
- security: Validates governance role and treasury address

- validation: Validates _treasury is not address(0) and is valid

- state-changes: Updates treasury state variable

- events: Emits TreasuryUpdated with new treasury address

- errors: Throws ZeroAddress if _treasury is address(0)

- reentrancy: Not protected - no external calls

- access: Restricted to GOVERNANCE_ROLE

- oracle: No oracle dependencies


```solidity
function updateTreasury(address _treasury) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_treasury`|`address`|New treasury address|


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

## Structs
### HedgePosition

```solidity
struct HedgePosition {
    address hedger;
    uint96 positionSize;
    uint96 margin;
    uint96 entryPrice;
    uint32 entryTime;
    uint32 lastUpdateTime;
    int128 unrealizedPnL;
    uint16 leverage;
    bool isActive;
}
```

### HedgerInfo

```solidity
struct HedgerInfo {
    uint256[] positionIds;
    uint128 totalMargin;
    uint128 totalExposure;
    uint128 pendingRewards;
    uint64 lastRewardClaim;
    bool isActive;
}
```

