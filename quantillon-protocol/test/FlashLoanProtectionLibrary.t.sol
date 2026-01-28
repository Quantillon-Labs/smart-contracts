// /test/FlashLoanProtectionLibrary.t.sol
// Unit tests for FlashLoanProtectionLibrary balance-change protection.
// This file exists to validate flash-loan detection logic in isolation.

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {FlashLoanProtectionLibrary} from "../src/libraries/FlashLoanProtectionLibrary.sol";

/// @notice Simple harness to expose the internal library function for testing.
contract FlashLoanProtectionHarness {
    function validate(
        uint256 beforeBalance,
        uint256 afterBalance,
        uint256 maxDecrease
    ) external pure returns (bool) {
        return FlashLoanProtectionLibrary.validateBalanceChange(
            beforeBalance,
            afterBalance,
            maxDecrease
        );
    }
}

contract FlashLoanProtectionLibraryTest is Test {
    FlashLoanProtectionHarness private harness;

    function setUp() public {
        harness = new FlashLoanProtectionHarness();
    }

    /// @notice When balance increases or stays the same, validation should always pass.
    function test_NoDecreaseAlwaysOk(uint256 beforeBalance, uint256 delta) public view {
        // Avoid overflow on addition when fuzzing
        vm.assume(beforeBalance <= type(uint256).max - delta);
        uint256 afterBalance = beforeBalance + delta;
        bool ok = harness.validate(beforeBalance, afterBalance, 0);
        assertTrue(ok, "Non-decreasing balances must be accepted");
    }

    /// @notice When decrease is within maxDecrease, validation should pass.
    function test_DecreaseWithinLimitOk(
        uint128 beforeBalance,
        uint128 decrease,
        uint128 maxDecrease
    ) public view {
        vm.assume(beforeBalance > 0);
        uint256 d = uint256(decrease % beforeBalance);
        uint256 m = uint256(maxDecrease);
        vm.assume(d <= m);

        uint256 afterBalance = beforeBalance - d;
        bool ok = harness.validate(beforeBalance, afterBalance, m);
        assertTrue(ok, "Decrease <= maxDecrease should be accepted");
    }

    /// @notice When decrease exceeds maxDecrease, validation should fail.
    function test_DecreaseAboveLimitFails(
        uint128 beforeBalance,
        uint128 /* decrease */,
        uint128 maxDecrease
    ) public view {
        vm.assume(beforeBalance > 1);
        uint256 m = uint256(maxDecrease % beforeBalance);
        vm.assume(m > 0);

        // Force decrease strictly greater than maxDecrease but less than beforeBalance
        uint256 d = m + 1;
        vm.assume(d < beforeBalance);

        uint256 afterBalance = beforeBalance - d;
        bool ok = harness.validate(beforeBalance, afterBalance, m);
        assertFalse(ok, "Decrease > maxDecrease should be rejected");
    }

    // =============================================================================
    // ADDITIONAL EDGE CASE TESTS
    // =============================================================================

    /// @notice Zero balance edge case - should handle gracefully
    function test_ZeroBeforeBalance_AcceptsAnyIncrease(uint256 afterBalance) public view {
        bool ok = harness.validate(0, afterBalance, 0);
        assertTrue(ok, "Zero starting balance with any ending balance should pass");
    }

    /// @notice Maximum values edge case
    function test_MaxValues_NoOverflow() public view {
        uint256 maxVal = type(uint256).max;
        // This should not overflow
        bool ok = harness.validate(maxVal, maxVal, 0);
        assertTrue(ok, "Max value with no change should pass");
    }

    /// @notice Exact boundary - decrease equals maxDecrease
    function test_ExactBoundary_Passes(uint128 beforeBalance, uint128 decrease) public view {
        vm.assume(beforeBalance > 0);
        uint256 d = uint256(decrease % beforeBalance);

        uint256 afterBalance = beforeBalance - d;
        // maxDecrease equals the actual decrease - should pass
        bool ok = harness.validate(beforeBalance, afterBalance, d);
        assertTrue(ok, "Exact boundary (decrease == maxDecrease) should pass");
    }

    /// @notice Large flash loan pattern detection
    function test_LargeFlashLoanPattern_Detected(uint128 initialBalance) public view {
        vm.assume(initialBalance > 1000);

        // Simulate flash loan: large temporary increase then back to original
        uint256 flashAmount = uint256(initialBalance) * 10;
        uint256 afterFlash = initialBalance; // Back to original

        // If checking before -> after flash, with very small maxDecrease
        // the pattern where balance returns to original after large spike
        // should be detected if decrease > maxDecrease
        bool ok = harness.validate(initialBalance + flashAmount, afterFlash, initialBalance / 10);

        // The decrease (flashAmount) exceeds maxDecrease (initialBalance/10)
        assertFalse(ok, "Flash loan return pattern should be detected");
    }

    /// @notice Fuzz: Relationship between before, after, and maxDecrease
    function testFuzz_RelationalProperty(
        uint128 before,
        uint128 after_,
        uint128 maxDec
    ) public view {
        vm.assume(before > 0);

        bool ok = harness.validate(before, after_, maxDec);

        if (after_ >= before) {
            // No decrease - should always pass
            assertTrue(ok, "Increase or no change should always pass");
        } else {
            uint256 decrease = before - after_;
            if (decrease <= maxDec) {
                assertTrue(ok, "Decrease within limit should pass");
            } else {
                assertFalse(ok, "Decrease exceeding limit should fail");
            }
        }
    }
}

