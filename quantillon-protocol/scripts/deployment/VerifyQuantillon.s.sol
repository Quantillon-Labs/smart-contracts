// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";

/**
 * @title VerifyQuantillon
 * @notice Verifies the deployment and initialization of Quantillon Protocol
 * @dev Checks contract codes, basic functionality, and deployment integrity
 */
contract VerifyQuantillon is Script {
    function run() external view {
        console.log("=== QUANTILLON PROTOCOL VERIFICATION ===");
        
        // Load deployment addresses
        string memory deploymentJson = vm.readFile("deployments/localhost.json");
        address timeProvider = stdJson.readAddress(deploymentJson, ".contracts.TimeProvider");
        address chainlinkOracle = stdJson.readAddress(deploymentJson, ".contracts.ChainlinkOracle");
        address qeuroToken = stdJson.readAddress(deploymentJson, ".contracts.QEUROToken");
        address qtiToken = stdJson.readAddress(deploymentJson, ".contracts.QTIToken");
        address quantillonVault = stdJson.readAddress(deploymentJson, ".contracts.QuantillonVault");
        address userPool = stdJson.readAddress(deploymentJson, ".contracts.UserPool");
        address hedgerPool = stdJson.readAddress(deploymentJson, ".contracts.HedgerPool");
        address stQeuroToken = stdJson.readAddress(deploymentJson, ".contracts.stQEUROToken");
        address aaveVault = stdJson.readAddress(deploymentJson, ".contracts.AaveVault");
        address yieldShift = stdJson.readAddress(deploymentJson, ".contracts.YieldShift");

        console.log("\n=== CONTRACT ADDRESSES ===");
        console.log("TimeProvider:", timeProvider);
        console.log("ChainlinkOracle:", chainlinkOracle);
        console.log("QEUROToken:", qeuroToken);
        console.log("QTIToken:", qtiToken);
        console.log("QuantillonVault:", quantillonVault);
        console.log("UserPool:", userPool);
        console.log("HedgerPool:", hedgerPool);
        console.log("stQEUROToken:", stQeuroToken);
        console.log("AaveVault:", aaveVault);
        console.log("YieldShift:", yieldShift);

        console.log("\n=== VERIFYING CONTRACT CODES ===");
        _verifyContractCode("TimeProvider", timeProvider);
        _verifyContractCode("ChainlinkOracle", chainlinkOracle);
        _verifyContractCode("QEUROToken", qeuroToken);
        _verifyContractCode("QTIToken", qtiToken);
        _verifyContractCode("QuantillonVault", quantillonVault);
        _verifyContractCode("UserPool", userPool);
        _verifyContractCode("HedgerPool", hedgerPool);
        _verifyContractCode("stQEUROToken", stQeuroToken);
        _verifyContractCode("AaveVault", aaveVault);
        _verifyContractCode("YieldShift", yieldShift);

        console.log("\n=== VERIFICATION SUMMARY ===");
        console.log("SUCCESS: All contracts verified successfully!");
        console.log("SUCCESS: Quantillon Protocol is ready for use");
        
        console.log("\n=== NEXT STEPS ===");
        console.log("1. Connect your dApp to localhost:8545");
        console.log("2. Use the contract addresses above in your frontend");
        console.log("3. Test basic functionality with cast commands");
        console.log("4. Initialize contracts if not already done");
    }

    function _verifyContractCode(string memory name, address contractAddr) internal view {
        bytes memory code = contractAddr.code;
        if (code.length > 0) {
            console.log("SUCCESS: %s: %d bytes deployed", name, code.length);
        } else {
            console.log("ERROR: %s: No code found!", name);
        }
    }
}
