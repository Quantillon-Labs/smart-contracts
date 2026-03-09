// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IYieldShift {
    struct YieldModelConfig {
        uint256 baseYieldShift;
        uint256 maxYieldShift;
        uint256 adjustmentSpeed;
        uint256 targetPoolRatio;
    }

    struct YieldDependencyConfig {
        address userPool;
        address hedgerPool;
        address aaveVault;
        address stQEURO;
        address treasury;
    }

    function initialize(
        address admin,
        address _usdc,
        address _userPool,
        address _hedgerPool,
        address _aaveVault,
        address _stQEURO,
        address _timelock,
        address _treasury
    ) external;

    function bootstrapDefaults() external;

    function updateYieldDistribution() external;
    function addYield(uint256 yieldAmount, bytes32 source) external;

    function claimUserYield(address user) external returns (uint256 yieldAmount);
    function claimHedgerYield(address hedger) external returns (uint256 yieldAmount);

    function updateLastDepositTime(address user) external;
    function updateYieldAllocation(address user, uint256 amount, bool isUser) external;

    function configureYieldModel(YieldModelConfig calldata cfg) external;
    function configureDependencies(YieldDependencyConfig calldata cfg) external;
    function setYieldSourceAuthorization(address source, bytes32 yieldType, bool authorized) external;

    function emergencyYieldDistribution(uint256 userAmount, uint256 hedgerAmount) external;
    function pauseYieldDistribution() external;
    function resumeYieldDistribution() external;

    function isYieldSourceAuthorized(address source, bytes32 yieldType) external view returns (bool);
    function checkAndUpdateYieldDistribution() external;
    function forceUpdateYieldDistribution() external;

    function getYieldDistributionBreakdown()
        external
        view
        returns (
            uint256 userYieldPool_,
            uint256 hedgerYieldPool_,
            uint256 distributionRatio
        );

    function getPoolMetrics()
        external
        view
        returns (
            uint256 userPoolSize,
            uint256 hedgerPoolSize,
            uint256 poolRatio,
            uint256 targetRatio
        );

    function calculateOptimalYieldShift() external view returns (uint256 optimalShift, uint256 currentDeviation);

    function getYieldSources()
        external
        view
        returns (
            uint256 aaveYield,
            uint256 protocolFees,
            uint256 interestDifferential,
            uint256 otherSources
        );

    function getHistoricalYieldShift(uint256 period)
        external
        view
        returns (
            uint256 averageShift,
            uint256 maxShift,
            uint256 minShift,
            uint256 volatility
        );

    function getYieldPerformanceMetrics()
        external
        view
        returns (
            uint256 totalYieldDistributed_,
            uint256 averageUserYield,
            uint256 averageHedgerYield,
            uint256 yieldEfficiency
        );

    function currentYieldShift() external view returns (uint256);
    function totalYieldGenerated() external view returns (uint256);
    function totalYieldDistributed() external view returns (uint256);
    function userYieldPool() external view returns (uint256);
    function hedgerYieldPool() external view returns (uint256);

    function userPendingYield(address user) external view returns (uint256);
    function hedgerPendingYield(address hedger) external view returns (uint256);
    function userLastClaim(address user) external view returns (uint256);
    function hedgerLastClaim(address hedger) external view returns (uint256);

    function baseYieldShift() external view returns (uint256);
    function maxYieldShift() external view returns (uint256);
    function adjustmentSpeed() external view returns (uint256);
    function targetPoolRatio() external view returns (uint256);
    function lastUpdateTime() external view returns (uint256);

    function paused() external view returns (bool);
}
