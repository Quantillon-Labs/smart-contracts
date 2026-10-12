// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {SignedReferenceSource} from "../oracle/SignedReferenceSource.sol";
import {SignedQuoteTypes as T} from "./SignedQuoteTypes.sol";
import {SignedQuoteErrors as E} from "./SignedQuoteErrors.sol";

/// @notice Resolve the reference from the consumer's governed oracle binding.
interface IReferenceConsumer {
    /**
     * @notice Read the consumer's governed oracle address.
     * @dev Returns the declared configuration or derived value without updating state.
     * @return Value defined by this accessor or calculation.
     * @custom:security Read-only; does not authorize settlement.
     * @custom:validation Uses the declared input types; target interface calls may revert.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input or target read failures.
     * @custom:reentrancy Read-only.
     * @custom:access Public.
     * @custom:oracle No fresh observation is created; reference getters expose existing source data.
     */
    function oracle() external view returns (address);
}

/// @notice Router reference bindings, independent of execution quotes.
interface IReferenceRouter {
    /**
     * @notice Read the router's active oracle slot.
     * @dev Returns the declared configuration or derived value without updating state.
     * @return Value defined by this accessor or calculation.
     * @custom:security Read-only; does not authorize settlement.
     * @custom:validation Uses the declared input types; target interface calls may revert.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input or target read failures.
     * @custom:reentrancy Read-only.
     * @custom:access Public.
     * @custom:oracle No fresh observation is created; reference getters expose existing source data.
     */
    function activeOracle() external view returns (uint8);
    /**
     * @notice Read the router's market-oracle address.
     * @dev Returns the declared configuration or derived value without updating state.
     * @return Value defined by this accessor or calculation.
     * @custom:security Read-only; does not authorize settlement.
     * @custom:validation Uses the declared input types; target interface calls may revert.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input or target read failures.
     * @custom:reentrancy Read-only.
     * @custom:access Public.
     * @custom:oracle No fresh observation is created; reference getters expose existing source data.
     */
    function marketOracle() external view returns (address);
}

/// @notice The existing Hyperliquid adapter owns the source binding.
interface IReferenceAdapter {
    /**
     * @notice Read the market adapter's governed snapshot-source address.
     * @dev Returns the declared configuration or derived value without updating state.
     * @return Value defined by this accessor or calculation.
     * @custom:security Read-only; does not authorize settlement.
     * @custom:validation Uses the declared input types; target interface calls may revert.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input or target read failures.
     * @custom:reentrancy Read-only.
     * @custom:access Public.
     * @custom:oracle No fresh observation is created; reference getters expose existing source data.
     */
    function slippageStorage() external view returns (address);
}

/// @title ReferenceSettlementLibrary
/// @notice Carry a signed valuation report with a hedger operation without changing its caller.
/// @dev Linked delegatecall preserves Safe, hedger ownership, role and existing reentrancy checks.
library ReferenceSettlementLibrary {
    /**
     * @notice Return the semantic version of this implementation.
     * @dev Returns the declared configuration or derived value without updating state.
     * @return Value defined by this accessor or calculation.
     * @custom:security Read-only; does not authorize settlement.
     * @custom:validation Uses the declared input types; target interface calls may revert.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input or target read failures.
     * @custom:reentrancy Read-only.
     * @custom:access Public.
     * @custom:oracle No fresh observation is created; reference getters expose existing source data.
     */
    function version() external pure returns (string memory) { return "1.0.0"; }

    /**
     * @notice Deliver a signed reference and execute one permitted hedger operation atomically.
     * @dev Invoked through the consumer; delegatecall retains its storage and original sender.
     * @param callData Complete ABI-encoded operation, including route and output bounds.
     * @param authorization ABI-encoded report or quote authorization required by this entrypoint.
     * @return result ABI-encoded return data of the dispatched operation.
     * @custom:security Consumer permissions and accounting checks remain in force.
     * @custom:validation Applies the selected operation's bounds; failures revert the entire call.
     * @custom:state-changes Updates the calling consumer and downstream contracts as described above.
     * @custom:events Underlying operation and token events when applicable.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy The consuming operation retains its existing reentrancy guards.
     * @custom:access Consumer entrypoint permissions; this helper grants no additional authority.
     * @custom:oracle Uses the consumer's configured reference and execution paths where the operation requires pricing.
     */
    function executeWithReference(bytes calldata callData, bytes calldata authorization) external returns (bytes memory result) {
        if (callData.length < 4) revert E.InvalidBinding();
        bytes4 selector = bytes4(callData[:4]);
        if (selector != bytes4(keccak256("enterHedgePosition(uint256,uint256)"))
            && selector != bytes4(keccak256("exitHedgePosition(uint256)"))
            && selector != bytes4(keccak256("removeMargin(uint256,uint256)"))
            && selector != bytes4(keccak256("emergencyClosePosition(address,uint256)"))) revert E.InvalidBinding();
        IReferenceRouter router = IReferenceRouter(IReferenceConsumer(address(this)).oracle());
        if (router.activeOracle() != 1) revert E.InvalidMode();
        address source = IReferenceAdapter(router.marketOracle()).slippageStorage();
        (T.ReferenceReport memory report, bytes memory signature) = abi.decode(authorization, (T.ReferenceReport, bytes));
        SignedReferenceSource(source).submit(report, signature);
        bool success;
        (success, result) = address(this).delegatecall(callData);
        if (!success) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
    }
}
