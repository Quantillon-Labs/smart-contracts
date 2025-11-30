// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {GovernanceErrorLibrary} from "./GovernanceErrorLibrary.sol";
import {CommonErrorLibrary} from "./CommonErrorLibrary.sol";
import {CommonValidationLibrary} from "./CommonValidationLibrary.sol";

/**
 * @title QTITokenGovernanceLibrary
 * @notice Library for QTIToken governance calculations and validations
 * @dev Extracts calculation logic from QTIToken to reduce contract size
 * @author Quantillon Labs
 */
library QTITokenGovernanceLibrary {
    
    // =============================================================================
    // CONSTANTS
    // =============================================================================
    
    /// @notice Maximum lock time for QTI tokens (1 year)
    uint256 public constant MAX_LOCK_TIME = 365 days;
    
    /// @notice Minimum lock time for vote-escrow (1 week)
    uint256 public constant MIN_LOCK_TIME = 7 days;
    
    /// @notice Maximum voting power multiplier (4x)
    uint256 public constant MAX_VE_QTI_MULTIPLIER = 4;
    
    // =============================================================================
    // STRUCTS
    // =============================================================================
    
    /// @notice Lock information structure
    struct LockInfo {
        uint96 amount;              // Amount of QTI locked
        uint32 unlockTime;          // Timestamp when lock expires
        uint96 votingPower;         // Current voting power
        uint32 lastClaimTime;       // Last claim time (for future use)
        uint96 initialVotingPower;  // Initial voting power when locked
        uint32 lockTime;            // Original lock duration
    }
    
    // =============================================================================
    // VOTING POWER CALCULATIONS
    // =============================================================================
    
    /**
     * @notice Calculate voting power multiplier based on lock time
     * @dev Calculates linear multiplier from 1x to 4x based on lock duration
     * @param lockTime Duration of the lock
     * @return multiplier Voting power multiplier
     * @custom:security No security implications - pure calculation function
     * @custom:validation Input validation handled by calling contract
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - pure function
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public function
     * @custom:oracle No oracle dependencies
     */
    function calculateVotingPowerMultiplier(uint256 lockTime) external pure returns (uint256 multiplier) {
        return _calculateVotingPowerMultiplier(lockTime);
    }
    
    /**
     * @notice Internal function to calculate voting power multiplier
     * @dev Calculates linear multiplier from 1x to 4x based on lock duration
     * @param lockTime Duration of the lock
     * @return multiplier Voting power multiplier
     * @custom:security No security implications - pure calculation function
     * @custom:validation Input validation handled by calling function
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - pure function
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal function
     * @custom:oracle No oracle dependencies
     */
    function _calculateVotingPowerMultiplier(uint256 lockTime) internal pure returns (uint256 multiplier) {
        // Linear multiplier from 1x to 4x based on lock time
        // 1x for MIN_LOCK_TIME, 4x for MAX_LOCK_TIME
        multiplier = 1e18 + (lockTime - MIN_LOCK_TIME) * 3e18 / (MAX_LOCK_TIME - MIN_LOCK_TIME);
        return multiplier > MAX_VE_QTI_MULTIPLIER * 1e18 ? MAX_VE_QTI_MULTIPLIER * 1e18 : multiplier;
    }
    
    /**
     * @notice Calculate voting power with overflow protection
     * @dev Calculates voting power based on amount and lock time with overflow protection
     * @param amount Amount of QTI tokens to lock
     * @param lockTime Duration to lock tokens
     * @return votingPower Calculated voting power
     * @custom:security Prevents overflow in voting power calculations
     * @custom:validation Input validation handled by calling contract
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws InvalidAmount if result exceeds uint96 max
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public function
     * @custom:oracle No oracle dependencies
     */
    function calculateVotingPower(uint256 amount, uint256 lockTime) external pure returns (uint256) {
        return _calculateVotingPower(amount, lockTime);
    }
    
    /**
     * @notice Internal function to calculate voting power with overflow protection
     * @dev Calculates voting power based on amount and lock time with overflow protection
     * @param amount Amount of QTI tokens to lock
     * @param lockTime Duration to lock tokens
     * @return votingPower Calculated voting power
     * @custom:security Prevents overflow in voting power calculations
     * @custom:validation Input validation handled by calling function
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws InvalidAmount if result exceeds uint96 max
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal function
     * @custom:oracle No oracle dependencies
     */
    function _calculateVotingPower(uint256 amount, uint256 lockTime) internal pure returns (uint256) {
        uint256 multiplier = _calculateVotingPowerMultiplier(lockTime);
        uint256 newVotingPower = amount * multiplier / 1e18;
        if (newVotingPower > type(uint96).max) revert CommonErrorLibrary.InvalidAmount();
        return newVotingPower;
    }
    
    /**
     * @notice Calculate current voting power with linear decay
     * @dev Calculates current voting power with linear decay over time
     * @param lockInfo Lock information structure
     * @param currentTime Current timestamp
     * @return votingPower Current voting power of the user (decays linearly over time)
     * @custom:security No security implications - pure calculation function
     * @custom:validation Input validation handled by calling contract
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - pure function
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public function
     * @custom:oracle No oracle dependencies
     */
    function calculateCurrentVotingPower(
        LockInfo memory lockInfo,
        uint256 currentTime
    ) external pure returns (uint256 votingPower) {
        // If no lock or lock has expired, return 0
        if (lockInfo.unlockTime <= currentTime || lockInfo.amount == 0) {
            return 0;
        }
        
        // If lock hasn't started yet, return initial voting power
        if (lockInfo.unlockTime <= lockInfo.lockTime) {
            return lockInfo.initialVotingPower;
        }
        
        // Calculate remaining time
        uint256 remainingTime = lockInfo.unlockTime - currentTime;
        uint256 originalLockTime = lockInfo.lockTime;
        
        // Voting power decreases linearly to zero
        // Use the smaller of remaining time or original lock time to prevent overflow
        if (remainingTime >= originalLockTime) {
            return lockInfo.initialVotingPower;
        }
        
        return lockInfo.initialVotingPower * remainingTime / originalLockTime;
    }
    
    // =============================================================================
    // LOCK TIME CALCULATIONS
    // =============================================================================
    
    /**
     * @notice Calculate unlock time with proper validation
     * @dev Calculates new unlock time based on current timestamp and lock duration
     * @param currentTimestamp Current timestamp for calculation
     * @param lockTime Duration to lock tokens
     * @param existingUnlockTime Existing unlock time if already locked
     * @return newUnlockTime Calculated unlock time
     * @custom:security Prevents timestamp overflow in unlock time calculations
     * @custom:validation Input validation handled by calling contract
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws InvalidTime if result exceeds uint32 max
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public function
     * @custom:oracle No oracle dependencies
     */
    function calculateUnlockTime(
        uint256 currentTimestamp,
        uint256 lockTime,
        uint256 existingUnlockTime
    ) external pure returns (uint256 newUnlockTime) {
        return _calculateUnlockTime(currentTimestamp, lockTime, existingUnlockTime);
    }
    
    /**
     * @notice Internal function to calculate unlock time with proper validation
     * @dev Calculates new unlock time based on current timestamp and lock duration
     * @param currentTimestamp Current timestamp for calculation
     * @param lockTime Duration to lock tokens
     * @param existingUnlockTime Existing unlock time if already locked
     * @return newUnlockTime Calculated unlock time
     * @custom:security Prevents timestamp overflow in unlock time calculations
     * @custom:validation Input validation handled by calling function
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws InvalidTime if result exceeds uint32 max
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal function
     * @custom:oracle No oracle dependencies
     */
    function _calculateUnlockTime(
        uint256 currentTimestamp,
        uint256 lockTime,
        uint256 existingUnlockTime
    ) internal pure returns (uint256 newUnlockTime) {
        newUnlockTime = currentTimestamp + lockTime;
        if (newUnlockTime > type(uint32).max) revert CommonErrorLibrary.InvalidTime();
        
        // If already locked, extend the lock time
        if (existingUnlockTime > currentTimestamp) {
            newUnlockTime = existingUnlockTime + lockTime;
            if (newUnlockTime > type(uint32).max) revert CommonErrorLibrary.InvalidTime();
        }
    }
    
    // =============================================================================
    // VALIDATION FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Validate all amounts and lock times, returns total amount
     * @dev Ensures all amounts and lock times are valid and calculates total amount
     * @param amounts Array of QTI amounts to lock
     * @param lockTimes Array of lock durations
     * @return totalAmount Total amount of QTI to be locked
     * @custom:security Prevents invalid amounts and lock times from being processed
     * @custom:validation Validates amounts are positive and lock times are within bounds
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws various validation errors for invalid inputs
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public function
     * @custom:oracle No oracle dependencies
     */
    function validateAndCalculateTotalAmount(
        uint256[] calldata amounts, 
        uint256[] calldata lockTimes
    ) external pure returns (uint256 totalAmount) {
        for (uint256 i = 0; i < amounts.length; i++) {
            CommonValidationLibrary.validatePositiveAmount(amounts[i]);
            if (lockTimes[i] < MIN_LOCK_TIME) revert CommonErrorLibrary.LockTimeTooShort();
            if (lockTimes[i] > MAX_LOCK_TIME) revert CommonErrorLibrary.LockTimeTooLong();
            if (amounts[i] > type(uint96).max) revert CommonErrorLibrary.InvalidAmount();
            if (lockTimes[i] > type(uint32).max) revert CommonErrorLibrary.InvalidTime();
            
            totalAmount += amounts[i];
        }
    }
    
    // =============================================================================
    // BATCH PROCESSING
    // =============================================================================
    
    /**
     * @notice Process batch locks and calculate totals
     * @dev Processes batch lock operations and calculates total voting power and amounts
     * @param amounts Array of QTI amounts to lock
     * @param lockTimes Array of lock durations
     * @param currentTimestamp Current timestamp
     * @param existingUnlockTime Existing unlock time if already locked
     * @return totalNewVotingPower Total new voting power from all locks
     * @return totalNewAmount Total new amount locked
     * @return finalUnlockTime Final unlock time after all locks
     * @return finalLockTime Final lock time
     * @return veQTIAmounts Array of calculated voting power amounts
     * @custom:security Prevents overflow in batch calculations
     * @custom:validation Input validation handled by calling contract
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - pure function
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public function
     * @custom:oracle No oracle dependencies
     */
    function processBatchLocks(
        uint256[] calldata amounts,
        uint256[] calldata lockTimes,
        uint256 currentTimestamp,
        uint256 existingUnlockTime
    ) external pure returns (
        uint256 totalNewVotingPower,
        uint256 totalNewAmount,
        uint256 finalUnlockTime,
        uint256 finalLockTime,
        uint256[] memory veQTIAmounts
    ) {
        veQTIAmounts = new uint256[](amounts.length);
        finalUnlockTime = existingUnlockTime;
        
        for (uint256 i = 0; i < amounts.length;) {
            uint256 newUnlockTime = _calculateUnlockTime(currentTimestamp, lockTimes[i], existingUnlockTime);
            uint256 newVotingPower = _calculateVotingPower(amounts[i], lockTimes[i]);
            
            veQTIAmounts[i] = newVotingPower;
            totalNewVotingPower += newVotingPower;
            totalNewAmount += amounts[i];
            
            // Store final values for last iteration
            finalUnlockTime = newUnlockTime;
            finalLockTime = lockTimes[i];
            
            unchecked { ++i; }
        }
    }
    
    /**
     * @notice Update lock info with overflow checks
     * @dev Updates user's lock information with new amounts and times
     * @param totalNewAmount Total new amount to lock
     * @param newUnlockTime New unlock time
     * @param totalNewVotingPower Total new voting power
     * @param lockTime Lock duration
     * @return updatedLockInfo Updated lock information
     * @custom:security Prevents overflow in lock info updates
     * @custom:validation Validates amounts and times are within bounds
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws InvalidAmount if values exceed uint96 max
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public function
     * @custom:oracle No oracle dependencies
     */
    function updateLockInfo(
        uint256 totalNewAmount,
        uint256 newUnlockTime,
        uint256 totalNewVotingPower,
        uint256 lockTime
    ) external pure returns (LockInfo memory updatedLockInfo) {
        if (totalNewAmount > type(uint96).max) revert CommonErrorLibrary.InvalidAmount();
        if (totalNewVotingPower > type(uint96).max) revert CommonErrorLibrary.InvalidAmount();
        
        updatedLockInfo.amount = uint96(totalNewAmount);
        updatedLockInfo.unlockTime = uint32(newUnlockTime);
        updatedLockInfo.initialVotingPower = uint96(totalNewVotingPower);
        updatedLockInfo.lockTime = uint32(lockTime);
        updatedLockInfo.votingPower = uint96(totalNewVotingPower);
    }
    
    // =============================================================================
    // GOVERNANCE CALCULATIONS
    // =============================================================================
    
    /**
     * @notice Calculate decentralization level based on time elapsed
     * @dev Calculates decentralization level based on elapsed time since start
     * @param currentTime Current timestamp
     * @param decentralizationStartTime Start time for decentralization
     * @param decentralizationDuration Total duration for decentralization
     * @param maxTimeElapsed Maximum time elapsed to consider
     * @return newLevel New decentralization level (0-10000)
     * @custom:security No security implications - pure calculation function
     * @custom:validation Input validation handled by calling contract
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors No errors thrown - pure function
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Public function
     * @custom:oracle No oracle dependencies
     */
    function calculateDecentralizationLevel(
        uint256 currentTime,
        uint256 decentralizationStartTime,
        uint256 decentralizationDuration,
        uint256 maxTimeElapsed
    ) external pure returns (uint256 newLevel) {
        uint256 timeElapsed = currentTime - decentralizationStartTime;
        
        if (timeElapsed > maxTimeElapsed) {
            timeElapsed = maxTimeElapsed;
        }
        
        newLevel = timeElapsed * 10000 / decentralizationDuration;
        
        if (newLevel > 10000) newLevel = 10000;
    }
}
