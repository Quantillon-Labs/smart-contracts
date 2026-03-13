// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// =============================================================================
// IMPORTS
// =============================================================================

import {ISlippageStorage} from "../interfaces/ISlippageStorage.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {TreasuryRecoveryLibrary} from "../libraries/TreasuryRecoveryLibrary.sol";
import {CommonValidationLibrary} from "../libraries/CommonValidationLibrary.sol";
import {CommonErrorLibrary} from "../libraries/CommonErrorLibrary.sol";
import {TimeProvider} from "../libraries/TimeProviderLibrary.sol";

// =============================================================================
// CONTRACT
// =============================================================================

/**
 * @title SlippageStorage
 * @notice On-chain storage for EUR/USD order book slippage data published by the Slippage Monitor service
 *
 * @dev Key features:
 *      - WRITER_ROLE publishes slippage snapshots (mid price, spread, depth, worst-case bps)
 *      - Rate-limited writes: rejects updates within minUpdateInterval unless deviation > threshold
 *      - MANAGER_ROLE configures interval and threshold parameters
 *      - Pausable by EMERGENCY_ROLE
 *      - UUPS upgradeable
 *
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract SlippageStorage is
    ISlippageStorage,
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;
    using Address for address payable;

    // ============ Constants & Roles ============

    /// @notice Source ID for Lighter DEX (maps to legacy _snapshot slot for backward compat)
    uint8 public constant SOURCE_LIGHTER = 0;

    /// @notice Source ID for Hyperliquid DEX
    uint8 public constant SOURCE_HYPERLIQUID = 1;

    /// @notice Role for the off-chain publisher service wallet
    bytes32 public constant WRITER_ROLE = keccak256("WRITER_ROLE");

    /// @notice Role for config management (interval, threshold)
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @notice Role for emergency pause/unpause
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    /// @notice Role for UUPS upgrades
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @notice Max allowed minUpdateInterval (1 hour)
    uint48 public constant MAX_UPDATE_INTERVAL = 3600;

    /// @notice Max allowed deviation threshold (500 bps = 5%)
    uint16 public constant MAX_DEVIATION_THRESHOLD = 500;

    // ============ State Variables ============

    /// @notice Current slippage snapshot (2 packed storage slots)
    SlippageSnapshot private _snapshot;

    /// @notice Minimum seconds between successive updates (rate limit)
    uint48 public override minUpdateInterval;

    /// @notice Deviation in bps that bypasses rate limit for immediate updates
    uint16 public override deviationThresholdBps;

    /// @notice Treasury address for recovery functions
    address public treasury;

    /// @notice Snapshots for sources other than SOURCE_LIGHTER (which uses _snapshot for compat)
    mapping(uint8 sourceId => SlippageSnapshot) private _sourceSnapshots;

    /// @notice Bitmask of enabled sources: bit N = source N enabled. 0x03 = both Lighter + Hyperliquid.
    uint8 public override enabledSources;

    /// @notice Shared time provider for deterministic timestamp reads
    TimeProvider public immutable TIME_PROVIDER;

    // ============ Constructor ============

    /**
     * @notice Disables initializers to prevent direct implementation contract use
     * @dev Called once at deployment time by the EVM. Prevents the implementation
     *      contract from being initialized directly (only proxy is initializable).
     * @param _TIME_PROVIDER Shared protocol time provider used for deterministic timestamps
     * @custom:security Calls _disableInitializers() to prevent re-initialization attacks
     * @custom:validation No input validation required
     * @custom:state-changes Disables all initializer functions permanently
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not applicable - constructor
     * @custom:access Public - called once at deployment
     * @custom:oracle No oracle dependencies
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(TimeProvider _TIME_PROVIDER) {
        if (address(_TIME_PROVIDER) == address(0)) revert CommonErrorLibrary.ZeroAddress();
        TIME_PROVIDER = _TIME_PROVIDER;
        _disableInitializers();
    }

    // ============ Initialization ============

    /**
     * @notice Initialize the SlippageStorage contract
     * @dev Sets up roles, rate-limit parameters, and treasury. Calls OpenZeppelin
     *      initializers for AccessControl, Pausable, and UUPSUpgradeable.
     *      Admin receives DEFAULT_ADMIN_ROLE, MANAGER_ROLE, EMERGENCY_ROLE, and UPGRADER_ROLE.
     * @param admin Address receiving DEFAULT_ADMIN_ROLE and all management roles
     * @param writer Address receiving WRITER_ROLE (the off-chain publisher service wallet)
     * @param minInterval Minimum seconds between successive writes (0..MAX_UPDATE_INTERVAL)
     * @param deviationThreshold Deviation in bps that bypasses rate limit (0..MAX_DEVIATION_THRESHOLD)
     * @param _treasury Treasury address for token/ETH recovery
     * @param initialEnabledSources Bitmask of initially enabled sources (0x01=Lighter, 0x02=Hyperliquid, 0x03=both)
     * @custom:security Validates admin, writer, and treasury are non-zero; enforces config bounds
     * @custom:validation Validates admin != address(0), writer != address(0), treasury != address(0),
     *                    minInterval <= MAX_UPDATE_INTERVAL, deviationThreshold <= MAX_DEVIATION_THRESHOLD
     * @custom:state-changes Grants roles, sets minUpdateInterval, deviationThresholdBps, treasury
     * @custom:events No events emitted (OpenZeppelin initializers emit no events)
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
        address _treasury,
        uint8   initialEnabledSources
    ) external override initializer {
        if (admin == address(0) || writer == address(0) || _treasury == address(0)) {
            revert CommonErrorLibrary.ZeroAddress();
        }
        CommonValidationLibrary.validateNonZeroAddress(admin, "admin");
        CommonValidationLibrary.validateNonZeroAddress(writer, "admin");
        CommonValidationLibrary.validateNonZeroAddress(_treasury, "treasury");

        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(WRITER_ROLE, writer);
        _grantRole(MANAGER_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        if (minInterval > MAX_UPDATE_INTERVAL) revert CommonErrorLibrary.ConfigValueTooHigh();
        if (deviationThreshold > MAX_DEVIATION_THRESHOLD) revert CommonErrorLibrary.ConfigValueTooHigh();

        minUpdateInterval = minInterval;
        deviationThresholdBps = deviationThreshold;
        treasury = _treasury;
        enabledSources = initialEnabledSources;
    }

    // ============ Write Functions ============

    /**
     * @notice Publish a new slippage snapshot on-chain
     * @dev Rate-limited: if within minUpdateInterval since last update, only allows
     *      the write when |newWorstCaseBps - lastWorstCaseBps| > deviationThresholdBps.
     *      First update always succeeds (timestamp == 0 means no prior data).
     *      Packs all fields into a single SlippageSnapshot struct for efficient storage.
     * @param midPrice EUR/USD mid price (18 decimals)
     * @param depthEur Total ask depth in EUR (18 decimals)
     * @param worstCaseBps Worst-case slippage across buckets (bps)
     * @param spreadBps Bid-ask spread (bps)
     * @param bucketBps Per-size slippage in bps, fixed order: [10k, 50k, 100k, 250k, 1M]
     * @custom:security Requires WRITER_ROLE; blocked when paused; rate-limited by minUpdateInterval
     * @custom:validation Checks elapsed time since last update; if within interval, validates
     *                    |worstCaseBps - lastWorstCaseBps| > deviationThresholdBps
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
    ) external override onlyRole(WRITER_ROLE) whenNotPaused {
        uint48 nowTs = uint48(TIME_PROVIDER.currentTime());
        uint48 lastTs = _snapshot.timestamp;

        // Rate limit check (skip for first-ever update when lastTs < 1)
        if (lastTs >= 1) {
            if (nowTs <= lastTs || nowTs - lastTs < minUpdateInterval) {
                uint16 lastBps = _snapshot.worstCaseBps;
                uint16 diff = worstCaseBps > lastBps
                    ? worstCaseBps - lastBps
                    : lastBps - worstCaseBps;
                if (diff <= deviationThresholdBps) {
                    revert CommonErrorLibrary.RateLimitTooHigh();
                }
            }
        }

        uint48 ts = nowTs;
        // forge-lint: disable-next-line(unsafe-typecast)
        uint48 bn = uint48(block.number);

        _snapshot = SlippageSnapshot({
            midPrice: midPrice,
            depthEur: depthEur,
            worstCaseBps: worstCaseBps,
            spreadBps: spreadBps,
            timestamp: ts,
            blockNumber: bn,
            bps10k:  bucketBps[0],
            bps50k:  bucketBps[1],
            bps100k: bucketBps[2],
            bps250k: bucketBps[3],
            bps1M:   bucketBps[4]
        });

        emit SlippageUpdated(midPrice, worstCaseBps, spreadBps, depthEur, ts);
    }

    /**
     * @notice Publish slippage snapshots for multiple sources in a single transaction
     * @dev Sources disabled in enabledSources bitmask are silently skipped (no revert).
     *      Rate-limited per source independently: within-interval updates are skipped
     *      unless |diff| > deviationThresholdBps. Lighter source (sourceId=0) writes to
     *      the legacy _snapshot slot for backward compatibility with getSlippage().
     * @param updates Array of per-source snapshot inputs
     * @custom:security Requires WRITER_ROLE; blocked when paused
     * @custom:validation Per-source rate limit: skips (does not revert) if within interval and deviation <= threshold
     * @custom:state-changes Writes each enabled source's snapshot; Lighter updates _snapshot for backward compat
     * @custom:events Emits SlippageSourceUpdated for each source actually written
     * @custom:errors No explicit reverts for rate-limited or disabled sources (silently skipped)
     * @custom:reentrancy Not protected - no external calls made during execution
     * @custom:oracle No on-chain oracle dependency; data is pushed by the off-chain Slippage Monitor
     * @custom:access Restricted to WRITER_ROLE; blocked when contract is paused
     */
    function updateSlippageBatch(
        SourceUpdate[] calldata updates
    ) external override onlyRole(WRITER_ROLE) whenNotPaused {
        uint48 nowTs = uint48(TIME_PROVIDER.currentTime());
        // forge-lint: disable-next-line(unsafe-typecast)
        uint48 bn = uint48(block.number);
        uint8 sources = enabledSources;

        for (uint256 i = 0; i < updates.length; i++) {
            SourceUpdate calldata u = updates[i];

            // Skip sources not enabled in the on-chain bitmask
            if ((sources >> u.sourceId) & 1 == 0) continue;

            // Lighter (sourceId=0) reuses the legacy _snapshot slot for backward compat
            SlippageSnapshot storage snap = u.sourceId == SOURCE_LIGHTER
                ? _snapshot
                : _sourceSnapshots[u.sourceId];

            // Rate limit check per source (first-ever update when timestamp == 0 always passes)
            uint48 lastTs = snap.timestamp;
            if (lastTs >= 1) {
                if (nowTs <= lastTs || nowTs - lastTs < minUpdateInterval) {
                    uint16 diff = u.worstCaseBps > snap.worstCaseBps
                        ? u.worstCaseBps - snap.worstCaseBps
                        : snap.worstCaseBps - u.worstCaseBps;
                    if (diff <= deviationThresholdBps) continue; // skip this source, don't revert
                }
            }

            snap.midPrice     = u.midPrice;
            snap.depthEur     = u.depthEur;
            snap.worstCaseBps = u.worstCaseBps;
            snap.spreadBps    = u.spreadBps;
            snap.timestamp    = nowTs;
            snap.blockNumber  = bn;
            snap.bps10k       = u.bucketBps[0];
            snap.bps50k       = u.bucketBps[1];
            snap.bps100k      = u.bucketBps[2];
            snap.bps250k      = u.bucketBps[3];
            snap.bps1M        = u.bucketBps[4];

            emit SlippageSourceUpdated(u.sourceId, u.midPrice, u.worstCaseBps, u.spreadBps, u.depthEur, nowTs);
        }
    }

    // ============ Config Functions ============

    /**
     * @notice Update the minimum interval between successive slippage writes
     * @dev Allows the manager to tighten or relax the rate limit. Setting to 0
     *      effectively disables the rate limit; MAX_UPDATE_INTERVAL caps it at 1 hour.
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
    /**
     * @notice Update the bitmask of sources enabled for storage in updateSlippageBatch
     * @dev Bit 0 = SOURCE_LIGHTER, Bit 1 = SOURCE_HYPERLIQUID.
     *      0x03 enables both. Disabled sources are silently skipped in batch writes without reverting.
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
    function setEnabledSources(uint8 mask) external override onlyRole(MANAGER_ROLE) {
        uint8 old = enabledSources;
        enabledSources = mask;
        emit EnabledSourcesUpdated(old, mask);
    }

    /**
     * @notice Update the minimum interval between successive slippage writes
     * @dev Allows the manager to tighten or relax the rate limit. Setting to 0
     *      effectively disables the rate limit; MAX_UPDATE_INTERVAL caps it at 1 hour.
     * @param newInterval New minimum interval in seconds (0..MAX_UPDATE_INTERVAL)
     * @custom:security Requires MANAGER_ROLE; enforces upper bound MAX_UPDATE_INTERVAL
     * @custom:validation Validates newInterval <= MAX_UPDATE_INTERVAL
     * @custom:state-changes Updates minUpdateInterval state variable
     * @custom:events Emits ConfigUpdated("minUpdateInterval", oldValue, newValue)
     * @custom:errors Reverts with ConfigValueTooHigh if newInterval > MAX_UPDATE_INTERVAL
     * @custom:reentrancy Not protected - no external calls made
     * @custom:oracle No oracle dependencies
     * @custom:access Restricted to MANAGER_ROLE
     */
    function setMinUpdateInterval(uint48 newInterval) external override onlyRole(MANAGER_ROLE) {
        if (newInterval > MAX_UPDATE_INTERVAL) revert CommonErrorLibrary.ConfigValueTooHigh();
        uint48 old = minUpdateInterval;
        minUpdateInterval = newInterval;
        emit ConfigUpdated("minUpdateInterval", uint256(old), uint256(newInterval));
    }

    /**
     * @notice Update the worst-case bps deviation threshold that bypasses the rate limit
     * @dev When the absolute difference between the new worstCaseBps and the stored
     *      worstCaseBps exceeds this threshold, the rate limit is bypassed and the
     *      update proceeds immediately regardless of minUpdateInterval.
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
    function setDeviationThreshold(uint16 newThreshold) external override onlyRole(MANAGER_ROLE) {
        if (newThreshold > MAX_DEVIATION_THRESHOLD) revert CommonErrorLibrary.ConfigValueTooHigh();
        uint16 old = deviationThresholdBps;
        deviationThresholdBps = newThreshold;
        emit ConfigUpdated("deviationThresholdBps", uint256(old), uint256(newThreshold));
    }

    // ============ Emergency Functions ============

    /**
     * @notice Pause the contract, blocking all slippage updates
     * @dev Once paused, updateSlippage will revert with a Paused error until unpaused.
     *      Used in emergency scenarios (e.g. off-chain service malfunction).
     * @custom:security Requires EMERGENCY_ROLE; prevents unauthorized pausing
     * @custom:validation No input validation required
     * @custom:state-changes Sets OpenZeppelin Pausable internal paused flag to true
     * @custom:events Emits Paused(account) from OpenZeppelin PausableUpgradeable
     * @custom:errors No errors thrown if already unpaused (OZ handles idempotently)
     * @custom:reentrancy Not protected - no external calls made
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle No oracle dependencies
     */
    function pause() external override onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the contract, resuming slippage updates
     * @dev Restores normal operation after an emergency pause. The WRITER_ROLE
     *      can immediately publish new snapshots once unpaused.
     * @custom:security Requires EMERGENCY_ROLE; prevents unauthorized unpausing
     * @custom:validation No input validation required
     * @custom:state-changes Sets OpenZeppelin Pausable internal paused flag to false
     * @custom:events Emits Unpaused(account) from OpenZeppelin PausableUpgradeable
     * @custom:errors No errors thrown if already unpaused (OZ handles idempotently)
     * @custom:reentrancy Not protected - no external calls made
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle No oracle dependencies
     */
    function unpause() external override onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }

    // ============ View Functions ============

    /**
     * @notice Get the full current slippage snapshot
     * @dev Returns the entire _snapshot struct including midPrice, depthEur,
     *      worstCaseBps, spreadBps, timestamp, blockNumber, and all bucketBps.
     *      Returns a zero-valued struct if updateSlippage has never been called.
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
    function getSlippage() external view override returns (SlippageSnapshot memory snapshot) {
        return _snapshot;
    }

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
    function getBucketBps() external view override returns (uint16[5] memory bucketBps) {
        bucketBps[0] = _snapshot.bps10k;
        bucketBps[1] = _snapshot.bps50k;
        bucketBps[2] = _snapshot.bps100k;
        bucketBps[3] = _snapshot.bps250k;
        bucketBps[4] = _snapshot.bps1M;
    }

    /**
     * @notice Get seconds elapsed since the last on-chain slippage update
     * @dev Returns 0 if no update has ever been published (timestamp == 0).
     *      Consumers can use this to assess data freshness before relying on it.
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
    function getSlippageAge() external view override returns (uint256 age) {
        if (_snapshot.timestamp < 1) return 0;
        uint256 nowTs = TIME_PROVIDER.currentTime();
        uint256 snapshotTs = uint256(_snapshot.timestamp);
        if (nowTs <= snapshotTs) return 0;
        return nowTs - snapshotTs;
    }

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
    function getSlippageBySource(uint8 sourceId) external view override returns (SlippageSnapshot memory snapshot) {
        return sourceId == SOURCE_LIGHTER ? _snapshot : _sourceSnapshots[sourceId];
    }

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
    function getSlippageAgeBySource(uint8 sourceId) external view override returns (uint256 age) {
        SlippageSnapshot storage snap = sourceId == SOURCE_LIGHTER
            ? _snapshot
            : _sourceSnapshots[sourceId];
        if (snap.timestamp < 1) return 0;
        uint256 nowTs = TIME_PROVIDER.currentTime();
        uint256 snapshotTs = uint256(snap.timestamp);
        if (nowTs <= snapshotTs) return 0;
        return nowTs - snapshotTs;
    }

    // ============ Recovery Functions ============

    /**
     * @notice Recover ERC20 tokens accidentally sent to this contract
     * @dev Transfers the specified token amount to the treasury address using
     *      TreasuryRecoveryLibrary. Use to rescue tokens that were mistakenly sent.
     * @param token ERC20 token contract address to recover
     * @param amount Amount of tokens to transfer to treasury (token decimals)
     * @custom:security Requires DEFAULT_ADMIN_ROLE; prevents unauthorized token withdrawals
     * @custom:validation Implicitly validates via SafeERC20 transfer
     * @custom:state-changes No internal state changes; transfers token balance externally
     * @custom:events No events emitted from this contract
     * @custom:errors Reverts if transfer fails (SafeERC20 revert)
     * @custom:reentrancy Not protected - external ERC20 call; admin-only mitigates risk
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependencies
     */
    function recoverToken(address token, uint256 amount) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        TreasuryRecoveryLibrary.recoverToken(token, amount, address(this), treasury);
    }

    /**
     * @notice Recover ETH accidentally sent to this contract
     * @dev Transfers the entire ETH balance to the treasury address using
     *      TreasuryRecoveryLibrary. The receive() function allows ETH to accumulate.
     * @custom:security Requires DEFAULT_ADMIN_ROLE; prevents unauthorized ETH withdrawals
     * @custom:validation No input validation required; uses address(this).balance
     * @custom:state-changes No internal state changes; transfers ETH balance externally
     * @custom:events Emits ETHRecovered(treasury, amount)
     * @custom:errors Reverts if ETH transfer fails
     * @custom:reentrancy Not protected - external ETH transfer; admin-only mitigates risk
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependencies
     */
    function recoverETH() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (treasury == address(0)) revert CommonErrorLibrary.InvalidAddress();
        uint256 balance = address(this).balance;
        if (balance < 1) revert CommonErrorLibrary.NoETHToRecover();
        emit ETHRecovered(treasury, balance);
        payable(treasury).sendValue(balance);
    }

    // ============ Admin Functions ============

    /**
     * @notice Update the treasury address used for token/ETH recovery
     * @dev The treasury is the destination for recoverToken and recoverETH calls.
     *      Must be a non-zero address to prevent accidental loss of recovered funds.
     * @param _treasury New treasury address (must be non-zero)
     * @custom:security Requires DEFAULT_ADMIN_ROLE; validates non-zero address
     * @custom:validation Validates _treasury != address(0) via CommonValidationLibrary
     * @custom:state-changes Updates the treasury state variable
     * @custom:events Emits TreasuryUpdated(_treasury)
     * @custom:errors Reverts with ZeroAddress if _treasury is address(0)
     * @custom:reentrancy Not protected - no external calls made
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependencies
     */
    function updateTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_treasury == address(0)) revert CommonErrorLibrary.ZeroAddress();
        CommonValidationLibrary.validateNonZeroAddress(_treasury, "treasury");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    // ============ Upgrade Function ============

    /**
     * @notice Authorize a UUPS proxy upgrade to a new implementation
     * @dev Called internally by UUPSUpgradeable.upgradeTo/upgradeToAndCall.
     *      Validates the new implementation address is non-zero before authorizing.
     * @param newImplementation Address of the new implementation contract
     * @custom:security Requires UPGRADER_ROLE; validates newImplementation is non-zero
     * @custom:validation Validates newImplementation != address(0)
     * @custom:state-changes No state changes in this function (upgrade handled by UUPS base)
     * @custom:events No events emitted from this function
     * @custom:errors Reverts with ZeroAddress if newImplementation is address(0)
     * @custom:reentrancy Not protected - internal function; called within upgrade transaction
     * @custom:access Restricted to UPGRADER_ROLE
     * @custom:oracle No oracle dependencies
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) view {
        if (newImplementation == address(0)) revert CommonErrorLibrary.ZeroAddress();
    }

    /**
     * @notice Accept ETH sent directly to the contract
     * @dev Allows the contract to receive ETH so that recoverETH can retrieve it.
     *      Used primarily for recovery testing to simulate accidental ETH deposits.
     * @custom:security No restrictions - any address can send ETH; admin can recover via recoverETH
     * @custom:validation No input validation required
     * @custom:state-changes No state changes - ETH balance increases implicitly
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not applicable - receive function
     * @custom:access Public - no restrictions
     * @custom:oracle No oracle dependencies
     */
    receive() external payable {}
}
