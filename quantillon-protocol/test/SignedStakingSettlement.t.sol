// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {StQEUROYieldDistributionTest} from "./StQEUROYieldDistribution.t.sol";
import {SignedExecutionPricing} from "../src/oracle/SignedExecutionPricing.sol";
import {SignedReferenceSource} from "../src/oracle/SignedReferenceSource.sol";
import {SignedQuoteTypes as T} from "../src/libraries/SignedQuoteTypes.sol";
import {SignedQuoteErrors as E} from "../src/libraries/SignedQuoteErrors.sol";

/// @dev Real vault, QEURO and stQEURO proxies with a mocked external yield adapter.
contract SignedStakingSettlementTest is StQEUROYieldDistributionTest {
    uint256 private constant KEY = 0x12345;
    SignedReferenceSource private source;
    SignedExecutionPricing private pricing;

    function peekEurUsdPrice() external view returns (uint256, uint256, bool) {
        return (1e18, block.timestamp, true);
    }

    function _prepareSignedStaking(bool seed) private {
        vm.warp(1_000_000); vm.roll(100); vm.setBlockhash(99, keccak256("canonical"));
        _setUpStaking(); oracle.setPrice(1e18);
        vm.startPrank(admin);
        vault.updatePriceCache(); vault.updateParameters(0, 0);
        vm.stopPrank();
        if (seed) _seedPositions(50e6, 50e6);
        source = new SignedReferenceSource(address(this), address(this), 60, 8100, 200, 300);
        pricing = new SignedExecutionPricing(address(this), address(vault), address(source), admin, 25, 1000e18, 60, 25);
        source.grantRole(source.REFERENCE_SIGNER_ROLE(), vm.addr(KEY));
        source.grantRole(source.EMERGENCY_CONTROLLER_ROLE(), address(pricing));
        pricing.grantRole(pricing.QUOTE_SIGNER_ROLE(), vm.addr(KEY));
        pricing.grantRole(pricing.CAPACITY_SIGNER_ROLE(), vm.addr(KEY));
        pricing.setMode(T.Mode.Signed);
        vm.startPrank(admin);
        vault.pause(); vault.configureExecutionPricing(address(pricing)); vault.unpause();
        vm.stopPrank();
    }

    function _sign(bytes32 digest) private view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    function _authorization(address caller, T.Action action, bytes memory data, uint256 maximum, uint256 nonce)
        private view returns (bytes memory)
    {
        T.Authorization memory a;
        a.referenceReport = T.ReferenceReport(1e18, block.timestamp, nonce, source.epoch());
        a.referenceSignature = _sign(source.digest(a.referenceReport));
        a.capacityReport = T.CapacityReport(0, 0, 1000e18, block.timestamp, nonce, pricing.epoch(), 99, keccak256("canonical"));
        a.capacitySignature = _sign(pricing.capacityDigest(a.capacityReport));
        a.quote = T.Quote(caller, caller, action, maximum, maximum * 1e12, block.timestamp, block.timestamp,
            block.timestamp + 20, nonce, pricing.epoch(), keccak256(data), source.digest(a.referenceReport));
        a.signature = _sign(pricing.quoteDigest(a.quote));
        return abi.encode(a);
    }

    function test_SignedMintAndStakePreservesShareOwnershipAndPrincipal() public {
        _prepareSignedStaking(false);
        uint256 principalBefore = vault.totalUsdcInExternalVaults();
        bytes memory data = abi.encodeWithSignature("mintAndStakeQEURO(uint256,uint256,uint256,uint256)", 100e6, 100e18, VAULT_ID, 1);
        bytes memory auth = _authorization(user, T.Action.Mint, data, 100e6, 1);
        vm.startPrank(user); usdc.approve(address(vault), 100e6);
        (uint256 minted, uint256 shares) = abi.decode(vault.executeWithQuote(data, auth), (uint256, uint256));
        vm.stopPrank();
        assertEq(minted, 100e18); assertGt(shares, 0); assertEq(stToken.balanceOf(user), shares);
        assertEq(qeuro.balanceOf(user), 0); assertEq(qeuro.balanceOf(address(stToken)), minted);
        assertEq(vault.totalUsdcInExternalVaults() - principalBefore, 100e6);
        assertEq(pricing.outstanding(), minted);
    }

    function test_SignedStakeMinimumFailureRollsBackMintAndReservation() public {
        _prepareSignedStaking(false);
        uint256 shares = stToken.previewDeposit(100e18);
        bytes memory data = abi.encodeWithSignature("mintAndStakeQEURO(uint256,uint256,uint256,uint256)", 100e6, 100e18, VAULT_ID, shares + 1);
        bytes memory auth = _authorization(user, T.Action.Mint, data, 100e6, 1);
        uint256 beforeUsdc = usdc.balanceOf(user);
        vm.startPrank(user); usdc.approve(address(vault), 100e6);
        vm.expectRevert(); vault.executeWithQuote(data, auth); vm.stopPrank();
        assertEq(usdc.balanceOf(user), beforeUsdc); assertEq(qeuro.totalSupply(), 0);
        assertEq(stToken.balanceOf(user), 0); assertFalse(pricing.usedNonces(user, 1));
    }

    function test_SignedHarvestUsesActualYieldAndPreservesVesting() public {
        _prepareSignedStaking(true); mockAaveVault.setAccruedYield(110e6);
        uint256 userShare = vault.previewVaultYieldDistribution(VAULT_ID).userShare;
        assertEq(userShare, 55e6);
        bytes memory data = abi.encodeWithSignature("harvestAndDistributeVaultYield(uint256)", VAULT_ID);
        bytes memory auth = _authorization(admin, T.Action.Yield, data, 60e6, 1);
        uint256 beforeBalance = qeuro.balanceOf(address(stToken));
        uint256 beforeRedeemable = stToken.totalAssets();
        uint256 beforeHeld = vault.totalUsdcHeld();
        vm.prank(admin); vault.executeWithQuote(data, auth);
        assertEq(qeuro.balanceOf(address(stToken)) - beforeBalance, userShare * 1e12);
        assertEq(vault.totalUsdcHeld() - beforeHeld, userShare);
        assertEq(pricing.outstanding(), userShare * 1e12, "unused authorization is not minted");
        stToken.syncVesting(); assertEq(stToken.totalAssets(), beforeRedeemable);
        vm.warp(block.timestamp + stToken.vestingPeriod());
        assertEq(stToken.totalAssets(), beforeRedeemable + userShare * 1e12);
    }

    function test_SignedHarvestExcessRevertsExternalHarvestAndNonce() public {
        _prepareSignedStaking(true); mockAaveVault.setAccruedYield(110e6);
        bytes memory data = abi.encodeWithSignature("harvestAndDistributeVaultYield(uint256)", VAULT_ID);
        bytes memory auth = _authorization(admin, T.Action.Yield, data, 54e6, 1);
        uint256 beforeSupply = qeuro.totalSupply();
        vm.prank(admin); vm.expectRevert(E.InvalidAmount.selector); vault.executeWithQuote(data, auth);
        assertEq(mockAaveVault.accruedYield(), 110e6); assertEq(qeuro.totalSupply(), beforeSupply);
        assertFalse(pricing.usedNonces(admin, 1)); assertEq(pricing.outstanding(), 0);
    }

    function test_SignedZeroHarvestConsumesAuthorizationWithoutExposure() public {
        _prepareSignedStaking(true);
        bytes memory data = abi.encodeWithSignature("harvestAndDistributeVaultYield(uint256)", VAULT_ID);
        bytes memory auth = _authorization(admin, T.Action.Yield, data, 1, 1);
        uint256 beforeSupply = qeuro.totalSupply();
        vm.prank(admin); vault.executeWithQuote(data, auth);
        assertEq(qeuro.totalSupply(), beforeSupply); assertTrue(pricing.usedNonces(admin, 1));
        assertEq(pricing.outstanding(), 0); assertFalse(pricing.active());
    }

    function test_SignedHarvestDoesNotGrantKeeperRole() public {
        _prepareSignedStaking(true); mockAaveVault.setAccruedYield(110e6);
        bytes memory data = abi.encodeWithSignature("harvestAndDistributeVaultYield(uint256)", VAULT_ID);
        bytes memory auth = _authorization(user, T.Action.Yield, data, 60e6, 1);
        vm.prank(user); vm.expectPartialRevert(bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)")));
        vault.executeWithQuote(data, auth);
        assertEq(mockAaveVault.accruedYield(), 110e6); assertFalse(pricing.usedNonces(user, 1));
    }
}
