// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// =============================================================================
// test/AaveIntegration.t.sol
// Tests for the USDC-to-Aave auto-deployment feature
// Verifies that USDC deposited during QEURO minting is automatically deployed to Aave
// =============================================================================

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {QuantillonVault} from "../src/core/QuantillonVault.sol";
import {UserPool} from "../src/core/UserPool.sol";
import {QEUROToken} from "../src/core/QEUROToken.sol";
import {FeeCollector} from "../src/core/FeeCollector.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";

/**
 * @title MockUSDC
 * @notice Simple mock USDC token for testing (6 decimals)
 */
contract MockUSDC {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    string public name = "Mock USDC";
    string public symbol = "USDC";
    uint8 public decimals = 6;
    uint256 public totalSupply;
    
    /**
     * @notice Mints new USDC tokens to an address
     * @dev Increases balanceOf mapping and totalSupply
     * @param to Address to receive the tokens
     * @param amount Amount of tokens to mint (6 decimals)
     * @custom:security No security implications - test mock
     * @custom:validation No validation - test mock
     * @custom:state-changes Increases balanceOf[to] and totalSupply
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependency
     */
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }
    
    /**
     * @notice Transfers USDC tokens to another address
     * @dev Transfers tokens from msg.sender to recipient, validates balance
     * @param to Address to receive the tokens
     * @param amount Amount of tokens to transfer (6 decimals)
     * @return Success status
     * @custom:security No security implications - test mock
     * @custom:validation Validates sender has sufficient balance
     * @custom:state-changes Decreases balanceOf[msg.sender], increases balanceOf[to]
     * @custom:events No events emitted
     * @custom:errors Reverts with "Insufficient balance" if balance insufficient
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependency
     */
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    /**
     * @notice Transfers USDC tokens from one address to another using allowance
     * @dev Transfers tokens using allowance mechanism, validates balance and allowance
     * @param from Address to transfer from
     * @param to Address to receive the tokens
     * @param amount Amount of tokens to transfer (6 decimals)
     * @return Success status
     * @custom:security No security implications - test mock
     * @custom:validation Validates from has sufficient balance and allowance
     * @custom:state-changes Decreases balanceOf[from] and allowance, increases balanceOf[to]
     * @custom:events No events emitted
     * @custom:errors Reverts with "Insufficient balance" or "Insufficient allowance"
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependency
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        return true;
    }
    
    /**
     * @notice Approves spender to transfer tokens on behalf of sender
     * @dev Sets allowance mapping for spender
     * @param spender Address to approve
     * @param amount Amount of tokens to approve (6 decimals)
     * @return Success status
     * @custom:security No security implications - test mock
     * @custom:validation No validation - test mock
     * @custom:state-changes Sets allowance[msg.sender][spender]
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependency
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

/**
 * @title MockOracle
 * @notice Simple mock oracle for testing
 */
contract MockOracle {
    uint256 public price = 108e16; // 1 EUR = 1.08 USD (18 decimals)
    
    /**
     * @notice Returns the current EUR/USD price
     * @dev Returns stored price value and always marks as valid
     * @return price Current price (18 decimals)
     * @return isValid Always returns true for mock
     * @custom:security No security implications - test mock
     * @custom:validation No validation - test mock
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - test mock
     * @custom:oracle Returns mock EUR/USD price
     */
    function getEurUsdPrice() external view returns (uint256, bool) {
        return (price, true);
    }
    
    /**
     * @notice Sets the mock EUR/USD price
     * @dev Updates stored price value
     * @param _price New price value (18 decimals)
     * @custom:security No security implications - test mock
     * @custom:validation No validation - test mock
     * @custom:state-changes Updates price state variable
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle Updates mock EUR/USD price
     */
    function setPrice(uint256 _price) external {
        price = _price;
    }
}

/**
 * @title MockHedgerPool
 * @notice Simple mock HedgerPool for testing
 */
contract MockHedgerPool {
    uint256 public totalMargin = 1000000e6; // 1M USDC margin
    
    /**
     * @notice Mock function to record user mint (no-op)
     * @dev Parameters are unused in mock implementation
     * @custom:security No security implications - test mock
     * @custom:validation No validation - test mock
     * @custom:state-changes No state changes - no-op
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependency
     */
    function recordUserMint(uint256, uint256, uint256) external {}
    
    /**
     * @notice Mock function to record user redeem (no-op)
     * @dev Parameters are unused in mock implementation
     * @custom:security No security implications - test mock
     * @custom:validation No validation - test mock
     * @custom:state-changes No state changes - no-op
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependency
     */
    function recordUserRedeem(uint256, uint256, uint256) external {}
    
    /**
     * @notice Returns total effective hedger collateral
     * @dev Parameter is unused in mock implementation
     * @return Total margin amount (6 decimals)
     * @custom:security No security implications - test mock
     * @custom:validation No validation - test mock
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependency
     */
    function getTotalEffectiveHedgerCollateral(uint256) external view returns (uint256) {
        return totalMargin;
    }
}

/**
 * @title MockAaveVault
 * @notice Mock AaveVault for testing the integration
 */
contract MockAaveVault {
    IERC20 public usdc;
    uint256 public principalDeposited;
    uint256 public totalDeployed;
    uint256 public totalWithdrawn;
    
    /**
     * @notice Constructor for mock Aave vault
     * @dev Initializes mock Aave vault with USDC token address
     * @param _usdc Address of USDC token contract
     * @custom:security No security implications - test mock
     * @custom:validation No validation - test mock
     * @custom:state-changes Initializes usdc address
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - constructor
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependency
     */
    constructor(address _usdc) {
        usdc = IERC20(_usdc);
    }
    
    /**
     * @notice Simulates deploying USDC to Aave
     * @dev Transfers USDC from caller and tracks deployment metrics
     * @param amount Amount of USDC to deploy (6 decimals)
     * @return Amount of aTokens received (1:1 for simplicity)
     * @custom:security No security implications - test mock
     * @custom:validation Validates transferFrom succeeds
     * @custom:state-changes Transfers USDC from caller, updates principalDeposited and totalDeployed
     * @custom:events No events emitted
     * @custom:errors Reverts if transferFrom fails
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependency
     */
    function deployToAave(uint256 amount) external returns (uint256) {
        // Transfer USDC from caller to this contract (simulating Aave deposit)
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        usdc.transferFrom(msg.sender, address(this), amount);
        principalDeposited += amount;
        totalDeployed += amount;
        return amount; // Return aTokens received (1:1 for simplicity)
    }
    
    /**
     * @notice Simulates withdrawing USDC from Aave
     * @dev Withdraws up to available principal and transfers to caller
     * @param amount Amount of USDC to withdraw (6 decimals)
     * @return Actual amount withdrawn (may be less than requested)
     * @custom:security No security implications - test mock
     * @custom:validation No validation - test mock
     * @custom:state-changes Decreases principalDeposited, increases totalWithdrawn, transfers USDC to caller
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependency
     */
    function withdrawFromAave(uint256 amount) external returns (uint256) {
        uint256 withdrawAmount = amount > principalDeposited ? principalDeposited : amount;
        if (withdrawAmount > 0) {
            principalDeposited -= withdrawAmount;
            totalWithdrawn += withdrawAmount;
            // Transfer USDC back to caller
            // forge-lint: disable-next-line(erc20-unchecked-transfer)
            usdc.transfer(msg.sender, withdrawAmount);
        }
        return withdrawAmount;
    }
    
    /**
     * @notice Returns current Aave balance
     * @dev Returns principalDeposited value
     * @return Current principal deposited in Aave (6 decimals)
     * @custom:security No security implications - test mock
     * @custom:validation No validation - test mock
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependency
     */
    function getAaveBalance() external view returns (uint256) {
        return principalDeposited;
    }
}

/**
 * @title AaveIntegrationTest
 * @notice Tests for the USDC-to-Aave auto-deployment feature
 */
contract AaveIntegrationTest is Test {
    // Contracts
    QuantillonVault public vault;
    UserPool public userPool;
    QEUROToken public qeuro;
    MockUSDC public usdc;
    MockOracle public oracle;
    MockHedgerPool public hedgerPool;
    MockAaveVault public aaveVault;
    FeeCollector public feeCollector;
    TimeProvider public timeProvider;
    
    // Addresses
    address public admin = address(0x1);
    address public user = address(0x2);
    address public treasury = address(0x3);
    
    // Constants
    uint256 constant INITIAL_USDC = 100_000e6; // 100,000 USDC
    
    /**
     * @notice Sets up test environment with all required contracts
     * @dev Deploys mock contracts, vault, user pool, and configures roles
     * @custom:security No security implications - test setup
     * @custom:validation No validation - test setup
     * @custom:state-changes Deploys and initializes all test contracts
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test setup
     * @custom:access Public - test setup
     * @custom:oracle No oracle dependency
     */
    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy mock contracts
        usdc = new MockUSDC();
        oracle = new MockOracle();
        hedgerPool = new MockHedgerPool();
        aaveVault = new MockAaveVault(address(usdc));
        
        // Deploy TimeProvider
        timeProvider = new TimeProvider();
        
        // Deploy FeeCollector first (needed for QEURO initialization)
        FeeCollector feeCollectorImpl = new FeeCollector();
        bytes memory feeCollectorData = abi.encodeWithSelector(
            FeeCollector.initialize.selector,
            admin,
            treasury, // treasury
            treasury, // devFund (use treasury for testing)
            treasury  // communityFund (use treasury for testing)
        );
        ERC1967Proxy feeCollectorProxy = new ERC1967Proxy(address(feeCollectorImpl), feeCollectorData);
        feeCollector = FeeCollector(address(feeCollectorProxy));

        // Deploy QEURO token (vault will be set later via role grant)
        QEUROToken qeuroImpl = new QEUROToken();
        bytes memory qeuroData = abi.encodeWithSelector(
            QEUROToken.initialize.selector,
            admin,
            admin, // vault (temporary, real vault gets MINTER_ROLE later)
            treasury, // timelock
            treasury, // treasury
            address(feeCollector) // feeCollector
        );
        ERC1967Proxy qeuroProxy = new ERC1967Proxy(address(qeuroImpl), qeuroData);
        qeuro = QEUROToken(address(qeuroProxy));
        
        // Deploy QuantillonVault
        QuantillonVault vaultImpl = new QuantillonVault();
        bytes memory vaultData = abi.encodeWithSelector(
            QuantillonVault.initialize.selector,
            admin,
            address(qeuro),
            address(usdc),
            address(oracle),
            address(hedgerPool),
            address(0), // UserPool set later
            treasury, // timelock
            address(feeCollector)
        );
        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(vaultImpl), vaultData);
        vault = QuantillonVault(address(vaultProxy));
        
        // Deploy UserPool
        UserPool userPoolImpl = new UserPool(timeProvider);
        bytes memory userPoolData = abi.encodeWithSelector(
            UserPool.initialize.selector,
            admin,
            address(qeuro),
            address(usdc),
            address(vault),
            address(oracle),
            address(0), // YieldShift not needed for this test
            treasury, // timelock
            treasury // treasury
        );
        ERC1967Proxy userPoolProxy = new ERC1967Proxy(address(userPoolImpl), userPoolData);
        userPool = UserPool(address(userPoolProxy));
        
        // Configure vault with AaveVault and grant roles
        vault.updateAaveVault(address(aaveVault));
        vault.updateUserPool(address(userPool));
        
        // Grant VAULT_OPERATOR_ROLE to UserPool
        vault.grantRole(vault.VAULT_OPERATOR_ROLE(), address(userPool));
        
        // Grant MINTER_ROLE and BURNER_ROLE to vault for QEURO
        qeuro.grantRole(qeuro.MINTER_ROLE(), address(vault));
        qeuro.grantRole(qeuro.BURNER_ROLE(), address(vault));
        
        // Grant TREASURY_ROLE to vault on FeeCollector to allow fee collection
        feeCollector.grantRole(feeCollector.TREASURY_ROLE(), address(vault));
        
        // Enable dev mode to bypass price cache requirements
        vault.setDevMode(true);
        
        // Mint USDC to user for testing
        usdc.mint(user, INITIAL_USDC);
        
        vm.stopPrank();
    }
    
    // =============================================================================
    // DEPLOYMENT TO AAVE TESTS
    // =============================================================================
    
    /**
     * @notice Tests that USDC is successfully deployed to Aave during deposit
     * @dev Verifies that depositing USDC triggers automatic Aave deployment
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Deposits USDC, triggers Aave deployment
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test function
     * @custom:access Public - test function
     * @custom:oracle No oracle dependency
     */
    function test_deployUsdcToAave_success() public {
        // Arrange: First deposit some USDC to vault through minting
        uint256 depositAmount = 10_000e6; // 10,000 USDC
        
        vm.startPrank(user);
        usdc.approve(address(userPool), depositAmount);
        
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = depositAmount;
        uint256[] memory minOuts = new uint256[](1);
        minOuts[0] = 0;
        
        userPool.deposit(amounts, minOuts);
        vm.stopPrank();
        
        // Assert: USDC should have been deployed to Aave
        // The vault should have reduced totalUsdcHeld and increased totalUsdcInAave
        assertGt(vault.totalUsdcInAave(), 0, "USDC should be deployed to Aave");
        assertEq(aaveVault.totalDeployed(), vault.totalUsdcInAave(), "AaveVault should have received USDC");
    }
    
    /**
     * @notice Tests that vault metrics are updated correctly after Aave deployment
     * @dev Verifies totalUsdcInAave and totalUsdcAvailable reflect Aave deployment
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Deposits USDC, checks vault metrics
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test function
     * @custom:access Public - test function
     * @custom:oracle No oracle dependency
     */
    function test_deployUsdcToAave_updatesMetrics() public {
        // Arrange: Deposit USDC
        uint256 depositAmount = 10_000e6;
        
        vm.startPrank(user);
        usdc.approve(address(userPool), depositAmount);
        
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = depositAmount;
        uint256[] memory minOuts = new uint256[](1);
        minOuts[0] = 0;
        
        userPool.deposit(amounts, minOuts);
        vm.stopPrank();
        
        // Act: Get vault metrics
        (
            uint256 totalUsdcHeld,
            uint256 _totalMinted,
            uint256 _totalDebtValue,
            uint256 totalUsdcInAave,
            uint256 totalUsdcAvailable
        ) = vault.getVaultMetrics();
        
        // Suppress unused variable warnings
        _totalMinted;
        _totalDebtValue;
        
        // Assert: Metrics should reflect Aave deployment
        assertGt(totalUsdcInAave, 0, "totalUsdcInAave should be > 0");
        assertEq(totalUsdcAvailable, totalUsdcHeld + totalUsdcInAave, "totalUsdcAvailable should be sum");
    }
    
    /**
     * @notice Tests that getTotalUsdcAvailable includes Aave balance
     * @dev Verifies that total available USDC calculation includes deployed Aave funds
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Deposits USDC, checks total available
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test function
     * @custom:access Public - test function
     * @custom:oracle No oracle dependency
     */
    function test_getTotalUsdcAvailable_includesAave() public {
        // Arrange: Deposit USDC
        uint256 depositAmount = 10_000e6;
        
        vm.startPrank(user);
        usdc.approve(address(userPool), depositAmount);
        
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = depositAmount;
        uint256[] memory minOuts = new uint256[](1);
        minOuts[0] = 0;
        
        userPool.deposit(amounts, minOuts);
        vm.stopPrank();
        
        // Assert: getTotalUsdcAvailable should include Aave balance
        uint256 totalAvailable = vault.getTotalUsdcAvailable();
        assertGt(totalAvailable, 0, "Total available should include Aave balance");
    }
    
    // =============================================================================
    // REDEMPTION FROM AAVE TESTS
    // =============================================================================
    
    /**
     * @notice Tests that QEURO redemption triggers Aave withdrawal
     * @dev Verifies that redeeming QEURO withdraws USDC from Aave when vault balance is insufficient
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Deposits USDC, redeems QEURO, checks Aave balance decrease
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test function
     * @custom:access Public - test function
     * @custom:oracle No oracle dependency
     */
    function test_redeemQEURO_withdrawsFromAave() public {
        // Arrange: Deposit USDC and get QEURO
        uint256 depositAmount = 10_000e6;
        
        vm.startPrank(user);
        usdc.approve(address(userPool), depositAmount);
        
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = depositAmount;
        uint256[] memory minOuts = new uint256[](1);
        minOuts[0] = 0;
        
        userPool.deposit(amounts, minOuts);
        
        // Get user's QEURO balance
        uint256 qeuroBalance = qeuro.balanceOf(user);
        assertGt(qeuroBalance, 0, "User should have QEURO");
        
        // Record Aave balance before redemption
        uint256 aaveBalanceBefore = vault.totalUsdcInAave();
        assertGt(aaveBalanceBefore, 0, "Aave should have USDC");
        
        // Act: Redeem some QEURO (this should trigger Aave withdrawal since vault balance is 0)
        uint256 redeemAmount = qeuroBalance / 2;
        qeuro.approve(address(vault), redeemAmount);
        vault.redeemQEURO(redeemAmount, 0);
        
        vm.stopPrank();
        
        // Assert: Aave balance should have decreased
        uint256 aaveBalanceAfter = vault.totalUsdcInAave();
        assertLt(aaveBalanceAfter, aaveBalanceBefore, "Aave balance should decrease after redemption");
    }
    
    // =============================================================================
    // ACCESS CONTROL TESTS
    // =============================================================================
    
    /**
     * @notice Tests that deployUsdcToAave is restricted to VAULT_OPERATOR_ROLE
     * @dev Verifies that non-operator cannot call deployUsdcToAave
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Attempts unauthorized call
     * @custom:events No events emitted
     * @custom:errors Expects revert on unauthorized access
     * @custom:reentrancy Not protected - test function
     * @custom:access Public - test function
     * @custom:oracle No oracle dependency
     */
    function test_deployUsdcToAave_onlyVaultOperator() public {
        // Arrange: Try to call deployUsdcToAave without VAULT_OPERATOR_ROLE
        vm.startPrank(user);
        
        // Act & Assert: Should revert
        vm.expectRevert();
        vault.deployUsdcToAave(1000e6);
        
        vm.stopPrank();
    }
    
    /**
     * @notice Tests that updateAaveVault is restricted to GOVERNANCE_ROLE
     * @dev Verifies that non-governance cannot update Aave vault address
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Attempts unauthorized call
     * @custom:events No events emitted
     * @custom:errors Expects revert on unauthorized access
     * @custom:reentrancy Not protected - test function
     * @custom:access Public - test function
     * @custom:oracle No oracle dependency
     */
    function test_updateAaveVault_onlyGovernance() public {
        // Arrange: Try to call updateAaveVault without GOVERNANCE_ROLE
        vm.startPrank(user);
        
        // Act & Assert: Should revert
        vm.expectRevert();
        vault.updateAaveVault(address(0x123));
        
        vm.stopPrank();
    }
    
    // =============================================================================
    // EDGE CASE TESTS
    // =============================================================================
    
    /**
     * @notice Tests that updateAaveVault rejects zero address
     * @dev Verifies that setting Aave vault to zero address reverts
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Attempts to set zero address
     * @custom:events No events emitted
     * @custom:errors Expects ZeroAddress error
     * @custom:reentrancy Not protected - test function
     * @custom:access Public - test function
     * @custom:oracle No oracle dependency
     */
    function test_deployUsdcToAave_zeroAddress() public {
        // Arrange: Set AaveVault to zero address
        vm.startPrank(admin);
        
        // This should revert when trying to set zero address
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        vault.updateAaveVault(address(0));
        
        vm.stopPrank();
    }
    
    /**
     * @notice Tests that deposit works when Aave vault is not configured
     * @dev Verifies that deposits succeed even without Aave vault (deployment silently skipped)
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Deploys vault without Aave, deposits USDC, mints QEURO
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test function
     * @custom:access Public - test function
     * @custom:oracle No oracle dependency
     */
    function test_deposit_worksWithoutAaveVault() public {
        // Arrange: Deploy a new vault without AaveVault set
        vm.startPrank(admin);
        
        // Deploy new vault without AaveVault
        QuantillonVault vaultImpl = new QuantillonVault();
        bytes memory vaultData = abi.encodeWithSelector(
            QuantillonVault.initialize.selector,
            admin,
            address(qeuro),
            address(usdc),
            address(oracle),
            address(hedgerPool),
            address(userPool),
            treasury,
            address(feeCollector)
        );
        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(vaultImpl), vaultData);
        QuantillonVault vaultNoAave = QuantillonVault(address(vaultProxy));
        
        // Grant MINTER_ROLE
        qeuro.grantRole(qeuro.MINTER_ROLE(), address(vaultNoAave));
        // Grant TREASURY_ROLE on FeeCollector to allow fee collection
        feeCollector.grantRole(feeCollector.TREASURY_ROLE(), address(vaultNoAave));
        vaultNoAave.setDevMode(true);
        
        vm.stopPrank();
        
        // Act: Deposit should still work (Aave deployment silently skipped)
        vm.startPrank(user);
        usdc.approve(address(vaultNoAave), 1000e6);
        vaultNoAave.mintQEURO(1000e6, 0);
        vm.stopPrank();
        
        // Assert: Minting should succeed, no USDC in Aave
        assertEq(vaultNoAave.totalUsdcInAave(), 0, "No USDC should be in Aave");
        assertGt(vaultNoAave.totalUsdcHeld(), 0, "USDC should be in vault");
    }
}
