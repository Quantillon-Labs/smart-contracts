// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

import {CommonErrorLibrary} from "../libraries/CommonErrorLibrary.sol";
import {SecureUpgradeable} from "./SecureUpgradeable.sol";

/**
 * @title stQEUROFactory
 * @notice Deploys and registers one stQEURO token proxy per staking vault.
 */
contract stQEUROFactory is Initializable, AccessControlUpgradeable, SecureUpgradeable {
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant VAULT_FACTORY_ROLE = keccak256("VAULT_FACTORY_ROLE");

    /// @notice stQEUROToken implementation used by newly deployed ERC1967 proxies.
    address public tokenImplementation;
    address public qeuro;
    address public yieldShift;
    address public usdc;
    address public treasury;
    address public oracle;
    address public tokenAdmin;

    mapping(uint256 => address) public stQEUROByVaultId;
    mapping(address => address) public stQEUROByVault;
    mapping(uint256 => address) public vaultById;
    mapping(address => uint256) public vaultIdByStQEURO;
    mapping(uint256 => string) private _vaultNamesById;
    mapping(bytes32 => bool) private _vaultNameHashUsed;

    event VaultRegistered(
        uint256 indexed vaultId,
        address indexed vault,
        address indexed stQEUROToken,
        string vaultName
    );
    event FactoryConfigUpdated(string indexed key, address oldValue, address newValue);

    /**
     * @notice Disables initializers on the implementation contract.
     * @dev Prevents direct initialization of the logic contract in proxy deployments.
     * @custom:security Locks implementation initialization to prevent takeover.
     * @custom:validation No input parameters.
     * @custom:state-changes Sets initializer state to disabled.
     * @custom:events No events emitted.
     * @custom:errors No custom errors expected.
     * @custom:reentrancy Not applicable during construction.
     * @custom:access Constructor executes once at deployment.
     * @custom:oracle No oracle dependencies.
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the stQEURO factory configuration and roles.
     * @dev Sets deployment dependencies and grants admin/governance/factory roles to `admin`.
     * @param admin Address receiving admin and governance privileges.
     * @param _tokenImplementation ERC1967 implementation used for new stQEURO proxies.
     * @param _qeuro QEURO token address.
     * @param _yieldShift YieldShift contract address.
     * @param _usdc USDC token address.
     * @param _treasury Treasury address used by deployed tokens.
     * @param _timelock Timelock contract used by SecureUpgradeable.
     * @param _oracle Oracle address referenced by the factory configuration.
     * @custom:security Validates all critical addresses before storing configuration.
     * @custom:validation Reverts on zero addresses for required dependencies.
     * @custom:state-changes Initializes access control and stores factory dependencies.
     * @custom:events Emits role grant events from AccessControl initialization.
     * @custom:errors Reverts with custom invalid-address errors for bad inputs.
     * @custom:reentrancy Protected by initializer pattern; no external untrusted flow.
     * @custom:access Callable once via `initializer`.
     * @custom:oracle Stores oracle configuration address; no live price reads.
     */
    function initialize(
        address admin,
        address _tokenImplementation,
        address _qeuro,
        address _yieldShift,
        address _usdc,
        address _treasury,
        address _timelock,
        address _oracle
    ) external initializer {
        if (admin == address(0)) revert CommonErrorLibrary.InvalidAdmin();
        if (_tokenImplementation == address(0)) revert CommonErrorLibrary.InvalidToken();
        if (_qeuro == address(0)) revert CommonErrorLibrary.InvalidToken();
        if (_yieldShift == address(0)) revert CommonErrorLibrary.InvalidToken();
        if (_usdc == address(0)) revert CommonErrorLibrary.InvalidToken();
        if (_treasury == address(0)) revert CommonErrorLibrary.InvalidTreasury();
        if (_oracle == address(0)) revert CommonErrorLibrary.InvalidOracle();

        __AccessControl_init();
        __SecureUpgradeable_init(_timelock);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(VAULT_FACTORY_ROLE, admin);

        tokenImplementation = _tokenImplementation;
        qeuro = _qeuro;
        yieldShift = _yieldShift;
        usdc = _usdc;
        treasury = _treasury;
        oracle = _oracle;
        tokenAdmin = admin;
    }

    /**
     * @notice Strict self-registration entrypoint. Caller vault deploys its own stQEURO.
     * @dev Computes deterministic proxy address, commits registry state, then deploys proxy with CREATE2.
     * @param vaultId Unique vault identifier in factory registry.
     * @param vaultName Uppercase alphanumeric vault label used for token metadata.
     * @return stQEUROToken_ Deterministic stQEURO proxy address registered for the vault.
     * @custom:security Restricts calls to `VAULT_FACTORY_ROLE` and enforces single-registration invariants.
     * @custom:validation Validates non-zero vault id, caller uniqueness, and vault name format.
     * @custom:state-changes Writes vault/token registry mappings and vault name tracking.
     * @custom:events Emits `VaultRegistered` on successful registration.
     * @custom:errors Reverts on invalid input, duplicate registration, or unexpected deployment address.
     * @custom:reentrancy Uses deterministic CEI ordering; critical state is committed before proxy deployment.
     * @custom:access Restricted to `VAULT_FACTORY_ROLE`.
     * @custom:oracle No oracle dependencies.
     */
    function registerVault(uint256 vaultId, string calldata vaultName)
        external
        onlyRole(VAULT_FACTORY_ROLE)
        returns (address stQEUROToken_)
    {
        address vault = msg.sender;
        if (vault == address(0)) revert CommonErrorLibrary.ZeroAddress();
        if (vaultId == 0) revert CommonErrorLibrary.InvalidVault();
        if (stQEUROByVaultId[vaultId] != address(0) || stQEUROByVault[vault] != address(0)) {
            revert CommonErrorLibrary.AlreadyInitialized();
        }

        _validateVaultName(vaultName);
        bytes32 nameHash;
        assembly ("memory-safe") {
            nameHash := keccak256(vaultName.offset, vaultName.length)
        }
        if (_vaultNameHashUsed[nameHash]) revert CommonErrorLibrary.AlreadyInitialized();

        bytes32 salt = _vaultSalt(vault, vaultId, vaultName);
        bytes memory initData = _buildInitData(vaultName);
        stQEUROToken_ = _predictProxyAddress(salt, initData);

        stQEUROByVaultId[vaultId] = stQEUROToken_;
        stQEUROByVault[vault] = stQEUROToken_;
        vaultById[vaultId] = vault;
        vaultIdByStQEURO[stQEUROToken_] = vaultId;
        _vaultNamesById[vaultId] = vaultName;
        _vaultNameHashUsed[nameHash] = true;

        address deployedProxy = address(new ERC1967Proxy{salt: salt}(tokenImplementation, initData));
        if (deployedProxy != stQEUROToken_) revert CommonErrorLibrary.InvalidAddress();

        emit VaultRegistered(vaultId, vault, stQEUROToken_, vaultName);
    }

    /**
     * @notice Previews the deterministic stQEURO token address for a vault registration.
     * @dev Computes the CREATE2 address using current factory configuration and provided vault metadata.
     * @param vault Vault contract address that will call `registerVault`.
     * @param vaultId Target vault identifier.
     * @param vaultName Uppercase alphanumeric vault label.
     * @return stQEUROToken_ Predicted stQEURO proxy address for this registration tuple.
     * @custom:security Read-only helper for deterministic address binding before registration.
     * @custom:validation Reverts for zero vault address, zero vault id, or invalid vault name.
     * @custom:state-changes No state changes; pure preview path.
     * @custom:events No events emitted.
     * @custom:errors Reverts on invalid vault metadata.
     * @custom:reentrancy Not applicable for view function.
     * @custom:access Public view helper.
     * @custom:oracle No oracle dependencies.
     */
    function previewVaultToken(address vault, uint256 vaultId, string calldata vaultName)
        external
        view
        returns (address stQEUROToken_)
    {
        if (vault == address(0)) revert CommonErrorLibrary.ZeroAddress();
        if (vaultId == 0) revert CommonErrorLibrary.InvalidVault();
        _validateVaultName(vaultName);

        bytes32 salt = _vaultSalt(vault, vaultId, vaultName);
        bytes memory initData = _buildInitData(vaultName);
        stQEUROToken_ = _predictProxyAddress(salt, initData);
    }

    /**
     * @notice Returns registered stQEURO token by vault id.
     * @dev Reads factory mapping for vault-id-to-token resolution.
     * @param vaultId Vault identifier in factory registry.
     * @return stQEUROToken_ Registered stQEURO token address (or zero if unset).
     * @custom:security Read-only lookup with no privileged behavior.
     * @custom:validation No additional validation; returns zero for unknown ids.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors No errors expected.
     * @custom:reentrancy Not applicable for view function.
     * @custom:access Public view.
     * @custom:oracle No oracle dependencies.
     */
    function getStQEUROByVaultId(uint256 vaultId) external view returns (address stQEUROToken_) {
        return stQEUROByVaultId[vaultId];
    }

    /**
     * @notice Returns registered stQEURO token by vault address.
     * @dev Reads factory mapping for vault-to-token resolution.
     * @param vault Vault contract address.
     * @return stQEUROToken_ Registered stQEURO token address (or zero if unset).
     * @custom:security Read-only lookup with no privileged behavior.
     * @custom:validation No additional validation; returns zero for unknown vaults.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors No errors expected.
     * @custom:reentrancy Not applicable for view function.
     * @custom:access Public view.
     * @custom:oracle No oracle dependencies.
     */
    function getStQEUROByVault(address vault) external view returns (address stQEUROToken_) {
        return stQEUROByVault[vault];
    }

    /**
     * @notice Returns vault address bound to a vault id.
     * @dev Reads registry mapping populated during registration.
     * @param vaultId Vault identifier in factory registry.
     * @return vault Vault address associated with the id (or zero if unset).
     * @custom:security Read-only lookup.
     * @custom:validation No additional validation; returns zero for unknown ids.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors No errors expected.
     * @custom:reentrancy Not applicable for view function.
     * @custom:access Public view.
     * @custom:oracle No oracle dependencies.
     */
    function getVaultById(uint256 vaultId) external view returns (address vault) {
        return vaultById[vaultId];
    }

    /**
     * @notice Returns vault id bound to an stQEURO token.
     * @dev Reads reverse registry mapping from token address to vault id.
     * @param stQEUROToken_ Registered stQEURO token address.
     * @return vaultId Vault identifier associated with the token (or zero if unset).
     * @custom:security Read-only lookup.
     * @custom:validation No additional validation; returns zero for unknown tokens.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors No errors expected.
     * @custom:reentrancy Not applicable for view function.
     * @custom:access Public view.
     * @custom:oracle No oracle dependencies.
     */
    function getVaultIdByStQEURO(address stQEUROToken_) external view returns (uint256 vaultId) {
        return vaultIdByStQEURO[stQEUROToken_];
    }

    /**
     * @notice Returns vault name string for a vault id.
     * @dev Reads the stored canonical vault label registered at creation time.
     * @param vaultId Vault identifier in factory registry.
     * @return vaultName Stored vault name (empty string if unset).
     * @custom:security Read-only lookup.
     * @custom:validation No additional validation; returns empty value for unknown ids.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors No errors expected.
     * @custom:reentrancy Not applicable for view function.
     * @custom:access Public view.
     * @custom:oracle No oracle dependencies.
     */
    function getVaultName(uint256 vaultId) external view returns (string memory vaultName) {
        return _vaultNamesById[vaultId];
    }

    /**
     * @notice Updates YieldShift dependency for future token deployments.
     * @dev Governance-only setter for the factory-level YieldShift address.
     * @param _yieldShift New YieldShift contract address.
     * @custom:security Restricted to governance role.
     * @custom:validation Reverts if `_yieldShift` is zero address.
     * @custom:state-changes Updates `yieldShift` configuration.
     * @custom:events Emits `FactoryConfigUpdated`.
     * @custom:errors Reverts with `InvalidToken` for zero address.
     * @custom:reentrancy No external calls beyond event emission.
     * @custom:access Restricted to `GOVERNANCE_ROLE`.
     * @custom:oracle No oracle dependencies.
     */
    function updateYieldShift(address _yieldShift) external onlyRole(GOVERNANCE_ROLE) {
        if (_yieldShift == address(0)) revert CommonErrorLibrary.InvalidToken();
        emit FactoryConfigUpdated("yieldShift", yieldShift, _yieldShift);
        yieldShift = _yieldShift;
    }

    /**
     * @notice Updates stQEURO implementation used for new proxies.
     * @dev Governance-only setter for proxy implementation address.
     * @param _tokenImplementation New implementation contract address.
     * @custom:security Restricted to governance role.
     * @custom:validation Reverts if `_tokenImplementation` is zero address.
     * @custom:state-changes Updates `tokenImplementation` configuration.
     * @custom:events Emits `FactoryConfigUpdated`.
     * @custom:errors Reverts with `InvalidToken` for zero address.
     * @custom:reentrancy No external calls beyond event emission.
     * @custom:access Restricted to `GOVERNANCE_ROLE`.
     * @custom:oracle No oracle dependencies.
     */
    function updateTokenImplementation(address _tokenImplementation) external onlyRole(GOVERNANCE_ROLE) {
        if (_tokenImplementation == address(0)) revert CommonErrorLibrary.InvalidToken();
        emit FactoryConfigUpdated("tokenImplementation", tokenImplementation, _tokenImplementation);
        tokenImplementation = _tokenImplementation;
    }

    /**
     * @notice Updates oracle dependency address for factory configuration.
     * @dev Governance-only setter for oracle address used by future deployments.
     * @param _oracle New oracle contract address.
     * @custom:security Restricted to governance role.
     * @custom:validation Reverts if `_oracle` is zero address.
     * @custom:state-changes Updates `oracle` configuration.
     * @custom:events Emits `FactoryConfigUpdated`.
     * @custom:errors Reverts with `InvalidOracle` for zero address.
     * @custom:reentrancy No external calls beyond event emission.
     * @custom:access Restricted to `GOVERNANCE_ROLE`.
     * @custom:oracle Updates oracle reference; no live price reads.
     */
    function updateOracle(address _oracle) external onlyRole(GOVERNANCE_ROLE) {
        if (_oracle == address(0)) revert CommonErrorLibrary.InvalidOracle();
        emit FactoryConfigUpdated("oracle", oracle, _oracle);
        oracle = _oracle;
    }

    /**
     * @notice Updates treasury address propagated to new token deployments.
     * @dev Governance-only setter for factory treasury configuration.
     * @param _treasury New treasury address.
     * @custom:security Restricted to governance role.
     * @custom:validation Reverts if `_treasury` is zero address.
     * @custom:state-changes Updates `treasury` configuration.
     * @custom:events Emits `FactoryConfigUpdated`.
     * @custom:errors Reverts with `InvalidTreasury` for zero address.
     * @custom:reentrancy No external calls beyond event emission.
     * @custom:access Restricted to `GOVERNANCE_ROLE`.
     * @custom:oracle No oracle dependencies.
     */
    function updateTreasury(address _treasury) external onlyRole(GOVERNANCE_ROLE) {
        if (_treasury == address(0)) revert CommonErrorLibrary.InvalidTreasury();
        emit FactoryConfigUpdated("treasury", treasury, _treasury);
        treasury = _treasury;
    }

    /**
     * @notice Updates token admin propagated to new token deployments.
     * @dev Governance-only setter for default token admin address.
     * @param _tokenAdmin New admin address for newly deployed stQEURO proxies.
     * @custom:security Restricted to governance role.
     * @custom:validation Reverts if `_tokenAdmin` is zero address.
     * @custom:state-changes Updates `tokenAdmin` configuration.
     * @custom:events Emits `FactoryConfigUpdated`.
     * @custom:errors Reverts with `InvalidAdmin` for zero address.
     * @custom:reentrancy No external calls beyond event emission.
     * @custom:access Restricted to `GOVERNANCE_ROLE`.
     * @custom:oracle No oracle dependencies.
     */
    function updateTokenAdmin(address _tokenAdmin) external onlyRole(GOVERNANCE_ROLE) {
        if (_tokenAdmin == address(0)) revert CommonErrorLibrary.InvalidAdmin();
        emit FactoryConfigUpdated("tokenAdmin", tokenAdmin, _tokenAdmin);
        tokenAdmin = _tokenAdmin;
    }

    /**
     * @notice Validates vault name format used by the registry.
     * @dev Accepts only uppercase letters and digits with length in range 1..12.
     * @param vaultName Candidate vault label to validate.
     * @custom:security Prevents malformed identifiers from entering registry state.
     * @custom:validation Reverts for empty, oversized, or non-alphanumeric-uppercase names.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors Reverts with `InvalidParameter` on invalid name format.
     * @custom:reentrancy Not applicable for pure validation helper.
     * @custom:access Internal helper.
     * @custom:oracle No oracle dependencies.
     */
    function _validateVaultName(string calldata vaultName) internal pure {
        bytes calldata raw = bytes(vaultName);
        uint256 len = raw.length;
        if (len == 0 || len > 12) revert CommonErrorLibrary.InvalidParameter();

        for (uint256 i = 0; i < len; ++i) {
            bytes1 ch = raw[i];
            bool isUpper = ch >= 0x41 && ch <= 0x5A;
            bool isDigit = ch >= 0x30 && ch <= 0x39;
            if (!isUpper && !isDigit) revert CommonErrorLibrary.InvalidParameter();
        }

        if (len == 4 && raw[0] == 0x43 && raw[1] == 0x4F && raw[2] == 0x52 && raw[3] == 0x45) {
            revert CommonErrorLibrary.InvalidParameter();
        }
    }

    /**
     * @notice Computes deterministic CREATE2 salt for vault registration.
     * @dev Hashes vault identity tuple to ensure unique deterministic deployment address.
     * @param vault Vault contract address.
     * @param vaultId Vault identifier.
     * @param vaultName Vault name string.
     * @return salt CREATE2 salt derived from vault tuple.
     * @custom:security Deterministic salt prevents accidental collisions across registrations.
     * @custom:validation Expects validated inputs from caller functions.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors No errors expected.
     * @custom:reentrancy Not applicable for pure helper.
     * @custom:access Internal helper.
     * @custom:oracle No oracle dependencies.
     */
    function _vaultSalt(address vault, uint256 vaultId, string calldata vaultName) internal pure returns (bytes32 salt) {
        bytes memory encoded = abi.encode(vault, vaultId, vaultName);
        assembly ("memory-safe") {
            salt := keccak256(add(encoded, 0x20), mload(encoded))
        }
    }

    /**
     * @notice Builds initializer calldata for stQEURO proxy deployment.
     * @dev Encodes token metadata and dependency addresses for the stQEURO `initialize` call.
     * @param vaultName Vault name used to derive token display name and symbol.
     * @return initData ABI-encoded initializer payload for proxy constructor.
     * @custom:security Uses factory-stored trusted dependency addresses.
     * @custom:validation Expects validated vault name input from caller.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors No custom errors expected.
     * @custom:reentrancy Not applicable for view helper.
     * @custom:access Internal helper.
     * @custom:oracle Uses stored oracle address indirectly through configuration.
     */
    function _buildInitData(string calldata vaultName) internal view returns (bytes memory initData) {
        string memory tokenName = string.concat("Staked Quantillon Euro ", vaultName);
        string memory tokenSymbol = string.concat("stQEURO", vaultName);
        bytes4 initSelector =
            bytes4(keccak256("initialize(address,address,address,address,address,address,string,string,string)"));

        return
            abi.encodeWithSelector(
                initSelector,
                tokenAdmin,
                qeuro,
                yieldShift,
                usdc,
                treasury,
                address(timelock),
                tokenName,
                tokenSymbol,
                vaultName
            );
    }

    /**
     * @notice Predicts CREATE2 proxy address for a vault registration.
     * @dev Recreates ERC1967Proxy creation bytecode hash and computes deterministic deployment address.
     * @param salt CREATE2 salt for deployment.
     * @param initData ABI-encoded initializer payload.
     * @return Predicted proxy address for the given deployment inputs.
     * @custom:security Enables pre-commit address binding to mitigate registration race inconsistencies.
     * @custom:validation Expects valid creation inputs from caller.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors No custom errors expected.
     * @custom:reentrancy Not applicable for view helper.
     * @custom:access Internal helper.
     * @custom:oracle No oracle dependencies.
     */
    function _predictProxyAddress(bytes32 salt, bytes memory initData) internal view returns (address) {
        bytes memory creationCode = abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(tokenImplementation, initData));
        return Create2.computeAddress(salt, keccak256(creationCode));
    }
}
