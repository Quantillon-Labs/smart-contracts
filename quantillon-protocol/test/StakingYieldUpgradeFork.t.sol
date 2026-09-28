// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {QuantillonVault} from "../src/core/QuantillonVault.sol";
import {StakingYieldLibrary} from "../src/libraries/StakingYieldLibrary.sol";

interface ILegacyFundingVault {
    function setFundingRateAnnualBps(uint256 newRateBps) external;
}

/// @notice Read-only Base fork rehearsal; run only with an explicitly supplied approved RPC fork.
contract StakingYieldUpgradeForkTest is Test {
    QuantillonVault vault = QuantillonVault(0x833E5Ba510a241b21F1C60c987D1c49eB52E4a07);

    function setUp() public {
        bool baseFork = block.chainid == 8453 && address(vault).code.length != 0;
        if (vm.envOr("REQUIRE_BASE_FORK", false)) require(baseFork, "Base fork required for release rehearsal");
        if (!baseFork) { vm.skip(true); return; }
    }

    function test_upgradePreservesCapitalSharesAndStartsAtZeroHaircut() public {
        uint256 id = vault.defaultStakingVaultId();
        address token = vault.stQEUROTokenByVaultId(id);
        uint256 held = vault.totalUsdcHeld();
        uint256 deployed = vault.totalUsdcInExternalVaults();
        uint256 supply = vault.qeuro().totalSupply();
        uint256 shares = IERC20(token).totalSupply();
        uint256 assets = vault.qeuro().balanceOf(token);
        address pricing = address(vault.executionPricing());
        address oracle = address(vault.oracle());
        (,,uint256 lastHarvest) = vault.harvestConfig(id);
        address controller = address(vault.timelock());
        // Local fork only: retain a nonzero legacy rate to prove it cannot become a haircut.
        bytes32 governance = vault.GOVERNANCE_ROLE();
        vm.prank(controller);
        vault.grantRole(governance, address(this));
        ILegacyFundingVault(address(vault)).setFundingRateAnnualBps(200);
        QuantillonVault next = new QuantillonVault();
        assertLe(address(next).code.length, 24576, "production runtime fits EIP-170");
        vm.prank(controller);
        vault.upgradeToAndCall(address(next), "");
        assertEq(vault.version(), "1.4.0");
        assertEq(vault.hedgerStakingYieldHaircutBps(), 0);
        assertEq(vault.totalUsdcHeld(), held);
        assertEq(vault.totalUsdcInExternalVaults(), deployed);
        assertEq(vault.qeuro().totalSupply(), supply);
        assertEq(IERC20(token).totalSupply(), shares);
        assertEq(vault.qeuro().balanceOf(token), assets);
        assertEq(address(vault.executionPricing()), pricing);
        assertEq(address(vault.oracle()), oracle);
        (uint256 legacyRate,,uint256 currentLast) = vault.harvestConfig(id);
        assertEq(legacyRate, 0);
        assertEq(currentLast, lastHarvest);
    }

    function test_upgradePaysYieldToTheConfiguredHedger() public {
        address hedger = vault.hedgerPool().singleHedger();
        assertTrue(hedger != address(0), "hedger must be configured");
        address safe = 0x1d7fF432a93d0085Fb69474c7E567f859829e6cd;
        assertTrue(vault.hasRole(vault.GOVERNANCE_ROLE(), safe), "Safe must configure recipient");
        address controller = address(vault.timelock());
        uint256 id = vault.defaultStakingVaultId();
        uint256 principal = vault.totalUsdcInExternalVaults();
        QuantillonVault next = new QuantillonVault();

        // Model the ordered calls in the Safe activation batch, all in the local fork.
        vm.prank(safe);
        vault.setHedgerYieldRecipient(hedger);
        vm.prank(controller);
        vault.upgradeToAndCall(address(next), "");
        (, address recipient,) = vault.yieldDistributionConfig(id);
        assertEq(recipient, hedger);

        bytes32 distributor = vault.YIELD_DISTRIBUTOR_ROLE();
        vm.prank(controller);
        vault.grantRole(distributor, address(this));
        StakingYieldLibrary.Split memory split = vault.previewVaultYieldDistribution(id);
        assertGt(split.hedgerShare, 0, "fork must exercise a hedger payout");
        uint256 beforeBalance = vault.usdc().balanceOf(hedger);
        vault.harvestAndDistributeVaultYield(id);
        assertEq(vault.usdc().balanceOf(hedger) - beforeBalance, split.hedgerShare);
        assertEq(vault.totalUsdcInExternalVaults(), principal);
    }
}
