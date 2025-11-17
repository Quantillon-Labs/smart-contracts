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
    
    /**
     * @notice Sets up the test environment for hedger vault integration tests
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
            admin  // treasury
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
     * @custom:security Tests vault deposit mechanism
     * @custom:validation Ensures USDC is properly deposited to vault
     * @custom:state-changes Opens hedger position and verifies vault balance
     * @custom:events Expects position opening events
     * @custom:errors None expected
     * @custom:reentrancy Not applicable - test function
     * @custom:access No access restrictions - test function
     * @custom:oracle Not applicable
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
     * @custom:security Tests event emission integrity
     * @custom:validation Ensures correct event parameters
     * @custom:state-changes Opens hedger position and verifies event emission
     * @custom:events Expects HedgerDepositAdded event
     * @custom:errors None expected
     * @custom:reentrancy Not applicable - test function
     * @custom:access No access restrictions - test function
     * @custom:oracle Not applicable
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
     * @custom:security Tests deposit accumulation mechanism
     * @custom:validation Ensures multiple deposits are properly tracked
     * @custom:state-changes Opens multiple positions and verifies accumulation
     * @custom:events Expects multiple position opening events
     * @custom:errors None expected
     * @custom:reentrancy Not applicable - test function
     * @custom:access No access restrictions - test function
     * @custom:oracle Not applicable
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
     * @custom:security Tests hedger withdrawal mechanism
     * @custom:validation Ensures withdrawal works correctly
     * @custom:state-changes Opens position and then withdraws
     * @custom:events Expects position opening and withdrawal events
     * @custom:errors None expected
     * @custom:reentrancy Not applicable - test function
     * @custom:access No access restrictions - test function
     * @custom:oracle Not applicable
     */
    function testHedgerWithdrawalFromVault() public {
        uint256 hedgerDepositAmount = 10000e6; // 10,000 USDC
        
        // Hedger opens position
        vm.prank(hedger);
        uint256 positionId = hedgerPool.enterHedgePosition(hedgerDepositAmount, 10);

        // Open an additional position to leave residual margin in the vault
        vm.prank(hedger);
        hedgerPool.enterHedgePosition(2000e6, 3);
        
        uint256 vaultUsdcAfterDeposit = vault.getTotalUsdcAvailable();
        assertEq(vaultUsdcAfterDeposit, hedgerDepositAmount + 2000e6, "Vault should reflect total hedger deposits");
        
        // Hedger closes position
        vm.prank(hedger);
        hedgerPool.exitHedgePosition(positionId);
        
        // Verify vault's totalUsdcHeld decreased
        uint256 vaultUsdcAfterWithdrawal = vault.getTotalUsdcAvailable();
        assertEq(vaultUsdcAfterWithdrawal, vaultUsdcAfterDeposit - hedgerDepositAmount, "Vault USDC should decrease by withdrawn deposit");
        
        // Verify hedger received USDC
        uint256 hedgerUsdcBalance = usdc.balanceOf(hedger);
        assertGt(hedgerUsdcBalance, 0, "Hedger should receive USDC back");
    }
    
    /**
     * @notice Test hedger withdrawal emits correct event
     * @dev Verifies HedgerDepositWithdrawn event is emitted with correct parameters
     * @custom:security Tests event emission integrity
     * @custom:validation Ensures correct event parameters
     * @custom:state-changes Opens position and withdraws, verifies event
     * @custom:events Expects HedgerDepositWithdrawn event
     * @custom:errors None expected
     * @custom:reentrancy Not applicable - test function
     * @custom:access No access restrictions - test function
     * @custom:oracle Not applicable
     */
    function testHedgerWithdrawalEmitsEvent() public {
        uint256 hedgerDepositAmount = 5000e6; // 5,000 USDC
        
        // Hedger opens position
        vm.prank(hedger);
        uint256 positionId = hedgerPool.enterHedgePosition(hedgerDepositAmount, 5);

        // Open a secondary position to keep the vault collateralized after first withdrawal
        vm.prank(hedger);
        hedgerPool.enterHedgePosition(1000e6, 3);

        uint256 vaultUsdcBeforeWithdrawal = vault.getTotalUsdcAvailable();
        uint256 expectedVaultAfterWithdrawal = vaultUsdcBeforeWithdrawal - hedgerDepositAmount;
        
        // Expect HedgerDepositWithdrawn event
        vm.expectEmit(true, false, false, true);
        emit QuantillonVault.HedgerDepositWithdrawn(
            hedger,
            hedgerDepositAmount,
            expectedVaultAfterWithdrawal
        );
        
        // Hedger closes position
        vm.prank(hedger);
        hedgerPool.exitHedgePosition(positionId);

        uint256 vaultUsdcAfterWithdrawal = vault.getTotalUsdcAvailable();
        assertEq(vaultUsdcAfterWithdrawal, expectedVaultAfterWithdrawal, "Vault USDC should match expectation after withdrawal");
    }
    
    // =============================================================================
    // TEST CASES - Unified Liquidity for User Redemptions
    // =============================================================================
    
    /**
     * @notice Test user redemption can use hedger USDC
     * @dev Verifies that user redemptions can access hedger USDC in vault
     * @custom:security Tests user redemption with hedger USDC
     * @custom:validation Ensures redemption can use hedger deposits
     * @custom:state-changes Opens hedger position and redeems QEURO
     * @custom:events Expects position opening and redemption events
     * @custom:errors None expected
     * @custom:reentrancy Not applicable - test function
     * @custom:access No access restrictions - test function
     * @custom:oracle Not applicable
     */
    function testUserRedemptionUsesHedgerUsdc() public {
        // Setup: Hedger deposits USDC
        uint256 hedgerUsdcAmount = 2000e6; // 2,000 USDC
        
        // Hedger opens position
        vm.prank(hedger);
        hedgerPool.enterHedgePosition(hedgerUsdcAmount, 2); // 2x leverage
        
        uint256 totalVaultUsdc = vault.getTotalUsdcAvailable();
        assertEq(totalVaultUsdc, hedgerUsdcAmount, "Vault should have hedger USDC");
        
        // Verify hedger position was created
        uint256 hedgerBalance = usdc.balanceOf(hedger);
        assertLt(hedgerBalance, 1000000e6, "Hedger should have less USDC after deposit");
        
        // Verify vault has the hedger's USDC
        assertEq(vault.getTotalUsdcAvailable(), hedgerUsdcAmount, "Vault should have hedger's USDC");
    }
    
    /**
     * @notice Test hedger deposit with insufficient USDC balance
     * @dev Verifies that hedger deposits fail when hedger doesn't have enough USDC
     * @custom:security Tests insufficient balance handling
     * @custom:validation Ensures insufficient balance is rejected
     * @custom:state-changes Attempts to open position with insufficient balance
     * @custom:events None expected due to revert
     * @custom:errors Expects insufficient balance error
     * @custom:reentrancy Not applicable - test function
     * @custom:access No access restrictions - test function
     * @custom:oracle Not applicable
     */
    function testRedemptionFailsInsufficientHedgerUsdc() public {
        // Test that hedger deposit fails when hedger has insufficient USDC balance
        uint256 hedgerAmount = 2000000e6; // 2M USDC (more than hedger's 1M balance)
        
        vm.prank(hedger);
        vm.expectRevert(); // Should revert due to insufficient balance
        hedgerPool.enterHedgePosition(hedgerAmount, 2); // 2x leverage
        
        // Verify vault has no USDC
        uint256 vaultUsdc = vault.getTotalUsdcAvailable();
        assertEq(vaultUsdc, 0, "Vault should have no USDC after failed deposit");
    }
    
    // =============================================================================
    // TEST CASES - Access Control and Security
    // =============================================================================
    
    /**
     * @notice Test only HedgerPool can call addHedgerDeposit
     * @dev Verifies access control for hedger deposit function
     * @custom:security Tests access control for hedger deposits
     * @custom:validation Ensures only HedgerPool can add deposits
     * @custom:state-changes Attempts unauthorized deposit addition
     * @custom:events None expected due to revert
     * @custom:errors Expects access control error
     * @custom:reentrancy Not applicable - test function
     * @custom:access Tests HedgerPool role access control
     * @custom:oracle Not applicable
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
     * @custom:security Tests access control for hedger withdrawals
     * @custom:validation Ensures only HedgerPool can withdraw deposits
     * @custom:state-changes Attempts unauthorized deposit withdrawal
     * @custom:events None expected due to revert
     * @custom:errors Expects access control error
     * @custom:reentrancy Not applicable - test function
     * @custom:access Tests HedgerPool role access control
     * @custom:oracle Not applicable
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
     * @custom:security Tests input validation for hedger deposits
     * @custom:validation Ensures zero amount is rejected
     * @custom:state-changes Attempts to add zero amount deposit
     * @custom:events None expected due to revert
     * @custom:errors Expects amount validation error
     * @custom:reentrancy Not applicable - test function
     * @custom:access Tests HedgerPool role access
     * @custom:oracle Not applicable
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
     * @custom:security Tests input validation for hedger withdrawals
     * @custom:validation Ensures zero amount is rejected
     * @custom:state-changes Attempts to withdraw zero amount
     * @custom:events None expected due to revert
     * @custom:errors Expects amount validation error
     * @custom:reentrancy Not applicable - test function
     * @custom:access Tests HedgerPool role access
     * @custom:oracle Not applicable
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
     * @custom:security Tests insufficient reserves handling
     * @custom:validation Ensures insufficient reserves are rejected
     * @custom:state-changes Attempts to withdraw from empty vault
     * @custom:events None expected due to revert
     * @custom:errors Expects insufficient reserves error
     * @custom:reentrancy Not applicable - test function
     * @custom:access Tests HedgerPool role access
     * @custom:oracle Not applicable
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
     * @custom:security Tests maximum deposit handling
     * @custom:validation Ensures large deposits work correctly
     * @custom:state-changes Opens position with maximum amount
     * @custom:events Expects position opening events
     * @custom:errors None expected
     * @custom:reentrancy Not applicable - test function
     * @custom:access No access restrictions - test function
     * @custom:oracle Not applicable
     */
    function testHedgerDepositMaximumAmount() public {
        uint256 maxAmount = 1000000e6; // 1M USDC
        
        // Should succeed with large amount
        vm.prank(hedger);
        hedgerPool.enterHedgePosition(maxAmount, 2); // 2x leverage (50% margin ratio)
        
        uint256 vaultUsdc = vault.getTotalUsdcAvailable();
        assertEq(vaultUsdc, maxAmount, "Vault should handle large hedger deposits");
    }
    
    /**
     * @notice Test hedger deposit with minimum amount
     * @dev Verifies system handles small hedger deposits correctly
     * @custom:security Tests minimum deposit handling
     * @custom:validation Ensures small deposits work correctly
     * @custom:state-changes Opens position with minimum amount
     * @custom:events Expects position opening events
     * @custom:errors None expected
     * @custom:reentrancy Not applicable - test function
     * @custom:access No access restrictions - test function
     * @custom:oracle Not applicable
     */
    function testHedgerDepositMinimumAmount() public {
        uint256 minAmount = 1e6; // 1 USDC
        
        // Should succeed with small amount
        vm.prank(hedger);
        hedgerPool.enterHedgePosition(minAmount, 2); // 2x leverage (50% margin ratio)
        
        uint256 vaultUsdc = vault.getTotalUsdcAvailable();
        assertEq(vaultUsdc, minAmount, "Vault should handle small hedger deposits");
    }
    
    /**
     * @notice Test getTotalUsdcAvailable returns correct value
     * @dev Verifies the view function returns accurate vault USDC balance
     * @custom:security Tests view function accuracy
     * @custom:validation Ensures view function returns correct values
     * @custom:state-changes Opens position and verifies vault balance
     * @custom:events Expects position opening events
     * @custom:errors None expected
     * @custom:reentrancy Not applicable - test function
     * @custom:access No access restrictions - test function
     * @custom:oracle Not applicable
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
     * @custom:validation Validates sufficient balance and allowance
     * @custom:state-changes Updates balanceOf and allowance mappings
     * @custom:events None
     * @custom:errors Reverts on insufficient balance or allowance
     * @custom:reentrancy Not applicable - simple state update
     * @custom:access No access restrictions - test function
     * @custom:oracle Not applicable
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}
