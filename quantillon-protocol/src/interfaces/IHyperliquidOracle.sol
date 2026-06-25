// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// Import the common oracle interface
import {IOracle} from "./IOracle.sol";

/**
 * @title IHyperliquidOracle
 * @notice Interface for the Quantillon Hyperliquid EUR/USD oracle adapter
 * @dev Extends IOracle with the management functions the OracleRouter delegates to the
 *      active oracle (updatePriceBounds / updateUsdcTolerance / resetCircuitBreaker /
 *      triggerCircuitBreaker) plus adapter-specific configuration. The EUR/USD price is the
 *      Hyperliquid xyz:EUR perp mid published on-chain by the off-chain Slippage Monitor into
 *      SlippageStorage; USDC/USD validation is delegated to the existing ChainlinkOracle.
 *
 *      The OracleRouter stores the active oracle as `IStorkOracle` and casts it unchecked, so an
 *      implementation only needs to expose the IOracle reads plus the four delegated management
 *      selectors above to slot into the Stork position via updateOracleAddresses + switchOracle.
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
interface IHyperliquidOracle is IOracle {
    /**
     * @notice Initializes the adapter with its price sources and treasury
     * @dev Callable once via the proxy. Grants admin/manager/emergency/upgrader roles to `admin`.
     * @param admin Address that receives admin and management roles
     * @param _slippageStorage SlippageStorage contract that holds the published Hyperliquid mid
     * @param _sourceId Slippage source id to read (SOURCE_HYPERLIQUID = 1)
     * @param _usdcSource Oracle providing USDC/USD (the existing ChainlinkOracle)
     * @param _treasury Treasury address for ETH/token recovery
     * @custom:security Validates all addresses are non-zero and grants roles to admin
     * @custom:validation Validates admin/_slippageStorage/_usdcSource/_treasury != address(0)
     * @custom:state-changes Initializes sources, roles, default bounds, staleness and tolerance
     * @custom:events Emits PriceUpdated if an initial mid is available
     * @custom:errors Reverts if any address is zero
     * @custom:reentrancy Protected by initializer modifier
     * @custom:access Public - only callable once during proxy deployment
     * @custom:oracle Reads the initial mid from SlippageStorage if present
     */
    function initialize(
        address admin,
        address _slippageStorage,
        uint8 _sourceId,
        address _usdcSource,
        address _treasury
    ) external;

    // ---- Management functions delegated by the OracleRouter ----

    /// @notice Updates EUR/USD min and max acceptable prices (18 decimals). ORACLE_MANAGER_ROLE.
    function updatePriceBounds(uint256 _minPrice, uint256 _maxPrice) external;

    /// @notice Updates the reported USDC tolerance in basis points. ORACLE_MANAGER_ROLE.
    function updateUsdcTolerance(uint256 newToleranceBps) external;

    /// @notice Clears the circuit breaker and attempts to re-seed the price. ORACLE_MANAGER_ROLE.
    function resetCircuitBreaker() external;

    /// @notice Manually triggers the circuit breaker (use last valid price). ORACLE_MANAGER_ROLE.
    function triggerCircuitBreaker() external;

    // ---- Adapter-specific configuration ----

    /// @notice Updates the maximum accepted staleness (seconds) of the published mid. ORACLE_MANAGER_ROLE.
    function setMaxPriceStaleness(uint256 newMaxStaleness) external;

    /// @notice Updates the SlippageStorage source contract and source id. ORACLE_MANAGER_ROLE.
    function updateSlippageSource(address _slippageStorage, uint8 _sourceId) external;

    /// @notice Updates the USDC/USD source oracle (ChainlinkOracle). ORACLE_MANAGER_ROLE.
    function updateUsdcSource(address _usdcSource) external;

    /// @notice Updates the treasury address. DEFAULT_ADMIN_ROLE.
    function updateTreasury(address _treasury) external;

    // ---- Emergency ----

    /// @notice Pauses oracle reads. EMERGENCY_ROLE.
    function pause() external;

    /// @notice Unpauses oracle reads. EMERGENCY_ROLE.
    function unpause() external;

    /// @notice Recovers ERC20 tokens to treasury. DEFAULT_ADMIN_ROLE.
    function recoverToken(address token, uint256 amount) external;

    /// @notice Recovers ETH to treasury. DEFAULT_ADMIN_ROLE.
    function recoverETH() external;
}
