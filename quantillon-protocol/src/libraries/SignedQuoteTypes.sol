// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title SignedQuoteTypes
/// @notice Wire types shared by the vault, signers and report consumers.
library SignedQuoteTypes {
    string internal constant VERSION = "1.0.0";
    enum Action { Mint, Redeem, Yield }
    enum Mode { Paused, Signed, EmergencyRedeem }

    /// @notice Exact public settlement, or bounded yield conversion. Calldata binds the complete route.
    /// @dev Yield amountIn is a maximum and amountOut is the output at that maximum.
    struct Quote {
        address user;
        address caller;
        Action action;
        uint256 amountIn;
        uint256 amountOut;
        uint256 observedAt;
        uint256 validAfter;
        uint256 validUntil;
        uint256 nonce;
        uint256 epoch;
        bytes32 callHash;
        bytes32 referenceHash;
    }
    /// @notice Original market observation, never timestamped at submission.
    struct ReferenceReport {
        uint256 price;
        uint256 observedAt;
        uint256 sequence;
        uint256 epoch;
    }
    /// @notice Lifetime fill acknowledgments and additional venue margin capacity.
    /// @dev canonicalBlock/hash identify the Base state actually reconciled by the reporter.
    struct CapacityReport {
        uint256 acknowledgedBuy;
        uint256 acknowledgedSell;
        uint256 capacity;
        uint256 observedAt;
        uint256 sequence;
        uint256 epoch;
        uint256 canonicalBlock;
        bytes32 canonicalBlockHash;
    }
    /// @notice Reports carried atomically with a settlement.
    struct Authorization {
        Quote quote;
        bytes signature;
        ReferenceReport referenceReport;
        bytes referenceSignature;
        CapacityReport capacityReport;
        bytes capacitySignature;
    }
}
