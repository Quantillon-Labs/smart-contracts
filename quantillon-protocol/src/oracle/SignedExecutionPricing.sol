// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IExecutionPricing} from "../interfaces/IExecutionPricing.sol";
import {SignedReferenceSource} from "./SignedReferenceSource.sol";
import {SignedQuoteTypes as T} from "../libraries/SignedQuoteTypes.sol";
import {SignedQuoteErrors as E} from "../libraries/SignedQuoteErrors.sol";

interface ISignedExecutionVault {
    /**
     * @notice Read the mint fee rate in 1e18 precision.
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
    function mintFee() external view returns (uint256);
    /**
     * @notice Read the redemption fee rate in 1e18 precision.
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
    function redemptionFee() external view returns (uint256);
    /**
     * @notice Read the vault pause state.
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
    function paused() external view returns (bool);
    /**
     * @notice Read the configured collateral token address.
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
    function usdc() external view returns (address);
}

/// @title SignedExecutionPricing
/// @notice Exact quotes with independently certified capacity and persistent admission accounting.
/// @dev Non-upgradeable, vault-bound replacement. A settlement context must begin and end in one vault call.
contract SignedExecutionPricing is AccessControl, EIP712, IExecutionPricing {
    using SafeERC20 for IERC20;
    bytes32 public constant QUOTE_SIGNER_ROLE = keccak256("QUOTE_SIGNER_ROLE");
    bytes32 public constant CAPACITY_SIGNER_ROLE = keccak256("CAPACITY_SIGNER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant QUOTE_TYPEHASH = keccak256("Quote(address user,address caller,uint8 action,uint256 amountIn,uint256 amountOut,uint256 observedAt,uint256 validAfter,uint256 validUntil,uint256 nonce,uint256 epoch,bytes32 callHash,bytes32 referenceHash)");
    bytes32 public constant CAPACITY_TYPEHASH = keccak256("CapacityReport(uint256 acknowledgedBuy,uint256 acknowledgedSell,uint256 capacity,uint256 observedAt,uint256 sequence,uint256 epoch,uint256 canonicalBlock,bytes32 canonicalBlockHash)");
    address public immutable override vault;
    address public immutable reserveRecipient;
    SignedReferenceSource public immutable referenceSource;
    uint256 public immutable maxImpactBps;
    uint256 public immutable maxOutstanding;
    uint256 public immutable maxAge;
    uint256 public immutable degradedHaircutBps;
    T.Mode public mode;
    uint256 public epoch = 1;
    uint256 public admittedBuy;
    uint256 public admittedSell;
    uint256 public acknowledgedBuy;
    uint256 public acknowledgedSell;
    uint256 public marginCapacity;
    uint256 public capacityObservedAt;
    uint256 public capacitySequence;
    bytes32 public capacityHash;
    uint256 public emergencyBudget;
    mapping(address => mapping(uint256 => bool)) public usedNonces;
    T.Quote private activeQuote;
    bool public active;
    bool private consumed;
    bool private emergencySettlement;
    uint256 private activeReference;
    bytes32 private activeDigest;

    event QuoteSettled(bytes32 indexed quoteId, address indexed caller, T.Action action, uint256 amountIn, uint256 amountOut);
    event HedgeAcknowledged(uint256 admittedBuy, uint256 admittedSell, uint256 capacity, uint256 observedAt);
    event ModeChanged(T.Mode mode, uint256 epoch);
    event EmergencyBudgetConfigured(uint256 budget);

    /**
     * @notice Bind the vault, reference source and immutable execution risk limits.
     * @dev Binds the EIP-712 domain and immutable safety limits at deployment.
     * @param admin Authority administering roles and operating parameters.
     * @param boundVault Vault allowed to prepare and consume execution contexts.
     * @param source Reference-source address, or snapshot source ID for the snapshot reader.
     * @param reserve Immutable recipient of execution spread withdrawals.
     * @param impact Maximum permitted execution impact in basis points.
     * @param outstandingLimit Maximum gross unacknowledged QEURO exposure.
     * @param age Maximum accepted report age in seconds.
     * @param haircut Emergency redemption haircut in basis points.
     * @custom:security Validates domain-specific permissions and configured risk bounds.
     * @custom:validation Rejects zero or incompatible dependencies and out-of-range safety parameters.
     * @custom:state-changes Sets immutable policy, initial mode and administrator role.
     * @custom:events RoleGranted for the initial administrator.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy Vault-only settlement and active-context checks constrain callbacks.
     * @custom:access Public.
     * @custom:oracle Signed reference and reconciled capacity for normal conversion; separate emergency policy.
     */
    constructor(address admin, address boundVault, address source, address reserve, uint256 impact, uint256 outstandingLimit, uint256 age, uint256 haircut)
        EIP712("Quantillon Execution", "1")
    {
        if (admin == address(0) || boundVault.code.length == 0 || source.code.length == 0 || reserve == address(0) || impact == 0 || impact > 500 || outstandingLimit == 0 || age == 0 || age > 300 || haircut < impact || haircut > 500) revert E.InvalidBinding();
        vault = boundVault; referenceSource = SignedReferenceSource(source); reserveRecipient = reserve;
        maxImpactBps = impact; maxOutstanding = outstandingLimit; maxAge = age; degradedHaircutBps = haircut;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        mode = T.Mode.Paused;
    }

    modifier onlyVault() { if (msg.sender != vault) revert E.InvalidBinding(); _; }
    /**
     * @notice Identify this module as requiring signed execution contexts.
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
    function supportsSignedExecution() external pure returns (bool) { return true; }
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
     * @notice Hash an execution quote using this chain and module's EIP-712 domain.
     * @dev Returns the declared configuration or derived value without updating state.
     * @param q Execution quote to hash.
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
    function quoteDigest(T.Quote calldata q) public view returns (bytes32) { return _hashTypedDataV4(keccak256(abi.encode(QUOTE_TYPEHASH, q))); }
    /**
     * @notice Hash a capacity report using this chain and module's EIP-712 domain.
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
    function capacityDigest(T.CapacityReport calldata r) public view returns (bytes32) { return _hashTypedDataV4(keccak256(abi.encode(CAPACITY_TYPEHASH, r))); }
    /**
     * @notice Return unresolved admitted buys plus unresolved admitted sells in QEURO units.
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
    function outstanding() public view override returns (uint256) { return admittedBuy - acknowledgedBuy + admittedSell - acknowledgedSell; }

    /**
     * @notice Accept monotonic fill acknowledgments bound to canonical Base state.
     * @dev Execution contexts are single-use and cannot replace the vault's accounting guards.
     * @param r Signed report containing its original observation, sequence and epoch.
     * @param signature EIP-712 signature by the corresponding authorized signer.
     * @custom:security Validates domain-specific permissions and configured risk bounds.
     * @custom:validation Enforces the checks described for this operation; invalid authorization reverts.
     * @custom:state-changes Updates acknowledged exposure, capacity, sequence and original observation time.
     * @custom:events HedgeAcknowledged.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy Vault-only settlement and active-context checks constrain callbacks.
     * @custom:access Anyone may relay a valid capacity signature.
     * @custom:oracle Signed reference and reconciled capacity for normal conversion; separate emergency policy.
     */
    function submitCapacity(T.CapacityReport calldata r, bytes calldata signature) public {
        if (r.epoch != epoch) revert E.InvalidReport();
        if (r.observedAt == 0 || r.observedAt > block.timestamp || block.timestamp - r.observedAt > maxAge) revert E.InvalidTime();
        bytes32 hash = capacityDigest(r);
        if (!hasRole(CAPACITY_SIGNER_ROLE, ECDSA.recover(hash, signature))) revert E.InvalidSignature();
        if (r.canonicalBlock >= block.number || block.number - r.canonicalBlock > 256 || r.canonicalBlockHash == bytes32(0) || blockhash(r.canonicalBlock) != r.canonicalBlockHash) revert E.InvalidReport();
        if (hash == capacityHash) return;
        // Older quotes can use a newer accepted capacity report. They may never
        // restore a higher limit, refresh its timestamp or rewind acknowledgments.
        if (capacityHash != bytes32(0) && r.sequence < capacitySequence && r.observedAt <= capacityObservedAt
            && r.acknowledgedBuy <= acknowledgedBuy && r.acknowledgedSell <= acknowledgedSell) return;
        if (r.sequence <= capacitySequence || r.observedAt < capacityObservedAt || r.acknowledgedBuy < acknowledgedBuy || r.acknowledgedSell < acknowledgedSell || r.acknowledgedBuy > admittedBuy || r.acknowledgedSell > admittedSell) revert E.InvalidReport();
        acknowledgedBuy = r.acknowledgedBuy; acknowledgedSell = r.acknowledgedSell;
        marginCapacity = Math.min(r.capacity, maxOutstanding); capacityObservedAt = r.observedAt;
        capacitySequence = r.sequence; capacityHash = hash;
        emit HedgeAcknowledged(acknowledgedBuy, acknowledgedSell, marginCapacity, capacityObservedAt);
    }

    /**
     * @notice Validate and prepare the operation before settlement.
     * @dev Execution contexts are single-use and cannot replace the vault's accounting guards.
     * @param user Original payer whose nonce and settlement are bound.
     * @param caller Executor that must match the active quote.
     * @param callData Complete ABI-encoded operation, including route and output bounds.
     * @param auth Complete execution, reference and capacity authorization.
     * @custom:security Validates domain-specific permissions and configured risk bounds.
     * @custom:validation Enforces the checks described for this operation; invalid authorization reverts.
     * @custom:state-changes Stores the active quote and consumes its nonce after report validation.
     * @custom:events Underlying operation and token events when applicable.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy Vault-only settlement and active-context checks constrain callbacks.
     * @custom:access Configured vault only.
     * @custom:oracle Signed reference and reconciled capacity for normal conversion; separate emergency policy.
     */
    function prepare(address user, address caller, bytes calldata callData, T.Authorization calldata auth) external onlyVault {
        T.Quote calldata q = auth.quote;
        if (active) revert E.ActiveSettlement();
        if (mode != T.Mode.Signed || q.epoch != epoch) revert E.InvalidMode();
        if (q.user != user || q.caller != caller || q.callHash != keccak256(callData) || callData.length < 4) revert E.InvalidBinding();
        _validateSelector(bytes4(callData[:4]), q.action);
        if (q.amountIn == 0 || q.amountOut == 0) revert E.InvalidAmount();
        if (q.observedAt == 0 || q.observedAt > q.validAfter || q.validAfter - q.observedAt > 5 || q.validUntil <= q.validAfter || q.validUntil - q.observedAt > 30 || block.timestamp < q.validAfter || block.timestamp > q.validUntil) revert E.InvalidTime();
        if (usedNonces[user][q.nonce]) revert E.QuoteConsumed();
        bytes32 hash = quoteDigest(q);
        if (!hasRole(QUOTE_SIGNER_ROLE, ECDSA.recover(hash, auth.signature))) revert E.InvalidSignature();
        if (referenceSource.submit(auth.referenceReport, auth.referenceSignature) != q.referenceHash) revert E.InvalidBinding();
        submitCapacity(auth.capacityReport, auth.capacitySignature);
        usedNonces[user][q.nonce] = true;
        // Exact output stays signed, while backing and fees use the latest
        // accepted reference. Current collateral and spread bounds still apply.
        activeQuote = q; activeDigest = hash; activeReference = referenceSource.price();
        active = true; consumed = false;
    }

    /**
     * @notice Reserve the emergency budget for one redemption.
     * @dev Execution contexts are single-use and cannot replace the vault's accounting guards.
     * @param caller Executor that must match the active quote.
     * @param amount Amount in the token units of the selected operation.
     * @custom:security Validates domain-specific permissions and configured risk bounds.
     * @custom:validation Enforces the checks described for this operation; invalid authorization reverts.
     * @custom:state-changes Decrements the emergency budget and initializes one redemption context.
     * @custom:events Underlying operation and token events when applicable.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy Vault-only settlement and active-context checks constrain callbacks.
     * @custom:access Configured vault only.
     * @custom:oracle Signed reference and reconciled capacity for normal conversion; separate emergency policy.
     */
    function prepareEmergency(address caller, uint256 amount) external onlyVault {
        if (active) revert E.ActiveSettlement();
        if (mode != T.Mode.EmergencyRedeem || amount == 0 || amount > emergencyBudget) revert E.InvalidMode();
        active = true; consumed = false; emergencySettlement = true;
        activeQuote.user = caller; activeQuote.caller = caller; activeQuote.action = T.Action.Redeem; activeQuote.amountIn = amount;
        emergencyBudget -= amount;
    }

    /**
     * @notice Require the active settlement to belong to the specified executor.
     * @dev Returns the declared configuration or derived value without updating state.
     * @param caller Executor that must match the active quote.
     * @custom:security Read-only; does not authorize settlement.
     * @custom:validation Uses the declared input types; target interface calls may revert.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors Propagates invalid input or target read failures.
     * @custom:reentrancy Read-only.
     * @custom:access Public.
     * @custom:oracle No fresh observation is created; reference getters expose existing source data.
     */
    function requireContext(address caller) external view onlyVault { if (!active || activeQuote.caller != caller) revert E.QuoteRequired(); }

    /**
     * @notice Close a consumed settlement or a permitted zero-yield harvest.
     * @dev Execution contexts are single-use and cannot replace the vault's accounting guards.
     * @param allowNoConversion Whether an authorized zero-yield harvest may finish without minting.
     * @custom:security Validates domain-specific permissions and configured risk bounds.
     * @custom:validation Enforces the checks described for this operation; invalid authorization reverts.
     * @custom:state-changes Clears the active settlement context.
     * @custom:events Underlying operation and token events when applicable.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy Vault-only settlement and active-context checks constrain callbacks.
     * @custom:access Configured vault only.
     * @custom:oracle Signed reference and reconciled capacity for normal conversion; separate emergency policy.
     */
    function finish(bool allowNoConversion) external onlyVault {
        if (!active || (!consumed && !allowNoConversion)) revert E.QuoteRequired();
        if (!consumed && activeQuote.action != T.Action.Yield) revert E.QuoteRequired();
        // A zero-yield operation still consumes its nonce. Give reconciliation
        // canonical settlement evidence so its reserved capacity can be released.
        if (!consumed) emit QuoteSettled(activeDigest, activeQuote.caller, activeQuote.action, 0, 0);
        delete activeQuote; active = false; consumed = false; emergencySettlement = false;
        activeReference = 0; activeDigest = bytes32(0);
    }

    /**
     * @notice Consume the exact mint or bounded yield authorization and admit its hedge exposure.
     * @dev Execution contexts are single-use and cannot replace the vault's accounting guards.
     * @param netUsdc USDC available for conversion after protocol fees.
     * @param referencePrice Validated EUR/USD reference in 1e18 precision.
     * @return q Authorized QEURO output in eighteen-decimal units.
     * @return backing Reference-valued backing in six-decimal USDC units.
     * @custom:security Validates domain-specific permissions and configured risk bounds.
     * @custom:validation Enforces the checks described for this operation; invalid authorization reverts.
     * @custom:state-changes Increments admitted buy exposure and marks the quote consumed.
     * @custom:events QuoteSettled.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy Vault-only settlement and active-context checks constrain callbacks.
     * @custom:access Configured vault only.
     * @custom:oracle Signed reference and reconciled capacity for normal conversion; separate emergency policy.
     */
    function consumeMint(uint256 netUsdc, uint256 referencePrice) external override onlyVault returns (uint256 q, uint256 backing) {
        _checkContext(referencePrice);
        T.Quote memory quote = activeQuote;
        if (quote.action == T.Action.Mint) {
            uint256 fee = Math.mulDiv(quote.amountIn, ISignedExecutionVault(vault).mintFee(), 1e18);
            if (netUsdc != quote.amountIn - fee) revert E.InvalidAmount();
            q = quote.amountOut;
        } else if (quote.action == T.Action.Yield) {
            if (netUsdc > quote.amountIn) revert E.InvalidAmount();
            q = Math.mulDiv(netUsdc, quote.amountOut, quote.amountIn);
        } else revert E.InvalidBinding();
        if (q == 0 || netUsdc == 0) revert E.InvalidAmount();
        backing = Math.mulDiv(q, referencePrice, 1e30);
        if (backing == 0 || backing > netUsdc || Math.mulDiv(netUsdc, 1e30, q, Math.Rounding.Ceil) > Math.mulDiv(referencePrice, 10_000 + maxImpactBps, 10_000)) revert E.ExcessiveImpact();
        _admit(q, true); consumed = true;
        emit QuoteSettled(activeDigest, quote.caller, quote.action, quote.action == T.Action.Yield ? netUsdc : quote.amountIn, q);
    }

    /**
     * @notice Consume a redemption authorization while enforcing reference fees and spread limits.
     * @dev Execution contexts are single-use and cannot replace the vault's accounting guards.
     * @param qeuroIn QEURO input in eighteen-decimal units.
     * @param referencePrice Validated EUR/USD reference in 1e18 precision.
     * @return executionUsdc Execution-valued USDC before protocol redemption fees.
     * @custom:security Validates domain-specific permissions and configured risk bounds.
     * @custom:validation Enforces the checks described for this operation; invalid authorization reverts.
     * @custom:state-changes Increments admitted sell exposure and marks the quote consumed.
     * @custom:events QuoteSettled.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy Vault-only settlement and active-context checks constrain callbacks.
     * @custom:access Configured vault only.
     * @custom:oracle Signed reference and reconciled capacity for normal conversion; separate emergency policy.
     */
    function consumeRedeem(uint256 qeuroIn, uint256 referencePrice) external override onlyVault returns (uint256 executionUsdc) {
        _checkContext(referencePrice);
        T.Quote memory quote = activeQuote;
        if (quote.action != T.Action.Redeem || qeuroIn != quote.amountIn) revert E.InvalidBinding();
        uint256 backing = Math.mulDiv(qeuroIn, referencePrice, 1e30);
        uint256 fee = Math.mulDiv(backing, ISignedExecutionVault(vault).redemptionFee(), 1e18);
        if (emergencySettlement) executionUsdc = Math.mulDiv(backing, 10_000 - degradedHaircutBps, 10_000);
        else {
            executionUsdc = quote.amountOut + fee;
            if (executionUsdc > backing || executionUsdc < Math.mulDiv(backing, 10_000 - maxImpactBps, 10_000)) revert E.ExcessiveImpact();
        }
        if (executionUsdc <= fee) revert E.InvalidAmount();
        _admit(qeuroIn, false); consumed = true;
        emit QuoteSettled(activeDigest, quote.caller, quote.action, qeuroIn, executionUsdc - fee);
    }

    /**
     * @notice Account for the admitted sell exposure of a budgeted liquidation redemption.
     * @dev Execution contexts are single-use and cannot replace the vault's accounting guards.
     * @param qeuroIn QEURO input in eighteen-decimal units.
     * @custom:security Validates domain-specific permissions and configured risk bounds.
     * @custom:validation Enforces the checks described for this operation; invalid authorization reverts.
     * @custom:state-changes Increments admitted sell exposure and marks the emergency conversion consumed.
     * @custom:events Underlying operation and token events when applicable.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy Vault-only settlement and active-context checks constrain callbacks.
     * @custom:access Configured vault only.
     * @custom:oracle Signed reference and reconciled capacity for normal conversion; separate emergency policy.
     */
    function consumeLiquidation(uint256 qeuroIn) external onlyVault {
        if (!active || consumed || !emergencySettlement || qeuroIn != activeQuote.amountIn) revert E.InvalidMode();
        admittedSell += qeuroIn; consumed = true;
    }

    /**
     * @notice Change operating mode and invalidate outstanding execution authorizations.
     * @dev Execution contexts are single-use and cannot replace the vault's accounting guards.
     * @param next Requested operating mode.
     * @custom:security Validates domain-specific permissions and configured risk bounds.
     * @custom:validation Enforces the checks described for this operation; invalid authorization reverts.
     * @custom:state-changes Updates mode and epoch, invalidates capacity freshness and selects reference mode.
     * @custom:events ModeChanged and reference-mode events when changed.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy Vault-only settlement and active-context checks constrain callbacks.
     * @custom:access Admin to enable Signed mode; admin or emergency role to stop normal execution.
     * @custom:oracle Signed reference and reconciled capacity for normal conversion; separate emergency policy.
     */
    function setMode(T.Mode next) external {
        if (active) revert E.ActiveSettlement();
        if (next == T.Mode.Signed) _checkRole(DEFAULT_ADMIN_ROLE);
        else if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) _checkRole(EMERGENCY_ROLE);
        if (next == mode) return;
        mode = next; ++epoch; capacityObservedAt = 0; capacityHash = bytes32(0);
        referenceSource.setEmergency(next == T.Mode.EmergencyRedeem);
        emit ModeChanged(next, epoch);
    }

    /**
     * @notice Set an emergency budget only while paused and with no unacknowledged exposure.
     * @dev Execution contexts are single-use and cannot replace the vault's accounting guards.
     * @param budget Maximum emergency QEURO redemption amount in eighteen-decimal units.
     * @custom:security Validates domain-specific permissions and configured risk bounds.
     * @custom:validation Enforces the checks described for this operation; invalid authorization reverts.
     * @custom:state-changes Replaces the explicitly configured emergency budget.
     * @custom:events EmergencyBudgetConfigured.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy Vault-only settlement and active-context checks constrain callbacks.
     * @custom:access Default admin only.
     * @custom:oracle Signed reference and reconciled capacity for normal conversion; separate emergency policy.
     */
    function configureEmergencyBudget(uint256 budget) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (active || !ISignedExecutionVault(vault).paused() || outstanding() != 0 || budget > maxOutstanding) revert E.CapacityExceeded();
        emergencyBudget = budget; emit EmergencyBudgetConfigured(budget);
    }

    /**
     * @notice Transfer execution spread to the immutable reserve recipient.
     * @dev Execution contexts are single-use and cannot replace the vault's accounting guards.
     * @param amount Amount in the token units of the selected operation.
     * @custom:security Validates domain-specific permissions and configured risk bounds.
     * @custom:validation Enforces the checks described for this operation; invalid authorization reverts.
     * @custom:state-changes Transfers module-held USDC to the configured recipient.
     * @custom:events Underlying operation and token events when applicable.
     * @custom:errors Reverts on invalid inputs, permissions or failed downstream calls.
     * @custom:reentrancy Vault-only settlement and active-context checks constrain callbacks.
     * @custom:access Default admin only.
     * @custom:oracle Signed reference and reconciled capacity for normal conversion; separate emergency policy.
     */
    function withdrawReserve(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(ISignedExecutionVault(vault).usdc()).safeTransfer(reserveRecipient, amount);
    }

    function _checkContext(uint256 referencePrice) private view {
        if (!active || consumed) revert E.QuoteRequired();
        if (!emergencySettlement && (mode != T.Mode.Signed || activeQuote.epoch != epoch || referencePrice != activeReference)) revert E.InvalidBinding();
    }

    function _admit(uint256 quantity, bool buy) private {
        if (!emergencySettlement) {
            if (capacityObservedAt == 0 || block.timestamp - capacityObservedAt > maxAge || outstanding() + quantity > Math.min(maxOutstanding, marginCapacity)) revert E.CapacityExceeded();
        }
        if (buy) admittedBuy += quantity; else admittedSell += quantity;
    }

    function _validateSelector(bytes4 selector, T.Action action) private pure {
        bool valid;
        if (action == T.Action.Mint) valid = selector == bytes4(keccak256("deposit(uint256[],uint256[])")) || selector == bytes4(keccak256("mintQEURO(uint256,uint256)")) || selector == bytes4(keccak256("mintQEUROToVault(uint256,uint256,uint256)")) || selector == bytes4(keccak256("mintAndStakeQEURO(uint256,uint256,uint256,uint256)"));
        else if (action == T.Action.Redeem) valid = selector == bytes4(keccak256("withdraw(uint256[],uint256[])")) || selector == bytes4(keccak256("redeemQEURO(uint256,uint256)"));
        else valid = selector == bytes4(keccak256("harvestAndDistributeVaultYield(uint256)")) || selector == bytes4(keccak256("creditVaultYield(uint256,uint256)"));
        if (!valid) revert E.InvalidBinding();
    }
}
