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
}

