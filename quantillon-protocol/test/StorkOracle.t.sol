// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {StorkOracle} from "../src/oracle/StorkOracle.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";

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
    
    function setPrice(int256 /* _price */) external {
        // Set price for all feed IDs (for backward compatibility)
        updatedAt = block.timestamp;
        // Note: This is kept for backward compatibility but setPriceForFeed should be used
    }
    
    function setPriceForFeed(bytes32 feedId, int256 _price) external {
        prices[feedId] = _price;
        // Don't update timestamp here - use setUpdatedAtForFeed to control timestamp separately
        // Only update if timestamp not already set for this feed
        if (timestamps[feedId] == 0) {
            timestamps[feedId] = block.timestamp;
        }
    }
    
    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }
    
    function setUpdatedAt(uint256 _updatedAt) external {
        updatedAt = _updatedAt;
        // Update all feed timestamps
    }
    
    function setUpdatedAtForFeed(bytes32 feedId, uint256 _updatedAt) external {
        timestamps[feedId] = _updatedAt;
        // Don't update updatedAt here to avoid conflicts
    }
    
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
    
    function test_Initialization() public view {
        assertEq(storkOracle.hasRole(storkOracle.DEFAULT_ADMIN_ROLE(), admin), true);
        assertEq(storkOracle.hasRole(storkOracle.ORACLE_MANAGER_ROLE(), admin), true);
        assertEq(storkOracle.hasRole(storkOracle.EMERGENCY_ROLE(), admin), true);
        assertEq(address(storkOracle.eurUsdPriceFeed()), address(eurUsdFeed));
        assertEq(address(storkOracle.usdcUsdPriceFeed()), address(usdcUsdFeed));
        assertEq(storkOracle.treasury(), treasury);
    }
    
    function test_GetEurUsdPrice() public view {
        (uint256 price, bool isValid) = storkOracle.getEurUsdPrice();
        assertGt(price, 0);
        assertTrue(isValid);
        // Price is already in 18 decimals (Stork uses 18 decimals)
        assertApproxEqRel(price, 1.08e18, 0.01e18);
    }
    
    function test_GetUsdcUsdPrice() public view {
        (uint256 price, bool isValid) = storkOracle.getUsdcUsdPrice();
        assertGt(price, 0);
        assertTrue(isValid);
        // Price is already in 18 decimals (Stork uses 18 decimals)
        assertApproxEqRel(price, 1.00e18, 0.01e18);
    }
    
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
    
    function test_CircuitBreaker() public {
        vm.prank(admin);
        // triggerCircuitBreaker doesn't emit CircuitBreakerTriggered event - it just sets the flag
        // The event is emitted in _updatePrices when validation fails
        storkOracle.triggerCircuitBreaker();
        
        assertTrue(storkOracle.circuitBreakerTriggered());
        
        (, bool isValid) = storkOracle.getEurUsdPrice();
        assertFalse(isValid);
    }
    
    function test_ResetCircuitBreaker() public {
        vm.prank(admin);
        storkOracle.triggerCircuitBreaker();
        
        vm.prank(admin);
        storkOracle.resetCircuitBreaker();
        
        assertFalse(storkOracle.circuitBreakerTriggered());
    }
    
    function test_UpdatePriceBounds() public {
        vm.prank(admin);
        storkOracle.updatePriceBounds(0.90e18, 1.30e18);
        
        (uint256 minPrice, uint256 maxPrice,,,) = storkOracle.getOracleConfig();
        assertEq(minPrice, 0.90e18);
        assertEq(maxPrice, 1.30e18);
    }
    
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
    
    function test_GetOracleHealth() public view {
        (bool isHealthy, bool eurUsdFresh, bool usdcUsdFresh) = storkOracle.getOracleHealth();
        assertTrue(isHealthy);
        assertTrue(eurUsdFresh);
        assertTrue(usdcUsdFresh);
    }
    
    function test_Pause() public {
        vm.prank(admin);
        storkOracle.pause();
        
        assertTrue(storkOracle.paused());
        
        (, bool isValid) = storkOracle.getEurUsdPrice();
        assertFalse(isValid);
    }
    
    function test_Unpause() public {
        vm.prank(admin);
        storkOracle.pause();
        
        vm.prank(admin);
        storkOracle.unpause();
        
        assertFalse(storkOracle.paused());
    }
    
    function test_RecoverETH() public {
        vm.deal(address(storkOracle), 1 ether);
        
        uint256 balanceBefore = treasury.balance;
        
        vm.prank(admin);
        storkOracle.recoverETH();
        
        assertEq(treasury.balance, balanceBefore + 1 ether);
    }
    
    function test_Revert_NonAdminCannotSwitchOracle() public {
        vm.prank(user);
        vm.expectRevert();
        storkOracle.updatePriceBounds(0.90e18, 1.30e18);
    }
    
    function test_Revert_InvalidPriceBounds() public {
        vm.prank(admin);
        vm.expectRevert();
        storkOracle.updatePriceBounds(1.50e18, 1.00e18); // min > max
    }
    
    event CircuitBreakerTriggered(uint256 attemptedPrice, uint256 lastValidPrice, string indexed reason);
}

