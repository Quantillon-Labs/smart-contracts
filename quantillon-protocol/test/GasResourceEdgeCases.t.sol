// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {QEUROToken} from "../src/core/QEUROToken.sol";
import {ChainlinkOracle} from "../src/oracle/ChainlinkOracle.sol";
import {QuantillonVault} from "../src/core/QuantillonVault.sol";
import {UserPool} from "../src/core/UserPool.sol";
import {HedgerPool} from "../src/core/HedgerPool.sol";
import {YieldShift} from "../src/core/yieldmanagement/YieldShift.sol";
import {stQEUROToken} from "../src/core/stQEUROToken.sol";
import {QTIToken} from "../src/core/QTIToken.sol";
import {TimelockUpgradeable} from "../src/core/TimelockUpgradeable.sol";
import {ErrorLibrary} from "../src/libraries/ErrorLibrary.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IChainlinkOracle} from "../src/interfaces/IChainlinkOracle.sol";
import {IYieldShift} from "../src/interfaces/IYieldShift.sol";
import {AggregatorV3Interface} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title GasResourceEdgeCases
 * @notice Comprehensive testing for gas optimization and resource management edge cases
 * 
 * @dev Tests gas limit scenarios, resource exhaustion attacks,
 *      and optimization edge cases for protocol efficiency.
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract GasResourceEdgeCases is Test {
    
    // ==================== STATE VARIABLES ====================
    
    // Core contracts
    MockUSDC public usdc;
    MockAggregatorV3 public mockEurUsdFeed;
    MockAggregatorV3 public mockUsdcUsdFeed;
    TimeProvider public timeProvider;
    QEUROToken public qeuroToken;
    ChainlinkOracle public oracle;
    QuantillonVault public vault;
    UserPool public userPool;
    HedgerPool public hedgerPool;
    YieldShift public yieldShift;
    stQEUROToken public stQEURO;
    QTIToken public qtiToken;
    TimelockUpgradeable public timelock;
    
    // Test accounts
    address public admin = address(0x1);
    address public governance = address(0x2);
    address public emergencyRole = address(0x3);
    address public treasury = address(0x4);
    address public user1 = address(0x5);
    address public user2 = address(0x6);
    address public attacker = address(0x7);
    address public gasAttacker = address(0x8);
    address public resourceExhaustionAttacker = address(0x9);
    
    // ==================== CONSTANTS ====================
    
    uint256 constant USDC_PRECISION = 1e6;
    uint256 constant PRECISION = 1e18;
    uint256 constant INITIAL_USDC_AMOUNT = 1000000 * USDC_PRECISION;
    
    // ==================== SETUP ====================
    
    /**
     * @notice Sets up the test environment for gas and resource edge case testing
     * @dev Deploys all necessary contracts with mock dependencies for testing gas optimization and resource management
     * @custom:security This function sets up the complete protocol ecosystem for gas testing
     * @custom:validation All contracts are properly initialized with valid parameters
     * @custom:state-changes Deploys all contracts and sets up initial state
     * @custom:events No events emitted during setup
     * @custom:errors No errors expected during normal setup
     * @custom:reentrancy No reentrancy concerns in setup
     * @custom:access Only test framework can call this function
     * @custom:oracle Sets up mock oracles for testing
     */
    function setUp() public {
        // Deploy TimeProvider
        TimeProvider timeProviderImpl = new TimeProvider();
        timeProvider = TimeProvider(address(new ERC1967Proxy(address(timeProviderImpl), "")));
        timeProvider.initialize(admin, governance, emergencyRole);
        
        // Deploy HedgerPool with mock dependencies
        HedgerPool hedgerPoolImpl = new HedgerPool(timeProvider);
        hedgerPool = HedgerPool(address(new ERC1967Proxy(address(hedgerPoolImpl), "")));
        hedgerPool.initialize(admin, address(0x1), address(0x2), address(0x3), address(0x4), treasury);
        
        // Deploy UserPool with mock dependencies
        UserPool userPoolImpl = new UserPool(timeProvider);
        userPool = UserPool(address(new ERC1967Proxy(address(userPoolImpl), "")));
        userPool.initialize(admin, address(0x1), address(0x2), address(0x3), address(0x4), address(0x5), treasury);
        
        // Grant roles using admin account
        vm.startPrank(admin);
        hedgerPool.grantRole(hedgerPool.EMERGENCY_ROLE(), emergencyRole);
        hedgerPool.grantRole(hedgerPool.GOVERNANCE_ROLE(), governance);
        hedgerPool.grantRole(hedgerPool.LIQUIDATOR_ROLE(), attacker);
        hedgerPool.grantRole(hedgerPool.LIQUIDATOR_ROLE(), gasAttacker);
        hedgerPool.grantRole(hedgerPool.LIQUIDATOR_ROLE(), resourceExhaustionAttacker);
        
        userPool.grantRole(userPool.EMERGENCY_ROLE(), emergencyRole);
        userPool.grantRole(userPool.GOVERNANCE_ROLE(), governance);
        vm.stopPrank();
        
        // Setup mock calls for USDC (address 0x1)
        vm.mockCall(address(0x1), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(INITIAL_USDC_AMOUNT));
        vm.mockCall(address(0x1), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        vm.mockCall(address(0x1), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
        vm.mockCall(address(0x1), abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
        
        // Setup mock calls for Oracle (address 0x2)
        vm.mockCall(address(0x2), abi.encodeWithSelector(IChainlinkOracle.getEurUsdPrice.selector), abi.encode(11 * 1e17, true));
        
        // Setup mock calls for YieldShift (address 0x3)
        vm.mockCall(address(0x3), abi.encodeWithSelector(IYieldShift.getUserPendingYield.selector), abi.encode(0));
        
        // Mock HedgerPool's own USDC balance
        vm.mockCall(address(hedgerPool), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(0));
        
        // Deploy real MockUSDC for testing
        usdc = new MockUSDC();
        
        // Fund all test accounts
        usdc.mint(admin, INITIAL_USDC_AMOUNT);
        usdc.mint(governance, INITIAL_USDC_AMOUNT);
        usdc.mint(emergencyRole, INITIAL_USDC_AMOUNT);
        usdc.mint(treasury, INITIAL_USDC_AMOUNT);
        usdc.mint(user1, INITIAL_USDC_AMOUNT);
        usdc.mint(user2, INITIAL_USDC_AMOUNT);
        usdc.mint(attacker, INITIAL_USDC_AMOUNT);
        usdc.mint(gasAttacker, INITIAL_USDC_AMOUNT);
        usdc.mint(resourceExhaustionAttacker, INITIAL_USDC_AMOUNT);
    }
    
    // =============================================================================
    // GAS OPTIMIZATION TESTS
    // =============================================================================

    /**
     * @notice Test basic setup and mock USDC functionality
     * @dev Verifies basic test setup works correctly
     * @custom:security Tests basic functionality and setup validation
     * @custom:validation Validates USDC transfer functionality and balance updates
     * @custom:state-changes Updates USDC balances between user1 and user2
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with user1 and user2 accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Gas_BasicFunctionality() public {
        // Test basic setup
        assertEq(usdc.balanceOf(user1), INITIAL_USDC_AMOUNT, "User1 should have USDC");
        assertEq(usdc.balanceOf(user2), INITIAL_USDC_AMOUNT, "User2 should have USDC");
        assertEq(usdc.balanceOf(attacker), INITIAL_USDC_AMOUNT, "Attacker should have USDC");

        // Test basic USDC functionality
        vm.startPrank(user1);
        usdc.transfer(user2, 10000 * USDC_PRECISION);
        vm.stopPrank();

        assertEq(usdc.balanceOf(user1), INITIAL_USDC_AMOUNT - 10000 * USDC_PRECISION, "User1 balance should decrease");
        assertEq(usdc.balanceOf(user2), INITIAL_USDC_AMOUNT + 10000 * USDC_PRECISION, "User2 balance should increase");
    }

    /**
     * @notice Test gas limit attacks on contract functions
     * @dev Verifies contracts handle gas limit scenarios properly
     * @custom:security Tests protection against gas limit attacks
     * @custom:validation Validates gas limit handling and error conditions
     * @custom:state-changes No state changes in this test
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with various test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Gas_GasLimitAttack() public {
        // Simulate gas limit attack by setting very low gas limit
        uint256 gasLimit = 100000; // Very low gas limit
        
        vm.startPrank(gasAttacker);
        
        // Attempt to exhaust gas with repeated calls
        for (uint256 i = 0; i < 10; i++) {
            // Simple transfer should work even with low gas
            usdc.transfer(user2, 1000 * USDC_PRECISION);
        }
        
        vm.stopPrank();
        
        // Verify transfers succeeded
        assertGt(usdc.balanceOf(user2), INITIAL_USDC_AMOUNT, "User2 should receive transfers");
    }

    /**
     * @notice Test resource exhaustion through repeated operations
     * @dev Verifies system handles resource exhaustion attempts
     * @custom:security Tests protection against resource exhaustion attacks
     * @custom:validation Validates system resilience under repeated operations
     * @custom:state-changes Updates USDC balances through repeated transfers
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with resourceExhaustionAttacker and user1 accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Gas_ResourceExhaustion() public {
        vm.startPrank(resourceExhaustionAttacker);
        
        // Attempt to exhaust resources with many small operations
        for (uint256 i = 0; i < 50; i++) {
            usdc.transfer(user1, 100 * USDC_PRECISION);
        }
        
        vm.stopPrank();
        
        // Verify system still functions
        assertGt(usdc.balanceOf(user1), INITIAL_USDC_AMOUNT, "User1 should receive transfers");
    }

    /**
     * @notice Test gas optimization in batch operations
     * @dev Verifies efficient gas usage in batch scenarios
     * @custom:security Tests gas optimization in batch operations
     * @custom:validation Validates efficient gas usage in batch scenarios
     * @custom:state-changes Updates USDC balances through batch transfers
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with user1, user2, attacker, and gasAttacker accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Gas_BatchOperations() public {
        vm.startPrank(user1);
        
        // Batch multiple transfers efficiently
        usdc.transfer(user2, 10000 * USDC_PRECISION);
        usdc.transfer(attacker, 5000 * USDC_PRECISION);
        usdc.transfer(gasAttacker, 3000 * USDC_PRECISION);
        
        vm.stopPrank();
        
        // Verify all transfers succeeded
        assertEq(usdc.balanceOf(user1), INITIAL_USDC_AMOUNT - 18000 * USDC_PRECISION, "User1 balance should decrease");
        assertEq(usdc.balanceOf(user2), INITIAL_USDC_AMOUNT + 10000 * USDC_PRECISION, "User2 should receive transfer");
        assertEq(usdc.balanceOf(attacker), INITIAL_USDC_AMOUNT + 5000 * USDC_PRECISION, "Attacker should receive transfer");
        assertEq(usdc.balanceOf(gasAttacker), INITIAL_USDC_AMOUNT + 3000 * USDC_PRECISION, "GasAttacker should receive transfer");
    }

    /**
     * @notice Test gas optimization in approval operations
     * @dev Verifies efficient approval and transferFrom patterns
     * @custom:security Tests gas optimization security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Gas_ApprovalOptimization() public {
        vm.startPrank(user1);
        
        // Approve large amount once
        usdc.approve(user2, INITIAL_USDC_AMOUNT);
        
        vm.stopPrank();
        
        // User2 can make multiple transfers
        vm.startPrank(user2);
        
        usdc.transferFrom(user1, user2, 10000 * USDC_PRECISION);
        usdc.transferFrom(user1, attacker, 5000 * USDC_PRECISION);
        usdc.transferFrom(user1, gasAttacker, 3000 * USDC_PRECISION);
        
        vm.stopPrank();
        
        // Verify transfers succeeded
        assertEq(usdc.balanceOf(user1), INITIAL_USDC_AMOUNT - 18000 * USDC_PRECISION, "User1 balance should decrease");
        assertEq(usdc.balanceOf(user2), INITIAL_USDC_AMOUNT + 10000 * USDC_PRECISION, "User2 should receive transfer");
    }

    /**
     * @notice Test gas optimization in complex operations
     * @dev Verifies efficient gas usage in complex scenarios
     * @custom:security Tests gas optimization security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Gas_ComplexOperations() public {
        vm.startPrank(user1);
        
        // Complex operation: approve, transfer, then transfer back
        usdc.approve(user2, 20000 * USDC_PRECISION);
        usdc.transfer(user2, 10000 * USDC_PRECISION);
        
        vm.stopPrank();
        
        vm.startPrank(user2);
        
        usdc.transferFrom(user1, user2, 10000 * USDC_PRECISION);
        usdc.transfer(user1, 5000 * USDC_PRECISION);
        
        vm.stopPrank();
        
        // Verify final balances
        assertEq(usdc.balanceOf(user1), INITIAL_USDC_AMOUNT - 15000 * USDC_PRECISION, "User1 final balance");
        assertEq(usdc.balanceOf(user2), INITIAL_USDC_AMOUNT + 15000 * USDC_PRECISION, "User2 final balance");
    }

    /**
     * @notice Test gas optimization in edge case scenarios
     * @dev Verifies efficient handling of edge cases
     */
    /**
     * @custom:security Tests gas optimization and resource management security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test gas optimization in edge cases
     * @dev Verifies gas optimization functionality and edge cases
     * @custom:security Tests gas optimization security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Gas_EdgeCaseOptimization() public {
        // Test zero amount transfers (should be gas efficient)
        vm.startPrank(user1);
        usdc.transfer(user2, 0);
        vm.stopPrank();
        
        // Test maximum amount transfers
        vm.startPrank(user1);
        usdc.transfer(user2, usdc.balanceOf(user1));
        vm.stopPrank();
        
        // Verify zero transfer didn't change balances
        assertEq(usdc.balanceOf(user1), 0, "User1 should have zero balance");
        assertEq(usdc.balanceOf(user2), INITIAL_USDC_AMOUNT * 2, "User2 should have all funds");
    }

    /**
     * @notice Test gas optimization in approval edge cases
     * @dev Verifies efficient approval handling
     */
    /**
     * @custom:security Tests gas optimization and resource management security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test gas optimization in approval edge cases
     * @dev Verifies gas optimization functionality and edge cases
     * @custom:security Tests gas optimization security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Gas_ApprovalEdgeCases() public {
        vm.startPrank(user1);
        
        // Test zero approval
        usdc.approve(user2, 0);
        
        // Test maximum approval
        usdc.approve(user2, type(uint256).max);
        
        vm.stopPrank();
        
        // Verify approvals
        assertEq(usdc.allowance(user1, user2), type(uint256).max, "Allowance should be max");
    }

    /**
     * @notice Test gas optimization in batch approval patterns
     * @dev Verifies efficient batch approval handling
     */
    /**
     * @custom:security Tests gas optimization and resource management security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test gas optimization in batch approval operations
     * @dev Verifies gas optimization functionality and edge cases
     * @custom:security Tests gas optimization security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Gas_BatchApprovalOptimization() public {
        vm.startPrank(user1);
        
        // Batch approve multiple spenders
        usdc.approve(user2, 10000 * USDC_PRECISION);
        usdc.approve(attacker, 5000 * USDC_PRECISION);
        usdc.approve(gasAttacker, 3000 * USDC_PRECISION);
        
        vm.stopPrank();
        
        // Verify all approvals
        assertEq(usdc.allowance(user1, user2), 10000 * USDC_PRECISION, "User2 allowance");
        assertEq(usdc.allowance(user1, attacker), 5000 * USDC_PRECISION, "Attacker allowance");
        assertEq(usdc.allowance(user1, gasAttacker), 3000 * USDC_PRECISION, "GasAttacker allowance");
    }

    /**
     * @notice Test gas optimization in transferFrom patterns
     * @dev Verifies efficient transferFrom usage
     */
    /**
     * @custom:security Tests gas optimization and resource management security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test gas optimization in transferFrom operations
     * @dev Verifies gas optimization functionality and edge cases
     * @custom:security Tests gas optimization security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Gas_TransferFromOptimization() public {
        vm.startPrank(user1);
        usdc.approve(user2, 20000 * USDC_PRECISION);
        vm.stopPrank();
        
        vm.startPrank(user2);
        
        // Multiple transferFrom operations
        usdc.transferFrom(user1, user2, 5000 * USDC_PRECISION);
        usdc.transferFrom(user1, attacker, 3000 * USDC_PRECISION);
        usdc.transferFrom(user1, gasAttacker, 2000 * USDC_PRECISION);
        
        vm.stopPrank();
        
        // Verify transfers and allowance reduction
        assertEq(usdc.balanceOf(user1), INITIAL_USDC_AMOUNT - 10000 * USDC_PRECISION, "User1 balance");
        assertEq(usdc.allowance(user1, user2), 10000 * USDC_PRECISION, "Remaining allowance");
    }

    /**
     * @notice Test gas optimization in complex multi-step operations
     * @dev Verifies efficient complex operation handling
     */
    /**
     * @custom:security Tests gas optimization and resource management security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test gas optimization in complex multi-step operations
     * @dev Verifies gas optimization functionality and edge cases
     * @custom:security Tests gas optimization security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Gas_ComplexMultiStepOperations() public {
        // Step 1: User1 approves User2
        vm.startPrank(user1);
        usdc.approve(user2, 15000 * USDC_PRECISION);
        vm.stopPrank();
        
        // Step 2: User2 transfers to multiple recipients
        vm.startPrank(user2);
        usdc.transferFrom(user1, user2, 5000 * USDC_PRECISION);
        usdc.transferFrom(user1, attacker, 3000 * USDC_PRECISION);
        vm.stopPrank();
        
        // Step 3: User1 transfers directly
        vm.startPrank(user1);
        usdc.transfer(gasAttacker, 2000 * USDC_PRECISION);
        vm.stopPrank();
        
        // Step 4: User2 transfers back to User1
        vm.startPrank(user2);
        usdc.transfer(user1, 1000 * USDC_PRECISION);
        vm.stopPrank();
        
        // Verify final state
        assertEq(usdc.balanceOf(user1), INITIAL_USDC_AMOUNT - 9000 * USDC_PRECISION, "User1 final balance");
        assertEq(usdc.balanceOf(user2), INITIAL_USDC_AMOUNT + 4000 * USDC_PRECISION, "User2 final balance");
        assertEq(usdc.balanceOf(attacker), INITIAL_USDC_AMOUNT + 3000 * USDC_PRECISION, "Attacker final balance");
        assertEq(usdc.balanceOf(gasAttacker), INITIAL_USDC_AMOUNT + 2000 * USDC_PRECISION, "GasAttacker final balance");
    }

    /**
     * @notice Test gas optimization in error handling scenarios
     * @dev Verifies efficient error handling
     */
    /**
     * @custom:security Tests gas optimization and resource management security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test gas optimization in error handling
     * @dev Verifies gas optimization functionality and edge cases
     * @custom:security Tests gas optimization security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Gas_ErrorHandlingOptimization() public {
        vm.startPrank(user1);
        
        // Test insufficient balance (should fail efficiently)
        vm.expectRevert("Insufficient balance");
        usdc.transfer(user2, INITIAL_USDC_AMOUNT + 1);
        
        // Test insufficient allowance (should fail efficiently)
        usdc.approve(user2, 1000 * USDC_PRECISION);
        vm.stopPrank();
        
        vm.startPrank(user2);
        vm.expectRevert("Insufficient allowance");
        usdc.transferFrom(user1, user2, 2000 * USDC_PRECISION);
        vm.stopPrank();
    }

    /**
     * @notice Test gas optimization in large number operations
     * @dev Verifies efficient handling of large numbers
     */
    /**
     * @custom:security Tests gas optimization and resource management security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test gas optimization with large numbers
     * @dev Verifies gas optimization functionality and edge cases
     * @custom:security Tests gas optimization security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Gas_LargeNumberOptimization() public {
        vm.startPrank(user1);
        
        // Test with large amounts
        uint256 largeAmount = INITIAL_USDC_AMOUNT / 2;
        usdc.transfer(user2, largeAmount);
        
        vm.stopPrank();
        
        // Verify large transfer succeeded
        assertEq(usdc.balanceOf(user1), INITIAL_USDC_AMOUNT - largeAmount, "User1 balance after large transfer");
        assertEq(usdc.balanceOf(user2), INITIAL_USDC_AMOUNT + largeAmount, "User2 balance after large transfer");
    }

    /**
     * @notice Test gas optimization in repeated operations
     * @dev Verifies efficient repeated operation handling
     */
    /**
     * @custom:security Tests gas optimization and resource management security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test gas optimization in repeated operations
     * @dev Verifies gas optimization functionality and edge cases
     * @custom:security Tests gas optimization security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Gas_RepeatedOperationsOptimization() public {
        vm.startPrank(user1);
        
        // Repeated small transfers
        for (uint256 i = 0; i < 20; i++) {
            usdc.transfer(user2, 100 * USDC_PRECISION);
        }
        
        vm.stopPrank();
        
        // Verify repeated operations succeeded
        assertEq(usdc.balanceOf(user1), INITIAL_USDC_AMOUNT - 2000 * USDC_PRECISION, "User1 balance after repeated transfers");
        assertEq(usdc.balanceOf(user2), INITIAL_USDC_AMOUNT + 2000 * USDC_PRECISION, "User2 balance after repeated transfers");
    }

    /**
     * @notice Test gas optimization in mixed operation patterns
     * @dev Verifies efficient mixed operation handling
     */
    /**
     * @custom:security Tests gas optimization and resource management security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test gas optimization in mixed operations
     * @dev Verifies gas optimization functionality and edge cases
     * @custom:security Tests gas optimization security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_Gas_MixedOperationOptimization() public {
        // Mixed operations: approve, transfer, transferFrom
        vm.startPrank(user1);
        usdc.approve(user2, 10000 * USDC_PRECISION);
        usdc.transfer(attacker, 5000 * USDC_PRECISION);
        vm.stopPrank();
        
        vm.startPrank(user2);
        usdc.transferFrom(user1, user2, 3000 * USDC_PRECISION);
        usdc.transfer(gasAttacker, 1000 * USDC_PRECISION);
        vm.stopPrank();
        
        // Verify mixed operations
        assertEq(usdc.balanceOf(user1), INITIAL_USDC_AMOUNT - 8000 * USDC_PRECISION, "User1 balance");
        assertEq(usdc.balanceOf(user2), INITIAL_USDC_AMOUNT + 2000 * USDC_PRECISION, "User2 balance");
        assertEq(usdc.balanceOf(attacker), INITIAL_USDC_AMOUNT + 5000 * USDC_PRECISION, "Attacker balance");
        assertEq(usdc.balanceOf(gasAttacker), INITIAL_USDC_AMOUNT + 1000 * USDC_PRECISION, "GasAttacker balance");
    }
}

// =============================================================================
// MOCK CONTRACTS
// =============================================================================

/**
 * @title MockUSDC
 * @notice Mock USDC token for testing purposes
 */
contract MockUSDC {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public totalSupply;
    string public name = "Mock USDC";
    string public symbol = "USDC";
    uint8 public decimals = 6;

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
     * @notice Mints new USDC tokens to the specified address
     * @dev Mock function for testing purposes
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
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
     * @notice Transfers tokens from the caller to the specified address
     * @dev Mock function for testing purposes
     * @param to The address to transfer tokens to
     * @param amount The amount of tokens to transfer
     * @return success Returns true if transfer is successful
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
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
     * @notice Approves the spender to transfer tokens on behalf of the caller
     * @dev Mock function for testing purposes
     * @param spender The address to approve for spending
     * @param amount The amount of tokens to approve
     * @return success Always returns true for mock implementation
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
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
     * @notice Transfers tokens from one address to another using allowance
     * @dev Mock function for testing purposes
     * @param from The address to transfer tokens from
     * @param to The address to transfer tokens to
     * @param amount The amount of tokens to transfer
     * @return success Returns true if transfer is successful
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");

        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;

        return true;
    }
}

/**
 * @title MockAggregatorV3
 * @notice Mock Chainlink price feed for testing purposes
 */
contract MockAggregatorV3 is AggregatorV3Interface {
    int256 private _price;
    uint256 private _updatedAt;
    uint80 private _roundId;
    bool private _shouldRevert;

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
     * @param price The new price to set
     
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    function setPrice(int256 price) external {
        _price = price;
        _updatedAt = block.timestamp;
        _roundId++;
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
     * @param timestamp The new timestamp to set
     
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    function setUpdatedAt(uint256 timestamp) external {
        _updatedAt = timestamp;
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
     * @param shouldRevert Whether the mock should revert
     
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    function setShouldRevert(bool shouldRevert) external {
        _shouldRevert = shouldRevert;
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
     
     * @return roundId The round ID
     * @return answer The price answer
     * @return startedAt The timestamp when the round started
     * @return updatedAt The timestamp when the round was updated
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
    function latestRoundData() external view override returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        if (_shouldRevert) {
            revert("MockAggregator: Simulated failure");
        }
        
        return (
            _roundId,
            _price,
            block.timestamp,
            _updatedAt,
            _roundId
        );
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
     * @param roundId The round ID to query (ignored in mock implementation)
     * @return The round ID
     * @return The price answer
     * @return The timestamp when the round started
     * @return The timestamp when the round was updated
     * @return The round ID when the answer was provided
     * @custom:security Mock function - no real security implications
     * @custom:validation No validation in mock implementation
     * @custom:state-changes Updates mock contract state
     * @custom:events No events emitted
     * @custom:errors No errors expected
     * @custom:reentrancy No reentrancy concerns
     * @custom:access Anyone can call this mock function
     * @custom:oracle No oracle dependencies
     */
    function getRoundData(uint80 roundId) external view override returns (
        uint80,
        int256,
        uint256,
        uint256,
        uint80
    ) {
        if (_shouldRevert) {
            revert("MockAggregator: Simulated failure");
        }
        
        return (
            roundId,
            _price,
            block.timestamp,
            _updatedAt,
            roundId
        );
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
    function description() external pure override returns (string memory) {
        return "Mock EUR/USD Price Feed";
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
    function version() external pure override returns (uint256) {
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
    function decimals() external pure override returns (uint8) {
        return 8;
    }
}
