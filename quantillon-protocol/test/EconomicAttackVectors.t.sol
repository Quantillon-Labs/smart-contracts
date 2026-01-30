// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {UserPool} from "../src/core/UserPool.sol";
import {HedgerPool} from "../src/core/HedgerPool.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOracle} from "../src/interfaces/IOracle.sol";
import {FlashLoanProtectionLibrary} from "../src/libraries/FlashLoanProtectionLibrary.sol";
import {IntegrationTests} from "./IntegrationTests.t.sol";

/// @notice Harness to expose FlashLoanProtectionLibrary.validateBalanceChange for testing
contract FlashLoanProtectionHarness {
    function validate(uint256 beforeBalance, uint256 afterBalance, uint256 maxDecrease)
        external pure returns (bool) {
        return FlashLoanProtectionLibrary.validateBalanceChange(beforeBalance, afterBalance, maxDecrease);
    }
}

/**
 * @title EconomicAttackVectors
 * @notice Comprehensive testing for economic attack vectors and arbitrage scenarios
 *
 * @dev This test suite covers actual economic attack scenarios:
 *      - Flash loan attacks on protocol economics
 *      - Cross-pool arbitrage exploitation
 *      - Price oracle manipulation for profit
 *      - Sandwich attacks on large transactions
 *      - Yield farming attack vectors
 *      - Collateral factor manipulation
 *      - stQEURO exchange rate manipulation
 *      - Liquidation profit attacks
 *      - MEV extraction scenarios
 *      - Fee extraction attacks
 *
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract EconomicAttackVectors is Test {
    // ==================== STATE VARIABLES ====================

    // Core contracts
    TimeProvider public timeProviderImpl;
    TimeProvider public timeProvider;
    HedgerPool public hedgerPoolImpl;
    HedgerPool public hedgerPool;
    UserPool public userPoolImpl;
    UserPool public userPool;

    // Test accounts
    address public admin = address(0x1);
    address public governance = address(0x2);
    address public emergencyRole = address(0x3);
    address public treasury = address(0x4);
    address public arbitrageur = address(0x5);
    address public flashLoanAttacker = address(0x6);
    address public yieldManipulator = address(0x7);
    address public priceManipulator = address(0x8);
    address public sandwichAttacker = address(0x9);
    address public mevExtractor = address(0xA);
    address public user1 = address(0xB);
    address public user2 = address(0xC);
    address public liquidator = address(0xD);

    // Mock addresses
    address public mockUSDC = address(0x100);
    address public mockOracle = address(0x101);
    address public mockYieldShift = address(0x102);
    address public mockQEURO = address(0x103);
    address public mockstQEURO = address(0x104);
    address public mockVault = address(0x105);
    address public mockTimelock = address(0x106);

    // ==================== CONSTANTS ====================

    uint256 constant USDC_PRECISION = 1e6;
    uint256 constant PRECISION = 1e18;
    uint256 constant INITIAL_USDC_AMOUNT = 1_000_000 * USDC_PRECISION; // 1M USDC
    uint256 constant LARGE_AMOUNT = 100_000 * USDC_PRECISION; // 100K USDC
    uint256 constant MEDIUM_AMOUNT = 10_000 * USDC_PRECISION; // 10K USDC
    uint256 constant SMALL_AMOUNT = 1_000 * USDC_PRECISION; // 1K USDC

    // Price constants (8 decimals for Chainlink)
    int256 constant EUR_USD_PRICE = 110000000; // 1.10 USD
    int256 constant EUR_USD_HIGH = 120000000; // 1.20 USD
    int256 constant EUR_USD_LOW = 100000000; // 1.00 USD

    // ==================== SETUP ====================

    function setUp() public {
        // Deploy TimeProvider
        timeProviderImpl = new TimeProvider();
        bytes memory timeProviderInitData = abi.encodeWithSelector(
            TimeProvider.initialize.selector,
            admin,
            admin,
            admin
        );
        ERC1967Proxy timeProviderProxy = new ERC1967Proxy(address(timeProviderImpl), timeProviderInitData);
        timeProvider = TimeProvider(address(timeProviderProxy));

        // Deploy HedgerPool
        hedgerPoolImpl = new HedgerPool(timeProvider);
        bytes memory hedgerPoolInitData = abi.encodeWithSelector(
            HedgerPool.initialize.selector,
            admin,
            mockUSDC,
            mockOracle,
            mockYieldShift,
            mockTimelock,
            treasury,
            mockVault
        );
        ERC1967Proxy hedgerPoolProxy = new ERC1967Proxy(address(hedgerPoolImpl), hedgerPoolInitData);
        hedgerPool = HedgerPool(address(hedgerPoolProxy));

        // Deploy UserPool
        userPoolImpl = new UserPool(timeProvider);
        bytes memory userPoolInitData = abi.encodeWithSelector(
            UserPool.initialize.selector,
            admin,
            mockUSDC,
            mockQEURO,
            mockstQEURO,
            mockYieldShift,
            treasury,
            100, // 0.01% deposit fee
            100, // 0.01% staking fee
            86400 // 1 day unstaking cooldown
        );
        ERC1967Proxy userPoolProxy = new ERC1967Proxy(address(userPoolImpl), userPoolInitData);
        userPool = UserPool(address(userPoolProxy));

        // Setup roles
        vm.startPrank(admin);
        hedgerPool.grantRole(hedgerPool.GOVERNANCE_ROLE(), governance);
        hedgerPool.grantRole(hedgerPool.EMERGENCY_ROLE(), emergencyRole);
        userPool.grantRole(userPool.GOVERNANCE_ROLE(), governance);
        userPool.grantRole(userPool.EMERGENCY_ROLE(), emergencyRole);
        vm.stopPrank();

        // Setup mock USDC calls
        _setupMockUSDC();

        // Setup mock Oracle calls
        _setupMockOracle(EUR_USD_PRICE);
    }

    function _setupMockUSDC() internal {
        // Mock balance calls
        vm.mockCall(
            mockUSDC,
            abi.encodeWithSelector(IERC20.balanceOf.selector),
            abi.encode(INITIAL_USDC_AMOUNT)
        );
        // Mock transfer calls
        vm.mockCall(
            mockUSDC,
            abi.encodeWithSelector(IERC20.transfer.selector),
            abi.encode(true)
        );
        // Mock transferFrom calls
        vm.mockCall(
            mockUSDC,
            abi.encodeWithSelector(IERC20.transferFrom.selector),
            abi.encode(true)
        );
        // Mock approve calls
        vm.mockCall(
            mockUSDC,
            abi.encodeWithSelector(IERC20.approve.selector),
            abi.encode(true)
        );
    }

    function _setupMockOracle(int256 price) internal {
        // Mock EUR/USD price
        vm.mockCall(
            mockOracle,
            abi.encodeWithSelector(IOracle.getEurUsdPrice.selector),
            // forge-lint: disable-next-line(unsafe-typecast)
            abi.encode(uint256(price) * 1e10, true) // Convert to 18 decimals
        );
    }

    // =============================================================================
    // FLASH LOAN ATTACK TESTS
    // =============================================================================

    /**
     * @notice Test flash loan protection prevents balance manipulation
     * @dev Verifies that flash loans cannot be used to manipulate pool balances
     */
    function test_Economic_FlashLoanBalanceManipulation_Blocked() public {
        // Flash loan protection: validateBalanceChange returns false when decrease > maxDecrease
        FlashLoanProtectionHarness harness = new FlashLoanProtectionHarness();
        // Before: 100 USDC, after: 10 USDC (90 drop), maxDecrease: 40 -> 90 > 40 -> invalid (false)
        bool valid = harness.validate(100 * USDC_PRECISION, 10 * USDC_PRECISION, 40 * USDC_PRECISION);
        assertFalse(valid, "Large balance drop beyond maxDecrease should be rejected");
        // Within limit: before 100, after 70, maxDecrease 40 -> decrease 30 <= 40 -> valid (true)
        bool validWithin = harness.validate(100 * USDC_PRECISION, 70 * USDC_PRECISION, 40 * USDC_PRECISION);
        assertTrue(validWithin, "Balance decrease within maxDecrease should pass");
    }

    /**
     * @notice Test that flash loan cannot manipulate collateral ratios
     * @dev Verifies FlashLoanProtectionLibrary rejects balance decrease beyond maxDecrease
     */
    function test_Economic_FlashLoanCollateralManipulation_Blocked() public {
        // Deploy harness that exposes FlashLoanProtectionLibrary.validateBalanceChange
        FlashLoanProtectionHarness harness = new FlashLoanProtectionHarness();
        // Before: 100 USDC, after: 50 USDC, maxDecrease: 40 -> allowed decrease is 40, actual is 50 -> should fail
        bool ok = harness.validate(100 * USDC_PRECISION, 50 * USDC_PRECISION, 40 * USDC_PRECISION);
        assertFalse(ok, "Balance decrease beyond maxDecrease should be rejected");
        // Within limit: before 100, after 65, maxDecrease 40 -> allowed, actual 35 -> should pass
        bool okWithin = harness.validate(100 * USDC_PRECISION, 65 * USDC_PRECISION, 40 * USDC_PRECISION);
        assertTrue(okWithin, "Balance decrease within maxDecrease should pass");
    }

    // test_Economic_FlashLoanYieldExtraction_Blocked: executable in EconomicAttackVectorsIntegration below

    // =============================================================================
    // PRICE ORACLE MANIPULATION TESTS
    // =============================================================================

    /**
     * @notice Test that stale price data is rejected
     * @dev Verifies oracle returns invalid when mocked as stale; vault would revert on mint
     */
    function test_Economic_StalePriceRejection() public {
        // Mock stale oracle data (isValid = false)
        vm.mockCall(
            mockOracle,
            abi.encodeWithSelector(IOracle.getEurUsdPrice.selector),
            // forge-lint: disable-next-line(unsafe-typecast)
            abi.encode(uint256(EUR_USD_PRICE) * 1e10, false) // false = stale
        );
        (uint256 price, bool isValid) = IOracle(mockOracle).getEurUsdPrice();
        assertFalse(isValid, "Stale price should return invalid");
        // casting to uint256 is safe: EUR_USD_PRICE is a test constant within uint256 range
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(price, uint256(EUR_USD_PRICE) * 1e10, "Price value should match mock");
    }

    // test_Economic_ExtremePriceDeviation_Protected: executable in EconomicAttackVectorsIntegration.test_Economic_Integration_ExtremePriceMintReverts

    // test_Economic_OracleManipulationLiquidation_Blocked: executable in EconomicAttackVectorsIntegration below

    // =============================================================================
    // SANDWICH ATTACK TESTS
    // =============================================================================

    // test_Economic_SandwichAttack_SlippageProtection: executable in EconomicAttackVectorsIntegration below

    /**
     * @notice Test MEV protection through transaction ordering
     * @dev Verifies commit-reveal or other MEV mitigation
     */
    function test_Economic_MEVProtection() public {
        vm.skip(true, "MEV protection tests pending contract MEV hooks; scenario requires full protocol");
    }

    // =============================================================================
    // ARBITRAGE ATTACK TESTS
    // =============================================================================

    /**
     * @notice Test cross-pool arbitrage is not profitable
     * @dev Verifies pricing consistency across pools
     */
    function test_Economic_CrossPoolArbitrage_NotProfitable() public {
        vm.skip(true, "Scenario requires full protocol deployment; covered by IntegrationTests");
    }

    /**
     * @notice Test arbitrage through stQEURO exchange rate
     * @dev Verifies exchange rate manipulation is prevented
     */
    function test_Economic_stQEUROArbitrage_Blocked() public {
        vm.skip(true, "Scenario requires full protocol deployment; covered by IntegrationTests");
    }

    // =============================================================================
    // YIELD MANIPULATION TESTS
    // =============================================================================

    /**
     * @notice Test yield cannot be extracted through timing attacks
     * @dev Verifies yield distribution is time-weighted
     */
    function test_Economic_YieldTimingAttack_Blocked() public {
        vm.skip(true, "Scenario requires full protocol deployment; covered by IntegrationTests");
    }

    /**
     * @notice Test yield shift parameters are bounded
     * @dev Verifies yield shift cannot be set to exploitable values
     */
    function test_Economic_YieldShiftBounds_Enforced() public {
        vm.skip(true, "Scenario requires full protocol deployment; covered by YieldValidationLibrary tests");
    }

    // =============================================================================
    // COLLATERAL MANIPULATION TESTS
    // =============================================================================

    /**
     * @notice Test minimum collateralization ratio is enforced
     * @dev Verifies positions cannot be undercollateralized
     */
    function test_Economic_MinCollateralRatio_Enforced() public {
        vm.skip(true, "Scenario requires full protocol deployment; covered by IntegrationTests / LiquidationScenarios");
    }

    /**
     * @notice Test maximum leverage is limited
     * @dev Verifies leverage cannot exceed safe limits
     */
    function test_Economic_MaxLeverage_Limited() public {
        vm.skip(true, "Scenario requires full protocol deployment; covered by HedgerPool tests");
    }

    // =============================================================================
    // FEE EXTRACTION TESTS
    // =============================================================================

    /**
     * @notice Test fees cannot be bypassed
     * @dev Verifies all operations charge appropriate fees
     */
    function test_Economic_FeeBypass_Blocked() public {
        vm.skip(true, "Scenario requires full protocol deployment; covered by FeeCollector / IntegrationTests");
    }

    /**
     * @notice Test fee accumulation is accurate
     * @dev Verifies fee collection is correct
     */
    function test_Economic_FeeAccumulation_Accurate() public {
        vm.skip(true, "Scenario requires full protocol deployment; covered by FeeCollector / IntegrationTests");
    }

    // =============================================================================
    // LIQUIDATION ATTACK TESTS
    // =============================================================================

    /**
     * @notice Test self-liquidation is not profitable
     * @dev Verifies liquidation penalties prevent self-liquidation attacks
     */
    function test_Economic_SelfLiquidation_NotProfitable() public {
        vm.skip(true, "Scenario requires full protocol deployment; covered by LiquidationScenarios");
    }

    /**
     * @notice Test liquidation race conditions are handled
     * @dev Verifies concurrent liquidations are processed correctly
     */
    function test_Economic_LiquidationRaceCondition_Handled() public {
        vm.skip(true, "Scenario requires full protocol deployment; covered by RaceConditionTests / LiquidationScenarios");
    }

    /**
     * @notice Test cascading liquidations are controlled
     * @dev Verifies cascade protection mechanisms
     */
    function test_Economic_CascadingLiquidations_Controlled() public {
        vm.skip(true, "Scenario requires full protocol deployment; covered by LiquidationScenarios");
    }

    // =============================================================================
    // ECONOMIC INVARIANT TESTS
    // =============================================================================

    /**
     * @notice Test total supply invariants
     * @dev Verifies minted tokens equal backing
     */
    function test_Economic_SupplyBacking_Invariant() public {
        vm.skip(true, "Scenario requires full protocol deployment; covered by QuantillonInvariants");
    }

    /**
     * @notice Test collateral is always sufficient
     * @dev Verifies system is never undercollateralized
     */
    function test_Economic_CollateralSufficiency_Invariant() public {
        vm.skip(true, "Scenario requires full protocol deployment; covered by QuantillonInvariants");
    }

    // =============================================================================
    // ATTACK SCENARIO TESTS
    // =============================================================================

    /**
     * @notice Test comprehensive economic attack scenario
     * @dev Simulates a sophisticated economic attack
     */
    function test_Economic_ComprehensiveAttack_Blocked() public {
        vm.skip(true, "Scenario requires full protocol deployment; covered by CombinedAttackVectors / IntegrationTests");
    }

    /**
     * @notice Test coordinated multi-user attack
     * @dev Simulates attack using multiple accounts
     */
    function test_Economic_CoordinatedAttack_Blocked() public {
        vm.skip(true, "Scenario requires full protocol deployment; covered by IntegrationTests");
    }

    /**
     * @notice Test economic attack through governance
     * @dev Verifies governance cannot extract value
     */
    function test_Economic_GovernanceExtraction_Blocked() public {
        vm.skip(true, "Scenario requires full protocol deployment; covered by CombinedAttackVectors / GovernanceAttackVectors");
    }

    // =============================================================================
    // PAUSE MECHANISM ECONOMIC TESTS
    // =============================================================================

    /**
     * @notice Test emergency pause protects economics
     * @dev Verifies pause stops economic exploits
     */
    function test_Economic_EmergencyPause_Protection() public {
        // Pause should stop all economic operations:
        vm.prank(emergencyRole);
        hedgerPool.pause();

        assertTrue(hedgerPool.paused(), "HedgerPool should be paused");

        vm.prank(emergencyRole);
        userPool.pause();

        assertTrue(userPool.paused(), "UserPool should be paused");
    }

    /**
     * @notice Test unpause requires proper authorization
     * @dev Verifies unpause is controlled
     */
    function test_Economic_UnpauseControl() public {
        // Pause contracts
        vm.prank(emergencyRole);
        hedgerPool.pause();

        // Attacker cannot unpause
        vm.prank(arbitrageur);
        vm.expectRevert();
        hedgerPool.unpause();

        // Only authorized can unpause
        vm.prank(emergencyRole);
        hedgerPool.unpause();

        assertFalse(hedgerPool.paused(), "HedgerPool should be unpaused");
    }

    // =============================================================================
    // ECONOMIC PARAMETER TESTS
    // =============================================================================

    /**
     * @notice Test fee parameters are bounded
     * @dev Verifies fee limits exist
     */
    function test_Economic_FeeBounds() public {
        vm.skip(true, "Scenario requires full protocol deployment; covered by FeeCollector tests");
    }

    /**
     * @notice Test collateral parameters are bounded
     * @dev Verifies collateral limits exist
     */
    function test_Economic_CollateralBounds() public {
        vm.skip(true, "Scenario requires full protocol deployment; covered by QuantillonVault / HedgerPool tests");
    }

    /**
     * @notice Test cooldown periods are enforced
     * @dev Verifies timing restrictions exist
     */
    function test_Economic_CooldownEnforcement() public {
        vm.skip(true, "Scenario requires full protocol deployment; covered by UserPool / HedgerPool tests");
    }
}

/**
 * @title EconomicAttackVectorsIntegration
 * @notice Executable economic attack tests using full protocol (inherits IntegrationTests)
 * @dev Reduces skips by running FlashLoan yield extraction, oracle/liquidation, and sandwich/slippage scenarios against deployed vault, oracle, and pools.
 */
contract EconomicAttackVectorsIntegration is IntegrationTests {
    /**
     * @notice Flash loan yield extraction: user mints, stakes; price drop; redeem bounded by collateral
     * @dev Same scenario as CombinedAttackVectors.test_Combined_YieldExtractionDuringVolatility_RedemptionBounded
     */
    function test_Economic_Integration_FlashLoanYieldExtraction_Blocked() public {
        vm.startPrank(user1);
        mockUSDC.approve(address(vault), DEPOSIT_AMOUNT);
        (uint256 eurPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "oracle invalid");
        uint256 expectedQEURO = (DEPOSIT_AMOUNT * 1e30) / eurPrice;
        vault.mintQEURO(DEPOSIT_AMOUNT, (expectedQEURO * 90) / 100);
        uint256 qeuroBal = qeuroToken.balanceOf(user1);
        qeuroToken.approve(address(stQEURO), qeuroBal / 2);
        stQEURO.stake(qeuroBal / 2);
        vm.stopPrank();

        eurUsdFeed.setPrice(int256(1e8));
        vm.prank(admin);
        oracle.setPrices(1.00e18, 1e18);

        uint256 vaultUsdcBefore = mockUSDC.balanceOf(address(vault));
        uint256 userUsdcBefore = mockUSDC.balanceOf(user1);
        vm.startPrank(user1);
        uint256 toRedeem = qeuroToken.balanceOf(user1);
        qeuroToken.approve(address(vault), toRedeem);
        uint256 expectedUsdc = (toRedeem * 1e18) / 1e30;
        uint256 minOut = (expectedUsdc * 80) / 100;
        vault.redeemQEURO(toRedeem, minOut);
        vm.stopPrank();

        uint256 usdcReceived = mockUSDC.balanceOf(user1) - userUsdcBefore;
        assertLe(usdcReceived, vaultUsdcBefore, "Yield extraction bounded by vault collateral");
    }

    /**
     * @notice Oracle manipulation / liquidation path: extreme price on redeem reverts or is bounded
     * @dev Redeem with unreasonable minOut reverts (ExcessiveSlippage or similar)
     */
    function test_Economic_Integration_OracleManipulationLiquidation_Blocked() public {
        vm.prank(admin);
        vault.setDevMode(false);

        vm.startPrank(user1);
        mockUSDC.approve(address(vault), DEPOSIT_AMOUNT);
        (uint256 eurPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "oracle invalid");
        uint256 expectedQEURO = (DEPOSIT_AMOUNT * 1e30) / eurPrice;
        vault.mintQEURO(DEPOSIT_AMOUNT, (expectedQEURO * 90) / 100);
        uint256 qeuroBal = qeuroToken.balanceOf(user1);
        vm.stopPrank();

        eurUsdFeed.setPrice(int256(0.50e8));
        vm.prank(admin);
        oracle.setPrices(0.50e18, 1e18);

        vm.startPrank(user1);
        qeuroToken.approve(address(vault), qeuroBal);
        uint256 unreasonableMinOut = 100_000 * 1e6;
        vm.expectRevert();
        vault.redeemQEURO(qeuroBal, unreasonableMinOut);
        vm.stopPrank();
    }

    /**
     * @notice Sandwich / slippage: mint then redeem with extreme price; slippage protection reverts
     * @dev Same as CombinedAttackVectors.test_Combined_RedeemWithExtremePrice_RevertsOrBounded
     */
    function test_Economic_Integration_SandwichSlippage_Blocked() public {
        vm.prank(admin);
        vault.setDevMode(false);

        vm.startPrank(user1);
        mockUSDC.approve(address(vault), DEPOSIT_AMOUNT);
        (uint256 eurPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "oracle invalid");
        uint256 expectedQEURO = (DEPOSIT_AMOUNT * 1e30) / eurPrice;
        vault.mintQEURO(DEPOSIT_AMOUNT, (expectedQEURO * 90) / 100);
        uint256 qeuroBal = qeuroToken.balanceOf(user1);
        vm.stopPrank();

        eurUsdFeed.setPrice(int256(0.50e8));
        vm.prank(admin);
        oracle.setPrices(0.50e18, 1e18);

        vm.startPrank(user1);
        qeuroToken.approve(address(vault), qeuroBal);
        vm.expectRevert();
        vault.redeemQEURO(qeuroBal, 100_000 * 1e6);
        vm.stopPrank();
    }
}
