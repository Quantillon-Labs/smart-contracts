// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {SlippageStorage} from "../src/oracle/SlippageStorage.sol";
import {ISlippageStorage} from "../src/interfaces/ISlippageStorage.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title SlippageStorageTest
 * @notice Comprehensive unit tests for the SlippageStorage contract
 *
 * @dev Covers:
 *      - Initialization (roles, config, zero-address reverts, double-init)
 *      - ACL on updateSlippage (writer, non-writer, paused)
 *      - Rate limit (first update, within interval, after interval, deviation bypass)
 *      - Config functions (MANAGER_ROLE set/revert)
 *      - Pause / unpause (EMERGENCY_ROLE)
 *      - View functions (getSlippage, getSlippageAge)
 *      - Recovery (recoverETH, recoverToken)
 *      - UUPS upgrade
 *
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract SlippageStorageTest is Test {

    // ============ Test Actors ============

    address admin    = makeAddr("admin");
    address writer   = makeAddr("writer");
    address treasury = makeAddr("treasury");
    address outsider = makeAddr("outsider");

    // ============ Contracts ============

    SlippageStorage public impl;
    SlippageStorage public store;
    TimeProvider public timeProvider;

    // ============ Default Config ============

    uint48 constant MIN_INTERVAL = 60;         // 60 seconds
    uint16 constant DEVIATION_THRESHOLD = 50;  // 50 bps

    // ============ Sample Data ============

    uint128 constant MID_PRICE  = 1.10e18;  // 1.10 USD/EUR
    uint128 constant DEPTH_EUR  = 500_000e18;
    uint16  constant WORST_BPS  = 25;
    uint16  constant SPREAD_BPS = 3;

    /// @dev Default per-bucket bps: [10k, 50k, 100k, 250k, 1M]
    function _defaultBuckets() internal pure returns (uint16[5] memory) {
        return [uint16(5), uint16(10), uint16(15), uint16(20), uint16(25)];
    }

    // ============ Setup ============

    function setUp() public {
        timeProvider = new TimeProvider();
        impl = new SlippageStorage(timeProvider);
        bytes memory initData = abi.encodeCall(
            SlippageStorage.initialize,
            (admin, writer, MIN_INTERVAL, DEVIATION_THRESHOLD, treasury)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        store = SlippageStorage(payable(address(proxy)));
    }

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    function test_initialize_setsAdminAndWriterAndConfig() public view {
        assertTrue(store.hasRole(store.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(store.hasRole(store.WRITER_ROLE(), writer));
        assertTrue(store.hasRole(store.MANAGER_ROLE(), admin));
        assertTrue(store.hasRole(store.EMERGENCY_ROLE(), admin));
        assertTrue(store.hasRole(store.UPGRADER_ROLE(), admin));
        assertEq(store.minUpdateInterval(), MIN_INTERVAL);
        assertEq(store.deviationThresholdBps(), DEVIATION_THRESHOLD);
    }

    function test_initialize_revertsIfAdminZero() public {
        SlippageStorage newImpl = new SlippageStorage(timeProvider);
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeCall(SlippageStorage.initialize, (address(0), writer, MIN_INTERVAL, DEVIATION_THRESHOLD, treasury))
        );
    }

    function test_initialize_revertsIfWriterZero() public {
        SlippageStorage newImpl = new SlippageStorage(timeProvider);
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeCall(SlippageStorage.initialize, (admin, address(0), MIN_INTERVAL, DEVIATION_THRESHOLD, treasury))
        );
    }

    function test_initialize_revertsIfTreasuryZero() public {
        SlippageStorage newImpl = new SlippageStorage(timeProvider);
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeCall(SlippageStorage.initialize, (admin, writer, MIN_INTERVAL, DEVIATION_THRESHOLD, address(0)))
        );
    }

    function test_initialize_revertsIfCalledTwice() public {
        vm.expectRevert();
        store.initialize(admin, writer, MIN_INTERVAL, DEVIATION_THRESHOLD, treasury);
    }

    function test_initialize_revertsIfIntervalTooHigh() public {
        SlippageStorage newImpl = new SlippageStorage(timeProvider);
        vm.expectRevert(CommonErrorLibrary.ConfigValueTooHigh.selector);
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeCall(SlippageStorage.initialize, (admin, writer, 7200, DEVIATION_THRESHOLD, treasury))
        );
    }

    function test_initialize_revertsIfDeviationTooHigh() public {
        SlippageStorage newImpl = new SlippageStorage(timeProvider);
        vm.expectRevert(CommonErrorLibrary.ConfigValueTooHigh.selector);
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeCall(SlippageStorage.initialize, (admin, writer, MIN_INTERVAL, 600, treasury))
        );
    }

    // =========================================================================
    // ACL — updateSlippage
    // =========================================================================

    function test_updateSlippage_succeedsAsWriter() public {
        vm.prank(writer);
        vm.expectEmit(true, true, true, true);
        // forge-lint: disable-next-line(unsafe-typecast)
        emit ISlippageStorage.SlippageUpdated(MID_PRICE, WORST_BPS, SPREAD_BPS, DEPTH_EUR, uint48(block.timestamp));
        store.updateSlippage(MID_PRICE, DEPTH_EUR, WORST_BPS, SPREAD_BPS, _defaultBuckets());

        ISlippageStorage.SlippageSnapshot memory s = store.getSlippage();
        assertEq(s.midPrice, MID_PRICE);
        assertEq(s.depthEur, DEPTH_EUR);
        assertEq(s.worstCaseBps, WORST_BPS);
        assertEq(s.spreadBps, SPREAD_BPS);
        assertEq(s.timestamp, uint48(block.timestamp));
        assertEq(s.blockNumber, uint48(block.number));
    }

    function test_updateSlippage_revertsIfNotWriter() public {
        vm.prank(outsider);
        vm.expectRevert();
        store.updateSlippage(MID_PRICE, DEPTH_EUR, WORST_BPS, SPREAD_BPS, _defaultBuckets());
    }

    function test_updateSlippage_revertsIfPaused() public {
        vm.prank(admin);
        store.pause();

        vm.prank(writer);
        vm.expectRevert();
        store.updateSlippage(MID_PRICE, DEPTH_EUR, WORST_BPS, SPREAD_BPS, _defaultBuckets());
    }

    // =========================================================================
    // RATE LIMIT (time-based)
    // =========================================================================

    function test_updateSlippage_allowsFirstUpdate() public {
        vm.prank(writer);
        store.updateSlippage(MID_PRICE, DEPTH_EUR, WORST_BPS, SPREAD_BPS, _defaultBuckets());
        assertEq(store.getSlippage().worstCaseBps, WORST_BPS);
    }

    function test_updateSlippage_revertsIfWithinMinIntervalSameBps() public {
        vm.prank(writer);
        store.updateSlippage(MID_PRICE, DEPTH_EUR, WORST_BPS, SPREAD_BPS, _defaultBuckets());

        // 30s later — within the 60s interval, same bps
        vm.warp(block.timestamp + 30);
        vm.prank(writer);
        vm.expectRevert(CommonErrorLibrary.RateLimitTooHigh.selector);
        store.updateSlippage(MID_PRICE, DEPTH_EUR, WORST_BPS, SPREAD_BPS, _defaultBuckets());
    }

    function test_updateSlippage_succeedsAfterMinInterval() public {
        vm.prank(writer);
        store.updateSlippage(MID_PRICE, DEPTH_EUR, WORST_BPS, SPREAD_BPS, _defaultBuckets());

        // 61s later — past the 60s interval
        vm.warp(block.timestamp + 61);
        vm.prank(writer);
        store.updateSlippage(MID_PRICE, DEPTH_EUR, WORST_BPS, SPREAD_BPS, _defaultBuckets());
        assertEq(store.getSlippage().worstCaseBps, WORST_BPS);
    }

    function test_updateSlippage_succeedsWithinIntervalIfDeviationAboveThreshold() public {
        vm.prank(writer);
        store.updateSlippage(MID_PRICE, DEPTH_EUR, WORST_BPS, SPREAD_BPS, _defaultBuckets());

        // 10s later — within interval, but big move (25 -> 76 = 51 bps diff > 50 threshold)
        vm.warp(block.timestamp + 10);
        vm.prank(writer);
        uint16 bigBps = WORST_BPS + DEVIATION_THRESHOLD + 1; // 76
        store.updateSlippage(MID_PRICE, DEPTH_EUR, bigBps, SPREAD_BPS, _defaultBuckets());
        assertEq(store.getSlippage().worstCaseBps, bigBps);
    }

    function test_updateSlippage_revertsWithinIntervalIfDeviationBelowThreshold() public {
        vm.prank(writer);
        store.updateSlippage(MID_PRICE, DEPTH_EUR, WORST_BPS, SPREAD_BPS, _defaultBuckets());

        // 10s later — within interval, small move (25 -> 74 = 49 bps diff <= 50 threshold)
        vm.warp(block.timestamp + 10);
        vm.prank(writer);
        uint16 smallBps = WORST_BPS + DEVIATION_THRESHOLD; // 75, diff = 50 = threshold, not above
        vm.expectRevert(CommonErrorLibrary.RateLimitTooHigh.selector);
        store.updateSlippage(MID_PRICE, DEPTH_EUR, smallBps, SPREAD_BPS, _defaultBuckets());
    }

    function test_updateSlippage_deviationBypassWorksDownward() public {
        // Start at 100 bps
        vm.prank(writer);
        store.updateSlippage(MID_PRICE, DEPTH_EUR, 100, SPREAD_BPS, _defaultBuckets());

        // 5s later — drop from 100 to 40, diff = 60 > 50 threshold
        vm.warp(block.timestamp + 5);
        vm.prank(writer);
        store.updateSlippage(MID_PRICE, DEPTH_EUR, 40, SPREAD_BPS, _defaultBuckets());
        assertEq(store.getSlippage().worstCaseBps, 40);
    }

    // =========================================================================
    // CONFIG (MANAGER_ROLE)
    // =========================================================================

    function test_setMinUpdateInterval_succeedsAsManager() public {
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit ISlippageStorage.ConfigUpdated("minUpdateInterval", uint256(MIN_INTERVAL), 120);
        store.setMinUpdateInterval(120);
        assertEq(store.minUpdateInterval(), 120);
    }

    function test_setMinUpdateInterval_revertsIfNotManager() public {
        vm.prank(outsider);
        vm.expectRevert();
        store.setMinUpdateInterval(120);
    }

    function test_setMinUpdateInterval_revertsIfTooHigh() public {
        vm.prank(admin);
        vm.expectRevert(CommonErrorLibrary.ConfigValueTooHigh.selector);
        store.setMinUpdateInterval(7200);
    }

    function test_setDeviationThreshold_succeedsAsManager() public {
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit ISlippageStorage.ConfigUpdated("deviationThresholdBps", uint256(DEVIATION_THRESHOLD), 100);
        store.setDeviationThreshold(100);
        assertEq(store.deviationThresholdBps(), 100);
    }

    function test_setDeviationThreshold_revertsIfNotManager() public {
        vm.prank(outsider);
        vm.expectRevert();
        store.setDeviationThreshold(100);
    }

    function test_setDeviationThreshold_revertsIfTooHigh() public {
        vm.prank(admin);
        vm.expectRevert(CommonErrorLibrary.ConfigValueTooHigh.selector);
        store.setDeviationThreshold(600);
    }

    // =========================================================================
    // PAUSE (EMERGENCY_ROLE)
    // =========================================================================

    function test_pause_succeedsAsEmergency() public {
        vm.prank(admin);
        store.pause();

        vm.prank(writer);
        vm.expectRevert();
        store.updateSlippage(MID_PRICE, DEPTH_EUR, WORST_BPS, SPREAD_BPS, _defaultBuckets());
    }

    function test_unpause_succeedsAsEmergency() public {
        vm.prank(admin);
        store.pause();

        vm.prank(admin);
        store.unpause();

        vm.prank(writer);
        store.updateSlippage(MID_PRICE, DEPTH_EUR, WORST_BPS, SPREAD_BPS, _defaultBuckets());
        assertEq(store.getSlippage().worstCaseBps, WORST_BPS);
    }

    function test_pause_revertsIfNotEmergency() public {
        vm.prank(outsider);
        vm.expectRevert();
        store.pause();
    }

    // =========================================================================
    // VIEW FUNCTIONS
    // =========================================================================

    function test_getSlippage_returnsCurrentSnapshot() public {
        vm.prank(writer);
        store.updateSlippage(MID_PRICE, DEPTH_EUR, WORST_BPS, SPREAD_BPS, _defaultBuckets());

        ISlippageStorage.SlippageSnapshot memory s = store.getSlippage();
        assertEq(s.midPrice, MID_PRICE);
        assertEq(s.depthEur, DEPTH_EUR);
        assertEq(s.worstCaseBps, WORST_BPS);
        assertEq(s.spreadBps, SPREAD_BPS);
    }

    function test_getSlippageAge_returnsZeroBeforeFirstUpdate() public view {
        assertEq(store.getSlippageAge(), 0);
    }

    function test_getSlippageAge_returnsCorrectAgeAfterUpdate() public {
        vm.prank(writer);
        store.updateSlippage(MID_PRICE, DEPTH_EUR, WORST_BPS, SPREAD_BPS, _defaultBuckets());

        vm.warp(block.timestamp + 120);
        assertEq(store.getSlippageAge(), 120);
    }

    // =========================================================================
    // RECOVERY
    // =========================================================================

    function test_recoverETH_succeedsAsAdmin() public {
        vm.deal(address(store), 1 ether);
        uint256 balBefore = treasury.balance;

        vm.prank(admin);
        store.recoverETH();

        assertEq(treasury.balance, balBefore + 1 ether);
    }

    function test_recoverETH_revertsIfNotAdmin() public {
        vm.deal(address(store), 1 ether);
        vm.prank(outsider);
        vm.expectRevert();
        store.recoverETH();
    }

    function test_recoverToken_succeedsAsAdmin() public {
        MockERC20 token = new MockERC20("Mock", "MCK");
        token.mint(address(store), 1000e18);

        vm.prank(admin);
        store.recoverToken(address(token), 1000e18);

        assertEq(token.balanceOf(treasury), 1000e18);
    }

    function test_recoverToken_revertsIfNotAdmin() public {
        MockERC20 token = new MockERC20("Mock", "MCK");
        token.mint(address(store), 1000e18);

        vm.prank(outsider);
        vm.expectRevert();
        store.recoverToken(address(token), 1000e18);
    }

    // =========================================================================
    // TREASURY UPDATE
    // =========================================================================

    function test_updateTreasury_succeedsAsAdmin() public {
        address newTreasury = makeAddr("newTreasury");
        vm.prank(admin);
        store.updateTreasury(newTreasury);
        assertEq(store.treasury(), newTreasury);
    }

    function test_updateTreasury_revertsIfZero() public {
        vm.prank(admin);
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        store.updateTreasury(address(0));
    }

    // =========================================================================
    // UPGRADE
    // =========================================================================

    function test_upgrade_succeedsAsUpgrader() public {
        // Write some data first
        vm.prank(writer);
        store.updateSlippage(MID_PRICE, DEPTH_EUR, WORST_BPS, SPREAD_BPS, _defaultBuckets());

        // Deploy a new implementation
        SlippageStorage newImpl = new SlippageStorage(timeProvider);

        vm.prank(admin);
        store.upgradeToAndCall(address(newImpl), "");

        // State is preserved after upgrade (including bucket bps)
        ISlippageStorage.SlippageSnapshot memory s = store.getSlippage();
        assertEq(s.midPrice, MID_PRICE);
        assertEq(s.worstCaseBps, WORST_BPS);
        assertEq(s.bps10k, 5);
        assertEq(s.bps1M, 25);
    }

    function test_upgrade_revertsIfNotUpgrader() public {
        SlippageStorage newImpl = new SlippageStorage(timeProvider);

        vm.prank(outsider);
        vm.expectRevert();
        store.upgradeToAndCall(address(newImpl), "");
    }

    // =========================================================================
    // BUCKET BPS
    // =========================================================================

    function test_updateSlippage_storesAllBucketBps() public {
        uint16[5] memory buckets = [uint16(3), uint16(7), uint16(12), uint16(18), uint16(30)];
        vm.prank(writer);
        store.updateSlippage(MID_PRICE, DEPTH_EUR, WORST_BPS, SPREAD_BPS, buckets);

        ISlippageStorage.SlippageSnapshot memory s = store.getSlippage();
        assertEq(s.bps10k,  3);
        assertEq(s.bps50k,  7);
        assertEq(s.bps100k, 12);
        assertEq(s.bps250k, 18);
        assertEq(s.bps1M,   30);
    }

    function test_getBucketBps_returnsCanonicalOrder() public {
        uint16[5] memory buckets = [uint16(3), uint16(7), uint16(12), uint16(18), uint16(30)];
        vm.prank(writer);
        store.updateSlippage(MID_PRICE, DEPTH_EUR, WORST_BPS, SPREAD_BPS, buckets);

        uint16[5] memory result = store.getBucketBps();
        assertEq(result[0], 3,  "10k bucket");
        assertEq(result[1], 7,  "50k bucket");
        assertEq(result[2], 12, "100k bucket");
        assertEq(result[3], 18, "250k bucket");
        assertEq(result[4], 30, "1M bucket");
    }

    function test_getBucketBps_returnsZerosBeforeFirstUpdate() public view {
        uint16[5] memory result = store.getBucketBps();
        for (uint256 i = 0; i < 5; i++) {
            assertEq(result[i], 0);
        }
    }

    function test_updateSlippage_bucketBpsOverwrittenOnSecondUpdate() public {
        uint16[5] memory first  = [uint16(1), uint16(2), uint16(3), uint16(4), uint16(5)];
        uint16[5] memory second = [uint16(10), uint16(20), uint16(30), uint16(40), uint16(50)];

        vm.prank(writer);
        store.updateSlippage(MID_PRICE, DEPTH_EUR, WORST_BPS, SPREAD_BPS, first);

        vm.warp(block.timestamp + 61);
        vm.prank(writer);
        store.updateSlippage(MID_PRICE, DEPTH_EUR, WORST_BPS, SPREAD_BPS, second);

        uint16[5] memory result = store.getBucketBps();
        assertEq(result[0], 10);
        assertEq(result[4], 50);
    }

    function test_rateLimitStillUsesWorstCaseBpsNotBuckets() public {
        // Rate limit uses worstCaseBps, not individual bucket values.
        // Even if buckets change dramatically, rate limit only checks worstCaseBps.
        uint16[5] memory low  = [uint16(1), uint16(2), uint16(3), uint16(4), uint16(5)];
        uint16[5] memory high = [uint16(100), uint16(200), uint16(300), uint16(400), uint16(500)];

        vm.prank(writer);
        store.updateSlippage(MID_PRICE, DEPTH_EUR, WORST_BPS, SPREAD_BPS, low);

        // Within interval, same worstCaseBps but different buckets — should still revert
        vm.warp(block.timestamp + 10);
        vm.prank(writer);
        vm.expectRevert(CommonErrorLibrary.RateLimitTooHigh.selector);
        store.updateSlippage(MID_PRICE, DEPTH_EUR, WORST_BPS, SPREAD_BPS, high);
    }
}

// ============ Minimal ERC20 mock for recovery tests ============

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
