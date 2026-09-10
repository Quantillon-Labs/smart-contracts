// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IExecutionPricing} from "../interfaces/IExecutionPricing.sol";
import {CommonErrorLibrary as Errors} from "./CommonErrorLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IHedgerPool} from "../interfaces/IHedgerPool.sol";
import {IQuantillonVault} from "../interfaces/IQuantillonVault.sol";
import {FeeCollector} from "../core/FeeCollector.sol";
import {PriceValidationLibrary} from "./PriceValidationLibrary.sol";
import {HedgerPoolErrorLibrary} from "./HedgerPoolErrorLibrary.sol";

/// @notice Reference collateral read used by linked vault calculations.
interface IExecutionCollateralView {
    /**
     * @notice Read reference-accounted collateral available to the vault.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @return result Value returned by the read interface.
     * @custom:security Uses explicit contract access boundaries and checked arithmetic.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy No state changes.
     * @custom:access Public read access.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function getTotalUsdcAvailable() external view returns (uint256);
}

/// @title ExecutionPricingLibrary
/// @notice Linked vault integration for volume pricing, preserving reference accounting.
library ExecutionPricingLibrary {
    using SafeERC20 for IERC20;
    event ProtocolFeeRouted(string sourceType, uint256 totalFee, uint256 hedgerReserveShare, uint256 collectorShare);
    event PriceDeviationDetected(uint256 currentPrice, uint256 lastValidPrice, uint256 deviationBps, uint256 blockNumber);
    /**
     * @notice Linked library semantic version.
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
    function version() external pure returns (string memory) { return "1.0.1"; }

    /**
     * @notice Calculate and consume a mint quote, reverting below the user's floor.
     * @param module Configured pricing module, or zero before activation.
     * @param input Gross USDC input.
     * @param feeRate Protocol fee fraction in 18 decimals.
     * @param ref Reference EUR/USD price in 18 decimals.
     * @param minimum Minimum QEURO output in 18 decimals.
     * @return fee Protocol fee in USDC.
     * @return backing Net reference backing in USDC.
     * @return q QEURO output.
     * @custom:security Called by delegatecall from the guarded vault flow.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes Applies the effects described above.
     * @custom:events Emits the events described above when applicable.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy Vault settlement is nonReentrant; publisher and reporter methods have no external state-changing callbacks.
     * @custom:access Called from the guarded vault flow.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function mint(IExecutionPricing module, uint256 input, uint256 feeRate, uint256 ref, uint256 minimum)
        external returns (uint256 fee, uint256 backing, uint256 q)
    {
        fee = Math.mulDiv(input, feeRate, 1e18);
        backing = input - fee;
        if (address(module) == address(0)) q = Math.mulDiv(backing, 1e30, ref);
        else (q, backing) = module.consumeMint(backing, ref);
        if (q < minimum) revert Errors.ExcessiveSlippage();
    }

    /**
     * @notice Calculate and consume a normal redemption quote.
     * @param module Configured pricing module, or zero before activation.
     * @param q QEURO input in 18 decimals.
     * @param feeRate Protocol fee fraction in 18 decimals.
     * @param ref Reference EUR/USD price in 18 decimals.
     * @param minimum Minimum USDC output in 6 decimals.
     * @return gross Reference-valued collateral removed.
     * @return net User payout after execution spread and protocol fee.
     * @return fee Protocol fee in USDC.
     * @custom:security No execution cost is charged twice; gross = net + fee + spread.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes Applies the effects described above.
     * @custom:events Emits the events described above when applicable.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy Vault settlement is nonReentrant; publisher and reporter methods have no external state-changing callbacks.
     * @custom:access Called from the guarded vault flow.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function redeem(IExecutionPricing module, uint256 q, uint256 feeRate, uint256 ref, uint256 minimum)
        external returns (uint256 gross, uint256 net, uint256 fee)
    {
        gross = Math.mulDiv(q, ref, 1e30);
        fee = Math.mulDiv(gross, feeRate, 1e18);
        uint256 execution = address(module) == address(0) ? gross : module.consumeRedeem(q, ref);
        if (execution < fee) revert Errors.InvalidAmount();
        net = execution - fee;
        if (net < minimum) revert Errors.ExcessiveSlippage();
    }

    /**
     * @notice Check a governance module transition without discarding pending exposure.
     * @param previous Previous configured module.
     * @param next Proposed module, or zero to deactivate.
     * @custom:security The vault enforces governance and pause requirements before delegation.
     * @dev Read-only contract interface.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy No state changes.
     * @custom:access Public read access.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function validateConfiguration(IExecutionPricing previous, address next) external view {
        if (address(previous) != address(0) && previous.outstanding() != 0) revert Errors.InvalidCondition();
        if (next != address(0) && IExecutionPricing(next).vault() != address(this)) revert Errors.InvalidVault();
    }

    /**
     * @notice Route protocol fees independently of execution spreads.
     * @param token USDC token.
     * @param fee Protocol fee amount.
     * @param split Hedger reward fraction in 18 decimals.
     * @param hedger Hedger reward pool.
     * @param collector Protocol fee collector.
     * @param source Accounting source tag.
     * @custom:security Delegatecalled within the vault's guarded settlement flow.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes Applies the effects described above.
     * @custom:events Emits the events described above when applicable.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy Vault settlement is nonReentrant; publisher and reporter methods have no external state-changing callbacks.
     * @custom:access Called from the guarded vault flow.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function routeFees(IERC20 token, uint256 fee, uint256 split, IHedgerPool hedger, address collector, string memory source) external {
        if (fee == 0) return;
        uint256 hedgerShare = Math.mulDiv(fee, split, 1e18);
        uint256 collectorShare = fee - hedgerShare;
        if (hedgerShare > 0) {
            if (address(hedger) == address(0)) revert Errors.InvalidVault();
            token.safeIncreaseAllowance(address(hedger), hedgerShare);
            hedger.fundRewardReserve(hedgerShare);
        }
        if (collectorShare > 0) {
            if (collector == address(0)) revert Errors.ZeroAddress();
            token.safeIncreaseAllowance(collector, collectorShare);
            FeeCollector(collector).collectFees(address(token), collectorShare, source);
        }
        emit ProtocolFeeRouted(source, fee, hedgerShare, collectorShare);
    }

    /**
     * @notice Enforce the vault's existing reference-price deviation policy.
     * @param price Live reference price.
     * @param previous Cached reference price.
     * @param lastBlock Block of the previous cache update.
     * @custom:security Preserves the 200 bps and one-block policy independently of execution pricing.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes Applies the effects described above.
     * @custom:events Emits the events described above when applicable.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy Vault settlement is nonReentrant; publisher and reporter methods have no external state-changing callbacks.
     * @custom:access Called from the guarded vault flow.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function enforceDeviation(uint256 price, uint256 previous, uint256 lastBlock) external {
        (bool invalid, uint256 bps) = PriceValidationLibrary.checkPriceDeviation(price, previous, 200, lastBlock, 1);
        if (invalid) {
            emit PriceDeviationDetected(price, previous, bps, block.number);
            revert Errors.ExcessiveSlippage();
        }
    }

    /**
     * @notice Validate projected reference-valued collateralization.
     * @param collateral Projected collateral in USDC units.
     * @param supply Projected QEURO supply.
     * @param price Reference price.
     * @param minimum Minimum collateralization percentage scaled by 1e18.
     * @custom:security Execution spread reserves are excluded by the caller.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy No state changes.
     * @custom:access Public read access.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function enforceCollateralization(uint256 collateral, uint256 supply, uint256 price, uint256 minimum) external pure {
        uint256 backing = Math.mulDiv(supply, price, 1e30);
        if (backing == 0) revert Errors.InvalidAmount();
        if (Math.mulDiv(collateral, 1e20, backing) < minimum) revert Errors.InsufficientCollateralization();
    }

    /**
     * @notice Compute the reference-valued collateralization ratio for the calling vault.
     * @param token QEURO token used for total circulating supply.
     * @param price Reference USD per EUR price.
     * @return ratio Percentage scaled by 1e18, or zero for absent backing.
     * @custom:security Reads collateral only after nonzero reference backing is established.
     * @dev Uses the documented units and preserves reference-price accounting.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy No state changes.
     * @custom:access Public read access.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function collateralizationRatio(IERC20 token, uint256 price) public view returns (uint256 ratio) {
        uint256 supply = token.totalSupply();
        if (supply == 0 || price == 0) return 0;
        uint256 backing = Math.mulDiv(supply, price, 1e30);
        if (backing == 0) return 0;
        return (IExecutionCollateralView(address(this)).getTotalUsdcAvailable() * 1e20) / backing;
    }

    /**
     * @notice Enforce initialized pricing, active hedging and the live mint floor.
     * @param token QEURO token.
     * @param hedger Configured hedger pool.
     * @param cached Previously initialized reference price.
     * @param price Live reference price.
     * @param minimum Minimum collateralization percentage scaled by 1e18.
     * @custom:security Preserves the vault's bounded dust-supply bootstrap behavior.
     * @dev Read-only contract interface.
     * @custom:validation Validates the documented preconditions; view interface reads delegate to the target contract.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input, freshness, capacity or downstream contract errors as applicable.
     * @custom:reentrancy No state changes.
     * @custom:access Public read access.
     * @custom:oracle Reference EUR/USD and observed venue depth where required; no oracle dependency for role and version reads.
     */
    function enforceMintEligibility(IERC20 token, IHedgerPool hedger, uint256 cached, uint256 price, uint256 minimum) external view {
        if (cached == 0) revert Errors.NotInitialized();
        if (address(hedger) == address(0) || !hedger.hasActiveHedger()) revert HedgerPoolErrorLibrary.NoActiveHedgerLiquidity();
        if (token.totalSupply() > 1e12 && (IQuantillonVault(address(this)).userPool() == address(0) || collateralizationRatio(token, price) < minimum)) revert Errors.InsufficientCollateralization();
    }
}
