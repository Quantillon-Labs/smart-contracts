// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {CommonErrorLibrary} from "./CommonErrorLibrary.sol";

/**
 * @title PriceValidationLibrary
 * @notice Library for price validation and deviation checks
 * 
 * @dev Main characteristics:
 *      - Price deviation checks to prevent flash loan attacks
 *      - Block-based validation for price freshness
 *      - Reduces code duplication across contracts
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
library PriceValidationLibrary {
    /**
     * @notice Checks if price deviation exceeds maximum allowed
     * @dev Only checks deviation if enough blocks have passed since last update
     * @param currentPrice Current price from oracle
     * @param lastValidPrice Last valid cached price
     * @param maxDeviation Maximum allowed deviation in basis points
     * @param lastUpdateBlock Block number of last price update
     * @param minBlocksBetweenUpdates Minimum blocks required between updates
     * @return shouldRevert True if deviation check should cause revert
     * @return deviationBps Calculated deviation in basis points
     * @custom:security Prevents flash loan attacks by validating price deviations
     * @custom:validation Validates price changes are within acceptable bounds
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - returns boolean flag
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal library function - no access restrictions
     * @custom:oracle Uses provided price parameters (no direct oracle calls)
     */
    function checkPriceDeviation(
        uint256 currentPrice,
        uint256 lastValidPrice,
        uint256 maxDeviation,
        uint256 lastUpdateBlock,
        uint256 minBlocksBetweenUpdates
    ) internal view returns (bool shouldRevert, uint256 deviationBps) {
        // Only check deviation if enough blocks have passed since last update
        if (lastValidPrice > 0 && block.number > lastUpdateBlock + minBlocksBetweenUpdates) {
            uint256 priceDiff = currentPrice > lastValidPrice ? 
                currentPrice - lastValidPrice : lastValidPrice - currentPrice;
            deviationBps = priceDiff * 10000 / lastValidPrice;
            
            if (deviationBps > maxDeviation) {
                return (true, deviationBps);
            }
        }
        return (false, 0);
    }
}

