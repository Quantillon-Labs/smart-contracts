// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MetaMorphoAdapterMigration} from "../src/automation/MetaMorphoAdapterMigration.sol";
import {MetaMorphoStakingVaultAdapter} from "../src/core/vaults/MetaMorphoStakingVaultAdapter.sol";
import {MockUSDCForMetaMorphoAdapter, MockMetaMorphoVault} from "./MetaMorphoStakingVaultAdapter.t.sol";

contract MigrationVaultMock {
    address public usdc;
    address public adapter;
    address public migrator;
    uint256 public principal;
    bool public paused = true;
    bool public reject;
    constructor(address token, address initial, uint256 amount) { usdc = token; adapter = initial; principal = amount; }
    function configure(address caller, bool paused_, bool reject_) external { migrator = caller; paused = paused_; reject = reject_; }
    function setPrincipal(uint256 p) external { principal = p; }
    function getVaultExposure(uint256) external view returns (address, bool, uint256, uint256) {
        return (adapter, true, principal, MetaMorphoStakingVaultAdapter(adapter).totalUnderlying());
    }
    function setStakingVault(uint256, address next, bool) external {
        require(msg.sender == migrator && !reject);
        adapter = next;
    }
}

contract MetaMorphoAdapterMigrationTest is Test {
    MockUSDCForMetaMorphoAdapter token;
    MockMetaMorphoVault morpho;
    MetaMorphoStakingVaultAdapter oldAdapter;
    MetaMorphoStakingVaultAdapter nextAdapter;
    MigrationVaultMock vault;
    MetaMorphoAdapterMigration migration;
    uint256 constant PRINCIPAL = 100e6;

    function setUp() public {
        token = new MockUSDCForMetaMorphoAdapter();
        morpho = new MockMetaMorphoVault(IERC20(address(token)));
        oldAdapter = new MetaMorphoStakingVaultAdapter(address(this), address(token), address(morpho));
        nextAdapter = new MetaMorphoStakingVaultAdapter(address(this), address(token), address(morpho));
        token.mint(address(this), 200e6);
        token.approve(address(oldAdapter), PRINCIPAL);
        oldAdapter.depositUnderlying(PRINCIPAL);
        token.transfer(address(morpho), 10e6);
        vault = new MigrationVaultMock(address(token), address(oldAdapter), PRINCIPAL);
        migration = new MetaMorphoAdapterMigration(address(this), address(vault), 2, address(oldAdapter), address(nextAdapter));
        vault.configure(address(migration), true, false);
        oldAdapter.grantRole(oldAdapter.VAULT_MANAGER_ROLE(), address(migration));
        nextAdapter.grantRole(nextAdapter.VAULT_MANAGER_ROLE(), address(migration));
    }

    function test_PreservesPrincipalAndUncreditedYield() public {
        uint256 beforeUnderlying = oldAdapter.totalUnderlying();
        uint256 safeBalance = token.balanceOf(address(this));
        migration.migrate();
        assertTrue(migration.completed());
        assertEq(vault.adapter(), address(nextAdapter));
        assertEq(vault.principal(), PRINCIPAL);
        assertEq(nextAdapter.principalDeposited(), PRINCIPAL);
        assertEq(oldAdapter.principalDeposited(), 0);
        assertEq(oldAdapter.totalUnderlying(), 0);
        assertGe(nextAdapter.totalUnderlying() + 1, beforeUnderlying);
        assertGt(token.balanceOf(address(nextAdapter)), 0, "yield remains uncredited");
        assertEq(token.balanceOf(address(migration)), 0);
        assertEq(token.allowance(address(migration), address(nextAdapter)), 0);
        assertEq(token.balanceOf(address(this)), safeBalance);
    }

    function test_RejectsUnauthorizedCaller() public {
        vm.prank(address(0xbad)); vm.expectRevert(MetaMorphoAdapterMigration.Unauthorized.selector); migration.migrate();
    }

    function test_RequiresPause() public {
        vault.configure(address(migration), false, false);
        vm.expectRevert(MetaMorphoAdapterMigration.InvalidState.selector); migration.migrate();
    }

    function test_OneUse() public {
        migration.migrate();
        vm.expectRevert(MetaMorphoAdapterMigration.InvalidState.selector); migration.migrate();
    }

    function test_PrincipalMismatchRevertsBeforeWithdrawal() public {
        vault.setPrincipal(PRINCIPAL + 1);
        vm.expectRevert(MetaMorphoAdapterMigration.InvalidState.selector); migration.migrate();
        assertEq(oldAdapter.principalDeposited(), PRINCIPAL);
    }

    function test_ImpairedAdapterCannotUseDonationsToMaskLoss() public {
        morpho.drainAssets(address(this), 20e6);
        token.transfer(address(nextAdapter), 20e6);
        vm.expectRevert(MetaMorphoAdapterMigration.InvalidState.selector); migration.migrate();
        assertFalse(migration.completed());
    }

    function test_IlliquidityLeavesEverythingUnchanged() public {
        morpho.setForcedMaxWithdraw(PRINCIPAL - 1);
        uint256 shares = morpho.balanceOf(address(oldAdapter));
        vm.expectRevert(); migration.migrate();
        assertFalse(migration.completed());
        assertEq(morpho.balanceOf(address(oldAdapter)), shares);
        assertEq(oldAdapter.principalDeposited(), PRINCIPAL);
    }

    function test_RegistryFailureRollsBackHarvestAndDeposit() public {
        vault.configure(address(migration), true, true);
        uint256 shares = morpho.balanceOf(address(oldAdapter));
        uint256 underlying = oldAdapter.totalUnderlying();
        vm.expectRevert(); migration.migrate();
        assertFalse(migration.completed());
        assertEq(vault.adapter(), address(oldAdapter));
        assertEq(morpho.balanceOf(address(oldAdapter)), shares);
        assertEq(oldAdapter.totalUnderlying(), underlying);
        assertEq(nextAdapter.totalUnderlying(), 0);
        assertEq(oldAdapter.principalDeposited(), PRINCIPAL);
        assertEq(nextAdapter.principalDeposited(), 0);
    }

    function test_PrefundedReplacementPrincipalRejected() public {
        token.approve(address(nextAdapter), 1e6);
        nextAdapter.depositUnderlying(1e6);
        vm.expectRevert(MetaMorphoAdapterMigration.InvalidState.selector); migration.migrate();
    }
}
