// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IQEUROToken} from "../interfaces/IQEUROToken.sol";
import {IHedgerPool} from "../interfaces/IHedgerPool.sol";
import {IExternalStakingVault} from "../interfaces/IExternalStakingVault.sol";
import {ExecutionPricingLibrary} from "./ExecutionPricingLibrary.sol";
import {CommonErrorLibrary as Errors} from "./CommonErrorLibrary.sol";
interface ITransferVault {
    /**
     * @notice Read the configured collateral token address.
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
    function usdc() external view returns(address);
    /**
     * @notice Read the configured QEURO token address.
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
    function qeuro() external view returns(address);
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
    function executionPricing() external view returns(address);
    /**
     * @notice Read the configured hedger accounting pool.
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
    function hedgerPool() external view returns(address);
    /**
     * @notice Read the configured protocol fee collector.
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
    function feeCollector() external view returns(address);
    /**
     * @notice Read the fee allocation to the hedger reserve, in 1e18 precision.
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
    function hedgerRewardFeeSplit() external view returns(uint256);
    /**
     * @notice Read the adapter, activity and tracked principal through the vault's public view.
     * @dev Private routing mappings have no generated external getters.
     * @param vaultId External strategy identifier.
     * @return adapter Configured external adapter.
     * @return active Whether the strategy accepts deposits.
     * @return principalTracked Recorded USDC principal, including committed mint backing.
     * @return currentUnderlying Underlying reported by the adapter.
     * @custom:security Read-only; does not authorize settlement.
     * @custom:validation Adapter reads fail closed.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates adapter read failures.
     * @custom:reentrancy Read-only.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function getVaultExposure(uint256 vaultId) external view returns(address adapter,bool active,uint256 principalTracked,uint256 currentUnderlying);
}
/// @notice Linked token interactions after the vault has persisted its accounting effects.
library VaultTransferLibrary {
    using SafeERC20 for IERC20;
    event UsdcDeployedToExternalVault(uint256 indexed vaultId, uint256 indexed usdcAmount, uint256 principalAfter);
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
    function version() external pure returns(string memory) { return "1.0.0"; }
    /**
     * @notice Receive USDC, route fees and spread, mint QEURO and deploy selected backing.
     * @dev Invoked through the consumer; delegatecall retains its storage and original sender.
     * @param payer Address from which input tokens are collected.
     * @param recipient Address receiving the output transfer.
     * @param input Gross input amount in input-token raw units.
     * @param fee Protocol fee in six-decimal USDC units.
     * @param backing Reference-valued collateral in six-decimal USDC units.
     * @param output Validated output amount in output-token raw units.
     * @param route External vault ID, or zero for liquid collateral.
     * @custom:security Consumer permissions and accounting checks remain in force.
     * @custom:validation Applies the selected operation's bounds; failures revert the entire call.
     * @custom:state-changes Updates the calling consumer and downstream contracts as described above.
     * @custom:events Underlying operation and token events when applicable.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy The consuming operation retains its existing reentrancy guards.
     * @custom:access Consumer entrypoint permissions; this helper grants no additional authority.
     * @custom:oracle Uses the consumer's configured reference and execution paths where the operation requires pricing.
     */
    function mint(address payer,address recipient,uint256 input,uint256 fee,uint256 backing,uint256 output,uint256 route) external {
        ITransferVault v=ITransferVault(address(this));
        IERC20 token=IERC20(v.usdc());
        token.safeTransferFrom(payer,address(this),input);
        uint256 spread=input-fee-backing;
        if(spread>0) token.safeTransfer(v.executionPricing(),spread);
        _fees(v,token,fee,"minting");
        IQEUROToken(v.qeuro()).mint(recipient,output);
        if(route!=0 && backing>0) _deploy(v,token,route,backing);
    }
    /**
     * @notice Burn QEURO and pay the user, fees and execution spread.
     * @dev Invoked through the consumer; delegatecall retains its storage and original sender.
     * @param recipient Address receiving the output transfer.
     * @param input Gross input amount in input-token raw units.
     * @param backing Reference-valued collateral in six-decimal USDC units.
     * @param output Validated output amount in output-token raw units.
     * @param fee Protocol fee in six-decimal USDC units.
     * @custom:security Consumer permissions and accounting checks remain in force.
     * @custom:validation Applies the selected operation's bounds; failures revert the entire call.
     * @custom:state-changes Updates the calling consumer and downstream contracts as described above.
     * @custom:events Underlying operation and token events when applicable.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy The consuming operation retains its existing reentrancy guards.
     * @custom:access Consumer entrypoint permissions; this helper grants no additional authority.
     * @custom:oracle Uses the consumer's configured reference and execution paths where the operation requires pricing.
     */
    function redeem(address recipient,uint256 input,uint256 backing,uint256 output,uint256 fee) external {
        ITransferVault v=ITransferVault(address(this));
        IERC20 token=IERC20(v.usdc());
        IQEUROToken(v.qeuro()).burn(recipient,input);
        token.safeTransfer(recipient,output);
        uint256 spread=backing-output-fee;
        if(spread>0) token.safeTransfer(v.executionPricing(),spread);
        _fees(v,token,fee,"redemption");
    }
    function _fees(ITransferVault v,IERC20 token,uint256 fee,string memory source) private {
        ExecutionPricingLibrary.routeFees(token,fee,v.hedgerRewardFeeSplit(),IHedgerPool(v.hedgerPool()),v.feeCollector(),source);
    }
    /**
     * @notice Deposit backing into the configured external adapter.
     * @dev Invoked through the consumer; delegatecall retains its storage and original sender.
     * @param id External vault identifier.
     * @param amount Amount in the token units of the selected operation.
     * @custom:security Consumer permissions and accounting checks remain in force.
     * @custom:validation Applies the selected operation's bounds; failures revert the entire call.
     * @custom:state-changes Updates the calling consumer and downstream contracts as described above.
     * @custom:events Underlying operation and token events when applicable.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy The consuming operation retains its existing reentrancy guards.
     * @custom:access Consumer entrypoint permissions; this helper grants no additional authority.
     * @custom:oracle Uses the consumer's configured reference and execution paths where the operation requires pricing.
     */
    function deploy(uint256 id,uint256 amount) external {
        ITransferVault v=ITransferVault(address(this));
        _deploy(v,IERC20(v.usdc()),id,amount);
    }
    function _deploy(ITransferVault v,IERC20 token,uint256 id,uint256 amount) private {
        if(id==0 || amount==0) return;
        (address adapterAddress,bool active,uint256 principal,) = v.getVaultExposure(id);
        IExternalStakingVault adapter=IExternalStakingVault(adapterAddress);
        if(!active || address(adapter)==address(0)) revert Errors.InvalidVault();
        token.safeIncreaseAllowance(address(adapter),amount);
        if(adapter.depositUnderlying(amount)==0) revert Errors.InvalidAmount();
        emit UsdcDeployedToExternalVault(id,amount,principal);
    }
}
