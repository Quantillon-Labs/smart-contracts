// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../../src/mocks/MockUSDC.sol";

/**
 * @title DeployMockUSDC
 * @dev Deployment script for MockUSDC contract
 */
contract DeployMockUSDC is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying MockUSDC...");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        MockUSDC mockUSDC = new MockUSDC();
        
        vm.stopBroadcast();
        
        console.log("MockUSDC deployed at:", address(mockUSDC));
        console.log("MockUSDC name:", mockUSDC.name());
        console.log("MockUSDC symbol:", mockUSDC.symbol());
        console.log("MockUSDC decimals:", mockUSDC.decimals());
        console.log("Deployer USDC balance:", mockUSDC.balanceOf(deployer));
        
        // Copy ABI to frontend
        copyUSDCABIToFrontend();
    }
    
    function copyUSDCABIToFrontend() internal {
        console.log("Copying MockUSDC ABI to frontend...");
        console.log("Please run './scripts/copy-abis.sh' manually to copy ABIs to frontend");
        console.log("This ensures the frontend has the latest contract interfaces.");
    }
}
