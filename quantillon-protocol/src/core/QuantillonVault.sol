// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// =============================================================================
// IMPORTS - OpenZeppelin security and features
// =============================================================================

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {SecureUpgradeable} from "./SecureUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {CommonErrorLibrary} from "../libraries/CommonErrorLibrary.sol";
import {CommonValidationLibrary} from "../libraries/CommonValidationLibrary.sol";
import {VaultErrorLibrary} from "../libraries/VaultErrorLibrary.sol";
import {HedgerPoolErrorLibrary} from "../libraries/HedgerPoolErrorLibrary.sol";

// Internal interfaces of the Quantillon protocol
import {IQEUROToken} from "../interfaces/IQEUROToken.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {IHedgerPool} from "../interfaces/IHedgerPool.sol";
import {IUserPool} from "../interfaces/IUserPool.sol";
import {IExternalStakingVault} from "../interfaces/IExternalStakingVault.sol";
import {IStQEUROFactory} from "../interfaces/IStQEUROFactory.sol";
import {IstQEURO} from "../interfaces/IstQEURO.sol";
import {FeeCollector} from "./FeeCollector.sol";
import {VaultMath} from "../libraries/VaultMath.sol";
import {TreasuryRecoveryLibrary} from "../libraries/TreasuryRecoveryLibrary.sol";
import {FlashLoanProtectionLibrary} from "../libraries/FlashLoanProtectionLibrary.sol";
import {PriceValidationLibrary} from "../libraries/PriceValidationLibrary.sol";

/**
 * @title QuantillonVault
 * @notice Main vault managing QEURO minting against USDC collateral
 * 
 * @dev Main characteristics:
 *      - Simple USDC to QEURO swap mechanism
 *      - USDC as input for QEURO minting
 *      - Real-time EUR/USD price oracle integration
 *      - Dynamic fee structure for protocol sustainability
 *      - Emergency pause mechanism for crisis situations
 *      - Upgradeable via UUPS pattern
 * 
 * @dev Minting mechanics:
 *      - Users swap USDC for QEURO
 *      - QEURO is minted based on EUR/USD exchange rate
 *      - Minting fees charged for protocol revenue
 *      - Simple 1:1 exchange with price conversion
 *      - Price deviation protection prevents flash loan manipulation
 *      - Block-based validation ensures price freshness
 * 
 * @dev Redemption mechanics:
 *      - Users can redeem QEURO back to USDC
 *      - Redemption based on current EUR/USD exchange rate
 *      - Protocol fees charged on redemptions
 *      - USDC returned to user after fee deduction
 *      - Same price deviation protection as minting
 *      - Consistent security across all operations
 * 
 * @dev Risk management:
 *      - Real-time price monitoring
 *      - Emergency pause capabilities
 *      - Slippage protection on swaps
 *      - Flash loan attack prevention via price deviation checks
 *      - Block-based price manipulation detection
 *      - Comprehensive oracle validation and fallback mechanisms
 * 
 * @dev Fee structure:
 *      - Minting fees for creating QEURO
 *      - Redemption fees for converting QEURO back to USDC
 *      - Dynamic fee adjustment based on market conditions
 * 
 * @dev Security features:
 *      - Role-based access control for all critical operations
 *      - Reentrancy protection for all external calls
 *      - Emergency pause mechanism for crisis situations
 *      - Upgradeable architecture for future improvements
 *      - Secure collateral management
 *      - Oracle price validation
 *      - Flash loan protection through price deviation checks
 *      - Block-based price update validation
 *      - Comprehensive price manipulation attack prevention
 * 
 * @dev Integration points:
 *      - QEURO token for minting and burning
 *      - USDC for collateral deposits and withdrawals
 *      - Chainlink oracle for EUR/USD price feeds
 *      - Vault math library for precise calculations
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract QuantillonVault is 
    Initializable,
    ReentrancyGuardUpgradeable,    // Reentrancy protection
    AccessControlUpgradeable,      // Role management
    PausableUpgradeable,          // Emergency pause
    SecureUpgradeable             // Secure upgrade pattern
{
    using SafeERC20 for IERC20;
    using Address for address payable;
    using VaultMath for uint256;   // Precise math operations

    // =============================================================================
    // CONSTANTS - Roles and identifiers
    // =============================================================================
    
    /// @notice Role for governance operations (parameter updates, emergency actions)
    /// @dev keccak256 hash avoids role collisions with other contracts
    /// @dev Should be assigned to governance multisig or DAO
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    

    
    /// @notice Role for emergency operations (pause)
    /// @dev keccak256 hash avoids role collisions with other contracts
    /// @dev Should be assigned to emergency multisig
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    /// @notice Role for vault operators (UserPool) to trigger Aave deployments
    /// @dev keccak256 hash avoids role collisions with other contracts
    /// @dev Should be assigned to UserPool contract
    bytes32 public constant VAULT_OPERATOR_ROLE = keccak256("VAULT_OPERATOR_ROLE");
    


    // =============================================================================
    // CONSTANTS - Emergency and security parameters
    // =============================================================================
    
    /// @notice Maximum allowed price deviation between consecutive price updates (in basis points)
    /// @dev Prevents flash loan price manipulation attacks
    /// @dev 200 basis points = 2% maximum deviation
    uint256 private constant MAX_PRICE_DEVIATION = 200; // 2%
    
    /// @notice Minimum number of blocks required between price updates for deviation checks
    /// @dev Prevents manipulation within the same block
    uint256 private constant MIN_BLOCKS_BETWEEN_UPDATES = 1;
    
    // Collateralization ratio constants
    // Fixes Slither ID-31-34: Replace magic numbers with named constants
    uint256 private constant MIN_COLLATERALIZATION_RATIO_FOR_MINTING = 105e18; // 105.000000% (18 decimals)
    uint256 private constant CRITICAL_COLLATERALIZATION_RATIO_BPS = 10100; // 101.000000% (basis points)
    uint256 private constant MIN_ALLOWED_COLLATERALIZATION_RATIO = 101e18; // 101.000000% - minimum allowed value (18 decimals)
    uint256 private constant MIN_ALLOWED_CRITICAL_RATIO = 100e18; // 100.000000% - minimum allowed critical ratio (18 decimals)


    // =============================================================================
    // STATE VARIABLES - External contracts and configuration
    // =============================================================================
    
    /// @notice QEURO token contract for minting and burning
    /// @dev Used for all QEURO minting and burning operations
    /// @dev Should be the official QEURO token contract
    IQEUROToken public qeuro;
    
    /// @notice USDC token used as collateral
    /// @dev Used for all collateral deposits, withdrawals, and fee payments
    /// @dev Should be the official USDC contract on the target network
    IERC20 public usdc;
    
    /// @notice Oracle contract for EUR/USD price feeds (Chainlink or Stork via router)
    /// @dev Provides real-time EUR/USD exchange rates for minting and redemption
    /// @dev Used for price calculations in swap operations
    IOracle public oracle;

    /// @notice HedgerPool contract for collateralization checks
    /// @dev Used to verify protocol has sufficient hedging positions before minting QEURO
    /// @dev Ensures protocol is properly collateralized by hedgers
    IHedgerPool public hedgerPool;
    
    /// @notice UserPool contract for user deposit tracking
    /// @dev Used to get total user deposits for collateralization ratio calculations
    /// @dev Required for accurate protocol collateralization assessment
    IUserPool public userPool;

    /// @notice Treasury address for ETH recovery
    /// @dev SECURITY: Only this address can receive ETH from recoverETH function
    address public treasury;
    
    /// @notice Fee collector contract for protocol fees
    /// @dev Centralized fee collection and distribution
    address public feeCollector;

    /// @notice USDC balance before flash loan check (used by flashLoanProtection modifier)
    uint256 private _flashLoanBalanceBefore;

    /// @notice Default vault id used for automatic deployment after minting.
    uint256 public defaultStakingVaultId;

    /// @notice Total principal deployed across all external staking vaults.
    uint256 public totalUsdcInExternalVaults;

    /// @notice External staking vault adapter by vault id.
    mapping(uint256 => IExternalStakingVault) private stakingVaultAdapterById;

    /// @notice Tracked principal deployed to each external staking vault.
    mapping(uint256 => uint256) private principalUsdcByVaultId;

    /// @notice Active flag for configured external staking vault ids.
    mapping(uint256 => bool) private stakingVaultActiveById;

    /// @notice Ordered list of active vault ids used for redemption liquidity sourcing.
    uint256[] private redemptionPriorityVaultIds;

    /// @notice stQEURO factory used to register this vault's staking token.
    address public stQEUROFactory;

    /// @notice stQEURO token address registered per vault id.
    mapping(uint256 => address) public stQEUROTokenByVaultId;

    struct LiquidationCommitParams {
        address redeemer;
        uint256 qeuroAmount;
        uint256 totalSupply;
        uint256 usdcPayout;
        uint256 netUsdcPayout;
        uint256 fee;
        uint256 collateralizationRatioBps;
        bool isPremium;
        uint256 externalWithdrawalAmount;
    }

    // Protocol parameters (configurable by governance)
    
    /// @notice Protocol fee charged on minting QEURO
    /// @dev INFO-7: Fee denominated in 1e18 precision — 1e16 = 1%, 1e18 = 100% (NOT basis points)
    /// @dev Revenue source for the protocol
    uint256 public mintFee;

    /// @notice Protocol fee charged on redeeming QEURO
    /// @dev INFO-7: Fee denominated in 1e18 precision — 1e16 = 1%, 1e18 = 100% (NOT basis points)
    /// @dev Revenue source for the protocol
    uint256 public redemptionFee;

    /// @notice Share of protocol fees routed to HedgerPool reward reserve (1e18 = 100%)
    uint256 public hedgerRewardFeeSplit;

    /// @notice Maximum value allowed for hedgerRewardFeeSplit
    uint256 private constant MAX_HEDGER_REWARD_FEE_SPLIT = 1e18;

    // INFO-3: TAKES_FEES_DURING_LIQUIDATION was a named constant for the immutable value `true`.
    //         Replaced with inline logic throughout to remove the misleading implication
    //         that this value is configurable by governance.

    // Collateralization parameters (configurable by governance)
    
    /// @notice Minimum collateralization ratio required for minting QEURO (in 1e18 precision, NOT basis points)
    /// @dev INFO-7: Example: 105000000000000000000 = 105% collateralization ratio required for minting
    /// @dev When protocol collateralization >= this threshold, minting is allowed
    /// @dev When protocol collateralization < this threshold, minting is halted
    /// @dev Can be updated by governance to adjust protocol risk parameters
    /// @dev Stored in 18 decimals format (e.g., 105000000000000000000 = 105.000000%)
    uint256 public minCollateralizationRatioForMinting;
    
    /// @notice Critical collateralization ratio that triggers liquidation (in 18 decimals)
    /// @dev Example: 101000000000000000000 = 101.000000% collateralization ratio triggers liquidation
    /// @dev When protocol collateralization < this threshold, hedgers start being liquidated
    /// @dev Emergency threshold to protect protocol solvency
    /// @dev Can be updated by governance to adjust liquidation triggers
    /// @dev Stored in 18 decimals format (e.g., 101000000000000000000 = 101.000000%)
    uint256 public criticalCollateralizationRatio;

    // Global vault state
    
    /// @notice Total USDC held in the vault
    /// @dev Used for vault analytics and risk management
    uint256 public totalUsdcHeld;
    
    /// @notice Total QEURO in circulation (minted by this vault)
    uint256 public totalMinted;

    // Price tracking for flash loan protection
    
    /// @notice Last valid EUR/USD price used in operations
    /// @dev Used for price deviation checks to prevent manipulation
    uint256 private lastValidEurUsdPrice;
    
    /// @notice Block number of the last price update
    /// @dev Used to ensure minimum blocks between updates for deviation checks
    uint256 private lastPriceUpdateBlock;

    /// @notice Dev mode flag to disable price caching requirements
    /// @dev When enabled, price deviation checks and caching requirements are skipped (dev/testing only)
    bool public devModeEnabled;

    /// @notice MED-1: Minimum delay before a proposed dev-mode change takes effect
    uint256 private constant DEV_MODE_DELAY = 48 hours;
    /// @notice MED-1: Canonical block delay for dev-mode proposals (12s block target)
    uint256 private constant DEV_MODE_DELAY_BLOCKS = DEV_MODE_DELAY / 12;

    /// @notice MED-1: Pending dev-mode value awaiting the timelock delay
    bool public pendingDevMode;

    /// @notice MED-1: Block at which pendingDevMode may be applied (0 = no pending proposal)
    uint256 public devModePendingAt;

    // =============================================================================
    // EVENTS - Events for tracking and monitoring
    // =============================================================================
    
    /// @notice Emitted when QEURO is minted
    event QEUROminted(
        address indexed user, 
        uint256 usdcAmount, 
        uint256 qeuroAmount
    );
    
    /// @notice Emitted when QEURO is redeemed
    event QEURORedeemed(
        address indexed user, 
        uint256 qeuroAmount, 
        uint256 usdcAmount
    );
    
    /// @notice Emitted when QEURO is redeemed in liquidation mode (pro-rata)
    /// @param user Address of the user redeeming QEURO
    /// @param qeuroAmount Amount of QEURO redeemed (18 decimals)
    /// @param usdcPayout Amount of USDC received (6 decimals)
    /// @param collateralizationRatioBps Protocol CR at redemption time (basis points)
    /// @param isPremium True if user received more than fair value (CR > 100%)
    event LiquidationRedeemed(
        address indexed user,
        uint256 qeuroAmount,
        uint256 usdcPayout,
        uint256 collateralizationRatioBps,
        bool isPremium
    );
    
    /// @notice LOW-3: Emitted when notifying HedgerPool of a liquidation redemption fails
    /// @param qeuroAmount Amount of QEURO that was being redeemed
    event HedgerPoolNotificationFailed(uint256 qeuroAmount);

    /// @notice Emitted when hedger deposits USDC to vault for unified liquidity
    /// @param hedgerPool Address of the HedgerPool contract that made the deposit
    /// @param usdcAmount Amount of USDC deposited (6 decimals)
    /// @param totalUsdcHeld New total USDC held in vault after deposit (6 decimals)
    event HedgerDepositAdded(
        address indexed hedgerPool,
        uint256 usdcAmount,
        uint256 totalUsdcHeld
    );
    
    /// @notice Emitted when hedger withdraws USDC from vault
    /// @param hedger Address of the hedger receiving the USDC
    /// @param usdcAmount Amount of USDC withdrawn (6 decimals)
    /// @param totalUsdcHeld New total USDC held in vault after withdrawal (6 decimals)
    event HedgerDepositWithdrawn(
        address indexed hedger,
        uint256 usdcAmount,
        uint256 totalUsdcHeld
    );
    
    /// @notice Emitted when parameters are changed
    /// @dev OPTIMIZED: Indexed parameter type for efficient filtering
    event ParametersUpdated(
        string indexed parameterType,
        uint256 mintFee, 
        uint256 redemptionFee
    );
    
    /// @notice Emitted when price deviation protection is triggered
    /// @dev Helps monitor potential flash loan attacks
    
    /// @notice Emitted when collateralization thresholds are updated by governance
    /// @param minCollateralizationRatioForMinting New minimum collateralization ratio for minting (in 18 decimals)
    /// @param criticalCollateralizationRatio New critical collateralization ratio for liquidation (in 18 decimals)
    /// @param caller Address of the governance role holder who updated the thresholds
    event CollateralizationThresholdsUpdated(
        uint256 indexed minCollateralizationRatioForMinting,
        uint256 indexed criticalCollateralizationRatio,
        address indexed caller
    );
    
    /// @notice Emitted when protocol collateralization status changes
    /// @param currentRatio Current protocol collateralization ratio (in basis points)
    /// @param canMint Whether minting is currently allowed based on collateralization
    /// @param shouldLiquidate Whether liquidation should be triggered based on collateralization
    event CollateralizationStatusChanged(
        uint256 indexed currentRatio,
        bool indexed canMint,
        bool indexed shouldLiquidate
    );
    event PriceDeviationDetected(
        uint256 currentPrice,
        uint256 lastValidPrice,
        uint256 deviationBps,
        uint256 blockNumber
    );
    
    /// @notice Emitted when price cache is manually updated by governance
    /// @param oldPrice Previous cached price
    /// @param newPrice New cached price
    /// @param blockNumber Block number when cache was updated
    event PriceCacheUpdated(
        uint256 oldPrice,
        uint256 newPrice,
        uint256 blockNumber
    );

    /// @notice Emitted when dev mode is toggled
    /// @param enabled Whether dev mode is enabled or disabled
    /// @param caller Address that triggered the toggle
    event DevModeToggled(bool enabled, address indexed caller);

    /// @notice MED-1: Emitted when a dev-mode change is proposed
    /// @param pending The proposed dev-mode value
    /// @param activatesAt Timestamp at which the change can be applied
    event DevModeProposed(bool pending, uint256 activatesAt);

    /// @notice Emitted when an external staking vault adapter is configured.
    event StakingVaultConfigured(uint256 indexed vaultId, address indexed adapter, bool active);
    event DefaultStakingVaultUpdated(uint256 indexed previousVaultId, uint256 indexed newVaultId);
    event RedemptionPriorityUpdated(uint256[] vaultIds);
    event StQEURORegistered(
        address indexed factory,
        uint256 indexed vaultId,
        address indexed stQEUROToken,
        string vaultName
    );

    event UsdcDeployedToExternalVault(uint256 indexed vaultId, uint256 indexed usdcAmount, uint256 principalInVault);
    event ExternalVaultYieldHarvested(uint256 indexed vaultId, uint256 harvestedYield);
    event ExternalVaultDeploymentFailed(uint256 indexed vaultId, uint256 amount, bytes reason);
    event HedgerSyncFailed(string operation, uint256 amount, uint256 price, bytes reason);

    event UsdcWithdrawnFromExternalVault(uint256 indexed vaultId, uint256 indexed usdcAmount, uint256 principalInVault);
    event HedgerRewardFeeSplitUpdated(uint256 previousSplit, uint256 newSplit);
    event ProtocolFeeRouted(string sourceType, uint256 totalFee, uint256 hedgerReserveShare, uint256 collectorShare);

    struct MintCommitPayload {
        address payer;
        address qeuroRecipient;
        uint256 usdcAmount;
        uint256 fee;
        uint256 netAmount;
        uint256 qeuroToMint;
        uint256 eurUsdPrice;
        bool isValidPrice;
        uint256 targetVaultId;
    }

    struct RedeemCommitPayload {
        address redeemer;
        uint256 qeuroAmount;
        uint256 usdcToReturn;
        uint256 netUsdcToReturn;
        uint256 fee;
        uint256 eurUsdPrice;
        bool isValidPrice;
        uint256 externalWithdrawalAmount;
    }

    // =============================================================================
    // MODIFIERS - Access control and security
    // =============================================================================

    /**
     * @notice Modifier to protect against flash loan attacks
     * @dev Uses the FlashLoanProtectionLibrary to check USDC balance consistency
     */
    modifier flashLoanProtection() {
        _flashLoanProtectionBefore();
        _;
        _flashLoanProtectionAfter();
    }

    modifier onlySelf() {
        _onlySelf();
        _;
    }

    /**
     * @notice Reverts unless caller is this contract.
     * @dev Internal guard used by `onlySelf` for explicit self-call commit functions.
     * @custom:security Prevents direct external invocation of commit-phase helpers.
     * @custom:validation Requires `msg.sender == address(this)`.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Reverts with `NotAuthorized` when caller is not self.
     * @custom:reentrancy No external calls.
     * @custom:access Internal helper used by modifier.
     * @custom:oracle No oracle dependencies.
     */
    function _onlySelf() internal view {
        if (msg.sender != address(this)) revert CommonErrorLibrary.NotAuthorized();
    }

    function _flashLoanProtectionBefore() private {
        _flashLoanBalanceBefore = usdc.balanceOf(address(this));
    }

    function _flashLoanProtectionAfter() private view {
        uint256 balanceAfter = usdc.balanceOf(address(this));
        if (!FlashLoanProtectionLibrary.validateBalanceChange(_flashLoanBalanceBefore, balanceAfter, 0)) {
            revert HedgerPoolErrorLibrary.FlashLoanAttackDetected();
        }
    }

    // =============================================================================
    // INITIALIZER - Initial vault configuration
    // =============================================================================

    /**
     * @notice Constructor for QuantillonVault contract
     * @dev Disables initializers for security
     * @custom:security Disables initializers for security
     * @custom:validation No validation needed
     * @custom:state-changes Disables initializers
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access No access restrictions
     * @custom:oracle No oracle dependencies
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the vault with contracts and parameters
     * 
     * @param admin Address with administrator privileges
     * @param _qeuro Address of the QEURO token contract
     * @param _usdc Address of the USDC token contract
     * @param _oracle Address of the Oracle contract
     * @param _hedgerPool Address of the HedgerPool contract
     * @param _userPool Address of the UserPool contract
     * @param _timelock Address of the timelock contract
     * @param _feeCollector Address of the fee collector contract
     * 
     * @dev This function configures:
     *      1. Access roles
     *      2. References to external contracts
     *      3. Default protocol parameters
     *      4. Security (pause, reentrancy, upgrades)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Initializes all contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to initializer modifier
     * @custom:oracle No oracle dependencies
     */
    function initialize(
        address admin,
        address _qeuro,
        address _usdc,
        address _oracle,
        address _hedgerPool,
        address _userPool,
        address _timelock,
        address _feeCollector
    ) public initializer {
        // Validation of critical parameters
        if (admin == address(0)) revert CommonErrorLibrary.ZeroAddress();
        if (_qeuro == address(0)) revert CommonErrorLibrary.InvalidToken();
        if (_usdc == address(0)) revert CommonErrorLibrary.InvalidToken();
        if (_oracle == address(0)) revert CommonErrorLibrary.InvalidOracle();
        // Note: HedgerPool and UserPool can be zero during initialization, but must be set before minting
        if (_timelock == address(0)) revert CommonErrorLibrary.ZeroAddress();
        if (_feeCollector == address(0)) revert CommonErrorLibrary.ZeroAddress();

        // Initialization of security modules
        __ReentrancyGuard_init();     // Reentrancy protection
        __AccessControl_init();        // Role system
        __Pausable_init();            // Pause mechanism
        __SecureUpgradeable_init(_timelock); // Secure upgrades

        // Configuration of access roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);

        // Connections to external contracts
        qeuro = IQEUROToken(_qeuro);
        usdc = IERC20(_usdc);
        oracle = IOracle(_oracle);
        // HedgerPool and UserPool can be set later via update functions if addresses are zero
        if (_hedgerPool != address(0)) {
            hedgerPool = IHedgerPool(_hedgerPool);
        }
        if (_userPool != address(0)) {
            userPool = IUserPool(_userPool);
        }
        treasury = _timelock; // Set treasury to timelock
        feeCollector = _feeCollector; // Set fee collector

        // Default protocol parameters (fees start at 0, can be set via admin panel)
        mintFee = 0;
        redemptionFee = 0;
        hedgerRewardFeeSplit = 2e17; // 20%
        
        // Default collateralization parameters (in 18 decimals format for maximum precision)
        minCollateralizationRatioForMinting = MIN_COLLATERALIZATION_RATIO_FOR_MINTING;  // 105.000000% - minimum ratio for minting
        // Convert bps to protocol ratio format where 100% = 1e20.
        // 10100 bps => 10100 * 1e16 = 101000000000000000000 (101%)
        criticalCollateralizationRatio = CRITICAL_COLLATERALIZATION_RATIO_BPS * 1e16;
        
        // Initialize price tracking for flash loan protection
        lastValidEurUsdPrice = 0;       // Will be set on first price fetch
        lastPriceUpdateBlock = block.number;
    }


    // =============================================================================
    // CORE FUNCTIONS - Main mint/redeem functions
    // =============================================================================

    /**
     * @notice Mints QEURO tokens by swapping USDC
     * 
     * @param usdcAmount Amount of USDC to swap for QEURO
     * @param minQeuroOut Minimum amount of QEURO expected (slippage protection)
     * 
     * @dev Minting process:
     *      1. Fetch EUR/USD price from oracle
     *      2. Calculate amount of QEURO to mint
     *      3. Transfer USDC from user
     *      4. Update vault balances
     *      5. Mint QEURO to user
     * 
     * @dev Example: 1100 USDC → ~1000 QEURO (if EUR/USD = 1.10)
     *      Simple swap with protocol fee applied
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access No access restrictions
     * @custom:oracle Requires fresh oracle price data
     */
    // SECURITY: Protected by nonReentrant modifier; external calls to trusted Oracle contract
    function mintQEURO(
        uint256 usdcAmount,
        uint256 minQeuroOut
    ) external nonReentrant whenNotPaused flashLoanProtection {
        _mintQEUROFlow(msg.sender, msg.sender, usdcAmount, minQeuroOut, defaultStakingVaultId);
    }

    /**
     * @notice Mints QEURO and routes deployed USDC to a specific external vault id.
     * @dev Same mint flow as `mintQEURO`, but with explicit target vault routing.
     * @param usdcAmount Amount of USDC provided by caller (6 decimals).
     * @param minQeuroOut Minimum acceptable QEURO output (18 decimals).
     * @param vaultId Target staking vault id (0 disables auto-deploy routing).
     * @custom:security Protected by pause and reentrancy guards.
     * @custom:validation Reverts on invalid routing id, slippage, oracle, or collateral checks.
     * @custom:state-changes Updates mint accounting, fee routing, and optional external vault principal.
     * @custom:events Emits mint and vault deployment events in downstream flow.
     * @custom:errors Reverts on invalid inputs, oracle/CR checks, or integration failures.
     * @custom:reentrancy Guarded by `nonReentrant`.
     * @custom:access Public.
     * @custom:oracle Requires valid oracle reads in mint flow.
     */
    function mintQEUROToVault(
        uint256 usdcAmount,
        uint256 minQeuroOut,
        uint256 vaultId
    ) external nonReentrant whenNotPaused flashLoanProtection {
        _mintQEUROFlow(msg.sender, msg.sender, usdcAmount, minQeuroOut, vaultId);
    }

    /**
     * @notice Mints QEURO then stakes it into the stQEURO token for the selected vault id.
     * @dev Executes mint flow to this contract, stakes into `stQEUROTokenByVaultId[vaultId]`, then transfers stQEURO to caller.
     * @param usdcAmount Amount of USDC provided by caller (6 decimals).
     * @param minQeuroOut Minimum acceptable QEURO output from mint (18 decimals).
     * @param vaultId Target staking vault id used for routing and stQEURO token selection.
     * @param minStQEUROOut Minimum acceptable stQEURO output from staking.
     * @return qeuroMinted QEURO minted before staking.
     * @return stQEUROMinted stQEURO minted and sent to caller.
     * @custom:security Protected by pause and reentrancy guards.
     * @custom:validation Reverts on invalid vault id/token, slippage, and staking failures.
     * @custom:state-changes Updates mint accounting, optional external deployment, and stQEURO balances.
     * @custom:events Emits mint/deployment events and staking token events downstream.
     * @custom:errors Reverts on mint, routing, approval, staking, or transfer failures.
     * @custom:reentrancy Guarded by `nonReentrant`.
     * @custom:access Public.
     * @custom:oracle Requires valid oracle reads in mint flow.
     */
    function mintAndStakeQEURO(
        uint256 usdcAmount,
        uint256 minQeuroOut,
        uint256 vaultId,
        uint256 minStQEUROOut
    ) external nonReentrant whenNotPaused flashLoanProtection returns (uint256 qeuroMinted, uint256 stQEUROMinted) {
        qeuroMinted = _mintQEUROFlow(msg.sender, address(this), usdcAmount, minQeuroOut, vaultId);

        address stToken = stQEUROTokenByVaultId[vaultId];
        if (stToken == address(0)) revert CommonErrorLibrary.InvalidVault();
        IERC20(address(qeuro)).safeIncreaseAllowance(stToken, qeuroMinted);
        stQEUROMinted = IstQEURO(stToken).stake(qeuroMinted);
        if (stQEUROMinted < minStQEUROOut) revert CommonErrorLibrary.ExcessiveSlippage();

        IERC20(stToken).safeTransfer(msg.sender, stQEUROMinted);
    }

    /**
     * @notice Shared mint pipeline used by mint entrypoints.
     * @dev Validates routing/oracle/collateral constraints, computes outputs, then dispatches commit phase.
     * @param payer Address funding the USDC transfer.
     * @param qeuroRecipient Address receiving minted QEURO.
     * @param usdcAmount Amount of USDC provided (6 decimals).
     * @param minQeuroOut Minimum acceptable QEURO output (18 decimals).
     * @param targetVaultId Vault id to auto-deploy net USDC principal into (0 disables routing).
     * @return qeuroToMint Final QEURO amount to mint.
     * @custom:security Enforces protocol collateralization, price deviation, and vault routing checks.
     * @custom:validation Reverts on invalid addresses/amounts, invalid routing, or failed risk checks.
     * @custom:state-changes Performs no direct writes until commit dispatch; writes occur in commit helper.
     * @custom:events Emits no events directly; commit helper emits mint/deployment events.
     * @custom:errors Reverts on any failed validation or risk check.
     * @custom:reentrancy Called from guarded external entrypoints.
     * @custom:access Internal helper.
     * @custom:oracle Uses live oracle reads for mint pricing and checks.
     */
    function _mintQEUROFlow(
        address payer,
        address qeuroRecipient,
        uint256 usdcAmount,
        uint256 minQeuroOut,
        uint256 targetVaultId
    ) internal returns (uint256 qeuroToMint) {
        CommonValidationLibrary.validatePositiveAmount(usdcAmount);
        if (payer == address(0) || qeuroRecipient == address(0)) revert CommonErrorLibrary.InvalidAddress();
        _validateMintRouting(targetVaultId);
        (uint256 eurUsdPrice, bool isValid) = _getValidatedMintPrices();
        _enforceMintEligibility();
        _enforceMintPriceDeviation(eurUsdPrice);
        (uint256 fee, uint256 netAmount, uint256 computedQeuroToMint) =
            _computeMintAmounts(usdcAmount, eurUsdPrice, minQeuroOut);
        qeuroToMint = computedQeuroToMint;
        _enforceProjectedMintCollateralization(netAmount, qeuroToMint, eurUsdPrice);

        MintCommitPayload memory payload;
        payload.payer = payer;
        payload.qeuroRecipient = qeuroRecipient;
        payload.usdcAmount = usdcAmount;
        payload.fee = fee;
        payload.netAmount = netAmount;
        payload.qeuroToMint = qeuroToMint;
        payload.eurUsdPrice = eurUsdPrice;
        payload.isValidPrice = isValid;
        payload.targetVaultId = targetVaultId;
        _dispatchMintCommit(payload);
    }

    /**
     * @notice Dispatches mint commit through explicit self-call.
     * @dev Preserves separation between validation/read phase and commit/interactions phase.
     * @param payload Packed mint commit payload.
     * @custom:security Uses `onlySelf`-guarded commit entrypoint.
     * @custom:validation Assumes payload was prepared by validated mint flow.
     * @custom:state-changes No direct state changes in dispatcher.
     * @custom:events No direct events in dispatcher.
     * @custom:errors Propagates commit-phase revert reasons.
     * @custom:reentrancy Called from guarded parent flow.
     * @custom:access Internal helper.
     * @custom:oracle No direct oracle reads.
     */
    function _dispatchMintCommit(MintCommitPayload memory payload) internal {
        this._mintQEUROCommit(
            payload.payer,
            payload.qeuroRecipient,
            payload.usdcAmount,
            payload.fee,
            payload.netAmount,
            payload.qeuroToMint,
            payload.eurUsdPrice,
            payload.isValidPrice,
            payload.targetVaultId
        );
    }

    /**
     * @notice Validates mint routing parameters for external vault deployment.
     * @dev `targetVaultId == 0` is allowed and means no auto-deploy.
     * @param targetVaultId Vault id requested for principal deployment.
     * @custom:security Ensures routing only targets active, configured adapters.
     * @custom:validation Reverts when non-zero vault id is inactive or adapter is unset.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors Reverts with `InvalidVault` or `ZeroAddress` for invalid routing.
     * @custom:reentrancy Not applicable for view function.
     * @custom:access Internal helper.
     * @custom:oracle No oracle dependencies.
     */
    function _validateMintRouting(uint256 targetVaultId) internal view {
        if (targetVaultId == 0) return;
        if (!stakingVaultActiveById[targetVaultId]) revert CommonErrorLibrary.InvalidVault();
        if (address(stakingVaultAdapterById[targetVaultId]) == address(0)) revert CommonErrorLibrary.ZeroAddress();
    }

    /**
     * @notice Fetches and validates oracle prices required for minting.
     * @dev Reads EUR/USD and USDC/USD and verifies both are valid/non-zero.
     * @return eurUsdPrice Validated EUR/USD price.
     * @return isValid Validity flag returned by oracle for EUR/USD.
     * @custom:security Rejects invalid oracle outputs before mint accounting.
     * @custom:validation Reverts when oracle flags invalid or returns zero USDC/USD.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors Reverts with `InvalidOraclePrice`.
     * @custom:reentrancy External oracle reads only.
     * @custom:access Internal helper.
     * @custom:oracle Requires live oracle reads.
     */
    function _getValidatedMintPrices() internal returns (uint256 eurUsdPrice, bool isValid) {
        (eurUsdPrice, isValid) = oracle.getEurUsdPrice();
        if (!isValid) revert CommonErrorLibrary.InvalidOraclePrice();

        (uint256 usdcUsdPrice, bool usdcIsValid) = oracle.getUsdcUsdPrice();
        if (!usdcIsValid || usdcUsdPrice == 0) revert CommonErrorLibrary.InvalidOraclePrice();
    }

    /**
     * @notice Enforces protocol-level mint eligibility constraints.
     * @dev Requires initialized price cache, active hedger liquidity, and collateralization allowance.
     * @custom:security Prevents minting when safety prerequisites are unmet.
     * @custom:validation Reverts when cache is uninitialized, no hedger liquidity, or CR check fails.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors Reverts with protocol-specific eligibility errors.
     * @custom:reentrancy Not applicable for view helper.
     * @custom:access Internal helper.
     * @custom:oracle Uses cached state and `canMint` logic.
     */
    function _enforceMintEligibility() internal view {
        if (lastValidEurUsdPrice == 0) revert CommonErrorLibrary.NotInitialized();
        if (address(hedgerPool) == address(0) || !hedgerPool.hasActiveHedger()) {
            revert HedgerPoolErrorLibrary.NoActiveHedgerLiquidity();
        }
        if (!canMint()) revert CommonErrorLibrary.InsufficientCollateralization();
    }

    /**
     * @notice Enforces mint-time EUR/USD deviation guard unless dev mode is enabled.
     * @dev Compares live price vs cached baseline and reverts when deviation exceeds configured threshold.
     * @param eurUsdPrice Current validated EUR/USD price.
     * @custom:security Blocks minting during abnormal price moves outside policy limits.
     * @custom:validation Reverts with `ExcessiveSlippage` when deviation rule is violated.
     * @custom:state-changes No state changes.
     * @custom:events Emits `PriceDeviationDetected` before reverting on violation.
     * @custom:errors Reverts with `ExcessiveSlippage`.
     * @custom:reentrancy No external calls besides pure library logic.
     * @custom:access Internal helper.
     * @custom:oracle Uses provided live oracle price and cached baseline.
     */
    function _enforceMintPriceDeviation(uint256 eurUsdPrice) internal {
        if (devModeEnabled) return;

        (bool shouldRevert, uint256 deviationBps) = PriceValidationLibrary.checkPriceDeviation(
            eurUsdPrice,
            lastValidEurUsdPrice,
            MAX_PRICE_DEVIATION,
            lastPriceUpdateBlock,
            MIN_BLOCKS_BETWEEN_UPDATES
        );
        if (shouldRevert) {
            emit PriceDeviationDetected(eurUsdPrice, lastValidEurUsdPrice, deviationBps, block.number);
            revert CommonErrorLibrary.ExcessiveSlippage();
        }
    }

    /**
     * @notice Computes mint fee, net USDC, and QEURO output.
     * @dev Applies configured mint fee and slippage floor against `minQeuroOut`.
     * @param usdcAmount Gross USDC input (6 decimals).
     * @param eurUsdPrice Validated EUR/USD price.
     * @param minQeuroOut Minimum acceptable QEURO output.
     * @return fee Protocol fee deducted from `usdcAmount`.
     * @return netAmount Net USDC backing minted QEURO.
     * @return qeuroToMint QEURO output to mint.
     * @custom:security Enforces minimum-output slippage protection.
     * @custom:validation Reverts when computed output is below `minQeuroOut`.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors Reverts with `ExcessiveSlippage`.
     * @custom:reentrancy Not applicable for pure arithmetic helper.
     * @custom:access Internal helper.
     * @custom:oracle Uses supplied validated oracle input.
     */
    function _computeMintAmounts(uint256 usdcAmount, uint256 eurUsdPrice, uint256 minQeuroOut)
        internal
        view
        returns (uint256 fee, uint256 netAmount, uint256 qeuroToMint)
    {
        fee = usdcAmount.mulDiv(mintFee, 1e18);
        netAmount = usdcAmount - fee;
        qeuroToMint = netAmount.mulDiv(1e30, eurUsdPrice);
        if (qeuroToMint < minQeuroOut) revert CommonErrorLibrary.ExcessiveSlippage();
    }

    /**
     * @notice Ensures projected collateralization remains above mint threshold after this mint.
     * @dev Simulates post-mint collateral/supply state and compares to configured minimum ratio.
     * @param netAmount Net USDC that will be added as collateral.
     * @param qeuroToMint QEURO amount that will be minted.
     * @param eurUsdPrice Validated EUR/USD price used for backing requirement conversion.
     * @custom:security Prevents minting that would violate collateralization policy.
     * @custom:validation Reverts if projected backing requirement is zero or projected ratio is too low.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors Reverts with `InvalidAmount` or `InsufficientCollateralization`.
     * @custom:reentrancy Not applicable for view helper.
     * @custom:access Internal helper.
     * @custom:oracle Uses supplied validated oracle input.
     */
    function _enforceProjectedMintCollateralization(uint256 netAmount, uint256 qeuroToMint, uint256 eurUsdPrice)
        internal
        view
    {
        uint256 currentSupply = qeuro.totalSupply();
        uint256 collateralBeforeMint = _getTotalCollateralWithAccruedYield();
        uint256 projectedSupply = currentSupply + qeuroToMint;
        uint256 projectedCollateral = collateralBeforeMint + netAmount;
        uint256 projectedBackingRequirement = projectedSupply.mulDiv(eurUsdPrice, 1e18) / 1e12;
        if (projectedBackingRequirement == 0) revert CommonErrorLibrary.InvalidAmount();
        uint256 projectedCollateralizationRatio = projectedCollateral.mulDiv(1e20, projectedBackingRequirement);
        if (projectedCollateralizationRatio < minCollateralizationRatioForMinting) {
            revert CommonErrorLibrary.InsufficientCollateralization();
        }
    }

    /**
     * @notice Commits mint flow effects/interactions after validation phase
     * @dev Called via explicit self-call from `mintQEURO` to separate validation and commit phases.
     * @param payer User receiving freshly minted QEURO
     * @param qeuroRecipient Address receiving minted QEURO output.
     * @param usdcAmount Gross USDC transferred in
     * @param fee Protocol fee portion from `usdcAmount`
     * @param netAmount Net USDC credited to collateral after fees
     * @param qeuroToMint QEURO amount to mint for `minter`
     * @param eurUsdPrice Validated EUR/USD price used for accounting cache
     * @param isValidPrice Whether oracle read used for cache timestamp was valid
     * @param targetVaultId Target vault id for optional auto-deployment (`0` disables deployment).
     * @custom:security Restricted by `onlySelf`; executed from `nonReentrant` parent flow
     * @custom:validation Assumes caller already validated collateralization and oracle constraints
     * @custom:state-changes Updates vault accounting, oracle cache timestamps, and optional Aave principal tracker
     * @custom:events Emits `QEUROminted` and potentially downstream fee/yield events
     * @custom:errors Token, hedger sync, fee routing, and Aave operations may revert
     * @custom:reentrancy Structured CEI commit path called from guarded parent
     * @custom:access External self-call entrypoint only
     * @custom:oracle Uses pre-validated oracle price input
     */
    function _mintQEUROCommit(
        address payer,
        address qeuroRecipient,
        uint256 usdcAmount,
        uint256 fee,
        uint256 netAmount,
        uint256 qeuroToMint,
        uint256 eurUsdPrice,
        bool isValidPrice,
        uint256 targetVaultId
    ) external onlySelf {
        uint256 autoDeployAmount = targetVaultId != 0 ? netAmount : 0;

        // EFFECTS
        lastPriceUpdateBlock = block.number;
        lastValidEurUsdPrice = eurUsdPrice;
        _updatePriceTimestamp(isValidPrice);

        totalUsdcHeld += netAmount;
        totalMinted += qeuroToMint;

        if (autoDeployAmount > 0) {
            unchecked {
                totalUsdcHeld -= autoDeployAmount;
                principalUsdcByVaultId[targetVaultId] += autoDeployAmount;
                totalUsdcInExternalVaults += autoDeployAmount;
            }
        }

        _syncMintWithHedgersOrRevert(netAmount, eurUsdPrice, qeuroToMint);
        emit QEUROminted(payer, usdcAmount, qeuroToMint);

        // INTERACTIONS
        usdc.safeTransferFrom(payer, address(this), usdcAmount);
        _routeProtocolFees(fee, "minting");
        qeuro.mint(qeuroRecipient, qeuroToMint);

        if (autoDeployAmount > 0) {
            _autoDeployToVault(targetVaultId, autoDeployAmount);
        }
    }
    
    /**
     * @notice Internal function to auto-deploy USDC to Aave after minting
     * @dev Uses strict CEI ordering and lets failures revert to preserve accounting integrity
     * @param vaultId Target external vault id for deployment.
     * @param usdcAmount Amount of USDC to deploy (6 decimals)
     * @custom:security Updates accounting before external interaction to remove reentrancy windows
     * @custom:validation Validates MockAaveVault is set and amount > 0
     * @custom:state-changes Updates totalUsdcHeld and totalUsdcInAave before calling MockAaveVault
     * @custom:events Emits UsdcDeployedToAave on success
     * @custom:errors Reverts on failed deployment or invalid Aave return value
     * @custom:reentrancy Not protected - internal function only
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _autoDeployToVault(uint256 vaultId, uint256 usdcAmount) internal {
        if (vaultId == 0 || usdcAmount == 0) return;

        IExternalStakingVault adapter = stakingVaultAdapterById[vaultId];
        if (!stakingVaultActiveById[vaultId] || address(adapter) == address(0)) revert CommonErrorLibrary.InvalidVault();

        usdc.safeIncreaseAllowance(address(adapter), usdcAmount);
        uint256 sharesReceived = adapter.depositUnderlying(usdcAmount);
        if (sharesReceived == 0) revert CommonErrorLibrary.InvalidAmount();
        emit UsdcDeployedToExternalVault(vaultId, usdcAmount, principalUsdcByVaultId[vaultId]);
    }

    /**
     * @notice Redeems QEURO for USDC - automatically routes to normal or liquidation mode
     * 
     * @param qeuroAmount Amount of QEURO to swap for USDC
     * @param minUsdcOut Minimum amount of USDC expected
     * 
     * @dev Redeem process:
     *      1. Check if protocol is in liquidation mode (CR <= 101%)
     *      2. If liquidation mode: use pro-rata distribution based on actual USDC in vault
     *         - Payout = (qeuroAmount / totalSupply) * totalVaultUsdc
     *         - Hedger loses margin proportionally: (qeuroAmount / totalSupply) * hedgerMargin
     *         - Fees are always applied using `redemptionFee`
     *      3. If normal mode: use oracle price with standard fees
     *      4. Burn QEURO and transfer USDC
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits QEURORedeemed or LiquidationRedeemed based on mode
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access No access restrictions
     * @custom:oracle Requires fresh oracle price data
     * @custom:security No flash loan protection needed - legitimate redemption operation
     */
    // SECURITY: Protected by nonReentrant modifier; external calls to trusted Oracle and MockAaveVault
    function redeemQEURO(
        uint256 qeuroAmount,
        uint256 minUsdcOut
    ) external nonReentrant whenNotPaused {
        // CHECKS
        CommonValidationLibrary.validatePositiveAmount(qeuroAmount);

        // Check if protocol is in liquidation mode using the configurable critical threshold
        uint256 currentRatio18Dec = getProtocolCollateralizationRatio();
        uint256 collateralizationRatioBps = currentRatio18Dec / 1e16;
        
        uint256 criticalRatioBps = criticalCollateralizationRatio / 1e16;

        // Route to liquidation mode if current CR is at/below configured critical threshold
        if (collateralizationRatioBps > 0 && collateralizationRatioBps <= criticalRatioBps) {
            _redeemLiquidationMode(qeuroAmount, minUsdcOut, collateralizationRatioBps);
            return;
        }

        // Normal mode redemption
        // Cache oracle price at start to avoid reentrancy issues
        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) revert CommonErrorLibrary.InvalidOraclePrice();
        
        // Price deviation check using cached price (skip if dev mode is enabled)
        if (!devModeEnabled) {
            (bool shouldRevert, uint256 deviationBps) = PriceValidationLibrary.checkPriceDeviation(
                eurUsdPrice,
                lastValidEurUsdPrice,
                MAX_PRICE_DEVIATION,
                lastPriceUpdateBlock,
                MIN_BLOCKS_BETWEEN_UPDATES
            );
            if (shouldRevert) {
                emit PriceDeviationDetected(eurUsdPrice, lastValidEurUsdPrice, deviationBps, block.number);
                revert CommonErrorLibrary.ExcessiveSlippage();
            }
        }

        // Calculate USDC to return using validated oracle price
        uint256 usdcToReturn = qeuroAmount.mulDiv(eurUsdPrice, 1e18);
        usdcToReturn = usdcToReturn / 1e12; // Convert from 18 to 6 decimals

        // Calculate fees before slippage check so minUsdcOut applies to the actual net payout
        uint256 fee = usdcToReturn.mulDiv(redemptionFee, 1e18);
        uint256 netUsdcToReturn = usdcToReturn - fee;

        if (netUsdcToReturn < minUsdcOut) revert CommonErrorLibrary.ExcessiveSlippage();

        // Check if total available USDC (vault + Aave principal + accrued Aave yield) is sufficient.
        uint256 totalAvailable = _getTotalCollateralWithAccruedYield();
        if (totalAvailable < usdcToReturn) revert CommonErrorLibrary.InsufficientBalance();

        if (address(hedgerPool) == address(0)) revert CommonErrorLibrary.InvalidVault();

        uint256 externalWithdrawalAmount = _planExternalVaultWithdrawal(usdcToReturn);
        RedeemCommitPayload memory payload;
        payload.redeemer = msg.sender;
        payload.qeuroAmount = qeuroAmount;
        payload.usdcToReturn = usdcToReturn;
        payload.netUsdcToReturn = netUsdcToReturn;
        payload.fee = fee;
        payload.eurUsdPrice = eurUsdPrice;
        payload.isValidPrice = isValid;
        payload.externalWithdrawalAmount = externalWithdrawalAmount;
        _dispatchRedeemCommit(payload);
    }

    /**
     * @notice Dispatches redeem commit through explicit self-call.
     * @dev Preserves separation between validation/read phase and commit/interactions phase.
     * @param payload Packed redeem commit payload.
     * @custom:security Uses `onlySelf`-guarded commit entrypoint.
     * @custom:validation Assumes payload was prepared by validated redeem flow.
     * @custom:state-changes No direct state changes in dispatcher.
     * @custom:events No direct events in dispatcher.
     * @custom:errors Propagates commit-phase revert reasons.
     * @custom:reentrancy Called from guarded parent flow.
     * @custom:access Internal helper.
     * @custom:oracle No direct oracle reads.
     */
    function _dispatchRedeemCommit(RedeemCommitPayload memory payload) internal {
        this._redeemQEUROCommit(
            payload.redeemer,
            payload.qeuroAmount,
            payload.usdcToReturn,
            payload.netUsdcToReturn,
            payload.fee,
            payload.eurUsdPrice,
            payload.isValidPrice,
            payload.externalWithdrawalAmount
        );
    }

    /**
     * @notice Commits normal-mode redemption effects/interactions after validation
     * @dev Called via explicit self-call from `redeemQEURO`.
     * @param redeemer User redeeming QEURO
     * @param qeuroAmount QEURO amount burned from `redeemer`
     * @param usdcToReturn Gross USDC redemption amount before fee transfer split
     * @param netUsdcToReturn Net USDC transferred to the redeemer
     * @param fee Protocol fee amount from redemption
     * @param eurUsdPrice Validated EUR/USD price used for cache update
     * @param isValidPrice Whether oracle read used for cache timestamp was valid
     * @param externalWithdrawalAmount Planned USDC amount to source from Aave (if needed)
     * @custom:security Restricted by `onlySelf`; called from `nonReentrant` parent flow
     * @custom:validation Reverts if held liquidity is insufficient or mint tracker underflows
     * @custom:state-changes Updates collateral/mint trackers and price cache
     * @custom:events Emits `QEURORedeemed` and downstream fee routing events
     * @custom:errors Reverts on insufficient balances, token failures, or downstream integration failures
     * @custom:reentrancy CEI commit path invoked from guarded parent
     * @custom:access External self-call entrypoint only
     * @custom:oracle Uses pre-validated oracle price input
     */
    function _redeemQEUROCommit(
        address redeemer,
        uint256 qeuroAmount,
        uint256 usdcToReturn,
        uint256 netUsdcToReturn,
        uint256 fee,
        uint256 eurUsdPrice,
        bool isValidPrice,
        uint256 externalWithdrawalAmount
    ) external onlySelf {
        uint256 projectedHeld = totalUsdcHeld + externalWithdrawalAmount;
        if (projectedHeld < usdcToReturn) revert CommonErrorLibrary.InsufficientBalance();

        // EFFECTS
        lastPriceUpdateBlock = block.number;
        lastValidEurUsdPrice = eurUsdPrice;
        _updatePriceTimestamp(isValidPrice);

        totalUsdcHeld = projectedHeld - usdcToReturn;
        if (totalMinted < qeuroAmount) revert CommonErrorLibrary.InvalidAmount();
        totalMinted -= qeuroAmount;

        if (externalWithdrawalAmount > 0) {
            _withdrawUsdcFromExternalVaults(externalWithdrawalAmount);
        }
        
        _syncRedeemWithHedgers(usdcToReturn, eurUsdPrice, qeuroAmount);
        emit QEURORedeemed(redeemer, qeuroAmount, netUsdcToReturn);

        // INTERACTIONS
        qeuro.burn(redeemer, qeuroAmount);
        usdc.safeTransfer(redeemer, netUsdcToReturn);
        _routeProtocolFees(fee, "redemption");
    }

    /**
     * @notice Internal function for liquidation mode redemption (pro-rata based on actual USDC)
     * @dev Called by redeemQEURO when protocol is in liquidation mode (CR <= 101%)
     * @dev Key formulas:
     *      - Payout = (qeuroAmount / totalSupply) * totalVaultUsdc (actual USDC, not market value)
     *      - Hedger loss = (qeuroAmount / totalSupply) * hedgerMargin (proportional margin reduction)
     *      - Fees applied using `redemptionFee`
     * @param qeuroAmount Amount of QEURO to redeem (18 decimals)
     * @param minUsdcOut Minimum USDC expected (slippage protection)
     * @param collateralizationRatioBps Current CR in basis points (for event emission)
     */
    /**
     * @notice Internal function to handle QEURO redemption in liquidation mode (CR ≤ 101%)
     * @dev Called by redeemQEURO when protocol enters liquidation mode
     * 
     * Liquidation Mode Formulas:
     * 1. userPayout = (qeuroAmount / totalQEUROSupply) × totalVaultUSDC
     *    - Pro-rata distribution based on actual USDC, NOT fair value
     *    - If CR < 100%, users take a haircut
     *    - If CR > 100%, users receive a small premium
     * 
     * 2. hedgerLoss = (qeuroAmount / totalQEUROSupply) × hedgerMargin
     *    - Hedger absorbs proportional margin loss
     *    - Recorded via hedgerPool.recordLiquidationRedeem()
     * 
     * In liquidation mode, hedger's unrealizedPnL = -margin (all margin at risk).
     * 
     * @param qeuroAmount Amount of QEURO to redeem (18 decimals)
     * @param minUsdcOut Minimum USDC expected (slippage protection, 6 decimals)
     * @param collateralizationRatioBps Current protocol CR in basis points (10000 = 100%)
     * @custom:security Internal function - handles liquidation redemptions with pro-rata distribution
     * @custom:validation Validates totalSupply > 0, oracle price valid, usdcPayout >= minUsdcOut, sufficient balance
     * @custom:state-changes Reduces totalUsdcHeld, totalMinted, calls hedgerPool.recordLiquidationRedeem
     * @custom:events Emits LiquidationRedeemed
     * @custom:errors Reverts with InvalidAmount, InvalidOraclePrice, ExcessiveSlippage, InsufficientBalance
     * @custom:reentrancy Protected by CEI pattern - state changes before external calls
     * @custom:access Internal function - called by redeemQEURO
     * @custom:oracle Requires valid EUR/USD price from oracle
     */
    // SECURITY: Internal function called from nonReentrant redeemQEURO; trusted Oracle and MockAaveVault
    function _redeemLiquidationMode(
        uint256 qeuroAmount,
        uint256 minUsdcOut,
        uint256 collateralizationRatioBps
    ) internal {
        // Get total QEURO supply for pro-rata calculation
        uint256 totalSupply = qeuro.totalSupply();
        if (totalSupply == 0) revert CommonErrorLibrary.InvalidAmount();

        // Get oracle price for fair value comparison (premium vs haircut)
        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) revert CommonErrorLibrary.InvalidOraclePrice();

        // Calculate pro-rata payout based on actual USDC available.
        uint256 totalCollateralUsdc = _getTotalCollateralWithAccruedYield();
        uint256 usdcPayout = qeuroAmount.mulDiv(totalCollateralUsdc, totalSupply);

        // Calculate fees and net payout
        (uint256 fee, uint256 netUsdcPayout) = _calculateLiquidationFees(usdcPayout);

        // LOW-7: validate slippage against net (post-fee) amount so minUsdcOut applies to what user actually receives
        if (netUsdcPayout < minUsdcOut) revert CommonErrorLibrary.ExcessiveSlippage();

        // Determine if premium or haircut
        uint256 fairValueUsdc = qeuroAmount.mulDiv(eurUsdPrice, 1e18) / 1e12;
        bool isPremium = usdcPayout >= fairValueUsdc;

        uint256 externalWithdrawalAmount = _planExternalVaultWithdrawal(usdcPayout);
        LiquidationCommitParams memory params = LiquidationCommitParams({
            redeemer: msg.sender,
            qeuroAmount: qeuroAmount,
            totalSupply: totalSupply,
            usdcPayout: usdcPayout,
            netUsdcPayout: netUsdcPayout,
            fee: fee,
            collateralizationRatioBps: collateralizationRatioBps,
            isPremium: isPremium,
            externalWithdrawalAmount: externalWithdrawalAmount
        });
        _redeemLiquidationCommit(params);
    }

    /**
     * @notice Commits liquidation-mode redemption effects/interactions
     * @dev Called via explicit self-call from `_redeemLiquidationMode`.
     * @param params Packed liquidation commit values
     * @custom:security Restricted by `onlySelf`; called from guarded liquidation flow
     * @custom:validation Reverts on insufficient balances or mint tracker underflow
     * @custom:state-changes Updates collateral/mint trackers and notifies hedger pool liquidation accounting
     * @custom:events Emits `LiquidationRedeemed` and downstream fee routing events
     * @custom:errors Reverts on balance/transfer/integration failures
     * @custom:reentrancy CEI commit path invoked from `nonReentrant` parent
     * @custom:access External self-call entrypoint only
     * @custom:oracle No direct oracle reads (uses precomputed inputs)
     */
    function _redeemLiquidationCommit(LiquidationCommitParams memory params) internal {
        uint256 projectedHeld = totalUsdcHeld + params.externalWithdrawalAmount;
        if (projectedHeld < params.usdcPayout) revert CommonErrorLibrary.InsufficientBalance();
        totalUsdcHeld = projectedHeld - params.usdcPayout;
        if (totalMinted < params.qeuroAmount) revert CommonErrorLibrary.InvalidAmount();
        totalMinted -= params.qeuroAmount;

        if (params.externalWithdrawalAmount > 0) {
            _withdrawUsdcFromExternalVaults(params.externalWithdrawalAmount);
        }

        _notifyHedgerPoolLiquidation(params.qeuroAmount, params.totalSupply);
        emit LiquidationRedeemed(
            params.redeemer,
            params.qeuroAmount,
            params.netUsdcPayout,
            params.collateralizationRatioBps,
            params.isPremium
        );

        qeuro.burn(params.redeemer, params.qeuroAmount);
        usdc.safeTransfer(params.redeemer, params.netUsdcPayout);
        _transferLiquidationFees(params.fee);
    }

    /**
     * @notice Calculates required Aave withdrawal to satisfy a USDC payout
     * @dev Returns zero when vault-held USDC already covers `requiredUsdc`.
     * @param requiredUsdc Target USDC amount that must be available in vault balance
     * @return vaultWithdrawalAmount Additional USDC that should be sourced from Aave
     * @custom:security Enforces that Aave vault is configured before planning an Aave-backed withdrawal
     * @custom:validation Reverts with `InsufficientBalance` when deficit exists and Aave is not configured
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors Reverts with `InsufficientBalance` when no Aave source exists for deficit
     * @custom:reentrancy No external calls
     * @custom:access Internal helper
     * @custom:oracle No oracle dependencies
     */
    function _planExternalVaultWithdrawal(uint256 requiredUsdc) internal view returns (uint256 vaultWithdrawalAmount) {
        if (requiredUsdc == 0 || totalUsdcHeld >= requiredUsdc) {
            return 0;
        }
        if (totalUsdcInExternalVaults == 0) revert CommonErrorLibrary.InsufficientBalance();
        vaultWithdrawalAmount = requiredUsdc - totalUsdcHeld;
        if (vaultWithdrawalAmount > totalUsdcInExternalVaults) revert CommonErrorLibrary.InsufficientBalance();
    }

    /**
     * @notice Calculates liquidation fees from gross liquidation payout.
     * @dev Fees are always applied in liquidation mode: `fee = usdcPayout * redemptionFee / 1e18`.
     * @param usdcPayout Gross payout amount
     * @return fee Fee amount
     * @return netPayout Net payout after fees
     * @custom:security View only
     * @custom:validation Uses current `redemptionFee` in 1e18 precision
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy None
     * @custom:access Internal
     * @custom:oracle None
     */
    function _calculateLiquidationFees(uint256 usdcPayout) internal view returns (uint256 fee, uint256 netPayout) {
        // INFO-3: fees are always taken during liquidation (TAKES_FEES_DURING_LIQUIDATION was always true)
        fee = usdcPayout.mulDiv(redemptionFee, 1e18);
        netPayout = usdcPayout - fee;
    }

    /**
     * @notice Notifies hedger pool of liquidation redemption for margin adjustment.
     * @dev LOW-3 hardening: when hedger collateral exists, this call is atomic and must succeed.
     *      It is skipped only when HedgerPool is unset or has zero collateral.
     * @param qeuroAmount Amount of QEURO being redeemed
     * @param totalSupply Total QEURO supply for pro-rata calculation
     * @custom:security Reverts liquidation flow if HedgerPool call fails while collateral exists
     * @custom:validation Skips only when HedgerPool is zero or totalMargin is 0
     * @custom:state-changes HedgerPool state via recordLiquidationRedeem
     * @custom:events Via HedgerPool
     * @custom:errors Bubbles HedgerPool errors in atomic path
     * @custom:reentrancy External call to HedgerPool
     * @custom:access Internal
     * @custom:oracle None
     */
    function _notifyHedgerPoolLiquidation(uint256 qeuroAmount, uint256 totalSupply) internal {
        if (address(hedgerPool) == address(0)) return;
        uint256 hedgerCollateral = hedgerPool.totalMargin();
        if (hedgerCollateral == 0) return;
        // LOW-3 fix: liquidation accounting must be atomic when hedger collateral exists.
        hedgerPool.recordLiquidationRedeem(qeuroAmount, totalSupply);
    }

    /**
     * @notice Transfers liquidation fees to fee collector if applicable
     * @dev Approves USDC to FeeCollector and calls collectFees; no-op if fees disabled or fee is 0
     * @param fee Fee amount to transfer
     * @custom:security Requires approve and collectFees to succeed
     * @custom:validation `fee > 0`
     * @custom:state-changes USDC balance of feeCollector
     * @custom:events Via FeeCollector
     * @custom:errors TokenTransferFailed if approve fails
     * @custom:reentrancy External call to FeeCollector
     * @custom:access Internal
     * @custom:oracle None
     */
    function _transferLiquidationFees(uint256 fee) internal {
        if (fee == 0) return;
        _routeProtocolFees(fee, "liquidation");
    }

    // =============================================================================
    // VIEW FUNCTIONS - Read functions for monitoring
    // =============================================================================

    /**
     * @notice Retrieves the vault's global metrics
     * @dev Returns comprehensive vault metrics for monitoring and analytics
     * @return totalUsdcHeld_ Total USDC held directly in the vault
     * @return totalMinted_ Total QEURO minted
     * @return totalDebtValue Total debt value in USD
     * @return totalUsdcInExternalVaults_ Total USDC deployed to Aave for yield
     * @return totalUsdcAvailable_ Total USDC available (vault + Aave)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes No state changes
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access No access restrictions
     * @custom:oracle No oracle dependencies
     */
    /**
     * @notice Checks if the protocol is properly collateralized by hedgers
     * @dev Public view function to check collateralization status
     * @return isCollateralized True if protocol has active hedging positions
     * @return totalMargin Total margin in HedgerPool (0 if not set)
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can check collateralization status
     * @custom:oracle No oracle dependencies
     */
    function isProtocolCollateralized() external view returns (bool isCollateralized, uint256 totalMargin) {
        if (address(hedgerPool) == address(0)) {
            return (false, 0);
        }
        
        totalMargin = hedgerPool.totalMargin();
        isCollateralized = totalMargin > 0;
    }


    // =============================================================================
    // GOVERNANCE FUNCTIONS - Governance functions
    // =============================================================================

    /**
     * @notice Updates the vault parameters (governance only)
     * 
     * @param _mintFee New minting fee (1e18 precision, 1e18 = 100%)
     * @param _redemptionFee New redemption fee (1e18 precision, 1e18 = 100%)
     * 
     * @dev Safety constraints:
     *      - Fees <= 5% (user protection)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function updateParameters(
        uint256 _mintFee,
        uint256 _redemptionFee
    ) external onlyRole(GOVERNANCE_ROLE) {
        if (_mintFee > 5e16) revert VaultErrorLibrary.FeeTooHigh();
        if (_redemptionFee > 5e16) revert VaultErrorLibrary.FeeTooHigh();

        mintFee = _mintFee;
        redemptionFee = _redemptionFee;

        emit ParametersUpdated("fees", _mintFee, _redemptionFee);
    }

    /**
     * @notice Updates the fee share routed to HedgerPool reward reserve.
     * @dev Governance-controlled split applied in `_routeProtocolFees`.
     * @param newSplit Share in 1e18 precision (1e18 = 100%).
     * @custom:security Restricted to governance and bounded by max split constant.
     * @custom:validation Reverts when `newSplit` exceeds `MAX_HEDGER_REWARD_FEE_SPLIT`.
     * @custom:state-changes Updates `hedgerRewardFeeSplit`.
     * @custom:events Emits `HedgerRewardFeeSplitUpdated`.
     * @custom:errors Reverts with `ConfigValueTooHigh` on invalid split.
     * @custom:reentrancy Not applicable - simple state update.
     * @custom:access Restricted to `GOVERNANCE_ROLE`.
     * @custom:oracle No oracle interaction.
     */
    function updateHedgerRewardFeeSplit(uint256 newSplit) external onlyRole(GOVERNANCE_ROLE) {
        if (newSplit > MAX_HEDGER_REWARD_FEE_SPLIT) revert CommonErrorLibrary.ConfigValueTooHigh();
        uint256 oldSplit = hedgerRewardFeeSplit;
        hedgerRewardFeeSplit = newSplit;
        emit HedgerRewardFeeSplitUpdated(oldSplit, newSplit);
    }

    /**
     * @notice Updates the collateralization thresholds (governance only)
     * 
     * @param _minCollateralizationRatioForMinting New minimum collateralization ratio for minting (in 18 decimals)
     * @param _criticalCollateralizationRatio New critical collateralization ratio for liquidation (in 18 decimals)
     * 
     * @dev Safety constraints:
     *      - minCollateralizationRatioForMinting >= 101000000000000000000 (101.000000% minimum = 101 * 1e18)
     *      - criticalCollateralizationRatio <= minCollateralizationRatioForMinting
     *      - criticalCollateralizationRatio >= 100000000000000000000 (100.000000% minimum = 100 * 1e18)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function updateCollateralizationThresholds(
        uint256 _minCollateralizationRatioForMinting,
        uint256 _criticalCollateralizationRatio
    ) external onlyRole(GOVERNANCE_ROLE) {
        if (_minCollateralizationRatioForMinting < MIN_ALLOWED_COLLATERALIZATION_RATIO) revert CommonErrorLibrary.InvalidThreshold();
        if (_criticalCollateralizationRatio < MIN_ALLOWED_CRITICAL_RATIO) revert CommonErrorLibrary.InvalidThreshold();
        if (_criticalCollateralizationRatio > _minCollateralizationRatioForMinting) revert CommonErrorLibrary.InvalidThreshold();

        minCollateralizationRatioForMinting = _minCollateralizationRatioForMinting;
        criticalCollateralizationRatio = _criticalCollateralizationRatio;

        emit CollateralizationThresholdsUpdated(
            _minCollateralizationRatioForMinting,
            _criticalCollateralizationRatio,
            msg.sender
        );
    }

    /**
     * @notice Updates the oracle address
     * @dev Updates the oracle contract address for price feeds
     * @param _oracle New oracle address
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function updateOracle(address _oracle) external onlyRole(GOVERNANCE_ROLE) {
        if (_oracle == address(0)) revert CommonErrorLibrary.InvalidOracle();
        oracle = IOracle(_oracle);
    }

    /**
     * @notice Updates the HedgerPool address
     * @dev Updates the HedgerPool contract address for collateralization checks
     * @param _hedgerPool New HedgerPool address
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function updateHedgerPool(address _hedgerPool) external onlyRole(GOVERNANCE_ROLE) {
        if (_hedgerPool == address(0)) revert CommonErrorLibrary.InvalidVault();
        hedgerPool = IHedgerPool(_hedgerPool);
        emit ParametersUpdated("hedgerPool", 0, 0);
    }
    
    /**
     * @notice Updates the UserPool address
     * @dev Updates the UserPool contract address for user deposit tracking
     * @param _userPool New UserPool address
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function updateUserPool(address _userPool) external onlyRole(GOVERNANCE_ROLE) {
        if (_userPool == address(0)) revert CommonErrorLibrary.InvalidVault();
        userPool = IUserPool(_userPool);
        emit ParametersUpdated("userPool", 0, 0);
    }
    
    /**
     * @notice Updates the fee collector address
     * @dev Only governance role can update the fee collector address
     * @param _feeCollector New fee collector address
     * @custom:security Validates address is not zero before updating
     * @custom:validation Ensures _feeCollector is not address(0)
     * @custom:state-changes Updates feeCollector state variable
     * @custom:events Emits ParametersUpdated event
     * @custom:errors Reverts if _feeCollector is address(0)
     * @custom:reentrancy No reentrancy risk, simple state update
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function updateFeeCollector(address _feeCollector) external onlyRole(GOVERNANCE_ROLE) {
        if (_feeCollector == address(0)) revert CommonErrorLibrary.ZeroAddress();
        feeCollector = _feeCollector;
        emit ParametersUpdated("feeCollector", 0, 0);
    }

    /**
     * @notice Configures adapter and activation status for a vault id.
     * @dev Governance management entrypoint for external staking vault routing.
     * @param vaultId Vault id to configure.
     * @param adapter Adapter contract implementing `IExternalStakingVault`.
     * @param active Activation flag controlling whether vault id is eligible for routing.
     * @custom:security Restricted to `GOVERNANCE_ROLE`.
     * @custom:validation Reverts on zero vault id or zero adapter address.
     * @custom:state-changes Updates adapter mapping and active-status mapping for `vaultId`.
     * @custom:events Emits `StakingVaultConfigured`.
     * @custom:errors Reverts with `InvalidVault` or `ZeroAddress`.
     * @custom:reentrancy No reentrancy-sensitive external calls.
     * @custom:access Governance-only.
     * @custom:oracle No oracle dependencies.
     */
    function setStakingVault(uint256 vaultId, address adapter, bool active) external onlyRole(GOVERNANCE_ROLE) {
        if (vaultId == 0) revert CommonErrorLibrary.InvalidVault();
        if (adapter == address(0)) revert CommonErrorLibrary.ZeroAddress();
        stakingVaultAdapterById[vaultId] = IExternalStakingVault(adapter);
        stakingVaultActiveById[vaultId] = active;
        emit StakingVaultConfigured(vaultId, adapter, active);
    }

    /**
     * @notice Sets default vault id used for mint routing and fallback redemption priority.
     * @dev `vaultId == 0` clears default routing.
     * @param vaultId New default vault id (or 0 to clear).
     * @custom:security Restricted to `GOVERNANCE_ROLE`.
     * @custom:validation Non-zero ids must be active and have a configured adapter.
     * @custom:state-changes Updates `defaultStakingVaultId`.
     * @custom:events Emits `DefaultStakingVaultUpdated`.
     * @custom:errors Reverts with `InvalidVault`/`ZeroAddress` for invalid non-zero ids.
     * @custom:reentrancy No reentrancy-sensitive external calls.
     * @custom:access Governance-only.
     * @custom:oracle No oracle dependencies.
     */
    function setDefaultStakingVaultId(uint256 vaultId) external onlyRole(GOVERNANCE_ROLE) {
        if (vaultId != 0) {
            if (!stakingVaultActiveById[vaultId]) revert CommonErrorLibrary.InvalidVault();
            if (address(stakingVaultAdapterById[vaultId]) == address(0)) revert CommonErrorLibrary.ZeroAddress();
        }
        uint256 previous = defaultStakingVaultId;
        defaultStakingVaultId = vaultId;
        emit DefaultStakingVaultUpdated(previous, vaultId);
    }

    /**
     * @notice Sets ordered vault ids used when sourcing redemption liquidity from external vaults.
     * @dev Replaces the full priority array with provided values.
     * @param vaultIds Ordered vault ids to use for redemption withdrawals.
     * @custom:security Restricted to `GOVERNANCE_ROLE`.
     * @custom:validation Each id must be non-zero, active, and mapped to a configured adapter.
     * @custom:state-changes Replaces `redemptionPriorityVaultIds`.
     * @custom:events Emits `RedemptionPriorityUpdated`.
     * @custom:errors Reverts with `InvalidVault`/`ZeroAddress` on invalid entries.
     * @custom:reentrancy No reentrancy-sensitive external calls.
     * @custom:access Governance-only.
     * @custom:oracle No oracle dependencies.
     */
    function setRedemptionPriority(uint256[] calldata vaultIds) external onlyRole(GOVERNANCE_ROLE) {
        delete redemptionPriorityVaultIds;
        for (uint256 i = 0; i < vaultIds.length; ++i) {
            uint256 vaultId = vaultIds[i];
            if (vaultId == 0 || !stakingVaultActiveById[vaultId]) revert CommonErrorLibrary.InvalidVault();
            if (address(stakingVaultAdapterById[vaultId]) == address(0)) revert CommonErrorLibrary.ZeroAddress();
            redemptionPriorityVaultIds.push(vaultId);
        }
        emit RedemptionPriorityUpdated(vaultIds);
    }

    /**
     * @notice Registers this vault in stQEUROFactory using strict self-call semantics.
     * @dev Previews deterministic token address, binds local state, then executes factory registration and verifies match.
     * @param factory Address of stQEUROFactory.
     * @param vaultId Desired vault id in the factory registry.
     * @param vaultName Uppercase alphanumeric vault name.
     * @return token Newly deployed stQEURO token address.
     * @custom:security Restricted to governance and protected by `nonReentrant`.
     * @custom:validation Requires non-zero factory address, non-zero vault id, and uninitialized local stQEURO state.
     * @custom:state-changes Sets `stQEUROFactory`, `stQEUROToken`, and `stQEUROVaultId` for this vault.
     * @custom:events Emits `StQEURORegistered` after successful factory registration.
     * @custom:errors Reverts on invalid inputs, duplicate initialization, or mismatched preview/registered token address.
     * @custom:reentrancy Guarded by `nonReentrant`; state binding follows CEI before external registration call.
     * @custom:access Restricted to `GOVERNANCE_ROLE`.
     * @custom:oracle No oracle dependencies.
     */
    function selfRegisterStQEURO(address factory, uint256 vaultId, string calldata vaultName)
        external
        onlyRole(GOVERNANCE_ROLE)
        nonReentrant
        returns (address token)
    {
        if (factory == address(0)) revert CommonErrorLibrary.InvalidToken();
        if (vaultId == 0) revert CommonErrorLibrary.InvalidVault();
        if (stQEUROTokenByVaultId[vaultId] != address(0)) revert CommonErrorLibrary.AlreadyInitialized();

        token = IStQEUROFactory(factory).previewVaultToken(address(this), vaultId, vaultName);
        if (token == address(0)) revert CommonErrorLibrary.InvalidAddress();

        stQEUROFactory = factory;
        stQEUROTokenByVaultId[vaultId] = token;

        address registeredToken = IStQEUROFactory(factory).registerVault(vaultId, vaultName);
        if (registeredToken != token) revert CommonErrorLibrary.InvalidAddress();

        emit StQEURORegistered(factory, vaultId, token, vaultName);
    }

    /**
     * @notice Harvests yield from a specific external vault adapter.
     * @dev Governance-triggered wrapper around adapter `harvestYield`.
     * @param vaultId Vault id whose adapter yield should be harvested.
     * @return harvestedYield Yield harvested by adapter in USDC units.
     * @custom:security Restricted to `GOVERNANCE_ROLE`; protected by `nonReentrant`.
     * @custom:validation Reverts when vault id is invalid/inactive or adapter is unset.
     * @custom:state-changes Adapter-side yield state may update; vault emits harvest event.
     * @custom:events Emits `ExternalVaultYieldHarvested`.
     * @custom:errors Reverts on invalid configuration or adapter harvest failures.
     * @custom:reentrancy Guarded by `nonReentrant`.
     * @custom:access Governance-only.
     * @custom:oracle No direct oracle dependency.
     */
    function harvestVaultYield(uint256 vaultId)
        external
        onlyRole(GOVERNANCE_ROLE)
        nonReentrant
        returns (uint256 harvestedYield)
    {
        IExternalStakingVault adapter = stakingVaultAdapterById[vaultId];
        if (vaultId == 0 || !stakingVaultActiveById[vaultId]) revert CommonErrorLibrary.InvalidVault();
        if (address(adapter) == address(0)) revert CommonErrorLibrary.ZeroAddress();

        harvestedYield = adapter.harvestYield();
        emit ExternalVaultYieldHarvested(vaultId, harvestedYield);
    }

    /**
     * @notice Deploys held USDC principal into a configured external vault adapter.
     * @dev Operator flow for moving idle vault USDC into yield-bearing adapters.
     * @param vaultId Target vault id.
     * @param usdcAmount USDC amount to deploy (6 decimals).
     * @custom:security Restricted to `VAULT_OPERATOR_ROLE`; protected by `nonReentrant`.
     * @custom:validation Reverts on zero amount, insufficient held liquidity, invalid vault id, or unset adapter.
     * @custom:state-changes Decreases `totalUsdcHeld`, increases per-vault and global external principal trackers.
     * @custom:events Emits `UsdcDeployedToExternalVault`.
     * @custom:errors Reverts on invalid inputs, accounting constraints, or adapter failures.
     * @custom:reentrancy Guarded by `nonReentrant`.
     * @custom:access Vault-operator role.
     * @custom:oracle No direct oracle dependency.
     */
    function deployUsdcToVault(uint256 vaultId, uint256 usdcAmount) external nonReentrant onlyRole(VAULT_OPERATOR_ROLE) {
        CommonValidationLibrary.validatePositiveAmount(usdcAmount);
        if (totalUsdcHeld < usdcAmount) revert CommonErrorLibrary.InsufficientBalance();
        if (vaultId == 0 || !stakingVaultActiveById[vaultId]) revert CommonErrorLibrary.InvalidVault();
        IExternalStakingVault adapter = stakingVaultAdapterById[vaultId];
        if (address(adapter) == address(0)) revert CommonErrorLibrary.ZeroAddress();

        unchecked {
            totalUsdcHeld -= usdcAmount;
            principalUsdcByVaultId[vaultId] += usdcAmount;
            totalUsdcInExternalVaults += usdcAmount;
        }

        usdc.safeIncreaseAllowance(address(adapter), usdcAmount);
        uint256 sharesReceived = adapter.depositUnderlying(usdcAmount);
        if (sharesReceived == 0) revert CommonErrorLibrary.InvalidAmount();

        emit UsdcDeployedToExternalVault(vaultId, usdcAmount, principalUsdcByVaultId[vaultId]);
    }

    /**
     * @notice Returns current exposure snapshot for a vault id.
     * @dev Provides adapter address, active flag, tracked principal, and best-effort underlying read.
     * @param vaultId Vault id to query.
     * @return adapter Adapter address mapped to vault id.
     * @return active Whether vault id is active.
     * @return principalTracked Principal tracked locally for vault id.
     * @return currentUnderlying Current underlying balance from adapter (fallbacks to principal on read failure).
     * @custom:security Read-only helper.
     * @custom:validation No additional validation; unknown ids return zeroed/default values.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors No explicit errors; adapter read failure is handled via fallback.
     * @custom:reentrancy Not applicable for view function.
     * @custom:access Public view.
     * @custom:oracle No oracle dependencies.
     */
    function getVaultExposure(uint256 vaultId)
        external
        view
        returns (address adapter, bool active, uint256 principalTracked, uint256 currentUnderlying)
    {
        adapter = address(stakingVaultAdapterById[vaultId]);
        active = stakingVaultActiveById[vaultId];
        principalTracked = principalUsdcByVaultId[vaultId];
        if (adapter != address(0)) {
            try IExternalStakingVault(adapter).totalUnderlying() returns (uint256 underlying) {
                currentUnderlying = underlying;
            } catch {
                currentUnderlying = principalTracked;
            }
        }
    }

    /**
     * @notice Withdraws requested USDC from external vault adapters following priority ordering.
     * @dev Iterates resolved priority list until amount is fully satisfied or reverts on shortfall.
     * @param usdcAmount Total USDC amount to source from external vaults.
     * @return usdcWithdrawn Total USDC withdrawn from adapters.
     * @custom:security Internal liquidity-sourcing helper for guarded redeem flows.
     * @custom:validation Reverts with `InsufficientBalance` if aggregate withdrawals cannot satisfy request.
     * @custom:state-changes Updates per-vault and global principal trackers via delegated withdrawal helper.
     * @custom:events Emits per-vault withdrawal events from delegated helper.
     * @custom:errors Reverts on insufficient liquidity or adapter withdrawal mismatch.
     * @custom:reentrancy Internal helper; downstream adapter calls are performed in controlled flow.
     * @custom:access Internal helper.
     * @custom:oracle No oracle dependencies.
     */
    function _withdrawUsdcFromExternalVaults(uint256 usdcAmount) internal returns (uint256 usdcWithdrawn) {
        if (usdcAmount == 0) return 0;

        uint256 remaining = usdcAmount;
        uint256[] memory priority = _resolveWithdrawalPriority();

        for (uint256 i = 0; i < priority.length && remaining > 0; ++i) {
            uint256 withdrawn = _withdrawFromExternalVault(priority[i], remaining);
            if (withdrawn == 0) continue;
            usdcWithdrawn += withdrawn;
            remaining -= withdrawn;
        }

        if (remaining > 0) revert CommonErrorLibrary.InsufficientBalance();
    }

    /**
     * @notice Resolves external-vault withdrawal priority list.
     * @dev Uses explicit `redemptionPriorityVaultIds` when configured, otherwise falls back to default vault id.
     * @return priority Ordered vault ids to use for withdrawal sourcing.
     * @custom:security Internal read helper.
     * @custom:validation Reverts if neither explicit priority nor default vault is available.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors Reverts with `InsufficientBalance` when no usable routing exists.
     * @custom:reentrancy Not applicable for view helper.
     * @custom:access Internal helper.
     * @custom:oracle No oracle dependencies.
     */
    function _resolveWithdrawalPriority() internal view returns (uint256[] memory priority) {
        priority = redemptionPriorityVaultIds;
        if (priority.length > 0) return priority;

        uint256 defaultVaultId = defaultStakingVaultId;
        if (defaultVaultId == 0) revert CommonErrorLibrary.InsufficientBalance();

        priority = new uint256[](1);
        priority[0] = defaultVaultId;
    }

    /**
     * @notice Withdraws up to `remaining` USDC principal from one external vault id.
     * @dev Caps withdrawal at locally tracked principal and requires adapter to return exact requested amount.
     * @param vaultId Vault id to withdraw from.
     * @param remaining Remaining aggregate withdrawal amount required.
     * @return withdrawnAmount Amount withdrawn from this vault id (0 when skipped/ineligible).
     * @custom:security Internal helper used by controlled redemption liquidity flow.
     * @custom:validation Skips inactive/unconfigured/zero-principal vaults; reverts on adapter mismatch.
     * @custom:state-changes Decreases per-vault and global principal trackers before adapter withdrawal.
     * @custom:events Emits `UsdcWithdrawnFromExternalVault` on successful withdrawal.
     * @custom:errors Reverts with `InvalidAmount` if adapter withdrawal result mismatches request.
     * @custom:reentrancy Internal helper; adapter interaction occurs after accounting updates.
     * @custom:access Internal helper.
     * @custom:oracle No oracle dependencies.
     */
    function _withdrawFromExternalVault(uint256 vaultId, uint256 remaining) internal returns (uint256 withdrawnAmount) {
        if (!stakingVaultActiveById[vaultId]) return 0;

        IExternalStakingVault adapter = stakingVaultAdapterById[vaultId];
        if (address(adapter) == address(0)) return 0;

        uint256 principalTracked = principalUsdcByVaultId[vaultId];
        if (principalTracked == 0) return 0;

        uint256 requested = remaining > principalTracked ? principalTracked : remaining;
        principalUsdcByVaultId[vaultId] = principalTracked - requested;
        totalUsdcInExternalVaults -= requested;

        uint256 withdrawn = adapter.withdrawUnderlying(requested);
        if (withdrawn != requested) revert CommonErrorLibrary.InvalidAmount();

        emit UsdcWithdrawnFromExternalVault(vaultId, requested, principalUsdcByVaultId[vaultId]);
        return requested;
    }
    

    /**
     * @notice Withdraws accumulated protocol fees
     * 
     * @param to Destination address for the fees
     * 
     * @dev Fees accumulate during minting and redemptions
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function withdrawProtocolFees(address to) external onlyRole(GOVERNANCE_ROLE) {
        if (to == address(0)) revert CommonErrorLibrary.InvalidAddress();
        
        // Calculate available fees (excess USDC beyond what's needed for redemptions)
        uint256 contractBalance = usdc.balanceOf(address(this));
        if (contractBalance <= totalUsdcHeld) revert CommonErrorLibrary.InsufficientBalance();
        
        uint256 feesToWithdraw = contractBalance - totalUsdcHeld;
        usdc.safeTransfer(to, feesToWithdraw);
    }

    // =============================================================================
    // HEDGER POOL INTEGRATION - Functions for unified USDC liquidity management
    // =============================================================================

    /**
     * @notice Adds hedger USDC deposit to vault's total USDC reserves
     * @dev Called by HedgerPool when hedgers open positions to unify USDC liquidity
     * @param usdcAmount Amount of USDC deposited by hedger (6 decimals)
     * @custom:security Validates caller is HedgerPool contract and amount is positive
     * @custom:validation Validates amount > 0 and caller is authorized HedgerPool
     * @custom:state-changes Updates totalUsdcHeld with hedger deposit amount
     * @custom:events Emits HedgerDepositAdded with deposit details
     * @custom:errors Throws "Vault: Only HedgerPool can call" if caller is not HedgerPool
     * @custom:errors Throws "Vault: Amount must be positive" if amount is zero
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to HedgerPool contract only
     * @custom:oracle No oracle dependencies
     */
    function addHedgerDeposit(uint256 usdcAmount) external nonReentrant {
        if (msg.sender != address(hedgerPool)) revert CommonErrorLibrary.NotAuthorized();
        CommonValidationLibrary.validatePositiveAmount(usdcAmount);
        
        // Update vault's total USDC reserves
        unchecked {
            totalUsdcHeld += usdcAmount;
        }
        
        emit HedgerDepositAdded(msg.sender, usdcAmount, totalUsdcHeld);
    }

    /**
     * @notice Withdraws hedger USDC deposit from vault's reserves
     * @dev Called by HedgerPool when hedgers close positions to return their deposits
     * @param hedger Address of the hedger receiving the USDC
     * @param usdcAmount Amount of USDC to withdraw (6 decimals)
     * @custom:security Validates caller is HedgerPool, amount is positive, and sufficient reserves
     * @custom:validation Validates amount > 0, caller is authorized, and totalUsdcHeld >= amount
     * @custom:state-changes Updates totalUsdcHeld and transfers USDC to hedger
     * @custom:events Emits HedgerDepositWithdrawn with withdrawal details
     * @custom:errors Throws "Vault: Only HedgerPool can call" if caller is not HedgerPool
     * @custom:errors Throws "Vault: Amount must be positive" if amount is zero
     * @custom:errors Throws "Vault: Insufficient USDC reserves" if not enough USDC available
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to HedgerPool contract only
     * @custom:oracle No oracle dependencies
     */
    // SECURITY: Protected by nonReentrant modifier; external calls to configured adapters
    function withdrawHedgerDeposit(address hedger, uint256 usdcAmount) external nonReentrant {
        if (msg.sender != address(hedgerPool)) revert CommonErrorLibrary.NotAuthorized();
        CommonValidationLibrary.validatePositiveAmount(usdcAmount);
        if (hedger == address(0)) revert CommonErrorLibrary.InvalidAddress();
        
        // Check if total available USDC (vault + Aave) is sufficient
        uint256 totalAvailable = _getTotalCollateralWithAccruedYield();
        if (totalAvailable < usdcAmount) revert CommonErrorLibrary.InsufficientBalance();

        uint256 externalWithdrawalAmount = _planExternalVaultWithdrawal(usdcAmount);
        uint256 projectedHeld = totalUsdcHeld + externalWithdrawalAmount;
        if (projectedHeld < usdcAmount) revert CommonErrorLibrary.InsufficientBalance();
        totalUsdcHeld = projectedHeld - usdcAmount;

        if (externalWithdrawalAmount > 0) {
            _withdrawUsdcFromExternalVaults(externalWithdrawalAmount);
        }

        // INTERACTIONS
        usdc.safeTransfer(hedger, usdcAmount);
        
        emit HedgerDepositWithdrawn(hedger, usdcAmount, totalUsdcHeld);
    }

    /**
     * @notice Gets the total USDC available (vault + Aave)
     * @dev Returns total USDC that can be used for withdrawals/redemptions
     * @return uint256 Total USDC available (vault + Aave) (6 decimals)
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public access - anyone can query total USDC available
     * @custom:oracle No oracle dependencies
     */
    function getTotalUsdcAvailable() external view returns (uint256) {
        return _getTotalCollateralWithAccruedYield();
    }

    // =============================================================================
    // INTERNAL FUNCTIONS - Internal validation functions
    // =============================================================================

    /**
     * @notice Updates the price cache with the current oracle price
     * @dev Allows governance to manually refresh the price cache to prevent deviation check failures
     * @dev Useful when price has moved significantly and cache needs to be updated
     * @custom:security Only callable by governance role
     * @custom:validation Validates oracle price is valid before updating cache
     * @custom:state-changes Updates lastValidEurUsdPrice, lastPriceUpdateBlock, and lastPriceUpdateTime
     * @custom:events Emits PriceCacheUpdated event
     * @custom:errors Reverts if oracle price is invalid
     * @custom:reentrancy Not applicable - no external calls after state changes
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle Requires valid oracle price
     */
    // SECURITY: Protected by nonReentrant modifier; external call to trusted Oracle contract
    function updatePriceCache() external onlyRole(GOVERNANCE_ROLE) nonReentrant {
        // Cache old price before external call
        uint256 oldPrice = lastValidEurUsdPrice;
        
        // Get new oracle price
        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) revert CommonErrorLibrary.InvalidOraclePrice();

        this._applyPriceCacheUpdate(oldPrice, eurUsdPrice);
    }

    /**
     * @notice Applies a validated price cache update
     * @dev Commit-phase helper called via explicit self-call from `updatePriceCache`.
     * @param oldPrice Previous cached EUR/USD price
     * @param eurUsdPrice New validated EUR/USD price
     * @custom:security Restricted by `onlySelf`
     * @custom:validation Assumes caller already validated oracle output
     * @custom:state-changes Updates `lastValidEurUsdPrice`, `lastPriceUpdateBlock`, and `lastPriceUpdateTime`
     * @custom:events Emits `PriceCacheUpdated`
     * @custom:errors None
     * @custom:reentrancy No external calls
     * @custom:access External self-call entrypoint only
     * @custom:oracle No direct oracle reads (uses pre-validated input)
     */
    function _applyPriceCacheUpdate(uint256 oldPrice, uint256 eurUsdPrice) external onlySelf {
        // EFFECTS - Update all state before emitting event.
        lastValidEurUsdPrice = eurUsdPrice;
        lastPriceUpdateBlock = block.number;
        lastPriceUpdateTime = _protocolTime();
        emit PriceCacheUpdated(oldPrice, eurUsdPrice, block.number);
    }

    /**
     * @notice Updates the last valid price timestamp when a valid price is fetched
     * @param isValid Whether the current price fetch was valid
     * @dev Internal function to track price update timing for monitoring
     * @custom:security Updates timestamp only for valid price fetches
     * @custom:validation No input validation required
     * @custom:state-changes Updates lastPriceUpdateTime if price is valid
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - internal function only
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _updatePriceTimestamp(bool isValid) internal {
        if (isValid) {
            lastPriceUpdateTime = _protocolTime();
        }
    }

    /**
     * @notice Computes aggregate external-vault collateral balance including accrued yield.
     * @dev Reads adapter `totalUnderlying` values with principal fallback on read failure.
     * @return externalCollateral Total external collateral balance in USDC units.
     * @custom:security Internal read helper.
     * @custom:validation Uses fallback to tracked principal when adapter reads fail.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors No explicit errors; read failures are handled via fallback.
     * @custom:reentrancy Not applicable for view helper.
     * @custom:access Internal helper.
     * @custom:oracle No oracle dependencies.
     */
    function _getExternalVaultCollateralBalance() internal view returns (uint256 externalCollateral) {
        uint256[] memory priority = redemptionPriorityVaultIds;
        if (priority.length == 0 && defaultStakingVaultId != 0) {
            IExternalStakingVault defaultAdapter = stakingVaultAdapterById[defaultStakingVaultId];
            uint256 principalTracked = principalUsdcByVaultId[defaultStakingVaultId];
            if (address(defaultAdapter) == address(0)) return principalTracked;
            try defaultAdapter.totalUnderlying() returns (uint256 currentBalance) {
                return currentBalance;
            } catch {
                return principalTracked;
            }
        }
        for (uint256 i = 0; i < priority.length; ++i) {
            uint256 vaultId = priority[i];
            IExternalStakingVault adapter = stakingVaultAdapterById[vaultId];
            if (address(adapter) == address(0)) continue;
            uint256 principalTracked = principalUsdcByVaultId[vaultId];
            try adapter.totalUnderlying() returns (uint256 currentBalance) {
                externalCollateral += currentBalance;
            } catch {
                externalCollateral += principalTracked;
            }
        }
    }

    /**
     * @notice Returns total collateral available including held and external-vault balances.
     * @dev Sum of `totalUsdcHeld` and `_getExternalVaultCollateralBalance()`.
     * @return Total collateral in USDC units.
     * @custom:security Internal read helper.
     * @custom:validation No input validation required.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors Propagates unexpected view-read errors.
     * @custom:reentrancy Not applicable for view helper.
     * @custom:access Internal helper.
     * @custom:oracle No direct oracle dependency.
     */
    function _getTotalCollateralWithAccruedYield() internal view returns (uint256) {
        return totalUsdcHeld + _getExternalVaultCollateralBalance();
    }

    /**
     * @notice MED-2: routes protocol fees between HedgerPool reserve and FeeCollector at source.
     * @dev Splits fee flow using `hedgerRewardFeeSplit` and transfers shares to each destination.
     * @param fee Total fee amount in USDC (6 decimals).
     * @param sourceType Source tag passed through to FeeCollector accounting.
     * @custom:security Validates required dependency addresses before routing each share.
     * @custom:validation No-op when `fee == 0`; reverts on unset required destinations.
     * @custom:state-changes Increases allowances and forwards fee shares to HedgerPool/FeeCollector.
     * @custom:events Emits `ProtocolFeeRouted`.
     * @custom:errors Reverts when HedgerPool/FeeCollector dependencies are unset for non-zero shares.
     * @custom:reentrancy Internal function; external calls are to configured protocol dependencies.
     * @custom:access Internal helper.
     * @custom:oracle No oracle interaction.
     */
    function _routeProtocolFees(uint256 fee, string memory sourceType) internal {
        if (fee == 0) return;

        uint256 hedgerReserveShare = fee.mulDiv(hedgerRewardFeeSplit, 1e18);
        uint256 collectorShare = fee - hedgerReserveShare;

        if (hedgerReserveShare > 0) {
            if (address(hedgerPool) == address(0)) revert CommonErrorLibrary.InvalidVault();
            usdc.safeIncreaseAllowance(address(hedgerPool), hedgerReserveShare);
            hedgerPool.fundRewardReserve(hedgerReserveShare);
        }

        if (collectorShare > 0) {
            if (feeCollector == address(0)) revert CommonErrorLibrary.ZeroAddress();
            usdc.safeIncreaseAllowance(feeCollector, collectorShare);
            FeeCollector(feeCollector).collectFees(address(usdc), collectorShare, sourceType);
        }

        emit ProtocolFeeRouted(sourceType, fee, hedgerReserveShare, collectorShare);
    }

    
    /**
     * @notice Calculates the current protocol collateralization ratio.
     * @dev Formula: `CR = (TotalCollateral / BackingRequirement) * 1e20`
     *
     * Where:
     * - `TotalCollateral = totalUsdcHeld + currentAaveCollateral` (includes accrued Aave yield when available)
     * - `BackingRequirement = QEUROSupply * cachedEurUsdPrice / 1e30` (USDC value of outstanding debt)
     *
     * Returns ratio in 18-decimal percentage format:
     * - `100% = 1e20`
     * - `101% = 1.01e20`
     *
     * @return ratio Current collateralization ratio in 18-decimal percentage format
     * @custom:security View function using cached price and current collateral state
     * @custom:validation Returns 0 if pools are unset, supply is 0, or price cache is uninitialized
     * @custom:state-changes None
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can check collateralization ratio
     * @custom:oracle Uses cached oracle price (`lastValidEurUsdPrice`)
     */
    function getProtocolCollateralizationRatio() public view returns (uint256 ratio) {
        // Check if both HedgerPool and UserPool are set
        if (address(hedgerPool) == address(0) || address(userPool) == address(0)) {
            return 0;
        }

        // Get current QEURO supply for denominator calculation
        uint256 currentQeuroSupply = qeuro.totalSupply();
        if (currentQeuroSupply == 0) {
            return 0;
        }

        if (lastValidEurUsdPrice == 0) return 0;
        uint256 backingRequirement = currentQeuroSupply.mulDiv(lastValidEurUsdPrice, 1e18) / 1e12;
        if (backingRequirement == 0) return 0;

        uint256 totalCollateral = _getTotalCollateralWithAccruedYield();
        ratio = (totalCollateral * 1e20) / backingRequirement;
    }
    
    /**
     * @notice Checks if minting is allowed based on current collateralization ratio
     * @dev Returns true if collateralization ratio >= minCollateralizationRatioForMinting
     * @return canMint Whether minting is currently allowed
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted - view function
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can check minting status
     * @custom:oracle No oracle dependencies
     */
    function canMint() public view returns (bool) {
        // LOW-5: minting requires initialized cached oracle price.
        if (lastValidEurUsdPrice == 0) return false;
        // INFO-2 safeguard: require configured and active single hedger before minting.
        if (address(hedgerPool) == address(0) || !hedgerPool.hasActiveHedger()) return false;

        uint256 currentQeuroSupply = qeuro.totalSupply();
        if (currentQeuroSupply == 0) {
            return true;
        }

        uint256 currentRatio = getProtocolCollateralizationRatio();
        return currentRatio >= minCollateralizationRatioForMinting;
    }
    
    /**
     * @notice LOW-4: Pure view variant of getProtocolCollateralizationRatio using cached oracle price.
     * @dev Delegates to `getProtocolCollateralizationRatio()` and performs no state refresh.
     * @return ratio Current collateralization ratio in 1e18-scaled percentage format.
     * @custom:security View-only wrapper.
     * @custom:validation Inherits validation/fallback behavior from delegated function.
     * @custom:state-changes None - view function.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable - view function.
     * @custom:access Public.
     * @custom:oracle Uses cached oracle price.
     */
    /**
     * @notice LOW-5: Seeds the oracle price cache so minting checks have a baseline.
     * @dev Governance MUST call this once immediately after deployment, before any user mints.
     *      Uses an explicit bootstrap price to avoid external oracle interaction in this state-changing call.
     * @param initialEurUsdPrice Initial EUR/USD price in 18 decimals.
     * @custom:security Restricted to governance.
     * @custom:validation Requires `initialEurUsdPrice > 0`.
     * @custom:state-changes Sets `lastValidEurUsdPrice`, `lastPriceUpdateBlock`, and `lastPriceUpdateTime`.
     * @custom:events Emits `PriceCacheUpdated`.
     * @custom:errors Reverts when price is zero or cache is already initialized.
     * @custom:reentrancy Not applicable - no external callbacks.
     * @custom:access Restricted to `GOVERNANCE_ROLE`.
     * @custom:oracle Bootstrap input should come from governance/oracle process.
     */
    function initializePriceCache(uint256 initialEurUsdPrice) external onlyRole(GOVERNANCE_ROLE) {
        if (initialEurUsdPrice == 0) revert CommonErrorLibrary.InvalidAmount();
        if (lastValidEurUsdPrice != 0) revert CommonErrorLibrary.NoChangeDetected();

        lastValidEurUsdPrice = initialEurUsdPrice;
        lastPriceUpdateBlock = block.number;
        lastPriceUpdateTime = _protocolTime();
        emit PriceCacheUpdated(0, initialEurUsdPrice, block.number);
    }

    /**
     * @notice Checks if liquidation should be triggered based on current collateralization ratio
     * @dev Returns true if collateralization ratio < criticalCollateralizationRatio
     * @return shouldLiquidate Whether liquidation should be triggered
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted - view function
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can check liquidation status
     * @custom:oracle No oracle dependencies
     */
    function shouldTriggerLiquidation() public view returns (bool shouldLiquidate) {
        uint256 currentRatio = getProtocolCollateralizationRatio();
        return currentRatio < criticalCollateralizationRatio;
    }

    /**
     * @notice Returns liquidation status and key metrics for pro-rata redemption
     * @dev Protocol enters liquidation mode when CR <= 101%. In this mode, users can redeem pro-rata.
     * @return isInLiquidation True if protocol is in liquidation mode (CR <= 101%)
     * @return collateralizationRatioBps Current collateralization ratio in basis points (e.g., 10100 = 101%)
     * @return totalCollateralUsdc Total protocol collateral in USDC (6 decimals)
     * @return totalQeuroSupply Total QEURO supply (18 decimals)
     * @custom:security View function - no state changes
     * @custom:validation No input validation required
     * @custom:state-changes None - view function
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can check liquidation status
     * @custom:oracle Requires oracle price for collateral calculation
     */

    // =============================================================================
    // EMERGENCY FUNCTIONS - Emergency functions
    // =============================================================================

    /**
     * @notice Pauses all vault operations
     * 
     * @dev When paused:
     *      - No mint/redeem possible
     *      - Read functions still active
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses and resumes operations
     * @dev Resumes all vault operations after emergency pause
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }



    // =============================================================================
    // UPGRADE AND RECOVERY - Upgrades and recovery
    // =============================================================================



    /**
     * @notice Recovers tokens accidentally sent to the vault to treasury only
     * 
     * @param token Token contract address
     * @param amount Amount to recover
     * 
     * @dev Protections:
     *      - Cannot recover own vault tokens
     *      - Tokens are sent to treasury address only
     *      - Only third-party tokens can be recovered
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependencies
     */
    function recoverToken(
        address token,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Use the shared library for secure token recovery to treasury
        TreasuryRecoveryLibrary.recoverToken(token, amount, address(this), treasury);
    }

    /**
     * @notice Recover ETH to treasury address only
     * @dev SECURITY: Restricted to treasury to prevent arbitrary ETH transfers
     * 
     * @dev Security considerations:
     *      - Only DEFAULT_ADMIN_ROLE can recover
     *      - Prevents sending to zero address
     *      - Validates balance before attempting transfer
     *      - Uses call() for reliable ETH transfers to any contract
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function recoverETH() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (treasury == address(0)) revert CommonErrorLibrary.InvalidAddress();
        uint256 balance = address(this).balance;
        if (balance < 1) revert CommonErrorLibrary.NoETHToRecover();
        payable(treasury).sendValue(balance);
    }

    /**
     * @notice Internal helper to notify HedgerPool about user mints.
     * @dev LOW-5 / INFO-2: mint path must fail if hedger synchronization fails.
     * @param amount Gross USDC amount allocated to hedger fills (6 decimals).
     * @param fillPrice EUR/USD price used for fill accounting (18 decimals).
     * @param qeuroAmount QEURO minted amount to track against hedger exposure (18 decimals).
     * @custom:security Internal hard-fail synchronization helper.
     * @custom:validation No-op on zero amount; otherwise requires downstream HedgerPool success.
     * @custom:state-changes No direct state changes in vault; delegates accounting updates to HedgerPool.
     * @custom:events None in vault.
     * @custom:errors Propagates HedgerPool reverts to preserve atomicity.
     * @custom:reentrancy Not applicable - internal helper.
     * @custom:access Internal helper.
     * @custom:oracle Uses provided cached/fetched fill price from caller context.
     */
    function _syncMintWithHedgersOrRevert(uint256 amount, uint256 fillPrice, uint256 qeuroAmount) internal {
        if (amount == 0) return;
        hedgerPool.recordUserMint(amount, fillPrice, qeuroAmount);
    }

    /**
     * @notice Internal helper to notify HedgerPool about user redeems
     * @dev Attempts to release hedger fills but swallows failures to avoid blocking users
     * @param amount Gross USDC returned to the user (6 decimals)
     * @param redeemPrice EUR/USD oracle price used for the redeem (18 decimals)
     * @param qeuroAmount QEURO amount that was redeemed (18 decimals)
     * @custom:security Internal helper; relies on HedgerPool access control
     * @custom:validation No additional validation beyond non-zero guard
     * @custom:state-changes None inside the vault; delegates to HedgerPool
     * @custom:events None
     * @custom:errors Silently ignores downstream errors
     * @custom:reentrancy Not applicable
     * @custom:access Internal helper
     * @custom:oracle Not applicable
     */
    function _syncRedeemWithHedgers(uint256 amount, uint256 redeemPrice, uint256 qeuroAmount) internal {
        if (amount == 0) {
            return;
        }
        try hedgerPool.recordUserRedeem(amount, redeemPrice, qeuroAmount) {} catch (bytes memory reason) {
            emit HedgerSyncFailed("redeem", amount, redeemPrice, reason);
        }
    }

    // =============================================================================
    // ADVANCED VIEW FUNCTIONS - Advanced read functions
    // =============================================================================





    /// @notice Variable to store the timestamp of the last valid price update
    uint256 private lastPriceUpdateTime;

    /**
     * @notice Toggles dev mode to disable price caching requirements
     * @dev DEV ONLY: When enabled, price deviation checks are skipped for testing
     * @param enabled True to enable dev mode, false to disable
     * @custom:security Only callable by DEFAULT_ADMIN_ROLE
     * @custom:validation No input validation required
     * @custom:state-changes Updates devModeEnabled flag
     * @custom:events Emits DevModeToggled event
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - simple state change
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependencies
     */
    /// @notice MED-1: Propose a dev-mode change; enforces a 48-hour timelock before it can be applied
    /// @param enabled The desired dev-mode value
    function proposeDevMode(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        pendingDevMode = enabled;
        devModePendingAt = block.number + DEV_MODE_DELAY_BLOCKS;
        emit DevModeProposed(enabled, devModePendingAt);
    }

    /**
     * @notice MED-1: Apply a previously proposed dev-mode change after the timelock has elapsed.
     * @dev Finalizes the pending proposal created by `proposeDevMode`.
     * @custom:security Restricted to default admin and time-locked via `DEV_MODE_DELAY`.
     * @custom:validation Requires active pending proposal and elapsed delay.
     * @custom:state-changes Updates `devModeEnabled` and clears `devModePendingAt`.
     * @custom:events Emits `DevModeToggled`.
     * @custom:errors Reverts when no proposal is pending or delay is not satisfied.
     * @custom:reentrancy Not applicable - simple state transition.
     * @custom:access Restricted to `DEFAULT_ADMIN_ROLE`.
     * @custom:oracle No oracle interaction.
     */
    function applyDevMode() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (devModePendingAt == 0) revert CommonErrorLibrary.InvalidAmount();
        if (block.number < devModePendingAt) revert CommonErrorLibrary.NotActive();
        devModeEnabled = pendingDevMode;
        devModePendingAt = 0;
        emit DevModeToggled(devModeEnabled, msg.sender);
    }
}

// =============================================================================
// END OF QUANTILLONVAULT CONTRACT
// =============================================================================
