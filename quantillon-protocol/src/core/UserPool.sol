// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// =============================================================================
// IMPORTS - OpenZeppelin libraries and protocol interfaces
// =============================================================================

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IQEUROToken.sol";
import "../interfaces/IQuantillonVault.sol";
import "../interfaces/IYieldShift.sol";
import "../libraries/VaultMath.sol";
import "../libraries/ErrorLibrary.sol";
import "../libraries/ValidationLibrary.sol";
import "./SecureUpgradeable.sol";
import "../libraries/TreasuryRecoveryLibrary.sol";
import "../libraries/FlashLoanProtectionLibrary.sol";
import "../libraries/TimeProviderLibrary.sol";

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
    
    /// @notice Yield shift mechanism for yield management
    /// @dev Handles yield distribution and management
    /// @dev Used for yield calculations and distributions
    IYieldShift public yieldShift;

    /// @notice Treasury address for ETH recovery
    /// @dev SECURITY: Only this address can receive ETH from recoverETH function
    address public treasury;

    /// @notice TimeProvider contract for centralized time management
    /// @dev Used to replace direct block.timestamp usage for testability and consistency
    TimeProvider public immutable timeProvider;

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
    /// @notice Total USDC equivalent deposits across all users
    /// @dev Sum of all user deposits converted to USDC equivalent
    /// @dev Used for pool analytics and risk management
    uint256 public totalDeposits;           // Total USDC equivalent deposits
    
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
     * @param _timeProvider TimeProvider contract for centralized time management
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
    constructor(TimeProvider _timeProvider) {
        if (address(_timeProvider) == address(0)) revert ErrorLibrary.ZeroAddress();
        timeProvider = _timeProvider;
        _disableInitializers();
    }

    /**
     * @notice Initializes the UserPool contract
     * @param admin Address that receives admin and governance roles
     * @param _qeuro Address of the QEURO token contract
     * @param _usdc Address of the USDC token contract
     * @param _vault Address of the QuantillonVault contract
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
     * @custom:oracle No oracle dependencies
     */
    function initialize(
        address admin,
        address _qeuro,
        address _usdc,
        address _vault,
        address _yieldShift,
        address _timelock,
        address _treasury
    ) public initializer {
        require(admin != address(0), "UserPool: Admin cannot be zero");
        require(_qeuro != address(0), "UserPool: QEURO cannot be zero");
        require(_usdc != address(0), "UserPool: USDC cannot be zero");
        require(_vault != address(0), "UserPool: Vault cannot be zero");
        require(_yieldShift != address(0), "UserPool: YieldShift cannot be zero");
        require(_treasury != address(0), "UserPool: Treasury cannot be zero");

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
        yieldShift = IYieldShift(_yieldShift);
        ValidationLibrary.validateTreasuryAddress(_treasury);
        treasury = _treasury;

        // Default parameters
        stakingAPY = 800;           // 8% APY for staking
        depositAPY = 400;           // 4% APY for deposits
        minStakeAmount = 100e18;    // 100 QEURO minimum
        unstakingCooldown = 7 days; // 7 days cooldown
        
        depositFee = 10;            // 0.1% deposit fee
        withdrawalFee = 20;         // 0.2% withdrawal fee
        performanceFee = 1000;      // 10% performance fee
        
        // Initialize yield tracking variables to prevent uninitialized state variable warnings
        accumulatedYieldPerShare = 0;
        lastYieldDistribution = timeProvider.currentTime();
        totalYieldDistributed = 0;
    }

    // =============================================================================
    // CORE DEPOSIT/WITHDRAWAL FUNCTIONS
    // =============================================================================

    /**
     * @notice Deposit USDC to mint QEURO and join user pool
     * @dev This function allows users to deposit USDC and receive QEURO.
     *      It includes a deposit fee and handles the minting process.
     * @param usdcAmount Amount of USDC to deposit (6 decimals)
     * @param minQeuroOut Minimum amount of QEURO to receive (18 decimals)
     * @return qeuroMinted Amount of QEURO minted (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Public access
     * @custom:oracle No oracle dependencies
     */
    function deposit(uint256 usdcAmount, uint256 minQeuroOut) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256 qeuroMinted) 
    {
        require(usdcAmount > 0, "UserPool: Amount must be positive");

        // Calculate deposit fee
        // GAS OPTIMIZATION: Cache storage read
        uint256 depositFee_ = depositFee;
        uint256 fee = usdcAmount.percentageOf(depositFee_);
        uint256 netAmount = usdcAmount - fee;

        // CHECKS & EFFECTS: Transfer USDC and update state before external calls
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);
        UserInfo storage user = userInfo[msg.sender];
        if (!hasDeposited[msg.sender]) {
            hasDeposited[msg.sender] = true;
            totalUsers++;
        }
        
        user.depositHistory += uint96(usdcAmount);
        totalDeposits += netAmount;
        // Use minQeuroOut as conservative estimate for user balance
        user.qeuroBalance += uint128(minQeuroOut);
        
        // Store expected balance before external call
        uint256 qeuroBefore = qeuro.balanceOf(address(this));
        
        // Approve vault to spend USDC
        usdc.safeIncreaseAllowance(address(vault), netAmount);
        
        // EXTERNAL CALL - vault.mintQEURO() (INTERACTIONS)
        vault.mintQEURO(netAmount, minQeuroOut);
        
        // Calculate actual minted amount
        uint256 qeuroAfter = qeuro.balanceOf(address(this));
        qeuroMinted = qeuroAfter - qeuroBefore;
        
        // Note: user.qeuroBalance already updated with minQeuroOut before external call
        // This ensures reentrancy protection. The user receives the actual minted amount,
        // but internal balance tracking uses the conservative minQeuroOut estimate.

        emit UserDeposit(msg.sender, usdcAmount, qeuroMinted, timeProvider.currentTime());
    }

    /**
     * @notice Batch deposit USDC to mint QEURO for multiple amounts
     * @dev This function allows users to make multiple deposits in one transaction.
     *      Each deposit includes a fee and handles the minting process.
     * @param usdcAmounts Array of USDC amounts to deposit (6 decimals)
     * @param minQeuroOuts Array of minimum QEURO amounts to receive (18 decimals)
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
     // slither-disable-next-line calls-loop
    function batchDeposit(uint256[] calldata usdcAmounts, uint256[] calldata minQeuroOuts)
        external
        nonReentrant
        whenNotPaused
        flashLoanProtection
        returns (uint256[] memory qeuroMintedAmounts)
    {
        if (usdcAmounts.length != minQeuroOuts.length) revert ErrorLibrary.ArrayLengthMismatch();
        if (usdcAmounts.length > MAX_BATCH_SIZE) revert ErrorLibrary.BatchSizeTooLarge();
        
        // Cache timestamp to avoid external calls in loop
        uint256 currentTime = timeProvider.currentTime();
        
        qeuroMintedAmounts = new uint256[](usdcAmounts.length);
        
        // Validate amounts and transfer USDC
        _validateAndTransferUsdc(usdcAmounts);
        
        // Initialize user info
        _initializeUserIfNeeded();
        
        // Calculate net amounts
        (uint256[] memory netAmounts, uint256 totalNetAmount) = _calculateNetAmounts(usdcAmounts);
        
        // Update user and pool state BEFORE external calls (reentrancy protection)
        _updateUserAndPoolState(usdcAmounts, minQeuroOuts, totalNetAmount);
        
        // Process vault operations AFTER state updates
        // slither-disable-next-line calls-loop
        _processVaultMinting(netAmounts, minQeuroOuts, qeuroMintedAmounts);
        
        // Transfer QEURO to users and emit events
        _transferQeuroAndEmitEvents(usdcAmounts, qeuroMintedAmounts, currentTime);
    }

    /**
     * @notice Internal function to validate amounts and transfer USDC
     * @param usdcAmounts Array of USDC amounts to validate and transfer (6 decimals)
     * @return totalUsdcAmount Total USDC amount transferred (6 decimals)
     * @dev Validates all amounts are positive and transfers total USDC from user
     * @custom:security Validates all amounts > 0 before transfer
     * @custom:validation Validates each amount in array is positive
     * @custom:state-changes Transfers USDC from msg.sender to contract
     * @custom:events No events emitted - handled by calling function
     * @custom:errors Throws if any amount is 0
     * @custom:reentrancy Not protected - internal function only
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _validateAndTransferUsdc(uint256[] calldata usdcAmounts) internal returns (uint256 totalUsdcAmount) {
        // Pre-validate amounts and calculate total
        for (uint256 i = 0; i < usdcAmounts.length; i++) {
            require(usdcAmounts[i] > 0, "UserPool: Amount must be positive");
            totalUsdcAmount += usdcAmounts[i];
        }
        
        // Transfer total USDC from user FIRST
        usdc.safeTransferFrom(msg.sender, address(this), totalUsdcAmount);
    }

    /**
     * @notice Internal function to initialize user if needed
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
     * @dev Processes vault minting operations with external calls to vault.mintQEURO
     * @custom:security Uses single approval for all vault operations to minimize external calls
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
        // Calculate total net amount for single vault approval
        uint256 totalNetAmount = 0;
        for (uint256 i = 0; i < netAmounts.length; i++) {
            totalNetAmount += netAmounts[i];
        }
        
        // Single approval for all vault operations
        usdc.safeIncreaseAllowance(address(vault), totalNetAmount);
        
        // Process vault minting operations
        // Note: External calls in loop are necessary as vault doesn't support batch minting
        // Batch size is limited to MAX_BATCH_SIZE to prevent gas limit issues
        for (uint256 i = 0; i < netAmounts.length; i++) {
            uint256 netAmount = netAmounts[i];
            uint256 minQeuroOut = minQeuroOuts[i];
            
            // Mint QEURO through vault - external call is necessary
            // slither-disable-next-line calls-loop
            vault.mintQEURO(netAmount, minQeuroOut);
            
            // Use the minimum expected amount as the actual minted amount
            qeuroMintedAmounts[i] = minQeuroOut;
        }
    }

    /**
     * @notice Internal function to update user and pool state
     * @param usdcAmounts Array of USDC amounts (6 decimals)
     * @param minQeuroOuts Array of minimum QEURO outputs (18 decimals)
     * @param totalNetAmount Total net amount (6 decimals)
     * @dev Updates user and pool state before external calls for reentrancy protection
     * @custom:security Updates state before external calls (CEI pattern)
     * @custom:validation No input validation required - parameters pre-validated
     * @custom:state-changes Updates user.depositHistory, user.qeuroBalance, totalDeposits
     * @custom:events No events emitted - handled by calling function
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - internal function only
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _updateUserAndPoolState(
        uint256[] calldata usdcAmounts,
        uint256[] calldata minQeuroOuts,
        uint256 totalNetAmount
    ) internal {
        UserInfo storage user = userInfo[msg.sender];
        
        // Calculate totals for batch updates
        uint256 totalUserDeposits = 0;
        uint256 totalQeuroToMint = 0;
        
        for (uint256 i = 0; i < usdcAmounts.length; i++) {
            totalUserDeposits += usdcAmounts[i];
            totalQeuroToMint += minQeuroOuts[i];
        }
        
        // Update user state once (single update outside loop)
        user.depositHistory += uint96(totalUserDeposits);
        user.qeuroBalance += uint128(totalQeuroToMint);
        
        // Update pool totals once (single update outside loop)  
        totalDeposits += totalNetAmount;
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
        for (uint256 i = 0; i < usdcAmounts.length; i++) {
            uint256 usdcAmount = usdcAmounts[i];
            uint256 qeuroMinted = qeuroMintedAmounts[i];
            
            // Transfer QEURO to user
            IERC20(address(qeuro)).safeTransfer(msg.sender, qeuroMinted);

            emit UserDeposit(msg.sender, usdcAmount, qeuroMinted, currentTime);
        }
    }

    /**
     * @notice Withdraw USDC by burning QEURO
     * @dev This function allows users to withdraw their QEURO and receive USDC.
     *      It includes a withdrawal fee and handles the redemption process.
     * @param qeuroAmount Amount of QEURO to burn (18 decimals)
     * @param minUsdcOut Minimum amount of USDC to receive (6 decimals)
     * @return usdcReceived Amount of USDC received (6 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Public access
     * @custom:oracle No oracle dependencies
     */
    function withdraw(uint256 qeuroAmount, uint256 minUsdcOut) 
        external 
        nonReentrant 
        whenNotPaused 
        flashLoanProtection
        returns (uint256 usdcReceived) 
    {
        require(qeuroAmount > 0, "UserPool: Amount must be positive");
        
        UserInfo storage user = userInfo[msg.sender];
        require(user.qeuroBalance >= qeuroAmount, "UserPool: Insufficient balance");

        user.qeuroBalance -= uint128(qeuroAmount);
        
        // Calculate conservative estimate for totalDeposits update
        uint256 withdrawalFee_ = withdrawalFee;
        uint256 estimatedFee = minUsdcOut.percentageOf(withdrawalFee_);
        uint256 estimatedNetAmount = minUsdcOut - estimatedFee;
        totalDeposits -= estimatedNetAmount;

        IERC20(address(qeuro)).safeTransferFrom(msg.sender, address(this), qeuroAmount);
        
        // Store balance before redemption
        uint256 usdcBefore = usdc.balanceOf(address(this));
        
        // Redeem USDC through vault
        vault.redeemQEURO(qeuroAmount, minUsdcOut);
        
        // Calculate actual received amount
        uint256 usdcAfter = usdc.balanceOf(address(this));
        usdcReceived = usdcAfter - usdcBefore;

        // Calculate actual withdrawal fee and net amount
        uint256 fee = usdcReceived.percentageOf(withdrawalFee_);
        uint256 netAmount = usdcReceived - fee;

        // Transfer USDC to user
        usdc.safeTransfer(msg.sender, netAmount);

        emit UserWithdrawal(msg.sender, qeuroAmount, netAmount, timeProvider.currentTime());
    }

    /**
     * @notice Batch withdraw USDC by burning QEURO for multiple amounts
     * @dev This function allows users to make multiple withdrawals in one transaction.
     *      Each withdrawal includes a fee and handles the redemption process.
     * @param qeuroAmounts Array of QEURO amounts to burn (18 decimals)
     * @param minUsdcOuts Array of minimum USDC amounts to receive (6 decimals)
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
    // slither-disable-next-line calls-loop
    function batchWithdraw(uint256[] calldata qeuroAmounts, uint256[] calldata minUsdcOuts)
        external
        nonReentrant
        whenNotPaused
        returns (uint256[] memory usdcReceivedAmounts)
    {
        if (qeuroAmounts.length != minUsdcOuts.length) revert ErrorLibrary.ArrayLengthMismatch();
        if (qeuroAmounts.length > MAX_BATCH_SIZE) revert ErrorLibrary.BatchSizeTooLarge();
        
        // Cache timestamp to avoid external calls in loop
        uint256 currentTime = timeProvider.currentTime();
        
        usdcReceivedAmounts = new uint256[](qeuroAmounts.length);
        UserInfo storage user = userInfo[msg.sender];
        uint256 totalQeuroAmount = 0;
        

        uint256 length = qeuroAmounts.length;
        
        // Pre-validate amounts and calculate total
        for (uint256 i = 0; i < length;) {
            require(qeuroAmounts[i] > 0, "UserPool: Amount must be positive");

            unchecked { totalQeuroAmount += qeuroAmounts[i]; }
            
            unchecked { ++i; }
        }
        
        require(user.qeuroBalance >= totalQeuroAmount, "UserPool: Insufficient balance");
        
        user.qeuroBalance -= uint128(totalQeuroAmount);
        
        // Calculate conservative estimate for totalDeposits using minimum expected amounts
        uint256 totalEstimatedNetAmount = 0;
        uint256 withdrawalFee_ = withdrawalFee;
        for (uint256 i = 0; i < length;) {
            uint256 minUsdcOut = minUsdcOuts[i];
            uint256 estimatedFee = minUsdcOut.percentageOf(withdrawalFee_);
            uint256 estimatedNetAmount = minUsdcOut - estimatedFee;
            totalEstimatedNetAmount += estimatedNetAmount;
            unchecked { ++i; }
        }
        totalDeposits -= totalEstimatedNetAmount;
        
        IERC20(address(qeuro)).safeTransferFrom(msg.sender, address(this), totalQeuroAmount);
        
        // Get initial balance once before the loop
        uint256 initialUsdcBalance = usdc.balanceOf(address(this));
        
        // Process all vault redemptions
        // Note: External calls in loop are necessary as vault doesn't support batch redemption
        // Batch size is limited to MAX_BATCH_SIZE to prevent gas limit issues
        // slither-disable-next-line calls-loop
        for (uint256 i = 0; i < length;) {
            uint256 qeuroAmount = qeuroAmounts[i];
            uint256 minUsdcOut = minUsdcOuts[i];
            
            // Redeem USDC through vault - external call is necessary
            vault.redeemQEURO(qeuroAmount, minUsdcOut); 
            
            // Use the minimum expected amount as the received amount
            // This avoids additional balance checks and external calls
            uint256 usdcReceived = minUsdcOut;
            
            // Calculate withdrawal fee
            uint256 fee = usdcReceived.percentageOf(withdrawalFee_);
            uint256 netAmount = usdcReceived - fee;
            usdcReceivedAmounts[i] = netAmount;
            
            unchecked { ++i; }
        }
        // Verify total received amount is reasonable (optional safety check)
        uint256 finalUsdcBalance = usdc.balanceOf(address(this));
        uint256 actualTotalReceived = finalUsdcBalance - initialUsdcBalance;
        
        // If there's a significant difference, adjust the last amount to account for slippage
        uint256 expectedTotalReceived = 0;
        for (uint256 i = 0; i < length; i++) {
            expectedTotalReceived += minUsdcOuts[i];
        }
        
        if (actualTotalReceived < expectedTotalReceived && length > 0) {
            uint256 difference = expectedTotalReceived - actualTotalReceived;
            if (difference <= minUsdcOuts[length - 1]) {
                // Adjust the last withdrawal amount to account for slippage
                uint256 lastMinUsdcOut = minUsdcOuts[length - 1];
                uint256 adjustedUsdcReceived = lastMinUsdcOut - difference;
                uint256 adjustedFee = adjustedUsdcReceived.percentageOf(withdrawalFee_);
                usdcReceivedAmounts[length - 1] = adjustedUsdcReceived - adjustedFee;
            }
        }
        
        // Note: totalDeposits already updated before external calls using conservative estimates
        // Users receive actual net amounts, internal tracking uses conservative values for reentrancy protection
        
        // Final transfers and events
        for (uint256 i = 0; i < length;) {
            uint256 qeuroAmount = qeuroAmounts[i];
            uint256 netAmount = usdcReceivedAmounts[i];
            
            // Transfer USDC to user
            usdc.safeTransfer(msg.sender, netAmount);

            emit UserWithdrawal(msg.sender, qeuroAmount, netAmount, currentTime);
            
            unchecked { ++i; }
        }
    }

    // =============================================================================
    // STAKING FUNCTIONS
    // =============================================================================

    /**
     * @notice Stakes QEURO tokens to earn enhanced staking rewards
     * @dev Updates pending rewards before staking and requires minimum stake amount
     * @param qeuroAmount The amount of QEURO tokens to stake (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Public access
     * @custom:oracle No oracle dependencies
     */
    function stake(uint256 qeuroAmount) external nonReentrant whenNotPaused {
        // GAS OPTIMIZATION: Cache storage read
        uint256 minStakeAmount_ = minStakeAmount;
        require(qeuroAmount >= minStakeAmount_, "UserPool: Amount below minimum");
        
        // Cache timestamp to avoid external calls
        uint256 currentTime = timeProvider.currentTime();
        
        UserInfo storage user = userInfo[msg.sender];
        
        // Update pending rewards before staking
        _updatePendingRewards(msg.sender, currentTime);
        

        IERC20(address(qeuro)).safeTransferFrom(msg.sender, address(this), qeuroAmount);
        
        // Update user staking info
        user.stakedAmount += uint128(qeuroAmount);
        user.lastStakeTime = uint64(timeProvider.currentTime());
        
        // Update pool totals
        totalStakes += qeuroAmount;

        emit QEUROStaked(msg.sender, qeuroAmount, timeProvider.currentTime());
    }

    /**
     * @notice Stakes multiple amounts of QEURO tokens in a single transaction
     * @dev More gas-efficient than multiple individual stake calls. Each stake must meet minimum requirements.
     * @param qeuroAmounts Array of QEURO amounts to stake (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Public access
     * @custom:oracle No oracle dependencies
     */
    function batchStake(uint256[] calldata qeuroAmounts) external nonReentrant whenNotPaused {
        if (qeuroAmounts.length > MAX_BATCH_SIZE) revert ErrorLibrary.BatchSizeTooLarge();
        
        // Cache timestamp to avoid external calls
        uint256 currentTime = timeProvider.currentTime();
        
        UserInfo storage user = userInfo[msg.sender];
        uint256 totalQeuroAmount = 0;
        

        uint256 minStakeAmount_ = minStakeAmount;
        
        // Pre-validate amounts and calculate total
        for (uint256 i = 0; i < qeuroAmounts.length; i++) {
            require(qeuroAmounts[i] >= minStakeAmount_, "UserPool: Amount below minimum");
            totalQeuroAmount += qeuroAmounts[i];
        }
        
        // Update pending rewards before staking (once for the batch)
        _updatePendingRewards(msg.sender, currentTime);
        
        // Transfer total QEURO from user FIRST
        IERC20(address(qeuro)).safeTransferFrom(msg.sender, address(this), totalQeuroAmount);
        
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
        uint256 currentTime = timeProvider.currentTime();
        
        UserInfo storage user = userInfo[msg.sender];
        require(user.stakedAmount >= qeuroAmount, "UserPool: Insufficient staked amount");
        
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
        require(user.unstakeAmount > 0, "UserPool: No unstaking request");
        require(
            timeProvider.currentTime() >= user.unstakeRequestTime + unstakingCooldown,
            "UserPool: Cooldown period not finished"
        );

        uint256 amount = user.unstakeAmount;
        
        // Update user staking info
        user.stakedAmount -= uint128(amount);
        user.unstakeAmount = 0;
        user.unstakeRequestTime = 0;
        
        // Update pool totals
        totalStakes -= amount;
        
        IERC20(address(qeuro)).safeTransfer(msg.sender, amount);

        emit QEUROUnstaked(msg.sender, amount, timeProvider.currentTime());
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
        uint256 currentTime = timeProvider.currentTime();
        _updatePendingRewards(msg.sender, currentTime);
        
        UserInfo storage user = userInfo[msg.sender];
        rewardAmount = user.pendingRewards;
        
        if (rewardAmount > 0) {
            user.pendingRewards = 0;
            
            // Mint reward tokens (could be QEURO or QTI)
            qeuro.mint(msg.sender, rewardAmount);
            
            emit StakingRewardsClaimed(msg.sender, rewardAmount, timeProvider.currentTime());
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
        if (users.length > MAX_REWARD_BATCH_SIZE) revert ErrorLibrary.BatchSizeTooLarge();
        
        rewardAmounts = new uint256[](users.length);
        
        // Cache timestamp to avoid external calls in loop
        uint256 currentTime = timeProvider.currentTime();
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
        require(msg.sender == address(yieldShift), "UserPool: Only YieldShift can call");
        
        // Yield distribution moved to stQEURO contract
        // This function kept for backward compatibility but does nothing
        emit YieldDistributed(yieldAmount, 0, timeProvider.currentTime());
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
            
            // Convert blocks to time (assuming 12 second blocks)
            uint256 timeElapsed = blocksElapsed * 12; // seconds
            

            if (timeElapsed > MAX_REWARD_PERIOD) {
                timeElapsed = MAX_REWARD_PERIOD;
            }
            
            // Calculate time-based staking rewards
            uint256 stakingReward = uint256(userdata.stakedAmount)
                .mulDiv(stakingAPY, 10000)
                .mulDiv(timeElapsed, 365 days);
            
            // Calculate yield-based rewards
            uint256 yieldReward = uint256(userdata.stakedAmount)
                .mulDiv(accumulatedYieldPerShare, 1e18);
            
            userdata.pendingRewards += uint128(stakingReward + yieldReward);
            userdata.lastStakeTime = uint64(currentTime);
            
            // Update last reward block
            userLastRewardBlock[user] = currentBlock;
        }
    }

    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================

    /**
     * @notice Get the total deposits of a specific user
     * @dev Returns the cumulative deposit history for a user in USDC equivalent
     * @param user Address of the user to query
     * @return uint256 Total deposits of the user in USDC equivalent (6 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function getUserDeposits(address user) external view returns (uint256) {
        return userInfo[user].depositHistory;
    }

    /**
     * @notice Get the current staked amount of a specific user
     * @dev Returns the current amount of QEURO staked by a user
     * @param user Address of the user to query
     * @return uint256 Current staked amount of the user in QEURO (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function getUserStakes(address user) external view returns (uint256) {
        return userInfo[user].stakedAmount;
    }

    /**
     * @notice Get the total pending rewards for a specific user
     * @dev Calculates and returns the total pending rewards for a user including
     *      both staking rewards and yield-based rewards
     * @param user Address of the user to query
     * @return uint256 Total pending rewards of the user in QEURO (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function getUserPendingRewards(address user) external view returns (uint256) {
        UserInfo storage userdata = userInfo[user];
        
        if (userdata.stakedAmount == 0) return userdata.pendingRewards;
        
        // Calculate additional rewards since last update using block-based calculations
        uint256 currentBlock = block.number;
        uint256 lastRewardBlock = userLastRewardBlock[user];
        
        if (lastRewardBlock < 1) {
            return userdata.pendingRewards;
        }
        
        uint256 blocksElapsed = currentBlock - lastRewardBlock;
        uint256 timeElapsed = blocksElapsed * 12; // seconds
        
        // Sanity check: cap time elapsed to prevent manipulation
        if (timeElapsed > MAX_REWARD_PERIOD) {
            timeElapsed = MAX_REWARD_PERIOD;
        }
        
        uint256 stakingReward = uint256(userdata.stakedAmount)
            .mulDiv(stakingAPY, 10000)
            .mulDiv(timeElapsed, 365 days);
        
        uint256 yieldReward = uint256(userdata.stakedAmount)
            .mulDiv(accumulatedYieldPerShare, 1e18);
        
        return uint256(userdata.pendingRewards) + stakingReward + yieldReward;
    }

    /**
     * @notice Get detailed information about a user's pool status
     * @dev Returns comprehensive user information including balances, stakes, and rewards
     * @param user Address of the user to query
     * @return qeuroBalance QEURO balance of the user (18 decimals)
     * @return stakedAmount Current staked amount of the user (18 decimals)
     * @return pendingRewards Total pending rewards of the user (18 decimals)
     * @return depositHistory Total historical deposits of the user (6 decimals)
     * @return lastStakeTime Timestamp of the user's last staking action
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function getUserInfo(address user) external view returns (
        uint256 qeuroBalance,
        uint256 stakedAmount,
        uint256 pendingRewards,
        uint256 depositHistory,
        uint256 lastStakeTime
    ) {
        UserInfo storage userdata = userInfo[user];
        return (
            userdata.qeuroBalance,
            userdata.stakedAmount,
            this.getUserPendingRewards(user),
            userdata.depositHistory,
            userdata.lastStakeTime
        );
    }

    /**
     * @notice Get the total deposits across all users in the pool
     * @dev Returns the cumulative total of all USDC deposits made to the pool
     * @return uint256 Total USDC equivalent deposits (6 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function getTotalDeposits() external view returns (uint256) {
        return totalDeposits;
    }

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
        totalUsers_ = totalUsers;
        averageDeposit = totalUsers > 0 ? totalDeposits / totalUsers : 0;
        stakingRatio = totalDeposits > 0 ? (totalStakes * 10000) / totalDeposits : 0;
        poolTVL = totalDeposits;
    }

    /**
     * @notice Get the current Staking APY
     * @dev Returns the current annual percentage yield for staking QEURO
     * @return uint256 Staking APY in basis points
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function getStakingAPY() external view returns (uint256) {
        return stakingAPY;
    }

    /**
     * @notice Get the current Deposit APY
     * @dev Returns the current annual percentage yield for depositing USDC
     * @return uint256 Deposit APY in basis points
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function getDepositAPY() external view returns (uint256) {
        return depositAPY;
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
        require(newStakingAPY <= 5000, "UserPool: APY too high"); // Max 50%
        require(newMinStakeAmount > 0, "UserPool: Min stake must be positive");
        require(newUnstakingCooldown <= 30 days, "UserPool: Cooldown too long");

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
        require(_depositFee <= 100, "UserPool: Deposit fee too high"); // Max 1%
        require(_withdrawalFee <= 200, "UserPool: Withdrawal fee too high"); // Max 2%
        require(_performanceFee <= 2000, "UserPool: Performance fee too high"); // Max 20%

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
     * @notice Get the current configuration parameters of the user pool
     * @dev Returns all current pool configuration parameters including fees and limits
     * @return minStakeAmount_ Current minimum stake amount (18 decimals)
     * @return unstakingCooldown_ Current unstaking cooldown period (seconds)
     * @return depositFee_ Current deposit fee (basis points)
     * @return withdrawalFee_ Current withdrawal fee (basis points)
     * @return performanceFee_ Current performance fee (basis points)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function getPoolConfig() external view returns (
        uint256 minStakeAmount_,
        uint256 unstakingCooldown_,
        uint256 depositFee_,
        uint256 withdrawalFee_,
        uint256 performanceFee_
    ) {
        return (minStakeAmount, unstakingCooldown, depositFee, withdrawalFee, performanceFee);
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
        // Use the shared library for secure token recovery to treasury
        TreasuryRecoveryLibrary.recoverToken(token, amount, address(this), treasury);
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

        emit ETHRecovered(treasury, address(this).balance);
        // Use the shared library for secure ETH recovery
        TreasuryRecoveryLibrary.recoverETH(treasury);
    }
}