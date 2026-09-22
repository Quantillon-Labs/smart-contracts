// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {HedgerPool} from "../core/HedgerPool.sol";

/**
 * @title HedgerPoolMigrationLibrary
 * @notice Three-party ownership transfer preserving the live single-hedger position.
 * @dev Linked library operating in the pool's storage through delegatecall. Proposal state
 *      occupies a dedicated hashed namespace; existing HedgerPool slots are unchanged.
 */
library HedgerPoolMigrationLibrary {
    bytes32 private constant STORAGE_SLOT = keccak256("quantillon.storage.HedgerMigration.v1");

    enum Action { Propose, Accept, Execute, Cancel }
    struct Request {
        Action action;
        address newHedger;
        uint64 expiresAt;
        bytes32 proposalId;
    }
    struct Proposal {
        bytes32 id;
        address previousHedger;
        address newHedger;
        uint64 expiresAt;
        uint64 openBlock;
        bool accepted;
    }
    struct State {
        uint256 nonce;
        Proposal proposal;
    }

    error MigrationUnauthorized();
    error InvalidMigration();
    error MigrationExpired();
    error MigrationNotAccepted();
    error RecipientHasHedgerState();
    error MigrationRequiresPause();

    event HedgerMigrationProposed(bytes32 indexed proposalId, address indexed previousHedger, address indexed newHedger, uint64 expiresAt);
    event HedgerMigrationAccepted(bytes32 indexed proposalId);
    event HedgerMigrationCancelled(bytes32 indexed proposalId);
    event HedgerMigrationExecuted(bytes32 indexed proposalId, address indexed previousHedger, address indexed newHedger);
    event SingleHedgerRotationApplied(address indexed previousHedger, address indexed newHedger);

    /**
     * @notice Reports the first release of the migration library.
     * @dev Uses no additional sequential storage slots.
     * @return release Semantic version string.
     * @custom:security Read-only helper.
     * @custom:validation No input validation required unless described above.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None beyond checked arithmetic.
     * @custom:reentrancy No state-changing external calls.
     * @custom:access Linked library helper.
     * @custom:oracle No oracle lookup.
     */
    function version() external pure returns (string memory) { return "1.0.1"; }

    /**
     * @notice Returns the current migration proposal, or an empty proposal after completion/cancellation.
     * @dev Uses no additional sequential storage slots.
     * @return pending Current proposal or a zeroed struct.
     * @custom:security Read-only helper.
     * @custom:validation No input validation required unless described above.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None beyond checked arithmetic.
     * @custom:reentrancy No state-changing external calls.
     * @custom:access Linked library helper.
     * @custom:oracle No oracle lookup.
     */
    function proposal() external view returns (Proposal memory) { return _state().proposal; }

    /**
     * @notice Proposes, accepts, executes or cancels a transfer using the caller's distinct authority.
     * @dev Moves pool rewards and their accrual timestamp; external YieldShift entitlements
     *      remain with their original beneficiary and remain directly claimable at YieldShift.
     * @param request Action and exact proposal fields.
     * @param singleHedger Current configured hedger.
     * @param governance Whether caller holds governance role.
     * @param paused Whether the pool is paused.
     * @param position Active single position storage.
     * @param rewards Per-hedger reward state.
     * @param activePositions Per-hedger active position IDs.
     * @param rewardTimes Per-hedger accrual clocks.
     * @param pendingWithdrawals Per-hedger withdrawal escrow.
     * @return hedger Configured hedger after this action.
     * @custom:security Enforces owner proposal, recipient acceptance and paused governance execution.
     * @custom:validation Binds chain, pool, nonce, parties, expiry and position; rejects dirty recipients.
     * @custom:state-changes Changes proposal state or transfers ownership, rewards, clocks and escrow atomically.
     * @custom:events HedgerMigrationProposed, HedgerMigrationAccepted, HedgerMigrationCancelled, HedgerMigrationExecuted, SingleHedgerRotationApplied.
     * @custom:errors MigrationUnauthorized, InvalidMigration, MigrationExpired, MigrationNotAccepted, RecipientHasHedgerState, MigrationRequiresPause.
     * @custom:reentrancy Called from nonReentrant pool wrapper; no external calls.
     * @custom:access Linked library invoked by HedgerPool through delegatecall.
     * @custom:oracle No oracle lookup; prices, where present, are supplied by the caller.
     */
    function manage(
        Request calldata request,
        address singleHedger,
        bool governance,
        bool paused,
        HedgerPool.HedgePosition storage position,
        mapping(address => HedgerPool.HedgerRewardState) storage rewards,
        mapping(address => uint256) storage activePositions,
        mapping(address => uint256) storage rewardTimes,
        mapping(address => uint256) storage pendingWithdrawals
    ) external returns (address) {
        State storage state = _state();
        if (request.action == Action.Propose) {
            if (msg.sender != singleHedger) revert MigrationUnauthorized();
            if (!position.isActive || position.hedger != singleHedger || activePositions[singleHedger] != 1
                || request.newHedger == singleHedger || request.newHedger.code.length == 0
                || request.expiresAt <= block.timestamp || request.expiresAt > block.timestamp + 7 days
                || request.proposalId != bytes32(0)) revert InvalidMigration();
            bytes32 id = keccak256(abi.encode(block.chainid, address(this), ++state.nonce,
                singleHedger, request.newHedger, request.expiresAt, position.openBlock));
            if (state.proposal.id != bytes32(0)) emit HedgerMigrationCancelled(state.proposal.id);
            state.proposal = Proposal(id, singleHedger, request.newHedger, request.expiresAt, position.openBlock, false);
            emit HedgerMigrationProposed(id, singleHedger, request.newHedger, request.expiresAt);
            return singleHedger;
        }

        Proposal memory p = state.proposal;
        if (p.id == bytes32(0) || p.id != request.proposalId || p.newHedger != request.newHedger
            || p.expiresAt != request.expiresAt) revert InvalidMigration();
        if (request.action == Action.Cancel) {
            if (msg.sender != p.previousHedger && msg.sender != p.newHedger && !governance) revert MigrationUnauthorized();
            delete state.proposal;
            emit HedgerMigrationCancelled(p.id);
            return singleHedger;
        }
        if (block.timestamp > p.expiresAt) revert MigrationExpired();
        if (!position.isActive || singleHedger != p.previousHedger || position.hedger != p.previousHedger
            || position.openBlock != p.openBlock || activePositions[p.previousHedger] != 1) revert InvalidMigration();
        if (request.action == Action.Accept) {
            if (msg.sender != p.newHedger) revert MigrationUnauthorized();
            state.proposal.accepted = true;
            emit HedgerMigrationAccepted(p.id);
            return singleHedger;
        }
        if (!governance) revert MigrationUnauthorized();
        if (!paused) revert MigrationRequiresPause();
        if (!p.accepted) revert MigrationNotAccepted();
        if (activePositions[p.newHedger] != 0 || rewards[p.newHedger].pendingRewards != 0
            || rewards[p.newHedger].lastRewardClaim != 0 || rewardTimes[p.newHedger] != 0
            || pendingWithdrawals[p.newHedger] != 0) revert RecipientHasHedgerState();

        // No arithmetic on exposure, margin, backing or PnL; no external call or token movement.
        position.hedger = p.newHedger;
        activePositions[p.newHedger] = 1;
        delete activePositions[p.previousHedger];
        rewards[p.newHedger] = rewards[p.previousHedger];
        delete rewards[p.previousHedger];
        rewardTimes[p.newHedger] = rewardTimes[p.previousHedger];
        delete rewardTimes[p.previousHedger];
        pendingWithdrawals[p.newHedger] = pendingWithdrawals[p.previousHedger];
        delete pendingWithdrawals[p.previousHedger];
        delete state.proposal;
        emit HedgerMigrationExecuted(p.id, p.previousHedger, p.newHedger);
        emit SingleHedgerRotationApplied(p.previousHedger, p.newHedger);
        return p.newHedger;
    }

    /**
     * @notice Invalidates consent whenever the active position closes, including same-block reopenings.
     * @dev Called by the pool's common position finalization path.
     * @custom:security Revokes prior consent when a position closes.
     * @custom:validation No-op without a pending proposal.
     * @custom:state-changes Deletes the current proposal, preserving the nonce.
     * @custom:events HedgerMigrationCancelled when a proposal existed.
     * @custom:errors None.
     * @custom:reentrancy No external calls.
     * @custom:access Linked library invoked by HedgerPool through delegatecall.
     * @custom:oracle No oracle lookup; prices, where present, are supplied by the caller.
     */
    function invalidate() external {
        State storage state = _state();
        if (state.proposal.id != bytes32(0)) {
            emit HedgerMigrationCancelled(state.proposal.id);
            delete state.proposal;
        }
    }

    /**
     * @notice Returns the dedicated migration storage namespace.
     * @dev Uses no additional sequential storage slots.
     * @return state Namespaced migration state storage pointer.
     * @custom:security Read-only helper.
     * @custom:validation No input validation required unless described above.
     * @custom:state-changes None.
     * @custom:events None.
     * @custom:errors None beyond checked arithmetic.
     * @custom:reentrancy No state-changing external calls.
     * @custom:access Linked library helper.
     * @custom:oracle No oracle lookup.
     */
    function _state() private pure returns (State storage state) {
        bytes32 slot = STORAGE_SLOT;
        assembly ("memory-safe") { state.slot := slot }
    }
}
