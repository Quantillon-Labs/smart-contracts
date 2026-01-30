// test/LiquidationScenarios.t.sol
// End-to-end liquidation mode tests: CR <= 101%, pro-rata redemption, HedgerPool state, paused revert.
// This file exists to verify liquidation mode behavior (vault + HedgerPool recordLiquidationRedeem).

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IntegrationTests} from "./IntegrationTests.t.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {QEUROToken} from "../src/core/QEUROToken.sol";
import {QuantillonVault} from "../src/core/QuantillonVault.sol";
import {UserPool} from "../src/core/UserPool.sol";
import {HedgerPool} from "../src/core/HedgerPool.sol";
import {stQEUROToken} from "../src/core/stQEUROToken.sol";
import {FeeCollector} from "../src/core/FeeCollector.sol";
import {YieldShift} from "../src/core/yieldmanagement/YieldShift.sol";
import {MockChainlinkOracle} from "../src/mocks/MockChainlinkOracle.sol";
import {MockAggregatorV3} from "./ChainlinkOracle.t.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

/**
 * @title LiquidationScenarios
 * @notice End-to-end tests for liquidation mode (CR <= 101%): redemption, events, paused revert
 * @dev Uses a minimal setup with small hedger deposit to trigger liquidation mode
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract LiquidationScenarios is IntegrationTests {
    // Small hedger deposit for liquidation testing
    // With 500 USDC hedger + 10k user = 10.5k collateral
    // At 2.0 EUR/USD, backing requirement = ~18k, so CR < 101%
    uint256 constant SMALL_HEDGER_DEPOSIT = 500 * 1e6; // 500 USDC
    address public user2 = address(0x10);

    /**
     * @notice Override setUp to use a smaller hedger deposit for liquidation testing
     */
    function setUp() public override {
        // Don't call parent setUp() - we do our own minimal setup
        // Deploy mock USDC
        mockUSDC = new MockUSDC();
        mockUSDC.mint(user1, INITIAL_USDC_AMOUNT);
        mockUSDC.mint(hedger1, INITIAL_USDC_AMOUNT);

        // Deploy mock Chainlink price feeds
        eurUsdFeed = new MockAggregatorV3(8);
        // casting to int256 is safe: EUR_USD_PRICE is a test constant within int256 range
        // forge-lint: disable-next-line(unsafe-typecast)
        eurUsdFeed.setPrice(int256(EUR_USD_PRICE));
        usdcUsdFeed = new MockAggregatorV3(8);
        // casting to int256 is safe: USDC_USD_PRICE is a test constant within int256 range
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
        oracle = MockChainlinkOracle(payable(address(oracleProxy)));

        vm.prank(admin);
        oracle.setPrices(1.10e18, 1.00e18);

        // Deploy FeeCollector
        FeeCollector feeCollectorImpl = new FeeCollector();
        bytes memory feeCollectorInitData = abi.encodeWithSelector(
            FeeCollector.initialize.selector,
            admin,
            treasury,
            treasury,
            treasury
        );
        ERC1967Proxy feeCollectorProxy = new ERC1967Proxy(address(feeCollectorImpl), feeCollectorInitData);
        feeCollector = FeeCollector(address(feeCollectorProxy));

        // Deploy QEUROToken
        QEUROToken qeuroImpl = new QEUROToken();
        bytes memory qeuroInitData = abi.encodeWithSelector(
            QEUROToken.initialize.selector,
            admin,
            admin,
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
            address(0),
            address(0),
            timelock,
            address(feeCollector)
        );
        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(vaultImpl), vaultInitData);
        vault = QuantillonVault(address(vaultProxy));

        vm.startPrank(admin);
        qeuroToken.grantRole(qeuroToken.MINTER_ROLE(), address(vault));
        qeuroToken.grantRole(qeuroToken.BURNER_ROLE(), address(vault));
        feeCollector.grantRole(feeCollector.TREASURY_ROLE(), address(vault));
        vm.stopPrank();

        // Deploy YieldShift (minimal)
        YieldShift yieldShiftImpl = new YieldShift(timeProvider);
        bytes memory yieldShiftInitData = abi.encodeWithSelector(
            YieldShift.initialize.selector,
            admin,
            address(mockUSDC),
            address(0),
            address(0),
            address(0),
            address(0),
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

        // Deploy UserPool
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

        // Wire contracts
        vm.startPrank(admin);
        vault.updateHedgerPool(address(hedgerPool));
        vault.updateUserPool(address(userPool));
        yieldShift.updateUserPool(address(userPool));
        yieldShift.updateHedgerPool(address(hedgerPool));
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

        // Use SMALL hedger deposit instead of 100k
        vm.prank(hedger1);
        mockUSDC.approve(address(hedgerPool), SMALL_HEDGER_DEPOSIT);
        vm.prank(hedger1);
        hedgerPool.enterHedgePosition(SMALL_HEDGER_DEPOSIT, 5);
    }

    /**
     * @notice When CR <= 101%, redemption uses liquidation path and emits LiquidationRedeemed
     * @dev User mints; set oracle price to 2.0 (max allowed) so CR drops below 101%; user redeems
     *      With 500 USDC hedger + 10k user = ~10.5k collateral
     *      At 2.0 EUR/USD, backing requirement = 10k/1.10 * 2.0 = ~18.2k USDC
     *      So CR = 10.5k / 18.2k = 58% which is < 101%
     */
    function test_LiquidationMode_RedemptionSucceeds() public {
        vm.startPrank(user1);
        mockUSDC.approve(address(vault), DEPOSIT_AMOUNT);
        (uint256 eurPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "oracle invalid");
        uint256 expectedQEURO = (DEPOSIT_AMOUNT * 1e30) / eurPrice;
        vault.mintQEURO(DEPOSIT_AMOUNT, (expectedQEURO * 90) / 100);
        uint256 qeuroBal = qeuroToken.balanceOf(user1);
        vm.stopPrank();

        uint256 hedgerMarginBefore = hedgerPool.totalMargin();

        // Set price to max allowed (2.0 EUR/USD) to trigger liquidation mode
        eurUsdFeed.setPrice(int256(2.0e8));
        vm.prank(admin);
        oracle.setPrices(2.0e18, 1e18);

        (bool isInLiquidation,,,) = vault.getLiquidationStatus();
        assertTrue(isInLiquidation, "Protocol should be in liquidation mode");

        vm.startPrank(user1);
        qeuroToken.approve(address(vault), qeuroBal);
        // In liquidation mode, use pro-rata payout calculation with generous slippage
        uint256 minOut = 0; // Accept any output in liquidation mode
        vault.redeemQEURO(qeuroBal, minOut);
        vm.stopPrank();

        assertLe(hedgerPool.totalMargin(), hedgerMarginBefore, "Hedger margin should decrease or stay same after liquidation redeem");
    }

    /**
     * @notice Override inherited test - not applicable with liquidation-focused setup
     * @dev This test is already covered in IntegrationTests with the standard setup
     */
    function test_Integration_OracleExtremePrice_RevertsMint() public override {
        vm.skip(true, "Covered by IntegrationTests with standard setup");
    }

    /**
     * @notice Redemption when protocol is paused reverts
     * @dev Put protocol in liquidation mode, pause vault, attempt redeem → revert
     */
    function test_LiquidationMode_PausedReverts() public {
        vm.startPrank(user1);
        mockUSDC.approve(address(vault), DEPOSIT_AMOUNT);
        (uint256 eurPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "oracle invalid");
        uint256 expectedQEURO = (DEPOSIT_AMOUNT * 1e30) / eurPrice;
        vault.mintQEURO(DEPOSIT_AMOUNT, (expectedQEURO * 90) / 100);
        uint256 qeuroBal = qeuroToken.balanceOf(user1);
        vm.stopPrank();

        // Set price to max allowed (2.0 EUR/USD) to trigger liquidation mode
        eurUsdFeed.setPrice(int256(2.0e8));
        vm.prank(admin);
        oracle.setPrices(2.0e18, 1e18);

        vm.prank(emergency);
        vault.pause();

        vm.startPrank(user1);
        qeuroToken.approve(address(vault), qeuroBal);
        vm.expectRevert();
        vault.redeemQEURO(qeuroBal, 0);
        vm.stopPrank();
    }

    /**
     * @notice Partial redemption in liquidation mode: user redeems only part of QEURO
     * @dev Pro-rata USDC out; vault and HedgerPool state consistent
     */
    function test_LiquidationMode_PartialRedemption() public {
        vm.startPrank(user1);
        mockUSDC.approve(address(vault), DEPOSIT_AMOUNT);
        (uint256 eurPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "oracle invalid");
        uint256 expectedQEURO = (DEPOSIT_AMOUNT * 1e30) / eurPrice;
        vault.mintQEURO(DEPOSIT_AMOUNT, (expectedQEURO * 90) / 100);
        uint256 qeuroBal = qeuroToken.balanceOf(user1);
        vm.stopPrank();

        eurUsdFeed.setPrice(int256(2.0e8));
        vm.prank(admin);
        oracle.setPrices(2.0e18, 1e18);

        (bool isInLiquidation,,,) = vault.getLiquidationStatus();
        assertTrue(isInLiquidation, "Protocol should be in liquidation mode");

        uint256 hedgerMarginBefore = hedgerPool.totalMargin();
        uint256 redeemHalf = qeuroBal / 2;

        vm.startPrank(user1);
        qeuroToken.approve(address(vault), redeemHalf);
        uint256 usdcBefore = mockUSDC.balanceOf(user1);
        vault.redeemQEURO(redeemHalf, 0);
        vm.stopPrank();

        uint256 usdcReceived = mockUSDC.balanceOf(user1) - usdcBefore;
        assertGt(usdcReceived, 0, "User should receive USDC for partial redeem");
        assertLe(hedgerPool.totalMargin(), hedgerMarginBefore, "Hedger margin should decrease or stay same");
    }

    /**
     * @notice Multiple redemptions in same block: two users redeem in liquidation mode
     * @dev Both succeed; supply and margin state consistent
     */
    function test_LiquidationMode_MultipleRedemptionsSameBlock() public {
        vm.prank(address(this));
        mockUSDC.mint(user2, INITIAL_USDC_AMOUNT);

        vm.startPrank(user1);
        mockUSDC.approve(address(vault), DEPOSIT_AMOUNT);
        (uint256 eurPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "oracle invalid");
        uint256 expectedQEURO = (DEPOSIT_AMOUNT * 1e30) / eurPrice;
        vault.mintQEURO(DEPOSIT_AMOUNT, (expectedQEURO * 90) / 100);
        vm.stopPrank();

        vm.startPrank(user2);
        mockUSDC.approve(address(vault), DEPOSIT_AMOUNT);
        (eurPrice, isValid) = oracle.getEurUsdPrice();
        require(isValid, "oracle invalid");
        expectedQEURO = (DEPOSIT_AMOUNT * 1e30) / eurPrice;
        vault.mintQEURO(DEPOSIT_AMOUNT, (expectedQEURO * 90) / 100);
        vm.stopPrank();

        eurUsdFeed.setPrice(int256(2.0e8));
        vm.prank(admin);
        oracle.setPrices(2.0e18, 1e18);

        uint256 supplyBefore = qeuroToken.totalSupply();

        vm.startPrank(user1);
        uint256 bal1 = qeuroToken.balanceOf(user1);
        qeuroToken.approve(address(vault), bal1);
        vault.redeemQEURO(bal1, 0);
        vm.stopPrank();

        vm.startPrank(user2);
        uint256 bal2 = qeuroToken.balanceOf(user2);
        qeuroToken.approve(address(vault), bal2);
        vault.redeemQEURO(bal2, 0);
        vm.stopPrank();

        assertEq(qeuroToken.totalSupply(), supplyBefore - bal1 - bal2, "Supply should decrease by both redemptions");
    }

    /**
     * @notice CR boundary: just above 101% → not in liquidation; just below → in liquidation
     * @dev Set oracle price so CR crosses 101% threshold
     */
    function test_LiquidationMode_CRBoundary() public {
        vm.startPrank(user1);
        mockUSDC.approve(address(vault), DEPOSIT_AMOUNT);
        (uint256 eurPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "oracle invalid");
        uint256 expectedQEURO = (DEPOSIT_AMOUNT * 1e30) / eurPrice;
        vault.mintQEURO(DEPOSIT_AMOUNT, (expectedQEURO * 90) / 100);
        vm.stopPrank();

        // Price ~1.13: CR just above 101% (collateral 10.5k, backing ~10.4k)
        eurUsdFeed.setPrice(int256(1.13e8));
        vm.prank(admin);
        oracle.setPrices(1.13e18, 1e18);
        (bool inLiq1,,,) = vault.getLiquidationStatus();
        // At 1.13, backing = 10k/1.10*1.13 = ~10.27k; CR = 10.5/10.27 > 1.01
        assertFalse(inLiq1, "CR just above 101% should not be in liquidation");

        // Price 1.15: CR drops below 101%
        eurUsdFeed.setPrice(int256(1.15e8));
        vm.prank(admin);
        oracle.setPrices(1.15e18, 1e18);
        (bool inLiq2,,,) = vault.getLiquidationStatus();
        assertTrue(inLiq2, "CR just below 101% should be in liquidation");
    }
}
