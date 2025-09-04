# IUserPool
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/d7c48fdd1629827b7afa681d6fa8df870ef46184/src/interfaces/IUserPool.sol)

**Author:**
Quantillon Labs

Interface for the UserPool managing deposits, staking, and yield

**Note:**
security-contact: team@quantillon.money


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
        uint256 _stakingAPY,
        uint256 _depositAPY,
        uint256 _minStakeAmount,
        uint256 _unstakingCooldown,
        uint256 _depositFee,
        uint256 _withdrawalFee,
        uint256 _performanceFee
    );
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_stakingAPY`|`uint256`|Staking APY (bps)|
|`_depositAPY`|`uint256`|Deposit APY (bps)|
|`_minStakeAmount`|`uint256`|Minimum stake amount|
|`_unstakingCooldown`|`uint256`|Unstaking cooldown seconds|
|`_depositFee`|`uint256`|Deposit fee (bps)|
|`_withdrawalFee`|`uint256`|Withdrawal fee (bps)|
|`_performanceFee`|`uint256`|Performance fee (bps)|


### isPoolActive

Whether the pool operations are active (not paused)


```solidity
function isPoolActive() external view returns (bool);
```

### hasRole


```solidity
function hasRole(bytes32 role, address account) external view returns (bool);
```

### getRoleAdmin


```solidity
function getRoleAdmin(bytes32 role) external view returns (bytes32);
```

### grantRole


```solidity
function grantRole(bytes32 role, address account) external;
```

### revokeRole


```solidity
function revokeRole(bytes32 role, address account) external;
```

### renounceRole


```solidity
function renounceRole(bytes32 role, address callerConfirmation) external;
```

### paused


```solidity
function paused() external view returns (bool);
```

### upgradeTo


```solidity
function upgradeTo(address newImplementation) external;
```

### upgradeToAndCall


```solidity
function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
```

### GOVERNANCE_ROLE


```solidity
function GOVERNANCE_ROLE() external view returns (bytes32);
```

### EMERGENCY_ROLE


```solidity
function EMERGENCY_ROLE() external view returns (bytes32);
```

### UPGRADER_ROLE


```solidity
function UPGRADER_ROLE() external view returns (bytes32);
```

### BLOCKS_PER_DAY


```solidity
function BLOCKS_PER_DAY() external view returns (uint256);
```

### MAX_REWARD_PERIOD


```solidity
function MAX_REWARD_PERIOD() external view returns (uint256);
```

### qeuro


```solidity
function qeuro() external view returns (address);
```

### usdc


```solidity
function usdc() external view returns (address);
```

### vault


```solidity
function vault() external view returns (address);
```

### yieldShift


```solidity
function yieldShift() external view returns (address);
```

### stakingAPY


```solidity
function stakingAPY() external view returns (uint256);
```

### depositAPY


```solidity
function depositAPY() external view returns (uint256);
```

### minStakeAmount


```solidity
function minStakeAmount() external view returns (uint256);
```

### unstakingCooldown


```solidity
function unstakingCooldown() external view returns (uint256);
```

### depositFee


```solidity
function depositFee() external view returns (uint256);
```

### withdrawalFee


```solidity
function withdrawalFee() external view returns (uint256);
```

### performanceFee


```solidity
function performanceFee() external view returns (uint256);
```

### totalDeposits


```solidity
function totalDeposits() external view returns (uint256);
```

### totalStakes


```solidity
function totalStakes() external view returns (uint256);
```

### totalUsers


```solidity
function totalUsers() external view returns (uint256);
```

### accumulatedYieldPerShare


```solidity
function accumulatedYieldPerShare() external view returns (uint256);
```

### lastYieldDistribution


```solidity
function lastYieldDistribution() external view returns (uint256);
```

### totalYieldDistributed


```solidity
function totalYieldDistributed() external view returns (uint256);
```

### userLastRewardBlock


```solidity
function userLastRewardBlock(address) external view returns (uint256);
```

### hasDeposited


```solidity
function hasDeposited(address) external view returns (bool);
```

### userInfo


```solidity
function userInfo(address)
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

### recoverToken


```solidity
function recoverToken(address token, address to, uint256 amount) external;
```

### recoverETH


```solidity
function recoverETH() external;
```

