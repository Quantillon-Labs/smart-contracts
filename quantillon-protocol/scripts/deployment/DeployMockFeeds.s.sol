// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// Import the mock aggregator from the test file
import "../../test/ChainlinkOracle.t.sol";

/**
 * @title DeployMockFeeds
 * @notice Deploy mock Chainlink price feeds for localhost development
 */
contract DeployMockFeeds is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== DEPLOYING MOCK PRICE FEEDS ===");
        console.log("Deploying with account:", deployer);
        console.log("Account balance:", deployer.balance / 1e18, "ETH");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy EUR/USD mock price feed (8 decimals like real Chainlink)
        console.log("Deploying EUR/USD mock price feed...");
        MockAggregatorV3 eurUsdFeed = new MockAggregatorV3(8);
        console.log("EUR/USD mock feed deployed to:", address(eurUsdFeed));
        
        // Set EUR/USD price to ~1.08 USD per EUR (realistic current price)
        eurUsdFeed.setPrice(108000000); // 1.08 * 10^8 (8 decimals)
        console.log("EUR/USD price set to 1.08 USD");

        // Deploy USDC/USD mock price feed (8 decimals like real Chainlink)
        console.log("Deploying USDC/USD mock price feed...");
        MockAggregatorV3 usdcUsdFeed = new MockAggregatorV3(8);
        console.log("USDC/USD mock feed deployed to:", address(usdcUsdFeed));
        
        // Set USDC/USD price to ~1.00 USD (should be close to $1)
        usdcUsdFeed.setPrice(100000000); // 1.00 * 10^8 (8 decimals)
        console.log("USDC/USD price set to 1.00 USD");

        vm.stopBroadcast();
        
        console.log("\n=== MOCK PRICE FEEDS DEPLOYED ===");
        console.log("EUR/USD Mock Feed:", address(eurUsdFeed));
        console.log("USDC/USD Mock Feed:", address(usdcUsdFeed));
        console.log("\nNext steps:");
        console.log("1. Update oracle contract with these addresses");
        console.log("2. Initialize the oracle contract");
    }
}
