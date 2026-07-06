// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {HedgerVaultIntegrationTest} from "./HedgerVaultIntegration.t.sol";
import {HedgerPool} from "../src/core/HedgerPool.sol";

/// @notice Minimal fee sink that records routed fees (matches FeeCollector.collectFees selector).
contract RecordingFeeCollector {
    uint256 public totalCollected;
    uint256 public callCount;

    function collectFees(address token, uint256 amount, string calldata) external {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        totalCollected += amount;
        callCount++;
    }
}

/**
 * @title HedgerPoolFeeRoutingAndRewardsTest
 * @notice Regression tests for HedgerPool reward-clock initialization on position open and for
 *         routing entry/exit fees to the reward reserve / FeeCollector (only net collateral
 *         reaches the vault).
 */
contract HedgerPoolFeeRoutingAndRewardsTest is HedgerVaultIntegrationTest {
    RecordingFeeCollector internal recorder;

    function _approveHedger() private {
        vm.prank(hedger);
        usdc.approve(address(hedgerPool), type(uint256).max);
    }

    function _installRecorderAndFees(uint256 entryBps, uint256 exitBps) private {
        recorder = new RecordingFeeCollector();
        vm.prank(admin);
        hedgerPool.configureDependencies(
            HedgerPool.HedgerDependencyConfig({
                treasury: treasury,
                vault: address(vault),
                oracle: address(oracle),
                yieldShift: address(0x999),
                feeCollector: address(recorder)
            })
        );
        vm.prank(admin);
        hedgerPool.configureRiskAndFees(
            HedgerPool.HedgerRiskConfig({
                minMarginRatio: 500,
                maxLeverage: 20,
                minPositionHoldBlocks: 0,
                minMarginAmount: 1e6,
                eurInterestRate: 350,
                usdInterestRate: 450,
                entryFee: entryBps,
                exitFee: exitBps,
                marginFee: 0,
                rewardFeeSplit: 5e17
            })
        );
    }

    // ---- reward clock initialization ----

    /// @notice Opening a position initializes the reward clock so the first interval is not dropped.
    function test_RewardClockInitializedOnOpen() public {
        _approveHedger();
        assertEq(hedgerPool.hedgerLastRewardBlock(hedger), 0, "clock unset before opening a position");

        vm.prank(hedger);
        hedgerPool.enterHedgePosition(10_000e6, 5);

        assertGt(hedgerPool.hedgerLastRewardBlock(hedger), 0, "Reward clock initialized on open");
    }

    // (End-to-end first-interval accrual is covered by the self-contained HedgerPoolInterestRewardAccrualTest,
    //  which uses a realistic timestamp and an always-valid oracle so the legacy migration guard and
    //  oracle staleness do not interfere — neither is possible in this small-timestamp fixture.)

    // ---- entry/exit fee routing ----

    /// @notice A non-zero entry fee is routed to the reward reserve + FeeCollector, and only net
    ///         collateral reaches the vault (was: full gross credited as vault collateral).
    function test_EntryFeeRoutedToSinks() public {
        _approveHedger();
        _installRecorderAndFees(100, 0); // 100 bps entry fee

        uint256 amount = 10_000e6;
        uint256 expectedFee = amount * 100 / 10_000;          // 100e6
        uint256 expectedNet = amount - expectedFee;           // 9_900e6
        uint256 expectedReserve = expectedFee / 2;            // rewardFeeSplit = 50%
        uint256 expectedCollector = expectedFee - expectedReserve;

        uint256 availBefore = vault.getTotalUsdcAvailable();

        vm.prank(hedger);
        hedgerPool.enterHedgePosition(amount, 5);

        assertEq(vault.getTotalUsdcAvailable() - availBefore, expectedNet, "vault credited only net margin");
        assertEq(recorder.totalCollected(), expectedCollector, "FeeCollector received the collector share");
        assertEq(recorder.callCount(), 1, "FeeCollector called once on entry");
        assertEq(usdc.balanceOf(address(hedgerPool)), expectedReserve, "reserve share retained in HedgerPool");
    }

    /// @notice A non-zero exit fee is routed to the fee sinks instead of being left in the vault.
    function test_ExitFeeRoutedToSinks() public {
        _approveHedger();
        _installRecorderAndFees(0, 100); // 100 bps exit fee

        uint256 amount = 10_000e6;
        vm.prank(hedger);
        uint256 positionId = hedgerPool.enterHedgePosition(amount, 5);

        uint256 hedgerBefore = usdc.balanceOf(hedger);

        vm.prank(hedger);
        hedgerPool.exitHedgePosition(positionId);

        assertGt(recorder.totalCollected(), 0, "exit fee routed to FeeCollector");
        assertEq(recorder.callCount(), 1, "FeeCollector called once on exit");
        assertGt(usdc.balanceOf(hedger), hedgerBefore, "hedger received net payout");
    }
    /// @notice A hedger with an already-active position cannot open a second one
    ///         (would double-count totalMargin/totalExposure).
    function test_enterHedgePosition_reentersActive_reverts() public {
        _approveHedger();
        vm.prank(hedger);
        hedgerPool.enterHedgePosition(10_000e6, 5);

        // Second open while the first is active reverts before any USDC is pulled.
        vm.prank(hedger);
        vm.expectRevert();
        hedgerPool.enterHedgePosition(10_000e6, 5);
    }
}
