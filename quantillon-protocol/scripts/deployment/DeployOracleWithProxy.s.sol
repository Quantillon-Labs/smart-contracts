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
        
        // Mock price feed addresses from previous deployment
        address eurUsdFeed = 0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e;
        address usdcUsdFeed = 0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82;
        
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
    }
}
