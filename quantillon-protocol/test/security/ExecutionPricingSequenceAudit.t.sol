// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ExecutionPricingTest} from "../ExecutionPricing.t.sol";
import {CommonErrorLibrary as Errors} from "../../src/libraries/CommonErrorLibrary.sol";

contract ExecutionPricingSequenceAuditTest is ExecutionPricingTest {
    function testFuzz_Audit_SplittingBudgetCannotImproveOutput(uint256 total, uint256 first) public {
        total = bound(total, 4, 29_000e6);
        first = bound(first, 2, total - 2);
        uint256 unsplit = pricing.previewMint(total).amountOut;
        (uint256 q1,) = pricing.consumeMint(first, ref);
        (uint256 q2,) = pricing.consumeMint(total-first, ref);
        assertLe(q1+q2, unsplit);
        assertEq(pricing.usedBuy(), q1+q2);
        assertEq(pricing.outstanding(), q1+q2);
    }

    function test_Audit_FreshBookCannotRefreshExpiredCapacity() public {
        vm.warp(block.timestamp + 61);
        _publish();
        vm.expectRevert(Errors.InvalidOraclePrice.selector);
        pricing.previewMint(100e6);
    }

    function test_Audit_FreshCapacityCannotRefreshExpiredBook() public {
        vm.warp(block.timestamp + 61);
        pricing.acknowledge(0,0,1000e18,block.timestamp);
        vm.expectRevert(Errors.InvalidOraclePrice.selector);
        pricing.previewMint(100e6);
    }

    function test_Audit_OppositeTradesDoNotCancelUnhedgedCapacityUse() public {
        pricing.acknowledge(0,0,2000e18,block.timestamp);
        pricing.consumeMint(1001e6,ref);
        pricing.consumeRedeem(1000e18,ref);
        assertEq(pricing.outstanding(),2000e18);
        (uint256 buy,uint256 sell)=pricing.availableCapacity();
        assertEq(buy,0);
        assertEq(sell,0);
    }

    function test_Audit_AcknowledgmentPreparedBeforeAnotherMintReverts() public {
        pricing.consumeMint(1001e6,ref);
        uint256 observedBuy=pricing.admittedBuy();
        pricing.consumeMint(1001e6,ref);
        vm.expectRevert(Errors.InvalidAmount.selector);
        pricing.acknowledge(observedBuy,0,1000e18,block.timestamp);
        assertEq(pricing.acknowledgedBuy(),0);
        assertEq(pricing.outstanding(),2000e18);
    }
}
