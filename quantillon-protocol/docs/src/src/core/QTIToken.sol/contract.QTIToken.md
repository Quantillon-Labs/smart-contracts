# QTIToken
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/e9c5d3b52c0c2fb1a1c72e3e33cbf9fa6d077fa8/src/core/QTIToken.sol)

**Inherits:**
Initializable, ERC20Upgradeable, AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, [SecureUpgradeable](/src/core/SecureUpgradeable.sol/abstract.SecureUpgradeable.md)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Governance token for Quantillon Protocol with vote-escrow mechanics

*Main characteristics:
- Standard ERC20 with 18 decimals
- Vote-escrow (ve) mechanics for governance power
- Progressive decentralization through governance
- Emergency pause mechanism for crisis situations
- Upgradeable via UUPS pattern
- Fixed supply cap for tokenomics
- Governance proposal and voting system
- Lock-based voting power calculation*

*Vote-escrow mechanics:
- Users can lock QTI tokens for governance power
- Longer locks = higher voting power (up to 4x multiplier)
- Minimum lock: 7 days, Maximum lock: 4 years
- Voting power decreases linearly over time
- Locked tokens cannot be transferred until unlock*

*Governance features:
- Proposal creation with minimum threshold
- Voting period with configurable duration
- Vote counting and execution
- Proposal cancellation and emergency actions*

*Security features:
- Role-based access control for all critical operations
- Emergency pause mechanism for crisis situations
- Upgradeable architecture for future improvements
- Secure vote-escrow mechanics
- Proposal execution safeguards*

*Tokenomics:
- Total supply: 100,000,000 QTI (fixed cap)
- Initial distribution: Through protocol mechanisms
- Decimals: 18 (standard for ERC20 tokens)
- Governance power: Based on locked amount and duration*

**Note:**
team@quantillon.money


## State Variables
### GOVERNANCE_ROLE
Role for governance operations (proposal creation, execution)

*keccak256 hash avoids role collisions with other contracts*

*Should be assigned to governance multisig or DAO*


```solidity
bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
```


### EMERGENCY_ROLE
Role for emergency operations (pause, emergency proposals)

*keccak256 hash avoids role collisions with other contracts*

*Should be assigned to emergency multisig*


```solidity
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
```


### MAX_LOCK_TIME
Maximum lock time for QTI tokens

*Prevents extremely long locks that could impact governance*


```solidity
uint256 public constant MAX_LOCK_TIME = 365 days;
```


### MAX_BATCH_SIZE
Maximum batch size for lock operations to prevent DoS

*Prevents out-of-gas attacks through large arrays*


```solidity
uint256 public constant MAX_BATCH_SIZE = 100;
```


### MAX_UNLOCK_BATCH_SIZE
Maximum batch size for unlock operations to prevent DoS

*Prevents out-of-gas attacks through large user arrays*


```solidity
uint256 public constant MAX_UNLOCK_BATCH_SIZE = 50;
```


### MAX_VOTE_BATCH_SIZE
Maximum batch size for voting operations to prevent DoS

*Prevents out-of-gas attacks through large proposal arrays*


```solidity
uint256 public constant MAX_VOTE_BATCH_SIZE = 50;
```


### MIN_LOCK_TIME
Minimum lock time for vote-escrow (1 week)

*Prevents very short locks that could manipulate governance*

*Value: 7 days*


```solidity
uint256 public constant MIN_LOCK_TIME = 7 days;
```


### WEEK
Week duration in seconds (7 days)

*Used for time calculations and voting periods*

*Value: 7 days = 604,800 seconds*


```solidity
uint256 public constant WEEK = 7 days;
```


### MAX_VE_QTI_MULTIPLIER
Maximum voting power multiplier (4x)

*Maximum voting power a user can achieve through locking*

*Value: 4 (400% voting power for maximum lock)*


```solidity
uint256 public constant MAX_VE_QTI_MULTIPLIER = 4;
```


### MAX_TIME_ELAPSED
Maximum time elapsed for calculations to prevent manipulation

*Caps time-based calculations to prevent timestamp manipulation*


```solidity
uint256 public constant MAX_TIME_ELAPSED = 10 * 365 days;
```


### TOTAL_SUPPLY_CAP
Total supply cap (100 million QTI)

*Fixed supply cap for tokenomics*

*Value: 100,000,000 * 10^18 = 100,000,000 QTI*


```solidity
uint256 public constant TOTAL_SUPPLY_CAP = 100_000_000 * 1e18;
```


### locks
Vote-escrow locks per user address

*Maps user addresses to their lock information*

*Used to track locked tokens and voting power*


```solidity
mapping(address => LockInfo) public locks;
```


### totalLocked
Total QTI tokens locked in vote-escrow

*Sum of all locked amounts across all users*

*Used for protocol analytics and governance metrics*


```solidity
uint256 public totalLocked;
```


### totalVotingPower
Total voting power across all locked tokens

*Sum of all voting power across all users*

*Used for governance quorum calculations*


```solidity
uint256 public totalVotingPower;
```


### proposals
Governance proposals by proposal ID

*Maps proposal IDs to proposal data*

*Used to store and retrieve proposal information*


```solidity
mapping(uint256 => Proposal) public proposals;
```


### nextProposalId
Next proposal ID to be assigned

*Auto-incremented for each new proposal*

*Used to generate unique proposal identifiers*


```solidity
uint256 public nextProposalId;
```


### proposalThreshold
Minimum QTI required to create a governance proposal

*Prevents spam proposals and ensures serious governance participation*

*Can be updated by governance*


```solidity
uint256 public proposalThreshold;
```


### minVotingPeriod
Minimum voting period duration

*Ensures adequate time for community discussion and voting*

*Can be updated by governance*


```solidity
uint256 public minVotingPeriod;
```


### maxVotingPeriod
Maximum voting period duration

*Prevents excessively long voting periods*

*Can be updated by governance*


```solidity
uint256 public maxVotingPeriod;
```


### quorumVotes
Quorum required for proposal to pass

*Minimum number of votes needed for a proposal to be considered valid*

*Can be updated by governance*


```solidity
uint256 public quorumVotes;
```


### treasury
Treasury address for protocol fees

*Address where protocol fees are collected and distributed*

*Can be updated by governance*


```solidity
address public treasury;
```


### decentralizationStartTime
Progressive decentralization parameters

*Start time for the decentralization process*

*Duration of the decentralization process*

*Current level of decentralization (0-10000)*


```solidity
uint256 public decentralizationStartTime;
```


### decentralizationDuration

```solidity
uint256 public decentralizationDuration;
```


### currentDecentralizationLevel

```solidity
uint256 public currentDecentralizationLevel;
```


### proposalExecutionTime
Execution time for each proposal (with random delay)


```solidity
mapping(uint256 => uint256) public proposalExecutionTime;
```


### proposalExecutionHash
Execution hash for each proposal (for verification)


```solidity
mapping(uint256 => bytes32) public proposalExecutionHash;
```


### proposalScheduled
Whether a proposal has been scheduled for execution


```solidity
mapping(uint256 => bool) public proposalScheduled;
```


### TIME_PROVIDER
TimeProvider contract for centralized time management

*Used to replace direct block.timestamp usage for testability and consistency*


```solidity
TimeProvider public immutable TIME_PROVIDER;
```


## Functions
### flashLoanProtection

Modifier to protect against flash loan attacks

*Uses the FlashLoanProtectionLibrary to check QTI balance consistency*


```solidity
modifier flashLoanProtection();
```

### constructor

Constructor for QTI token contract

*Sets up the time provider and disables initializers for security*

**Notes:**
- Validates time provider address and disables initializers

- Validates input parameters and business logic constraints

- Sets immutable time provider and disables initializers

- No events emitted

- Throws custom errors for invalid conditions

- No reentrancy protection needed

- No access restrictions

- No oracle dependencies


```solidity
constructor(TimeProvider _TIME_PROVIDER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_TIME_PROVIDER`|`TimeProvider`|TimeProvider contract for centralized time management|


### initialize

Initializes the QTI token contract

*Sets up the governance token with initial configuration and assigns roles to admin*

**Notes:**
- Validates all input addresses and enforces security checks

- Validates input parameters and business logic constraints

- Initializes all contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to initializer modifier

- No oracle dependencies


```solidity
function initialize(address admin, address _treasury, address _timelock) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address that receives admin and governance roles|
|`_treasury`|`address`|Treasury address for protocol fees|
|`_timelock`|`address`|Timelock contract address for secure upgrades|


### lock

Locks QTI tokens for a specified duration to earn voting power (veQTI)

*Longer lock periods generate more voting power via time-weighted calculations*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function lock(uint256 amount, uint256 lockTime) external whenNotPaused flashLoanProtection returns (uint256 veQTI);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of QTI tokens to lock|
|`lockTime`|`uint256`|The duration to lock tokens (in seconds)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`veQTI`|`uint256`|The amount of voting power (veQTI) earned from this lock|


### unlock

Unlock QTI tokens after lock period expires

*Releases locked QTI tokens and removes voting power when lock period has expired*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function unlock() external whenNotPaused returns (uint256 amount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of QTI unlocked|


### batchLock

Batch lock QTI tokens for voting power for multiple amounts

*Efficiently locks multiple amounts with different lock times in a single transaction*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function batchLock(uint256[] calldata amounts, uint256[] calldata lockTimes)
    external
    whenNotPaused
    flashLoanProtection
    returns (uint256[] memory veQTIAmounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amounts`|`uint256[]`|Array of QTI amounts to lock|
|`lockTimes`|`uint256[]`|Array of lock durations (must be >= MIN_LOCK_TIME)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`veQTIAmounts`|`uint256[]`|Array of voting power calculated for each locked amount|


### _validateBatchLockInputs

Validates basic batch lock inputs

*Ensures array lengths match and batch size is within limits*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- No state changes

- No events emitted

- Throws custom errors for invalid conditions

- No reentrancy protection needed

- Internal function

- No oracle dependencies


```solidity
function _validateBatchLockInputs(uint256[] calldata amounts, uint256[] calldata lockTimes) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amounts`|`uint256[]`|Array of QTI amounts to lock|
|`lockTimes`|`uint256[]`|Array of lock durations|


### _validateAndCalculateTotalAmount

Validates all amounts and lock times, returns total amount

*Ensures all amounts and lock times are valid and calculates total amount*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- No state changes

- No events emitted

- Throws custom errors for invalid conditions

- No reentrancy protection needed

- Internal function

- No oracle dependencies


```solidity
function _validateAndCalculateTotalAmount(uint256[] calldata amounts, uint256[] calldata lockTimes)
    internal
    pure
    returns (uint256 totalAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amounts`|`uint256[]`|Array of QTI amounts to lock|
|`lockTimes`|`uint256[]`|Array of lock durations|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalAmount`|`uint256`|Total amount of QTI to be locked|


### _processBatchLocks

Processes all locks and calculates totals

*Processes batch lock operations and calculates total voting power and amounts*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- No reentrancy protection needed

- Internal function

- No oracle dependencies


```solidity
function _processBatchLocks(
    uint256[] calldata amounts,
    uint256[] calldata lockTimes,
    uint256[] memory veQTIAmounts,
    LockInfo storage lockInfo
) internal returns (uint256 totalNewVotingPower, uint256 totalNewAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amounts`|`uint256[]`|Array of QTI amounts to lock|
|`lockTimes`|`uint256[]`|Array of lock durations|
|`veQTIAmounts`|`uint256[]`|Array to store calculated voting power amounts|
|`lockInfo`|`LockInfo`|Storage reference to user's lock information|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalNewVotingPower`|`uint256`|Total new voting power from all locks|
|`totalNewAmount`|`uint256`|Total new amount locked|


### _calculateUnlockTime

Calculates unlock time with proper validation

*Calculates new unlock time based on current timestamp and lock duration*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- No state changes

- No events emitted

- Throws custom errors for invalid conditions

- No reentrancy protection needed

- Internal function

- No oracle dependencies


```solidity
function _calculateUnlockTime(uint256 currentTimestamp, uint256 lockTime, uint256 existingUnlockTime)
    internal
    pure
    returns (uint256 newUnlockTime);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currentTimestamp`|`uint256`|Current timestamp for calculation|
|`lockTime`|`uint256`|Duration to lock tokens|
|`existingUnlockTime`|`uint256`|Existing unlock time if already locked|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`newUnlockTime`|`uint256`|Calculated unlock time|


### _calculateVotingPower

Calculates voting power with overflow protection

*Calculates voting power based on amount and lock time with overflow protection*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- No state changes

- No events emitted

- Throws custom errors for invalid conditions

- No reentrancy protection needed

- Internal function

- No oracle dependencies


```solidity
function _calculateVotingPower(uint256 amount, uint256 lockTime) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of QTI tokens to lock|
|`lockTime`|`uint256`|Duration to lock tokens|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|votingPower Calculated voting power|


### _updateLockInfo

Updates lock info with overflow checks

*Updates user's lock information with new amounts and times*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- No events emitted

- Throws custom errors for invalid conditions

- No reentrancy protection needed

- Internal function

- No oracle dependencies


```solidity
function _updateLockInfo(
    LockInfo storage lockInfo,
    uint256 totalNewAmount,
    uint256 newUnlockTime,
    uint256 totalNewVotingPower,
    uint256 lockTime
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`lockInfo`|`LockInfo`|Storage reference to user's lock information|
|`totalNewAmount`|`uint256`|Total new amount to lock|
|`newUnlockTime`|`uint256`|New unlock time|
|`totalNewVotingPower`|`uint256`|Total new voting power|
|`lockTime`|`uint256`|Lock duration|


### _updateGlobalTotalsAndTransfer

Updates global totals and transfers tokens

*Updates global locked amounts and voting power, then transfers tokens*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- No reentrancy protection needed

- Internal function

- No oracle dependencies


```solidity
function _updateGlobalTotalsAndTransfer(uint256 totalAmount, uint256 oldVotingPower, uint256 totalNewVotingPower)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`totalAmount`|`uint256`|Total amount of tokens to lock|
|`oldVotingPower`|`uint256`|Previous voting power|
|`totalNewVotingPower`|`uint256`|New total voting power|


### batchUnlock

Batch unlock QTI tokens for multiple users (admin function)

*Efficiently unlocks tokens for multiple users in a single transaction*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to GOVERNANCE_ROLE

- No oracle dependencies


```solidity
function batchUnlock(address[] calldata users)
    external
    onlyRole(GOVERNANCE_ROLE)
    whenNotPaused
    returns (uint256[] memory amounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`users`|`address[]`|Array of user addresses to unlock for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amounts`|`uint256[]`|Array of QTI amounts unlocked|


### batchTransfer

Batch transfer QTI tokens to multiple addresses

*Efficiently transfers tokens to multiple recipients in a single transaction*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- No access restrictions

- No oracle dependencies


```solidity
function batchTransfer(address[] calldata recipients, uint256[] calldata amounts)
    external
    whenNotPaused
    flashLoanProtection
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipients`|`address[]`|Array of recipient addresses|
|`amounts`|`uint256[]`|Array of amounts to transfer|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|success True if all transfers were successful|


### getVotingPower

Get voting power for an address with linear decay

*Calculates current voting power with linear decay over time*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function getVotingPower(address user) external view returns (uint256 votingPower);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to get voting power for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`votingPower`|`uint256`|Current voting power of the user (decays linearly over time)|


### updateVotingPower

Update voting power for the caller based on current time

*Updates voting power based on current time and lock duration*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function updateVotingPower() external returns (uint256 newVotingPower);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`newVotingPower`|`uint256`|Updated voting power|


### getLockInfo

Get lock info for an address

*Returns comprehensive lock information for a user*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function getLockInfo(address user)
    external
    view
    returns (
        uint256 amount,
        uint256 unlockTime,
        uint256 votingPower,
        uint256 lastClaimTime,
        uint256 initialVotingPower,
        uint256 lockTime
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to get lock info for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Locked QTI amount|
|`unlockTime`|`uint256`|Timestamp when lock expires|
|`votingPower`|`uint256`|Current voting power|
|`lastClaimTime`|`uint256`|Last claim time (for future use)|
|`initialVotingPower`|`uint256`|Initial voting power when locked|
|`lockTime`|`uint256`|Original lock duration|


### createProposal

Create a new governance proposal

*Creates a new governance proposal with specified parameters and voting period*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- No oracle dependencies


```solidity
function createProposal(string calldata description, uint256 votingPeriod, bytes calldata data)
    external
    whenNotPaused
    returns (uint256 proposalId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`description`|`string`|Proposal description|
|`votingPeriod`|`uint256`|Voting period in seconds|
|`data`|`bytes`|Execution data (function calls)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`uint256`|Unique identifier for the created proposal|


### vote

Vote on a proposal

*Allows users to vote on governance proposals with their voting power*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function vote(uint256 proposalId, bool support) external whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`uint256`|Proposal ID|
|`support`|`bool`|True for yes, false for no|


### batchVote

Batch vote on multiple proposals

*Efficiently votes on multiple proposals in a single transaction*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function batchVote(uint256[] calldata proposalIds, bool[] calldata supportVotes)
    external
    whenNotPaused
    flashLoanProtection;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalIds`|`uint256[]`|Array of proposal IDs to vote on|
|`supportVotes`|`bool[]`|Array of vote directions (true for yes, false for no)|


### executeProposal

Execute a successful proposal

*Executes a proposal that has passed voting and meets quorum requirements*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function executeProposal(uint256 proposalId) external nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`uint256`|Proposal ID|


### _verifyCallResult

*Verifies call result and reverts with appropriate error*


```solidity
function _verifyCallResult(bool success) private pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`success`|`bool`|Whether the call was successful|


### getProposalExecutionInfo

Get execution information for a scheduled proposal

*Returns execution status and timing information for a proposal*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function getProposalExecutionInfo(uint256 proposalId)
    external
    view
    returns (bool scheduled, uint256 executionTime, bool canExecute);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`uint256`|Proposal ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`scheduled`|`bool`|Whether the proposal is scheduled|
|`executionTime`|`uint256`|When the proposal can be executed|
|`canExecute`|`bool`|Whether the proposal can be executed now|


### getProposalExecutionHash

Get the execution hash for a scheduled proposal

*Returns the execution hash required to execute a scheduled proposal*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function getProposalExecutionHash(uint256 proposalId) external view returns (bytes32 executionHash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`uint256`|Proposal ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`executionHash`|`bytes32`|Hash required to execute the proposal|


### cancelProposal

Cancel a proposal (only proposer or admin)

*Allows proposer or admin to cancel a proposal before execution*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function cancelProposal(uint256 proposalId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`uint256`|Proposal ID|


### getProposal

Get proposal details

*Returns comprehensive proposal information including voting results*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function getProposal(uint256 proposalId)
    external
    view
    returns (
        address proposer,
        uint256 startTime,
        uint256 endTime,
        uint256 forVotes,
        uint256 againstVotes,
        bool executed,
        bool canceled,
        string memory description
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`uint256`|Proposal ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`proposer`|`address`|Address of the proposer|
|`startTime`|`uint256`|Timestamp when voting starts|
|`endTime`|`uint256`|Timestamp when voting ends|
|`forVotes`|`uint256`|Total votes in favor|
|`againstVotes`|`uint256`|Total votes against|
|`executed`|`bool`|Whether the proposal was executed|
|`canceled`|`bool`|Whether the proposal was canceled|
|`description`|`string`|Proposal description|


### getReceipt

Get voting receipt for a user

*Returns voting information for a specific user on a specific proposal*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function getReceipt(uint256 proposalId, address voter)
    external
    view
    returns (bool hasVoted, bool support, uint256 votes);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`uint256`|Proposal ID|
|`voter`|`address`|Address of the voter|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`hasVoted`|`bool`|Whether the user has voted|
|`support`|`bool`|True for yes vote, false for no vote|
|`votes`|`uint256`|Number of votes cast|


### updateGovernanceParameters

Update governance parameters

*Updates governance parameters including proposal threshold, voting period, and quorum*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to GOVERNANCE_ROLE

- No oracle dependencies


```solidity
function updateGovernanceParameters(uint256 _proposalThreshold, uint256 _minVotingPeriod, uint256 _quorumVotes)
    external
    onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_proposalThreshold`|`uint256`|New minimum QTI required to propose|
|`_minVotingPeriod`|`uint256`|New minimum voting period|
|`_quorumVotes`|`uint256`|New quorum required for proposals to pass|


### updateTreasury

Update treasury address

*Updates the treasury address for protocol fee collection*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function updateTreasury(address _treasury) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_treasury`|`address`|New treasury address|


### updateDecentralizationLevel

Update decentralization level

*This function is intended to be called periodically by the governance
to update the decentralization level based on the elapsed time.
Includes bounds checking to prevent timestamp manipulation.*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function updateDecentralizationLevel() external onlyRole(GOVERNANCE_ROLE);
```

### _calculateVotingPowerMultiplier

Calculate voting power multiplier based on lock time

*Calculates linear multiplier from 1x to 4x based on lock duration*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- No state changes

- No events emitted

- Throws custom errors for invalid conditions

- No reentrancy protection needed

- Internal function

- No oracle dependencies


```solidity
function _calculateVotingPowerMultiplier(uint256 lockTime) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`lockTime`|`uint256`|Duration of the lock|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|multiplier Voting power multiplier|


### _updateVotingPower

Update voting power for a user based on current time

*Updates voting power based on current time and lock duration with linear decay*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- No reentrancy protection needed

- Internal function

- No oracle dependencies


```solidity
function _updateVotingPower(address user) internal returns (uint256 newVotingPower);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user to update|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`newVotingPower`|`uint256`|Updated voting power|


### decimals

Returns the number of decimals for the QTI token

*Always returns 18 for standard ERC20 compatibility*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function decimals() public pure override returns (uint8);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|The number of decimals (18)|


### pause

Pauses all token operations including transfers and governance

*Emergency function to halt all contract operations when needed*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function pause() external onlyRole(EMERGENCY_ROLE);
```

### unpause

Unpauses all token operations

*Resumes normal contract operations after emergency is resolved*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function unpause() external onlyRole(EMERGENCY_ROLE);
```

### recoverToken

Recover accidentally sent tokens to treasury only

*Recovers accidentally sent tokens to the treasury address*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function recoverToken(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address to recover|
|`amount`|`uint256`|Amount to recover|


### recoverETH

Recover accidentally sent ETH to treasury address only

*SECURITY: Restricted to treasury to prevent arbitrary ETH transfers*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function recoverETH() external onlyRole(DEFAULT_ADMIN_ROLE);
```

### getGovernanceInfo

Get current governance information

*Returns comprehensive governance information including totals and parameters*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function getGovernanceInfo()
    external
    view
    returns (
        uint256 totalLocked_,
        uint256 totalVotingPower_,
        uint256 proposalThreshold_,
        uint256 quorumVotes_,
        uint256 currentDecentralizationLevel_
    );
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalLocked_`|`uint256`|Total QTI tokens locked in vote-escrow|
|`totalVotingPower_`|`uint256`|Total voting power across all locked tokens|
|`proposalThreshold_`|`uint256`|Minimum QTI required to propose|
|`quorumVotes_`|`uint256`|Quorum required for proposals to pass|
|`currentDecentralizationLevel_`|`uint256`|Current decentralization level (0-10000)|


## Events
### TokensLocked
Emitted when tokens are locked for voting power

*OPTIMIZED: Indexed amount and unlockTime for efficient filtering*


```solidity
event TokensLocked(address indexed user, uint256 indexed amount, uint256 indexed unlockTime, uint256 votingPower);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user who locked tokens|
|`amount`|`uint256`|Amount of QTI locked|
|`unlockTime`|`uint256`|Timestamp when the lock expires|
|`votingPower`|`uint256`|Voting power calculated for the locked amount|

### TokensUnlocked
Emitted when tokens are unlocked after lock period expires

*OPTIMIZED: Indexed amount for efficient filtering by unlock size*


```solidity
event TokensUnlocked(address indexed user, uint256 indexed amount, uint256 votingPower);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user who unlocked tokens|
|`amount`|`uint256`|Amount of QTI unlocked|
|`votingPower`|`uint256`|Voting power before unlocking|

### VotingPowerUpdated
Emitted when voting power for an address is updated


```solidity
event VotingPowerUpdated(address indexed user, uint256 oldPower, uint256 newPower);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user whose voting power changed|
|`oldPower`|`uint256`|Previous voting power|
|`newPower`|`uint256`|New voting power|

### ProposalCreated
Emitted when a new governance proposal is created


```solidity
event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`uint256`|Unique identifier for the proposal|
|`proposer`|`address`|Address of the proposer|
|`description`|`string`|Description of the proposal|

### Voted
Emitted when a user votes on a proposal

*OPTIMIZED: Indexed support for efficient filtering by vote direction*


```solidity
event Voted(uint256 indexed proposalId, address indexed voter, bool indexed support, uint256 votes);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`uint256`|Unique identifier for the proposal|
|`voter`|`address`|Address of the voter|
|`support`|`bool`|True for yes vote, false for no vote|
|`votes`|`uint256`|Number of votes cast|

### ProposalExecuted
Emitted when a proposal is successfully executed


```solidity
event ProposalExecuted(uint256 indexed proposalId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`uint256`|Unique identifier for the executed proposal|

### ProposalCanceled
Emitted when a proposal is canceled


```solidity
event ProposalCanceled(uint256 indexed proposalId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`uint256`|Unique identifier for the canceled proposal|

### GovernanceParametersUpdated
Emitted when governance parameters are updated

*OPTIMIZED: Indexed parameter type for efficient filtering*


```solidity
event GovernanceParametersUpdated(
    string indexed parameterType, uint256 proposalThreshold, uint256 minVotingPeriod, uint256 quorumVotes
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`parameterType`|`string`||
|`proposalThreshold`|`uint256`|New minimum QTI required to propose|
|`minVotingPeriod`|`uint256`|New minimum voting period|
|`quorumVotes`|`uint256`|New quorum required for proposals to pass|

### DecentralizationLevelUpdated
Emitted when the decentralization level is updated

*OPTIMIZED: Indexed level for efficient filtering by decentralization stage*


```solidity
event DecentralizationLevelUpdated(uint256 indexed newLevel);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newLevel`|`uint256`|New decentralization level (0-10000)|

### ETHRecovered
Emitted when ETH is recovered from the contract


```solidity
event ETHRecovered(address indexed to, uint256 indexed amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Recipient address|
|`amount`|`uint256`|Amount of ETH recovered|

## Structs
### LockInfo
Vote-escrow lock information for each user

*Stores locked amount, unlock time, voting power, and claim time*

*Used to calculate governance power and manage locks*

*OPTIMIZED: Fields ordered for optimal storage packing*


```solidity
struct LockInfo {
    uint96 amount;
    uint96 votingPower;
    uint96 initialVotingPower;
    uint32 unlockTime;
    uint32 lastClaimTime;
    uint32 lockTime;
}
```

### Proposal
Governance proposal structure

*Stores all proposal data including voting results and execution info*

*Used for governance decision making*


```solidity
struct Proposal {
    address proposer;
    uint256 startTime;
    uint256 endTime;
    uint256 forVotes;
    uint256 againstVotes;
    bool executed;
    bool canceled;
    string description;
    bytes data;
    mapping(address => Receipt) receipts;
}
```

### Receipt
Voting receipt for each voter in a proposal

*Stores individual voting information for each user*

*Used to prevent double voting and track individual votes*


```solidity
struct Receipt {
    bool hasVoted;
    bool support;
    uint256 votes;
}
```

