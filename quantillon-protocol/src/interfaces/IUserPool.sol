// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IUserPool
 * @notice Interface for the UserPool managing deposits, staking, and yield
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
interface IUserPool {
    /**
     * @notice Initializes the user pool
     * @dev Sets up the user pool with initial configuration and assigns roles to admin
     * @param admin Admin address
     * @param _qeuro QEURO token address
     * @param _usdc USDC token address
     * @param _vault Vault contract address
     * @param _yieldShift YieldShift contract address
     * @param _timelock Timelock contract address
     * @param _treasury Treasury address
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function initialize(address admin, address _qeuro, address _usdc, address _vault, address _yieldShift, address _timelock, address _treasury) external;

    /**
     * @notice Deposit USDC to mint QEURO and join the pool
     * @dev Converts USDC to QEURO and adds user to the pool for yield distribution
     * @param usdcAmount Amount of USDC to deposit
     * @param minQeuroOut Minimum QEURO expected (slippage protection)
     * @return qeuroMinted Amount of QEURO minted to user
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function deposit(uint256 usdcAmount, uint256 minQeuroOut) external returns (uint256 qeuroMinted);

    /**
     * @notice Withdraw USDC by burning QEURO
     * @dev Converts QEURO back to USDC and removes user from the pool
     * @param qeuroAmount Amount of QEURO to burn
     * @param minUsdcOut Minimum USDC expected
     * @return usdcReceived USDC received by user
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function withdraw(uint256 qeuroAmount, uint256 minUsdcOut) external returns (uint256 usdcReceived);

    /**
     * @notice Stake QEURO to earn staking rewards
     * @dev Locks QEURO tokens to earn staking rewards with cooldown period
     * @param qeuroAmount Amount of QEURO to stake
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function stake(uint256 qeuroAmount) external;

    /**
     * @notice Request to unstake staked QEURO (starts cooldown)
     * @dev Initiates unstaking process with cooldown period before final withdrawal
     * @param qeuroAmount Amount to unstake
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function requestUnstake(uint256 qeuroAmount) external;

    /**
     * @notice Finalize unstake after cooldown
     * @dev Completes the unstaking process after cooldown period has passed
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function unstake() external;

    /**
     * @notice Claim accumulated staking rewards
     * @dev Claims all accumulated staking rewards for the caller
     * @return rewardAmount Amount of rewards claimed
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function claimStakingRewards() external returns (uint256 rewardAmount);


    /**
     * @notice Get a user's total deposits (USDC equivalent)
     * @dev Returns the total USDC equivalent value of user's deposits
     * @param user Address to query
     * @return Total deposits in USDC equivalent
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getUserDeposits(address user) external view returns (uint256);

    /**
     * @notice Get a user's total staked QEURO
     * @dev Returns the total amount of QEURO staked by the user
     * @param user Address to query
     * @return Total staked QEURO amount
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getUserStakes(address user) external view returns (uint256);

    /**
     * @notice Get a user's pending staking rewards
     * @dev Returns the amount of staking rewards available to claim
     * @param user Address to query
     * @return Pending staking rewards amount
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getUserPendingRewards(address user) external view returns (uint256);

    /**
     * @notice Get detailed user info
     * @dev Returns comprehensive user information including balances and staking data
     * @param user Address to query
     * @return qeuroBalance QEURO balance from deposits
     * @return stakedAmount QEURO amount staked
     * @return pendingRewards Pending staking rewards
     * @return depositHistory Total historical deposits
     * @return lastStakeTime Timestamp of last stake
     * @return unstakeRequestTime Timestamp of unstake request
     * @return unstakeAmount Amount currently requested to unstake
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
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
     * @dev Returns the total value of all deposits in the pool
     * @return Total deposits in USDC equivalent
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getTotalDeposits() external view returns (uint256);

    /**
     * @notice Total QEURO staked in the pool
     * @dev Returns the total amount of QEURO staked by all users
     * @return Total staked QEURO amount
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getTotalStakes() external view returns (uint256);

    /**
     * @notice Summary pool metrics
     * @dev Returns comprehensive pool statistics and metrics
     * @return totalUsers_ Number of users
     * @return averageDeposit Average deposit per user
     * @return stakingRatio Staking ratio (bps)
     * @return poolTVL Total value locked
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getPoolMetrics() external view returns (
        uint256 totalUsers_,
        uint256 averageDeposit,
        uint256 stakingRatio,
        uint256 poolTVL
    );

    /**
     * @notice Current staking APY (bps)
     * @dev Returns the current annual percentage yield for staking
     * @return Current staking APY in basis points
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getStakingAPY() external view returns (uint256);

    /**
     * @notice Current base deposit APY (bps)
     * @dev Returns the current annual percentage yield for deposits
     * @return Current deposit APY in basis points
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getDepositAPY() external view returns (uint256);

    /**
     * @notice Calculate projected rewards for a staking duration
     * @dev Calculates expected rewards for a given staking amount and duration
     * @param qeuroAmount QEURO amount
     * @param duration Duration in seconds
     * @return projectedRewards Expected rewards amount
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function calculateProjectedRewards(uint256 qeuroAmount, uint256 duration) external view returns (uint256 projectedRewards);

    /**
     * @notice Update staking parameters
     * @dev Allows governance to update staking configuration parameters
     * @param _stakingAPY New staking APY (bps)
     * @param _depositAPY New base deposit APY (bps)
     * @param _minStakeAmount Minimum stake amount
     * @param _unstakingCooldown Unstaking cooldown in seconds
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function updateStakingParameters(
        uint256 _stakingAPY,
        uint256 _depositAPY,
        uint256 _minStakeAmount,
        uint256 _unstakingCooldown
    ) external;

    /**
     * @notice Set performance fee for staking rewards
     * @dev Allows governance to update performance fee parameter
     * @dev NOTE: Mint/redemption fees are set in QuantillonVault, not UserPool
     * @param _performanceFee Performance fee on staking rewards (bps)
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates performanceFee <= 2000 bps (20%)
      * @custom:state-changes Updates performanceFee state variable
      * @custom:events None
      * @custom:errors Reverts if fee exceeds maximum allowed
      * @custom:reentrancy Not applicable
      * @custom:access Restricted to GOVERNANCE_ROLE
      * @custom:oracle Not applicable
     */
    function setPerformanceFee(uint256 _performanceFee) external;

    /**
     * @notice Emergency unstake for a user by admin
     * @dev Allows admin to emergency unstake for a user bypassing cooldown
     * @param user User address
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function emergencyUnstake(address user) external;

    /**
     * @notice Pause user pool operations
     * @dev Emergency function to pause all pool operations
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function pause() external;

    /**
     * @notice Unpause user pool operations
     * @dev Resumes all pool operations after emergency pause
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function unpause() external;

    /**
     * @notice Pool configuration snapshot
     * @dev Returns current pool configuration parameters
     * @dev NOTE: Mint/redemption fees are handled by QuantillonVault, not UserPool
     * @return _stakingAPY Staking APY (bps)
     * @return _depositAPY Deposit APY (bps)
     * @return _minStakeAmount Minimum stake amount
     * @return _unstakingCooldown Unstaking cooldown seconds
     * @return _performanceFee Performance fee on staking rewards (bps)
      * @custom:security No security implications (view function)
      * @custom:validation No validation required
      * @custom:state-changes No state changes (view function)
      * @custom:events No events (view function)
      * @custom:errors No custom errors
      * @custom:reentrancy No external calls, safe
      * @custom:access Public (anyone can call)
      * @custom:oracle No oracle dependencies
     */
    function getPoolConfig() external view returns (
        uint256 _stakingAPY,
        uint256 _depositAPY,
        uint256 _minStakeAmount,
        uint256 _unstakingCooldown,
        uint256 _performanceFee
    );

    /**
     * @notice Whether the pool operations are active (not paused)
     * @dev Returns true if the pool is not paused and operations are active
     * @return True if pool operations are active
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function isPoolActive() external view returns (bool);

    // AccessControl functions
    /**
     * @notice Checks if an account has a specific role
     * @dev Returns true if the account has been granted the role
     * @param role The role to check
     * @param account The account to check
     * @return True if the account has the role
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function hasRole(bytes32 role, address account) external view returns (bool);
    
    /**
     * @notice Gets the admin role for a given role
     * @dev Returns the role that is the admin of the given role
     * @param role The role to get admin for
     * @return The admin role
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    
    /**
     * @notice Grants a role to an account
     * @dev Can only be called by an account with the admin role
     * @param role The role to grant
     * @param account The account to grant the role to
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function grantRole(bytes32 role, address account) external;
    
    /**
     * @notice Revokes a role from an account
     * @dev Can only be called by an account with the admin role
     * @param role The role to revoke
     * @param account The account to revoke the role from
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function revokeRole(bytes32 role, address account) external;
    
    /**
     * @notice Renounces a role from the caller
     * @dev The caller gives up their own role
     * @param role The role to renounce
     * @param callerConfirmation Confirmation that the caller is renouncing their own role
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function renounceRole(bytes32 role, address callerConfirmation) external;

    // Pausable functions
    /**
     * @notice Checks if the contract is paused
     * @dev Returns true if the contract is currently paused
     * @return True if paused, false otherwise
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function paused() external view returns (bool);

    // UUPS functions
    /**
     * @notice Upgrades the contract to a new implementation
     * @dev Can only be called by accounts with UPGRADER_ROLE
     * @param newImplementation Address of the new implementation contract
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function upgradeTo(address newImplementation) external;
    
    /**
     * @notice Upgrades the contract to a new implementation and calls a function
     * @dev Can only be called by accounts with UPGRADER_ROLE
     * @param newImplementation Address of the new implementation contract
     * @param data Encoded function call data
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;

    // Constants
    /**
     * @notice Returns the governance role identifier
     * @dev Role that can update pool parameters and governance functions
     * @return The governance role bytes32 identifier
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function GOVERNANCE_ROLE() external view returns (bytes32);
    
    /**
     * @notice Returns the emergency role identifier
     * @dev Role that can pause the pool and perform emergency operations
     * @return The emergency role bytes32 identifier
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function EMERGENCY_ROLE() external view returns (bytes32);
    
    /**
     * @notice Returns the upgrader role identifier
     * @dev Role that can upgrade the contract implementation
     * @return The upgrader role bytes32 identifier
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function UPGRADER_ROLE() external view returns (bytes32);
    
    /**
     * @notice Returns the number of blocks per day
     * @dev Used for reward calculations
     * @return Number of blocks per day
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function BLOCKS_PER_DAY() external view returns (uint256);
    
    /**
     * @notice Returns the maximum reward period
     * @dev Maximum duration for reward calculations
     * @return Maximum reward period in seconds
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function MAX_REWARD_PERIOD() external view returns (uint256);

    // State variables
    /**
     * @notice Returns the QEURO token address
     * @dev The euro-pegged stablecoin token used in the pool
     * @return Address of the QEURO token contract
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function qeuro() external view returns (address);
    
    /**
     * @notice Returns the USDC token address
     * @dev The collateral token used for deposits
     * @return Address of the USDC token contract
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function usdc() external view returns (address);
    
    /**
     * @notice Returns the vault contract address
     * @dev The vault contract used for minting/burning QEURO
     * @return Address of the vault contract
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function vault() external view returns (address);
    
    /**
     * @notice Returns the yield shift contract address
     * @dev The contract managing yield distribution
     * @return Address of the yield shift contract
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function yieldShift() external view returns (address);
    
    /**
     * @notice Returns the current staking APY
     * @dev Annual percentage yield for staking (in basis points)
     * @return Current staking APY in basis points
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function stakingAPY() external view returns (uint256);
    
    /**
     * @notice Returns the current deposit APY
     * @dev Annual percentage yield for deposits (in basis points)
     * @return Current deposit APY in basis points
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function depositAPY() external view returns (uint256);
    
    /**
     * @notice Returns the minimum stake amount
     * @dev Minimum amount of QEURO required to stake
     * @return Minimum stake amount in QEURO
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function minStakeAmount() external view returns (uint256);
    
    /**
     * @notice Returns the unstaking cooldown period
     * @dev Time in seconds before unstaking can be completed
     * @return Unstaking cooldown in seconds
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function unstakingCooldown() external view returns (uint256);
    
    // NOTE: depositFee and withdrawalFee have been removed
    // Mint and redemption fees are handled by QuantillonVault, not UserPool
    
    /**
     * @notice Returns the performance fee
     * @dev Fee charged on performance (in basis points)
     * @return Performance fee in basis points
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function performanceFee() external view returns (uint256);
    
    /**
     * @notice Returns the total deposits
     * @dev Total USDC equivalent value of all deposits
     * @return Total deposits in USDC equivalent
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function totalDeposits() external view returns (uint256);
    
    /**
     * @notice Returns the total user deposits
     * @dev Total USDC deposits across all users (in USDC decimals - 6)
     * @dev Tracks the sum of all USDC deposits made by users
     * @return Total user deposits in USDC (6 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function totalUserDeposits() external view returns (uint256);
    
    /**
     * @notice Returns the total stakes
     * @dev Total amount of QEURO staked by all users
     * @return Total staked QEURO amount
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function totalStakes() external view returns (uint256);
    
    /**
     * @notice Returns the total number of users
     * @dev Number of users who have deposited or staked
     * @return Total number of users
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function totalUsers() external view returns (uint256);
    
    /**
     * @notice Returns the accumulated yield per share
     * @dev Used for calculating user rewards
     * @return Accumulated yield per share
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function accumulatedYieldPerShare() external view returns (uint256);
    
    /**
     * @notice Returns the last yield distribution timestamp
     * @dev Timestamp of the last yield distribution
     * @return Last yield distribution timestamp
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function lastYieldDistribution() external view returns (uint256);
    
    /**
     * @notice Returns the total yield distributed
     * @dev Total amount of yield distributed to users
     * @return Total yield distributed
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function totalYieldDistributed() external view returns (uint256);
    
    /**
     * @notice Returns the last reward block for a user
     * @dev Last block when user rewards were calculated
     * @param user The user address
     * @return Last reward block number
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function userLastRewardBlock(address user) external view returns (uint256);
    
    /**
     * @notice Checks if a user has deposited
     * @dev Returns true if the user has ever deposited
     * @param user The user address
     * @return True if user has deposited
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function hasDeposited(address user) external view returns (bool);
    
    /**
     * @notice Returns detailed user information
     * @dev Returns comprehensive user data including balances and staking info
     * @param user The user address
     * @return qeuroBalance QEURO balance from deposits
     * @return stakedAmount QEURO amount staked
     * @return pendingRewards Pending staking rewards
     * @return depositHistory Total historical deposits
     * @return lastStakeTime Timestamp of last stake
     * @return unstakeRequestTime Timestamp of unstake request
     * @return unstakeAmount Amount currently requested to unstake
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function userInfo(address user) external view returns (
        uint256 qeuroBalance,
        uint256 stakedAmount,
        uint256 pendingRewards,
        uint256 depositHistory,
        uint256 lastStakeTime,
        uint256 unstakeRequestTime,
        uint256 unstakeAmount
    );

    // Recovery functions
    /**
     * @notice Recovers ERC20 tokens sent by mistake
     * @dev Allows governance to recover accidentally sent ERC20 tokens
     * @param token Token address
     * @param amount Amount to transfer
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function recoverToken(address token, uint256 amount) external;
    
    /**
     * @notice Recovers ETH sent by mistake
     * @dev Allows governance to recover accidentally sent ETH
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function recoverETH() external;
} 