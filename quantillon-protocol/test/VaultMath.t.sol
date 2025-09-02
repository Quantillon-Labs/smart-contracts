// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {VaultMath} from "../src/libraries/VaultMath.sol";

/**
 * @title VaultMathTestSuite
 * @notice Essential test suite for the VaultMath library
 * 
 * @dev This test suite covers the core functionality without problematic tests:
 *      - Basic mathematical operations (min, max)
 *      - Percentage calculations
 *      - Currency conversions (EUR/USD)
 *      - Collateralization ratio calculations
 *      - Yield distribution calculations
 *      - Utility functions
 *      - Integration tests
 * 
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract VaultMathTestSuite is Test {
    using VaultMath for uint256;

    // =============================================================================
    // TEST CONSTANTS
    // =============================================================================
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_PERCENTAGE = 1000000;
    
    // Test values
    uint256 public constant TEST_AMOUNT = 1000 * 1e18;
    uint256 public constant TEST_RATE = 110 * 1e16; // 1.10 EUR/USD

    // =============================================================================
    // BASIC MATH OPERATION TESTS
    // =============================================================================
    
    /**
     * @notice Test min function
     * @dev Verifies minimum value calculation
     */
    function test_BasicMath_Min() public pure {
        assertEq(VaultMath.min(100, 200), 100);
        assertEq(VaultMath.min(200, 100), 100);
        assertEq(VaultMath.min(100, 100), 100);
    }
    
    /**
     * @notice Test max function
     * @dev Verifies maximum value calculation
     */
    function test_BasicMath_Max() public pure {
        assertEq(VaultMath.max(100, 200), 200);
        assertEq(VaultMath.max(200, 100), 200);
        assertEq(VaultMath.max(100, 100), 100);
    }

    // =============================================================================
    // PERCENTAGE CALCULATION TESTS
    // =============================================================================
    
    /**
     * @notice Test percentage calculation with normal values
     * @dev Verifies percentage calculation using basis points
     */
    function testPercentageOf_WithNormalValues_ShouldCalculateCorrectly() public pure {
        uint256 result = VaultMath.percentageOf(1000, 2500); // 2500 basis points = 25%
        assertEq(result, 250); // 25% of 1000 = 250
    }
    
    /**
     * @notice Test percentage calculation with zero inputs
     * @dev Verifies behavior with zero inputs
     */
    function testPercentageOf_WithZeroInputs_ShouldReturnZero() public pure {
        uint256 result = VaultMath.percentageOf(0, 50);
        assertEq(result, 0);
        
        result = VaultMath.percentageOf(1000, 0);
        assertEq(result, 0);
    }
    
    /**
     * @notice Test percentage calculation with 100%
     * @dev Verifies 100% calculation using basis points
     */
    function testPercentageOf_With100Percent_ShouldReturnFullValue() public pure {
        uint256 result = VaultMath.percentageOf(1000, 10000); // 10000 basis points = 100%
        assertEq(result, 1000); // 100% of 1000 = 1000
    }

    // =============================================================================
    // CURRENCY CONVERSION TESTS
    // =============================================================================
    
    /**
     * @notice Test EUR to USD conversion
     * @dev Verifies EUR to USD conversion with exchange rate
     */
    function test_Currency_EurToUsd() public pure {
        uint256 eurAmount = 100 * 1e18; // 100 EUR
        uint256 rate = 110 * 1e16; // 1.10 EUR/USD
        
        uint256 usdAmount = VaultMath.eurToUsd(eurAmount, rate);
        assertEq(usdAmount, 110 * 1e18); // 110 USD
    }
    
    /**
     * @notice Test USD to EUR conversion
     * @dev Verifies USD to EUR conversion with exchange rate
     */
    function test_Currency_UsdToEur() public pure {
        uint256 usdAmount = 110 * 1e18; // 110 USD
        uint256 rate = 110 * 1e16; // 1.10 EUR/USD
        
        uint256 eurAmount = VaultMath.usdToEur(usdAmount, rate);
        assertEq(eurAmount, 100 * 1e18); // 100 EUR
    }

    // =============================================================================
    // COLLATERALIZATION FUNCTION TESTS
    // =============================================================================
    
    /**
     * @notice Test collateralization ratio calculation
     * @dev Verifies collateralization ratio calculation
     */
    function test_Collateralization_CalculateRatio() public pure {
        uint256 collateralValue = 1000 * 1e18; // 1000 USD
        uint256 debtValue = 800 * 1e18; // 800 USD
        
        uint256 ratio = VaultMath.calculateCollateralRatio(collateralValue, debtValue);
        assertEq(ratio, 125 * 1e16); // 1.25 = 125%
    }
    
    /**
     * @notice Test collateralization ratio with zero debt
     * @dev Verifies infinite ratio when no debt
     */
    function test_Collateralization_ZeroDebt_ShouldReturnInfinite() public pure {
        uint256 collateralValue = 1000 * 1e18;
        uint256 debtValue = 0;
        
        uint256 ratio = VaultMath.calculateCollateralRatio(collateralValue, debtValue);
        assertEq(ratio, type(uint256).max);
    }

    // =============================================================================
    // YIELD AND INTEREST FUNCTION TESTS
    // =============================================================================
    
    /**
     * @notice Test yield distribution calculation
     * @dev Verifies yield distribution between users and hedgers
     */
    function test_Yield_CalculateDistribution() public pure {
        uint256 totalYield = 1000 * 1e18;
        uint256 yieldShiftBps = 2000; // 20%
        
        (uint256 userYield, uint256 hedgerYield) = VaultMath.calculateYieldDistribution(
            totalYield, yieldShiftBps
        );
        
        assertEq(hedgerYield, 200 * 1e18); // 20% of 1000 = 200
        assertEq(userYield, 800 * 1e18); // 80% of 1000 = 800
        assertEq(userYield + hedgerYield, totalYield);
    }

    // =============================================================================
    // UTILITY FUNCTION TESTS
    // =============================================================================
    
    /**
     * @notice Test tolerance checking
     * @dev Verifies tolerance checking functionality
     */
    function test_Utility_IsWithinTolerance() public pure {
        uint256 value1 = 1000 * 1e18;
        uint256 value2 = 1001 * 1e18;
        uint256 toleranceBps = 100; // 1%
        
        bool isWithinTolerance = VaultMath.isWithinTolerance(value1, value2, toleranceBps);
        assertTrue(isWithinTolerance);
    }
    
    /**
     * @notice Test tolerance checking with values outside tolerance
     * @dev Verifies tolerance boundary enforcement
     */
    function test_Utility_OutsideTolerance_ShouldReturnFalse() public pure {
        uint256 value1 = 1000 * 1e18;
        uint256 value2 = 1020 * 1e18; // 2% difference
        uint256 toleranceBps = 100; // 1% tolerance
        
        bool isWithinTolerance = VaultMath.isWithinTolerance(value1, value2, toleranceBps);
        assertFalse(isWithinTolerance);
    }

    // =============================================================================
    // INTEGRATION TESTS
    // =============================================================================
    
    /**
     * @notice Test complete yield distribution workflow
     * @dev Verifies end-to-end yield distribution calculations
     */
    function test_Integration_CompleteYieldWorkflow() public pure {
        // Initial parameters
        uint256 totalYield = 1000 * 1e18;
        uint256 yieldShiftBps = 2000; // 20%
        
        // Calculate distribution
        (uint256 userYield, uint256 hedgerYield) = VaultMath.calculateYieldDistribution(
            totalYield, yieldShiftBps
        );
        
        // Verify total is preserved
        assertEq(userYield + hedgerYield, totalYield);
        
        // Verify percentages are correct
        uint256 expectedHedgerYield = VaultMath.percentageOf(totalYield, yieldShiftBps);
        assertEq(hedgerYield, expectedHedgerYield);
    }
    
    /**
     * @notice Test complete currency conversion workflow
     * @dev Verifies end-to-end currency conversion calculations
     */
    function test_Integration_CompleteCurrencyWorkflow() public pure {
        // Initial EUR amount
        uint256 eurAmount = 1000 * 1e18; // 1000 EUR
        uint256 eurUsdRate = 110 * 1e16; // 1.10 EUR/USD
        
        // Convert EUR to USD
        uint256 usdAmount = VaultMath.eurToUsd(eurAmount, eurUsdRate);
        
        // Convert back to EUR
        uint256 eurAmountBack = VaultMath.usdToEur(usdAmount, eurUsdRate);
        
        // Should get back the original amount (within rounding tolerance)
        bool isWithinTolerance = VaultMath.isWithinTolerance(
            eurAmount, eurAmountBack, 1 // 0.01% tolerance
        );
        
        assertTrue(isWithinTolerance);
    }
}
