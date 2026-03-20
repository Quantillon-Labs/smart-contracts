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
        address stQEUROFactory;
        address treasury;
    }

    /**
     * @notice Initializes the YieldShift contract.
     * @dev Sets up core roles, USDC token and optional initial dependencies.
     * @param admin Address receiving admin and governance roles.
     * @param _usdc USDC token address used for yield accounting.
     * @param _userPool UserPool contract address (optional at deploy time).
     * @param _hedgerPool HedgerPool contract address (optional at deploy time).
     * @param _aaveVault AaveVault contract address (optional at deploy time).
     * @param _stQEUROFactory stQEURO factory contract address (optional at deploy time).
     * @param _timelock Timelock contract used for SecureUpgradeable.
     * @param _treasury Treasury address for recovery flows.
     * @custom:security Validates non‑zero admin and USDC address, sets up access control.
     * @custom:validation Reverts on invalid addresses; optional dependencies may be zero.
     * @custom:state-changes Initializes roles, references and scalar defaults.
     * @custom:events Emits implementation‑specific initialization events.
     * @custom:errors Reverts with protocol‑specific validation errors.
     * @custom:reentrancy Protected by initializer modifier in implementation.
     * @custom:access External initializer; callable once.
     * @custom:oracle No direct oracle dependency.
     */
    function initialize(
        address admin,
        address _usdc,
        address _userPool,
        address _hedgerPool,
        address _aaveVault,
        address _stQEUROFactory,
        address _timelock,
        address _treasury
    ) external;

    /**
     * @notice Governance bootstrap to set initial histories and default sources.
     * @dev Lazily initializes TWAP histories and default yield source metadata after `initialize`.
     * @custom:security Restricted to governance; reads only already‑validated state.
     * @custom:validation Reverts if caller lacks governance role.
     * @custom:state-changes Records initial snapshots and default yield source mappings.
     * @custom:events Emits no external events beyond those in implementation.
     * @custom:errors Reverts with access‑control errors on unauthorized callers.
     * @custom:reentrancy Not applicable – configuration only.
     * @custom:access Governance‑only.
     * @custom:oracle No oracle dependency.
     */
    function bootstrapDefaults() external;

    /**
     * @notice Updates the yield distribution between user and hedger pools.
     * @dev Recomputes `currentYieldShift` using eligible pool metrics and updates history.
     * @custom:security Callable by authorized roles; uses holding‑period protection against flash deposits.
     * @custom:validation Reverts if dependencies are misconfigured.
     * @custom:state-changes Updates `currentYieldShift`, `lastUpdateTime` and pool snapshots.
     * @custom:events Emits `YieldDistributionUpdated`.
     * @custom:errors Reverts with protocol‑specific config or math errors.
     * @custom:reentrancy Protected by nonReentrant modifier in implementation.
     * @custom:access Typically callable by anyone or scheduled keeper, per implementation.
     * @custom:oracle No direct oracle reads; relies on pool metrics.
     */
    function updateYieldDistribution() external;

    /**
     * @notice Adds yield from an authorized source and allocates it between users and hedgers.
     * @dev Transfers USDC from `msg.sender`, checks authorization and updates yield pools.
     * @param vaultId Target vault id receiving user-yield routing.
     * @param yieldAmount Yield amount in USDC (6 decimals).
     * @param source Logical yield source identifier (e.g. `keccak256("aave")`).
     * @custom:security Only authorized yield sources may call; validates source mapping.
     * @custom:validation Reverts if transferred amount does not match `yieldAmount` within 1 wei.
     * @custom:state-changes Updates `yieldSources`, `totalYieldGenerated`, `userYieldPool`, `hedgerYieldPool`.
     * @custom:events Emits `YieldAdded`.
     * @custom:errors Reverts with authorization or amount‑mismatch errors.
     * @custom:reentrancy Protected by nonReentrant modifier in implementation.
     * @custom:access Restricted to whitelisted yield source contracts.
     * @custom:oracle No direct oracle dependency.
     */
    function addYield(uint256 vaultId, uint256 yieldAmount, bytes32 source) external;

    /**
     * @notice Claims accumulated user yield for a specific address.
     * @dev Enforces holding period via `lastDepositTime` before releasing USDC yield.
     * @param user Address whose yield is being claimed.
     * @return yieldAmount Amount of USDC yield transferred to `user`.
     * @custom:security Callable by user or UserPool; checks holding period and pool balances.
     * @custom:validation Reverts if holding period not met or pool has insufficient yield.
     * @custom:state-changes Updates `userPendingYield`, `userLastClaim`, `userYieldPool`, `totalYieldDistributed`.
     * @custom:events Emits `UserYieldClaimed`.
     * @custom:errors Reverts with holding‑period or insufficient‑yield errors.
     * @custom:reentrancy Protected by nonReentrant modifier in implementation.
     * @custom:access Restricted to `user` or UserPool contract.
     * @custom:oracle No direct oracle dependency.
     */
    function claimUserYield(address user) external returns (uint256 yieldAmount);

    /**
     * @notice Claims accumulated hedger yield for a specific hedger.
     * @dev Transfers pending hedger yield from `hedgerYieldPool` to `hedger`.
     * @param hedger Address of the hedger.
     * @return yieldAmount Amount of USDC yield transferred.
     * @custom:security Callable by hedger or HedgerPool; enforces authorization.
     * @custom:validation Reverts if pool has insufficient yield.
     * @custom:state-changes Updates `hedgerPendingYield`, `hedgerLastClaim`, `hedgerYieldPool`, `totalYieldDistributed`.
     * @custom:events Emits `HedgerYieldClaimed`.
     * @custom:errors Reverts with insufficient‑yield or access errors.
     * @custom:reentrancy Protected by nonReentrant modifier in implementation.
     * @custom:access Restricted to `hedger` or HedgerPool.
     * @custom:oracle No direct oracle dependency.
     */
    function claimHedgerYield(address hedger) external returns (uint256 yieldAmount);

    /**
     * @notice Updates the last deposit timestamp for a user.
     * @dev Called by UserPool / HedgerPool so holding‑period logic can be enforced.
     * @param user Address whose last deposit time is updated.
     * @custom:security Only callable by UserPool or HedgerPool contracts.
     * @custom:validation Reverts on unauthorized caller.
     * @custom:state-changes Updates `lastDepositTime[user]`.
     * @custom:events None.
     * @custom:errors Reverts with authorization error.
     * @custom:reentrancy Not applicable – simple storage write.
     * @custom:access Restricted to pools.
     * @custom:oracle No oracle dependency.
     */
    function updateLastDepositTime(address user) external;

    /**
     * @notice Updates per‑user or per‑hedger yield allocation.
     * @dev Called by pool logic to adjust individual pending yield balances.
     * @param user User or hedger address.
     * @param amount Allocation delta amount.
     * @param isUser True if `user` is a UserPool participant, false if hedger.
     * @custom:security Restricted to yield‑manager roles via `AccessControlLibrary`.
     * @custom:validation Reverts on unauthorized caller.
     * @custom:state-changes Updates `userPendingYield` or `hedgerPendingYield`.
     * @custom:events None.
     * @custom:errors Reverts with access‑control errors.
     * @custom:reentrancy Not applicable – simple storage updates.
     * @custom:access Restricted to YieldManager role.
     * @custom:oracle No oracle dependency.
     */
    function updateYieldAllocation(address user, uint256 amount, bool isUser) external;

    /**
     * @notice Batch‑updates all yield model parameters.
     * @dev See `YieldShift.configureYieldModel` for implementation semantics.
     * @param cfg New yield model configuration.
     * @custom:security Restricted to governance.
     * @custom:validation Reverts when parameters are out of allowed bounds.
     * @custom:state-changes Updates scalar configuration in storage.
     * @custom:events None.
     * @custom:errors Protocol‑specific config errors.
     * @custom:reentrancy Not applicable.
     * @custom:access Governance‑only.
     * @custom:oracle No oracle dependency.
     */
    function configureYieldModel(YieldModelConfig calldata cfg) external;

    /**
     * @notice Batch‑updates core dependency addresses.
     * @dev See `YieldShift.configureDependencies` for implementation semantics.
     * @param cfg New dependency configuration.
     * @custom:security Restricted to governance; validates non‑zero addresses.
     * @custom:validation Reverts on invalid or zero addresses.
     * @custom:state-changes Updates pool, vault, stQEURO and treasury references.
     * @custom:events None.
     * @custom:errors Protocol‑specific config errors.
     * @custom:reentrancy Not applicable.
     * @custom:access Governance‑only.
     * @custom:oracle No oracle dependency.
     */
    function configureDependencies(YieldDependencyConfig calldata cfg) external;

    /**
     * @notice Sets authorization status and yield type for a yield source.
     * @dev See `YieldShift.setYieldSourceAuthorization` for implementation semantics.
     * @param source Address of the yield source.
     * @param yieldType Type/category of yield generated by the source.
     * @param authorized True to authorize, false to deauthorize.
     * @custom:security Restricted to governance; prevents arbitrary contracts from adding yield.
     * @custom:validation Reverts on zero `source` address.
     * @custom:state-changes Updates authorization and source‑type mappings.
     * @custom:events None.
     * @custom:errors Protocol‑specific validation errors.
     * @custom:reentrancy Not applicable.
     * @custom:access Governance‑only.
     * @custom:oracle No oracle dependency.
     */
    function setYieldSourceAuthorization(address source, bytes32 yieldType, bool authorized) external;

    /**
     * @notice Binds a source to a single vault id for optional strict routing.
     * @dev Governance hook used to restrict a source to one vault when enforcement is enabled.
     * @param source Yield source address.
     * @param vaultId Vault id the source is allowed to target in strict mode.
     * @custom:security Restricted to governance in implementation.
     * @custom:validation Reverts on zero source or invalid vault id per implementation rules.
     * @custom:state-changes Updates source-to-vault binding map.
     * @custom:events Emits binding update event in implementation.
     * @custom:errors Reverts on invalid inputs or unauthorized access.
     * @custom:reentrancy Not applicable.
     * @custom:access Governance-only.
     * @custom:oracle No oracle dependency.
     */
    function setSourceVaultBinding(address source, uint256 vaultId) external;

    /**
     * @notice Clears a source-to-vault binding.
     * @dev Governance hook that removes strict routing assignment for a source.
     * @param source Yield source address.
     * @custom:security Restricted to governance in implementation.
     * @custom:validation Reverts on zero source per implementation rules.
     * @custom:state-changes Deletes source-to-vault binding entry.
     * @custom:events Emits binding clear event in implementation.
     * @custom:errors Reverts on invalid inputs or unauthorized access.
     * @custom:reentrancy Not applicable.
     * @custom:access Governance-only.
     * @custom:oracle No oracle dependency.
     */
    function clearSourceVaultBinding(address source) external;

    /**
     * @notice Enables or disables strict source-to-vault binding enforcement.
     * @dev Governance toggle controlling whether `addYield` must respect source bindings.
     * @param enabled True to enforce binding in `addYield`.
     * @custom:security Restricted to governance in implementation.
     * @custom:validation Boolean input only; no additional validation required.
     * @custom:state-changes Updates binding-enforcement flag.
     * @custom:events Emits enforcement toggle event in implementation.
     * @custom:errors Reverts on unauthorized access.
     * @custom:reentrancy Not applicable.
     * @custom:access Governance-only.
     * @custom:oracle No oracle dependency.
     */
    function setSourceVaultBindingEnforcement(bool enabled) external;

    /**
     * @notice Executes an emergency yield distribution with explicit pool amounts.
     * @dev Transfers specified portions of yield pool balances to UserPool and HedgerPool.
     * @param userAmount Amount to distribute to user pool.
     * @param hedgerAmount Amount to distribute to hedger pool.
     * @custom:security Restricted to emergency role; validates pool sufficiency.
     * @custom:validation Reverts if requested amounts exceed available pools.
     * @custom:state-changes Decreases internal pools and transfers USDC to pools.
     * @custom:events Emits implementation‑specific emergency distribution events.
     * @custom:errors Reverts with insufficient‑yield errors.
     * @custom:reentrancy Protected by nonReentrant modifier in implementation.
     * @custom:access Emergency‑only.
     * @custom:oracle No oracle dependency.
     */
    function emergencyYieldDistribution(uint256 userAmount, uint256 hedgerAmount) external;

    /**
     * @notice Pauses yield distribution operations.
     * @dev Emergency function to halt yield‑related state changes.
     * @custom:security Restricted to emergency role.
     * @custom:validation None.
     * @custom:state-changes Sets paused state to true.
     * @custom:events Emits `Paused`.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Emergency‑only.
     * @custom:oracle No oracle dependency.
     */
    function pauseYieldDistribution() external;

    /**
     * @notice Resumes yield distribution operations after a pause.
     * @dev Clears the paused state to restore normal operation.
     * @custom:security Restricted to emergency role.
     * @custom:validation None.
     * @custom:state-changes Sets paused state to false.
     * @custom:events Emits `Unpaused`.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Emergency‑only.
     * @custom:oracle No oracle dependency.
     */
    function resumeYieldDistribution() external;

    /**
     * @notice Checks if a yield source is authorized for a given yield type.
     * @dev Reads the authorization and yield‑type mapping configured by governance.
     * @param source Address of the yield source.
     * @param yieldType Yield type identifier.
     * @return authorized True if `source` is authorized for `yieldType`.
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function isYieldSourceAuthorized(address source, bytes32 yieldType) external view returns (bool authorized);

    /**
     * @notice Checks current conditions and updates yield distribution if required.
     * @dev Uses TWAP metrics and tolerance thresholds to decide whether to call `updateYieldDistribution`.
     * @custom:security Public keeper function; guarded by internal conditions.
     * @custom:validation None.
     * @custom:state-changes May update `currentYieldShift`, snapshots and timestamps indirectly.
     * @custom:events Emits `YieldDistributionUpdated` when distribution is adjusted.
     * @custom:errors None when conditions are not met; may revert on configuration errors.
     * @custom:reentrancy Protected by nonReentrant modifier in implementation.
     * @custom:access Public/keeper‑triggered.
     * @custom:oracle No oracle dependency.
     */
    function checkAndUpdateYieldDistribution() external;

    /**
     * @notice Forces an immediate yield‑distribution update regardless of conditions.
     * @dev Governance escape hatch calling `updateYieldDistribution` via `this` to preserve modifiers.
     * @custom:security Restricted to governance; overrides normal TWAP/tolerance checks.
     * @custom:validation None beyond access‑control.
     * @custom:state-changes Same as `updateYieldDistribution`.
     * @custom:events Emits `YieldDistributionUpdated`.
     * @custom:errors Reverts with configuration or math errors.
     * @custom:reentrancy Protected by nonReentrant modifier in implementation.
     * @custom:access Governance‑only.
     * @custom:oracle No oracle dependency.
     */
    function forceUpdateYieldDistribution() external;

    /**
     * @notice Returns a breakdown of yield between user and hedger pools.
     * @dev Aggregates `userYieldPool` and `hedgerYieldPool` into a distribution ratio.
     * @return userYieldPool_ Current user yield pool balance.
     * @return hedgerYieldPool_ Current hedger yield pool balance.
     * @return distributionRatio User share of total yield pool in basis points.
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public – for dashboards and analytics.
     * @custom:oracle No oracle dependency.
     */
    function getYieldDistributionBreakdown()
        external
        view
        returns (
            uint256 userYieldPool_,
            uint256 hedgerYieldPool_,
            uint256 distributionRatio
        );

    /**
     * @notice Returns current pool metrics for user and hedger pools.
     * @dev Exposes pool sizes, current ratio and target ratio for monitoring.
     * @return userPoolSize Current user pool size.
     * @return hedgerPoolSize Current hedger pool size.
     * @return poolRatio Ratio of user to hedger pools.
     * @return targetRatio Target pool ratio configured in the model.
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function getPoolMetrics()
        external
        view
        returns (
            uint256 userPoolSize,
            uint256 hedgerPoolSize,
            uint256 poolRatio,
            uint256 targetRatio
        );

    /**
     * @notice Calculates the optimal yield shift based on current pool metrics.
     * @dev Purely view‑based recommendation; does not update state.
     * @return optimalShift Recommended yield shift in basis points.
     * @return currentDeviation Absolute deviation between current and optimal shifts.
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public – off‑chain controllers may act on it.
     * @custom:oracle No oracle dependency.
     */
    function calculateOptimalYieldShift() external view returns (uint256 optimalShift, uint256 currentDeviation);

    /**
     * @notice Returns aggregated yield amounts by source category.
     * @dev Splits `yieldSources` into Aave, protocol fees, interest differential and other.
     * @return aaveYield Yield attributed to Aave.
     * @return protocolFees Yield attributed to protocol fees.
     * @return interestDifferential Yield attributed to interest‑rate differential.
     * @return otherSources Residual yield not in the known categories.
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public – for analytics.
     * @custom:oracle No oracle dependency.
     */
    function getYieldSources()
        external
        view
        returns (
            uint256 aaveYield,
            uint256 protocolFees,
            uint256 interestDifferential,
            uint256 otherSources
        );

    /**
     * @notice Returns a compact summary of yield‑shift behavior over a period.
     * @dev Implementation currently returns a representative single value for the window.
     * @param period Look‑back period in seconds.
     * @return averageShift Representative shift in the period.
     * @return maxShift Same as `averageShift` in compact mode.
     * @return minShift Same as `averageShift` in compact mode.
     * @return volatility Always 0 in compact summary mode.
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public – for historical analytics.
     * @custom:oracle No oracle dependency.
     */
    function getHistoricalYieldShift(uint256 period)
        external
        view
        returns (
            uint256 averageShift,
            uint256 maxShift,
            uint256 minShift,
            uint256 volatility
        );

    /**
     * @notice Returns compact performance metrics for yield operations.
     * @dev Aggregates total distributed yield, current pools and efficiency ratio.
     * @return totalYieldDistributed_ Total yield distributed so far.
     * @return averageUserYield Current user yield pool balance.
     * @return averageHedgerYield Current hedger yield pool balance.
     * @return yieldEfficiency Distributed/generate ratio in basis points.
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public – for dashboards and reporting.
     * @custom:oracle No oracle dependency.
     */
    function getYieldPerformanceMetrics()
        external
        view
        returns (
            uint256 totalYieldDistributed_,
            uint256 averageUserYield,
            uint256 averageHedgerYield,
            uint256 yieldEfficiency
        );

    /**
     * @notice Returns the current yield shift between users and hedgers.
     * @dev This value drives how new yield is split between `userYieldPool` and `hedgerYieldPool`.
     * @return shift Current shift value in basis points.
     * @custom:security View‑only.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function currentYieldShift() external view returns (uint256 shift);

    /**
     * @notice Returns total yield generated across all sources.
     * @dev Monotonically increasing counter of all yield ever added via `addYield`.
     * @return total Total generated yield.
     * @custom:security View‑only.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function totalYieldGenerated() external view returns (uint256 total);

    /**
     * @notice Returns total yield distributed so far.
     * @dev Tracks how much of `totalYieldGenerated` has actually been paid out.
     * @return total Total distributed yield.
     * @custom:security View‑only.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function totalYieldDistributed() external view returns (uint256 total);

    /**
     * @notice Returns current user yield pool balance.
     * @dev Amount of yield currently earmarked for users but not yet claimed.
     * @return pool User yield pool amount.
     * @custom:security View‑only.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function userYieldPool() external view returns (uint256 pool);

    /**
     * @notice Returns current hedger yield pool balance.
     * @dev Amount of yield currently earmarked for hedgers but not yet claimed.
     * @return pool Hedger yield pool amount.
     * @custom:security View‑only.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function hedgerYieldPool() external view returns (uint256 pool);

    /**
     * @notice Returns pending yield for a user.
     * @dev Reads per‑user pending yield that can be claimed via `claimUserYield`.
     * @param user User address.
     * @return amount Pending yield amount.
     * @custom:security View‑only.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function userPendingYield(address user) external view returns (uint256 amount);

    /**
     * @notice Returns pending yield for a hedger.
     * @dev Reads per‑hedger pending yield that can be claimed via `claimHedgerYield`.
     * @param hedger Hedger address.
     * @return amount Pending yield amount.
     * @custom:security View‑only.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function hedgerPendingYield(address hedger) external view returns (uint256 amount);

    /**
     * @notice Returns last claim timestamp for a user.
     * @dev Used together with `lastDepositTime` to enforce holding‑period rules.
     * @param user User address.
     * @return timestamp Last claim time.
     * @custom:security View‑only.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function userLastClaim(address user) external view returns (uint256 timestamp);

    /**
     * @notice Returns last claim timestamp for a hedger.
     * @dev Used to monitor hedger reward activity and potential abuse.
     * @param hedger Hedger address.
     * @return timestamp Last claim time.
     * @custom:security View‑only.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function hedgerLastClaim(address hedger) external view returns (uint256 timestamp);

    /**
     * @notice Returns the base yield shift configuration parameter.
     * @dev Baseline user share when pools are perfectly balanced.
     * @return base Base shift value (bps).
     * @custom:security View‑only.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function baseYieldShift() external view returns (uint256 base);

    /**
     * @notice Returns the maximum yield shift configuration parameter.
     * @dev Upper bound for how far `currentYieldShift` may move away from the base.
     * @return maxShift Maximum shift value (bps).
     * @custom:security View‑only.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function maxYieldShift() external view returns (uint256 maxShift);

    /**
     * @notice Returns the adjustment speed configuration parameter.
     * @dev Controls how quickly `currentYieldShift` moves toward the optimal shift.
     * @return speed Adjustment speed in basis points.
     * @custom:security View‑only.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function adjustmentSpeed() external view returns (uint256 speed);

    /**
     * @notice Returns the target pool ratio configuration parameter.
     * @dev Ideal ratio of user‑pool size to hedger‑pool size used in shift calculations.
     * @return ratio Target user/hedger pool ratio in basis points.
     * @custom:security View‑only.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function targetPoolRatio() external view returns (uint256 ratio);

    /**
     * @notice Returns the last time yield distribution was updated.
     * @dev Timestamp used to enforce minimum intervals and TWAP windows between updates.
     * @return timestamp Last update time.
     * @custom:security View‑only.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function lastUpdateTime() external view returns (uint256 timestamp);

    /**
     * @notice Returns whether yield distribution is currently paused.
     * @dev When true, state‑changing yield operations are halted by `Pausable`.
     * @return isPaused True if paused, false otherwise.
     * @custom:security View‑only.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function paused() external view returns (bool isPaused);
}
