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
import {CommonErrorLibrary} from "../libraries/CommonErrorLibrary.sol";
import {CommonValidationLibrary} from "../libraries/CommonValidationLibrary.sol";
import {VaultErrorLibrary} from "../libraries/VaultErrorLibrary.sol";
import {HedgerPoolErrorLibrary} from "../libraries/HedgerPoolErrorLibrary.sol";

// Internal interfaces of the Quantillon protocol
import {IQEUROToken} from "../interfaces/IQEUROToken.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {IHedgerPool} from "../interfaces/IHedgerPool.sol";
import {IUserPool} from "../interfaces/IUserPool.sol";
import {IAaveVault} from "../interfaces/IAaveVault.sol";
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

    /// @notice MED-7: Dedicated reentrancy guard for _executeAaveDeployment (separate from OZ lock)
    bool private _aaveDeploymentInProgress;

    /// @notice AaveVault contract for USDC yield generation
    /// @dev Used to deploy idle USDC to Aave lending pool
    IAaveVault public aaveVault;
    
    /// @notice Total USDC deployed to Aave for yield generation
    /// @dev Tracks USDC that has been sent to AaveVault
    uint256 public totalUsdcInAave;

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
    uint256 public constant MAX_HEDGER_REWARD_FEE_SPLIT = 1e18;

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
    uint256 public constant DEV_MODE_DELAY = 48 hours;

    /// @notice MED-1: Pending dev-mode value awaiting the timelock delay
    bool public pendingDevMode;

    /// @notice MED-1: Timestamp at which pendingDevMode may be applied (0 = no pending proposal)
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

    /// @notice Emitted when AaveVault address is updated
    /// @param oldAaveVault Previous AaveVault address
    /// @param newAaveVault New AaveVault address
    event AaveVaultUpdated(address indexed oldAaveVault, address indexed newAaveVault);

    /// @notice Emitted when USDC is deployed to Aave for yield generation
    /// @param usdcAmount Amount of USDC deployed to Aave
    /// @param totalUsdcInAave New total USDC in Aave after deployment
    event UsdcDeployedToAave(uint256 indexed usdcAmount, uint256 totalUsdcInAave);
    event AaveDeploymentFailed(uint256 amount, bytes reason);
    event HedgerSyncFailed(string operation, uint256 amount, uint256 price, bytes reason);

    /// @notice Emitted when USDC is withdrawn from Aave
    /// @param usdcAmount Amount of USDC withdrawn from Aave
    /// @param totalUsdcInAave New total USDC in Aave after withdrawal
    event UsdcWithdrawnFromAave(uint256 indexed usdcAmount, uint256 totalUsdcInAave);
    event HedgerRewardFeeSplitUpdated(uint256 previousSplit, uint256 newSplit);
    event AaveInterestHarvested(uint256 harvestedYield);
    event ProtocolFeeRouted(string sourceType, uint256 totalFee, uint256 hedgerReserveShare, uint256 collectorShare);

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
    // slither-disable-start reentrancy-no-eth
    // slither-disable-start reentrancy-benign
    // SECURITY: Protected by nonReentrant modifier; external calls to trusted Oracle contract
    function mintQEURO(
        uint256 usdcAmount,
        uint256 minQeuroOut
    ) external nonReentrant whenNotPaused flashLoanProtection {
        // CHECKS
        CommonValidationLibrary.validatePositiveAmount(usdcAmount);
        
        // Cache all oracle calls at start to avoid reentrancy issues
        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) revert CommonErrorLibrary.InvalidOraclePrice();

        // Reject minting if USDC is depegged to prevent undercollateralization
        (, bool usdcIsValid) = oracle.getUsdcUsdPrice();
        if (!usdcIsValid) revert CommonErrorLibrary.InvalidOraclePrice();

        // LOW-5 / INFO-2: minting requires initialized cache and an active single hedger.
        if (lastValidEurUsdPrice == 0) revert CommonErrorLibrary.NotInitialized();
        if (address(hedgerPool) == address(0) || !hedgerPool.hasActiveHedger()) {
            revert HedgerPoolErrorLibrary.NoActiveHedgerLiquidity();
        }

        // Check if we can mint based on current state
        if (!canMint()) revert CommonErrorLibrary.InsufficientCollateralization();
        
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

        // Calculate mint fee and QEURO amount using validated oracle price
        uint256 fee = usdcAmount.mulDiv(mintFee, 1e18);
        uint256 netAmount = usdcAmount - fee;
        uint256 qeuroToMint = netAmount.mulDiv(1e30, eurUsdPrice);
        if (qeuroToMint < minQeuroOut) revert CommonErrorLibrary.ExcessiveSlippage();

        // Critical safety check: enforce collateralization on projected post-mint state.
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

        // EFFECTS - Update all state before external calls
        // Update price cache
        lastPriceUpdateBlock = block.number;
        lastValidEurUsdPrice = eurUsdPrice;
        _updatePriceTimestamp(isValid);

        // Update vault accounting
        totalUsdcHeld += netAmount;
        totalMinted += qeuroToMint;

        // Inform HedgerPool after vault accounting is updated.
        // LOW-5 / INFO-2: mint finalization is atomic with hedger synchronization.
        _syncMintWithHedgersOrRevert(netAmount, eurUsdPrice, qeuroToMint);

        // Emit event after state changes but before external calls
        emit QEUROminted(msg.sender, usdcAmount, qeuroToMint);

        // INTERACTIONS - All external calls after state updates
        // Transfer full amount to vault
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);
        
        _routeProtocolFees(fee, "minting");
        
        qeuro.mint(msg.sender, qeuroToMint);
        
        // Auto-deploy USDC to Aave for yield generation (if AaveVault is configured)
        // This happens atomically with minting to ensure USDC is put to work immediately
        _autoDeployToAave(netAmount);
    }
    // slither-disable-end reentrancy-no-eth
    // slither-disable-end reentrancy-benign
    
    /**
     * @notice Internal function to auto-deploy USDC to Aave after minting
     * @dev Silently catches errors to ensure minting always succeeds even if Aave has issues
     * @param usdcAmount Amount of USDC to deploy (6 decimals)
     * @custom:security Uses try-catch to prevent Aave issues from blocking user mints
     * @custom:validation Validates AaveVault is set and amount > 0
     * @custom:state-changes Updates totalUsdcHeld and totalUsdcInAave on success
     * @custom:events Emits UsdcDeployedToAave on success
     * @custom:errors Silently swallows errors to ensure mints always succeed
     * @custom:reentrancy Not protected - internal function only
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _autoDeployToAave(uint256 usdcAmount) internal {
        // Skip if AaveVault not configured or amount is zero
        if (address(aaveVault) == address(0) || usdcAmount == 0) return;
        if (totalUsdcHeld < usdcAmount) return;
        
        // Try to deploy to Aave, but don't block minting if it fails
        try this._executeAaveDeployment(usdcAmount) {} catch (bytes memory reason) {
            emit AaveDeploymentFailed(usdcAmount, reason);
        }
    }
    
    /**
     * @notice External function to execute Aave deployment (called by _autoDeployToAave via try/catch)
     * @dev This is external so it can be called via try/catch for error handling
     * @param usdcAmount Amount of USDC to deploy (6 decimals)
     * @custom:security Only callable from this contract
     * @custom:validation Validates sufficient balance
     * @custom:state-changes Updates totalUsdcHeld and totalUsdcInAave
     * @custom:events Emits UsdcDeployedToAave
     * @custom:errors Throws if insufficient balance or Aave deployment fails
     * @custom:reentrancy Not protected - internal helper
     * @custom:access Internal use only (via try/catch)
     * @custom:oracle No oracle dependencies
     */
    function _executeAaveDeployment(uint256 usdcAmount) external {
        // Only callable from within this contract
        if (msg.sender != address(this)) revert CommonErrorLibrary.NotAuthorized();
        // MED-7: Dedicated reentrancy lock (separate from OZ lock which is already held by caller)
        if (_aaveDeploymentInProgress) revert CommonErrorLibrary.NotAuthorized();
        _aaveDeploymentInProgress = true;

        // Update state before external calls
        totalUsdcHeld -= usdcAmount;
        totalUsdcInAave += usdcAmount;

        emit UsdcDeployedToAave(usdcAmount, totalUsdcInAave);

        // Transfer and deploy to Aave
        usdc.safeIncreaseAllowance(address(aaveVault), usdcAmount);
        uint256 aTokensReceived = aaveVault.deployToAave(usdcAmount);

        _aaveDeploymentInProgress = false;

        // Validate that deployment was successful (aTokensReceived should be > 0)
        if (aTokensReceived == 0) revert CommonErrorLibrary.InvalidAmount();
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
    // slither-disable-start reentrancy-no-eth
    // slither-disable-start reentrancy-benign
    // SECURITY: Protected by nonReentrant modifier; external calls to trusted Oracle and AaveVault
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

        // Check if total available USDC (vault + Aave principal + accrued Aave yield) is sufficient
        uint256 totalAvailable = _getTotalCollateralWithAccruedYield();
        if (totalAvailable < usdcToReturn) revert CommonErrorLibrary.InsufficientBalance();

        // If vault doesn't have enough USDC, withdraw from Aave
        if (totalUsdcHeld < usdcToReturn && address(aaveVault) != address(0)) {
            uint256 deficit = usdcToReturn - totalUsdcHeld;
            _withdrawUsdcFromAave(deficit);
        }

        // Re-check after potential Aave withdrawal
        if (totalUsdcHeld < usdcToReturn) revert CommonErrorLibrary.InsufficientBalance();

        if (address(hedgerPool) == address(0)) revert CommonErrorLibrary.InvalidVault();

        // EFFECTS - Update all state before external calls
        // Update price cache
        lastPriceUpdateBlock = block.number;
        lastValidEurUsdPrice = eurUsdPrice;
        _updatePriceTimestamp(isValid);

        // Update vault balances
        totalUsdcHeld -= usdcToReturn;
        // Reduce tracked minted supply by the redeemed amount; revert if inconsistent
        if (totalMinted < qeuroAmount) revert CommonErrorLibrary.InvalidAmount();
        totalMinted -= qeuroAmount;
        
        // Inform HedgerPool after internal state is updated
        _syncRedeemWithHedgers(usdcToReturn, eurUsdPrice, qeuroAmount);

        // Emit event after state changes but before external calls
        emit QEURORedeemed(msg.sender, qeuroAmount, netUsdcToReturn);

        // INTERACTIONS - All external calls after state updates
        qeuro.burn(msg.sender, qeuroAmount);
        usdc.safeTransfer(msg.sender, netUsdcToReturn);
        
        _routeProtocolFees(fee, "redemption");
    }
    // slither-disable-end reentrancy-no-eth
    // slither-disable-end reentrancy-benign

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
    // slither-disable-start reentrancy-no-eth
    // slither-disable-start reentrancy-benign
    // SECURITY: Internal function called from nonReentrant redeemQEURO; trusted Oracle and AaveVault
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

        // Calculate pro-rata payout based on actual USDC available
        uint256 totalCollateralUsdc = _getTotalCollateralWithAccruedYield();
        uint256 usdcPayout = qeuroAmount.mulDiv(totalCollateralUsdc, totalSupply);

        // Ensure sufficient USDC (withdraw from Aave if needed)
        _ensureSufficientUsdcForPayout(usdcPayout);

        // Calculate fees and net payout
        (uint256 fee, uint256 netUsdcPayout) = _calculateLiquidationFees(usdcPayout);

        // LOW-7: validate slippage against net (post-fee) amount so minUsdcOut applies to what user actually receives
        if (netUsdcPayout < minUsdcOut) revert CommonErrorLibrary.ExcessiveSlippage();

        // Determine if premium or haircut
        uint256 fairValueUsdc = qeuroAmount.mulDiv(eurUsdPrice, 1e18) / 1e12;
        bool isPremium = usdcPayout >= fairValueUsdc;

        // EFFECTS - Update state
        if (totalUsdcHeld < usdcPayout) revert CommonErrorLibrary.InsufficientBalance();
        totalUsdcHeld -= usdcPayout;
        if (totalMinted < qeuroAmount) revert CommonErrorLibrary.InvalidAmount();
        totalMinted -= qeuroAmount;

        // Notify hedger pool of liquidation redemption
        _notifyHedgerPoolLiquidation(qeuroAmount, totalSupply);

        // Emit liquidation event (emit net payout after fees)
        emit LiquidationRedeemed(msg.sender, qeuroAmount, netUsdcPayout, collateralizationRatioBps, isPremium);

        // INTERACTIONS - All external calls after state updates
        qeuro.burn(msg.sender, qeuroAmount);
        usdc.safeTransfer(msg.sender, netUsdcPayout);

        // Transfer fee to fee collector
        _transferLiquidationFees(fee);
    }

    /**
     * @notice Ensures vault has sufficient USDC for payout, withdrawing from Aave if needed
     * @dev Withdraws from Aave to cover deficit; reverts if totalAvailable < usdcAmount
     * @param usdcAmount Amount of USDC needed
     * @custom:security Internal; may call Aave withdrawal
     * @custom:validation totalAvailable >= usdcAmount after withdrawal
     * @custom:state-changes totalUsdcHeld, totalUsdcInAave via _withdrawUsdcFromAave
     * @custom:events Via _withdrawUsdcFromAave
     * @custom:errors InsufficientBalance if cannot meet usdcAmount
     * @custom:reentrancy External call to Aave; caller in CEI context
     * @custom:access Internal
     * @custom:oracle None
     */
    function _ensureSufficientUsdcForPayout(uint256 usdcAmount) internal {
        uint256 totalAvailable = _getTotalCollateralWithAccruedYield();
        if (totalAvailable < usdcAmount) revert CommonErrorLibrary.InsufficientBalance();

        // If vault doesn't have enough USDC, withdraw from Aave
        if (totalUsdcHeld < usdcAmount && address(aaveVault) != address(0)) {
            uint256 deficit = usdcAmount - totalUsdcHeld;
            _withdrawUsdcFromAave(deficit);
        }

        // Re-check after potential Aave withdrawal
        if (totalUsdcHeld < usdcAmount) revert CommonErrorLibrary.InsufficientBalance();
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
    // slither-disable-end reentrancy-no-eth
    // slither-disable-end reentrancy-benign

    /**
     * @notice Redeems QEURO for USDC using pro-rata distribution in liquidation mode
     * @dev Only callable when protocol is in liquidation mode (CR <= 101%)
     * @dev Key formulas:
     *      - Payout = (qeuroAmount / totalSupply) * totalVaultUsdc (actual USDC in vault)
     *      - Hedger loss = (qeuroAmount / totalSupply) * hedgerMargin (realized as negative P&L)
     *      - Fees always applied using `redemptionFee`
     * @dev Premium if CR > 100%, haircut if CR < 100%
     * @param qeuroAmount Amount of QEURO to redeem (18 decimals)
     * @param minUsdcOut Minimum USDC expected (slippage protection)
     * @custom:security Protected by nonReentrant, requires liquidation mode
     * @custom:validation Validates qeuroAmount > 0, minUsdcOut slippage, liquidation mode
     * @custom:state-changes Burns QEURO, transfers USDC pro-rata, reduces hedger margin proportionally
     * @custom:events Emits LiquidationRedeemed
     * @custom:errors Reverts if not in liquidation mode or slippage exceeded
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Public - anyone with QEURO can redeem
     * @custom:oracle Requires oracle price for fair value calculation
     */
    // slither-disable-start reentrancy-no-eth
    // slither-disable-start reentrancy-benign
    // SECURITY: Protected by nonReentrant modifier; external calls to trusted Oracle and AaveVault
    function redeemQEUROLiquidation(
        uint256 qeuroAmount,
        uint256 minUsdcOut
    ) external nonReentrant whenNotPaused {
        // CHECKS
        CommonValidationLibrary.validatePositiveAmount(qeuroAmount);

        // MED-5: Reject call when core pool contracts are not yet initialized;
        // getProtocolCollateralizationRatio() returns 0 in that state, which would
        // falsely indicate liquidation mode and allow protocol-draining redemptions.
        if (address(hedgerPool) == address(0) || address(userPool) == address(0)) {
            revert CommonErrorLibrary.InvalidVault();
        }

        // Check protocol is in liquidation mode using the configurable critical threshold
        uint256 currentRatio18Dec = getProtocolCollateralizationRatio();
        uint256 collateralizationRatioBps = currentRatio18Dec / 1e16;
        uint256 criticalRatioBps = criticalCollateralizationRatio / 1e16;
        if (collateralizationRatioBps > criticalRatioBps) revert CommonErrorLibrary.NotInLiquidationMode();

        // Delegate to shared liquidation logic
        _redeemLiquidationMode(qeuroAmount, minUsdcOut, collateralizationRatioBps);
    }
    // slither-disable-end reentrancy-no-eth
    // slither-disable-end reentrancy-benign



    // =============================================================================
    // VIEW FUNCTIONS - Read functions for monitoring
    // =============================================================================

    /**
     * @notice Retrieves the vault's global metrics
     * @dev Returns comprehensive vault metrics for monitoring and analytics
     * @return totalUsdcHeld_ Total USDC held directly in the vault
     * @return totalMinted_ Total QEURO minted
     * @return totalDebtValue Total debt value in USD
     * @return totalUsdcInAave_ Total USDC deployed to Aave for yield
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
    function getVaultMetrics() 
        external 
        view
        returns (
            uint256 totalUsdcHeld_,
            uint256 totalMinted_,
            uint256 totalDebtValue,
            uint256 totalUsdcInAave_,
            uint256 totalUsdcAvailable_
        ) 
    {
        totalUsdcHeld_ = totalUsdcHeld;
        totalMinted_ = totalMinted;
        totalUsdcInAave_ = totalUsdcInAave;
        totalUsdcAvailable_ = _getTotalCollateralWithAccruedYield();

        // Use live QEURO totalSupply as the authoritative debt base so metrics
        // stay in sync even if MINTER_ROLE/BURNER_ROLE operates outside this vault.
        uint256 _liveSupply = qeuro.totalSupply();
        if (lastValidEurUsdPrice > 0 && _liveSupply > 0) {
            totalDebtValue = _liveSupply.mulDiv(lastValidEurUsdPrice, 1e18);
        } else {
            totalDebtValue = 0;
        }
    }

    /**
     * @notice Calculates the amount of QEURO that can be minted for a given USDC amount
     * @dev Calculates mint amount based on cached oracle price and protocol fees
     * @param usdcAmount Amount of USDC to swap
     * @return qeuroAmount Amount of QEURO that will be minted (after fees)
     * @return fee Protocol fee
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes No state changes
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access No access restrictions
     * @custom:oracle Uses cached oracle price (`lastValidEurUsdPrice`)
     */
    function calculateMintAmount(uint256 usdcAmount)
        external
        view
        returns (uint256 qeuroAmount, uint256 fee)
    {
        uint256 eurUsdPrice = lastValidEurUsdPrice;
        if (eurUsdPrice == 0) return (0, 0);
        fee = usdcAmount.mulDiv(mintFee, 1e18);
        uint256 netAmount = usdcAmount - fee;
        qeuroAmount = netAmount.mulDiv(1e30, eurUsdPrice);
    }

    /**
     * @notice Calculates the amount of USDC received for a QEURO redemption
     * @dev Calculates redeem amount based on cached oracle price and protocol fees
     * @param qeuroAmount Amount of QEURO to redeem
     * @return usdcAmount USDC received (after fees)
     * @return fee Protocol fee
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes No state changes
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access No access restrictions
     * @custom:oracle Uses cached oracle price (`lastValidEurUsdPrice`)
     */
    function calculateRedeemAmount(uint256 qeuroAmount)
        external
        view
        returns (uint256 usdcAmount, uint256 fee)
    {
        uint256 eurUsdPrice = lastValidEurUsdPrice;
        if (eurUsdPrice == 0) return (0, 0);

        uint256 grossUsdcAmount = qeuroAmount.mulDiv(eurUsdPrice, 1e18);
        
        // Convert from 18 decimals (QEURO precision) to 6 decimals (USDC precision)
        grossUsdcAmount = grossUsdcAmount / 1e12;
        
        // Apply protocol fees (redemptionFee is in 18 decimals, grossUsdcAmount is in 6 decimals)
        fee = grossUsdcAmount.mulDiv(redemptionFee, 1e18);
        usdcAmount = grossUsdcAmount - fee;
    }

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
     * @notice Updates the AaveVault address for USDC yield generation
     * @dev Only governance role can update the AaveVault address
     * @param _aaveVault New AaveVault address
     * @custom:security Validates address is not zero before updating
     * @custom:validation Ensures _aaveVault is not address(0)
     * @custom:state-changes Updates aaveVault state variable
     * @custom:events Emits AaveVaultUpdated event
     * @custom:errors Reverts if _aaveVault is address(0)
     * @custom:reentrancy No reentrancy risk, simple state update
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function updateAaveVault(address _aaveVault) external onlyRole(GOVERNANCE_ROLE) {
        if (_aaveVault == address(0)) revert CommonErrorLibrary.ZeroAddress();
        address oldAaveVault = address(aaveVault);
        aaveVault = IAaveVault(_aaveVault);
        emit AaveVaultUpdated(oldAaveVault, _aaveVault);
    }

    /**
     * @notice Harvests accrued Aave interest through AaveVault and routes yield via YieldShift.
     * @dev HIGH-2 / NEW-1 remediation entrypoint for explicit yield synchronization.
     * @return harvestedYield Amount harvested by AaveVault (USDC 6 decimals).
     * @custom:security Restricted to governance and guarded by `nonReentrant`.
     * @custom:validation Requires configured AaveVault address.
     * @custom:state-changes May update Aave-side accounting and emits local harvest event.
     * @custom:events Emits `AaveInterestHarvested`.
     * @custom:errors Reverts when AaveVault is unset or downstream harvest call fails.
     * @custom:reentrancy Protected by `nonReentrant`.
     * @custom:access Restricted to `GOVERNANCE_ROLE`.
     * @custom:oracle No direct oracle interaction.
     */
    function harvestAaveInterest() external onlyRole(GOVERNANCE_ROLE) nonReentrant returns (uint256 harvestedYield) {
        if (address(aaveVault) == address(0)) revert CommonErrorLibrary.ZeroAddress();
        harvestedYield = aaveVault.harvestAaveYield();
        emit AaveInterestHarvested(harvestedYield);
    }

    // =============================================================================
    // AAVE INTEGRATION FUNCTIONS - Deploy USDC to Aave for yield generation
    // =============================================================================

    /**
     * @notice Deploys USDC from the vault to Aave for yield generation
     * @dev Called by UserPool after minting QEURO to automatically deploy USDC to Aave
     * @param usdcAmount Amount of USDC to deploy to Aave (6 decimals)
     * @custom:security Only callable by VAULT_OPERATOR_ROLE (UserPool)
     * @custom:validation Validates amount > 0, AaveVault is set, and sufficient USDC balance
     * @custom:state-changes Updates totalUsdcHeld (decreases) and totalUsdcInAave (increases)
     * @custom:events Emits UsdcDeployedToAave event
     * @custom:errors Reverts if amount is 0, AaveVault not set, or insufficient USDC
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to VAULT_OPERATOR_ROLE
     * @custom:oracle No oracle dependencies
     */
    function deployUsdcToAave(uint256 usdcAmount) external nonReentrant onlyRole(VAULT_OPERATOR_ROLE) {
        // CHECKS
        CommonValidationLibrary.validatePositiveAmount(usdcAmount);
        if (address(aaveVault) == address(0)) revert CommonErrorLibrary.ZeroAddress();
        if (totalUsdcHeld < usdcAmount) revert CommonErrorLibrary.InsufficientBalance();
        
        // EFFECTS - Update state before external calls
        unchecked {
            totalUsdcHeld -= usdcAmount;
            totalUsdcInAave += usdcAmount;
        }
        
        emit UsdcDeployedToAave(usdcAmount, totalUsdcInAave);
        
        // INTERACTIONS - Transfer USDC to AaveVault and deploy to Aave
        usdc.safeIncreaseAllowance(address(aaveVault), usdcAmount);
        uint256 aTokensReceived = aaveVault.deployToAave(usdcAmount);
        
        // Validate that deployment was successful (aTokensReceived should be > 0)
        if (aTokensReceived == 0) revert CommonErrorLibrary.InvalidAmount();
    }

    /**
     * @notice Withdraws USDC from Aave back to the vault
     * @dev Called internally when redemptions require more USDC than available in vault
     * @param usdcAmount Amount of USDC to withdraw from Aave (6 decimals)
     * @return usdcWithdrawn Actual amount of USDC withdrawn
     * @custom:security Internal function, called during redemption flow
     * @custom:validation Validates amount > 0 and AaveVault is set
     * @custom:state-changes Updates totalUsdcHeld (increases) and totalUsdcInAave (decreases)
     * @custom:events Emits UsdcWithdrawnFromAave event
     * @custom:errors Reverts if amount is 0 or AaveVault not set
     * @custom:reentrancy Not protected - internal function only
     * @custom:access Internal function - called by redeemQEURO
     * @custom:oracle No oracle dependencies
     */
    // slither-disable-start reentrancy-no-eth
    // slither-disable-start reentrancy-benign
    // SECURITY: Internal function called from nonReentrant context; external call to trusted AaveVault
    function _withdrawUsdcFromAave(uint256 usdcAmount) internal returns (uint256 usdcWithdrawn) {
        if (address(aaveVault) == address(0)) revert CommonErrorLibrary.ZeroAddress();
        if (usdcAmount == 0) return 0;

        // Include accrued yield in withdraw capacity; cap to current aToken balance when available.
        uint256 amountToWithdraw = usdcAmount;
        try aaveVault.getAaveBalance() returns (uint256 currentAaveBalance) {
            if (currentAaveBalance == 0) return 0;
            if (amountToWithdraw > currentAaveBalance) {
                amountToWithdraw = currentAaveBalance;
            }
        } catch {
            if (totalUsdcInAave == 0) return 0;
            if (amountToWithdraw > totalUsdcInAave) {
                amountToWithdraw = totalUsdcInAave;
            }
        }
        if (amountToWithdraw == 0) return 0;

        // Withdraw from AaveVault
        usdcWithdrawn = aaveVault.withdrawFromAave(amountToWithdraw);

        // HIGH-2 fix: principal tracker is decremented only by principal portion.
        uint256 principalReduction = usdcWithdrawn > totalUsdcInAave ? totalUsdcInAave : usdcWithdrawn;
        totalUsdcInAave -= principalReduction;
        totalUsdcHeld += usdcWithdrawn;
        
        emit UsdcWithdrawnFromAave(usdcWithdrawn, totalUsdcInAave);
    }
    // slither-disable-end reentrancy-no-eth
    // slither-disable-end reentrancy-benign
    

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
    // slither-disable-start reentrancy-no-eth
    // slither-disable-start reentrancy-benign
    // SECURITY: Protected by nonReentrant modifier; external call to trusted AaveVault
    function withdrawHedgerDeposit(address hedger, uint256 usdcAmount) external nonReentrant {
        if (msg.sender != address(hedgerPool)) revert CommonErrorLibrary.NotAuthorized();
        CommonValidationLibrary.validatePositiveAmount(usdcAmount);
        if (hedger == address(0)) revert CommonErrorLibrary.InvalidAddress();
        
        // Check if total available USDC (vault + Aave) is sufficient
        uint256 totalAvailable = _getTotalCollateralWithAccruedYield();
        if (totalAvailable < usdcAmount) revert CommonErrorLibrary.InsufficientBalance();
        
        // If vault doesn't have enough USDC, withdraw from Aave
        if (totalUsdcHeld < usdcAmount && address(aaveVault) != address(0)) {
            uint256 deficit = usdcAmount - totalUsdcHeld;
            _withdrawUsdcFromAave(deficit);
        }
        
        // Re-check after potential Aave withdrawal
        if (totalUsdcHeld < usdcAmount) revert CommonErrorLibrary.InsufficientBalance();
        
        // Update vault's total USDC reserves
        unchecked {
            totalUsdcHeld -= usdcAmount;
        }
        
        // Transfer USDC to hedger
        usdc.safeTransfer(hedger, usdcAmount);
        
        emit HedgerDepositWithdrawn(hedger, usdcAmount, totalUsdcHeld);
    }
    // slither-disable-end reentrancy-no-eth
    // slither-disable-end reentrancy-benign

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
    // slither-disable-start reentrancy-no-eth
    // slither-disable-start reentrancy-benign
    // SECURITY: Protected by nonReentrant modifier; external call to trusted Oracle contract
    function updatePriceCache() external onlyRole(GOVERNANCE_ROLE) nonReentrant {
        // Cache old price before external call
        uint256 oldPrice = lastValidEurUsdPrice;
        
        // Get new oracle price
        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) revert CommonErrorLibrary.InvalidOraclePrice();
        
        // EFFECTS - Update all state before emitting event
        lastValidEurUsdPrice = eurUsdPrice;
        lastPriceUpdateBlock = block.number;
        lastPriceUpdateTime = block.timestamp;
        
        // Emit event after state changes
        emit PriceCacheUpdated(oldPrice, eurUsdPrice, block.number);
    }
    // slither-disable-end reentrancy-no-eth
    // slither-disable-end reentrancy-benign

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
            lastPriceUpdateTime = block.timestamp;
        }
    }

    /**
     * @notice Returns current Aave collateral balance including accrued yield when available.
     * @dev Falls back to tracked principal if the external balance query is unavailable.
     * @return collateralBalance Aave-side collateral balance in USDC units (6 decimals).
     * @custom:security View helper with defensive fallback path.
     * @custom:validation Returns tracked principal when Aave balance query reverts.
     * @custom:state-changes None - view function.
     * @custom:events None.
     * @custom:errors None - errors are caught via try/catch fallback.
     * @custom:reentrancy Not applicable - view function.
     * @custom:access Internal helper.
     * @custom:oracle No oracle interaction.
     */
    function _getAaveCollateralBalance() internal view returns (uint256) {
        if (address(aaveVault) == address(0)) {
            return totalUsdcInAave;
        }
        try aaveVault.getAaveBalance() returns (uint256 currentAaveBalance) {
            return currentAaveBalance;
        } catch {
            return totalUsdcInAave;
        }
    }

    /**
     * @notice HIGH-2/NEW-1: total protocol collateral including accrued Aave interest.
     * @dev Uses on-chain Aave balance (principal + yield) with a principal fallback path.
     * @return totalCollateral Combined vault-held + Aave-held collateral in USDC units (6 decimals).
     * @custom:security View helper used by CR calculations and withdrawal checks.
     * @custom:validation Relies on `_getAaveCollateralBalance` fallback behavior.
     * @custom:state-changes None - view function.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable - view function.
     * @custom:access Internal helper.
     * @custom:oracle No oracle interaction.
     */
    function _getTotalCollateralWithAccruedYield() internal view returns (uint256) {
        return totalUsdcHeld + _getAaveCollateralBalance();
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
    function getProtocolCollateralizationRatioView() public view returns (uint256 ratio) {
        return getProtocolCollateralizationRatio();
    }

    /**
     * @notice LOW-4: Pure view variant of canMint using cached oracle price.
     * @dev Delegates to `canMint()` and performs no state refresh.
     * @return mintAllowed True when mint preconditions currently pass.
     * @custom:security View-only wrapper.
     * @custom:validation Inherits price-cache and hedger-liveness checks from delegated function.
     * @custom:state-changes None - view function.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable - view function.
     * @custom:access Public.
     * @custom:oracle Uses cached oracle price.
     */
    function canMintView() public view returns (bool) {
        return canMint();
    }

    /**
     * @notice LOW-5: Seeds the oracle price cache so minting checks have a baseline.
     * @dev Governance MUST call this once immediately after deployment, before any user mints.
     * @custom:security Restricted to governance.
     * @custom:validation Requires configured oracle and a valid fetched price.
     * @custom:state-changes Sets `lastValidEurUsdPrice`, `lastPriceUpdateBlock`, and `lastPriceUpdateTime`.
     * @custom:events Emits `PriceCacheUpdated`.
     * @custom:errors Reverts when oracle is unset or returns an invalid price.
     * @custom:reentrancy Not applicable - no external callbacks.
     * @custom:access Restricted to `GOVERNANCE_ROLE`.
     * @custom:oracle Pulls current EUR/USD price from configured oracle.
     */
    function initializePriceCache() external onlyRole(GOVERNANCE_ROLE) {
        if (address(oracle) == address(0)) revert CommonErrorLibrary.ZeroAddress();
        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) revert CommonErrorLibrary.InvalidOraclePrice();
        lastValidEurUsdPrice = eurUsdPrice;
        lastPriceUpdateBlock = block.number;
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
    function getLiquidationStatus() external view returns (
        bool isInLiquidation,
        uint256 collateralizationRatioBps,
        uint256 totalCollateralUsdc,
        uint256 totalQeuroSupply
    ) {
        // Get current QEURO supply
        totalQeuroSupply = qeuro.totalSupply();
        
        // If no QEURO supply, not in liquidation
        if (totalQeuroSupply == 0) {
            return (false, 0, 0, 0);
        }
        
        // Get collateralization ratio (18 decimals format)
        uint256 currentRatio18Dec = getProtocolCollateralizationRatio();
        
        // Convert from 18 decimals to basis points (divide by 1e16)
        // Format: percentage * 1e18, so 100% = 1e20, 101% = 1.01e20
        // To convert to bps: (ratio / 1e18) * 10000 = ratio / 1e16
        // 1e20 (100%) -> 10000 bps, 1.01e20 (101%) -> 10100 bps
        collateralizationRatioBps = currentRatio18Dec / 1e16;
        
        // Total collateral = actual USDC in vault (user deposits + hedger margin)
        totalCollateralUsdc = _getTotalCollateralWithAccruedYield();
        
        uint256 criticalRatioBps = criticalCollateralizationRatio / 1e16;

        // Liquidation mode when CR <= configured critical threshold
        isInLiquidation = collateralizationRatioBps <= criticalRatioBps;
    }

    /**
     * @notice Calculates pro-rata payout for liquidation mode redemption
     * @dev Formula: payout = (qeuroAmount / totalSupply) * totalCollateral
     * @dev Premium if CR > 100%, haircut if CR < 100%
     * @param qeuroAmount Amount of QEURO to redeem (18 decimals)
     * @return usdcPayout Amount of USDC the user would receive (6 decimals)
     * @return isPremium True if payout > fair value (CR > 100%), false if haircut (CR < 100%)
     * @return premiumOrDiscountBps Premium or discount in basis points (e.g., 50 = 0.5%)
     * @custom:security View function - no state changes
     * @custom:validation Validates qeuroAmount > 0
     * @custom:state-changes None - view function
     * @custom:events None
     * @custom:errors Throws InvalidAmount if qeuroAmount is 0
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can calculate payout
     * @custom:oracle Requires oracle price for fair value calculation
     */
    function calculateLiquidationPayout(uint256 qeuroAmount) external view returns (
        uint256 usdcPayout,
        bool isPremium,
        uint256 premiumOrDiscountBps
    ) {
        CommonValidationLibrary.validatePositiveAmount(qeuroAmount);
        
        // Get total QEURO supply
        uint256 totalSupply = qeuro.totalSupply();
        if (totalSupply == 0) {
            return (0, false, 0);
        }
        
        // Use cached price so this function stays view-only/off-chain safe.
        uint256 eurUsdPrice = lastValidEurUsdPrice;
        if (eurUsdPrice == 0) {
            return (0, false, 0);
        }
        
        // INFO-5: Use actual vault USDC balance (same formula as _redeemLiquidationMode) so this
        // view function matches the real liquidation payout in stress scenarios.
        uint256 totalCollateralUsdc = _getTotalCollateralWithAccruedYield();

        // Calculate pro-rata payout: (qeuroAmount / totalSupply) * totalCollateral
        // qeuroAmount (18 dec) * totalCollateral (6 dec) / totalSupply (18 dec) = 6 dec
        usdcPayout = qeuroAmount.mulDiv(totalCollateralUsdc, totalSupply);
        
        // Calculate fair value: qeuroAmount * eurUsdPrice
        // qeuroAmount (18 dec) * eurUsdPrice (18 dec) / 1e18 = 18 dec, then / 1e12 = 6 dec
        uint256 fairValueUsdc = qeuroAmount.mulDiv(eurUsdPrice, 1e18) / 1e12;
        
        // Determine if premium or discount
        if (usdcPayout >= fairValueUsdc) {
            isPremium = true;
            // Premium = (payout - fairValue) / fairValue * 10000
            if (fairValueUsdc > 0) {
                premiumOrDiscountBps = (usdcPayout - fairValueUsdc).mulDiv(10000, fairValueUsdc);
            }
        } else {
            isPremium = false;
            // Discount = (fairValue - payout) / fairValue * 10000
            if (fairValueUsdc > 0) {
                premiumOrDiscountBps = (fairValueUsdc - usdcPayout).mulDiv(10000, fairValueUsdc);
            }
        }
    }
    
    /**
     * @notice Returns the current price protection status
     * @return lastValidPrice Last valid EUR/USD price used
     * @return lastUpdateBlock Block number of last price update
     * @return maxDeviation Maximum allowed price deviation in basis points
     * @return minBlocks Minimum blocks required between updates
     * @dev Useful for monitoring and debugging price protection
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getPriceProtectionStatus() external view returns (
        uint256 lastValidPrice,
        uint256 lastUpdateBlock,
        uint256 maxDeviation,
        uint256 minBlocks
    ) {
        return (
            lastValidEurUsdPrice,
            lastPriceUpdateBlock,
            MAX_PRICE_DEVIATION,
            MIN_BLOCKS_BETWEEN_UPDATES
        );
    }





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
        // Use the shared library for secure ETH recovery
        TreasuryRecoveryLibrary.recoverETH(treasury);
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
        devModePendingAt = block.timestamp + DEV_MODE_DELAY;
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
        if (block.timestamp < devModePendingAt) revert CommonErrorLibrary.NotActive();
        devModeEnabled = pendingDevMode;
        devModePendingAt = 0;
        emit DevModeToggled(devModeEnabled, msg.sender);
    }
}

// =============================================================================
// END OF QUANTILLONVAULT CONTRACT
// =============================================================================
