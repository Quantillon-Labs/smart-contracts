// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// Import the common oracle interface
import {IOracle} from "./IOracle.sol";

/**
 * @title IChainlinkOracle
 * @notice Interface for the Quantillon Chainlink-based oracle
 * @dev Extends IOracle with Chainlink-specific functions
 *      This interface is specific to ChainlinkOracle implementation
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
interface IChainlinkOracle is IOracle {
    /**
     * @notice Initializes the oracle with admin and feed addresses
     * @dev Sets up the oracle with initial configuration and assigns roles to admin
     * @param admin Address that receives admin and manager roles
     * @param _eurUsdPriceFeed Chainlink EUR/USD feed address
     * @param _usdcUsdPriceFeed Chainlink USDC/USD feed address
     * @param _treasury Treasury address
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function initialize(address admin, address _eurUsdPriceFeed, address _usdcUsdPriceFeed, address _treasury) external;

    // All read functions are inherited from IOracle

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
    function recoverToken(address token, uint256 amount) external;

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
