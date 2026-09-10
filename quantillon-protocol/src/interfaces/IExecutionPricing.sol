// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IExecutionPricing
/// @notice Volume-dependent execution pricing and admission for a single vault.
interface IExecutionPricing {
    /**
     * @notice Vault authorized to consume quoted liquidity.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @return result Calculated result in the units described by this operation.
     * @custom:security Uses explicit contract access boundaries and checked arithmetic.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy No state changes.
     * @custom:access Public read access.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function vault() external view returns (address);
    /**
     * @notice Total admitted EUR exposure awaiting acknowledgment, in 18 decimals.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @return result Calculated result in the units described by this operation.
     * @custom:security Uses explicit contract access boundaries and checked arithmetic.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy No state changes.
     * @custom:access Public read access.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function outstanding() external view returns (uint256);
    /**
     * @notice Consume buy liquidity for net USDC input (6 decimals).
     * @param netUsdc Input after protocol fees.
     * @param referencePrice Reference USD per EUR in 18 decimals.
     * @return qeuroOut Minted quantity in 18 decimals.
     * @return backingUsdc Reference-valued backing in 6 decimals.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @custom:security Uses explicit contract access boundaries and checked arithmetic.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes Updates consumed liquidity counters.
     * @custom:events LiquidityConsumed.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy Vault settlement is nonReentrant; publisher and reporter methods have no external state-changing callbacks.
     * @custom:access Configured vault only.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function consumeMint(uint256 netUsdc, uint256 referencePrice) external returns (uint256 qeuroOut, uint256 backingUsdc);
    /**
     * @notice Consume sell liquidity for QEURO input (18 decimals).
     * @param qeuroIn Quantity redeemed.
     * @param referencePrice Reference USD per EUR in 18 decimals.
     * @return executionUsdc Payout before protocol fees, in 6 decimals.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @custom:security Uses explicit contract access boundaries and checked arithmetic.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes Updates consumed liquidity counters.
     * @custom:events LiquidityConsumed.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy Vault settlement is nonReentrant; publisher and reporter methods have no external state-changing callbacks.
     * @custom:access Configured vault only.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function consumeRedeem(uint256 qeuroIn, uint256 referencePrice) external returns (uint256 executionUsdc);
}
