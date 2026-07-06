// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {YieldShiftOptimizationLibrary as L} from "../src/libraries/YieldShiftOptimizationLibrary.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";

/// @notice Minimal UserPool double exposing getTotalDeposits (revert-toggle for the catch branch).
contract MockUP {
    uint256 public d;
    bool public rv;
    function set(uint256 _d, bool _rv) external { d = _d; rv = _rv; }
    function getTotalDeposits() external view returns (uint256) { if (rv) revert("up"); return d; }
}

/// @notice Minimal HedgerPool double exposing totalExposure.
contract MockHP {
    uint256 public e;
    bool public rv;
    function set(uint256 _e, bool _rv) external { e = _e; rv = _rv; }
    function totalExposure() external view returns (uint256) { if (rv) revert("hp"); return e; }
}

/**
 * @title YieldShiftOptimizationLibraryTest
 * @notice Unit coverage for the pure/view pool-metrics, history, allocation and stats helpers.
 */
contract YieldShiftOptimizationLibraryTest is Test {
    MockUP internal up;
    MockHP internal hp;

    function setUp() public {
        up = new MockUP();
        hp = new MockHP();
    }

    // ---- version ----
    function test_version() public pure {
        assertEq(L.version(), "1.0.0");
    }

    // ---- getCurrentPoolMetrics ----
    function test_getCurrentPoolMetrics_success_andRatio() public {
        up.set(1_000, false);
        hp.set(500, false);
        (uint256 u, uint256 h, uint256 r) = L.getCurrentPoolMetrics(address(up), address(hp));
        assertEq(u, 1_000);
        assertEq(h, 500);
        assertEq(r, 1_000 * 10000 / 500); // 20000
    }

    function test_getCurrentPoolMetrics_zeroHedgerExposure_ratioMax() public {
        up.set(1_000, false);
        hp.set(0, false);
        (, , uint256 r) = L.getCurrentPoolMetrics(address(up), address(hp));
        assertEq(r, type(uint256).max);
    }

    function test_getCurrentPoolMetrics_zeroAddress_reverts() public {
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        L.getCurrentPoolMetrics(address(0), address(hp));
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        L.getCurrentPoolMetrics(address(up), address(0));
    }

    function test_getCurrentPoolMetrics_userPoolReverts_yieldError() public {
        up.set(0, true);
        hp.set(500, false);
        vm.expectRevert(CommonErrorLibrary.YieldCalculationError.selector);
        L.getCurrentPoolMetrics(address(up), address(hp));
    }

    function test_getCurrentPoolMetrics_hedgerPoolReverts_yieldError() public {
        up.set(1_000, false);
        hp.set(0, true);
        vm.expectRevert(CommonErrorLibrary.YieldCalculationError.selector);
        L.getCurrentPoolMetrics(address(up), address(hp));
    }

    // ---- getEligiblePoolMetrics ----
    function test_getEligiblePoolMetrics_recentAndStableDiscount() public {
        up.set(10_000, false);
        hp.set(4_000, false);
        // Recent activity: currentTime - lastUpdate < MIN_HOLDING_PERIOD (7 days).
        (uint256 u1, uint256 h1, uint256 r1) = L.getEligiblePoolMetrics(address(up), address(hp), 1_000_000, 1_000_000 - 1 days);
        assertGt(u1, 0);
        assertLe(u1, 10_000); // eligible never exceeds total
        assertLe(h1, 4_000);
        assertGt(r1, 0);
        // Stable period: elapsed >= MIN_HOLDING_PERIOD -> base 80% discount.
        (uint256 u2,,) = L.getEligiblePoolMetrics(address(up), address(hp), 5_000_000, 5_000_000 - 30 days);
        assertEq(u2, 10_000 * 8000 / 10000); // 8000
    }

    function test_getEligiblePoolMetrics_zeroHedger_ratioMax() public {
        up.set(10_000, false);
        hp.set(0, false);
        (, , uint256 r) = L.getEligiblePoolMetrics(address(up), address(hp), 5_000_000, 5_000_000 - 30 days);
        assertEq(r, type(uint256).max);
    }

    function test_getEligiblePoolMetrics_zeroAddress_reverts() public {
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        L.getEligiblePoolMetrics(address(0), address(hp), 1, 0);
    }

    function test_getEligiblePoolMetrics_poolReverts_yieldError() public {
        up.set(0, true);
        hp.set(1, false);
        vm.expectRevert(CommonErrorLibrary.YieldCalculationError.selector);
        L.getEligiblePoolMetrics(address(up), address(hp), 1_000_000, 999_000);
    }

    // ---- getTimeWeightedAverage ----
    function _snap(uint64 ts, uint128 u, uint128 h) internal pure returns (L.PoolSnapshot memory s) {
        s = L.PoolSnapshot({timestamp: ts, userPoolSize: u, hedgerPoolSize: h});
    }

    function test_twap_emptyHistory_returnsZero() public pure {
        L.PoolSnapshot[] memory hist = new L.PoolSnapshot[](0);
        assertEq(L.getTimeWeightedAverage(hist, 24 hours, true, 1_000_000), 0);
    }

    function test_twap_inWindow_weightedAverage() public pure {
        L.PoolSnapshot[] memory hist = new L.PoolSnapshot[](2);
        hist[0] = _snap(950_000, 1_000, 500);
        hist[1] = _snap(990_000, 2_000, 800);
        uint256 avgUser = L.getTimeWeightedAverage(hist, 24 hours, true, 1_000_000);
        assertGe(avgUser, 1_000);
        assertLe(avgUser, 2_000);
        uint256 avgHedger = L.getTimeWeightedAverage(hist, 24 hours, false, 1_000_000);
        assertGe(avgHedger, 500);
        assertLe(avgHedger, 800);
    }

    function test_twap_allStale_fallsBackToLast() public pure {
        // Both snapshots older than cutoff (currentTime - period) -> totalWeight 0 -> last snapshot.
        L.PoolSnapshot[] memory hist = new L.PoolSnapshot[](2);
        hist[0] = _snap(800_000, 111, 11);
        hist[1] = _snap(900_000, 222, 22);
        assertEq(L.getTimeWeightedAverage(hist, 24 hours, true, 1_000_000), 222);
        assertEq(L.getTimeWeightedAverage(hist, 24 hours, false, 1_000_000), 22);
    }

    // ---- addToPoolHistory ----
    function test_addToPoolHistory_growsWhenBelowMax() public pure {
        L.PoolSnapshot[] memory hist = new L.PoolSnapshot[](2);
        hist[0] = _snap(1, 10, 0);
        hist[1] = _snap(2, 20, 0);
        L.PoolSnapshot[] memory out = L.addToPoolHistory(hist, 30, true, 3);
        assertEq(out.length, 3);
        assertEq(out[2].userPoolSize, 30);
        assertEq(out[2].timestamp, 3);
        // isUserPool=false records into hedgerPoolSize.
        L.PoolSnapshot[] memory outH = L.addToPoolHistory(hist, 30, false, 3);
        assertEq(outH[2].hedgerPoolSize, 30);
        assertEq(outH[2].userPoolSize, 0);
    }

    function test_addToPoolHistory_shiftsWhenAtMax() public pure {
        L.PoolSnapshot[] memory hist = new L.PoolSnapshot[](100); // MAX_HISTORY_LENGTH
        for (uint64 i = 0; i < 100; i++) {
            hist[i] = _snap(i + 1, uint128(i + 1), 0);
        }
        L.PoolSnapshot[] memory out = L.addToPoolHistory(hist, 999, true, 500);
        assertEq(out.length, 100, "length capped at MAX");
        assertEq(out[99].userPoolSize, 999, "new snapshot appended at end");
        assertEq(out[99].timestamp, 500);
        assertEq(out[0].userPoolSize, hist[1].userPoolSize, "oldest element dropped, shifted left");
    }

    // ---- allocations ----
    function test_userAndHedgerAllocation_splitByShift() public pure {
        uint256 u = L.calculateUserAllocation(600, 400, 7000); // 70% of 1000
        uint256 h = L.calculateHedgerAllocation(600, 400, 7000); // 30% of 1000
        assertEq(u, 700);
        assertEq(h, 300);
        assertEq(u + h, 1000);
    }

    // ---- isWithinTolerance ----
    function test_isWithinTolerance_equalWithinAndOutside() public pure {
        assertTrue(L.isWithinTolerance(100, 100, 1000)); // equal
        assertTrue(L.isWithinTolerance(105, 100, 1000)); // +5% within 10%
        assertTrue(L.isWithinTolerance(95, 100, 1000));  // -5% within 10%
        assertFalse(L.isWithinTolerance(120, 100, 1000)); // +20% outside 10%
    }

    // ---- calculateHistoricalYieldShift ----
    function _ys(uint128 shift, uint64 ts) internal pure returns (L.YieldShiftSnapshot memory s) {
        s = L.YieldShiftSnapshot({yieldShift: shift, timestamp: ts});
    }

    function test_historicalYieldShift_emptyReturnsZeros() public pure {
        L.YieldShiftSnapshot[] memory h = new L.YieldShiftSnapshot[](0);
        (uint256 a, uint256 mx, uint256 mn, uint256 v) = L.calculateHistoricalYieldShift(h, 24 hours, 1_000_000);
        assertEq(a, 0); assertEq(mx, 0); assertEq(mn, 0); assertEq(v, 0);
    }

    function test_historicalYieldShift_allStaleReturnsZeros() public pure {
        L.YieldShiftSnapshot[] memory h = new L.YieldShiftSnapshot[](2);
        h[0] = _ys(5000, 800_000);
        h[1] = _ys(6000, 900_000); // both older than cutoff 1_000_000 - 24h
        (uint256 a,,, uint256 v) = L.calculateHistoricalYieldShift(h, 24 hours, 1_000_000);
        assertEq(a, 0); assertEq(v, 0);
    }

    function test_historicalYieldShift_statsAndVolatility() public pure {
        L.YieldShiftSnapshot[] memory h = new L.YieldShiftSnapshot[](3);
        h[0] = _ys(4000, 990_000);
        h[1] = _ys(6000, 995_000);
        h[2] = _ys(5000, 999_000);
        (uint256 a, uint256 mx, uint256 mn, uint256 v) = L.calculateHistoricalYieldShift(h, 24 hours, 1_000_000);
        assertEq(a, 5000, "average");
        assertEq(mx, 6000, "max");
        assertEq(mn, 4000, "min");
        assertGt(v, 0, "volatility computed for >1 sample");
    }

    function test_historicalYieldShift_singleSample_zeroVolatility() public pure {
        L.YieldShiftSnapshot[] memory h = new L.YieldShiftSnapshot[](1);
        h[0] = _ys(5000, 999_000);
        (uint256 a, uint256 mx, uint256 mn, uint256 v) = L.calculateHistoricalYieldShift(h, 24 hours, 1_000_000);
        assertEq(a, 5000); assertEq(mx, 5000); assertEq(mn, 5000);
        assertEq(v, 0, "single sample -> zero volatility");
    }
}
