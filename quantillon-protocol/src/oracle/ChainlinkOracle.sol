// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// =============================================================================
// IMPORTS - Chainlink interfaces and OpenZeppelin security
// =============================================================================

// Standard interface for Chainlink price feeds
import "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

// OpenZeppelin role system
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

// Emergency pause mechanism
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

// Initialization pattern for upgradeable contracts
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// UUPS upgrade pattern
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// ERC20 interface and SafeERC20 for safe transfers
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Treasury recovery library for secure ETH recovery
import "../libraries/TreasuryRecoveryLibrary.sol";

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
 * @author Quantillon Labs
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

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the oracle contract with Chainlink price feeds
     * 
     * @param admin Address with administrator privileges
     * @param _eurUsdPriceFeed Chainlink EUR/USD price feed address on Base
     * @param _usdcUsdPriceFeed Chainlink USDC/USD price feed address on Base
     * @param _treasury Treasury address for ETH recovery
     * 
     * @dev This function:
     *      1. Configures access roles
     *      2. Initializes Chainlink interfaces
     *      3. Sets default price bounds
     *      4. Performs an initial price update
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
     */
    function updateTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasury != address(0), "Oracle: Treasury cannot be zero");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    /**
     * @notice Removes pause and resumes oracle operations
     */
    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }

    // =============================================================================
    // INTERNAL FUNCTIONS - Utility internal functions
    // =============================================================================

    /**
     * @notice Performs division with proper rounding to nearest integer
     * 
     * @param a Numerator
     * @param b Denominator
     * @return Result of division with rounding to nearest
     * 

     */
    function _divRound(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "Oracle: Division by zero");
        return (a + b / 2) / b;
    }

    /**
     * @notice Validates if a timestamp is recent enough to prevent manipulation attacks
     * @param reportedTime The timestamp to validate
     * @return true if the timestamp is valid, false otherwise
     */
    function _validateTimestamp(uint256 reportedTime) internal view returns (bool) {
        // Reject if reported time is in the future
        if (reportedTime > block.timestamp) return false;
        
        // Check if the timestamp is too old (beyond normal staleness + drift)
        // Use safe arithmetic to prevent underflow
        uint256 maxAllowedAge = MAX_PRICE_STALENESS + MAX_TIMESTAMP_DRIFT;
        if (block.timestamp > reportedTime + maxAllowedAge) return false;
        
        return true;
    }

    /**
     * @notice Updates and validates internal prices
     * @dev Internal function called during initialization and resets
     * @dev FIXED: No longer calls external functions on itself during initialization
     */
    function _updatePrices() internal {
        // Fetch EUR/USD price data directly from Chainlink
        // SECURITY: Only need price and timestamp, ignore other return values (roundId, answer, answeredInRound)
        (uint80 eurUsdRoundId, int256 eurUsdRawPrice, uint256 eurUsdStartedAt, uint256 eurUsdUpdatedAt, uint80 eurUsdAnsweredInRound) = eurUsdPriceFeed.latestRoundData();
        // Note: eurUsdRoundId, eurUsdStartedAt, and eurUsdAnsweredInRound are intentionally unused for price updates
        
        // Fetch USDC/USD price data directly from Chainlink
        // SECURITY: Only need price and timestamp, ignore other return values (roundId, answer, answeredInRound)
        (uint80 usdcUsdRoundId, int256 usdcUsdRawPrice, uint256 usdcUsdStartedAt, uint256 usdcUsdUpdatedAt, uint80 usdcUsdAnsweredInRound) = usdcUsdPriceFeed.latestRoundData();
        // Note: usdcUsdRoundId, usdcUsdStartedAt, and usdcUsdAnsweredInRound are intentionally unused for price updates
        
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
        lastPriceUpdateTime = block.timestamp;
        lastPriceUpdateBlock = block.number;

        // Emit update event
        emit PriceUpdated(eurUsdPrice, usdcUsdPrice, block.timestamp);
    }

    /**
     * @notice Scale price to 18 decimals for consistency
     * @param rawPrice Raw price from Chainlink
     * @param decimals Number of decimals in raw price
     * @return Scaled price with 18 decimals
     * @dev FIXED: Now scales to 18 decimals instead of 8 to match contract expectations
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
     * 
     * @return isHealthy true if everything operates normally
     * @return eurUsdFresh true if EUR/USD price is fresh
     * @return usdcUsdFresh true if USDC/USD price is fresh
     * 
     * @dev Used by UI and monitoring systems to display real-time status
     * @dev FIXED: No longer calls external functions on itself
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
            uint80 eurUsdRoundId,
            int256 eurUsdPrice,
            uint256 eurUsdStartedAt,
            uint256 updatedAt,
            uint80 eurUsdAnsweredInRound
        ) {
            eurUsdFresh = _validateTimestamp(updatedAt);
            // Note: eurUsdRoundId, eurUsdPrice, eurUsdStartedAt, and eurUsdAnsweredInRound are intentionally unused for health checks
        } catch {
            eurUsdFresh = false;
        }
        
        // Check USDC/USD price freshness directly
        try usdcUsdPriceFeed.latestRoundData() returns (
            uint80 usdcUsdRoundId,
            int256 usdcUsdPrice,
            uint256 usdcUsdStartedAt,
            uint256 updatedAt,
            uint80 usdcUsdAnsweredInRound
        ) {
            usdcUsdFresh = _validateTimestamp(updatedAt);
            // Note: usdcUsdRoundId, usdcUsdPrice, usdcUsdStartedAt, and usdcUsdAnsweredInRound are intentionally unused for health checks
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
     * 
     * @return currentPrice Current price (may be fallback)
     * @return lastValidPrice Last validated price
     * @return lastUpdate Timestamp of last update
     * @return isStale true if the price is stale
     * @return withinBounds true if within acceptable bounds
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
                // Note: roundId, startedAt, and answeredInRound are intentionally unused for price details
                if (_validateTimestamp(updatedAt) && rawPrice > 0) {
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
            isStale = !_validateTimestamp(updatedAt);
            // Note: roundId, price, startedAt, and answeredInRound are intentionally unused for staleness checks
        } catch {
            isStale = true;
        }
        
        // Bounds check
        withinBounds = currentPrice >= minEurUsdPrice && currentPrice <= maxEurUsdPrice;
    }

    /**
     * @notice Retrieves current configuration parameters
     * 
     * @return minPrice Minimum EUR/USD price
     * @return maxPrice Maximum EUR/USD price
     * @return maxStaleness Maximum duration before staleness
     * @return usdcTolerance USDC tolerance in basis points
     * @return circuitBreakerActive Circuit breaker status
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
     * 
     * @return eurUsdFeedAddress EUR/USD feed address
     * @return usdcUsdFeedAddress USDC/USD feed address
     * @return eurUsdDecimals Number of decimals for the EUR/USD feed
     * @return usdcUsdDecimals Number of decimals for the USDC/USD feed
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
     * 
     * @return eurUsdConnected true if the EUR/USD feed responds
     * @return usdcUsdConnected true if the USDC/USD feed responds
     * @return eurUsdLatestRound Latest round ID for EUR/USD
     * @return usdcUsdLatestRound Latest round ID for USDC/USD
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
            eurUsdConnected = true;
            eurUsdLatestRound = roundId;
            // Note: price, startedAt, updatedAt, and answeredInRound are intentionally unused for connectivity checks
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
            usdcUsdConnected = true;
            usdcUsdLatestRound = roundId;
            // Note: price, startedAt, updatedAt, and answeredInRound are intentionally unused for connectivity checks
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
     * @param token Address of the token to recover
     * @param amount Amount to recover
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
     */
    function triggerCircuitBreaker() external onlyRole(EMERGENCY_ROLE) {
        circuitBreakerTriggered = true;
    }

    /**
     * @notice Pauses all oracle operations
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
     */
    function getEurUsdPrice() external view returns (uint256 price, bool isValid) {
        // If circuit breaker is active or contract is paused, use the last valid price
        if (circuitBreakerTriggered || paused()) {
            return (lastValidEurUsdPrice, false);
        }

        // Fetch data from Chainlink
        // SECURITY: Only need price and timestamp, ignore other return values (roundId, answer, answeredInRound)
        (uint80 roundId, int256 rawPrice, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = eurUsdPriceFeed.latestRoundData();
        // Note: roundId, startedAt, and answeredInRound are intentionally unused for price fetching
        
        // Data freshness check with timestamp validation
        if (!_validateTimestamp(updatedAt)) {
            return (lastValidEurUsdPrice, false);
        }

        // Ensure price is positive
        if (rawPrice <= 0) {
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
     */
    function getUsdcUsdPrice() external view returns (uint256 price, bool isValid) {
        // Fetch from Chainlink
        // SECURITY: Only need price and timestamp, ignore other return values (roundId, answer, answeredInRound)
        (uint80 roundId, int256 rawPrice, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = usdcUsdPriceFeed.latestRoundData();
        // Note: roundId, startedAt, and answeredInRound are intentionally unused for price fetching
        
        // Freshness check with timestamp validation
        if (!_validateTimestamp(updatedAt) || rawPrice <= 0) {
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
     * 
     * @param _minPrice Minimum accepted EUR/USD price (18 decimals)
     * @param _maxPrice Maximum accepted EUR/USD price (18 decimals)
     * 
     * @dev Used to adjust thresholds according to market conditions.
     *      Example: widen the range during a crisis.
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
     * @param newToleranceBps New tolerance in basis points
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
     * 
     * @param _eurUsdFeed New EUR/USD feed address
     * @param _usdcUsdFeed New USDC/USD feed address
     * 
     * @dev Used if Chainlink updates its contracts or to switch to newer, more precise feeds
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