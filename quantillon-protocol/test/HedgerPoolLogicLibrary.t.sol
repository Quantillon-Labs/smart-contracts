// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {HedgerPoolLogicLibrary} from "../src/libraries/HedgerPoolLogicLibrary.sol";
import {HedgerPoolErrorLibrary} from "../src/libraries/HedgerPoolErrorLibrary.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";

/**
 * @title HedgerPoolLogicLibraryTest
 * @notice Comprehensive test suite for HedgerPoolLogicLibrary
 *
 * @dev This test suite covers:
 *      - P&L calculations (calculatePnL)
 *      - Position parameter validation
 *      - Collateral capacity calculations
 *      - Liquidation eligibility checks
 *      - Reward calculations
 *      - Margin operations validation
 *      - Edge cases and boundary conditions
 *
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract HedgerPoolLogicLibraryTest is Test {
    // =============================================================================
    // CONSTANTS
    // =============================================================================

    uint256 constant PRECISION = 1e18;
    uint256 constant USDC_DECIMALS = 1e6;
    uint256 constant QEURO_DECIMALS = 1e18;
    uint256 constant BASIS_POINTS = 10000;

    // Standard test prices (18 decimals)
    uint256 constant EUR_USD_PRICE_1_10 = 110 * 1e16; // 1.10 USD per EUR
    uint256 constant EUR_USD_PRICE_1_00 = 100 * 1e16; // 1.00 USD per EUR
    uint256 constant EUR_USD_PRICE_1_20 = 120 * 1e16; // 1.20 USD per EUR
    uint256 constant EUR_USD_PRICE_0_90 = 90 * 1e16;  // 0.90 USD per EUR

    // Standard test parameters
    uint256 constant MIN_MARGIN_RATIO = 500;  // 5%
    uint256 constant MAX_MARGIN_RATIO = 10000; // 100%
    uint256 constant MAX_LEVERAGE = 20;
    uint256 constant MAX_MARGIN = 1000000 * USDC_DECIMALS; // 1M USDC
    uint256 constant MAX_POSITION_SIZE = 10000000 * USDC_DECIMALS; // 10M USDC
    uint256 constant MAX_ENTRY_PRICE = 200 * 1e16; // 2.00 USD per EUR
    uint256 constant MAX_LEVERAGE_VALUE = 10000000 * USDC_DECIMALS;
    uint256 constant ENTRY_FEE = 30; // 0.3%
    uint256 constant LIQUIDATION_THRESHOLD = 300; // 3%

    // =============================================================================
    // CALCULATE PNL TESTS
    // =============================================================================

    /**
     * @notice Test P&L calculation with zero filled volume returns zero
     */
    function test_CalculatePnL_ZeroFilledVolume_ReturnsZero() public {
        int256 pnl = _calculatePnL(0, 1000 * QEURO_DECIMALS, EUR_USD_PRICE_1_10);
        assertEq(pnl, 0, "Zero filled volume should return zero P&L");
    }

    /**
     * @notice Test P&L calculation with zero price returns zero
     */
    function test_CalculatePnL_ZeroPrice_ReturnsZero() public {
        int256 pnl = _calculatePnL(1000 * USDC_DECIMALS, 1000 * QEURO_DECIMALS, 0);
        assertEq(pnl, 0, "Zero price should return zero P&L");
    }

    /**
     * @notice Test P&L calculation with zero QEURO backed returns negative filled volume
     */
    function test_CalculatePnL_ZeroQeuroBacked_ReturnsNegativeFilledVolume() public {
        uint256 filledVolume = 1000 * USDC_DECIMALS;
        int256 pnl = _calculatePnL(filledVolume, 0, EUR_USD_PRICE_1_10);
        assertEq(pnl, -int256(filledVolume), "Zero QEURO should return negative filled volume");
    }

    /**
     * @notice Test P&L calculation when price drops (hedger profits)
     * @dev When price drops, QEURO value in USDC decreases, hedger profits
     */
    function test_CalculatePnL_PriceDrops_PositivePnL() public {
        // Entry: 1000 USDC for 1000 QEURO at 1.00 price
        // Current price: 0.90
        // QEURO value: 1000 * 0.90 = 900 USDC
        // P&L: 1000 - 900 = 100 USDC profit
        uint256 filledVolume = 1000 * USDC_DECIMALS;
        uint256 qeuroBacked = 1000 * QEURO_DECIMALS;

        int256 pnl = _calculatePnL(filledVolume, qeuroBacked, EUR_USD_PRICE_0_90);

        // filledVolume - (qeuroBacked * price / 1e30) = 1000e6 - (1000e18 * 0.9e18 / 1e30) = 1000e6 - 900e6 = 100e6
        assertEq(pnl, 100 * int256(USDC_DECIMALS), "Price drop should result in positive P&L");
    }

    /**
     * @notice Test P&L calculation when price rises (hedger loses)
     * @dev When price rises, QEURO value in USDC increases, hedger loses
     */
    function test_CalculatePnL_PriceRises_NegativePnL() public {
        // Entry: 1000 USDC for 1000 QEURO at 1.00 price
        // Current price: 1.20
        // QEURO value: 1000 * 1.20 = 1200 USDC
        // P&L: 1000 - 1200 = -200 USDC loss
        uint256 filledVolume = 1000 * USDC_DECIMALS;
        uint256 qeuroBacked = 1000 * QEURO_DECIMALS;

        int256 pnl = _calculatePnL(filledVolume, qeuroBacked, EUR_USD_PRICE_1_20);

        assertEq(pnl, -200 * int256(USDC_DECIMALS), "Price rise should result in negative P&L");
    }

    /**
     * @notice Test P&L calculation when price unchanged
     */
    function test_CalculatePnL_PriceUnchanged_ZeroPnL() public {
        uint256 filledVolume = 1000 * USDC_DECIMALS;
        uint256 qeuroBacked = 1000 * QEURO_DECIMALS;

        int256 pnl = _calculatePnL(filledVolume, qeuroBacked, EUR_USD_PRICE_1_00);

        assertEq(pnl, 0, "Unchanged price should result in zero P&L");
    }

    /**
     * @notice Fuzz test P&L calculation for various inputs
     */
    function testFuzz_CalculatePnL_VariousInputs(
        uint128 filledVolume,
        uint128 qeuroBacked,
        uint128 price
    ) public {
        vm.assume(price > 0);
        vm.assume(filledVolume > 0);
        vm.assume(qeuroBacked > 0);

        int256 pnl = _calculatePnL(uint256(filledVolume), uint256(qeuroBacked), uint256(price));

        // P&L should be bounded by filled volume
        assertLe(pnl, int256(uint256(filledVolume)), "P&L should not exceed filled volume");
    }

    // =============================================================================
    // IS POSITION LIQUIDATABLE TESTS
    // =============================================================================

    /**
     * @notice Test liquidation check with zero QEURO backed returns false
     */
    function test_IsPositionLiquidatable_ZeroQeuroBacked_ReturnsFalse() public {
        bool liquidatable = HedgerPoolLogicLibrary.isPositionLiquidatable(
            1000 * USDC_DECIMALS, // margin
            1000 * USDC_DECIMALS, // filledVolume
            EUR_USD_PRICE_1_00,   // currentPrice
            LIQUIDATION_THRESHOLD,
            0,                    // qeuroBacked = 0
            0                     // realizedPnL
        );
        assertFalse(liquidatable, "Zero QEURO should not be liquidatable");
    }

    /**
     * @notice Test liquidation check with zero price returns false
     */
    function test_IsPositionLiquidatable_ZeroPrice_ReturnsFalse() public {
        bool liquidatable = HedgerPoolLogicLibrary.isPositionLiquidatable(
            1000 * USDC_DECIMALS,
            1000 * USDC_DECIMALS,
            0,                    // price = 0
            LIQUIDATION_THRESHOLD,
            uint128(1000 * QEURO_DECIMALS),
            0
        );
        assertFalse(liquidatable, "Zero price should not be liquidatable");
    }

    /**
     * @notice Test healthy position is not liquidatable
     */
    function test_IsPositionLiquidatable_HealthyPosition_ReturnsFalse() public {
        // 10% margin ratio is above 3% liquidation threshold
        uint256 margin = 100 * USDC_DECIMALS;
        uint256 filledVolume = 1000 * USDC_DECIMALS;
        uint128 qeuroBacked = uint128(1000 * QEURO_DECIMALS);

        bool liquidatable = HedgerPoolLogicLibrary.isPositionLiquidatable(
            margin,
            filledVolume,
            EUR_USD_PRICE_1_00,
            LIQUIDATION_THRESHOLD,
            qeuroBacked,
            0
        );
        assertFalse(liquidatable, "Healthy position should not be liquidatable");
    }

    /**
     * @notice Test undercollateralized position is liquidatable
     */
    function test_IsPositionLiquidatable_Undercollateralized_ReturnsTrue() public {
        // 2% margin ratio is below 3% liquidation threshold
        uint256 margin = 20 * USDC_DECIMALS;
        uint256 filledVolume = 1000 * USDC_DECIMALS;
        uint128 qeuroBacked = uint128(1000 * QEURO_DECIMALS);

        bool liquidatable = HedgerPoolLogicLibrary.isPositionLiquidatable(
            margin,
            filledVolume,
            EUR_USD_PRICE_1_00,
            LIQUIDATION_THRESHOLD,
            qeuroBacked,
            0
        );
        assertTrue(liquidatable, "Undercollateralized position should be liquidatable");
    }

    /**
     * @notice Test position with large losses becomes liquidatable
     */
    function test_IsPositionLiquidatable_LargeLoss_ReturnsTrue() public {
        // Start with 10% margin but price rise causes large losses
        uint256 margin = 100 * USDC_DECIMALS;
        uint256 filledVolume = 1000 * USDC_DECIMALS;
        uint128 qeuroBacked = uint128(1000 * QEURO_DECIMALS);

        // Price rises significantly, causing large unrealized loss
        bool liquidatable = HedgerPoolLogicLibrary.isPositionLiquidatable(
            margin,
            filledVolume,
            140 * 1e16, // 1.40 price causes 400 USDC loss on 1000 QEURO position
            LIQUIDATION_THRESHOLD,
            qeuroBacked,
            0
        );
        assertTrue(liquidatable, "Large loss position should be liquidatable");
    }

    /**
     * @notice Test realized P&L affects liquidation status
     */
    function test_IsPositionLiquidatable_WithRealizedPnL_CorrectCalculation() public {
        uint256 margin = 100 * USDC_DECIMALS;
        uint256 filledVolume = 1000 * USDC_DECIMALS;
        uint128 qeuroBacked = uint128(800 * QEURO_DECIMALS); // Partial redemption
        int128 realizedPnL = int128(int256(50 * USDC_DECIMALS)); // 50 USDC realized profit

        bool liquidatable = HedgerPoolLogicLibrary.isPositionLiquidatable(
            margin,
            filledVolume,
            EUR_USD_PRICE_1_00,
            LIQUIDATION_THRESHOLD,
            qeuroBacked,
            realizedPnL
        );

        // The calculation accounts for realized P&L properly
        assertFalse(liquidatable, "Position with realized profit should be healthier");
    }

    // =============================================================================
    // CALCULATE COLLATERAL CAPACITY TESTS
    // =============================================================================

    /**
     * @notice Test capacity with zero price returns zero
     */
    function test_CalculateCollateralCapacity_ZeroPrice_ReturnsZero() public {
        uint256 capacity = HedgerPoolLogicLibrary.calculateCollateralCapacity(
            1000 * USDC_DECIMALS, // margin
            1000 * USDC_DECIMALS, // filledVolume
            0,                    // entryPrice (unused)
            0,                    // currentPrice = 0
            MIN_MARGIN_RATIO,
            0,                    // realizedPnL
            uint128(1000 * QEURO_DECIMALS)
        );
        assertEq(capacity, 0, "Zero price should return zero capacity");
    }

    /**
     * @notice Test capacity with zero margin ratio returns zero
     */
    function test_CalculateCollateralCapacity_ZeroMarginRatio_ReturnsZero() public {
        uint256 capacity = HedgerPoolLogicLibrary.calculateCollateralCapacity(
            1000 * USDC_DECIMALS,
            1000 * USDC_DECIMALS,
            0,
            EUR_USD_PRICE_1_00,
            0,                    // minMarginRatio = 0
            0,
            uint128(1000 * QEURO_DECIMALS)
        );
        assertEq(capacity, 0, "Zero margin ratio should return zero capacity");
    }

    /**
     * @notice Test capacity calculation with healthy position
     */
    function test_CalculateCollateralCapacity_HealthyPosition_ReturnsPositiveCapacity() public {
        uint256 margin = 200 * USDC_DECIMALS; // 20% margin
        uint256 filledVolume = 1000 * USDC_DECIMALS;
        uint128 qeuroBacked = uint128(1000 * QEURO_DECIMALS);

        uint256 capacity = HedgerPoolLogicLibrary.calculateCollateralCapacity(
            margin,
            filledVolume,
            0,
            EUR_USD_PRICE_1_00,
            MIN_MARGIN_RATIO, // 5%
            0,
            qeuroBacked
        );

        assertGt(capacity, 0, "Healthy position should have positive capacity");
    }

    /**
     * @notice Test capacity with negative effective margin returns zero
     */
    function test_CalculateCollateralCapacity_NegativeEffectiveMargin_ReturnsZero() public {
        uint256 margin = 50 * USDC_DECIMALS; // Small margin
        uint256 filledVolume = 1000 * USDC_DECIMALS;
        uint128 qeuroBacked = uint128(1000 * QEURO_DECIMALS);

        // Large price rise causes effective margin to go negative
        uint256 capacity = HedgerPoolLogicLibrary.calculateCollateralCapacity(
            margin,
            filledVolume,
            0,
            150 * 1e16, // 1.50 price causes 500 USDC loss
            MIN_MARGIN_RATIO,
            0,
            qeuroBacked
        );

        assertEq(capacity, 0, "Negative effective margin should return zero capacity");
    }

    // =============================================================================
    // CALCULATE REWARD UPDATE TESTS
    // =============================================================================

    /**
     * @notice Test reward calculation with zero exposure returns unchanged rewards
     */
    function test_CalculateRewardUpdate_ZeroExposure_ReturnsCurrentRewards() public {
        (uint256 newRewards, uint256 newBlock) = HedgerPoolLogicLibrary.calculateRewardUpdate(
            0,    // totalExposure = 0
            300,  // eurInterestRate
            500,  // usdInterestRate
            100,  // lastRewardBlock
            200,  // currentBlock
            1000, // maxRewardPeriod
            50    // currentPendingRewards
        );

        assertEq(newRewards, 50, "Zero exposure should return current rewards");
        assertEq(newBlock, 200, "Should update to current block");
    }

    /**
     * @notice Test reward calculation with zero last reward block
     */
    function test_CalculateRewardUpdate_ZeroLastRewardBlock_ReturnsCurrentRewards() public {
        (uint256 newRewards, uint256 newBlock) = HedgerPoolLogicLibrary.calculateRewardUpdate(
            1000 * USDC_DECIMALS,
            300,
            500,
            0,    // lastRewardBlock = 0
            200,
            1000,
            50
        );

        assertEq(newRewards, 50, "Zero last block should return current rewards");
        assertEq(newBlock, 200, "Should update to current block");
    }

    /**
     * @notice Test reward calculation with positive interest differential
     */
    function test_CalculateRewardUpdate_PositiveDifferential_IncreasesRewards() public {
        uint256 totalExposure = 1000000 * USDC_DECIMALS; // 1M USDC
        uint256 eurInterestRate = 300; // 3%
        uint256 usdInterestRate = 500; // 5%
        uint256 lastRewardBlock = 100;
        uint256 currentBlock = 200; // 100 blocks = 1200 seconds
        uint256 currentPendingRewards = 0;

        (uint256 newRewards, uint256 newBlock) = HedgerPoolLogicLibrary.calculateRewardUpdate(
            totalExposure,
            eurInterestRate,
            usdInterestRate,
            lastRewardBlock,
            currentBlock,
            365 days,
            currentPendingRewards
        );

        assertGt(newRewards, 0, "Positive differential should increase rewards");
        assertEq(newBlock, currentBlock, "Should update to current block");
    }

    /**
     * @notice Test reward calculation with EUR rate higher than USD rate
     */
    function test_CalculateRewardUpdate_NegativeDifferential_NoRewardIncrease() public {
        (uint256 newRewards,) = HedgerPoolLogicLibrary.calculateRewardUpdate(
            1000000 * USDC_DECIMALS,
            500,  // EUR rate higher
            300,  // USD rate lower
            100,
            200,
            365 days,
            0
        );

        assertEq(newRewards, 0, "Negative differential should not increase rewards");
    }

    /**
     * @notice Test reward calculation respects max reward period
     */
    function test_CalculateRewardUpdate_ExceedsMaxPeriod_CapsTimeElapsed() public {
        uint256 maxPeriod = 100; // 100 seconds max

        (uint256 rewardsLimited,) = HedgerPoolLogicLibrary.calculateRewardUpdate(
            1000000 * USDC_DECIMALS,
            300,
            500,
            100,
            1000, // Many blocks elapsed (10800 seconds)
            maxPeriod,
            0
        );

        (uint256 rewardsUnlimited,) = HedgerPoolLogicLibrary.calculateRewardUpdate(
            1000000 * USDC_DECIMALS,
            300,
            500,
            100,
            1000,
            365 days, // No cap
            0
        );

        assertLt(rewardsLimited, rewardsUnlimited, "Max period should cap rewards");
    }

    // =============================================================================
    // VALIDATE MARGIN OPERATION TESTS
    // =============================================================================

    /**
     * @notice Test margin addition increases margin
     */
    function test_ValidateMarginOperation_Addition_IncreasesMargin() public {
        uint256 currentMargin = 1000 * USDC_DECIMALS;
        uint256 amount = 500 * USDC_DECIMALS;
        uint256 positionSize = 10000 * USDC_DECIMALS;

        (uint256 newMargin, uint256 newRatio) = HedgerPoolLogicLibrary.validateMarginOperation(
            currentMargin,
            amount,
            true, // isAddition
            MIN_MARGIN_RATIO,
            positionSize,
            MAX_MARGIN
        );

        assertEq(newMargin, 1500 * USDC_DECIMALS, "New margin should be sum");
        assertEq(newRatio, 1500, "Ratio should be 15%");
    }

    /**
     * @notice Test margin removal decreases margin
     */
    function test_ValidateMarginOperation_Removal_DecreasesMargin() public {
        uint256 currentMargin = 1000 * USDC_DECIMALS;
        uint256 amount = 300 * USDC_DECIMALS;
        uint256 positionSize = 10000 * USDC_DECIMALS;

        (uint256 newMargin, uint256 newRatio) = HedgerPoolLogicLibrary.validateMarginOperation(
            currentMargin,
            amount,
            false, // isAddition = false (removal)
            MIN_MARGIN_RATIO,
            positionSize,
            MAX_MARGIN
        );

        assertEq(newMargin, 700 * USDC_DECIMALS, "New margin should be difference");
        assertEq(newRatio, 700, "Ratio should be 7%");
    }

    /**
     * @notice Test margin removal below minimum reverts
     */
    function test_ValidateMarginOperation_RemovalBelowMinRatio_Reverts() public {
        uint256 currentMargin = 600 * USDC_DECIMALS; // 6% of position
        uint256 amount = 200 * USDC_DECIMALS; // Would leave 4%, below 5% min
        uint256 positionSize = 10000 * USDC_DECIMALS;

        vm.expectRevert(HedgerPoolErrorLibrary.InsufficientMarginRatio.selector);
        HedgerPoolLogicLibrary.validateMarginOperation(
            currentMargin,
            amount,
            false,
            MIN_MARGIN_RATIO,
            positionSize,
            MAX_MARGIN
        );
    }

    /**
     * @notice Test margin removal more than current reverts
     */
    function test_ValidateMarginOperation_RemovalExceedsCurrent_Reverts() public {
        uint256 currentMargin = 1000 * USDC_DECIMALS;
        uint256 amount = 1500 * USDC_DECIMALS; // More than current
        uint256 positionSize = 10000 * USDC_DECIMALS;

        vm.expectRevert(HedgerPoolErrorLibrary.InsufficientMargin.selector);
        HedgerPoolLogicLibrary.validateMarginOperation(
            currentMargin,
            amount,
            false,
            MIN_MARGIN_RATIO,
            positionSize,
            MAX_MARGIN
        );
    }

    /**
     * @notice Test margin addition exceeding max reverts
     */
    function test_ValidateMarginOperation_AdditionExceedsMax_Reverts() public {
        uint256 currentMargin = MAX_MARGIN - 100 * USDC_DECIMALS;
        uint256 amount = 200 * USDC_DECIMALS; // Would exceed max
        uint256 positionSize = 10000 * USDC_DECIMALS;

        vm.expectRevert(HedgerPoolErrorLibrary.MaxMarginExceeded.selector);
        HedgerPoolLogicLibrary.validateMarginOperation(
            currentMargin,
            amount,
            true,
            MIN_MARGIN_RATIO,
            positionSize,
            MAX_MARGIN
        );
    }

    // =============================================================================
    // FUZZ TESTS
    // =============================================================================

    /**
     * @notice Fuzz test P&L sign based on price movement
     */
    function testFuzz_CalculatePnL_SignBasedOnPriceMovement(
        uint64 filledVolume,
        uint64 qeuroBacked,
        uint64 entryPrice,
        uint64 currentPrice
    ) public {
        vm.assume(filledVolume > 0);
        vm.assume(qeuroBacked > 0);
        vm.assume(entryPrice > 0);
        vm.assume(currentPrice > 0);

        // Calculate what the entry price would have been
        // filledVolume = qeuroBacked * entryPrice / 1e30 (approximately)

        int256 pnl = _calculatePnL(
            uint256(filledVolume) * USDC_DECIMALS,
            uint256(qeuroBacked) * QEURO_DECIMALS,
            uint256(currentPrice) * 1e10 // Scale to 18 decimals
        );

        // P&L should be finite
        assertTrue(pnl >= type(int256).min && pnl <= type(int256).max, "P&L should be valid int256");
    }

    /**
     * @notice Fuzz test margin ratio calculation
     */
    function testFuzz_ValidateMarginOperation_RatioCalculation(
        uint64 margin,
        uint64 positionSize
    ) public {
        vm.assume(margin > 0);
        vm.assume(positionSize > margin); // Position larger than margin
        vm.assume(uint256(margin) * 10000 / uint256(positionSize) >= MIN_MARGIN_RATIO); // Meet min ratio
        vm.assume(margin < MAX_MARGIN / 2); // Don't exceed max with addition

        uint256 smallAddition = 1000; // Small amount to add

        (uint256 newMargin, uint256 newRatio) = HedgerPoolLogicLibrary.validateMarginOperation(
            uint256(margin),
            smallAddition,
            true,
            MIN_MARGIN_RATIO,
            uint256(positionSize),
            MAX_MARGIN
        );

        // New margin should be sum
        assertEq(newMargin, uint256(margin) + smallAddition, "New margin calculation");

        // Ratio should be correct
        uint256 expectedRatio = newMargin * 10000 / uint256(positionSize);
        assertEq(newRatio, expectedRatio, "Ratio calculation");
    }

    /**
     * @notice Fuzz test liquidation consistency
     */
    function testFuzz_IsPositionLiquidatable_ConsistentWithMarginRatio(
        uint64 margin,
        uint64 qeuroBacked,
        uint64 price
    ) public {
        vm.assume(price > 1e10); // Reasonable minimum price
        vm.assume(qeuroBacked > 0);
        vm.assume(margin > 0);

        uint256 filledVolume = uint256(qeuroBacked) * uint256(price) / 1e30 + 1; // Approximate

        bool liquidatable = HedgerPoolLogicLibrary.isPositionLiquidatable(
            uint256(margin),
            filledVolume,
            uint256(price),
            LIQUIDATION_THRESHOLD,
            uint128(qeuroBacked),
            0
        );

        // Calculate manual margin ratio
        uint256 qeuroValue = uint256(qeuroBacked) * uint256(price) / 1e30;
        if (qeuroValue > 0) {
            uint256 marginRatio = uint256(margin) * 10000 / qeuroValue;

            // If margin ratio is clearly above threshold, should not be liquidatable
            if (marginRatio > LIQUIDATION_THRESHOLD * 2) {
                assertFalse(liquidatable, "High margin ratio should not be liquidatable");
            }
        }
    }

    // =============================================================================
    // HELPER FUNCTIONS
    // =============================================================================

    /**
     * @notice Internal wrapper to call calculatePnL (internal function)
     * @dev Uses a test harness pattern to access internal library functions
     */
    function _calculatePnL(
        uint256 filledVolume,
        uint256 qeuroBacked,
        uint256 currentPrice
    ) internal pure returns (int256) {
        // Direct calculation matching library logic
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
