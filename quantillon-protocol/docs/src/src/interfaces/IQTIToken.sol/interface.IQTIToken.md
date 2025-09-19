# IQTIToken
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/91f7ed3e8a496e9d369dc182e8f549ec75449a6b/src/interfaces/IQTIToken.sol)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Interface for the QTI governance token with vote-escrow mechanics

**Note:**
security-contact: team@quantillon.money


## Functions
### initialize

Initializes the QTI token

*Sets up initial roles and configuration for the governance token*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

*Locks QTI tokens for a specified duration to receive voting power*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function lock(uint256 amount, uint256 lockTime) external returns (uint256 veQTI);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of QTI to lock (18 decimals)|
|`lockTime`|`uint256`|Duration to lock (seconds)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`veQTI`|`uint256`|Voting power received (18 decimals)|


### unlock

Unlock QTI tokens after lock period expires

*Unlocks all expired QTI tokens and returns them to the caller*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function unlock() external returns (uint256 amount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of QTI unlocked (18 decimals)|


### batchLock

Batch lock QTI tokens for voting power

*Locks multiple amounts of QTI tokens with different lock durations*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function batchLock(uint256[] calldata amounts, uint256[] calldata lockTimes)
    external
    returns (uint256[] memory veQTIAmounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amounts`|`uint256[]`|Array of amounts to lock (18 decimals each)|
|`lockTimes`|`uint256[]`|Array of corresponding lock durations (seconds each)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`veQTIAmounts`|`uint256[]`|Array of voting power received per lock (18 decimals each)|


### batchUnlock

Batch unlock QTI tokens for multiple users (admin/governance)

*Unlocks expired QTI tokens for multiple users in a single transaction*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
|`amounts`|`uint256[]`|Array of amounts unlocked per user (18 decimals each)|


### getVotingPower

Get voting power for an address

*Returns the current voting power for a user based on their locked tokens*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
|`votingPower`|`uint256`|Current voting power (18 decimals)|


### updateVotingPower

Update voting power for the caller based on current time

*Recalculates and updates voting power based on time decay*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function updateVotingPower() external returns (uint256 newVotingPower);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`newVotingPower`|`uint256`|Updated voting power (18 decimals)|


### getLockInfo

Get lock info for an address

*Returns comprehensive lock information for a user*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
|`amount`|`uint256`|Locked amount (18 decimals)|
|`unlockTime`|`uint256`|Unlock timestamp|
|`votingPower`|`uint256`|Current voting power (18 decimals)|
|`lastClaimTime`|`uint256`|Last claim time|
|`initialVotingPower`|`uint256`|Initial voting power when locked (18 decimals)|
|`lockTime`|`uint256`|Original lock duration (seconds)|


### createProposal

Create a new governance proposal

*Creates a new governance proposal with specified parameters*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

*Casts a vote on a governance proposal*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

*Casts votes on multiple governance proposals in a single transaction*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

*Executes a proposal that has passed voting requirements*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function executeProposal(uint256 proposalId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`uint256`|Proposal ID|


### cancelProposal

Cancel a proposal

*Cancels a proposal before execution*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function cancelProposal(uint256 proposalId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`uint256`|Proposal ID|


### getProposal

Get proposal details

*Returns comprehensive information about a governance proposal*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
|`forVotes`|`uint256`|Votes in favor (18 decimals)|
|`againstVotes`|`uint256`|Votes against (18 decimals)|
|`executed`|`bool`|Whether executed|
|`canceled`|`bool`|Whether canceled|
|`description`|`string`|Proposal description|


### getReceipt

Get voting receipt for a user

*Returns voting information for a specific user and proposal*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
|`votes`|`uint256`|Number of votes cast (18 decimals)|


### updateGovernanceParameters

Update governance parameters

*Updates key governance parameters for the protocol*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function updateGovernanceParameters(uint256 _proposalThreshold, uint256 _minVotingPeriod, uint256 _quorumVotes)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_proposalThreshold`|`uint256`|New proposal threshold (18 decimals)|
|`_minVotingPeriod`|`uint256`|New minimum voting period (seconds)|
|`_quorumVotes`|`uint256`|New quorum requirement (18 decimals)|


### updateTreasury

Update treasury address

*Updates the treasury address for protocol fees and rewards*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function updateTreasury(address _treasury) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_treasury`|`address`|New treasury address|


### updateDecentralizationLevel

Update decentralization level

*Updates the decentralization level based on current protocol state*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function updateDecentralizationLevel() external;
```

### pause

Pause the contract

*Pauses all contract operations for emergency situations*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function pause() external;
```

### unpause

Unpause the contract

*Resumes all contract operations after emergency pause*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function unpause() external;
```

### getGovernanceInfo

Get governance information

*Returns comprehensive governance information in a single call*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
|`_totalLocked`|`uint256`|Total locked QTI (18 decimals)|
|`_totalVotingPower`|`uint256`|Total voting power (18 decimals)|
|`_proposalThreshold`|`uint256`|Proposal threshold (18 decimals)|
|`_quorumVotes`|`uint256`|Quorum requirement (18 decimals)|
|`_currentDecentralizationLevel`|`uint256`|Current decentralization level|


### name

Get the token name

*Returns the name of the QTI token*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function name() external view returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|name The token name string|


### symbol

Get the token symbol

*Returns the symbol of the QTI token*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function symbol() external view returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|symbol The token symbol string|


### decimals

Get the token decimals

*Returns the number of decimals used by the token*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function decimals() external view returns (uint8);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|decimals The number of decimals (always 18)|


### totalSupply

Get the total token supply

*Returns the total supply of QTI tokens*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function totalSupply() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|totalSupply The total supply (18 decimals)|


### balanceOf

Get the balance of an account

*Returns the token balance of the specified account*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function balanceOf(address account) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|balance The token balance (18 decimals)|


### transfer

Transfer QTI tokens to another address

*Standard ERC20 transfer function*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function transfer(address to, uint256 amount) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Address to transfer tokens to|
|`amount`|`uint256`|Amount of tokens to transfer (18 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|success True if transfer was successful|


### allowance

Get the allowance for a spender

*Returns the amount of tokens that a spender is allowed to transfer*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function allowance(address owner, address spender) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|Address of the token owner|
|`spender`|`address`|Address of the spender|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|allowance Amount of tokens the spender can transfer (18 decimals)|


### approve

Approve a spender to transfer tokens

*Sets the allowance for a spender to transfer tokens on behalf of the caller*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function approve(address spender, uint256 amount) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`spender`|`address`|Address of the spender to approve|
|`amount`|`uint256`|Amount of tokens to approve (18 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|success True if approval was successful|


### transferFrom

Transfer tokens from one address to another

*Standard ERC20 transferFrom function*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function transferFrom(address from, address to, uint256 amount) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Address to transfer tokens from|
|`to`|`address`|Address to transfer tokens to|
|`amount`|`uint256`|Amount of tokens to transfer (18 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|success True if transfer was successful|


### hasRole

Check if an account has a specific role

*Returns true if the account has the specified role*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can check roles

- oracle: No oracle dependencies


```solidity
function hasRole(bytes32 role, address account) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to check|
|`account`|`address`|The account to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if account has the role, false otherwise|


### getRoleAdmin

Get the admin role for a specific role

*Returns the admin role that can grant/revoke the specified role*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query role admin

- oracle: No oracle dependencies


```solidity
function getRoleAdmin(bytes32 role) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to get admin for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|bytes32 The admin role|


### grantRole

Grant a role to an account

*Grants the specified role to the account*

**Notes:**
- security: Validates caller has admin role for the specified role

- validation: Validates account is not address(0)

- state-changes: Grants role to account

- events: Emits RoleGranted event

- errors: Throws AccessControlUnauthorizedAccount if caller lacks admin role

- reentrancy: Not protected - no external calls

- access: Restricted to role admin

- oracle: No oracle dependencies


```solidity
function grantRole(bytes32 role, address account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to grant|
|`account`|`address`|The account to grant the role to|


### revokeRole

Revoke a role from an account

*Revokes the specified role from the account*

**Notes:**
- security: Validates caller has admin role for the specified role

- validation: Validates account is not address(0)

- state-changes: Revokes role from account

- events: Emits RoleRevoked event

- errors: Throws AccessControlUnauthorizedAccount if caller lacks admin role

- reentrancy: Not protected - no external calls

- access: Restricted to role admin

- oracle: No oracle dependencies


```solidity
function revokeRole(bytes32 role, address account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to revoke|
|`account`|`address`|The account to revoke the role from|


### renounceRole

Renounce a role

*Allows an account to renounce their own role*

**Notes:**
- security: Validates caller is renouncing their own role

- validation: Validates callerConfirmation matches msg.sender

- state-changes: Revokes role from caller

- events: Emits RoleRevoked event

- errors: Throws AccessControlBadConfirmation if callerConfirmation != msg.sender

- reentrancy: Not protected - no external calls

- access: Public - anyone can renounce their own roles

- oracle: No oracle dependencies


```solidity
function renounceRole(bytes32 role, address callerConfirmation) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to renounce|
|`callerConfirmation`|`address`|The caller's address for confirmation|


### paused

Check if the contract is paused

*Returns true if the contract is currently paused*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can check pause status

- oracle: No oracle dependencies


```solidity
function paused() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if paused, false if not paused|


### upgradeTo

Upgrade the contract implementation

*Upgrades the contract to a new implementation*

**Notes:**
- security: Validates caller has UPGRADER_ROLE

- validation: Validates newImplementation is not address(0)

- state-changes: Updates implementation address

- events: Emits Upgraded event

- errors: Throws AccessControlUnauthorizedAccount if caller lacks UPGRADER_ROLE

- reentrancy: Not protected - no external calls

- access: Restricted to UPGRADER_ROLE

- oracle: No oracle dependencies


```solidity
function upgradeTo(address newImplementation) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|


### upgradeToAndCall

Upgrade the contract implementation with initialization

*Upgrades the contract to a new implementation and calls initialization function*

**Notes:**
- security: Validates caller has UPGRADER_ROLE

- validation: Validates newImplementation is not address(0)

- state-changes: Updates implementation address and calls initialization

- events: Emits Upgraded event

- errors: Throws AccessControlUnauthorizedAccount if caller lacks UPGRADER_ROLE

- reentrancy: Not protected - no external calls

- access: Restricted to UPGRADER_ROLE

- oracle: No oracle dependencies


```solidity
function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|
|`data`|`bytes`|Initialization data to call on new implementation|


### GOVERNANCE_ROLE

Returns the governance role identifier

*Role required for governance operations*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query governance role

- oracle: No oracle dependencies


```solidity
function GOVERNANCE_ROLE() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|bytes32 The governance role identifier|


### EMERGENCY_ROLE

Returns the emergency role identifier

*Role required for emergency operations*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query emergency role

- oracle: No oracle dependencies


```solidity
function EMERGENCY_ROLE() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|bytes32 The emergency role identifier|


### UPGRADER_ROLE

Returns the upgrader role identifier

*Role required for contract upgrades*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query upgrader role

- oracle: No oracle dependencies


```solidity
function UPGRADER_ROLE() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|bytes32 The upgrader role identifier|


### MAX_LOCK_TIME

Returns the maximum lock time

*Maximum duration tokens can be locked for (seconds)*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query maximum lock time

- oracle: No oracle dependencies


```solidity
function MAX_LOCK_TIME() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Maximum lock time in seconds|


### MIN_LOCK_TIME

Returns the minimum lock time

*Minimum duration tokens must be locked for (seconds)*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query minimum lock time

- oracle: No oracle dependencies


```solidity
function MIN_LOCK_TIME() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Minimum lock time in seconds|


### WEEK

Returns the week duration

*Duration of one week in seconds*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query week duration

- oracle: No oracle dependencies


```solidity
function WEEK() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Week duration in seconds|


### MAX_VE_QTI_MULTIPLIER

Returns the maximum veQTI multiplier

*Maximum voting power multiplier for locked tokens*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query maximum veQTI multiplier

- oracle: No oracle dependencies


```solidity
function MAX_VE_QTI_MULTIPLIER() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Maximum veQTI multiplier|


### MAX_TIME_ELAPSED

Returns the maximum time elapsed

*Maximum time that can elapse for calculations*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query maximum time elapsed

- oracle: No oracle dependencies


```solidity
function MAX_TIME_ELAPSED() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Maximum time elapsed in seconds|


### TOTAL_SUPPLY_CAP

Returns the total supply cap

*Maximum total supply of QTI tokens (18 decimals)*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query total supply cap

- oracle: No oracle dependencies


```solidity
function TOTAL_SUPPLY_CAP() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Total supply cap in QTI tokens|


### locks

Returns lock information for an address

*Returns comprehensive lock information for a user*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query lock information

- oracle: No oracle dependencies


```solidity
function locks(address user)
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
|`user`|`address`|Address of the user to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Locked amount (18 decimals)|
|`unlockTime`|`uint256`|Unlock timestamp|
|`votingPower`|`uint256`|Current voting power (18 decimals)|
|`lastClaimTime`|`uint256`|Last claim time|
|`initialVotingPower`|`uint256`|Initial voting power when locked (18 decimals)|
|`lockTime`|`uint256`|Original lock duration (seconds)|


### totalLocked

Returns total locked QTI tokens

*Total amount of QTI tokens locked across all users (18 decimals)*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query total locked

- oracle: No oracle dependencies


```solidity
function totalLocked() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Total locked QTI tokens|


### totalVotingPower

Returns total voting power

*Total voting power across all locked tokens (18 decimals)*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query total voting power

- oracle: No oracle dependencies


```solidity
function totalVotingPower() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Total voting power|


### proposals

Returns proposal information by ID

*Returns comprehensive proposal information*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query proposal information

- oracle: No oracle dependencies


```solidity
function proposals(uint256 proposalId)
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
|`proposalId`|`uint256`|ID of the proposal to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`proposer`|`address`|Proposal creator address|
|`startTime`|`uint256`|Voting start timestamp|
|`endTime`|`uint256`|Voting end timestamp|
|`forVotes`|`uint256`|Votes in favor (18 decimals)|
|`againstVotes`|`uint256`|Votes against (18 decimals)|
|`executed`|`bool`|Whether proposal was executed|
|`canceled`|`bool`|Whether proposal was canceled|
|`description`|`string`|Proposal description|


### nextProposalId

Returns the next proposal ID

*Counter for generating unique proposal IDs*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query next proposal ID

- oracle: No oracle dependencies


```solidity
function nextProposalId() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Next proposal ID|


### proposalThreshold

Returns the proposal threshold

*Minimum voting power required to create proposals (18 decimals)*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query proposal threshold

- oracle: No oracle dependencies


```solidity
function proposalThreshold() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Proposal threshold in QTI tokens|


### minVotingPeriod

Returns the minimum voting period

*Minimum duration for proposal voting (seconds)*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query minimum voting period

- oracle: No oracle dependencies


```solidity
function minVotingPeriod() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Minimum voting period in seconds|


### maxVotingPeriod

Returns the maximum voting period

*Maximum duration for proposal voting (seconds)*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query maximum voting period

- oracle: No oracle dependencies


```solidity
function maxVotingPeriod() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Maximum voting period in seconds|


### quorumVotes

Returns the quorum votes requirement

*Minimum votes required for proposal execution (18 decimals)*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query quorum votes

- oracle: No oracle dependencies


```solidity
function quorumVotes() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Quorum votes requirement in QTI tokens|


### treasury

Returns the treasury address

*Address where protocol fees and rewards are sent*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query treasury address

- oracle: No oracle dependencies


```solidity
function treasury() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|address Treasury address|


### decentralizationStartTime

Returns the decentralization start time

*Timestamp when decentralization process began*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query decentralization start time

- oracle: No oracle dependencies


```solidity
function decentralizationStartTime() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Decentralization start timestamp|


### decentralizationDuration

Returns the decentralization duration

*Duration of the decentralization process (seconds)*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query decentralization duration

- oracle: No oracle dependencies


```solidity
function decentralizationDuration() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Decentralization duration in seconds|


### currentDecentralizationLevel

Returns the current decentralization level

*Current level of protocol decentralization (0-100)*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query current decentralization level

- oracle: No oracle dependencies


```solidity
function currentDecentralizationLevel() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Current decentralization level|


### recoverToken

Recovers tokens accidentally sent to the contract

*Emergency function to recover ERC20 tokens that are not part of normal operations*

**Notes:**
- security: Validates admin role and uses secure recovery library

- validation: No input validation required - library handles validation

- state-changes: Transfers tokens from contract to specified address

- events: Emits TokenRecovered event

- errors: No errors thrown - library handles error cases

- reentrancy: Not protected - library handles reentrancy

- access: Restricted to DEFAULT_ADMIN_ROLE

- oracle: No oracle dependencies for token recovery


```solidity
function recoverToken(address token, address to, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Address of the token to recover|
|`to`|`address`|Address to send recovered tokens to|
|`amount`|`uint256`|Amount of tokens to recover|


### recoverETH

Recovers ETH accidentally sent to the contract

*Emergency function to recover ETH that was accidentally sent to the contract*

**Notes:**
- security: Validates admin role and emits recovery event

- validation: No input validation required - transfers all ETH

- state-changes: Transfers all contract ETH balance to treasury

- events: Emits ETHRecovered with amount and treasury address

- errors: No errors thrown - safe ETH transfer

- reentrancy: Not protected - no external calls

- access: Restricted to DEFAULT_ADMIN_ROLE

- oracle: No oracle dependencies


```solidity
function recoverETH() external;
```

