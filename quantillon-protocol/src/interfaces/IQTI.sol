// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IQTI
 * @notice Interface for the QTI governance token with vote-escrow mechanics
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
interface IQTI {
    /**
     * @notice Initializes the QTI token
     * @param admin Admin address
     * @param _treasury Treasury address
     */
    function initialize(address admin, address _treasury) external;

    /**
     * @notice Lock QTI tokens for voting power
     * @param amount Amount of QTI to lock
     * @param lockTime Duration to lock
     * @return veQTI Voting power received
     */
    function lock(uint256 amount, uint256 lockTime) external returns (uint256 veQTI);

    /**
     * @notice Unlock QTI tokens after lock period expires
     * @return amount Amount of QTI unlocked
     */
    function unlock() external returns (uint256 amount);

    /**
     * @notice Get voting power for an address
     * @param user User address
     * @return votingPower Current voting power
     */
    function getVotingPower(address user) external view returns (uint256 votingPower);

    /**
     * @notice Update voting power for the caller based on current time
     * @return newVotingPower Updated voting power
     */
    function updateVotingPower() external returns (uint256 newVotingPower);

    /**
     * @notice Get lock info for an address
     * @param user User address
     * @return amount Locked amount
     * @return unlockTime Unlock timestamp
     * @return votingPower Current voting power
     * @return lastClaimTime Last claim time
     * @return initialVotingPower Initial voting power when locked
     * @return lockTime Original lock duration
     */
    function getLockInfo(address user) external view returns (
        uint256 amount,
        uint256 unlockTime,
        uint256 votingPower,
        uint256 lastClaimTime,
        uint256 initialVotingPower,
        uint256 lockTime
    );

    /**
     * @notice Create a new governance proposal
     * @param description Proposal description
     * @param votingPeriod Voting period in seconds
     * @param data Execution data
     * @return proposalId New proposal ID
     */
    function createProposal(
        string calldata description,
        uint256 votingPeriod,
        bytes calldata data
    ) external returns (uint256 proposalId);

    /**
     * @notice Vote on a proposal
     * @param proposalId Proposal ID
     * @param support True for yes, false for no
     */
    function vote(uint256 proposalId, bool support) external;

    /**
     * @notice Execute a successful proposal
     * @param proposalId Proposal ID
     */
    function executeProposal(uint256 proposalId) external;

    /**
     * @notice Cancel a proposal
     * @param proposalId Proposal ID
     */
    function cancelProposal(uint256 proposalId) external;

    /**
     * @notice Get proposal details
     * @param proposalId Proposal ID
     * @return proposer Proposal creator
     * @return startTime Voting start time
     * @return endTime Voting end time
     * @return forVotes Votes in favor
     * @return againstVotes Votes against
     * @return executed Whether executed
     * @return canceled Whether canceled
     * @return description Proposal description
     */
    function getProposal(uint256 proposalId) external view returns (
        address proposer,
        uint256 startTime,
        uint256 endTime,
        uint256 forVotes,
        uint256 againstVotes,
        bool executed,
        bool canceled,
        string memory description
    );

    /**
     * @notice Get voting receipt for a user
     * @param proposalId Proposal ID
     * @param voter Voter address
     * @return hasVoted Whether user voted
     * @return support Vote direction
     * @return votes Number of votes cast
     */
    function getReceipt(uint256 proposalId, address voter) external view returns (
        bool hasVoted,
        bool support,
        uint256 votes
    );

    /**
     * @notice Update governance parameters
     * @param _proposalThreshold New proposal threshold
     * @param _minVotingPeriod New minimum voting period
     * @param _quorumVotes New quorum requirement
     */
    function updateGovernanceParameters(
        uint256 _proposalThreshold,
        uint256 _minVotingPeriod,
        uint256 _quorumVotes
    ) external;

    /**
     * @notice Update treasury address
     * @param _treasury New treasury address
     */
    function updateTreasury(address _treasury) external;

    /**
     * @notice Update decentralization level
     */
    function updateDecentralizationLevel() external;

    /**
     * @notice Pause the contract
     */
    function pause() external;

    /**
     * @notice Unpause the contract
     */
    function unpause() external;

    /**
     * @notice Get governance information
     * @return totalLocked Total locked QTI
     * @return totalVotingPower Total voting power
     * @return proposalThreshold Proposal threshold
     * @return quorumVotes Quorum requirement
     * @return currentDecentralizationLevel Current decentralization level
     */
    function getGovernanceInfo() external view returns (
        uint256 totalLocked,
        uint256 totalVotingPower,
        uint256 proposalThreshold,
        uint256 quorumVotes,
        uint256 currentDecentralizationLevel
    );

    // ERC20 functions
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}
