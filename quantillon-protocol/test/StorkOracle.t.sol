// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {StorkOracle} from "../src/oracle/StorkOracle.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title MockStorkFeed
 * @notice Mock Stork price feed for testing
 * @dev Implements IStorkFeed interface with configurable behavior
 */
contract MockStorkFeed {
    struct TemporalNumericValue {
        int256 value;
        uint256 timestamp;
    }
    
    uint8 public decimals_;
    uint256 public updatedAt;
    bool public shouldRevert;
    
    // Store prices per feed ID to support multiple feeds from same contract
    mapping(bytes32 => int256) public prices;
    mapping(bytes32 => uint256) public timestamps;
    
    /**
     * @notice Constructor for mock Stork feed
     * @dev Initializes mock feed with decimals and optional feed ID price
     * @param _decimals Number of decimals for price representation
     * @param _feedId Feed ID to initialize (optional)
     * @custom:security No security implications - test mock
     * @custom:validation No validation - test mock
     * @custom:state-changes Initializes decimals, updatedAt, and default price for feed ID
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - constructor
     * @custom:access Public - test mock
     * @custom:oracle Mock Stork price feed
     */
    constructor(uint8 _decimals, bytes32 _feedId) {
        decimals_ = _decimals;
        updatedAt = block.timestamp;
        // Set default price for the feed ID
        // Stork uses 18 decimals, so use 1.08e18 for EUR/USD
        if (_feedId != bytes32(0)) {
            prices[_feedId] = 1.08e18; // Default EUR/USD price in 18 decimals
            timestamps[_feedId] = block.timestamp;
        }
    }
    
    /**
     * @notice Sets price for backward compatibility (deprecated)
     * @dev Parameter is unused - kept for backward compatibility
     * @custom:security No security implications - test mock
     * @custom:validation No validation - test mock
     * @custom:state-changes Updates updatedAt timestamp
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle Updates mock timestamp
     */
    function setPrice(int256 /* _price */) external {
        // Set price for all feed IDs (for backward compatibility)
        updatedAt = block.timestamp;
        // Note: This is kept for backward compatibility but setPriceForFeed should be used
    }
    
    /**
     * @notice Sets price for a specific feed ID
     * @dev Updates price mapping and sets timestamp if not already set
     * @param feedId Feed ID to set price for
     * @param _price New price value (18 decimals)
     * @custom:security No security implications - test mock
     * @custom:validation No validation - test mock
     * @custom:state-changes Updates prices[feedId] and timestamps[feedId] if not set
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle Updates mock price for specific feed
     */
    function setPriceForFeed(bytes32 feedId, int256 _price) external {
        prices[feedId] = _price;
        // Don't update timestamp here - use setUpdatedAtForFeed to control timestamp separately
        // Only update if timestamp not already set for this feed
        if (timestamps[feedId] == 0) {
            timestamps[feedId] = block.timestamp;
        }
    }
    
    /**
     * @notice Sets whether getTemporalNumericValueV1 should revert
     * @dev Updates shouldRevert flag to control mock behavior
     * @param _shouldRevert True to make getTemporalNumericValueV1 revert
     * @custom:security No security implications - test mock
     * @custom:validation No validation - test mock
     * @custom:state-changes Updates shouldRevert flag
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle No oracle dependency
     */
    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }
    
    /**
     * @notice Sets updatedAt timestamp for all feeds
     * @dev Updates global updatedAt timestamp used as fallback
     * @param _updatedAt New timestamp value
     * @custom:security No security implications - test mock
     * @custom:validation No validation - test mock
     * @custom:state-changes Updates updatedAt timestamp
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle Updates mock timestamp
     */
    function setUpdatedAt(uint256 _updatedAt) external {
        updatedAt = _updatedAt;
        // Update all feed timestamps
    }
    
    /**
     * @notice Sets updatedAt timestamp for a specific feed ID
     * @dev Updates timestamp mapping for specific feed ID
     * @param feedId Feed ID to update timestamp for
     * @param _updatedAt New timestamp value
     * @custom:security No security implications - test mock
     * @custom:validation No validation - test mock
     * @custom:state-changes Updates timestamps[feedId]
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test mock
     * @custom:access Public - test mock
     * @custom:oracle Updates mock timestamp for specific feed
     */
    function setUpdatedAtForFeed(bytes32 feedId, uint256 _updatedAt) external {
        timestamps[feedId] = _updatedAt;
        // Don't update updatedAt here to avoid conflicts
    }
    
    /**
     * @notice Returns temporal numeric value for a feed ID
     * @dev Returns price and timestamp for feed ID, with fallback logic
     * @param id Feed ID to query
     * @return TemporalNumericValue struct with price and timestamp
     * @custom:security No security implications - test mock
     * @custom:validation No validation - test mock
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors Reverts with "MockStorkFeed: Revert requested" if shouldRevert is true
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - test mock
     * @custom:oracle Returns mock price and timestamp for feed ID
     */
    function getTemporalNumericValueV1(bytes32 id) external view returns (TemporalNumericValue memory) {
        if (shouldRevert) {
            revert("MockStorkFeed: Revert requested");
        }
        // Return price for the specific feed ID
        int256 price = prices[id];
        // Always use the timestamp stored for this specific feed ID
        uint256 timestamp = timestamps[id];
        
        // If no timestamp set for this feed ID, use updatedAt
        if (timestamp == 0) {
            timestamp = updatedAt;
        }
        
        // If still 0, use block.timestamp as last resort
        if (timestamp == 0) {
            timestamp = block.timestamp;
        }
        
        return TemporalNumericValue({
            value: price,
            timestamp: timestamp
        });
    }
    
    /**
     * @notice Returns number of decimals for price representation
     * @dev Returns stored decimals value
     * @return Number of decimals
     * @custom:security No security implications - test mock
     * @custom:validation No validation - test mock
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - test mock
     * @custom:oracle Returns mock decimals value
     */
    function decimals() external view returns (uint8) {
        return decimals_;
    }
}

/**
 * @title StorkOracleTest
 * @notice Test suite for StorkOracle contract
 */
contract StorkOracleTest is Test {
    StorkOracle public storkOracle;
    StorkOracle public implementation;
    TimeProvider public timeProvider;
    TimeProvider public timeProviderImpl;
    ERC1967Proxy public timeProviderProxy;
    ERC1967Proxy public oracleProxy;
    
    MockStorkFeed public eurUsdFeed;
    MockStorkFeed public usdcUsdFeed;
    
    address public admin = address(0x1);
    address public treasury = address(0x2);
    address public user = address(0x3);
    
    bytes32 public constant EUR_USD_FEED_ID = keccak256("EUR/USD");
    bytes32 public constant USDC_USD_FEED_ID = keccak256("USDC/USD");
    
    /**
     * @notice Sets up test environment with all required contracts
     * @dev Deploys and initializes TimeProvider, StorkOracle, and mock feeds
     * @custom:security No security implications - test setup
     * @custom:validation No validation - test setup
     * @custom:state-changes Deploys contracts and initializes test environment
     * @custom:events Emits initialization events
     * @custom:errors No errors thrown
     * @custom:reentrancy Not applicable - test setup
     * @custom:access Public - test function
     * @custom:oracle Sets up mock Stork feeds
     */
    function setUp() public {
        // Deploy TimeProvider
        timeProviderImpl = new TimeProvider();
        timeProviderProxy = new ERC1967Proxy(
            address(timeProviderImpl),
            abi.encodeWithSelector(
                TimeProvider.initialize.selector,
                admin,      // admin
                admin,      // governance (use admin for testing)
                admin       // emergency (use admin for testing)
            )
        );
        timeProvider = TimeProvider(payable(address(timeProviderProxy)));
        
        // Deploy StorkOracle implementation
        implementation = new StorkOracle(timeProvider);
        
        // Deploy mock feed - Stork uses a single contract for all feeds
        // We'll create a single mock that can handle both feed IDs with different prices
        // Stork feeds use 18 decimals
        eurUsdFeed = new MockStorkFeed(18, EUR_USD_FEED_ID);
        usdcUsdFeed = eurUsdFeed; // Use same contract for both feeds (Stork architecture)
        
        // Set initial prices for each feed ID (18 decimals)
        eurUsdFeed.setPriceForFeed(EUR_USD_FEED_ID, 1.08e18); // 1.08 USD per EUR
        eurUsdFeed.setPriceForFeed(USDC_USD_FEED_ID, 1.00e18); // 1.00 USD
        
        // Deploy proxy
        // Stork uses single contract address for all feeds
        oracleProxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                StorkOracle.initialize.selector,
                admin,
                address(eurUsdFeed), // Stork contract address (same for both feeds)
                EUR_USD_FEED_ID,
                USDC_USD_FEED_ID,
                treasury
            )
        );
        storkOracle = StorkOracle(payable(address(oracleProxy)));
    }
    
    /**
     * @notice Tests that StorkOracle is properly initialized
     * @dev Verifies admin roles, feed addresses, and treasury address
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
        assertEq(storkOracle.hasRole(storkOracle.DEFAULT_ADMIN_ROLE(), admin), true);
        assertEq(storkOracle.hasRole(storkOracle.ORACLE_MANAGER_ROLE(), admin), true);
        assertEq(storkOracle.hasRole(storkOracle.EMERGENCY_ROLE(), admin), true);
        assertEq(address(storkOracle.eurUsdPriceFeed()), address(eurUsdFeed));
        assertEq(address(storkOracle.usdcUsdPriceFeed()), address(usdcUsdFeed));
        assertEq(storkOracle.treasury(), treasury);
    }
    
    /**
     * @notice Tests that StorkOracle returns valid EUR/USD price
     * @dev Verifies price is returned in 18 decimals and marked as valid
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - test function
     * @custom:oracle Queries Stork feed for EUR/USD price
     */
    function test_GetEurUsdPrice() public view {
        (uint256 price, bool isValid) = storkOracle.getEurUsdPrice();
        assertGt(price, 0);
        assertTrue(isValid);
        // Price is already in 18 decimals (Stork uses 18 decimals)
        assertApproxEqRel(price, 1.08e18, 0.01e18);
    }
    
    /**
     * @notice Tests that StorkOracle returns valid USDC/USD price
     * @dev Verifies price is returned in 18 decimals and marked as valid
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - test function
     * @custom:oracle Queries Stork feed for USDC/USD price
     */
    function test_GetUsdcUsdPrice() public view {
        (uint256 price, bool isValid) = storkOracle.getUsdcUsdPrice();
        assertGt(price, 0);
        assertTrue(isValid);
        // Price is already in 18 decimals (Stork uses 18 decimals)
        assertApproxEqRel(price, 1.00e18, 0.01e18);
    }
    
    /**
     * @notice Tests that price bounds validation works correctly
     * @dev Verifies prices outside bounds are marked invalid
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Updates mock feed prices
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test function
     * @custom:access Public - test function
     * @custom:oracle Tests price bound validation on Stork feed
     */
    function test_PriceBounds() public {
        bool isValid;
        
        // Set price below minimum (18 decimals)
        eurUsdFeed.setPriceForFeed(EUR_USD_FEED_ID, 0.50e18); // 0.50 USD per EUR (below 0.80 minimum)
        (, isValid) = storkOracle.getEurUsdPrice();
        assertFalse(isValid);
        
        // Set price above maximum (18 decimals)
        eurUsdFeed.setPriceForFeed(EUR_USD_FEED_ID, 1.50e18); // 1.50 USD per EUR (above 1.40 maximum)
        (, isValid) = storkOracle.getEurUsdPrice();
        assertFalse(isValid);
        
        // Set valid price (18 decimals)
        eurUsdFeed.setPriceForFeed(EUR_USD_FEED_ID, 1.10e18); // 1.10 USD per EUR (within bounds)
        (, isValid) = storkOracle.getEurUsdPrice();
        assertTrue(isValid);
    }
    
    /**
     * @notice Tests that stale price timestamps are detected
     * @dev Verifies prices with timestamps older than max staleness are marked invalid
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Sets stale timestamp on mock feed, advances block time
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test function
     * @custom:access Public - test function
     * @custom:oracle Tests stale timestamp detection on Stork feed
     */
    function test_StalePrice() public {
        // Set a higher timestamp to avoid underflow issues
        vm.warp(10000);
        
        // First, establish a valid price by setting fresh timestamp and valid price
        eurUsdFeed.setPriceForFeed(EUR_USD_FEED_ID, 1.08e18);
        eurUsdFeed.setUpdatedAtForFeed(EUR_USD_FEED_ID, block.timestamp);
        
        // Reset circuit breaker to trigger _updatePrices() which sets lastValidEurUsdPrice
        // This ensures we have a valid price stored
        vm.prank(admin);
        storkOracle.resetCircuitBreaker();
        
        // Verify we now have a valid price
        (uint256 initialPrice, bool initialValid) = storkOracle.getEurUsdPrice();
        assertTrue(initialValid); // Should be valid after reset
        assertGt(initialPrice, 0); // Should have a price
        
        // Advance time significantly to ensure stale timestamp is clearly in the past
        // MAX_PRICE_STALENESS = 3600, MAX_TIMESTAMP_DRIFT = 900, total = 4500
        // We need to advance time and then set a timestamp that's more than 4500 seconds old
        vm.warp(block.timestamp + 10000); // Advance 10000 seconds, now at 20000
        
        // Now set timestamp to be stale (more than 1 hour + 15 minutes ago from current time)
        // Current time is now 20000, so set timestamp to 5000 (15000 seconds ago, clearly stale)
        // Validation: 20000 > 5000 + 4500 = 20000 > 9500 = true, so should be invalid
        uint256 staleTimestamp = 5000; // ~4.17 hours ago from current time (definitely stale)
        eurUsdFeed.setUpdatedAtForFeed(EUR_USD_FEED_ID, staleTimestamp);
        // Keep the price valid (positive), just make timestamp stale
        eurUsdFeed.setPriceForFeed(EUR_USD_FEED_ID, 1.08e18);
        
        // Verify the timestamp is actually stale by checking the mock feed
        // Then call getEurUsdPrice which should detect stale timestamp
        (uint256 price, bool isValid) = storkOracle.getEurUsdPrice();
        
        // When timestamp is stale, _validateTimestamp(5000) should return false because:
        // TIME_PROVIDER.currentTime() (20000) > staleTimestamp (5000) + maxAllowedAge (4500)
        // 20000 > 9500 = true, so validation fails
        // Therefore we return early with (lastValidEurUsdPrice, false)
        assertGt(price, 0); // Should return last valid price
        assertFalse(isValid, "Price should be invalid due to stale timestamp"); // Should be marked as invalid
    }
    
    /**
     * @notice Tests that circuit breaker prevents invalid prices
     * @dev Verifies circuit breaker triggers and marks prices as invalid
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Triggers circuit breaker
     * @custom:events Emits CircuitBreakerTriggered event
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test function
     * @custom:access Restricted to admin role
     * @custom:oracle Tests circuit breaker functionality
     */
    function test_CircuitBreaker() public {
        vm.prank(admin);
        // triggerCircuitBreaker doesn't emit CircuitBreakerTriggered event - it just sets the flag
        // The event is emitted in _updatePrices when validation fails
        storkOracle.triggerCircuitBreaker();
        
        assertTrue(storkOracle.circuitBreakerTriggered());
        
        (, bool isValid) = storkOracle.getEurUsdPrice();
        assertFalse(isValid);
    }
    
    /**
     * @notice Tests that circuit breaker can be reset
     * @dev Verifies resetCircuitBreaker clears circuit breaker flag
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Triggers then resets circuit breaker
     * @custom:events Emits circuit breaker events
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test function
     * @custom:access Restricted to admin role
     * @custom:oracle Tests circuit breaker reset functionality
     */
    function test_ResetCircuitBreaker() public {
        vm.prank(admin);
        storkOracle.triggerCircuitBreaker();
        
        vm.prank(admin);
        storkOracle.resetCircuitBreaker();
        
        assertFalse(storkOracle.circuitBreakerTriggered());
    }
    
    /**
     * @notice Tests that price bounds can be updated
     * @dev Verifies updatePriceBounds updates min and max price bounds
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Updates price bounds configuration
     * @custom:events Emits price bounds update events
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test function
     * @custom:access Restricted to admin role
     * @custom:oracle Updates price validation bounds
     */
    function test_UpdatePriceBounds() public {
        vm.prank(admin);
        storkOracle.updatePriceBounds(0.90e18, 1.30e18);
        
        (uint256 minPrice, uint256 maxPrice,,,) = storkOracle.getOracleConfig();
        assertEq(minPrice, 0.90e18);
        assertEq(maxPrice, 1.30e18);
    }
    
    /**
     * @notice Tests that price feed addresses can be updated
     * @dev Verifies updatePriceFeeds updates feed contract addresses and feed IDs
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Updates feed addresses and feed IDs
     * @custom:events Emits feed update events
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test function
     * @custom:access Restricted to admin role
     * @custom:oracle Updates Stork feed contract and feed IDs
     */
    function test_UpdatePriceFeeds() public {
        MockStorkFeed newFeed = new MockStorkFeed(18, EUR_USD_FEED_ID);
        newFeed.setPriceForFeed(EUR_USD_FEED_ID, 1.10e18);
        newFeed.setPriceForFeed(USDC_USD_FEED_ID, 1.00e18);
        
        vm.prank(admin);
        // Stork uses single contract address with different feed IDs
        storkOracle.updatePriceFeeds(
            address(newFeed),  // Stork contract address (same for both feeds)
            EUR_USD_FEED_ID,
            USDC_USD_FEED_ID
        );
        
        assertEq(address(storkOracle.eurUsdPriceFeed()), address(newFeed));
        assertEq(address(storkOracle.usdcUsdPriceFeed()), address(newFeed));
    }
    
    /**
     * @notice Tests that oracle health status is returned correctly
     * @dev Verifies getOracleHealth returns health status for both feeds
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - test function
     * @custom:oracle Queries health status from Stork feeds
     */
    function test_GetOracleHealth() public view {
        (bool isHealthy, bool eurUsdFresh, bool usdcUsdFresh) = storkOracle.getOracleHealth();
        assertTrue(isHealthy);
        assertTrue(eurUsdFresh);
        assertTrue(usdcUsdFresh);
    }
    
    /**
     * @notice Tests that oracle can be paused
     * @dev Verifies pause functionality prevents price queries
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
        storkOracle.pause();
        
        assertTrue(storkOracle.paused());
        
        (, bool isValid) = storkOracle.getEurUsdPrice();
        assertFalse(isValid);
    }
    
    /**
     * @notice Tests that oracle can be unpaused
     * @dev Verifies unpause functionality restores price queries
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
        storkOracle.pause();
        
        vm.prank(admin);
        storkOracle.unpause();
        
        assertFalse(storkOracle.paused());
    }
    
    /**
     * @notice Tests that ETH can be recovered to treasury
     * @dev Verifies recoverETH transfers ETH from oracle to treasury
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Transfers ETH from oracle to treasury
     * @custom:events Emits ETH recovery events
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test function
     * @custom:access Restricted to admin role
     * @custom:oracle No oracle dependency
     */
    function test_RecoverETH() public {
        vm.deal(address(storkOracle), 1 ether);
        
        uint256 balanceBefore = treasury.balance;
        
        vm.prank(admin);
        storkOracle.recoverETH();
        
        assertEq(treasury.balance, balanceBefore + 1 ether);
    }
    
    /**
     * @notice Tests that non-admin cannot update price bounds
     * @dev Verifies access control prevents unauthorized price bound updates
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Attempts unauthorized price bound update
     * @custom:events No events emitted
     * @custom:errors Expects revert on unauthorized access
     * @custom:reentrancy Not protected - test function
     * @custom:access Restricted to admin role
     * @custom:oracle No oracle dependency
     */
    function test_Revert_NonAdminCannotSwitchOracle() public {
        vm.prank(user);
        vm.expectRevert();
        storkOracle.updatePriceBounds(0.90e18, 1.30e18);
    }
    
    /**
     * @notice Tests that invalid price bounds (min > max) are rejected
     * @dev Verifies updatePriceBounds reverts when min price exceeds max price
     * @custom:security No security implications - test function
     * @custom:validation No validation - test function
     * @custom:state-changes Attempts to set invalid price bounds
     * @custom:events No events emitted
     * @custom:errors Expects revert on invalid bounds
     * @custom:reentrancy Not protected - test function
     * @custom:access Restricted to admin role
     * @custom:oracle No oracle dependency
     */
    function test_Revert_InvalidPriceBounds() public {
        vm.prank(admin);
        vm.expectRevert();
        storkOracle.updatePriceBounds(1.50e18, 1.00e18); // min > max
    }
    
    event CircuitBreakerTriggered(uint256 attemptedPrice, uint256 lastValidPrice, string indexed reason);
}

