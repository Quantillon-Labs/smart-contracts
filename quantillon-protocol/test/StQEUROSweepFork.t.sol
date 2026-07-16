// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {stQEUROToken} from "../src/core/stQEUROToken.sol";
import {stQEUROFactory} from "../src/core/stQEUROFactory.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IQEUROMint {
    function mint(address to, uint256 amount) external;
}

/**
 * @title StQEUROSweepForkTest
 * @notice Fork validation of the stQEURO v1.0.3 residual sweep against live Base state
 *
 * @dev Live stQEUROMORPHO1 (0x17CD...B1d) still holds the 1 wei of QEURO orphaned by the
 *      2026-07-15 full-exit round-down (share supply is 0, so nobody can claim it on
 *      v1.0.1). The test upgrades the real proxy to the local v1.0.3 implementation via
 *      the timelock, runs a full stake -> yield -> unstake cycle, and asserts the final
 *      exit sweeps the vault to an exact-zero QEURO balance — including that pre-existing
 *      orphaned wei. Also validates the factory template switch the Safe batch performs.
 *
 *      Opt-in: requires BASE_FORK_RPC_URL, e.g.
 *      BASE_FORK_RPC_URL=https://live.quantillon.money/rpc/base \
 *        forge test --match-contract StQEUROSweepForkTest -vv
 *
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract StQEUROSweepForkTest is Test {
    address internal constant STQEURO = 0x17CD8ed967d17072297CcAe3D379C9e86aeBEb1d;
    address internal constant FACTORY = 0x0382B0b9FB6Ff737209C3B31D727BB9d2E2bcb53;
    address internal constant QEURO = 0x69aD4e6c49d6275D0e11b5515D98a89f029869AA;
    address internal constant VAULT = 0x833E5Ba510a241b21F1C60c987D1c49eB52E4a07; // QEURO MINTER_ROLE
    address internal constant TIMELOCK = 0x7Ade8f3Bf1FdaF0785efE9Ea5C6339D1aD6B8342;
    address internal constant SAFE = 0x1d7fF432a93d0085Fb69474c7E567f859829e6cd;
    address internal constant TIME_PROVIDER = 0x520236487CBD0a6958B4EefC7853cd7C3F5C56E7;

    address internal staker = address(0x5715);

    function testLiveOrphanedWeiSweptAfterUpgrade() public {
        string memory rpc = vm.envOr("BASE_FORK_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            emit log("SKIP: set BASE_FORK_RPC_URL to run this fork validation");
            return;
        }
        vm.createSelectFork(rpc);

        stQEUROToken vaultToken = stQEUROToken(STQEURO);
        IERC20 qeuro = IERC20(QEURO);

        // Incident residue: the zero-share vault still holds orphaned QEURO dust.
        uint256 orphaned = qeuro.balanceOf(STQEURO);
        assertGt(orphaned, 0);
        assertEq(vaultToken.totalSupply(), 0);

        // Upgrade the real proxy to the local v1.0.3 implementation via the timelock.
        stQEUROToken newImpl = new stQEUROToken(TimeProvider(TIME_PROVIDER));
        vm.prank(TIMELOCK);
        vaultToken.upgradeToAndCall(address(newImpl), "");
        assertEq(vaultToken.version(), "1.0.3");

        // Factory template switch (direct Safe call in the same batch).
        vm.prank(SAFE);
        stQEUROFactory(FACTORY).updateTokenImplementation(address(newImpl));
        assertEq(stQEUROFactory(FACTORY).tokenImplementation(), address(newImpl));

        // Full cycle on the upgraded vault: stake, receive a yield mint, exit entirely.
        uint256 stakeAmount = 10e18;
        uint256 yieldAmount = 1_530_255_334_032_878; // incident-shaped awkward yield
        vm.prank(VAULT);
        IQEUROMint(QEURO).mint(staker, stakeAmount);

        vm.startPrank(staker);
        qeuro.approve(STQEURO, stakeAmount);
        vaultToken.deposit(stakeAmount, staker);
        vm.stopPrank();

        vm.prank(VAULT);
        IQEUROMint(QEURO).mint(STQEURO, yieldAmount);

        uint256 stakerShares = vaultToken.balanceOf(staker);
        vm.prank(staker);
        vaultToken.redeem(stakerShares, staker, staker);

        // The final exit sweeps everything: yield residue AND the pre-existing orphan.
        assertEq(vaultToken.totalSupply(), 0);
        assertEq(qeuro.balanceOf(STQEURO), 0);
        assertEq(qeuro.balanceOf(staker), stakeAmount + yieldAmount + orphaned);
    }
}
