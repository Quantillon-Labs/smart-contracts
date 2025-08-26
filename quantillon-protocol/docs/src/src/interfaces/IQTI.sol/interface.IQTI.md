# IQTI
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/c5a08452eb568457f0f8b1c726e5ba978b846461/src/interfaces/IQTI.sol)

**Author:**
Quantillon Labs

Interface for the QTI governance token with vote-escrow mechanics

**Note:**
security-contact: team@quantillon.money


## Functions
### initialize

Initializes the QTI token


```solidity
function initialize(address admin, address _treasury) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Admin address|
|`_treasury`|`address`|Treasury address|


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
        uint256 totalLocked,
        uint256 totalVotingPower,
        uint256 proposalThreshold,
        uint256 quorumVotes,
        uint256 currentDecentralizationLevel
    );
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalLocked`|`uint256`|Total locked QTI|
|`totalVotingPower`|`uint256`|Total voting power|
|`proposalThreshold`|`uint256`|Proposal threshold|
|`quorumVotes`|`uint256`|Quorum requirement|
|`currentDecentralizationLevel`|`uint256`|Current decentralization level|


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

