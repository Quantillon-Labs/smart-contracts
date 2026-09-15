// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {PublicationBatcher} from "../src/oracle/PublicationBatcher.sol";
import {CommonErrorLibrary as Errors} from "../src/libraries/CommonErrorLibrary.sol";

contract PublicationTargetMock {
    bytes public received;
    address public caller;
    bool public reject;
    bool public reenter;
    PublicationBatcher public batcher;
    function configure(bool fail, bool callback, PublicationBatcher target) external {
        reject = fail; reenter = callback; batcher = target;
    }
    fallback() external {
        if (reject) revert Errors.InvalidTime();
        if (reenter) batcher.publishTogether(msg.data, msg.data);
        received = msg.data;
        caller = msg.sender;
    }
}

contract PublicationBatcherTest is Test {
    PublicationTargetMock internal price;
    PublicationTargetMock internal depth;
    PublicationBatcher internal batcher;
    address internal writer = address(0x1234);
    bytes internal priceCall = abi.encodeWithSignature("updateSlippageBatch((uint8,uint128,uint128,uint16,uint16,uint16[5])[])");
    bytes internal depthCall = abi.encodeWithSignature("publish(uint256,(uint128,uint128)[],(uint128,uint128)[])");

    function setUp() public {
        price = new PublicationTargetMock(); depth = new PublicationTargetMock();
        batcher = new PublicationBatcher(writer, address(price), address(depth));
    }
    function test_ImmutableBindingsAndVersion() public view {
        assertEq(batcher.writer(), writer); assertEq(batcher.priceStore(), address(price));
        assertEq(batcher.depthStore(), address(depth)); assertEq(batcher.version(), "1.0.0");
    }
    function testFuzz_OnlyWriter(address stranger) public {
        vm.assume(stranger != writer);
        vm.prank(stranger); vm.expectRevert(Errors.NotAuthorized.selector);
        batcher.publishTogether(priceCall, depthCall);
    }
    function test_ForwardsExactCalldataWithBatcherAsCaller() public {
        vm.prank(writer); batcher.publishTogether(priceCall, depthCall);
        assertEq(price.received(), priceCall); assertEq(depth.received(), depthCall);
        assertEq(price.caller(), address(batcher)); assertEq(depth.caller(), address(batcher));
    }
    function test_DepthRevertRollsBackPriceAndBubblesReason() public {
        depth.configure(true, false, batcher);
        vm.prank(writer); vm.expectRevert(Errors.InvalidTime.selector);
        batcher.publishTogether(priceCall, depthCall);
        assertEq(price.received().length, 0); assertEq(depth.received().length, 0);
    }
    function test_PriceRevertPreventsDepth() public {
        price.configure(true, false, batcher);
        vm.prank(writer); vm.expectRevert(Errors.InvalidTime.selector);
        batcher.publishTogether(priceCall, depthCall);
        assertEq(depth.received().length, 0);
    }
    function test_TargetCannotReenter() public {
        price.configure(false, true, batcher);
        vm.prank(writer); vm.expectRevert(Errors.NotAuthorized.selector);
        batcher.publishTogether(priceCall, depthCall);
    }
    function test_NoArbitrarySelectorsOrEmptyCalls() public {
        bytes memory grant = abi.encodeWithSignature("grantRole(bytes32,address)", bytes32(0), writer);
        vm.startPrank(writer);
        vm.expectRevert(Errors.InvalidParameter.selector); batcher.publishTogether(grant, depthCall);
        vm.expectRevert(Errors.InvalidParameter.selector); batcher.publishTogether(priceCall, grant);
        vm.expectRevert(Errors.InvalidParameter.selector); batcher.publishTogether(hex"", depthCall);
        vm.expectRevert(Errors.InvalidParameter.selector); batcher.publishTogether(priceCall, hex"010203");
        vm.expectRevert(Errors.InvalidParameter.selector); batcher.publishTogether(depthCall, priceCall);
        vm.stopPrank();
    }
    function test_InvalidBindingsRejected() public {
        vm.expectRevert(Errors.InvalidAddress.selector); new PublicationBatcher(address(0), address(price), address(depth));
        vm.expectRevert(Errors.InvalidAddress.selector); new PublicationBatcher(writer, address(0), address(depth));
        vm.expectRevert(Errors.InvalidAddress.selector); new PublicationBatcher(writer, address(price), writer);
        vm.expectRevert(Errors.InvalidAddress.selector); new PublicationBatcher(writer, address(price), address(price));
        vm.expectRevert(Errors.InvalidAddress.selector); new PublicationBatcher(address(price), address(price), address(depth));
    }
}
