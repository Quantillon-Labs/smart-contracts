// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IVersioned} from "../interfaces/IVersioned.sol";

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
    SecureUpgradeable,
    IVersioned
{

    /**
     * @notice Returns the semantic version of this implementation.
     * @dev Pure getter (no storage slot) read through the proxy, so it reflects the deployed
     *      implementation. Bump per semver on any change; enforced by `make check-version-bump`.
     *      See deployments/{chainId}/versions.json for the deployed impl/commit provenance.
     * @return Semantic version string (e.g. "1.0.0").
     * @custom:security No security implications - returns a compile-time constant.
     * @custom:validation No input validation required.
     * @custom:state-changes None - pure function.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable - pure function.
     * @custom:access Public - anyone can read the version.
     * @custom:oracle No oracle dependencies.
     */
    function version() external pure virtual override returns (string memory) {
        return "1.2.4";
    }
    using SafeERC20 for IERC20;
    using Address for address payable;

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    IQEUROToken public qeuro;
    address public treasury;
    string public vaultName;
    uint256 public yieldFee;

    // Appended storage for lazy linear vesting of unsolicited/harvested QEURO yield.
    uint256 private accountedBalance;
    uint256 private unvestedBalance;
    uint64 private vestingEnd;
    uint64 private lastVestingUpdate;
    uint32 public vestingPeriod;
    bool private vestingInitialized;

    TimeProvider public immutable TIME_PROVIDER;

    event YieldParametersUpdated(uint256 yieldFee);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury, address indexed caller);
    event ETHRecovered(address indexed to, uint256 indexed amount);
    /// @notice Emitted when the rounding residue left by the final exit is swept to its receiver
    event ResidualSwept(address indexed receiver, uint256 amount);
    event VestingPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);
    event YieldVestingSynced(uint256 vested, uint256 unvested, uint256 accounted);

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
     * @notice Returns canonical protocol time from this contract's TimeProvider
     * @dev Overrides the SecureUpgradeable base, which returns `block.timestamp`.
     * @return Canonical protocol time in seconds
     * @custom:security Reads the immutable TimeProvider set at construction
     * @custom:validation None required
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Read-only helper; no state mutation
     * @custom:access Internal helper
     * @custom:oracle No oracle dependencies
     */
    function _protocolTime() internal view override returns (uint256) {
        return TIME_PROVIDER.currentTime();
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
        vestingPeriod = 1 days;
        vestingInitialized = true;
        lastVestingUpdate = uint64(_protocolTime());
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
     * @notice Returns only principal and the currently vested portion of yield.
     * @dev Unvested underlying remains excluded from ERC-4626 share pricing.
     * @return assets Accounted assets available to share holders.
     * @custom:security Prevents a new depositor from immediately capturing harvested yield.
     * @custom:validation None; the raw underlying balance caps the result.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public view.
     * @custom:oracle No oracle dependency.
     */
    function totalAssets() public view override returns (uint256 assets) {
        uint256 rawBalance = IERC20(asset()).balanceOf(address(this));
        if (!vestingInitialized) return rawBalance;
        uint256 vested = _vestedBalanceView();
        uint256 accounted = accountedBalance + vested;
        assets = accounted < rawBalance ? accounted : rawBalance;
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
        _syncVestingAccounting();
        shares = super.deposit(assets, receiver);
        accountedBalance += assets;
        if (shares == 0 || previewRedeem(shares) < assets - assets / 10_000) {
            revert CommonErrorLibrary.InvalidAmount();
        }
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
        _syncVestingAccounting();
        assets = super.mint(shares, receiver);
        accountedBalance += assets;
        if (shares == 0 || previewRedeem(shares) < assets - assets / 10_000) {
            revert CommonErrorLibrary.InvalidAmount();
        }
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
        _syncVestingAccounting();
        shares = super.withdraw(assets, receiver, owner);
        if (assets > accountedBalance) revert CommonErrorLibrary.InvalidAmount();
        accountedBalance -= assets;
        _sweepResidualOnEmpty(receiver);
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
        _syncVestingAccounting();
        assets = super.redeem(shares, receiver, owner);
        if (assets > accountedBalance) revert CommonErrorLibrary.InvalidAmount();
        accountedBalance -= assets;
        assets += _sweepResidualOnEmpty(receiver);
    }

    /**
     * @notice Clears remaining QEURO after the final share exit.
     * @dev Returns up to 1e12 wei of rounding dust to the receiver and sends excess to treasury.
     * @param receiver Address that receives the swept residue (same receiver as the exit).
     * @return residual Amount of QEURO swept (0 when shares remain or nothing is left).
     * @custom:security Only reachable from `nonReentrant` exit paths; QEURO has no transfer hooks.
     * @custom:validation No-op unless the share supply is exactly zero.
     * @custom:state-changes Transfers bounded dust to receiver and excess to treasury.
     * @custom:events Emits `ResidualSwept` when a nonzero residue is transferred.
     * @custom:errors Reverts only if the underlying QEURO transfer fails.
     * @custom:reentrancy Callers hold the `nonReentrant` guard.
     * @custom:access Internal helper only.
     * @custom:oracle Not applicable.
     */
    function _sweepResidualOnEmpty(address receiver) private returns (uint256 residual) {
        if (totalSupply() != 0) return 0;
        IERC20 assetToken = IERC20(asset());
        uint256 balance = assetToken.balanceOf(address(this));
        uint256 vestedResidual = balance > unvestedBalance ? balance - unvestedBalance : 0;
        residual = vestedResidual > 1e12 ? 1e12 : vestedResidual;
        if (residual > 0) {
            assetToken.safeTransfer(receiver, residual);
            emit ResidualSwept(receiver, residual);
        }
        if (balance > residual) {
            assetToken.safeTransfer(treasury, balance - residual);
            emit ResidualSwept(treasury, balance - residual);
        }
        accountedBalance = 0;
        unvestedBalance = 0;
        vestingEnd = 0;
        lastVestingUpdate = uint64(_protocolTime());
    }

    /**
     * @notice Records a new governance-selected vesting period.
     * @dev Synchronizes already-observed yield before changing the period used for future surplus.
     * @param newPeriod Seconds over which newly observed yield vests (1 day to 30 days).
     * @custom:security Restricted to governance.
     * @custom:validation Rejects periods outside the bounded safety range.
     * @custom:state-changes Updates the future yield vesting period.
     * @custom:events Emits `VestingPeriodUpdated`.
     * @custom:errors ConfigValueTooLow or ConfigValueTooHigh.
     * @custom:reentrancy Not applicable.
     * @custom:access Governance role.
     * @custom:oracle No oracle dependency.
     */
    function setVestingPeriod(uint256 newPeriod) external onlyRole(GOVERNANCE_ROLE) {
        if (newPeriod < 1 days) revert CommonErrorLibrary.ConfigValueTooLow();
        if (newPeriod > 30 days) revert CommonErrorLibrary.ConfigValueTooHigh();
        _syncVestingAccounting();
        uint256 oldPeriod = vestingPeriod;
        vestingPeriod = uint32(newPeriod);
        emit VestingPeriodUpdated(oldPeriod, newPeriod);
    }

    /**
     * @notice Materializes currently vested yield and records newly observed surplus.
     * @dev Permissionless during normal operation; governance may also sync during paused upgrades.
     * @custom:security Paused maintenance requires governance authorization.
     * @custom:validation Underlying balance deltas are bounded by the token balance.
     * @custom:state-changes Updates principal, unvested yield, and vesting timestamps.
     * @custom:events Emits `YieldVestingSynced`.
     * @custom:errors AccessControlUnauthorizedAccount for non-governance callers while paused.
     * @custom:reentrancy Protected by `nonReentrant`.
     * @custom:access Public when unpaused; GOVERNANCE_ROLE while paused.
     * @custom:oracle No oracle dependency.
     */
    function syncVesting() external nonReentrant {
        if (paused()) _checkRole(GOVERNANCE_ROLE);
        _syncVestingAccounting();
    }

    function _syncVestingAccounting() private {
        uint256 nowTime = _protocolTime();
        uint256 rawBalance = IERC20(asset()).balanceOf(address(this));
        if (!vestingInitialized) {
            vestingInitialized = true;
            if (vestingPeriod == 0) vestingPeriod = 1 days;
            accountedBalance = rawBalance;
            lastVestingUpdate = uint64(nowTime);
            emit YieldVestingSynced(0, 0, rawBalance);
            return;
        }

        uint256 vested = _vestedBalanceView();
        if (vested > 0) {
            accountedBalance += vested;
            unvestedBalance -= vested;
        }
        lastVestingUpdate = uint64(nowTime);
        if (unvestedBalance == 0) vestingEnd = 0;

        uint256 tracked = accountedBalance + unvestedBalance;
        if (rawBalance > tracked) {
            uint256 surplus = rawBalance - tracked;
            uint256 newEnd = nowTime + vestingPeriod;
            if (unvestedBalance == 0) {
                unvestedBalance = surplus;
                vestingEnd = uint64(newEnd);
            } else {
                uint256 weightedEnd = (unvestedBalance * uint256(vestingEnd) + surplus * newEnd)
                    / (unvestedBalance + surplus);
                unvestedBalance += surplus;
                vestingEnd = uint64(weightedEnd);
            }
        } else if (rawBalance < tracked) {
            uint256 shortfall = tracked - rawBalance;
            if (shortfall >= unvestedBalance) {
                shortfall -= unvestedBalance;
                unvestedBalance = 0;
                vestingEnd = 0;
                accountedBalance = shortfall >= accountedBalance ? 0 : accountedBalance - shortfall;
            } else {
                unvestedBalance -= shortfall;
            }
        }
        emit YieldVestingSynced(vested, unvestedBalance, accountedBalance);
    }

    function _vestedBalanceView() private view returns (uint256 vested) {
        if (unvestedBalance == 0) return 0;
        uint256 nowTime = _protocolTime();
        if (nowTime >= vestingEnd || vestingEnd <= lastVestingUpdate) return unvestedBalance;
        vested = unvestedBalance * (nowTime - lastVestingUpdate) / (uint256(vestingEnd) - lastVestingUpdate);
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

        _syncVestingAccounting();
        uint256 assets = previewRedeem(shares);
        accountedBalance -= assets;
        _burn(user, shares);
        IERC20(asset()).safeTransfer(user, assets);
        emit Withdraw(msg.sender, user, user, assets, shares);
        _sweepResidualOnEmpty(user);
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
