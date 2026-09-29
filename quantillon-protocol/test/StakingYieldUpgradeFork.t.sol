// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {QuantillonVault} from "../src/core/QuantillonVault.sol";
import {stQEUROToken} from "../src/core/stQEUROToken.sol";
import {StakingYieldLibrary} from "../src/libraries/StakingYieldLibrary.sol";

/// @notice Read-only Base fork rehearsal. Pin a block running 1.4.0 via the approved protocol RPC.
contract StakingYieldUpgradeForkTest is Test {
    QuantillonVault vault = QuantillonVault(0x833E5Ba510a241b21F1C60c987D1c49eB52E4a07);

    function setUp() public {
        bool baseFork = block.chainid == 8453 && address(vault).code.length != 0;
        if (vm.envOr("REQUIRE_BASE_FORK", false)) require(baseFork, "Base fork required for release rehearsal");
        if (!baseFork) { vm.skip(true); return; }
        assertEq(vault.version(), "1.4.0", "pin the deployed predecessor");
    }

    function _state(uint256 id) internal view returns (bytes32) {
        stQEUROToken token = stQEUROToken(vault.stQEUROTokenByVaultId(id));
        bytes32 vaultState = keccak256(abi.encode(
            vault.totalUsdcHeld(), vault.totalUsdcInExternalVaults(), vault.qeuro().totalSupply(),
            address(vault.executionPricing()), address(vault.oracle()), vault.hedgerStakingYieldHaircutBps()
        ));
        bytes32 tokenState = keccak256(abi.encode(
            token.totalSupply(), vault.qeuro().balanceOf(address(token)), token.totalAssets(), token.vestingPeriod()
        ));
        return keccak256(abi.encode(vaultState, tokenState, _tokenStorage(address(token))));
    }

    function _tokenStorage(address token) internal view returns (bytes32 digest) {
        // Cover ordinary token storage, including private vesting fields, without changing the token ABI.
        for (uint256 slot; slot < 64; ++slot) digest = keccak256(abi.encode(digest, vm.load(token, bytes32(slot))));
    }

    function _upgrade() internal {
        QuantillonVault next = new QuantillonVault();
        assertLe(address(next).code.length, 24576, "production runtime fits EIP-170");
        vm.prank(address(vault.timelock()));
        vault.upgradeToAndCall(address(next), "");
    }

    function test_upgradePreservesBalancesVestingConfigurationAndClock() public {
        uint256 id = vault.defaultStakingVaultId();
        bytes32 beforeState = _state(id);
        (uint256 haircut, address recipient, uint256 last) = vault.yieldDistributionConfig(id);
        _upgrade();
        assertEq(vault.version(), "1.5.0");
        assertEq(_state(id), beforeState);
        (uint256 afterHaircut, address afterRecipient, uint256 afterLast) = vault.yieldDistributionConfig(id);
        assertEq(afterHaircut, haircut); assertEq(afterRecipient, recipient); assertEq(afterLast, last);
    }

    function _harvest(uint256 haircut) internal {
        _upgrade();
        uint256 id = vault.defaultStakingVaultId();
        address controller = address(vault.timelock());
        bytes32 governance = vault.GOVERNANCE_ROLE();
        bytes32 distributor = vault.YIELD_DISTRIBUTOR_ROLE();
        vm.startPrank(controller);
        vault.grantRole(governance, address(this));
        vault.grantRole(distributor, address(this));
        vm.stopPrank();
        address sink = address(0xBEEF);
        vault.setHedgerYieldRecipient(sink);
        vault.setHedgerStakingYieldHaircutBps(haircut);
        uint256 principal = vault.totalUsdcInExternalVaults();
        StakingYieldLibrary.Split memory split = vault.previewVaultYieldDistribution(id);
        assertGt(split.realizedYield, 0, "fork must contain harvestable yield");
        assertEq(split.hedgerBase, 0);
        assertEq(split.hedgerShare, split.haircut);
        if (haircut == 0) assertEq(split.hedgerShare, 0);
        else assertGt(split.hedgerShare, 0);
        stQEUROToken token = stQEUROToken(vault.stQEUROTokenByVaultId(id));
        uint256 beforeAssets = vault.qeuro().balanceOf(address(token));
        uint256 beforeRedeemable = token.totalAssets();
        uint256 beforeHedger = vault.usdc().balanceOf(sink);
        uint256 beforeTreasury = vault.usdc().balanceOf(vault.treasury());
        vault.harvestAndDistributeVaultYield(id);
        assertEq(vault.usdc().balanceOf(sink) - beforeHedger, split.hedgerShare);
        assertEq(vault.usdc().balanceOf(vault.treasury()) - beforeTreasury, split.treasuryShare);
        assertEq(vault.totalUsdcInExternalVaults(), principal);
        assertGt(vault.qeuro().balanceOf(address(token)), beforeAssets);
        token.syncVesting();
        assertEq(token.totalAssets(), beforeRedeemable, "new yield does not unlock immediately");
        vm.warp(block.timestamp + token.vestingPeriod());
        assertEq(token.totalAssets(), vault.qeuro().balanceOf(address(token)));
    }

    function test_upgradePaysNoHedgerBaseAtZeroHaircut() public { _harvest(0); }
    function test_upgradePaysOnlyConfiguredHaircut() public { _harvest(200); }
}
