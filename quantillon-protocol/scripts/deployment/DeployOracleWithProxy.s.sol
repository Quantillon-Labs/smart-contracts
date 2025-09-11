// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../../src/oracle/ChainlinkOracle.sol";
import "../../src/libraries/TimeProviderLibrary.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployOracleWithProxy
 * @notice Deploy ChainlinkOracle with proper proxy pattern
 */
contract DeployOracleWithProxy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(deployerPrivateKey);
        
        // TimeProvider address from previous deployment
        address timeProviderAddress = 0xE6E340D132b5f46d1e472DebcD681B2aBc16e57E;
        
        // Mock price feed addresses from latest deployment
        address eurUsdFeed = 0x7a2088a1bFc9d81c55368AE168C2C02570cB814F;
        address usdcUsdFeed = 0xc5a5C42992dECbae36851359345FE25997F5C42d;
        
        console.log("=== DEPLOYING ORACLE WITH PROXY ===");
        console.log("Deploying with account:", deployer);
        console.log("TimeProvider address:", timeProviderAddress);
        console.log("EUR/USD feed:", eurUsdFeed);
        console.log("USDC/USD feed:", usdcUsdFeed);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the implementation contract
        console.log("Deploying ChainlinkOracle implementation...");
        ChainlinkOracle implementation = new ChainlinkOracle(TimeProvider(timeProviderAddress));
        console.log("Implementation deployed to:", address(implementation));
        
        // Deploy the proxy
        console.log("Deploying proxy...");
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                ChainlinkOracle.initialize.selector,
                deployer,        // admin
                eurUsdFeed,      // EUR/USD price feed
                usdcUsdFeed,     // USDC/USD price feed
                deployer         // treasury
            )
        );
        console.log("Proxy deployed to:", address(proxy));
        
        // Create oracle instance pointing to proxy
        ChainlinkOracle oracle = ChainlinkOracle(address(proxy));
        
        console.log("Oracle deployed and initialized successfully!");
        console.log("Oracle proxy address:", address(oracle));

        vm.stopBroadcast();
        
        console.log("\n=== ORACLE DEPLOYMENT COMPLETED ===");
        console.log("Implementation:", address(implementation));
        console.log("Proxy (Oracle):", address(oracle));
        console.log("Update your dApp to use the proxy address:", address(oracle));
        
        // Copy ChainlinkOracle ABI to frontend
        copyOracleABIToFrontend();
    }

    function copyOracleABIToFrontend() internal {
        console.log("Copying ChainlinkOracle ABI to frontend...");
        console.log("Please run './scripts/deployment/copy-abis.sh' manually to copy ABIs to frontend");
        console.log("This ensures the frontend has the latest contract interfaces.");
    }
}
