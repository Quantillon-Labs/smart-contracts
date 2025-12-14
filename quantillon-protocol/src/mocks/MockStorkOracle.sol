// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../interfaces/IStorkOracle.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../libraries/CommonValidationLibrary.sol";

/**
 * @title MockStorkOracle
 * @notice Mock oracle that implements IStorkOracle interface but uses mock data
 * @dev Used for localhost testing - provides same interface as StorkOracle
 * @author Quantillon Labs
 */
contract MockStorkOracle is IStorkOracle, Initializable, AccessControlUpgradeable, PausableUpgradeable {
    
    // Role definitions
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant ORACLE_MANAGER_ROLE = keccak256("ORACLE_MANAGER_ROLE");
    
    // Treasury address
    address public treasury;
    
    // Original admin address (immutable after initialization)
    address private originalAdmin;
    
    // Price bounds (same as StorkOracle)
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
    
    // Dev mode flag to disable spread deviation checks
    bool public devModeEnabled;
    
    // Events
    event PriceDeviationDetected(uint256 newPrice, uint256 lastPrice, uint256 deviationBps, uint256 blockNumber);
    event CircuitBreakerTriggered(uint256 blockNumber, string reason);
    event CircuitBreakerReset(uint256 blockNumber);
    event ETHRecovered(address indexed treasury, uint256 amount);
    event DevModeToggled(bool enabled, address indexed caller);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // Note: We don't disable initializers here because this mock is used directly, not as an implementation
    }
    
    /**
     * @notice Initializes the mock oracle
     * @param admin Admin address
     * @param _storkFeedAddress Mock Stork feed address (unused, kept for interface compatibility)
     * @param _eurUsdFeedId Mock EUR/USD feed ID (unused, kept for interface compatibility)
     * @param _usdcUsdFeedId Mock USDC/USD feed ID (unused, kept for interface compatibility)
     * @param _treasury Treasury address
     */
    function initialize(
        address admin,
        address _storkFeedAddress,
        bytes32 _eurUsdFeedId,
        bytes32 _usdcUsdFeedId,
        address _treasury
    ) external initializer {
        // Validate admin address before any assignments (fixes Slither ID-6)
        CommonValidationLibrary.validateNonZeroAddress(admin, "admin");
        
        __AccessControl_init();
        __Pausable_init();
        
        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);
        _grantRole(ORACLE_MANAGER_ROLE, admin);
        
        // Store original admin address for security
        originalAdmin = admin;
        treasury = _treasury != address(0) ? _treasury : admin; // Use admin as treasury if not provided
        
        // Parameters are unused in mock, but kept for interface compatibility
        // Suppress unused parameter warnings by referencing them
        _storkFeedAddress;
        _eurUsdFeedId;
        _usdcUsdFeedId;
        
        // Initialize with default prices
        lastValidEurUsdPrice = 1.08e18; // 1.08 USD
        lastValidUsdcUsdPrice = 1.00e18; // 1.00 USD
        lastPriceUpdateBlock = block.number;
    }
    
    /**
     * @notice Gets the current EUR/USD price with validation
     * @return price EUR/USD price in 18 decimals
     * @return isValid True if price is valid and fresh
     */
    function getEurUsdPrice() external view override returns (uint256 price, bool isValid) {
        // If circuit breaker is active or contract is paused, use the last valid price
        if (circuitBreakerTriggered || paused()) {
            return (lastValidEurUsdPrice, false);
        }

        // Return last valid price (mock implementation)
        price = lastValidEurUsdPrice;
        isValid = price >= MIN_EUR_USD_PRICE && price <= MAX_EUR_USD_PRICE;
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

        // Return last valid price (mock implementation)
        price = lastValidUsdcUsdPrice;
        isValid = price >= MIN_USDC_USD_PRICE && price <= MAX_USDC_USD_PRICE;
    }
    
    /**
     * @notice Updates treasury address
     * @param _treasury New treasury address
     */
    function updateTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasury != address(0), "Treasury cannot be zero address");
        CommonValidationLibrary.validateNonZeroAddress(_treasury, "treasury");
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
    function getOracleHealth() external view override returns (bool isHealthy, bool eurUsdFresh, bool usdcUsdFresh) {
        isHealthy = !circuitBreakerTriggered && !paused();
        eurUsdFresh = lastValidEurUsdPrice > 0;
        usdcUsdFresh = lastValidUsdcUsdPrice > 0;
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
        currentPrice = lastValidEurUsdPrice;
        lastValidPrice = lastValidEurUsdPrice;
        lastUpdate = block.timestamp;
        isStale = false; // Mock data is never stale
        withinBounds = currentPrice >= MIN_EUR_USD_PRICE && currentPrice <= MAX_EUR_USD_PRICE;
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
        eurUsdFeedAddress = address(this); // Mock feed address
        usdcUsdFeedAddress = address(this); // Mock feed address
        eurUsdDecimals = 18; // Mock feeds use 18 decimals
        usdcUsdDecimals = 18; // Mock feeds use 18 decimals
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
        eurUsdConnected = lastValidEurUsdPrice > 0;
        usdcUsdConnected = lastValidUsdcUsdPrice > 0;
        eurUsdLatestRound = 1; // Mock round ID
        usdcUsdLatestRound = 1; // Mock round ID
    }
    
    /**
     * @notice Mock implementation of updatePriceBounds
     */
    function updatePriceBounds(uint256 _minPrice, uint256 _maxPrice) external override onlyRole(ORACLE_MANAGER_ROLE) {
        // Mock implementation - in real oracle this would update bounds
        // For mock, we just emit an event or do nothing
    }
    
    /**
     * @notice Mock implementation of updateUsdcTolerance
     */
    function updateUsdcTolerance(uint256 newToleranceBps) external override onlyRole(ORACLE_MANAGER_ROLE) {
        // Mock implementation - in real oracle this would update tolerance
        // For mock, we just emit an event or do nothing
    }
    
    /**
     * @notice Mock implementation of updatePriceFeeds
     */
    function updatePriceFeeds(address _storkFeedAddress, bytes32 _eurUsdFeedId, bytes32 _usdcUsdFeedId) external view override onlyRole(ORACLE_MANAGER_ROLE) {
        // Mock implementation - in real oracle this would update feeds
        // For mock, we just emit an event or do nothing
        // Suppress unused parameter warnings by referencing them (fixes Slither ID-25-30)
        _storkFeedAddress;
        _eurUsdFeedId;
        _usdcUsdFeedId;
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
    
    /**
     * @notice Set the EUR/USD price for testing purposes
     * @dev Only available in mock oracle for testing
     * @param _price The new EUR/USD price in 18 decimals
     */
    function setPrice(uint256 _price) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_price > 0, "Price must be positive");
        require(_price >= MIN_EUR_USD_PRICE && _price <= MAX_EUR_USD_PRICE, "Price out of bounds");
        
        lastValidEurUsdPrice = _price;
        lastPriceUpdateBlock = block.number;
        
        emit PriceDeviationDetected(_price, lastValidEurUsdPrice, 0, block.number);
    }
    
    /**
     * @notice Set the USDC/USD price for testing purposes
     * @dev Only available in mock oracle for testing
     * @param _price The new USDC/USD price in 18 decimals
     */
    function setUsdcUsdPrice(uint256 _price) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_price > 0, "Price must be positive");
        require(_price >= MIN_USDC_USD_PRICE && _price <= MAX_USDC_USD_PRICE, "Price out of bounds");
        
        lastValidUsdcUsdPrice = _price;
        lastPriceUpdateBlock = block.number;
        
        emit PriceDeviationDetected(_price, lastValidUsdcUsdPrice, 0, block.number);
    }
    
    /**
     * @notice Set both EUR/USD and USDC/USD prices for testing purposes
     * @dev Only available in mock oracle for testing
     * @param _eurUsdPrice The new EUR/USD price in 18 decimals
     * @param _usdcUsdPrice The new USDC/USD price in 18 decimals
     */
    function setPrices(uint256 _eurUsdPrice, uint256 _usdcUsdPrice) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_eurUsdPrice > 0, "EUR/USD price must be positive");
        require(_usdcUsdPrice > 0, "USDC/USD price must be positive");
        require(_eurUsdPrice >= MIN_EUR_USD_PRICE && _eurUsdPrice <= MAX_EUR_USD_PRICE, "EUR/USD price out of bounds");
        require(_usdcUsdPrice >= MIN_USDC_USD_PRICE && _usdcUsdPrice <= MAX_USDC_USD_PRICE, "USDC/USD price out of bounds");
        
        lastValidEurUsdPrice = _eurUsdPrice;
        lastValidUsdcUsdPrice = _usdcUsdPrice;
        lastPriceUpdateBlock = block.number;
        
        emit PriceDeviationDetected(_eurUsdPrice, lastValidEurUsdPrice, 0, block.number);
    }
    
    /**
     * @notice Toggles dev mode to disable spread deviation checks
     * @dev DEV ONLY: When enabled, price deviation checks are skipped for testing
     * @param enabled True to enable dev mode, false to disable
     */
    function setDevMode(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        devModeEnabled = enabled;
        emit DevModeToggled(enabled, msg.sender);
    }
}

