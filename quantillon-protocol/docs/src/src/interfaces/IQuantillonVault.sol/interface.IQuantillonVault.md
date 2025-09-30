# IQuantillonVault
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/8526548ebebe4cec60f21492516bc5894f11137e/src/interfaces/IQuantillonVault.sol)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Interface for the Quantillon vault managing QEURO mint/redeem against USDC

*Exposes core swap functions, views, governance, emergency, and recovery*

**Note:**
security-contact: team@quantillon.money


## Functions
### initialize

Initializes the vault

*Sets up the vault with initial configuration and assigns roles to admin*

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
function initialize(
    address admin,
    address _qeuro,
    address _usdc,
    address _oracle,
    address _hedgerPool,
    address _userPool,
    address _timelock
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


### mintQEURO

Mints QEURO by swapping USDC

*Converts USDC to QEURO using current oracle price with slippage protection*

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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

*Uses current oracle price to calculate QEURO equivalent without executing swap*

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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


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

Unpauses the vault

*Resumes all vault operations after emergency pause*

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

### recoverToken

Recovers ERC20 tokens sent by mistake

*Allows governance to recover accidentally sent ERC20 tokens*

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
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address|
|`to`|`address`|Recipient|
|`amount`|`uint256`|Amount to transfer|


### recoverETH

Recovers ETH sent by mistake

*Allows governance to recover accidentally sent ETH*

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

### hasRole

Checks if an account has a specific role

*Returns true if the account has been granted the role*

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
|`<none>`|`bool`|True if the account has the role|


### getRoleAdmin

Gets the admin role for a given role

*Returns the role that is the admin of the given role*

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
|`<none>`|`bytes32`|The admin role|


### grantRole

Grants a role to an account

*Can only be called by an account with the admin role*

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

Revokes a role from an account

*Can only be called by an account with the admin role*

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

Renounces a role from the caller

*The caller gives up their own role*

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
|`callerConfirmation`|`address`|Confirmation that the caller is renouncing their own role|


### paused

Checks if the contract is paused

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
|`<none>`|`bool`|True if paused, false otherwise|


### upgradeTo

Upgrades the contract to a new implementation

*Can only be called by accounts with UPGRADER_ROLE*

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
|`newImplementation`|`address`|Address of the new implementation contract|


### upgradeToAndCall

Upgrades the contract to a new implementation and calls a function

*Can only be called by accounts with UPGRADER_ROLE*

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
|`newImplementation`|`address`|Address of the new implementation contract|
|`data`|`bytes`|Encoded function call data|


### GOVERNANCE_ROLE

Returns the governance role identifier

*Role that can update vault parameters and governance functions*

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query role identifier

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query role identifier

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query role identifier

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query token address

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query token address

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query oracle address

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query minting fee

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query redemption fee

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query total USDC held

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query total QEURO minted

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can check collateralization status

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query minimum ratio

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can query user pool address

- oracle: No oracle dependencies


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
- security: Validates caller is HedgerPool contract and amount is positive

- validation: Validates amount > 0 and caller is authorized HedgerPool

- state-changes: Updates totalUsdcHeld with hedger deposit amount

- events: Emits HedgerDepositAdded with deposit details

- errors: Throws "Vault: Only HedgerPool can call" if caller is not HedgerPool

- errors: Throws "Vault: Amount must be positive" if amount is zero

- reentrancy: Protected by nonReentrant modifier

- access: Restricted to HedgerPool contract only

- oracle: No oracle dependencies


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
- security: Validates caller is HedgerPool, amount is positive, and sufficient reserves

- validation: Validates amount > 0, caller is authorized, and totalUsdcHeld >= amount

- state-changes: Updates totalUsdcHeld and transfers USDC to hedger

- events: Emits HedgerDepositWithdrawn with withdrawal details

- errors: Throws "Vault: Only HedgerPool can call" if caller is not HedgerPool

- errors: Throws "Vault: Amount must be positive" if amount is zero

- errors: Throws "Vault: Insufficient USDC reserves" if not enough USDC available

- reentrancy: Protected by nonReentrant modifier

- access: Restricted to HedgerPool contract only

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not applicable - view function

- access: Public access - anyone can query total USDC held

- oracle: No oracle dependencies


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to GOVERNANCE_ROLE

- oracle: No oracle dependencies


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
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to GOVERNANCE_ROLE

- oracle: No oracle dependencies


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
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not applicable - view function

- access: Public access - anyone can query price protection status

- oracle: No oracle dependencies


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


