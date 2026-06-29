// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IExternalStakingVault} from "../interfaces/IExternalStakingVault.sol";
import {IstQEURO} from "../interfaces/IstQEURO.sol";
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
            // MINIMAL V1: never ponction the user pool — cap the hedger share at the realized yield.
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
