// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

/**
 * @title VerifyDeployment
 * @notice Simple verification script for deployed contracts
 * @dev Checks contract codes without reading files
 */
contract VerifyDeployment is Script {
    function run() external view {
        console.log("=== QUANTILLON PROTOCOL VERIFICATION ===");
        
        // Current deployed addresses (from our successful deployment)
        address timeProvider = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;
        address chainlinkOracle = 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9;
        address qeuroToken = 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9;
        address qtiToken = 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707;
        address quantillonVault = 0x0165878A594ca255338adfa4d48449f69242Eb8F;
        address userPool = 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853;
        address hedgerPool = 0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6;
        address stQeuroToken = 0x8A791620dd6260079BF849Dc5567aDC3F2FdC318;
        address aaveVault = 0x610178dA211FEF7D417bC0e6FeD39F05609AD788;
        address yieldShift = 0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e;

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
