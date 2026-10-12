// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ReferenceSettlementLibrary} from "../src/libraries/ReferenceSettlementLibrary.sol";
import {SignedReferenceSource} from "../src/oracle/SignedReferenceSource.sol";
import {SignedQuoteTypes as T} from "../src/libraries/SignedQuoteTypes.sol";
import {SignedQuoteErrors as E} from "../src/libraries/SignedQuoteErrors.sol";

contract ReferenceRouterFixture {
    uint8 public activeOracle = 1;
    address public marketOracle;
    address public slippageStorage;
    constructor(address source) { marketOracle = address(this); slippageStorage = source; }
    function select(uint8 choice) external { activeOracle = choice; }
}

contract ReferencePoolFixture {
    address public oracle;
    address public owner;
    address public lastCaller;
    uint256 public withdrawn;
    constructor(address router, address hedger) { oracle = router; owner = hedger; }
    function executeWithReference(bytes calldata data, bytes calldata auth) external returns (bytes memory) {
        return ReferenceSettlementLibrary.executeWithReference(data, auth);
    }
    function removeMargin(uint256, uint256 amount) external {
        require(msg.sender == owner, "OWNER");
        require(amount < 100, "FLOOR");
        lastCaller = msg.sender; withdrawn += amount;
    }
}

contract ReferenceSettlementTest is Test {
    uint256 private constant KEY = 12345;
    SignedReferenceSource private source;
    ReferenceRouterFixture private router;
    ReferencePoolFixture private pool;
    address private hedger = address(0xBEEF);
    function peekEurUsdPrice() external view returns (uint256, uint256, bool) { return (1e18, block.timestamp, true); }
    function setUp() public {
        vm.warp(1000);
        source = new SignedReferenceSource(address(this), address(this), 60, 8100, 200, 300);
        source.grantRole(source.REFERENCE_SIGNER_ROLE(), vm.addr(KEY));
        router = new ReferenceRouterFixture(address(source));
        pool = new ReferencePoolFixture(address(router), hedger);
    }
    function _auth() private view returns (bytes memory) {
        T.ReferenceReport memory r = T.ReferenceReport(1e18, block.timestamp, 1, source.epoch());
        (uint8 v, bytes32 a, bytes32 b) = vm.sign(KEY, source.digest(r));
        return abi.encode(r, abi.encodePacked(a,b,v));
    }
    function test_ReferenceAndOperationPreserveHedgerIdentity() public {
        bytes memory auth = _auth();
        vm.prank(hedger); pool.executeWithReference(abi.encodeCall(pool.removeMargin,(1,25)),auth);
        assertEq(pool.lastCaller(),hedger); assertEq(pool.withdrawn(),25); assertEq(source.observedAt(),1000);
    }
    function test_OperationFailureRevertsReferenceUpdate() public {
        bytes memory auth = _auth();
        vm.prank(hedger); vm.expectRevert("FLOOR"); pool.executeWithReference(abi.encodeCall(pool.removeMargin,(1,100)),auth);
        assertEq(source.sequence(),0); assertEq(pool.withdrawn(),0);
    }
    function test_ReferenceDoesNotGrantHedgerPermissions() public {
        bytes memory auth = _auth();
        vm.expectRevert("OWNER"); pool.executeWithReference(abi.encodeCall(pool.removeMargin,(1,25)),auth);
        assertEq(source.sequence(),0);
    }
    function test_NoRecursiveDispatchOrTargetOverride() public {
        vm.expectRevert(E.InvalidBinding.selector); pool.executeWithReference(abi.encodeWithSignature("executeWithReference(bytes,bytes)","",""),"");
        vm.expectRevert(E.InvalidBinding.selector); pool.executeWithReference(abi.encodeWithSignature("upgradeToAndCall(address,bytes)",address(this),""),"");
    }
    function test_WrongRouterModeRejectsSignedDelivery() public {
        router.select(0);
        bytes memory auth = _auth();
        vm.prank(hedger); vm.expectRevert(E.InvalidMode.selector); pool.executeWithReference(abi.encodeCall(pool.removeMargin,(1,25)),auth);
    }
}
