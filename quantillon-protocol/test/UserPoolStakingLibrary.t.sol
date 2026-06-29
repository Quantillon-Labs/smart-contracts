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

}
