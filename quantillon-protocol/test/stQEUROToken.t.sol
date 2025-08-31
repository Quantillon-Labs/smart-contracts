// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {stQEUROToken} from "../src/core/stQEUROToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IYieldShift} from "../src/interfaces/IYieldShift.sol";

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
 * @author Quantillon Labs
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
     */
    function setUp() public {
        // Deploy implementation
        implementation = new stQEUROToken();
        
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
     * @dev Verifies that the contract is properly initialized with correct roles and settings
     */
    function test_Initialization_Success() public {
        // Check token details
        assertEq(stQEURO.name(), "Staked Quantillon Euro");
        assertEq(stQEURO.symbol(), "stQEURO");
        assertEq(stQEURO.decimals(), 18);
        assertEq(stQEURO.totalSupply(), 0);
        
        // Check roles are properly assigned
        assertTrue(stQEURO.hasRole(0x00, admin)); // DEFAULT_ADMIN_ROLE is 0x00
        assertTrue(stQEURO.hasRole(keccak256("GOVERNANCE_ROLE"), admin));
        assertTrue(stQEURO.hasRole(keccak256("YIELD_MANAGER_ROLE"), admin));
        assertTrue(stQEURO.hasRole(keccak256("EMERGENCY_ROLE"), admin));

        
        // Check external contracts
        assertEq(address(stQEURO.qeuro()), mockQEURO);
        assertEq(address(stQEURO.yieldShift()), mockYieldShift);
        assertEq(address(stQEURO.usdc()), mockUSDC);
        assertEq(stQEURO.treasury(), treasury);
        
        // Check initial state variables
        assertEq(stQEURO.exchangeRate(), 1e18); // 1:1 initial rate
        assertEq(stQEURO.totalUnderlying(), 0);
        assertEq(stQEURO.totalYieldEarned(), 0);
        assertEq(stQEURO.yieldFee(), 1000); // 10% fee
        assertEq(stQEURO.minYieldThreshold(), 1000e6); // 1000 USDC
        assertEq(stQEURO.maxUpdateFrequency(), 1 hours);
    }
    
    /**
     * @notice Test initialization with zero addresses should revert
     * @dev Verifies that initialization fails with invalid parameters
     */
    function test_Initialization_ZeroAddresses_Revert() public {
        // Create implementation once to reuse
        stQEUROToken implementation = new stQEUROToken();
        
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
        new ERC1967Proxy(address(implementation), initData1);
        
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
        new ERC1967Proxy(address(implementation), initData2);
        
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
        new ERC1967Proxy(address(implementation), initData3);
        
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
        new ERC1967Proxy(address(implementation), initData4);
        
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
        new ERC1967Proxy(address(implementation), initData5);
    }
    
    /**
     * @notice Test that initialization can only be called once
     * @dev Verifies the initializer modifier works correctly
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
     */
    function test_Staking_StakeZeroAmount_Revert() public {
        vm.prank(user1);
        vm.expectRevert("stQEURO: Amount must be positive");
        stQEURO.stake(0);
    }
    
    /**
     * @notice Test staking with insufficient QEURO balance should revert
     * @dev Verifies that users cannot stake more QEURO than they have
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
    
    /**
     * @notice Test unstaking with zero amount should revert
     * @dev Verifies that unstaking zero stQEURO is prevented
     */
    function test_Unstaking_UnstakeZeroAmount_Revert() public {
        vm.prank(user1);
        vm.expectRevert("stQEURO: Amount must be positive");
        stQEURO.unstake(0);
    }
    
    /**
     * @notice Test unstaking with insufficient stQEURO balance should revert
     * @dev Verifies that users cannot unstake more stQEURO than they have
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
     */
    function test_Yield_DistributeZeroYield_Revert() public {
        vm.prank(yieldManager);
        vm.expectRevert("stQEURO: Yield amount must be positive");
        stQEURO.distributeYield(0);
    }
    
    /**
     * @notice Test yield distribution with no stQEURO supply should revert
     * @dev Verifies that yield cannot be distributed when no one has staked
     */
    function test_Yield_DistributeYieldNoSupply_Revert() public {
        vm.prank(yieldManager);
        vm.expectRevert("stQEURO: No stQEURO supply");
        stQEURO.distributeYield(YIELD_AMOUNT);
    }
    
    /**
     * @notice Test yield distribution by non-yield manager should revert
     * @dev Verifies that only yield manager can distribute yield
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
     */
    function test_ExchangeRate_GetQEUROEquivalentNoBalance() public {
        uint256 qeuroEquivalent = stQEURO.getQEUROEquivalent(user1);
        assertEq(qeuroEquivalent, 0);
    }

    // =============================================================================
    // VIEW FUNCTION TESTS
    // =============================================================================
    
    /**
     * @notice Test getting TVL
     * @dev Verifies that total value locked is returned correctly
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
     */
    function test_Emergency_Pause() public {
        vm.prank(admin);
        stQEURO.pause();
        
        assertTrue(stQEURO.paused());
    }
    
    /**
     * @notice Test pausing by non-emergency role should revert
     * @dev Verifies that only emergency role can pause
     */
    function test_Emergency_PauseByNonEmergency_Revert() public {
        vm.prank(user1);
        vm.expectRevert();
        stQEURO.pause();
    }
    
    /**
     * @notice Test unpausing the contract
     * @dev Verifies that emergency role can unpause the contract
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
     */
    function test_Admin_UpdateYieldParametersByNonGovernance_Revert() public {
        vm.prank(user1);
        vm.expectRevert();
        stQEURO.updateYieldParameters(500, 500e6, 2 hours);
    }
    
    /**
     * @notice Test updating yield parameters with invalid values should revert
     * @dev Verifies that invalid yield parameters are rejected
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
     */
    function test_Admin_UpdateTreasuryToZero_Revert() public {
        vm.prank(governance);
        vm.expectRevert("stQEURO: Treasury cannot be zero");
        stQEURO.updateTreasury(address(0));
    }
    
    /**
     * @notice Test updating treasury by non-governance role should revert
     * @dev Verifies that only governance role can update treasury
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
     * @notice Test recovering tokens
     * @dev Verifies that admin can recover accidentally sent tokens
     */
    function test_Recovery_RecoverToken() public {
        address mockToken = address(0x123);
        address recipient = address(0x456);
        uint256 amount = 1000e18;
        
        // Setup mock for token transfer
        vm.mockCall(
            mockToken,
            abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount),
            abi.encode(true)
        );
        
        vm.prank(admin);
        stQEURO.recoverToken(mockToken, recipient, amount);
        
        // Should not revert (mock call will succeed)
    }
    
    /**
     * @notice Test recovering QEURO should revert
     * @dev Verifies that QEURO cannot be recovered
     */
    function test_Recovery_RecoverQEURO_Revert() public {
        address recipient = address(0x456);
        uint256 amount = 1000e18;
        
        vm.prank(admin);
        vm.expectRevert("stQEURO: Cannot recover QEURO");
        stQEURO.recoverToken(mockQEURO, recipient, amount);
    }
    
    /**
     * @notice Test recovering stQEURO should revert
     * @dev Verifies that stQEURO cannot be recovered
     */
    function test_Recovery_RecoverStQEURO_Revert() public {
        address recipient = address(0x456);
        uint256 amount = 1000e18;
        
        vm.prank(admin);
        vm.expectRevert("stQEURO: Cannot recover stQEURO");
        stQEURO.recoverToken(address(stQEURO), recipient, amount);
    }
    
    /**
     * @notice Test recovering token to zero address should revert
     * @dev Verifies that tokens cannot be recovered to zero address
     */
    function test_Recovery_RecoverTokenToZero_Revert() public {
        address mockToken = address(0x123);
        uint256 amount = 1000e18;
        
        vm.prank(admin);
        vm.expectRevert("stQEURO: Cannot send to zero address");
        stQEURO.recoverToken(mockToken, address(0), amount);
    }
    
    /**
     * @notice Test recovering token by non-admin should revert
     * @dev Verifies that only admin can recover tokens
     */
    function test_Recovery_RecoverTokenByNonAdmin_Revert() public {
        address mockToken = address(0x123);
        address recipient = address(0x456);
        uint256 amount = 1000e18;
        
        vm.prank(user1);
        vm.expectRevert();
        stQEURO.recoverToken(mockToken, recipient, amount);
    }
    
    /**
     * @notice Test recovering ETH
     * @dev Verifies that admin can recover accidentally sent ETH
     */
    function test_Recovery_RecoverETH() public {
        address payable recipient = payable(address(0x456));
        
        // Fund the contract with some ETH
        vm.deal(address(stQEURO), 1 ether);
        
        vm.prank(admin);
        stQEURO.recoverETH(recipient);
        
        // Should not revert (mock call will succeed)
    }
    
    /**
     * @notice Test recovering ETH to zero address should revert
     * @dev Verifies that ETH cannot be recovered to zero address
     */
    function test_Recovery_RecoverETHToZero_Revert() public {
        // Fund the contract with some ETH
        vm.deal(address(stQEURO), 1 ether);
        
        vm.prank(admin);
        vm.expectRevert("stQEURO: Cannot send to zero address");
        stQEURO.recoverETH(payable(address(0)));
    }
    
    /**
     * @notice Test recovering ETH by non-admin should revert
     * @dev Verifies that only admin can recover ETH
     */
    function test_Recovery_RecoverETHByNonAdmin_Revert() public {
        // Fund the contract with some ETH
        vm.deal(address(stQEURO), 1 ether);
        
        vm.prank(user1);
        vm.expectRevert();
        stQEURO.recoverETH(payable(address(0x456)));
    }

    // =============================================================================
    // INTEGRATION TESTS
    // =============================================================================
    
    /**
     * @notice Test complete staking and yield cycle
     * @dev Verifies that a complete staking and yield cycle works correctly
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
    
    function getUserPendingYield(address user) external view returns (uint256) {
        return mockPendingYield;
    }
    
    function setMockPendingYield(uint256 amount) external {
        mockPendingYield = amount;
    }
}
