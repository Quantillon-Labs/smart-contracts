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
}

