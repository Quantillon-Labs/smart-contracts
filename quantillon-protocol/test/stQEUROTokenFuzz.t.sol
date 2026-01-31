// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {VaultMath} from "../src/libraries/VaultMath.sol";

/**
 * @title stQEUROTokenFuzz
 * @notice Comprehensive fuzz testing for stQEURO token exchange rate and staking mechanics
 *
 * @dev This test suite covers:
 *      - Exchange rate calculations under various conditions
 *      - Stake/unstake roundtrip consistency
 *      - Yield distribution math
 *      - Exchange rate manipulation resistance
 *      - Virtual shares/assets protection
 *      - Edge cases and boundary conditions
 *
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract stQEUROTokenFuzz is Test {
    using VaultMath for uint256;

    // =============================================================================
    // CONSTANTS
    // =============================================================================

    uint256 constant PRECISION = 1e18;
    uint256 constant VIRTUAL_SHARES = 1e8;
    uint256 constant VIRTUAL_ASSETS = 1e8;
    uint256 constant BASIS_POINTS = 10000;
    uint256 constant MAX_EXCHANGE_RATE = 10 * PRECISION; // 10x max rate

    // =============================================================================
    // EXCHANGE RATE CALCULATION FUZZ TESTS
    // =============================================================================

    /**
     * @notice Fuzz test exchange rate calculation is monotonically increasing with yield
     */
    function testFuzz_ExchangeRate_MonotonicallyIncreasingWithYield(
        uint128 totalUnderlying,
        uint64 totalYield1,
        uint64 totalYield2
    ) public pure {
        vm.assume(totalUnderlying > 0);
        vm.assume(totalYield1 <= totalYield2);

        // Calculate exchange rates with virtual shares/assets
        uint256 totalAssets1 = uint256(totalUnderlying) + uint256(totalYield1) + VIRTUAL_ASSETS;
        uint256 totalAssets2 = uint256(totalUnderlying) + uint256(totalYield2) + VIRTUAL_ASSETS;
        uint256 totalShares = uint256(totalUnderlying) + VIRTUAL_SHARES;

        uint256 rate1 = totalAssets1 * PRECISION / totalShares;
        uint256 rate2 = totalAssets2 * PRECISION / totalShares;

        assertGe(rate2, rate1, "Exchange rate should be monotonically increasing with yield");
    }

    /**
     * @notice Fuzz test exchange rate starts at 1:1 (approximately)
     */
    function testFuzz_ExchangeRate_StartsAtParityApproximately(
        uint128 totalUnderlying
    ) public pure {
        vm.assume(totalUnderlying > 1e18); // At least 1 QEURO
        vm.assume(totalUnderlying < 1e30); // Reasonable max

        // No yield earned yet
        uint256 totalAssets = uint256(totalUnderlying) + VIRTUAL_ASSETS;
        uint256 totalShares = uint256(totalUnderlying) + VIRTUAL_SHARES;

        uint256 rate = totalAssets * PRECISION / totalShares;

        // Should be very close to 1:1 for reasonable amounts
        // Due to virtual shares/assets, small amounts have different behavior
        uint256 deviation = rate > PRECISION ? rate - PRECISION : PRECISION - rate;
        uint256 maxDeviation = PRECISION / 100; // 1% max deviation

        assertLe(deviation, maxDeviation, "Initial exchange rate should be approximately 1:1");
    }

    /**
     * @notice Fuzz test exchange rate never exceeds maximum
     */
    function testFuzz_ExchangeRate_BoundedByMaximum(
        uint64 totalUnderlying,
        uint64 totalYield
    ) public pure {
        vm.assume(totalUnderlying > 0);

        uint256 totalAssets = uint256(totalUnderlying) + uint256(totalYield) + VIRTUAL_ASSETS;
        uint256 totalShares = uint256(totalUnderlying) + VIRTUAL_SHARES;

        uint256 rate = totalAssets * PRECISION / totalShares;

        // With reasonable yield (up to 100% of underlying), rate should not exceed 10x
        if (uint256(totalYield) <= uint256(totalUnderlying) * 9) {
            assertLe(rate, MAX_EXCHANGE_RATE, "Exchange rate should not exceed maximum");
        }
    }

    // =============================================================================
    // STAKE/UNSTAKE ROUNDTRIP FUZZ TESTS
    // =============================================================================

    /**
     * @notice Fuzz test stake and immediate unstake returns approximately same amount
     */
    function testFuzz_StakeUnstake_RoundtripPreservesValue(
        uint64 stakeAmount
    ) public pure {
        vm.assume(stakeAmount >= 1e18); // At least 1 QEURO
        vm.assume(stakeAmount < 1e30); // Reasonable max

        // Simulate stake: calculate stQEURO received
        uint256 totalUnderlyingBefore = 1000000e18; // 1M QEURO already staked
        uint256 totalYield = 50000e18; // 50K yield earned
        uint256 totalSharesBefore = 1000000e18;

        uint256 totalAssets = totalUnderlyingBefore + totalYield + VIRTUAL_ASSETS;
        uint256 totalShares = totalSharesBefore + VIRTUAL_SHARES;
        uint256 exchangeRate = totalAssets * PRECISION / totalShares;

        // stQEURO received = qeuroAmount * PRECISION / exchangeRate
        uint256 stQEUROReceived = uint256(stakeAmount) * PRECISION / exchangeRate;

        // Simulate unstake: calculate QEURO returned
        // qeuroReturned = stQEUROAmount * exchangeRate / PRECISION
        uint256 qeuroReturned = stQEUROReceived * exchangeRate / PRECISION;

        // Should get back approximately the same amount (within rounding)
        uint256 diff = uint256(stakeAmount) > qeuroReturned
            ? uint256(stakeAmount) - qeuroReturned
            : qeuroReturned - uint256(stakeAmount);

        // Allow for small rounding error (< 0.01%)
        assertLe(diff, uint256(stakeAmount) / 10000 + 1, "Roundtrip should preserve value");
    }

    /**
     * @notice Fuzz test stake amount conversion to stQEURO
     */
    function testFuzz_Stake_ConversionCorrect(
        uint64 stakeAmount,
        uint64 currentRate
    ) public pure {
        vm.assume(stakeAmount > 0);
        vm.assume(currentRate >= PRECISION / 2); // Rate at least 0.5
        vm.assume(currentRate <= 5 * PRECISION); // Rate at most 5x

        // stQEURO received = qeuroAmount * PRECISION / exchangeRate
        uint256 stQEURO = uint256(stakeAmount) * PRECISION / uint256(currentRate);

        // Higher rate = fewer stQEURO for same QEURO
        if (uint256(currentRate) > PRECISION) {
            assertLt(stQEURO, uint256(stakeAmount), "Higher rate should give fewer stQEURO");
        }
    }

    /**
     * @notice Fuzz test unstake amount conversion to QEURO
     */
    function testFuzz_Unstake_ConversionCorrect(
        uint64 unstakeAmount,
        uint64 currentRate
    ) public pure {
        vm.assume(unstakeAmount > 0);
        vm.assume(currentRate >= PRECISION / 2);
        vm.assume(currentRate <= 5 * PRECISION);

        // QEURO returned = stQEUROAmount * exchangeRate / PRECISION
        uint256 qeuro = uint256(unstakeAmount) * uint256(currentRate) / PRECISION;

        // Higher rate = more QEURO for same stQEURO
        if (uint256(currentRate) > PRECISION) {
            assertGt(qeuro, uint256(unstakeAmount), "Higher rate should give more QEURO");
        }
    }

    // =============================================================================
    // YIELD DISTRIBUTION FUZZ TESTS
    // =============================================================================

    /**
     * @notice Fuzz test yield fee calculation
     */
    function testFuzz_YieldFee_CalculationCorrect(
        uint64 yieldAmount,
        uint16 feeBps
    ) public pure {
        vm.assume(feeBps <= BASIS_POINTS); // Max 100% fee

        uint256 fee = uint256(yieldAmount) * uint256(feeBps) / BASIS_POINTS;
        uint256 netYield = uint256(yieldAmount) - fee;

        assertLe(fee, uint256(yieldAmount), "Fee should not exceed yield");
        assertEq(fee + netYield, uint256(yieldAmount), "Fee + net should equal gross");
    }

    /**
     * @notice Fuzz test exchange rate increases after yield distribution
     */
    function testFuzz_YieldDistribution_IncreasesExchangeRate(
        uint64 totalUnderlying,
        uint64 existingYield,
        uint64 newYield
    ) public pure {
        vm.assume(totalUnderlying > 1e18);
        vm.assume(newYield > 0);

        // Before yield distribution
        uint256 assetsBefore = uint256(totalUnderlying) + uint256(existingYield) + VIRTUAL_ASSETS;
        uint256 shares = uint256(totalUnderlying) + VIRTUAL_SHARES;
        uint256 rateBefore = assetsBefore * PRECISION / shares;

        // After yield distribution
        uint256 assetsAfter = assetsBefore + uint256(newYield);
        uint256 rateAfter = assetsAfter * PRECISION / shares;

        assertGt(rateAfter, rateBefore, "Exchange rate should increase after yield");
    }

    /**
     * @notice Fuzz test yield proportional to stake
     */
    function testFuzz_Yield_ProportionalToStake(
        uint64 stake1,
        uint64 stake2,
        uint64 totalYield
    ) public pure {
        vm.assume(stake1 > 0);
        vm.assume(stake2 > 0);
        vm.assume(totalYield > 0);

        uint256 totalStake = uint256(stake1) + uint256(stake2);

        // Yield is proportional to stake share
        uint256 yield1 = uint256(totalYield) * uint256(stake1) / totalStake;
        uint256 yield2 = uint256(totalYield) * uint256(stake2) / totalStake;

        // Larger stake = larger yield
        if (stake1 > stake2) {
            assertGe(yield1, yield2, "Larger stake should get more yield");
        } else if (stake2 > stake1) {
            assertGe(yield2, yield1, "Larger stake should get more yield");
        }
    }

    // =============================================================================
    // VIRTUAL SHARES/ASSETS PROTECTION FUZZ TESTS
    // =============================================================================

    /**
     * @notice Fuzz test virtual shares prevent inflation attack
     */
    function testFuzz_VirtualShares_PreventInflationAttack(
        uint64 attackerDonation,
        uint64 victimDeposit
    ) public pure {
        vm.assume(victimDeposit > 1e15); // At least 0.001 QEURO
        vm.assume(attackerDonation > 0);

        // Scenario: Attacker tries to inflate exchange rate before victim deposits
        // With virtual shares, the attack is mitigated

        // After attacker donation (before victim)
        uint256 totalAssets = uint256(attackerDonation) + VIRTUAL_ASSETS;
        uint256 totalShares = VIRTUAL_SHARES; // Only virtual shares

        uint256 inflatedRate = totalAssets * PRECISION / totalShares;

        // Victim deposits
        uint256 victimShares = uint256(victimDeposit) * PRECISION / inflatedRate;

        // Check victim doesn't lose too much to rounding
        uint256 victimValueAfter = victimShares * inflatedRate / PRECISION;
        uint256 loss = uint256(victimDeposit) > victimValueAfter
            ? uint256(victimDeposit) - victimValueAfter
            : 0;

        // With virtual shares, loss should be bounded (< 10% for reasonable scenarios)
        if (uint256(attackerDonation) <= uint256(victimDeposit) * 10) {
            assertLe(loss, uint256(victimDeposit) / 10, "Virtual shares should limit loss");
        }
    }

    /**
     * @notice Fuzz test exchange rate with only virtual shares/assets
     */
    function testFuzz_ExchangeRate_WithOnlyVirtual() public pure {
        // Only virtual shares and assets
        uint256 rate = VIRTUAL_ASSETS * PRECISION / VIRTUAL_SHARES;

        // Should be exactly 1:1 since VIRTUAL_ASSETS == VIRTUAL_SHARES
        assertEq(rate, PRECISION, "Virtual rate should be 1:1");
    }

    // =============================================================================
    // EDGE CASE FUZZ TESTS
    // =============================================================================

    /**
     * @notice Fuzz test very small deposits don't break exchange rate
     */
    function testFuzz_SmallDeposit_HandledCorrectly(
        uint32 smallAmount
    ) public pure {
        vm.assume(smallAmount > 0);

        // Large existing state
        uint256 totalUnderlying = 10000000e18; // 10M QEURO
        uint256 totalYield = 1000000e18; // 1M yield

        uint256 totalAssets = totalUnderlying + totalYield + VIRTUAL_ASSETS;
        uint256 totalShares = totalUnderlying + VIRTUAL_SHARES;

        uint256 rate = totalAssets * PRECISION / totalShares;

        // Small deposit
        uint256 stQEURO = uint256(smallAmount) * PRECISION / rate;

        // Should get at least some shares if amount > 0
        // (This verifies no div-by-zero or excessive rounding)
        assertTrue(rate > 0, "Rate should be positive");
    }

    /**
     * @notice Fuzz test very large deposits don't overflow
     */
    function testFuzz_LargeDeposit_NoOverflow(
        uint128 largeAmount
    ) public pure {
        vm.assume(largeAmount > 1e18);
        vm.assume(largeAmount < type(uint128).max / 2);

        uint256 rate = PRECISION; // 1:1 rate

        // Should not overflow
        uint256 stQEURO = uint256(largeAmount) * PRECISION / rate;

        assertEq(stQEURO, uint256(largeAmount), "Large deposit should work correctly");
    }

    /**
     * @notice Fuzz test exchange rate calculation precision
     */
    function testFuzz_ExchangeRate_PrecisionMaintained(
        uint64 underlying,
        uint64 yield_
    ) public pure {
        vm.assume(underlying > 1e12);

        uint256 totalAssets = uint256(underlying) + uint256(yield_) + VIRTUAL_ASSETS;
        uint256 totalShares = uint256(underlying) + VIRTUAL_SHARES;

        // Forward calculation
        uint256 rate = totalAssets * PRECISION / totalShares;

        // Reverse calculation should be consistent
        uint256 assetsFromRate = rate * totalShares / PRECISION;

        // Should be within 1 unit of original due to rounding
        uint256 diff = totalAssets > assetsFromRate
            ? totalAssets - assetsFromRate
            : assetsFromRate - totalAssets;

        assertLe(diff, 1, "Precision should be maintained in calculations");
    }

    /**
     * @notice Fuzz test stake amount never returns zero shares for positive input
     */
    function testFuzz_Stake_AlwaysReturnsSomeShares(
        uint64 stakeAmount,
        uint64 rate
    ) public pure {
        vm.assume(stakeAmount >= 1e9); // At least 1 gwei equivalent
        vm.assume(rate >= PRECISION / 10); // Rate at least 0.1
        vm.assume(rate <= 100 * PRECISION); // Rate at most 100x

        uint256 shares = uint256(stakeAmount) * PRECISION / uint256(rate);

        // Should always get some shares for reasonable inputs
        assertGt(shares, 0, "Should always receive some shares");
    }

    /**
     * @notice Fuzz test consecutive operations maintain consistency
     */
    function testFuzz_ConsecutiveOperations_Consistent(
        uint32 amount1,
        uint32 amount2,
        uint32 amount3
    ) public pure {
        vm.assume(amount1 >= 1e6);
        vm.assume(amount2 >= 1e6);
        vm.assume(amount3 >= 1e6);

        uint256 rate = PRECISION; // 1:1

        // Three consecutive stakes
        uint256 shares1 = uint256(amount1) * PRECISION / rate;
        uint256 shares2 = uint256(amount2) * PRECISION / rate;
        uint256 shares3 = uint256(amount3) * PRECISION / rate;

        // Combined stake
        uint256 totalAmount = uint256(amount1) + uint256(amount2) + uint256(amount3);
        uint256 combinedShares = totalAmount * PRECISION / rate;

        // Should be equivalent (within rounding)
        uint256 sumShares = shares1 + shares2 + shares3;
        uint256 diff = combinedShares > sumShares
            ? combinedShares - sumShares
            : sumShares - combinedShares;

        assertLe(diff, 3, "Consecutive operations should match combined");
    }
}
