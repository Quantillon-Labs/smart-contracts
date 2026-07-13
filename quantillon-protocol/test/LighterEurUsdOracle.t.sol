// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {LighterEurUsdOracle} from "../src/oracle/LighterEurUsdOracle.sol";
import {ISlippageStorage} from "../src/interfaces/ISlippageStorage.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MockUSDC} from "./AaveIntegration.t.sol";
import {MockUsdcOracle} from "./HyperliquidEurUsdOracle.t.sol";

/// @notice Source-aware SlippageStorage double: snapshots are stored per sourceId, so a snapshot
///         written to one source (e.g. SOURCE_HYPERLIQUID = 1) is invisible to readers of another
///         (e.g. SOURCE_LIGHTER = 0), mirroring the real SlippageStorage behavior.
contract MockSourceSlippageStorage {
    mapping(uint8 => uint128) public mid;
    mapping(uint8 => uint48) public ts;
    bool public shouldRevert;

    function setMid(uint8 sourceId, uint128 _mid, uint48 _ts) external {
        mid[sourceId] = _mid;
        ts[sourceId] = _ts;
    }

    function setShouldRevert(bool r) external {
        shouldRevert = r;
    }

    function getSlippageBySource(uint8 sourceId) external view returns (ISlippageStorage.SlippageSnapshot memory snap) {
        if (shouldRevert) revert("slippage revert");
        snap.midPrice = mid[sourceId];
        snap.timestamp = ts[sourceId];
    }
}

/// @notice Consumer that reverts when the price is invalid, mirroring the vault's mint/redeem gate.
contract LighterGate {
    error InvalidOraclePrice();

    function requireLivePrice(LighterEurUsdOracle oracle) external returns (uint256) {
        (uint256 price, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) revert InvalidOraclePrice();
        return price;
    }
}

/**
 * @title LighterEurUsdOracleTest
 * @notice Test suite for the Lighter EUR/USD oracle adapter (SlippageStorage SOURCE_LIGHTER = 0).
 */
contract LighterEurUsdOracleTest is Test {
    LighterEurUsdOracle public oracle;
    LighterEurUsdOracle public implementation;
    TimeProvider public timeProvider;

    MockSourceSlippageStorage public slippage;
    MockUsdcOracle public usdc;
    LighterGate public gate;

    address public admin = address(0x1);
    address public treasury = address(0x2);
    address public stranger = address(0x3);

    uint8 internal constant SOURCE_LIGHTER = 0;
    uint8 internal constant SOURCE_HYPERLIQUID = 1;
    uint256 internal constant INITIAL_MID = 1.08e18;

    /// @notice Deploys TimeProvider, mocks and the oracle proxy with an initial fresh mid.
    function setUp() public {
        vm.warp(1_000_000);

        TimeProvider tpImpl = new TimeProvider();
        ERC1967Proxy tpProxy = new ERC1967Proxy(
            address(tpImpl),
            abi.encodeWithSelector(TimeProvider.initialize.selector, admin, admin, admin)
        );
        timeProvider = TimeProvider(payable(address(tpProxy)));

        slippage = new MockSourceSlippageStorage();
        slippage.setMid(SOURCE_LIGHTER, uint128(INITIAL_MID), uint48(block.timestamp));
        usdc = new MockUsdcOracle();

        implementation = new LighterEurUsdOracle(timeProvider);
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                LighterEurUsdOracle.initialize.selector,
                admin,
                address(slippage),
                SOURCE_LIGHTER,
                address(usdc),
                treasury
            )
        );
        oracle = LighterEurUsdOracle(payable(address(proxy)));
        gate = new LighterGate();
    }

    // ---- Initialization ----

    function test_Initialization() public view {
        assertTrue(oracle.hasRole(oracle.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(oracle.hasRole(oracle.ORACLE_MANAGER_ROLE(), admin));
        assertTrue(oracle.hasRole(oracle.EMERGENCY_ROLE(), admin));
        assertEq(address(oracle.slippageStorage()), address(slippage));
        assertEq(address(oracle.usdcSource()), address(usdc));
        assertEq(oracle.sourceId(), SOURCE_LIGHTER);
        assertEq(oracle.treasury(), treasury);
        assertEq(oracle.maxPriceStaleness(), 900);
        assertEq(oracle.minEurUsdPrice(), 0.80e18);
        assertEq(oracle.maxEurUsdPrice(), 1.40e18);
    }

    function test_SeedsBaselineOnInit() public view {
        // initialize() seeds from the fresh mid present at deploy time.
        assertEq(oracle.lastValidEurUsdPrice(), INITIAL_MID);
    }

    // ---- Happy path ----

    function test_GetEurUsdPrice_ReturnsPublishedMid() public {
        (uint256 price, bool isValid) = oracle.getEurUsdPrice();
        assertEq(price, INITIAL_MID);
        assertTrue(isValid);
    }

    function test_GetEurUsdPrice_TracksMidMoves() public {
        // A small in-bounds, within-deviation move is accepted and advances the baseline.
        uint128 newMid = 1.10e18;
        slippage.setMid(SOURCE_LIGHTER, newMid, uint48(block.timestamp));
        (uint256 price, bool isValid) = oracle.getEurUsdPrice();
        assertEq(price, newMid);
        assertTrue(isValid);
        assertEq(oracle.lastValidEurUsdPrice(), newMid);
    }

    // ---- Source separation ----

    /// @notice A snapshot written only to SOURCE_HYPERLIQUID (1) must NOT be read by the Lighter
    ///         adapter (sourceId 0): the read stays on the SOURCE_LIGHTER snapshot.
    function test_SourceSeparation_HyperliquidSnapshotNotRead() public {
        // Fresh Hyperliquid-only snapshot at a different price.
        slippage.setMid(SOURCE_HYPERLIQUID, uint128(1.12e18), uint48(block.timestamp));

        (uint256 price, bool isValid) = oracle.getEurUsdPrice();
        assertTrue(isValid, "Lighter snapshot still fresh and valid");
        assertEq(price, INITIAL_MID, "read must come from SOURCE_LIGHTER, not SOURCE_HYPERLIQUID");
        assertEq(oracle.lastValidEurUsdPrice(), INITIAL_MID, "baseline untouched by the other source");
    }

    /// @notice With no SOURCE_LIGHTER snapshot at all, a Hyperliquid-only publish leaves the
    ///         Lighter adapter unseeded and invalid; the first SOURCE_LIGHTER publish then seeds it.
    function test_SourceSeparation_HyperliquidOnlyStorage_NoSeed() public {
        MockSourceSlippageStorage hlOnly = new MockSourceSlippageStorage();
        hlOnly.setMid(SOURCE_HYPERLIQUID, uint128(1.12e18), uint48(block.timestamp));

        LighterEurUsdOracle fresh;
        {
            ERC1967Proxy proxy = new ERC1967Proxy(
                address(new LighterEurUsdOracle(timeProvider)),
                abi.encodeWithSelector(
                    LighterEurUsdOracle.initialize.selector,
                    admin,
                    address(hlOnly),
                    SOURCE_LIGHTER,
                    address(usdc),
                    treasury
                )
            );
            fresh = LighterEurUsdOracle(payable(address(proxy)));
        }

        assertEq(fresh.lastValidEurUsdPrice(), 0, "Hyperliquid-only snapshot must not seed source 0");
        (, bool isValid) = fresh.getEurUsdPrice();
        assertFalse(isValid, "no SOURCE_LIGHTER snapshot -> invalid read");

        // First SOURCE_LIGHTER publish is read and seeds the baseline.
        hlOnly.setMid(SOURCE_LIGHTER, uint128(INITIAL_MID), uint48(block.timestamp));
        (uint256 price, bool nowValid) = fresh.getEurUsdPrice();
        assertTrue(nowValid, "SOURCE_LIGHTER publish accepted");
        assertEq(price, INITIAL_MID);
        assertEq(fresh.lastValidEurUsdPrice(), INITIAL_MID);
    }

    // ---- Staleness ----

    function test_StalePrice_ReturnsFallbackInvalid() public {
        vm.warp(block.timestamp + 901); // exceed maxPriceStaleness (900)
        (uint256 price, bool isValid) = oracle.getEurUsdPrice();
        assertFalse(isValid);
        assertEq(price, INITIAL_MID); // last valid baseline
    }

    function test_StalePrice_GateReverts() public {
        vm.warp(block.timestamp + 901);
        vm.expectRevert(LighterGate.InvalidOraclePrice.selector);
        gate.requireLivePrice(oracle);
    }

    function test_FreshAgainAfterRepublish() public {
        vm.warp(block.timestamp + 901);
        (, bool stale) = oracle.getEurUsdPrice();
        assertFalse(stale);
        // Publisher writes a fresh snapshot.
        slippage.setMid(SOURCE_LIGHTER, uint128(INITIAL_MID), uint48(block.timestamp));
        (uint256 price, bool isValid) = oracle.getEurUsdPrice();
        assertTrue(isValid);
        assertEq(price, INITIAL_MID);
    }

    // ---- Bounds & deviation ----

    function test_OutOfBounds_ReturnsFallbackInvalid() public {
        slippage.setMid(SOURCE_LIGHTER, uint128(1.50e18), uint48(block.timestamp)); // > maxEurUsdPrice
        (uint256 price, bool isValid) = oracle.getEurUsdPrice();
        assertFalse(isValid);
        assertEq(price, INITIAL_MID);
    }

    function test_ExcessiveDeviation_ReturnsFallbackInvalid() public {
        // 1.08 -> 1.20 is in-bounds but > 5% deviation.
        slippage.setMid(SOURCE_LIGHTER, uint128(1.20e18), uint48(block.timestamp));
        (uint256 price, bool isValid) = oracle.getEurUsdPrice();
        assertFalse(isValid);
        assertEq(price, INITIAL_MID);
    }

    // ---- Circuit breaker ----

    function test_CircuitBreaker_TriggerAndReset() public {
        vm.prank(admin);
        oracle.triggerCircuitBreaker();
        (uint256 p1, bool v1) = oracle.getEurUsdPrice();
        assertFalse(v1);
        assertEq(p1, INITIAL_MID);

        slippage.setMid(SOURCE_LIGHTER, uint128(1.10e18), uint48(block.timestamp));
        vm.prank(admin);
        oracle.resetCircuitBreaker();
        // reset re-seeds from the fresh mid
        assertEq(oracle.lastValidEurUsdPrice(), 1.10e18);
        (uint256 p2, bool v2) = oracle.getEurUsdPrice();
        assertTrue(v2);
        assertEq(p2, 1.10e18);
    }

    // ---- Pause ----

    function test_Pause_BlocksReads() public {
        vm.prank(admin);
        oracle.pause();
        (uint256 price, bool isValid) = oracle.getEurUsdPrice();
        assertFalse(isValid);
        assertEq(price, INITIAL_MID);

        vm.prank(admin);
        oracle.unpause();
        (, bool v2) = oracle.getEurUsdPrice();
        assertTrue(v2);
    }

    // ---- USDC delegation ----

    function test_UsdcDelegation_PassesThrough() public {
        usdc.setUsdc(1.001e18, true);
        (uint256 price, bool isValid) = oracle.getUsdcUsdPrice();
        assertEq(price, 1.001e18);
        assertTrue(isValid);
    }

    function test_UsdcDelegation_FailSafeOnRevert() public {
        usdc.setShouldRevert(true);
        (uint256 price, bool isValid) = oracle.getUsdcUsdPrice();
        assertEq(price, 1e18);
        assertFalse(isValid);
    }

    // ---- Details / health / config ----

    function test_GetEurUsdDetails_FreshAndStale() public {
        (uint256 cur,, uint256 lastUpdate, bool isStale, bool withinBounds) = oracle.getEurUsdDetails();
        assertEq(cur, INITIAL_MID);
        assertFalse(isStale);
        assertTrue(withinBounds);
        assertEq(lastUpdate, block.timestamp);

        vm.warp(block.timestamp + 901);
        (uint256 cur2,,, bool isStale2,) = oracle.getEurUsdDetails();
        assertTrue(isStale2);
        assertEq(cur2, INITIAL_MID); // fallback to last valid
    }

    function test_GetOracleHealth() public {
        (bool healthy, bool eurFresh, bool usdcFresh) = oracle.getOracleHealth();
        assertTrue(healthy);
        assertTrue(eurFresh);
        assertTrue(usdcFresh);

        usdc.setUsdc(1e18, false);
        (bool healthy2,, bool usdcFresh2) = oracle.getOracleHealth();
        assertFalse(usdcFresh2);
        assertFalse(healthy2);
    }

    function test_GetOracleConfig() public view {
        (uint256 minP, uint256 maxP, uint256 staleness, uint256 tol, bool cb) = oracle.getOracleConfig();
        assertEq(minP, 0.80e18);
        assertEq(maxP, 1.40e18);
        assertEq(staleness, 900);
        assertEq(tol, 200);
        assertFalse(cb);
    }

    function test_GetPriceFeedAddresses() public view {
        (address eurFeed, address usdcFeed, uint8 d1, uint8 d2) = oracle.getPriceFeedAddresses();
        assertEq(eurFeed, address(slippage));
        assertEq(usdcFeed, address(usdc));
        assertEq(d1, 18);
        assertEq(d2, 18);
    }

    // ---- Source failure is fail-safe ----

    function test_SlippageRevert_HealthAndDetailsDegradeGracefully() public {
        slippage.setShouldRevert(true);
        (bool healthy, bool eurFresh,) = oracle.getOracleHealth();
        assertFalse(eurFresh);
        assertFalse(healthy);
        (uint256 cur,,, bool isStale,) = oracle.getEurUsdDetails();
        assertTrue(isStale);
        assertEq(cur, INITIAL_MID);
    }

    function test_SlippageRevert_GetEurUsdPriceBubbles() public {
        slippage.setShouldRevert(true);
        vm.expectRevert();
        oracle.getEurUsdPrice();
    }

    // ---- Configuration setters ----

    function test_SetMaxPriceStaleness() public {
        vm.prank(admin);
        oracle.setMaxPriceStaleness(300);
        assertEq(oracle.maxPriceStaleness(), 300);

        vm.warp(block.timestamp + 301);
        (, bool isValid) = oracle.getEurUsdPrice();
        assertFalse(isValid);
    }

    function test_SetMaxPriceStaleness_BoundsEnforced() public {
        vm.prank(admin);
        vm.expectRevert();
        oracle.setMaxPriceStaleness(0);

        vm.prank(admin);
        vm.expectRevert();
        oracle.setMaxPriceStaleness(3601); // > HARD_MAX_STALENESS
    }

    function test_UpdateSlippageSource() public {
        MockSourceSlippageStorage s2 = new MockSourceSlippageStorage();
        s2.setMid(SOURCE_LIGHTER, uint128(1.09e18), uint48(block.timestamp));
        vm.prank(admin);
        oracle.updateSlippageSource(address(s2), SOURCE_LIGHTER);
        assertEq(address(oracle.slippageStorage()), address(s2));
        (uint256 price, bool isValid) = oracle.getEurUsdPrice();
        assertTrue(isValid);
        assertEq(price, 1.09e18);
    }

    function test_UpdatePriceBounds() public {
        vm.prank(admin);
        oracle.updatePriceBounds(0.5e18, 2e18);
        assertEq(oracle.minEurUsdPrice(), 0.5e18);
        assertEq(oracle.maxEurUsdPrice(), 2e18);
    }

    function test_UpdateUsdcSource() public {
        MockUsdcOracle u2 = new MockUsdcOracle();
        u2.setUsdc(0.999e18, true);
        vm.prank(admin);
        oracle.updateUsdcSource(address(u2));
        (uint256 price, bool isValid) = oracle.getUsdcUsdPrice();
        assertTrue(isValid);
        assertEq(price, 0.999e18);
    }

    function test_UpdateTreasury() public {
        address newTreasury = address(0x9);
        vm.prank(admin);
        oracle.updateTreasury(newTreasury);
        assertEq(oracle.treasury(), newTreasury);
    }

    function test_UpdateTreasury_RevertsOnZero() public {
        vm.prank(admin);
        vm.expectRevert();
        oracle.updateTreasury(address(0));
    }

    function test_UpdateTreasury_OnlyAdmin() public {
        vm.prank(stranger);
        vm.expectRevert();
        oracle.updateTreasury(address(0x9));
    }

    // ---- Access control ----

    function test_AccessControl_OnlyManager() public {
        vm.prank(stranger);
        vm.expectRevert();
        oracle.updatePriceBounds(0.5e18, 2e18);

        vm.prank(stranger);
        vm.expectRevert();
        oracle.setMaxPriceStaleness(300);

        vm.prank(stranger);
        vm.expectRevert();
        oracle.updateSlippageSource(address(slippage), SOURCE_LIGHTER);
    }

    function test_AccessControl_OnlyEmergency() public {
        vm.prank(stranger);
        vm.expectRevert();
        oracle.triggerCircuitBreaker();

        vm.prank(stranger);
        vm.expectRevert();
        oracle.pause();
    }

    // ---- Edge cases ----

    /// @notice A snapshot timestamp in the future must be rejected, not treated as ultra-fresh.
    function test_FutureTimestamp_ReturnsFallbackInvalid() public {
        slippage.setMid(SOURCE_LIGHTER, uint128(INITIAL_MID), uint48(block.timestamp + 3600));
        (, bool isValid) = oracle.getEurUsdPrice();
        assertFalse(isValid, "future-dated snapshot must be invalid");
    }

    /// @notice Initializing against an empty SlippageStorage (mid == 0) must not seed a baseline;
    ///         reads stay invalid until the first valid publish, which then seeds it.
    function test_InitAgainstEmptyStorage_NoSeedThenRecovers() public {
        MockSourceSlippageStorage emptySlippage = new MockSourceSlippageStorage();
        LighterEurUsdOracle fresh;
        {
            ERC1967Proxy proxy = new ERC1967Proxy(
                address(new LighterEurUsdOracle(timeProvider)),
                abi.encodeWithSelector(
                    LighterEurUsdOracle.initialize.selector,
                    admin,
                    address(emptySlippage),
                    SOURCE_LIGHTER,
                    address(usdc),
                    treasury
                )
            );
            fresh = LighterEurUsdOracle(payable(address(proxy)));
        }

        assertEq(fresh.lastValidEurUsdPrice(), 0, "no baseline from empty storage");
        (, bool isValid) = fresh.getEurUsdPrice();
        assertFalse(isValid, "empty storage reads invalid");

        // First publish: no baseline yet, so no deviation gate — price becomes valid and seeds it.
        emptySlippage.setMid(SOURCE_LIGHTER, uint128(INITIAL_MID), uint48(block.timestamp));
        (uint256 price, bool nowValid) = fresh.getEurUsdPrice();
        assertTrue(nowValid, "first valid publish accepted");
        assertEq(price, INITIAL_MID);
        assertEq(fresh.lastValidEurUsdPrice(), INITIAL_MID, "baseline seeded by first valid read");
    }

    /// @notice Re-pointing the slippage source keeps the deviation baseline: a wildly different
    ///         mid from the new source is rejected instead of being trusted blindly.
    function test_UpdateSlippageSource_KeepsDeviationBaseline() public {
        // Commit the current baseline.
        (, bool isValid) = oracle.getEurUsdPrice();
        assertTrue(isValid);

        MockSourceSlippageStorage newSource = new MockSourceSlippageStorage();
        newSource.setMid(7, uint128(1.30e18), uint48(block.timestamp)); // in bounds, +20% vs baseline

        vm.prank(admin);
        oracle.updateSlippageSource(address(newSource), 7);

        (, bool validAfterSwitch) = oracle.getEurUsdPrice();
        assertFalse(validAfterSwitch, "20% jump from re-pointed source must trip the deviation gate");
    }

    /// @notice updateSlippageSource rejects the zero address.
    function test_UpdateSlippageSource_RevertsOnZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert();
        oracle.updateSlippageSource(address(0), SOURCE_LIGHTER);
    }

    // ---- Fuzz ----

    /// @notice Any in-bounds mid within the 5% deviation window of the baseline is accepted
    ///         and returned verbatim; it then becomes the new baseline.
    function testFuzz_GetEurUsdPrice_AcceptsWithinDeviation(uint256 mid) public {
        // 5% window around the 1.08 baseline, clamped inside the [0.80, 1.40] bounds.
        mid = bound(mid, (INITIAL_MID * 9501) / 10000, (INITIAL_MID * 10499) / 10000);
        slippage.setMid(SOURCE_LIGHTER, uint128(mid), uint48(block.timestamp));

        (uint256 price, bool isValid) = oracle.getEurUsdPrice();
        assertTrue(isValid, "in-window mid accepted");
        assertEq(price, mid, "mid returned verbatim");
        assertEq(oracle.lastValidEurUsdPrice(), mid, "accepted mid becomes the baseline");
    }

    /// @notice Any mid outside the [minEurUsdPrice, maxEurUsdPrice] bounds is rejected,
    ///         regardless of freshness.
    function testFuzz_GetEurUsdPrice_RejectsOutOfBounds(uint256 mid) public {
        // Split the fuzz domain: below min or above max (uint128 to fit the storage slot).
        if (mid % 2 == 0) {
            mid = bound(mid, 1, oracle.minEurUsdPrice() - 1);
        } else {
            mid = bound(mid, oracle.maxEurUsdPrice() + 1, type(uint128).max);
        }
        slippage.setMid(SOURCE_LIGHTER, uint128(mid), uint48(block.timestamp));

        (, bool isValid) = oracle.getEurUsdPrice();
        assertFalse(isValid, "out-of-bounds mid rejected");
        assertEq(oracle.lastValidEurUsdPrice(), INITIAL_MID, "baseline untouched by rejected read");
    }

    /// @notice Any staleness beyond maxPriceStaleness invalidates the read; anything within keeps it valid.
    function testFuzz_Staleness_Boundary(uint256 age) public {
        uint256 maxStaleness = oracle.maxPriceStaleness();
        age = bound(age, 0, 7 days);
        uint48 publishedAt = uint48(block.timestamp);
        slippage.setMid(SOURCE_LIGHTER, uint128(INITIAL_MID), publishedAt);
        vm.warp(block.timestamp + age);

        (, bool isValid) = oracle.getEurUsdPrice();
        if (age <= maxStaleness) {
            assertTrue(isValid, "within staleness window");
        } else {
            assertFalse(isValid, "beyond staleness window");
        }
    }

    /// @notice updatePriceBounds accepts any strictly ordered pair under the 10e18 cap and
    ///         applies it to validation immediately.
    function testFuzz_UpdatePriceBounds_Applied(uint256 minP, uint256 maxP) public {
        minP = bound(minP, 1, 5e18);
        maxP = bound(maxP, minP + 1, 10e18);

        vm.prank(admin);
        oracle.updatePriceBounds(minP, maxP);

        assertEq(oracle.minEurUsdPrice(), minP);
        assertEq(oracle.maxEurUsdPrice(), maxP);
    }

    // -- setters + recover (coverage) --
    function test_updateUsdcTolerance_success() public {
        vm.prank(admin);
        oracle.updateUsdcTolerance(150);
        assertEq(oracle.usdcToleranceBps(), 150);
    }

    function test_updateTreasury_successAndZero() public {
        address newT = address(0x7EA);
        vm.prank(admin);
        oracle.updateTreasury(newT);
        assertEq(oracle.treasury(), newT);
        vm.prank(admin);
        vm.expectRevert();
        oracle.updateTreasury(address(0));
    }

    function test_recoverETH_noEth_reverts() public {
        vm.prank(admin);
        vm.expectRevert();
        oracle.recoverETH();
    }

    // -- additional branch coverage --

    function test_version_returnsSemver() public view {
        assertEq(oracle.version(), "1.0.0");
    }

    /// @notice A reverting USDC source does not block the EUR/USD commit: the event read
    ///         falls back to $1.00 and the price is still valid.
    function test_getEurUsdPrice_usdcEventFallbackOnRevert() public {
        slippage.setMid(SOURCE_LIGHTER, uint128(INITIAL_MID), uint48(block.timestamp));
        usdc.setShouldRevert(true);
        (uint256 price, bool isValid) = oracle.getEurUsdPrice();
        assertTrue(isValid, "EUR/USD read unaffected by USDC-source revert");
        assertEq(price, INITIAL_MID);
    }

    /// @notice getOracleHealth reports usdcUsdFresh=false when the USDC source reverts.
    function test_getOracleHealth_usdcRevert_notFresh() public {
        usdc.setShouldRevert(true);
        (bool healthy, bool eurFresh, bool usdcFresh) = oracle.getOracleHealth();
        assertFalse(usdcFresh, "USDC source revert -> not fresh");
        assertFalse(healthy, "overall health degraded");
        assertTrue(eurFresh, "EUR mid still fresh");
    }

    /// @notice checkPriceFeedConnectivity: connected on a healthy read, both false when both sources revert.
    function test_checkPriceFeedConnectivity_successAndCatch() public {
        slippage.setMid(SOURCE_LIGHTER, uint128(INITIAL_MID), uint48(block.timestamp));
        (bool eurC, bool usdcC,,) = oracle.checkPriceFeedConnectivity();
        assertTrue(eurC, "EUR connected on healthy mid");
        assertTrue(usdcC, "USDC connected");

        slippage.setShouldRevert(true);
        usdc.setShouldRevert(true);
        (bool eurC2, bool usdcC2,,) = oracle.checkPriceFeedConnectivity();
        assertFalse(eurC2, "EUR disconnected on source revert");
        assertFalse(usdcC2, "USDC disconnected on source revert");
    }

    /// @notice resetCircuitBreaker clears the breaker and re-seeds the baseline from the current mid.
    function test_resetCircuitBreaker_reseedsBaseline() public {
        vm.prank(admin);
        oracle.triggerCircuitBreaker();
        assertTrue(oracle.circuitBreakerTriggered());

        slippage.setMid(SOURCE_LIGHTER, uint128(INITIAL_MID), uint48(block.timestamp));
        vm.prank(admin);
        oracle.resetCircuitBreaker();
        assertFalse(oracle.circuitBreakerTriggered());
        assertEq(oracle.lastValidEurUsdPrice(), INITIAL_MID);
    }

    function test_pauseThenUnpause() public {
        vm.prank(admin);
        oracle.pause();
        assertTrue(oracle.paused());
        vm.prank(admin);
        oracle.unpause();
        assertFalse(oracle.paused());
    }

    function test_recoverETH_success() public {
        vm.deal(address(oracle), 1 ether);
        uint256 before = treasury.balance;
        vm.prank(admin);
        oracle.recoverETH();
        assertEq(treasury.balance, before + 1 ether);
    }

    function test_recoverToken_toTreasury() public {
        MockUSDC tok = new MockUSDC();
        tok.mint(address(oracle), 1_000e6);
        vm.prank(admin);
        oracle.recoverToken(address(tok), 1_000e6);
        assertEq(tok.balanceOf(treasury), 1_000e6);
    }

    function test_authorizeUpgrade_viaUpgrade() public {
        LighterEurUsdOracle newImpl = new LighterEurUsdOracle(timeProvider);
        vm.prank(admin);
        oracle.upgradeToAndCall(address(newImpl), "");
        assertEq(oracle.version(), "1.0.0");
    }

}
