// /test/TokenValidationLibrary.t.sol
// Unit tests for TokenValidationLibrary's treasury helper — its only production-live function
// (the fee/threshold/oracle helpers were removed as production-dead; QEUROToken calls only
// validateTreasuryAddress).

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {TokenValidationLibrary} from "../src/libraries/TokenValidationLibrary.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";

/// @notice Harness contract to exercise TokenValidationLibrary through external calls.
contract TokenValidationHarness {
    function validateTreasuryAddress(address treasury) external pure {
        TokenValidationLibrary.validateTreasuryAddress(treasury);
    }
}

contract TokenValidationLibraryTest is Test {
    TokenValidationHarness private h;

    function setUp() public {
        h = new TokenValidationHarness();
    }

    function test_ValidateTreasuryAddress_NonZeroOk(address treasury) public view {
        vm.assume(treasury != address(0));
        h.validateTreasuryAddress(treasury);
    }

    function test_ValidateTreasuryAddress_ZeroReverts() public {
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        h.validateTreasuryAddress(address(0));
    }
}
