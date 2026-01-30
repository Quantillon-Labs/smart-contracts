# UserPoolStakingLibrary
**Title:**
UserPoolStakingLibrary

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Staking and reward calculation functions for UserPool to reduce contract size

Extracted from UserPool to reduce bytecode size and improve maintainability

**Note:**
security-contact: team@quantillon.money


## State Variables
### MIN_STAKE_AMOUNT

```solidity
uint256 public constant MIN_STAKE_AMOUNT = 1e18
```


### MAX_STAKE_AMOUNT

```solidity
uint256 public constant MAX_STAKE_AMOUNT = 1000000e18
```


### MIN_STAKE_DURATION

```solidity
uint256 public constant MIN_STAKE_DURATION = 1 days
```


### MAX_STAKE_DURATION

```solidity
uint256 public constant MAX_STAKE_DURATION = 365 days
```


### UNSTAKE_COOLDOWN

```solidity
uint256 public constant UNSTAKE_COOLDOWN = 7 days
```


### REWARD_CLAIM_COOLDOWN

```solidity
uint256 public constant REWARD_CLAIM_COOLDOWN = 1 days
```


## Functions
### _calculateStakingRewards

Calculates staking rewards for a user

Internal function to calculate rewards based on stake duration and APY

**Notes:**
- security: No security implications - pure calculation function

- validation: Input validation handled by calling function

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No errors thrown - pure function

- reentrancy: Not applicable - pure function

- access: Internal function

- oracle: No oracle dependencies


```solidity
function _calculateStakingRewards(StakeInfo memory stakeInfo, uint256 stakingAPY, uint256 currentTime)
    internal
    pure
    returns (uint256 rewards);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`stakeInfo`|`StakeInfo`|Stake information|
|`stakingAPY`|`uint256`|Staking APY in basis points|
|`currentTime`|`uint256`|Current timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rewards`|`uint256`|Calculated rewards|


### calculateStakingRewards

Public wrapper for calculateStakingRewards

Public interface for calculating staking rewards

**Notes:**
- security: No security implications - pure calculation function

- validation: Input validation handled by calling contract

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No errors thrown - pure function

- reentrancy: Not applicable - pure function

- access: Public function

- oracle: No oracle dependencies


```solidity
function calculateStakingRewards(StakeInfo memory stakeInfo, uint256 stakingAPY, uint256 currentTime)
    external
    pure
    returns (uint256 rewards);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`stakeInfo`|`StakeInfo`|Stake information|
|`stakingAPY`|`uint256`|Staking APY in basis points|
|`currentTime`|`uint256`|Current timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rewards`|`uint256`|Calculated rewards|


### calculateTotalStakingRewards

Calculates total staking rewards for a user

Calculates total rewards across all active stakes for a user

**Notes:**
- security: No security implications - pure calculation function

- validation: Input validation handled by calling contract

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No errors thrown - pure function

- reentrancy: Not applicable - pure function

- access: Public function

- oracle: No oracle dependencies


```solidity
function calculateTotalStakingRewards(StakeInfo[] memory userStakes, uint256 stakingAPY, uint256 currentTime)
    external
    pure
    returns (uint256 totalRewards);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`userStakes`|`StakeInfo[]`|Array of user stakes|
|`stakingAPY`|`uint256`|Staking APY in basis points|
|`currentTime`|`uint256`|Current timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalRewards`|`uint256`|Total rewards for all stakes|


### validateStakeParameters

Validates stake parameters

Ensures stake parameters are within acceptable bounds

**Notes:**
- security: Prevents invalid stake parameters from being processed

- validation: Validates amounts, durations, and user limits

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws various validation errors for invalid inputs

- reentrancy: Not applicable - pure function

- access: Public function

- oracle: No oracle dependencies


```solidity
function validateStakeParameters(uint256 amount, uint256 duration, UserStakingData memory userStakingData)
    external
    pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Stake amount|
|`duration`|`uint256`|Stake duration|
|`userStakingData`|`UserStakingData`|User's current staking data|


### validateUnstakeParameters

Validates unstake parameters

Ensures unstake operations meet minimum requirements

**Notes:**
- security: Prevents premature unstaking and enforces cooldowns

- validation: Validates stake status and timing requirements

- state-changes: No state changes - pure function

- events: No events emitted

- errors: Throws various validation errors for invalid unstake attempts

- reentrancy: Not applicable - pure function

- access: Public function

- oracle: No oracle dependencies


```solidity
function validateUnstakeParameters(StakeInfo memory stakeInfo, uint256 currentTime) external pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`stakeInfo`|`StakeInfo`|Stake information|
|`currentTime`|`uint256`|Current timestamp|


### calculateUnstakePenalty

Calculates unstake penalty

Calculates penalty based on stake duration to discourage early unstaking

**Notes:**
- security: No security implications - pure calculation function

- validation: Input validation handled by calling contract

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No errors thrown - pure function

- reentrancy: Not applicable - pure function

- access: Public function

- oracle: No oracle dependencies


```solidity
function calculateUnstakePenalty(StakeInfo memory stakeInfo, uint256 currentTime)
    external
    pure
    returns (uint256 penalty);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`stakeInfo`|`StakeInfo`|Stake information|
|`currentTime`|`uint256`|Current timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`penalty`|`uint256`|Penalty percentage in basis points|


### calculateDepositAPY

Calculates deposit APY based on pool metrics

Adjusts deposit APY based on staking ratio to incentivize optimal behavior

**Notes:**
- security: No security implications - pure calculation function

- validation: Input validation handled by calling contract

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No errors thrown - pure function

- reentrancy: Not applicable - pure function

- access: Public function

- oracle: No oracle dependencies


```solidity
function calculateDepositAPY(uint256 totalDeposits, uint256 totalStaked, uint256 baseAPY)
    external
    pure
    returns (uint256 depositAPY);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`totalDeposits`|`uint256`|Total pool deposits|
|`totalStaked`|`uint256`|Total staked amount|
|`baseAPY`|`uint256`|Base APY in basis points|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`depositAPY`|`uint256`|Calculated deposit APY|


### calculateStakingAPY

Calculates staking APY based on pool metrics

Adjusts staking APY based on staking ratio to incentivize optimal behavior

**Notes:**
- security: No security implications - pure calculation function

- validation: Input validation handled by calling contract

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No errors thrown - pure function

- reentrancy: Not applicable - pure function

- access: Public function

- oracle: No oracle dependencies


```solidity
function calculateStakingAPY(uint256 totalDeposits, uint256 totalStaked, uint256 baseAPY)
    external
    pure
    returns (uint256 stakingAPY);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`totalDeposits`|`uint256`|Total pool deposits|
|`totalStaked`|`uint256`|Total staked amount|
|`baseAPY`|`uint256`|Base APY in basis points|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`stakingAPY`|`uint256`|Calculated staking APY|


### calculateDynamicFee

Calculates fee for deposit/withdrawal

Adjusts fees based on pool utilization to manage liquidity

**Notes:**
- security: No security implications - pure calculation function

- validation: Input validation handled by calling contract

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No errors thrown - pure function

- reentrancy: Not applicable - pure function

- access: Public function

- oracle: No oracle dependencies


```solidity
function calculateDynamicFee(uint256 amount, uint256 baseFee, uint256 poolUtilization)
    external
    pure
    returns (uint256 fee);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Transaction amount|
|`baseFee`|`uint256`|Base fee in basis points|
|`poolUtilization`|`uint256`|Pool utilization ratio|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`fee`|`uint256`|Calculated fee amount|


### calculatePoolMetrics

Calculates pool metrics

Packs pool metrics into a single uint256 for gas efficiency

**Notes:**
- security: No security implications - pure calculation function

- validation: Input validation handled by calling contract

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No errors thrown - pure function

- reentrancy: Not applicable - pure function

- access: Public function

- oracle: No oracle dependencies


```solidity
function calculatePoolMetrics(uint256 totalDeposits, uint256 totalStaked, uint256 totalUsers)
    external
    pure
    returns (uint256 metrics);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`totalDeposits`|`uint256`|Total pool deposits|
|`totalStaked`|`uint256`|Total staked amount|
|`totalUsers`|`uint256`|Total number of users|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`metrics`|`uint256`|Packed pool metrics|


### unpackPoolMetrics

Unpacks pool metrics

Unpacks pool metrics from a single uint256 for gas efficiency

**Notes:**
- security: No security implications - pure calculation function

- validation: Input validation handled by calling contract

- state-changes: No state changes - pure function

- events: No events emitted

- errors: No errors thrown - pure function

- reentrancy: Not applicable - pure function

- access: Public function

- oracle: No oracle dependencies


```solidity
function unpackPoolMetrics(uint256 metrics)
    external
    pure
    returns (uint256 stakingRatio, uint256 averageDeposit, uint256 totalUsers);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`metrics`|`uint256`|Packed pool metrics|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`stakingRatio`|`uint256`|Staking ratio in basis points|
|`averageDeposit`|`uint256`|Average deposit per user|
|`totalUsers`|`uint256`|Total number of users|


## Structs
### StakeInfo

```solidity
struct StakeInfo {
    uint256 amount;
    uint256 startTime;
    uint256 endTime;
    uint256 lastRewardClaim;
    uint256 totalRewardsClaimed;
    bool isActive;
}
```

### UserStakingData

```solidity
struct UserStakingData {
    uint256 totalStaked;
    uint256 totalRewardsEarned;
    uint256 totalRewardsClaimed;
    uint256 lastStakeTime;
    uint256 lastUnstakeTime;
    uint256 activeStakes;
}
```

