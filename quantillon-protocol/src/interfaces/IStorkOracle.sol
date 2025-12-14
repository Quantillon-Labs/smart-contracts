// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// Import the common oracle interface
import {IOracle} from "./IOracle.sol";

/**
 * @title IStorkOracle
 * @notice Interface for the Quantillon Stork-based oracle
 * @dev Extends IOracle with Stork-specific functions
 *      This interface is specific to StorkOracle implementation
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
interface IStorkOracle is IOracle {
    /**
     * @notice Initializes the oracle with admin and Stork feed addresses
     * @dev Sets up the oracle with initial configuration and assigns roles to admin
     * @param admin Address that receives admin and manager roles
     * @param _storkFeedAddress Stork feed contract address
     * @param _eurUsdFeedId Stork EUR/USD feed ID (bytes32)
     * @param _usdcUsdFeedId Stork USDC/USD feed ID (bytes32)
     * @param _treasury Treasury address
     * @custom:security Validates all addresses are non-zero, grants admin roles
     * @custom:validation Validates all input addresses are not address(0)
     * @custom:state-changes Initializes all state variables, sets default price bounds
     * @custom:events Emits PriceUpdated during initial price update
     * @custom:errors Throws "Oracle: Admin cannot be zero" if admin is address(0)
     * @custom:reentrancy Protected by initializer modifier
     * @custom:access Public - only callable once during deployment
     * @custom:oracle Initializes Stork price feed interfaces
     */
    function initialize(
        address admin,
        address _storkFeedAddress,
        bytes32 _eurUsdFeedId,
        bytes32 _usdcUsdFeedId,
        address _treasury
    ) external;

    // All read functions are inherited from IOracle

    /**
     * @notice Updates EUR/USD min and max acceptable prices
     * @dev Updates the price bounds for EUR/USD validation with security checks
     * @param _minPrice New minimum price (18 decimals)
     * @param _maxPrice New maximum price (18 decimals)
     * @custom:security Validates min < max and reasonable bounds
     * @custom:validation Validates price bounds are within acceptable range
     * @custom:state-changes Updates minPrice and maxPrice state variables
     * @custom:events Emits PriceBoundsUpdated event
     * @custom:errors Throws if minPrice >= maxPrice or invalid bounds
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:oracle No oracle dependency - configuration update only
     */
    function updatePriceBounds(uint256 _minPrice, uint256 _maxPrice) external;

    /**
     * @notice Updates the allowed USDC deviation from $1.00 in basis points
     * @dev Updates the USDC price tolerance for validation with security checks
     * @param newToleranceBps New tolerance (e.g., 200 = 2%)
     * @custom:security Validates tolerance is within reasonable limits
     * @custom:validation Validates tolerance is not zero and within max bounds
     * @custom:state-changes Updates usdcTolerance state variable
     * @custom:events Emits UsdcToleranceUpdated event
     * @custom:errors Throws if tolerance is invalid or out of bounds
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:oracle No oracle dependency - configuration update only
     */
    function updateUsdcTolerance(uint256 newToleranceBps) external;

    /**
     * @notice Updates Stork feed addresses and feed IDs
     * @dev Updates the addresses and feed IDs of both Stork price feeds with validation
     * @param _storkFeedAddress New Stork feed contract address
     * @param _eurUsdFeedId New EUR/USD feed ID
     * @param _usdcUsdFeedId New USDC/USD feed ID
     * @custom:security Validates feed address is non-zero and contract exists
     * @custom:validation Validates all addresses are not address(0)
     * @custom:state-changes Updates eurUsdPriceFeed, usdcUsdPriceFeed, and feed IDs
     * @custom:events Emits PriceFeedsUpdated event
     * @custom:errors Throws if feed address is zero or invalid
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:oracle Updates Stork feed contract references
     */
    function updatePriceFeeds(address _storkFeedAddress, bytes32 _eurUsdFeedId, bytes32 _usdcUsdFeedId) external;

    /**
     * @notice Clears circuit breaker and attempts to resume live prices
     * @dev Resets the circuit breaker state to allow normal price operations
     * @custom:security Resets circuit breaker after manual intervention
     * @custom:validation Validates circuit breaker was previously triggered
     * @custom:state-changes Resets circuitBreakerTriggered flag
     * @custom:events Emits CircuitBreakerReset event
     * @custom:errors No errors thrown
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:oracle Resumes normal oracle price queries
     */
    function resetCircuitBreaker() external;

    /**
     * @notice Manually triggers circuit breaker to use fallback prices
     * @dev Activates circuit breaker to switch to fallback price mode for safety
     * @custom:security Manually activates circuit breaker for emergency situations
     * @custom:validation No validation - emergency function
     * @custom:state-changes Sets circuitBreakerTriggered flag to true
     * @custom:events Emits CircuitBreakerTriggered event
     * @custom:errors No errors thrown
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:oracle Switches to fallback prices instead of live oracle queries
     */
    function triggerCircuitBreaker() external;

    /**
     * @notice Pauses all oracle operations
     * @dev Pauses the oracle contract to halt all price operations
     * @custom:security Emergency pause to halt all oracle operations
     * @custom:validation No validation - emergency function
     * @custom:state-changes Sets paused state to true
     * @custom:events Emits Paused event
     * @custom:errors No errors thrown
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle Halts all oracle price queries
     */
    function pause() external;

    /**
     * @notice Unpauses oracle operations
     * @dev Resumes oracle operations after being paused
     * @custom:security Resumes oracle operations after pause
     * @custom:validation Validates contract was previously paused
     * @custom:state-changes Sets paused state to false
     * @custom:events Emits Unpaused event
     * @custom:errors No errors thrown
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle Resumes normal oracle price queries
     */
    function unpause() external;

    /**
     * @notice Recovers ERC20 tokens sent to the oracle contract by mistake
     * @dev Allows recovery of ERC20 tokens accidentally sent to the oracle contract
     * @param token Token address to recover
     * @param amount Amount to transfer
     * @custom:security Transfers tokens to treasury, prevents accidental loss
     * @custom:validation Validates token and amount are non-zero
     * @custom:state-changes Transfers tokens from contract to treasury
     * @custom:events Emits TokenRecovered event
     * @custom:errors Throws if token is zero address or transfer fails
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependency
     */
    function recoverToken(address token, uint256 amount) external;

    /**
     * @notice Recovers ETH sent to the oracle contract by mistake
     * @dev Allows recovery of ETH accidentally sent to the oracle contract
     * @custom:security Transfers ETH to treasury, prevents accidental loss
     * @custom:validation Validates contract has ETH balance
     * @custom:state-changes Transfers ETH from contract to treasury
     * @custom:events Emits ETHRecovered event
     * @custom:errors Throws if transfer fails
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependency
     */
    function recoverETH() external;
}

