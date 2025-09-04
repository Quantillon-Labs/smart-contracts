// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IHedgerPool
 * @notice Interface for the Quantillon HedgerPool contract
 * @dev Provides EUR/USD hedging functionality with leverage and margin management
 * @custom:security-contact team@quantillon.money
 */
interface IHedgerPool {
    // Core hedging functions
    
    /**
     * @notice Opens a new hedge position with specified USDC amount and leverage
     * @param usdcAmount The amount of USDC to use for the position
     * @param leverage The leverage multiplier for the position (e.g., 5 for 5x leverage)
     * @return positionId The unique ID of the created position
     */
    function enterHedgePosition(uint256 usdcAmount, uint256 leverage) external returns (uint256 positionId);
    
    /**
     * @notice Closes an existing hedge position
     * @param positionId The ID of the position to close
     * @return pnl The profit or loss from the position (positive for profit, negative for loss)
     */
    function exitHedgePosition(uint256 positionId) external returns (int256 pnl);
    
    // Margin management
    
    /**
     * @notice Adds additional margin to an existing position
     * @param positionId The ID of the position to add margin to
     * @param amount The amount of USDC to add as margin
     */
    function addMargin(uint256 positionId, uint256 amount) external;
    
    /**
     * @notice Removes margin from an existing position
     * @param positionId The ID of the position to remove margin from
     * @param amount The amount of USDC margin to remove
     */
    function removeMargin(uint256 positionId, uint256 amount) external;
    
    // Liquidation system
    
    /**
     * @notice Commits to liquidating a position (first step of two-phase liquidation)
     * @param hedger The address of the hedger whose position will be liquidated
     * @param positionId The ID of the position to liquidate
     * @param salt A random value to prevent front-running
     */
    function commitLiquidation(address hedger, uint256 positionId, bytes32 salt) external;
    
    /**
     * @notice Executes the liquidation of a position (second step of two-phase liquidation)
     * @param hedger The address of the hedger whose position is being liquidated
     * @param positionId The ID of the position to liquidate
     * @param salt The same salt value used in the commitment
     * @return liquidationReward The reward paid to the liquidator
     */
    function liquidateHedger(address hedger, uint256 positionId, bytes32 salt) external returns (uint256 liquidationReward);
    
    /**
     * @notice Checks if there's a pending liquidation commitment for a position
     * @param hedger The address of the hedger
     * @param positionId The ID of the position
     * @return bool True if there's a pending liquidation commitment
     */
    function hasPendingLiquidationCommitment(address hedger, uint256 positionId) external view returns (bool);
    function clearExpiredLiquidationCommitment(address hedger, uint256 positionId) external;
    function cancelLiquidationCommitment(address hedger, uint256 positionId, bytes32 salt) external;
    
    // Rewards
    function claimHedgingRewards() external returns (uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards);
    
    // View functions
    function getHedgerPosition(address hedger, uint256 positionId) external view returns (
        uint256 positionSize,
        uint256 margin,
        uint256 entryPrice,
        uint256 currentPrice,
        uint256 leverage,
        uint256 lastUpdateTime
    );
    
    function getHedgerMarginRatio(address hedger, uint256 positionId) external view returns (uint256);
    function isHedgerLiquidatable(address hedger, uint256 positionId) external view returns (bool);
    function getTotalHedgeExposure() external view returns (uint256);

    
    // Governance functions
    function updateHedgingParameters(
        uint256 newMinMarginRatio,
        uint256 newLiquidationThreshold,
        uint256 newMaxLeverage,
        uint256 newLiquidationPenalty
    ) external;
    
    function updateInterestRates(uint256 newEurRate, uint256 newUsdRate) external;
    function setHedgingFees(uint256 _entryFee, uint256 _exitFee, uint256 _marginFee) external;
    /**
     * @notice Get hedging configuration parameters
     * @return _minMarginRatio Minimum margin ratio
     * @return _liquidationThreshold Liquidation threshold
     * @return _maxLeverage Maximum leverage
     * @return _liquidationPenalty Liquidation penalty
     * @return _entryFee Entry fee
     * @return _exitFee Exit fee
     */
    function getHedgingConfig() external view returns (
        uint256 _minMarginRatio,
        uint256 _liquidationThreshold,
        uint256 _maxLeverage,
        uint256 _liquidationPenalty,
        uint256 _entryFee,
        uint256 _exitFee
    );
    
    // Emergency functions
    function emergencyClosePosition(address hedger, uint256 positionId) external;
    function pause() external;
    function unpause() external;
    function isHedgingActive() external view returns (bool);
    
    // Recovery functions
    function recoverToken(address token, address to, uint256 amount) external;
    function recoverETH() external;
    
    // State variables
    function usdc() external view returns (IERC20);
    function oracle() external view returns (address);
    function yieldShift() external view returns (address);
    function minMarginRatio() external view returns (uint256);
    function liquidationThreshold() external view returns (uint256);
    function maxLeverage() external view returns (uint256);
    function liquidationPenalty() external view returns (uint256);
    function entryFee() external view returns (uint256);
    function exitFee() external view returns (uint256);
    function marginFee() external view returns (uint256);
    function totalMargin() external view returns (uint256);
    function totalExposure() external view returns (uint256);
    function activeHedgers() external view returns (uint256);
    function nextPositionId() external view returns (uint256);
    function eurInterestRate() external view returns (uint256);
    function usdInterestRate() external view returns (uint256);
    function totalYieldEarned() external view returns (uint256);
    function interestDifferentialPool() external view returns (uint256);
    function activePositionCount(address) external view returns (uint256);
    function positions(uint256) external view returns (
        address hedger,
        uint256 positionSize,
        uint256 margin,
        uint256 entryPrice,
        uint256 leverage,
        uint256 entryTime,
        uint256 lastUpdateTime,
        int256 unrealizedPnL,
        bool isActive
    );
    /**
     * @notice Get hedger information
     * @return positionIds Array of position IDs
     * @return _totalMargin Total margin
     * @return _totalExposure Total exposure
     * @return pendingRewards Pending rewards
     * @return lastRewardClaim Last reward claim time
     * @return isActive Whether hedger is active
     */
    function hedgers(address) external view returns (
        uint256[] memory positionIds,
        uint256 _totalMargin,
        uint256 _totalExposure,
        uint256 pendingRewards,
        uint256 lastRewardClaim,
        bool isActive
    );
    function hedgerPositions(address) external view returns (uint256[] memory);
    function userPendingYield(address) external view returns (uint256);
    function hedgerPendingYield(address) external view returns (uint256);
    function userLastClaim(address) external view returns (uint256);
    function hedgerLastClaim(address) external view returns (uint256);
    function hedgerLastRewardBlock(address) external view returns (uint256);
    function liquidationCommitments(bytes32) external view returns (bool);
    function liquidationCommitmentTimes(bytes32) external view returns (uint256);
    function lastLiquidationAttempt(address) external view returns (uint256);
    function hasPendingLiquidation(address, uint256) external view returns (bool);
    
    // Constants
    function MAX_POSITIONS_PER_HEDGER() external view returns (uint256);
    function BLOCKS_PER_DAY() external view returns (uint256);
    function MAX_REWARD_PERIOD() external view returns (uint256);
    function LIQUIDATION_COOLDOWN() external view returns (uint256);
    
    // Events
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
} 