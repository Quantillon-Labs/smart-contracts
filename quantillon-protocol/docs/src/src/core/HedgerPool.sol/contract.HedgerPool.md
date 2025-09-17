# HedgerPool
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/bbddbedca72271d4260ea804101124f3dc71302c/src/core/HedgerPool.sol)

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
- Positions require minimum margin ratio (default 10%)
- Maximum leverage of 10x to limit risk exposure
- Position sizes tracked for risk management
- Entry and exit fees charged for protocol revenue*

*Margin system:
- Initial margin required for position opening
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
- Validates position ownership to prevent unauthorized access

- Validates hedger address and positionId > 0

- No state changes - view function only

- No events emitted

- Throws InvalidHedger if hedger doesn't own the position

- Not applicable - view function

- Internal function - no access restrictions

- No oracle dependencies


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
- Validates oracle price freshness and validity

- Validates oracle price is valid and not stale

- No state changes - view function only

- No events emitted

- Throws InvalidOraclePrice if oracle price is invalid

- Not applicable - view function

- Internal function - no access restrictions

- Requires fresh EUR/USD price from Chainlink oracle


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
- Validates caller has the required role for access control

- Validates role parameter is a valid role constant

- No state changes - view function only

- No events emitted

- Throws "Invalid role" if role is not recognized

- Not applicable - view function

- Internal function - no access restrictions

- No oracle dependencies


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
- Validates TimeProvider address is not zero

- Validates _TIME_PROVIDER is not address(0)

- Sets TIME_PROVIDER immutable variable and disables initializers

- No events emitted

- Throws ZeroAddress if _TIME_PROVIDER is address(0)

- Not applicable - constructor

- Public - anyone can deploy

- No oracle dependencies


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
- Validates all addresses are not zero, grants admin roles

- Validates all input addresses using AccessControlLibrary

- Initializes all state variables, sets default fees and parameters

- No events emitted during initialization

- Throws ZeroAddress if any address is address(0)

- Protected by initializer modifier

- Public - only callable once during deployment

- Sets oracle address for EUR/USD price feeds


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
- Validates oracle price freshness, enforces margin ratios and leverage limits

- Validates usdcAmount > 0, leverage <= maxLeverage, position count limits

- Creates new HedgePosition, updates hedger totals, increments position counters

- Emits HedgePositionOpened with position details

- Throws InvalidAmount, InvalidLeverage, InvalidOraclePrice, RateLimitExceeded

- Protected by secureNonReentrant modifier

- Public - requires sufficient USDC balance and approval

- Requires fresh EUR/USD price from Chainlink oracle


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
- Validates position ownership and active status, enforces oracle price freshness

- Validates position exists, is active, and owned by caller

- Closes position, updates hedger totals, decrements position counters

- Emits HedgePositionClosed with PnL and exit details

- Throws InvalidPosition, PositionNotActive, InvalidOraclePrice

- Protected by secureNonReentrant modifier

- Public - requires position ownership

- Requires fresh EUR/USD price from Chainlink oracle


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


### closePositionsBatch

Closes multiple hedge positions in a single transaction

*Batch closes positions for gas efficiency, applies same validations as single close*

**Notes:**
- Validates batch size limits and position ownership for each position

- Validates positionIds.length <= maxPositions, maxPositions <= 10

- Closes all positions, updates hedger totals, decrements position counters

- Emits HedgePositionClosed for each closed position

- Throws BatchSizeTooLarge, TooManyPositionsPerTx, MaxPositionsPerTx

- Protected by secureOperation modifier

- Public - requires position ownership for all positions

- Requires fresh EUR/USD price from Chainlink oracle


```solidity
function closePositionsBatch(uint256[] calldata positionIds, uint256 maxPositions)
    external
    secureOperation
    returns (int256[] memory pnls);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionIds`|`uint256[]`|Array of position IDs to close|
|`maxPositions`|`uint256`|Maximum number of positions allowed per transaction|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`pnls`|`int256[]`|Array of profit/loss for each closed position|


### _closeSinglePositionBatchOptimized

Optimized internal function to close a single position in batch operation

*Internal helper for batch position closing without external calls or costly operations in loop*

**Notes:**
- Validates position ownership and active status

- Validates position exists and is active

- Closes position, updates hedger totals, emits events

- Emits HedgePositionClosed event

- Throws InvalidPosition, PositionNotActive

- Not protected - internal function only

- Internal function - no access restrictions

- Uses currentPrice parameter for PnL calculation


```solidity
function _closeSinglePositionBatchOptimized(uint256 positionId, uint256 currentPrice, uint256 currentTime)
    internal
    returns (int256 pnl, uint256 marginDeducted, uint256 exposureDeducted);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|ID of the position to close|
|`currentPrice`|`uint256`|Current EUR/USD price for PnL calculation|
|`currentTime`|`uint256`|Cached timestamp to avoid external calls|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`pnl`|`int256`|Profit or loss from the position|
|`marginDeducted`|`uint256`|Amount of margin to deduct from global totals|
|`exposureDeducted`|`uint256`|Amount of exposure to deduct from global totals|


### _removePositionFromArrays

Removes a position from internal tracking arrays

*Performs O(1) removal by swapping with last element*

**Notes:**
- Validates position exists in tracking arrays

- Validates hedgerHasPosition mapping is true

- Removes position from arrays, cleans up mappings

- No events emitted

- Throws PositionNotFound if position not in tracking arrays

- Not protected - internal function only

- Internal function - no access restrictions

- No oracle dependencies


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
- Validates position ownership, active status, and liquidation cooldown

- Validates amount > 0, position exists and is active, no pending liquidation

- Increases position margin, hedger totals, and global margin

- Emits MarginUpdated with added margin details

- Throws InvalidPosition, PositionNotActive, PendingLiquidationCommitment

- Protected by secureOperation modifier

- Public - requires position ownership

- No oracle dependencies for margin addition


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
- Validates position ownership, active status, and minimum margin ratio

- Validates amount > 0, sufficient margin available, maintains minMarginRatio

- Decreases position margin, hedger totals, and global margin

- Emits MarginUpdated with removed margin details

- Throws InvalidPosition, PositionNotActive, InsufficientMargin

- Protected by secureOperation modifier

- Public - requires position ownership

- No oracle dependencies for margin removal


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
- Validates liquidator role, creates commitment hash, sets cooldown

- Validates hedger address, positionId > 0, commitment doesn't exist

- Creates liquidation commitment, sets pending liquidation flag

- No events emitted during commitment phase

- Throws InvalidPosition, CommitmentAlreadyExists

- Not protected - view operations only

- Restricted to LIQUIDATOR_ROLE

- No oracle dependencies for commitment


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
- Validates liquidator role, commitment exists, position is liquidatable

- Validates commitment hash, position ownership, active status

- Closes position, transfers rewards, updates global totals

- Emits HedgerLiquidated with liquidation details

- Throws InvalidHedger, PositionNotActive, PositionNotLiquidatable

- Protected by nonReentrant modifier

- Restricted to LIQUIDATOR_ROLE

- Requires fresh EUR/USD price for liquidation validation


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
- Validates reward calculations to prevent overflow

- Validates hedger has active exposure and time elapsed

- Updates hedger pending rewards and last reward block

- No events emitted

- Throws RewardOverflow if reward calculation overflows

- Not protected - internal function only

- Internal function - no access restrictions

- No oracle dependencies for reward calculation


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


### _isPositionLiquidatable

Check if a position is eligible for liquidation

*Position is liquidatable if margin ratio falls below liquidation threshold*

**Notes:**
- Validates position is active and oracle price is valid

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe arithmetic used

- Not applicable - view function

- Internal function - no access restrictions

- Requires fresh EUR/USD price for liquidation calculation


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
- Uses safe arithmetic to prevent overflow

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe arithmetic used

- Not applicable - view function

- Internal function - no access restrictions

- Uses currentPrice parameter for PnL calculation


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

Updates the EUR and USD interest rates used for reward calculations

*Only callable by governance. Rates are in basis points (e.g., 500 = 5%)*

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

Emergency closure of a hedge position by authorized emergency role

*Bypasses normal closure process for emergency situations*

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

Unpauses hedging operations after emergency is resolved

*Can only be called by addresses with EMERGENCY_ROLE*

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

### hasPendingLiquidationCommitment

Checks if a position has a pending liquidation commitment

*Used to prevent margin operations during liquidation process*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can check commitment status

- No oracle dependencies


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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
- Validates liquidator role and commitment exists

- Validates commitment hash matches stored commitment

- Deletes liquidation commitment and pending liquidation flag

- No events emitted for commitment cancellation

- Throws CommitmentNotFound if commitment doesn't exist

- Not protected - no external calls

- Restricted to LIQUIDATOR_ROLE

- No oracle dependencies for commitment cancellation


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
- No security validations required - internal view function

- No input validation required - internal function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Internal function - no access restrictions

- No oracle dependencies


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
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

### updateTreasury

Update treasury address

*Allows governance to update the treasury address for fee collection*

**Notes:**
- Validates governance role and treasury address

- Validates _treasury is not address(0) and is valid

- Updates treasury state variable

- Emits TreasuryUpdated with new treasury address

- Throws ZeroAddress if _treasury is address(0)

- Not protected - no external calls

- Restricted to GOVERNANCE_ROLE

- No oracle dependencies


```solidity
function updateTreasury(address _treasury) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_treasury`|`address`|New treasury address|


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

