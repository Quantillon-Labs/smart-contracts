// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title HedgerPoolErrorLibrary
 * @notice HedgerPool-specific errors for Quantillon Protocol
 *
 * @dev Main characteristics:
 *      - Errors specific to HedgerPool operations
 *      - Trading position management errors
 *      - Liquidation system errors
 *      - Margin and leverage validation errors
 *
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
library HedgerPoolErrorLibrary {
    /// @notice Library version (semver); see deployments/{chainId}/versions.json for provenance.
    string internal constant VERSION = "1.0.0";

    // HedgerPool Specific Errors
    error FlashLoanAttackDetected();
    error InvalidPosition();
    error InvalidHedger();
    error OnlyVault();
    error RewardOverflow();
    error InsufficientMargin();

    // Position Limit Errors
    error MarginExceedsMaximum();
    error PositionSizeExceedsMaximum();
    error EntryPriceExceedsMaximum();
    error LeverageExceedsMaximum();
    error TimestampOverflow();
    error TotalMarginExceedsMaximum();
    error TotalExposureExceedsMaximum();
    error NewMarginExceedsMaximum();

    // Leverage and Margin Errors
    error InvalidLeverage();
    error LeverageTooHigh();
    error MarginRatioTooLow();
    error MarginRatioTooHigh();

    // Position Management Errors
    error PositionOwnerMismatch();
    error PositionClosureRestricted();
    error InsufficientHedgerCapacity();
    error NoActiveHedgerLiquidity();
    error HedgerHasActivePosition();
    error MinHoldPeriodNotElapsed();
}
