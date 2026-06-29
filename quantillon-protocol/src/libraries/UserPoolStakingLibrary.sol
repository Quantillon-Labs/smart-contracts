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
    /**
     * @notice Returns the semantic version of this linked library.
     * @dev On-chain version of the standalone deployed library; bump per semver on any change.
     *      See deployments/{chainId}/versions.json for deployed-address provenance.
     * @return Semantic version string (e.g. "1.0.0").
     * @custom:security No security implications - returns a compile-time constant.
     * @custom:validation No input validation required.
     * @custom:state-changes None - pure function.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable - pure function.
     * @custom:access Public - anyone can read the version.
     * @custom:oracle No oracle dependencies.
     */
    function version() external pure returns (string memory) {
        return "1.0.0";
    }

    using VaultMath for uint256;

    // Constants
    uint256 public constant MIN_STAKE_AMOUNT = 1e18; // 1 QEURO minimum stake
    uint256 public constant MAX_STAKE_AMOUNT = 1000000e18; // 1M QEURO maximum stake
    uint256 public constant MIN_STAKE_DURATION = 1 days; // 1 day minimum stake duration
    uint256 public constant MAX_STAKE_DURATION = 365 days; // 1 year maximum stake duration
    uint256 public constant UNSTAKE_COOLDOWN = 7 days; // 7 days unstake cooldown

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

}
