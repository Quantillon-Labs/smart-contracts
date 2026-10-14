// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IstQEURO} from "../interfaces/IstQEURO.sol";
import {CommonErrorLibrary as Errors} from "./CommonErrorLibrary.sol";
import {SignedQuoteErrors as E} from "./SignedQuoteErrors.sol";
import {SignedExecutionPricing} from "../oracle/SignedExecutionPricing.sol";
import {SignedQuoteTypes as T} from "./SignedQuoteTypes.sol";

interface IQuoteVaultView {
    /**
     * @notice Read whether the vault requires signed settlement.
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
    function signedExecutionEnabled() external view returns (bool);
    /**
     * @notice Read the configured UserPool address.
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
    function userPool() external view returns (address);
    /**
     * @notice Read the configured execution module address.
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
    function executionPricing() external view returns (address);
}

/// @title SignedSettlementLibrary
/// @notice Linked entrypoint that keeps signature decoding outside the size-constrained vault.
/// @dev Delegatecall retains the original payer and the existing guarded settlement functions.
library SignedSettlementLibrary {
    using SafeERC20 for IERC20;
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
     * @notice Dispatch one signed operation with the original caller and existing accounting.
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
    function executeWithQuote(bytes calldata callData, bytes calldata authorization) external returns (bytes memory result) {
        return _execute(IQuoteVaultView(address(this)).executionPricing(), callData, authorization);
    }
    /**
     * @notice Begin an atomic pool route bound to its original user and complete calldata.
     * @dev Invoked through the consumer; delegatecall retains its storage and original sender.
     * @param user Original payer whose nonce and settlement are bound.
     * @param callData Complete ABI-encoded operation, including route and output bounds.
     * @param authorization ABI-encoded report or quote authorization required by this entrypoint.
     * @custom:security Consumer permissions and accounting checks remain in force.
     * @custom:validation Applies the selected operation's bounds; failures revert the entire call.
     * @custom:state-changes Updates the calling consumer and downstream contracts as described above.
     * @custom:events Underlying operation and token events when applicable.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy The consuming operation retains its existing reentrancy guards.
     * @custom:access Consumer entrypoint permissions; this helper grants no additional authority.
     * @custom:oracle Uses the consumer's configured reference and execution paths where the operation requires pricing.
     */
    function preparePoolQuote(address user, bytes calldata callData, bytes calldata authorization) external {
        _preparePool(IQuoteVaultView(address(this)).executionPricing(), user, callData, authorization);
    }
    /**
     * @notice Finish the atomic pool route after its conversion has been consumed.
     * @dev Invoked through the consumer; delegatecall retains its storage and original sender.
     * @custom:security Consumer permissions and accounting checks remain in force.
     * @custom:validation Applies the selected operation's bounds; failures revert the entire call.
     * @custom:state-changes Updates the calling consumer and downstream contracts as described above.
     * @custom:events Underlying operation and token events when applicable.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy The consuming operation retains its existing reentrancy guards.
     * @custom:access Consumer entrypoint permissions; this helper grants no additional authority.
     * @custom:oracle Uses the consumer's configured reference and execution paths where the operation requires pricing.
     */
    function finishPoolQuote() external {
        _finishPool(IQuoteVaultView(address(this)).executionPricing());
    }
    /**
     * @notice Run the governed budgeted emergency redemption path.
     * @dev Invoked through the consumer; delegatecall retains its storage and original sender.
     * @param amount Amount in the token units of the selected operation.
     * @param minimum Minimum acceptable output in the output token's raw units.
     * @custom:security Consumer permissions and accounting checks remain in force.
     * @custom:validation Applies the selected operation's bounds; failures revert the entire call.
     * @custom:state-changes Updates the calling consumer and downstream contracts as described above.
     * @custom:events Underlying operation and token events when applicable.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy The consuming operation retains its existing reentrancy guards.
     * @custom:access Consumer entrypoint permissions; this helper grants no additional authority.
     * @custom:oracle Uses the consumer's configured reference and execution paths where the operation requires pricing.
     */
    function emergencyRedeemQEURO(uint256 amount, uint256 minimum) external {
        _emergencyRedeem(IQuoteVaultView(address(this)).executionPricing(), amount, minimum);
    }

    /**
     * @notice Dispatch the permitted operation while preserving the consumer's original caller.
     * @dev Invoked through the consumer; delegatecall retains its storage and original sender.
     * @param module Execution module already bound by the calling vault.
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
    function execute(address module, bytes calldata callData, bytes calldata authorization) external returns (bytes memory result) {
        return _execute(module, callData, authorization);
    }
    function _execute(address module, bytes calldata callData, bytes calldata authorization) private returns (bytes memory result) {
        if (!IQuoteVaultView(address(this)).signedExecutionEnabled()) revert E.InvalidMode();
        T.Authorization memory auth = abi.decode(authorization, (T.Authorization));
        SignedExecutionPricing(module).prepare(msg.sender, msg.sender, callData, auth);
        result = _dispatch(callData);
        SignedExecutionPricing(module).finish(auth.quote.action == T.Action.Yield);
    }

    function _preparePool(address module, address user, bytes calldata callData, bytes calldata authorization) private {
        if (!IQuoteVaultView(address(this)).signedExecutionEnabled() || msg.sender != IQuoteVaultView(address(this)).userPool()) revert E.InvalidBinding();
        T.Authorization memory auth = abi.decode(authorization, (T.Authorization));
        SignedExecutionPricing(module).prepare(user, msg.sender, callData, auth);
    }

    /**
     * @notice Run the vault redemption with a bounded emergency context.
     * @dev Invoked through the consumer; delegatecall retains its storage and original sender.
     * @param module Execution module already bound by the calling vault.
     * @param amount Amount in the token units of the selected operation.
     * @param minimum Minimum acceptable output in the output token's raw units.
     * @custom:security Consumer permissions and accounting checks remain in force.
     * @custom:validation Applies the selected operation's bounds; failures revert the entire call.
     * @custom:state-changes Updates the calling consumer and downstream contracts as described above.
     * @custom:events Underlying operation and token events when applicable.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy The consuming operation retains its existing reentrancy guards.
     * @custom:access Consumer entrypoint permissions; this helper grants no additional authority.
     * @custom:oracle Uses the consumer's configured reference and execution paths where the operation requires pricing.
     */
    function emergencyRedeem(address module, uint256 amount, uint256 minimum) external {
        _emergencyRedeem(module, amount, minimum);
    }
    function _emergencyRedeem(address module, uint256 amount, uint256 minimum) private {
        if (!IQuoteVaultView(address(this)).signedExecutionEnabled()) revert E.InvalidMode();
        SignedExecutionPricing(module).prepareEmergency(msg.sender, amount);
        _dispatch(abi.encodeWithSignature("redeemQEURO(uint256,uint256)", amount, minimum));
        SignedExecutionPricing(module).finish(false);
    }

    function _finishPool(address module) private {
        if (!IQuoteVaultView(address(this)).signedExecutionEnabled() || msg.sender != IQuoteVaultView(address(this)).userPool()) revert E.InvalidBinding();
        SignedExecutionPricing(module).finish(false);
    }

    /**
     * @notice Deposit newly minted QEURO and enforce the actual minimum share output.
     * @dev Invoked through the consumer; delegatecall retains its storage and original sender.
     * @param token Token whose balances and transfers are checked.
     * @param shares stQEURO share token receiving the deposit.
     * @param amount Amount in the token units of the selected operation.
     * @param minimum Minimum acceptable output in the output token's raw units.
     * @return minted Value defined by this accessor or calculation.
     * @custom:security Consumer permissions and accounting checks remain in force.
     * @custom:validation Applies the selected operation's bounds; failures revert the entire call.
     * @custom:state-changes Updates the calling consumer and downstream contracts as described above.
     * @custom:events Underlying operation and token events when applicable.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy The consuming operation retains its existing reentrancy guards.
     * @custom:access Consumer entrypoint permissions; this helper grants no additional authority.
     * @custom:oracle Uses the consumer's configured reference and execution paths where the operation requires pricing.
     */
    function stake(address token, address shares, uint256 amount, uint256 minimum) external returns (uint256 minted) {
        if (shares == address(0)) revert Errors.InvalidVault();
        IERC20(token).safeIncreaseAllowance(shares, amount);
        minted = IstQEURO(shares).previewDeposit(amount);
        if (minted == 0) revert Errors.InvalidAmount();
        if (minted < minimum) revert Errors.ExcessiveSlippage();
        minted = IstQEURO(shares).deposit(amount, msg.sender);
        if (minted < minimum || minted == 0) revert Errors.ExcessiveSlippage();
    }

    function _dispatch(bytes memory callData) private returns (bytes memory result) {
        bool success;
        (success, result) = address(this).delegatecall(callData);
        if (!success) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
    }
}
