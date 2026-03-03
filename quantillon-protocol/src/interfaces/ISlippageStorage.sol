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

    /// @notice Emitted when slippage data is updated on-chain
    event SlippageUpdated(
        uint128 midPrice,
        uint16  worstCaseBps,
        uint16  spreadBps,
        uint128 depthEur,
        uint48  timestamp
    );

    /// @notice Emitted when a config parameter is changed
    event ConfigUpdated(string indexed param, uint256 oldValue, uint256 newValue);

    /// @notice Emitted when treasury address is updated
    event TreasuryUpdated(address indexed newTreasury);

    /// @notice Emitted when ETH is recovered from the contract
    event ETHRecovered(address indexed to, uint256 amount);

    // ============ Write Functions ============

    /// @notice Initialize the contract
    /// @param admin Address with DEFAULT_ADMIN_ROLE
    /// @param writer Address with WRITER_ROLE (publisher service wallet)
    /// @param minInterval Minimum seconds between updates (rate limit)
    /// @param deviationThreshold Deviation in bps that bypasses rate limit
    /// @param treasury Treasury address for recovery functions
    function initialize(
        address admin,
        address writer,
        uint48  minInterval,
        uint16  deviationThreshold,
        address treasury
    ) external;

    /// @notice Publish a new slippage snapshot on-chain
    /// @dev WRITER_ROLE only. Rate-limited: rejects if within minUpdateInterval
    ///      unless |newWorstCaseBps - lastWorstCaseBps| > deviationThresholdBps.
    /// @param midPrice EUR/USD mid price (18 decimals)
    /// @param depthEur Total ask depth in EUR (18 decimals)
    /// @param worstCaseBps Worst-case slippage across buckets (bps)
    /// @param spreadBps Bid-ask spread (bps)
    /// @param bucketBps Per-size slippage in bps, fixed order: [10k, 50k, 100k, 250k, 1M]
    function updateSlippage(
        uint128 midPrice,
        uint128 depthEur,
        uint16  worstCaseBps,
        uint16  spreadBps,
        uint16[5] calldata bucketBps
    ) external;

    // ============ Config Functions ============

    /// @notice Update the minimum interval between updates
    /// @param newInterval New interval in seconds
    function setMinUpdateInterval(uint48 newInterval) external;

    /// @notice Update the deviation threshold that bypasses rate limit
    /// @param newThreshold New threshold in bps
    function setDeviationThreshold(uint16 newThreshold) external;

    // ============ Emergency Functions ============

    /// @notice Pause the contract (blocks updateSlippage)
    function pause() external;

    /// @notice Unpause the contract
    function unpause() external;

    // ============ View Functions ============

    /// @notice Get the current slippage snapshot
    /// @return snapshot The latest SlippageSnapshot struct
    function getSlippage() external view returns (SlippageSnapshot memory snapshot);

    /// @notice Get per-bucket slippage bps in canonical order [10k, 50k, 100k, 250k, 1M]
    /// @return bucketBps Array of 5 uint16 bps values
    function getBucketBps() external view returns (uint16[5] memory bucketBps);

    /// @notice Get seconds since the last on-chain update
    /// @return age Seconds since last update (0 if never updated)
    function getSlippageAge() external view returns (uint256 age);

    /// @notice Get the current minimum update interval
    /// @return interval Seconds
    function minUpdateInterval() external view returns (uint48 interval);

    /// @notice Get the current deviation threshold
    /// @return threshold Bps
    function deviationThresholdBps() external view returns (uint16 threshold);

    // ============ Recovery Functions ============

    /// @notice Recover ERC20 tokens accidentally sent to the contract
    /// @param token Token address
    /// @param amount Amount to recover
    function recoverToken(address token, uint256 amount) external;

    /// @notice Recover ETH accidentally sent to the contract
    function recoverETH() external;
}
