// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {StakingYieldLibrary} from "../src/libraries/StakingYieldLibrary.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";
import {MockAaveVault} from "./AaveIntegration.t.sol";
import {Vm} from "forge-std/Vm.sol";

import {AaveIntegrationTest} from "./AaveIntegration.t.sol";
import {QuantillonVault} from "../src/core/QuantillonVault.sol";
import {stQEUROFactory} from "../src/core/stQEUROFactory.sol";
import {stQEUROToken} from "../src/core/stQEUROToken.sol";

/// @notice Capital ownership, haircut, settlement and upgrade-compatibility regressions.
contract StQEUROYieldDistributionTest is AaveIntegrationTest {
    stQEUROFactory internal factory;
    stQEUROToken internal stToken;

    uint256 internal constant VAULT_ID = 1; // the Aave-mock staking vault wired in AaveIntegrationTest.setUp
    address internal hedgerSink = address(0xBEEF);

    /// @notice Deploys an stQEURO series for VAULT_ID and configures the distribution parameters.
    function _setUpStaking() internal {
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
        stToken = stQEUROToken(vault.selfRegisterStQEURO(address(factory), VAULT_ID, "AAVE"));

        vault.grantRole(vault.YIELD_DISTRIBUTOR_ROLE(), admin);
        vault.setHedgerStakingYieldHaircutBps(0);
        vault.setHedgerYieldRecipient(hedgerSink);

        usdc.mint(user, 200_000e6); // extra USDC for mint + stake below
        vm.stopPrank();
    }

    /// @notice Builds an unstaked QEURO balance + a staked stQEURO position, both deploying principal.
    function _seedPositions(uint256 unstakedUsdc, uint256 stakeUsdc) internal returns (uint256 stShares) {
        vm.startPrank(user);
        usdc.approve(address(vault), unstakedUsdc + stakeUsdc);
        vault.mintQEURO(unstakedUsdc, 0); // unstaked circulating QEURO + principal to VAULT_ID
        (, stShares) = vault.mintAndStakeQEURO(stakeUsdc, 0, VAULT_ID, 1); // staked QEURO + principal
        vm.stopPrank();
        assertGt(stShares, 0, "user holds a staked position");
    }

    /// @notice Primes the funding clock so the next distribution accrues a non-zero hedger share.
    function _prime() internal {
        vm.prank(admin);
        vault.harvestAndDistributeVaultYield(VAULT_ID);
    }

    /// @notice Triggers harvest+distribute (as admin) and returns the split decoded from the
    ///         VaultYieldDistributed event (the function no longer returns the values).
    function _distribute()
        internal
        returns (uint256 realized, uint256 hedgerShare, uint256 userShare, uint256 treasuryShare)
    {
        vm.recordLogs();
        vm.prank(admin);
        vault.harvestAndDistributeVaultYield(VAULT_ID);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 sig = keccak256("VaultYieldDistributed(uint256,uint256,uint256,uint256,uint256)");
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == sig) {
                return abi.decode(logs[i].data, (uint256, uint256, uint256, uint256));
            }
        }
        revert("VaultYieldDistributed not emitted");
    }


    function _example(uint256 haircut) internal {
        _setUpStaking();
        oracle.setPrice(1e18);
        vm.startPrank(admin);
        vault.updatePriceCache();
        vault.setHedgerStakingYieldHaircutBps(haircut);
        vm.stopPrank();
        vm.mockCall(address(hedgerPool), abi.encodeWithSignature("getTotalEffectiveHedgerCollateral(uint256)", 1e18), abi.encode(1000e6));
        _seedPositions(50e6, 50e6);
        mockAaveVault.setAccruedYield(110e6);
    }

    function _checkExample(uint256 haircut, uint256 expectedHaircut) internal {
        _example(haircut);
        StakingYieldLibrary.Split memory preview = vault.previewVaultYieldDistribution(VAULT_ID);
        assertEq(preview.hedgerBase, 100e6);
        assertEq(preview.haircut, expectedHaircut);
        uint256 beforeAssets = qeuro.balanceOf(address(stToken));
        uint256 beforeRedeemable = stToken.totalAssets();
        uint256 beforeHeld = vault.totalUsdcHeld();
        (uint256 realized, uint256 h, uint256 u, uint256 t) = _distribute();
        assertEq(realized, 110e6);
        assertEq(h, 100e6 + expectedHaircut);
        assertEq(u, 5e6 - expectedHaircut);
        assertEq(t, 5e6);
        assertEq(h + u + t, realized);
        assertEq(usdc.balanceOf(hedgerSink), h);
        assertEq(qeuro.balanceOf(address(stToken)) - beforeAssets, u * 1e12);
        assertEq(vault.totalUsdcHeld() - beforeHeld, u);
        stToken.syncVesting();
        assertEq(stToken.totalAssets(), beforeRedeemable, "vesting does not unlock immediately");
        vm.warp(block.timestamp + stToken.vestingPeriod());
        assertEq(stToken.totalAssets(), beforeRedeemable + u * 1e12);
        (uint256 legacyRate,, uint256 last) = vault.harvestConfig(VAULT_ID);
        assertEq(legacyRate, 0);
        assertGt(last, 0);
    }

    function test_exampleZero() public { _checkExample(0, 0); }
    function test_exampleOnePercent() public { _checkExample(100, 50_000); }
    function test_exampleTwoPercent() public { _checkExample(200, 100_000); }
    function test_exampleHundredPercent() public { _checkExample(10000, 5e6); }

    function test_feeAfterHaircut() public {
        _example(200);
        vm.prank(admin);
        stToken.updateYieldParameters(1000);
        uint256 beforeTreasury = usdc.balanceOf(treasury);
        uint256 beforeAssets = qeuro.balanceOf(address(stToken));
        _distribute();
        assertEq(usdc.balanceOf(treasury) - beforeTreasury, 5e6 + 490_000);
        assertEq(qeuro.balanceOf(address(stToken)) - beforeAssets, 4.41e18);
    }

    function test_unvestedYieldRemainsStakerOwned() public {
        _example(0);
        _distribute();
        stToken.syncVesting();
        assertEq(stToken.totalAssets(), 50e18);
        assertEq(qeuro.balanceOf(address(stToken)), 55e18);
        mockAaveVault.setAccruedYield(110e6);
        StakingYieldLibrary.Split memory s = vault.previewVaultYieldDistribution(VAULT_ID);
        uint256 residual = 110e6 - uint256(110e6) * 1000e6 / 1105e6;
        assertEq(s.userShare, residual * 55 / 105);
    }

    function test_secondShareholderSharesRedeemableGain() public {
        _example(0);
        address second = address(0x12345);
        vm.startPrank(user);
        stToken.transfer(second, stToken.balanceOf(user) / 2);
        vm.stopPrank();
        _distribute();
        stToken.syncVesting();
        vm.warp(block.timestamp + stToken.vestingPeriod());
        assertApproxEqAbs(stToken.previewRedeem(stToken.balanceOf(user)), 27.5e18, 2);
        assertApproxEqAbs(stToken.previewRedeem(stToken.balanceOf(second)), 27.5e18, 2);
    }

    function test_harvestSnapshotReflectsNewStakeAndOraclePrice() public {
        _example(0);
        oracle.setPrice(1.2e18);
        vm.mockCall(address(hedgerPool), abi.encodeWithSignature("getTotalEffectiveHedgerCollateral(uint256)", 1.2e18), abi.encode(980e6));
        StakingYieldLibrary.Split memory s = vault.previewVaultYieldDistribution(VAULT_ID);
        assertEq(s.hedgerBase, 98e6);
        assertEq(s.userShare, 6e6);
        vm.startPrank(user);
        qeuro.approve(address(stToken), 50e18);
        stToken.deposit(50e18, user);
        vm.stopPrank();
        s = vault.previewVaultYieldDistribution(VAULT_ID);
        assertEq(s.userShare, 12e6);
        assertEq(s.treasuryShare, 0);
    }

    function test_missingRecipientRollsBackHarvest() public {
        _example(200);
        // Mock only the configuration read: represent an existing proxy with an unset recipient.
        vm.mockCall(address(vault), abi.encodeWithSelector(vault.yieldDistributionConfig.selector, VAULT_ID), abi.encode(200, address(0), 0));
        (, , uint256 principal, uint256 underlying) = vault.getVaultExposure(VAULT_ID);
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        vm.prank(admin);
        vault.harvestAndDistributeVaultYield(VAULT_ID);
        (, , uint256 principalAfter, uint256 underlyingAfter) = vault.getVaultExposure(VAULT_ID);
        assertEq(principalAfter, principal);
        assertEq(underlyingAfter, underlying);
        (,,uint256 last) = vault.harvestConfig(VAULT_ID);
        assertEq(last, 0);
    }

    function test_creditFailureRollsBackTransfersAndClock() public {
        _example(200);
        vm.mockCallRevert(address(qeuro), abi.encodeWithSignature("mint(address,uint256)"), abi.encodeWithSignature("Error(string)", "mint blocked"));
        uint256 beforeHedger = usdc.balanceOf(hedgerSink);
        uint256 beforeTreasury = usdc.balanceOf(treasury);
        vm.expectRevert();
        vm.prank(admin);
        vault.harvestAndDistributeVaultYield(VAULT_ID);
        assertEq(usdc.balanceOf(hedgerSink), beforeHedger);
        assertEq(usdc.balanceOf(treasury), beforeTreasury);
        (,,uint256 last) = vault.harvestConfig(VAULT_ID);
        assertEq(last, 0);
        (,,uint256 principal,uint256 underlying) = vault.getVaultExposure(VAULT_ID);
        assertEq(underlying-principal, 110e6);
    }

    function test_rejectsOtherFundedStrategy() public {
        _example(0);
        vm.startPrank(admin);
        MockAaveVault other = new MockAaveVault(address(usdc));
        vault.setStakingVault(2, address(other), true);
        uint256[] memory ids = new uint256[](2); ids[0] = 1; ids[1] = 2;
        vault.setRedemptionPriority(ids);
        vault.grantRole(vault.VAULT_OPERATOR_ROLE(), admin);
        vault.deployUsdcToVault(2, 1e6);
        vm.expectRevert(CommonErrorLibrary.InvalidCondition.selector);
        vault.harvestAndDistributeVaultYield(VAULT_ID);
        vm.stopPrank();
    }

    function test_rejectsOtherStakingSharesEvenWithoutDeployedCapital() public {
        _example(0);
        vm.prank(admin);
        stQEUROToken other = stQEUROToken(vault.selfRegisterStQEURO(address(factory), 2, "OTHER"));
        vm.startPrank(user);
        qeuro.approve(address(other), 1e18);
        other.deposit(1e18, user);
        vm.stopPrank();
        vm.expectRevert(CommonErrorLibrary.InvalidCondition.selector);
        vault.previewVaultYieldDistribution(VAULT_ID);
    }

    function test_invalidOracleFailsClosed() public {
        _example(0);
        vm.mockCall(address(oracle), abi.encodeWithSignature("getEurUsdPrice()"), abi.encode(1e18, false));
        vm.expectRevert(CommonErrorLibrary.InvalidOraclePrice.selector);
        vault.previewVaultYieldDistribution(VAULT_ID);
    }

    function test_governanceBoundariesAndRetiredSetter() public {
        _setUpStaking();
        assertEq(vault.hedgerStakingYieldHaircutBps(), 0);
        vm.expectRevert(); vm.prank(user); vault.setHedgerStakingYieldHaircutBps(200);
        vm.expectRevert(); vm.prank(user); vault.harvestAndDistributeVaultYield(VAULT_ID);
        vm.startPrank(admin);
        vm.expectRevert(CommonErrorLibrary.AboveLimit.selector); vault.setHedgerStakingYieldHaircutBps(10001);
        vm.expectRevert(CommonErrorLibrary.InvalidCondition.selector); vault.setFundingRateAnnualBps(200);
        vm.expectEmit(false, false, false, true, address(vault));
        emit QuantillonVault.HedgerStakingYieldHaircutUpdated(0, 200);
        vault.setHedgerStakingYieldHaircutBps(200);
        vm.stopPrank();
    }

    function test_zeroYieldUpdatesKeeperClockWithoutPayment() public {
        _setUpStaking();
        (uint256 y,uint256 h,uint256 u,uint256 t) = _distribute();
        assertEq(y+h+u+t, 0);
        (,,uint256 last) = vault.harvestConfig(VAULT_ID);
        assertEq(last, block.timestamp);
    }

    function test_noStakersAndNoSupply() public {
        _setUpStaking();
        mockAaveVault.setAccruedYield(110e6);
        (uint256 y,uint256 h,uint256 u,uint256 t) = _distribute();
        assertEq(y, 110e6); assertEq(h, y); assertEq(u+t, 0);
    }

    function test_unstakingAllRoutesUserBackingYieldToTreasury() public {
        _example(200);
        uint256 shares = stToken.balanceOf(user);
        vm.prank(user);
        stToken.redeem(shares, user, user);
        (uint256 y,uint256 h,uint256 u,uint256 t) = _distribute();
        assertEq(y, 110e6); assertEq(h, 100e6); assertEq(u, 0); assertEq(t, 10e6);
    }

    function test_cannotSwitchFactoryAndHideExistingShareholders() public {
        _example(0);
        vm.prank(admin);
        vm.expectRevert(CommonErrorLibrary.InvalidCondition.selector);
        vault.selfRegisterStQEURO(address(0x1234), 3, "HIDDEN");
        assertEq(vault.stQEUROFactory(), address(factory));
    }

    function test_orphanYieldGoesToTreasury() public {
        StakingYieldLibrary.Capital memory c;
        StakingYieldLibrary.Split memory s = StakingYieldLibrary.calculateSplit(110e6, c, 200);
        assertEq(s.treasuryShare, 110e6); assertEq(s.hedgerShare+s.userShare, 0);
    }

    function testFuzz_conservationAndHaircutBound(uint96 y, uint96 h, uint96 u, uint96 supply, uint96 staked, uint16 bps) public pure {
        bps = uint16(uint256(bps) % 10001);
        StakingYieldLibrary.Capital memory c = StakingYieldLibrary.Capital(h, u, staked, supply);
        StakingYieldLibrary.Split memory s = StakingYieldLibrary.calculateSplit(y, c, bps);
        assertEq(s.hedgerShare+s.userShare+s.treasuryShare, y);
        assertLe(s.haircut, s.userShare+s.haircut);
        assertEq(s.hedgerShare, s.hedgerBase+s.haircut);
    }
}
