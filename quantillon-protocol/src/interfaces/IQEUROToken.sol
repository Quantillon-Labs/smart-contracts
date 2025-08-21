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
     */
    function name() external view returns (string memory);

    /**
     * @notice Token symbol
     */
    function symbol() external view returns (string memory);

    /**
     * @notice Token decimals (always 18)
     */
    function decimals() external view returns (uint8);

    /**
     * @notice Total token supply
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice Balance of an account
     * @param account Address to query
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @notice Whether an address has the minter role
     * @param account Address to check
     */
    function isMinter(address account) external view returns (bool);

    /**
     * @notice Whether an address has the burner role
     * @param account Address to check
     */
    function isBurner(address account) external view returns (bool);

    /**
     * @notice Percentage of max supply utilized (basis points)
     */
    function getSupplyUtilization() external view returns (uint256);

    /**
     * @notice Remaining mint capacity before reaching max supply
     */
    function getRemainingMintCapacity() external view returns (uint256);

    /**
     * @notice Current rate limit status
     * @return mintedThisHour Amount minted in the current hour
     * @return burnedThisHour Amount burned in the current hour
     * @return mintLimit Mint rate limit per hour
     * @return burnLimit Burn rate limit per hour
     * @return nextResetTime Timestamp when limits reset
     */
    function getRateLimitStatus() external view returns (
        uint256 mintedThisHour,
        uint256 burnedThisHour,
        uint256 mintLimit,
        uint256 burnLimit,
        uint256 nextResetTime
    );

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
} 