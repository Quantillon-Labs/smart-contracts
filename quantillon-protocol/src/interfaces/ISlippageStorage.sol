// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title ISlippageStorage
 * @notice Interface for the Quantillon SlippageStorage contract
 * @dev Stores on-chain slippage data published by an off-chain service.
 *      Provides rate-limited writes via WRITER_ROLE and config management via MANAGER_ROLE.
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
interface ISlippageStorage {

    // ============ Structs ============

    /// @notice Input for one source in a batch update
    struct SourceUpdate {
        uint8     sourceId;     // SOURCE_LIGHTER=0, SOURCE_HYPERLIQUID=1
        uint128   midPrice;     // EUR/USD mid price (18 decimals)
        uint128   depthEur;     // Total ask depth in EUR (18 decimals)
        uint16    worstCaseBps;
        uint16    spreadBps;
        uint16[5] bucketBps;   // [10k, 50k, 100k, 250k, 1M]
    }

    /// @notice Packed on-chain slippage snapshot (2 storage slots)
    /// @dev Storage layout (must not be reordered — UUPS upgrade-safe):
    ///      Slot 0 (32 bytes): midPrice (uint128) + depthEur (uint128)
    ///      Slot 1 (26/32 bytes): worstCaseBps (2) + spreadBps (2) + timestamp (6) +
    ///             blockNumber (6) + bps10k (2) + bps50k (2) + bps100k (2) + bps250k (2) + bps1M (2)
    ///      Individual uint16 fields are used instead of uint16[5] because Solidity
    ///      arrays always start a new storage slot, which would waste a full slot.
    struct SlippageSnapshot {
        uint128 midPrice;       // EUR/USD mid price (18 decimals)
        uint128 depthEur;       // Total ask depth in EUR (18 decimals)
        uint16  worstCaseBps;   // Worst-case slippage across buckets (bps)
        uint16  spreadBps;      // Bid-ask spread (bps)
        uint48  timestamp;      // Block timestamp of update
        uint48  blockNumber;    // Block number of update
        uint16  bps10k;         // Slippage bps for 10k EUR bucket
        uint16  bps50k;         // Slippage bps for 50k EUR bucket
        uint16  bps100k;        // Slippage bps for 100k EUR bucket
        uint16  bps250k;        // Slippage bps for 250k EUR bucket
        uint16  bps1M;          // Slippage bps for 1M EUR bucket
    }

    // ============ Events ============

    /// @notice Emitted when slippage data is updated on-chain (Lighter legacy single-source path)
    event SlippageUpdated(
        uint128 midPrice,
        uint16  worstCaseBps,
        uint16  spreadBps,
        uint128 depthEur,
        uint48  timestamp
    );

    /// @notice Emitted once per source written in updateSlippageBatch
    event SlippageSourceUpdated(
        uint8   indexed sourceId,
        uint128 midPrice,
        uint16  worstCaseBps,
        uint16  spreadBps,
        uint128 depthEur,
        uint48  timestamp
    );

    /// @notice Emitted when the enabledSources bitmask is changed by MANAGER_ROLE
    event EnabledSourcesUpdated(uint8 oldMask, uint8 newMask);

    /// @notice Emitted when a config parameter is changed
    event ConfigUpdated(string indexed param, uint256 oldValue, uint256 newValue);

    /// @notice Emitted when treasury address is updated
    event TreasuryUpdated(address indexed newTreasury);

    /// @notice Emitted when ETH is recovered from the contract
    event ETHRecovered(address indexed to, uint256 amount);

    // ============ Write Functions ============

    /**
     * @notice Initialize the SlippageStorage contract
     * @dev Sets up roles, rate-limit parameters, and treasury. Admin receives
     *      DEFAULT_ADMIN_ROLE, MANAGER_ROLE, EMERGENCY_ROLE, and UPGRADER_ROLE.
     *      Writer receives WRITER_ROLE. Callable only once via proxy deployment.
     * @param admin Address receiving DEFAULT_ADMIN_ROLE and all management roles
     * @param writer Address receiving WRITER_ROLE (the off-chain publisher service wallet)
     * @param minInterval Minimum seconds between successive writes (0..MAX_UPDATE_INTERVAL)
     * @param deviationThreshold Deviation in bps that bypasses rate limit (0..MAX_DEVIATION_THRESHOLD)
     * @param treasury Treasury address for token/ETH recovery
     * @param initialEnabledSources Bitmask of initially enabled sources (0x01=Lighter, 0x02=Hyperliquid, 0x03=both)
     * @custom:security Validates admin, writer, and treasury are non-zero; enforces config bounds
     * @custom:validation Validates admin/writer/treasury != address(0); interval and threshold within max
     * @custom:state-changes Grants roles, sets minUpdateInterval, deviationThresholdBps, treasury
     * @custom:events No events emitted
     * @custom:errors Reverts with ZeroAddress if admin/writer/treasury is zero;
     *               reverts with ConfigValueTooHigh if interval or threshold exceeds max
     * @custom:reentrancy Protected by initializer modifier (callable only once)
     * @custom:access Public - only callable once during proxy deployment
     * @custom:oracle No oracle dependencies
     */
    function initialize(
        address admin,
        address writer,
        uint48  minInterval,
        uint16  deviationThreshold,
        address treasury,
        uint8   initialEnabledSources
    ) external;

    /**
     * @notice Publish a new slippage snapshot on-chain
     * @dev Rate-limited: if within minUpdateInterval since last update, only allows
     *      the write when |newWorstCaseBps - lastWorstCaseBps| > deviationThresholdBps.
     *      First update always succeeds (timestamp == 0 means no prior data).
     * @param midPrice EUR/USD mid price (18 decimals)
     * @param depthEur Total ask depth in EUR (18 decimals)
     * @param worstCaseBps Worst-case slippage across buckets (bps)
     * @param spreadBps Bid-ask spread (bps)
     * @param bucketBps Per-size slippage in bps, fixed order: [10k, 50k, 100k, 250k, 1M]
     * @custom:security Requires WRITER_ROLE; blocked when paused; rate-limited by minUpdateInterval
     * @custom:validation Checks elapsed time since last update; validates deviation if within interval
     * @custom:state-changes Overwrites _snapshot with new values, timestamp, and block number
     * @custom:events Emits SlippageUpdated(midPrice, worstCaseBps, spreadBps, depthEur, timestamp)
     * @custom:errors Reverts with RateLimitTooHigh if within interval and deviation is below threshold
     * @custom:reentrancy Not protected - no external calls made during execution
     * @custom:access Restricted to WRITER_ROLE; blocked when contract is paused
     * @custom:oracle No on-chain oracle dependency; data is pushed by the off-chain Slippage Monitor
     */
    function updateSlippage(
        uint128 midPrice,
        uint128 depthEur,
        uint16  worstCaseBps,
        uint16  spreadBps,
        uint16[5] calldata bucketBps
    ) external;

    /**
     * @notice Publish slippage snapshots for multiple sources in a single transaction
     * @dev Sources disabled in enabledSources bitmask are silently skipped (not reverted).
     *      Rate-limited per source: within-interval updates are skipped unless deviation > threshold.
     *      Lighter source (sourceId=0) writes to the legacy _snapshot slot for backward compat.
     * @param updates Array of per-source snapshot inputs
     * @custom:security Requires WRITER_ROLE; blocked when paused
     * @custom:validation Per-source rate limit: skips (does not revert) if within interval and deviation <= threshold
     * @custom:state-changes Writes each enabled source's snapshot; Lighter updates _snapshot for backward compat
     * @custom:events Emits SlippageSourceUpdated for each source actually written
     * @custom:errors No explicit reverts for rate-limited sources (silently skipped)
     * @custom:reentrancy Not protected - no external calls made during execution
     * @custom:oracle No on-chain oracle dependency; data is pushed by the off-chain Slippage Monitor
     * @custom:access Restricted to WRITER_ROLE; blocked when contract is paused
     */
    function updateSlippageBatch(SourceUpdate[] calldata updates) external;

    // ============ Config Functions ============

    /**
     * @notice Update the minimum interval between successive slippage writes
     * @dev Setting to 0 disables the rate limit; MAX_UPDATE_INTERVAL caps at 1 hour.
     * @param newInterval New minimum interval in seconds (0..MAX_UPDATE_INTERVAL)
     * @custom:security Requires MANAGER_ROLE; enforces upper bound MAX_UPDATE_INTERVAL
     * @custom:validation Validates newInterval <= MAX_UPDATE_INTERVAL
     * @custom:state-changes Updates minUpdateInterval state variable
     * @custom:events Emits ConfigUpdated("minUpdateInterval", oldValue, newValue)
     * @custom:errors Reverts with ConfigValueTooHigh if newInterval > MAX_UPDATE_INTERVAL
     * @custom:reentrancy Not protected - no external calls made
     * @custom:access Restricted to MANAGER_ROLE
     * @custom:oracle No oracle dependencies
     */
    function setMinUpdateInterval(uint48 newInterval) external;

    /**
     * @notice Update the worst-case bps deviation threshold that bypasses the rate limit
     * @dev When |newWorstCaseBps - lastWorstCaseBps| > threshold, rate limit is bypassed.
     * @param newThreshold New deviation threshold in bps (0..MAX_DEVIATION_THRESHOLD)
     * @custom:security Requires MANAGER_ROLE; enforces upper bound MAX_DEVIATION_THRESHOLD (500 bps)
     * @custom:validation Validates newThreshold <= MAX_DEVIATION_THRESHOLD
     * @custom:state-changes Updates deviationThresholdBps state variable
     * @custom:events Emits ConfigUpdated("deviationThresholdBps", oldValue, newValue)
     * @custom:errors Reverts with ConfigValueTooHigh if newThreshold > MAX_DEVIATION_THRESHOLD
     * @custom:reentrancy Not protected - no external calls made
     * @custom:access Restricted to MANAGER_ROLE
     * @custom:oracle No oracle dependencies
     */
    function setDeviationThreshold(uint16 newThreshold) external;

    // ============ Emergency Functions ============

    /**
     * @notice Pause the contract, blocking all slippage updates
     * @dev Once paused, updateSlippage reverts until unpaused.
     * @custom:security Requires EMERGENCY_ROLE; prevents unauthorized pausing
     * @custom:validation No input validation required
     * @custom:state-changes Sets OpenZeppelin Pausable internal paused flag to true
     * @custom:events Emits Paused(account) from OpenZeppelin PausableUpgradeable
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - no external calls made
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle No oracle dependencies
     */
    function pause() external;

    /**
     * @notice Unpause the contract, resuming slippage updates
     * @dev Restores normal operation; WRITER_ROLE can immediately publish again.
     * @custom:security Requires EMERGENCY_ROLE; prevents unauthorized unpausing
     * @custom:validation No input validation required
     * @custom:state-changes Sets OpenZeppelin Pausable internal paused flag to false
     * @custom:events Emits Unpaused(account) from OpenZeppelin PausableUpgradeable
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - no external calls made
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle No oracle dependencies
     */
    function unpause() external;

    // ============ View Functions ============

    /**
     * @notice Get the full current slippage snapshot
     * @dev Returns a zero-valued struct if updateSlippage has never been called.
     * @return snapshot The latest SlippageSnapshot stored on-chain
     * @custom:security No security concerns - read-only view function
     * @custom:validation No input validation required
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - no restrictions
     * @custom:oracle No oracle dependencies - reads stored state only
     */
    function getSlippage() external view returns (SlippageSnapshot memory snapshot);

    /**
     * @notice Get per-bucket slippage in bps in canonical size order
     * @dev Returns buckets in fixed order: [10k EUR, 50k EUR, 100k EUR, 250k EUR, 1M EUR].
     *      All values are zero if updateSlippage has never been called.
     * @return bucketBps Array of 5 slippage values in bps for each order size bucket
     * @custom:security No security concerns - read-only view function
     * @custom:validation No input validation required
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - no restrictions
     * @custom:oracle No oracle dependencies - reads stored state only
     */
    function getBucketBps() external view returns (uint16[5] memory bucketBps);

    /**
     * @notice Get seconds elapsed since the last on-chain slippage update
     * @dev Returns 0 if no update has ever been published (timestamp == 0).
     * @return age Seconds since last updateSlippage call, or 0 if never updated
     * @custom:security No security concerns - read-only view function
     * @custom:validation No input validation required
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - no restrictions
     * @custom:oracle No oracle dependencies - reads stored timestamp only
     */
    function getSlippageAge() external view returns (uint256 age);

    /**
     * @notice Get the full slippage snapshot for a specific source
     * @dev sourceId=0 (SOURCE_LIGHTER) reads from the legacy _snapshot slot.
     *      Other sourceIds read from _sourceSnapshots mapping.
     *      Returns a zero-valued struct if no data has been published for that source.
     * @param sourceId Source identifier (SOURCE_LIGHTER=0, SOURCE_HYPERLIQUID=1)
     * @return snapshot The latest SlippageSnapshot for the given source
     * @custom:security No security concerns - read-only view function
     * @custom:validation No input validation required
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not applicable - view function
     * @custom:oracle No oracle dependencies - reads stored state only
     * @custom:access Public - no restrictions
     */
    function getSlippageBySource(uint8 sourceId) external view returns (SlippageSnapshot memory snapshot);

    /**
     * @notice Get seconds elapsed since the last on-chain update for a specific source
     * @dev Returns 0 if no update has ever been published for the source (timestamp == 0).
     * @param sourceId Source identifier (SOURCE_LIGHTER=0, SOURCE_HYPERLIQUID=1)
     * @return age Seconds since last update for that source, or 0 if never updated
     * @custom:security No security concerns - read-only view function
     * @custom:validation No input validation required
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not applicable - view function
     * @custom:oracle No oracle dependencies - reads stored timestamp only
     * @custom:access Public - no restrictions
     */
    function getSlippageAgeBySource(uint8 sourceId) external view returns (uint256 age);

    /**
     * @notice Get the bitmask of enabled sources (bit N = source N enabled)
     * @dev Bit 0 = SOURCE_LIGHTER, Bit 1 = SOURCE_HYPERLIQUID. 0x03 = both enabled.
     * @return mask Current enabled sources bitmask
     * @custom:security No security concerns - read-only view function
     * @custom:validation No input validation required
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not applicable - view function
     * @custom:oracle No oracle dependencies
     * @custom:access Public - no restrictions
     */
    function enabledSources() external view returns (uint8 mask);

    /**
     * @notice Update which sources are enabled for storage in updateSlippageBatch
     * @dev Bit 0 = SOURCE_LIGHTER, Bit 1 = SOURCE_HYPERLIQUID. 0x03 = both enabled.
     *      Disabled sources are silently skipped in batch writes without reverting.
     * @param mask New bitmask (0x01=Lighter only, 0x02=Hyperliquid only, 0x03=both)
     * @custom:security Requires MANAGER_ROLE
     * @custom:validation No additional validation; all uint8 values accepted
     * @custom:state-changes Updates enabledSources state variable
     * @custom:events Emits EnabledSourcesUpdated(oldMask, newMask)
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - no external calls made
     * @custom:oracle No oracle dependencies
     * @custom:access Restricted to MANAGER_ROLE
     */
    function setEnabledSources(uint8 mask) external;

    /**
     * @notice Get the current minimum update interval
     * @dev Rate limit applied to consecutive updateSlippage calls.
     * @return interval Minimum seconds required between successive writes
     * @custom:security No security concerns - read-only view function
     * @custom:validation No input validation required
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - no restrictions
     * @custom:oracle No oracle dependencies
     */
    function minUpdateInterval() external view returns (uint48 interval);

    /**
     * @notice Get the current deviation threshold that bypasses the rate limit
     * @dev When |newWorstCaseBps - lastWorstCaseBps| exceeds this, rate limit is bypassed.
     * @return threshold Current deviation threshold in bps
     * @custom:security No security concerns - read-only view function
     * @custom:validation No input validation required
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - no restrictions
     * @custom:oracle No oracle dependencies
     */
    function deviationThresholdBps() external view returns (uint16 threshold);

    // ============ Recovery Functions ============

    /**
     * @notice Recover ERC20 tokens accidentally sent to this contract
     * @dev Transfers the specified amount to the treasury address.
     * @param token ERC20 token contract address to recover
     * @param amount Amount of tokens to transfer to treasury (token decimals)
     * @custom:security Requires DEFAULT_ADMIN_ROLE; prevents unauthorized token withdrawals
     * @custom:validation Implicitly validated via SafeERC20 transfer
     * @custom:state-changes No internal state changes; transfers token balance externally
     * @custom:events No events emitted from this contract
     * @custom:errors Reverts if ERC20 transfer fails (SafeERC20 revert)
     * @custom:reentrancy Not protected - external ERC20 call; admin-only mitigates risk
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependencies
     */
    function recoverToken(address token, uint256 amount) external;

    /**
     * @notice Recover ETH accidentally sent to this contract
     * @dev Transfers the entire ETH balance to the treasury address.
     * @custom:security Requires DEFAULT_ADMIN_ROLE; prevents unauthorized ETH withdrawals
     * @custom:validation No input validation required; uses address(this).balance
     * @custom:state-changes No internal state changes; transfers ETH balance externally
     * @custom:events Emits ETHRecovered(treasury, amount)
     * @custom:errors Reverts if ETH transfer fails
     * @custom:reentrancy Not protected - external ETH transfer; admin-only mitigates risk
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependencies
     */
    function recoverETH() external;
}
