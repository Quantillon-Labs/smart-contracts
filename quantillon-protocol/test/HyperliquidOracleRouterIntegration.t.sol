// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {OracleRouter} from "../src/oracle/OracleRouter.sol";
import {HyperliquidEurUsdOracle} from "../src/oracle/HyperliquidEurUsdOracle.sol";
import {MockChainlinkOracle} from "../src/mocks/MockChainlinkOracle.sol";
import {MockAggregatorV3} from "../src/mocks/MockAggregatorV3.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {MockSlippageStorage} from "./HyperliquidEurUsdOracle.t.sol";

/**
 * @title HyperliquidOracleRouterIntegrationTest
 * @notice Proves the Hyperliquid adapter slots into the OracleRouter's Stork position with no
 *         router change: reads route via IOracle and the four management calls delegate correctly.
 */
contract HyperliquidOracleRouterIntegrationTest is Test {
    OracleRouter public router;
    HyperliquidEurUsdOracle public hlOracle;
    MockChainlinkOracle public chainlink;
    MockSlippageStorage public slippage;
    TimeProvider public timeProvider;

    address public admin = address(0x1);
    address public treasury = address(0x2);
    uint8 internal constant SOURCE_HYPERLIQUID = 1;
    uint256 internal constant MID = 1.08e18;

    function setUp() public {
        vm.warp(1_000_000);

        TimeProvider tpImpl = new TimeProvider();
        ERC1967Proxy tpProxy = new ERC1967Proxy(
            address(tpImpl),
            abi.encodeWithSelector(TimeProvider.initialize.selector, admin, admin, admin)
        );
        timeProvider = TimeProvider(payable(address(tpProxy)));

        // Chainlink mock used both as the router's CHAINLINK slot and the adapter's USDC source.
        MockAggregatorV3 eurAgg = new MockAggregatorV3(8);
        MockAggregatorV3 usdcAgg = new MockAggregatorV3(8);
        eurAgg.setPrice(1.08e8);
        usdcAgg.setPrice(1.00e8);
        MockChainlinkOracle clImpl = new MockChainlinkOracle();
        ERC1967Proxy clProxy = new ERC1967Proxy(
            address(clImpl),
            abi.encodeWithSelector(
                MockChainlinkOracle.initialize.selector,
                admin,
                address(eurAgg),
                address(usdcAgg),
                treasury
            )
        );
        chainlink = MockChainlinkOracle(payable(address(clProxy)));

        slippage = new MockSlippageStorage();
        slippage.setMid(uint128(MID), uint48(block.timestamp));

        HyperliquidEurUsdOracle hlImpl = new HyperliquidEurUsdOracle(timeProvider);
        ERC1967Proxy hlProxy = new ERC1967Proxy(
            address(hlImpl),
            abi.encodeWithSelector(
                HyperliquidEurUsdOracle.initialize.selector,
                admin,
                address(slippage),
                SOURCE_HYPERLIQUID,
                address(chainlink),
                treasury
            )
        );
        hlOracle = HyperliquidEurUsdOracle(payable(address(hlProxy)));

        OracleRouter rImpl = new OracleRouter();
        ERC1967Proxy rProxy = new ERC1967Proxy(
            address(rImpl),
            abi.encodeWithSelector(
                OracleRouter.initialize.selector,
                admin,
                address(chainlink),
                address(hlOracle), // Hyperliquid adapter takes the Stork slot
                treasury,
                OracleRouter.OracleType.CHAINLINK
            )
        );
        router = OracleRouter(payable(address(rProxy)));

        // The router delegates management with ORACLE_MANAGER_ROLE (bounds/tolerance) and
        // EMERGENCY_ROLE (circuit breaker), so grant both on the adapter — same as for StorkOracle.
        vm.startPrank(admin);
        AccessControlUpgradeable(address(hlOracle)).grantRole(hlOracle.ORACLE_MANAGER_ROLE(), address(router));
        AccessControlUpgradeable(address(hlOracle)).grantRole(hlOracle.EMERGENCY_ROLE(), address(router));
        vm.stopPrank();
    }

    function test_RouterRoutesEurUsdToHyperliquid() public {
        vm.prank(admin);
        router.switchOracle(OracleRouter.OracleType.STORK);
        assertEq(uint256(router.activeOracle()), uint256(OracleRouter.OracleType.STORK));

        (uint256 price, bool isValid) = router.getEurUsdPrice();
        assertTrue(isValid);
        assertEq(price, MID);
    }

    function test_RouterDelegatesPriceBounds() public {
        vm.startPrank(admin);
        router.switchOracle(OracleRouter.OracleType.STORK);
        router.updatePriceBounds(0.5e18, 2e18);
        vm.stopPrank();
        assertEq(hlOracle.minEurUsdPrice(), 0.5e18);
        assertEq(hlOracle.maxEurUsdPrice(), 2e18);
    }

    function test_RouterDelegatesCircuitBreaker() public {
        vm.startPrank(admin);
        router.switchOracle(OracleRouter.OracleType.STORK);
        router.triggerCircuitBreaker();
        vm.stopPrank();
        assertTrue(hlOracle.circuitBreakerTriggered());

        (uint256 price, bool isValid) = router.getEurUsdPrice();
        assertFalse(isValid);
        assertEq(price, MID);

        vm.prank(admin);
        router.resetCircuitBreaker();
        assertFalse(hlOracle.circuitBreakerTriggered());
        (, bool isValid2) = router.getEurUsdPrice();
        assertTrue(isValid2);
    }

    function test_RouterUsdcDelegatesThroughAdapterToChainlink() public {
        vm.prank(admin);
        router.switchOracle(OracleRouter.OracleType.STORK);
        (uint256 price, bool isValid) = router.getUsdcUsdPrice();
        assertTrue(isValid);
        assertApproxEqAbs(price, 1e18, 0.02e18);
    }

    function test_ChainlinkFallbackStillServes() public {
        // Default active oracle is CHAINLINK: the safety fallback path remains live.
        (uint256 price, bool isValid) = router.getEurUsdPrice();
        assertTrue(isValid);
        assertGt(price, 0);
    }
}
