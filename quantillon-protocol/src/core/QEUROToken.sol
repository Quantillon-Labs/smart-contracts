// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// =============================================================================
// IMPORTS - OpenZeppelin libraries for security and standards
// =============================================================================

// ERC20 upgradeable with all standard functionality
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
// Replace missing upgradeable IERC20/SafeERC20 with non-upgradeable interface and library
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Role system to control who can do what
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

// Emergency pause mechanism
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

// Base for upgradeable contracts
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// UUPS: Universal Upgradeable Proxy Standard (more gas-efficient than Transparent)
import "./SecureUpgradeable.sol";

// Custom libraries for bytecode reduction
import "../libraries/ErrorLibrary.sol";
import "../libraries/AccessControlLibrary.sol";
import "../libraries/ValidationLibrary.sol";
import "../libraries/TokenLibrary.sol";

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
 * @dev Security features:
 *      - Role-based access control for all critical operations
 *      - Emergency pause mechanism for crisis situations
 *      - Rate limiting to prevent abuse
 *      - Blacklist/whitelist for regulatory compliance
 *      - Upgradeable architecture for future improvements
 * 
 * @dev Tokenomics:
 *      - Initial supply: 0 (all tokens minted through vault operations)
 *      - Maximum supply: Configurable by governance (default 100M QEURO)
 *      - Decimals: 18 (standard for ERC20 tokens)
 *      - Peg: 1:1 with Euro (managed by vault operations)
 * 
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract QEUROToken is 
    Initializable,           // Base for initialization instead of constructor
    ERC20Upgradeable,        // Standard ERC20 token
    AccessControlUpgradeable, // Role management
    PausableUpgradeable,     // Emergency pause
    SecureUpgradeable        // Secure upgrade pattern
{
    using SafeERC20 for IERC20;
    using AccessControlLibrary for AccessControlUpgradeable;
    using ValidationLibrary for uint256;
    using TokenLibrary for address;

    // =============================================================================
    // CONSTANTS - Protocol roles and limits
    // =============================================================================
    
    /// @notice Role for minting tokens (assigned to QuantillonVault only)
    /// @dev keccak256 hash avoids role collisions with other contracts
    /// @dev Only the vault should have this role to maintain tokenomics
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    /// @notice Role for burning tokens (assigned to QuantillonVault only)
    /// @dev keccak256 hash avoids role collisions with other contracts
    /// @dev Only the vault should have this role to maintain tokenomics
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    
    /// @notice Role for pausing the contract in emergency situations
    /// @dev keccak256 hash avoids role collisions with other contracts
    /// @dev Should be assigned to governance or emergency multisig
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    


    /// @notice Role for managing blacklist/whitelist for compliance
    /// @dev keccak256 hash avoids role collisions with other contracts
    /// @dev Should be assigned to compliance team or governance
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");

    /// @notice Default maximum supply limit (100 million QEURO)
    /// @dev Can be updated by governance through updateMaxSupply()
    /// @dev Value: 100,000,000 * 10^18 = 100,000,000 QEURO
    uint256 public constant DEFAULT_MAX_SUPPLY = 100_000_000 * 1e18;

    /// @notice Maximum rate limit for mint/burn operations (per hour)
    /// @dev Prevents abuse and provides time for emergency response
    /// @dev Value: 10,000,000 * 10^18 = 10,000,000 QEURO per hour
    uint256 public constant MAX_RATE_LIMIT = 10_000_000 * 1e18; // 10M QEURO per hour

    /// @notice Precision for decimal calculations (18 decimals)
    /// @dev Standard precision used throughout the protocol
    /// @dev Value: 10^18
    uint256 public constant PRECISION = 1e18;

    // =============================================================================
    // STATE VARIABLES - Dynamic configuration
    // =============================================================================

    /// @notice Current maximum supply limit (updatable by governance)
    /// @dev Initialized to DEFAULT_MAX_SUPPLY, can be changed by governance
    /// @dev Prevents infinite minting and maintains tokenomics
    uint256 public maxSupply;

    /// @notice Packed rate limit caps for mint and burn (per hour)
    /// @dev Two uint128 packed into one slot for storage efficiency
    struct RateLimitCaps { uint128 mint; uint128 burn; }
    RateLimitCaps public rateLimitCaps;

    /// @notice Rate limiting information - OPTIMIZED: Packed for storage efficiency
    /// @dev Resets every hour or when rate limits are updated
    /// @dev Used to enforce mintRateLimit and burnRateLimit
    struct RateLimitInfo {
        uint96 currentHourMinted;  // Current minted amount in the current hour (12 bytes)
        uint96 currentHourBurned;  // Current burned amount in the current hour (12 bytes)
        uint64 lastRateLimitReset; // Timestamp of the last rate limit reset (8 bytes)
        // Total: 12 + 12 + 8 = 32 bytes (fits in 1 slot vs 3 slots)
    }
    
    RateLimitInfo public rateLimitInfo;

    /// @notice Blacklist mapping for compliance and security
    /// @dev Blacklisted addresses cannot transfer or receive tokens
    /// @dev Can be managed by addresses with COMPLIANCE_ROLE
    mapping(address => bool) public isBlacklisted;

    /// @notice Whitelist mapping for compliance (if enabled)
    /// @dev When whitelistEnabled is true, only whitelisted addresses can transfer
    /// @dev Can be managed by addresses with COMPLIANCE_ROLE
    mapping(address => bool) public isWhitelisted;

    /// @notice Whether whitelist mode is enabled
    /// @dev When true, only whitelisted addresses can transfer tokens
    /// @dev Can be toggled by addresses with COMPLIANCE_ROLE
    bool public whitelistEnabled;

    /// @notice Minimum precision for external price feeds
    /// @dev Used to validate price feed precision for accurate calculations
    /// @dev Can be updated by governance through updateMinPricePrecision()
    uint256 public minPricePrecision;

    // =============================================================================
    // EVENTS - Events for tracking and monitoring
    // =============================================================================
    
    /// @notice Emitted when tokens are minted
    /// @param to Recipient of the tokens
    /// @param amount Amount minted in wei (18 decimals)
    /// @param minter Address that performed the mint (vault)
    /// @dev OPTIMIZED: Indexed amount for efficient filtering by mint size
    event TokensMinted(address indexed to, uint256 indexed amount, address indexed minter);
    
    /// @notice Emitted when tokens are burned
    /// @param from Address from which tokens are burned
    /// @param amount Amount burned in wei (18 decimals)
    /// @param burner Address that performed the burn (vault)
    /// @dev OPTIMIZED: Indexed amount for efficient filtering by burn size
    event TokensBurned(address indexed from, uint256 indexed amount, address indexed burner);
    
    /// @notice Emitted when the supply limit is modified
    /// @param oldCap Old supply limit in wei (18 decimals)
    /// @param newCap New supply limit in wei (18 decimals)
    /// @dev Emitted when governance updates the maximum supply
    event SupplyCapUpdated(uint256 oldCap, uint256 newCap);

    /// @notice Emitted when rate limits are updated
    /// @param mintLimit New mint rate limit in wei per hour (18 decimals)
    /// @param burnLimit New burn rate limit in wei per hour (18 decimals)
    /// @dev OPTIMIZED: Indexed parameter type for efficient filtering
    event RateLimitsUpdated(string indexed limitType, uint256 mintLimit, uint256 burnLimit);

    /// @notice Emitted when an address is blacklisted
    /// @param account Address that was blacklisted
    /// @param reason Reason for blacklisting (for compliance records)
    /// @dev OPTIMIZED: Indexed reason for efficient filtering by blacklist type
    event AddressBlacklisted(address indexed account, string indexed reason);

    /// @notice Emitted when an address is removed from blacklist
    /// @param account Address that was removed from blacklist
    /// @dev Emitted when COMPLIANCE_ROLE removes an address from blacklist
    event AddressUnblacklisted(address indexed account);

    /// @notice Emitted when an address is whitelisted
    /// @param account Address that was whitelisted
    /// @dev Emitted when COMPLIANCE_ROLE whitelists an address
    event AddressWhitelisted(address indexed account);

    /// @notice Emitted when an address is removed from whitelist
    /// @param account Address that was removed from whitelist
    /// @dev Emitted when COMPLIANCE_ROLE removes an address from whitelist
    event AddressUnwhitelisted(address indexed account);

    /// @notice Emitted when whitelist mode is toggled
    /// @param enabled Whether whitelist mode is enabled
    /// @dev Emitted when COMPLIANCE_ROLE toggles whitelist mode
    event WhitelistModeToggled(bool enabled);

    /// @notice Emitted when minimum price precision is updated
    /// @param oldPrecision Old minimum precision value
    /// @param newPrecision New minimum precision value
    /// @dev Emitted when governance updates minimum price precision
    event MinPricePrecisionUpdated(uint256 oldPrecision, uint256 newPrecision);

    /// @notice Emitted when rate limit is reset
    /// @param timestamp Timestamp of reset
    /// @dev OPTIMIZED: Indexed timestamp for efficient time-based filtering
    event RateLimitReset(uint256 indexed timestamp);

    // =============================================================================
    // MODIFIERS - Access control and security
    // =============================================================================

    /**
     * @notice Modifier to protect against flash loan attacks
     * @dev Checks that the contract's QEURO balance doesn't decrease during execution
     * @dev This prevents flash loans that would drain QEURO from the contract
     */
    modifier flashLoanProtection() {
        uint256 balanceBefore = balanceOf(address(this));
        _;
        uint256 balanceAfter = balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "Flash loan detected: QEURO balance decreased");
    }

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
     * 
     * @dev Security considerations:
     *      - Only callable once (initializer modifier)
     *      - Validates input parameters
     *      - Sets up proper role hierarchy
     *      - Initializes all state variables
     */
    function initialize(
        address admin,
        address vault,
        address timelock
    ) public initializer {
        // Input parameter validation
        AccessControlLibrary.validateAddress(admin);
        AccessControlLibrary.validateAddress(vault);
        AccessControlLibrary.validateAddress(timelock);

        // Initialize parent contracts
        __ERC20_init("Quantillon Euro", "QEURO");
        __AccessControl_init();
        __Pausable_init();
        __SecureUpgradeable_init(timelock);

        // Set up roles and permissions
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, vault);
        _grantRole(BURNER_ROLE, vault);
        _grantRole(PAUSER_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        _grantRole(COMPLIANCE_ROLE, admin);

        // Initialize state variables
        maxSupply = DEFAULT_MAX_SUPPLY;
        rateLimitCaps = RateLimitCaps(uint128(MAX_RATE_LIMIT), uint128(MAX_RATE_LIMIT));
        rateLimitInfo = RateLimitInfo(0, 0, uint64(block.timestamp));
        whitelistEnabled = false;
        minPricePrecision = 1e8; // 8 decimals minimum for price feeds
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
     * 
     * @dev Security considerations:
     *      - Only MINTER_ROLE can mint
     *      - Pause check
     *      - Rate limiting
     *      - Blacklist/whitelist checks
     *      - Supply cap verification
     *      - Secure minting using OpenZeppelin
     */
    function mint(address to, uint256 amount) 
        external 
        onlyRole(MINTER_ROLE)    // Only the vault can mint
        whenNotPaused            // Not in pause mode
    {
        // Strict parameter validation
        TokenLibrary.validateMint(to, amount, totalSupply(), maxSupply);
        
        // Blacklist check
        if (isBlacklisted[to]) revert ErrorLibrary.BlacklistedAddress();
        
        // Whitelist check (if enabled)
        if (whitelistEnabled && !isWhitelisted[to]) {
            revert ErrorLibrary.NotWhitelisted();
        }

        // Rate limiting check
        _checkAndUpdateMintRateLimit(amount);
        
        // Supply cap verification to prevent excessive inflation
        // Handled by TokenLibrary.validateMint()

        // Actual mint (secure OpenZeppelin function)
        _mint(to, amount);
        
        // Event for tracking
        emit TokensMinted(to, amount, msg.sender);
    }

    /**
     * @notice Batch mint QEURO tokens to multiple addresses
     * 
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts to mint (18 decimals)
     *
     * @dev Applies the same validations as single mint per item to avoid bypassing
     *      rate limits, blacklist/whitelist checks, and max supply constraints.
     *      Using external mint for each entry reuses all checks and events.
     */
    function batchMint(address[] calldata recipients, uint256[] calldata amounts)
        external
        onlyRole(MINTER_ROLE)
        whenNotPaused
        flashLoanProtection
    {
        if (recipients.length != amounts.length) revert ErrorLibrary.ArrayLengthMismatch();
        
        uint256 totalAmount = 0;
        
        // Pre-validate inputs and compliance per recipient
        for (uint256 i = 0; i < recipients.length; i++) {
            address to = recipients[i];
            uint256 amount = amounts[i];
            
            if (to == address(0)) revert ErrorLibrary.InvalidAddress();
            if (amount == 0) revert ErrorLibrary.InvalidAmount();
            
            if (isBlacklisted[to]) revert ErrorLibrary.BlacklistedAddress();
            if (whitelistEnabled && !isWhitelisted[to]) revert ErrorLibrary.NotWhitelisted();
            
            // Accumulate total to check supply cap and rate limits once
            totalAmount = totalAmount + amount;
        }
        
        // Supply cap verification for the whole batch
        if (totalSupply() + totalAmount > maxSupply) revert ErrorLibrary.WouldExceedLimit();

        // Rate limiting for the whole batch
        _checkAndUpdateMintRateLimit(totalAmount);

        // Perform mints
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
            emit TokensMinted(recipients[i], amounts[i], msg.sender);
        }
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
     * 
     * @dev Security considerations:
     *      - Only BURNER_ROLE can burn
     *      - Pause check
     *      - Rate limiting
     *      - Secure burning using OpenZeppelin
     */
    function burn(address from, uint256 amount) 
        external 
        onlyRole(BURNER_ROLE)    // Only the vault can burn
        whenNotPaused            // Not in pause mode
        flashLoanProtection
    {
        // Parameter validation
        TokenLibrary.validateBurn(from, amount, balanceOf(from));

        // Rate limiting check
        _checkAndUpdateBurnRateLimit(amount);

        // Actual burn (secure OpenZeppelin function)
        _burn(from, amount);
        
        // Event for tracking
        emit TokensBurned(from, amount, msg.sender);
    }

    /**
     * @notice Batch burn QEURO tokens from multiple addresses
     * 
     * @param froms Array of addresses to burn from
     * @param amounts Array of amounts to burn (18 decimals)
     *
     * @dev Applies the same validations as single burn per item to avoid bypassing
     *      rate limits and balance checks. Accumulates total for rate limiting.
     */
    function batchBurn(address[] calldata froms, uint256[] calldata amounts)
        external
        onlyRole(BURNER_ROLE)
        whenNotPaused
        flashLoanProtection
    {
        if (froms.length != amounts.length) revert ErrorLibrary.ArrayLengthMismatch();
        
        uint256 totalAmount = 0;
        
        // Pre-validate inputs per address
        for (uint256 i = 0; i < froms.length; i++) {
            address from = froms[i];
            uint256 amount = amounts[i];
            
            if (from == address(0)) revert ErrorLibrary.InvalidAddress();
            if (amount == 0) revert ErrorLibrary.InvalidAmount();
            if (balanceOf(from) < amount) revert ErrorLibrary.InsufficientBalance();
            
            // Accumulate total to check rate limits once
            totalAmount = totalAmount + amount;
        }
        
        // Rate limiting for the whole batch
        _checkAndUpdateBurnRateLimit(totalAmount);

        // Perform burns
        for (uint256 i = 0; i < froms.length; i++) {
            _burn(froms[i], amounts[i]);
            emit TokensBurned(froms[i], amounts[i], msg.sender);
        }
    }

    // =============================================================================
    // RATE LIMITING FUNCTIONS - Rate limiting for mint/burn operations
    // =============================================================================

    /**
     * @notice Checks and updates mint rate limit
     * @param amount Amount being minted
     * @dev Internal function to enforce rate limiting
     * 
     * @dev Security considerations:
     *      - Resets rate limit if an hour has passed
     *      - Checks if the new amount would exceed the rate limit
     *      - Updates the current hour minted amount
     *      - Throws an error if rate limit is exceeded
     *      - Includes bounds checking to prevent timestamp manipulation
     * 

     */
    function _checkAndUpdateMintRateLimit(uint256 amount) internal {
        // Reset rate limit if an hour has passed
        uint256 timeSinceReset = block.timestamp - rateLimitInfo.lastRateLimitReset;
        
        // SECURITY FIX: Bounds check to prevent timestamp manipulation
        // Caps time elapsed at 24 hours maximum to prevent excessive manipulation
        if (timeSinceReset > 24 hours) {
            timeSinceReset = 24 hours; // Cap at 24 hours maximum
        }
        
        if (timeSinceReset >= 1 hours) {
            rateLimitInfo.currentHourMinted = 0;
            rateLimitInfo.currentHourBurned = 0;
            rateLimitInfo.lastRateLimitReset = uint64(block.timestamp);
            emit RateLimitReset(block.timestamp);
        }

        // Check if the new amount would exceed the rate limit
        if (rateLimitInfo.currentHourMinted + amount > rateLimitCaps.mint) {
            revert ErrorLibrary.RateLimitExceeded();
        }

        // Update the current hour minted amount - OPTIMIZED: Use unchecked for safe arithmetic
        unchecked {
            rateLimitInfo.currentHourMinted = uint96(rateLimitInfo.currentHourMinted + amount);
        }
    }

    /**
     * @notice Checks and updates burn rate limit
     * @param amount Amount being burned
     * @dev Internal function to enforce rate limiting
     * 
     * @dev Security considerations:
     *      - Resets rate limit if an hour has passed
     *      - Checks if the new amount would exceed the rate limit
     *      - Updates the current hour burned amount
     *      - Throws an error if rate limit is exceeded
     *      - Includes bounds checking to prevent timestamp manipulation
     * 

     */
    function _checkAndUpdateBurnRateLimit(uint256 amount) internal {
        // Reset rate limit if an hour has passed
        uint256 timeSinceReset = block.timestamp - rateLimitInfo.lastRateLimitReset;
        
        // SECURITY FIX: Bounds check to prevent timestamp manipulation
        // Caps time elapsed at 24 hours maximum to prevent excessive manipulation
        if (timeSinceReset > 24 hours) {
            timeSinceReset = 24 hours; // Cap at 24 hours maximum
        }
        
        if (timeSinceReset >= 1 hours) {
            rateLimitInfo.currentHourMinted = 0;
            rateLimitInfo.currentHourBurned = 0;
            rateLimitInfo.lastRateLimitReset = uint64(block.timestamp);
            emit RateLimitReset(block.timestamp);
        }

        // Check if the new amount would exceed the rate limit
        if (rateLimitInfo.currentHourBurned + amount > rateLimitCaps.burn) {
            revert ErrorLibrary.RateLimitExceeded();
        }

        // Update the current hour burned amount - OPTIMIZED: Use unchecked for safe arithmetic
        unchecked {
            rateLimitInfo.currentHourBurned = uint96(rateLimitInfo.currentHourBurned + amount);
        }
    }

    /**
     * @notice Updates rate limits for mint and burn operations
     * @param newMintLimit New mint rate limit per hour
     * @param newBurnLimit New burn rate limit per hour
     * @dev Only callable by admin
     * 
     * @dev Security considerations:
     *      - Validates new limits
     *      - Ensures new limits are not zero
     *      - Ensures new limits are not too high
     *      - Updates rateLimitCaps (mint and burn) in a single storage slot
     *      - Emits RateLimitsUpdated event
     */
    function updateRateLimits(uint256 newMintLimit, uint256 newBurnLimit) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        ValidationLibrary.validatePositiveAmount(newMintLimit);
        ValidationLibrary.validatePositiveAmount(newBurnLimit);
        if (newMintLimit > MAX_RATE_LIMIT) revert ErrorLibrary.RateLimitTooHigh();
        if (newBurnLimit > MAX_RATE_LIMIT) revert ErrorLibrary.RateLimitTooHigh();

        rateLimitCaps = RateLimitCaps(uint128(newMintLimit), uint128(newBurnLimit));

        emit RateLimitsUpdated("rate_limits", newMintLimit, newBurnLimit);
    }

    // =============================================================================
    // COMPLIANCE FUNCTIONS - Blacklist and whitelist management
    // =============================================================================

    /**
     * @notice Blacklists an address
     * @param account Address to blacklist
     * @param reason Reason for blacklisting
     * @dev Only callable by compliance role
     * 
     * @dev Security considerations:
     *      - Validates input parameters
     *      - Prevents blacklisting of zero address
     *      - Prevents blacklisting of already blacklisted addresses
     *      - Updates isBlacklisted mapping
     *      - Emits AddressBlacklisted event
     */
    function blacklistAddress(address account, string memory reason) 
        external 
        onlyRole(COMPLIANCE_ROLE) 
    {
        AccessControlLibrary.validateAddress(account);
        if (isBlacklisted[account]) revert ErrorLibrary.AlreadyBlacklisted();
        
        isBlacklisted[account] = true;
        emit AddressBlacklisted(account, reason);
    }

    /**
     * @notice Removes an address from blacklist
     * @param account Address to remove from blacklist
     * @dev Only callable by compliance role
     * 
     * @dev Security considerations:
     *      - Validates input parameter
     *      - Prevents unblacklisting of non-blacklisted addresses
     *      - Updates isBlacklisted mapping
     *      - Emits AddressUnblacklisted event
     */
    function unblacklistAddress(address account) 
        external 
        onlyRole(COMPLIANCE_ROLE) 
    {
        if (!isBlacklisted[account]) revert ErrorLibrary.NotBlacklisted();
        
        isBlacklisted[account] = false;
        emit AddressUnblacklisted(account);
    }

    /**
     * @notice Whitelists an address
     * @param account Address to whitelist
     * @dev Only callable by compliance role
     * 
     * @dev Security considerations:
     *      - Validates input parameters
     *      - Prevents whitelisting of zero address
     *      - Prevents whitelisting of already whitelisted addresses
     *      - Updates isWhitelisted mapping
     *      - Emits AddressWhitelisted event
     */
    function whitelistAddress(address account) 
        external 
        onlyRole(COMPLIANCE_ROLE) 
    {
        AccessControlLibrary.validateAddress(account);
        if (isWhitelisted[account]) revert ErrorLibrary.AlreadyWhitelisted();
        
        isWhitelisted[account] = true;
        emit AddressWhitelisted(account);
    }

    /**
     * @notice Removes an address from whitelist
     * @param account Address to remove from whitelist
     * @dev Only callable by compliance role
     * 
     * @dev Security considerations:
     *      - Validates input parameter
     *      - Prevents unwhitelisting of non-whitelisted addresses
     *      - Updates isWhitelisted mapping
     *      - Emits AddressUnwhitelisted event
     */
    function unwhitelistAddress(address account) 
        external 
        onlyRole(COMPLIANCE_ROLE) 
    {
        if (!isWhitelisted[account]) revert ErrorLibrary.NotWhitelisted();
        
        isWhitelisted[account] = false;
        emit AddressUnwhitelisted(account);
    }

    /**
     * @notice Toggles whitelist mode
     * @param enabled Whether to enable whitelist mode
     * @dev Only callable by compliance role
     * 
     * @dev Security considerations:
     *      - Validates input parameter
     *      - Updates whitelistEnabled state
     *      - Emits WhitelistModeToggled event
     */
    function toggleWhitelistMode(bool enabled) 
        external 
        onlyRole(COMPLIANCE_ROLE) 
    {
        whitelistEnabled = enabled;
        emit WhitelistModeToggled(enabled);
    }

    /**
     * @notice Batch blacklist multiple addresses
     * @param accounts Array of addresses to blacklist
     * @param reasons Array of reasons for blacklisting
     * @dev Only callable by compliance role
     */
    function batchBlacklistAddresses(address[] calldata accounts, string[] calldata reasons)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        if (accounts.length != reasons.length) revert ErrorLibrary.ArrayLengthMismatch();
        
        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            AccessControlLibrary.validateAddress(account);
            if (isBlacklisted[account]) revert ErrorLibrary.AlreadyBlacklisted();
            
            isBlacklisted[account] = true;
            emit AddressBlacklisted(account, reasons[i]);
        }
    }

    /**
     * @notice Batch unblacklist multiple addresses
     * @param accounts Array of addresses to remove from blacklist
     * @dev Only callable by compliance role
     */
    function batchUnblacklistAddresses(address[] calldata accounts)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            if (!isBlacklisted[account]) revert ErrorLibrary.NotBlacklisted();
            
            isBlacklisted[account] = false;
            emit AddressUnblacklisted(account);
        }
    }

    /**
     * @notice Batch whitelist multiple addresses
     * @param accounts Array of addresses to whitelist
     * @dev Only callable by compliance role
     */
    function batchWhitelistAddresses(address[] calldata accounts)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            AccessControlLibrary.validateAddress(account);
            if (isWhitelisted[account]) revert ErrorLibrary.AlreadyWhitelisted();
            
            isWhitelisted[account] = true;
            emit AddressWhitelisted(account);
        }
    }

    /**
     * @notice Batch unwhitelist multiple addresses
     * @param accounts Array of addresses to remove from whitelist
     * @dev Only callable by compliance role
     */
    function batchUnwhitelistAddresses(address[] calldata accounts)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            if (!isWhitelisted[account]) revert ErrorLibrary.NotWhitelisted();
            
            isWhitelisted[account] = false;
            emit AddressUnwhitelisted(account);
        }
    }

    // =============================================================================
    // DECIMAL PRECISION FUNCTIONS - Handle precision issues with external price feeds
    // =============================================================================

    /**
     * @notice Updates minimum price precision for external feeds
     * @param newPrecision New minimum precision (e.g., 1e6 for 6 decimals)
     * @dev Only callable by admin
     * 
     * @dev Security considerations:
     *      - Validates input parameter
     *      - Prevents setting precision to zero
     *      - Prevents setting precision higher than PRECISION
     *      - Updates minPricePrecision
     *      - Emits MinPricePrecisionUpdated event
     */
    function updateMinPricePrecision(uint256 newPrecision) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        ValidationLibrary.validatePositiveAmount(newPrecision);
        if (newPrecision > PRECISION) revert ErrorLibrary.PrecisionTooHigh();

        uint256 oldPrecision = minPricePrecision;
        minPricePrecision = newPrecision;

        emit MinPricePrecisionUpdated(oldPrecision, newPrecision);
    }

    /**
     * @notice Normalizes a price value to 18 decimals
     * @param price Price value from external feed
     * @param feedDecimals Number of decimals in the price feed
     * @return Normalized price with 18 decimals
     * @dev Helper function for external integrations
     * 
     * @dev Security considerations:
     *      - Validates input parameters
     *      - Prevents too many decimals
     *      - Prevents zero price
     *      - Handles normalization correctly
     */
    function normalizePrice(uint256 price, uint8 feedDecimals) 
        external 
        pure 
        returns (uint256) 
    {
        if (feedDecimals > 18) revert ErrorLibrary.TooManyDecimals();
        ValidationLibrary.validatePositiveAmount(price);

        if (feedDecimals == 18) {
            return price;
        } else if (feedDecimals < 18) {
            unchecked {
                return price * (10 ** (18 - feedDecimals));
            }
        } else {
            unchecked {
                return price / (10 ** (feedDecimals - 18));
            }
        }
    }

    /**
     * @notice Validates price precision from external feed
     * @param price Price value from external feed
     * @param feedDecimals Number of decimals in the price feed
     * @return Whether the price meets minimum precision requirements
     * @dev Helper function for external integrations
     * 
     * @dev Security considerations:
     *      - Validates input parameters
     *      - Handles normalization if feedDecimals is not 18
     *      - Returns true if price is above or equal to minPricePrecision
     */
    function validatePricePrecision(uint256 price, uint8 feedDecimals) 
        external 
        view 
        returns (bool) 
    {
        if (feedDecimals == 0) return price >= minPricePrecision;
        
        uint256 normalizedPrice = this.normalizePrice(price, feedDecimals);
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
     * 
     * @dev Security considerations:
     *      - Only PAUSER_ROLE can pause
     *      - Pauses all token operations
     *      - Prevents any state changes
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Removes pause and restores normal operations
     * 
     * @dev Can only be called by a PAUSER_ROLE
     *      Used after resolving the issue that caused the pause
     * 
     * @dev Security considerations:
     *      - Only PAUSER_ROLE can unpause
     *      - Unpauses all token operations
     *      - Allows normal state changes
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
     * 
     * @dev Security considerations:
     *      - Always returns 18
     *      - No input validation
     *      - No state changes
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    /**
     * @notice Checks if an address has the minter role
     * @param account Address to check
     * @return true if the address can mint
     * 
     * @dev Security considerations:
     *      - Checks if account has MINTER_ROLE
     *      - No input validation
     *      - No state changes
     */
    function isMinter(address account) external view returns (bool) {
        return hasRole(MINTER_ROLE, account);
    }

    /**
     * @notice Checks if an address has the burner role
     * @param account Address to check  
     * @return true if the address can burn
     * 
     * @dev Security considerations:
     *      - Checks if account has BURNER_ROLE
     *      - No input validation
     *      - No state changes
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
     * 
     * @dev Security considerations:
     *      - Calculates percentage based on totalSupply and maxSupply
     *      - Handles division by zero
     *      - Returns 0 if totalSupply is 0
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
     * 
     * @dev Security considerations:
     *      - Calculates remaining capacity by subtracting currentSupply from maxSupply
     *      - Handles case where currentSupply >= maxSupply
     *      - Returns 0 if no more minting is possible
     */


    /**
     * @notice Gets current rate limit status
     * @return mintedThisHour Amount minted in current hour
     * @return burnedThisHour Amount burned in current hour
     * @return mintLimit Current mint rate limit
     * @return burnLimit Current burn rate limit
     * @return nextResetTime Timestamp when rate limits reset
     * 

     * 
     * @dev Security considerations:
     *      - Returns current hour amounts if within the hour
     *      - Returns zeros if an hour has passed
     *      - Returns current limits and next reset time
     *      - Includes bounds checking to prevent timestamp manipulation
     */


    /**
     * @notice Batch transfer QEURO tokens to multiple addresses
     * 
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts to transfer (18 decimals)
     *
     * @dev Performs multiple transfers from msg.sender to recipients.
     *      Uses OpenZeppelin's transfer mechanism with compliance checks.
     */
    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts)
        external
        whenNotPaused
        returns (bool)
    {
        if (recipients.length != amounts.length) revert ErrorLibrary.ArrayLengthMismatch();
        
        // Pre-validate recipients and amounts
        for (uint256 i = 0; i < recipients.length; i++) {
            address to = recipients[i];
            uint256 amount = amounts[i];
            
            if (to == address(0)) revert ErrorLibrary.InvalidAddress();
            if (amount == 0) revert ErrorLibrary.InvalidAmount();
            
            // Check compliance (blacklist/whitelist) per recipient
            if (isBlacklisted[msg.sender]) revert ErrorLibrary.BlacklistedAddress();
            if (isBlacklisted[to]) revert ErrorLibrary.BlacklistedAddress();
            if (whitelistEnabled && !isWhitelisted[to]) revert ErrorLibrary.NotWhitelisted();
        }
        
        // Perform transfers using OpenZeppelin's transfer mechanism
        for (uint256 i = 0; i < recipients.length; i++) {
            _transfer(msg.sender, recipients[i], amounts[i]);
        }
        
        return true;
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
     * 
     * @dev Security considerations:
     *      - Checks if transfer is from a blacklisted address
     *      - Checks if transfer is to a blacklisted address
     *      - If whitelist is enabled, checks if recipient is whitelisted
     *      - Prevents transfers if any checks fail
     *      - Calls super._update for standard ERC20 logic
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        // Blacklist checks (skip for mint operations)
        if (from != address(0) && isBlacklisted[from]) {
            revert ErrorLibrary.BlacklistedAddress();
        }
        if (to != address(0) && isBlacklisted[to]) {
            revert ErrorLibrary.BlacklistedAddress();
        }

        // Whitelist checks (if enabled, skip for burn operations)
        if (whitelistEnabled && to != address(0) && !isWhitelisted[to]) {
            revert ErrorLibrary.NotWhitelisted();
        }

        super._update(from, to, amount);
    }

    // =============================================================================
    // UPGRADE FUNCTIONS - Contract update management
    // =============================================================================



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
     * 
     * @dev Security considerations:
     *      - Only DEFAULT_ADMIN_ROLE can recover
     *      - Prevents recovery of own QEURO tokens
     *      - Validates input parameters
     *      - Uses SafeERC20 for secure transfers
     */
    function recoverToken(
        address token,
        address to,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Prevents recovery of own QEURO tokens (security)
        if (token == address(this)) revert ErrorLibrary.CannotRecoverQEURO();
        AccessControlLibrary.validateAddress(to);
        
        // Transfer of external token using SafeERC20
        IERC20(token).safeTransfer(to, amount);
    }

    /**
     * @notice Recovers ETH accidentally sent
     * @param to ETH recipient
     * 

     * 
     * @dev Security considerations:
     *      - Only DEFAULT_ADMIN_ROLE can recover
     *      - Prevents sending to zero address
     *      - Validates balance before attempting transfer
     *      - Uses call() for reliable ETH transfers to any contract
     */
    function recoverETH(address payable to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        AccessControlLibrary.validateAddress(to);
        uint256 balance = address(this).balance;
        if (balance == 0) revert ErrorLibrary.NoETHToRecover();
        
        // SECURITY FIX: Use call() instead of transfer() for reliable ETH transfers
        // transfer() has 2300 gas stipend which can fail with complex receive/fallback logic
        (bool success, ) = to.call{value: balance}("");
        if (!success) revert ErrorLibrary.ETHTransferFailed();
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
     * 
     * @dev Security considerations:
     *      - Only DEFAULT_ADMIN_ROLE can update
     *      - Validates newMaxSupply
     *      - Prevents setting cap below current supply
     *      - Prevents setting cap to zero
     *      - Emits SupplyCapUpdated event
     */
    function updateMaxSupply(uint256 newMaxSupply) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        if (newMaxSupply < totalSupply()) revert ErrorLibrary.NewCapBelowCurrentSupply();
        ValidationLibrary.validatePositiveAmount(newMaxSupply);
        
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
     * 
     * @dev Security considerations:
     *      - Returns current state of the token
     *      - No input validation
     *      - No state changes
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
            rateLimitCaps.mint,
            rateLimitCaps.burn
        );
    }

    /**
     * @notice Get current mint rate limit (per hour)
     * @return limit Mint rate limit in wei per hour (18 decimals)
     */
    function mintRateLimit() external view returns (uint256 limit) {
        return rateLimitCaps.mint;
    }

    /**
     * @notice Get current burn rate limit (per hour)
     * @return limit Burn rate limit in wei per hour (18 decimals)
     */
    function burnRateLimit() external view returns (uint256 limit) {
        return rateLimitCaps.burn;
    }
}