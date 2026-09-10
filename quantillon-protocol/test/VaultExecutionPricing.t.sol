// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {QuantillonVaultMintCollateralizationAndLiquidationThresholdTest} from "./QuantillonVault_MintCollateralizationAndLiquidationThreshold.t.sol";
import {ExecutionPricing} from "../src/oracle/ExecutionPricing.sol";
import {CommonErrorLibrary as Errors} from "../src/libraries/CommonErrorLibrary.sol";

contract VaultExecutionPricingTest is QuantillonVaultMintCollateralizationAndLiquidationThresholdTest {
    function _activate() internal returns (ExecutionPricing module) {
        vm.warp(100_000);
        module = new ExecutionPricing(
            [address(vault), address(0x1234), admin, address(this), address(this), admin],
            [uint256(60), uint256(500), uint256(0), uint256(1_000_000e18)]
        );
        vm.mockCall(address(oracle), abi.encodeWithSignature("activeOracle()"), abi.encode(uint8(1)));
        vm.mockCall(address(oracle), abi.encodeWithSignature("marketOracle()"), abi.encode(address(0x1234)));
        vm.mockCall(address(oracle), abi.encodeWithSignature("getEurUsdDetails()"), abi.encode(1e18,1e18,block.timestamp,false,true));
        ExecutionPricing.Level[] memory asks = new ExecutionPricing.Level[](1);
        ExecutionPricing.Level[] memory bids = new ExecutionPricing.Level[](1);
        asks[0] = ExecutionPricing.Level(1.01e18,100_000e18);
        bids[0] = ExecutionPricing.Level(0.99e18,100_000e18);
        module.publish(block.timestamp,asks,bids);
        module.acknowledge(0,0,1_000_000e18,block.timestamp);
        vm.startPrank(admin);
        vault.pause();
        vault.configureExecutionPricing(address(module));
        vault.unpause();
        vm.stopPrank();
        _seedHedgerMargin(10_000e6);
    }

    function test_ExecutionMintRedeemConservesBackingAndSpread() public {
        ExecutionPricing module = _activate();
        uint256 held = vault.totalUsdcHeld();
        uint256 userBefore = usdc.balanceOf(bootstrapUser);
        vm.startPrank(bootstrapUser);
        usdc.approve(address(vault),1010e6);
        vault.mintQEURO(1010e6,1000e18);
        vm.stopPrank();
        assertEq(qeuro.balanceOf(bootstrapUser),1000e18);
        assertEq(vault.totalUsdcHeld(),held+1000e6);
        assertEq(usdc.balanceOf(address(module)),10e6);
        assertEq(vault.getProtocolCollateralizationRatio(),1100e18);
        vm.prank(bootstrapUser);
        vault.redeemQEURO(1000e18,990e6);
        assertEq(qeuro.balanceOf(bootstrapUser),0);
        assertEq(vault.totalUsdcHeld(),held);
        assertEq(usdc.balanceOf(address(module)),20e6);
        assertEq(usdc.balanceOf(bootstrapUser),userBefore-20e6);
        assertEq(module.outstanding(),2000e18);
    }

    function test_UserFloorRevertRollsBackCapacityAndFunds() public {
        ExecutionPricing module = _activate();
        uint256 beforeBalance = usdc.balanceOf(bootstrapUser);
        vm.startPrank(bootstrapUser);
        usdc.approve(address(vault),1010e6);
        vm.expectRevert(Errors.ExcessiveSlippage.selector);
        vault.mintQEURO(1010e6,1001e18);
        vm.stopPrank();
        assertEq(module.outstanding(),0);
        assertEq(usdc.balanceOf(bootstrapUser),beforeBalance);
    }

    function test_DirectMintCannotBypassStaleDepth() public {
        ExecutionPricing module = _activate();
        vm.warp(100_061);
        vm.startPrank(bootstrapUser);
        usdc.approve(address(vault),1010e6);
        vm.expectRevert(Errors.InvalidOraclePrice.selector);
        vault.mintQEURO(1010e6,0);
        vm.stopPrank();
        assertEq(module.outstanding(),0);
    }

    function test_ModuleCannotBeRemovedWithOutstandingHedge() public {
        _activate();
        vm.startPrank(bootstrapUser);
        usdc.approve(address(vault),1010e6);
        vault.mintQEURO(1010e6,0);
        vm.stopPrank();
        vm.startPrank(admin);
        vault.pause();
        vm.expectRevert(Errors.InvalidCondition.selector);
        vault.configureExecutionPricing(address(0));
        vm.stopPrank();
    }
}
