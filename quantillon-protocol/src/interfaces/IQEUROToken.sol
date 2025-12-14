// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IQEUROToken
 * @notice Read-only interface for the QEURO token
 * @dev Exposes ERC20 metadata and helper views used by integrators
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
interface IQEUROToken {
    /**
     * @notice Token name
     * @dev Returns the name of the QEURO token
     * @return name The token name string
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
     * @dev Returns the symbol of the QEURO token
     * @return symbol The token symbol string
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
     * @dev Returns the number of decimals used by the token
     * @return decimals The number of decimals (always 18)
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
     * @dev Returns the total supply of QEURO tokens
     * @return totalSupply The total supply (18 decimals)
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
     * @dev Returns the token balance of the specified account
     * @param account Address to query
     * @return balance The token balance (18 decimals)
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
     * @dev Checks if the specified account has the MINTER_ROLE
     * @param account Address to check
     * @return isMinter True if the account has the minter role
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
     * @dev Checks if the specified account has the BURNER_ROLE
     * @param account Address to check
     * @return isBurner True if the account has the burner role
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
     * @dev Returns the percentage of maximum supply currently in circulation
     * @return utilization Percentage of max supply utilized (basis points)
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
     * @dev Returns comprehensive token information in a single call
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
     * @param treasury Treasury address
     * @param feeCollector Address of the fee collector contract
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function initialize(address admin, address vault, address timelock, address treasury, address feeCollector) external;

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
    /**
     * @notice Update rate limits for minting and burning operations
     * @dev Modifies the maximum amount of tokens that can be minted or burned per hour
     * @param newMintLimit New maximum amount of tokens that can be minted per hour (18 decimals)
     * @param newBurnLimit New maximum amount of tokens that can be burned per hour (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function updateRateLimits(uint256 newMintLimit, uint256 newBurnLimit) external;

    // Compliance functions
    /**
     * @notice Add an address to the blacklist with a reason
     * @dev Prevents the specified address from participating in token operations
     * @param account Address to blacklist
     * @param reason Reason for blacklisting the address
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function blacklistAddress(address account, string memory reason) external;

    /**
     * @notice Remove an address from the blacklist
     * @dev Allows the specified address to participate in token operations again
     * @param account Address to remove from blacklist
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function unblacklistAddress(address account) external;

    /**
     * @notice Add an address to the whitelist
     * @dev Allows the specified address to participate in token operations when whitelist mode is enabled
     * @param account Address to whitelist
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function whitelistAddress(address account) external;

    /**
     * @notice Remove an address from the whitelist
     * @dev Prevents the specified address from participating in token operations when whitelist mode is enabled
     * @param account Address to remove from whitelist
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function unwhitelistAddress(address account) external;

    /**
     * @notice Toggle whitelist mode on or off
     * @dev When enabled, only whitelisted addresses can participate in token operations
     * @param enabled True to enable whitelist mode, false to disable
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function toggleWhitelistMode(bool enabled) external;

    /**
     * @notice Add multiple addresses to the blacklist with reasons
     * @dev Batch operation to blacklist multiple addresses efficiently
     * @param accounts Array of addresses to blacklist
     * @param reasons Array of reasons for blacklisting each address
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function batchBlacklistAddresses(address[] calldata accounts, string[] calldata reasons) external;

    /**
     * @notice Remove multiple addresses from the blacklist
     * @dev Batch operation to unblacklist multiple addresses efficiently
     * @param accounts Array of addresses to remove from blacklist
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function batchUnblacklistAddresses(address[] calldata accounts) external;

    /**
     * @notice Add multiple addresses to the whitelist
     * @dev Batch operation to whitelist multiple addresses efficiently
     * @param accounts Array of addresses to whitelist
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function batchWhitelistAddresses(address[] calldata accounts) external;

    /**
     * @notice Remove multiple addresses from the whitelist
     * @dev Batch operation to unwhitelist multiple addresses efficiently
     * @param accounts Array of addresses to remove from whitelist
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function batchUnwhitelistAddresses(address[] calldata accounts) external;

    // Decimal precision functions
    /**
     * @notice Update the minimum price precision for oracle feeds
     * @dev Sets the minimum number of decimal places required for price feeds
     * @param newPrecision New minimum precision value (number of decimal places)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function updateMinPricePrecision(uint256 newPrecision) external;

    /**
     * @notice Normalize price from different decimal precisions to 18 decimals
     * @dev Converts price from source feed decimals to standard 18 decimal format
     * @param price Price value to normalize
     * @param feedDecimals Number of decimal places in the source feed
     * @return normalizedPrice Price normalized to 18 decimals
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function normalizePrice(uint256 price, uint8 feedDecimals) external pure returns (uint256);

    /**
     * @notice Validate if price precision meets minimum requirements
     * @dev Checks if the price feed has sufficient decimal precision
     * @param price Price value to validate
     * @param feedDecimals Number of decimal places in the price feed
     * @return isValid True if precision meets minimum requirements
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function validatePricePrecision(uint256 price, uint8 feedDecimals) external view returns (bool);

    // Emergency functions
    /**
     * @notice Pause all token operations
     * @dev Emergency function to halt all token transfers, minting, and burning
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function pause() external;

    /**
     * @notice Unpause all token operations
     * @dev Resumes normal token operations after emergency pause
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function unpause() external;

    // Recovery functions
    /**
     * @notice Recover accidentally sent tokens
     * @dev Allows recovery of ERC20 tokens sent to the contract by mistake
     * @param token Address of the token to recover
     * @param amount Amount of tokens to recover
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function recoverToken(address token, uint256 amount) external;

    /**
     * @notice Recover accidentally sent ETH
     * @dev Allows recovery of ETH sent to the contract by mistake
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function recoverETH() external;

    // Administrative functions
    /**
     * @notice Update the maximum supply of QEURO tokens
     * @dev Sets a new maximum supply limit for the token
     * @param newMaxSupply New maximum supply limit (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function updateMaxSupply(uint256 newMaxSupply) external;

    // ERC20 functions
    /**
     * @notice Transfer QEURO tokens to another address
     * @dev Standard ERC20 transfer function with compliance checks
     * @param to Address to transfer tokens to
     * @param amount Amount of tokens to transfer (18 decimals)
     * @return success True if transfer was successful
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @notice Get the allowance for a spender
     * @dev Returns the amount of tokens that a spender is allowed to transfer
     * @param owner Address of the token owner
     * @param spender Address of the spender
     * @return allowance Amount of tokens the spender can transfer (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @notice Approve a spender to transfer tokens
     * @dev Sets the allowance for a spender to transfer tokens on behalf of the caller
     * @param spender Address of the spender to approve
     * @param amount Amount of tokens to approve (18 decimals)
     * @return success True if approval was successful
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @notice Transfer tokens from one address to another
     * @dev Standard ERC20 transferFrom function with compliance checks
     * @param from Address to transfer tokens from
     * @param to Address to transfer tokens to
     * @param amount Amount of tokens to transfer (18 decimals)
     * @return success True if transfer was successful
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    // AccessControl functions
    /**
     * @notice Check if an address has a specific role
     * @dev Returns true if the account has the specified role
     * @param role Role to check for
     * @param account Address to check
     * @return hasRole True if the account has the role
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @notice Get the admin role for a specific role
     * @dev Returns the role that is the admin of the given role
     * @param role Role to get admin for
     * @return adminRole The admin role
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @notice Grant a role to an address
     * @dev Assigns the specified role to the given account
     * @param role Role to grant
     * @param account Address to grant the role to
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @notice Revoke a role from an address
     * @dev Removes the specified role from the given account
     * @param role Role to revoke
     * @param account Address to revoke the role from
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @notice Renounce a role
     * @dev Removes the specified role from the caller
     * @param role Role to renounce
     * @param callerConfirmation Address of the caller (for security)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function renounceRole(bytes32 role, address callerConfirmation) external;

    // Pausable functions
    /**
     * @notice Check if the contract is paused
     * @dev Returns true if all token operations are paused
     * @return isPaused True if the contract is paused
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function paused() external view returns (bool);

    // UUPS functions
    /**
     * @notice Upgrade the contract implementation
     * @dev Upgrades to a new implementation address
     * @param newImplementation Address of the new implementation
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function upgradeTo(address newImplementation) external;

    /**
     * @notice Upgrade the contract implementation and call a function
     * @dev Upgrades to a new implementation and executes a function call
     * @param newImplementation Address of the new implementation
     * @param data Encoded function call data
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;

    // Constants
    /**
     * @notice Get the MINTER_ROLE constant
     * @dev Returns the role hash for minters
     * @return role The MINTER_ROLE bytes32 value
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function MINTER_ROLE() external view returns (bytes32);

    /**
     * @notice Get the BURNER_ROLE constant
     * @dev Returns the role hash for burners
     * @return role The BURNER_ROLE bytes32 value
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function BURNER_ROLE() external view returns (bytes32);

    /**
     * @notice Get the PAUSER_ROLE constant
     * @dev Returns the role hash for pausers
     * @return role The PAUSER_ROLE bytes32 value
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function PAUSER_ROLE() external view returns (bytes32);

    /**
     * @notice Get the UPGRADER_ROLE constant
     * @dev Returns the role hash for upgraders
     * @return role The UPGRADER_ROLE bytes32 value
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function UPGRADER_ROLE() external view returns (bytes32);

    /**
     * @notice Get the COMPLIANCE_ROLE constant
     * @dev Returns the role hash for compliance officers
     * @return role The COMPLIANCE_ROLE bytes32 value
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function COMPLIANCE_ROLE() external view returns (bytes32);

    /**
     * @notice Get the DEFAULT_MAX_SUPPLY constant
     * @dev Returns the default maximum supply limit
     * @return maxSupply The default maximum supply (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function DEFAULT_MAX_SUPPLY() external view returns (uint256);

    /**
     * @notice Get the MAX_RATE_LIMIT constant
     * @dev Returns the maximum rate limit value
     * @return maxLimit The maximum rate limit (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function MAX_RATE_LIMIT() external view returns (uint256);

    /**
     * @notice Get the PRECISION constant
     * @dev Returns the precision value used for calculations
     * @return precision The precision value (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function PRECISION() external view returns (uint256);

    // State variables
    /**
     * @notice Get the current maximum supply limit
     * @dev Returns the maximum number of tokens that can be minted
     * @return maxSupply Current maximum supply limit (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function maxSupply() external view returns (uint256);

    /**
     * @notice Get the current mint rate limit
     * @dev Returns the maximum amount of tokens that can be minted per hour
     * @return mintLimit Current mint rate limit (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function mintRateLimit() external view returns (uint256);

    /**
     * @notice Get the current burn rate limit
     * @dev Returns the maximum amount of tokens that can be burned per hour
     * @return burnLimit Current burn rate limit (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function burnRateLimit() external view returns (uint256);

    /**
     * @notice Get the amount minted in the current hour
     * @dev Returns the total amount of tokens minted in the current rate limit window
     * @return minted Current hour minted amount (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function currentHourMinted() external view returns (uint256);

    /**
     * @notice Get the amount burned in the current hour
     * @dev Returns the total amount of tokens burned in the current rate limit window
     * @return burned Current hour burned amount (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function currentHourBurned() external view returns (uint256);

    /**
     * @notice Get the timestamp of the last rate limit reset
     * @dev Returns when the rate limit counters were last reset
     * @return resetTime Timestamp of last rate limit reset
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function lastRateLimitReset() external view returns (uint256);

    /**
     * @notice Check if an address is blacklisted
     * @dev Returns true if the address is on the blacklist
     * @param account Address to check
     * @return isBlacklisted True if the address is blacklisted
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function isBlacklisted(address account) external view returns (bool);

    /**
     * @notice Check if an address is whitelisted
     * @dev Returns true if the address is on the whitelist
     * @param account Address to check
     * @return isWhitelisted True if the address is whitelisted
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function isWhitelisted(address account) external view returns (bool);

    /**
     * @notice Check if whitelist mode is enabled
     * @dev Returns true if whitelist mode is active
     * @return enabled True if whitelist mode is enabled
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function whitelistEnabled() external view returns (bool);

    /**
     * @notice Get the minimum price precision requirement
     * @dev Returns the minimum number of decimal places required for price feeds
     * @return precision Minimum price precision value
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function minPricePrecision() external view returns (uint256);
} 