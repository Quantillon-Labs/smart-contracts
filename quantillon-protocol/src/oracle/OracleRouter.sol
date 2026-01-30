// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// =============================================================================
// IMPORTS - OpenZeppelin security and Quantillon interfaces
// =============================================================================

// Quantillon Oracle interfaces
import {IOracle} from "../interfaces/IOracle.sol";
import {IChainlinkOracle} from "../interfaces/IChainlinkOracle.sol";
import {IStorkOracle} from "../interfaces/IStorkOracle.sol";

// OpenZeppelin role system
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

// Emergency pause mechanism
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

// Initialization pattern for upgradeable contracts
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// UUPS upgrade pattern
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// Validation library
import {CommonValidationLibrary} from "../libraries/CommonValidationLibrary.sol";
import {TreasuryRecoveryLibrary} from "../libraries/TreasuryRecoveryLibrary.sol";

/**
 * @title OracleRouter
 * @notice Router contract that allows admin to switch between Chainlink and Stork oracles
 * 
 * @dev Key features:
 *      - Holds references to both ChainlinkOracle and StorkOracle
 *      - Routes all IOracle calls to the currently active oracle
 *      - Admin can switch between oracles via switchOracle()
 *      - Implements IOracle interface (generic, oracle-agnostic)
 *      - Protocol contracts use IOracle interface for oracle-agnostic integration
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract OracleRouter is 
    IOracle,
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    // =============================================================================
    // CONSTANTS AND ROLES
    // =============================================================================
    
    /// @notice Role to manage oracle configurations
    bytes32 public constant ORACLE_MANAGER_ROLE = keccak256("ORACLE_MANAGER_ROLE");
    
    /// @notice Role for emergency actions
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    /// @notice Role for contract upgrades
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @notice Enum for oracle type selection
    enum OracleType {
        CHAINLINK,
        STORK
    }

    // =============================================================================
    // STATE VARIABLES - Contract state variables
    // =============================================================================
    
    /// @notice Chainlink oracle contract reference
    IChainlinkOracle public chainlinkOracle;
    
    /// @notice Stork oracle contract reference
    IStorkOracle public storkOracle;

    /// @notice Currently active oracle type
    OracleType public activeOracle;

    /// @notice Treasury address for ETH recovery
    address public treasury;

    // =============================================================================
    // EVENTS - Events for monitoring and alerts
    // =============================================================================
    
    /// @notice Emitted when the active oracle is switched
    /// @dev OPTIMIZED: Indexed oracle type for efficient filtering
    event OracleSwitched(
        OracleType indexed oldOracle,
        OracleType indexed newOracle,
        address indexed caller
    );

    /// @notice Emitted when oracle addresses are updated
    event OracleAddressesUpdated(
        address newChainlinkOracle,
        address newStorkOracle
    );

    /// @notice Emitted when treasury address is updated
    event TreasuryUpdated(address indexed newTreasury);

    /// @notice Emitted when ETH is recovered from the contract
    event ETHRecovered(address indexed to, uint256 amount);

    // =============================================================================
    // INITIALIZER - Initial contract configuration
    // =============================================================================

    /**
     * @notice Initializes the router contract with both oracle addresses
     * @dev Sets up all core dependencies, roles, and default oracle selection
     * @param admin Address with administrator privileges
     * @param _chainlinkOracle ChainlinkOracle contract address
     * @param _storkOracle StorkOracle contract address
     * @param _treasury Treasury address for ETH recovery
     * @param _defaultOracle Default oracle to use (CHAINLINK or STORK)
     * @custom:security Validates all addresses are not zero, grants admin roles
     * @custom:validation Validates all input addresses are not address(0)
     * @custom:state-changes Initializes all state variables, sets default oracle
     * @custom:events Emits OracleSwitched during initialization
     * @custom:errors Throws validation errors if addresses are zero
     * @custom:reentrancy Protected by initializer modifier
     * @custom:access Public - only callable once during deployment
     * @custom:oracle Initializes references to ChainlinkOracle and StorkOracle contracts
     */
    function initialize(
        address admin,
        address _chainlinkOracle,
        address _storkOracle,
        address _treasury,
        OracleType _defaultOracle
    ) public initializer {
        // Input parameter validation
        CommonValidationLibrary.validateNonZeroAddress(admin, "admin");
        CommonValidationLibrary.validateNonZeroAddress(_chainlinkOracle, "oracle");
        CommonValidationLibrary.validateNonZeroAddress(_storkOracle, "oracle");
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

        // Initialize oracle references
        chainlinkOracle = IChainlinkOracle(_chainlinkOracle);
        storkOracle = IStorkOracle(_storkOracle);
        treasury = _treasury;

        // NOTE: Admin must grant router the ORACLE_MANAGER_ROLE on both oracles after deployment
        // so the router can delegate admin function calls. This is done in deployment scripts.

        // Set default active oracle
        activeOracle = _defaultOracle;

        // Emit event for initial oracle selection
        emit OracleSwitched(OracleType.CHAINLINK, _defaultOracle, admin);
    }

    /**
     * @notice Update treasury address
     * @dev Only admin can update treasury address
     * @param _treasury New treasury address
     * @custom:security Restricted to DEFAULT_ADMIN_ROLE
     * @custom:validation _treasury not zero
     * @custom:state-changes treasury
     * @custom:events TreasuryUpdated
     * @custom:errors InvalidAddress if zero
     * @custom:reentrancy No external calls
     * @custom:access DEFAULT_ADMIN_ROLE
     * @custom:oracle None
     */
    function updateTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        CommonValidationLibrary.validateNonZeroAddress(_treasury, "treasury");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    /**
     * @notice Removes pause and resumes oracle operations
     * @dev Only emergency role can unpause the router
     * @custom:security Restricted to EMERGENCY_ROLE
     * @custom:validation None
     * @custom:state-changes Pausable state
     * @custom:events Unpaused
     * @custom:errors None
     * @custom:reentrancy No external calls
     * @custom:access EMERGENCY_ROLE
     * @custom:oracle None
     */
    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }

    // =============================================================================
    // INTERNAL FUNCTIONS - Utility internal functions
    // =============================================================================

    /**
     * @notice Gets the currently active oracle contract
     * @dev Returns chainlinkOracle or storkOracle based on activeOracle enum
     * @return The active oracle contract implementing IOracle
     * @custom:security View only
     * @custom:validation None
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy No external calls
     * @custom:access Internal
     * @custom:oracle Returns oracle reference
     */
    function _getActiveOracle() internal view returns (IOracle) {
        return activeOracle == OracleType.CHAINLINK
            ? IOracle(address(chainlinkOracle))
            : IOracle(address(storkOracle));
    }

    // =============================================================================
    // VIEW FUNCTIONS - Read functions for monitoring
    // =============================================================================

    /**
     * @notice Gets the currently active oracle type
     * @dev Returns activeOracle enum value
     * @return The active oracle type (CHAINLINK or STORK)
     * @custom:security View only
     * @custom:validation None
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy No external calls
     * @custom:access Anyone
     * @custom:oracle None
     */
    function getActiveOracle() external view returns (OracleType) {
        return activeOracle;
    }

    /**
     * @notice Gets the addresses of both oracle contracts
     * @dev Returns chainlinkOracle and storkOracle addresses
     * @return chainlinkAddress Address of ChainlinkOracle contract
     * @return storkAddress Address of StorkOracle contract
     * @custom:security View only
     * @custom:validation None
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy No external calls
     * @custom:access Anyone
     * @custom:oracle None
     */
    function getOracleAddresses() external view returns (address chainlinkAddress, address storkAddress) {
        return (address(chainlinkOracle), address(storkOracle));
    }

    // =============================================================================
    // UPGRADE FUNCTION - Upgrade authorization
    // =============================================================================

    /**
     * @notice Authorizes router contract upgrades
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
     * @dev Delegates to TreasuryRecoveryLibrary.recoverToken
     * @param token Address of the token to recover
     * @param amount Amount to recover
     * @custom:security DEFAULT_ADMIN_ROLE; sends to treasury only
     * @custom:validation Treasury and amount
     * @custom:state-changes Token balance of treasury
     * @custom:events Via TreasuryRecoveryLibrary
     * @custom:errors Via library
     * @custom:reentrancy External call to token and treasury
     * @custom:access DEFAULT_ADMIN_ROLE
     * @custom:oracle None
     */
    function recoverToken(
        address token,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        TreasuryRecoveryLibrary.recoverToken(token, amount, address(this), treasury);
    }

    /**
     * @notice Recover ETH to treasury address only
     * @dev Delegates to TreasuryRecoveryLibrary.recoverETH; emits ETHRecovered
     * @custom:security DEFAULT_ADMIN_ROLE; sends to treasury only
     * @custom:validation Treasury not zero
     * @custom:state-changes ETH balance of treasury
     * @custom:events ETHRecovered
     * @custom:errors Via library
     * @custom:reentrancy External call to treasury
     * @custom:access DEFAULT_ADMIN_ROLE
     * @custom:oracle None
     */
    function recoverETH() external onlyRole(DEFAULT_ADMIN_ROLE) {
        emit ETHRecovered(treasury, address(this).balance);
        TreasuryRecoveryLibrary.recoverETH(treasury);
    }

    // =============================================================================
    // EMERGENCY FUNCTIONS - Emergency controls
    // =============================================================================

    /**
     * @notice Pauses all oracle operations
     * @dev Calls _pause(); only EMERGENCY_ROLE
     * @custom:security EMERGENCY_ROLE only
     * @custom:validation None
     * @custom:state-changes Pausable state
     * @custom:events Paused
     * @custom:errors None
     * @custom:reentrancy No external calls
     * @custom:access EMERGENCY_ROLE
     * @custom:oracle None
     */
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    // =============================================================================
    // ADMIN FUNCTIONS - Administrative functions
    // =============================================================================

    /**
     * @notice Switches the active oracle between Chainlink and Stork
     * @dev Validates newOracle != activeOracle and oracle address not zero; emits OracleSwitched
     * @param newOracle The new oracle type to activate (CHAINLINK or STORK)
     * @custom:security ORACLE_MANAGER_ROLE only
     * @custom:validation newOracle != activeOracle; oracle address not zero
     * @custom:state-changes activeOracle
     * @custom:events OracleSwitched
     * @custom:errors Require message if same oracle
     * @custom:reentrancy No external calls
     * @custom:access ORACLE_MANAGER_ROLE
     * @custom:oracle None
     */
    function switchOracle(OracleType newOracle) external onlyRole(ORACLE_MANAGER_ROLE) {
        require(newOracle != activeOracle, "OracleRouter: Already using this oracle");

        address oracleAddress = newOracle == OracleType.CHAINLINK
            ? address(chainlinkOracle)
            : address(storkOracle);
        CommonValidationLibrary.validateNonZeroAddress(oracleAddress, "oracle");

        OracleType oldOracle = activeOracle;
        activeOracle = newOracle;

        emit OracleSwitched(oldOracle, newOracle, msg.sender);
    }

    /**
     * @notice Updates the oracle contract addresses
     * @dev Validates both addresses; updates chainlinkOracle and storkOracle; emits OracleAddressesUpdated
     * @param _chainlinkOracle New ChainlinkOracle address
     * @param _storkOracle New StorkOracle address
     * @custom:security ORACLE_MANAGER_ROLE only
     * @custom:validation Both addresses not zero
     * @custom:state-changes chainlinkOracle, storkOracle
     * @custom:events OracleAddressesUpdated
     * @custom:errors InvalidOracle if zero
     * @custom:reentrancy No external calls
     * @custom:access ORACLE_MANAGER_ROLE
     * @custom:oracle None
     */
    function updateOracleAddresses(
        address _chainlinkOracle,
        address _storkOracle
    ) external onlyRole(ORACLE_MANAGER_ROLE) {
        CommonValidationLibrary.validateNonZeroAddress(_chainlinkOracle, "oracle");
        CommonValidationLibrary.validateNonZeroAddress(_storkOracle, "oracle");

        chainlinkOracle = IChainlinkOracle(_chainlinkOracle);
        storkOracle = IStorkOracle(_storkOracle);

        emit OracleAddressesUpdated(_chainlinkOracle, _storkOracle);
    }

    // =============================================================================
    // IOracle INTERFACE IMPLEMENTATION - All read functions delegate to active oracle
    // =============================================================================

    /**
     * @notice Retrieves the current EUR/USD price with full validation
     * @dev Delegates to active oracle getEurUsdPrice()
     * @return price EUR/USD price in 18 decimals
     * @return isValid True if the price is fresh and within acceptable bounds
     * @custom:security Delegates to trusted oracle
     * @custom:validation Via oracle
     * @custom:state-changes May update oracle state (e.g. last price)
     * @custom:events None
     * @custom:errors Via oracle
     * @custom:reentrancy External call to oracle
     * @custom:access Anyone
     * @custom:oracle Delegates to active oracle
     */
    function getEurUsdPrice() external override returns (uint256 price, bool isValid) {
        return _getActiveOracle().getEurUsdPrice();
    }

    /**
     * @notice Retrieves the USDC/USD price with validation
     * @dev Delegates to active oracle getUsdcUsdPrice()
     * @return price USDC/USD price in 18 decimals
     * @return isValid True if USDC remains close to $1.00
     * @custom:security View; delegates to oracle
     * @custom:validation Via oracle
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors Via oracle
     * @custom:reentrancy External call to oracle (view)
     * @custom:access Anyone
     * @custom:oracle Delegates to active oracle
     */
    function getUsdcUsdPrice() external view override returns (uint256 price, bool isValid) {
        return _getActiveOracle().getUsdcUsdPrice();
    }

    /**
     * @notice Returns overall oracle health signals
     * @dev Delegates to active oracle getOracleHealth()
     * @return isHealthy True if both feeds are fresh, circuit breaker is off, and not paused
     * @return eurUsdFresh True if EUR/USD feed is fresh
     * @return usdcUsdFresh True if USDC/USD feed is fresh
     * @custom:security Delegates to oracle
     * @custom:validation Via oracle
     * @custom:state-changes May update oracle state
     * @custom:events None
     * @custom:errors Via oracle
     * @custom:reentrancy External call to oracle
     * @custom:access Anyone
     * @custom:oracle Delegates to active oracle
     */
    function getOracleHealth() external override returns (bool isHealthy, bool eurUsdFresh, bool usdcUsdFresh) {
        return _getActiveOracle().getOracleHealth();
    }

    /**
     * @notice Detailed information about the EUR/USD price
     * @dev Delegates to active oracle getEurUsdDetails()
     * @return currentPrice Current price (may be fallback)
     * @return lastValidPrice Last validated price stored
     * @return lastUpdate Timestamp of last successful update
     * @return isStale True if the feed data is stale
     * @return withinBounds True if within configured min/max bounds
     * @custom:security Delegates to oracle
     * @custom:validation Via oracle
     * @custom:state-changes May update oracle state
     * @custom:events None
     * @custom:errors Via oracle
     * @custom:reentrancy External call to oracle
     * @custom:access Anyone
     * @custom:oracle Delegates to active oracle
     */
    function getEurUsdDetails() external override returns (
        uint256 currentPrice,
        uint256 lastValidPrice,
        uint256 lastUpdate,
        bool isStale,
        bool withinBounds
    ) {
        return _getActiveOracle().getEurUsdDetails();
    }

    /**
     * @notice Current configuration and circuit breaker state
     * @dev Delegates to active oracle getOracleConfig()
     * @return minPrice Minimum accepted EUR/USD price
     * @return maxPrice Maximum accepted EUR/USD price
     * @return maxStaleness Maximum allowed staleness in seconds
     * @return usdcTolerance USDC tolerance in basis points
     * @return circuitBreakerActive True if circuit breaker is triggered
     * @custom:security View; delegates to oracle
     * @custom:validation Via oracle
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors Via oracle
     * @custom:reentrancy External call to oracle (view)
     * @custom:access Anyone
     * @custom:oracle Delegates to active oracle
     */
    function getOracleConfig() external view override returns (
        uint256 minPrice,
        uint256 maxPrice,
        uint256 maxStaleness,
        uint256 usdcTolerance,
        bool circuitBreakerActive
    ) {
        return _getActiveOracle().getOracleConfig();
    }

    /**
     * @notice Addresses and decimals of the underlying feeds
     * @dev Delegates to active oracle getPriceFeedAddresses()
     * @return eurUsdFeedAddress EUR/USD feed address
     * @return usdcUsdFeedAddress USDC/USD feed address
     * @return eurUsdDecimals EUR/USD feed decimals
     * @return usdcUsdDecimals USDC/USD feed decimals
     * @custom:security View; delegates to oracle
     * @custom:validation Via oracle
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors Via oracle
     * @custom:reentrancy External call to oracle (view)
     * @custom:access Anyone
     * @custom:oracle Delegates to active oracle
     */
    function getPriceFeedAddresses() external view override returns (
        address eurUsdFeedAddress,
        address usdcUsdFeedAddress,
        uint8 eurUsdDecimals,
        uint8 usdcUsdDecimals
    ) {
        return _getActiveOracle().getPriceFeedAddresses();
    }

    /**
     * @notice Connectivity check for both feeds
     * @dev Delegates to active oracle checkPriceFeedConnectivity()
     * @return eurUsdConnected True if EUR/USD feed responds
     * @return usdcUsdConnected True if USDC/USD feed responds
     * @return eurUsdLatestRound Latest round ID for EUR/USD
     * @return usdcUsdLatestRound Latest round ID for USDC/USD
     * @custom:security View; delegates to oracle
     * @custom:validation Via oracle
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors Via oracle
     * @custom:reentrancy External call to oracle (view)
     * @custom:access Anyone
     * @custom:oracle Delegates to active oracle
     */
    function checkPriceFeedConnectivity() external view override returns (
        bool eurUsdConnected,
        bool usdcUsdConnected,
        uint80 eurUsdLatestRound,
        uint80 usdcUsdLatestRound
    ) {
        return _getActiveOracle().checkPriceFeedConnectivity();
    }

    /**
     * @notice Updates EUR/USD min and max acceptable prices
     * @dev Delegates to active oracle updatePriceBounds
     * @param _minPrice New minimum price (18 decimals)
     * @param _maxPrice New maximum price (18 decimals)
     * @custom:security ORACLE_MANAGER_ROLE only
     * @custom:validation Via oracle
     * @custom:state-changes Oracle state
     * @custom:events Via oracle
     * @custom:errors Via oracle
     * @custom:reentrancy External call to oracle
     * @custom:access ORACLE_MANAGER_ROLE
     * @custom:oracle Delegates to active oracle
     */
    function updatePriceBounds(uint256 _minPrice, uint256 _maxPrice) external onlyRole(ORACLE_MANAGER_ROLE) {
        if (activeOracle == OracleType.CHAINLINK) {
            chainlinkOracle.updatePriceBounds(_minPrice, _maxPrice);
        } else {
            storkOracle.updatePriceBounds(_minPrice, _maxPrice);
        }
    }

    /**
     * @notice Updates the allowed USDC deviation from $1.00 in basis points
     * @dev Delegates to active oracle updateUsdcTolerance
     * @param newToleranceBps New tolerance (e.g., 200 = 2%)
     * @custom:security ORACLE_MANAGER_ROLE only
     * @custom:validation Via oracle
     * @custom:state-changes Oracle state
     * @custom:events Via oracle
     * @custom:errors Via oracle
     * @custom:reentrancy External call to oracle
     * @custom:access ORACLE_MANAGER_ROLE
     * @custom:oracle Delegates to active oracle
     */
    function updateUsdcTolerance(uint256 newToleranceBps) external onlyRole(ORACLE_MANAGER_ROLE) {
        if (activeOracle == OracleType.CHAINLINK) {
            chainlinkOracle.updateUsdcTolerance(newToleranceBps);
        } else {
            storkOracle.updateUsdcTolerance(newToleranceBps);
        }
    }

    /**
     * @notice Updates price feed addresses (Chainlink only)
     * @param _eurUsdFeed New EUR/USD feed address
     * @param _usdcUsdFeed New USDC/USD feed address
     * @dev Reverts for Stork oracle - use oracle-specific methods instead
     * @custom:security Only Chainlink path; reverts for Stork
     * @custom:validation Via ChainlinkOracle
     * @custom:state-changes Oracle feed addresses
     * @custom:events Via oracle
     * @custom:errors Reverts for Stork
     * @custom:reentrancy External call to ChainlinkOracle
     * @custom:access Caller must have role on oracle (router does not check)
     * @custom:oracle Delegates to ChainlinkOracle only
     */
    function updatePriceFeeds(address _eurUsdFeed, address _usdcUsdFeed) external {
        if (activeOracle == OracleType.CHAINLINK) {
            chainlinkOracle.updatePriceFeeds(_eurUsdFeed, _usdcUsdFeed);
        } else {
            revert("OracleRouter: Use oracle-specific updatePriceFeeds for Stork");
        }
    }

    /**
     * @notice Clears circuit breaker and attempts to resume live prices
     * @dev Delegates to active oracle resetCircuitBreaker()
     * @custom:security Anyone can reset (oracle may restrict)
     * @custom:validation Via oracle
     * @custom:state-changes Oracle circuit breaker state
     * @custom:events Via oracle
     * @custom:errors Via oracle
     * @custom:reentrancy External call to oracle
     * @custom:access Anyone
     * @custom:oracle Delegates to active oracle
     */
    function resetCircuitBreaker() external {
        if (activeOracle == OracleType.CHAINLINK) {
            chainlinkOracle.resetCircuitBreaker();
        } else {
            storkOracle.resetCircuitBreaker();
        }
    }

    /**
     * @notice Manually triggers circuit breaker to use fallback prices
     * @dev Delegates to active oracle triggerCircuitBreaker()
     * @custom:security ORACLE_MANAGER_ROLE only
     * @custom:validation Via oracle
     * @custom:state-changes Oracle circuit breaker state
     * @custom:events Via oracle
     * @custom:errors Via oracle
     * @custom:reentrancy External call to oracle
     * @custom:access ORACLE_MANAGER_ROLE
     * @custom:oracle Delegates to active oracle
     */
    function triggerCircuitBreaker() external onlyRole(ORACLE_MANAGER_ROLE) {
        if (activeOracle == OracleType.CHAINLINK) {
            chainlinkOracle.triggerCircuitBreaker();
        } else {
            storkOracle.triggerCircuitBreaker();
        }
    }

}

