// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SignedExecutionPricing} from "../../src/oracle/SignedExecutionPricing.sol";
import {SignedReferenceSource} from "../../src/oracle/SignedReferenceSource.sol";

/// @notice Deploy inactive modules under governance; activation and proxy upgrades are separate.
/// @dev The broadcaster receives no role. No signing key or transaction payload is exported.
contract SignedQuoteDeployment is Script {
    function run() external returns (SignedReferenceSource source, SignedExecutionPricing pricing) {
        string memory environment = vm.envString("QUANTILLON_ENV");
        uint256 expectedChain = vm.envUint("QUOTE_CHAIN_ID");
        bytes32 name = keccak256(bytes(environment));
        require(
            (name == keccak256("dev") && expectedChain == 31337)
                || (name == keccak256("preprod") && expectedChain == 31338)
                || (name == keccak256("prod") && expectedChain == 8453),
            "environment/chain mismatch"
        );
        require(block.chainid == expectedChain, "wrong chain");
        address vault = vm.envAddress("QUOTE_VAULT");
        address independent = vm.envAddress("QUOTE_INDEPENDENT_REFERENCE");
        address governance = vm.envAddress("QUOTE_GOVERNANCE");
        address reserve = vm.envAddress("QUOTE_RESERVE_RECIPIENT");
        require(vault.code.length != 0 && independent.code.length != 0, "missing dependencies");
        require(governance != address(0) && reserve != address(0), "zero authority");
        uint256 age = vm.envUint("QUOTE_MAX_AGE_SECONDS");
        uint256 independentAge = vm.envUint("QUOTE_MAX_REFERENCE_AGE");
        uint256 normalBps = vm.envUint("QUOTE_NORMAL_DIVERGENCE_BPS");
        uint256 offHoursBps = vm.envUint("QUOTE_OFF_HOURS_DIVERGENCE_BPS");
        uint256 impact = vm.envUint("QUOTE_MAX_IMPACT_BPS");
        uint256 outstanding = vm.envUint("QUOTE_MAX_OUTSTANDING_EUR_RAW");
        uint256 haircut = vm.envUint("QUOTE_EMERGENCY_HAIRCUT_BPS");
        vm.startBroadcast();
        source = new SignedReferenceSource(governance, independent, age, independentAge, normalBps, offHoursBps);
        pricing = new SignedExecutionPricing(governance, vault, address(source), reserve, impact, outstanding, age, haircut);
        vm.stopBroadcast();
        console.log("SignedReferenceSource", address(source));
        console.log("SignedExecutionPricing", address(pricing));
        console.log("Modules remain paused and unbound. Governed roles, upgrades and activation are still required.");
    }
}
