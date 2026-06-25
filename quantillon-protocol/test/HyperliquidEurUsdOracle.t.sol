// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {HyperliquidEurUsdOracle} from "../src/oracle/HyperliquidEurUsdOracle.sol";
import {IOracle} from "../src/interfaces/IOracle.sol";
import {ISlippageStorage} from "../src/interfaces/ISlippageStorage.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @notice Minimal SlippageStorage double exposing only getSlippageBySource.
contract MockSlippageStorage {
    uint128 public mid;
    uint48 public ts;
    bool public shouldRevert;

    function setMid(uint128 _mid, uint48 _ts) external {
        mid = _mid;
        ts = _ts;
    }

    function setShouldRevert(bool r) external {
        shouldRevert = r;
    }

    function getSlippageBySource(uint8) external view returns (ISlippageStorage.SlippageSnapshot memory snap) {
        if (shouldRevert) revert("slippage revert");
        snap.midPrice = mid;
        snap.timestamp = ts;
    }
}

/// @notice Minimal IOracle double used as the USDC/USD source.
contract MockUsdcOracle is IOracle {
    uint256 public price = 1e18;
    bool public valid = true;
    bool public shouldRevert;

    function setUsdc(uint256 p, bool v) external {
        price = p;
        valid = v;
    }

    function setShouldRevert(bool r) external {
        shouldRevert = r;
    }

    function getEurUsdPrice() external pure returns (uint256, bool) {
        return (0, false);
    }

    function getUsdcUsdPrice() external view returns (uint256, bool) {
        if (shouldRevert) revert("usdc revert");
        return (price, valid);
    }

    function getOracleHealth() external pure returns (bool, bool, bool) {
        return (true, true, true);
    }

    function getEurUsdDetails() external pure returns (uint256, uint256, uint256, bool, bool) {
        return (0, 0, 0, false, true);
    }

    function getOracleConfig() external pure returns (uint256, uint256, uint256, uint256, bool) {
        return (0, 0, 0, 0, false);
    }

    function getPriceFeedAddresses() external pure returns (address, address, uint8, uint8) {
        return (address(0), address(0), 18, 18);
    }

    function checkPriceFeedConnectivity() external pure returns (bool, bool, uint80, uint80) {
        return (true, true, 0, 0);
    }
}

/// @notice Consumer that reverts when the price is invalid, mirroring the vault's mint/redeem gate.
contract HLGate {
    error InvalidOraclePrice();

    function requireLivePrice(HyperliquidEurUsdOracle oracle) external returns (uint256) {
        (uint256 price, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) revert InvalidOraclePrice();
        return price;
    }
}

/**
 * @title HyperliquidEurUsdOracleTest
 * @notice Test suite for the Hyperliquid EUR/USD oracle adapter.
 */
contract HyperliquidEurUsdOracleTest is Test {
    HyperliquidEurUsdOracle public oracle;
    HyperliquidEurUsdOracle public implementation;
    TimeProvider public timeProvider;

    MockSlippageStorage public slippage;
    MockUsdcOracle public usdc;
    HLGate public gate;

    address public admin = address(0x1);
    address public treasury = address(0x2);
    address public stranger = address(0x3);

    uint8 internal constant SOURCE_HYPERLIQUID = 1;
    uint256 internal constant INITIAL_MID = 1.08e18;

    /// @notice Deploys TimeProvider, mocks and the oracle proxy with an initial fresh mid.
    function setUp() public {
        vm.warp(1_000_000);

        TimeProvider tpImpl = new TimeProvider();
        ERC1967Proxy tpProxy = new ERC1967Proxy(
            address(tpImpl),
            abi.encodeWithSelector(TimeProvider.initialize.selector, admin, admin, admin)
        );
        timeProvider = TimeProvider(payable(address(tpProxy)));

        slippage = new MockSlippageStorage();
        slippage.setMid(uint128(INITIAL_MID), uint48(block.timestamp));
        usdc = new MockUsdcOracle();

        implementation = new HyperliquidEurUsdOracle(timeProvider);
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                HyperliquidEurUsdOracle.initialize.selector,
                admin,
                address(slippage),
                SOURCE_HYPERLIQUID,
                address(usdc),
                treasury
            )
        );
        oracle = HyperliquidEurUsdOracle(payable(address(proxy)));
        gate = new HLGate();
    }

    // ---- Initialization ----

    function test_Initialization() public view {
        assertTrue(oracle.hasRole(oracle.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(oracle.hasRole(oracle.ORACLE_MANAGER_ROLE(), admin));
        assertTrue(oracle.hasRole(oracle.EMERGENCY_ROLE(), admin));
        assertEq(address(oracle.slippageStorage()), address(slippage));
        assertEq(address(oracle.usdcSource()), address(usdc));
        assertEq(oracle.sourceId(), SOURCE_HYPERLIQUID);
        assertEq(oracle.treasury(), treasury);
        assertEq(oracle.maxPriceStaleness(), 900);
        assertEq(oracle.minEurUsdPrice(), 0.80e18);
        assertEq(oracle.maxEurUsdPrice(), 1.40e18);
    }

    function test_SeedsBaselineOnInit() public view {
        // initialize() seeds from the fresh mid present at deploy time.
        assertEq(oracle.lastValidEurUsdPrice(), INITIAL_MID);
    }

    // ---- Happy path ----

    function test_GetEurUsdPrice_ReturnsPublishedMid() public {
        (uint256 price, bool isValid) = oracle.getEurUsdPrice();
        assertEq(price, INITIAL_MID);
        assertTrue(isValid);
    }

    function test_GetEurUsdPrice_TracksMidMoves() public {
        // A small in-bounds, within-deviation move is accepted and advances the baseline.
        uint128 newMid = 1.10e18;
        slippage.setMid(newMid, uint48(block.timestamp));
        (uint256 price, bool isValid) = oracle.getEurUsdPrice();
        assertEq(price, newMid);
        assertTrue(isValid);
        assertEq(oracle.lastValidEurUsdPrice(), newMid);
    }

    // ---- Staleness ----

    function test_StalePrice_ReturnsFallbackInvalid() public {
        vm.warp(block.timestamp + 901); // exceed maxPriceStaleness (900)
        (uint256 price, bool isValid) = oracle.getEurUsdPrice();
        assertFalse(isValid);
        assertEq(price, INITIAL_MID); // last valid baseline
    }

    function test_StalePrice_GateReverts() public {
        vm.warp(block.timestamp + 901);
        vm.expectRevert(HLGate.InvalidOraclePrice.selector);
        gate.requireLivePrice(oracle);
    }

    function test_FreshAgainAfterRepublish() public {
        vm.warp(block.timestamp + 901);
        (, bool stale) = oracle.getEurUsdPrice();
        assertFalse(stale);
        // Publisher writes a fresh snapshot.
        slippage.setMid(uint128(INITIAL_MID), uint48(block.timestamp));
        (uint256 price, bool isValid) = oracle.getEurUsdPrice();
        assertTrue(isValid);
        assertEq(price, INITIAL_MID);
    }

    // ---- Bounds & deviation ----

    function test_OutOfBounds_ReturnsFallbackInvalid() public {
        slippage.setMid(uint128(1.50e18), uint48(block.timestamp)); // > maxEurUsdPrice
        (uint256 price, bool isValid) = oracle.getEurUsdPrice();
        assertFalse(isValid);
        assertEq(price, INITIAL_MID);
    }

    function test_ExcessiveDeviation_ReturnsFallbackInvalid() public {
        // 1.08 -> 1.20 is in-bounds but > 5% deviation.
        slippage.setMid(uint128(1.20e18), uint48(block.timestamp));
        (uint256 price, bool isValid) = oracle.getEurUsdPrice();
        assertFalse(isValid);
        assertEq(price, INITIAL_MID);
    }

    // ---- Circuit breaker ----

    function test_CircuitBreaker_TriggerAndReset() public {
        vm.prank(admin);
        oracle.triggerCircuitBreaker();
        (uint256 p1, bool v1) = oracle.getEurUsdPrice();
        assertFalse(v1);
        assertEq(p1, INITIAL_MID);

        slippage.setMid(uint128(1.10e18), uint48(block.timestamp));
        vm.prank(admin);
        oracle.resetCircuitBreaker();
        // reset re-seeds from the fresh mid
        assertEq(oracle.lastValidEurUsdPrice(), 1.10e18);
        (uint256 p2, bool v2) = oracle.getEurUsdPrice();
        assertTrue(v2);
        assertEq(p2, 1.10e18);
    }

    // ---- Pause ----

    function test_Pause_BlocksReads() public {
        vm.prank(admin);
        oracle.pause();
        (uint256 price, bool isValid) = oracle.getEurUsdPrice();
        assertFalse(isValid);
        assertEq(price, INITIAL_MID);

        vm.prank(admin);
        oracle.unpause();
        (, bool v2) = oracle.getEurUsdPrice();
        assertTrue(v2);
    }

    // ---- USDC delegation ----

    function test_UsdcDelegation_PassesThrough() public {
        usdc.setUsdc(1.001e18, true);
        (uint256 price, bool isValid) = oracle.getUsdcUsdPrice();
        assertEq(price, 1.001e18);
        assertTrue(isValid);
    }

    function test_UsdcDelegation_FailSafeOnRevert() public {
        usdc.setShouldRevert(true);
        (uint256 price, bool isValid) = oracle.getUsdcUsdPrice();
        assertEq(price, 1e18);
        assertFalse(isValid);
    }

    // ---- Details / health / config ----

    function test_GetEurUsdDetails_FreshAndStale() public {
        (uint256 cur,, uint256 lastUpdate, bool isStale, bool withinBounds) = oracle.getEurUsdDetails();
        assertEq(cur, INITIAL_MID);
        assertFalse(isStale);
        assertTrue(withinBounds);
        assertEq(lastUpdate, block.timestamp);

        vm.warp(block.timestamp + 901);
        (uint256 cur2,,, bool isStale2,) = oracle.getEurUsdDetails();
        assertTrue(isStale2);
        assertEq(cur2, INITIAL_MID); // fallback to last valid
    }

    function test_GetOracleHealth() public {
        (bool healthy, bool eurFresh, bool usdcFresh) = oracle.getOracleHealth();
        assertTrue(healthy);
        assertTrue(eurFresh);
        assertTrue(usdcFresh);

        usdc.setUsdc(1e18, false);
        (bool healthy2,, bool usdcFresh2) = oracle.getOracleHealth();
        assertFalse(usdcFresh2);
        assertFalse(healthy2);
    }

    function test_GetOracleConfig() public view {
        (uint256 minP, uint256 maxP, uint256 staleness, uint256 tol, bool cb) = oracle.getOracleConfig();
        assertEq(minP, 0.80e18);
        assertEq(maxP, 1.40e18);
        assertEq(staleness, 900);
        assertEq(tol, 200);
        assertFalse(cb);
    }

    function test_GetPriceFeedAddresses() public view {
        (address eurFeed, address usdcFeed, uint8 d1, uint8 d2) = oracle.getPriceFeedAddresses();
        assertEq(eurFeed, address(slippage));
        assertEq(usdcFeed, address(usdc));
        assertEq(d1, 18);
        assertEq(d2, 18);
    }

    // ---- Source failure is fail-safe ----

    function test_SlippageRevert_HealthAndDetailsDegradeGracefully() public {
        slippage.setShouldRevert(true);
        (bool healthy, bool eurFresh,) = oracle.getOracleHealth();
        assertFalse(eurFresh);
        assertFalse(healthy);
        (uint256 cur,,, bool isStale,) = oracle.getEurUsdDetails();
        assertTrue(isStale);
        assertEq(cur, INITIAL_MID);
    }

    function test_SlippageRevert_GetEurUsdPriceBubbles() public {
        slippage.setShouldRevert(true);
        vm.expectRevert();
        oracle.getEurUsdPrice();
    }

    // ---- Configuration setters ----

    function test_SetMaxPriceStaleness() public {
        vm.prank(admin);
        oracle.setMaxPriceStaleness(300);
        assertEq(oracle.maxPriceStaleness(), 300);

        vm.warp(block.timestamp + 301);
        (, bool isValid) = oracle.getEurUsdPrice();
        assertFalse(isValid);
    }

    function test_SetMaxPriceStaleness_BoundsEnforced() public {
        vm.prank(admin);
        vm.expectRevert();
        oracle.setMaxPriceStaleness(0);

        vm.prank(admin);
        vm.expectRevert();
        oracle.setMaxPriceStaleness(3601); // > HARD_MAX_STALENESS
    }

    function test_UpdateSlippageSource() public {
        MockSlippageStorage s2 = new MockSlippageStorage();
        s2.setMid(uint128(1.09e18), uint48(block.timestamp));
        vm.prank(admin);
        oracle.updateSlippageSource(address(s2), 1);
        assertEq(address(oracle.slippageStorage()), address(s2));
        (uint256 price, bool isValid) = oracle.getEurUsdPrice();
        assertTrue(isValid);
        assertEq(price, 1.09e18);
    }

    function test_UpdatePriceBounds() public {
        vm.prank(admin);
        oracle.updatePriceBounds(0.5e18, 2e18);
        assertEq(oracle.minEurUsdPrice(), 0.5e18);
        assertEq(oracle.maxEurUsdPrice(), 2e18);
    }

    // ---- Access control ----

    function test_AccessControl_OnlyManager() public {
        vm.prank(stranger);
        vm.expectRevert();
        oracle.updatePriceBounds(0.5e18, 2e18);

        vm.prank(stranger);
        vm.expectRevert();
        oracle.setMaxPriceStaleness(300);

        vm.prank(stranger);
        vm.expectRevert();
        oracle.updateSlippageSource(address(slippage), 1);
    }

    function test_AccessControl_OnlyEmergency() public {
        vm.prank(stranger);
        vm.expectRevert();
        oracle.triggerCircuitBreaker();

        vm.prank(stranger);
        vm.expectRevert();
        oracle.pause();
    }
}
