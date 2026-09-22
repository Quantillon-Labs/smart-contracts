// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {FeeCollector} from "../core/FeeCollector.sol";
import {HedgerPool} from "../core/HedgerPool.sol";
import {HedgerPoolRedeemMathLibrary} from "./HedgerPoolRedeemMathLibrary.sol";
import {HedgerPoolLogicLibrary} from "./HedgerPoolLogicLibrary.sol";
import {HedgerPoolValidationLibrary} from "./HedgerPoolValidationLibrary.sol";
import {HedgerPoolErrorLibrary} from "./HedgerPoolErrorLibrary.sol";
import {IQuantillonVault} from "../interfaces/IQuantillonVault.sol";
import {CommonErrorLibrary} from "./CommonErrorLibrary.sol";
import {IYieldShift} from "../interfaces/IYieldShift.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title HedgerPoolAccountingLibrary
/// @notice Existing pool accounting extracted to keep HedgerPool deployable.
/// @dev Delegatecalled with explicit storage references; correction replay protection uses a dedicated hashed namespace.
library HedgerPoolAccountingLibrary {
    using SafeERC20 for IERC20;

    bytes32 private constant LEGACY_CORRECTION_SLOT = keccak256("quantillon.storage.LegacyMarginCorrection.20260701");
    bytes32 private constant LEGACY_CORRECTION_ID = keccak256("base:48054036:hedger-profit:388448");
    address private constant LEGACY_POOL = 0xff5D7cE5c7671B2EA805Ee752B4f8eC9Ecf2975A;
    address private constant LEGACY_SAFE = 0x1d7fF432a93d0085Fb69474c7E567f859829e6cd;
    uint256 private constant LEGACY_CREDIT = 388448;

    error LegacyCorrectionUnauthorized();
    error LegacyCorrectionStateMismatch();
    error LegacyCorrectionAlreadyApplied();
    event LegacyMarginCorrected(bytes32 indexed correctionId, address indexed hedger, uint256 amount);
    event SingleHedgerRotationApplied(address indexed previousHedger, address indexed newHedger);
    event RewardReserveFunded(address indexed funder, uint256 amount);

    /**
     * @notice Routes collected fees between the reward reserve and collector.
     * @dev Reserve amounts remain in the calling pool.
     * @param usdc Collateral token.
     * @param collector Fee collector address.
     * @param split Reserve fraction scaled by 1e18.
     * @param funder Account credited with funding the reserve.
     * @param fee Collected fee in USDC units.
     * @param sourceType Collector accounting category.
     * @custom:security Caller validates the configured split and recipient.
     * @custom:validation A zero fee is a no-op.
     * @custom:state-changes Transfers the collector portion and updates allowance.
     * @custom:events RewardReserveFunded and collector events.
     * @custom:errors Propagates token and collector failures.
     * @custom:reentrancy Calling pool holds its reentrancy guard.
     * @custom:access Linked library.
     * @custom:oracle None.
     */
    function routeFee(IERC20 usdc, address collector, uint256 split, address funder, uint256 fee, string memory sourceType) external {
        if (fee == 0) return;
        uint256 reserveShare = Math.mulDiv(fee, split, 1e18);
        uint256 collectorShare = fee - reserveShare;
        if (reserveShare != 0) emit RewardReserveFunded(funder, reserveShare);
        if (collectorShare != 0 && collector != address(0)) {
            usdc.safeIncreaseAllowance(collector, collectorShare);
            FeeCollector(collector).collectFees(address(usdc), collectorShare, sourceType);
        }
    }

    /**
     * @notice Assigns the configured owner with the existing inactive-position restriction.
     * @dev Extracted unchanged to preserve EIP-170 headroom for the correction entry point.
     * @param position Fixed position one, used only to read its active flag.
     * @param next Requested owner.
     * @return Configured owner after assignment.
     * @custom:security Helper enforces the existing governance role.
     * @custom:validation Nonzero recipient and no active position when replacing an owner.
     * @custom:state-changes None; wrapper stores returned owner.
     * @custom:events SingleHedgerRotationApplied.
     * @custom:errors InvalidAddress, HedgerHasActivePosition.
     * @custom:reentrancy No external calls.
     * @custom:access Linked library only.
     * @custom:oracle No oracle dependency.
     */
    function assignSingleHedger(HedgerPool.HedgePosition storage position, address next) external returns (address) {
        HedgerPool pool = HedgerPool(address(this));
        if (!pool.hasRole(keccak256("GOVERNANCE_ROLE"), msg.sender)) revert CommonErrorLibrary.NotAuthorized();
        address current = pool.singleHedger();
        if (next == address(0)) revert CommonErrorLibrary.InvalidAddress();
        if (current != address(0) && position.isActive) revert HedgerPoolErrorLibrary.HedgerHasActivePosition();
        emit SingleHedgerRotationApplied(current, next);
        return next;
    }

    /**
     * @notice Reclassifies exactly the verified historical residue as current Safe margin once.
     * @dev No deposit, withdrawal, mint, cost-basis change or realized-PnL adjustment occurs.
     *      Exact surplus and opening-block checks reject drift or reuse for another position.
     * @param position The pool's fixed active position one.
     * @return nextTotalMargin Global margin after correction.
     * @return nextTotalExposure Global nominal exposure after correction.
     * @custom:security Fixed chain/pool/owner/position and governance, pause and replay guards.
     * @custom:validation Verifies global totals, supply/backing dust and exact existing surplus.
     * @custom:state-changes Updates margin, position size and namespaced one-time marker.
     * @custom:events LegacyMarginCorrected.
     * @custom:errors LegacyCorrectionUnauthorized, LegacyCorrectionStateMismatch, LegacyCorrectionAlreadyApplied.
     * @custom:reentrancy Pool wrapper is nonReentrant; external calls are static reads.
     * @custom:access Linked library invoked by the fixed Base pool through delegatecall.
     * @custom:oracle Independent of oracle price and cached valuation.
     */
    function correctLegacyMargin(HedgerPool.HedgePosition storage position)
        external returns (uint256 nextTotalMargin, uint256 nextTotalExposure)
    {
        HedgerPool pool = HedgerPool(address(this));
        if (!pool.hasRole(keccak256("GOVERNANCE_ROLE"), msg.sender)) revert LegacyCorrectionUnauthorized();
        bytes32 slot = LEGACY_CORRECTION_SLOT;
        uint256 applied;
        assembly ("memory-safe") { applied := sload(slot) }
        if (applied != 0) revert LegacyCorrectionAlreadyApplied();
        if (block.chainid != 8453 || address(this) != LEGACY_POOL || !pool.paused() || !pool.costBasisAccountingInitialized()
            || pool.singleHedger() != LEGACY_SAFE || position.hedger != LEGACY_SAFE
            || !position.isActive || position.openBlock != 51160486
            || pool.totalMargin() != uint256(position.margin)
            || pool.totalExposure() != uint256(position.positionSize)
            || pool.totalFilledExposure() != uint256(position.filledVolume)
            || uint256(position.positionSize) != uint256(position.margin) * position.leverage) {
            revert LegacyCorrectionStateMismatch();
        }
        IQuantillonVault vault = pool.vault();
        uint256 supply = IERC20(vault.qeuro()).totalSupply();
        if (supply < position.qeuroBacked || supply - position.qeuroBacked > 1e12
            || vault.getTotalUsdcAvailable() != uint256(position.margin) + position.filledVolume + LEGACY_CREDIT) {
            revert LegacyCorrectionStateMismatch();
        }
        nextTotalMargin = uint256(position.margin) + LEGACY_CREDIT;
        nextTotalExposure = nextTotalMargin * position.leverage;
        if (nextTotalMargin > type(uint96).max || nextTotalExposure > type(uint96).max) {
            revert LegacyCorrectionStateMismatch();
        }
        assembly ("memory-safe") { sstore(slot, 1) }
        position.margin = uint96(nextTotalMargin);
        position.positionSize = uint96(nextTotalExposure);
        emit LegacyMarginCorrected(LEGACY_CORRECTION_ID, LEGACY_SAFE, LEGACY_CREDIT);
    }

    /**
     * @notice Preserves the pool's existing restriction on closing while users remain exposed.
     * @dev Extracted unchanged; bounded QEURO dust is treated as an empty supply.
     * @param vault Configured vault.
     * @param positionMargin Closing position's recorded margin.
     * @custom:security Read-only closure guard.
     * @custom:validation Requires sufficient remaining hedger margin when QEURO is outstanding.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors PositionClosureRestricted.
     * @custom:reentrancy External static reads only.
     * @custom:access Linked library invoked by HedgerPool.
     * @custom:oracle No price dependency.
     */
    function validateClosure(IQuantillonVault vault, uint256 positionMargin) external view {
        if (address(vault) == address(0)) return;
        if (vault.totalMinted() <= 1e12) return;
        (bool isCollateralized, uint256 reportedMargin) = vault.isProtocolCollateralized();
        if (!isCollateralized || reportedMargin <= positionMargin) revert HedgerPoolErrorLibrary.PositionClosureRestricted();
    }

    /**
     * @notice Validates and applies the existing risk and fee configuration.
     * @dev Scalar settings outside CoreParams remain assigned by the pool.
     * @param params Pool core parameters in storage.
     * @param cfg Requested complete risk and fee configuration.
     * @param position Active position used to bound the margin-ratio setting.
     * @custom:security Pool wrappers enforce caller authority and storage references.
     * @custom:validation Uses the pool's existing validation rules.
     * @custom:state-changes Updates only the explicitly supplied accounting storage.
     * @custom:events None.
     * @custom:errors Propagates accounting, validation and trusted integration errors.
     * @custom:reentrancy State-changing pool wrappers are nonReentrant except governance configuration.
     * @custom:access Linked library invoked by HedgerPool through delegatecall.
     * @custom:oracle No oracle lookup; prices, where present, are supplied by the caller.
     */
    function configure(HedgerPool.CoreParams storage params, HedgerPool.HedgerRiskConfig calldata cfg, HedgerPool.HedgePosition storage position) external {
        if (position.isActive && (position.leverage == 0 || cfg.minMarginRatio > 10_000 / position.leverage)) {
            revert CommonErrorLibrary.ConfigValueTooHigh();
        }
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
    function version() external pure returns (string memory) { return "1.3.0"; }

    /**
     * @notice Books interest earned up to the current exposure change.
     * @dev Checkpointing before every exposure mutation prevents a later, larger
     *      exposure from being applied retroactively to an earlier accrual period.
     * @param rewardState Hedger reward state.
     * @param rewardTimes Per-hedger accrual clocks.
     * @param params Pool interest-rate configuration.
     * @param totalExposure Exposure that was active during the elapsed period.
     * @param currentTime Canonical protocol time.
     * @param maxRewardPeriod Maximum accrual duration.
     * @param hedger Hedger whose clock is being checkpointed.
     * @return pendingRewards Updated pending interest reward.
     * @custom:security Uses only explicitly supplied storage and accounting inputs.
     * @custom:validation Rejects reward overflow through the shared error library.
     * @custom:state-changes Updates the hedger's pending reward and accrual clock.
     * @custom:events None.
     * @custom:errors RewardOverflow on uint128 overflow.
     * @custom:reentrancy No external calls.
     * @custom:access Linked library invoked by HedgerPool.
     * @custom:oracle No oracle dependency.
     */
    function checkpoint(
        HedgerPool.HedgerRewardState storage rewardState,
        mapping(address => uint256) storage rewardTimes,
        HedgerPool.CoreParams storage params,
        uint256 totalExposure,
        uint256 currentTime,
        uint256 maxRewardPeriod,
        address hedger
    ) external returns (uint256 pendingRewards) {
        uint256 lastRewardTime = rewardTimes[hedger];
        if (lastRewardTime > 0 && lastRewardTime < 1_000_000_000) lastRewardTime = currentTime;
        (uint256 pending, uint256 last) = HedgerPoolLogicLibrary.calculateRewardUpdate(
            totalExposure, params.eurInterestRate, params.usdInterestRate,
            lastRewardTime, currentTime, maxRewardPeriod, uint256(rewardState.pendingRewards)
        );
        if (pending > type(uint128).max) revert HedgerPoolErrorLibrary.RewardOverflow();
        rewardState.pendingRewards = uint128(pending);
        rewardTimes[hedger] = last;
        pendingRewards = pending;
    }

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

    /**
     * @notice Applies realized profit or loss to margin and notional exposure.
     * @dev Keeps aggregate exposure aligned with the resulting position size.
     * @param pos Position to update.
     * @param totalMargin Aggregate margin before the transition.
     * @param totalExposure Aggregate exposure before the transition.
     * @param realizedDelta Realized USDC profit or loss.
     * @return nextMargin Aggregate margin after settlement.
     * @return nextExposure Aggregate exposure after settlement.
     * @custom:security Caller checkpoints rewards before changing exposure.
     * @custom:validation Shared math validates position bounds.
     * @custom:state-changes Updates position margin and size.
     * @custom:events None.
     * @custom:errors Propagates checked arithmetic errors.
     * @custom:reentrancy No external state-changing calls.
     * @custom:access Linked library.
     * @custom:oracle Caller supplies settled profit or loss.
     */
    function applyMarginTransition(
        HedgerPool.HedgePosition storage pos, uint256 totalMargin, uint256 totalExposure, int256 realizedDelta
    ) external returns (uint256 nextMargin, uint256 nextExposure) {
        uint256 oldPositionSize = uint256(pos.positionSize);
        HedgerPoolRedeemMathLibrary.MarginTransition memory transition = HedgerPoolRedeemMathLibrary.computeMarginTransition(
            totalMargin,
            uint256(pos.margin),
            uint256(pos.leverage),
            realizedDelta
        );

        nextMargin = transition.totalMarginAfter;
        // forge-lint: disable-next-line(unsafe-typecast)
        pos.margin = uint96(transition.nextMargin);
        // forge-lint: disable-next-line(unsafe-typecast)
        pos.positionSize = uint96(transition.nextPositionSize);

        if (transition.nextPositionSize >= oldPositionSize) {
            nextExposure = totalExposure + transition.nextPositionSize - oldPositionSize;
        } else {
            uint256 exposureDrop = oldPositionSize - transition.nextPositionSize;
            nextExposure = totalExposure - (exposureDrop > totalExposure ? totalExposure : exposureDrop);
        }
    }
}
