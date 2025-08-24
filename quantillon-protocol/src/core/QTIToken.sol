// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title QTIToken
 * @notice Governance token for Quantillon Protocol with vote-escrow mechanics
 * @dev Implements progressive decentralization and governance features
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract QTIToken is 
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    // =============================================================================
    // CONSTANTS AND ROLES
    // =============================================================================
    
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Vote-escrow constants
    uint256 public constant MAX_LOCK_TIME = 4 * 365 days; // 4 years max lock
    uint256 public constant MIN_LOCK_TIME = 7 days; // 1 week minimum lock
    uint256 public constant WEEK = 7 days;
    uint256 public constant MAX_VE_QTI_MULTIPLIER = 4; // 4x max voting power

    // =============================================================================
    // STATE VARIABLES
    // =============================================================================
    
    /// @notice Total supply cap (100 million QTI)
    uint256 public constant TOTAL_SUPPLY_CAP = 100_000_000 * 1e18;
    
    /// @notice Vote-escrow lock info
    struct LockInfo {
        uint256 amount;           // Locked QTI amount
        uint256 unlockTime;       // When lock expires
        uint256 votingPower;      // Current voting power
        uint256 lastClaimTime;    // Last claim time (for future use)
    }
    
    /// @notice Governance proposal structure
    struct Proposal {
        address proposer;         // Who created the proposal
        uint256 startTime;        // When voting starts
        uint256 endTime;          // When voting ends
        uint256 forVotes;         // Votes in favor
        uint256 againstVotes;     // Votes against
        bool executed;            // Whether proposal was executed
        bool canceled;            // Whether proposal was canceled
        string description;       // Proposal description
        bytes data;               // Execution data
        mapping(address => Receipt) receipts; // Voting receipts
    }
    
    /// @notice Voting receipt for each voter
    struct Receipt {
        bool hasVoted;            // Whether user voted
        bool support;             // True for yes, false for no
        uint256 votes;            // Number of votes cast
    }
    
    /// @notice Vote-escrow locks per user
    mapping(address => LockInfo) public locks;
    
    /// @notice Total locked QTI
    uint256 public totalLocked;
    
    /// @notice Total voting power
    uint256 public totalVotingPower;
    
    /// @notice Governance proposals
    mapping(uint256 => Proposal) public proposals;
    
    /// @notice Next proposal ID
    uint256 public nextProposalId;
    
    /// @notice Minimum QTI required to create proposal
    uint256 public proposalThreshold;
    
    /// @notice Minimum voting period
    uint256 public minVotingPeriod;
    
    /// @notice Maximum voting period
    uint256 public maxVotingPeriod;
    
    /// @notice Quorum required for proposal to pass
    uint256 public quorumVotes;
    

    
    /// @notice Treasury address for protocol fees
    address public treasury;
    
    /// @notice Progressive decentralization parameters
    uint256 public decentralizationStartTime;
    uint256 public decentralizationDuration;
    uint256 public currentDecentralizationLevel; // 0-10000 (0-100%)

    // =============================================================================
    // EVENTS
    // =============================================================================
    
    event TokensLocked(address indexed user, uint256 amount, uint256 unlockTime, uint256 votingPower);
    event TokensUnlocked(address indexed user, uint256 amount, uint256 votingPower);
    event VotingPowerUpdated(address indexed user, uint256 oldPower, uint256 newPower);
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 votes);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);

    event GovernanceParametersUpdated(uint256 proposalThreshold, uint256 minVotingPeriod, uint256 quorumVotes);
    event DecentralizationLevelUpdated(uint256 newLevel);

    // =============================================================================
    // INITIALIZER
    // =============================================================================

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin,
        address _treasury
    ) public initializer {
        require(admin != address(0), "QTI: Admin cannot be zero");
        require(_treasury != address(0), "QTI: Treasury cannot be zero");

        __ERC20_init("Quantillon Token", "QTI");
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        treasury = _treasury;
        
        // Initial governance parameters
        proposalThreshold = 100_000 * 1e18; // 100k QTI to propose
        minVotingPeriod = 3 days;
        maxVotingPeriod = 14 days;
        quorumVotes = 1_000_000 * 1e18; // 1M QTI quorum
        

        
        decentralizationStartTime = block.timestamp;
        decentralizationDuration = 2 * 365 days; // 2 years to full decentralization
        currentDecentralizationLevel = 0; // Start with 0% decentralization
    }

    // =============================================================================
    // VOTE-ESCROW FUNCTIONS
    // =============================================================================

    /**
     * @notice Lock QTI tokens for voting power
     * @param amount Amount of QTI to lock
     * @param lockTime Duration to lock (must be >= MIN_LOCK_TIME)
     */
    function lock(uint256 amount, uint256 lockTime) external returns (uint256 veQTI) {
        require(amount > 0, "QTI: Amount must be positive");
        require(lockTime >= MIN_LOCK_TIME, "QTI: Lock time too short");
        require(lockTime <= MAX_LOCK_TIME, "QTI: Lock time too long");
        require(balanceOf(msg.sender) >= amount, "QTI: Insufficient balance");



        LockInfo storage lockInfo = locks[msg.sender];
        uint256 oldVotingPower = lockInfo.votingPower;
        
        // Calculate new unlock time
        uint256 newUnlockTime = block.timestamp + lockTime;
        
        // If already locked, extend the lock time
        if (lockInfo.unlockTime > block.timestamp) {
            newUnlockTime = lockInfo.unlockTime + lockTime;
        }
        
        // Calculate voting power multiplier based on lock time
        uint256 multiplier = _calculateVotingPowerMultiplier(lockTime);
        uint256 newVotingPower = amount * multiplier / 1e18;
        
        // Update lock info
        lockInfo.amount += amount;
        lockInfo.unlockTime = newUnlockTime;
        lockInfo.votingPower = newVotingPower;
        
        // Update global totals
        totalLocked += amount;
        totalVotingPower = totalVotingPower - oldVotingPower + newVotingPower;
        
        // Transfer tokens to this contract
        _transfer(msg.sender, address(this), amount);
        
        veQTI = newVotingPower;
        
        emit TokensLocked(msg.sender, amount, newUnlockTime, newVotingPower);
        emit VotingPowerUpdated(msg.sender, oldVotingPower, newVotingPower);
    }

    /**
     * @notice Unlock QTI tokens after lock period expires
     */
    function unlock() external returns (uint256 amount) {
        LockInfo storage lockInfo = locks[msg.sender];
        require(lockInfo.unlockTime <= block.timestamp, "QTI: Lock not expired");
        require(lockInfo.amount > 0, "QTI: Nothing to unlock");



        amount = lockInfo.amount;
        uint256 oldVotingPower = lockInfo.votingPower;
        
        // Clear lock info
        lockInfo.amount = 0;
        lockInfo.unlockTime = 0;
        lockInfo.votingPower = 0;
        
        // Update global totals
        totalLocked -= amount;
        totalVotingPower -= oldVotingPower;
        
        // Transfer tokens back to user
        _transfer(address(this), msg.sender, amount);
        
        emit TokensUnlocked(msg.sender, amount, oldVotingPower);
        emit VotingPowerUpdated(msg.sender, oldVotingPower, 0);
    }

    /**
     * @notice Get voting power for an address
     */
    function getVotingPower(address user) external view returns (uint256) {
        return locks[user].votingPower;
    }

    /**
     * @notice Get lock info for an address
     */
    function getLockInfo(address user) external view returns (
        uint256 amount,
        uint256 unlockTime,
        uint256 votingPower,
        uint256 lastClaimTime
    ) {
        LockInfo storage lockInfo = locks[user];
        return (
            lockInfo.amount,
            lockInfo.unlockTime,
            lockInfo.votingPower,
            lockInfo.lastClaimTime
        );
    }

    // =============================================================================
    // GOVERNANCE FUNCTIONS
    // =============================================================================

    /**
     * @notice Create a new governance proposal
     * @param description Proposal description
     * @param votingPeriod Voting period in seconds
     * @param data Execution data
     */
    function createProposal(
        string calldata description,
        uint256 votingPeriod,
        bytes calldata data
    ) external returns (uint256 proposalId) {
        require(this.getVotingPower(msg.sender) >= proposalThreshold, "QTI: Insufficient voting power");
        require(votingPeriod >= minVotingPeriod, "QTI: Voting period too short");
        require(votingPeriod <= maxVotingPeriod, "QTI: Voting period too long");

        proposalId = nextProposalId++;
        
        Proposal storage proposal = proposals[proposalId];
        proposal.proposer = msg.sender;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + votingPeriod;
        proposal.description = description;
        proposal.data = data;

        emit ProposalCreated(proposalId, msg.sender, description);
    }

    /**
     * @notice Vote on a proposal
     * @param proposalId Proposal ID
     * @param support True for yes, false for no
     */
    function vote(uint256 proposalId, bool support) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.startTime, "QTI: Voting not started");
        require(block.timestamp < proposal.endTime, "QTI: Voting ended");
        require(!proposal.receipts[msg.sender].hasVoted, "QTI: Already voted");

        uint256 votingPower = this.getVotingPower(msg.sender);
        require(votingPower > 0, "QTI: No voting power");

        proposal.receipts[msg.sender] = Receipt({
            hasVoted: true,
            support: support,
            votes: votingPower
        });

        if (support) {
            proposal.forVotes += votingPower;
        } else {
            proposal.againstVotes += votingPower;
        }

        emit Voted(proposalId, msg.sender, support, votingPower);
    }

    /**
     * @notice Execute a successful proposal
     * @param proposalId Proposal ID
     */
    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.endTime, "QTI: Voting not ended");
        require(!proposal.executed, "QTI: Already executed");
        require(!proposal.canceled, "QTI: Proposal canceled");
        require(proposal.forVotes > proposal.againstVotes, "QTI: Proposal failed");
        require(proposal.forVotes + proposal.againstVotes >= quorumVotes, "QTI: Quorum not met");

        proposal.executed = true;

        // Execute the proposal data
        if (proposal.data.length > 0) {
            (bool success, ) = address(this).call(proposal.data);
            require(success, "QTI: Proposal execution failed");
        }

        emit ProposalExecuted(proposalId);
    }

    /**
     * @notice Cancel a proposal (only proposer or admin)
     * @param proposalId Proposal ID
     */
    function cancelProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == proposal.proposer || hasRole(GOVERNANCE_ROLE, msg.sender),
            "QTI: Not authorized"
        );
        require(!proposal.executed, "QTI: Already executed");
        require(!proposal.canceled, "QTI: Already canceled");

        proposal.canceled = true;
        emit ProposalCanceled(proposalId);
    }

    /**
     * @notice Get proposal details
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
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.proposer,
            proposal.startTime,
            proposal.endTime,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.executed,
            proposal.canceled,
            proposal.description
        );
    }

    /**
     * @notice Get voting receipt for a user
     */
    function getReceipt(uint256 proposalId, address voter) external view returns (
        bool hasVoted,
        bool support,
        uint256 votes
    ) {
        Receipt storage receipt = proposals[proposalId].receipts[voter];
        return (receipt.hasVoted, receipt.support, receipt.votes);
    }



    // =============================================================================
    // GOVERNANCE ADMIN FUNCTIONS
    // =============================================================================

    /**
     * @notice Update governance parameters
     */
    function updateGovernanceParameters(
        uint256 _proposalThreshold,
        uint256 _minVotingPeriod,
        uint256 _quorumVotes
    ) external onlyRole(GOVERNANCE_ROLE) {
        proposalThreshold = _proposalThreshold;
        minVotingPeriod = _minVotingPeriod;
        quorumVotes = _quorumVotes;

        emit GovernanceParametersUpdated(_proposalThreshold, _minVotingPeriod, _quorumVotes);
    }



    /**
     * @notice Update treasury address
     */
    function updateTreasury(address _treasury) external onlyRole(GOVERNANCE_ROLE) {
        require(_treasury != address(0), "QTI: Treasury cannot be zero");
        treasury = _treasury;
    }

    /**
     * @notice Update decentralization level
     */
    function updateDecentralizationLevel() external onlyRole(GOVERNANCE_ROLE) {
        uint256 timeElapsed = block.timestamp - decentralizationStartTime;
        uint256 newLevel = timeElapsed * 10000 / decentralizationDuration;
        
        if (newLevel > 10000) newLevel = 10000;
        
        currentDecentralizationLevel = newLevel;
        emit DecentralizationLevelUpdated(newLevel);
    }

    // =============================================================================
    // INTERNAL FUNCTIONS
    // =============================================================================

    /**
     * @notice Calculate voting power multiplier based on lock time
     */
    function _calculateVotingPowerMultiplier(uint256 lockTime) internal pure returns (uint256) {
        // Linear multiplier from 1x to 4x based on lock time
        // 1x for MIN_LOCK_TIME, 4x for MAX_LOCK_TIME
        uint256 multiplier = 1e18 + (lockTime - MIN_LOCK_TIME) * 3e18 / (MAX_LOCK_TIME - MIN_LOCK_TIME);
        return multiplier > MAX_VE_QTI_MULTIPLIER * 1e18 ? MAX_VE_QTI_MULTIPLIER * 1e18 : multiplier;
    }



    // =============================================================================
    // OVERRIDE FUNCTIONS
    // =============================================================================

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    // =============================================================================
    // EMERGENCY FUNCTIONS
    // =============================================================================

    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }

    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================

    function getGovernanceInfo() external view returns (
        uint256 totalLocked_,
        uint256 totalVotingPower_,
        uint256 proposalThreshold_,
        uint256 quorumVotes_,
        uint256 currentDecentralizationLevel_
    ) {
        return (
            totalLocked,
            totalVotingPower,
            proposalThreshold,
            quorumVotes,
            currentDecentralizationLevel
        );
    }
}
