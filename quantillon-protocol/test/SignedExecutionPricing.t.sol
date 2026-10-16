// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SignedExecutionPricing} from "../src/oracle/SignedExecutionPricing.sol";
import {SignedReferenceSource} from "../src/oracle/SignedReferenceSource.sol";
import {SignedSettlementLibrary} from "../src/libraries/SignedSettlementLibrary.sol";
import {SignedQuoteTypes as T} from "../src/libraries/SignedQuoteTypes.sol";
import {SignedQuoteErrors as E} from "../src/libraries/SignedQuoteErrors.sol";

contract SignedVaultHarness is ReentrancyGuard {
    SignedExecutionPricing public module;
    uint256 public mintFee;
    uint256 public redemptionFee;
    bool public paused = true;
    bool public signedExecutionEnabled = true;
    uint256 public minted;
    uint256 public backing;
    address public lastCaller;
    function configure(SignedExecutionPricing p) external { module = p; }
    function execute(bytes calldata callData, bytes calldata auth) external returns (bytes memory) {
        return SignedSettlementLibrary.execute(address(module), callData, auth);
    }
    function mintQEURO(uint256 input, uint256 minimum) external nonReentrant {
        lastCaller = msg.sender;
        (uint256 q, uint256 b) = module.consumeMint(input, module.referenceSource().price());
        require(q >= minimum); minted += q; backing += b;
    }
    function redeemQEURO(uint256 input, uint256 minimum) external nonReentrant {
        uint256 out = module.consumeRedeem(input, 1e18); require(out >= minimum);
    }
    function harvestAndDistributeVaultYield(uint256 amount) external nonReentrant {
        if (amount > 0) { (uint256 q,) = module.consumeMint(amount, module.referenceSource().price()); minted += q; }
    }
    function emergency(uint256 input) external { SignedSettlementLibrary.emergencyRedeem(address(module), input, 0); }
}

contract SignedExecutionPricingTest is Test {
    uint256 private constant KEY = 0x12345;
    address private signer;
    SignedVaultHarness private vault;
    SignedReferenceSource private source;
    SignedExecutionPricing private pricing;
    function peekEurUsdPrice() external view returns (uint256, uint256, bool) { return (1e18, block.timestamp, true); }

    function setUp() public {
        vm.warp(1_000_000); vm.roll(100);
        vm.setBlockhash(99, keccak256("canonical"));
        signer = vm.addr(KEY);
        vault = new SignedVaultHarness();
        source = new SignedReferenceSource(address(this), address(this), 60, 8100, 200, 300);
        pricing = new SignedExecutionPricing(address(this), address(vault), address(source), address(this), 25, 1000e18, 60, 25);
        vault.configure(pricing);
        source.grantRole(source.REFERENCE_SIGNER_ROLE(), signer);
        source.grantRole(source.EMERGENCY_CONTROLLER_ROLE(), address(pricing));
        pricing.grantRole(pricing.QUOTE_SIGNER_ROLE(), signer);
        pricing.grantRole(pricing.CAPACITY_SIGNER_ROLE(), signer);
        pricing.setMode(T.Mode.Signed);
    }

    function _sign(bytes32 hash) private view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(KEY, hash);
        return abi.encodePacked(r, s, v);
    }

    function _auth(bytes memory data, uint256 input, uint256 output, uint256 nonce) private view returns (T.Authorization memory a) {
        a.referenceReport = T.ReferenceReport(1e18, block.timestamp, 1, source.epoch());
        a.referenceSignature = _sign(source.digest(a.referenceReport));
        a.capacityReport = T.CapacityReport(0, 0, 1000e18, block.timestamp, 1, pricing.epoch(), 99, keccak256("canonical"));
        a.capacitySignature = _sign(pricing.capacityDigest(a.capacityReport));
        a.quote = T.Quote(address(this), address(this), T.Action.Mint, input, output, block.timestamp, block.timestamp, block.timestamp + 20, nonce, pricing.epoch(), keccak256(data), source.digest(a.referenceReport));
        a.signature = _sign(pricing.quoteDigest(a.quote));
    }

    function test_AtomicSettlementPreservesCallerAndAccounting() public {
        bytes memory data = abi.encodeWithSignature("mintQEURO(uint256,uint256)", 100e6, 100e18);
        T.Authorization memory a = _auth(data, 100e6, 100e18, 1);
        vault.execute(data, abi.encode(a));
        assertEq(vault.minted(), 100e18); assertEq(vault.backing(), 100e6);
        assertEq(vault.lastCaller(), address(this)); assertEq(pricing.outstanding(), 100e18);
        assertFalse(pricing.active());
        vm.expectRevert(E.QuoteConsumed.selector); vault.execute(data, abi.encode(a));
    }

    function test_DirectLegacyCallCannotConsumeQuote() public {
        vm.expectRevert(E.QuoteRequired.selector); vault.mintQEURO(100e6, 0);
    }

    function test_ConcurrentValidQuotesCannotExceedCapacity() public {
        bytes memory data = abi.encodeWithSignature("mintQEURO(uint256,uint256)", 600e6, 600e18);
        T.Authorization memory a = _auth(data, 600e6, 600e18, 1);
        T.Authorization memory b = _auth(data, 600e6, 600e18, 2);
        vault.execute(data, abi.encode(a));
        vm.expectRevert(E.CapacityExceeded.selector); vault.execute(data, abi.encode(b));
        assertEq(pricing.outstanding(), 600e18); assertFalse(pricing.usedNonces(address(this), 2));
    }

    function test_FailedSettlementRollsBackNonceReportsAndAdmission() public {
        bytes memory data = abi.encodeWithSignature("mintQEURO(uint256,uint256)", 100e6, 101e18);
        T.Authorization memory a = _auth(data, 100e6, 100e18, 1);
        vm.expectRevert(); vault.execute(data, abi.encode(a));
        assertFalse(pricing.usedNonces(address(this), 1)); assertEq(pricing.outstanding(), 0);
        assertEq(source.sequence(), 0); assertFalse(pricing.active());
    }

    function test_WrongCallerAndChangedRouteRejected() public {
        bytes memory data = abi.encodeWithSignature("mintQEURO(uint256,uint256)", 100e6, 0);
        T.Authorization memory a = _auth(data, 100e6, 100e18, 1);
        vm.prank(address(0xCAFE)); vm.expectRevert(E.InvalidBinding.selector); vault.execute(data, abi.encode(a));
        vm.expectRevert(E.InvalidBinding.selector); vault.execute(abi.encodeWithSignature("mintQEURO(uint256,uint256)", 200e6, 0), abi.encode(a));
    }

    function test_ExpiredAndRevokedQuotesRejected() public {
        bytes memory data = abi.encodeWithSignature("mintQEURO(uint256,uint256)", 100e6, 0);
        T.Authorization memory a = _auth(data, 100e6, 100e18, 1);
        vm.warp(block.timestamp + 21);
        vm.expectRevert(E.InvalidTime.selector); vault.execute(data, abi.encode(a));
        vm.warp(block.timestamp - 21);
        pricing.revokeRole(pricing.QUOTE_SIGNER_ROLE(), signer);
        vm.expectRevert(E.InvalidSignature.selector); vault.execute(data, abi.encode(a));
    }

    function test_QuoteValidFor45SecondsIncludingFinalSecond() public {
        bytes memory data = abi.encodeWithSignature("mintQEURO(uint256,uint256)", 100e6, 0);
        T.Authorization memory a = _auth(data, 100e6, 100e18, 1);
        a.quote.validUntil = block.timestamp + 45;
        a.signature = _sign(pricing.quoteDigest(a.quote));
        vm.warp(block.timestamp + 45);
        vault.execute(data, abi.encode(a));
        assertEq(vault.minted(), 100e18);
    }

    function test_QuoteLongerThan45SecondsRejected() public {
        bytes memory data = abi.encodeWithSignature("mintQEURO(uint256,uint256)", 100e6, 0);
        T.Authorization memory a = _auth(data, 100e6, 100e18, 1);
        a.quote.validUntil = block.timestamp + 46;
        a.signature = _sign(pricing.quoteDigest(a.quote));
        vm.expectRevert(E.InvalidTime.selector);
        vault.execute(data, abi.encode(a));
    }

    function test_45SecondQuoteRejectedAfterExpiry() public {
        bytes memory data = abi.encodeWithSignature("mintQEURO(uint256,uint256)", 100e6, 0);
        T.Authorization memory a = _auth(data, 100e6, 100e18, 1);
        a.quote.validUntil = block.timestamp + 45;
        a.signature = _sign(pricing.quoteDigest(a.quote));
        vm.warp(block.timestamp + 46);
        vm.expectRevert(E.InvalidTime.selector);
        vault.execute(data, abi.encode(a));
    }

    function test_SignedAmountCannotMintUnbackedQeuro() public {
        bytes memory data = abi.encodeWithSignature("mintQEURO(uint256,uint256)", 100e6, 0);
        T.Authorization memory a = _auth(data, 100e6, 101e18, 1);
        vm.expectRevert(E.ExcessiveImpact.selector); vault.execute(data, abi.encode(a));
    }

    function test_EmergencyModeDoesNotReplenishBudget() public {
        pricing.configureEmergencyBudget(100e18);
        pricing.setMode(T.Mode.EmergencyRedeem);
        vault.emergency(60e18);
        assertEq(pricing.emergencyBudget(), 40e18);
        pricing.setMode(T.Mode.Paused); pricing.setMode(T.Mode.EmergencyRedeem);
        assertEq(pricing.emergencyBudget(), 40e18);
        vm.expectRevert(E.InvalidMode.selector); vault.emergency(60e18);
    }

    function test_ReferenceReplayCannotRefreshObservation() public {
        bytes memory data = abi.encodeWithSignature("mintQEURO(uint256,uint256)", 100e6, 0);
        T.Authorization memory a = _auth(data, 100e6, 100e18, 1);
        source.submit(a.referenceReport, a.referenceSignature);
        uint256 original = source.observedAt();
        vm.warp(block.timestamp + 10); source.submit(a.referenceReport, a.referenceSignature);
        assertEq(source.observedAt(), original);
        vm.warp(block.timestamp + 51);
        vm.expectRevert(E.InvalidTime.selector); source.submit(a.referenceReport, a.referenceSignature);
    }

    function test_YieldAuthorizationCapsActualConversion() public {
        bytes memory data = abi.encodeWithSignature("harvestAndDistributeVaultYield(uint256)", 60e6);
        T.Authorization memory a = _auth(data, 100e6, 100e18, 1);
        a.quote.action = T.Action.Yield; a.signature = _sign(pricing.quoteDigest(a.quote));
        vault.execute(data, abi.encode(a)); assertEq(vault.minted(), 60e18);
        data = abi.encodeWithSignature("harvestAndDistributeVaultYield(uint256)", 101e6);
        a = _auth(data, 100e6, 100e18, 2); a.quote.action = T.Action.Yield; a.signature = _sign(pricing.quoteDigest(a.quote));
        vm.expectRevert(E.InvalidAmount.selector); vault.execute(data, abi.encode(a));
    }

    function test_ZeroYieldStillEmitsSettlementEvidence() public {
        bytes memory data = abi.encodeWithSignature("harvestAndDistributeVaultYield(uint256)", 0);
        T.Authorization memory a = _auth(data, 100e6, 100e18, 1);
        a.quote.action = T.Action.Yield; a.signature = _sign(pricing.quoteDigest(a.quote));
        vm.recordLogs();
        vault.execute(data, abi.encode(a));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool found;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(pricing) && logs[i].topics[0] == keccak256("QuoteSettled(bytes32,address,uint8,uint256,uint256)")) {
                assertEq(logs[i].topics[1], pricing.quoteDigest(a.quote));
                (, uint256 input, uint256 output) = abi.decode(logs[i].data, (uint8, uint256, uint256));
                assertEq(input, 0); assertEq(output, 0); found = true;
            }
        }
        assertTrue(found); assertTrue(pricing.usedNonces(address(this), 1));
        assertEq(pricing.outstanding(), 0); assertFalse(pricing.active());
    }

    function test_QuotesMaySettleOutOfReportOrder() public {
        bytes memory data = abi.encodeWithSignature("mintQEURO(uint256,uint256)", 100e6, 0);
        T.Authorization memory older = _auth(data, 100e6, 100e18, 1);
        vm.warp(block.timestamp + 1);
        T.Authorization memory newer = _auth(data, 100e6, 100e18, 2);
        newer.referenceReport.sequence = 2;
        newer.referenceSignature = _sign(source.digest(newer.referenceReport));
        newer.quote.referenceHash = source.digest(newer.referenceReport);
        newer.signature = _sign(pricing.quoteDigest(newer.quote));
        newer.capacityReport.sequence = 2;
        newer.capacitySignature = _sign(pricing.capacityDigest(newer.capacityReport));
        vault.execute(data, abi.encode(newer));
        vault.execute(data, abi.encode(older));
        assertEq(vault.minted(), 200e18); assertEq(pricing.outstanding(), 200e18);
        assertEq(source.sequence(), 2); assertEq(source.observedAt(), block.timestamp);
        assertEq(pricing.capacitySequence(), 2); assertEq(pricing.capacityObservedAt(), block.timestamp);
    }

    function test_OlderQuoteUsesCurrentValuationForBacking() public {
        bytes memory data = abi.encodeWithSignature("mintQEURO(uint256,uint256)", 100e6, 0);
        T.Authorization memory older = _auth(data, 100e6, 99.9e18, 1);
        T.ReferenceReport memory report = T.ReferenceReport(1.001e18, block.timestamp, 2, source.epoch());
        source.submit(report, _sign(source.digest(report)));
        vault.execute(data, abi.encode(older));
        assertEq(vault.minted(), 99.9e18); assertEq(vault.backing(), 99_999_900);
        assertEq(source.price(), 1.001e18); assertEq(source.sequence(), 2);
    }

    function test_OlderQuoteStillCannotViolateCurrentBacking() public {
        bytes memory data = abi.encodeWithSignature("mintQEURO(uint256,uint256)", 100e6, 0);
        T.Authorization memory older = _auth(data, 100e6, 100e18, 1);
        T.ReferenceReport memory report = T.ReferenceReport(1.001e18, block.timestamp, 2, source.epoch());
        source.submit(report, _sign(source.digest(report)));
        vm.expectRevert(E.ExcessiveImpact.selector); vault.execute(data, abi.encode(older));
        assertFalse(pricing.usedNonces(address(this), 1)); assertEq(pricing.outstanding(), 0);
    }

    function test_OlderCapacityCannotRestoreHigherLimit() public {
        bytes memory data = abi.encodeWithSignature("mintQEURO(uint256,uint256)", 100e6, 0);
        T.Authorization memory older = _auth(data, 100e6, 100e18, 1);
        T.CapacityReport memory report = abi.decode(abi.encode(older.capacityReport), (T.CapacityReport));
        report.sequence = 2; report.capacity = 50e18;
        pricing.submitCapacity(report, _sign(pricing.capacityDigest(report)));
        vm.expectRevert(E.CapacityExceeded.selector); vault.execute(data, abi.encode(older));
        assertEq(pricing.marginCapacity(), 50e18); assertEq(pricing.capacitySequence(), 2);
        assertFalse(pricing.usedNonces(address(this), 1));
    }

    function test_OlderCapacityCannotEraseAcknowledgedHedge() public {
        bytes memory data = abi.encodeWithSignature("mintQEURO(uint256,uint256)", 100e6, 0);
        T.Authorization memory first = _auth(data, 100e6, 100e18, 1);
        T.Authorization memory second = _auth(data, 100e6, 100e18, 2);
        vault.execute(data, abi.encode(first));
        T.CapacityReport memory report = first.capacityReport;
        report.sequence = 2; report.acknowledgedBuy = 100e18;
        pricing.submitCapacity(report, _sign(pricing.capacityDigest(report)));
        vault.execute(data, abi.encode(second));
        assertEq(pricing.admittedBuy(), 200e18); assertEq(pricing.acknowledgedBuy(), 100e18);
        assertEq(pricing.outstanding(), 100e18);
    }

    function test_IgnoredReportsStillRequireValidSignersAndCanonicalBlock() public {
        bytes memory data = abi.encodeWithSignature("mintQEURO(uint256,uint256)", 100e6, 0);
        T.Authorization memory older = _auth(data, 100e6, 100e18, 1);
        T.ReferenceReport memory referenceReport = abi.decode(abi.encode(older.referenceReport), (T.ReferenceReport));
        referenceReport.sequence = 2; source.submit(referenceReport, _sign(source.digest(referenceReport)));
        source.revokeRole(source.REFERENCE_SIGNER_ROLE(), signer);
        vm.expectRevert(E.InvalidSignature.selector); source.submit(older.referenceReport, older.referenceSignature);
        T.CapacityReport memory capacityReport = abi.decode(abi.encode(older.capacityReport), (T.CapacityReport));
        capacityReport.sequence = 2; pricing.submitCapacity(capacityReport, _sign(pricing.capacityDigest(capacityReport)));
        vm.setBlockhash(99, keccak256("reorganized"));
        vm.expectRevert(E.InvalidReport.selector); pricing.submitCapacity(older.capacityReport, older.capacitySignature);
    }

    function test_ConflictingSameSequenceReportsAreRejected() public {
        bytes memory data = abi.encodeWithSignature("mintQEURO(uint256,uint256)", 100e6, 0);
        T.Authorization memory auth = _auth(data, 100e6, 100e18, 1);
        source.submit(auth.referenceReport, auth.referenceSignature);
        auth.referenceReport.price += 1;
        bytes memory referenceSignature = _sign(source.digest(auth.referenceReport));
        vm.expectRevert(E.InvalidReport.selector); source.submit(auth.referenceReport, referenceSignature);
        pricing.submitCapacity(auth.capacityReport, auth.capacitySignature);
        auth.capacityReport.capacity -= 1;
        bytes memory capacitySignature = _sign(pricing.capacityDigest(auth.capacityReport));
        vm.expectRevert(E.InvalidReport.selector); pricing.submitCapacity(auth.capacityReport, capacitySignature);
    }
}
