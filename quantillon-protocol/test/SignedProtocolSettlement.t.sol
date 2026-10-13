// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {QuantillonVaultMintCollateralizationAndLiquidationThresholdTest} from "./QuantillonVault_MintCollateralizationAndLiquidationThreshold.t.sol";
import {UserPool} from "../src/core/UserPool.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {SignedExecutionPricing} from "../src/oracle/SignedExecutionPricing.sol";
import {SignedReferenceSource} from "../src/oracle/SignedReferenceSource.sol";
import {SignedQuoteTypes as T} from "../src/libraries/SignedQuoteTypes.sol";
import {SignedQuoteErrors as E} from "../src/libraries/SignedQuoteErrors.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SettlementFeeSink {
    function collectFees(address token, uint256 amount, string calldata) external {
        require(IERC20(token).transferFrom(msg.sender, address(this), amount));
    }
}

/// @notice Real token and proxy settlement tests; only external market data and hedge accounting use fixtures.
contract SignedProtocolSettlementTest is QuantillonVaultMintCollateralizationAndLiquidationThresholdTest {
    uint256 private constant KEY = 0x12345;
    SignedReferenceSource private source;
    SignedExecutionPricing private pricing;
    UserPool private pool;

    function peekEurUsdPrice() external view returns (uint256, uint256, bool) {
        return (1e18, block.timestamp, true);
    }

    function _activate() private {
        vm.warp(1_000_000);
        vm.roll(100);
        vm.setBlockhash(99, keccak256("canonical"));
        _seedHedgerMargin(1000e6);
        source = new SignedReferenceSource(address(this), address(this), 60, 8100, 200, 300);
        pricing = new SignedExecutionPricing(address(this), address(vault), address(source), admin, 25, 1000e18, 60, 25);
        address signer = vm.addr(KEY);
        source.grantRole(source.REFERENCE_SIGNER_ROLE(), signer);
        source.grantRole(source.EMERGENCY_CONTROLLER_ROLE(), address(pricing));
        pricing.grantRole(pricing.QUOTE_SIGNER_ROLE(), signer);
        pricing.grantRole(pricing.CAPACITY_SIGNER_ROLE(), signer);
        pricing.setMode(T.Mode.Signed);
        vm.startPrank(admin);
        vault.pause();
        vault.configureExecutionPricing(address(pricing));
        vault.updateParameters(0, 0);
        vault.unpause();
        vm.stopPrank();
    }

    function _pool() private {
        TimeProvider implementation = new TimeProvider();
        TimeProvider time = TimeProvider(address(new ERC1967Proxy(address(implementation),
            abi.encodeCall(TimeProvider.initialize, (admin, admin, admin)))));
        UserPool poolImplementation = new UserPool(time);
        pool = UserPool(address(new ERC1967Proxy(address(poolImplementation), abi.encodeCall(UserPool.initialize,
            (admin, address(qeuro), address(usdc), address(vault), address(oracle), address(0), admin, admin)))));
        vm.prank(admin);
        vault.updateUserPool(address(pool));
    }

    function _sign(bytes32 digest) private view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    function _authorization(address caller, T.Action action, bytes memory data, uint256 input, uint256 output, uint256 nonce)
        private view returns (bytes memory)
    {
        T.Authorization memory a;
        a.referenceReport = T.ReferenceReport(1e18, block.timestamp, 1, source.epoch());
        a.referenceSignature = _sign(source.digest(a.referenceReport));
        a.capacityReport = T.CapacityReport(0, 0, 1000e18, block.timestamp, 1, pricing.epoch(), 99, keccak256("canonical"));
        a.capacitySignature = _sign(pricing.capacityDigest(a.capacityReport));
        a.quote = T.Quote(bootstrapUser, caller, action, input, output, block.timestamp, block.timestamp,
            block.timestamp + 20, nonce, pricing.epoch(), keccak256(data), source.digest(a.referenceReport));
        a.signature = _sign(pricing.quoteDigest(a.quote));
        return abi.encode(a);
    }

    function test_SignedProxyMintAndRedeemPreserveBalances() public {
        _activate();
        bytes memory data = abi.encodeWithSignature("mintQEURO(uint256,uint256)", 100e6, 100e18);
        bytes memory auth = _authorization(bootstrapUser, T.Action.Mint, data, 100e6, 100e18, 1);
        uint256 initial = usdc.balanceOf(bootstrapUser);
        vm.startPrank(bootstrapUser);
        usdc.approve(address(vault), 100e6);
        vault.executeWithQuote(data, auth);
        vm.stopPrank();
        assertEq(qeuro.balanceOf(bootstrapUser), 100e18);
        assertEq(vault.totalMinted(), 100e18);
        assertEq(vault.totalUsdcHeld(), 1100e6);
        assertTrue(pricing.usedNonces(bootstrapUser, 1));
        data = abi.encodeWithSignature("redeemQEURO(uint256,uint256)", 100e18, 100e6);
        auth = _authorization(bootstrapUser, T.Action.Redeem, data, 100e18, 100e6, 2);
        vm.prank(bootstrapUser);
        vault.executeWithQuote(data, auth);
        assertEq(usdc.balanceOf(bootstrapUser), initial);
        assertEq(qeuro.totalSupply(), 0);
        assertEq(vault.totalMinted(), 0);
        assertEq(vault.totalUsdcHeld(), 1000e6);
        assertEq(pricing.outstanding(), 200e18, "unacknowledged buys and sells do not cancel risk admission");
        assertFalse(pricing.active());
    }

    function test_SignedPoolRoundTripTracksOriginalUser() public {
        _activate(); _pool();
        uint256[] memory input = new uint256[](1);
        uint256[] memory output = new uint256[](1);
        input[0] = 100e6; output[0] = 100e18;
        bytes memory data = abi.encodeCall(UserPool.deposit, (input, output));
        bytes memory auth = _authorization(address(pool), T.Action.Mint, data, input[0], output[0], 1);
        uint256 initial = usdc.balanceOf(bootstrapUser);
        vm.startPrank(bootstrapUser);
        usdc.approve(address(pool), input[0]);
        uint256[] memory minted = abi.decode(pool.executeWithQuote(data, auth), (uint256[]));
        vm.stopPrank();
        assertEq(minted[0], 100e18);
        assertEq(pool.totalUserDeposits(), 100e6);
        assertEq(qeuro.balanceOf(bootstrapUser), 100e18);
        assertEq(qeuro.balanceOf(address(pool)), 0);
        assertTrue(pricing.usedNonces(bootstrapUser, 1));
        assertFalse(pricing.usedNonces(address(pool), 1));
        data = abi.encodeCall(UserPool.withdraw, (output, input));
        auth = _authorization(address(pool), T.Action.Redeem, data, output[0], input[0], 2);
        vm.startPrank(bootstrapUser);
        qeuro.approve(address(pool), output[0]);
        uint256[] memory redeemed = abi.decode(pool.executeWithQuote(data, auth), (uint256[]));
        vm.stopPrank();
        assertEq(redeemed[0], 100e6);
        assertEq(usdc.balanceOf(bootstrapUser), initial);
        assertEq(pool.totalUserWithdrawals(), 100e18);
        assertEq(pool.totalPendingUsdcWithdrawals(), 0);
        assertFalse(pricing.active());
    }

    function test_SignedFailureRollsBackPoolTrackingAndTokenTransfers() public {
        _activate(); _pool();
        uint256[] memory input = new uint256[](1);
        uint256[] memory output = new uint256[](1);
        input[0] = 100e6; output[0] = 101e18;
        bytes memory data = abi.encodeCall(UserPool.deposit, (input, output));
        bytes memory auth = _authorization(address(pool), T.Action.Mint, data, input[0], 100e18, 1);
        uint256 initial = usdc.balanceOf(bootstrapUser);
        vm.startPrank(bootstrapUser);
        usdc.approve(address(pool), input[0]);
        vm.expectRevert();
        pool.executeWithQuote(data, auth);
        vm.stopPrank();
        assertEq(usdc.balanceOf(bootstrapUser), initial);
        assertEq(pool.totalUserDeposits(), 0);
        assertEq(qeuro.totalSupply(), 0);
        assertEq(source.sequence(), 0);
        assertFalse(pricing.usedNonces(bootstrapUser, 1));
        assertFalse(pricing.active());
    }

    function test_SignedProxyRetainsFeesAndExecutionSpread() public {
        _activate();
        SettlementFeeSink sink = new SettlementFeeSink();
        vm.startPrank(admin);
        vault.updateParameters(1e15, 0);
        vault.updateHedgerRewardFeeSplit(0);
        vault.updateFeeCollector(address(sink));
        vm.stopPrank();
        bytes memory data = abi.encodeWithSignature("mintQEURO(uint256,uint256)", 100e6, 99.8e18);
        bytes memory auth = _authorization(bootstrapUser, T.Action.Mint, data, 100e6, 99.8e18, 1);
        vm.startPrank(bootstrapUser);
        usdc.approve(address(vault), 100e6);
        vault.executeWithQuote(data, auth);
        vm.stopPrank();
        assertEq(qeuro.balanceOf(bootstrapUser), 99.8e18);
        assertEq(vault.totalUsdcHeld(), 1099.8e6);
        assertEq(usdc.balanceOf(address(sink)), 0.1e6, "fee remains separate from spread and backing");
        assertEq(usdc.balanceOf(address(pricing)), 0.1e6, "spread remains outside backing");
        assertEq(pricing.outstanding(), 99.8e18);
    }

    function test_SignedActivationClosesUnquotedVaultAndPoolEntry() public {
        _activate(); _pool();
        vm.startPrank(bootstrapUser);
        usdc.approve(address(vault), 100e6);
        usdc.approve(address(pool), 100e6);
        vm.expectRevert(E.QuoteRequired.selector);
        vault.mintQEURO(100e6, 0);
        uint256[] memory amounts = new uint256[](1); amounts[0] = 100e6;
        uint256[] memory minimums = new uint256[](1);
        vm.expectRevert(E.QuoteRequired.selector);
        pool.deposit(amounts, minimums);
        vm.stopPrank();
        assertEq(pool.totalUserDeposits(), 0);
    }
    function test_PauseResumeDoesNotConsumeQuoteOrTransferFunds() public {
        _activate();
        bytes memory data = abi.encodeWithSignature("mintQEURO(uint256,uint256)", 100e6, 100e18);
        bytes memory auth = _authorization(bootstrapUser, T.Action.Mint, data, 100e6, 100e18, 41);
        uint256 balance = usdc.balanceOf(bootstrapUser);
        vm.prank(bootstrapUser); usdc.approve(address(vault), 100e6);
        vm.prank(admin); vault.pause();
        vm.prank(bootstrapUser); vm.expectRevert(); vault.executeWithQuote(data, auth);
        assertEq(usdc.balanceOf(bootstrapUser), balance);
        assertEq(source.sequence(), 0);
        assertEq(pricing.outstanding(), 0);
        assertFalse(pricing.usedNonces(bootstrapUser, 41));
        vm.prank(admin); vault.unpause();
        vm.prank(bootstrapUser); vault.executeWithQuote(data, auth);
        assertTrue(pricing.usedNonces(bootstrapUser, 41));
        vm.prank(bootstrapUser); vm.expectRevert(); vault.executeWithQuote(data, auth);
        assertEq(qeuro.balanceOf(bootstrapUser), 100e18);
    }

    function test_ConcurrentQuotesCannotReuseUnacknowledgedCapacity() public {
        _activate();
        bytes memory first = abi.encodeWithSignature("mintQEURO(uint256,uint256)", 900e6, 900e18);
        bytes memory second = abi.encodeWithSignature("mintQEURO(uint256,uint256)", 200e6, 200e18);
        bytes memory auth1 = _authorization(bootstrapUser, T.Action.Mint, first, 900e6, 900e18, 51);
        bytes memory auth2 = _authorization(bootstrapUser, T.Action.Mint, second, 200e6, 200e18, 52);
        vm.startPrank(bootstrapUser);
        usdc.approve(address(vault), 1100e6);
        vault.executeWithQuote(first, auth1);
        vm.expectRevert(); vault.executeWithQuote(second, auth2);
        vm.stopPrank();
        assertEq(pricing.outstanding(), 900e18);
        assertEq(qeuro.balanceOf(bootstrapUser), 900e18);
        assertFalse(pricing.usedNonces(bootstrapUser, 52));
    }

    function test_EmergencyRedemptionAfterSignerOutageIsBudgetedAndAtomic() public {
        _activate();
        vm.prank(admin); vault.pause();
        pricing.configureEmergencyBudget(100e18);
        vm.prank(admin); vault.unpause();
        bytes memory data = abi.encodeWithSignature("mintQEURO(uint256,uint256)", 100e6, 100e18);
        bytes memory auth = _authorization(bootstrapUser, T.Action.Mint, data, 100e6, 100e18, 61);
        vm.startPrank(bootstrapUser);
        usdc.approve(address(vault), 100e6);
        vault.executeWithQuote(data, auth);
        vm.stopPrank();
        pricing.setMode(T.Mode.EmergencyRedeem);
        // No signer call, fresh quote, or periodic publisher is needed here.
        vm.prank(bootstrapUser); vm.expectRevert(); vault.emergencyRedeemQEURO(100e18, 101e6);
        assertEq(pricing.emergencyBudget(), 100e18);
        assertEq(qeuro.balanceOf(bootstrapUser), 100e18);
        vm.prank(bootstrapUser); vault.emergencyRedeemQEURO(100e18, 0);
        assertEq(pricing.emergencyBudget(), 0);
        assertEq(qeuro.balanceOf(bootstrapUser), 0);
        assertEq(vault.totalMinted(), 0);
        assertFalse(pricing.active());
    }

}
