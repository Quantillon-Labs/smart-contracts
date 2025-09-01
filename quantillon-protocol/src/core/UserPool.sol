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
import "./SecureUpgradeable.sol";

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
 * 
 * @dev Integration points:
 *      - QEURO token for minting and burning
 *      - USDC for deposits and withdrawals
 *      - QuantillonVault for QEURO minting/burning
 *      - Yield shift mechanism for yield management
 *      - Vault math library for calculations
 * 
 * @author Quantillon Labs
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
        // Total: 16+16+16+16+12+8+8 = 92 bytes (3 slots vs 7 slots = 57% gas savings)
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
    /// @dev Indexed parameters allow efficient filtering of events
    event YieldDistributed(uint256 totalYield, uint256 yieldPerShare, uint256 timestamp);

    /// @notice Emitted when pool parameters are updated
    /// @param parameter Name of the parameter updated
    /// @param oldValue Original value of the parameter
    /// @param newValue New value of the parameter
    /// @dev Indexed parameters allow efficient filtering of events
    event PoolParameterUpdated(string parameter, uint256 oldValue, uint256 newValue);

    // =============================================================================
    // INITIALIZER
    // =============================================================================

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin,
        address _qeuro,
        address _usdc,
        address _vault,
        address _yieldShift,
        address timelock
    ) public initializer {
        require(admin != address(0), "UserPool: Admin cannot be zero");
        require(_qeuro != address(0), "UserPool: QEURO cannot be zero");
        require(_usdc != address(0), "UserPool: USDC cannot be zero");
        require(_vault != address(0), "UserPool: Vault cannot be zero");
        require(_yieldShift != address(0), "UserPool: YieldShift cannot be zero");

        __ReentrancyGuard_init();
        __AccessControl_init();
        __Pausable_init();
        __SecureUpgradeable_init(timelock);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);

        qeuro = IQEUROToken(_qeuro);
        usdc = IERC20(_usdc);
        vault = IQuantillonVault(_vault);
        yieldShift = IYieldShift(_yieldShift);

        // Default parameters
        stakingAPY = 800;           // 8% APY for staking
        depositAPY = 400;           // 4% APY for deposits
        minStakeAmount = 100e18;    // 100 QEURO minimum
        unstakingCooldown = 7 days; // 7 days cooldown
        
        depositFee = 10;            // 0.1% deposit fee
        withdrawalFee = 20;         // 0.2% withdrawal fee
        performanceFee = 1000;      // 10% performance fee
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
     */
    function deposit(uint256 usdcAmount, uint256 minQeuroOut) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256 qeuroMinted) 
    {
        require(usdcAmount > 0, "UserPool: Amount must be positive");

        // Calculate deposit fee
        uint256 fee = usdcAmount.percentageOf(depositFee);
        uint256 netAmount = usdcAmount - fee;

        // Transfer USDC from user FIRST
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);
        
        // Update state BEFORE external calls
        UserInfo storage user = userInfo[msg.sender];
        if (!hasDeposited[msg.sender]) {
            hasDeposited[msg.sender] = true;
            totalUsers++;
        }
        
        // Store expected balance before external call
        uint256 qeuroBefore = qeuro.balanceOf(address(this));
        
        // Approve vault to spend USDC
        usdc.safeIncreaseAllowance(address(vault), netAmount);
        
        // Mint QEURO through vault
        vault.mintQEURO(netAmount, minQeuroOut);
        
        // Calculate actual minted amount
        uint256 qeuroAfter = qeuro.balanceOf(address(this));
        qeuroMinted = qeuroAfter - qeuroBefore;
        
        // Update user balance and pool totals
        user.qeuroBalance += uint128(qeuroMinted);
        user.depositHistory += uint96(usdcAmount);
        totalDeposits += netAmount;

        // Transfer QEURO to user as final step
        IERC20(address(qeuro)).safeTransfer(msg.sender, qeuroMinted);

        emit UserDeposit(msg.sender, usdcAmount, qeuroMinted, block.timestamp);
    }

    /**
     * @notice Batch deposit USDC to mint QEURO for multiple amounts
     * @dev This function allows users to make multiple deposits in one transaction.
     *      Each deposit includes a fee and handles the minting process.
     * @param usdcAmounts Array of USDC amounts to deposit (6 decimals)
     * @param minQeuroOuts Array of minimum QEURO amounts to receive (18 decimals)
     * @return qeuroMintedAmounts Array of QEURO amounts minted (18 decimals)
     */
    function batchDeposit(uint256[] calldata usdcAmounts, uint256[] calldata minQeuroOuts)
        external
        nonReentrant
        whenNotPaused
        returns (uint256[] memory qeuroMintedAmounts)
    {
        if (usdcAmounts.length != minQeuroOuts.length) revert ErrorLibrary.ArrayLengthMismatch();
        
        qeuroMintedAmounts = new uint256[](usdcAmounts.length);
        uint256 totalUsdcAmount = 0;
        
        // Pre-validate amounts and calculate total
        for (uint256 i = 0; i < usdcAmounts.length; i++) {
            require(usdcAmounts[i] > 0, "UserPool: Amount must be positive");
            totalUsdcAmount += usdcAmounts[i];
        }
        
        // Transfer total USDC from user FIRST
        usdc.safeTransferFrom(msg.sender, address(this), totalUsdcAmount);
        
        // Update state BEFORE external calls
        UserInfo storage user = userInfo[msg.sender];
        if (!hasDeposited[msg.sender]) {
            hasDeposited[msg.sender] = true;
            totalUsers++;
        }
        
        // Process each deposit
        for (uint256 i = 0; i < usdcAmounts.length; i++) {
            uint256 usdcAmount = usdcAmounts[i];
            uint256 minQeuroOut = minQeuroOuts[i];
            
            // Calculate deposit fee
            uint256 fee = usdcAmount.percentageOf(depositFee);
            uint256 netAmount = usdcAmount - fee;
            
            // Store expected balance before external call
            uint256 qeuroBefore = qeuro.balanceOf(address(this));
            
            // Approve vault to spend USDC
            usdc.safeIncreaseAllowance(address(vault), netAmount);
            
            // Mint QEURO through vault
            vault.mintQEURO(netAmount, minQeuroOut);
            
            // Calculate actual minted amount
            uint256 qeuroAfter = qeuro.balanceOf(address(this));
            uint256 qeuroMinted = qeuroAfter - qeuroBefore;
            qeuroMintedAmounts[i] = qeuroMinted;
            
            // Update user balance and pool totals
            user.qeuroBalance += uint128(qeuroMinted);
            user.depositHistory += uint96(usdcAmount);
            totalDeposits += netAmount;

            // Transfer QEURO to user
            IERC20(address(qeuro)).safeTransfer(msg.sender, qeuroMinted);

            emit UserDeposit(msg.sender, usdcAmount, qeuroMinted, block.timestamp);
        }
    }

    /**
     * @notice Withdraw USDC by burning QEURO
     * @dev This function allows users to withdraw their QEURO and receive USDC.
     *      It includes a withdrawal fee and handles the redemption process.
     * @param qeuroAmount Amount of QEURO to burn (18 decimals)
     * @param minUsdcOut Minimum amount of USDC to receive (6 decimals)
     * @return usdcReceived Amount of USDC received (6 decimals)
     */
    function withdraw(uint256 qeuroAmount, uint256 minUsdcOut) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256 usdcReceived) 
    {
        require(qeuroAmount > 0, "UserPool: Amount must be positive");
        
        UserInfo storage user = userInfo[msg.sender];
        require(user.qeuroBalance >= qeuroAmount, "UserPool: Insufficient balance");

        // SECURITY FIX: Use safeTransferFrom for reliable QEURO transfers
        IERC20(address(qeuro)).safeTransferFrom(msg.sender, address(this), qeuroAmount);
        
        // Redeem USDC through vault
        vault.redeemQEURO(qeuroAmount, minUsdcOut);
        usdcReceived = usdc.balanceOf(address(this));

        // Calculate withdrawal fee
        uint256 fee = usdcReceived.percentageOf(withdrawalFee);
        uint256 netAmount = usdcReceived - fee;

        // Update user info
        user.qeuroBalance -= uint128(qeuroAmount);
        
        // Update pool totals
        totalDeposits -= netAmount;

        // Transfer USDC to user
        usdc.safeTransfer(msg.sender, netAmount);

        emit UserWithdrawal(msg.sender, qeuroAmount, netAmount, block.timestamp);
    }

    /**
     * @notice Batch withdraw USDC by burning QEURO for multiple amounts
     * @dev This function allows users to make multiple withdrawals in one transaction.
     *      Each withdrawal includes a fee and handles the redemption process.
     * @param qeuroAmounts Array of QEURO amounts to burn (18 decimals)
     * @param minUsdcOuts Array of minimum USDC amounts to receive (6 decimals)
     * @return usdcReceivedAmounts Array of USDC amounts received (6 decimals)
     */
    function batchWithdraw(uint256[] calldata qeuroAmounts, uint256[] calldata minUsdcOuts)
        external
        nonReentrant
        whenNotPaused
        returns (uint256[] memory usdcReceivedAmounts)
    {
        if (qeuroAmounts.length != minUsdcOuts.length) revert ErrorLibrary.ArrayLengthMismatch();
        
        usdcReceivedAmounts = new uint256[](qeuroAmounts.length);
        UserInfo storage user = userInfo[msg.sender];
        uint256 totalQeuroAmount = 0;
        
        // Pre-validate amounts and calculate total
        for (uint256 i = 0; i < qeuroAmounts.length; i++) {
            require(qeuroAmounts[i] > 0, "UserPool: Amount must be positive");
            totalQeuroAmount += qeuroAmounts[i];
        }
        
        require(user.qeuroBalance >= totalQeuroAmount, "UserPool: Insufficient balance");
        
        // Transfer total QEURO from user FIRST
        IERC20(address(qeuro)).safeTransferFrom(msg.sender, address(this), totalQeuroAmount);
        
        // Process each withdrawal
        for (uint256 i = 0; i < qeuroAmounts.length; i++) {
            uint256 qeuroAmount = qeuroAmounts[i];
            uint256 minUsdcOut = minUsdcOuts[i];
            
            // Store balance before redemption
            uint256 usdcBefore = usdc.balanceOf(address(this));
            
            // Redeem USDC through vault
            vault.redeemQEURO(qeuroAmount, minUsdcOut);
            
            // Calculate received amount
            uint256 usdcAfter = usdc.balanceOf(address(this));
            uint256 usdcReceived = usdcAfter - usdcBefore;

            // Calculate withdrawal fee
            uint256 fee = usdcReceived.percentageOf(withdrawalFee);
            uint256 netAmount = usdcReceived - fee;
            usdcReceivedAmounts[i] = netAmount;

            // Update user info
            user.qeuroBalance -= uint128(qeuroAmount);
            
            // Update pool totals
            totalDeposits -= netAmount;

            // Transfer USDC to user
            usdc.safeTransfer(msg.sender, netAmount);

            emit UserWithdrawal(msg.sender, qeuroAmount, netAmount, block.timestamp);
        }
    }

    // =============================================================================
    // STAKING FUNCTIONS
    // =============================================================================

    /**
     * @notice Stake QEURO tokens to earn enhanced yield
     * @dev This function allows users to stake their QEURO tokens.
     *      It updates their pending rewards and adds to their staked amount.
     * @param qeuroAmount Amount of QEURO to stake (18 decimals)
     */
    function stake(uint256 qeuroAmount) external nonReentrant whenNotPaused {
        require(qeuroAmount >= minStakeAmount, "UserPool: Amount below minimum");
        
        UserInfo storage user = userInfo[msg.sender];
        
        // Update pending rewards before staking
        _updatePendingRewards(msg.sender);
        
        // SECURITY FIX: Use safeTransferFrom for reliable QEURO transfers
        IERC20(address(qeuro)).safeTransferFrom(msg.sender, address(this), qeuroAmount);
        
        // Update user staking info
        user.stakedAmount += uint128(qeuroAmount);
        user.lastStakeTime = uint64(block.timestamp);
        
        // Update pool totals
        totalStakes += qeuroAmount;

        emit QEUROStaked(msg.sender, qeuroAmount, block.timestamp);
    }

    /**
     * @notice Batch stake QEURO tokens for multiple amounts
     * @dev This function allows users to make multiple stakes in one transaction.
     *      Each stake must meet minimum requirements and updates rewards.
     * @param qeuroAmounts Array of QEURO amounts to stake (18 decimals)
     */
    function batchStake(uint256[] calldata qeuroAmounts) external nonReentrant whenNotPaused {
        UserInfo storage user = userInfo[msg.sender];
        uint256 totalQeuroAmount = 0;
        
        // Pre-validate amounts and calculate total
        for (uint256 i = 0; i < qeuroAmounts.length; i++) {
            require(qeuroAmounts[i] >= minStakeAmount, "UserPool: Amount below minimum");
            totalQeuroAmount += qeuroAmounts[i];
        }
        
        // Update pending rewards before staking (once for the batch)
        _updatePendingRewards(msg.sender);
        
        // Transfer total QEURO from user FIRST
        IERC20(address(qeuro)).safeTransferFrom(msg.sender, address(this), totalQeuroAmount);
        
        // Process each stake
        for (uint256 i = 0; i < qeuroAmounts.length; i++) {
            uint256 qeuroAmount = qeuroAmounts[i];
            
            // Update user staking info
            user.stakedAmount += uint128(qeuroAmount);
            user.lastStakeTime = uint64(block.timestamp);
            
            // Update pool totals
            totalStakes += qeuroAmount;

            emit QEUROStaked(msg.sender, qeuroAmount, block.timestamp);
        }
    }

    /**
     * @notice Request to unstake QEURO tokens (starts cooldown)
     * @dev This function allows users to request to unstake their QEURO.
     *      It sets a cooldown period before they can complete the unstaking.
     * @param qeuroAmount Amount of QEURO to unstake (18 decimals)
     */
    function requestUnstake(uint256 qeuroAmount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.stakedAmount >= qeuroAmount, "UserPool: Insufficient staked amount");
        
        // Update pending rewards
        _updatePendingRewards(msg.sender);
        
        // Set unstaking request
        user.unstakeRequestTime = uint64(block.timestamp);
        user.unstakeAmount = uint128(qeuroAmount);
    }

    /**
     * @notice Complete unstaking after cooldown period
     * @dev This function allows users to complete their unstaking request
     *      after the cooldown period has passed.
     */
    function unstake() external nonReentrant whenNotPaused {
        UserInfo storage user = userInfo[msg.sender];
        require(user.unstakeAmount > 0, "UserPool: No unstaking request");
        require(
            block.timestamp >= user.unstakeRequestTime + unstakingCooldown,
            "UserPool: Cooldown period not finished"
        );

        uint256 amount = user.unstakeAmount;
        
        // Update user staking info
        user.stakedAmount -= uint128(amount);
        user.unstakeAmount = 0;
        user.unstakeRequestTime = 0;
        
        // Update pool totals
        totalStakes -= amount;
        
        // SECURITY FIX: Use safeTransfer for reliable QEURO transfers
        IERC20(address(qeuro)).safeTransfer(msg.sender, amount);

        emit QEUROUnstaked(msg.sender, amount, block.timestamp);
    }

    /**
     * @notice Claim staking rewards
     * @dev This function allows users to claim their pending staking rewards.
     *      It calculates and transfers the rewards based on their staked amount.
     * @return rewardAmount Amount of QEURO rewards claimed (18 decimals)
     */
    function claimStakingRewards() external nonReentrant returns (uint256 rewardAmount) {
        _updatePendingRewards(msg.sender);
        
        UserInfo storage user = userInfo[msg.sender];
        rewardAmount = user.pendingRewards;
        
        if (rewardAmount > 0) {
            user.pendingRewards = 0;
            
            // Mint reward tokens (could be QEURO or QTI)
            qeuro.mint(msg.sender, rewardAmount);
            
            emit StakingRewardsClaimed(msg.sender, rewardAmount, block.timestamp);
        }
    }

    /**
     * @notice Batch claim staking rewards for multiple users (admin function)
     * @dev This function allows admins to claim rewards for multiple users in one transaction.
     *      Useful for protocol-wide reward distributions or automated reward processing.
     * @param users Array of user addresses to claim rewards for
     * @return rewardAmounts Array of reward amounts claimed for each user (18 decimals)
     */
    function batchRewardClaim(address[] calldata users) 
        external 
        nonReentrant 
        onlyRole(GOVERNANCE_ROLE)
        returns (uint256[] memory rewardAmounts) 
    {
        rewardAmounts = new uint256[](users.length);
        
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            _updatePendingRewards(user);
            
            UserInfo storage userInfo_ = userInfo[user];
            uint256 rewardAmount = userInfo_.pendingRewards;
            rewardAmounts[i] = rewardAmount;
            
            if (rewardAmount > 0) {
                userInfo_.pendingRewards = 0;
                
                // Mint reward tokens (could be QEURO or QTI)
                qeuro.mint(user, rewardAmount);
                
                emit StakingRewardsClaimed(user, rewardAmount, block.timestamp);
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
     */
    function distributeYield(uint256 yieldAmount) external {
        require(msg.sender == address(yieldShift), "UserPool: Only YieldShift can call");
        
        // Yield distribution moved to stQEURO contract
        // This function kept for backward compatibility but does nothing
        emit YieldDistributed(yieldAmount, 0, block.timestamp);
    }

    /**
     * @notice Update pending rewards for a user
     * @param user Address of the user to update
     * @dev This internal function calculates and updates the pending rewards
     *      for a given user based on their staked amount and the current APY.
     *      Uses block-based calculations to prevent timestamp manipulation.
     * 

     */
    function _updatePendingRewards(address user) internal {
        UserInfo storage userdata = userInfo[user];
        
        if (userdata.stakedAmount > 0) {
            // SECURITY FIX: Use block numbers instead of timestamps to prevent manipulation
            uint256 currentBlock = block.number;
            uint256 lastRewardBlock = userLastRewardBlock[user];
            
            if (lastRewardBlock == 0) {
                // First time claiming, set initial block
                userLastRewardBlock[user] = currentBlock;
                return;
            }
            
            uint256 blocksElapsed = currentBlock - lastRewardBlock;
            
            // Convert blocks to time (assuming 12 second blocks)
            uint256 timeElapsed = blocksElapsed * 12; // seconds
            
            // SECURITY FIX: Sanity check to cap time elapsed and prevent manipulation
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
            userdata.lastStakeTime = uint64(block.timestamp);
            
            // Update last reward block
            userLastRewardBlock[user] = currentBlock;
        }
    }

    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================

    /**
     * @notice Get the total deposits of a specific user
     * @param user Address of the user to query
     * @return uint256 Total deposits of the user in USDC equivalent (6 decimals)
     */
    function getUserDeposits(address user) external view returns (uint256) {
        return userInfo[user].depositHistory;
    }

    /**
     * @notice Get the current staked amount of a specific user
     * @param user Address of the user to query
     * @return uint256 Current staked amount of the user in QEURO (18 decimals)
     */
    function getUserStakes(address user) external view returns (uint256) {
        return userInfo[user].stakedAmount;
    }

    /**
     * @notice Get the total pending rewards for a specific user
     * @param user Address of the user to query
     * @return uint256 Total pending rewards of the user in QEURO (18 decimals)
     */
    function getUserPendingRewards(address user) external view returns (uint256) {
        UserInfo storage userdata = userInfo[user];
        
        if (userdata.stakedAmount == 0) return userdata.pendingRewards;
        
        // Calculate additional rewards since last update using block-based calculations
        uint256 currentBlock = block.number;
        uint256 lastRewardBlock = userLastRewardBlock[user];
        
        if (lastRewardBlock == 0) {
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
     * @param user Address of the user to query
     * @return qeuroBalance QEURO balance of the user (18 decimals)
     * @return stakedAmount Current staked amount of the user (18 decimals)
     * @return pendingRewards Total pending rewards of the user (18 decimals)
     * @return depositHistory Total historical deposits of the user (6 decimals)
     * @return lastStakeTime Timestamp of the user's last staking action
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
     * @return uint256 Total USDC equivalent deposits (6 decimals)
     */
    function getTotalDeposits() external view returns (uint256) {
        return totalDeposits;
    }

    /**
     * @notice Get the total QEURO staked across all users
     * @return uint256 Total QEURO staked (18 decimals)
     */
    function getTotalStakes() external view returns (uint256) {
        return totalStakes;
    }

    /**
     * @notice Get various metrics about the user pool
     * @return totalUsers_ Number of unique users
     * @return averageDeposit Average deposit amount per user (6 decimals)
     * @return stakingRatio Ratio of total staked QEURO to total deposits (basis points)
     * @return poolTVL Total value locked in the pool (6 decimals)
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
     * @return uint256 Staking APY in basis points
     */
    function getStakingAPY() external view returns (uint256) {
        return stakingAPY;
    }

    /**
     * @notice Get the current Deposit APY
     * @return uint256 Deposit APY in basis points
     */
    function getDepositAPY() external view returns (uint256) {
        return depositAPY;
    }

    /**
     * @notice Calculate projected rewards for a given QEURO amount and duration
     * @param qeuroAmount Amount of QEURO to calculate rewards for (18 decimals)
     * @param duration Duration in seconds
     * @return uint256 Calculated rewards (18 decimals)
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
     */
    function emergencyUnstake(address user) external onlyRole(EMERGENCY_ROLE) {
        UserInfo storage userdata = userInfo[user];
        uint256 amount = userdata.stakedAmount;
        
        if (amount > 0) {
            userdata.stakedAmount = 0;
            totalStakes -= amount;
            // SECURITY FIX: Use safeTransfer for reliable QEURO transfers
            IERC20(address(qeuro)).safeTransfer(user, amount);
        }
    }

    /**
     * @notice Pause the user pool (restricted to emergency roles)
     * @dev This function is used to pause critical operations in case of
     *      a protocol-wide emergency or vulnerability.
     */
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the user pool (restricted to emergency roles)
     * @dev This function is used to re-enable critical operations after
     *      an emergency pause.
     */
    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }

    /**
     * @notice Get the current configuration parameters of the user pool
     * @return minStakeAmount_ Current minimum stake amount (18 decimals)
     * @return unstakingCooldown_ Current unstaking cooldown period (seconds)
     * @return depositFee_ Current deposit fee (basis points)
     * @return withdrawalFee_ Current withdrawal fee (basis points)
     * @return performanceFee_ Current performance fee (basis points)
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
     * @return bool True if the pool is active, false otherwise
     */
    function isPoolActive() external view returns (bool) {
        return !paused();
    }



    // =============================================================================
    // RECOVERY FUNCTIONS
    // =============================================================================

    /**
     * @notice Recover accidentally sent tokens
     * @param token Token address to recover
     * @param to Recipient address
     * @param amount Amount to recover
     */
    function recoverToken(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(qeuro), "UserPool: Cannot recover QEURO");
        require(token != address(usdc), "UserPool: Cannot recover USDC");
        require(to != address(0), "UserPool: Cannot send to zero address");
        
        IERC20(token).safeTransfer(to, amount);
    }

    /**
     * @notice Recover accidentally sent ETH
     * @param to Recipient address
     */
    function recoverETH(address payable to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(to != address(0), "UserPool: Cannot send to zero address");
        uint256 balance = address(this).balance;
        require(balance > 0, "UserPool: No ETH to recover");
        
        // SECURITY FIX: Use call() instead of transfer() for reliable ETH transfers
        (bool success, ) = to.call{value: balance}("");
        require(success, "UserPool: ETH transfer failed");
    }
}