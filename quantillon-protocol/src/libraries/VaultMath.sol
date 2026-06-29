// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {CommonErrorLibrary} from "./CommonErrorLibrary.sol";

/**
 * @title VaultMath
 * @notice Mathematical operations library for Quantillon Protocol
 * 
 * @dev This library provides essential mathematical utilities:
 *      - Percentage calculations for fees and yield distributions
 *      - Min/max value selection for safe boundaries
 *      - Decimal scaling utilities for different token precisions
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
library VaultMath {
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

    /// @notice Precision for percentage calculations (10000 = 100%)
    uint256 public constant BASIS_POINTS = 10000;
    
    /// @notice High precision scalar (18 decimals)
    uint256 public constant PRECISION = 1e18;
    
    /// @notice Maximum allowed percentage (10000%)
    uint256 public constant MAX_PERCENTAGE = 1000000;

    /**
     * @notice Multiply two numbers and divide by a third with rounding
     * @param a First number
     * @param b Second number  
     * @param c Divisor
     * @return result a * b / c with proper rounding
     * @dev Used by percentageOf for fee calculations
     * @custom:security Prevents division by zero and multiplication overflow
     * @custom:validation Validates c != 0, checks for multiplication overflow
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws "Division by zero" if c is 0, "Multiplication overflow" if overflow
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function mulDiv(uint256 a, uint256 b, uint256 c) internal pure returns (uint256 result) {
        if (c == 0) revert CommonErrorLibrary.DivisionByZero();
        // INFO-6: Solidity 0.8.x checked arithmetic reverts on overflow automatically;
        // the manual overflow guard below was unreachable dead code.
        result = (a * b) / c;
    }

    /**
     * @notice Calculate percentage of a value
     * @param value Base value
     * @param percentage Percentage in basis points (e.g., 500 = 5%)
     * @return Calculated percentage value
     * @dev Used for fee calculations across all contracts
     * @custom:security Prevents percentage overflow and division by zero
     * @custom:validation Validates percentage <= MAX_PERCENTAGE
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws "Percentage too high" if percentage > MAX_PERCENTAGE
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function percentageOf(uint256 value, uint256 percentage) internal pure returns (uint256) {
        if (percentage > MAX_PERCENTAGE) revert CommonErrorLibrary.PercentageTooHigh();
        return mulDiv(value, percentage, BASIS_POINTS);
    }

    /**
     * @notice Scale a value between different decimal precisions with proper rounding
     * @param value Original value
     * @param fromDecimals Original decimal places
     * @param toDecimals Target decimal places
     * @return scaledValue Scaled value with proper rounding
     * @dev Used for converting between token precisions (e.g., USDC 6 decimals to 18 decimals)
     * @custom:security Pure; no overflow for typical decimals
     * @custom:validation fromDecimals/toDecimals are uint8
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy No external calls
     * @custom:access Internal library
     * @custom:oracle None
     */
    function scaleDecimals(
        uint256 value,
        uint8 fromDecimals,
        uint8 toDecimals
    ) internal pure returns (uint256 scaledValue) {
        if (fromDecimals == toDecimals) {
            return value;
        } else if (fromDecimals < toDecimals) {
            // Increase precision: multiply
            scaledValue = value * (10 ** (toDecimals - fromDecimals));
        } else {
            // Decrease precision: divide with proper rounding
            uint256 divisor = 10 ** (fromDecimals - toDecimals);
            uint256 remainder = value % divisor;
            scaledValue = value / divisor;
            
            // Round up if remainder is >= divisor/2
            if (remainder >= divisor / 2) {
                scaledValue += 1;
            }
        }
    }

}