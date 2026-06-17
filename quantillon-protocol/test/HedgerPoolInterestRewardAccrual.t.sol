// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {HedgerPool} from "../src/core/HedgerPool.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";

contract RewardUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract RewardOracle {
    uint256 public price = 1.10e18;

    function getEurUsdPrice() external view returns (uint256, bool) {
        return (price, true);
    }
}

contract RewardYieldShift {
    function hedgerPendingYield(address) external pure returns (uint256) {
        return 0;
    }

    function claimHedgerYield(address) external pure returns (uint256) {
        return 0;
    }
}

contract RewardVault {
    address public userPool = address(0xBEEF);
    uint256 public totalMargin;

    function addHedgerDeposit(uint256 usdcAmount) external {
        totalMargin += usdcAmount;
    }

    function withdrawHedgerDeposit(address, uint256 usdcAmount) external {
        totalMargin -= usdcAmount;
    }

    function isProtocolCollateralized() external view returns (bool, uint256) {
        return (totalMargin > 0, totalMargin);
    }
}

/**
 * @title HedgerPoolInterestRewardAccrualTest
 * @notice Self-contained regression: the first claimHedgingRewards() after a position opens
 *         accrues the interest-differential interval instead of discarding it.
 * @dev Uses a realistic timestamp (so the reward clock is a real unix time, above the legacy
 *      block-number migration threshold) and an always-valid oracle. Mirrors the reporter PoC with
 *      the assertion inverted to the corrected behavior.
 */
contract HedgerPoolInterestRewardAccrualTest is Test {
    address private admin = address(0xA11CE);
    address private hedger = address(0xB0B);

    RewardUSDC private usdc;
    HedgerPool private hedgerPool;

    function setUp() public {
        vm.warp(1_700_000_000);

        usdc = new RewardUSDC();
        RewardOracle oracle = new RewardOracle();
        RewardYieldShift yieldShift = new RewardYieldShift();
        RewardVault vault = new RewardVault();

        TimeProvider timeProviderImpl = new TimeProvider();
        ERC1967Proxy timeProviderProxy = new ERC1967Proxy(
            address(timeProviderImpl),
            abi.encodeWithSelector(TimeProvider.initialize.selector, admin, admin, admin)
        );
        TimeProvider timeProvider = TimeProvider(address(timeProviderProxy));

        HedgerPool implementation = new HedgerPool(timeProvider);
        ERC1967Proxy poolProxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                HedgerPool.initialize.selector,
                admin,
                address(usdc),
                address(oracle),
                address(yieldShift),
                admin,
                admin,
                address(vault)
            )
        );
        hedgerPool = HedgerPool(address(poolProxy));

        vm.prank(admin);
        hedgerPool.setSingleHedger(hedger);

        usdc.mint(hedger, 100_000e6);
        vm.prank(hedger);
        usdc.approve(address(hedgerPool), type(uint256).max);
    }

    function test_FirstInterestRewardIntervalIsNotLost() public {
        uint256 margin = 10_000e6;
        uint256 leverage = 5;
        uint256 startTime = block.timestamp; // == position open time (set in setUp)

        vm.prank(hedger);
        hedgerPool.enterHedgePosition(margin, leverage);

        // The reward clock is initialized at open (was left at zero).
        assertGt(hedgerPool.hedgerLastRewardBlock(hedger), 0, "reward clock initialized on open");

        uint256 exposure = hedgerPool.totalExposure();
        uint256 expectedThirtyDayReward = exposure * 100 * 30 days / (10_000 * 365 days);
        assertGt(expectedThirtyDayReward, 0, "sanity: a positive reward is expected");

        // Use explicit absolute warps so each claim sees a distinct 30-day interval.
        vm.warp(startTime + 30 days);
        vm.prank(hedger);
        (uint256 firstInterestReward,,) = hedgerPool.claimHedgingRewards();

        // The whole first interval is now accrued rather than discarded.
        assertApproxEqAbs(
            firstInterestReward,
            expectedThirtyDayReward,
            1,
            "First interval accrues instead of only starting the clock"
        );
        assertEq(hedgerPool.pendingRewardWithdrawals(hedger), firstInterestReward, "reward queued for withdrawal");

        // And a subsequent interval still accrues (the first claim advanced the clock correctly,
        // so later claims keep accruing rather than being permanently broken by the fix).
        vm.warp(startTime + 60 days);
        vm.prank(hedger);
        (uint256 secondInterestReward,,) = hedgerPool.claimHedgingRewards();
        assertGt(secondInterestReward, 0, "subsequent interval still accrues after the first claim");
    }
}
