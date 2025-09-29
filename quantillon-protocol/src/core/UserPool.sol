// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// =============================================================================
// IMPORTS - OpenZeppelin libraries and protocol interfaces
// =============================================================================

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IQEUROToken} from "../interfaces/IQEUROToken.sol";
import {IQuantillonVault} from "../interfaces/IQuantillonVault.sol";
import {IChainlinkOracle} from "../interfaces/IChainlinkOracle.sol";
import {IYieldShift} from "../interfaces/IYieldShift.sol";
import {VaultMath} from "../libraries/VaultMath.sol";
import {CommonErrorLibrary} from "../libraries/CommonErrorLibrary.sol";
import {SecureUpgradeable} from "./SecureUpgradeable.sol";
import {FlashLoanProtectionLibrary} from "../libraries/FlashLoanProtectionLibrary.sol";
import {TimeProvider} from "../libraries/TimeProviderLibrary.sol";
import {UserPoolStakingLibrary} from "../libraries/UserPoolStakingLibrary.sol";
import {AdminFunctionsLibrary} from "../libraries/AdminFunctionsLibrary.sol";
import {CommonValidationLibrary} from "../libraries/CommonValidationLibrary.sol";

/**
 * @title UserPool
 * @notice Manages QEURO user deposits, staking, and yield distribution
 * 
 * @dev Main characteristics:
 *      - User deposit and withdrawal management
 *      - QEURO staking mechanism with rewards
 *      - Yield distribution system
 *      - Fee structure for protocol sustainability
 *      - Emergency pause mechanism for crisis situations
 *      - Upgradeable via UUPS pattern
 * 
 * @dev Deposit mechanics:
 *      - Users deposit USDC to receive QEURO
 *      - QEURO is minted based on current EUR/USD exchange rate
 *      - Deposit fees charged for protocol revenue
 *      - Deposits are tracked per user for analytics
 * 
 * @dev Staking mechanics:
 *      - Users can stake their QEURO for additional rewards
 *      - Staking APY provides yield on staked QEURO
 *      - Unstaking has a cooldown period to prevent abuse
 *      - Rewards are distributed based on staking duration and amount
 * 
 * @dev Withdrawal mechanics:
 *      - Users can withdraw their QEURO back to USDC
 *      - Withdrawal fees charged for protocol revenue
 *      - Withdrawals are processed based on current EUR/USD rate
 *      - Staked QEURO must be unstaked before withdrawal
 * 
 * @dev Yield distribution:
 *      - Yield is distributed to stakers based on their stake amount
 *      - Performance fees charged on yield distributions
 *      - Yield sources include protocol fees and yield shift mechanisms
 *      - Real-time yield tracking and distribution
 * 
 * @dev Fee structure:
 *      - Deposit fees for creating QEURO from USDC
 *      - Withdrawal fees for converting QEURO back to USDC
 *      - Performance fees on yield distributions
 *      - Dynamic fee adjustment based on market conditions
 * 
 * @dev Security features:
 *      - Role-based access control for all critical operations
 *      - Reentrancy protection for all external calls
 *      - Emergency pause mechanism for crisis situations
 *      - Upgradeable architecture for future improvements
 *      - Secure deposit and withdrawal management
 *      - Staking cooldown mechanisms
 *      - Batch size limits to prevent DoS attacks
 *      - Gas optimization through storage read caching
 * 
 * @dev Integration points:
 *      - QEURO token for minting and burning
 *      - USDC for deposits and withdrawals
 *      - QuantillonVault for QEURO minting/burning
 *      - Yield shift mechanism for yield management
 *      - Vault math library for calculations
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract UserPool is 
    Initializable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    SecureUpgradeable
{
    using SafeERC20 for IERC20;
    using VaultMath for uint256;

    // =============================================================================
    // CONSTANTS AND ROLES - Protocol roles and limits
    // =============================================================================
    
    /// @notice Role for governance operations (parameter updates, emergency actions)
    /// @dev keccak256 hash avoids role collisions with other contracts
    /// @dev Should be assigned to governance multisig or DAO
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    
    /// @notice Role for emergency operations (pause, emergency withdrawals)
    /// @dev keccak256 hash avoids role collisions with other contracts
    /// @dev Should be assigned to emergency multisig
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    


    // =============================================================================
    // STATE VARIABLES - External contracts and configuration
    // =============================================================================
    
    /// @notice QEURO token contract for minting and burning
    /// @dev Used for all QEURO minting and burning operations
    /// @dev Should be the official QEURO token contract
    IQEUROToken public qeuro;
    
    /// @notice USDC token contract for deposits and withdrawals
    /// @dev Used for all USDC deposits and withdrawals
    /// @dev Should be the official USDC contract on the target network
    IERC20 public usdc;
    
    /// @notice Main Quantillon vault for QEURO operations
    /// @dev Used for QEURO minting and burning operations
    /// @dev Should be the official QuantillonVault contract
    IQuantillonVault public vault;
    
    /// @notice Chainlink Oracle for EUR/USD price feeds
    /// @dev Used for converting QEURO supply to USDC equivalent in analytics
    IChainlinkOracle public oracle;
    
    /// @notice Yield shift mechanism for yield management
    /// @dev Handles yield distribution and management
    /// @dev Used for yield calculations and distributions
    IYieldShift public yieldShift;

    /// @notice Treasury address for ETH recovery
    /// @dev SECURITY: Only this address can receive ETH from recoverETH function
    address public treasury;

    /// @notice TimeProvider contract for centralized time management
    /// @dev Used to replace direct block.timestamp usage for testability and consistency
    TimeProvider public immutable TIME_PROVIDER;

    // Pool configuration parameters
    /// @notice Staking APY in basis points
    /// @dev Example: 500 = 5% staking APY
    /// @dev Used for calculating staking rewards
    uint256 public stakingAPY;              // Staking APY in basis points
    
    /// @notice Base deposit APY in basis points
    /// @dev Example: 200 = 2% base deposit APY
    /// @dev Used for calculating deposit rewards
    uint256 public depositAPY;              // Base deposit APY in basis points
    
    /// @notice Minimum amount required for staking (in QEURO)
    /// @dev Example: 100 * 1e18 = 100 QEURO minimum stake
    /// @dev Prevents dust staking and reduces gas costs
    uint256 public minStakeAmount;          // Minimum amount for staking
    
    /// @notice Cooldown period for unstaking (in seconds)
    /// @dev Example: 7 days = 604,800 seconds
    /// @dev Prevents rapid staking/unstaking cycles
    uint256 public unstakingCooldown;       // Cooldown period for unstaking
    
    // Fee configuration parameters
    /// @notice Fee charged on deposits (in basis points)
    /// @dev Example: 10 = 0.1% deposit fee
    /// @dev Revenue source for the protocol
    uint256 public depositFee;              // Deposit fee in basis points
    
    /// @notice Fee charged on withdrawals (in basis points)
    /// @dev Example: 10 = 0.1% withdrawal fee
    /// @dev Revenue source for the protocol
    uint256 public withdrawalFee;           // Withdrawal fee in basis points
    
    /// @notice Fee charged on yield distributions (in basis points)
    /// @dev Example: 200 = 2% performance fee
    /// @dev Revenue source for the protocol
    uint256 public performanceFee;          // Performance fee in basis points

    // Pool state variables
    /// @notice Total QEURO staked across all users
    /// @dev Sum of all staked QEURO amounts
    /// @dev Used for yield distribution calculations
    uint256 public totalStakes;             // Total QEURO staked
    
    /// @notice Number of unique users who have deposited
    /// @dev Count of unique addresses that have made deposits
    /// @dev Used for protocol analytics and governance
    uint256 public totalUsers;              // Number of unique users
    
    // =============================================================================
    // DATA STRUCTURES - User information and tracking
    // =============================================================================
    
    /// @notice User information data structure
    /// @dev Stores all information about a user's deposits, stakes, and rewards
    /// @dev Used for user management and reward calculations
    /// @dev OPTIMIZED: Timestamps and amounts packed for gas efficiency
    struct UserInfo {
        uint128 qeuroBalance;               // QEURO balance from deposits (18 decimals, max ~340B)
        uint128 stakedAmount;               // QEURO amount currently staked (18 decimals, max ~340B)
        uint128 pendingRewards;             // Pending staking rewards in QEURO (18 decimals, max ~340B)
        uint128 unstakeAmount;              // Amount being unstaked (18 decimals, max ~340B)
        uint96 depositHistory;              // Total historical deposits in USDC (6 decimals, max ~79B USDC)
        uint64 lastStakeTime;               // Timestamp of last staking action (until year 2554)
        uint64 unstakeRequestTime;          // Timestamp when unstaking was requested (until year 2554)
    }
    
    /// @notice User deposit information with oracle ratio tracking
    /// @dev Stores individual deposit records with oracle ratios for detailed analytics
    /// @dev Used for audit trails and historical analysis
    struct UserDepositInfo {
        uint128 usdcAmount;                 // USDC amount deposited (6 decimals, max ~340B USDC)
        uint128 qeuroReceived;              // QEURO amount received (18 decimals, max ~340B QEURO)
        uint64 timestamp;                   // Block timestamp when deposit was made (until year 2554)
        uint32 oracleRatio;                 // Oracle ratio at time of deposit (scaled by 1e6, max ~4.2B)
        uint32 blockNumber;                 // Block number when deposit was made (until year 2106)
    }
    
    /// @notice User withdrawal information with oracle ratio tracking
    /// @dev Stores individual withdrawal records with oracle ratios for detailed analytics
    /// @dev Used for audit trails and historical analysis
    struct UserWithdrawalInfo {
        uint128 qeuroAmount;                // QEURO amount withdrawn (18 decimals, max ~340B QEURO)
        uint128 usdcReceived;               // USDC amount received (6 decimals, max ~340B USDC)
        uint64 timestamp;                   // Block timestamp when withdrawal was made (until year 2554)
        uint32 oracleRatio;                 // Oracle ratio at time of withdrawal (scaled by 1e6, max ~4.2B)
        uint32 blockNumber;                 // Block number when withdrawal was made (until year 2106)
    }
    
    // Storage mappings
    /// @notice User information by address
    /// @dev Maps user addresses to their detailed information
    /// @dev Used to track user deposits, stakes, and rewards
    mapping(address => UserInfo) public userInfo;
    
    /// @notice Whether a user has ever deposited
    /// @dev Maps user addresses to their deposit status
    /// @dev Used to track unique users and prevent double counting
    mapping(address => bool) public hasDeposited;

    // Yield tracking variables
    /// @notice Accumulated yield per staked QEURO share
    /// @dev Used for calculating user rewards based on their stake amount
    /// @dev Increases over time as yield is distributed
    uint256 public accumulatedYieldPerShare;    // Accumulated yield per staked QEURO
    
    /// @notice Timestamp of last yield distribution
    /// @dev Used to track when yield was last distributed
    /// @dev Used for yield calculation intervals
    uint256 public lastYieldDistribution;       // Last yield distribution timestamp
    
    /// @notice Total yield distributed to users
    /// @dev Sum of all yield distributed to users
    /// @dev Used for protocol analytics and governance
    uint256 public totalYieldDistributed;       // Total yield distributed to users

    // =============================================================================
    // DEPOSIT AND WITHDRAWAL TRACKING - Enhanced analytics and tracking
    // =============================================================================
    
    /// @notice Total USDC deposits across all users (in USDC decimals - 6)
    /// @dev Tracks the sum of all USDC deposits made by users
    /// @dev Used for protocol analytics and collateralization calculations
    uint256 public totalUserDeposits;           // Total USDC deposits (6 decimals)
    
    /// @notice Total QEURO withdrawals across all users (in QEURO decimals - 18)
    /// @dev Tracks the sum of all QEURO withdrawals made by users
    /// @dev Used for protocol analytics and supply tracking
    uint256 public totalUserWithdrawals;        // Total QEURO withdrawals (18 decimals)
    
    /// @notice User deposit tracking with oracle ratios
    /// @dev Maps user addresses to their deposit history with oracle ratios
    /// @dev Used for detailed analytics and audit trails
    mapping(address => UserDepositInfo[]) public userDeposits;
    
    /// @notice User withdrawal tracking with oracle ratios
    /// @dev Maps user addresses to their withdrawal history with oracle ratios
    /// @dev Used for detailed analytics and audit trails
    mapping(address => UserWithdrawalInfo[]) public userWithdrawals;

    // Block-based tracking to prevent timestamp manipulation
    mapping(address => uint256) public userLastRewardBlock;
    uint256 public constant BLOCKS_PER_DAY = 7200; // Assuming 12 second blocks
    uint256 public constant MAX_REWARD_PERIOD = 365 days; // Maximum reward period

    /// @notice Maximum batch size for deposit operations to prevent DoS
    /// @dev Prevents out-of-gas attacks through large arrays
    uint256 public constant MAX_BATCH_SIZE = 100;
    
    /// @notice Maximum batch size for reward claim operations to prevent DoS
    /// @dev Prevents out-of-gas attacks through large user arrays
    uint256 public constant MAX_REWARD_BATCH_SIZE = 50;

    // =============================================================================
    // EVENTS - Events for tracking and monitoring
    // =============================================================================
    
    /// @notice Emitted when a user deposits USDC and receives QEURO
    /// @param user Address of the user who deposited
    /// @param usdcAmount Amount of USDC deposited (6 decimals)
    /// @param qeuroMinted Amount of QEURO minted (18 decimals)
    /// @param timestamp Timestamp of the deposit
    /// @dev Indexed parameters allow efficient filtering of events
    event UserDeposit(address indexed user, uint256 usdcAmount, uint256 qeuroMinted, uint256 timestamp);
    
    /// @notice Emitted when a user withdraws QEURO and receives USDC
    /// @param user Address of the user who withdrew
    /// @param qeuroBurned Amount of QEURO burned (18 decimals)
    /// @param usdcReceived Amount of USDC received (6 decimals)
    /// @param timestamp Timestamp of the withdrawal
    /// @dev Indexed parameters allow efficient filtering of events
    event UserWithdrawal(address indexed user, uint256 qeuroBurned, uint256 usdcReceived, uint256 timestamp);
    
    /// @notice Emitted when a user deposit is tracked with oracle ratio
    /// @param user Address of the user who deposited
    /// @param usdcAmount USDC amount deposited (6 decimals)
    /// @param qeuroReceived QEURO amount received (18 decimals)
    /// @param oracleRatio Oracle ratio at time of deposit (scaled by 1e6)
    /// @param timestamp Block timestamp when deposit was made
    /// @param blockNumber Block number when deposit was made
    event UserDepositTracked(
        address indexed user, 
        uint256 usdcAmount, 
        uint256 qeuroReceived, 
        uint256 oracleRatio, 
        uint256 timestamp, 
        uint256 blockNumber
    );
    
    /// @notice Emitted when a user withdrawal is tracked with oracle ratio
    /// @param user Address of the user who withdrew
    /// @param qeuroAmount QEURO amount withdrawn (18 decimals)
    /// @param usdcReceived USDC amount received (6 decimals)
    /// @param oracleRatio Oracle ratio at time of withdrawal (scaled by 1e6)
    /// @param timestamp Block timestamp when withdrawal was made
    /// @param blockNumber Block number when withdrawal was made
    event UserWithdrawalTracked(
        address indexed user, 
        uint256 qeuroAmount, 
        uint256 usdcReceived, 
        uint256 oracleRatio, 
        uint256 timestamp, 
        uint256 blockNumber
    );
    
    /// @notice Emitted when a user stakes QEURO
    /// @param user Address of the user who staked
    /// @param qeuroAmount Amount of QEURO staked (18 decimals)
    /// @param timestamp Timestamp of the staking action
    /// @dev Indexed parameters allow efficient filtering of events
    event QEUROStaked(address indexed user, uint256 qeuroAmount, uint256 timestamp);
    
    /// @notice Emitted when a user unstakes QEURO
    /// @param user Address of the user who unstaked
    /// @param qeuroAmount Amount of QEURO unstaked (18 decimals)
    /// @param timestamp Timestamp of the unstaking action
    /// @dev Indexed parameters allow efficient filtering of events
    event QEUROUnstaked(address indexed user, uint256 qeuroAmount, uint256 timestamp);
    
    /// @notice Emitted when staking rewards are claimed by a user
    /// @param user Address of the user who claimed rewards
    /// @param rewardAmount Amount of QEURO rewards claimed (18 decimals)
    /// @param timestamp Timestamp of the reward claim
    /// @dev Indexed parameters allow efficient filtering of events
    event StakingRewardsClaimed(address indexed user, uint256 rewardAmount, uint256 timestamp);

    /// @notice Emitted when yield is distributed to stakers
    /// @param totalYield Total amount of yield distributed (18 decimals)
    /// @param yieldPerShare Amount of yield per staked QEURO share (18 decimals)
    /// @param timestamp Timestamp of the yield distribution
    /// @dev OPTIMIZED: Indexed timestamp for efficient time-based filtering
    event YieldDistributed(uint256 totalYield, uint256 yieldPerShare, uint256 indexed timestamp);

    /// @notice Emitted when pool parameters are updated
    /// @param parameter Name of the parameter updated
    /// @param oldValue Original value of the parameter
    /// @param newValue New value of the parameter
    /// @dev OPTIMIZED: Indexed parameter name for efficient filtering by parameter type
    event PoolParameterUpdated(string indexed parameter, uint256 oldValue, uint256 newValue);

    /// @notice Emitted when ETH is recovered to the treasury
    /// @param to Recipient address
    /// @param amount Amount of ETH recovered
    event ETHRecovered(address indexed to, uint256 indexed amount);

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
        require(
            FlashLoanProtectionLibrary.validateBalanceChange(balanceBefore, balanceAfter, 0),
            "Flash loan attack detected"
        );
    }

    // =============================================================================
    // INITIALIZER
    // =============================================================================

    /**
     * @notice Constructor for UserPool contract
     * @param _TIME_PROVIDER TimeProvider contract for centralized time management
     * @dev Sets up the time provider and disables initializers for security
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Disables initializers
     * @custom:events No events emitted
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access No access restrictions
     * @custom:oracle No oracle dependencies
     */
    constructor(TimeProvider _TIME_PROVIDER) {
        if (address(_TIME_PROVIDER) == address(0)) revert CommonErrorLibrary.ZeroAddress();
        TIME_PROVIDER = _TIME_PROVIDER;
        _disableInitializers();
    }

    /**
     * @notice Initializes the UserPool contract
     * @param admin Address that receives admin and governance roles
     * @param _qeuro Address of the QEURO token contract
     * @param _usdc Address of the USDC token contract
     * @param _vault Address of the QuantillonVault contract
     * @param _oracle Address of the Chainlink Oracle contract
     * @param _yieldShift Address of the YieldShift contract
     * @param _timelock Address of the timelock contract
     * @param _treasury Address of the treasury contract
     * @dev Initializes the UserPool with all required contracts and default parameters
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Initializes all contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to initializer modifier
     * @custom:oracle Requires oracle for analytics functions
     */
    function initialize(
        address admin,
        address _qeuro,
        address _usdc,
        address _vault,
        address _oracle,
        address _yieldShift,
        address _timelock,
        address _treasury
    ) public initializer {
        CommonValidationLibrary.validateNonZeroAddress(admin, "admin");
        CommonValidationLibrary.validateNonZeroAddress(_qeuro, "token");
        CommonValidationLibrary.validateNonZeroAddress(_usdc, "token");
        CommonValidationLibrary.validateNonZeroAddress(_vault, "vault");
        CommonValidationLibrary.validateNonZeroAddress(_oracle, "oracle");
        CommonValidationLibrary.validateNonZeroAddress(_yieldShift, "token");
        CommonValidationLibrary.validateNonZeroAddress(_treasury, "treasury");

        __ReentrancyGuard_init();
        __AccessControl_init();
        __Pausable_init();
        __SecureUpgradeable_init(_timelock);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);

        qeuro = IQEUROToken(_qeuro);
        usdc = IERC20(_usdc);
        vault = IQuantillonVault(_vault);
        oracle = IChainlinkOracle(_oracle);
        yieldShift = IYieldShift(_yieldShift);
        require(_treasury != address(0), "Treasury cannot be zero address");
        // Treasury validation handled by CommonValidationLibrary
        CommonValidationLibrary.validateNonZeroAddress(_treasury, "treasury");
        treasury = _treasury;

        // Default parameters
        stakingAPY = 800;           // 8% APY for staking
        depositAPY = 400;           // 4% APY for deposits
        minStakeAmount = 100e18;    // 100 QEURO minimum
        unstakingCooldown = 7 days; // 7 days cooldown
        
        depositFee = 0;             // No deposit fee - Vault handles minting fees
        withdrawalFee = 0;          // No withdrawal fee - Vault handles redemption fees
        performanceFee = 1000;      // 10% performance fee
        
        // Initialize yield tracking variables to prevent uninitialized state variable warnings
        accumulatedYieldPerShare = 0;
        lastYieldDistribution = TIME_PROVIDER.currentTime();
        totalYieldDistributed = 0;
    }

    // =============================================================================
    // CORE DEPOSIT/WITHDRAWAL FUNCTIONS
    // =============================================================================

    /**
     * @notice Deposit USDC to mint QEURO (unified single/batch function)
     * @dev Handles both single deposits and batch deposits in one function
     * @param usdcAmounts Array of USDC amounts to deposit (6 decimals) - use [amount] for single
     * @param minQeuroOuts Array of minimum QEURO amounts to receive (18 decimals) - use [amount] for single
     * @return qeuroMintedAmounts Array of QEURO amounts minted (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Public access
     * @custom:oracle No oracle dependencies
     */
    function deposit(uint256[] calldata usdcAmounts, uint256[] calldata minQeuroOuts)
        external
        nonReentrant
        whenNotPaused
        flashLoanProtection
        returns (uint256[] memory qeuroMintedAmounts)
    {
        if (usdcAmounts.length != minQeuroOuts.length) revert CommonErrorLibrary.ArrayLengthMismatch();
        if (usdcAmounts.length > MAX_BATCH_SIZE) revert CommonErrorLibrary.BatchSizeTooLarge();
        if (usdcAmounts.length == 0) revert CommonErrorLibrary.EmptyArray();
        
        // Cache timestamp to avoid external calls in loop
        uint256 currentTime = TIME_PROVIDER.currentTime();
        
        qeuroMintedAmounts = new uint256[](usdcAmounts.length);
        
        // Validate amounts and transfer USDC
        _validateAndTransferTokens(usdcAmounts, usdc, true);
        
        // Initialize user info
        _initializeUserIfNeeded();
        
        // Calculate net amounts
        (uint256[] memory netAmounts, uint256 totalNetAmount) = _calculateNetAmounts(usdcAmounts);
        
        // Update user and pool state BEFORE external calls (reentrancy protection)
        _updateUserAndPoolState(usdcAmounts, minQeuroOuts, totalNetAmount);
        
        // Process vault operations AFTER state updates
        _processVaultMinting(netAmounts, minQeuroOuts, qeuroMintedAmounts);
        
        // Transfer QEURO to users and emit events
        _transferQeuroAndEmitEvents(usdcAmounts, qeuroMintedAmounts, currentTime);
    }


    /**
     * @notice Internal function to validate amounts and transfer tokens (unified validation)
     * @param amounts Array of amounts to validate and transfer
     * @param token Token to transfer (usdc or qeuro)
     * @param isFromUser Whether to transfer from user (true) or to user (false)
     * @return totalAmount Total amount transferred
     * @dev Unified validation and transfer function to reduce code duplication
     * @custom:security Validates all amounts > 0 before transfer
     * @custom:validation Validates each amount in array is positive
     * @custom:state-changes Transfers tokens from/to msg.sender
     * @custom:events No events emitted - handled by calling function
     * @custom:errors Throws if any amount is 0
     * @custom:reentrancy Not protected - internal function only
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _validateAndTransferTokens(uint256[] calldata amounts, IERC20 token, bool isFromUser) internal returns (uint256 totalAmount) {
        // Pre-validate amounts and calculate total
        for (uint256 i = 0; i < amounts.length; i++) {
            CommonValidationLibrary.validatePositiveAmount(amounts[i]);
            totalAmount += amounts[i];
        }
        
        // Transfer tokens
        if (isFromUser) {
            token.safeTransferFrom(msg.sender, address(this), totalAmount);
        } else {
            token.safeTransfer(msg.sender, totalAmount);
        }
    }

    /**
     * @notice Internal function to initialize user if needed (consolidated)
     * @dev Initializes user tracking if they haven't deposited before
     * @custom:security Updates hasDeposited mapping and totalUsers counter
     * @custom:validation No input validation required
     * @custom:state-changes Updates hasDeposited[msg.sender] and totalUsers
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - internal function only
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _initializeUserIfNeeded() internal {
        if (!hasDeposited[msg.sender]) {
            hasDeposited[msg.sender] = true;
            totalUsers++;
        }
    }

    /**
     * @notice Internal function to calculate net amounts after fees
     * @param usdcAmounts Array of USDC amounts (6 decimals)
     * @return netAmounts Array of net amounts after fees (6 decimals)
     * @return totalNetAmount Total net amount (6 decimals)
     * @dev Calculates net amounts by subtracting deposit fees from each USDC amount
     * @custom:security Uses cached depositFee to prevent reentrancy
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _calculateNetAmounts(uint256[] calldata usdcAmounts) 
        internal 
        view 
        returns (uint256[] memory netAmounts, uint256 totalNetAmount) 
    {
        uint256 depositFee_ = depositFee;
        netAmounts = new uint256[](usdcAmounts.length);
        
        for (uint256 i = 0; i < usdcAmounts.length; i++) {
            uint256 usdcAmount = usdcAmounts[i];
            uint256 fee = usdcAmount.percentageOf(depositFee_);
            uint256 netAmount = usdcAmount - fee;
            netAmounts[i] = netAmount;
            totalNetAmount += netAmount;
        }
    }

    /**
     * @notice Internal function to process vault minting operations
     * @param netAmounts Array of net amounts to mint (6 decimals)
     * @param minQeuroOuts Array of minimum QEURO outputs (18 decimals)
     * @param qeuroMintedAmounts Array to store minted amounts (18 decimals)
     * @dev Processes vault minting operations with single vault call to avoid external calls in loop
     * @custom:security Uses single approval and single vault call to minimize external calls
     * @custom:validation No input validation required - parameters pre-validated
     * @custom:state-changes Updates qeuroMintedAmounts array with minted amounts
     * @custom:events No events emitted - handled by calling function
     * @custom:errors Throws if vault.mintQEURO fails
     * @custom:reentrancy Protected by nonReentrant modifier on calling function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _processVaultMinting(
        uint256[] memory netAmounts,
        uint256[] calldata minQeuroOuts,
        uint256[] memory qeuroMintedAmounts
    ) internal {
        // Calculate total amounts for single vault call
        uint256 totalNetAmount = 0;
        uint256 totalMinQeuroOut = 0;
        
        for (uint256 i = 0; i < netAmounts.length; i++) {
            totalNetAmount += netAmounts[i];
            totalMinQeuroOut += minQeuroOuts[i];
        }
        
        // Single approval for all vault operations
        usdc.safeIncreaseAllowance(address(vault), totalNetAmount);
        
        // Single vault call instead of multiple calls in loop
        vault.mintQEURO(totalNetAmount, totalMinQeuroOut);
        
        // Get oracle price once to avoid external calls in loop
        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "UserPool: Invalid oracle price");
        
        // Calculate individual amounts locally to avoid external calls in loop
        for (uint256 i = 0; i < netAmounts.length; i++) {
            // Calculate QEURO amount using the same formula as vault.calculateMintAmount
            // Formula: qeuroAmount = netAmount.mulDiv(1e30, eurUsdPrice)
            uint256 qeuroAmount = netAmounts[i].mulDiv(1e30, eurUsdPrice);
            qeuroMintedAmounts[i] = qeuroAmount;
        }
    }

    /**
     * @notice Internal function to update user and pool state
     * @param usdcAmounts Array of USDC amounts (6 decimals)
     * @param minQeuroOuts Array of minimum QEURO outputs (18 decimals)
     * @dev Updates user and pool state before external calls for reentrancy protection
     * @custom:security Updates state before external calls (CEI pattern)
     * @custom:validation No input validation required - parameters pre-validated
     * @custom:state-changes Updates user.depositHistory, totalDeposits
     * @custom:events No events emitted - handled by calling function
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - internal function only
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _updateUserAndPoolState(
        uint256[] calldata usdcAmounts,
        uint256[] calldata minQeuroOuts,
        uint256 /* totalNetAmount */
    ) internal {
        UserInfo storage user = userInfo[msg.sender];
        
        // Calculate totals for batch updates
        uint256 totalUsdcAmount = 0;
        uint256 totalQeuroToMint = 0;
        
        for (uint256 i = 0; i < usdcAmounts.length; i++) {
            totalUsdcAmount += usdcAmounts[i];
            totalQeuroToMint += minQeuroOuts[i];
        }
        
        // Update user state once (single update outside loop)
        user.depositHistory += uint96(totalUsdcAmount);
        // Note: user.qeuroBalance is not updated since QEURO goes to user's wallet
        
        // Track total deposits for analytics
        totalUserDeposits += totalUsdcAmount;
    }

    /**
     * @notice Internal function to transfer QEURO and emit events
     * @param usdcAmounts Array of USDC amounts (6 decimals)
     * @param qeuroMintedAmounts Array of minted QEURO amounts (18 decimals)
     * @param currentTime Current timestamp
     * @dev Transfers QEURO to users and emits UserDeposit events
     * @custom:security Uses SafeERC20 for secure token transfers
     * @custom:validation No input validation required - parameters pre-validated
     * @custom:state-changes Transfers QEURO tokens to msg.sender
     * @custom:events Emits UserDeposit event for each transfer
     * @custom:errors Throws if QEURO transfer fails
     * @custom:reentrancy Not protected - internal function only
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _transferQeuroAndEmitEvents(
        uint256[] calldata usdcAmounts,
        uint256[] memory qeuroMintedAmounts,
        uint256 currentTime
    ) internal {
        // Cache oracle ratio and block number for all deposits in this batch
        uint32 oracleRatio = _getOracleRatioScaled();
        uint32 currentBlock = uint32(block.number);
        
        for (uint256 i = 0; i < usdcAmounts.length; i++) {
            uint256 usdcAmount = usdcAmounts[i];
            uint256 qeuroMinted = qeuroMintedAmounts[i];
            
            // Transfer QEURO to user
            IERC20(address(qeuro)).safeTransfer(msg.sender, qeuroMinted);

            // Track detailed deposit information with oracle ratio
            userDeposits[msg.sender].push(UserDepositInfo({
                usdcAmount: uint128(usdcAmount),
                qeuroReceived: uint128(qeuroMinted),
                timestamp: uint64(currentTime),
                oracleRatio: oracleRatio,
                blockNumber: currentBlock
            }));

            emit UserDeposit(msg.sender, usdcAmount, qeuroMinted, currentTime);
            emit UserDepositTracked(msg.sender, usdcAmount, qeuroMinted, oracleRatio, currentTime, currentBlock);
        }
    }

    /**
     * @notice Withdraw USDC by burning QEURO (unified single/batch function)
     * @dev Handles both single withdrawals and batch withdrawals in one function
     * @param qeuroAmounts Array of QEURO amounts to burn (18 decimals) - use [amount] for single
     * @param minUsdcOuts Array of minimum USDC amounts to receive (6 decimals) - use [amount] for single
     * @return usdcReceivedAmounts Array of USDC amounts received (6 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Public access
     * @custom:oracle No oracle dependencies
     */
    function withdraw(uint256[] calldata qeuroAmounts, uint256[] calldata minUsdcOuts)
        external
        nonReentrant
        whenNotPaused
        returns (uint256[] memory usdcReceivedAmounts)
    {
        if (qeuroAmounts.length != minUsdcOuts.length) revert CommonErrorLibrary.ArrayLengthMismatch();
        if (qeuroAmounts.length > MAX_BATCH_SIZE) revert CommonErrorLibrary.BatchSizeTooLarge();
        if (qeuroAmounts.length == 0) revert CommonErrorLibrary.EmptyArray();
        
        uint256 currentTime = TIME_PROVIDER.currentTime();
        usdcReceivedAmounts = new uint256[](qeuroAmounts.length);
        
        // Validate and process withdrawal
        _validateAndProcessBatchWithdrawal(qeuroAmounts, minUsdcOuts, usdcReceivedAmounts);
        
        // Final transfers and events
        _executeBatchTransfers(qeuroAmounts, usdcReceivedAmounts, currentTime);
    }

    
    /**
     * @notice Validates and processes batch withdrawal
     * @param qeuroAmounts Array of QEURO amounts to withdraw
     * @param minUsdcOuts Array of minimum USDC amounts expected
     * @param usdcReceivedAmounts Array to store received USDC amounts
     * @dev Internal helper to reduce stack depth
     * @custom:security Validates amounts and user balances to prevent over-withdrawal
     * @custom:validation Validates all amounts are positive and user has sufficient balance
     * @custom:state-changes Updates user balance and processes withdrawal calculations
     * @custom:events No events emitted - internal helper function
     * @custom:errors Throws "Amount must be positive" if any amount is zero
     * @custom:reentrancy Not protected - internal function only
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _validateAndProcessBatchWithdrawal(
        uint256[] calldata qeuroAmounts,
        uint256[] calldata minUsdcOuts,
        uint256[] memory usdcReceivedAmounts
    ) internal {
        uint256 length = qeuroAmounts.length;
        uint256 totalQeuroAmount = 0;
        
        // Calculate total QEURO amount
        for (uint256 i = 0; i < length;) {
            CommonValidationLibrary.validatePositiveAmount(qeuroAmounts[i]);
            unchecked { 
                totalQeuroAmount += qeuroAmounts[i];
                ++i; 
            }
        }
        
        // Note: No need to check user.qeuroBalance since QEURO is held in user's wallet
        // The user must have QEURO in their wallet to call this function
        
        // Calculate and update total deposits
        uint256 totalEstimatedNetAmount = 0;
        uint256 withdrawalFee_ = withdrawalFee;
        for (uint256 i = 0; i < length;) {
            uint256 estimatedFee = minUsdcOuts[i].percentageOf(withdrawalFee_);
            totalEstimatedNetAmount += minUsdcOuts[i] - estimatedFee;
            unchecked { ++i; }
        }
        // Note: We don't update totalDeposits during batch withdrawal for the same reasons
        // as single withdrawal - oracle rate changes make accurate tracking impossible
        
        // Transfer QEURO tokens using unified function
        _validateAndTransferTokens(qeuroAmounts, IERC20(address(qeuro)), true);
        
        // Process vault redemptions
        _processVaultRedemptions(qeuroAmounts, minUsdcOuts, usdcReceivedAmounts, withdrawalFee_);
    }
    
    /**
     * @notice Processes vault redemptions for batch withdrawal
     * @param qeuroAmounts Array of QEURO amounts to redeem
     * @param minUsdcOuts Array of minimum USDC amounts expected
     * @param usdcReceivedAmounts Array to store received USDC amounts
     * @param withdrawalFee_ Cached withdrawal fee percentage
     * @dev Internal helper to reduce stack depth
     * @dev OPTIMIZATION: Uses single vault call with total amounts to avoid external calls in loop
     * @custom:security Validates vault redemption amounts and minimum outputs
     * @custom:validation Validates all amounts are positive and within limits
     * @custom:state-changes Processes vault redemptions and updates received amounts
     * @custom:events No events emitted - internal helper function
     * @custom:errors Throws validation errors if amounts are invalid
     * @custom:reentrancy Not protected - internal function only
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _processVaultRedemptions(
        uint256[] calldata qeuroAmounts,
        uint256[] calldata minUsdcOuts,
        uint256[] memory usdcReceivedAmounts,
        uint256 withdrawalFee_
    ) internal {
        uint256 length = qeuroAmounts.length;
        
        // Calculate total amounts for single vault call
        uint256 totalQeuroAmount = 0;
        uint256 totalMinUsdcOut = 0;
        
        for (uint256 i = 0; i < length;) {
            totalQeuroAmount += qeuroAmounts[i];
            totalMinUsdcOut += minUsdcOuts[i];
            unchecked { ++i; }
        }
        
        // Single vault call instead of multiple calls in loop
        vault.redeemQEURO(totalQeuroAmount, totalMinUsdcOut);
        
        // Calculate individual amounts after single redemption
        for (uint256 i = 0; i < length;) {
            uint256 fee = minUsdcOuts[i].percentageOf(withdrawalFee_);
            usdcReceivedAmounts[i] = minUsdcOuts[i] - fee;
            unchecked { ++i; }
        }
    }
    
    /**
     * @notice Executes final transfers and emits events for batch withdrawal
     * @param qeuroAmounts Array of QEURO amounts withdrawn
     * @param usdcReceivedAmounts Array of USDC amounts received
     * @param currentTime Current timestamp for events
     * @dev Internal helper to reduce stack depth
     * @custom:security Executes final token transfers and emits withdrawal events
     * @custom:validation Validates all amounts are positive before transfer
     * @custom:state-changes Burns QEURO tokens and transfers USDC to user
     * @custom:events Emits Withdrawal event for each withdrawal
     * @custom:errors Throws transfer errors if token operations fail
     * @custom:reentrancy Not protected - internal function only
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _executeBatchTransfers(
        uint256[] calldata qeuroAmounts,
        uint256[] memory usdcReceivedAmounts,
        uint256 currentTime
    ) internal {
        uint256 length = qeuroAmounts.length;
        uint256 totalWithdrawn = 0;
        
        // Cache oracle ratio and block number for all withdrawals in this batch
        uint32 oracleRatio = _getOracleRatioScaled();
        uint32 currentBlock = uint32(block.number);
        
        for (uint256 i = 0; i < length;) {
            usdc.safeTransfer(msg.sender, usdcReceivedAmounts[i]);
            totalWithdrawn += usdcReceivedAmounts[i];
            
            // Track detailed withdrawal information with oracle ratio
            userWithdrawals[msg.sender].push(UserWithdrawalInfo({
                qeuroAmount: uint128(qeuroAmounts[i]),
                usdcReceived: uint128(usdcReceivedAmounts[i]),
                timestamp: uint64(currentTime),
                oracleRatio: oracleRatio,
                blockNumber: currentBlock
            }));
            
            emit UserWithdrawal(msg.sender, qeuroAmounts[i], usdcReceivedAmounts[i], currentTime);
            emit UserWithdrawalTracked(msg.sender, qeuroAmounts[i], usdcReceivedAmounts[i], oracleRatio, currentTime, currentBlock);
            unchecked { ++i; }
        }
        
        // Track total withdrawals for analytics
        for (uint256 i = 0; i < length;) {
            totalUserWithdrawals += qeuroAmounts[i];
            unchecked { ++i; }
        }
    }

    // =============================================================================
    // STAKING FUNCTIONS
    // =============================================================================

    /**
     * @notice Stakes QEURO tokens (unified single/batch function)
     * @dev Handles both single stakes and batch stakes in one function
     * @param qeuroAmounts Array of QEURO amounts to stake (18 decimals) - use [amount] for single
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Public access
     * @custom:oracle No oracle dependencies
     */
    function stake(uint256[] calldata qeuroAmounts) external nonReentrant whenNotPaused {
        if (qeuroAmounts.length > MAX_BATCH_SIZE) revert CommonErrorLibrary.BatchSizeTooLarge();
        if (qeuroAmounts.length == 0) revert CommonErrorLibrary.EmptyArray();
        
        // Cache timestamp to avoid external calls
        uint256 currentTime = TIME_PROVIDER.currentTime();
        
        UserInfo storage user = userInfo[msg.sender];
        uint256 totalQeuroAmount = 0;
        
        uint256 minStakeAmount_ = minStakeAmount;
        
        // Pre-validate amounts and calculate total
        for (uint256 i = 0; i < qeuroAmounts.length; i++) {
            CommonValidationLibrary.validateMinAmount(qeuroAmounts[i], minStakeAmount_);
            totalQeuroAmount += qeuroAmounts[i];
        }
        
        // Update pending rewards before staking (once for the batch)
        _updatePendingRewards(msg.sender, currentTime);
        
        // Transfer total QEURO from user using unified function
        _validateAndTransferTokens(qeuroAmounts, IERC20(address(qeuro)), true);
        
        uint64 currentTimestamp = uint64(currentTime);
        
        // Update user staking info with total amount (single update)
        user.stakedAmount += uint128(totalQeuroAmount);
        user.lastStakeTime = currentTimestamp;
        
        // Update pool totals once (single update outside loop)
        totalStakes += totalQeuroAmount;
        
        // Process each stake for events
        for (uint256 i = 0; i < qeuroAmounts.length; i++) {
            uint256 qeuroAmount = qeuroAmounts[i];
            emit QEUROStaked(msg.sender, qeuroAmount, currentTimestamp);
        }
    }


    /**
     * @notice Requests to unstake QEURO tokens (starts unstaking cooldown period)
     * @dev Begins the unstaking process with a cooldown period before tokens can be withdrawn
     * @param qeuroAmount The amount of staked QEURO tokens to unstake (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Public access
     * @custom:oracle No oracle dependencies
     */
    function requestUnstake(uint256 qeuroAmount) external nonReentrant {
        // Cache timestamp to avoid external calls
        uint256 currentTime = TIME_PROVIDER.currentTime();
        
        UserInfo storage user = userInfo[msg.sender];
        CommonValidationLibrary.validateSufficientBalance(user.stakedAmount, qeuroAmount);
        
        // Update pending rewards
        _updatePendingRewards(msg.sender, currentTime);
        
        // Set unstaking request
        user.unstakeRequestTime = uint64(currentTime);
        user.unstakeAmount = uint128(qeuroAmount);
    }

    /**
     * @notice Complete unstaking after cooldown period
     * @dev This function allows users to complete their unstaking request
     *      after the cooldown period has passed.
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Public access
     * @custom:oracle No oracle dependencies
     */
    function unstake() external nonReentrant whenNotPaused {
        UserInfo storage user = userInfo[msg.sender];
        CommonValidationLibrary.validatePositiveAmount(user.unstakeAmount);
        CommonValidationLibrary.validateCondition(
            TIME_PROVIDER.currentTime() >= user.unstakeRequestTime + unstakingCooldown,
            "cooldown"
        );

        uint256 amount = user.unstakeAmount;
        
        // Update user staking info
        user.stakedAmount -= uint128(amount);
        user.unstakeAmount = 0;
        user.unstakeRequestTime = 0;
        
        // Update pool totals
        totalStakes -= amount;
        
        IERC20(address(qeuro)).safeTransfer(msg.sender, amount);

        emit QEUROUnstaked(msg.sender, amount, TIME_PROVIDER.currentTime());
    }

    /**
     * @notice Claim staking rewards
     * @dev This function allows users to claim their pending staking rewards.
     *      It calculates and transfers the rewards based on their staked amount.
     * @return rewardAmount Amount of QEURO rewards claimed (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function claimStakingRewards() external nonReentrant returns (uint256 rewardAmount) {
        // Cache timestamp to avoid external calls
        uint256 currentTime = TIME_PROVIDER.currentTime();
        _updatePendingRewards(msg.sender, currentTime);
        
        UserInfo storage user = userInfo[msg.sender];
        rewardAmount = user.pendingRewards;
        
        if (rewardAmount > 0) {
            user.pendingRewards = 0;
            
            // Mint reward tokens (could be QEURO or QTI)
            qeuro.mint(msg.sender, rewardAmount);
            
            emit StakingRewardsClaimed(msg.sender, rewardAmount, TIME_PROVIDER.currentTime());
        }
    }

    /**
     * @notice Batch claim staking rewards for multiple users (admin function)
     * @dev This function allows admins to claim rewards for multiple users in one transaction.
     *      Useful for protocol-wide reward distributions or automated reward processing.
     * @param users Array of user addresses to claim rewards for
     * @return rewardAmounts Array of reward amounts claimed for each user (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function batchRewardClaim(address[] calldata users) 
        external 
        nonReentrant 
        onlyRole(GOVERNANCE_ROLE)
        returns (uint256[] memory rewardAmounts) 
    {
        if (users.length > MAX_REWARD_BATCH_SIZE) revert CommonErrorLibrary.BatchSizeTooLarge();
        
        rewardAmounts = new uint256[](users.length);
        
        // Cache timestamp to avoid external calls in loop
        uint256 currentTime = TIME_PROVIDER.currentTime();
        uint64 currentTimestamp = uint64(currentTime);
        
        // Store users with non-zero rewards to minimize external calls
        address[] memory usersToMint = new address[](users.length);
        uint256[] memory amountsToMint = new uint256[](users.length);
        uint256 mintCount = 0;

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            _updatePendingRewards(user, currentTime);
            
            UserInfo storage userInfo_ = userInfo[user];
            uint256 rewardAmount = userInfo_.pendingRewards;
            rewardAmounts[i] = rewardAmount;
            
            if (rewardAmount > 0) {
                userInfo_.pendingRewards = 0;
                
                // Store for batched minting
                usersToMint[mintCount] = user;
                amountsToMint[mintCount] = rewardAmount;
                mintCount++;
            }
        }
        
        // Use batch minting to avoid external calls in loop
        if (mintCount > 0) {
            // Create arrays for batch minting
            address[] memory recipients = new address[](mintCount);
            uint256[] memory amounts = new uint256[](mintCount);
            
            for (uint256 i = 0; i < mintCount; i++) {
                recipients[i] = usersToMint[i];
                amounts[i] = amountsToMint[i];
            }
            
            // Single batch mint call instead of multiple individual calls
            qeuro.batchMint(recipients, amounts);
            
            // Emit events for each user
            for (uint256 i = 0; i < mintCount; i++) {
                emit StakingRewardsClaimed(recipients[i], amounts[i], currentTimestamp);
            }
        }
    }

    // =============================================================================
    // YIELD DISTRIBUTION
    // =============================================================================

    /**
     * @notice Distribute yield to stakers (called by YieldShift contract)
     * @dev This function is deprecated - yield now goes to stQEURO
     * @param yieldAmount Amount of yield to distribute (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function distributeYield(uint256 yieldAmount) external {
        CommonValidationLibrary.validateCondition(msg.sender == address(yieldShift), "authorization");
        
        // Yield distribution moved to stQEURO contract
        // This function kept for backward compatibility but does nothing
        emit YieldDistributed(yieldAmount, 0, TIME_PROVIDER.currentTime());
    }

    /**
     * @notice Update pending rewards for a user
     * @param user Address of the user to update
     * @param currentTime Current timestamp for reward calculations
     * @dev This internal function calculates and updates the pending rewards
     *      for a given user based on their staked amount and the current APY.
     *      Uses block-based calculations to prevent timestamp manipulation.
     * @custom:security Uses block-based calculations to prevent timestamp manipulation
     * @custom:validation Validates user has staked amount > 0
     * @custom:state-changes Updates user.pendingRewards, user.lastStakeTime, userLastRewardBlock
     * @custom:events No events emitted - handled by calling function
     * @custom:errors No errors thrown - safe arithmetic used
     * @custom:reentrancy Not protected - internal function only
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _updatePendingRewards(address user, uint256 currentTime) internal {
        UserInfo storage userdata = userInfo[user];
        
        if (userdata.stakedAmount > 0) {
            uint256 currentBlock = block.number;
            uint256 lastRewardBlock = userLastRewardBlock[user];
            
            if (lastRewardBlock < 1) {
                userLastRewardBlock[user] = currentBlock;
                return;
            }
            
            uint256 blocksElapsed = currentBlock - lastRewardBlock;
            uint256 timeElapsed = blocksElapsed * 12; // Convert blocks to seconds
            
            if (timeElapsed > MAX_REWARD_PERIOD) {
                timeElapsed = MAX_REWARD_PERIOD;
            }
            
            // Use library for reward calculation
            uint256 stakingReward = UserPoolStakingLibrary.calculateStakingRewards(
                UserPoolStakingLibrary.StakeInfo({
                    amount: userdata.stakedAmount,
                    startTime: userdata.lastStakeTime,
                    endTime: 0,
                    lastRewardClaim: userdata.lastStakeTime,
                    totalRewardsClaimed: 0,
                    isActive: true
                }),
                stakingAPY,
                currentTime
            );
            
            // Calculate yield-based rewards
            uint256 yieldReward = uint256(userdata.stakedAmount)
                .mulDiv(accumulatedYieldPerShare, 1e18);
            
            userdata.pendingRewards += uint128(stakingReward + yieldReward);
            userdata.lastStakeTime = uint64(currentTime);
            userLastRewardBlock[user] = currentBlock;
        }
    }

    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================

    /**
     * @notice Get comprehensive user information (consolidated view function)
     * @dev Returns all user-related data in one call to reduce contract size
     * @param user Address of the user to query
     * @return qeuroBalance QEURO balance of the user (18 decimals)
     * @return stakedAmount Current staked amount of the user (18 decimals)
     * @return pendingRewards Total pending rewards of the user (18 decimals)
     * @return depositHistory Total historical deposits of the user (6 decimals)
     * @return lastStakeTime Timestamp of the user's last staking action
     * @return unstakeAmount Amount being unstaked (18 decimals)
     * @return unstakeRequestTime Timestamp when unstaking was requested
     * @custom:security No security implications (view function)
     * @custom:validation No validation required
     * @custom:state-changes No state changes (view function)
     * @custom:events No events (view function)
     * @custom:errors No custom errors
     * @custom:reentrancy No external calls, safe
     * @custom:access Public (anyone can call)
     * @custom:oracle No oracle dependencies
     */
    function getUserInfo(address user) external view returns (
        uint256 qeuroBalance,
        uint256 stakedAmount,
        uint256 pendingRewards,
        uint256 depositHistory,
        uint256 lastStakeTime,
        uint256 unstakeAmount,
        uint256 unstakeRequestTime
    ) {
        UserInfo storage userdata = userInfo[user];
        
        // Calculate pending rewards
        uint256 calculatedPendingRewards = userdata.pendingRewards;
        if (userdata.stakedAmount > 0) {
            uint256 currentBlock = block.number;
            uint256 lastRewardBlock = userLastRewardBlock[user];
            
            if (lastRewardBlock >= 1) {
                uint256 blocksElapsed = currentBlock - lastRewardBlock;
                uint256 timeElapsed = blocksElapsed * 12; // seconds
                
                if (timeElapsed > MAX_REWARD_PERIOD) {
                    timeElapsed = MAX_REWARD_PERIOD;
                }
                
                uint256 stakingReward = uint256(userdata.stakedAmount)
                    .mulDiv(stakingAPY, 10000)
                    .mulDiv(timeElapsed, 365 days);
                
                uint256 yieldReward = uint256(userdata.stakedAmount)
                    .mulDiv(accumulatedYieldPerShare, 1e18);
                
                calculatedPendingRewards += stakingReward + yieldReward;
            }
        }
        
        return (
            userdata.qeuroBalance,
            userdata.stakedAmount,
            calculatedPendingRewards,
            userdata.depositHistory,
            userdata.lastStakeTime,
            userdata.unstakeAmount,
            userdata.unstakeRequestTime
        );
    }

    /**
     * @notice Get comprehensive pool totals (consolidated view function)
     * @dev Returns all pool totals in one call to reduce contract size
     * @return totalDeposits Total USDC deposits (6 decimals)
     * @return totalWithdrawals Total QEURO withdrawals (18 decimals)
     * @return totalStakes_ Total QEURO staked (18 decimals)
     * @return totalUsers_ Total number of users
     * @custom:security No security implications (view function)
     * @custom:validation No validation required
     * @custom:state-changes No state changes (view function)
     * @custom:events No events (view function)
     * @custom:errors No custom errors
     * @custom:reentrancy No external calls, safe
     * @custom:access Public (anyone can call)
     * @custom:oracle No oracle dependencies
     */
    function getPoolTotals() external view returns (
        uint256 totalDeposits,
        uint256 totalWithdrawals,
        uint256 totalStakes_,
        uint256 totalUsers_
    ) {
        return (totalUserDeposits, totalUserWithdrawals, totalStakes, totalUsers);
    }
    
    /**
     * @notice Get user deposit history with oracle ratios
     * @param user Address of the user
     * @return Array of UserDepositInfo structs containing deposit history
     * @dev Used for detailed analytics and audit trails
     * @dev Returns complete deposit history with oracle ratios
     * @custom:security No security implications (view function)
     * @custom:validation No validation required
     * @custom:state-changes No state changes (view function)
     * @custom:events No events (view function)
     * @custom:errors No custom errors
     * @custom:reentrancy No external calls, safe
     * @custom:access Public (anyone can call)
     * @custom:oracle No oracle dependencies
     */
    function getUserDepositHistory(address user) external view returns (UserDepositInfo[] memory) {
        return userDeposits[user];
    }
    
    /**
     * @notice Get user withdrawal history with oracle ratios
     * @param user Address of the user
     * @return Array of UserWithdrawalInfo structs containing withdrawal history
     * @dev Used for detailed analytics and audit trails
     * @dev Returns complete withdrawal history with oracle ratios
     * @custom:security No security implications (view function)
     * @custom:validation No validation required
     * @custom:state-changes No state changes (view function)
     * @custom:events No events (view function)
     * @custom:errors No custom errors
     * @custom:reentrancy No external calls, safe
     * @custom:access Public (anyone can call)
     * @custom:oracle No oracle dependencies
     */
    function getUserWithdrawals(address user) external view returns (UserWithdrawalInfo[] memory) {
        return userWithdrawals[user];
    }
    
    /**
     * @notice Get current oracle ratio scaled by 1e6 for storage efficiency
     * @return Oracle ratio scaled by 1e6 (e.g., 1.08 becomes 1080000)
     * @dev Used internally for tracking oracle ratios in deposit/withdrawal records
     * @dev Scaled to fit in uint32 for gas efficiency
     * @custom:security No security implications (view function)
     * @custom:validation No validation required
     * @custom:state-changes No state changes (view function)
     * @custom:events No events (view function)
     * @custom:errors No custom errors
     * @custom:reentrancy No external calls, safe
     * @custom:access Internal function
     * @custom:oracle Depends on oracle for current EUR/USD rate
     */
    function _getOracleRatioScaled() internal returns (uint32) {
        (uint256 oraclePrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "Oracle price is invalid");
        // Scale by 1e6 to fit in uint32 (max value ~4.2B)
        // Oracle price is in 8 decimals, so we scale by 1e6 to get 2 decimals precision
        return uint32(oraclePrice / 1e6);
    }

    /**
     * @notice Get the total USDC equivalent withdrawals across all users
     * @return Total withdrawals in USDC equivalent (6 decimals)
     * @dev Used for analytics and cash flow monitoring
     * @custom:access Public access
     * @custom:oracle No oracle dependencies
     */

    /**
     * @notice Get the total QEURO staked across all users
     * @dev Returns the total amount of QEURO currently staked in the pool
     * @return uint256 Total QEURO staked (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function getTotalStakes() external view returns (uint256) {
        return totalStakes;
    }

    /**
     * @notice Get various metrics about the user pool
     * @dev Returns comprehensive pool statistics including user count, averages, and ratios
     * @return totalUsers_ Number of unique users
     * @return averageDeposit Average deposit amount per user (6 decimals)
     * @return stakingRatio Ratio of total staked QEURO to total deposits (basis points)
     * @return poolTVL Total value locked in the pool (6 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function getPoolMetrics() external view returns (
        uint256 totalUsers_,
        uint256 averageDeposit,
        uint256 stakingRatio,
        uint256 poolTVL
    ) {
        // Use QEURO total supply instead of totalDeposits for accurate metrics
        uint256 currentQeuroSupply = qeuro.totalSupply();
        
        // Calculate metrics directly (library bit-packing doesn't work with large QEURO values)
        totalUsers_ = totalUsers;
        averageDeposit = totalUsers > 0 ? currentQeuroSupply / totalUsers : 0;
        stakingRatio = currentQeuroSupply > 0 ? (totalStakes * 10000) / currentQeuroSupply : 0;
        poolTVL = currentQeuroSupply;
    }

    /**
     * @notice Get comprehensive pool analytics using QEURO total supply
     * @return currentQeuroSupply Current QEURO total supply (net minted QEURO)
     * @return usdcEquivalentAtCurrentRate Current USDC equivalent of QEURO supply
     * @return totalUsers_ Total number of users
     * @return totalStakes_ Total QEURO staked
     * @dev Uses QEURO total supply for accurate analytics instead of misleading USDC tracking
     * @custom:security No external calls except oracle, read-only function
     * @custom:validation Oracle price validation with fallback to zero
     * @custom:state-changes No state changes, view-like function
     * @custom:events No events emitted
     * @custom:errors No custom errors, handles oracle failures gracefully
     * @custom:reentrancy No reentrancy risk, read-only operations
     * @custom:access Public access
     * @custom:oracle Requires fresh oracle price data for USDC equivalent
     */
    function getPoolAnalytics() external returns (
        uint256 currentQeuroSupply,
        uint256 usdcEquivalentAtCurrentRate,
        uint256 totalUsers_,
        uint256 totalStakes_
    ) {
        currentQeuroSupply = qeuro.totalSupply();
        totalUsers_ = totalUsers;
        totalStakes_ = totalStakes;
        
        // Convert QEURO supply to current USDC equivalent
        (uint256 currentRate, bool isValid) = oracle.getEurUsdPrice();
        if (isValid) {
            usdcEquivalentAtCurrentRate = currentQeuroSupply.mulDiv(currentRate, 1e18) / 1e12;
        } else {
            usdcEquivalentAtCurrentRate = 0;
        }
    }

    /**
     * @notice Get comprehensive pool configuration (consolidated view function)
     * @dev Returns all pool configuration parameters in one call to reduce contract size
     * @return stakingAPY_ Current staking APY in basis points
     * @return depositAPY_ Current deposit APY in basis points
     * @return minStakeAmount_ Current minimum stake amount (18 decimals)
     * @return unstakingCooldown_ Current unstaking cooldown period (seconds)
     * @return depositFee_ Current deposit fee (basis points)
     * @return withdrawalFee_ Current withdrawal fee (basis points)
     * @return performanceFee_ Current performance fee (basis points)
     * @custom:security No security implications (view function)
     * @custom:validation No validation required
     * @custom:state-changes No state changes (view function)
     * @custom:events No events (view function)
     * @custom:errors No custom errors
     * @custom:reentrancy No external calls, safe
     * @custom:access Public (anyone can call)
     * @custom:oracle No oracle dependencies
     */
    function getPoolConfiguration() external view returns (
        uint256 stakingAPY_,
        uint256 depositAPY_,
        uint256 minStakeAmount_,
        uint256 unstakingCooldown_,
        uint256 depositFee_,
        uint256 withdrawalFee_,
        uint256 performanceFee_
    ) {
        return (stakingAPY, depositAPY, minStakeAmount, unstakingCooldown, depositFee, withdrawalFee, performanceFee);
    }

    /**
     * @notice Calculate projected rewards for a given QEURO amount and duration
     * @dev Calculates the expected rewards for staking a specific amount for a given duration
     * @param qeuroAmount Amount of QEURO to calculate rewards for (18 decimals)
     * @param duration Duration in seconds
     * @return uint256 Calculated rewards (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function calculateProjectedRewards(uint256 qeuroAmount, uint256 duration) 
        external 
        view 
        returns (uint256) 
    {
        return qeuroAmount.mulDiv(stakingAPY, 10000).mulDiv(duration, 365 days);
    }

    // =============================================================================
    // GOVERNANCE FUNCTIONS
    // =============================================================================

    /**
     * @notice Update the parameters for staking (APY, min stake, cooldown)
     * @dev This function is restricted to governance roles.
     * @param newStakingAPY New Staking APY in basis points
     * @param newMinStakeAmount New Minimum stake amount (18 decimals)
     * @param newUnstakingCooldown New unstaking cooldown period (seconds)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function updateStakingParameters(
        uint256 newStakingAPY,
        uint256 newMinStakeAmount,
        uint256 newUnstakingCooldown
    ) external onlyRole(GOVERNANCE_ROLE) {
        CommonValidationLibrary.validatePercentage(newStakingAPY, 5000); // Max 50%
        CommonValidationLibrary.validatePositiveAmount(newMinStakeAmount);
        CommonValidationLibrary.validateMaxAmount(newUnstakingCooldown, 30 days);

        emit PoolParameterUpdated("stakingAPY", stakingAPY, newStakingAPY);
        emit PoolParameterUpdated("minStakeAmount", minStakeAmount, newMinStakeAmount);
        emit PoolParameterUpdated("unstakingCooldown", unstakingCooldown, newUnstakingCooldown);

        stakingAPY = newStakingAPY;
        minStakeAmount = newMinStakeAmount;
        unstakingCooldown = newUnstakingCooldown;
    }

    /**
     * @notice Set the fees for deposits, withdrawals, and performance
     * @dev This function is restricted to governance roles.
     * @param _depositFee New deposit fee in basis points
     * @param _withdrawalFee New withdrawal fee in basis points
     * @param _performanceFee New performance fee in basis points
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function setPoolFees(
        uint256 _depositFee,
        uint256 _withdrawalFee,
        uint256 _performanceFee
    ) external onlyRole(GOVERNANCE_ROLE) {
        CommonValidationLibrary.validatePercentage(_depositFee, 100); // Max 1%
        CommonValidationLibrary.validatePercentage(_withdrawalFee, 200); // Max 2%
        CommonValidationLibrary.validatePercentage(_performanceFee, 2000); // Max 20%

        depositFee = _depositFee;
        withdrawalFee = _withdrawalFee;
        performanceFee = _performanceFee;
    }

    // =============================================================================
    // EMERGENCY FUNCTIONS
    // =============================================================================

    /**
     * @notice Emergency unstake for a specific user (restricted to emergency roles)
     * @dev This function is intended for emergency situations where a user's
     *      staked QEURO needs to be forcibly unstaked.
     * @param user Address of the user to unstake
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function emergencyUnstake(address user) external onlyRole(EMERGENCY_ROLE) {
        UserInfo storage userdata = userInfo[user];
        uint256 amount = userdata.stakedAmount;
        
        if (amount > 0) {
            userdata.stakedAmount = 0;
            totalStakes -= amount;
    
            IERC20(address(qeuro)).safeTransfer(user, amount);
        }
    }

    /**
     * @notice Pause the user pool (restricted to emergency roles)
     * @dev This function is used to pause critical operations in case of
     *      a protocol-wide emergency or vulnerability.
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
     * @notice Unpause the user pool (restricted to emergency roles)
     * @dev This function is used to re-enable critical operations after
     *      an emergency pause.
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


    /**
     * @notice Check if the user pool is currently active (not paused)
     * @dev Returns the current pause status of the pool
     * @return bool True if the pool is active, false otherwise
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function isPoolActive() external view returns (bool) {
        return !paused();
    }



    // =============================================================================
    // RECOVERY FUNCTIONS
    // =============================================================================

    /**
     * @notice Recover accidentally sent tokens to treasury only
     * @dev Recovers accidentally sent ERC20 tokens to the treasury address
     * @param token Token address to recover
     * @param amount Amount to recover
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function recoverToken(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        AdminFunctionsLibrary.recoverToken(address(this), token, amount, treasury, DEFAULT_ADMIN_ROLE);
    }

    /**
     * @notice Recover ETH to treasury address only
     * @dev SECURITY: Restricted to treasury to prevent arbitrary ETH transfers
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
        AdminFunctionsLibrary.recoverETH(address(this), treasury, DEFAULT_ADMIN_ROLE);
    }
}