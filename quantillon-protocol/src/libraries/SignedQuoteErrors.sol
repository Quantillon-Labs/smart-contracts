// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Errors shared by signed execution and reference validation.
library SignedQuoteErrors {
    error InvalidBinding();
    error InvalidSignature();
    error InvalidTime();
    error InvalidReport();
    error QuoteRequired();
    error QuoteConsumed();
    error InvalidMode();
    error CapacityExceeded();
    error InvalidAmount();
    error ExcessiveImpact();
    error ActiveSettlement();
}
