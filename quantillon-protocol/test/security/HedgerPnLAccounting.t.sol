// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {HedgerVaultRegressionTest} from "../HedgerVaultRegression.t.sol";
import {HedgerPool} from "../../src/core/HedgerPool.sol";
import {CommonErrorLibrary} from "../../src/libraries/CommonErrorLibrary.sol";
import {HedgerPoolErrorLibrary} from "../../src/libraries/HedgerPoolErrorLibrary.sol";
import {stdStorage, StdStorage} from "forge-std/StdStorage.sol";

contract HedgerPnLAccountingTest is HedgerVaultRegressionTest {
    using stdStorage for StdStorage;
    function _prepare() internal {
        vm.prank(admin);
        vault.updateParameters(0, 0);
        vm.prank(hedger);
        hedgerPool.enterHedgePosition(200e6, 10);
        vm.prank(user);
        vault.mintQEURO(1100e6, 1000e18);
        vm.prank(user);
        qeuro.approve(address(vault), type(uint256).max);
        vm.roll(block.number + 10);
    }

    function _price(int256 price) internal {
        vm.mockCall(address(0x123), abi.encodeWithSelector(bytes4(0xfeaf968c)),
            abi.encode(uint80(1), price, block.timestamp, block.timestamp, uint80(1)));
    }

    function _position() internal view returns (HedgerPool.HedgePosition memory p) {
        (bool ok, bytes memory data) = address(hedgerPool).staticcall(
            abi.encodeWithSignature("positions(uint256)", 1));
        assertTrue(ok);
        p = abi.decode(data, (HedgerPool.HedgePosition));
    }

    function test_Accounting_FullProfitExitPaysEarnedProfit() public {
        _prepare();
        _price(1.09e8);
        vm.prank(user);
        vault.redeemQEURO(1000e18, 1090e6);
        assertEq(_position().margin, 210e6);
        uint256 beforeBalance = usdc.balanceOf(hedger);
        vm.prank(hedger);
        hedgerPool.exitHedgePosition(1);
        assertEq(usdc.balanceOf(hedger) - beforeBalance, 210e6);
        assertEq(vault.getTotalUsdcAvailable(), 0);
    }

    function test_Accounting_PartialRedeemRetainsCostBasisAndWithdrawalBuffer() public {
        _prepare();
        _price(1.11e8);
        vm.prank(user);
        vault.redeemQEURO(995e18, 110445e4);
        HedgerPool.HedgePosition memory p = _position();
        assertEq(p.filledVolume, 550e4);
        assertEq(p.qeuroBacked, 5e18);
        assertEq(p.margin, 19005e4);
        assertEq(hedgerPool.getTotalEffectiveHedgerCollateral(1.11e18), 190e6);
        vm.expectRevert(HedgerPoolErrorLibrary.InsufficientMargin.selector);
        vm.prank(hedger);
        hedgerPool.removeMargin(1, 190e6);
    }

    function test_Accounting_PreviousCycleLossDoesNotBecomeProfit() public {
        _prepare();
        _price(1.11e8);
        vm.prank(user);
        vault.redeemQEURO(1000e18, 1110e6);
        assertEq(_position().margin, 190e6);
        vm.roll(block.number + 1);
        vm.prank(user);
        vault.mintQEURO(1110e6, 1000e18);
        vm.roll(block.number + 1);
        vm.prank(user);
        vault.redeemQEURO(1000e18, 1110e6);
        assertEq(_position().margin, 190e6);
        uint256 beforeBalance = usdc.balanceOf(hedger);
        vm.prank(hedger);
        hedgerPool.exitHedgePosition(1);
        assertEq(usdc.balanceOf(hedger) - beforeBalance, 190e6);
    }

    function test_Accounting_StaleOracleBlocksRemoveAndRedeem() public {
        _prepare();
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert(CommonErrorLibrary.InvalidOraclePrice.selector);
        vm.prank(hedger);
        hedgerPool.removeMargin(1, 1e6);
        vm.expectRevert(CommonErrorLibrary.InvalidOraclePrice.selector);
        vm.prank(user);
        vault.redeemQEURO(1e18, 0);
    }

    function testFuzz_Accounting_SplitRedemptionsConserveActualUsdc(uint256 firstQ, uint256 rawPrice) public {
        firstQ = bound(firstQ, 1e18, 999e18);
        rawPrice = bound(rawPrice, 109000000, 111000000);
        _prepare();
        _price(int256(rawPrice));
        vm.prank(user);
        vault.redeemQEURO(firstQ, 0);
        HedgerPool.HedgePosition memory p = _position();
        assertEq(uint256(p.margin) + p.filledVolume, vault.getTotalUsdcAvailable());
        assertEq(hedgerPool.totalFilledExposure(), p.filledVolume);
        assertEq(hedgerPool.totalExposure(), p.positionSize);
        vm.roll(block.number + 1);
        uint256 remainingQ = qeuro.balanceOf(user);
        vm.prank(user);
        vault.redeemQEURO(remainingQ, 0);
        p = _position();
        assertEq(p.filledVolume, 0);
        assertEq(p.qeuroBacked, 0);
        uint256 actualRemainingUsdc = vault.getTotalUsdcAvailable();
        assertEq(p.margin, actualRemainingUsdc);
        uint256 beforeBalance = usdc.balanceOf(hedger);
        vm.prank(hedger);
        hedgerPool.exitHedgePosition(1);
        assertEq(usdc.balanceOf(hedger) - beforeBalance, actualRemainingUsdc);
        assertEq(vault.getTotalUsdcAvailable(), 0);
    }

    function test_Accounting_ProfitThenNewFillConservesAssets() public {
        _prepare();
        _price(1.09e8);
        vm.prank(user);
        vault.redeemQEURO(500e18, 545e6);
        vm.roll(block.number + 1);
        vm.prank(user);
        vault.mintQEURO(1090e6, 1000e18);
        HedgerPool.HedgePosition memory p = _position();
        assertEq(uint256(p.margin) + p.filledVolume, vault.getTotalUsdcAvailable());
        vm.roll(block.number + 1);
        _price(1.10e8);
        vm.prank(user);
        vault.redeemQEURO(1500e18, 1650e6);
        assertEq(_position().margin, 195e6);
        assertEq(vault.getTotalUsdcAvailable(), 195e6);
        assertEq(hedgerPool.getTotalEffectiveHedgerCollateral(1.10e18), 195e6);
    }

    function test_Accounting_LiquidationThenNormalRedeemKeepsCountersAndHistoryConsistent() public {
        vm.prank(admin);
        vault.updateParameters(0, 0);
        vm.prank(hedger);
        hedgerPool.enterHedgePosition(200e6, 20);
        vm.prank(user);
        vault.mintQEURO(4000e6, 0);
        vm.prank(user);
        qeuro.approve(address(vault), type(uint256).max);
        vm.roll(block.number + 10);
        _price(1.145e8);
        vault.updatePriceCache();
        // This fraction makes separately rounded margin/cost releases differ by one USDC unit
        // from the vault's aggregate pro-rata payout.
        uint256 redeemQ = 1000e18 + 9e12;
        vm.prank(user);
        vault.redeemQEURO(redeemQ, 0);
        HedgerPool.HedgePosition memory p = _position();
        assertApproxEqAbs(p.margin, 145e6, 1);
        assertEq(hedgerPool.totalExposure(), p.positionSize);
        assertEq(p.positionSize, uint256(p.margin) * p.leverage);
        assertEq(hedgerPool.totalFilledExposure(), p.filledVolume);
        vm.roll(block.number + 1);
        _price(1.10e8);
        vault.updatePriceCache();
        uint256 remainingQ = qeuro.balanceOf(user);
        vm.prank(user);
        vault.redeemQEURO(remainingQ, 0);
        assertApproxEqAbs(_position().margin, 145e6, 2);
        assertApproxEqAbs(_position().margin, vault.getTotalUsdcAvailable(), 1);
        assertEq(_position().filledVolume, 0);
        assertEq(_position().qeuroBacked, 0);
        vm.prank(hedger);
        hedgerPool.exitHedgePosition(1);
        assertLe(vault.getTotalUsdcAvailable(), 1);
    }

    function _simulateUninitializedUpgrade() internal {
        // A legacy proxy has zero in the newly appended accounting flag slot.
        stdstore.target(address(hedgerPool)).sig("costBasisAccountingInitialized()").checked_write(false);
    }

    function test_Accounting_UpgradeBlocksLegacyActivePosition() public {
        _prepare();
        _simulateUninitializedUpgrade();
        vm.expectRevert(HedgerPoolErrorLibrary.InvalidPosition.selector);
        vm.prank(hedger);
        hedgerPool.removeMargin(1, 1e6);
        vm.expectRevert(HedgerPoolErrorLibrary.InvalidPosition.selector);
        vm.prank(user);
        vault.redeemQEURO(1e18, 0);
        vm.expectRevert(HedgerPoolErrorLibrary.InvalidPosition.selector);
        hedgerPool.getTotalEffectiveHedgerCollateral(1.1e18);
        vm.prank(admin);
        hedgerPool.pause();
        vm.expectRevert(HedgerPoolErrorLibrary.InvalidPosition.selector);
        vm.prank(admin);
        hedgerPool.initializeCostBasisAccounting();
    }

    function test_Accounting_UpgradeActivationRequiresPausedGovernanceAndSettledPool() public {
        _simulateUninitializedUpgrade();
        vm.expectRevert();
        vm.prank(admin);
        hedgerPool.initializeCostBasisAccounting();
        vm.prank(admin);
        hedgerPool.pause();
        vm.expectRevert();
        vm.prank(user);
        hedgerPool.initializeCostBasisAccounting();
        vm.prank(admin);
        hedgerPool.initializeCostBasisAccounting();
        assertTrue(hedgerPool.costBasisAccountingInitialized());
        vm.expectRevert();
        vm.prank(admin);
        hedgerPool.initializeCostBasisAccounting();
        vm.prank(admin);
        hedgerPool.unpause();
        _prepare();
        assertEq(_position().filledVolume, 1100e6);
    }
}
