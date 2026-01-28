// /test/TreasuryRecoveryLibrary.t.sol
// Unit tests for TreasuryRecoveryLibrary token and ETH recovery helpers.
// This file exists to validate recovery and secure transfer logic in isolation.

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {TreasuryRecoveryLibrary} from "../src/libraries/TreasuryRecoveryLibrary.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

contract TreasuryRecoveryHarness {
    using TreasuryRecoveryLibrary for *;

    mapping(address => bool) public authorizedRecipients;

    function addAuthorized(address recipient) external {
        authorizedRecipients[recipient] = true;
    }

    function callRecoverToken(
        address token,
        uint256 amount,
        address treasury
    ) external {
        TreasuryRecoveryLibrary.recoverToken(token, amount, address(this), treasury);
    }

    function callRecoverETH(address treasury) external {
        TreasuryRecoveryLibrary.recoverETH(treasury);
    }

    function callSecureETH(address recipient, uint256 amount) external {
        TreasuryRecoveryLibrary.secureETHTransfer(recipient, amount, authorizedRecipients);
    }

    receive() external payable {}
}

contract TreasuryRecoveryLibraryTest is Test {
    TreasuryRecoveryHarness private harness;
    MockUSDC private token;
    address private treasury = address(0xA1);
    address private user = address(0xB2);

    function setUp() public {
        harness = new TreasuryRecoveryHarness();
        token = new MockUSDC();

        // Fund harness with some tokens and ETH
        vm.startPrank(token.owner());
        token.transfer(address(harness), 1_000e6);
        vm.stopPrank();

        vm.deal(address(harness), 10 ether);
    }

    // ----------------- recoverToken -----------------

    function test_RecoverToken_SendsToTreasury() public {
        uint256 amount = 100e6;
        uint256 beforeTreasury = token.balanceOf(treasury);

        vm.prank(user);
        harness.callRecoverToken(address(token), amount, treasury);

        assertEq(token.balanceOf(treasury), beforeTreasury + amount, "Treasury should receive tokens");
    }

    function test_RecoverToken_RevertWhenOwnToken() public {
        vm.prank(user);
        vm.expectRevert(CommonErrorLibrary.CannotRecoverOwnToken.selector);
        harness.callRecoverToken(address(harness), 1, treasury);
    }

    function test_RecoverToken_RevertWhenTreasuryZero() public {
        vm.prank(user);
        vm.expectRevert(CommonErrorLibrary.InvalidAddress.selector);
        harness.callRecoverToken(address(token), 1, address(0));
    }

    // ----------------- recoverETH -----------------

    function test_RecoverETH_SendsAllBalanceToTreasury() public {
        uint256 beforeTreasury = treasury.balance;

        vm.prank(user);
        harness.callRecoverETH(treasury);

        assertEq(treasury.balance, beforeTreasury + 10 ether, "Treasury should receive all ETH");
        assertEq(address(harness).balance, 0, "Harness should be drained");
    }

    function test_RecoverETH_RevertWhenTreasuryZero() public {
        vm.prank(user);
        vm.expectRevert(CommonErrorLibrary.InvalidAddress.selector);
        harness.callRecoverETH(address(0));
    }

    function test_RecoverETH_RevertWhenNoBalance() public {
        // Drain harness first
        vm.prank(user);
        harness.callRecoverETH(treasury);

        vm.prank(user);
        vm.expectRevert(CommonErrorLibrary.NoETHToRecover.selector);
        harness.callRecoverETH(treasury);
    }

    // ----------------- secureETHTransfer -----------------

    function test_SecureETHTransfer_SendsToWhitelistedEOA() public {
        address recipient = address(0xC3);
        vm.deal(address(harness), address(harness).balance + 1 ether);

        vm.prank(user);
        harness.addAuthorized(recipient);

        uint256 before = recipient.balance;

        vm.prank(user);
        harness.callSecureETH(recipient, 1 ether);

        assertEq(recipient.balance, before + 1 ether, "Recipient should receive ETH");
    }

    function test_SecureETHTransfer_RevertWhenAmountZero() public {
        address recipient = address(0xC4);
        vm.prank(user);
        harness.addAuthorized(recipient);

        vm.prank(user);
        vm.expectRevert(CommonErrorLibrary.InvalidAmount.selector);
        harness.callSecureETH(recipient, 0);
    }

    function test_SecureETHTransfer_RevertWhenNotAuthorized() public {
        address recipient = address(0xC5);

        vm.prank(user);
        vm.expectRevert(CommonErrorLibrary.InvalidAddress.selector);
        harness.callSecureETH(recipient, 1 ether);
    }

    function test_SecureETHTransfer_RevertWhenZeroAddress() public {
        // Library checks authorization before zero-address, so the effective error is InvalidAddress.
        vm.prank(user);
        vm.expectRevert(CommonErrorLibrary.InvalidAddress.selector);
        harness.callSecureETH(address(0), 1 ether);
    }

    function test_SecureETHTransfer_RevertWhenRecipientIsContract() public {
        address recipient = address(harness);
        vm.prank(user);
        harness.addAuthorized(recipient);

        vm.prank(user);
        vm.expectRevert(CommonErrorLibrary.InvalidAddress.selector);
        harness.callSecureETH(recipient, 1 ether);
    }
}

