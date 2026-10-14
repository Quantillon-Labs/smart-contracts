// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
import {SignedQuoteErrors as E} from "./SignedQuoteErrors.sol";
interface IQuotePoolVault {
    /**
     * @notice Begin an atomic pool route bound to its original user and complete calldata.
     * @dev Invoked through the consumer; delegatecall retains its storage and original sender.
     * @param user Original payer whose nonce and settlement are bound.
     * @param callData Complete ABI-encoded operation, including route and output bounds.
     * @param authorization ABI-encoded report or quote authorization required by this entrypoint.
     * @custom:security Consumer permissions and accounting checks remain in force.
     * @custom:validation Applies the selected operation's bounds; failures revert the entire call.
     * @custom:state-changes Updates the calling consumer and downstream contracts as described above.
     * @custom:events None.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy The consuming operation retains its existing reentrancy guards.
     * @custom:access Consumer entrypoint permissions; this helper grants no additional authority.
     * @custom:oracle Uses the consumer's configured reference and execution paths where the operation requires pricing.
     */
    function preparePoolQuote(address user, bytes calldata callData, bytes calldata authorization) external;
    /**
     * @notice Finish the atomic pool route after its conversion has been consumed.
     * @dev Invoked through the consumer; delegatecall retains its storage and original sender.
     * @custom:security Consumer permissions and accounting checks remain in force.
     * @custom:validation Applies the selected operation's bounds; failures revert the entire call.
     * @custom:state-changes Updates the calling consumer and downstream contracts as described above.
     * @custom:events None.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy The consuming operation retains its existing reentrancy guards.
     * @custom:access Consumer entrypoint permissions; this helper grants no additional authority.
     * @custom:oracle Uses the consumer's configured reference and execution paths where the operation requires pricing.
     */
    function finishPoolQuote() external;
}
/// @notice Linked UserPool wrapper, preserving sender, existing guards and storage layout.
library SignedUserPoolLibrary {
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
     * @notice Dispatch the permitted operation while preserving the consumer's original caller.
     * @dev Invoked through the consumer; delegatecall retains its storage and original sender.
     * @param vault Configured vault that owns execution authorization.
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
    function execute(address vault, bytes calldata callData, bytes calldata authorization) external returns (bytes memory result) {
        if (callData.length < 4) revert E.InvalidBinding();
        bytes4 selector = bytes4(callData[:4]);
        if (selector != bytes4(keccak256("deposit(uint256[],uint256[])")) && selector != bytes4(keccak256("withdraw(uint256[],uint256[])"))) revert E.InvalidBinding();
        IQuotePoolVault(vault).preparePoolQuote(msg.sender, callData, authorization);
        bool success;
        (success, result) = address(this).delegatecall(callData);
        if (!success) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        IQuotePoolVault(vault).finishPoolQuote();
    }
}
