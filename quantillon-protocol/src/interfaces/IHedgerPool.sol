// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IHedgerPool {
    struct HedgerRiskConfig {
        uint256 minMarginRatio;
        uint256 maxLeverage;
        uint256 minPositionHoldBlocks;
        uint256 minMarginAmount;
        uint256 eurInterestRate;
        uint256 usdInterestRate;
        uint256 entryFee;
        uint256 exitFee;
        uint256 marginFee;
        uint256 rewardFeeSplit;
    }

    struct HedgerDependencyConfig {
        address treasury;
        address vault;
        address oracle;
        address yieldShift;
        address feeCollector;
    }

    /**
     * @notice Initializes the HedgerPool contract.
     * @dev Sets up core references, roles and timelock required for hedger operations.
     * @param admin Address receiving admin and governance roles.
     * @param _usdc USDC token address used for margin and PnL settlement.
     * @param _oracle Oracle contract used to obtain EUR/USD prices.
     * @param _yieldShift YieldShift contract used for hedger reward accounting.
     * @param _timelock Timelock contract used for secure upgrades.
     * @param _treasury Treasury address receiving protocol fees / recoveries.
     * @param _vault QuantillonVault address holding unified USDC liquidity.
     * @custom:security Validates non‑zero addresses and configures roles.
     * @custom:validation Reverts on zero addresses or inconsistent configuration.
     * @custom:state-changes Initializes storage, roles and external references.
     * @custom:events Emits implementation‑specific initialization events.
     * @custom:errors Reverts with protocol‑specific errors on invalid configuration.
     * @custom:reentrancy Protected by initializer modifier in implementation.
     * @custom:access External initializer; callable only once by deployer/timelock.
     * @custom:oracle No live oracle reads; only stores oracle address.
     */
    function initialize(
        address admin,
        address _usdc,
        address _oracle,
        address _yieldShift,
        address _timelock,
        address _treasury,
        address _vault
    ) external;

    /**
     * @notice Opens a new hedge position using USDC margin.
     * @dev Locks `usdcAmount` as margin and creates a leveraged EUR short/long exposure.
     * @param usdcAmount Margin amount in USDC (6 decimals) to lock.
     * @param leverage Leverage multiplier applied to margin.
     * @return positionId Identifier of the newly created hedge position.
     * @custom:security Validates margin ratios, leverage bounds and single‑hedger constraints.
     * @custom:validation Reverts on zero amount, invalid leverage or insufficient balance.
     * @custom:state-changes Updates margin, exposure and internal position bookkeeping.
     * @custom:events Emits `HedgePositionOpened`.
     * @custom:errors Reverts with protocol‑specific risk/validation errors.
     * @custom:reentrancy Protected by nonReentrant modifier in implementation.
     * @custom:access Callable by authorized hedger addresses.
     * @custom:oracle Uses oracle price for margin and exposure checks.
     */
    function enterHedgePosition(uint256 usdcAmount, uint256 leverage) external returns (uint256 positionId);

    /**
     * @notice Closes an existing hedge position.
     * @dev Unwinds exposure, realizes PnL and releases remaining margin to the hedger.
     * @param positionId Identifier of the position to close.
     * @return pnl Signed realized PnL in USDC terms.
     * @custom:security Enforces ownership and minimum hold time before closure.
     * @custom:validation Reverts if position is inactive or caller is not the hedger.
     * @custom:state-changes Updates margin totals, exposure and realized PnL fields.
     * @custom:events Emits `HedgePositionClosed`.
     * @custom:errors Reverts with protocol‑specific position or risk errors.
     * @custom:reentrancy Protected by nonReentrant modifier in implementation.
     * @custom:access Callable by the owning hedger (and possibly governance/emergency).
     * @custom:oracle Uses latest oracle price to compute final PnL.
     */
    function exitHedgePosition(uint256 positionId) external returns (int256 pnl);

    /**
     * @notice Adds additional margin to an existing position.
     * @dev Increases `margin` and recomputes position metrics while keeping exposure rules intact.
     * @param positionId Identifier of the position to top‑up.
     * @param amount USDC amount to add as extra margin.
     * @custom:security Enforces ownership and validates that position is active.
     * @custom:validation Reverts on zero amount or inactive position.
     * @custom:state-changes Increases per‑position and total margin.
     * @custom:events Emits `MarginUpdated`.
     * @custom:errors Reverts with protocol‑specific margin/validation errors.
     * @custom:reentrancy Protected by nonReentrant modifier in implementation.
     * @custom:access Callable by the owning hedger.
     * @custom:oracle May use oracle indirectly in risk checks.
     */
    function addMargin(uint256 positionId, uint256 amount) external;

    /**
     * @notice Removes margin from an existing position.
     * @dev Decreases `margin` subject to min margin ratio and min margin amount constraints.
     * @param positionId Identifier of the position to adjust.
     * @param amount USDC amount of margin to remove.
     * @custom:security Prevents margin removal that would violate risk constraints.
     * @custom:validation Reverts on zero amount, inactive position or under‑margining.
     * @custom:state-changes Decreases per‑position and total margin.
     * @custom:events Emits `MarginUpdated`.
     * @custom:errors Reverts with protocol‑specific risk/validation errors.
     * @custom:reentrancy Protected by nonReentrant modifier in implementation.
     * @custom:access Callable by the owning hedger.
     * @custom:oracle Uses oracle price via risk libraries.
     */
    function removeMargin(uint256 positionId, uint256 amount) external;

    /**
     * @notice Records a user mint event for hedger accounting.
     * @dev Called by `QuantillonVault` when users mint QEURO so hedger exposure can be tracked.
     * @param usdcAmount USDC amount entering the system from the mint.
     * @param fillPrice Oracle mint price used for the operation.
     * @param qeuroAmount QEURO minted to the user.
     * @custom:security Callable only by the vault; validates caller and parameters.
     * @custom:validation Reverts on zero amounts or unauthorized caller.
     * @custom:state-changes Updates aggregated exposure and PnL tracking for hedgers.
     * @custom:events Emits internal accounting events in implementation.
     * @custom:errors Reverts with protocol‑specific accounting errors.
     * @custom:reentrancy Protected by nonReentrant modifier in implementation.
     * @custom:access Restricted to `QuantillonVault`.
     * @custom:oracle Expects `fillPrice` to be derived from a validated oracle path.
     */
    function recordUserMint(uint256 usdcAmount, uint256 fillPrice, uint256 qeuroAmount) external;

    /**
     * @notice Records a user redeem event for hedger accounting.
     * @dev Called by `QuantillonVault` when users redeem QEURO back to USDC.
     * @param usdcAmount USDC paid out to the user.
     * @param redeemPrice Oracle price used for the redemption.
     * @param qeuroAmount QEURO burned from the user.
     * @custom:security Callable only by the vault; validates caller and parameters.
     * @custom:validation Reverts on zero amounts or unauthorized caller.
     * @custom:state-changes Updates aggregated exposure and realized PnL for hedgers.
     * @custom:events Emits internal accounting events in implementation.
     * @custom:errors Reverts with protocol‑specific accounting errors.
     * @custom:reentrancy Protected by nonReentrant modifier in implementation.
     * @custom:access Restricted to `QuantillonVault`.
     * @custom:oracle Expects `redeemPrice` to be derived from a validated oracle path.
     */
    function recordUserRedeem(uint256 usdcAmount, uint256 redeemPrice, uint256 qeuroAmount) external;

    /**
     * @notice Records a pro‑rata liquidation redeem event.
     * @dev Called when QEURO redemptions happen in liquidation mode so hedger metrics
     *      can be aligned with total supply.
     * @param qeuroAmount QEURO amount redeemed under liquidation mode.
     * @param totalQeuroSupply Total QEURO supply at the time of redemption.
     * @custom:security Callable only by authorized vault component.
     * @custom:validation Reverts on inconsistent supply or zero amounts.
     * @custom:state-changes Updates hedger exposure and PnL tracking.
     * @custom:events Emits internal accounting events in implementation.
     * @custom:errors Reverts with protocol‑specific accounting errors.
     * @custom:reentrancy Protected by nonReentrant modifier in implementation.
     * @custom:access Restricted to vault modules.
     * @custom:oracle Indirectly depends on vault’s oracle‑validated paths.
     */
    function recordLiquidationRedeem(uint256 qeuroAmount, uint256 totalQeuroSupply) external;

    /**
     * @notice Claims accumulated hedging rewards for the caller.
     * @dev Aggregates interest differential and yield‑shift rewards into a single payout.
     * @return interestDifferential Portion of rewards from interest‑rate differential.
     * @return yieldShiftRewards Portion of rewards from YieldShift allocations.
     * @return totalRewards Total rewards transferred to the caller.
     * @custom:security Enforces that caller is an eligible hedger.
     * @custom:validation Reverts if there is no claimable amount.
     * @custom:state-changes Decreases internal reward pools and updates last‑claim markers.
     * @custom:events Emits `HedgingRewardsClaimed`.
     * @custom:errors Reverts with protocol‑specific reward errors.
     * @custom:reentrancy Protected by nonReentrant modifier in implementation.
     * @custom:access Public – callable by hedgers.
     * @custom:oracle No direct oracle dependency; uses already‑accounted rewards.
     */
    function claimHedgingRewards() external returns (uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards);

    /**
     * @notice Withdraws pending rewards to a specified recipient.
     * @dev Allows an operator (or the hedger) to withdraw accrued rewards to `recipient`.
     * @param recipient Address receiving the pending rewards.
     * @custom:security Enforces authorization for withdrawing on behalf of hedgers.
     * @custom:validation Reverts if recipient is zero or there are no pending rewards.
     * @custom:state-changes Decreases pending reward balances and transfers USDC.
     * @custom:events Emits reward‑withdrawal events in implementation.
     * @custom:errors Reverts with protocol‑specific reward or access errors.
     * @custom:reentrancy Protected by nonReentrant modifier in implementation.
     * @custom:access Restricted to authorized roles or hedgers as defined by implementation.
     * @custom:oracle No direct oracle dependency.
     */
    function withdrawPendingRewards(address recipient) external;

    /**
     * @notice Returns the total effective hedger collateral at a given price.
     * @dev Aggregates per‑position collateral after applying current price and haircuts.
     * @param currentPrice Current EUR/USD oracle price used for collateral computation.
     * @return totalEffectiveCollateral Effective hedger collateral in USDC terms.
     * @custom:security View function; caller must source a sane `currentPrice`.
     * @custom:validation Returns 0 if no active positions or if price is invalid.
     * @custom:state-changes None – view function.
     * @custom:events None.
     * @custom:errors None – callers handle interpretation.
     * @custom:reentrancy Not applicable – view function.
     * @custom:access Public – used by vault and monitoring tools.
     * @custom:oracle Expects `currentPrice` to come from a validated oracle.
     */
    function getTotalEffectiveHedgerCollateral(uint256 currentPrice) external view returns (uint256 totalEffectiveCollateral);

    /**
     * @notice Returns whether there is at least one active hedger position.
     * @dev Used by the vault to check that the protocol is hedged.
     * @return hasActive True if at least one hedger has an active position.
     * @custom:security View function; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None – view function.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable – view function.
     * @custom:access Public – anyone can inspect hedger activity.
     * @custom:oracle No direct oracle dependency.
     */
    function hasActiveHedger() external view returns (bool hasActive);

    /**
     * @notice Configures core hedger risk parameters and fee schedule.
     * @dev Updates leverage, margin, interest and fee parameters in a single call.
     * @param cfg Struct containing all risk and fee configuration fields.
     * @custom:security Restricted to governance; misconfiguration can break risk model.
     * @custom:validation Implementation validates each field is within allowed bounds.
     * @custom:state-changes Updates internal risk configuration used for all positions.
     * @custom:events Emits configuration‑update events.
     * @custom:errors Reverts with protocol‑specific config errors.
     * @custom:reentrancy Not applicable – configuration only.
     * @custom:access Restricted to governance roles.
     * @custom:oracle No direct oracle dependency.
     */
    function configureRiskAndFees(HedgerRiskConfig calldata cfg) external;

    /**
     * @notice Configures external dependencies used by HedgerPool.
     * @dev Wires treasury, vault, oracle, YieldShift and FeeCollector references.
     * @param cfg Struct specifying dependency addresses.
     * @custom:security Restricted to governance; validates non‑zero and compatible addresses.
     * @custom:validation Reverts on zero addresses or invalid dependencies.
     * @custom:state-changes Updates contract references used for hedger operations.
     * @custom:events Emits dependency‑update events.
     * @custom:errors Reverts with protocol‑specific config errors.
     * @custom:reentrancy Not applicable – configuration only.
     * @custom:access Restricted to governance roles.
     * @custom:oracle No direct oracle dependency.
     */
    function configureDependencies(HedgerDependencyConfig calldata cfg) external;

    /**
     * @notice Emergency closure of a specific hedger position.
     * @dev Allows governance/emergency role to forcibly close a position in extreme cases.
     * @param hedger Address of the hedger whose position is being closed.
     * @param positionId Identifier of the position to close.
     * @custom:security Restricted to emergency/governance roles; bypasses normal hedger flow.
     * @custom:validation Reverts if position is already inactive or hedger mismatch.
     * @custom:state-changes Realizes PnL and updates margin/exposure like a normal close.
     * @custom:events Emits `HedgePositionClosed` with emergency context.
     * @custom:errors Reverts with protocol‑specific position errors.
     * @custom:reentrancy Protected by nonReentrant modifier in implementation.
     * @custom:access Restricted to emergency/governance roles.
     * @custom:oracle Uses oracle price for PnL computation.
     */
    function emergencyClosePosition(address hedger, uint256 positionId) external;

    /**
     * @notice Pauses HedgerPool operations.
     * @dev Emergency function that halts user‑facing state‑changing methods.
     * @custom:security Restricted to EMERGENCY_ROLE in implementation.
     * @custom:validation None.
     * @custom:state-changes Sets paused state to true.
     * @custom:events Emits `Paused` from OpenZeppelin.
     * @custom:errors None – pause is best‑effort.
     * @custom:reentrancy Not applicable – no external calls.
     * @custom:access Emergency‑only.
     * @custom:oracle No oracle dependency.
     */
    function pause() external;

    /**
     * @notice Unpauses HedgerPool operations.
     * @dev Resumes normal operation after an emergency pause.
     * @custom:security Restricted to EMERGENCY_ROLE in implementation.
     * @custom:validation None.
     * @custom:state-changes Sets paused state to false.
     * @custom:events Emits `Unpaused` from OpenZeppelin.
     * @custom:errors None.
     * @custom:reentrancy Not applicable – no external calls.
     * @custom:access Emergency‑only.
     * @custom:oracle No oracle dependency.
     */
    function unpause() external;

    /**
     * @notice Recovers arbitrary ERC20 tokens from the contract.
     * @dev Intended only for governance to recover tokens that are not part of normal flows.
     * @param token Token address to recover.
     * @param amount Amount of tokens to send to treasury.
     * @custom:security Restricted to governance/treasury roles; never used for user margin.
     * @custom:validation Reverts on zero token, zero amount or insufficient balance.
     * @custom:state-changes Transfers tokens from HedgerPool to treasury or designated address.
     * @custom:events Emits recovery events in implementation.
     * @custom:errors Reverts with protocol‑specific recovery errors.
     * @custom:reentrancy Protected by nonReentrant modifier in implementation.
     * @custom:access Restricted to governance/admin.
     * @custom:oracle No oracle dependency.
     */
    function recover(address token, uint256 amount) external;

    /**
     * @notice Sets the designated single hedger address.
     * @dev Configures an address that is allowed to act as the sole hedger when single‑hedger
     *      mode is enabled.
     * @param hedger Address proposed as single hedger.
     * @custom:security Restricted to governance; validates hedger is non‑zero.
     * @custom:validation May enforce that previous rotation has completed.
     * @custom:state-changes Updates single‑hedger configuration state.
     * @custom:events Emits `SingleHedgerRotationProposed`.
     * @custom:errors Reverts on invalid hedger address.
     * @custom:reentrancy Not applicable – configuration only.
     * @custom:access Restricted to governance roles.
     * @custom:oracle No oracle dependency.
     */
    function setSingleHedger(address hedger) external;

    /**
     * @notice Applies a previously proposed single‑hedger rotation.
     * @dev Finalizes the transition to `pendingSingleHedger` once any activation delay has elapsed.
     * @custom:security Restricted to governance; relies on internal timing/quorum checks.
     * @custom:validation Reverts if there is no pending rotation or delay not met.
     * @custom:state-changes Updates `singleHedger` and clears pending rotation state.
     * @custom:events Emits `SingleHedgerRotationApplied`.
     * @custom:errors Reverts with protocol‑specific rotation errors.
     * @custom:reentrancy Not applicable – configuration only.
     * @custom:access Restricted to governance roles.
     * @custom:oracle No oracle dependency.
     */
    function applySingleHedgerRotation() external;

    /**
     * @notice Funds the reward reserve used to pay hedger rewards.
     * @dev Transfers USDC from caller into the reward reserve accounting balance.
     * @param amount Amount of USDC to add to the reserve.
     * @custom:security Callable by treasury/governance; validates positive amount.
     * @custom:validation Reverts on zero amount or insufficient allowance.
     * @custom:state-changes Increases internal reward reserve and vault balances.
     * @custom:events Emits `RewardReserveFunded`.
     * @custom:errors Reverts with protocol‑specific funding errors.
     * @custom:reentrancy Protected by nonReentrant modifier in implementation.
     * @custom:access Restricted to treasury/governance roles.
     * @custom:oracle No oracle dependency.
     */
    function fundRewardReserve(uint256 amount) external;

    /**
     * @notice Returns the USDC token used for margin and settlement.
     * @dev Exposes the ERC20 collateral token that backs hedger margin and PnL.
     * @return usdcToken IERC20 instance of the USDC token.
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function usdc() external view returns (IERC20 usdcToken);

    /**
     * @notice Returns the oracle contract address used for pricing.
     * @dev This oracle is used by the implementation to value exposure and margin.
     * @return oracleAddress Address of the oracle.
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle Exposes the price‑feed dependency.
     */
    function oracle() external view returns (address oracleAddress);

    /**
     * @notice Returns the YieldShift contract address.
     * @dev YieldShift is responsible for computing and distributing protocol yield.
     * @return yieldShiftAddress Address of the YieldShift contract.
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function yieldShift() external view returns (address yieldShiftAddress);

    /**
     * @notice Returns the QuantillonVault contract address.
     * @dev Vault holds unified USDC liquidity shared between users and hedgers.
     * @return vaultAddress Address of the vault contract.
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function vault() external view returns (address vaultAddress);

    /**
     * @notice Returns the treasury address used for fee flows.
     * @dev Treasury receives protocol fees and recovered funds from HedgerPool.
     * @return treasuryAddress Treasury address.
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function treasury() external view returns (address treasuryAddress);

    /**
     * @notice Returns packed core hedger parameters.
     * @dev Exposes key risk and fee parameters as a compact tuple.
     * @return minMarginRatio Minimum margin ratio (bps).
     * @return maxLeverage Maximum allowed leverage (1e2 or similar scaling).
     * @return entryFee Entry fee (bps).
     * @return exitFee Exit fee (bps).
     * @return marginFee Ongoing margin fee (bps).
     * @return eurInterestRate EUR interest rate (bps).
     * @return usdInterestRate USD interest rate (bps).
     * @return reserved Reserved field for future use.
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public – for UI and risk monitoring.
     * @custom:oracle No oracle dependency.
     */
    function coreParams()
        external
        view
        returns (
            uint64 minMarginRatio,
            uint16 maxLeverage,
            uint16 entryFee,
            uint16 exitFee,
            uint16 marginFee,
            uint16 eurInterestRate,
            uint16 usdInterestRate,
            uint8 reserved
        );

    /**
     * @notice Returns the total margin locked across all hedger positions.
     * @dev Sums the `margin` field of every active position, in USDC units.
     * @return margin Total margin in USDC terms.
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function totalMargin() external view returns (uint256 margin);

    /**
     * @notice Returns the total notional exposure of all hedger positions.
     * @dev Aggregates leveraged notional position sizes across all active hedgers.
     * @return exposure Total position size in notional units.
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function totalExposure() external view returns (uint256 exposure);

    /**
     * @notice Returns the total filled exposure across all positions.
     * @dev Tracks how much of the theoretical exposure is actually filled in the market.
     * @return filledExposure Total filled exposure.
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function totalFilledExposure() external view returns (uint256 filledExposure);

    /**
     * @notice Returns the currently active single hedger address.
     * @dev When single‑hedger mode is enabled, only this address may open positions.
     * @return hedgerAddress Single hedger address, or zero if not configured.
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function singleHedger() external view returns (address hedgerAddress);

    /**
     * @notice Returns the minimum number of blocks a position must be held.
     * @dev Used to prevent instant in‑and‑out hedger positions around price updates.
     * @return minBlocks Minimum position hold in blocks.
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function minPositionHoldBlocks() external view returns (uint256 minBlocks);

    /**
     * @notice Returns the minimum allowed margin amount for a position.
     * @dev Positions with margin below this threshold are not allowed to open.
     * @return minMargin Minimum margin in USDC terms.
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function minMarginAmount() external view returns (uint256 minMargin);

    /**
     * @notice Returns pending reward withdrawals for a specific hedger.
     * @dev Shows how much claimable USDC yield is currently assigned to `hedger`.
     * @param hedger Address of the hedger.
     * @return amount Pending reward amount in USDC.
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public – hedgers and UIs can inspect claimable rewards.
     * @custom:oracle No oracle dependency.
     */
    function pendingRewardWithdrawals(address hedger) external view returns (uint256 amount);

    /**
     * @notice Returns the FeeCollector contract address.
     * @dev FeeCollector aggregates protocol fees before they are routed to treasury or rewards.
     * @return feeCollectorAddress Address of the fee collector.
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function feeCollector() external view returns (address feeCollectorAddress);

    /**
     * @notice Returns the current reward fee split between treasury and hedgers.
     * @dev Implementations use this split to decide how collected fees are allocated.
     * @return split Reward fee split as a fraction (bps or 1e18‑scaled per implementation).
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function rewardFeeSplit() external view returns (uint256 split);

    /**
     * @notice Returns the maximum allowed reward fee split.
     * @dev Governance cannot configure `rewardFeeSplit` above this constant.
     * @return maxSplit Maximum allowed split constant.
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function MAX_REWARD_FEE_SPLIT() external view returns (uint256 maxSplit);

    /**
     * @notice Returns the pending single hedger address, if any.
     * @dev When non‑zero, this address will become `singleHedger` once rotation is applied.
     * @return pending Address that will become the single hedger after rotation is applied.
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function pendingSingleHedger() external view returns (address pending);

    /**
     * @notice Returns the timestamp at which the pending single hedger can be applied.
     * @dev After this timestamp, `applySingleHedgerRotation` may finalize the rotation.
     * @return pendingAt Unix timestamp when rotation becomes executable.
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function singleHedgerPendingAt() external view returns (uint256 pendingAt);

    /**
     * @notice Returns the last block number at which a hedger claimed rewards.
     * @dev Useful for enforcing minimum intervals between reward claims.
     * @param hedger Address of the hedger.
     * @return lastRewardBlock Block number of the last reward claim.
     * @custom:security View‑only; no access restriction.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle No oracle dependency.
     */
    function hedgerLastRewardBlock(address hedger) external view returns (uint256 lastRewardBlock);

    /**
     * @notice Returns full position data for a given position id.
     * @dev Provides a denormalized snapshot of all key risk metrics for off‑chain monitoring.
     * @param positionId Identifier of the position.
     * @return hedger Hedger address owning the position.
     * @return positionSize Current notional position size.
     * @return filledVolume Filled hedge volume.
     * @return margin Current margin allocated to the position.
     * @return entryPrice Price at which the position was opened.
     * @return entryTime Timestamp of position opening.
     * @return lastUpdateTime Timestamp of last position update.
     * @return unrealizedPnL Current unrealized PnL (signed).
     * @return realizedPnL Realized PnL accumulated so far (signed).
     * @return leverage Position leverage.
     * @return isActive Whether the position is currently active.
     * @return qeuroBacked Amount of QEURO backed by this position.
     * @return openBlock Block number at which the position was opened.
     * @custom:security View‑only; no access restriction.
     * @custom:validation Returns zeroed values for nonexistent positions.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public – for analytics and monitoring.
     * @custom:oracle No oracle dependency.
     */
    function positions(uint256 positionId)
        external
        view
        returns (
            address hedger,
            uint96 positionSize,
            uint96 filledVolume,
            uint96 margin,
            uint96 entryPrice,
            uint32 entryTime,
            uint32 lastUpdateTime,
            int128 unrealizedPnL,
            int128 realizedPnL,
            uint16 leverage,
            bool isActive,
            uint128 qeuroBacked,
            uint64 openBlock
        );

    event HedgePositionOpened(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
    event HedgePositionClosed(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
    event MarginUpdated(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
    event HedgingRewardsClaimed(address indexed hedger, bytes32 packedData);
    event RewardReserveFunded(address indexed funder, uint256 amount);
    event SingleHedgerRotationProposed(address indexed currentHedger, address indexed pendingHedger, uint256 activatesAt);
    event SingleHedgerRotationApplied(address indexed previousHedger, address indexed newHedger);
}
