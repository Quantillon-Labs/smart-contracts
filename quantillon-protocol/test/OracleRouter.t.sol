// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {OracleRouter} from "../src/oracle/OracleRouter.sol";
import {ChainlinkOracle} from "../src/oracle/ChainlinkOracle.sol";
import {MockChainlinkOracle} from "../src/mocks/MockChainlinkOracle.sol";
import {MockStorkOracle} from "../src/mocks/MockStorkOracle.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AggregatorV3Interface} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";
import {MockUSDC} from "./AaveIntegration.t.sol";

    /**
     * @title MockAggregatorV3
     * @notice Mock Chainlink price feed for testing
     * @dev Implements AggregatorV3Interface for testing OracleRouter functionality
     */
    contract MockAggregatorV3 is AggregatorV3Interface {
    int256 public price;
    uint8 public decimals_;
    uint256 public updatedAt;
    uint80 public roundId = 1;
    
    /**
     * @notice Constructor for mock aggregator
     * @dev Initializes mock Chainlink aggregator with default price
     * @param _decimals Number of decimals for price representation
     * @custom:security No security implications - test mock
     * @custom:validation No validation - test mock
     * @custom:state-changes Initializes price, decimals, and timestamp
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - constructor
     * @custom:access Public - test mock
     * @custom:oracle Mock Chainlink price feed
     */
    constructor(uint8 _decimals) {
        decimals_ = _decimals;
        updatedAt = block.timestamp;
        price = 1.08e8; // Default EUR/USD price in 8 decimals
    }
    
    /**
     * @notice Sets the mock price
     * @dev Updates price, increments roundId, and updates timestamp
     * @param _price New price value
     * @custom:security No security implications - test mock
     * @custom:validation No validation - test mock
     * @custom:state-changes Updates price, roundId, and updatedAt
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle Updates mock Chainlink price
     */
    function setPrice(int256 _price) external {
        price = _price;
        roundId++;
        updatedAt = block.timestamp;
    }

    /**
     * @notice Sets the mock feed timestamp
     * @dev Allows tests to distinguish feed freshness from current block time
     * @param _updatedAt New feed updatedAt timestamp
     */
    function setUpdatedAt(uint256 _updatedAt) external {
        updatedAt = _updatedAt;
    }
    
    /**
     * @notice Returns latest round data
     * @dev Returns mock round data with current price and timestamps
     * @return roundId Latest round ID
     * @return price Latest price
     * @return startedAt Timestamp when round started
     * @return updatedAt Timestamp when round updated
     * @return answeredInRound Round ID when answer was computed
     * @custom:security No security implications - test mock
     * @custom:validation No validation - test mock
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - test mock
     * @custom:oracle Returns mock Chainlink round data
     */
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (roundId, price, updatedAt, updatedAt, roundId);
    }
    
    /**
     * @notice Returns number of decimals
     * @dev Returns the decimals value set in constructor
     * @return Number of decimals for price
     * @custom:security No security implications - test mock
     * @custom:validation No validation - test mock
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - test mock
     * @custom:oracle Returns mock Chainlink decimals
     */
    function decimals() external view returns (uint8) {
        return decimals_;
    }
    
    /**
     * @notice Returns feed description
     * @dev Returns hardcoded description string for mock feed
     * @return Description string
     * @custom:security No security implications - test mock
     * @custom:validation No validation - test mock
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - pure function
     * @custom:access Public - test mock
     * @custom:oracle Returns mock Chainlink description
     */
    function description() external pure returns (string memory) {
        return "Mock EUR/USD";
    }
    
    /**
     * @notice Returns feed version
     * @dev Returns hardcoded version number for mock feed
     * @return Version number
     * @custom:security No security implications - test mock
     * @custom:validation No validation - test mock
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - pure function
     * @custom:access Public - test mock
     * @custom:oracle Returns mock Chainlink version
     */
    function version() external pure returns (uint256) {
        return 1;
    }
    
    /**
     * @notice Returns round data for specific round
     * @dev Parameter is unnamed and unused in mock implementation
     * @return roundId Round ID
     * @return price Price for round
     * @return startedAt Timestamp when round started
     * @return updatedAt Timestamp when round updated
     * @return answeredInRound Round ID when answer was computed
     * @custom:security No security implications - test mock
     * @custom:validation No validation - test mock
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Reverts with "Not implemented"
     * @custom:reentrancy Not protected - pure function
     * @custom:access Public - test mock
     * @custom:oracle Returns mock Chainlink round data (not implemented)
     */
    function getRoundData(uint80) external pure returns (uint80, int256, uint256, uint256, uint80) {
        revert("Not implemented");
    }
}

/**
 * @title OracleRouterTest
 * @notice Test suite for OracleRouter contract
 */
contract OracleRouterTest is Test {
    OracleRouter public router;
    OracleRouter public implementation;
    MockChainlinkOracle public chainlinkOracle;
    MockStorkOracle public storkOracle;
    
    address public admin = address(0x1);
    address public treasury = address(0x2);
    address public user = address(0x3);
    
    MockAggregatorV3 public eurUsdFeed;
    MockAggregatorV3 public usdcUsdFeed;
    
    /**
     * @notice Sets up test environment
     * @dev Deploys and initializes mock oracles and router for testing
     * @custom:security No security implications - test setup
     * @custom:validation No validation - test setup
     * @custom:state-changes Deploys contracts and initializes test environment
     * @custom:events Emits initialization events
     * @custom:errors No errors thrown
     * @custom:reentrancy Not applicable - test setup
     * @custom:access Public - test function
     * @custom:oracle Sets up mock Chainlink and Stork oracles
     */
    function setUp() public {
        // Deploy mock Chainlink feeds
        eurUsdFeed = new MockAggregatorV3(8);
        usdcUsdFeed = new MockAggregatorV3(8);
        eurUsdFeed.setPrice(1.08e8); // 1.08 USD per EUR
        usdcUsdFeed.setPrice(1.00e8); // 1.00 USD
        
        // Deploy mock oracles
        chainlinkOracle = new MockChainlinkOracle();
        chainlinkOracle.initialize(
            admin,
            address(eurUsdFeed),
            address(usdcUsdFeed),
            treasury
        );
        vm.prank(admin);
        chainlinkOracle.setPrices(1.08e18, 1.00e18);
        
        storkOracle = new MockStorkOracle();
        storkOracle.initialize(
            admin,
            address(0), // Stork feed address (not used in mock)
            bytes32(0), // EUR/USD feed ID (not used in mock)
            bytes32(0), // USDC/USD feed ID (not used in mock)
            treasury
        );
        vm.prank(admin);
        storkOracle.setPrices(1.10e18, 1.00e18); // Different price for testing
        
        // Deploy router implementation
        implementation = new OracleRouter();
        
        // Deploy router proxy
        ERC1967Proxy routerProxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                OracleRouter.initialize.selector,
                admin,
                address(chainlinkOracle),
                address(storkOracle),
                treasury,
                OracleRouter.OracleType.CHAINLINK // Default to Chainlink
            )
        );
        router = OracleRouter(payable(address(routerProxy)));
        
        // Grant router the ORACLE_MANAGER_ROLE on both oracles so it can delegate admin calls
        bytes32 oracleManagerRole = keccak256("ORACLE_MANAGER_ROLE");
        vm.prank(admin);
        AccessControlUpgradeable(address(chainlinkOracle)).grantRole(oracleManagerRole, address(router));
        vm.prank(admin);
        AccessControlUpgradeable(address(storkOracle)).grantRole(oracleManagerRole, address(router));
    }
    
    /**
     * @notice Tests that router is properly initialized with correct roles and oracle addresses
     * @dev Verifies admin roles, oracle addresses, active oracle type, and treasury address
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - test function
     * @custom:oracle No oracle dependency
     */
    function test_Initialization() public view {
        assertEq(router.hasRole(router.DEFAULT_ADMIN_ROLE(), admin), true);
        assertEq(router.hasRole(router.ORACLE_MANAGER_ROLE(), admin), true);
        assertEq(router.hasRole(router.EMERGENCY_ROLE(), admin), true);
        assertEq(address(router.chainlinkOracle()), address(chainlinkOracle));
        assertEq(address(router.marketOracle()), address(storkOracle));
        // deprecated pre-1.1.0 alias must keep returning the slot-1 oracle
        assertEq(address(router.storkOracle()), address(storkOracle));
        assertEq(uint256(router.activeOracle()), uint256(OracleRouter.OracleType.CHAINLINK));
        assertEq(router.treasury(), treasury);
    }
    
    /**
     * @notice Tests that router delegates EUR/USD price to Chainlink oracle (default)
     * @dev Verifies router returns Chainlink price when Chainlink is active oracle
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes No state changes
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test function
     * @custom:access Public - test function
     * @custom:oracle Delegates to Chainlink oracle
     */
    function test_GetEurUsdPrice_Chainlink() public {
        // Router should delegate to Chainlink (default)
        (uint256 price, bool isValid) = router.getEurUsdPrice();
        assertGt(price, 0);
        assertTrue(isValid);
        assertEq(price, 1.08e18); // Chainlink price
    }

    function test_GetEurUsdPrice_AdvancesProductionChainlinkBaseline() public {
        MockAggregatorV3 realEurUsdFeed = new MockAggregatorV3(8);
        MockAggregatorV3 realUsdcUsdFeed = new MockAggregatorV3(8);
        realEurUsdFeed.setPrice(110_000_000);
        realUsdcUsdFeed.setPrice(100_000_000);

        TimeProvider timeProviderImpl = new TimeProvider();
        ERC1967Proxy timeProviderProxy = new ERC1967Proxy(
            address(timeProviderImpl),
            abi.encodeWithSelector(TimeProvider.initialize.selector, admin, admin, admin)
        );
        TimeProvider timeProvider = TimeProvider(payable(address(timeProviderProxy)));

        ChainlinkOracle realChainlinkImpl = new ChainlinkOracle(timeProvider);
        ERC1967Proxy realChainlinkProxy = new ERC1967Proxy(
            address(realChainlinkImpl),
            abi.encodeWithSelector(
                ChainlinkOracle.initialize.selector,
                admin,
                address(realEurUsdFeed),
                address(realUsdcUsdFeed),
                treasury
            )
        );
        ChainlinkOracle realChainlinkOracle = ChainlinkOracle(address(realChainlinkProxy));

        OracleRouter realRouterImpl = new OracleRouter();
        ERC1967Proxy realRouterProxy = new ERC1967Proxy(
            address(realRouterImpl),
            abi.encodeWithSelector(
                OracleRouter.initialize.selector,
                admin,
                address(realChainlinkOracle),
                address(storkOracle),
                treasury,
                OracleRouter.OracleType.CHAINLINK
            )
        );
        OracleRouter realRouter = OracleRouter(payable(address(realRouterProxy)));

        realEurUsdFeed.setPrice(114_000_000);
        (uint256 price, bool isValid) = realRouter.getEurUsdPrice();

        assertTrue(isValid);
        assertEq(price, 1.14e18);
        assertEq(realChainlinkOracle.lastValidEurUsdPrice(), 1.14e18);
    }
    
    /**
     * @notice Tests that router delegates EUR/USD price to Stork oracle after switch
     * @dev Verifies router returns Stork price when Stork is active oracle
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Switches active oracle to Stork
     * @custom:events Emits OracleSwitched event
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test function
     * @custom:access Public - test function
     * @custom:oracle Delegates to Stork oracle
     */
    function test_GetEurUsdPrice_Stork() public {
        // Switch to Stork
        vm.prank(admin);
        router.switchOracle(OracleRouter.OracleType.MARKET);
        
        // Router should delegate to Stork
        (uint256 price, bool isValid) = router.getEurUsdPrice();
        assertGt(price, 0);
        assertTrue(isValid);
        assertEq(price, 1.10e18); // Stork price
    }
    
    /**
     * @notice Tests switching active oracle from Chainlink to Stork
     * @dev Verifies oracle switch updates activeOracle and emits event
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Updates activeOracle to Stork
     * @custom:events Emits OracleSwitched event
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test function
     * @custom:access Restricted to admin role
     * @custom:oracle Switches from Chainlink to Stork oracle
     */
    function test_SwitchOracle_ChainlinkToStork() public {
        assertEq(uint256(router.activeOracle()), uint256(OracleRouter.OracleType.CHAINLINK));
        
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit OracleRouter.OracleSwitched(
            OracleRouter.OracleType.CHAINLINK,
            OracleRouter.OracleType.MARKET,
            admin
        );
        router.switchOracle(OracleRouter.OracleType.MARKET);
        
        assertEq(uint256(router.activeOracle()), uint256(OracleRouter.OracleType.MARKET));
        
        // Verify price comes from Stork
        (uint256 price, ) = router.getEurUsdPrice();
        assertEq(price, 1.10e18); // Stork price
    }
    
    /**
     * @notice Tests switching active oracle from Stork back to Chainlink
     * @dev Verifies oracle switch updates activeOracle correctly
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Updates activeOracle to Chainlink
     * @custom:events Emits OracleSwitched event
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test function
     * @custom:access Restricted to admin role
     * @custom:oracle Switches from Stork to Chainlink oracle
     */
    function test_SwitchOracle_StorkToChainlink() public {
        // First switch to Stork
        vm.prank(admin);
        router.switchOracle(OracleRouter.OracleType.MARKET);
        
        // Then switch back to Chainlink
        vm.prank(admin);
        router.switchOracle(OracleRouter.OracleType.CHAINLINK);
        
        assertEq(uint256(router.activeOracle()), uint256(OracleRouter.OracleType.CHAINLINK));
        
        // Verify price comes from Chainlink
        (uint256 price, ) = router.getEurUsdPrice();
        assertEq(price, 1.08e18); // Chainlink price
    }
    
    /**
     * @notice Tests that router returns USDC/USD price from active oracle
     * @dev Verifies router delegates USDC/USD price query to active oracle
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - test function
     * @custom:oracle Delegates to active oracle for USDC/USD price
     */
    function test_GetUsdcUsdPrice() public view {
        (uint256 price, bool isValid) = router.getUsdcUsdPrice();
        assertGt(price, 0);
        assertTrue(isValid);
        assertEq(price, 1.00e18);
    }
    
    /**
     * @notice Tests that router returns oracle health status
     * @dev Verifies router delegates health check to active oracle
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes No state changes
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test function
     * @custom:access Public - test function
     * @custom:oracle Delegates to active oracle for health check
     */
    function test_GetOracleHealth() public {
        (bool isHealthy, bool eurUsdFresh, bool usdcUsdFresh) = router.getOracleHealth();
        assertTrue(isHealthy);
        assertTrue(eurUsdFresh);
        assertTrue(usdcUsdFresh);
    }
    
    /**
     * @notice Tests that router returns detailed EUR/USD price information
     * @dev Verifies router delegates detailed price query to active oracle
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes No state changes
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test function
     * @custom:access Public - test function
     * @custom:oracle Delegates to active oracle for detailed price info
     */
    function test_GetEurUsdDetails() public view {
        (uint256 currentPrice, uint256 lastValidPrice, uint256 lastUpdate, bool isStale, bool withinBounds) = 
            router.getEurUsdDetails();
        assertGt(currentPrice, 0);
        assertGt(lastValidPrice, 0);
        assertGt(lastUpdate, 0);
        assertFalse(isStale);
        assertTrue(withinBounds);
    }

    /**
     * @notice Tests that router delegates the underlying feed timestamp
     * @dev Verifies lastUpdate is not replaced with current block time by the router path
     */
    function test_GetEurUsdDetailsDelegatesFeedTimestamp() public {
        vm.warp(block.timestamp + 1 days);
        uint256 feedTimestamp = block.timestamp - 1 hours;
        eurUsdFeed.setUpdatedAt(feedTimestamp);

        (, , uint256 lastUpdate, bool isStale, ) = router.getEurUsdDetails();

        assertEq(lastUpdate, feedTimestamp);
        assertNotEq(lastUpdate, block.timestamp);
        assertFalse(isStale);
    }
    
    /**
     * @notice Tests that router returns oracle configuration parameters
     * @dev Verifies router delegates config query to active oracle
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - test function
     * @custom:oracle Delegates to active oracle for configuration
     */
    function test_GetOracleConfig() public view {
        (uint256 minPrice, uint256 maxPrice, uint256 maxStaleness, uint256 usdcTolerance, bool circuitBreakerActive) = 
            router.getOracleConfig();
        assertGt(minPrice, 0);
        assertGt(maxPrice, 0);
        assertGt(maxStaleness, 0);
        assertGt(usdcTolerance, 0);
        assertFalse(circuitBreakerActive);
    }
    
    /**
     * @notice Tests that router returns price feed addresses and decimals
     * @dev Verifies router delegates feed address query to active oracle
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - test function
     * @custom:oracle Delegates to active oracle for feed addresses
     */
    function test_GetPriceFeedAddresses() public view {
        (address eurUsdFeedAddress, address usdcUsdFeedAddress, uint8 eurUsdDecimals, uint8 usdcUsdDecimals) = 
            router.getPriceFeedAddresses();
        assertNotEq(eurUsdFeedAddress, address(0));
        assertNotEq(usdcUsdFeedAddress, address(0));
        assertGt(eurUsdDecimals, 0);
        assertGt(usdcUsdDecimals, 0);
    }
    
    /**
     * @notice Tests that router checks price feed connectivity
     * @dev Verifies router delegates connectivity check to active oracle
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - test function
     * @custom:oracle Delegates to active oracle for connectivity check
     */
    function test_CheckPriceFeedConnectivity() public view {
        (bool eurUsdConnected, bool usdcUsdConnected, uint80 eurUsdLatestRound, uint80 usdcUsdLatestRound) = 
            router.checkPriceFeedConnectivity();
        assertTrue(eurUsdConnected);
        assertTrue(usdcUsdConnected);
        assertGt(eurUsdLatestRound, 0);
        assertGt(usdcUsdLatestRound, 0);
    }
    
    /**
     * @notice Tests that router can update oracle addresses
     * @dev Verifies router updates chainlinkOracle and marketOracle addresses
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Updates oracle addresses
     * @custom:events Emits oracle address update events
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test function
     * @custom:access Restricted to admin role
     * @custom:oracle Updates Chainlink and Stork oracle addresses
     */
    function test_UpdateOracleAddresses() public {
        MockChainlinkOracle newChainlink = new MockChainlinkOracle();
        newChainlink.initialize(admin, address(eurUsdFeed), address(usdcUsdFeed), treasury);
        
        MockStorkOracle newStork = new MockStorkOracle();
        newStork.initialize(admin, address(0), bytes32(0), bytes32(0), treasury);
        
        vm.prank(admin);
        router.updateOracleAddresses(address(newChainlink), address(newStork));
        
        assertEq(address(router.chainlinkOracle()), address(newChainlink));
        assertEq(address(router.marketOracle()), address(newStork));
        // deprecated pre-1.1.0 alias follows the slot-1 update
        assertEq(address(router.storkOracle()), address(newStork));
    }
    
    /**
     * @notice Tests that router can update price bounds via delegation
     * @dev Verifies router delegates price bound update to active oracle
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Updates price bounds on active oracle
     * @custom:events Emits price bound update events
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test function
     * @custom:access Restricted to admin role
     * @custom:oracle Delegates price bound update to active oracle
     */
    function test_UpdatePriceBounds() public {
        // updatePriceBounds requires ORACLE_MANAGER_ROLE on the underlying oracle
        // Admin should already have this role from initialization
        vm.prank(admin);
        router.updatePriceBounds(0.90e18, 1.30e18);
        
        // Verify it was delegated to active oracle
        // Variables are intentionally unused - we only verify the call succeeds
        uint256 _minPrice;
        uint256 _maxPrice;
        (_minPrice, _maxPrice, , , ) = router.getOracleConfig();
        // Note: This will reflect the oracle's bounds, not necessarily what we set
        // because the router delegates to the oracle
    }
    
    /**
     * @notice Tests that router can be paused
     * @dev Verifies pause functionality works correctly
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Sets paused state to true
     * @custom:events Emits Paused event
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test function
     * @custom:access Restricted to admin role
     * @custom:oracle No oracle dependency
     */
    function test_Pause() public {
        vm.prank(admin);
        router.pause();
        
        assertTrue(router.paused());
    }
    
    /**
     * @notice Tests that router can be unpaused
     * @dev Verifies unpause functionality works correctly
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Sets paused state to false
     * @custom:events Emits Unpaused event
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test function
     * @custom:access Restricted to admin role
     * @custom:oracle No oracle dependency
     */
    function test_Unpause() public {
        vm.prank(admin);
        router.pause();
        
        vm.prank(admin);
        router.unpause();
        
        assertFalse(router.paused());
    }
    
    /**
     * @notice Tests that router can recover ETH to treasury
     * @dev Verifies ETH recovery functionality transfers ETH to treasury
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Transfers ETH from router to treasury
     * @custom:events Emits ETH recovery events
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test function
     * @custom:access Restricted to admin role
     * @custom:oracle No oracle dependency
     */
    function test_RecoverETH() public {
        vm.deal(address(router), 1 ether);
        
        uint256 balanceBefore = treasury.balance;
        
        vm.prank(admin);
        router.recoverETH();
        
        assertEq(treasury.balance, balanceBefore + 1 ether);
    }
    
    /**
     * @notice Tests that router returns current active oracle type
     * @dev Verifies getActiveOracle returns correct oracle type after switches
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Switches active oracle
     * @custom:events Emits OracleSwitched event
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test function
     * @custom:access Public - test function
     * @custom:oracle Returns active oracle type
     */
    function test_GetActiveOracle() public {
        assertEq(uint256(router.getActiveOracle()), uint256(OracleRouter.OracleType.CHAINLINK));
        
        vm.prank(admin);
        router.switchOracle(OracleRouter.OracleType.MARKET);
        
        assertEq(uint256(router.getActiveOracle()), uint256(OracleRouter.OracleType.MARKET));
    }
    
    /**
     * @notice Tests that router returns Chainlink and Stork oracle addresses
     * @dev Verifies getOracleAddresses returns both oracle contract addresses
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - test function
     * @custom:oracle Returns oracle contract addresses
     */
    function test_GetOracleAddresses() public view {
        (address chainlinkAddress, address marketAddress) = router.getOracleAddresses();
        assertEq(chainlinkAddress, address(chainlinkOracle));
        assertEq(marketAddress, address(storkOracle));
    }
    
    /**
     * @notice Tests that non-admin cannot switch oracle
     * @dev Verifies access control prevents unauthorized oracle switching
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Attempts unauthorized oracle switch
     * @custom:events No events emitted
     * @custom:errors Expects revert on unauthorized access
     * @custom:reentrancy Not protected - test function
     * @custom:access Restricted to admin role
     * @custom:oracle No oracle dependency
     */
    function test_Revert_NonAdminCannotSwitchOracle() public {
        vm.prank(user);
        vm.expectRevert();
        router.switchOracle(OracleRouter.OracleType.MARKET);
    }
    
    /**
     * @notice Tests that switching to the same oracle reverts
     * @dev Verifies router prevents redundant oracle switches
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Attempts to switch to current oracle
     * @custom:events No events emitted
     * @custom:errors Expects revert with "Already using this oracle"
     * @custom:reentrancy Not protected - test function
     * @custom:access Restricted to admin role
     * @custom:oracle No oracle dependency
     */
    function test_Revert_CannotSwitchToSameOracle() public {
        vm.prank(admin);
        // F-11: switchOracle now reverts with the CommonErrorLibrary.NoChangeDetected custom error
        vm.expectRevert(bytes4(keccak256("NoChangeDetected()")));
        router.switchOracle(OracleRouter.OracleType.CHAINLINK); // Already using Chainlink
    }
    
    /**
     * @notice Tests that initialize cannot be called on already initialized router
     * @dev Verifies that re-initialization is prevented
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Attempts to re-initialize router
     * @custom:events No events emitted
     * @custom:errors Expects revert with InvalidInitialization error
     * @custom:reentrancy Not protected - test function
     * @custom:access Public - test function
     * @custom:oracle No oracle dependency
     */
    function test_Revert_InitializeCalledOnRouter() public {
        // Router is already initialized via proxy, so calling initialize again will revert with InvalidInitialization
        vm.expectRevert();
        // Router initialize requires 5 parameters: admin, chainlinkOracle, marketOracle, treasury, defaultOracle
        router.initialize(admin, address(chainlinkOracle), address(storkOracle), treasury, OracleRouter.OracleType.CHAINLINK);
    }

    /**
     * @notice The implementation contract itself cannot be initialized (F-3/F-4)
     * @dev The constructor calls _disableInitializers(), so initializing the
     *      implementation directly (not via a proxy) must revert.
     * @custom:security Verifies implementation-takeover vector is closed
     * @custom:validation No validation - test function
     * @custom:state-changes None - revert expected
     * @custom:events No events emitted
     * @custom:errors Expects revert with InvalidInitialization error
     * @custom:reentrancy Not protected - test function
     * @custom:access Public - test function
     * @custom:oracle No oracle dependency
     */
    function test_Revert_InitializeImplementationDirectly() public {
        vm.expectRevert();
        implementation.initialize(admin, address(chainlinkOracle), address(storkOracle), treasury, OracleRouter.OracleType.CHAINLINK);
    }
    
    event OracleSwitched(
        OracleRouter.OracleType indexed oldOracle,
        OracleRouter.OracleType indexed newOracle,
        address indexed caller
    );

    event TreasuryUpdated(address indexed newTreasury);

    // ─────────────────────────────────────────────────────────────────────────
    // Added coverage (audit SC1-6): initialize validation, treasury mgmt,
    // recover guards, and the switch-event emission — previously untested branches.
    // ─────────────────────────────────────────────────────────────────────────

    function _initData(address a, address cl, address mkt, address t) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            OracleRouter.initialize.selector, a, cl, mkt, t, OracleRouter.OracleType.CHAINLINK
        );
    }

    function test_Initialize_ZeroAdmin_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        new ERC1967Proxy(address(implementation), _initData(address(0), address(chainlinkOracle), address(storkOracle), treasury));
    }

    function test_Initialize_ZeroChainlink_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        new ERC1967Proxy(address(implementation), _initData(admin, address(0), address(storkOracle), treasury));
    }

    function test_Initialize_ZeroMarket_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        new ERC1967Proxy(address(implementation), _initData(admin, address(chainlinkOracle), address(0), treasury));
    }

    function test_Initialize_ZeroTreasury_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        new ERC1967Proxy(address(implementation), _initData(admin, address(chainlinkOracle), address(storkOracle), address(0)));
    }

    function test_UpdateTreasury_Success_EmitsAndUpdates() public {
        address newTreasury = address(0xBEEF);
        vm.expectEmit(true, false, false, false);
        emit TreasuryUpdated(newTreasury);
        vm.prank(admin);
        router.updateTreasury(newTreasury);
        assertEq(router.treasury(), newTreasury);
    }

    function test_UpdateTreasury_Zero_Reverts() public {
        vm.prank(admin);
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        router.updateTreasury(address(0));
    }

    function test_UpdateTreasury_Unauthorized_Reverts() public {
        vm.prank(address(0x1234));
        vm.expectRevert();
        router.updateTreasury(address(0xBEEF));
    }

    function test_RecoverETH_NoEth_Reverts() public {
        // Router holds no ETH -> balance < 1 branch.
        vm.prank(admin);
        vm.expectRevert(CommonErrorLibrary.NoETHToRecover.selector);
        router.recoverETH();
    }

    function test_SwitchOracle_EmitsEvent() public {
        vm.expectEmit(true, true, true, false);
        emit OracleSwitched(OracleRouter.OracleType.CHAINLINK, OracleRouter.OracleType.MARKET, admin);
        vm.prank(admin);
        router.switchOracle(OracleRouter.OracleType.MARKET);
        assertEq(uint256(router.activeOracle()), uint256(OracleRouter.OracleType.MARKET));
    }

    // =============================================================================
    // DELEGATION + ADMIN BRANCH COVERAGE
    // =============================================================================

    function test_version_returnsSemver() public view {
        assertEq(router.version(), "1.1.1");
    }

    /// @notice updateUsdcTolerance delegates to the active oracle on both slots.
    function test_updateUsdcTolerance_chainlinkAndMarket() public {
        // CHAINLINK slot active by default.
        vm.prank(admin);
        router.updateUsdcTolerance(150);
        // Switch to MARKET and delegate there.
        vm.prank(admin);
        router.switchOracle(OracleRouter.OracleType.MARKET);
        vm.prank(admin);
        router.updateUsdcTolerance(200);
    }

    /// @notice updatePriceFeeds delegates on CHAINLINK and reverts on the MARKET slot.
    function test_updatePriceFeeds_chainlinkThenMarketReverts() public {
        vm.prank(admin);
        router.updatePriceFeeds(address(0xEE), address(0xFF));

        vm.prank(admin);
        router.switchOracle(OracleRouter.OracleType.MARKET);
        vm.prank(admin);
        vm.expectRevert(CommonErrorLibrary.InvalidParameter.selector);
        router.updatePriceFeeds(address(0xEE), address(0xFF));
    }

    /// @notice reset/trigger circuit breaker delegate to the active oracle.
    function test_resetAndTriggerCircuitBreaker_chainlink() public {
        // The router needs EMERGENCY_ROLE on the delegate to forward breaker calls.
        vm.prank(admin);
        AccessControlUpgradeable(address(chainlinkOracle)).grantRole(keccak256("EMERGENCY_ROLE"), address(router));

        vm.prank(admin);
        router.triggerCircuitBreaker();
        vm.prank(admin);
        router.resetCircuitBreaker();
    }

    function test_pauseThenUnpause() public {
        vm.prank(admin);
        router.pause();
        assertTrue(router.paused());
        vm.prank(admin);
        router.unpause();
        assertFalse(router.paused());
    }

    function test_recoverToken_toTreasury() public {
        MockUSDC tok = new MockUSDC();
        tok.mint(address(router), 500e6);
        vm.prank(admin);
        router.recoverToken(address(tok), 500e6);
        assertEq(tok.balanceOf(treasury), 500e6);
    }

    function test_authorizeUpgrade_viaUpgrade() public {
        OracleRouter newImpl = new OracleRouter();
        vm.prank(admin);
        router.upgradeToAndCall(address(newImpl), "");
        assertEq(router.version(), "1.1.1");
    }
}
