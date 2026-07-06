// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MorphoStakingVaultAdapter} from "../src/core/vaults/MorphoStakingVaultAdapter.sol";
import {MockMorphoVault} from "../src/mocks/MockMorphoVault.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";

/**
 * @title MorphoStakingVaultAdapterTest
 * @notice Full-branch coverage for the Morpho adapter (was 0% — audit SC1-6 test-gap).
 * @dev Exercises the deposit / withdraw / harvest / setVault paths, every revert branch,
 *      the withdraw principal cap, and access control on each role-gated entrypoint.
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract MockUSDCForMorphoAdapter is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}
    function decimals() public pure override returns (uint8) { return 6; }
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

contract MorphoStakingVaultAdapterTest is Test {
    MorphoStakingVaultAdapter public adapter;
    MockMorphoVault public morphoVault;
    MockUSDCForMorphoAdapter public usdc;

    address public admin = address(0x1);       // holds DEFAULT_ADMIN + GOVERNANCE + VAULT_MANAGER
    address public yieldSource = address(0x3);
    address public other = address(0x9);        // no roles

    uint256 public constant DEPOSIT_AMT = 1_000e6;
    uint256 public constant YIELD_AMT = 100e6;

    event MorphoVaultUpdated(address indexed oldVault, address indexed newVault);

    function setUp() public {
        usdc = new MockUSDCForMorphoAdapter();
        morphoVault = new MockMorphoVault(address(usdc));
        adapter = new MorphoStakingVaultAdapter(admin, address(usdc), address(morphoVault));

        usdc.mint(admin, 10_000e6);
        usdc.mint(yieldSource, 10_000e6);

        vm.prank(admin);
        usdc.approve(address(adapter), type(uint256).max);
        vm.prank(yieldSource);
        usdc.approve(address(morphoVault), type(uint256).max);
    }

    // ── constructor ─────────────────────────────────────────────────────────
    function test_Constructor_Success_GrantsRolesAndSetsDeps() public view {
        assertTrue(adapter.hasRole(adapter.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(adapter.hasRole(adapter.GOVERNANCE_ROLE(), admin));
        assertTrue(adapter.hasRole(adapter.VAULT_MANAGER_ROLE(), admin));
        assertEq(address(adapter.USDC()), address(usdc));
        assertEq(address(adapter.morphoVault()), address(morphoVault));
    }

    function test_Constructor_ZeroAdmin_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        new MorphoStakingVaultAdapter(address(0), address(usdc), address(morphoVault));
    }

    function test_Constructor_ZeroUsdc_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        new MorphoStakingVaultAdapter(admin, address(0), address(morphoVault));
    }

    function test_Constructor_ZeroMorphoVault_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        new MorphoStakingVaultAdapter(admin, address(usdc), address(0));
    }

    // ── depositUnderlying ───────────────────────────────────────────────────
    function test_DepositUnderlying_Success() public {
        vm.prank(admin);
        uint256 shares = adapter.depositUnderlying(DEPOSIT_AMT);
        assertGt(shares, 0, "should receive shares");
        assertEq(adapter.principalDeposited(), DEPOSIT_AMT);
        assertEq(adapter.totalUnderlying(), DEPOSIT_AMT);
    }

    function test_DepositUnderlying_ZeroAmount_Reverts() public {
        vm.prank(admin);
        vm.expectRevert(CommonErrorLibrary.InvalidAmount.selector);
        adapter.depositUnderlying(0);
    }

    function test_DepositUnderlying_Unauthorized_Reverts() public {
        vm.prank(other);
        vm.expectRevert();
        adapter.depositUnderlying(DEPOSIT_AMT);
    }

    // ── withdrawUnderlying ──────────────────────────────────────────────────
    function test_WithdrawUnderlying_Success() public {
        vm.prank(admin);
        adapter.depositUnderlying(DEPOSIT_AMT);
        uint256 balBefore = usdc.balanceOf(admin);

        vm.prank(admin);
        uint256 withdrawn = adapter.withdrawUnderlying(DEPOSIT_AMT);

        assertEq(withdrawn, DEPOSIT_AMT);
        assertEq(usdc.balanceOf(admin) - balBefore, DEPOSIT_AMT);
        assertEq(adapter.principalDeposited(), 0);
    }

    function test_WithdrawUnderlying_CapsToPrincipal() public {
        vm.prank(admin);
        adapter.depositUnderlying(DEPOSIT_AMT);

        // Request more than principal -> only principal is withdrawn, tracker hits zero.
        vm.prank(admin);
        uint256 withdrawn = adapter.withdrawUnderlying(DEPOSIT_AMT * 5);

        assertEq(withdrawn, DEPOSIT_AMT, "capped to tracked principal");
        assertEq(adapter.principalDeposited(), 0);
    }

    function test_WithdrawUnderlying_ZeroAmount_Reverts() public {
        vm.prank(admin);
        adapter.depositUnderlying(DEPOSIT_AMT);
        vm.prank(admin);
        vm.expectRevert(CommonErrorLibrary.InvalidAmount.selector);
        adapter.withdrawUnderlying(0);
    }

    function test_WithdrawUnderlying_NoPrincipal_Reverts() public {
        vm.prank(admin);
        vm.expectRevert(CommonErrorLibrary.InsufficientBalance.selector);
        adapter.withdrawUnderlying(DEPOSIT_AMT);
    }

    function test_WithdrawUnderlying_Unauthorized_Reverts() public {
        vm.prank(admin);
        adapter.depositUnderlying(DEPOSIT_AMT);
        vm.prank(other);
        vm.expectRevert();
        adapter.withdrawUnderlying(DEPOSIT_AMT);
    }

    // ── harvestYieldToVault ─────────────────────────────────────────────────
    function test_HarvestYieldToVault_TransfersYieldToCaller_PrincipalUnchanged() public {
        vm.prank(admin);
        adapter.depositUnderlying(DEPOSIT_AMT);

        vm.prank(yieldSource);
        morphoVault.injectYield(YIELD_AMT);

        uint256 balBefore = usdc.balanceOf(admin);
        vm.prank(admin);
        uint256 harvested = adapter.harvestYieldToVault();

        assertEq(harvested, YIELD_AMT, "harvest equals injected yield");
        assertEq(adapter.principalDeposited(), DEPOSIT_AMT, "principal untouched");
        assertEq(usdc.balanceOf(admin) - balBefore, YIELD_AMT, "caller receives yield");
        assertApproxEqAbs(adapter.totalUnderlying(), DEPOSIT_AMT, 1, "position back to principal");
    }

    function test_HarvestYieldToVault_NoYield_ReturnsZero() public {
        vm.prank(admin);
        adapter.depositUnderlying(DEPOSIT_AMT);
        vm.prank(admin);
        assertEq(adapter.harvestYieldToVault(), 0);
    }

    function test_HarvestYieldToVault_Unauthorized_Reverts() public {
        vm.prank(other);
        vm.expectRevert();
        adapter.harvestYieldToVault();
    }

    // ── totalUnderlying ─────────────────────────────────────────────────────
    function test_TotalUnderlying_TracksDeposit() public {
        assertEq(adapter.totalUnderlying(), 0);
        vm.prank(admin);
        adapter.depositUnderlying(DEPOSIT_AMT);
        assertEq(adapter.totalUnderlying(), DEPOSIT_AMT);
    }

    // ── setMorphoVault ──────────────────────────────────────────────────────
    function test_SetMorphoVault_Success_EmitsAndUpdates() public {
        MockMorphoVault newVault = new MockMorphoVault(address(usdc));
        vm.expectEmit(true, true, false, false);
        emit MorphoVaultUpdated(address(morphoVault), address(newVault));
        vm.prank(admin);
        adapter.setMorphoVault(address(newVault));
        assertEq(address(adapter.morphoVault()), address(newVault));
    }

    function test_SetMorphoVault_ZeroAddress_Reverts() public {
        vm.prank(admin);
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        adapter.setMorphoVault(address(0));
    }

    function test_SetMorphoVault_Unauthorized_Reverts() public {
        vm.prank(other);
        vm.expectRevert();
        adapter.setMorphoVault(address(morphoVault));
    }
}
