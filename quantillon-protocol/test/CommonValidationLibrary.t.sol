// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {CommonValidationLibrary} from "../src/libraries/CommonValidationLibrary.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";

/**
 * @title CommonValidationLibraryTest
 * @notice Comprehensive test suite for CommonValidationLibrary
 *
 * @dev This test suite covers:
 *      - Address validation (zero address, non-contract)
 *      - Amount validation (positive, min, max)
 *      - Percentage validation
 *      - Duration validation
 *      - Price validation
 *      - Condition validation
 *      - Balance and threshold validation
 *      - Slippage validation
 *      - Edge cases and boundary conditions
 *
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract CommonValidationLibraryTest is Test {
    // =============================================================================
    // TEST HARNESS CONTRACT
    // =============================================================================

    // Since library functions are internal, we use a harness contract
    CommonValidationHarness public harness;

    function setUp() public {
        harness = new CommonValidationHarness();
    }

    // =============================================================================
    // ADDRESS VALIDATION TESTS
    // =============================================================================

    /**
     * @notice Test validateNonZeroAddress passes for valid address
     */
    function test_ValidateNonZeroAddress_ValidAddress_Passes() public view {
        harness.validateNonZeroAddress(address(0x1234), "admin");
    }

    /**
     * @notice Test validateNonZeroAddress reverts for zero address with admin type
     */
    function test_ValidateNonZeroAddress_ZeroAdmin_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.InvalidAdmin.selector);
        harness.validateNonZeroAddress(address(0), "admin");
    }

    /**
     * @notice Test validateNonZeroAddress reverts for zero address with treasury type
     */
    function test_ValidateNonZeroAddress_ZeroTreasury_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.InvalidTreasury.selector);
        harness.validateNonZeroAddress(address(0), "treasury");
    }

    /**
     * @notice Test validateNonZeroAddress reverts for zero address with token type
     */
    function test_ValidateNonZeroAddress_ZeroToken_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.InvalidToken.selector);
        harness.validateNonZeroAddress(address(0), "token");
    }

    /**
     * @notice Test validateNonZeroAddress reverts for zero address with oracle type
     */
    function test_ValidateNonZeroAddress_ZeroOracle_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.InvalidOracle.selector);
        harness.validateNonZeroAddress(address(0), "oracle");
    }

    /**
     * @notice Test validateNonZeroAddress reverts for zero address with vault type
     */
    function test_ValidateNonZeroAddress_ZeroVault_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.InvalidVault.selector);
        harness.validateNonZeroAddress(address(0), "vault");
    }

    /**
     * @notice Test validateNonZeroAddress reverts for zero address with unknown type
     */
    function test_ValidateNonZeroAddress_ZeroUnknownType_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.InvalidAddress.selector);
        harness.validateNonZeroAddress(address(0), "unknown");
    }

    /**
     * @notice Test validateTreasuryAddress passes for valid address
     */
    function test_ValidateTreasuryAddress_ValidAddress_Passes() public view {
        harness.validateTreasuryAddress(address(0x1234));
    }

    /**
     * @notice Test validateTreasuryAddress reverts for zero address
     */
    function test_ValidateTreasuryAddress_ZeroAddress_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        harness.validateTreasuryAddress(address(0));
    }

    // =============================================================================
    // AMOUNT VALIDATION TESTS
    // =============================================================================

    /**
     * @notice Test validatePositiveAmount passes for positive amount
     */
    function test_ValidatePositiveAmount_PositiveAmount_Passes() public view {
        harness.validatePositiveAmount(1);
        harness.validatePositiveAmount(1000);
        harness.validatePositiveAmount(type(uint256).max);
    }

    /**
     * @notice Test validatePositiveAmount reverts for zero
     */
    function test_ValidatePositiveAmount_ZeroAmount_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.InvalidAmount.selector);
        harness.validatePositiveAmount(0);
    }

    /**
     * @notice Test validateMinAmount passes when amount >= min
     */
    function test_ValidateMinAmount_AboveMin_Passes() public view {
        harness.validateMinAmount(100, 50);
        harness.validateMinAmount(100, 100);
    }

    /**
     * @notice Test validateMinAmount reverts when amount < min
     */
    function test_ValidateMinAmount_BelowMin_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.InsufficientBalance.selector);
        harness.validateMinAmount(50, 100);
    }

    /**
     * @notice Test validateMaxAmount passes when amount <= max
     */
    function test_ValidateMaxAmount_BelowMax_Passes() public view {
        harness.validateMaxAmount(50, 100);
        harness.validateMaxAmount(100, 100);
    }

    /**
     * @notice Test validateMaxAmount reverts when amount > max
     */
    function test_ValidateMaxAmount_AboveMax_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.AboveLimit.selector);
        harness.validateMaxAmount(150, 100);
    }

    // =============================================================================
    // PERCENTAGE VALIDATION TESTS
    // =============================================================================

    /**
     * @notice Test validatePercentage passes for valid percentage
     */
    function test_ValidatePercentage_ValidPercentage_Passes() public view {
        harness.validatePercentage(0, 10000);
        harness.validatePercentage(5000, 10000);
        harness.validatePercentage(10000, 10000);
    }

    /**
     * @notice Test validatePercentage reverts when percentage exceeds max
     */
    function test_ValidatePercentage_ExceedsMax_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.AboveLimit.selector);
        harness.validatePercentage(10001, 10000);
    }

    // =============================================================================
    // DURATION VALIDATION TESTS
    // =============================================================================

    /**
     * @notice Test validateDuration passes for valid duration
     */
    function test_ValidateDuration_ValidDuration_Passes() public view {
        harness.validateDuration(7 days, 1 days, 30 days);
        harness.validateDuration(1 days, 1 days, 30 days); // At min
        harness.validateDuration(30 days, 1 days, 30 days); // At max
    }

    /**
     * @notice Test validateDuration reverts when duration too short
     */
    function test_ValidateDuration_TooShort_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.HoldingPeriodNotMet.selector);
        harness.validateDuration(12 hours, 1 days, 30 days);
    }

    /**
     * @notice Test validateDuration reverts when duration too long
     */
    function test_ValidateDuration_TooLong_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.AboveLimit.selector);
        harness.validateDuration(60 days, 1 days, 30 days);
    }

    // =============================================================================
    // PRICE VALIDATION TESTS
    // =============================================================================

    /**
     * @notice Test validatePrice passes for valid price
     */
    function test_ValidatePrice_ValidPrice_Passes() public view {
        harness.validatePrice(1);
        harness.validatePrice(1e18);
    }

    /**
     * @notice Test validatePrice reverts for zero price
     */
    function test_ValidatePrice_ZeroPrice_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.InvalidPrice.selector);
        harness.validatePrice(0);
    }

    // =============================================================================
    // CONDITION VALIDATION TESTS
    // =============================================================================

    /**
     * @notice Test validateCondition passes when condition is true
     */
    function test_ValidateCondition_True_Passes() public view {
        harness.validateCondition(true, "oracle");
    }

    /**
     * @notice Test validateCondition reverts for oracle type
     */
    function test_ValidateCondition_FalseOracle_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.InvalidOracle.selector);
        harness.validateCondition(false, "oracle");
    }

    /**
     * @notice Test validateCondition reverts for collateralization type
     */
    function test_ValidateCondition_FalseCollateralization_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.InsufficientCollateralization.selector);
        harness.validateCondition(false, "collateralization");
    }

    /**
     * @notice Test validateCondition reverts for authorization type
     */
    function test_ValidateCondition_FalseAuthorization_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.NotAuthorized.selector);
        harness.validateCondition(false, "authorization");
    }

    /**
     * @notice Test validateCondition reverts with generic error for unknown type
     */
    function test_ValidateCondition_FalseUnknown_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.InvalidCondition.selector);
        harness.validateCondition(false, "unknown");
    }

    // =============================================================================
    // COUNT AND BALANCE VALIDATION TESTS
    // =============================================================================

    /**
     * @notice Test validateCountLimit passes when count below max
     */
    function test_ValidateCountLimit_BelowMax_Passes() public view {
        harness.validateCountLimit(5, 10);
    }

    /**
     * @notice Test validateCountLimit reverts when count >= max
     */
    function test_ValidateCountLimit_AtMax_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.TooManyPositions.selector);
        harness.validateCountLimit(10, 10);
    }

    /**
     * @notice Test validateSufficientBalance passes when sufficient
     */
    function test_ValidateSufficientBalance_Sufficient_Passes() public view {
        harness.validateSufficientBalance(100, 50);
        harness.validateSufficientBalance(100, 100);
    }

    /**
     * @notice Test validateSufficientBalance reverts when insufficient
     */
    function test_ValidateSufficientBalance_Insufficient_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.InsufficientBalance.selector);
        harness.validateSufficientBalance(50, 100);
    }

    // =============================================================================
    // SLIPPAGE VALIDATION TESTS
    // =============================================================================

    /**
     * @notice Test validateSlippage passes when within tolerance
     */
    function test_ValidateSlippage_WithinTolerance_Passes() public view {
        // 100 received, 100 expected, 10% tolerance
        harness.validateSlippage(100, 100, 1000);
        // 95 received, 100 expected, 10% tolerance (5% slippage ok)
        harness.validateSlippage(95, 100, 1000);
        // 90 received, 100 expected, 10% tolerance (exactly at limit)
        harness.validateSlippage(90, 100, 1000);
    }

    /**
     * @notice Test validateSlippage reverts when exceeds tolerance
     */
    function test_ValidateSlippage_ExceedsTolerance_Reverts() public {
        // 85 received, 100 expected, 10% tolerance (15% slippage exceeds)
        vm.expectRevert(CommonErrorLibrary.InvalidParameter.selector);
        harness.validateSlippage(85, 100, 1000);
    }

    // =============================================================================
    // THRESHOLD VALIDATION TESTS
    // =============================================================================

    /**
     * @notice Test validateThresholdValue passes when value >= threshold
     */
    function test_ValidateThresholdValue_AboveThreshold_Passes() public view {
        harness.validateThresholdValue(100, 50);
        harness.validateThresholdValue(100, 100);
    }

    /**
     * @notice Test validateThresholdValue reverts when value < threshold
     */
    function test_ValidateThresholdValue_BelowThreshold_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.BelowThreshold.selector);
        harness.validateThresholdValue(50, 100);
    }

    /**
     * @notice Test validateFee passes when fee <= max
     */
    function test_ValidateFee_ValidFee_Passes() public view {
        harness.validateFee(100, 500);
        harness.validateFee(500, 500);
    }

    /**
     * @notice Test validateFee reverts when fee > max
     */
    function test_ValidateFee_ExceedsMax_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.InvalidParameter.selector);
        harness.validateFee(600, 500);
    }

    /**
     * @notice Test validateThreshold passes when threshold <= max
     */
    function test_ValidateThreshold_ValidThreshold_Passes() public view {
        harness.validateThreshold(100, 500);
        harness.validateThreshold(500, 500);
    }

    /**
     * @notice Test validateThreshold reverts when threshold > max
     */
    function test_ValidateThreshold_ExceedsMax_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.InvalidParameter.selector);
        harness.validateThreshold(600, 500);
    }

    // =============================================================================
    // FUZZ TESTS
    // =============================================================================

    /**
     * @notice Fuzz test validatePositiveAmount
     */
    function testFuzz_ValidatePositiveAmount_NonZeroPasses(uint256 amount) public view {
        vm.assume(amount > 0);
        harness.validatePositiveAmount(amount);
    }

    /**
     * @notice Fuzz test validateMinAmount
     */
    function testFuzz_ValidateMinAmount_AboveMinPasses(uint256 amount, uint256 minAmount) public view {
        vm.assume(amount >= minAmount);
        harness.validateMinAmount(amount, minAmount);
    }

    /**
     * @notice Fuzz test validateMaxAmount
     */
    function testFuzz_ValidateMaxAmount_BelowMaxPasses(uint256 amount, uint256 maxAmount) public view {
        vm.assume(amount <= maxAmount);
        harness.validateMaxAmount(amount, maxAmount);
    }

    /**
     * @notice Fuzz test validatePercentage
     */
    function testFuzz_ValidatePercentage_WithinMaxPasses(uint256 percentage, uint256 maxPercentage) public view {
        vm.assume(percentage <= maxPercentage);
        harness.validatePercentage(percentage, maxPercentage);
    }

    /**
     * @notice Fuzz test validateDuration
     */
    function testFuzz_ValidateDuration_WithinRangePasses(
        uint256 duration,
        uint256 minDuration,
        uint256 maxDuration
    ) public view {
        vm.assume(minDuration <= maxDuration);
        vm.assume(duration >= minDuration);
        vm.assume(duration <= maxDuration);
        harness.validateDuration(duration, minDuration, maxDuration);
    }

    /**
     * @notice Fuzz test validateSlippage
     */
    function testFuzz_ValidateSlippage_WithinTolerancePasses(
        uint128 received,
        uint128 expected,
        uint16 tolerance
    ) public view {
        vm.assume(expected > 0);
        vm.assume(tolerance <= 10000);

        uint256 minReceived = uint256(expected) * (10000 - uint256(tolerance)) / 10000;
        vm.assume(received >= minReceived);

        harness.validateSlippage(uint256(received), uint256(expected), uint256(tolerance));
    }
}

/**
 * @title CommonValidationHarness
 * @notice Exposes internal library functions for testing
 */
contract CommonValidationHarness {
    function validateNonZeroAddress(address addr, string memory errorType) external pure {
        CommonValidationLibrary.validateNonZeroAddress(addr, errorType);
    }

    function validatePositiveAmount(uint256 amount) external pure {
        CommonValidationLibrary.validatePositiveAmount(amount);
    }

    function validateMinAmount(uint256 amount, uint256 minAmount) external pure {
        CommonValidationLibrary.validateMinAmount(amount, minAmount);
    }

    function validateMaxAmount(uint256 amount, uint256 maxAmount) external pure {
        CommonValidationLibrary.validateMaxAmount(amount, maxAmount);
    }

    function validatePercentage(uint256 percentage, uint256 maxPercentage) external pure {
        CommonValidationLibrary.validatePercentage(percentage, maxPercentage);
    }

    function validateDuration(uint256 duration, uint256 minDuration, uint256 maxDuration) external pure {
        CommonValidationLibrary.validateDuration(duration, minDuration, maxDuration);
    }

    function validatePrice(uint256 price) external pure {
        CommonValidationLibrary.validatePrice(price);
    }

    function validateCondition(bool condition, string memory errorType) external pure {
        CommonValidationLibrary.validateCondition(condition, errorType);
    }

    function validateCountLimit(uint256 count, uint256 maxCount) external pure {
        CommonValidationLibrary.validateCountLimit(count, maxCount);
    }

    function validateSufficientBalance(uint256 balance, uint256 requiredAmount) external pure {
        CommonValidationLibrary.validateSufficientBalance(balance, requiredAmount);
    }

    function validateTreasuryAddress(address treasury) external pure {
        CommonValidationLibrary.validateTreasuryAddress(treasury);
    }

    function validateSlippage(uint256 received, uint256 expected, uint256 tolerance) external pure {
        CommonValidationLibrary.validateSlippage(received, expected, tolerance);
    }

    function validateThresholdValue(uint256 value, uint256 threshold) external pure {
        CommonValidationLibrary.validateThresholdValue(value, threshold);
    }

    function validateFee(uint256 fee, uint256 maxFee) external pure {
        CommonValidationLibrary.validateFee(fee, maxFee);
    }

    function validateThreshold(uint256 threshold, uint256 maxThreshold) external pure {
        CommonValidationLibrary.validateThreshold(threshold, maxThreshold);
    }
}
