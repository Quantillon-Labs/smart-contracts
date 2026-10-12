// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ISlippageStorage} from "../interfaces/ISlippageStorage.sol";
import {SignedQuoteTypes as T} from "../libraries/SignedQuoteTypes.sol";
import {SignedQuoteErrors as E} from "../libraries/SignedQuoteErrors.sol";

/// @notice Independent reference source that never substitutes cached data for an invalid round.
interface ISignedIndependentReference {
    /**
     * @notice Read an independent reference, its original observation time and validity.
     * @dev Returns the declared configuration or derived value without updating state.
     * @return Value defined by this accessor or calculation.
     * @return Value defined by this accessor or calculation.
     * @return Value defined by this accessor or calculation.
     * @custom:security Read-only; does not authorize settlement.
     * @custom:validation Uses the declared input types; target interface calls may revert.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input or target read failures.
     * @custom:reentrancy Read-only.
     * @custom:access Public.
     * @custom:oracle No fresh observation is created; reference getters expose existing source data.
     */
    function peekEurUsdPrice() external view returns (uint256, uint256, bool);
}

/// @title SignedReferenceSource
/// @notice Pull-delivered market reference compatible with HyperliquidEurUsdOracle's snapshot reader.
/// @dev The existing oracle retains price bounds, deviation checks, USDC validation and router semantics.
contract SignedReferenceSource is AccessControl, EIP712 {
    bytes32 public constant REFERENCE_SIGNER_ROLE = keccak256("REFERENCE_SIGNER_ROLE");
    bytes32 public constant EMERGENCY_CONTROLLER_ROLE = keccak256("EMERGENCY_CONTROLLER_ROLE");
    bytes32 public constant REPORT_TYPEHASH = keccak256("ReferenceReport(uint256 price,uint256 observedAt,uint256 sequence,uint256 epoch)");
    ISignedIndependentReference public immutable independentReference;
    uint256 public immutable maxAge;
    uint256 public immutable maxReferenceAge;
    uint256 public immutable normalDivergenceBps;
    uint256 public immutable offHoursDivergenceBps;
    uint256 public epoch = 1;
    uint256 public sequence;
    uint256 public observedAt;
    uint256 public price;
    bytes32 public reportHash;
    bool public emergency;

    event ReferenceAccepted(bytes32 indexed digest, uint256 price, uint256 observedAt, uint256 sequence);
    event ReferenceEpochChanged(uint256 epoch, bool emergency);

    /**
     * @notice Bind the reference authority and immutable freshness and divergence limits.
     * @dev Binds the EIP-712 domain and immutable safety limits at deployment.
     * @param admin Authority administering roles and operating parameters.
     * @param independent Contract supplying independently validated EUR/USD observations.
     * @param age Maximum accepted report age in seconds.
     * @param referenceAge Maximum independent-reference age in seconds.
     * @param normalBps Reference divergence bound during normal trading hours.
     * @param offHoursBps Reference divergence bound outside normal trading hours.
     * @custom:security Validates domain-specific permissions and configured risk bounds.
     * @custom:validation Rejects zero or incompatible dependencies and out-of-range safety parameters.
     * @custom:state-changes Sets immutable policy, initial mode and administrator role.
     * @custom:events RoleGranted for the initial administrator.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy Independent price reads use static calls.
     * @custom:access Public.
     * @custom:oracle Independent EUR/USD validation; accepted reports preserve original market timestamps.
     */
    constructor(address admin, address independent, uint256 age, uint256 referenceAge, uint256 normalBps, uint256 offHoursBps)
        EIP712("Quantillon Reference", "1")
    {
        if (admin == address(0) || independent.code.length == 0 || age == 0 || age > 900 || referenceAge == 0 || normalBps == 0 || normalBps > 300 || offHoursBps < normalBps || offHoursBps > 300) revert E.InvalidBinding();
        independentReference = ISignedIndependentReference(independent);
        maxAge = age; maxReferenceAge = referenceAge;
        normalDivergenceBps = normalBps; offHoursDivergenceBps = offHoursBps;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /**
     * @notice Return the semantic version of this implementation.
     * @dev Returns the declared configuration or derived value without updating state.
     * @return Value defined by this accessor or calculation.
     * @custom:security Read-only; does not authorize settlement.
     * @custom:validation Uses the declared input types; target interface calls may revert.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input or target read failures.
     * @custom:reentrancy Read-only.
     * @custom:access Public.
     * @custom:oracle No fresh observation is created; reference getters expose existing source data.
     */
    function version() external pure returns (string memory) { return "1.0.0"; }

    /**
     * @notice Hash a market-reference report using this chain and source's EIP-712 domain.
     * @dev Returns the declared configuration or derived value without updating state.
     * @param r Signed report containing its original observation, sequence and epoch.
     * @return Value defined by this accessor or calculation.
     * @custom:security Read-only; does not authorize settlement.
     * @custom:validation Uses the declared input types; target interface calls may revert.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input or target read failures.
     * @custom:reentrancy Read-only.
     * @custom:access Public.
     * @custom:oracle No fresh observation is created; reference getters expose existing source data.
     */
    function digest(T.ReferenceReport calldata r) public view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(REPORT_TYPEHASH, r)));
    }

    /**
     * @notice Authenticate a reference report, updating the cache only for newer observations.
     * @dev Original observation timestamps remain authoritative; signature replay never refreshes them.
     * @param r Signed report containing its original observation, sequence and epoch.
     * @param signature EIP-712 signature by the corresponding authorized signer.
     * @return hash EIP-712 digest of the accepted report.
     * @custom:security Validates domain-specific permissions and configured risk bounds.
     * @custom:validation Enforces the checks described for this operation; invalid authorization reverts.
     * @custom:state-changes Stores price, original observation, sequence and digest.
     * @custom:events ReferenceAccepted for a new observation.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy Independent price reads use static calls.
     * @custom:access Anyone may relay a valid reference signature.
     * @custom:oracle Independent EUR/USD validation; accepted reports preserve original market timestamps.
     */
    function submit(T.ReferenceReport calldata r, bytes calldata signature) external returns (bytes32 hash) {
        if (emergency || r.epoch != epoch) revert E.InvalidMode();
        if (r.observedAt == 0 || r.observedAt > block.timestamp || block.timestamp - r.observedAt > maxAge) revert E.InvalidTime();
        hash = digest(r);
        if (!hasRole(REFERENCE_SIGNER_ROLE, ECDSA.recover(hash, signature))) revert E.InvalidSignature();
        _validateIndependent(r.price);
        if (r.price < 0.8e18 || r.price > 1.4e18) revert E.InvalidReport();
        if (hash == reportHash) return hash;
        // Quotes may arrive out of issuance order. Authenticate their reference
        // without rolling valuation or its original observation backwards.
        if (reportHash != bytes32(0) && r.sequence < sequence && r.observedAt <= observedAt) return hash;
        if (r.sequence <= sequence || r.observedAt < observedAt) revert E.InvalidReport();
        price = r.price; observedAt = r.observedAt; sequence = r.sequence; reportHash = hash;
        emit ReferenceAccepted(hash, price, observedAt, sequence);
    }

    /**
     * @notice Change reference mode and invalidate prior reference authorizations.
     * @dev Original observation timestamps remain authoritative; signature replay never refreshes them.
     * @param enabled Enabled-vault mapping, or requested emergency state for the reference source.
     * @custom:security Validates domain-specific permissions and configured risk bounds.
     * @custom:validation Enforces the checks described for this operation; invalid authorization reverts.
     * @custom:state-changes Updates emergency state and reference epoch.
     * @custom:events ReferenceEpochChanged when the mode changes.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy Independent price reads use static calls.
     * @custom:access Emergency-controller role only.
     * @custom:oracle Independent EUR/USD validation; accepted reports preserve original market timestamps.
     */
    function setEmergency(bool enabled) external onlyRole(EMERGENCY_CONTROLLER_ROLE) {
        if (emergency == enabled) return;
        emergency = enabled; ++epoch; reportHash = bytes32(0);
        emit ReferenceEpochChanged(epoch, enabled);
    }

    /**
     * @notice Read a compatible snapshot with its original market or independent-reference timestamp.
     * @dev Returns the declared configuration or derived value without updating state.
     * @param source Reference-source address, or snapshot source ID for the snapshot reader.
     * @return snapshot Price and original timestamp in the snapshot interface.
     * @custom:security Read-only; does not authorize settlement.
     * @custom:validation Uses the declared input types; target interface calls may revert.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input or target read failures.
     * @custom:reentrancy Read-only.
     * @custom:access Public.
     * @custom:oracle No fresh observation is created; reference getters expose existing source data.
     */
    function getSlippageBySource(uint8 source) external view returns (ISlippageStorage.SlippageSnapshot memory snapshot) {
        if (source != 1) revert E.InvalidBinding();
        uint256 p = price; uint256 time = observedAt;
        if (emergency) (p, time) = _independent();
        if (time == 0 || time > block.timestamp || block.timestamp - time > (emergency ? maxReferenceAge : maxAge)) return snapshot;
        snapshot.midPrice = uint128(p); snapshot.timestamp = uint48(time);
    }

    function _independent() private view returns (uint256 p, uint256 time) {
        bool valid;
        (p, time, valid) = independentReference.peekEurUsdPrice();
        if (!valid || p < 0.8e18 || p > 1.4e18 || time == 0 || time > block.timestamp || block.timestamp - time > maxReferenceAge) revert E.InvalidReport();
    }

    function _validateIndependent(uint256 candidate) private view {
        (uint256 p,) = _independent();
        uint256 day = (block.timestamp / 1 days + 4) % 7;
        bool offHours = (day == 5 && block.timestamp % 1 days >= 21 hours) || day == 6 || (day == 0 && block.timestamp % 1 days <= 21 hours);
        uint256 difference = candidate > p ? candidate - p : p - candidate;
        if (difference * 10_000 > p * (offHours ? offHoursDivergenceBps : normalDivergenceBps)) revert E.ExcessiveImpact();
    }
}
