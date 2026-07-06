# UserPoolStakingLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/e6d6ab67e05d161d0d4815c50b5213a2a6cbb873/src/libraries/UserPoolStakingLibrary.sol)

**Title:**
UserPoolStakingLibrary

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Staking and reward calculation functions for UserPool to reduce contract size

Extracted from UserPool to reduce bytecode size and improve maintainability

**Note:**
security-contact: team@quantillon.money


## Constants
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


## Functions
### version

Returns the semantic version of this linked library.

On-chain version of the standalone deployed library; bump per semver on any change.
See deployments/{chainId}/versions.json for deployed-address provenance.

**Notes:**
- security: No security implications - returns a compile-time constant.

- validation: No input validation required.

- state-changes: None - pure function.

- events: None.

- errors: None.

- reentrancy: Not applicable - pure function.

- access: Public - anyone can read the version.

- oracle: No oracle dependencies.


```solidity
function version() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Semantic version string (e.g. "1.0.0").|


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

