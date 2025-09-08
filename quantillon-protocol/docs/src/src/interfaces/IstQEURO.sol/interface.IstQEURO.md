# IstQEURO
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/a616e9423dc69fc1960f3a480a5300eaa5fe80e0/src/interfaces/IstQEURO.sol)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Interface for the stQEURO yield-bearing wrapper token (yield accrual mechanism)

**Note:**
team@quantillon.money


## Functions
### initialize

Initializes the stQEURO token

*Sets up the stQEURO token with initial configuration and assigns roles to admin*

**Notes:**
- Validates all addresses are not zero and initializes roles

- Validates admin is not address(0), all contract addresses are valid

- Initializes roles, sets contract addresses, enables staking

- Emits role assignment and initialization events

- Throws InvalidAddress if any address is zero

- Protected by onlyInitializing modifier

- Internal function - only callable during initialization

- No oracle dependencies


```solidity
function initialize(
    address admin,
    address _qeuro,
    address _yieldShift,
    address _usdc,
    address _treasury,
    address timelock
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Admin address|
|`_qeuro`|`address`|QEURO token address|
|`_yieldShift`|`address`|YieldShift contract address|
|`_usdc`|`address`|USDC token address|
|`_treasury`|`address`|Treasury address|
|`timelock`|`address`|Timelock contract address|


### stake

Stake QEURO to receive stQEURO

*Converts QEURO to stQEURO at current exchange rate with yield accrual*

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
function stake(uint256 qeuroAmount) external returns (uint256 stQEUROAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount of QEURO to stake|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`stQEUROAmount`|`uint256`|Amount of stQEURO received|


### unstake

Unstake QEURO by burning stQEURO

*Converts stQEURO back to QEURO at current exchange rate*

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
function unstake(uint256 stQEUROAmount) external returns (uint256 qeuroAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`stQEUROAmount`|`uint256`|Amount of stQEURO to burn|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount of QEURO received|


### batchStake

Batch stake QEURO amounts

*Efficiently stakes multiple QEURO amounts in a single transaction*

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
function batchStake(uint256[] calldata qeuroAmounts) external returns (uint256[] memory stQEUROAmounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmounts`|`uint256[]`|Array of QEURO amounts|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`stQEUROAmounts`|`uint256[]`|Array of stQEURO minted|


### batchUnstake

Batch unstake stQEURO amounts

*Efficiently unstakes multiple stQEURO amounts in a single transaction*

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
function batchUnstake(uint256[] calldata stQEUROAmounts) external returns (uint256[] memory qeuroAmounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`stQEUROAmounts`|`uint256[]`|Array of stQEURO amounts|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmounts`|`uint256[]`|Array of QEURO returned|


### batchTransfer

Batch transfer stQEURO to multiple recipients

*Efficiently transfers stQEURO to multiple recipients in a single transaction*

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
function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipients`|`address[]`|Array of recipient addresses|
|`amounts`|`uint256[]`|Array of amounts to transfer|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|success True if all transfers succeeded|


### distributeYield

Distribute yield to stQEURO holders (increases exchange rate)

*Distributes yield by increasing the exchange rate for all stQEURO holders*

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
function distributeYield(uint256 yieldAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`yieldAmount`|`uint256`|Amount of yield in USDC|


### claimYield

Claim accumulated yield for a user (in USDC)

*Claims the user's accumulated yield and transfers it to their address*

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
function claimYield() external returns (uint256 yieldAmount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`yieldAmount`|`uint256`|Amount of yield claimed|


### getPendingYield

Get pending yield for a user (in USDC)

*Returns the amount of yield available for a specific user to claim*

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
function getPendingYield(address user) external view returns (uint256 yieldAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`yieldAmount`|`uint256`|Pending yield amount|


### getExchangeRate

Get current exchange rate between QEURO and stQEURO

*Returns the current exchange rate used for staking/unstaking operations*

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
function getExchangeRate() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|exchangeRate Current exchange rate (18 decimals)|


### getTVL

Get total value locked in stQEURO

*Returns the total value locked in the stQEURO system*

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
function getTVL() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|tvl Total value locked (18 decimals)|


### getQEUROEquivalent

Get user's QEURO equivalent balance

*Returns the QEURO equivalent value of a user's stQEURO balance*

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
function getQEUROEquivalent(address user) external view returns (uint256 qeuroEquivalent);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`qeuroEquivalent`|`uint256`|QEURO equivalent of stQEURO balance|


### getStakingStats

Get staking statistics

*Returns comprehensive staking statistics and metrics*

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
function getStakingStats()
    external
    view
    returns (
        uint256 totalStQEUROSupply,
        uint256 totalQEUROUnderlying,
        uint256 currentExchangeRate,
        uint256 _totalYieldEarned,
        uint256 apy
    );
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalStQEUROSupply`|`uint256`|Total stQEURO supply|
|`totalQEUROUnderlying`|`uint256`|Total QEURO underlying|
|`currentExchangeRate`|`uint256`|Current exchange rate|
|`_totalYieldEarned`|`uint256`|Total yield earned|
|`apy`|`uint256`|Annual percentage yield|


### updateYieldParameters

Update yield parameters

*Updates yield-related parameters with security checks*

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
function updateYieldParameters(uint256 _yieldFee, uint256 _minYieldThreshold, uint256 _maxUpdateFrequency) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_yieldFee`|`uint256`|New yield fee percentage|
|`_minYieldThreshold`|`uint256`|New minimum yield threshold|
|`_maxUpdateFrequency`|`uint256`|New maximum update frequency|


### updateTreasury

Update treasury address

*Updates the treasury address for yield distribution*

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
function updateTreasury(address _treasury) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_treasury`|`address`|New treasury address|


### pause

Pause the contract

*Pauses all stQEURO operations for emergency situations*

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
function pause() external;
```

### unpause

Unpause the contract

*Resumes all stQEURO operations after being paused*

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
function unpause() external;
```

### emergencyWithdraw

Emergency withdrawal of QEURO

*Allows emergency withdrawal of QEURO for a specific user*

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
function emergencyWithdraw(address user) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address to withdraw for|


### recoverToken

Recover accidentally sent tokens

*Allows recovery of ERC20 tokens accidentally sent to the contract*

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
function recoverToken(address token, address to, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address to recover|
|`to`|`address`|Recipient address|
|`amount`|`uint256`|Amount to transfer|


### recoverETH

Recover accidentally sent ETH

*Allows recovery of ETH accidentally sent to the contract*

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
function recoverETH() external;
```

### name

Returns the name of the token

*Returns the token name for display purposes*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query token name

- No oracle dependencies


```solidity
function name() external view returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The token name|


### symbol

Returns the symbol of the token

*Returns the token symbol for display purposes*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query token symbol

- No oracle dependencies


```solidity
function symbol() external view returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The token symbol|


### decimals

Returns the decimals of the token

*Returns the number of decimals used for token amounts*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query token decimals

- No oracle dependencies


```solidity
function decimals() external view returns (uint8);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|The number of decimals|


### totalSupply

Returns the total supply of the token

*Returns the total amount of tokens in existence*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query total supply

- No oracle dependencies


```solidity
function totalSupply() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total supply|


### balanceOf

Returns the balance of an account

*Returns the token balance of the specified account*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query account balance

- No oracle dependencies


```solidity
function balanceOf(address account) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The balance of the account|


### transfer

Transfers tokens to a recipient

*Transfers the specified amount of tokens to the recipient*

**Notes:**
- Validates recipient is not address(0) and caller has sufficient balance

- Validates to != address(0) and amount <= balanceOf(msg.sender)

- Updates balances of sender and recipient

- Emits Transfer event

- Throws InsufficientBalance if amount > balance

- Not protected - no external calls

- Public - any token holder can transfer

- No oracle dependencies


```solidity
function transfer(address to, uint256 amount) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The recipient address|
|`amount`|`uint256`|The amount to transfer|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the transfer succeeded|


### allowance

Returns the allowance for a spender

*Returns the amount of tokens that the spender is allowed to spend*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query allowance

- No oracle dependencies


```solidity
function allowance(address owner, address spender) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The owner address|
|`spender`|`address`|The spender address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The allowance amount|


### approve

Approves a spender to spend tokens

*Sets the allowance for the spender to spend tokens on behalf of the caller*

**Notes:**
- Validates spender is not address(0)

- Validates spender != address(0)

- Updates allowance mapping

- Emits Approval event

- No errors thrown - safe function

- Not protected - no external calls

- Public - any token holder can approve

- No oracle dependencies


```solidity
function approve(address spender, uint256 amount) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`spender`|`address`|The spender address|
|`amount`|`uint256`|The amount to approve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the approval succeeded|


### transferFrom

Transfers tokens from one account to another

*Transfers tokens from the from account to the to account*

**Notes:**
- Validates recipient is not address(0) and sufficient allowance

- Validates to != address(0) and amount <= allowance(from, msg.sender)

- Updates balances and allowance

- Emits Transfer event

- Throws InsufficientAllowance if amount > allowance

- Not protected - no external calls

- Public - any approved spender can transfer

- No oracle dependencies


```solidity
function transferFrom(address from, address to, uint256 amount) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|The sender address|
|`to`|`address`|The recipient address|
|`amount`|`uint256`|The amount to transfer|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the transfer succeeded|


### hasRole

Checks if an account has a specific role

*Returns true if the account has been granted the role*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can check roles

- No oracle dependencies


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
|`<none>`|`bool`|True if the account has the role|


### getRoleAdmin

Returns the admin role for a role

*Returns the role that is the admin of the given role*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query role admin

- No oracle dependencies


```solidity
function getRoleAdmin(bytes32 role) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The admin role|


### grantRole

Grants a role to an account

*Grants the specified role to the account*

**Notes:**
- Validates caller has admin role for the specified role

- Validates account is not address(0)

- Grants role to account

- Emits RoleGranted event

- Throws AccessControlUnauthorizedAccount if caller lacks admin role

- Not protected - no external calls

- Restricted to role admin

- No oracle dependencies


```solidity
function grantRole(bytes32 role, address account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to grant|
|`account`|`address`|The account to grant the role to|


### revokeRole

Revokes a role from an account

*Revokes the specified role from the account*

**Notes:**
- Validates caller has admin role for the specified role

- Validates account is not address(0)

- Revokes role from account

- Emits RoleRevoked event

- Throws AccessControlUnauthorizedAccount if caller lacks admin role

- Not protected - no external calls

- Restricted to role admin

- No oracle dependencies


```solidity
function revokeRole(bytes32 role, address account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to revoke|
|`account`|`address`|The account to revoke the role from|


### renounceRole

Renounces a role

*Renounces the specified role from the caller*

**Notes:**
- Validates caller is renouncing their own role

- Validates callerConfirmation == msg.sender

- Removes role from caller

- Emits RoleRenounced event

- Throws AccessControlInvalidCaller if callerConfirmation != msg.sender

- Not protected - no external calls

- Public - anyone can renounce their own roles

- No oracle dependencies


```solidity
function renounceRole(bytes32 role, address callerConfirmation) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The role to renounce|
|`callerConfirmation`|`address`|The caller confirmation|


### paused

Returns the paused state

*Returns true if the contract is paused*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can check pause status

- No oracle dependencies


```solidity
function paused() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if paused|


### upgradeTo

Upgrades the implementation

*Upgrades the contract to a new implementation*

**Notes:**
- Validates caller has UPGRADER_ROLE

- Validates newImplementation is not address(0)

- Updates implementation address

- Emits Upgraded event

- Throws AccessControlUnauthorizedAccount if caller lacks UPGRADER_ROLE

- Not protected - no external calls

- Restricted to UPGRADER_ROLE

- No oracle dependencies


```solidity
function upgradeTo(address newImplementation) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|The new implementation address|


### upgradeToAndCall

Upgrades the implementation and calls a function

*Upgrades the contract and calls a function on the new implementation*

**Notes:**
- Validates caller has UPGRADER_ROLE

- Validates newImplementation is not address(0)

- Updates implementation address and calls initialization

- Emits Upgraded event

- Throws AccessControlUnauthorizedAccount if caller lacks UPGRADER_ROLE

- Not protected - no external calls

- Restricted to UPGRADER_ROLE

- No oracle dependencies


```solidity
function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|The new implementation address|
|`data`|`bytes`|The function call data|


### GOVERNANCE_ROLE

Returns the governance role

*Returns the role identifier for governance functions*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query role identifier

- No oracle dependencies


```solidity
function GOVERNANCE_ROLE() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The governance role|


### YIELD_MANAGER_ROLE

Returns the yield manager role

*Returns the role identifier for yield management functions*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query role identifier

- No oracle dependencies


```solidity
function YIELD_MANAGER_ROLE() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The yield manager role|


### EMERGENCY_ROLE

Returns the emergency role

*Returns the role identifier for emergency functions*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query role identifier

- No oracle dependencies


```solidity
function EMERGENCY_ROLE() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The emergency role|


### UPGRADER_ROLE

Returns the upgrader role

*Returns the role identifier for upgrade functions*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query role identifier

- No oracle dependencies


```solidity
function UPGRADER_ROLE() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The upgrader role|


### qeuro

Returns the QEURO token address

*Returns the address of the underlying QEURO token*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query token address

- No oracle dependencies


```solidity
function qeuro() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The QEURO token address|


### yieldShift

Returns the YieldShift contract address

*Returns the address of the YieldShift contract*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query contract address

- No oracle dependencies


```solidity
function yieldShift() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The YieldShift contract address|


### usdc

Returns the USDC token address

*Returns the address of the USDC token*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query token address

- No oracle dependencies


```solidity
function usdc() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The USDC token address|


### treasury

Returns the treasury address

*Returns the address of the treasury contract*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query treasury address

- No oracle dependencies


```solidity
function treasury() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The treasury address|


### exchangeRate

Returns the current exchange rate

*Returns the current exchange rate between QEURO and stQEURO*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query exchange rate

- No oracle dependencies


```solidity
function exchangeRate() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current exchange rate|


### lastUpdateTime

Returns the last update time

*Returns the timestamp of the last exchange rate update*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query last update time

- No oracle dependencies


```solidity
function lastUpdateTime() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The last update time|


### totalUnderlying

Returns the total underlying QEURO

*Returns the total amount of QEURO underlying all stQEURO*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query total underlying

- No oracle dependencies


```solidity
function totalUnderlying() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total underlying QEURO|


### totalYieldEarned

Returns the total yield earned

*Returns the total amount of yield earned by all stQEURO holders*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query total yield earned

- No oracle dependencies


```solidity
function totalYieldEarned() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total yield earned|


### yieldFee

Returns the yield fee percentage

*Returns the percentage of yield that goes to the treasury*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query yield fee

- No oracle dependencies


```solidity
function yieldFee() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The yield fee percentage|


### minYieldThreshold

Returns the minimum yield threshold

*Returns the minimum yield amount required for distribution*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query minimum yield threshold

- No oracle dependencies


```solidity
function minYieldThreshold() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The minimum yield threshold|


### maxUpdateFrequency

Returns the maximum update frequency

*Returns the maximum frequency for exchange rate updates*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query maximum update frequency

- No oracle dependencies


```solidity
function maxUpdateFrequency() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The maximum update frequency|


