// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ChainlinkOracle} from "../src/oracle/ChainlinkOracle.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AggregatorV3Interface} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title OracleEdgeCases
 * @notice Comprehensive edge case testing for Oracle and Price Feed scenarios
 * 
 * @dev Tests extreme oracle conditions, price manipulation scenarios, and failure modes
 *      that could impact protocol security and stability.
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract OracleEdgeCases is Test {
    
    // ==================== STATE VARIABLES ====================
    
    MockAggregatorV3 public mockEurUsdFeed;
    MockAggregatorV3 public mockUsdcUsdFeed;
    ChainlinkOracle public oracle;
    TimeProvider public timeProvider;
    
    // Test accounts
    address public admin = address(0x1);
    address public governance = address(0x2);
    address public emergencyRole = address(0x3);
    address public oracleManager = address(0x4);
    address public treasury = address(0x5);
    
    // ==================== CONSTANTS ====================
    
    uint256 constant PRECISION = 1e8; // 8 decimals for Chainlink feeds
    uint256 constant MAX_PRICE = 140 * 1e16; // $1.40 (18 decimals for price bounds)
    uint256 constant MIN_PRICE = 80 * 1e16;  // $0.80 (18 decimals for price bounds)
    
    // ==================== SETUP ====================
    
    /**
     * @notice Mock function for testing
     * @dev Mock function for testing purposes
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    function setUp() public {
        // Deploy mock price feeds with proper decimals
        mockEurUsdFeed = new MockAggregatorV3(8); // 8 decimals
        mockUsdcUsdFeed = new MockAggregatorV3(8); // 8 decimals
        
        // Set initial prices (using 8 decimals format)
        mockEurUsdFeed.setPrice(110000000); // 1.10 USD (8 decimals)
        mockUsdcUsdFeed.setPrice(100000000); // 1.00 USD (8 decimals)
        
        // Deploy TimeProvider through proxy
        TimeProvider timeProviderImpl = new TimeProvider();
        bytes memory timeProviderInitData = abi.encodeWithSelector(
            TimeProvider.initialize.selector,
            admin,
            admin,
            admin
        );
        ERC1967Proxy timeProviderProxy = new ERC1967Proxy(address(timeProviderImpl), timeProviderInitData);
        timeProvider = TimeProvider(address(timeProviderProxy));
        
        // Deploy oracle implementation
        ChainlinkOracle oracleImpl = new ChainlinkOracle(timeProvider);
        
        // Deploy oracle proxy
        bytes memory oracleInitData = abi.encodeWithSelector(
            ChainlinkOracle.initialize.selector,
            admin,
            address(mockEurUsdFeed),
            address(mockUsdcUsdFeed),
            treasury
        );
        ERC1967Proxy oracleProxy = new ERC1967Proxy(address(oracleImpl), oracleInitData);
        oracle = ChainlinkOracle(address(oracleProxy));
        
        // Grant additional roles for testing
        vm.startPrank(admin);
        oracle.grantRole(oracle.ORACLE_MANAGER_ROLE(), oracleManager);
        oracle.grantRole(oracle.EMERGENCY_ROLE(), emergencyRole);
        vm.stopPrank();
    }
    
    // =============================================================================
    // ORACLE MANIPULATION SCENARIOS
    // =============================================================================
    
    /**
     * @notice Test rapid price changes within same block
     * @dev Verifies oracle handles rapid price updates correctly
     */
    /**
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test oracle with rapid price changes
     * @dev Verifies oracle edge cases functionality and edge cases
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Oracle_RapidPriceChanges() public {
        uint256 initialPrice = 110000000; // 1.10 USD (8 decimals)
        uint256 newPrice = 115000000;     // 1.15 USD (8 decimals) - 4.5% increase
        
        // Set initial price and force oracle update
        mockEurUsdFeed.setPrice(int256(initialPrice));
        mockEurUsdFeed.setUpdatedAt(block.timestamp);
        vm.prank(emergencyRole);
        oracle.resetCircuitBreaker();
        
        (uint256 price1, bool valid1) = oracle.getEurUsdPrice();
        assertTrue(valid1);
        assertEq(price1, initialPrice * 1e10); // Oracle returns 18-decimal format
        
        // Rapidly change price in same block (within deviation limits)
        mockEurUsdFeed.setPrice(int256(newPrice));
        mockEurUsdFeed.setUpdatedAt(block.timestamp);
        vm.prank(emergencyRole);
        oracle.resetCircuitBreaker();
        
        (uint256 price2, bool valid2) = oracle.getEurUsdPrice();
        assertTrue(valid2);
        assertEq(price2, newPrice * 1e10); // Oracle returns 18-decimal format
        
        // Verify price change is reflected
        assertGt(price2, price1);
    }
    
    /**
     * @notice Test price feed updates during transaction execution
     * @dev Verifies oracle consistency during mid-transaction updates
     */
    /**
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test oracle price update during execution
     * @dev Verifies oracle edge cases functionality and edge cases
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Oracle_PriceUpdateDuringExecution() public {
        uint256 price1 = 110000000; // 1.10 USD (8 decimals)
        uint256 price2 = 115000000; // 1.15 USD (8 decimals)
        
        // Set initial price and force oracle update
        mockEurUsdFeed.setPrice(int256(price1));
        mockEurUsdFeed.setUpdatedAt(block.timestamp);
        vm.prank(emergencyRole);
        oracle.resetCircuitBreaker();
        
        // Simulate price update during execution
        vm.startPrank(oracleManager);
        oracle.updatePriceBounds(MIN_PRICE, MAX_PRICE);
        mockEurUsdFeed.setPrice(int256(price2));
        mockEurUsdFeed.setUpdatedAt(block.timestamp);
        oracle.updatePriceBounds(MIN_PRICE, MAX_PRICE);
        vm.stopPrank();
        
        // Force oracle to recognize the new price
        vm.prank(emergencyRole);
        oracle.resetCircuitBreaker();
        
        // Verify final price is correct
        (uint256 finalPrice, bool valid) = oracle.getEurUsdPrice();
        assertTrue(valid);
        assertEq(finalPrice, price2 * 1e10); // Oracle returns 18-decimal format
    }
    
    /**
     * @notice Test oracle price staleness during high volatility
     * @dev Verifies staleness detection works during volatile periods
     */
    /**
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test oracle staleness during volatility
     * @dev Verifies oracle edge cases functionality and edge cases
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Oracle_StalenessDuringVolatility() public {
        // Advance time to avoid underflow, then set stale price
        vm.warp(block.timestamp + 10000); // Move to timestamp 10001
        
        // Set stale price (2 hours old)
        uint256 staleTimestamp = block.timestamp - 7200; // 10001 - 7200 = 2801
        mockEurUsdFeed.setPrice(int256(110 * PRECISION));
        mockEurUsdFeed.setUpdatedAt(staleTimestamp);
        
        // Verify staleness detection
        (uint256 price, bool valid) = oracle.getEurUsdPrice();
        assertFalse(valid, "Should detect stale price during volatility");
        assertGt(price, 0, "Should return last valid price");
    }
    
    // =============================================================================
    // EXTREME PRICE MOVEMENTS
    // =============================================================================
    
    /**
     * @notice Test 50%+ price movements in single update
     * @dev Verifies oracle handles extreme price changes
     */
    /**
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test oracle with extreme price movements
     * @dev Verifies oracle edge cases functionality and edge cases
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Oracle_ExtremePriceMovements() public {
        // Test extreme price movement beyond deviation limits
        // This should trigger circuit breaker, not accept the price
        uint256 extremePrice = 200 * PRECISION; // 200 USD, 82% increase from 1.1
        
        // Set extreme price movement
        mockEurUsdFeed.setPrice(int256(extremePrice));
        mockEurUsdFeed.setUpdatedAt(block.timestamp);
        
        // Verify oracle rejects extreme movement (returns last valid price)
        (uint256 price, bool valid) = oracle.getEurUsdPrice();
        assertFalse(valid, "Should reject extreme price movements");
        assertEq(price, 11 * 1e17); // Should return last valid price (1.1 USD)
    }
    
    /**
     * @notice Test price feeds returning zero values
     * @dev Verifies oracle rejects zero prices
     */
    /**
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test oracle zero price rejection
     * @dev Verifies oracle edge cases functionality and edge cases
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Oracle_ZeroPriceRejection() public {
        // Set zero price
        mockEurUsdFeed.setPrice(0);
        
        // Verify zero price is rejected
        (uint256 price, bool valid) = oracle.getEurUsdPrice();
        assertFalse(valid, "Should reject zero prices");
        assertGt(price, 0, "Should return last valid price");
    }
    
    /**
     * @notice Test price feeds with negative values
     * @dev Verifies oracle handles negative price attempts
     */
    /**
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test oracle negative price handling
     * @dev Verifies oracle edge cases functionality and edge cases
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Oracle_NegativePriceHandling() public {
        // Set negative price in the mock feed
        mockEurUsdFeed.setPrice(-1);
        mockEurUsdFeed.setUpdatedAt(block.timestamp);
        
        // Oracle should reject negative price and return last valid price
        (uint256 price, bool valid) = oracle.getEurUsdPrice();
        assertFalse(valid, "Should reject negative prices");
        assertEq(price, 11 * 1e17); // Should return last valid price (1.1 USD)
    }
    
    /**
     * @notice Test price feeds with extreme decimals
     * @dev Verifies oracle handles unusual decimal precision
     */
    /**
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test oracle with extreme decimals
     * @dev Verifies oracle edge cases functionality and edge cases
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Oracle_ExtremeDecimals() public {
        // Test with very high precision but close to current price (1.1)
        uint256 highPrecisionPrice = 110000000 + 12345; // 1.10012345 USD in 8 decimals
        mockEurUsdFeed.setPrice(int256(highPrecisionPrice));
        mockEurUsdFeed.setUpdatedAt(block.timestamp);
        
        (uint256 price, bool valid) = oracle.getEurUsdPrice();
        assertTrue(valid, "Should handle high precision prices");
        // Oracle scales from 8 decimals to 18 decimals
        assertEq(price, highPrecisionPrice * 1e10);
    }
    
    // =============================================================================
    // MULTIPLE FEED FAILURES
    // =============================================================================
    
    /**
     * @notice Test both EUR/USD and USDC/USD feeds failing simultaneously
     * @dev Verifies oracle behavior during complete failure
     */
    /**
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test oracle with multiple feed failures
     * @dev Verifies oracle edge cases functionality and edge cases
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Oracle_MultipleFeedFailures() public {
        // Make both feeds fail
        mockEurUsdFeed.setShouldRevert(true);
        mockUsdcUsdFeed.setShouldRevert(true);
        
        // Verify both feeds fail
        vm.expectRevert("MockAggregator: Simulated failure");
        oracle.getEurUsdPrice();
        
        vm.expectRevert("MockAggregator: Simulated failure");
        oracle.getUsdcUsdPrice();
    }
    
    /**
     * @notice Test cascading oracle failures
     * @dev Verifies oracle recovery from cascading failures
     */
    /**
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test oracle with cascading failures
     * @dev Verifies oracle edge cases functionality and edge cases
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Oracle_CascadingFailures() public {
        // First feed fails
        mockEurUsdFeed.setShouldRevert(true);
        vm.expectRevert("MockAggregator: Simulated failure");
        oracle.getEurUsdPrice();
        
        // Second feed fails
        mockUsdcUsdFeed.setShouldRevert(true);
        vm.expectRevert("MockAggregator: Simulated failure");
        oracle.getUsdcUsdPrice();
        
        // Recover both feeds (resetCircuitBreaker needs both feeds working)
        mockEurUsdFeed.setShouldRevert(false);
        mockEurUsdFeed.setPrice(int256(110000000)); // 1.10 USD (8 decimals)
        mockEurUsdFeed.setUpdatedAt(block.timestamp);
        
        mockUsdcUsdFeed.setShouldRevert(false); // Also recover USDC feed
        mockUsdcUsdFeed.setUpdatedAt(block.timestamp);
        
        // Force oracle to update with the recovered price
        vm.prank(emergencyRole);
        oracle.resetCircuitBreaker();
        
        // Verify first feed recovers
        (uint256 price, bool valid) = oracle.getEurUsdPrice();
        assertTrue(valid, "First feed should recover");
        assertEq(price, 110000000 * 1e10); // Oracle returns 18-decimal format
    }
    
    /**
     * @notice Test oracle recovery scenarios
     * @dev Verifies oracle can recover from various failure modes
     */
    /**
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test oracle recovery scenarios
     * @dev Verifies oracle edge cases functionality and edge cases
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Oracle_RecoveryScenarios() public {
        // Simulate failure
        mockEurUsdFeed.setShouldRevert(true);
        vm.expectRevert("MockAggregator: Simulated failure");
        oracle.getEurUsdPrice();
        
        // Recover with new price (close to current price to avoid deviation issues)
        mockEurUsdFeed.setShouldRevert(false);
        mockEurUsdFeed.setPrice(int256(115000000)); // 1.15 USD (8 decimals)
        mockEurUsdFeed.setUpdatedAt(block.timestamp);
        
        // Force oracle to update with the new price
        vm.prank(emergencyRole);
        oracle.resetCircuitBreaker();
        
        // Verify recovery
        (uint256 price, bool valid) = oracle.getEurUsdPrice();
        assertTrue(valid, "Oracle should recover");
        assertEq(price, 115000000 * 1e10); // Oracle returns 18-decimal format
    }
    
    // =============================================================================
    // PRICE BOUNDARY TESTS
    // =============================================================================
    
    /**
     * @notice Test prices at minimum boundary
     * @dev Verifies oracle accepts minimum valid prices
     */
    /**
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test oracle minimum boundary conditions
     * @dev Verifies oracle edge cases functionality and edge cases
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Oracle_MinimumBoundary() public {
        // Set price bounds first
        vm.startPrank(oracleManager);
        oracle.updatePriceBounds(MIN_PRICE, MAX_PRICE);
        vm.stopPrank();
        
        // Gradually decrease price to avoid deviation check (5% max deviation)
        // Start with 1.05 (4.5% decrease from 1.1)
        mockEurUsdFeed.setPrice(105000000); // 1.05 USD (8 decimals)
        mockEurUsdFeed.setUpdatedAt(block.timestamp);
        
        // Force oracle to update its internal state
        vm.prank(emergencyRole);
        oracle.resetCircuitBreaker();
        
        // Advance time to allow price update
        vm.warp(block.timestamp + 1);
        
        // Decrease to 1.00 (4.8% decrease from 1.05)
        mockEurUsdFeed.setPrice(100000000); // 1.00 USD (8 decimals)
        mockEurUsdFeed.setUpdatedAt(block.timestamp);
        
        // Force oracle to update its internal state
        vm.prank(emergencyRole);
        oracle.resetCircuitBreaker();
        
        // Advance time to allow price update
        vm.warp(block.timestamp + 1);
        
        // Decrease to 0.95 (5% decrease from 1.00)
        mockEurUsdFeed.setPrice(95000000); // 0.95 USD (8 decimals)
        mockEurUsdFeed.setUpdatedAt(block.timestamp);
        
        // Force oracle to update its internal state
        vm.prank(emergencyRole);
        oracle.resetCircuitBreaker();
        
        // Advance time to allow price update
        vm.warp(block.timestamp + 1);
        
        // Decrease to 0.905 (4.7% decrease from 0.95)
        mockEurUsdFeed.setPrice(90500000); // 0.905 USD (8 decimals)
        mockEurUsdFeed.setUpdatedAt(block.timestamp);
        
        // Force oracle to update its internal state
        vm.prank(emergencyRole);
        oracle.resetCircuitBreaker();
        
        // Advance time to allow price update
        vm.warp(block.timestamp + 1);
        
        // Decrease to 0.86 (5.0% decrease from 0.905)
        mockEurUsdFeed.setPrice(86000000); // 0.86 USD (8 decimals)
        mockEurUsdFeed.setUpdatedAt(block.timestamp);
        
        // Force oracle to update its internal state
        vm.prank(emergencyRole);
        oracle.resetCircuitBreaker();
        
        // Advance time to allow price update
        vm.warp(block.timestamp + 1);
        
        // Decrease to 0.817 (5.0% decrease from 0.86)
        mockEurUsdFeed.setPrice(81700000); // 0.817 USD (8 decimals)
        mockEurUsdFeed.setUpdatedAt(block.timestamp);
        
        // Force oracle to update its internal state
        vm.prank(emergencyRole);
        oracle.resetCircuitBreaker();
        
        // Advance time to allow price update
        vm.warp(block.timestamp + 1);
        
        // Finally set to minimum price (2.1% decrease from 0.817)
        mockEurUsdFeed.setPrice(80000000); // 0.80 USD (8 decimals)
        mockEurUsdFeed.setUpdatedAt(block.timestamp);
        
        // Force oracle to update its internal state
        vm.prank(emergencyRole);
        oracle.resetCircuitBreaker();
        
        (uint256 price, bool valid) = oracle.getEurUsdPrice();
        assertTrue(valid, "Should accept minimum price");
        assertEq(price, MIN_PRICE);
    }
    
    /**
     * @notice Test prices at maximum boundary
     * @dev Verifies oracle accepts maximum valid prices
     */
    /**
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test oracle maximum boundary conditions
     * @dev Verifies oracle edge cases functionality and edge cases
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Oracle_MaximumBoundary() public {
        // Set price bounds first
        vm.startPrank(oracleManager);
        oracle.updatePriceBounds(MIN_PRICE, MAX_PRICE);
        vm.stopPrank();
        
        // Gradually increase price to avoid deviation check (5% max deviation)
        // Start with 1.15 (5% increase from 1.1)
        mockEurUsdFeed.setPrice(115000000); // 1.15 USD (8 decimals)
        mockEurUsdFeed.setUpdatedAt(block.timestamp);
        
        // Force oracle to update its internal state
        vm.prank(emergencyRole);
        oracle.resetCircuitBreaker();
        
        // Advance time to allow price update
        vm.warp(block.timestamp + 1);
        
        // Increase to 1.20 (4.3% increase from 1.15)
        mockEurUsdFeed.setPrice(120000000); // 1.20 USD (8 decimals)
        mockEurUsdFeed.setUpdatedAt(block.timestamp);
        
        // Force oracle to update its internal state
        vm.prank(emergencyRole);
        oracle.resetCircuitBreaker();
        
        // Advance time to allow price update
        vm.warp(block.timestamp + 1);
        
        // Increase to 1.25 (4.2% increase from 1.20)
        mockEurUsdFeed.setPrice(125000000); // 1.25 USD (8 decimals)
        mockEurUsdFeed.setUpdatedAt(block.timestamp);
        
        // Force oracle to update its internal state
        vm.prank(emergencyRole);
        oracle.resetCircuitBreaker();
        
        // Advance time to allow price update
        vm.warp(block.timestamp + 1);
        
        // Increase to 1.30 (4% increase from 1.25)
        mockEurUsdFeed.setPrice(130000000); // 1.30 USD (8 decimals)
        mockEurUsdFeed.setUpdatedAt(block.timestamp);
        
        // Force oracle to update its internal state
        vm.prank(emergencyRole);
        oracle.resetCircuitBreaker();
        
        // Advance time to allow price update
        vm.warp(block.timestamp + 1);
        
        // Increase to 1.35 (3.8% increase from 1.30)
        mockEurUsdFeed.setPrice(135000000); // 1.35 USD (8 decimals)
        mockEurUsdFeed.setUpdatedAt(block.timestamp);
        
        // Force oracle to update its internal state
        vm.prank(emergencyRole);
        oracle.resetCircuitBreaker();
        
        // Advance time to allow price update
        vm.warp(block.timestamp + 1);
        
        // Finally set to maximum price (3.7% increase from 1.35)
        mockEurUsdFeed.setPrice(140000000); // 1.40 USD (8 decimals)
        mockEurUsdFeed.setUpdatedAt(block.timestamp);
        
        // Force oracle to update its internal state
        vm.prank(emergencyRole);
        oracle.resetCircuitBreaker();
        
        (uint256 price, bool valid) = oracle.getEurUsdPrice();
        
        assertTrue(valid, "Should accept maximum price");
        assertEq(price, MAX_PRICE);
    }
    
    /**
     * @notice Test prices below minimum boundary
     * @dev Verifies oracle rejects prices below minimum
     */
    /**
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test oracle below minimum boundary
     * @dev Verifies oracle edge cases functionality and edge cases
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Oracle_BelowMinimumBoundary() public {
        uint256 belowMin = MIN_PRICE - 1;
        mockEurUsdFeed.setPrice(int256(belowMin));
        
        (uint256 price, bool valid) = oracle.getEurUsdPrice();
        assertFalse(valid, "Should reject price below minimum");
        assertGt(price, 0, "Should return last valid price");
    }
    
    /**
     * @notice Test prices above maximum boundary
     * @dev Verifies oracle rejects prices above maximum
     */
    /**
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test oracle above maximum boundary
     * @dev Verifies oracle edge cases functionality and edge cases
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Oracle_AboveMaximumBoundary() public {
        uint256 aboveMax = MAX_PRICE + 1;
        mockEurUsdFeed.setPrice(int256(aboveMax));
        
        (uint256 price, bool valid) = oracle.getEurUsdPrice();
        assertFalse(valid, "Should reject price above maximum");
        assertGt(price, 0, "Should return last valid price");
    }
    
    // =============================================================================
    // TIMESTAMP MANIPULATION TESTS
    // =============================================================================
    
    /**
     * @notice Test future timestamp manipulation
     * @dev Verifies oracle rejects future timestamps
     */
    /**
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test oracle with future timestamp
     * @dev Verifies oracle edge cases functionality and edge cases
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Oracle_FutureTimestamp() public {
        uint256 futureTimestamp = block.timestamp + 3600; // 1 hour in future
        mockEurUsdFeed.setPrice(int256(110 * PRECISION));
        mockEurUsdFeed.setUpdatedAt(futureTimestamp);
        
        (uint256 price, bool valid) = oracle.getEurUsdPrice();
        assertFalse(valid, "Should reject future timestamps");
        assertGt(price, 0, "Should return last valid price");
    }
    
    /**
     * @notice Test timestamp overflow scenarios
     * @dev Verifies oracle handles timestamp edge cases
     */
    /**
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test oracle with timestamp overflow
     * @dev Verifies oracle edge cases functionality and edge cases
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Oracle_TimestampOverflow() public {
        // Test with maximum timestamp
        uint256 maxTimestamp = type(uint256).max;
        mockEurUsdFeed.setPrice(int256(110 * PRECISION));
        mockEurUsdFeed.setUpdatedAt(maxTimestamp);
        
        (uint256 price, bool valid) = oracle.getEurUsdPrice();
        assertFalse(valid, "Should reject extreme timestamps");
        assertGt(price, 0, "Should return last valid price");
    }
    
    // =============================================================================
    // CIRCUIT BREAKER EDGE CASES
    // =============================================================================
    
    /**
     * @notice Test circuit breaker during extreme volatility
     * @dev Verifies circuit breaker activates during extreme conditions
     */
    /**
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test oracle circuit breaker with extreme volatility
     * @dev Verifies oracle edge cases functionality and edge cases
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Oracle_CircuitBreakerExtremeVolatility() public {
        // Trigger circuit breaker
        vm.prank(emergencyRole);
        oracle.triggerCircuitBreaker();
        
        // Verify circuit breaker is active
        (bool isHealthy, , ) = oracle.getOracleHealth();
        assertFalse(isHealthy, "Circuit breaker should be active");
        
        // Test price fetching during circuit breaker
        (uint256 price, bool valid) = oracle.getEurUsdPrice();
        assertFalse(valid, "Should not return valid price during circuit breaker");
        assertGt(price, 0, "Should return last valid price");
    }
    
    /**
     * @notice Test circuit breaker reset during active state
     * @dev Verifies circuit breaker can be reset properly
     */
    /**
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test oracle circuit breaker reset
     * @dev Verifies oracle edge cases functionality and edge cases
     * @custom:security Tests oracle edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Oracle_CircuitBreakerReset() public {
        // Trigger circuit breaker
        vm.prank(emergencyRole);
        oracle.triggerCircuitBreaker();
        
        // Reset circuit breaker
        vm.prank(emergencyRole);
        oracle.resetCircuitBreaker();
        
        // Verify circuit breaker is reset
        (bool isHealthy, , ) = oracle.getOracleHealth();
        assertTrue(isHealthy, "Circuit breaker should be reset");
        
        // Verify price fetching works again
        (uint256 price, bool valid) = oracle.getEurUsdPrice();
        assertTrue(valid, "Should return valid price after reset");
        assertEq(price, 11 * 1e17); // 1.1 USD in 18-decimal precision
    }
}

// =============================================================================
// MOCK CONTRACTS
// =============================================================================

/**
 * @title MockAggregatorV3
 * @notice Mock Chainlink price feed for testing
 */
contract MockAggregatorV3 is AggregatorV3Interface {
    int256 public price;
    uint8 public decimals_;
    uint256 public updatedAt;
    bool public shouldRevert;
    bool public shouldReturnInvalidPrice;
    uint80 public roundId = 1;

    /**
     * @notice Constructor for MockAggregatorV3
     * @dev Initializes the mock price feed with specified decimals
     * @param _decimals The number of decimals for the price feed
     * @custom:security No security validations - test mock
     * @custom:validation No input validation - test mock
     * @custom:state-changes Initializes decimals_ and updatedAt
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can deploy this mock contract
     * @custom:oracle No oracle dependencies
     */
    constructor(uint8 _decimals) {
        decimals_ = _decimals;
        updatedAt = block.timestamp;
    }

    /**
     * @notice Mock function for testing
     * @dev Mock function for testing purposes
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    /**
     * @notice Sets the mock price for testing
     * @dev Mock function for testing purposes
     * @param _price The new price to set
     
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    function setPrice(int256 _price) external {
        price = _price;
        roundId++;
    }

    /**
     * @notice Mock function for testing
     * @dev Mock function for testing purposes
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    /**
     * @notice Sets whether the mock should revert for testing
     * @dev Mock function for testing purposes
     * @param _shouldRevert Whether the mock should revert
     
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    /**
     * @notice Mock function for testing
     * @dev Mock function for testing purposes
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    /**
     * @notice Sets whether the mock should return invalid price
     * @dev Mock function for testing purposes
     * @param _shouldReturnInvalidPrice Whether the mock should return invalid price
     
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    function setShouldReturnInvalidPrice(bool _shouldReturnInvalidPrice) external {
        shouldReturnInvalidPrice = _shouldReturnInvalidPrice;
    }

    /**
     * @notice Mock function for testing
     * @dev Mock function for testing purposes
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    /**
     * @notice Sets the updated timestamp for testing
     * @dev Mock function for testing purposes
     * @param _updatedAt The new timestamp to set
     
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    function setUpdatedAt(uint256 _updatedAt) external {
        updatedAt = _updatedAt;
    }

    /**
     * @notice Mock function for testing
     * @dev Mock function for testing purposes
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    /**
     * @notice Gets the latest round data from the mock price feed
     * @dev Mock function for testing purposes
     
     * @return _roundId The round ID
     * @return _answer The price answer
     * @return _startedAt The timestamp when the round started
     * @return _updatedAt The timestamp when the round was updated
     * @return _answeredInRound The round ID when the answer was provided
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    function latestRoundData() external view returns (
        uint80 _roundId,
        int256 _answer,
        uint256 _startedAt,
        uint256 _updatedAt,
        uint80 _answeredInRound
    ) {
        if (shouldRevert) {
            revert("MockAggregator: Simulated failure");
        }

        if (shouldReturnInvalidPrice) {
            return (roundId, -1, 0, updatedAt, roundId);
        }

        return (roundId, price, 0, updatedAt, roundId);
    }

    /**
     * @notice Mock function for testing
     * @dev Mock function for testing purposes
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    /**
     * @notice Gets the decimals of the mock price feed
     * @dev Mock function for testing purposes
     
     * @return The number of decimals
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    function decimals() external view returns (uint8) {
        return decimals_;
    }

    /**
     * @notice Mock function for testing
     * @dev Mock function for testing purposes
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    /**
     * @notice Gets the description of the mock price feed
     * @dev Mock function for testing purposes
     
     * @return The description string
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    function description() external pure returns (string memory) {
        return "Mock Price Feed";
    }

    /**
     * @notice Mock function for testing
     * @dev Mock function for testing purposes
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    /**
     * @notice Gets the version of the mock price feed
     * @dev Mock function for testing purposes
     
     * @return The version number
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    function version() external pure returns (uint256) {
        return 1;
    }

    /**
     * @notice Mock function for testing
     * @dev Mock function for testing purposes
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    /**
     * @notice Gets round data for the mock price feed
     * @dev Mock function for testing purposes
     * @param _roundId The round ID to query (ignored in mock implementation)
     * @return roundId_ The round ID
     * @return answer The price answer
     * @return startedAt The timestamp when the round started
     * @return updatedAt_ The timestamp when the round was updated
     * @return answeredInRound The round ID when the answer was provided
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    function getRoundData(uint80 _roundId) external view returns (
        uint80 roundId_,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt_,
        uint80 answeredInRound
    ) {
        if (shouldRevert) {
            revert("MockAggregator: Simulated failure");
        }

        if (shouldReturnInvalidPrice) {
            return (_roundId, -1, 0, updatedAt, _roundId);
        }

        return (roundId, price, 0, updatedAt, roundId);
    }
}
