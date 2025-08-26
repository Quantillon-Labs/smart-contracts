# HedgerPool
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/2ed390346abaeb7aea3465c14f74d96e70dc2cba/src/core/HedgerPool.sol)

**Inherits:**
Initializable, ReentrancyGuardUpgradeable, AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable

**Author:**
Quantillon Labs

Manages EUR/USD hedging positions, margin, and hedger rewards

*Main characteristics:
- Dual-pool mechanism for EUR/USD hedging
- Margin-based position management
- Liquidation mechanisms for risk management
- Dynamic fee structure for protocol sustainability
- Interest rate differential handling
- Hedger reward distribution system
- Emergency pause mechanism for crisis situations
- Upgradeable via UUPS pattern*

*Hedging mechanics:
- Hedgers provide USDC margin to open EUR/USD positions
- Positions are leveraged based on margin and market conditions
- P&L is calculated based on EUR/USD price movements
- Liquidation occurs when margin ratio falls below threshold
- Hedgers earn rewards for providing liquidity and taking risk*

*Risk management:
- Minimum margin ratio requirements
- Liquidation thresholds and penalties
- Maximum leverage limits
- Position size limits
- Real-time P&L tracking
- Emergency pause capabilities*

*Fee structure:
- Entry fees for opening positions
- Exit fees for closing positions
- Margin fees for margin operations
- Liquidation penalties for risk management
- Dynamic fee adjustment based on market conditions*

*Security features:
- Role-based access control for all critical operations
- Reentrancy protection for all external calls
- Emergency pause mechanism for crisis situations
- Upgradeable architecture for future improvements
- Secure margin and position management
- Oracle price validation*

*Integration points:
- Chainlink oracle for EUR/USD price feeds
- Yield shift mechanism for interest rate management
- Vault math library for calculations
- USDC for margin and settlement*

**Note:**
security-contact: team@quantillon.money


## State Variables
### GOVERNANCE_ROLE
Role for governance operations (parameter updates, emergency actions)

*keccak256 hash avoids role collisions with other contracts*

*Should be assigned to governance multisig or DAO*


```solidity
bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
```


### LIQUIDATOR_ROLE
Role for liquidating undercollateralized positions

*keccak256 hash avoids role collisions with other contracts*

*Should be assigned to trusted liquidators or automated systems*


```solidity
bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
```


### EMERGENCY_ROLE
Role for emergency operations (pause, emergency liquidations)

*keccak256 hash avoids role collisions with other contracts*

*Should be assigned to emergency multisig*


```solidity
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
```


### UPGRADER_ROLE
Role for performing contract upgrades via UUPS pattern

*keccak256 hash avoids role collisions with other contracts*

*Should be assigned to governance or upgrade multisig*


```solidity
bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
```


### usdc
USDC token contract for margin and settlement

*Used for all margin deposits, withdrawals, and fee payments*

*Should be the official USDC contract on the target network*


```solidity
IERC20 public usdc;
```


### oracle
Chainlink oracle contract for EUR/USD price feeds

*Provides real-time EUR/USD exchange rates for position calculations*

*Used for P&L calculations and liquidation checks*


```solidity
IChainlinkOracle public oracle;
```


### yieldShift
Yield shift mechanism for interest rate management

*Handles interest rate differentials between EUR and USD*

*Used for funding rate calculations and yield distribution*


```solidity
IYieldShift public yieldShift;
```


### minMarginRatio
Minimum margin ratio required for positions (in basis points)

*Example: 1000 = 10% minimum margin ratio*

*Used to prevent excessive leverage and manage risk*


```solidity
uint256 public minMarginRatio;
```


### liquidationThreshold
Liquidation threshold below which positions can be liquidated (in basis points)

*Example: 500 = 5% liquidation threshold*

*Must be lower than minMarginRatio to provide buffer*


```solidity
uint256 public liquidationThreshold;
```


### maxLeverage
Maximum allowed leverage for positions

*Example: 10 = 10x maximum leverage*

*Used to limit risk exposure and prevent excessive speculation*


```solidity
uint256 public maxLeverage;
```


### liquidationPenalty
Penalty charged during liquidations (in basis points)

*Example: 200 = 2% liquidation penalty*

*Incentivizes hedgers to maintain adequate margin*


```solidity
uint256 public liquidationPenalty;
```


### MAX_POSITIONS_PER_HEDGER

```solidity
uint256 public constant MAX_POSITIONS_PER_HEDGER = 50;
```


### activePositionCount

```solidity
mapping(address => uint256) public activePositionCount;
```


### entryFee
Fee charged when opening positions (in basis points)

*Example: 50 = 0.5% entry fee*

*Revenue source for the protocol*


```solidity
uint256 public entryFee;
```


### exitFee
Fee charged when closing positions (in basis points)

*Example: 30 = 0.3% exit fee*

*Revenue source for the protocol*


```solidity
uint256 public exitFee;
```


### marginFee
Fee charged for margin operations (in basis points)

*Example: 10 = 0.1% margin fee*

*Revenue source for the protocol*


```solidity
uint256 public marginFee;
```


### totalMargin
Total margin deposited across all active positions

*Sum of all margin amounts across all hedgers*

*Used for pool analytics and risk management*


```solidity
uint256 public totalMargin;
```


### totalExposure
Total EUR/USD exposure across all positions

*Net exposure of the pool to EUR/USD price movements*

*Used for risk management and hedging calculations*


```solidity
uint256 public totalExposure;
```


### activeHedgers
Number of active hedgers with open positions

*Count of unique addresses with active positions*

*Used for protocol analytics and governance*


```solidity
uint256 public activeHedgers;
```


### nextPositionId
Next position ID to be assigned

*Auto-incremented for each new position*

*Used to generate unique position identifiers*


```solidity
uint256 public nextPositionId;
```


### eurInterestRate
EUR interest rate (in basis points)

*Example: 400 = 4% EUR interest rate*

*Used for funding rate calculations*


```solidity
uint256 public eurInterestRate;
```


### usdInterestRate
USD interest rate (in basis points)

*Example: 500 = 5% USD interest rate*

*Used for funding rate calculations*


```solidity
uint256 public usdInterestRate;
```


### positions
Positions by position ID

*Maps position IDs to position data*

*Used to store and retrieve position information*


```solidity
mapping(uint256 => HedgePosition) public positions;
```


### hedgers
Hedger information by address

*Maps hedger addresses to their aggregated information*

*Used to track hedger activity and rewards*


```solidity
mapping(address => HedgerInfo) public hedgers;
```


### hedgerPositions

```solidity
mapping(address => uint256[]) public hedgerPositions;
```


### totalYieldEarned
Total yield earned by hedgers in QTI tokens

*Sum of interest differential rewards and yield shift rewards*


```solidity
uint256 public totalYieldEarned;
```


### interestDifferentialPool
Pool of interest differential rewards

*Rewards distributed to hedgers based on their exposure to interest rate differentials*


```solidity
uint256 public interestDifferentialPool;
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

```solidity
uint256 public constant LIQUIDATION_COOLDOWN = 1 hours;
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
### constructor


```solidity
constructor();
```

### initialize


```solidity
function initialize(address admin, address _usdc, address _oracle, address _yieldShift) public initializer;
```

### enterHedgePosition

Enter a new EUR/USD hedging position (short EUR/USD)

*This function allows hedgers to open a new EUR/USD hedging position.
- Hedgers provide USDC margin.
- A fee is charged based on the entry fee percentage.
- The position size is calculated based on the net margin and leverage.
- The margin ratio is checked against the minimum required.
- The USDC margin is transferred from the hedger to the contract.
- A new position is created and stored.
- Hedger info and pool totals are updated.
- An event is emitted.*


```solidity
function enterHedgePosition(uint256 usdcAmount, uint256 leverage)
    external
    nonReentrant
    whenNotPaused
    returns (uint256 positionId);
```

### exitHedgePosition

Exit an existing hedging position

*This function allows hedgers to close an existing EUR/USD hedging position.
- The hedger must be the owner of the position.
- The position must be active.
- The current EUR/USD price is fetched.
- The P&L is calculated based on the current price.
- An exit fee is charged.
- Hedger info and pool totals are updated.
- The position is deactivated and removed from arrays.
- The payout is transferred to the hedger.
- An event is emitted.*


```solidity
function exitHedgePosition(uint256 positionId) external nonReentrant whenNotPaused returns (int256 pnl);
```

### _removePositionFromArrays

Remove position from hedger arrays to prevent DoS


```solidity
function _removePositionFromArrays(address hedger, uint256 positionId) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger|
|`positionId`|`uint256`|Position ID to remove|


### partialClosePosition

Partially close a hedging position

*This function allows hedgers to partially close an existing EUR/USD hedging position.
- The hedger must be the owner of the position.
- The position must be active.
- The current EUR/USD price is fetched.
- Partial amounts are calculated based on the percentage.
- The P&L for the partial position is calculated.
- The payout is calculated.
- The position is updated.
- Hedger info and pool totals are updated.
- The payout is transferred to the hedger.
- The partial P&L is returned.*


```solidity
function partialClosePosition(uint256 positionId, uint256 percentage)
    external
    nonReentrant
    whenNotPaused
    returns (int256 pnl);
```

### addMargin

Add margin to an existing position

*This function allows hedgers to add margin to an existing EUR/USD hedging position.
- The hedger must be the owner of the position.
- The position must be active.
- The amount of margin to add must be positive.
- A margin fee is charged.
- The USDC margin is transferred from the hedger to the contract.
- The position margin is updated.
- Hedger and pool totals are updated.
- A new margin ratio is calculated.
- An event is emitted.*

*Front-running protection:
- Cannot add margin during liquidation cooldown period
- Cannot add margin if there are pending liquidation commitments
- Prevents hedgers from front-running liquidation attempts*


```solidity
function addMargin(uint256 positionId, uint256 amount) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|Position ID to add margin to|
|`amount`|`uint256`|Amount of USDC to add as margin|


### removeMargin

Remove excess margin from a position

*This function allows hedgers to remove margin from an existing EUR/USD hedging position.
- The hedger must be the owner of the position.
- The position must be active.
- The amount of margin to remove must be positive.
- The position must have sufficient margin.
- The new margin ratio is checked against the minimum required.
- The position margin is updated.
- Hedger and pool totals are updated.
- The USDC margin is transferred back to the hedger.
- An event is emitted.*


```solidity
function removeMargin(uint256 positionId, uint256 amount) external nonReentrant whenNotPaused;
```

### commitLiquidation

Commit to a liquidation to prevent front-running


```solidity
function commitLiquidation(address hedger, uint256 positionId, bytes32 salt) external onlyRole(LIQUIDATOR_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger to liquidate|
|`positionId`|`uint256`|Position ID to liquidate|
|`salt`|`bytes32`|Random salt for commitment|


### liquidateHedger

Liquidate an undercollateralized hedger position with immediate execution

*This function allows liquidators to liquidate an undercollateralized hedger position.
- The liquidator must have the LIQUIDATOR_ROLE.
- The hedger must be the owner of the position.
- The position must be active.
- The position must be liquidatable.
- The current EUR/USD price is fetched.
- The liquidation reward is calculated.
- The remaining margin is calculated.
- Hedger info and pool totals are updated.
- The position is deactivated and removed from arrays.
- The liquidation reward is transferred to the liquidator.
- The remaining margin is transferred back to the hedger if any.
- An event is emitted.
- Front-running protection via immediate execution after commitment.*


```solidity
function liquidateHedger(address hedger, uint256 positionId, bytes32 salt)
    external
    onlyRole(LIQUIDATOR_ROLE)
    nonReentrant
    returns (uint256 liquidationReward);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger to liquidate|
|`positionId`|`uint256`|Position ID to liquidate|
|`salt`|`bytes32`|Salt used in the commitment|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`liquidationReward`|`uint256`|Amount of liquidation reward|


### claimHedgingRewards

Claim hedging rewards (interest differential + yield shift)

*This function allows hedgers to claim their accumulated hedging rewards.
- Only the hedger themselves can call this function.
- The pending rewards are updated using block-based calculations.
- The interest differential reward is calculated.
- The yield shift rewards are fetched from the yield shift mechanism.
- The total rewards are summed.
- If total rewards are greater than zero, they are transferred to the hedger.
- The last reward claim timestamp is updated.
- The yield shift rewards are claimed if applicable.
- An event is emitted.*


```solidity
function claimHedgingRewards()
    external
    nonReentrant
    returns (uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards);
```

### _updateHedgerRewards

Update hedger rewards based on interest rate differential

*This internal function calculates and updates the pending hedging rewards
for a given hedger based on their total exposure and the interest rate differential.
- It calculates the interest differential reward.
- It calculates the reward amount based on the hedger's total exposure,
the interest differential, and the time elapsed since the last claim.
- The pending rewards are incremented with overflow protection.
- Uses block-based calculations to prevent timestamp manipulation.*


```solidity
function _updateHedgerRewards(address hedger) internal;
```

### getHedgerPosition

Get detailed information about a specific hedger's position

*This function allows external contracts to query a hedger's position by ID.
- It fetches the position data from storage.
- It validates that the hedger is the owner of the position.
- It fetches the current EUR/USD price from the oracle.
- It returns the position size, margin, entry price, current price, leverage,
and last update time.*


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

### getHedgerMarginRatio

Get the margin ratio of a specific hedger's position

*This function allows external contracts to query the margin ratio of a hedger's position.
- It fetches the position data from storage.
- It validates that the hedger is the owner of the position.
- It returns the margin ratio in basis points.*


```solidity
function getHedgerMarginRatio(address hedger, uint256 positionId) external view returns (uint256);
```

### isHedgerLiquidatable

Check if a hedger's position is liquidatable

*This function allows external contracts to query if a hedger's position is at risk of liquidation.
- It fetches the position data from storage.
- It validates that the hedger is the owner of the position.
- It checks if the position is active.
- It fetches the current EUR/USD price from the oracle.
- It calculates the effective margin including unrealized P&L.
- It checks if the effective margin is less than or equal to zero.
- It returns true if liquidatable, false otherwise.*


```solidity
function isHedgerLiquidatable(address hedger, uint256 positionId) external view returns (bool);
```

### _isPositionLiquidatable

Internal function to check if a position is liquidatable

*This function is used by the liquidation system to determine if a position
is at risk of liquidation.
- It fetches the position data from storage.
- It checks if the position is active.
- It fetches the current EUR/USD price from the oracle.
- It calculates the effective margin including unrealized P&L.
- It checks if the effective margin is less than or equal to zero.
- It returns true if liquidatable, false otherwise.*


```solidity
function _isPositionLiquidatable(uint256 positionId) internal view returns (bool);
```

### _calculatePnL

Internal function to calculate P&L for a hedging position

*This function calculates the profit or loss of a hedging position based on
the current EUR/USD price and the position's entry price.
- For a short EUR/USD position, profit is made when EUR/USD falls.
- The P&L is calculated as the difference between the current price and entry price,
multiplied by the position size and divided by the entry price.
- Uses safe arithmetic operations to prevent overflow.*


```solidity
function _calculatePnL(HedgePosition storage position, uint256 currentPrice) internal view returns (int256);
```

### getTotalHedgeExposure

Get the total EUR/USD exposure of the hedger pool

*This function allows external contracts to query the total EUR/USD exposure
of the hedger pool.
- It returns the totalExposure variable.*


```solidity
function getTotalHedgeExposure() external view returns (uint256);
```

### getPoolStatistics

Get statistics about the hedger pool

*This function allows external contracts to query various statistics
about the hedger pool, such as the number of active hedgers, total positions,
average position size, total margin, and pool utilization.*


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

### getPendingHedgingRewards

Get pending hedging rewards for a specific hedger

*This function allows external contracts to query the pending hedging rewards
for a specific hedger, including interest differential and yield shift rewards.
- It calculates the pending interest differential using block-based calculations.
- It fetches the pending yield shift rewards from the yield shift mechanism.
- It sums up the total pending rewards.*


```solidity
function getPendingHedgingRewards(address hedger)
    external
    view
    returns (uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalPending);
```

### updateHedgingParameters

Update hedging parameters (margin ratio, liquidation, leverage, fees)

*This function allows governance to update critical parameters of the hedging mechanism.
- It requires new values to be within reasonable bounds.
- It updates the minMarginRatio, liquidationThreshold, maxLeverage, and liquidationPenalty.*


```solidity
function updateHedgingParameters(
    uint256 newMinMarginRatio,
    uint256 newLiquidationThreshold,
    uint256 newMaxLeverage,
    uint256 newLiquidationPenalty
) external onlyRole(GOVERNANCE_ROLE);
```

### updateInterestRates

Update interest rates for EUR and USD

*This function allows governance to update the interest rates for EUR and USD.
- It requires new rates to be within reasonable bounds.
- It updates the eurInterestRate and usdInterestRate.*


```solidity
function updateInterestRates(uint256 newEurRate, uint256 newUsdRate) external onlyRole(GOVERNANCE_ROLE);
```

### setHedgingFees

Set hedging fees (entry, exit, margin)

*This function allows governance to set the fees for entering, exiting, and margin operations.
- It requires new fees to be within reasonable bounds.
- It updates the entryFee, exitFee, and marginFee.*


```solidity
function setHedgingFees(uint256 _entryFee, uint256 _exitFee, uint256 _marginFee) external onlyRole(GOVERNANCE_ROLE);
```

### getHedgerPositionStats

Get position statistics for a hedger


```solidity
function getHedgerPositionStats(address hedger)
    external
    view
    returns (uint256 totalPositions, uint256 activePositions, uint256 totalMargin_, uint256 totalExposure_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalPositions`|`uint256`|Total number of positions (active + inactive)|
|`activePositions`|`uint256`|Number of active positions|
|`totalMargin_`|`uint256`|Total margin across all positions|
|`totalExposure_`|`uint256`|Total exposure across all positions|


### emergencyClosePosition

Emergency close a hedger's position

*This function allows emergency roles to forcibly close a hedger's position
in case of emergency.
- The hedger must be the owner of the position.
- The position must be active.
- Hedger info and pool totals are updated.
- The margin is returned to the hedger.
- The position is deactivated and removed from arrays.*


```solidity
function emergencyClosePosition(address hedger, uint256 positionId) external onlyRole(EMERGENCY_ROLE);
```

### pause

Pause the hedger pool

*This function allows emergency roles to pause the hedger pool in case of crisis.*


```solidity
function pause() external onlyRole(EMERGENCY_ROLE);
```

### unpause

Unpause the hedger pool

*This function allows emergency roles to unpause the hedger pool after a crisis.*


```solidity
function unpause() external onlyRole(EMERGENCY_ROLE);
```

### hasPendingLiquidationCommitment

Check if a hedger has pending liquidation commitments


```solidity
function hasPendingLiquidationCommitment(address hedger, uint256 positionId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger|
|`positionId`|`uint256`|Position ID to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if there are pending liquidation commitments|


### getHedgingConfig

Get current hedging configuration parameters

*This function allows external contracts to query the current hedging configuration
parameters, such as minimum margin ratio, liquidation threshold, max leverage,
liquidation penalty, entry fee, and exit fee.*


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

### isHedgingActive

Check if hedging is currently active

*This function allows external contracts to query if the hedger pool is
currently active (not paused).*


```solidity
function isHedgingActive() external view returns (bool);
```

### clearExpiredLiquidationCommitment

Internal function for UUPS upgrade authorization

Clear expired liquidation commitments for a hedger/position

*This function is called by the UUPS upgrade mechanism to authorize
the upgrade to a new implementation.
- It requires the caller to have the UPGRADER_ROLE.*

*This function allows clearing of expired commitments that were never executed*

*Only callable by liquidators or governance*

*Note: With immediate execution, this is mainly for cleanup of stale commitments*


```solidity
function clearExpiredLiquidationCommitment(address hedger, uint256 positionId) external onlyRole(LIQUIDATOR_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger|
|`positionId`|`uint256`|Position ID|


### cancelLiquidationCommitment

Cancel a liquidation commitment (only by the liquidator who created it)

*This function allows liquidators to cancel their own commitments*

*Only callable by the liquidator who created the commitment*


```solidity
function cancelLiquidationCommitment(address hedger, uint256 positionId, bytes32 salt)
    external
    onlyRole(LIQUIDATOR_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger|
|`positionId`|`uint256`|Position ID|
|`salt`|`bytes32`|Salt used in the original commitment|


### _authorizeUpgrade


```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE);
```

### _hasPendingLiquidationCommitment

Check if a hedger has any pending liquidation commitments


```solidity
function _hasPendingLiquidationCommitment(address hedger, uint256 positionId) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger|
|`positionId`|`uint256`|Position ID to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if any commitment exists for this hedger/position, false otherwise|


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

## Structs
### HedgePosition
Hedge position data structure

*Stores all information about a single hedging position*

*Used for position management and P&L calculations*


```solidity
struct HedgePosition {
    address hedger;
    uint256 positionSize;
    uint256 margin;
    uint256 entryPrice;
    uint256 leverage;
    uint256 entryTime;
    uint256 lastUpdateTime;
    int256 unrealizedPnL;
    bool isActive;
}
```

### HedgerInfo
Hedger information data structure

*Stores aggregated information about a hedger's activity*

*Used for reward calculations and risk management*


```solidity
struct HedgerInfo {
    uint256[] positionIds;
    uint256 totalMargin;
    uint256 totalExposure;
    uint256 pendingRewards;
    uint256 lastRewardClaim;
    bool isActive;
}
```

