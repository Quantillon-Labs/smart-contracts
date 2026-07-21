// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {QEUROToken} from "../src/core/QEUROToken.sol";
import {QuantillonVault} from "../src/core/QuantillonVault.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";

contract FixedOracle {
    uint256 public eurUsdPrice = 1e18;
    uint256 public usdcUsdPrice = 1e18;

    function setPrices(uint256 eurUsd, uint256 usdcUsd) external {
        eurUsdPrice = eurUsd;
        usdcUsdPrice = usdcUsd;
    }

    function getEurUsdPrice() external view returns (uint256 price, bool isValid) {
        return (eurUsdPrice, true);
    }

    function getUsdcUsdPrice() external view returns (uint256 price, bool isValid) {
        return (usdcUsdPrice, true);
    }
}

contract HedgerPoolHarness {
    IERC20 public immutable USDC;
    QuantillonVault public immutable VAULT;
    uint256 public totalMargin;

    constructor(IERC20 _usdc, QuantillonVault _vault) {
        USDC = _usdc;
        VAULT = _vault;
    }

    function seedMargin(uint256 amount) external {
        bool transferred = USDC.transferFrom(msg.sender, address(VAULT), amount);
        require(transferred, "transferFrom failed");
        totalMargin += amount;
        VAULT.addHedgerDeposit(amount);
    }

    function recordUserMint(uint256, uint256, uint256) external {}

    function recordUserRedeem(uint256, uint256, uint256) external {}

    function recordLiquidationRedeem(uint256 qeuroAmount, uint256 totalQeuroSupply) external {
        if (totalQeuroSupply == 0 || totalMargin == 0) return;
        uint256 marginLoss = (qeuroAmount * totalMargin) / totalQeuroSupply;
        if (marginLoss > totalMargin) marginLoss = totalMargin;
        totalMargin -= marginLoss;
    }

    function getTotalEffectiveHedgerCollateral(uint256) external view returns (uint256) {
        return totalMargin;
    }

    function hasActiveHedger() external view returns (bool) {
        return totalMargin > 0;
    }

    function fundRewardReserve(uint256) external {}
}

contract QuantillonVaultMintCollateralizationAndLiquidationThresholdTest is Test {
    uint256 internal constant QEURO_DUST_THRESHOLD = 1e12;

    address internal admin = address(0xA11CE);
    address internal hedger = address(0xBEEF01);
    address internal bootstrapUser = address(0xB007);
    address internal attacker = address(0xBAD);
    address internal orphanedDustHolder = address(0xD057);

    MockUSDC internal usdc;
    QEUROToken internal qeuro;
    QuantillonVault internal vault;
    FixedOracle internal oracle;
    HedgerPoolHarness internal hedgerPool;

    function setUp() public {
        usdc = new MockUSDC();
        oracle = new FixedOracle();

        QEUROToken qeuroImpl = new QEUROToken();
        bytes memory qeuroInit = abi.encodeWithSelector(
            QEUROToken.initialize.selector,
            admin,
            address(0x1111), // placeholder vault
            address(0x2222), // placeholder timelock
            admin,           // treasury
            address(0x3333)  // fee collector
        );
        qeuro = QEUROToken(address(new ERC1967Proxy(address(qeuroImpl), qeuroInit)));

        QuantillonVault vaultImpl = new QuantillonVault();
        bytes memory vaultInit = abi.encodeWithSelector(
            QuantillonVault.initialize.selector,
            admin,
            address(qeuro),
            address(usdc),
            address(oracle),
            address(0),      // hedgerPool wired later
            address(0x4444), // non-zero userPool placeholder
            address(0x5555), // timelock
            address(0x6666)  // fee collector
        );
        vault = QuantillonVault(address(new ERC1967Proxy(address(vaultImpl), vaultInit)));

        hedgerPool = new HedgerPoolHarness(IERC20(address(usdc)), vault);

        vm.startPrank(admin);
        qeuro.grantRole(qeuro.MINTER_ROLE(), address(vault));
        qeuro.grantRole(qeuro.BURNER_ROLE(), address(vault));
        vault.updateHedgerPool(address(hedgerPool));
        vault.initializePriceCache(oracle.eurUsdPrice());
        vm.stopPrank();

        usdc.mint(hedger, 1_000_000e6);
        usdc.mint(bootstrapUser, 10_000e6);
        usdc.mint(attacker, 2_000_000e6);
    }

    function _seedHedgerMargin(uint256 amount) internal {
        vm.startPrank(hedger);
        usdc.approve(address(hedgerPool), amount);
        hedgerPool.seedMargin(amount);
        vm.stopPrank();
    }

    function _mintOrphanedDust(uint256 amount) internal {
        vm.prank(address(vault));
        qeuro.mint(orphanedDustHolder, amount);
    }

    function _reproduceOneWeiIncidentDust() internal {
        vm.startPrank(bootstrapUser);
        usdc.approve(address(vault), 1e6);
        vault.mintQEURO(1e6, 0);
        qeuro.transfer(orphanedDustHolder, 1);
        vault.redeemQEURO(1e18 - 1, 0);
        vm.stopPrank();

        assertEq(qeuro.totalSupply(), 1, "incident should leave one wei of QEURO supply");
        assertEq(vault.totalMinted(), 1, "vault tracker should retain the same one wei");
        assertEq(qeuro.balanceOf(orphanedDustHolder), 1, "dust should be stranded outside its former owner");
    }

    function test_OneWeiIncidentDust_AllowsOneUsdcMint() public {
        _seedHedgerMargin(50e6);
        _reproduceOneWeiIncidentDust();

        assertEq(vault.getProtocolCollateralizationRatio(), 0, "sub-USDC backing should keep the empty-state sentinel");
        assertFalse(vault.shouldTriggerLiquidation(), "dust-only supply must not trigger cached liquidation");
        (bool liveShouldLiquidate, uint256 liveRatio) = vault.shouldTriggerLiquidationLive();
        assertFalse(liveShouldLiquidate, "dust-only supply must not trigger live liquidation");
        assertEq(liveRatio, 0, "live ratio should preserve the empty-state sentinel");
        assertTrue(vault.canMint(), "bounded orphaned dust must not dead-lock minting");

        uint256 supplyBefore = qeuro.totalSupply();
        vm.startPrank(bootstrapUser);
        usdc.approve(address(vault), 1e6);
        vault.mintQEURO(1e6, 0);
        vm.stopPrank();

        assertEq(qeuro.balanceOf(bootstrapUser), 1e18, "one USDC should mint one QEURO at the fixed price");
        assertEq(qeuro.totalSupply(), supplyBefore + 1e18, "new mint should retain and account for the dust wei");
    }

    function test_DustBoundaryIsInclusive_AboveBoundaryUsesNormalCrGate() public {
        _seedHedgerMargin(1);
        _mintOrphanedDust(QEURO_DUST_THRESHOLD);

        assertEq(vault.getProtocolCollateralizationRatio(), 100e18, "one atomic USDC should give 100% CR");
        assertTrue(vault.canMint(), "the exact dust boundary should use bootstrap mint eligibility");

        vm.prank(address(vault));
        qeuro.burn(orphanedDustHolder, QEURO_DUST_THRESHOLD);
        _mintOrphanedDust(QEURO_DUST_THRESHOLD + 1);

        assertEq(vault.getProtocolCollateralizationRatio(), 100e18, "above-boundary fixture should remain at 100% CR");
        assertFalse(vault.canMint(), "supply above the dust boundary must use the normal 105% CR gate");

        vm.prank(bootstrapUser);
        usdc.approve(address(vault), 1e6);
        vm.prank(bootstrapUser);
        vm.expectRevert(CommonErrorLibrary.InsufficientCollateralization.selector);
        vault.mintQEURO(1e6, 0);
    }

    function test_DustEligibilityCannotBypassProjectedCollateralizationFloor() public {
        _seedHedgerMargin(50e6);
        _mintOrphanedDust(QEURO_DUST_THRESHOLD);
        assertTrue(vault.canMint(), "dust should pass only the pre-mint eligibility gate");

        uint256 undercollateralizingDeposit = 1_000_000e6;
        vm.prank(attacker);
        usdc.approve(address(vault), undercollateralizingDeposit);
        vm.prank(attacker);
        vm.expectRevert(CommonErrorLibrary.InsufficientCollateralization.selector);
        vault.mintQEURO(undercollateralizingDeposit, 0);
    }

    function test_PostMintCollateralizationCheck_BlocksMarginExtractionExploit() public {
        uint256 hedgerMargin = 50e6; // 50 USDC
        vm.startPrank(hedger);
        usdc.approve(address(hedgerPool), hedgerMargin);
        hedgerPool.seedMargin(hedgerMargin);
        vm.stopPrank();

        // Bootstrap at exactly 105% CR: 1,000 USDC user collateral + 50 USDC hedger margin
        uint256 bootstrapDeposit = 1_000e6;
        vm.prank(bootstrapUser);
        usdc.approve(address(vault), bootstrapDeposit);
        vm.prank(bootstrapUser);
        vault.mintQEURO(bootstrapDeposit, 0);

        // Large one-shot mint is allowed because canMint() checks only PRE-mint CR.
        uint256 attackerDeposit = 1_000_000e6;
        uint256 attackerUsdcBefore = usdc.balanceOf(attacker);

        vm.prank(attacker);
        usdc.approve(address(vault), attackerDeposit);
        vm.prank(attacker);
        vm.expectRevert(CommonErrorLibrary.InsufficientCollateralization.selector);
        vault.mintQEURO(attackerDeposit, 0);

        uint256 attackerUsdcAfter = usdc.balanceOf(attacker);
        assertEq(attackerUsdcAfter, attackerUsdcBefore, "attacker should not be able to execute exploit path");
    }

    function test_CriticalThresholdConfig_DrivesLiquidationRouting() public {
        // Lower critical threshold to 100% (while keeping mint threshold at 101%).
        vm.prank(admin);
        vault.updateCollateralizationThresholds(101e18, 100e18);

        // Build a 101% CR state: 1,000 USDC user collateral + 10 USDC hedger margin.
        uint256 hedgerMargin = 10e6;
        vm.startPrank(hedger);
        usdc.approve(address(hedgerPool), hedgerMargin);
        hedgerPool.seedMargin(hedgerMargin);
        vm.stopPrank();

        uint256 bootstrapDeposit = 1_000e6;
        vm.prank(bootstrapUser);
        usdc.approve(address(vault), bootstrapDeposit);
        vm.prank(bootstrapUser);
        vault.mintQEURO(bootstrapDeposit, 0);

        uint256 usdcBefore = usdc.balanceOf(bootstrapUser);

        // At CR = 101% and critical = 100%, redemption should stay in normal mode.
        // Normal mode payout for 100 QEURO at price 1.0 is exactly 100 USDC.
        uint256 redeemAmount = 100e18;
        vm.prank(bootstrapUser);
        vault.redeemQEURO(redeemAmount, 0);

        uint256 usdcAfter = usdc.balanceOf(bootstrapUser);
        uint256 received = usdcAfter - usdcBefore;
        assertEq(received, 100e6, "redeem should use normal mode when CR > configured critical threshold");
    }

    function test_RedeemRoutesToLiquidationWhenFreshPriceCrFallsBelowCritical() public {
        vm.prank(admin);
        vault.updateCollateralizationThresholds(101e18, 101e18);

        // Cached price is 1.0. Build cached CR = 101.1%:
        // 1,000 USDC user collateral + 11 USDC hedger margin backs 1,000 QEURO.
        uint256 hedgerMargin = 11e6;
        vm.startPrank(hedger);
        usdc.approve(address(hedgerPool), hedgerMargin);
        hedgerPool.seedMargin(hedgerMargin);
        vm.stopPrank();

        uint256 bootstrapDeposit = 1_000e6;
        vm.prank(bootstrapUser);
        usdc.approve(address(vault), bootstrapDeposit);
        vm.prank(bootstrapUser);
        vault.mintQEURO(bootstrapDeposit, 0);

        uint256 cachedCrBefore = vault.getProtocolCollateralizationRatio();
        assertGt(cachedCrBefore, vault.criticalCollateralizationRatio(), "cached CR should be above critical");

        uint256 livePrice = 1.019e18; // +1.9%, within the vault's 2% deviation guard.
        oracle.setPrices(livePrice, 1e18);
        vm.roll(block.number + 1);

        uint256 totalCollateralBefore = vault.getTotalUsdcAvailable();
        uint256 totalSupplyBefore = qeuro.totalSupply();
        uint256 freshBackingRequirement = (totalSupplyBefore * livePrice) / 1e18 / 1e12;
        uint256 freshCrBefore = (totalCollateralBefore * 1e20) / freshBackingRequirement;
        assertLt(freshCrBefore, vault.criticalCollateralizationRatio(), "fresh CR should be below critical");

        uint256 redeemAmount = 900e18;
        uint256 expectedNormalPayout = (redeemAmount * livePrice) / 1e18 / 1e12;
        uint256 expectedLiquidationPayout = (redeemAmount * totalCollateralBefore) / totalSupplyBefore;
        assertGt(expectedNormalPayout, expectedLiquidationPayout, "normal payout should exceed liquidation payout");

        uint256 hedgerMarginBefore = hedgerPool.totalMargin();
        uint256 usdcBefore = usdc.balanceOf(bootstrapUser);

        vm.prank(bootstrapUser);
        vault.redeemQEURO(redeemAmount, 0);

        uint256 received = usdc.balanceOf(bootstrapUser) - usdcBefore;
        uint256 expectedMarginLoss = (redeemAmount * hedgerMarginBefore) / totalSupplyBefore;

        assertEq(received, expectedLiquidationPayout, "redeem should use liquidation pro-rata payout");
        assertEq(hedgerPool.totalMargin(), hedgerMarginBefore - expectedMarginLoss, "hedger margin should be reduced");
    }

    function test_RedeemUsesNormalModeWhenFreshPriceCrStaysAboveCritical() public {
        vm.prank(admin);
        vault.updateCollateralizationThresholds(101e18, 101e18);

        uint256 hedgerMargin = 30e6;
        vm.startPrank(hedger);
        usdc.approve(address(hedgerPool), hedgerMargin);
        hedgerPool.seedMargin(hedgerMargin);
        vm.stopPrank();

        uint256 bootstrapDeposit = 1_000e6;
        vm.prank(bootstrapUser);
        usdc.approve(address(vault), bootstrapDeposit);
        vm.prank(bootstrapUser);
        vault.mintQEURO(bootstrapDeposit, 0);

        uint256 livePrice = 1.01e18; // Fresh CR remains above 101%.
        oracle.setPrices(livePrice, 1e18);
        vm.roll(block.number + 1);

        uint256 redeemAmount = 100e18;
        uint256 expectedNormalPayout = (redeemAmount * livePrice) / 1e18 / 1e12;
        uint256 usdcBefore = usdc.balanceOf(bootstrapUser);
        uint256 hedgerMarginBefore = hedgerPool.totalMargin();

        vm.prank(bootstrapUser);
        vault.redeemQEURO(redeemAmount, 0);

        uint256 received = usdc.balanceOf(bootstrapUser) - usdcBefore;
        assertEq(received, expectedNormalPayout, "redeem should use normal live-price payout");
        assertEq(hedgerPool.totalMargin(), hedgerMarginBefore, "normal redeem should not use liquidation accounting");
    }

    /// @notice Cached canMint() is false, yet a mint succeeds because the binding gate uses the live
    ///         price: when EUR/USD moves DOWN within the deviation guard, the live-price CR rises
    ///         above the mint threshold even though the cached-price CR is still below it.
    function test_CachedCanMintFalseButLivePriceMintSucceedsWhenEurMovesDown() public {
        // Bootstrap to ~106% CR at the initialized cached price of 1.0
        // (1,000 USDC user collateral + 60 USDC hedger margin backs 1,000 QEURO).
        uint256 hedgerMargin = 60e6;
        vm.startPrank(hedger);
        usdc.approve(address(hedgerPool), hedgerMargin);
        hedgerPool.seedMargin(hedgerMargin);
        vm.stopPrank();

        uint256 bootstrapDeposit = 1_000e6;
        vm.prank(bootstrapUser);
        usdc.approve(address(vault), bootstrapDeposit);
        vm.prank(bootstrapUser);
        vault.mintQEURO(bootstrapDeposit, 0);
        assertTrue(vault.canMint(), "canMint should be true right after bootstrap");

        // Bump the CACHED price up 1.5% (within the 2% guard) by committing it via a tiny redeem.
        // This drops the cached-price CR to ~104.4%, just below the 105% mint threshold.
        oracle.setPrices(1.015e18, 1e18);
        vm.roll(block.number + 1);
        vm.prank(bootstrapUser);
        vault.redeemQEURO(1e18, 0);

        uint256 mintThreshold = vault.minCollateralizationRatioForMinting();
        assertLt(vault.getProtocolCollateralizationRatio(), mintThreshold, "cached CR should be below mint threshold");
        assertFalse(vault.canMint(), "cached canMint() must be false");

        // EUR/USD now moves DOWN ~1.5% from the cached price (within the 2% deviation guard).
        // A lower EUR price means a smaller backing requirement, so the live-price CR rises above 105%.
        uint256 livePrice = 0.99978e18;
        oracle.setPrices(livePrice, 1e18);
        vm.roll(block.number + 1);

        uint256 totalCollateral = vault.getTotalUsdcAvailable();
        uint256 supply = qeuro.totalSupply();
        uint256 liveBackingRequirement = (supply * livePrice) / 1e18 / 1e12;
        uint256 liveCr = (totalCollateral * 1e20) / liveBackingRequirement;
        assertGe(liveCr, mintThreshold, "live-price CR should be at/above mint threshold");

        // The binding mint gate uses the live price, so a small mint SUCCEEDS even though the public
        // cached canMint() reports false.
        uint256 supplyBefore = qeuro.totalSupply();
        vm.prank(bootstrapUser);
        usdc.approve(address(vault), 1e6);
        vm.prank(bootstrapUser);
        vault.mintQEURO(1e6, 0);
        assertGt(qeuro.totalSupply(), supplyBefore, "live-price mint should succeed despite cached canMint() == false");
    }

    /// @notice shouldTriggerLiquidationLive() reflects the live oracle price and can diverge from the
    ///         cached shouldTriggerLiquidation() near the critical threshold (Bertie's scenario): the
    ///         cached view says "not liquidation" while the live view says "liquidation".
    function test_ShouldTriggerLiquidationLiveDivergesFromCachedNearThreshold() public {
        // Mint threshold == critical == 101% so we can bootstrap a CR just above critical.
        vm.prank(admin);
        vault.updateCollateralizationThresholds(101e18, 101e18);

        // Build cached CR = 101.1% at the cached price of 1.0
        // (1,000 USDC user collateral + 11 USDC hedger margin backs 1,000 QEURO).
        uint256 hedgerMargin = 11e6;
        vm.startPrank(hedger);
        usdc.approve(address(hedgerPool), hedgerMargin);
        hedgerPool.seedMargin(hedgerMargin);
        vm.stopPrank();

        uint256 bootstrapDeposit = 1_000e6;
        vm.prank(bootstrapUser);
        usdc.approve(address(vault), bootstrapDeposit);
        vm.prank(bootstrapUser);
        vault.mintQEURO(bootstrapDeposit, 0);

        uint256 critical = vault.criticalCollateralizationRatio();
        assertGt(vault.getProtocolCollateralizationRatio(), critical, "cached CR should be above critical");

        // EUR/USD moves UP 1.9% (within the 2% deviation guard) but is NOT committed to the cache.
        // The live-price CR (~99.2%) falls at/below critical while the cached CR (101.1%) stays above.
        oracle.setPrices(1.019e18, 1e18);

        // Cached view: still reports NOT in liquidation.
        assertFalse(vault.shouldTriggerLiquidation(), "cached shouldTriggerLiquidation() should be false");

        // Live view: reports IN liquidation, and the two predicates disagree.
        (bool liveShouldLiquidate, uint256 liveRatio) = vault.shouldTriggerLiquidationLive();
        assertTrue(liveShouldLiquidate, "live shouldTriggerLiquidationLive() should be true");
        assertGt(liveRatio, 0, "live ratio should be non-zero");
        assertLe(liveRatio, critical, "live ratio should be at/below critical");
        assertTrue(
            liveShouldLiquidate != vault.shouldTriggerLiquidation(),
            "live and cached liquidation predicates must diverge near the threshold"
        );
    }
}
