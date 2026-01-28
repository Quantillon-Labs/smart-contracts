// /test/TokenValidationLibrary.t.sol
// Unit tests for TokenValidationLibrary fee, threshold, oracle, and treasury helpers.
// This file exists to validate token-specific validation semantics directly.

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {TokenValidationLibrary} from "../src/libraries/TokenValidationLibrary.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";

/// @notice Harness contract to exercise TokenValidationLibrary through external calls.
contract TokenValidationHarness {
    function validateFee(uint256 fee, uint256 maxFee) external pure {
        TokenValidationLibrary.validateFee(fee, maxFee);
    }

    function validateThreshold(uint256 threshold, uint256 maxThreshold) external pure {
        TokenValidationLibrary.validateThreshold(threshold, maxThreshold);
    }

    function validateThresholdValue(uint256 value, uint256 threshold) external pure {
        TokenValidationLibrary.validateThresholdValue(value, threshold);
    }

    function validateOraclePrice(bool isValid) external pure {
        TokenValidationLibrary.validateOraclePrice(isValid);
    }

    function validateTreasuryAddress(address treasury) external pure {
        TokenValidationLibrary.validateTreasuryAddress(treasury);
    }
}

contract TokenValidationLibraryTest is Test {
    TokenValidationHarness private h;

    function setUp() public {
        h = new TokenValidationHarness();
    }
    // ----------------- validateFee -----------------

    function test_ValidateFee_WithinMaxOk(uint256 fee, uint256 maxFee) public view {
        vm.assume(maxFee > 0 && maxFee < type(uint128).max);
        uint256 f = fee % (maxFee + 1);
        h.validateFee(f, maxFee);
    }

    function test_ValidateFee_AboveMaxReverts(uint256 fee, uint256 maxFee) public {
        vm.assume(maxFee > 0 && maxFee < type(uint128).max);
        vm.assume(fee > maxFee);
        vm.expectRevert(CommonErrorLibrary.AboveLimit.selector);
        h.validateFee(fee, maxFee);
    }

    // ----------------- validateThreshold -----------------

    function test_ValidateThreshold_WithinMaxOk(uint256 threshold, uint256 maxThreshold) public view {
        vm.assume(maxThreshold > 0 && maxThreshold < type(uint128).max);
        uint256 t = threshold % (maxThreshold + 1);
        h.validateThreshold(t, maxThreshold);
    }

    function test_ValidateThreshold_AboveMaxReverts(uint256 threshold, uint256 maxThreshold) public {
        vm.assume(maxThreshold > 0 && maxThreshold < type(uint128).max);
        vm.assume(threshold > maxThreshold);
        vm.expectRevert(CommonErrorLibrary.AboveLimit.selector);
        h.validateThreshold(threshold, maxThreshold);
    }

    // ----------------- validateThresholdValue -----------------

    function test_ValidateThresholdValue_AboveOrEqualOk(uint256 value, uint256 threshold) public view {
        vm.assume(threshold > 0);
        vm.assume(value >= threshold);
        h.validateThresholdValue(value, threshold);
    }

    function test_ValidateThresholdValue_BelowReverts(uint256 value, uint256 threshold) public {
        vm.assume(threshold > 0);
        vm.assume(value < threshold);
        vm.expectRevert(CommonErrorLibrary.BelowThreshold.selector);
        h.validateThresholdValue(value, threshold);
    }

    // ----------------- validateOraclePrice -----------------

    function test_ValidateOraclePrice_ValidOk() public view {
        h.validateOraclePrice(true);
    }

    function test_ValidateOraclePrice_InvalidReverts() public {
        vm.expectRevert(CommonErrorLibrary.InvalidParameter.selector);
        h.validateOraclePrice(false);
    }

    // ----------------- validateTreasuryAddress -----------------

    function test_ValidateTreasuryAddress_NonZeroOk(address treasury) public view {
        vm.assume(treasury != address(0));
        h.validateTreasuryAddress(treasury);
    }

    function test_ValidateTreasuryAddress_ZeroReverts() public {
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        h.validateTreasuryAddress(address(0));
    }
}

