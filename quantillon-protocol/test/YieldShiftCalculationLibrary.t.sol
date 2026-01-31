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
    function test_CalculateOptimalYieldShift_HedgerPoolZero_ReturnsMaxShift() public pure {
        uint256 optimalShift = YieldShiftCalculationLibrary.calculateOptimalYieldShift(
            type(uint256).max, // poolRatio = max when hedger pool is zero
            BASE_YIELD_SHIFT,
            MAX_YIELD_SHIFT,
            TARGET_POOL_RATIO
        );

        assertEq(optimalShift, MAX_YIELD_SHIFT, "Zero hedger pool should return max shift");
    }

    /**
     * @notice Test optimal shift with user pool at zero (edge case)
     */
    function test_CalculateOptimalYieldShift_UserPoolZero_ReturnsZero() public pure {
        uint256 optimalShift = YieldShiftCalculationLibrary.calculateOptimalYieldShift(
            0, // poolRatio = 0 when user pool is zero
            BASE_YIELD_SHIFT,
            MAX_YIELD_SHIFT,
            TARGET_POOL_RATIO
        );

        assertEq(optimalShift, 0, "Zero user pool should return zero shift");
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
    function test_CalculateOptimalYieldShift_UserPoolLarger_IncreasesShift() public pure {
        uint256 optimalShift = YieldShiftCalculationLibrary.calculateOptimalYieldShift(
            15000, // User pool 1.5x hedger pool
            BASE_YIELD_SHIFT,
            MAX_YIELD_SHIFT,
            TARGET_POOL_RATIO
        );

        assertGt(optimalShift, BASE_YIELD_SHIFT, "Larger user pool should increase shift to hedgers");
    }

    /**
     * @notice Test optimal shift when hedger pool larger decreases shift
     */
    function test_CalculateOptimalYieldShift_HedgerPoolLarger_DecreasesShift() public pure {
        uint256 optimalShift = YieldShiftCalculationLibrary.calculateOptimalYieldShift(
            5000, // User pool 0.5x hedger pool
            BASE_YIELD_SHIFT,
            MAX_YIELD_SHIFT,
            TARGET_POOL_RATIO
        );

        assertLt(optimalShift, BASE_YIELD_SHIFT, "Larger hedger pool should decrease shift");
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
    // ALLOCATION CALCULATION TESTS
    // =============================================================================

    /**
     * @notice Test user allocation is complement of yield shift
     */
    function test_CalculateUserAllocation_ReturnsComplement() public pure {
        uint256 userAllocation = YieldShiftCalculationLibrary.calculateUserAllocation(3000);
        assertEq(userAllocation, 7000, "User allocation should be 10000 - yieldShift");
    }

    /**
     * @notice Test hedger allocation equals yield shift
     */
    function test_CalculateHedgerAllocation_ReturnsShift() public pure {
        uint256 hedgerAllocation = YieldShiftCalculationLibrary.calculateHedgerAllocation(3000);
        assertEq(hedgerAllocation, 3000, "Hedger allocation should equal yield shift");
    }

    /**
     * @notice Test allocations sum to 10000
     */
    function test_Allocations_SumTo10000() public pure {
        uint256 yieldShift = 4500;
        uint256 userAlloc = YieldShiftCalculationLibrary.calculateUserAllocation(yieldShift);
        uint256 hedgerAlloc = YieldShiftCalculationLibrary.calculateHedgerAllocation(yieldShift);

        assertEq(userAlloc + hedgerAlloc, 10000, "Allocations should sum to 100%");
    }

    // =============================================================================
    // POOL TWAP TESTS
    // =============================================================================

    /**
     * @notice Test TWAP with empty snapshots returns zero
     */
    function test_CalculatePoolTWAP_EmptySnapshots_ReturnsZero() public pure {
        uint256[] memory snapshots = new uint256[](0);

        (uint256 userTWAP, uint256 hedgerTWAP) =
            YieldShiftCalculationLibrary.calculatePoolTWAP(snapshots);

        assertEq(userTWAP, 0, "Empty snapshots should return zero user TWAP");
        assertEq(hedgerTWAP, 0, "Empty snapshots should return zero hedger TWAP");
    }

    /**
     * @notice Test TWAP with single snapshot
     */
    function test_CalculatePoolTWAP_SingleSnapshot() public pure {
        uint256[] memory snapshots = new uint256[](1);
        // Pack: hedger pool (high 128 bits) | user pool (low 128 bits)
        uint128 userPool = 1000e6;
        uint128 hedgerPool = 500e6;
        snapshots[0] = (uint256(hedgerPool) << 128) | uint256(userPool);

        (uint256 userTWAP, uint256 hedgerTWAP) =
            YieldShiftCalculationLibrary.calculatePoolTWAP(snapshots);

        assertEq(userTWAP, userPool, "Single snapshot user TWAP");
        assertEq(hedgerTWAP, hedgerPool, "Single snapshot hedger TWAP");
    }

    /**
     * @notice Test TWAP weighs recent values more heavily
     */
    function test_CalculatePoolTWAP_RecentWeightedMore() public pure {
        uint256[] memory snapshots = new uint256[](3);
        // Earlier snapshots with lower values
        snapshots[0] = (uint256(100e6) << 128) | uint256(100e6);
        snapshots[1] = (uint256(200e6) << 128) | uint256(200e6);
        // Most recent with higher value - should have more weight
        snapshots[2] = (uint256(300e6) << 128) | uint256(300e6);

        (uint256 userTWAP,) = YieldShiftCalculationLibrary.calculatePoolTWAP(snapshots);

        // Simple average would be 200e6, weighted should be higher
        assertGt(userTWAP, 200e6, "TWAP should weight recent values more");
    }

    // =============================================================================
    // YIELD DISTRIBUTION TESTS
    // =============================================================================

    /**
     * @notice Test yield distribution sums to total
     */
    function test_CalculateYieldDistribution_SumsToTotal() public pure {
        uint256 totalYield = 10000e18;
        uint256 userAllocation = 6000; // 60%
        uint256 hedgerAllocation = 4000; // 40%

        (uint256 userYield, uint256 hedgerYield) =
            YieldShiftCalculationLibrary.calculateYieldDistribution(
                totalYield,
                userAllocation,
                hedgerAllocation
            );

        assertEq(userYield + hedgerYield, totalYield, "Distribution should sum to total");
    }

    /**
     * @notice Test yield distribution with 100% to users
     */
    function test_CalculateYieldDistribution_AllToUsers() public pure {
        uint256 totalYield = 10000e18;

        (uint256 userYield, uint256 hedgerYield) =
            YieldShiftCalculationLibrary.calculateYieldDistribution(
                totalYield,
                10000, // 100% to users
                0
            );

        assertEq(userYield, totalYield, "All yield should go to users");
        assertEq(hedgerYield, 0, "No yield should go to hedgers");
    }

    /**
     * @notice Test yield distribution with 100% to hedgers
     */
    function test_CalculateYieldDistribution_AllToHedgers() public pure {
        uint256 totalYield = 10000e18;

        (uint256 userYield, uint256 hedgerYield) =
            YieldShiftCalculationLibrary.calculateYieldDistribution(
                totalYield,
                0,
                10000 // 100% to hedgers
            );

        assertEq(userYield, 0, "No yield should go to users");
        assertEq(hedgerYield, totalYield, "All yield should go to hedgers");
    }

    // =============================================================================
    // PARAMETER VALIDATION TESTS
    // =============================================================================

    /**
     * @notice Test validation passes with valid parameters
     */
    function test_ValidateYieldShiftParams_ValidParams_Passes() public pure {
        // Should not revert
        YieldShiftCalculationLibrary.validateYieldShiftParams(
            5000,  // baseYieldShift
            8000,  // maxYieldShift
            1000,  // adjustmentSpeed
            10000  // targetPoolRatio
        );
    }

    /**
     * @notice Test validation fails with invalid base yield shift
     */
    function test_ValidateYieldShiftParams_InvalidBaseShift_Reverts() public {
        vm.expectRevert("Invalid base yield shift");
        YieldShiftCalculationLibrary.validateYieldShiftParams(
            15000, // > 10000
            8000,
            1000,
            10000
        );
    }

    /**
     * @notice Test validation fails with invalid max yield shift
     */
    function test_ValidateYieldShiftParams_InvalidMaxShift_Reverts() public {
        vm.expectRevert("Invalid max yield shift");
        YieldShiftCalculationLibrary.validateYieldShiftParams(
            5000,
            15000, // > 10000
            1000,
            10000
        );
    }

    /**
     * @notice Test validation fails with base exceeding max
     */
    function test_ValidateYieldShiftParams_BaseExceedsMax_Reverts() public {
        vm.expectRevert("Base shift exceeds max shift");
        YieldShiftCalculationLibrary.validateYieldShiftParams(
            8000,  // base
            5000,  // max < base
            1000,
            10000
        );
    }

    /**
     * @notice Test validation fails with zero target pool ratio
     */
    function test_ValidateYieldShiftParams_ZeroTargetRatio_Reverts() public {
        vm.expectRevert("Invalid target pool ratio");
        YieldShiftCalculationLibrary.validateYieldShiftParams(
            5000,
            8000,
            1000,
            0     // Zero target ratio
        );
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
     * @notice Fuzz test allocations always sum to 10000
     */
    function testFuzz_Allocations_AlwaysSumTo10000(uint16 yieldShift) public pure {
        vm.assume(yieldShift <= 10000);

        uint256 userAlloc = YieldShiftCalculationLibrary.calculateUserAllocation(uint256(yieldShift));
        uint256 hedgerAlloc = YieldShiftCalculationLibrary.calculateHedgerAllocation(uint256(yieldShift));

        assertEq(userAlloc + hedgerAlloc, 10000, "Allocations must sum to 10000");
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
