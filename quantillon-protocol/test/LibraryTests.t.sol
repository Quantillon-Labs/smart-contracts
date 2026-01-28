// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {FlashLoanProtectionLibrary} from "../src/libraries/FlashLoanProtectionLibrary.sol";
import {TreasuryRecoveryLibrary} from "../src/libraries/TreasuryRecoveryLibrary.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title MockToken
 * @notice Mock ERC20 token for testing
 */
contract MockToken is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;

    function mint(address to, uint256 amount) external {
        _balances[to] += amount;
        _totalSupply += amount;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        _allowances[from][msg.sender] -= amount;
        _balances[from] -= amount;
        _balances[to] += amount;
        return true;
    }
}

/**
 * @title TreasuryRecoveryWrapper
 * @notice Wrapper contract to test TreasuryRecoveryLibrary
 */
contract TreasuryRecoveryWrapper {
    mapping(address => bool) public authorizedRecipients;

    receive() external payable {}

    function addAuthorizedRecipient(address recipient) external {
        authorizedRecipients[recipient] = true;
    }

    function removeAuthorizedRecipient(address recipient) external {
        authorizedRecipients[recipient] = false;
    }

    function recoverToken(address token, uint256 amount, address treasury) external {
        TreasuryRecoveryLibrary.recoverToken(token, amount, address(this), treasury);
    }

    function recoverETH(address treasury) external {
        TreasuryRecoveryLibrary.recoverETH(treasury);
    }

    function secureETHTransfer(address recipient, uint256 amount) external {
        TreasuryRecoveryLibrary.secureETHTransfer(recipient, amount, authorizedRecipients);
    }
}

/**
 * @title LibraryTests
 * @notice Comprehensive unit tests for protocol libraries
 *
 * @dev This test suite covers:
 *      - FlashLoanProtectionLibrary functions
 *      - TreasuryRecoveryLibrary functions
 *      - Edge cases and boundary conditions
 *      - Error conditions and reverts
 *
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract LibraryTests is Test {
    // =============================================================================
    // STATE VARIABLES
    // =============================================================================

    TreasuryRecoveryWrapper public wrapper;
    MockToken public mockToken;

    address public treasury = address(0x1);
    address public recipient = address(0x2);
    address public attacker = address(0x3);

    // =============================================================================
    // SETUP
    // =============================================================================

    function setUp() public {
        wrapper = new TreasuryRecoveryWrapper();
        mockToken = new MockToken();

        // Fund the wrapper with tokens and ETH
        mockToken.mint(address(wrapper), 1000 ether);
        vm.deal(address(wrapper), 10 ether);
    }

    // =============================================================================
    // FLASH LOAN PROTECTION LIBRARY TESTS
    // =============================================================================

    /**
     * @notice Test validateBalanceChange when balance increases
     */
    function test_FlashLoanProtection_BalanceIncrease() public pure {
        bool result = FlashLoanProtectionLibrary.validateBalanceChange(100, 150, 0);
        assertTrue(result, "Balance increase should always pass");
    }

    /**
     * @notice Test validateBalanceChange when balance stays the same
     */
    function test_FlashLoanProtection_BalanceSame() public pure {
        bool result = FlashLoanProtectionLibrary.validateBalanceChange(100, 100, 0);
        assertTrue(result, "Same balance should pass");
    }

    /**
     * @notice Test validateBalanceChange when balance decreases within limit
     */
    function test_FlashLoanProtection_BalanceDecrease_WithinLimit() public pure {
        bool result = FlashLoanProtectionLibrary.validateBalanceChange(100, 90, 10);
        assertTrue(result, "Decrease within limit should pass");
    }

    /**
     * @notice Test validateBalanceChange when balance decreases at exact limit
     */
    function test_FlashLoanProtection_BalanceDecrease_AtExactLimit() public pure {
        bool result = FlashLoanProtectionLibrary.validateBalanceChange(100, 90, 10);
        assertTrue(result, "Decrease at exact limit should pass");
    }

    /**
     * @notice Test validateBalanceChange when balance decreases beyond limit
     */
    function test_FlashLoanProtection_BalanceDecrease_BeyondLimit() public pure {
        bool result = FlashLoanProtectionLibrary.validateBalanceChange(100, 89, 10);
        assertFalse(result, "Decrease beyond limit should fail");
    }

    /**
     * @notice Test validateBalanceChange with zero max decrease (strict mode)
     */
    function test_FlashLoanProtection_StrictMode_NoDecrease() public pure {
        // Any decrease should fail
        bool result = FlashLoanProtectionLibrary.validateBalanceChange(100, 99, 0);
        assertFalse(result, "Any decrease should fail in strict mode");
    }

    /**
     * @notice Test validateBalanceChange with zero balances
     */
    function test_FlashLoanProtection_ZeroBalances() public pure {
        bool result = FlashLoanProtectionLibrary.validateBalanceChange(0, 0, 0);
        assertTrue(result, "Zero balances should pass");
    }

    /**
     * @notice Fuzz test validateBalanceChange
     */
    function testFuzz_FlashLoanProtection_ValidateBalanceChange(
        uint128 balanceBefore,
        uint128 balanceAfter,
        uint128 maxDecrease
    ) public pure {
        bool result = FlashLoanProtectionLibrary.validateBalanceChange(
            uint256(balanceBefore),
            uint256(balanceAfter),
            uint256(maxDecrease)
        );

        if (balanceAfter >= balanceBefore) {
            assertTrue(result, "Balance increase/same should always pass");
        } else {
            uint256 decrease = uint256(balanceBefore) - uint256(balanceAfter);
            if (decrease <= uint256(maxDecrease)) {
                assertTrue(result, "Decrease within limit should pass");
            } else {
                assertFalse(result, "Decrease beyond limit should fail");
            }
        }
    }

    // =============================================================================
    // TREASURY RECOVERY LIBRARY - RECOVER TOKEN TESTS
    // =============================================================================

    /**
     * @notice Test recoverToken success
     */
    function test_TreasuryRecovery_RecoverToken_Success() public {
        uint256 amount = 500 ether;
        uint256 treasuryBalanceBefore = mockToken.balanceOf(treasury);

        wrapper.recoverToken(address(mockToken), amount, treasury);

        assertEq(
            mockToken.balanceOf(treasury),
            treasuryBalanceBefore + amount,
            "Treasury should receive tokens"
        );
    }

    /**
     * @notice Test recoverToken reverts when recovering own token
     */
    function test_TreasuryRecovery_RecoverToken_RevertOwnToken() public {
        // Try to recover the wrapper contract's own address as token
        vm.expectRevert(CommonErrorLibrary.CannotRecoverOwnToken.selector);
        wrapper.recoverToken(address(wrapper), 100, treasury);
    }

    /**
     * @notice Test recoverToken reverts with zero treasury address
     */
    function test_TreasuryRecovery_RecoverToken_RevertZeroTreasury() public {
        vm.expectRevert(CommonErrorLibrary.InvalidAddress.selector);
        wrapper.recoverToken(address(mockToken), 100, address(0));
    }

    // =============================================================================
    // TREASURY RECOVERY LIBRARY - RECOVER ETH TESTS
    // =============================================================================

    /**
     * @notice Test recoverETH success
     */
    function test_TreasuryRecovery_RecoverETH_Success() public {
        uint256 wrapperBalance = address(wrapper).balance;
        uint256 treasuryBalanceBefore = treasury.balance;

        wrapper.recoverETH(treasury);

        assertEq(
            treasury.balance,
            treasuryBalanceBefore + wrapperBalance,
            "Treasury should receive ETH"
        );
    }

    /**
     * @notice Test recoverETH reverts with zero treasury address
     */
    function test_TreasuryRecovery_RecoverETH_RevertZeroTreasury() public {
        vm.expectRevert(CommonErrorLibrary.InvalidAddress.selector);
        wrapper.recoverETH(address(0));
    }

    /**
     * @notice Test recoverETH reverts when no ETH to recover
     */
    function test_TreasuryRecovery_RecoverETH_RevertNoETH() public {
        // First recover all ETH
        wrapper.recoverETH(treasury);

        // Try to recover again
        vm.expectRevert(CommonErrorLibrary.NoETHToRecover.selector);
        wrapper.recoverETH(treasury);
    }

    // =============================================================================
    // TREASURY RECOVERY LIBRARY - SECURE ETH TRANSFER TESTS
    // =============================================================================

    /**
     * @notice Test secureETHTransfer success with authorized recipient
     */
    function test_TreasuryRecovery_SecureETHTransfer_Success() public {
        // Add recipient to whitelist
        wrapper.addAuthorizedRecipient(recipient);

        uint256 amount = 1 ether;
        uint256 recipientBalanceBefore = recipient.balance;

        wrapper.secureETHTransfer(recipient, amount);

        assertEq(
            recipient.balance,
            recipientBalanceBefore + amount,
            "Recipient should receive ETH"
        );
    }

    /**
     * @notice Test secureETHTransfer reverts with unauthorized recipient
     */
    function test_TreasuryRecovery_SecureETHTransfer_RevertUnauthorized() public {
        vm.expectRevert(CommonErrorLibrary.InvalidAddress.selector);
        wrapper.secureETHTransfer(attacker, 1 ether);
    }

    /**
     * @notice Test secureETHTransfer reverts with zero amount
     */
    function test_TreasuryRecovery_SecureETHTransfer_RevertZeroAmount() public {
        wrapper.addAuthorizedRecipient(recipient);

        vm.expectRevert(CommonErrorLibrary.InvalidAmount.selector);
        wrapper.secureETHTransfer(recipient, 0);
    }

    /**
     * @notice Test secureETHTransfer reverts with zero address
     */
    function test_TreasuryRecovery_SecureETHTransfer_RevertZeroAddress() public {
        // Even if somehow zero address was in whitelist, it should fail
        wrapper.addAuthorizedRecipient(address(0));

        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        wrapper.secureETHTransfer(address(0), 1 ether);
    }

    /**
     * @notice Test secureETHTransfer reverts with contract recipient
     */
    function test_TreasuryRecovery_SecureETHTransfer_RevertContractRecipient() public {
        // Add wrapper itself (a contract) to whitelist
        wrapper.addAuthorizedRecipient(address(wrapper));

        // Should fail because recipient is a contract
        vm.expectRevert(CommonErrorLibrary.InvalidAddress.selector);
        wrapper.secureETHTransfer(address(wrapper), 1 ether);
    }

    /**
     * @notice Test secureETHTransfer after removing from whitelist
     */
    function test_TreasuryRecovery_SecureETHTransfer_AfterRemoval() public {
        // Add then remove from whitelist
        wrapper.addAuthorizedRecipient(recipient);
        wrapper.removeAuthorizedRecipient(recipient);

        vm.expectRevert(CommonErrorLibrary.InvalidAddress.selector);
        wrapper.secureETHTransfer(recipient, 1 ether);
    }

    // =============================================================================
    // INTEGRATION TESTS
    // =============================================================================

    /**
     * @notice Test full recovery flow
     */
    function test_Integration_FullRecoveryFlow() public {
        // Initial state
        uint256 initialWrapperTokens = mockToken.balanceOf(address(wrapper));
        uint256 initialWrapperETH = address(wrapper).balance;

        // Recover tokens
        wrapper.recoverToken(address(mockToken), initialWrapperTokens / 2, treasury);
        assertEq(
            mockToken.balanceOf(treasury),
            initialWrapperTokens / 2,
            "Half tokens should be in treasury"
        );

        // Recover remaining tokens
        wrapper.recoverToken(
            address(mockToken),
            mockToken.balanceOf(address(wrapper)),
            treasury
        );
        assertEq(
            mockToken.balanceOf(treasury),
            initialWrapperTokens,
            "All tokens should be in treasury"
        );

        // Recover ETH
        wrapper.recoverETH(treasury);
        assertEq(treasury.balance, initialWrapperETH, "All ETH should be in treasury");
    }

    /**
     * @notice Test whitelist management
     */
    function test_Integration_WhitelistManagement() public {
        address[] memory recipients = new address[](3);
        recipients[0] = address(0x10);
        recipients[1] = address(0x11);
        recipients[2] = address(0x12);

        // Add all to whitelist
        for (uint256 i = 0; i < recipients.length; i++) {
            wrapper.addAuthorizedRecipient(recipients[i]);
        }

        // Verify all can receive
        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 balanceBefore = recipients[i].balance;
            wrapper.secureETHTransfer(recipients[i], 0.1 ether);
            assertEq(
                recipients[i].balance,
                balanceBefore + 0.1 ether,
                "Recipient should receive ETH"
            );
        }

        // Remove one from whitelist
        wrapper.removeAuthorizedRecipient(recipients[1]);

        // Verify removed recipient cannot receive
        vm.expectRevert(CommonErrorLibrary.InvalidAddress.selector);
        wrapper.secureETHTransfer(recipients[1], 0.1 ether);

        // Verify others can still receive
        wrapper.secureETHTransfer(recipients[0], 0.1 ether);
        wrapper.secureETHTransfer(recipients[2], 0.1 ether);
    }
}
