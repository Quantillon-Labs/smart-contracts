// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {QTIToken} from "../src/core/QTIToken.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @notice Test helper exposing a mint so local QTI balances can be created (QTI is otherwise dormant).
contract QTITestHelper is QTIToken {
    constructor(TimeProvider timeProvider) QTIToken(timeProvider) {}

    function mintForTest(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title QTIVoteEscrowAndProposalExecutionTest
 * @notice Regression tests for QTI vote-escrow top-ups preserving voting power over the full
 *         merged position, and for passed proposals executing their role-gated governance action
 *         only after the post-vote execution timelock.
 */
contract QTIVoteEscrowAndProposalExecutionTest is Test {
    QTITestHelper private qti;

    address private admin = address(0xA11CE);
    address private treasury = address(0xB0B);
    address private timelock = address(0x1234);
    address private user = address(0xCAFE);
    address private voter1 = address(0xD00D);
    address private voter2 = address(0xBEEF);

    function setUp() public {
        vm.warp(1_700_000_000);

        TimeProvider timeProviderImpl = new TimeProvider();
        ERC1967Proxy timeProviderProxy = new ERC1967Proxy(
            address(timeProviderImpl),
            abi.encodeWithSelector(TimeProvider.initialize.selector, admin, admin, admin)
        );
        TimeProvider timeProvider = TimeProvider(address(timeProviderProxy));

        QTITestHelper implementation = new QTITestHelper(timeProvider);
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(QTIToken.initialize.selector, admin, treasury, timelock)
        );
        qti = QTITestHelper(address(proxy));
    }

    // ---- vote-escrow top-up voting power ----

    /// @notice A small top-up no longer collapses voting power; it reflects the full merged position.
    function test_TopUpDoesNotCollapseVotingPower() public {
        qti.mintForTest(user, 500_001 ether);

        vm.prank(user);
        qti.lock(500_000 ether, 365 days);
        assertEq(qti.totalVotingPower(), 2_000_000 ether, "max-lock gives 4x voting power");

        vm.prank(user);
        qti.lock(1 ether, 7 days);

        (uint256 lockedAmountAfter,, uint256 votingPowerAfter,, uint256 initialPowerAfter,) = qti.getLockInfo(user);

        assertEq(lockedAmountAfter, 500_001 ether, "full merged amount remains locked");
        // The whole merged position keeps (here gains, via the extended lock) its voting weight,
        // rather than collapsing to the ~1 veQTI of the top-up as in the reported bug.
        assertGe(votingPowerAfter, 2_000_000 ether, "Voting power not collapsed by the top-up");
        assertEq(votingPowerAfter, initialPowerAfter, "stored initial/current voting power consistent");
        assertEq(qti.totalVotingPower(), votingPowerAfter, "global total consistent with user voting power");
    }

    /// @notice Same property through the batchLock() path.
    function test_BatchTopUpDoesNotCollapseVotingPower() public {
        qti.mintForTest(user, 500_001 ether);

        vm.prank(user);
        qti.lock(500_000 ether, 365 days);
        assertEq(qti.totalVotingPower(), 2_000_000 ether);

        uint256[] memory amounts = new uint256[](1);
        uint256[] memory lockTimes = new uint256[](1);
        amounts[0] = 1 ether;
        lockTimes[0] = 7 days;

        vm.prank(user);
        qti.batchLock(amounts, lockTimes);

        (uint256 lockedAmountAfter,, uint256 votingPowerAfter,,,) = qti.getLockInfo(user);
        assertEq(lockedAmountAfter, 500_001 ether, "full merged amount remains locked");
        assertGe(votingPowerAfter, 2_000_000 ether, "Batch top-up does not collapse voting power");
        assertEq(qti.totalVotingPower(), votingPowerAfter, "global total consistent");
    }

    // ---- proposal execution + timelock ----

    function _passProposal() private returns (uint256 proposalId) {
        qti.mintForTest(voter1, 1_000_000 ether);
        qti.mintForTest(voter2, 1_000_000 ether);

        bytes memory proposalData = abi.encodeWithSelector(
            QTIToken.updateGovernanceParameters.selector, uint256(1 ether), uint256(3 days), uint256(1 ether)
        );

        vm.prank(voter1);
        qti.lock(500_000 ether, 30 days);
        vm.prank(voter1);
        proposalId = qti.createProposal("Reduce governance threshold and quorum", 5 days, proposalData);
        vm.prank(voter1);
        qti.vote(proposalId, true);

        vm.prank(voter2);
        qti.lock(500_000 ether, 30 days);
        vm.prank(voter2);
        qti.vote(proposalId, true);
    }

    /// @notice A passed proposal can now execute its role-gated governance action after the timelock.
    function test_PassedProposalExecutesRoleGatedAction() public {
        // The token itself must hold GOVERNANCE_ROLE for the self-call to succeed.
        assertTrue(qti.hasRole(qti.GOVERNANCE_ROLE(), address(qti)), "token holds GOVERNANCE_ROLE");

        uint256 proposalId = _passProposal();

        // Past voting end (5d) AND past the 2-day execution delay.
        vm.warp(block.timestamp + 5 days + 2 days + 1);
        qti.executeProposal(proposalId);

        assertEq(qti.proposalThreshold(), 1 ether, "role-gated governance change applied");
        assertEq(qti.minVotingPeriod(), 3 days, "min voting period updated");
        assertEq(qti.quorumVotes(), 1 ether, "quorum updated");
    }

    /// @notice Execution before the post-vote timelock elapses reverts.
    function test_ExecutionBeforeDelayReverts() public {
        uint256 proposalId = _passProposal();

        // Past voting end (5d) but before the 2-day execution delay has elapsed.
        vm.warp(block.timestamp + 5 days + 1);
        vm.expectRevert(CommonErrorLibrary.ExecutionTimeNotReached.selector);
        qti.executeProposal(proposalId);

        assertEq(qti.proposalThreshold(), 100_000 ether, "params unchanged before delay elapses");
    }
}
