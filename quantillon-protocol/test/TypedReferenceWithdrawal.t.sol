// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
import {HedgerPoolTestSuite} from "./HedgerPool.t.sol";
import {SignedReferenceSource} from "../src/oracle/SignedReferenceSource.sol";
import {SignedQuoteTypes as T} from "../src/libraries/SignedQuoteTypes.sol";

/// Real HedgerPool proxy and reference source; existing fixture mocks token/vault/market reads.
contract TypedReferenceWithdrawalTest is HedgerPoolTestSuite {
    function peekEurUsdPrice() external view returns (uint256,uint256,bool) { return (EUR_USD_PRICE,block.timestamp,true); }
    function _fixture() internal returns (SignedReferenceSource source, bytes memory auth, uint256 id) {
        vm.warp(1000);
        _setSingleHedger(hedger1);
        vm.prank(hedger1); id = hedgerPool.enterHedgePosition(MARGIN_AMOUNT,5);
        source = new SignedReferenceSource(address(this),address(this),60,8100,200,300);
        source.grantRole(source.REFERENCE_SIGNER_ROLE(),vm.addr(12345));
        vm.mockCall(mockOracle,abi.encodeWithSignature("activeOracle()"),abi.encode(uint8(1)));
        vm.mockCall(mockOracle,abi.encodeWithSignature("marketOracle()"),abi.encode(mockOracle));
        vm.mockCall(mockOracle,abi.encodeWithSignature("slippageStorage()"),abi.encode(address(source)));
        T.ReferenceReport memory report = T.ReferenceReport(EUR_USD_PRICE,block.timestamp,1,source.epoch());
        (uint8 v,bytes32 r,bytes32 sigS) = vm.sign(12345,source.digest(report));
        auth = abi.encode(report,abi.encodePacked(r,sigS,v));
    }
    function test_TypedReferenceWithdrawalPreservesOwnerAndAccounting() public {
        (SignedReferenceSource source,bytes memory auth,uint256 id)=_fixture();
        uint256 beforeMargin=hedgerPool.totalMargin();
        vm.prank(hedger1);hedgerPool.removeMarginWithReference(id,2000e6,auth);
        assertEq(hedgerPool.totalMargin(),beforeMargin-2000e6);assertEq(source.sequence(),1);
    }
    function test_TypedReferenceWithdrawalRejectsUnauthorizedCallerAndRollsBack() public {
        (SignedReferenceSource source,bytes memory auth,uint256 id)=_fixture();
        uint256 beforeMargin=hedgerPool.totalMargin();
        vm.prank(address(0xBAD));vm.expectRevert();hedgerPool.removeMarginWithReference(id,2000e6,auth);
        assertEq(hedgerPool.totalMargin(),beforeMargin);assertEq(source.sequence(),0);
    }
    function test_TypedReferenceWithdrawalRollsBackOnEconomicFailure() public {
        (SignedReferenceSource source,bytes memory auth,uint256 id)=_fixture();
        uint256 beforeMargin=hedgerPool.totalMargin();
        vm.prank(hedger1);vm.expectRevert();hedgerPool.removeMarginWithReference(id,MARGIN_AMOUNT*2,auth);
        assertEq(hedgerPool.totalMargin(),beforeMargin);assertEq(source.sequence(),0);
    }
    function test_TypedReferenceWithdrawalRejectsExpiredReference() public {
        (SignedReferenceSource source,bytes memory auth,uint256 id)=_fixture();
        vm.warp(block.timestamp+61);
        vm.prank(hedger1);vm.expectRevert();hedgerPool.removeMarginWithReference(id,2000e6,auth);
        assertEq(source.sequence(),0);
    }
}
