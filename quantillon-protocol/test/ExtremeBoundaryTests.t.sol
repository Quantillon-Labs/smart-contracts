// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {VaultMath} from "../src/libraries/VaultMath.sol";
import {QTITokenGovernanceLibrary} from "../src/libraries/QTITokenGovernanceLibrary.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";

/**
 * @title ExtremeBoundaryTests
 * @notice Comprehensive boundary and edge case testing for Quantillon Protocol
 *
 * @dev This test suite covers:
 *      - Maximum uint256 value handling
 *      - Minimum value thresholds
 *      - Timestamp overflow scenarios (year 2106 for uint32)
 *      - Extreme decimal precision scenarios
 *      - Division edge cases
 *      - Overflow prevention mechanisms
 *      - Rounding behavior at boundaries
 *
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract ExtremeBoundaryTests is Test {
    using VaultMath for uint256;

    // =============================================================================
    // CONSTANTS
    // =============================================================================

    uint256 constant PRECISION = 1e18;
    uint256 constant BASIS_POINTS = 10000;
    uint256 constant MAX_UINT256 = type(uint256).max;
    uint256 constant MAX_UINT128 = type(uint128).max;
    uint256 constant MAX_UINT96 = type(uint96).max;
    uint256 constant MAX_UINT64 = type(uint64).max;
    uint256 constant MAX_UINT32 = type(uint32).max;

    // Year 2106 timestamp (uint32 overflow point)
    uint256 constant YEAR_2106_TIMESTAMP = 4294967295; // 2^32 - 1

    // =============================================================================
    // UINT256 MAX VALUE TESTS
    // =============================================================================

    /**
     * @notice Test mulDiv with maximum values handles correctly
     */
    function test_MulDiv_MaxValues_HandlesCorrectly() public pure {
        // Large but not overflow-causing values
        uint256 largeA = MAX_UINT128;
        uint256 largeB = 1000;
        uint256 largeC = 1000;

        uint256 result = VaultMath.mulDiv(largeA, largeB, largeC);

        // Should equal approximately largeA
        assertApproxEqAbs(result, largeA, 2, "Large value multiplication should work");
    }

    /**
     * @notice Test percentageOf with maximum percentage
     */
    function test_PercentageOf_MaxPercentage() public pure {
        uint256 value = 1000000e18;
        uint256 maxBps = 10000; // 100%

        uint256 result = VaultMath.percentageOf(value, maxBps);

        // 100% should return approximately the original value
        assertApproxEqAbs(result, value, 2, "100% should return value");
    }

    /**
     * @notice Test percentageOf with zero value
     */
    function test_PercentageOf_ZeroValue() public pure {
        uint256 result = VaultMath.percentageOf(0, 5000);
        assertEq(result, 0, "Zero value should return zero");
    }

    /**
     * @notice Test percentageOf with zero percentage
     */
    function test_PercentageOf_ZeroPercentage() public pure {
        uint256 result = VaultMath.percentageOf(1000000e18, 0);
        assertEq(result, 0, "Zero percentage should return zero");
    }

    // =============================================================================
    // TIMESTAMP BOUNDARY TESTS (YEAR 2106)
    // =============================================================================

    /**
     * @notice Test unlock time calculation near uint32 max
     */
    function test_UnlockTime_NearUint32Max_Reverts() public {
        uint256 currentTime = MAX_UINT32 - 1 days;
        uint256 lockTime = 30 days; // Would overflow uint32

        vm.expectRevert(CommonErrorLibrary.InvalidTime.selector);
        QTITokenGovernanceLibrary.calculateUnlockTime(currentTime, lockTime, 0);
    }

    /**
     * @notice Test unlock time calculation well before uint32 max
     */
    function test_UnlockTime_WellBeforeUint32Max_Works() public {
        uint256 currentTime = MAX_UINT32 - 365 days;
        uint256 lockTime = 30 days;

        uint256 unlockTime = QTITokenGovernanceLibrary.calculateUnlockTime(
            currentTime,
            lockTime,
            0
        );

        assertEq(unlockTime, currentTime + lockTime, "Should calculate correctly");
    }

    /**
     * @notice Test timestamp at exactly year 2106
     */
    function test_Timestamp_AtYear2106() public {
        // Set block timestamp to year 2106
        vm.warp(YEAR_2106_TIMESTAMP - 1000);

        // This should still work as currentTime fits in uint32
        uint256 lockTime = 100; // Very small lock to avoid overflow

        uint256 unlockTime = QTITokenGovernanceLibrary.calculateUnlockTime(
            block.timestamp,
            lockTime,
            0
        );

        assertEq(unlockTime, block.timestamp + lockTime, "Should work at year 2106");
    }

    // =============================================================================
    // EXTREME DECIMAL PRECISION TESTS
    // =============================================================================

    /**
     * @notice Test scaleDecimals with identical decimals
     */
    function test_ScaleDecimals_IdenticalDecimals() public pure {
        uint256 value = 1000000;

        assertEq(VaultMath.scaleDecimals(value, 6, 6), value, "Same decimals unchanged");
        assertEq(VaultMath.scaleDecimals(value, 18, 18), value, "Same decimals unchanged");
    }

    /**
     * @notice Test scaleDecimals from 6 to 18 decimals
     */
    function test_ScaleDecimals_6To18() public pure {
        uint256 value = 1000000; // 1.0 in 6 decimals

        uint256 scaled = VaultMath.scaleDecimals(value, 6, 18);

        assertEq(scaled, 1e18, "Should scale correctly from 6 to 18");
    }

    /**
     * @notice Test scaleDecimals from 18 to 6 decimals with rounding
     */
    function test_ScaleDecimals_18To6_Rounding() public pure {
        uint256 value = 1e18; // 1.0 in 18 decimals

        uint256 scaled = VaultMath.scaleDecimals(value, 18, 6);

        assertEq(scaled, 1e6, "Should scale correctly from 18 to 6");
    }

    /**
     * @notice Test scaleDecimals with very small value
     */
    function test_ScaleDecimals_VerySmallValue() public pure {
        uint256 value = 1; // Smallest possible

        // Scaling up
        uint256 scaledUp = VaultMath.scaleDecimals(value, 6, 18);
        assertEq(scaledUp, 1e12, "Small value should scale up");

        // Scaling down - may round to zero
        uint256 scaledDown = VaultMath.scaleDecimals(value, 18, 6);
        assertEq(scaledDown, 0, "Very small value rounds to zero when scaling down");
    }

    /**
     * @notice Test scaleDecimals with maximum safe value
     */
    function test_ScaleDecimals_MaxSafeValue() public pure {
        // Max value that can be scaled from 6 to 18 without overflow
        uint256 maxSafe = MAX_UINT256 / 1e12;

        uint256 scaled = VaultMath.scaleDecimals(maxSafe, 6, 18);

        assertEq(scaled, maxSafe * 1e12, "Max safe value should scale correctly");
    }

    // =============================================================================
    // DIVISION EDGE CASE TESTS
    // =============================================================================

    /**
     * @notice Test collateral ratio with zero debt returns max
     */
    function test_CollateralRatio_ZeroDebt_ReturnsMax() public pure {
        uint256 ratio = VaultMath.calculateCollateralRatio(1000e18, 0);
        assertEq(ratio, MAX_UINT256, "Zero debt should return max ratio");
    }

    /**
     * @notice Test collateral ratio with zero collateral returns zero
     */
    function test_CollateralRatio_ZeroCollateral_ReturnsZero() public pure {
        uint256 ratio = VaultMath.calculateCollateralRatio(0, 1000e18);
        assertEq(ratio, 0, "Zero collateral should return zero ratio");
    }

    /**
     * @notice Test min function with equal values
     */
    function test_Min_EqualValues() public pure {
        uint256 value = 1000e18;
        assertEq(VaultMath.min(value, value), value, "Min of equal values");
    }

    /**
     * @notice Test min function with max uint256
     */
    function test_Min_WithMaxUint256() public pure {
        assertEq(VaultMath.min(MAX_UINT256, 1), 1, "Min with max should return smaller");
        assertEq(VaultMath.min(1, MAX_UINT256), 1, "Min with max should return smaller");
    }

    /**
     * @notice Test max function with zero
     */
    function test_Max_WithZero() public pure {
        assertEq(VaultMath.max(0, 1000), 1000, "Max with zero");
        assertEq(VaultMath.max(1000, 0), 1000, "Max with zero");
    }

    // =============================================================================
    // OVERFLOW PREVENTION TESTS
    // =============================================================================

    /**
     * @notice Test voting power calculation overflow protection
     */
    function test_VotingPower_OverflowProtection() public {
        // Amount that would overflow uint96 when multiplied by 4
        uint256 largeAmount = uint256(MAX_UINT96) / 2;

        vm.expectRevert(CommonErrorLibrary.InvalidAmount.selector);
        QTITokenGovernanceLibrary.calculateVotingPower(
            largeAmount,
            365 days // Max lock = 4x multiplier
        );
    }

    /**
     * @notice Test voting power with safe large amount
     */
    function test_VotingPower_SafeLargeAmount() public pure {
        // Amount that fits in uint96 even with 4x multiplier
        uint256 safeAmount = uint256(MAX_UINT96) / 5;

        uint256 power = QTITokenGovernanceLibrary.calculateVotingPower(safeAmount, 365 days);

        assertLe(power, MAX_UINT96, "Power should fit in uint96");
        assertEq(power, safeAmount * 4, "Should be 4x with max lock");
    }

    /**
     * @notice Test update lock info amount overflow
     */
    function test_UpdateLockInfo_AmountOverflow() public {
        uint256 largeAmount = uint256(MAX_UINT96) + 1;

        vm.expectRevert(CommonErrorLibrary.InvalidAmount.selector);
        QTITokenGovernanceLibrary.updateLockInfo(
            largeAmount,
            block.timestamp + 30 days,
            1000e18,
            30 days
        );
    }

    // =============================================================================
    // ROUNDING BEHAVIOR TESTS
    // =============================================================================

    /**
     * @notice Test mulDiv rounding behavior
     */
    function test_MulDiv_RoundingBehavior() public pure {
        // Test cases where rounding matters
        uint256 result1 = VaultMath.mulDiv(10, 3, 10); // 30/10 = 3
        assertEq(result1, 3, "Exact division");

        uint256 result2 = VaultMath.mulDiv(10, 3, 7); // 30/7 = 4.28... (rounds)
        assertTrue(result2 >= 4 && result2 <= 5, "Rounded division");
    }

    /**
     * @notice Test yield distribution rounding preserves total
     */
    function test_YieldDistribution_RoundingPreservesTotal() public pure {
        uint256 totalYield = 1000000e18; // 1M
        uint256 userShift = 6000; // 60%

        (uint256 userYield, uint256 hedgerYield) =
            VaultMath.calculateYieldDistribution(totalYield, userShift);

        // Total should be preserved within rounding
        uint256 total = userYield + hedgerYield;
        assertApproxEqAbs(total, totalYield, 2, "Total should be preserved");
    }

    /**
     * @notice Test isWithinTolerance at exact boundary
     */
    function test_IsWithinTolerance_ExactBoundary() public pure {
        uint256 expected = 1000e18;
        uint256 tolerance = 100; // 1%

        // At exactly 1% below
        uint256 atBoundary = expected * 99 / 100;
        assertTrue(VaultMath.isWithinTolerance(atBoundary, expected, tolerance), "At boundary");

        // Just below boundary
        uint256 belowBoundary = expected * 98 / 100;
        assertFalse(VaultMath.isWithinTolerance(belowBoundary, expected, tolerance), "Below boundary");
    }

    // =============================================================================
    // CURRENCY CONVERSION BOUNDARY TESTS
    // =============================================================================

    /**
     * @notice Test EUR to USD with extreme exchange rate
     */
    function test_EurToUsd_ExtremeRate() public pure {
        uint256 eurAmount = 1000e18;

        // Very high EUR/USD rate (2.0)
        uint256 highRate = 2e18;
        uint256 highResult = VaultMath.eurToUsd(eurAmount, highRate);
        assertApproxEqAbs(highResult, 2000e18, 2, "High rate conversion");

        // Very low EUR/USD rate (0.5)
        uint256 lowRate = 5e17;
        uint256 lowResult = VaultMath.eurToUsd(eurAmount, lowRate);
        assertApproxEqAbs(lowResult, 500e18, 2, "Low rate conversion");
    }

    /**
     * @notice Test USD to EUR with extreme exchange rate
     */
    function test_UsdToEur_ExtremeRate() public pure {
        uint256 usdAmount = 1000e18;

        // Very high EUR/USD rate (2.0) means USD buys less EUR
        uint256 highRate = 2e18;
        uint256 highResult = VaultMath.usdToEur(usdAmount, highRate);
        assertApproxEqAbs(highResult, 500e18, 2, "High rate conversion");

        // Very low EUR/USD rate (0.5) means USD buys more EUR
        uint256 lowRate = 5e17;
        uint256 lowResult = VaultMath.usdToEur(usdAmount, lowRate);
        assertApproxEqAbs(lowResult, 2000e18, 2, "Low rate conversion");
    }

    // =============================================================================
    // BATCH SIZE BOUNDARY TESTS
    // =============================================================================

    /**
     * @notice Test validate total amount with empty arrays
     */
    function test_ValidateTotal_EmptyArrays() public pure {
        uint256[] memory amounts = new uint256[](0);
        uint256[] memory lockTimes = new uint256[](0);

        uint256 total = QTITokenGovernanceLibrary.validateAndCalculateTotalAmount(
            amounts,
            lockTimes
        );

        assertEq(total, 0, "Empty arrays should return zero");
    }

    /**
     * @notice Test validate total amount with single element
     */
    function test_ValidateTotal_SingleElement() public pure {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000e18;

        uint256[] memory lockTimes = new uint256[](1);
        lockTimes[0] = 30 days;

        uint256 total = QTITokenGovernanceLibrary.validateAndCalculateTotalAmount(
            amounts,
            lockTimes
        );

        assertEq(total, 1000e18, "Single element should return that amount");
    }

    // =============================================================================
    // GAS EFFICIENT BOUNDARY CHECKS
    // =============================================================================

    /**
     * @notice Test repeated min operations gas efficiency
     */
    function test_Min_GasEfficiency() public pure {
        // This should not consume excessive gas
        uint256 result = VaultMath.min(1000, 2000);
        for (uint256 i = 0; i < 100; i++) {
            result = VaultMath.min(result, i);
        }
        assertEq(result, 0, "Final min should be 0");
    }

    /**
     * @notice Test repeated max operations gas efficiency
     */
    function test_Max_GasEfficiency() public pure {
        uint256 result = VaultMath.max(0, 1);
        for (uint256 i = 0; i < 100; i++) {
            result = VaultMath.max(result, i);
        }
        assertEq(result, 99, "Final max should be 99");
    }
}
