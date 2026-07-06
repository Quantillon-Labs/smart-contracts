// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {SlippageStorage} from "../src/oracle/SlippageStorage.sol";
import {HyperliquidEurUsdOracle} from "../src/oracle/HyperliquidEurUsdOracle.sol";
import {ISlippageStorage} from "../src/interfaces/ISlippageStorage.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";

import {MockUsdcOracle, HLGate} from "./HyperliquidEurUsdOracle.t.sol";

/**
 * @title OraclePriceWalkDefenseTest
 * @notice End-to-end adversarial tests for the EUR/USD pricing path that the vault mints and
 *         redeems against: the real SlippageStorage (write side) wired to the real
 *         HyperliquidEurUsdOracle (read side).
 *
 * @dev The unit suites for each contract validate the guards in isolation against mocks. This
 *      suite exercises the two guards *together* on the live wiring and configuration, modelling
 *      a WRITER key that has been compromised and is trying to walk the mid the vault prices
 *      against. It asserts the layered defense:
 *
 *        - write side (SlippageStorage): an absolute band plus a per-write deviation cap, applied
 *          on both the single-source path (reverts, writer-visible) and the batch path the live
 *          publisher actually uses (skips the offending source, no revert);
 *        - read side (HyperliquidEurUsdOracle): staleness, absolute bounds, a per-read deviation
 *          breaker and a last-valid-price fail-safe.
 *
 *      The properties proved here: a bad mid can never be pushed through to a live price (worst
 *      case the feed freezes onto the last good value and the vault gate reverts), and a sequence
 *      of individually-legal steps is still bounded by the tighter write-side band rather than the
 *      wider read-side bounds.
 *
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract OraclePriceWalkDefenseTest is Test {
    SlippageStorage public store;
    HyperliquidEurUsdOracle public oracle;
    TimeProvider public timeProvider;
    MockUsdcOracle public usdc;
    HLGate public gate;

    address internal admin    = makeAddr("admin");
    address internal writer   = makeAddr("writer");   // the (potentially compromised) publisher key
    address internal treasury = makeAddr("treasury");

    uint8 internal constant SOURCE_HYPERLIQUID = 1;
    uint128 internal constant DEPTH_EUR = 500_000e18;

    // Live-configuration guards.
    uint128 internal constant BAND_MIN = 0.95e18;
    uint128 internal constant BAND_MAX = 1.35e18;
    uint16  internal constant WRITE_DEV_BPS = 200; // 2% max per write

    uint128 internal constant SEED_MID = 1.08e18;

    function setUp() public {
        vm.warp(1_000_000);

        TimeProvider tpImpl = new TimeProvider();
        ERC1967Proxy tpProxy = new ERC1967Proxy(
            address(tpImpl),
            abi.encodeWithSelector(TimeProvider.initialize.selector, admin, admin, admin)
        );
        timeProvider = TimeProvider(payable(address(tpProxy)));

        // Real SlippageStorage: rate limit disabled (0 interval/threshold) so these tests isolate
        // the midPrice guards; both sources enabled (0x03).
        SlippageStorage ssImpl = new SlippageStorage(timeProvider);
        ERC1967Proxy ssProxy = new ERC1967Proxy(
            address(ssImpl),
            abi.encodeCall(SlippageStorage.initialize, (admin, writer, 0, 0, treasury, 3))
        );
        store = SlippageStorage(payable(address(ssProxy)));

        // Arm the write-side guards to the live configuration, then seed an in-band mid so the
        // oracle can take a baseline at construction.
        vm.prank(admin);
        store.setMidPriceGuards(BAND_MIN, BAND_MAX, WRITE_DEV_BPS);
        _publishHL(SEED_MID, 25);

        usdc = new MockUsdcOracle();

        HyperliquidEurUsdOracle oImpl = new HyperliquidEurUsdOracle(timeProvider);
        ERC1967Proxy oProxy = new ERC1967Proxy(
            address(oImpl),
            abi.encodeWithSelector(
                HyperliquidEurUsdOracle.initialize.selector,
                admin,
                address(store),
                SOURCE_HYPERLIQUID,
                address(usdc),
                treasury
            )
        );
        oracle = HyperliquidEurUsdOracle(payable(address(oProxy)));
        gate = new HLGate();
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    /// @notice Publish a Hyperliquid mid via the batch path (the live publisher's path).
    /// @dev Never reverts on a guard failure: the batch silently skips the offending source.
    function _publishHL(uint128 mid, uint16 worstBps) internal {
        ISlippageStorage.SourceUpdate[] memory u = new ISlippageStorage.SourceUpdate[](1);
        u[0] = ISlippageStorage.SourceUpdate({
            sourceId:     SOURCE_HYPERLIQUID,
            midPrice:     mid,
            depthEur:     DEPTH_EUR,
            worstCaseBps: worstBps,
            spreadBps:    3,
            bucketBps:    [uint16(1), uint16(2), uint16(3), uint16(4), uint16(5)]
        });
        vm.prank(writer);
        store.updateSlippageBatch(u);
    }

    /// @notice The mid currently stored for the Hyperliquid source (what the oracle reads).
    function _storedHLMid() internal view returns (uint128) {
        return store.getSlippageBySource(SOURCE_HYPERLIQUID).midPrice;
    }

    // =========================================================================
    // Write-side band: both edges, single (reverting) path
    // =========================================================================

    function test_writeBand_rejectsAboveAndBelow_singlePath() public {
        // updateSlippage writes the legacy (source 0) slot; the same guards apply. Seed in band.
        // worstCaseBps varies per write so the (separately tested) rate limiter never masks the
        // band guard we are exercising here.
        vm.warp(block.timestamp + 1);
        vm.prank(writer);
        store.updateSlippage(1.10e18, DEPTH_EUR, 25, 3, [uint16(1), 2, 3, 4, 5]);

        // Above the band ceiling: reject.
        vm.warp(block.timestamp + 1);
        vm.prank(writer);
        vm.expectRevert(CommonErrorLibrary.InvalidPrice.selector);
        store.updateSlippage(1.40e18, DEPTH_EUR, 125, 3, [uint16(1), 2, 3, 4, 5]);

        // Below the band floor: reject.
        vm.warp(block.timestamp + 1);
        vm.prank(writer);
        vm.expectRevert(CommonErrorLibrary.InvalidPrice.selector);
        store.updateSlippage(0.90e18, DEPTH_EUR, 200, 3, [uint16(1), 2, 3, 4, 5]);
    }

    function test_writeDeviation_capsStepButAllowsLegalStep_singlePath() public {
        vm.warp(block.timestamp + 1);
        vm.prank(writer);
        store.updateSlippage(1.10e18, DEPTH_EUR, 25, 3, [uint16(1), 2, 3, 4, 5]);

        // ~1.8% step (<= 2%) is accepted even though it moves the mid.
        vm.warp(block.timestamp + 1);
        vm.prank(writer);
        store.updateSlippage(1.12e18, DEPTH_EUR, 60, 3, [uint16(1), 2, 3, 4, 5]);
        assertEq(store.getSlippage().midPrice, 1.12e18, "legal <=2% step should be accepted");

        // ~3.6% step (> 2%) is rejected although 1.16 is still inside the absolute band.
        vm.warp(block.timestamp + 1);
        vm.prank(writer);
        vm.expectRevert(CommonErrorLibrary.InvalidPrice.selector);
        store.updateSlippage(1.16e18, DEPTH_EUR, 125, 3, [uint16(1), 2, 3, 4, 5]);
    }

    function test_setMidPriceGuards_rejectsDevBpsAbove100pct() public {
        // devBps is bounded at 10_000 (100%); above that reverts.
        vm.prank(admin);
        vm.expectRevert(CommonErrorLibrary.ConfigValueTooHigh.selector);
        store.setMidPriceGuards(BAND_MIN, BAND_MAX, 10001);
    }

    // =========================================================================
    // Batch path: guard skips the source (no revert), oracle keeps the last good price,
    // then a stale feed fails safe rather than accepting a bad mid.
    // =========================================================================

    function test_batchGuardSkip_keepsLastGoodMid_thenStaleFailsSafe() public {
        // Baseline: the seed is live and the oracle prices against it.
        (uint256 p0, bool v0) = oracle.getEurUsdPrice();
        assertTrue(v0, "seed should be a valid live price");
        assertEq(p0, SEED_MID, "oracle should price against the honest seed");

        // Compromised writer attempts an out-of-band jump via the batch path.
        vm.warp(block.timestamp + 1);
        _publishHL(1.60e18, 400);

        // The batch skipped the source: the stored mid is unchanged, no bad value landed.
        assertEq(_storedHLMid(), SEED_MID, "out-of-band batch write must be skipped, not stored");

        // The oracle still reads the last honest mid (fresh), so mint/redeem is unaffected.
        (uint256 p1, bool v1) = oracle.getEurUsdPrice();
        assertTrue(v1, "oracle stays valid on the last honest mid");
        assertEq(p1, SEED_MID, "attacker cannot move the priced value");

        // With no fresh honest write, the mid eventually goes stale. The oracle then fails safe:
        // it returns the last valid price with isValid=false, and the vault-mirroring gate reverts.
        vm.warp(block.timestamp + 901); // exceed the 900s staleness window
        (uint256 p2, bool v2) = oracle.getEurUsdPrice();
        assertFalse(v2, "stale feed must be invalid");
        assertEq(p2, SEED_MID, "stale read returns the last valid price as the fallback");

        vm.expectRevert(HLGate.InvalidOraclePrice.selector);
        gate.requireLivePrice(oracle);
    }

    function test_batchLegalStep_isAcceptedAndPriced() public {
        // A legal in-band <=2% step through the batch path is accepted and tracked by the oracle.
        vm.warp(block.timestamp + 1);
        uint128 step = uint128((uint256(SEED_MID) * 102) / 100); // +2%
        _publishHL(step, 30);
        assertEq(_storedHLMid(), step, "legal batch step should be stored");

        (uint256 p, bool v) = oracle.getEurUsdPrice();
        assertTrue(v, "legal step should price as valid");
        assertEq(p, step, "oracle should advance to the legal step");
        assertEq(oracle.lastValidEurUsdPrice(), step, "read-side baseline advances with the source");
    }

    // =========================================================================
    // The full walk: a sequence of individually-legal steps is bounded by the tighter
    // write-side band, not the wider read-side bounds.
    // =========================================================================

    function test_compromisedWriter_cannotWalkPastWriteSideBand() public {
        // Sanity: the read-side absolute bounds are wider than the write-side band, so if the walk
        // were only limited by the read side it could reach ~1.40.
        (uint256 minP, uint256 maxP,,,) = oracle.getOracleConfig();
        assertEq(minP, 0.80e18);
        assertEq(maxP, 1.40e18);
        assertLt(uint256(BAND_MAX), maxP, "write-side band must be tighter than read-side max");

        // The attacker repeatedly tries to ratchet the mid up by the maximum legal 2% per write,
        // aiming for the read-side ceiling (1.40). Each accepted step is also read through the
        // oracle so its baseline tracks.
        uint128 accepted = SEED_MID;
        for (uint256 i = 0; i < 40; i++) {
            vm.warp(block.timestamp + 1);
            uint256 target = (uint256(accepted) * 102) / 100; // +2%
            if (target > 1.40e18) target = 1.40e18;           // aim at the read-side ceiling
            _publishHL(uint128(target), uint16(30 + (i % 5)));

            uint128 nowStored = _storedHLMid();
            if (nowStored != accepted) {
                accepted = nowStored;
                (uint256 p, bool v) = oracle.getEurUsdPrice();
                assertTrue(v, "each 2% step is within the read-side breaker and must price valid");
                assertEq(p, accepted, "oracle tracks each accepted step");
            }
        }

        // The walk was capped by the write-side band, well short of the read-side 1.40 ceiling.
        assertLe(_storedHLMid(), BAND_MAX, "stored mid must never exceed the write-side band");
        assertLe(oracle.lastValidEurUsdPrice(), uint256(BAND_MAX), "priced value is capped by the band");
        assertGt(_storedHLMid(), uint128(1.30e18), "walk should have progressed to just below the band");

        // At the ceiling, any further legal-looking step that would cross the band is skipped.
        uint128 pinned = _storedHLMid();
        vm.warp(block.timestamp + 1);
        _publishHL(uint128((uint256(pinned) * 102) / 100), 40);
        assertEq(_storedHLMid(), pinned, "a step crossing the band ceiling must be skipped");
    }

    // =========================================================================
    // The read-side seed branch (no baseline yet) skips the deviation breaker, but the write-side
    // band still constrains what can be seeded.
    // =========================================================================

    function test_readSeedBranch_isStillBoundedByWriteSideBand() public {
        // Fresh oracle with no baseline yet, pointed at the same guarded store.
        HyperliquidEurUsdOracle freshImpl = new HyperliquidEurUsdOracle(timeProvider);
        // Empty the source first so initialize takes no seed.
        SlippageStorage emptyImpl = new SlippageStorage(timeProvider);
        ERC1967Proxy emptyProxy = new ERC1967Proxy(
            address(emptyImpl),
            abi.encodeCall(SlippageStorage.initialize, (admin, writer, 0, 0, treasury, 3))
        );
        SlippageStorage emptyStore = SlippageStorage(payable(address(emptyProxy)));
        vm.prank(admin);
        emptyStore.setMidPriceGuards(BAND_MIN, BAND_MAX, WRITE_DEV_BPS);

        ERC1967Proxy freshProxy = new ERC1967Proxy(
            address(freshImpl),
            abi.encodeWithSelector(
                HyperliquidEurUsdOracle.initialize.selector,
                admin,
                address(emptyStore),
                SOURCE_HYPERLIQUID,
                address(usdc),
                treasury
            )
        );
        HyperliquidEurUsdOracle fresh = HyperliquidEurUsdOracle(payable(address(freshProxy)));
        assertEq(fresh.lastValidEurUsdPrice(), 0, "no baseline should be seeded from an empty store");

        // The write-side band still gates the first published mid: an out-of-band seed is skipped,
        // so the oracle never takes an out-of-band baseline even though the read-side deviation
        // breaker is inactive while lastValid == 0.
        vm.startPrank(writer);
        ISlippageStorage.SourceUpdate[] memory u = new ISlippageStorage.SourceUpdate[](1);
        u[0] = ISlippageStorage.SourceUpdate({
            sourceId: SOURCE_HYPERLIQUID, midPrice: 1.60e18, depthEur: DEPTH_EUR,
            worstCaseBps: 30, spreadBps: 3, bucketBps: [uint16(1), 2, 3, 4, 5]
        });
        vm.warp(block.timestamp + 1);
        emptyStore.updateSlippageBatch(u);
        vm.stopPrank();
        assertEq(emptyStore.getSlippageBySource(SOURCE_HYPERLIQUID).midPrice, 0, "out-of-band seed skipped");

        // A first in-band mid seeds the baseline (deviation breaker skipped for the very first value)
        // but that value is band-constrained by construction.
        vm.warp(block.timestamp + 1);
        _publishTo(emptyStore, 1.20e18);
        (uint256 p, bool v) = fresh.getEurUsdPrice();
        assertTrue(v, "first in-band mid should seed a valid baseline");
        assertEq(p, 1.20e18);
        assertLe(fresh.lastValidEurUsdPrice(), uint256(BAND_MAX), "seeded baseline is within the band");
    }

    /// @notice Publish an in-band mid to an arbitrary store (used for the fresh-oracle seed case).
    function _publishTo(SlippageStorage s, uint128 mid) internal {
        ISlippageStorage.SourceUpdate[] memory u = new ISlippageStorage.SourceUpdate[](1);
        u[0] = ISlippageStorage.SourceUpdate({
            sourceId: SOURCE_HYPERLIQUID, midPrice: mid, depthEur: DEPTH_EUR,
            worstCaseBps: 30, spreadBps: 3, bucketBps: [uint16(1), 2, 3, 4, 5]
        });
        vm.prank(writer);
        s.updateSlippageBatch(u);
    }
}
