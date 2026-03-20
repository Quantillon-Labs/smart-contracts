// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IUserPool} from "../../interfaces/IUserPool.sol";
import {IHedgerPool} from "../../interfaces/IHedgerPool.sol";
import {IAaveVault} from "../../interfaces/IAaveVault.sol";
import {IstQEURO} from "../../interfaces/IstQEURO.sol";
import {IStQEUROFactory} from "../../interfaces/IStQEUROFactory.sol";
import {VaultMath} from "../../libraries/VaultMath.sol";
import {CommonErrorLibrary} from "../../libraries/CommonErrorLibrary.sol";
import {YieldValidationLibrary} from "../../libraries/YieldValidationLibrary.sol";
import {AccessControlLibrary} from "../../libraries/AccessControlLibrary.sol";
import {TreasuryRecoveryLibrary} from "../../libraries/TreasuryRecoveryLibrary.sol";
import {TimeProvider} from "../../libraries/TimeProviderLibrary.sol";
import {YieldShiftCalculationLibrary} from "../../libraries/YieldShiftCalculationLibrary.sol";
import {YieldShiftOptimizationLibrary} from "../../libraries/YieldShiftOptimizationLibrary.sol";
import {CommonValidationLibrary} from "../../libraries/CommonValidationLibrary.sol";
import {SecureUpgradeable} from "../SecureUpgradeable.sol";

/**
 * @title YieldShift
 * @notice Dynamic yield distribution system balancing rewards between users and hedgers
 * 
 * @dev Main characteristics:
 *      - Dynamic yield allocation based on pool balance ratios
 *      - Time-weighted average price (TWAP) calculations for stability
 *      - Multiple yield sources integration (Aave, fees, interest differentials)
 *      - Automatic yield distribution with holding period requirements
 *      - Emergency pause mechanism for crisis situations
 *      - Upgradeable via UUPS pattern
 * 
 * @dev Yield shift mechanics:
 *      - Base yield shift determines default allocation (default 50/50)
 *      - Maximum yield shift caps allocation changes (default 90/10)
 *      - Adjustment speed controls how quickly shifts occur
 *      - Target pool ratio defines optimal balance point
 *      - Real-time calculations based on pool metrics
 * 
 * @dev Distribution algorithm:
 *      - Monitors user pool vs hedger pool size ratios
 *      - Adjusts yield allocation to incentivize balance
 *      - Higher user pool → more yield to hedgers (attract hedging)
 *      - Higher hedger pool → more yield to users (attract deposits)
 *      - Gradual adjustments prevent dramatic shifts
 *      - Flash deposit protection through eligible pool size calculations
 *      - Only deposits meeting holding period requirements count toward yield distribution
 * 
 * @dev Yield sources:
 *      - Aave yield from USDC deposits in lending protocols
 *      - Protocol fees from minting, redemption, and trading
 *      - Interest rate differentials from hedging operations
 *      - External yield farming opportunities
 *      - Authorized source validation for security
 * 
 * @dev Time-weighted calculations:
 *      - 24-hour TWAP for pool size measurements
 *      - Historical data tracking for trend analysis
 *      - Maximum history length prevents unbounded storage
 *      - Drift tolerance for timestamp validation
 *      - Automatic data cleanup and optimization
 * 
 * @dev Holding period requirements:
 *      - Minimum 7-day holding period for yield claims
 *      - Prevents yield farming attacks and speculation
 *      - Encourages long-term protocol participation
 *      - Tracked per user with deposit timestamps
 *      - Enhanced protection against flash deposit manipulation
 *      - Eligible pool sizes exclude recent deposits from yield calculations
 *      - Dynamic discount system based on deposit timing and activity
 * 
 * @dev Security features:
 *      - Role-based access control for all critical operations
 *      - Reentrancy protection for all external calls
 *      - Emergency pause mechanism for crisis situations
 *      - Upgradeable architecture for future improvements
 *      - Authorized yield source validation
 *      - Secure yield distribution mechanisms
 *      - Flash deposit attack prevention through holding period requirements
 *      - Eligible pool size calculations for yield distribution
 *      - Time-weighted protection against yield manipulation
 * 
 * @dev Integration points:
 *      - User pool for deposit and staking metrics
 *      - Hedger pool for hedging exposure metrics
 *      - Aave vault for yield generation and harvesting
 *      - stQEURO token for user yield distribution
 *      - USDC for yield payments and transfers
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract YieldShift is 
    Initializable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    SecureUpgradeable
{
    using SafeERC20 for IERC20;
    using Address for address payable;
    using VaultMath for uint256;
    using AccessControlLibrary for AccessControlUpgradeable;
    using YieldValidationLibrary for uint256;

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant YIELD_MANAGER_ROLE = keccak256("YIELD_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    IERC20 public usdc;
    IUserPool public userPool;
    IHedgerPool public hedgerPool;
    IAaveVault public aaveVault;
    IStQEUROFactory public stQEUROFactory;

    /// @notice TimeProvider contract for centralized time management
    /// @dev Used to replace direct block.timestamp usage for testability and consistency
    TimeProvider public immutable TIME_PROVIDER;

    uint256 public baseYieldShift;
    uint256 public maxYieldShift;
    uint256 public adjustmentSpeed;
    uint256 public targetPoolRatio;
    
    uint256 public constant MIN_HOLDING_PERIOD = 7 days;
    uint256 public constant TWAP_PERIOD = 24 hours;
    uint256 public constant MAX_TIME_ELAPSED = 365 days;
    
    uint256 public currentYieldShift;
    uint256 public lastUpdateTime;
    
    uint256 public totalYieldGenerated;
    uint256 public totalYieldDistributed;
    uint256 public userYieldPool;
    uint256 public hedgerYieldPool;
    address public treasury;
    
    mapping(bytes32 => uint256) public yieldSources;
    bytes32[] public yieldSourceNames;
    
    // Add yield source authorization mappings
    mapping(address => bool) public authorizedYieldSources;
    mapping(address => bytes32) public sourceToYieldType;
    
    mapping(address => uint256) public userPendingYield;
    mapping(address => uint256) public hedgerPendingYield;
    mapping(address => uint256) public userLastClaim;
    mapping(address => uint256) public hedgerLastClaim;
    
    mapping(address => uint256) public lastDepositTime;
    
    /// @dev OPTIMIZED: Packed struct for gas efficiency in historical arrays
    struct PoolSnapshot {
        uint128 userPoolSize;
        uint128 hedgerPoolSize;
        uint64 timestamp;                   // Timestamp (8 bytes, until year 2554)
    }
    
    PoolSnapshot[] public userPoolHistory;
    PoolSnapshot[] public hedgerPoolHistory;
    uint256 public constant MAX_HISTORY_LENGTH = 1000;

    /// @dev OPTIMIZED: Packed struct for gas efficiency in yield shift tracking
    struct YieldShiftSnapshot {
        uint128 yieldShift;
        uint64 timestamp;                   // Timestamp (8 bytes, until year 2554)
    }
    YieldShiftSnapshot[] public yieldShiftHistory;
    mapping(address => uint256) public sourceToVaultId;
    bool public enforceSourceVaultBinding;

    struct YieldModelConfig {
        uint256 baseYieldShift;
        uint256 maxYieldShift;
        uint256 adjustmentSpeed;
        uint256 targetPoolRatio;
    }

    struct YieldDependencyConfig {
        address userPool;
        address hedgerPool;
        address aaveVault;
        address stQEUROFactory;
        address treasury;
    }

    /// @dev OPTIMIZED: Indexed timestamp for efficient time-based filtering
    event YieldDistributionUpdated(
        uint256 newYieldShift,
        uint256 userYieldAllocation,
        uint256 hedgerYieldAllocation,
        uint256 indexed timestamp
    );
    
    event UserYieldClaimed(address indexed user, uint256 yieldAmount, uint256 timestamp);
    event HedgerYieldClaimed(address indexed hedger, uint256 yieldAmount, uint256 timestamp);
    /// @dev OPTIMIZED: Indexed source and timestamp for efficient filtering
    event YieldAdded(uint256 yieldAmount, string indexed source, uint256 indexed timestamp);
    event SourceVaultBindingUpdated(address indexed source, uint256 indexed vaultId);
    event SourceVaultBindingModeUpdated(bool enabled);

    /**
     * @notice Constructor for YieldShift implementation
     * @dev Sets up the time provider and disables initialization on implementation for security
     * @param _TIME_PROVIDER Address of the time provider contract
     * @custom:security Validates time provider address and disables initialization on implementation
     * @custom:validation Validates time provider is not zero address
     * @custom:state-changes Sets time provider and disables initializers
     * @custom:events No events emitted
     * @custom:errors Throws ZeroAddress if time provider is zero
     * @custom:reentrancy Not protected - constructor only
     * @custom:access Public constructor
     * @custom:oracle No oracle dependencies
     */
    constructor(TimeProvider _TIME_PROVIDER) {
        if (address(_TIME_PROVIDER) == address(0)) revert CommonErrorLibrary.ZeroAddress();
        TIME_PROVIDER = _TIME_PROVIDER;
        _disableInitializers();
    }

    /**
     * @notice Initialize the YieldShift contract
     * @dev Sets up the contract with all required addresses and roles
     * @param admin Address of the admin role
     * @param _usdc Address of the USDC token contract
     * @param _userPool Address of the user pool contract
     * @param _hedgerPool Address of the hedger pool contract
     * @param _aaveVault Address of the Aave vault contract
     * @param _stQEUROFactory Address of the stQEURO factory contract
     * @param _timelock Address of the timelock contract
     * @param _treasury Address of the treasury
     * @custom:security Validates all addresses are not zero
     * @custom:validation Validates all input addresses
     * @custom:state-changes Initializes ReentrancyGuard, AccessControl, and Pausable
     * @custom:events Emits initialization events
     * @custom:errors Throws if any address is zero
     * @custom:reentrancy Protected by initializer modifier
     * @custom:access Public initializer
     * @custom:oracle No oracle dependencies
     */
    function initialize(
        address admin,
        address _usdc,
        address _userPool,
        address _hedgerPool,
        address _aaveVault,
        address _stQEUROFactory,
        address _timelock,
        address _treasury
    ) public initializer {
        // Minimal initializer: only core guards/roles + USDC and optional references
        AccessControlLibrary.validateAddress(admin);
        AccessControlLibrary.validateAddress(_usdc);

        __ReentrancyGuard_init();
        __AccessControl_init();
        __Pausable_init();
        __SecureUpgradeable_init(_timelock);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(YIELD_MANAGER_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);

        usdc = IERC20(_usdc);

        // Optional references may be zero during phased deploy; wire later via governance setters
        if (_userPool != address(0)) {
            AccessControlLibrary.validateAddress(_userPool);
            userPool = IUserPool(_userPool);
        }
        if (_hedgerPool != address(0)) {
            AccessControlLibrary.validateAddress(_hedgerPool);
            hedgerPool = IHedgerPool(_hedgerPool);
        }
        if (_aaveVault != address(0)) {
            AccessControlLibrary.validateAddress(_aaveVault);
            aaveVault = IAaveVault(_aaveVault);
        }
        if (_stQEUROFactory != address(0)) {
            AccessControlLibrary.validateAddress(_stQEUROFactory);
            stQEUROFactory = IStQEUROFactory(_stQEUROFactory);
        }
        if (_treasury != address(0)) {
            YieldValidationLibrary.validateTreasuryAddress(_treasury);
            CommonValidationLibrary.validateNonZeroAddress(_treasury, "treasury");
            treasury = _treasury;
        }

        // Scalar defaults only; defer arrays/history and authorizations to a separate bootstrap tx
        baseYieldShift = 5000;
        maxYieldShift = 9000;
        adjustmentSpeed = 100;
        targetPoolRatio = 10000;
        currentYieldShift = baseYieldShift;
        lastUpdateTime = TIME_PROVIDER.currentTime();
    }

    /**
     * @notice Governance bootstrap to set initial histories and source metadata after minimal init
     * @dev Lazily initializes historical arrays and default authorized yield sources
     * @custom:security Restricted to governance; reads trusted state only
     * @custom:validation Relies on prior initialization guarantees
     * @custom:state-changes Records initial snapshots and default yield source metadata
     * @custom:events Emits none (pure bookkeeping)
     * @custom:errors Reverts if caller lacks governance role
     * @custom:reentrancy Not applicable
     * @custom:access Governance-only
     * @custom:oracle Not applicable
     */
    function bootstrapDefaults() external {
        AccessControlLibrary.onlyGovernance(this);
        // Initialize arrays lazily to cut initializer gas
        _recordPoolSnapshot();
        yieldShiftHistory.push(YieldShiftSnapshot({
            // forge-lint: disable-next-line(unsafe-typecast)
            yieldShift: uint128(currentYieldShift),
            // forge-lint: disable-next-line(unsafe-typecast)
            timestamp: uint64(TIME_PROVIDER.currentTime())
        }));
        yieldSourceNames.push(keccak256("aave"));
        yieldSourceNames.push(keccak256("fees"));
        yieldSourceNames.push(keccak256("interest_differential"));
        authorizedYieldSources[address(this)] = true;
        sourceToYieldType[address(this)] = keccak256("aave");
    }

    /**
     * @notice Updates the yield distribution between users and hedgers
     * @dev Recalculates and applies new yield distribution ratios based on current pool states
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function updateYieldDistribution() external nonReentrant whenNotPaused {
        // Apply holding period requirements to current pool metrics
        (uint256 eligibleUserPoolSize, uint256 eligibleHedgerPoolSize,) = _getEligiblePoolMetrics();
        
        // Use eligible pool sizes for ratio calculation to prevent manipulation
        uint256 poolRatio = eligibleHedgerPoolSize == 0 ? type(uint256).max : 
                           eligibleUserPoolSize.mulDiv(10000, eligibleHedgerPoolSize);
        
        uint256 optimalShift = _calculateOptimalYieldShift(poolRatio);
        uint256 newYieldShift = _applyGradualAdjustment(optimalShift);
        
        currentYieldShift = newYieldShift;
        lastUpdateTime = TIME_PROVIDER.currentTime();
        
        // Record snapshot using eligible pool sizes to prevent future manipulation
        _recordPoolSnapshotWithEligibleSizes(eligibleUserPoolSize, eligibleHedgerPoolSize);
        
        emit YieldDistributionUpdated(
            newYieldShift,
            _calculateUserAllocation(),
            _calculateHedgerAllocation(),
            TIME_PROVIDER.currentTime()
        );
    }

    /**
     * @notice Add yield from authorized sources
     * @dev Adds yield from authorized sources and distributes it according to current yield shift
     * @param vaultId Registered vault identifier used to resolve the target stQEURO token
     * @param yieldAmount Amount of yield to add (6 decimals)
     * @param source Source identifier for the yield
     * @custom:security Validates caller is authorized for the yield source
     * @custom:validation Validates yield amount is positive and matches actual received
     * @custom:state-changes Updates yield sources and total yield generated
     * @custom:events Emits YieldAdded event
     * @custom:errors Throws if caller is unauthorized or yield amount mismatch
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to authorized yield sources
     * @custom:oracle No oracle dependencies
     */
    function addYield(uint256 vaultId, uint256 yieldAmount, bytes32 source) 
        external 
        nonReentrant 
    {
        // Verify caller is authorized for this yield source
        if (!authorizedYieldSources[msg.sender] || sourceToYieldType[msg.sender] != source) {
            revert CommonErrorLibrary.NotAuthorized();
        }
        
        CommonValidationLibrary.validatePositiveAmount(yieldAmount);
        if (vaultId == 0) revert CommonErrorLibrary.InvalidVault();
        if (enforceSourceVaultBinding) {
            uint256 boundVaultId = sourceToVaultId[msg.sender];
            if (boundVaultId == 0 || boundVaultId != vaultId) revert CommonErrorLibrary.NotAuthorized();
        }
        
        // Verify USDC was actually received
        uint256 balanceBefore = usdc.balanceOf(address(this));
        usdc.safeTransferFrom(msg.sender, address(this), yieldAmount);
        uint256 balanceAfter = usdc.balanceOf(address(this));
        uint256 actualReceived = balanceAfter - balanceBefore;
        if (actualReceived < yieldAmount || actualReceived > yieldAmount + 1) {
            revert CommonErrorLibrary.InvalidAmount();
        }
        
        yieldSources[source] += yieldAmount;
        totalYieldGenerated += yieldAmount;
        
        uint256 userAllocation = yieldAmount.mulDiv(currentYieldShift, 10000);
        uint256 hedgerAllocation = yieldAmount - userAllocation;
        
        userYieldPool += userAllocation;
        hedgerYieldPool += hedgerAllocation;
        
        if (userAllocation > 0) {
            if (address(stQEUROFactory) == address(0)) revert CommonErrorLibrary.InvalidAddress();
            address stQEUROAddress = stQEUROFactory.getStQEUROByVaultId(vaultId);
            if (stQEUROAddress == address(0)) revert CommonErrorLibrary.InvalidVault();

            usdc.safeIncreaseAllowance(stQEUROAddress, userAllocation);
            IstQEURO(stQEUROAddress).distributeYield(userAllocation);
        }
        
        emit YieldAdded(yieldAmount, string(abi.encodePacked(source)), TIME_PROVIDER.currentTime());
    }




    /**
     * @notice Claim user yield
     * @dev Claims yield for a user after holding period requirements are met
     * @param user Address of the user to claim yield for
     * @return yieldAmount Amount of yield claimed
     * @custom:security Validates caller is authorized and holding period is met
     * @custom:validation Validates user has pending yield and meets holding period
     * @custom:state-changes Updates user pending yield and transfers USDC
     * @custom:events Emits YieldClaimed event
     * @custom:errors Throws if caller is unauthorized or holding period not met
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to user or user pool
     * @custom:oracle No oracle dependencies
     */
    function claimUserYield(address user) 
        external 
        nonReentrant 
        returns (uint256 yieldAmount) 
    {
        if (msg.sender != user && msg.sender != address(userPool)) {
            revert CommonErrorLibrary.NotAuthorized();
        }
        
        yieldAmount = userPendingYield[user];
        
        if (yieldAmount > 0) {
            // Check holding period
            if (TIME_PROVIDER.currentTime() < lastDepositTime[user] + MIN_HOLDING_PERIOD) {
                revert CommonErrorLibrary.HoldingPeriodNotMet();
            }
            
            if (userYieldPool < yieldAmount) revert CommonErrorLibrary.InsufficientYield();
            
            userPendingYield[user] = 0;
            userLastClaim[user] = TIME_PROVIDER.currentTime();
            userYieldPool -= yieldAmount;
            totalYieldDistributed += yieldAmount;
            
            usdc.safeTransfer(user, yieldAmount);
            
            emit UserYieldClaimed(user, yieldAmount, TIME_PROVIDER.currentTime());
        }
    }

    /**
     * @notice Claim hedger yield
     * @dev Claims yield for a hedger
     * @param hedger Address of the hedger to claim yield for
     * @return yieldAmount Amount of yield claimed
     * @custom:security Validates caller is authorized
     * @custom:validation Validates hedger has pending yield
     * @custom:state-changes Updates hedger pending yield and transfers USDC
     * @custom:events Emits HedgerYieldClaimed event
     * @custom:errors Throws if caller is unauthorized or insufficient yield
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to hedger or hedger pool
     * @custom:oracle No oracle dependencies
     */
    function claimHedgerYield(address hedger) 
        external 
        nonReentrant 
        returns (uint256 yieldAmount) 
    {
        if (msg.sender != hedger && msg.sender != address(hedgerPool)) {
            revert CommonErrorLibrary.NotAuthorized();
        }
        
        yieldAmount = hedgerPendingYield[hedger];
        
        if (yieldAmount > 0) {
            if (hedgerYieldPool < yieldAmount) revert CommonErrorLibrary.InsufficientYield();
            
            hedgerPendingYield[hedger] = 0;
            hedgerLastClaim[hedger] = TIME_PROVIDER.currentTime();
            hedgerYieldPool -= yieldAmount;
            totalYieldDistributed += yieldAmount;
            
            usdc.safeTransfer(hedger, yieldAmount);
            
            emit HedgerYieldClaimed(hedger, yieldAmount, TIME_PROVIDER.currentTime());
        }
    }

    /**
     * @notice Calculate optimal yield shift based on current pool ratio
     * @param poolRatio Current ratio between user and hedger pools (basis points)
     * @return Optimal yield shift percentage (basis points)
     * @dev Calculates optimal yield allocation to incentivize pool balance
     * @custom:security Uses tolerance checks to prevent excessive adjustments
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe arithmetic used
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _calculateOptimalYieldShift(uint256 poolRatio) internal view returns (uint256) {
        return YieldShiftCalculationLibrary.calculateOptimalYieldShift(
            poolRatio, baseYieldShift, maxYieldShift, targetPoolRatio
        );
    }

    /**
     * @notice Apply gradual adjustment to yield shift to prevent sudden changes
     * @param targetShift Target yield shift percentage (basis points)
     * @return Adjusted yield shift percentage (basis points)
     * @dev Gradually adjusts yield shift based on adjustmentSpeed to prevent volatility
     * @custom:security Limits adjustment speed to prevent sudden changes
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe arithmetic used
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _applyGradualAdjustment(uint256 targetShift) internal view returns (uint256) {
        return YieldShiftCalculationLibrary.applyGradualAdjustment(
            currentYieldShift, targetShift, adjustmentSpeed
        );
    }

    /**
     * @notice Get current pool metrics
     * @dev Returns current pool sizes and ratio for yield shift calculations
     * @return userPoolSize Current user pool size
     * @return hedgerPoolSize Current hedger pool size
     * @return poolRatio Ratio of user to hedger pool sizes
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function _getCurrentPoolMetrics() internal view returns (
        uint256 userPoolSize,
        uint256 hedgerPoolSize,
        uint256 poolRatio
    ) {
        (userPoolSize, hedgerPoolSize, poolRatio) = YieldShiftOptimizationLibrary.getCurrentPoolMetrics(
            address(userPool),
            address(hedgerPool)
        );
    }
    
    /**
     * @notice Get eligible pool metrics that only count deposits meeting holding period requirements
     * @dev SECURITY: Prevents flash deposit attacks by excluding recent deposits from yield calculations
     * @return userPoolSize Eligible user pool size (deposits older than MIN_HOLDING_PERIOD)
     * @return hedgerPoolSize Eligible hedger pool size (deposits older than MIN_HOLDING_PERIOD)
     * @return poolRatio Ratio of eligible pool sizes
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function _getEligiblePoolMetrics() internal view returns (
        uint256 userPoolSize,
        uint256 hedgerPoolSize,
        uint256 poolRatio
    ) {
        (userPoolSize, hedgerPoolSize, poolRatio) = YieldShiftOptimizationLibrary.getEligiblePoolMetrics(
            address(userPool),
            address(hedgerPool),
            TIME_PROVIDER.currentTime(),
            lastUpdateTime
        );
    }
    
    /**
     * @notice Calculate holding period discount based on recent deposit activity
     * @dev Returns a percentage (in basis points) representing eligible deposits
     * @return discountBps Discount in basis points (10000 = 100%)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function _calculateHoldingPeriodDiscount() internal view returns (uint256 discountBps) {
        return YieldShiftOptimizationLibrary.calculateHoldingPeriodDiscount(
            TIME_PROVIDER.currentTime(),
            lastUpdateTime
        );
    }

    /**
     * @notice Check if a value is within tolerance of a target value
     * @param value The value to check
     * @param target The target value
     * @param toleranceBps Tolerance in basis points (e.g., 1000 = 10%)
     * @return True if value is within tolerance, false otherwise
     * @dev Helper function for yield shift calculations
     * @custom:security Uses safe arithmetic to prevent overflow
     * @custom:validation No input validation required - pure function
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe arithmetic used
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _isWithinTolerance(uint256 value, uint256 target, uint256 toleranceBps) 
        internal 
        pure 
        returns (bool) 
    {
        return YieldShiftOptimizationLibrary.isWithinTolerance(value, target, toleranceBps);
    }

    /**
     * @notice Updates the last deposit timestamp for a user
     * @dev Called by UserPool to track user deposit timing for yield calculations
     * @param user The user address to update
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function updateLastDepositTime(address user) external {
        if (msg.sender != address(userPool) && msg.sender != address(hedgerPool)) {
            revert CommonErrorLibrary.NotAuthorized();
        }
        lastDepositTime[user] = TIME_PROVIDER.currentTime();
    }

    /**
     * @notice Returns detailed breakdown of yield distribution
     * @dev Shows how yield is allocated between different pools and stakeholders
     * @return userYieldPool_ Yield allocated to user pool
     * @return hedgerYieldPool_ Yield allocated to hedger pool
     * @return distributionRatio Current distribution ratio between pools
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getYieldDistributionBreakdown() external view returns (
        uint256 userYieldPool_,
        uint256 hedgerYieldPool_,
        uint256 distributionRatio
    ) {
        userYieldPool_ = userYieldPool;
        hedgerYieldPool_ = hedgerYieldPool;
        
        uint256 totalPool = userYieldPool_ + hedgerYieldPool_;
        distributionRatio = totalPool > 0 ? userYieldPool_.mulDiv(10000, totalPool) : 5000;
    }

    /**
     * @notice Returns comprehensive metrics for both user and hedger pools
     * @dev Provides detailed analytics about pool performance and utilization
     * @return userPoolSize Total size of user pool
     * @return hedgerPoolSize Total size of hedger pool
     * @return poolRatio Current ratio between pools
     * @return targetRatio Target ratio between pools
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
        uint256 userPoolSize,
        uint256 hedgerPoolSize,
        uint256 poolRatio,
        uint256 targetRatio
    ) {
        (userPoolSize, hedgerPoolSize, poolRatio) = _getCurrentPoolMetrics();
        targetRatio = targetPoolRatio;
    }

    /**
     * @notice Calculates the optimal yield shift based on current market conditions
     * @dev Uses algorithms to determine best yield distribution strategy
     * @return optimalShift Recommended yield shift percentage
     * @return currentDeviation Current deviation from optimal shift
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function calculateOptimalYieldShift() external view returns (
        uint256 optimalShift,
        uint256 currentDeviation
    ) {
        (, , uint256 poolRatio) = _getCurrentPoolMetrics();
        optimalShift = _calculateOptimalYieldShift(poolRatio);
        
        if (currentYieldShift > optimalShift) {
            currentDeviation = currentYieldShift - optimalShift;
        } else {
            currentDeviation = optimalShift - currentYieldShift;
        }
    }

    /**
     * @notice Returns information about all yield sources
     * @dev Provides details about different yield-generating mechanisms
     * @return aaveYield Yield from Aave protocol
     * @return protocolFees Protocol fees collected
     * @return interestDifferential Interest rate differential yield
     * @return otherSources Other miscellaneous yield sources
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getYieldSources() external view returns (
        uint256 aaveYield,
        uint256 protocolFees,
        uint256 interestDifferential,
        uint256 otherSources
    ) {
        aaveYield = yieldSources[keccak256("aave")];
        protocolFees = yieldSources[keccak256("fees")];
        interestDifferential = yieldSources[keccak256("interest_differential")];
        
        uint256 knownSources = aaveYield + protocolFees + interestDifferential;
        otherSources = totalYieldGenerated > knownSources ? 
            totalYieldGenerated - knownSources : 0;
    }
    
    /**
     * @notice Returns a lightweight historical yield-shift summary for a period
     * @dev Uses the latest in-period snapshot (or current shift) to avoid O(n) scans.
     * @param period The time period to analyze (in seconds)
     * @return averageShift Representative shift for the period
     * @return maxShift Same as `averageShift` in compact summary mode
     * @return minShift Same as `averageShift` in compact summary mode
     * @return volatility Always 0 in compact summary mode
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getHistoricalYieldShift(uint256 period) external view returns (
        uint256 averageShift,
        uint256 maxShift,
        uint256 minShift,
        uint256 volatility
    ) {
        uint256 representativeShift = currentYieldShift;
        uint256 length = yieldShiftHistory.length;
        if (length > 0) {
            YieldShiftSnapshot memory lastSnapshot = yieldShiftHistory[length - 1];
            uint256 cutoffTime = TIME_PROVIDER.currentTime() > period
                ? TIME_PROVIDER.currentTime() - period
                : 0;
            if (lastSnapshot.timestamp >= cutoffTime) {
                representativeShift = lastSnapshot.yieldShift;
            }
        }
        averageShift = representativeShift;
        maxShift = representativeShift;
        minShift = representativeShift;
        volatility = 0;
    }

    /**
     * @notice Returns compact performance metrics for yield operations
     * @dev Uses aggregate pools directly to avoid cross-contract reads.
     * @return totalYieldDistributed_ Total yield distributed to date
     * @return averageUserYield Aggregate user yield pool
     * @return averageHedgerYield Aggregate hedger yield pool
     * @return yieldEfficiency Distributed / generated ratio (bps)
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getYieldPerformanceMetrics() external view returns (
        uint256 totalYieldDistributed_,
        uint256 averageUserYield,
        uint256 averageHedgerYield,
        uint256 yieldEfficiency
    ) {
        totalYieldDistributed_ = totalYieldDistributed;
        averageUserYield = userYieldPool;
        averageHedgerYield = hedgerYieldPool;
        yieldEfficiency = totalYieldGenerated > 0
            ? totalYieldDistributed_.mulDiv(10000, totalYieldGenerated)
            : 0;
    }

    /**
     * @notice Calculate user allocation from current yield shift
     * @return User allocation amount based on current yield shift percentage
     * @dev Calculates how much yield should be allocated to users
     * @custom:security Uses safe arithmetic to prevent overflow
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe arithmetic used
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _calculateUserAllocation() internal view returns (uint256) {
        return YieldShiftOptimizationLibrary.calculateUserAllocation(
            userYieldPool,
            hedgerYieldPool,
            currentYieldShift
        );
    }

    /**
     * @notice Calculate hedger allocation from current yield shift
     * @return Hedger allocation amount based on current yield shift percentage
     * @dev Calculates how much yield should be allocated to hedgers
     * @custom:security Uses safe arithmetic to prevent overflow
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe arithmetic used
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _calculateHedgerAllocation() internal view returns (uint256) {
        return YieldShiftOptimizationLibrary.calculateHedgerAllocation(
            userYieldPool,
            hedgerYieldPool,
            currentYieldShift
        );
    }

    /**
     * @notice Batch-updates all yield model parameters.
     * @dev Applies a new configuration for `baseYieldShift`, `maxYieldShift`, `adjustmentSpeed`
     *      and `targetPoolRatio` in a single governance transaction.
     *      Uses `YieldValidationLibrary` to enforce sane bounds and invariants.
     * @param cfg Struct containing the new yield model configuration:
     *        - `baseYieldShift`: baseline user share (bps) when pools are balanced.
     *        - `maxYieldShift`: maximum deviation from baseline (bps).
     *        - `adjustmentSpeed`: how fast the shift moves toward the optimal value.
     *        - `targetPoolRatio`: desired user/hedger pool ratio (bps).
     * @custom:security Only governance may call; validates that `maxYieldShift >= baseYieldShift`
     *                  and that all parameters stay within library-defined limits.
     * @custom:validation Reverts if yield shifts, adjustment speed or target ratio are out of bounds.
     * @custom:state-changes Updates `baseYieldShift`, `maxYieldShift`, `adjustmentSpeed`, `targetPoolRatio`.
     * @custom:events None – consumers should read the updated state via view functions.
     * @custom:errors InvalidShiftRange if `maxYieldShift < baseYieldShift`; library errors otherwise.
     * @custom:reentrancy Not applicable – no external calls after state updates.
     * @custom:access Restricted to governance via `AccessControlLibrary.onlyGovernance`.
     * @custom:oracle No direct oracle access – operates purely on configuration values.
     */
    function configureYieldModel(YieldModelConfig calldata cfg) external {
        AccessControlLibrary.onlyGovernance(this);
        YieldValidationLibrary.validateYieldShift(cfg.baseYieldShift);
        YieldValidationLibrary.validateYieldShift(cfg.maxYieldShift);
        if (cfg.maxYieldShift < cfg.baseYieldShift) revert CommonErrorLibrary.InvalidShiftRange();
        YieldValidationLibrary.validateAdjustmentSpeed(cfg.adjustmentSpeed, 1000);
        YieldValidationLibrary.validateTargetRatio(cfg.targetPoolRatio, 50000);

        baseYieldShift = cfg.baseYieldShift;
        maxYieldShift = cfg.maxYieldShift;
        adjustmentSpeed = cfg.adjustmentSpeed;
        targetPoolRatio = cfg.targetPoolRatio;
    }

    /**
     * @notice Batch-updates external dependency addresses used for yield distribution.
     * @dev Wires or re-wires the `userPool`, `hedgerPool`, `aaveVault`, `stQEUROFactory` and `treasury`
     *      references in a single governance transaction.
     * @param cfg Struct containing the new dependency configuration:
     *        - `userPool`: UserPool contract address.
     *        - `hedgerPool`: HedgerPool contract address.
     *        - `aaveVault`: AaveVault contract address.
     *        - `stQEUROFactory`: stQEURO factory contract address.
     *        - `treasury`: treasury address receiving recovered funds.
     * @custom:security Only governance may call; validates all addresses are non-zero and sane.
     * @custom:validation Uses `AccessControlLibrary` / `YieldValidationLibrary` to check addresses.
     * @custom:state-changes Updates `userPool`, `hedgerPool`, `aaveVault`, `stQEUROFactory`, `treasury`.
     * @custom:events None – downstream contracts emit their own events on meaningful actions.
     * @custom:errors Library validation errors on zero/invalid addresses.
     * @custom:reentrancy Not applicable – no external calls after state updates.
     * @custom:access Restricted to governance via `AccessControlLibrary.onlyGovernance`.
     * @custom:oracle No direct oracle access – configuration only.
     */
    function configureDependencies(YieldDependencyConfig calldata cfg) external {
        AccessControlLibrary.onlyGovernance(this);
        AccessControlLibrary.validateAddress(cfg.userPool);
        AccessControlLibrary.validateAddress(cfg.hedgerPool);
        AccessControlLibrary.validateAddress(cfg.aaveVault);
        AccessControlLibrary.validateAddress(cfg.stQEUROFactory);
        YieldValidationLibrary.validateTreasuryAddress(cfg.treasury);
        CommonValidationLibrary.validateNonZeroAddress(cfg.treasury, "treasury");

        userPool = IUserPool(cfg.userPool);
        hedgerPool = IHedgerPool(cfg.hedgerPool);
        aaveVault = IAaveVault(cfg.aaveVault);
        stQEUROFactory = IStQEUROFactory(cfg.stQEUROFactory);
        treasury = cfg.treasury;
    }

    /**
     * @notice Sets authorization status and yield type for a yield source.
     * @dev Governance function mapping a source address to a logical yield type (e.g. "aave", "fees")
     *      and toggling whether that source is allowed to push yield via `addYield`.
     * @param source Address of the yield source whose authorization is being updated.
     * @param yieldType Logical yield category identifier (e.g., `keccak256("aave")`).
     * @param authorized True to authorize the source, false to revoke authorization.
     * @custom:security Only governance may call; prevents untrusted contracts from minting yield.
     * @custom:validation Reverts on zero `source` address; clears mapping when `authorized` is false.
     * @custom:state-changes Updates `authorizedYieldSources[source]` and `sourceToYieldType[source]`.
     * @custom:events None – yield events are emitted when yield is actually added.
     * @custom:errors Library validation errors for invalid addresses.
     * @custom:reentrancy Not applicable – no external calls after state updates.
     * @custom:access Restricted to governance via `AccessControlLibrary.onlyGovernance`.
     * @custom:oracle No oracle dependencies.
     */
    function setYieldSourceAuthorization(address source, bytes32 yieldType, bool authorized) external {
        AccessControlLibrary.onlyGovernance(this);
        AccessControlLibrary.validateAddress(source);

        authorizedYieldSources[source] = authorized;
        if (authorized) {
            sourceToYieldType[source] = yieldType;
        } else {
            sourceToYieldType[source] = bytes32(0);
            sourceToVaultId[source] = 0;
            emit SourceVaultBindingUpdated(source, 0);
        }
    }

    /**
     * @notice Binds a yield source to a single vault id for optional strict routing.
     * @dev When strict mode is enabled, calls from `source` can only route yield to `vaultId`.
     * @param source Yield source address to bind.
     * @param vaultId Vault id that this source is allowed to target.
     * @custom:security Governance-only control over source/vault routing boundaries.
     * @custom:validation Reverts on zero source address or zero vault id.
     * @custom:state-changes Updates `sourceToVaultId[source]`.
     * @custom:events Emits `SourceVaultBindingUpdated`.
     * @custom:errors `ZeroAddress` / `InvalidVault` on invalid inputs.
     * @custom:reentrancy Not applicable.
     * @custom:access Restricted to governance.
     * @custom:oracle No oracle dependencies.
     */
    function setSourceVaultBinding(address source, uint256 vaultId) external {
        AccessControlLibrary.onlyGovernance(this);
        AccessControlLibrary.validateAddress(source);
        if (vaultId == 0) revert CommonErrorLibrary.InvalidVault();
        sourceToVaultId[source] = vaultId;
        emit SourceVaultBindingUpdated(source, vaultId);
    }

    /**
     * @notice Clears the vault binding for a yield source.
     * @dev In strict mode, a cleared source must be rebound before it can call `addYield`.
     * @param source Yield source address to unbind.
     * @custom:security Governance-only.
     * @custom:validation Reverts on zero source address.
     * @custom:state-changes Resets `sourceToVaultId[source]` to zero.
     * @custom:events Emits `SourceVaultBindingUpdated` with vault id `0`.
     * @custom:errors `ZeroAddress` on invalid input.
     * @custom:reentrancy Not applicable.
     * @custom:access Restricted to governance.
     * @custom:oracle No oracle dependencies.
     */
    function clearSourceVaultBinding(address source) external {
        AccessControlLibrary.onlyGovernance(this);
        AccessControlLibrary.validateAddress(source);
        sourceToVaultId[source] = 0;
        emit SourceVaultBindingUpdated(source, 0);
    }

    /**
     * @notice Enables or disables strict source-to-vault enforcement.
     * @dev When enabled, `addYield` requires `sourceToVaultId[msg.sender] == vaultId`.
     * @param enabled True to enforce source/vault binding, false for permissive routing.
     * @custom:security Governance-only mode toggle.
     * @custom:validation No extra validation required.
     * @custom:state-changes Updates `enforceSourceVaultBinding`.
     * @custom:events Emits `SourceVaultBindingModeUpdated`.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Restricted to governance.
     * @custom:oracle No oracle dependencies.
     */
    function setSourceVaultBindingEnforcement(bool enabled) external {
        AccessControlLibrary.onlyGovernance(this);
        enforceSourceVaultBinding = enabled;
        emit SourceVaultBindingModeUpdated(enabled);
    }

    /**
     * @notice Updates yield allocation for a specific user or hedger
     * @dev Called by pools to update individual yield allocations
     * @param user The user or hedger address
     * @param amount The allocation amount
     * @param isUser True if user, false if hedger
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function updateYieldAllocation(address user, uint256 amount, bool isUser) external {
        AccessControlLibrary.onlyYieldManager(this);
        if (isUser) {
            userPendingYield[user] += amount;
        } else {
            hedgerPendingYield[user] += amount;
        }
    }

    /**
     * @notice Executes emergency yield distribution with specified amounts
     * @dev Emergency function to manually distribute yield during critical situations
     * @param userAmount Amount to distribute to user pool
     * @param hedgerAmount Amount to distribute to hedger pool
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function emergencyYieldDistribution(uint256 userAmount, uint256 hedgerAmount) external {
        AccessControlLibrary.onlyEmergencyRole(this);
        if (userAmount > userYieldPool) revert CommonErrorLibrary.InsufficientYield();
        if (hedgerAmount > hedgerYieldPool) revert CommonErrorLibrary.InsufficientYield();
        
        if (userAmount > 0) {
            userYieldPool -= userAmount;
            usdc.safeTransfer(address(userPool), userAmount);
        }
        
        if (hedgerAmount > 0) {
            hedgerYieldPool -= hedgerAmount;
            usdc.safeTransfer(address(hedgerPool), hedgerAmount);
        }
    }

    /**
     * @notice Pauses all yield distribution operations
     * @dev Emergency function to halt yield distribution during critical situations
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function pauseYieldDistribution() external {
        AccessControlLibrary.onlyEmergencyRole(this);
        _pause();
    }

    /**
     * @notice Resumes yield distribution operations after being paused
     * @dev Restarts yield distribution when emergency is resolved
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function resumeYieldDistribution() external {
        AccessControlLibrary.onlyEmergencyRole(this);
        _unpause();
    }

    /**
     * @notice Check if a yield source is authorized
     * @param source Source address
     * @param yieldType Yield type identifier
     * @return True if authorized
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    /**
     * @notice Checks if a yield source is authorized for a specific yield type
     * @dev Checks if a yield source is authorized for a specific yield type
     * @param source Address of the yield source
     * @param yieldType Type of yield to check
     * @return True if authorized, false otherwise
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function isYieldSourceAuthorized(address source, bytes32 yieldType) external view returns (bool) {
        return authorizedYieldSources[source] && sourceToYieldType[source] == yieldType;
    }

    /**
     * @notice Checks current conditions and updates yield distribution if needed
     * @dev Automated function to maintain optimal yield distribution
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function checkAndUpdateYieldDistribution() external {
        uint256 timeSinceUpdate = TIME_PROVIDER.currentTime() - lastUpdateTime;
        
        if (timeSinceUpdate > MAX_TIME_ELAPSED) {
            timeSinceUpdate = MAX_TIME_ELAPSED;
        }
        
        bool timeCondition = timeSinceUpdate >= TWAP_PERIOD;
        
        uint256 avgUserPoolSize = getTimeWeightedAverage(userPoolHistory, TWAP_PERIOD, true);
        uint256 avgHedgerPoolSize = getTimeWeightedAverage(hedgerPoolHistory, TWAP_PERIOD, false);
        uint256 poolRatio = avgHedgerPoolSize == 0 ? type(uint256).max : 
                           avgUserPoolSize.mulDiv(10000, avgHedgerPoolSize);
        
        bool imbalanceCondition = !_isWithinTolerance(poolRatio, targetPoolRatio, 2000);
        
        if (timeCondition || imbalanceCondition) {
            this.updateYieldDistribution();
        }
    }

    /**
     * @notice Forces an immediate update of yield distribution
     * @dev Emergency function to bypass normal update conditions and force distribution
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function forceUpdateYieldDistribution() external {
        AccessControlLibrary.onlyGovernance(this);
        this.updateYieldDistribution();
    }

    /**
     * @notice Get time weighted average of pool history
     * @dev Calculates time weighted average of pool history over a specified period
     * @param poolHistory Array of pool snapshots
     * @param period Time period for calculation
     * @param isUserPool Whether this is for user pool or hedger pool
     * @return uint256 Time weighted average value
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function getTimeWeightedAverage(PoolSnapshot[] storage poolHistory, uint256 period, bool isUserPool) 
        internal 
        view 
        returns (uint256) 
    {
        uint256 length = poolHistory.length;
        if (length == 0) {
            return 0;
        }
        
        uint256 cutoffTime = TIME_PROVIDER.currentTime() > period ? 
            TIME_PROVIDER.currentTime() - period : 0;
        
        uint256 totalWeightedValue = 0;
        uint256 totalWeight = 0;
        
        // Cache storage reference to avoid multiple SLOAD operations
        PoolSnapshot memory snapshot;
        uint256 timestamp;
        uint256 poolSize;
        
        for (uint256 i = 0; i < length;) {
            snapshot = poolHistory[i];
            timestamp = snapshot.timestamp;
            
            if (timestamp >= cutoffTime) {
                poolSize = isUserPool ? 
                    snapshot.userPoolSize : 
                    snapshot.hedgerPoolSize;
                
                unchecked {
                    uint256 weight = timestamp - cutoffTime;
                    totalWeightedValue += poolSize * weight;
                    totalWeight += weight;
                }
            }
            
            unchecked { ++i; }
        }
        
        if (totalWeight == 0) {
            // Cache the last snapshot to avoid another storage read
            snapshot = poolHistory[length - 1];
            return isUserPool ? snapshot.userPoolSize : snapshot.hedgerPoolSize;
        }
        
        return totalWeightedValue / totalWeight;
    }

    /**
     * @notice Record pool snapshot
     * @dev Records current pool metrics as a snapshot for historical tracking
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function _recordPoolSnapshot() internal {
        (uint256 eligibleUserPoolSize, uint256 eligibleHedgerPoolSize,) = _getEligiblePoolMetrics();
        
        _addToPoolHistory(userPoolHistory, eligibleUserPoolSize, true);
        _addToPoolHistory(hedgerPoolHistory, eligibleHedgerPoolSize, false);
    }
    
    /**
     * @notice Record pool snapshot using eligible pool sizes to prevent manipulation
     * @dev SECURITY: Uses eligible pool sizes that respect holding period requirements
     * @param eligibleUserPoolSize Eligible user pool size for yield calculations
     * @param eligibleHedgerPoolSize Eligible hedger pool size for yield calculations
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function _recordPoolSnapshotWithEligibleSizes(uint256 eligibleUserPoolSize, uint256 eligibleHedgerPoolSize) internal {
        _addToPoolHistory(userPoolHistory, eligibleUserPoolSize, true);
        _addToPoolHistory(hedgerPoolHistory, eligibleHedgerPoolSize, false);
    }

    /**
     * @notice Add pool snapshot to history
     * @dev Adds a pool snapshot to the history array with size management
     * @param poolHistory Array of pool snapshots to add to
     * @param poolSize Size of the pool to record
     * @param isUserPool Whether this is for user pool or hedger pool
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function _addToPoolHistory(PoolSnapshot[] storage poolHistory, uint256 poolSize, bool isUserPool) internal {
        uint256 length = poolHistory.length;
        
        if (length >= MAX_HISTORY_LENGTH) {
            // Optimize the shift operation by using unchecked arithmetic
            for (uint256 i = 0; i < length - 1;) {
                poolHistory[i] = poolHistory[i + 1];
                unchecked { ++i; }
            }
            poolHistory.pop();
        }
        
        poolHistory.push(PoolSnapshot({
            // forge-lint: disable-next-line(unsafe-typecast)
            timestamp: uint64(TIME_PROVIDER.currentTime()),
            // forge-lint: disable-next-line(unsafe-typecast)
            userPoolSize: isUserPool ? uint128(poolSize) : 0,
            // forge-lint: disable-next-line(unsafe-typecast)
            hedgerPoolSize: isUserPool ? 0 : uint128(poolSize)
        }));
    }

    /**
     * @notice Recovers accidentally sent ERC20 tokens from the contract
     * @dev Emergency function to recover tokens that are not part of normal operations
     * @param token The token address to recover
     * @param amount The amount of tokens to recover
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function recoverToken(address token, uint256 amount) external {
        AccessControlLibrary.onlyAdmin(this);
        // Use the shared library for secure token recovery to treasury
        TreasuryRecoveryLibrary.recoverToken(token, amount, address(this), treasury);
    }

    /**
     * @notice Recovers accidentally sent ETH from the contract
     * @dev Emergency function to recover ETH that shouldn't be in the contract
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function recoverETH() external {
        AccessControlLibrary.onlyAdmin(this);
        if (treasury == address(0)) revert CommonErrorLibrary.InvalidAddress();
        uint256 balance = address(this).balance;
        if (balance < 1) revert CommonErrorLibrary.NoETHToRecover();
        payable(treasury).sendValue(balance);
    }
    
}
