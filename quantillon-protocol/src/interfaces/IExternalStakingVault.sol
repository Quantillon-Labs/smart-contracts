// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IExternalStakingVault
 * @notice Generic adapter interface for third-party staking/yield vaults.
 * @dev QuantillonVault interacts with all external yield sources through this surface.
 */
interface IExternalStakingVault {
    /**
     * @notice Deposits underlying USDC into the external vault.
     * @param usdcAmount Amount of USDC to deposit (6 decimals).
     * @return sharesReceived Adapter-specific share amount or accounting units received.
     */
    function depositUnderlying(uint256 usdcAmount) external returns (uint256 sharesReceived);

    /**
     * @notice Withdraws underlying USDC from the external vault.
     * @param usdcAmount Amount of USDC to withdraw (6 decimals).
     * @return usdcWithdrawn Actual USDC withdrawn.
     */
    function withdrawUnderlying(uint256 usdcAmount) external returns (uint256 usdcWithdrawn);

    /**
     * @notice Harvests yield and routes it to YieldShift using adapter-defined source semantics.
     * @return harvestedYield Yield harvested in USDC (6 decimals).
     */
    function harvestYield() external returns (uint256 harvestedYield);

    /**
     * @notice Returns total underlying value currently controlled by the adapter.
     * @return underlyingBalance Underlying USDC-equivalent balance (6 decimals).
     */
    function totalUnderlying() external view returns (uint256 underlyingBalance);
}
