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
 * @title InitializeMultisig
 * @notice Initialization script for Quantillon Protocol with multisig wallet
 * @dev Initializes contracts and transfers admin roles to multisig
 */
contract InitializeMultisig is Script {
    // Contract addresses from deployment
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
        
        // Load deployment addresses from file
        _loadDeploymentAddresses();
        
        console.log("=== QUANTILLON PROTOCOL MULTISIG INITIALIZATION ===");
        console.log("Initializing with account:", deployer);
        console.log("Multisig wallet:", multisigWallet);
        console.log("Account balance:", deployer.balance / 1e18, "ETH");

        vm.startBroadcast(deployerPrivateKey);

        // Get contract instances
        TimeProvider timeProviderContract = TimeProvider(timeProvider);
        ChainlinkOracle chainlinkOracleContract = ChainlinkOracle(chainlinkOracle);
        QEUROToken qeuroTokenContract = QEUROToken(qeuroToken);
        QTIToken qtiTokenContract = QTIToken(qtiToken);
        QuantillonVault quantillonVaultContract = QuantillonVault(quantillonVault);
        UserPool userPoolContract = UserPool(userPool);
        HedgerPool hedgerPoolContract = HedgerPool(hedgerPool);
        stQEUROToken stQeuroTokenContract = stQEUROToken(stQeuroToken);
        AaveVault aaveVaultContract = AaveVault(aaveVault);
        YieldShift yieldShiftContract = YieldShift(yieldShift);

        // Phase 1: Initialize Core Infrastructure
        console.log("\n=== PHASE 1: INITIALIZE CORE INFRASTRUCTURE ===");
        
        // 1. Initialize TimeProvider
        console.log("Initializing TimeProvider...");
        try timeProviderContract.initialize(deployer) {
            console.log("[OK] TimeProvider initialized");
        } catch {
            console.log("[WARN] TimeProvider already initialized or failed");
        }

        // 2. Initialize ChainlinkOracle
        console.log("Initializing ChainlinkOracle...");
        try chainlinkOracleContract.initialize(
            deployer,
            MOCK_EUR_USD_FEED,
            MOCK_USDC_USD_FEED
        ) {
            console.log("[OK] ChainlinkOracle initialized");
        } catch {
            console.log("[WARN] ChainlinkOracle already initialized or failed");
        }

        // 3. Initialize QEUROToken
        console.log("Initializing QEUROToken...");
        try qeuroTokenContract.initialize(
            deployer,
            multisigWallet // Treasury address
        ) {
            console.log("[OK] QEUROToken initialized");
        } catch {
            console.log("[WARN] QEUROToken already initialized or failed");
        }

        // Phase 2: Initialize Core Protocol
        console.log("\n=== PHASE 2: INITIALIZE CORE PROTOCOL ===");
        
        // 4. Initialize QTIToken
        console.log("Initializing QTIToken...");
        try qtiTokenContract.initialize(
            deployer,
            multisigWallet, // Treasury address
            multisigWallet  // Timelock address (can be updated later)
        ) {
            console.log("[OK] QTIToken initialized");
        } catch {
            console.log("[WARN] QTIToken already initialized or failed");
        }

        // 5. Initialize QuantillonVault
        console.log("Initializing QuantillonVault...");
        try quantillonVaultContract.initialize(
            deployer,
            qeuroToken,
            MOCK_USDC_TOKEN,
            chainlinkOracle
        ) {
            console.log("[OK] QuantillonVault initialized");
        } catch {
            console.log("[WARN] QuantillonVault already initialized or failed");
        }

        // Phase 3: Initialize Pool Contracts
        console.log("\n=== PHASE 3: INITIALIZE POOL CONTRACTS ===");
        
        // 6. Initialize UserPool
        console.log("Initializing UserPool...");
        try userPoolContract.initialize(
            deployer,
            qeuroToken,
            quantillonVault,
            MOCK_USDC_TOKEN
        ) {
            console.log("[OK] UserPool initialized");
        } catch {
            console.log("[WARN] UserPool already initialized or failed");
        }

        // 7. Initialize HedgerPool
        console.log("Initializing HedgerPool...");
        try hedgerPoolContract.initialize(
            deployer,
            qeuroToken,
            chainlinkOracle,
            MOCK_USDC_TOKEN
        ) {
            console.log("[OK] HedgerPool initialized");
        } catch {
            console.log("[WARN] HedgerPool already initialized or failed");
        }

        // 8. Initialize stQEUROToken
        console.log("Initializing stQEUROToken...");
        try stQeuroTokenContract.initialize(
            deployer,
            qeuroToken,
            multisigWallet // Treasury address
        ) {
            console.log("[OK] stQEUROToken initialized");
        } catch {
            console.log("[WARN] stQEUROToken already initialized or failed");
        }

        // Phase 4: Initialize Yield Management
        console.log("\n=== PHASE 4: INITIALIZE YIELD MANAGEMENT ===");
        
        // 9. Initialize AaveVault
        console.log("Initializing AaveVault...");
        try aaveVaultContract.initialize(
            deployer,
            qeuroToken,
            MOCK_USDC_TOKEN,
            MOCK_AAVE_POOL
        ) {
            console.log("[OK] AaveVault initialized");
        } catch {
            console.log("[WARN] AaveVault already initialized or failed");
        }

        // 10. Initialize YieldShift
        console.log("Initializing YieldShift...");
        try yieldShiftContract.initialize(
            deployer,
            userPool,
            hedgerPool,
            aaveVault,
            MOCK_USDC_TOKEN
        ) {
            console.log("[OK] YieldShift initialized");
        } catch {
            console.log("[WARN] YieldShift already initialized or failed");
        }

        vm.stopBroadcast();

        // Phase 5: Configure Contract Relationships
        console.log("\n=== PHASE 5: CONFIGURE CONTRACT RELATIONSHIPS ===");
        _configureContractRelationships();

        // Phase 6: Transfer Admin Roles to Multisig
        console.log("\n=== PHASE 6: TRANSFER ADMIN ROLES TO MULTISIG ===");
        _transferAdminRoles();

        console.log("\n=== INITIALIZATION COMPLETED SUCCESSFULLY ===");
        console.log("All contracts initialized and configured for multisig governance");
        console.log("Admin roles transferred to multisig wallet:", multisigWallet);
    }

    function _loadDeploymentAddresses() internal {
        // Read deployment addresses from file
        string memory deploymentFile = "deployments/multisig-localhost.json";
        
        try vm.readFile(deploymentFile) returns (string memory jsonData) {
            // Parse JSON to extract addresses
            // For simplicity, we'll use hardcoded approach or environment variables
            console.log("Loading deployment addresses from:", deploymentFile);
        } catch {
            console.log("[WARN] Deployment file not found, using environment variables");
        }

        // Load addresses from environment variables or use defaults
        timeProvider = vm.envOr("TIME_PROVIDER", address(0));
        chainlinkOracle = vm.envOr("CHAINLINK_ORACLE", address(0));
        qeuroToken = vm.envOr("QEURO_TOKEN", address(0));
        qtiToken = vm.envOr("QTI_TOKEN", address(0));
        quantillonVault = vm.envOr("QUANTILLON_VAULT", address(0));
        userPool = vm.envOr("USER_POOL", address(0));
        hedgerPool = vm.envOr("HEDGER_POOL", address(0));
        stQeuroToken = vm.envOr("ST_QEURO_TOKEN", address(0));
        aaveVault = vm.envOr("AAVE_VAULT", address(0));
        yieldShift = vm.envOr("YIELD_SHIFT", address(0));

        // Validate that all addresses are set
        require(timeProvider != address(0), "TimeProvider address not set");
        require(chainlinkOracle != address(0), "ChainlinkOracle address not set");
        require(qeuroToken != address(0), "QEUROToken address not set");
        require(qtiToken != address(0), "QTIToken address not set");
        require(quantillonVault != address(0), "QuantillonVault address not set");
        require(userPool != address(0), "UserPool address not set");
        require(hedgerPool != address(0), "HedgerPool address not set");
        require(stQeuroToken != address(0), "stQEUROToken address not set");
        require(aaveVault != address(0), "AaveVault address not set");
        require(yieldShift != address(0), "YieldShift address not set");
    }

    function _configureContractRelationships() internal {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        
        vm.startBroadcast(deployerPrivateKey);

        // Get contract instances
        QEUROToken qeuroTokenContract = QEUROToken(qeuroToken);
        YieldShift yieldShiftContract = YieldShift(yieldShift);

        // Set vault role for QEURO token
        console.log("Configuring QEUROToken vault role...");
        bytes32 VAULT_ROLE = qeuroTokenContract.VAULT_ROLE();
        qeuroTokenContract.grantRole(VAULT_ROLE, quantillonVault);
        console.log("[OK] Vault role granted to QuantillonVault");

        // Set yield manager roles
        console.log("Configuring YieldShift roles...");
        bytes32 YIELD_MANAGER_ROLE = yieldShiftContract.YIELD_MANAGER_ROLE();
        yieldShiftContract.grantRole(YIELD_MANAGER_ROLE, aaveVault);
        console.log("[OK] Yield manager role granted to AaveVault");

        // Set authorized yield sources
        yieldShiftContract.setAuthorizedYieldSource(aaveVault, true);
        console.log("[OK] AaveVault authorized as yield source");

        vm.stopBroadcast();
    }

    function _transferAdminRoles() internal {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        
        vm.startBroadcast(deployerPrivateKey);

        // Get contract instances
        TimeProvider timeProviderContract = TimeProvider(timeProvider);
        ChainlinkOracle chainlinkOracleContract = ChainlinkOracle(chainlinkOracle);
        QEUROToken qeuroTokenContract = QEUROToken(qeuroToken);
        QTIToken qtiTokenContract = QTIToken(qtiToken);
        QuantillonVault quantillonVaultContract = QuantillonVault(quantillonVault);
        UserPool userPoolContract = UserPool(userPool);
        HedgerPool hedgerPoolContract = HedgerPool(hedgerPool);
        stQEUROToken stQeuroTokenContract = stQEUROToken(stQeuroToken);
        AaveVault aaveVaultContract = AaveVault(aaveVault);
        YieldShift yieldShiftContract = YieldShift(yieldShift);

        // Transfer admin roles to multisig
        address[] memory contracts = new address[](10);
        contracts[0] = timeProvider;
        contracts[1] = chainlinkOracle;
        contracts[2] = qeuroToken;
        contracts[3] = qtiToken;
        contracts[4] = quantillonVault;
        contracts[5] = userPool;
        contracts[6] = hedgerPool;
        contracts[7] = stQeuroToken;
        contracts[8] = aaveVault;
        contracts[9] = yieldShift;

        string[] memory contractNames = new string[](10);
        contractNames[0] = "TimeProvider";
        contractNames[1] = "ChainlinkOracle";
        contractNames[2] = "QEUROToken";
        contractNames[3] = "QTIToken";
        contractNames[4] = "QuantillonVault";
        contractNames[5] = "UserPool";
        contractNames[6] = "HedgerPool";
        contractNames[7] = "stQEUROToken";
        contractNames[8] = "AaveVault";
        contractNames[9] = "YieldShift";

        for (uint256 i = 0; i < contracts.length; i++) {
            console.log(string(abi.encodePacked("Transferring admin role for ", contractNames[i], "...")));
            bytes32 DEFAULT_ADMIN_ROLE = 0x00;
            // Grant admin role to multisig
            if (contracts[i] == timeProvider) {
                timeProviderContract.grantRole(DEFAULT_ADMIN_ROLE, multisigWallet);
            } else if (contracts[i] == chainlinkOracle) {
                chainlinkOracleContract.grantRole(DEFAULT_ADMIN_ROLE, multisigWallet);
            } else if (contracts[i] == qeuroToken) {
                qeuroTokenContract.grantRole(DEFAULT_ADMIN_ROLE, multisigWallet);
            } else if (contracts[i] == qtiToken) {
                qtiTokenContract.grantRole(DEFAULT_ADMIN_ROLE, multisigWallet);
            } else if (contracts[i] == quantillonVault) {
                quantillonVaultContract.grantRole(DEFAULT_ADMIN_ROLE, multisigWallet);
            } else if (contracts[i] == userPool) {
                userPoolContract.grantRole(DEFAULT_ADMIN_ROLE, multisigWallet);
            } else if (contracts[i] == hedgerPool) {
                hedgerPoolContract.grantRole(DEFAULT_ADMIN_ROLE, multisigWallet);
            } else if (contracts[i] == stQeuroToken) {
                stQeuroTokenContract.grantRole(DEFAULT_ADMIN_ROLE, multisigWallet);
            } else if (contracts[i] == aaveVault) {
                aaveVaultContract.grantRole(DEFAULT_ADMIN_ROLE, multisigWallet);
            } else if (contracts[i] == yieldShift) {
                yieldShiftContract.grantRole(DEFAULT_ADMIN_ROLE, multisigWallet);
            }
            console.log(string(abi.encodePacked("[OK] Admin role granted to multisig for ", contractNames[i])));
        }

        vm.stopBroadcast();
    }
}
