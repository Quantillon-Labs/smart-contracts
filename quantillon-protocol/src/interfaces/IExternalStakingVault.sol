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
     * @dev Adapter entrypoint used by QuantillonVault for principal deployment.
     * @param usdcAmount Amount of USDC to deposit (6 decimals).
     * @return sharesReceived Adapter-specific share amount or accounting units received.
     * @custom:security Implementations should restrict unauthorized callers.
     * @custom:validation Implementations should validate non-zero amount and integration readiness.
     * @custom:state-changes Typically increases adapter-held principal and downstream vault position.
     * @custom:events Implementations should emit deposit/accounting events.
     * @custom:errors Reverts on invalid input or downstream integration failure.
     * @custom:reentrancy Implementations should enforce CEI/nonReentrant where needed.
     * @custom:access Access control is implementation-defined.
     * @custom:oracle No mandatory oracle dependency at interface level.
     */
    function depositUnderlying(uint256 usdcAmount) external returns (uint256 sharesReceived);

    /**
     * @notice Withdraws underlying USDC from the external vault.
     * @dev Adapter entrypoint used by QuantillonVault for redemption liquidity.
     * @param usdcAmount Amount of USDC to withdraw (6 decimals).
     * @return usdcWithdrawn Actual USDC withdrawn.
     * @custom:security Implementations should restrict unauthorized callers.
     * @custom:validation Implementations should validate amount and available liquidity.
     * @custom:state-changes Typically decreases adapter-held principal and returns USDC.
     * @custom:events Implementations should emit withdrawal/accounting events.
     * @custom:errors Reverts on invalid input or downstream integration failure.
     * @custom:reentrancy Implementations should enforce CEI/nonReentrant where needed.
     * @custom:access Access control is implementation-defined.
     * @custom:oracle No mandatory oracle dependency at interface level.
     */
    function withdrawUnderlying(uint256 usdcAmount) external returns (uint256 usdcWithdrawn);

    /**
     * @notice Harvests yield and routes it to YieldShift using adapter-defined source semantics.
     * @dev Realizes accrued yield without withdrawing tracked principal.
     * @return harvestedYield Yield harvested in USDC (6 decimals).
     * @custom:security Implementations should restrict unauthorized callers.
     * @custom:validation Implementations should validate source state before harvesting.
     * @custom:state-changes Typically realizes yield and routes it to downstream distribution logic.
     * @custom:events Implementations should emit harvest/yield-routing events.
     * @custom:errors Reverts on invalid state or downstream integration failure.
     * @custom:reentrancy Implementations should enforce CEI/nonReentrant where needed.
     * @custom:access Access control is implementation-defined.
     * @custom:oracle No mandatory oracle dependency at interface level.
     */
    function harvestYield() external returns (uint256 harvestedYield);

    /**
     * @notice Returns total underlying value currently controlled by the adapter.
     * @dev View helper for exposure accounting (principal + accrued yield).
     * @return underlyingBalance Underlying USDC-equivalent balance (6 decimals).
     * @custom:security Read-only helper.
     * @custom:validation No input validation required.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors Implementations may revert on unavailable downstream reads.
     * @custom:reentrancy Not applicable for view function.
     * @custom:access Public view.
     * @custom:oracle Oracle use is implementation-defined.
     */
    function totalUnderlying() external view returns (uint256 underlyingBalance);
}
