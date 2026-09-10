// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ExecutionPricing} from "../src/oracle/ExecutionPricing.sol";
import {CommonErrorLibrary as Errors} from "../src/libraries/CommonErrorLibrary.sol";

contract ExecutionPricingTest is Test {
    ExecutionPricing internal pricing;
    uint256 public mintFee;
    uint256 public redemptionFee;
    bool public paused;
    uint8 public activeOracle = 1;
    address public marketOracle = address(0x1234);
    uint256 internal ref = 1e18;
    function oracle() external view returns (address) { return address(this); }
    function getEurUsdDetails() external view returns (uint256,uint256,uint256,bool,bool) { return (ref,ref,block.timestamp,false,true); }

    function setUp() public {
        vm.warp(10_000);
        pricing = new ExecutionPricing(
            [address(this), marketOracle, address(this), address(this), address(this), address(0xBEEF)],
            [uint256(60), uint256(500), uint256(0), uint256(1_000_000e18)]
        );
        pricing.acknowledge(0,0,1_000_000e18,block.timestamp);
        _publish();
    }

    function _publish() internal {
        ExecutionPricing.Level[] memory asks = new ExecutionPricing.Level[](2);
        ExecutionPricing.Level[] memory bids = new ExecutionPricing.Level[](2);
        asks[0] = ExecutionPricing.Level(1.001e18,10_000e18);
        asks[1] = ExecutionPricing.Level(1.01e18,20_000e18);
        bids[0] = ExecutionPricing.Level(0.999e18,10_000e18);
        bids[1] = ExecutionPricing.Level(0.99e18,20_000e18);
        pricing.publish(block.timestamp,asks,bids);
    }

    function test_VolumeDependentRateAndConservation() public {
        ExecutionPricing.Quote memory small = pricing.previewMint(1001e6);
        ExecutionPricing.Quote memory large = pricing.previewMint(20_110e6);
        assertEq(small.amountOut,1000e18);
        assertEq(large.amountOut,20_000e18);
        assertGt(large.executionRate,small.executionRate);
        (uint256 q,uint256 backing) = pricing.consumeMint(20_110e6,ref);
        assertEq(q,large.amountOut);
        assertEq(backing,20_000e6);
        assertEq(20_110e6-backing,110e6);
        assertEq(pricing.outstanding(),q);
    }

    function test_SplittingCannotReuseCheapDepth() public {
        (uint256 q1,) = pricing.consumeMint(10_010e6,ref);
        (uint256 q2,) = pricing.consumeMint(10_100e6,ref);
        assertEq(q1+q2,20_000e18);
        assertEq(pricing.usedBuy(),20_000e18);
    }

    function test_PublishDoesNotResetPendingConsumption() public {
        pricing.consumeMint(10_010e6,ref);
        vm.warp(10_001);
        _publish();
        assertEq(pricing.usedBuy(),10_000e18);
        assertEq(pricing.previewMint(10_100e6).amountOut,10_000e18);
        vm.expectRevert(Errors.InvalidAmount.selector);
        pricing.acknowledge(0,0,1_000_000e18,block.timestamp);
        pricing.acknowledge(10_000e18,0,1_000_000e18,block.timestamp);
        assertEq(pricing.usedBuy(),10_000e18);
        vm.warp(10_002);
        // A fresh account heartbeat must not postpone release of already hedged depth.
        pricing.acknowledge(10_000e18,0,1_000_000e18,block.timestamp);
        _publish();
        assertEq(pricing.usedBuy(),0);
        (uint256 buy, uint256 sell) = pricing.availableCapacity();
        assertEq(buy,30_000e18);
        assertEq(sell,30_000e18);
    }

    function test_InsufficientDepthAndStaleObservationsRevert() public {
        vm.expectRevert(Errors.InsufficientBalance.selector);
        pricing.previewMint(31_000e6);
        vm.expectRevert(Errors.InsufficientBalance.selector);
        pricing.previewRedeem(30_001e18);
        vm.warp(block.timestamp+61);
        vm.expectRevert(Errors.InvalidOraclePrice.selector);
        pricing.previewMint(100e6);
    }

    function test_DirectionalRedemptionAndFeeBasis() public {
        redemptionFee = 1e16;
        ExecutionPricing.Quote memory quote = pricing.previewRedeem(20_000e18);
        assertEq(quote.amountOut,19_890e6-200e6);
        assertEq(pricing.consumeRedeem(20_000e18,ref),19_890e6);
    }

    function test_MarginCapacityAndVenueFailClosed() public {
        pricing.acknowledge(0,0,100e18,block.timestamp);
        vm.expectRevert(Errors.InsufficientBalance.selector);
        pricing.previewMint(101e6);
        activeOracle = 0;
        vm.expectRevert(Errors.InvalidOracle.selector);
        pricing.previewMint(10e6);
    }

    function test_OnlyVaultConsumesAndOnlyReporterAcknowledges() public {
        vm.prank(address(0xBAD));
        vm.expectRevert(Errors.NotAuthorized.selector);
        pricing.consumeMint(1e6,ref);
        vm.prank(address(0xBAD));
        vm.expectRevert();
        pricing.acknowledge(0,0,1e18,block.timestamp);
    }

    function test_OldAndFutureBookRejected() public {
        vm.expectRevert(Errors.InvalidTime.selector);
        _publish();
        ExecutionPricing.Level[] memory levels = new ExecutionPricing.Level[](1);
        levels[0] = ExecutionPricing.Level(1e18,1e18);
        vm.expectRevert(Errors.InvalidTime.selector);
        pricing.publish(block.timestamp+1,levels,levels);
    }

    function testFuzz_MintReferenceBackingDoesNotExceedInput(uint256 input) public {
        input = bound(input,2,30_000e6);
        (uint256 q,uint256 backing) = pricing.consumeMint(input,ref);
        assertGt(q,0);
        assertLe(backing,input);
        assertLe(q,30_000e18);
    }

    function test_RiskLimitsRequireGovernancePauseAndSettledAdmission() public {
        paused = true;
        vm.prank(address(0xBAD));
        vm.expectRevert();
        pricing.updateRiskLimits(60,25,10,1000e18);
        paused = false;
        vm.expectRevert(Errors.InvalidCondition.selector);
        pricing.updateRiskLimits(60,25,10,1000e18);
        pricing.consumeMint(1001e6,ref);
        paused = true;
        vm.expectRevert(Errors.InvalidCondition.selector);
        pricing.updateRiskLimits(60,25,10,1000e18);
        assertEq(pricing.outstanding(),1000e18);
    }

    function test_RiskLimitsInvalidateReportsAndPreserveAdmissionHistory() public {
        pricing.consumeMint(1001e6,ref);
        pricing.acknowledge(1000e18,0,1_000_000e18,block.timestamp);
        paused = true;
        pricing.updateRiskLimits(120,25,10,1000e18);
        assertEq(pricing.maxAge(),120);
        assertEq(pricing.maxImpactBps(),25);
        assertEq(pricing.bufferBps(),10);
        assertEq(pricing.maxOutstanding(),1000e18);
        assertEq(pricing.admittedBuy(),1000e18);
        assertEq(pricing.acknowledgedBuy(),1000e18);
        assertEq(pricing.outstanding(),0);
        assertEq(pricing.marginCapacity(),0);
        assertEq(pricing.observedAt(),0);
        assertEq(pricing.capacityObservedAt(),0);
        vm.expectRevert(Errors.InvalidOraclePrice.selector);
        pricing.previewMint(10e6);
        vm.expectRevert(Errors.InvalidTime.selector);
        _publish();
        vm.expectRevert(Errors.InvalidTime.selector);
        pricing.acknowledge(1000e18,0,1000e18,block.timestamp);
        vm.warp(block.timestamp+1);
        pricing.acknowledge(1000e18,0,1000e18,block.timestamp);
        _publish();
        paused = false;
        (uint256 buy,uint256 sell) = pricing.availableCapacity();
        assertEq(buy,1000e18);
        assertEq(sell,1000e18);
        pricing.consumeMint(10e6,ref);
        assertGt(pricing.outstanding(),0);
    }

    function test_RiskLimitBounds() public {
        paused = true;
        vm.expectRevert(Errors.InvalidParameter.selector);
        pricing.updateRiskLimits(0,25,10,1000e18);
        vm.expectRevert(Errors.InvalidParameter.selector);
        pricing.updateRiskLimits(301,25,10,1000e18);
        vm.expectRevert(Errors.InvalidParameter.selector);
        pricing.updateRiskLimits(60,0,0,1000e18);
        vm.expectRevert(Errors.InvalidParameter.selector);
        pricing.updateRiskLimits(60,501,10,1000e18);
        vm.expectRevert(Errors.InvalidParameter.selector);
        pricing.updateRiskLimits(60,25,26,1000e18);
        vm.expectRevert(Errors.InvalidParameter.selector);
        pricing.updateRiskLimits(60,25,10,0);
    }
}
