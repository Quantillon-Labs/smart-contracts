# IstQEURO
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/43ac0bece4bbd2df8011613aafa1156984ab00f8/src/interfaces/IstQEURO.sol)

**Author:**
Quantillon Labs

Interface for the stQEURO yield-bearing wrapper token (yield accrual mechanism)

**Note:**
security-contact: team@quantillon.money


## Functions
### initialize

Initializes the stQEURO token


```solidity
function initialize(address admin, address _qeuro, address _yieldShift, address _usdc, address _treasury) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Admin address|
|`_qeuro`|`address`|QEURO token address|
|`_yieldShift`|`address`|YieldShift contract address|
|`_usdc`|`address`|USDC token address|
|`_treasury`|`address`|Treasury address|


### stake

Stake QEURO to receive stQEURO


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


### distributeYield

Distribute yield to stQEURO holders (increases exchange rate)


```solidity
function distributeYield(uint256 yieldAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`yieldAmount`|`uint256`|Amount of yield in USDC|


### claimYield

Claim accumulated yield for a user (in USDC)


```solidity
function claimYield() external returns (uint256 yieldAmount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`yieldAmount`|`uint256`|Amount of yield claimed|


### getPendingYield

Get pending yield for a user (in USDC)


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


```solidity
function getExchangeRate() external view returns (uint256);
```

### getTVL

Get total value locked in stQEURO


```solidity
function getTVL() external view returns (uint256);
```

### getQEUROEquivalent

Get user's QEURO equivalent balance


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


```solidity
function getStakingStats()
    external
    view
    returns (
        uint256 totalStQEUROSupply,
        uint256 totalQEUROUnderlying,
        uint256 currentExchangeRate,
        uint256 totalYieldEarned,
        uint256 apy
    );
```

### updateYieldParameters

Update yield parameters


```solidity
function updateYieldParameters(uint256 _yieldFee, uint256 _minYieldThreshold, uint256 _maxUpdateFrequency) external;
```

### updateTreasury

Update treasury address


```solidity
function updateTreasury(address _treasury) external;
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

### emergencyWithdraw

Emergency withdrawal of QEURO


```solidity
function emergencyWithdraw(address user) external;
```

### recoverToken

Recover accidentally sent tokens


```solidity
function recoverToken(address token, address to, uint256 amount) external;
```

### recoverETH

Recover accidentally sent ETH


```solidity
function recoverETH(address payable to) external;
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

