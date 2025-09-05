// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IQEUROToken
 * @notice Read-only interface for the QEURO token
 * @dev Exposes ERC20 metadata and helper views used by integrators
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
interface IQEUROToken {
    /**
     * @notice Token name
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function name() external view returns (string memory);

    /**
     * @notice Token symbol
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function symbol() external view returns (string memory);

    /**
     * @notice Token decimals (always 18)
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function decimals() external view returns (uint8);

    /**
     * @notice Total token supply
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice Balance of an account
     * @param account Address to query
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @notice Whether an address has the minter role
     * @param account Address to check
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function isMinter(address account) external view returns (bool);

    /**
     * @notice Whether an address has the burner role
     * @param account Address to check
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function isBurner(address account) external view returns (bool);

    /**
     * @notice Percentage of max supply utilized (basis points)
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getSupplyUtilization() external view returns (uint256);



    /**
     * @notice Aggregated token information snapshot
     * @return name_ Token name
     * @return symbol_ Token symbol
     * @return decimals_ Token decimals
     * @return totalSupply_ Current total supply
     * @return maxSupply_ Maximum supply cap
     * @return isPaused_ Whether the token is paused
     * @return whitelistEnabled_ Whether whitelist mode is active
     * @return mintRateLimit_ Current mint rate limit per hour
     * @return burnRateLimit_ Current burn rate limit per hour
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getTokenInfo() external view returns (
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        uint256 maxSupply_,
        bool isPaused_,
        bool whitelistEnabled_,
        uint256 mintRateLimit_,
        uint256 burnRateLimit_
    );

    // Initialization
    /**
     * @notice Initialize the QEURO token contract
     * @dev Sets up initial roles and configuration for the token
     * @param admin Address of the admin role
     * @param vault Address of the vault contract
     * @param timelock Address of the timelock contract
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function initialize(address admin, address vault, address timelock) external;

    // Core functions
    /**
     * @notice Mint new QEURO tokens to an address
     * @dev Creates new tokens and adds them to the specified address
     * @param to Address to receive the minted tokens
     * @param amount Amount of tokens to mint (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function mint(address to, uint256 amount) external;
    
    /**
     * @notice Burn QEURO tokens from an address
     * @dev Destroys tokens from the specified address
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function burn(address from, uint256 amount) external;
    
    /**
     * @notice Mint new QEURO tokens to multiple addresses
     * @dev Creates new tokens and distributes them to multiple recipients
     * @param recipients Array of addresses to receive the minted tokens
     * @param amounts Array of amounts to mint for each recipient (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function batchMint(address[] calldata recipients, uint256[] calldata amounts) external;
    
    /**
     * @notice Burn QEURO tokens from multiple addresses
     * @dev Destroys tokens from multiple addresses
     * @param froms Array of addresses to burn tokens from
     * @param amounts Array of amounts to burn from each address (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function batchBurn(address[] calldata froms, uint256[] calldata amounts) external;
    
    /**
     * @notice Transfer QEURO tokens to multiple addresses
     * @dev Transfers tokens from the caller to multiple recipients
     * @param recipients Array of addresses to receive the tokens
     * @param amounts Array of amounts to transfer to each recipient (18 decimals)
     * @return success True if all transfers were successful
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) external returns (bool);

    // Rate limiting
    function updateRateLimits(uint256 newMintLimit, uint256 newBurnLimit) external;

    // Compliance functions
    function blacklistAddress(address account, string memory reason) external;
    function unblacklistAddress(address account) external;
    function whitelistAddress(address account) external;
    function unwhitelistAddress(address account) external;
    function toggleWhitelistMode(bool enabled) external;
    function batchBlacklistAddresses(address[] calldata accounts, string[] calldata reasons) external;
    function batchUnblacklistAddresses(address[] calldata accounts) external;
    function batchWhitelistAddresses(address[] calldata accounts) external;
    function batchUnwhitelistAddresses(address[] calldata accounts) external;

    // Decimal precision functions
    function updateMinPricePrecision(uint256 newPrecision) external;
    function normalizePrice(uint256 price, uint8 feedDecimals) external pure returns (uint256);
    function validatePricePrecision(uint256 price, uint8 feedDecimals) external view returns (bool);

    // Emergency functions
    function pause() external;
    function unpause() external;

    // Recovery functions
    function recoverToken(address token, address to, uint256 amount) external;
    function recoverETH() external;

    // Administrative functions
    function updateMaxSupply(uint256 newMaxSupply) external;

    // ERC20 functions
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    // AccessControl functions
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address callerConfirmation) external;

    // Pausable functions
    function paused() external view returns (bool);

    // UUPS functions
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;

    // Constants
    function MINTER_ROLE() external view returns (bytes32);
    function BURNER_ROLE() external view returns (bytes32);
    function PAUSER_ROLE() external view returns (bytes32);
    function UPGRADER_ROLE() external view returns (bytes32);
    function COMPLIANCE_ROLE() external view returns (bytes32);
    function DEFAULT_MAX_SUPPLY() external view returns (uint256);
    function MAX_RATE_LIMIT() external view returns (uint256);
    function PRECISION() external view returns (uint256);

    // State variables
    function maxSupply() external view returns (uint256);
    function mintRateLimit() external view returns (uint256);
    function burnRateLimit() external view returns (uint256);
    function currentHourMinted() external view returns (uint256);
    function currentHourBurned() external view returns (uint256);
    function lastRateLimitReset() external view returns (uint256);
    function isBlacklisted(address) external view returns (bool);
    function isWhitelisted(address) external view returns (bool);
    function whitelistEnabled() external view returns (bool);
    function minPricePrecision() external view returns (uint256);
} 