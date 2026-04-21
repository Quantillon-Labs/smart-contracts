# IQuantillonVault
**Title:**
IQuantillonVault

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Interface for the Quantillon vault managing QEURO mint/redeem against USDC

Exposes core swap functions, views, governance, emergency, and recovery

**Note:**
security-contact: team@quantillon.money


## Functions
### initialize

Initializes the vault

Sets up the vault with initial configuration and assigns roles to admin

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

Converts USDC to QEURO using current oracle price with slippage protection

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


### mintQEUROToVault

Mints QEURO and routes resulting principal toward a specific vault id.

Variant of mint flow with explicit external-vault routing control.

**Notes:**
- security: Protected by implementation pause/reentrancy controls.

- validation: Implementations validate vault id state and slippage/oracle checks.

- state-changes: Updates mint accounting and optional external-vault principal allocation.

- events: Emits mint and potentially vault-deployment events in implementation.

- errors: Reverts on invalid routing, slippage, oracle, or collateralization failures.

- reentrancy: Implementation is expected to guard with `nonReentrant`.

- access: Public.

- oracle: Requires fresh oracle price data.


```solidity
function mintQEUROToVault(uint256 usdcAmount, uint256 minQeuroOut, uint256 vaultId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC to swap.|
|`minQeuroOut`|`uint256`|Minimum QEURO expected (slippage protection).|
|`vaultId`|`uint256`|Target vault id for principal routing (`0` disables explicit routing).|


### mintAndStakeQEURO

Mints QEURO and stakes it into the stQEURO token for a selected vault id.

One-step user flow combining mint and stake operations.

**Notes:**
- security: Protected by implementation pause/reentrancy controls.

- validation: Implementations validate vault/token availability and slippage constraints.

- state-changes: Updates mint and staking state across integrated contracts.

- events: Emits mint/staking events in implementation and downstream contracts.

- errors: Reverts on invalid vault, slippage, or integration failures.

- reentrancy: Implementation is expected to guard with `nonReentrant`.

- access: Public.

- oracle: Requires fresh oracle price data for mint.


```solidity
function mintAndStakeQEURO(uint256 usdcAmount, uint256 minQeuroOut, uint256 vaultId, uint256 minStQEUROOut)
    external
    returns (uint256 qeuroMinted, uint256 stQEUROMinted);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC to swap.|
|`minQeuroOut`|`uint256`|Minimum QEURO expected from mint.|
|`vaultId`|`uint256`|Target vault id for mint routing and stQEURO token selection.|
|`minStQEUROOut`|`uint256`|Minimum stQEURO expected from staking.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`qeuroMinted`|`uint256`|QEURO minted before staking.|
|`stQEUROMinted`|`uint256`|stQEURO minted and returned to user.|


### creditVaultYield

Credits harvested user yield into a vault-specific stQEURO series.

Converts harvested USDC yield into QEURO using the vault minting path and deposits the resulting backing directly into the target stQEURO vault.

**Notes:**
- security: Restricted in implementation to authorized yield distributors and validated vault bindings.

- validation: Implementations validate vault registration, non-zero amounts, and fee/oracle constraints before crediting yield.

- state-changes: Pulls or accounts for harvested USDC, mints QEURO backing, updates protocol accounting, and increases the target vault's asset balance.

- events: Emits implementation-defined yield crediting and mint-related events.

- errors: Reverts on invalid vault ids, zero amounts, oracle failures, or downstream minting/transfer failures.

- reentrancy: Implementation is expected to guard integrated token-transfer flows.

- access: Restricted in implementation to a dedicated yield-distributor permission.

- oracle: Requires fresh oracle price data for USDC-to-QEURO conversion.


```solidity
function creditVaultYield(uint256 vaultId, uint256 usdcAmount) external returns (uint256 qeuroMinted);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vaultId`|`uint256`|Vault identifier receiving the compounded yield.|
|`usdcAmount`|`uint256`|User-side harvested yield in USDC.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`qeuroMinted`|`uint256`|Net QEURO minted into the stQEURO vault.|


### redeemQEURO

Redeems QEURO for USDC

Converts QEURO (18 decimals) to USDC (6 decimals) using oracle price

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

Provides comprehensive vault statistics for monitoring and analysis

**Notes:**
- security: Read-only helper

- validation: None

- state-changes: None

- events: None

- errors: None

- reentrancy: Not applicable

- access: Public

- oracle: Uses cached oracle price for debt-value conversion


```solidity
function getVaultMetrics()
    external
    view
    returns (
        uint256 totalUsdcHeld_,
        uint256 totalMinted_,
        uint256 totalDebtValue,
        uint256 totalUsdcInExternalVaults_,
        uint256 totalUsdcAvailable_
    );
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalUsdcHeld_`|`uint256`|Total USDC held directly in the vault|
|`totalMinted_`|`uint256`|Total QEURO minted|
|`totalDebtValue`|`uint256`|Total debt value in USD|
|`totalUsdcInExternalVaults_`|`uint256`|Total USDC principal deployed across external vault adapters|
|`totalUsdcAvailable_`|`uint256`|Total USDC available (vault + external adapters)|


### calculateMintAmount

Computes QEURO mint amount for a USDC swap

Uses cached oracle price to calculate QEURO equivalent without executing swap

**Notes:**
- security: Read-only helper

- validation: Returns zeroes when price cache is uninitialized

- state-changes: None

- events: None

- errors: None

- reentrancy: Not applicable

- access: Public

- oracle: Uses cached oracle price only


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

Uses cached oracle price to calculate USDC equivalent without executing swap

**Notes:**
- security: Read-only helper

- validation: Returns zeroes when price cache is uninitialized

- state-changes: None

- events: None

- errors: None

- reentrancy: Not applicable

- access: Public

- oracle: Uses cached oracle price only


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

Allows governance to update fee parameters for minting and redemption

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
|`_mintFee`|`uint256`|New minting fee (1e18-scaled, where 1e18 = 100%)|
|`_redemptionFee`|`uint256`|New redemption fee (1e18-scaled, where 1e18 = 100%)|


### updateOracle

Updates the oracle address

Allows governance to update the price oracle used for conversions

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

Allows governance to withdraw accumulated fees to specified address

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

Emergency function to pause all vault operations

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

Resumes all vault operations after emergency pause

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

Allows governance to recover accidentally sent ERC20 tokens to treasury

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
function recoverToken(address token, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address|
|`amount`|`uint256`|Amount to transfer|


### recoverETH

Recovers ETH sent by mistake

Allows governance to recover accidentally sent ETH

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

Returns true if the account has been granted the role

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

Returns the role that is the admin of the given role

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

Can only be called by an account with the admin role

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

Can only be called by an account with the admin role

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

The caller gives up their own role

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

Returns true if the contract is currently paused

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

Can only be called by accounts with UPGRADER_ROLE

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

Can only be called by accounts with UPGRADER_ROLE

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

Role that can update vault parameters and governance functions

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

Role that can pause the vault and perform emergency operations

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

Role that can upgrade the contract implementation

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

The euro-pegged stablecoin token managed by this vault

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

The collateral token used for minting QEURO

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

The price oracle used for EUR/USD conversions

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

Fee charged when minting QEURO with USDC (1e18-scaled, where 1e16 = 1%)

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
|`<none>`|`uint256`|The minting fee as a 1e18-scaled percentage|


### redemptionFee

Returns the current redemption fee

Fee charged when redeeming QEURO for USDC (1e18-scaled, where 1e16 = 1%)

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
|`<none>`|`uint256`|The redemption fee as a 1e18-scaled percentage|


### totalUsdcHeld

Returns the total USDC held in the vault

Total amount of USDC collateral backing QEURO

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

Total amount of QEURO tokens in circulation

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

Public view function to check collateralization status

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

Minimum ratio required for QEURO minting (1e18-scaled percentage format)

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
|`<none>`|`uint256`|The minimum collateralization ratio in 1e18-scaled percentage format|


### userPool

Returns the UserPool contract address

The user pool contract managing user deposits

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

Called by HedgerPool when hedgers open positions to unify USDC liquidity

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

Called by HedgerPool when hedgers close positions to return their deposits

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

Returns the current total USDC held in the vault for transparency

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

Updates the HedgerPool contract address for hedger operations

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

Updates the UserPool contract address for user deposit tracking

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

Returns price protection configuration for monitoring

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


### updateFeeCollector

Updates the fee collector address

Updates the fee collector contract address

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
function updateFeeCollector(address _feeCollector) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_feeCollector`|`address`|New fee collector address|


### updateCollateralizationThresholds

Updates the collateralization thresholds

Updates minimum and critical collateralization ratios

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
function updateCollateralizationThresholds(
    uint256 _minCollateralizationRatioForMinting,
    uint256 _criticalCollateralizationRatio
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_minCollateralizationRatioForMinting`|`uint256`|New minimum collateralization ratio for minting (1e18-scaled percentage)|
|`_criticalCollateralizationRatio`|`uint256`|New critical collateralization ratio for liquidation (1e18-scaled percentage)|


### canMint

Checks if minting is allowed based on current collateralization ratio

Returns true if collateralization ratio >= minCollateralizationRatioForMinting

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: No state changes - view function

- events: No events emitted - view function

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can check minting status

- oracle: No oracle dependencies


```solidity
function canMint() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|canMint Whether minting is currently allowed|


### shouldTriggerLiquidation

Checks if liquidation should be triggered based on current collateralization ratio

Returns true if collateralization ratio < criticalCollateralizationRatio

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: No state changes - view function

- events: No events emitted - view function

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can check liquidation status

- oracle: No oracle dependencies


```solidity
function shouldTriggerLiquidation() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|shouldLiquidate Whether liquidation should be triggered|


### getLiquidationStatus

Returns liquidation status and key metrics for pro-rata redemption

Protocol enters liquidation mode when CR <= 101%

**Notes:**
- security: View function - no state changes

- validation: No input validation required

- state-changes: None - view function

- events: None

- errors: None

- reentrancy: Not applicable - view function

- access: Public - anyone can check liquidation status

- oracle: Requires oracle price for collateral calculation


```solidity
function getLiquidationStatus()
    external
    view
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

Formula: payout = (qeuroAmount / totalSupply) * totalCollateral

**Notes:**
- security: View function - no state changes

- validation: Validates qeuroAmount > 0

- state-changes: None - view function

- events: None

- errors: Throws InvalidAmount if qeuroAmount is 0

- reentrancy: Not applicable - view function

- access: Public - anyone can calculate payout

- oracle: Requires oracle price for fair value calculation


```solidity
function calculateLiquidationPayout(uint256 qeuroAmount)
    external
    view
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

Only callable when protocol is in liquidation mode (CR <= 101%)

**Notes:**
- security: Protected by nonReentrant, requires liquidation mode

- validation: Validates qeuroAmount > 0, minUsdcOut slippage, liquidation mode

- state-changes: Burns QEURO, transfers USDC pro-rata

- events: Emits LiquidationRedeemed

- errors: Reverts if not in liquidation mode or slippage exceeded

- reentrancy: Protected by nonReentrant modifier

- access: Public - anyone with QEURO can redeem

- oracle: Requires oracle price for collateral calculation


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

Returns ratio in 1e18-scaled percentage format (100% = 1e20)

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: No state changes - view function

- events: No events emitted - view function

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can check collateralization ratio

- oracle: Requires fresh oracle price data (via HedgerPool)


```solidity
function getProtocolCollateralizationRatio() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|ratio Current collateralization ratio in 1e18-scaled percentage format|


### getProtocolCollateralizationRatioView

View-only collateralization ratio using cached price.

Returns the same units as `getProtocolCollateralizationRatio()` but relies solely
on the cached EUR/USD price to remain view-safe (no external oracle calls).

**Notes:**
- security: View helper; does not mutate state or touch external oracles.

- validation: Returns a stale or sentinel value if the cache is uninitialized.

- state-changes: None – pure view over cached pricing and vault balances.

- events: None.

- errors: None – callers must handle edge cases (e.g. 0 collateral).

- reentrancy: Not applicable – view function only.

- access: Public – intended for dashboards and off‑chain monitoring.

- oracle: Uses only the last cached price maintained on-chain.


```solidity
function getProtocolCollateralizationRatioView() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|ratio Cached collateralization ratio in 1e18‑scaled percentage format.|


### canMintView

View-only mintability check using cached price and current hedger status.

Equivalent to `canMint()` but guaranteed not to perform fresh oracle reads,
making it safe for off‑chain calls that must not revert due to oracle issues.

**Notes:**
- security: Read‑only helper; never mutates state or external dependencies.

- validation: Returns false on uninitialized cache or missing hedger configuration.

- state-changes: None – pure read of cached price and protocol state.

- events: None.

- errors: None – callers interpret the boolean.

- reentrancy: Not applicable – view function only.

- access: Public – anyone can pre‑check mint conditions.

- oracle: Uses cached price only; no live oracle reads.


```solidity
function canMintView() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|canMintCached True if, based on cached price and current hedger state, minting would be allowed.|


### updatePriceCache

Updates the price cache with the current oracle price

Allows governance to manually refresh the price cache

**Notes:**
- security: Only callable by governance role

- validation: Validates oracle price is valid before updating cache

- state-changes: Updates lastValidEurUsdPrice, lastPriceUpdateBlock, and lastPriceUpdateTime

- events: Emits PriceCacheUpdated event

- errors: Reverts if oracle price is invalid

- reentrancy: Not applicable - no external calls after state changes

- access: Restricted to GOVERNANCE_ROLE

- oracle: Requires valid oracle price


```solidity
function updatePriceCache() external;
```

### initializePriceCache

Initializes the cached EUR/USD price used by view-safe query paths.

Seeds the internal cache with an explicit bootstrap price so view paths
have a baseline without performing external oracle reads in this mutating call.

**Notes:**
- security: Restricted to governance.

- validation: Reverts if `initialEurUsdPrice` is zero.

- state-changes: Writes the initial cached price and associated timestamp/blocks.

- events: Emits a price-cache initialization event in the implementation.

- errors: Reverts when cache is already initialized or input is invalid.

- reentrancy: Not applicable.

- access: Restricted to `GOVERNANCE_ROLE`.

- oracle: Bootstrap input should come from governance/oracle operations.


```solidity
function initializePriceCache(uint256 initialEurUsdPrice) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`initialEurUsdPrice`|`uint256`|Initial EUR/USD price in 18 decimals.|


### setStakingVault

Configures adapter binding and active status for a vault id.

Governance-managed registry update for external vault routing.

**Notes:**
- security: Restricted to governance in implementation.

- validation: Reverts on invalid vault id or adapter address per implementation rules.

- state-changes: Updates vault-id adapter and active-status mappings.

- events: Emits vault configuration event in implementation.

- errors: Reverts on invalid configuration values.

- reentrancy: Not typically reentrancy-sensitive.

- access: Governance-only in implementation.

- oracle: No oracle dependencies.


```solidity
function setStakingVault(uint256 vaultId, address adapter, bool active) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vaultId`|`uint256`|Vault id to configure.|
|`adapter`|`address`|Adapter contract implementing `IExternalStakingVault`.|
|`active`|`bool`|Whether the vault id should be active for routing.|


### setDefaultStakingVaultId

Sets the default vault id used for routing/fallback behavior.

`vaultId == 0` may be used to clear default routing depending on implementation.

**Notes:**
- security: Restricted to governance in implementation.

- validation: Non-zero ids are validated against active configured adapters.

- state-changes: Updates default vault-id configuration.

- events: Emits default-vault update event in implementation.

- errors: Reverts on invalid/unconfigured ids.

- reentrancy: Not reentrancy-sensitive.

- access: Governance-only in implementation.

- oracle: No oracle dependencies.


```solidity
function setDefaultStakingVaultId(uint256 vaultId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vaultId`|`uint256`|New default vault id.|


### setRedemptionPriority

Sets ordered vault ids used for redemption liquidity sourcing.

Replaces current priority ordering with provided array.

**Notes:**
- security: Restricted to governance in implementation.

- validation: Each id is validated as active/configured by implementation.

- state-changes: Updates redemption-priority configuration.

- events: Emits redemption-priority update event in implementation.

- errors: Reverts on invalid ids.

- reentrancy: Not reentrancy-sensitive.

- access: Governance-only in implementation.

- oracle: No oracle dependencies.


```solidity
function setRedemptionPriority(uint256[] calldata vaultIds) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vaultIds`|`uint256[]`|Ordered vault ids.|


### deployUsdcToVault

Deploys held USDC into a configured external vault id.

Operator flow for moving idle collateral into yield adapters.

**Notes:**
- security: Restricted to operator role in implementation.

- validation: Reverts on invalid amount, vault config, or insufficient held balance.

- state-changes: Updates held/external principal accounting and adapter position.

- events: Emits deployment event in implementation.

- errors: Reverts on adapter or accounting failures.

- reentrancy: Implementation is expected to guard with `nonReentrant`.

- access: Role-restricted in implementation.

- oracle: No oracle dependencies.


```solidity
function deployUsdcToVault(uint256 vaultId, uint256 usdcAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vaultId`|`uint256`|Target vault id.|
|`usdcAmount`|`uint256`|Amount of USDC to deploy.|


### selfRegisterStQEURO

Registers this vault into stQEUROFactory and deploys its dedicated token.

Binds the vault to a deterministic stQEURO token address and records factory linkage.

**Notes:**
- security: Intended for governance-only execution in implementation.

- validation: Implementations must validate factory address, vault id, and registration uniqueness.

- state-changes: Updates factory/token/vault-id bindings on successful registration.

- events: Emits registration event in implementation.

- errors: Reverts for invalid input, duplicate initialization, or registration mismatch.

- reentrancy: Implementation protects external registration flow with reentrancy guard.

- access: Access controlled by implementation (governance role).

- oracle: No oracle dependencies.


```solidity
function selfRegisterStQEURO(address factory, uint256 vaultId, string calldata vaultName)
    external
    returns (address token);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`factory`|`address`|Address of stQEUROFactory.|
|`vaultId`|`uint256`|Target vault id.|
|`vaultName`|`string`|Uppercase alphanumeric vault name.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Newly deployed stQEURO token address.|


### updateHedgerRewardFeeSplit

Updates the protocol‑fee share routed to HedgerPool reward reserve.

Sets the fraction of protocol fees (scaled by 1e18 where 1e18 = 100%)
that is forwarded to HedgerPool’s reward reserve instead of remaining in the vault.

**Notes:**
- security: Only callable by governance; misconfiguration can starve protocol or hedgers.

- validation: Implementation validates that `newSplit` is within acceptable bounds.

- state-changes: Updates internal accounting for how fees are split on collection.

- events: Emits an event in the implementation describing the new split.

- errors: Reverts on invalid split values as defined by implementation.

- reentrancy: Not applicable – configuration only, no external transfers.

- access: Restricted to `GOVERNANCE_ROLE`.

- oracle: No direct oracle dependency.


```solidity
function updateHedgerRewardFeeSplit(uint256 newSplit) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newSplit`|`uint256`|New fee‑share value (1e18‑scaled, 0–1e18 allowed by implementation).|


### harvestVaultYield

Harvests yield from a configured external vault id.

Governance-triggered adapter harvest operation.

**Notes:**
- security: Restricted to governance in implementation.

- validation: Reverts when vault id is invalid/inactive or adapter is unset.

- state-changes: May update adapter and downstream yield accounting.

- events: Emits vault-yield harvested event in implementation.

- errors: Reverts on configuration or adapter failures.

- reentrancy: Implementation is expected to guard with `nonReentrant`.

- access: Governance-only in implementation.

- oracle: No direct oracle dependency.


```solidity
function harvestVaultYield(uint256 vaultId) external returns (uint256 harvestedYield);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vaultId`|`uint256`|Vault id to harvest.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`harvestedYield`|`uint256`|Yield harvested in USDC units.|


### getVaultExposure

Returns exposure snapshot for a vault id.

Includes adapter address, active status, tracked principal, and current underlying read.

**Notes:**
- security: Read-only helper.

- validation: No additional validation required.

- state-changes: No state changes.

- events: No events emitted.

- errors: No explicit errors expected by interface contract.

- reentrancy: Not applicable for view function.

- access: Public view.

- oracle: No oracle dependencies.


```solidity
function getVaultExposure(uint256 vaultId)
    external
    view
    returns (address adapter, bool active, uint256 principalTracked, uint256 currentUnderlying);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vaultId`|`uint256`|Vault id to query.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`adapter`|`address`|Adapter address bound to vault id.|
|`active`|`bool`|Whether the vault id is active.|
|`principalTracked`|`uint256`|Principal tracked locally for vault id.|
|`currentUnderlying`|`uint256`|Current underlying balance from adapter (implementation may fallback).|


### defaultStakingVaultId

Returns configured default staking vault id.

Used by clients to infer default mint routing.

**Notes:**
- security: Read-only accessor.

- validation: No input validation required.

- state-changes: No state changes.

- events: No events emitted.

- errors: No errors expected.

- reentrancy: Not applicable for view function.

- access: Public view.

- oracle: No oracle dependencies.


```solidity
function defaultStakingVaultId() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Default vault id (`0` when unset).|


### totalUsdcInExternalVaults

Returns total principal tracked across external vault adapters.

Aggregated accounting metric for externally deployed USDC.

**Notes:**
- security: Read-only accessor.

- validation: No input validation required.

- state-changes: No state changes.

- events: No events emitted.

- errors: No errors expected.

- reentrancy: Not applicable for view function.

- access: Public view.

- oracle: No oracle dependencies.


```solidity
function totalUsdcInExternalVaults() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total USDC principal tracked in external vaults.|


### stQEUROFactory

Returns configured stQEUROFactory address.

Read-only accessor for the factory bound to this vault instance.

**Notes:**
- security: Read-only accessor.

- validation: No input validation required.

- state-changes: No state changes.

- events: No events emitted.

- errors: No errors expected.

- reentrancy: Not applicable for view function.

- access: Public view.

- oracle: No oracle dependencies.


```solidity
function stQEUROFactory() external view returns (address);
```

### stQEUROTokenByVaultId

Returns stQEURO token address bound to a vault id.

Mapping accessor for vault-id-to-stQEURO token identity.

**Notes:**
- security: Read-only accessor.

- validation: No input validation required; unknown ids return zero address.

- state-changes: No state changes.

- events: No events emitted.

- errors: No errors expected.

- reentrancy: Not applicable for view function.

- access: Public view.

- oracle: No oracle dependencies.


```solidity
function stQEUROTokenByVaultId(uint256 vaultId) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vaultId`|`uint256`|Vault identifier.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|stQEURO token address bound to `vaultId` (or zero if unset).|


### VAULT_OPERATOR_ROLE

Returns the vault operator role identifier

Role that can trigger Aave deployments (assigned to UserPool)

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
function VAULT_OPERATOR_ROLE() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The vault operator role bytes32 identifier|


