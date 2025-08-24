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
    function addYield(uint256 yieldAmount, string calldata source) external;

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
} 