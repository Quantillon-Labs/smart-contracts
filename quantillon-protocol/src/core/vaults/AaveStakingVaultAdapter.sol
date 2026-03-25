// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IExternalStakingVault} from "../../interfaces/IExternalStakingVault.sol";
import {IYieldShift} from "../../interfaces/IYieldShift.sol";
import {CommonErrorLibrary} from "../../libraries/CommonErrorLibrary.sol";

interface IMockAaveVault {
    /**
     * @notice Deposits underlying assets into the mock Aave vault.
     * @param assets Amount of USDC to deposit.
     * @param onBehalfOf Account credited with vault shares.
     * @return shares Vault shares minted for the deposit.
     * @dev Forwards parameters to the underlying vault and relies on the adapter-level
     *      access control and `nonReentrant` protection in the main adapter.
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
     * @notice Withdraws underlying assets from the mock Aave vault.
     * @param assets Amount of USDC requested.
     * @param to Recipient of withdrawn USDC.
     * @return withdrawn Actual USDC withdrawn.
     * @dev Forwards parameters to the underlying vault.
     *      Reverts and/or returns values are handled by the calling adapter.
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
     * @param account Account to query.
     * @return Underlying USDC-equivalent amount for `account`.
     * @dev View helper used by the adapter to compute available yield.
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
 * @title AaveStakingVaultAdapter
 * @notice Generic external vault adapter for Aave-like third-party vaults.
 * @dev Mirrors MorphoStakingVaultAdapter structure for symmetric localhost testing.
 *      Wraps a MockAaveVault (simple share-accounting mock) and routes yield to YieldShift.
 */
contract AaveStakingVaultAdapter is AccessControl, ReentrancyGuard, IExternalStakingVault {
    using SafeERC20 for IERC20;

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");

    IERC20 public immutable USDC;
    IMockAaveVault public aaveVault;
    IYieldShift public yieldShift;
    uint256 public yieldVaultId;
    uint256 public principalDeposited;

    event AaveVaultUpdated(address indexed oldVault, address indexed newVault);
    event YieldShiftUpdated(address indexed oldYieldShift, address indexed newYieldShift);
    event YieldVaultIdUpdated(uint256 indexed oldVaultId, uint256 indexed newVaultId);

    /**
     * @notice Initializes Aave adapter dependencies and roles.
     * @param admin Admin address granted governance and manager roles.
     * @param usdc_ USDC token address.
     * @param aaveVault_ Mock Aave vault address.
     * @param yieldShift_ YieldShift contract address.
     * @param yieldVaultId_ YieldShift vault id used when routing harvested yield.
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `GOVERNANCE_ROLE`, and `VAULT_MANAGER_ROLE`,
     *      then stores dependency pointers used by the adapter functions.
     * @custom:security Validates non-zero dependency addresses and vault id.
     * @custom:validation Reverts on zero address or zero `yieldVaultId_`.
     * @custom:state-changes Initializes role assignments and adapter dependency pointers.
     * @custom:events No events emitted by constructor.
     * @custom:errors Reverts with `ZeroAddress` or `InvalidVault` on invalid inputs.
     * @custom:reentrancy Not applicable - constructor only.
     * @custom:access Public constructor.
     * @custom:oracle No oracle dependencies.
     */
    constructor(address admin, address usdc_, address aaveVault_, address yieldShift_, uint256 yieldVaultId_) {
        if (admin == address(0) || usdc_ == address(0) || aaveVault_ == address(0) || yieldShift_ == address(0)) {
            revert CommonErrorLibrary.ZeroAddress();
        }
        if (yieldVaultId_ == 0) revert CommonErrorLibrary.InvalidVault();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(VAULT_MANAGER_ROLE, admin);

        USDC = IERC20(usdc_);
        aaveVault = IMockAaveVault(aaveVault_);
        yieldShift = IYieldShift(yieldShift_);
        yieldVaultId = yieldVaultId_;
    }

    /**
     * @notice Deposits USDC into the configured Aave vault.
     * @param usdcAmount Amount of USDC to deposit (6 decimals).
     * @return sharesReceived Aave vault shares received for the deposit.
     * @dev Tracks principal and forwards the deposit to `aaveVault.depositUnderlying`.
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
        USDC.safeIncreaseAllowance(address(aaveVault), usdcAmount);
        sharesReceived = aaveVault.depositUnderlying(usdcAmount, address(this));
        if (sharesReceived == 0) revert CommonErrorLibrary.InvalidAmount();
    }

    /**
     * @notice Withdraws USDC principal from the configured Aave vault.
     * @param usdcAmount Requested USDC withdrawal amount (6 decimals).
     * @return usdcWithdrawn Actual USDC withdrawn and transferred to caller.
     * @dev Withdraws up to the tracked principal, then transfers the withdrawn USDC to `msg.sender`.
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

        usdcWithdrawn = aaveVault.withdrawUnderlying(requested, address(this));
        if (usdcWithdrawn != requested) revert CommonErrorLibrary.InvalidAmount();
        USDC.safeTransfer(msg.sender, usdcWithdrawn);
    }

    /**
     * @notice Harvests accrued yield from the Aave vault and routes it to YieldShift.
     * @return harvestedYield USDC yield harvested and routed (6 decimals).
     * @dev Computes yield as `totalUnderlyingOf(this) - principalDeposited`, withdraws it,
     *      and routes it to `yieldShift.addYield`.
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
        uint256 currentUnderlying = aaveVault.totalUnderlyingOf(address(this));
        if (currentUnderlying <= principalDeposited) return 0;

        uint256 availableYield = currentUnderlying - principalDeposited;
        harvestedYield = aaveVault.withdrawUnderlying(availableYield, address(this));
        if (harvestedYield == 0) return 0;

        USDC.safeIncreaseAllowance(address(yieldShift), harvestedYield);
        yieldShift.addYield(yieldVaultId, harvestedYield, bytes32("aave"));
    }

    /**
     * @notice Returns current underlying balance controlled by this adapter.
     * @return underlyingBalance Underlying USDC-equivalent balance in the Aave vault.
     * @dev Reads the underlying amount from the configured `aaveVault`.
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
        return aaveVault.totalUnderlyingOf(address(this));
    }

    /**
     * @notice Updates the configured Aave vault endpoint.
     * @param newAaveVault New Aave vault address.
     * @dev Updates the `aaveVault` pointer; the adapter uses the new vault for future deposits/withdrawals.
     * @custom:security Restricted to `GOVERNANCE_ROLE`.
     * @custom:validation Reverts on zero address input.
     * @custom:state-changes Updates `aaveVault` pointer.
     * @custom:events Emits `AaveVaultUpdated`.
     * @custom:errors Reverts with `ZeroAddress` for invalid input.
     * @custom:reentrancy No external calls after state change.
     * @custom:access Restricted to governance role.
     * @custom:oracle No oracle dependencies.
     */
    function setAaveVault(address newAaveVault) external onlyRole(GOVERNANCE_ROLE) {
        if (newAaveVault == address(0)) revert CommonErrorLibrary.ZeroAddress();
        address oldVault = address(aaveVault);
        aaveVault = IMockAaveVault(newAaveVault);
        emit AaveVaultUpdated(oldVault, newAaveVault);
    }

    /**
     * @notice Updates YieldShift destination contract.
     * @param newYieldShift New YieldShift contract address.
     * @dev Updates the `yieldShift` pointer; future harvested yield is routed to the new contract.
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
     * @param newYieldVaultId New YieldShift vault id.
     * @dev Updates the `yieldVaultId` used by `harvestYield` when calling `yieldShift.addYield`.
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
