// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IVersioned} from "../interfaces/IVersioned.sol";

// =============================================================================
// IMPORTS - Quantillon interfaces and OpenZeppelin security
// =============================================================================

import {IOracle} from "../interfaces/IOracle.sol";
import {IHyperliquidOracle} from "../interfaces/IHyperliquidOracle.sol";
import {ISlippageStorage} from "../interfaces/ISlippageStorage.sol";

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {TreasuryRecoveryLibrary} from "../libraries/TreasuryRecoveryLibrary.sol";
import {TimeProvider} from "../libraries/TimeProviderLibrary.sol";
import {CommonValidationLibrary} from "../libraries/CommonValidationLibrary.sol";
import {CommonErrorLibrary} from "../libraries/CommonErrorLibrary.sol";

/**
 * @notice Minimal read surface of SlippageStorage used by this adapter
 * @dev Declared narrowly so the adapter depends only on the per-source mid read, letting both the
 *      real SlippageStorage and lightweight test doubles satisfy it without the full interface.
 *      The selector matches ISlippageStorage.getSlippageBySource(uint8).
 * @custom:security-contact team@quantillon.money
 */
interface ISlippageMidSource {
    /**
     * @notice Returns the latest slippage snapshot for a given source id
     * @param sourceId Source identifier (SOURCE_HYPERLIQUID = 1)
     * @return snapshot Latest snapshot; midPrice (18 decimals) and timestamp are used here
     * @custom:security No security implications - view function
     * @custom:validation No validation - interface definition
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle Interface for SlippageStorage reads
     */
    function getSlippageBySource(uint8 sourceId)
        external
        view
        returns (ISlippageStorage.SlippageSnapshot memory snapshot);
}

/**
 * @title HyperliquidEurUsdOracle
 * @notice EUR/USD oracle for Quantillon that mirrors the Hyperliquid xyz:EUR perp mid used to
 *         execute the protocol hedge, so QEURO mint/redeem prices align with the hedge venue.
 *
 * @dev Design:
 *      - EUR/USD source: the Hyperliquid xyz:EUR mid published on-chain by the off-chain Slippage
 *        Monitor into SlippageStorage (getSlippageBySource(SOURCE_HYPERLIQUID).midPrice, 18 decimals).
 *        The snapshot timestamp is the on-chain write time, used for staleness.
 *      - USDC/USD source: delegated to the existing ChainlinkOracle (the hedge does not change USDC
 *        valuation), kept decoupled so a USDC feed issue cannot block EUR/USD reads.
 *      - Safety: configurable staleness, [min,max] price bounds, per-update deviation circuit
 *        breaker and a last-valid-price fallback — mirroring StorkOracle so the failure modes and
 *        the OracleRouter wiring are identical.
 *
 *      Slots into the OracleRouter's Stork position: the router reads via IOracle and delegates
 *      updatePriceBounds / updateUsdcTolerance / resetCircuitBreaker / triggerCircuitBreaker, all of
 *      which are implemented here with matching selectors. No OracleRouter change is required.
 *
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract HyperliquidEurUsdOracle is
    IHyperliquidOracle,
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    IVersioned
{
    using SafeERC20 for IERC20;
    using Address for address payable;

    /**
     * @notice Returns the semantic version of this implementation.
     * @dev Pure getter read through the proxy; bump per semver on any change.
     * @return Semantic version string (e.g. "1.0.0").
     * @custom:security No security implications - compile-time constant.
     * @custom:validation No input validation required.
     * @custom:state-changes None - pure function.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable - pure function.
     * @custom:access Public - anyone can read the version.
     * @custom:oracle No oracle dependencies.
     */
    function version() external pure virtual override returns (string memory) {
        return "1.0.0";
    }

    // =============================================================================
    // CONSTANTS AND ROLES
    // =============================================================================

    /// @notice Role to manage oracle configurations
    bytes32 public constant ORACLE_MANAGER_ROLE = keccak256("ORACLE_MANAGER_ROLE");

    /// @notice Role for emergency actions
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    /// @notice Role for contract upgrades
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @notice Maximum allowed deviation from previous price (5% = 500 bps)
    uint256 public constant MAX_PRICE_DEVIATION = 500;

    /// @notice Basis for basis points calculations
    uint256 public constant BASIS_POINTS = 10000;

    /// @notice Hard upper bound for the configurable staleness window (1 hour)
    uint256 public constant HARD_MAX_STALENESS = 3600;

    /// @notice Published mid decimals (SlippageStorage stores midPrice in 18 decimals)
    uint8 public constant MID_DECIMALS = 18;

    // =============================================================================
    // STATE VARIABLES
    // =============================================================================

    /// @notice SlippageStorage contract holding the published Hyperliquid mid
    ISlippageMidSource public slippageStorage;

    /// @notice USDC/USD source oracle (the existing ChainlinkOracle)
    IOracle public usdcSource;

    /// @notice Slippage source id to read (SOURCE_HYPERLIQUID = 1)
    uint8 public sourceId;

    /// @notice Treasury address for ETH/token recovery
    address public treasury;

    /// @notice Minimum accepted EUR/USD price (lower circuit breaker, 18 decimals)
    uint256 public minEurUsdPrice;

    /// @notice Maximum accepted EUR/USD price (upper circuit breaker, 18 decimals)
    uint256 public maxEurUsdPrice;

    /// @notice Last valid EUR/USD price recorded (18 decimals) - used as fallback
    uint256 public lastValidEurUsdPrice;

    /// @notice Timestamp of the last valid price update
    uint256 public lastPriceUpdateTime;

    /// @notice Block number of the last valid price update
    uint256 public lastPriceUpdateBlock;

    /// @notice Circuit breaker status (true = triggered, use last valid price)
    bool public circuitBreakerTriggered;

    /// @notice Reported USDC/USD tolerance in basis points (validation lives in usdcSource)
    uint256 public usdcToleranceBps;

    /// @notice Maximum accepted staleness of the published mid, in seconds
    uint256 public maxPriceStaleness;

    // =============================================================================
    // EVENTS
    // =============================================================================

    /// @notice Emitted on each valid price update
    event PriceUpdated(uint256 eurUsdPrice, uint256 usdcUsdPrice, uint256 indexed timestamp);

    /// @notice Emitted when the circuit breaker is triggered
    event CircuitBreakerTriggered(uint256 attemptedPrice, uint256 lastValidPrice, string indexed reason);

    /// @notice Emitted when the circuit breaker is reset
    event CircuitBreakerReset(address indexed admin);

    /// @notice Emitted when price bounds are modified
    event PriceBoundsUpdated(string indexed boundType, uint256 newMinPrice, uint256 newMaxPrice);

    /// @notice Emitted when the slippage source contract or source id is updated
    event SlippageSourceUpdated(address indexed newSlippageStorage, uint8 newSourceId);

    /// @notice Emitted when the USDC/USD source oracle is updated
    event UsdcSourceUpdated(address indexed newUsdcSource);

    /// @notice Emitted when the maximum staleness window is updated
    event MaxStalenessUpdated(uint256 oldStaleness, uint256 newStaleness);

    /// @notice Emitted when the treasury address is updated
    event TreasuryUpdated(address indexed newTreasury);

    /// @notice Emitted when ETH is recovered from the contract
    event ETHRecovered(address indexed to, uint256 amount);

    // =============================================================================
    // INITIALIZER
    // =============================================================================

    /// @notice TimeProvider contract for centralized, testable time
    TimeProvider public immutable TIME_PROVIDER;

    /**
     * @notice Constructor sets the TimeProvider and disables initializers for the proxy pattern
     * @param _TIME_PROVIDER Address of the TimeProvider contract
     * @custom:security Validates TimeProvider is non-zero
     * @custom:validation Validates _TIME_PROVIDER != address(0)
     * @custom:state-changes Sets TIME_PROVIDER immutable and disables initializers
     * @custom:events No events emitted
     * @custom:errors Reverts "Zero address" if _TIME_PROVIDER is zero
     * @custom:reentrancy Not applicable - constructor
     * @custom:access Public - anyone can deploy
     * @custom:oracle No oracle dependencies
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(TimeProvider _TIME_PROVIDER) {
        if (address(_TIME_PROVIDER) == address(0)) revert("Zero address");
        TIME_PROVIDER = _TIME_PROVIDER;
        _disableInitializers();
    }

    /**
     * @notice Initializes the adapter with its price sources and treasury
     * @dev Grants admin/manager/emergency/upgrader roles to admin, sets default bounds, tolerance
     *      and staleness, then attempts a best-effort initial seed from SlippageStorage.
     * @param admin Address with administrator privileges
     * @param _slippageStorage SlippageStorage contract holding the published Hyperliquid mid
     * @param _sourceId Slippage source id to read (SOURCE_HYPERLIQUID = 1)
     * @param _usdcSource Oracle providing USDC/USD (the existing ChainlinkOracle)
     * @param _treasury Treasury address for ETH/token recovery
     * @custom:security Validates all addresses non-zero, grants roles to admin
     * @custom:validation Validates admin/_slippageStorage/_usdcSource/_treasury != address(0)
     * @custom:state-changes Initializes sources, roles, default bounds/staleness/tolerance, seeds price
     * @custom:events Emits PriceUpdated if an initial mid is available
     * @custom:errors Reverts if any address is zero
     * @custom:reentrancy Protected by initializer modifier
     * @custom:access Public - only callable once during proxy deployment
     * @custom:oracle Reads the initial mid from SlippageStorage if present
     */
    function initialize(
        address admin,
        address _slippageStorage,
        uint8 _sourceId,
        address _usdcSource,
        address _treasury
    ) public initializer {
        CommonValidationLibrary.validateNonZeroAddress(admin, "admin");
        CommonValidationLibrary.validateNonZeroAddress(_slippageStorage, "oracle");
        CommonValidationLibrary.validateNonZeroAddress(_usdcSource, "oracle");
        CommonValidationLibrary.validateTreasuryAddress(_treasury);
        CommonValidationLibrary.validateNonZeroAddress(_treasury, "treasury");

        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ORACLE_MANAGER_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        slippageStorage = ISlippageMidSource(_slippageStorage);
        usdcSource = IOracle(_usdcSource);
        sourceId = _sourceId;
        treasury = _treasury;

        // Default EUR/USD bounds (historical extremes), reported USDC tolerance and staleness.
        minEurUsdPrice = 0.80e18;
        maxEurUsdPrice = 1.40e18;
        usdcToleranceBps = 200; // 2%
        maxPriceStaleness = 900; // 15 minutes - valuation-grade freshness

        // Best-effort seed; never reverts and never trips the breaker if no data is published yet.
        _seedInitialPrice();
    }

    // =============================================================================
    // INTERNAL HELPERS
    // =============================================================================

    /**
     * @notice Division with rounding to the nearest integer
     * @param a Numerator
     * @param b Denominator (must be > 0)
     * @return Rounded result of a / b
     * @custom:security Validates denominator is positive
     * @custom:validation Validates b > 0
     * @custom:state-changes None - pure function
     * @custom:events No events emitted
     * @custom:errors Reverts if denominator is zero
     * @custom:reentrancy Not protected - pure function
     * @custom:access Internal
     * @custom:oracle No oracle dependency
     */
    function _divRound(uint256 a, uint256 b) internal pure returns (uint256) {
        CommonValidationLibrary.validatePositiveAmount(b);
        return (a + b / 2) / b;
    }

    /**
     * @notice Validates the published mid timestamp against future-dating and staleness
     * @dev SlippageStorage timestamps are on-chain write times, so they cannot be in the future
     *      except under clock skew; rejects zero (never published) and anything older than maxPriceStaleness.
     * @param reportedTime The snapshot timestamp to validate
     * @return True if the timestamp is fresh and not future-dated
     * @custom:security Bounds acceptable data age for valuation reads
     * @custom:validation Rejects zero, future, or stale timestamps
     * @custom:state-changes None - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - returns false on failure
     * @custom:reentrancy Not protected - view function
     * @custom:access Internal
     * @custom:oracle Uses TimeProvider for current time
     */
    function _validateTimestamp(uint256 reportedTime) internal view returns (bool) {
        if (reportedTime == 0) return false;
        uint256 nowTime = TIME_PROVIDER.currentTime();
        if (reportedTime > nowTime) return false;
        if (nowTime > reportedTime + maxPriceStaleness) return false;
        return true;
    }

    /**
     * @notice Reads the latest Hyperliquid mid and its timestamp from SlippageStorage
     * @return price EUR/USD mid in 18 decimals (0 if unavailable)
     * @return timestamp On-chain write timestamp of the snapshot
     * @custom:security Single external view read of the trusted SlippageStorage
     * @custom:validation No validation here - caller validates freshness/bounds
     * @custom:state-changes None - view function
     * @custom:events No events emitted
     * @custom:errors Reverts only if SlippageStorage reverts (fail-safe for callers that bubble it)
     * @custom:reentrancy Not protected - external staticcall only
     * @custom:access Internal
     * @custom:oracle Reads SlippageStorage.getSlippageBySource(sourceId)
     */
    function _readMid() internal view returns (uint256 price, uint256 timestamp) {
        ISlippageStorage.SlippageSnapshot memory snap = slippageStorage.getSlippageBySource(sourceId);
        price = uint256(snap.midPrice);
        timestamp = uint256(snap.timestamp);
    }

    /**
     * @notice Validates a candidate EUR/USD price against freshness, bounds and deviation
     * @param price Candidate price (18 decimals)
     * @param timestamp Snapshot timestamp
     * @return outPrice The candidate price echoed back (0 if it fails freshness)
     * @return isValid True if the price can advance the baseline
     * @custom:security Enforces staleness, bounds and per-update deviation limits
     * @custom:validation Returns isValid=false on stale, zero, out-of-bounds or over-deviation input
     * @custom:state-changes None - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - signals via (price, false)
     * @custom:reentrancy Not protected - view function
     * @custom:access Internal
     * @custom:oracle Reads cached bounds/baseline only
     */
    function _validateEurUsd(uint256 price, uint256 timestamp)
        internal
        view
        returns (uint256 outPrice, bool isValid)
    {
        if (!_validateTimestamp(timestamp) || price == 0) {
            return (0, false);
        }

        outPrice = price;
        isValid = price >= minEurUsdPrice && price <= maxEurUsdPrice;

        if (isValid && lastValidEurUsdPrice > 0) {
            uint256 base = lastValidEurUsdPrice;
            uint256 diff = price > base ? price - base : base - price;
            uint256 deviationBps = _divRound(diff * BASIS_POINTS, base);
            if (deviationBps > MAX_PRICE_DEVIATION) {
                isValid = false;
            }
        }
    }

    /**
     * @notice Reads USDC/USD from the delegated source for event enrichment only
     * @dev try/catch so a failing USDC source never blocks an EUR/USD commit.
     * @return usdcUsdPrice USDC/USD price (18 decimals); $1.00 on any failure
     * @custom:security Isolates USDC-source failures from the EUR/USD path
     * @custom:validation Falls back to 1e18 when the source reverts or returns invalid
     * @custom:state-changes None - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - falls back to 1e18
     * @custom:reentrancy Not protected - external staticcall only
     * @custom:access Internal
     * @custom:oracle Reads usdcSource.getUsdcUsdPrice()
     */
    function _readUsdcForEvent() internal view returns (uint256 usdcUsdPrice) {
        usdcUsdPrice = 1e18;
        try usdcSource.getUsdcUsdPrice() returns (uint256 p, bool ok) {
            if (ok && p > 0) usdcUsdPrice = p;
        } catch {
            usdcUsdPrice = 1e18;
        }
    }

    /**
     * @notice Commits an accepted EUR/USD price as the new baseline
     * @param eurUsdPrice Accepted EUR/USD price (18 decimals)
     * @custom:security Reached only after validation; advances the deviation baseline
     * @custom:validation Assumes the caller validated the price
     * @custom:state-changes Sets lastValidEurUsdPrice, lastPriceUpdateTime, lastPriceUpdateBlock
     * @custom:events Emits PriceUpdated
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - one external staticcall for event enrichment
     * @custom:access Internal
     * @custom:oracle Reads usdcSource for the emitted event only
     */
    function _commitEurUsdPrice(uint256 eurUsdPrice) internal {
        lastValidEurUsdPrice = eurUsdPrice;
        lastPriceUpdateTime = TIME_PROVIDER.currentTime();
        lastPriceUpdateBlock = block.number;
        emit PriceUpdated(eurUsdPrice, _readUsdcForEvent(), TIME_PROVIDER.currentTime());
    }

    /**
     * @notice Best-effort initial/reset seed of the baseline from SlippageStorage
     * @dev Never reverts and never trips the breaker: if no fresh, in-bounds mid is published yet,
     *      the baseline is left as-is and the first successful read seeds it.
     * @custom:security Avoids bricking init/reset when no data has been published yet
     * @custom:validation Applies bounds (deviation is skipped while no baseline exists)
     * @custom:state-changes May set lastValidEurUsdPrice/time/block via _commitEurUsdPrice
     * @custom:events Emits PriceUpdated if a seed price is accepted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - external staticcall only
     * @custom:access Internal
     * @custom:oracle Reads SlippageStorage
     */
    function _seedInitialPrice() internal {
        try slippageStorage.getSlippageBySource(sourceId) returns (
            ISlippageStorage.SlippageSnapshot memory snap
        ) {
            uint256 price = uint256(snap.midPrice);
            uint256 ts = uint256(snap.timestamp);
            (uint256 vPrice, bool ok) = _validateEurUsd(price, ts);
            if (ok) {
                _commitEurUsdPrice(vPrice);
            }
        } catch {
            // No data available yet - leave baseline unset.
        }
    }

    // =============================================================================
    // IOracle READ FUNCTIONS
    // =============================================================================

    /**
     * @notice Retrieves the current EUR/USD price with full validation
     * @dev Reads the Hyperliquid mid from SlippageStorage; on circuit breaker, pause, staleness,
     *      out-of-bounds or over-deviation, returns the last valid price with isValid=false so the
     *      vault fails safe. A valid price advances the baseline.
     * @return price EUR/USD price in 18 decimals
     * @return isValid True if fresh and within bounds/deviation
     * @custom:security Validates freshness, bounds, deviation and breaker state
     * @custom:validation Returns isValid=false for any invalid condition
     * @custom:state-changes Updates baseline (lastValid*) when a valid price is accepted
     * @custom:events Emits PriceUpdated when the baseline advances
     * @custom:errors No errors thrown unless SlippageStorage itself reverts (fail-safe)
     * @custom:reentrancy Not protected - external staticcall only
     * @custom:access Public - no access restrictions
     * @custom:oracle Reads SlippageStorage mid; reads usdcSource for the event only
     */
    function getEurUsdPrice() external override returns (uint256 price, bool isValid) {
        if (circuitBreakerTriggered || paused()) {
            return (lastValidEurUsdPrice, false);
        }

        (uint256 mid, uint256 ts) = _readMid();
        if (!_validateTimestamp(ts) || mid == 0) {
            return (lastValidEurUsdPrice, false);
        }

        (price, isValid) = _validateEurUsd(mid, ts);
        if (!isValid) {
            return (lastValidEurUsdPrice, false);
        }

        _commitEurUsdPrice(price);
    }

    /**
     * @notice Retrieves the USDC/USD price with validation, delegated to the USDC source
     * @return price USDC/USD price in 18 decimals (≈ 1e18)
     * @return isValid True if USDC remains within the source's tolerance
     * @custom:security Delegates to the trusted USDC source; falls back to $1.00 on failure
     * @custom:validation Validation performed by usdcSource
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - falls back to (1e18, false) on revert
     * @custom:reentrancy Not protected - external staticcall only
     * @custom:access Public - no access restrictions
     * @custom:oracle Reads usdcSource.getUsdcUsdPrice()
     */
    function getUsdcUsdPrice() external view override returns (uint256 price, bool isValid) {
        try usdcSource.getUsdcUsdPrice() returns (uint256 p, bool ok) {
            return (p, ok);
        } catch {
            return (1e18, false);
        }
    }

    /**
     * @notice Returns overall oracle health signals
     * @return isHealthy True if both feeds are fresh, breaker is off and not paused
     * @return eurUsdFresh True if the Hyperliquid mid is fresh and positive
     * @return usdcUsdFresh True if the USDC source reports a valid price
     * @custom:security Health view for monitoring and watchdog decisions
     * @custom:validation Checks freshness, breaker and pause state
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - degraded sources report false
     * @custom:reentrancy Not protected - external staticcalls only
     * @custom:access Public - no access restrictions
     * @custom:oracle Reads SlippageStorage and usdcSource
     */
    function getOracleHealth()
        external
        view
        override
        returns (bool isHealthy, bool eurUsdFresh, bool usdcUsdFresh)
    {
        try slippageStorage.getSlippageBySource(sourceId) returns (
            ISlippageStorage.SlippageSnapshot memory snap
        ) {
            eurUsdFresh = _validateTimestamp(uint256(snap.timestamp)) && snap.midPrice > 0;
        } catch {
            eurUsdFresh = false;
        }

        try usdcSource.getUsdcUsdPrice() returns (uint256 p, bool ok) {
            usdcUsdFresh = ok && p > 0;
        } catch {
            usdcUsdFresh = false;
        }

        isHealthy = eurUsdFresh && usdcUsdFresh && !circuitBreakerTriggered && !paused();
    }

    /**
     * @notice Detailed information about the EUR/USD price
     * @return currentPrice Current price (may be the fallback)
     * @return lastValidPrice Last validated price stored
     * @return lastUpdate Snapshot timestamp reported by SlippageStorage
     * @return isStale True if the published mid is stale
     * @return withinBounds True if currentPrice is within configured bounds
     * @custom:security Detailed view for debugging and monitoring
     * @custom:validation Checks freshness, bounds and deviation
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - returns fallback on source revert
     * @custom:reentrancy Not protected - external staticcall only
     * @custom:access Public - no access restrictions
     * @custom:oracle Reads SlippageStorage
     */
    function getEurUsdDetails()
        external
        view
        override
        returns (
            uint256 currentPrice,
            uint256 lastValidPrice,
            uint256 lastUpdate,
            bool isStale,
            bool withinBounds
        )
    {
        try slippageStorage.getSlippageBySource(sourceId) returns (
            ISlippageStorage.SlippageSnapshot memory snap
        ) {
            uint256 price = uint256(snap.midPrice);
            lastUpdate = uint256(snap.timestamp);
            isStale = !_validateTimestamp(lastUpdate) || price == 0;

            if (circuitBreakerTriggered || paused() || isStale) {
                currentPrice = lastValidEurUsdPrice;
            } else {
                currentPrice = price;
                bool isValid = price >= minEurUsdPrice && price <= maxEurUsdPrice;
                if (isValid && lastValidEurUsdPrice > 0) {
                    uint256 base = lastValidEurUsdPrice;
                    uint256 diff = price > base ? price - base : base - price;
                    uint256 deviationBps = _divRound(diff * BASIS_POINTS, base);
                    if (deviationBps > MAX_PRICE_DEVIATION) {
                        isValid = false;
                    }
                }
                if (!isValid) {
                    currentPrice = lastValidEurUsdPrice;
                }
            }
        } catch {
            lastUpdate = 0;
            isStale = true;
            currentPrice = lastValidEurUsdPrice;
        }

        lastValidPrice = lastValidEurUsdPrice;
        withinBounds = currentPrice >= minEurUsdPrice && currentPrice <= maxEurUsdPrice;
    }

    /**
     * @notice Current configuration and circuit breaker state
     * @return minPrice Minimum accepted EUR/USD price
     * @return maxPrice Maximum accepted EUR/USD price
     * @return maxStaleness Maximum accepted staleness in seconds
     * @return usdcTolerance Reported USDC tolerance in basis points
     * @return circuitBreakerActive True if the circuit breaker is triggered
     * @custom:security Configuration view for monitoring
     * @custom:validation No validation - read-only
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle No oracle dependency
     */
    function getOracleConfig()
        external
        view
        override
        returns (
            uint256 minPrice,
            uint256 maxPrice,
            uint256 maxStaleness,
            uint256 usdcTolerance,
            bool circuitBreakerActive
        )
    {
        return (minEurUsdPrice, maxEurUsdPrice, maxPriceStaleness, usdcToleranceBps, circuitBreakerTriggered);
    }

    /**
     * @notice Addresses and decimals of the underlying sources
     * @return eurUsdFeedAddress EUR/USD source address (SlippageStorage)
     * @return usdcUsdFeedAddress USDC/USD source address (ChainlinkOracle)
     * @return eurUsdDecimals EUR/USD decimals (18)
     * @return usdcUsdDecimals USDC/USD decimals (18)
     * @custom:security Returns source addresses for verification
     * @custom:validation No validation - read-only
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle No oracle dependency
     */
    function getPriceFeedAddresses()
        external
        view
        override
        returns (
            address eurUsdFeedAddress,
            address usdcUsdFeedAddress,
            uint8 eurUsdDecimals,
            uint8 usdcUsdDecimals
        )
    {
        return (address(slippageStorage), address(usdcSource), MID_DECIMALS, MID_DECIMALS);
    }

    /**
     * @notice Connectivity check for both sources
     * @return eurUsdConnected True if SlippageStorage returns a fresh, positive mid
     * @return usdcUsdConnected True if the USDC source returns a valid price
     * @return eurUsdLatestRound Always 0 (not round-based)
     * @return usdcUsdLatestRound Always 0 (not round-based)
     * @custom:security Connectivity view for monitoring
     * @custom:validation No validation - connectivity test only
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - degraded sources report false
     * @custom:reentrancy Not protected - external staticcalls only
     * @custom:access Public - no access restrictions
     * @custom:oracle Reads SlippageStorage and usdcSource
     */
    function checkPriceFeedConnectivity()
        external
        view
        override
        returns (
            bool eurUsdConnected,
            bool usdcUsdConnected,
            uint80 eurUsdLatestRound,
            uint80 usdcUsdLatestRound
        )
    {
        try slippageStorage.getSlippageBySource(sourceId) returns (
            ISlippageStorage.SlippageSnapshot memory snap
        ) {
            eurUsdConnected = snap.midPrice > 0 && _validateTimestamp(uint256(snap.timestamp));
        } catch {
            eurUsdConnected = false;
        }
        eurUsdLatestRound = 0;

        try usdcSource.getUsdcUsdPrice() returns (uint256 p, bool ok) {
            usdcUsdConnected = ok && p > 0;
        } catch {
            usdcUsdConnected = false;
        }
        usdcUsdLatestRound = 0;
    }

    // =============================================================================
    // MANAGEMENT FUNCTIONS (delegated by the OracleRouter)
    // =============================================================================

    /**
     * @notice Updates EUR/USD min and max acceptable prices
     * @param _minPrice Minimum accepted EUR/USD price (18 decimals)
     * @param _maxPrice Maximum accepted EUR/USD price (18 decimals)
     * @custom:security Validates min < max and a sane upper bound
     * @custom:validation Validates _minPrice > 0, _maxPrice > _minPrice, _maxPrice <= 10e18
     * @custom:state-changes Updates minEurUsdPrice and maxEurUsdPrice
     * @custom:events Emits PriceBoundsUpdated
     * @custom:errors Reverts on invalid bounds
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:oracle No oracle dependency
     */
    function updatePriceBounds(uint256 _minPrice, uint256 _maxPrice)
        external
        override
        onlyRole(ORACLE_MANAGER_ROLE)
    {
        CommonValidationLibrary.validatePositiveAmount(_minPrice);
        CommonValidationLibrary.validateCondition(_maxPrice > _minPrice, "price");
        CommonValidationLibrary.validateMaxAmount(_maxPrice, 10e18);

        minEurUsdPrice = _minPrice;
        maxEurUsdPrice = _maxPrice;
        emit PriceBoundsUpdated("bounds", _minPrice, _maxPrice);
    }

    /**
     * @notice Updates the reported USDC tolerance (validation lives in the USDC source)
     * @param newToleranceBps New tolerance in basis points (e.g., 200 = 2%)
     * @custom:security Validates tolerance within 10%
     * @custom:validation Validates newToleranceBps <= 1000
     * @custom:state-changes Updates usdcToleranceBps
     * @custom:events No events emitted
     * @custom:errors Reverts if tolerance is out of bounds
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:oracle No oracle dependency
     */
    function updateUsdcTolerance(uint256 newToleranceBps)
        external
        override
        onlyRole(ORACLE_MANAGER_ROLE)
    {
        CommonValidationLibrary.validatePercentage(newToleranceBps, 1000);
        usdcToleranceBps = newToleranceBps;
    }

    /**
     * @notice Clears the circuit breaker and attempts to re-seed the baseline
     * @custom:security Re-enables live prices after manual intervention
     * @custom:validation None
     * @custom:state-changes Clears circuitBreakerTriggered and may re-seed the baseline
     * @custom:events Emits CircuitBreakerReset (and PriceUpdated if re-seeded)
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - external staticcall only
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle Reads SlippageStorage to re-seed
     */
    function resetCircuitBreaker() external override onlyRole(EMERGENCY_ROLE) {
        circuitBreakerTriggered = false;
        _seedInitialPrice();
        emit CircuitBreakerReset(msg.sender);
    }

    /**
     * @notice Manually triggers the circuit breaker (use last valid price)
     * @custom:security Forces fallback pricing during incidents
     * @custom:validation None
     * @custom:state-changes Sets circuitBreakerTriggered to true
     * @custom:events Emits CircuitBreakerTriggered
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle No oracle dependency
     */
    function triggerCircuitBreaker() external override onlyRole(EMERGENCY_ROLE) {
        circuitBreakerTriggered = true;
        emit CircuitBreakerTriggered(0, lastValidEurUsdPrice, "Manual trigger");
    }

    // =============================================================================
    // ADAPTER-SPECIFIC CONFIGURATION
    // =============================================================================

    /**
     * @notice Updates the maximum accepted staleness of the published mid
     * @param newMaxStaleness New staleness window in seconds (1..HARD_MAX_STALENESS)
     * @custom:security Bounds the staleness window to a safe maximum
     * @custom:validation Validates 0 < newMaxStaleness <= HARD_MAX_STALENESS
     * @custom:state-changes Updates maxPriceStaleness
     * @custom:events Emits MaxStalenessUpdated
     * @custom:errors Reverts if out of bounds
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:oracle No oracle dependency
     */
    function setMaxPriceStaleness(uint256 newMaxStaleness)
        external
        override
        onlyRole(ORACLE_MANAGER_ROLE)
    {
        CommonValidationLibrary.validatePositiveAmount(newMaxStaleness);
        CommonValidationLibrary.validateMaxAmount(newMaxStaleness, HARD_MAX_STALENESS);
        uint256 old = maxPriceStaleness;
        maxPriceStaleness = newMaxStaleness;
        emit MaxStalenessUpdated(old, newMaxStaleness);
    }

    /**
     * @notice Updates the SlippageStorage source contract and source id
     * @param _slippageStorage New SlippageStorage contract address
     * @param _sourceId New slippage source id (SOURCE_HYPERLIQUID = 1)
     * @custom:security Validates non-zero source address
     * @custom:validation Validates _slippageStorage != address(0)
     * @custom:state-changes Updates slippageStorage and sourceId
     * @custom:events Emits SlippageSourceUpdated
     * @custom:errors Reverts if source address is zero
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:oracle Updates the SlippageStorage reference
     */
    function updateSlippageSource(address _slippageStorage, uint8 _sourceId)
        external
        override
        onlyRole(ORACLE_MANAGER_ROLE)
    {
        CommonValidationLibrary.validateNonZeroAddress(_slippageStorage, "oracle");
        slippageStorage = ISlippageMidSource(_slippageStorage);
        sourceId = _sourceId;
        emit SlippageSourceUpdated(_slippageStorage, _sourceId);
    }

    /**
     * @notice Updates the USDC/USD source oracle
     * @param _usdcSource New USDC/USD source (ChainlinkOracle)
     * @custom:security Validates non-zero source address
     * @custom:validation Validates _usdcSource != address(0)
     * @custom:state-changes Updates usdcSource
     * @custom:events Emits UsdcSourceUpdated
     * @custom:errors Reverts if source address is zero
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:oracle Updates the USDC source reference
     */
    function updateUsdcSource(address _usdcSource)
        external
        override
        onlyRole(ORACLE_MANAGER_ROLE)
    {
        CommonValidationLibrary.validateNonZeroAddress(_usdcSource, "oracle");
        usdcSource = IOracle(_usdcSource);
        emit UsdcSourceUpdated(_usdcSource);
    }

    /**
     * @notice Updates the treasury address
     * @param _treasury New treasury address
     * @custom:security Validates non-zero treasury
     * @custom:validation Validates _treasury != address(0)
     * @custom:state-changes Updates treasury
     * @custom:events Emits TreasuryUpdated
     * @custom:errors Reverts if treasury is zero
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependency
     */
    function updateTreasury(address _treasury) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        CommonValidationLibrary.validateTreasuryAddress(_treasury);
        CommonValidationLibrary.validateNonZeroAddress(_treasury, "treasury");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    // =============================================================================
    // EMERGENCY FUNCTIONS
    // =============================================================================

    /**
     * @notice Pauses all oracle reads
     * @custom:security Emergency halt of price reads
     * @custom:validation None
     * @custom:state-changes Sets paused = true
     * @custom:events Emits Paused
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle Halts oracle price reads
     */
    function pause() external override onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses oracle reads
     * @custom:security Resumes normal operation
     * @custom:validation None
     * @custom:state-changes Sets paused = false
     * @custom:events Emits Unpaused
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle Resumes oracle price reads
     */
    function unpause() external override onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }

    /**
     * @notice Recovers ERC20 tokens accidentally sent to the contract, to treasury only
     * @param token Token address to recover
     * @param amount Amount to transfer
     * @custom:security Sends recovered tokens to treasury only
     * @custom:validation Validated by the recovery library
     * @custom:state-changes Transfers token balance to treasury
     * @custom:events Emits TokenRecovered via library
     * @custom:errors Reverts if token is zero or transfer fails
     * @custom:reentrancy Protected by library
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependency
     */
    function recoverToken(address token, uint256 amount) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        TreasuryRecoveryLibrary.recoverToken(token, amount, address(this), treasury);
    }

    /**
     * @notice Recovers ETH accidentally sent to the contract, to treasury only
     * @custom:security Sends recovered ETH to treasury only
     * @custom:validation Validates treasury is set and balance is non-zero
     * @custom:state-changes Transfers ETH balance to treasury
     * @custom:events Emits ETHRecovered
     * @custom:errors Reverts if treasury is zero or there is no ETH
     * @custom:reentrancy Uses sendValue to a trusted treasury
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependency
     */
    function recoverETH() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (treasury == address(0)) revert CommonErrorLibrary.InvalidAddress();
        uint256 balance = address(this).balance;
        if (balance < 1) revert CommonErrorLibrary.NoETHToRecover();
        emit ETHRecovered(treasury, balance);
        payable(treasury).sendValue(balance);
    }

    // =============================================================================
    // UPGRADE AUTHORIZATION
    // =============================================================================

    /**
     * @notice Authorizes contract upgrades
     * @param newImplementation Address of the new implementation
     * @custom:security Restricted to UPGRADER_ROLE
     * @custom:validation None beyond role check
     * @custom:state-changes None directly
     * @custom:events No events emitted
     * @custom:errors Reverts if caller lacks UPGRADER_ROLE
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to UPGRADER_ROLE
     * @custom:oracle No oracle dependency
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
