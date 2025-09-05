# IstQEURO
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/07b6c9d21c3d2b99aa95cee2e6cc9c3f00f0009a/src/interfaces/IstQEURO.sol)

**Author:**
Quantillon Labs

Interface for the stQEURO yield-bearing wrapper token (yield accrual mechanism)

**Note:**
security-contact: team@quantillon.money


## Functions
### initialize

Initializes the stQEURO token


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
|`timelock`|`address`||


### stake

Stake QEURO to receive stQEURO

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
function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) external returns (bool);
```

### distributeYield

Distribute yield to stQEURO holders (increases exchange rate)

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
function distributeYield(uint256 yieldAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`yieldAmount`|`uint256`|Amount of yield in USDC|


### claimYield

Claim accumulated yield for a user (in USDC)

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
function claimYield() external returns (uint256 yieldAmount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`yieldAmount`|`uint256`|Amount of yield claimed|


### getPendingYield

Get pending yield for a user (in USDC)

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
function getExchangeRate() external view returns (uint256);
```

### getTVL

Get total value locked in stQEURO

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
function getTVL() external view returns (uint256);
```

### getQEUROEquivalent

Get user's QEURO equivalent balance

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


```solidity
function updateYieldParameters(uint256 _yieldFee, uint256 _minYieldThreshold, uint256 _maxUpdateFrequency) external;
```

### updateTreasury

Update treasury address

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

### pause

Pause the contract

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

### emergencyWithdraw

Emergency withdrawal of QEURO

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
function emergencyWithdraw(address user) external;
```

### recoverToken

Recover accidentally sent tokens

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
function recoverToken(address token, address to, uint256 amount) external;
```

### recoverETH

Recover accidentally sent ETH

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
function recoverETH() external;
```

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

### YIELD_MANAGER_ROLE


```solidity
function YIELD_MANAGER_ROLE() external view returns (bytes32);
```

### EMERGENCY_ROLE


```solidity
function EMERGENCY_ROLE() external view returns (bytes32);
```

### UPGRADER_ROLE


```solidity
function UPGRADER_ROLE() external view returns (bytes32);
```

### qeuro


```solidity
function qeuro() external view returns (address);
```

### yieldShift


```solidity
function yieldShift() external view returns (address);
```

### usdc


```solidity
function usdc() external view returns (address);
```

### treasury


```solidity
function treasury() external view returns (address);
```

### exchangeRate


```solidity
function exchangeRate() external view returns (uint256);
```

### lastUpdateTime


```solidity
function lastUpdateTime() external view returns (uint256);
```

### totalUnderlying


```solidity
function totalUnderlying() external view returns (uint256);
```

### totalYieldEarned


```solidity
function totalYieldEarned() external view returns (uint256);
```

### yieldFee


```solidity
function yieldFee() external view returns (uint256);
```

### minYieldThreshold


```solidity
function minYieldThreshold() external view returns (uint256);
```

### maxUpdateFrequency


```solidity
function maxUpdateFrequency() external view returns (uint256);
```

