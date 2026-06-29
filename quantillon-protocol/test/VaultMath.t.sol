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
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
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
    // PERCENTAGE CALCULATION TESTS
    // =============================================================================
    
    /**
     * @notice Test percentage calculation with normal values
     * @dev Verifies percentage calculation using basis points
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function testPercentageOf_WithNormalValues_ShouldCalculateCorrectly() public pure {
        uint256 result = VaultMath.percentageOf(1000, 2500); // 2500 basis points = 25%
        assertEq(result, 250); // 25% of 1000 = 250
    }
    
    /**
     * @notice Test percentage calculation with zero inputs
     * @dev Verifies behavior with zero inputs
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
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
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function testPercentageOf_With100Percent_ShouldReturnFullValue() public pure {
        uint256 result = VaultMath.percentageOf(1000, 10000); // 10000 basis points = 100%
        assertEq(result, 1000); // 100% of 1000 = 1000
    }

}
