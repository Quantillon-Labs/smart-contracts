// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {HedgerPool} from "../src/core/HedgerPool.sol";
import {HedgerPoolMigrationLibrary as Migration} from "../src/libraries/HedgerPoolMigrationLibrary.sol";
import {QuantillonRebalancerModule} from "../src/automation/QuantillonRebalancerModule.sol";

interface IRolloutSafe {
    function getOwners() external view returns (address[] memory);
    function getThreshold() external view returns (uint256);
    function nonce() external view returns (uint256);
    function approveHash(bytes32 hash) external;
    function getTransactionHash(address,uint256,bytes calldata,uint8,uint256,uint256,uint256,address,address,uint256) external view returns (bytes32);
    function execTransaction(address,uint256,bytes calldata,uint8,uint256,uint256,uint256,address,address,bytes calldata) external payable returns (bool);
    function enableModule(address module) external;
    function disableModule(address previous, address module) external;
    function isModuleEnabled(address module) external view returns (bool);
    function getModulesPaginated(address start, uint256 pageSize) external view returns (address[] memory, address);
}
interface IRolloutTimelock {
    function getMinDelay() external view returns (uint256);
    function schedule(address,uint256,bytes calldata,bytes32,bytes32,uint256) external;
    function execute(address,uint256,bytes calldata,bytes32,bytes32) external payable;
    function hashOperation(address,uint256,bytes calldata,bytes32,bytes32) external pure returns (bytes32);
    function isOperationDone(bytes32 id) external view returns (bool);
}

/// @notice Rehearses real Safe threshold execution and production TimelockController on a local fork.
/// @dev No broadcast. Owner hash approvals, pilot funding and post-delay oracle quotes are test-only.
contract SafeHedgerRolloutTest is Test {
    address internal constant SAFE = 0x1d7fF432a93d0085Fb69474c7E567f859829e6cd;
    address internal constant POOL = 0xff5D7cE5c7671B2EA805Ee752B4f8eC9Ecf2975A;
    address internal constant OPERATOR = 0x8DAD1B6c1A40e2649d50952977b5af1992f098d1;
    address internal constant SENTINEL = address(1);
    IRolloutSafe internal safe = IRolloutSafe(SAFE);
    HedgerPool internal pool = HedgerPool(POOL);
    address internal ownerA;
    address internal ownerB;

    // Approved deployment policy: 5/action, 10/window, 10-minute cooldown.
    function _limits() internal pure returns (QuantillonRebalancerModule.Limits memory) {
        return QuantillonRebalancerModule.Limits(5e6, 10e6, 600, 5e6, 350, 100, 100);
    }

    function _approve(address to, bytes memory data) internal returns (bytes memory signatures) {
        bytes32 hash = safe.getTransactionHash(to, 0, data, 0, 0, 0, 0, address(0), address(0), safe.nonce());
        vm.prank(ownerA);
        safe.approveHash(hash);
        vm.prank(ownerB);
        safe.approveHash(hash);
        // Real Safe pre-approved-hash signatures, sorted by owner address; no owner keys are read.
        return abi.encodePacked(bytes32(uint256(uint160(ownerA))), bytes32(0), uint8(1),
            bytes32(uint256(uint160(ownerB))), bytes32(0), uint8(1));
    }

    function _safeCall(address to, bytes memory data) internal {
        bytes memory signatures = _approve(to, data);
        assertTrue(safe.execTransaction(to, 0, data, 0, 0, 0, 0, address(0), address(0), signatures));
    }

    function _snapshot() internal view returns (bytes32) {
        return keccak256(abi.encode(pool.totalMargin(), pool.totalExposure(), pool.totalFilledExposure(),
            pool.usdc().balanceOf(POOL), pool.usdc().balanceOf(address(pool.vault())),
            IERC20(pool.vault().qeuro()).totalSupply()));
    }

    function _position() internal view returns (bytes memory data) {
        (bool ok, bytes memory result) = POOL.staticcall(abi.encodeWithSignature("positions(uint256)", 1));
        require(ok);
        return result;
    }

    function testForkFullSafeHedgerRollout() public {
        string memory rpc = vm.envOr("REBALANCER_TEST_BASE_RPC_URL", string(""));
        if (bytes(rpc).length == 0) { vm.skip(true); return; }
        vm.createSelectFork(rpc);
        assertEq(block.chainid, 8453);
        assertEq(pool.singleHedger(), OPERATOR);
        assertEq(safe.getThreshold(), 2);
        address[] memory owners = safe.getOwners();
        assertEq(owners.length, 3);
        ownerA = owners[0] < owners[1] ? owners[0] : owners[1];
        ownerB = owners[0] < owners[1] ? owners[1] : owners[0];
        (address[] memory modules,) = safe.getModulesPaginated(SENTINEL, 100);
        assertEq(modules.length, 0, "Re-review linked list if modules changed");
        IRolloutTimelock timelock = IRolloutTimelock(address(pool.timelock()));
        assertEq(timelock.getMinDelay(), 12 hours);
        (uint256 observedPrice, bool valid) = pool.oracle().getEurUsdPrice();
        assertTrue(valid);
        assertGt(observedPrice, 0);

        address deployedImplementation = vm.envOr("SAFE_HEDGER_TEST_IMPLEMENTATION", address(0));
        address deployedModule = vm.envOr("SAFE_HEDGER_TEST_MODULE", address(0));
        require((deployedImplementation == address(0)) == (deployedModule == address(0)), "Supply both deployed addresses");
        HedgerPool implementation = deployedImplementation == address(0)
            ? new HedgerPool(pool.TIME_PROVIDER()) : HedgerPool(deployedImplementation);
        assertEq(implementation.version(), "1.2.0");
        assertEq(address(implementation.TIME_PROVIDER()), address(pool.TIME_PROVIDER()));
        assertLe(address(implementation).code.length, 24_576);
        QuantillonRebalancerModule module = deployedModule == address(0)
            ? new QuantillonRebalancerModule(SAFE, POOL, 1, OPERATOR, _limits())
            : QuantillonRebalancerModule(deployedModule);
        assertEq(module.version(), "1.0.0");
        assertEq(module.safe(), SAFE);
        assertEq(address(module.hedgerPool()), POOL);
        assertEq(module.operator(), OPERATOR);
        assertEq(module.positionId(), 1);
        assertEq(address(module.usdc()), address(pool.usdc()));
        assertEq(address(module.vault()), address(pool.vault()));
        (bool policyOk, bytes memory policy) = address(module).staticcall(abi.encodeWithSignature("limits()"));
        assertTrue(policyOk);
        assertEq(policy, abi.encode(_limits()));
        assertEq(module.nonce(), 0);
        assertEq(module.windowUsage(), 0);
        assertTrue(module.paused());
        assertFalse(safe.isModuleEnabled(address(module)));
        bytes32 economics = _snapshot();
        bytes memory expectedPosition = _position();

        bytes memory upgrade = abi.encodeWithSignature("executeUpgrade(address)", address(implementation));
        bytes32 salt = keccak256("quantillon-safe-hedger-v1.2.0-rehearsal");
        bytes memory schedule = abi.encodeCall(IRolloutTimelock.schedule, (POOL, 0, upgrade, bytes32(0), salt, 12 hours));
        // A single owner approval cannot pass the actual Safe's two-signature threshold.
        bytes memory signatures = _approve(address(timelock), schedule);
        bytes memory single = new bytes(65);
        for (uint256 i; i < 65; ++i) single[i] = signatures[i];
        vm.expectRevert(bytes("GS020"));
        safe.execTransaction(address(timelock), 0, schedule, 0, 0, 0, 0, address(0), address(0), single);
        _safeCall(address(timelock), schedule);
        bytes memory execute = abi.encodeCall(IRolloutTimelock.execute, (POOL, 0, upgrade, bytes32(0), salt));
        signatures = _approve(address(timelock), execute);
        vm.expectRevert(bytes("GS013"));
        safe.execTransaction(address(timelock), 0, execute, 0, 0, 0, 0, address(0), address(0), signatures);
        vm.warp(vm.getBlockTimestamp() + 12 hours);
        _safeCall(address(timelock), execute);
        assertTrue(timelock.isOperationDone(timelock.hashOperation(POOL, 0, upgrade, bytes32(0), salt)));
        assertEq(pool.version(), "1.2.0");
        assertEq(_snapshot(), economics);
        assertEq(_position(), expectedPosition);

        // Create the transfer proposal after the upgrade delay, so its 24-hour expiry remains useful.
        Migration.Request memory request = Migration.Request(Migration.Action.Propose, SAFE, uint64(vm.getBlockTimestamp() + 1 days), 0);
        vm.prank(OPERATOR);
        pool.manageHedgerMigration(request);
        request.proposalId = pool.hedgerMigration().id;
        request.action = Migration.Action.Accept;
        _safeCall(POOL, abi.encodeCall(HedgerPool.manageHedgerMigration, (request)));
        _safeCall(POOL, abi.encodeCall(HedgerPool.pause, ()));
        request.action = Migration.Action.Execute;
        _safeCall(POOL, abi.encodeCall(HedgerPool.manageHedgerMigration, (request)));
        _safeCall(POOL, abi.encodeCall(HedgerPool.unpause, ()));
        assembly ("memory-safe") { mstore(add(expectedPosition, 32), SAFE) }
        assertEq(_position(), expectedPosition);
        assertEq(_snapshot(), economics);
        assertEq(pool.singleHedger(), SAFE);
        vm.prank(OPERATOR);
        vm.expectRevert();
        pool.addMargin(1, 1e6);

        _safeCall(SAFE, abi.encodeCall(IRolloutSafe.enableModule, (address(module))));
        assertTrue(safe.isModuleEnabled(address(module)));
        vm.prank(OPERATOR);
        vm.expectRevert(QuantillonRebalancerModule.ModulePaused.selector);
        module.addMargin(1e6, 0, vm.getBlockTimestamp() + 300);
        _safeCall(address(module), abi.encodeCall(QuantillonRebalancerModule.setPaused, (false)));

        // No real feed updates happen across a local 12-hour warp. Stale withdrawals must fail.
        vm.mockCall(address(pool.oracle()), abi.encodeWithSignature("getEurUsdPrice()"), abi.encode(observedPrice, false));
        vm.prank(OPERATOR);
        vm.expectRevert();
        module.removeMargin(1e6, 0, vm.getBlockTimestamp() + 300);
        assertEq(module.nonce(), 0);
        // Explicit simulation assumptions: 6 USDC pilot funding; a fresh unchanged oracle quote.
        deal(address(pool.usdc()), SAFE, 6e6);
        vm.mockCall(address(pool.oracle()), abi.encodeWithSignature("getEurUsdPrice()"), abi.encode(observedPrice, true));
        vm.prank(OPERATOR);
        module.addMargin(1e6, 0, vm.getBlockTimestamp() + 300);
        assertEq(pool.usdc().balanceOf(SAFE), 5e6);
        assertEq(pool.usdc().allowance(SAFE, POOL), 0);
        vm.warp(vm.getBlockTimestamp() + 600);
        vm.prank(OPERATOR);
        module.removeMargin(1e6, 1, vm.getBlockTimestamp() + 300);
        assertEq(pool.usdc().balanceOf(SAFE), 6e6);
        assertEq(module.windowUsage(), 2e6);

        vm.warp(vm.getBlockTimestamp() + 600);
        vm.prank(OPERATOR);
        vm.expectRevert(QuantillonRebalancerModule.LimitExceeded.selector);
        module.addMargin(5e6 + 1, 2, vm.getBlockTimestamp() + 300);
        _safeCall(address(module), abi.encodeCall(QuantillonRebalancerModule.setPaused, (true)));
        vm.prank(OPERATOR);
        vm.expectRevert(QuantillonRebalancerModule.ModulePaused.selector);
        module.removeMargin(1e6, 2, vm.getBlockTimestamp() + 300);
        _safeCall(SAFE, abi.encodeCall(IRolloutSafe.disableModule, (SENTINEL, address(module))));
        assertFalse(safe.isModuleEnabled(address(module)));
        _safeCall(address(module), abi.encodeCall(QuantillonRebalancerModule.setPaused, (false)));
        vm.prank(OPERATOR);
        vm.expectRevert();
        module.removeMargin(1e6, 2, vm.getBlockTimestamp() + 300);
        assertEq(module.nonce(), 2, "Revocation failure must not consume an operation nonce");
        assertEq(pool.singleHedger(), SAFE, "Revoking automation must not transfer the position back");
    }
}
