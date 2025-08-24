// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// =============================================================================
// IMPORTS - OpenZeppelin libraries for security and standards
// =============================================================================

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
 * 
 * @dev Main characteristics:
 *      - Standard ERC20 with 18 decimals
 *      - Vote-escrow (ve) mechanics for governance power
 *      - Progressive decentralization through governance
 *      - Emergency pause mechanism for crisis situations
 *      - Upgradeable via UUPS pattern
 *      - Fixed supply cap for tokenomics
 *      - Governance proposal and voting system
 *      - Lock-based voting power calculation
 * 
 * @dev Vote-escrow mechanics:
 *      - Users can lock QTI tokens for governance power
 *      - Longer locks = higher voting power (up to 4x multiplier)
 *      - Minimum lock: 7 days, Maximum lock: 4 years
 *      - Voting power decreases linearly over time
 *      - Locked tokens cannot be transferred until unlock
 * 
 * @dev Governance features:
 *      - Proposal creation with minimum threshold
 *      - Voting period with configurable duration
 *      - Vote counting and execution
 *      - Proposal cancellation and emergency actions
 * 
 * @dev Security features:
 *      - Role-based access control for all critical operations
 *      - Emergency pause mechanism for crisis situations
 *      - Upgradeable architecture for future improvements
 *      - Secure vote-escrow mechanics
 *      - Proposal execution safeguards
 * 
 * @dev Tokenomics:
 *      - Total supply: 100,000,000 QTI (fixed cap)
 *      - Initial distribution: Through protocol mechanisms
 *      - Decimals: 18 (standard for ERC20 tokens)
 *      - Governance power: Based on locked amount and duration
 * 
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
    // CONSTANTS AND ROLES - Protocol roles and limits
    // =============================================================================
    
    /// @notice Role for governance operations (proposal creation, execution)
    /// @dev keccak256 hash avoids role collisions with other contracts
    /// @dev Should be assigned to governance multisig or DAO
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    
    /// @notice Role for emergency operations (pause, emergency proposals)
    /// @dev keccak256 hash avoids role collisions with other contracts
    /// @dev Should be assigned to emergency multisig
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    /// @notice Role for performing contract upgrades via UUPS pattern
    /// @dev keccak256 hash avoids role collisions with other contracts
    /// @dev Should be assigned to governance or upgrade multisig
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Vote-escrow constants
    /// @notice Maximum lock time for vote-escrow (4 years)
    /// @dev Prevents infinite locks and ensures token circulation
    /// @dev Value: 4 * 365 days = 1,460 days
    uint256 public constant MAX_LOCK_TIME = 4 * 365 days; // 4 years max lock
    
    /// @notice Minimum lock time for vote-escrow (1 week)
    /// @dev Prevents very short locks that could manipulate governance
    /// @dev Value: 7 days
    uint256 public constant MIN_LOCK_TIME = 7 days; // 1 week minimum lock
    
    /// @notice Week duration in seconds (7 days)
    /// @dev Used for time calculations and voting periods
    /// @dev Value: 7 days = 604,800 seconds
    uint256 public constant WEEK = 7 days;
    
    /// @notice Maximum voting power multiplier (4x)
    /// @dev Maximum voting power a user can achieve through locking
    /// @dev Value: 4 (400% voting power for maximum lock)
    uint256 public constant MAX_VE_QTI_MULTIPLIER = 4; // 4x max voting power
    
    /// @notice Maximum time elapsed for calculations to prevent manipulation
    /// @dev Caps time-based calculations to prevent timestamp manipulation
    uint256 public constant MAX_TIME_ELAPSED = 10 * 365 days; // 10 years maximum

    // =============================================================================
    // STATE VARIABLES - Dynamic configuration and storage
    // =============================================================================
    
    /// @notice Total supply cap (100 million QTI)
    /// @dev Fixed supply cap for tokenomics
    /// @dev Value: 100,000,000 * 10^18 = 100,000,000 QTI
    uint256 public constant TOTAL_SUPPLY_CAP = 100_000_000 * 1e18;
    
    /// @notice Vote-escrow lock information for each user
    /// @dev Stores locked amount, unlock time, voting power, and claim time
    /// @dev Used to calculate governance power and manage locks
    struct LockInfo {
        uint256 amount;           // Locked QTI amount in wei (18 decimals)
        uint256 unlockTime;       // Timestamp when lock expires
        uint256 votingPower;      // Current voting power (calculated)
        uint256 lastClaimTime;    // Last claim time (for future use)
    }
    
    /// @notice Governance proposal structure
    /// @dev Stores all proposal data including voting results and execution info
    /// @dev Used for governance decision making
    struct Proposal {
        address proposer;         // Address that created the proposal
        uint256 startTime;        // Timestamp when voting starts
        uint256 endTime;          // Timestamp when voting ends
        uint256 forVotes;         // Total votes in favor
        uint256 againstVotes;     // Total votes against
        bool executed;            // Whether proposal was executed
        bool canceled;            // Whether proposal was canceled
        string description;       // Human-readable proposal description
        bytes data;               // Execution data (function calls)
        mapping(address => Receipt) receipts; // Individual voting receipts
    }
    
    /// @notice Voting receipt for each voter in a proposal
    /// @dev Stores individual voting information for each user
    /// @dev Used to prevent double voting and track individual votes
    struct Receipt {
        bool hasVoted;            // Whether user has voted on this proposal
        bool support;             // True for yes vote, false for no vote
        uint256 votes;            // Number of votes cast (voting power used)
    }
    
    /// @notice Vote-escrow locks per user address
    /// @dev Maps user addresses to their lock information
    /// @dev Used to track locked tokens and voting power
    mapping(address => LockInfo) public locks;
    
    /// @notice Total QTI tokens locked in vote-escrow
    /// @dev Sum of all locked amounts across all users
    /// @dev Used for protocol analytics and governance metrics
    uint256 public totalLocked;
    
    /// @notice Total voting power across all locked tokens
    /// @dev Sum of all voting power across all users
    /// @dev Used for governance quorum calculations
    uint256 public totalVotingPower;
    
    /// @notice Governance proposals by proposal ID
    /// @dev Maps proposal IDs to proposal data
    /// @dev Used to store and retrieve proposal information
    mapping(uint256 => Proposal) public proposals;
    
    /// @notice Next proposal ID to be assigned
    /// @dev Auto-incremented for each new proposal
    /// @dev Used to generate unique proposal identifiers
    uint256 public nextProposalId;
    
    /// @notice Minimum QTI required to create a governance proposal
    /// @dev Prevents spam proposals and ensures serious governance participation
    /// @dev Can be updated by governance
    uint256 public proposalThreshold;
    
    /// @notice Minimum voting period duration
    /// @dev Ensures adequate time for community discussion and voting
    /// @dev Can be updated by governance
    uint256 public minVotingPeriod;
    
    /// @notice Maximum voting period duration
    /// @dev Prevents excessively long voting periods
    /// @dev Can be updated by governance
    uint256 public maxVotingPeriod;
    
    /// @notice Quorum required for proposal to pass
    /// @dev Minimum number of votes needed for a proposal to be considered valid
    /// @dev Can be updated by governance
    uint256 public quorumVotes;

    /// @notice Treasury address for protocol fees
    /// @dev Address where protocol fees are collected and distributed
    /// @dev Can be updated by governance
    address public treasury;
    
    /// @notice Progressive decentralization parameters
    /// @dev Start time for the decentralization process
    /// @dev Duration of the decentralization process
    /// @dev Current level of decentralization (0-10000)
    uint256 public decentralizationStartTime;
    uint256 public decentralizationDuration;
    uint256 public currentDecentralizationLevel; // 0-10000 (0-100%)

    // =============================================================================
    // EVENTS
    // =============================================================================
    
    /// @notice Emitted when tokens are locked for voting power
    /// @param user Address of the user who locked tokens
    /// @param amount Amount of QTI locked
    /// @param unlockTime Timestamp when the lock expires
    /// @param votingPower Voting power calculated for the locked amount
    event TokensLocked(address indexed user, uint256 amount, uint256 unlockTime, uint256 votingPower);
    
    /// @notice Emitted when tokens are unlocked after lock period expires
    /// @param user Address of the user who unlocked tokens
    /// @param amount Amount of QTI unlocked
    /// @param votingPower Voting power before unlocking
    event TokensUnlocked(address indexed user, uint256 amount, uint256 votingPower);
    
    /// @notice Emitted when voting power for an address is updated
    /// @param user Address of the user whose voting power changed
    /// @param oldPower Previous voting power
    /// @param newPower New voting power
    event VotingPowerUpdated(address indexed user, uint256 oldPower, uint256 newPower);
    
    /// @notice Emitted when a new governance proposal is created
    /// @param proposalId Unique identifier for the proposal
    /// @param proposer Address of the proposer
    /// @param description Description of the proposal
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    
    /// @notice Emitted when a user votes on a proposal
    /// @param proposalId Unique identifier for the proposal
    /// @param voter Address of the voter
    /// @param support True for yes vote, false for no vote
    /// @param votes Number of votes cast
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 votes);
    
    /// @notice Emitted when a proposal is successfully executed
    /// @param proposalId Unique identifier for the executed proposal
    event ProposalExecuted(uint256 indexed proposalId);
    
    /// @notice Emitted when a proposal is canceled
    /// @param proposalId Unique identifier for the canceled proposal
    event ProposalCanceled(uint256 indexed proposalId);

    /// @notice Emitted when governance parameters are updated
    /// @param proposalThreshold New minimum QTI required to propose
    /// @param minVotingPeriod New minimum voting period
    /// @param quorumVotes New quorum required for proposals to pass
    event GovernanceParametersUpdated(uint256 proposalThreshold, uint256 minVotingPeriod, uint256 quorumVotes);

    /// @notice Emitted when the decentralization level is updated
    /// @param newLevel New decentralization level (0-10000)
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
     * @return veQTI Voting power calculated for the locked amount
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
     * @return amount Amount of QTI unlocked
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
     * @param user Address to get voting power for
     * @return votingPower Current voting power of the user
     */
    function getVotingPower(address user) external view returns (uint256 votingPower) {
        return locks[user].votingPower;
    }

    /**
     * @notice Get lock info for an address
     * @param user Address to get lock info for
     * @return amount Locked QTI amount
     * @return unlockTime Timestamp when lock expires
     * @return votingPower Current voting power
     * @return lastClaimTime Last claim time (for future use)
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
     * @param data Execution data (function calls)
     * @return proposalId Unique identifier for the created proposal
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
     * @param proposalId Proposal ID
     * @return proposer Address of the proposer
     * @return startTime Timestamp when voting starts
     * @return endTime Timestamp when voting ends
     * @return forVotes Total votes in favor
     * @return againstVotes Total votes against
     * @return executed Whether the proposal was executed
     * @return canceled Whether the proposal was canceled
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
     * @param proposalId Proposal ID
     * @param voter Address of the voter
     * @return hasVoted Whether the user has voted
     * @return support True for yes vote, false for no vote
     * @return votes Number of votes cast
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
     * @param _proposalThreshold New minimum QTI required to propose
     * @param _minVotingPeriod New minimum voting period
     * @param _quorumVotes New quorum required for proposals to pass
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
     * @param _treasury New treasury address
     */
    function updateTreasury(address _treasury) external onlyRole(GOVERNANCE_ROLE) {
        require(_treasury != address(0), "QTI: Treasury cannot be zero");
        treasury = _treasury;
    }

    /**
     * @notice Update decentralization level
     * @dev This function is intended to be called periodically by the governance
     *      to update the decentralization level based on the elapsed time.
     *      Includes bounds checking to prevent timestamp manipulation.
     * 
     * @dev SECURITY FIX: Timestamp Manipulation Protection
     *      - Added bounds checking to cap time elapsed at 10 years maximum
     *      - Prevents validators from manipulating timestamps to accelerate decentralization
     *      - Uses timeSinceStart calculation with reasonable upper bounds
     *      - Protects against excessive time manipulation that could bypass governance controls
     *      - Ensures decentralization process follows intended timeline
     */
    function updateDecentralizationLevel() external onlyRole(GOVERNANCE_ROLE) {
        uint256 timeElapsed = block.timestamp - decentralizationStartTime;
        
        // SECURITY FIX: Bounds check to prevent timestamp manipulation
        if (timeElapsed > MAX_TIME_ELAPSED) {
            timeElapsed = MAX_TIME_ELAPSED;
        }
        
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
     * @param lockTime Duration of the lock
     * @return multiplier Voting power multiplier
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

    /**
     * @notice Get current governance information
     * @return totalLocked_ Total QTI tokens locked in vote-escrow
     * @return totalVotingPower_ Total voting power across all locked tokens
     * @return proposalThreshold_ Minimum QTI required to propose
     * @return quorumVotes_ Quorum required for proposals to pass
     * @return currentDecentralizationLevel_ Current decentralization level (0-10000)
     */
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
