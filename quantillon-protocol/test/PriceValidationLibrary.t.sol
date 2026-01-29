// /test/PriceValidationLibrary.t.sol
// Unit tests for PriceValidationLibrary deviation and freshness checks.
// This file exists to validate price deviation semantics directly.

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {PriceValidationLibrary} from "../src/libraries/PriceValidationLibrary.sol";

contract PriceValidationHarness {
    function check(
        uint256 currentPrice,
        uint256 lastValidPrice,
        uint256 maxDeviation,
        uint256 lastUpdateBlock,
        uint256 minBlocksBetweenUpdates
    ) external view returns (bool shouldRevert, uint256 deviationBps) {
        return PriceValidationLibrary.checkPriceDeviation(
            currentPrice,
            lastValidPrice,
            maxDeviation,
            lastUpdateBlock,
            minBlocksBetweenUpdates
        );
    }
}

contract PriceValidationLibraryTest is Test {
    PriceValidationHarness private h;

    function setUp() public {
        h = new PriceValidationHarness();
    }

    /// @notice If lastValidPrice is zero, no deviation check should run.
    function test_NoLastPrice_NoRevertAndZeroDeviation(uint256 currentPrice) public view {
        (bool shouldRevert, uint256 devBps) = h.check(
            currentPrice,
            0,
            1_000,
            block.number,
            1
        );

        assertFalse(shouldRevert, "Should never revert when no last price");
        assertEq(devBps, 0, "Deviation should be zero when no last price");
    }

    /// @notice Deviation within maxDeviation should not request revert.
    function test_DeviationWithinBounds_NoRevert(
        uint128 lastPrice,
        uint16 maxDeviationBps
    ) public {
        vm.assume(lastPrice > 0);
        vm.assume(maxDeviationBps > 0);

        // Set block so deviation check is active
        uint256 lastUpdateBlock = block.number;
        uint256 minBlocks = 1;
        vm.roll(lastUpdateBlock + minBlocks + 1);

        uint256 maxDiff = (uint256(lastPrice) * maxDeviationBps) / 10_000;
        uint256 currentPrice = uint256(lastPrice) + maxDiff;

        (bool shouldRevert, uint256 devBps) = h.check(
            currentPrice,
            lastPrice,
            maxDeviationBps,
            lastUpdateBlock,
            minBlocks
        );

        assertFalse(shouldRevert, "Deviation within bounds must not request revert");
        assertLe(devBps, maxDeviationBps, "Deviation must be <= maxDeviation");
    }

    /// @notice When the library requests a revert, deviation must be above the configured max.
    /// @dev This is a relational property test instead of constructing a specific reverting case.
    function test_DeviationAboveBounds_Property(
        uint128 lastPrice,
        uint128 currentPrice,
        uint16 maxDeviationBps
    ) public {
        vm.assume(lastPrice > 0);
        vm.assume(maxDeviationBps > 0);

        uint256 lastUpdateBlock = block.number;
        uint256 minBlocks = 1;
        vm.roll(lastUpdateBlock + minBlocks + 1);

        (bool shouldRevert, uint256 devBps) = h.check(
            currentPrice,
            lastPrice,
            maxDeviationBps,
            lastUpdateBlock,
            minBlocks
        );

        if (shouldRevert) {
            assertGt(devBps, maxDeviationBps, "Deviation must exceed maxDeviation when revert requested");
        } else if (devBps > 0) {
            // When deviation is computed and no revert requested, it must be within bounds.
            assertLe(devBps, maxDeviationBps, "Deviation within bounds must not request revert");
        }
    }

    // =============================================================================
    // ADDITIONAL EDGE CASE AND FUZZ TESTS
    // =============================================================================

    /// @notice Price drop to zero should be detected
    function test_PriceDropToZero_Detected(uint128 lastPrice) public {
        vm.assume(lastPrice > 0);

        // Use fixed block numbers so the library's block check is satisfied in all runs
        uint256 lastUpdateBlock = 1;
        vm.roll(lastUpdateBlock + 10);

        (bool shouldRevert, uint256 devBps) = h.check(
            0, // current price is zero
            lastPrice,
            1000, // 10% max deviation
            lastUpdateBlock,
            1
        );

        // 100% drop should exceed any reasonable deviation limit
        assertTrue(shouldRevert, "Price drop to zero should trigger revert");
        assertEq(devBps, 10_000, "100% drop should be 10000 bps");
    }

    /// @notice Price spike (doubling) should be detected with low threshold
    function test_PriceSpike_Detected(uint128 lastPrice) public {
        vm.assume(lastPrice > 0 && lastPrice < type(uint128).max / 2);

        // Use fixed block numbers so the library's block check is satisfied in all runs
        uint256 lastUpdateBlock = 1;
        vm.roll(lastUpdateBlock + 10);

        uint256 currentPrice = uint256(lastPrice) * 2; // 100% increase

        (bool shouldRevert, uint256 devBps) = h.check(
            currentPrice,
            lastPrice,
            5000, // 50% max deviation
            lastUpdateBlock,
            1
        );

        assertTrue(shouldRevert, "100% price spike should exceed 50% threshold");
        assertEq(devBps, 10_000, "100% increase should be 10000 bps");
    }

    /// @notice Updates within min block window should not check deviation
    function test_WithinMinBlockWindow_NoCheck(
        uint128 lastPrice,
        uint128 currentPrice
    ) public view {
        vm.assume(lastPrice > 0);

        // Don't advance blocks - still within window
        (bool shouldRevert, ) = h.check(
            currentPrice,
            lastPrice,
            100, // Very tight 1% threshold
            block.number, // Same block
            10 // Need 10 blocks minimum
        );

        // Within window, should not trigger revert regardless of deviation
        assertFalse(shouldRevert, "Within min block window should not revert");
        // devBps might still be calculated but revert is false
    }

    /// @notice Fuzz: Symmetry - deviation calculation should be same for up/down moves of same magnitude
    function testFuzz_DeviationSymmetry(uint64 basePrice, uint64 deviation) public {
        vm.assume(basePrice > 1000);
        vm.assume(deviation > 0 && deviation < basePrice);

        uint256 lastUpdateBlock = block.number;
        vm.roll(lastUpdateBlock + 2);

        uint256 priceUp = uint256(basePrice) + deviation;
        uint256 priceDown = uint256(basePrice) - deviation;

        (, uint256 devBpsUp) = h.check(
            priceUp,
            basePrice,
            10_000,
            lastUpdateBlock,
            1
        );

        (, uint256 devBpsDown) = h.check(
            priceDown,
            basePrice,
            10_000,
            lastUpdateBlock,
            1
        );

        // Deviation should be same magnitude for same absolute change
        assertEq(devBpsUp, devBpsDown, "Up and down deviations should be equal");
    }

    /// @notice Edge case: very small prices (potential precision issues)
    function test_VerySmallPrices(uint8 smallPrice) public {
        vm.assume(smallPrice > 0);

        uint256 lastUpdateBlock = block.number;
        vm.roll(lastUpdateBlock + 2);

        // Should handle small prices without overflow/underflow
        (bool shouldRevert, ) = h.check(
            smallPrice,
            smallPrice,
            1000,
            lastUpdateBlock,
            1
        );

        assertFalse(shouldRevert, "Same small price should not trigger revert");
    }

    /// @notice Edge case: large prices (potential overflow)
    function test_LargePrices() public {
        uint256 lastUpdateBlock = block.number;
        vm.roll(lastUpdateBlock + 2);

        uint256 largePrice = type(uint128).max;

        (bool shouldRevert, ) = h.check(
            largePrice,
            largePrice,
            1000,
            lastUpdateBlock,
            1
        );

        assertFalse(shouldRevert, "Same large price should not trigger revert");
    }
}

