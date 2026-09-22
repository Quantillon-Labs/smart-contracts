// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IVersioned} from "../interfaces/IVersioned.sol";

interface IMigrationAdapter {
    function USDC() external view returns (address);
    function metaMorphoVault() external view returns (address);
    function principalDeposited() external view returns (uint256);
    function totalUnderlying() external view returns (uint256);
    function withdrawUnderlying(uint256 amount) external returns (uint256);
    function harvestYieldToVault() external returns (uint256);
    function depositUnderlying(uint256 amount) external returns (uint256);
}

interface IMigrationVault {
    function paused() external view returns (bool);
    function usdc() external view returns (address);
    function getVaultExposure(uint256 id) external view returns (address, bool, uint256, uint256);
    function setStakingVault(uint256 id, address adapter, bool active) external;
}

/// @title MetaMorphoAdapterMigration
/// @notice Moves one configured adapter's principal and uncredited yield atomically.
/// @dev Grant temporary manager roles on both adapters and governance on the paused vault,
/// then revoke them in the same Safe transaction. No user tokens are minted or burned.
contract MetaMorphoAdapterMigration is IVersioned, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable safe;
    IMigrationVault public immutable vault;
    IMigrationAdapter public immutable oldAdapter;
    IMigrationAdapter public immutable newAdapter;
    IERC20 public immutable usdc;
    uint256 public immutable vaultId;
    bool public completed;

    error Unauthorized();
    error InvalidConfiguration();
    error InvalidState();
    error BalanceMismatch();

    event Migrated(uint256 indexed vaultId, address indexed oldAdapter, address indexed newAdapter,
        uint256 principal, uint256 uncreditedYield);

    /// @notice Binds this one-use operation to a Safe, vault and adapter pair.
    constructor(address safe_, address vault_, uint256 id_, address old_, address next_) {
        if (safe_.code.length == 0 || vault_.code.length == 0 || id_ == 0 || old_ == next_ ||
            old_.code.length == 0 || next_.code.length == 0) revert InvalidConfiguration();
        safe = safe_;
        vault = IMigrationVault(vault_);
        oldAdapter = IMigrationAdapter(old_);
        newAdapter = IMigrationAdapter(next_);
        vaultId = id_;
        address token = vault.usdc();
        if (token == address(0) || oldAdapter.USDC() != token || newAdapter.USDC() != token ||
            oldAdapter.metaMorphoVault() != newAdapter.metaMorphoVault()) revert InvalidConfiguration();
        usdc = IERC20(token);
    }

    /// @notice Identifies the immutable migration implementation.
    function version() external pure override returns (string memory) { return "1.0.0"; }

    /// @notice Migrates current balances without embedding an amount that can become stale.
    /// @dev Leaves yield uncredited as idle USDC at the replacement adapter. A legacy adapter
    /// can retain fractional shares worth zero USDC base units; no valued assets may remain.
    /// Any failure rolls back the withdrawals, deposits, registry change and completion flag.
    function migrate() external nonReentrant {
        if (msg.sender != safe) revert Unauthorized();
        if (completed || !vault.paused()) revert InvalidState();
        (address current, bool active, uint256 principal, uint256 oldUnderlying) = vault.getVaultExposure(vaultId);
        if (current != address(oldAdapter) || !active || principal == 0 ||
            oldAdapter.principalDeposited() != principal || oldUnderlying < principal ||
            newAdapter.principalDeposited() != 0) revert InvalidState();
        completed = true;
        uint256 heldBefore = usdc.balanceOf(address(this));
        uint256 newUnderlyingBefore = newAdapter.totalUnderlying();
        uint256 withdrawn = oldAdapter.withdrawUnderlying(principal);
        if (withdrawn != principal || usdc.balanceOf(address(this)) - heldBefore != principal) revert BalanceMismatch();
        uint256 harvested = oldAdapter.harvestYieldToVault();
        uint256 received = usdc.balanceOf(address(this)) - heldBefore;
        if (received != principal + harvested || received < oldUnderlying ||
            oldAdapter.principalDeposited() != 0 || oldAdapter.totalUnderlying() != 0) revert BalanceMismatch();

        usdc.forceApprove(address(newAdapter), principal);
        newAdapter.depositUnderlying(principal);
        usdc.forceApprove(address(newAdapter), 0);
        if (harvested != 0) usdc.safeTransfer(address(newAdapter), harvested);
        uint256 newUnderlying = newAdapter.totalUnderlying();
        if (usdc.balanceOf(address(this)) != heldBefore || newAdapter.principalDeposited() != principal ||
            newUnderlying < principal || newUnderlying < newUnderlyingBefore ||
            newUnderlying - newUnderlyingBefore + 1 < received) revert BalanceMismatch();
        vault.setStakingVault(vaultId, address(newAdapter), true);
        (address configured, bool enabled, uint256 tracked,) = vault.getVaultExposure(vaultId);
        if (configured != address(newAdapter) || !enabled || tracked != principal) revert InvalidState();
        emit Migrated(vaultId, address(oldAdapter), address(newAdapter), principal, harvested);
    }
}
