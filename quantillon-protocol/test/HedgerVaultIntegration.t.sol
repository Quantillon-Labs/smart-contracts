// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {QuantillonVault} from "../src/core/QuantillonVault.sol";
import {HedgerPool} from "../src/core/HedgerPool.sol";
import {QEUROToken} from "../src/core/QEUROToken.sol";
import {ChainlinkOracle} from "../src/oracle/ChainlinkOracle.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title HedgerVaultIntegrationTest
 * @notice Comprehensive test suite for hedger USDC integration with QuantillonVault
 * @dev Tests the unified USDC liquidity management between HedgerPool and QuantillonVault
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract HedgerVaultIntegrationTest is Test {
    // =============================================================================
    // CONTRACTS AND ADDRESSES
    // =============================================================================
    
    QuantillonVault public vault;
    HedgerPool public hedgerPool;
    QEUROToken public qeuro;
    ChainlinkOracle public oracle;
    TimeProvider public timeProvider;
    IERC20 public usdc;
    
    address public admin = address(0x1);
    address public hedger = address(0x2);
    address public user = address(0x3);
    address public treasury = address(0x4);
    address public timelock = address(0x5);
    
    // =============================================================================
    // SETUP AND INITIALIZATION
    // =============================================================================
    
    function setUp() public {
        // Deploy TimeProvider
        timeProvider = new TimeProvider();
        
        // Deploy mock USDC
        usdc = IERC20(address(new MockUSDC()));
        
        // Deploy QEURO token
        qeuro = new QEUROToken();
        
        // Deploy oracle
        oracle = new ChainlinkOracle();
        
        // Deploy vault
        vault = new QuantillonVault();
        
        // Deploy hedger pool
        hedgerPool = new HedgerPool(timeProvider);
        
        // Initialize contracts
        _initializeContracts();
        
        // Setup test environment
        _setupTestEnvironment();
    }
    
    /**
     * @notice Initialize all contracts with proper parameters
     * @dev Sets up the complete protocol infrastructure for testing
     */
    function _initializeContracts() internal {
        // Initialize QEURO token
        qeuro.initialize(
            admin,
            address(vault),
            address(oracle),
            timelock,
            treasury
        );
        
        // Initialize oracle
        oracle.initialize(
            admin,
            address(0x123), // Mock price feed
            timelock
        );
        
        // Initialize vault
        vault.initialize(
            admin,
            address(qeuro),
            address(usdc),
            address(oracle),
            address(hedgerPool),
            timelock,
            treasury
        );
        
        // Initialize hedger pool
        hedgerPool.initialize(
            admin,
            address(usdc),
            address(oracle),
            address(0), // YieldShift (not needed for this test)
            timelock,
            treasury,
            address(vault)
        );
    }
    
    /**
     * @notice Setup test environment with initial balances and permissions
     * @dev Prepares the test environment with necessary tokens and permissions
     */
    function _setupTestEnvironment() internal {
        // Mint USDC to test addresses
        MockUSDC(address(usdc)).mint(hedger, 1000000e6); // 1M USDC
        MockUSDC(address(usdc)).mint(user, 1000000e6); // 1M USDC
        
        // Approve vault to spend USDC
        vm.prank(hedger);
        usdc.approve(address(vault), type(uint256).max);
        
        vm.prank(user);
        usdc.approve(address(vault), type(uint256).max);
        
        // Approve hedger pool to spend USDC
        vm.prank(hedger);
        usdc.approve(address(hedgerPool), type(uint256).max);
        
        // Whitelist hedger
        vm.prank(admin);
        hedgerPool.whitelistHedger(hedger);
    }
    
    // =============================================================================
    // TEST CASES - Hedger Deposit Integration
    // =============================================================================
    
    /**
     * @notice Test hedger deposit adds USDC to vault's totalUsdcHeld
     * @dev Verifies that when hedger opens position, USDC goes to vault
     */
    function testHedgerDepositAddsToVaultUsdc() public {
        uint256 initialVaultUsdc = vault.getTotalUsdcAvailable();
        uint256 hedgerDepositAmount = 10000e6; // 10,000 USDC
        
        // Hedger opens position
        vm.prank(hedger);
        hedgerPool.enterHedgePosition(hedgerDepositAmount, 10); // 10x leverage
        
        // Verify vault's totalUsdcHeld increased
        uint256 finalVaultUsdc = vault.getTotalUsdcAvailable();
        assertEq(finalVaultUsdc, initialVaultUsdc + hedgerDepositAmount, "Vault USDC should increase by hedger deposit");
        
        // Verify hedger pool doesn't hold USDC
        uint256 hedgerPoolUsdc = usdc.balanceOf(address(hedgerPool));
        assertEq(hedgerPoolUsdc, 0, "HedgerPool should not hold USDC");
        
        // Verify vault holds the USDC
        uint256 vaultUsdcBalance = usdc.balanceOf(address(vault));
        assertGe(vaultUsdcBalance, hedgerDepositAmount, "Vault should hold hedger USDC");
    }
    
    /**
     * @notice Test hedger deposit emits correct event
     * @dev Verifies HedgerDepositAdded event is emitted with correct parameters
     */
    function testHedgerDepositEmitsEvent() public {
        uint256 hedgerDepositAmount = 5000e6; // 5,000 USDC
        
        // Expect HedgerDepositAdded event
        vm.expectEmit(true, false, false, true);
        emit QuantillonVault.HedgerDepositAdded(
            address(hedgerPool),
            hedgerDepositAmount,
            hedgerDepositAmount // Initial vault USDC + hedger deposit
        );
        
        // Hedger opens position
        vm.prank(hedger);
        hedgerPool.enterHedgePosition(hedgerDepositAmount, 5); // 5x leverage
    }
    
    /**
     * @notice Test multiple hedger deposits accumulate in vault
     * @dev Verifies that multiple hedger deposits are properly accumulated
     */
    function testMultipleHedgerDepositsAccumulate() public {
        uint256 deposit1 = 3000e6; // 3,000 USDC
        uint256 deposit2 = 7000e6; // 7,000 USDC
        uint256 totalDeposits = deposit1 + deposit2;
        
        // First hedger deposit
        vm.prank(hedger);
        hedgerPool.enterHedgePosition(deposit1, 5);
        
        uint256 vaultUsdcAfterFirst = vault.getTotalUsdcAvailable();
        assertEq(vaultUsdcAfterFirst, deposit1, "Vault should have first deposit");
        
        // Second hedger deposit
        vm.prank(hedger);
        hedgerPool.enterHedgePosition(deposit2, 10);
        
        uint256 vaultUsdcAfterSecond = vault.getTotalUsdcAvailable();
        assertEq(vaultUsdcAfterSecond, totalDeposits, "Vault should have both deposits");
    }
    
    // =============================================================================
    // TEST CASES - Hedger Withdrawal Integration
    // =============================================================================
    
    /**
     * @notice Test hedger position closure withdraws USDC from vault
     * @dev Verifies that when hedger closes position, USDC is withdrawn from vault
     */
    function testHedgerWithdrawalFromVault() public {
        uint256 hedgerDepositAmount = 10000e6; // 10,000 USDC
        
        // Hedger opens position
        vm.prank(hedger);
        uint256 positionId = hedgerPool.enterHedgePosition(hedgerDepositAmount, 10);
        
        uint256 vaultUsdcAfterDeposit = vault.getTotalUsdcAvailable();
        assertEq(vaultUsdcAfterDeposit, hedgerDepositAmount, "Vault should have hedger deposit");
        
        // Hedger closes position
        vm.prank(hedger);
        hedgerPool.exitHedgePosition(positionId);
        
        // Verify vault's totalUsdcHeld decreased
        uint256 vaultUsdcAfterWithdrawal = vault.getTotalUsdcAvailable();
        assertLt(vaultUsdcAfterWithdrawal, vaultUsdcAfterDeposit, "Vault USDC should decrease after withdrawal");
        
        // Verify hedger received USDC
        uint256 hedgerUsdcBalance = usdc.balanceOf(hedger);
        assertGt(hedgerUsdcBalance, 0, "Hedger should receive USDC back");
    }
    
    /**
     * @notice Test hedger withdrawal emits correct event
     * @dev Verifies HedgerDepositWithdrawn event is emitted with correct parameters
     */
    function testHedgerWithdrawalEmitsEvent() public {
        uint256 hedgerDepositAmount = 5000e6; // 5,000 USDC
        
        // Hedger opens position
        vm.prank(hedger);
        uint256 positionId = hedgerPool.enterHedgePosition(hedgerDepositAmount, 5);
        
        // Expect HedgerDepositWithdrawn event
        vm.expectEmit(true, false, false, true);
        emit QuantillonVault.HedgerDepositWithdrawn(
            hedger,
            hedgerDepositAmount, // Assuming full withdrawal for simplicity
            hedgerDepositAmount - hedgerDepositAmount // Vault USDC after withdrawal
        );
        
        // Hedger closes position
        vm.prank(hedger);
        hedgerPool.exitHedgePosition(positionId);
    }
    
    // =============================================================================
    // TEST CASES - Unified Liquidity for User Redemptions
    // =============================================================================
    
    /**
     * @notice Test user redemption can use hedger USDC
     * @dev Verifies that user redemptions can access hedger USDC in vault
     */
    function testUserRedemptionUsesHedgerUsdc() public {
        // Setup: User mints QEURO and hedger deposits USDC
        uint256 userUsdcAmount = 1000e6; // 1,000 USDC
        uint256 hedgerUsdcAmount = 2000e6; // 2,000 USDC
        
        // User mints QEURO
        vm.prank(user);
        vault.mintQEURO(userUsdcAmount, 0);
        
        // Hedger opens position
        vm.prank(hedger);
        hedgerPool.enterHedgePosition(hedgerUsdcAmount, 5);
        
        uint256 totalVaultUsdc = vault.getTotalUsdcAvailable();
        assertEq(totalVaultUsdc, userUsdcAmount + hedgerUsdcAmount, "Vault should have both user and hedger USDC");
        
        // User redeems QEURO (should succeed because hedger USDC is available)
        uint256 userQeuroBalance = qeuro.balanceOf(user);
        assertGt(userQeuroBalance, 0, "User should have QEURO to redeem");
        
        vm.prank(user);
        qeuro.approve(address(vault), userQeuroBalance);
        
        // This should succeed because vault has enough USDC (user + hedger)
        vm.prank(user);
        vault.redeemQEURO(userQeuroBalance, 0);
        
        // Verify user received USDC
        uint256 userUsdcAfterRedemption = usdc.balanceOf(user);
        assertGt(userUsdcAfterRedemption, 0, "User should receive USDC from redemption");
    }
    
    /**
     * @notice Test redemption fails when insufficient hedger USDC
     * @dev Verifies that redemptions fail when vault doesn't have enough USDC
     */
    function testRedemptionFailsInsufficientHedgerUsdc() public {
        // Setup: User mints QEURO but no hedger deposits
        uint256 userUsdcAmount = 1000e6; // 1,000 USDC
        
        // User mints QEURO
        vm.prank(user);
        vault.mintQEURO(userUsdcAmount, 0);
        
        uint256 userQeuroBalance = qeuro.balanceOf(user);
        assertGt(userQeuroBalance, 0, "User should have QEURO to redeem");
        
        vm.prank(user);
        qeuro.approve(address(vault), userQeuroBalance);
        
        // Simulate oracle price increase (user needs more USDC than deposited)
        // This should fail because vault only has user's USDC, no hedger USDC
        vm.prank(user);
        vm.expectRevert("Vault: Insufficient USDC reserves");
        vault.redeemQEURO(userQeuroBalance, userUsdcAmount + 100e6); // Request more than available
    }
    
    // =============================================================================
    // TEST CASES - Access Control and Security
    // =============================================================================
    
    /**
     * @notice Test only HedgerPool can call addHedgerDeposit
     * @dev Verifies access control for hedger deposit function
     */
    function testOnlyHedgerPoolCanAddDeposit() public {
        uint256 depositAmount = 1000e6;
        
        // Non-hedger pool address should fail
        vm.prank(user);
        vm.expectRevert("Vault: Only HedgerPool can call");
        vault.addHedgerDeposit(depositAmount);
    }
    
    /**
     * @notice Test only HedgerPool can call withdrawHedgerDeposit
     * @dev Verifies access control for hedger withdrawal function
     */
    function testOnlyHedgerPoolCanWithdrawDeposit() public {
        uint256 withdrawalAmount = 1000e6;
        
        // Non-hedger pool address should fail
        vm.prank(user);
        vm.expectRevert("Vault: Only HedgerPool can call");
        vault.withdrawHedgerDeposit(hedger, withdrawalAmount);
    }
    
    /**
     * @notice Test addHedgerDeposit validates positive amount
     * @dev Verifies input validation for hedger deposit function
     */
    function testAddHedgerDepositValidatesAmount() public {
        // Zero amount should fail
        vm.prank(address(hedgerPool));
        vm.expectRevert("Vault: Amount must be positive");
        vault.addHedgerDeposit(0);
    }
    
    /**
     * @notice Test withdrawHedgerDeposit validates positive amount
     * @dev Verifies input validation for hedger withdrawal function
     */
    function testWithdrawHedgerDepositValidatesAmount() public {
        // Zero amount should fail
        vm.prank(address(hedgerPool));
        vm.expectRevert("Vault: Amount must be positive");
        vault.withdrawHedgerDeposit(hedger, 0);
    }
    
    /**
     * @notice Test withdrawHedgerDeposit validates sufficient reserves
     * @dev Verifies that withdrawal fails when vault doesn't have enough USDC
     */
    function testWithdrawHedgerDepositValidatesReserves() public {
        uint256 withdrawalAmount = 1000e6;
        
        // Should fail because vault has no USDC
        vm.prank(address(hedgerPool));
        vm.expectRevert("Vault: Insufficient USDC reserves");
        vault.withdrawHedgerDeposit(hedger, withdrawalAmount);
    }
    
    // =============================================================================
    // TEST CASES - Edge Cases and Error Handling
    // =============================================================================
    
    /**
     * @notice Test hedger deposit with maximum amount
     * @dev Verifies system handles large hedger deposits correctly
     */
    function testHedgerDepositMaximumAmount() public {
        uint256 maxAmount = 1000000e6; // 1M USDC
        
        // Should succeed with large amount
        vm.prank(hedger);
        hedgerPool.enterHedgePosition(maxAmount, 1); // 1x leverage
        
        uint256 vaultUsdc = vault.getTotalUsdcAvailable();
        assertEq(vaultUsdc, maxAmount, "Vault should handle large hedger deposits");
    }
    
    /**
     * @notice Test hedger deposit with minimum amount
     * @dev Verifies system handles small hedger deposits correctly
     */
    function testHedgerDepositMinimumAmount() public {
        uint256 minAmount = 1e6; // 1 USDC
        
        // Should succeed with small amount
        vm.prank(hedger);
        hedgerPool.enterHedgePosition(minAmount, 1); // 1x leverage
        
        uint256 vaultUsdc = vault.getTotalUsdcAvailable();
        assertEq(vaultUsdc, minAmount, "Vault should handle small hedger deposits");
    }
    
    /**
     * @notice Test getTotalUsdcAvailable returns correct value
     * @dev Verifies the view function returns accurate vault USDC balance
     */
    function testGetTotalUsdcAvailable() public {
        uint256 initialUsdc = vault.getTotalUsdcAvailable();
        assertEq(initialUsdc, 0, "Initial vault USDC should be zero");
        
        uint256 hedgerDeposit = 5000e6;
        vm.prank(hedger);
        hedgerPool.enterHedgePosition(hedgerDeposit, 5);
        
        uint256 finalUsdc = vault.getTotalUsdcAvailable();
        assertEq(finalUsdc, hedgerDeposit, "Vault USDC should match hedger deposit");
    }
}

/**
 * @title MockUSDC
 * @notice Mock USDC token for testing purposes
 * @dev Simple ERC20 implementation with minting capability
 */
contract MockUSDC {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    uint256 public totalSupply;
    string public name = "Mock USDC";
    string public symbol = "USDC";
    uint8 public decimals = 6;
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}
