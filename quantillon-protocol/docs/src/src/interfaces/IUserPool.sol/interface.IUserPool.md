# IUserPool
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/076c7312a6c5bd467439b8303ad03ed05c21f052/src/interfaces/IUserPool.sol)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Interface for the UserPool managing deposits, staking, and yield

**Note:**
team@quantillon.money


## Functions
### initialize

Initializes the user pool

*Sets up the user pool with initial configuration and assigns roles to admin*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

*Converts USDC to QEURO and adds user to the pool for yield distribution*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

*Converts QEURO back to USDC and removes user from the pool*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

*Locks QEURO tokens to earn staking rewards with cooldown period*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function stake(uint256 qeuroAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount of QEURO to stake|


### requestUnstake

Request to unstake staked QEURO (starts cooldown)

*Initiates unstaking process with cooldown period before final withdrawal*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function requestUnstake(uint256 qeuroAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount to unstake|


### unstake

Finalize unstake after cooldown

*Completes the unstaking process after cooldown period has passed*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function unstake() external;
```

### claimStakingRewards

Claim accumulated staking rewards

*Claims all accumulated staking rewards for the caller*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function claimStakingRewards() external returns (uint256 rewardAmount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rewardAmount`|`uint256`|Amount of rewards claimed|


### distributeYield

Distribute new yield to the user pool

*Distributes yield to all pool participants based on their share*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function distributeYield(uint256 yieldAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`yieldAmount`|`uint256`|Amount of yield in USDC equivalent|


### getUserDeposits

Get a user's total deposits (USDC equivalent)

*Returns the total USDC equivalent value of user's deposits*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function getUserDeposits(address user) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total deposits in USDC equivalent|


### getUserStakes

Get a user's total staked QEURO

*Returns the total amount of QEURO staked by the user*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function getUserStakes(address user) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total staked QEURO amount|


### getUserPendingRewards

Get a user's pending staking rewards

*Returns the amount of staking rewards available to claim*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function getUserPendingRewards(address user) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Pending staking rewards amount|


### getUserInfo

Get detailed user info

*Returns comprehensive user information including balances and staking data*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

*Returns the total value of all deposits in the pool*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function getTotalDeposits() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total deposits in USDC equivalent|


### getTotalStakes

Total QEURO staked in the pool

*Returns the total amount of QEURO staked by all users*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function getTotalStakes() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total staked QEURO amount|


### getPoolMetrics

Summary pool metrics

*Returns comprehensive pool statistics and metrics*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

*Returns the current annual percentage yield for staking*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function getStakingAPY() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Current staking APY in basis points|


### getDepositAPY

Current base deposit APY (bps)

*Returns the current annual percentage yield for deposits*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function getDepositAPY() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Current deposit APY in basis points|


### calculateProjectedRewards

Calculate projected rewards for a staking duration

*Calculates expected rewards for a given staking amount and duration*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

*Allows governance to update staking configuration parameters*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

*Allows governance to update fee parameters for the pool*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

*Allows admin to emergency unstake for a user bypassing cooldown*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function emergencyUnstake(address user) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address|


### pause

Pause user pool operations

*Emergency function to pause all pool operations*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function pause() external;
```

### unpause

Unpause user pool operations

*Resumes all pool operations after emergency pause*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function unpause() external;
```

### getPoolConfig

Pool configuration snapshot

*Returns current pool configuration parameters*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

*Returns true if the pool is not paused and operations are active*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function isPoolActive() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if pool operations are active|


### hasRole

Checks if an account has a specific role

*Returns true if the account has been granted the role*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function hasRole(bytes32 role, address account) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to check|
|`account`|`address`|The account to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the account has the role|


### getRoleAdmin

Gets the admin role for a given role

*Returns the role that is the admin of the given role*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function getRoleAdmin(bytes32 role) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to get admin for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The admin role|


### grantRole

Grants a role to an account

*Can only be called by an account with the admin role*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function grantRole(bytes32 role, address account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to grant|
|`account`|`address`|The account to grant the role to|


### revokeRole

Revokes a role from an account

*Can only be called by an account with the admin role*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function revokeRole(bytes32 role, address account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to revoke|
|`account`|`address`|The account to revoke the role from|


### renounceRole

Renounces a role from the caller

*The caller gives up their own role*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function renounceRole(bytes32 role, address callerConfirmation) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to renounce|
|`callerConfirmation`|`address`|Confirmation that the caller is renouncing their own role|


### paused

Checks if the contract is paused

*Returns true if the contract is currently paused*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function paused() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if paused, false otherwise|


### upgradeTo

Upgrades the contract to a new implementation

*Can only be called by accounts with UPGRADER_ROLE*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function upgradeTo(address newImplementation) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation contract|


### upgradeToAndCall

Upgrades the contract to a new implementation and calls a function

*Can only be called by accounts with UPGRADER_ROLE*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation contract|
|`data`|`bytes`|Encoded function call data|


### GOVERNANCE_ROLE

Returns the governance role identifier

*Role that can update pool parameters and governance functions*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function GOVERNANCE_ROLE() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The governance role bytes32 identifier|


### EMERGENCY_ROLE

Returns the emergency role identifier

*Role that can pause the pool and perform emergency operations*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function EMERGENCY_ROLE() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The emergency role bytes32 identifier|


### UPGRADER_ROLE

Returns the upgrader role identifier

*Role that can upgrade the contract implementation*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function UPGRADER_ROLE() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The upgrader role bytes32 identifier|


### BLOCKS_PER_DAY

Returns the number of blocks per day

*Used for reward calculations*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function BLOCKS_PER_DAY() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Number of blocks per day|


### MAX_REWARD_PERIOD

Returns the maximum reward period

*Maximum duration for reward calculations*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function MAX_REWARD_PERIOD() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Maximum reward period in seconds|


### qeuro

Returns the QEURO token address

*The euro-pegged stablecoin token used in the pool*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function qeuro() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Address of the QEURO token contract|


### usdc

Returns the USDC token address

*The collateral token used for deposits*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function usdc() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Address of the USDC token contract|


### vault

Returns the vault contract address

*The vault contract used for minting/burning QEURO*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function vault() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Address of the vault contract|


### yieldShift

Returns the yield shift contract address

*The contract managing yield distribution*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function yieldShift() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Address of the yield shift contract|


### stakingAPY

Returns the current staking APY

*Annual percentage yield for staking (in basis points)*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function stakingAPY() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Current staking APY in basis points|


### depositAPY

Returns the current deposit APY

*Annual percentage yield for deposits (in basis points)*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function depositAPY() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Current deposit APY in basis points|


### minStakeAmount

Returns the minimum stake amount

*Minimum amount of QEURO required to stake*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function minStakeAmount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Minimum stake amount in QEURO|


### unstakingCooldown

Returns the unstaking cooldown period

*Time in seconds before unstaking can be completed*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function unstakingCooldown() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Unstaking cooldown in seconds|


### depositFee

Returns the deposit fee

*Fee charged on deposits (in basis points)*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function depositFee() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Deposit fee in basis points|


### withdrawalFee

Returns the withdrawal fee

*Fee charged on withdrawals (in basis points)*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function withdrawalFee() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Withdrawal fee in basis points|


### performanceFee

Returns the performance fee

*Fee charged on performance (in basis points)*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function performanceFee() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Performance fee in basis points|


### totalDeposits

Returns the total deposits

*Total USDC equivalent value of all deposits*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function totalDeposits() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total deposits in USDC equivalent|


### totalStakes

Returns the total stakes

*Total amount of QEURO staked by all users*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function totalStakes() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total staked QEURO amount|


### totalUsers

Returns the total number of users

*Number of users who have deposited or staked*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function totalUsers() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total number of users|


### accumulatedYieldPerShare

Returns the accumulated yield per share

*Used for calculating user rewards*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function accumulatedYieldPerShare() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Accumulated yield per share|


### lastYieldDistribution

Returns the last yield distribution timestamp

*Timestamp of the last yield distribution*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function lastYieldDistribution() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Last yield distribution timestamp|


### totalYieldDistributed

Returns the total yield distributed

*Total amount of yield distributed to users*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function totalYieldDistributed() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total yield distributed|


### userLastRewardBlock

Returns the last reward block for a user

*Last block when user rewards were calculated*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function userLastRewardBlock(address user) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The user address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Last reward block number|


### hasDeposited

Checks if a user has deposited

*Returns true if the user has ever deposited*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function hasDeposited(address user) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The user address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if user has deposited|


### userInfo

Returns detailed user information

*Returns comprehensive user data including balances and staking info*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function userInfo(address user)
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
|`user`|`address`|The user address|

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


### recoverToken

Recovers ERC20 tokens sent by mistake

*Allows governance to recover accidentally sent ERC20 tokens*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function recoverToken(address token, address to, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address|
|`to`|`address`|Recipient address|
|`amount`|`uint256`|Amount to transfer|


### recoverETH

Recovers ETH sent by mistake

*Allows governance to recover accidentally sent ETH*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function recoverETH() external;
```

