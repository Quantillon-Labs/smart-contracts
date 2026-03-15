// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {CommonErrorLibrary} from "../libraries/CommonErrorLibrary.sol";
import {CommonValidationLibrary} from "../libraries/CommonValidationLibrary.sol";
import {SecureUpgradeable} from "./SecureUpgradeable.sol";
import {stQEUROToken} from "./stQEUROToken.sol";

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

    constructor() {
        _disableInitializers();
    }

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
        CommonValidationLibrary.validateNonZeroAddress(admin, "admin");
        CommonValidationLibrary.validateNonZeroAddress(_tokenImplementation, "token");
        CommonValidationLibrary.validateNonZeroAddress(_qeuro, "token");
        CommonValidationLibrary.validateNonZeroAddress(_yieldShift, "token");
        CommonValidationLibrary.validateNonZeroAddress(_usdc, "token");
        CommonValidationLibrary.validateNonZeroAddress(_treasury, "treasury");

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
     */
    function registerVault(uint256 vaultId, string calldata vaultName) external onlyRole(VAULT_FACTORY_ROLE) returns (address stQEUROToken_) {
        address vault = msg.sender;
        if (vault == address(0)) revert CommonErrorLibrary.ZeroAddress();
        if (vaultId == 0) revert CommonErrorLibrary.InvalidVault();
        if (stQEUROByVaultId[vaultId] != address(0) || stQEUROByVault[vault] != address(0)) {
            revert CommonErrorLibrary.AlreadyInitialized();
        }

        _validateVaultName(vaultName);
        bytes32 nameHash = keccak256(bytes(vaultName));
        if (_vaultNameHashUsed[nameHash]) revert CommonErrorLibrary.AlreadyInitialized();

        string memory tokenName = string.concat("Staked Quantillon Euro ", vaultName);
        string memory tokenSymbol = string.concat("stQEURO", vaultName);

        bytes4 initSelector =
            bytes4(keccak256("initialize(address,address,address,address,address,address,string,string,string)"));
        bytes memory initData =
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
        ERC1967Proxy proxy = new ERC1967Proxy(tokenImplementation, initData);
        stQEUROToken_ = address(proxy);

        stQEUROByVaultId[vaultId] = stQEUROToken_;
        stQEUROByVault[vault] = stQEUROToken_;
        vaultById[vaultId] = vault;
        vaultIdByStQEURO[stQEUROToken_] = vaultId;
        _vaultNamesById[vaultId] = vaultName;
        _vaultNameHashUsed[nameHash] = true;

        emit VaultRegistered(vaultId, vault, stQEUROToken_, vaultName);
    }

    function getStQEUROByVaultId(uint256 vaultId) external view returns (address stQEUROToken_) {
        return stQEUROByVaultId[vaultId];
    }

    function getStQEUROByVault(address vault) external view returns (address stQEUROToken_) {
        return stQEUROByVault[vault];
    }

    function getVaultById(uint256 vaultId) external view returns (address vault) {
        return vaultById[vaultId];
    }

    function getVaultIdByStQEURO(address stQEUROToken_) external view returns (uint256 vaultId) {
        return vaultIdByStQEURO[stQEUROToken_];
    }

    function getVaultName(uint256 vaultId) external view returns (string memory vaultName) {
        return _vaultNamesById[vaultId];
    }

    function updateYieldShift(address _yieldShift) external onlyRole(GOVERNANCE_ROLE) {
        CommonValidationLibrary.validateNonZeroAddress(_yieldShift, "token");
        emit FactoryConfigUpdated("yieldShift", yieldShift, _yieldShift);
        yieldShift = _yieldShift;
    }

    function updateTokenImplementation(address _tokenImplementation) external onlyRole(GOVERNANCE_ROLE) {
        CommonValidationLibrary.validateNonZeroAddress(_tokenImplementation, "token");
        emit FactoryConfigUpdated("tokenImplementation", tokenImplementation, _tokenImplementation);
        tokenImplementation = _tokenImplementation;
    }

    function updateOracle(address _oracle) external onlyRole(GOVERNANCE_ROLE) {
        emit FactoryConfigUpdated("oracle", oracle, _oracle);
        oracle = _oracle;
    }

    function updateTreasury(address _treasury) external onlyRole(GOVERNANCE_ROLE) {
        CommonValidationLibrary.validateNonZeroAddress(_treasury, "treasury");
        CommonValidationLibrary.validateTreasuryAddress(_treasury);
        emit FactoryConfigUpdated("treasury", treasury, _treasury);
        treasury = _treasury;
    }

    function updateTokenAdmin(address _tokenAdmin) external onlyRole(GOVERNANCE_ROLE) {
        CommonValidationLibrary.validateNonZeroAddress(_tokenAdmin, "admin");
        emit FactoryConfigUpdated("tokenAdmin", tokenAdmin, _tokenAdmin);
        tokenAdmin = _tokenAdmin;
    }

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
    }
}
