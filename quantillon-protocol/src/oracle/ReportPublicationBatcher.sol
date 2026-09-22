// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IVersioned} from "../interfaces/IVersioned.sol";
import {CommonErrorLibrary as Errors} from "../libraries/CommonErrorLibrary.sol";

/**
 * @title ReportPublicationBatcher
 * @notice Publishes any combination of market price, depth and reconciled capacity.
 * @dev Fixed destinations and selectors. Reports fail independently; target events
 *      determine accepted data, since a successful price call can skip a source.
 * @custom:security Only the immutable writer can publish. Each subcall has a fixed
 *      gas budget, reserved before execution so estimation cannot starve later reports.
 * @custom:security-contact team@quantillon.money
 */
contract ReportPublicationBatcher is IVersioned {
    /// @notice Authorized publisher account.
    address public immutable writer;
    /// @notice Market summary storage.
    address public immutable priceStore;
    /// @notice Execution depth and hedge capacity storage.
    address public immutable depthStore;
    /// @notice Block time of the last batch with a successful destination call.
    uint256 public lastPublicationAt;
    /// @notice Upper gas allocation for at most two market sources.
    uint256 public constant PRICE_GAS = 200_000;
    /// @notice Allocation covers the publisher's ten levels per side, including cold storage.
    uint256 public constant DEPTH_GAS = 1_100_000;
    /// @notice Upper gas allocation for a capacity acknowledgment.
    uint256 public constant CAPACITY_GAS = 150_000;
    bytes4 private constant PRICE_SELECTOR = bytes4(keccak256("updateSlippageBatch((uint8,uint128,uint128,uint16,uint16,uint16[5])[])"));
    bytes4 private constant DEPTH_SELECTOR = bytes4(keccak256("publish(uint256,(uint128,uint128)[],(uint128,uint128)[])"));
    bytes4 private constant CAPACITY_SELECTOR = bytes4(keccak256("acknowledge(uint256,uint256,uint256,uint256)"));
    /// @notice Masks use price=1, depth=2, capacity=4. Success denotes call success, not source acceptance.
    event ReportsPublished(uint8 attempted, uint8 succeeded);
    /// @notice First four revert bytes for a failed report; no unbounded return data is copied.
    event ReportRejected(uint8 indexed report, bytes4 reason);
    error InsufficientReportGas();
    error NoSuccessfulReports();

    /**
     * @notice Set permanent publisher and target addresses.
     * @dev Constructor wiring is immutable and rejects overlapping publisher and destination addresses.
     * @param publisher Publisher account, distinct from both destinations.
     * @param price Deployed price storage.
     * @param depth Deployed execution pricing contract.
     * @custom:security No role grants or arbitrary targets are exposed.
     * @custom:validation Rejects zero, non-contract, or overlapping addresses.
     * @custom:state-changes Stores immutable writer and destination addresses.
     * @custom:events None.
     * @custom:errors InvalidAddress for invalid wiring.
     * @custom:reentrancy No external calls.
     * @custom:access Deployment only.
     * @custom:oracle None.
     */
    constructor(address publisher, address price, address depth) {
        if (publisher == address(0) || price.code.length == 0 || depth.code.length == 0 ||
            price == depth || publisher == price || publisher == depth) revert Errors.InvalidAddress();
        writer = publisher; priceStore = price; depthStore = depth;
    }

    /**
     * @notice Submit one, two or three independently validated reports.
     * @param priceCall Encoded updateSlippageBatch, or empty to omit.
     * @param depthCall Encoded publish, or empty to omit.
     * @param capacityCall Encoded acknowledge, or empty to omit.
     * @return succeeded Destination-call success mask; inspect target events for accepted reports.
     * @dev Price then depth then capacity preserves the existing combined-publication order.
     *      Capacity never resets consumed depth; a later fresh book applies the target's rules.
     * @custom:security Rejects invalid selectors before any effects. Reverting reports do not
     *      undo valid reports. All-failed batches revert so preflight estimation rejects them.
     * @custom:validation Requires at least one supported call and enough gas for the selected reports.
     * @custom:state-changes Updates successful target reports and the publication timestamp.
     * @custom:events Emits ReportsPublished and ReportRejected for failed subcalls.
     * @custom:errors NotAuthorized, InvalidParameter, InsufficientReportGas, or NoSuccessfulReports.
     * @custom:reentrancy Uses bounded low-level calls to immutable targets.
     * @custom:access Restricted to the immutable writer.
     * @custom:oracle Reads no oracle directly; forwards validated report calls.
     */
    function publishReports(bytes calldata priceCall, bytes calldata depthCall, bytes calldata capacityCall)
        external returns (uint8 succeeded)
    {
        if (msg.sender != writer) revert Errors.NotAuthorized();
        uint8 attempted;
        uint256 budget = 70_000;
        if (priceCall.length != 0) { _selector(priceCall, PRICE_SELECTOR); attempted |= 1; budget += PRICE_GAS; }
        if (depthCall.length != 0) { _selector(depthCall, DEPTH_SELECTOR); attempted |= 2; budget += DEPTH_GAS; }
        if (capacityCall.length != 0) { _selector(capacityCall, CAPACITY_SELECTOR); attempted |= 4; budget += CAPACITY_GAS; }
        if (attempted == 0) revert Errors.InvalidParameter();
        // Includes EIP-150 forwarding headroom, calldata copies, logs and the cadence write.
        if (gasleft() < budget) revert InsufficientReportGas();
        if (priceCall.length != 0 && _call(priceStore, priceCall, PRICE_GAS, 1)) succeeded |= 1;
        if (depthCall.length != 0 && _call(depthStore, depthCall, DEPTH_GAS, 2)) succeeded |= 2;
        if (capacityCall.length != 0 && _call(depthStore, capacityCall, CAPACITY_GAS, 4)) succeeded |= 4;
        if (succeeded == 0) revert NoSuccessfulReports();
        lastPublicationAt = block.timestamp;
        emit ReportsPublished(attempted, succeeded);
    }

    function _selector(bytes calldata data, bytes4 expected) private pure {
        if (data.length < 4 || bytes4(data[:4]) != expected) revert Errors.InvalidParameter();
    }

    function _call(address target, bytes calldata data, uint256 budget, uint8 report) private returns (bool ok) {
        bytes memory input = data;
        bytes4 reason;
        assembly ("memory-safe") {
            ok := call(budget, target, 0, add(input, 32), mload(input), 0, 0)
            if iszero(ok) {
                mstore(0, 0)
                let size := returndatasize()
                if gt(size, 4) { size := 4 }
                returndatacopy(0, 0, size)
                reason := mload(0)
            }
        }
        if (!ok) emit ReportRejected(report, reason);
    }

    /**
     * @notice Semantic version of this separately deployed, non-upgradeable contract.
     * @dev The value is embedded in bytecode for release traceability.
     * @return Semantic version string.
     * @custom:security No security implications; this is a pure constant getter.
     * @custom:validation No input validation.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable.
     * @custom:access Public.
     * @custom:oracle None.
     */
    function version() external pure override returns (string memory) { return "1.0.0"; }
}
