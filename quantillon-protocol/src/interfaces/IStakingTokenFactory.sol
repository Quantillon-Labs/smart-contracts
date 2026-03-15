// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IStakingTokenFactory
 * @notice Interface for the StakingTokenFactory contract
 *
 * @dev The factory creates and tracks one stQEURO ERC1967Proxy per staking vault.
 *      Each proxy is independently upgradeable via its own UUPS mechanism.
 *      The factory itself is also UUPS upgradeable.
 *
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
interface IStakingTokenFactory {
    // =============================================================================
    // EVENTS
    // =============================================================================

    /// @notice Emitted when a new staking token proxy is created
    /// @param vaultId Numeric vault identifier
    /// @param stakingToken Address of the newly deployed stQEURO proxy
    /// @param vault Address of the associated staking vault
    /// @param name ERC20 token name
    /// @param symbol ERC20 token symbol
    event StakingTokenCreated(
        uint256 indexed vaultId,
        address indexed stakingToken,
        address indexed vault,
        string name,
        string symbol
    );

    /// @notice Emitted when the staking token implementation address is updated
    /// @param oldImpl Previous implementation address
    /// @param newImpl New implementation address
    event ImplementationUpdated(address indexed oldImpl, address indexed newImpl);

    // =============================================================================
    // INITIALIZER
    // =============================================================================

    /**
     * @notice Initialize the StakingTokenFactory
     * @param admin Address receiving admin and operator roles
     * @param _stakingTokenImplementation Address of the deployed stQEUROToken logic contract
     * @param _timelock Address of the timelock contract for secure upgrades
     * @custom:access Public initializer — callable once
     */
    function initialize(
        address admin,
        address _stakingTokenImplementation,
        address _timelock
    ) external;

    // =============================================================================
    // FACTORY FUNCTIONS
    // =============================================================================

    /**
     * @notice Create a new stQEURO staking token for a staking vault
     * @param _vaultId Numeric identifier for the vault (must be unique)
     * @param _vault Address of the staking vault (must not already be registered)
     * @param name ERC20 token name (e.g., "Staked QEURO Vault 1")
     * @param symbol ERC20 token symbol (e.g., "stQEURO1")
     * @param admin Admin address for the new staking token
     * @param qeuro QEURO token address
     * @param yieldShift YieldShift contract address
     * @param usdc USDC token address
     * @param treasury Treasury address for fee collection
     * @param timelockAddr Timelock address for the new token's secure upgrades
     * @return proxy Address of the newly deployed stQEURO proxy
     * @custom:access Restricted to FACTORY_ROLE
     */
    function createStakingToken(
        uint256 _vaultId,
        address _vault,
        string calldata name,
        string calldata symbol,
        address admin,
        address qeuro,
        address yieldShift,
        address usdc,
        address treasury,
        address timelockAddr
    ) external returns (address proxy);

    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================

    /**
     * @notice Get the stQEURO proxy address for a given vault ID
     * @param _vaultId Numeric vault identifier
     * @return stakingToken Address of the stQEURO proxy
     * @custom:errors Throws StakingTokenNotFound if vaultId is not registered
     */
    function getStakingToken(uint256 _vaultId) external view returns (address stakingToken);

    /**
     * @notice Get the stQEURO proxy address for a given vault address
     * @param _vault Address of the staking vault
     * @return Address of the stQEURO proxy, or address(0) if not found
     */
    function getStakingTokenByVault(address _vault) external view returns (address);

    /**
     * @notice Returns whether a vault address is already registered in this factory
     * @param _vault Address to check
     * @return True if registered, false otherwise
     */
    function isVaultRegistered(address _vault) external view returns (bool);

    /**
     * @notice Returns the vault ID registered for a given vault address
     * @param _vault Address of the staking vault
     * @return The vault ID, or 0 if not registered
     */
    function getVaultId(address _vault) external view returns (uint256);

    /**
     * @notice Returns all registered vault IDs in creation order
     * @return Array of vault IDs
     */
    function getAllVaultIds() external view returns (uint256[] memory);

    /**
     * @notice Returns all registered stQEURO proxy addresses in creation order
     * @return tokens Array of stQEURO proxy addresses
     */
    function getAllStakingTokens() external view returns (address[] memory tokens);

    /**
     * @notice Returns the stQEURO implementation address used for new deployments
     * @return Address of the stQEUROToken logic contract
     */
    function stakingTokenImplementation() external view returns (address);

    /**
     * @notice Returns the total number of staking tokens created
     * @return Count of created staking tokens
     */
    function tokenCount() external view returns (uint256);

    /**
     * @notice Maps vaultId to stQEURO proxy address
     * @param vaultId Numeric vault identifier
     * @return stQEURO proxy address, or address(0) if not registered
     */
    function stakingTokens(uint256 vaultId) external view returns (address);

    // =============================================================================
    // GOVERNANCE FUNCTIONS
    // =============================================================================

    /**
     * @notice Update the stQEURO implementation address used for future token deployments
     * @param newImpl Address of the new stQEUROToken logic contract
     * @custom:access Restricted to GOVERNANCE_ROLE
     */
    function updateImplementation(address newImpl) external;

    // =============================================================================
    // EMERGENCY FUNCTIONS
    // =============================================================================

    /**
     * @notice Pause the factory — prevents new staking token creation
     * @custom:access Restricted to EMERGENCY_ROLE
     */
    function pause() external;

    /**
     * @notice Unpause the factory — re-enables staking token creation
     * @custom:access Restricted to EMERGENCY_ROLE
     */
    function unpause() external;
}
