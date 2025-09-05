// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IChainlinkOracle
 * @notice Interface for the Quantillon Chainlink-based oracle
 * @dev Exposes read methods for prices and health, plus admin/emergency controls
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
interface IChainlinkOracle {
    /**
     * @notice Initializes the oracle with admin and feed addresses
     * @param admin Address that receives admin and manager roles
     * @param _eurUsdPriceFeed Chainlink EUR/USD feed address
     * @param _usdcUsdPriceFeed Chainlink USDC/USD feed address
     */
    function initialize(address admin, address _eurUsdPriceFeed, address _usdcUsdPriceFeed) external;

    /**
     * @notice Gets the current EUR/USD price with validation
     * @return price EUR/USD price in 18 decimals
     * @return isValid True if fresh and within acceptable bounds
     * @custom:security Validates timestamp freshness, circuit breaker status, price bounds
     * @custom:validation Checks price > 0, timestamp < 1 hour old, within min/max bounds
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - returns fallback price if invalid
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle Requires fresh Chainlink EUR/USD price feed data
     */
    function getEurUsdPrice() external view returns (uint256 price, bool isValid);

    /**
     * @notice Gets the current USDC/USD price with validation
     * @return price USDC/USD price in 18 decimals (should be ~1e18)
     * @return isValid True if fresh and within tolerance
     */
    function getUsdcUsdPrice() external view returns (uint256 price, bool isValid);

    /**
     * @notice Returns overall oracle health signals
     * @return isHealthy True if both feeds are fresh, circuit breaker is off, and not paused
     * @return eurUsdFresh True if EUR/USD feed is fresh
     * @return usdcUsdFresh True if USDC/USD feed is fresh
     */
    function getOracleHealth() external view returns (bool isHealthy, bool eurUsdFresh, bool usdcUsdFresh);

    /**
     * @notice Detailed information about the EUR/USD price
     * @return currentPrice Current price (may be fallback)
     * @return lastValidPrice Last validated price stored
     * @return lastUpdate Timestamp of last successful update
     * @return isStale True if the feed data is stale
     * @return withinBounds True if within configured min/max bounds
     */
    function getEurUsdDetails() external view returns (
        uint256 currentPrice,
        uint256 lastValidPrice,
        uint256 lastUpdate,
        bool isStale,
        bool withinBounds
    );

    /**
     * @notice Current configuration and circuit breaker state
     * @return minPrice Minimum accepted EUR/USD price
     * @return maxPrice Maximum accepted EUR/USD price
     * @return maxStaleness Maximum allowed staleness in seconds
     * @return usdcTolerance USDC tolerance in basis points
     * @return circuitBreakerActive True if circuit breaker is triggered
     */
    function getOracleConfig() external view returns (
        uint256 minPrice,
        uint256 maxPrice,
        uint256 maxStaleness,
        uint256 usdcTolerance,
        bool circuitBreakerActive
    );

    /**
     * @notice Addresses and decimals of the underlying feeds
     * @return eurUsdFeedAddress EUR/USD feed address
     * @return usdcUsdFeedAddress USDC/USD feed address
     * @return eurUsdDecimals EUR/USD feed decimals
     * @return usdcUsdDecimals USDC/USD feed decimals
     */
    function getPriceFeedAddresses() external view returns (
        address eurUsdFeedAddress,
        address usdcUsdFeedAddress,
        uint8 eurUsdDecimals,
        uint8 usdcUsdDecimals
    );

    /**
     * @notice Connectivity check for both feeds
     * @return eurUsdConnected True if EUR/USD feed responds
     * @return usdcUsdConnected True if USDC/USD feed responds
     * @return eurUsdLatestRound Latest round ID for EUR/USD
     * @return usdcUsdLatestRound Latest round ID for USDC/USD
     */
    function checkPriceFeedConnectivity() external view returns (
        bool eurUsdConnected,
        bool usdcUsdConnected,
        uint80 eurUsdLatestRound,
        uint80 usdcUsdLatestRound
    );

    /**
     * @notice Updates EUR/USD min and max acceptable prices
     * @param _minPrice New minimum price (18 decimals)
     * @param _maxPrice New maximum price (18 decimals)
     */
    function updatePriceBounds(uint256 _minPrice, uint256 _maxPrice) external;

    /**
     * @notice Updates the allowed USDC deviation from $1.00 in basis points
     * @param newToleranceBps New tolerance (e.g., 200 = 2%)
     */
    function updateUsdcTolerance(uint256 newToleranceBps) external;

    /**
     * @notice Updates Chainlink feed addresses
     * @param _eurUsdFeed New EUR/USD feed
     * @param _usdcUsdFeed New USDC/USD feed
     */
    function updatePriceFeeds(address _eurUsdFeed, address _usdcUsdFeed) external;

    /**
     * @notice Clears circuit breaker and attempts to resume live prices
     */
    function resetCircuitBreaker() external;

    /**
     * @notice Manually triggers circuit breaker to use fallback prices
     */
    function triggerCircuitBreaker() external;

    /**
     * @notice Pauses all oracle operations
     */
    function pause() external;

    /**
     * @notice Unpauses oracle operations
     */
    function unpause() external;

    /**
     * @notice Recovers ERC20 tokens sent to the oracle contract by mistake
     * @param token Token address to recover
     * @param to Recipient address
     * @param amount Amount to transfer
     */
    function recoverToken(address token, address to, uint256 amount) external;

    /**
     * @notice Recovers ETH sent to the oracle contract by mistake
     */
    function recoverETH() external;
}
