// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title VaultMath
 * @notice Mathematical operations library for Quantillon Protocol
 * 
 * @dev This library provides essential mathematical utilities:
 *      - Percentage calculations for fees and yield distributions
 *      - Min/max value selection for safe boundaries
 *      - Decimal scaling utilities for different token precisions
 * 
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
library VaultMath {
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
     */
    function mulDiv(uint256 a, uint256 b, uint256 c) internal pure returns (uint256 result) {
        require(c != 0, "VaultMath: Division by zero");
        
        // Handle overflow protection
        uint256 prod = a * b;
        require(a == 0 || prod / a == b, "VaultMath: Multiplication overflow");
        
        result = prod / c;
        
        // Round up if remainder is >= c/2
        if (prod % c >= c / 2) {
            result += 1;
        }
    }

    /**
     * @notice Calculate percentage of a value
     * @param value Base value
     * @param percentage Percentage in basis points (e.g., 500 = 5%)
     * @return Calculated percentage value
     * @dev Used for fee calculations across all contracts
     */
    function percentageOf(uint256 value, uint256 percentage) internal pure returns (uint256) {
        require(percentage <= MAX_PERCENTAGE, "VaultMath: Percentage too high");
        return mulDiv(value, percentage, BASIS_POINTS);
    }

    /**
     * @notice Scale a value between different decimal precisions with proper rounding
     * @param value Original value
     * @param fromDecimals Original decimal places
     * @param toDecimals Target decimal places
     * @return scaledValue Scaled value with proper rounding
     * @dev Used for converting between token precisions (e.g., USDC 6 decimals to 18 decimals)
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

    /**
     * @notice Calculate minimum value between two numbers
     * @param a First number
     * @param b Second number
     * @return Minimum value
     * @dev Used for safe boundary calculations in yield management and vault operations
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @notice Calculate maximum value between two numbers
     * @param a First number
     * @param b Second number
     * @return Maximum value
     * @dev Used in tests and edge case calculations
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @notice Convert EUR amount to USD using exchange rate
     * @param eurAmount Amount in EUR (18 decimals)
     * @param eurUsdRate EUR/USD exchange rate (18 decimals)
     * @return usdAmount Amount in USD (18 decimals)
     * @dev Used in tests for currency conversion
     */
    function eurToUsd(
        uint256 eurAmount,
        uint256 eurUsdRate
    ) internal pure returns (uint256 usdAmount) {
        usdAmount = mulDiv(eurAmount, eurUsdRate, PRECISION);
    }

    /**
     * @notice Convert USD amount to EUR using exchange rate
     * @param usdAmount Amount in USD (18 decimals)
     * @param eurUsdRate EUR/USD exchange rate (18 decimals)
     * @return eurAmount Amount in EUR (18 decimals)
     * @dev Used in tests for currency conversion
     */
    function usdToEur(
        uint256 usdAmount,
        uint256 eurUsdRate
    ) internal pure returns (uint256 eurAmount) {
        eurAmount = mulDiv(usdAmount, PRECISION, eurUsdRate);
    }

    /**
     * @notice Calculate collateralization ratio
     * @param collateralValue Total collateral value in USD
     * @param debtValue Total debt value in USD  
     * @return ratio Collateralization ratio in 18 decimals (e.g., 1.5e18 = 150%)
     * @dev Used in tests for collateral calculations
     */
    function calculateCollateralRatio(
        uint256 collateralValue,
        uint256 debtValue
    ) internal pure returns (uint256 ratio) {
        if (debtValue == 0) {
            return type(uint256).max; // Infinite ratio when no debt
        }
        
        ratio = mulDiv(collateralValue, PRECISION, debtValue);
    }

    /**
     * @notice Calculate yield distribution between users and hedgers
     * @param totalYield Total yield generated
     * @param yieldShiftBps Yield shift percentage in basis points (0-10000)
     * @return userYield Yield allocated to QEURO users
     * @return hedgerYield Yield allocated to hedgers
     * @dev Used in tests for yield calculations
     */
    function calculateYieldDistribution(
        uint256 totalYield,
        uint256 yieldShiftBps
    ) internal pure returns (uint256 userYield, uint256 hedgerYield) {
        require(yieldShiftBps <= BASIS_POINTS, "VaultMath: Invalid yield shift");
        
        hedgerYield = percentageOf(totalYield, yieldShiftBps);
        userYield = totalYield - hedgerYield;
    }

    /**
     * @notice Check if a value is within a certain percentage of another value
     * @param value1 First value
     * @param value2 Second value
     * @param toleranceBps Tolerance in basis points
     * @return isWithinTolerance Whether values are within tolerance
     * @dev Used in tests for tolerance checks
     */
    function isWithinTolerance(
        uint256 value1,
        uint256 value2,
        uint256 toleranceBps
    ) internal pure returns (bool) {
        if (value1 == value2) return true;
        
        uint256 larger = max(value1, value2);
        uint256 smaller = min(value1, value2);
        uint256 difference = larger - smaller;
        uint256 toleranceAmount = percentageOf(larger, toleranceBps);
        
        return difference <= toleranceAmount;
    }
}