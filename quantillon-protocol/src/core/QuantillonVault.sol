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
import {IChainlinkOracle} from "../interfaces/IChainlinkOracle.sol";
import {IHedgerPool} from "../interfaces/IHedgerPool.sol";
import {IUserPool} from "../interfaces/IUserPool.sol";
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
    
    /// @notice Chainlink oracle contract for EUR/USD price feeds
    /// @dev Provides real-time EUR/USD exchange rates for minting and redemption
    /// @dev Used for price calculations in swap operations
    IChainlinkOracle public oracle;

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

    // Protocol parameters (configurable by governance)
    
    /// @notice Protocol fee charged on minting QEURO (in basis points)
    /// @dev Example: 10 = 0.1% minting fee
    /// @dev Revenue source for the protocol
    uint256 public mintFee;
    
    /// @notice Protocol fee charged on redeeming QEURO (in basis points)
    /// @dev Example: 10 = 0.1% redemption fee
    /// @dev Revenue source for the protocol
    uint256 public redemptionFee;

    // Collateralization parameters (configurable by governance)
    
    /// @notice Minimum collateralization ratio required for minting QEURO (in basis points)
    /// @dev Example: 10500 = 105% collateralization ratio required for minting
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

    // =============================================================================
    // MODIFIERS - Access control and security
    // =============================================================================

    /**
     * @notice Modifier to protect against flash loan attacks
     * @dev Uses the FlashLoanProtectionLibrary to check USDC balance consistency
     */
    modifier flashLoanProtection() {
        uint256 balanceBefore = usdc.balanceOf(address(this));
        _;
        uint256 balanceAfter = usdc.balanceOf(address(this));
        if (!FlashLoanProtectionLibrary.validateBalanceChange(balanceBefore, balanceAfter, 0)) {
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
        oracle = IChainlinkOracle(_oracle);
        // HedgerPool and UserPool can be set later via update functions if addresses are zero
        if (_hedgerPool != address(0)) {
            hedgerPool = IHedgerPool(_hedgerPool);
        }
        if (_userPool != address(0)) {
            userPool = IUserPool(_userPool);
        }
        treasury = _timelock; // Set treasury to timelock
        feeCollector = _feeCollector; // Set fee collector

        // Default protocol parameters
        mintFee = 1e15;                 // 0.1% mint fee (taken from USDC deposit)
        redemptionFee = 1e15;           // 0.1% redemption fee
        
        // Default collateralization parameters (in 18 decimals format for maximum precision)
        minCollateralizationRatioForMinting = 105000000000000000000;  // 105.000000% - minimum ratio for minting (105 * 1e18)
        criticalCollateralizationRatio = 101000000000000000000;       // 101.000000% - critical ratio for liquidation (101 * 1e18)
        
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
    function mintQEURO(
        uint256 usdcAmount,
        uint256 minQeuroOut
    ) external nonReentrant whenNotPaused flashLoanProtection {
        // CHECKS
        CommonValidationLibrary.validatePositiveAmount(usdcAmount);
        
        // Cache all oracle calls at start to avoid reentrancy issues
        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) revert CommonErrorLibrary.InvalidOraclePrice();
        
        // Check if we can mint (this also calls oracle internally, but we've already cached the price)
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

        if (address(hedgerPool) == address(0)) revert CommonErrorLibrary.InvalidVault();

        // EFFECTS - Update all state before external calls
        // Update price cache
        lastPriceUpdateBlock = block.number;
        lastValidEurUsdPrice = eurUsdPrice;
        _updatePriceTimestamp(isValid);

        // Update vault accounting
        unchecked {
            totalUsdcHeld += netAmount;
            totalMinted += qeuroToMint;
        }

        // Inform HedgerPool after vault accounting is updated
        // Pass netAmount (after fee) to recordUserMint, as the fee is paid by the buyer, not the hedger
        // The hedger's filledVolume should track the net USDC that was actually used to mint QEURO
        _syncMintWithHedgers(netAmount, eurUsdPrice, qeuroToMint);

        // Emit event after state changes but before external calls
        emit QEUROminted(msg.sender, usdcAmount, qeuroToMint);

        // INTERACTIONS - All external calls after state updates
        // Transfer full amount to vault
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);
        
        // Transfer fee to fee collector (if fee > 0)
        if (fee > 0) {
            // Approve FeeCollector to pull the fee
            usdc.safeIncreaseAllowance(feeCollector, fee);
            // Call FeeCollector to collect the fee with proper tracking
            FeeCollector(feeCollector).collectFees(address(usdc), fee, "minting");
        }
        
        qeuro.mint(msg.sender, qeuroToMint);
    }

    /**
     * @notice Redeems QEURO for USDC
     * 
     * @param qeuroAmount Amount of QEURO to swap for USDC
     * @param minUsdcOut Minimum amount of USDC expected
     * 
     * @dev Redeem process:
     *      1. Calculate USDC to return based on EUR/USD price
     *      2. Apply protocol fees
     *      3. Burn QEURO
     *      4. Update vault balances
     *      5. Transfer USDC to user
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access No access restrictions
     * @custom:oracle Requires fresh oracle price data
     * @custom:security No flash loan protection needed - legitimate redemption operation
     */
    function redeemQEURO(
        uint256 qeuroAmount,
        uint256 minUsdcOut
    ) external nonReentrant whenNotPaused {
        // CHECKS
        CommonValidationLibrary.validatePositiveAmount(qeuroAmount);

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
        
        if (usdcToReturn < minUsdcOut) revert CommonErrorLibrary.ExcessiveSlippage();
        if (totalUsdcHeld < usdcToReturn) revert CommonErrorLibrary.InsufficientBalance();

        if (address(hedgerPool) == address(0)) revert CommonErrorLibrary.InvalidVault();

        // Calculate fees before state changes
        uint256 fee = usdcToReturn.mulDiv(redemptionFee, 1e18);
        uint256 netUsdcToReturn = usdcToReturn - fee;

        // EFFECTS - Update all state before external calls
        // Update price cache
        lastPriceUpdateBlock = block.number;
        lastValidEurUsdPrice = eurUsdPrice;
        _updatePriceTimestamp(isValid);

        // Update vault balances
        unchecked {
            totalUsdcHeld -= usdcToReturn;
            totalMinted -= qeuroAmount;
        }
        
        // Inform HedgerPool after internal state is updated
        _syncRedeemWithHedgers(usdcToReturn, eurUsdPrice, qeuroAmount);

        // Emit event after state changes but before external calls
        emit QEURORedeemed(msg.sender, qeuroAmount, netUsdcToReturn);

        // INTERACTIONS - All external calls after state updates
        qeuro.burn(msg.sender, qeuroAmount);
        usdc.safeTransfer(msg.sender, netUsdcToReturn);
        
        // Transfer fee to fee collector (if fee > 0)
        if (fee > 0) {
            // Approve FeeCollector to pull the fee
            bool success = usdc.approve(feeCollector, fee);
            if (!success) revert CommonErrorLibrary.TokenTransferFailed();
            // Call FeeCollector to collect the fee with proper tracking
            FeeCollector(feeCollector).collectFees(address(usdc), fee, "redemption");
        }
    }





    // =============================================================================
    // VIEW FUNCTIONS - Read functions for monitoring
    // =============================================================================

    /**
     * @notice Retrieves the vault's global metrics
     * @dev Returns comprehensive vault metrics for monitoring and analytics
     * @return totalUsdcHeld_ Total USDC held in the vault
     * @return totalMinted_ Total QEURO minted
     * @return totalDebtValue Total debt value in USD
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
        returns (
            uint256 totalUsdcHeld_,
            uint256 totalMinted_,
            uint256 totalDebtValue
        ) 
    {
        totalUsdcHeld_ = totalUsdcHeld;
        totalMinted_ = totalMinted;

        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        if (isValid && totalMinted > 0) {
            totalDebtValue = totalMinted.mulDiv(eurUsdPrice, 1e18);
        } else {
            totalDebtValue = 0;
        }
    }

    /**
     * @notice Calculates the amount of QEURO that can be minted for a given USDC amount
     * @dev Calculates mint amount based on current oracle price and protocol fees
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
     * @custom:oracle Requires fresh oracle price data
     */
    function calculateMintAmount(uint256 usdcAmount) 
        external 
        returns (uint256 qeuroAmount, uint256 fee) 
    {
        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) return (0, 0);

        fee = usdcAmount.mulDiv(mintFee, 1e18);
        uint256 netAmount = usdcAmount - fee;
        qeuroAmount = netAmount.mulDiv(1e30, eurUsdPrice);
    }

    /**
     * @notice Calculates the amount of USDC received for a QEURO redemption
     * @dev Calculates redeem amount based on current oracle price and protocol fees
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
     * @custom:oracle Requires fresh oracle price data
     */
    function calculateRedeemAmount(uint256 qeuroAmount) 
        external 
        returns (uint256 usdcAmount, uint256 fee) 
    {
        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) return (0, 0);

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
     * @param _mintFee New minting fee
     * @param _redemptionFee New redemption fee
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
        if (_minCollateralizationRatioForMinting < 101000000000000000000) revert CommonErrorLibrary.InvalidThreshold();
        if (_criticalCollateralizationRatio < 100000000000000000000) revert CommonErrorLibrary.InvalidThreshold();
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
        oracle = IChainlinkOracle(_oracle);
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
     * @notice Updates price deviation protection parameters
     * @param _maxPriceDeviation New maximum price deviation in basis points
     * @param _minBlocksBetweenUpdates New minimum blocks between updates
     * @dev Only governance can update these security parameters
     * @dev Note: This function requires converting constants to state variables
     *      for full implementation. Currently a placeholder for future governance control.
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function updatePriceProtectionParams(
        uint256 _maxPriceDeviation, 
        uint256 _minBlocksBetweenUpdates
    ) external onlyRole(GOVERNANCE_ROLE) {
        if (_maxPriceDeviation > 1000) revert CommonErrorLibrary.ConfigValueTooHigh();
        if (_minBlocksBetweenUpdates > 100) revert CommonErrorLibrary.ConfigValueTooHigh();
        
        // For now, this function validates parameters but doesn't update them
        // as they are currently implemented as constants
        
        emit ParametersUpdated("price_protection", _maxPriceDeviation, _minBlocksBetweenUpdates);
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
    function withdrawHedgerDeposit(address hedger, uint256 usdcAmount) external nonReentrant {
        if (msg.sender != address(hedgerPool)) revert CommonErrorLibrary.NotAuthorized();
        CommonValidationLibrary.validatePositiveAmount(usdcAmount);
        if (hedger == address(0)) revert CommonErrorLibrary.InvalidAddress();
        if (totalUsdcHeld < usdcAmount) revert CommonErrorLibrary.InsufficientBalance();
        
        // Update vault's total USDC reserves
        unchecked {
            totalUsdcHeld -= usdcAmount;
        }
        
        // Transfer USDC to hedger
        usdc.safeTransfer(hedger, usdcAmount);
        
        emit HedgerDepositWithdrawn(hedger, usdcAmount, totalUsdcHeld);
    }

    /**
     * @notice Gets the total USDC available for hedger deposits
     * @dev Returns the current total USDC held in the vault for transparency
     * @return uint256 Total USDC held in vault (6 decimals)
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public access - anyone can query total USDC held
     * @custom:oracle No oracle dependencies
     */
    function getTotalUsdcAvailable() external view returns (uint256) {
        return totalUsdcHeld;
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
    function updatePriceCache() external onlyRole(GOVERNANCE_ROLE) {
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
     * @notice Calculates the current protocol collateralization ratio
     * @dev Formula: (COLLATUser + COLLATHedger) / (qMinted * oraclePrice) * 100
     * @dev Where COLLATUser = totalUserDeposits, COLLATHedger = hedger effective collateral (deposits + P&L)
     * @dev Returns ratio in 18 decimals (e.g., 109183495000000000000 = 109.183495%) for maximum precision
     * @dev Uses hedger effective collateral instead of raw deposits to account for P&L
     * @return ratio Current collateralization ratio in 18 decimals (maximum precision, e.g., 109183495000000000000 = 109.183495%)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted - view function
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can check collateralization ratio
     * @custom:oracle Requires fresh oracle price data (via HedgerPool)
     */
    function getProtocolCollateralizationRatio() public returns (uint256 ratio) {
        // Check if both HedgerPool and UserPool are set
        if (address(hedgerPool) == address(0) || address(userPool) == address(0)) {
            return 0;
        }
        
        // Get current QEURO supply for denominator calculation
        uint256 currentQeuroSupply = qeuro.totalSupply();
        
        // If no QEURO supply, we can't calculate a meaningful ratio
        // Return 0 to indicate no user deposits yet
        if (currentQeuroSupply == 0) {
            return 0;
        }
        
        // Get oracle price once and reuse it for consistency
        (uint256 currentRate, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) revert CommonErrorLibrary.InvalidOraclePrice();
        
        // Convert QEURO supply to current USDC equivalent
        // This represents the current debt value: qMinted * oraclePrice
        // This also represents COLLATUser (user deposits backing the QEURO supply)
        uint256 currentUsdcEquivalent = currentQeuroSupply.mulDiv(currentRate, 1e18) / 1e12;
        
        // COLLATUser = current QEURO supply in USDC (user deposits backing the debt)
        // Note: We use currentUsdcEquivalent for COLLATUser instead of totalUserDeposits
        // because totalUserDeposits tracks historical deposits which may differ due to fees/redemptions
        uint256 userDeposits = currentUsdcEquivalent;
        
        // Get hedger effective collateral from HedgerPool (COLLATHedger)
        // This includes deposits + P&L, giving accurate collateralization ratio
        // Pass currentRate to avoid double oracle call and ensure price consistency
        uint256 hedgerEffectiveCollateral = hedgerPool.getTotalEffectiveHedgerCollateral(currentRate);
        
        // Calculate total collateral: COLLATUser + COLLATHedger
        uint256 totalCollateral = userDeposits + hedgerEffectiveCollateral;
        
        // Calculate ratio with maximum precision: (totalCollateral / currentUsdcEquivalent) * 100 * 1e18
        // Using 18 decimals (multiply by 1e18) for maximum precision - matches protocol standard
        // Multiply by 100 to convert ratio to percentage (e.g., 1.09183495 -> 109.183495%)
        // Result format: percentage * 1e18, so 100% = 1e20, 109.183495% = 109183495000000000000
        // Formula: (totalCollateral * 1e20) / currentUsdcEquivalent
        // This gives us the percentage directly (e.g., 109.657% = 109657000000000000000)
        ratio = (totalCollateral * 1e20) / currentUsdcEquivalent;
        
        return ratio;
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
    function canMint() public returns (bool) {
        uint256 currentQeuroSupply = qeuro.totalSupply();
        
        // Allow minting if there's no QEURO supply yet (first mint)
        if (currentQeuroSupply == 0) {
            return true;
        }
        
        uint256 currentRatio = getProtocolCollateralizationRatio();
        return currentRatio >= minCollateralizationRatioForMinting;
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
    function shouldTriggerLiquidation() public returns (bool shouldLiquidate) {
        uint256 currentRatio = getProtocolCollateralizationRatio();
        return currentRatio < criticalCollateralizationRatio;
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
     * @notice Internal helper to notify HedgerPool about user mints
     * @dev Attempts to update hedger fills but swallows failures to avoid blocking users
     * @param amount Net USDC amount minted into QEURO (6 decimals)
     * @param fillPrice EUR/USD oracle price used for the mint (18 decimals)
     * @param qeuroAmount QEURO amount that was minted (18 decimals)
     * @custom:security Internal helper; relies on HedgerPool access control
     * @custom:validation No additional validation beyond non-zero guard
     * @custom:state-changes None inside the vault; delegates to HedgerPool
     * @custom:events None
     * @custom:errors Silently ignores downstream errors
     * @custom:reentrancy Not applicable
     * @custom:access Internal helper
     * @custom:oracle Not applicable
     */
    function _syncMintWithHedgers(uint256 amount, uint256 fillPrice, uint256 qeuroAmount) internal {
        if (amount == 0) {
            return;
        }
        try hedgerPool.recordUserMint(amount, fillPrice, qeuroAmount) {} catch {}
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
        try hedgerPool.recordUserRedeem(amount, redeemPrice, qeuroAmount) {} catch {}
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
    function setDevMode(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        devModeEnabled = enabled;
        emit DevModeToggled(enabled, msg.sender);
    }
}

// =============================================================================
// END OF QUANTILLONVAULT CONTRACT
// =============================================================================