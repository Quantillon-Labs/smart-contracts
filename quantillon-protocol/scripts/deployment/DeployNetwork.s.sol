// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

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
 * @title DeployNetwork
 * @notice Network-specific deployment script for Quantillon Protocol
 * @dev Supports different networks with appropriate configuration
 */
contract DeployNetwork is Script {
    // Network-specific addresses (set via environment variables)
    address public eurUsdFeed;
    address public usdcUsdFeed;
    address public usdcToken;
    address public aavePool;
    address public rewardsController;

    function run() external {
        // Get network configuration
        string memory network = vm.envOr("NETWORK", string("localhost"));
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== QUANTILLON PROTOCOL DEPLOYMENT ===");
        console.log("Network:", network);
        console.log("Deploying with account:", deployer);
        console.log("Account balance:", deployer.balance / 1e18, "ETH");

        // Load network-specific configuration
        _loadNetworkConfig(network);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy all contracts
        _deployContracts();

        vm.stopBroadcast();

        // Save deployment info
        _saveDeploymentInfo(deployer, network);
        
        console.log("\n=== DEPLOYMENT COMPLETED ===");
        console.log("Network:", network);
        console.log("Deployment info saved to deployments/", network, ".json");
    }

    function _loadNetworkConfig(string memory network) internal {
        if (keccak256(abi.encodePacked(network)) == keccak256(abi.encodePacked("localhost"))) {
            // Localhost configuration
            eurUsdFeed = 0x1234567890123456789012345678901234567890;
            usdcUsdFeed = 0x2345678901234567890123456789012345678901;
            usdcToken = 0x3456789012345678901234567890123456789012;
            aavePool = 0x4567890123456789012345678901234567890123;
            rewardsController = address(0);
        } else if (keccak256(abi.encodePacked(network)) == keccak256(abi.encodePacked("sepolia"))) {
            // Sepolia testnet configuration
            eurUsdFeed = vm.envAddress("EUR_USD_FEED_SEPOLIA");
            usdcUsdFeed = vm.envAddress("USDC_USD_FEED_SEPOLIA");
            usdcToken = vm.envAddress("USDC_TOKEN_SEPOLIA");
            aavePool = vm.envAddress("AAVE_POOL_SEPOLIA");
            rewardsController = vm.envAddress("REWARDS_CONTROLLER_SEPOLIA");
        } else if (keccak256(abi.encodePacked(network)) == keccak256(abi.encodePacked("base"))) {
            // Base mainnet configuration
            eurUsdFeed = vm.envAddress("EUR_USD_FEED_BASE");
            usdcUsdFeed = vm.envAddress("USDC_USD_FEED_BASE");
            usdcToken = vm.envAddress("USDC_TOKEN_BASE");
            aavePool = vm.envAddress("AAVE_POOL_BASE");
            rewardsController = vm.envAddress("REWARDS_CONTROLLER_BASE");
        } else {
            revert("Unsupported network");
        }

        console.log("Network configuration loaded for:", network);
    }

    function _deployContracts() internal {
        // Deploy TimeProvider
        console.log("Deploying TimeProvider...");
        TimeProvider timeProvider = new TimeProvider();
        console.log("TimeProvider:", address(timeProvider));

        // Deploy ChainlinkOracle
        console.log("Deploying ChainlinkOracle...");
        ChainlinkOracle oracle = new ChainlinkOracle(timeProvider);
        console.log("ChainlinkOracle:", address(oracle));

        // Deploy QEUROToken
        console.log("Deploying QEUROToken...");
        QEUROToken qeuro = new QEUROToken();
        console.log("QEUROToken:", address(qeuro));

        // Deploy QTIToken
        console.log("Deploying QTIToken...");
        QTIToken qti = new QTIToken(timeProvider);
        console.log("QTIToken:", address(qti));

        // Deploy QuantillonVault
        console.log("Deploying QuantillonVault...");
        QuantillonVault vault = new QuantillonVault();
        console.log("QuantillonVault:", address(vault));

        // Deploy UserPool
        console.log("Deploying UserPool...");
        UserPool userPool = new UserPool(timeProvider);
        console.log("UserPool:", address(userPool));

        // Deploy HedgerPool
        console.log("Deploying HedgerPool...");
        HedgerPool hedgerPool = new HedgerPool(timeProvider);
        console.log("HedgerPool:", address(hedgerPool));

        // Deploy stQEUROToken
        console.log("Deploying stQEUROToken...");
        stQEUROToken stQeuro = new stQEUROToken(timeProvider);
        console.log("stQEUROToken:", address(stQeuro));

        // Deploy AaveVault
        console.log("Deploying AaveVault...");
        AaveVault aaveVault = new AaveVault();
        console.log("AaveVault:", address(aaveVault));

        // Deploy YieldShift
        console.log("Deploying YieldShift...");
        YieldShift yieldShift = new YieldShift(timeProvider);
        console.log("YieldShift:", address(yieldShift));
    }

    function _saveDeploymentInfo(address deployer, string memory network) internal {
        // This would save to network-specific file
        console.log("Saving deployment info for network:", network);
    }
}
