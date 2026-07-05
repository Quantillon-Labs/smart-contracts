// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {VaultMath} from "./VaultMath.sol";

/**
 * @title YieldShiftCalculationLibrary
 * @notice Calculation functions for YieldShift to reduce contract size
 * @dev Extracted from YieldShift to reduce bytecode size
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
library YieldShiftCalculationLibrary {
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
        return "1.0.1";
    }

    using VaultMath for uint256;

    /**
     * @notice Calculates optimal yield shift based on pool ratio
     * @dev Calculates optimal yield shift to balance user and hedger pools
     * @param poolRatio Current pool ratio (user/hedger)
     * @param baseYieldShift Base yield shift percentage
     * @param maxYieldShift Maximum yield shift percentage
     * @param targetPoolRatio Target pool ratio
     * @return optimalShift Optimal yield shift percentage
     * @custom:security No security implications - pure calculation function
     * @custom:validation Input validation handled by calling contract
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - pure function
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public function
     * @custom:oracle No oracle dependencies
     */
    function calculateOptimalYieldShift(
        uint256 poolRatio,
        uint256 baseYieldShift,
        uint256 maxYieldShift,
        uint256 targetPoolRatio
    ) external pure returns (uint256 optimalShift) {
        // `optimalShift` is the USER share of yield (hedgers get the remainder), and
        // `poolRatio = userPool / hedgerPool` (higher = user pool bigger). The shift
        // must incentivize the DEFICIENT pool, so a larger user pool LOWERS the user
        // share (more to hedgers) and vice-versa. Audit SC2-2: both the edge cases and
        // the deviation branches below were inverted (they routed yield to the already-
        // oversized pool); corrected here.
        if (poolRatio == type(uint256).max) {
            // Edge case: hedger pool is zero (maximally under-hedged) -> give hedgers
            // the most -> user share at the floor.
            return 10000 - maxYieldShift;
        }

        if (poolRatio == 0) {
            // Edge case: user pool is zero (maximally over-hedged) -> give users the most.
            return maxYieldShift;
        }

        // Calculate deviation from target ratio
        uint256 deviation;
        if (poolRatio > targetPoolRatio) {
            // User pool is larger than target - shift more yield to hedgers (lower user share)
            deviation = poolRatio - targetPoolRatio;
            uint256 reduction = (deviation * 100) / targetPoolRatio;
            optimalShift = reduction < baseYieldShift ? baseYieldShift - reduction : 0;
        } else {
            // Hedger pool is larger than target - shift more yield to users (raise user share)
            deviation = targetPoolRatio - poolRatio;
            optimalShift = baseYieldShift + (deviation * 100) / targetPoolRatio;
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
     * @dev Gradually adjusts yield shift to prevent sudden changes
     * @param currentShift Current yield shift
     * @param targetShift Target yield shift
     * @param adjustmentSpeed Adjustment speed (basis points per update)
     * @return newShift New yield shift after adjustment
     * @custom:security No security implications - pure calculation function
     * @custom:validation Input validation handled by calling contract
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - pure function
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public function
     * @custom:oracle No oracle dependencies
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

}
