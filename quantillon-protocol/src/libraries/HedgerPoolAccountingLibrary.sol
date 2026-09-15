// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {HedgerPool} from "../core/HedgerPool.sol";
import {HedgerPoolLogicLibrary} from "./HedgerPoolLogicLibrary.sol";
import {HedgerPoolValidationLibrary} from "./HedgerPoolValidationLibrary.sol";
import {CommonErrorLibrary} from "./CommonErrorLibrary.sol";
import {IYieldShift} from "../interfaces/IYieldShift.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title HedgerPoolAccountingLibrary
/// @notice Existing pool accounting extracted to keep HedgerPool deployable.
/// @dev Delegatecalled with explicit storage references; owns no storage namespace.
library HedgerPoolAccountingLibrary {
    using SafeERC20 for IERC20;

    /**
     * @notice Validates and applies the existing risk and fee configuration.
     * @dev Scalar settings outside CoreParams remain assigned by the pool.
     * @param params Pool core parameters in storage.
     * @param cfg Requested complete risk and fee configuration.
     * @custom:security Pool wrappers enforce caller authority and storage references.
     * @custom:validation Uses the pool's existing validation rules.
     * @custom:state-changes Updates only the explicitly supplied accounting storage.
     * @custom:events None.
     * @custom:errors Propagates accounting, validation and trusted integration errors.
     * @custom:reentrancy State-changing pool wrappers are nonReentrant except governance configuration.
     * @custom:access Linked library invoked by HedgerPool through delegatecall.
     * @custom:oracle No oracle lookup; prices, where present, are supplied by the caller.
     */
    function configure(HedgerPool.CoreParams storage params, HedgerPool.HedgerRiskConfig calldata cfg) external {
        if (cfg.minMarginRatio < 250) revert CommonErrorLibrary.ConfigValueTooLow();
        if (cfg.minMarginRatio > type(uint64).max) revert CommonErrorLibrary.ConfigValueTooHigh();
        if (cfg.maxLeverage > 40) revert CommonErrorLibrary.ConfigValueTooHigh();
        if (cfg.eurInterestRate > 2000 || cfg.usdInterestRate > 2000) revert CommonErrorLibrary.ConfigValueTooHigh();
        HedgerPoolValidationLibrary.validateFee(cfg.entryFee, 100);
        HedgerPoolValidationLibrary.validateFee(cfg.exitFee, 100);
        HedgerPoolValidationLibrary.validateFee(cfg.marginFee, 50);
        if (cfg.rewardFeeSplit > 1e18) revert CommonErrorLibrary.ConfigValueTooHigh();

        // forge-lint: disable-next-line(unsafe-typecast)
        params.minMarginRatio = uint64(cfg.minMarginRatio);
        // forge-lint: disable-next-line(unsafe-typecast)
        params.maxLeverage = uint16(cfg.maxLeverage);
        // forge-lint: disable-next-line(unsafe-typecast)
        params.eurInterestRate = uint16(cfg.eurInterestRate);
        // forge-lint: disable-next-line(unsafe-typecast)
        params.usdInterestRate = uint16(cfg.usdInterestRate);
        // forge-lint: disable-next-line(unsafe-typecast)
        params.entryFee = uint16(cfg.entryFee);
        // forge-lint: disable-next-line(unsafe-typecast)
        params.exitFee = uint16(cfg.exitFee);
        // forge-lint: disable-next-line(unsafe-typecast)
        params.marginFee = uint16(cfg.marginFee);

    }

    /**
     * @notice Values the active position using remaining cost and the caller's price.
     * @dev Floors negative effective collateral at zero; realized history is already in margin.
     * @param position Active position storage.
     * @param price EUR/USD price with 18 decimals.
     * @return collateral Effective USDC collateral, floored at zero.
     * @custom:security Read-only helper.
     * @custom:validation No input validation required unless described above.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None beyond checked arithmetic.
     * @custom:reentrancy No state-changing external calls.
     * @custom:access Linked library helper.
     * @custom:oracle No oracle lookup.
     */
    function effectiveCollateral(HedgerPool.HedgePosition storage position, uint256 price) external view returns (uint256) {
        if (!position.isActive) return 0;
        int256 effective = int256(uint256(position.margin)) + HedgerPoolLogicLibrary.calculatePnL(
            uint256(position.filledVolume), uint256(position.qeuroBacked), price
        );
        return effective > 0 ? uint256(effective) : 0;
    }

    /**
     * @notice Reports the initial library release.
     * @dev Uses no additional sequential storage slots.
     * @return release Semantic version string.
     * @custom:security Read-only helper.
     * @custom:validation No input validation required unless described above.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None beyond checked arithmetic.
     * @custom:reentrancy No state-changing external calls.
     * @custom:access Linked library helper.
     * @custom:oracle No oracle lookup.
     */
    function version() external pure returns (string memory) { return "1.0.0"; }

    /**
     * @notice Accrues interest into withdrawal escrow and claims external yield.
     * @dev Preserves the pool's legacy-clock migration, narrowing casts and pull settlement.
     * @param rewardState Current hedger reward state.
     * @param rewardTimes Per-hedger accrual clocks.
     * @param pendingWithdrawals Per-hedger withdrawal escrow.
     * @param params Pool interest rate configuration.
     * @param totalExposure Pool notional exposure.
     * @param currentTime Canonical protocol time.
     * @param maxRewardPeriod Maximum accrual duration.
     * @param yieldShift Trusted yield distributor.
     * @return interestDifferential Interest queued for withdrawal.
     * @return yieldShiftRewards Yield paid by YieldShift.
     * @return totalRewards Sum of both reward sources.
     * @custom:security Pool wrappers enforce caller authority and storage references.
     * @custom:validation Uses the pool's existing validation rules.
     * @custom:state-changes Updates only the explicitly supplied accounting storage.
     * @custom:events None.
     * @custom:errors Propagates accounting, validation and trusted integration errors.
     * @custom:reentrancy State-changing pool wrappers are nonReentrant except governance configuration.
     * @custom:access Linked library invoked by HedgerPool through delegatecall.
     * @custom:oracle No oracle lookup; prices, where present, are supplied by the caller.
     */
    function claim(
        HedgerPool.HedgerRewardState storage rewardState,
        mapping(address => uint256) storage rewardTimes,
        mapping(address => uint256) storage pendingWithdrawals,
        HedgerPool.CoreParams storage params,
        uint256 totalExposure,
        uint256 currentTime,
        uint256 maxRewardPeriod,
        IYieldShift yieldShift
    ) external returns (uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards) {
        address hedger = msg.sender;
        uint256 lastRewardTime = rewardTimes[hedger];
        if (lastRewardTime > 0 && lastRewardTime < 1_000_000_000) lastRewardTime = currentTime;
        (uint256 pending, uint256 last) = HedgerPoolLogicLibrary.calculateRewardUpdate(
            totalExposure, params.eurInterestRate, params.usdInterestRate,
            lastRewardTime, currentTime, maxRewardPeriod, uint256(rewardState.pendingRewards)
        );
        // Preserve the original uint128 accounting behavior.
        interestDifferential = uint128(pending);
        rewardTimes[hedger] = last;
        rewardState.lastRewardClaim = uint64(currentTime);
        rewardState.pendingRewards = 0;
        if (interestDifferential > 0) pendingWithdrawals[hedger] += interestDifferential;
        yieldShiftRewards = yieldShift.hedgerPendingYield(hedger);
        if (yieldShiftRewards > 0) {
            yieldShiftRewards = yieldShift.claimHedgerYield(hedger);
            if (yieldShiftRewards == 0) revert CommonErrorLibrary.YieldClaimFailed();
        }
        totalRewards = interestDifferential + yieldShiftRewards;
    }

    /**
     * @notice Pays the caller's funded escrow balance to their chosen recipient.
     * @dev Leaves any unfunded remainder available for a later withdrawal.
     * @param pendingWithdrawals Per-hedger withdrawal escrow.
     * @param usdc Pool collateral token.
     * @param recipient Caller-selected payout recipient.
     * @custom:security Pool wrappers enforce caller authority and storage references.
     * @custom:validation Uses the pool's existing validation rules.
     * @custom:state-changes Reduces caller escrow by funded amount and transfers USDC.
     * @custom:events None.
     * @custom:errors Propagates accounting, validation and trusted integration errors.
     * @custom:reentrancy Invoked from the nonReentrant withdrawal wrapper.
     * @custom:access Linked library invoked by HedgerPool through delegatecall.
     * @custom:oracle No oracle lookup; prices, where present, are supplied by the caller.
     */
    function withdraw(
        mapping(address => uint256) storage pendingWithdrawals,
        IERC20 usdc,
        address recipient
    ) external {
        if (recipient == address(0)) revert CommonErrorLibrary.ZeroAddress();
        uint256 amount = pendingWithdrawals[msg.sender];
        if (amount == 0) revert CommonErrorLibrary.InvalidAmount();
        uint256 reserve = usdc.balanceOf(address(this));
        uint256 payout = amount > reserve ? reserve : amount;
        if (payout == 0) revert CommonErrorLibrary.InsufficientBalance();
        pendingWithdrawals[msg.sender] = amount - payout;
        usdc.safeTransfer(recipient, payout);
    }
}
