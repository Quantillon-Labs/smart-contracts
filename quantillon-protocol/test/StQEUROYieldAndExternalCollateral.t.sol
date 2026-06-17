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
}
