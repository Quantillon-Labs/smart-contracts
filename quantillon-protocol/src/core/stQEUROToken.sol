// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IQEURO.sol";
import "../interfaces/IYieldShift.sol";
import "../libraries/VaultMath.sol";

/**
 * @title stQEUROToken
 * @notice Yield-bearing wrapper for QEURO tokens (yield accrual mechanism)
 * @dev Implements yield accrual like stETH - exchange rate increases over time
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract stQEUROToken is 
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;
    using VaultMath for uint256;

    // =============================================================================
    // CONSTANTS AND ROLES
    // =============================================================================
    
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant YIELD_MANAGER_ROLE = keccak256("YIELD_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // =============================================================================
    // STATE VARIABLES
    // =============================================================================
    
    /// @notice QEURO token contract
    IQEURO public qeuro;
    
    /// @notice YieldShift contract for yield distribution
    IYieldShift public yieldShift;
    
    /// @notice USDC token for yield payments
    IERC20 public usdc;
    
    /// @notice Treasury address for fees
    address public treasury;
    
    /// @notice Exchange rate between QEURO and stQEURO (18 decimals)
    /// @dev Increases over time as yield accrues (like stETH)
    uint256 public exchangeRate;
    
    /// @notice Last time exchange rate was updated
    uint256 public lastUpdateTime;
    
    /// @notice Total QEURO underlying the stQEURO supply
    uint256 public totalUnderlying;
    
    /// @notice Total yield earned by stQEURO holders
    uint256 public totalYieldEarned;
    
    /// @notice Fee on yield (basis points)
    uint256 public yieldFee;
    
    /// @notice Minimum yield to trigger exchange rate update
    uint256 public minYieldThreshold;
    
    /// @notice Maximum time between exchange rate updates
    uint256 public maxUpdateFrequency;

    // =============================================================================
    // EVENTS
    // =============================================================================
    
    event QEUROStaked(address indexed user, uint256 qeuroAmount, uint256 stQEUROAmount);
    event QEUROUnstaked(address indexed user, uint256 stQEUROAmount, uint256 qeuroAmount);
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate, uint256 timestamp);
    event YieldDistributed(uint256 yieldAmount, uint256 newExchangeRate);
    event YieldClaimed(address indexed user, uint256 yieldAmount);
    event YieldParametersUpdated(uint256 yieldFee, uint256 minYieldThreshold, uint256 maxUpdateFrequency);

    // =============================================================================
    // INITIALIZER
    // =============================================================================

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin,
        address _qeuro,
        address _yieldShift,
        address _usdc,
        address _treasury
    ) public initializer {
        require(admin != address(0), "stQEURO: Admin cannot be zero");
        require(_qeuro != address(0), "stQEURO: QEURO cannot be zero");
        require(_yieldShift != address(0), "stQEURO: YieldShift cannot be zero");
        require(_usdc != address(0), "stQEURO: USDC cannot be zero");
        require(_treasury != address(0), "stQEURO: Treasury cannot be zero");

        __ERC20_init("Staked Quantillon Euro", "stQEURO");
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(YIELD_MANAGER_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        qeuro = IQEURO(_qeuro);
        yieldShift = IYieldShift(_yieldShift);
        usdc = IERC20(_usdc);
        treasury = _treasury;

        // Initialize exchange rate at 1:1
        exchangeRate = 1e18;
        lastUpdateTime = block.timestamp;
        
        // Initial parameters
        yieldFee = 1000; // 10% fee on yield
        minYieldThreshold = 1000e6; // 1000 USDC minimum to update
        maxUpdateFrequency = 1 hours; // Max 1 hour between updates
    }

    // =============================================================================
    // CORE STAKING FUNCTIONS
    // =============================================================================

    /**
     * @notice Stake QEURO to receive stQEURO
     * @param qeuroAmount Amount of QEURO to stake
     * @return stQEUROAmount Amount of stQEURO received
     */
    function stake(uint256 qeuroAmount) external nonReentrant whenNotPaused returns (uint256 stQEUROAmount) {
        require(qeuroAmount > 0, "stQEURO: Amount must be positive");
        require(qeuro.balanceOf(msg.sender) >= qeuroAmount, "stQEURO: Insufficient QEURO balance");

        // Update exchange rate before staking
        _updateExchangeRate();

        // Calculate stQEURO amount based on current exchange rate
        stQEUROAmount = qeuroAmount.mulDiv(1e18, exchangeRate);

        // Transfer QEURO from user
        qeuro.transferFrom(msg.sender, address(this), qeuroAmount);

        // Update totals
        totalUnderlying += qeuroAmount;

        // Mint stQEURO to user
        _mint(msg.sender, stQEUROAmount);

        emit QEUROStaked(msg.sender, qeuroAmount, stQEUROAmount);
    }

    /**
     * @notice Unstake QEURO by burning stQEURO
     * @param stQEUROAmount Amount of stQEURO to burn
     * @return qeuroAmount Amount of QEURO received
     */
    function unstake(uint256 stQEUROAmount) external nonReentrant whenNotPaused returns (uint256 qeuroAmount) {
        require(stQEUROAmount > 0, "stQEURO: Amount must be positive");
        require(balanceOf(msg.sender) >= stQEUROAmount, "stQEURO: Insufficient stQEURO balance");

        // Update exchange rate before unstaking
        _updateExchangeRate();

        // Calculate QEURO amount based on current exchange rate
        qeuroAmount = stQEUROAmount.mulDiv(exchangeRate, 1e18);

        // Ensure we have enough QEURO
        require(totalUnderlying >= qeuroAmount, "stQEURO: Insufficient underlying");

        // Burn stQEURO from user
        _burn(msg.sender, stQEUROAmount);

        // Update totals
        totalUnderlying -= qeuroAmount;

        // Transfer QEURO to user
        qeuro.transfer(msg.sender, qeuroAmount);

        emit QEUROUnstaked(msg.sender, stQEUROAmount, qeuroAmount);
    }

    // =============================================================================
    // YIELD FUNCTIONS
    // =============================================================================

    /**
     * @notice Distribute yield to stQEURO holders (increases exchange rate)
     * @param yieldAmount Amount of yield in USDC
     */
    function distributeYield(uint256 yieldAmount) external onlyRole(YIELD_MANAGER_ROLE) {
        require(yieldAmount > 0, "stQEURO: Yield amount must be positive");
        require(totalSupply() > 0, "stQEURO: No stQEURO supply");

        // Transfer USDC yield from sender
        usdc.safeTransferFrom(msg.sender, address(this), yieldAmount);

        // Calculate fee
        uint256 fee = yieldAmount.percentageOf(yieldFee);
        uint256 netYield = yieldAmount - fee;

        // Send fee to treasury
        if (fee > 0) {
            usdc.safeTransfer(treasury, fee);
        }

        // Update exchange rate based on yield
        uint256 oldRate = exchangeRate;
        exchangeRate = exchangeRate + (netYield.mulDiv(1e18, totalSupply()));
        lastUpdateTime = block.timestamp;

        // Update totals
        totalYieldEarned += netYield;

        emit ExchangeRateUpdated(oldRate, exchangeRate, block.timestamp);
        emit YieldDistributed(netYield, exchangeRate);
    }

    /**
     * @notice Claim accumulated yield for a user (in USDC)
     * @return yieldAmount Amount of yield claimed
     */
    function claimYield() public returns (uint256 yieldAmount) {
        // In yield accrual model, yield is claimed by unstaking
        // This function is kept for compatibility but returns 0
        yieldAmount = 0;
        
        emit YieldClaimed(msg.sender, yieldAmount);
    }

    /**
     * @notice Get pending yield for a user (in USDC)
     * @param user User address
     * @return yieldAmount Pending yield amount
     */
    function getPendingYield(address user) public view returns (uint256 yieldAmount) {
        uint256 userBalance = balanceOf(user);
        if (userBalance == 0) return 0;

        // In yield accrual model, yield is distributed via exchange rate increases
        // Users can claim yield by unstaking (they get more QEURO than they staked)
        // This function returns 0 as yield is not claimed separately in USDC
        return 0;
    }

    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================

    /**
     * @notice Get current exchange rate between QEURO and stQEURO
     */
    function getExchangeRate() external view returns (uint256) {
        return _calculateCurrentExchangeRate();
    }

    /**
     * @notice Get total value locked in stQEURO
     */
    function getTVL() external view returns (uint256) {
        return totalUnderlying;
    }

    /**
     * @notice Get user's QEURO equivalent balance
     * @param user User address
     * @return qeuroEquivalent QEURO equivalent of stQEURO balance
     */
    function getQEUROEquivalent(address user) external view returns (uint256 qeuroEquivalent) {
        uint256 stQEUROBalance = balanceOf(user);
        if (stQEUROBalance == 0) return 0;

        uint256 currentRate = _calculateCurrentExchangeRate();
        qeuroEquivalent = stQEUROBalance.mulDiv(currentRate, 1e18);
    }

    /**
     * @notice Get staking statistics
     */
    function getStakingStats() external view returns (
        uint256 totalStQEUROSupply,
        uint256 totalQEUROUnderlying,
        uint256 currentExchangeRate,
        uint256 totalYieldEarned_,
        uint256 apy
    ) {
        return (
            totalSupply(),
            totalUnderlying,
            _calculateCurrentExchangeRate(),
            totalYieldEarned,
            0 // APY calculated off-chain based on exchange rate changes
        );
    }

    // =============================================================================
    // INTERNAL FUNCTIONS
    // =============================================================================

    /**
     * @notice Update exchange rate based on time elapsed
     */
    function _updateExchangeRate() internal {
        uint256 newRate = _calculateCurrentExchangeRate();
        if (newRate != exchangeRate) {
            uint256 oldRate = exchangeRate;
            exchangeRate = newRate;
            lastUpdateTime = block.timestamp;
            
            emit ExchangeRateUpdated(oldRate, newRate, block.timestamp);
        }
    }

    /**
     * @notice Calculate current exchange rate including accrued yield
     */
    function _calculateCurrentExchangeRate() internal view returns (uint256) {
        if (totalSupply() == 0) return 1e18;

        // Get yield from YieldShift
        uint256 pendingYield = yieldShift.getUserPendingYield(address(this));
        
        if (pendingYield >= minYieldThreshold || 
            block.timestamp >= lastUpdateTime + maxUpdateFrequency) {
            
            // Calculate new exchange rate
            uint256 totalValue = totalUnderlying + pendingYield;
            return totalValue.mulDiv(1e18, totalSupply());
        }
        
        return exchangeRate;
    }

    // =============================================================================
    // GOVERNANCE FUNCTIONS
    // =============================================================================

    /**
     * @notice Update yield parameters
     */
    function updateYieldParameters(
        uint256 _yieldFee,
        uint256 _minYieldThreshold,
        uint256 _maxUpdateFrequency
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(_yieldFee <= 2000, "stQEURO: Yield fee too high"); // Max 20%
        require(_maxUpdateFrequency <= 24 hours, "stQEURO: Update frequency too long");

        yieldFee = _yieldFee;
        minYieldThreshold = _minYieldThreshold;
        maxUpdateFrequency = _maxUpdateFrequency;

        emit YieldParametersUpdated(_yieldFee, _minYieldThreshold, _maxUpdateFrequency);
    }

    /**
     * @notice Update treasury address
     */
    function updateTreasury(address _treasury) external onlyRole(GOVERNANCE_ROLE) {
        require(_treasury != address(0), "stQEURO: Treasury cannot be zero");
        treasury = _treasury;
    }

    // =============================================================================
    // OVERRIDE FUNCTIONS
    // =============================================================================

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    // =============================================================================
    // EMERGENCY FUNCTIONS
    // =============================================================================

    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }

    /**
     * @notice Emergency withdrawal of QEURO (only in emergency)
     */
    function emergencyWithdraw(address user) external onlyRole(EMERGENCY_ROLE) {
        uint256 stQEUROBalance = balanceOf(user);
        if (stQEUROBalance > 0) {
            uint256 qeuroAmount = stQEUROBalance.mulDiv(exchangeRate, 1e18);
            
            _burn(user, stQEUROBalance);
            totalUnderlying -= qeuroAmount;
            
            qeuro.transfer(user, qeuroAmount);
        }
    }

    // =============================================================================
    // RECOVERY FUNCTIONS
    // =============================================================================

    /**
     * @notice Recover accidentally sent tokens
     */
    function recoverToken(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(qeuro), "stQEURO: Cannot recover QEURO");
        require(token != address(this), "stQEURO: Cannot recover stQEURO");
        require(to != address(0), "stQEURO: Cannot send to zero address");
        
        IERC20(token).safeTransfer(to, amount);
    }

    /**
     * @notice Recover accidentally sent ETH
     */
    function recoverETH(address payable to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(to != address(0), "stQEURO: Cannot send to zero address");
        require(address(this).balance > 0, "stQEURO: No ETH to recover");
        
        to.transfer(address(this).balance);
    }
}
