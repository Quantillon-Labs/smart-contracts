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
import "../../src/mocks/MockUSDC.sol";

/**
 * @title DeployQuantillon
 * @notice Complete deployment script for Quantillon Protocol
 * @dev Deploys all contracts in the correct order with proper dependencies
 */
contract DeployQuantillon is Script {
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
    address public mockUSDC;

    // Contract instances (to avoid stack too deep)
    TimeProvider public timeProviderContract;
    ChainlinkOracle public chainlinkOracleContract;
    QEUROToken public qeuroTokenContract;
    QTIToken public qtiTokenContract;
    QuantillonVault public quantillonVaultContract;
    UserPool public userPoolContract;
    HedgerPool public hedgerPoolContract;
    stQEUROToken public stQeuroTokenContract;
    AaveVault public aaveVaultContract;
    YieldShift public yieldShiftContract;
    MockUSDC public mockUSDCContract;

    // Network configuration
    string public network;
    bool public isLocalhost;
    bool public isBaseSepolia;
    
    // Mock addresses for localhost (replace with real addresses for testnet/mainnet)
    address constant MOCK_EUR_USD_FEED = 0x1234567890123456789012345678901234567890;
    address constant MOCK_USDC_USD_FEED = 0x2345678901234567890123456789012345678901;
    address constant MOCK_AAVE_POOL = 0x4567890123456789012345678901234567890123;
    
    // Base Sepolia addresses (real addresses for testnet)
    // Note: These are placeholder addresses - update with actual Base Sepolia addresses
    address constant BASE_SEPOLIA_EUR_USD_FEED = 0x0000000000000000000000000000000000000001; // EUR/USD on Base Sepolia
    address constant BASE_SEPOLIA_USDC_USD_FEED = 0x0000000000000000000000000000000000000002; // USDC/USD on Base Sepolia
    address constant BASE_SEPOLIA_USDC_TOKEN = 0x0000000000000000000000000000000000000003; // USDC on Base Sepolia
    address constant BASE_SEPOLIA_AAVE_POOL = 0x0000000000000000000000000000000000000004; // Aave Pool on Base Sepolia

    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(deployerPrivateKey);
        
        // Detect network
        _detectNetwork();
        
        console.log("=== QUANTILLON PROTOCOL DEPLOYMENT ===");
        console.log("Network:", network);
        console.log("Deploying with account:", deployer);
        console.log("Account balance:", deployer.balance / 1e18, "ETH");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy MockUSDC first if needed (localhost or Base Sepolia)
        if (isLocalhost || isBaseSepolia) {
            _deployMockUSDC();
        }

        // Deploy all contracts in phases
        _deployPhase1();
        _deployPhase2();
        _deployPhase3();
        _deployPhase4();

        vm.stopBroadcast();
        
        console.log("\n=== DEPLOYMENT COMPLETED SUCCESSFULLY ===");
        console.log("All contracts deployed and ready for initialization");
        console.log("Deployment addresses:");
        if (isLocalhost || isBaseSepolia) {
            console.log("MockUSDC:", mockUSDC);
        }
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

    function _detectNetwork() internal {
        uint256 chainId = block.chainid;
        
        if (chainId == 31337) {
            network = "localhost";
            isLocalhost = true;
            isBaseSepolia = false;
        } else if (chainId == 84532) {
            network = "base-sepolia";
            isLocalhost = false;
            isBaseSepolia = true;
        } else {
            network = "unknown";
            isLocalhost = false;
            isBaseSepolia = false;
        }
        
        console.log("Detected chain ID:", chainId);
        console.log("Network:", network);
    }

    function _deployMockUSDC() internal {
        console.log("\n=== DEPLOYING MOCK USDC ===");
        
        console.log("Deploying MockUSDC...");
        mockUSDCContract = new MockUSDC();
        mockUSDC = address(mockUSDCContract);
        console.log("MockUSDC deployed to:", mockUSDC);
        console.log("MockUSDC name:", mockUSDCContract.name());
        console.log("MockUSDC symbol:", mockUSDCContract.symbol());
        console.log("MockUSDC decimals:", mockUSDCContract.decimals());
        
        // Mint some USDC to deployer for testing
        uint256 mintAmount = 1000000 * 10**6; // 1M USDC
        mockUSDCContract.mint(msg.sender, mintAmount);
        console.log("Minted", mintAmount / 10**6, "USDC to deployer");
    }

    function _getUSDCAddress() internal view returns (address) {
        if (isLocalhost) {
            return mockUSDC;
        } else if (isBaseSepolia) {
            return BASE_SEPOLIA_USDC_TOKEN;
        } else {
            return address(0); // fallback - no USDC available
        }
    }

    function _getEURUSDFeed() internal view returns (address) {
        if (isLocalhost) {
            return MOCK_EUR_USD_FEED;
        } else if (isBaseSepolia) {
            return BASE_SEPOLIA_EUR_USD_FEED;
        } else {
            return MOCK_EUR_USD_FEED; // fallback
        }
    }

    function _getUSDCUSDFeed() internal view returns (address) {
        if (isLocalhost) {
            return MOCK_USDC_USD_FEED;
        } else if (isBaseSepolia) {
            return BASE_SEPOLIA_USDC_USD_FEED;
        } else {
            return MOCK_USDC_USD_FEED; // fallback
        }
    }

    function _getAavePool() internal view returns (address) {
        if (isLocalhost) {
            return MOCK_AAVE_POOL;
        } else if (isBaseSepolia) {
            return BASE_SEPOLIA_AAVE_POOL;
        } else {
            return MOCK_AAVE_POOL; // fallback
        }
    }

    function _deployPhase1() internal {
        console.log("\n=== PHASE 1: CORE INFRASTRUCTURE ===");
        
        // 1. Deploy TimeProvider (required by most contracts)
        console.log("Deploying TimeProvider...");
        timeProviderContract = new TimeProvider();
        timeProvider = address(timeProviderContract);
        console.log("TimeProvider deployed to:", timeProvider);

        // 2. Deploy ChainlinkOracle
        console.log("Deploying ChainlinkOracle...");
        chainlinkOracleContract = new ChainlinkOracle(timeProviderContract);
        chainlinkOracle = address(chainlinkOracleContract);
        console.log("ChainlinkOracle deployed to:", chainlinkOracle);
        console.log("Using EUR/USD feed:", _getEURUSDFeed());
        console.log("Using USDC/USD feed:", _getUSDCUSDFeed());

        // 3. Deploy QEUROToken
        console.log("Deploying QEUROToken...");
        qeuroTokenContract = new QEUROToken();
        qeuroToken = address(qeuroTokenContract);
        console.log("QEUROToken deployed to:", qeuroToken);
    }

    function _deployPhase2() internal {
        console.log("\n=== PHASE 2: CORE PROTOCOL ===");
        
        // 4. Deploy QTIToken
        console.log("Deploying QTIToken...");
        qtiTokenContract = new QTIToken(timeProviderContract);
        qtiToken = address(qtiTokenContract);
        console.log("QTIToken deployed to:", qtiToken);

        // 5. Deploy QuantillonVault
        console.log("Deploying QuantillonVault...");
        quantillonVaultContract = new QuantillonVault();
        quantillonVault = address(quantillonVaultContract);
        console.log("QuantillonVault deployed to:", quantillonVault);
    }

    function _deployPhase3() internal {
        console.log("\n=== PHASE 3: POOL CONTRACTS ===");
        
        // 6. Deploy UserPool
        console.log("Deploying UserPool...");
        userPoolContract = new UserPool(timeProviderContract);
        userPool = address(userPoolContract);
        console.log("UserPool deployed to:", userPool);

        // 7. Deploy HedgerPool
        console.log("Deploying HedgerPool...");
        hedgerPoolContract = new HedgerPool(timeProviderContract);
        hedgerPool = address(hedgerPoolContract);
        console.log("HedgerPool deployed to:", hedgerPool);

        // 8. Deploy stQEUROToken
        console.log("Deploying stQEUROToken...");
        stQeuroTokenContract = new stQEUROToken(timeProviderContract);
        stQeuroToken = address(stQeuroTokenContract);
        console.log("stQEUROToken deployed to:", stQeuroToken);
    }

    function _deployPhase4() internal {
        console.log("\n=== PHASE 4: YIELD MANAGEMENT ===");
        
        // 9. Deploy AaveVault
        console.log("Deploying AaveVault...");
        aaveVaultContract = new AaveVault();
        aaveVault = address(aaveVaultContract);
        console.log("AaveVault deployed to:", aaveVault);
        console.log("Using USDC address:", _getUSDCAddress());
        console.log("Using Aave pool:", _getAavePool());

        // 10. Deploy YieldShift
        console.log("Deploying YieldShift...");
        yieldShiftContract = new YieldShift(timeProviderContract);
        yieldShift = address(yieldShiftContract);
        console.log("YieldShift deployed to:", yieldShift);

        // 11. Copy ABIs to frontend
        copyABIsToFrontend();
    }

    function copyABIsToFrontend() internal {
        console.log("Copying ABIs to frontend...");
        console.log("Please run './scripts/copy-abis.sh' manually to copy ABIs to frontend");
        console.log("This ensures the frontend has the latest contract interfaces.");
    }

}
