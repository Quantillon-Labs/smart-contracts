// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// Import OpenZeppelin proxy contracts
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

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
 * @title DeployUUPS
 * @notice UUPS Proxy deployment script for Quantillon Protocol
 * @dev Deploys all contracts as UUPS proxies with proper initialization
 */
contract DeployUUPS is Script {
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

    // Proxy addresses
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

    // Mock addresses for localhost
    address constant MOCK_EUR_USD_FEED = 0x1234567890123456789012345678901234567890;
    address constant MOCK_USDC_USD_FEED = 0x2345678901234567890123456789012345678901;
    address constant MOCK_USDC_TOKEN = 0x3456789012345678901234567890123456789012;
    address constant MOCK_AAVE_POOL = 0x4567890123456789012345678901234567890123;

    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== QUANTILLON PROTOCOL UUPS DEPLOYMENT ===");
        console.log("Deploying with account:", deployer);
        console.log("Account balance:", deployer.balance / 1e18, "ETH");

        vm.startBroadcast(deployerPrivateKey);

        // Phase 1: Deploy Implementations
        console.log("\n=== PHASE 1: DEPLOY IMPLEMENTATIONS ===");
        _deployImplementations();

        // Phase 2: Deploy Proxies
        console.log("\n=== PHASE 2: DEPLOY UUPS PROXIES ===");
        _deployProxies(deployer);

        vm.stopBroadcast();

        // Save deployment info
        _saveDeploymentInfo(deployer);
        
        console.log("\n=== UUPS DEPLOYMENT COMPLETED SUCCESSFULLY ===");
        console.log("All contracts deployed as UUPS proxies and ready for initialization");
        console.log("Deployment info saved to deployments/localhost.json");
    }

    function _deployImplementations() internal {
        // Deploy TimeProvider implementation
        console.log("Deploying TimeProvider implementation...");
        TimeProvider timeProviderImplContract = new TimeProvider();
        timeProviderImpl = address(timeProviderImplContract);
        console.log("TimeProvider implementation:", timeProviderImpl);

        // Deploy ChainlinkOracle implementation
        console.log("Deploying ChainlinkOracle implementation...");
        ChainlinkOracle chainlinkOracleImplContract = new ChainlinkOracle(timeProviderImplContract);
        chainlinkOracleImpl = address(chainlinkOracleImplContract);
        console.log("ChainlinkOracle implementation:", chainlinkOracleImpl);

        // Deploy QEUROToken implementation
        console.log("Deploying QEUROToken implementation...");
        QEUROToken qeuroTokenImplContract = new QEUROToken();
        qeuroTokenImpl = address(qeuroTokenImplContract);
        console.log("QEUROToken implementation:", qeuroTokenImpl);

        // Deploy QTIToken implementation
        console.log("Deploying QTIToken implementation...");
        QTIToken qtiTokenImplContract = new QTIToken(timeProviderImplContract);
        qtiTokenImpl = address(qtiTokenImplContract);
        console.log("QTIToken implementation:", qtiTokenImpl);

        // Deploy QuantillonVault implementation
        console.log("Deploying QuantillonVault implementation...");
        QuantillonVault quantillonVaultImplContract = new QuantillonVault();
        quantillonVaultImpl = address(quantillonVaultImplContract);
        console.log("QuantillonVault implementation:", quantillonVaultImpl);

        // Deploy UserPool implementation
        console.log("Deploying UserPool implementation...");
        UserPool userPoolImplContract = new UserPool(timeProviderImplContract);
        userPoolImpl = address(userPoolImplContract);
        console.log("UserPool implementation:", userPoolImpl);

        // Deploy HedgerPool implementation
        console.log("Deploying HedgerPool implementation...");
        HedgerPool hedgerPoolImplContract = new HedgerPool(timeProviderImplContract);
        hedgerPoolImpl = address(hedgerPoolImplContract);
        console.log("HedgerPool implementation:", hedgerPoolImpl);

        // Deploy stQEUROToken implementation
        console.log("Deploying stQEUROToken implementation...");
        stQEUROToken stQeuroTokenImplContract = new stQEUROToken(timeProviderImplContract);
        stQeuroTokenImpl = address(stQeuroTokenImplContract);
        console.log("stQEUROToken implementation:", stQeuroTokenImpl);

        // Deploy AaveVault implementation
        console.log("Deploying AaveVault implementation...");
        AaveVault aaveVaultImplContract = new AaveVault();
        aaveVaultImpl = address(aaveVaultImplContract);
        console.log("AaveVault implementation:", aaveVaultImpl);

        // Deploy YieldShift implementation
        console.log("Deploying YieldShift implementation...");
        YieldShift yieldShiftImplContract = new YieldShift(timeProviderImplContract);
        yieldShiftImpl = address(yieldShiftImplContract);
        console.log("YieldShift implementation:", yieldShiftImpl);
    }

    function _deployProxies(address deployer) internal {
        // Deploy TimeProvider proxy
        console.log("Deploying TimeProvider proxy...");
        bytes memory timeProviderInitData = abi.encodeWithSelector(
            TimeProvider.initialize.selector,
            deployer, // admin
            deployer, // governance
            deployer  // emergency
        );
        ERC1967Proxy timeProviderProxy = new ERC1967Proxy(timeProviderImpl, timeProviderInitData);
        timeProvider = address(timeProviderProxy);
        console.log("TimeProvider proxy:", timeProvider);

        // Deploy ChainlinkOracle proxy
        console.log("Deploying ChainlinkOracle proxy...");
        bytes memory chainlinkOracleInitData = abi.encodeWithSelector(
            ChainlinkOracle.initialize.selector,
            deployer, // admin
            MOCK_EUR_USD_FEED,
            MOCK_USDC_USD_FEED,
            deployer  // treasury
        );
        ERC1967Proxy chainlinkOracleProxy = new ERC1967Proxy(chainlinkOracleImpl, chainlinkOracleInitData);
        chainlinkOracle = address(chainlinkOracleProxy);
        console.log("ChainlinkOracle proxy:", chainlinkOracle);

        // Deploy QEUROToken proxy
        console.log("Deploying QEUROToken proxy...");
        bytes memory qeuroTokenInitData = abi.encodeWithSelector(
            QEUROToken.initialize.selector,
            deployer, // admin
            address(0), // vault (will be set later)
            deployer, // timelock
            deployer  // treasury
        );
        ERC1967Proxy qeuroTokenProxy = new ERC1967Proxy(qeuroTokenImpl, qeuroTokenInitData);
        qeuroToken = address(qeuroTokenProxy);
        console.log("QEUROToken proxy:", qeuroToken);

        // Deploy QTIToken proxy
        console.log("Deploying QTIToken proxy...");
        bytes memory qtiTokenInitData = abi.encodeWithSelector(
            QTIToken.initialize.selector,
            deployer, // admin
            deployer, // treasury
            deployer  // timelock
        );
        ERC1967Proxy qtiTokenProxy = new ERC1967Proxy(qtiTokenImpl, qtiTokenInitData);
        qtiToken = address(qtiTokenProxy);
        console.log("QTIToken proxy:", qtiToken);

        // Deploy QuantillonVault proxy
        console.log("Deploying QuantillonVault proxy...");
        bytes memory quantillonVaultInitData = abi.encodeWithSelector(
            QuantillonVault.initialize.selector,
            deployer, // admin
            qeuroToken,
            MOCK_USDC_TOKEN,
            chainlinkOracle,
            deployer  // timelock
        );
        ERC1967Proxy quantillonVaultProxy = new ERC1967Proxy(quantillonVaultImpl, quantillonVaultInitData);
        quantillonVault = address(quantillonVaultProxy);
        console.log("QuantillonVault proxy:", quantillonVault);

        // Deploy UserPool proxy
        console.log("Deploying UserPool proxy...");
        bytes memory userPoolInitData = abi.encodeWithSelector(
            UserPool.initialize.selector,
            deployer, // admin
            qeuroToken,
            MOCK_USDC_TOKEN,
            quantillonVault,
            address(0), // yieldShift (will be set later)
            deployer, // timelock
            deployer  // treasury
        );
        ERC1967Proxy userPoolProxy = new ERC1967Proxy(userPoolImpl, userPoolInitData);
        userPool = address(userPoolProxy);
        console.log("UserPool proxy:", userPool);

        // Deploy HedgerPool proxy
        console.log("Deploying HedgerPool proxy...");
        bytes memory hedgerPoolInitData = abi.encodeWithSelector(
            HedgerPool.initialize.selector,
            deployer, // admin
            MOCK_USDC_TOKEN,
            chainlinkOracle,
            address(0), // yieldShift (will be set later)
            deployer, // timelock
            deployer  // treasury
        );
        ERC1967Proxy hedgerPoolProxy = new ERC1967Proxy(hedgerPoolImpl, hedgerPoolInitData);
        hedgerPool = address(hedgerPoolProxy);
        console.log("HedgerPool proxy:", hedgerPool);

        // Deploy stQEUROToken proxy
        console.log("Deploying stQEUROToken proxy...");
        bytes memory stQeuroTokenInitData = abi.encodeWithSelector(
            stQEUROToken.initialize.selector,
            deployer, // admin
            qeuroToken,
            address(0), // yieldShift (will be set later)
            MOCK_USDC_TOKEN,
            deployer, // treasury
            deployer  // timelock
        );
        ERC1967Proxy stQeuroTokenProxy = new ERC1967Proxy(stQeuroTokenImpl, stQeuroTokenInitData);
        stQeuroToken = address(stQeuroTokenProxy);
        console.log("stQEUROToken proxy:", stQeuroToken);

        // Deploy AaveVault proxy
        console.log("Deploying AaveVault proxy...");
        bytes memory aaveVaultInitData = abi.encodeWithSelector(
            AaveVault.initialize.selector,
            deployer, // admin
            MOCK_USDC_TOKEN,
            MOCK_AAVE_POOL,
            address(0), // rewardsController (mock)
            address(0), // yieldShift (will be set later)
            deployer, // timelock
            deployer  // treasury
        );
        ERC1967Proxy aaveVaultProxy = new ERC1967Proxy(aaveVaultImpl, aaveVaultInitData);
        aaveVault = address(aaveVaultProxy);
        console.log("AaveVault proxy:", aaveVault);

        // Deploy YieldShift proxy
        console.log("Deploying YieldShift proxy...");
        bytes memory yieldShiftInitData = abi.encodeWithSelector(
            YieldShift.initialize.selector,
            deployer, // admin
            MOCK_USDC_TOKEN,
            userPool,
            hedgerPool,
            aaveVault,
            stQeuroToken,
            deployer, // timelock
            deployer  // treasury
        );
        ERC1967Proxy yieldShiftProxy = new ERC1967Proxy(yieldShiftImpl, yieldShiftInitData);
        yieldShift = address(yieldShiftProxy);
        console.log("YieldShift proxy:", yieldShift);
    }

    function _saveDeploymentInfo(address deployer) internal {
        string memory deploymentInfo = string(abi.encodePacked(
            '{\n',
            '  "network": "localhost",\n',
            '  "timestamp": "', vm.toString(block.timestamp), '",\n',
            '  "deployer": "', vm.toString(deployer), '",\n',
            '  "deploymentType": "UUPS",\n',
            '  "implementations": {\n',
            '    "TimeProvider": "', vm.toString(timeProviderImpl), '",\n',
            '    "ChainlinkOracle": "', vm.toString(chainlinkOracleImpl), '",\n',
            '    "QEUROToken": "', vm.toString(qeuroTokenImpl), '",\n',
            '    "QTIToken": "', vm.toString(qtiTokenImpl), '",\n',
            '    "QuantillonVault": "', vm.toString(quantillonVaultImpl), '",\n',
            '    "UserPool": "', vm.toString(userPoolImpl), '",\n',
            '    "HedgerPool": "', vm.toString(hedgerPoolImpl), '",\n',
            '    "stQEUROToken": "', vm.toString(stQeuroTokenImpl), '",\n',
            '    "AaveVault": "', vm.toString(aaveVaultImpl), '",\n',
            '    "YieldShift": "', vm.toString(yieldShiftImpl), '"\n',
            '  },\n',
            '  "proxies": {\n',
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

        vm.writeFile("deployments/localhost.json", deploymentInfo);
    }
}
