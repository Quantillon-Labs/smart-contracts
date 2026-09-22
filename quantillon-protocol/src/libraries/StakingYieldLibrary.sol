// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IExternalStakingVault} from "../interfaces/IExternalStakingVault.sol";
import {IStQEUROFactory} from "../interfaces/IStQEUROFactory.sol";
import {IstQEURO} from "../interfaces/IstQEURO.sol";
import {CommonErrorLibrary} from "./CommonErrorLibrary.sol";
import {VaultMath} from "./VaultMath.sol";

/**
 * @title StakingYieldLibrary
 * @notice External (linked) library holding the stQEURO yield-distribution split, extracted from
 *         QuantillonVault to keep that contract under the EIP-170 24,576-byte runtime limit.
 * @dev Called via delegatecall from QuantillonVault, so external calls (adapter harvest, USDC
 *      transfers) execute in the vault's context (`address(this)` == vault). The vault performs the
 *      stQEURO credit and event emission; this library realizes the yield, computes the hedger /
 *      staker / treasury split, and routes the hedger and treasury shares.
 */
library StakingYieldLibrary {
    using SafeERC20 for IERC20;
    using VaultMath for uint256;

    uint256 private constant BPS_DENOMINATOR = 10000;

    event UsdcWithdrawnFromExternalVault(uint256 indexed vaultId, uint256 indexed usdcAmount, uint256 principalAfter);

    event StakingVaultConfigured(uint256 indexed vaultId, address indexed adapter, bool active);
    event ExternalVaultLossRealized(uint256 indexed vaultId, uint256 previousPrincipal, uint256 currentUnderlying);

    event RedemptionPriorityUpdated(uint256[] vaultIds);

    /**
     * @notice Replaces the withdrawal priority with unique configured adapter ids.
     * @dev Prevents duplicate principal accounting in priority-dependent views.
     * @param adapters Adapter registry.
     * @param active Active flags.
     * @param priority Existing priority storage.
     * @param ids Requested ids.
     * @custom:security Caller enforces governance authorization.
     * @custom:validation Rejects inactive, duplicate, zero, or unconfigured ids.
     * @custom:state-changes Replaces priority storage.
     * @custom:events RedemptionPriorityUpdated.
     * @custom:errors InvalidVault or ZeroAddress.
     * @custom:reentrancy No external calls.
     * @custom:access Linked library.
     * @custom:oracle None.
     */
    function setPriority(
        mapping(uint256 => IExternalStakingVault) storage adapters,
        mapping(uint256 => bool) storage active,
        uint256[] storage priority, uint256[] calldata ids
    ) external {
        while (priority.length != 0) priority.pop();
        for (uint256 i; i < ids.length; ++i) {
            uint256 id = ids[i];
            if (id == 0 || !active[id]) revert CommonErrorLibrary.InvalidVault();
            if (address(adapters[id]) == address(0)) revert CommonErrorLibrary.ZeroAddress();
            for (uint256 j; j < i; ++j) {
                if (ids[j] == id) revert CommonErrorLibrary.InvalidVault();
            }
            priority.push(id);
        }
        emit RedemptionPriorityUpdated(ids);
    }

    /**
     * @notice Configures an external adapter while preserving tracked collateral.
     * @dev Funded replacements require a paused vault, empty old adapter, and funded new adapter.
     * @param adapters Adapter registry.
     * @param active Active adapter flags.
     * @param principal Tracked principal by vault.
     * @param id Vault id.
     * @param next New adapter.
     * @param enabled Requested active flag.
     * @param isPaused Vault pause state.
     * @custom:security Caller enforces governance authorization.
     * @custom:validation Rejects disabling funded adapters and unfunded replacements.
     * @custom:state-changes Updates registry and active flag.
     * @custom:events StakingVaultConfigured.
     * @custom:errors InvalidVault, ZeroAddress, InvalidCondition.
     * @custom:reentrancy External adapter calls are view-only.
     * @custom:access Linked library.
     * @custom:oracle None.
     */
    function configureAdapter(
        mapping(uint256 => IExternalStakingVault) storage adapters,
        mapping(uint256 => bool) storage active,
        mapping(uint256 => uint256) storage principal,
        uint256 id, address next, bool enabled, bool isPaused
    ) external {
        if (id == 0) revert CommonErrorLibrary.InvalidVault();
        if (next == address(0)) revert CommonErrorLibrary.ZeroAddress();
        if (principal[id] != 0) {
            if (!enabled) revert CommonErrorLibrary.InvalidCondition();
            if (address(adapters[id]) != next) {
                if (!isPaused || adapters[id].totalUnderlying() != 0 ||
                    IExternalStakingVault(next).totalUnderlying() < principal[id]) {
                    revert CommonErrorLibrary.InvalidCondition();
                }
            }
        }
        adapters[id] = IExternalStakingVault(next);
        active[id] = enabled;
        emit StakingVaultConfigured(id, next, enabled);
    }

    /**
     * @notice Records reduced external collateral without changing hedger margin.
     * @dev The caller deducts the returned loss from aggregate external principal.
     * @param adapters Adapter registry.
     * @param principal Tracked principal by vault.
     * @param id Vault id.
     * @return loss USDC principal loss recognized.
     * @custom:security Caller enforces governance authorization.
     * @custom:validation Adapter must exist and report less underlying than tracked principal.
     * @custom:state-changes Reduces per-vault principal.
     * @custom:events ExternalVaultLossRealized.
     * @custom:errors InvalidVault or InvalidCondition.
     * @custom:reentrancy View-only adapter call.
     * @custom:access Linked library.
     * @custom:oracle None.
     */
    function realizeLoss(
        mapping(uint256 => IExternalStakingVault) storage adapters,
        mapping(uint256 => uint256) storage principal,
        uint256 id
    ) external returns (uint256 loss) {
        if (address(adapters[id]) == address(0)) revert CommonErrorLibrary.InvalidVault();
        uint256 previous = principal[id];
        uint256 underlying = adapters[id].totalUnderlying();
        if (underlying >= previous) revert CommonErrorLibrary.InvalidCondition();
        loss = previous - underlying;
        principal[id] = underlying;
        emit ExternalVaultLossRealized(id, previous, underlying);
    }

    /**
     * @notice Registers and verifies a deterministic per-vault staking token.
     * @dev Preserves registry binding before the external factory call.
     * @param tokens Per-vault staking token registry.
     * @param factory Factory address.
     * @param id Vault identifier.
     * @param name Vault name.
     * @return token Registered staking token.
     * @custom:security Vault wrapper enforces governance and nonReentrant.
     * @custom:validation Requires a fresh valid binding and matching preview.
     * @custom:state-changes Stores token binding.
     * @custom:events Factory emits registration events; caller emits local registration.
     * @custom:errors InvalidToken, InvalidVault, AlreadyInitialized, InvalidAddress.
     * @custom:reentrancy Caller holds the guard.
     * @custom:access Linked library.
     * @custom:oracle None.
     */
    function registerToken(mapping(uint256 => address) storage tokens, address factory, uint256 id, string calldata name)
        external returns (address token)
    {
        if (factory == address(0)) revert CommonErrorLibrary.InvalidToken();
        if (id == 0) revert CommonErrorLibrary.InvalidVault();
        if (tokens[id] != address(0)) revert CommonErrorLibrary.AlreadyInitialized();
        token = IStQEUROFactory(factory).previewVaultToken(address(this), id, name);
        if (token == address(0)) revert CommonErrorLibrary.InvalidAddress();
        tokens[id] = token;
        if (IStQEUROFactory(factory).registerVault(id, name) != token) revert CommonErrorLibrary.InvalidAddress();
    }

    /**
     * @notice Sources an exact aggregate payout from priority-ordered adapters.
     * @dev Requires every adapter to return the exact requested amount and verifies the balance
     *      delta. Adapters must absorb any rounding dust internally before returning.
     * @param adapters Adapter registry.
     * @param active Active adapter flags.
     * @param principal Per-adapter tracked principal.
     * @param priority Ordered source identifiers.
     * @param amount Exact USDC deficit to source.
     * @param usdc Collateral token.
     * @return withdrawn Aggregate transferred USDC.
     * @custom:security Delegatecalled from guarded vault settlement.
     * @custom:validation Requires exact aggregate liquidity and verifies adapter balance deltas.
     * @custom:state-changes Reduces per-adapter principal; caller reduces aggregate principal.
     * @custom:events UsdcWithdrawnFromExternalVault.
     * @custom:errors InvalidAmount or InsufficientBalance.
     * @custom:reentrancy Caller holds nonReentrant guard.
     * @custom:access Linked library.
     * @custom:oracle None.
     */
    function withdrawPrincipal(
        mapping(uint256 => IExternalStakingVault) storage adapters,
        mapping(uint256 => bool) storage active,
        mapping(uint256 => uint256) storage principal,
        uint256[] memory priority, uint256 amount, IERC20 usdc
    ) external returns (uint256 withdrawn) {
        for (uint256 i; i < priority.length && withdrawn < amount; ++i) {
            uint256 id = priority[i];
            if (!active[id] || address(adapters[id]) == address(0) || principal[id] == 0) continue;
            uint256 requested = amount - withdrawn;
            if (requested > principal[id]) requested = principal[id];
            uint256 beforeBalance = usdc.balanceOf(address(this));
            uint256 received = adapters[id].withdrawUnderlying(requested);
            if (received != requested || usdc.balanceOf(address(this)) - beforeBalance != received) {
                revert CommonErrorLibrary.InvalidAmount();
            }
            principal[id] -= requested;
            withdrawn += received;
            emit UsdcWithdrawnFromExternalVault(id, requested, principal[id]);
        }
        if (withdrawn != amount) revert CommonErrorLibrary.InsufficientBalance();
    }

    /**
     * @notice Returns the semantic version of this linked library.
     * @dev On-chain version of the standalone deployed library; bump per semver on any change.
     *      See deployments/{chainId}/versions.json for deployed-address provenance.
     * @return Semantic version string (e.g. "1.0.0").
     * @custom:security No security implications - returns a compile-time constant.
     * @custom:validation No input validation required.
     * @custom:state-changes None - pure function.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable - pure function.
     * @custom:access Public - anyone can read the version.
     * @custom:oracle No oracle dependencies.
     */
    function version() external pure returns (string memory) {
        return "1.3.2";
    }

    /**
     * @notice Inputs for `harvestAndSplit`, read from vault storage by the caller.
     * @param adapter External staking vault adapter for the vault id.
     * @param stToken stQEURO share token for the vault id (zero if unregistered).
     * @param qeuro QEURO token (for circulating supply).
     * @param usdc USDC token used for hedger/treasury routing.
     * @param treasury Protocol treasury (treasury share + hedger fallback recipient).
     * @param hedgerRecipient Hedger funding recipient (falls back to treasury when zero).
     * @param principalUsdc Tracked principal deployed to the vault (hedger notional, 6 decimals).
     * @param fundingRateAnnualBps Annualized hedger funding rate in basis points.
     * @param lastHarvest Timestamp of the previous distribution (0 = first call, no hedger accrual).
     */
    struct DistributeParams {
        address adapter;
        address stToken;
        address qeuro;
        address usdc;
        address treasury;
        address hedgerRecipient;
        uint256 principalUsdc;
        uint256 fundingRateAnnualBps;
        uint256 lastHarvest;
    }

    /**
     * @notice Harvests adapter yield and splits it: hedger funding first, residual by staked ratio,
     *         remainder to treasury; routes the hedger and treasury shares in USDC.
     * @dev The caller (vault) credits `userShare` into stQEURO and emits the distribution event.
     * @param p Distribution inputs read from vault storage.
     * @return realizedYield Total USDC yield realized from the adapter (6 decimals).
     * @return hedgerShare USDC routed to the hedger recipient (6 decimals).
     * @return userShare USDC the vault must credit into stQEURO (6 decimals).
     * @return treasuryShare USDC routed to the treasury (6 decimals).
     * @custom:security Runs under the vault's `nonReentrant`/pause guards via delegatecall.
     * @custom:validation Caller validates vault id, adapter, and access control.
     * @custom:state-changes Moves USDC out of the vault to hedger recipient and treasury.
     * @custom:events None; the vault emits `VaultYieldDistributed`.
     * @custom:errors Reverts on adapter or transfer failures.
     * @custom:reentrancy Caller-guarded.
     * @custom:access Internal protocol use (linked library).
     * @custom:oracle No oracle dependency in this library.
     */
    // slither-disable-next-line timestamp
    function harvestAndSplit(DistributeParams memory p)
        external
        returns (uint256 realizedYield, uint256 hedgerShare, uint256 userShare, uint256 treasuryShare)
    {
        realizedYield = IExternalStakingVault(p.adapter).harvestYieldToVault();
        if (realizedYield == 0) return (0, 0, 0, 0);

        // Hedger funding carve-out: absolute, time-prorated on the deployed notional. First call
        // (lastHarvest == 0) only anchors the clock, so no hedger share accrues.
        if (p.lastHarvest != 0 && p.fundingRateAnnualBps != 0 && block.timestamp > p.lastHarvest) {
            uint256 elapsed = block.timestamp - p.lastHarvest;
            hedgerShare = p.principalUsdc.mulDiv(p.fundingRateAnnualBps * elapsed, BPS_DENOMINATOR * 365 days);
            // MINIMAL V1: never draw from the user pool — cap the hedger share at the realized yield.
            if (hedgerShare > realizedYield) hedgerShare = realizedYield;
        }

        uint256 residual = realizedYield - hedgerShare;

        // Residual split: staked users (via stQEURO share price) pro-rata to staked/circulating QEURO,
        // remainder to treasury (the share attributable to unstaked QEURO).
        if (residual > 0) {
            uint256 staked = 0;
            if (p.stToken != address(0) && IstQEURO(p.stToken).totalSupply() > 0) {
                staked = IstQEURO(p.stToken).totalAssets();
            }
            uint256 circulating = IERC20(p.qeuro).totalSupply();
            if (staked > circulating) staked = circulating;
            userShare = (staked == 0 || circulating == 0) ? 0 : residual.mulDiv(staked, circulating);
            treasuryShare = residual - userShare;
        }

        // Route the hedger and treasury shares from the realized USDC now held by the vault.
        if (hedgerShare > 0) {
            address hedgerSink = p.hedgerRecipient == address(0) ? p.treasury : p.hedgerRecipient;
            IERC20(p.usdc).safeTransfer(hedgerSink, hedgerShare);
        }
        if (treasuryShare > 0) {
            IERC20(p.usdc).safeTransfer(p.treasury, treasuryShare);
        }
    }
}
