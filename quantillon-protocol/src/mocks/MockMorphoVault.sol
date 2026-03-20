// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title MockMorphoVault
 * @notice Localhost-only mock that emulates a third-party Morpho-like USDC vault.
 * @dev Tracks principal-like balances by account and supports synthetic yield injection.
 */
contract MockMorphoVault {
    using SafeERC20 for IERC20;

    IERC20 public immutable USDC;
    mapping(address => uint256) public shareBalanceOf;
    uint256 public totalShares;

    event Deposited(address indexed caller, address indexed onBehalfOf, uint256 assets);
    event Withdrawn(address indexed caller, address indexed to, uint256 assets);
    event YieldInjected(address indexed from, uint256 amount);

    constructor(address usdc_) {
        USDC = IERC20(usdc_);
    }

    function depositUnderlying(uint256 assets, address onBehalfOf) external returns (uint256 shares) {
        if (assets == 0 || onBehalfOf == address(0)) return 0;
        uint256 assetsBefore = totalAssets();
        USDC.safeTransferFrom(msg.sender, address(this), assets);
        if (totalShares == 0 || assetsBefore == 0) {
            shares = assets;
        } else {
            shares = (assets * totalShares) / assetsBefore;
        }
        if (shares == 0) return 0;
        shareBalanceOf[onBehalfOf] += shares;
        totalShares += shares;
        emit Deposited(msg.sender, onBehalfOf, assets);
    }

    function withdrawUnderlying(uint256 assets, address to) external returns (uint256 withdrawn) {
        if (assets == 0 || to == address(0)) return 0;
        uint256 assetsBefore = totalAssets();
        if (assetsBefore == 0 || totalShares == 0) return 0;
        uint256 maxAssets = (shareBalanceOf[msg.sender] * assetsBefore) / totalShares;
        withdrawn = assets > maxAssets ? maxAssets : assets;
        if (withdrawn == 0) return 0;

        uint256 burnedShares = (withdrawn * totalShares + assetsBefore - 1) / assetsBefore;
        if (burnedShares > shareBalanceOf[msg.sender]) {
            burnedShares = shareBalanceOf[msg.sender];
        }
        shareBalanceOf[msg.sender] -= burnedShares;
        totalShares -= burnedShares;
        USDC.safeTransfer(to, withdrawn);
        emit Withdrawn(msg.sender, to, withdrawn);
    }

    function injectYield(uint256 amount) external {
        if (amount == 0) return;
        USDC.safeTransferFrom(msg.sender, address(this), amount);
        emit YieldInjected(msg.sender, amount);
    }

    function totalAssets() public view returns (uint256) {
        return USDC.balanceOf(address(this));
    }

    function totalUnderlyingOf(address account) external view returns (uint256) {
        if (totalShares == 0) return 0;
        return (shareBalanceOf[account] * totalAssets()) / totalShares;
    }
}
