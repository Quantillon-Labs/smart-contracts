// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {AaveIntegrationTest} from "./AaveIntegration.t.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";
import {stQEUROFactory} from "../src/core/stQEUROFactory.sol";
import {stQEUROToken} from "../src/core/stQEUROToken.sol";

/**
 * @title StQEUROYieldAndExternalCollateralTest
 * @notice Regression tests for the stQEURO empty-vault yield guard (a positive deposit can never
 *         mint zero shares) and for external-vault redemption collateral being limited to the
 *         withdrawable tracked principal.
 */
contract StQEUROYieldAndExternalCollateralTest is AaveIntegrationTest {
    stQEUROFactory internal factory;
    stQEUROToken internal stToken;

    uint256 internal constant VAULT_ID = 1;
    uint256 internal constant YIELD_USDC = 1_080e6;
    uint256 internal constant STAKE_USDC = 1_080e6;

    function _setUpStQEURO() internal {
        vm.startPrank(admin);
        stQEUROToken tokenImplementation = new stQEUROToken(timeProvider);
        stQEUROFactory factoryImplementation = new stQEUROFactory();
        factory = stQEUROFactory(
            address(
                new ERC1967Proxy(
                    address(factoryImplementation),
                    abi.encodeWithSelector(
                        stQEUROFactory.initialize.selector,
                        admin,
                        address(tokenImplementation),
                        address(qeuro),
                        address(0xCAFE),
                        address(usdc),
                        treasury,
                        treasury,
                        address(oracle)
                    )
                )
            )
        );

        factory.grantRole(factory.VAULT_FACTORY_ROLE(), address(vault));
        address stTokenAddress = vault.selfRegisterStQEURO(address(factory), VAULT_ID, "AAVE");
        stToken = stQEUROToken(stTokenAddress);

        vault.grantRole(vault.YIELD_DISTRIBUTOR_ROLE(), admin);
        vm.stopPrank();
    }

    // ---- stQEURO empty-vault yield guard ----

    /// @notice Crediting yield into an stQEURO vault with no shares must revert (was: minted into empty vault).
    function test_CreditYieldRevertsWhenNoStQEUROShares() public {
        _setUpStQEURO();

        vm.startPrank(admin);
        usdc.mint(admin, YIELD_USDC);
        usdc.approve(address(vault), YIELD_USDC);
        vm.expectRevert(CommonErrorLibrary.NotInitialized.selector);
        vault.creditVaultYield(VAULT_ID, YIELD_USDC);
        vm.stopPrank();

        assertEq(stToken.totalSupply(), 0, "no shares were created");
        assertEq(stToken.totalAssets(), 0, "no orphaned assets in the empty vault");
    }

    /// @notice The first stake mints shares 1:1, after which yield can be credited normally.
    function test_FirstStakeThenYieldCreditSucceeds() public {
        _setUpStQEURO();

        vm.startPrank(user);
        usdc.approve(address(vault), STAKE_USDC);
        (uint256 qeuroMinted, uint256 stMinted) = vault.mintAndStakeQEURO(STAKE_USDC, 0, VAULT_ID, 1);
        vm.stopPrank();

        assertGt(stMinted, 0, "first staker receives shares");
        assertGt(qeuroMinted, 0, "first staker minted QEURO");
        assertEq(stToken.balanceOf(user), stMinted, "user holds a redeemable position");

        vm.startPrank(admin);
        usdc.mint(admin, YIELD_USDC);
        usdc.approve(address(vault), YIELD_USDC);
        uint256 credited = vault.creditVaultYield(VAULT_ID, YIELD_USDC);
        vm.stopPrank();
        assertGt(credited, 0, "yield credits once there is a share holder");
    }

    // ---- external-vault redemption collateral ----

    /// @notice Liquidation redemption succeeds when external yield has accrued: availability now
    ///         equals withdrawable principal, so the payout is never sized against unharvested yield.
    function test_LiquidationRedeemSucceedsWithAccruedExternalYield() public {
        uint256 depositAmount = 10_000e6;

        vm.startPrank(user);
        usdc.approve(address(userPool), depositAmount);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = depositAmount;
        uint256[] memory minOuts = new uint256[](1);
        minOuts[0] = 0;
        userPool.deposit(amounts, minOuts);
        vm.stopPrank();

        uint256 qeuroBalance = qeuro.balanceOf(user);
        uint256 principalTracked = vault.totalUsdcInExternalVaults();
        uint256 heldBefore = vault.totalUsdcHeld();
        assertEq(principalTracked, depositAmount, "principal tracker only includes deployed principal");

        // Accrue external yield that the withdrawal path cannot release.
        mockAaveVault.setAccruedYield(500e6);

        // Availability excludes unharvested external yield (== withdrawable principal).
        uint256 totalAvailable = vault.getTotalUsdcAvailable();
        assertEq(totalAvailable, heldBefore + principalTracked, "availability excludes unharvested external yield");

        // Drive the protocol into liquidation mode against that same collateral base.
        uint256 liquidationPrice = (totalAvailable * 1e30) / qeuro.totalSupply();
        oracle.setPrice(liquidationPrice);
        (bool shouldLiquidate,) = vault.shouldTriggerLiquidationLive();
        assertTrue(shouldLiquidate, "redemption route should enter liquidation mode");

        // The full redemption must now succeed (previously reverted with InsufficientBalance).
        uint256 userUsdcBefore = usdc.balanceOf(user);
        vm.startPrank(user);
        qeuro.approve(address(vault), qeuroBalance);
        vault.redeemQEURO(qeuroBalance, 0);
        vm.stopPrank();

        assertEq(qeuro.balanceOf(user), 0, "user fully redeemed their QEURO");
        assertGt(usdc.balanceOf(user), userUsdcBefore, "user received USDC payout");
        assertEq(vault.totalUsdcInExternalVaults(), 0, "external principal drained to satisfy redemption");
    }

    // ---- yield credit uses the 100% floor, not the 105% mint floor ----

    /// @notice At a CR above the 105% mint floor, a credit whose projected CR lands in [100%,105%)
    ///         is accepted (credit is gated on a 100% floor because it adds fully-backed 1:1
    ///         collateral), whereas a same-sized mint at the same state reverts on the 105% floor.
    function test_creditVaultYield_succeedsAtProjectedCrBelowMintFloor() public {
        _setUpStQEURO();

        // Create at least one stQEURO share holder and some outstanding QEURO.
        vm.startPrank(user);
        usdc.approve(address(vault), STAKE_USDC);
        vault.mintAndStakeQEURO(STAKE_USDC, 0, VAULT_ID, 1);
        vm.stopPrank();

        uint256 collateral = vault.getTotalUsdcAvailable();
        uint256 supply = qeuro.totalSupply();

        // Position the live price so the current CR sits ~110% — comfortably above the 105% mint
        // floor, so mint *eligibility* passes and the only thing that can differ is the projected floor.
        uint256 price = (collateral * 1e30 * 100) / (supply * 110);
        oracle.setPrice(price);

        // Sanity (test-side, live price): current CR is just above the mint floor.
        uint256 currentCr = (collateral * 1e50) / (supply * price);
        assertGt(currentCr, 106e18, "current CR must clear the 105% mint floor");
        assertLt(currentCr, 114e18, "current CR positioned just above the floor");

        // From ~110%, a credit/mint of 4x the current backing drives projected CR to ~102%
        // (inside [100%,105%): below the mint floor, above the yield-credit floor).
        uint256 backing = (supply * price / 1e18) / 1e12;
        uint256 amount = 4 * backing;

        // A fresh mint of `amount` reverts: projected CR < 105% mint floor.
        usdc.mint(user, amount);
        vm.startPrank(user);
        usdc.approve(address(vault), amount);
        vm.expectRevert(CommonErrorLibrary.InsufficientCollateralization.selector);
        vault.mintQEURO(amount, 0);
        vm.stopPrank();

        // The same-sized yield credit succeeds: gated on the 100% floor, not 105%.
        usdc.mint(admin, amount);
        vm.startPrank(admin);
        usdc.approve(address(vault), amount);
        uint256 credited = vault.creditVaultYield(VAULT_ID, amount);
        vm.stopPrank();
        assertGt(credited, 0, "yield credit must succeed where a same-sized mint reverts on the mint floor");
    }
}
