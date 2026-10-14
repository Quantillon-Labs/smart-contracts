// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IQEUROToken} from "../interfaces/IQEUROToken.sol";
import {IHedgerPool} from "../interfaces/IHedgerPool.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {IExecutionPricing} from "../interfaces/IExecutionPricing.sol";
import {ExecutionPricingLibrary} from "./ExecutionPricingLibrary.sol";
import {CommonErrorLibrary as Errors} from "./CommonErrorLibrary.sol";
interface IYieldSettlementView {
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
    function oracle() external view returns(address);
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
     * @notice Read the stQEURO recipient for an external vault.
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
    function stQEUROTokenByVaultId(uint256) external view returns(address);
    /**
     * @notice Read the mint fee rate in 1e18 precision.
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
    function mintFee() external view returns(uint256);
    /**
     * @notice Read the required mint collateralization ratio.
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
    function minCollateralizationRatioForMinting() external view returns(uint256);
    /**
     * @notice Read the liquidation threshold.
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
    function criticalCollateralizationRatio() external view returns(uint256);
    /**
     * @notice Read whether the delayed development policy is enabled.
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
    function devModeEnabled() external view returns(bool);
    /**
     * @notice Read loss-aware collateral available to the vault.
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
    function getTotalUsdcAvailable() external view returns(uint256);
}
/// @notice Linked yield validation and token interactions, retaining principal and share accounting.
library VaultYieldSettlementLibrary {
    using SafeERC20 for IERC20;
    struct Credit { uint256 quantity; uint256 backing; uint256 price; address recipient; }
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
     * @notice Validate staking recipients, reference pricing and projected yield collateralization.
     * @dev Invoked through the consumer; delegatecall retains its storage and original sender.
     * @param id External vault identifier.
     * @param amount Amount in the token units of the selected operation.
     * @param cached Previous cached EUR/USD reference in 1e18 precision.
     * @param lastBlock Block of the previous reference-cache update.
     * @return c Validated staking-yield credit.
     * @custom:security Consumer permissions and accounting checks remain in force.
     * @custom:validation Applies the selected operation's bounds; failures revert the entire call.
     * @custom:state-changes Updates the calling consumer and downstream contracts as described above.
     * @custom:events Underlying operation and token events when applicable.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy The consuming operation retains its existing reentrancy guards.
     * @custom:access Consumer entrypoint permissions; this helper grants no additional authority.
     * @custom:oracle Uses the consumer's configured reference and execution paths where the operation requires pricing.
     */
    function prepare(uint256 id,uint256 amount,uint256 cached,uint256 lastBlock) external returns(Credit memory c) {
        IYieldSettlementView v=IYieldSettlementView(address(this));
        c.recipient=v.stQEUROTokenByVaultId(id);
        if(c.recipient==address(0)) revert Errors.InvalidVault();
        if(IERC20(c.recipient).totalSupply()==0) revert Errors.NotInitialized();
        bool valid;
        (c.price,valid)=IOracle(v.oracle()).getEurUsdPrice();
        if(!valid) revert Errors.InvalidOraclePrice();
        IERC20 token=IERC20(v.qeuro());
        ExecutionPricingLibrary.enforceYieldEligibility(token,IHedgerPool(v.hedgerPool()),cached,c.price,v.criticalCollateralizationRatio());
        if(!v.devModeEnabled()) ExecutionPricingLibrary.enforceDeviation(c.price,cached,lastBlock);
        (,c.backing,c.quantity)=ExecutionPricingLibrary.mint(IExecutionPricing(v.executionPricing()),amount,0,c.price,0);
        if(c.quantity==0) revert Errors.InvalidAmount();
        ExecutionPricingLibrary.enforceCollateralization(v.getTotalUsdcAvailable()+c.backing,token.totalSupply()+c.quantity,c.price,100e18);
    }
    struct Mint { uint256 fee; uint256 backing; uint256 quantity; uint256 price; }
    /**
     * @notice Validate reference price, eligibility, output and projected mint collateralization.
     * @dev Invoked through the consumer; delegatecall retains its storage and original sender.
     * @param amount Amount in the token units of the selected operation.
     * @param minimum Minimum acceptable output in the output token's raw units.
     * @param cached Previous cached EUR/USD reference in 1e18 precision.
     * @param lastBlock Block of the previous reference-cache update.
     * @return m Validated mint fee, backing, output and reference price.
     * @custom:security Consumer permissions and accounting checks remain in force.
     * @custom:validation Applies the selected operation's bounds; failures revert the entire call.
     * @custom:state-changes Updates the calling consumer and downstream contracts as described above.
     * @custom:events Underlying operation and token events when applicable.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy The consuming operation retains its existing reentrancy guards.
     * @custom:access Consumer entrypoint permissions; this helper grants no additional authority.
     * @custom:oracle Uses the consumer's configured reference and execution paths where the operation requires pricing.
     */
    function prepareMint(uint256 amount,uint256 minimum,uint256 cached,uint256 lastBlock) external returns(Mint memory m) {
        IYieldSettlementView v=IYieldSettlementView(address(this));
        bool valid;
        (m.price,valid)=IOracle(v.oracle()).getEurUsdPrice();
        if(!valid) revert Errors.InvalidOraclePrice();
        IERC20 token=IERC20(v.qeuro());
        uint256 floor=v.minCollateralizationRatioForMinting();
        ExecutionPricingLibrary.enforceMintEligibility(token,IHedgerPool(v.hedgerPool()),cached,m.price,floor);
        if(!v.devModeEnabled()) ExecutionPricingLibrary.enforceDeviation(m.price,cached,lastBlock);
        (m.fee,m.backing,m.quantity)=ExecutionPricingLibrary.mint(IExecutionPricing(v.executionPricing()),amount,v.mintFee(),m.price,minimum);
        ExecutionPricingLibrary.enforceCollateralization(v.getTotalUsdcAvailable()+m.backing,token.totalSupply()+m.quantity,m.price,floor);
    }
    /**
     * @notice Synchronize hedger accounting and mint the validated yield credit to stQEURO.
     * @dev Invoked through the consumer; delegatecall retains its storage and original sender.
     * @param amount Amount in the token units of the selected operation.
     * @param c Validated yield credit with output, backing, price and recipient.
     * @custom:security Consumer permissions and accounting checks remain in force.
     * @custom:validation Applies the selected operation's bounds; failures revert the entire call.
     * @custom:state-changes Updates the calling consumer and downstream contracts as described above.
     * @custom:events Underlying operation and token events when applicable.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy The consuming operation retains its existing reentrancy guards.
     * @custom:access Consumer entrypoint permissions; this helper grants no additional authority.
     * @custom:oracle Uses the consumer's configured reference and execution paths where the operation requires pricing.
     */
    function commit(uint256 amount,Credit memory c) external {
        IYieldSettlementView v=IYieldSettlementView(address(this));
        if(c.backing!=0) IHedgerPool(v.hedgerPool()).recordUserMint(c.backing,c.price,c.quantity);
        if(amount>c.backing) IERC20(v.usdc()).safeTransfer(v.executionPricing(),amount-c.backing);
        IQEUROToken(v.qeuro()).mint(c.recipient,c.quantity);
    }
}
