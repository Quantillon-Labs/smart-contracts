// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IHedgerPool
 * @notice Interface for the Quantillon HedgerPool contract
 * @dev Provides EUR/USD hedging functionality with leverage and margin management
 * @custom:security-contact team@quantillon.money
 */
interface IHedgerPool {
    // Initialization
    
    /**
     * @notice Initializes the HedgerPool with contracts and parameters
     * @dev Sets up the HedgerPool with initial configuration and assigns roles to admin
     * @param admin Admin address receiving roles
     * @param _usdc USDC token address
     * @param _oracle Oracle contract address
     * @param _yieldShift YieldShift contract address
     * @param _timelock Timelock contract address
     * @param _treasury Treasury address
     * @param _vault QuantillonVault contract address
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Initializes all contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by initializer modifier
     * @custom:access Restricted to initializer modifier
     * @custom:oracle No oracle dependencies
     */
    function initialize(address admin, address _usdc, address _oracle, address _yieldShift, address _timelock, address _treasury, address _vault) external;
    
    // Core hedging functions
    
    /**
     * @notice Opens a new hedge position with specified USDC amount and leverage
     * @dev Creates a new hedge position with margin requirements and leverage validation
     * @param usdcAmount The amount of USDC to use for the position (6 decimals)
     * @param leverage The leverage multiplier for the position (e.g., 5 for 5x leverage)
     * @return positionId The unique ID of the created position
     * @custom:security Validates oracle price freshness, enforces margin ratios and leverage limits
     * @custom:validation Validates usdcAmount > 0, leverage <= maxLeverage, position count limits
     * @custom:state-changes Creates new HedgePosition, updates hedger totals, increments position counters
     * @custom:events Emits HedgePositionOpened with position details
     * @custom:errors Throws InvalidAmount if amount is 0, LeverageTooHigh if exceeds max
     * @custom:reentrancy Protected by secureNonReentrant modifier
     * @custom:access Public - no access restrictions
     * @custom:oracle Requires fresh EUR/USD price for position entry
     */
    function enterHedgePosition(uint256 usdcAmount, uint256 leverage) external returns (uint256 positionId);
    
    /**
     * @notice Closes an existing hedge position
     * @dev Closes a hedge position and calculates PnL based on current EUR/USD price
     * @param positionId The ID of the position to close
     * @return pnl The profit or loss from the position (positive for profit, negative for loss)
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function exitHedgePosition(uint256 positionId) external returns (int256 pnl);
    
    // Margin management
    
    /**
     * @notice Adds additional margin to an existing position
     * @dev Adds USDC margin to an existing hedge position to improve margin ratio
     * @param positionId The ID of the position to add margin to
     * @param amount The amount of USDC to add as margin
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function addMargin(uint256 positionId, uint256 amount) external;
    
    /**
     * @notice Removes margin from an existing position
     * @dev Removes USDC margin from an existing hedge position, subject to minimum margin requirements
     * @param positionId The ID of the position to remove margin from
     * @param amount The amount of USDC margin to remove
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function removeMargin(uint256 positionId, uint256 amount) external;
    
    // Liquidation system
    
    /**
     * @notice Commits to liquidating a position (first step of two-phase liquidation)
     * @dev Commits to liquidating an undercollateralized position using a two-phase commit-reveal scheme
     * @param hedger The address of the hedger whose position will be liquidated
     * @param positionId The ID of the position to liquidate
     * @param salt A random value to prevent front-running
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function commitLiquidation(address hedger, uint256 positionId, bytes32 salt) external;
    
    /**
     * @notice Executes the liquidation of a position (second step of two-phase liquidation)
     * @dev Executes liquidation after valid commitment, transfers rewards and remaining margin
     * @param hedger The address of the hedger whose position is being liquidated
     * @param positionId The ID of the position to liquidate
     * @param salt The same salt value used in the commitment
     * @return liquidationReward The reward paid to the liquidator
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function liquidateHedger(address hedger, uint256 positionId, bytes32 salt) external returns (uint256 liquidationReward);
    
    /**
     * @notice Checks if there's a pending liquidation commitment for a position
     * @dev Used to prevent margin operations during liquidation process
     * @param hedger The address of the hedger
     * @param positionId The ID of the position
     * @return bool True if there's a pending liquidation commitment
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function hasPendingLiquidationCommitment(address hedger, uint256 positionId) external view returns (bool);
    /**
     * @notice Clears expired liquidation commitments
     * @dev Removes liquidation commitments that have expired beyond the commitment window
     * @param hedger The address of the hedger
     * @param positionId The ID of the position
     * @custom:security Validates liquidator role and commitment expiration
     * @custom:validation Validates commitment exists and has expired
     * @custom:state-changes Removes expired liquidation commitment
     * @custom:events No events emitted for commitment clearing
     * @custom:errors Throws CommitmentNotFound if commitment doesn't exist
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to LIQUIDATOR_ROLE
     * @custom:oracle No oracle dependencies
     */
    function clearExpiredLiquidationCommitment(address hedger, uint256 positionId) external;
    
    /**
     * @notice Cancels a pending liquidation commitment
     * @dev Allows hedgers to cancel their liquidation commitment before execution
     * @param hedger The hedger address
     * @param positionId The position ID to cancel liquidation for
     * @param salt Same salt used in commitLiquidation for commitment verification
     * @custom:security Validates liquidator role and commitment exists
     * @custom:validation Validates commitment hash matches stored commitment
     * @custom:state-changes Deletes liquidation commitment and pending liquidation flag
     * @custom:events No events emitted for commitment cancellation
     * @custom:errors Throws CommitmentNotFound if commitment doesn't exist
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to LIQUIDATOR_ROLE
     * @custom:oracle No oracle dependencies
     */
    function cancelLiquidationCommitment(address hedger, uint256 positionId, bytes32 salt) external;
    
    // Rewards
    
    /**
     * @notice Claims accumulated hedging rewards for the caller
     * @dev Combines interest rate differential rewards and yield shift rewards
     * @return interestDifferential USDC rewards from interest rate differential (6 decimals)
     * @return yieldShiftRewards USDC rewards from yield shift mechanism (6 decimals)
     * @return totalRewards Total USDC rewards claimed (6 decimals)
     * @custom:security Validates hedger has active positions, updates reward calculations
     * @custom:validation Validates hedger exists and has pending rewards
     * @custom:state-changes Resets pending rewards, updates last claim timestamp
     * @custom:events Emits HedgingRewardsClaimed with reward breakdown
     * @custom:errors Throws YieldClaimFailed if yield shift claim fails
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Public - any hedger can claim their rewards
     * @custom:oracle No oracle dependencies for reward claiming
     */
    function claimHedgingRewards() external returns (uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards);
    
    // View functions
    
    /**
     * @notice Returns detailed information about a specific hedge position
     * @dev Provides comprehensive position data including current market price
     * @param hedger Address of the hedger who owns the position
     * @param positionId Unique identifier of the position to query
     * @return positionSize Total position size in USD equivalent
     * @return margin Current margin amount in USDC (6 decimals)
     * @return entryPrice EUR/USD price when position was opened
     * @return currentPrice Current EUR/USD price from oracle
     * @return leverage Leverage multiplier used for the position
     * @return lastUpdateTime Timestamp of last position update
     * @custom:security Validates position ownership and oracle price validity
     * @custom:validation Validates hedger owns the position
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors Throws InvalidHedger, InvalidOraclePrice
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query position data
     * @custom:oracle Requires fresh EUR/USD price from Chainlink oracle
     */
    function getHedgerPosition(address hedger, uint256 positionId) external view returns (
        uint256 positionSize,
        uint256 margin,
        uint256 entryPrice,
        uint256 currentPrice,
        uint256 leverage,
        uint256 lastUpdateTime
    );
    
    /**
     * @notice Returns the current margin ratio for a specific hedge position
     * @dev Calculates margin ratio as (margin / positionSize) * 10000 (in basis points)
     * @param hedger Address of the hedger who owns the position
     * @param positionId Unique identifier of the position to query
     * @return marginRatio Current margin ratio in basis points (10000 = 100%)
     * @custom:security Validates position ownership
     * @custom:validation Validates hedger owns the position
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors Throws InvalidHedger if hedger doesn't own position
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query margin ratio
     * @custom:oracle No oracle dependencies for margin ratio calculation
     */
    function getHedgerMarginRatio(address hedger, uint256 positionId) external view returns (uint256);
    
    /**
     * @notice Checks if a hedge position is eligible for liquidation
     * @dev Determines if position margin ratio is below liquidation threshold
     * @param hedger Address of the hedger who owns the position
     * @param positionId Unique identifier of the position to check
     * @return liquidatable True if position can be liquidated, false otherwise
     * @custom:security Validates position ownership and oracle price validity
     * @custom:validation Validates hedger owns the position
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors Throws InvalidHedger if hedger doesn't own position
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can check liquidation status
     * @custom:oracle Requires fresh EUR/USD price for liquidation calculation
     */
    function isHedgerLiquidatable(address hedger, uint256 positionId) external view returns (bool);
    
    /**
     * @notice Returns the total hedge exposure across all active positions
     * @dev Calculates sum of all active position sizes in USD equivalent
     * @return totalExposure Total exposure across all hedge positions in USD
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query total exposure
     * @custom:oracle No oracle dependencies for exposure calculation
     */
    function getTotalHedgeExposure() external view returns (uint256);

    
    // Governance functions
    
    /**
     * @notice Updates core hedging parameters for risk management
     * @dev Allows governance to adjust risk parameters based on market conditions
     * @param newMinMarginRatio New minimum margin ratio in basis points (e.g., 500 = 5%)
     * @param newLiquidationThreshold New liquidation threshold in basis points (e.g., 100 = 1%)
     * @param newMaxLeverage New maximum leverage multiplier (e.g., 20 = 20x)
     * @param newLiquidationPenalty New liquidation penalty in basis points (e.g., 200 = 2%)
     * @custom:security Validates governance role and parameter constraints
     * @custom:validation Validates minMarginRatio >= 500, liquidationThreshold < minMarginRatio, maxLeverage <= 20, liquidationPenalty <= 1000
     * @custom:state-changes Updates all hedging parameter state variables
     * @custom:events No events emitted for parameter updates
     * @custom:errors Throws ConfigValueTooLow, ConfigInvalid, ConfigValueTooHigh
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies for parameter updates
     */
    function updateHedgingParameters(
        uint256 newMinMarginRatio,
        uint256 newLiquidationThreshold,
        uint256 newMaxLeverage,
        uint256 newLiquidationPenalty
    ) external;
    
    /**
     * @notice Updates interest rates for EUR and USD
     * @dev Allows governance to adjust interest rates for reward calculations
     * @param newEurRate New EUR interest rate in basis points (e.g., 350 = 3.5%)
     * @param newUsdRate New USD interest rate in basis points (e.g., 450 = 4.5%)
     * @custom:security Validates governance role and rate constraints
     * @custom:validation Validates rates are within reasonable bounds (0-10000 basis points)
     * @custom:state-changes Updates eurInterestRate and usdInterestRate
     * @custom:events No events emitted for rate updates
     * @custom:errors Throws ConfigValueTooHigh if rates exceed maximum limits
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies for rate updates
     */
    function updateInterestRates(uint256 newEurRate, uint256 newUsdRate) external;
    
    /**
     * @notice Updates hedging fee parameters for protocol revenue
     * @dev Allows governance to adjust fees based on market conditions and protocol needs
     * @param _entryFee New entry fee in basis points (e.g., 20 = 0.2%, max 100 = 1%)
     * @param _exitFee New exit fee in basis points (e.g., 20 = 0.2%, max 100 = 1%)
     * @param _marginFee New margin fee in basis points (e.g., 10 = 0.1%, max 50 = 0.5%)
     * @custom:security Validates governance role and fee constraints
     * @custom:validation Validates entryFee <= 100, exitFee <= 100, marginFee <= 50
     * @custom:state-changes Updates entryFee, exitFee, and marginFee state variables
     * @custom:events No events emitted for fee updates
     * @custom:errors Throws ConfigValueTooHigh if fees exceed maximum limits
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies for fee updates
     */
    function setHedgingFees(uint256 _entryFee, uint256 _exitFee, uint256 _marginFee) external;
    /**
     * @notice Get hedging configuration parameters
     * @dev Returns all key hedging configuration parameters for risk management
     * @return _minMarginRatio Minimum margin ratio in basis points
     * @return _liquidationThreshold Liquidation threshold in basis points
     * @return _maxLeverage Maximum leverage multiplier
     * @return _liquidationPenalty Liquidation penalty in basis points
     * @return _entryFee Entry fee in basis points
     * @return _exitFee Exit fee in basis points
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query hedging configuration
     * @custom:oracle No oracle dependencies
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
    
    /**
     * @notice Emergency close position function
     * @dev Allows emergency role to force close a position in emergency situations
     * @param hedger Address of the hedger whose position to close
     * @param positionId ID of the position to close
     * @custom:security Validates emergency role authorization
     * @custom:validation Validates position exists and is active
     * @custom:state-changes Closes position, transfers remaining margin to hedger
     * @custom:events Emits HedgePositionClosed event
     * @custom:errors Throws InvalidPosition if position doesn't exist
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle Requires fresh EUR/USD price for PnL calculation
     */
    function emergencyClosePosition(address hedger, uint256 positionId) external;
    
    /**
     * @notice Pauses all hedging operations
     * @dev Emergency function to pause the hedger pool in case of critical issues
     * @custom:security Validates emergency role authorization
     * @custom:validation No input validation required
     * @custom:state-changes Sets pause state, stops all hedging operations
     * @custom:events Emits Paused event from OpenZeppelin
     * @custom:errors No errors thrown - safe pause operation
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle No oracle dependencies for pause
     */
    function pause() external;
    
    /**
     * @notice Unpauses hedging operations
     * @dev Allows emergency role to unpause the hedger pool after resolving issues
     * @custom:security Validates emergency role authorization
     * @custom:validation No input validation required
     * @custom:state-changes Removes pause state, resumes hedging operations
     * @custom:events Emits Unpaused event from OpenZeppelin
     * @custom:errors No errors thrown - safe unpause operation
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to EMERGENCY_ROLE
     * @custom:oracle No oracle dependencies for unpause
     */
    function unpause() external;
    
    /**
     * @notice Checks if hedging is currently active
     * @dev Returns true if the hedger pool is not paused and operational
     * @return isActive True if hedging is active, false if paused
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can check hedging status
     * @custom:oracle No oracle dependencies
     */
    function isHedgingActive() external view returns (bool);
    
    // Recovery functions
    
    /**
     * @notice Recovers tokens accidentally sent to the contract
     * @dev Emergency function to recover ERC20 tokens that are not part of normal operations
     * @param token Address of the token to recover
     * @param amount Amount of tokens to recover
     * @custom:security Validates admin role and uses secure recovery library
     * @custom:validation No input validation required - library handles validation
     * @custom:state-changes Transfers tokens from contract to treasury
     * @custom:events Emits TokenRecovered event
     * @custom:errors No errors thrown - library handles error cases
     * @custom:reentrancy Not protected - library handles reentrancy
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependencies for token recovery
     */
    function recoverToken(address token, uint256 amount) external;
    
    /**
     * @notice Recovers ETH accidentally sent to the contract
     * @dev Emergency function to recover ETH that was accidentally sent to the contract
     * @custom:security Validates admin role and emits recovery event
     * @custom:validation No input validation required - transfers all ETH
     * @custom:state-changes Transfers all contract ETH balance to treasury
     * @custom:events Emits ETHRecovered with amount and treasury address
     * @custom:errors No errors thrown - safe ETH transfer
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependencies
     */
    function recoverETH() external;
    
    // State variables
    
    /**
     * @notice Returns the USDC token contract interface
     * @dev USDC token used for margin deposits and withdrawals (6 decimals)
     * @return IERC20 USDC token contract interface
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query USDC contract
     * @custom:oracle No oracle dependencies
     */
    function usdc() external view returns (IERC20);
    
    /**
     * @notice Returns the oracle contract address
     * @dev Chainlink oracle for EUR/USD price feeds
     * @return address Oracle contract address
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query oracle address
     * @custom:oracle No oracle dependencies
     */
    function oracle() external view returns (address);
    
    /**
     * @notice Returns the yield shift contract address
     * @dev YieldShift contract for reward distribution
     * @return address YieldShift contract address
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query yield shift address
     * @custom:oracle No oracle dependencies
     */
    function yieldShift() external view returns (address);
    
    /**
     * @notice Returns the minimum margin ratio in basis points
     * @dev Minimum margin ratio required for positions (e.g., 1000 = 10%)
     * @return uint256 Minimum margin ratio in basis points
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query minimum margin ratio
     * @custom:oracle No oracle dependencies
     */
    function minMarginRatio() external view returns (uint256);
    
    /**
     * @notice Returns the liquidation threshold in basis points
     * @dev Margin ratio below which positions can be liquidated (e.g., 100 = 1%)
     * @return uint256 Liquidation threshold in basis points
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query liquidation threshold
     * @custom:oracle No oracle dependencies
     */
    function liquidationThreshold() external view returns (uint256);
    
    /**
     * @notice Returns the maximum leverage multiplier
     * @dev Maximum leverage allowed for hedge positions (e.g., 10 = 10x)
     * @return uint256 Maximum leverage multiplier
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query maximum leverage
     * @custom:oracle No oracle dependencies
     */
    function maxLeverage() external view returns (uint256);
    
    /**
     * @notice Returns the liquidation penalty in basis points
     * @dev Penalty applied to liquidated positions (e.g., 200 = 2%)
     * @return uint256 Liquidation penalty in basis points
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query liquidation penalty
     * @custom:oracle No oracle dependencies
     */
    function liquidationPenalty() external view returns (uint256);
    
    /**
     * @notice Returns the entry fee in basis points
     * @dev Fee charged when opening hedge positions (e.g., 20 = 0.2%)
     * @return uint256 Entry fee in basis points
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query entry fee
     * @custom:oracle No oracle dependencies
     */
    function entryFee() external view returns (uint256);
    
    /**
     * @notice Returns the exit fee in basis points
     * @dev Fee charged when closing hedge positions (e.g., 20 = 0.2%)
     * @return uint256 Exit fee in basis points
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query exit fee
     * @custom:oracle No oracle dependencies
     */
    function exitFee() external view returns (uint256);
    
    /**
     * @notice Returns the margin fee in basis points
     * @dev Fee charged when adding/removing margin (e.g., 10 = 0.1%)
     * @return uint256 Margin fee in basis points
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query margin fee
     * @custom:oracle No oracle dependencies
     */
    function marginFee() external view returns (uint256);
    
    /**
     * @notice Returns the total margin across all positions
     * @dev Total USDC margin held across all active hedge positions (6 decimals)
     * @return uint256 Total margin in USDC
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query total margin
     * @custom:oracle No oracle dependencies
     */
    function totalMargin() external view returns (uint256);
    
    /**
     * @notice Returns the total exposure across all positions
     * @dev Total USD exposure across all active hedge positions
     * @return uint256 Total exposure in USD
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query total exposure
     * @custom:oracle No oracle dependencies
     */
    function totalExposure() external view returns (uint256);
    
    /**
     * @notice Returns the number of active hedgers
     * @dev Count of unique addresses with active hedge positions
     * @return uint256 Number of active hedgers
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query active hedger count
     * @custom:oracle No oracle dependencies
     */
    function activeHedgers() external view returns (uint256);
    
    /**
     * @notice Returns the next position ID to be assigned
     * @dev Counter for generating unique position IDs
     * @return uint256 Next position ID
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query next position ID
     * @custom:oracle No oracle dependencies
     */
    function nextPositionId() external view returns (uint256);
    
    /**
     * @notice Returns the EUR interest rate in basis points
     * @dev Interest rate for EUR-denominated positions (e.g., 350 = 3.5%)
     * @return uint256 EUR interest rate in basis points
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query EUR interest rate
     * @custom:oracle No oracle dependencies
     */
    function eurInterestRate() external view returns (uint256);
    
    /**
     * @notice Returns the USD interest rate in basis points
     * @dev Interest rate for USD-denominated positions (e.g., 450 = 4.5%)
     * @return uint256 USD interest rate in basis points
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query USD interest rate
     * @custom:oracle No oracle dependencies
     */
    function usdInterestRate() external view returns (uint256);
    
    /**
     * @notice Returns the total yield earned across all positions
     * @dev Total yield earned from interest rate differentials (6 decimals)
     * @return uint256 Total yield earned in USDC
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query total yield earned
     * @custom:oracle No oracle dependencies
     */
    function totalYieldEarned() external view returns (uint256);
    
    /**
     * @notice Returns the interest differential pool balance
     * @dev Pool of funds available for interest rate differential rewards (6 decimals)
     * @return uint256 Interest differential pool balance in USDC
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query interest differential pool
     * @custom:oracle No oracle dependencies
     */
    function interestDifferentialPool() external view returns (uint256);
    
    /**
     * @notice Returns the active position count for a hedger
     * @dev Number of active positions owned by a specific hedger
     * @param hedger Address of the hedger to query
     * @return uint256 Number of active positions for the hedger
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query position count
     * @custom:oracle No oracle dependencies
     */
    function activePositionCount(address hedger) external view returns (uint256);
    /**
     * @notice Returns position details by position ID
     * @dev Returns comprehensive position information for a specific position ID
     * @param positionId The ID of the position to query
     * @return hedger Address of the hedger who owns the position
     * @return positionSize Total position size in USD equivalent
     * @return margin Current margin amount in USDC (6 decimals)
     * @return entryPrice EUR/USD price when position was opened
     * @return leverage Leverage multiplier used for the position
     * @return entryTime Timestamp when position was opened
     * @return lastUpdateTime Timestamp of last position update
     * @return unrealizedPnL Current unrealized profit or loss
     * @return isActive Whether the position is currently active
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query position details
     * @custom:oracle No oracle dependencies for position data
     */
    function positions(uint256 positionId) external view returns (
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
     * @dev Returns comprehensive information about a hedger's positions and rewards
     * @param hedger Address of the hedger to query
     * @return positionIds Array of position IDs owned by the hedger
     * @return _totalMargin Total margin across all positions (6 decimals)
     * @return _totalExposure Total exposure across all positions in USD
     * @return pendingRewards Pending rewards available for claim (6 decimals)
     * @return lastRewardClaim Timestamp of last reward claim
     * @return isActive Whether hedger has active positions
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query hedger information
     * @custom:oracle No oracle dependencies
     */
    function hedgers(address hedger) external view returns (
        uint256[] memory positionIds,
        uint256 _totalMargin,
        uint256 _totalExposure,
        uint256 pendingRewards,
        uint256 lastRewardClaim,
        bool isActive
    );
    
    /**
     * @notice Returns array of position IDs for a hedger
     * @dev Returns all position IDs owned by a specific hedger
     * @param hedger Address of the hedger to query
     * @return uint256[] Array of position IDs owned by the hedger
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query hedger positions
     * @custom:oracle No oracle dependencies
     */
    function hedgerPositions(address hedger) external view returns (uint256[] memory);
    
    /**
     * @notice Returns pending yield for a user
     * @dev Returns pending yield rewards for a specific user address
     * @param user Address of the user to query
     * @return uint256 Pending yield amount in USDC (6 decimals)
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query user pending yield
     * @custom:oracle No oracle dependencies
     */
    function userPendingYield(address user) external view returns (uint256);
    
    /**
     * @notice Returns pending yield for a hedger
     * @dev Returns pending yield rewards for a specific hedger address
     * @param hedger Address of the hedger to query
     * @return uint256 Pending yield amount in USDC (6 decimals)
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query hedger pending yield
     * @custom:oracle No oracle dependencies
     */
    function hedgerPendingYield(address hedger) external view returns (uint256);
    
    /**
     * @notice Returns last claim time for a user
     * @dev Returns timestamp of last yield claim for a specific user
     * @param user Address of the user to query
     * @return uint256 Timestamp of last yield claim
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query user last claim time
     * @custom:oracle No oracle dependencies
     */
    function userLastClaim(address user) external view returns (uint256);
    
    /**
     * @notice Returns last claim time for a hedger
     * @dev Returns timestamp of last yield claim for a specific hedger
     * @param hedger Address of the hedger to query
     * @return uint256 Timestamp of last yield claim
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query hedger last claim time
     * @custom:oracle No oracle dependencies
     */
    function hedgerLastClaim(address hedger) external view returns (uint256);
    
    /**
     * @notice Returns last reward block for a hedger
     * @dev Returns block number of last reward calculation for a specific hedger
     * @param hedger Address of the hedger to query
     * @return uint256 Block number of last reward calculation
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query hedger last reward block
     * @custom:oracle No oracle dependencies
     */
    function hedgerLastRewardBlock(address hedger) external view returns (uint256);
    
    /**
     * @notice Returns liquidation commitment status
     * @dev Returns whether a specific liquidation commitment exists
     * @param commitment Hash of the liquidation commitment
     * @return bool True if commitment exists, false otherwise
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query commitment status
     * @custom:oracle No oracle dependencies
     */
    function liquidationCommitments(bytes32 commitment) external view returns (bool);
    
    /**
     * @notice Returns liquidation commitment timestamp
     * @dev Returns block number when liquidation commitment was created
     * @param commitment Hash of the liquidation commitment
     * @return uint256 Block number when commitment was created
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query commitment timestamp
     * @custom:oracle No oracle dependencies
     */
    function liquidationCommitmentTimes(bytes32 commitment) external view returns (uint256);
    
    /**
     * @notice Returns last liquidation attempt block
     * @dev Returns block number of last liquidation attempt for a hedger
     * @param hedger Address of the hedger to query
     * @return uint256 Block number of last liquidation attempt
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query last liquidation attempt
     * @custom:oracle No oracle dependencies
     */
    function lastLiquidationAttempt(address hedger) external view returns (uint256);
    
    /**
     * @notice Returns pending liquidation status
     * @dev Returns whether a position has a pending liquidation commitment
     * @param hedger Address of the hedger
     * @param positionId ID of the position
     * @return bool True if liquidation is pending, false otherwise
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query pending liquidation status
     * @custom:oracle No oracle dependencies
     */
    function hasPendingLiquidation(address hedger, uint256 positionId) external view returns (bool);
    
    // Constants
    
    /**
     * @notice Returns the maximum positions per hedger
     * @dev Maximum number of positions a single hedger can have open simultaneously
     * @return uint256 Maximum positions per hedger
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query maximum positions per hedger
     * @custom:oracle No oracle dependencies
     */
    function MAX_POSITIONS_PER_HEDGER() external view returns (uint256);
    
    /**
     * @notice Returns the number of blocks per day
     * @dev Used for time-based calculations and reward periods
     * @return uint256 Number of blocks per day
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query blocks per day
     * @custom:oracle No oracle dependencies
     */
    function BLOCKS_PER_DAY() external view returns (uint256);
    
    /**
     * @notice Returns the maximum reward period
     * @dev Maximum time period for reward calculations in blocks
     * @return uint256 Maximum reward period in blocks
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query maximum reward period
     * @custom:oracle No oracle dependencies
     */
    function MAX_REWARD_PERIOD() external view returns (uint256);
    
    /**
     * @notice Returns the liquidation cooldown period
     * @dev Minimum blocks between liquidation attempts for the same hedger
     * @return uint256 Liquidation cooldown in blocks
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query liquidation cooldown
     * @custom:oracle No oracle dependencies
     */
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
    
    // Hedger Whitelist Management
    
    /**
     * @notice Whitelists a hedger address
     * @dev Allows the specified address to open hedge positions when whitelist is enabled
     * @param hedger Address to whitelist as a hedger
     * @custom:security Validates governance role and hedger address
     * @custom:validation Validates hedger is not address(0) and not already whitelisted
     * @custom:state-changes Updates isWhitelistedHedger mapping and grants HEDGER_ROLE
     * @custom:events Emits HedgerWhitelisted with hedger and caller addresses
     * @custom:errors Throws ZeroAddress if hedger is address(0), AlreadyWhitelisted if already whitelisted
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function whitelistHedger(address hedger) external;
    
    /**
     * @notice Removes a hedger from the whitelist
     * @dev Prevents the specified address from opening new hedge positions
     * @param hedger Address to remove from hedger whitelist
     * @custom:security Validates governance role and hedger address
     * @custom:validation Validates hedger is not address(0) and is currently whitelisted
     * @custom:state-changes Updates isWhitelistedHedger mapping and revokes HEDGER_ROLE
     * @custom:events Emits HedgerRemoved with hedger and caller addresses
     * @custom:errors Throws ZeroAddress if hedger is address(0), NotWhitelisted if not whitelisted
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function removeHedger(address hedger) external;
    
    /**
     * @notice Toggles hedger whitelist mode
     * @dev When enabled, only whitelisted addresses can open hedge positions
     * @param enabled Whether to enable hedger whitelist mode
     * @custom:security Validates governance role
     * @custom:validation No input validation required - boolean parameter
     * @custom:state-changes Updates hedgerWhitelistEnabled state variable
     * @custom:events Emits HedgerWhitelistModeToggled with enabled status and caller
     * @custom:errors No errors thrown - safe boolean toggle
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function toggleHedgerWhitelistMode(bool enabled) external;
    
    
    /**
     * @notice Check if an address is whitelisted as a hedger
     * @dev Returns true if the address is on the hedger whitelist
     * @param hedger Address to check
     * @return isWhitelisted True if the address is whitelisted as a hedger
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query hedger whitelist status
     * @custom:oracle No oracle dependencies
     */
    function isWhitelistedHedger(address hedger) external view returns (bool);
    
    /**
     * @notice Check if hedger whitelist mode is enabled
     * @dev Returns true if hedger whitelist mode is active
     * @return enabled True if hedger whitelist mode is enabled
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query hedger whitelist mode status
     * @custom:oracle No oracle dependencies
     */
    function hedgerWhitelistEnabled() external view returns (bool);
    
    // Hedger Whitelist Events
    
    event HedgerWhitelisted(address indexed hedger, address indexed caller);
    event HedgerRemoved(address indexed hedger, address indexed caller);
    event HedgerWhitelistModeToggled(bool enabled, address indexed caller);
} 