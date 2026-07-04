// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IMarketOracleAdmin
 * @notice Minimal admin surface shared by every oracle that can occupy the router's
 *         MARKET slot (slot 1)
 *
 * @dev The OracleRouter delegates manager operations to the active oracle. Slot-1
 *      implementations (StorkOracle historically, HyperliquidEurUsdOracle currently)
 *      all expose these four selectors with identical signatures; this interface lets
 *      the router address them without coupling to a concrete implementation name.
 *
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
interface IMarketOracleAdmin {
    /**
     * @notice Updates EUR/USD min and max acceptable prices
     * @dev Implementation-defined validation; caller is the router (ORACLE_MANAGER_ROLE)
     * @param _minPrice New minimum price (18 decimals)
     * @param _maxPrice New maximum price (18 decimals)
     * @custom:security Restricted by the implementing oracle's access control
     * @custom:validation Via implementing oracle
     * @custom:state-changes Oracle price bounds
     * @custom:events Via implementing oracle
     * @custom:errors Via implementing oracle
     * @custom:reentrancy No reentrancy protection required at interface level
     * @custom:access Implementation-defined (ORACLE_MANAGER_ROLE expected)
     * @custom:oracle Configures the implementing oracle
     */
    function updatePriceBounds(uint256 _minPrice, uint256 _maxPrice) external;

    /**
     * @notice Updates the allowed USDC deviation from $1.00 in basis points
     * @dev Implementation-defined validation; caller is the router (ORACLE_MANAGER_ROLE)
     * @param newToleranceBps New tolerance (e.g., 200 = 2%)
     * @custom:security Restricted by the implementing oracle's access control
     * @custom:validation Via implementing oracle
     * @custom:state-changes Oracle USDC tolerance
     * @custom:events Via implementing oracle
     * @custom:errors Via implementing oracle
     * @custom:reentrancy No reentrancy protection required at interface level
     * @custom:access Implementation-defined (ORACLE_MANAGER_ROLE expected)
     * @custom:oracle Configures the implementing oracle
     */
    function updateUsdcTolerance(uint256 newToleranceBps) external;

    /**
     * @notice Clears the circuit breaker and attempts to resume live prices
     * @dev Implementation-defined validation; caller is the router (ORACLE_MANAGER_ROLE)
     * @custom:security Restricted by the implementing oracle's access control
     * @custom:validation Via implementing oracle
     * @custom:state-changes Oracle circuit-breaker state
     * @custom:events Via implementing oracle
     * @custom:errors Via implementing oracle
     * @custom:reentrancy No reentrancy protection required at interface level
     * @custom:access Implementation-defined
     * @custom:oracle Configures the implementing oracle
     */
    function resetCircuitBreaker() external;

    /**
     * @notice Manually triggers the circuit breaker to use fallback prices
     * @dev Implementation-defined validation; caller is the router (ORACLE_MANAGER_ROLE)
     * @custom:security Restricted by the implementing oracle's access control
     * @custom:validation Via implementing oracle
     * @custom:state-changes Oracle circuit-breaker state
     * @custom:events Via implementing oracle
     * @custom:errors Via implementing oracle
     * @custom:reentrancy No reentrancy protection required at interface level
     * @custom:access Implementation-defined
     * @custom:oracle Configures the implementing oracle
     */
    function triggerCircuitBreaker() external;
}
