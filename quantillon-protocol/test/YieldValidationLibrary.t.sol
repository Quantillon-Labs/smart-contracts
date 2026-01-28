// /test/YieldValidationLibrary.t.sol
// Unit tests for YieldValidationLibrary yield/ratio/slippage helpers.
// This file exists to validate yield-specific validation semantics directly.

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {YieldValidationLibrary} from "../src/libraries/YieldValidationLibrary.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";

/// @notice Harness to exercise YieldValidationLibrary via external calls for revert testing.
contract YieldValidationHarness {
    function validateYieldShift(uint256 shift) external pure {
        YieldValidationLibrary.validateYieldShift(shift);
    }

    function validateAdjustmentSpeed(uint256 speed, uint256 maxSpeed) external pure {
        YieldValidationLibrary.validateAdjustmentSpeed(speed, maxSpeed);
    }

    function validateTargetRatio(uint256 ratio, uint256 maxRatio) external pure {
        YieldValidationLibrary.validateTargetRatio(ratio, maxRatio);
    }

    function validateSlippage(
        uint256 minAcceptable,
        uint256 expected,
        uint16 toleranceBps
    ) external pure {
        YieldValidationLibrary.validateSlippage(minAcceptable, expected, toleranceBps);
    }

    function validateTreasuryAddress(address treasury) external pure {
        YieldValidationLibrary.validateTreasuryAddress(treasury);
    }
}

contract YieldValidationLibraryTest is Test {
    YieldValidationHarness private h;

    function setUp() public {
        h = new YieldValidationHarness();
    }
    // ----------------- validateYieldShift -----------------

    function test_ValidateYieldShift_InRangeOk(uint256 shift) public view {
        vm.assume(shift <= 10_000);
        h.validateYieldShift(shift);
    }

    function test_ValidateYieldShift_AboveRangeReverts(uint256 shift) public {
        vm.assume(shift > 10_000);
        vm.expectRevert(CommonErrorLibrary.InvalidParameter.selector);
        h.validateYieldShift(shift);
    }

    // ----------------- validateAdjustmentSpeed -----------------

    function test_ValidateAdjustmentSpeed_WithinMaxOk(uint256 speed, uint256 maxSpeed) public view {
        vm.assume(maxSpeed > 0 && maxSpeed < type(uint128).max);
        uint256 s = speed % (maxSpeed + 1);
        h.validateAdjustmentSpeed(s, maxSpeed);
    }

    function test_ValidateAdjustmentSpeed_TooHighReverts(uint256 maxSpeed) public {
        vm.assume(maxSpeed > 0 && maxSpeed < type(uint128).max);
        uint256 speed = maxSpeed + 1;
        vm.expectRevert(CommonErrorLibrary.InvalidParameter.selector);
        h.validateAdjustmentSpeed(speed, maxSpeed);
    }

    // ----------------- validateTargetRatio -----------------

    function test_ValidateTargetRatio_ValidOk(uint256 ratio, uint256 maxRatio) public view {
        vm.assume(maxRatio > 0);
        vm.assume(ratio > 0 && ratio <= maxRatio);
        h.validateTargetRatio(ratio, maxRatio);
    }

    function test_ValidateTargetRatio_ZeroReverts(uint256 maxRatio) public {
        vm.assume(maxRatio > 0);
        vm.expectRevert(CommonErrorLibrary.InvalidParameter.selector);
        h.validateTargetRatio(0, maxRatio);
    }

    function test_ValidateTargetRatio_AboveMaxReverts(uint256 ratio, uint256 maxRatio) public {
        vm.assume(maxRatio > 0);
        vm.assume(ratio > maxRatio);
        vm.expectRevert(CommonErrorLibrary.AboveLimit.selector);
        h.validateTargetRatio(ratio, maxRatio);
    }

    // ----------------- validateSlippage -----------------

    function test_ValidateSlippage_WithinToleranceOk(
        uint128 expected,
        uint16 toleranceBps
    ) public view {
        vm.assume(expected > 0);
        vm.assume(toleranceBps <= 10_000);

        uint256 minAcceptable = (uint256(expected) * (10_000 - toleranceBps)) / 10_000;
        h.validateSlippage(minAcceptable, expected, toleranceBps);
    }

    function test_ValidateSlippage_BelowToleranceReverts(
        uint128 expected,
        uint16 toleranceBps
    ) public {
        vm.assume(expected > 0);
        vm.assume(toleranceBps <= 10_000);

        uint256 minAcceptable = (uint256(expected) * (10_000 - toleranceBps)) / 10_000;
        if (minAcceptable == 0) return;

        vm.expectRevert(CommonErrorLibrary.ExcessiveSlippage.selector);
        h.validateSlippage(minAcceptable - 1, expected, toleranceBps);
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

