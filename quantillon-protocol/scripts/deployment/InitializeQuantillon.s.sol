// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";

// Import all contracts
import "../src/libraries/TimeProviderLibrary.sol";
import "../src/oracle/ChainlinkOracle.sol";
import "../src/core/QEUROToken.sol";
import "../src/core/QTIToken.sol";
import "../src/core/QuantillonVault.sol";
import "../src/core/UserPool.sol";
import "../src/core/HedgerPool.sol";
import "../src/core/stQEUROToken.sol";
import "../src/core/vaults/AaveVault.sol";
import "../src/core/yieldmanagement/YieldShift.sol";

/**
 * @title InitializeQuantillon
 * @notice Initializes all deployed Quantillon Protocol contracts
 * @dev Sets up proper roles, relationships, and initial configuration
 */
contract InitializeQuantillon is Script {
    // Mock addresses for localhost
    address constant MOCK_EUR_USD_FEED = 0x1234567890123456789012345678901234567890;
    address constant MOCK_USDC_USD_FEED = 0x2345678901234567890123456789012345678901;
    address constant MOCK_USDC_TOKEN = 0x3456789012345678901234567890123456789012;
    address constant MOCK_AAVE_POOL = 0x4567890123456789012345678901234567890123;

    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== QUANTILLON PROTOCOL INITIALIZATION ===");
        console.log("Initializing with account:", deployer);

        // Load deployment addresses from the deployment file
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

        vm.startBroadcast(deployerPrivateKey);

        // Phase 1: Initialize Core Infrastructure
        console.log("\n=== PHASE 1: CORE INFRASTRUCTURE ===");
        
        // Initialize TimeProvider
        console.log("Initializing TimeProvider...");
        TimeProvider(timeProvider).initialize(
            deployer, // admin
            deployer, // governance
            deployer  // emergency
        );
        console.log("✓ TimeProvider initialized");

        // Initialize ChainlinkOracle
        console.log("Initializing ChainlinkOracle...");
        ChainlinkOracle(chainlinkOracle).initialize(
            deployer, // admin
            MOCK_EUR_USD_FEED,
            MOCK_USDC_USD_FEED,
            deployer  // treasury
        );
        console.log("✓ ChainlinkOracle initialized");

        // Phase 2: Initialize Core Protocol
        console.log("\n=== PHASE 2: CORE PROTOCOL ===");
        
        // Initialize QEUROToken
        console.log("Initializing QEUROToken...");
        QEUROToken(qeuroToken).initialize(
            deployer, // admin
            quantillonVault, // vault
            deployer, // timelock
            deployer  // treasury
        );
        console.log("✓ QEUROToken initialized");

        // Initialize QTIToken
        console.log("Initializing QTIToken...");
        QTIToken(qtiToken).initialize(
            deployer, // admin
            deployer, // treasury
            deployer  // timelock
        );
        console.log("✓ QTIToken initialized");

        // Initialize QuantillonVault
        console.log("Initializing QuantillonVault...");
        QuantillonVault(quantillonVault).initialize(
            deployer, // admin
            qeuroToken,
            MOCK_USDC_TOKEN,
            chainlinkOracle,
            deployer  // timelock
        );
        console.log("✓ QuantillonVault initialized");

        // Phase 3: Initialize Pool Contracts
        console.log("\n=== PHASE 3: POOL CONTRACTS ===");
        
        // Initialize UserPool
        console.log("Initializing UserPool...");
        UserPool(userPool).initialize(
            deployer, // admin
            qeuroToken,
            MOCK_USDC_TOKEN,
            quantillonVault,
            yieldShift,
            deployer, // timelock
            deployer  // treasury
        );
        console.log("✓ UserPool initialized");

        // Initialize HedgerPool
        console.log("Initializing HedgerPool...");
        HedgerPool(hedgerPool).initialize(
            deployer, // admin
            MOCK_USDC_TOKEN,
            chainlinkOracle,
            yieldShift,
            deployer, // timelock
            deployer  // treasury
        );
        console.log("✓ HedgerPool initialized");

        // Initialize stQEUROToken
        console.log("Initializing stQEUROToken...");
        stQEUROToken(stQeuroToken).initialize(
            deployer, // admin
            qeuroToken,
            yieldShift,
            MOCK_USDC_TOKEN,
            deployer, // treasury
            deployer  // timelock
        );
        console.log("✓ stQEUROToken initialized");

        // Phase 4: Initialize Yield Management
        console.log("\n=== PHASE 4: YIELD MANAGEMENT ===");
        
        // Initialize AaveVault
        console.log("Initializing AaveVault...");
        AaveVault(aaveVault).initialize(
            deployer, // admin
            MOCK_USDC_TOKEN,
            MOCK_AAVE_POOL,
            address(0), // rewardsController (mock)
            yieldShift,
            deployer, // timelock
            deployer  // treasury
        );
        console.log("✓ AaveVault initialized");

        // Initialize YieldShift
        console.log("Initializing YieldShift...");
        YieldShift(yieldShift).initialize(
            deployer, // admin
            MOCK_USDC_TOKEN,
            userPool,
            hedgerPool,
            aaveVault,
            stQeuroToken,
            deployer, // timelock
            deployer  // treasury
        );
        console.log("✓ YieldShift initialized");

        // Phase 5: Configure Contract Relationships
        console.log("\n=== PHASE 5: CONFIGURE RELATIONSHIPS ===");
        
        // Set minter role for QEURO token
        console.log("Configuring QEURO token roles...");
        bytes32 MINTER_ROLE = QEUROToken(qeuroToken).MINTER_ROLE();
        QEUROToken(qeuroToken).grantRole(MINTER_ROLE, quantillonVault);
        console.log("✓ Minter role granted to QuantillonVault");

        // Set yield manager roles
        console.log("Configuring YieldShift roles...");
        bytes32 YIELD_MANAGER_ROLE = YieldShift(yieldShift).YIELD_MANAGER_ROLE();
        YieldShift(yieldShift).grantRole(YIELD_MANAGER_ROLE, aaveVault);
        console.log("✓ Yield manager role granted to AaveVault");

        vm.stopBroadcast();

        console.log("\n=== INITIALIZATION COMPLETED SUCCESSFULLY ===");
        console.log("All contracts initialized and configured");
        console.log("Quantillon Protocol is ready for use!");
    }
}
