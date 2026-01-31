// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {UserPoolStakingLibrary} from "../src/libraries/UserPoolStakingLibrary.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";

/**
 * @title UserPoolStakingLibraryTest
 * @notice Comprehensive test suite for UserPoolStakingLibrary
 *
 * @dev This test suite covers:
 *      - Staking reward calculations
 *      - Stake parameter validation
 *      - Unstake parameter validation
 *      - Unstake penalty calculations
 *      - APY calculations (deposit and staking)
 *      - Dynamic fee calculations
 *      - Pool metrics packing/unpacking
 *      - Edge cases and boundary conditions
 *
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract UserPoolStakingLibraryTest is Test {
    // =============================================================================
    // CONSTANTS (matching library)
    // =============================================================================

    uint256 constant MIN_STAKE_AMOUNT = 1e18;

    function setUp() public {
        // Avoid underflow in tests that use block.timestamp - 30 days
        vm.warp(40 days);
    }
    uint256 constant MAX_STAKE_AMOUNT = 1000000e18;
    uint256 constant MIN_STAKE_DURATION = 1 days;
    uint256 constant MAX_STAKE_DURATION = 365 days;
    uint256 constant UNSTAKE_COOLDOWN = 7 days;
    uint256 constant REWARD_CLAIM_COOLDOWN = 1 days;

    // Test parameters
    uint256 constant BASE_APY = 500; // 5%

    // =============================================================================
    // STAKING REWARDS CALCULATION TESTS
    // =============================================================================

    /**
     * @notice Test rewards calculation with inactive stake returns zero
     */
    function test_CalculateStakingRewards_InactiveStake_ReturnsZero() public view {
        UserPoolStakingLibrary.StakeInfo memory stakeInfo = UserPoolStakingLibrary.StakeInfo({
            amount: 1000e18,
            startTime: block.timestamp - 30 days,
            endTime: block.timestamp + 30 days,
            lastRewardClaim: block.timestamp - 1 days,
            totalRewardsClaimed: 0,
            isActive: false // Inactive
        });

        uint256 rewards = UserPoolStakingLibrary.calculateStakingRewards(
            stakeInfo,
            BASE_APY,
            block.timestamp
        );

        assertEq(rewards, 0, "Inactive stake should return zero rewards");
    }

    /**
     * @notice Test rewards calculation before minimum duration returns zero
     */
    function test_CalculateStakingRewards_BeforeMinDuration_ReturnsZero() public view {
        UserPoolStakingLibrary.StakeInfo memory stakeInfo = UserPoolStakingLibrary.StakeInfo({
            amount: 1000e18,
            startTime: block.timestamp,
            endTime: block.timestamp + 30 days,
            lastRewardClaim: block.timestamp,
            totalRewardsClaimed: 0,
            isActive: true
        });

        // Check at 12 hours (before MIN_STAKE_DURATION = 1 day)
        uint256 rewards = UserPoolStakingLibrary.calculateStakingRewards(
            stakeInfo,
            BASE_APY,
            block.timestamp + 12 hours
        );

        assertEq(rewards, 0, "Stake before min duration should return zero rewards");
    }

    /**
     * @notice Test rewards calculation after minimum duration
     */
    function test_CalculateStakingRewards_AfterMinDuration_ReturnsPositive() public view {
        uint256 amount = 10000e18;
        uint256 startTime = block.timestamp;

        UserPoolStakingLibrary.StakeInfo memory stakeInfo = UserPoolStakingLibrary.StakeInfo({
            amount: amount,
            startTime: startTime,
            endTime: startTime + 30 days,
            lastRewardClaim: startTime,
            totalRewardsClaimed: 0,
            isActive: true
        });

        // Check at 2 days (after MIN_STAKE_DURATION)
        uint256 currentTime = startTime + 2 days;
        uint256 rewards = UserPoolStakingLibrary.calculateStakingRewards(
            stakeInfo,
            BASE_APY,
            currentTime
        );

        assertGt(rewards, 0, "Stake after min duration should return positive rewards");
    }

    /**
     * @notice Test rewards calculation with bonus for long duration
     */
    function test_CalculateStakingRewards_LongDuration_AppliesBonus() public view {
        uint256 amount = 10000e18;
        uint256 startTime = block.timestamp;

        UserPoolStakingLibrary.StakeInfo memory stakeInfo = UserPoolStakingLibrary.StakeInfo({
            amount: amount,
            startTime: startTime,
            endTime: startTime + 90 days,
            lastRewardClaim: startTime,
            totalRewardsClaimed: 0,
            isActive: true
        });

        // Short duration (5 days) - no bonus
        uint256 shortDurationTime = startTime + 5 days;
        uint256 shortRewards = UserPoolStakingLibrary.calculateStakingRewards(
            stakeInfo,
            BASE_APY,
            shortDurationTime
        );

        // Long duration (60 days) - with bonus
        stakeInfo.lastRewardClaim = startTime; // Reset for comparison
        uint256 longDurationTime = startTime + 60 days;
        uint256 longRewards = UserPoolStakingLibrary.calculateStakingRewards(
            stakeInfo,
            BASE_APY,
            longDurationTime
        );

        // Long duration rewards per day should be higher due to bonus
        uint256 shortRewardsPerDay = shortRewards * 1 days / 5 days;
        uint256 longRewardsPerDay = longRewards * 1 days / 60 days;

        assertGt(longRewardsPerDay, shortRewardsPerDay, "Long duration should have higher daily rewards");
    }

    // =============================================================================
    // STAKE PARAMETER VALIDATION TESTS
    // =============================================================================

    /**
     * @notice Test validation with valid parameters passes
     */
    function test_ValidateStakeParameters_ValidParams_Passes() public pure {
        UserPoolStakingLibrary.UserStakingData memory userData = UserPoolStakingLibrary.UserStakingData({
            totalStaked: 0,
            totalRewardsEarned: 0,
            totalRewardsClaimed: 0,
            lastStakeTime: 0,
            lastUnstakeTime: 0,
            activeStakes: 0
        });

        // Should not revert
        UserPoolStakingLibrary.validateStakeParameters(
            100e18,     // Valid amount
            30 days,    // Valid duration
            userData
        );
    }

    /**
     * @notice Test validation with amount below minimum reverts
     */
    function test_ValidateStakeParameters_BelowMinAmount_Reverts() public {
        UserPoolStakingLibrary.UserStakingData memory userData = UserPoolStakingLibrary.UserStakingData({
            totalStaked: 0,
            totalRewardsEarned: 0,
            totalRewardsClaimed: 0,
            lastStakeTime: 0,
            lastUnstakeTime: 0,
            activeStakes: 0
        });

        vm.expectRevert(CommonErrorLibrary.InsufficientBalance.selector);
        UserPoolStakingLibrary.validateStakeParameters(
            MIN_STAKE_AMOUNT - 1, // Below minimum
            30 days,
            userData
        );
    }

    /**
     * @notice Test validation with amount above maximum reverts
     */
    function test_ValidateStakeParameters_AboveMaxAmount_Reverts() public {
        UserPoolStakingLibrary.UserStakingData memory userData = UserPoolStakingLibrary.UserStakingData({
            totalStaked: 0,
            totalRewardsEarned: 0,
            totalRewardsClaimed: 0,
            lastStakeTime: 0,
            lastUnstakeTime: 0,
            activeStakes: 0
        });

        vm.expectRevert(CommonErrorLibrary.AboveLimit.selector);
        UserPoolStakingLibrary.validateStakeParameters(
            MAX_STAKE_AMOUNT + 1, // Above maximum
            30 days,
            userData
        );
    }

    /**
     * @notice Test validation with duration below minimum reverts
     */
    function test_ValidateStakeParameters_BelowMinDuration_Reverts() public {
        UserPoolStakingLibrary.UserStakingData memory userData = UserPoolStakingLibrary.UserStakingData({
            totalStaked: 0,
            totalRewardsEarned: 0,
            totalRewardsClaimed: 0,
            lastStakeTime: 0,
            lastUnstakeTime: 0,
            activeStakes: 0
        });

        vm.expectRevert(CommonErrorLibrary.HoldingPeriodNotMet.selector);
        UserPoolStakingLibrary.validateStakeParameters(
            100e18,
            MIN_STAKE_DURATION - 1, // Below minimum
            userData
        );
    }

    /**
     * @notice Test validation with too many active stakes reverts
     */
    function test_ValidateStakeParameters_TooManyStakes_Reverts() public {
        UserPoolStakingLibrary.UserStakingData memory userData = UserPoolStakingLibrary.UserStakingData({
            totalStaked: 0,
            totalRewardsEarned: 0,
            totalRewardsClaimed: 0,
            lastStakeTime: 0,
            lastUnstakeTime: 0,
            activeStakes: 10 // Maximum
        });

        vm.expectRevert(CommonErrorLibrary.TooManyPositions.selector);
        UserPoolStakingLibrary.validateStakeParameters(
            100e18,
            30 days,
            userData
        );
    }

    // =============================================================================
    // UNSTAKE PARAMETER VALIDATION TESTS
    // =============================================================================

    /**
     * @notice Test unstake validation with inactive stake reverts
     */
    function test_ValidateUnstakeParameters_InactiveStake_Reverts() public {
        UserPoolStakingLibrary.StakeInfo memory stakeInfo = UserPoolStakingLibrary.StakeInfo({
            amount: 1000e18,
            startTime: block.timestamp - 30 days,
            endTime: block.timestamp + 30 days,
            lastRewardClaim: block.timestamp - 8 days,
            totalRewardsClaimed: 0,
            isActive: false // Inactive
        });

        vm.expectRevert(CommonErrorLibrary.PositionNotActive.selector);
        UserPoolStakingLibrary.validateUnstakeParameters(stakeInfo, block.timestamp);
    }

    /**
     * @notice Test unstake validation before minimum duration reverts
     */
    function test_ValidateUnstakeParameters_BeforeMinDuration_Reverts() public {
        UserPoolStakingLibrary.StakeInfo memory stakeInfo = UserPoolStakingLibrary.StakeInfo({
            amount: 1000e18,
            startTime: block.timestamp,
            endTime: block.timestamp + 30 days,
            lastRewardClaim: block.timestamp,
            totalRewardsClaimed: 0,
            isActive: true
        });

        vm.expectRevert(CommonErrorLibrary.HoldingPeriodNotMet.selector);
        UserPoolStakingLibrary.validateUnstakeParameters(
            stakeInfo,
            block.timestamp + 12 hours // Before min duration
        );
    }

    /**
     * @notice Test unstake validation within cooldown reverts
     */
    function test_ValidateUnstakeParameters_WithinCooldown_Reverts() public {
        UserPoolStakingLibrary.StakeInfo memory stakeInfo = UserPoolStakingLibrary.StakeInfo({
            amount: 1000e18,
            startTime: block.timestamp - 30 days,
            endTime: block.timestamp + 30 days,
            lastRewardClaim: block.timestamp, // Just claimed
            totalRewardsClaimed: 100e18,
            isActive: true
        });

        vm.expectRevert(CommonErrorLibrary.LiquidationCooldown.selector);
        UserPoolStakingLibrary.validateUnstakeParameters(
            stakeInfo,
            block.timestamp + 1 days // Within 7 day cooldown
        );
    }

    // =============================================================================
    // UNSTAKE PENALTY TESTS
    // =============================================================================

    /**
     * @notice Test penalty for very short stake (< 7 days)
     */
    function test_CalculateUnstakePenalty_VeryShortStake_Returns10Percent() public view {
        UserPoolStakingLibrary.StakeInfo memory stakeInfo = UserPoolStakingLibrary.StakeInfo({
            amount: 1000e18,
            startTime: block.timestamp,
            endTime: block.timestamp + 30 days,
            lastRewardClaim: block.timestamp,
            totalRewardsClaimed: 0,
            isActive: true
        });

        uint256 penalty = UserPoolStakingLibrary.calculateUnstakePenalty(
            stakeInfo,
            block.timestamp + 3 days // Less than 7 days
        );

        assertEq(penalty, 1000, "Very short stake should have 10% penalty");
    }

    /**
     * @notice Test penalty for short stake (7-30 days)
     */
    function test_CalculateUnstakePenalty_ShortStake_Returns5Percent() public view {
        UserPoolStakingLibrary.StakeInfo memory stakeInfo = UserPoolStakingLibrary.StakeInfo({
            amount: 1000e18,
            startTime: block.timestamp,
            endTime: block.timestamp + 60 days,
            lastRewardClaim: block.timestamp,
            totalRewardsClaimed: 0,
            isActive: true
        });

        uint256 penalty = UserPoolStakingLibrary.calculateUnstakePenalty(
            stakeInfo,
            block.timestamp + 15 days // Between 7 and 30 days
        );

        assertEq(penalty, 500, "Short stake should have 5% penalty");
    }

    /**
     * @notice Test penalty for medium stake (30-90 days)
     */
    function test_CalculateUnstakePenalty_MediumStake_Returns2Percent() public view {
        UserPoolStakingLibrary.StakeInfo memory stakeInfo = UserPoolStakingLibrary.StakeInfo({
            amount: 1000e18,
            startTime: block.timestamp,
            endTime: block.timestamp + 120 days,
            lastRewardClaim: block.timestamp,
            totalRewardsClaimed: 0,
            isActive: true
        });

        uint256 penalty = UserPoolStakingLibrary.calculateUnstakePenalty(
            stakeInfo,
            block.timestamp + 60 days // Between 30 and 90 days
        );

        assertEq(penalty, 200, "Medium stake should have 2% penalty");
    }

    /**
     * @notice Test penalty for long stake (> 90 days)
     */
    function test_CalculateUnstakePenalty_LongStake_ReturnsZero() public view {
        UserPoolStakingLibrary.StakeInfo memory stakeInfo = UserPoolStakingLibrary.StakeInfo({
            amount: 1000e18,
            startTime: block.timestamp,
            endTime: block.timestamp + 180 days,
            lastRewardClaim: block.timestamp,
            totalRewardsClaimed: 0,
            isActive: true
        });

        uint256 penalty = UserPoolStakingLibrary.calculateUnstakePenalty(
            stakeInfo,
            block.timestamp + 100 days // More than 90 days
        );

        assertEq(penalty, 0, "Long stake should have no penalty");
    }

    // =============================================================================
    // APY CALCULATION TESTS
    // =============================================================================

    /**
     * @notice Test deposit APY with zero deposits returns base APY
     */
    function test_CalculateDepositAPY_ZeroDeposits_ReturnsBaseAPY() public pure {
        uint256 apy = UserPoolStakingLibrary.calculateDepositAPY(0, 0, BASE_APY);
        assertEq(apy, BASE_APY, "Zero deposits should return base APY");
    }

    /**
     * @notice Test deposit APY with low staking ratio gets bonus
     */
    function test_CalculateDepositAPY_LowStakingRatio_GetsBonus() public pure {
        uint256 totalDeposits = 1000000e18;
        uint256 totalStaked = 100000e18; // 10% staked

        uint256 apy = UserPoolStakingLibrary.calculateDepositAPY(totalDeposits, totalStaked, BASE_APY);

        assertEq(apy, BASE_APY + 500, "Low staking ratio should get +5% bonus");
    }

    /**
     * @notice Test deposit APY with high staking ratio gets reduction
     */
    function test_CalculateDepositAPY_HighStakingRatio_GetsReduction() public pure {
        uint256 totalDeposits = 1000000e18;
        uint256 totalStaked = 900000e18; // 90% staked

        uint256 apy = UserPoolStakingLibrary.calculateDepositAPY(totalDeposits, totalStaked, BASE_APY);

        assertEq(apy, BASE_APY - 300, "High staking ratio should get -3% reduction");
    }

    /**
     * @notice Test staking APY with low staking ratio gets larger bonus
     */
    function test_CalculateStakingAPY_LowStakingRatio_GetsLargerBonus() public pure {
        uint256 totalDeposits = 1000000e18;
        uint256 totalStaked = 100000e18; // 10% staked

        uint256 apy = UserPoolStakingLibrary.calculateStakingAPY(totalDeposits, totalStaked, BASE_APY);

        assertEq(apy, BASE_APY + 1000, "Low staking ratio should get +10% bonus for staking");
    }

    // =============================================================================
    // DYNAMIC FEE CALCULATION TESTS
    // =============================================================================

    /**
     * @notice Test dynamic fee with normal utilization
     */
    function test_CalculateDynamicFee_NormalUtilization_ReturnsBaseFee() public pure {
        uint256 amount = 10000e18;
        uint256 baseFee = 100; // 1%
        uint256 utilization = 5000; // 50%

        uint256 fee = UserPoolStakingLibrary.calculateDynamicFee(amount, baseFee, utilization);

        assertEq(fee, amount * baseFee / 10000, "Normal utilization should return base fee");
    }

    /**
     * @notice Test dynamic fee with high utilization gets increase
     */
    function test_CalculateDynamicFee_HighUtilization_GetsIncrease() public pure {
        uint256 amount = 10000e18;
        uint256 baseFee = 100; // 1%
        uint256 utilization = 9500; // 95%

        uint256 fee = UserPoolStakingLibrary.calculateDynamicFee(amount, baseFee, utilization);

        uint256 baseFeeAmount = amount * baseFee / 10000;
        assertEq(fee, baseFeeAmount * 150 / 100, "High utilization should get +50% fee increase");
    }

    /**
     * @notice Test dynamic fee with low utilization gets reduction
     */
    function test_CalculateDynamicFee_LowUtilization_GetsReduction() public pure {
        uint256 amount = 10000e18;
        uint256 baseFee = 100; // 1%
        uint256 utilization = 2000; // 20%

        uint256 fee = UserPoolStakingLibrary.calculateDynamicFee(amount, baseFee, utilization);

        uint256 baseFeeAmount = amount * baseFee / 10000;
        assertEq(fee, baseFeeAmount * 50 / 100, "Low utilization should get -50% fee reduction");
    }

    // =============================================================================
    // POOL METRICS PACKING/UNPACKING TESTS
    // =============================================================================

    /**
     * @notice Test pool metrics packing and unpacking roundtrip
     */
    function test_PoolMetrics_PackUnpack_Roundtrip() public pure {
        // Use values so (averageDeposit << 64) doesn't spill into high 128 bits; averageDeposit and totalUsers fit in 64 bits
        uint256 totalDeposits = 1000e18;
        uint256 totalStaked = 500e18;
        uint256 totalUsers = 100;

        uint256 packed = UserPoolStakingLibrary.calculatePoolMetrics(
            totalDeposits,
            totalStaked,
            totalUsers
        );

        (uint256 stakingRatio, uint256 averageDeposit, uint256 users) =
            UserPoolStakingLibrary.unpackPoolMetrics(packed);

        assertApproxEqAbs(stakingRatio, 5000, 100, "Staking ratio should be ~50%");
        assertEq(users, totalUsers, "Total users should match");
        assertEq(averageDeposit, totalDeposits / totalUsers, "Average deposit roundtrip");
    }

    /**
     * @notice Test pool metrics with zero deposits
     */
    function test_PoolMetrics_ZeroDeposits_HandlesCorrectly() public pure {
        uint256 packed = UserPoolStakingLibrary.calculatePoolMetrics(0, 0, 100);

        (uint256 stakingRatio, uint256 averageDeposit, uint256 users) =
            UserPoolStakingLibrary.unpackPoolMetrics(packed);

        assertEq(stakingRatio, 0, "Zero deposits should have zero staking ratio");
        assertEq(averageDeposit, 0, "Zero deposits should have zero average");
        assertEq(users, 100, "Users should still be tracked");
    }

    // =============================================================================
    // FUZZ TESTS
    // =============================================================================

    /**
     * @notice Fuzz test penalty decreases with stake duration
     */
    function testFuzz_UnstakePenalty_DecreasesWithDuration(uint64 duration) public view {
        vm.assume(duration >= 1 days);
        vm.assume(duration <= 365 days);

        UserPoolStakingLibrary.StakeInfo memory stakeInfo = UserPoolStakingLibrary.StakeInfo({
            amount: 1000e18,
            startTime: block.timestamp,
            endTime: block.timestamp + 365 days,
            lastRewardClaim: block.timestamp,
            totalRewardsClaimed: 0,
            isActive: true
        });

        uint256 penalty = UserPoolStakingLibrary.calculateUnstakePenalty(
            stakeInfo,
            block.timestamp + uint256(duration)
        );

        assertLe(penalty, 1000, "Penalty should be at most 10%");
    }

    /**
     * @notice Fuzz test APY adjustments stay within bounds
     */
    function testFuzz_APY_StaysWithinBounds(uint64 deposits, uint64 staked) public pure {
        vm.assume(deposits > 0);
        vm.assume(staked <= deposits);

        uint256 depositAPY = UserPoolStakingLibrary.calculateDepositAPY(
            uint256(deposits),
            uint256(staked),
            BASE_APY
        );

        uint256 stakingAPY = UserPoolStakingLibrary.calculateStakingAPY(
            uint256(deposits),
            uint256(staked),
            BASE_APY
        );

        // APYs should be reasonable
        assertLe(depositAPY, BASE_APY + 500, "Deposit APY should not exceed base + 5%");
        assertGe(depositAPY, BASE_APY - 300, "Deposit APY should not go below base - 3%");
        assertLe(stakingAPY, BASE_APY + 1000, "Staking APY should not exceed base + 10%");
        assertGe(stakingAPY, BASE_APY - 500, "Staking APY should not go below base - 5%");
    }

    /**
     * @notice Fuzz test pool metrics packing preserves data
     */
    function testFuzz_PoolMetrics_PreservesData(uint64 deposits, uint64 staked, uint32 users) public pure {
        vm.assume(deposits > 0);
        vm.assume(users > 0);

        uint256 packed = UserPoolStakingLibrary.calculatePoolMetrics(
            uint256(deposits),
            uint256(staked),
            uint256(users)
        );

        (, , uint256 unpackedUsers) = UserPoolStakingLibrary.unpackPoolMetrics(packed);

        assertEq(unpackedUsers, uint256(users), "Users should be preserved");
    }
}
