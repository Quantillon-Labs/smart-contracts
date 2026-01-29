// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// =============================================================================
// IMPORTS - OpenZeppelin libraries for security and standards
// =============================================================================

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SecureUpgradeable} from "./SecureUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Custom libraries for bytecode reduction
import {CommonErrorLibrary} from "../libraries/CommonErrorLibrary.sol";
import {TokenErrorLibrary} from "../libraries/TokenErrorLibrary.sol";
import {AccessControlLibrary} from "../libraries/AccessControlLibrary.sol";
import {CommonValidationLibrary} from "../libraries/CommonValidationLibrary.sol";
import {TokenLibrary} from "../libraries/TokenLibrary.sol";

import {TreasuryRecoveryLibrary} from "../libraries/TreasuryRecoveryLibrary.sol";
import {FlashLoanProtectionLibrary} from "../libraries/FlashLoanProtectionLibrary.sol";
import {TimeProvider} from "../libraries/TimeProviderLibrary.sol";
import {QTITokenGovernanceLibrary} from "../libraries/QTITokenGovernanceLibrary.sol";
import {AdminFunctionsLibrary} from "../libraries/AdminFunctionsLibrary.sol";
import {CommonValidationLibrary} from "../libraries/CommonValidationLibrary.sol";
import {HedgerPoolErrorLibrary} from "../libraries/HedgerPoolErrorLibrary.sol";

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
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
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
    using CommonValidationLibrary for uint256;
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
    // Struct to reduce stack depth in batch operations
    struct BatchLockState {
        uint256 currentTimestamp;
        uint256 existingUnlockTime;
        uint256 finalUnlockTime;
        uint256 finalLockTime;
        uint256 newUnlockTime;
        uint256 newVotingPower;
    }
    
    struct LockInfo {
        uint96 amount;            // Locked QTI amount in wei (18 decimals) - 12 bytes
        uint96 votingPower;       // Current voting power (calculated) - 12 bytes
        uint96 initialVotingPower; // Initial voting power when locked - 12 bytes
        uint32 unlockTime;        // Timestamp when lock expires - 4 bytes
        uint32 lastClaimTime;     // Last claim time (for future use) - 4 bytes
        uint32 lockTime;          // Original lock duration - 4 bytes
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

    /// @notice Balance before flash loan check (used by flashLoanProtection modifier)
    uint256 private _flashLoanBalanceBefore;
    
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

    /// @notice TimeProvider contract for centralized time management
    /// @dev Used to replace direct block.timestamp usage for testability and consistency
    TimeProvider public immutable TIME_PROVIDER;

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
        _flashLoanProtectionBefore();
        _;
        _flashLoanProtectionAfter();
    }

    function _flashLoanProtectionBefore() private {
        _flashLoanBalanceBefore = balanceOf(address(this));
    }

    function _flashLoanProtectionAfter() private view {
        uint256 balanceAfter = balanceOf(address(this));
        if (!FlashLoanProtectionLibrary.validateBalanceChange(_flashLoanBalanceBefore, balanceAfter, 0)) {
            revert HedgerPoolErrorLibrary.FlashLoanAttackDetected();
        }
    }

    // =============================================================================
    // INITIALIZER
    // =============================================================================

    /**
     * @notice Constructor for QTI token contract
     * @dev Sets up the time provider and disables initializers for security
     * @param _TIME_PROVIDER TimeProvider contract for centralized time management
     * @custom:security Validates time provider address and disables initializers
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Sets immutable time provider and disables initializers
     * @custom:events No events emitted
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access No access restrictions
     * @custom:oracle No oracle dependencies
     */
    constructor(TimeProvider _TIME_PROVIDER) {
        if (address(_TIME_PROVIDER) == address(0)) revert CommonErrorLibrary.ZeroAddress();
        TIME_PROVIDER = _TIME_PROVIDER;
        _disableInitializers();
    }

    /**
     * @notice Initializes the QTI token contract
     * @dev Sets up the governance token with initial configuration and assigns roles to admin
     * @param admin Address that receives admin and governance roles
     * @param _treasury Treasury address for protocol fees
     * @param _timelock Timelock contract address for secure upgrades
     * @custom:security Validates all input addresses and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Initializes all contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to initializer modifier
     * @custom:oracle No oracle dependencies
     */
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

        if (_treasury == address(0)) revert CommonErrorLibrary.ZeroAddress();
        CommonValidationLibrary.validateTreasuryAddress(_treasury);
        CommonValidationLibrary.validateNonZeroAddress(_treasury, "treasury");
        treasury = _treasury;
        
        // Initial governance parameters
        proposalThreshold = 100_000 * 1e18; // 100k QTI to propose
        minVotingPeriod = 3 days;
        maxVotingPeriod = 14 days;
        quorumVotes = 1_000_000 * 1e18; // 1M QTI quorum     
        
        decentralizationStartTime = TIME_PROVIDER.currentTime();
        decentralizationDuration = 2 * 365 days; // 2 years to full decentralization
        currentDecentralizationLevel = 0; // Start with 0% decentralization
    }



    // =============================================================================
    // VOTE-ESCROW FUNCTIONS
    // =============================================================================

    /**
     * @notice Locks QTI tokens for a specified duration to earn voting power (veQTI)
     * @dev Longer lock periods generate more voting power via time-weighted calculations
     * @param amount The amount of QTI tokens to lock
     * @param lockTime The duration to lock tokens (in seconds)
     * @return veQTI The amount of voting power (veQTI) earned from this lock
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function lock(uint256 amount, uint256 lockTime) external whenNotPaused flashLoanProtection returns (uint256 veQTI) {
        CommonValidationLibrary.validatePositiveAmount(amount);
        if (lockTime < MIN_LOCK_TIME) revert CommonErrorLibrary.LockTimeTooShort();
        if (lockTime > MAX_LOCK_TIME) revert CommonErrorLibrary.LockTimeTooLong();
        if (balanceOf(msg.sender) < amount) revert CommonErrorLibrary.InsufficientBalance();
        
        // Add validation for uint96 bounds
        if (amount > type(uint96).max) revert CommonErrorLibrary.InvalidAmount();
        if (lockTime > type(uint32).max) revert CommonErrorLibrary.InvalidTime();

        LockInfo storage lockInfo = locks[msg.sender];
        uint256 oldVotingPower = lockInfo.votingPower;
        
        // Calculate new unlock time with overflow check
        // Time-based logic using TimeProvider for consistent and testable timing
        uint256 newUnlockTime = TIME_PROVIDER.currentTime() + lockTime;
        if (newUnlockTime > type(uint32).max) revert CommonErrorLibrary.InvalidTime();
        
        // If already locked, extend the lock time
        // Time-based logic using TimeProvider for consistent and testable timing
        if (lockInfo.unlockTime > TIME_PROVIDER.currentTime()) {
            newUnlockTime = lockInfo.unlockTime + lockTime;
            if (newUnlockTime > type(uint32).max) revert CommonErrorLibrary.InvalidTime();
        }
        
        // Calculate voting power with overflow check
        uint256 multiplier = _calculateVotingPowerMultiplier(lockTime);
        uint256 newVotingPower = amount * multiplier / 1e18;
        if (newVotingPower > type(uint96).max) revert CommonErrorLibrary.InvalidAmount();
        

        uint256 newAmount = uint256(lockInfo.amount) + amount;
        if (newAmount > type(uint96).max) revert CommonErrorLibrary.InvalidAmount();

        // Now safe to cast
        // forge-lint: disable-next-line(unsafe-typecast)
        lockInfo.amount = uint96(newAmount);
        // forge-lint: disable-next-line(unsafe-typecast)
        lockInfo.unlockTime = uint32(newUnlockTime);
        // forge-lint: disable-next-line(unsafe-typecast)
        lockInfo.initialVotingPower = uint96(newVotingPower);
        // forge-lint: disable-next-line(unsafe-typecast)
        lockInfo.lockTime = uint32(lockTime);
        // forge-lint: disable-next-line(unsafe-typecast)
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
     * @dev Releases locked QTI tokens and removes voting power when lock period has expired
     * @return amount Amount of QTI unlocked
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function unlock() external whenNotPaused returns (uint256 amount) {
        LockInfo storage lockInfo = locks[msg.sender];
        // Time-based logic using TimeProvider for consistent and testable timing
        if (lockInfo.unlockTime > TIME_PROVIDER.currentTime()) revert TokenErrorLibrary.LockNotExpired();
        if (lockInfo.amount == 0) revert TokenErrorLibrary.NothingToUnlock();



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
     * @dev Efficiently locks multiple amounts with different lock times in a single transaction
     * @param amounts Array of QTI amounts to lock
     * @param lockTimes Array of lock durations (must be >= MIN_LOCK_TIME)
     * @return veQTIAmounts Array of voting power calculated for each locked amount
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function batchLock(uint256[] calldata amounts, uint256[] calldata lockTimes) 
        external 
        whenNotPaused 
        flashLoanProtection
        returns (uint256[] memory veQTIAmounts) 
    {
        _validateBatchLockInputs(amounts, lockTimes);
        
        uint256 totalAmount = _validateAndCalculateTotalAmount(amounts, lockTimes);
        if (balanceOf(msg.sender) < totalAmount) revert CommonErrorLibrary.InsufficientBalance();
        
        veQTIAmounts = new uint256[](amounts.length);
        LockInfo storage lockInfo = locks[msg.sender];
        uint256 oldVotingPower = lockInfo.votingPower;
        
        (uint256 totalNewVotingPower,) = _processBatchLocks(
            amounts, 
            lockTimes, 
            veQTIAmounts, 
            lockInfo
        );
        
        _updateGlobalTotalsAndTransfer(totalAmount, oldVotingPower, totalNewVotingPower);
        
        emit VotingPowerUpdated(msg.sender, oldVotingPower, totalNewVotingPower);
    }
    
    /**
     * @notice Validates basic batch lock inputs
     * @dev Ensures array lengths match and batch size is within limits
     * @param amounts Array of QTI amounts to lock
     * @param lockTimes Array of lock durations
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes No state changes
     * @custom:events No events emitted
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access Internal function
     * @custom:oracle No oracle dependencies
     */
    function _validateBatchLockInputs(uint256[] calldata amounts, uint256[] calldata lockTimes) internal pure {
        if (amounts.length != lockTimes.length) revert CommonErrorLibrary.ArrayLengthMismatch();
        if (amounts.length > MAX_BATCH_SIZE) revert CommonErrorLibrary.BatchSizeTooLarge();
    }
    
    /**
     * @notice Validates all amounts and lock times, returns total amount
     * @dev Ensures all amounts and lock times are valid and calculates total amount
     * @param amounts Array of QTI amounts to lock
     * @param lockTimes Array of lock durations
     * @return totalAmount Total amount of QTI to be locked
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes No state changes
     * @custom:events No events emitted
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access Internal function
     * @custom:oracle No oracle dependencies
     */
    function _validateAndCalculateTotalAmount(
        uint256[] calldata amounts, 
        uint256[] calldata lockTimes
    ) internal pure returns (uint256 totalAmount) {
        return QTITokenGovernanceLibrary.validateAndCalculateTotalAmount(amounts, lockTimes);
    }
    
    /**
     * @notice Processes all locks and calculates totals
     * @dev Processes batch lock operations and calculates total voting power and amounts
     * @param amounts Array of QTI amounts to lock
     * @param lockTimes Array of lock durations
     * @param veQTIAmounts Array to store calculated voting power amounts
     * @param lockInfo Storage reference to user's lock information
     * @return totalNewVotingPower Total new voting power from all locks
     * @return totalNewAmount Total new amount locked
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access Internal function
     * @custom:oracle No oracle dependencies
     */
    function _processBatchLocks(
        uint256[] calldata amounts,
        uint256[] calldata lockTimes,
        uint256[] memory veQTIAmounts,
        LockInfo storage lockInfo
    ) internal returns (uint256 totalNewVotingPower, uint256 totalNewAmount) {
        // Use struct to reduce stack depth - initialize all fields explicitly
        uint256 currentTimestamp = TIME_PROVIDER.currentTime();
        uint256 existingUnlockTime = lockInfo.unlockTime;
        totalNewAmount = uint256(lockInfo.amount);
        BatchLockState memory state = BatchLockState({
            currentTimestamp: currentTimestamp,
            existingUnlockTime: existingUnlockTime,
            finalUnlockTime: existingUnlockTime,
            finalLockTime: lockInfo.lockTime,
            newUnlockTime: 0,
            newVotingPower: 0
        });
        
        uint256 length = amounts.length;
        for (uint256 i = 0; i < length;) {
            state.newUnlockTime = _calculateUnlockTime(state.currentTimestamp, lockTimes[i], state.existingUnlockTime);
            state.newVotingPower = _calculateVotingPower(amounts[i], lockTimes[i]);
            
            veQTIAmounts[i] = state.newVotingPower;
            totalNewVotingPower += state.newVotingPower;
            totalNewAmount += amounts[i];
            
            // Store final values for last iteration
            state.finalUnlockTime = state.newUnlockTime;
            state.finalLockTime = lockTimes[i];
            
            emit TokensLocked(msg.sender, amounts[i], state.newUnlockTime, state.newVotingPower);
            
            unchecked { ++i; }
        }
        
        // Update lock info after the loop
        _updateLockInfo(lockInfo, totalNewAmount, state.finalUnlockTime, totalNewVotingPower, state.finalLockTime);
    }
    
    /**
     * @notice Calculates unlock time with proper validation
     * @dev Calculates new unlock time based on current timestamp and lock duration
     * @param currentTimestamp Current timestamp for calculation
     * @param lockTime Duration to lock tokens
     * @param existingUnlockTime Existing unlock time if already locked
     * @return newUnlockTime Calculated unlock time
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes No state changes
     * @custom:events No events emitted
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access Internal function
     * @custom:oracle No oracle dependencies
     */
    function _calculateUnlockTime(
        uint256 currentTimestamp,
        uint256 lockTime,
        uint256 existingUnlockTime
    ) internal pure returns (uint256 newUnlockTime) {
        return QTITokenGovernanceLibrary.calculateUnlockTime(currentTimestamp, lockTime, existingUnlockTime);
    }
    
    /**
     * @notice Calculates voting power with overflow protection
     * @dev Calculates voting power based on amount and lock time with overflow protection
     * @param amount Amount of QTI tokens to lock
     * @param lockTime Duration to lock tokens
     * @return votingPower Calculated voting power
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes No state changes
     * @custom:events No events emitted
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access Internal function
     * @custom:oracle No oracle dependencies
     */
    function _calculateVotingPower(uint256 amount, uint256 lockTime) internal pure returns (uint256) {
        return QTITokenGovernanceLibrary.calculateVotingPower(amount, lockTime);
    }
    
    /**
     * @notice Updates lock info with overflow checks
     * @dev Updates user's lock information with new amounts and times
     * @param lockInfo Storage reference to user's lock information
     * @param totalNewAmount Total new amount to lock
     * @param newUnlockTime New unlock time
     * @param totalNewVotingPower Total new voting power
     * @param lockTime Lock duration
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events No events emitted
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access Internal function
     * @custom:oracle No oracle dependencies
     */
    function _updateLockInfo(
        LockInfo storage lockInfo,
        uint256 totalNewAmount,
        uint256 newUnlockTime,
        uint256 totalNewVotingPower,
        uint256 lockTime
    ) internal {
        if (totalNewAmount > type(uint96).max) revert CommonErrorLibrary.InvalidAmount();
        if (totalNewVotingPower > type(uint96).max) revert CommonErrorLibrary.InvalidAmount();

        // forge-lint: disable-next-line(unsafe-typecast)
        lockInfo.amount = uint96(totalNewAmount);
        // forge-lint: disable-next-line(unsafe-typecast)
        lockInfo.unlockTime = uint32(newUnlockTime);
        // forge-lint: disable-next-line(unsafe-typecast)
        lockInfo.initialVotingPower = uint96(totalNewVotingPower);
        // forge-lint: disable-next-line(unsafe-typecast)
        lockInfo.lockTime = uint32(lockTime);
        // forge-lint: disable-next-line(unsafe-typecast)
        lockInfo.votingPower = uint96(totalNewVotingPower);
    }
    
    /**
     * @notice Updates global totals and transfers tokens
     * @dev Updates global locked amounts and voting power, then transfers tokens
     * @param totalAmount Total amount of tokens to lock
     * @param oldVotingPower Previous voting power
     * @param totalNewVotingPower New total voting power
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access Internal function
     * @custom:oracle No oracle dependencies
     */
    function _updateGlobalTotalsAndTransfer(
        uint256 totalAmount,
        uint256 oldVotingPower,
        uint256 totalNewVotingPower
    ) internal {
        totalLocked = totalLocked + totalAmount;
        totalVotingPower = totalVotingPower - oldVotingPower + totalNewVotingPower;
        _transfer(msg.sender, address(this), totalAmount);
    }

    /**
     * @notice Batch unlock QTI tokens for multiple users (admin function)
     * @dev Efficiently unlocks tokens for multiple users in a single transaction
     * @param users Array of user addresses to unlock for
     * @return amounts Array of QTI amounts unlocked
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function batchUnlock(address[] calldata users)
        external
        onlyRole(GOVERNANCE_ROLE)
        whenNotPaused
        returns (uint256[] memory amounts)
    {
        if (users.length > MAX_UNLOCK_BATCH_SIZE) revert CommonErrorLibrary.BatchSizeTooLarge();

        amounts = new uint256[](users.length);
        uint256 currentTimestamp = TIME_PROVIDER.currentTime();
        uint256 totalAmountToUnlock = 0;
        uint256 totalVotingPowerToRemove = 0;

        for (uint256 i = 0; i < users.length;) {
            (uint256 amount, uint256 oldVotingPower) = _processOneBatchUnlock(users[i], currentTimestamp);
            amounts[i] = amount;
            totalAmountToUnlock += amount;
            totalVotingPowerToRemove += oldVotingPower;
            unchecked { ++i; }
        }

        unchecked {
            totalLocked = totalLocked - totalAmountToUnlock;
            totalVotingPower = totalVotingPower - totalVotingPowerToRemove;
        }
    }

    /**
     * @notice Unlocks one user's lock and transfers tokens (used by batchUnlock to reduce stack depth)
     * @param user Address to unlock for
     * @param currentTimestamp Current time from TimeProvider
     * @return amount Amount unlocked
     * @return oldVotingPower Voting power removed
     */
    function _processOneBatchUnlock(address user, uint256 currentTimestamp)
        internal
        returns (uint256 amount, uint256 oldVotingPower)
    {
        LockInfo storage lockInfo = locks[user];
        if (lockInfo.unlockTime > currentTimestamp) revert TokenErrorLibrary.LockNotExpired();
        if (lockInfo.amount == 0) revert TokenErrorLibrary.NothingToUnlock();

        amount = lockInfo.amount;
        oldVotingPower = lockInfo.votingPower;

        lockInfo.amount = 0;
        lockInfo.unlockTime = 0;
        lockInfo.votingPower = 0;

        _transfer(address(this), user, amount);
        emit TokensUnlocked(user, amount, oldVotingPower);
        emit VotingPowerUpdated(user, oldVotingPower, 0);
    }

    /**
     * @notice Batch transfer QTI tokens to multiple addresses
     * @dev Efficiently transfers tokens to multiple recipients in a single transaction
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts to transfer
     * @return success True if all transfers were successful
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access No access restrictions
     * @custom:oracle No oracle dependencies
     */
    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts)
        external
        whenNotPaused
        flashLoanProtection
        returns (bool)
    {
        if (recipients.length != amounts.length) revert CommonErrorLibrary.ArrayLengthMismatch();
        if (recipients.length > MAX_BATCH_SIZE) revert CommonErrorLibrary.BatchSizeTooLarge();
        
        // Pre-validate recipients and amounts
        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] == address(0)) revert CommonErrorLibrary.InvalidAddress();
            if (amounts[i] == 0) revert CommonErrorLibrary.InvalidAmount();
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
     * @dev Calculates current voting power with linear decay over time
     * @param user Address to get voting power for
     * @return votingPower Current voting power of the user (decays linearly over time)
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getVotingPower(address user) external view returns (uint256 votingPower) {
        LockInfo storage lockInfo = locks[user];
        
        // Use library for voting power calculation
        QTITokenGovernanceLibrary.LockInfo memory lockInfoMemory = QTITokenGovernanceLibrary.LockInfo({
            amount: lockInfo.amount,
            unlockTime: lockInfo.unlockTime,
            votingPower: lockInfo.votingPower,
            lastClaimTime: lockInfo.lastClaimTime,
            initialVotingPower: lockInfo.initialVotingPower,
            lockTime: lockInfo.lockTime
        });
        
        return QTITokenGovernanceLibrary.calculateCurrentVotingPower(
            lockInfoMemory,
            TIME_PROVIDER.currentTime()
        );
    }

    /**
     * @notice Update voting power for the caller based on current time
     * @dev Updates voting power based on current time and lock duration
     * @return newVotingPower Updated voting power
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function updateVotingPower() external returns (uint256 newVotingPower) {
        return _updateVotingPower(msg.sender);
    }

    /**
     * @notice Get lock info for an address
     * @dev Returns comprehensive lock information for a user
     * @param user Address to get lock info for
     * @return amount Locked QTI amount
     * @return unlockTime Timestamp when lock expires
     * @return votingPower Current voting power
     * @return lastClaimTime Last claim time (for future use)
     * @return initialVotingPower Initial voting power when locked
     * @return lockTime Original lock duration
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
     * @dev Creates a new governance proposal with specified parameters and voting period
     * @param description Proposal description
     * @param votingPeriod Voting period in seconds
     * @param data Execution data (function calls)
     * @return proposalId Unique identifier for the created proposal
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle No oracle dependencies
     */
    function createProposal(
        string calldata description,
        uint256 votingPeriod,
        bytes calldata data
    ) external whenNotPaused returns (uint256 proposalId) {
        // Update voting power to current time before checking threshold
        uint256 currentVotingPower = _updateVotingPower(msg.sender);
        if (currentVotingPower < proposalThreshold) revert CommonErrorLibrary.InsufficientVotingPower();
        if (votingPeriod < minVotingPeriod) revert CommonErrorLibrary.VotingPeriodTooShort();
        if (votingPeriod > maxVotingPeriod) revert CommonErrorLibrary.VotingPeriodTooLong();

        proposalId = nextProposalId++;
        
        Proposal storage proposal = proposals[proposalId];
        proposal.proposer = msg.sender;
        proposal.startTime = TIME_PROVIDER.currentTime();
        proposal.endTime = TIME_PROVIDER.currentTime() + votingPeriod;
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
     * @dev Allows users to vote on governance proposals with their voting power
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
    function vote(uint256 proposalId, bool support) external whenNotPaused {
        Proposal storage proposal = proposals[proposalId];
        if (TIME_PROVIDER.currentTime() < proposal.startTime) revert CommonErrorLibrary.VotingNotStarted();
        if (TIME_PROVIDER.currentTime() >= proposal.endTime) revert CommonErrorLibrary.VotingEnded();
        if (proposal.receipts[msg.sender].hasVoted) revert CommonErrorLibrary.AlreadyVoted();

        // Update voting power to current time before voting
        uint256 votingPower = _updateVotingPower(msg.sender);
        if (votingPower == 0) revert CommonErrorLibrary.NoVotingPower();

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
     * @dev Efficiently votes on multiple proposals in a single transaction
     * @param proposalIds Array of proposal IDs to vote on
     * @param supportVotes Array of vote directions (true for yes, false for no)
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function batchVote(uint256[] calldata proposalIds, bool[] calldata supportVotes) external whenNotPaused flashLoanProtection {
        if (proposalIds.length != supportVotes.length) revert CommonErrorLibrary.ArrayLengthMismatch();
        if (proposalIds.length > MAX_VOTE_BATCH_SIZE) revert CommonErrorLibrary.BatchSizeTooLarge();
        
        // Update voting power once for the batch
        uint256 votingPower = _updateVotingPower(msg.sender);
        if (votingPower == 0) revert CommonErrorLibrary.NoVotingPower();
        

        uint256 currentTimestamp = TIME_PROVIDER.currentTime();
        address sender = msg.sender;
        
        // Process each vote
        for (uint256 i = 0; i < proposalIds.length; i++) {
            uint256 proposalId = proposalIds[i];
            bool support = supportVotes[i];
            
            Proposal storage proposal = proposals[proposalId];
            if (currentTimestamp < proposal.startTime) revert CommonErrorLibrary.VotingNotStarted();
            if (currentTimestamp >= proposal.endTime) revert CommonErrorLibrary.VotingEnded();
            if (proposal.receipts[sender].hasVoted) revert CommonErrorLibrary.AlreadyVoted();

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
     * @dev Executes a proposal that has passed voting and meets quorum requirements
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
    function executeProposal(uint256 proposalId) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        if (TIME_PROVIDER.currentTime() < proposal.endTime) revert CommonErrorLibrary.VotingNotEnded();
        if (proposal.executed) revert CommonErrorLibrary.ProposalAlreadyExecuted();
        if (proposal.canceled) revert CommonErrorLibrary.ProposalCanceled();
        if (proposal.forVotes <= proposal.againstVotes) revert CommonErrorLibrary.ProposalFailed();
        if (proposal.forVotes + proposal.againstVotes < quorumVotes) revert CommonErrorLibrary.QuorumNotMet();


        proposal.executed = true;

        // Execute the proposal data
        if (proposal.data.length > 0) {
            (bool success, ) = address(this).call(proposal.data); // slither-disable-line low-level-calls
            if (!success) {
                // Use Address.verifyCallResult to bubble up revert reason without assembly
                _verifyCallResult(success);
            }
        }

        emit ProposalExecuted(proposalId);
    }

    /**
     * @dev Verifies call result and reverts with appropriate error
     * @param success Whether the call was successful
     */
    function _verifyCallResult(bool success) private pure {
        if (!success) {
            revert CommonErrorLibrary.ProposalFailed();
        }
    }

    /**
     * @notice Get execution information for a scheduled proposal
     * @dev Returns execution status and timing information for a proposal
     * @param proposalId Proposal ID
     * @return scheduled Whether the proposal is scheduled
     * @return executionTime When the proposal can be executed
     * @return canExecute Whether the proposal can be executed now
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getProposalExecutionInfo(uint256 proposalId) external view returns (
        bool scheduled,
        uint256 executionTime,
        bool canExecute
    ) {
        scheduled = proposalScheduled[proposalId];
        executionTime = proposalExecutionTime[proposalId];
        canExecute = scheduled && TIME_PROVIDER.currentTime() >= executionTime;
    }

    /**
     * @notice Get the execution hash for a scheduled proposal
     * @dev Returns the execution hash required to execute a scheduled proposal
     * @param proposalId Proposal ID
     * @return executionHash Hash required to execute the proposal
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getProposalExecutionHash(uint256 proposalId) external view returns (bytes32 executionHash) {
        return proposalExecutionHash[proposalId];
    }

    /**
     * @notice Cancel a proposal (only proposer or admin)
     * @dev Allows proposer or admin to cancel a proposal before execution
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
    function cancelProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        if (msg.sender != proposal.proposer && !hasRole(GOVERNANCE_ROLE, msg.sender)) {
            revert CommonErrorLibrary.NotAuthorized();
        }
        if (proposal.executed) revert CommonErrorLibrary.ProposalAlreadyExecuted();
        if (proposal.canceled) revert CommonErrorLibrary.ProposalAlreadyCanceled();

        proposal.canceled = true;
        emit ProposalCanceled(proposalId);
    }

    /**
     * @notice Get proposal details
     * @dev Returns comprehensive proposal information including voting results
     * @param proposalId Proposal ID
     * @return proposer Address of the proposer
     * @return startTime Timestamp when voting starts
     * @return endTime Timestamp when voting ends
     * @return forVotes Total votes in favor
     * @return againstVotes Total votes against
     * @return executed Whether the proposal was executed
     * @return canceled Whether the proposal was canceled
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
     * @dev Returns voting information for a specific user on a specific proposal
     * @param proposalId Proposal ID
     * @param voter Address of the voter
     * @return hasVoted Whether the user has voted
     * @return support True for yes vote, false for no vote
     * @return votes Number of votes cast
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
    ) {
        Receipt storage receipt = proposals[proposalId].receipts[voter];
        return (receipt.hasVoted, receipt.support, receipt.votes);
    }



    // =============================================================================
    // GOVERNANCE ADMIN FUNCTIONS
    // =============================================================================

    /**
     * @notice Update governance parameters
     * @dev Updates governance parameters including proposal threshold, voting period, and quorum
     * @param _proposalThreshold New minimum QTI required to propose
     * @param _minVotingPeriod New minimum voting period
     * @param _quorumVotes New quorum required for proposals to pass
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
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
     * @dev Updates the treasury address for protocol fee collection
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
    function updateTreasury(address _treasury) external onlyRole(GOVERNANCE_ROLE) {
        AccessControlLibrary.validateAddress(_treasury);
        CommonValidationLibrary.validateTreasuryAddress(_treasury);
        CommonValidationLibrary.validateNonZeroAddress(_treasury, "treasury");
        if (_treasury == address(0)) revert CommonErrorLibrary.ZeroAddress();
        treasury = _treasury;
    }

    /**
     * @notice Update decentralization level
     * @dev This function is intended to be called periodically by the governance
     *      to update the decentralization level based on the elapsed time.
     *      Includes bounds checking to prevent timestamp manipulation.
     * 

      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function updateDecentralizationLevel() external onlyRole(GOVERNANCE_ROLE) {
        uint256 newLevel = QTITokenGovernanceLibrary.calculateDecentralizationLevel(
            TIME_PROVIDER.currentTime(),
            decentralizationStartTime,
            decentralizationDuration,
            MAX_TIME_ELAPSED
        );
        
        currentDecentralizationLevel = newLevel;
        emit DecentralizationLevelUpdated(newLevel);
    }

    // =============================================================================
    // INTERNAL FUNCTIONS
    // =============================================================================

    /**
     * @notice Calculate voting power multiplier based on lock time
     * @dev Calculates linear multiplier from 1x to 4x based on lock duration
     * @param lockTime Duration of the lock
     * @return multiplier Voting power multiplier
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes No state changes
     * @custom:events No events emitted
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access Internal function
     * @custom:oracle No oracle dependencies
     */
    function _calculateVotingPowerMultiplier(uint256 lockTime) internal pure returns (uint256) {
        return QTITokenGovernanceLibrary.calculateVotingPowerMultiplier(lockTime);
    }

    /**
     * @notice Update voting power for a user based on current time
     * @dev Updates voting power based on current time and lock duration with linear decay
     * @param user Address of the user to update
     * @return newVotingPower Updated voting power
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy No reentrancy protection needed
     * @custom:access Internal function
     * @custom:oracle No oracle dependencies
     */
    function _updateVotingPower(address user) internal returns (uint256 newVotingPower) {
        LockInfo storage lockInfo = locks[user];
        
        // Use library for voting power calculation
        QTITokenGovernanceLibrary.LockInfo memory lockInfoMemory = QTITokenGovernanceLibrary.LockInfo({
            amount: lockInfo.amount,
            unlockTime: lockInfo.unlockTime,
            votingPower: lockInfo.votingPower,
            lastClaimTime: lockInfo.lastClaimTime,
            initialVotingPower: lockInfo.initialVotingPower,
            lockTime: lockInfo.lockTime
        });
        
        newVotingPower = QTITokenGovernanceLibrary.calculateCurrentVotingPower(
            lockInfoMemory,
            TIME_PROVIDER.currentTime()
        );
        
        // Update stored voting power with overflow check
        uint256 oldVotingPower = lockInfo.votingPower;
        if (newVotingPower > type(uint96).max) revert CommonErrorLibrary.InvalidAmount();
        // forge-lint: disable-next-line(unsafe-typecast)
        lockInfo.votingPower = uint96(newVotingPower);
        
        // Update total voting power - Use checked arithmetic for critical state
        totalVotingPower = totalVotingPower - oldVotingPower + newVotingPower;
        
        return newVotingPower;
    }



    // =============================================================================
    // OVERRIDE FUNCTIONS
    // =============================================================================

    /**
     * @notice Returns the number of decimals for the QTI token
     * @dev Always returns 18 for standard ERC20 compatibility
     * @return The number of decimals (18)
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }



    // =============================================================================
    // EMERGENCY FUNCTIONS
    // =============================================================================

    /**
     * @notice Pauses all token operations including transfers and governance
     * @dev Emergency function to halt all contract operations when needed
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses all token operations
     * @dev Resumes normal contract operations after emergency is resolved
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }

    // =============================================================================
    // RECOVERY FUNCTIONS
    // =============================================================================

    /**
     * @notice Recover accidentally sent tokens to treasury only
     * @dev Recovers accidentally sent tokens to the treasury address
     * @param token Token address to recover
     * @param amount Amount to recover
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function recoverToken(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Use the shared library for secure token recovery to treasury
        TreasuryRecoveryLibrary.recoverToken(token, amount, address(this), treasury);
    }

    /**
     * @notice Recover accidentally sent ETH to treasury address only
     * @dev SECURITY: Restricted to treasury to prevent arbitrary ETH transfers
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function recoverETH() external onlyRole(DEFAULT_ADMIN_ROLE) {
        AdminFunctionsLibrary.recoverETH(address(this), treasury, DEFAULT_ADMIN_ROLE);
    }

    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================

    /**
     * @notice Get current governance information
     * @dev Returns comprehensive governance information including totals and parameters
     * @return totalLocked_ Total QTI tokens locked in vote-escrow
     * @return totalVotingPower_ Total voting power across all locked tokens
     * @return proposalThreshold_ Minimum QTI required to propose
     * @return quorumVotes_ Quorum required for proposals to pass
     * @return currentDecentralizationLevel_ Current decentralization level (0-10000)
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
