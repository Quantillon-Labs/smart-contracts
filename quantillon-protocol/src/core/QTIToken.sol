// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// =============================================================================
// IMPORTS - OpenZeppelin libraries for security and standards
// =============================================================================

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./SecureUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Custom libraries for bytecode reduction
import "../libraries/ErrorLibrary.sol";
import "../libraries/AccessControlLibrary.sol";
import "../libraries/ValidationLibrary.sol";
import "../libraries/TokenLibrary.sol";

import "../libraries/TreasuryRecoveryLibrary.sol";
import "../libraries/FlashLoanProtectionLibrary.sol";

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
    ReentrancyGuardUpgradeable,
    SecureUpgradeable
{
    using SafeERC20 for IERC20;
    using AccessControlLibrary for AccessControlUpgradeable;
    using ValidationLibrary for uint256;
    using TokenLibrary for address;

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
    


    // Vote-escrow constants
    /// @notice Maximum lock time for QTI tokens
    /// @dev Prevents extremely long locks that could impact governance
    uint256 public constant MAX_LOCK_TIME = 365 days;

    // SECURITY: Maximum batch sizes to prevent DoS attacks
    /// @notice Maximum batch size for lock operations to prevent DoS
    /// @dev Prevents out-of-gas attacks through large arrays
    uint256 public constant MAX_BATCH_SIZE = 100;
    
    /// @notice Maximum batch size for unlock operations to prevent DoS
    /// @dev Prevents out-of-gas attacks through large user arrays
    uint256 public constant MAX_UNLOCK_BATCH_SIZE = 50;
    
    /// @notice Maximum batch size for voting operations to prevent DoS
    /// @dev Prevents out-of-gas attacks through large proposal arrays
    uint256 public constant MAX_VOTE_BATCH_SIZE = 50;
    
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
    /// @dev OPTIMIZED: Fields ordered for optimal storage packing
    struct LockInfo {
        uint96 amount;            // Locked QTI amount in wei (18 decimals) - 12 bytes
        uint96 votingPower;       // Current voting power (calculated) - 12 bytes
        uint96 initialVotingPower; // Initial voting power when locked - 12 bytes
        uint32 unlockTime;        // Timestamp when lock expires - 4 bytes
        uint32 lastClaimTime;     // Last claim time (for future use) - 4 bytes
        uint32 lockTime;          // Original lock duration - 4 bytes
        // Total: 12 + 12 + 12 + 4 + 4 + 4 = 48 bytes (fits in 2 slots vs 6 slots)
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

    // MEV protection for governance execution
    /// @notice Execution time for each proposal (with random delay)
    mapping(uint256 => uint256) public proposalExecutionTime;
    /// @notice Execution hash for each proposal (for verification)
    mapping(uint256 => bytes32) public proposalExecutionHash;
    /// @notice Whether a proposal has been scheduled for execution
    mapping(uint256 => bool) public proposalScheduled;

    // =============================================================================
    // EVENTS
    // =============================================================================
    
    /// @notice Emitted when tokens are locked for voting power
    /// @param user Address of the user who locked tokens
    /// @param amount Amount of QTI locked
    /// @param unlockTime Timestamp when the lock expires
    /// @param votingPower Voting power calculated for the locked amount
    /// @dev OPTIMIZED: Indexed amount and unlockTime for efficient filtering
    event TokensLocked(address indexed user, uint256 indexed amount, uint256 indexed unlockTime, uint256 votingPower);
    
    /// @notice Emitted when tokens are unlocked after lock period expires
    /// @param user Address of the user who unlocked tokens
    /// @param amount Amount of QTI unlocked
    /// @param votingPower Voting power before unlocking
    /// @dev OPTIMIZED: Indexed amount for efficient filtering by unlock size
    event TokensUnlocked(address indexed user, uint256 indexed amount, uint256 votingPower);
    
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
    /// @dev OPTIMIZED: Indexed support for efficient filtering by vote direction
    event Voted(uint256 indexed proposalId, address indexed voter, bool indexed support, uint256 votes);
    
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
    /// @dev OPTIMIZED: Indexed parameter type for efficient filtering
    event GovernanceParametersUpdated(string indexed parameterType, uint256 proposalThreshold, uint256 minVotingPeriod, uint256 quorumVotes);

    /// @notice Emitted when the decentralization level is updated
    /// @param newLevel New decentralization level (0-10000)
    /// @dev OPTIMIZED: Indexed level for efficient filtering by decentralization stage
    event DecentralizationLevelUpdated(uint256 indexed newLevel);

    /// @notice Emitted when ETH is recovered from the contract
    /// @param to Recipient address
    /// @param amount Amount of ETH recovered
    event ETHRecovered(address indexed to, uint256 indexed amount);

    // =============================================================================
    // MODIFIERS - Access control and security
    // =============================================================================

    /**
     * @notice Modifier to protect against flash loan attacks
     * @dev Uses the FlashLoanProtectionLibrary to check QTI balance consistency
     */
    modifier flashLoanProtection() {
        uint256 balanceBefore = balanceOf(address(this));
        _;
        uint256 balanceAfter = balanceOf(address(this));
        FlashLoanProtectionLibrary.validateBalanceChange(balanceBefore, balanceAfter, 0);
    }

    // =============================================================================
    // INITIALIZER
    // =============================================================================

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin,
        address _treasury,
        address _timelock
    ) public initializer {
        AccessControlLibrary.validateAddress(admin);
        AccessControlLibrary.validateAddress(_treasury);
        AccessControlLibrary.validateAddress(_timelock);

        __ERC20_init("Quantillon Token", "QTI");
        __AccessControl_init();
        __Pausable_init();
        __SecureUpgradeable_init(_timelock);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);

        // slither-disable-next-line missing-zero-check
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
    function lock(uint256 amount, uint256 lockTime) external whenNotPaused flashLoanProtection returns (uint256 veQTI) {
        ValidationLibrary.validatePositiveAmount(amount);
        if (lockTime < MIN_LOCK_TIME) revert ErrorLibrary.LockTimeTooShort();
        if (lockTime > MAX_LOCK_TIME) revert ErrorLibrary.LockTimeTooLong();
        if (balanceOf(msg.sender) < amount) revert ErrorLibrary.InsufficientBalance();
        
        // Add validation for uint96 bounds
        if (amount > type(uint96).max) revert ErrorLibrary.InvalidAmount();
        if (lockTime > type(uint32).max) revert ErrorLibrary.InvalidTime();

        LockInfo storage lockInfo = locks[msg.sender];
        uint256 oldVotingPower = lockInfo.votingPower;
        
        // Calculate new unlock time with overflow check
        // SECURITY: Using block.timestamp for unlock time calculation (acceptable for time-based logic)
        uint256 newUnlockTime = block.timestamp + lockTime;
        if (newUnlockTime > type(uint32).max) revert ErrorLibrary.InvalidTime();
        
        // If already locked, extend the lock time
        // SECURITY: Using block.timestamp for lock expiration check (acceptable for time-based logic)
        if (lockInfo.unlockTime > block.timestamp) {
            newUnlockTime = lockInfo.unlockTime + lockTime;
            if (newUnlockTime > type(uint32).max) revert ErrorLibrary.InvalidTime();
        }
        
        // Calculate voting power with overflow check
        uint256 multiplier = _calculateVotingPowerMultiplier(lockTime);
        uint256 newVotingPower = amount * multiplier / 1e18;
        if (newVotingPower > type(uint96).max) revert ErrorLibrary.InvalidAmount();
        
        // Safe addition for amount
        uint256 newAmount = uint256(lockInfo.amount) + amount;
        if (newAmount > type(uint96).max) revert ErrorLibrary.InvalidAmount();
        
        // Now safe to cast
        lockInfo.amount = uint96(newAmount);
        lockInfo.unlockTime = uint32(newUnlockTime);
        lockInfo.initialVotingPower = uint96(newVotingPower);
        lockInfo.lockTime = uint32(lockTime);
        lockInfo.votingPower = uint96(newVotingPower);
        
        // Use checked arithmetic for critical state
        totalLocked = totalLocked + amount;
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
    function unlock() external whenNotPaused returns (uint256 amount) {
        LockInfo storage lockInfo = locks[msg.sender];
        // SECURITY: Using block.timestamp for lock expiration check (acceptable for time-based logic)
        if (lockInfo.unlockTime > block.timestamp) revert ErrorLibrary.LockNotExpired();
        if (lockInfo.amount == 0) revert ErrorLibrary.NothingToUnlock();



        amount = lockInfo.amount;
        uint256 oldVotingPower = lockInfo.votingPower;
        
        // Clear lock info - OPTIMIZED: Batch storage writes
        lockInfo.amount = 0;
        lockInfo.unlockTime = 0;
        lockInfo.votingPower = 0;
        
        // Update global totals - Use checked arithmetic for critical state
        totalLocked = totalLocked - amount;
        totalVotingPower = totalVotingPower - oldVotingPower;
        
        // Transfer tokens back to user
        _transfer(address(this), msg.sender, amount);
        
        emit TokensUnlocked(msg.sender, amount, oldVotingPower);
        emit VotingPowerUpdated(msg.sender, oldVotingPower, 0);
    }

    /**
     * @notice Batch lock QTI tokens for voting power for multiple amounts
     * @param amounts Array of QTI amounts to lock
     * @param lockTimes Array of lock durations (must be >= MIN_LOCK_TIME)
     * @return veQTIAmounts Array of voting power calculated for each locked amount
     */
    function batchLock(uint256[] calldata amounts, uint256[] calldata lockTimes) 
        external 
        whenNotPaused 
        flashLoanProtection
        returns (uint256[] memory veQTIAmounts) 
    {
        if (amounts.length != lockTimes.length) revert ErrorLibrary.ArrayLengthMismatch();
        if (amounts.length > MAX_BATCH_SIZE) revert ErrorLibrary.BatchSizeTooLarge();
        
        veQTIAmounts = new uint256[](amounts.length);
        uint256 totalAmount = 0;
        
        // GAS OPTIMIZATION: Cache storage reads
        uint256 minLockTime = MIN_LOCK_TIME;
        uint256 maxLockTime = MAX_LOCK_TIME;
        
        // Pre-validate all inputs
        for (uint256 i = 0; i < amounts.length; i++) {
            ValidationLibrary.validatePositiveAmount(amounts[i]);
            if (lockTimes[i] < minLockTime) revert ErrorLibrary.LockTimeTooShort();
            if (lockTimes[i] > maxLockTime) revert ErrorLibrary.LockTimeTooLong();
            if (amounts[i] > type(uint96).max) revert ErrorLibrary.InvalidAmount();
            if (lockTimes[i] > type(uint32).max) revert ErrorLibrary.InvalidTime();
            
            totalAmount += amounts[i];
        }
        
        if (balanceOf(msg.sender) < totalAmount) revert ErrorLibrary.InsufficientBalance();
        
        LockInfo storage lockInfo = locks[msg.sender];
        uint256 oldVotingPower = lockInfo.votingPower;
        uint256 totalNewVotingPower = 0;
        uint256 totalNewAmount = uint256(lockInfo.amount);
        

        // SECURITY: Using block.timestamp for unlock time calculation (acceptable for time-based logic)
        uint256 currentTimestamp = block.timestamp;
        uint256 lockInfoUnlockTime = lockInfo.unlockTime;
        
        // Process each lock
        for (uint256 i = 0; i < amounts.length; i++) {
            uint256 amount = amounts[i];
            uint256 lockTime = lockTimes[i];
            
            // Calculate new unlock time with overflow check
            uint256 newUnlockTime = currentTimestamp + lockTime;
            if (newUnlockTime > type(uint32).max) revert ErrorLibrary.InvalidTime();
            
            // If already locked, extend the lock time
            if (lockInfoUnlockTime > currentTimestamp) {
                newUnlockTime = lockInfoUnlockTime + lockTime;
                if (newUnlockTime > type(uint32).max) revert ErrorLibrary.InvalidTime();
            }
            
            // Calculate voting power with overflow check
            uint256 multiplier = _calculateVotingPowerMultiplier(lockTime);
            uint256 newVotingPower = amount * multiplier / 1e18;
            if (newVotingPower > type(uint96).max) revert ErrorLibrary.InvalidAmount();
            
            veQTIAmounts[i] = newVotingPower;
            totalNewVotingPower += newVotingPower;
            totalNewAmount += amount;
            
            // Update lock info for the last iteration
            if (i == amounts.length - 1) {
                if (totalNewAmount > type(uint96).max) revert ErrorLibrary.InvalidAmount();
                if (totalNewVotingPower > type(uint96).max) revert ErrorLibrary.InvalidAmount();
                
                lockInfo.amount = uint96(totalNewAmount);
                lockInfo.unlockTime = uint32(newUnlockTime);
                lockInfo.initialVotingPower = uint96(totalNewVotingPower);
                lockInfo.lockTime = uint32(lockTime); // Use the last lock time
                lockInfo.votingPower = uint96(totalNewVotingPower);
            }
            
            emit TokensLocked(msg.sender, amount, newUnlockTime, newVotingPower);
        }
        
        // Update global totals once
        totalLocked = totalLocked + totalAmount;
        totalVotingPower = totalVotingPower - oldVotingPower + totalNewVotingPower;
        
        // Transfer tokens to this contract once
        _transfer(msg.sender, address(this), totalAmount);
        
        emit VotingPowerUpdated(msg.sender, oldVotingPower, totalNewVotingPower);
    }

    /**
     * @notice Batch unlock QTI tokens for multiple users (admin function)
     * @param users Array of user addresses to unlock for
     * @return amounts Array of QTI amounts unlocked
     */
    function batchUnlock(address[] calldata users) 
        external 
        onlyRole(GOVERNANCE_ROLE)
        whenNotPaused 
        returns (uint256[] memory amounts) 
    {
        if (users.length > MAX_UNLOCK_BATCH_SIZE) revert ErrorLibrary.BatchSizeTooLarge();
        
        amounts = new uint256[](users.length);
        

        // SECURITY: Using block.timestamp for lock expiration check (acceptable for time-based logic)
        uint256 currentTimestamp = block.timestamp;
        uint256 length = users.length;
        
        for (uint256 i = 0; i < length;) {
            address user = users[i];
            LockInfo storage lockInfo = locks[user];
            
            if (lockInfo.unlockTime > currentTimestamp) revert ErrorLibrary.LockNotExpired();
            if (lockInfo.amount == 0) revert ErrorLibrary.NothingToUnlock();

            uint256 amount = lockInfo.amount;
            uint256 oldVotingPower = lockInfo.votingPower;
            amounts[i] = amount;
            
            // Clear lock info
            lockInfo.amount = 0;
            lockInfo.unlockTime = 0;
            lockInfo.votingPower = 0;
            
            // Update global totals - GAS OPTIMIZATION: Use unchecked for safe arithmetic
            unchecked {
                totalLocked = totalLocked - amount;
                totalVotingPower = totalVotingPower - oldVotingPower;
            }
            
            // Transfer tokens back to user
            _transfer(address(this), user, amount);
            
            emit TokensUnlocked(user, amount, oldVotingPower);
            emit VotingPowerUpdated(user, oldVotingPower, 0);
            
            unchecked { ++i; }
        }
    }

    /**
     * @notice Batch transfer QTI tokens to multiple addresses
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts to transfer
     */
    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts)
        external
        whenNotPaused
        flashLoanProtection
        returns (bool)
    {
        if (recipients.length != amounts.length) revert ErrorLibrary.ArrayLengthMismatch();
        if (recipients.length > MAX_BATCH_SIZE) revert ErrorLibrary.BatchSizeTooLarge();
        
        // Pre-validate recipients and amounts
        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] == address(0)) revert ErrorLibrary.InvalidAddress();
            if (amounts[i] == 0) revert ErrorLibrary.InvalidAmount();
        }
        

        address sender = msg.sender;
        
        // Perform transfers using OpenZeppelin's transfer mechanism
        for (uint256 i = 0; i < recipients.length; i++) {
            _transfer(sender, recipients[i], amounts[i]);
        }
        
        return true;
    }

    /**
     * @notice Get voting power for an address with linear decay
     * @param user Address to get voting power for
     * @return votingPower Current voting power of the user (decays linearly over time)
     */
    function getVotingPower(address user) external view returns (uint256 votingPower) {
        LockInfo storage lockInfo = locks[user];
        
        // If no lock or lock has expired, return 0
        if (lockInfo.unlockTime <= block.timestamp || lockInfo.amount == 0) {
            return 0;
        }
        
        // If lock hasn't started yet, return initial voting power
        if (lockInfo.unlockTime <= lockInfo.lockTime) {
            return lockInfo.initialVotingPower;
        }
        
        // Calculate remaining time - OPTIMIZED: Use unchecked for safe arithmetic
        unchecked {
            uint256 remainingTime = lockInfo.unlockTime - block.timestamp;
            uint256 originalLockTime = lockInfo.lockTime;
            
            // Voting power decreases linearly to zero
            // Use the smaller of remaining time or original lock time to prevent overflow
            if (remainingTime >= originalLockTime) {
                return lockInfo.initialVotingPower;
            }
            
            return lockInfo.initialVotingPower * remainingTime / originalLockTime;
        }
    }

    /**
     * @notice Update voting power for the caller based on current time
     * @return newVotingPower Updated voting power
     */
    function updateVotingPower() external returns (uint256 newVotingPower) {
        return _updateVotingPower(msg.sender);
    }

    /**
     * @notice Get lock info for an address
     * @param user Address to get lock info for
     * @return amount Locked QTI amount
     * @return unlockTime Timestamp when lock expires
     * @return votingPower Current voting power
     * @return lastClaimTime Last claim time (for future use)
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
    ) {
        LockInfo storage lockInfo = locks[user];
        return (
            lockInfo.amount,
            lockInfo.unlockTime,
            lockInfo.votingPower,
            lockInfo.lastClaimTime,
            lockInfo.initialVotingPower,
            lockInfo.lockTime
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
    ) external whenNotPaused returns (uint256 proposalId) {
        // Update voting power to current time before checking threshold
        uint256 currentVotingPower = _updateVotingPower(msg.sender);
        if (currentVotingPower < proposalThreshold) revert ErrorLibrary.InsufficientVotingPower();
        if (votingPeriod < minVotingPeriod) revert ErrorLibrary.VotingPeriodTooShort();
        if (votingPeriod > maxVotingPeriod) revert ErrorLibrary.VotingPeriodTooLong();

        proposalId = nextProposalId++;
        
        Proposal storage proposal = proposals[proposalId];
        proposal.proposer = msg.sender;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + votingPeriod;
        proposal.description = description;
        proposal.data = data;

        // Initialize execution-related mappings to prevent uninitialized state variable warnings
        proposalExecutionTime[proposalId] = 0;
        proposalExecutionHash[proposalId] = bytes32(0);
        proposalScheduled[proposalId] = false;

        emit ProposalCreated(proposalId, msg.sender, description);
    }

    /**
     * @notice Vote on a proposal
     * @param proposalId Proposal ID
     * @param support True for yes, false for no
     */
    function vote(uint256 proposalId, bool support) external whenNotPaused {
        Proposal storage proposal = proposals[proposalId];
        if (block.timestamp < proposal.startTime) revert ErrorLibrary.VotingNotStarted();
        if (block.timestamp >= proposal.endTime) revert ErrorLibrary.VotingEnded();
        if (proposal.receipts[msg.sender].hasVoted) revert ErrorLibrary.AlreadyVoted();

        // Update voting power to current time before voting
        uint256 votingPower = _updateVotingPower(msg.sender);
        if (votingPower == 0) revert ErrorLibrary.NoVotingPower();

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
     * @notice Batch vote on multiple proposals
     * @param proposalIds Array of proposal IDs to vote on
     * @param supportVotes Array of vote directions (true for yes, false for no)
     */
    function batchVote(uint256[] calldata proposalIds, bool[] calldata supportVotes) external whenNotPaused flashLoanProtection {
        if (proposalIds.length != supportVotes.length) revert ErrorLibrary.ArrayLengthMismatch();
        if (proposalIds.length > MAX_VOTE_BATCH_SIZE) revert ErrorLibrary.BatchSizeTooLarge();
        
        // Update voting power once for the batch
        uint256 votingPower = _updateVotingPower(msg.sender);
        if (votingPower == 0) revert ErrorLibrary.NoVotingPower();
        

        uint256 currentTimestamp = block.timestamp;
        address sender = msg.sender;
        
        // Process each vote
        for (uint256 i = 0; i < proposalIds.length; i++) {
            uint256 proposalId = proposalIds[i];
            bool support = supportVotes[i];
            
            Proposal storage proposal = proposals[proposalId];
            if (currentTimestamp < proposal.startTime) revert ErrorLibrary.VotingNotStarted();
            if (currentTimestamp >= proposal.endTime) revert ErrorLibrary.VotingEnded();
            if (proposal.receipts[sender].hasVoted) revert ErrorLibrary.AlreadyVoted();

            proposal.receipts[sender] = Receipt({
                hasVoted: true,
                support: support,
                votes: votingPower
            });

            if (support) {
                proposal.forVotes += votingPower;
            } else {
                proposal.againstVotes += votingPower;
            }

            emit Voted(proposalId, sender, support, votingPower);
        }
    }

    /**
     * @notice Execute a successful proposal
     * @param proposalId Proposal ID
     */
    function executeProposal(uint256 proposalId) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        if (block.timestamp < proposal.endTime) revert ErrorLibrary.VotingNotEnded();
        if (proposal.executed) revert ErrorLibrary.ProposalAlreadyExecuted();
        if (proposal.canceled) revert ErrorLibrary.ProposalCanceled();
        if (proposal.forVotes <= proposal.againstVotes) revert ErrorLibrary.ProposalFailed();
        if (proposal.forVotes + proposal.againstVotes < quorumVotes) revert ErrorLibrary.QuorumNotMet();


        proposal.executed = true;

        // Execute the proposal data
        if (proposal.data.length > 0) {

            (bool success, ) = address(this).call(proposal.data);
            if (!success) revert ErrorLibrary.ProposalExecutionFailed();
        }

        emit ProposalExecuted(proposalId);
    }

    /**
     * @notice Get execution information for a scheduled proposal
     * @param proposalId Proposal ID
     * @return scheduled Whether the proposal is scheduled
     * @return executionTime When the proposal can be executed
     * @return canExecute Whether the proposal can be executed now
     */
    function getProposalExecutionInfo(uint256 proposalId) external view returns (
        bool scheduled,
        uint256 executionTime,
        bool canExecute
    ) {
        scheduled = proposalScheduled[proposalId];
        executionTime = proposalExecutionTime[proposalId];
        canExecute = scheduled && block.timestamp >= executionTime;
    }

    /**
     * @notice Get the execution hash for a scheduled proposal
     * @param proposalId Proposal ID
     * @return executionHash Hash required to execute the proposal
     */
    function getProposalExecutionHash(uint256 proposalId) external view returns (bytes32 executionHash) {
        return proposalExecutionHash[proposalId];
    }

    /**
     * @notice Cancel a proposal (only proposer or admin)
     * @param proposalId Proposal ID
     */
    function cancelProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        if (msg.sender != proposal.proposer && !hasRole(GOVERNANCE_ROLE, msg.sender)) {
            revert ErrorLibrary.NotAuthorized();
        }
        if (proposal.executed) revert ErrorLibrary.ProposalAlreadyExecuted();
        if (proposal.canceled) revert ErrorLibrary.ProposalAlreadyCanceled();

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

        emit GovernanceParametersUpdated("governance", _proposalThreshold, _minVotingPeriod, _quorumVotes);
    }



    /**
     * @notice Update treasury address
     * @param _treasury New treasury address
     */
    function updateTreasury(address _treasury) external onlyRole(GOVERNANCE_ROLE) {
        AccessControlLibrary.validateAddress(_treasury);
        // slither-disable-next-line missing-zero-check
        treasury = _treasury;
    }

    /**
     * @notice Update decentralization level
     * @dev This function is intended to be called periodically by the governance
     *      to update the decentralization level based on the elapsed time.
     *      Includes bounds checking to prevent timestamp manipulation.
     * 

     */
    function updateDecentralizationLevel() external onlyRole(GOVERNANCE_ROLE) {
        uint256 timeElapsed = block.timestamp - decentralizationStartTime;
        

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

    /**
     * @notice Update voting power for a user based on current time
     * @param user Address of the user to update
     * @return newVotingPower Updated voting power
     */
    function _updateVotingPower(address user) internal returns (uint256 newVotingPower) {
        LockInfo storage lockInfo = locks[user];
        
        // If no lock or lock has expired, voting power is 0
        if (lockInfo.unlockTime <= block.timestamp || lockInfo.amount == 0) {
            newVotingPower = 0;
        } else {
            // Calculate current voting power with linear decay - OPTIMIZED: Use unchecked for safe arithmetic
            unchecked {
                uint256 remainingTime = lockInfo.unlockTime - block.timestamp;
                uint256 originalLockTime = lockInfo.lockTime;
                
                if (remainingTime >= originalLockTime) {
                    newVotingPower = lockInfo.initialVotingPower;
                } else {
                    newVotingPower = lockInfo.initialVotingPower * remainingTime / originalLockTime;
                }
            }
        }
        
        // Update stored voting power with overflow check
        uint256 oldVotingPower = lockInfo.votingPower;
        if (newVotingPower > type(uint96).max) revert ErrorLibrary.InvalidAmount();
        lockInfo.votingPower = uint96(newVotingPower);
        
        // Update total voting power - Use checked arithmetic for critical state
        totalVotingPower = totalVotingPower - oldVotingPower + newVotingPower;
        
        return newVotingPower;
    }



    // =============================================================================
    // OVERRIDE FUNCTIONS
    // =============================================================================

    function decimals() public pure override returns (uint8) {
        return 18;
    }



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
    // RECOVERY FUNCTIONS
    // =============================================================================

    /**
     * @notice Recover accidentally sent tokens to treasury only
     * @param token Token address to recover
     * @param amount Amount to recover
     */
    function recoverToken(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Use the shared library for secure token recovery to treasury
        TreasuryRecoveryLibrary.recoverToken(token, amount, address(this), treasury);
    }

    /**
     * @notice Recover accidentally sent ETH to treasury address only
     * @dev SECURITY: Restricted to treasury to prevent arbitrary ETH transfers
     */
    function recoverETH() external onlyRole(DEFAULT_ADMIN_ROLE) {

        emit ETHRecovered(treasury, address(this).balance);
        // Use the shared library for secure ETH recovery
        TreasuryRecoveryLibrary.recoverETH(treasury);
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
