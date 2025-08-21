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
     */
    function initialize(address admin, address _usdc, address _userPool, address _hedgerPool, address _aaveVault) external;

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
     * @return userAllocation Current computed user allocation
     * @return hedgerAllocation Current computed hedger allocation
     */
    function calculateOptimalYieldShift() external view returns (
        uint256 optimalShift,
        uint256 userAllocation,
        uint256 hedgerAllocation
    );

    /**
     * @notice Yield source names and amounts
     * @return names Array of source names
     * @return amounts Array of amounts per source
     */
    function getYieldSources() external view returns (
        string[] memory names,
        uint256[] memory amounts
    );

    /**
     * @notice Historical yield shift data for a period
     * @param period Index from the end (0 = latest)
     * @return timestamp Snapshot timestamp
     * @return yieldShift Yield shift value at snapshot
     * @return userPoolSize User pool size at snapshot
     * @return hedgerPoolSize Hedger pool size at snapshot
     * @return poolRatio Pool ratio at snapshot
     */
    function getHistoricalYieldShift(uint256 period) external view returns (
        uint256 timestamp,
        uint256 yieldShift,
        uint256 userPoolSize,
        uint256 hedgerPoolSize,
        uint256 poolRatio
    );

    /**
     * @notice Yield performance metrics
     * @return totalYieldDistributed Total distributed
     * @return userYieldPool Current user yield pool
     * @return hedgerYieldPool Current hedger yield pool
     */
    function getYieldPerformanceMetrics() external view returns (
        uint256 totalYieldDistributed,
        uint256 userYieldPool,
        uint256 hedgerYieldPool
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
     * @return baseYieldShift Base shift (bps)
     * @return maxYieldShift Max shift (bps)
     * @return adjustmentSpeed Adjustment speed (bps)
     * @return targetPoolRatio Target ratio (bps)
     */
    function getYieldShiftConfig() external view returns (
        uint256 baseYieldShift,
        uint256 maxYieldShift,
        uint256 adjustmentSpeed,
        uint256 targetPoolRatio
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