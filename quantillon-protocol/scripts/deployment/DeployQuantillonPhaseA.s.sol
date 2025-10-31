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
    address constant BASE_SEPOLIA_EUR_USD_FEED = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165; //TO UPDATE
    address constant BASE_SEPOLIA_USDC_USD_FEED = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;
    
    // Ethereum Sepolia oracle feed addresses
    address constant ETHEREUM_SEPOLIA_EUR_USD_FEED = 0x1a81afB8146aeFfCFc5E50e8479e826E7D55b910;
    address constant ETHEREUM_SEPOLIA_USDC_USD_FEED = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E;

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
        console.log("WITH_MOCKS environment variable:", withMocks);
        if (isLocalhost) {
            // USDC must be provided via environment (from DeployMockUSDC.s.sol)
            usdc = DeploymentHelpers.selectUSDCAddress(vm, block.chainid);
            console.log("Using USDC from helper:", usdc);
            MockAggregatorV3 eur = new MockAggregatorV3(8);
            eur.setPrice(108000000);
            eurUsdFeed = address(eur);
            MockAggregatorV3 usdcFeed = new MockAggregatorV3(8);
            usdcFeed.setPrice(100000000);
            usdcUsdFeed = address(usdcFeed);
        } else if (isBaseSepolia) {
            console.log("Base Sepolia deployment detected");
            if (withMocks) {
                console.log("Using MockChainlinkOracle for Base Sepolia");
                // Deploy mock feeds (oracle will be deployed in _deployOraclePhased)
                MockAggregatorV3 eurFeed = new MockAggregatorV3(8);
                eurFeed.setPrice(108000000);
                MockAggregatorV3 usdcFeed = new MockAggregatorV3(8);
                usdcFeed.setPrice(100000000);
                
                usdc = DeploymentHelpers.selectUSDCAddress(vm, block.chainid);
                console.log("Using USDC from helper:", usdc);
                eurUsdFeed = address(eurFeed);
                usdcUsdFeed = address(usdcFeed);
            } else {
                console.log("Using real Chainlink feeds for Base Sepolia");
                // Use real Chainlink feeds
                usdc = DeploymentHelpers.selectUSDCAddress(vm, block.chainid);
                console.log("Using USDC from helper:", usdc);
                eurUsdFeed = BASE_SEPOLIA_EUR_USD_FEED;
                usdcUsdFeed = BASE_SEPOLIA_USDC_USD_FEED;
            }
        } else if (isEthereumSepolia) {
            console.log("Ethereum Sepolia deployment detected");
            if (withMocks) {
                console.log("Using MockChainlinkOracle for Ethereum Sepolia");
                // Deploy mock feeds (oracle will be deployed in _deployOraclePhased)
                MockAggregatorV3 eurFeed = new MockAggregatorV3(8);
                eurFeed.setPrice(108000000);
                MockAggregatorV3 usdcFeed = new MockAggregatorV3(8);
                usdcFeed.setPrice(100000000);
                
                usdc = DeploymentHelpers.selectUSDCAddress(vm, block.chainid);
                console.log("Using USDC from helper:", usdc);
                eurUsdFeed = address(eurFeed);
                usdcUsdFeed = address(usdcFeed);
            } else {
                console.log("Using real Chainlink EUR/USD feed for Ethereum Sepolia");
                // Use real Chainlink EUR/USD feed
                eurUsdFeed = ETHEREUM_SEPOLIA_EUR_USD_FEED;
                console.log("EUR/USD Feed:", eurUsdFeed);
                
                // For USDC/USD feed, use constant if available, otherwise deploy mock
                if (ETHEREUM_SEPOLIA_USDC_USD_FEED != address(0)) {
                    usdcUsdFeed = ETHEREUM_SEPOLIA_USDC_USD_FEED;
                    console.log("Using USDC/USD Feed from constant:", usdcUsdFeed);
                } else {
                    // Deploy mock for USDC/USD feed (not available on Ethereum Sepolia)
                    console.log("USDC/USD feed not available, deploying mock");
                    MockAggregatorV3 usdcFeed = new MockAggregatorV3(8);
                    usdcFeed.setPrice(100000000);
                    usdcUsdFeed = address(usdcFeed);
                }
                
                // Use shared helper for USDC selection
                usdc = DeploymentHelpers.selectUSDCAddress(vm, block.chainid);
                console.log("Using USDC from helper:", usdc);
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
            if (withMocks) {
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
            feeCollector.initialize(deployerEOA, deployerEOA, deployerEOA, deployerEOA);
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

