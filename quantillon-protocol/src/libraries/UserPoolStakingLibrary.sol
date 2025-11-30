// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {VaultMath} from "./VaultMath.sol";
import {CommonErrorLibrary} from "./CommonErrorLibrary.sol";

/**
 * @title UserPoolStakingLibrary
 * @notice Staking and reward calculation functions for UserPool to reduce contract size
 * @dev Extracted from UserPool to reduce bytecode size and improve maintainability
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
library UserPoolStakingLibrary {
    using VaultMath for uint256;

    // Constants
    uint256 public constant MIN_STAKE_AMOUNT = 1e18; // 1 QEURO minimum stake
    uint256 public constant MAX_STAKE_AMOUNT = 1000000e18; // 1M QEURO maximum stake
    uint256 public constant MIN_STAKE_DURATION = 1 days; // 1 day minimum stake duration
    uint256 public constant MAX_STAKE_DURATION = 365 days; // 1 year maximum stake duration
    uint256 public constant UNSTAKE_COOLDOWN = 7 days; // 7 days unstake cooldown
    uint256 public constant REWARD_CLAIM_COOLDOWN = 1 days; // 1 day reward claim cooldown

    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        uint256 lastRewardClaim;
        uint256 totalRewardsClaimed;
        bool isActive;
    }

    struct UserStakingData {
        uint256 totalStaked;
        uint256 totalRewardsEarned;
        uint256 totalRewardsClaimed;
        uint256 lastStakeTime;
        uint256 lastUnstakeTime;
        uint256 activeStakes;
    }

    /**
     * @notice Calculates staking rewards for a user
     * @dev Internal function to calculate rewards based on stake duration and APY
     * @param stakeInfo Stake information
     * @param stakingAPY Staking APY in basis points
     * @param currentTime Current timestamp
     * @return rewards Calculated rewards
     * @custom:security No security implications - pure calculation function
     * @custom:validation Input validation handled by calling function
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - pure function
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal function
     * @custom:oracle No oracle dependencies
     */
    function _calculateStakingRewards(
        StakeInfo memory stakeInfo,
        uint256 stakingAPY,
        uint256 currentTime
    ) internal pure returns (uint256 rewards) {
        if (!stakeInfo.isActive || currentTime < stakeInfo.lastRewardClaim) {
            return 0;
        }

        uint256 timeElapsed = currentTime - stakeInfo.lastRewardClaim;
        uint256 stakeDuration = currentTime - stakeInfo.startTime;
        
        // Check minimum stake duration
        if (stakeDuration < MIN_STAKE_DURATION) {
            return 0;
        }

        // Calculate rewards based on APY and time elapsed
        rewards = (stakeInfo.amount * stakingAPY * timeElapsed) / (365 days * 10000);
        
        // Apply bonus for longer stake duration
        if (stakeDuration > 30 days) {
            uint256 bonusMultiplier = 10000 + ((stakeDuration - 30 days) * 100) / (365 days - 30 days);
            rewards = (rewards * bonusMultiplier) / 10000;
        }
    }

    /**
     * @notice Public wrapper for calculateStakingRewards
     * @dev Public interface for calculating staking rewards
     * @param stakeInfo Stake information
     * @param stakingAPY Staking APY in basis points
     * @param currentTime Current timestamp
     * @return rewards Calculated rewards
     * @custom:security No security implications - pure calculation function
     * @custom:validation Input validation handled by calling contract
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - pure function
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public function
     * @custom:oracle No oracle dependencies
     */
    function calculateStakingRewards(
        StakeInfo memory stakeInfo,
        uint256 stakingAPY,
        uint256 currentTime
    ) external pure returns (uint256 rewards) {
        return _calculateStakingRewards(stakeInfo, stakingAPY, currentTime);
    }

    /**
     * @notice Calculates total staking rewards for a user
     * @dev Calculates total rewards across all active stakes for a user
     * @param userStakes Array of user stakes
     * @param stakingAPY Staking APY in basis points
     * @param currentTime Current timestamp
     * @return totalRewards Total rewards for all stakes
     * @custom:security No security implications - pure calculation function
     * @custom:validation Input validation handled by calling contract
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - pure function
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public function
     * @custom:oracle No oracle dependencies
     */
    function calculateTotalStakingRewards(
        StakeInfo[] memory userStakes,
        uint256 stakingAPY,
        uint256 currentTime
    ) external pure returns (uint256 totalRewards) {
        for (uint256 i = 0; i < userStakes.length; i++) {
            if (userStakes[i].isActive) {
                totalRewards += _calculateStakingRewards(userStakes[i], stakingAPY, currentTime);
            }
        }
    }

    /**
     * @notice Validates stake parameters
     * @dev Ensures stake parameters are within acceptable bounds
     * @param amount Stake amount
     * @param duration Stake duration
     * @param userStakingData User's current staking data
     * @custom:security Prevents invalid stake parameters from being processed
     * @custom:validation Validates amounts, durations, and user limits
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws various validation errors for invalid inputs
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public function
     * @custom:oracle No oracle dependencies
     */
    function validateStakeParameters(
        uint256 amount,
        uint256 duration,
        UserStakingData memory userStakingData
    ) external pure {
        if (amount < MIN_STAKE_AMOUNT) {
            revert CommonErrorLibrary.InsufficientBalance();
        }
        
        if (amount > MAX_STAKE_AMOUNT) {
            revert CommonErrorLibrary.AboveLimit();
        }
        
        if (duration < MIN_STAKE_DURATION) {
            revert CommonErrorLibrary.HoldingPeriodNotMet();
        }
        
        if (duration > MAX_STAKE_DURATION) {
            revert CommonErrorLibrary.AboveLimit();
        }
        
        // Check if user has too many active stakes
        if (userStakingData.activeStakes >= 10) {
            revert CommonErrorLibrary.TooManyPositions();
        }
    }

    /**
     * @notice Validates unstake parameters
     * @dev Ensures unstake operations meet minimum requirements
     * @param stakeInfo Stake information
     * @param currentTime Current timestamp
     * @custom:security Prevents premature unstaking and enforces cooldowns
     * @custom:validation Validates stake status and timing requirements
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws various validation errors for invalid unstake attempts
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public function
     * @custom:oracle No oracle dependencies
     */
    function validateUnstakeParameters(
        StakeInfo memory stakeInfo,
        uint256 currentTime
    ) external pure {
        if (!stakeInfo.isActive) {
            revert CommonErrorLibrary.PositionNotActive();
        }
        
        // Check minimum stake duration
        uint256 stakeDuration = currentTime - stakeInfo.startTime;
        if (stakeDuration < MIN_STAKE_DURATION) {
            revert CommonErrorLibrary.HoldingPeriodNotMet();
        }
        
        // Check unstake cooldown
        if (currentTime - stakeInfo.lastRewardClaim < UNSTAKE_COOLDOWN) {
            revert CommonErrorLibrary.LiquidationCooldown();
        }
    }

    /**
     * @notice Calculates unstake penalty
     * @dev Calculates penalty based on stake duration to discourage early unstaking
     * @param stakeInfo Stake information
     * @param currentTime Current timestamp
     * @return penalty Penalty percentage in basis points
     * @custom:security No security implications - pure calculation function
     * @custom:validation Input validation handled by calling contract
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - pure function
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public function
     * @custom:oracle No oracle dependencies
     */
    function calculateUnstakePenalty(
        StakeInfo memory stakeInfo,
        uint256 currentTime
    ) external pure returns (uint256 penalty) {
        uint256 stakeDuration = currentTime - stakeInfo.startTime;
        
        if (stakeDuration < 7 days) {
            penalty = 1000; // 10% penalty
        } else if (stakeDuration < 30 days) {
            penalty = 500; // 5% penalty
        } else if (stakeDuration < 90 days) {
            penalty = 200; // 2% penalty
        } else {
            penalty = 0; // No penalty
        }
    }

    /**
     * @notice Calculates deposit APY based on pool metrics
     * @dev Adjusts deposit APY based on staking ratio to incentivize optimal behavior
     * @param totalDeposits Total pool deposits
     * @param totalStaked Total staked amount
     * @param baseAPY Base APY in basis points
     * @return depositAPY Calculated deposit APY
     * @custom:security No security implications - pure calculation function
     * @custom:validation Input validation handled by calling contract
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - pure function
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public function
     * @custom:oracle No oracle dependencies
     */
    function calculateDepositAPY(
        uint256 totalDeposits,
        uint256 totalStaked,
        uint256 baseAPY
    ) external pure returns (uint256 depositAPY) {
        if (totalDeposits == 0) {
            return baseAPY;
        }
        
        // Calculate staking ratio
        uint256 stakingRatio = (totalStaked * 10000) / totalDeposits;
        
        // Adjust APY based on staking ratio
        if (stakingRatio < 2000) { // Less than 20% staked
            depositAPY = baseAPY + 500; // +5% bonus
        } else if (stakingRatio > 8000) { // More than 80% staked
            depositAPY = baseAPY - 300; // -3% reduction
        } else {
            depositAPY = baseAPY;
        }
    }

    /**
     * @notice Calculates staking APY based on pool metrics
     * @dev Adjusts staking APY based on staking ratio to incentivize optimal behavior
     * @param totalDeposits Total pool deposits
     * @param totalStaked Total staked amount
     * @param baseAPY Base APY in basis points
     * @return stakingAPY Calculated staking APY
     * @custom:security No security implications - pure calculation function
     * @custom:validation Input validation handled by calling contract
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - pure function
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public function
     * @custom:oracle No oracle dependencies
     */
    function calculateStakingAPY(
        uint256 totalDeposits,
        uint256 totalStaked,
        uint256 baseAPY
    ) external pure returns (uint256 stakingAPY) {
        if (totalDeposits == 0) {
            return baseAPY;
        }
        
        // Calculate staking ratio
        uint256 stakingRatio = (totalStaked * 10000) / totalDeposits;
        
        // Adjust APY based on staking ratio
        if (stakingRatio < 2000) { // Less than 20% staked
            stakingAPY = baseAPY + 1000; // +10% bonus
        } else if (stakingRatio > 8000) { // More than 80% staked
            stakingAPY = baseAPY - 500; // -5% reduction
        } else {
            stakingAPY = baseAPY;
        }
    }

    /**
     * @notice Calculates fee for deposit/withdrawal
     * @dev Adjusts fees based on pool utilization to manage liquidity
     * @param amount Transaction amount
     * @param baseFee Base fee in basis points
     * @param poolUtilization Pool utilization ratio
     * @return fee Calculated fee amount
     * @custom:security No security implications - pure calculation function
     * @custom:validation Input validation handled by calling contract
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - pure function
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public function
     * @custom:oracle No oracle dependencies
     */
    function calculateDynamicFee(
        uint256 amount,
        uint256 baseFee,
        uint256 poolUtilization
    ) external pure returns (uint256 fee) {
        // Base fee calculation
        fee = (amount * baseFee) / 10000;
        
        // Dynamic adjustment based on pool utilization
        if (poolUtilization > 9000) { // More than 90% utilized
            fee = (fee * 150) / 100; // +50% fee increase
        } else if (poolUtilization < 3000) { // Less than 30% utilized
            fee = (fee * 50) / 100; // -50% fee reduction
        }
    }

    /**
     * @notice Calculates pool metrics
     * @dev Packs pool metrics into a single uint256 for gas efficiency
     * @param totalDeposits Total pool deposits
     * @param totalStaked Total staked amount
     * @param totalUsers Total number of users
     * @return metrics Packed pool metrics
     * @custom:security No security implications - pure calculation function
     * @custom:validation Input validation handled by calling contract
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - pure function
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public function
     * @custom:oracle No oracle dependencies
     */
    function calculatePoolMetrics(
        uint256 totalDeposits,
        uint256 totalStaked,
        uint256 totalUsers
    ) external pure returns (uint256 metrics) {
        uint256 stakingRatio = totalDeposits > 0 ? (totalStaked * 10000) / totalDeposits : 0;
        uint256 averageDeposit = totalUsers > 0 ? totalDeposits / totalUsers : 0;
        
        // Pack metrics into a single uint256
        metrics = (stakingRatio << 128) | (averageDeposit << 64) | totalUsers;
    }

    /**
     * @notice Unpacks pool metrics
     * @dev Unpacks pool metrics from a single uint256 for gas efficiency
     * @param metrics Packed pool metrics
     * @return stakingRatio Staking ratio in basis points
     * @return averageDeposit Average deposit per user
     * @return totalUsers Total number of users
     * @custom:security No security implications - pure calculation function
     * @custom:validation Input validation handled by calling contract
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - pure function
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public function
     * @custom:oracle No oracle dependencies
     */
    function unpackPoolMetrics(uint256 metrics) external pure returns (
        uint256 stakingRatio,
        uint256 averageDeposit,
        uint256 totalUsers
    ) {
        stakingRatio = metrics >> 128;
        averageDeposit = (metrics >> 64) & 0xFFFFFFFFFFFFFFFF;
        totalUsers = metrics & 0xFFFFFFFFFFFFFFFF;
    }
}
