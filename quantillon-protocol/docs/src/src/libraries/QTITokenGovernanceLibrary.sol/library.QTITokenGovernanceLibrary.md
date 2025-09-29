# QTITokenGovernanceLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/71cd41fc9aa7c18638af4654e656fb0dc6b6d493/src/libraries/QTITokenGovernanceLibrary.sol)

**Author:**
Quantillon Labs

Library for QTIToken governance calculations and validations

*Extracts calculation logic from QTIToken to reduce contract size*


## State Variables
### MAX_LOCK_TIME
Maximum lock time for QTI tokens (1 year)


```solidity
uint256 public constant MAX_LOCK_TIME = 365 days;
```


### MIN_LOCK_TIME
Minimum lock time for vote-escrow (1 week)


```solidity
uint256 public constant MIN_LOCK_TIME = 7 days;
```


### MAX_VE_QTI_MULTIPLIER
Maximum voting power multiplier (4x)


```solidity
uint256 public constant MAX_VE_QTI_MULTIPLIER = 4;
```


## Functions
### calculateVotingPowerMultiplier

Calculate voting power multiplier based on lock time

*Calculates linear multiplier from 1x to 4x based on lock duration*

**Notes:**
- No security implications - pure calculation function

- Input validation handled by calling contract

- No state changes - pure function

- No events emitted

- No errors thrown - pure function

- Not applicable - pure function

- Public function

- No oracle dependencies


```solidity
function calculateVotingPowerMultiplier(uint256 lockTime) external pure returns (uint256 multiplier);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`lockTime`|`uint256`|Duration of the lock|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`multiplier`|`uint256`|Voting power multiplier|


### _calculateVotingPowerMultiplier

Internal function to calculate voting power multiplier

*Calculates linear multiplier from 1x to 4x based on lock duration*

**Notes:**
- No security implications - pure calculation function

- Input validation handled by calling function

- No state changes - pure function

- No events emitted

- No errors thrown - pure function

- Not applicable - pure function

- Internal function

- No oracle dependencies


```solidity
function _calculateVotingPowerMultiplier(uint256 lockTime) internal pure returns (uint256 multiplier);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`lockTime`|`uint256`|Duration of the lock|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`multiplier`|`uint256`|Voting power multiplier|


### calculateVotingPower

Calculate voting power with overflow protection

*Calculates voting power based on amount and lock time with overflow protection*

**Notes:**
- Prevents overflow in voting power calculations

- Input validation handled by calling contract

- No state changes - pure function

- No events emitted

- Throws InvalidAmount if result exceeds uint96 max

- Not applicable - pure function

- Public function

- No oracle dependencies


```solidity
function calculateVotingPower(uint256 amount, uint256 lockTime) external pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of QTI tokens to lock|
|`lockTime`|`uint256`|Duration to lock tokens|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|votingPower Calculated voting power|


### _calculateVotingPower

Internal function to calculate voting power with overflow protection

*Calculates voting power based on amount and lock time with overflow protection*

**Notes:**
- Prevents overflow in voting power calculations

- Input validation handled by calling function

- No state changes - pure function

- No events emitted

- Throws InvalidAmount if result exceeds uint96 max

- Not applicable - pure function

- Internal function

- No oracle dependencies


```solidity
function _calculateVotingPower(uint256 amount, uint256 lockTime) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of QTI tokens to lock|
|`lockTime`|`uint256`|Duration to lock tokens|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|votingPower Calculated voting power|


### calculateCurrentVotingPower

Calculate current voting power with linear decay

*Calculates current voting power with linear decay over time*

**Notes:**
- No security implications - pure calculation function

- Input validation handled by calling contract

- No state changes - pure function

- No events emitted

- No errors thrown - pure function

- Not applicable - pure function

- Public function

- No oracle dependencies


```solidity
function calculateCurrentVotingPower(LockInfo memory lockInfo, uint256 currentTime)
    external
    pure
    returns (uint256 votingPower);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`lockInfo`|`LockInfo`|Lock information structure|
|`currentTime`|`uint256`|Current timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`votingPower`|`uint256`|Current voting power of the user (decays linearly over time)|


### calculateUnlockTime

Calculate unlock time with proper validation

*Calculates new unlock time based on current timestamp and lock duration*

**Notes:**
- Prevents timestamp overflow in unlock time calculations

- Input validation handled by calling contract

- No state changes - pure function

- No events emitted

- Throws InvalidTime if result exceeds uint32 max

- Not applicable - pure function

- Public function

- No oracle dependencies


```solidity
function calculateUnlockTime(uint256 currentTimestamp, uint256 lockTime, uint256 existingUnlockTime)
    external
    pure
    returns (uint256 newUnlockTime);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currentTimestamp`|`uint256`|Current timestamp for calculation|
|`lockTime`|`uint256`|Duration to lock tokens|
|`existingUnlockTime`|`uint256`|Existing unlock time if already locked|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`newUnlockTime`|`uint256`|Calculated unlock time|


### _calculateUnlockTime

Internal function to calculate unlock time with proper validation

*Calculates new unlock time based on current timestamp and lock duration*

**Notes:**
- Prevents timestamp overflow in unlock time calculations

- Input validation handled by calling function

- No state changes - pure function

- No events emitted

- Throws InvalidTime if result exceeds uint32 max

- Not applicable - pure function

- Internal function

- No oracle dependencies


```solidity
function _calculateUnlockTime(uint256 currentTimestamp, uint256 lockTime, uint256 existingUnlockTime)
    internal
    pure
    returns (uint256 newUnlockTime);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currentTimestamp`|`uint256`|Current timestamp for calculation|
|`lockTime`|`uint256`|Duration to lock tokens|
|`existingUnlockTime`|`uint256`|Existing unlock time if already locked|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`newUnlockTime`|`uint256`|Calculated unlock time|


### validateAndCalculateTotalAmount

Validate all amounts and lock times, returns total amount

*Ensures all amounts and lock times are valid and calculates total amount*

**Notes:**
- Prevents invalid amounts and lock times from being processed

- Validates amounts are positive and lock times are within bounds

- No state changes - pure function

- No events emitted

- Throws various validation errors for invalid inputs

- Not applicable - pure function

- Public function

- No oracle dependencies


```solidity
function validateAndCalculateTotalAmount(uint256[] calldata amounts, uint256[] calldata lockTimes)
    external
    pure
    returns (uint256 totalAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amounts`|`uint256[]`|Array of QTI amounts to lock|
|`lockTimes`|`uint256[]`|Array of lock durations|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalAmount`|`uint256`|Total amount of QTI to be locked|


### processBatchLocks

Process batch locks and calculate totals

*Processes batch lock operations and calculates total voting power and amounts*

**Notes:**
- Prevents overflow in batch calculations

- Input validation handled by calling contract

- No state changes - pure function

- No events emitted

- No errors thrown - pure function

- Not applicable - pure function

- Public function

- No oracle dependencies


```solidity
function processBatchLocks(
    uint256[] calldata amounts,
    uint256[] calldata lockTimes,
    uint256 currentTimestamp,
    uint256 existingUnlockTime
)
    external
    pure
    returns (
        uint256 totalNewVotingPower,
        uint256 totalNewAmount,
        uint256 finalUnlockTime,
        uint256 finalLockTime,
        uint256[] memory veQTIAmounts
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amounts`|`uint256[]`|Array of QTI amounts to lock|
|`lockTimes`|`uint256[]`|Array of lock durations|
|`currentTimestamp`|`uint256`|Current timestamp|
|`existingUnlockTime`|`uint256`|Existing unlock time if already locked|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalNewVotingPower`|`uint256`|Total new voting power from all locks|
|`totalNewAmount`|`uint256`|Total new amount locked|
|`finalUnlockTime`|`uint256`|Final unlock time after all locks|
|`finalLockTime`|`uint256`|Final lock time|
|`veQTIAmounts`|`uint256[]`|Array of calculated voting power amounts|


### updateLockInfo

Update lock info with overflow checks

*Updates user's lock information with new amounts and times*

**Notes:**
- Prevents overflow in lock info updates

- Validates amounts and times are within bounds

- No state changes - pure function

- No events emitted

- Throws InvalidAmount if values exceed uint96 max

- Not applicable - pure function

- Public function

- No oracle dependencies


```solidity
function updateLockInfo(uint256 totalNewAmount, uint256 newUnlockTime, uint256 totalNewVotingPower, uint256 lockTime)
    external
    pure
    returns (LockInfo memory updatedLockInfo);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`totalNewAmount`|`uint256`|Total new amount to lock|
|`newUnlockTime`|`uint256`|New unlock time|
|`totalNewVotingPower`|`uint256`|Total new voting power|
|`lockTime`|`uint256`|Lock duration|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`updatedLockInfo`|`LockInfo`|Updated lock information|


### calculateDecentralizationLevel

Calculate decentralization level based on time elapsed

*Calculates decentralization level based on elapsed time since start*

**Notes:**
- No security implications - pure calculation function

- Input validation handled by calling contract

- No state changes - pure function

- No events emitted

- No errors thrown - pure function

- Not applicable - pure function

- Public function

- No oracle dependencies


```solidity
function calculateDecentralizationLevel(
    uint256 currentTime,
    uint256 decentralizationStartTime,
    uint256 decentralizationDuration,
    uint256 maxTimeElapsed
) external pure returns (uint256 newLevel);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currentTime`|`uint256`|Current timestamp|
|`decentralizationStartTime`|`uint256`|Start time for decentralization|
|`decentralizationDuration`|`uint256`|Total duration for decentralization|
|`maxTimeElapsed`|`uint256`|Maximum time elapsed to consider|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`newLevel`|`uint256`|New decentralization level (0-10000)|


## Structs
### LockInfo
Lock information structure


```solidity
struct LockInfo {
    uint96 amount;
    uint32 unlockTime;
    uint96 votingPower;
    uint32 lastClaimTime;
    uint96 initialVotingPower;
    uint32 lockTime;
}
```

