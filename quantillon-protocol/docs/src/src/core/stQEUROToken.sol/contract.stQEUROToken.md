# stQEUROToken
**Inherits:**
Initializable, ERC4626Upgradeable, AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, [SecureUpgradeable](/src/core/SecureUpgradeable.sol/abstract.SecureUpgradeable.md)

**Title:**
stQEUROToken

ERC-4626 vault over QEURO used for per-vault staking series.


## State Variables
### GOVERNANCE_ROLE

```solidity
bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE")
```


### EMERGENCY_ROLE

```solidity
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE")
```


### qeuro

```solidity
IQEUROToken public qeuro
```


### treasury

```solidity
address public treasury
```


### vaultName

```solidity
string public vaultName
```


### yieldFee

```solidity
uint256 public yieldFee
```


### TIME_PROVIDER

```solidity
TimeProvider public immutable TIME_PROVIDER
```


## Functions
### constructor

Constructs the implementation contract with its immutable time provider.

Validates the provided time provider, stores it immutably, and disables initializers on the implementation.

**Notes:**
- security: Rejects zero-address dependencies before deployment completes.

- validation: Ensures `_TIME_PROVIDER` is non-zero.

- state-changes: Sets the immutable `TIME_PROVIDER` reference and disables future initializers on the implementation.

- events: None.

- errors: Reverts with `ZeroAddress` when `_TIME_PROVIDER` is the zero address.

- reentrancy: Not applicable.

- access: Deployment only.

- oracle: Not applicable.

- oz-upgrades-unsafe-allow: constructor


```solidity
constructor(TimeProvider _TIME_PROVIDER) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_TIME_PROVIDER`|`TimeProvider`|Time provider used by inherited secure upgrade and timelock logic.|


### initialize

Initializes the default stQEURO vault series without a vault suffix.

Keeps the legacy initializer shape for factory compatibility, ignores unused placeholder addresses, and wires the ERC-4626 vault over QEURO.

**Notes:**
- security: Uses OpenZeppelin initializer guards and validates all named dependencies before role grants.

- validation: Ensures admin, token, treasury, and timelock dependencies are valid for vault setup.

- state-changes: Initializes ERC-20/ERC-4626 metadata, role assignments, treasury configuration, and the vault asset reference.

- events: Emits initialization events through inherited OpenZeppelin modules when applicable.

- errors: Reverts on duplicate initialization or invalid dependency addresses.

- reentrancy: Not applicable during initialization.

- access: Callable once during deployment.

- oracle: Not applicable.


```solidity
function initialize(address admin, address _qeuro, address, address, address _treasury, address _timelock)
    public
    initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address receiving admin, governance, and emergency roles.|
|`_qeuro`|`address`|QEURO token used as the ERC-4626 underlying asset.|
|`<none>`|`address`||
|`<none>`|`address`||
|`_treasury`|`address`|Treasury that receives recovered assets and fees.|
|`_timelock`|`address`|Timelock used by inherited secure upgrade controls.|


### initialize

Initializes a vault-specific stQEURO series with custom metadata.

Builds vault-specific ERC-20 metadata, sets the ERC-4626 asset to QEURO, and applies secure-role configuration.

**Notes:**
- security: Uses initializer guards and validates critical dependency addresses before activation.

- validation: Ensures named dependencies are non-zero and treasury configuration is valid.

- state-changes: Initializes ERC-20/ERC-4626 metadata, stores `vaultName`, and grants operational roles.

- events: Emits initialization events through inherited OpenZeppelin modules when applicable.

- errors: Reverts on duplicate initialization or invalid dependency addresses.

- reentrancy: Not applicable during initialization.

- access: Callable once during deployment.

- oracle: Not applicable.


```solidity
function initialize(address admin, address _qeuro, address _treasury, address _timelock, string calldata _vaultName)
    public
    initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address receiving admin, governance, and emergency roles.|
|`_qeuro`|`address`|QEURO token used as the ERC-4626 underlying asset.|
|`_treasury`|`address`|Treasury that receives recovered assets and fees.|
|`_timelock`|`address`|Timelock used by inherited secure upgrade controls.|
|`_vaultName`|`string`|Vault suffix appended to the share-token name and symbol.|


### _initializeStQEURODependencies

Applies the shared dependency and role setup for all stQEURO vault series.

Initializes inherited access-control, pause, reentrancy, and secure-upgrade modules, then stores treasury and QEURO references.

**Notes:**
- security: Centralizes all critical dependency validation before privileged roles are granted.

- validation: Requires non-zero admin/token/treasury addresses and a valid treasury destination.

- state-changes: Initializes inherited modules, grants roles, stores token/treasury references, and resets `yieldFee` to zero.

- events: Emits inherited role/admin initialization events when applicable.

- errors: Reverts on invalid addresses or treasury configuration failures.

- reentrancy: Not applicable.

- access: Internal initialization helper.

- oracle: Not applicable.


```solidity
function _initializeStQEURODependencies(
    address admin,
    address qeuroAddress,
    address treasuryAddress,
    address timelockAddress
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address receiving admin, governance, and emergency roles.|
|`qeuroAddress`|`address`|Address of the QEURO underlying asset.|
|`treasuryAddress`|`address`|Treasury destination for recovered funds.|
|`timelockAddress`|`address`|Timelock used by the inherited secure-upgrade module.|


### maxDeposit

Returns the maximum assets a receiver can deposit while respecting pause state.

Returns zero when the vault is paused and otherwise delegates limit calculation to the ERC-4626 parent implementation.

**Notes:**
- security: Read-only helper.

- validation: Paused state forces a zero limit.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: Not applicable.


```solidity
function maxDeposit(address receiver) public view override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`receiver`|`address`|Address that would receive minted stQEURO shares.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|maxAssets Maximum QEURO assets currently depositable for `receiver`.|


### maxMint

Returns the maximum shares a receiver can mint while respecting pause state.

Returns zero when the vault is paused and otherwise delegates limit calculation to the ERC-4626 parent implementation.

**Notes:**
- security: Read-only helper.

- validation: Paused state forces a zero limit.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: Not applicable.


```solidity
function maxMint(address receiver) public view override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`receiver`|`address`|Address that would receive minted stQEURO shares.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|maxShares Maximum stQEURO shares currently mintable for `receiver`.|


### maxWithdraw

Returns the maximum assets an owner can withdraw while respecting pause state.

Returns zero when the vault is paused and otherwise delegates limit calculation to the ERC-4626 parent implementation.

**Notes:**
- security: Read-only helper.

- validation: Paused state forces a zero limit.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: Not applicable.


```solidity
function maxWithdraw(address owner) public view override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|Share owner whose withdraw capacity is being queried.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|maxAssets Maximum QEURO assets currently withdrawable by `owner`.|


### maxRedeem

Returns the maximum shares an owner can redeem while respecting pause state.

Returns zero when the vault is paused and otherwise delegates limit calculation to the ERC-4626 parent implementation.

**Notes:**
- security: Read-only helper.

- validation: Paused state forces a zero limit.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: Not applicable.

- access: Public.

- oracle: Not applicable.


```solidity
function maxRedeem(address owner) public view override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|Share owner whose redeem capacity is being queried.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|maxShares Maximum stQEURO shares currently redeemable by `owner`.|


### deposit

Deposits QEURO into the vault and mints stQEURO shares to a receiver.

Wraps the ERC-4626 deposit flow with pause and reentrancy protection.

**Notes:**
- security: Protected by pause and `nonReentrant` guards.

- validation: Delegates asset, allowance, and receiver checks to ERC-4626/ERC-20 logic.

- state-changes: Transfers QEURO into the vault and mints new stQEURO shares.

- events: Emits the standard ERC-4626 `Deposit` event.

- errors: Reverts when paused or when ERC-20/ERC-4626 validations fail.

- reentrancy: Protected by `nonReentrant`.

- access: Public.

- oracle: Not applicable.


```solidity
function deposit(uint256 assets, address receiver)
    public
    override
    nonReentrant
    whenNotPaused
    returns (uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|Amount of QEURO assets to deposit.|
|`receiver`|`address`|Address receiving newly minted stQEURO shares.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|Amount of stQEURO shares minted for `receiver`.|


### mint

Mints a target amount of stQEURO shares by supplying the required QEURO assets.

Wraps the ERC-4626 mint flow with pause and reentrancy protection.

**Notes:**
- security: Protected by pause and `nonReentrant` guards.

- validation: Delegates share, allowance, and receiver checks to ERC-4626/ERC-20 logic.

- state-changes: Transfers QEURO into the vault and mints stQEURO shares.

- events: Emits the standard ERC-4626 `Deposit` event.

- errors: Reverts when paused or when ERC-20/ERC-4626 validations fail.

- reentrancy: Protected by `nonReentrant`.

- access: Public.

- oracle: Not applicable.


```solidity
function mint(uint256 shares, address receiver)
    public
    override
    nonReentrant
    whenNotPaused
    returns (uint256 assets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|Amount of stQEURO shares to mint.|
|`receiver`|`address`|Address receiving the minted shares.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|Amount of QEURO assets pulled from the caller.|


### withdraw

Withdraws a target amount of QEURO assets from the vault.

Wraps the ERC-4626 withdraw flow with pause and reentrancy protection.

**Notes:**
- security: Protected by pause and `nonReentrant` guards.

- validation: Delegates asset, allowance, and balance checks to ERC-4626/ERC-20 logic.

- state-changes: Burns stQEURO shares and transfers QEURO assets out of the vault.

- events: Emits the standard ERC-4626 `Withdraw` event.

- errors: Reverts when paused or when ERC-20/ERC-4626 validations fail.

- reentrancy: Protected by `nonReentrant`.

- access: Public.

- oracle: Not applicable.


```solidity
function withdraw(uint256 assets, address receiver, address owner)
    public
    override
    nonReentrant
    whenNotPaused
    returns (uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|Amount of QEURO assets to withdraw.|
|`receiver`|`address`|Address receiving the withdrawn QEURO.|
|`owner`|`address`|Share owner whose balance and allowance are consumed.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|Amount of stQEURO shares burned to complete the withdrawal.|


### redeem

Redeems stQEURO shares for their corresponding QEURO assets.

Wraps the ERC-4626 redeem flow with pause and reentrancy protection.

**Notes:**
- security: Protected by pause and `nonReentrant` guards.

- validation: Delegates share, allowance, and balance checks to ERC-4626/ERC-20 logic.

- state-changes: Burns stQEURO shares and transfers QEURO assets out of the vault.

- events: Emits the standard ERC-4626 `Withdraw` event.

- errors: Reverts when paused or when ERC-20/ERC-4626 validations fail.

- reentrancy: Protected by `nonReentrant`.

- access: Public.

- oracle: Not applicable.


```solidity
function redeem(uint256 shares, address receiver, address owner)
    public
    override
    nonReentrant
    whenNotPaused
    returns (uint256 assets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|Amount of stQEURO shares to redeem.|
|`receiver`|`address`|Address receiving the redeemed QEURO.|
|`owner`|`address`|Share owner whose balance and allowance are consumed.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|Amount of QEURO assets transferred to `receiver`.|


### transfer

Transfers stQEURO shares while the vault is active.

Blocks share transfers whenever the vault is paused.

**Notes:**
- security: Protected by the pause guard.

- validation: Delegates recipient, balance, and amount checks to ERC-20 logic.

- state-changes: Moves stQEURO share balances between accounts.

- events: Emits the standard ERC-20 `Transfer` event.

- errors: Reverts when paused or when ERC-20 validations fail.

- reentrancy: Not applicable.

- access: Public.

- oracle: Not applicable.


```solidity
function transfer(address to, uint256 value)
    public
    override(ERC20Upgradeable, IERC20)
    whenNotPaused
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Recipient of the transferred stQEURO shares.|
|`value`|`uint256`|Amount of stQEURO shares to transfer.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|success True when the transfer succeeds.|


### transferFrom

Transfers stQEURO shares from another account while the vault is active.

Blocks allowance-based share transfers whenever the vault is paused.

**Notes:**
- security: Protected by the pause guard.

- validation: Delegates allowance, recipient, balance, and amount checks to ERC-20 logic.

- state-changes: Moves stQEURO share balances between accounts and updates allowance when applicable.

- events: Emits the standard ERC-20 `Transfer` event and allowance events when applicable.

- errors: Reverts when paused or when ERC-20 validations fail.

- reentrancy: Not applicable.

- access: Public.

- oracle: Not applicable.


```solidity
function transferFrom(address from, address to, uint256 value)
    public
    override(ERC20Upgradeable, IERC20)
    whenNotPaused
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Account whose share balance and allowance are consumed.|
|`to`|`address`|Recipient of the transferred stQEURO shares.|
|`value`|`uint256`|Amount of stQEURO shares to transfer.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|success True when the transfer succeeds.|


### updateYieldParameters

Updates the yield fee charged on compounded vault yield.

Governance can set the fee in basis points up to the configured 20% cap.

**Notes:**
- security: Restricted to `GOVERNANCE_ROLE`.

- validation: Validates `_yieldFee` against the 2000 bps maximum.

- state-changes: Updates the stored `yieldFee`.

- events: Emits `YieldParametersUpdated`.

- errors: Reverts on invalid fee values or missing governance role.

- reentrancy: Not applicable.

- access: Restricted to `GOVERNANCE_ROLE`.

- oracle: Not applicable.


```solidity
function updateYieldParameters(uint256 _yieldFee) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_yieldFee`|`uint256`|New yield fee in basis points.|


### updateTreasury

Updates the treasury destination used for recovery flows.

Governance can rotate the treasury after standard non-zero and treasury-address validation passes.

**Notes:**
- security: Restricted to `GOVERNANCE_ROLE`.

- validation: Requires a non-zero address that passes treasury validation rules.

- state-changes: Replaces the stored `treasury` address.

- events: Emits `TreasuryUpdated`.

- errors: Reverts on invalid treasury addresses or missing governance role.

- reentrancy: Not applicable.

- access: Restricted to `GOVERNANCE_ROLE`.

- oracle: Not applicable.


```solidity
function updateTreasury(address _treasury) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_treasury`|`address`|New treasury address.|


### pause

Pauses deposits, withdrawals, redemptions, and share transfers.

Emergency role can freeze vault interactions until the pause is lifted.

**Notes:**
- security: Restricted to `EMERGENCY_ROLE`.

- validation: None.

- state-changes: Sets the paused state to true.

- events: Emits the inherited `Paused` event.

- errors: Reverts on missing emergency role or if already paused.

- reentrancy: Not applicable.

- access: Restricted to `EMERGENCY_ROLE`.

- oracle: Not applicable.


```solidity
function pause() external onlyRole(EMERGENCY_ROLE);
```

### unpause

Unpauses deposits, withdrawals, redemptions, and share transfers.

Emergency role can resume normal vault operation after a pause.

**Notes:**
- security: Restricted to `EMERGENCY_ROLE`.

- validation: None.

- state-changes: Sets the paused state to false.

- events: Emits the inherited `Unpaused` event.

- errors: Reverts on missing emergency role or if the vault is not paused.

- reentrancy: Not applicable.

- access: Restricted to `EMERGENCY_ROLE`.

- oracle: Not applicable.


```solidity
function unpause() external onlyRole(EMERGENCY_ROLE);
```

### emergencyWithdraw

Forces a full emergency redemption of a user's stQEURO position.

Emergency role can burn all of a user's shares and transfer the current redeemable QEURO balance directly to that user.

**Notes:**
- security: Restricted to `EMERGENCY_ROLE` and protected by `nonReentrant`.

- validation: Returns early when `user` holds no shares.

- state-changes: Burns the user's full share balance and transfers corresponding QEURO assets out of the vault.

- events: Emits the standard ERC-4626 `Withdraw` event when shares are burned.

- errors: Reverts on missing emergency role or failed asset transfer.

- reentrancy: Protected by `nonReentrant`.

- access: Restricted to `EMERGENCY_ROLE`.

- oracle: Not applicable.


```solidity
function emergencyWithdraw(address user) external onlyRole(EMERGENCY_ROLE) nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Account whose full vault position is being unwound.|


### recoverToken

Recovers non-QEURO ERC-20 tokens mistakenly sent to the vault.

Admin-only recovery route forwards unsupported tokens to the configured treasury and explicitly forbids recovering the underlying asset.

**Notes:**
- security: Restricted to `DEFAULT_ADMIN_ROLE` and blocks recovery of the vault's underlying asset.

- validation: Requires `token` to differ from `asset()`.

- state-changes: Transfers the specified token amount from the vault to the treasury.

- events: Emits downstream ERC-20 `Transfer` events from the recovered token.

- errors: Reverts on invalid token selection, failed transfers, or missing admin role.

- reentrancy: Not applicable.

- access: Restricted to `DEFAULT_ADMIN_ROLE`.

- oracle: Not applicable.


```solidity
function recoverToken(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|ERC-20 token address to recover.|
|`amount`|`uint256`|Amount of tokens to recover.|


### recoverETH

Recovers native ETH held by the vault and forwards it to the treasury.

Admin-only recovery route sends the contract's entire ETH balance to the configured treasury.

**Notes:**
- security: Restricted to `DEFAULT_ADMIN_ROLE`.

- validation: Requires a configured treasury and a positive ETH balance.

- state-changes: Transfers the full native ETH balance from the vault to the treasury.

- events: Emits `ETHRecovered`.

- errors: Reverts on missing treasury, zero ETH balance, send failure, or missing admin role.

- reentrancy: Not applicable.

- access: Restricted to `DEFAULT_ADMIN_ROLE`.

- oracle: Not applicable.


```solidity
function recoverETH() external onlyRole(DEFAULT_ADMIN_ROLE);
```

## Events
### YieldParametersUpdated

```solidity
event YieldParametersUpdated(uint256 yieldFee);
```

### TreasuryUpdated

```solidity
event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury, address indexed caller);
```

### ETHRecovered

```solidity
event ETHRecovered(address indexed to, uint256 indexed amount);
```

