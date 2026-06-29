// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {MetaMorphoStakingVaultAdapter} from "../src/core/vaults/MetaMorphoStakingVaultAdapter.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";

contract MockUSDCForMetaMorphoAdapter is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockMetaMorphoVault is ERC4626 {
    using SafeERC20 for IERC20;

    constructor(IERC20 asset_) ERC20("MetaMorpho USDC", "mmUSDC") ERC4626(asset_) {}

    function injectYield(uint256 amount) external {
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), amount);
    }
}

contract MetaMorphoStakingVaultAdapterTest is Test {
    MetaMorphoStakingVaultAdapter public adapter;
    MockMetaMorphoVault public metaMorphoVault;
    MockUSDCForMetaMorphoAdapter public usdc;

    address public admin = address(0x1);
    address public vaultMgr = address(0x1);
    address public yieldSource = address(0x3);
    address public other = address(0x9);

    uint256 public constant DEPOSIT_AMT = 1_000e6;
    uint256 public constant YIELD_AMT = 100e6;

    function setUp() public {
        usdc = new MockUSDCForMetaMorphoAdapter();
        metaMorphoVault = new MockMetaMorphoVault(IERC20(address(usdc)));
        adapter = new MetaMorphoStakingVaultAdapter(admin, address(usdc), address(metaMorphoVault));

        usdc.mint(vaultMgr, 10_000e6);
        usdc.mint(yieldSource, 10_000e6);

        vm.prank(vaultMgr);
        usdc.approve(address(adapter), type(uint256).max);

        vm.prank(yieldSource);
        usdc.approve(address(metaMorphoVault), type(uint256).max);
    }

    function test_Constructor_ZeroAdmin_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        new MetaMorphoStakingVaultAdapter(address(0), address(usdc), address(metaMorphoVault));
    }

    function test_Constructor_WrongAsset_Reverts() public {
        MockUSDCForMetaMorphoAdapter otherAsset = new MockUSDCForMetaMorphoAdapter();
        vm.expectRevert(CommonErrorLibrary.InvalidAddress.selector);
        new MetaMorphoStakingVaultAdapter(admin, address(otherAsset), address(metaMorphoVault));
    }

    function test_DepositUnderlying_UsesERC4626Deposit() public {
        vm.prank(vaultMgr);
        uint256 shares = adapter.depositUnderlying(DEPOSIT_AMT);

        assertGt(shares, 0, "Should receive ERC4626 shares");
        assertEq(adapter.principalDeposited(), DEPOSIT_AMT);
        assertEq(adapter.totalUnderlying(), DEPOSIT_AMT);
        assertEq(metaMorphoVault.balanceOf(address(adapter)), shares);
    }

    function test_DepositUnderlying_UnauthorizedCaller_Reverts() public {
        vm.prank(other);
        vm.expectRevert();
        adapter.depositUnderlying(DEPOSIT_AMT);
    }

    function test_DepositUnderlying_ZeroAmount_Reverts() public {
        vm.prank(vaultMgr);
        vm.expectRevert(CommonErrorLibrary.InvalidAmount.selector);
        adapter.depositUnderlying(0);
    }

    function test_WithdrawUnderlying_UsesERC4626Withdraw() public {
        vm.prank(vaultMgr);
        adapter.depositUnderlying(DEPOSIT_AMT);

        uint256 balanceBefore = usdc.balanceOf(vaultMgr);

        vm.prank(vaultMgr);
        uint256 withdrawn = adapter.withdrawUnderlying(DEPOSIT_AMT);

        assertEq(withdrawn, DEPOSIT_AMT);
        assertEq(usdc.balanceOf(vaultMgr) - balanceBefore, DEPOSIT_AMT);
        assertEq(adapter.principalDeposited(), 0);
        assertEq(adapter.totalUnderlying(), 0);
    }

    function test_WithdrawUnderlying_NoPrincipal_Reverts() public {
        vm.prank(vaultMgr);
        vm.expectRevert(CommonErrorLibrary.InsufficientBalance.selector);
        adapter.withdrawUnderlying(DEPOSIT_AMT);
    }

    function test_HarvestYieldToVault_WithdrawsERC4626YieldAndTransfersToCaller() public {
        vm.prank(vaultMgr);
        adapter.depositUnderlying(DEPOSIT_AMT);

        vm.prank(yieldSource);
        metaMorphoVault.injectYield(YIELD_AMT);

        uint256 underlyingBeforeHarvest = adapter.totalUnderlying();
        uint256 expectedHarvest = underlyingBeforeHarvest - DEPOSIT_AMT;
        assertApproxEqAbs(underlyingBeforeHarvest, DEPOSIT_AMT + YIELD_AMT, 1);

        uint256 balBefore = usdc.balanceOf(vaultMgr);

        vm.prank(vaultMgr);
        uint256 harvested = adapter.harvestYieldToVault();

        assertEq(harvested, expectedHarvest);
        assertEq(adapter.principalDeposited(), DEPOSIT_AMT);
        assertApproxEqAbs(adapter.totalUnderlying(), DEPOSIT_AMT, 1);
        assertEq(usdc.balanceOf(vaultMgr) - balBefore, expectedHarvest, "Caller should receive yield");
    }

    function test_HarvestYieldToVault_NoYield_ReturnsZero() public {
        vm.prank(vaultMgr);
        adapter.depositUnderlying(DEPOSIT_AMT);

        vm.prank(vaultMgr);
        uint256 harvested = adapter.harvestYieldToVault();

        assertEq(harvested, 0);
    }

    function test_SetMetaMorphoVault_RequiresMatchingAsset() public {
        MockUSDCForMetaMorphoAdapter otherAsset = new MockUSDCForMetaMorphoAdapter();
        MockMetaMorphoVault wrongVault = new MockMetaMorphoVault(IERC20(address(otherAsset)));

        vm.prank(admin);
        vm.expectRevert(CommonErrorLibrary.InvalidAddress.selector);
        adapter.setMetaMorphoVault(address(wrongVault));
    }

    function test_SetMetaMorphoVault_Success() public {
        MockMetaMorphoVault newVault = new MockMetaMorphoVault(IERC20(address(usdc)));

        vm.prank(admin);
        adapter.setMetaMorphoVault(address(newVault));

        assertEq(address(adapter.metaMorphoVault()), address(newVault));
    }
}
