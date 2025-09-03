// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IUserPool
 * @notice Interface for the UserPool managing deposits, staking, and yield
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
interface IUserPool {
    /**
     * @notice Initializes the user pool
     * @param admin Admin address
     * @param _qeuro QEURO token address
     * @param _usdc USDC token address
     * @param _vault Vault contract address
     * @param _yieldShift YieldShift contract address
     */
    function initialize(address admin, address _qeuro, address _usdc, address _vault, address _yieldShift) external;

    /**
     * @notice Deposit USDC to mint QEURO and join the pool
     * @param usdcAmount Amount of USDC to deposit
     * @param minQeuroOut Minimum QEURO expected (slippage protection)
     * @return qeuroMinted Amount of QEURO minted to user
     */
    function deposit(uint256 usdcAmount, uint256 minQeuroOut) external returns (uint256 qeuroMinted);

    /**
     * @notice Withdraw USDC by burning QEURO
     * @param qeuroAmount Amount of QEURO to burn
     * @param minUsdcOut Minimum USDC expected
     * @return usdcReceived USDC received by user
     */
    function withdraw(uint256 qeuroAmount, uint256 minUsdcOut) external returns (uint256 usdcReceived);

    /**
     * @notice Stake QEURO to earn staking rewards
     * @param qeuroAmount Amount of QEURO to stake
     */
    function stake(uint256 qeuroAmount) external;

    /**
     * @notice Request to unstake staked QEURO (starts cooldown)
     * @param qeuroAmount Amount to unstake
     */
    function requestUnstake(uint256 qeuroAmount) external;

    /**
     * @notice Finalize unstake after cooldown
     */
    function unstake() external;

    /**
     * @notice Claim accumulated staking rewards
     * @return rewardAmount Amount of rewards claimed
     */
    function claimStakingRewards() external returns (uint256 rewardAmount);

    /**
     * @notice Distribute new yield to the user pool
     * @param yieldAmount Amount of yield in USDC equivalent
     */
    function distributeYield(uint256 yieldAmount) external;

    /**
     * @notice Get a user's total deposits (USDC equivalent)
     * @param user Address to query
     */
    function getUserDeposits(address user) external view returns (uint256);

    /**
     * @notice Get a user's total staked QEURO
     * @param user Address to query
     */
    function getUserStakes(address user) external view returns (uint256);

    /**
     * @notice Get a user's pending staking rewards
     * @param user Address to query
     */
    function getUserPendingRewards(address user) external view returns (uint256);

    /**
     * @notice Get detailed user info
     * @param user Address to query
     * @return qeuroBalance QEURO balance from deposits
     * @return stakedAmount QEURO amount staked
     * @return pendingRewards Pending staking rewards
     * @return depositHistory Total historical deposits
     * @return lastStakeTime Timestamp of last stake
     * @return unstakeRequestTime Timestamp of unstake request
     * @return unstakeAmount Amount currently requested to unstake
     */
    function getUserInfo(address user) external view returns (
        uint256 qeuroBalance,
        uint256 stakedAmount,
        uint256 pendingRewards,
        uint256 depositHistory,
        uint256 lastStakeTime,
        uint256 unstakeRequestTime,
        uint256 unstakeAmount
    );

    /**
     * @notice Total USDC-equivalent deposits in the pool
     */
    function getTotalDeposits() external view returns (uint256);

    /**
     * @notice Total QEURO staked in the pool
     */
    function getTotalStakes() external view returns (uint256);

    /**
     * @notice Summary pool metrics
     * @return totalUsers_ Number of users
     * @return averageDeposit Average deposit per user
     * @return stakingRatio Staking ratio (bps)
     * @return poolTVL Total value locked
     */
    function getPoolMetrics() external view returns (
        uint256 totalUsers_,
        uint256 averageDeposit,
        uint256 stakingRatio,
        uint256 poolTVL
    );

    /**
     * @notice Current staking APY (bps)
     */
    function getStakingAPY() external view returns (uint256);

    /**
     * @notice Current base deposit APY (bps)
     */
    function getDepositAPY() external view returns (uint256);

    /**
     * @notice Calculate projected rewards for a staking duration
     * @param qeuroAmount QEURO amount
     * @param duration Duration in seconds
     * @return projectedRewards Expected rewards amount
     */
    function calculateProjectedRewards(uint256 qeuroAmount, uint256 duration) external view returns (uint256 projectedRewards);

    /**
     * @notice Update staking parameters
     * @param _stakingAPY New staking APY (bps)
     * @param _depositAPY New base deposit APY (bps)
     * @param _minStakeAmount Minimum stake amount
     * @param _unstakingCooldown Unstaking cooldown in seconds
     */
    function updateStakingParameters(
        uint256 _stakingAPY,
        uint256 _depositAPY,
        uint256 _minStakeAmount,
        uint256 _unstakingCooldown
    ) external;

    /**
     * @notice Set pool fees
     * @param _depositFee Deposit fee (bps)
     * @param _withdrawalFee Withdrawal fee (bps)
     * @param _performanceFee Performance fee (bps)
     */
    function setPoolFees(uint256 _depositFee, uint256 _withdrawalFee, uint256 _performanceFee) external;

    /**
     * @notice Emergency unstake for a user by admin
     * @param user User address
     */
    function emergencyUnstake(address user) external;

    /**
     * @notice Pause user pool operations
     */
    function pause() external;

    /**
     * @notice Unpause user pool operations
     */
    function unpause() external;

    /**
     * @notice Pool configuration snapshot
     * @return _stakingAPY Staking APY (bps)
     * @return _depositAPY Deposit APY (bps)
     * @return _minStakeAmount Minimum stake amount
     * @return _unstakingCooldown Unstaking cooldown seconds
     * @return _depositFee Deposit fee (bps)
     * @return _withdrawalFee Withdrawal fee (bps)
     * @return _performanceFee Performance fee (bps)
     */
    function getPoolConfig() external view returns (
        uint256 _stakingAPY,
        uint256 _depositAPY,
        uint256 _minStakeAmount,
        uint256 _unstakingCooldown,
        uint256 _depositFee,
        uint256 _withdrawalFee,
        uint256 _performanceFee
    );

    /**
     * @notice Whether the pool operations are active (not paused)
     */
    function isPoolActive() external view returns (bool);

    // AccessControl functions
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address callerConfirmation) external;

    // Pausable functions
    function paused() external view returns (bool);

    // UUPS functions
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;

    // Constants
    function GOVERNANCE_ROLE() external view returns (bytes32);
    function EMERGENCY_ROLE() external view returns (bytes32);
    function UPGRADER_ROLE() external view returns (bytes32);
    function BLOCKS_PER_DAY() external view returns (uint256);
    function MAX_REWARD_PERIOD() external view returns (uint256);

    // State variables
    function qeuro() external view returns (address);
    function usdc() external view returns (address);
    function vault() external view returns (address);
    function yieldShift() external view returns (address);
    function stakingAPY() external view returns (uint256);
    function depositAPY() external view returns (uint256);
    function minStakeAmount() external view returns (uint256);
    function unstakingCooldown() external view returns (uint256);
    function depositFee() external view returns (uint256);
    function withdrawalFee() external view returns (uint256);
    function performanceFee() external view returns (uint256);
    function totalDeposits() external view returns (uint256);
    function totalStakes() external view returns (uint256);
    function totalUsers() external view returns (uint256);
    function accumulatedYieldPerShare() external view returns (uint256);
    function lastYieldDistribution() external view returns (uint256);
    function totalYieldDistributed() external view returns (uint256);
    function userLastRewardBlock(address) external view returns (uint256);
    function hasDeposited(address) external view returns (bool);
    function userInfo(address) external view returns (
        uint256 qeuroBalance,
        uint256 stakedAmount,
        uint256 pendingRewards,
        uint256 depositHistory,
        uint256 lastStakeTime,
        uint256 unstakeRequestTime,
        uint256 unstakeAmount
    );

    // Recovery functions
    function recoverToken(address token, address to, uint256 amount) external;
    function recoverETH() external;
} 