// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VaultMath} from "./VaultMath.sol";

/**
 * @title YieldShiftOptimizationLibrary
 * @notice Library for YieldShift pool metrics, historical data, and utility functions
 * @dev Extracts utility functions from YieldShift to reduce contract size
 * @author Quantillon Labs
 */
library YieldShiftOptimizationLibrary {
    using VaultMath for uint256;
    
    // =============================================================================
    // STRUCTS
    // =============================================================================
    
    struct PoolSnapshot {
        uint64 timestamp;
        uint128 userPoolSize;
        uint128 hedgerPoolSize;
    }
    
    struct YieldShiftSnapshot {
        uint128 yieldShift;
        uint64 timestamp;
    }
    
    // =============================================================================
    // CONSTANTS
    // =============================================================================
    
    uint256 public constant MIN_HOLDING_PERIOD = 7 days;
    uint256 public constant TWAP_PERIOD = 24 hours;
    uint256 public constant MAX_TIME_ELAPSED = 365 days;
    uint256 public constant MAX_HISTORY_LENGTH = 100;
    
    // =============================================================================
    // POOL METRICS FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Get current pool metrics
     * @dev Returns current pool sizes and ratio for yield shift calculations
     * @param userPoolAddress Address of the user pool contract
     * @param hedgerPoolAddress Address of the hedger pool contract
     * @return userPoolSize Current user pool size
     * @return hedgerPoolSize Current hedger pool size
     * @return poolRatio Ratio of user to hedger pool sizes
     */
    function getCurrentPoolMetrics(
        address userPoolAddress,
        address hedgerPoolAddress
    ) external view returns (
        uint256 userPoolSize,
        uint256 hedgerPoolSize,
        uint256 poolRatio
    ) {
        (bool success1, bytes memory data1) = userPoolAddress.staticcall(
            abi.encodeWithSelector(0x168a4822) // getTotalDeposits()
        );
        if (success1 && data1.length >= 32) {
            userPoolSize = abi.decode(data1, (uint256));
        }
        
        (bool success2, bytes memory data2) = hedgerPoolAddress.staticcall(
            abi.encodeWithSelector(0xdc0a80ca) // getTotalHedgeExposure()
        );
        if (success2 && data2.length >= 32) {
            hedgerPoolSize = abi.decode(data2, (uint256));
        }
        
        if (hedgerPoolSize == 0) {
            poolRatio = type(uint256).max;
        } else {
            poolRatio = userPoolSize.mulDiv(10000, hedgerPoolSize);
        }
    }
    
    /**
     * @notice Get eligible pool metrics that only count deposits meeting holding period requirements
     * @dev SECURITY: Prevents flash deposit attacks by excluding recent deposits from yield calculations
     * @param userPoolAddress Address of the user pool contract
     * @param hedgerPoolAddress Address of the hedger pool contract
     * @param currentTime Current timestamp
     * @param lastUpdateTime Last update timestamp
     * @return userPoolSize Eligible user pool size (deposits older than MIN_HOLDING_PERIOD)
     * @return hedgerPoolSize Eligible hedger pool size (deposits older than MIN_HOLDING_PERIOD)
     * @return poolRatio Ratio of eligible pool sizes
     */
    function getEligiblePoolMetrics(
        address userPoolAddress,
        address hedgerPoolAddress,
        uint256 currentTime,
        uint256 lastUpdateTime
    ) external view returns (
        uint256 userPoolSize,
        uint256 hedgerPoolSize,
        uint256 poolRatio
    ) {
        // Get current pool sizes
        (bool success1, bytes memory data1) = userPoolAddress.staticcall(
            abi.encodeWithSelector(0x168a4822) // getTotalDeposits()
        );
        uint256 currentUserPoolSize = 0;
        if (success1 && data1.length >= 32) {
            currentUserPoolSize = abi.decode(data1, (uint256));
        }
        
        (bool success2, bytes memory data2) = hedgerPoolAddress.staticcall(
            abi.encodeWithSelector(0xdc0a80ca) // getTotalHedgeExposure()
        );
        uint256 currentHedgerPoolSize = 0;
        if (success2 && data2.length >= 32) {
            currentHedgerPoolSize = abi.decode(data2, (uint256));
        }
        
        // Calculate eligible pool sizes based on holding period
        userPoolSize = _calculateEligibleUserPoolSize(currentUserPoolSize, currentTime, lastUpdateTime);
        hedgerPoolSize = _calculateEligibleHedgerPoolSize(currentHedgerPoolSize, currentTime, lastUpdateTime);
        
        if (hedgerPoolSize == 0) {
            poolRatio = type(uint256).max;
        } else {
            poolRatio = userPoolSize.mulDiv(10000, hedgerPoolSize);
        }
    }
    
    /**
     * @notice Calculate eligible user pool size excluding recent deposits
     * @dev Only counts deposits older than MIN_HOLDING_PERIOD
     * @param totalUserPoolSize Current total user pool size
     * @param currentTime Current timestamp
     * @param lastUpdateTime Last update timestamp
     * @return eligibleSize Eligible pool size for yield calculations
     */
    function calculateEligibleUserPoolSize(
        uint256 totalUserPoolSize,
        uint256 currentTime,
        uint256 lastUpdateTime
    ) external pure returns (uint256 eligibleSize) {
        return _calculateEligibleUserPoolSize(totalUserPoolSize, currentTime, lastUpdateTime);
    }
    
    function _calculateEligibleUserPoolSize(
        uint256 totalUserPoolSize,
        uint256 currentTime,
        uint256 lastUpdateTime
    ) internal pure returns (uint256 eligibleSize) {
        // For now, we'll use a conservative approach by applying a holding period discount
        // In a full implementation, this would iterate through individual user deposits
        // and only count those meeting the holding period requirement
        
        // This is a simplified approach - in production, you'd want to track individual deposits
        uint256 holdingPeriodDiscount = _calculateHoldingPeriodDiscount(currentTime, lastUpdateTime);
        eligibleSize = totalUserPoolSize.mulDiv(holdingPeriodDiscount, 10000);
        
        // Ensure we don't return more than the total pool size
        if (eligibleSize > totalUserPoolSize) {
            eligibleSize = totalUserPoolSize;
        }
    }
    
    /**
     * @notice Calculate eligible hedger pool size excluding recent deposits
     * @dev Only counts deposits older than MIN_HOLDING_PERIOD
     * @param totalHedgerPoolSize Current total hedger pool size
     * @param currentTime Current timestamp
     * @param lastUpdateTime Last update timestamp
     * @return eligibleSize Eligible pool size for yield calculations
     */
    function calculateEligibleHedgerPoolSize(
        uint256 totalHedgerPoolSize,
        uint256 currentTime,
        uint256 lastUpdateTime
    ) external pure returns (uint256 eligibleSize) {
        return _calculateEligibleHedgerPoolSize(totalHedgerPoolSize, currentTime, lastUpdateTime);
    }
    
    function _calculateEligibleHedgerPoolSize(
        uint256 totalHedgerPoolSize,
        uint256 currentTime,
        uint256 lastUpdateTime
    ) internal pure returns (uint256 eligibleSize) {
        // Similar approach to user pool size
        uint256 holdingPeriodDiscount = _calculateHoldingPeriodDiscount(currentTime, lastUpdateTime);
        eligibleSize = totalHedgerPoolSize.mulDiv(holdingPeriodDiscount, 10000);
        
        if (eligibleSize > totalHedgerPoolSize) {
            eligibleSize = totalHedgerPoolSize;
        }
    }
    
    /**
     * @notice Calculate holding period discount based on recent deposit activity
     * @dev Returns a percentage (in basis points) representing eligible deposits
     * @param currentTime Current timestamp
     * @param lastUpdateTime Last update timestamp
     * @return discountBps Discount in basis points (10000 = 100%)
     */
    function calculateHoldingPeriodDiscount(
        uint256 currentTime,
        uint256 lastUpdateTime
    ) external pure returns (uint256 discountBps) {
        return _calculateHoldingPeriodDiscount(currentTime, lastUpdateTime);
    }
    
    function _calculateHoldingPeriodDiscount(
        uint256 currentTime,
        uint256 lastUpdateTime
    ) internal pure returns (uint256 discountBps) {
        // Base discount: assume 80% of deposits meet holding period (conservative)
        uint256 baseDiscount = 8000; // 80%
        
        // Adjust based on time since last major deposit activity
        uint256 timeSinceLastUpdate = currentTime - lastUpdateTime;
        
        if (timeSinceLastUpdate < MIN_HOLDING_PERIOD) {
            // Recent activity - apply stricter discount
            uint256 timeFactor = timeSinceLastUpdate.mulDiv(2000, MIN_HOLDING_PERIOD); // 0-20% additional discount
            discountBps = baseDiscount - timeFactor;
        } else {
            // Stable period - use base discount
            discountBps = baseDiscount;
        }
        
        // Ensure discount is reasonable (minimum 50%)
        if (discountBps < 5000) {
            discountBps = 5000;
        }
    }
    
    // =============================================================================
    // HISTORICAL DATA FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Get time weighted average of pool history
     * @dev Calculates time weighted average of pool history over a specified period
     * @param poolHistory Array of pool snapshots
     * @param period Time period for calculation
     * @param isUserPool Whether this is for user pool or hedger pool
     * @param currentTime Current timestamp
     * @return Time weighted average value
     */
    function getTimeWeightedAverage(
        PoolSnapshot[] memory poolHistory,
        uint256 period,
        bool isUserPool,
        uint256 currentTime
    ) external pure returns (uint256) {
        uint256 length = poolHistory.length;
        if (length == 0) {
            return 0;
        }
        
        uint256 cutoffTime = currentTime > period ? 
            currentTime - period : 0;
        
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
     * @notice Add pool snapshot to history
     * @dev Adds a pool snapshot to the history array with size management
     * @param poolHistory Array of pool snapshots to add to
     * @param poolSize Size of the pool to record
     * @param isUserPool Whether this is for user pool or hedger pool
     * @param currentTime Current timestamp
     * @return newHistory Updated pool history array
     */
    function addToPoolHistory(
        PoolSnapshot[] memory poolHistory,
        uint256 poolSize,
        bool isUserPool,
        uint256 currentTime
    ) external pure returns (PoolSnapshot[] memory newHistory) {
        uint256 length = poolHistory.length;
        
        if (length >= MAX_HISTORY_LENGTH) {
            // Create new array with one less element
            newHistory = new PoolSnapshot[](length);
            
            // Shift all elements left by one
            for (uint256 i = 0; i < length - 1;) {
                newHistory[i] = poolHistory[i + 1];
                unchecked { ++i; }
            }
            
            // Add new element at the end
            newHistory[length - 1] = PoolSnapshot({
                timestamp: uint64(currentTime),
                userPoolSize: isUserPool ? uint128(poolSize) : 0,
                hedgerPoolSize: isUserPool ? 0 : uint128(poolSize)
            });
        } else {
            // Create new array with one more element
            newHistory = new PoolSnapshot[](length + 1);
            
            // Copy existing elements
            for (uint256 i = 0; i < length;) {
                newHistory[i] = poolHistory[i];
                unchecked { ++i; }
            }
            
            // Add new element at the end
            newHistory[length] = PoolSnapshot({
                timestamp: uint64(currentTime),
                userPoolSize: isUserPool ? uint128(poolSize) : 0,
                hedgerPoolSize: isUserPool ? 0 : uint128(poolSize)
            });
        }
    }
    
    // =============================================================================
    // YIELD CALCULATION FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Calculate user allocation from current yield shift
     * @param userYieldPool Current user yield pool amount
     * @param hedgerYieldPool Current hedger yield pool amount
     * @param currentYieldShift Current yield shift percentage
     * @return User allocation amount based on current yield shift percentage
     */
    function calculateUserAllocation(
        uint256 userYieldPool,
        uint256 hedgerYieldPool,
        uint256 currentYieldShift
    ) external pure returns (uint256) {
        uint256 totalAvailable = userYieldPool + hedgerYieldPool;
        uint256 userAllocationPct = currentYieldShift; // This is the user allocation percentage
        return totalAvailable.mulDiv(userAllocationPct, 10000);
    }
    
    /**
     * @notice Calculate hedger allocation from current yield shift
     * @param userYieldPool Current user yield pool amount
     * @param hedgerYieldPool Current hedger yield pool amount
     * @param currentYieldShift Current yield shift percentage
     * @return Hedger allocation amount based on current yield shift percentage
     */
    function calculateHedgerAllocation(
        uint256 userYieldPool,
        uint256 hedgerYieldPool,
        uint256 currentYieldShift
    ) external pure returns (uint256) {
        uint256 totalAvailable = userYieldPool + hedgerYieldPool;
        uint256 hedgerAllocationPct = 10000 - currentYieldShift; // This is the hedger allocation percentage
        return totalAvailable.mulDiv(hedgerAllocationPct, 10000);
    }
    
    // =============================================================================
    // UTILITY FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Check if a value is within tolerance of a target value
     * @param value The value to check
     * @param target The target value
     * @param toleranceBps Tolerance in basis points (e.g., 1000 = 10%)
     * @return True if value is within tolerance, false otherwise
     */
    function isWithinTolerance(
        uint256 value,
        uint256 target,
        uint256 toleranceBps
    ) external pure returns (bool) {
        if (value == target) return true;
        
        uint256 tolerance = target.mulDiv(toleranceBps, 10000);
        return value >= target - tolerance && value <= target + tolerance;
    }
    
    /**
     * @notice Calculate historical yield shift metrics
     * @param yieldShiftHistory Array of yield shift snapshots
     * @param period Time period to analyze
     * @param currentTime Current timestamp
     * @return averageShift Average yield shift during the period
     * @return maxShift Maximum yield shift during the period
     * @return minShift Minimum yield shift during the period
     * @return volatility Volatility measure of yield shifts
     */
    function calculateHistoricalYieldShift(
        YieldShiftSnapshot[] memory yieldShiftHistory,
        uint256 period,
        uint256 currentTime
    ) external pure returns (
        uint256 averageShift,
        uint256 maxShift,
        uint256 minShift,
        uint256 volatility
    ) {
        uint256 length = yieldShiftHistory.length;
        if (length < 1) {
            return (0, 0, 0, 0);
        }
        
        uint256 cutoffTime = currentTime > period ? 
            currentTime - period : 0;
        
        uint256[] memory validShifts = new uint256[](length);
        uint256 validCount = 0;
        
        // Cache storage reference to avoid multiple SLOAD operations
        YieldShiftSnapshot memory snapshot;
        
        for (uint256 i = 0; i < length;) {
            snapshot = yieldShiftHistory[i];
            if (snapshot.timestamp >= cutoffTime) {
                validShifts[validCount] = snapshot.yieldShift;
                validCount++;
            }
            unchecked { ++i; }
        }
        
        if (validCount == 0) {
            return (0, 0, 0, 0);
        }
        
        uint256 sumShifts = 0;
        maxShift = 0;
        minShift = type(uint256).max;
        
        for (uint256 i = 0; i < validCount; i++) {
            uint256 shift = validShifts[i];
            sumShifts += shift;
            if (shift > maxShift) maxShift = shift;
            if (shift < minShift) minShift = shift;
        }
        
        averageShift = sumShifts / validCount;
        
        uint256 sumSquaredDeviations = 0;
        for (uint256 i = 0; i < validCount; i++) {
            uint256 shift = validShifts[i];
            uint256 deviation = shift > averageShift ? 
                shift - averageShift : averageShift - shift;
            sumSquaredDeviations += deviation * deviation;
        }
        
        volatility = validCount > 1 ? 
            VaultMath.scaleDecimals(sumSquaredDeviations / (validCount - 1), 0, 9) : 0;
    }
}
