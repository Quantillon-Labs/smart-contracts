# IUserPool
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/a0c4605b79826572de49aa1618715c7e4813adad/src/interfaces/IUserPool.sol)

**Author:**
Quantillon Labs

Interface for the UserPool managing deposits, staking, and yield

**Note:**
team@quantillon.money


## Functions
### initialize

Initializes the user pool


```solidity
function initialize(address admin, address _qeuro, address _usdc, address _vault, address _yieldShift) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Admin address|
|`_qeuro`|`address`|QEURO token address|
|`_usdc`|`address`|USDC token address|
|`_vault`|`address`|Vault contract address|
|`_yieldShift`|`address`|YieldShift contract address|


### deposit

Deposit USDC to mint QEURO and join the pool


```solidity
function deposit(uint256 usdcAmount, uint256 minQeuroOut) external returns (uint256 qeuroMinted);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC to deposit|
|`minQeuroOut`|`uint256`|Minimum QEURO expected (slippage protection)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`qeuroMinted`|`uint256`|Amount of QEURO minted to user|


### withdraw

Withdraw USDC by burning QEURO


```solidity
function withdraw(uint256 qeuroAmount, uint256 minUsdcOut) external returns (uint256 usdcReceived);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount of QEURO to burn|
|`minUsdcOut`|`uint256`|Minimum USDC expected|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`usdcReceived`|`uint256`|USDC received by user|


### stake

Stake QEURO to earn staking rewards


```solidity
function stake(uint256 qeuroAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount of QEURO to stake|


### requestUnstake

Request to unstake staked QEURO (starts cooldown)


```solidity
function requestUnstake(uint256 qeuroAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount to unstake|


### unstake

Finalize unstake after cooldown


```solidity
function unstake() external;
```

### claimStakingRewards

Claim accumulated staking rewards


```solidity
function claimStakingRewards() external returns (uint256 rewardAmount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rewardAmount`|`uint256`|Amount of rewards claimed|


### distributeYield

Distribute new yield to the user pool


```solidity
function distributeYield(uint256 yieldAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`yieldAmount`|`uint256`|Amount of yield in USDC equivalent|


### getUserDeposits

Get a user's total deposits (USDC equivalent)


```solidity
function getUserDeposits(address user) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to query|


### getUserStakes

Get a user's total staked QEURO


```solidity
function getUserStakes(address user) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to query|


### getUserPendingRewards

Get a user's pending staking rewards


```solidity
function getUserPendingRewards(address user) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to query|


### getUserInfo

Get detailed user info


```solidity
function getUserInfo(address user)
    external
    view
    returns (
        uint256 qeuroBalance,
        uint256 stakedAmount,
        uint256 pendingRewards,
        uint256 depositHistory,
        uint256 lastStakeTime,
        uint256 unstakeRequestTime,
        uint256 unstakeAmount
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`qeuroBalance`|`uint256`|QEURO balance from deposits|
|`stakedAmount`|`uint256`|QEURO amount staked|
|`pendingRewards`|`uint256`|Pending staking rewards|
|`depositHistory`|`uint256`|Total historical deposits|
|`lastStakeTime`|`uint256`|Timestamp of last stake|
|`unstakeRequestTime`|`uint256`|Timestamp of unstake request|
|`unstakeAmount`|`uint256`|Amount currently requested to unstake|


### getTotalDeposits

Total USDC-equivalent deposits in the pool


```solidity
function getTotalDeposits() external view returns (uint256);
```

### getTotalStakes

Total QEURO staked in the pool


```solidity
function getTotalStakes() external view returns (uint256);
```

### getPoolMetrics

Summary pool metrics


```solidity
function getPoolMetrics()
    external
    view
    returns (uint256 totalUsers_, uint256 averageDeposit, uint256 stakingRatio, uint256 poolTVL);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalUsers_`|`uint256`|Number of users|
|`averageDeposit`|`uint256`|Average deposit per user|
|`stakingRatio`|`uint256`|Staking ratio (bps)|
|`poolTVL`|`uint256`|Total value locked|


### getStakingAPY

Current staking APY (bps)


```solidity
function getStakingAPY() external view returns (uint256);
```

### getDepositAPY

Current base deposit APY (bps)


```solidity
function getDepositAPY() external view returns (uint256);
```

### calculateProjectedRewards

Calculate projected rewards for a staking duration


```solidity
function calculateProjectedRewards(uint256 qeuroAmount, uint256 duration)
    external
    view
    returns (uint256 projectedRewards);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|QEURO amount|
|`duration`|`uint256`|Duration in seconds|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`projectedRewards`|`uint256`|Expected rewards amount|


### updateStakingParameters

Update staking parameters


```solidity
function updateStakingParameters(
    uint256 _stakingAPY,
    uint256 _depositAPY,
    uint256 _minStakeAmount,
    uint256 _unstakingCooldown
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_stakingAPY`|`uint256`|New staking APY (bps)|
|`_depositAPY`|`uint256`|New base deposit APY (bps)|
|`_minStakeAmount`|`uint256`|Minimum stake amount|
|`_unstakingCooldown`|`uint256`|Unstaking cooldown in seconds|


### setPoolFees

Set pool fees


```solidity
function setPoolFees(uint256 _depositFee, uint256 _withdrawalFee, uint256 _performanceFee) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_depositFee`|`uint256`|Deposit fee (bps)|
|`_withdrawalFee`|`uint256`|Withdrawal fee (bps)|
|`_performanceFee`|`uint256`|Performance fee (bps)|


### emergencyUnstake

Emergency unstake for a user by admin


```solidity
function emergencyUnstake(address user) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address|


### pause

Pause user pool operations


```solidity
function pause() external;
```

### unpause

Unpause user pool operations


```solidity
function unpause() external;
```

### getPoolConfig

Pool configuration snapshot


```solidity
function getPoolConfig()
    external
    view
    returns (
        uint256 stakingAPY,
        uint256 depositAPY,
        uint256 minStakeAmount,
        uint256 unstakingCooldown,
        uint256 depositFee,
        uint256 withdrawalFee,
        uint256 performanceFee
    );
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`stakingAPY`|`uint256`|Staking APY (bps)|
|`depositAPY`|`uint256`|Deposit APY (bps)|
|`minStakeAmount`|`uint256`|Minimum stake amount|
|`unstakingCooldown`|`uint256`|Unstaking cooldown seconds|
|`depositFee`|`uint256`|Deposit fee (bps)|
|`withdrawalFee`|`uint256`|Withdrawal fee (bps)|
|`performanceFee`|`uint256`|Performance fee (bps)|


### isPoolActive

Whether the pool operations are active (not paused)


```solidity
function isPoolActive() external view returns (bool);
```

