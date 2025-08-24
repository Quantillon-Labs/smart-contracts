// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IQEURO
 * @notice Minimal interface for the QEURO token used by the vault
 * @dev Exposes only the functions the vault needs (mint/burn) and basic views
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
interface IQEURO {
    /**
     * @notice Mints QEURO to an address
     * @param to Recipient address
     * @param amount Amount to mint (18 decimals)
     */
    function mint(address to, uint256 amount) external;

    /**
     * @notice Burns QEURO from an address
     * @param from Address to burn from
     * @param amount Amount to burn (18 decimals)
     */
    function burn(address from, uint256 amount) external;

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
     * @notice Token decimals (should be 18)
     */
    function decimals() external view returns (uint8);

    /**
     * @notice Transfer tokens to another address
     * @param to Recipient address
     * @param amount Amount to transfer
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @notice Transfer tokens from one address to another (requires allowance)
     * @param from Source address
     * @param to Recipient address
     * @param amount Amount to transfer
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
} 