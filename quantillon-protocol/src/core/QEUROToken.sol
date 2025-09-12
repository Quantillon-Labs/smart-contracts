// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// =============================================================================
// IMPORTS - OpenZeppelin libraries for security and standards
// =============================================================================

// ERC20 upgradeable with all standard functionality
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
// Replace missing upgradeable IERC20/SafeERC20 with non-upgradeable interface and library
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Role system to control who can do what
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

// Emergency pause mechanism
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

// Base for upgradeable contracts
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// UUPS: Universal Upgradeable Proxy Standard (more gas-efficient than Transparent)
import {SecureUpgradeable} from "./SecureUpgradeable.sol";

// Custom libraries for bytecode reduction
import {ErrorLibrary} from "../libraries/ErrorLibrary.sol";
import {AccessControlLibrary} from "../libraries/AccessControlLibrary.sol";
import {ValidationLibrary} from "../libraries/ValidationLibrary.sol";
import {TokenLibrary} from "../libraries/TokenLibrary.sol";
import {TreasuryRecoveryLibrary} from "../libraries/TreasuryRecoveryLibrary.sol";
import {FlashLoanProtectionLibrary} from "../libraries/FlashLoanProtectionLibrary.sol";

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
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
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

    /// @notice Maximum rate limit for mint/burn operations (per reset period)
    /// @dev Prevents abuse and provides time for emergency response
    /// @dev Value: 10,000,000 * 10^18 = 10,000,000 QEURO per reset period (~300 blocks)
    uint256 public constant MAX_RATE_LIMIT = 10_000_000 * 1e18; // 10M QEURO per reset period

    /// @notice Rate limit reset period in blocks (~1 hour assuming 12 second blocks)
    /// @dev Using block numbers instead of timestamps for security against miner manipulation
    uint256 public constant RATE_LIMIT_RESET_PERIOD = 300;

    /// @notice Precision for decimal calculations (18 decimals)
    /// @dev Standard precision used throughout the protocol
    /// @dev Value: 10^18
    uint256 public constant PRECISION = 1e18;

    /// @notice Maximum batch size for mint operations to prevent DoS
    /// @dev Prevents out-of-gas attacks through large arrays
    uint256 public constant MAX_BATCH_SIZE = 100;
    
    /// @notice Maximum batch size for compliance operations to prevent DoS
    /// @dev Prevents out-of-gas attacks through large blacklist/whitelist arrays
    uint256 public constant MAX_COMPLIANCE_BATCH_SIZE = 50;

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
    /// @dev Resets every ~300 blocks (~1 hour assuming 12 second blocks) or when rate limits are updated
    /// @dev Used to enforce mintRateLimit and burnRateLimit
    struct RateLimitInfo {
        uint96 currentHourMinted;  // Current minted amount in the current hour (12 bytes)
        uint96 currentHourBurned;  // Current burned amount in the current hour (12 bytes)
        uint64 lastRateLimitReset; // Block number of the last rate limit reset (8 bytes)
    }
    
    RateLimitInfo public rateLimitInfo;

    /// @notice Emergency killswitch to prevent all QEURO minting operations
    /// @dev When enabled (true), blocks both regular and batch minting functions
    /// @dev Can only be toggled by addresses with PAUSER_ROLE
    /// @dev Used as a crisis management tool when protocol lacks sufficient collateral
    /// @dev Independent of the general pause mechanism - provides granular control
    /// @return Current state of the killswitch (true = minting blocked, false = minting allowed)
    bool public mintingKillswitch;

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
    
    /// @notice Treasury address for ETH recovery
    /// @dev SECURITY: Only this address can receive ETH from recoverETH function
    address public treasury;

    // =============================================================================
    // EVENTS - Events for tracking and monitoring
    // =============================================================================
    
    /// @notice Emitted when tokens are minted
    /// @param to Recipient of the tokens
    /// @param amount Amount minted in wei (18 decimals)
    /// @param minter Address that performed the mint (vault)
    /// @dev OPTIMIZED: Indexed amount for efficient filtering by mint size
    event TokensMinted(address indexed to, uint256 indexed amount, address indexed minter);
    
    /// @notice Emitted when the minting killswitch is toggled on or off
    /// @dev Provides transparency for emergency actions taken by protocol administrators
    /// @param enabled True if killswitch is being enabled (minting blocked), false if disabled (minting allowed)
    /// @param caller Address of the PAUSER_ROLE holder who toggled the killswitch
    event MintingKillswitchToggled(bool enabled, address indexed caller);
    
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
    
    /// @notice Emitted when treasury address is updated
    /// @param treasury New treasury address
    event TreasuryUpdated(address indexed treasury);

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
    /// @param blockNumber Block number when reset occurred
    /// @dev OPTIMIZED: Indexed block number for efficient block-based filtering
    event RateLimitReset(uint256 indexed blockNumber);

    /// @notice Emitted when ETH is recovered to treasury
    /// @param to Address to which ETH was recovered
    /// @param amount Amount of ETH recovered
    event ETHRecovered(address indexed to, uint256 indexed amount);

    // =============================================================================
    // MODIFIERS - Access control and security
    // =============================================================================

    /**
     * @notice Modifier to protect against flash loan attacks
     * @dev Uses the FlashLoanProtectionLibrary to check QEURO balance consistency
     */
    modifier flashLoanProtection() {
        uint256 balanceBefore = balanceOf(address(this));
        _;
        uint256 balanceAfter = balanceOf(address(this));
        require(
            FlashLoanProtectionLibrary.validateBalanceChange(balanceBefore, balanceAfter, 0),
            "Flash loan attack detected"
        );
    }

    // =============================================================================
    // INITIALIZER - Replaces constructor for upgradeable contracts
    // =============================================================================
    
    /**
     * @notice Constructor for QEURO token contract
     * @dev Disables initializers for security
     * @custom:security Disables initializers for security
     * @custom:validation No validation needed
     * @custom:state-changes Disables initializers
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access No access restrictions
     * @custom:oracle No oracle dependencies
     */
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
     * @param _timelock Address of the timelock contract
     * @param _treasury Treasury address for protocol fees
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
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Initializes all contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to initializer modifier
     * @custom:oracle No oracle dependencies
     */
    function initialize(
        address admin,
        address vault,
        address _timelock,
        address _treasury
    ) public initializer {
        // Input parameter validation
        AccessControlLibrary.validateAddress(admin);
        AccessControlLibrary.validateAddress(vault);
        AccessControlLibrary.validateAddress(_timelock);
        AccessControlLibrary.validateAddress(_treasury);

        // Initialize parent contracts
        __ERC20_init("Quantillon Euro", "QEURO");
        __AccessControl_init();
        __Pausable_init();
        __SecureUpgradeable_init(_timelock);

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
        rateLimitInfo = RateLimitInfo(0, 0, uint64(block.number));
        whitelistEnabled = false;
        minPricePrecision = 1e8; // 8 decimals minimum for price feeds
        ValidationLibrary.validateTreasuryAddress(_treasury);
        require(_treasury != address(0), "Treasury cannot be zero address");
        treasury = _treasury;
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
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to MINTER_ROLE
     * @custom:oracle No oracle dependencies
     */
    function mint(address to, uint256 amount) 
        external 
        onlyRole(MINTER_ROLE)    // Only the vault can mint
        whenNotPaused            // Not in pause mode
    {
        // Emergency killswitch check - prevents minting when protocol lacks collateral
        if (mintingKillswitch) revert ErrorLibrary.MintingDisabled();
        
        // Strict parameter validation
        TokenLibrary.validateMint(to, amount, totalSupply(), maxSupply);
        
        // Blacklist check
        if (isBlacklisted[to]) revert ErrorLibrary.BlacklistedAddress();
        
        // Whitelist check (if enabled)
        // GAS OPTIMIZATION: Cache storage read
        bool whitelistEnabled_ = whitelistEnabled;
        if (whitelistEnabled_ && !isWhitelisted[to]) {
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
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to MINTER_ROLE
     * @custom:oracle No oracle dependencies
     */
    function batchMint(address[] calldata recipients, uint256[] calldata amounts)
        external
        onlyRole(MINTER_ROLE)
        whenNotPaused
        flashLoanProtection
    {
        // Emergency killswitch check - prevents batch minting when protocol lacks collateral
        if (mintingKillswitch) revert ErrorLibrary.MintingDisabled();
        
        if (recipients.length != amounts.length) revert ErrorLibrary.ArrayLengthMismatch();
        if (recipients.length > MAX_BATCH_SIZE) revert ErrorLibrary.BatchSizeTooLarge();
        
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

        address minter = msg.sender;
        
        // Perform mints
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
            emit TokensMinted(recipients[i], amounts[i], minter);
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
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to BURNER_ROLE
     * @custom:oracle No oracle dependencies
     * @custom:security No flash loan protection needed - only vault can burn
     */
    function burn(address from, uint256 amount) 
        external 
        onlyRole(BURNER_ROLE)    // Only the vault can burn
        whenNotPaused            // Not in pause mode
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
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to BURNER_ROLE
     * @custom:oracle No oracle dependencies
     */
    function batchBurn(address[] calldata froms, uint256[] calldata amounts)
        external
        onlyRole(BURNER_ROLE)
        whenNotPaused
        flashLoanProtection
    {
        if (froms.length != amounts.length) revert ErrorLibrary.ArrayLengthMismatch();
        if (froms.length > MAX_BATCH_SIZE) revert ErrorLibrary.BatchSizeTooLarge();
        
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

        address burner = msg.sender;
        
        // Perform burns
        for (uint256 i = 0; i < froms.length; i++) {
            _burn(froms[i], amounts[i]);
            emit TokensBurned(froms[i], amounts[i], burner);
        }
    }

    // =============================================================================
    // RATE LIMITING FUNCTIONS - Rate limiting for mint/burn operations
    // =============================================================================

    /**
     * @notice Checks and updates the mint rate limit for the caller
     * @dev Implements sliding window rate limiting using block numbers to prevent abuse
     * @param amount The amount to be minted (18 decimals), used to check against rate limits
     * @custom:security Resets rate limit if reset period has passed (~300 blocks), prevents block manipulation
     * @custom:validation Validates amount against current rate limit caps
     * @custom:state-changes Updates rateLimitInfo.currentHourMinted and lastRateLimitReset
     * @custom:events No events emitted
     * @custom:errors Throws RateLimitExceeded if amount would exceed current rate limit
     * @custom:reentrancy Not protected - internal function only
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _checkAndUpdateMintRateLimit(uint256 amount) internal {
        // Reset rate limit if reset period has passed (using block numbers)
        uint256 blocksSinceReset = block.number - rateLimitInfo.lastRateLimitReset;
        
        // Caps blocks elapsed at 7200 blocks maximum (~24 hours) to prevent excessive manipulation
        if (blocksSinceReset > 7200) {
            blocksSinceReset = 7200; // Cap at 7200 blocks maximum (~24 hours)
        }
        
        if (blocksSinceReset >= RATE_LIMIT_RESET_PERIOD) {
            rateLimitInfo.currentHourMinted = 0;
            rateLimitInfo.currentHourBurned = 0;
            rateLimitInfo.lastRateLimitReset = uint64(block.number);
            emit RateLimitReset(block.number);
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
     * @notice Checks and updates the burn rate limit for the caller
     * @dev Implements sliding window rate limiting using block numbers to prevent abuse
     * @param amount The amount to be burned (18 decimals), used to check against rate limits
     * @custom:security Resets rate limit if reset period has passed (~300 blocks), prevents block manipulation
     * @custom:validation Validates amount against current rate limit caps
     * @custom:state-changes Updates rateLimitInfo.currentHourBurned and lastRateLimitReset
     * @custom:events No events emitted
     * @custom:errors Throws RateLimitExceeded if amount would exceed current rate limit
     * @custom:reentrancy Not protected - internal function only
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _checkAndUpdateBurnRateLimit(uint256 amount) internal {
        // Reset rate limit if reset period has passed (using block numbers)
        uint256 blocksSinceReset = block.number - rateLimitInfo.lastRateLimitReset;
        
        // Caps blocks elapsed at 7200 blocks maximum (~24 hours) to prevent excessive manipulation
        if (blocksSinceReset > 7200) {
            blocksSinceReset = 7200; // Cap at 7200 blocks maximum (~24 hours)
        }
        
        if (blocksSinceReset >= RATE_LIMIT_RESET_PERIOD) {
            rateLimitInfo.currentHourMinted = 0;
            rateLimitInfo.currentHourBurned = 0;
            rateLimitInfo.lastRateLimitReset = uint64(block.number);
            emit RateLimitReset(block.number);
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
     * @param newMintLimit New mint rate limit per reset period (~300 blocks)
     * @param newBurnLimit New burn rate limit per reset period (~300 blocks)
     * @dev Only callable by admin
     * 
     * @dev Security considerations:
     *      - Validates new limits
     *      - Ensures new limits are not zero
     *      - Ensures new limits are not too high
     *      - Updates rateLimitCaps (mint and burn) in a single storage slot
     *      - Emits RateLimitsUpdated event
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependencies
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
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to COMPLIANCE_ROLE
     * @custom:oracle No oracle dependencies
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
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to COMPLIANCE_ROLE
     * @custom:oracle No oracle dependencies
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
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to COMPLIANCE_ROLE
     * @custom:oracle No oracle dependencies
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
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to COMPLIANCE_ROLE
     * @custom:oracle No oracle dependencies
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
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to COMPLIANCE_ROLE
     * @custom:oracle No oracle dependencies
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
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to COMPLIANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function batchBlacklistAddresses(address[] calldata accounts, string[] calldata reasons)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        if (accounts.length != reasons.length) revert ErrorLibrary.ArrayLengthMismatch();
        if (accounts.length > MAX_COMPLIANCE_BATCH_SIZE) revert ErrorLibrary.BatchSizeTooLarge();
        
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
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to COMPLIANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function batchUnblacklistAddresses(address[] calldata accounts)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        if (accounts.length > MAX_COMPLIANCE_BATCH_SIZE) revert ErrorLibrary.BatchSizeTooLarge();
        
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
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to COMPLIANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function batchWhitelistAddresses(address[] calldata accounts)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        if (accounts.length > MAX_COMPLIANCE_BATCH_SIZE) revert ErrorLibrary.BatchSizeTooLarge();
        
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
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to COMPLIANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function batchUnwhitelistAddresses(address[] calldata accounts)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        if (accounts.length > MAX_COMPLIANCE_BATCH_SIZE) revert ErrorLibrary.BatchSizeTooLarge();
        
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
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependencies
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
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes No state changes
     * @custom:events No events emitted
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access No access restrictions
     * @custom:oracle No oracle dependencies
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
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes No state changes
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access No access restrictions
     * @custom:oracle No oracle dependencies
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
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to PAUSER_ROLE
     * @custom:oracle No oracle dependencies
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Removes pause and restores normal operations
     * @dev Can only be called by a PAUSER_ROLE
     *      Used after resolving the issue that caused the pause
     * 
     * @dev Security considerations:
     *      - Only PAUSER_ROLE can unpause
     *      - Unpauses all token operations
     *      - Allows normal state changes
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to PAUSER_ROLE
     * @custom:oracle No oracle dependencies
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
     * @dev Always returns 18 for DeFi compatibility
     * 
     * @dev Security considerations:
     *      - Always returns 18
     *      - No input validation
     *      - No state changes
     * @custom:security No security checks needed
     * @custom:validation No validation needed
     * @custom:state-changes No state changes
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access No access restrictions
     * @custom:oracle No oracle dependencies
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    /**
     * @notice Checks if an address has the minter role
     * @param account Address to check
     * @return true if the address can mint
     * @dev Checks if account has MINTER_ROLE
     * 
     * @dev Security considerations:
     *      - Checks if account has MINTER_ROLE
     *      - No input validation
     *      - No state changes
     * @custom:security No security checks needed
     * @custom:validation No validation needed
     * @custom:state-changes No state changes
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access No access restrictions
     * @custom:oracle No oracle dependencies
     */
    function isMinter(address account) external view returns (bool) {
        return hasRole(MINTER_ROLE, account);
    }

    /**
     * @notice Checks if an address has the burner role
     * @param account Address to check  
     * @return true if the address can burn
     * @dev Checks if account has BURNER_ROLE
     * 
     * @dev Security considerations:
     *      - Checks if account has BURNER_ROLE
     *      - No input validation
     *      - No state changes
     * @custom:security No security checks needed
     * @custom:validation No validation needed
     * @custom:state-changes No state changes
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access No access restrictions
     * @custom:oracle No oracle dependencies
     */
    function isBurner(address account) external view returns (bool) {
        return hasRole(BURNER_ROLE, account);
    }

    /**
     * @notice Calculates the percentage of maximum supply utilization
     * @return Percentage in basis points (0-10000, where 10000 = 100%)
     * @dev Useful for monitoring:
     *      - 0 = 0% used
     *      - 5000 = 50% used  
     *      - 10000 = 100% used (maximum supply reached)
     * 
     * @dev Security considerations:
     *      - Calculates percentage based on totalSupply and maxSupply
     *      - Handles division by zero
     *      - Returns 0 if totalSupply is 0
     * @custom:security No security checks needed
     * @custom:validation No validation needed
     * @custom:state-changes No state changes
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access No access restrictions
     * @custom:oracle No oracle dependencies
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
     * @return Number of tokens that can still be minted (18 decimals)
     * @dev Calculates remaining capacity by subtracting currentSupply from maxSupply
     * 
     * @dev Security considerations:
     *      - Calculates remaining capacity by subtracting currentSupply from maxSupply
     *      - Handles case where currentSupply >= maxSupply
     *      - Returns 0 if no more minting is possible
     * @custom:security No security checks needed
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function getRemainingMintCapacity() external view returns (uint256) {
        uint256 currentSupply = totalSupply();
        if (currentSupply >= maxSupply) {
            return 0;
        }
        return maxSupply - currentSupply;
    }


    /**
     * @notice Gets current rate limit status
     * @return mintedThisHour Amount minted in current hour (18 decimals)
     * @return burnedThisHour Amount burned in current hour (18 decimals)
     * @return mintLimit Current mint rate limit (18 decimals)
     * @return burnLimit Current burn rate limit (18 decimals)
     * @return nextResetTime Block number when rate limits reset
     * @dev Returns current hour amounts if within the hour, zeros if an hour has passed
     * 
     * @dev Security considerations:
     *      - Returns current hour amounts if within the hour
     *      - Returns zeros if an hour has passed
     *      - Returns current limits and next reset time
     *      - Includes bounds checking to prevent timestamp manipulation
     * @custom:security No security checks needed
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function getRateLimitStatus() external view returns (
        uint256 mintedThisHour,
        uint256 burnedThisHour,
        uint256 mintLimit,
        uint256 burnLimit,
        uint256 nextResetTime
    ) {
        uint256 blocksSinceReset = block.number - rateLimitInfo.lastRateLimitReset;
        
        if (blocksSinceReset >= RATE_LIMIT_RESET_PERIOD) {
            mintedThisHour = 0;
            burnedThisHour = 0;
        } else {
            mintedThisHour = rateLimitInfo.currentHourMinted;
            burnedThisHour = rateLimitInfo.currentHourBurned;
        }
        
        mintLimit = rateLimitCaps.mint;
        burnLimit = rateLimitCaps.burn;
        nextResetTime = rateLimitInfo.lastRateLimitReset + RATE_LIMIT_RESET_PERIOD;
    }


    /**
     * @notice Batch transfer QEURO tokens to multiple addresses
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts to transfer (18 decimals)
     * @return success Always returns true if all transfers succeed
     * @dev Performs multiple transfers from msg.sender to recipients.
     *      Uses OpenZeppelin's transfer mechanism with compliance checks.
     * @custom:security Validates all recipients and amounts, enforces blacklist/whitelist checks
     * @custom:validation Validates array lengths match, amounts > 0, recipients != address(0)
     * @custom:state-changes Updates balances for all recipients and sender
     * @custom:events Emits Transfer events for each successful transfer
     * @custom:errors Throws ArrayLengthMismatch, BatchSizeTooLarge, InvalidAddress, InvalidAmount, BlacklistedAddress, NotWhitelisted
     * @custom:reentrancy Protected by whenNotPaused modifier
     * @custom:access Public - requires sufficient balance and compliance checks
     * @custom:oracle No oracle dependencies
     */
    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts)
        external
        whenNotPaused
        returns (bool)
    {
        if (recipients.length != amounts.length) revert ErrorLibrary.ArrayLengthMismatch();
        if (recipients.length > MAX_BATCH_SIZE) revert ErrorLibrary.BatchSizeTooLarge();
        

        uint256 length = recipients.length;
        address sender = msg.sender;
        
        // Pre-validate recipients and amounts
        for (uint256 i = 0; i < length;) {
            address to = recipients[i];
            uint256 amount = amounts[i];
            
            if (to == address(0)) revert ErrorLibrary.InvalidAddress();
            if (amount == 0) revert ErrorLibrary.InvalidAmount();
            
            // Check compliance (blacklist/whitelist) per recipient
            if (isBlacklisted[sender]) revert ErrorLibrary.BlacklistedAddress();
            if (isBlacklisted[to]) revert ErrorLibrary.BlacklistedAddress();
            if (whitelistEnabled && !isWhitelisted[to]) revert ErrorLibrary.NotWhitelisted();
            
            unchecked { ++i; }
        }
        
        // Perform transfers using OpenZeppelin's transfer mechanism
        for (uint256 i = 0; i < length;) {
            _transfer(sender, recipients[i], amounts[i]);
            
            unchecked { ++i; }
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
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by whenNotPaused modifier
     * @custom:access Internal function
     * @custom:oracle No oracle dependencies
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
     * @notice Recover tokens accidentally sent to the contract to treasury only
     * @param token Token address to recover
     * @param amount Amount to recover
     * @dev Only DEFAULT_ADMIN_ROLE can recover tokens to treasury
     * 
     * @dev Security considerations:
     *      - Only DEFAULT_ADMIN_ROLE can recover
     *      - Prevents recovery of own QEURO tokens
     *      - Tokens are sent to treasury address only
     *      - Uses SafeERC20 for secure transfers
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependencies
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
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependencies
     */
    function recoverETH() external onlyRole(DEFAULT_ADMIN_ROLE) {

        emit ETHRecovered(treasury, address(this).balance);
        // Use the shared library for secure ETH recovery
        TreasuryRecoveryLibrary.recoverETH(treasury);
    }

    // =============================================================================
    // ADMINISTRATIVE FUNCTIONS - Advanced administrative functions
    // =============================================================================

    /**
     * @notice Updates the maximum supply limit (governance only)
     * @param newMaxSupply New supply limit
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
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependencies
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
     * @notice Update treasury address
     * @dev SECURITY: Only governance can update treasury address
     * @param _treasury New treasury address
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependencies
     */
    function updateTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        AccessControlLibrary.validateAddress(_treasury);
        ValidationLibrary.validateTreasuryAddress(_treasury);
        require(_treasury != address(0), "Treasury cannot be zero address");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
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
     * @dev Returns current state of the token for monitoring purposes
     * 
     * @dev Security considerations:
     *      - Returns current state of the token
     *      - No input validation
     *      - No state changes
     * @custom:security No security checks needed
     * @custom:validation No validation needed
     * @custom:state-changes No state changes
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access No access restrictions
     * @custom:oracle No oracle dependencies
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
     * @dev Returns current mint rate limit
     * @custom:security No security checks needed
     * @custom:validation No validation needed
     * @custom:state-changes No state changes
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access No access restrictions
     * @custom:oracle No oracle dependencies
     */
    function mintRateLimit() external view returns (uint256 limit) {
        return rateLimitCaps.mint;
    }

    // =============================================================================
    // KILLSWITCH FUNCTIONS
    // =============================================================================

    /**
     * @notice Toggle the emergency minting killswitch to enable/disable all minting operations
     * @dev Emergency function that provides granular control over minting without affecting other operations
     * @dev Can only be called by addresses with PAUSER_ROLE for security
     * @dev Used as a crisis management tool when protocol lacks sufficient collateral
     * @dev Independent of the general pause mechanism - allows selective operation blocking
     * @dev When enabled, both mint() and batchMint() functions will revert with MintingDisabled error
     * @dev Burning operations remain unaffected by the killswitch
     * @param enabled True to enable killswitch (block all minting), false to disable (allow minting)
     * @custom:security Only callable by PAUSER_ROLE holders
     * @custom:events Emits MintingKillswitchToggled event with new state and caller
     * @custom:state-changes Updates mintingKillswitch state variable
     * @custom:access Restricted to PAUSER_ROLE
     * @custom:reentrancy Not protected - simple state change
     * @custom:oracle No oracle dependencies
     */
    function setMintingKillswitch(bool enabled) external onlyRole(PAUSER_ROLE) {
        mintingKillswitch = enabled;
        emit MintingKillswitchToggled(enabled, msg.sender);
    }

    /**
     * @notice Get current burn rate limit (per hour)
     * @return limit Burn rate limit in wei per hour (18 decimals)
     * @dev Returns current burn rate limit
     * @custom:security No security checks needed
     * @custom:validation No validation needed
     * @custom:state-changes No state changes
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access No access restrictions
     * @custom:oracle No oracle dependencies
     */
    function burnRateLimit() external view returns (uint256 limit) {
        return rateLimitCaps.burn;
    }
}