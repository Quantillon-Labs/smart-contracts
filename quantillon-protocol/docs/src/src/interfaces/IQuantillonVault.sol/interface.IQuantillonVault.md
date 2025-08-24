# IQuantillonVault
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/fe414bc17d9f44041055fc158bb99f01c5c5476e/src/interfaces/IQuantillonVault.sol)

**Author:**
Quantillon Labs

Interface for the Quantillon vault managing QEURO mint/redeem against USDC

*Exposes core actions, liquidation, views, governance, emergency, and recovery*

**Note:**
team@quantillon.money


## Functions
### initialize

Initializes the vault


```solidity
function initialize(address admin, address _qeuro, address _usdc, address _oracle) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Admin address receiving roles|
|`_qeuro`|`address`|QEURO token address|
|`_usdc`|`address`|USDC token address|
|`_oracle`|`address`|Oracle contract address|


### mintQEURO

Mints QEURO by depositing USDC


```solidity
function mintQEURO(uint256 usdcAmount, uint256 minQeuroOut) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC to deposit|
|`minQeuroOut`|`uint256`|Minimum QEURO expected (slippage protection)|


### redeemQEURO

Redeems QEURO for USDC


```solidity
function redeemQEURO(uint256 qeuroAmount, uint256 minUsdcOut) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount of QEURO to burn|
|`minUsdcOut`|`uint256`|Minimum USDC expected|


### addCollateral

Adds USDC collateral


```solidity
function addCollateral(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of USDC to add|


### removeCollateral

Removes USDC collateral if safe


```solidity
function removeCollateral(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of USDC to remove|


### liquidate

Liquidates an undercollateralized user


```solidity
function liquidate(address user, uint256 debtToCover) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User to liquidate|
|`debtToCover`|`uint256`|Amount of debt to cover|


### isUserLiquidatable

Returns whether a user can be liquidated


```solidity
function isUserLiquidatable(address user) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if liquidatable|


### getUserCollateralRatio

User collateralization ratio


```solidity
function getUserCollateralRatio(address user) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Ratio with 18 decimals|


### getVaultHealth

Global vault health metrics


```solidity
function getVaultHealth()
    external
    view
    returns (uint256 totalCollateralValue, uint256 totalDebtValue, uint256 globalCollateralRatio);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalCollateralValue`|`uint256`|Total USDC collateral|
|`totalDebtValue`|`uint256`|Total QEURO debt valued in USDC|
|`globalCollateralRatio`|`uint256`|Global ratio with 18 decimals|


### getUserInfo

Detailed user info


```solidity
function getUserInfo(address user)
    external
    view
    returns (uint256 collateral, uint256 debt, uint256 collateralRatio, bool isLiquidatable, bool liquidated);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`collateral`|`uint256`|User USDC collateral|
|`debt`|`uint256`|User QEURO debt|
|`collateralRatio`|`uint256`|Current ratio with 18 decimals|
|`isLiquidatable`|`bool`|Whether the user can be liquidated|
|`liquidated`|`bool`|Liquidation status flag|


### calculateMintAmount

Computes QEURO mint amount for a USDC deposit


```solidity
function calculateMintAmount(uint256 usdcAmount) external view returns (uint256 qeuroAmount, uint256 collateralRatio);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|USDC to deposit|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Expected QEURO to mint|
|`collateralRatio`|`uint256`|Resulting ratio|


### calculateRedeemAmount

Computes USDC redemption amount for a QEURO burn


```solidity
function calculateRedeemAmount(uint256 qeuroAmount) external view returns (uint256 usdcAmount, uint256 fee);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|QEURO to redeem|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|USDC returned after fees|
|`fee`|`uint256`|Protocol fee|


### updateParameters

Updates vault parameters


```solidity
function updateParameters(uint256 _minCollateralRatio, uint256 _liquidationThreshold, uint256 _liquidationPenalty)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_minCollateralRatio`|`uint256`|New minimum ratio (>= 100%)|
|`_liquidationThreshold`|`uint256`|New liquidation threshold (<= min)|
|`_liquidationPenalty`|`uint256`|New liquidation penalty (<= 20%)|


### updateProtocolFee

Updates the protocol fee


```solidity
function updateProtocolFee(uint256 _protocolFee) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_protocolFee`|`uint256`|New fee (e.g., 1e15 = 0.1%)|


### updateOracle

Updates the oracle address


```solidity
function updateOracle(address _oracle) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_oracle`|`address`|New oracle address|


### withdrawProtocolFees

Withdraws accumulated protocol fees


```solidity
function withdrawProtocolFees(address to) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Recipient address|


### pause

Pauses the vault


```solidity
function pause() external;
```

### unpause

Unpauses the vault


```solidity
function unpause() external;
```

### emergencyLiquidate

Emergency liquidation bypassing normal checks


```solidity
function emergencyLiquidate(address user, uint256 debtToCover) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User to liquidate|
|`debtToCover`|`uint256`|Debt to cover|


### recoverToken

Recovers ERC20 tokens sent by mistake


```solidity
function recoverToken(address token, address to, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address|
|`to`|`address`|Recipient|
|`amount`|`uint256`|Amount to transfer|


### recoverETH

Recovers ETH sent by mistake


```solidity
function recoverETH(address payable to) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address payable`|Recipient|


