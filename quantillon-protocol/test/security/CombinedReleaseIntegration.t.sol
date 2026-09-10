// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {HedgerVaultRegressionTest} from "../HedgerVaultRegression.t.sol";
import {ExecutionPricing} from "../../src/oracle/ExecutionPricing.sol";
import {HedgerPool} from "../../src/core/HedgerPool.sol";
import {VmSafe} from "forge-std/Vm.sol";

contract CombinedReleaseIntegrationTest is HedgerVaultRegressionTest {
    function _publish(ExecutionPricing module, uint128 ask, uint128 bid) internal {
        ExecutionPricing.Level[] memory asks = new ExecutionPricing.Level[](1);
        ExecutionPricing.Level[] memory bids = new ExecutionPricing.Level[](1);
        asks[0] = ExecutionPricing.Level(ask, 100_000e18);
        bids[0] = ExecutionPricing.Level(bid, 100_000e18);
        module.publish(block.timestamp, asks, bids);
    }

    function _position() internal view returns (HedgerPool.HedgePosition memory p) {
        (bool ok, bytes memory data) = address(hedgerPool).staticcall(
            abi.encodeWithSignature("positions(uint256)", 1));
        assertTrue(ok);
        return abi.decode(data, (HedgerPool.HedgePosition));
    }

    function test_CombinedRelease_ExecutionSpreadAndHedgerProfitConserveUsdc() public {
        ExecutionPricing module = new ExecutionPricing(
            [address(vault), address(0x1234), admin, address(this), address(this), treasury],
            [uint256(60), uint256(25), uint256(10), uint256(1000e18)]
        );
        // Model the router's venue selection while keeping the real reference feed checks.
        vm.mockCall(address(oracle), abi.encodeWithSignature("activeOracle()"), abi.encode(uint8(1)));
        vm.mockCall(address(oracle), abi.encodeWithSignature("marketOracle()"), abi.encode(address(0x1234)));
        _publish(module, 1.1001e18, 1.0999e18);
        module.acknowledge(0, 0, 1000e18, block.timestamp);

        vm.startPrank(admin);
        vault.updateParameters(0, 0);
        vault.pause();
        vault.configureExecutionPricing(address(module));
        vault.unpause();
        vm.stopPrank();
        vm.prank(hedger);
        hedgerPool.enterHedgePosition(200e6, 10);
        uint256 userBefore = usdc.balanceOf(user);

        vm.startStateDiffRecording();
        vm.prank(user);
        vault.mintQEURO(110120010, 100e18);
        VmSafe.AccountAccess[] memory accesses = vm.stopAndReturnStateDiff();
        for (uint256 i; i < accesses.length; ++i) {
            assertFalse(
                accesses[i].account == address(vault.timelock())
                    && accesses[i].accessor == address(vault)
                    && accesses[i].kind == VmSafe.AccountAccessKind.StaticCall,
                "mint timing must not probe the upgrade authority"
            );
        }
        assertEq(_position().filledVolume, 110e6);
        assertEq(_position().qeuroBacked, 100e18);
        assertEq(usdc.balanceOf(address(module)), 120010);

        vm.roll(block.number + 10);
        vm.warp(block.timestamp + 1);
        vm.mockCall(address(0x123), abi.encodeWithSelector(bytes4(0xfeaf968c)),
            abi.encode(uint80(2), int256(1.09e8), block.timestamp, block.timestamp, uint80(2)));
        _publish(module, 1.0901e18, 1.0899e18);
        vm.startPrank(user);
        qeuro.approve(address(vault), type(uint256).max);
        vault.redeemQEURO(100e18, 108881010);
        vm.stopPrank();

        assertEq(_position().margin, 201e6);
        assertEq(_position().filledVolume, 0);
        assertEq(_position().qeuroBacked, 0);
        assertEq(usdc.balanceOf(address(module)), 239000);
        assertEq(usdc.balanceOf(user), userBefore - 1239000);
        assertEq(module.outstanding(), 200e18);
        uint256 hedgerBefore = usdc.balanceOf(hedger);
        vm.prank(hedger);
        hedgerPool.exitHedgePosition(1);
        assertEq(usdc.balanceOf(hedger) - hedgerBefore, 201e6);
        assertEq(vault.getTotalUsdcAvailable(), 0);
        assertEq(qeuro.totalSupply(), 0);
    }
}
