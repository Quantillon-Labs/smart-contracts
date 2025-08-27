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
import "./SecureUpgradeable.sol";

contract HedgerPool is 
    Initializable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    SecureUpgradeable
{
    using SafeERC20 for IERC20;
    using VaultMath for uint256;

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    IERC20 public usdc;
    IChainlinkOracle public oracle;
    IYieldShift public yieldShift;

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

    struct HedgePosition {
        address hedger;
        uint256 positionSize;
        uint256 margin;
        uint256 entryPrice;
        uint256 leverage;
        uint256 entryTime;
        uint256 lastUpdateTime;
        int256 unrealizedPnL;
        bool isActive;
    }

    struct HedgerInfo {
        uint256[] positionIds;
        uint256 totalMargin;
        uint256 totalExposure;
        uint256 pendingRewards;
        uint256 lastRewardClaim;
        bool isActive;
    }

    mapping(uint256 => HedgePosition) public positions;
    mapping(address => HedgerInfo) public hedgers;
    mapping(address => uint256[]) public hedgerPositions;

    uint256 public totalYieldEarned;
    uint256 public interestDifferentialPool;

    mapping(address => uint256) public userPendingYield;
    mapping(address => uint256) public hedgerPendingYield;
    mapping(address => uint256) public userLastClaim;
    mapping(address => uint256) public hedgerLastClaim;
    
    mapping(address => uint256) public hedgerLastRewardBlock;
    uint256 public constant BLOCKS_PER_DAY = 7200;
    uint256 public constant MAX_REWARD_PERIOD = 365 days;

    uint256 public constant LIQUIDATION_COOLDOWN = 1 hours;
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

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin,
        address _usdc,
        address _oracle,
        address _yieldShift,
        address timelock
    ) public initializer {
        require(admin != address(0), "HedgerPool: Admin cannot be zero");
        require(_usdc != address(0), "HedgerPool: USDC cannot be zero");
        require(_oracle != address(0), "HedgerPool: Oracle cannot be zero");
        require(_yieldShift != address(0), "HedgerPool: YieldShift cannot be zero");

        __ReentrancyGuard_init();
        __AccessControl_init();
        __Pausable_init();
        __SecureUpgradeable_init(timelock);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);

        usdc = IERC20(_usdc);
        oracle = IChainlinkOracle(_oracle);
        yieldShift = IYieldShift(_yieldShift);

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
        returns (uint256 positionId) 
    {
        require(usdcAmount > 0, "HedgerPool: Amount must be positive");
        require(leverage <= maxLeverage, "HedgerPool: Leverage too high");
        require(leverage > 0, "HedgerPool: Leverage must be positive");
        require(
            activePositionCount[msg.sender] < MAX_POSITIONS_PER_HEDGER,
            "HedgerPool: Too many active positions"
        );

        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "HedgerPool: Invalid EUR/USD price");

        uint256 fee = usdcAmount.percentageOf(entryFee);
        uint256 netMargin = usdcAmount - fee;
        uint256 positionSize = netMargin.mulDiv(leverage, 1);
        uint256 marginRatio = netMargin.mulDiv(10000, positionSize);
        require(marginRatio >= minMarginRatio, "HedgerPool: Insufficient margin ratio");

        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);

        positionId = nextPositionId++;
        
        HedgePosition storage position = positions[positionId];
        position.hedger = msg.sender;
        position.positionSize = positionSize;
        position.margin = netMargin;
        position.entryTime = block.timestamp;
        position.lastUpdateTime = block.timestamp;
        position.leverage = leverage;
        position.entryPrice = eurUsdPrice;
        position.unrealizedPnL = 0;
        position.isActive = true;

        HedgerInfo storage hedger = hedgers[msg.sender];
        if (!hedger.isActive) {
            hedger.isActive = true;
            activeHedgers++;
        }
        
        hedger.positionIds.push(positionId);
        hedger.totalMargin += netMargin;
        hedger.totalExposure += positionSize;
        hedgerPositions[msg.sender].push(positionId);

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
        returns (int256 pnl) 
    {
        HedgePosition storage position = positions[positionId];
        require(position.hedger == msg.sender, "HedgerPool: Not position owner");
        require(position.isActive, "HedgerPool: Position not active");

        (uint256 currentPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "HedgerPool: Invalid EUR/USD price");

        pnl = _calculatePnL(position, currentPrice);

        uint256 grossPayout = uint256(int256(position.margin) + pnl);
        uint256 exitFeeAmount = grossPayout.percentageOf(exitFee);
        uint256 netPayout = grossPayout - exitFeeAmount;

        HedgerInfo storage hedger = hedgers[msg.sender];
        hedger.totalMargin -= position.margin;
        hedger.totalExposure -= position.positionSize;

        totalMargin -= position.margin;
        totalExposure -= position.positionSize;

        position.isActive = false;
        _removePositionFromArrays(msg.sender, positionId);
        
        activePositionCount[msg.sender]--;

        if (netPayout > 0) {
            usdc.safeTransfer(msg.sender, netPayout);
        }

        emit HedgePositionClosed(msg.sender, positionId, currentPrice, pnl, block.timestamp);
    }

    function _removePositionFromArrays(address hedger, uint256 positionId) internal {
        unchecked {
            uint256[] storage positionIds = hedgers[hedger].positionIds;
            uint256 positionIdsLength = positionIds.length;
            for (uint256 i = 0; i < positionIdsLength; i++) {
                if (positionIds[i] == positionId) {
                    positionIds[i] = positionIds[positionIdsLength - 1];
                    positionIds.pop();
                    break;
                }
            }
            
            uint256[] storage hedgerPos = hedgerPositions[hedger];
            uint256 hedgerPosLength = hedgerPos.length;
            for (uint256 i = 0; i < hedgerPosLength; i++) {
                if (hedgerPos[i] == positionId) {
                    hedgerPos[i] = hedgerPos[hedgerPosLength - 1];
                    hedgerPos.pop();
                    break;
                }
            }
        }
    }

    function addMargin(uint256 positionId, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        HedgePosition storage position = positions[positionId];
        require(position.hedger == msg.sender, "HedgerPool: Not position owner");
        require(position.isActive, "HedgerPool: Position not active");
        require(amount > 0, "HedgerPool: Amount must be positive");
        
        require(
            block.timestamp >= lastLiquidationAttempt[msg.sender] + LIQUIDATION_COOLDOWN,
            "HedgerPool: Cannot add margin during liquidation cooldown"
        );
        
        require(
            !_hasPendingLiquidationCommitment(msg.sender, positionId),
            "HedgerPool: Cannot add margin with pending liquidation commitment"
        );

        uint256 fee = amount.percentageOf(marginFee);
        uint256 netAmount = amount - fee;

        usdc.safeTransferFrom(msg.sender, address(this), amount);

        position.margin += netAmount;

        hedgers[msg.sender].totalMargin += netAmount;
        totalMargin += netAmount;

        uint256 newMarginRatio = position.margin.mulDiv(10000, position.positionSize);

        emit MarginAdded(msg.sender, positionId, netAmount, newMarginRatio);
    }

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

        uint256 newMargin = position.margin - amount;
        uint256 newMarginRatio = newMargin.mulDiv(10000, position.positionSize);
        require(newMarginRatio >= minMarginRatio, "HedgerPool: Would breach minimum margin");

        position.margin = newMargin;

        hedgers[msg.sender].totalMargin -= amount;
        totalMargin -= amount;

        usdc.safeTransfer(msg.sender, amount);

        emit MarginRemoved(msg.sender, positionId, amount, newMarginRatio);
    }

    function commitLiquidation(
        address hedger,
        uint256 positionId,
        bytes32 salt
    ) external onlyRole(LIQUIDATOR_ROLE) {
        require(hedger != address(0), "HedgerPool: Invalid hedger address");
        require(positionId > 0, "HedgerPool: Invalid position ID");
        
        bytes32 commitment = keccak256(abi.encodePacked(hedger, positionId, salt, msg.sender));
        require(!liquidationCommitments[commitment], "HedgerPool: Commitment already exists");
        
        liquidationCommitments[commitment] = true;
        liquidationCommitmentTimes[commitment] = block.timestamp;
        
        hasPendingLiquidation[hedger][positionId] = true;
        lastLiquidationAttempt[hedger] = block.timestamp;
    }

    function liquidateHedger(
        address hedger, 
        uint256 positionId,
        bytes32 salt
    ) external onlyRole(LIQUIDATOR_ROLE) nonReentrant returns (uint256 liquidationReward) {
        HedgePosition storage position = positions[positionId];
        require(position.hedger == hedger, "HedgerPool: Invalid hedger");
        require(position.isActive, "HedgerPool: Position not active");

        bytes32 commitment = keccak256(abi.encodePacked(hedger, positionId, salt, msg.sender));
        require(liquidationCommitments[commitment], "HedgerPool: No valid commitment");
        
        delete liquidationCommitments[commitment];
        delete liquidationCommitmentTimes[commitment];
        hasPendingLiquidation[hedger][positionId] = false;

        require(_isPositionLiquidatable(positionId), "HedgerPool: Position not liquidatable");

        (, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "HedgerPool: Invalid EUR/USD price");

        liquidationReward = position.margin.percentageOf(liquidationPenalty);
        uint256 remainingMargin = position.margin - liquidationReward;

        HedgerInfo storage hedgerInfo = hedgers[hedger];
        hedgerInfo.totalMargin -= position.margin;
        hedgerInfo.totalExposure -= position.positionSize;

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
            hedgerInfo.lastRewardClaim = block.timestamp;
            
            if (yieldShiftRewards > 0) {
                yieldShift.claimHedgerYield(hedger);
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
            
            if (lastRewardBlock == 0) {
                hedgerLastRewardBlock[hedger] = currentBlock;
                return;
            }
            
            uint256 blocksElapsed = currentBlock - lastRewardBlock;
            uint256 timeElapsed = blocksElapsed * 12;
            
            if (timeElapsed > MAX_REWARD_PERIOD) {
                timeElapsed = MAX_REWARD_PERIOD;
            }
            
            uint256 interestDifferential = usdInterestRate > eurInterestRate ? 
                usdInterestRate - eurInterestRate : 0;
            
            uint256 reward = hedgerInfo.totalExposure
                .mulDiv(interestDifferential, 10000)
                .mulDiv(timeElapsed, 365 days);
            
            uint256 newPendingRewards = hedgerInfo.pendingRewards + reward;
            require(newPendingRewards >= hedgerInfo.pendingRewards, "HedgerPool: Reward overflow");
            hedgerInfo.pendingRewards = newPendingRewards;
            
            hedgerLastRewardBlock[hedger] = currentBlock;
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
        int256 priceChange = int256(position.entryPrice) - int256(currentPrice);
        
        if (priceChange >= 0) {
            uint256 absPriceChange = uint256(priceChange);
            uint256 intermediate = position.positionSize.mulDiv(absPriceChange, position.entryPrice);
            return int256(intermediate);
        } else {
            uint256 absPriceChange = uint256(-priceChange);
            uint256 intermediate = position.positionSize.mulDiv(absPriceChange, position.entryPrice);
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
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(newMinMarginRatio >= 500, "HedgerPool: Min margin too low");
        require(newLiquidationThreshold < newMinMarginRatio, "HedgerPool: Invalid thresholds");
        require(newMaxLeverage <= 20, "HedgerPool: Max leverage too high");
        require(newLiquidationPenalty <= 1000, "HedgerPool: Penalty too high");

        minMarginRatio = newMinMarginRatio;
        liquidationThreshold = newLiquidationThreshold;
        maxLeverage = newMaxLeverage;
        liquidationPenalty = newLiquidationPenalty;
    }

    function updateInterestRates(uint256 newEurRate, uint256 newUsdRate) 
        external 
        onlyRole(GOVERNANCE_ROLE) 
    {
        require(newEurRate <= 2000 && newUsdRate <= 2000, "HedgerPool: Rates too high");
        
        eurInterestRate = newEurRate;
        usdInterestRate = newUsdRate;
    }

    function setHedgingFees(
        uint256 _entryFee,
        uint256 _exitFee,
        uint256 _marginFee
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(_entryFee <= 100, "HedgerPool: Entry fee too high");
        require(_exitFee <= 100, "HedgerPool: Exit fee too high");
        require(_marginFee <= 50, "HedgerPool: Margin fee too high");

        entryFee = _entryFee;
        exitFee = _exitFee;
        marginFee = _marginFee;
    }

    function emergencyClosePosition(address hedger, uint256 positionId) 
        external 
        onlyRole(EMERGENCY_ROLE) 
    {
        HedgePosition storage position = positions[positionId];
        require(position.hedger == hedger, "HedgerPool: Invalid hedger");
        require(position.isActive, "HedgerPool: Position not active");

        HedgerInfo storage hedgerInfo = hedgers[hedger];
        hedgerInfo.totalMargin -= position.margin;
        hedgerInfo.totalExposure -= position.positionSize;

        totalMargin -= position.margin;
        totalExposure -= position.positionSize;

        usdc.safeTransfer(hedger, position.margin);

        position.isActive = false;
        _removePositionFromArrays(hedger, positionId);
        
        activePositionCount[hedger]--;
    }

    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(EMERGENCY_ROLE) {
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

    function clearExpiredLiquidationCommitment(address hedger, uint256 positionId) 
        external 
        onlyRole(LIQUIDATOR_ROLE) 
    {
        if (block.timestamp > lastLiquidationAttempt[hedger] + 1 hours) {
            hasPendingLiquidation[hedger][positionId] = false;
        }
    }

    function cancelLiquidationCommitment(address hedger, uint256 positionId, bytes32 salt) 
        external 
        onlyRole(LIQUIDATOR_ROLE) 
    {
        bytes32 commitment = keccak256(abi.encodePacked(hedger, positionId, salt, msg.sender));
        require(liquidationCommitments[commitment], "HedgerPool: Commitment does not exist");
        
        delete liquidationCommitments[commitment];
        delete liquidationCommitmentTimes[commitment];
        hasPendingLiquidation[hedger][positionId] = false;
    }



    function _hasPendingLiquidationCommitment(address hedger, uint256 positionId) internal view returns (bool) {
        return hasPendingLiquidation[hedger][positionId];
    }

    function recoverToken(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(usdc) && to != address(0), "HedgerPool: Invalid params");
        
        IERC20(token).safeTransfer(to, amount);
    }

    function recoverETH(address payable to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(to != address(0), "HedgerPool: Cannot send to zero address");
        
        uint256 balance = address(this).balance;
        require(balance > 0, "HedgerPool: No ETH to recover");
        
        (bool success, ) = to.call{value: balance}("");
        require(success, "HedgerPool: ETH transfer failed");
    }
}