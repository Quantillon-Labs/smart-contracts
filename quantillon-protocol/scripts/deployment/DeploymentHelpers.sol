// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

/**
 * @title DeploymentHelpers
 * @notice Shared deployment utilities for all phase scripts
 * @dev Provides network detection and USDC address selection logic
 */
library DeploymentHelpers {
    // Network chain IDs
    uint256 constant CHAINID_LOCALHOST = 31337;
    uint256 constant CHAINID_BASE_SEPOLIA = 84532;
    uint256 constant CHAINID_ETHEREUM_SEPOLIA = 11155111;

    // USDC token addresses per network
    address constant BASE_SEPOLIA_USDC_TOKEN = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address constant ETHEREUM_SEPOLIA_USDC_TOKEN = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    /**
     * @notice Detects the current network
     * @param chainId The current chain ID
     * @return isLocalhost True if localhost
     * @return isBaseSepolia True if Base Sepolia
     * @return isEthereumSepolia True if Ethereum Sepolia
     */
    function detectNetwork(uint256 chainId)
        internal
        pure
        returns (bool isLocalhost, bool isBaseSepolia, bool isEthereumSepolia)
    {
        isLocalhost = (chainId == CHAINID_LOCALHOST);
        isBaseSepolia = (chainId == CHAINID_BASE_SEPOLIA);
        isEthereumSepolia = (chainId == CHAINID_ETHEREUM_SEPOLIA);
    }

    /**
     * @notice Selects the appropriate USDC address based on network and mock flag
     * @param withMocks Whether deployment uses mocks
     * @param chainId Current chain ID
     * @return usdc The USDC token address to use
     */
    function selectUSDCAddress(bool withMocks, uint256 chainId) internal view returns (address usdc) {
        (bool isLocalhost, bool isBaseSepolia, bool isEthereumSepolia) = detectNetwork(chainId);

        if (isLocalhost) {
            // For localhost, still rely on env injection from deploy script
            return address(0);
        } else if (isBaseSepolia) {
            return withMocks ? address(0) : BASE_SEPOLIA_USDC_TOKEN;
        } else if (isEthereumSepolia) {
            return withMocks ? address(0) : ETHEREUM_SEPOLIA_USDC_TOKEN;
        } else {
            return address(0);
        }
    }
}

