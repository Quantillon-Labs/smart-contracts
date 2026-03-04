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

Initialize the SlippageStorage contract

Sets up roles, rate-limit parameters, and treasury. Admin receives
DEFAULT_ADMIN_ROLE, MANAGER_ROLE, EMERGENCY_ROLE, and UPGRADER_ROLE.
Writer receives WRITER_ROLE. Callable only once via proxy deployment.

**Notes:**
- security: Validates admin, writer, and treasury are non-zero; enforces config bounds

- validation: Validates admin/writer/treasury != address(0); interval and threshold within max

- state-changes: Grants roles, sets minUpdateInterval, deviationThresholdBps, treasury

- events: No events emitted

- errors: Reverts with ZeroAddress if admin/writer/treasury is zero;
reverts with ConfigValueTooHigh if interval or threshold exceeds max

- reentrancy: Protected by initializer modifier (callable only once)

- access: Public - only callable once during proxy deployment

- oracle: No oracle dependencies


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
|`admin`|`address`|Address receiving DEFAULT_ADMIN_ROLE and all management roles|
|`writer`|`address`|Address receiving WRITER_ROLE (the off-chain publisher service wallet)|
|`minInterval`|`uint48`|Minimum seconds between successive writes (0..MAX_UPDATE_INTERVAL)|
|`deviationThreshold`|`uint16`|Deviation in bps that bypasses rate limit (0..MAX_DEVIATION_THRESHOLD)|
|`treasury`|`address`|Treasury address for token/ETH recovery|


### updateSlippage

Publish a new slippage snapshot on-chain

Rate-limited: if within minUpdateInterval since last update, only allows
the write when |newWorstCaseBps - lastWorstCaseBps| > deviationThresholdBps.
First update always succeeds (timestamp == 0 means no prior data).

**Notes:**
- security: Requires WRITER_ROLE; blocked when paused; rate-limited by minUpdateInterval

- validation: Checks elapsed time since last update; validates deviation if within interval

- state-changes: Overwrites _snapshot with new values, timestamp, and block number

- events: Emits SlippageUpdated(midPrice, worstCaseBps, spreadBps, depthEur, timestamp)

- errors: Reverts with RateLimitTooHigh if within interval and deviation is below threshold

- reentrancy: Not protected - no external calls made during execution

- access: Restricted to WRITER_ROLE; blocked when contract is paused

- oracle: No on-chain oracle dependency; data is pushed by the off-chain Slippage Monitor


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

Update the minimum interval between successive slippage writes

Setting to 0 disables the rate limit; MAX_UPDATE_INTERVAL caps at 1 hour.

**Notes:**
- security: Requires MANAGER_ROLE; enforces upper bound MAX_UPDATE_INTERVAL

- validation: Validates newInterval <= MAX_UPDATE_INTERVAL

- state-changes: Updates minUpdateInterval state variable

- events: Emits ConfigUpdated("minUpdateInterval", oldValue, newValue)

- errors: Reverts with ConfigValueTooHigh if newInterval > MAX_UPDATE_INTERVAL

- reentrancy: Not protected - no external calls made

- access: Restricted to MANAGER_ROLE

- oracle: No oracle dependencies


```solidity
function setMinUpdateInterval(uint48 newInterval) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newInterval`|`uint48`|New minimum interval in seconds (0..MAX_UPDATE_INTERVAL)|


### setDeviationThreshold

Update the worst-case bps deviation threshold that bypasses the rate limit

When |newWorstCaseBps - lastWorstCaseBps| > threshold, rate limit is bypassed.

**Notes:**
- security: Requires MANAGER_ROLE; enforces upper bound MAX_DEVIATION_THRESHOLD (500 bps)

- validation: Validates newThreshold <= MAX_DEVIATION_THRESHOLD

- state-changes: Updates deviationThresholdBps state variable

- events: Emits ConfigUpdated("deviationThresholdBps", oldValue, newValue)

- errors: Reverts with ConfigValueTooHigh if newThreshold > MAX_DEVIATION_THRESHOLD

- reentrancy: Not protected - no external calls made

- access: Restricted to MANAGER_ROLE

- oracle: No oracle dependencies


```solidity
function setDeviationThreshold(uint16 newThreshold) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newThreshold`|`uint16`|New deviation threshold in bps (0..MAX_DEVIATION_THRESHOLD)|


### pause

Pause the contract, blocking all slippage updates

Once paused, updateSlippage reverts until unpaused.

**Notes:**
- security: Requires EMERGENCY_ROLE; prevents unauthorized pausing

- validation: No input validation required

- state-changes: Sets OpenZeppelin Pausable internal paused flag to true

- events: Emits Paused(account) from OpenZeppelin PausableUpgradeable

- errors: No errors thrown

- reentrancy: Not protected - no external calls made

- access: Restricted to EMERGENCY_ROLE

- oracle: No oracle dependencies


```solidity
function pause() external;
```

### unpause

Unpause the contract, resuming slippage updates

Restores normal operation; WRITER_ROLE can immediately publish again.

**Notes:**
- security: Requires EMERGENCY_ROLE; prevents unauthorized unpausing

- validation: No input validation required

- state-changes: Sets OpenZeppelin Pausable internal paused flag to false

- events: Emits Unpaused(account) from OpenZeppelin PausableUpgradeable

- errors: No errors thrown

- reentrancy: Not protected - no external calls made

- access: Restricted to EMERGENCY_ROLE

- oracle: No oracle dependencies


```solidity
function unpause() external;
```

### getSlippage

Get the full current slippage snapshot

Returns a zero-valued struct if updateSlippage has never been called.

**Notes:**
- security: No security concerns - read-only view function

- validation: No input validation required

- state-changes: No state changes - view function

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not applicable - view function

- access: Public - no restrictions

- oracle: No oracle dependencies - reads stored state only


```solidity
function getSlippage() external view returns (SlippageSnapshot memory snapshot);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`snapshot`|`SlippageSnapshot`|The latest SlippageSnapshot stored on-chain|


### getBucketBps

Get per-bucket slippage in bps in canonical size order

Returns buckets in fixed order: [10k EUR, 50k EUR, 100k EUR, 250k EUR, 1M EUR].
All values are zero if updateSlippage has never been called.

**Notes:**
- security: No security concerns - read-only view function

- validation: No input validation required

- state-changes: No state changes - view function

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not applicable - view function

- access: Public - no restrictions

- oracle: No oracle dependencies - reads stored state only


```solidity
function getBucketBps() external view returns (uint16[5] memory bucketBps);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`bucketBps`|`uint16[5]`|Array of 5 slippage values in bps for each order size bucket|


### getSlippageAge

Get seconds elapsed since the last on-chain slippage update

Returns 0 if no update has ever been published (timestamp == 0).

**Notes:**
- security: No security concerns - read-only view function

- validation: No input validation required

- state-changes: No state changes - view function

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not applicable - view function

- access: Public - no restrictions

- oracle: No oracle dependencies - reads stored timestamp only


```solidity
function getSlippageAge() external view returns (uint256 age);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`age`|`uint256`|Seconds since last updateSlippage call, or 0 if never updated|


### minUpdateInterval

Get the current minimum update interval

Rate limit applied to consecutive updateSlippage calls.

**Notes:**
- security: No security concerns - read-only view function

- validation: No input validation required

- state-changes: No state changes - view function

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not applicable - view function

- access: Public - no restrictions

- oracle: No oracle dependencies


```solidity
function minUpdateInterval() external view returns (uint48 interval);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`interval`|`uint48`|Minimum seconds required between successive writes|


### deviationThresholdBps

Get the current deviation threshold that bypasses the rate limit

When |newWorstCaseBps - lastWorstCaseBps| exceeds this, rate limit is bypassed.

**Notes:**
- security: No security concerns - read-only view function

- validation: No input validation required

- state-changes: No state changes - view function

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not applicable - view function

- access: Public - no restrictions

- oracle: No oracle dependencies


```solidity
function deviationThresholdBps() external view returns (uint16 threshold);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`threshold`|`uint16`|Current deviation threshold in bps|


### recoverToken

Recover ERC20 tokens accidentally sent to this contract

Transfers the specified amount to the treasury address.

**Notes:**
- security: Requires DEFAULT_ADMIN_ROLE; prevents unauthorized token withdrawals

- validation: Implicitly validated via SafeERC20 transfer

- state-changes: No internal state changes; transfers token balance externally

- events: No events emitted from this contract

- errors: Reverts if ERC20 transfer fails (SafeERC20 revert)

- reentrancy: Not protected - external ERC20 call; admin-only mitigates risk

- access: Restricted to DEFAULT_ADMIN_ROLE

- oracle: No oracle dependencies


```solidity
function recoverToken(address token, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|ERC20 token contract address to recover|
|`amount`|`uint256`|Amount of tokens to transfer to treasury (token decimals)|


### recoverETH

Recover ETH accidentally sent to this contract

Transfers the entire ETH balance to the treasury address.

**Notes:**
- security: Requires DEFAULT_ADMIN_ROLE; prevents unauthorized ETH withdrawals

- validation: No input validation required; uses address(this).balance

- state-changes: No internal state changes; transfers ETH balance externally

- events: Emits ETHRecovered(treasury, amount)

- errors: Reverts if ETH transfer fails

- reentrancy: Not protected - external ETH transfer; admin-only mitigates risk

- access: Restricted to DEFAULT_ADMIN_ROLE

- oracle: No oracle dependencies


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

