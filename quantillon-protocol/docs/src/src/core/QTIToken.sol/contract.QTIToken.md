# QTIToken
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/d412a0619acefb191468f4973a48348275c68bd9/src/core/QTIToken.sol)

**Inherits:**
Initializable, ERC20Upgradeable, AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, [SecureUpgradeable](/src/core/SecureUpgradeable.sol/abstract.SecureUpgradeable.md)

**Author:**
Quantillon Labs

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
Maximum lock time for vote-escrow (4 years)

*Prevents infinite locks and ensures token circulation*

*Value: 4 * 365 days = 1,460 days*


```solidity
uint256 public constant MAX_LOCK_TIME = 4 * 365 days;
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


## Functions
### flashLoanProtection

Modifier to protect against flash loan attacks

*Checks that the contract's QTI balance doesn't decrease during execution*

*This prevents flash loans that would drain QTI from the contract*


```solidity
modifier flashLoanProtection();
```

### constructor


```solidity
constructor();
```

### initialize


```solidity
function initialize(address admin, address _treasury, address timelock) public initializer;
```

### lock

Lock QTI tokens for voting power


```solidity
function lock(uint256 amount, uint256 lockTime) external whenNotPaused flashLoanProtection returns (uint256 veQTI);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of QTI to lock|
|`lockTime`|`uint256`|Duration to lock (must be >= MIN_LOCK_TIME)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`veQTI`|`uint256`|Voting power calculated for the locked amount|


### unlock

Unlock QTI tokens after lock period expires


```solidity
function unlock() external whenNotPaused returns (uint256 amount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of QTI unlocked|


### batchLock

Batch lock QTI tokens for voting power for multiple amounts


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


### batchUnlock

Batch unlock QTI tokens for multiple users (admin function)


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


### getVotingPower

Get voting power for an address with linear decay


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


```solidity
function updateVotingPower() external returns (uint256 newVotingPower);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`newVotingPower`|`uint256`|Updated voting power|


### getLockInfo

Get lock info for an address


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


```solidity
function executeProposal(uint256 proposalId) external nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`uint256`|Proposal ID|


### getProposalExecutionInfo

Get execution information for a scheduled proposal


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


```solidity
function cancelProposal(uint256 proposalId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`uint256`|Proposal ID|


### getProposal

Get proposal details


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


```solidity
function updateDecentralizationLevel() external onlyRole(GOVERNANCE_ROLE);
```

### _calculateVotingPowerMultiplier

Calculate voting power multiplier based on lock time


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


```solidity
function decimals() public pure override returns (uint8);
```

### pause


```solidity
function pause() external onlyRole(EMERGENCY_ROLE);
```

### unpause


```solidity
function unpause() external onlyRole(EMERGENCY_ROLE);
```

### recoverToken

Recover accidentally sent tokens to treasury only


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


```solidity
function recoverETH(address payable to) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address payable`|Treasury address (must match the contract's treasury)|


### getGovernanceInfo

Get current governance information


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

