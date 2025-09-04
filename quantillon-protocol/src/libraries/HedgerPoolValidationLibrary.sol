// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./ErrorLibrary.sol";

/**
 * @title HedgerPoolValidationLibrary
 * @notice Validation functions for HedgerPool to reduce contract size
 */
library HedgerPoolValidationLibrary {
    function validatePositionParams(
        uint256 netMargin,
        uint256 positionSize,
        uint256 eurUsdPrice,
        uint256 leverage,
        uint256 maxMargin,
        uint256 maxPositionSize,
        uint256 maxEntryPrice,
        uint256 maxLeverage
    ) internal pure {
        if (netMargin > maxMargin) revert ErrorLibrary.MarginExceedsMaximum();
        if (positionSize > maxPositionSize) revert ErrorLibrary.PositionSizeExceedsMaximum();
        if (eurUsdPrice > maxEntryPrice) revert ErrorLibrary.EntryPriceExceedsMaximum();
        if (leverage > maxLeverage) revert ErrorLibrary.LeverageExceedsMaximum();
    }
    
    function validateTotals(
        uint256 currentMargin,
        uint256 currentExposure,
        uint256 additionalMargin,
        uint256 additionalExposure,
        uint256 maxTotalMargin,
        uint256 maxTotalExposure
    ) internal pure {
        if (currentMargin + additionalMargin > maxTotalMargin) revert ErrorLibrary.TotalMarginExceedsMaximum();
        if (currentExposure + additionalExposure > maxTotalExposure) revert ErrorLibrary.TotalExposureExceedsMaximum();
    }
    
    function validateTimestamp(uint256 timestamp) internal pure {
        if (timestamp > type(uint32).max) revert ErrorLibrary.TimestampOverflow();
    }
    
    function validateNewMargin(uint256 newMargin, uint256 maxMargin) internal pure {
        if (newMargin > maxMargin) revert ErrorLibrary.NewMarginExceedsMaximum();
    }
    
    function validatePendingRewards(uint256 newRewards, uint256 maxRewards) internal pure {
        if (newRewards > maxRewards) revert ErrorLibrary.PendingRewardsExceedMaximum();
    }
}
