// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IYieldShift
 * @notice Interface for YieldShift dynamic yield redistribution
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
interface IYieldShift {
    /**
     * @notice Initializes the YieldShift contract
     * @dev Sets up the yield shift contract with initial configuration and assigns roles to admin
     * @param admin Admin address
     * @param _usdc USDC token address
     * @param _userPool UserPool address
     * @param _hedgerPool HedgerPool address
     * @param _aaveVault Aave vault address
     * @param _stQEURO stQEURO token address
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function initialize(address admin, address _usdc, address _userPool, address _hedgerPool, address _aaveVault, address _stQEURO) external;

    /**
     * @notice Update yield distribution according to pool balances
     * @dev Recalculates and updates yield distribution based on current pool balances
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function updateYieldDistribution() external;

    /**
     * @notice Add new yield to be distributed
     * @dev Adds new yield from various sources to the distribution pool
     * @param yieldAmount Yield amount in USDC equivalent
     * @param source Source identifier (e.g., "aave", "fees")
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function addYield(uint256 yieldAmount, bytes32 source) external;

    /**
     * @notice Claim pending yield for a user
     * @dev Claims all pending yield for a specific user from the user pool
     * @param user Address of the user
     * @return yieldAmount Yield amount claimed
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function claimUserYield(address user) external returns (uint256 yieldAmount);

    /**
     * @notice Claim pending yield for a hedger
     * @dev Claims all pending yield for a specific hedger from the hedger pool
     * @param hedger Address of the hedger
     * @return yieldAmount Yield amount claimed
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function claimHedgerYield(address hedger) external returns (uint256 yieldAmount);

    /**
     * @notice Current yield shift percentage (bps)
     * @dev Returns the current yield shift percentage in basis points
     * @return Current yield shift percentage in basis points
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getCurrentYieldShift() external view returns (uint256);

    /**
     * @notice Pending yield amounts
     * @dev Returns the amount of pending yield for a specific user
     * @param user Address of the user
     * @return Pending yield amount for the user
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getUserPendingYield(address user) external view returns (uint256);

    /**
     * @notice Pending yield amounts
     * @dev Returns the amount of pending yield for a specific hedger
     * @param hedger Address of the hedger
     * @return Pending yield amount for the hedger
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getHedgerPendingYield(address hedger) external view returns (uint256);

    /**
     * @notice Total yield generated to date
     * @dev Returns the total amount of yield generated since inception
     * @return Total yield generated amount
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getTotalYieldGenerated() external view returns (uint256);

    /**
     * @notice Yield distribution breakdown
     * @dev Returns the current yield allocation breakdown between users and hedgers
     * @return userAllocation Current allocation to users
     * @return hedgerAllocation Current allocation to hedgers
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getYieldDistributionBreakdown() external view returns (
        uint256 userAllocation,
        uint256 hedgerAllocation
    );

    /**
     * @notice Current pool metrics
     * @dev Returns current pool size metrics and ratios
     * @return userPoolSize User pool size
     * @return hedgerPoolSize Hedger pool size
     * @return poolRatio Ratio (bps) user/hedger
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
        uint256 userPoolSize,
        uint256 hedgerPoolSize,
        uint256 poolRatio
    );

    /**
     * @notice Calculate optimal yield shift based on current metrics
     * @dev Calculates the optimal yield shift based on current pool metrics
     * @return optimalShift Optimal shift (bps)
     * @return currentDeviation Current deviation from optimal
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function calculateOptimalYieldShift() external view returns (
        uint256 optimalShift,
        uint256 currentDeviation
    );

    /**
     * @notice Yield source amounts
     * @dev Returns yield amounts from different sources
     * @return aaveYield Aave yield amount
     * @return protocolFees Protocol fees amount
     * @return interestDifferential Interest differential amount
     * @return otherSources Other sources amount
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getYieldSources() external view returns (
        uint256 aaveYield,
        uint256 protocolFees,
        uint256 interestDifferential,
        uint256 otherSources
    );

    /**
     * @notice Historical yield shift statistics for a period
     * @dev Returns historical yield shift statistics for a specified time period
     * @param period Time period in seconds
     * @return averageShift Average shift over period
     * @return maxShift Maximum shift over period
     * @return minShift Minimum shift over period
     * @return volatility Volatility measure
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getHistoricalYieldShift(uint256 period) external view returns (
        uint256 averageShift,
        uint256 maxShift,
        uint256 minShift,
        uint256 volatility
    );

    /**
     * @notice Yield performance metrics
     * @dev Returns comprehensive yield performance metrics
     * @return totalYieldDistributed_ Total distributed
     * @return averageUserYield Average user yield
     * @return averageHedgerYield Average hedger yield
     * @return yieldEfficiency Yield efficiency percentage
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getYieldPerformanceMetrics() external view returns (
        uint256 totalYieldDistributed_,
        uint256 averageUserYield,
        uint256 averageHedgerYield,
        uint256 yieldEfficiency
    );

    /**
     * @notice Update yield shift parameters
     * @dev Allows governance to update yield shift configuration parameters
     * @param _baseYieldShift Base allocation (bps)
     * @param _maxYieldShift Max allocation (bps)
     * @param _adjustmentSpeed Adjustment speed (bps)
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function setYieldShiftParameters(uint256 _baseYieldShift, uint256 _maxYieldShift, uint256 _adjustmentSpeed) external;

    /**
     * @notice Set the target pool ratio (bps)
     * @dev Sets the target ratio between user and hedger pools
     * @param _targetPoolRatio Target ratio
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function setTargetPoolRatio(uint256 _targetPoolRatio) external;

    /**
     * @notice Authorize a yield source for specific yield type
     * @dev Authorizes a yield source for a specific type of yield
     * @param source Address of the yield source
     * @param yieldType Type of yield this source is authorized for
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function authorizeYieldSource(address source, bytes32 yieldType) external;

    /**
     * @notice Revoke authorization for a yield source
     * @dev Revokes authorization for a yield source
     * @param source Address of the yield source to revoke
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function revokeYieldSource(address source) external;

    /**
     * @notice Check if an address is authorized for a specific yield type
     * @dev Checks if an address is authorized for a specific yield type
     * @param source Address to check
     * @param yieldType Yield type to check
     * @return True if authorized
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function isYieldSourceAuthorized(address source, bytes32 yieldType) external view returns (bool);

    /**
     * @notice Update yield allocation for a participant
     * @dev Updates yield allocation for a specific participant
     * @param user Address of participant
     * @param amount Amount to add/subtract
     * @param isUser True if user pool, false if hedger pool
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function updateYieldAllocation(address user, uint256 amount, bool isUser) external;

    /**
     * @notice Emergency manual yield distribution
     * @dev Performs emergency manual yield distribution bypassing normal logic
     * @param userAmount Amount to users
     * @param hedgerAmount Amount to hedgers
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function emergencyYieldDistribution(uint256 userAmount, uint256 hedgerAmount) external;

    /**
     * @notice Pause yield distribution operations
     * @dev Emergency function to pause all yield distribution operations
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function pauseYieldDistribution() external;

    /**
     * @notice Resume yield distribution operations
     * @dev Resumes yield distribution operations after emergency pause
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function resumeYieldDistribution() external;

    /**
     * @notice YieldShift configuration snapshot
     * @dev Returns current yield shift configuration parameters
     * @return baseShift Base shift (bps)
     * @return maxShift Max shift (bps)
     * @return adjustmentSpeed_ Adjustment speed (bps)
     * @return lastUpdate Last update timestamp
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getYieldShiftConfig() external view returns (
        uint256 baseShift,
        uint256 maxShift,
        uint256 adjustmentSpeed_,
        uint256 lastUpdate
    );

    /**
     * @notice Whether yield distribution is active (not paused)
     * @dev Returns true if yield distribution is not paused and operations are active
     * @return True if yield distribution is active
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function isYieldDistributionActive() external view returns (bool);

    /**
     * @notice Check if an update to yield distribution is needed and apply if so
     * @dev Checks if yield distribution needs updating and applies changes if necessary
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function checkAndUpdateYieldDistribution() external;

    /**
     * @notice Update the last deposit time for a user (for TWAP calculations)
     * @dev Updates the last deposit time for a user, called by user pool on deposits
     * @param user Address of the user
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function updateLastDepositTime(address user) external;

    /**
     * @notice Force update yield distribution (governance only)
     * @dev This function allows governance to force an update to yield distribution
     * @dev Only callable by governance role
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function forceUpdateYieldDistribution() external;

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

    // Recovery functions
    /**
     * @notice Recovers ERC20 tokens sent by mistake
     * @dev Allows governance to recover accidentally sent ERC20 tokens
     * @param token Token address
     * @param to Recipient address
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
    function recoverToken(address token, address to, uint256 amount) external;
    
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