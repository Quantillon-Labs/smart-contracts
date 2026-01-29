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

    // =============================================================================
    // ADDITIONAL EDGE CASE AND FUZZ TESTS
    // =============================================================================

    /// @notice Fee at exact max boundary should pass
    function test_ValidateFee_ExactMax(uint128 maxFee) public view {
        vm.assume(maxFee > 0);
        h.validateFee(maxFee, maxFee);
    }

    /// @notice Fee just above max should revert
    function test_ValidateFee_JustAboveMax(uint128 maxFee) public {
        vm.assume(maxFee > 0 && maxFee < type(uint128).max);
        vm.expectRevert(CommonErrorLibrary.AboveLimit.selector);
        h.validateFee(uint256(maxFee) + 1, maxFee);
    }

    /// @notice Zero fee should always be valid
    function test_ValidateFee_ZeroFee(uint128 maxFee) public view {
        vm.assume(maxFee > 0);
        h.validateFee(0, maxFee);
    }

    /// @notice Threshold at exact max boundary should pass
    function test_ValidateThreshold_ExactMax(uint128 maxThreshold) public view {
        vm.assume(maxThreshold > 0);
        h.validateThreshold(maxThreshold, maxThreshold);
    }

    /// @notice Value exactly at threshold should pass
    function test_ValidateThresholdValue_ExactThreshold(uint128 threshold) public view {
        vm.assume(threshold > 0);
        h.validateThresholdValue(threshold, threshold);
    }

    /// @notice Value just below threshold should revert
    function test_ValidateThresholdValue_JustBelow(uint128 threshold) public {
        vm.assume(threshold > 1);
        vm.expectRevert(CommonErrorLibrary.BelowThreshold.selector);
        h.validateThresholdValue(threshold - 1, threshold);
    }

    /// @notice Fuzz: Fee validation relational property
    function testFuzz_ValidateFee_RelationalProperty(uint256 fee, uint256 maxFee) public {
        vm.assume(maxFee > 0 && maxFee < type(uint128).max);

        if (fee <= maxFee) {
            // Should not revert
            h.validateFee(fee, maxFee);
        } else {
            // Should revert
            vm.expectRevert(CommonErrorLibrary.AboveLimit.selector);
            h.validateFee(fee, maxFee);
        }
    }

    /// @notice Fuzz: Threshold value validation relational property
    function testFuzz_ValidateThresholdValue_RelationalProperty(uint256 value, uint256 threshold) public {
        vm.assume(threshold > 0);

        if (value >= threshold) {
            // Should not revert
            h.validateThresholdValue(value, threshold);
        } else {
            // Should revert
            vm.expectRevert(CommonErrorLibrary.BelowThreshold.selector);
            h.validateThresholdValue(value, threshold);
        }
    }

    /// @notice Large values should not overflow
    function test_LargeValues_NoOverflow() public view {
        uint256 largeVal = type(uint128).max;
        h.validateFee(largeVal, largeVal);
        h.validateThreshold(largeVal, largeVal);
        h.validateThresholdValue(largeVal, largeVal);
    }

    /// @notice Oracle price validation with true is idempotent
    function test_ValidateOraclePrice_TrueMultipleTimes() public view {
        h.validateOraclePrice(true);
        h.validateOraclePrice(true);
        h.validateOraclePrice(true);
        // All should pass without issue
    }
}

