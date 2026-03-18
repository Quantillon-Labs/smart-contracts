// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IStQEUROFactory {
    /**
     * @notice Registers caller vault and deploys a dedicated stQEURO proxy.
     * @dev Implementation enforces vault uniqueness and deterministic token deployment.
     * @param vaultId Vault identifier to register.
     * @param vaultName Uppercase alphanumeric vault name.
     * @return stQEUROToken Registered stQEURO token address.
     * @custom:security Restricted by implementation access control.
     * @custom:validation Implementations should validate vault id/name and uniqueness.
     * @custom:state-changes Updates factory registry mappings and deploys token proxy.
     * @custom:events Emits registration event in implementation.
     * @custom:errors Reverts on invalid input or duplicate registration.
     * @custom:reentrancy Implementation should use CEI-safe ordering for external deployment call.
     * @custom:access Access controlled by implementation.
     * @custom:oracle No oracle dependencies.
     */
    function registerVault(uint256 vaultId, string calldata vaultName) external returns (address stQEUROToken);

    /**
     * @notice Previews deterministic stQEURO address for a vault registration tuple.
     * @dev Read-only helper used before registration to bind expected token address.
     * @param vault Vault address that will register.
     * @param vaultId Vault identifier to register.
     * @param vaultName Uppercase alphanumeric vault name.
     * @return stQEUROToken Predicted token address for registration tuple.
     * @custom:security Read-only helper.
     * @custom:validation Implementations should validate vault inputs and name format.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors Reverts on invalid preview inputs.
     * @custom:reentrancy Not applicable for view function.
     * @custom:access Public view.
     * @custom:oracle No oracle dependencies.
     */
    function previewVaultToken(address vault, uint256 vaultId, string calldata vaultName)
        external
        view
        returns (address stQEUROToken);

    /**
     * @notice Returns registered stQEURO token by vault id.
     * @dev Read-only registry lookup.
     * @param vaultId Vault identifier.
     * @return stQEUROToken Registered token address (or zero if unset).
     * @custom:security Read-only accessor.
     * @custom:validation No input validation required.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors No errors expected.
     * @custom:reentrancy Not applicable for view function.
     * @custom:access Public view.
     * @custom:oracle No oracle dependencies.
     */
    function getStQEUROByVaultId(uint256 vaultId) external view returns (address stQEUROToken);

    /**
     * @notice Returns registered stQEURO token by vault address.
     * @dev Read-only registry lookup.
     * @param vault Vault contract address.
     * @return stQEUROToken Registered token address (or zero if unset).
     * @custom:security Read-only accessor.
     * @custom:validation No input validation required.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors No errors expected.
     * @custom:reentrancy Not applicable for view function.
     * @custom:access Public view.
     * @custom:oracle No oracle dependencies.
     */
    function getStQEUROByVault(address vault) external view returns (address stQEUROToken);

    /**
     * @notice Returns vault address mapped to a vault id.
     * @dev Read-only registry lookup.
     * @param vaultId Vault identifier.
     * @return vault Vault address (or zero if unset).
     * @custom:security Read-only accessor.
     * @custom:validation No input validation required.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors No errors expected.
     * @custom:reentrancy Not applicable for view function.
     * @custom:access Public view.
     * @custom:oracle No oracle dependencies.
     */
    function getVaultById(uint256 vaultId) external view returns (address vault);

    /**
     * @notice Returns vault id mapped to an stQEURO token address.
     * @dev Read-only reverse-registry lookup.
     * @param stQEUROToken Registered token address.
     * @return vaultId Vault identifier (or zero if unset).
     * @custom:security Read-only accessor.
     * @custom:validation No input validation required.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors No errors expected.
     * @custom:reentrancy Not applicable for view function.
     * @custom:access Public view.
     * @custom:oracle No oracle dependencies.
     */
    function getVaultIdByStQEURO(address stQEUROToken) external view returns (uint256 vaultId);

    /**
     * @notice Returns canonical vault name string for a vault id.
     * @dev Read-only registry lookup.
     * @param vaultId Vault identifier.
     * @return vaultName Registered vault name string.
     * @custom:security Read-only accessor.
     * @custom:validation No input validation required.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors No errors expected.
     * @custom:reentrancy Not applicable for view function.
     * @custom:access Public view.
     * @custom:oracle No oracle dependencies.
     */
    function getVaultName(uint256 vaultId) external view returns (string memory vaultName);
}
