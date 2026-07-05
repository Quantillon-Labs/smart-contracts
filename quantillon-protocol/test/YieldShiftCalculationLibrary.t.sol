// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {YieldShiftCalculationLibrary} from "../src/libraries/YieldShiftCalculationLibrary.sol";

/**
 * @title YieldShiftCalculationLibraryTest
 * @notice Comprehensive test suite for YieldShiftCalculationLibrary
 *
 * @dev This test suite covers:
 *      - Optimal yield shift calculations
 *      - Gradual adjustment mechanics
 *      - User/hedger allocation calculations
 *      - Pool TWAP calculations
 *      - Yield distribution calculations
 *      - Parameter validation
 *      - Edge cases and boundary conditions
 *
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract YieldShiftCalculationLibraryTest is Test {
    // =============================================================================
    // CONSTANTS
    // =============================================================================

    uint256 constant BASIS_POINTS = 10000;
    uint256 constant BASE_YIELD_SHIFT = 5000;  // 50%
    uint256 constant MAX_YIELD_SHIFT = 8000;   // 80%
    uint256 constant TARGET_POOL_RATIO = 10000; // 1:1

    // =============================================================================
    // OPTIMAL YIELD SHIFT TESTS
    // =============================================================================

    /**
     * @notice Test optimal shift with hedger pool at zero (edge case)
     */
    function test_CalculateOptimalYieldShift_HedgerPoolZero_ReturnsFloorShift() public pure {
        uint256 optimalShift = YieldShiftCalculationLibrary.calculateOptimalYieldShift(
            type(uint256).max, // poolRatio = max when hedger pool is zero
            BASE_YIELD_SHIFT,
            MAX_YIELD_SHIFT,
            TARGET_POOL_RATIO
        );

        // Audit SC2-2: user share is the fraction going to USERS; a zero hedger pool
        // (maximally under-hedged) must route the MOST to hedgers => user share at the floor.
        assertEq(optimalShift, 10000 - MAX_YIELD_SHIFT, "Zero hedger pool should return the floor user share");
    }

    /**
     * @notice Test optimal shift with user pool at zero (edge case)
     */
    function test_CalculateOptimalYieldShift_UserPoolZero_ReturnsMaxShift() public pure {
        uint256 optimalShift = YieldShiftCalculationLibrary.calculateOptimalYieldShift(
            0, // poolRatio = 0 when user pool is zero
            BASE_YIELD_SHIFT,
            MAX_YIELD_SHIFT,
            TARGET_POOL_RATIO
        );

        // Audit SC2-2: a zero user pool (maximally over-hedged) must route the MOST to users.
        assertEq(optimalShift, MAX_YIELD_SHIFT, "Zero user pool should return the max user share");
    }

    /**
     * @notice Test optimal shift at target ratio returns base shift
     */
    function test_CalculateOptimalYieldShift_AtTargetRatio_ReturnsBaseShift() public pure {
        uint256 optimalShift = YieldShiftCalculationLibrary.calculateOptimalYieldShift(
            TARGET_POOL_RATIO, // At target
            BASE_YIELD_SHIFT,
            MAX_YIELD_SHIFT,
            TARGET_POOL_RATIO
        );

        assertEq(optimalShift, BASE_YIELD_SHIFT, "At target ratio should return base shift");
    }

    /**
     * @notice Test optimal shift when user pool larger increases shift
     */
    function test_CalculateOptimalYieldShift_UserPoolLarger_LowersUserShare() public pure {
        uint256 optimalShift = YieldShiftCalculationLibrary.calculateOptimalYieldShift(
            15000, // User pool 1.5x hedger pool
            BASE_YIELD_SHIFT,
            MAX_YIELD_SHIFT,
            TARGET_POOL_RATIO
        );

        // Audit SC2-2: a larger user pool must shift more yield to hedgers => LOWER user share.
        assertLt(optimalShift, BASE_YIELD_SHIFT, "Larger user pool should lower the user share");
    }

    /**
     * @notice Test optimal shift when hedger pool larger decreases shift
     */
    function test_CalculateOptimalYieldShift_HedgerPoolLarger_RaisesUserShare() public pure {
        uint256 optimalShift = YieldShiftCalculationLibrary.calculateOptimalYieldShift(
            5000, // User pool 0.5x hedger pool
            BASE_YIELD_SHIFT,
            MAX_YIELD_SHIFT,
            TARGET_POOL_RATIO
        );

        // Audit SC2-2: a larger hedger pool must shift more yield to users => HIGHER user share.
        assertGt(optimalShift, BASE_YIELD_SHIFT, "Larger hedger pool should raise the user share");
    }

    /**
     * @notice Test optimal shift is clamped to max
     */
    function test_CalculateOptimalYieldShift_ClampsToMax() public pure {
        uint256 optimalShift = YieldShiftCalculationLibrary.calculateOptimalYieldShift(
            50000, // User pool 5x hedger pool - would push beyond max
            BASE_YIELD_SHIFT,
            MAX_YIELD_SHIFT,
            TARGET_POOL_RATIO
        );

        assertLe(optimalShift, MAX_YIELD_SHIFT, "Shift should be clamped to max");
    }

    // =============================================================================
    // GRADUAL ADJUSTMENT TESTS
    // =============================================================================

    /**
     * @notice Test gradual adjustment when at target returns same
     */
    function test_ApplyGradualAdjustment_AtTarget_ReturnsSame() public pure {
        uint256 currentShift = 5000;
        uint256 targetShift = 5000;

        uint256 newShift = YieldShiftCalculationLibrary.applyGradualAdjustment(
            currentShift,
            targetShift,
            1000 // 10% adjustment speed
        );

        assertEq(newShift, currentShift, "At target should return same shift");
    }

    /**
     * @notice Test gradual adjustment increases toward higher target
     */
    function test_ApplyGradualAdjustment_TowardHigherTarget_Increases() public pure {
        uint256 currentShift = 5000;
        uint256 targetShift = 6000;

        uint256 newShift = YieldShiftCalculationLibrary.applyGradualAdjustment(
            currentShift,
            targetShift,
            1000 // 10% adjustment speed
        );

        assertGt(newShift, currentShift, "Should increase toward higher target");
        assertLe(newShift, targetShift, "Should not exceed target");
    }

    /**
     * @notice Test gradual adjustment decreases toward lower target
     */
    function test_ApplyGradualAdjustment_TowardLowerTarget_Decreases() public pure {
        uint256 currentShift = 6000;
        uint256 targetShift = 5000;

        uint256 newShift = YieldShiftCalculationLibrary.applyGradualAdjustment(
            currentShift,
            targetShift,
            1000 // 10% adjustment speed
        );

        assertLt(newShift, currentShift, "Should decrease toward lower target");
        assertGe(newShift, targetShift, "Should not go below target");
    }

    /**
     * @notice Test gradual adjustment makes minimum adjustment of 1
     */
    function test_ApplyGradualAdjustment_MinimumAdjustment() public pure {
        uint256 currentShift = 5000;
        uint256 targetShift = 5001; // Very small difference

        uint256 newShift = YieldShiftCalculationLibrary.applyGradualAdjustment(
            currentShift,
            targetShift,
            1 // Very slow speed
        );

        assertEq(newShift, 5001, "Should adjust by at least 1");
    }

    /**
     * @notice Test gradual adjustment respects speed
     */
    function test_ApplyGradualAdjustment_RespectsSpeed() public pure {
        uint256 currentShift = 5000;
        uint256 targetShift = 7000;

        uint256 slowShift = YieldShiftCalculationLibrary.applyGradualAdjustment(
            currentShift,
            targetShift,
            1000 // 10% speed
        );

        uint256 fastShift = YieldShiftCalculationLibrary.applyGradualAdjustment(
            currentShift,
            targetShift,
            5000 // 50% speed
        );

        assertLt(slowShift, fastShift, "Faster speed should make larger adjustment");
    }

    // =============================================================================
    // FUZZ TESTS
    // =============================================================================

    /**
     * @notice Fuzz test optimal shift stays within bounds
     */
    function testFuzz_OptimalYieldShift_StaysInBounds(
        uint64 poolRatio,
        uint16 baseShift,
        uint16 maxShift
    ) public pure {
        vm.assume(poolRatio > 0);
        vm.assume(poolRatio < type(uint256).max);
        vm.assume(baseShift <= 10000);
        vm.assume(maxShift <= 10000);
        vm.assume(baseShift <= maxShift);
        // When poolRatio < targetPoolRatio the library does baseShift - (deviation*100)/targetPoolRatio; avoid underflow
        vm.assume(baseShift >= 100);

        uint256 optimalShift = YieldShiftCalculationLibrary.calculateOptimalYieldShift(
            uint256(poolRatio),
            uint256(baseShift),
            uint256(maxShift),
            10000
        );

        assertLe(optimalShift, 10000, "Shift should not exceed 100%");
    }

    /**
     * @notice Fuzz test gradual adjustment moves toward target
     */
    function testFuzz_GradualAdjustment_MovesTowardTarget(
        uint64 current,
        uint64 target,
        uint16 speed
    ) public pure {
        vm.assume(current != target);
        vm.assume(speed > 0);
        vm.assume(speed <= 10000);

        uint256 newShift = YieldShiftCalculationLibrary.applyGradualAdjustment(
            uint256(current),
            uint256(target),
            uint256(speed)
        );

        if (current < target) {
            assertGe(newShift, current, "Should move toward higher target");
            assertLe(newShift, target, "Should not exceed target");
        } else {
            assertLe(newShift, current, "Should move toward lower target");
            assertGe(newShift, target, "Should not go below target");
        }
    }
}
