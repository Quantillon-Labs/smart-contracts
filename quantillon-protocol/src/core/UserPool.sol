// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IQEURO.sol";
import "../interfaces/IQuantillonVault.sol";
import "../interfaces/IYieldShift.sol";
import "../libraries/VaultMath.sol";

/**
 * @title UserPool
 * @notice Manages QEURO user deposits, staking, and yield distribution
 * @dev Handles the user side of the dual-pool mechanism
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract UserPool is 
    Initializable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;
    using VaultMath for uint256;

    // =============================================================================
    // CONSTANTS AND ROLES
    // =============================================================================
    
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // =============================================================================
    // STATE VARIABLES
    // =============================================================================
    
    /// @notice QEURO token contract
    IQEURO public qeuro;
    
    /// @notice USDC token contract
    IERC20 public usdc;
    
    /// @notice Main Quantillon vault
    IQuantillonVault public vault;
    
    /// @notice Yield shift mechanism
    IYieldShift public yieldShift;

    // Pool configuration
    uint256 public stakingAPY;              // Staking APY in basis points
    uint256 public depositAPY;              // Base deposit APY in basis points
    uint256 public minStakeAmount;          // Minimum amount for staking
    uint256 public unstakingCooldown;       // Cooldown period for unstaking
    
    // Fee configuration
    uint256 public depositFee;              // Deposit fee in basis points
    uint256 public withdrawalFee;           // Withdrawal fee in basis points
    uint256 public performanceFee;          // Performance fee in basis points

    // Pool state
    uint256 public totalDeposits;           // Total USDC equivalent deposits
    uint256 public totalStakes;             // Total QEURO staked
    uint256 public totalUsers;              // Number of unique users
    
    // User data structures
    struct UserInfo {
        uint256 qeuroBalance;               // QEURO balance (from deposits)
        uint256 stakedAmount;               // QEURO staked amount
        uint256 pendingRewards;             // Pending staking rewards
        uint256 depositHistory;             // Total historical deposits
        uint256 lastStakeTime;              // Last staking timestamp
        uint256 unstakeRequestTime;         // Unstaking request timestamp
        uint256 unstakeAmount;              // Amount being unstaked
    }
    
    mapping(address => UserInfo) public userInfo;
    mapping(address => bool) public hasDeposited;

    // Yield tracking
    uint256 public accumulatedYieldPerShare;    // Accumulated yield per staked QEURO
    uint256 public lastYieldDistribution;       // Last yield distribution timestamp
    uint256 public totalYieldDistributed;       // Total yield distributed to users

    // =============================================================================
    // EVENTS
    // =============================================================================
    
    event UserDeposit(address indexed user, uint256 usdcAmount, uint256 qeuroMinted, uint256 timestamp);
    event UserWithdrawal(address indexed user, uint256 qeuroBurned, uint256 usdcReceived, uint256 timestamp);
    event QEUROStaked(address indexed user, uint256 qeuroAmount, uint256 timestamp);
    event QEUROUnstaked(address indexed user, uint256 qeuroAmount, uint256 timestamp);
    event StakingRewardsClaimed(address indexed user, uint256 rewardAmount, uint256 timestamp);
    event YieldDistributed(uint256 totalYield, uint256 yieldPerShare, uint256 timestamp);
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
        address _yieldShift
    ) public initializer {
        require(admin != address(0), "UserPool: Admin cannot be zero");
        require(_qeuro != address(0), "UserPool: QEURO cannot be zero");
        require(_usdc != address(0), "UserPool: USDC cannot be zero");
        require(_vault != address(0), "UserPool: Vault cannot be zero");
        require(_yieldShift != address(0), "UserPool: YieldShift cannot be zero");

        __ReentrancyGuard_init();
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        qeuro = IQEURO(_qeuro);
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

        // Transfer USDC from user
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);
        
        // Approve vault to spend USDC
        usdc.safeApprove(address(vault), netAmount);
        
        // Mint QEURO through vault
        vault.mintQEURO(netAmount, minQeuroOut);
        qeuroMinted = qeuro.balanceOf(address(this));

        // Update user info
        UserInfo storage user = userInfo[msg.sender];
        if (!hasDeposited[msg.sender]) {
            hasDeposited[msg.sender] = true;
            totalUsers++;
        }
        
        user.qeuroBalance += qeuroMinted;
        user.depositHistory += usdcAmount;
        
        // Update pool totals
        totalDeposits += netAmount;

        // Transfer QEURO to user
        qeuro.transfer(msg.sender, qeuroMinted);

        emit UserDeposit(msg.sender, usdcAmount, qeuroMinted, block.timestamp);
    }

    /**
     * @notice Withdraw USDC by burning QEURO
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

        // Transfer QEURO from user to redeem
        qeuro.transferFrom(msg.sender, address(this), qeuroAmount);
        
        // Redeem USDC through vault
        vault.redeemQEURO(qeuroAmount, minUsdcOut);
        usdcReceived = usdc.balanceOf(address(this));

        // Calculate withdrawal fee
        uint256 fee = usdcReceived.percentageOf(withdrawalFee);
        uint256 netAmount = usdcReceived - fee;

        // Update user info
        user.qeuroBalance -= qeuroAmount;
        
        // Update pool totals
        totalDeposits -= netAmount;

        // Transfer USDC to user
        usdc.safeTransfer(msg.sender, netAmount);

        emit UserWithdrawal(msg.sender, qeuroAmount, netAmount, block.timestamp);
    }

    // =============================================================================
    // STAKING FUNCTIONS
    // =============================================================================

    /**
     * @notice Stake QEURO tokens to earn enhanced yield
     */
    function stake(uint256 qeuroAmount) external nonReentrant whenNotPaused {
        require(qeuroAmount >= minStakeAmount, "UserPool: Amount below minimum");
        
        UserInfo storage user = userInfo[msg.sender];
        
        // Update pending rewards before staking
        _updatePendingRewards(msg.sender);
        
        // Transfer QEURO from user
        qeuro.transferFrom(msg.sender, address(this), qeuroAmount);
        
        // Update user staking info
        user.stakedAmount += qeuroAmount;
        user.lastStakeTime = block.timestamp;
        
        // Update pool totals
        totalStakes += qeuroAmount;

        emit QEUROStaked(msg.sender, qeuroAmount, block.timestamp);
    }

    /**
     * @notice Request to unstake QEURO tokens (starts cooldown)
     */
    function requestUnstake(uint256 qeuroAmount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.stakedAmount >= qeuroAmount, "UserPool: Insufficient staked amount");
        
        // Update pending rewards
        _updatePendingRewards(msg.sender);
        
        // Set unstaking request
        user.unstakeRequestTime = block.timestamp;
        user.unstakeAmount = qeuroAmount;
    }

    /**
     * @notice Complete unstaking after cooldown period
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
        user.stakedAmount -= amount;
        user.unstakeAmount = 0;
        user.unstakeRequestTime = 0;
        
        // Update pool totals
        totalStakes -= amount;
        
        // Transfer QEURO back to user
        qeuro.transfer(msg.sender, amount);

        emit QEUROUnstaked(msg.sender, amount, block.timestamp);
    }

    /**
     * @notice Claim staking rewards
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

    // =============================================================================
    // YIELD DISTRIBUTION
    // =============================================================================

    /**
     * @notice Distribute yield to stakers (called by YieldShift contract)
     */
    function distributeYield(uint256 yieldAmount) external {
        require(msg.sender == address(yieldShift), "UserPool: Only YieldShift can call");
        
        if (totalStakes > 0 && yieldAmount > 0) {
            uint256 yieldPerShare = yieldAmount.mulDiv(1e18, totalStakes);
            accumulatedYieldPerShare += yieldPerShare;
            totalYieldDistributed += yieldAmount;
            lastYieldDistribution = block.timestamp;
            
            emit YieldDistributed(yieldAmount, yieldPerShare, block.timestamp);
        }
    }

    /**
     * @notice Update pending rewards for a user
     */
    function _updatePendingRewards(address user) internal {
        UserInfo storage userdata = userInfo[user];
        
        if (userdata.stakedAmount > 0) {
            // Calculate time-based staking rewards
            uint256 timeElapsed = block.timestamp - userdata.lastStakeTime;
            uint256 stakingReward = userdata.stakedAmount
                .mulDiv(stakingAPY, 10000)
                .mulDiv(timeElapsed, 365 days);
            
            // Calculate yield-based rewards
            uint256 yieldReward = userdata.stakedAmount
                .mulDiv(accumulatedYieldPerShare, 1e18);
            
            userdata.pendingRewards += stakingReward + yieldReward;
            userdata.lastStakeTime = block.timestamp;
        }
    }

    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================

    function getUserDeposits(address user) external view returns (uint256) {
        return userInfo[user].depositHistory;
    }

    function getUserStakes(address user) external view returns (uint256) {
        return userInfo[user].stakedAmount;
    }

    function getUserPendingRewards(address user) external view returns (uint256) {
        UserInfo storage userdata = userInfo[user];
        
        if (userdata.stakedAmount == 0) return userdata.pendingRewards;
        
        // Calculate additional rewards since last update
        uint256 timeElapsed = block.timestamp - userdata.lastStakeTime;
        uint256 stakingReward = userdata.stakedAmount
            .mulDiv(stakingAPY, 10000)
            .mulDiv(timeElapsed, 365 days);
        
        uint256 yieldReward = userdata.stakedAmount
            .mulDiv(accumulatedYieldPerShare, 1e18);
        
        return userdata.pendingRewards + stakingReward + yieldReward;
    }

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

    function getTotalDeposits() external view returns (uint256) {
        return totalDeposits;
    }

    function getTotalStakes() external view returns (uint256) {
        return totalStakes;
    }

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

    function getStakingAPY() external view returns (uint256) {
        return stakingAPY;
    }

    function getDepositAPY() external view returns (uint256) {
        return depositAPY;
    }

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

    function emergencyUnstake(address user) external onlyRole(EMERGENCY_ROLE) {
        UserInfo storage userdata = userInfo[user];
        uint256 amount = userdata.stakedAmount;
        
        if (amount > 0) {
            userdata.stakedAmount = 0;
            totalStakes -= amount;
            qeuro.transfer(user, amount);
        }
    }

    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }

    function getPoolConfig() external view returns (
        uint256 minStakeAmount_,
        uint256 unstakingCooldown_,
        uint256 depositFee_,
        uint256 withdrawalFee_,
        uint256 performanceFee_
    ) {
        return (minStakeAmount, unstakingCooldown, depositFee, withdrawalFee, performanceFee);
    }

    function isPoolActive() external view returns (bool) {
        return !paused();
    }

    function _authorizeUpgrade(address newImplementation) 
        internal 
        override 
        onlyRole(UPGRADER_ROLE) 
    {}
}