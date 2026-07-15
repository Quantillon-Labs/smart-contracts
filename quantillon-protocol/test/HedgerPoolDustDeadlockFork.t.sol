// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {HedgerPool} from "../src/core/HedgerPool.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {HedgerPoolErrorLibrary} from "../src/libraries/HedgerPoolErrorLibrary.sol";

/**
 * @title HedgerPoolDustDeadlockForkTest
 * @notice Fork validation of the QEURO dust-deadlock fix against live Base mainnet state
 *
 * @dev Reproduces the incident observed live on 2026-07-15: after a full unstake/redeem
 *      cycle, proportional round-down stranded 1 wei of QEURO in a stQEURO vault whose
 *      share supply is zero. vault.totalMinted() therefore never returns to 0, and the
 *      sole hedger's exitHedgePosition reverts PositionClosureRestricted forever (the
 *      closure safety check compares post-removal totalMargin — 0 for the sole hedger —
 *      against the position margin).
 *
 *      The test first proves the deadlock on the deployed implementation, then upgrades
 *      the proxy to the local (fixed) implementation via the timelock and proves the
 *      hedger can exit and collect the full loss-adjusted margin.
 *
 *      Opt-in: requires BASE_FORK_RPC_URL to be set, e.g.
 *      BASE_FORK_RPC_URL=https://live.quantillon.money/rpc/base \
 *        forge test --match-contract HedgerPoolDustDeadlockForkTest -vv
 *
 *      NOTE: only meaningful while live position 1 is still open and dead-locked; once
 *      it has been closed (e.g. via emergencyClosePosition) the reproduction step will
 *      fail and this file documents the scenario rather than gating CI.
 *
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract HedgerPoolDustDeadlockForkTest is Test {
    address internal constant HEDGER_POOL = 0xff5D7cE5c7671B2EA805Ee752B4f8eC9Ecf2975A;
    address internal constant HEDGER = 0x8DAD1B6c1A40e2649d50952977b5af1992f098d1;
    address internal constant TIMELOCK = 0x7Ade8f3Bf1FdaF0785efE9Ea5C6339D1aD6B8342;
    address internal constant TIME_PROVIDER = 0x520236487CBD0a6958B4EefC7853cd7C3F5C56E7;
    address internal constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    uint256 internal constant POSITION_ID = 1;

    function testLiveDustDeadlockResolvedByUpgrade() public {
        string memory rpc = vm.envOr("BASE_FORK_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            emit log("SKIP: set BASE_FORK_RPC_URL to run this fork validation");
            return;
        }
        vm.createSelectFork(rpc);

        HedgerPool pool = HedgerPool(HEDGER_POOL);

        // Reproduce the deadlock on the deployed implementation.
        vm.startPrank(HEDGER);
        vm.expectRevert(HedgerPoolErrorLibrary.PositionClosureRestricted.selector);
        pool.exitHedgePosition(POSITION_ID);
        vm.stopPrank();

        // Upgrade the proxy to the fixed implementation. secureUpgradesEnabled is on for
        // the live pool, so the timelock is the only authorized upgrader.
        HedgerPool newImpl = new HedgerPool(TimeProvider(TIME_PROVIDER));
        vm.prank(TIMELOCK);
        pool.upgradeToAndCall(address(newImpl), "");

        (, , , uint96 marginBefore, , , , , , , , , ) = pool.positions(POSITION_ID);
        assertGt(uint256(marginBefore), 0);
        uint256 hedgerUsdcBefore = IERC20(USDC).balanceOf(HEDGER);

        vm.startPrank(HEDGER);
        pool.exitHedgePosition(POSITION_ID);
        vm.stopPrank();

        // Full loss-adjusted margin is paid out: the exit fee is 0 on live, and the dust
        // backing left on the position rounds to zero USDC of P&L.
        assertEq(IERC20(USDC).balanceOf(HEDGER) - hedgerUsdcBefore, uint256(marginBefore));
        assertEq(pool.totalMargin(), 0);
    }
}
