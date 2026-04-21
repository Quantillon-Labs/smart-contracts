// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IstQEURO
 * @notice Minimal ERC-4626-oriented interface for stQEURO vault tokens.
 */
interface IstQEURO {
    /**
     * @notice Returns the underlying ERC-20 asset managed by the vault.
     * @dev Implementations should return the QEURO token address used by the ERC-4626 vault.
     * @return underlyingAsset Address of the underlying QEURO asset.
     * @custom:security Read-only helper.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function asset() external view returns (address);

    /**
     * @notice Returns the total QEURO assets currently backing the vault.
     * @dev Implementations should include principal and compounded yield held by the ERC-4626 vault.
     * @return managedAssets Total QEURO assets managed by the vault.
     * @custom:security Read-only helper.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function totalAssets() external view returns (uint256);

    /**
     * @notice Converts a QEURO asset amount into the equivalent share amount.
     * @dev Mirrors ERC-4626 share-conversion math using the current vault exchange rate.
     * @param assets Amount of QEURO assets to convert.
     * @return shares Equivalent stQEURO shares for `assets`.
     * @custom:security Read-only helper.
     * @custom:validation Uses the current vault accounting model and rounding rules.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function convertToShares(uint256 assets) external view returns (uint256 shares);

    /**
     * @notice Converts a stQEURO share amount into the equivalent asset amount.
     * @dev Mirrors ERC-4626 asset-conversion math using the current vault exchange rate.
     * @param shares Amount of stQEURO shares to convert.
     * @return assets Equivalent QEURO assets for `shares`.
     * @custom:security Read-only helper.
     * @custom:validation Uses the current vault accounting model and rounding rules.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    /**
     * @notice Previews how many shares a deposit would mint.
     * @dev Mirrors ERC-4626 preview math without transferring assets.
     * @param assets Amount of QEURO assets to preview.
     * @return shares Estimated stQEURO shares for the deposit.
     * @custom:security Read-only helper.
     * @custom:validation Uses current vault accounting and rounding behavior.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function previewDeposit(uint256 assets) external view returns (uint256 shares);

    /**
     * @notice Previews how many assets would be required to mint a target share amount.
     * @dev Mirrors ERC-4626 preview math without transferring assets.
     * @param shares Amount of stQEURO shares to preview.
     * @return assets Estimated QEURO assets required to mint `shares`.
     * @custom:security Read-only helper.
     * @custom:validation Uses current vault accounting and rounding behavior.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function previewMint(uint256 shares) external view returns (uint256 assets);

    /**
     * @notice Previews how many shares would be burned to withdraw a target asset amount.
     * @dev Mirrors ERC-4626 preview math without transferring assets.
     * @param assets Amount of QEURO assets to preview.
     * @return shares Estimated stQEURO shares burned for the withdrawal.
     * @custom:security Read-only helper.
     * @custom:validation Uses current vault accounting and rounding behavior.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);

    /**
     * @notice Previews how many assets would be returned for a target share redemption.
     * @dev Mirrors ERC-4626 preview math without transferring assets.
     * @param shares Amount of stQEURO shares to preview.
     * @return assets Estimated QEURO assets returned for redeeming `shares`.
     * @custom:security Read-only helper.
     * @custom:validation Uses current vault accounting and rounding behavior.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function previewRedeem(uint256 shares) external view returns (uint256 assets);

    /**
     * @notice Deposits QEURO and mints stQEURO shares to a receiver.
     * @dev Implementations should follow ERC-4626 deposit semantics and emit a `Deposit` event.
     * @param assets Amount of QEURO assets to deposit.
     * @param receiver Address receiving the minted stQEURO shares.
     * @return shares Amount of stQEURO shares minted.
     * @custom:security Implementations should apply pause, allowance, and asset-transfer protections.
     * @custom:validation Implementations validate deposit amount, receiver, and available limits.
     * @custom:state-changes Transfers QEURO into the vault and mints stQEURO shares.
     * @custom:events Emits the standard ERC-4626 `Deposit` event in implementation.
     * @custom:errors Reverts on invalid input, paused state, or ERC-20/ERC-4626 failures.
     * @custom:reentrancy Implementation should guard integrated transfer flows as needed.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /**
     * @notice Mints a target share amount by supplying the required QEURO assets.
     * @dev Implementations should follow ERC-4626 mint semantics and emit a `Deposit` event.
     * @param shares Amount of stQEURO shares to mint.
     * @param receiver Address receiving the minted stQEURO shares.
     * @return assets Amount of QEURO assets required for the mint.
     * @custom:security Implementations should apply pause, allowance, and asset-transfer protections.
     * @custom:validation Implementations validate share amount, receiver, and available limits.
     * @custom:state-changes Transfers QEURO into the vault and mints stQEURO shares.
     * @custom:events Emits the standard ERC-4626 `Deposit` event in implementation.
     * @custom:errors Reverts on invalid input, paused state, or ERC-20/ERC-4626 failures.
     * @custom:reentrancy Implementation should guard integrated transfer flows as needed.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    /**
     * @notice Withdraws QEURO assets from the vault.
     * @dev Implementations should follow ERC-4626 withdraw semantics and emit a `Withdraw` event.
     * @param assets Amount of QEURO assets to withdraw.
     * @param receiver Address receiving the withdrawn QEURO.
     * @param owner Share owner whose balance and allowance are consumed.
     * @return shares Amount of stQEURO shares burned.
     * @custom:security Implementations should apply pause, allowance, and asset-transfer protections.
     * @custom:validation Implementations validate asset amount, receiver/owner, and available limits.
     * @custom:state-changes Burns stQEURO shares and transfers QEURO assets out of the vault.
     * @custom:events Emits the standard ERC-4626 `Withdraw` event in implementation.
     * @custom:errors Reverts on invalid input, paused state, insufficient balances, or ERC-20/ERC-4626 failures.
     * @custom:reentrancy Implementation should guard integrated transfer flows as needed.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    /**
     * @notice Redeems stQEURO shares for the underlying QEURO assets.
     * @dev Implementations should follow ERC-4626 redeem semantics and emit a `Withdraw` event.
     * @param shares Amount of stQEURO shares to redeem.
     * @param receiver Address receiving the redeemed QEURO.
     * @param owner Share owner whose balance and allowance are consumed.
     * @return assets Amount of QEURO assets returned.
     * @custom:security Implementations should apply pause, allowance, and asset-transfer protections.
     * @custom:validation Implementations validate share amount, receiver/owner, and available limits.
     * @custom:state-changes Burns stQEURO shares and transfers QEURO assets out of the vault.
     * @custom:events Emits the standard ERC-4626 `Withdraw` event in implementation.
     * @custom:errors Reverts on invalid input, paused state, insufficient balances, or ERC-20/ERC-4626 failures.
     * @custom:reentrancy Implementation should guard integrated transfer flows as needed.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);

    /**
     * @notice Returns the current share balance for an owner.
     * @dev Mirrors the ERC-20 balance view for stQEURO shares.
     * @param owner Account whose share balance is being queried.
     * @return shares Current stQEURO share balance of `owner`.
     * @custom:security Read-only helper.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function balanceOf(address owner) external view returns (uint256 shares);

    /**
     * @notice Returns the total outstanding supply of stQEURO shares.
     * @dev Mirrors the ERC-20 total supply view for the vault share token.
     * @return sharesSupply Total stQEURO shares currently issued.
     * @custom:security Read-only helper.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function totalSupply() external view returns (uint256 sharesSupply);

    /**
     * @notice Returns the configured yield fee for compounded vault yield.
     * @dev Implementations generally express the fee in basis points.
     * @return feeBps Current yield fee in basis points.
     * @custom:security Read-only helper.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function yieldFee() external view returns (uint256);

    /**
     * @notice Updates the yield fee applied to compounded vault yield.
     * @dev Implementations typically restrict this governance action and validate basis-point caps.
     * @param _yieldFee New yield fee in basis points.
     * @custom:security Restricted in implementation to governance or admin roles.
     * @custom:validation Implementations validate `_yieldFee` against configured fee limits.
     * @custom:state-changes Updates the stored yield-fee configuration.
     * @custom:events Emits implementation-defined yield-parameter update events.
     * @custom:errors Reverts on invalid fee values or missing privileges in implementation.
     * @custom:reentrancy Not applicable.
     * @custom:access Restricted in implementation to governance or admin roles.
     * @custom:oracle Not applicable.
     */
    function updateYieldParameters(uint256 _yieldFee) external;

    /**
     * @notice Returns the human-readable vault name associated with the share series.
     * @dev Used by frontends and admin tooling to distinguish vault-specific stQEURO series.
     * @return name Vault name or suffix configured for the share token.
     * @custom:security Read-only helper.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function vaultName() external view returns (string memory);
}
