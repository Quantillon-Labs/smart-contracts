// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {HedgerPoolRedeemMathLibrary} from "../src/libraries/HedgerPoolRedeemMathLibrary.sol";

contract HedgerPoolRedeemMathLibraryTest is Test {
    function test_CalculateRedeemPnL_ProfitVector() public pure {
        int256 realizedDelta = HedgerPoolRedeemMathLibrary.calculateRedeemPnL(
            1_000e18, // currentQeuroBacked
            1_300e6, // filledBefore
            1e18, // price
            250e18, // qeuroAmount
            int128(100e6) // previousRealizedPnL
        );

        // totalUnrealized = +300e6, netUnrealized = +200e6, 25% share => +50e6
        assertEq(realizedDelta, int256(50e6));
    }

    function test_CalculateRedeemPnL_LossVector() public pure {
        int256 realizedDelta = HedgerPoolRedeemMathLibrary.calculateRedeemPnL(
            1_000e18, // currentQeuroBacked
            800e6, // filledBefore
            1e18, // price
            200e18, // qeuroAmount
            int128(-50e6) // previousRealizedPnL
        );

        // totalUnrealized = -200e6, netUnrealized = -150e6, 20% share => -30e6
        assertEq(realizedDelta, -int256(30e6));
    }

    function test_ComputeMarginTransition_ProfitVector() public pure {
        HedgerPoolRedeemMathLibrary.MarginTransition memory t =
            HedgerPoolRedeemMathLibrary.computeMarginTransition(1_000e6, 400e6, 5, int256(100e6));

        assertTrue(t.isProfit);
        assertFalse(t.marginWiped);
        assertEq(t.deltaAmount, 100e6);
        assertEq(t.nextMargin, 500e6);
        assertEq(t.totalMarginAfter, 1_100e6);
        assertEq(t.nextPositionSize, 2_500e6);
        assertEq(t.newMarginRatio, 2000);
    }

    function test_ComputeMarginTransition_LossVector() public pure {
        HedgerPoolRedeemMathLibrary.MarginTransition memory t =
            HedgerPoolRedeemMathLibrary.computeMarginTransition(1_000e6, 400e6, 5, -int256(150e6));

        assertFalse(t.isProfit);
        assertFalse(t.marginWiped);
        assertEq(t.deltaAmount, 150e6);
        assertEq(t.nextMargin, 250e6);
        assertEq(t.totalMarginAfter, 850e6);
        assertEq(t.nextPositionSize, 1_250e6);
        assertEq(t.newMarginRatio, 2000);
    }

    function test_ComputeMarginTransition_FullMarginWipeout() public pure {
        HedgerPoolRedeemMathLibrary.MarginTransition memory t =
            HedgerPoolRedeemMathLibrary.computeMarginTransition(1_000e6, 400e6, 5, -int256(500e6));

        assertFalse(t.isProfit);
        assertTrue(t.marginWiped);
        assertEq(t.deltaAmount, 500e6);
        assertEq(t.nextMargin, 0);
        assertEq(t.totalMarginAfter, 600e6);
        assertEq(t.nextPositionSize, 0);
        assertEq(t.newMarginRatio, 0);
    }

    function test_ComputeMarginTransition_ClampsToUint96Boundaries() public pure {
        uint256 max96 = type(uint96).max;
        HedgerPoolRedeemMathLibrary.MarginTransition memory t =
            HedgerPoolRedeemMathLibrary.computeMarginTransition(max96 + 100, max96 - 1, 20, int256(10));

        assertTrue(t.isProfit);
        assertFalse(t.marginWiped);
        assertEq(t.nextMargin, max96);
        assertEq(t.totalMarginAfter, max96 + 101);
        assertEq(t.nextPositionSize, max96);
        assertEq(t.newMarginRatio, 10000);
    }
}
