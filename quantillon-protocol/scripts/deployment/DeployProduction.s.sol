// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// Import OpenZeppelin proxy contracts
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

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
 * @title DeployProduction
 * @notice Production deployment script for Quantillon Protocol
 * @dev Combines UUPS upgradeability with multisig governance for maximum security and flexibility
 * 
 * Features:
 * - UUPS proxy pattern for upgradeability
 * - Multisig wallet as admin for enhanced security
 * - Network-specific oracle configuration
 * - Comprehensive initialization
 * - Production-ready security measures
 */
contract DeployProduction is Script {
    // Implementation addresses
    address public timeProviderImpl;
    address public chainlinkOracleImpl;
    address public qeuroTokenImpl;
    address public qtiTokenImpl;
    address public quantillonVaultImpl;
    address public userPoolImpl;
    address public hedgerPoolImpl;
    address public stQeuroTokenImpl;
    address public aaveVaultImpl;
    address public yieldShiftImpl;

    // Proxy addresses (these are the addresses users will interact with)
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

    // Configuration
    address public multisigWallet;
    address public deployer;
    string public network;

    // Network-specific addresses (set via environment variables)
    address public eurUsdFeed;
    address public usdcUsdFeed;
    address public usdcToken;
    address public aavePool;
    address public rewardsController;

    function run() external {
        // Get configuration from environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);
        multisigWallet = vm.envAddress("MULTISIG_WALLET");
        network = vm.envOr("NETWORK", string("localhost"));
        
        console.log("=== QUANTILLON PROTOCOL PRODUCTION DEPLOYMENT ===");
        console.log("Network:", network);
        console.log("Deploying with account:", deployer);
        console.log("Multisig wallet:", multisigWallet);
        console.log("Account balance:", deployer.balance / 1e18, "ETH");

        // Load network-specific configuration
        _loadNetworkConfig();

        vm.startBroadcast(deployerPrivateKey);

        // Phase 1: Deploy Implementation Contracts
        _deployImplementations();

        // Phase 2: Deploy UUPS Proxies
        _deployProxies();

        // Phase 3: Initialize Contracts
        _initializeContracts();

        // Phase 4: Configure Multisig Governance
        _configureMultisigGovernance();

        vm.stopBroadcast();

        // Save deployment information
        _saveDeploymentInfo();
        
        console.log("\n=== PRODUCTION DEPLOYMENT COMPLETED SUCCESSFULLY ===");
        console.log("All contracts deployed as UUPS proxies with multisig governance");
        console.log("Proxy addresses (use these in your dApp):");
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
    }

    function _loadNetworkConfig() internal {
        if (keccak256(abi.encodePacked(network)) == keccak256(abi.encodePacked("localhost"))) {
            // Mock addresses for localhost (for testing production script locally)
            eurUsdFeed = 0x1234567890123456789012345678901234567890;
            usdcUsdFeed = 0x2345678901234567890123456789012345678901;
            usdcToken = 0x3456789012345678901234567890123456789012;
            aavePool = 0x4567890123456789012345678901234567890123;
            rewardsController = address(0);
        } else {
            // Load from environment variables for real networks (mainnet, testnet)
            eurUsdFeed = vm.envAddress(string(abi.encodePacked("EUR_USD_FEED_", _toUpperCase(network))));
            usdcUsdFeed = vm.envAddress(string(abi.encodePacked("USDC_USD_FEED_", _toUpperCase(network))));
            usdcToken = vm.envAddress(string(abi.encodePacked("USDC_TOKEN_", _toUpperCase(network))));
            aavePool = vm.envAddress(string(abi.encodePacked("AAVE_POOL_", _toUpperCase(network))));
            rewardsController = vm.envOr(string(abi.encodePacked("REWARDS_CONTROLLER_", _toUpperCase(network))), address(0));
        }
        
        console.log("Network configuration loaded for:", network);
        console.log("EUR/USD Feed:", eurUsdFeed);
        console.log("USDC/USD Feed:", usdcUsdFeed);
        console.log("USDC Token:", usdcToken);
        console.log("Aave Pool:", aavePool);
    }

    function _deployImplementations() internal {
        console.log("\n=== PHASE 1: DEPLOY IMPLEMENTATIONS ===");
        
        // Deploy TimeProvider implementation
        console.log("Deploying TimeProvider implementation...");
        timeProviderImpl = address(new TimeProvider());
        console.log("TimeProvider implementation:", timeProviderImpl);

        // Deploy ChainlinkOracle implementation
        console.log("Deploying ChainlinkOracle implementation...");
        chainlinkOracleImpl = address(new ChainlinkOracle(TimeProvider(timeProviderImpl)));
        console.log("ChainlinkOracle implementation:", chainlinkOracleImpl);

        // Deploy QEUROToken implementation
        console.log("Deploying QEUROToken implementation...");
        qeuroTokenImpl = address(new QEUROToken());
        console.log("QEUROToken implementation:", qeuroTokenImpl);

        // Deploy QTIToken implementation
        console.log("Deploying QTIToken implementation...");
        qtiTokenImpl = address(new QTIToken(TimeProvider(timeProviderImpl)));
        console.log("QTIToken implementation:", qtiTokenImpl);

        // Deploy QuantillonVault implementation
        console.log("Deploying QuantillonVault implementation...");
        quantillonVaultImpl = address(new QuantillonVault());
        console.log("QuantillonVault implementation:", quantillonVaultImpl);

        // Deploy UserPool implementation
        console.log("Deploying UserPool implementation...");
        userPoolImpl = address(new UserPool(TimeProvider(timeProviderImpl)));
        console.log("UserPool implementation:", userPoolImpl);

        // Deploy HedgerPool implementation
        console.log("Deploying HedgerPool implementation...");
        hedgerPoolImpl = address(new HedgerPool(TimeProvider(timeProviderImpl)));
        console.log("HedgerPool implementation:", hedgerPoolImpl);

        // Deploy stQEUROToken implementation
        console.log("Deploying stQEUROToken implementation...");
        stQeuroTokenImpl = address(new stQEUROToken(TimeProvider(timeProviderImpl)));
        console.log("stQEUROToken implementation:", stQeuroTokenImpl);

        // Deploy AaveVault implementation
        console.log("Deploying AaveVault implementation...");
        aaveVaultImpl = address(new AaveVault());
        console.log("AaveVault implementation:", aaveVaultImpl);

        // Deploy YieldShift implementation
        console.log("Deploying YieldShift implementation...");
        yieldShiftImpl = address(new YieldShift(TimeProvider(timeProviderImpl)));
        console.log("YieldShift implementation:", yieldShiftImpl);
    }

    function _deployProxies() internal {
        console.log("\n=== PHASE 2: DEPLOY UUPS PROXIES ===");
        
        // Deploy TimeProvider proxy
        console.log("Deploying TimeProvider proxy...");
        bytes memory timeProviderInitData = abi.encodeWithSelector(
            TimeProvider.initialize.selector,
            multisigWallet, // admin
            multisigWallet, // governance
            multisigWallet  // emergency
        );
        timeProvider = address(new ERC1967Proxy(timeProviderImpl, timeProviderInitData));
        console.log("TimeProvider proxy:", timeProvider);

        // Deploy ChainlinkOracle proxy
        console.log("Deploying ChainlinkOracle proxy...");
        bytes memory chainlinkOracleInitData = abi.encodeWithSelector(
            ChainlinkOracle.initialize.selector,
            multisigWallet, // admin
            eurUsdFeed,
            usdcUsdFeed,
            multisigWallet  // treasury
        );
        chainlinkOracle = address(new ERC1967Proxy(chainlinkOracleImpl, chainlinkOracleInitData));
        console.log("ChainlinkOracle proxy:", chainlinkOracle);

        // Deploy QEUROToken proxy
        console.log("Deploying QEUROToken proxy...");
        bytes memory qeuroTokenInitData = abi.encodeWithSelector(
            QEUROToken.initialize.selector,
            multisigWallet, // admin
            quantillonVault, // vault (will be set after vault deployment)
            multisigWallet, // timelock
            multisigWallet  // treasury
        );
        qeuroToken = address(new ERC1967Proxy(qeuroTokenImpl, qeuroTokenInitData));
        console.log("QEUROToken proxy:", qeuroToken);

        // Deploy QTIToken proxy
        console.log("Deploying QTIToken proxy...");
        bytes memory qtiTokenInitData = abi.encodeWithSelector(
            QTIToken.initialize.selector,
            multisigWallet, // admin
            multisigWallet, // treasury
            multisigWallet  // timelock
        );
        qtiToken = address(new ERC1967Proxy(qtiTokenImpl, qtiTokenInitData));
        console.log("QTIToken proxy:", qtiToken);

        // Deploy QuantillonVault proxy
        console.log("Deploying QuantillonVault proxy...");
        bytes memory quantillonVaultInitData = abi.encodeWithSelector(
            QuantillonVault.initialize.selector,
            multisigWallet, // admin
            qeuroToken,
            usdcToken,
            chainlinkOracle,
            multisigWallet  // timelock
        );
        quantillonVault = address(new ERC1967Proxy(quantillonVaultImpl, quantillonVaultInitData));
        console.log("QuantillonVault proxy:", quantillonVault);

        // Deploy UserPool proxy
        console.log("Deploying UserPool proxy...");
        bytes memory userPoolInitData = abi.encodeWithSelector(
            UserPool.initialize.selector,
            multisigWallet, // admin
            quantillonVault,
            yieldShift, // will be set after yieldShift deployment
            multisigWallet, // timelock
            multisigWallet  // treasury
        );
        userPool = address(new ERC1967Proxy(userPoolImpl, userPoolInitData));
        console.log("UserPool proxy:", userPool);

        // Deploy HedgerPool proxy
        console.log("Deploying HedgerPool proxy...");
        bytes memory hedgerPoolInitData = abi.encodeWithSelector(
            HedgerPool.initialize.selector,
            multisigWallet, // admin
            quantillonVault,
            chainlinkOracle,
            yieldShift, // will be set after yieldShift deployment
            multisigWallet, // timelock
            multisigWallet  // treasury
        );
        hedgerPool = address(new ERC1967Proxy(hedgerPoolImpl, hedgerPoolInitData));
        console.log("HedgerPool proxy:", hedgerPool);

        // Deploy stQEUROToken proxy
        console.log("Deploying stQEUROToken proxy...");
        bytes memory stQeuroTokenInitData = abi.encodeWithSelector(
            stQEUROToken.initialize.selector,
            multisigWallet, // admin
            qeuroToken,
            yieldShift, // will be set after yieldShift deployment
            usdcToken,
            multisigWallet, // treasury
            multisigWallet  // timelock
        );
        stQeuroToken = address(new ERC1967Proxy(stQeuroTokenImpl, stQeuroTokenInitData));
        console.log("stQEUROToken proxy:", stQeuroToken);

        // Deploy AaveVault proxy
        console.log("Deploying AaveVault proxy...");
        bytes memory aaveVaultInitData = abi.encodeWithSelector(
            AaveVault.initialize.selector,
            multisigWallet, // admin
            aavePool,
            usdcToken,
            rewardsController,
            yieldShift, // will be set after yieldShift deployment
            multisigWallet, // timelock
            multisigWallet  // treasury
        );
        aaveVault = address(new ERC1967Proxy(aaveVaultImpl, aaveVaultInitData));
        console.log("AaveVault proxy:", aaveVault);

        // Deploy YieldShift proxy
        console.log("Deploying YieldShift proxy...");
        bytes memory yieldShiftInitData = abi.encodeWithSelector(
            YieldShift.initialize.selector,
            multisigWallet, // admin
            userPool,
            hedgerPool,
            aaveVault,
            stQeuroToken,
            multisigWallet, // timelock
            multisigWallet  // treasury
        );
        yieldShift = address(new ERC1967Proxy(yieldShiftImpl, yieldShiftInitData));
        console.log("YieldShift proxy:", yieldShift);
    }

    function _initializeContracts() internal {
        console.log("\n=== PHASE 3: INITIALIZE CONTRACTS ===");
        
        // All contracts are initialized during proxy deployment
        // Additional configuration will be done through multisig governance
        console.log("All contracts initialized successfully during proxy deployment");
    }

    function _configureMultisigGovernance() internal {
        console.log("\n=== PHASE 4: CONFIGURE MULTISIG GOVERNANCE ===");
        
        // Grant minter role to QuantillonVault
        console.log("Granting minter role to QuantillonVault...");
        bytes32 MINTER_ROLE = QEUROToken(qeuroToken).MINTER_ROLE();
        QEUROToken(qeuroToken).grantRole(MINTER_ROLE, quantillonVault);
        
        // Grant yield manager role to AaveVault
        console.log("Granting yield manager role to AaveVault...");
        bytes32 YIELD_MANAGER_ROLE = YieldShift(yieldShift).YIELD_MANAGER_ROLE();
        YieldShift(yieldShift).grantRole(YIELD_MANAGER_ROLE, aaveVault);
        
        console.log("Multisig governance configured successfully");
        console.log("Note: All contracts are initialized with multisig as admin");
        console.log("Implementation contracts can be upgraded through multisig governance");
    }

    function _saveDeploymentInfo() internal {
        // Build deployment info in smaller chunks to avoid stack too deep
        string memory header = string(abi.encodePacked(
            '{\n',
            '  "network": "', network, '",\n',
            '  "deploymentType": "production",\n',
            '  "timestamp": "', vm.toString(block.timestamp), '",\n',
            '  "deployer": "', vm.toString(deployer), '",\n',
            '  "multisigWallet": "', vm.toString(multisigWallet), '",\n',
            '  "implementations": {\n'
        ));

        string memory implementations = string(abi.encodePacked(
            '    "TimeProvider": "', vm.toString(timeProviderImpl), '",\n',
            '    "ChainlinkOracle": "', vm.toString(chainlinkOracleImpl), '",\n',
            '    "QEUROToken": "', vm.toString(qeuroTokenImpl), '",\n',
            '    "QTIToken": "', vm.toString(qtiTokenImpl), '",\n',
            '    "QuantillonVault": "', vm.toString(quantillonVaultImpl), '",\n'
        ));

        string memory implementations2 = string(abi.encodePacked(
            '    "UserPool": "', vm.toString(userPoolImpl), '",\n',
            '    "HedgerPool": "', vm.toString(hedgerPoolImpl), '",\n',
            '    "stQEUROToken": "', vm.toString(stQeuroTokenImpl), '",\n',
            '    "AaveVault": "', vm.toString(aaveVaultImpl), '",\n',
            '    "YieldShift": "', vm.toString(yieldShiftImpl), '"\n'
        ));

        string memory proxies = string(abi.encodePacked(
            '  },\n',
            '  "proxies": {\n',
            '    "TimeProvider": "', vm.toString(timeProvider), '",\n',
            '    "ChainlinkOracle": "', vm.toString(chainlinkOracle), '",\n',
            '    "QEUROToken": "', vm.toString(qeuroToken), '",\n',
            '    "QTIToken": "', vm.toString(qtiToken), '",\n',
            '    "QuantillonVault": "', vm.toString(quantillonVault), '",\n'
        ));

        string memory proxies2 = string(abi.encodePacked(
            '    "UserPool": "', vm.toString(userPool), '",\n',
            '    "HedgerPool": "', vm.toString(hedgerPool), '",\n',
            '    "stQEUROToken": "', vm.toString(stQeuroToken), '",\n',
            '    "AaveVault": "', vm.toString(aaveVault), '",\n',
            '    "YieldShift": "', vm.toString(yieldShift), '"\n'
        ));

        string memory footer = string(abi.encodePacked(
            '  },\n',
            '  "networkAddresses": {\n',
            '    "EUR_USD_FEED": "', vm.toString(eurUsdFeed), '",\n',
            '    "USDC_USD_FEED": "', vm.toString(usdcUsdFeed), '",\n',
            '    "USDC_TOKEN": "', vm.toString(usdcToken), '",\n',
            '    "AAVE_POOL": "', vm.toString(aavePool), '",\n',
            '    "REWARDS_CONTROLLER": "', vm.toString(rewardsController), '"\n',
            '  }\n',
            '}'
        ));

        string memory deploymentInfo = string(abi.encodePacked(header, implementations, implementations2, proxies, proxies2, footer));
        
        string memory filename = string(abi.encodePacked("deployments/production-", network, ".json"));
        vm.writeFile(filename, deploymentInfo);
    }

    function _toUpperCase(string memory str) internal pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bUpper = new bytes(bStr.length);
        for (uint i = 0; i < bStr.length; i++) {
            bUpper[i] = bStr[i] >= 0x61 && bStr[i] <= 0x7A ? bytes1(uint8(bStr[i]) - 32) : bStr[i];
        }
        return string(bUpper);
    }
}
