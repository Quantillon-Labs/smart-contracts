// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./ErrorLibrary.sol";

/**
 * @title ValidationLibrary
 * @notice Validation functions for Quantillon Protocol
 * 
 * @dev Main characteristics:
 *      - Comprehensive parameter validation for leverage, margin, fees, and rates
 *      - Time-based validation for holding periods and liquidation cooldowns
 *      - Balance and exposure validation functions
 *      - Array and position validation utilities
 * 
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
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
    
    function validateThreshold(uint256 threshold, uint256 maxThreshold) internal pure {
        if (threshold > maxThreshold) revert ErrorLibrary.InvalidThreshold();
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
    
    function validateLiquidationCooldown(uint256 lastAttempt, uint256 cooldown) internal view {
        if (block.number < lastAttempt + cooldown) revert ErrorLibrary.LiquidationCooldown();
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
    
    function validateCommitmentNotExists(bool exists) internal pure {
        if (exists) revert ErrorLibrary.CommitmentAlreadyExists();
    }
    
    function validateCommitment(bool exists) internal pure {
        if (!exists) revert ErrorLibrary.NoValidCommitment();
    }
    
    function validateOraclePrice(bool isValid) internal pure {
        if (!isValid) revert ErrorLibrary.InvalidOraclePrice();
    }
}
