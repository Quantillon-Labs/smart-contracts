// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IYieldShift
 * @notice Interface for YieldShift dynamic yield redistribution
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
interface IYieldShift {
    /**
     * @notice Initializes the YieldShift contract
     * @param admin Admin address
     * @param _usdc USDC token address
     * @param _userPool UserPool address
     * @param _hedgerPool HedgerPool address
     * @param _aaveVault Aave vault address
     * @param _stQEURO stQEURO token address
     */
    function initialize(address admin, address _usdc, address _userPool, address _hedgerPool, address _aaveVault, address _stQEURO) external;

    /**
     * @notice Update yield distribution according to pool balances
     */
    function updateYieldDistribution() external;

    /**
     * @notice Add new yield to be distributed
     * @param yieldAmount Yield amount in USDC equivalent
     * @param source Source identifier (e.g., "aave", "fees")
     */
    function addYield(uint256 yieldAmount, bytes32 source) external;

    /**
     * @notice Claim pending yield for a user
     * @param user Address of the user
     * @return yieldAmount Yield amount claimed
     */
    function claimUserYield(address user) external returns (uint256 yieldAmount);

    /**
     * @notice Claim pending yield for a hedger
     * @param hedger Address of the hedger
     * @return yieldAmount Yield amount claimed
     */
    function claimHedgerYield(address hedger) external returns (uint256 yieldAmount);

    /**
     * @notice Current yield shift percentage (bps)
     */
    function getCurrentYieldShift() external view returns (uint256);

    /**
     * @notice Pending yield amounts
     * @param user Address of the user
     */
    function getUserPendingYield(address user) external view returns (uint256);

    /**
     * @notice Pending yield amounts
     * @param hedger Address of the hedger
     */
    function getHedgerPendingYield(address hedger) external view returns (uint256);

    /**
     * @notice Total yield generated to date
     */
    function getTotalYieldGenerated() external view returns (uint256);

    /**
     * @notice Yield distribution breakdown
     * @return userAllocation Current allocation to users
     * @return hedgerAllocation Current allocation to hedgers
     */
    function getYieldDistributionBreakdown() external view returns (
        uint256 userAllocation,
        uint256 hedgerAllocation
    );

    /**
     * @notice Current pool metrics
     * @return userPoolSize User pool size
     * @return hedgerPoolSize Hedger pool size
     * @return poolRatio Ratio (bps) user/hedger
     */
    function getPoolMetrics() external view returns (
        uint256 userPoolSize,
        uint256 hedgerPoolSize,
        uint256 poolRatio
    );

    /**
     * @notice Calculate optimal yield shift based on current metrics
     * @return optimalShift Optimal shift (bps)
     * @return currentDeviation Current deviation from optimal
     */
    function calculateOptimalYieldShift() external view returns (
        uint256 optimalShift,
        uint256 currentDeviation
    );

    /**
     * @notice Yield source amounts
     * @return aaveYield Aave yield amount
     * @return protocolFees Protocol fees amount
     * @return interestDifferential Interest differential amount
     * @return otherSources Other sources amount
     */
    function getYieldSources() external view returns (
        uint256 aaveYield,
        uint256 protocolFees,
        uint256 interestDifferential,
        uint256 otherSources
    );

    /**
     * @notice Historical yield shift statistics for a period
     * @param period Time period in seconds
     * @return averageShift Average shift over period
     * @return maxShift Maximum shift over period
     * @return minShift Minimum shift over period
     * @return volatility Volatility measure
     */
    function getHistoricalYieldShift(uint256 period) external view returns (
        uint256 averageShift,
        uint256 maxShift,
        uint256 minShift,
        uint256 volatility
    );

    /**
     * @notice Yield performance metrics
     * @return totalYieldDistributed_ Total distributed
     * @return averageUserYield Average user yield
     * @return averageHedgerYield Average hedger yield
     * @return yieldEfficiency Yield efficiency percentage
     */
    function getYieldPerformanceMetrics() external view returns (
        uint256 totalYieldDistributed_,
        uint256 averageUserYield,
        uint256 averageHedgerYield,
        uint256 yieldEfficiency
    );

    /**
     * @notice Update yield shift parameters
     * @param _baseYieldShift Base allocation (bps)
     * @param _maxYieldShift Max allocation (bps)
     * @param _adjustmentSpeed Adjustment speed (bps)
     */
    function setYieldShiftParameters(uint256 _baseYieldShift, uint256 _maxYieldShift, uint256 _adjustmentSpeed) external;

    /**
     * @notice Set the target pool ratio (bps)
     * @param _targetPoolRatio Target ratio
     */
    function setTargetPoolRatio(uint256 _targetPoolRatio) external;

    /**
     * @notice Authorize a yield source for specific yield type
     * @param source Address of the yield source
     * @param yieldType Type of yield this source is authorized for
     */
    function authorizeYieldSource(address source, bytes32 yieldType) external;

    /**
     * @notice Revoke authorization for a yield source
     * @param source Address of the yield source to revoke
     */
    function revokeYieldSource(address source) external;

    /**
     * @notice Check if an address is authorized for a specific yield type
     * @param source Address to check
     * @param yieldType Yield type to check
     * @return True if authorized
     */
    function isYieldSourceAuthorized(address source, bytes32 yieldType) external view returns (bool);

    /**
     * @notice Update yield allocation for a participant
     * @param user Address of participant
     * @param amount Amount to add/subtract
     * @param isUser True if user pool, false if hedger pool
     */
    function updateYieldAllocation(address user, uint256 amount, bool isUser) external;

    /**
     * @notice Emergency manual yield distribution
     * @param userAmount Amount to users
     * @param hedgerAmount Amount to hedgers
     */
    function emergencyYieldDistribution(uint256 userAmount, uint256 hedgerAmount) external;

    /**
     * @notice Pause yield distribution operations
     */
    function pauseYieldDistribution() external;

    /**
     * @notice Resume yield distribution operations
     */
    function resumeYieldDistribution() external;

    /**
     * @notice YieldShift configuration snapshot
     * @return baseShift Base shift (bps)
     * @return maxShift Max shift (bps)
     * @return adjustmentSpeed_ Adjustment speed (bps)
     * @return lastUpdate Last update timestamp
     */
    function getYieldShiftConfig() external view returns (
        uint256 baseShift,
        uint256 maxShift,
        uint256 adjustmentSpeed_,
        uint256 lastUpdate
    );

    /**
     * @notice Whether yield distribution is active (not paused)
     */
    function isYieldDistributionActive() external view returns (bool);

    /**
     * @notice Harvest and distribute Aave yield (if any)
     */
    function harvestAndDistributeAaveYield() external;

    /**
     * @notice Check if an update to yield distribution is needed and apply if so
     */
    function checkAndUpdateYieldDistribution() external;

    /**
     * @notice Update the last deposit time for a user (for TWAP calculations)
     * @param user Address of the user
     * @dev This function is called by the user pool when users deposit
     * @dev Used for time-weighted average calculations
     */
    function updateLastDepositTime(address user) external;

    /**
     * @notice Force update yield distribution (governance only)
     * @dev This function allows governance to force an update to yield distribution
     * @dev Only callable by governance role
     */
    function forceUpdateYieldDistribution() external;

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

    // Recovery functions
    function recoverToken(address token, address to, uint256 amount) external;
    function recoverETH(address payable to) external;
} 