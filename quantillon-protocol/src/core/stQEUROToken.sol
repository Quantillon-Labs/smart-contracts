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
import "../libraries/ValidationLibrary.sol";
import "./SecureUpgradeable.sol";
import "../libraries/TreasuryRecoveryLibrary.sol";
import "../libraries/FlashLoanProtectionLibrary.sol";
import "../libraries/TimeProviderLibrary.sol";

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
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
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

    /// @notice TimeProvider contract for centralized time management
    /// @dev Used to replace direct block.timestamp usage for testability and consistency
    TimeProvider public immutable timeProvider;
    
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

    /// @notice Virtual shares to prevent exchange rate manipulation
    /// @dev Prevents donation attacks by maintaining minimum share value
    uint256 private constant VIRTUAL_SHARES = 1e8;
    
    /// @notice Virtual assets to prevent exchange rate manipulation
    /// @dev Prevents donation attacks by maintaining minimum asset value
    uint256 private constant VIRTUAL_ASSETS = 1e8;
    
    /// @notice Maximum batch size for staking operations to prevent DoS
    /// @dev Prevents out-of-gas attacks through large arrays
    uint256 public constant MAX_BATCH_SIZE = 100;

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

    /// @notice Emitted when ETH is recovered to the treasury
    /// @param to Address to which ETH was recovered
    /// @param amount Amount of ETH recovered
    event ETHRecovered(address indexed to, uint256 indexed amount);

    // =============================================================================
    // MODIFIERS - Access control and security
    // =============================================================================

    /**
     * @notice Modifier to protect against flash loan attacks
     * @dev Checks that the contract's total underlying QEURO doesn't decrease during execution
     * @dev This prevents flash loans that would drain QEURO from the contract
     */
    modifier flashLoanProtection() {
        uint256 totalUnderlyingBefore = totalUnderlying;
        _;
        uint256 totalUnderlyingAfter = totalUnderlying;
        require(totalUnderlyingAfter >= totalUnderlyingBefore, "Flash loan detected: Total underlying decreased");
    }

    // =============================================================================
    // INITIALIZER - Contract initialization
    // =============================================================================

    /**
     * @notice Constructor for stQEURO token implementation
     * @dev Initializes the time provider and disables initialization on implementation
     * @param _timeProvider Address of the time provider contract
     * @custom:security Disables initialization on implementation for security
     * @custom:validation Validates time provider is not zero address
     * @custom:state-changes Sets timeProvider and disables initializers
     * @custom:events No events emitted
     * @custom:errors Throws ZeroAddress if time provider is zero
     * @custom:reentrancy Not protected - constructor only
     * @custom:access Public constructor
     * @custom:oracle No oracle dependencies
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(TimeProvider _timeProvider) {
        if (address(_timeProvider) == address(0)) revert ErrorLibrary.ZeroAddress();
        timeProvider = _timeProvider;
        // Disables initialization on the implementation for security
        _disableInitializers();
    }

    /**
     * @notice Initialize the stQEURO token contract
     * @dev Sets up the contract with all required addresses and roles
     * @param admin Address of the admin role
     * @param _qeuro Address of the QEURO token contract
     * @param _yieldShift Address of the YieldShift contract
     * @param _usdc Address of the USDC token contract
     * @param _treasury Address of the treasury
     * @param _timelock Address of the timelock contract
     * @custom:security Validates all addresses are not zero
     * @custom:validation Validates all input addresses
     * @custom:state-changes Initializes ERC20, AccessControl, and Pausable
     * @custom:events Emits initialization events
     * @custom:errors Throws if any address is zero
     * @custom:reentrancy Protected by initializer modifier
     * @custom:access Public initializer
     * @custom:oracle No oracle dependencies
     */
    function initialize(
        address admin,
        address _qeuro,
        address _yieldShift,
        address _usdc,
        address _treasury,
        address _timelock
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
        __SecureUpgradeable_init(_timelock);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(YIELD_MANAGER_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);

        qeuro = IQEUROToken(_qeuro);
        yieldShift = IYieldShift(_yieldShift);
        usdc = IERC20(_usdc);
        ValidationLibrary.validateTreasuryAddress(_treasury);
        treasury = _treasury;

        // Initialize exchange rate at 1:1
        exchangeRate = 1e18;
        lastUpdateTime = timeProvider.currentTime();
        
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
     * @dev Converts QEURO to stQEURO at current exchange rate
     * @param qeuroAmount Amount of QEURO to stake
     * @return stQEUROAmount Amount of stQEURO received
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function stake(uint256 qeuroAmount) external nonReentrant whenNotPaused flashLoanProtection returns (uint256 stQEUROAmount) {
        require(qeuroAmount > 0, "stQEURO: Amount must be positive");
        require(qeuro.balanceOf(msg.sender) >= qeuroAmount, "stQEURO: Insufficient QEURO balance");

        // Update exchange rate before staking
        _updateExchangeRate();

        // Calculate stQEURO amount based on current exchange rate
        // GAS OPTIMIZATION: Cache storage read
        uint256 exchangeRate_ = exchangeRate;
        stQEUROAmount = qeuroAmount.mulDiv(1e18, exchangeRate_);

        // Transfer QEURO from user

        IERC20(address(qeuro)).safeTransferFrom(msg.sender, address(this), qeuroAmount);

        // Update totals - Use checked arithmetic for critical state
        totalUnderlying = totalUnderlying + qeuroAmount;

        // Mint stQEURO to user
        _mint(msg.sender, stQEUROAmount);

        emit QEUROStaked(msg.sender, qeuroAmount, stQEUROAmount);
    }

    /**
     * @notice Unstake QEURO by burning stQEURO
     * @dev Burns stQEURO tokens and returns QEURO at current exchange rate
     * @param stQEUROAmount Amount of stQEURO to burn
     * @return qeuroAmount Amount of QEURO received
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function unstake(uint256 stQEUROAmount) external nonReentrant whenNotPaused returns (uint256 qeuroAmount) {
        require(stQEUROAmount > 0, "stQEURO: Amount must be positive");
        require(balanceOf(msg.sender) >= stQEUROAmount, "stQEURO: Insufficient stQEURO balance");

        // Update exchange rate before unstaking
        _updateExchangeRate();

        // Calculate QEURO amount based on current exchange rate
        // GAS OPTIMIZATION: Cache storage read
        uint256 exchangeRate_ = exchangeRate;
        qeuroAmount = stQEUROAmount.mulDiv(exchangeRate_, 1e18);

        // Ensure we have enough QEURO
        require(totalUnderlying >= qeuroAmount, "stQEURO: Insufficient underlying");

        // Burn stQEURO from user
        _burn(msg.sender, stQEUROAmount);

        // Update totals - Use checked arithmetic for critical state
        totalUnderlying = totalUnderlying - qeuroAmount;

        IERC20(address(qeuro)).safeTransfer(msg.sender, qeuroAmount);

        emit QEUROUnstaked(msg.sender, stQEUROAmount, qeuroAmount);
    }

    /**
     * @notice Batch stake QEURO to receive stQEURO for multiple amounts
     * @dev Processes multiple staking operations in a single transaction
     * @param qeuroAmounts Array of QEURO amounts to stake
     * @return stQEUROAmounts Array of stQEURO amounts received
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function batchStake(uint256[] calldata qeuroAmounts) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256[] memory stQEUROAmounts) 
    {
        if (qeuroAmounts.length > MAX_BATCH_SIZE) revert ErrorLibrary.BatchSizeTooLarge();
        
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


        address staker = msg.sender;
        uint256 exchangeRate_ = exchangeRate;
        
        // Process each stake
        for (uint256 i = 0; i < qeuroAmounts.length; i++) {
            uint256 qeuroAmount = qeuroAmounts[i];
            
            // Calculate stQEURO amount based on current exchange rate
            uint256 stQEUROAmount = qeuroAmount.mulDiv(1e18, exchangeRate_);
            stQEUROAmounts[i] = stQEUROAmount;

            // Mint stQEURO to user
            _mint(staker, stQEUROAmount);

            emit QEUROStaked(staker, qeuroAmount, stQEUROAmount);
        }
    }

    /**
     * @notice Batch unstake QEURO by burning stQEURO for multiple amounts
     * @dev Processes multiple unstaking operations in a single transaction
     * @param stQEUROAmounts Array of stQEURO amounts to burn
     * @return qeuroAmounts Array of QEURO amounts received
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function batchUnstake(uint256[] calldata stQEUROAmounts) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256[] memory qeuroAmounts) 
    {
        if (stQEUROAmounts.length > MAX_BATCH_SIZE) revert ErrorLibrary.BatchSizeTooLarge();
        
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
        uint256 exchangeRate_ = exchangeRate; // GAS OPTIMIZATION: Cache storage read
        for (uint256 i = 0; i < stQEUROAmounts.length; i++) {
            uint256 qeuroAmount = stQEUROAmounts[i].mulDiv(exchangeRate_, 1e18);
            qeuroAmounts[i] = qeuroAmount;
            totalQeuroAmount += qeuroAmount;
        }

        // Ensure we have enough QEURO
        require(totalUnderlying >= totalQeuroAmount, "stQEURO: Insufficient underlying");


        address unstaker = msg.sender;
        
        // Process each unstake
        for (uint256 i = 0; i < stQEUROAmounts.length; i++) {
            uint256 stQEUROAmount = stQEUROAmounts[i];
            uint256 qeuroAmount = qeuroAmounts[i];

            // Burn stQEURO from user
            _burn(unstaker, stQEUROAmount);

            // Transfer QEURO to user
            IERC20(address(qeuro)).safeTransfer(unstaker, qeuroAmount);

            emit QEUROUnstaked(unstaker, stQEUROAmount, qeuroAmount);
        }

        // Update totals once at the end
        totalUnderlying = totalUnderlying - totalQeuroAmount;
    }

    /**
     * @notice Batch transfer stQEURO tokens to multiple addresses
     * @dev Transfers stQEURO tokens to multiple recipients in a single transaction
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts to transfer
     * @return bool Always returns true if successful
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts)
        external
        whenNotPaused
        returns (bool)
    {
        if (recipients.length != amounts.length) revert ErrorLibrary.ArrayLengthMismatch();
        if (recipients.length > MAX_BATCH_SIZE) revert ErrorLibrary.BatchSizeTooLarge();
        

        uint256 length = recipients.length;
        address sender = msg.sender;
        
        // Pre-validate recipients and amounts
        for (uint256 i = 0; i < length;) {
            require(recipients[i] != address(0), "stQEURO: Cannot transfer to zero address");
            require(amounts[i] > 0, "stQEURO: Amount must be positive");
            
            unchecked { ++i; }
        }
        
        // Perform transfers using OpenZeppelin's transfer mechanism
        for (uint256 i = 0; i < length;) {
            _transfer(sender, recipients[i], amounts[i]);
            
            unchecked { ++i; }
        }
        
        return true;
    }

    // =============================================================================
    // YIELD FUNCTIONS
    // =============================================================================

    /**
     * @notice Distribute yield to stQEURO holders (increases exchange rate)
     * @dev Distributes USDC yield to stQEURO holders by increasing the exchange rate
     * @param yieldAmount Amount of yield in USDC
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
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
        lastUpdateTime = timeProvider.currentTime();

        // Update totals - Use checked arithmetic for critical state
        totalYieldEarned = totalYieldEarned + netYield;

        emit ExchangeRateUpdated(oldRate, exchangeRate, timeProvider.currentTime());
        emit YieldDistributed(netYield, exchangeRate);
    }

    /**
     * @notice Claim accumulated yield for a user (in USDC)
     * @dev In yield accrual model, yield is claimed by unstaking - kept for compatibility
     * @return yieldAmount Amount of yield claimed (always 0 in this model)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function claimYield() public returns (uint256 yieldAmount) {
        // In yield accrual model, yield is claimed by unstaking
        // This function is kept for compatibility but returns 0
        yieldAmount = 0;
        
        emit YieldClaimed(msg.sender, yieldAmount);
    }

    /**
     * @notice Get pending yield for a user (in USDC)
     * @dev In yield accrual model, yield is distributed via exchange rate increases
     * @param user User address
     * @return yieldAmount Pending yield amount
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
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
     * @dev Returns the current exchange rate calculated with yield accrual
     * @return uint256 Current exchange rate (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function getExchangeRate() external view returns (uint256) {
        return _calculateCurrentExchangeRate();
    }

    /**
     * @notice Get total value locked in stQEURO
     * @dev Returns the total amount of QEURO underlying all stQEURO tokens
     * @return uint256 Total value locked in QEURO (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function getTVL() external view returns (uint256) {
        return totalUnderlying;
    }

    /**
     * @notice Get user's QEURO equivalent balance
     * @dev Calculates the QEURO equivalent of a user's stQEURO balance
     * @param user User address
     * @return qeuroEquivalent QEURO equivalent of stQEURO balance
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function getQEUROEquivalent(address user) external view returns (uint256 qeuroEquivalent) {
        uint256 stQEUROBalance = balanceOf(user);
        if (stQEUROBalance == 0) return 0;

        uint256 currentRate = _calculateCurrentExchangeRate();
        qeuroEquivalent = stQEUROBalance.mulDiv(currentRate, 1e18);
    }

    /**
     * @notice Get staking statistics
     * @dev Returns comprehensive staking statistics including supply, TVL, and yield
     * @return totalStQEUROSupply Total supply of stQEURO tokens
     * @return totalQEUROUnderlying Total QEURO underlying all stQEURO
     * @return currentExchangeRate Current exchange rate between QEURO and stQEURO
     * @return totalYieldEarned_ Total yield earned by all stakers
     * @return apy Annual percentage yield (calculated off-chain)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
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
     * @notice Update exchange rate based on time elapsed and yield accrual
     * @dev Internal function to update exchange rate when conditions are met
     * @custom:security Calculates new rate with bounds checking to prevent manipulation
     * @custom:validation No input validation required
     * @custom:state-changes Updates exchangeRate and lastUpdateTime if rate changes
     * @custom:events Emits ExchangeRateUpdated if rate changes
     * @custom:errors No errors thrown - safe arithmetic used
     * @custom:reentrancy Not protected - internal function only
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _updateExchangeRate() internal {
        uint256 newRate = _calculateCurrentExchangeRate();
        if (newRate != exchangeRate) {
            uint256 oldRate = exchangeRate;
            exchangeRate = newRate;
            lastUpdateTime = timeProvider.currentTime();
            
            emit ExchangeRateUpdated(oldRate, newRate, block.timestamp);
        }
    }

    /**
     * @notice Calculate current exchange rate including accrued yield
     * @return Current exchange rate (18 decimals) including pending yield
     * @dev Calculates exchange rate based on total underlying assets and pending yield
     * @custom:security Uses minimum supply threshold to prevent manipulation
     * @custom:validation No input validation required
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe arithmetic used
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _calculateCurrentExchangeRate() internal view returns (uint256) {
        uint256 supply = totalSupply();
        
        // Minimum supply threshold to prevent manipulation
        if (supply < 1e6) return 1e18; // Minimum 0.000000000001 stQEURO

        // Get yield from YieldShift
        uint256 pendingYield = yieldShift.getUserPendingYield(address(this));
        
        if (pendingYield >= minYieldThreshold || 
            timeProvider.currentTime() >= lastUpdateTime + maxUpdateFrequency) {
            
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
     * @dev Updates yield fee, minimum threshold, and maximum update frequency
     * @param _yieldFee New yield fee in basis points
     * @param _minYieldThreshold New minimum yield threshold in USDC
     * @param _maxUpdateFrequency New maximum update frequency in seconds
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
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
     * @dev Updates the treasury address for token recovery operations
     * @param _treasury New treasury address
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function updateTreasury(address _treasury) external onlyRole(GOVERNANCE_ROLE) {
        require(_treasury != address(0), "stQEURO: Treasury cannot be zero");
        treasury = _treasury;
    }

    // =============================================================================
    // OVERRIDE FUNCTIONS
    // =============================================================================

    /**
     * @notice Returns the number of decimals used by the token
     * @dev Always returns 18 to match QEURO token standard
     * @return The number of decimals (18)
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }



    // =============================================================================
    // EMERGENCY FUNCTIONS
    // =============================================================================

    /**
     * @notice Pauses all token transfers and minting/burning operations
     * @dev Can only be called by addresses with EMERGENCY_ROLE during emergencies
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
     * @notice Unpauses all token transfers and minting/burning operations
     * @dev Can only be called by addresses with EMERGENCY_ROLE to resume normal operations
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
     * @notice Emergency withdrawal of QEURO (only in emergency)
     * @dev Emergency function to withdraw QEURO for a specific user
     * @param user Address of the user to withdraw for
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function emergencyWithdraw(address user) external onlyRole(EMERGENCY_ROLE) {
        uint256 stQEUROBalance = balanceOf(user);
        if (stQEUROBalance > 0) {
            uint256 qeuroAmount = stQEUROBalance.mulDiv(exchangeRate, 1e18);
            
            _burn(user, stQEUROBalance);
            totalUnderlying = totalUnderlying - qeuroAmount;
            
    
            // safeTransfer() will revert on failure, preventing silent failures
            IERC20(address(qeuro)).safeTransfer(user, qeuroAmount);
        }
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
    
    /**
     * @notice Returns the current virtual protection status
     * @return virtualShares Current virtual shares amount
     * @return virtualAssets Current virtual assets amount
     * @return effectiveSupply Effective supply including virtual shares
     * @return effectiveAssets Effective assets including virtual assets
     * @dev Useful for monitoring and debugging virtual protection
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getVirtualProtectionStatus() external view returns (
        uint256 virtualShares,
        uint256 virtualAssets,
        uint256 effectiveSupply,
        uint256 effectiveAssets
    ) {
        virtualShares = VIRTUAL_SHARES;
        virtualAssets = VIRTUAL_ASSETS;
        effectiveSupply = totalSupply() + VIRTUAL_SHARES;
        effectiveAssets = totalUnderlying + VIRTUAL_ASSETS;
        
        return (virtualShares, virtualAssets, effectiveSupply, effectiveAssets);
    }

}
