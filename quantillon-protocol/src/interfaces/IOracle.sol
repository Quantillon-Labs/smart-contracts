// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IOracle
 * @notice Generic interface for Quantillon Protocol oracle contracts
 * @dev This interface is oracle-agnostic and can work with Chainlink, Stork, or any other oracle implementation
 *      The OracleRouter implements this interface and delegates to the active oracle (Chainlink or Stork)
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
interface IOracle {
    /**
     * @notice Gets the current EUR/USD price with validation
     * @dev Retrieves and validates EUR/USD price from the active oracle with freshness checks
     * @return price EUR/USD price in 18 decimals
     * @return isValid True if fresh and within acceptable bounds
     * @custom:security Validates price freshness and bounds before returning
     * @custom:validation Checks price staleness and circuit breaker state
     * @custom:state-changes May update lastValidPrice if price is valid
     * @custom:events No events emitted
     * @custom:errors No errors thrown, returns isValid=false for invalid prices
     * @custom:reentrancy Not protected - read-only operation
     * @custom:access Public - no access restrictions
     * @custom:oracle Queries active oracle (Chainlink or Stork) for EUR/USD price
     */
    function getEurUsdPrice() external returns (uint256 price, bool isValid);

    /**
     * @notice Gets the current USDC/USD price with validation
     * @dev Retrieves and validates USDC/USD price from the active oracle with tolerance checks
     * @return price USDC/USD price in 18 decimals (should be ~1e18)
     * @return isValid True if fresh and within tolerance
     * @custom:security Validates price is within tolerance of $1.00
     * @custom:validation Checks price staleness and deviation from $1.00
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown, returns isValid=false for invalid prices
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle Queries active oracle (Chainlink or Stork) for USDC/USD price
     */
    function getUsdcUsdPrice() external view returns (uint256 price, bool isValid);

    /**
     * @notice Returns overall oracle health signals
     * @dev Checks the health status of both price feeds and overall oracle state
     * @return isHealthy True if both feeds are fresh, circuit breaker is off, and not paused
     * @return eurUsdFresh True if EUR/USD feed is fresh
     * @return usdcUsdFresh True if USDC/USD feed is fresh
     * @custom:security Provides health status for monitoring and circuit breaker decisions
     * @custom:validation Checks feed freshness, circuit breaker state, and pause status
     * @custom:state-changes May update internal state during health check
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - read-only operation
     * @custom:access Public - no access restrictions
     * @custom:oracle Queries active oracle health status for both feeds
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
     * @custom:security Provides detailed price information for debugging and monitoring
     * @custom:validation Checks price freshness and bounds validation
     * @custom:state-changes May update internal state during price check
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - read-only operation
     * @custom:access Public - no access restrictions
     * @custom:oracle Queries active oracle for detailed EUR/USD price information
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
     * @custom:security Returns configuration for security monitoring
     * @custom:validation No validation - read-only configuration
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle Returns configuration from active oracle
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
     * @dev Returns the addresses and decimal precision of both price feeds
     * @return eurUsdFeedAddress EUR/USD feed address
     * @return usdcUsdFeedAddress USDC/USD feed address
     * @return eurUsdDecimals EUR/USD feed decimals
     * @return usdcUsdDecimals USDC/USD feed decimals
     * @custom:security Returns feed addresses for verification
     * @custom:validation No validation - read-only information
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle Returns feed addresses from active oracle
     */
    function getPriceFeedAddresses() external view returns (
        address eurUsdFeedAddress,
        address usdcUsdFeedAddress,
        uint8 eurUsdDecimals,
        uint8 usdcUsdDecimals
    );

    /**
     * @notice Connectivity check for both feeds
     * @dev Tests connectivity to both price feeds and returns latest round information
     * @return eurUsdConnected True if EUR/USD feed responds
     * @return usdcUsdConnected True if USDC/USD feed responds
     * @return eurUsdLatestRound Latest round ID for EUR/USD (0 for non-round-based oracles)
     * @return usdcUsdLatestRound Latest round ID for USDC/USD (0 for non-round-based oracles)
     * @custom:security Tests feed connectivity for health monitoring
     * @custom:validation No validation - connectivity test only
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown, returns false for disconnected feeds
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle Tests connectivity to active oracle feeds
     */
    function checkPriceFeedConnectivity() external view returns (
        bool eurUsdConnected,
        bool usdcUsdConnected,
        uint80 eurUsdLatestRound,
        uint80 usdcUsdLatestRound
    );
}

