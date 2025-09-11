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
        address timeProviderAddress = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
        
        // Mock price feed addresses from latest deployment
        address eurUsdFeed = 0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE;
        address usdcUsdFeed = 0x3Aa5ebB10DC797CAC828524e59A333d0A371443c;
        
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
