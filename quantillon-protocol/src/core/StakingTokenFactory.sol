// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// =============================================================================
// IMPORTS
// =============================================================================

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {stQEUROToken} from "./stQEUROToken.sol";
import {SecureUpgradeable} from "./SecureUpgradeable.sol";
import {TimeProvider} from "../libraries/TimeProviderLibrary.sol";
import {CommonErrorLibrary} from "../libraries/CommonErrorLibrary.sol";
import {CommonValidationLibrary} from "../libraries/CommonValidationLibrary.sol";
import {StakingTokenFactoryErrorLibrary} from "../libraries/StakingTokenFactoryErrorLibrary.sol";

// =============================================================================
// CONTRACT
// =============================================================================

/**
 * @title StakingTokenFactory
 * @notice Factory contract for creating and managing per-vault stQEURO staking tokens
 *
 * @dev Main characteristics:
 *      - Creates one stQEURO ERC1967Proxy per staking vault
 *      - All proxies share the same stQEUROToken implementation but are independent
 *      - Maintains a registry: vaultId → proxy address and vault address → vaultId
 *      - Each created token is independently upgradeable via its own UUPS mechanism
 *      - The factory itself is upgradeable via UUPS pattern (SecureUpgradeable)
 *
 * @dev Naming convention:
 *      - Vault 1 → name: "Staked QEURO Vault 1", symbol: "stQEURO1"
 *      - Vault N → name: "Staked QEURO Vault N", symbol: "stQEURON"
 *      - Callers supply arbitrary name/symbol; no automatic numbering is enforced
 *
 * @dev Access control:
 *      - FACTORY_ROLE: create new staking tokens
 *      - GOVERNANCE_ROLE: update the implementation address used for future deployments
 *      - DEFAULT_ADMIN_ROLE: role management and factory upgrade authorization
 *
 * @dev Upgrade notes:
 *      - updateImplementation() only affects future createStakingToken() calls
 *      - Existing token proxies are NOT automatically migrated; upgrade each proxy individually
 *
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract StakingTokenFactory is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    SecureUpgradeable
{
    // =============================================================================
    // CONSTANTS AND ROLES
    // =============================================================================

    /// @notice Role for creating new staking tokens
    /// @dev Assign to governance multisig or automated deployment system
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    /// @notice Role for governance operations (implementation updates)
    /// @dev Assign to governance multisig or DAO
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    /// @notice Role for emergency operations (pause/unpause)
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    // =============================================================================
    // IMMUTABLES
    // =============================================================================

    /// @notice TimeProvider contract for centralized time management
    /// @dev Shared with all stQEURO token instances created by this factory
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    TimeProvider public immutable TIME_PROVIDER;

    // =============================================================================
    // STATE VARIABLES
    // =============================================================================

    /// @notice Address of the stQEUROToken logic contract used for new deployments
    /// @dev Changing this does NOT affect existing proxies; each proxy retains its own impl
    address public stakingTokenImplementation;

    /// @notice Maps vaultId → stQEURO proxy address
    /// @dev Returns address(0) for unregistered vault IDs
    mapping(uint256 => address) public stakingTokens;

    /// @notice Maps vault address → vaultId for reverse lookups
    /// @dev Use _registeredVaults to disambiguate vaultId 0 from "not found"
    mapping(address => uint256) private _vaultToId;

    /// @notice Tracks whether a vault address is already registered
    /// @dev Required because _vaultToId cannot distinguish vaultId==0 from unregistered
    mapping(address => bool) private _registeredVaults;

    /// @notice Ordered list of registered vault IDs for enumeration
    uint256[] private _vaultIds;

    /// @notice Total number of staking tokens created by this factory
    uint256 public tokenCount;

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
    // CONSTRUCTOR
    // =============================================================================

    /**
     * @notice Constructor for StakingTokenFactory implementation
     * @dev Sets the immutable TIME_PROVIDER and disables initialization on the implementation
     * @param _TIME_PROVIDER Address of the time provider contract
     * @custom:security Disables initialization on implementation for security
     * @custom:validation Validates TIME_PROVIDER is not zero address
     * @custom:state-changes Sets TIME_PROVIDER and disables initializers
     * @custom:events No events emitted
     * @custom:errors Throws ZeroAddress if TIME_PROVIDER is zero
     * @custom:reentrancy Not protected - constructor only
     * @custom:access Public constructor
     * @custom:oracle No oracle dependencies
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(TimeProvider _TIME_PROVIDER) {
        if (address(_TIME_PROVIDER) == address(0)) revert CommonErrorLibrary.ZeroAddress();
        TIME_PROVIDER = _TIME_PROVIDER;
        _disableInitializers();
    }

    // =============================================================================
    // INITIALIZER
    // =============================================================================

    /**
     * @notice Initialize the StakingTokenFactory
     * @dev Sets up roles, timelock, and the initial stQEURO implementation address
     * @param admin Address receiving DEFAULT_ADMIN_ROLE, FACTORY_ROLE, GOVERNANCE_ROLE, EMERGENCY_ROLE
     * @param _stakingTokenImplementation Address of the deployed stQEUROToken logic contract
     * @param _timelock Address of the timelock contract for secure upgrades
     * @custom:security Validates all addresses are not zero
     * @custom:validation Validates admin, implementation, and timelock addresses
     * @custom:state-changes Initializes AccessControl, Pausable, ReentrancyGuard, SecureUpgradeable
     * @custom:events No custom events - standard OZ init events
     * @custom:errors Throws InvalidAdmin on zero admin; InvalidImplementation on zero impl
     * @custom:reentrancy Protected by initializer modifier
     * @custom:access Public initializer — callable once
     * @custom:oracle No oracle dependencies
     */
    function initialize(
        address admin,
        address _stakingTokenImplementation,
        address _timelock
    ) public initializer {
        CommonValidationLibrary.validateNonZeroAddress(admin, "admin");
        if (_stakingTokenImplementation == address(0)) {
            revert StakingTokenFactoryErrorLibrary.InvalidImplementation();
        }

        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __SecureUpgradeable_init(_timelock);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(FACTORY_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);

        stakingTokenImplementation = _stakingTokenImplementation;
    }

    // =============================================================================
    // FACTORY FUNCTIONS
    // =============================================================================

    /**
     * @notice Create a new stQEURO staking token for a staking vault
     * @dev Deploys an ERC1967Proxy pointing to stakingTokenImplementation and calls
     *      stQEUROToken.initialize with the supplied parameters.  The proxy is
     *      independently upgradeable via its own UUPS mechanism.
     * @param _vaultId Numeric identifier for the vault (must be unique across all vault IDs)
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
     * @custom:security Enforces unique vaultId and vault address; re-entrancy protected
     * @custom:validation Validates all addresses via stQEUROToken.initialize
     * @custom:state-changes Registers token; updates stakingTokens, _vaultToId, _registeredVaults; increments tokenCount
     * @custom:events Emits StakingTokenCreated
     * @custom:errors Throws StakingTokenAlreadyExists or VaultAlreadyRegistered; propagates inner init errors
     * @custom:reentrancy Protected by nonReentrant
     * @custom:access Restricted to FACTORY_ROLE
     * @custom:oracle No oracle dependencies
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
    ) external nonReentrant onlyRole(FACTORY_ROLE) whenNotPaused returns (address proxy) {
        if (stakingTokens[_vaultId] != address(0)) {
            revert StakingTokenFactoryErrorLibrary.StakingTokenAlreadyExists(_vaultId);
        }
        CommonValidationLibrary.validateNonZeroAddress(_vault, "vault");
        if (_registeredVaults[_vault]) {
            revert StakingTokenFactoryErrorLibrary.VaultAlreadyRegistered(_vault);
        }

        bytes memory initData = abi.encodeCall(
            stQEUROToken.initialize,
            (name, symbol, _vaultId, _vault, admin, qeuro, yieldShift, usdc, treasury, timelockAddr)
        );

        proxy = address(new ERC1967Proxy(stakingTokenImplementation, initData));

        stakingTokens[_vaultId] = proxy;
        _vaultToId[_vault] = _vaultId;
        _registeredVaults[_vault] = true;
        _vaultIds.push(_vaultId);
        tokenCount++;

        emit StakingTokenCreated(_vaultId, proxy, _vault, name, symbol);
    }

    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================

    /**
     * @notice Get the stQEURO proxy address for a given vault ID
     * @param _vaultId Numeric vault identifier
     * @return stakingToken Address of the stQEURO proxy
     * @custom:errors Throws StakingTokenNotFound if vaultId is not registered
     * @custom:access Public view
     */
    function getStakingToken(uint256 _vaultId) external view returns (address stakingToken) {
        stakingToken = stakingTokens[_vaultId];
        if (stakingToken == address(0)) {
            revert StakingTokenFactoryErrorLibrary.StakingTokenNotFound(_vaultId);
        }
    }

    /**
     * @notice Get the stQEURO proxy address for a given vault address
     * @dev Returns address(0) if the vault is not registered
     * @param _vault Address of the staking vault
     * @return Address of the stQEURO proxy, or address(0) if not found
     * @custom:access Public view
     */
    function getStakingTokenByVault(address _vault) external view returns (address) {
        if (!_registeredVaults[_vault]) return address(0);
        return stakingTokens[_vaultToId[_vault]];
    }

    /**
     * @notice Returns whether a vault address is already registered in this factory
     * @param _vault Address to check
     * @return True if registered, false otherwise
     * @custom:access Public view
     */
    function isVaultRegistered(address _vault) external view returns (bool) {
        return _registeredVaults[_vault];
    }

    /**
     * @notice Returns the vault ID registered for a given vault address
     * @dev Returns 0 if not registered — callers should use isVaultRegistered() first
     * @param _vault Address of the staking vault
     * @return The vault ID, or 0 if not registered
     * @custom:access Public view
     */
    function getVaultId(address _vault) external view returns (uint256) {
        return _vaultToId[_vault];
    }

    /**
     * @notice Returns all registered vault IDs in creation order
     * @return Array of vault IDs
     * @custom:access Public view
     */
    function getAllVaultIds() external view returns (uint256[] memory) {
        return _vaultIds;
    }

    /**
     * @notice Returns all registered stQEURO proxy addresses in creation order
     * @return tokens Array of stQEURO proxy addresses corresponding to getAllVaultIds()
     * @custom:access Public view
     */
    function getAllStakingTokens() external view returns (address[] memory tokens) {
        uint256 len = _vaultIds.length;
        tokens = new address[](len);
        for (uint256 i = 0; i < len; ++i) {
            tokens[i] = stakingTokens[_vaultIds[i]];
        }
    }

    // =============================================================================
    // GOVERNANCE FUNCTIONS
    // =============================================================================

    /**
     * @notice Update the stQEURO implementation address used for future token deployments
     * @dev Only affects tokens created after this call; existing proxies are NOT migrated.
     *      To upgrade an existing proxy, call upgradeToAndCall directly on that proxy.
     * @param newImpl Address of the new stQEUROToken logic contract
     * @custom:security Only affects future deployments; existing proxies are independent
     * @custom:validation Validates newImpl is not zero and differs from current implementation
     * @custom:state-changes Updates stakingTokenImplementation
     * @custom:events Emits ImplementationUpdated
     * @custom:errors Throws InvalidImplementation if zero or unchanged
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function updateImplementation(address newImpl) external onlyRole(GOVERNANCE_ROLE) {
        if (newImpl == address(0) || newImpl == stakingTokenImplementation) {
            revert StakingTokenFactoryErrorLibrary.InvalidImplementation();
        }
        address oldImpl = stakingTokenImplementation;
        stakingTokenImplementation = newImpl;
        emit ImplementationUpdated(oldImpl, newImpl);
    }

    // =============================================================================
    // EMERGENCY FUNCTIONS
    // =============================================================================

    /**
     * @notice Pause the factory — prevents new staking token creation
     * @custom:access Restricted to EMERGENCY_ROLE
     */
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the factory — re-enables staking token creation
     * @custom:access Restricted to EMERGENCY_ROLE
     */
    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }

    // =============================================================================
    // UUPS UPGRADE AUTHORIZATION
    // =============================================================================

    /**
     * @notice Authorize an upgrade of the factory implementation
     * @dev Restricted to DEFAULT_ADMIN_ROLE via inherited SecureUpgradeable pattern
     * @param newImplementation Address of the new factory implementation
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {} // solhint-disable-line no-empty-blocks
}
