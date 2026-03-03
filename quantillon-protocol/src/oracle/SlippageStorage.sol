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
import {TreasuryRecoveryLibrary} from "../libraries/TreasuryRecoveryLibrary.sol";
import {CommonValidationLibrary} from "../libraries/CommonValidationLibrary.sol";
import {CommonErrorLibrary} from "../libraries/CommonErrorLibrary.sol";

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

    // ============ Constants & Roles ============

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

    // ============ Constructor ============

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ============ Initialization ============

    /**
     * @notice Initialize the SlippageStorage contract
     * @param admin Address with DEFAULT_ADMIN_ROLE
     * @param writer Address with WRITER_ROLE (publisher service wallet)
     * @param minInterval Minimum seconds between updates
     * @param deviationThreshold Deviation in bps that bypasses rate limit
     * @param _treasury Treasury address for recovery functions
     * @custom:security Validates all addresses and config bounds
     * @custom:access Public -- only callable once via initializer
     */
    function initialize(
        address admin,
        address writer,
        uint48  minInterval,
        uint16  deviationThreshold,
        address _treasury
    ) external override initializer {
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
    }

    // ============ Write Functions ============

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
     * @custom:security WRITER_ROLE, whenNotPaused, rate-limited
     * @custom:events Emits SlippageUpdated
     * @custom:errors RateLimitTooHigh if within interval and deviation below threshold
     */
    function updateSlippage(
        uint128 midPrice,
        uint128 depthEur,
        uint16  worstCaseBps,
        uint16  spreadBps,
        uint16[5] calldata bucketBps
    ) external override onlyRole(WRITER_ROLE) whenNotPaused {
        uint48 lastTs = _snapshot.timestamp;

        // Rate limit check (skip for first-ever update when lastTs == 0)
        if (lastTs != 0) {
            // forge-lint: disable-next-line(unsafe-typecast)
            uint48 now_ = uint48(block.timestamp);
            if (now_ - lastTs < minUpdateInterval) {
                uint16 lastBps = _snapshot.worstCaseBps;
                uint16 diff = worstCaseBps > lastBps
                    ? worstCaseBps - lastBps
                    : lastBps - worstCaseBps;
                if (diff <= deviationThresholdBps) {
                    revert CommonErrorLibrary.RateLimitTooHigh();
                }
            }
        }

        // forge-lint: disable-next-line(unsafe-typecast)
        uint48 ts = uint48(block.timestamp);
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

    // ============ Config Functions ============

    /**
     * @notice Update the minimum interval between updates
     * @param newInterval New interval in seconds (0 to MAX_UPDATE_INTERVAL)
     * @custom:access MANAGER_ROLE
     * @custom:events Emits ConfigUpdated
     */
    function setMinUpdateInterval(uint48 newInterval) external override onlyRole(MANAGER_ROLE) {
        if (newInterval > MAX_UPDATE_INTERVAL) revert CommonErrorLibrary.ConfigValueTooHigh();
        uint48 old = minUpdateInterval;
        minUpdateInterval = newInterval;
        emit ConfigUpdated("minUpdateInterval", uint256(old), uint256(newInterval));
    }

    /**
     * @notice Update the deviation threshold that bypasses rate limit
     * @param newThreshold New threshold in bps (0 to MAX_DEVIATION_THRESHOLD)
     * @custom:access MANAGER_ROLE
     * @custom:events Emits ConfigUpdated
     */
    function setDeviationThreshold(uint16 newThreshold) external override onlyRole(MANAGER_ROLE) {
        if (newThreshold > MAX_DEVIATION_THRESHOLD) revert CommonErrorLibrary.ConfigValueTooHigh();
        uint16 old = deviationThresholdBps;
        deviationThresholdBps = newThreshold;
        emit ConfigUpdated("deviationThresholdBps", uint256(old), uint256(newThreshold));
    }

    // ============ Emergency Functions ============

    /// @notice Pause the contract (blocks updateSlippage)
    /// @custom:access EMERGENCY_ROLE
    function pause() external override onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    /// @notice Unpause the contract
    /// @custom:access EMERGENCY_ROLE
    function unpause() external override onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }

    // ============ View Functions ============

    /// @notice Get the current slippage snapshot
    function getSlippage() external view override returns (SlippageSnapshot memory snapshot) {
        return _snapshot;
    }

    /// @notice Get per-bucket slippage bps in canonical order [10k, 50k, 100k, 250k, 1M]
    function getBucketBps() external view override returns (uint16[5] memory bucketBps) {
        bucketBps[0] = _snapshot.bps10k;
        bucketBps[1] = _snapshot.bps50k;
        bucketBps[2] = _snapshot.bps100k;
        bucketBps[3] = _snapshot.bps250k;
        bucketBps[4] = _snapshot.bps1M;
    }

    /// @notice Get seconds since the last on-chain update
    /// @return age Seconds since last update (0 if never updated)
    function getSlippageAge() external view override returns (uint256 age) {
        if (_snapshot.timestamp == 0) return 0;
        return block.timestamp - uint256(_snapshot.timestamp);
    }

    // ============ Recovery Functions ============

    /// @notice Recover ERC20 tokens accidentally sent to the contract
    /// @custom:access DEFAULT_ADMIN_ROLE
    function recoverToken(address token, uint256 amount) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        TreasuryRecoveryLibrary.recoverToken(token, amount, address(this), treasury);
    }

    /// @notice Recover ETH accidentally sent to the contract
    /// @custom:access DEFAULT_ADMIN_ROLE
    function recoverETH() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        emit ETHRecovered(treasury, address(this).balance);
        TreasuryRecoveryLibrary.recoverETH(treasury);
    }

    // ============ Admin Functions ============

    /**
     * @notice Update treasury address
     * @param _treasury New treasury address
     * @custom:access DEFAULT_ADMIN_ROLE
     */
    function updateTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        CommonValidationLibrary.validateNonZeroAddress(_treasury, "treasury");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    // ============ Upgrade Function ============

    /// @notice Authorize UUPS upgrade
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) view {
        if (newImplementation == address(0)) revert CommonErrorLibrary.ZeroAddress();
    }

    /// @notice Accept ETH (for recovery testing)
    receive() external payable {}
}
