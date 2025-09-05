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
    
    /**
     * @notice Check if an account has a specific role
     * @dev Returns true if the account has the specified role
     * @param role The role to check
     * @param account The account to check
     * @return bool True if account has the role, false otherwise
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can check roles
     * @custom:oracle No oracle dependencies
     */
    function hasRole(bytes32 role, address account) external view returns (bool);
    
    /**
     * @notice Get the admin role for a specific role
     * @dev Returns the admin role that can grant/revoke the specified role
     * @param role The role to get admin for
     * @return bytes32 The admin role
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query role admin
     * @custom:oracle No oracle dependencies
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    
    /**
     * @notice Grant a role to an account
     * @dev Grants the specified role to the account
     * @param role The role to grant
     * @param account The account to grant the role to
     * @custom:security Validates caller has admin role for the specified role
     * @custom:validation Validates account is not address(0)
     * @custom:state-changes Grants role to account
     * @custom:events Emits RoleGranted event
     * @custom:errors Throws AccessControlUnauthorizedAccount if caller lacks admin role
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to role admin
     * @custom:oracle No oracle dependencies
     */
    function grantRole(bytes32 role, address account) external;
    
    /**
     * @notice Revoke a role from an account
     * @dev Revokes the specified role from the account
     * @param role The role to revoke
     * @param account The account to revoke the role from
     * @custom:security Validates caller has admin role for the specified role
     * @custom:validation Validates account is not address(0)
     * @custom:state-changes Revokes role from account
     * @custom:events Emits RoleRevoked event
     * @custom:errors Throws AccessControlUnauthorizedAccount if caller lacks admin role
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to role admin
     * @custom:oracle No oracle dependencies
     */
    function revokeRole(bytes32 role, address account) external;
    
    /**
     * @notice Renounce a role
     * @dev Allows an account to renounce their own role
     * @param role The role to renounce
     * @param callerConfirmation The caller's address for confirmation
     * @custom:security Validates caller is renouncing their own role
     * @custom:validation Validates callerConfirmation matches msg.sender
     * @custom:state-changes Revokes role from caller
     * @custom:events Emits RoleRevoked event
     * @custom:errors Throws AccessControlBadConfirmation if callerConfirmation != msg.sender
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Public - anyone can renounce their own roles
     * @custom:oracle No oracle dependencies
     */
    function renounceRole(bytes32 role, address callerConfirmation) external;
    
    // Pausable functions
    
    /**
     * @notice Check if the contract is paused
     * @dev Returns true if the contract is currently paused
     * @return bool True if paused, false if not paused
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can check pause status
     * @custom:oracle No oracle dependencies
     */
    function paused() external view returns (bool);
    
    // UUPS functions
    
    /**
     * @notice Upgrade the contract implementation
     * @dev Upgrades the contract to a new implementation
     * @param newImplementation Address of the new implementation
     * @custom:security Validates caller has UPGRADER_ROLE
     * @custom:validation Validates newImplementation is not address(0)
     * @custom:state-changes Updates implementation address
     * @custom:events Emits Upgraded event
     * @custom:errors Throws AccessControlUnauthorizedAccount if caller lacks UPGRADER_ROLE
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to UPGRADER_ROLE
     * @custom:oracle No oracle dependencies
     */
    function upgradeTo(address newImplementation) external;
    
    /**
     * @notice Upgrade the contract implementation with initialization
     * @dev Upgrades the contract to a new implementation and calls initialization function
     * @param newImplementation Address of the new implementation
     * @param data Initialization data to call on new implementation
     * @custom:security Validates caller has UPGRADER_ROLE
     * @custom:validation Validates newImplementation is not address(0)
     * @custom:state-changes Updates implementation address and calls initialization
     * @custom:events Emits Upgraded event
     * @custom:errors Throws AccessControlUnauthorizedAccount if caller lacks UPGRADER_ROLE
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to UPGRADER_ROLE
     * @custom:oracle No oracle dependencies
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
    
    // Constants
    
    /**
     * @notice Returns the governance role identifier
     * @dev Role required for governance operations
     * @return bytes32 The governance role identifier
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query governance role
     * @custom:oracle No oracle dependencies
     */
    function GOVERNANCE_ROLE() external view returns (bytes32);
    
    /**
     * @notice Returns the emergency role identifier
     * @dev Role required for emergency operations
     * @return bytes32 The emergency role identifier
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query emergency role
     * @custom:oracle No oracle dependencies
     */
    function EMERGENCY_ROLE() external view returns (bytes32);
    
    /**
     * @notice Returns the upgrader role identifier
     * @dev Role required for contract upgrades
     * @return bytes32 The upgrader role identifier
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query upgrader role
     * @custom:oracle No oracle dependencies
     */
    function UPGRADER_ROLE() external view returns (bytes32);
    
    /**
     * @notice Returns the maximum lock time
     * @dev Maximum duration tokens can be locked for (seconds)
     * @return uint256 Maximum lock time in seconds
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query maximum lock time
     * @custom:oracle No oracle dependencies
     */
    function MAX_LOCK_TIME() external view returns (uint256);
    
    /**
     * @notice Returns the minimum lock time
     * @dev Minimum duration tokens must be locked for (seconds)
     * @return uint256 Minimum lock time in seconds
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query minimum lock time
     * @custom:oracle No oracle dependencies
     */
    function MIN_LOCK_TIME() external view returns (uint256);
    
    /**
     * @notice Returns the week duration
     * @dev Duration of one week in seconds
     * @return uint256 Week duration in seconds
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query week duration
     * @custom:oracle No oracle dependencies
     */
    function WEEK() external view returns (uint256);
    
    /**
     * @notice Returns the maximum veQTI multiplier
     * @dev Maximum voting power multiplier for locked tokens
     * @return uint256 Maximum veQTI multiplier
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query maximum veQTI multiplier
     * @custom:oracle No oracle dependencies
     */
    function MAX_VE_QTI_MULTIPLIER() external view returns (uint256);
    
    /**
     * @notice Returns the maximum time elapsed
     * @dev Maximum time that can elapse for calculations
     * @return uint256 Maximum time elapsed in seconds
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query maximum time elapsed
     * @custom:oracle No oracle dependencies
     */
    function MAX_TIME_ELAPSED() external view returns (uint256);
    
    /**
     * @notice Returns the total supply cap
     * @dev Maximum total supply of QTI tokens (18 decimals)
     * @return uint256 Total supply cap in QTI tokens
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query total supply cap
     * @custom:oracle No oracle dependencies
     */
    function TOTAL_SUPPLY_CAP() external view returns (uint256);
    
    // State variables
    
    /**
     * @notice Returns lock information for an address
     * @dev Returns comprehensive lock information for a user
     * @param user Address of the user to query
     * @return amount Locked amount (18 decimals)
     * @return unlockTime Unlock timestamp
     * @return votingPower Current voting power (18 decimals)
     * @return lastClaimTime Last claim time
     * @return initialVotingPower Initial voting power when locked (18 decimals)
     * @return lockTime Original lock duration (seconds)
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query lock information
     * @custom:oracle No oracle dependencies
     */
    function locks(address user) external view returns (
        uint256 amount,
        uint256 unlockTime,
        uint256 votingPower,
        uint256 lastClaimTime,
        uint256 initialVotingPower,
        uint256 lockTime
    );
    
    /**
     * @notice Returns total locked QTI tokens
     * @dev Total amount of QTI tokens locked across all users (18 decimals)
     * @return uint256 Total locked QTI tokens
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query total locked
     * @custom:oracle No oracle dependencies
     */
    function totalLocked() external view returns (uint256);
    
    /**
     * @notice Returns total voting power
     * @dev Total voting power across all locked tokens (18 decimals)
     * @return uint256 Total voting power
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query total voting power
     * @custom:oracle No oracle dependencies
     */
    function totalVotingPower() external view returns (uint256);
    
    /**
     * @notice Returns proposal information by ID
     * @dev Returns comprehensive proposal information
     * @param proposalId ID of the proposal to query
     * @return proposer Proposal creator address
     * @return startTime Voting start timestamp
     * @return endTime Voting end timestamp
     * @return forVotes Votes in favor (18 decimals)
     * @return againstVotes Votes against (18 decimals)
     * @return executed Whether proposal was executed
     * @return canceled Whether proposal was canceled
     * @return description Proposal description
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query proposal information
     * @custom:oracle No oracle dependencies
     */
    function proposals(uint256 proposalId) external view returns (
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
     * @notice Returns the next proposal ID
     * @dev Counter for generating unique proposal IDs
     * @return uint256 Next proposal ID
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query next proposal ID
     * @custom:oracle No oracle dependencies
     */
    function nextProposalId() external view returns (uint256);
    
    /**
     * @notice Returns the proposal threshold
     * @dev Minimum voting power required to create proposals (18 decimals)
     * @return uint256 Proposal threshold in QTI tokens
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query proposal threshold
     * @custom:oracle No oracle dependencies
     */
    function proposalThreshold() external view returns (uint256);
    
    /**
     * @notice Returns the minimum voting period
     * @dev Minimum duration for proposal voting (seconds)
     * @return uint256 Minimum voting period in seconds
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query minimum voting period
     * @custom:oracle No oracle dependencies
     */
    function minVotingPeriod() external view returns (uint256);
    
    /**
     * @notice Returns the maximum voting period
     * @dev Maximum duration for proposal voting (seconds)
     * @return uint256 Maximum voting period in seconds
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query maximum voting period
     * @custom:oracle No oracle dependencies
     */
    function maxVotingPeriod() external view returns (uint256);
    
    /**
     * @notice Returns the quorum votes requirement
     * @dev Minimum votes required for proposal execution (18 decimals)
     * @return uint256 Quorum votes requirement in QTI tokens
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query quorum votes
     * @custom:oracle No oracle dependencies
     */
    function quorumVotes() external view returns (uint256);
    
    /**
     * @notice Returns the treasury address
     * @dev Address where protocol fees and rewards are sent
     * @return address Treasury address
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query treasury address
     * @custom:oracle No oracle dependencies
     */
    function treasury() external view returns (address);
    
    /**
     * @notice Returns the decentralization start time
     * @dev Timestamp when decentralization process began
     * @return uint256 Decentralization start timestamp
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query decentralization start time
     * @custom:oracle No oracle dependencies
     */
    function decentralizationStartTime() external view returns (uint256);
    
    /**
     * @notice Returns the decentralization duration
     * @dev Duration of the decentralization process (seconds)
     * @return uint256 Decentralization duration in seconds
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query decentralization duration
     * @custom:oracle No oracle dependencies
     */
    function decentralizationDuration() external view returns (uint256);
    
    /**
     * @notice Returns the current decentralization level
     * @dev Current level of protocol decentralization (0-100)
     * @return uint256 Current decentralization level
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query current decentralization level
     * @custom:oracle No oracle dependencies
     */
    function currentDecentralizationLevel() external view returns (uint256);

    // Recovery functions
    
    /**
     * @notice Recovers tokens accidentally sent to the contract
     * @dev Emergency function to recover ERC20 tokens that are not part of normal operations
     * @param token Address of the token to recover
     * @param to Address to send recovered tokens to
     * @param amount Amount of tokens to recover
     * @custom:security Validates admin role and uses secure recovery library
     * @custom:validation No input validation required - library handles validation
     * @custom:state-changes Transfers tokens from contract to specified address
     * @custom:events Emits TokenRecovered event
     * @custom:errors No errors thrown - library handles error cases
     * @custom:reentrancy Not protected - library handles reentrancy
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependencies for token recovery
     */
    function recoverToken(address token, address to, uint256 amount) external;
    
    /**
     * @notice Recovers ETH accidentally sent to the contract
     * @dev Emergency function to recover ETH that was accidentally sent to the contract
     * @custom:security Validates admin role and emits recovery event
     * @custom:validation No input validation required - transfers all ETH
     * @custom:state-changes Transfers all contract ETH balance to treasury
     * @custom:events Emits ETHRecovered with amount and treasury address
     * @custom:errors No errors thrown - safe ETH transfer
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to DEFAULT_ADMIN_ROLE
     * @custom:oracle No oracle dependencies
     */
    function recoverETH() external;
}
