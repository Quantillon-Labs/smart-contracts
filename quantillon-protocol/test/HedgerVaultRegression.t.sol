// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {QuantillonVault} from "../src/core/QuantillonVault.sol";
import {HedgerPool} from "../src/core/HedgerPool.sol";
import {QEUROToken} from "../src/core/QEUROToken.sol";
import {ChainlinkOracle} from "../src/oracle/ChainlinkOracle.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";

/**
 * @title MockUserPool
 * @dev Mock UserPool for testing purposes
 */
contract MockUserPool {
    uint256 public totalDeposits = 100000000e6; // 100M USDC in deposits
}

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
    
    /**
     * @notice Sets up the test environment for hedger vault regression tests
     * @dev Deploys all necessary contracts and configures test environment
     * @custom:security No security implications - test setup only
     * @custom:validation No validation needed - test setup
     * @custom:state-changes Deploys contracts and sets up mock calls
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - test setup
     * @custom:access No access restrictions - test setup
     * @custom:oracle Not applicable
     */
    function setUp() public {
        // Deploy TimeProvider
        TimeProvider timeProviderImpl = new TimeProvider();
        bytes memory timeProviderInitData = abi.encodeWithSelector(
            TimeProvider.initialize.selector,
            admin,
            admin, // governance
            admin  // emergency
        );
        timeProvider = TimeProvider(address(new ERC1967Proxy(address(timeProviderImpl), timeProviderInitData)));
        
        // Deploy mock USDC
        usdc = IERC20(address(new MockUSDC()));
        
        // Deploy QEURO token
        QEUROToken qeuroImpl = new QEUROToken();
        bytes memory qeuroInitData = abi.encodeWithSelector(
            QEUROToken.initialize.selector,
            admin,
            address(0x123), // mock vault address (will be updated)
            admin, // timelock
            admin, // treasury
            address(0x456) // feeCollector
        );
        qeuro = QEUROToken(address(new ERC1967Proxy(address(qeuroImpl), qeuroInitData)));
        
        // Mock price feed calls before deploying oracle
        vm.mockCall(
            address(0x123), // Mock EUR/USD price feed
            abi.encodeWithSelector(0xfeaf968c), // latestRoundData() selector
            abi.encode(uint80(1), int256(1.1e8), uint256(block.timestamp), uint256(block.timestamp), uint80(1))
        );
        
        vm.mockCall(
            address(0x123), // Mock EUR/USD price feed
            abi.encodeWithSelector(0x313ce567), // decimals() selector
            abi.encode(uint8(8))
        );
        
        vm.mockCall(
            address(0x456), // Mock USDC/USD price feed
            abi.encodeWithSelector(0xfeaf968c), // latestRoundData() selector
            abi.encode(uint80(1), int256(1e8), uint256(block.timestamp), uint256(block.timestamp), uint80(1))
        );
        
        vm.mockCall(
            address(0x456), // Mock USDC/USD price feed
            abi.encodeWithSelector(0x313ce567), // decimals() selector
            abi.encode(uint8(8))
        );
        
        // Deploy oracle
        ChainlinkOracle oracleImpl = new ChainlinkOracle(timeProvider);
        bytes memory oracleInitData = abi.encodeWithSelector(
            ChainlinkOracle.initialize.selector,
            admin,
            address(0x123), // Mock EUR/USD price feed
            address(0x456), // Mock USDC/USD price feed
            admin // treasury
        );
        oracle = ChainlinkOracle(address(new ERC1967Proxy(address(oracleImpl), oracleInitData)));
        
        // Deploy vault
        QuantillonVault vaultImpl = new QuantillonVault();
        bytes memory vaultInitData = abi.encodeWithSelector(
            QuantillonVault.initialize.selector,
            admin,
            address(qeuro),
            address(usdc),
            address(oracle),
            address(0x789), // mock hedger pool address (will be updated)
            address(0), // UserPool (not needed for this test)
            admin, // timelock
            address(0x999) // feeCollector
        );
        vault = QuantillonVault(address(new ERC1967Proxy(address(vaultImpl), vaultInitData)));
        
        // Deploy hedger pool
        HedgerPool hedgerPoolImpl = new HedgerPool(timeProvider);
        bytes memory hedgerPoolInitData = abi.encodeWithSelector(
            HedgerPool.initialize.selector,
            admin,
            address(usdc),
            address(oracle),
            address(0x999), // Mock YieldShift address (not needed for this test)
            admin, // timelock
            admin, // treasury
            address(vault)
        );
        hedgerPool = HedgerPool(address(new ERC1967Proxy(address(hedgerPoolImpl), hedgerPoolInitData)));
        
        // Update vault with correct hedger pool address
        vm.prank(admin);
        vault.updateHedgerPool(address(hedgerPool));
        
        // Grant QEURO mint/burn roles to vault
        vm.prank(admin);
        qeuro.grantRole(keccak256("MINTER_ROLE"), address(vault));
        vm.prank(admin);
        qeuro.grantRole(keccak256("BURNER_ROLE"), address(vault));
        
        // Mock FeeCollector.collectFees calls
        vm.mockCall(
            address(0x999), // feeCollector address
            abi.encodeWithSelector(bytes4(keccak256("collectFees(address,uint256,string)"))),
            abi.encode()
        );
        
        // Deploy mock UserPool to provide collateralization
        MockUserPool mockUserPool = new MockUserPool();
        
        // Update vault with UserPool
        vm.prank(admin);
        vault.updateUserPool(address(mockUserPool));
        
        // Setup test environment
        _setupTestEnvironment();
    }
    
    
    /**
     * @notice Setup test environment with initial balances and permissions
     * @dev Prepares the test environment with necessary tokens and permissions
     * @custom:security No security implications - test setup only
     * @custom:validation No validation needed - test setup
     * @custom:state-changes Mints tokens and sets up approvals
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - test setup
     * @custom:access No access restrictions - test setup
     * @custom:oracle Not applicable
     */
    function _setupTestEnvironment() internal {
        // Mint USDC to test addresses
        MockUSDC(address(usdc)).mint(hedger, 10000000e6); // 10M USDC
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
        hedgerPool.setHedgerWhitelist(hedger, true);
    }
    
    // =============================================================================
    // REGRESSION TESTS - User Minting and Redemption
    // =============================================================================
    
    /**
     * @notice Test user minting still works correctly
     * @dev Verifies that user QEURO minting functionality remains intact
     * @custom:security Tests user minting functionality integrity
     * @custom:validation Ensures minting works correctly
     * @custom:state-changes Mints QEURO and verifies balances
     * @custom:events Expects minting events
     * @custom:errors None expected
     * @custom:reentrancy Not applicable - test function
     * @custom:access No access restrictions - test function
     * @custom:oracle Not applicable
     */
    function testUserMintingStillWorks() public {
        uint256 usdcAmount = 1000e6; // 1,000 USDC
        uint256 initialUserUsdc = usdc.balanceOf(user);
        uint256 initialVaultUsdc = vault.getTotalUsdcAvailable();
        
        // Add hedger deposit to provide collateralization for minting
        uint256 hedgerDepositAmount = 5000000e6; // 5,000,000 USDC
        vm.prank(hedger);
        hedgerPool.enterHedgePosition(hedgerDepositAmount, 2); // 2x leverage
        
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
     * @custom:security Tests user redemption functionality integrity
     * @custom:validation Ensures redemption works correctly
     * @custom:state-changes Redeems QEURO and verifies balances
     * @custom:events Expects redemption events
     * @custom:errors None expected
     * @custom:reentrancy Not applicable - test function
     * @custom:access No access restrictions - test function
     * @custom:oracle Not applicable
     */
    function testUserRedemptionStillWorks() public {
        uint256 usdcAmount = 1000e6; // 1,000 USDC
        
        // Add hedger deposit to provide collateralization for minting
        uint256 hedgerDepositAmount = 5000000e6; // 5,000,000 USDC
        vm.prank(hedger);
        hedgerPool.enterHedgePosition(hedgerDepositAmount, 2); // 2x leverage
        
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
     * @custom:security Tests hedger position opening functionality integrity
     * @custom:validation Ensures position opening works correctly
     * @custom:state-changes Opens hedger position and verifies balances
     * @custom:events Expects position opening events
     * @custom:errors None expected
     * @custom:reentrancy Not applicable - test function
     * @custom:access No access restrictions - test function
     * @custom:oracle Not applicable
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
        (
            address owner,
            uint96 positionSizeRaw,
            ,
            uint96 marginRaw,
            ,
            ,
            ,
            ,
            ,
            uint16 positionLeverageRaw,
            bool isActive,
        ) = hedgerPool.positions(positionId);
        
        assertEq(owner, hedger, "Position owner should match");
        assertTrue(isActive, "Position should be active");
        assertEq(positionLeverageRaw, leverage, "Position leverage should match");
        assertGt(uint256(marginRaw), 0, "Position margin should be positive");
        assertGt(uint256(positionSizeRaw), 0, "Position size should be positive");
    }
    
    /**
     * @notice Test hedger position closing still works correctly
     * @dev Verifies that hedger position closing functionality remains intact
     * @custom:security Tests hedger position closing functionality integrity
     * @custom:validation Ensures position closing works correctly
     * @custom:state-changes Opens and closes hedger position
     * @custom:events Expects position opening and closing events
     * @custom:errors None expected
     * @custom:reentrancy Not applicable - test function
     * @custom:access No access restrictions - test function
     * @custom:oracle Not applicable
     */
    function testHedgerPositionClosingStillWorks() public {
        uint256 usdcAmount = 5000e6; // 5,000 USDC
        uint256 leverage = 5; // 5x leverage
        
        // Hedger opens position
        vm.prank(hedger);
        uint256 positionId = hedgerPool.enterHedgePosition(usdcAmount, leverage);
        
        // Open an additional smaller position to ensure remaining collateral after closure
        vm.prank(hedger);
        hedgerPool.enterHedgePosition(1000e6, 3);
        
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
     * @custom:security Tests hedger margin addition functionality integrity
     * @custom:validation Ensures margin addition works correctly
     * @custom:state-changes Opens position and adds additional margin
     * @custom:events Expects position opening and margin addition events
     * @custom:errors None expected
     * @custom:reentrancy Not applicable - test function
     * @custom:access No access restrictions - test function
     * @custom:oracle Not applicable
     */
    function testHedgerMarginAdditionStillWorks() public {
        uint256 initialUsdcAmount = 3000e6; // 3,000 USDC
        uint256 additionalMargin = 1000e6; // 1,000 USDC
        uint256 leverage = 5; // 5x leverage
        
        // Hedger opens position
        vm.prank(hedger);
        uint256 positionId = hedgerPool.enterHedgePosition(initialUsdcAmount, leverage);
        
        uint256 initialVaultUsdc = vault.getTotalUsdcAvailable();
        
        // Wait for liquidation cooldown to expire
        vm.roll(block.number + 301);
        
        // Hedger adds margin
        vm.prank(hedger);
        hedgerPool.addMargin(positionId, additionalMargin);
        
        // Verify vault USDC increased
        uint256 finalVaultUsdc = vault.getTotalUsdcAvailable();
        assertGt(finalVaultUsdc, initialVaultUsdc, "Vault USDC should increase after margin addition");
        
        // Verify position margin increased
        (, , , uint96 marginRaw, , , , , , , , ) = hedgerPool.positions(positionId);
        assertGt(uint256(marginRaw), initialUsdcAmount, "Position margin should increase");
    }
    
    /**
     * @notice Test hedger margin removal still works correctly
     * @dev Verifies that hedger margin removal functionality remains intact
     * @custom:security Tests hedger margin removal functionality integrity
     * @custom:validation Ensures margin removal works correctly
     * @custom:state-changes Opens position and removes margin
     * @custom:events Expects position opening and margin removal events
     * @custom:errors None expected
     * @custom:reentrancy Not applicable - test function
     * @custom:access No access restrictions - test function
     * @custom:oracle Not applicable
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
     * @custom:security Tests vault metrics functionality integrity
     * @custom:validation Ensures vault metrics work correctly
     * @custom:state-changes Opens positions and verifies metrics
     * @custom:events Expects position opening and minting events
     * @custom:errors None expected
     * @custom:reentrancy Not applicable - test function
     * @custom:access No access restrictions - test function
     * @custom:oracle Not applicable
     */
    function testVaultMetricsStillWork() public {
        uint256 userUsdcAmount = 1000e6; // 1,000 USDC
        uint256 hedgerUsdcAmount = 2000e6; // 2,000 USDC
        
        // Add hedger deposit to provide collateralization for minting
        uint256 initialHedgerDepositAmount = 5000000e6; // 5,000,000 USDC
        vm.prank(hedger);
        hedgerPool.enterHedgePosition(initialHedgerDepositAmount, 2); // 2x leverage
        
        // User mints QEURO
        vm.prank(user);
        vault.mintQEURO(userUsdcAmount, 0);
        
        // Hedger opens position
        vm.prank(hedger);
        hedgerPool.enterHedgePosition(hedgerUsdcAmount, 5);
        
        // Get vault metrics
        (uint256 totalUsdcHeld, uint256 totalMinted, uint256 totalDebtValue) = vault.getVaultMetrics();
        
        // Calculate expected total (accounting for minting fee)
        uint256 mintingFee = (userUsdcAmount * vault.mintFee()) / 1e18;
        uint256 expectedTotal = initialHedgerDepositAmount + (userUsdcAmount - mintingFee) + hedgerUsdcAmount;
        
        // Verify metrics are correct
        assertEq(totalUsdcHeld, expectedTotal, "Total USDC held should include all deposits minus fees");
        assertGt(totalMinted, 0, "Total minted should be positive");
        assertGt(totalDebtValue, 0, "Total debt value should be positive");
    }
    
    /**
     * @notice Test vault state consistency
     * @dev Verifies that vault state remains consistent after operations
     * @custom:security Tests vault state consistency integrity
     * @custom:validation Ensures vault state remains consistent
     * @custom:state-changes Opens positions and verifies state consistency
     * @custom:events Expects position opening and minting events
     * @custom:errors None expected
     * @custom:reentrancy Not applicable - test function
     * @custom:access No access restrictions - test function
     * @custom:oracle Not applicable
     */
    function testVaultStateConsistency() public {
        uint256 userUsdcAmount = 1000e6; // 1,000 USDC
        uint256 hedgerUsdcAmount = 2000e6; // 2,000 USDC
        
        // Add hedger deposit to provide collateralization for minting
        uint256 initialHedgerDepositAmount = 5000000e6; // 5,000,000 USDC
        vm.prank(hedger);
        hedgerPool.enterHedgePosition(initialHedgerDepositAmount, 2); // 2x leverage
        
        // User mints QEURO
        vm.prank(user);
        vault.mintQEURO(userUsdcAmount, 0);
        
        // Hedger opens position
        vm.prank(hedger);
        uint256 positionId = hedgerPool.enterHedgePosition(hedgerUsdcAmount, 5);
        
        // Verify vault USDC balance matches totalUsdcHeld (accounting for fees that remain in vault due to mocking)
        uint256 vaultUsdcBalance = usdc.balanceOf(address(vault));
        uint256 totalUsdcHeld = vault.getTotalUsdcAvailable();
        // If fees are enabled, balance should be higher than totalUsdcHeld due to fees remaining in vault
        // If fees are 0 (testing mode), balance should equal totalUsdcHeld
        assertGe(vaultUsdcBalance, totalUsdcHeld, "Vault USDC balance should be >= totalUsdcHeld");
        
        // Hedger closes position
        vm.prank(hedger);
        hedgerPool.exitHedgePosition(positionId);
        
        // Verify vault USDC balance still accounts for fees
        vaultUsdcBalance = usdc.balanceOf(address(vault));
        totalUsdcHeld = vault.getTotalUsdcAvailable();
        assertGe(vaultUsdcBalance, totalUsdcHeld, "Vault USDC balance should still be >= totalUsdcHeld");
    }
    
    // =============================================================================
    // REGRESSION TESTS - Access Control and Permissions
    // =============================================================================
    
    /**
     * @notice Test access control still works correctly
     * @dev Verifies that access control functionality remains intact
     * @custom:security Tests access control functionality integrity
     * @custom:validation Ensures access control works correctly
     * @custom:state-changes Attempts unauthorized parameter updates
     * @custom:events None expected due to revert
     * @custom:errors Expects access control error
     * @custom:reentrancy Not applicable - test function
     * @custom:access Tests admin role access control
     * @custom:oracle Not applicable
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
        uint256 mintFee = vault.mintFee();
        uint256 redemptionFee = vault.redemptionFee();
        assertEq(mintFee, 100, "Mint fee should be updated");
        assertEq(redemptionFee, 200, "Redemption fee should be updated");
    }
    
    /**
     * @notice Test hedger whitelist still works correctly
     * @dev Verifies that hedger whitelist functionality remains intact
     * @custom:security Tests hedger whitelist functionality integrity
     * @custom:validation Ensures whitelist functionality works correctly
     * @custom:state-changes Whitelists hedger and opens position
     * @custom:events Expects whitelist and position opening events
     * @custom:errors None expected
     * @custom:reentrancy Not applicable - test function
     * @custom:access Tests governance role access
     * @custom:oracle Not applicable
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
        hedgerPool.setHedgerWhitelist(newHedger, true);
        
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
     * @custom:security Tests error handling functionality integrity
     * @custom:validation Ensures error handling works correctly
     * @custom:state-changes Attempts invalid operations to trigger errors
     * @custom:events None expected due to revert
     * @custom:errors Expects various validation errors
     * @custom:reentrancy Not applicable - test function
     * @custom:access No access restrictions - test function
     * @custom:oracle Not applicable
     */
    function testErrorHandlingStillWorks() public {
        // Zero amount should fail
        vm.prank(user);
        vm.expectRevert(CommonErrorLibrary.InvalidAmount.selector);
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
    
    /**
     * @notice Mints tokens to a specified address
     * @dev Mock implementation for testing purposes
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     * @custom:security No security implications - test mock only
     * @custom:validation No validation needed - test function
     * @custom:state-changes Increases balanceOf[to] and totalSupply
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - simple state update
     * @custom:access No access restrictions - test function
     * @custom:oracle Not applicable
     */
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }
    
    /**
     * @notice Approves a spender to transfer tokens
     * @dev Mock implementation for testing purposes
     * @param spender Address to approve for spending
     * @param amount Amount of tokens to approve
     * @return bool Always returns true
     * @custom:security No security implications - test mock only
     * @custom:validation No validation needed - test function
     * @custom:state-changes Updates allowance mapping
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - simple state update
     * @custom:access No access restrictions - test function
     * @custom:oracle Not applicable
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
    
    /**
     * @notice Transfers tokens to a specified address
     * @dev Mock implementation for testing purposes
     * @param to Address to transfer tokens to
     * @param amount Amount of tokens to transfer
     * @return bool Always returns true
     * @custom:security No security implications - test mock only
     * @custom:validation No validation needed - test function
     * @custom:state-changes Updates balanceOf mappings
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - simple state update
     * @custom:access No access restrictions - test function
     * @custom:oracle Not applicable
     */
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    /**
     * @notice Transfers tokens from one address to another using allowance
     * @dev Mock implementation for testing purposes
     * @param from Address to transfer tokens from
     * @param to Address to transfer tokens to
     * @param amount Amount of tokens to transfer
     * @return bool Always returns true
     * @custom:security No security implications - test mock only
     * @custom:validation No validation needed - test function
     * @custom:state-changes Updates balanceOf and allowance mappings
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - simple state update
     * @custom:access No access restrictions - test function
     * @custom:oracle Not applicable
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}
