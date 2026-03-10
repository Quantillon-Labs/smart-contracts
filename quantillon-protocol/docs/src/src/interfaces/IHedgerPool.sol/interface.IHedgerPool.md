# IHedgerPool

## Functions
### initialize

Initializes the HedgerPool contract.

Sets up core references, roles and timelock required for hedger operations.

**Notes:**
- security: Validates non‑zero addresses and configures roles.

- validation: Reverts on zero addresses or inconsistent configuration.

- state-changes: Initializes storage, roles and external references.

- events: Emits implementation‑specific initialization events.

- errors: Reverts with protocol‑specific errors on invalid configuration.

- reentrancy: Protected by initializer modifier in implementation.

- access: External initializer; callable only once by deployer/timelock.

- oracle: No live oracle reads; only stores oracle address.


```solidity
function initialize(
    address admin,
    address _usdc,
    address _oracle,
    address _yieldShift,
    address _timelock,
    address _treasury,
    address _vault
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address receiving admin and governance roles.|
|`_usdc`|`address`|USDC token address used for margin and PnL settlement.|
|`_oracle`|`address`|Oracle contract used to obtain EUR/USD prices.|
|`_yieldShift`|`address`|YieldShift contract used for hedger reward accounting.|
|`_timelock`|`address`|Timelock contract used for secure upgrades.|
|`_treasury`|`address`|Treasury address receiving protocol fees / recoveries.|
|`_vault`|`address`|QuantillonVault address holding unified USDC liquidity.|


### enterHedgePosition

Opens a new hedge position using USDC margin.

Locks `usdcAmount` as margin and creates a leveraged EUR short/long exposure.

**Notes:**
- security: Validates margin ratios, leverage bounds and single‑hedger constraints.

- validation: Reverts on zero amount, invalid leverage or insufficient balance.

- state-changes: Updates margin, exposure and internal position bookkeeping.

- events: Emits `HedgePositionOpened`.

- errors: Reverts with protocol‑specific risk/validation errors.

- reentrancy: Protected by nonReentrant modifier in implementation.

- access: Callable by authorized hedger addresses.

- oracle: Uses oracle price for margin and exposure checks.


```solidity
function enterHedgePosition(uint256 usdcAmount, uint256 leverage) external returns (uint256 positionId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Margin amount in USDC (6 decimals) to lock.|
|`leverage`|`uint256`|Leverage multiplier applied to margin.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|Identifier of the newly created hedge position.|


### exitHedgePosition

Closes an existing hedge position.

Unwinds exposure, realizes PnL and releases remaining margin to the hedger.

**Notes:**
- security: Enforces ownership and minimum hold time before closure.

- validation: Reverts if position is inactive or caller is not the hedger.

- state-changes: Updates margin totals, exposure and realized PnL fields.

- events: Emits `HedgePositionClosed`.

- errors: Reverts with protocol‑specific position or risk errors.

- reentrancy: Protected by nonReentrant modifier in implementation.

- access: Callable by the owning hedger (and possibly governance/emergency).

- oracle: Uses latest oracle price to compute final PnL.


```solidity
function exitHedgePosition(uint256 positionId) external returns (int256 pnl);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|Identifier of the position to close.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`pnl`|`int256`|Signed realized PnL in USDC terms.|


### addMargin

Adds additional margin to an existing position.

Increases `margin` and recomputes position metrics while keeping exposure rules intact.

**Notes:**
- security: Enforces ownership and validates that position is active.

- validation: Reverts on zero amount or inactive position.

- state-changes: Increases per‑position and total margin.

- events: Emits `MarginUpdated`.

- errors: Reverts with protocol‑specific margin/validation errors.

- reentrancy: Protected by nonReentrant modifier in implementation.

- access: Callable by the owning hedger.

- oracle: May use oracle indirectly in risk checks.


```solidity
function addMargin(uint256 positionId, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|Identifier of the position to top‑up.|
|`amount`|`uint256`|USDC amount to add as extra margin.|


### removeMargin

Removes margin from an existing position.

Decreases `margin` subject to min margin ratio and min margin amount constraints.

**Notes:**
- security: Prevents margin removal that would violate risk constraints.

- validation: Reverts on zero amount, inactive position or under‑margining.

- state-changes: Decreases per‑position and total margin.

- events: Emits `MarginUpdated`.

- errors: Reverts with protocol‑specific risk/validation errors.

- reentrancy: Protected by nonReentrant modifier in implementation.

- access: Callable by the owning hedger.

- oracle: Uses oracle price via risk libraries.


```solidity
function removeMargin(uint256 positionId, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|Identifier of the position to adjust.|
|`amount`|`uint256`|USDC amount of margin to remove.|


### recordUserMint

Records a user mint event for hedger accounting.

Called by `QuantillonVault` when users mint QEURO so hedger exposure can be tracked.

**Notes:**
- security: Callable only by the vault; validates caller and parameters.

- validation: Reverts on zero amounts or unauthorized caller.

- state-changes: Updates aggregated exposure and PnL tracking for hedgers.

- events: Emits internal accounting events in implementation.

- errors: Reverts with protocol‑specific accounting errors.

- reentrancy: Protected by nonReentrant modifier in implementation.

- access: Restricted to `QuantillonVault`.

- oracle: Expects `fillPrice` to be derived from a validated oracle path.


```solidity
function recordUserMint(uint256 usdcAmount, uint256 fillPrice, uint256 qeuroAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|USDC amount entering the system from the mint.|
|`fillPrice`|`uint256`|Oracle mint price used for the operation.|
|`qeuroAmount`|`uint256`|QEURO minted to the user.|


### recordUserRedeem

Records a user redeem event for hedger accounting.

Called by `QuantillonVault` when users redeem QEURO back to USDC.

**Notes:**
- security: Callable only by the vault; validates caller and parameters.

- validation: Reverts on zero amounts or unauthorized caller.

- state-changes: Updates aggregated exposure and realized PnL for hedgers.

- events: Emits internal accounting events in implementation.

- errors: Reverts with protocol‑specific accounting errors.

- reentrancy: Protected by nonReentrant modifier in implementation.

- access: Restricted to `QuantillonVault`.

- oracle: Expects `redeemPrice` to be derived from a validated oracle path.


```solidity
function recordUserRedeem(uint256 usdcAmount, uint256 redeemPrice, uint256 qeuroAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|USDC paid out to the user.|
|`redeemPrice`|`uint256`|Oracle price used for the redemption.|
|`qeuroAmount`|`uint256`|QEURO burned from the user.|


### recordLiquidationRedeem

Records a pro‑rata liquidation redeem event.

Called when QEURO redemptions happen in liquidation mode so hedger metrics
can be aligned with total supply.

**Notes:**
- security: Callable only by authorized vault component.

- validation: Reverts on inconsistent supply or zero amounts.

- state-changes: Updates hedger exposure and PnL tracking.

- events: Emits internal accounting events in implementation.

- errors: Reverts with protocol‑specific accounting errors.

- reentrancy: Protected by nonReentrant modifier in implementation.

- access: Restricted to vault modules.

- oracle: Indirectly depends on vault’s oracle‑validated paths.


```solidity
function recordLiquidationRedeem(uint256 qeuroAmount, uint256 totalQeuroSupply) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|QEURO amount redeemed under liquidation mode.|
|`totalQeuroSupply`|`uint256`|Total QEURO supply at the time of redemption.|


### claimHedgingRewards

Claims accumulated hedging rewards for the caller.

Aggregates interest differential and yield‑shift rewards into a single payout.

**Notes:**
- security: Enforces that caller is an eligible hedger.

- validation: Reverts if there is no claimable amount.

- state-changes: Decreases internal reward pools and updates last‑claim markers.

- events: Emits `HedgingRewardsClaimed`.

- errors: Reverts with protocol‑specific reward errors.

- reentrancy: Protected by nonReentrant modifier in implementation.

- access: Public – callable by hedgers.

- oracle: No direct oracle dependency; uses already‑accounted rewards.


```solidity
function claimHedgingRewards()
    external
    returns (uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`interestDifferential`|`uint256`|Portion of rewards from interest‑rate differential.|
|`yieldShiftRewards`|`uint256`|Portion of rewards from YieldShift allocations.|
|`totalRewards`|`uint256`|Total rewards transferred to the caller.|


### withdrawPendingRewards

Withdraws pending rewards to a specified recipient.

Allows an operator (or the hedger) to withdraw accrued rewards to `recipient`.

**Notes:**
- security: Enforces authorization for withdrawing on behalf of hedgers.

- validation: Reverts if recipient is zero or there are no pending rewards.

- state-changes: Decreases pending reward balances and transfers USDC.

- events: Emits reward‑withdrawal events in implementation.

- errors: Reverts with protocol‑specific reward or access errors.

- reentrancy: Protected by nonReentrant modifier in implementation.

- access: Restricted to authorized roles or hedgers as defined by implementation.

- oracle: No direct oracle dependency.


```solidity
function withdrawPendingRewards(address recipient) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|Address receiving the pending rewards.|


### getTotalEffectiveHedgerCollateral

Returns the total effective hedger collateral at a given price.

Aggregates per‑position collateral after applying current price and haircuts.

**Notes:**
- security: View function; caller must source a sane `currentPrice`.

- validation: Returns 0 if no active positions or if price is invalid.

- state-changes: None – view function.

- events: None.

- errors: None – callers handle interpretation.

- reentrancy: Not applicable – view function.

- access: Public – used by vault and monitoring tools.

- oracle: Expects `currentPrice` to come from a validated oracle.


```solidity
function getTotalEffectiveHedgerCollateral(uint256 currentPrice)
    external
    view
    returns (uint256 totalEffectiveCollateral);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currentPrice`|`uint256`|Current EUR/USD oracle price used for collateral computation.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalEffectiveCollateral`|`uint256`|Effective hedger collateral in USDC terms.|


### hasActiveHedger

Returns whether there is at least one active hedger position.

Used by the vault to check that the protocol is hedged.

**Notes:**
- security: View function; no access restriction.

- validation: None.

- state-changes: None – view function.

- events: None.

- errors: None.

- reentrancy: Not applicable – view function.

- access: Public – anyone can inspect hedger activity.

- oracle: No direct oracle dependency.


```solidity
function hasActiveHedger() external view returns (bool hasActive);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`hasActive`|`bool`|True if at least one hedger has an active position.|


### configureRiskAndFees

Configures core hedger risk parameters and fee schedule.

Updates leverage, margin, interest and fee parameters in a single call.

**Notes:**
- security: Restricted to governance; misconfiguration can break risk model.

- validation: Implementation validates each field is within allowed bounds.

- state-changes: Updates internal risk configuration used for all positions.

- events: Emits configuration‑update events.

- errors: Reverts with protocol‑specific config errors.

- reentrancy: Not applicable – configuration only.

- access: Restricted to governance roles.

- oracle: No direct oracle dependency.


```solidity
function configureRiskAndFees(HedgerRiskConfig calldata cfg) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`cfg`|`HedgerRiskConfig`|Struct containing all risk and fee configuration fields.|


### configureDependencies

Configures external dependencies used by HedgerPool.

Wires treasury, vault, oracle, YieldShift and FeeCollector references.

**Notes:**
- security: Restricted to governance; validates non‑zero and compatible addresses.

- validation: Reverts on zero addresses or invalid dependencies.

- state-changes: Updates contract references used for hedger operations.

- events: Emits dependency‑update events.

- errors: Reverts with protocol‑specific config errors.

- reentrancy: Not applicable – configuration only.

- access: Restricted to governance roles.

- oracle: No direct oracle dependency.


```solidity
function configureDependencies(HedgerDependencyConfig calldata cfg) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`cfg`|`HedgerDependencyConfig`|Struct specifying dependency addresses.|


### emergencyClosePosition

Emergency closure of a specific hedger position.

Allows governance/emergency role to forcibly close a position in extreme cases.

**Notes:**
- security: Restricted to emergency/governance roles; bypasses normal hedger flow.

- validation: Reverts if position is already inactive or hedger mismatch.

- state-changes: Realizes PnL and updates margin/exposure like a normal close.

- events: Emits `HedgePositionClosed` with emergency context.

- errors: Reverts with protocol‑specific position errors.

- reentrancy: Protected by nonReentrant modifier in implementation.

- access: Restricted to emergency/governance roles.

- oracle: Uses oracle price for PnL computation.


```solidity
function emergencyClosePosition(address hedger, uint256 positionId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger whose position is being closed.|
|`positionId`|`uint256`|Identifier of the position to close.|


### pause

Pauses HedgerPool operations.

Emergency function that halts user‑facing state‑changing methods.

**Notes:**
- security: Restricted to EMERGENCY_ROLE in implementation.

- validation: None.

- state-changes: Sets paused state to true.

- events: Emits `Paused` from OpenZeppelin.

- errors: None – pause is best‑effort.

- reentrancy: Not applicable – no external calls.

- access: Emergency‑only.

- oracle: No oracle dependency.


```solidity
function pause() external;
```

### unpause

Unpauses HedgerPool operations.

Resumes normal operation after an emergency pause.

**Notes:**
- security: Restricted to EMERGENCY_ROLE in implementation.

- validation: None.

- state-changes: Sets paused state to false.

- events: Emits `Unpaused` from OpenZeppelin.

- errors: None.

- reentrancy: Not applicable – no external calls.

- access: Emergency‑only.

- oracle: No oracle dependency.


```solidity
function unpause() external;
```

### recover

Recovers arbitrary ERC20 tokens from the contract.

Intended only for governance to recover tokens that are not part of normal flows.

**Notes:**
- security: Restricted to governance/treasury roles; never used for user margin.

- validation: Reverts on zero token, zero amount or insufficient balance.

- state-changes: Transfers tokens from HedgerPool to treasury or designated address.

- events: Emits recovery events in implementation.

- errors: Reverts with protocol‑specific recovery errors.

- reentrancy: Protected by nonReentrant modifier in implementation.

- access: Restricted to governance/admin.

- oracle: No oracle dependency.


```solidity
function recover(address token, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address to recover.|
|`amount`|`uint256`|Amount of tokens to send to treasury.|


### setSingleHedger

Sets the designated single hedger address.

Configures an address that is allowed to act as the sole hedger when single‑hedger
mode is enabled.

**Notes:**
- security: Restricted to governance; validates hedger is non‑zero.

- validation: May enforce that previous rotation has completed.

- state-changes: Updates single‑hedger configuration state.

- events: Emits `SingleHedgerRotationProposed`.

- errors: Reverts on invalid hedger address.

- reentrancy: Not applicable – configuration only.

- access: Restricted to governance roles.

- oracle: No oracle dependency.


```solidity
function setSingleHedger(address hedger) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address proposed as single hedger.|


### applySingleHedgerRotation

Applies a previously proposed single‑hedger rotation.

Finalizes the transition to `pendingSingleHedger` once any activation delay has elapsed.

**Notes:**
- security: Restricted to governance; relies on internal timing/quorum checks.

- validation: Reverts if there is no pending rotation or delay not met.

- state-changes: Updates `singleHedger` and clears pending rotation state.

- events: Emits `SingleHedgerRotationApplied`.

- errors: Reverts with protocol‑specific rotation errors.

- reentrancy: Not applicable – configuration only.

- access: Restricted to governance roles.

- oracle: No oracle dependency.


```solidity
function applySingleHedgerRotation() external;
```

### fundRewardReserve

Funds the reward reserve used to pay hedger rewards.

Transfers USDC from caller into the reward reserve accounting balance.

**Notes:**
- security: Callable by treasury/governance; validates positive amount.

- validation: Reverts on zero amount or insufficient allowance.

- state-changes: Increases internal reward reserve and vault balances.

- events: Emits `RewardReserveFunded`.

- errors: Reverts with protocol‑specific funding errors.

- reentrancy: Protected by nonReentrant modifier in implementation.

- access: Restricted to treasury/governance roles.

- oracle: No oracle dependency.


```solidity
function fundRewardReserve(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of USDC to add to the reserve.|


### usdc

Returns the USDC token used for margin and settlement.

Exposes the ERC20 collateral token that backs hedger margin and PnL.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function usdc() external view returns (IERC20 usdcToken);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`usdcToken`|`IERC20`|IERC20 instance of the USDC token.|


### oracle

Returns the oracle contract address used for pricing.

This oracle is used by the implementation to value exposure and margin.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: Exposes the price‑feed dependency.


```solidity
function oracle() external view returns (address oracleAddress);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`oracleAddress`|`address`|Address of the oracle.|


### yieldShift

Returns the YieldShift contract address.

YieldShift is responsible for computing and distributing protocol yield.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function yieldShift() external view returns (address yieldShiftAddress);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`yieldShiftAddress`|`address`|Address of the YieldShift contract.|


### vault

Returns the QuantillonVault contract address.

Vault holds unified USDC liquidity shared between users and hedgers.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function vault() external view returns (address vaultAddress);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`vaultAddress`|`address`|Address of the vault contract.|


### treasury

Returns the treasury address used for fee flows.

Treasury receives protocol fees and recovered funds from HedgerPool.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function treasury() external view returns (address treasuryAddress);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`treasuryAddress`|`address`|Treasury address.|


### coreParams

Returns packed core hedger parameters.

Exposes key risk and fee parameters as a compact tuple.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public – for UI and risk monitoring.

- oracle: No oracle dependency.


```solidity
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
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`minMarginRatio`|`uint64`|Minimum margin ratio (bps).|
|`maxLeverage`|`uint16`|Maximum allowed leverage (1e2 or similar scaling).|
|`entryFee`|`uint16`|Entry fee (bps).|
|`exitFee`|`uint16`|Exit fee (bps).|
|`marginFee`|`uint16`|Ongoing margin fee (bps).|
|`eurInterestRate`|`uint16`|EUR interest rate (bps).|
|`usdInterestRate`|`uint16`|USD interest rate (bps).|
|`reserved`|`uint8`|Reserved field for future use.|


### totalMargin

Returns the total margin locked across all hedger positions.

Sums the `margin` field of every active position, in USDC units.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function totalMargin() external view returns (uint256 margin);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`margin`|`uint256`|Total margin in USDC terms.|


### totalExposure

Returns the total notional exposure of all hedger positions.

Aggregates leveraged notional position sizes across all active hedgers.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function totalExposure() external view returns (uint256 exposure);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`exposure`|`uint256`|Total position size in notional units.|


### totalFilledExposure

Returns the total filled exposure across all positions.

Tracks how much of the theoretical exposure is actually filled in the market.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function totalFilledExposure() external view returns (uint256 filledExposure);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`filledExposure`|`uint256`|Total filled exposure.|


### singleHedger

Returns the currently active single hedger address.

When single‑hedger mode is enabled, only this address may open positions.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function singleHedger() external view returns (address hedgerAddress);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`hedgerAddress`|`address`|Single hedger address, or zero if not configured.|


### minPositionHoldBlocks

Returns the minimum number of blocks a position must be held.

Used to prevent instant in‑and‑out hedger positions around price updates.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function minPositionHoldBlocks() external view returns (uint256 minBlocks);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`minBlocks`|`uint256`|Minimum position hold in blocks.|


### minMarginAmount

Returns the minimum allowed margin amount for a position.

Positions with margin below this threshold are not allowed to open.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function minMarginAmount() external view returns (uint256 minMargin);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`minMargin`|`uint256`|Minimum margin in USDC terms.|


### pendingRewardWithdrawals

Returns pending reward withdrawals for a specific hedger.

Shows how much claimable USDC yield is currently assigned to `hedger`.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public – hedgers and UIs can inspect claimable rewards.

- oracle: No oracle dependency.


```solidity
function pendingRewardWithdrawals(address hedger) external view returns (uint256 amount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Pending reward amount in USDC.|


### feeCollector

Returns the FeeCollector contract address.

FeeCollector aggregates protocol fees before they are routed to treasury or rewards.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function feeCollector() external view returns (address feeCollectorAddress);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`feeCollectorAddress`|`address`|Address of the fee collector.|


### rewardFeeSplit

Returns the current reward fee split between treasury and hedgers.

Implementations use this split to decide how collected fees are allocated.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function rewardFeeSplit() external view returns (uint256 split);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`split`|`uint256`|Reward fee split as a fraction (bps or 1e18‑scaled per implementation).|


### MAX_REWARD_FEE_SPLIT

Returns the maximum allowed reward fee split.

Governance cannot configure `rewardFeeSplit` above this constant.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function MAX_REWARD_FEE_SPLIT() external view returns (uint256 maxSplit);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`maxSplit`|`uint256`|Maximum allowed split constant.|


### pendingSingleHedger

Returns the pending single hedger address, if any.

When non‑zero, this address will become `singleHedger` once rotation is applied.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function pendingSingleHedger() external view returns (address pending);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`pending`|`address`|Address that will become the single hedger after rotation is applied.|


### singleHedgerPendingAt

Returns the timestamp at which the pending single hedger can be applied.

After this timestamp, `applySingleHedgerRotation` may finalize the rotation.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function singleHedgerPendingAt() external view returns (uint256 pendingAt);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`pendingAt`|`uint256`|Unix timestamp when rotation becomes executable.|


### hedgerLastRewardBlock

Returns the last block number at which a hedger claimed rewards.

Useful for enforcing minimum intervals between reward claims.

**Notes:**
- security: View‑only; no access restriction.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: No oracle dependency.


```solidity
function hedgerLastRewardBlock(address hedger) external view returns (uint256 lastRewardBlock);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`lastRewardBlock`|`uint256`|Block number of the last reward claim.|


### positions

Returns full position data for a given position id.

Provides a denormalized snapshot of all key risk metrics for off‑chain monitoring.

**Notes:**
- security: View‑only; no access restriction.

- validation: Returns zeroed values for nonexistent positions.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public – for analytics and monitoring.

- oracle: No oracle dependency.


```solidity
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
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`positionId`|`uint256`|Identifier of the position.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Hedger address owning the position.|
|`positionSize`|`uint96`|Current notional position size.|
|`filledVolume`|`uint96`|Filled hedge volume.|
|`margin`|`uint96`|Current margin allocated to the position.|
|`entryPrice`|`uint96`|Price at which the position was opened.|
|`entryTime`|`uint32`|Timestamp of position opening.|
|`lastUpdateTime`|`uint32`|Timestamp of last position update.|
|`unrealizedPnL`|`int128`|Current unrealized PnL (signed).|
|`realizedPnL`|`int128`|Realized PnL accumulated so far (signed).|
|`leverage`|`uint16`|Position leverage.|
|`isActive`|`bool`|Whether the position is currently active.|
|`qeuroBacked`|`uint128`|Amount of QEURO backed by this position.|
|`openBlock`|`uint64`|Block number at which the position was opened.|


## Events
### HedgePositionOpened

```solidity
event HedgePositionOpened(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
```

### HedgePositionClosed

```solidity
event HedgePositionClosed(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
```

### MarginUpdated

```solidity
event MarginUpdated(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
```

### HedgingRewardsClaimed

```solidity
event HedgingRewardsClaimed(address indexed hedger, bytes32 packedData);
```

### RewardReserveFunded

```solidity
event RewardReserveFunded(address indexed funder, uint256 amount);
```

### SingleHedgerRotationProposed

```solidity
event SingleHedgerRotationProposed(
    address indexed currentHedger, address indexed pendingHedger, uint256 activatesAt
);
```

### SingleHedgerRotationApplied

```solidity
event SingleHedgerRotationApplied(address indexed previousHedger, address indexed newHedger);
```

## Structs
### HedgerRiskConfig

```solidity
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
```

### HedgerDependencyConfig

```solidity
struct HedgerDependencyConfig {
    address treasury;
    address vault;
    address oracle;
    address yieldShift;
    address feeCollector;
}
```

