// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {IExternalStakingVault} from "../../interfaces/IExternalStakingVault.sol";
import {IYieldShift} from "../../interfaces/IYieldShift.sol";
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
    IYieldShift public yieldShift;
    uint256 public yieldVaultId;
    bytes32 public yieldSource;
    uint256 public principalDeposited;

    event MetaMorphoVaultUpdated(address indexed oldVault, address indexed newVault);
    event YieldShiftUpdated(address indexed oldYieldShift, address indexed newYieldShift);
    event YieldVaultIdUpdated(uint256 indexed oldVaultId, uint256 indexed newVaultId);
    event YieldSourceUpdated(bytes32 indexed oldSource, bytes32 indexed newSource);

    constructor(
        address admin,
        address usdc_,
        address metaMorphoVault_,
        address yieldShift_,
        uint256 yieldVaultId_,
        bytes32 yieldSource_
    ) {
        if (admin == address(0) || usdc_ == address(0) || metaMorphoVault_ == address(0) || yieldShift_ == address(0)) {
            revert CommonErrorLibrary.ZeroAddress();
        }
        if (yieldVaultId_ == 0) revert CommonErrorLibrary.InvalidVault();
        if (yieldSource_ == bytes32(0)) revert CommonErrorLibrary.InvalidAmount();
        if (IERC4626(metaMorphoVault_).asset() != usdc_) revert CommonErrorLibrary.InvalidAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(VAULT_MANAGER_ROLE, admin);

        USDC = IERC20(usdc_);
        metaMorphoVault = IERC4626(metaMorphoVault_);
        yieldShift = IYieldShift(yieldShift_);
        yieldVaultId = yieldVaultId_;
        yieldSource = yieldSource_;
    }

    /**
     * @notice Deposits USDC into the MetaMorpho ERC-4626 vault and tracks principal.
     * @param usdcAmount Amount of USDC to deposit.
     * @return sharesReceived MetaMorpho shares minted to this adapter.
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

        USDC.safeTransferFrom(msg.sender, address(this), usdcAmount);
        USDC.forceApprove(address(metaMorphoVault), usdcAmount);
        sharesReceived = metaMorphoVault.deposit(usdcAmount, address(this));
        USDC.forceApprove(address(metaMorphoVault), 0);

        if (sharesReceived == 0) revert CommonErrorLibrary.InvalidAmount();
        principalDeposited += usdcAmount;
    }

    /**
     * @notice Withdraws tracked principal from MetaMorpho and returns USDC to the caller.
     * @param usdcAmount Requested USDC amount.
     * @return usdcWithdrawn Actual USDC amount withdrawn.
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

        uint256 balanceBefore = USDC.balanceOf(address(this));
        uint256 sharesBurned = metaMorphoVault.withdraw(requested, address(this), address(this));
        if (sharesBurned == 0) revert CommonErrorLibrary.InvalidAmount();

        uint256 received = USDC.balanceOf(address(this)) - balanceBefore;
        if (received < requested) revert CommonErrorLibrary.InvalidAmount();

        principalDeposited -= requested;
        USDC.safeTransfer(msg.sender, requested);
        return requested;
    }

    /**
     * @notice Harvests accrued ERC-4626 share yield and routes it to YieldShift.
     * @return harvestedYield Yield harvested in USDC.
     */
    function harvestYield()
        external
        override
        onlyRole(VAULT_MANAGER_ROLE)
        nonReentrant
        returns (uint256 harvestedYield)
    {
        uint256 currentUnderlying = _totalUnderlying();
        if (currentUnderlying <= principalDeposited) return 0;

        uint256 availableYield = currentUnderlying - principalDeposited;
        uint256 liquidAssets = metaMorphoVault.maxWithdraw(address(this));
        harvestedYield = availableYield < liquidAssets ? availableYield : liquidAssets;
        if (harvestedYield == 0) return 0;

        uint256 balanceBefore = USDC.balanceOf(address(this));
        uint256 sharesBurned = metaMorphoVault.withdraw(harvestedYield, address(this), address(this));
        if (sharesBurned == 0) revert CommonErrorLibrary.InvalidAmount();

        uint256 received = USDC.balanceOf(address(this)) - balanceBefore;
        if (received < harvestedYield) revert CommonErrorLibrary.InvalidAmount();

        USDC.forceApprove(address(yieldShift), harvestedYield);
        yieldShift.addYield(yieldVaultId, harvestedYield, yieldSource);
        USDC.forceApprove(address(yieldShift), 0);
    }

    /**
     * @notice Returns the USDC value of this adapter's MetaMorpho shares.
     */
    function totalUnderlying() external view override returns (uint256 underlyingBalance) {
        return _totalUnderlying();
    }

    function setMetaMorphoVault(address newMetaMorphoVault) external onlyRole(GOVERNANCE_ROLE) {
        if (newMetaMorphoVault == address(0)) revert CommonErrorLibrary.ZeroAddress();
        if (IERC4626(newMetaMorphoVault).asset() != address(USDC)) revert CommonErrorLibrary.InvalidAddress();

        address oldVault = address(metaMorphoVault);
        metaMorphoVault = IERC4626(newMetaMorphoVault);
        emit MetaMorphoVaultUpdated(oldVault, newMetaMorphoVault);
    }

    function setYieldShift(address newYieldShift) external onlyRole(GOVERNANCE_ROLE) {
        if (newYieldShift == address(0)) revert CommonErrorLibrary.ZeroAddress();
        address oldYieldShift = address(yieldShift);
        yieldShift = IYieldShift(newYieldShift);
        emit YieldShiftUpdated(oldYieldShift, newYieldShift);
    }

    function setYieldVaultId(uint256 newYieldVaultId) external onlyRole(GOVERNANCE_ROLE) {
        if (newYieldVaultId == 0) revert CommonErrorLibrary.InvalidVault();
        uint256 old = yieldVaultId;
        yieldVaultId = newYieldVaultId;
        emit YieldVaultIdUpdated(old, newYieldVaultId);
    }

    function setYieldSource(bytes32 newYieldSource) external onlyRole(GOVERNANCE_ROLE) {
        if (newYieldSource == bytes32(0)) revert CommonErrorLibrary.InvalidAmount();
        bytes32 old = yieldSource;
        yieldSource = newYieldSource;
        emit YieldSourceUpdated(old, newYieldSource);
    }

    function _totalUnderlying() internal view returns (uint256) {
        return metaMorphoVault.convertToAssets(metaMorphoVault.balanceOf(address(this)));
    }
}
