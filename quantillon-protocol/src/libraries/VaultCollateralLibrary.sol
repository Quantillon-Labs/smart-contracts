// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
import {IExternalStakingVault} from "../interfaces/IExternalStakingVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CommonErrorLibrary as Errors} from "./CommonErrorLibrary.sol";

/// @notice Linked collateral helpers preserving loss-aware principal accounting.
library VaultCollateralLibrary {
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
     * @notice Sum external principal capped by each adapter's recoverable underlying.
     * @dev Returns the declared configuration or derived value without updating state.
     * @param adapters Vault storage mapping from IDs to adapters.
     * @param principal Vault storage mapping of tracked USDC principal.
     * @param priority Configured redemption order in vault storage.
     * @param defaultId Default vault used when no explicit redemption order exists.
     * @return total Value defined by this accessor or calculation.
     * @custom:security Read-only; does not authorize settlement.
     * @custom:validation Uses the declared input types; target interface calls may revert.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input or target read failures.
     * @custom:reentrancy Read-only.
     * @custom:access Public.
     * @custom:oracle No fresh observation is created; reference getters expose existing source data.
     */
    function collateral(mapping(uint256=>IExternalStakingVault) storage adapters, mapping(uint256=>uint256) storage principal, uint256[] storage priority, uint256 defaultId) external view returns (uint256 total) {
        if (priority.length == 0) return defaultId == 0 ? 0 : _value(adapters[defaultId], principal[defaultId]);
        for (uint256 i; i < priority.length; ++i) total += _value(adapters[priority[i]], principal[priority[i]]);
    }
    /**
     * @notice Require an enabled adapter belonging to the configured redemption set.
     * @dev Returns the declared configuration or derived value without updating state.
     * @param adapters Vault storage mapping from IDs to adapters.
     * @param enabled Enabled-vault mapping, or requested emergency state for the reference source.
     * @param priority Configured redemption order in vault storage.
     * @param defaultId Default vault used when no explicit redemption order exists.
     * @param id External vault identifier.
     * @custom:security Read-only; does not authorize settlement.
     * @custom:validation Uses the declared input types; target interface calls may revert.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input or target read failures.
     * @custom:reentrancy Read-only.
     * @custom:access Public.
     * @custom:oracle No fresh observation is created; reference getters expose existing source data.
     */
    function validateRouting(mapping(uint256=>IExternalStakingVault) storage adapters, mapping(uint256=>bool) storage enabled, uint256[] storage priority, uint256 defaultId, uint256 id) external view {
        if (id == 0) return;
        if (!enabled[id]) revert Errors.InvalidVault();
        if (address(adapters[id]) == address(0)) revert Errors.ZeroAddress();
        if (!_inSet(priority, defaultId, id)) revert Errors.InvalidVault();
    }
    /**
     * @notice Check whether an external vault belongs to the redemption set.
     * @dev Returns the declared configuration or derived value without updating state.
     * @param priority Configured redemption order in vault storage.
     * @param defaultId Default vault used when no explicit redemption order exists.
     * @param id External vault identifier.
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
    function inSet(uint256[] storage priority, uint256 defaultId, uint256 id) external view returns (bool) { return _inSet(priority, defaultId, id); }
    function _inSet(uint256[] storage priority, uint256 defaultId, uint256 id) private view returns (bool) {
        if (priority.length == 0) return id != 0 && id == defaultId;
        for (uint256 i; i < priority.length; ++i) if (priority[i] == id) return true;
        return false;
    }
    function _value(IExternalStakingVault adapter, uint256 principal) private view returns (uint256) {
        if (principal == 0) return 0;
        uint256 underlying = address(adapter) == address(0) ? 0 : adapter.totalUnderlying();
        return underlying < principal ? underlying : principal;
    }
    /**
     * @notice Transfer only the vault token balance exceeding accounted collateral.
     * @dev Invoked through the consumer; delegatecall retains its storage and original sender.
     * @param token Token whose balances and transfers are checked.
     * @param recipient Address receiving the output transfer.
     * @param held Accounted collateral that cannot be withdrawn as fees.
     * @custom:security Consumer permissions and accounting checks remain in force.
     * @custom:validation Applies the selected operation's bounds; failures revert the entire call.
     * @custom:state-changes Updates the calling consumer and downstream contracts as described above.
     * @custom:events Underlying operation and token events when applicable.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy The consuming operation retains its existing reentrancy guards.
     * @custom:access Consumer entrypoint permissions; this helper grants no additional authority.
     * @custom:oracle Uses the consumer's configured reference and execution paths where the operation requires pricing.
     */
    function withdrawFees(IERC20 token, address recipient, uint256 held) external {
        if (recipient == address(0)) revert Errors.InvalidAddress();
        uint256 balance = token.balanceOf(address(this));
        if (balance <= held) revert Errors.InsufficientBalance();
        token.safeTransfer(recipient, balance - held);
    }
}
