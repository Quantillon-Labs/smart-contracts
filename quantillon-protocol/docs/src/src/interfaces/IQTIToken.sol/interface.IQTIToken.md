# IQTIToken
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/872c40203709a592ab12a8276b4170d2d29fd99f/src/interfaces/IQTIToken.sol)

**Author:**
Quantillon Labs

Interface for the QTI governance token with vote-escrow mechanics

**Note:**
security-contact: team@quantillon.money


## Functions
### initialize

Initializes the QTI token


```solidity
function initialize(address admin, address _treasury, address timelock) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Admin address|
|`_treasury`|`address`|Treasury address|
|`timelock`|`address`|Timelock address|


### lock

Lock QTI tokens for voting power


```solidity
function lock(uint256 amount, uint256 lockTime) external returns (uint256 veQTI);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of QTI to lock|
|`lockTime`|`uint256`|Duration to lock|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`veQTI`|`uint256`|Voting power received|


### unlock

Unlock QTI tokens after lock period expires


```solidity
function unlock() external returns (uint256 amount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of QTI unlocked|


### batchLock

Batch lock QTI tokens for voting power


```solidity
function batchLock(uint256[] calldata amounts, uint256[] calldata lockTimes)
    external
    returns (uint256[] memory veQTIAmounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amounts`|`uint256[]`|Array of amounts to lock|
|`lockTimes`|`uint256[]`|Array of corresponding lock durations|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`veQTIAmounts`|`uint256[]`|Array of voting power received per lock|


### batchUnlock

Batch unlock QTI tokens for multiple users (admin/governance)


```solidity
function batchUnlock(address[] calldata users) external returns (uint256[] memory amounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`users`|`address[]`|Array of user addresses to unlock for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amounts`|`uint256[]`|Array of amounts unlocked per user|


### getVotingPower

Get voting power for an address


```solidity
function getVotingPower(address user) external view returns (uint256 votingPower);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`votingPower`|`uint256`|Current voting power|


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
|`user`|`address`|User address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Locked amount|
|`unlockTime`|`uint256`|Unlock timestamp|
|`votingPower`|`uint256`|Current voting power|
|`lastClaimTime`|`uint256`|Last claim time|
|`initialVotingPower`|`uint256`|Initial voting power when locked|
|`lockTime`|`uint256`|Original lock duration|


### createProposal

Create a new governance proposal


```solidity
function createProposal(string calldata description, uint256 votingPeriod, bytes calldata data)
    external
    returns (uint256 proposalId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`description`|`string`|Proposal description|
|`votingPeriod`|`uint256`|Voting period in seconds|
|`data`|`bytes`|Execution data|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`uint256`|New proposal ID|


### vote

Vote on a proposal


```solidity
function vote(uint256 proposalId, bool support) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`uint256`|Proposal ID|
|`support`|`bool`|True for yes, false for no|


### batchVote

Batch vote on multiple proposals


```solidity
function batchVote(uint256[] calldata proposalIds, bool[] calldata supportVotes) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalIds`|`uint256[]`|Array of proposal IDs|
|`supportVotes`|`bool[]`|Array of vote choices (true/false)|


### executeProposal

Execute a successful proposal


```solidity
function executeProposal(uint256 proposalId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`uint256`|Proposal ID|


### cancelProposal

Cancel a proposal


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
|`proposer`|`address`|Proposal creator|
|`startTime`|`uint256`|Voting start time|
|`endTime`|`uint256`|Voting end time|
|`forVotes`|`uint256`|Votes in favor|
|`againstVotes`|`uint256`|Votes against|
|`executed`|`bool`|Whether executed|
|`canceled`|`bool`|Whether canceled|
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
|`voter`|`address`|Voter address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`hasVoted`|`bool`|Whether user voted|
|`support`|`bool`|Vote direction|
|`votes`|`uint256`|Number of votes cast|


### updateGovernanceParameters

Update governance parameters


```solidity
function updateGovernanceParameters(uint256 _proposalThreshold, uint256 _minVotingPeriod, uint256 _quorumVotes)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_proposalThreshold`|`uint256`|New proposal threshold|
|`_minVotingPeriod`|`uint256`|New minimum voting period|
|`_quorumVotes`|`uint256`|New quorum requirement|


### updateTreasury

Update treasury address


```solidity
function updateTreasury(address _treasury) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_treasury`|`address`|New treasury address|


### updateDecentralizationLevel

Update decentralization level


```solidity
function updateDecentralizationLevel() external;
```

### pause

Pause the contract


```solidity
function pause() external;
```

### unpause

Unpause the contract


```solidity
function unpause() external;
```

### getGovernanceInfo

Get governance information


```solidity
function getGovernanceInfo()
    external
    view
    returns (
        uint256 _totalLocked,
        uint256 _totalVotingPower,
        uint256 _proposalThreshold,
        uint256 _quorumVotes,
        uint256 _currentDecentralizationLevel
    );
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_totalLocked`|`uint256`|Total locked QTI|
|`_totalVotingPower`|`uint256`|Total voting power|
|`_proposalThreshold`|`uint256`|Proposal threshold|
|`_quorumVotes`|`uint256`|Quorum requirement|
|`_currentDecentralizationLevel`|`uint256`|Current decentralization level|


### name


```solidity
function name() external view returns (string memory);
```

### symbol


```solidity
function symbol() external view returns (string memory);
```

### decimals


```solidity
function decimals() external view returns (uint8);
```

### totalSupply


```solidity
function totalSupply() external view returns (uint256);
```

### balanceOf


```solidity
function balanceOf(address account) external view returns (uint256);
```

### transfer


```solidity
function transfer(address to, uint256 amount) external returns (bool);
```

### allowance


```solidity
function allowance(address owner, address spender) external view returns (uint256);
```

### approve


```solidity
function approve(address spender, uint256 amount) external returns (bool);
```

### transferFrom


```solidity
function transferFrom(address from, address to, uint256 amount) external returns (bool);
```

### hasRole


```solidity
function hasRole(bytes32 role, address account) external view returns (bool);
```

### getRoleAdmin


```solidity
function getRoleAdmin(bytes32 role) external view returns (bytes32);
```

### grantRole


```solidity
function grantRole(bytes32 role, address account) external;
```

### revokeRole


```solidity
function revokeRole(bytes32 role, address account) external;
```

### renounceRole


```solidity
function renounceRole(bytes32 role, address callerConfirmation) external;
```

### paused


```solidity
function paused() external view returns (bool);
```

### upgradeTo


```solidity
function upgradeTo(address newImplementation) external;
```

### upgradeToAndCall


```solidity
function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
```

### GOVERNANCE_ROLE


```solidity
function GOVERNANCE_ROLE() external view returns (bytes32);
```

### EMERGENCY_ROLE


```solidity
function EMERGENCY_ROLE() external view returns (bytes32);
```

### UPGRADER_ROLE


```solidity
function UPGRADER_ROLE() external view returns (bytes32);
```

### MAX_LOCK_TIME


```solidity
function MAX_LOCK_TIME() external view returns (uint256);
```

### MIN_LOCK_TIME


```solidity
function MIN_LOCK_TIME() external view returns (uint256);
```

### WEEK


```solidity
function WEEK() external view returns (uint256);
```

### MAX_VE_QTI_MULTIPLIER


```solidity
function MAX_VE_QTI_MULTIPLIER() external view returns (uint256);
```

### MAX_TIME_ELAPSED


```solidity
function MAX_TIME_ELAPSED() external view returns (uint256);
```

### TOTAL_SUPPLY_CAP


```solidity
function TOTAL_SUPPLY_CAP() external view returns (uint256);
```

### locks


```solidity
function locks(address)
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

### totalLocked


```solidity
function totalLocked() external view returns (uint256);
```

### totalVotingPower


```solidity
function totalVotingPower() external view returns (uint256);
```

### proposals


```solidity
function proposals(uint256)
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

### nextProposalId


```solidity
function nextProposalId() external view returns (uint256);
```

### proposalThreshold


```solidity
function proposalThreshold() external view returns (uint256);
```

### minVotingPeriod


```solidity
function minVotingPeriod() external view returns (uint256);
```

### maxVotingPeriod


```solidity
function maxVotingPeriod() external view returns (uint256);
```

### quorumVotes


```solidity
function quorumVotes() external view returns (uint256);
```

### treasury


```solidity
function treasury() external view returns (address);
```

### decentralizationStartTime


```solidity
function decentralizationStartTime() external view returns (uint256);
```

### decentralizationDuration


```solidity
function decentralizationDuration() external view returns (uint256);
```

### currentDecentralizationLevel


```solidity
function currentDecentralizationLevel() external view returns (uint256);
```

### recoverToken


```solidity
function recoverToken(address token, address to, uint256 amount) external;
```

### recoverETH


```solidity
function recoverETH() external;
```

