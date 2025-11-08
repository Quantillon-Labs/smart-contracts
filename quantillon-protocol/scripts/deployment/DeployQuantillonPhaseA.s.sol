// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../../src/libraries/TimeProviderLibrary.sol";
import "../../src/oracle/ChainlinkOracle.sol";
import "../../src/mocks/MockChainlinkOracle.sol";
import "../../src/core/QEUROToken.sol";
import "../../src/core/QuantillonVault.sol";
import "../../src/core/FeeCollector.sol";
import "../../test/ChainlinkOracle.t.sol";
import "./DeploymentHelpers.sol";

contract DeployQuantillonPhaseA is Script {
    TimeProvider public timeProvider;
    ChainlinkOracle public chainlinkOracle;
    QEUROToken public qeuroToken;
    QuantillonVault public quantillonVault;
    FeeCollector public feeCollector;

    address public deployerEOA;
    address public usdc;
    address public eurUsdFeed;
    address public usdcUsdFeed;
    bool public isLocalhost;
    bool public isBaseSepolia;
    bool public isEthereumSepolia;

    // Oracle feed addresses (Phase A specific)
    // Base Sepolia
    address constant BASE_SEPOLIA_EUR_USD_FEED = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165; //TO UPDATE
    address constant BASE_SEPOLIA_USDC_USD_FEED = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;
    address constant BASE_SEPOLIA_USDC_TOKEN = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    
    // Base Mainnet
    address constant BASE_MAINNET_EUR_USD_FEED = 0xc91D87E81faB8f93699ECf7Ee9B44D11e1D53F0F; // Chainlink EUR/USD on Base
    address constant BASE_MAINNET_USDC_USD_FEED = 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B; // Chainlink USDC/USD on Base
    address constant BASE_MAINNET_USDC_TOKEN = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    
    // Ethereum Sepolia addresses
    address constant ETHEREUM_SEPOLIA_EUR_USD_FEED = 0x1a81afB8146aeFfCFc5E50e8479e826E7D55b910;
    address constant ETHEREUM_SEPOLIA_USDC_USD_FEED = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E;
    address constant ETHEREUM_SEPOLIA_USDC_TOKEN = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        deployerEOA = vm.addr(pk);
        (isLocalhost, isBaseSepolia, isEthereumSepolia) = DeploymentHelpers.detectNetwork(block.chainid);
        console.log("ChainId:", block.chainid);
        console.log("Phase A1: Core Infrastructure (TimeProvider, Oracle, QEURO, FeeCollector, Vault)");

        vm.startBroadcast(pk);
        _selectExternalAddresses();

        _deployTimeProvider();
        _deployOraclePhased();
        _deployQEUROPhased();
        _deployFeeCollectorPhased();
        _deployVaultPhased();
        _setupQEURORoles();

        vm.stopBroadcast();
        console.log("\nPhase A1 Complete:");
        console.log("TimeProvider:", address(timeProvider));
        console.log("ChainlinkOracle:", address(chainlinkOracle));
        console.log("QEUROToken:", address(qeuroToken));
        console.log("FeeCollector:", address(feeCollector));
        console.log("QuantillonVault:", address(quantillonVault));
    }


    function _selectExternalAddresses() internal {
        bool withMocks = vm.envOr("WITH_MOCKS", false);
        bool withMockUSDC = vm.envOr("WITH_MOCK_USDC", false);
        bool withMockOracle = vm.envOr("WITH_MOCK_ORACLE", false);
        
        // If --with-mocks is set, it implies both
        if (withMocks) {
            withMockUSDC = true;
            withMockOracle = true;
        }
        
        console.log("WITH_MOCKS:", withMocks);
        console.log("WITH_MOCK_USDC:", withMockUSDC);
        console.log("WITH_MOCK_ORACLE:", withMockOracle);
        
        if (isLocalhost) {
            console.log("Localhost deployment detected");
            // USDC must be provided via environment
            usdc = DeploymentHelpers.selectUSDCAddress(withMockUSDC, block.chainid);
            if (usdc == address(0)) {
                usdc = vm.envAddress("USDC");
            }
            console.log("Using USDC:", usdc);
            
            if (withMockOracle) {
                console.log("Using Mock Chainlink feeds for localhost");
                // Deploy mock feeds
                MockAggregatorV3 eur = new MockAggregatorV3(8);
                eur.setPrice(108000000);
                eurUsdFeed = address(eur);
                MockAggregatorV3 usdcFeed = new MockAggregatorV3(8);
                usdcFeed.setPrice(100000000);
                usdcUsdFeed = address(usdcFeed);
                console.log("EUR/USD Feed (mock):", eurUsdFeed);
                console.log("USDC/USD Feed (mock):", usdcUsdFeed);
            } else {
                console.log("Using real Chainlink feeds for localhost (Base mainnet fork)");
                // When forking Base mainnet, use real Chainlink feeds
                // USDC is already set from environment variable above
                eurUsdFeed = BASE_MAINNET_EUR_USD_FEED;
                usdcUsdFeed = BASE_MAINNET_USDC_USD_FEED;
                console.log("EUR/USD Feed (real):", eurUsdFeed);
                console.log("USDC/USD Feed (real):", usdcUsdFeed);
            }
        } else if (isBaseSepolia) {
            console.log("Base Sepolia deployment detected");
            // Use granular mock flags for Base Sepolia
            usdc = DeploymentHelpers.selectUSDCAddress(withMockUSDC, block.chainid);
            if (usdc == address(0)) {
                usdc = vm.envAddress("USDC");
            }
            console.log("Using USDC:", usdc);
            
            if (withMockOracle) {
                console.log("Using Mock Chainlink feeds for Base Sepolia");
                // Deploy mock feeds
                MockAggregatorV3 eurFeed = new MockAggregatorV3(8);
                eurFeed.setPrice(108000000);
                MockAggregatorV3 usdcFeed = new MockAggregatorV3(8);
                usdcFeed.setPrice(100000000);
                eurUsdFeed = address(eurFeed);
                usdcUsdFeed = address(usdcFeed);
                console.log("EUR/USD Feed (mock):", eurUsdFeed);
                console.log("USDC/USD Feed (mock):", usdcUsdFeed);
            } else {
                console.log("Using real Chainlink feeds for Base Sepolia");
                // Use real Chainlink feeds
                eurUsdFeed = BASE_SEPOLIA_EUR_USD_FEED;
                usdcUsdFeed = BASE_SEPOLIA_USDC_USD_FEED;
                console.log("EUR/USD Feed (real):", eurUsdFeed);
                console.log("USDC/USD Feed (real):", usdcUsdFeed);
            }
        } else if (isEthereumSepolia) {
            console.log("Ethereum Sepolia deployment detected");
            // Use granular mock flags for Ethereum Sepolia
            usdc = DeploymentHelpers.selectUSDCAddress(withMockUSDC, block.chainid);
            if (usdc == address(0)) {
                usdc = vm.envAddress("USDC");
            }
            console.log("Using USDC:", usdc);
            
            if (withMockOracle) {
                console.log("Using Mock Chainlink feeds for Ethereum Sepolia");
                // Deploy mock feeds
                MockAggregatorV3 eurFeed = new MockAggregatorV3(8);
                eurFeed.setPrice(108000000);
                MockAggregatorV3 usdcFeed = new MockAggregatorV3(8);
                usdcFeed.setPrice(100000000);
                eurUsdFeed = address(eurFeed);
                usdcUsdFeed = address(usdcFeed);
                console.log("EUR/USD Feed (mock):", eurUsdFeed);
                console.log("USDC/USD Feed (mock):", usdcUsdFeed);
            } else {
                console.log("Using real Chainlink feeds for Ethereum Sepolia");
                // Use real Chainlink feeds
                eurUsdFeed = ETHEREUM_SEPOLIA_EUR_USD_FEED;
                console.log("EUR/USD Feed (real):", eurUsdFeed);
                
                // For USDC/USD feed, use constant if available, otherwise deploy mock
                if (ETHEREUM_SEPOLIA_USDC_USD_FEED != address(0)) {
                    usdcUsdFeed = ETHEREUM_SEPOLIA_USDC_USD_FEED;
                    console.log("USDC/USD Feed (real):", usdcUsdFeed);
                } else {
                    // Deploy mock for USDC/USD feed (not available on Ethereum Sepolia)
                    console.log("USDC/USD feed not available, deploying mock");
                    MockAggregatorV3 usdcFeed = new MockAggregatorV3(8);
                    usdcFeed.setPrice(100000000);
                    usdcUsdFeed = address(usdcFeed);
                    console.log("USDC/USD Feed (mock - not available):", usdcUsdFeed);
                }
            }
        }
    }

    function _deployTimeProvider() internal {
        if (address(timeProvider) == address(0)) {
            timeProvider = new TimeProvider();
            console.log("TimeProvider:", address(timeProvider));
        }
    }

    function _deployOraclePhased() internal {
        if (address(chainlinkOracle) == address(0)) {
            bool withMocks = vm.envOr("WITH_MOCKS", false);
            bool withMockOracle = vm.envOr("WITH_MOCK_ORACLE", false);
            
            // If --with-mocks is set, it implies mock oracle
            if (withMocks) {
                withMockOracle = true;
            }
            
            if (withMockOracle) {
                // Use MockChainlinkOracle when WITH_MOCKS is true
                MockChainlinkOracle impl = new MockChainlinkOracle();
                ERC1967Proxy proxy = new ERC1967Proxy(address(impl), bytes(""));
                chainlinkOracle = ChainlinkOracle(address(proxy));
                chainlinkOracle.initialize(deployerEOA, eurUsdFeed, usdcUsdFeed, deployerEOA);
                console.log("Mock Oracle Proxy:", address(chainlinkOracle));
            } else {
                // Use real ChainlinkOracle when WITH_MOCKS is false
                address impl = address(new ChainlinkOracle(timeProvider));
                ERC1967Proxy proxy = new ERC1967Proxy(impl, bytes(""));
                chainlinkOracle = ChainlinkOracle(address(proxy));
                ChainlinkOracle(address(chainlinkOracle)).initialize(deployerEOA, eurUsdFeed, usdcUsdFeed, deployerEOA);
                console.log("Real Oracle Proxy:", address(chainlinkOracle));
            }
        }
    }

    function _deployQEUROPhased() internal {
        if (address(qeuroToken) == address(0)) {
            QEUROToken impl = new QEUROToken();
            ERC1967Proxy proxy = new ERC1967Proxy(address(impl), bytes(""));
            qeuroToken = QEUROToken(address(proxy));
            qeuroToken.initialize(deployerEOA, deployerEOA, deployerEOA, deployerEOA);
            console.log("QEURO Proxy:", address(qeuroToken));
        }
    }

    function _deployFeeCollectorPhased() internal {
        if (address(feeCollector) == address(0)) {
            FeeCollector impl = new FeeCollector();
            ERC1967Proxy proxy = new ERC1967Proxy(address(impl), bytes(""));
            feeCollector = FeeCollector(address(proxy));
            
            // Generate EOA addresses that are guaranteed to not have code
            // Use deterministic addresses based on deployer to ensure they're EOAs
            address treasury = address(uint160(uint256(keccak256(abi.encodePacked("treasury", deployerEOA)))));
            address devFund = address(uint160(uint256(keccak256(abi.encodePacked("devFund", deployerEOA)))));
            address communityFund = address(uint160(uint256(keccak256(abi.encodePacked("communityFund", deployerEOA)))));
            
            // Ensure these addresses don't have code (they're deterministic EOAs)
            // If they somehow have code, use fallback addresses
            if (treasury.code.length > 0) {
                treasury = address(uint160(uint256(keccak256(abi.encodePacked("treasury2", deployerEOA)))));
            }
            if (devFund.code.length > 0) {
                devFund = address(uint160(uint256(keccak256(abi.encodePacked("devFund2", deployerEOA)))));
            }
            if (communityFund.code.length > 0) {
                communityFund = address(uint160(uint256(keccak256(abi.encodePacked("communityFund2", deployerEOA)))));
            }
            
            feeCollector.initialize(deployerEOA, treasury, devFund, communityFund);
            console.log("FeeCollector Proxy:", address(feeCollector));
        }
    }

    function _deployVaultPhased() internal {
        if (address(quantillonVault) == address(0)) {
            QuantillonVault impl = new QuantillonVault();
            ERC1967Proxy proxy = new ERC1967Proxy(address(impl), bytes(""));
            quantillonVault = QuantillonVault(address(proxy));
            quantillonVault.initialize(deployerEOA, address(qeuroToken), usdc, address(chainlinkOracle), address(0), address(0), deployerEOA, address(feeCollector));
            console.log("Vault Proxy:", address(quantillonVault));
            
            // Debug: Check roles after initialization
            console.log("Checking roles after QuantillonVault initialization:");
            console.log("Deployer address:", deployerEOA);
            console.log("Has DEFAULT_ADMIN_ROLE:", quantillonVault.hasRole(quantillonVault.DEFAULT_ADMIN_ROLE(), deployerEOA));
            console.log("Has GOVERNANCE_ROLE:", quantillonVault.hasRole(quantillonVault.GOVERNANCE_ROLE(), deployerEOA));
        }
    }

    function _setupQEURORoles() internal {
        if (qeuroToken.hasRole(qeuroToken.MINTER_ROLE(), deployerEOA)) qeuroToken.revokeRole(qeuroToken.MINTER_ROLE(), deployerEOA);
        if (!qeuroToken.hasRole(qeuroToken.MINTER_ROLE(), address(quantillonVault))) qeuroToken.grantRole(qeuroToken.MINTER_ROLE(), address(quantillonVault));
        if (qeuroToken.hasRole(qeuroToken.BURNER_ROLE(), deployerEOA)) qeuroToken.revokeRole(qeuroToken.BURNER_ROLE(), deployerEOA);
        if (!qeuroToken.hasRole(qeuroToken.BURNER_ROLE(), address(quantillonVault))) qeuroToken.grantRole(qeuroToken.BURNER_ROLE(), address(quantillonVault));
    }
}

