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
    function depositUnderlying(uint256 assets, address onBehalfOf) external returns (uint256 shares);
    function withdrawUnderlying(uint256 assets, address to) external returns (uint256 withdrawn);
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

    function depositUnderlying(uint256 usdcAmount) external override onlyRole(VAULT_MANAGER_ROLE) nonReentrant returns (uint256 sharesReceived) {
        if (usdcAmount == 0) revert CommonErrorLibrary.InvalidAmount();
        principalDeposited += usdcAmount;

        USDC.safeTransferFrom(msg.sender, address(this), usdcAmount);
        USDC.safeIncreaseAllowance(address(morphoVault), usdcAmount);
        sharesReceived = morphoVault.depositUnderlying(usdcAmount, address(this));
        if (sharesReceived == 0) revert CommonErrorLibrary.InvalidAmount();
    }

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

    function harvestYield() external override onlyRole(VAULT_MANAGER_ROLE) nonReentrant returns (uint256 harvestedYield) {
        uint256 currentUnderlying = morphoVault.totalUnderlyingOf(address(this));
        if (currentUnderlying <= principalDeposited) return 0;

        uint256 availableYield = currentUnderlying - principalDeposited;
        harvestedYield = morphoVault.withdrawUnderlying(availableYield, address(this));
        if (harvestedYield == 0) return 0;

        USDC.safeIncreaseAllowance(address(yieldShift), harvestedYield);
        yieldShift.addYield(yieldVaultId, harvestedYield, bytes32("morpho"));
    }

    function totalUnderlying() external view override returns (uint256 underlyingBalance) {
        return morphoVault.totalUnderlyingOf(address(this));
    }

    function setMorphoVault(address newMorphoVault) external onlyRole(GOVERNANCE_ROLE) {
        if (newMorphoVault == address(0)) revert CommonErrorLibrary.ZeroAddress();
        address oldVault = address(morphoVault);
        morphoVault = IMockMorphoVault(newMorphoVault);
        emit MorphoVaultUpdated(oldVault, newMorphoVault);
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
}
