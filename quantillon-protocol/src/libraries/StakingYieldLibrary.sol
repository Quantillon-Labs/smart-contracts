// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IQuantillonVault} from "../interfaces/IQuantillonVault.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {IHedgerPool} from "../interfaces/IHedgerPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IExternalStakingVault} from "../interfaces/IExternalStakingVault.sol";
import {IStQEUROFactory} from "../interfaces/IStQEUROFactory.sol";
import {CommonErrorLibrary} from "./CommonErrorLibrary.sol";
import {VaultMath} from "./VaultMath.sol";

/// @notice Vault getters used by linked distribution code to keep proxy runtime compact.
interface IYieldDistributionVault is IQuantillonVault {
    /**
     * @notice Configured hedger accounting contract.
     * @dev Read from the calling vault during library delegatecall.
     * @return Configured address.
     * @custom:security Read-only vault getter.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy View only.
     * @custom:access Public.
     * @custom:oracle None.
     */
    function hedgerPool() external view returns (address);
    /**
     * @notice Protocol treasury recipient.
     * @dev Read from the calling vault during library delegatecall.
     * @return Configured address.
     * @custom:security Read-only vault getter.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy View only.
     * @custom:access Public.
     * @custom:oracle None.
     */
    function treasury() external view returns (address);
    /**
     * @notice Capital distribution haircut, recipient and last harvest.
     * @dev Read from the calling vault during library delegatecall.
     * @param vaultId Selected strategy.
     * @return Haircut basis points.
     * @return Hedger recipient.
     * @return Last successful harvest timestamp.
     * @custom:security Read-only vault getter.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy View only.
     * @custom:access Public.
     * @custom:oracle None.
     */
    function yieldDistributionConfig(uint256 vaultId) external view returns (uint256, address, uint256);
}

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
    event VaultYieldDistributed(uint256 indexed vaultId, uint256 realizedYield, uint256 hedgerShare, uint256 userShare, uint256 treasuryShare);
    event VaultYieldBreakdown(uint256 indexed vaultId, uint256 hedgerBase, uint256 stakingYieldHaircut);

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
        address existingFactory = IYieldDistributionVault(address(this)).stQEUROFactory();
        if (existingFactory != address(0) && existingFactory != factory) revert CommonErrorLibrary.InvalidCondition();
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
        return "1.4.0";
    }

    /// @notice Configuration and capital registries supplied by the calling vault.
    struct DistributeParams {
        address adapter;
        address stToken;
        address qeuro;
        address usdc;
        address treasury;
        address hedgerRecipient;
        uint256 principalUsdc;
        uint256 totalPrincipalUsdc;
        uint256 haircutBps;
        address factory;
        address hedgerPool;
        address oracle;
        uint256 vaultId;
    }

    /// @notice USDC amounts before the staking token's existing yield fee and execution costs.
    struct Split {
        uint256 realizedYield;
        uint256 hedgerBase;
        uint256 haircut;
        uint256 hedgerShare;
        uint256 userShare;
        uint256 treasuryShare;
    }

    /// @notice Harvest-time ownership snapshot, excluding the yield being distributed.
    struct Capital {
        uint256 hedger;
        uint256 userBacking;
        uint256 staked;
        uint256 supply;
    }

    /**
     * @notice Calculate conserved capital-weighted allocations of realized yield.
     * @dev Floors the hedger base and haircut; residual rounding remains in the user/treasury allocation.
     * @param yieldUsdc Realized USDC yield.
     * @param c Economic ownership snapshot.
     * @param haircutBps Percentage of gross staker yield, in basis points.
     * @return s Distribution before existing staking fees.
     * @custom:security Never deducts principal; allocations sum to yieldUsdc.
     * @custom:validation Haircut cannot exceed 100%.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors AboveLimit for an invalid haircut.
     * @custom:reentrancy No external calls.
     * @custom:access Public library calculation.
     * @custom:oracle Uses caller-supplied economic values.
     */
    // Zero selects an empty pool; positive balances always use proportional allocation.
    // slither-disable-next-line incorrect-equality
    function calculateSplit(uint256 yieldUsdc, Capital memory c, uint256 haircutBps)
        public pure returns (Split memory s)
    {
        if (haircutBps > BPS_DENOMINATOR) revert CommonErrorLibrary.AboveLimit();
        s.realizedYield = yieldUsdc;
        uint256 capital = c.hedger + c.userBacking;
        if (capital == 0) {
            s.treasuryShare = yieldUsdc;
            return s;
        }
        s.hedgerBase = yieldUsdc.mulDiv(c.hedger, capital);
        uint256 userPool = yieldUsdc - s.hedgerBase;
        uint256 staked = c.staked > c.supply ? c.supply : c.staked;
        uint256 gross = c.supply == 0 ? 0 : userPool.mulDiv(staked, c.supply);
        s.haircut = gross.mulDiv(haircutBps, BPS_DENOMINATOR);
        s.hedgerShare = s.hedgerBase + s.haircut;
        s.userShare = gross - s.haircut;
        s.treasuryShare = userPool - gross;
    }

    /// @notice Resolve the calling vault's configuration before taking a capital snapshot.
    /// @dev Only called by delegatecall entrypoints; external self-calls read public vault getters.
    /// @param vaultId Selected strategy.
    /// @return p Validated configuration.
    function _params(uint256 vaultId) private view returns (DistributeParams memory p) {
        IYieldDistributionVault v = IYieldDistributionVault(address(this));
        bool active;
        // Underlying is sampled by preview/harvest, separately from tracked principal.
        // slither-disable-next-line unused-return
        (p.adapter, active, p.principalUsdc,) = v.getVaultExposure(vaultId);
        if (vaultId == 0 || !active) revert CommonErrorLibrary.InvalidVault();
        if (p.adapter == address(0)) revert CommonErrorLibrary.ZeroAddress();
        // The timestamp guards keeper scheduling; it does not affect ownership weights.
        // slither-disable-next-line unused-return
        (p.haircutBps, p.hedgerRecipient,) = v.yieldDistributionConfig(vaultId);
        p.stToken = v.stQEUROTokenByVaultId(vaultId);
        p.qeuro = v.qeuro();
        p.usdc = v.usdc();
        p.treasury = v.treasury();
        p.totalPrincipalUsdc = v.totalUsdcInExternalVaults();
        p.factory = v.stQEUROFactory();
        p.hedgerPool = v.hedgerPool();
        p.oracle = v.oracle();
        p.vaultId = vaultId;
    }

    /**
     * @notice Snapshot capital and enforce the single-funded-strategy distribution boundary.
     * @dev Registered token balances include credited unvested QEURO when shareholders exist.
     * @param p Calling vault configuration.
     * @return c Economic ownership before harvest and minting.
     * @custom:security Fails closed on unsupported strategies or invalid oracle/accounting reads.
     * @custom:validation All external principal and all outstanding staking shares must belong to this series.
     * @custom:state-changes Oracle may refresh its price cache.
     * @custom:events Oracle events only.
     * @custom:errors InvalidCondition, InvalidVault, InvalidOraclePrice, or propagated external errors.
     * @custom:reentrancy Caller holds its reentrancy guard.
     * @custom:access Internal library helper.
     * @custom:oracle Fresh validated EUR/USD reference price.
     */
    function _snapshot(DistributeParams memory p) private returns (Capital memory c) {
        if (p.totalPrincipalUsdc != p.principalUsdc) revert CommonErrorLibrary.InvalidCondition();
        if (p.factory != address(0)) {
            uint256[] memory ids = IStQEUROFactory(p.factory).getVaultIdsByVault(address(this));
            for (uint256 i; i < ids.length; ++i) {
                if (ids[i] == p.vaultId) continue;
                // Reject funds in other strategies regardless of their active flag or adapter address.
                // slither-disable-next-line unused-return
                (,, uint256 otherPrincipal, uint256 otherUnderlying) = IYieldDistributionVault(address(this)).getVaultExposure(ids[i]);
                if (otherPrincipal != 0 || otherUnderlying != 0) revert CommonErrorLibrary.InvalidCondition();
                address other = IStQEUROFactory(p.factory).getStQEUROByVaultId(ids[i]);
                if (other != address(0) && IERC20(other).totalSupply() != 0) {
                    revert CommonErrorLibrary.InvalidCondition();
                }
            }
        }
        (uint256 price, bool valid) = IOracle(p.oracle).getEurUsdPrice();
        if (!valid || price == 0) revert CommonErrorLibrary.InvalidOraclePrice();
        c.supply = IERC20(p.qeuro).totalSupply();
        c.userBacking = c.supply.mulDiv(price, 1e30);
        if (p.hedgerPool != address(0)) {
            c.hedger = IHedgerPool(p.hedgerPool).getTotalEffectiveHedgerCollateral(price);
        }
        if (p.stToken != address(0) && IERC20(p.stToken).totalSupply() > 0) {
            c.staked = IERC20(p.qeuro).balanceOf(p.stToken);
        }
    }

    /**
     * @notice Preview the next distribution with the same ownership calculation as execution.
     * @dev Call through eth_call: the oracle interface can refresh state. Actual realized yield may differ.
     * @param vaultId Selected strategy.
     * @return s Estimated USDC allocations before existing staking fees.
     * @custom:security Shares execution validation and requires a recipient for nonzero hedger payments.
     * @custom:validation Validates capital, strategy boundary, oracle and recipient.
     * @custom:state-changes Oracle cache only; eth_call persists nothing.
     * @custom:events Oracle events only.
     * @custom:errors Propagates snapshot errors; ZeroAddress for a missing hedger recipient.
     * @custom:reentrancy Caller holds its reentrancy guard.
     * @custom:access Linked library.
     * @custom:oracle Fresh EUR/USD reference price.
     */
    function previewSplit(uint256 vaultId) external returns (Split memory s) {
        DistributeParams memory p = _params(vaultId);
        Capital memory c = _snapshot(p);
        uint256 underlying = IExternalStakingVault(p.adapter).totalUnderlying();
        s = calculateSplit(underlying > p.principalUsdc ? underlying - p.principalUsdc : 0, c, p.haircutBps);
        if (s.hedgerShare > 0 && p.hedgerRecipient == address(0)) revert CommonErrorLibrary.ZeroAddress();
    }

    /**
     * @notice Harvest and allocate yield by economic capital, with a haircut on gross staking yield.
     * @dev The vault credits userShare via its existing QEURO mint path. Failure rolls back the whole harvest.
     * @param vaultId Selected strategy.
     * @param lastHarvest Keeper timestamps updated atomically with distribution.
     * @return userShare USDC allocation to credit through the existing QEURO mint path.
     * @custom:security Principal is untouched; no fallback recipient silently captures hedger yield.
     * @custom:validation Same capital validation as preview; nonzero hedger payout requires a recipient.
     * @custom:state-changes Harvests adapter yield and transfers hedger/treasury USDC.
     * @custom:events Adapter/token/oracle events; the vault emits distribution events.
     * @custom:errors Propagates snapshot/adapter/token errors; ZeroAddress for missing recipient.
     * @custom:reentrancy Caller holds its reentrancy guard.
     * @custom:access Linked library.
     * @custom:oracle Snapshot taken before harvesting and yield minting.
     */
    function harvestAndSplit(uint256 vaultId, mapping(uint256 => uint256) storage lastHarvest) external returns (uint256 userShare) {
        Split memory s;
        DistributeParams memory p = _params(vaultId);
        Capital memory c = _snapshot(p);
        s = calculateSplit(IExternalStakingVault(p.adapter).harvestYieldToVault(), c, p.haircutBps);
        if (s.hedgerShare > 0) {
            if (p.hedgerRecipient == address(0)) revert CommonErrorLibrary.ZeroAddress();
            IERC20(p.usdc).safeTransfer(p.hedgerRecipient, s.hedgerShare);
        }
        if (s.treasuryShare > 0) IERC20(p.usdc).safeTransfer(p.treasury, s.treasuryShare);
        lastHarvest[vaultId] = block.timestamp;
        emit VaultYieldDistributed(vaultId, s.realizedYield, s.hedgerShare, s.userShare, s.treasuryShare);
        emit VaultYieldBreakdown(vaultId, s.hedgerBase, s.haircut);
        return s.userShare;
    }
}
