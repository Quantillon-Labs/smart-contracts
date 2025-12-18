# IQuantillonVault
**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Interface for the Quantillon vault managing QEURO mint/redeem against USDC

*Exposes core swap functions, views, governance, emergency, and recovery*

**Note:**
team@quantillon.money


## Functions
### initialize

Initializes the vault

*Sets up the vault with initial configuration and assigns roles to admin*

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
function initialize(
    address admin,
    address _qeuro,
    address _usdc,
    address _oracle,
    address _hedgerPool,
    address _userPool,
    address _timelock,
    address _feeCollector
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Admin address receiving roles|
|`_qeuro`|`address`|QEURO token address|
|`_usdc`|`address`|USDC token address|
|`_oracle`|`address`|Oracle contract address|
|`_hedgerPool`|`address`|HedgerPool contract address|
|`_userPool`|`address`|UserPool contract address|
|`_timelock`|`address`|Timelock contract address|
|`_feeCollector`|`address`|FeeCollector contract address|


### mintQEURO

Mints QEURO by swapping USDC

*Converts USDC to QEURO using current oracle price with slippage protection*

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
function mintQEURO(uint256 usdcAmount, uint256 minQeuroOut) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC to swap|
|`minQeuroOut`|`uint256`|Minimum QEURO expected (slippage protection)|


### redeemQEURO

Redeems QEURO for USDC

*Converts QEURO (18 decimals) to USDC (6 decimals) using oracle price*

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
function redeemQEURO(uint256 qeuroAmount, uint256 minUsdcOut) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount of QEURO to swap|
|`minUsdcOut`|`uint256`|Minimum USDC expected|


### getVaultMetrics

Retrieves the vault's global metrics

*Provides comprehensive vault statistics for monitoring and analysis*

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
function getVaultMetrics()
    external
    returns (
        uint256 totalUsdcHeld_,
        uint256 totalMinted_,
        uint256 totalDebtValue,
        uint256 totalUsdcInAave_,
        uint256 totalUsdcAvailable_
    );
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalUsdcHeld_`|`uint256`|Total USDC held directly in the vault|
|`totalMinted_`|`uint256`|Total QEURO minted|
|`totalDebtValue`|`uint256`|Total debt value in USD|
|`totalUsdcInAave_`|`uint256`|Total USDC deployed to Aave for yield|
|`totalUsdcAvailable_`|`uint256`|Total USDC available (vault + Aave)|


### calculateMintAmount

Computes QEURO mint amount for a USDC swap

*Uses current oracle price to calculate QEURO equivalent without executing swap*

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

*Uses current oracle price to calculate USDC equivalent without executing swap*

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

*Allows governance to update fee parameters for minting and redemption*

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
function updateParameters(uint256 _mintFee, uint256 _redemptionFee) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_mintFee`|`uint256`|New minting fee|
|`_redemptionFee`|`uint256`|New redemption fee|


### updateOracle

Updates the oracle address

*Allows governance to update the price oracle used for conversions*

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
function updateOracle(address _oracle) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_oracle`|`address`|New oracle address|


### withdrawProtocolFees

Withdraws accumulated protocol fees

*Allows governance to withdraw accumulated fees to specified address*

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
function withdrawProtocolFees(address to) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Recipient address|


### pause

Pauses the vault

*Emergency function to pause all vault operations*

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

Unpauses the vault

*Resumes all vault operations after emergency pause*

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

### recoverToken

Recovers ERC20 tokens sent by mistake

*Allows governance to recover accidentally sent ERC20 tokens to treasury*

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
function recoverToken(address token, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address|
|`amount`|`uint256`|Amount to transfer|


### recoverETH

Recovers ETH sent by mistake

*Allows governance to recover accidentally sent ETH*

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

Gets the admin role for a given role

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
|`role`|`bytes32`|The role to get admin for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The admin role|


### grantRole

Grants a role to an account

*Can only be called by an account with the admin role*

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

*Can only be called by an account with the admin role*

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

Renounces a role from the caller

*The caller gives up their own role*

**Notes:**
- Validates caller is renouncing their own role

- Validates callerConfirmation matches msg.sender

- Revokes role from caller

- Emits RoleRevoked event

- Throws AccessControlBadConfirmation if callerConfirmation != msg.sender

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
|`callerConfirmation`|`address`|Confirmation that the caller is renouncing their own role|


### paused

Checks if the contract is paused

*Returns true if the contract is currently paused*

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
|`<none>`|`bool`|True if paused, false otherwise|


### upgradeTo

Upgrades the contract to a new implementation

*Can only be called by accounts with UPGRADER_ROLE*

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
|`newImplementation`|`address`|Address of the new implementation contract|


### upgradeToAndCall

Upgrades the contract to a new implementation and calls a function

*Can only be called by accounts with UPGRADER_ROLE*

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
|`newImplementation`|`address`|Address of the new implementation contract|
|`data`|`bytes`|Encoded function call data|


### GOVERNANCE_ROLE

Returns the governance role identifier

*Role that can update vault parameters and governance functions*

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
|`<none>`|`bytes32`|The governance role bytes32 identifier|


### EMERGENCY_ROLE

Returns the emergency role identifier

*Role that can pause the vault and perform emergency operations*

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
|`<none>`|`bytes32`|The emergency role bytes32 identifier|


### UPGRADER_ROLE

Returns the upgrader role identifier

*Role that can upgrade the contract implementation*

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
|`<none>`|`bytes32`|The upgrader role bytes32 identifier|


### qeuro

Returns the QEURO token address

*The euro-pegged stablecoin token managed by this vault*

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
|`<none>`|`address`|Address of the QEURO token contract|


### usdc

Returns the USDC token address

*The collateral token used for minting QEURO*

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
|`<none>`|`address`|Address of the USDC token contract|


### oracle

Returns the oracle contract address

*The price oracle used for EUR/USD conversions*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query oracle address

- No oracle dependencies


```solidity
function oracle() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Address of the oracle contract|


### mintFee

Returns the current minting fee

*Fee charged when minting QEURO with USDC (in basis points)*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query minting fee

- No oracle dependencies


```solidity
function mintFee() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The minting fee in basis points|


### redemptionFee

Returns the current redemption fee

*Fee charged when redeeming QEURO for USDC (in basis points)*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query redemption fee

- No oracle dependencies


```solidity
function redemptionFee() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The redemption fee in basis points|


### totalUsdcHeld

Returns the total USDC held in the vault

*Total amount of USDC collateral backing QEURO*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query total USDC held

- No oracle dependencies


```solidity
function totalUsdcHeld() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total USDC amount (6 decimals)|


### totalMinted

Returns the total QEURO minted

*Total amount of QEURO tokens in circulation*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query total QEURO minted

- No oracle dependencies


```solidity
function totalMinted() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total QEURO amount (18 decimals)|


### isProtocolCollateralized

Checks if the protocol is properly collateralized by hedgers

*Public view function to check collateralization status*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can check collateralization status

- No oracle dependencies


```solidity
function isProtocolCollateralized() external view returns (bool isCollateralized, uint256 totalMargin);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isCollateralized`|`bool`|True if protocol has active hedging positions|
|`totalMargin`|`uint256`|Total margin in HedgerPool (0 if not set)|


### minCollateralizationRatioForMinting

Returns the minimum collateralization ratio for minting

*Minimum ratio required for QEURO minting (in basis points)*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query minimum ratio

- No oracle dependencies


```solidity
function minCollateralizationRatioForMinting() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The minimum collateralization ratio in basis points|


### userPool

Returns the UserPool contract address

*The user pool contract managing user deposits*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query user pool address

- No oracle dependencies


```solidity
function userPool() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Address of the UserPool contract|


### addHedgerDeposit

Adds hedger USDC deposit to vault's total USDC reserves

*Called by HedgerPool when hedgers open positions to unify USDC liquidity*

**Notes:**
- Validates caller is HedgerPool contract and amount is positive

- Validates amount > 0 and caller is authorized HedgerPool

- Updates totalUsdcHeld with hedger deposit amount

- Emits HedgerDepositAdded with deposit details

- Throws "Vault: Only HedgerPool can call" if caller is not HedgerPool

- Throws "Vault: Amount must be positive" if amount is zero

- Protected by nonReentrant modifier

- Restricted to HedgerPool contract only

- No oracle dependencies


```solidity
function addHedgerDeposit(uint256 usdcAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC deposited by hedger (6 decimals)|


### withdrawHedgerDeposit

Withdraws hedger USDC deposit from vault's reserves

*Called by HedgerPool when hedgers close positions to return their deposits*

**Notes:**
- Validates caller is HedgerPool, amount is positive, and sufficient reserves

- Validates amount > 0, caller is authorized, and totalUsdcHeld >= amount

- Updates totalUsdcHeld and transfers USDC to hedger

- Emits HedgerDepositWithdrawn with withdrawal details

- Throws "Vault: Only HedgerPool can call" if caller is not HedgerPool

- Throws "Vault: Amount must be positive" if amount is zero

- Throws "Vault: Insufficient USDC reserves" if not enough USDC available

- Protected by nonReentrant modifier

- Restricted to HedgerPool contract only

- No oracle dependencies


```solidity
function withdrawHedgerDeposit(address hedger, uint256 usdcAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger receiving the USDC|
|`usdcAmount`|`uint256`|Amount of USDC to withdraw (6 decimals)|


### getTotalUsdcAvailable

Gets the total USDC available for hedger deposits

*Returns the current total USDC held in the vault for transparency*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown

- Not applicable - view function

- Public access - anyone can query total USDC held

- No oracle dependencies


```solidity
function getTotalUsdcAvailable() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Total USDC held in vault (6 decimals)|


### updateHedgerPool

Updates the HedgerPool address

*Updates the HedgerPool contract address for hedger operations*

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
function updateHedgerPool(address _hedgerPool) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_hedgerPool`|`address`|New HedgerPool address|


### updateUserPool

Updates the UserPool address

*Updates the UserPool contract address for user deposit tracking*

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
function updateUserPool(address _userPool) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_userPool`|`address`|New UserPool address|


### getPriceProtectionStatus

Gets the price protection status and parameters

*Returns price protection configuration for monitoring*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown

- Not applicable - view function

- Public access - anyone can query price protection status

- No oracle dependencies


```solidity
function getPriceProtectionStatus()
    external
    view
    returns (uint256 lastValidPrice, uint256 lastUpdateBlock, uint256 maxDeviation, uint256 minBlocks);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`lastValidPrice`|`uint256`|Last valid EUR/USD price|
|`lastUpdateBlock`|`uint256`|Block number of last price update|
|`maxDeviation`|`uint256`|Maximum allowed price deviation|
|`minBlocks`|`uint256`|Minimum blocks between price updates|


### updateFeeCollector

Updates the fee collector address

*Updates the fee collector contract address*

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
function updateFeeCollector(address _feeCollector) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_feeCollector`|`address`|New fee collector address|


### updateCollateralizationThresholds

Updates the collateralization thresholds

*Updates minimum and critical collateralization ratios*

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
function updateCollateralizationThresholds(
    uint256 _minCollateralizationRatioForMinting,
    uint256 _criticalCollateralizationRatio
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_minCollateralizationRatioForMinting`|`uint256`|New minimum collateralization ratio for minting (in basis points)|
|`_criticalCollateralizationRatio`|`uint256`|New critical collateralization ratio for liquidation (in basis points)|


### canMint

Checks if minting is allowed based on current collateralization ratio

*Returns true if collateralization ratio >= minCollateralizationRatioForMinting*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- No state changes - view function

- No events emitted - view function

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can check minting status

- No oracle dependencies


```solidity
function canMint() external returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|canMint Whether minting is currently allowed|


### shouldTriggerLiquidation

Checks if liquidation should be triggered based on current collateralization ratio

*Returns true if collateralization ratio < criticalCollateralizationRatio*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- No state changes - view function

- No events emitted - view function

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can check liquidation status

- No oracle dependencies


```solidity
function shouldTriggerLiquidation() external returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|shouldLiquidate Whether liquidation should be triggered|


### getLiquidationStatus

Returns liquidation status and key metrics for pro-rata redemption

*Protocol enters liquidation mode when CR <= 101%*

**Notes:**
- View function - no state changes

- No input validation required

- None - view function

- None

- None

- Not applicable - view function

- Public - anyone can check liquidation status

- Requires oracle price for collateral calculation


```solidity
function getLiquidationStatus()
    external
    returns (
        bool isInLiquidation,
        uint256 collateralizationRatioBps,
        uint256 totalCollateralUsdc,
        uint256 totalQeuroSupply
    );
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isInLiquidation`|`bool`|True if protocol is in liquidation mode|
|`collateralizationRatioBps`|`uint256`|Current CR in basis points|
|`totalCollateralUsdc`|`uint256`|Total protocol collateral in USDC (6 decimals)|
|`totalQeuroSupply`|`uint256`|Total QEURO supply (18 decimals)|


### calculateLiquidationPayout

Calculates pro-rata payout for liquidation mode redemption

*Formula: payout = (qeuroAmount / totalSupply) * totalCollateral*

**Notes:**
- View function - no state changes

- Validates qeuroAmount > 0

- None - view function

- None

- Throws InvalidAmount if qeuroAmount is 0

- Not applicable - view function

- Public - anyone can calculate payout

- Requires oracle price for fair value calculation


```solidity
function calculateLiquidationPayout(uint256 qeuroAmount)
    external
    returns (uint256 usdcPayout, bool isPremium, uint256 premiumOrDiscountBps);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount of QEURO to redeem (18 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`usdcPayout`|`uint256`|Amount of USDC the user would receive (6 decimals)|
|`isPremium`|`bool`|True if payout > fair value (CR > 100%)|
|`premiumOrDiscountBps`|`uint256`|Premium or discount in basis points|


### redeemQEUROLiquidation

Redeems QEURO for USDC using pro-rata distribution in liquidation mode

*Only callable when protocol is in liquidation mode (CR <= 101%)*

**Notes:**
- Protected by nonReentrant, requires liquidation mode

- Validates qeuroAmount > 0, minUsdcOut slippage, liquidation mode

- Burns QEURO, transfers USDC pro-rata

- Emits LiquidationRedeemed

- Reverts if not in liquidation mode or slippage exceeded

- Protected by nonReentrant modifier

- Public - anyone with QEURO can redeem

- Requires oracle price for collateral calculation


```solidity
function redeemQEUROLiquidation(uint256 qeuroAmount, uint256 minUsdcOut) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount of QEURO to redeem (18 decimals)|
|`minUsdcOut`|`uint256`|Minimum USDC expected (slippage protection)|


### getProtocolCollateralizationRatio

Calculates the current protocol collateralization ratio

*Returns ratio in basis points (e.g., 10500 = 105%)*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- No state changes - view function

- No events emitted - view function

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can check collateralization ratio

- Requires fresh oracle price data (via HedgerPool)


```solidity
function getProtocolCollateralizationRatio() external returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|ratio Current collateralization ratio in basis points|


### updatePriceCache

Updates the price cache with the current oracle price

*Allows governance to manually refresh the price cache*

**Notes:**
- Only callable by governance role

- Validates oracle price is valid before updating cache

- Updates lastValidEurUsdPrice, lastPriceUpdateBlock, and lastPriceUpdateTime

- Emits PriceCacheUpdated event

- Reverts if oracle price is invalid

- Not applicable - no external calls after state changes

- Restricted to GOVERNANCE_ROLE

- Requires valid oracle price


```solidity
function updatePriceCache() external;
```

### deployUsdcToAave

Deploys USDC from the vault to Aave for yield generation

*Called by UserPool after minting QEURO to automatically deploy USDC to Aave*

**Notes:**
- Only callable by VAULT_OPERATOR_ROLE (UserPool)

- Validates amount > 0, AaveVault is set, and sufficient USDC balance

- Updates totalUsdcHeld (decreases) and totalUsdcInAave (increases)

- Emits UsdcDeployedToAave event

- Reverts if amount is 0, AaveVault not set, or insufficient USDC

- Protected by nonReentrant modifier

- Restricted to VAULT_OPERATOR_ROLE

- No oracle dependencies


```solidity
function deployUsdcToAave(uint256 usdcAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC to deploy to Aave (6 decimals)|


### updateAaveVault

Updates the AaveVault address for USDC yield generation

*Only governance role can update the AaveVault address*

**Notes:**
- Validates address is not zero before updating

- Ensures _aaveVault is not address(0)

- Updates aaveVault state variable

- Emits AaveVaultUpdated event

- Reverts if _aaveVault is address(0)

- No reentrancy risk, simple state update

- Restricted to GOVERNANCE_ROLE

- No oracle dependencies


```solidity
function updateAaveVault(address _aaveVault) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_aaveVault`|`address`|New AaveVault address|


### aaveVault

Returns the AaveVault contract address

*The AaveVault contract for USDC yield generation*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query aaveVault address

- No oracle dependencies


```solidity
function aaveVault() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Address of the AaveVault contract|


### totalUsdcInAave

Returns the total USDC deployed to Aave

*Tracks USDC that has been sent to AaveVault for yield generation*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can query total USDC in Aave

- No oracle dependencies


```solidity
function totalUsdcInAave() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total USDC in Aave (6 decimals)|


### VAULT_OPERATOR_ROLE

Returns the vault operator role identifier

*Role that can trigger Aave deployments (assigned to UserPool)*

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
function VAULT_OPERATOR_ROLE() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The vault operator role bytes32 identifier|


