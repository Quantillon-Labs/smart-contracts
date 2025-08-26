# IQuantillonVault
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/c5a08452eb568457f0f8b1c726e5ba978b846461/src/interfaces/IQuantillonVault.sol)

**Author:**
Quantillon Labs

Interface for the Quantillon vault managing QEURO mint/redeem against USDC

*Exposes core swap functions, views, governance, emergency, and recovery*

**Note:**
security-contact: team@quantillon.money


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

Mints QEURO by swapping USDC


```solidity
function mintQEURO(uint256 usdcAmount, uint256 minQeuroOut) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC to swap|
|`minQeuroOut`|`uint256`|Minimum QEURO expected (slippage protection)|


### redeemQEURO

Redeems QEURO for USDC


```solidity
function redeemQEURO(uint256 qeuroAmount, uint256 minUsdcOut) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount of QEURO to swap|
|`minUsdcOut`|`uint256`|Minimum USDC expected|


### getVaultMetrics

Retrieves the vault's global metrics


```solidity
function getVaultMetrics()
    external
    view
    returns (uint256 totalUsdcHeld_, uint256 totalMinted_, uint256 totalDebtValue);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalUsdcHeld_`|`uint256`|Total USDC held in the vault|
|`totalMinted_`|`uint256`|Total QEURO minted|
|`totalDebtValue`|`uint256`|Total debt value in USD|


### calculateMintAmount

Computes QEURO mint amount for a USDC swap


```solidity
function calculateMintAmount(uint256 usdcAmount) external view returns (uint256 qeuroAmount, uint256 fee);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|USDC to swap|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Expected QEURO to mint (after fees)|
|`fee`|`uint256`|Protocol fee|


### calculateRedeemAmount

Computes USDC redemption amount for a QEURO swap


```solidity
function calculateRedeemAmount(uint256 qeuroAmount) external view returns (uint256 usdcAmount, uint256 fee);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|QEURO to swap|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|USDC returned after fees|
|`fee`|`uint256`|Protocol fee|


### updateParameters

Updates vault parameters


```solidity
function updateParameters(uint256 _mintFee, uint256 _redemptionFee) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_mintFee`|`uint256`|New minting fee|
|`_redemptionFee`|`uint256`|New redemption fee|


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


