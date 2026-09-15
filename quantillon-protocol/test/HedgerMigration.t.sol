// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {QuantillonRebalancerModuleTest, RebalanceSafeHarness} from "./QuantillonRebalancerModule.t.sol";
import {HedgerPool} from "../src/core/HedgerPool.sol";
import {HedgerPoolMigrationLibrary as Migration} from "../src/libraries/HedgerPoolMigrationLibrary.sol";
import {QuantillonRebalancerModule} from "../src/automation/QuantillonRebalancerModule.sol";

contract HedgerMigrationTest is QuantillonRebalancerModuleTest {
    function _propose(address recipient) internal returns (Migration.Request memory request) {
        request = Migration.Request(Migration.Action.Propose, recipient, uint64(vm.getBlockTimestamp() + 1 days), 0);
        vm.prank(safe);
        pool.manageHedgerMigration(request);
        request.proposalId = pool.hedgerMigration().id;
    }

    function _accept(Migration.Request memory request) internal {
        request.action = Migration.Action.Accept;
        vm.prank(request.newHedger);
        pool.manageHedgerMigration(request);
    }

    function _execute(Migration.Request memory request) internal {
        request.action = Migration.Action.Execute;
        pool.pause();
        pool.manageHedgerMigration(request);
    }

    function _slot(address owner, uint256 slot) internal pure returns (bytes32) {
        return keccak256(abi.encode(owner, slot));
    }

    function _positionBytes() internal view returns (bytes memory data) {
        (bool ok, bytes memory result) = address(pool).staticcall(abi.encodeWithSignature("positions(uint256)", 1));
        require(ok);
        return result;
    }

    function _economicSnapshot() internal view returns (bytes32) {
        return keccak256(abi.encode(
            pool.totalMargin(), pool.totalExposure(), pool.totalFilledExposure(),
            pool.usdc().balanceOf(address(pool)), pool.usdc().balanceOf(address(pool.vault())),
            pool.getTotalEffectiveHedgerCollateral(1e18)
        ));
    }

    function testMigrationPreservesPositionAndMovesPoolRewards() public {
        address recipient = address(new RebalanceSafeHarness());
        // Live storage layout: escrow=14, reward state=20, active ID=21, clock=22.
        bytes32 rewards = bytes32(uint256(123e6) | (uint256(1_700_000_000) << 128));
        vm.store(address(pool), _slot(safe, 20), rewards);
        vm.store(address(pool), _slot(safe, 14), bytes32(uint256(99e6)));
        vm.store(address(pool), _slot(safe, 22), bytes32(uint256(1_700_000_100)));
        bytes memory expected = _positionBytes();
        assembly ("memory-safe") { mstore(add(expected, 32), recipient) }
        bytes32 economic = _economicSnapshot();
        uint256 oldBalance = usdc.balanceOf(safe);
        Migration.Request memory request = _propose(recipient);
        _accept(request);
        _execute(request);
        assertEq(_positionBytes(), expected, "only position owner changes");
        assertEq(_economicSnapshot(), economic, "backing/cash/counters preserved");
        assertEq(usdc.balanceOf(safe), oldBalance);
        assertEq(usdc.balanceOf(recipient), 0);
        assertEq(pool.singleHedger(), recipient);
        assertEq(uint256(vm.load(address(pool), _slot(safe, 21))), 0);
        assertEq(uint256(vm.load(address(pool), _slot(recipient, 21))), 1);
        assertEq(vm.load(address(pool), _slot(recipient, 20)), rewards);
        assertEq(vm.load(address(pool), _slot(safe, 20)), bytes32(0));
        assertEq(pool.pendingRewardWithdrawals(recipient), 99e6);
        assertEq(pool.pendingRewardWithdrawals(safe), 0);
        assertEq(pool.hedgerLastRewardBlock(recipient), 1_700_000_100);
        assertEq(pool.hedgerLastRewardBlock(safe), 0);
        assertEq(pool.hedgerMigration().id, bytes32(0));
        request.action = Migration.Action.Execute;
        vm.expectRevert(Migration.InvalidMigration.selector);
        pool.manageHedgerMigration(request);
    }

    function testMigrationRequiresThreeAuthoritiesAndPause() public {
        address recipient = address(new RebalanceSafeHarness());
        Migration.Request memory request = Migration.Request(Migration.Action.Propose, recipient, uint64(vm.getBlockTimestamp() + 1 days), 0);
        vm.expectRevert(Migration.MigrationUnauthorized.selector);
        pool.manageHedgerMigration(request);
        request = _propose(recipient);
        request.action = Migration.Action.Accept;
        vm.expectRevert(Migration.MigrationUnauthorized.selector);
        pool.manageHedgerMigration(request);
        request.action = Migration.Action.Execute;
        vm.expectRevert(Migration.MigrationRequiresPause.selector);
        pool.manageHedgerMigration(request);
        pool.pause();
        vm.expectRevert(Migration.MigrationNotAccepted.selector);
        pool.manageHedgerMigration(request);
        _accept(request);
        request.action = Migration.Action.Execute;
        vm.prank(recipient);
        vm.expectRevert(Migration.MigrationUnauthorized.selector);
        pool.manageHedgerMigration(request);
        pool.manageHedgerMigration(request);
        assertEq(pool.singleHedger(), recipient);
    }

    function testMigrationRejectsExpiredAndReplacedProposals() public {
        address recipient = address(new RebalanceSafeHarness());
        Migration.Request memory previous = _propose(recipient);
        Migration.Request memory current = _propose(recipient);
        previous.action = Migration.Action.Accept;
        vm.prank(recipient);
        vm.expectRevert(Migration.InvalidMigration.selector);
        pool.manageHedgerMigration(previous);
        _accept(current);
        vm.warp(uint256(current.expiresAt) + 1);
        current.action = Migration.Action.Execute;
        pool.pause();
        vm.expectRevert(Migration.MigrationExpired.selector);
        pool.manageHedgerMigration(current);
        current.action = Migration.Action.Cancel;
        vm.prank(recipient);
        pool.manageHedgerMigration(current);
        assertEq(pool.hedgerMigration().id, bytes32(0));
    }

    function testMigrationRejectsDirtyRecipientWithoutLosingClaims() public {
        address recipient = address(new RebalanceSafeHarness());
        Migration.Request memory request = _propose(recipient);
        _accept(request);
        request.action = Migration.Action.Execute;
        pool.pause();
        uint256[4] memory slots = [uint256(14), 20, 21, 22];
        for (uint256 i; i < slots.length; ++i) {
            bytes32 slot = _slot(recipient, slots[i]);
            vm.store(address(pool), slot, bytes32(uint256(1)));
            vm.expectRevert(Migration.RecipientHasHedgerState.selector);
            pool.manageHedgerMigration(request);
            assertEq(vm.load(address(pool), slot), bytes32(uint256(1)));
            assertEq(pool.singleHedger(), safe);
            vm.store(address(pool), slot, bytes32(0));
        }
        // A historical claim timestamp alone must also prevent overwriting state.
        vm.store(address(pool), _slot(recipient, 20), bytes32(uint256(1) << 128));
        vm.expectRevert(Migration.RecipientHasHedgerState.selector);
        pool.manageHedgerMigration(request);
    }

    function testMigrationCancellationAndExactProposalBinding() public {
        address recipient = address(new RebalanceSafeHarness());
        Migration.Request memory request = _propose(recipient);
        request.action = Migration.Action.Accept;
        request.expiresAt += 1;
        vm.prank(recipient);
        vm.expectRevert(Migration.InvalidMigration.selector);
        pool.manageHedgerMigration(request);
        request.expiresAt -= 1;
        request.action = Migration.Action.Cancel;
        vm.prank(operator);
        vm.expectRevert(Migration.MigrationUnauthorized.selector);
        pool.manageHedgerMigration(request);
        vm.prank(safe);
        pool.manageHedgerMigration(request);
        assertEq(pool.hedgerMigration().id, bytes32(0));
    }

    function testMigrationRejectsClosedPositionAndInvalidRecipient() public {
        vm.prank(safe);
        vm.expectRevert(Migration.InvalidMigration.selector);
        pool.manageHedgerMigration(Migration.Request(Migration.Action.Propose, operator, uint64(vm.getBlockTimestamp() + 1 days), 0));
        Migration.Request memory request = _propose(address(new RebalanceSafeHarness()));
        _accept(request);
        pool.emergencyClosePosition(safe, 1);
        pool.pause();
        request.action = Migration.Action.Execute;
        vm.expectRevert(Migration.InvalidMigration.selector);
        pool.manageHedgerMigration(request);
    }

    function testMigratedSafeCanRebalanceAndOldOperatorLosesAccess() public {
        address recipient = address(new RebalanceSafeHarness());
        Migration.Request memory request = _propose(recipient);
        _accept(request);
        _execute(request);
        pool.unpause();
        _expectAdd(10e6, bytes4(0));
        module = new QuantillonRebalancerModule(recipient, address(pool), 1, operator, _limits());
        vm.prank(recipient);
        RebalanceSafeHarness(recipient).enableModule(address(module));
        vm.prank(recipient);
        module.setPaused(false);
        usdc.mint(recipient, 1_000e6);
        _add(100e6);
        vm.warp(vm.getBlockTimestamp() + 60);
        _remove(50e6);
        assertEq(usdc.balanceOf(recipient), 950e6);
    }

    function testClosingAndReopeningInSameBlockInvalidatesAcceptance() public {
        Migration.Request memory request = _propose(address(new RebalanceSafeHarness()));
        _accept(request);
        pool.emergencyClosePosition(safe, 1);
        vm.startPrank(safe);
        usdc.approve(address(pool), 1_000e6);
        pool.enterHedgePosition(1_000e6, 10);
        vm.stopPrank();
        assertEq(pool.hedgerMigration().id, bytes32(0));
        request.action = Migration.Action.Execute;
        pool.pause();
        vm.expectRevert(Migration.InvalidMigration.selector);
        pool.manageHedgerMigration(request);
    }

    function testForkLivePositionMigration() public {
        string memory rpc = vm.envOr("REBALANCER_TEST_BASE_RPC_URL", string(""));
        if (bytes(rpc).length == 0) { vm.skip(true); return; }
        vm.createSelectFork(rpc);
        pool = HedgerPool(0xff5D7cE5c7671B2EA805Ee752B4f8eC9Ecf2975A);
        safe = pool.singleHedger();
        address recipient = 0x1d7fF432a93d0085Fb69474c7E567f859829e6cd;
        assertTrue(pool.hasRole(pool.GOVERNANCE_ROLE(), recipient));
        assertTrue(pool.hasRole(pool.EMERGENCY_ROLE(), recipient));
        bytes memory expected = _positionBytes();
        assembly ("memory-safe") { mstore(add(expected, 32), recipient) }
        bytes32 economic = _economicSnapshot();
        bytes32 rewards = vm.load(address(pool), _slot(safe, 20));
        uint256 rewardTime = pool.hedgerLastRewardBlock(safe);
        uint256 escrow = pool.pendingRewardWithdrawals(safe);
        uint256 vaultEther = address(pool.vault()).balance;
        address implementation = address(new HedgerPool(pool.TIME_PROVIDER()));
        vm.prank(address(pool.timelock()));
        pool.executeUpgrade(implementation);
        assertEq(pool.version(), "1.2.0");
        Migration.Request memory request = _propose(recipient);
        _accept(request);
        request.action = Migration.Action.Execute;
        vm.startPrank(recipient);
        pool.pause();
        pool.manageHedgerMigration(request);
        vm.stopPrank();
        assertEq(_positionBytes(), expected);
        assertEq(_economicSnapshot(), economic);
        assertEq(vm.load(address(pool), _slot(recipient, 20)), rewards);
        assertEq(pool.hedgerLastRewardBlock(recipient), rewardTime);
        assertEq(pool.pendingRewardWithdrawals(recipient), escrow);
        assertEq(address(pool.vault()).balance, vaultEther);
        assertEq(pool.singleHedger(), recipient);
        assertEq(uint256(vm.load(address(pool), _slot(safe, 21))), 0);
        assertEq(uint256(vm.load(address(pool), _slot(recipient, 21))), 1);
    }
}
