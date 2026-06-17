// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {DeploymentSmokeTest} from "./DeploymentSmoke.t.sol";

/**
 * @title VaultRedeemHedgerSyncAtomicityTest
 * @notice Regression tests for atomic redeem/hedger synchronization: redeem reverts when
 *         HedgerPool is unavailable (paused) rather than silently desyncing filled exposure, but
 *         still succeeds under normal conditions (no redemption DoS).
 */
contract VaultRedeemHedgerSyncAtomicityTest is DeploymentSmokeTest {
    function _mintAsUser1() private returns (uint256 qeuroBal) {
        vm.startPrank(user1);
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        (uint256 eurPrice, bool ok) = oracle.getEurUsdPrice();
        require(ok, "oracle invalid");
        uint256 expectedQeuro = (DEPOSIT_AMOUNT * 1e30) / eurPrice;
        vault.mintQEURO(DEPOSIT_AMOUNT, (expectedQeuro * 80) / 100);
        qeuroBal = qeuroToken.balanceOf(user1);
        vm.stopPrank();
        require(qeuroBal > 0, "mint produced QEURO");
    }

    /// @notice With HedgerPool paused, redeem reverts instead of completing with stale hedger state.
    function test_RedeemRevertsWhenHedgerPoolPaused() public {
        deployFullProtocol();
        uint256 qeuroBal = _mintAsUser1();

        vm.prank(emergency);
        hedgerPool.pause();

        vm.startPrank(user1);
        qeuroToken.approve(address(vault), qeuroBal);
        vm.expectRevert();
        vault.redeemQEURO(qeuroBal, 0);
        vm.stopPrank();

        // The redemption was fully rolled back: the user keeps their QEURO.
        assertEq(qeuroToken.balanceOf(user1), qeuroBal, "redeem reverted atomically; no QEURO burned");
    }

    /// @notice Control: redeem still succeeds under normal conditions (no DoS introduced).
    function test_RedeemSucceedsWhenHedgerPoolActive() public {
        deployFullProtocol();
        uint256 qeuroBal = _mintAsUser1();

        uint256 filledBefore = hedgerPool.totalFilledExposure();

        vm.startPrank(user1);
        qeuroToken.approve(address(vault), qeuroBal);
        vault.redeemQEURO(qeuroBal, 0);
        vm.stopPrank();

        assertEq(qeuroToken.balanceOf(user1), 0, "redeem succeeded in normal conditions");
        assertLt(hedgerPool.totalFilledExposure(), filledBefore, "hedger filled exposure synced down atomically");
    }
}
