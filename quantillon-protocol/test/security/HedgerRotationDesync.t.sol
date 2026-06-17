// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {DeploymentSmokeTest} from "../DeploymentSmoke.t.sol";
import {HedgerPoolErrorLibrary} from "../../src/libraries/HedgerPoolErrorLibrary.sol";
import {CommonErrorLibrary} from "../../src/libraries/CommonErrorLibrary.sol";

/**
 * @title HedgerRotationDesyncTest
 * @notice Regression tests for audit F-1 (single-hedger rotation).
 *
 * The protocol is single-hedger-only; the delayed multi-hedger rotation machinery is a relic.
 * These tests assert the fix:
 *   - `applySingleHedgerRotation()` is disabled (always reverts).
 *   - `setSingleHedger()` reverts when reassigning while positionId 1 is still active (which would
 *     otherwise orphan the backing position, brick minting, desync redeems, and strand margin).
 *   - reassignment is permitted synchronously once the slot is free, and the new hedger opens a
 *     clean position (no stale qeuroBacked, no double-counted totals).
 */
contract HedgerRotationDesyncTest is DeploymentSmokeTest {
    address internal hedger2 = address(0xBEEF);

    /// @notice The delayed-rotation relic is disabled and always reverts.
    function test_ApplySingleHedgerRotationDisabled() public {
        deployFullProtocol();
        vm.prank(governance);
        vm.expectRevert(CommonErrorLibrary.NotActive.selector);
        hedgerPool.applySingleHedgerRotation();
    }

    /// @notice Reassigning the single hedger while a backing position is active fails loudly.
    function test_SetSingleHedgerRevertsWhilePositionActive() public {
        deployFullProtocol();
        // hedger1 holds the active seed position (positionId 1) from deployFullProtocol.
        (, , , , , , , , , , bool active, , ) = hedgerPool.positions(1);
        assertTrue(active, "seed position active");

        vm.prank(governance);
        vm.expectRevert(HedgerPoolErrorLibrary.HedgerHasActivePosition.selector);
        hedgerPool.setSingleHedger(hedger2);

        // The original hedger is unchanged; nothing was orphaned.
        assertEq(hedgerPool.singleHedger(), hedger1, "single hedger unchanged after failed rotation");
        assertTrue(hedgerPool.hasActiveHedger(), "backing position still recognized");
    }

    /// @notice Once the slot is free, reassignment applies synchronously and the new hedger opens
    ///         a clean position: positionId 1 belongs to the new hedger with no stale state and
    ///         totals are not double-counted.
    function test_ReassignAllowedWhenSlotFreeAndOpensClean() public {
        deployFullProtocol();

        // No QEURO is outstanding (no user mint), so the seed hedger can exit and free the slot.
        vm.roll(block.number + 10);
        vm.prank(hedger1);
        hedgerPool.exitHedgePosition(1);
        assertEq(hedgerPool.totalMargin(), 0, "totalMargin cleared after exit");
        (, , , , , , , , , , bool stillActive, , ) = hedgerPool.positions(1);
        assertFalse(stillActive, "slot 1 free after exit");

        // Synchronous reassignment now allowed.
        vm.prank(governance);
        hedgerPool.setSingleHedger(hedger2);
        assertEq(hedgerPool.singleHedger(), hedger2, "reassignment applied synchronously");

        // New hedger opens; positionId 1 is reused cleanly.
        uint256 margin2 = 100_000 * 1e6;
        usdc.mint(hedger2, margin2);
        vm.startPrank(hedger2);
        usdc.approve(address(hedgerPool), margin2);
        hedgerPool.enterHedgePosition(margin2, 5);
        vm.stopPrank();

        (address ownerNow, , , uint96 marginNow, , , , , int128 realized, , bool activeNow, uint128 qeuroBacked, ) =
            hedgerPool.positions(1);
        assertEq(ownerNow, hedger2, "position 1 now owned by new hedger");
        assertTrue(activeNow, "new position active");
        assertEq(uint256(qeuroBacked), 0, "fresh position has zero qeuroBacked (no stale backing)");
        assertEq(int256(realized), 0, "fresh position has zero realized P&L");
        // No double-count: the aggregate equals the single live position's margin.
        assertEq(hedgerPool.totalMargin(), uint256(marginNow), "totalMargin equals the only live position");
        assertTrue(hedgerPool.hasActiveHedger(), "new hedger recognized as active");
    }
}
