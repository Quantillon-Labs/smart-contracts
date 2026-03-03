# SlippageStorage
**Inherits:**
[ISlippageStorage](/src/interfaces/ISlippageStorage.sol/interface.ISlippageStorage.md), Initializable, AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable

**Title:**
SlippageStorage

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

On-chain storage for EUR/USD order book slippage data published by the Slippage Monitor service

Key features:
- WRITER_ROLE publishes slippage snapshots (mid price, spread, depth, worst-case bps)
- Rate-limited writes: rejects updates within minUpdateInterval unless deviation > threshold
- MANAGER_ROLE configures interval and threshold parameters
- Pausable by EMERGENCY_ROLE
- UUPS upgradeable

**Note:**
security-contact: team@quantillon.money


## State Variables
### WRITER_ROLE
Role for the off-chain publisher service wallet


```solidity
bytes32 public constant WRITER_ROLE = keccak256("WRITER_ROLE")
```


### MANAGER_ROLE
Role for config management (interval, threshold)


```solidity
bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE")
```


### EMERGENCY_ROLE
Role for emergency pause/unpause


```solidity
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE")
```


### UPGRADER_ROLE
Role for UUPS upgrades


```solidity
bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE")
```


### MAX_UPDATE_INTERVAL
Max allowed minUpdateInterval (1 hour)


```solidity
uint48 public constant MAX_UPDATE_INTERVAL = 3600
```


### MAX_DEVIATION_THRESHOLD
Max allowed deviation threshold (500 bps = 5%)


```solidity
uint16 public constant MAX_DEVIATION_THRESHOLD = 500
```


### _snapshot
Current slippage snapshot (2 packed storage slots)


```solidity
SlippageSnapshot private _snapshot
```


### minUpdateInterval
Minimum seconds between successive updates (rate limit)


```solidity
uint48 public override minUpdateInterval
```


### deviationThresholdBps
Deviation in bps that bypasses rate limit for immediate updates


```solidity
uint16 public override deviationThresholdBps
```


### treasury
Treasury address for recovery functions


```solidity
address public treasury
```


## Functions
### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor() ;
```

### initialize

Initialize the SlippageStorage contract

**Notes:**
- security: Validates all addresses and config bounds

- access: Public -- only callable once via initializer


```solidity
function initialize(
    address admin,
    address writer,
    uint48 minInterval,
    uint16 deviationThreshold,
    address _treasury
) external override initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address with DEFAULT_ADMIN_ROLE|
|`writer`|`address`|Address with WRITER_ROLE (publisher service wallet)|
|`minInterval`|`uint48`|Minimum seconds between updates|
|`deviationThreshold`|`uint16`|Deviation in bps that bypasses rate limit|
|`_treasury`|`address`|Treasury address for recovery functions|


### updateSlippage

Publish a new slippage snapshot on-chain

Rate-limited: if within minUpdateInterval since last update, only allows
the write when |newWorstCaseBps - lastWorstCaseBps| > deviationThresholdBps.
First update always succeeds (timestamp == 0 means no prior data).

**Notes:**
- security: WRITER_ROLE, whenNotPaused, rate-limited

- events: Emits SlippageUpdated

- errors: RateLimitTooHigh if within interval and deviation below threshold


```solidity
function updateSlippage(
    uint128 midPrice,
    uint128 depthEur,
    uint16 worstCaseBps,
    uint16 spreadBps,
    uint16[5] calldata bucketBps
) external override onlyRole(WRITER_ROLE) whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`midPrice`|`uint128`|EUR/USD mid price (18 decimals)|
|`depthEur`|`uint128`|Total ask depth in EUR (18 decimals)|
|`worstCaseBps`|`uint16`|Worst-case slippage across buckets (bps)|
|`spreadBps`|`uint16`|Bid-ask spread (bps)|
|`bucketBps`|`uint16[5]`|Per-size slippage in bps, fixed order: [10k, 50k, 100k, 250k, 1M]|


### setMinUpdateInterval

Update the minimum interval between updates

**Notes:**
- access: MANAGER_ROLE

- events: Emits ConfigUpdated


```solidity
function setMinUpdateInterval(uint48 newInterval) external override onlyRole(MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newInterval`|`uint48`|New interval in seconds (0 to MAX_UPDATE_INTERVAL)|


### setDeviationThreshold

Update the deviation threshold that bypasses rate limit

**Notes:**
- access: MANAGER_ROLE

- events: Emits ConfigUpdated


```solidity
function setDeviationThreshold(uint16 newThreshold) external override onlyRole(MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newThreshold`|`uint16`|New threshold in bps (0 to MAX_DEVIATION_THRESHOLD)|


### pause

Pause the contract (blocks updateSlippage)

**Note:**
access: EMERGENCY_ROLE


```solidity
function pause() external override onlyRole(EMERGENCY_ROLE);
```

### unpause

Unpause the contract

**Note:**
access: EMERGENCY_ROLE


```solidity
function unpause() external override onlyRole(EMERGENCY_ROLE);
```

### getSlippage

Get the current slippage snapshot


```solidity
function getSlippage() external view override returns (SlippageSnapshot memory snapshot);
```

### getBucketBps

Get per-bucket slippage bps in canonical order [10k, 50k, 100k, 250k, 1M]


```solidity
function getBucketBps() external view override returns (uint16[5] memory bucketBps);
```

### getSlippageAge

Get seconds since the last on-chain update


```solidity
function getSlippageAge() external view override returns (uint256 age);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`age`|`uint256`|Seconds since last update (0 if never updated)|


### recoverToken

Recover ERC20 tokens accidentally sent to the contract

**Note:**
access: DEFAULT_ADMIN_ROLE


```solidity
function recoverToken(address token, uint256 amount) external override onlyRole(DEFAULT_ADMIN_ROLE);
```

### recoverETH

Recover ETH accidentally sent to the contract

**Note:**
access: DEFAULT_ADMIN_ROLE


```solidity
function recoverETH() external override onlyRole(DEFAULT_ADMIN_ROLE);
```

### updateTreasury

Update treasury address

**Note:**
access: DEFAULT_ADMIN_ROLE


```solidity
function updateTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_treasury`|`address`|New treasury address|


### _authorizeUpgrade

Authorize UUPS upgrade


```solidity
function _authorizeUpgrade(address newImplementation) internal view override onlyRole(UPGRADER_ROLE);
```

### receive

Accept ETH (for recovery testing)


```solidity
receive() external payable;
```

