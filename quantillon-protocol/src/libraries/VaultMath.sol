// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title VaultMath
 * @notice Mathematical operations library for Quantillon Protocol
 * 
 * @dev Main characteristics:
 *      - Safe mathematical operations with overflow protection
 *      - High precision financial calculations for collateral and debt ratios
 *      - Currency conversion between EUR and USD with proper precision handling
 *      - Yield distribution and compound interest calculations
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
     */
    function percentageOf(uint256 value, uint256 percentage) internal pure returns (uint256) {
        require(percentage <= MAX_PERCENTAGE, "VaultMath: Percentage too high");
        return mulDiv(value, percentage, BASIS_POINTS);
    }

    /**
     * @notice Calculate collateralization ratio
     * @param collateralValue Total collateral value in USD
     * @param debtValue Total debt value in USD  
     * @return ratio Collateralization ratio in 18 decimals (e.g., 1.5e18 = 150%)
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
     * @notice Calculate liquidation penalty amount
     * @param collateralAmount Amount of collateral being liquidated
     * @param penaltyRate Penalty rate in basis points
     * @return penalty Penalty amount in collateral tokens
     */
    function calculateLiquidationPenalty(
        uint256 collateralAmount,
        uint256 penaltyRate
    ) internal pure returns (uint256 penalty) {
        penalty = percentageOf(collateralAmount, penaltyRate);
    }

    /**
     * @notice Convert EUR amount to USD using exchange rate
     * @param eurAmount Amount in EUR (18 decimals)
     * @param eurUsdRate EUR/USD exchange rate (18 decimals)
     * @return usdAmount Amount in USD (18 decimals)
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
     */
    function usdToEur(
        uint256 usdAmount,
        uint256 eurUsdRate
    ) internal pure returns (uint256 eurAmount) {
        eurAmount = mulDiv(usdAmount, PRECISION, eurUsdRate);
    }

    /**
     * @notice Convert USD amount to EUR using exchange rate with USDC precision handling
     * @param usdAmount Amount in USD (6 decimals for USDC)
     * @param eurUsdRate EUR/USD exchange rate (18 decimals)
     * @return eurAmount Amount in EUR (18 decimals)
     */
    function usdToEurWithUsdcPrecision(
        uint256 usdAmount,
        uint256 eurUsdRate
    ) internal pure returns (uint256 eurAmount) {
        // Convert USDC (6 decimals) to 18 decimals for calculation
        uint256 usdAmount18 = scaleDecimals(usdAmount, 6, 18);
        eurAmount = mulDiv(usdAmount18, PRECISION, eurUsdRate);
    }

    /**
     * @notice Convert EUR amount to USD using exchange rate with USDC precision handling
     * @param eurAmount Amount in EUR (18 decimals)
     * @param eurUsdRate EUR/USD exchange rate (18 decimals)
     * @return usdAmount Amount in USD (6 decimals for USDC)
     */
    function eurToUsdWithUsdcPrecision(
        uint256 eurAmount,
        uint256 eurUsdRate
    ) internal pure returns (uint256 usdAmount) {
        // Calculate in 18 decimals
        uint256 usdAmount18 = mulDiv(eurAmount, eurUsdRate, PRECISION);
        // Convert to USDC precision (6 decimals) with proper rounding
        usdAmount = scaleDecimals(usdAmount18, 18, 6);
    }

    /**
     * @notice Calculate required USDC collateral for given QEURO debt amount
     * @param debtAmount Debt amount in QEURO (18 decimals)
     * @param eurUsdRate EUR/USD exchange rate (18 decimals)
     * @param collateralRatio Required collateral ratio (e.g., 1.01e18 for 101%)
     * @return requiredCollateral Required USDC collateral amount (6 decimals)
     */
    function calculateRequiredUsdcCollateral(
        uint256 debtAmount,
        uint256 eurUsdRate,
        uint256 collateralRatio
    ) internal pure returns (uint256 requiredCollateral) {
        // Convert QEURO debt to USD value in 18 decimals
        uint256 debtValueUsd18 = eurToUsd(debtAmount, eurUsdRate);
        
        // Apply collateral ratio in 18 decimals
        uint256 requiredCollateral18 = mulDiv(debtValueUsd18, collateralRatio, PRECISION);
        
        // Convert to USDC precision (6 decimals) with proper rounding
        requiredCollateral = scaleDecimals(requiredCollateral18, 18, 6);
    }

    /**
     * @notice Calculate maximum QEURO debt for given USDC collateral
     * @param collateralAmount USDC collateral amount (6 decimals)
     * @param eurUsdRate EUR/USD exchange rate (18 decimals)
     * @param collateralRatio Required collateral ratio
     * @return maxDebt Maximum QEURO that can be minted (18 decimals)
     */
    function calculateMaxQeuroDebt(
        uint256 collateralAmount,
        uint256 eurUsdRate,
        uint256 collateralRatio
    ) internal pure returns (uint256 maxDebt) {
        // Convert USDC to 18 decimals for calculation
        uint256 collateralAmount18 = scaleDecimals(collateralAmount, 6, 18);
        
        // Calculate max USD debt value based on collateral
        uint256 maxDebtValueUsd = mulDiv(collateralAmount18, PRECISION, collateralRatio);
        
        // Convert to QEURO amount
        maxDebt = usdToEur(maxDebtValueUsd, eurUsdRate);
    }

    /**
     * @notice Check if collateral amount satisfies minimum ratio
     * @param collateralAmount USDC collateral amount
     * @param debtAmount QEURO debt amount
     * @param eurUsdRate EUR/USD exchange rate
     * @param minRatio Minimum required ratio
     * @return isValid Whether collateral is sufficient
     */
    function isCollateralSufficient(
        uint256 collateralAmount,
        uint256 debtAmount,
        uint256 eurUsdRate,
        uint256 minRatio
    ) internal pure returns (bool isValid) {
        if (debtAmount == 0) return true;
        
        uint256 debtValueUsd = eurToUsd(debtAmount, eurUsdRate);
        uint256 currentRatio = calculateCollateralRatio(collateralAmount, debtValueUsd);
        
        isValid = currentRatio >= minRatio;
    }

    /**
     * @notice Calculate yield distribution between users and hedgers
     * @param totalYield Total yield generated
     * @param yieldShiftBps Yield shift percentage in basis points (0-10000)
     * @return userYield Yield allocated to QEURO users
     * @return hedgerYield Yield allocated to hedgers
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
     * @notice Calculate compound interest
     * @param principal Initial principal amount
     * @param rate Annual interest rate in basis points
     * @param timeElapsed Time elapsed in seconds
     * @return newPrincipal Principal after compound interest
     */
    function calculateCompoundInterest(
        uint256 principal,
        uint256 rate,
        uint256 timeElapsed
    ) internal pure returns (uint256 newPrincipal) {
        if (timeElapsed == 0 || rate == 0) {
            return principal;
        }
        
        // Convert annual rate to per-second rate
        uint256 secondsPerYear = 365 days;
        uint256 ratePerSecond = mulDiv(rate, PRECISION, BASIS_POINTS * secondsPerYear);
        
        // Simple interest approximation for gas efficiency
        // For more precise compound interest, use exponential calculation
        uint256 interest = mulDiv(principal, ratePerSecond, PRECISION) * timeElapsed;
        newPrincipal = principal + interest;
    }

    /**
     * @notice Scale a value between different decimal precisions with proper rounding
     * @param value Original value
     * @param fromDecimals Original decimal places
     * @param toDecimals Target decimal places
     * @return scaledValue Scaled value with proper rounding
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
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @notice Calculate maximum value between two numbers
     * @param a First number
     * @param b Second number
     * @return Maximum value
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @notice Check if a value is within a certain percentage of another value
     * @param value1 First value
     * @param value2 Second value
     * @param toleranceBps Tolerance in basis points
     * @return isWithinTolerance Whether values are within tolerance
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