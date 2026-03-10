// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {TreasuryRecoveryLibrary} from "../src/libraries/TreasuryRecoveryLibrary.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

contract TreasuryRecoveryHarness {
    function callRecoverToken(
        address token,
        uint256 amount,
        address treasury
    ) external {
        TreasuryRecoveryLibrary.recoverToken(token, amount, address(this), treasury);
    }
}

contract TreasuryRecoveryLibraryTest is Test {
    TreasuryRecoveryHarness private harness;
    MockUSDC private token;
    address private treasury = address(0xA1);
    address private user = address(0xB2);

    function setUp() public {
        harness = new TreasuryRecoveryHarness();
        token = new MockUSDC();

        vm.startPrank(token.owner());
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(address(harness), 1_000e6);
        vm.stopPrank();
    }

    function test_RecoverToken_SendsToTreasury() public {
        uint256 amount = 100e6;
        uint256 beforeTreasury = token.balanceOf(treasury);

        vm.prank(user);
        harness.callRecoverToken(address(token), amount, treasury);

        assertEq(token.balanceOf(treasury), beforeTreasury + amount);
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
}
