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
 * @title SimpleMultisigInit
 * @notice Simplified initialization script for Quantillon Protocol multisig deployment
 * @dev Initializes contracts with correct parameters and transfers admin roles to multisig
 */
contract SimpleMultisigInit is Script {
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
        
        // Load deployment addresses from environment variables
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
        
        // 1. Initialize TimeProvider (3 parameters: admin, governance, emergency)
        console.log("Initializing TimeProvider...");
        timeProviderContract.initialize(deployer, multisigWallet, multisigWallet);
        console.log("[OK] TimeProvider initialized");

        // 2. Initialize ChainlinkOracle (4 parameters: admin, eurUsdFeed, usdcUsdFeed, treasury)
        console.log("Initializing ChainlinkOracle...");
        chainlinkOracleContract.initialize(deployer, MOCK_EUR_USD_FEED, MOCK_USDC_USD_FEED, multisigWallet);
        console.log("[OK] ChainlinkOracle initialized");

        // 3. Initialize QEUROToken (4 parameters: admin, vault, timelock, treasury)
        console.log("Initializing QEUROToken...");
        qeuroTokenContract.initialize(deployer, quantillonVault, multisigWallet, multisigWallet);
        console.log("[OK] QEUROToken initialized");

        // Phase 2: Initialize Core Protocol
        console.log("\n=== PHASE 2: INITIALIZE CORE PROTOCOL ===");
        
        // 4. Initialize QTIToken (4 parameters: admin, treasury, timelock)
        console.log("Initializing QTIToken...");
        qtiTokenContract.initialize(deployer, multisigWallet, multisigWallet);
        console.log("[OK] QTIToken initialized");

        // 5. Initialize QuantillonVault (5 parameters: admin, qeuro, usdc, oracle, timelock)
        console.log("Initializing QuantillonVault...");
        quantillonVaultContract.initialize(deployer, qeuroToken, MOCK_USDC_TOKEN, chainlinkOracle, multisigWallet);
        console.log("[OK] QuantillonVault initialized");

        // Phase 3: Initialize Pool Contracts
        console.log("\n=== PHASE 3: INITIALIZE POOL CONTRACTS ===");
        
        // 6. Initialize UserPool (7 parameters: admin, qeuro, usdc, vault, yieldShift, timeProvider, oracle)
        console.log("Initializing UserPool...");
        userPoolContract.initialize(deployer, qeuroToken, MOCK_USDC_TOKEN, quantillonVault, yieldShift, timeProvider, chainlinkOracle);
        console.log("[OK] UserPool initialized");

        // 7. Initialize HedgerPool (6 parameters: admin, usdc, oracle, timeProvider, qeuro, vault)
        console.log("Initializing HedgerPool...");
        hedgerPoolContract.initialize(deployer, MOCK_USDC_TOKEN, chainlinkOracle, timeProvider, qeuroToken, quantillonVault);
        console.log("[OK] HedgerPool initialized");

        // 8. Initialize stQEUROToken (6 parameters: admin, qeuro, yieldShift, timeProvider, treasury, oracle)
        console.log("Initializing stQEUROToken...");
        stQeuroTokenContract.initialize(deployer, qeuroToken, yieldShift, timeProvider, multisigWallet, chainlinkOracle);
        console.log("[OK] stQEUROToken initialized");

        // Phase 4: Initialize Yield Management
        console.log("\n=== PHASE 4: INITIALIZE YIELD MANAGEMENT ===");
        
        // 9. Initialize AaveVault (7 parameters: admin, usdc, aaveProvider, qeuro, timeProvider, oracle, treasury)
        console.log("Initializing AaveVault...");
        aaveVaultContract.initialize(deployer, MOCK_USDC_TOKEN, MOCK_AAVE_POOL, qeuroToken, timeProvider, chainlinkOracle, multisigWallet);
        console.log("[OK] AaveVault initialized");

        // 10. Initialize YieldShift (8 parameters: admin, usdc, userPool, hedgerPool, aaveVault, stQEURO, timeProvider, oracle)
        console.log("Initializing YieldShift...");
        yieldShiftContract.initialize(deployer, MOCK_USDC_TOKEN, userPool, hedgerPool, aaveVault, stQeuroToken, timeProvider, chainlinkOracle);
        console.log("[OK] YieldShift initialized");

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
        // Load addresses from environment variables
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

        // Grant MINTER_ROLE to QuantillonVault for QEURO token
        console.log("Configuring QEUROToken minter role...");
        bytes32 MINTER_ROLE = qeuroTokenContract.MINTER_ROLE();
        qeuroTokenContract.grantRole(MINTER_ROLE, quantillonVault);
        console.log("[OK] Minter role granted to QuantillonVault");

        // Grant YIELD_MANAGER_ROLE to AaveVault for YieldShift
        console.log("Configuring YieldShift yield manager role...");
        bytes32 YIELD_MANAGER_ROLE = yieldShiftContract.YIELD_MANAGER_ROLE();
        yieldShiftContract.grantRole(YIELD_MANAGER_ROLE, aaveVault);
        console.log("[OK] Yield manager role granted to AaveVault");

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
        bytes32 DEFAULT_ADMIN_ROLE = 0x00;

        console.log("Transferring admin roles to multisig...");
        
        timeProviderContract.grantRole(DEFAULT_ADMIN_ROLE, multisigWallet);
        console.log("[OK] TimeProvider admin role granted to multisig");
        
        chainlinkOracleContract.grantRole(DEFAULT_ADMIN_ROLE, multisigWallet);
        console.log("[OK] ChainlinkOracle admin role granted to multisig");
        
        qeuroTokenContract.grantRole(DEFAULT_ADMIN_ROLE, multisigWallet);
        console.log("[OK] QEUROToken admin role granted to multisig");
        
        qtiTokenContract.grantRole(DEFAULT_ADMIN_ROLE, multisigWallet);
        console.log("[OK] QTIToken admin role granted to multisig");
        
        quantillonVaultContract.grantRole(DEFAULT_ADMIN_ROLE, multisigWallet);
        console.log("[OK] QuantillonVault admin role granted to multisig");
        
        userPoolContract.grantRole(DEFAULT_ADMIN_ROLE, multisigWallet);
        console.log("[OK] UserPool admin role granted to multisig");
        
        hedgerPoolContract.grantRole(DEFAULT_ADMIN_ROLE, multisigWallet);
        console.log("[OK] HedgerPool admin role granted to multisig");
        
        stQeuroTokenContract.grantRole(DEFAULT_ADMIN_ROLE, multisigWallet);
        console.log("[OK] stQEUROToken admin role granted to multisig");
        
        aaveVaultContract.grantRole(DEFAULT_ADMIN_ROLE, multisigWallet);
        console.log("[OK] AaveVault admin role granted to multisig");
        
        yieldShiftContract.grantRole(DEFAULT_ADMIN_ROLE, multisigWallet);
        console.log("[OK] YieldShift admin role granted to multisig");

        vm.stopBroadcast();
    }
}
