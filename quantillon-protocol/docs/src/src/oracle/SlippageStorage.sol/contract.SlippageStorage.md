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


### TIME_PROVIDER
Shared time provider for deterministic timestamp reads


```solidity
TimeProvider public immutable TIME_PROVIDER
```


## Functions
### constructor

Disables initializers to prevent direct implementation contract use

Called once at deployment time by the EVM. Prevents the implementation
contract from being initialized directly (only proxy is initializable).

**Notes:**
- security: Calls _disableInitializers() to prevent re-initialization attacks

- validation: No input validation required

- state-changes: Disables all initializer functions permanently

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not applicable - constructor

- access: Public - called once at deployment

- oracle: No oracle dependencies

- oz-upgrades-unsafe-allow: constructor


```solidity
constructor(TimeProvider _TIME_PROVIDER) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_TIME_PROVIDER`|`TimeProvider`|Shared protocol time provider used for deterministic timestamps|


### initialize

Initialize the SlippageStorage contract

Sets up roles, rate-limit parameters, and treasury. Calls OpenZeppelin
initializers for AccessControl, Pausable, and UUPSUpgradeable.
Admin receives DEFAULT_ADMIN_ROLE, MANAGER_ROLE, EMERGENCY_ROLE, and UPGRADER_ROLE.

**Notes:**
- security: Validates admin, writer, and treasury are non-zero; enforces config bounds

- validation: Validates admin != address(0), writer != address(0), treasury != address(0),
minInterval <= MAX_UPDATE_INTERVAL, deviationThreshold <= MAX_DEVIATION_THRESHOLD

- state-changes: Grants roles, sets minUpdateInterval, deviationThresholdBps, treasury

- events: No events emitted (OpenZeppelin initializers emit no events)

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
    address _treasury
) external override initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address receiving DEFAULT_ADMIN_ROLE and all management roles|
|`writer`|`address`|Address receiving WRITER_ROLE (the off-chain publisher service wallet)|
|`minInterval`|`uint48`|Minimum seconds between successive writes (0..MAX_UPDATE_INTERVAL)|
|`deviationThreshold`|`uint16`|Deviation in bps that bypasses rate limit (0..MAX_DEVIATION_THRESHOLD)|
|`_treasury`|`address`|Treasury address for token/ETH recovery|


### updateSlippage

Publish a new slippage snapshot on-chain

Rate-limited: if within minUpdateInterval since last update, only allows
the write when |newWorstCaseBps - lastWorstCaseBps| > deviationThresholdBps.
First update always succeeds (timestamp == 0 means no prior data).
Packs all fields into a single SlippageSnapshot struct for efficient storage.

**Notes:**
- security: Requires WRITER_ROLE; blocked when paused; rate-limited by minUpdateInterval

- validation: Checks elapsed time since last update; if within interval, validates
|worstCaseBps - lastWorstCaseBps| > deviationThresholdBps

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

Update the minimum interval between successive slippage writes

Allows the manager to tighten or relax the rate limit. Setting to 0
effectively disables the rate limit; MAX_UPDATE_INTERVAL caps it at 1 hour.

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
function setMinUpdateInterval(uint48 newInterval) external override onlyRole(MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newInterval`|`uint48`|New minimum interval in seconds (0..MAX_UPDATE_INTERVAL)|


### setDeviationThreshold

Update the worst-case bps deviation threshold that bypasses the rate limit

When the absolute difference between the new worstCaseBps and the stored
worstCaseBps exceeds this threshold, the rate limit is bypassed and the
update proceeds immediately regardless of minUpdateInterval.

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
function setDeviationThreshold(uint16 newThreshold) external override onlyRole(MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newThreshold`|`uint16`|New deviation threshold in bps (0..MAX_DEVIATION_THRESHOLD)|


### pause

Pause the contract, blocking all slippage updates

Once paused, updateSlippage will revert with a Paused error until unpaused.
Used in emergency scenarios (e.g. off-chain service malfunction).

**Notes:**
- security: Requires EMERGENCY_ROLE; prevents unauthorized pausing

- validation: No input validation required

- state-changes: Sets OpenZeppelin Pausable internal paused flag to true

- events: Emits Paused(account) from OpenZeppelin PausableUpgradeable

- errors: No errors thrown if already unpaused (OZ handles idempotently)

- reentrancy: Not protected - no external calls made

- access: Restricted to EMERGENCY_ROLE

- oracle: No oracle dependencies


```solidity
function pause() external override onlyRole(EMERGENCY_ROLE);
```

### unpause

Unpause the contract, resuming slippage updates

Restores normal operation after an emergency pause. The WRITER_ROLE
can immediately publish new snapshots once unpaused.

**Notes:**
- security: Requires EMERGENCY_ROLE; prevents unauthorized unpausing

- validation: No input validation required

- state-changes: Sets OpenZeppelin Pausable internal paused flag to false

- events: Emits Unpaused(account) from OpenZeppelin PausableUpgradeable

- errors: No errors thrown if already unpaused (OZ handles idempotently)

- reentrancy: Not protected - no external calls made

- access: Restricted to EMERGENCY_ROLE

- oracle: No oracle dependencies


```solidity
function unpause() external override onlyRole(EMERGENCY_ROLE);
```

### getSlippage

Get the full current slippage snapshot

Returns the entire _snapshot struct including midPrice, depthEur,
worstCaseBps, spreadBps, timestamp, blockNumber, and all bucketBps.
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
function getSlippage() external view override returns (SlippageSnapshot memory snapshot);
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
function getBucketBps() external view override returns (uint16[5] memory bucketBps);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`bucketBps`|`uint16[5]`|Array of 5 slippage values in bps for each order size bucket|


### getSlippageAge

Get seconds elapsed since the last on-chain slippage update

Returns 0 if no update has ever been published (timestamp == 0).
Consumers can use this to assess data freshness before relying on it.

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
function getSlippageAge() external view override returns (uint256 age);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`age`|`uint256`|Seconds since last updateSlippage call, or 0 if never updated|


### recoverToken

Recover ERC20 tokens accidentally sent to this contract

Transfers the specified token amount to the treasury address using
TreasuryRecoveryLibrary. Use to rescue tokens that were mistakenly sent.

**Notes:**
- security: Requires DEFAULT_ADMIN_ROLE; prevents unauthorized token withdrawals

- validation: Implicitly validates via SafeERC20 transfer

- state-changes: No internal state changes; transfers token balance externally

- events: No events emitted from this contract

- errors: Reverts if transfer fails (SafeERC20 revert)

- reentrancy: Not protected - external ERC20 call; admin-only mitigates risk

- access: Restricted to DEFAULT_ADMIN_ROLE

- oracle: No oracle dependencies


```solidity
function recoverToken(address token, uint256 amount) external override onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|ERC20 token contract address to recover|
|`amount`|`uint256`|Amount of tokens to transfer to treasury (token decimals)|


### recoverETH

Recover ETH accidentally sent to this contract

Transfers the entire ETH balance to the treasury address using
TreasuryRecoveryLibrary. The receive() function allows ETH to accumulate.

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
function recoverETH() external override onlyRole(DEFAULT_ADMIN_ROLE);
```

### updateTreasury

Update the treasury address used for token/ETH recovery

The treasury is the destination for recoverToken and recoverETH calls.
Must be a non-zero address to prevent accidental loss of recovered funds.

**Notes:**
- security: Requires DEFAULT_ADMIN_ROLE; validates non-zero address

- validation: Validates _treasury != address(0) via CommonValidationLibrary

- state-changes: Updates the treasury state variable

- events: Emits TreasuryUpdated(_treasury)

- errors: Reverts with ZeroAddress if _treasury is address(0)

- reentrancy: Not protected - no external calls made

- access: Restricted to DEFAULT_ADMIN_ROLE

- oracle: No oracle dependencies


```solidity
function updateTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_treasury`|`address`|New treasury address (must be non-zero)|


### _authorizeUpgrade

Authorize a UUPS proxy upgrade to a new implementation

Called internally by UUPSUpgradeable.upgradeTo/upgradeToAndCall.
Validates the new implementation address is non-zero before authorizing.

**Notes:**
- security: Requires UPGRADER_ROLE; validates newImplementation is non-zero

- validation: Validates newImplementation != address(0)

- state-changes: No state changes in this function (upgrade handled by UUPS base)

- events: No events emitted from this function

- errors: Reverts with ZeroAddress if newImplementation is address(0)

- reentrancy: Not protected - internal function; called within upgrade transaction

- access: Restricted to UPGRADER_ROLE

- oracle: No oracle dependencies


```solidity
function _authorizeUpgrade(address newImplementation) internal view override onlyRole(UPGRADER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation contract|


### receive

Accept ETH sent directly to the contract

Allows the contract to receive ETH so that recoverETH can retrieve it.
Used primarily for recovery testing to simulate accidental ETH deposits.

**Notes:**
- security: No restrictions - any address can send ETH; admin can recover via recoverETH

- validation: No input validation required

- state-changes: No state changes - ETH balance increases implicitly

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not applicable - receive function

- access: Public - no restrictions

- oracle: No oracle dependencies


```solidity
receive() external payable;
```

