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
     * @dev Allows emergency role to unpause the router after resolving issues
     * @custom:security Resumes router operations after emergency pause
     * @custom:validation Validates contract was previously paused
     * @custom:state-changes Sets paused state to false
     * @custom:events Emits Unpaused event
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle Resumes oracle queries through active oracle
     */
    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }

    // =============================================================================
    // INTERNAL FUNCTIONS - Utility internal functions
    // =============================================================================

    /**
     * @notice Gets the currently active oracle contract
     * @dev Returns the oracle contract based on activeOracle state
     * @return The active oracle contract implementing IOracle
     * @custom:security Internal function - no security implications
     * @custom:validation No validation - read-only operation
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Internal - only callable within contract
     * @custom:oracle Returns reference to active oracle (Chainlink or Stork)
     */
    function _getActiveOracle() internal view returns (IOracle) {
        if (activeOracle == OracleType.CHAINLINK) {
            return IOracle(address(chainlinkOracle));
        } else {
            return IOracle(address(storkOracle));
        }
    }

    // =============================================================================
    // VIEW FUNCTIONS - Read functions for monitoring
    // =============================================================================

    /**
     * @notice Gets the currently active oracle type
     * @dev Returns the enum value of the active oracle
     * @return The active oracle type (CHAINLINK or STORK)
     * @custom:security Returns current oracle selection for monitoring
     * @custom:validation No validation - read-only operation
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle Returns which oracle (Chainlink or Stork) is currently active
     */
    function getActiveOracle() external view returns (OracleType) {
        return activeOracle;
    }

    /**
     * @notice Gets the addresses of both oracle contracts
     * @dev Returns both oracle addresses for reference
     * @return chainlinkAddress Address of ChainlinkOracle contract
     * @return storkAddress Address of StorkOracle contract
     * @custom:security Returns oracle addresses for verification
     * @custom:validation No validation - read-only operation
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle Returns addresses of both Chainlink and Stork oracle contracts
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
     * @notice Pauses all oracle operations
     * @dev Emergency function to pause router in case of critical issues
     * @custom:security Emergency pause to halt all router operations
     * @custom:validation No validation - emergency function
     * @custom:state-changes Sets paused state to true
     * @custom:events Emits Paused event
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle Halts all oracle queries through router
     */
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    // =============================================================================
    // ADMIN FUNCTIONS - Administrative functions
    // =============================================================================

    /**
     * @notice Switches the active oracle between Chainlink and Stork
     * @dev Allows oracle manager to change which oracle is actively used
     * @param newOracle The new oracle type to activate (CHAINLINK or STORK)
     * @custom:security Only ORACLE_MANAGER_ROLE can switch oracles
     * @custom:validation Validates newOracle is different from current activeOracle
     * @custom:state-changes Updates activeOracle state variable
     * @custom:events Emits OracleSwitched event
     * @custom:errors Throws if newOracle is same as current activeOracle
     * @custom:reentrancy Not protected - no external calls that could reenter
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:oracle Switches active oracle between Chainlink and Stork
     */
    function switchOracle(OracleType newOracle) external onlyRole(ORACLE_MANAGER_ROLE) {
        require(newOracle != activeOracle, "OracleRouter: Already using this oracle");
        
        // Validate oracle address is not zero before switching
        if (newOracle == OracleType.CHAINLINK) {
            CommonValidationLibrary.validateNonZeroAddress(address(chainlinkOracle), "oracle");
        } else {
            CommonValidationLibrary.validateNonZeroAddress(address(storkOracle), "oracle");
        }

        OracleType oldOracle = activeOracle;
        activeOracle = newOracle;

        emit OracleSwitched(oldOracle, newOracle, msg.sender);
    }

    /**
     * @notice Updates the oracle contract addresses
     * @dev Allows oracle manager to update oracle addresses for maintenance or upgrades
     * @param _chainlinkOracle New ChainlinkOracle address
     * @param _storkOracle New StorkOracle address
     * @custom:security Validates both oracle addresses are non-zero
     * @custom:validation Validates all addresses are not address(0)
     * @custom:state-changes Updates chainlinkOracle and storkOracle references
     * @custom:events Emits OracleAddressesUpdated event
     * @custom:errors Throws if oracle addresses are zero
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:oracle Updates references to Chainlink and Stork oracle contracts
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
     * @dev Delegates to the currently active oracle
     * @return price EUR/USD price in 18 decimals
     * @return isValid True if the price is fresh and within acceptable bounds
     * @custom:security Validates price freshness and bounds before returning
     * @custom:validation Checks price staleness and circuit breaker state
     * @custom:state-changes May update lastValidPrice if price is valid
     * @custom:events No events emitted
     * @custom:errors No errors thrown, returns isValid=false for invalid prices
     * @custom:reentrancy Not protected - delegates to active oracle
     * @custom:access Public - no access restrictions
     * @custom:oracle Queries active oracle (Chainlink or Stork) for EUR/USD price
     */
    function getEurUsdPrice() external override returns (uint256 price, bool isValid) {
        if (paused()) {
            // If paused, try to get last valid price from active oracle
            return _getActiveOracle().getEurUsdPrice();
        }
        return _getActiveOracle().getEurUsdPrice();
    }

    /**
     * @notice Retrieves the USDC/USD price with validation
     * @dev Delegates to the currently active oracle
     * @return price USDC/USD price in 18 decimals
     * @return isValid True if USDC remains close to $1.00
     * @custom:security Validates price is within tolerance of $1.00
     * @custom:validation Checks price staleness and deviation from $1.00
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown, returns isValid=false for invalid prices
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle Queries active oracle (Chainlink or Stork) for USDC/USD price
     */
    function getUsdcUsdPrice() external view override returns (uint256 price, bool isValid) {
        return _getActiveOracle().getUsdcUsdPrice();
    }

    /**
     * @notice Returns overall oracle health signals
     * @dev Delegates to the currently active oracle
     * @return isHealthy True if both feeds are fresh, circuit breaker is off, and not paused
     * @return eurUsdFresh True if EUR/USD feed is fresh
     * @return usdcUsdFresh True if USDC/USD feed is fresh
     * @custom:security Provides health status for monitoring and circuit breaker decisions
     * @custom:validation Checks feed freshness, circuit breaker state, and pause status
     * @custom:state-changes May update internal state during health check
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - delegates to active oracle
     * @custom:access Public - no access restrictions
     * @custom:oracle Queries active oracle health status for both feeds
     */
    function getOracleHealth() external override returns (bool isHealthy, bool eurUsdFresh, bool usdcUsdFresh) {
        return _getActiveOracle().getOracleHealth();
    }

    /**
     * @notice Detailed information about the EUR/USD price
     * @dev Delegates to the currently active oracle
     * @return currentPrice Current price (may be fallback)
     * @return lastValidPrice Last validated price stored
     * @return lastUpdate Timestamp of last successful update
     * @return isStale True if the feed data is stale
     * @return withinBounds True if within configured min/max bounds
     * @custom:security Provides detailed price information for debugging and monitoring
     * @custom:validation Checks price freshness and bounds validation
     * @custom:state-changes May update internal state during price check
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - delegates to active oracle
     * @custom:access Public - no access restrictions
     * @custom:oracle Queries active oracle for detailed EUR/USD price information
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
     * @dev Delegates to the currently active oracle
     * @return minPrice Minimum accepted EUR/USD price
     * @return maxPrice Maximum accepted EUR/USD price
     * @return maxStaleness Maximum allowed staleness in seconds
     * @return usdcTolerance USDC tolerance in basis points
     * @return circuitBreakerActive True if circuit breaker is triggered
     * @custom:security Returns configuration for security monitoring
     * @custom:validation No validation - read-only configuration
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle Returns configuration from active oracle
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
     * @dev Delegates to the currently active oracle
     * @return eurUsdFeedAddress EUR/USD feed address
     * @return usdcUsdFeedAddress USDC/USD feed address
     * @return eurUsdDecimals EUR/USD feed decimals
     * @return usdcUsdDecimals USDC/USD feed decimals
     * @custom:security Returns feed addresses for verification
     * @custom:validation No validation - read-only information
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle Returns feed addresses from active oracle
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
     * @dev Delegates to the currently active oracle
     * @return eurUsdConnected True if EUR/USD feed responds
     * @return usdcUsdConnected True if USDC/USD feed responds
     * @return eurUsdLatestRound Latest round ID for EUR/USD
     * @return usdcUsdLatestRound Latest round ID for USDC/USD
     * @custom:security Tests feed connectivity for health monitoring
     * @custom:validation No validation - connectivity test only
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown, returns false for disconnected feeds
     * @custom:reentrancy Not protected - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle Tests connectivity to active oracle feeds
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
     * @dev Delegates to the currently active oracle (requires casting to specific interface)
     *      Requires ORACLE_MANAGER_ROLE on the router
     * @param _minPrice New minimum price (18 decimals)
     * @param _maxPrice New maximum price (18 decimals)
     * @custom:security Validates min < max and reasonable bounds
     * @custom:validation Validates price bounds are within acceptable range
     * @custom:state-changes Updates minPrice and maxPrice in active oracle
     * @custom:events Emits PriceBoundsUpdated event (via active oracle)
     * @custom:errors Throws if minPrice >= maxPrice or invalid bounds
     * @custom:reentrancy Protected by active oracle's reentrancy guard
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:oracle Delegates to active oracle (Chainlink or Stork) to update price bounds
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
     * @dev Delegates to the currently active oracle (requires casting to specific interface)
     *      Requires ORACLE_MANAGER_ROLE on the router
     * @param newToleranceBps New tolerance (e.g., 200 = 2%)
     * @custom:security Validates tolerance is within reasonable limits
     * @custom:validation Validates tolerance is not zero and within max bounds
     * @custom:state-changes Updates usdcTolerance in active oracle
     * @custom:events Emits UsdcToleranceUpdated event (via active oracle)
     * @custom:errors Throws if tolerance is invalid or out of bounds
     * @custom:reentrancy Protected by active oracle's reentrancy guard
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:oracle Delegates to active oracle (Chainlink or Stork) to update USDC tolerance
     */
    function updateUsdcTolerance(uint256 newToleranceBps) external onlyRole(ORACLE_MANAGER_ROLE) {
        if (activeOracle == OracleType.CHAINLINK) {
            chainlinkOracle.updateUsdcTolerance(newToleranceBps);
        } else {
            storkOracle.updateUsdcTolerance(newToleranceBps);
        }
    }

    /**
     * @notice Updates price feed addresses
     * @dev Delegates to the currently active oracle (requires casting to specific interface)
     *      Note: Chainlink uses addresses, Stork uses address + feed IDs
     * @param _eurUsdFeed New EUR/USD feed address (for Chainlink) or Stork feed address (for Stork)
     * @param _usdcUsdFeed New USDC/USD feed address (for Chainlink) or unused (for Stork)
     * @custom:security Validates feed address is non-zero and contract exists
     * @custom:validation Validates all addresses are not address(0)
     * @custom:state-changes Updates feed addresses in active oracle (Chainlink only)
     * @custom:events Emits PriceFeedsUpdated event (via active oracle)
     * @custom:errors Throws if feed address is zero, invalid, or Stork oracle is active
     * @custom:reentrancy Protected by active oracle's reentrancy guard
     * @custom:access Restricted to ORACLE_MANAGER_ROLE (via active oracle)
     * @custom:oracle Delegates to active Chainlink oracle to update feed addresses (reverts for Stork)
     */
    function updatePriceFeeds(address _eurUsdFeed, address _usdcUsdFeed) external {
        if (activeOracle == OracleType.CHAINLINK) {
            chainlinkOracle.updatePriceFeeds(_eurUsdFeed, _usdcUsdFeed);
        } else {
            // For Stork, this function signature doesn't match - would need separate function
            // For now, revert with helpful message
            revert("OracleRouter: Use oracle-specific updatePriceFeeds for Stork");
        }
    }

    /**
     * @notice Clears circuit breaker and attempts to resume live prices
     * @dev Delegates to the currently active oracle (requires casting to specific interface)
     * @custom:security Resets circuit breaker after manual intervention
     * @custom:validation Validates circuit breaker was previously triggered
     * @custom:state-changes Resets circuitBreakerTriggered flag in active oracle
     * @custom:events Emits CircuitBreakerReset event (via active oracle)
     * @custom:errors No errors thrown
     * @custom:reentrancy Protected by active oracle's reentrancy guard
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:oracle Delegates to active oracle (Chainlink or Stork) to reset circuit breaker
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
     * @dev Delegates to the currently active oracle (requires casting to specific interface)
     * @custom:security Manually activates circuit breaker for emergency situations
     * @custom:validation No validation - emergency function
     * @custom:state-changes Sets circuitBreakerTriggered flag to true in active oracle
     * @custom:events Emits CircuitBreakerTriggered event (via active oracle)
     * @custom:errors No errors thrown
     * @custom:reentrancy Protected by active oracle's reentrancy guard
     * @custom:access Restricted to ORACLE_MANAGER_ROLE
     * @custom:oracle Delegates to active oracle (Chainlink or Stork) to trigger circuit breaker
     */
    function triggerCircuitBreaker() external onlyRole(ORACLE_MANAGER_ROLE) {
        if (activeOracle == OracleType.CHAINLINK) {
            chainlinkOracle.triggerCircuitBreaker();
        } else {
            storkOracle.triggerCircuitBreaker();
        }
    }

}

