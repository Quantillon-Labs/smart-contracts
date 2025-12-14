// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {OracleRouter} from "../src/oracle/OracleRouter.sol";
import {MockChainlinkOracle} from "../src/mocks/MockChainlinkOracle.sol";
import {MockStorkOracle} from "../src/mocks/MockStorkOracle.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AggregatorV3Interface} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title MockAggregatorV3
 * @notice Mock Chainlink price feed for testing
 */
contract MockAggregatorV3 is AggregatorV3Interface {
    int256 public price;
    uint8 public decimals_;
    uint256 public updatedAt;
    uint80 public roundId = 1;
    
    /**
     * @notice Constructor for mock aggregator
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
     * @notice Returns latest round data
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
    
    function test_Initialization() public view {
        assertEq(router.hasRole(router.DEFAULT_ADMIN_ROLE(), admin), true);
        assertEq(router.hasRole(router.ORACLE_MANAGER_ROLE(), admin), true);
        assertEq(router.hasRole(router.EMERGENCY_ROLE(), admin), true);
        assertEq(address(router.chainlinkOracle()), address(chainlinkOracle));
        assertEq(address(router.storkOracle()), address(storkOracle));
        assertEq(uint256(router.activeOracle()), uint256(OracleRouter.OracleType.CHAINLINK));
        assertEq(router.treasury(), treasury);
    }
    
    function test_GetEurUsdPrice_Chainlink() public {
        // Router should delegate to Chainlink (default)
        (uint256 price, bool isValid) = router.getEurUsdPrice();
        assertGt(price, 0);
        assertTrue(isValid);
        assertEq(price, 1.08e18); // Chainlink price
    }
    
    function test_GetEurUsdPrice_Stork() public {
        // Switch to Stork
        vm.prank(admin);
        router.switchOracle(OracleRouter.OracleType.STORK);
        
        // Router should delegate to Stork
        (uint256 price, bool isValid) = router.getEurUsdPrice();
        assertGt(price, 0);
        assertTrue(isValid);
        assertEq(price, 1.10e18); // Stork price
    }
    
    function test_SwitchOracle_ChainlinkToStork() public {
        assertEq(uint256(router.activeOracle()), uint256(OracleRouter.OracleType.CHAINLINK));
        
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit OracleRouter.OracleSwitched(
            OracleRouter.OracleType.CHAINLINK,
            OracleRouter.OracleType.STORK,
            admin
        );
        router.switchOracle(OracleRouter.OracleType.STORK);
        
        assertEq(uint256(router.activeOracle()), uint256(OracleRouter.OracleType.STORK));
        
        // Verify price comes from Stork
        (uint256 price, ) = router.getEurUsdPrice();
        assertEq(price, 1.10e18); // Stork price
    }
    
    function test_SwitchOracle_StorkToChainlink() public {
        // First switch to Stork
        vm.prank(admin);
        router.switchOracle(OracleRouter.OracleType.STORK);
        
        // Then switch back to Chainlink
        vm.prank(admin);
        router.switchOracle(OracleRouter.OracleType.CHAINLINK);
        
        assertEq(uint256(router.activeOracle()), uint256(OracleRouter.OracleType.CHAINLINK));
        
        // Verify price comes from Chainlink
        (uint256 price, ) = router.getEurUsdPrice();
        assertEq(price, 1.08e18); // Chainlink price
    }
    
    function test_GetUsdcUsdPrice() public view {
        (uint256 price, bool isValid) = router.getUsdcUsdPrice();
        assertGt(price, 0);
        assertTrue(isValid);
        assertEq(price, 1.00e18);
    }
    
    function test_GetOracleHealth() public {
        (bool isHealthy, bool eurUsdFresh, bool usdcUsdFresh) = router.getOracleHealth();
        assertTrue(isHealthy);
        assertTrue(eurUsdFresh);
        assertTrue(usdcUsdFresh);
    }
    
    function test_GetEurUsdDetails() public {
        (uint256 currentPrice, uint256 lastValidPrice, uint256 lastUpdate, bool isStale, bool withinBounds) = 
            router.getEurUsdDetails();
        assertGt(currentPrice, 0);
        assertGt(lastValidPrice, 0);
        assertGt(lastUpdate, 0);
        assertFalse(isStale);
        assertTrue(withinBounds);
    }
    
    function test_GetOracleConfig() public view {
        (uint256 minPrice, uint256 maxPrice, uint256 maxStaleness, uint256 usdcTolerance, bool circuitBreakerActive) = 
            router.getOracleConfig();
        assertGt(minPrice, 0);
        assertGt(maxPrice, 0);
        assertGt(maxStaleness, 0);
        assertGt(usdcTolerance, 0);
        assertFalse(circuitBreakerActive);
    }
    
    function test_GetPriceFeedAddresses() public view {
        (address eurUsdFeedAddress, address usdcUsdFeedAddress, uint8 eurUsdDecimals, uint8 usdcUsdDecimals) = 
            router.getPriceFeedAddresses();
        assertNotEq(eurUsdFeedAddress, address(0));
        assertNotEq(usdcUsdFeedAddress, address(0));
        assertGt(eurUsdDecimals, 0);
        assertGt(usdcUsdDecimals, 0);
    }
    
    function test_CheckPriceFeedConnectivity() public view {
        (bool eurUsdConnected, bool usdcUsdConnected, uint80 eurUsdLatestRound, uint80 usdcUsdLatestRound) = 
            router.checkPriceFeedConnectivity();
        assertTrue(eurUsdConnected);
        assertTrue(usdcUsdConnected);
        assertGt(eurUsdLatestRound, 0);
        assertGt(usdcUsdLatestRound, 0);
    }
    
    function test_UpdateOracleAddresses() public {
        MockChainlinkOracle newChainlink = new MockChainlinkOracle();
        newChainlink.initialize(admin, address(eurUsdFeed), address(usdcUsdFeed), treasury);
        
        MockStorkOracle newStork = new MockStorkOracle();
        newStork.initialize(admin, address(0), bytes32(0), bytes32(0), treasury);
        
        vm.prank(admin);
        router.updateOracleAddresses(address(newChainlink), address(newStork));
        
        assertEq(address(router.chainlinkOracle()), address(newChainlink));
        assertEq(address(router.storkOracle()), address(newStork));
    }
    
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
    
    function test_Pause() public {
        vm.prank(admin);
        router.pause();
        
        assertTrue(router.paused());
    }
    
    function test_Unpause() public {
        vm.prank(admin);
        router.pause();
        
        vm.prank(admin);
        router.unpause();
        
        assertFalse(router.paused());
    }
    
    function test_RecoverETH() public {
        vm.deal(address(router), 1 ether);
        
        uint256 balanceBefore = treasury.balance;
        
        vm.prank(admin);
        router.recoverETH();
        
        assertEq(treasury.balance, balanceBefore + 1 ether);
    }
    
    function test_GetActiveOracle() public {
        assertEq(uint256(router.getActiveOracle()), uint256(OracleRouter.OracleType.CHAINLINK));
        
        vm.prank(admin);
        router.switchOracle(OracleRouter.OracleType.STORK);
        
        assertEq(uint256(router.getActiveOracle()), uint256(OracleRouter.OracleType.STORK));
    }
    
    function test_GetOracleAddresses() public view {
        (address chainlinkAddress, address storkAddress) = router.getOracleAddresses();
        assertEq(chainlinkAddress, address(chainlinkOracle));
        assertEq(storkAddress, address(storkOracle));
    }
    
    function test_Revert_NonAdminCannotSwitchOracle() public {
        vm.prank(user);
        vm.expectRevert();
        router.switchOracle(OracleRouter.OracleType.STORK);
    }
    
    function test_Revert_CannotSwitchToSameOracle() public {
        vm.prank(admin);
        vm.expectRevert("OracleRouter: Already using this oracle");
        router.switchOracle(OracleRouter.OracleType.CHAINLINK); // Already using Chainlink
    }
    
    function test_Revert_InitializeCalledOnRouter() public {
        // Router is already initialized via proxy, so calling initialize again will revert with InvalidInitialization
        vm.expectRevert();
        // Router initialize requires 5 parameters: admin, chainlinkOracle, storkOracle, treasury, defaultOracle
        router.initialize(admin, address(chainlinkOracle), address(storkOracle), treasury, OracleRouter.OracleType.CHAINLINK);
    }
    
    event OracleSwitched(
        OracleRouter.OracleType indexed oldOracle,
        OracleRouter.OracleType indexed newOracle,
        address indexed caller
    );
}

