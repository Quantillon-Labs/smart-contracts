// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {SignedQuoteDeployment as DeploySignedQuoteModules} from "../scripts/utils/SignedQuoteDeployment.s.sol";
import {SignedExecutionPricing} from "../src/oracle/SignedExecutionPricing.sol";
import {SignedReferenceSource} from "../src/oracle/SignedReferenceSource.sol";
import {SignedQuoteTypes as T} from "../src/libraries/SignedQuoteTypes.sol";

contract SignedQuoteDeploymentTest is Test {
    address private constant GOVERNANCE = address(0xA11CE);

    function _config(string memory environment, uint256 chain) private {
        vm.chainId(chain);
        vm.setEnv("QUANTILLON_ENV", environment); vm.setEnv("QUOTE_CHAIN_ID", vm.toString(chain));
        vm.setEnv("QUOTE_VAULT", vm.toString(address(this)));
        vm.setEnv("QUOTE_INDEPENDENT_REFERENCE", vm.toString(address(this)));
        vm.setEnv("QUOTE_GOVERNANCE", vm.toString(GOVERNANCE));
        vm.setEnv("QUOTE_RESERVE_RECIPIENT", vm.toString(address(0xBEEF)));
        vm.setEnv("QUOTE_MAX_AGE_SECONDS", "60"); vm.setEnv("QUOTE_MAX_REFERENCE_AGE", "8100");
        vm.setEnv("QUOTE_NORMAL_DIVERGENCE_BPS", "200"); vm.setEnv("QUOTE_OFF_HOURS_DIVERGENCE_BPS", "300");
        vm.setEnv("QUOTE_MAX_IMPACT_BPS", "25"); vm.setEnv("QUOTE_MAX_OUTSTANDING_EUR_RAW", vm.toString(uint256(1000e18)));
        vm.setEnv("QUOTE_EMERGENCY_HAIRCUT_BPS", "25");
    }

    function test_DeploymentSeparatesAllEnvironmentsAndLeavesModulesInactive() public {
        string[3] memory environments = [string("dev"), "preprod", "prod"];
        uint256[3] memory chains = [uint256(31337), 31338, 8453];
        for (uint256 i; i < chains.length; ++i) {
            _config(environments[i], chains[i]);
            DeploySignedQuoteModules script = new DeploySignedQuoteModules();
            (SignedReferenceSource source, SignedExecutionPricing pricing) = script.run();
            assertEq(pricing.vault(), address(this)); assertEq(address(pricing.referenceSource()), address(source));
            assertEq(uint256(pricing.mode()), uint256(T.Mode.Paused));
            assertTrue(pricing.hasRole(pricing.DEFAULT_ADMIN_ROLE(), GOVERNANCE));
            assertTrue(source.hasRole(source.DEFAULT_ADMIN_ROLE(), GOVERNANCE));
            assertFalse(pricing.hasRole(pricing.DEFAULT_ADMIN_ROLE(), address(script)));
            assertFalse(pricing.hasRole(pricing.QUOTE_SIGNER_ROLE(), GOVERNANCE));
            assertEq(source.observedAt(), 0); assertEq(pricing.outstanding(), 0);
        }
        // Environment variables are process-wide in Forge. Keep all script
        // scenarios in one test so parallel tests cannot overwrite each other.
        _config("prod", 31337);
        DeploySignedQuoteModules script = new DeploySignedQuoteModules();
        vm.expectRevert("environment/chain mismatch"); script.run();
        _config("prod", 8453); vm.chainId(31338);
        vm.expectRevert("wrong chain"); script.run();
    }
}
