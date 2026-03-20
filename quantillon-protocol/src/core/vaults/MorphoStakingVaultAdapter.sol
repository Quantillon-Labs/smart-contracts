// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IExternalStakingVault} from "../../interfaces/IExternalStakingVault.sol";
import {IYieldShift} from "../../interfaces/IYieldShift.sol";
import {CommonErrorLibrary} from "../../libraries/CommonErrorLibrary.sol";

interface IMockMorphoVault {
    /**
     * @notice Deposits underlying assets into the mock Morpho vault.
     * @dev Test-only vault interface used by the adapter in localhost simulations.
     * @param assets Amount of USDC to deposit.
     * @param onBehalfOf Account credited with vault shares.
     * @return shares Vault shares minted for the deposit.
     * @custom:security External dependency call; trust model is environment-specific.
     * @custom:validation Reverts on invalid amount or vault-side checks.
     * @custom:state-changes Updates vault share/asset accounting.
     * @custom:events Vault implementation may emit deposit events.
     * @custom:errors Reverts on vault-side failures.
     * @custom:reentrancy Interface declaration only.
     * @custom:access Access control defined by vault implementation.
     * @custom:oracle No oracle dependencies.
     */
    function depositUnderlying(uint256 assets, address onBehalfOf) external returns (uint256 shares);
    /**
     * @notice Withdraws underlying assets from the mock Morpho vault.
     * @dev Test-only vault interface used by the adapter in localhost simulations.
     * @param assets Amount of USDC requested.
     * @param to Recipient of withdrawn USDC.
     * @return withdrawn Actual USDC withdrawn.
     * @custom:security External dependency call; trust model is environment-specific.
     * @custom:validation Reverts on insufficient balance or vault-side checks.
     * @custom:state-changes Updates vault share/asset accounting.
     * @custom:events Vault implementation may emit withdrawal events.
     * @custom:errors Reverts on vault-side failures.
     * @custom:reentrancy Interface declaration only.
     * @custom:access Access control defined by vault implementation.
     * @custom:oracle No oracle dependencies.
     */
    function withdrawUnderlying(uint256 assets, address to) external returns (uint256 withdrawn);
    /**
     * @notice Returns underlying assets held for an account.
     * @dev Read helper used by the adapter for principal/yield accounting.
     * @param account Account to query.
     * @return Underlying USDC-equivalent amount for `account`.
     * @custom:security Read-only helper.
     * @custom:validation No input validation required at interface level.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors May revert if implementation cannot service read.
     * @custom:reentrancy Not applicable for view function.
     * @custom:access Public view at implementation level.
     * @custom:oracle No oracle dependencies.
     */
    function totalUnderlyingOf(address account) external view returns (uint256);
}

/**
 * @title MorphoStakingVaultAdapter
 * @notice Generic external vault adapter for Morpho-like third-party vaults.
 */
contract MorphoStakingVaultAdapter is AccessControl, ReentrancyGuard, IExternalStakingVault {
    using SafeERC20 for IERC20;

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");

    IERC20 public immutable USDC;
    IMockMorphoVault public morphoVault;
    IYieldShift public yieldShift;
    uint256 public yieldVaultId;
    uint256 public principalDeposited;

    event MorphoVaultUpdated(address indexed oldVault, address indexed newVault);
    event YieldShiftUpdated(address indexed oldYieldShift, address indexed newYieldShift);
    event YieldVaultIdUpdated(uint256 indexed oldVaultId, uint256 indexed newVaultId);

    /**
     * @notice Initializes Morpho adapter dependencies and roles.
     * @dev Configures governance/operator roles and immutable USDC reference.
     * @param admin Admin address granted governance and manager roles.
     * @param usdc_ USDC token address.
     * @param morphoVault_ Mock Morpho vault address.
     * @param yieldShift_ YieldShift contract address.
     * @param yieldVaultId_ YieldShift vault id used when routing harvested yield.
     * @custom:security Validates non-zero dependency addresses and vault id.
     * @custom:validation Reverts on zero address or zero `yieldVaultId_`.
     * @custom:state-changes Initializes role assignments and adapter dependency pointers.
     * @custom:events No events emitted by constructor.
     * @custom:errors Reverts with `ZeroAddress` or `InvalidVault` on invalid inputs.
     * @custom:reentrancy Not applicable - constructor only.
     * @custom:access Public constructor.
     * @custom:oracle No oracle dependencies.
     */
    constructor(address admin, address usdc_, address morphoVault_, address yieldShift_, uint256 yieldVaultId_) {
        if (admin == address(0) || usdc_ == address(0) || morphoVault_ == address(0) || yieldShift_ == address(0)) {
            revert CommonErrorLibrary.ZeroAddress();
        }
        if (yieldVaultId_ == 0) revert CommonErrorLibrary.InvalidVault();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(VAULT_MANAGER_ROLE, admin);

        USDC = IERC20(usdc_);
        morphoVault = IMockMorphoVault(morphoVault_);
        yieldShift = IYieldShift(yieldShift_);
        yieldVaultId = yieldVaultId_;
    }

    /**
     * @notice Deposits USDC into the configured Morpho vault.
     * @dev Pulls USDC from caller, deposits to Morpho, and increases tracked principal.
     * @param usdcAmount Amount of USDC to deposit (6 decimals).
     * @return sharesReceived Morpho vault shares received for the deposit.
     * @custom:security Restricted to `VAULT_MANAGER_ROLE`; protected by nonReentrant.
     * @custom:validation Reverts on zero amount or zero-share deposit outcome.
     * @custom:state-changes Increases `principalDeposited` and updates vault position.
     * @custom:events Emits downstream transfer/deposit events from dependencies.
     * @custom:errors Reverts on transfer/approval/deposit failures.
     * @custom:reentrancy Protected by `nonReentrant`.
     * @custom:access Restricted to vault manager role.
     * @custom:oracle No oracle dependencies.
     */
    function depositUnderlying(uint256 usdcAmount) external override onlyRole(VAULT_MANAGER_ROLE) nonReentrant returns (uint256 sharesReceived) {
        if (usdcAmount == 0) revert CommonErrorLibrary.InvalidAmount();
        principalDeposited += usdcAmount;

        USDC.safeTransferFrom(msg.sender, address(this), usdcAmount);
        USDC.safeIncreaseAllowance(address(morphoVault), usdcAmount);
        sharesReceived = morphoVault.depositUnderlying(usdcAmount, address(this));
        if (sharesReceived == 0) revert CommonErrorLibrary.InvalidAmount();
    }

    /**
     * @notice Withdraws USDC principal from the configured Morpho vault.
     * @dev Caps withdrawal to tracked principal, redeems from Morpho, then returns USDC to caller.
     * @param usdcAmount Requested USDC withdrawal amount (6 decimals).
     * @return usdcWithdrawn Actual USDC withdrawn and transferred to caller.
     * @custom:security Restricted to `VAULT_MANAGER_ROLE`; protected by nonReentrant.
     * @custom:validation Reverts on zero amount or when no principal is tracked.
     * @custom:state-changes Decreases `principalDeposited` and updates vault position.
     * @custom:events Emits downstream transfer/withdrawal events from dependencies.
     * @custom:errors Reverts on withdrawal mismatch or transfer failures.
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
        principalDeposited -= requested;

        usdcWithdrawn = morphoVault.withdrawUnderlying(requested, address(this));
        if (usdcWithdrawn != requested) revert CommonErrorLibrary.InvalidAmount();
        USDC.safeTransfer(msg.sender, usdcWithdrawn);
    }

    /**
     * @notice Harvests accrued yield from Morpho and routes it to YieldShift.
     * @dev Withdraws only the amount above tracked principal, then forwards to YieldShift.
     * @return harvestedYield USDC yield harvested and routed (6 decimals).
     * @custom:security Restricted to `VAULT_MANAGER_ROLE`; protected by nonReentrant.
     * @custom:validation Reverts only on downstream failures; returns zero when no yield is available.
     * @custom:state-changes Leaves principal unchanged and routes yield through YieldShift.
     * @custom:events Emits downstream transfer/yield events from dependencies.
     * @custom:errors Reverts on downstream withdrawal, approval, or addYield failures.
     * @custom:reentrancy Protected by `nonReentrant`.
     * @custom:access Restricted to vault manager role.
     * @custom:oracle No oracle dependencies.
     */
    function harvestYield() external override onlyRole(VAULT_MANAGER_ROLE) nonReentrant returns (uint256 harvestedYield) {
        uint256 currentUnderlying = morphoVault.totalUnderlyingOf(address(this));
        if (currentUnderlying <= principalDeposited) return 0;

        uint256 availableYield = currentUnderlying - principalDeposited;
        harvestedYield = morphoVault.withdrawUnderlying(availableYield, address(this));
        if (harvestedYield == 0) return 0;

        USDC.safeIncreaseAllowance(address(yieldShift), harvestedYield);
        yieldShift.addYield(yieldVaultId, harvestedYield, bytes32("morpho"));
    }

    /**
     * @notice Returns current underlying balance controlled by this adapter.
     * @dev Read helper used by QuantillonVault for exposure accounting.
     * @return underlyingBalance Underlying USDC-equivalent balance in Morpho.
     * @custom:security Read-only helper.
     * @custom:validation No input validation required.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors May revert if downstream vault read fails.
     * @custom:reentrancy Not applicable for view function.
     * @custom:access Public view.
     * @custom:oracle No oracle dependencies.
     */
    function totalUnderlying() external view override returns (uint256 underlyingBalance) {
        return morphoVault.totalUnderlyingOf(address(this));
    }

    /**
     * @notice Updates the configured Morpho vault endpoint.
     * @dev Governance maintenance hook for swapping vault implementation/address.
     * @param newMorphoVault New Morpho vault address.
     * @custom:security Restricted to `GOVERNANCE_ROLE`.
     * @custom:validation Reverts on zero address input.
     * @custom:state-changes Updates `morphoVault` pointer.
     * @custom:events Emits `MorphoVaultUpdated`.
     * @custom:errors Reverts with `ZeroAddress` for invalid input.
     * @custom:reentrancy No external calls after state change.
     * @custom:access Restricted to governance role.
     * @custom:oracle No oracle dependencies.
     */
    function setMorphoVault(address newMorphoVault) external onlyRole(GOVERNANCE_ROLE) {
        if (newMorphoVault == address(0)) revert CommonErrorLibrary.ZeroAddress();
        address oldVault = address(morphoVault);
        morphoVault = IMockMorphoVault(newMorphoVault);
        emit MorphoVaultUpdated(oldVault, newMorphoVault);
    }

    /**
     * @notice Updates YieldShift destination contract.
     * @dev Governance maintenance hook for yield routing dependency changes.
     * @param newYieldShift New YieldShift contract address.
     * @custom:security Restricted to `GOVERNANCE_ROLE`.
     * @custom:validation Reverts on zero address input.
     * @custom:state-changes Updates `yieldShift` dependency pointer.
     * @custom:events Emits `YieldShiftUpdated`.
     * @custom:errors Reverts with `ZeroAddress` for invalid input.
     * @custom:reentrancy No external calls after state change.
     * @custom:access Restricted to governance role.
     * @custom:oracle No oracle dependencies.
     */
    function setYieldShift(address newYieldShift) external onlyRole(GOVERNANCE_ROLE) {
        if (newYieldShift == address(0)) revert CommonErrorLibrary.ZeroAddress();
        address oldYieldShift = address(yieldShift);
        yieldShift = IYieldShift(newYieldShift);
        emit YieldShiftUpdated(oldYieldShift, newYieldShift);
    }

    /**
     * @notice Updates destination vault id used when routing harvested yield.
     * @dev Governance maintenance hook aligning adapter output with YieldShift vault mapping.
     * @param newYieldVaultId New YieldShift vault id.
     * @custom:security Restricted to `GOVERNANCE_ROLE`.
     * @custom:validation Reverts when `newYieldVaultId` is zero.
     * @custom:state-changes Updates `yieldVaultId`.
     * @custom:events Emits `YieldVaultIdUpdated`.
     * @custom:errors Reverts with `InvalidVault` for zero id.
     * @custom:reentrancy No external calls after state change.
     * @custom:access Restricted to governance role.
     * @custom:oracle No oracle dependencies.
     */
    function setYieldVaultId(uint256 newYieldVaultId) external onlyRole(GOVERNANCE_ROLE) {
        if (newYieldVaultId == 0) revert CommonErrorLibrary.InvalidVault();
        uint256 old = yieldVaultId;
        yieldVaultId = newYieldVaultId;
        emit YieldVaultIdUpdated(old, newYieldVaultId);
    }
}
