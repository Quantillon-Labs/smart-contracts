// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockAaveVault} from "../src/mocks/MockAaveVault.sol";

/**
 * @title MockUSDCSimple
 * @notice Minimal ERC-20 mock for MockAaveVault tests.
 */
contract MockUSDCSimple {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint8 public decimals = 6;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

/**
 * @title MockAaveVaultTest
 * @notice Unit tests for the simple MockAaveVault (localhost mock).
 * @dev Verifies deposit/withdraw share accounting, yield injection, and totalUnderlyingOf.
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract MockAaveVaultTest is Test {
    // =============================================================================
    // STATE
    // =============================================================================

    MockAaveVault public vault;
    MockUSDCSimple public usdc;

    address public depositor = address(0x1);
    address public recipient  = address(0x2);
    address public yieldSource = address(0x3);

    uint256 public constant DEPOSIT_AMOUNT = 1000e6; // 1000 USDC

    // =============================================================================
    // SETUP
    // =============================================================================

    function setUp() public {
        usdc  = new MockUSDCSimple();
        vault = new MockAaveVault(address(usdc));

        // Fund accounts
        usdc.mint(depositor,   10_000e6);
        usdc.mint(yieldSource, 10_000e6);

        // Approvals
        vm.prank(depositor);
        usdc.approve(address(vault), type(uint256).max);

        vm.prank(yieldSource);
        usdc.approve(address(vault), type(uint256).max);
    }

    // =============================================================================
    // DEPOSIT TESTS
    // =============================================================================

    /**
     * @notice First deposit mints shares 1:1 with assets.
     * @custom:security No security implications - unit test
     * @custom:validation Verifies first-deposit share ratio
     * @custom:state-changes Deposits USDC, mints shares
     * @custom:events Emits Deposited
     * @custom:errors No errors expected
     * @custom:reentrancy Not applicable
     * @custom:access No access restrictions
     * @custom:oracle No oracle dependency
     */
    function test_Deposit_FirstDeposit_SharesEqualAssets() public {
        vm.prank(depositor);
        uint256 shares = vault.depositUnderlying(DEPOSIT_AMOUNT, depositor);

        assertEq(shares, DEPOSIT_AMOUNT, "First deposit: shares should equal assets");
        assertEq(vault.shareBalanceOf(depositor), DEPOSIT_AMOUNT);
        assertEq(vault.totalShares(), DEPOSIT_AMOUNT);
        assertEq(vault.totalAssets(), DEPOSIT_AMOUNT);
    }

    /**
     * @notice Deposit of zero returns zero shares.
     * @custom:security No security implications - unit test
     * @custom:validation Verifies zero-amount guard
     * @custom:state-changes No state changes
     * @custom:events No events
     * @custom:errors No errors
     * @custom:reentrancy Not applicable
     * @custom:access No restrictions
     * @custom:oracle No dependency
     */
    function test_Deposit_ZeroAmount_ReturnsZero() public {
        vm.prank(depositor);
        uint256 shares = vault.depositUnderlying(0, depositor);
        assertEq(shares, 0);
        assertEq(vault.totalShares(), 0);
    }

    /**
     * @notice Deposit to zero address returns zero.
     * @custom:security No security implications - unit test
     * @custom:validation Verifies zero-address guard
     * @custom:state-changes No state changes
     * @custom:events No events
     * @custom:errors No errors
     * @custom:reentrancy Not applicable
     * @custom:access No restrictions
     * @custom:oracle No dependency
     */
    function test_Deposit_ZeroOnBehalfOf_ReturnsZero() public {
        vm.prank(depositor);
        uint256 shares = vault.depositUnderlying(DEPOSIT_AMOUNT, address(0));
        assertEq(shares, 0);
    }

    // =============================================================================
    // WITHDRAW TESTS
    // =============================================================================

    /**
     * @notice Withdraw returns same amount as deposited (no yield).
     * @custom:security No security implications - unit test
     * @custom:validation Verifies withdraw round-trip
     * @custom:state-changes Burns shares, transfers USDC
     * @custom:events Emits Withdrawn
     * @custom:errors No errors expected
     * @custom:reentrancy Not applicable
     * @custom:access No restrictions
     * @custom:oracle No dependency
     */
    function test_Withdraw_ExactAmount_ReturnsDeposited() public {
        vm.prank(depositor);
        vault.depositUnderlying(DEPOSIT_AMOUNT, depositor);

        uint256 balBefore = usdc.balanceOf(recipient);

        vm.prank(depositor);
        uint256 withdrawn = vault.withdrawUnderlying(DEPOSIT_AMOUNT, recipient);

        assertEq(withdrawn, DEPOSIT_AMOUNT);
        assertEq(usdc.balanceOf(recipient) - balBefore, DEPOSIT_AMOUNT);
        assertEq(vault.totalShares(), 0);
    }

    /**
     * @notice Withdraw caps at depositor's entitlement when requesting more.
     * @custom:security No security implications - unit test
     * @custom:validation Verifies over-withdrawal cap
     * @custom:state-changes Burns all shares, transfers capped USDC
     * @custom:events Emits Withdrawn
     * @custom:errors No errors
     * @custom:reentrancy Not applicable
     * @custom:access No restrictions
     * @custom:oracle No dependency
     */
    function test_Withdraw_MoreThanBalance_CapsAtEntitlement() public {
        vm.prank(depositor);
        vault.depositUnderlying(DEPOSIT_AMOUNT, depositor);

        vm.prank(depositor);
        uint256 withdrawn = vault.withdrawUnderlying(DEPOSIT_AMOUNT * 2, recipient);

        assertEq(withdrawn, DEPOSIT_AMOUNT, "Should cap withdrawal at depositor entitlement");
        assertEq(vault.totalShares(), 0);
    }

    // =============================================================================
    // YIELD INJECTION TESTS
    // =============================================================================

    /**
     * @notice Injecting yield increases totalAssets but not totalShares.
     * @custom:security No security implications - unit test
     * @custom:validation Verifies yield increases totalAssets
     * @custom:state-changes Transfers USDC into vault
     * @custom:events Emits YieldInjected
     * @custom:errors No errors
     * @custom:reentrancy Not applicable
     * @custom:access No restrictions
     * @custom:oracle No dependency
     */
    function test_InjectYield_IncreasesTotalAssets() public {
        vm.prank(depositor);
        vault.depositUnderlying(DEPOSIT_AMOUNT, depositor);

        uint256 yieldAmount = 100e6;
        vm.prank(yieldSource);
        vault.injectYield(yieldAmount);

        assertEq(vault.totalAssets(), DEPOSIT_AMOUNT + yieldAmount);
        assertEq(vault.totalShares(), DEPOSIT_AMOUNT, "Shares unchanged by yield");
    }

    /**
     * @notice totalUnderlyingOf reflects accrued yield proportionally.
     * @custom:security No security implications - unit test
     * @custom:validation Verifies yield accrual in account balance
     * @custom:state-changes None beyond setup
     * @custom:events No events
     * @custom:errors No errors
     * @custom:reentrancy Not applicable
     * @custom:access No restrictions
     * @custom:oracle No dependency
     */
    function test_TotalUnderlyingOf_ReflectsYield() public {
        vm.prank(depositor);
        vault.depositUnderlying(DEPOSIT_AMOUNT, depositor);

        uint256 yieldAmount = 100e6;
        vm.prank(yieldSource);
        vault.injectYield(yieldAmount);

        uint256 underlying = vault.totalUnderlyingOf(depositor);
        assertEq(underlying, DEPOSIT_AMOUNT + yieldAmount, "Underlying should include yield");
    }

    /**
     * @notice Withdraw after yield injection delivers principal + proportional yield.
     * @custom:security No security implications - unit test
     * @custom:validation Verifies full yield withdrawal
     * @custom:state-changes Burns shares, transfers USDC with yield
     * @custom:events Emits Withdrawn
     * @custom:errors No errors
     * @custom:reentrancy Not applicable
     * @custom:access No restrictions
     * @custom:oracle No dependency
     */
    function test_Withdraw_AfterYield_DeliversPrincipalPlusYield() public {
        vm.prank(depositor);
        vault.depositUnderlying(DEPOSIT_AMOUNT, depositor);

        uint256 yieldAmount = 100e6;
        vm.prank(yieldSource);
        vault.injectYield(yieldAmount);

        uint256 total = DEPOSIT_AMOUNT + yieldAmount;

        vm.prank(depositor);
        uint256 withdrawn = vault.withdrawUnderlying(total, recipient);

        assertEq(withdrawn, total, "Should withdraw principal + yield");
    }

    /**
     * @notice totalUnderlyingOf returns zero when vault has no shares.
     * @custom:security No security implications - unit test
     * @custom:validation Verifies zero-share guard
     * @custom:state-changes No state changes
     * @custom:events No events
     * @custom:errors No errors
     * @custom:reentrancy Not applicable
     * @custom:access No restrictions
     * @custom:oracle No dependency
     */
    function test_TotalUnderlyingOf_EmptyVault_ReturnsZero() public view {
        assertEq(vault.totalUnderlyingOf(depositor), 0);
    }
}
