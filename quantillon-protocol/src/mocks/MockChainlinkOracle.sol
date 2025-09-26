// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../interfaces/IChainlinkOracle.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "../libraries/CommonValidationLibrary.sol";

/**
 * @title MockChainlinkOracle
 * @notice Mock oracle that implements IChainlinkOracle interface but uses mock feeds
 * @dev Used for localhost testing - provides same interface as ChainlinkOracle
 * @author Quantillon Labs
 */
contract MockChainlinkOracle is IChainlinkOracle, Initializable, AccessControlUpgradeable, PausableUpgradeable {
    
    // Role definitions
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    // Mock feed interfaces
    AggregatorV3Interface public eurUsdPriceFeed;
    AggregatorV3Interface public usdcUsdPriceFeed;
    
    // Treasury address
    address public treasury;
    
    // Original admin address (immutable after initialization)
    address private originalAdmin;
    
    // Price bounds (same as ChainlinkOracle)
    uint256 public constant MIN_EUR_USD_PRICE = 0.5e18;  // 0.5 USD
    uint256 public constant MAX_EUR_USD_PRICE = 2.0e18;  // 2.0 USD
    uint256 public constant MIN_USDC_USD_PRICE = 0.95e18; // 0.95 USD
    uint256 public constant MAX_USDC_USD_PRICE = 1.05e18; // 1.05 USD
    
    // Price deviation protection
    uint256 public constant MAX_PRICE_DEVIATION = 500; // 5% in basis points
    uint256 public lastValidEurUsdPrice;
    uint256 public lastValidUsdcUsdPrice;
    uint256 public lastPriceUpdateBlock;
    uint256 public constant MIN_BLOCKS_BETWEEN_UPDATES = 1;
    
    // Circuit breaker
    bool public circuitBreakerTriggered;
    
    // Events
    event PriceDeviationDetected(uint256 newPrice, uint256 lastPrice, uint256 deviationBps, uint256 blockNumber);
    event CircuitBreakerTriggered(uint256 blockNumber, string reason);
    event CircuitBreakerReset(uint256 blockNumber);
    event ETHRecovered(address indexed treasury, uint256 amount);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @notice Initializes the mock oracle
     * @param admin Admin address
     * @param _eurUsdPriceFeed Mock EUR/USD feed address
     * @param _usdcUsdPriceFeed Mock USDC/USD feed address
     */
    function initialize(
        address admin,
        address _eurUsdPriceFeed,
        address _usdcUsdPriceFeed,
        address /* _treasury */
    ) external initializer {
        CommonValidationLibrary.validateNonZeroAddress(admin, "admin");
        CommonValidationLibrary.validateNonZeroAddress(_eurUsdPriceFeed, "oracle");
        CommonValidationLibrary.validateNonZeroAddress(_usdcUsdPriceFeed, "oracle");
        
        __AccessControl_init();
        __Pausable_init();
        
        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);
        
        // Set feed addresses
        eurUsdPriceFeed = AggregatorV3Interface(_eurUsdPriceFeed);
        usdcUsdPriceFeed = AggregatorV3Interface(_usdcUsdPriceFeed);
        require(admin != address(0), "Admin cannot be zero address");
        CommonValidationLibrary.validateNonZeroAddress(admin, "admin");
        
        // Store original admin address for security
        originalAdmin = admin;
        treasury = admin; // Use admin as treasury for mock
        
        // Initialize with default prices (no recursive calls during initialization)
        lastValidEurUsdPrice = 1.08e18; // 1.08 USD
        lastValidUsdcUsdPrice = 1.00e18; // 1.00 USD
        lastPriceUpdateBlock = block.number;
    }
    
    /**
     * @notice Gets the current EUR/USD price with validation and auto-updates lastValidEurUsdPrice
     * @return price EUR/USD price in 18 decimals
     * @return isValid True if price is valid and fresh
     */
    function getEurUsdPrice() external override returns (uint256 price, bool isValid) {
        // If circuit breaker is active or contract is paused, use the last valid price
        if (circuitBreakerTriggered || paused()) {
            return (lastValidEurUsdPrice, false);
        }

        // Fetch data from mock feed
        (uint80 roundId, int256 rawPrice, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = eurUsdPriceFeed.latestRoundData();
        
        // Data freshness check (more lenient for mock feeds)
        if (rawPrice <= 0 || roundId != answeredInRound || startedAt > updatedAt) {
            return (lastValidEurUsdPrice, false);
        }

        // Convert Chainlink decimals (usually 8) to 18 decimals
        uint8 feedDecimals = eurUsdPriceFeed.decimals();
        price = _scalePrice(rawPrice, feedDecimals);

        // Circuit breaker bounds check
        isValid = price >= MIN_EUR_USD_PRICE && price <= MAX_EUR_USD_PRICE;

        // For mock oracle, always update lastValidEurUsdPrice to enable step-by-step changes
        // This allows gradual price changes without hitting deviation limits
        if (isValid) {
            lastValidEurUsdPrice = price;
            lastPriceUpdateBlock = block.number;
        }
        
        return (price, isValid);
    }
    
    /**
     * @notice Gets the current USDC/USD price with validation
     * @return price USDC/USD price in 18 decimals
     * @return isValid True if price is valid and fresh
     */
    function getUsdcUsdPrice() external view override returns (uint256 price, bool isValid) {
        // If circuit breaker is active or contract is paused, use the last valid price
        if (circuitBreakerTriggered || paused()) {
            return (lastValidUsdcUsdPrice, false);
        }

        // Fetch data from mock feed
        (uint80 roundId, int256 rawPrice, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = usdcUsdPriceFeed.latestRoundData();
        
        // Data freshness check (more lenient for mock feeds)
        if (rawPrice <= 0 || roundId != answeredInRound || startedAt > updatedAt) {
            return (lastValidUsdcUsdPrice, false);
        }

        // Convert Chainlink decimals (usually 8) to 18 decimals
        uint8 feedDecimals = usdcUsdPriceFeed.decimals();
        price = _scalePrice(rawPrice, feedDecimals);

        // Circuit breaker bounds check
        isValid = price >= MIN_USDC_USD_PRICE && price <= MAX_USDC_USD_PRICE;

        // Deviation check against last valid price
        if (isValid && lastValidUsdcUsdPrice > 0) {
            uint256 base = lastValidUsdcUsdPrice;
            uint256 diff = price > base ? price - base : base - price;
    
            uint256 deviationBps = _divRound(diff * 10000, base);
            if (deviationBps > MAX_PRICE_DEVIATION) {
                isValid = false;
            }
        }
        
        return (price, isValid);
    }
    
    /**
     * @notice Updates prices and validates them
     * @dev Internal function to update and validate current prices
     */
    function _updatePrices() internal {
        // Update block number first (EFFECTS - before external calls)
        lastPriceUpdateBlock = block.number;
        
        // Calculate new prices directly without external calls to avoid reentrancy
        // This is a mock oracle, so we can calculate prices directly
        uint256 eurUsdPrice = _calculateEurUsdPrice();
        uint256 usdcUsdPrice = _calculateUsdcUsdPrice();
        
        // Update state variables (EFFECTS)
        lastValidEurUsdPrice = eurUsdPrice;
        lastValidUsdcUsdPrice = usdcUsdPrice;
    }
    
    /**
     * @notice Internal function to calculate EUR/USD price
     * @dev Avoids external calls to prevent reentrancy
     */
    function _calculateEurUsdPrice() internal pure returns (uint256) {
        // Mock price calculation - in real implementation this would be from external source
        return 1.10e9; // 1.10 * 1e9 (9 decimals)
    }
    
    /**
     * @notice Internal function to calculate USDC/USD price
     * @dev Avoids external calls to prevent reentrancy
     */
    function _calculateUsdcUsdPrice() internal pure returns (uint256) {
        // Mock price calculation - in real implementation this would be from external source
        return 1.00e9; // 1.00 * 1e9 (9 decimals)
    }
    
    /**
     * @notice Scales price from feed decimals to 18 decimals
     * @param price Price from feed
     * @param feedDecimals Number of decimals in the feed
     * @return Scaled price in 18 decimals
     */
    function _scalePrice(int256 price, uint8 feedDecimals) internal pure returns (uint256) {
        if (feedDecimals >= 18) {
            return uint256(price) / (10 ** (feedDecimals - 18));
        } else {
            return uint256(price) * (10 ** (18 - feedDecimals));
        }
    }
    
    /**
     * @notice Divides with rounding
     * @param a Numerator
     * @param b Denominator
     * @return Result with rounding
     */
    function _divRound(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a + b / 2) / b;
    }
    
    /**
     * @notice Updates treasury address
     * @param _treasury New treasury address
     * @dev Treasury can only be updated to the original admin address to prevent arbitrary sends
     */
    function updateTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasury != address(0), "Treasury cannot be zero address");
        CommonValidationLibrary.validateNonZeroAddress(_treasury, "treasury");
        
        // Only allow setting treasury to the original admin address
        CommonValidationLibrary.validateCondition(_treasury == originalAdmin, "authorization");
        
        treasury = _treasury;
    }
    
    /**
     * @notice Unpauses the contract
     */
    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }
    
    /**
     * @notice Recovers ETH sent to the contract
     * @dev Only sends ETH to the original admin address to prevent arbitrary sends
     */
    function recoverETH() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        CommonValidationLibrary.validatePositiveAmount(balance);
        
        // Use the original admin address (the one who deployed the contract)
        // This prevents arbitrary sends by ensuring ETH only goes to the original deployer
        CommonValidationLibrary.validateNonZeroAddress(originalAdmin, "admin");
        CommonValidationLibrary.validateCondition(originalAdmin != address(this), "self");
        
        emit ETHRecovered(originalAdmin, balance);
        
        // Use a safer transfer method - payable transfer to a known address
        payable(originalAdmin).transfer(balance);
    }
    
    /**
     * @notice Resets the circuit breaker
     */
    function resetCircuitBreaker() external onlyRole(EMERGENCY_ROLE) {
        circuitBreakerTriggered = false;
        emit CircuitBreakerReset(block.number);
        _updatePrices(); // Attempt immediate update
    }
    
    /**
     * @notice Triggers the circuit breaker
     */
    function triggerCircuitBreaker() external onlyRole(EMERGENCY_ROLE) {
        circuitBreakerTriggered = true;
        emit CircuitBreakerTriggered(block.number, "Manual trigger");
    }
    
    /**
     * @notice Pauses the contract
     */
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }
    
    // Receive function to accept ETH
    receive() external payable {}
    
    // =============================================================================
    // MISSING INTERFACE FUNCTIONS (Mock implementations)
    // =============================================================================
    
    /**
     * @notice Mock implementation of getOracleHealth
     */
    function getOracleHealth() external pure override returns (bool isHealthy, bool eurUsdFresh, bool usdcUsdFresh) {
        // Use internal calculations to avoid external calls
        uint256 eurUsdPrice = _calculateEurUsdPrice();
        uint256 usdcUsdPrice = _calculateUsdcUsdPrice();
        
        // Validate that prices are reasonable (not zero)
        CommonValidationLibrary.validatePositiveAmount(eurUsdPrice);
        CommonValidationLibrary.validatePositiveAmount(usdcUsdPrice);
        
        isHealthy = true; // Mock oracle is always healthy
        eurUsdFresh = true;
        usdcUsdFresh = true;
    }
    
    /**
     * @notice Mock implementation of getEurUsdDetails
     */
    function getEurUsdDetails() external view override returns (
        uint256 currentPrice,
        uint256 lastValidPrice,
        uint256 lastUpdate,
        bool isStale,
        bool withinBounds
    ) {
        // Use internal calculation to avoid external calls
        currentPrice = _calculateEurUsdPrice();
        lastValidPrice = currentPrice;
        lastUpdate = block.timestamp;
        isStale = false; // Mock data is never stale
        withinBounds = true; // Mock data is always within bounds
    }
    
    /**
     * @notice Mock implementation of getOracleConfig
     */
    function getOracleConfig() external view override returns (
        uint256 minPrice,
        uint256 maxPrice,
        uint256 maxStaleness,
        uint256 usdcTolerance,
        bool circuitBreakerActive
    ) {
        minPrice = MIN_EUR_USD_PRICE;
        maxPrice = MAX_EUR_USD_PRICE;
        maxStaleness = 3600; // 1 hour
        usdcTolerance = 100; // 1%
        circuitBreakerActive = circuitBreakerTriggered;
    }
    
    /**
     * @notice Mock implementation of getPriceFeedAddresses
     */
    function getPriceFeedAddresses() external view override returns (
        address eurUsdFeedAddress,
        address usdcUsdFeedAddress,
        uint8 eurUsdDecimals,
        uint8 usdcUsdDecimals
    ) {
        eurUsdFeedAddress = address(eurUsdPriceFeed);
        usdcUsdFeedAddress = address(usdcUsdPriceFeed);
        eurUsdDecimals = 8; // Mock feeds use 8 decimals
        usdcUsdDecimals = 8; // Mock feeds use 8 decimals
    }
    
    /**
     * @notice Mock implementation of checkPriceFeedConnectivity
     */
    function checkPriceFeedConnectivity() external view override returns (
        bool eurUsdConnected,
        bool usdcUsdConnected,
        uint80 eurUsdLatestRound,
        uint80 usdcUsdLatestRound
    ) {
        eurUsdConnected = address(eurUsdPriceFeed) != address(0);
        usdcUsdConnected = address(usdcUsdPriceFeed) != address(0);
        eurUsdLatestRound = 1; // Mock round ID
        usdcUsdLatestRound = 1; // Mock round ID
    }
    
    /**
     * @notice Mock implementation of updatePriceBounds
     */
    function updatePriceBounds(uint256 _minPrice, uint256 _maxPrice) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        // Mock implementation - in real oracle this would update bounds
        // For mock, we just emit an event or do nothing
    }
    
    /**
     * @notice Mock implementation of updateUsdcTolerance
     */
    function updateUsdcTolerance(uint256 newToleranceBps) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        // Mock implementation - in real oracle this would update tolerance
        // For mock, we just emit an event or do nothing
    }
    
    /**
     * @notice Mock implementation of updatePriceFeeds
     */
    function updatePriceFeeds(address _eurUsdFeed, address _usdcUsdFeed) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        CommonValidationLibrary.validateNonZeroAddress(_eurUsdFeed, "oracle");
        CommonValidationLibrary.validateNonZeroAddress(_usdcUsdFeed, "oracle");
        
        eurUsdPriceFeed = AggregatorV3Interface(_eurUsdFeed);
        usdcUsdPriceFeed = AggregatorV3Interface(_usdcUsdFeed);
    }
    
    /**
     * @notice Mock implementation of recoverToken
     */
    function recoverToken(address token, uint256 amount) external view override onlyRole(DEFAULT_ADMIN_ROLE) {
        CommonValidationLibrary.validateNonZeroAddress(token, "token");
        CommonValidationLibrary.validatePositiveAmount(amount);
        // Mock implementation - in real oracle this would recover tokens to treasury
        // For mock, we just emit an event or do nothing
    }
    
}
