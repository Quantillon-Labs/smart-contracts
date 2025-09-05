// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {stQEUROToken} from "../src/core/stQEUROToken.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IYieldShift} from "../src/interfaces/IYieldShift.sol";
import {ErrorLibrary} from "../src/libraries/ErrorLibrary.sol";

/**
 * @title stQEUROTokenTestSuite
 * @notice Comprehensive test suite for the stQEUROToken contract
 * 
 * @dev This test suite covers:
 *      - Contract initialization and setup
 *      - Staking and unstaking mechanics
 *      - Exchange rate calculations and updates
 *      - Yield distribution and management
 *      - Fee structure and treasury operations
 *      - Emergency functions (pause/unpause)
 *      - Administrative functions
 *      - Recovery functions
 *      - Edge cases and security scenarios
 * 
 * @dev Test categories:
 *      - Setup and Initialization
 *      - Staking Functions
 *      - Unstaking Functions
 *      - Yield Functions
 *      - Exchange Rate Functions
 *      - Emergency Functions
 *      - Administrative Functions
 *      - Recovery Functions
 *      - Edge Cases and Security
 *      - Integration Tests
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract stQEUROTokenTestSuite is Test {
    // =============================================================================
    // TEST CONTRACTS AND ADDRESSES
    // =============================================================================
    
    stQEUROToken public implementation;
    stQEUROToken public stQEURO;
    
    // Mock contracts for testing
    address public mockQEURO = address(0x1);
    address public mockYieldShift = address(0x2);
    address public mockUSDC = address(0x3);
    address public mockTimelock = address(0x123);
    
    // Test addresses
    address public admin = address(0x4);
    address public treasury = address(0x5);
    address public user1 = address(0x6);
    address public user2 = address(0x7);
    address public user3 = address(0x8);
    address public yieldManager = address(0x9);
    address public governance = address(0xA);
    
    // Test amounts
    uint256 public constant INITIAL_QEURO_AMOUNT = 1000000 * 1e18; // 1M QEURO
    uint256 public constant STAKE_AMOUNT = 100000 * 1e18; // 100k QEURO
    uint256 public constant SMALL_AMOUNT = 10000 * 1e18; // 10k QEURO
    uint256 public constant YIELD_AMOUNT = 10000 * 1e6; // 10k USDC
    
    // =============================================================================
    // EVENTS FOR TESTING
    // =============================================================================
    
    event QEUROStaked(address indexed user, uint256 qeuroAmount, uint256 stQEUROAmount);
    event QEUROUnstaked(address indexed user, uint256 stQEUROAmount, uint256 qeuroAmount);
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate, uint256 timestamp);
    event YieldDistributed(uint256 yieldAmount, uint256 newExchangeRate);
    event YieldClaimed(address indexed user, uint256 yieldAmount);
    event YieldParametersUpdated(uint256 yieldFee, uint256 minYieldThreshold, uint256 maxUpdateFrequency);

    // =============================================================================
    // SETUP AND TEARDOWN
    // =============================================================================
    
    /**
     * @notice Set up test environment before each test
     * @dev Deploys a new stQEUROToken contract using proxy pattern and initializes it
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function setUp() public {
        // Deploy TimeProvider through proxy
        TimeProvider timeProviderImpl = new TimeProvider();
        bytes memory timeProviderInitData = abi.encodeWithSelector(
            TimeProvider.initialize.selector,
            admin,
            admin,
            admin
        );
        ERC1967Proxy timeProviderProxy = new ERC1967Proxy(address(timeProviderImpl), timeProviderInitData);
        TimeProvider timeProvider = TimeProvider(address(timeProviderProxy));
        
        // Deploy implementation
        implementation = new stQEUROToken(timeProvider);
        
        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(
            stQEUROToken.initialize.selector,
            admin,
            mockQEURO,
            mockYieldShift,
            mockUSDC,
            treasury,
            mockTimelock
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        
        stQEURO = stQEUROToken(address(proxy));
        
        // Grant additional roles for testing
        vm.prank(admin);
        stQEURO.grantRole(keccak256("YIELD_MANAGER_ROLE"), yieldManager);
        vm.prank(admin);
        stQEURO.grantRole(keccak256("GOVERNANCE_ROLE"), governance);
        
        // Setup mock balances for testing
        vm.mockCall(
            mockQEURO,
            abi.encodeWithSelector(IERC20.balanceOf.selector, user1),
            abi.encode(INITIAL_QEURO_AMOUNT)
        );
        vm.mockCall(
            mockQEURO,
            abi.encodeWithSelector(IERC20.balanceOf.selector, user2),
            abi.encode(INITIAL_QEURO_AMOUNT)
        );
        vm.mockCall(
            mockQEURO,
            abi.encodeWithSelector(IERC20.balanceOf.selector, user3),
            abi.encode(INITIAL_QEURO_AMOUNT)
        );
        
        // Setup mock transferFrom calls to succeed (with specific parameters)
        vm.mockCall(
            mockQEURO,
            abi.encodeWithSelector(IERC20.transferFrom.selector, user1, address(stQEURO), STAKE_AMOUNT),
            abi.encode(true)
        );
        vm.mockCall(
            mockQEURO,
            abi.encodeWithSelector(IERC20.transferFrom.selector, user2, address(stQEURO), STAKE_AMOUNT),
            abi.encode(true)
        );
        vm.mockCall(
            mockQEURO,
            abi.encodeWithSelector(IERC20.transferFrom.selector, user3, address(stQEURO), STAKE_AMOUNT),
            abi.encode(true)
        );
        
        // Setup mock transfer calls to succeed (with specific parameters)
        // Note: These will be overridden in individual tests for yield scenarios
        vm.mockCall(
            mockQEURO,
            abi.encodeWithSelector(IERC20.transfer.selector, user1, STAKE_AMOUNT),
            abi.encode(true)
        );
        vm.mockCall(
            mockQEURO,
            abi.encodeWithSelector(IERC20.transfer.selector, user2, STAKE_AMOUNT),
            abi.encode(true)
        );
        vm.mockCall(
            mockQEURO,
            abi.encodeWithSelector(IERC20.transfer.selector, user3, STAKE_AMOUNT),
            abi.encode(true)
        );
        
        // Setup mock USDC transferFrom calls to succeed
        vm.mockCall(
            mockUSDC,
            abi.encodeWithSelector(IERC20.transferFrom.selector, yieldManager, address(stQEURO), YIELD_AMOUNT),
            abi.encode(true)
        );
        
        // Setup mock USDC transfer calls to succeed
        vm.mockCall(
            mockUSDC,
            abi.encodeWithSelector(IERC20.transfer.selector, treasury, YIELD_AMOUNT / 10),
            abi.encode(true)
        );
        
        // Setup mock YieldShift calls
        vm.mockCall(
            mockYieldShift,
            abi.encodeWithSelector(IYieldShift.getUserPendingYield.selector, address(stQEURO)),
            abi.encode(0)
        );
    }

    // =============================================================================
    // INITIALIZATION TESTS
    // =============================================================================
    
    /**
     * @notice Test successful contract initialization
     * @dev Verifies proper initialization with valid parameters
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function testInitialization_WithValidParameters_ShouldInitializeCorrectly() public view {
        // Check token details
        assertEq(stQEURO.name(), "Staked Quantillon Euro");
        assertEq(stQEURO.symbol(), "stQEURO");
        assertEq(stQEURO.decimals(), 18);
        assertEq(stQEURO.totalSupply(), 0);
        
        // Check roles are properly assigned
        assertTrue(stQEURO.hasRole(stQEURO.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(stQEURO.hasRole(keccak256("YIELD_MANAGER_ROLE"), yieldManager));
        assertTrue(stQEURO.hasRole(keccak256("GOVERNANCE_ROLE"), governance));
        
        // Check initial state variables - only check what's actually available
        assertTrue(stQEURO.hasRole(stQEURO.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(stQEURO.hasRole(keccak256("YIELD_MANAGER_ROLE"), yieldManager));
        assertTrue(stQEURO.hasRole(keccak256("GOVERNANCE_ROLE"), governance));
    }
    
    /**
     * @notice Test initialization with zero addresses should revert
     * @dev Verifies that initialization fails with invalid parameters
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Initialization_ZeroAddresses_Revert() public {
        // Create implementation once to reuse
        TimeProvider timeProviderImpl2 = new TimeProvider();
        bytes memory timeProviderInitData2 = abi.encodeWithSelector(
            TimeProvider.initialize.selector,
            admin,
            admin,
            admin
        );
        ERC1967Proxy timeProviderProxy2 = new ERC1967Proxy(address(timeProviderImpl2), timeProviderInitData2);
        TimeProvider timeProvider2 = TimeProvider(address(timeProviderProxy2));
        
        stQEUROToken testImplementation = new stQEUROToken(timeProvider2);
        
        // Test with zero admin
        bytes memory initData1 = abi.encodeWithSelector(
            stQEUROToken.initialize.selector,
            address(0),
            mockQEURO,
            mockYieldShift,
            mockUSDC,
            treasury,
            mockTimelock
        );
        
        vm.expectRevert("stQEURO: Admin cannot be zero");
        new ERC1967Proxy(address(testImplementation), initData1);
        
        // Test with zero QEURO
        bytes memory initData2 = abi.encodeWithSelector(
            stQEUROToken.initialize.selector,
            admin,
            address(0),
            mockYieldShift,
            mockUSDC,
            treasury,
            mockTimelock
        );
        
        vm.expectRevert("stQEURO: QEURO cannot be zero");
        new ERC1967Proxy(address(testImplementation), initData2);
        
        // Test with zero YieldShift
        bytes memory initData3 = abi.encodeWithSelector(
            stQEUROToken.initialize.selector,
            admin,
            mockQEURO,
            address(0),
            mockUSDC,
            treasury,
            mockTimelock
        );
        
        vm.expectRevert("stQEURO: YieldShift cannot be zero");
        new ERC1967Proxy(address(testImplementation), initData3);
        
        // Test with zero USDC
        bytes memory initData4 = abi.encodeWithSelector(
            stQEUROToken.initialize.selector,
            admin,
            mockQEURO,
            mockYieldShift,
            address(0),
            treasury,
            mockTimelock
        );
        
        vm.expectRevert("stQEURO: USDC cannot be zero");
        new ERC1967Proxy(address(testImplementation), initData4);
        
        // Test with zero treasury
        bytes memory initData5 = abi.encodeWithSelector(
            stQEUROToken.initialize.selector,
            admin,
            mockQEURO,
            mockYieldShift,
            mockUSDC,
            address(0),
            mockTimelock
        );
        
        vm.expectRevert("stQEURO: Treasury cannot be zero");
        new ERC1967Proxy(address(testImplementation), initData5);
    }
    
    /**
     * @notice Test that initialization can only be called once
     * @dev Verifies the initializer modifier works correctly
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Initialization_CalledTwice_Revert() public {
        // Try to call initialize again on the proxy
        vm.expectRevert();
        stQEURO.initialize(admin, mockQEURO, mockYieldShift, mockUSDC, treasury, mockTimelock);
    }

    // =============================================================================
    // STAKING TESTS
    // =============================================================================
    
    /**
     * @notice Test successful QEURO staking
     * @dev Verifies that users can stake QEURO to receive stQEURO
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Staking_StakeSuccess() public {
        vm.prank(user1);
        uint256 stQEUROAmount = stQEURO.stake(STAKE_AMOUNT);
        
        // Check stQEURO amount received (should be equal to QEURO amount initially)
        assertEq(stQEUROAmount, STAKE_AMOUNT);
        
        // Check user balance
        assertEq(stQEURO.balanceOf(user1), STAKE_AMOUNT);
        
        // Check total supply
        assertEq(stQEURO.totalSupply(), STAKE_AMOUNT);
        
        // Check total underlying
        assertEq(stQEURO.totalUnderlying(), STAKE_AMOUNT);
        
        // Check exchange rate (should still be 1:1)
        assertEq(stQEURO.exchangeRate(), 1e18);
    }
    
    /**
     * @notice Test staking with zero amount should revert
     * @dev Verifies that staking zero QEURO is prevented
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Staking_StakeZeroAmount_Revert() public {
        vm.prank(user1);
        vm.expectRevert("stQEURO: Amount must be positive");
        stQEURO.stake(0);
    }
    
    /**
     * @notice Test staking with insufficient QEURO balance should revert
     * @dev Verifies that users cannot stake more QEURO than they have
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Staking_StakeInsufficientBalance_Revert() public {
        uint256 tooMuch = INITIAL_QEURO_AMOUNT + 1;
        
        vm.prank(user1);
        vm.expectRevert("stQEURO: Insufficient QEURO balance");
        stQEURO.stake(tooMuch);
    }
    
    /**
     * @notice Test staking when contract is paused should revert
     * @dev Verifies that staking is blocked when contract is paused
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Staking_StakeWhenPaused_Revert() public {
        // Pause the contract
        vm.prank(admin);
        stQEURO.pause();
        
        // Try to stake
        vm.prank(user1);
        vm.expectRevert();
        stQEURO.stake(STAKE_AMOUNT);
    }
    
    /**
     * @notice Test multiple users staking
     * @dev Verifies that multiple users can stake QEURO
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Staking_MultipleUsersStake() public {
        // User1 stakes
        vm.prank(user1);
        uint256 stQEURO1 = stQEURO.stake(STAKE_AMOUNT);
        assertEq(stQEURO1, STAKE_AMOUNT);
        assertEq(stQEURO.balanceOf(user1), STAKE_AMOUNT);
        
        // User2 stakes
        vm.prank(user2);
        uint256 stQEURO2 = stQEURO.stake(STAKE_AMOUNT);
        assertEq(stQEURO2, STAKE_AMOUNT);
        assertEq(stQEURO.balanceOf(user2), STAKE_AMOUNT);
        
        // Check total supply
        assertEq(stQEURO.totalSupply(), 2 * STAKE_AMOUNT);
        
        // Check total underlying
        assertEq(stQEURO.totalUnderlying(), 2 * STAKE_AMOUNT);
    }

    // =============================================================================
    // UNSTAKING TESTS
    // =============================================================================
    
    /**
     * @notice Test successful QEURO unstaking
     * @dev Verifies that users can unstake QEURO by burning stQEURO
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Unstaking_UnstakeSuccess() public {
        // First stake some QEURO
        vm.prank(user1);
        stQEURO.stake(STAKE_AMOUNT);
        
        // Then unstake
        vm.prank(user1);
        uint256 qeuroAmount = stQEURO.unstake(STAKE_AMOUNT);
        
        // Check QEURO amount received (should be equal to stQEURO amount initially)
        assertEq(qeuroAmount, STAKE_AMOUNT);
        
        // Check user balance (should be 0)
        assertEq(stQEURO.balanceOf(user1), 0);
        
        // Check total supply (should be 0)
        assertEq(stQEURO.totalSupply(), 0);
        
        // Check total underlying (should be 0)
        assertEq(stQEURO.totalUnderlying(), 0);
    }

    // =============================================================================
    // BATCH FUNCTION TESTS
    // =============================================================================

    /**
     * @notice Tests successful batch staking of multiple amounts
     * @dev Validates that batch staking works correctly with multiple valid amounts
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_BatchStake_Success() public {
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 10_000 * 1e18;
        amounts[1] = 20_000 * 1e18;
        amounts[2] = 30_000 * 1e18;

        vm.prank(user1);
        uint256[] memory minted = stQEURO.batchStake(amounts);

        assertEq(minted.length, 3);
        assertEq(stQEURO.balanceOf(user1), 60_000 * 1e18);
        assertEq(stQEURO.totalUnderlying(), 60_000 * 1e18);
    }

    /**
     * @notice Tests successful batch unstaking of multiple amounts
     * @dev Validates that batch unstaking works correctly with multiple valid amounts
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_BatchUnstake_Success() public {
        // Stake first
        vm.prank(user1);
        stQEURO.stake(60_000 * 1e18);

        uint256[] memory burnAmounts = new uint256[](2);
        burnAmounts[0] = 10_000 * 1e18;
        burnAmounts[1] = 20_000 * 1e18;

        vm.prank(user1);
        uint256[] memory received = stQEURO.batchUnstake(burnAmounts);

        assertEq(received.length, 2);
        assertEq(stQEURO.balanceOf(user1), 30_000 * 1e18);
        assertEq(stQEURO.totalUnderlying(), 30_000 * 1e18);
    }

    /**
     * @notice Tests successful batch transfer of tokens to multiple recipients
     * @dev Validates that batch transfers work correctly with multiple valid transfers
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_BatchTransfer_Success() public {
        // Stake then transfer out
        vm.prank(user1);
        stQEURO.stake(50_000 * 1e18);

        address[] memory recipients = new address[](2);
        recipients[0] = user2;
        recipients[1] = user3;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 5_000 * 1e18;
        amounts[1] = 10_000 * 1e18;

        vm.prank(user1);
        stQEURO.batchTransfer(recipients, amounts);

        assertEq(stQEURO.balanceOf(user1), 35_000 * 1e18);
        assertEq(stQEURO.balanceOf(user2), 5_000 * 1e18);
        assertEq(stQEURO.balanceOf(user3), 10_000 * 1e18);
    }

    // =============================================================================
    // BATCH SIZE LIMIT TESTS
    // =============================================================================

    /**
     * @notice Tests that batch staking reverts when batch size exceeds limit
     * @dev Validates that the batch size limit is enforced for staking operations
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_BatchStake_BatchSizeTooLarge_Revert() public {
        // Create array larger than MAX_BATCH_SIZE (100)
        uint256[] memory amounts = new uint256[](101);
        
        for (uint256 i = 0; i < 101; i++) {
            amounts[i] = 1e18;
        }

        vm.prank(user1);
        vm.expectRevert(ErrorLibrary.BatchSizeTooLarge.selector);
        stQEURO.batchStake(amounts);
    }

    /**
     * @notice Tests that batch unstaking reverts when batch size exceeds limit
     * @dev Validates that the batch size limit is enforced for unstaking operations
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_BatchUnstake_BatchSizeTooLarge_Revert() public {
        // Create array larger than MAX_BATCH_SIZE (100)
        uint256[] memory amounts = new uint256[](101);
        
        for (uint256 i = 0; i < 101; i++) {
            amounts[i] = 1e18;
        }

        vm.prank(user1);
        vm.expectRevert(ErrorLibrary.BatchSizeTooLarge.selector);
        stQEURO.batchUnstake(amounts);
    }

    /**
     * @notice Tests that batch transfer reverts when batch size exceeds limit
     * @dev Validates that the batch size limit is enforced for transfer operations
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_BatchTransfer_BatchSizeTooLarge_Revert() public {
        // Create array larger than MAX_BATCH_SIZE (100)
        address[] memory recipients = new address[](101);
        uint256[] memory amounts = new uint256[](101);
        
        for (uint256 i = 0; i < 101; i++) {
            recipients[i] = address(uint160(i + 1000)); // Generate unique addresses
            amounts[i] = 1e18;
        }

        vm.prank(user1);
        vm.expectRevert(ErrorLibrary.BatchSizeTooLarge.selector);
        stQEURO.batchTransfer(recipients, amounts);
    }

    /**
     * @notice Tests successful batch staking at maximum batch size
     * @dev Validates that staking works correctly at the maximum allowed batch size
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_BatchStake_MaxBatchSize_Success() public {
        // Test with exactly MAX_BATCH_SIZE (100)
        uint256[] memory amounts = new uint256[](100);
        
        for (uint256 i = 0; i < 100; i++) {
            amounts[i] = 1e18;
        }

        vm.prank(user1);
        uint256[] memory minted = stQEURO.batchStake(amounts);

        assertEq(minted.length, 100);
        assertEq(stQEURO.balanceOf(user1), 100 * 1e18);
        assertEq(stQEURO.totalUnderlying(), 100 * 1e18);
    }

    // =============================================================================
    // VIRTUAL PROTECTION TESTS
    // =============================================================================

    /**
     * @notice Tests the virtual protection status functionality
     * @dev Validates that virtual protection status is correctly tracked and reported
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_VirtualProtection_Status() public {
        // Test virtual protection status function
        (uint256 virtualShares, uint256 virtualAssets, uint256 effectiveSupply, uint256 effectiveAssets) = stQEURO.getVirtualProtectionStatus();
        
        assertEq(virtualShares, 1e8, "Virtual shares should be 1e8");
        assertEq(virtualAssets, 1e8, "Virtual assets should be 1e8");
        assertEq(effectiveSupply, stQEURO.totalSupply() + 1e8, "Effective supply should include virtual shares");
        assertEq(effectiveAssets, stQEURO.totalUnderlying() + 1e8, "Effective assets should include virtual assets");
    }

    /**
     * @notice Tests that virtual protection prevents donation attacks
     * @dev Validates that the virtual protection mechanism prevents malicious donation attacks
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_VirtualProtection_DonationAttackPrevention() public {
        // Test that virtual protection prevents donation attacks
        uint256 initialSupply = stQEURO.totalSupply();
        uint256 initialUnderlying = stQEURO.totalUnderlying();
        
        // The virtual protection should ensure that even with 0 supply and underlying,
        // the effective values are reasonable due to virtual shares/assets
        (,, uint256 effectiveSupply, uint256 effectiveAssets) = stQEURO.getVirtualProtectionStatus();
        
        // Virtual protection should provide reasonable base values
        assertEq(effectiveSupply, 1e8, "Effective supply should be at least virtual shares");
        assertEq(effectiveAssets, 1e8, "Effective assets should be at least virtual assets");
        
        // The effective exchange rate should be 1:1 when no real tokens exist
        uint256 effectiveRate = effectiveAssets * 1e18 / effectiveSupply;
        assertEq(effectiveRate, 1e18, "Effective rate should be 1:1 with virtual protection");
        
        // This demonstrates that virtual protection prevents the exchange rate from being
        // undefined or extremely high when no real tokens exist
    }
    
    /**
     * @notice Test unstaking with zero amount should revert
     * @dev Verifies that unstaking zero stQEURO is prevented
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Unstaking_UnstakeZeroAmount_Revert() public {
        vm.prank(user1);
        vm.expectRevert("stQEURO: Amount must be positive");
        stQEURO.unstake(0);
    }
    
    /**
     * @notice Test unstaking with insufficient stQEURO balance should revert
     * @dev Verifies that users cannot unstake more stQEURO than they have
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Unstaking_UnstakeInsufficientBalance_Revert() public {
        uint256 tooMuch = STAKE_AMOUNT + 1;
        
        vm.prank(user1);
        vm.expectRevert("stQEURO: Insufficient stQEURO balance");
        stQEURO.unstake(tooMuch);
    }
    
    /**
     * @notice Test unstaking when contract is paused should revert
     * @dev Verifies that unstaking is blocked when contract is paused
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Unstaking_UnstakeWhenPaused_Revert() public {
        // First stake some QEURO
        vm.prank(user1);
        stQEURO.stake(STAKE_AMOUNT);
        
        // Pause the contract
        vm.prank(admin);
        stQEURO.pause();
        
        // Try to unstake
        vm.prank(user1);
        vm.expectRevert();
        stQEURO.unstake(STAKE_AMOUNT);
    }
    
    /**
     * @notice Test partial unstaking
     * @dev Verifies that users can unstake part of their stQEURO
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Unstaking_PartialUnstake() public {
        // First stake some QEURO
        vm.prank(user1);
        stQEURO.stake(STAKE_AMOUNT);
        
        // Unstake half
        uint256 unstakeAmount = STAKE_AMOUNT / 2;
        vm.prank(user1);
        uint256 qeuroAmount = stQEURO.unstake(unstakeAmount);
        
        // Check QEURO amount received
        assertEq(qeuroAmount, unstakeAmount);
        
        // Check remaining stQEURO balance
        assertEq(stQEURO.balanceOf(user1), STAKE_AMOUNT - unstakeAmount);
        
        // Check total supply
        assertEq(stQEURO.totalSupply(), STAKE_AMOUNT - unstakeAmount);
        
        // Check total underlying
        assertEq(stQEURO.totalUnderlying(), STAKE_AMOUNT - unstakeAmount);
    }

    // =============================================================================
    // YIELD TESTS
    // =============================================================================
    
    /**
     * @notice Test yield distribution
     * @dev Verifies that yield can be distributed to increase exchange rate
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Yield_DistributeYield() public {
        // First stake some QEURO
        vm.prank(user1);
        stQEURO.stake(STAKE_AMOUNT);
        
        // Distribute yield
        vm.prank(yieldManager);
        stQEURO.distributeYield(YIELD_AMOUNT);
        
        // Check that exchange rate increased
        uint256 newRate = stQEURO.exchangeRate();
        assertGt(newRate, 1e18);
        
        // Check total yield earned
        assertEq(stQEURO.totalYieldEarned(), YIELD_AMOUNT * 9 / 10); // 90% after 10% fee
    }
    
    /**
     * @notice Test yield distribution with zero amount should revert
     * @dev Verifies that distributing zero yield is prevented
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Yield_DistributeZeroYield_Revert() public {
        vm.prank(yieldManager);
        vm.expectRevert("stQEURO: Yield amount must be positive");
        stQEURO.distributeYield(0);
    }
    
    /**
     * @notice Test yield distribution with no stQEURO supply should revert
     * @dev Verifies that yield cannot be distributed when no one has staked
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Yield_DistributeYieldNoSupply_Revert() public {
        vm.prank(yieldManager);
        vm.expectRevert("stQEURO: No stQEURO supply");
        stQEURO.distributeYield(YIELD_AMOUNT);
    }
    
    /**
     * @notice Test yield distribution by non-yield manager should revert
     * @dev Verifies that only yield manager can distribute yield
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Yield_DistributeYieldByNonManager_Revert() public {
        // First stake some QEURO
        vm.prank(user1);
        stQEURO.stake(STAKE_AMOUNT);
        
        // Try to distribute yield by non-manager
        vm.prank(user1);
        vm.expectRevert();
        stQEURO.distributeYield(YIELD_AMOUNT);
    }
    
    /**
     * @notice Test yield distribution and exchange rate increase
     * @dev Verifies that yield distribution increases the exchange rate
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Yield_UnstakeAfterYieldDistribution() public {
        // First stake some QEURO
        vm.prank(user1);
        stQEURO.stake(STAKE_AMOUNT);
        
        // Check initial exchange rate
        uint256 initialRate = stQEURO.exchangeRate();
        assertEq(initialRate, 1e18);
        
        // Distribute yield
        vm.prank(yieldManager);
        stQEURO.distributeYield(YIELD_AMOUNT);
        
        // Get the new exchange rate
        uint256 newRate = stQEURO.exchangeRate();
        
        // Exchange rate should increase
        assertGt(newRate, initialRate);
        
        // Check that total underlying didn't change
        assertEq(stQEURO.totalUnderlying(), STAKE_AMOUNT);
        
        // Check that total yield earned increased
        assertGt(stQEURO.totalYieldEarned(), 0);
        
        // Calculate expected QEURO amount
        uint256 expectedAmount = STAKE_AMOUNT * newRate / 1e18;
        
        // Verify the calculation is correct
        assertGt(expectedAmount, STAKE_AMOUNT);
    }
    
    /**
     * @notice Test yield claiming (should return 0 in this model)
     * @dev Verifies that yield claiming returns 0 as yield is distributed via exchange rate
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Yield_ClaimYield() public {
        // First stake some QEURO
        vm.prank(user1);
        stQEURO.stake(STAKE_AMOUNT);
        
        // Claim yield
        vm.prank(user1);
        uint256 yieldAmount = stQEURO.claimYield();
        
        // Should return 0 as yield is distributed via exchange rate
        assertEq(yieldAmount, 0);
    }
    
    /**
     * @notice Test getting pending yield (should return 0 in this model)
     * @dev Verifies that pending yield returns 0 as yield is distributed via exchange rate
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Yield_GetPendingYield() public {
        // First stake some QEURO
        vm.prank(user1);
        stQEURO.stake(STAKE_AMOUNT);
        
        // Get pending yield
        uint256 pendingYield = stQEURO.getPendingYield(user1);
        
        // Should return 0 as yield is distributed via exchange rate
        assertEq(pendingYield, 0);
    }

    // =============================================================================
    // EXCHANGE RATE TESTS
    // =============================================================================
    
    /**
     * @notice Test exchange rate calculation
     * @dev Verifies that exchange rate is calculated correctly
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_ExchangeRate_GetExchangeRate() public {
        // Initial exchange rate should be 1:1
        uint256 rate = stQEURO.getExchangeRate();
        assertEq(rate, 1e18);
        
        // Stake some QEURO
        vm.prank(user1);
        stQEURO.stake(STAKE_AMOUNT);
        
        // Exchange rate should still be 1:1
        rate = stQEURO.getExchangeRate();
        assertEq(rate, 1e18);
        
        // Distribute yield
        vm.prank(yieldManager);
        stQEURO.distributeYield(YIELD_AMOUNT);
        
        // Exchange rate should increase
        rate = stQEURO.getExchangeRate();
        assertGt(rate, 1e18);
    }
    
    /**
     * @notice Test QEURO equivalent calculation
     * @dev Verifies that QEURO equivalent is calculated correctly
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_ExchangeRate_GetQEUROEquivalent() public {
        // Stake some QEURO
        vm.prank(user1);
        stQEURO.stake(STAKE_AMOUNT);
        
        // Get QEURO equivalent
        uint256 qeuroEquivalent = stQEURO.getQEUROEquivalent(user1);
        assertEq(qeuroEquivalent, STAKE_AMOUNT);
        
        // Distribute yield
        vm.prank(yieldManager);
        stQEURO.distributeYield(YIELD_AMOUNT);
        
        // Get QEURO equivalent after yield
        qeuroEquivalent = stQEURO.getQEUROEquivalent(user1);
        assertGt(qeuroEquivalent, STAKE_AMOUNT);
    }
    
    /**
     * @notice Test QEURO equivalent for user with no balance
     * @dev Verifies that QEURO equivalent returns 0 for users with no stQEURO
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_ExchangeRate_GetQEUROEquivalentNoBalance() public view {
        uint256 qeuroEquivalent = stQEURO.getQEUROEquivalent(user1);
        assertEq(qeuroEquivalent, 0);
    }

    // =============================================================================
    // VIEW FUNCTION TESTS
    // =============================================================================
    
    /**
     * @notice Test getting TVL
     * @dev Verifies that total value locked is returned correctly
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_View_GetTVL() public {
        // Initial TVL should be 0
        uint256 tvl = stQEURO.getTVL();
        assertEq(tvl, 0);
        
        // Stake some QEURO
        vm.prank(user1);
        stQEURO.stake(STAKE_AMOUNT);
        
        // TVL should equal staked amount
        tvl = stQEURO.getTVL();
        assertEq(tvl, STAKE_AMOUNT);
    }
    
    /**
     * @notice Test getting staking statistics
     * @dev Verifies that staking statistics are returned correctly
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_View_GetStakingStats() public {
        // Get initial stats
        (
            uint256 totalStQEUROSupply,
            uint256 totalQEUROUnderlying,
            uint256 currentExchangeRate,
            uint256 totalYieldEarned_,
            uint256 apy
        ) = stQEURO.getStakingStats();
        
        assertEq(totalStQEUROSupply, 0);
        assertEq(totalQEUROUnderlying, 0);
        assertEq(currentExchangeRate, 1e18);
        assertEq(totalYieldEarned_, 0);
        assertEq(apy, 0);
        
        // Stake some QEURO
        vm.prank(user1);
        stQEURO.stake(STAKE_AMOUNT);
        
        // Get stats after staking
        (
            totalStQEUROSupply,
            totalQEUROUnderlying,
            currentExchangeRate,
            totalYieldEarned_,
            apy
        ) = stQEURO.getStakingStats();
        
        assertEq(totalStQEUROSupply, STAKE_AMOUNT);
        assertEq(totalQEUROUnderlying, STAKE_AMOUNT);
        assertEq(currentExchangeRate, 1e18);
        assertEq(totalYieldEarned_, 0);
        assertEq(apy, 0);
    }

    // =============================================================================
    // EMERGENCY TESTS
    // =============================================================================
    
    /**
     * @notice Test pausing the contract
     * @dev Verifies that emergency role can pause the contract
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Emergency_Pause() public {
        vm.prank(admin);
        stQEURO.pause();
        
        assertTrue(stQEURO.paused());
    }
    
    /**
     * @notice Test pausing by non-emergency role should revert
     * @dev Verifies that only emergency role can pause
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Emergency_PauseByNonEmergency_Revert() public {
        vm.prank(user1);
        vm.expectRevert();
        stQEURO.pause();
    }
    
    /**
     * @notice Test unpausing the contract
     * @dev Verifies that emergency role can unpause the contract
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Emergency_Unpause() public {
        // First pause
        vm.prank(admin);
        stQEURO.pause();
        
        // Then unpause
        vm.prank(admin);
        stQEURO.unpause();
        
        assertFalse(stQEURO.paused());
    }
    
    /**
     * @notice Test emergency withdrawal
     * @dev Verifies that emergency role can withdraw user's QEURO
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Emergency_EmergencyWithdraw() public {
        // First stake some QEURO
        vm.prank(user1);
        stQEURO.stake(STAKE_AMOUNT);
        
        // Emergency withdraw
        vm.prank(admin);
        stQEURO.emergencyWithdraw(user1);
        
        // User should have no stQEURO
        assertEq(stQEURO.balanceOf(user1), 0);
        
        // Total supply should be 0
        assertEq(stQEURO.totalSupply(), 0);
        
        // Total underlying should be 0
        assertEq(stQEURO.totalUnderlying(), 0);
    }
    
    /**
     * @notice Test emergency withdrawal by non-emergency role should revert
     * @dev Verifies that only emergency role can perform emergency withdrawal
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Emergency_EmergencyWithdrawByNonEmergency_Revert() public {
        // First stake some QEURO
        vm.prank(user1);
        stQEURO.stake(STAKE_AMOUNT);
        
        // Try emergency withdraw by non-emergency role
        vm.prank(user1);
        vm.expectRevert();
        stQEURO.emergencyWithdraw(user1);
    }

    // =============================================================================
    // ADMINISTRATIVE TESTS
    // =============================================================================
    
    /**
     * @notice Test updating yield parameters
     * @dev Verifies that governance role can update yield parameters
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Admin_UpdateYieldParameters() public {
        uint256 newFee = 500; // 5%
        uint256 newThreshold = 500e6; // 500 USDC
        uint256 newFrequency = 2 hours;
        
        vm.prank(governance);
        stQEURO.updateYieldParameters(newFee, newThreshold, newFrequency);
        
        assertEq(stQEURO.yieldFee(), newFee);
        assertEq(stQEURO.minYieldThreshold(), newThreshold);
        assertEq(stQEURO.maxUpdateFrequency(), newFrequency);
    }
    
    /**
     * @notice Test updating yield parameters by non-governance role should revert
     * @dev Verifies that only governance role can update yield parameters
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Admin_UpdateYieldParametersByNonGovernance_Revert() public {
        vm.prank(user1);
        vm.expectRevert();
        stQEURO.updateYieldParameters(500, 500e6, 2 hours);
    }
    
    /**
     * @notice Test updating yield parameters with invalid values should revert
     * @dev Verifies that invalid yield parameters are rejected
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Admin_UpdateYieldParametersInvalidValues_Revert() public {
        // Test yield fee too high
        vm.prank(governance);
        vm.expectRevert("stQEURO: Yield fee too high");
        stQEURO.updateYieldParameters(2500, 500e6, 2 hours); // 25% fee
        
        // Test update frequency too long
        vm.prank(governance);
        vm.expectRevert("stQEURO: Update frequency too long");
        stQEURO.updateYieldParameters(500, 500e6, 25 hours); // 25 hours
    }
    
    /**
     * @notice Test updating treasury address
     * @dev Verifies that governance role can update treasury
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Admin_UpdateTreasury() public {
        address newTreasury = address(0x999);
        
        vm.prank(governance);
        stQEURO.updateTreasury(newTreasury);
        
        assertEq(stQEURO.treasury(), newTreasury);
    }
    
    /**
     * @notice Test updating treasury to zero address should revert
     * @dev Verifies that treasury cannot be set to zero address
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Admin_UpdateTreasuryToZero_Revert() public {
        vm.prank(governance);
        vm.expectRevert("stQEURO: Treasury cannot be zero");
        stQEURO.updateTreasury(address(0));
    }
    
    /**
     * @notice Test updating treasury by non-governance role should revert
     * @dev Verifies that only governance role can update treasury
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Admin_UpdateTreasuryByNonGovernance_Revert() public {
        vm.prank(user1);
        vm.expectRevert();
        stQEURO.updateTreasury(address(0x999));
    }

    // =============================================================================
    // RECOVERY TESTS
    // =============================================================================
    
    /**
     * @notice Test recovering external tokens to treasury
     * @dev Verifies that admin can recover accidentally sent tokens to treasury
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Recovery_RecoverToken() public {
        // Deploy a mock ERC20 token
        MockERC20 mockToken = new MockERC20("Mock Token", "MTK");
        uint256 amount = 1000e18;
        
        // Mint tokens to the stQEURO contract
        mockToken.mint(address(stQEURO), amount);
        
        uint256 initialTreasuryBalance = mockToken.balanceOf(treasury); // recipient is treasury
        
        // Admin recovers tokens
        vm.prank(admin);
        stQEURO.recoverToken(address(mockToken), amount);
        
        // Verify tokens were sent to treasury (recipient)
        assertEq(mockToken.balanceOf(treasury), initialTreasuryBalance + amount);
    }
    
    /**
     * @notice Test recovering QEURO tokens to treasury
     * @dev Verifies that admin can recover QEURO tokens to treasury
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Recovery_RecoverQEURO() public {
        uint256 amount = 1000e18;
        
        // Use mockQEURO address for testing
        // Note: This test simulates recovery of QEURO tokens
        // Since mockQEURO is just an address, we can't mint to it
        // This test verifies the recovery function works without reverting
        
        vm.prank(admin);
        stQEURO.recoverToken(mockQEURO, amount);
        
        // The test passes if the function doesn't revert
        // The actual token transfer would happen in a real scenario
    }
    
    /**
     * @notice Test recovering stQEURO tokens should revert
     * @dev Verifies that stQEURO tokens cannot be recovered
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Recovery_RecoverStQEURO() public {
        uint256 amount = 1000e18;
        
        vm.prank(admin);
        vm.expectRevert(ErrorLibrary.CannotRecoverOwnToken.selector);
        stQEURO.recoverToken(address(stQEURO), amount);
    }
    
    /**
     * @notice Test recovering tokens by non-admin should revert
     * @dev Verifies that only admin can recover tokens
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Recovery_RecoverTokenByNonAdmin_Revert() public {
        MockERC20 mockToken = new MockERC20("Mock Token", "MTK");
        
        vm.prank(user1);
        vm.expectRevert();
        stQEURO.recoverToken(address(mockToken), 1000e18);
    }
    
    /**
     * @notice Test recovering ETH to treasury address
     * @dev Verifies that admin can recover accidentally sent ETH to treasury only
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Recovery_RecoverETH() public {
        // Fund the contract with some ETH
        vm.deal(address(stQEURO), 1 ether);
        
        vm.prank(admin);
        stQEURO.recoverETH(); // Must be treasury address
        
        // Should not revert (mock call will succeed)
    }
    

    
    /**
     * @notice Test recovering ETH by non-admin should revert
     * @dev Verifies that only admin can recover ETH
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Recovery_RecoverETHByNonAdmin_Revert() public {
        // Fund the contract with some ETH
        vm.deal(address(stQEURO), 1 ether);
        
        vm.prank(user1);
        vm.expectRevert();
        stQEURO.recoverETH();
    }

    // =============================================================================
    // INTEGRATION TESTS
    // =============================================================================
    
    /**
     * @notice Test complete staking and yield cycle
     * @dev Verifies that a complete staking and yield cycle works correctly
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Integration_CompleteStakingYieldCycle() public {
        // User1 stakes QEURO
        vm.prank(user1);
        stQEURO.stake(STAKE_AMOUNT);
        
        // User2 stakes QEURO
        vm.prank(user2);
        stQEURO.stake(STAKE_AMOUNT);
        
        // Check initial state
        assertEq(stQEURO.totalSupply(), 2 * STAKE_AMOUNT);
        assertEq(stQEURO.totalUnderlying(), 2 * STAKE_AMOUNT);
        assertEq(stQEURO.exchangeRate(), 1e18);
        
        // Distribute yield
        vm.prank(yieldManager);
        stQEURO.distributeYield(YIELD_AMOUNT);
        
        // Check exchange rate increased
        uint256 newRate = stQEURO.exchangeRate();
        assertGt(newRate, 1e18);
        
        // Check that total underlying didn't change
        assertEq(stQEURO.totalUnderlying(), 2 * STAKE_AMOUNT);
        
        // Check that total yield earned increased
        assertGt(stQEURO.totalYieldEarned(), 0);
    }
    
    /**
     * @notice Test multiple yield distributions
     * @dev Verifies that multiple yield distributions work correctly
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Integration_MultipleYieldDistributions() public {
        // User stakes QEURO
        vm.prank(user1);
        stQEURO.stake(STAKE_AMOUNT);
        
        // First yield distribution
        vm.prank(yieldManager);
        stQEURO.distributeYield(YIELD_AMOUNT);
        
        uint256 rate1 = stQEURO.exchangeRate();
        assertGt(rate1, 1e18);
        
        // Second yield distribution
        vm.prank(yieldManager);
        stQEURO.distributeYield(YIELD_AMOUNT);
        
        uint256 rate2 = stQEURO.exchangeRate();
        assertGt(rate2, rate1);
        
        // Check that total underlying didn't change
        assertEq(stQEURO.totalUnderlying(), STAKE_AMOUNT);
        
        // Check that total yield earned increased
        assertGt(stQEURO.totalYieldEarned(), 0);
    }
    
    /**
     * @notice Test partial staking and unstaking with yield
     * @dev Verifies that partial operations work correctly with yield
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_Integration_PartialStakingUnstakingWithYield() public {
        // User stakes QEURO
        vm.prank(user1);
        stQEURO.stake(STAKE_AMOUNT);
        
        // Distribute yield
        vm.prank(yieldManager);
        stQEURO.distributeYield(YIELD_AMOUNT);
        
        // Check exchange rate increased
        uint256 rate1 = stQEURO.exchangeRate();
        assertGt(rate1, 1e18);
        
        // Check that total underlying didn't change
        assertEq(stQEURO.totalUnderlying(), STAKE_AMOUNT);
        
        // Distribute more yield
        vm.prank(yieldManager);
        stQEURO.distributeYield(YIELD_AMOUNT);
        
        // Check exchange rate increased again
        uint256 rate2 = stQEURO.exchangeRate();
        assertGt(rate2, rate1);
        
        // Check that total underlying still didn't change
        assertEq(stQEURO.totalUnderlying(), STAKE_AMOUNT);
        
        // Check that total yield earned increased
        assertGt(stQEURO.totalYieldEarned(), 0);
    }
}

// =============================================================================
// MOCK CONTRACTS FOR TESTING
// =============================================================================

/**
 * @title MockYieldShift
 * @notice Mock contract for testing yield shift functionality
 */
contract MockYieldShift {
    uint256 public mockPendingYield = 0;
    
    /**
     * @notice Gets the pending yield for a user
     * @dev Mock function for testing purposes
     * @return The pending yield amount
     * @custom:security No security validations - test mock
     * @custom:validation No input validation - test mock
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependencies
     */
    function getUserPendingYield(address /* user */) external view returns (uint256) {
        return mockPendingYield;
    }
    
    /**
     * @notice Sets the mock pending yield amount
     * @dev Mock function for testing purposes
     * @param amount The amount to set as pending yield
     * @custom:security No security validations - test mock
     * @custom:validation No input validation - test mock
     * @custom:state-changes Updates mockPendingYield state variable
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependencies
     */
    function setMockPendingYield(uint256 amount) external {
        mockPendingYield = amount;
    }
}

/**
 * @title MockERC20
 * @notice Mock ERC20 token for testing
 */
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @notice Constructor for MockERC20 token
     * @dev Mock function for testing purposes
     * @param _name The name of the token
     * @param _symbol The symbol of the token
     * @custom:security No security validations - test mock
     * @custom:validation No input validation - test mock
     * @custom:state-changes Initializes token name, symbol, and decimals
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependencies
     */
    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        decimals = 18;
    }

    /**
     * @notice Mints tokens to an address
     * @dev Mock function for testing purposes
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     * @custom:security No security validations - test mock
     * @custom:validation No input validation - test mock
     * @custom:state-changes Updates balanceOf and totalSupply
     * @custom:events Emits Transfer event
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependencies
     */
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    /**
     * @notice Transfers tokens to another address
     * @dev Mock function for testing purposes
     * @param to The address to transfer tokens to
     * @param amount The amount of tokens to transfer
     * @return True if transfer is successful
     * @custom:security No security validations - test mock
     * @custom:validation No input validation - test mock
     * @custom:state-changes Updates balanceOf mapping
     * @custom:events Emits Transfer event
     * @custom:errors Throws "Insufficient balance" if balance is too low
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependencies
     */
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /**
     * @notice Approves a spender to transfer tokens
     * @dev Mock function for testing purposes
     * @param spender The address to approve for spending
     * @param amount The amount of tokens to approve
     * @return True if approval is successful
     * @custom:security No security validations - test mock
     * @custom:validation No input validation - test mock
     * @custom:state-changes Updates allowance mapping
     * @custom:events Emits Approval event
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependencies
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /**
     * @notice Transfers tokens from one address to another
     * @dev Mock function for testing purposes
     * @param from The address to transfer tokens from
     * @param to The address to transfer tokens to
     * @param amount The amount of tokens to transfer
     * @return True if transfer is successful
     * @custom:security No security validations - test mock
     * @custom:validation No input validation - test mock
     * @custom:state-changes Updates balanceOf and allowance mappings
     * @custom:events Emits Transfer event
     * @custom:errors Throws "Insufficient balance" or "Insufficient allowance" if conditions not met
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependencies
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }
}
