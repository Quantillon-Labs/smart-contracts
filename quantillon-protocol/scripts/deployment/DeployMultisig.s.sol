// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// Import all contracts
import "../../src/libraries/TimeProviderLibrary.sol";
import "../../src/oracle/ChainlinkOracle.sol";
import "../../src/core/QEUROToken.sol";
import "../../src/core/QTIToken.sol";
import "../../src/core/QuantillonVault.sol";
import "../../src/core/UserPool.sol";
import "../../src/core/HedgerPool.sol";
import "../../src/core/stQEUROToken.sol";
import "../../src/core/vaults/AaveVault.sol";
import "../../src/core/yieldmanagement/YieldShift.sol";

/**
 * @title DeployMultisig
 * @notice Deployment script for Quantillon Protocol with multisig wallet
 * @dev Deploys contracts and configures multisig as admin
 */
contract DeployMultisig is Script {
    // Deployment addresses
    address public timeProvider;
    address public chainlinkOracle;
    address public qeuroToken;
    address public qtiToken;
    address public quantillonVault;
    address public userPool;
    address public hedgerPool;
    address public stQeuroToken;
    address public aaveVault;
    address public yieldShift;

    // Multisig configuration
    address public multisigWallet;
    address public deployer;

    // Mock addresses for localhost
    address constant MOCK_EUR_USD_FEED = 0x1234567890123456789012345678901234567890;
    address constant MOCK_USDC_USD_FEED = 0x2345678901234567890123456789012345678901;
    address constant MOCK_USDC_TOKEN = 0x3456789012345678901234567890123456789012;
    address constant MOCK_AAVE_POOL = 0x4567890123456789012345678901234567890123;

    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        deployer = vm.addr(deployerPrivateKey);
        
        // Get multisig wallet address from environment or use deployer as fallback
        multisigWallet = vm.envOr("MULTISIG_WALLET", deployer);
        
        console.log("=== QUANTILLON PROTOCOL MULTISIG DEPLOYMENT ===");
        console.log("Deploying with account:", deployer);
        console.log("Multisig wallet:", multisigWallet);
        console.log("Account balance:", deployer.balance / 1e18, "ETH");

        vm.startBroadcast(deployerPrivateKey);

        // Phase 1: Deploy Core Infrastructure
        console.log("\n=== PHASE 1: CORE INFRASTRUCTURE ===");
        
        // 1. Deploy TimeProvider
        console.log("Deploying TimeProvider...");
        TimeProvider timeProviderContract = new TimeProvider();
        timeProvider = address(timeProviderContract);
        console.log("TimeProvider deployed to:", timeProvider);

        // 2. Deploy ChainlinkOracle
        console.log("Deploying ChainlinkOracle...");
        ChainlinkOracle chainlinkOracleContract = new ChainlinkOracle(timeProviderContract);
        chainlinkOracle = address(chainlinkOracleContract);
        console.log("ChainlinkOracle deployed to:", chainlinkOracle);

        // 3. Deploy QEUROToken
        console.log("Deploying QEUROToken...");
        QEUROToken qeuroTokenContract = new QEUROToken();
        qeuroToken = address(qeuroTokenContract);
        console.log("QEUROToken deployed to:", qeuroToken);

        // Phase 2: Deploy Core Protocol Contracts
        console.log("\n=== PHASE 2: CORE PROTOCOL ===");
        
        // 4. Deploy QTIToken
        console.log("Deploying QTIToken...");
        QTIToken qtiTokenContract = new QTIToken(timeProviderContract);
        qtiToken = address(qtiTokenContract);
        console.log("QTIToken deployed to:", qtiToken);

        // 5. Deploy QuantillonVault
        console.log("Deploying QuantillonVault...");
        QuantillonVault quantillonVaultContract = new QuantillonVault();
        quantillonVault = address(quantillonVaultContract);
        console.log("QuantillonVault deployed to:", quantillonVault);

        // Phase 3: Deploy Pool Contracts
        console.log("\n=== PHASE 3: POOL CONTRACTS ===");
        
        // 6. Deploy UserPool
        console.log("Deploying UserPool...");
        UserPool userPoolContract = new UserPool(timeProviderContract);
        userPool = address(userPoolContract);
        console.log("UserPool deployed to:", userPool);

        // 7. Deploy HedgerPool
        console.log("Deploying HedgerPool...");
        HedgerPool hedgerPoolContract = new HedgerPool(timeProviderContract);
        hedgerPool = address(hedgerPoolContract);
        console.log("HedgerPool deployed to:", hedgerPool);

        // 8. Deploy stQEUROToken
        console.log("Deploying stQEUROToken...");
        stQEUROToken stQeuroTokenContract = new stQEUROToken(timeProviderContract);
        stQeuroToken = address(stQeuroTokenContract);
        console.log("stQEUROToken deployed to:", stQeuroToken);

        // Phase 4: Deploy Yield Management
        console.log("\n=== PHASE 4: YIELD MANAGEMENT ===");
        
        // 9. Deploy AaveVault
        console.log("Deploying AaveVault...");
        AaveVault aaveVaultContract = new AaveVault();
        aaveVault = address(aaveVaultContract);
        console.log("AaveVault deployed to:", aaveVault);

        // 10. Deploy YieldShift
        console.log("Deploying YieldShift...");
        YieldShift yieldShiftContract = new YieldShift(timeProviderContract);
        yieldShift = address(yieldShiftContract);
        console.log("YieldShift deployed to:", yieldShift);

        vm.stopBroadcast();

        // Save deployment info
        _saveDeploymentInfo();
        
        console.log("\n=== DEPLOYMENT COMPLETED SUCCESSFULLY ===");
        console.log("All contracts deployed and ready for multisig configuration");
        console.log("Deployment info saved to deployments/multisig-localhost.json");
        console.log("\n=== NEXT STEPS ===");
        console.log("1. Run initialization script: forge script scripts/deployment/InitializeMultisig.s.sol --rpc-url http://localhost:8545 --broadcast");
        console.log("2. Transfer admin roles to multisig wallet");
        console.log("3. Verify deployment: forge script scripts/deployment/VerifyMultisig.s.sol --rpc-url http://localhost:8545");
    }

    function _saveDeploymentInfo() internal {
        string memory deploymentInfo = string(abi.encodePacked(
            '{\n',
            '  "network": "localhost",\n',
            '  "deploymentType": "multisig",\n',
            '  "timestamp": "', vm.toString(block.timestamp), '",\n',
            '  "deployer": "', vm.toString(deployer), '",\n',
            '  "multisigWallet": "', vm.toString(multisigWallet), '",\n',
            '  "contracts": {\n',
            '    "TimeProvider": "', vm.toString(timeProvider), '",\n',
            '    "ChainlinkOracle": "', vm.toString(chainlinkOracle), '",\n',
            '    "QEUROToken": "', vm.toString(qeuroToken), '",\n',
            '    "QTIToken": "', vm.toString(qtiToken), '",\n',
            '    "QuantillonVault": "', vm.toString(quantillonVault), '",\n',
            '    "UserPool": "', vm.toString(userPool), '",\n',
            '    "HedgerPool": "', vm.toString(hedgerPool), '",\n',
            '    "stQEUROToken": "', vm.toString(stQeuroToken), '",\n',
            '    "AaveVault": "', vm.toString(aaveVault), '",\n',
            '    "YieldShift": "', vm.toString(yieldShift), '"\n',
            '  },\n',
            '  "mockAddresses": {\n',
            '    "EUR_USD_FEED": "', vm.toString(MOCK_EUR_USD_FEED), '",\n',
            '    "USDC_USD_FEED": "', vm.toString(MOCK_USDC_USD_FEED), '",\n',
            '    "USDC_TOKEN": "', vm.toString(MOCK_USDC_TOKEN), '",\n',
            '    "AAVE_POOL": "', vm.toString(MOCK_AAVE_POOL), '"\n',
            '  }\n',
            '}'
        ));

        vm.writeFile("deployments/multisig-localhost.json", deploymentInfo);
    }
}
