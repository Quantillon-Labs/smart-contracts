// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VaultMath} from "./VaultMath.sol";

/**
 * @title YieldShiftCalculationLibrary
 * @notice Calculation functions for YieldShift to reduce contract size
 * @dev Extracted from YieldShift to reduce bytecode size
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
library YieldShiftCalculationLibrary {
    using VaultMath for uint256;

    /**
     * @notice Calculates optimal yield shift based on pool ratio
     * @param poolRatio Current pool ratio (user/hedger)
     * @param baseYieldShift Base yield shift percentage
     * @param maxYieldShift Maximum yield shift percentage
     * @param targetPoolRatio Target pool ratio
     * @return optimalShift Optimal yield shift percentage
     */
    function calculateOptimalYieldShift(
        uint256 poolRatio,
        uint256 baseYieldShift,
        uint256 maxYieldShift,
        uint256 targetPoolRatio
    ) external pure returns (uint256 optimalShift) {
        if (poolRatio == type(uint256).max) {
            // Edge case: hedger pool is zero
            return maxYieldShift;
        }
        
        if (poolRatio == 0) {
            // Edge case: user pool is zero
            return 0;
        }
        
        // Calculate deviation from target ratio
        uint256 deviation;
        if (poolRatio > targetPoolRatio) {
            // User pool is larger than target - shift more yield to hedgers
            deviation = poolRatio - targetPoolRatio;
            optimalShift = baseYieldShift + (deviation * 100) / targetPoolRatio;
        } else {
            // Hedger pool is larger than target - shift more yield to users
            deviation = targetPoolRatio - poolRatio;
            optimalShift = baseYieldShift - (deviation * 100) / targetPoolRatio;
        }
        
        // Clamp to valid range
        if (optimalShift > maxYieldShift) {
            optimalShift = maxYieldShift;
        }
        if (optimalShift < (10000 - maxYieldShift)) {
            optimalShift = 10000 - maxYieldShift;
        }
        
        return optimalShift;
    }

    /**
     * @notice Applies gradual adjustment to yield shift
     * @param currentShift Current yield shift
     * @param targetShift Target yield shift
     * @param adjustmentSpeed Adjustment speed (basis points per update)
     * @return newShift New yield shift after adjustment
     */
    function applyGradualAdjustment(
        uint256 currentShift,
        uint256 targetShift,
        uint256 adjustmentSpeed
    ) external pure returns (uint256 newShift) {
        if (currentShift == targetShift) {
            return currentShift;
        }
        
        uint256 difference = currentShift > targetShift ? 
            currentShift - targetShift : targetShift - currentShift;
        
        uint256 adjustment = (difference * adjustmentSpeed) / 10000;
        if (adjustment == 0) {
            adjustment = 1; // Minimum adjustment
        }
        
        if (currentShift > targetShift) {
            newShift = currentShift - adjustment;
            if (newShift < targetShift) {
                newShift = targetShift;
            }
        } else {
            newShift = currentShift + adjustment;
            if (newShift > targetShift) {
                newShift = targetShift;
            }
        }
        
        return newShift;
    }

    /**
     * @notice Calculates user allocation percentage
     * @param yieldShift Current yield shift percentage
     * @return userAllocation User allocation percentage
     */
    function calculateUserAllocation(uint256 yieldShift) external pure returns (uint256 userAllocation) {
        return 10000 - yieldShift;
    }

    /**
     * @notice Calculates hedger allocation percentage
     * @param yieldShift Current yield shift percentage
     * @return hedgerAllocation Hedger allocation percentage
     */
    function calculateHedgerAllocation(uint256 yieldShift) external pure returns (uint256 hedgerAllocation) {
        return yieldShift;
    }

    /**
     * @notice Calculates TWAP for pool sizes
     * @param snapshots Array of pool snapshots
     * @return userPoolTWAP TWAP for user pool size
     * @return hedgerPoolTWAP TWAP for hedger pool size
     */
    function calculatePoolTWAP(
        uint256[] memory snapshots
    ) external pure returns (uint256 userPoolTWAP, uint256 hedgerPoolTWAP) {
        if (snapshots.length == 0) {
            return (0, 0);
        }
        
        uint256 totalWeight = 0;
        uint256 weightedUserPool = 0;
        uint256 weightedHedgerPool = 0;
        
        for (uint256 i = 0; i < snapshots.length; i++) {
            // Extract data from packed snapshot (assuming 128 bits each)
            uint256 snapshot = snapshots[i];
            uint128 userPoolSize = uint128(snapshot);
            uint128 hedgerPoolSize = uint128(snapshot >> 128);
            
            // Calculate weight based on time proximity (simplified)
            uint256 weight = 1;
            if (i > 0) {
                weight = i + 1; // More recent = higher weight
            }
            
            weightedUserPool += userPoolSize * weight;
            weightedHedgerPool += hedgerPoolSize * weight;
            totalWeight += weight;
        }
        
        if (totalWeight > 0) {
            userPoolTWAP = weightedUserPool / totalWeight;
            hedgerPoolTWAP = weightedHedgerPool / totalWeight;
        }
    }

    /**
     * @notice Calculates yield distribution amounts
     * @param totalYield Total yield to distribute
     * @param userAllocation User allocation percentage
     * @param hedgerAllocation Hedger allocation percentage
     * @return userYield User yield amount
     * @return hedgerYield Hedger yield amount
     */
    function calculateYieldDistribution(
        uint256 totalYield,
        uint256 userAllocation,
        uint256 hedgerAllocation
    ) external pure returns (uint256 userYield, uint256 hedgerYield) {
        userYield = (totalYield * userAllocation) / 10000;
        hedgerYield = (totalYield * hedgerAllocation) / 10000;
    }

    /**
     * @notice Validates yield shift parameters
     * @param baseYieldShift Base yield shift
     * @param maxYieldShift Maximum yield shift
     * @param adjustmentSpeed Adjustment speed
     * @param targetPoolRatio Target pool ratio
     */
    function validateYieldShiftParams(
        uint256 baseYieldShift,
        uint256 maxYieldShift,
        uint256 adjustmentSpeed,
        uint256 targetPoolRatio
    ) external pure {
        require(baseYieldShift <= 10000, "Invalid base yield shift");
        require(maxYieldShift <= 10000, "Invalid max yield shift");
        require(adjustmentSpeed <= 10000, "Invalid adjustment speed");
        require(targetPoolRatio > 0, "Invalid target pool ratio");
        require(baseYieldShift <= maxYieldShift, "Base shift exceeds max shift");
    }
}
