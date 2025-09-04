# HedgerPool
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/7a38080e43ad67d1bf394347f3ca09d4cbbceb2e/src/core/HedgerPool.sol)

**Inherits:**
Initializable, ReentrancyGuardUpgradeable, AccessControlUpgradeable, PausableUpgradeable, [SecureUpgradeable](/src/core/SecureUpgradeable.sol/abstract.SecureUpgradeable.md)

**Author:**
Quantillon Labs

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


### timeProvider
TimeProvider contract for centralized time management

*Used to replace direct block.timestamp usage for testability and consistency*


```solidity
TimeProvider public immutable timeProvider;
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


### totalYieldEarned

```solidity
uint256 public constant totalYieldEarned = 0;
```


### interestDifferentialPool

```solidity
uint256 public constant interestDifferentialPool = 0;
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

### constructor


```solidity
constructor(TimeProvider _timeProvider);
```

### initialize


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

### enterHedgePosition


```solidity
function enterHedgePosition(uint256 usdcAmount, uint256 leverage)
    external
    secureNonReentrant
    returns (uint256 positionId);
```

### exitHedgePosition


```solidity
function exitHedgePosition(uint256 positionId) external secureNonReentrant returns (int256 pnl);
```

### closePositionsBatch


```solidity
function closePositionsBatch(uint256[] calldata positionIds, uint256 maxPositions)
    external
    secureOperation
    returns (int256[] memory pnls);
```

### _closeSinglePositionBatch


```solidity
function _closeSinglePositionBatch(
    uint256 positionId,
    uint256 currentPrice,
    HedgerInfo storage hedger,
    uint256 exitFee_,
    uint256 currentTime
) internal returns (int256 pnl, uint256 marginDeducted, uint256 exposureDeducted);
```

### _removePositionFromArrays

Removes a position from internal tracking arrays

*Performs O(1) removal by swapping with last element*


```solidity
function _removePositionFromArrays(address hedger, uint256 positionId) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|The address of the hedger who owns the position|
|`positionId`|`uint256`|The ID of the position to remove|


### addMargin


```solidity
function addMargin(uint256 positionId, uint256 amount) external secureOperation;
```

### removeMargin


```solidity
function removeMargin(uint256 positionId, uint256 amount) external secureOperation;
```

### commitLiquidation


```solidity
function commitLiquidation(address hedger, uint256 positionId, bytes32 salt) external;
```

### liquidateHedger


```solidity
function liquidateHedger(address hedger, uint256 positionId, bytes32 salt)
    external
    nonReentrant
    returns (uint256 liquidationReward);
```

### claimHedgingRewards


```solidity
function claimHedgingRewards()
    external
    nonReentrant
    returns (uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards);
```

### _updateHedgerRewards

Updates pending rewards for a hedger based on their exposure

*Calculates rewards using interest rate differential and time-weighted exposure*


```solidity
function _updateHedgerRewards(address hedger) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|The address of the hedger to update rewards for|


### getHedgerPosition


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


```solidity
function getHedgerMarginRatio(address hedger, uint256 positionId) external view returns (uint256);
```

### isHedgerLiquidatable


```solidity
function isHedgerLiquidatable(address hedger, uint256 positionId) external view returns (bool);
```

### _isPositionLiquidatable

Checks if a position is eligible for liquidation

*Position is liquidatable if margin ratio falls below liquidation threshold*


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
|`<none>`|`bool`|bool True if position can be liquidated, false otherwise|


### _calculatePnL


```solidity
function _calculatePnL(HedgePosition storage position, uint256 currentPrice) internal view returns (int256);
```

### getTotalHedgeExposure

Returns the total exposure across all active hedge positions

*Used for monitoring overall risk and system health*


```solidity
function getTotalHedgeExposure() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The total exposure amount in USD equivalent|


### updateHedgingParameters


```solidity
function updateHedgingParameters(
    uint256 newMinMarginRatio,
    uint256 newLiquidationThreshold,
    uint256 newMaxLeverage,
    uint256 newLiquidationPenalty
) external;
```

### updateInterestRates

Updates the EUR and USD interest rates used for reward calculations

*Only callable by governance. Rates are in basis points (e.g., 500 = 5%)*


```solidity
function updateInterestRates(uint256 newEurRate, uint256 newUsdRate) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newEurRate`|`uint256`|The new EUR interest rate in basis points|
|`newUsdRate`|`uint256`|The new USD interest rate in basis points|


### setHedgingFees


```solidity
function setHedgingFees(uint256 _entryFee, uint256 _exitFee, uint256 _marginFee) external;
```

### emergencyClosePosition

Emergency closure of a hedge position by authorized emergency role

*Bypasses normal closure process for emergency situations*


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


```solidity
function pause() external;
```

### unpause

Unpauses hedging operations after emergency is resolved

*Can only be called by addresses with EMERGENCY_ROLE*


```solidity
function unpause() external;
```

### hasPendingLiquidationCommitment


```solidity
function hasPendingLiquidationCommitment(address hedger, uint256 positionId) external view returns (bool);
```

### getHedgingConfig

Returns the current hedging configuration parameters

*Provides access to all key configuration values for hedging operations*


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


```solidity
function getMaxValues()
    external
    view
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


```solidity
function cancelLiquidationCommitment(address hedger, uint256 positionId, bytes32 salt) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|The hedger address|
|`positionId`|`uint256`|The position ID to cancel liquidation for|
|`salt`|`bytes32`||


### _hasPendingLiquidationCommitment


```solidity
function _hasPendingLiquidationCommitment(address hedger, uint256 positionId) internal view returns (bool);
```

### recoverToken

Recovers accidentally sent ERC20 tokens from the contract

*Emergency function to recover tokens that are not part of normal operations*


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


```solidity
function recoverETH() external;
```

### updateTreasury

Update treasury address


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

