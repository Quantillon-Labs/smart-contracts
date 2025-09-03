// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IQTIToken
 * @notice Interface for the QTI governance token with vote-escrow mechanics
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
interface IQTIToken {
    /**
     * @notice Initializes the QTI token
     * @param admin Admin address
     * @param _treasury Treasury address
     * @param timelock Timelock address
     */
    function initialize(address admin, address _treasury, address timelock) external;

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
     * @notice Batch lock QTI tokens for voting power
     * @param amounts Array of amounts to lock
     * @param lockTimes Array of corresponding lock durations
     * @return veQTIAmounts Array of voting power received per lock
     */
    function batchLock(uint256[] calldata amounts, uint256[] calldata lockTimes) external returns (uint256[] memory veQTIAmounts);

    /**
     * @notice Batch unlock QTI tokens for multiple users (admin/governance)
     * @param users Array of user addresses to unlock for
     * @return amounts Array of amounts unlocked per user
     */
    function batchUnlock(address[] calldata users) external returns (uint256[] memory amounts);

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
     * @notice Batch vote on multiple proposals
     * @param proposalIds Array of proposal IDs
     * @param supportVotes Array of vote choices (true/false)
     */
    function batchVote(uint256[] calldata proposalIds, bool[] calldata supportVotes) external;

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
     * @return _totalLocked Total locked QTI
     * @return _totalVotingPower Total voting power
     * @return _proposalThreshold Proposal threshold
     * @return _quorumVotes Quorum requirement
     * @return _currentDecentralizationLevel Current decentralization level
     */
    function getGovernanceInfo() external view returns (
        uint256 _totalLocked,
        uint256 _totalVotingPower,
        uint256 _proposalThreshold,
        uint256 _quorumVotes,
        uint256 _currentDecentralizationLevel
    );

    // ERC20 functions
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    
    // Additional ERC20 functions
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    
    // AccessControl functions
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address callerConfirmation) external;
    
    // Pausable functions
    function paused() external view returns (bool);
    
    // UUPS functions
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
    
    // Constants
    function GOVERNANCE_ROLE() external view returns (bytes32);
    function EMERGENCY_ROLE() external view returns (bytes32);
    function UPGRADER_ROLE() external view returns (bytes32);
    function MAX_LOCK_TIME() external view returns (uint256);
    function MIN_LOCK_TIME() external view returns (uint256);
    function WEEK() external view returns (uint256);
    function MAX_VE_QTI_MULTIPLIER() external view returns (uint256);
    function MAX_TIME_ELAPSED() external view returns (uint256);
    function TOTAL_SUPPLY_CAP() external view returns (uint256);
    
    // State variables
    function locks(address) external view returns (
        uint256 amount,
        uint256 unlockTime,
        uint256 votingPower,
        uint256 lastClaimTime,
        uint256 initialVotingPower,
        uint256 lockTime
    );
    function totalLocked() external view returns (uint256);
    function totalVotingPower() external view returns (uint256);
    function proposals(uint256) external view returns (
        address proposer,
        uint256 startTime,
        uint256 endTime,
        uint256 forVotes,
        uint256 againstVotes,
        bool executed,
        bool canceled,
        string memory description
    );
    function nextProposalId() external view returns (uint256);
    function proposalThreshold() external view returns (uint256);
    function minVotingPeriod() external view returns (uint256);
    function maxVotingPeriod() external view returns (uint256);
    function quorumVotes() external view returns (uint256);
    function treasury() external view returns (address);
    function decentralizationStartTime() external view returns (uint256);
    function decentralizationDuration() external view returns (uint256);
    function currentDecentralizationLevel() external view returns (uint256);

    // Recovery functions
    function recoverToken(address token, address to, uint256 amount) external;
    function recoverETH() external;
}
