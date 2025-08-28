// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./ErrorLibrary.sol";

/**
 * @title ValidationLibrary
 * @notice Validation functions for Quantillon Protocol
 * @dev Extracts validation logic to reduce contract size
 */
library ValidationLibrary {
    function validateLeverage(uint256 leverage, uint256 maxLeverage) internal pure {
        if (leverage == 0) revert ErrorLibrary.InvalidLeverage();
        if (leverage > maxLeverage) revert ErrorLibrary.LeverageTooHigh();
    }
    
    function validateMarginRatio(uint256 marginRatio, uint256 minRatio) internal pure {
        if (marginRatio < minRatio) revert ErrorLibrary.MarginRatioTooLow();
    }
    
    function validateFee(uint256 fee, uint256 maxFee) internal pure {
        if (fee > maxFee) revert ErrorLibrary.FeeTooHigh();
    }
    
    function validateRate(uint256 rate, uint256 maxRate) internal pure {
        if (rate > maxRate) revert ErrorLibrary.InvalidRate();
    }
    
    function validateThreshold(uint256 threshold, uint256 maxThreshold) internal pure {
        if (threshold > maxThreshold) revert ErrorLibrary.InvalidThreshold();
    }
    
    function validateRatio(uint256 ratio, uint256 maxRatio) internal pure {
        if (ratio > maxRatio) revert ErrorLibrary.InvalidRatio();
    }
    
    function validatePositiveAmount(uint256 amount) internal pure {
        if (amount <= 0) revert ErrorLibrary.InvalidAmount();
    }
    
    function validateYieldShift(uint256 shift) internal pure {
        if (shift > 10000) revert ErrorLibrary.InvalidYieldShift();
    }
    
    function validateAdjustmentSpeed(uint256 speed, uint256 maxSpeed) internal pure {
        if (speed > maxSpeed) revert ErrorLibrary.AdjustmentSpeedTooHigh();
    }
    
    function validateTargetRatio(uint256 ratio, uint256 maxRatio) internal pure {
        if (ratio == 0) revert ErrorLibrary.InvalidRatio();
        if (ratio > maxRatio) revert ErrorLibrary.TargetRatioTooHigh();
    }
    
    function validateHoldingPeriod(uint256 depositTime, uint256 minPeriod) internal view {
        uint256 timeElapsed = block.timestamp - depositTime;
        if (timeElapsed < minPeriod) revert ErrorLibrary.HoldingPeriodNotMet();
    }
    
    function validateLiquidationCooldown(uint256 lastAttempt, uint256 cooldown) internal view {
        if (block.timestamp < lastAttempt + cooldown) revert ErrorLibrary.LiquidationCooldown();
    }
    
    function validateBalance(uint256 balance, uint256 required) internal pure {
        if (balance < required) revert ErrorLibrary.InsufficientBalance();
    }
    
    function validateExposure(uint256 current, uint256 max) internal pure {
        if (current > max) revert ErrorLibrary.AboveLimit();
    }
    
    function validateSlippage(uint256 received, uint256 expected, uint256 tolerance) internal pure {
        if (received < expected * (10000 - tolerance) / 10000) revert ErrorLibrary.ExcessiveSlippage();
    }
    
    function validateThresholdValue(uint256 value, uint256 threshold) internal pure {
        if (value < threshold) revert ErrorLibrary.BelowThreshold();
    }
    
    function validatePositionActive(bool isActive) internal pure {
        if (!isActive) revert ErrorLibrary.PositionNotActive();
    }
    
    function validatePositionOwner(address owner, address caller) internal pure {
        if (owner != caller) revert ErrorLibrary.PositionOwnerMismatch();
    }
    
    function validatePositionCount(uint256 count, uint256 max) internal pure {
        if (count >= max) revert ErrorLibrary.TooManyPositions();
    }
    
    function validateCommitment(bool exists) internal pure {
        if (!exists) revert ErrorLibrary.NoValidCommitment();
    }
    
    function validateCommitmentNotExists(bool exists) internal pure {
        if (exists) revert ErrorLibrary.CommitmentAlreadyExists();
    }
    
    function validateOraclePrice(bool isValid) internal pure {
        if (!isValid) revert ErrorLibrary.InvalidOraclePrice();
    }
    
    function validateAaveHealth(bool isHealthy) internal pure {
        if (!isHealthy) revert ErrorLibrary.AavePoolNotHealthy();
    }
    
    function validateTimeElapsed(uint256 elapsed, uint256 max) internal pure {
        if (elapsed > max) revert ErrorLibrary.TimeElapsedTooHigh();
    }
    
    function validateArrayLength(uint256 length, uint256 expected) internal pure {
        if (length != expected) revert ErrorLibrary.ArrayLengthMismatch();
    }
    
    function validateArrayNotEmpty(uint256 length) internal pure {
        if (length == 0) revert ErrorLibrary.EmptyArray();
    }
    
    function validateIndex(uint256 index, uint256 length) internal pure {
        if (index >= length) revert ErrorLibrary.IndexOutOfBounds();
    }
}
