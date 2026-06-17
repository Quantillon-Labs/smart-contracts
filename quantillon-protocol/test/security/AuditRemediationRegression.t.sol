// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {DeploymentSmokeTest} from "../DeploymentSmoke.t.sol";
import {CommonErrorLibrary} from "../../src/libraries/CommonErrorLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AuditRemediationRegression
 * @notice Regression tests for audit remediations F-3, F-4, F-6 using the full-protocol harness.
 *         (F-1 is covered by HedgerRotationDesync.t.sol; F-2/F-5 by their own targeted tests.)
 */
contract AuditRemediationRegression is DeploymentSmokeTest {
    // Mirror of HedgerPool.EmergencyPositionClosed for expectEmit.
    event EmergencyPositionClosed(
        address indexed hedger,
        uint256 indexed positionId,
        uint256 marginWithdrawn,
        uint256 outstandingQeuro
    );

    function _mintUser1(uint256 amount) private returns (uint256 qeuroBal) {
        vm.startPrank(user1);
        usdc.approve(address(vault), amount);
        (uint256 eurPrice, bool ok) = oracle.getEurUsdPrice();
        require(ok, "oracle");
        uint256 expectedQeuro = (amount * 1e30) / eurPrice;
        vault.mintQEURO(amount, (expectedQeuro * 80) / 100);
        qeuroBal = qeuroToken.balanceOf(user1);
        vm.stopPrank();
    }

    function _disableDevMode() private {
        vm.startPrank(admin);
        vault.proposeDevMode(false);
        vm.warp(block.timestamp + 48 hours + 1);
        vm.roll(block.number + 14_401);
        vault.applyDevMode();
        vm.stopPrank();
        assertFalse(vault.devModeEnabled(), "devMode off");
    }

    // ----------------------------------------------------------------- F-3

    /// @notice updatePriceCache() is permissionless (callable by a non-governance EOA).
    function test_F3_UpdatePriceCacheIsPermissionless() public {
        deployFullProtocol();
        vm.prank(user1); // no GOVERNANCE_ROLE
        vault.updatePriceCache();
    }

    /// @notice With devMode off, a >2% EUR move blocks redemption; a permissionless cache refresh
    ///         restores it without any governance action (F-3).
    function test_F3_DeviationBlocksRedeemThenPermissionlessRefreshRestores() public {
        deployFullProtocol();
        _disableDevMode();

        uint256 qeuroBal = _mintUser1(DEPOSIT_AMOUNT); // baseline cached at 1.10
        assertGt(qeuroBal, 0);

        // Move EUR/USD +~4.5% (> the 2% deviation guard). Update both the oracle's internal
        // baseline AND the underlying feed so the oracle returns a *valid* 1.15 price (otherwise
        // the mock's own deviation check would just report isValid=false). The vault's cached
        // baseline is still 1.10, so the vault's deviation guard is what fires here.
        vm.prank(admin);
        oracle.setPrices(1.15e18, 1.00e18);
        eurUsdFeed.setPrice(int256(1.15e8));
        vm.roll(block.number + 2);

        // Redemption is blocked by the deviation guard.
        vm.startPrank(user1);
        qeuroToken.approve(address(vault), qeuroBal);
        vm.expectRevert(CommonErrorLibrary.ExcessiveSlippage.selector);
        vault.redeemQEURO(qeuroBal, 0);
        vm.stopPrank();

        // Anyone can re-baseline the cache (permissionless) — here a plain user, not governance.
        vm.prank(user1);
        vault.updatePriceCache();

        // Redemption now succeeds at the refreshed baseline.
        uint256 usdcBefore = usdc.balanceOf(user1);
        vm.prank(user1);
        vault.redeemQEURO(qeuroBal, 0);
        assertGt(usdc.balanceOf(user1), usdcBefore, "redeem succeeds after permissionless refresh");
    }

    // ----------------------------------------------------------------- F-4

    /// @notice A donation-inflated first deposit that rounds to zero shares reverts instead of
    ///         silently forfeiting the depositor's QEURO (F-4).
    function test_F4_ZeroShareDepositReverts() public {
        deployFullProtocol();
        uint256 qeuroBal = _mintUser1(DEPOSIT_AMOUNT);

        // Donate QEURO directly into the (empty) stQEURO vault to inflate totalAssets. Use a third
        // so the remaining two-thirds is strictly greater than the donation (mints >=1 share).
        uint256 donation = qeuroBal / 3;
        vm.prank(user1);
        IERC20(address(qeuroToken)).transfer(address(stQEURO), donation);

        // A 1-wei deposit now previews 0 shares -> must revert (no asset forfeiture).
        vm.startPrank(user1);
        qeuroToken.approve(address(stQEURO), 1);
        vm.expectRevert(CommonErrorLibrary.InvalidAmount.selector);
        stQEURO.deposit(1, user1);
        vm.stopPrank();

        // A deposit larger than the donation still mints non-zero shares (guard only blocks the
        // zero-share rounding case). user1 retains `qeuroBal - donation`; deposit within that.
        vm.startPrank(user1);
        uint256 ok = qeuroBal - donation; // all remaining balance, which is > donation
        qeuroToken.approve(address(stQEURO), ok);
        uint256 shares = stQEURO.deposit(ok, user1);
        assertGt(shares, 0, "deposit above donation mints shares");
        vm.stopPrank();
    }

    // ----------------------------------------------------------------- F-6

    /// @notice emergencyClosePosition emits EmergencyPositionClosed carrying the outstanding QEURO
    ///         so monitoring can detect backing removed under an active supply (F-6).
    function test_F6_EmergencyCloseEmitsOutstandingQeuro() public {
        deployFullProtocol();
        _mintUser1(DEPOSIT_AMOUNT); // QEURO now outstanding

        ( , , , uint96 marginBefore, , , , , , , , , ) = hedgerPool.positions(1);
        uint256 outstanding = vault.totalMinted();
        assertGt(outstanding, 0, "QEURO outstanding");

        vm.expectEmit(true, true, false, true, address(hedgerPool));
        emit EmergencyPositionClosed(hedger1, 1, uint256(marginBefore), outstanding);

        vm.prank(emergency);
        hedgerPool.emergencyClosePosition(hedger1, 1);
    }
}
