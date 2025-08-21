// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IChainlinkOracle.sol";
import "../interfaces/IYieldShift.sol";
import "../libraries/VaultMath.sol";

/**
 * @title HedgerPool
 * @notice Manages EUR/USD hedging positions, margin, and hedger rewards
 * @dev Handles the hedger side of the dual-pool mechanism
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract HedgerPool is 
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
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // =============================================================================
    // STATE VARIABLES
    // =============================================================================
    
    /// @notice USDC token contract
    IERC20 public usdc;
    
    /// @notice Price oracle contract
    IChainlinkOracle public oracle;
    
    /// @notice Yield shift mechanism
    IYieldShift public yieldShift;

    // Pool configuration
    uint256 public minMarginRatio;          // Minimum margin ratio (e.g., 10% = 1000 bps)
    uint256 public liquidationThreshold;    // Liquidation threshold (e.g., 5% = 500 bps)
    uint256 public maxLeverage;             // Maximum allowed leverage (e.g., 10x)
    uint256 public liquidationPenalty;      // Liquidation penalty (e.g., 2% = 200 bps)
    
    // Fee configuration
    uint256 public entryFee;                // Fee for entering positions (bps)
    uint256 public exitFee;                 // Fee for exiting positions (bps)
    uint256 public marginFee;               // Fee for margin operations (bps)

    // Pool state
    uint256 public totalMargin;             // Total margin across all positions
    uint256 public totalExposure;           // Total EUR/USD exposure
    uint256 public activeHedgers;           // Number of active hedgers
    uint256 public nextPositionId;          // Next position ID counter

    // Interest rate differential (EUR/USD)
    uint256 public eurInterestRate;         // EUR interest rate (bps)
    uint256 public usdInterestRate;         // USD interest rate (bps)

    // Position data structure
    struct HedgePosition {
        address hedger;                     // Hedger address
        uint256 positionSize;               // Position size in QEURO equivalent
        uint256 margin;                     // Current margin in USDC
        uint256 entryPrice;                 // EUR/USD price when opened
        uint256 leverage;                   // Position leverage
        uint256 entryTime;                  // Position creation timestamp
        uint256 lastUpdateTime;             // Last update timestamp
        int256 unrealizedPnL;               // Current unrealized P&L
        bool isActive;                      // Position status
    }

    // Hedger data structure
    struct HedgerInfo {
        uint256[] positionIds;              // Array of position IDs
        uint256 totalMargin;                // Total margin across positions
        uint256 totalExposure;              // Total exposure across positions
        uint256 pendingRewards;             // Pending hedging rewards
        uint256 lastRewardClaim;            // Last reward claim timestamp
        bool isActive;                      // Hedger status
    }

    mapping(uint256 => HedgePosition) public positions;
    mapping(address => HedgerInfo) public hedgers;
    mapping(address => uint256[]) public hedgerPositions;

    // Yield tracking
    uint256 public totalYieldEarned;        // Total yield earned by hedgers
    uint256 public interestDifferentialPool; // Pool of interest differential rewards

    // =============================================================================
    // EVENTS
    // =============================================================================
    
    event HedgePositionOpened(
        address indexed hedger,
        uint256 indexed positionId,
        uint256 positionSize,
        uint256 margin,
        uint256 leverage,
        uint256 entryPrice
    );
    
    event HedgePositionClosed(
        address indexed hedger,
        uint256 indexed positionId,
        uint256 exitPrice,
        int256 pnl,
        uint256 timestamp
    );
    
    event MarginAdded(
        address indexed hedger,
        uint256 indexed positionId,
        uint256 marginAdded,
        uint256 newMarginRatio
    );
    
    event MarginRemoved(
        address indexed hedger,
        uint256 indexed positionId,
        uint256 marginRemoved,
        uint256 newMarginRatio
    );
    
    event HedgerLiquidated(
        address indexed hedger,
        uint256 indexed positionId,
        address indexed liquidator,
        uint256 liquidationReward,
        uint256 remainingMargin
    );
    
    event HedgingRewardsClaimed(
        address indexed hedger,
        uint256 interestDifferential,
        uint256 yieldShiftRewards,
        uint256 totalRewards
    );

    // =============================================================================
    // INITIALIZER
    // =============================================================================

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin,
        address _usdc,
        address _oracle,
        address _yieldShift
    ) public initializer {
        require(admin != address(0), "HedgerPool: Admin cannot be zero");
        require(_usdc != address(0), "HedgerPool: USDC cannot be zero");
        require(_oracle != address(0), "HedgerPool: Oracle cannot be zero");
        require(_yieldShift != address(0), "HedgerPool: YieldShift cannot be zero");

        __ReentrancyGuard_init();
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        usdc = IERC20(_usdc);
        oracle = IChainlinkOracle(_oracle);
        yieldShift = IYieldShift(_yieldShift);

        // Default parameters
        minMarginRatio = 1000;          // 10% minimum margin
        liquidationThreshold = 500;     // 5% liquidation threshold
        maxLeverage = 10;               // 10x maximum leverage
        liquidationPenalty = 200;       // 2% liquidation penalty
        
        entryFee = 20;                  // 0.2% entry fee
        exitFee = 20;                   // 0.2% exit fee
        marginFee = 10;                 // 0.1% margin fee

        // Default interest rates (updated by governance)
        eurInterestRate = 350;          // 3.5% EUR rate
        usdInterestRate = 450;          // 4.5% USD rate

        nextPositionId = 1;
    }

    // =============================================================================
    // CORE HEDGING FUNCTIONS
    // =============================================================================

    /**
     * @notice Enter a new EUR/USD hedging position (short EUR/USD)
     */
    function enterHedgePosition(uint256 usdcAmount, uint256 leverage) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256 positionId) 
    {
        require(usdcAmount > 0, "HedgerPool: Amount must be positive");
        require(leverage <= maxLeverage, "HedgerPool: Leverage too high");
        require(leverage > 0, "HedgerPool: Leverage must be positive");

        // Get current EUR/USD price
        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "HedgerPool: Invalid EUR/USD price");

        // Calculate entry fee
        uint256 fee = usdcAmount.percentageOf(entryFee);
        uint256 netMargin = usdcAmount - fee;

        // Calculate position size based on leverage
        uint256 positionSize = netMargin.mulDiv(leverage, 1);

        // Validate margin ratio
        uint256 marginRatio = netMargin.mulDiv(10000, positionSize);
        require(marginRatio >= minMarginRatio, "HedgerPool: Insufficient margin ratio");

        // Transfer USDC from hedger
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);

        // Create new position
        positionId = nextPositionId++;
        
        HedgePosition storage position = positions[positionId];
        position.hedger = msg.sender;
        position.positionSize = positionSize;
        position.margin = netMargin;
        position.entryPrice = eurUsdPrice;
        position.leverage = leverage;
        position.entryTime = block.timestamp;
        position.lastUpdateTime = block.timestamp;
        position.unrealizedPnL = 0;
        position.isActive = true;

        // Update hedger info
        HedgerInfo storage hedger = hedgers[msg.sender];
        if (!hedger.isActive) {
            hedger.isActive = true;
            activeHedgers++;
        }
        
        hedger.positionIds.push(positionId);
        hedger.totalMargin += netMargin;
        hedger.totalExposure += positionSize;
        hedgerPositions[msg.sender].push(positionId);

        // Update pool totals
        totalMargin += netMargin;
        totalExposure += positionSize;

        emit HedgePositionOpened(
            msg.sender,
            positionId,
            positionSize,
            netMargin,
            leverage,
            eurUsdPrice
        );
    }

    /**
     * @notice Exit an existing hedging position
     */
    function exitHedgePosition(uint256 positionId) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (int256 pnl) 
    {
        HedgePosition storage position = positions[positionId];
        require(position.hedger == msg.sender, "HedgerPool: Not position owner");
        require(position.isActive, "HedgerPool: Position not active");

        // Get current EUR/USD price
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "HedgerPool: Invalid EUR/USD price");

        // Calculate P&L (short position benefits from EUR/USD decline)
        pnl = _calculatePnL(position, currentPrice);

        // Calculate exit fee
        uint256 grossPayout = uint256(int256(position.margin) + pnl);
        uint256 exitFeeAmount = grossPayout.percentageOf(exitFee);
        uint256 netPayout = grossPayout - exitFeeAmount;

        // Update hedger info
        HedgerInfo storage hedger = hedgers[msg.sender];
        hedger.totalMargin -= position.margin;
        hedger.totalExposure -= position.positionSize;

        // Update pool totals
        totalMargin -= position.margin;
        totalExposure -= position.positionSize;

        // Deactivate position
        position.isActive = false;

        // Transfer payout to hedger
        if (netPayout > 0) {
            usdc.safeTransfer(msg.sender, netPayout);
        }

        emit HedgePositionClosed(msg.sender, positionId, currentPrice, pnl, block.timestamp);
    }

    /**
     * @notice Partially close a hedging position
     */
    function partialClosePosition(uint256 positionId, uint256 percentage) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (int256 pnl) 
    {
        require(percentage > 0 && percentage <= 10000, "HedgerPool: Invalid percentage");
        
        HedgePosition storage position = positions[positionId];
        require(position.hedger == msg.sender, "HedgerPool: Not position owner");
        require(position.isActive, "HedgerPool: Position not active");

        // Get current EUR/USD price
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "HedgerPool: Invalid EUR/USD price");

        // Calculate partial amounts
        uint256 partialSize = position.positionSize.percentageOf(percentage);
        uint256 partialMargin = position.margin.percentageOf(percentage);

        // Calculate P&L for partial position
        pnl = _calculatePnL(position, currentPrice);
        int256 partialPnL = pnl * int256(percentage) / 10000;

        // Calculate payout
        uint256 grossPayout = uint256(int256(partialMargin) + partialPnL);
        uint256 exitFeeAmount = grossPayout.percentageOf(exitFee);
        uint256 netPayout = grossPayout - exitFeeAmount;

        // Update position
        position.positionSize -= partialSize;
        position.margin -= partialMargin;

        // Update hedger info
        HedgerInfo storage hedger = hedgers[msg.sender];
        hedger.totalMargin -= partialMargin;
        hedger.totalExposure -= partialSize;

        // Update pool totals
        totalMargin -= partialMargin;
        totalExposure -= partialSize;

        // Transfer payout to hedger
        if (netPayout > 0) {
            usdc.safeTransfer(msg.sender, netPayout);
        }

        pnl = partialPnL;
    }

    // =============================================================================
    // MARGIN MANAGEMENT
    // =============================================================================

    /**
     * @notice Add margin to an existing position
     */
    function addMargin(uint256 positionId, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        HedgePosition storage position = positions[positionId];
        require(position.hedger == msg.sender, "HedgerPool: Not position owner");
        require(position.isActive, "HedgerPool: Position not active");
        require(amount > 0, "HedgerPool: Amount must be positive");

        // Calculate margin fee
        uint256 fee = amount.percentageOf(marginFee);
        uint256 netAmount = amount - fee;

        // Transfer USDC from hedger
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        // Update position margin
        position.margin += netAmount;

        // Update hedger and pool totals
        hedgers[msg.sender].totalMargin += netAmount;
        totalMargin += netAmount;

        // Calculate new margin ratio
        uint256 newMarginRatio = position.margin.mulDiv(10000, position.positionSize);

        emit MarginAdded(msg.sender, positionId, netAmount, newMarginRatio);
    }

    /**
     * @notice Remove excess margin from a position
     */
    function removeMargin(uint256 positionId, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        HedgePosition storage position = positions[positionId];
        require(position.hedger == msg.sender, "HedgerPool: Not position owner");
        require(position.isActive, "HedgerPool: Position not active");
        require(amount > 0, "HedgerPool: Amount must be positive");
        require(position.margin >= amount, "HedgerPool: Insufficient margin");

        // Check if removal maintains minimum margin ratio
        uint256 newMargin = position.margin - amount;
        uint256 newMarginRatio = newMargin.mulDiv(10000, position.positionSize);
        require(newMarginRatio >= minMarginRatio, "HedgerPool: Would breach minimum margin");

        // Update position margin
        position.margin = newMargin;

        // Update hedger and pool totals
        hedgers[msg.sender].totalMargin -= amount;
        totalMargin -= amount;

        // Transfer USDC to hedger
        usdc.safeTransfer(msg.sender, amount);

        emit MarginRemoved(msg.sender, positionId, amount, newMarginRatio);
    }

    // =============================================================================
    // LIQUIDATION SYSTEM
    // =============================================================================

    /**
     * @notice Liquidate an undercollateralized hedger position
     */
    function liquidateHedger(address hedger, uint256 positionId) 
        external 
        onlyRole(LIQUIDATOR_ROLE) 
        nonReentrant 
        returns (uint256 liquidationReward) 
    {
        HedgePosition storage position = positions[positionId];
        require(position.hedger == hedger, "HedgerPool: Invalid hedger");
        require(position.isActive, "HedgerPool: Position not active");
        require(_isPositionLiquidatable(positionId), "HedgerPool: Position not liquidatable");

        // Get current EUR/USD price
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "HedgerPool: Invalid EUR/USD price");

        // Calculate liquidation reward
        liquidationReward = position.margin.percentageOf(liquidationPenalty);
        uint256 remainingMargin = position.margin - liquidationReward;

        // Update hedger info
        HedgerInfo storage hedgerInfo = hedgers[hedger];
        hedgerInfo.totalMargin -= position.margin;
        hedgerInfo.totalExposure -= position.positionSize;

        // Update pool totals
        totalMargin -= position.margin;
        totalExposure -= position.positionSize;

        // Deactivate position
        position.isActive = false;

        // Transfer liquidation reward to liquidator
        usdc.safeTransfer(msg.sender, liquidationReward);

        // Return remaining margin to hedger if any
        if (remainingMargin > 0) {
            usdc.safeTransfer(hedger, remainingMargin);
        }

        emit HedgerLiquidated(hedger, positionId, msg.sender, liquidationReward, remainingMargin);
    }

    // =============================================================================
    // YIELD AND REWARDS
    // =============================================================================

    /**
     * @notice Claim hedging rewards (interest differential + yield shift)
     */
    function claimHedgingRewards(address hedger) 
        external 
        nonReentrant 
        returns (uint256 totalRewards) 
    {
        require(msg.sender == hedger || hasRole(GOVERNANCE_ROLE, msg.sender), "HedgerPool: Unauthorized");
        
        HedgerInfo storage hedgerInfo = hedgers[hedger];
        
        // Update pending rewards
        _updateHedgerRewards(hedger);
        
        uint256 interestRewards = hedgerInfo.pendingRewards;
        uint256 yieldShiftRewards = yieldShift.getHedgerPendingYield(hedger);
        
        totalRewards = interestRewards + yieldShiftRewards;
        
        if (totalRewards > 0) {
            hedgerInfo.pendingRewards = 0;
            hedgerInfo.lastRewardClaim = block.timestamp;
            
            // Claim yield shift rewards
            if (yieldShiftRewards > 0) {
                yieldShift.claimHedgerYield(hedger);
            }
            
            // Transfer USDC rewards
            usdc.safeTransfer(hedger, totalRewards);
            
            emit HedgingRewardsClaimed(hedger, interestRewards, yieldShiftRewards, totalRewards);
        }
    }

    /**
     * @notice Update hedger rewards based on interest rate differential
     */
    function _updateHedgerRewards(address hedger) internal {
        HedgerInfo storage hedgerInfo = hedgers[hedger];
        
        if (hedgerInfo.totalExposure > 0) {
            uint256 timeElapsed = block.timestamp - hedgerInfo.lastRewardClaim;
            
            // Calculate interest differential reward
            // Hedgers earn the difference between USD and EUR rates
            uint256 interestDifferential = usdInterestRate > eurInterestRate ? 
                usdInterestRate - eurInterestRate : 0;
            
            uint256 reward = hedgerInfo.totalExposure
                .mulDiv(interestDifferential, 10000)
                .mulDiv(timeElapsed, 365 days);
            
            hedgerInfo.pendingRewards += reward;
        }
    }

    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================

    function getHedgerPosition(address hedger, uint256 positionId) 
        external 
        view 
        returns (
            uint256 positionSize,
            uint256 margin,
            uint256 entryPrice,
            uint256 currentPrice,
            uint256 leverage,
            uint256 lastUpdateTime
        ) 
    {
        HedgePosition storage position = positions[positionId];
        require(position.hedger == hedger, "HedgerPool: Invalid hedger");
        
        (currentPrice, ) = oracle.getEurUsdPrice();
        
        return (
            position.positionSize,
            position.margin,
            position.entryPrice,
            currentPrice,
            position.leverage,
            position.lastUpdateTime
        );
    }

    function getHedgerMarginRatio(address hedger, uint256 positionId) 
        external 
        view 
        returns (uint256) 
    {
        HedgePosition storage position = positions[positionId];
        require(position.hedger == hedger, "HedgerPool: Invalid hedger");
        
        if (position.positionSize == 0) return 0;
        return position.margin.mulDiv(10000, position.positionSize);
    }

    function isHedgerLiquidatable(address hedger, uint256 positionId) 
        external 
        view 
        returns (bool) 
    {
        HedgePosition storage position = positions[positionId];
        require(position.hedger == hedger, "HedgerPool: Invalid hedger");
        
        return _isPositionLiquidatable(positionId);
    }

    function _isPositionLiquidatable(uint256 positionId) internal view returns (bool) {
        HedgePosition storage position = positions[positionId];
        if (!position.isActive) return false;
        
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) return false;
        
        // Calculate current margin ratio including unrealized P&L
        int256 pnl = _calculatePnL(position, currentPrice);
        int256 effectiveMargin = int256(position.margin) + pnl;
        
        if (effectiveMargin <= 0) return true;
        
        uint256 marginRatio = uint256(effectiveMargin).mulDiv(10000, position.positionSize);
        return marginRatio < liquidationThreshold;
    }

    function _calculatePnL(HedgePosition storage position, uint256 currentPrice) 
        internal 
        view 
        returns (int256) 
    {
        // For short EUR/USD position: profit when EUR/USD falls
        int256 priceChange = int256(position.entryPrice) - int256(currentPrice);
        return priceChange * int256(position.positionSize) / int256(position.entryPrice);
    }

    function getTotalHedgeExposure() external view returns (uint256) {
        return totalExposure;
    }

    function getPoolStatistics() external view returns (
        uint256 activeHedgers_,
        uint256 totalPositions,
        uint256 averagePosition,
        uint256 totalMargin_,
        uint256 poolUtilization
    ) {
        activeHedgers_ = activeHedgers;
        totalPositions = nextPositionId - 1;
        averagePosition = totalPositions > 0 ? totalExposure / totalPositions : 0;
        totalMargin_ = totalMargin;
        poolUtilization = totalMargin > 0 ? (totalExposure * 10000) / totalMargin : 0;
    }

    function getPendingHedgingRewards(address hedger) external view returns (
        uint256 interestDifferential,
        uint256 yieldShiftRewards,
        uint256 totalPending
    ) {
        HedgerInfo storage hedgerInfo = hedgers[hedger];
        
        // Calculate pending interest differential
        if (hedgerInfo.totalExposure > 0) {
            uint256 timeElapsed = block.timestamp - hedgerInfo.lastRewardClaim;
            uint256 rateDiff = usdInterestRate > eurInterestRate ? 
                usdInterestRate - eurInterestRate : 0;
            
            interestDifferential = hedgerInfo.pendingRewards + 
                hedgerInfo.totalExposure.mulDiv(rateDiff, 10000).mulDiv(timeElapsed, 365 days);
        }
        
        yieldShiftRewards = yieldShift.getHedgerPendingYield(hedger);
        totalPending = interestDifferential + yieldShiftRewards;
    }

    // =============================================================================
    // GOVERNANCE FUNCTIONS
    // =============================================================================

    function updateHedgingParameters(
        uint256 newMinMarginRatio,
        uint256 newLiquidationThreshold,
        uint256 newMaxLeverage,
        uint256 newLiquidationPenalty
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(newMinMarginRatio >= 500, "HedgerPool: Min margin too low"); // Min 5%
        require(newLiquidationThreshold < newMinMarginRatio, "HedgerPool: Invalid thresholds");
        require(newMaxLeverage <= 20, "HedgerPool: Max leverage too high");
        require(newLiquidationPenalty <= 1000, "HedgerPool: Penalty too high"); // Max 10%

        minMarginRatio = newMinMarginRatio;
        liquidationThreshold = newLiquidationThreshold;
        maxLeverage = newMaxLeverage;
        liquidationPenalty = newLiquidationPenalty;
    }

    function updateInterestRates(uint256 newEurRate, uint256 newUsdRate) 
        external 
        onlyRole(GOVERNANCE_ROLE) 
    {
        require(newEurRate <= 2000 && newUsdRate <= 2000, "HedgerPool: Rates too high"); // Max 20%
        
        eurInterestRate = newEurRate;
        usdInterestRate = newUsdRate;
    }

    function setHedgingFees(
        uint256 _entryFee,
        uint256 _exitFee,
        uint256 _marginFee
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(_entryFee <= 100, "HedgerPool: Entry fee too high"); // Max 1%
        require(_exitFee <= 100, "HedgerPool: Exit fee too high"); // Max 1%
        require(_marginFee <= 50, "HedgerPool: Margin fee too high"); // Max 0.5%

        entryFee = _entryFee;
        exitFee = _exitFee;
        marginFee = _marginFee;
    }

    // =============================================================================
    // EMERGENCY FUNCTIONS
    // =============================================================================

    function emergencyClosePosition(address hedger, uint256 positionId) 
        external 
        onlyRole(EMERGENCY_ROLE) 
    {
        HedgePosition storage position = positions[positionId];
        require(position.hedger == hedger, "HedgerPool: Invalid hedger");
        require(position.isActive, "HedgerPool: Position not active");

        // Update hedger info
        HedgerInfo storage hedgerInfo = hedgers[hedger];
        hedgerInfo.totalMargin -= position.margin;
        hedgerInfo.totalExposure -= position.positionSize;

        // Update pool totals
        totalMargin -= position.margin;
        totalExposure -= position.positionSize;

        // Return margin to hedger
        usdc.safeTransfer(hedger, position.margin);

        // Deactivate position
        position.isActive = false;
    }

    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }

    function getHedgingConfig() external view returns (
        uint256 minMarginRatio_,
        uint256 liquidationThreshold_,
        uint256 maxLeverage_,
        uint256 liquidationPenalty_,
        uint256 entryFee_,
        uint256 exitFee_
    ) {
        return (
            minMarginRatio,
            liquidationThreshold,
            maxLeverage,
            liquidationPenalty,
            entryFee,
            exitFee
        );
    }

    function isHedgingActive() external view returns (bool) {
        return !paused();
    }

    function _authorizeUpgrade(address newImplementation) 
        internal 
        override 
        onlyRole(UPGRADER_ROLE) 
    {}
}