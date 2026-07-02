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

    /**
     * @notice Updates EUR/USD min and max acceptable prices (18 decimals)
     * @dev The bounds gate the validation path; both must be nonzero with min below max.
     * @param _minPrice Minimum accepted EUR/USD price (18 decimals)
     * @param _maxPrice Maximum accepted EUR/USD price (18 decimals)
     * @custom:security Misconfigured bounds can force fallback pricing
     * @custom:validation Reverts unless 0 < _minPrice < _maxPrice
     * @custom:events Emits a bounds-updated event in the implementation
     * @custom:errors Reverts on invalid bounds
     * @custom:reentrancy No external calls
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:state-changes Updates minEurUsdPrice / maxEurUsdPrice
     * @custom:oracle Affects EUR/USD validation only
     */
    function updatePriceBounds(uint256 _minPrice, uint256 _maxPrice) external;

    /**
     * @notice Updates the reported USDC tolerance in basis points
     * @dev Reported via getOracleConfig only — USDC validation itself is delegated to the USDC source.
     * @param newToleranceBps New tolerance in basis points
     * @custom:security Reporting-only; does not change validation behavior
     * @custom:validation Bounded by the implementation's tolerance cap
     * @custom:events Emits a tolerance-updated event in the implementation
     * @custom:errors Reverts when above the cap
     * @custom:reentrancy No external calls
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:state-changes Updates the stored tolerance
     * @custom:oracle No effect on price reads
     */
    function updateUsdcTolerance(uint256 newToleranceBps) external;

    /**
     * @notice Clears the circuit breaker and attempts to re-seed the price
     * @dev Re-seeds the deviation baseline from the current published mid when it is valid.
     * @custom:security Re-enables live pricing after an incident review
     * @custom:validation None beyond role check
     * @custom:events Emits a breaker-reset event in the implementation
     * @custom:errors None
     * @custom:reentrancy Reads SlippageStorage
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:state-changes Clears circuitBreakerTriggered; may update the baseline
     * @custom:oracle Reads the published mid to re-seed
     */
    function resetCircuitBreaker() external;

    /**
     * @notice Manually triggers the circuit breaker (use last valid price)
     * @dev Forces reads onto the last valid price with isValid=false until reset.
     * @custom:security Emergency lever to freeze pricing on a bad feed
     * @custom:validation None beyond role check
     * @custom:events Emits a breaker-triggered event in the implementation
     * @custom:errors None
     * @custom:reentrancy No external calls
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:state-changes Sets circuitBreakerTriggered
     * @custom:oracle Live reads are suspended until reset
     */
    function triggerCircuitBreaker() external;

    // ---- Adapter-specific configuration ----

    /**
     * @notice Updates the maximum accepted staleness (seconds) of the published mid
     * @dev Gates the timestamp validation; capped by the implementation's hard maximum.
     * @param newMaxStaleness New staleness window in seconds
     * @custom:security Too-large windows accept outdated prices
     * @custom:validation Reverts above the hard cap
     * @custom:events Emits a staleness-updated event in the implementation
     * @custom:errors Reverts on zero or above-cap values
     * @custom:reentrancy No external calls
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:state-changes Updates the staleness window
     * @custom:oracle Affects freshness validation of the published mid
     */
    function setMaxPriceStaleness(uint256 newMaxStaleness) external;

    /**
     * @notice Updates the SlippageStorage source contract and source id
     * @dev Points the adapter at a new SlippageStorage deployment and/or source id.
     * @param _slippageStorage New SlippageStorage contract address
     * @param _sourceId New slippage source id to read
     * @custom:security The new source becomes the EUR/USD price authority
     * @custom:validation Reverts on zero address
     * @custom:events Emits a source-updated event in the implementation
     * @custom:errors Reverts on zero address
     * @custom:reentrancy No external calls
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:state-changes Updates slippageStorage and sourceId
     * @custom:oracle Changes where the EUR/USD mid is read from
     */
    function updateSlippageSource(address _slippageStorage, uint8 _sourceId) external;

    /**
     * @notice Updates the USDC/USD source oracle (ChainlinkOracle)
     * @dev Swaps the delegated USDC/USD oracle.
     * @param _usdcSource New USDC/USD oracle address
     * @custom:security The new source becomes the USDC/USD validation authority
     * @custom:validation Reverts on zero address
     * @custom:events Emits a source-updated event in the implementation
     * @custom:errors Reverts on zero address
     * @custom:reentrancy No external calls
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:state-changes Updates usdcSource
     * @custom:oracle Changes the delegated USDC/USD feed
     */
    function updateUsdcSource(address _usdcSource) external;

    /**
     * @notice Updates the treasury address
     * @dev The treasury receives recovered tokens/ETH from the recovery functions.
     * @param _treasury New treasury address
     * @custom:security Recovery destination changes with this address
     * @custom:validation Reverts on zero address
     * @custom:events Emits TreasuryUpdated
     * @custom:errors Reverts on zero address
     * @custom:reentrancy No external calls
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:state-changes Updates treasury
     * @custom:oracle No oracle dependency
     */
    function updateTreasury(address _treasury) external;

    // ---- Emergency ----

    /**
     * @notice Pauses oracle reads
     * @dev While paused, price reads return the last valid price with isValid=false.
     * @custom:security Emergency stop for live pricing
     * @custom:validation None beyond role check
     * @custom:events Emits Paused
     * @custom:errors Reverts when already paused
     * @custom:reentrancy No external calls
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:state-changes Sets the paused flag
     * @custom:oracle Live reads suspended
     */
    function pause() external;

    /**
     * @notice Unpauses oracle reads
     * @dev Re-enables live price reads.
     * @custom:security Restores live pricing
     * @custom:validation None beyond role check
     * @custom:events Emits Unpaused
     * @custom:errors Reverts when not paused
     * @custom:reentrancy No external calls
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:state-changes Clears the paused flag
     * @custom:oracle Live reads resume
     */
    function unpause() external;

    /**
     * @notice Recovers ERC20 tokens to treasury
     * @dev Routed through TreasuryRecoveryLibrary; funds always go to the treasury.
     * @param token Token contract address to recover
     * @param amount Amount of tokens to recover
     * @custom:security Funds can only reach the configured treasury
     * @custom:validation Validated by TreasuryRecoveryLibrary
     * @custom:events Emits a recovery event in the implementation
     * @custom:errors Reverts on invalid token or amount
     * @custom:reentrancy Token transfer to the treasury
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:state-changes Transfers the token balance
     * @custom:oracle No oracle dependency
     */
    function recoverToken(address token, uint256 amount) external;

    /**
     * @notice Recovers ETH to treasury
     * @dev Routed through TreasuryRecoveryLibrary; funds always go to the treasury.
     * @custom:security Funds can only reach the configured treasury
     * @custom:validation Validated by TreasuryRecoveryLibrary
     * @custom:events Emits a recovery event in the implementation
     * @custom:errors Reverts when there is no ETH balance
     * @custom:reentrancy ETH send to the treasury
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:state-changes Transfers the ETH balance
     * @custom:oracle No oracle dependency
     */
    function recoverETH() external;
}
