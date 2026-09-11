// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {QuantillonVault} from "../../src/core/QuantillonVault.sol";
import {QEUROToken} from "../../src/core/QEUROToken.sol";
import {ExecutionPricing} from "../../src/oracle/ExecutionPricing.sol";
import {CommonErrorLibrary as Errors} from "../../src/libraries/CommonErrorLibrary.sol";

interface IAuditStakingToken {
    function deposit(uint256 assets, address receiver) external returns (uint256);
}

/// @notice Execute only with an explicitly supplied Base fork. All mutations occur in Foundry's local VM.
contract MintExecutionLiveForkAuditTest is Test {
    QuantillonVault internal vault = QuantillonVault(0x833E5Ba510a241b21F1C60c987D1c49eB52E4a07);
    QEUROToken internal qeuro = QEUROToken(0x69aD4e6c49d6275D0e11b5515D98a89f029869AA);
    IERC20 internal usdc = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    ExecutionPricing internal pricing;
    address internal outsider = address(0xBADCAFE);
    address internal publisher = 0xC57bF47310897B49aa72503AE568Fa46f2a5E008;
    address internal keeper = 0x6b4B4eBC64Ec4d8910B9ac4d8E733803F80EB7C2;

    function setUp() public {
        if (block.chainid != 8453) { vm.skip(true); return; }
        pricing = ExecutionPricing(address(vault.executionPricing()));
        assertTrue(address(pricing) != address(0));
        assertEq(pricing.vault(), address(vault));
        assertFalse(vault.paused());
        deal(address(usdc), outsider, 1_000_000e6);
        vm.prank(outsider);
        usdc.approve(address(vault), type(uint256).max);
    }

    function test_LiveAudit_DirectMintCannotBypassDepthOrCapacity() public {
        uint256 supply = qeuro.totalSupply();
        vm.prank(outsider);
        vm.expectRevert(Errors.InsufficientBalance.selector);
        vault.mintQEUROToVault(1_000_000e6, 0, 0);
        assertEq(qeuro.totalSupply(), supply);
    }

    function test_LiveAudit_DirectMintCannotBypassExpiredExecutionObservation() public {
        vm.warp(block.timestamp + pricing.maxAge() + 1);
        vm.prank(outsider);
        vm.expectRevert(Errors.InvalidOraclePrice.selector);
        vault.mintQEUROToVault(1e6, 0, 0);
    }

    function test_LiveAudit_OutsiderCannotMintTokenOrCreditYield() public {
        bytes4 denied = bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)"));
        vm.startPrank(outsider);
        vm.expectPartialRevert(denied);
        qeuro.mint(outsider, 1e18);
        vm.expectPartialRevert(denied);
        vault.creditVaultYield(1, 1e6);
        vm.stopPrank();
    }

    function test_LiveAudit_Finding_RealYieldPathIgnoresZeroExecutionCapacity() public {
        uint256 vaultId = _prepareYieldCredit();
        uint256 buy = pricing.admittedBuy();
        uint256 supply = qeuro.totalSupply();
        vm.prank(keeper);
        uint256 minted = vault.creditVaultYield(vaultId, 1e6);
        assertGt(minted, 0);
        assertEq(qeuro.totalSupply() - supply, minted);
        assertEq(pricing.admittedBuy(), buy);
        assertEq(pricing.outstanding(), 0);
        emit log_named_uint("QEURO minted with zero execution capacity (18 decimals)", minted);
    }

    function _prepareYieldCredit() internal returns (uint256 vaultId) {
        assertTrue(pricing.hasRole(pricing.REPORTER_ROLE(), publisher));
        assertTrue(vault.hasRole(vault.YIELD_DISTRIBUTOR_ROLE(), keeper));
        for (uint256 i=1; i<=32; ++i) {
            address token = vault.stQEUROTokenByVaultId(i);
            if (token != address(0)) { vaultId=i; break; }
        }
        assertGt(vaultId, 0, "fork requires a registered stQEURO token");
        address stToken = vault.stQEUROTokenByVaultId(vaultId);
        // The pinned chain state has no stQEURO holders. Create one through normal
        // public calls on the local fork before exercising the privileged credit path.
        if (IERC20(stToken).totalSupply() == 0) {
            vm.startPrank(outsider);
            vault.mintQEUROToVault(1e6, 0, 0);
            uint256 q = qeuro.balanceOf(outsider);
            qeuro.approve(stToken, q);
            IAuditStakingToken(stToken).deposit(q, outsider);
            vm.stopPrank();
        }
        uint256 buy = pricing.admittedBuy();
        uint256 sell = pricing.admittedSell();
        vm.prank(publisher);
        pricing.acknowledge(buy, sell, 0, block.timestamp);
        deal(address(usdc), keeper, 1e6);
        vm.prank(keeper);
        usdc.approve(address(vault), 1e6);
    }

    function _upgradeToFixedVault() internal {
        uint256 held = vault.totalUsdcHeld();
        uint256 supply = qeuro.totalSupply();
        address oracle = address(vault.oracle());
        address module = address(vault.executionPricing());
        address controller = address(vault.timelock());
        QuantillonVault implementation = new QuantillonVault();
        assertLe(address(implementation).code.length, 24_576);
        // Exercise the proxy's UUPS authorization as the existing controller in
        // the local VM. This does not schedule or execute any mainnet transaction.
        vm.prank(controller);
        vault.upgradeToAndCall(address(implementation), "");
        assertEq(vault.version(), "1.2.1");
        assertEq(vault.totalUsdcHeld(), held);
        assertEq(qeuro.totalSupply(), supply);
        assertEq(address(vault.oracle()), oracle);
        assertEq(address(vault.executionPricing()), module);
        assertEq(address(vault.timelock()), controller);
    }

    function test_LiveAudit_UpgradeBlocksYieldAtZeroCapacity() public {
        uint256 vaultId = _prepareYieldCredit();
        _upgradeToFixedVault();
        uint256 supply = qeuro.totalSupply();
        uint256 buy = pricing.admittedBuy();
        vm.prank(keeper);
        vm.expectRevert(Errors.InsufficientBalance.selector);
        vault.creditVaultYield(vaultId, 1e6);
        assertEq(qeuro.totalSupply(), supply);
        assertEq(pricing.admittedBuy(), buy);
        assertEq(usdc.balanceOf(keeper), 1e6);
    }

    function test_LiveAudit_UpgradeBlocksYieldWithExpiredExecutionObservation() public {
        uint256 vaultId = _prepareYieldCredit();
        _upgradeToFixedVault();
        vm.warp(block.timestamp + pricing.maxAge() + 1);
        vm.prank(keeper);
        vm.expectRevert(Errors.InvalidOraclePrice.selector);
        vault.creditVaultYield(vaultId, 1e6);
        assertEq(usdc.balanceOf(keeper), 1e6);
    }

    function test_LiveAudit_UpgradePricesYieldAndReservesExposure() public {
        uint256 vaultId = _prepareYieldCredit();
        _upgradeToFixedVault();
        uint256 buy = pricing.admittedBuy();
        uint256 sell = pricing.admittedSell();
        vm.prank(publisher);
        pricing.acknowledge(buy, sell, 100e18, block.timestamp);
        uint256 supply = qeuro.totalSupply();
        uint256 held = vault.totalUsdcHeld();
        uint256 reserve = usdc.balanceOf(address(pricing));
        vm.prank(keeper);
        uint256 minted = vault.creditVaultYield(vaultId, 1e6);
        uint256 spread = usdc.balanceOf(address(pricing)) - reserve;
        assertGt(minted, 0);
        assertGt(spread, 0);
        assertEq(qeuro.totalSupply() - supply, minted);
        assertEq(pricing.admittedBuy() - buy, minted);
        assertEq(pricing.outstanding(), minted);
        assertEq(vault.totalUsdcHeld() - held + spread, 1e6);
    }
}
