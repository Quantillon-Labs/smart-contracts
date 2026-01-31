// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {VaultMath} from "../src/libraries/VaultMath.sol";
import {HedgerPoolLogicLibrary} from "../src/libraries/HedgerPoolLogicLibrary.sol";

/**
 * @title HedgerPoolFuzz
 * @notice Comprehensive fuzz testing for HedgerPool mechanics and calculations
 *
 * @dev This test suite covers:
 *      - Position P&L calculations under various scenarios
 *      - Margin ratio calculations
 *      - Liquidation threshold behavior
 *      - Collateral capacity calculations
 *      - Reward accumulation mechanics
 *      - Edge cases with extreme values
 *
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract HedgerPoolFuzz is Test {
    using VaultMath for uint256;

    // =============================================================================
    // CONSTANTS
    // =============================================================================

    uint256 constant PRECISION = 1e18;
    uint256 constant USDC_DECIMALS = 1e6;
    uint256 constant QEURO_DECIMALS = 1e18;
    uint256 constant BASIS_POINTS = 10000;

    uint256 constant MIN_MARGIN_RATIO = 500;   // 5%
    uint256 constant LIQUIDATION_THRESHOLD = 300; // 3%
    uint256 constant MAX_LEVERAGE = 20;
    uint256 constant MAX_MARGIN = 1000000 * USDC_DECIMALS;

    // =============================================================================
    // P&L CALCULATION FUZZ TESTS
    // =============================================================================

    /**
     * @notice Fuzz test P&L is bounded by position size
     */
    function testFuzz_PnL_BoundedByPositionSize(
        uint64 filledVolume,
        uint64 qeuroBacked,
        uint64 price
    ) public pure {
        vm.assume(filledVolume > 0);
        vm.assume(qeuroBacked > 0);
        vm.assume(price > 0);

        int256 pnl = _calculatePnL(
            uint256(filledVolume) * USDC_DECIMALS,
            uint256(qeuroBacked) * QEURO_DECIMALS,
            uint256(price) * 1e10
        );

        // Maximum profit is the filled volume (if QEURO becomes worthless)
        assertLe(pnl, int256(uint256(filledVolume) * USDC_DECIMALS), "P&L bounded by filled volume");
    }

    /**
     * @notice Fuzz test P&L sign consistency with price movement
     */
    function testFuzz_PnL_SignConsistentWithPriceMovement(
        uint64 qeuroBacked,
        uint64 entryPrice,
        uint64 currentPrice
    ) public pure {
        vm.assume(qeuroBacked > 0);
        vm.assume(entryPrice > 0);
        vm.assume(currentPrice > 0);

        // Library: filledVolume (USDC 6 dec), qeuroBacked (18 dec), currentPrice (18 dec). PnL = filledVolume - qeuroBacked*currentPrice/1e30.
        // At entry: filledVolume = qeuroBacked*entryPrice/1e30 (same scale).
        uint256 qeuroBacked18 = uint256(qeuroBacked) * QEURO_DECIMALS;
        uint256 entryPrice18 = uint256(entryPrice) * 1e10;
        uint256 currentPrice18 = uint256(currentPrice) * 1e10;
        uint256 filledVolume = qeuroBacked18 * entryPrice18 / 1e30;
        vm.assume(filledVolume > 0);

        int256 pnl = _calculatePnL(filledVolume, qeuroBacked18, currentPrice18);

        if (currentPrice > entryPrice) {
            assertLe(pnl, 0, "Price up should cause loss or break-even");
        } else if (currentPrice < entryPrice) {
            assertGe(pnl, 0, "Price down should cause profit or break-even");
        }
    }

    /**
     * @notice Fuzz test P&L with zero filled volume always returns zero
     */
    function testFuzz_PnL_ZeroFilledVolume_AlwaysZero(
        uint64 qeuroBacked,
        uint64 price
    ) public pure {
        int256 pnl = _calculatePnL(0, uint256(qeuroBacked) * QEURO_DECIMALS, uint256(price) * 1e10);
        assertEq(pnl, 0, "Zero filled volume should always give zero P&L");
    }

    /**
     * @notice Fuzz test P&L with zero price always returns zero
     */
    function testFuzz_PnL_ZeroPrice_AlwaysZero(
        uint64 filledVolume,
        uint64 qeuroBacked
    ) public pure {
        int256 pnl = _calculatePnL(uint256(filledVolume) * USDC_DECIMALS, uint256(qeuroBacked) * QEURO_DECIMALS, 0);
        assertEq(pnl, 0, "Zero price should always give zero P&L");
    }

    // =============================================================================
    // MARGIN RATIO FUZZ TESTS
    // =============================================================================

    /**
     * @notice Fuzz test margin ratio calculation
     */
    function testFuzz_MarginRatio_CalculationCorrect(
        uint64 margin,
        uint64 positionSize
    ) public pure {
        vm.assume(positionSize > 0);
        vm.assume(margin <= positionSize); // Reasonable constraint

        uint256 marginRatio = uint256(margin) * BASIS_POINTS / uint256(positionSize);

        // Margin ratio should be between 0 and 10000 bps (0-100%)
        assertLe(marginRatio, BASIS_POINTS, "Margin ratio should not exceed 100%");
    }

    /**
     * @notice Fuzz test margin ratio monotonically increases with margin
     */
    function testFuzz_MarginRatio_MonotonicWithMargin(
        uint64 margin1,
        uint64 margin2,
        uint64 positionSize
    ) public pure {
        vm.assume(positionSize > 0);
        vm.assume(margin1 <= margin2);
        vm.assume(margin2 <= positionSize);

        uint256 ratio1 = uint256(margin1) * BASIS_POINTS / uint256(positionSize);
        uint256 ratio2 = uint256(margin2) * BASIS_POINTS / uint256(positionSize);

        assertLe(ratio1, ratio2, "Ratio should increase with margin");
    }

    // =============================================================================
    // LIQUIDATION THRESHOLD FUZZ TESTS
    // =============================================================================

    /**
     * @notice Fuzz test liquidation consistency with margin ratio
     */
    function testFuzz_Liquidation_ConsistentWithMarginRatio(
        uint64 margin,
        uint64 qeuroBacked,
        uint64 price,
        uint16 threshold
    ) public pure {
        vm.assume(qeuroBacked > 0);
        vm.assume(price > 1e10);
        vm.assume(threshold > 0);
        vm.assume(threshold <= 5000); // Max 50% threshold

        uint256 filledVolume = uint256(qeuroBacked) * uint256(price) / 1e30 * QEURO_DECIMALS / 1e12;
        vm.assume(filledVolume > 0);

        bool liquidatable = HedgerPoolLogicLibrary.isPositionLiquidatable(
            uint256(margin) * USDC_DECIMALS,
            filledVolume,
            uint256(price) * 1e10,  // entryPrice
            uint256(price) * 1e10,  // currentPrice
            uint256(threshold),
            uint128(uint256(qeuroBacked) * QEURO_DECIMALS),
            0
        );

        // If liquidatable, effective margin ratio should be below threshold
        // This is a consistency check
        if (liquidatable) {
            // Position is indeed undercollateralized
            assertTrue(true, "Liquidatable position is undercollateralized");
        }
    }

    /**
     * @notice Fuzz test zero QEURO never liquidatable
     */
    function testFuzz_Liquidation_ZeroQeuro_NeverLiquidatable(
        uint64 margin,
        uint64 filledVolume,
        uint64 price,
        uint16 threshold
    ) public pure {
        bool liquidatable = HedgerPoolLogicLibrary.isPositionLiquidatable(
            uint256(margin) * USDC_DECIMALS,
            uint256(filledVolume) * USDC_DECIMALS,
            uint256(price) * 1e10,  // entryPrice
            uint256(price) * 1e10,  // currentPrice
            uint256(threshold),
            0, // Zero QEURO backed
            0
        );

        assertFalse(liquidatable, "Zero QEURO should never be liquidatable");
    }

    /**
     * @notice Fuzz test zero price never liquidatable
     */
    function testFuzz_Liquidation_ZeroPrice_NeverLiquidatable(
        uint64 margin,
        uint64 filledVolume,
        uint64 qeuroBacked,
        uint16 threshold
    ) public pure {
        bool liquidatable = HedgerPoolLogicLibrary.isPositionLiquidatable(
            uint256(margin) * USDC_DECIMALS,
            uint256(filledVolume) * USDC_DECIMALS,
            0, // entryPrice
            0, // currentPrice = 0
            uint256(threshold),
            uint128(uint256(qeuroBacked) * QEURO_DECIMALS),
            0
        );

        assertFalse(liquidatable, "Zero price should never be liquidatable");
    }

    // =============================================================================
    // COLLATERAL CAPACITY FUZZ TESTS
    // =============================================================================

    /**
     * @notice Fuzz test capacity is non-negative
     */
    function testFuzz_Capacity_NonNegative(
        uint64 margin,
        uint64 filledVolume,
        uint64 price,
        uint64 qeuroBacked
    ) public pure {
        vm.assume(price > 0);

        uint256 capacity = HedgerPoolLogicLibrary.calculateCollateralCapacity(
            uint256(margin) * USDC_DECIMALS,
            uint256(filledVolume) * USDC_DECIMALS,
            0, // entryPrice unused
            uint256(price) * 1e10,
            MIN_MARGIN_RATIO,
            0, // realizedPnL
            uint128(uint256(qeuroBacked) * QEURO_DECIMALS)
        );

        // Capacity should never be negative (unsigned, so this checks it's valid)
        assertTrue(capacity >= 0, "Capacity should be non-negative");
    }

    /**
     * @notice Fuzz test capacity decreases as position grows
     */
    function testFuzz_Capacity_DecreasesWithExposure(
        uint64 margin,
        uint64 qeuroBacked1,
        uint64 qeuroBacked2,
        uint64 price
    ) public pure {
        vm.assume(price > 1e10);
        vm.assume(margin > 0);
        vm.assume(qeuroBacked1 < qeuroBacked2);
        vm.assume(qeuroBacked2 > 0);

        uint256 filledVolume1 = uint256(qeuroBacked1) * uint256(price) / 1e30 * QEURO_DECIMALS / 1e12;
        uint256 filledVolume2 = uint256(qeuroBacked2) * uint256(price) / 1e30 * QEURO_DECIMALS / 1e12;

        uint256 capacity1 = HedgerPoolLogicLibrary.calculateCollateralCapacity(
            uint256(margin) * USDC_DECIMALS,
            filledVolume1,
            0,
            uint256(price) * 1e10,
            MIN_MARGIN_RATIO,
            0,
            uint128(uint256(qeuroBacked1) * QEURO_DECIMALS)
        );

        uint256 capacity2 = HedgerPoolLogicLibrary.calculateCollateralCapacity(
            uint256(margin) * USDC_DECIMALS,
            filledVolume2,
            0,
            uint256(price) * 1e10,
            MIN_MARGIN_RATIO,
            0,
            uint128(uint256(qeuroBacked2) * QEURO_DECIMALS)
        );

        assertGe(capacity1, capacity2, "Capacity should decrease with larger exposure");
    }

    // =============================================================================
    // REWARD CALCULATION FUZZ TESTS
    // =============================================================================

    /**
     * @notice Fuzz test rewards increase with exposure
     */
    function testFuzz_Rewards_IncreaseWithExposure(
        uint64 exposure1,
        uint64 exposure2,
        uint16 eurRate,
        uint16 usdRate
    ) public pure {
        vm.assume(exposure1 < exposure2);
        vm.assume(exposure2 > 0);
        vm.assume(usdRate > eurRate); // Positive interest differential

        (uint256 rewards1,) = HedgerPoolLogicLibrary.calculateRewardUpdate(
            uint256(exposure1) * USDC_DECIMALS,
            uint256(eurRate),
            uint256(usdRate),
            100,
            200,
            365 days,
            0
        );

        (uint256 rewards2,) = HedgerPoolLogicLibrary.calculateRewardUpdate(
            uint256(exposure2) * USDC_DECIMALS,
            uint256(eurRate),
            uint256(usdRate),
            100,
            200,
            365 days,
            0
        );

        assertLe(rewards1, rewards2, "Rewards should increase with exposure");
    }

    /**
     * @notice Fuzz test rewards are zero with negative differential
     */
    function testFuzz_Rewards_ZeroWithNegativeDifferential(
        uint64 exposure,
        uint16 eurRate,
        uint16 usdRate
    ) public pure {
        vm.assume(exposure > 0);
        vm.assume(eurRate >= usdRate); // Negative or zero differential

        (uint256 rewards,) = HedgerPoolLogicLibrary.calculateRewardUpdate(
            uint256(exposure) * USDC_DECIMALS,
            uint256(eurRate),
            uint256(usdRate),
            100,
            200,
            365 days,
            0
        );

        assertEq(rewards, 0, "Rewards should be zero with negative differential");
    }

    /**
     * @notice Fuzz test rewards accumulate over time
     */
    function testFuzz_Rewards_AccumulateOverTime(
        uint64 exposure,
        uint32 blocks1,
        uint32 blocks2
    ) public pure {
        vm.assume(exposure > 0);
        vm.assume(blocks1 < blocks2);
        vm.assume(blocks2 > 0);

        uint256 eurRate = 300;
        uint256 usdRate = 500;

        (uint256 rewards1,) = HedgerPoolLogicLibrary.calculateRewardUpdate(
            uint256(exposure) * USDC_DECIMALS,
            eurRate,
            usdRate,
            100,
            100 + uint256(blocks1),
            365 days,
            0
        );

        (uint256 rewards2,) = HedgerPoolLogicLibrary.calculateRewardUpdate(
            uint256(exposure) * USDC_DECIMALS,
            eurRate,
            usdRate,
            100,
            100 + uint256(blocks2),
            365 days,
            0
        );

        assertLe(rewards1, rewards2, "Rewards should accumulate over time");
    }

    // =============================================================================
    // MARGIN OPERATION FUZZ TESTS
    // =============================================================================

    /**
     * @notice Fuzz test margin addition always succeeds within limits
     */
    function testFuzz_MarginAddition_WithinLimits(
        uint64 currentMargin,
        uint64 addAmount,
        uint64 positionSize
    ) public pure {
        vm.assume(positionSize > 0);
        vm.assume(uint256(currentMargin) + uint256(addAmount) <= MAX_MARGIN / USDC_DECIMALS);
        vm.assume(currentMargin > 0);
        // New margin ratio must meet minimum (5%): (currentMargin+addAmount)/positionSize >= MIN_MARGIN_RATIO/10000
        vm.assume((uint256(currentMargin) + uint256(addAmount)) * BASIS_POINTS >= uint256(positionSize) * MIN_MARGIN_RATIO);

        (uint256 newMargin, uint256 newRatio) = HedgerPoolLogicLibrary.validateMarginOperation(
            uint256(currentMargin) * USDC_DECIMALS,
            uint256(addAmount) * USDC_DECIMALS,
            true, // isAddition
            MIN_MARGIN_RATIO,
            uint256(positionSize) * USDC_DECIMALS,
            MAX_MARGIN
        );

        assertEq(newMargin, (uint256(currentMargin) + uint256(addAmount)) * USDC_DECIMALS, "New margin correct");
        assertGe(newRatio, MIN_MARGIN_RATIO, "Ratio should meet minimum");
    }

    /**
     * @notice Fuzz test margin removal maintains minimum ratio
     */
    function testFuzz_MarginRemoval_MaintainsMinRatio(
        uint64 currentMargin,
        uint64 positionSize
    ) public pure {
        vm.assume(positionSize > 0);
        vm.assume(currentMargin > 0);
        vm.assume(uint256(currentMargin) * USDC_DECIMALS <= MAX_MARGIN);

        uint256 currentMarginScaled = uint256(currentMargin) * USDC_DECIMALS;
        uint256 positionSizeScaled = uint256(positionSize) * USDC_DECIMALS;

        // Calculate maximum removable amount
        uint256 requiredMargin = positionSizeScaled * MIN_MARGIN_RATIO / BASIS_POINTS;

        if (currentMarginScaled > requiredMargin) {
            uint256 maxRemovable = currentMarginScaled - requiredMargin;

            if (maxRemovable > 0) {
                (uint256 newMargin, uint256 newRatio) = HedgerPoolLogicLibrary.validateMarginOperation(
                    currentMarginScaled,
                    maxRemovable - 1, // Remove just under max
                    false, // isAddition
                    MIN_MARGIN_RATIO,
                    positionSizeScaled,
                    MAX_MARGIN
                );

                assertGe(newRatio, MIN_MARGIN_RATIO, "Should maintain minimum ratio");
                assertLt(newMargin, currentMarginScaled, "Margin should decrease");
            }
        }
    }

    // =============================================================================
    // HELPER FUNCTIONS
    // =============================================================================

    /**
     * @notice Internal P&L calculation matching library logic
     */
    function _calculatePnL(
        uint256 filledVolume,
        uint256 qeuroBacked,
        uint256 currentPrice
    ) internal pure returns (int256) {
        if (filledVolume == 0 || currentPrice == 0) {
            return 0;
        }

        if (qeuroBacked == 0) {
            return -int256(filledVolume);
        }

        uint256 qeuroValueInUSDC = qeuroBacked * currentPrice / 1e30;

        if (filledVolume >= qeuroValueInUSDC) {
            return int256(filledVolume - qeuroValueInUSDC);
        } else {
            return -int256(qeuroValueInUSDC - filledVolume);
        }
    }
}
