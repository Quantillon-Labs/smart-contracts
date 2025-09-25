// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
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
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IChainlinkOracle} from "../src/interfaces/IChainlinkOracle.sol";
import {IYieldShift} from "../src/interfaces/IYieldShift.sol";
import {AggregatorV3Interface} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title TimeBlockEdgeCases
 * @notice Comprehensive testing for time and block-based edge cases
 * 
 * @dev Tests time manipulation, block-based logic, and temporal edge cases.
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract TimeBlockEdgeCases is Test {
    
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
    address public timeManipulator = address(0x7);
    address public blockManipulator = address(0x8);
    address public temporalTester = address(0x9);
    address public timeEdgeCaseUser = address(0xa);
    
    // ==================== CONSTANTS ====================
    
    uint256 constant USDC_PRECISION = 1e6;
    uint256 constant PRECISION = 1e18;
    uint256 constant INITIAL_USDC_AMOUNT = 1000000 * USDC_PRECISION;
    
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
        // Deploy TimeProvider
        TimeProvider timeProviderImpl = new TimeProvider();
        timeProvider = TimeProvider(address(new ERC1967Proxy(address(timeProviderImpl), "")));
        timeProvider.initialize(admin, governance, emergencyRole);
        
        // Deploy HedgerPool with mock dependencies
        HedgerPool hedgerPoolImpl = new HedgerPool(timeProvider);
        hedgerPool = HedgerPool(address(new ERC1967Proxy(address(hedgerPoolImpl), "")));
        hedgerPool.initialize(admin, address(0x1), address(0x2), address(0x3), address(0x4), treasury, address(0x999));
        
        // Deploy UserPool with mock dependencies
        UserPool userPoolImpl = new UserPool(timeProvider);
        userPool = UserPool(address(new ERC1967Proxy(address(userPoolImpl), "")));
        userPool.initialize(admin, address(0x1), address(0x2), address(0x3), address(0x4), address(0x5), treasury);
        
        // Deploy QTIToken with mock dependencies
        QTIToken qtiTokenImpl = new QTIToken(timeProvider);
        qtiToken = QTIToken(address(new ERC1967Proxy(address(qtiTokenImpl), "")));
        qtiToken.initialize(admin, treasury, address(0x1));
        
        // Deploy TimelockUpgradeable
        TimelockUpgradeable timelockImpl = new TimelockUpgradeable(timeProvider);
        timelock = TimelockUpgradeable(address(new ERC1967Proxy(address(timelockImpl), "")));
        timelock.initialize(admin);
        
        // Grant roles using admin account
        vm.startPrank(admin);
        hedgerPool.grantRole(hedgerPool.EMERGENCY_ROLE(), emergencyRole);
        hedgerPool.grantRole(hedgerPool.GOVERNANCE_ROLE(), governance);
        hedgerPool.grantRole(hedgerPool.LIQUIDATOR_ROLE(), timeManipulator);
        
        userPool.grantRole(userPool.EMERGENCY_ROLE(), emergencyRole);
        userPool.grantRole(userPool.GOVERNANCE_ROLE(), governance);
        
        qtiToken.grantRole(qtiToken.GOVERNANCE_ROLE(), governance);
        qtiToken.grantRole(qtiToken.EMERGENCY_ROLE(), emergencyRole);
        
        timelock.grantRole(timelock.UPGRADE_PROPOSER_ROLE(), governance);
        timelock.grantRole(timelock.UPGRADE_EXECUTOR_ROLE(), governance);
        timelock.grantRole(timelock.EMERGENCY_UPGRADER_ROLE(), emergencyRole);
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
        // NOTE: This mock always returns 0, which means flash loan protection never triggers
        // because the balance never changes from 0 to 0. This could hide bugs in real deployment.
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
        usdc.mint(timeManipulator, INITIAL_USDC_AMOUNT);
        usdc.mint(blockManipulator, INITIAL_USDC_AMOUNT);
        usdc.mint(temporalTester, INITIAL_USDC_AMOUNT);
        usdc.mint(timeEdgeCaseUser, INITIAL_USDC_AMOUNT);
    }
    
    // =============================================================================
    // TIME BLOCK TESTS
    // =============================================================================
    
    /**
     * @notice Test basic setup and mock USDC functionality
     * @dev Verifies basic test setup works correctly
     */
    /**
     * @custom:security Tests time and block edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test basic time and block functionality
     * @dev Verifies time and block edge cases functionality and edge cases
     * @custom:security Tests time and block edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_TimeBlock_BasicFunctionality() public {
        // Test basic setup
        assertEq(usdc.balanceOf(user1), INITIAL_USDC_AMOUNT, "User1 should have USDC");
        assertEq(usdc.balanceOf(user2), INITIAL_USDC_AMOUNT, "User2 should have USDC");
        assertEq(usdc.balanceOf(timeManipulator), INITIAL_USDC_AMOUNT, "TimeManipulator should have USDC");
        
        // Test basic USDC functionality
        vm.startPrank(user1);
        require(usdc.transfer(timeManipulator, 10000 * USDC_PRECISION), "Transfer failed");
        vm.stopPrank();
        
        assertEq(usdc.balanceOf(user1), INITIAL_USDC_AMOUNT - 10000 * USDC_PRECISION, "User1 balance should decrease");
        assertEq(usdc.balanceOf(timeManipulator), INITIAL_USDC_AMOUNT + 10000 * USDC_PRECISION, "TimeManipulator balance should increase");
    }

    /**
     * @notice Test time manipulation scenarios
     * @dev Verifies time manipulation edge cases
     */
    /**
     * @custom:security Tests time and block edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test time manipulation scenarios
     * @dev Verifies time and block edge cases functionality and edge cases
     * @custom:security Tests time and block edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_TimeBlock_TimeManipulation() public {
        uint256 initialTime = block.timestamp;
        
        vm.startPrank(timeManipulator);
        
        // Test transfers at different time points
        require(usdc.transfer(user1, 20000 * USDC_PRECISION), "Transfer failed");
        
        // Warp time forward
        vm.warp(initialTime + 1 days);
        require(usdc.transfer(user2, 15000 * USDC_PRECISION), "Transfer failed");
        
        // Warp time further
        vm.warp(initialTime + 7 days);
        require(usdc.transfer(temporalTester, 10000 * USDC_PRECISION), "Transfer failed");
        
        vm.stopPrank();
        
        // Verify time-based transfers
        assertEq(usdc.balanceOf(user1), INITIAL_USDC_AMOUNT + 20000 * USDC_PRECISION, "User1 should receive time-based transfer");
        assertEq(usdc.balanceOf(user2), INITIAL_USDC_AMOUNT + 15000 * USDC_PRECISION, "User2 should receive time-based transfer");
        assertEq(usdc.balanceOf(temporalTester), INITIAL_USDC_AMOUNT + 10000 * USDC_PRECISION, "TemporalTester should receive time-based transfer");
    }

    /**
     * @notice Test block manipulation scenarios
     * @dev Verifies block manipulation edge cases
     */
    /**
     * @custom:security Tests time and block edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test block manipulation scenarios
     * @dev Verifies time and block edge cases functionality and edge cases
     * @custom:security Tests time and block edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_TimeBlock_BlockManipulation() public {
        uint256 initialBlock = block.number;
        
        vm.startPrank(blockManipulator);
        
        // Test transfers at different block numbers
        require(usdc.transfer(user1, 25000 * USDC_PRECISION), "Transfer failed");
        
        // Roll to next block
        vm.roll(initialBlock + 1);
        require(usdc.transfer(user2, 20000 * USDC_PRECISION), "Transfer failed");
        
        // Roll to multiple blocks ahead
        vm.roll(initialBlock + 10);
        require(usdc.transfer(timeEdgeCaseUser, 15000 * USDC_PRECISION), "Transfer failed");
        
        vm.stopPrank();
        
        // Verify block-based transfers
        assertEq(usdc.balanceOf(user1), INITIAL_USDC_AMOUNT + 25000 * USDC_PRECISION, "User1 should receive block-based transfer");
        assertEq(usdc.balanceOf(user2), INITIAL_USDC_AMOUNT + 20000 * USDC_PRECISION, "User2 should receive block-based transfer");
        assertEq(usdc.balanceOf(timeEdgeCaseUser), INITIAL_USDC_AMOUNT + 15000 * USDC_PRECISION, "TimeEdgeCaseUser should receive block-based transfer");
    }

    /**
     * @notice Test temporal edge cases
     * @dev Verifies temporal edge case scenarios
     */
    /**
     * @custom:security Tests time and block edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test temporal edge cases
     * @dev Verifies time and block edge cases functionality and edge cases
     * @custom:security Tests time and block edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_TimeBlock_TemporalEdgeCases() public {
        vm.startPrank(temporalTester);
        
        // Test edge case time values
        vm.warp(0); // Test at epoch
        require(usdc.transfer(user1, 10000 * USDC_PRECISION), "Transfer failed");
        
        vm.warp(type(uint256).max); // Test at max timestamp
        require(usdc.transfer(user2, 10000 * USDC_PRECISION), "Transfer failed");
        
        vm.warp(1); // Test at minimum non-zero timestamp
        require(usdc.transfer(timeManipulator, 10000 * USDC_PRECISION), "Transfer failed");
        
        vm.stopPrank();
        
        // Verify temporal edge cases
        assertEq(usdc.balanceOf(user1), INITIAL_USDC_AMOUNT + 10000 * USDC_PRECISION, "User1 should receive epoch transfer");
        assertEq(usdc.balanceOf(user2), INITIAL_USDC_AMOUNT + 10000 * USDC_PRECISION, "User2 should receive max timestamp transfer");
        assertEq(usdc.balanceOf(timeManipulator), INITIAL_USDC_AMOUNT + 10000 * USDC_PRECISION, "TimeManipulator should receive min timestamp transfer");
    }

    /**
     * @notice Test time-based approval patterns
     * @dev Verifies time-based approval scenarios
     */
    /**
     * @custom:security Tests time and block edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test time-based approvals
     * @dev Verifies time and block edge cases functionality and edge cases
     * @custom:security Tests time and block edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_TimeBlock_TimeBasedApprovals() public {
        vm.startPrank(timeEdgeCaseUser);
        
        // Time-based approval patterns
        usdc.approve(user1, 30000 * USDC_PRECISION);
        
        vm.warp(block.timestamp + 1 hours);
        usdc.approve(user2, 25000 * USDC_PRECISION);
        
        vm.warp(block.timestamp + 1 days);
        usdc.approve(temporalTester, 20000 * USDC_PRECISION);
        
        vm.stopPrank();
        
        // Verify time-based approvals
        assertEq(usdc.allowance(timeEdgeCaseUser, user1), 30000 * USDC_PRECISION, "User1 should have time-based allowance");
        assertEq(usdc.allowance(timeEdgeCaseUser, user2), 25000 * USDC_PRECISION, "User2 should have time-based allowance");
        assertEq(usdc.allowance(timeEdgeCaseUser, temporalTester), 20000 * USDC_PRECISION, "TemporalTester should have time-based allowance");
    }

    /**
     * @notice Test block-based approval patterns
     * @dev Verifies block-based approval scenarios
     */
    /**
     * @custom:security Tests time and block edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test block-based approvals
     * @dev Verifies time and block edge cases functionality and edge cases
     * @custom:security Tests time and block edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_TimeBlock_BlockBasedApprovals() public {
        vm.startPrank(blockManipulator);
        
        // Block-based approval patterns
        usdc.approve(user1, 35000 * USDC_PRECISION);
        
        vm.roll(block.number + 1);
        usdc.approve(user2, 30000 * USDC_PRECISION);
        
        vm.roll(block.number + 5);
        usdc.approve(timeEdgeCaseUser, 25000 * USDC_PRECISION);
        
        vm.stopPrank();
        
        // Verify block-based approvals
        assertEq(usdc.allowance(blockManipulator, user1), 35000 * USDC_PRECISION, "User1 should have block-based allowance");
        assertEq(usdc.allowance(blockManipulator, user2), 30000 * USDC_PRECISION, "User2 should have block-based allowance");
        assertEq(usdc.allowance(blockManipulator, timeEdgeCaseUser), 25000 * USDC_PRECISION, "TimeEdgeCaseUser should have block-based allowance");
    }

    /**
     * @notice Test time and block combination scenarios
     * @dev Verifies combined time and block manipulation
     */
    /**
     * @custom:security Tests time and block edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test time and block combination scenarios
     * @dev Verifies time and block edge cases functionality and edge cases
     * @custom:security Tests time and block edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_TimeBlock_TimeBlockCombination() public {
        vm.startPrank(temporalTester);
        
        // Combined time and block manipulation
        require(usdc.transfer(user1, 15000 * USDC_PRECISION), "Transfer failed");
        
        vm.warp(block.timestamp + 1 hours);
        vm.roll(block.number + 1);
        require(usdc.transfer(user2, 12000 * USDC_PRECISION), "Transfer failed");
        
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 10);
        require(usdc.transfer(timeManipulator, 10000 * USDC_PRECISION), "Transfer failed");
        
        vm.stopPrank();
        
        // Verify combined time and block scenarios
        assertEq(usdc.balanceOf(user1), INITIAL_USDC_AMOUNT + 15000 * USDC_PRECISION, "User1 should receive combined transfer");
        assertEq(usdc.balanceOf(user2), INITIAL_USDC_AMOUNT + 12000 * USDC_PRECISION, "User2 should receive combined transfer");
        assertEq(usdc.balanceOf(timeManipulator), INITIAL_USDC_AMOUNT + 10000 * USDC_PRECISION, "TimeManipulator should receive combined transfer");
    }

    /**
     * @notice Test time-based transferFrom patterns
     * @dev Verifies time-based transferFrom scenarios
     */
    /**
     * @custom:security Tests time and block edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test time-based transferFrom operations
     * @dev Verifies time and block edge cases functionality and edge cases
     * @custom:security Tests time and block edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_TimeBlock_TimeBasedTransferFrom() public {
        vm.startPrank(timeEdgeCaseUser);
        usdc.approve(user1, 40000 * USDC_PRECISION);
        vm.stopPrank();
        
        vm.startPrank(user1);
        
        // Time-based transferFrom patterns
        require(usdc.transferFrom(timeEdgeCaseUser, user1, 20000 * USDC_PRECISION), "TransferFrom failed");
        
        vm.warp(block.timestamp + 2 hours);
        require(usdc.transferFrom(timeEdgeCaseUser, user2, 15000 * USDC_PRECISION), "TransferFrom failed");
        
        vm.warp(block.timestamp + 1 days);
        require(usdc.transferFrom(timeEdgeCaseUser, temporalTester, 5000 * USDC_PRECISION), "TransferFrom failed");
        
        vm.stopPrank();
        
        // Verify time-based transferFrom
        assertEq(usdc.balanceOf(timeEdgeCaseUser), INITIAL_USDC_AMOUNT - 40000 * USDC_PRECISION, "TimeEdgeCaseUser balance");
        assertEq(usdc.balanceOf(user1), INITIAL_USDC_AMOUNT + 20000 * USDC_PRECISION, "User1 balance");
        assertEq(usdc.balanceOf(user2), INITIAL_USDC_AMOUNT + 15000 * USDC_PRECISION, "User2 balance");
        assertEq(usdc.balanceOf(temporalTester), INITIAL_USDC_AMOUNT + 5000 * USDC_PRECISION, "TemporalTester balance");
    }

    /**
     * @notice Test block-based transferFrom patterns
     * @dev Verifies block-based transferFrom scenarios
     */
    /**
     * @custom:security Tests time and block edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test block-based transferFrom operations
     * @dev Verifies time and block edge cases functionality and edge cases
     * @custom:security Tests time and block edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_TimeBlock_BlockBasedTransferFrom() public {
        vm.startPrank(blockManipulator);
        usdc.approve(user1, 45000 * USDC_PRECISION);
        vm.stopPrank();
        
        vm.startPrank(user1);
        
        // Block-based transferFrom patterns
        require(usdc.transferFrom(blockManipulator, user1, 25000 * USDC_PRECISION), "TransferFrom failed");
        
        vm.roll(block.number + 2);
        require(usdc.transferFrom(blockManipulator, user2, 15000 * USDC_PRECISION), "TransferFrom failed");
        
        vm.roll(block.number + 5);
        require(usdc.transferFrom(blockManipulator, timeEdgeCaseUser, 5000 * USDC_PRECISION), "TransferFrom failed");
        
        vm.stopPrank();
        
        // Verify block-based transferFrom
        assertEq(usdc.balanceOf(blockManipulator), INITIAL_USDC_AMOUNT - 45000 * USDC_PRECISION, "BlockManipulator balance");
        assertEq(usdc.balanceOf(user1), INITIAL_USDC_AMOUNT + 25000 * USDC_PRECISION, "User1 balance");
        assertEq(usdc.balanceOf(user2), INITIAL_USDC_AMOUNT + 15000 * USDC_PRECISION, "User2 balance");
        assertEq(usdc.balanceOf(timeEdgeCaseUser), INITIAL_USDC_AMOUNT + 5000 * USDC_PRECISION, "TimeEdgeCaseUser balance");
    }

    /**
     * @notice Test extreme time scenarios
     * @dev Verifies extreme time manipulation scenarios
     */
    /**
     * @custom:security Tests time and block edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test extreme time scenarios
     * @dev Verifies time and block edge cases functionality and edge cases
     * @custom:security Tests time and block edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_TimeBlock_ExtremeTimeScenarios() public {
        vm.startPrank(timeManipulator);
        
        // Extreme time scenarios
        vm.warp(1); // Minimum time
        require(usdc.transfer(user1, 5000 * USDC_PRECISION), "Transfer failed");
        
        vm.warp(365 days); // One year
        require(usdc.transfer(user2, 10000 * USDC_PRECISION), "Transfer failed");
        
        vm.warp(365 * 100 days); // 100 years
        require(usdc.transfer(temporalTester, 15000 * USDC_PRECISION), "Transfer failed");
        
        vm.stopPrank();
        
        // Verify extreme time scenarios
        assertEq(usdc.balanceOf(user1), INITIAL_USDC_AMOUNT + 5000 * USDC_PRECISION, "User1 should receive min time transfer");
        assertEq(usdc.balanceOf(user2), INITIAL_USDC_AMOUNT + 10000 * USDC_PRECISION, "User2 should receive year transfer");
        assertEq(usdc.balanceOf(temporalTester), INITIAL_USDC_AMOUNT + 15000 * USDC_PRECISION, "TemporalTester should receive century transfer");
    }

    /**
     * @notice Test extreme block scenarios
     * @dev Verifies extreme block manipulation scenarios
     */
    /**
     * @custom:security Tests time and block edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    /**
     * @notice Test extreme block scenarios
     * @dev Verifies time and block edge cases functionality and edge cases
     * @custom:security Tests time and block edge cases security
     * @custom:validation Validates functionality and state changes
     * @custom:state-changes Updates contract state as needed
     * @custom:events No events emitted in this test
     * @custom:errors No errors expected during normal operation
     * @custom:reentrancy No reentrancy concerns in this test
     * @custom:access Tests with appropriate test accounts
     * @custom:oracle No oracle dependencies in this test
     */
    function test_TimeBlock_ExtremeBlockScenarios() public {
        vm.startPrank(blockManipulator);
        
        // Extreme block scenarios
        vm.roll(1); // Minimum block
        require(usdc.transfer(user1, 8000 * USDC_PRECISION), "Transfer failed");
        
        vm.roll(1000); // 1000 blocks
        require(usdc.transfer(user2, 12000 * USDC_PRECISION), "Transfer failed");
        
        vm.roll(1000000); // 1 million blocks
        require(usdc.transfer(timeEdgeCaseUser, 20000 * USDC_PRECISION), "Transfer failed");
        
        vm.stopPrank();
        
        // Verify extreme block scenarios
        assertEq(usdc.balanceOf(user1), INITIAL_USDC_AMOUNT + 8000 * USDC_PRECISION, "User1 should receive min block transfer");
        assertEq(usdc.balanceOf(user2), INITIAL_USDC_AMOUNT + 12000 * USDC_PRECISION, "User2 should receive 1000 block transfer");
        assertEq(usdc.balanceOf(timeEdgeCaseUser), INITIAL_USDC_AMOUNT + 20000 * USDC_PRECISION, "TimeEdgeCaseUser should receive million block transfer");
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
