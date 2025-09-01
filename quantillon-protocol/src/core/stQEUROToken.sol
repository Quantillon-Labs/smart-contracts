// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// =============================================================================
// IMPORTS - OpenZeppelin libraries and protocol interfaces
// =============================================================================

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IQEUROToken.sol";
import "../interfaces/IYieldShift.sol";
import "../libraries/VaultMath.sol";
import "../libraries/ErrorLibrary.sol";
import "./SecureUpgradeable.sol";

/**
 * @title stQEUROToken
 * @notice Yield-bearing wrapper for QEURO tokens (yield accrual mechanism)
 * 
 * @dev Main characteristics:
 *      - Yield-bearing wrapper token for QEURO
 *      - Exchange rate increases over time as yield accrues
 *      - Similar to stETH (Lido's staked ETH token)
 *      - Automatic yield distribution to all stQEURO holders
 *      - Fee structure for protocol sustainability
 *      - Emergency pause mechanism for crisis situations
 *      - Upgradeable via UUPS pattern
 * 
 * @dev Staking mechanics:
 *      - Users stake QEURO to receive stQEURO
 *      - Exchange rate starts at 1:1 and increases over time
 *      - Yield is distributed proportionally to all stQEURO holders
 *      - Users can unstake at any time to receive QEURO + accrued yield
 *      - No lock-up period or cooldown requirements
 * 
 * @dev Yield distribution:
 *      - Yield is distributed from protocol fees and yield shift mechanisms
 *      - Exchange rate increases as yield accrues
 *      - All stQEURO holders benefit from yield automatically
 *      - Yield fees charged for protocol sustainability
 *      - Real-time yield tracking and distribution
 * 
 * @dev Exchange rate mechanism:
 *      - Exchange rate = (totalUnderlying + totalYieldEarned) / totalSupply
 *      - Increases over time as yield is earned
 *      - Updated periodically or when yield is distributed
 *      - Minimum yield threshold prevents frequent updates
 *      - Maximum update frequency prevents excessive gas costs
 * 
 * @dev Fee structure:
 *      - Yield fees on distributed yield
 *      - Treasury receives fees for protocol sustainability
 *      - Dynamic fee adjustment based on market conditions
 *      - Transparent fee structure for users
 * 
 * @dev Security features:
 *      - Role-based access control for all critical operations
 *      - Reentrancy protection for all external calls
 *      - Emergency pause mechanism for crisis situations
 *      - Upgradeable architecture for future improvements
 *      - Secure yield distribution mechanisms
 *      - Exchange rate validation
 * 
 * @dev Integration points:
 *      - QEURO token for staking and unstaking
 *      - USDC for yield payments
 *      - Yield shift mechanism for yield management
 *      - Treasury for fee collection
 *      - Vault math library for calculations
 * 
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract stQEUROToken is 
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
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
    
    /// @notice Role for yield management operations (distribution, updates)
    /// @dev keccak256 hash avoids role collisions with other contracts
    /// @dev Should be assigned to yield management system or governance
    bytes32 public constant YIELD_MANAGER_ROLE = keccak256("YIELD_MANAGER_ROLE");
    
    /// @notice Role for emergency operations (pause, emergency actions)
    /// @dev keccak256 hash avoids role collisions with other contracts
    /// @dev Should be assigned to emergency multisig
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    /// @notice Role for performing contract upgrades via UUPS pattern


    // =============================================================================
    // STATE VARIABLES - External contracts and configuration
    // =============================================================================
    
    /// @notice QEURO token contract for staking and unstaking
    /// @dev Used for all QEURO staking and unstaking operations
    /// @dev Should be the official QEURO token contract
    IQEUROToken public qeuro;
    
    /// @notice YieldShift contract for yield distribution
    /// @dev Handles yield distribution and management
    /// @dev Used for yield calculations and distributions
    IYieldShift public yieldShift;
    
    /// @notice USDC token for yield payments
    /// @dev Used for yield distributions to stQEURO holders
    /// @dev Should be the official USDC contract on the target network
    IERC20 public usdc;
    
    /// @notice Treasury address for fee collection
    /// @dev Receives yield fees for protocol sustainability
    /// @dev Should be a secure multisig or DAO treasury
    address public treasury;
    
    // Yield and exchange rate variables
    /// @notice Exchange rate between QEURO and stQEURO (18 decimals)
    /// @dev Increases over time as yield accrues (like stETH)
    /// @dev Formula: (totalUnderlying + totalYieldEarned) / totalSupply
    uint256 public exchangeRate;
    
    /// @notice Timestamp of last exchange rate update
    /// @dev Used to track when exchange rate was last updated
    /// @dev Used for yield calculation intervals
    uint256 public lastUpdateTime;
    
    /// @notice Total QEURO underlying the stQEURO supply
    /// @dev Sum of all QEURO staked by users
    /// @dev Used for exchange rate calculations
    uint256 public totalUnderlying;
    
    /// @notice Total yield earned by stQEURO holders
    /// @dev Sum of all yield distributed to stQEURO holders
    /// @dev Used for exchange rate calculations and analytics
    uint256 public totalYieldEarned;
    
    // Fee and threshold configuration
    /// @notice Fee charged on yield distributions (in basis points)
    /// @dev Example: 200 = 2% yield fee
    /// @dev Revenue source for the protocol
    uint256 public yieldFee;
    
    /// @notice Minimum yield amount to trigger exchange rate update
    /// @dev Prevents frequent updates for small yield amounts
    /// @dev Reduces gas costs and improves efficiency
    uint256 public minYieldThreshold;
    
    /// @notice Maximum time between exchange rate updates (in seconds)
    /// @dev Ensures regular updates even with low yield
    /// @dev Example: 1 day = 86400 seconds
    uint256 public maxUpdateFrequency;

    // =============================================================================
    // EVENTS - Events for tracking and monitoring
    // =============================================================================
    
    /// @notice Emitted when QEURO is staked to receive stQEURO
    /// @param user Address of the user who staked
    /// @param qeuroAmount Amount of QEURO staked (18 decimals)
    /// @param stQEUROAmount Amount of stQEURO received (18 decimals)
    /// @dev Indexed parameters allow efficient filtering of events
    event QEUROStaked(address indexed user, uint256 qeuroAmount, uint256 stQEUROAmount);
    
    /// @notice Emitted when stQEURO is unstaked to receive QEURO
    /// @param user Address of the user who unstaked
    /// @param stQEUROAmount Amount of stQEURO burned (18 decimals)
    /// @param qeuroAmount Amount of QEURO received (18 decimals)
    /// @dev Indexed parameters allow efficient filtering of events
    event QEUROUnstaked(address indexed user, uint256 stQEUROAmount, uint256 qeuroAmount);
    
    /// @notice Emitted when exchange rate is updated
    /// @param oldRate Previous exchange rate (18 decimals)
    /// @param newRate New exchange rate (18 decimals)
    /// @param timestamp Timestamp of the update
    /// @dev Used to track exchange rate changes over time
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate, uint256 timestamp);
    
    /// @notice Emitted when yield is distributed to stQEURO holders
    /// @param yieldAmount Amount of yield distributed (18 decimals)
    /// @param newExchangeRate New exchange rate after distribution (18 decimals)
    /// @dev Used to track yield distributions and their impact
    /// @dev OPTIMIZED: Indexed exchange rate for efficient filtering
    event YieldDistributed(uint256 yieldAmount, uint256 indexed newExchangeRate);
    
    /// @notice Emitted when a user claims yield
    /// @param user Address of the user who claimed yield
    /// @param yieldAmount Amount of yield claimed (18 decimals)
    /// @dev Indexed parameters allow efficient filtering of events
    event YieldClaimed(address indexed user, uint256 yieldAmount);
    
    /// @notice Emitted when yield parameters are updated
    /// @param yieldFee New yield fee in basis points
    /// @param minYieldThreshold New minimum yield threshold
    /// @param maxUpdateFrequency New maximum update frequency
    /// @dev Used to track parameter changes by governance
    /// @dev OPTIMIZED: Indexed parameter type for efficient filtering
    event YieldParametersUpdated(string indexed parameterType, uint256 yieldFee, uint256 minYieldThreshold, uint256 maxUpdateFrequency);

    // =============================================================================
    // INITIALIZER - Contract initialization
    // =============================================================================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // Disables initialization on the implementation for security
        _disableInitializers();
    }

    function initialize(
        address admin,
        address _qeuro,
        address _yieldShift,
        address _usdc,
        address _treasury,
        address timelock
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
        __SecureUpgradeable_init(timelock);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(YIELD_MANAGER_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);

        qeuro = IQEUROToken(_qeuro);
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
        // SECURITY FIX: Use safeTransferFrom for reliable QEURO transfers
        IERC20(address(qeuro)).safeTransferFrom(msg.sender, address(this), qeuroAmount);

        // Update totals - Use checked arithmetic for critical state
        totalUnderlying = totalUnderlying + qeuroAmount;

        // Mint stQEURO to user
        _mint(msg.sender, stQEUROAmount);

        emit QEUROStaked(msg.sender, qeuroAmount, stQEUROAmount);
    }

    /**
     * @notice Unstake QEURO by burning stQEURO
     * @param stQEUROAmount Amount of stQEURO to burn
     * @return qeuroAmount Amount of QEURO received
     * 

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

        // Update totals - Use checked arithmetic for critical state
        totalUnderlying = totalUnderlying - qeuroAmount;

        // SECURITY FIX: Use safeTransfer for reliable QEURO transfers
        // safeTransfer() will revert on failure, preventing silent failures
        IERC20(address(qeuro)).safeTransfer(msg.sender, qeuroAmount);

        emit QEUROUnstaked(msg.sender, stQEUROAmount, qeuroAmount);
    }

    /**
     * @notice Batch stake QEURO to receive stQEURO for multiple amounts
     * @param qeuroAmounts Array of QEURO amounts to stake
     * @return stQEUROAmounts Array of stQEURO amounts received
     */
    function batchStake(uint256[] calldata qeuroAmounts) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256[] memory stQEUROAmounts) 
    {
        stQEUROAmounts = new uint256[](qeuroAmounts.length);
        uint256 totalQeuroAmount = 0;
        
        // Pre-validate amounts and calculate total
        for (uint256 i = 0; i < qeuroAmounts.length; i++) {
            require(qeuroAmounts[i] > 0, "stQEURO: Amount must be positive");
            totalQeuroAmount += qeuroAmounts[i];
        }
        
        require(qeuro.balanceOf(msg.sender) >= totalQeuroAmount, "stQEURO: Insufficient QEURO balance");

        // Update exchange rate before staking (once for the batch)
        _updateExchangeRate();

        // Transfer total QEURO from user FIRST
        IERC20(address(qeuro)).safeTransferFrom(msg.sender, address(this), totalQeuroAmount);

        // Update totals once
        totalUnderlying = totalUnderlying + totalQeuroAmount;

        // Process each stake
        for (uint256 i = 0; i < qeuroAmounts.length; i++) {
            uint256 qeuroAmount = qeuroAmounts[i];
            
            // Calculate stQEURO amount based on current exchange rate
            uint256 stQEUROAmount = qeuroAmount.mulDiv(1e18, exchangeRate);
            stQEUROAmounts[i] = stQEUROAmount;

            // Mint stQEURO to user
            _mint(msg.sender, stQEUROAmount);

            emit QEUROStaked(msg.sender, qeuroAmount, stQEUROAmount);
        }
    }

    /**
     * @notice Batch unstake QEURO by burning stQEURO for multiple amounts
     * @param stQEUROAmounts Array of stQEURO amounts to burn
     * @return qeuroAmounts Array of QEURO amounts received
     */
    function batchUnstake(uint256[] calldata stQEUROAmounts) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256[] memory qeuroAmounts) 
    {
        qeuroAmounts = new uint256[](stQEUROAmounts.length);
        uint256 totalStQEUROAmount = 0;
        uint256 totalQeuroAmount = 0;
        
        // Pre-validate amounts and calculate totals
        for (uint256 i = 0; i < stQEUROAmounts.length; i++) {
            require(stQEUROAmounts[i] > 0, "stQEURO: Amount must be positive");
            totalStQEUROAmount += stQEUROAmounts[i];
        }
        
        require(balanceOf(msg.sender) >= totalStQEUROAmount, "stQEURO: Insufficient stQEURO balance");

        // Update exchange rate before unstaking (once for the batch)
        _updateExchangeRate();

        // Calculate total QEURO to return and validate
        for (uint256 i = 0; i < stQEUROAmounts.length; i++) {
            uint256 qeuroAmount = stQEUROAmounts[i].mulDiv(exchangeRate, 1e18);
            qeuroAmounts[i] = qeuroAmount;
            totalQeuroAmount += qeuroAmount;
        }

        // Ensure we have enough QEURO
        require(totalUnderlying >= totalQeuroAmount, "stQEURO: Insufficient underlying");

        // Process each unstake
        for (uint256 i = 0; i < stQEUROAmounts.length; i++) {
            uint256 stQEUROAmount = stQEUROAmounts[i];
            uint256 qeuroAmount = qeuroAmounts[i];

            // Burn stQEURO from user
            _burn(msg.sender, stQEUROAmount);

            // Transfer QEURO to user
            IERC20(address(qeuro)).safeTransfer(msg.sender, qeuroAmount);

            emit QEUROUnstaked(msg.sender, stQEUROAmount, qeuroAmount);
        }

        // Update totals once at the end
        totalUnderlying = totalUnderlying - totalQeuroAmount;
    }

    /**
     * @notice Batch transfer stQEURO tokens to multiple addresses
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts to transfer
     */
    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts)
        external
        whenNotPaused
        returns (bool)
    {
        if (recipients.length != amounts.length) revert ErrorLibrary.ArrayLengthMismatch();
        
        // Pre-validate recipients and amounts
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "stQEURO: Cannot transfer to zero address");
            require(amounts[i] > 0, "stQEURO: Amount must be positive");
        }
        
        // Perform transfers using OpenZeppelin's transfer mechanism
        for (uint256 i = 0; i < recipients.length; i++) {
            _transfer(msg.sender, recipients[i], amounts[i]);
        }
        
        return true;
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

        // Update totals - Use checked arithmetic for critical state
        totalYieldEarned = totalYieldEarned + netYield;

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
        uint256 supply = totalSupply();
        
        // Minimum supply threshold to prevent manipulation
        if (supply < 1e6) return 1e18; // Minimum 0.000000000001 stQEURO

        // Get yield from YieldShift
        uint256 pendingYield = yieldShift.getUserPendingYield(address(this));
        
        if (pendingYield >= minYieldThreshold || 
            block.timestamp >= lastUpdateTime + maxUpdateFrequency) {
            
            // Add bounds checking
            uint256 totalValue = totalUnderlying + pendingYield;
            
            // Prevent extreme exchange rates
            uint256 newRate = totalValue.mulDiv(1e18, supply);
            
            // Limit rate changes to prevent manipulation
            uint256 maxChange = exchangeRate / 10; // Max 10% change
            if (newRate > exchangeRate + maxChange) {
                newRate = exchangeRate + maxChange;
            } else if (newRate < exchangeRate - maxChange) {
                newRate = exchangeRate - maxChange;
            }
            
            return newRate;
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

        emit YieldParametersUpdated("yield", _yieldFee, _minYieldThreshold, _maxUpdateFrequency);
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
     * 

     */
    function emergencyWithdraw(address user) external onlyRole(EMERGENCY_ROLE) {
        uint256 stQEUROBalance = balanceOf(user);
        if (stQEUROBalance > 0) {
            uint256 qeuroAmount = stQEUROBalance.mulDiv(exchangeRate, 1e18);
            
            _burn(user, stQEUROBalance);
            totalUnderlying = totalUnderlying - qeuroAmount;
            
            // SECURITY FIX: Use safeTransfer for reliable QEURO transfers
            // safeTransfer() will revert on failure, preventing silent failures
            IERC20(address(qeuro)).safeTransfer(user, qeuroAmount);
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
     * 

     */
    function recoverETH(address payable to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(to != address(0), "stQEURO: Cannot send to zero address");
        uint256 balance = address(this).balance;
        require(balance > 0, "stQEURO: No ETH to recover");
        
        // SECURITY FIX: Use call() instead of transfer() for reliable ETH transfers
        // transfer() has 2300 gas stipend which can fail with complex receive/fallback logic
        (bool success, ) = to.call{value: balance}("");
        require(success, "stQEURO: ETH transfer failed");
    }
}
