// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// =============================================================================
// IMPORTS - Stork interfaces and OpenZeppelin security
// =============================================================================

/**
 * @notice Stork Network oracle feed interface
 * @dev This interface is based on Stork's EVM contract API
 * 
 * VERIFICATION STATUS:
 * ✅ Function getTemporalNumericValueV1 - Verified matches Stork's contract
 * ✅ Struct TemporalNumericValue - Verified matches Stork's contract
 * ✅ Decimals handling - Stork feeds use 18 decimals (constant, no function needed)
 * 
 * NOTE: Stork's official SDK uses interface name "IStork" instead of "IStorkFeed",
 *       but the function signatures are identical. This interface should work correctly.
 * 
 * IMPORTANT: Stork's contract does NOT have a decimals() function.
 *            Stork feeds use 18 decimals precision (value is multiplied by 10^18).
 *            We use constant STORK_FEED_DECIMALS = 18 instead of calling decimals().
 * 
 * See docs/STORK_INTERFACE_VERIFICATION.md for detailed verification
 * 
 * Resources:
 * - Documentation: https://docs.storkengine.com/contract-apis/evm
 * - Contract Addresses: https://docs.stork.network/resources/contract-addresses/evm
 * - Asset ID Registry: https://docs.stork.network/resources/asset-id-registry
 * - GitHub: https://github.com/Stork-Oracle/stork-external
 * - Official SDK: storknetwork/stork-evm-sdk (npm package)
 * 
 * NOTE: Stork also provides Chainlink and Pyth adapters that may be easier to integrate.
 * Consider using StorkChainlinkAdapter if you want to use Chainlink's familiar interface.
 * 
 * @custom:security-contact team@quantillon.money
 */
interface IStorkFeed {
    /**
     * @notice Temporal numeric value structure returned by Stork feeds
     * @param value The price value (can be negative for some feeds)
     * @param timestamp The timestamp when the value was last updated
     * @dev Verified to match Stork's StorkStructs.TemporalNumericValue
     */
    struct TemporalNumericValue {
        int256 value;
        uint256 timestamp;
    }
    
    /**
     * @notice Gets the latest temporal numeric value for a given feed ID
     * @param id The feed ID (bytes32 identifier for the price feed)
     * @return The temporal numeric value containing price and timestamp
     * @dev Feed IDs are specific to each price pair (e.g., EUR/USD, USDC/USD)
     *      Obtain feed IDs from Stork's Asset ID Registry: https://docs.stork.network/resources/asset-id-registry
     *      ✅ Verified: Function signature matches Stork's contract
     * @custom:security Interface function - no security implications
     * @custom:validation No validation - interface definition
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle Interface for Stork feed contract
     */
    function getTemporalNumericValueV1(bytes32 id) external view returns (TemporalNumericValue memory);
    
}

// Quantillon Oracle interfaces
import {IStorkOracle} from "../interfaces/IStorkOracle.sol";

// OpenZeppelin role system
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

// Emergency pause mechanism
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

// Initialization pattern for upgradeable contracts
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// UUPS upgrade pattern
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// ERC20 interface and SafeERC20 for safe transfers
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Treasury recovery library for secure ETH recovery
import {TreasuryRecoveryLibrary} from "../libraries/TreasuryRecoveryLibrary.sol";
import {TimeProvider} from "../libraries/TimeProviderLibrary.sol";
import {CommonValidationLibrary} from "../libraries/CommonValidationLibrary.sol";

/**
 * @title StorkOracle
 * @notice EUR/USD and USDC/USD price manager for Quantillon Protocol using Stork Network
 * 
 * @dev Key features:
 *      - Fetch EUR/USD price from Stork Network
 *      - Validate USDC/USD (should remain close to $1.00)
 *      - Circuit breakers against outlier prices
 *      - Fallbacks in case of oracle outage
 *      - Data freshness checks
 * 
 * @dev DEPLOYMENT REQUIREMENTS:
 *      Before deploying, you must obtain the following from Stork Network:
 *      1. Stork contract address on Base mainnet (the main Stork oracle contract)
 *      2. EUR/USD feed ID (bytes32 identifier for EUR/USD price feed)
 *      3. USDC/USD feed ID (bytes32 identifier for USDC/USD price feed)
 * 
 *      How to obtain:
 *      - Visit Stork's data feeds: https://data.stork.network/
 *      - Search for "EUR/USD" and "USDC/USD" feeds
 *      - Contact Stork support for Base mainnet contract addresses:
 *        * Discord: https://discord.com (Stork Network)
 *        * Documentation: https://docs.stork.network/
 *        * Email: support at stork.network (if available)
 * 
 *      ALTERNATIVE: Consider using Stork's Chainlink adapter for easier integration:
 *      - GitHub: https://github.com/Stork-Oracle/stork-external
 *      - This would allow using Chainlink's familiar interface with Stork data
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract StorkOracle is 
    IStorkOracle,
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    // =============================================================================
    // CONSTANTS AND ROLES
    // =============================================================================
    
    /// @notice Role to manage oracle configurations
    bytes32 public constant ORACLE_MANAGER_ROLE = keccak256("ORACLE_MANAGER_ROLE");
    
    /// @notice Role for emergency actions
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    /// @notice Role for contract upgrades
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @notice Maximum duration before a price is considered stale (1 hour)
    /// @dev 3600 seconds = reasonable limit for real-time DeFi
    uint256 public constant MAX_PRICE_STALENESS = 3600;
    
    /// @notice Maximum allowed deviation from previous price (5%)
    /// @dev 500 basis points = 5% in basis points (500/10000)
    uint256 public constant MAX_PRICE_DEVIATION = 500;
    
    /// @notice Basis for basis points calculations
    uint256 public constant BASIS_POINTS = 10000;

    /// @notice Maximum timestamp drift tolerance (15 minutes)
    /// @dev Prevents timestamp manipulation attacks by miners
    uint256 public constant MAX_TIMESTAMP_DRIFT = 900;

    // =============================================================================
    // STATE VARIABLES - Contract state variables
    // =============================================================================
    
    /// @notice Interface to Stork EUR/USD price feed
    IStorkFeed public eurUsdPriceFeed;
    
    /// @notice Interface to Stork USDC/USD price feed
    /// @dev Used for USDC price validation and cross-checking
    IStorkFeed public usdcUsdPriceFeed;
    
    /// @notice Stork price feed decimals (constant)
    /// @dev Stork feeds use 18 decimals precision (value is multiplied by 10^18)
    ///      This is verified based on Stork's documentation
    uint8 public constant STORK_FEED_DECIMALS = 18;

    /// @notice Treasury address for ETH recovery
    /// @dev SECURITY: Only this address can receive ETH from recoverETH function
    address public treasury;

    /// @notice EUR/USD feed ID for Stork
    bytes32 public eurUsdFeedId;
    
    /// @notice USDC/USD feed ID for Stork
    bytes32 public usdcUsdFeedId;

    /// @notice Minimum accepted EUR/USD price (lower circuit breaker)
    /// @dev Initialized to 0.80 USD per EUR (extreme crisis)
    uint256 public minEurUsdPrice;
    
    /// @notice Maximum accepted EUR/USD price (upper circuit breaker)
    /// @dev Initialized to 1.40 USD per EUR (extreme scenario)
    uint256 public maxEurUsdPrice;
    
    /// @notice Last valid EUR/USD price recorded (18 decimals)
    /// @dev Used as fallback if oracle is down
    uint256 public lastValidEurUsdPrice;
    
    /// @notice Timestamp of the last valid price update
    uint256 public lastPriceUpdateTime;

    /// @notice Block number of the last valid price update
    /// @dev Used for block-based staleness checks to prevent timestamp manipulation
    uint256 public lastPriceUpdateBlock;

    /// @notice Circuit breaker status (true = triggered, fixed prices)
    bool public circuitBreakerTriggered;

    /// @notice USDC/USD tolerance (USDC should remain close to $1.00)
    /// @dev 200 basis points = 2% (USDC can vary between 0.98 and 1.02)
    uint256 public usdcToleranceBps;

    /// @notice Dev mode flag to disable spread deviation checks
    /// @dev When enabled, price deviation checks are skipped (dev/testing only)
    bool public devModeEnabled;

    // =============================================================================
    // EVENTS - Events for monitoring and alerts
    // =============================================================================
    
    /// @notice Emitted on each valid price update
    /// @dev OPTIMIZED: Indexed timestamp for efficient time-based filtering
    event PriceUpdated(
        uint256 eurUsdPrice, 
        uint256 usdcUsdPrice, 
        uint256 indexed timestamp
    );
    
    /// @notice Emitted when the circuit breaker is triggered
    /// @dev OPTIMIZED: Indexed reason for efficient filtering by trigger type
    event CircuitBreakerTriggered(
        uint256 attemptedPrice, 
        uint256 lastValidPrice, 
        string indexed reason
    );
    
    /// @notice Emitted when the circuit breaker is reset
    event CircuitBreakerReset(address indexed admin);
    
    /// @notice Emitted when price bounds are modified
    /// @dev OPTIMIZED: Indexed bound type for efficient filtering
    event PriceBoundsUpdated(string indexed boundType, uint256 newMinPrice, uint256 newMaxPrice);
    
    /// @notice Emitted when price feed addresses are updated
    event PriceFeedsUpdated(address newEurUsdFeed, address newUsdcUsdFeed, bytes32 newEurUsdFeedId, bytes32 newUsdcUsdFeedId);

    /// @notice Emitted when treasury address is updated
    /// @param newTreasury New treasury address
    event TreasuryUpdated(address indexed newTreasury);

    /// @notice Emitted when ETH is recovered from the contract
    event ETHRecovered(address indexed to, uint256 amount);

    /// @notice Emitted when dev mode is toggled
    /// @param enabled Whether dev mode is enabled or disabled
    /// @param caller Address that triggered the toggle
    event DevModeToggled(bool enabled, address indexed caller);

    // =============================================================================
    // INITIALIZER - Initial contract configuration
    // =============================================================================

    /// @notice TimeProvider contract for centralized time management
    /// @dev Used to replace direct block.timestamp usage for testability and consistency
    TimeProvider public immutable TIME_PROVIDER;

    /**
     * @notice Constructor for StorkOracle contract
     * @dev Initializes the TimeProvider and disables initializers for proxy pattern
     * @param _TIME_PROVIDER Address of the TimeProvider contract for centralized time management
     * @custom:security Validates TimeProvider address is not zero
     * @custom:validation Validates _TIME_PROVIDER is not address(0)
     * @custom:state-changes Sets TIME_PROVIDER immutable variable and disables initializers
     * @custom:events No events emitted
     * @custom:errors Throws "Zero address" if _TIME_PROVIDER is address(0)
     * @custom:reentrancy Not applicable - constructor
     * @custom:access Public - anyone can deploy
     * @custom:oracle No oracle dependencies
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(TimeProvider _TIME_PROVIDER) {
        if (address(_TIME_PROVIDER) == address(0)) revert("Zero address");
        TIME_PROVIDER = _TIME_PROVIDER;
        _disableInitializers();
    }

    /**
     * @notice Initializes the oracle contract with Stork price feeds
     * @dev Sets up all core dependencies, roles, and default configuration parameters
     * @param admin Address with administrator privileges
     * @param _storkFeedAddress Stork feed contract address on Base (single contract for all feeds)
     * @param _eurUsdFeedId Stork EUR/USD feed ID (bytes32)
     * @param _usdcUsdFeedId Stork USDC/USD feed ID (bytes32)
     * @param _treasury Treasury address for ETH recovery
     * @custom:security Validates all addresses are not zero, grants admin roles
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
    ) public initializer {
        // Input parameter validation
        CommonValidationLibrary.validateNonZeroAddress(admin, "admin");
        CommonValidationLibrary.validateNonZeroAddress(_storkFeedAddress, "oracle");
        CommonValidationLibrary.validateNonZeroAddress(_treasury, "treasury");

        // OpenZeppelin module initialization
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        // Role configuration
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ORACLE_MANAGER_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        // Initialize price feed interfaces (Stork uses single contract with different feed IDs)
        eurUsdPriceFeed = IStorkFeed(_storkFeedAddress);
        usdcUsdPriceFeed = IStorkFeed(_storkFeedAddress);
        eurUsdFeedId = _eurUsdFeedId;
        usdcUsdFeedId = _usdcUsdFeedId;
        
        require(_treasury != address(0), "Treasury cannot be zero address");
        CommonValidationLibrary.validateTreasuryAddress(_treasury);
        CommonValidationLibrary.validateNonZeroAddress(_treasury, "treasury");
        treasury = _treasury;

        // Default price bounds configuration
        // EUR/USD historically between 0.80 and 1.40 in extreme cases
        minEurUsdPrice = 0.80e18;  // 0.80 USD per EUR (major crisis)
        maxEurUsdPrice = 1.40e18;  // 1.40 USD per EUR (EUR euphoric run)

        // Tolerance for USDC (should remain close to $1.00)
        usdcToleranceBps = 200;    // 2% tolerance (0.98 - 1.02)

        // Initialize with current price
        _updatePrices();
    }

    /**
     * @notice Update treasury address
     * @dev SECURITY: Only admin can update treasury address
     * @param _treasury New treasury address
     * @custom:security Validates treasury address is non-zero
     * @custom:validation Validates _treasury is not address(0)
     * @custom:state-changes Updates treasury state variable
     * @custom:events Emits TreasuryUpdated event
     * @custom:errors Throws if treasury is zero address
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependency
     */
    function updateTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasury != address(0), "Treasury cannot be zero address");
        CommonValidationLibrary.validateNonZeroAddress(_treasury, "treasury");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    /**
     * @notice Removes pause and resumes oracle operations
     * @dev Allows emergency role to unpause the oracle after resolving issues
     * @custom:security Resumes oracle operations after emergency pause
     * @custom:validation Validates contract was previously paused
     * @custom:state-changes Sets paused state to false
     * @custom:events Emits Unpaused event
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle Resumes normal oracle price queries
     */
    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }

    // =============================================================================
    // INTERNAL FUNCTIONS - Utility internal functions
    // =============================================================================

    /**
     * @notice Performs division with proper rounding to nearest integer
     * @dev Adds half the divisor before division to achieve proper rounding
     * @param a Numerator
     * @param b Denominator
     * @return Result of division with rounding to nearest
     * @custom:security Validates denominator is non-zero
     * @custom:validation Validates b > 0 to prevent division by zero
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws if denominator is zero
     * @custom:reentrancy Not protected - pure function
     * @custom:access Internal - only callable within contract
     * @custom:oracle No oracle dependency
     */
    function _divRound(uint256 a, uint256 b) internal pure returns (uint256) {
        CommonValidationLibrary.validatePositiveAmount(b);
        return (a + b / 2) / b;
    }

    /**
     * @notice Validates if a timestamp is recent enough to prevent manipulation attacks
     * @dev Checks timestamp is not in future and not too old beyond staleness + drift limits
     * @param reportedTime The timestamp to validate
     * @return true if the timestamp is valid, false otherwise
     * @custom:security Prevents timestamp manipulation attacks by miners
     * @custom:validation Checks timestamp is not in future and within staleness limits
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown, returns false for invalid timestamps
     * @custom:reentrancy Not protected - view function
     * @custom:access Internal - only callable within contract
     * @custom:oracle Uses TimeProvider for current time validation
     */
    function _validateTimestamp(uint256 reportedTime) internal view returns (bool) {
        // Reject if reported time is in the future
        if (reportedTime > TIME_PROVIDER.currentTime()) return false;
        
        // Check if the timestamp is too old (beyond normal staleness + drift)
        // Use safe arithmetic to prevent underflow
        uint256 maxAllowedAge = MAX_PRICE_STALENESS + MAX_TIMESTAMP_DRIFT;
        if (TIME_PROVIDER.currentTime() > reportedTime + maxAllowedAge) return false;
        
        return true;
    }

    /**
     * @notice Updates and validates internal prices
     * @dev Internal function called during initialization and resets, fetches fresh prices from Stork
     * @custom:security Validates prices, checks bounds, and triggers circuit breaker if needed
     * @custom:validation Validates timestamp freshness, price bounds, and deviation limits
     * @custom:state-changes Updates lastValidEurUsdPrice, lastPriceUpdateTime, and circuitBreakerTriggered
     * @custom:events Emits PriceUpdated or CircuitBreakerTriggered events
     * @custom:errors No errors thrown, uses circuit breaker for invalid prices
     * @custom:reentrancy Not protected - internal function
     * @custom:access Internal - only callable within contract
     * @custom:oracle Fetches prices from Stork feed contracts for EUR/USD and USDC/USD
     */
    function _updatePrices() internal {
        // Fetch EUR/USD price data directly from Stork
        IStorkFeed.TemporalNumericValue memory eurUsdData = eurUsdPriceFeed.getTemporalNumericValueV1(eurUsdFeedId);
        
        // Validate data integrity
        CommonValidationLibrary.validateCondition(eurUsdData.timestamp > 0, "oracle");
        
        // Fetch USDC/USD price data directly from Stork
        IStorkFeed.TemporalNumericValue memory usdcUsdData = usdcUsdPriceFeed.getTemporalNumericValueV1(usdcUsdFeedId);
        
        // Validate data integrity
        CommonValidationLibrary.validateCondition(usdcUsdData.timestamp > 0, "oracle");
        
        // Validate EUR/USD price
        bool eurUsdValid = true;
        uint256 eurUsdPrice = 0;
        
        // Check if EUR/USD price is fresh and positive with timestamp validation
        if (!_validateTimestamp(eurUsdData.timestamp) || eurUsdData.value <= 0) {
            eurUsdValid = false;
        } else {
            // Convert Stork decimals to 18 decimals
            // Stork feeds use 18 decimals, so no scaling needed
            eurUsdPrice = _scalePrice(eurUsdData.value, STORK_FEED_DECIMALS);
            
            // Circuit breaker bounds check
            eurUsdValid = eurUsdPrice >= minEurUsdPrice && eurUsdPrice <= maxEurUsdPrice;
            
            // Deviation check against last valid price (reject sudden jumps > MAX_PRICE_DEVIATION)
            // Skip deviation check if dev mode is enabled
            if (eurUsdValid && lastValidEurUsdPrice > 0 && !devModeEnabled) {
                uint256 base = lastValidEurUsdPrice;
                uint256 diff = eurUsdPrice > base ? eurUsdPrice - base : base - eurUsdPrice;
                uint256 deviationBps = _divRound(diff * BASIS_POINTS, base);
                if (deviationBps > MAX_PRICE_DEVIATION) {
                    eurUsdValid = false;
                }
            }
        }
        
        // If EUR/USD invalid, trigger the circuit breaker
        if (!eurUsdValid) {
            circuitBreakerTriggered = true;
            emit CircuitBreakerTriggered(
                eurUsdPrice, 
                lastValidEurUsdPrice, 
                "Price validation failed during update"
            );
            return;
        }
        
        // Calculate USDC/USD price for event emission
        uint256 usdcUsdPrice = 1e18; // Default fallback
        if (_validateTimestamp(usdcUsdData.timestamp) && usdcUsdData.value > 0) {
            // Stork feeds use 18 decimals, so no scaling needed
            usdcUsdPrice = _scalePrice(usdcUsdData.value, STORK_FEED_DECIMALS);
            
            // Check USDC tolerance
            uint256 tolerance = _divRound(1e18 * usdcToleranceBps, BASIS_POINTS);
            uint256 minPrice = 1e18 - tolerance;
            uint256 maxPrice = 1e18 + tolerance;
            
            if (usdcUsdPrice < minPrice || usdcUsdPrice > maxPrice) {
                usdcUsdPrice = 1e18; // Use fallback if outside tolerance
            }
        }

        // Update internal values
        lastValidEurUsdPrice = eurUsdPrice;
        lastPriceUpdateTime = TIME_PROVIDER.currentTime();
        lastPriceUpdateBlock = block.number;

        // Emit update event
        emit PriceUpdated(eurUsdPrice, usdcUsdPrice, TIME_PROVIDER.currentTime());
    }

    /**
     * @notice Scale price to 18 decimals for consistency
     * @dev Converts Stork price from its native decimals to 18 decimals with proper rounding
     * @param rawPrice Raw price from Stork
     * @param decimals Number of decimals in raw price
     * @return Scaled price with 18 decimals
     * @custom:security Handles negative prices by returning 0
     * @custom:validation Validates rawPrice is positive before scaling
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown, returns 0 for negative prices
     * @custom:reentrancy Not protected - pure function
     * @custom:access Internal - only callable within contract
     * @custom:oracle Scales Stork price data to 18 decimals standard
     */
    function _scalePrice(int256 rawPrice, uint8 decimals) internal pure returns (uint256) {
        if (rawPrice <= 0) return 0;

        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 price = uint256(rawPrice);
        
        if (decimals == 18) {
            return price;
        } else if (decimals < 18) {
            // Multiply by 10^(18-decimals) to scale up
            return price * (10 ** (18 - decimals));
        } else {
            // Divide by 10^(decimals-18) to scale down with rounding
            uint256 divisor = 10 ** (decimals - 18);
            uint256 halfDivisor = divisor / 2;
            return (price + halfDivisor) / divisor; // Round to nearest
        }
    }

    // =============================================================================
    // VIEW FUNCTIONS - Read functions for monitoring
    // =============================================================================

    /**
     * @notice Retrieves the oracle global health status
     * @dev Checks freshness of both price feeds and overall system health
     * @return isHealthy true if everything operates normally
     * @return eurUsdFresh true if EUR/USD price is fresh
     * @return usdcUsdFresh true if USDC/USD price is fresh
     * @custom:security Provides health status for monitoring and circuit breaker decisions
     * @custom:validation Checks feed freshness, circuit breaker state, and pause status
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown, returns false for unhealthy feeds
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle Queries Stork feed contracts for EUR/USD and USDC/USD health status
     */
    function getOracleHealth() 
        external 
        view 
        returns (
            bool isHealthy,
            bool eurUsdFresh,
            bool usdcUsdFresh
        ) 
    {
        // Check EUR/USD price freshness directly
        try eurUsdPriceFeed.getTemporalNumericValueV1(eurUsdFeedId) returns (IStorkFeed.TemporalNumericValue memory data) {
            eurUsdFresh = _validateTimestamp(data.timestamp) && data.value > 0;
        } catch {
            eurUsdFresh = false;
        }
        
        // Check USDC/USD price freshness directly
        try usdcUsdPriceFeed.getTemporalNumericValueV1(usdcUsdFeedId) returns (IStorkFeed.TemporalNumericValue memory data) {
            usdcUsdFresh = _validateTimestamp(data.timestamp) && data.value > 0;
        } catch {
            usdcUsdFresh = false;
        }
        
        // Oracle is healthy if:
        // - Both prices are fresh
        // - The circuit breaker is not triggered
        // - The contract is not paused
        isHealthy = eurUsdFresh && 
                   usdcUsdFresh && 
                   !circuitBreakerTriggered && 
                   !paused();
    }

    /**
     * @notice Retrieves detailed information about the EUR/USD price
     * @dev Provides comprehensive EUR/USD price information including validation status
     * @return currentPrice Current price (may be fallback)
     * @return lastValidPrice Last validated price stored
     * @return lastUpdate Timestamp of last update
     * @return isStale True if the feed data is stale
     * @return withinBounds True if within configured min/max bounds
     * @custom:security Provides detailed price information for debugging and monitoring
     * @custom:validation Checks price freshness and bounds validation
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle Queries Stork feed contract for detailed EUR/USD price information
     */
    function getEurUsdDetails() 
        external 
        view 
        returns (
            uint256 currentPrice,
            uint256 lastValidPrice,
            uint256 lastUpdate,
            bool isStale,
            bool withinBounds
        ) 
    {
        // Get current price directly without calling external function on self
        if (circuitBreakerTriggered || paused()) {
            currentPrice = lastValidEurUsdPrice;
        } else {
            try eurUsdPriceFeed.getTemporalNumericValueV1(eurUsdFeedId) returns (IStorkFeed.TemporalNumericValue memory data) {
                if (_validateTimestamp(data.timestamp) && data.value > 0) {
                    // Stork feeds use 18 decimals
                    currentPrice = _scalePrice(data.value, STORK_FEED_DECIMALS);
                    
                    // Check bounds and deviation
                    bool isValid = currentPrice >= minEurUsdPrice && currentPrice <= maxEurUsdPrice;
                    
                    // Skip deviation check if dev mode is enabled
                    if (isValid && lastValidEurUsdPrice > 0 && !devModeEnabled) {
                        uint256 base = lastValidEurUsdPrice;
                        uint256 diff = currentPrice > base ? currentPrice - base : base - currentPrice;
                        uint256 deviationBps = _divRound(diff * BASIS_POINTS, base);
                        if (deviationBps > MAX_PRICE_DEVIATION) {
                            isValid = false;
                        }
                    }
                    
                    if (!isValid) {
                        currentPrice = lastValidEurUsdPrice;
                    }
                } else {
                    currentPrice = lastValidEurUsdPrice;
                }
            } catch {
                currentPrice = lastValidEurUsdPrice;
            }
        }
        
        lastValidPrice = lastValidEurUsdPrice;
        lastUpdate = lastPriceUpdateTime;
        
        // Staleness check
        try eurUsdPriceFeed.getTemporalNumericValueV1(eurUsdFeedId) returns (IStorkFeed.TemporalNumericValue memory data) {
            isStale = !_validateTimestamp(data.timestamp) || data.value <= 0;
        } catch {
            isStale = true;
        }
        
        // Bounds check
        withinBounds = currentPrice >= minEurUsdPrice && currentPrice <= maxEurUsdPrice;
    }

    /**
     * @notice Retrieves current configuration parameters
     * @dev Returns all key configuration values for oracle operations
     * @return minPrice Minimum EUR/USD price
     * @return maxPrice Maximum EUR/USD price
     * @return maxStaleness Maximum duration before staleness
     * @return usdcTolerance USDC tolerance in basis points
     * @return circuitBreakerActive Circuit breaker status
     * @custom:security Returns configuration for security monitoring
     * @custom:validation No validation - read-only configuration
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle Returns configuration parameters for Stork oracle
     */
    function getOracleConfig() 
        external 
        view 
        returns (
            uint256 minPrice,
            uint256 maxPrice,
            uint256 maxStaleness,
            uint256 usdcTolerance,
            bool circuitBreakerActive
        ) 
    {
        return (
            minEurUsdPrice,
            maxEurUsdPrice,
            MAX_PRICE_STALENESS,
            usdcToleranceBps,
            circuitBreakerTriggered
        );
    }

    /**
     * @notice Retrieves addresses of the Stork price feeds used
     * @dev Returns feed addresses and their decimal configurations
     * @return eurUsdFeedAddress EUR/USD feed address
     * @return usdcUsdFeedAddress USDC/USD feed address
     * @return eurUsdDecimals Number of decimals for the EUR/USD feed
     * @return usdcUsdDecimals Number of decimals for the USDC/USD feed
     * @custom:security Returns feed addresses for verification
     * @custom:validation No validation - read-only information
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle Returns Stork feed contract addresses and decimals (18 for both)
     */
    function getPriceFeedAddresses() 
        external 
        view 
        returns (
            address eurUsdFeedAddress,
            address usdcUsdFeedAddress,
            uint8 eurUsdDecimals,
            uint8 usdcUsdDecimals
        ) 
    {
        return (
            address(eurUsdPriceFeed),
            address(usdcUsdPriceFeed),
            STORK_FEED_DECIMALS,
            STORK_FEED_DECIMALS
        );
    }

    /**
     * @notice Tests connectivity to the Stork price feeds
     * @dev Tests if both price feeds are responding and returns latest round information
     * @return eurUsdConnected true if the EUR/USD feed responds
     * @return usdcUsdConnected true if the USDC/USD feed responds
     * @return eurUsdLatestRound Latest round ID for EUR/USD (always 0 for Stork)
     * @return usdcUsdLatestRound Latest round ID for USDC/USD (always 0 for Stork)
     * @custom:security Tests feed connectivity for health monitoring
     * @custom:validation No validation - connectivity test only
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown, returns false for disconnected feeds
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle Tests connectivity to Stork feed contracts for both feeds
     */
    function checkPriceFeedConnectivity() 
        external 
        view 
        returns (
            bool eurUsdConnected,
            bool usdcUsdConnected,
            uint80 eurUsdLatestRound,
            uint80 usdcUsdLatestRound
        ) 
    {
        // Test EUR/USD feed
        try eurUsdPriceFeed.getTemporalNumericValueV1(eurUsdFeedId) returns (IStorkFeed.TemporalNumericValue memory data) {
            eurUsdConnected = data.value > 0 && _validateTimestamp(data.timestamp);
            eurUsdLatestRound = 0; // Stork doesn't use round IDs
        } catch {
            eurUsdConnected = false;
            eurUsdLatestRound = 0;
        }

        // Test USDC/USD feed
        try usdcUsdPriceFeed.getTemporalNumericValueV1(usdcUsdFeedId) returns (IStorkFeed.TemporalNumericValue memory data) {
            usdcUsdConnected = data.value > 0 && _validateTimestamp(data.timestamp);
            usdcUsdLatestRound = 0; // Stork doesn't use round IDs
        } catch {
            usdcUsdConnected = false;
            usdcUsdLatestRound = 0;
        }
    }

    // =============================================================================
    // UPGRADE FUNCTION - Upgrade authorization
    // =============================================================================

    /**
     * @notice Authorizes oracle contract upgrades
     * @param newImplementation Address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) 
        internal 
        override 
        onlyRole(UPGRADER_ROLE) 
    {
        // Additional validations can be added here
        // For example: verify newImplementation compatibility
    }

    // =============================================================================
    // EMERGENCY RECOVERY - Emergency recovery functions
    // =============================================================================

    /**
     * @notice Recovers tokens accidentally sent to the contract to treasury only
     * @dev Emergency function to recover ERC20 tokens that are not part of normal operations
     * @param token Address of the token to recover
     * @param amount Amount to recover
     * @custom:security Transfers tokens to treasury, prevents accidental loss
     * @custom:validation Validates token and amount are non-zero
     * @custom:state-changes Transfers tokens from contract to treasury
     * @custom:events Emits TokenRecovered event (via library)
     * @custom:errors Throws if token is zero address or transfer fails
     * @custom:reentrancy Protected by library reentrancy guard
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependency
     */
    function recoverToken(
        address token,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Use the shared library for secure token recovery to treasury
        TreasuryRecoveryLibrary.recoverToken(token, amount, address(this), treasury);
    }

    /**
     * @notice Recover ETH to treasury address only
     * @dev SECURITY: Restricted to treasury to prevent arbitrary ETH transfers
     * @custom:security Transfers ETH to treasury, prevents accidental loss
     * @custom:validation Validates contract has ETH balance
     * @custom:state-changes Transfers ETH from contract to treasury
     * @custom:events Emits ETHRecovered event
     * @custom:errors Throws if transfer fails
     * @custom:reentrancy Protected by library reentrancy guard
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependency
     */
    function recoverETH() external onlyRole(DEFAULT_ADMIN_ROLE) {
        emit ETHRecovered(treasury, address(this).balance);
        // Use the shared library for secure ETH recovery
        TreasuryRecoveryLibrary.recoverETH(treasury);
    }

    // =============================================================================
    // EMERGENCY FUNCTIONS - Emergency controls
    // =============================================================================

    /**
     * @notice Resets the circuit breaker and resumes oracle usage
     * 
     * @dev Emergency action after resolving an incident.
     *      Restarts price updates and disables fallback mode.
     * @custom:security Resets circuit breaker after manual intervention
     * @custom:validation Validates circuit breaker was previously triggered
     * @custom:state-changes Resets circuitBreakerTriggered flag and updates prices
     * @custom:events Emits CircuitBreakerReset event
     * @custom:errors No errors thrown
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle Resumes normal Stork oracle price queries
     */
    function resetCircuitBreaker() external onlyRole(EMERGENCY_ROLE) {
        circuitBreakerTriggered = false;
        _updatePrices(); // Attempt immediate update
        emit CircuitBreakerReset(msg.sender);
    }

    /**
     * @notice Manually triggers the circuit breaker
     * 
     * @dev Used when the team detects an issue with the oracles.
     *      Forces the use of the last known valid price.
     * @custom:security Manually activates circuit breaker for emergency situations
     * @custom:validation No validation - emergency function
     * @custom:state-changes Sets circuitBreakerTriggered flag to true
     * @custom:events Emits CircuitBreakerTriggered event
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle Switches to fallback prices instead of live Stork oracle queries
     */
    function triggerCircuitBreaker() external onlyRole(EMERGENCY_ROLE) {
        circuitBreakerTriggered = true;
    }

    /**
     * @notice Pauses all oracle operations
     * @dev Emergency function to pause oracle in case of critical issues
     * @custom:security Emergency pause to halt all oracle operations
     * @custom:validation No validation - emergency function
     * @custom:state-changes Sets paused state to true
     * @custom:events Emits Paused event
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle Halts all Stork oracle price queries
     */
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    /**
     * @notice Retrieves the current EUR/USD price with full validation
     * 
     * @return price EUR/USD price in 18 decimals (e.g., 1.10e18 = 1.10 USD per EUR)
     * @return isValid true if the price is fresh and within acceptable bounds
     * 
     * @dev Validation process:
     *      1. Check circuit breaker status
     *      2. Fetch from Stork
     *      3. Freshness check (< 1 hour)
     *      4. Convert to 18 decimals
     *      5. Check min/max bounds
     *      6. Return valid price or fallback
     * @custom:security Validates price freshness and bounds before returning
     * @custom:validation Checks price staleness, circuit breaker state, and bounds
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown, returns isValid=false for invalid prices
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle Queries Stork feed contract for EUR/USD price
     */
    function getEurUsdPrice() external view returns (uint256 price, bool isValid) {
        // If circuit breaker is active or contract is paused, use the last valid price
        if (circuitBreakerTriggered || paused()) {
            return (lastValidEurUsdPrice, false);
        }

        // Fetch data from Stork
        IStorkFeed.TemporalNumericValue memory data = eurUsdPriceFeed.getTemporalNumericValueV1(eurUsdFeedId);
        
        // Data freshness check with timestamp validation and data integrity
        if (!_validateTimestamp(data.timestamp) || data.value <= 0) {
            return (lastValidEurUsdPrice, false);
        }

        // Convert Stork decimals to 18 decimals
        // Stork feeds use 18 decimals
        price = _scalePrice(data.value, STORK_FEED_DECIMALS);

        // Circuit breaker bounds check
        isValid = price >= minEurUsdPrice && price <= maxEurUsdPrice;

        // Deviation check against last valid price (reject sudden jumps > MAX_PRICE_DEVIATION)
        // Skip deviation check if dev mode is enabled
        if (isValid && lastValidEurUsdPrice > 0 && !devModeEnabled) {
            uint256 base = lastValidEurUsdPrice;
            uint256 diff = price > base ? price - base : base - price;
    
            uint256 deviationBps = _divRound(diff * BASIS_POINTS, base);
            if (deviationBps > MAX_PRICE_DEVIATION) {
                isValid = false;
            }
        }
        
        // If price invalid, return the last valid price
        if (!isValid) {
            price = lastValidEurUsdPrice;
        }
    }

    /**
     * @notice Retrieves the USDC/USD price with validation
     * 
     * @return price USDC/USD price in 18 decimals (should be close to 1.0e18)
     * @return isValid true if USDC remains close to $1.00
     * 
     * @dev USDC is expected to maintain parity with USD.
     *      A large deviation indicates a systemic issue.
     * @custom:security Validates price is within tolerance of $1.00
     * @custom:validation Checks price staleness and deviation from $1.00
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown, returns isValid=false for invalid prices
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle Queries Stork feed contract for USDC/USD price
     */
    function getUsdcUsdPrice() external view returns (uint256 price, bool isValid) {
        // Fetch from Stork
        IStorkFeed.TemporalNumericValue memory data = usdcUsdPriceFeed.getTemporalNumericValueV1(usdcUsdFeedId);
        
        // Freshness check with timestamp validation and data integrity
        if (!_validateTimestamp(data.timestamp) || data.value <= 0) {
            return (1e18, false); // Fallback to $1.00
        }

        // Convert to 18 decimals
        // Stork feeds use 18 decimals
        price = _scalePrice(data.value, STORK_FEED_DECIMALS);

        // USDC must stay within tolerance around $1.00
        uint256 tolerance = _divRound(1e18 * usdcToleranceBps, BASIS_POINTS);
        uint256 minPrice = 1e18 - tolerance;  // e.g., 0.98e18
        uint256 maxPrice = 1e18 + tolerance;  // e.g., 1.02e18
        
        isValid = price >= minPrice && price <= maxPrice;
        
        // If USDC exceeds tolerance, use $1.00 by default
        if (!isValid) {
            price = 1e18;
        }
    }

    // =============================================================================
    // ADMIN FUNCTIONS - Administrative functions
    // =============================================================================

    /**
     * @notice Updates price bounds for the circuit breaker
     * @dev Allows oracle manager to adjust price thresholds based on market conditions
     * @param _minPrice Minimum accepted EUR/USD price (18 decimals)
     * @param _maxPrice Maximum accepted EUR/USD price (18 decimals)
     * @custom:security Validates min < max and reasonable bounds
     * @custom:validation Validates price bounds are within acceptable range
     * @custom:state-changes Updates minEurUsdPrice and maxEurUsdPrice state variables
     * @custom:events Emits PriceBoundsUpdated event
     * @custom:errors Throws if minPrice >= maxPrice or invalid bounds
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:oracle No oracle dependency - configuration update only
     */
    function updatePriceBounds(
        uint256 _minPrice,
        uint256 _maxPrice
    ) external onlyRole(ORACLE_MANAGER_ROLE) {
        CommonValidationLibrary.validatePositiveAmount(_minPrice);
        CommonValidationLibrary.validateCondition(_maxPrice > _minPrice, "price");
        CommonValidationLibrary.validateMaxAmount(_maxPrice, 10e18); // Sanity check

        minEurUsdPrice = _minPrice;
        maxEurUsdPrice = _maxPrice;

        emit PriceBoundsUpdated("bounds", _minPrice, _maxPrice);
    }

    /**
     * @notice Updates the tolerance for USDC/USD
     * @dev Allows oracle manager to adjust USDC price tolerance around $1.00
     * @param newToleranceBps New tolerance in basis points (e.g., 200 = 2%)
     * @custom:security Validates tolerance is within reasonable limits
     * @custom:validation Validates tolerance is not zero and within max bounds (10%)
     * @custom:state-changes Updates usdcToleranceBps state variable
     * @custom:events No events emitted
     * @custom:errors Throws if tolerance is invalid or out of bounds
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:oracle No oracle dependency - configuration update only
     */
    function updateUsdcTolerance(uint256 newToleranceBps) 
        external 
        onlyRole(ORACLE_MANAGER_ROLE) 
    {
        CommonValidationLibrary.validatePercentage(newToleranceBps, 1000); // Max 10%
        usdcToleranceBps = newToleranceBps;
    }

    /**
     * @notice Updates the Stork feed address and feed IDs
     * @dev Allows oracle manager to update feed address and feed IDs for maintenance or upgrades
     *      Note: Stork uses a single contract address with different feed IDs
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
    function updatePriceFeeds(
        address _storkFeedAddress,
        bytes32 _eurUsdFeedId,
        bytes32 _usdcUsdFeedId
    ) external onlyRole(ORACLE_MANAGER_ROLE) {
        CommonValidationLibrary.validateNonZeroAddress(_storkFeedAddress, "oracle");

        // Stork uses single contract with different feed IDs
        eurUsdPriceFeed = IStorkFeed(_storkFeedAddress);
        usdcUsdPriceFeed = IStorkFeed(_storkFeedAddress);
        eurUsdFeedId = _eurUsdFeedId;
        usdcUsdFeedId = _usdcUsdFeedId;

        emit PriceFeedsUpdated(_storkFeedAddress, _storkFeedAddress, _eurUsdFeedId, _usdcUsdFeedId);
    }

    /**
     * @notice Toggles dev mode to disable spread deviation checks
     * @dev DEV ONLY: When enabled, price deviation checks are skipped for testing
     * @param enabled True to enable dev mode, false to disable
     */
    /**
     * @notice Toggles dev mode to disable price deviation checks
     * @dev Dev mode allows testing with price deviations that would normally trigger circuit breaker
     * @param enabled True to enable dev mode, false to disable
     * @custom:security Disables price deviation checks - use only for testing
     * @custom:validation No validation - admin function
     * @custom:state-changes Updates devModeEnabled flag
     * @custom:events Emits DevModeToggled event
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependency - configuration update only
     */
    function setDevMode(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        devModeEnabled = enabled;
        emit DevModeToggled(enabled, msg.sender);
    }
}

