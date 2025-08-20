// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// =============================================================================
// IMPORTS - OpenZeppelin libraries for security and standards
// =============================================================================

// ERC20 upgradeable with all standard functionality
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

// Role system to control who can do what
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

// Emergency pause mechanism
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

// Base for upgradeable contracts
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// UUPS: Universal Upgradeable Proxy Standard (more gas-efficient than Transparent)
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title QEUROToken
 * @notice Euro-pegged stablecoin token for the Quantillon protocol
 * 
 * @dev Main characteristics:
 *      - Standard ERC20 with 18 decimals
 *      - Mint/Burn controlled only by the vault
 *      - Emergency pause in case of issues
 *      - Upgradeable via UUPS pattern
 *      - Dynamic supply cap for governance flexibility
 *      - Blacklist/whitelist functionality for compliance
 *      - Rate limiting for mint/burn operations
 *      - Decimal precision handling for external price feeds
 * 
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract QEUROToken is 
    Initializable,           // Base for initialization instead of constructor
    ERC20Upgradeable,        // Standard ERC20 token
    AccessControlUpgradeable, // Role management
    PausableUpgradeable,     // Emergency pause
    UUPSUpgradeable          // Upgrade pattern
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // =============================================================================
    // CONSTANTS - Protocol roles and limits
    // =============================================================================
    
    /// @notice Role for minting tokens (assigned to QuantillonVault only)
    /// @dev keccak256 hash avoids role collisions
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    /// @notice Role for burning tokens (assigned to QuantillonVault only)
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    
    /// @notice Role for pausing the contract in emergency
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    /// @notice Role for performing contract upgrades
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @notice Role for managing blacklist/whitelist
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");

    /// @notice Default maximum supply limit (100 million QEURO)
    /// @dev Can be updated by governance
    uint256 public constant DEFAULT_MAX_SUPPLY = 100_000_000 * 1e18;

    /// @notice Maximum rate limit for mint/burn operations (per hour)
    uint256 public constant MAX_RATE_LIMIT = 10_000_000 * 1e18; // 10M QEURO per hour

    /// @notice Precision for decimal calculations (18 decimals)
    uint256 public constant PRECISION = 1e18;

    // =============================================================================
    // STATE VARIABLES - Dynamic configuration
    // =============================================================================

    /// @notice Current maximum supply limit (updatable by governance)
    uint256 public maxSupply;

    /// @notice Rate limit for mint operations (per hour)
    uint256 public mintRateLimit;

    /// @notice Rate limit for burn operations (per hour)
    uint256 public burnRateLimit;

    /// @notice Current minted amount in the current hour
    uint256 public currentHourMinted;

    /// @notice Current burned amount in the current hour
    uint256 public currentHourBurned;

    /// @notice Timestamp of the last rate limit reset
    uint256 public lastRateLimitReset;

    /// @notice Blacklist mapping for compliance
    mapping(address => bool) public isBlacklisted;

    /// @notice Whitelist mapping for compliance (if enabled)
    mapping(address => bool) public isWhitelisted;

    /// @notice Whether whitelist mode is enabled
    bool public whitelistEnabled;

    /// @notice Minimum precision for external price feeds
    uint256 public minPricePrecision;

    // =============================================================================
    // EVENTS - Events for tracking and monitoring
    // =============================================================================
    
    /// @notice Emitted when tokens are minted
    /// @param to Recipient of the tokens
    /// @param amount Amount minted
    /// @param minter Address that performed the mint (vault)
    event TokensMinted(address indexed to, uint256 amount, address indexed minter);
    
    /// @notice Emitted when tokens are burned
    /// @param from Address from which tokens are burned
    /// @param amount Amount burned
    /// @param burner Address that performed the burn (vault)
    event TokensBurned(address indexed from, uint256 amount, address indexed burner);
    
    /// @notice Emitted when the supply limit is modified
    /// @param oldCap Old limit
    /// @param newCap New limit
    event SupplyCapUpdated(uint256 oldCap, uint256 newCap);

    /// @notice Emitted when rate limits are updated
    /// @param mintLimit New mint rate limit
    /// @param burnLimit New burn rate limit
    event RateLimitsUpdated(uint256 mintLimit, uint256 burnLimit);

    /// @notice Emitted when an address is blacklisted
    /// @param account Address that was blacklisted
    /// @param reason Reason for blacklisting
    event AddressBlacklisted(address indexed account, string reason);

    /// @notice Emitted when an address is removed from blacklist
    /// @param account Address that was removed from blacklist
    event AddressUnblacklisted(address indexed account);

    /// @notice Emitted when an address is whitelisted
    /// @param account Address that was whitelisted
    event AddressWhitelisted(address indexed account);

    /// @notice Emitted when an address is removed from whitelist
    /// @param account Address that was removed from whitelist
    event AddressUnwhitelisted(address indexed account);

    /// @notice Emitted when whitelist mode is toggled
    /// @param enabled Whether whitelist mode is enabled
    event WhitelistModeToggled(bool enabled);

    /// @notice Emitted when minimum price precision is updated
    /// @param oldPrecision Old minimum precision
    /// @param newPrecision New minimum precision
    event MinPricePrecisionUpdated(uint256 oldPrecision, uint256 newPrecision);

    /// @notice Emitted when rate limit is reset
    /// @param timestamp Timestamp of reset
    event RateLimitReset(uint256 timestamp);

    // =============================================================================
    // INITIALIZER - Replaces constructor for upgradeable contracts
    // =============================================================================
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // Disables initialization on the implementation for security
        _disableInitializers();
    }

    /**
     * @notice Initializes the QEURO token (called only once at deployment)
     * 
     * @param admin Address that will have the DEFAULT_ADMIN_ROLE
     * @param vault Address of the QuantillonVault (will get MINTER_ROLE and BURNER_ROLE)
     * 
     * @dev This function replaces the constructor. It:
     *      1. Initializes the ERC20 token with name and symbol
     *      2. Configures the role system
     *      3. Assigns appropriate roles
     *      4. Configures pause and upgrade system
     *      5. Sets initial rate limits and precision settings
     */
    function initialize(
        address admin,
        address vault
    ) public initializer {
        // Input parameter validation
        require(admin != address(0), "QEURO: Admin cannot be zero address");
        require(vault != address(0), "QEURO: Vault cannot be zero address");
        
        // OpenZeppelin module initialization
        __ERC20_init("Quantillon Euro", "QEURO");  // Token name and symbol
        __AccessControl_init();                     // Role system
        __Pausable_init();                         // Pause mechanism
        __UUPSUpgradeable_init();                  // Upgrade system

        // Initialize state variables
        maxSupply = DEFAULT_MAX_SUPPLY;
        mintRateLimit = MAX_RATE_LIMIT;
        burnRateLimit = MAX_RATE_LIMIT;
        lastRateLimitReset = block.timestamp;
        whitelistEnabled = false;
        minPricePrecision = 1e6; // 6 decimal precision minimum

        // Role configuration
        // DEFAULT_ADMIN_ROLE can manage all other roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        
        // The vault can mint and burn tokens
        _grantRole(MINTER_ROLE, vault);
        _grantRole(BURNER_ROLE, vault);
        
        // The admin can pause in emergency
        _grantRole(PAUSER_ROLE, admin);
        
        // The admin can perform upgrades
        _grantRole(UPGRADER_ROLE, admin);

        // The admin can manage compliance
        _grantRole(COMPLIANCE_ROLE, admin);
    }

    // =============================================================================
    // CORE FUNCTIONS - Main mint/burn functions
    // =============================================================================

    /**
     * @notice Mints QEURO tokens to a specified address
     * 
     * @param to Address that will receive the tokens
     * @param amount Amount of tokens to mint (in wei, 18 decimals)
     * 
     * @dev Implemented securities:
     *      - Only the vault can call this function (MINTER_ROLE)
     *      - The contract must not be paused
     *      - Respect for maximum supply cap
     *      - Input parameter validation
     *      - Rate limiting
     *      - Blacklist/whitelist checks
     * 
     * Usage example: vault.mint(user, 1000 * 1e18) for 1000 QEURO
     */
    function mint(address to, uint256 amount) 
        external 
        onlyRole(MINTER_ROLE)    // Only the vault can mint
        whenNotPaused            // Not in pause mode
    {
        // Strict parameter validation
        require(to != address(0), "QEURO: Cannot mint to zero address");
        require(amount > 0, "QEURO: Amount must be greater than zero");
        
        // Blacklist check
        require(!isBlacklisted[to], "QEURO: Recipient is blacklisted");
        
        // Whitelist check (if enabled)
        if (whitelistEnabled) {
            require(isWhitelisted[to], "QEURO: Recipient not whitelisted");
        }

        // Rate limiting check
        _checkAndUpdateMintRateLimit(amount);
        
        // Supply cap verification to prevent excessive inflation
        require(
            totalSupply() + amount <= maxSupply, 
            "QEURO: Would exceed max supply"
        );

        // Actual mint (secure OpenZeppelin function)
        _mint(to, amount);
        
        // Event for tracking
        emit TokensMinted(to, amount, msg.sender);
    }

    /**
     * @notice Burns QEURO tokens from a specified address
     * 
     * @param from Address from which to burn tokens
     * @param amount Amount of tokens to burn
     * 
     * @dev Implemented securities:
     *      - Only the vault can call this function (BURNER_ROLE)
     *      - The contract must not be paused
     *      - Sufficient balance verification
     *      - Parameter validation
     *      - Rate limiting
     * 
     * Note: The vault must have an allowance or be authorized otherwise
     */
    function burn(address from, uint256 amount) 
        external 
        onlyRole(BURNER_ROLE)    // Only the vault can burn
        whenNotPaused            // Not in pause mode
    {
        // Parameter validation
        require(from != address(0), "QEURO: Cannot burn from zero address");
        require(amount > 0, "QEURO: Amount must be greater than zero");
        require(balanceOf(from) >= amount, "QEURO: Insufficient balance to burn");

        // Rate limiting check
        _checkAndUpdateBurnRateLimit(amount);

        // Actual burn (secure OpenZeppelin function)
        _burn(from, amount);
        
        // Event for tracking
        emit TokensBurned(from, amount, msg.sender);
    }

    // =============================================================================
    // RATE LIMITING FUNCTIONS - Rate limiting for mint/burn operations
    // =============================================================================

    /**
     * @notice Checks and updates mint rate limit
     * @param amount Amount being minted
     * @dev Internal function to enforce rate limiting
     */
    function _checkAndUpdateMintRateLimit(uint256 amount) internal {
        // Reset rate limit if an hour has passed
        if (block.timestamp >= lastRateLimitReset + 1 hours) {
            currentHourMinted = 0;
            currentHourBurned = 0;
            lastRateLimitReset = block.timestamp;
            emit RateLimitReset(block.timestamp);
        }

        // Check if the new amount would exceed the rate limit
        require(
            currentHourMinted + amount <= mintRateLimit,
            "QEURO: Mint rate limit exceeded"
        );

        // Update the current hour minted amount
        unchecked {
            currentHourMinted += amount;
        }
    }

    /**
     * @notice Checks and updates burn rate limit
     * @param amount Amount being burned
     * @dev Internal function to enforce rate limiting
     */
    function _checkAndUpdateBurnRateLimit(uint256 amount) internal {
        // Reset rate limit if an hour has passed
        if (block.timestamp >= lastRateLimitReset + 1 hours) {
            currentHourMinted = 0;
            currentHourBurned = 0;
            lastRateLimitReset = block.timestamp;
            emit RateLimitReset(block.timestamp);
        }

        // Check if the new amount would exceed the rate limit
        require(
            currentHourBurned + amount <= burnRateLimit,
            "QEURO: Burn rate limit exceeded"
        );

        // Update the current hour burned amount
        unchecked {
            currentHourBurned += amount;
        }
    }

    /**
     * @notice Updates rate limits for mint and burn operations
     * @param newMintLimit New mint rate limit per hour
     * @param newBurnLimit New burn rate limit per hour
     * @dev Only callable by admin
     */
    function updateRateLimits(uint256 newMintLimit, uint256 newBurnLimit) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(newMintLimit > 0, "QEURO: Mint limit must be positive");
        require(newBurnLimit > 0, "QEURO: Burn limit must be positive");
        require(newMintLimit <= MAX_RATE_LIMIT, "QEURO: Mint limit too high");
        require(newBurnLimit <= MAX_RATE_LIMIT, "QEURO: Burn limit too high");

        uint256 oldMintLimit = mintRateLimit;
        uint256 oldBurnLimit = burnRateLimit;

        mintRateLimit = newMintLimit;
        burnRateLimit = newBurnLimit;

        emit RateLimitsUpdated(newMintLimit, newBurnLimit);
    }

    // =============================================================================
    // COMPLIANCE FUNCTIONS - Blacklist and whitelist management
    // =============================================================================

    /**
     * @notice Blacklists an address
     * @param account Address to blacklist
     * @param reason Reason for blacklisting
     * @dev Only callable by compliance role
     */
    function blacklistAddress(address account, string memory reason) 
        external 
        onlyRole(COMPLIANCE_ROLE) 
    {
        require(account != address(0), "QEURO: Cannot blacklist zero address");
        require(!isBlacklisted[account], "QEURO: Address already blacklisted");
        
        isBlacklisted[account] = true;
        emit AddressBlacklisted(account, reason);
    }

    /**
     * @notice Removes an address from blacklist
     * @param account Address to remove from blacklist
     * @dev Only callable by compliance role
     */
    function unblacklistAddress(address account) 
        external 
        onlyRole(COMPLIANCE_ROLE) 
    {
        require(isBlacklisted[account], "QEURO: Address not blacklisted");
        
        isBlacklisted[account] = false;
        emit AddressUnblacklisted(account);
    }

    /**
     * @notice Whitelists an address
     * @param account Address to whitelist
     * @dev Only callable by compliance role
     */
    function whitelistAddress(address account) 
        external 
        onlyRole(COMPLIANCE_ROLE) 
    {
        require(account != address(0), "QEURO: Cannot whitelist zero address");
        require(!isWhitelisted[account], "QEURO: Address already whitelisted");
        
        isWhitelisted[account] = true;
        emit AddressWhitelisted(account);
    }

    /**
     * @notice Removes an address from whitelist
     * @param account Address to remove from whitelist
     * @dev Only callable by compliance role
     */
    function unwhitelistAddress(address account) 
        external 
        onlyRole(COMPLIANCE_ROLE) 
    {
        require(isWhitelisted[account], "QEURO: Address not whitelisted");
        
        isWhitelisted[account] = false;
        emit AddressUnwhitelisted(account);
    }

    /**
     * @notice Toggles whitelist mode
     * @param enabled Whether to enable whitelist mode
     * @dev Only callable by compliance role
     */
    function toggleWhitelistMode(bool enabled) 
        external 
        onlyRole(COMPLIANCE_ROLE) 
    {
        whitelistEnabled = enabled;
        emit WhitelistModeToggled(enabled);
    }

    // =============================================================================
    // DECIMAL PRECISION FUNCTIONS - Handle precision issues with external price feeds
    // =============================================================================

    /**
     * @notice Updates minimum price precision for external feeds
     * @param newPrecision New minimum precision (e.g., 1e6 for 6 decimals)
     * @dev Only callable by admin
     */
    function updateMinPricePrecision(uint256 newPrecision) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(newPrecision > 0, "QEURO: Precision must be positive");
        require(newPrecision <= PRECISION, "QEURO: Precision too high");

        uint256 oldPrecision = minPricePrecision;
        minPricePrecision = newPrecision;

        emit MinPricePrecisionUpdated(oldPrecision, newPrecision);
    }

    /**
     * @notice Normalizes a price value to 18 decimals
     * @param price Price value from external feed
     * @param decimals Number of decimals in the price feed
     * @return Normalized price with 18 decimals
     * @dev Helper function for external integrations
     */
    function normalizePrice(uint256 price, uint8 decimals) 
        external 
        view 
        returns (uint256) 
    {
        require(decimals <= 18, "QEURO: Too many decimals");
        require(price > 0, "QEURO: Price must be positive");

        if (decimals == 18) {
            return price;
        } else if (decimals < 18) {
            unchecked {
                return price * (10 ** (18 - decimals));
            }
        } else {
            unchecked {
                return price / (10 ** (decimals - 18));
            }
        }
    }

    /**
     * @notice Validates price precision from external feed
     * @param price Price value from external feed
     * @param decimals Number of decimals in the price feed
     * @return Whether the price meets minimum precision requirements
     * @dev Helper function for external integrations
     */
    function validatePricePrecision(uint256 price, uint8 decimals) 
        external 
        view 
        returns (bool) 
    {
        if (decimals == 0) return price >= minPricePrecision;
        
        uint256 normalizedPrice = this.normalizePrice(price, decimals);
        return normalizedPrice >= minPricePrecision;
    }

    // =============================================================================
    // EMERGENCY FUNCTIONS - Emergency functions
    // =============================================================================

    /**
     * @notice Pauses all token operations (emergency only)
     * 
     * @dev When paused:
     *      - No transfers possible
     *      - No mint/burn possible
     *      - Only read functions work
     *      
     * Used in case of:
     *      - Critical bug discovered
     *      - Ongoing attack
     *      - Emergency protocol maintenance
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Removes pause and restores normal operations
     * 
     * @dev Can only be called by a PAUSER_ROLE
     *      Used after resolving the issue that caused the pause
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // =============================================================================
    // VIEW FUNCTIONS - Public read functions
    // =============================================================================

    /**
     * @notice Returns the number of decimals for the token (always 18)
     * @return Number of decimals (18 for DeFi compatibility)
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    /**
     * @notice Checks if an address has the minter role
     * @param account Address to check
     * @return true if the address can mint
     */
    function isMinter(address account) external view returns (bool) {
        return hasRole(MINTER_ROLE, account);
    }

    /**
     * @notice Checks if an address has the burner role
     * @param account Address to check  
     * @return true if the address can burn
     */
    function isBurner(address account) external view returns (bool) {
        return hasRole(BURNER_ROLE, account);
    }

    /**
     * @notice Calculates the percentage of maximum supply utilization
     * @return Percentage in basis points (0-10000, where 10000 = 100%)
     * 
     * @dev Useful for monitoring:
     *      - 0 = 0% used
     *      - 5000 = 50% used  
     *      - 10000 = 100% used (maximum supply reached)
     */
    function getSupplyUtilization() external view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return 0;
        
        unchecked {
            return (supply * 10000) / maxSupply;
        }
    }

    /**
     * @notice Calculates remaining space for minting new tokens
     * @return Number of tokens that can still be minted
     */
    function getRemainingMintCapacity() external view returns (uint256) {
        uint256 currentSupply = totalSupply();
        if (currentSupply >= maxSupply) return 0;
        
        unchecked {
            return maxSupply - currentSupply;
        }
    }

    /**
     * @notice Gets current rate limit status
     * @return mintedThisHour Amount minted in current hour
     * @return burnedThisHour Amount burned in current hour
     * @return mintLimit Current mint rate limit
     * @return burnLimit Current burn rate limit
     * @return nextResetTime Timestamp when rate limits reset
     */
    function getRateLimitStatus() 
        external 
        view 
        returns (
            uint256 mintedThisHour,
            uint256 burnedThisHour,
            uint256 mintLimit,
            uint256 burnLimit,
            uint256 nextResetTime
        ) 
    {
        // If an hour has passed, return zeros for current hour amounts
        if (block.timestamp >= lastRateLimitReset + 1 hours) {
            return (0, 0, mintRateLimit, burnRateLimit, lastRateLimitReset + 1 hours);
        }
        
        return (
            currentHourMinted,
            currentHourBurned,
            mintRateLimit,
            burnRateLimit,
            lastRateLimitReset + 1 hours
        );
    }

    // =============================================================================
    // INTERNAL OVERRIDES - OpenZeppelin behavior modifications
    // =============================================================================

    /**
     * @notice Hook called before each token transfer
     * @dev Adds pause verification and blacklist checks to standard OpenZeppelin transfers
     * 
     * @param from Source address (address(0) for mint)
     * @param to Destination address (address(0) for burn)  
     * @param amount Amount transferred
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        // Call to parent OpenZeppelin function
        super._beforeTokenTransfer(from, to, amount);
        
        // Blacklist checks (skip for mint operations)
        if (from != address(0)) {
            require(!isBlacklisted[from], "QEURO: Sender is blacklisted");
        }
        if (to != address(0)) {
            require(!isBlacklisted[to], "QEURO: Recipient is blacklisted");
        }

        // Whitelist checks (if enabled, skip for burn operations)
        if (whitelistEnabled && to != address(0)) {
            require(isWhitelisted[to], "QEURO: Recipient not whitelisted");
        }
    }

    // =============================================================================
    // UPGRADE FUNCTIONS - Contract update management
    // =============================================================================

    /**
     * @notice Authorizes contract upgrades
     * @param newImplementation Address of the new implementation
     * 
     * @dev Securities:
     *      - Only UPGRADER_ROLE can upgrade
     *      - Additional validation possible here
     *      - Upgrades can be time-locked by governance
     */
    function _authorizeUpgrade(address newImplementation) 
        internal 
        override 
        onlyRole(UPGRADER_ROLE) 
    {
        // Additional upgrade validations can be added here
        // For example:
        // - Verify that newImplementation is a valid contract
        // - Verify a community signature
        // - Apply a time lock
        
        // For now, only role verification is required
    }

    // =============================================================================
    // RECOVERY FUNCTIONS - Emergency recovery functions
    // =============================================================================

    /**
     * @notice Recovers tokens accidentally sent to the contract
     * 
     * @param token Address of the token contract to recover
     * @param to Address to send recovered tokens to
     * @param amount Amount to recover
     * 
     * @dev Securities:
     *      - Only admin can recover
     *      - Cannot recover own QEURO tokens
     *      - Recipient cannot be zero address
     *      - Uses SafeERC20 for secure transfers
     *      
     * Use cases: 
     *      - A user accidentally sends USDC to the QEURO contract
     *      - Admin can recover them and return them
     */
    function recoverToken(
        address token,
        address to,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Prevents recovery of own QEURO tokens (security)
        require(token != address(this), "QEURO: Cannot recover QEURO tokens");
        require(to != address(0), "QEURO: Cannot send to zero address");
        
        // Transfer of external token using SafeERC20
        IERC20Upgradeable(token).safeTransfer(to, amount);
    }

    /**
     * @notice Recovers ETH accidentally sent to the contract
     * @param to Address to send ETH to
     * 
     * @dev Although token contracts normally don't receive ETH,
     *      this function allows recovery in case of accidental sending
     */
    function recoverETH(address payable to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(to != address(0), "QEURO: Cannot send to zero address");
        require(address(this).balance > 0, "QEURO: No ETH to recover");
        
        to.transfer(address(this).balance);
    }

    // =============================================================================
    // ADMINISTRATIVE FUNCTIONS - Advanced administrative functions
    // =============================================================================

    /**
     * @notice Updates the maximum supply limit (governance only)
     * @param newMaxSupply New supply limit
     * 
     * @dev Function to adjust supply cap if necessary
     *      Requires governance and must be used with caution
     * 
     * @dev IMPROVEMENT: Now functional with dynamic supply cap
     */
    function updateMaxSupply(uint256 newMaxSupply) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(newMaxSupply >= totalSupply(), "QEURO: New cap below current supply");
        require(newMaxSupply > 0, "QEURO: Max supply must be positive");
        
        uint256 oldCap = maxSupply;
        maxSupply = newMaxSupply;
        
        emit SupplyCapUpdated(oldCap, newMaxSupply);
    }

    /**
     * @notice Complete token information (for monitoring)
     * @return name_ Token name
     * @return symbol_ Token symbol  
     * @return decimals_ Number of decimals
     * @return totalSupply_ Current total supply
     * @return maxSupply_ Maximum authorized supply
     * @return isPaused_ Pause state
     * @return whitelistEnabled_ Whether whitelist mode is enabled
     * @return mintRateLimit_ Current mint rate limit
     * @return burnRateLimit_ Current burn rate limit
     */
    function getTokenInfo() 
        external 
        view 
        returns (
            string memory name_,
            string memory symbol_,
            uint8 decimals_,
            uint256 totalSupply_,
            uint256 maxSupply_,
            bool isPaused_,
            bool whitelistEnabled_,
            uint256 mintRateLimit_,
            uint256 burnRateLimit_
        ) 
    {
        return (
            name(),
            symbol(), 
            decimals(),
            totalSupply(),
            maxSupply,
            paused(),
            whitelistEnabled,
            mintRateLimit,
            burnRateLimit
        );
    }
}