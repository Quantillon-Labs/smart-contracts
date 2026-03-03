# ISlippageStorage
**Title:**
ISlippageStorage

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Interface for the Quantillon SlippageStorage contract

Stores on-chain slippage data published by an off-chain service.
Provides rate-limited writes via WRITER_ROLE and config management via MANAGER_ROLE.

**Note:**
security-contact: team@quantillon.money


## Functions
### initialize

Initialize the contract


```solidity
function initialize(
    address admin,
    address writer,
    uint48 minInterval,
    uint16 deviationThreshold,
    address treasury
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address with DEFAULT_ADMIN_ROLE|
|`writer`|`address`|Address with WRITER_ROLE (publisher service wallet)|
|`minInterval`|`uint48`|Minimum seconds between updates (rate limit)|
|`deviationThreshold`|`uint16`|Deviation in bps that bypasses rate limit|
|`treasury`|`address`|Treasury address for recovery functions|


### updateSlippage

Publish a new slippage snapshot on-chain

WRITER_ROLE only. Rate-limited: rejects if within minUpdateInterval
unless |newWorstCaseBps - lastWorstCaseBps| > deviationThresholdBps.


```solidity
function updateSlippage(
    uint128 midPrice,
    uint128 depthEur,
    uint16 worstCaseBps,
    uint16 spreadBps,
    uint16[5] calldata bucketBps
) external;
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


```solidity
function setMinUpdateInterval(uint48 newInterval) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newInterval`|`uint48`|New interval in seconds|


### setDeviationThreshold

Update the deviation threshold that bypasses rate limit


```solidity
function setDeviationThreshold(uint16 newThreshold) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newThreshold`|`uint16`|New threshold in bps|


### pause

Pause the contract (blocks updateSlippage)


```solidity
function pause() external;
```

### unpause

Unpause the contract


```solidity
function unpause() external;
```

### getSlippage

Get the current slippage snapshot


```solidity
function getSlippage() external view returns (SlippageSnapshot memory snapshot);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`snapshot`|`SlippageSnapshot`|The latest SlippageSnapshot struct|


### getBucketBps

Get per-bucket slippage bps in canonical order [10k, 50k, 100k, 250k, 1M]


```solidity
function getBucketBps() external view returns (uint16[5] memory bucketBps);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`bucketBps`|`uint16[5]`|Array of 5 uint16 bps values|


### getSlippageAge

Get seconds since the last on-chain update


```solidity
function getSlippageAge() external view returns (uint256 age);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`age`|`uint256`|Seconds since last update (0 if never updated)|


### minUpdateInterval

Get the current minimum update interval


```solidity
function minUpdateInterval() external view returns (uint48 interval);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`interval`|`uint48`|Seconds|


### deviationThresholdBps

Get the current deviation threshold


```solidity
function deviationThresholdBps() external view returns (uint16 threshold);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`threshold`|`uint16`|Bps|


### recoverToken

Recover ERC20 tokens accidentally sent to the contract


```solidity
function recoverToken(address token, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address|
|`amount`|`uint256`|Amount to recover|


### recoverETH

Recover ETH accidentally sent to the contract


```solidity
function recoverETH() external;
```

## Events
### SlippageUpdated
Emitted when slippage data is updated on-chain


```solidity
event SlippageUpdated(uint128 midPrice, uint16 worstCaseBps, uint16 spreadBps, uint128 depthEur, uint48 timestamp);
```

### ConfigUpdated
Emitted when a config parameter is changed


```solidity
event ConfigUpdated(string indexed param, uint256 oldValue, uint256 newValue);
```

### TreasuryUpdated
Emitted when treasury address is updated


```solidity
event TreasuryUpdated(address indexed newTreasury);
```

### ETHRecovered
Emitted when ETH is recovered from the contract


```solidity
event ETHRecovered(address indexed to, uint256 amount);
```

## Structs
### SlippageSnapshot
Packed on-chain slippage snapshot (2 storage slots)

Storage layout (must not be reordered — UUPS upgrade-safe):
Slot 0 (32 bytes): midPrice (uint128) + depthEur (uint128)
Slot 1 (26/32 bytes): worstCaseBps (2) + spreadBps (2) + timestamp (6) +
blockNumber (6) + bps10k (2) + bps50k (2) + bps100k (2) + bps250k (2) + bps1M (2)
Individual uint16 fields are used instead of uint16[5] because Solidity
arrays always start a new storage slot, which would waste a full slot.


```solidity
struct SlippageSnapshot {
    uint128 midPrice; // EUR/USD mid price (18 decimals)
    uint128 depthEur; // Total ask depth in EUR (18 decimals)
    uint16 worstCaseBps; // Worst-case slippage across buckets (bps)
    uint16 spreadBps; // Bid-ask spread (bps)
    uint48 timestamp; // Block timestamp of update
    uint48 blockNumber; // Block number of update
    uint16 bps10k; // Slippage bps for 10k EUR bucket
    uint16 bps50k; // Slippage bps for 50k EUR bucket
    uint16 bps100k; // Slippage bps for 100k EUR bucket
    uint16 bps250k; // Slippage bps for 250k EUR bucket
    uint16 bps1M; // Slippage bps for 1M EUR bucket
}
```

