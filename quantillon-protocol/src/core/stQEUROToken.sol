// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IQEUROToken} from "../interfaces/IQEUROToken.sol";
import {CommonErrorLibrary} from "../libraries/CommonErrorLibrary.sol";
import {CommonValidationLibrary} from "../libraries/CommonValidationLibrary.sol";
import {SecureUpgradeable} from "./SecureUpgradeable.sol";
import {TreasuryRecoveryLibrary} from "../libraries/TreasuryRecoveryLibrary.sol";
import {TimeProvider} from "../libraries/TimeProviderLibrary.sol";

/**
 * @title stQEUROToken
 * @notice ERC-4626 vault over QEURO used for per-vault staking series.
 */
contract stQEUROToken is
    Initializable,
    ERC4626Upgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    SecureUpgradeable
{
    using SafeERC20 for IERC20;
    using Address for address payable;

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    IQEUROToken public qeuro;
    address public treasury;
    string public vaultName;
    uint256 public yieldFee;

    TimeProvider public immutable TIME_PROVIDER;

    event YieldParametersUpdated(uint256 yieldFee);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury, address indexed caller);
    event ETHRecovered(address indexed to, uint256 indexed amount);

    /**
     * @notice Constructs the implementation contract with its immutable time provider.
     * @dev Validates the provided time provider, stores it immutably, and disables initializers on the implementation.
     * @param _TIME_PROVIDER Time provider used by inherited secure upgrade and timelock logic.
     * @custom:security Rejects zero-address dependencies before deployment completes.
     * @custom:validation Ensures `_TIME_PROVIDER` is non-zero.
     * @custom:state-changes Sets the immutable `TIME_PROVIDER` reference and disables future initializers on the implementation.
     * @custom:events None.
     * @custom:errors Reverts with `ZeroAddress` when `_TIME_PROVIDER` is the zero address.
     * @custom:reentrancy Not applicable.
     * @custom:access Deployment only.
     * @custom:oracle Not applicable.
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(TimeProvider _TIME_PROVIDER) {
        if (address(_TIME_PROVIDER) == address(0)) revert CommonErrorLibrary.ZeroAddress();
        TIME_PROVIDER = _TIME_PROVIDER;
        _disableInitializers();
    }

    /**
     * @notice Initializes the default stQEURO vault series without a vault suffix.
     * @dev Keeps the legacy initializer shape for factory compatibility, ignores unused placeholder addresses, and wires the ERC-4626 vault over QEURO.
     * @param admin Address receiving admin, governance, and emergency roles.
     * @param _qeuro QEURO token used as the ERC-4626 underlying asset.
     * @param _treasury Treasury that receives recovered assets and fees.
     * @param _timelock Timelock used by inherited secure upgrade controls.
     * @custom:security Uses OpenZeppelin initializer guards and validates all named dependencies before role grants.
     * @custom:validation Ensures admin, token, treasury, and timelock dependencies are valid for vault setup.
     * @custom:state-changes Initializes ERC-20/ERC-4626 metadata, role assignments, treasury configuration, and the vault asset reference.
     * @custom:events Emits initialization events through inherited OpenZeppelin modules when applicable.
     * @custom:errors Reverts on duplicate initialization or invalid dependency addresses.
     * @custom:reentrancy Not applicable during initialization.
     * @custom:access Callable once during deployment.
     * @custom:oracle Not applicable.
     */
    function initialize(
        address admin,
        address _qeuro,
        address,
        address,
        address _treasury,
        address _timelock
    ) public initializer {
        __ERC20_init("Staked Quantillon Euro", "stQEURO");
        __ERC4626_init(IERC20(_qeuro));
        vaultName = "";
        _initializeStQEURODependencies(admin, _qeuro, _treasury, _timelock);
    }

    /**
     * @notice Initializes a vault-specific stQEURO series with custom metadata.
     * @dev Builds vault-specific ERC-20 metadata, sets the ERC-4626 asset to QEURO, and applies secure-role configuration.
     * @param admin Address receiving admin, governance, and emergency roles.
     * @param _qeuro QEURO token used as the ERC-4626 underlying asset.
     * @param _treasury Treasury that receives recovered assets and fees.
     * @param _timelock Timelock used by inherited secure upgrade controls.
     * @param _vaultName Vault suffix appended to the share-token name and symbol.
     * @custom:security Uses initializer guards and validates critical dependency addresses before activation.
     * @custom:validation Ensures named dependencies are non-zero and treasury configuration is valid.
     * @custom:state-changes Initializes ERC-20/ERC-4626 metadata, stores `vaultName`, and grants operational roles.
     * @custom:events Emits initialization events through inherited OpenZeppelin modules when applicable.
     * @custom:errors Reverts on duplicate initialization or invalid dependency addresses.
     * @custom:reentrancy Not applicable during initialization.
     * @custom:access Callable once during deployment.
     * @custom:oracle Not applicable.
     */
    function initialize(
        address admin,
        address _qeuro,
        address _treasury,
        address _timelock,
        string calldata _vaultName
    ) public initializer {
        string memory tokenName = string.concat("Staked Quantillon Euro ", _vaultName);
        string memory tokenSymbol = string.concat("stQEURO", _vaultName);

        __ERC20_init(tokenName, tokenSymbol);
        __ERC4626_init(IERC20(_qeuro));
        vaultName = _vaultName;
        _initializeStQEURODependencies(admin, _qeuro, _treasury, _timelock);
    }

    /**
     * @notice Applies the shared dependency and role setup for all stQEURO vault series.
     * @dev Initializes inherited access-control, pause, reentrancy, and secure-upgrade modules, then stores treasury and QEURO references.
     * @param admin Address receiving admin, governance, and emergency roles.
     * @param qeuroAddress Address of the QEURO underlying asset.
     * @param treasuryAddress Treasury destination for recovered funds.
     * @param timelockAddress Timelock used by the inherited secure-upgrade module.
     * @custom:security Centralizes all critical dependency validation before privileged roles are granted.
     * @custom:validation Requires non-zero admin/token/treasury addresses and a valid treasury destination.
     * @custom:state-changes Initializes inherited modules, grants roles, stores token/treasury references, and resets `yieldFee` to zero.
     * @custom:events Emits inherited role/admin initialization events when applicable.
     * @custom:errors Reverts on invalid addresses or treasury configuration failures.
     * @custom:reentrancy Not applicable.
     * @custom:access Internal initialization helper.
     * @custom:oracle Not applicable.
     */
    function _initializeStQEURODependencies(
        address admin,
        address qeuroAddress,
        address treasuryAddress,
        address timelockAddress
    ) internal {
        CommonValidationLibrary.validateNonZeroAddress(admin, "admin");
        CommonValidationLibrary.validateNonZeroAddress(qeuroAddress, "token");
        CommonValidationLibrary.validateNonZeroAddress(treasuryAddress, "treasury");
        CommonValidationLibrary.validateTreasuryAddress(treasuryAddress);

        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __SecureUpgradeable_init(timelockAddress);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);

        qeuro = IQEUROToken(qeuroAddress);
        treasury = treasuryAddress;
        yieldFee = 0;
    }

    /**
     * @notice Returns the maximum assets a receiver can deposit while respecting pause state.
     * @dev Returns zero when the vault is paused and otherwise delegates limit calculation to the ERC-4626 parent implementation.
     * @param receiver Address that would receive minted stQEURO shares.
     * @return maxAssets Maximum QEURO assets currently depositable for `receiver`.
     * @custom:security Read-only helper.
     * @custom:validation Paused state forces a zero limit.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function maxDeposit(address receiver) public view override returns (uint256) {
        if (paused()) return 0;
        return super.maxDeposit(receiver);
    }

    /**
     * @notice Returns the maximum shares a receiver can mint while respecting pause state.
     * @dev Returns zero when the vault is paused and otherwise delegates limit calculation to the ERC-4626 parent implementation.
     * @param receiver Address that would receive minted stQEURO shares.
     * @return maxShares Maximum stQEURO shares currently mintable for `receiver`.
     * @custom:security Read-only helper.
     * @custom:validation Paused state forces a zero limit.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function maxMint(address receiver) public view override returns (uint256) {
        if (paused()) return 0;
        return super.maxMint(receiver);
    }

    /**
     * @notice Returns the maximum assets an owner can withdraw while respecting pause state.
     * @dev Returns zero when the vault is paused and otherwise delegates limit calculation to the ERC-4626 parent implementation.
     * @param owner Share owner whose withdraw capacity is being queried.
     * @return maxAssets Maximum QEURO assets currently withdrawable by `owner`.
     * @custom:security Read-only helper.
     * @custom:validation Paused state forces a zero limit.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function maxWithdraw(address owner) public view override returns (uint256) {
        if (paused()) return 0;
        return super.maxWithdraw(owner);
    }

    /**
     * @notice Returns the maximum shares an owner can redeem while respecting pause state.
     * @dev Returns zero when the vault is paused and otherwise delegates limit calculation to the ERC-4626 parent implementation.
     * @param owner Share owner whose redeem capacity is being queried.
     * @return maxShares Maximum stQEURO shares currently redeemable by `owner`.
     * @custom:security Read-only helper.
     * @custom:validation Paused state forces a zero limit.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function maxRedeem(address owner) public view override returns (uint256) {
        if (paused()) return 0;
        return super.maxRedeem(owner);
    }

    /**
     * @notice Deposits QEURO into the vault and mints stQEURO shares to a receiver.
     * @dev Wraps the ERC-4626 deposit flow with pause and reentrancy protection.
     * @param assets Amount of QEURO assets to deposit.
     * @param receiver Address receiving newly minted stQEURO shares.
     * @return shares Amount of stQEURO shares minted for `receiver`.
     * @custom:security Protected by pause and `nonReentrant` guards.
     * @custom:validation Delegates asset, allowance, and receiver checks to ERC-4626/ERC-20 logic.
     * @custom:state-changes Transfers QEURO into the vault and mints new stQEURO shares.
     * @custom:events Emits the standard ERC-4626 `Deposit` event.
     * @custom:errors Reverts when paused or when ERC-20/ERC-4626 validations fail.
     * @custom:reentrancy Protected by `nonReentrant`.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function deposit(uint256 assets, address receiver)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 shares)
    {
        shares = super.deposit(assets, receiver);
    }

    /**
     * @notice Mints a target amount of stQEURO shares by supplying the required QEURO assets.
     * @dev Wraps the ERC-4626 mint flow with pause and reentrancy protection.
     * @param shares Amount of stQEURO shares to mint.
     * @param receiver Address receiving the minted shares.
     * @return assets Amount of QEURO assets pulled from the caller.
     * @custom:security Protected by pause and `nonReentrant` guards.
     * @custom:validation Delegates share, allowance, and receiver checks to ERC-4626/ERC-20 logic.
     * @custom:state-changes Transfers QEURO into the vault and mints stQEURO shares.
     * @custom:events Emits the standard ERC-4626 `Deposit` event.
     * @custom:errors Reverts when paused or when ERC-20/ERC-4626 validations fail.
     * @custom:reentrancy Protected by `nonReentrant`.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function mint(uint256 shares, address receiver)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 assets)
    {
        assets = super.mint(shares, receiver);
    }

    /**
     * @notice Withdraws a target amount of QEURO assets from the vault.
     * @dev Wraps the ERC-4626 withdraw flow with pause and reentrancy protection.
     * @param assets Amount of QEURO assets to withdraw.
     * @param receiver Address receiving the withdrawn QEURO.
     * @param owner Share owner whose balance and allowance are consumed.
     * @return shares Amount of stQEURO shares burned to complete the withdrawal.
     * @custom:security Protected by pause and `nonReentrant` guards.
     * @custom:validation Delegates asset, allowance, and balance checks to ERC-4626/ERC-20 logic.
     * @custom:state-changes Burns stQEURO shares and transfers QEURO assets out of the vault.
     * @custom:events Emits the standard ERC-4626 `Withdraw` event.
     * @custom:errors Reverts when paused or when ERC-20/ERC-4626 validations fail.
     * @custom:reentrancy Protected by `nonReentrant`.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 shares)
    {
        shares = super.withdraw(assets, receiver, owner);
    }

    /**
     * @notice Redeems stQEURO shares for their corresponding QEURO assets.
     * @dev Wraps the ERC-4626 redeem flow with pause and reentrancy protection.
     * @param shares Amount of stQEURO shares to redeem.
     * @param receiver Address receiving the redeemed QEURO.
     * @param owner Share owner whose balance and allowance are consumed.
     * @return assets Amount of QEURO assets transferred to `receiver`.
     * @custom:security Protected by pause and `nonReentrant` guards.
     * @custom:validation Delegates share, allowance, and balance checks to ERC-4626/ERC-20 logic.
     * @custom:state-changes Burns stQEURO shares and transfers QEURO assets out of the vault.
     * @custom:events Emits the standard ERC-4626 `Withdraw` event.
     * @custom:errors Reverts when paused or when ERC-20/ERC-4626 validations fail.
     * @custom:reentrancy Protected by `nonReentrant`.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function redeem(uint256 shares, address receiver, address owner)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 assets)
    {
        assets = super.redeem(shares, receiver, owner);
    }

    /**
     * @notice Transfers stQEURO shares while the vault is active.
     * @dev Blocks share transfers whenever the vault is paused.
     * @param to Recipient of the transferred stQEURO shares.
     * @param value Amount of stQEURO shares to transfer.
     * @return success True when the transfer succeeds.
     * @custom:security Protected by the pause guard.
     * @custom:validation Delegates recipient, balance, and amount checks to ERC-20 logic.
     * @custom:state-changes Moves stQEURO share balances between accounts.
     * @custom:events Emits the standard ERC-20 `Transfer` event.
     * @custom:errors Reverts when paused or when ERC-20 validations fail.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function transfer(address to, uint256 value) public override(ERC20Upgradeable, IERC20) whenNotPaused returns (bool) {
        return super.transfer(to, value);
    }

    /**
     * @notice Transfers stQEURO shares from another account while the vault is active.
     * @dev Blocks allowance-based share transfers whenever the vault is paused.
     * @param from Account whose share balance and allowance are consumed.
     * @param to Recipient of the transferred stQEURO shares.
     * @param value Amount of stQEURO shares to transfer.
     * @return success True when the transfer succeeds.
     * @custom:security Protected by the pause guard.
     * @custom:validation Delegates allowance, recipient, balance, and amount checks to ERC-20 logic.
     * @custom:state-changes Moves stQEURO share balances between accounts and updates allowance when applicable.
     * @custom:events Emits the standard ERC-20 `Transfer` event and allowance events when applicable.
     * @custom:errors Reverts when paused or when ERC-20 validations fail.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle Not applicable.
     */
    function transferFrom(address from, address to, uint256 value)
        public
        override(ERC20Upgradeable, IERC20)
        whenNotPaused
        returns (bool)
    {
        return super.transferFrom(from, to, value);
    }

    /**
     * @notice Updates the yield fee charged on compounded vault yield.
     * @dev Governance can set the fee in basis points up to the configured 20% cap.
     * @param _yieldFee New yield fee in basis points.
     * @custom:security Restricted to `GOVERNANCE_ROLE`.
     * @custom:validation Validates `_yieldFee` against the 2000 bps maximum.
     * @custom:state-changes Updates the stored `yieldFee`.
     * @custom:events Emits `YieldParametersUpdated`.
     * @custom:errors Reverts on invalid fee values or missing governance role.
     * @custom:reentrancy Not applicable.
     * @custom:access Restricted to `GOVERNANCE_ROLE`.
     * @custom:oracle Not applicable.
     */
    function updateYieldParameters(uint256 _yieldFee) external onlyRole(GOVERNANCE_ROLE) {
        CommonValidationLibrary.validatePercentage(_yieldFee, 2000);
        yieldFee = _yieldFee;
        emit YieldParametersUpdated(_yieldFee);
    }

    /**
     * @notice Updates the treasury destination used for recovery flows.
     * @dev Governance can rotate the treasury after standard non-zero and treasury-address validation passes.
     * @param _treasury New treasury address.
     * @custom:security Restricted to `GOVERNANCE_ROLE`.
     * @custom:validation Requires a non-zero address that passes treasury validation rules.
     * @custom:state-changes Replaces the stored `treasury` address.
     * @custom:events Emits `TreasuryUpdated`.
     * @custom:errors Reverts on invalid treasury addresses or missing governance role.
     * @custom:reentrancy Not applicable.
     * @custom:access Restricted to `GOVERNANCE_ROLE`.
     * @custom:oracle Not applicable.
     */
    function updateTreasury(address _treasury) external onlyRole(GOVERNANCE_ROLE) {
        if (_treasury == address(0)) revert CommonErrorLibrary.InvalidAddress();
        CommonValidationLibrary.validateNonZeroAddress(_treasury, "treasury");
        CommonValidationLibrary.validateTreasuryAddress(_treasury);

        address oldTreasury = treasury;
        treasury = _treasury;

        emit TreasuryUpdated(oldTreasury, _treasury, msg.sender);
    }

    /**
     * @notice Pauses deposits, withdrawals, redemptions, and share transfers.
     * @dev Emergency role can freeze vault interactions until the pause is lifted.
     * @custom:security Restricted to `EMERGENCY_ROLE`.
     * @custom:validation None.
     * @custom:state-changes Sets the paused state to true.
     * @custom:events Emits the inherited `Paused` event.
     * @custom:errors Reverts on missing emergency role or if already paused.
     * @custom:reentrancy Not applicable.
     * @custom:access Restricted to `EMERGENCY_ROLE`.
     * @custom:oracle Not applicable.
     */
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses deposits, withdrawals, redemptions, and share transfers.
     * @dev Emergency role can resume normal vault operation after a pause.
     * @custom:security Restricted to `EMERGENCY_ROLE`.
     * @custom:validation None.
     * @custom:state-changes Sets the paused state to false.
     * @custom:events Emits the inherited `Unpaused` event.
     * @custom:errors Reverts on missing emergency role or if the vault is not paused.
     * @custom:reentrancy Not applicable.
     * @custom:access Restricted to `EMERGENCY_ROLE`.
     * @custom:oracle Not applicable.
     */
    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }

    /**
     * @notice Forces a full emergency redemption of a user's stQEURO position.
     * @dev Emergency role can burn all of a user's shares and transfer the current redeemable QEURO balance directly to that user.
     * @param user Account whose full vault position is being unwound.
     * @custom:security Restricted to `EMERGENCY_ROLE` and protected by `nonReentrant`.
     * @custom:validation Returns early when `user` holds no shares.
     * @custom:state-changes Burns the user's full share balance and transfers corresponding QEURO assets out of the vault.
     * @custom:events Emits the standard ERC-4626 `Withdraw` event when shares are burned.
     * @custom:errors Reverts on missing emergency role or failed asset transfer.
     * @custom:reentrancy Protected by `nonReentrant`.
     * @custom:access Restricted to `EMERGENCY_ROLE`.
     * @custom:oracle Not applicable.
     */
    function emergencyWithdraw(address user) external onlyRole(EMERGENCY_ROLE) nonReentrant {
        uint256 shares = balanceOf(user);
        if (shares == 0) return;

        uint256 assets = previewRedeem(shares);
        _burn(user, shares);
        IERC20(asset()).safeTransfer(user, assets);

        emit Withdraw(msg.sender, user, user, assets, shares);
    }

    /**
     * @notice Recovers non-QEURO ERC-20 tokens mistakenly sent to the vault.
     * @dev Admin-only recovery route forwards unsupported tokens to the configured treasury and explicitly forbids recovering the underlying asset.
     * @param token ERC-20 token address to recover.
     * @param amount Amount of tokens to recover.
     * @custom:security Restricted to `DEFAULT_ADMIN_ROLE` and blocks recovery of the vault's underlying asset.
     * @custom:validation Requires `token` to differ from `asset()`.
     * @custom:state-changes Transfers the specified token amount from the vault to the treasury.
     * @custom:events Emits downstream ERC-20 `Transfer` events from the recovered token.
     * @custom:errors Reverts on invalid token selection, failed transfers, or missing admin role.
     * @custom:reentrancy Not applicable.
     * @custom:access Restricted to `DEFAULT_ADMIN_ROLE`.
     * @custom:oracle Not applicable.
     */
    function recoverToken(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == asset()) revert CommonErrorLibrary.InvalidToken();
        TreasuryRecoveryLibrary.recoverToken(token, amount, address(this), treasury);
    }

    /**
     * @notice Recovers native ETH held by the vault and forwards it to the treasury.
     * @dev Admin-only recovery route sends the contract's entire ETH balance to the configured treasury.
     * @custom:security Restricted to `DEFAULT_ADMIN_ROLE`.
     * @custom:validation Requires a configured treasury and a positive ETH balance.
     * @custom:state-changes Transfers the full native ETH balance from the vault to the treasury.
     * @custom:events Emits `ETHRecovered`.
     * @custom:errors Reverts on missing treasury, zero ETH balance, send failure, or missing admin role.
     * @custom:reentrancy Not applicable.
     * @custom:access Restricted to `DEFAULT_ADMIN_ROLE`.
     * @custom:oracle Not applicable.
     */
    function recoverETH() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (treasury == address(0)) revert CommonErrorLibrary.InvalidAddress();
        uint256 balance = address(this).balance;
        if (balance < 1) revert CommonErrorLibrary.NoETHToRecover();
        payable(treasury).sendValue(balance);
        emit ETHRecovered(treasury, balance);
    }
}
