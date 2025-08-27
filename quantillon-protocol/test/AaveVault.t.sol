// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {AaveVault} from "../src/core/vaults/AaveVault.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";


/**
 * @title MockUSDC
 * @notice Mock USDC token for testing
 */
contract MockUSDC {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply = 1000000000 * 1e6; // 1B USDC
    
    string public name = "USD Coin";
    string public symbol = "USDC";
    uint8 public decimals = 6;
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

/**
 * @title MockAUSDC
 * @notice Mock aUSDC token for testing
 */
contract MockAUSDC {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    string public name = "Aave USDC";
    string public symbol = "aUSDC";
    uint8 public decimals = 6;
    
    // Function to directly modify balance for testing
    function setBalance(address account, uint256 amount) external {
        balanceOf[account] = amount;
    }
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

/**
 * @title MockAavePool
 * @notice Mock Aave Pool for testing
 */
contract MockAavePool {
    MockUSDC public usdc;
    MockAUSDC public aUSDC;
    uint256 public currentLiquidityRate = 300 * 1e23; // 3% APY in ray
    uint256 public totalSupply = 100000000 * 1e6; // 100M USDC
    uint256 public availableLiquidity = 80000000 * 1e6; // 80M USDC
    
    // Define ReserveData struct for testing
    struct ReserveData {
        uint256 configuration;
        uint128 liquidityIndex;
        uint128 currentLiquidityRate;
        uint128 variableBorrowIndex;
        uint128 currentVariableBorrowRate;
        uint128 currentStableBorrowRate;
        uint40 lastUpdateTimestamp;
        uint16 id;
        address aTokenAddress;
        address stableDebtTokenAddress;
        address variableDebtTokenAddress;
        address interestRateStrategyAddress;
        uint128 accruedToTreasury;
        uint128 unbacked;
        uint128 isolationModeTotalDebt;
    }
    
    constructor(address _usdc, address _aUSDC) {
        usdc = MockUSDC(_usdc);
        aUSDC = MockAUSDC(_aUSDC);
    }
    
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external {
        require(asset == address(usdc), "Invalid asset");
        require(amount > 0, "Amount must be positive");
        
        // Transfer USDC from caller
        usdc.transferFrom(msg.sender, address(this), amount);
        
        // Mint aUSDC to onBehalfOf (1:1 ratio initially)
        aUSDC.mint(onBehalfOf, amount);
    }
    
    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        require(asset == address(usdc), "Invalid asset");
        require(amount > 0, "Amount must be positive");
        
        // Calculate actual amount to withdraw
        uint256 actualAmount = amount;
        if (amount == type(uint256).max) {
            actualAmount = aUSDC.balanceOf(msg.sender);
        }
        
        // Check balance (but don't require transfer approval in mock)
        require(aUSDC.balanceOf(msg.sender) >= actualAmount, "Insufficient aUSDC");
        
        // Simulate burning aUSDC by reducing balance
        aUSDC.setBalance(msg.sender, aUSDC.balanceOf(msg.sender) - actualAmount);
        
        // Transfer USDC to recipient (with some yield if available)
        uint256 yield = actualAmount * 5 / 1000; // 0.5% yield
        uint256 totalToTransfer = actualAmount + yield;
        
        usdc.transfer(to, totalToTransfer);
        return totalToTransfer;
    }
    
    function getReserveData(address asset) external view returns (ReserveData memory) {
        require(asset == address(usdc), "Invalid asset");
        return ReserveData({
            configuration: 0,
            liquidityIndex: 1e27,
            currentLiquidityRate: uint128(currentLiquidityRate),
            variableBorrowIndex: 1e27,
            currentVariableBorrowRate: 500 * 1e23, // 5% borrow rate
            currentStableBorrowRate: 400 * 1e23, // 4% stable rate
            lastUpdateTimestamp: uint40(block.timestamp),
            id: 1,
            aTokenAddress: address(aUSDC),
            stableDebtTokenAddress: address(0),
            variableDebtTokenAddress: address(0),
            interestRateStrategyAddress: address(0),
            accruedToTreasury: 0,
            unbacked: 0,
            isolationModeTotalDebt: 0
        });
    }
    
    function getUserAccountData(address user) external view returns (
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 availableBorrowsBase,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    ) {
        uint256 aUSDCBalance = aUSDC.balanceOf(user);
        return (
            aUSDCBalance, // totalCollateralBase
            0, // totalDebtBase
            aUSDCBalance * 8000 / 10000, // availableBorrowsBase (80% LTV)
            8500, // currentLiquidationThreshold
            8000, // ltv
            100000 // healthFactor (healthy)
        );
    }
    
    function setLiquidityRate(uint256 newRate) external {
        currentLiquidityRate = newRate;
    }
    
    function setAvailableLiquidity(uint256 newLiquidity) external {
        availableLiquidity = newLiquidity;
    }
}

/**
 * @title MockPoolAddressesProvider
 * @notice Mock Aave Pool Addresses Provider for testing
 */
contract MockPoolAddressesProvider {
    address public poolAddress;
    
    constructor(address _poolAddress) {
        poolAddress = _poolAddress;
    }
    
    function getPool() external view returns (address) {
        return poolAddress;
    }
    
    function getPriceOracle() external view returns (address) {
        return address(0x1);
    }
}

/**
 * @title MockRewardsController
 * @notice Mock Aave Rewards Controller for testing
 */
contract MockRewardsController {
    mapping(address => uint256) public pendingRewards;
    
    function claimRewards(
        address[] calldata assets,
        uint256 amount,
        address to
    ) external returns (uint256) {
        uint256 totalClaimed = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 reward = pendingRewards[assets[i]];
            if (reward > 0) {
                totalClaimed += reward;
                pendingRewards[assets[i]] = 0;
            }
        }
        return totalClaimed;
    }
    
    function getUserRewards(
        address[] calldata assets,
        address user
    ) external view returns (uint256[] memory) {
        uint256[] memory rewards = new uint256[](assets.length);
        for (uint256 i = 0; i < assets.length; i++) {
            rewards[i] = pendingRewards[assets[i]];
        }
        return rewards;
    }
    
    function setPendingRewards(address asset, uint256 amount) external {
        pendingRewards[asset] = amount;
    }
}

/**
 * @title MockYieldShift
 * @notice Mock YieldShift contract for testing
 */
contract MockYieldShift {
    uint256 public currentYieldShift = 5000; // 50%
    
    function addYield(uint256 amount, string calldata source) external {
        // Mock implementation
    }
    
    function getCurrentYieldShift() external view returns (uint256) {
        return currentYieldShift;
    }
    
    function setCurrentYieldShift(uint256 newShift) external {
        currentYieldShift = newShift;
    }
}

/**
 * @title AaveVaultTestSuite
 * @notice Comprehensive test suite for the AaveVault contract
 * 
 * @dev This test suite covers:
 *      - Initialization and setup
 *      - Aave integration (supply/withdraw)
 *      - Yield harvesting and distribution
 *      - Risk management
 *      - Emergency functions
 *      - Configuration management
 *      - Historical data tracking
 * 
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract AaveVaultTestSuite is Test {
    using console2 for uint256;

    // =============================================================================
    // TEST ADDRESSES
    // =============================================================================
    
    address public admin = address(0x1);
    address public governance = address(0x2);
    address public vaultManager = address(0x3);
    address public emergencyRole = address(0x4);
    address public user = address(0x5);
    address public recipient = address(0x6);
    address public mockTimelock = address(0x123);

    // =============================================================================
    // TEST CONSTANTS
    // =============================================================================
    
    uint256 public constant MAX_AAVE_EXPOSURE = 50_000_000e6; // 50M USDC
    uint256 public constant HARVEST_THRESHOLD = 1000e6; // 1000 USDC
    uint256 public constant YIELD_FEE = 1000; // 10%
    uint256 public constant REBALANCE_THRESHOLD = 500; // 5%
    uint256 public constant UTILIZATION_LIMIT = 9500; // 95%
    uint256 public constant EMERGENCY_EXIT_THRESHOLD = 110; // 1.1

    // =============================================================================
    // TEST VARIABLES
    // =============================================================================
    
    AaveVault public implementation;
    AaveVault public aaveVault;
    MockUSDC public usdc;
    MockAUSDC public aUSDC;
    MockAavePool public aavePool;
    MockPoolAddressesProvider public aaveProvider;
    MockRewardsController public rewardsController;
    MockYieldShift public yieldShift;

    // =============================================================================
    // SETUP AND TEARDOWN
    // =============================================================================
    
    function setUp() public {
        // Deploy mock contracts
        usdc = new MockUSDC();
        aUSDC = new MockAUSDC();
        aavePool = new MockAavePool(address(usdc), address(aUSDC));
        aaveProvider = new MockPoolAddressesProvider(address(aavePool));
        rewardsController = new MockRewardsController();
        yieldShift = new MockYieldShift();
        
        // Deploy implementation
        implementation = new AaveVault();
        
        // Deploy proxy
        bytes memory initData = abi.encodeWithSelector(
            AaveVault.initialize.selector,
            admin,
            address(usdc),
            address(aaveProvider),
            address(rewardsController),
            address(yieldShift),
            mockTimelock
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        
        aaveVault = AaveVault(address(proxy));
        
        // Grant additional roles for testing
        vm.startPrank(admin);
        aaveVault.grantRole(aaveVault.GOVERNANCE_ROLE(), governance);
        aaveVault.grantRole(aaveVault.VAULT_MANAGER_ROLE(), vaultManager);
        aaveVault.grantRole(aaveVault.EMERGENCY_ROLE(), emergencyRole);
        vm.stopPrank();
        
        // Mint USDC to contracts for testing
        usdc.mint(address(aaveVault), 10000000 * 1e6); // 10M USDC
        usdc.mint(address(aavePool), 100000000 * 1e6); // 100M USDC
        usdc.mint(vaultManager, 1000000 * 1e6); // 1M USDC
        
        // Approve aUSDC transfers for the vault
        aUSDC.approve(address(aaveVault), type(uint256).max);
        
        // Approve aUSDC transfers from vault to aave pool
        vm.prank(address(aaveVault));
        aUSDC.approve(address(aavePool), type(uint256).max);
    }

    // =============================================================================
    // INITIALIZATION TESTS
    // =============================================================================
    
    /**
     * @notice Test successful initialization
     * @dev Verifies proper contract setup and configuration
     */
    function test_Initialization_Success() public {
        // Check roles
        assertTrue(aaveVault.hasRole(aaveVault.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(aaveVault.hasRole(aaveVault.GOVERNANCE_ROLE(), admin));
        assertTrue(aaveVault.hasRole(aaveVault.VAULT_MANAGER_ROLE(), admin));
        assertTrue(aaveVault.hasRole(aaveVault.EMERGENCY_ROLE(), admin));

        
        // Check contract addresses
        assertEq(address(aaveVault.usdc()), address(usdc));
        assertEq(address(aaveVault.aUSDC()), address(aUSDC));
        assertEq(address(aaveVault.aavePool()), address(aavePool));
        assertEq(address(aaveVault.aaveProvider()), address(aaveProvider));
        assertEq(address(aaveVault.rewardsController()), address(rewardsController));
        assertEq(address(aaveVault.yieldShift()), address(yieldShift));
        
        // Check default configuration
        (address aavePool_, address aUSDC_, uint256 harvestThreshold_, uint256 yieldFee_, uint256 maxExposure_) = aaveVault.getAaveConfig();
        assertEq(aavePool_, address(aavePool));
        assertEq(aUSDC_, address(aUSDC));
        assertEq(harvestThreshold_, HARVEST_THRESHOLD);
        assertEq(yieldFee_, YIELD_FEE);
        assertEq(maxExposure_, MAX_AAVE_EXPOSURE);
        
        // Check initial state
        assertEq(aaveVault.principalDeposited(), 0);
        assertEq(aaveVault.totalYieldHarvested(), 0);
        assertEq(aaveVault.totalFeesCollected(), 0);
        assertFalse(aaveVault.emergencyMode());
    }
    
    /**
     * @notice Test initialization with zero admin address should revert
     * @dev Verifies zero address validation
     */
    function test_Initialization_ZeroAdmin_Revert() public {
        AaveVault newImplementation = new AaveVault();
        
        bytes memory initData = abi.encodeWithSelector(
            AaveVault.initialize.selector,
            address(0),
            address(usdc),
            address(aaveProvider),
            address(rewardsController),
            address(yieldShift),
            mockTimelock
        );
        
        vm.expectRevert("AaveVault: Admin cannot be zero");
        new ERC1967Proxy(address(newImplementation), initData);
    }
    
    /**
     * @notice Test initialization with zero USDC address should revert
     * @dev Verifies zero address validation
     */
    function test_Initialization_ZeroUsdc_Revert() public {
        AaveVault newImplementation = new AaveVault();
        
        bytes memory initData = abi.encodeWithSelector(
            AaveVault.initialize.selector,
            admin,
            address(0),
            address(aaveProvider),
            address(rewardsController),
            address(yieldShift),
            mockTimelock
        );
        
        vm.expectRevert("AaveVault: USDC cannot be zero");
        new ERC1967Proxy(address(newImplementation), initData);
    }

    // =============================================================================
    // AAVE INTEGRATION TESTS
    // =============================================================================
    
    /**
     * @notice Test deploying USDC to Aave
     * @dev Verifies Aave supply functionality
     */
    function test_AaveIntegration_DeployToAave() public {
        uint256 deployAmount = 1000000 * 1e6; // 1M USDC
        
        // Record initial state
        uint256 initialAaveBalance = aaveVault.getAaveBalance();
        uint256 initialPrincipal = aaveVault.principalDeposited();
        
        // Approve USDC transfer
        vm.prank(vaultManager);
        usdc.approve(address(aaveVault), deployAmount);
        
        // Deploy to Aave
        vm.prank(vaultManager);
        uint256 aTokensReceived = aaveVault.deployToAave(deployAmount);
        
        // Check that deployment was successful
        assertGt(aTokensReceived, 0);
        assertEq(aaveVault.getAaveBalance(), initialAaveBalance + aTokensReceived);
        assertEq(aaveVault.principalDeposited(), initialPrincipal + deployAmount);
    }
    
    /**
     * @notice Test deploying USDC to Aave by non-vault manager should revert
     * @dev Verifies access control
     */
    function test_AaveIntegration_DeployToAaveUnauthorized_Revert() public {
        uint256 deployAmount = 1000000 * 1e6;
        
        vm.prank(user);
        usdc.approve(address(aaveVault), deployAmount);
        
        vm.prank(user);
        vm.expectRevert();
        aaveVault.deployToAave(deployAmount);
    }
    
    /**
     * @notice Test deploying zero amount should revert
     * @dev Verifies parameter validation
     */
    function test_AaveIntegration_DeployToAaveZeroAmount_Revert() public {
        vm.prank(vaultManager);
        vm.expectRevert("AaveVault: Amount must be positive");
        aaveVault.deployToAave(0);
    }
    
    /**
     * @notice Test deploying amount exceeding max exposure should revert
     * @dev Verifies exposure limits
     */
    function test_AaveIntegration_DeployToAaveExceedsMaxExposure_Revert() public {
        uint256 excessiveAmount = MAX_AAVE_EXPOSURE + 1;
        
        vm.prank(vaultManager);
        usdc.approve(address(aaveVault), excessiveAmount);
        
        vm.prank(vaultManager);
        vm.expectRevert("AaveVault: Would exceed max exposure");
        aaveVault.deployToAave(excessiveAmount);
    }
    
    /**
     * @notice Test withdrawing from Aave
     * @dev Verifies Aave withdrawal functionality
     */
    function test_AaveIntegration_WithdrawFromAave() public {
        // First deploy some USDC to Aave
        uint256 deployAmount = 1000000 * 1e6;
        vm.prank(vaultManager);
        usdc.approve(address(aaveVault), deployAmount);
        vm.prank(vaultManager);
        aaveVault.deployToAave(deployAmount);
        
        // Record initial state
        uint256 initialAaveBalance = aaveVault.getAaveBalance();
        uint256 initialPrincipal = aaveVault.principalDeposited();
        
        // Withdraw a small amount to avoid breaching minimum balance
        uint256 withdrawAmount = 200000 * 1e6; // 200K USDC (small enough to not breach minimum)
        vm.prank(vaultManager);
        uint256 usdcWithdrawn = aaveVault.withdrawFromAave(withdrawAmount);
        
        // Check that withdrawal was successful
        assertGt(usdcWithdrawn, 0);
        assertLt(aaveVault.getAaveBalance(), initialAaveBalance);
        assertLt(aaveVault.principalDeposited(), initialPrincipal);
    }
    
    /**
     * @notice Test withdrawing all from Aave
     * @dev Verifies max withdrawal functionality
     */
    function test_AaveIntegration_WithdrawAllFromAave() public {
        // First deploy some USDC to Aave
        uint256 deployAmount = 1000000 * 1e6;
        vm.prank(vaultManager);
        usdc.approve(address(aaveVault), deployAmount);
        vm.prank(vaultManager);
        aaveVault.deployToAave(deployAmount);
        
        // Enable emergency mode to bypass minimum balance check
        vm.prank(emergencyRole);
        aaveVault.toggleEmergencyMode(true, "Test withdrawal");
        
        // Record initial state
        uint256 initialAaveBalance = aaveVault.getAaveBalance();
        
        // Withdraw all from Aave
        vm.prank(vaultManager);
        uint256 usdcWithdrawn = aaveVault.withdrawFromAave(type(uint256).max);
        
        // Check that withdrawal was successful
        assertGt(usdcWithdrawn, 0);
        assertEq(aaveVault.getAaveBalance(), 0);
        
        // Disable emergency mode
        vm.prank(emergencyRole);
        aaveVault.toggleEmergencyMode(false, "Test complete");
    }

    // =============================================================================
    // YIELD MANAGEMENT TESTS
    // =============================================================================
    
    /**
     * @notice Test harvesting Aave yield
     * @dev Verifies yield harvesting functionality
     */
    function test_YieldManagement_HarvestAaveYield() public {
        // First deploy USDC to Aave to generate yield
        uint256 deployAmount = 1000000 * 1e6;
        vm.prank(vaultManager);
        usdc.approve(address(aaveVault), deployAmount);
        vm.prank(vaultManager);
        aaveVault.deployToAave(deployAmount);
        
        // Simulate yield generation by minting aUSDC directly
        aUSDC.mint(address(aaveVault), 5000 * 1e6); // 5K USDC yield
        
        // Record initial state
        uint256 initialYieldHarvested = aaveVault.totalYieldHarvested();
        uint256 initialFeesCollected = aaveVault.totalFeesCollected();
        
        // Harvest yield
        vm.prank(vaultManager);
        uint256 yieldHarvested = aaveVault.harvestAaveYield();
        
        // Check that yield was harvested
        assertGt(yieldHarvested, 0);
        assertGt(aaveVault.totalYieldHarvested(), initialYieldHarvested);
        assertGt(aaveVault.totalFeesCollected(), initialFeesCollected);
    }
    
    /**
     * @notice Test harvesting yield below threshold should revert
     * @dev Verifies harvest threshold validation
     */
    function test_YieldManagement_HarvestYieldBelowThreshold_Revert() public {
        // Deploy small amount to generate minimal yield
        uint256 deployAmount = 100000 * 1e6; // 100K USDC
        vm.prank(vaultManager);
        usdc.approve(address(aaveVault), deployAmount);
        vm.prank(vaultManager);
        aaveVault.deployToAave(deployAmount);
        
        // Add small yield (below threshold)
        aUSDC.mint(address(aaveVault), 500 * 1e6); // 500 USDC yield (below 1000 threshold)
        
        vm.prank(vaultManager);
        vm.expectRevert("AaveVault: Yield below threshold");
        aaveVault.harvestAaveYield();
    }
    
    /**
     * @notice Test getting available yield
     * @dev Verifies yield calculation
     */
    function test_YieldManagement_GetAvailableYield() public {
        // Deploy USDC to Aave
        uint256 deployAmount = 1000000 * 1e6;
        vm.prank(vaultManager);
        usdc.approve(address(aaveVault), deployAmount);
        vm.prank(vaultManager);
        aaveVault.deployToAave(deployAmount);
        
        // Check initial yield (should be 0)
        assertEq(aaveVault.getAvailableYield(), 0);
        
        // Add yield
        aUSDC.mint(address(aaveVault), 5000 * 1e6);
        
        // Check available yield
        assertEq(aaveVault.getAvailableYield(), 5000 * 1e6);
    }
    
    /**
     * @notice Test yield distribution breakdown
     * @dev Verifies yield allocation calculations
     */
    function test_YieldManagement_GetYieldDistribution() public {
        // Deploy USDC and add yield
        uint256 deployAmount = 1000000 * 1e6;
        vm.prank(vaultManager);
        usdc.approve(address(aaveVault), deployAmount);
        vm.prank(vaultManager);
        aaveVault.deployToAave(deployAmount);
        
        aUSDC.mint(address(aaveVault), 10000 * 1e6); // 10K USDC yield
        
        // Get yield distribution
        (uint256 protocolYield, uint256 userYield, uint256 hedgerYield) = aaveVault.getYieldDistribution();
        
        // Check calculations
        assertEq(protocolYield, 1000 * 1e6); // 10% of 10K = 1K
        assertEq(userYield, 4500 * 1e6); // 50% of 9K = 4.5K
        assertEq(hedgerYield, 4500 * 1e6); // 50% of 9K = 4.5K
    }

    // =============================================================================
    // AAVE POSITION TESTS
    // =============================================================================
    
    /**
     * @notice Test getting Aave balance
     * @dev Verifies balance tracking
     */
    function test_AavePosition_GetAaveBalance() public {
        // Deploy USDC to Aave
        uint256 deployAmount = 1000000 * 1e6;
        vm.prank(vaultManager);
        usdc.approve(address(aaveVault), deployAmount);
        vm.prank(vaultManager);
        aaveVault.deployToAave(deployAmount);
        
        // Check Aave balance
        assertEq(aaveVault.getAaveBalance(), deployAmount);
    }
    
    /**
     * @notice Test getting accrued interest
     * @dev Verifies interest calculation
     */
    function test_AavePosition_GetAccruedInterest() public {
        // Deploy USDC to Aave
        uint256 deployAmount = 1000000 * 1e6;
        vm.prank(vaultManager);
        usdc.approve(address(aaveVault), deployAmount);
        vm.prank(vaultManager);
        aaveVault.deployToAave(deployAmount);
        
        // Add yield
        aUSDC.mint(address(aaveVault), 5000 * 1e6);
        
        // Check accrued interest
        assertEq(aaveVault.getAccruedInterest(), 5000 * 1e6);
    }
    
    /**
     * @notice Test getting Aave APY
     * @dev Verifies APY calculation
     */
    function test_AavePosition_GetAaveAPY() public {
        uint256 aaveAPY = aaveVault.getAaveAPY();
        
        // Check that APY is reasonable (should be around 3% based on mock)
        assertGe(aaveAPY, 200); // At least 2%
        assertLe(aaveAPY, 500); // At most 5%
    }
    
    /**
     * @notice Test getting Aave position details
     * @dev Verifies position tracking
     */
    function test_AavePosition_GetAavePositionDetails() public {
        // Deploy USDC to Aave
        uint256 deployAmount = 1000000 * 1e6;
        vm.prank(vaultManager);
        usdc.approve(address(aaveVault), deployAmount);
        vm.prank(vaultManager);
        aaveVault.deployToAave(deployAmount);
        
        // Get position details
        (uint256 principalDeposited_, uint256 currentBalance, uint256 aTokenBalance, uint256 lastUpdateTime) = aaveVault.getAavePositionDetails();
        
        // Check details
        assertEq(principalDeposited_, deployAmount);
        assertEq(currentBalance, deployAmount);
        assertEq(aTokenBalance, deployAmount);
        assertGt(lastUpdateTime, 0);
    }

    // =============================================================================
    // AAVE MARKET TESTS
    // =============================================================================
    
    /**
     * @notice Test getting Aave market data
     * @dev Verifies market data retrieval
     */
    function test_AaveMarket_GetAaveMarketData() public {
        (uint256 supplyRate, uint256 utilizationRate, uint256 totalSupply, uint256 availableLiquidity) = aaveVault.getAaveMarketData();
        
        // Check market data
        assertGe(supplyRate, 0);
        assertLe(supplyRate, 1000); // Should be reasonable rate
        assertGe(utilizationRate, 0);
        assertLe(utilizationRate, 10000); // Should be percentage
        assertGt(totalSupply, 0);
        assertGt(availableLiquidity, 0);
    }
    
    /**
     * @notice Test checking Aave health
     * @dev Verifies health monitoring
     */
    function test_AaveMarket_CheckAaveHealth() public {
        (bool isHealthy, bool pauseStatus, uint256 lastUpdate) = aaveVault.checkAaveHealth();
        
        // Check health status
        assertTrue(isHealthy);
        assertFalse(pauseStatus);
        assertGt(lastUpdate, 0);
    }

    // =============================================================================
    // AUTOMATIC STRATEGIES TESTS
    // =============================================================================
    
    /**
     * @notice Test auto rebalancing
     * @dev Verifies rebalancing logic
     */
    function test_AutomaticStrategies_AutoRebalance() public {
        // Deploy USDC to Aave
        uint256 deployAmount = 1000000 * 1e6;
        vm.prank(vaultManager);
        usdc.approve(address(aaveVault), deployAmount);
        vm.prank(vaultManager);
        aaveVault.deployToAave(deployAmount);
        
        // Test auto rebalancing
        vm.prank(vaultManager);
        (bool rebalanced, uint256 newAllocation) = aaveVault.autoRebalance();
        
        // Check rebalancing result
        assertGe(newAllocation, 0);
        assertLe(newAllocation, 10000);
    }
    
    /**
     * @notice Test calculating optimal allocation
     * @dev Verifies allocation optimization
     */
    function test_AutomaticStrategies_CalculateOptimalAllocation() public {
        (uint256 optimalAllocation, uint256 expectedYield) = aaveVault.calculateOptimalAllocation();
        
        // Check optimal allocation
        assertGe(optimalAllocation, 0);
        assertLe(optimalAllocation, 10000);
        assertGe(expectedYield, 0);
    }

    // =============================================================================
    // RISK MANAGEMENT TESTS
    // =============================================================================
    
    /**
     * @notice Test setting max Aave exposure
     * @dev Verifies exposure limit management
     */
    function test_RiskManagement_SetMaxAaveExposure() public {
        uint256 newMaxExposure = 75000000 * 1e6; // 75M USDC
        
        vm.prank(governance);
        aaveVault.setMaxAaveExposure(newMaxExposure);
        
        // Check that max exposure was updated
        (,,,, uint256 maxExposure_) = aaveVault.getAaveConfig();
        assertEq(maxExposure_, newMaxExposure);
    }
    
    /**
     * @notice Test setting max exposure too high should revert
     * @dev Verifies exposure limit validation
     */
    function test_RiskManagement_SetMaxExposureTooHigh_Revert() public {
        uint256 excessiveExposure = 2000000000 * 1e6; // 2B USDC (exceeds 1B limit)
        
        vm.prank(governance);
        vm.expectRevert("AaveVault: Max exposure too high");
        aaveVault.setMaxAaveExposure(excessiveExposure);
    }
    
    /**
     * @notice Test emergency withdrawal from Aave
     * @dev Verifies emergency functionality
     */
    function test_RiskManagement_EmergencyWithdrawFromAave() public {
        // First deploy USDC to Aave
        uint256 deployAmount = 1000000 * 1e6;
        vm.prank(vaultManager);
        usdc.approve(address(aaveVault), deployAmount);
        vm.prank(vaultManager);
        aaveVault.deployToAave(deployAmount);
        
        // Record initial state
        uint256 initialAaveBalance = aaveVault.getAaveBalance();
        
        // Emergency withdrawal
        vm.prank(emergencyRole);
        uint256 amountWithdrawn = aaveVault.emergencyWithdrawFromAave();
        
        // Check emergency withdrawal
        assertGt(amountWithdrawn, 0);
        assertEq(aaveVault.getAaveBalance(), 0);
        assertTrue(aaveVault.emergencyMode());
        
        // Reset emergency mode
        vm.prank(emergencyRole);
        aaveVault.toggleEmergencyMode(false, "Test complete");
    }
    
    /**
     * @notice Test getting risk metrics
     * @dev Verifies risk assessment
     */
    function test_RiskManagement_GetRiskMetrics() public {
        // Deploy USDC to Aave
        uint256 deployAmount = 1000000 * 1e6;
        vm.prank(vaultManager);
        usdc.approve(address(aaveVault), deployAmount);
        vm.prank(vaultManager);
        aaveVault.deployToAave(deployAmount);
        
        (uint256 exposureRatio, uint256 concentrationRisk, uint256 liquidityRisk) = aaveVault.getRiskMetrics();
        
        // Check risk metrics
        assertGe(exposureRatio, 0);
        assertLe(exposureRatio, 10000);
        assertGe(concentrationRisk, 1);
        assertLe(concentrationRisk, 3);
        assertGe(liquidityRisk, 1);
        assertLe(liquidityRisk, 3);
    }

    // =============================================================================
    // CONFIGURATION TESTS
    // =============================================================================
    
    /**
     * @notice Test updating Aave parameters
     * @dev Verifies parameter management
     */
    function test_Configuration_UpdateAaveParameters() public {
        uint256 newHarvestThreshold = 2000 * 1e6; // 2K USDC
        uint256 newYieldFee = 1500; // 15%
        uint256 newRebalanceThreshold = 1000; // 10%
        
        vm.prank(governance);
        aaveVault.updateAaveParameters(newHarvestThreshold, newYieldFee, newRebalanceThreshold);
        
        // Check that parameters were updated
        (,, uint256 harvestThreshold_, uint256 yieldFee_,) = aaveVault.getAaveConfig();
        assertEq(harvestThreshold_, newHarvestThreshold);
        assertEq(yieldFee_, newYieldFee);
    }
    
    /**
     * @notice Test updating parameters with invalid values should revert
     * @dev Verifies parameter validation
     */
    function test_Configuration_UpdateParametersInvalid_Revert() public {
        // Test yield fee too high
        vm.prank(governance);
        vm.expectRevert("AaveVault: Yield fee too high");
        aaveVault.updateAaveParameters(1000 * 1e6, 2500, 500); // 25% fee
        
        // Test rebalance threshold too high
        vm.prank(governance);
        vm.expectRevert("AaveVault: Rebalance threshold too high");
        aaveVault.updateAaveParameters(1000 * 1e6, 1000, 2500); // 25% threshold
    }
    
    /**
     * @notice Test toggling emergency mode
     * @dev Verifies emergency mode management
     */
    function test_Configuration_ToggleEmergencyMode() public {
        vm.prank(emergencyRole);
        aaveVault.toggleEmergencyMode(true, "Test emergency");
        
        assertTrue(aaveVault.emergencyMode());
        
        vm.prank(emergencyRole);
        aaveVault.toggleEmergencyMode(false, "Test recovery");
        
        assertFalse(aaveVault.emergencyMode());
    }

    // =============================================================================
    // HISTORICAL DATA TESTS
    // =============================================================================
    


    // =============================================================================
    // EMERGENCY AND ADMIN TESTS
    // =============================================================================
    
    /**
     * @notice Test pausing and unpausing the vault
     * @dev Verifies pause functionality
     */
    function test_Emergency_PauseAndUnpause() public {
        // Pause vault
        vm.prank(emergencyRole);
        aaveVault.pause();
        
        assertTrue(aaveVault.paused());
        
        // Unpause vault
        vm.prank(emergencyRole);
        aaveVault.unpause();
        
        assertFalse(aaveVault.paused());
    }
    
    /**
     * @notice Test pausing by non-emergency role should revert
     * @dev Verifies access control
     */
    function test_Emergency_PauseUnauthorized_Revert() public {
        vm.prank(user);
        vm.expectRevert();
        aaveVault.pause();
    }
    
    /**
     * @notice Test recovering tokens
     * @dev Verifies token recovery functionality
     */
    function test_Emergency_RecoverToken() public {
        // Create a mock token
        MockUSDC mockToken = new MockUSDC();
        mockToken.mint(address(aaveVault), 1000 * 1e6);
        
        uint256 initialBalance = mockToken.balanceOf(recipient);
        
        // Recover token
        vm.prank(admin);
        aaveVault.recoverToken(address(mockToken), recipient, 1000 * 1e6);
        
        // Check that token was recovered
        assertEq(mockToken.balanceOf(recipient), initialBalance + 1000 * 1e6);
    }
    
    /**
     * @notice Test recovering USDC should revert
     * @dev Verifies USDC protection
     */
    function test_Emergency_RecoverUsdc_Revert() public {
        vm.prank(admin);
        vm.expectRevert("AaveVault: Cannot recover USDC");
        aaveVault.recoverToken(address(usdc), recipient, 1000 * 1e6);
    }
    
    /**
     * @notice Test recovering aUSDC should revert
     * @dev Verifies aUSDC protection
     */
    function test_Emergency_RecoverAUsdc_Revert() public {
        vm.prank(admin);
        vm.expectRevert("AaveVault: Cannot recover aUSDC");
        aaveVault.recoverToken(address(aUSDC), recipient, 1000 * 1e6);
    }

    // =============================================================================
    // INTEGRATION TESTS
    // =============================================================================
    
    /**
     * @notice Test complete Aave vault workflow
     * @dev Verifies end-to-end functionality
     */
    function test_Integration_CompleteAaveWorkflow() public {
        // 1. Deploy USDC to Aave
        uint256 deployAmount = 1000000 * 1e6;
        vm.prank(vaultManager);
        usdc.approve(address(aaveVault), deployAmount);
        vm.prank(vaultManager);
        uint256 aTokensReceived = aaveVault.deployToAave(deployAmount);
        
        assertGt(aTokensReceived, 0);
        assertEq(aaveVault.getAaveBalance(), aTokensReceived);
        
        // 2. Generate yield
        aUSDC.mint(address(aaveVault), 5000 * 1e6);
        
        // 3. Harvest yield
        vm.prank(vaultManager);
        uint256 yieldHarvested = aaveVault.harvestAaveYield();
        
        assertGt(yieldHarvested, 0);
        assertGt(aaveVault.totalYieldHarvested(), 0);
        
        // 4. Check position details
        (uint256 principalDeposited_, uint256 currentBalance, uint256 aTokenBalance,) = aaveVault.getAavePositionDetails();
        
        assertEq(principalDeposited_, deployAmount);
        assertGt(currentBalance, 0);
        assertEq(aTokenBalance, currentBalance);
        
        // 5. Check risk metrics
        (uint256 exposureRatio, uint256 concentrationRisk, uint256 liquidityRisk) = aaveVault.getRiskMetrics();
        
        assertGt(exposureRatio, 0);
        assertLe(concentrationRisk, 3);
        assertLe(liquidityRisk, 3);
    }
    
    /**
     * @notice Test Aave rewards claiming
     * @dev Verifies rewards functionality
     */
    function test_Integration_ClaimAaveRewards() public {
        // Set up pending rewards
        rewardsController.setPendingRewards(address(aUSDC), 1000 * 1e6);
        
        // Claim rewards
        vm.prank(vaultManager);
        uint256 rewardsClaimed = aaveVault.claimAaveRewards();
        
        // Check that rewards were claimed
        assertGt(rewardsClaimed, 0);
    }

    // =============================================================================
    // MISSING FUNCTION TESTS - Ensuring 100% coverage
    // =============================================================================

    /**
     * @notice Test get Aave configuration
     * @dev Verifies that Aave configuration can be retrieved
     */
    function test_View_GetAaveConfig() public {
        (address aavePool_, address aUSDC_, uint256 harvestThreshold_, uint256 yieldFee_, uint256 maxExposure_) = aaveVault.getAaveConfig();
        
        assertEq(aavePool_, address(aavePool));
        assertEq(aUSDC_, address(aUSDC));
        assertGt(harvestThreshold_, 0);
        assertGt(yieldFee_, 0);
        assertGt(maxExposure_, 0);
    }

    // =============================================================================
    // RECOVERY FUNCTION TESTS
    // =============================================================================

    /**
     * @notice Test recovering ETH
     * @dev Verifies that admin can recover accidentally sent ETH
     */
    function test_Recovery_RecoverETH() public {
        uint256 recoveryAmount = 1 ether;
        uint256 initialBalance = admin.balance;
        
        // Send ETH to the contract
        vm.deal(address(aaveVault), recoveryAmount);
        
        // Admin recovers ETH
        vm.prank(admin);
        aaveVault.recoverETH(payable(admin));
        
        uint256 finalBalance = admin.balance;
        assertEq(finalBalance, initialBalance + recoveryAmount);
    }

    /**
     * @notice Test recovering ETH by non-admin (should revert)
     * @dev Verifies that only admin can recover ETH
     */
    function test_Recovery_RecoverETHByNonAdmin_Revert() public {
        vm.deal(address(aaveVault), 1 ether);
        
        vm.prank(vaultManager);
        vm.expectRevert();
        aaveVault.recoverETH(payable(vaultManager));
    }

    /**
     * @notice Test recovering ETH to zero address (should revert)
     * @dev Verifies that ETH cannot be recovered to zero address
     */
    function test_Recovery_RecoverETHToZeroAddress_Revert() public {
        vm.deal(address(aaveVault), 1 ether);
        
        vm.prank(admin);
        vm.expectRevert("AaveVault: Cannot send to zero address");
        aaveVault.recoverETH(payable(address(0)));
    }

    /**
     * @notice Test recovering ETH when contract has no ETH (should revert)
     * @dev Verifies that recovery fails when there's no ETH to recover
     */
    function test_Recovery_RecoverETHNoBalance_Revert() public {
        vm.prank(admin);
        vm.expectRevert("AaveVault: No ETH to recover");
        aaveVault.recoverETH(payable(admin));
    }
}
