// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {IExternalStakingVault} from "../../interfaces/IExternalStakingVault.sol";
import {CommonErrorLibrary} from "../../libraries/CommonErrorLibrary.sol";

/**
 * @title MetaMorphoStakingVaultAdapter
 * @notice Adapter for MetaMorpho ERC-4626 vaults such as 0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2.
 */
contract MetaMorphoStakingVaultAdapter is AccessControl, ReentrancyGuard, IExternalStakingVault {
    using SafeERC20 for IERC20;

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");
    IERC20 public immutable USDC;
    IERC4626 public metaMorphoVault;
    uint256 public principalDeposited;

    event MetaMorphoVaultUpdated(address indexed oldVault, address indexed newVault);

    /**
     * @notice Initializes MetaMorpho adapter dependencies and roles.
     * @dev Configures governance/manager roles, immutable USDC reference, and validates that the
     *      MetaMorpho ERC-4626 vault's asset matches USDC.
     * @param admin Admin address granted default-admin, governance, and manager roles.
     * @param usdc_ USDC token address.
     * @param metaMorphoVault_ MetaMorpho ERC-4626 vault address (asset must equal `usdc_`).
     * @custom:security Validates non-zero dependencies and matching ERC-4626 asset.
     * @custom:validation Reverts on zero address or asset mismatch.
     * @custom:state-changes Initializes role assignments and adapter dependency pointers.
     * @custom:events No events emitted by constructor.
     * @custom:errors Reverts with `ZeroAddress` or `InvalidAddress`.
     * @custom:reentrancy Not applicable - constructor only.
     * @custom:access Public constructor.
     * @custom:oracle No oracle dependencies.
     */
    constructor(address admin, address usdc_, address metaMorphoVault_) {
        if (admin == address(0) || usdc_ == address(0) || metaMorphoVault_ == address(0)) {
            revert CommonErrorLibrary.ZeroAddress();
        }
        if (IERC4626(metaMorphoVault_).asset() != usdc_) revert CommonErrorLibrary.InvalidAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(VAULT_MANAGER_ROLE, admin);

        USDC = IERC20(usdc_);
        metaMorphoVault = IERC4626(metaMorphoVault_);
    }

    /**
     * @notice Deposits USDC into the MetaMorpho ERC-4626 vault and tracks principal.
     * @dev Pulls USDC from caller, deposits into the ERC-4626 vault using a scoped approval, and
     *      increases tracked principal by the deposited amount.
     * @param usdcAmount Amount of USDC to deposit (6 decimals).
     * @return sharesReceived MetaMorpho shares minted to this adapter.
     * @custom:security Restricted to `VAULT_MANAGER_ROLE`; protected by nonReentrant.
     * @custom:validation Reverts on zero amount, insufficient deposit capacity, or zero-share outcome.
     * @custom:state-changes Increases `principalDeposited` and updates the ERC-4626 vault position.
     * @custom:events Emits downstream transfer/deposit events from dependencies.
     * @custom:errors Reverts with `InvalidAmount` or `InsufficientBalance` on failed checks.
     * @custom:reentrancy Protected by `nonReentrant`.
     * @custom:access Restricted to vault manager role.
     * @custom:oracle No oracle dependencies.
     */
    function depositUnderlying(uint256 usdcAmount)
        external
        override
        onlyRole(VAULT_MANAGER_ROLE)
        nonReentrant
        returns (uint256 sharesReceived)
    {
        if (usdcAmount == 0) revert CommonErrorLibrary.InvalidAmount();
        if (metaMorphoVault.maxDeposit(address(this)) < usdcAmount) revert CommonErrorLibrary.InsufficientBalance();

        principalDeposited += usdcAmount;
        USDC.safeTransferFrom(msg.sender, address(this), usdcAmount);
        USDC.forceApprove(address(metaMorphoVault), usdcAmount);
        sharesReceived = metaMorphoVault.deposit(usdcAmount, address(this));
        USDC.forceApprove(address(metaMorphoVault), 0);

        if (sharesReceived == 0) revert CommonErrorLibrary.InvalidAmount();
    }

    /**
     * @notice Withdraws tracked principal from MetaMorpho and returns USDC to the caller.
     * @dev Caps the withdrawal to tracked principal, redeems from the ERC-4626 vault, verifies the
     *      received amount, decreases tracked principal, then transfers USDC to the caller.
     * @param usdcAmount Requested USDC amount (6 decimals).
     * @return usdcWithdrawn Actual USDC amount withdrawn and transferred to the caller.
     * @custom:security Restricted to `VAULT_MANAGER_ROLE`; protected by nonReentrant.
     * @custom:validation Reverts on zero amount, no tracked principal, insufficient liquidity, or shortfall.
     * @custom:state-changes Decreases `principalDeposited` and updates the ERC-4626 vault position.
     * @custom:events Emits downstream transfer/withdrawal events from dependencies.
     * @custom:errors Reverts with `InvalidAmount` or `InsufficientBalance` on failed checks.
     * @custom:reentrancy Protected by `nonReentrant`.
     * @custom:access Restricted to vault manager role.
     * @custom:oracle No oracle dependencies.
     */
    function withdrawUnderlying(uint256 usdcAmount)
        external
        override
        onlyRole(VAULT_MANAGER_ROLE)
        nonReentrant
        returns (uint256 usdcWithdrawn)
    {
        if (usdcAmount == 0) revert CommonErrorLibrary.InvalidAmount();
        if (principalDeposited == 0) revert CommonErrorLibrary.InsufficientBalance();

        uint256 requested = usdcAmount > principalDeposited ? principalDeposited : usdcAmount;
        if (metaMorphoVault.maxWithdraw(address(this)) < requested) revert CommonErrorLibrary.InsufficientBalance();

        principalDeposited -= requested;
        uint256 balanceBefore = USDC.balanceOf(address(this));
        uint256 sharesBurned = metaMorphoVault.withdraw(requested, address(this), address(this));
        if (sharesBurned == 0) revert CommonErrorLibrary.InvalidAmount();

        uint256 received = USDC.balanceOf(address(this)) - balanceBefore;
        if (received < requested) revert CommonErrorLibrary.InvalidAmount();

        USDC.safeTransfer(msg.sender, requested);
        return requested;
    }

    /**
     * @notice Harvests accrued ERC-4626 share yield and transfers it as USDC to the caller (the vault).
     * @dev Transfers the realized USDC to `msg.sender` (the vault) so the caller can apply its own
     *      distribution policy. Caps to the vault's liquid withdrawable amount and leaves tracked
     *      principal unchanged.
     * @return realizedYield USDC yield harvested and transferred to the caller (6 decimals).
     * @custom:security Restricted to `VAULT_MANAGER_ROLE`; protected by nonReentrant.
     * @custom:validation Returns zero when no yield is available; reverts only on downstream failures.
     * @custom:state-changes Leaves `principalDeposited` unchanged; transfers realized USDC to the caller.
     * @custom:events Emits downstream transfer events from dependencies.
     * @custom:errors Reverts with `InvalidAmount` on withdrawal mismatch or downstream failures.
     * @custom:reentrancy Protected by `nonReentrant`.
     * @custom:access Restricted to vault manager role.
     * @custom:oracle No oracle dependencies.
     */
    function harvestYieldToVault()
        external
        override
        onlyRole(VAULT_MANAGER_ROLE)
        nonReentrant
        returns (uint256 realizedYield)
    {
        uint256 currentUnderlying = _totalUnderlying();
        if (currentUnderlying <= principalDeposited) return 0;

        uint256 availableYield = currentUnderlying - principalDeposited;
        uint256 liquidAssets = metaMorphoVault.maxWithdraw(address(this));
        realizedYield = availableYield < liquidAssets ? availableYield : liquidAssets;
        if (realizedYield == 0) return 0;

        uint256 balanceBefore = USDC.balanceOf(address(this));
        uint256 sharesBurned = metaMorphoVault.withdraw(realizedYield, address(this), address(this));
        if (sharesBurned == 0) revert CommonErrorLibrary.InvalidAmount();

        uint256 received = USDC.balanceOf(address(this)) - balanceBefore;
        if (received < realizedYield) revert CommonErrorLibrary.InvalidAmount();

        USDC.safeTransfer(msg.sender, realizedYield);
    }

    /**
     * @notice Returns the USDC value of this adapter's MetaMorpho shares.
     * @dev Read helper used by QuantillonVault for exposure accounting; delegates to `_totalUnderlying`.
     * @return underlyingBalance Underlying USDC-equivalent balance held via ERC-4626 shares.
     * @custom:security Read-only helper.
     * @custom:validation No input validation required.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors May revert if the downstream ERC-4626 read fails.
     * @custom:reentrancy Not applicable for view function.
     * @custom:access Public view.
     * @custom:oracle No oracle dependencies.
     */
    function totalUnderlying() external view override returns (uint256 underlyingBalance) {
        return _totalUnderlying();
    }

    /**
     * @notice Updates the configured MetaMorpho ERC-4626 vault endpoint.
     * @dev Governance maintenance hook; validates the new vault's asset matches USDC before swapping.
     * @param newMetaMorphoVault New MetaMorpho ERC-4626 vault address.
     * @custom:security Restricted to `GOVERNANCE_ROLE`.
     * @custom:validation Reverts on zero address or asset mismatch with USDC.
     * @custom:state-changes Updates `metaMorphoVault` pointer.
     * @custom:events Emits `MetaMorphoVaultUpdated`.
     * @custom:errors Reverts with `ZeroAddress` or `InvalidAddress` for invalid input.
     * @custom:reentrancy No external calls after state change.
     * @custom:access Restricted to governance role.
     * @custom:oracle No oracle dependencies.
     */
    function setMetaMorphoVault(address newMetaMorphoVault) external onlyRole(GOVERNANCE_ROLE) {
        if (newMetaMorphoVault == address(0)) revert CommonErrorLibrary.ZeroAddress();
        if (IERC4626(newMetaMorphoVault).asset() != address(USDC)) revert CommonErrorLibrary.InvalidAddress();

        address oldVault = address(metaMorphoVault);
        metaMorphoVault = IERC4626(newMetaMorphoVault);
        emit MetaMorphoVaultUpdated(oldVault, newMetaMorphoVault);
    }

    /**
     * @notice Returns the USDC-equivalent value of this adapter's MetaMorpho shares.
     * @dev Converts the adapter's ERC-4626 share balance to assets via `convertToAssets`.
     * @return Underlying USDC-equivalent amount held via ERC-4626 shares.
     * @custom:security Internal read-only helper.
     * @custom:validation No input validation required.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors May revert if the downstream ERC-4626 read fails.
     * @custom:reentrancy Not applicable for view function.
     * @custom:access Internal.
     * @custom:oracle No oracle dependencies.
     */
    function _totalUnderlying() internal view returns (uint256) {
        return metaMorphoVault.convertToAssets(metaMorphoVault.balanceOf(address(this)));
    }
}
