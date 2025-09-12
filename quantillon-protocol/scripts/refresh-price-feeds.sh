#!/bin/bash

# Script to refresh mock price feeds with current timestamps
# Run this whenever you get "Invalid EUR/USD price" errors

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔄 Refreshing mock price feeds...${NC}"

# Check if we're in the right directory
if [ ! -f "foundry.toml" ]; then
    echo -e "${RED}❌ Please run this script from the smart-contracts/quantillon-protocol directory${NC}"
    exit 1
fi

# Check if Anvil is running
if ! curl -s http://localhost:8545 > /dev/null; then
    echo -e "${RED}❌ Anvil is not running on localhost:8545${NC}"
    echo -e "${BLUE}💡 Start Anvil with: anvil${NC}"
    exit 1
fi

# Set environment variables
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Create temporary script
cat > /tmp/refresh_feeds.s.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../test/ChainlinkOracle.t.sol";

contract RefreshFeeds is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        
        // Mock price feed addresses from deployment
        address eurUsdFeed = 0xAD523115cd35a8d4E60B3C0953E0E0ac10418309;
        address usdcUsdFeed = 0x2b5A4e5493d4a54E717057B127cf0C000C876f9B;
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Update EUR/USD feed with fresh timestamp
        MockAggregatorV3 eurUsdMock = MockAggregatorV3(eurUsdFeed);
        eurUsdMock.setPrice(108000000); // 1.08 * 10^8 (8 decimals)
        
        // Update USDC/USD feed with fresh timestamp
        MockAggregatorV3 usdcUsdMock = MockAggregatorV3(usdcUsdFeed);
        usdcUsdMock.setPrice(100000000); // 1.00 * 10^8 (8 decimals)
        
        vm.stopBroadcast();
        
        console.log("Price feeds refreshed successfully!");
    }
}
EOF

# Run the script
echo -e "${BLUE}📡 Updating price feeds...${NC}"
forge script /tmp/refresh_feeds.s.sol --rpc-url http://localhost:8545 --broadcast

# Clean up
rm -f /tmp/refresh_feeds.s.sol

echo -e "${GREEN}✅ Price feeds refreshed! You can now try minting again.${NC}"
echo -e "${BLUE}💡 Note: You'll need to run this script again in ~75 minutes when the feeds become stale.${NC}"
