// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IHedgerPool
 * @notice Interface for the HedgerPool managing hedging positions and rewards
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
interface IHedgerPool {
    /**
     * @notice Initializes the hedger pool
     * @param admin Admin address
     * @param _usdc USDC token address
     * @param _oracle Oracle contract address
     * @param _yieldShift YieldShift contract address
     */
    function initialize(address admin, address _usdc, address _oracle, address _yieldShift) external;

    /**
     * @notice Enter a new hedging position
     * @param usdcAmount Margin amount in USDC
     * @param leverage Desired leverage (<= max)
     * @return positionId New position ID
     */
    function enterHedgePosition(uint256 usdcAmount, uint256 leverage) external returns (uint256 positionId);

    /**
     * @notice Exit an existing hedging position fully
     * @param positionId Position identifier
     */
    function exitHedgePosition(uint256 positionId) external;

    /**
     * @notice Close part of a hedging position
     * @param positionId Position identifier
     * @param percentage Percentage (bps) to close
     */
    function partialClosePosition(uint256 positionId, uint256 percentage) external;

    /**
     * @notice Add margin to a position
     * @param positionId Position identifier
     * @param amount Amount of USDC to add
     */
    function addMargin(uint256 positionId, uint256 amount) external;

    /**
     * @notice Remove margin from a position if safe
     * @param positionId Position identifier
     * @param amount Amount of USDC to remove
     */
    function removeMargin(uint256 positionId, uint256 amount) external;

    /**
     * @notice Commit to a liquidation to prevent front-running
     * @param hedger Address of the hedger to liquidate
     * @param positionId Position ID to liquidate
     * @param salt Random salt for commitment
     */
    function commitLiquidation(address hedger, uint256 positionId, bytes32 salt) external;

    /**
     * @notice Liquidate an unsafe position with front-running protection
     * @param hedger Owner of the position
     * @param positionId Position identifier
     * @param salt Salt used in the commitment
     * @return liquidationReward Amount of liquidation reward
     */
    function liquidateHedger(address hedger, uint256 positionId, bytes32 salt) external returns (uint256 liquidationReward);

    /**
     * @notice Claim accumulated hedging rewards (only own rewards)
     * @return interestDifferential Interest differential amount
     * @return yieldShiftRewards Rewards from YieldShift
     * @return totalRewards Total rewards claimed
     * @dev SECURITY: Only hedgers can claim their own rewards (msg.sender == hedger)
     */
    function claimHedgingRewards() external returns (
        uint256 interestDifferential,
        uint256 yieldShiftRewards,
        uint256 totalRewards
    );

    /**
     * @notice Get a hedger position details
     * @param hedger Hedger address
     * @param positionId Position identifier
     * @return positionSize Current position size
     * @return margin Current margin
     * @return entryPrice Entry price
     * @return leverage Leverage
     * @return entryTime Entry timestamp
     * @return lastUpdateTime Last update timestamp
     * @return unrealizedPnL Current unrealized PnL
     * @return isActive Active flag
     */
    function getHedgerPosition(address hedger, uint256 positionId) external view returns (
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
     * @notice Get current margin ratio for a position
     * @param hedger Hedger address
     * @param positionId Position identifier
     * @return Margin ratio in basis points
     */
    function getHedgerMarginRatio(address hedger, uint256 positionId) external view returns (uint256);

    /**
     * @notice Check if a position is liquidatable
     * @param hedger Hedger address
     * @param positionId Position identifier
     * @return True if liquidatable
     */
    function isHedgerLiquidatable(address hedger, uint256 positionId) external view returns (bool);

    /**
     * @notice Get position statistics for a hedger
     * @param hedger Address of the hedger
     * @return totalPositions Total number of positions (active + inactive)
     * @return activePositions Number of active positions
     * @return totalMargin_ Total margin across all positions
     * @return totalExposure_ Total exposure across all positions
     */
    function getHedgerPositionStats(address hedger) external view returns (
        uint256 totalPositions,
        uint256 activePositions,
        uint256 totalMargin_,
        uint256 totalExposure_
    );

    /**
     * @notice Total hedge exposure in the pool
     */
    function getTotalHedgeExposure() external view returns (uint256);

    /**
     * @notice Pool statistics snapshot
     * @return activeHedgers_ Number of active hedgers
     * @return totalPositions Total number of positions
     * @return averagePosition Average position size
     * @return totalMargin_ Total margin
     * @return poolUtilization Pool utilization ratio (bps)
     */
    function getPoolStatistics() external view returns (
        uint256 activeHedgers_,
        uint256 totalPositions,
        uint256 averagePosition,
        uint256 totalMargin_,
        uint256 poolUtilization
    );

    /**
     * @notice Pending hedging rewards for a hedger
     * @param hedger Hedger address
     * @return interestDifferential Pending interest differential
     * @return yieldShiftRewards Pending YieldShift rewards
     * @return totalRewards Total pending rewards
     */
    function getPendingHedgingRewards(address hedger) external view returns (
        uint256 interestDifferential,
        uint256 yieldShiftRewards,
        uint256 totalRewards
    );

    /**
     * @notice Update hedging parameters
     * @param _minMarginRatio Minimum margin ratio (bps)
     * @param _liquidationThreshold Liquidation threshold (bps)
     * @param _maxLeverage Maximum leverage
     * @param _liquidationPenalty Liquidation penalty (bps)
     */
    function updateHedgingParameters(
        uint256 _minMarginRatio,
        uint256 _liquidationThreshold,
        uint256 _maxLeverage,
        uint256 _liquidationPenalty
    ) external;

    /**
     * @notice Update interest rates
     * @param newEurRate EUR rate (bps)
     * @param newUsdRate USD rate (bps)
     */
    function updateInterestRates(uint256 newEurRate, uint256 newUsdRate) external;

    /**
     * @notice Set hedging fees
     * @param _entryFee Entry fee (bps)
     * @param _exitFee Exit fee (bps)
     * @param _marginFee Margin fee (bps)
     */
    function setHedgingFees(uint256 _entryFee, uint256 _exitFee, uint256 _marginFee) external;

    /**
     * @notice Emergency close a position by admin
     * @param hedger Hedger address
     * @param positionId Position identifier
     */
    function emergencyClosePosition(address hedger, uint256 positionId) external;

    /**
     * @notice Pause hedger pool operations
     */
    function pause() external;

    /**
     * @notice Unpause hedger pool operations
     */
    function unpause() external;

    /**
     * @notice Hedging configuration snapshot
     * @return minMarginRatio Minimum margin ratio (bps)
     * @return liquidationThreshold Liquidation threshold (bps)
     * @return maxLeverage Maximum leverage
     * @return liquidationPenalty Liquidation penalty (bps)
     * @return entryFee Entry fee (bps)
     * @return exitFee Exit fee (bps)
     * @return marginFee Margin fee (bps)
     */
    function getHedgingConfig() external view returns (
        uint256 minMarginRatio,
        uint256 liquidationThreshold,
        uint256 maxLeverage,
        uint256 liquidationPenalty,
        uint256 entryFee,
        uint256 exitFee,
        uint256 marginFee
    );

    /**
     * @notice Whether hedging operations are active (not paused)
     */
    function isHedgingActive() external view returns (bool);

    /**
     * @notice Check if a hedger has pending liquidation commitments
     * @param hedger Address of the hedger
     * @param positionId Position ID to check
     * @return bool True if there are pending liquidation commitments
     * 

     */
    function hasPendingLiquidationCommitment(address hedger, uint256 positionId) external view returns (bool);

    /**
     * @notice Clear expired liquidation commitments for a hedger/position
     * @param hedger Address of the hedger
     * @param positionId Position ID
     * @dev This function allows clearing of expired commitments that were never executed
     * @dev Only callable by liquidators or governance
     * @dev Note: With immediate execution, this is mainly for cleanup of stale commitments
     */
    function clearExpiredLiquidationCommitment(address hedger, uint256 positionId) external;

    /**
     * @notice Cancel a liquidation commitment (only by the liquidator who created it)
     * @param hedger Address of the hedger
     * @param positionId Position ID
     * @param salt Salt used in the original commitment
     * @dev This function allows liquidators to cancel their own commitments
     * @dev Only callable by the liquidator who created the commitment
     */
    function cancelLiquidationCommitment(address hedger, uint256 positionId, bytes32 salt) external;

    // AccessControl functions
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address callerConfirmation) external;

    // Pausable functions
    function paused() external view returns (bool);

    // UUPS functions
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;

    // Constants
    function GOVERNANCE_ROLE() external view returns (bytes32);
    function LIQUIDATOR_ROLE() external view returns (bytes32);
    function EMERGENCY_ROLE() external view returns (bytes32);
    function UPGRADER_ROLE() external view returns (bytes32);
    function MAX_POSITIONS_PER_HEDGER() external view returns (uint256);
    function LIQUIDATION_COOLDOWN() external view returns (uint256);
    function BLOCKS_PER_DAY() external view returns (uint256);
    function MAX_REWARD_PERIOD() external view returns (uint256);

    // State variables
    function usdc() external view returns (address);
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
    function userPendingYield(address) external view returns (uint256);
    function hedgerPendingYield(address) external view returns (uint256);
    function userLastClaim(address) external view returns (uint256);
    function hedgerLastClaim(address) external view returns (uint256);
    function hedgerLastRewardBlock(address) external view returns (uint256);
    function activePositionCount(address) external view returns (uint256);
    function liquidationCommitments(bytes32) external view returns (bool);
    function liquidationCommitmentTimes(bytes32) external view returns (uint256);
    function lastLiquidationAttempt(address) external view returns (uint256);
    function hasPendingLiquidation(address, uint256) external view returns (bool);
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
    function hedgers(address) external view returns (
        uint256[] memory positionIds,
        uint256 totalMargin,
        uint256 totalExposure,
        uint256 pendingRewards,
        uint256 lastRewardClaim,
        bool isActive
    );
    function hedgerPositions(address) external view returns (uint256[] memory);

    // Recovery functions
    function recoverToken(address token, address to, uint256 amount) external;
    function recoverETH(address payable to) external;
} 