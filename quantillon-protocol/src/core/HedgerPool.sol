// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IChainlinkOracle} from "../interfaces/IChainlinkOracle.sol";
import {IYieldShift} from "../interfaces/IYieldShift.sol";
import {IQuantillonVault} from "../interfaces/IQuantillonVault.sol";
import {VaultMath} from "../libraries/VaultMath.sol";
import {ErrorLibrary} from "../libraries/ErrorLibrary.sol";
import {AccessControlLibrary} from "../libraries/AccessControlLibrary.sol";
import {ValidationLibrary} from "../libraries/ValidationLibrary.sol";
import {SecureUpgradeable} from "./SecureUpgradeable.sol";
import {TreasuryRecoveryLibrary} from "../libraries/TreasuryRecoveryLibrary.sol";
import {FlashLoanProtectionLibrary} from "../libraries/FlashLoanProtectionLibrary.sol";
import {TimeProvider} from "../libraries/TimeProviderLibrary.sol";
import {HedgerPoolLogicLibrary} from "../libraries/HedgerPoolLogicLibrary.sol";

/**
 * @title HedgerPool
 * @notice Optimized EUR/USD hedging pool for managing currency risk and providing yield
 * @dev Optimized version with reduced contract size through library extraction and code consolidation
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
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

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant HEDGER_ROLE = keccak256("HEDGER_ROLE");

    IERC20 public usdc;
    IChainlinkOracle public oracle;
    IYieldShift public yieldShift;
    IQuantillonVault public vault;
    address public treasury;
    TimeProvider public immutable TIME_PROVIDER;

    struct CoreParams {
        uint64 minMarginRatio;
        uint64 liquidationThreshold;
        uint16 maxLeverage;
        uint16 liquidationPenalty;
        uint16 entryFee;
        uint16 exitFee;
        uint16 marginFee;
        uint16 eurInterestRate;
        uint16 usdInterestRate;
        uint8 reserved;
    }
    CoreParams public coreParams;

    uint256 public totalMargin;
    uint256 public totalExposure;
    uint256 public activeHedgers;
    uint256 public nextPositionId;

    mapping(address => bool) public isWhitelistedHedger;
    bool public hedgerWhitelistEnabled;

    struct HedgePosition {
        address hedger;
        uint96 positionSize;
        uint96 margin;
        uint96 entryPrice;
        uint32 entryTime;
        uint32 lastUpdateTime;
        int128 unrealizedPnL;
        uint16 leverage;
        bool isActive;
    }

    struct HedgerInfo {
        uint256[] positionIds;
        uint128 totalMargin;
        uint128 totalExposure;
        uint128 pendingRewards;
        uint64 lastRewardClaim;
        bool isActive;
    }

    mapping(uint256 => HedgePosition) public positions;
    mapping(address => HedgerInfo) public hedgers;
    mapping(address => uint256) public activePositionCount;

    mapping(address => mapping(uint256 => bool)) public hedgerHasPosition;
    mapping(address => mapping(uint256 => uint256)) public positionIndex;

    mapping(bytes32 => bool) public liquidationCommitments;
    mapping(bytes32 => uint256) public liquidationCommitmentTimes;
    mapping(address => uint256) public lastLiquidationAttempt;
    mapping(address => mapping(uint256 => bool)) public hasPendingLiquidation;

    mapping(address => uint256) public hedgerLastRewardBlock;

    uint256 public constant MAX_POSITIONS_PER_HEDGER = 50;
    uint96 public constant MAX_UINT96_VALUE = type(uint96).max;
    uint256 public constant MAX_POSITION_SIZE = MAX_UINT96_VALUE;
    uint256 public constant MAX_MARGIN = MAX_UINT96_VALUE;
    uint256 public constant MAX_ENTRY_PRICE = MAX_UINT96_VALUE;
    uint256 public constant MAX_LEVERAGE = type(uint16).max;
    uint256 public constant MAX_MARGIN_RATIO = 5000; // 50% maximum margin ratio (2x minimum leverage)
    uint128 public constant MAX_UINT128_VALUE = type(uint128).max;
    uint256 public constant MAX_TOTAL_MARGIN = MAX_UINT128_VALUE;
    uint256 public constant MAX_TOTAL_EXPOSURE = MAX_UINT128_VALUE;
    uint256 public constant MAX_PENDING_REWARDS = MAX_UINT128_VALUE;
    uint256 public constant LIQUIDATION_COOLDOWN = 300;
    uint256 public constant MAX_REWARD_PERIOD = 365 days;

    event HedgePositionOpened(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
    event HedgePositionClosed(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
    event MarginUpdated(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
    event HedgerLiquidated(address indexed hedger, uint256 indexed positionId, address indexed liquidator, bytes32 packedData);
    event HedgingRewardsClaimed(address indexed hedger, bytes32 packedData);
    event HedgerWhitelisted(address indexed hedger, address indexed caller);
    event HedgerRemoved(address indexed hedger, address indexed caller);
    event HedgerWhitelistModeToggled(bool enabled, address indexed caller);
    event ETHRecovered(address indexed to, uint256 indexed amount);
    event TreasuryUpdated(address indexed treasury);
    event VaultUpdated(address indexed vault);

    modifier flashLoanProtection() {
        uint256 balanceBefore = usdc.balanceOf(address(this));
        _;
        uint256 balanceAfter = usdc.balanceOf(address(this));
        if (!FlashLoanProtectionLibrary.validateBalanceChange(balanceBefore, balanceAfter, 0))
            revert ErrorLibrary.FlashLoanAttackDetected();
    }

    modifier secureNonReentrant() {
        if (paused()) revert ErrorLibrary.NotPaused();
        uint256 balanceBefore = usdc.balanceOf(address(this));
        _;
        uint256 balanceAfter = usdc.balanceOf(address(this));
        if (!FlashLoanProtectionLibrary.validateBalanceChange(balanceBefore, balanceAfter, 0))
            revert ErrorLibrary.FlashLoanAttackDetected();
    }

    constructor(TimeProvider _TIME_PROVIDER) {
        if (address(_TIME_PROVIDER) == address(0)) revert ErrorLibrary.ZeroAddress();
        TIME_PROVIDER = _TIME_PROVIDER;
        _disableInitializers();
    }

    function initialize(
        address admin,
        address _usdc,
        address _oracle,
        address _yieldShift,
        address _timelock,
        address _treasury,
        address _vault
    ) public initializer {
        AccessControlLibrary.validateAddress(admin);
        AccessControlLibrary.validateAddress(_usdc);
        AccessControlLibrary.validateAddress(_oracle);
        AccessControlLibrary.validateAddress(_yieldShift);
        AccessControlLibrary.validateAddress(_treasury);
        AccessControlLibrary.validateAddress(_vault);

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
        vault = IQuantillonVault(_vault);
        treasury = _treasury;

        coreParams.minMarginRatio = 500;  // 5% minimum margin ratio (20x max leverage)
        coreParams.liquidationThreshold = 100;
        coreParams.maxLeverage = 20;      // 20x maximum leverage (5% minimum margin)
        coreParams.liquidationPenalty = 200;
        coreParams.entryFee = 0;
        coreParams.exitFee = 0;
        coreParams.marginFee = 0;
        coreParams.eurInterestRate = 350;
        coreParams.usdInterestRate = 450;
        hedgerWhitelistEnabled = true;
        nextPositionId = 1;
    }

    function enterHedgePosition(uint256 usdcAmount, uint256 leverage) 
        external 
        secureNonReentrant
        returns (uint256 positionId) 
    {
        if (hedgerWhitelistEnabled && !isWhitelistedHedger[msg.sender]) {
            revert ErrorLibrary.NotWhitelisted();
        }
        
        uint256 eurUsdPrice = _getValidOraclePrice();
        
        (uint256 fee, uint256 netMargin, uint256 positionSize, uint256 marginRatio) = 
            HedgerPoolLogicLibrary.validateAndCalculatePositionParams(
                usdcAmount, leverage, eurUsdPrice, coreParams.entryFee, coreParams.minMarginRatio, MAX_MARGIN_RATIO, coreParams.maxLeverage,
                MAX_POSITIONS_PER_HEDGER, activePositionCount[msg.sender], MAX_MARGIN,
                MAX_POSITION_SIZE, MAX_ENTRY_PRICE, MAX_LEVERAGE, TIME_PROVIDER.currentTime()
            );

        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);

        positionId = nextPositionId++;
        
        HedgePosition storage position = positions[positionId];
        position.hedger = msg.sender;
        position.positionSize = uint96(positionSize);
        position.margin = uint96(netMargin);
        position.entryTime = uint32(TIME_PROVIDER.currentTime());
        position.lastUpdateTime = uint32(TIME_PROVIDER.currentTime());
        position.leverage = uint16(leverage);
        position.entryPrice = uint96(eurUsdPrice);
        position.unrealizedPnL = 0;
        position.isActive = true;

        HedgerInfo storage hedgerInfo = hedgers[msg.sender];
        if (!hedgerInfo.isActive) {
            hedgerInfo.isActive = true;
            activeHedgers++;
        }
        
        hedgerInfo.positionIds.push(positionId);
        positionIndex[msg.sender][positionId] = hedgerInfo.positionIds.length - 1;
        
        ValidationLibrary.validateTotals(
            hedgerInfo.totalMargin, hedgerInfo.totalExposure,
            netMargin, positionSize, MAX_TOTAL_MARGIN, MAX_TOTAL_EXPOSURE
        );
        
        hedgerInfo.totalMargin += uint128(netMargin);
        hedgerInfo.totalExposure += uint128(positionSize);
        
        hedgerHasPosition[msg.sender][positionId] = true;
        activePositionCount[msg.sender]++;
        totalMargin += netMargin;
        totalExposure += positionSize;

        emit HedgePositionOpened(
            msg.sender, 
            positionId, 
            _packPositionOpenData(positionSize, netMargin, leverage, eurUsdPrice)
        );
    }

    function exitHedgePosition(uint256 positionId) 
        external 
        whenNotPaused
        returns (int256 pnl) 
    {
        HedgePosition storage position = positions[positionId];
        ValidationLibrary.validatePositionOwner(position.hedger, msg.sender);
        ValidationLibrary.validatePositionActive(position.isActive);

        // Check if closing this position would cause protocol undercollateralization
        _validatePositionClosureSafety(positionId, position.margin);

        uint256 currentPrice = _getValidOraclePrice();
        pnl = HedgerPoolLogicLibrary.calculatePnL(
            uint256(position.positionSize), 
            uint256(position.entryPrice), 
            currentPrice
        );

        uint256 grossPayout = uint256(int256(uint256(position.margin)) + pnl);
        uint256 exitFeeAmount = grossPayout.percentageOf(coreParams.exitFee);
        uint256 netPayout = grossPayout - exitFeeAmount;

        HedgerInfo storage hedgerInfo = hedgers[msg.sender];
        hedgerInfo.totalMargin -= uint128(position.margin);
        hedgerInfo.totalExposure -= uint128(position.positionSize);

        totalMargin -= uint256(position.margin);
        totalExposure -= uint256(position.positionSize);

        position.isActive = false;
        _removePositionFromArrays(msg.sender, positionId);
        
        activePositionCount[msg.sender]--;
        
        // Check if hedger has no more active positions
        if (activePositionCount[msg.sender] == 0) {
            hedgerInfo.isActive = false;
            activeHedgers--;
        }

        if (netPayout > 0) {
            usdc.safeTransfer(msg.sender, netPayout);
        }

        emit HedgePositionClosed(
            msg.sender, 
            positionId, 
            _packPositionCloseData(currentPrice, pnl, TIME_PROVIDER.currentTime())
        );
    }

    function addMargin(uint256 positionId, uint256 amount) external flashLoanProtection {
        HedgePosition storage position = positions[positionId];
        ValidationLibrary.validatePositionOwner(position.hedger, msg.sender);
        ValidationLibrary.validatePositionActive(position.isActive);
        ValidationLibrary.validatePositiveAmount(amount);
        ValidationLibrary.validateLiquidationCooldown(lastLiquidationAttempt[msg.sender], LIQUIDATION_COOLDOWN);
        
        if (hasPendingLiquidation[msg.sender][positionId]) {
            revert ErrorLibrary.PendingLiquidationCommitment();
        }

        uint256 fee = amount.percentageOf(coreParams.marginFee);
        uint256 netAmount = amount - fee;

        usdc.safeTransferFrom(msg.sender, address(this), amount);

        (uint256 newMargin, uint256 newMarginRatio) = HedgerPoolLogicLibrary.validateMarginOperation(
            uint256(position.margin), netAmount, true, coreParams.minMarginRatio, 
            uint256(position.positionSize), MAX_MARGIN
        );
        
        position.margin = uint96(newMargin);
        hedgers[msg.sender].totalMargin += uint128(netAmount);
        totalMargin += netAmount;

        emit MarginUpdated(
            msg.sender, 
            positionId, 
            _packMarginData(netAmount, newMarginRatio, true)
        );
    }

    function removeMargin(uint256 positionId, uint256 amount) external flashLoanProtection {
        HedgePosition storage position = positions[positionId];
        ValidationLibrary.validatePositionOwner(position.hedger, msg.sender);
        ValidationLibrary.validatePositionActive(position.isActive);
        ValidationLibrary.validatePositiveAmount(amount);

        (uint256 newMargin, uint256 newMarginRatio) = HedgerPoolLogicLibrary.validateMarginOperation(
            uint256(position.margin), amount, false, coreParams.minMarginRatio, 
            uint256(position.positionSize), MAX_MARGIN
        );
        
        position.margin = uint96(newMargin);
        hedgers[msg.sender].totalMargin -= uint128(amount);
        totalMargin -= amount;

        usdc.safeTransfer(msg.sender, amount);

        emit MarginUpdated(
            msg.sender, 
            positionId, 
            _packMarginData(amount, newMarginRatio, false)
        );
    }

    function commitLiquidation(address hedger, uint256 positionId, bytes32 salt) external {
        _validateRole(LIQUIDATOR_ROLE);
        AccessControlLibrary.validateAddress(hedger);
        if (positionId == 0) revert ErrorLibrary.InvalidPosition();
        
        bytes32 commitment = HedgerPoolLogicLibrary.generateLiquidationCommitment(
            hedger, positionId, salt, msg.sender
        );
        ValidationLibrary.validateCommitmentNotExists(liquidationCommitments[commitment]);
        
        liquidationCommitments[commitment] = true;
        liquidationCommitmentTimes[commitment] = block.number;
        hasPendingLiquidation[hedger][positionId] = true;
        lastLiquidationAttempt[hedger] = block.number;
    }

    function liquidateHedger(address hedger, uint256 positionId, bytes32 salt) 
        external 
        nonReentrant 
        returns (uint256 liquidationReward) 
    {
        _validateRole(LIQUIDATOR_ROLE);
        
        HedgePosition storage position = positions[positionId];
        ValidationLibrary.validatePositionOwner(position.hedger, hedger);
        ValidationLibrary.validatePositionActive(position.isActive);

        bytes32 commitment = HedgerPoolLogicLibrary.generateLiquidationCommitment(
            hedger, positionId, salt, msg.sender
        );
        ValidationLibrary.validateCommitment(liquidationCommitments[commitment]);
        
        delete liquidationCommitments[commitment];
        delete liquidationCommitmentTimes[commitment];
        hasPendingLiquidation[hedger][positionId] = false;

        uint256 currentPrice = _getValidOraclePrice();
        bool liquidatable = HedgerPoolLogicLibrary.isPositionLiquidatable(
            uint256(position.margin), uint256(position.positionSize), 
            uint256(position.entryPrice), currentPrice, coreParams.liquidationThreshold
        );
        
        if (!liquidatable) revert ErrorLibrary.PositionNotLiquidatable();

        liquidationReward = uint256(position.margin).percentageOf(coreParams.liquidationPenalty);
        uint256 remainingMargin = uint256(position.margin) - liquidationReward;

        HedgerInfo storage hedgerInfo = hedgers[hedger];
        hedgerInfo.totalMargin -= uint128(position.margin);
        hedgerInfo.totalExposure -= uint128(position.positionSize);

        totalMargin -= position.margin;
        totalExposure -= position.positionSize;

        position.isActive = false;
        _removePositionFromArrays(hedger, positionId);
        
        activePositionCount[hedger]--;
        
        // Check if hedger has no more active positions
        if (activePositionCount[hedger] == 0) {
            hedgerInfo.isActive = false;
            activeHedgers--;
        }

        usdc.safeTransfer(msg.sender, liquidationReward);

        if (remainingMargin > 0) {
            usdc.safeTransfer(hedger, remainingMargin);
        }

        emit HedgerLiquidated(
            hedger, 
            positionId, 
            msg.sender, 
            _packLiquidationData(liquidationReward, remainingMargin)
        );
    }

    function claimHedgingRewards() 
        external 
        nonReentrant 
        returns (uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards) 
    {
        address hedger = msg.sender;
        HedgerInfo storage hedgerInfo = hedgers[hedger];
        
        (uint256 newPendingRewards, uint256 newLastRewardBlock) = HedgerPoolLogicLibrary.calculateRewardUpdate(
            uint256(hedgerInfo.totalExposure), coreParams.eurInterestRate, coreParams.usdInterestRate,
            hedgerLastRewardBlock[hedger], block.number, MAX_REWARD_PERIOD, 
            uint256(hedgerInfo.pendingRewards)
        );
        
        hedgerInfo.pendingRewards = uint128(newPendingRewards);
        hedgerLastRewardBlock[hedger] = newLastRewardBlock;
        
        interestDifferential = hedgerInfo.pendingRewards;
        yieldShiftRewards = yieldShift.getHedgerPendingYield(hedger);
        totalRewards = interestDifferential + yieldShiftRewards;
        
        if (totalRewards > 0) {
            hedgerInfo.pendingRewards = 0;
            hedgerInfo.lastRewardClaim = uint64(TIME_PROVIDER.currentTime());
            
            if (yieldShiftRewards > 0) {
                uint256 claimedAmount = yieldShift.claimHedgerYield(hedger);
                if (claimedAmount == 0) revert ErrorLibrary.YieldClaimFailed();
            }
            
            usdc.safeTransfer(hedger, totalRewards);
            
            emit HedgingRewardsClaimed(
                hedger, 
                _packRewardData(interestDifferential, yieldShiftRewards, totalRewards)
            );
        }
    }

    function getHedgerPosition(address hedger, uint256 positionId) 
        external 
        view 
        returns (uint256 positionSize, uint256 margin, uint256 entryPrice, uint256 currentPrice, uint256 leverage, uint256 lastUpdateTime) 
    {
        HedgePosition storage position = positions[positionId];
        if (position.hedger != hedger) revert ErrorLibrary.InvalidHedger();
        
        uint256 oraclePrice = _getValidOraclePrice();
        
        return (
            position.positionSize,
            position.margin,
            position.entryPrice,
            oraclePrice,
            position.leverage,
            position.lastUpdateTime
        );
    }

    function getHedgerMarginRatio(address hedger, uint256 positionId) external view returns (uint256) {
        HedgePosition storage position = positions[positionId];
        if (position.hedger != hedger) revert ErrorLibrary.InvalidHedger();
        
        if (position.positionSize == 0) return 0;
        return uint256(position.margin).mulDiv(10000, uint256(position.positionSize));
    }

    function isHedgerLiquidatable(address hedger, uint256 positionId) external view returns (bool) {
        HedgePosition storage position = positions[positionId];
        if (position.hedger != hedger) revert ErrorLibrary.InvalidHedger();
        
        if (!position.isActive) return false;
        
        uint256 currentPrice = _getValidOraclePrice();
        return HedgerPoolLogicLibrary.isPositionLiquidatable(
            uint256(position.margin), uint256(position.positionSize), 
            uint256(position.entryPrice), currentPrice, coreParams.liquidationThreshold
        );
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
        _validateRole(GOVERNANCE_ROLE);
        if (newMinMarginRatio < 500) revert ErrorLibrary.ConfigValueTooLow();
        if (newLiquidationThreshold >= newMinMarginRatio) revert ErrorLibrary.ConfigInvalid();
        if (newMaxLeverage > 20) revert ErrorLibrary.ConfigValueTooHigh();
        if (newLiquidationPenalty > 1000) revert ErrorLibrary.ConfigValueTooHigh();

        coreParams.minMarginRatio = uint64(newMinMarginRatio);
        coreParams.liquidationThreshold = uint64(newLiquidationThreshold);
        coreParams.maxLeverage = uint16(newMaxLeverage);
        coreParams.liquidationPenalty = uint16(newLiquidationPenalty);
    }

    function updateInterestRates(uint256 newEurRate, uint256 newUsdRate) external {
        _validateRole(GOVERNANCE_ROLE);
        if (newEurRate > 2000 || newUsdRate > 2000) revert ErrorLibrary.ConfigValueTooHigh();
        
        coreParams.eurInterestRate = uint16(newEurRate);
        coreParams.usdInterestRate = uint16(newUsdRate);
    }

    function setHedgingFees(uint256 _entryFee, uint256 _exitFee, uint256 _marginFee) external {
        _validateRole(GOVERNANCE_ROLE);
        ValidationLibrary.validateFee(_entryFee, 100);
        ValidationLibrary.validateFee(_exitFee, 100);
        ValidationLibrary.validateFee(_marginFee, 50);

        coreParams.entryFee = uint16(_entryFee);
        coreParams.exitFee = uint16(_exitFee);
        coreParams.marginFee = uint16(_marginFee);
    }

    function emergencyClosePosition(address hedger, uint256 positionId) external {
        _validateRole(EMERGENCY_ROLE);
        
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
        
        // Check if hedger has no more active positions
        if (activePositionCount[hedger] == 0) {
            hedgerInfo.isActive = false;
            activeHedgers--;
        }
    }

    function pause() external {
        _validateRole(EMERGENCY_ROLE);
        _pause();
    }

    function unpause() external {
        _validateRole(EMERGENCY_ROLE);
        _unpause();
    }

    function hasPendingLiquidationCommitment(address hedger, uint256 positionId) external view returns (bool) {
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
        return (coreParams.minMarginRatio, coreParams.liquidationThreshold, coreParams.maxLeverage, coreParams.liquidationPenalty, coreParams.entryFee, coreParams.exitFee);
    }

    function marginFee() external view returns (uint256) {
        return coreParams.marginFee;
    }

    function getMaxValues() external pure returns (
        uint256 maxPositionSize,
        uint256 maxMargin,
        uint256 maxEntryPrice,
        uint256 maxLeverageValue,
        uint256 maxTotalMargin,
        uint256 maxTotalExposure,
        uint256 maxPendingRewards
    ) {
        return (MAX_POSITION_SIZE, MAX_MARGIN, MAX_ENTRY_PRICE, MAX_LEVERAGE, MAX_TOTAL_MARGIN, MAX_TOTAL_EXPOSURE, MAX_PENDING_REWARDS);
    }

    function isHedgingActive() external view returns (bool) {
        return !paused();
    }

    function clearExpiredLiquidationCommitment(address hedger, uint256 positionId) external {
        _validateRole(LIQUIDATOR_ROLE);
        if (block.number > lastLiquidationAttempt[hedger] + LIQUIDATION_COOLDOWN) {
            hasPendingLiquidation[hedger][positionId] = false;
        }
    }

    function cancelLiquidationCommitment(address hedger, uint256 positionId, bytes32 salt) external {
        _validateRole(LIQUIDATOR_ROLE);
        bytes32 commitment = HedgerPoolLogicLibrary.generateLiquidationCommitment(
            hedger, positionId, salt, msg.sender
        );
        ValidationLibrary.validateCommitment(liquidationCommitments[commitment]);
        
        delete liquidationCommitments[commitment];
        delete liquidationCommitmentTimes[commitment];
        hasPendingLiquidation[hedger][positionId] = false;
    }

    function recoverToken(address token, uint256 amount) external {
        _validateRole(DEFAULT_ADMIN_ROLE);
        TreasuryRecoveryLibrary.recoverToken(token, amount, address(this), treasury);
    }

    function recoverETH() external {
        _validateRole(DEFAULT_ADMIN_ROLE);
        emit ETHRecovered(treasury, address(this).balance);
        TreasuryRecoveryLibrary.recoverETH(treasury);
    }

    function updateTreasury(address _treasury) external {
        _validateRole(GOVERNANCE_ROLE);
        AccessControlLibrary.validateAddress(_treasury);
        ValidationLibrary.validateTreasuryAddress(_treasury);
        require(_treasury != address(0), "Treasury cannot be zero address");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    function updateVault(address _vault) external {
        _validateRole(GOVERNANCE_ROLE);
        AccessControlLibrary.validateAddress(_vault);
        vault = IQuantillonVault(_vault);
        emit VaultUpdated(_vault);
    }

    function whitelistHedger(address hedger) external {
        _validateRole(GOVERNANCE_ROLE);
        AccessControlLibrary.validateAddress(hedger);
        
        if (isWhitelistedHedger[hedger]) revert ErrorLibrary.AlreadyWhitelisted();
        
        isWhitelistedHedger[hedger] = true;
        _grantRole(HEDGER_ROLE, hedger);
        
        emit HedgerWhitelisted(hedger, msg.sender);
    }

    function removeHedger(address hedger) external {
        _validateRole(GOVERNANCE_ROLE);
        AccessControlLibrary.validateAddress(hedger);
        
        if (!isWhitelistedHedger[hedger]) revert ErrorLibrary.NotWhitelisted();
        
        isWhitelistedHedger[hedger] = false;
        _revokeRole(HEDGER_ROLE, hedger);
        
        emit HedgerRemoved(hedger, msg.sender);
    }

    function toggleHedgerWhitelistMode(bool enabled) external {
        _validateRole(GOVERNANCE_ROLE);
        hedgerWhitelistEnabled = enabled;
        emit HedgerWhitelistModeToggled(enabled, msg.sender);
    }

    function _getValidOraclePrice() internal view returns (uint256) {
        (uint256 price, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) revert ErrorLibrary.InvalidOraclePrice();
        return price;
    }

    function _validateRole(bytes32 role) internal view {
        if (role == GOVERNANCE_ROLE) {
            AccessControlLibrary.onlyGovernance(this);
        } else if (role == LIQUIDATOR_ROLE) {
            AccessControlLibrary.onlyLiquidatorRole(this);
        } else if (role == EMERGENCY_ROLE) {
            AccessControlLibrary.onlyEmergencyRole(this);
        } else if (role == DEFAULT_ADMIN_ROLE) {
            AccessControlLibrary.onlyAdmin(this);
        } else {
            revert("Invalid role");
        }
    }

    function _removePositionFromArrays(address hedger, uint256 positionId) internal {
        if (!hedgerHasPosition[hedger][positionId]) revert ErrorLibrary.PositionNotFound();
        
        uint256 index = positionIndex[hedger][positionId];
        uint256[] storage positionIds = hedgers[hedger].positionIds;
        uint256 lastIndex = positionIds.length - 1;
        
        if (index != lastIndex) {
            uint256 lastPositionId = positionIds[lastIndex];
            positionIds[index] = lastPositionId;
            positionIndex[hedger][lastPositionId] = index;
        }
        
        positionIds.pop();
        
        delete positionIndex[hedger][positionId];
        delete hedgerHasPosition[hedger][positionId];
    }
    
    /**
     * @notice Internal event data packing functions to reduce contract size
     */
    function _packPositionOpenData(
        uint256 positionSize,
        uint256 margin, 
        uint256 leverage,
        uint256 entryPrice
    ) internal pure returns (bytes32) {
        return bytes32(
            (uint256(uint64(positionSize)) << 192) |
            (uint256(uint64(margin)) << 128) |
            (uint256(uint32(leverage)) << 96) |
            uint256(uint96(entryPrice))
        );
    }
    
    function _packPositionCloseData(
        uint256 exitPrice,
        int256 pnl,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        uint256 absPnl = uint256(pnl < 0 ? -pnl : pnl);
        uint256 signFlag = pnl < 0 ? (1 << 63) : 0;
        return bytes32(
            (uint256(uint96(exitPrice)) << 160) |
            (uint256(uint96(absPnl)) << 64) |
            uint256(uint64(timestamp)) |
            signFlag
        );
    }
    
    function _packMarginData(
        uint256 marginAmount,
        uint256 newMarginRatio,
        bool isAdded
    ) internal pure returns (bytes32) {
        return bytes32(
            (uint256(uint128(marginAmount)) << 128) |
            (uint256(uint128(newMarginRatio)) << 1) |
            (isAdded ? 1 : 0)
        );
    }
    
    function _packLiquidationData(
        uint256 liquidationReward,
        uint256 remainingMargin
    ) internal pure returns (bytes32) {
        return bytes32(
            (uint256(uint128(liquidationReward)) << 128) |
            uint256(uint128(remainingMargin))
        );
    }
    
    function _packRewardData(
        uint256 interestDifferential,
        uint256 yieldShiftRewards,
        uint256 totalRewards
    ) internal pure returns (bytes32) {
        return bytes32(
            (uint256(uint128(interestDifferential)) << 128) |
            (uint256(uint64(yieldShiftRewards)) << 64) |
            uint256(uint64(totalRewards))
        );
    }

    /**
     * @notice Validates that closing a position won't cause protocol undercollateralization
     * @dev Checks if closing the position would make the protocol undercollateralized for QEURO minting
     * @param positionId The position ID being closed
     * @param positionMargin The margin amount of the position being closed
     * @custom:security Validates protocol collateralization status
     * @custom:validation Checks vault collateralization ratio
     * @custom:state-changes No state changes - validation only
     * @custom:events No events emitted
     * @custom:errors Throws PositionClosureRestricted if closure would cause undercollateralization
     * @custom:reentrancy Not protected - internal function only
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _validatePositionClosureSafety(uint256 positionId, uint256 positionMargin) internal view {
        // Skip validation if vault is not set (for backward compatibility)
        if (address(vault) == address(0)) {
            return;
        }

        // Get current protocol collateralization status
        (, uint256 currentTotalMargin) = vault.isProtocolCollateralized();
        
        // Get minimum collateralization ratio for minting
        uint256 minCollateralizationRatio = vault.minCollateralizationRatioForMinting();
        
        // Get UserPool total deposits
        address userPoolAddress = vault.userPool();
        uint256 userDeposits = 0;
        if (userPoolAddress != address(0)) {
            // Call totalDeposits on the UserPool contract
            (bool success, bytes memory data) = userPoolAddress.staticcall(
                abi.encodeWithSignature("totalDeposits()")
            );
            if (success && data.length >= 32) {
                userDeposits = abi.decode(data, (uint256));
            }
        }
        
        // Calculate what the collateralization ratio would be after closing this position
        uint256 remainingHedgerMargin = currentTotalMargin - positionMargin;
        
        // If no user deposits, hedger margin is the only collateral
        if (userDeposits == 0) {
            if (remainingHedgerMargin == 0) {
                revert ErrorLibrary.PositionClosureRestricted();
            }
            return; // If there's still hedger margin, it's safe
        }

        // Calculate future collateralization ratio
        uint256 futureRatio = ((userDeposits + remainingHedgerMargin) * 10000) / userDeposits;

        // Check if closing would make the protocol undercollateralized for minting
        if (futureRatio < minCollateralizationRatio) {
            revert ErrorLibrary.PositionClosureRestricted();
        }
    }
}