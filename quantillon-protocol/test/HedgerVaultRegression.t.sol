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
 * @title HedgerVaultRegressionTest
 * @notice Regression tests to ensure existing functionality remains intact after hedger-vault integration
 * @dev Tests that all existing features work correctly with the new unified USDC liquidity system
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract HedgerVaultRegressionTest is Test {
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
    // REGRESSION TESTS - User Minting and Redemption
    // =============================================================================
    
    /**
     * @notice Test user minting still works correctly
     * @dev Verifies that user QEURO minting functionality remains intact
     */
    function testUserMintingStillWorks() public {
        uint256 usdcAmount = 1000e6; // 1,000 USDC
        uint256 initialUserUsdc = usdc.balanceOf(user);
        uint256 initialVaultUsdc = vault.getTotalUsdcAvailable();
        
        // User mints QEURO
        vm.prank(user);
        vault.mintQEURO(usdcAmount, 0);
        
        // Verify user received QEURO
        uint256 userQeuroBalance = qeuro.balanceOf(user);
        assertGt(userQeuroBalance, 0, "User should receive QEURO");
        
        // Verify user USDC decreased
        uint256 finalUserUsdc = usdc.balanceOf(user);
        assertLt(finalUserUsdc, initialUserUsdc, "User USDC should decrease");
        
        // Verify vault USDC increased
        uint256 finalVaultUsdc = vault.getTotalUsdcAvailable();
        assertGt(finalVaultUsdc, initialVaultUsdc, "Vault USDC should increase");
    }
    
    /**
     * @notice Test user redemption still works correctly
     * @dev Verifies that user QEURO redemption functionality remains intact
     */
    function testUserRedemptionStillWorks() public {
        uint256 usdcAmount = 1000e6; // 1,000 USDC
        
        // User mints QEURO first
        vm.prank(user);
        vault.mintQEURO(usdcAmount, 0);
        
        uint256 userQeuroBalance = qeuro.balanceOf(user);
        assertGt(userQeuroBalance, 0, "User should have QEURO to redeem");
        
        // User redeems QEURO
        vm.prank(user);
        qeuro.approve(address(vault), userQeuroBalance);
        
        uint256 initialUserUsdc = usdc.balanceOf(user);
        uint256 initialVaultUsdc = vault.getTotalUsdcAvailable();
        
        vm.prank(user);
        vault.redeemQEURO(userQeuroBalance, 0);
        
        // Verify user USDC increased
        uint256 finalUserUsdc = usdc.balanceOf(user);
        assertGt(finalUserUsdc, initialUserUsdc, "User USDC should increase after redemption");
        
        // Verify vault USDC decreased
        uint256 finalVaultUsdc = vault.getTotalUsdcAvailable();
        assertLt(finalVaultUsdc, initialVaultUsdc, "Vault USDC should decrease after redemption");
        
        // Verify user QEURO decreased
        uint256 finalUserQeuro = qeuro.balanceOf(user);
        assertLt(finalUserQeuro, userQeuroBalance, "User QEURO should decrease after redemption");
    }
    
    // =============================================================================
    // REGRESSION TESTS - Hedger Pool Functionality
    // =============================================================================
    
    /**
     * @notice Test hedger position opening still works correctly
     * @dev Verifies that hedger position opening functionality remains intact
     */
    function testHedgerPositionOpeningStillWorks() public {
        uint256 usdcAmount = 5000e6; // 5,000 USDC
        uint256 leverage = 10; // 10x leverage
        
        uint256 initialHedgerUsdc = usdc.balanceOf(hedger);
        uint256 initialVaultUsdc = vault.getTotalUsdcAvailable();
        
        // Hedger opens position
        vm.prank(hedger);
        uint256 positionId = hedgerPool.enterHedgePosition(usdcAmount, leverage);
        
        // Verify position was created
        assertGt(positionId, 0, "Position ID should be valid");
        
        // Verify hedger USDC decreased
        uint256 finalHedgerUsdc = usdc.balanceOf(hedger);
        assertLt(finalHedgerUsdc, initialHedgerUsdc, "Hedger USDC should decrease");
        
        // Verify vault USDC increased
        uint256 finalVaultUsdc = vault.getTotalUsdcAvailable();
        assertGt(finalVaultUsdc, initialVaultUsdc, "Vault USDC should increase");
        
        // Verify position data is correct
        (uint256 positionSize, uint256 margin, uint256 entryPrice, uint256 currentPrice, uint256 positionLeverage, uint256 lastUpdateTime) = 
            hedgerPool.getHedgerPosition(hedger, positionId);
        
        assertEq(positionLeverage, leverage, "Position leverage should match");
        assertGt(margin, 0, "Position margin should be positive");
        assertGt(positionSize, 0, "Position size should be positive");
    }
    
    /**
     * @notice Test hedger position closing still works correctly
     * @dev Verifies that hedger position closing functionality remains intact
     */
    function testHedgerPositionClosingStillWorks() public {
        uint256 usdcAmount = 5000e6; // 5,000 USDC
        uint256 leverage = 5; // 5x leverage
        
        // Hedger opens position
        vm.prank(hedger);
        uint256 positionId = hedgerPool.enterHedgePosition(usdcAmount, leverage);
        
        uint256 initialHedgerUsdc = usdc.balanceOf(hedger);
        uint256 initialVaultUsdc = vault.getTotalUsdcAvailable();
        
        // Hedger closes position
        vm.prank(hedger);
        hedgerPool.exitHedgePosition(positionId);
        
        // Verify hedger USDC increased
        uint256 finalHedgerUsdc = usdc.balanceOf(hedger);
        assertGt(finalHedgerUsdc, initialHedgerUsdc, "Hedger USDC should increase after closing");
        
        // Verify vault USDC decreased
        uint256 finalVaultUsdc = vault.getTotalUsdcAvailable();
        assertLt(finalVaultUsdc, initialVaultUsdc, "Vault USDC should decrease after closing");
    }
    
    /**
     * @notice Test hedger margin addition still works correctly
     * @dev Verifies that hedger margin addition functionality remains intact
     */
    function testHedgerMarginAdditionStillWorks() public {
        uint256 initialUsdcAmount = 3000e6; // 3,000 USDC
        uint256 additionalMargin = 1000e6; // 1,000 USDC
        uint256 leverage = 5; // 5x leverage
        
        // Hedger opens position
        vm.prank(hedger);
        uint256 positionId = hedgerPool.enterHedgePosition(initialUsdcAmount, leverage);
        
        uint256 initialVaultUsdc = vault.getTotalUsdcAvailable();
        
        // Hedger adds margin
        vm.prank(hedger);
        hedgerPool.addMargin(positionId, additionalMargin);
        
        // Verify vault USDC increased
        uint256 finalVaultUsdc = vault.getTotalUsdcAvailable();
        assertGt(finalVaultUsdc, initialVaultUsdc, "Vault USDC should increase after margin addition");
        
        // Verify position margin increased
        (uint256 positionSize, uint256 margin, uint256 entryPrice, uint256 currentPrice, uint256 positionLeverage, uint256 lastUpdateTime) = 
            hedgerPool.getHedgerPosition(hedger, positionId);
        
        assertGt(margin, initialUsdcAmount, "Position margin should increase");
    }
    
    /**
     * @notice Test hedger margin removal still works correctly
     * @dev Verifies that hedger margin removal functionality remains intact
     */
    function testHedgerMarginRemovalStillWorks() public {
        uint256 usdcAmount = 5000e6; // 5,000 USDC
        uint256 marginToRemove = 1000e6; // 1,000 USDC
        uint256 leverage = 5; // 5x leverage
        
        // Hedger opens position
        vm.prank(hedger);
        uint256 positionId = hedgerPool.enterHedgePosition(usdcAmount, leverage);
        
        uint256 initialHedgerUsdc = usdc.balanceOf(hedger);
        uint256 initialVaultUsdc = vault.getTotalUsdcAvailable();
        
        // Hedger removes margin
        vm.prank(hedger);
        hedgerPool.removeMargin(positionId, marginToRemove);
        
        // Verify hedger USDC increased
        uint256 finalHedgerUsdc = usdc.balanceOf(hedger);
        assertGt(finalHedgerUsdc, initialHedgerUsdc, "Hedger USDC should increase after margin removal");
        
        // Verify vault USDC decreased
        uint256 finalVaultUsdc = vault.getTotalUsdcAvailable();
        assertLt(finalVaultUsdc, initialVaultUsdc, "Vault USDC should decrease after margin removal");
    }
    
    // =============================================================================
    // REGRESSION TESTS - Vault Metrics and State
    // =============================================================================
    
    /**
     * @notice Test vault metrics still work correctly
     * @dev Verifies that vault metrics functionality remains intact
     */
    function testVaultMetricsStillWork() public {
        uint256 userUsdcAmount = 1000e6; // 1,000 USDC
        uint256 hedgerUsdcAmount = 2000e6; // 2,000 USDC
        
        // User mints QEURO
        vm.prank(user);
        vault.mintQEURO(userUsdcAmount, 0);
        
        // Hedger opens position
        vm.prank(hedger);
        hedgerPool.enterHedgePosition(hedgerUsdcAmount, 5);
        
        // Get vault metrics
        (uint256 totalUsdcHeld, uint256 totalMinted, uint256 totalDebtValue) = vault.getVaultMetrics();
        
        // Verify metrics are correct
        assertEq(totalUsdcHeld, userUsdcAmount + hedgerUsdcAmount, "Total USDC held should include both user and hedger deposits");
        assertGt(totalMinted, 0, "Total minted should be positive");
        assertGt(totalDebtValue, 0, "Total debt value should be positive");
    }
    
    /**
     * @notice Test vault state consistency
     * @dev Verifies that vault state remains consistent after operations
     */
    function testVaultStateConsistency() public {
        uint256 userUsdcAmount = 1000e6; // 1,000 USDC
        uint256 hedgerUsdcAmount = 2000e6; // 2,000 USDC
        
        // User mints QEURO
        vm.prank(user);
        vault.mintQEURO(userUsdcAmount, 0);
        
        // Hedger opens position
        vm.prank(hedger);
        uint256 positionId = hedgerPool.enterHedgePosition(hedgerUsdcAmount, 5);
        
        // Verify vault USDC balance matches totalUsdcHeld
        uint256 vaultUsdcBalance = usdc.balanceOf(address(vault));
        uint256 totalUsdcHeld = vault.getTotalUsdcAvailable();
        assertEq(vaultUsdcBalance, totalUsdcHeld, "Vault USDC balance should match totalUsdcHeld");
        
        // Hedger closes position
        vm.prank(hedger);
        hedgerPool.exitHedgePosition(positionId);
        
        // Verify vault USDC balance still matches totalUsdcHeld
        vaultUsdcBalance = usdc.balanceOf(address(vault));
        totalUsdcHeld = vault.getTotalUsdcAvailable();
        assertEq(vaultUsdcBalance, totalUsdcHeld, "Vault USDC balance should still match totalUsdcHeld");
    }
    
    // =============================================================================
    // REGRESSION TESTS - Access Control and Permissions
    // =============================================================================
    
    /**
     * @notice Test access control still works correctly
     * @dev Verifies that access control functionality remains intact
     */
    function testAccessControlStillWorks() public {
        // Non-admin should not be able to update parameters
        vm.prank(user);
        vm.expectRevert();
        vault.updateParameters(100, 200); // 1% mint fee, 2% redemption fee
        
        // Admin should be able to update parameters
        vm.prank(admin);
        vault.updateParameters(100, 200);
        
        // Verify parameters were updated
        (uint256 mintFee, uint256 redemptionFee) = vault.getParameters();
        assertEq(mintFee, 100, "Mint fee should be updated");
        assertEq(redemptionFee, 200, "Redemption fee should be updated");
    }
    
    /**
     * @notice Test hedger whitelist still works correctly
     * @dev Verifies that hedger whitelist functionality remains intact
     */
    function testHedgerWhitelistStillWorks() public {
        address newHedger = address(0x6);
        
        // Mint USDC to new hedger
        MockUSDC(address(usdc)).mint(newHedger, 100000e6);
        
        // Approve hedger pool to spend USDC
        vm.prank(newHedger);
        usdc.approve(address(hedgerPool), type(uint256).max);
        
        // Non-whitelisted hedger should fail
        vm.prank(newHedger);
        vm.expectRevert();
        hedgerPool.enterHedgePosition(1000e6, 5);
        
        // Whitelist hedger
        vm.prank(admin);
        hedgerPool.whitelistHedger(newHedger);
        
        // Whitelisted hedger should succeed
        vm.prank(newHedger);
        uint256 positionId = hedgerPool.enterHedgePosition(1000e6, 5);
        assertGt(positionId, 0, "Whitelisted hedger should be able to open position");
    }
    
    // =============================================================================
    // REGRESSION TESTS - Error Handling
    // =============================================================================
    
    /**
     * @notice Test error handling still works correctly
     * @dev Verifies that error handling functionality remains intact
     */
    function testErrorHandlingStillWorks() public {
        // Zero amount should fail
        vm.prank(user);
        vm.expectRevert("Vault: Amount must be positive");
        vault.mintQEURO(0, 0);
        
        // Insufficient balance should fail
        vm.prank(user);
        vm.expectRevert();
        vault.mintQEURO(2000000e6, 0); // More than user has
        
        // Invalid hedger should fail
        vm.prank(hedger);
        vm.expectRevert();
        hedgerPool.enterHedgePosition(1000e6, 0); // Zero leverage
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
