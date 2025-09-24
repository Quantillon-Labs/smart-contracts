// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IChainlinkOracle
 * @notice Interface for the Quantillon Chainlink-based oracle
 * @dev Exposes read methods for prices and health, plus admin/emergency controls
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
interface IChainlinkOracle {
    /**
     * @notice Initializes the oracle with admin and feed addresses
     * @dev Sets up the oracle with initial configuration and assigns roles to admin
     * @param admin Address that receives admin and manager roles
     * @param _eurUsdPriceFeed Chainlink EUR/USD feed address
     * @param _usdcUsdPriceFeed Chainlink USDC/USD feed address
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function initialize(address admin, address _eurUsdPriceFeed, address _usdcUsdPriceFeed) external;

    /**
     * @notice Gets the current EUR/USD price with validation
     * @dev Retrieves and validates EUR/USD price from Chainlink feed with freshness checks
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
    function getEurUsdPrice() external returns (uint256 price, bool isValid);

    /**
     * @notice Gets the current USDC/USD price with validation
     * @dev Retrieves and validates USDC/USD price from Chainlink feed with tolerance checks
     * @return price USDC/USD price in 18 decimals (should be ~1e18)
     * @return isValid True if fresh and within tolerance
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getUsdcUsdPrice() external view returns (uint256 price, bool isValid);

    /**
     * @notice Returns overall oracle health signals
     * @dev Checks the health status of both price feeds and overall oracle state
     * @return isHealthy True if both feeds are fresh, circuit breaker is off, and not paused
     * @return eurUsdFresh True if EUR/USD feed is fresh
     * @return usdcUsdFresh True if USDC/USD feed is fresh
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getOracleHealth() external returns (bool isHealthy, bool eurUsdFresh, bool usdcUsdFresh);

    /**
     * @notice Detailed information about the EUR/USD price
     * @dev Provides comprehensive EUR/USD price information including validation status
     * @return currentPrice Current price (may be fallback)
     * @return lastValidPrice Last validated price stored
     * @return lastUpdate Timestamp of last successful update
     * @return isStale True if the feed data is stale
     * @return withinBounds True if within configured min/max bounds
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getEurUsdDetails() external returns (
        uint256 currentPrice,
        uint256 lastValidPrice,
        uint256 lastUpdate,
        bool isStale,
        bool withinBounds
    );

    /**
     * @notice Current configuration and circuit breaker state
     * @dev Returns current oracle configuration parameters and circuit breaker status
     * @return minPrice Minimum accepted EUR/USD price
     * @return maxPrice Maximum accepted EUR/USD price
     * @return maxStaleness Maximum allowed staleness in seconds
     * @return usdcTolerance USDC tolerance in basis points
     * @return circuitBreakerActive True if circuit breaker is triggered
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
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
     * @dev Returns the addresses and decimal precision of both Chainlink price feeds
     * @return eurUsdFeedAddress EUR/USD feed address
     * @return usdcUsdFeedAddress USDC/USD feed address
     * @return eurUsdDecimals EUR/USD feed decimals
     * @return usdcUsdDecimals USDC/USD feed decimals
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getPriceFeedAddresses() external view returns (
        address eurUsdFeedAddress,
        address usdcUsdFeedAddress,
        uint8 eurUsdDecimals,
        uint8 usdcUsdDecimals
    );

    /**
     * @notice Connectivity check for both feeds
     * @dev Tests connectivity to both Chainlink price feeds and returns latest round information
     * @return eurUsdConnected True if EUR/USD feed responds
     * @return usdcUsdConnected True if USDC/USD feed responds
     * @return eurUsdLatestRound Latest round ID for EUR/USD
     * @return usdcUsdLatestRound Latest round ID for USDC/USD
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function checkPriceFeedConnectivity() external view returns (
        bool eurUsdConnected,
        bool usdcUsdConnected,
        uint80 eurUsdLatestRound,
        uint80 usdcUsdLatestRound
    );

    /**
     * @notice Updates EUR/USD min and max acceptable prices
     * @dev Updates the price bounds for EUR/USD validation with security checks
     * @param _minPrice New minimum price (18 decimals)
     * @param _maxPrice New maximum price (18 decimals)
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function updatePriceBounds(uint256 _minPrice, uint256 _maxPrice) external;

    /**
     * @notice Updates the allowed USDC deviation from $1.00 in basis points
     * @dev Updates the USDC price tolerance for validation with security checks
     * @param newToleranceBps New tolerance (e.g., 200 = 2%)
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function updateUsdcTolerance(uint256 newToleranceBps) external;

    /**
     * @notice Updates Chainlink feed addresses
     * @dev Updates the addresses of both Chainlink price feeds with validation
     * @param _eurUsdFeed New EUR/USD feed
     * @param _usdcUsdFeed New USDC/USD feed
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function updatePriceFeeds(address _eurUsdFeed, address _usdcUsdFeed) external;

    /**
     * @notice Clears circuit breaker and attempts to resume live prices
     * @dev Resets the circuit breaker state to allow normal price operations
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function resetCircuitBreaker() external;

    /**
     * @notice Manually triggers circuit breaker to use fallback prices
     * @dev Activates circuit breaker to switch to fallback price mode for safety
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function triggerCircuitBreaker() external;

    /**
     * @notice Pauses all oracle operations
     * @dev Pauses the oracle contract to halt all price operations
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function pause() external;

    /**
     * @notice Unpauses oracle operations
     * @dev Resumes oracle operations after being paused
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function unpause() external;

    /**
     * @notice Recovers ERC20 tokens sent to the oracle contract by mistake
     * @dev Allows recovery of ERC20 tokens accidentally sent to the oracle contract
     * @param token Token address to recover
     * @param to Recipient address
     * @param amount Amount to transfer
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function recoverToken(address token, address to, uint256 amount) external;

    /**
     * @notice Recovers ETH sent to the oracle contract by mistake
     * @dev Allows recovery of ETH accidentally sent to the oracle contract
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function recoverETH() external;
}
