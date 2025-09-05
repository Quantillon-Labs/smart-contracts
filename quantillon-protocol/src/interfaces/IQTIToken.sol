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
     * @dev Sets up initial roles and configuration for the governance token
     * @param admin Admin address
     * @param _treasury Treasury address
     * @param timelock Timelock address
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function initialize(address admin, address _treasury, address timelock) external;

    /**
     * @notice Lock QTI tokens for voting power
     * @dev Locks QTI tokens for a specified duration to receive voting power
     * @param amount Amount of QTI to lock (18 decimals)
     * @param lockTime Duration to lock (seconds)
     * @return veQTI Voting power received (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function lock(uint256 amount, uint256 lockTime) external returns (uint256 veQTI);

    /**
     * @notice Unlock QTI tokens after lock period expires
     * @dev Unlocks all expired QTI tokens and returns them to the caller
     * @return amount Amount of QTI unlocked (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function unlock() external returns (uint256 amount);

    /**
     * @notice Batch lock QTI tokens for voting power
     * @dev Locks multiple amounts of QTI tokens with different lock durations
     * @param amounts Array of amounts to lock (18 decimals each)
     * @param lockTimes Array of corresponding lock durations (seconds each)
     * @return veQTIAmounts Array of voting power received per lock (18 decimals each)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function batchLock(uint256[] calldata amounts, uint256[] calldata lockTimes) external returns (uint256[] memory veQTIAmounts);

    /**
     * @notice Batch unlock QTI tokens for multiple users (admin/governance)
     * @dev Unlocks expired QTI tokens for multiple users in a single transaction
     * @param users Array of user addresses to unlock for
     * @return amounts Array of amounts unlocked per user (18 decimals each)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function batchUnlock(address[] calldata users) external returns (uint256[] memory amounts);

    /**
     * @notice Get voting power for an address
     * @dev Returns the current voting power for a user based on their locked tokens
     * @param user User address
     * @return votingPower Current voting power (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function getVotingPower(address user) external view returns (uint256 votingPower);

    /**
     * @notice Update voting power for the caller based on current time
     * @dev Recalculates and updates voting power based on time decay
     * @return newVotingPower Updated voting power (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function updateVotingPower() external returns (uint256 newVotingPower);

    /**
     * @notice Get lock info for an address
     * @dev Returns comprehensive lock information for a user
     * @param user User address
     * @return amount Locked amount (18 decimals)
     * @return unlockTime Unlock timestamp
     * @return votingPower Current voting power (18 decimals)
     * @return lastClaimTime Last claim time
     * @return initialVotingPower Initial voting power when locked (18 decimals)
     * @return lockTime Original lock duration (seconds)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
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
     * @dev Creates a new governance proposal with specified parameters
     * @param description Proposal description
     * @param votingPeriod Voting period in seconds
     * @param data Execution data
     * @return proposalId New proposal ID
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function createProposal(
        string calldata description,
        uint256 votingPeriod,
        bytes calldata data
    ) external returns (uint256 proposalId);

    /**
     * @notice Vote on a proposal
     * @dev Casts a vote on a governance proposal
     * @param proposalId Proposal ID
     * @param support True for yes, false for no
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function vote(uint256 proposalId, bool support) external;

    /**
     * @notice Batch vote on multiple proposals
     * @dev Casts votes on multiple governance proposals in a single transaction
     * @param proposalIds Array of proposal IDs
     * @param supportVotes Array of vote choices (true/false)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function batchVote(uint256[] calldata proposalIds, bool[] calldata supportVotes) external;

    /**
     * @notice Execute a successful proposal
     * @dev Executes a proposal that has passed voting requirements
     * @param proposalId Proposal ID
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function executeProposal(uint256 proposalId) external;

    /**
     * @notice Cancel a proposal
     * @dev Cancels a proposal before execution
     * @param proposalId Proposal ID
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function cancelProposal(uint256 proposalId) external;

    /**
     * @notice Get proposal details
     * @dev Returns comprehensive information about a governance proposal
     * @param proposalId Proposal ID
     * @return proposer Proposal creator
     * @return startTime Voting start time
     * @return endTime Voting end time
     * @return forVotes Votes in favor (18 decimals)
     * @return againstVotes Votes against (18 decimals)
     * @return executed Whether executed
     * @return canceled Whether canceled
     * @return description Proposal description
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
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
     * @dev Returns voting information for a specific user and proposal
     * @param proposalId Proposal ID
     * @param voter Voter address
     * @return hasVoted Whether user voted
     * @return support Vote direction
     * @return votes Number of votes cast (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function getReceipt(uint256 proposalId, address voter) external view returns (
        bool hasVoted,
        bool support,
        uint256 votes
    );

    /**
     * @notice Update governance parameters
     * @dev Updates key governance parameters for the protocol
     * @param _proposalThreshold New proposal threshold (18 decimals)
     * @param _minVotingPeriod New minimum voting period (seconds)
     * @param _quorumVotes New quorum requirement (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function updateGovernanceParameters(
        uint256 _proposalThreshold,
        uint256 _minVotingPeriod,
        uint256 _quorumVotes
    ) external;

    /**
     * @notice Update treasury address
     * @dev Updates the treasury address for protocol fees and rewards
     * @param _treasury New treasury address
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function updateTreasury(address _treasury) external;

    /**
     * @notice Update decentralization level
     * @dev Updates the decentralization level based on current protocol state
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function updateDecentralizationLevel() external;

    /**
     * @notice Pause the contract
     * @dev Pauses all contract operations for emergency situations
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function pause() external;

    /**
     * @notice Unpause the contract
     * @dev Resumes all contract operations after emergency pause
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function unpause() external;

    /**
     * @notice Get governance information
     * @dev Returns comprehensive governance information in a single call
     * @return _totalLocked Total locked QTI (18 decimals)
     * @return _totalVotingPower Total voting power (18 decimals)
     * @return _proposalThreshold Proposal threshold (18 decimals)
     * @return _quorumVotes Quorum requirement (18 decimals)
     * @return _currentDecentralizationLevel Current decentralization level
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function getGovernanceInfo() external view returns (
        uint256 _totalLocked,
        uint256 _totalVotingPower,
        uint256 _proposalThreshold,
        uint256 _quorumVotes,
        uint256 _currentDecentralizationLevel
    );

    // ERC20 functions
    /**
     * @notice Get the token name
     * @dev Returns the name of the QTI token
     * @return name The token name string
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function name() external view returns (string memory);

    /**
     * @notice Get the token symbol
     * @dev Returns the symbol of the QTI token
     * @return symbol The token symbol string
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function symbol() external view returns (string memory);

    /**
     * @notice Get the token decimals
     * @dev Returns the number of decimals used by the token
     * @return decimals The number of decimals (always 18)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function decimals() external view returns (uint8);

    /**
     * @notice Get the total token supply
     * @dev Returns the total supply of QTI tokens
     * @return totalSupply The total supply (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice Get the balance of an account
     * @dev Returns the token balance of the specified account
     * @param account Address to query
     * @return balance The token balance (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function balanceOf(address account) external view returns (uint256);
    
    // Additional ERC20 functions
    /**
     * @notice Transfer QTI tokens to another address
     * @dev Standard ERC20 transfer function
     * @param to Address to transfer tokens to
     * @param amount Amount of tokens to transfer (18 decimals)
     * @return success True if transfer was successful
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @notice Get the allowance for a spender
     * @dev Returns the amount of tokens that a spender is allowed to transfer
     * @param owner Address of the token owner
     * @param spender Address of the spender
     * @return allowance Amount of tokens the spender can transfer (18 decimals)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @notice Approve a spender to transfer tokens
     * @dev Sets the allowance for a spender to transfer tokens on behalf of the caller
     * @param spender Address of the spender to approve
     * @param amount Amount of tokens to approve (18 decimals)
     * @return success True if approval was successful
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @notice Transfer tokens from one address to another
     * @dev Standard ERC20 transferFrom function
     * @param from Address to transfer tokens from
     * @param to Address to transfer tokens to
     * @param amount Amount of tokens to transfer (18 decimals)
     * @return success True if transfer was successful
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
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
