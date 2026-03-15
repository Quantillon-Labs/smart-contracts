// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IStQEUROFactory {
    function registerVault(uint256 vaultId, string calldata vaultName) external returns (address stQEUROToken);

    function getStQEUROByVaultId(uint256 vaultId) external view returns (address stQEUROToken);

    function getStQEUROByVault(address vault) external view returns (address stQEUROToken);

    function getVaultById(uint256 vaultId) external view returns (address vault);

    function getVaultIdByStQEURO(address stQEUROToken) external view returns (uint256 vaultId);

    function getVaultName(uint256 vaultId) external view returns (string memory vaultName);
}

