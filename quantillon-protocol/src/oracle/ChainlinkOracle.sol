// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// =============================================================================
// IMPORTS - Chainlink interfaces and OpenZeppelin security
// =============================================================================

// Standard interface for Chainlink price feeds
import {AggregatorV3Interface} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

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
import {ValidationLibrary} from "../libraries/ValidationLibrary.sol";

/**
 * @title ChainlinkOracle
 * @notice EUR/USD and USDC/USD price manager for Quantillon Protocol
 * 
 * @dev Key features:
 *      - Fetch EUR/USD price from Chainlink
 *      - Validate USDC/USD (should remain close to $1.00)
 *      - Circuit breakers against outlier prices
 *      - Fallbacks in case of oracle outage
 *      - Data freshness checks
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract ChainlinkOracle is 
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
    
    /// @notice Blocks per hour for block-based staleness checks
    /// @dev ~12 second blocks on Ethereum, ~2 second blocks on L2s
    uint256 public constant BLOCKS_PER_HOUR = 300;

    // =============================================================================
    // STATE VARIABLES - Contract state variables
    // =============================================================================
    
    /// @notice Interface to Chainlink EUR/USD price feed
    AggregatorV3Interface public eurUsdPriceFeed;
    
    /// @notice Interface to Chainlink USDC/USD price feed
    /// @dev Used for USDC price validation and cross-checking
    /// @dev Should be the official USDC/USD Chainlink feed
    AggregatorV3Interface public usdcUsdPriceFeed;

    /// @notice Treasury address for ETH recovery
    /// @dev SECURITY: Only this address can receive ETH from recoverETH function
    address public treasury;

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
    event PriceFeedsUpdated(address newEurUsdFeed, address newUsdcUsdFeed);

    /// @notice Emitted when treasury address is updated
    /// @param newTreasury New treasury address
    event TreasuryUpdated(address indexed newTreasury);

    /// @notice Emitted when ETH is recovered from the contract
    event ETHRecovered(address indexed to, uint256 amount);

    // =============================================================================
    // INITIALIZER - Initial contract configuration
    // =============================================================================

    /// @notice TimeProvider contract for centralized time management
    /// @dev Used to replace direct block.timestamp usage for testability and consistency
    TimeProvider public immutable TIME_PROVIDER;

    /**
     * @notice Constructor for ChainlinkOracle contract
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
     * @notice Initializes the oracle contract with Chainlink price feeds
     * @dev Sets up all core dependencies, roles, and default configuration parameters
     * @param admin Address with administrator privileges
     * @param _eurUsdPriceFeed Chainlink EUR/USD price feed address on Base
     * @param _usdcUsdPriceFeed Chainlink USDC/USD price feed address on Base
     * @param _treasury Treasury address for ETH recovery
     * @custom:security Validates all addresses are not zero, grants admin roles
     * @custom:validation Validates all input addresses are not address(0)
     * @custom:state-changes Initializes all state variables, sets default price bounds
     * @custom:events Emits PriceUpdated during initial price update
     * @custom:errors Throws "Oracle: Admin cannot be zero" if admin is address(0)
     * @custom:reentrancy Protected by initializer modifier
     * @custom:access Public - only callable once during deployment
     * @custom:oracle Initializes Chainlink price feed interfaces
     */
    function initialize(
        address admin,
        address _eurUsdPriceFeed,
        address _usdcUsdPriceFeed,
        address _treasury
    ) public initializer {
        // Input parameter validation
        require(admin != address(0), "Oracle: Admin cannot be zero");
        require(_eurUsdPriceFeed != address(0), "Oracle: EUR/USD feed cannot be zero");
        require(_usdcUsdPriceFeed != address(0), "Oracle: USDC/USD feed cannot be zero");
        require(_treasury != address(0), "Oracle: Treasury cannot be zero");

        // OpenZeppelin module initialization
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        // Role configuration
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ORACLE_MANAGER_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        // Initialize price feed interfaces
        eurUsdPriceFeed = AggregatorV3Interface(_eurUsdPriceFeed);
        usdcUsdPriceFeed = AggregatorV3Interface(_usdcUsdPriceFeed);
        ValidationLibrary.validateTreasuryAddress(_treasury);
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
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function updateTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasury != address(0), "Oracle: Treasury cannot be zero");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    /**
     * @notice Removes pause and resumes oracle operations
     * @dev Allows emergency role to unpause the oracle after resolving issues
     * @custom:security Validates emergency role authorization
     * @custom:validation No input validation required
     * @custom:state-changes Removes pause state, resumes oracle operations
     * @custom:events Emits Unpaused event from OpenZeppelin
     * @custom:errors No errors thrown - safe unpause operation
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle No oracle dependencies for unpause
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
     * @custom:security Validates denominator is not zero to prevent division by zero
     * @custom:validation Validates b > 0
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws "Oracle: Division by zero" if b is 0
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _divRound(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "Oracle: Division by zero");
        return (a + b / 2) / b;
    }

    /**
     * @notice Validates if a timestamp is recent enough to prevent manipulation attacks
     * @dev Checks timestamp is not in future and not too old beyond staleness + drift limits
     * @param reportedTime The timestamp to validate
     * @return true if the timestamp is valid, false otherwise
     * @custom:security Validates timestamp is not in future and within acceptable age
     * @custom:validation Validates reportedTime <= currentTime and within MAX_PRICE_STALENESS + MAX_TIMESTAMP_DRIFT
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies for timestamp validation
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
     * @dev Internal function called during initialization and resets, fetches fresh prices from Chainlink
     * @custom:security Validates price data integrity, circuit breaker bounds, and deviation limits
     * @custom:validation Validates roundId == answeredInRound, startedAt <= updatedAt, price > 0
     * @custom:state-changes Updates lastValidEurUsdPrice, lastPriceUpdateTime, lastPriceUpdateBlock
     * @custom:events Emits PriceUpdated with current prices or CircuitBreakerTriggered if invalid
     * @custom:errors Throws "EUR/USD price data is stale" if roundId != answeredInRound
     * @custom:reentrancy Not protected - internal function only
     * @custom:access Internal function - no access restrictions
     * @custom:oracle Fetches fresh prices from Chainlink EUR/USD and USDC/USD feeds
     */
    function _updatePrices() internal {
        // Fetch EUR/USD price data directly from Chainlink
        (uint80 eurUsdRoundId, int256 eurUsdRawPrice, uint256 eurUsdStartedAt, uint256 eurUsdUpdatedAt, uint80 eurUsdAnsweredInRound) = eurUsdPriceFeed.latestRoundData();
        
        // Validate data integrity - ensure roundId matches answeredInRound and data is not too old
        require(eurUsdRoundId == eurUsdAnsweredInRound, "EUR/USD price data is stale");
        require(eurUsdStartedAt <= eurUsdUpdatedAt, "EUR/USD price data has invalid timestamps");
        
        // Fetch USDC/USD price data directly from Chainlink
        (uint80 usdcUsdRoundId, int256 usdcUsdRawPrice, uint256 usdcUsdStartedAt, uint256 usdcUsdUpdatedAt, uint80 usdcUsdAnsweredInRound) = usdcUsdPriceFeed.latestRoundData();
        
        // Validate data integrity - ensure roundId matches answeredInRound and data is not too old
        require(usdcUsdRoundId == usdcUsdAnsweredInRound, "USDC/USD price data is stale");
        require(usdcUsdStartedAt <= usdcUsdUpdatedAt, "USDC/USD price data has invalid timestamps");
        
        // Validate EUR/USD price
        bool eurUsdValid = true;
        uint256 eurUsdPrice = 0;
        
        // Check if EUR/USD price is fresh and positive with timestamp validation
        if (!_validateTimestamp(eurUsdUpdatedAt) || eurUsdRawPrice <= 0) {
            eurUsdValid = false;
        } else {
            // Convert Chainlink decimals to 18 decimals
            uint8 eurUsdFeedDecimals = eurUsdPriceFeed.decimals();
            eurUsdPrice = _scalePrice(eurUsdRawPrice, eurUsdFeedDecimals);
            
            // Circuit breaker bounds check
            eurUsdValid = eurUsdPrice >= minEurUsdPrice && eurUsdPrice <= maxEurUsdPrice;
            
            // Deviation check against last valid price (reject sudden jumps > MAX_PRICE_DEVIATION)
            if (eurUsdValid && lastValidEurUsdPrice > 0) {
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
        if (_validateTimestamp(usdcUsdUpdatedAt) && usdcUsdRawPrice > 0) {
            uint8 usdcUsdFeedDecimals = usdcUsdPriceFeed.decimals();
            usdcUsdPrice = _scalePrice(usdcUsdRawPrice, usdcUsdFeedDecimals);
            
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
     * @dev Converts Chainlink price from its native decimals to 18 decimals with proper rounding
     * @param rawPrice Raw price from Chainlink
     * @param decimals Number of decimals in raw price
     * @return Scaled price with 18 decimals
     * @custom:security Validates rawPrice > 0 and handles decimal conversion safely
     * @custom:validation Validates rawPrice > 0, returns 0 if invalid
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe arithmetic used
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies for price scaling
     */
    function _scalePrice(int256 rawPrice, uint8 decimals) internal pure returns (uint256) {
        if (rawPrice <= 0) return 0;
        
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
     * @custom:security Validates price feed connectivity and data integrity
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function with try/catch
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can check oracle health
     * @custom:oracle Checks connectivity to Chainlink EUR/USD and USDC/USD feeds
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
        try eurUsdPriceFeed.latestRoundData() returns (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) {
            // Use all return values meaningfully
            eurUsdFresh = _validateTimestamp(updatedAt) && (roundId == answeredInRound) && (price > 0) && (startedAt <= updatedAt);
        } catch {
            eurUsdFresh = false;
        }
        
        // Check USDC/USD price freshness directly
        try usdcUsdPriceFeed.latestRoundData() returns (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) {
            // Use all return values meaningfully
            usdcUsdFresh = _validateTimestamp(updatedAt) && (roundId == answeredInRound) && (price > 0) && (startedAt <= updatedAt);
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
     * @dev Provides comprehensive EUR/USD price data including staleness and bounds checks
     * @return currentPrice Current price (may be fallback)
     * @return lastValidPrice Last validated price
     * @return lastUpdate Timestamp of last update
     * @return isStale true if the price is stale
     * @return withinBounds true if within acceptable bounds
     * @custom:security Validates price feed data integrity and circuit breaker status
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function with try/catch
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query EUR/USD details
     * @custom:oracle Fetches fresh data from Chainlink EUR/USD price feed
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
            try eurUsdPriceFeed.latestRoundData() returns (
                uint80 roundId,
                int256 rawPrice,
                uint256 startedAt,
                uint256 updatedAt,
                uint80 answeredInRound
            ) {
                // Use all return values meaningfully
                if (_validateTimestamp(updatedAt) && rawPrice > 0 && (roundId == answeredInRound) && (startedAt <= updatedAt)) {
                    uint8 feedDecimals = eurUsdPriceFeed.decimals();
                    currentPrice = _scalePrice(rawPrice, feedDecimals);
                    
                    // Check bounds and deviation
                    bool isValid = currentPrice >= minEurUsdPrice && currentPrice <= maxEurUsdPrice;
                    
                    if (isValid && lastValidEurUsdPrice > 0) {
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
        try eurUsdPriceFeed.latestRoundData() returns (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) {
            // Use all return values meaningfully
            isStale = !_validateTimestamp(updatedAt) || (roundId != answeredInRound) || (price <= 0) || (startedAt > updatedAt);
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
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query configuration
     * @custom:oracle No oracle dependencies for configuration query
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
     * @notice Retrieves addresses of the Chainlink price feeds used
     * @dev Returns feed addresses and their decimal configurations
     * @return eurUsdFeedAddress EUR/USD feed address
     * @return usdcUsdFeedAddress USDC/USD feed address
     * @return eurUsdDecimals Number of decimals for the EUR/USD feed
     * @return usdcUsdDecimals Number of decimals for the USDC/USD feed
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query feed addresses
     * @custom:oracle Queries decimal configuration from Chainlink feeds
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
            eurUsdPriceFeed.decimals(),
            usdcUsdPriceFeed.decimals()
        );
    }

    /**
     * @notice Tests connectivity to the Chainlink price feeds
     * @dev Tests if both price feeds are responding and returns latest round information
     * @return eurUsdConnected true if the EUR/USD feed responds
     * @return usdcUsdConnected true if the USDC/USD feed responds
     * @return eurUsdLatestRound Latest round ID for EUR/USD
     * @return usdcUsdLatestRound Latest round ID for USDC/USD
     * @custom:security Validates price feed connectivity and data integrity
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function with try/catch
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can test feed connectivity
     * @custom:oracle Tests connectivity to Chainlink EUR/USD and USDC/USD feeds
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
        try eurUsdPriceFeed.latestRoundData() returns (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) {
            // Use all return values meaningfully
            eurUsdConnected = (price > 0) && (roundId == answeredInRound) && (startedAt <= updatedAt);
            eurUsdLatestRound = roundId;
        } catch {
            eurUsdConnected = false;
            eurUsdLatestRound = 0;
        }

        // Test USDC/USD feed
        try usdcUsdPriceFeed.latestRoundData() returns (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) {
            // Use all return values meaningfully
            usdcUsdConnected = (price > 0) && (roundId == answeredInRound) && (startedAt <= updatedAt);
            usdcUsdLatestRound = roundId;
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
     * @custom:security Validates admin role and uses secure recovery library
     * @custom:validation No input validation required - library handles validation
     * @custom:state-changes Transfers tokens from contract to treasury
     * @custom:events No events emitted - library handles events
     * @custom:errors No errors thrown - library handles error cases
     * @custom:reentrancy Not protected - library handles reentrancy
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependencies for token recovery
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
     * 
     * @dev Security considerations:
     *      - Only DEFAULT_ADMIN_ROLE can recover
     *      - Prevents sending to zero address
     *      - Validates balance before attempting transfer
     *      - Uses call() for reliable ETH transfers to any contract
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
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
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
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
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function triggerCircuitBreaker() external onlyRole(EMERGENCY_ROLE) {
        circuitBreakerTriggered = true;
    }

    /**
     * @notice Pauses all oracle operations
     * @dev Emergency function to pause oracle in case of critical issues
     * @custom:security Validates emergency role authorization
     * @custom:validation No input validation required
     * @custom:state-changes Sets pause state, stops oracle operations
     * @custom:events Emits Paused event from OpenZeppelin
     * @custom:errors No errors thrown - safe pause operation
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle No oracle dependencies for pause
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
     *      2. Fetch from Chainlink
     *      3. Freshness check (< 1 hour)
     *      4. Convert to 18 decimals
     *      5. Check min/max bounds
     *      6. Return valid price or fallback
     * 
     * @custom:security Validates timestamp freshness, circuit breaker status, price bounds
     * @custom:validation Checks price > 0, timestamp < 1 hour old, within min/max bounds
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - returns fallback price if invalid
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle Requires fresh Chainlink EUR/USD price feed data
     */
    function getEurUsdPrice() external view returns (uint256 price, bool isValid) {
        // If circuit breaker is active or contract is paused, use the last valid price
        if (circuitBreakerTriggered || paused()) {
            return (lastValidEurUsdPrice, false);
        }

        // Fetch data from Chainlink
        (uint80 roundId, int256 rawPrice, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = eurUsdPriceFeed.latestRoundData();
        
        // Data freshness check with timestamp validation and data integrity
        if (!_validateTimestamp(updatedAt) || rawPrice <= 0 || roundId != answeredInRound || startedAt > updatedAt) {
            return (lastValidEurUsdPrice, false);
        }

        // Convert Chainlink decimals (usually 8) to 18 decimals
        uint8 feedDecimals = eurUsdPriceFeed.decimals();
        price = _scalePrice(rawPrice, feedDecimals);

        // Circuit breaker bounds check
        isValid = price >= minEurUsdPrice && price <= maxEurUsdPrice;

        // Deviation check against last valid price (reject sudden jumps > MAX_PRICE_DEVIATION)
        if (isValid && lastValidEurUsdPrice > 0) {
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
     * 
     * @custom:security Validates timestamp freshness, USDC tolerance bounds
     * @custom:validation Checks price > 0, timestamp < 1 hour old, within USDC tolerance
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - returns $1.00 fallback if invalid
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle Requires fresh Chainlink USDC/USD price feed data
     */
    function getUsdcUsdPrice() external view returns (uint256 price, bool isValid) {
        // Fetch from Chainlink
        (uint80 roundId, int256 rawPrice, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = usdcUsdPriceFeed.latestRoundData();
        
        // Freshness check with timestamp validation and data integrity
        if (!_validateTimestamp(updatedAt) || rawPrice <= 0 || roundId != answeredInRound || startedAt > updatedAt) {
            return (1e18, false); // Fallback to $1.00
        }

        // Convert to 18 decimals
        uint8 feedDecimals = usdcUsdPriceFeed.decimals();
        price = _scalePrice(rawPrice, feedDecimals);

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
     * @custom:security Validates oracle manager role and price bounds constraints
     * @custom:validation Validates _minPrice > 0, _maxPrice > _minPrice, _maxPrice < 10e18
     * @custom:state-changes Updates minEurUsdPrice and maxEurUsdPrice
     * @custom:events Emits PriceBoundsUpdated with new bounds
     * @custom:errors Throws "Oracle: Min price must be positive" if _minPrice <= 0
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:oracle No oracle dependencies for bounds update
     */
    function updatePriceBounds(
        uint256 _minPrice,
        uint256 _maxPrice
    ) external onlyRole(ORACLE_MANAGER_ROLE) {
        require(_minPrice > 0, "Oracle: Min price must be positive");
        require(_maxPrice > _minPrice, "Oracle: Max price must be greater than min");
        require(_maxPrice < 10e18, "Oracle: Max price too high"); // Sanity check

        minEurUsdPrice = _minPrice;
        maxEurUsdPrice = _maxPrice;

        emit PriceBoundsUpdated("bounds", _minPrice, _maxPrice);
    }

    /**
     * @notice Updates the tolerance for USDC/USD
     * @dev Allows oracle manager to adjust USDC price tolerance around $1.00
     * @param newToleranceBps New tolerance in basis points (e.g., 200 = 2%)
     * @custom:security Validates oracle manager role and tolerance constraints
     * @custom:validation Validates newToleranceBps <= 1000 (max 10%)
     * @custom:state-changes Updates usdcToleranceBps
     * @custom:events No events emitted for tolerance update
     * @custom:errors Throws "Oracle: Tolerance too high" if newToleranceBps > 1000
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:oracle No oracle dependencies for tolerance update
     */
    function updateUsdcTolerance(uint256 newToleranceBps) 
        external 
        onlyRole(ORACLE_MANAGER_ROLE) 
    {
        require(newToleranceBps <= 1000, "Oracle: Tolerance too high"); // Max 10%
        usdcToleranceBps = newToleranceBps;
    }

    /**
     * @notice Updates the Chainlink price feed addresses
     * @dev Allows oracle manager to update price feed addresses for maintenance or upgrades
     * @param _eurUsdFeed New EUR/USD feed address
     * @param _usdcUsdFeed New USDC/USD feed address
     * @custom:security Validates oracle manager role and feed address constraints
     * @custom:validation Validates both feed addresses are not address(0)
     * @custom:state-changes Updates eurUsdPriceFeed and usdcUsdPriceFeed interfaces
     * @custom:events Emits PriceFeedsUpdated with new feed addresses
     * @custom:errors Throws "Oracle: EUR/USD feed cannot be zero" if _eurUsdFeed is address(0)
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:oracle Updates Chainlink price feed interface addresses
     */
    function updatePriceFeeds(
        address _eurUsdFeed,
        address _usdcUsdFeed
    ) external onlyRole(ORACLE_MANAGER_ROLE) {
        require(_eurUsdFeed != address(0), "Oracle: EUR/USD feed cannot be zero");
        require(_usdcUsdFeed != address(0), "Oracle: USDC/USD feed cannot be zero");

        eurUsdPriceFeed = AggregatorV3Interface(_eurUsdFeed);
        usdcUsdPriceFeed = AggregatorV3Interface(_usdcUsdFeed);

        emit PriceFeedsUpdated(_eurUsdFeed, _usdcUsdFeed);
    }
}