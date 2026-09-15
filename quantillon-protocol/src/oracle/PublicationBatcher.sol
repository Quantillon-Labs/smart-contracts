// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IVersioned} from "../interfaces/IVersioned.sol";
import {CommonErrorLibrary as Errors} from "../libraries/CommonErrorLibrary.sol";

/**
 * @title PublicationBatcher
 * @notice Publishes market summaries and execution depth in one transaction.
 * @dev Immutable, non-upgradeable forwarding contract. Existing target validation
 *      and events are preserved, including SlippageStorage's per-source skips.
 *      Governance must grant this contract WRITER_ROLE on both destinations.
 * @custom:security Only the fixed writer can call the two fixed publication selectors.
 * @custom:security-contact team@quantillon.money
 */
contract PublicationBatcher is IVersioned {
    /// @notice Account authorized to submit combined publications.
    address public immutable writer;
    /// @notice SlippageStorage destination for market summaries.
    address public immutable priceStore;
    /// @notice ExecutionPricing destination for executable order books.
    address public immutable depthStore;
    /// @dev The sole allowed SlippageStorage entry point.
    bytes4 private constant PRICE_SELECTOR = bytes4(keccak256("updateSlippageBatch((uint8,uint128,uint128,uint16,uint16,uint16[5])[])"));
    /// @dev The sole allowed ExecutionPricing entry point.
    bytes4 private constant DEPTH_SELECTOR = bytes4(keccak256("publish(uint256,(uint128,uint128)[],(uint128,uint128)[])"));

    /**
     * @notice Fix the writer and both publication destinations for this deployment.
     * @dev The writer cannot be either destination, preventing target callbacks.
     * @param publisher Authorized publication account.
     * @param price SlippageStorage contract.
     * @param depth ExecutionPricing contract.
     * @custom:security Targets must contain code and be distinct from the writer and each other.
     * @custom:validation Nonzero writer, deployed and distinct destinations.
     * @custom:state-changes Sets immutable deployment bindings.
     * @custom:events None.
     * @custom:errors InvalidAddress on invalid bindings.
     * @custom:reentrancy No external calls.
     * @custom:access Deployment only.
     * @custom:oracle No oracle reads.
     */
    constructor(address publisher, address price, address depth) {
        if (publisher == address(0) || price.code.length == 0 || depth.code.length == 0 ||
            price == depth || publisher == price || publisher == depth) revert Errors.InvalidAddress();
        writer = publisher;
        priceStore = price;
        depthStore = depth;
    }

    /**
     * @notice Forward both reports atomically, market summaries first.
     * @dev Revert data is propagated unchanged. No ETH, delegatecall, generic calls
     *      or role management is exposed. A target revert rolls back both calls;
     *      a source silently skipped by SlippageStorage remains skipped.
     * @param priceCall ABI-encoded updateSlippageBatch call.
     * @param depthCall ABI-encoded publish call.
     * @custom:security Fixed caller, targets and selectors; callbacks from targets cannot reenter.
     * @custom:validation Caller and selectors here; report validation in each destination.
     * @custom:state-changes Updates destination reports; no local storage writes.
     * @custom:events Destination SlippageSourceUpdated and BookPublished events.
     * @custom:errors NotAuthorized, InvalidParameter, and unmodified destination errors.
     * @custom:reentrancy Target callbacks fail the immutable writer check.
     * @custom:access Only the immutable writer.
     * @custom:oracle Preserves both destinations' oracle and freshness validation.
     */
    function publishTogether(bytes calldata priceCall, bytes calldata depthCall) external {
        if (msg.sender != writer) revert Errors.NotAuthorized();
        if (priceCall.length < 4 || depthCall.length < 4 ||
            bytes4(priceCall[:4]) != PRICE_SELECTOR || bytes4(depthCall[:4]) != DEPTH_SELECTOR) {
            revert Errors.InvalidParameter();
        }
        (bool success, bytes memory result) = priceStore.call(priceCall);
        if (!success) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        (success, result) = depthStore.call(depthCall);
        if (!success) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
    }

    /**
     * @notice Return the semantic version of this contract.
     * @dev Compile-time constant for deployment provenance.
     * @return Semantic version string.
     * @custom:security Read-only metadata.
     * @custom:validation None.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy No external calls.
     * @custom:access Public.
     * @custom:oracle None.
     */
    function version() external pure override returns (string memory) { return "1.0.0"; }
}
