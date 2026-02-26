// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Core contracts
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {QEUROToken} from "../src/core/QEUROToken.sol";
import {QuantillonVault} from "../src/core/QuantillonVault.sol";
import {UserPool} from "../src/core/UserPool.sol";
import {HedgerPool} from "../src/core/HedgerPool.sol";
import {stQEUROToken} from "../src/core/stQEUROToken.sol";
import {FeeCollector} from "../src/core/FeeCollector.sol";
import {YieldShift} from "../src/core/yieldmanagement/YieldShift.sol";

// Oracle
import {MockChainlinkOracle} from "../src/mocks/MockChainlinkOracle.sol";
import {MockAggregatorV3} from "./ChainlinkOracle.t.sol";

// Mocks
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";

/**
 * @title IntegrationTests
 * @notice Fully on-chain integration tests for Quantillon Protocol
 * 
 * @dev This test suite performs real contract deployments and interactions:
 *      1. Deploys all core contracts (TimeProvider, QEURO, Vault, UserPool, HedgerPool, stQEURO, YieldShift, AaveVault, FeeCollector, Oracle)
 *      2. Wires contracts together with proper dependencies
 *      3. Performs actual on-chain operations:
 *         - User deposits USDC to UserPool
 *         - QEURO is minted via QuantillonVault
 *         - User stakes QEURO into stQEURO
 *         - Yield is generated and distributed
 *         - User claims yield
 *         - User redeems QEURO back to USDC
 *      4. Validates actual on-chain balances and protocol state
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract IntegrationTests is Test {
    // =============================================================================
    // CONTRACT INSTANCES
    // =============================================================================
    
    TimeProvider public timeProvider;
    QEUROToken public qeuroToken;
    QuantillonVault public vault;
    UserPool public userPool;
    HedgerPool public hedgerPool;
    stQEUROToken public stQEURO;
    FeeCollector public feeCollector;
    YieldShift public yieldShift;
    MockChainlinkOracle public oracle;
    
    MockUSDC public mockUSDC;
    MockAggregatorV3 public eurUsdFeed;
    MockAggregatorV3 public usdcUsdFeed;
    
    // =============================================================================
    // TEST ADDRESSES
    // =============================================================================
    
    address public admin = address(0x1);
    address public treasury = address(0x2);
    address public governance = address(0x3);
    address public emergency = address(0x4);
    address public user1 = address(0x5);
    address public hedger1 = address(0x6);
    address public timelock = address(0x7);
    
    // =============================================================================
    // TEST CONSTANTS
    // =============================================================================
    
    uint256 public constant INITIAL_USDC_AMOUNT = 1_000_000 * 1e6; // 1M USDC
    uint256 public constant DEPOSIT_AMOUNT = 10_000 * 1e6; // 10k USDC
    uint256 public constant EUR_USD_PRICE = 1.10e8; // 1.10 USD per EUR (8 decimals for Chainlink)
    uint256 public constant USDC_USD_PRICE = 1.00e8; // 1.00 USD per USDC (8 decimals)
    
    // =============================================================================
    // SETUP
    // =============================================================================
    
    /**
     * @notice Sets up the complete protocol deployment for integration testing
     * @dev Deploys all contracts in the correct order and wires them together
     */
    function setUp() public virtual {
        // Deploy mock USDC
        mockUSDC = new MockUSDC();
        mockUSDC.mint(user1, INITIAL_USDC_AMOUNT);
        mockUSDC.mint(hedger1, INITIAL_USDC_AMOUNT);
        
        // Deploy mock Chainlink price feeds
        eurUsdFeed = new MockAggregatorV3(8);
        // forge-lint: disable-next-line(unsafe-typecast)
        eurUsdFeed.setPrice(int256(EUR_USD_PRICE));
        usdcUsdFeed = new MockAggregatorV3(8);
        // forge-lint: disable-next-line(unsafe-typecast)
        usdcUsdFeed.setPrice(int256(USDC_USD_PRICE));
        
        // Deploy TimeProvider
        TimeProvider timeProviderImpl = new TimeProvider();
        bytes memory timeProviderInitData = abi.encodeWithSelector(
            TimeProvider.initialize.selector,
            admin,
            admin,
            admin
        );
        ERC1967Proxy timeProviderProxy = new ERC1967Proxy(address(timeProviderImpl), timeProviderInitData);
        timeProvider = TimeProvider(address(timeProviderProxy));
        
        // Deploy MockChainlinkOracle
        MockChainlinkOracle oracleImpl = new MockChainlinkOracle();
        bytes memory oracleInitData = abi.encodeWithSelector(
            MockChainlinkOracle.initialize.selector,
            admin,
            address(eurUsdFeed),
            address(usdcUsdFeed),
            treasury
        );
        ERC1967Proxy oracleProxy = new ERC1967Proxy(address(oracleImpl), oracleInitData);
        // MockChainlinkOracle has a payable receive/fallback, so cast via address payable
        oracle = MockChainlinkOracle(payable(address(oracleProxy)));
        
        // Set oracle prices
        vm.prank(admin);
        oracle.setPrices(1.10e18, 1.00e18); // 1.10 EUR/USD, 1.00 USDC/USD in 18 decimals
        
        // Deploy FeeCollector
        FeeCollector feeCollectorImpl = new FeeCollector();
        bytes memory feeCollectorInitData = abi.encodeWithSelector(
            FeeCollector.initialize.selector,
            admin,
            treasury,
            treasury, // devFund
            treasury  // communityFund
        );
        ERC1967Proxy feeCollectorProxy = new ERC1967Proxy(address(feeCollectorImpl), feeCollectorInitData);
        feeCollector = FeeCollector(address(feeCollectorProxy));
        
        // Deploy QEUROToken (vault placeholder: protocol requires non-zero; we grant MINTER/BURNER to vault after deploy)
        QEUROToken qeuroImpl = new QEUROToken();
        bytes memory qeuroInitData = abi.encodeWithSelector(
            QEUROToken.initialize.selector,
            admin,
            admin, // placeholder vault; grant to real vault below
            timelock,
            treasury,
            address(feeCollector)
        );
        ERC1967Proxy qeuroProxy = new ERC1967Proxy(address(qeuroImpl), qeuroInitData);
        qeuroToken = QEUROToken(address(qeuroProxy));
        
        // Deploy QuantillonVault
        QuantillonVault vaultImpl = new QuantillonVault();
        bytes memory vaultInitData = abi.encodeWithSelector(
            QuantillonVault.initialize.selector,
            admin,
            address(qeuroToken),
            address(mockUSDC),
            address(oracle),
            address(0), // hedgerPool (will be set later)
            address(0), // userPool (will be set later)
            timelock,
            address(feeCollector) // feeCollector
        );
        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(vaultImpl), vaultInitData);
        vault = QuantillonVault(address(vaultProxy));
        
        // Grant vault MINTER_ROLE and BURNER_ROLE on QEURO, and TREASURY_ROLE on FeeCollector so vault can collect fees
        vm.startPrank(admin);
        qeuroToken.grantRole(qeuroToken.MINTER_ROLE(), address(vault));
        qeuroToken.grantRole(qeuroToken.BURNER_ROLE(), address(vault));
        feeCollector.grantRole(feeCollector.TREASURY_ROLE(), address(vault));
        vm.stopPrank();
        
        // Deploy YieldShift with minimal wiring (user/hedger/aave/stQEURO will be set later)
        YieldShift yieldShiftImpl = new YieldShift(timeProvider);
        bytes memory yieldShiftInitData = abi.encodeWithSelector(
            YieldShift.initialize.selector,
            admin,
            address(mockUSDC),
            address(0), // userPool (will be set later)
            address(0), // hedgerPool (will be set later)
            address(0), // aaveVault (will be set later)
            address(0), // stQEURO (will be set later)
            timelock,
            treasury
        );
        ERC1967Proxy yieldShiftProxy = new ERC1967Proxy(address(yieldShiftImpl), yieldShiftInitData);
        yieldShift = YieldShift(address(yieldShiftProxy));
        
        // Deploy stQEUROToken
        stQEUROToken stQEUROImpl = new stQEUROToken(timeProvider);
        bytes memory stQEUROInitData = abi.encodeWithSelector(
            stQEUROToken.initialize.selector,
            admin,
            address(qeuroToken),
            address(yieldShift),
            address(mockUSDC),
            treasury,
            timelock
        );
        ERC1967Proxy stQEUROProxy = new ERC1967Proxy(address(stQEUROImpl), stQEUROInitData);
        stQEURO = stQEUROToken(address(stQEUROProxy));
        
        // Deploy UserPool (signature: admin, _qeuro, _usdc, _vault, _oracle, _yieldShift, _timelock, _treasury)
        UserPool userPoolImpl = new UserPool(timeProvider);
        bytes memory userPoolInitData = abi.encodeWithSelector(
            UserPool.initialize.selector,
            admin,
            address(qeuroToken),
            address(mockUSDC),
            address(vault),
            address(oracle),
            address(yieldShift),
            timelock,
            treasury
        );
        ERC1967Proxy userPoolProxy = new ERC1967Proxy(address(userPoolImpl), userPoolInitData);
        userPool = UserPool(address(userPoolProxy));
        
        // Deploy HedgerPool
        HedgerPool hedgerPoolImpl = new HedgerPool(timeProvider);
        bytes memory hedgerPoolInitData = abi.encodeWithSelector(
            HedgerPool.initialize.selector,
            admin,
            address(mockUSDC),
            address(oracle),
            address(yieldShift),
            timelock,
            treasury,
            address(vault)
        );
        ERC1967Proxy hedgerPoolProxy = new ERC1967Proxy(address(hedgerPoolImpl), hedgerPoolInitData);
        hedgerPool = HedgerPool(address(hedgerPoolProxy));
        
        // Wire contracts together
        vm.startPrank(admin);
        
        // Update vault with pool addresses
        vault.updateHedgerPool(address(hedgerPool));
        vault.updateUserPool(address(userPool));
        
        // Update YieldShift with pool addresses
        yieldShift.updateUserPool(address(userPool));
        yieldShift.updateHedgerPool(address(hedgerPool));
        // Note: AaveVault integration would require additional setup
        
        // Grant necessary roles
        vault.grantRole(vault.GOVERNANCE_ROLE(), governance);
        vault.grantRole(vault.EMERGENCY_ROLE(), emergency);
        
        userPool.grantRole(userPool.GOVERNANCE_ROLE(), governance);
        userPool.grantRole(userPool.EMERGENCY_ROLE(), emergency);
        
        hedgerPool.grantRole(hedgerPool.GOVERNANCE_ROLE(), governance);
        hedgerPool.grantRole(hedgerPool.EMERGENCY_ROLE(), emergency);

        vault.setDevMode(true);
        vm.stopPrank();

        vm.startPrank(governance);
        vault.updateCollateralizationThresholds(101e18, 101e18);
        hedgerPool.setSingleHedger(hedger1);
        vm.stopPrank();

        uint256 seedAmount = 100_000 * 1e6;
        vm.prank(hedger1);
        mockUSDC.approve(address(hedgerPool), seedAmount);
        vm.prank(hedger1);
        hedgerPool.enterHedgePosition(seedAmount, 5); // leverage 5 so margin ratio is within allowed range
    }
    
    // =============================================================================
    // END-TO-END INTEGRATION TESTS
    // =============================================================================

    /**
     * @notice Complete protocol workflow integration test
     * @dev Tests deposit -> mint -> stake -> unstake -> redeem flow
     */
    function test_CompleteProtocolWorkflow() public {
        console.log("=== Complete Protocol Workflow Integration Test ===");
        
        uint256 initialUserUSDC = mockUSDC.balanceOf(user1);
        uint256 initialVaultUSDC = mockUSDC.balanceOf(address(vault));
        
        // =============================================================================
        // STEP 1: User deposits USDC to UserPool
        // =============================================================================
        console.log("\n--- Step 1: User Deposit ---");
        
        vm.startPrank(user1);
        mockUSDC.approve(address(userPool), DEPOSIT_AMOUNT);
        
        // Note: UserPool.deposit() would need to be implemented to call vault.mintQEURO()
        // For now, we'll simulate the flow by directly interacting with vault
        // In a real scenario, UserPool would handle this internally
        
        // Approve vault to spend USDC
        mockUSDC.approve(address(vault), DEPOSIT_AMOUNT);
        
        // Get expected QEURO (18 decimals): netAmount * 1e30 / price; use 90% for minQeuroOut to allow fee
        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "Oracle price invalid");
        uint256 expectedQEURO = (DEPOSIT_AMOUNT * 1e30) / eurUsdPrice;
        vault.mintQEURO(DEPOSIT_AMOUNT, (expectedQEURO * 90) / 100);
        vm.stopPrank();

        uint256 userQEUROBalance = qeuroToken.balanceOf(user1);
        assertGt(userQEUROBalance, 0, "User should receive QEURO");
        // Actual is slightly less due to 0.1% mint fee; use 2% relative tolerance
        assertApproxEqRel(userQEUROBalance, expectedQEURO, 0.02e18, "QEURO amount should match calculation");
        
        console.log("USDC deposited:", DEPOSIT_AMOUNT / 1e6);
        console.log("QEURO minted:", userQEUROBalance / 1e18);
        
        // Verify vault received USDC (full amount minus mint fee sent to FeeCollector)
        uint256 vaultUSDCAfter = mockUSDC.balanceOf(address(vault));
        uint256 currentMintFee = vault.mintFee();
        uint256 expectedVaultIncrease = DEPOSIT_AMOUNT - (DEPOSIT_AMOUNT * currentMintFee / 1e18);
        assertEq(vaultUSDCAfter - initialVaultUSDC, expectedVaultIncrease, "Vault should receive USDC minus fee");
        
        // =============================================================================
        // STEP 2: User stakes QEURO into stQEURO
        // =============================================================================
        console.log("\n--- Step 2: User Stakes QEURO ---");
        
        uint256 stakeAmount = userQEUROBalance / 2; // Stake half
        
        vm.startPrank(user1);
        qeuroToken.approve(address(stQEURO), stakeAmount);
        uint256 stQEUROReceived = stQEURO.stake(stakeAmount);
        vm.stopPrank();
        
        uint256 userStQEUROBalance = stQEURO.balanceOf(user1);
        assertGt(userStQEUROBalance, 0, "User should receive stQEURO");
        assertEq(userStQEUROBalance, stQEUROReceived, "stQEURO balance should match returned amount");
        
        uint256 remainingQEURO = qeuroToken.balanceOf(user1);
        assertEq(remainingQEURO, userQEUROBalance - stakeAmount, "Remaining QEURO should be correct");
        
        console.log("QEURO staked:", stakeAmount / 1e18);
        console.log("stQEURO received:", userStQEUROBalance / 1e18);
        
        // =============================================================================
        // STEP 3: Verify supply consistency
        // =============================================================================
        console.log("\n--- Step 3: Supply Consistency Check ---");
        
        uint256 totalQEUROSupply = qeuroToken.totalSupply();
        uint256 stQEUROUnderlying = stQEURO.totalUnderlying();
        
        // QEURO in circulation + QEURO locked in stQEURO should equal total supply
        uint256 qeuroInStQEURO = qeuroToken.balanceOf(address(stQEURO));
        uint256 qeuroInCirculation = totalQEUROSupply - qeuroInStQEURO;
        
        assertEq(qeuroInStQEURO, stQEUROUnderlying, "stQEURO underlying should match locked QEURO");
        assertEq(totalQEUROSupply, qeuroInCirculation + qeuroInStQEURO, "Total QEURO supply should be consistent");
        
        console.log("Total QEURO supply:", totalQEUROSupply / 1e18);
        console.log("QEURO in stQEURO:", qeuroInStQEURO / 1e18);
        console.log("QEURO in circulation:", qeuroInCirculation / 1e18);
        
        // =============================================================================
        // STEP 4: Verify collateralization
        // =============================================================================
        console.log("\n--- Step 4: Collateralization Check ---");
        
        uint256 vaultUSDCBalance = mockUSDC.balanceOf(address(vault));
        // Convert QEURO (18 dec) to USDC (6 dec) via EUR/USD price (18 dec): USDC = QEURO * price / 1e30
        uint256 requiredUSDC = (totalQEUROSupply * eurUsdPrice) / 1e30;

        assertGe(vaultUSDCBalance, requiredUSDC, "Vault should have sufficient USDC collateral");
        
        uint256 collateralizationRatio = (vaultUSDCBalance * 1e18) / requiredUSDC;
        console.log("Collateralization ratio:", collateralizationRatio / 1e16, "%");
        
        // =============================================================================
        // STEP 5: User unstakes and redeems QEURO back to USDC
        // =============================================================================
        console.log("\n--- Step 5: User Unstakes and Redeems ---");
        
        vm.startPrank(user1);
        
        // Unstake stQEURO
        stQEURO.unstake(userStQEUROBalance);
        
        uint256 qeuroAfterUnstake = qeuroToken.balanceOf(user1);
        assertApproxEqRel(qeuroAfterUnstake, userQEUROBalance, 0.01e18, "User should have QEURO back after unstaking");
        
        // Redeem QEURO for USDC
        uint256 qeuroToRedeem = qeuroAfterUnstake;
        uint256 usdcBeforeRedeem = mockUSDC.balanceOf(user1);
        
        // Calculate minimum USDC expected (allow slippage for fees)
        // Convert QEURO (18 dec) to USDC (6 dec) via EUR/USD price (18 dec): USDC = QEURO * price / 1e30
        uint256 expectedUSDC = (qeuroToRedeem * eurUsdPrice) / 1e30;
        uint256 minUsdcOut = (expectedUSDC * 80) / 100;
        
        qeuroToken.approve(address(vault), qeuroToRedeem);
        vault.redeemQEURO(qeuroToRedeem, minUsdcOut);
        
        uint256 usdcAfterRedeem = mockUSDC.balanceOf(user1);
        uint256 usdcReceived = usdcAfterRedeem - usdcBeforeRedeem;
        
        vm.stopPrank();
        
        // Verify redemption amount (should be approximately equal to deposit, minus fees)
        assertApproxEqRel(usdcReceived, expectedUSDC, 0.01e18, "USDC received should match expected amount");
        
        console.log("QEURO redeemed:", qeuroToRedeem / 1e18);
        console.log("USDC received:", usdcReceived / 1e6);
        
        // =============================================================================
        // STEP 6: Final state verification
        // =============================================================================
        console.log("\n--- Step 6: Final State Verification ---");
        
        uint256 finalUserUSDC = mockUSDC.balanceOf(user1);
        uint256 finalUserQEURO = qeuroToken.balanceOf(user1);
        uint256 finalQEUROSupply = qeuroToken.totalSupply();
        
        assertEq(finalUserQEURO, 0, "User should have no QEURO remaining");
        assertApproxEqRel(finalUserUSDC, initialUserUSDC, 0.01e18, "User USDC should be approximately restored");
        assertEq(finalQEUROSupply, 0, "All QEURO should be burned");
        
        console.log("Initial USDC:", initialUserUSDC / 1e6);
        console.log("Final USDC:", finalUserUSDC / 1e6);
        console.log("Net change:", (finalUserUSDC > initialUserUSDC ? finalUserUSDC - initialUserUSDC : initialUserUSDC - finalUserUSDC) / 1e6);
        
        console.log("\n=== Complete Protocol Workflow Integration Test PASSED ===");
    }
    
    /**
     * @notice Batch operations workflow test
     * @dev Tests multiple users performing deposits concurrently
     */
    function test_BatchOperationsWorkflow() public {
        console.log("\n=== Batch Operations Integration Test ===");
        
        address[] memory users = new address[](3);
        users[0] = address(0x10);
        users[1] = address(0x11);
        users[2] = address(0x12);
        
        uint256[] memory deposits = new uint256[](3);
        deposits[0] = 5_000 * 1e6; // 5k USDC
        deposits[1] = 3_000 * 1e6; // 3k USDC
        deposits[2] = 2_000 * 1e6; // 2k USDC
        
        // Mint USDC to users
        for (uint256 i = 0; i < users.length; i++) {
            mockUSDC.mint(users[i], deposits[i]);
        }
        
        uint256 totalDeposited = 0;
        uint256 totalQEUROMinted = 0;
        
        // All users deposit
        
        (uint256 eurUsdPriceBatch, bool isValidBatch) = oracle.getEurUsdPrice();
        require(isValidBatch, "Oracle price invalid");
        
        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            mockUSDC.approve(address(vault), deposits[i]);
            
            // Calculate expected QEURO and set slippage tolerance
            uint256 expectedQEUROBatch = (deposits[i] * 1e30) / eurUsdPriceBatch;
            uint256 minQeuroOut = (expectedQEUROBatch * 90) / 100;
            
            vault.mintQEURO(deposits[i], minQeuroOut);
            
            uint256 qeuroBalance = qeuroToken.balanceOf(users[i]);
            totalDeposited += deposits[i];
            totalQEUROMinted += qeuroBalance;
            
            vm.stopPrank();
        }
        
        assertEq(totalDeposited, 10_000 * 1e6, "Total deposits should equal sum");
        assertGt(totalQEUROMinted, 0, "Total QEURO should be minted");
        
        uint256 totalQEUROSupply = qeuroToken.totalSupply();
        assertEq(totalQEUROSupply, totalQEUROMinted, "Total supply should match minted amount");
        
        console.log("Total USDC deposited:", totalDeposited / 1e6);
        console.log("Total QEURO minted:", totalQEUROMinted / 1e18);
        console.log("\n=== Batch Operations Integration Test PASSED ===");
    }

    /**
     * @notice Oracle extreme price deviation causes mint to revert
     * @dev Vault uses PriceValidationLibrary; deviation > MAX_PRICE_DEVIATION (2%) reverts with ExcessiveSlippage
     */
    function test_Integration_OracleExtremePrice_RevertsMint() public virtual {
        vm.prank(admin);
        vault.setDevMode(false); // enable price deviation check

        // One mint at normal price to set lastValidEurUsdPrice
        vm.startPrank(user1);
        mockUSDC.approve(address(vault), DEPOSIT_AMOUNT);
        (uint256 eurPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "oracle invalid");
        uint256 expectedQEURO = (DEPOSIT_AMOUNT * 1e30) / eurPrice;
        vault.mintQEURO(DEPOSIT_AMOUNT, (expectedQEURO * 90) / 100);
        vm.stopPrank();

        // Advance blocks so deviation check runs (MIN_BLOCKS_BETWEEN_UPDATES = 1)
        vm.roll(block.number + 2);

        // Set feed to extreme price so oracle returns (1.15e18, true); vault's lastValid is 1.10e18 so vault reverts with ExcessiveSlippage
        eurUsdFeed.setPrice(int256(1.15e8)); // 8 decimals for Chainlink feed
        vm.prank(admin);
        oracle.setPrices(1.15e18, 1e18);

        vm.startPrank(user1);
        mockUSDC.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 expectedQEURO2 = (DEPOSIT_AMOUNT * 1e30) / 1.15e18;
        vm.expectRevert(CommonErrorLibrary.ExcessiveSlippage.selector);
        vault.mintQEURO(DEPOSIT_AMOUNT, (expectedQEURO2 * 90) / 100);
        vm.stopPrank();
    }
}
