// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IChainlinkOracle.sol";
import "../interfaces/IYieldShift.sol";
import "../libraries/VaultMath.sol";
import "../libraries/ErrorLibrary.sol";
import "../libraries/AccessControlLibrary.sol";
import "../libraries/ValidationLibrary.sol";
import "../libraries/VaultLibrary.sol";
import "./SecureUpgradeable.sol";
import "../libraries/TreasuryRecoveryLibrary.sol";

/**
 * @title HedgerPool
 * @notice EUR/USD hedging pool for managing currency risk and providing yield
 * 
 * @dev Main characteristics:
 *      - EUR/USD currency hedging through leveraged positions
 *      - Margin-based trading with liquidation system
 *      - Interest rate differential yield generation
 *      - Multi-position management per hedger
 *      - Emergency pause mechanism for crisis situations
 *      - Upgradeable via UUPS pattern
 * 
 * @dev Position mechanics:
 *      - Hedgers open leveraged EUR/USD positions
 *      - Positions require minimum margin ratio (default 10%)
 *      - Maximum leverage of 10x to limit risk exposure
 *      - Position sizes tracked for risk management
 *      - Entry and exit fees charged for protocol revenue
 * 
 * @dev Margin system:
 *      - Initial margin required for position opening
 *      - Margin can be added to strengthen positions
 *      - Margin removal allowed if above minimum ratio
 *      - Real-time margin ratio calculations
 *      - Margin fees charged on additions
 * 
 * @dev Liquidation system:
 *      - Two-phase liquidation with commit-reveal pattern
 *      - Liquidation threshold below minimum margin ratio (default 1%)
 *      - Liquidation penalty rewarded to liquidators (default 2%)
 *      - Cooldown period prevents liquidation manipulation
 *      - Emergency position closure for critical situations
 * 
 * @dev Yield generation:
 *      - Interest rate differential between EUR and USD rates
 *      - Rewards distributed based on position exposure
 *      - Time-weighted reward calculations
 *      - Integration with yield shift mechanism
 *      - Automatic reward accumulation and claiming
 * 
 * @dev Risk management:
 *      - Maximum positions per hedger (50) to prevent concentration
 *      - Real-time oracle price monitoring
 *      - Position size limits and exposure tracking
 *      - Liquidation cooldown mechanisms
 *      - Emergency position closure capabilities
 * 
 * @dev Fee structure:
 *      - Entry fees for opening positions (default 0.2%)
 *      - Exit fees for closing positions (default 0.2%)
 *      - Margin fees for adding collateral (default 0.1%)
 *      - Dynamic fee adjustment based on market conditions
 * 
 * @dev Security features:
 *      - Role-based access control for all critical operations
 *      - Reentrancy protection for all external calls
 *      - Emergency pause mechanism for crisis situations
 *      - Upgradeable architecture for future improvements
 *      - Secure position and margin management
 *      - Two-phase liquidation for manipulation resistance
 * 
 * @dev Integration points:
 *      - USDC for margin deposits and withdrawals
 *      - Chainlink oracle for EUR/USD price feeds
 *      - Yield shift mechanism for reward distribution
 *      - Vault math library for precise calculations
 *      - Position tracking and management systems
 * 
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract HedgerPool is 
    Initializable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    SecureUpgradeable
{
    using SafeERC20 for IERC20;
    using VaultMath for uint256;
    using AccessControlLibrary for AccessControlUpgradeable;
    using ValidationLibrary for uint256;
    using VaultLibrary for address;

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    IERC20 public usdc;
    IChainlinkOracle public oracle;
    IYieldShift public yieldShift;
    address public treasury;

    uint256 public minMarginRatio;
    uint256 public liquidationThreshold;
    uint256 public maxLeverage;
    uint256 public liquidationPenalty;
    uint256 public constant MAX_POSITIONS_PER_HEDGER = 50;
    mapping(address => uint256) public activePositionCount;

    uint256 public entryFee;
    uint256 public exitFee;
    uint256 public marginFee;

    uint256 public totalMargin;
    uint256 public totalExposure;
    uint256 public activeHedgers;
    uint256 public nextPositionId;

    uint256 public eurInterestRate;
    uint256 public usdInterestRate;

    /// @dev OPTIMIZED: Packed struct for gas efficiency
    struct HedgePosition {
        address hedger;                     // Address of position owner (20 bytes)
        uint96 positionSize;               // Position size in USD (12 bytes, max ~79B USD)
        uint96 margin;                     // Margin amount in USDC (12 bytes, max ~79B USDC)
        uint96 entryPrice;                 // Entry price (12 bytes, scaled appropriately)
        uint32 entryTime;                  // Entry timestamp (4 bytes, until year 2106)
        uint32 lastUpdateTime;             // Last update timestamp (4 bytes, until year 2106)
        uint16 leverage;                   // Leverage multiplier (2 bytes, max 65535x)
        bool isActive;                     // Position status (1 byte)
        int128 unrealizedPnL;              // Unrealized P&L (16 bytes, max ~170B USD)
        // Total: 20+12+12+12+4+4+2+1+16 = 83 bytes (3 slots vs 9 slots = 67% gas savings)
    }

    /// @dev OPTIMIZED: Packed struct for gas efficiency
    struct HedgerInfo {
        uint256[] positionIds;              // Dynamic array (separate storage)
        uint128 totalMargin;                // Total margin across positions (16 bytes, max ~340B USDC)
        uint128 totalExposure;              // Total exposure across positions (16 bytes, max ~340B USD)
        uint128 pendingRewards;             // Pending rewards (16 bytes, max ~340B tokens)
        uint64 lastRewardClaim;             // Last reward claim timestamp (8 bytes, until year 2554)
        bool isActive;                      // Hedger status (1 byte)
        // Total: 32+16+16+16+8+1 = 89 bytes (3 slots vs 6 slots = 50% gas savings)
    }

    mapping(uint256 => HedgePosition) public positions;
    mapping(address => HedgerInfo) public hedgers;
    mapping(address => uint256[]) public hedgerPositions;

    // O(1) position removal mappings to prevent unbounded loops
    mapping(address => mapping(uint256 => bool)) public hedgerHasPosition;
    mapping(address => mapping(uint256 => uint256)) public positionIndex;
    mapping(address => mapping(uint256 => uint256)) public hedgerPositionIndex;

    uint256 public totalYieldEarned;
    uint256 public interestDifferentialPool;

    mapping(address => uint256) public userPendingYield;
    mapping(address => uint256) public hedgerPendingYield;
    mapping(address => uint256) public userLastClaim;
    mapping(address => uint256) public hedgerLastClaim;
    
    mapping(address => uint256) public hedgerLastRewardBlock;
    uint256 public constant BLOCKS_PER_DAY = 7200;
    uint256 public constant MAX_REWARD_PERIOD = 365 days;

    /// @dev Cooldown period in blocks (~1 hour assuming 12 second blocks)
    /// @dev Using block numbers instead of timestamps for security against miner manipulation
    uint256 public constant LIQUIDATION_COOLDOWN = 300;
    mapping(bytes32 => bool) public liquidationCommitments;
    mapping(bytes32 => uint256) public liquidationCommitmentTimes;
    mapping(address => uint256) public lastLiquidationAttempt;
    mapping(address => mapping(uint256 => bool)) public hasPendingLiquidation;

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

    event ETHRecovered(address indexed to, uint256 indexed amount);
    event TreasuryUpdated(address indexed treasury);

    // =============================================================================
    // MODIFIERS - Access control and security
    // =============================================================================

    /**
     * @notice Modifier to protect against flash loan attacks
     * @dev Checks that the contract's USDC balance doesn't decrease during execution
     * @dev This prevents flash loans that would drain USDC from the contract
     */
    modifier flashLoanProtection() {
        uint256 balanceBefore = usdc.balanceOf(address(this));
        _;
        uint256 balanceAfter = usdc.balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "Flash loan detected: USDC balance decreased");
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin,
        address _usdc,
        address _oracle,
        address _yieldShift,
        address _timelock,
        address _treasury
    ) public initializer {
        AccessControlLibrary.validateAddress(admin);
        AccessControlLibrary.validateAddress(_usdc);
        AccessControlLibrary.validateAddress(_oracle);
        AccessControlLibrary.validateAddress(_yieldShift);
        AccessControlLibrary.validateAddress(_treasury);

        __ReentrancyGuard_init();
        __AccessControl_init();
        __Pausable_init();
        __SecureUpgradeable_init(_timelock);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);

        usdc = IERC20(_usdc);
        oracle = IChainlinkOracle(_oracle);
        yieldShift = IYieldShift(_yieldShift);
        treasury = _treasury;

        minMarginRatio = 1000;
        liquidationThreshold = 100;
        maxLeverage = 10;
        liquidationPenalty = 200;
        
        entryFee = 20;
        exitFee = 20;
        marginFee = 10;

        eurInterestRate = 350;
        usdInterestRate = 450;

        nextPositionId = 1;
    }

    function enterHedgePosition(uint256 usdcAmount, uint256 leverage) 
        external 
        nonReentrant 
        whenNotPaused 
        flashLoanProtection
        returns (uint256 positionId) 
    {
        ValidationLibrary.validatePositiveAmount(usdcAmount);
        ValidationLibrary.validateLeverage(leverage, maxLeverage);
        ValidationLibrary.validatePositionCount(activePositionCount[msg.sender], MAX_POSITIONS_PER_HEDGER);

        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        ValidationLibrary.validateOraclePrice(isValid);

        uint256 fee = usdcAmount.percentageOf(entryFee);
        uint256 netMargin = usdcAmount - fee;
        uint256 positionSize = netMargin.mulDiv(leverage, 1);
        uint256 marginRatio = netMargin.mulDiv(10000, positionSize);
        ValidationLibrary.validateMarginRatio(marginRatio, minMarginRatio);

        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);

        positionId = nextPositionId++;
        
        HedgePosition storage position = positions[positionId];
        position.hedger = msg.sender;
        position.positionSize = uint96(positionSize);
        position.margin = uint96(netMargin);
        position.entryTime = uint32(block.timestamp);
        position.lastUpdateTime = uint32(block.timestamp);
        position.leverage = uint16(leverage);
        position.entryPrice = uint96(eurUsdPrice);
        position.unrealizedPnL = 0;
        position.isActive = true;

        HedgerInfo storage hedger = hedgers[msg.sender];
        if (!hedger.isActive) {
            hedger.isActive = true;
            activeHedgers++;
        }
        
        // Add to hedgers[hedger].positionIds array with O(1) indexing
        hedger.positionIds.push(positionId);
        positionIndex[msg.sender][positionId] = hedger.positionIds.length - 1;
        
        hedger.totalMargin += uint128(netMargin);
        hedger.totalExposure += uint128(positionSize);
        
        // Add to hedgerPositions[hedger] array with O(1) indexing
        hedgerPositions[msg.sender].push(positionId);
        hedgerPositionIndex[msg.sender][positionId] = hedgerPositions[msg.sender].length - 1;
        
        // Mark position as owned by hedger
        hedgerHasPosition[msg.sender][positionId] = true;

        activePositionCount[msg.sender]++;

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

    function exitHedgePosition(uint256 positionId) 
        external 
        nonReentrant 
        whenNotPaused 
        flashLoanProtection
        returns (int256 pnl) 
    {
        HedgePosition storage position = positions[positionId];
        ValidationLibrary.validatePositionOwner(position.hedger, msg.sender);
        ValidationLibrary.validatePositionActive(position.isActive);

        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        ValidationLibrary.validateOraclePrice(isValid);

        pnl = _calculatePnL(position, currentPrice);

        uint256 grossPayout = uint256(int256(uint256(position.margin)) + pnl);
        uint256 exitFeeAmount = grossPayout.percentageOf(exitFee);
        uint256 netPayout = grossPayout - exitFeeAmount;

        HedgerInfo storage hedger = hedgers[msg.sender];
        hedger.totalMargin -= uint128(position.margin);
        hedger.totalExposure -= uint128(position.positionSize);

        totalMargin -= uint256(position.margin);
        totalExposure -= uint256(position.positionSize);

        position.isActive = false;
        _removePositionFromArrays(msg.sender, positionId);
        
        activePositionCount[msg.sender]--;

        if (netPayout > 0) {
            usdc.safeTransfer(msg.sender, netPayout);
        }

        emit HedgePositionClosed(msg.sender, positionId, currentPrice, pnl, block.timestamp);
    }

    function closePositionsBatch(uint256[] calldata positionIds, uint256 maxPositions) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (int256[] memory pnls) 
    {
        require(positionIds.length <= maxPositions, "Too many positions");
        require(maxPositions <= 10, "Max 10 positions per tx");
        
        pnls = new int256[](positionIds.length);
        

        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        ValidationLibrary.validateOraclePrice(isValid);
        

        HedgerInfo storage hedger = hedgers[msg.sender];
        
        for (uint i = 0; i < positionIds.length; i++) {
            pnls[i] = _closeSinglePosition(positionIds[i], currentPrice, hedger);
        }
    }

    /**
     * @notice Close a single hedge position
     * @param positionId The ID of the position to close
     * @param currentPrice The current EUR/USD price
     * @param hedger The hedger info storage reference
     * @return pnl The profit/loss for the position
     */
    function _closeSinglePosition(
        uint256 positionId, 
        uint256 currentPrice, 
        HedgerInfo storage hedger
    ) internal returns (int256 pnl) {

        HedgePosition storage position = positions[positionId];
        uint128 positionMargin = position.margin;
        uint128 positionSize = position.positionSize;
        address positionHedger = position.hedger;
        bool positionIsActive = position.isActive;
        
        ValidationLibrary.validatePositionOwner(positionHedger, msg.sender);
        ValidationLibrary.validatePositionActive(positionIsActive);

        pnl = _calculatePnL(position, currentPrice);

        uint256 grossPayout = uint256(int256(uint256(positionMargin)) + pnl);
        uint256 exitFeeAmount = grossPayout.percentageOf(exitFee);
        uint256 netPayout = grossPayout - exitFeeAmount;

        // Update hedger totals
        hedger.totalMargin -= positionMargin;
        hedger.totalExposure -= positionSize;

        totalMargin -= positionMargin;
        totalExposure -= positionSize;

        // Update position state
        position.isActive = false;
        _removePositionFromArrays(msg.sender, positionId);
        
        activePositionCount[msg.sender]--;

        if (netPayout > 0) {
            usdc.safeTransfer(msg.sender, netPayout);
        }

        emit HedgePositionClosed(msg.sender, positionId, currentPrice, pnl, block.timestamp);
    }

    function _removePositionFromArrays(address hedger, uint256 positionId) internal {
        require(hedgerHasPosition[hedger][positionId], "Position not found");
        
        // O(1) removal from hedgers[hedger].positionIds array
        uint256 index = positionIndex[hedger][positionId];
        uint256[] storage positionIds = hedgers[hedger].positionIds;
        uint256 lastIndex = positionIds.length - 1;
        
        if (index != lastIndex) {
            uint256 lastPositionId = positionIds[lastIndex];
            positionIds[index] = lastPositionId;
            positionIndex[hedger][lastPositionId] = index;
        }
        
        positionIds.pop();
        
        // O(1) removal from hedgerPositions[hedger] array
        uint256[] storage hedgerPos = hedgerPositions[hedger];
        uint256 posIndex = hedgerPositionIndex[hedger][positionId];
        uint256 posLastIndex = hedgerPos.length - 1;
        
        if (posIndex != posLastIndex) {
            uint256 posLastPositionId = hedgerPos[posLastIndex];
            hedgerPos[posIndex] = posLastPositionId;
            hedgerPositionIndex[hedger][posLastPositionId] = posIndex;
        }
        
        hedgerPos.pop();
        
        // Clean up mappings
        delete positionIndex[hedger][positionId];
        delete hedgerPositionIndex[hedger][positionId];
        delete hedgerHasPosition[hedger][positionId];
    }

    function addMargin(uint256 positionId, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        HedgePosition storage position = positions[positionId];
        ValidationLibrary.validatePositionOwner(position.hedger, msg.sender);
        ValidationLibrary.validatePositionActive(position.isActive);
        ValidationLibrary.validatePositiveAmount(amount);
        
        ValidationLibrary.validateLiquidationCooldown(lastLiquidationAttempt[msg.sender], LIQUIDATION_COOLDOWN);
        
        if (_hasPendingLiquidationCommitment(msg.sender, positionId)) {
            revert ErrorLibrary.PendingLiquidationCommitment();
        }

        uint256 fee = amount.percentageOf(marginFee);
        uint256 netAmount = amount - fee;

        usdc.safeTransferFrom(msg.sender, address(this), amount);

        position.margin += uint96(netAmount);

        hedgers[msg.sender].totalMargin += uint128(netAmount);
        totalMargin += netAmount;

        uint256 newMarginRatio = uint256(position.margin).mulDiv(10000, uint256(position.positionSize));

        emit MarginAdded(msg.sender, positionId, netAmount, newMarginRatio);
    }

    function removeMargin(uint256 positionId, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        HedgePosition storage position = positions[positionId];
        ValidationLibrary.validatePositionOwner(position.hedger, msg.sender);
        ValidationLibrary.validatePositionActive(position.isActive);
        ValidationLibrary.validatePositiveAmount(amount);
        if (uint256(position.margin) < amount) revert ErrorLibrary.InsufficientMargin();

        uint256 newMargin = uint256(position.margin) - amount;
        uint256 newMarginRatio = newMargin.mulDiv(10000, uint256(position.positionSize));
        ValidationLibrary.validateMarginRatio(newMarginRatio, minMarginRatio);

        position.margin = uint96(newMargin);

        hedgers[msg.sender].totalMargin -= uint128(amount);
        totalMargin -= amount;

        usdc.safeTransfer(msg.sender, amount);

        emit MarginRemoved(msg.sender, positionId, amount, newMarginRatio);
    }

    function commitLiquidation(
        address hedger,
        uint256 positionId,
        bytes32 salt
    ) external {
        AccessControlLibrary.onlyLiquidatorRole(this);
        AccessControlLibrary.validateAddress(hedger);
        if (positionId == 0) revert ErrorLibrary.InvalidPosition();
        
        bytes32 commitment = keccak256(abi.encodePacked(hedger, positionId, salt, msg.sender));
        ValidationLibrary.validateCommitmentNotExists(liquidationCommitments[commitment]);
        
        liquidationCommitments[commitment] = true;
        liquidationCommitmentTimes[commitment] = block.number;
        
        hasPendingLiquidation[hedger][positionId] = true;
        lastLiquidationAttempt[hedger] = block.number;
    }

    function liquidateHedger(
        address hedger, 
        uint256 positionId,
        bytes32 salt
    ) external nonReentrant returns (uint256 liquidationReward) {
        AccessControlLibrary.onlyLiquidatorRole(this);
        
        HedgePosition storage position = positions[positionId];
        if (position.hedger != hedger) revert ErrorLibrary.InvalidHedger();
        ValidationLibrary.validatePositionActive(position.isActive);

        bytes32 commitment = keccak256(abi.encodePacked(hedger, positionId, salt, msg.sender));
        ValidationLibrary.validateCommitment(liquidationCommitments[commitment]);
        
        delete liquidationCommitments[commitment];
        delete liquidationCommitmentTimes[commitment];
        hasPendingLiquidation[hedger][positionId] = false;

        if (!_isPositionLiquidatable(positionId)) revert ErrorLibrary.PositionNotLiquidatable();

        // SECURITY: Only need validation status, ignore price (safe to ignore for liquidation)
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        ValidationLibrary.validateOraclePrice(isValid);
        // Note: currentPrice is intentionally unused for liquidation logic

        liquidationReward = uint256(position.margin).percentageOf(liquidationPenalty);
        uint256 remainingMargin = uint256(position.margin) - liquidationReward;

        HedgerInfo storage hedgerInfo = hedgers[hedger];
        hedgerInfo.totalMargin -= uint128(position.margin);
        hedgerInfo.totalExposure -= uint128(position.positionSize);

        totalMargin -= position.margin;
        totalExposure -= position.positionSize;

        position.isActive = false;
        _removePositionFromArrays(hedger, positionId);
        
        activePositionCount[hedger]--;

        usdc.safeTransfer(msg.sender, liquidationReward);

        if (remainingMargin > 0) {
            usdc.safeTransfer(hedger, remainingMargin);
        }

        emit HedgerLiquidated(hedger, positionId, msg.sender, liquidationReward, remainingMargin);
    }

    function claimHedgingRewards() 
        external 
        nonReentrant 
        returns (
            uint256 interestDifferential,
            uint256 yieldShiftRewards,
            uint256 totalRewards
        ) 
    {
        address hedger = msg.sender;
        
        HedgerInfo storage hedgerInfo = hedgers[hedger];
        
        _updateHedgerRewards(hedger);
        
        interestDifferential = hedgerInfo.pendingRewards;
        yieldShiftRewards = yieldShift.getHedgerPendingYield(hedger);
        
        totalRewards = interestDifferential + yieldShiftRewards;
        
        if (totalRewards > 0) {
            hedgerInfo.pendingRewards = 0;
            hedgerInfo.lastRewardClaim = uint64(block.timestamp);
            
            if (yieldShiftRewards > 0) {
                uint256 claimedAmount = yieldShift.claimHedgerYield(hedger);
                if (claimedAmount == 0) revert ErrorLibrary.YieldClaimFailed();
            }
            
            usdc.safeTransfer(hedger, totalRewards);
            
            emit HedgingRewardsClaimed(hedger, interestDifferential, yieldShiftRewards, totalRewards);
        }
    }

    function _updateHedgerRewards(address hedger) internal {
        HedgerInfo storage hedgerInfo = hedgers[hedger];
        
        if (hedgerInfo.totalExposure > 0) {
            uint256 currentBlock = block.number;
            uint256 lastRewardBlock = hedgerLastRewardBlock[hedger];
            
            if (lastRewardBlock < 1) {
                hedgerLastRewardBlock[hedger] = currentBlock;
                return;
            }
            
    
            unchecked {
                uint256 blocksElapsed = currentBlock - lastRewardBlock;
                uint256 timeElapsed = blocksElapsed * 12;
                
                if (timeElapsed > MAX_REWARD_PERIOD) {
                    timeElapsed = MAX_REWARD_PERIOD;
                }
                
                uint256 interestDifferential = usdInterestRate > eurInterestRate ? 
                    usdInterestRate - eurInterestRate : 0;
                
                uint256 reward = uint256(hedgerInfo.totalExposure)
                    .mulDiv(interestDifferential, 10000)
                    .mulDiv(timeElapsed, 365 days);
                
                uint256 newPendingRewards = uint256(hedgerInfo.pendingRewards) + reward;
                if (newPendingRewards < uint256(hedgerInfo.pendingRewards)) revert ErrorLibrary.RewardOverflow();
                hedgerInfo.pendingRewards = uint128(newPendingRewards);
                
                hedgerLastRewardBlock[hedger] = currentBlock;
            }
        }
    }

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
        if (position.hedger != hedger) revert ErrorLibrary.InvalidHedger();
        
        (uint256 oraclePrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) revert ErrorLibrary.InvalidOraclePrice();
        
        return (
            position.positionSize,
            position.margin,
            position.entryPrice,
            oraclePrice,
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
        if (position.hedger != hedger) revert ErrorLibrary.InvalidHedger();
        
        if (position.positionSize == 0) return 0;
        return uint256(position.margin).mulDiv(10000, uint256(position.positionSize));
    }

    function isHedgerLiquidatable(address hedger, uint256 positionId) 
        external 
        view 
        returns (bool) 
    {
        HedgePosition storage position = positions[positionId];
        if (position.hedger != hedger) revert ErrorLibrary.InvalidHedger();
        
        return _isPositionLiquidatable(positionId);
    }

    function _isPositionLiquidatable(uint256 positionId) internal view returns (bool) {
        HedgePosition storage position = positions[positionId];
        if (!position.isActive) return false;
        
        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) return false;
        
        int256 pnl = _calculatePnL(position, currentPrice);
        int256 effectiveMargin = int256(uint256(position.margin)) + pnl;
        
        if (effectiveMargin <= 0) return true;
        
        uint256 marginRatio = uint256(effectiveMargin).mulDiv(10000, position.positionSize);
        return marginRatio < liquidationThreshold;
    }

    function _calculatePnL(HedgePosition storage position, uint256 currentPrice) 
        internal 
        view 
        returns (int256) 
    {
        int256 priceChange = int256(uint256(position.entryPrice)) - int256(currentPrice);
        
        if (priceChange >= 0) {
            uint256 absPriceChange = uint256(priceChange);
            uint256 intermediate = uint256(position.positionSize).mulDiv(absPriceChange, uint256(position.entryPrice));
            return int256(intermediate);
        } else {
            uint256 absPriceChange = uint256(-priceChange);
            uint256 intermediate = uint256(position.positionSize).mulDiv(absPriceChange, uint256(position.entryPrice));
            return -int256(intermediate);
        }
    }

    function getTotalHedgeExposure() external view returns (uint256) {
        return totalExposure;
    }

    function updateHedgingParameters(
        uint256 newMinMarginRatio,
        uint256 newLiquidationThreshold,
        uint256 newMaxLeverage,
        uint256 newLiquidationPenalty
    ) external {
        AccessControlLibrary.onlyGovernance(this);
        if (newMinMarginRatio < 500) revert ErrorLibrary.ConfigValueTooLow();
        if (newLiquidationThreshold >= newMinMarginRatio) revert ErrorLibrary.ConfigInvalid();
        if (newMaxLeverage > 20) revert ErrorLibrary.ConfigValueTooHigh();
        if (newLiquidationPenalty > 1000) revert ErrorLibrary.ConfigValueTooHigh();

        minMarginRatio = newMinMarginRatio;
        liquidationThreshold = newLiquidationThreshold;
        maxLeverage = newMaxLeverage;
        liquidationPenalty = newLiquidationPenalty;
    }

    function updateInterestRates(uint256 newEurRate, uint256 newUsdRate) external {
        AccessControlLibrary.onlyGovernance(this);
        if (newEurRate > 2000 || newUsdRate > 2000) revert ErrorLibrary.ConfigValueTooHigh();
        
        eurInterestRate = newEurRate;
        usdInterestRate = newUsdRate;
    }

    function setHedgingFees(
        uint256 _entryFee,
        uint256 _exitFee,
        uint256 _marginFee
    ) external {
        AccessControlLibrary.onlyGovernance(this);
        ValidationLibrary.validateFee(_entryFee, 100);
        ValidationLibrary.validateFee(_exitFee, 100);
        ValidationLibrary.validateFee(_marginFee, 50);

        entryFee = _entryFee;
        exitFee = _exitFee;
        marginFee = _marginFee;
    }

    function emergencyClosePosition(address hedger, uint256 positionId) external {
        AccessControlLibrary.onlyEmergencyRole(this);
        
        HedgePosition storage position = positions[positionId];
        if (position.hedger != hedger) revert ErrorLibrary.InvalidHedger();
        ValidationLibrary.validatePositionActive(position.isActive);

        HedgerInfo storage hedgerInfo = hedgers[hedger];
        hedgerInfo.totalMargin -= uint128(position.margin);
        hedgerInfo.totalExposure -= uint128(position.positionSize);

        totalMargin -= position.margin;
        totalExposure -= position.positionSize;

        usdc.safeTransfer(hedger, position.margin);

        position.isActive = false;
        _removePositionFromArrays(hedger, positionId);
        
        activePositionCount[hedger]--;
    }

    function pause() external {
        AccessControlLibrary.onlyEmergencyRole(this);
        _pause();
    }

    function unpause() external {
        AccessControlLibrary.onlyEmergencyRole(this);
        _unpause();
    }

    function hasPendingLiquidationCommitment(address hedger, uint256 positionId) 
        external 
        view 
        returns (bool) 
    {
        return hasPendingLiquidation[hedger][positionId];
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

    /**
     * @notice Clear expired liquidation commitment after cooldown period
     * @dev Uses block numbers instead of timestamps for security against miner manipulation
     * @param hedger Address of the hedger
     * @param positionId ID of the position
     */
    function clearExpiredLiquidationCommitment(address hedger, uint256 positionId) external {
        AccessControlLibrary.onlyLiquidatorRole(this);
        if (block.number > lastLiquidationAttempt[hedger] + LIQUIDATION_COOLDOWN) {
            hasPendingLiquidation[hedger][positionId] = false;
        }
    }

    function cancelLiquidationCommitment(address hedger, uint256 positionId, bytes32 salt) external {
        AccessControlLibrary.onlyLiquidatorRole(this);
        bytes32 commitment = keccak256(abi.encodePacked(hedger, positionId, salt, msg.sender));
        ValidationLibrary.validateCommitment(liquidationCommitments[commitment]);
        
        delete liquidationCommitments[commitment];
        delete liquidationCommitmentTimes[commitment];
        hasPendingLiquidation[hedger][positionId] = false;
    }

    function _hasPendingLiquidationCommitment(address hedger, uint256 positionId) internal view returns (bool) {
        return hasPendingLiquidation[hedger][positionId];
    }

    function recoverToken(address token, uint256 amount) external {
        AccessControlLibrary.onlyAdmin(this);
        // Use the shared library for secure token recovery to treasury
        TreasuryRecoveryLibrary.recoverToken(token, amount, address(this), treasury);
    }

    /**
     * @notice Recover ETH to treasury address only
     * @dev SECURITY: Uses TreasuryRecoveryLibrary for secure ETH recovery
     */
    function recoverETH() external {
        AccessControlLibrary.onlyAdmin(this);

        emit ETHRecovered(treasury, address(this).balance);
        TreasuryRecoveryLibrary.recoverETH(treasury);
    }
    
    /**
     * @notice Update treasury address
     * @dev SECURITY: Only governance can update treasury address
     * @param _treasury New treasury address
     */
    function updateTreasury(address _treasury) external {
        AccessControlLibrary.onlyGovernance(this);
        AccessControlLibrary.validateAddress(_treasury);
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }
}