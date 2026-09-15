// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
import {Test} from "forge-std/Test.sol";
import {ReportPublicationBatcher} from "../src/oracle/ReportPublicationBatcher.sol";
import {CommonErrorLibrary as Errors} from "../src/libraries/CommonErrorLibrary.sol";
contract ReportTargetMock {
    mapping(bytes4 => uint256) public calls;
    mapping(bytes4 => bool) public reject;
    bool public exhaust;
    ReportPublicationBatcher public reenter;
    function configure(bytes4 selector, bool fail) external { reject[selector] = fail; }
    function burn(bool value) external { exhaust = value; }
    function callback(ReportPublicationBatcher value) external { reenter = value; }
    fallback() external {
        if (reject[msg.sig]) revert Errors.InvalidTime();
        if (exhaust) { while (true) {} }
        if (address(reenter) != address(0)) reenter.publishReports(msg.data, "", "");
        calls[msg.sig]++;
    }
}
contract ReportPublicationBatcherTest is Test {
    ReportTargetMock price; ReportTargetMock depth; ReportPublicationBatcher batcher;
    address writer = address(0x1234);
    bytes p = abi.encodeWithSignature("updateSlippageBatch((uint8,uint128,uint128,uint16,uint16,uint16[5])[])");
    bytes d = abi.encodeWithSignature("publish(uint256,(uint128,uint128)[],(uint128,uint128)[])");
    bytes c = abi.encodeWithSignature("acknowledge(uint256,uint256,uint256,uint256)",0,0,0,1);
    function setUp() public { price=new ReportTargetMock(); depth=new ReportTargetMock(); batcher=new ReportPublicationBatcher(writer,address(price),address(depth)); }
    function testFuzz_OnlyWriter(address other) public { vm.assume(other!=writer); vm.prank(other); vm.expectRevert(Errors.NotAuthorized.selector); batcher.publishReports(p,d,c); }
    function testFuzz_AllNonemptySubsets(uint8 mask) public { mask=uint8(bound(mask,1,7)); vm.prank(writer); uint8 ok=batcher.publishReports(mask&1!=0?p:bytes(""),mask&2!=0?d:bytes(""),mask&4!=0?c:bytes("")); assertEq(ok,mask); assertEq(batcher.lastPublicationAt(),block.timestamp); }
    function test_CapacityRaceDoesNotUndoMarketReports() public { depth.configure(bytes4(c),true); vm.prank(writer); assertEq(batcher.publishReports(p,d,c),3); assertEq(price.calls(bytes4(p)),1); assertEq(depth.calls(bytes4(d)),1); assertEq(depth.calls(bytes4(c)),0); }
    function test_DepthFailureDoesNotBlockPriceOrCapacity() public { depth.configure(bytes4(d),true); vm.prank(writer); assertEq(batcher.publishReports(p,d,c),5); }
    function test_PriceFailureDoesNotBlockDepthOrCapacity() public { price.configure(bytes4(p),true); vm.prank(writer); assertEq(batcher.publishReports(p,d,c),6); }
    function test_AllFailedReverts() public { price.configure(bytes4(p),true); vm.prank(writer); vm.expectRevert(ReportPublicationBatcher.NoSuccessfulReports.selector); batcher.publishReports(p,"",""); assertEq(batcher.lastPublicationAt(),0); }
    function test_EmptyOrWrongSelectorRejectedBeforeEffects() public { vm.startPrank(writer); vm.expectRevert(Errors.InvalidParameter.selector); batcher.publishReports("","",""); vm.expectRevert(Errors.InvalidParameter.selector); batcher.publishReports(p,d,p); vm.expectRevert(Errors.InvalidParameter.selector); batcher.publishReports(hex"01",d,c); vm.stopPrank(); assertEq(price.calls(bytes4(p)),0); }
    function test_UnderfundedBatchCannotSucceedPartially() public { vm.prank(writer); vm.expectRevert(ReportPublicationBatcher.InsufficientReportGas.selector); batcher.publishReports{gas:500_000}(p,d,c); assertEq(price.calls(bytes4(p)),0); }
    function test_GasExhaustionIsIsolated() public { price.burn(true); vm.prank(writer); assertEq(batcher.publishReports(p,d,c),6); }
    function test_ReentryCannotPublish() public { price.callback(batcher); vm.prank(writer); assertEq(batcher.publishReports(p,d,c),6); assertEq(price.calls(bytes4(p)),0); }
    function test_Bindings() public view { assertEq(batcher.writer(),writer); assertEq(batcher.priceStore(),address(price)); assertEq(batcher.depthStore(),address(depth)); assertEq(batcher.version(),"1.0.0"); }
    function test_InvalidBindings() public { vm.expectRevert(Errors.InvalidAddress.selector); new ReportPublicationBatcher(address(price),address(price),address(depth)); }
}
