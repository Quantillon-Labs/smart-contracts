# FeeCollector
**Inherits:**
AccessControlUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable, UUPSUpgradeable

**Author:**
Quantillon Protocol Team

Centralized fee collection and distribution contract for Quantillon Protocol

*This contract handles all protocol fees from:
- QEURO minting fees
- QEURO redemption fees
- Hedger position fees
- Yield management fees
- Other protocol operations*

*Features:
- Centralized fee collection from all protocol contracts
- Governance-controlled fee distribution
- Multi-token fee support (USDC, QEURO, etc.)
- Fee analytics and tracking
- Emergency pause functionality
- Upgradeable via UUPS proxy*

**Note:**
security-contact: team@quantillon.money


## State Variables
### GOVERNANCE_ROLE
Governance role for fee distribution and configuration


```solidity
bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
```


### TREASURY_ROLE
Treasury role for fee withdrawal


```solidity
bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");
```


### EMERGENCY_ROLE
Emergency role for pausing and emergency operations


```solidity
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
```


### treasury
Treasury address for fee distribution


```solidity
address public treasury;
```


### devFund
Protocol development fund address


```solidity
address public devFund;
```


### communityFund
Community fund address


```solidity
address public communityFund;
```


### treasuryRatio
Fee distribution ratios (in basis points, 10000 = 100%)


```solidity
uint256 public treasuryRatio;
```


### devFundRatio

```solidity
uint256 public devFundRatio;
```


### communityRatio

```solidity
uint256 public communityRatio;
```


### totalFeesCollected
Total fees collected per token


```solidity
mapping(address => uint256) public totalFeesCollected;
```


### totalFeesDistributed
Total fees distributed per token


```solidity
mapping(address => uint256) public totalFeesDistributed;
```


### feeCollectionCount
Fee collection events per token


```solidity
mapping(address => uint256) public feeCollectionCount;
```


## Functions
### onlyFeeSource

Ensures only authorized contracts can collect fees


```solidity
modifier onlyFeeSource();
```

### initialize

Initializes the FeeCollector contract

*Sets up the initial configuration for fee collection and distribution*

*Sets up roles, fund addresses, and default fee distribution ratios*

**Notes:**
- security: Protected by initializer modifier

- validation: Validates that all addresses are non-zero

- state-changes: Sets up roles, fund addresses, and default ratios

- events: Emits role grant events and FundAddressesUpdated event

- errors: Throws ZeroAddress if any address is zero

- reentrancy: No external calls, safe

- access: Can only be called once during initialization

- oracle: No oracle dependencies


```solidity
function initialize(address _admin, address _treasury, address _devFund, address _communityFund) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_admin`|`address`|Admin address (will receive DEFAULT_ADMIN_ROLE, GOVERNANCE_ROLE, and EMERGENCY_ROLE)|
|`_treasury`|`address`|Treasury address (will receive TREASURY_ROLE)|
|`_devFund`|`address`|Dev fund address (cannot be zero)|
|`_communityFund`|`address`|Community fund address (cannot be zero)|


### collectFees

Collects fees from protocol contracts

*Transfers tokens from the caller to this contract and updates tracking variables*

*Only authorized fee sources can call this function*

*Emits FeesCollected event for transparency and analytics*

**Notes:**
- security: Protected by onlyFeeSource modifier and reentrancy guard

- validation: Validates token address and amount parameters

- state-changes: Updates totalFeesCollected and feeCollectionCount mappings

- events: Emits FeesCollected event with collection details

- errors: Throws InvalidAmount if amount is zero

- errors: Throws ZeroAddress if token address is zero

- reentrancy: Protected by nonReentrant modifier

- access: Restricted to authorized fee sources only

- oracle: No oracle dependencies


```solidity
function collectFees(address token, uint256 amount, string calldata sourceType)
    external
    onlyFeeSource
    whenNotPaused
    nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address to collect fees for (cannot be zero address)|
|`amount`|`uint256`|Amount of fees to collect (must be greater than zero)|
|`sourceType`|`string`|Type of fee source (e.g., "minting", "redemption", "hedging")|


### collectETHFees

Collects ETH fees from protocol contracts

*Accepts ETH payments and updates tracking variables for ETH (tracked as address(0))*

*Only authorized fee sources can call this function*

*Emits FeesCollected event for transparency and analytics*

**Notes:**
- security: Protected by onlyFeeSource modifier and reentrancy guard

- validation: Validates that msg.value is greater than zero

- state-changes: Updates totalFeesCollected and feeCollectionCount for address(0)

- events: Emits FeesCollected event with ETH collection details

- errors: Throws InvalidAmount if msg.value is zero

- reentrancy: Protected by nonReentrant modifier

- access: Restricted to authorized fee sources only

- oracle: No oracle dependencies


```solidity
function collectETHFees(string calldata sourceType) external payable onlyFeeSource whenNotPaused nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sourceType`|`string`|Type of fee source (e.g., "staking", "governance", "liquidation")|


### distributeFees

Distributes collected fees according to configured ratios

*Calculates distribution amounts based on treasuryRatio, devFundRatio, and communityRatio*

*Handles rounding by adjusting community amount to ensure total doesn't exceed balance*

*Only treasury role can call this function*

*Emits FeesDistributed event for transparency*

**Notes:**
- security: Protected by TREASURY_ROLE and reentrancy guard

- validation: Validates that contract has sufficient balance

- state-changes: Updates totalFeesDistributed and transfers tokens to fund addresses

- events: Emits FeesDistributed event with distribution details

- errors: Throws InsufficientBalance if contract balance is zero

- reentrancy: Protected by nonReentrant modifier

- access: Restricted to TREASURY_ROLE only

- oracle: No oracle dependencies


```solidity
function distributeFees(address token) external onlyRole(TREASURY_ROLE) whenNotPaused nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address to distribute (address(0) for ETH)|


### _calculateDistributionAmounts

Calculate distribution amounts with rounding protection

*Internal function to reduce cyclomatic complexity*

**Notes:**
- security: No external calls, pure calculation function

- validation: Balance must be non-zero for meaningful distribution

- state-changes: No state changes, view function

- events: No events emitted

- errors: No custom errors, uses SafeMath for overflow protection

- reentrancy: No reentrancy risk, view function

- access: Internal function, no access control needed

- oracle: No oracle dependencies


```solidity
function _calculateDistributionAmounts(uint256 balance)
    internal
    view
    returns (uint256 treasuryAmount, uint256 devFundAmount, uint256 communityAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`balance`|`uint256`|Total balance to distribute|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`treasuryAmount`|`uint256`|Amount for treasury|
|`devFundAmount`|`uint256`|Amount for dev fund|
|`communityAmount`|`uint256`|Amount for community fund|


### _executeTransfers

Execute transfers for ETH or ERC20 tokens

*Internal function to reduce cyclomatic complexity*

**Notes:**
- security: Delegates to specific transfer functions with proper validation

- validation: Amounts must be non-zero for transfers to execute

- state-changes: Updates token balances through transfers

- events: No direct events, delegated functions emit events

- errors: May revert on transfer failures

- reentrancy: Protected by internal function design

- access: Internal function, no access control needed

- oracle: No oracle dependencies


```solidity
function _executeTransfers(address token, uint256 treasuryAmount, uint256 devFundAmount, uint256 communityAmount)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address (address(0) for ETH)|
|`treasuryAmount`|`uint256`|Amount for treasury|
|`devFundAmount`|`uint256`|Amount for dev fund|
|`communityAmount`|`uint256`|Amount for community fund|


### _executeETHTransfers

Execute ETH transfers

*Internal function to reduce cyclomatic complexity*

**Notes:**
- security: Uses secure ETH transfer with address validation

- validation: Amounts must be non-zero for transfers to execute

- state-changes: Reduces contract ETH balance, increases recipient balances

- events: No direct events emitted

- errors: Reverts with ETHTransferFailed on call failure

- reentrancy: Protected by internal function design and address validation

- access: Internal function, no access control needed

- oracle: No oracle dependencies


```solidity
function _executeETHTransfers(uint256 treasuryAmount, uint256 devFundAmount, uint256 communityAmount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`treasuryAmount`|`uint256`|Amount for treasury|
|`devFundAmount`|`uint256`|Amount for dev fund|
|`communityAmount`|`uint256`|Amount for community fund|


### _secureETHTransfer

Secure ETH transfer with comprehensive validation

*Validates recipient address against whitelist and performs secure ETH transfer*

**Notes:**
- security: Multiple validation layers prevent arbitrary sends:
- Recipient must be one of three pre-authorized fund addresses
- Addresses are validated to be non-zero and non-contract
- Only GOVERNANCE_ROLE can update these addresses
- This is NOT an arbitrary send as recipient is strictly controlled

- validation: Ensures recipient is valid and amount is positive

- state-changes: Transfers ETH from contract to recipient

- events: No events emitted

- errors: Reverts with ETHTransferFailed on transfer failure

- reentrancy: Protected by address validation and call pattern

- access: Internal function, no access control needed

- oracle: No oracle dependencies


```solidity
function _secureETHTransfer(address recipient, uint256 amount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|Address to receive ETH (must be treasury, devFund, or communityFund)|
|`amount`|`uint256`|Amount of ETH to transfer|


### _executeERC20Transfers

Execute ERC20 token transfers

*Internal function to reduce cyclomatic complexity*

**Notes:**
- security: Uses safeTransfer for ERC20 tokens with proper error handling

- validation: Amounts must be non-zero for transfers to execute

- state-changes: Reduces contract token balance, increases recipient balances

- events: No direct events emitted

- errors: May revert on transfer failures from ERC20 contract

- reentrancy: Protected by internal function design and safeTransfer

- access: Internal function, no access control needed

- oracle: No oracle dependencies


```solidity
function _executeERC20Transfers(address token, uint256 treasuryAmount, uint256 devFundAmount, uint256 communityAmount)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address|
|`treasuryAmount`|`uint256`|Amount for treasury|
|`devFundAmount`|`uint256`|Amount for dev fund|
|`communityAmount`|`uint256`|Amount for community fund|


### updateFeeRatios

Updates fee distribution ratios

*Sets new distribution ratios for treasury, dev fund, and community fund*

*Ratios must sum to exactly 10000 (100%) in basis points*

*Only governance role can call this function*

*Emits FeeRatiosUpdated event for transparency*

**Notes:**
- security: Protected by GOVERNANCE_ROLE

- validation: Validates that ratios sum to exactly 10000

- state-changes: Updates treasuryRatio, devFundRatio, and communityRatio

- events: Emits FeeRatiosUpdated event with new ratios

- errors: Throws InvalidRatio if ratios don't sum to 10000

- reentrancy: No external calls, safe

- access: Restricted to GOVERNANCE_ROLE only

- oracle: No oracle dependencies


```solidity
function updateFeeRatios(uint256 _treasuryRatio, uint256 _devFundRatio, uint256 _communityRatio)
    external
    onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_treasuryRatio`|`uint256`|New treasury ratio (in basis points, 10000 = 100%)|
|`_devFundRatio`|`uint256`|New dev fund ratio (in basis points, 10000 = 100%)|
|`_communityRatio`|`uint256`|New community ratio (in basis points, 10000 = 100%)|


### updateFundAddresses

Updates fund addresses for fee distribution

*Sets new addresses for treasury, dev fund, and community fund*

*All addresses must be non-zero*

*Only governance role can call this function*

*Emits FundAddressesUpdated event for transparency*

**Notes:**
- security: Protected by GOVERNANCE_ROLE

- validation: Validates that all addresses are non-zero

- state-changes: Updates treasury, devFund, and communityFund addresses

- events: Emits FundAddressesUpdated event with new addresses

- errors: Throws ZeroAddress if any address is zero

- reentrancy: No external calls, safe

- access: Restricted to GOVERNANCE_ROLE only

- oracle: No oracle dependencies


```solidity
function updateFundAddresses(address _treasury, address _devFund, address _communityFund)
    external
    onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_treasury`|`address`|New treasury address (cannot be zero)|
|`_devFund`|`address`|New dev fund address (cannot be zero)|
|`_communityFund`|`address`|New community fund address (cannot be zero)|


### authorizeFeeSource

Authorizes a contract to collect fees

*Grants TREASURY_ROLE to the specified address, allowing it to collect fees*

*Only governance role can call this function*

**Notes:**
- security: Protected by GOVERNANCE_ROLE

- validation: Validates that feeSource is not zero address

- state-changes: Grants TREASURY_ROLE to feeSource

- events: Emits RoleGranted event for TREASURY_ROLE

- errors: Throws ZeroAddress if feeSource is zero

- reentrancy: No external calls, safe

- access: Restricted to GOVERNANCE_ROLE only

- oracle: No oracle dependencies


```solidity
function authorizeFeeSource(address feeSource) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`feeSource`|`address`|Contract address to authorize (cannot be zero)|


### revokeFeeSource

Revokes fee collection authorization

*Revokes TREASURY_ROLE from the specified address, preventing it from collecting fees*

*Only governance role can call this function*

**Notes:**
- security: Protected by GOVERNANCE_ROLE

- validation: No validation required (can revoke from any address)

- state-changes: Revokes TREASURY_ROLE from feeSource

- events: Emits RoleRevoked event for TREASURY_ROLE

- errors: No custom errors

- reentrancy: No external calls, safe

- access: Restricted to GOVERNANCE_ROLE only

- oracle: No oracle dependencies


```solidity
function revokeFeeSource(address feeSource) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`feeSource`|`address`|Contract address to revoke authorization from|


### pause

Pauses fee collection and distribution

*Emergency function to pause all fee operations in case of security issues*

*Only emergency role can call this function*

**Notes:**
- security: Protected by EMERGENCY_ROLE

- validation: No validation required

- state-changes: Sets paused state to true

- events: Emits Paused event

- errors: No custom errors

- reentrancy: No external calls, safe

- access: Restricted to EMERGENCY_ROLE only

- oracle: No oracle dependencies


```solidity
function pause() external onlyRole(EMERGENCY_ROLE);
```

### unpause

Unpauses fee collection and distribution

*Resumes all fee operations after a pause*

*Only emergency role can call this function*

**Notes:**
- security: Protected by EMERGENCY_ROLE

- validation: No validation required

- state-changes: Sets paused state to false

- events: Emits Unpaused event

- errors: No custom errors

- reentrancy: No external calls, safe

- access: Restricted to EMERGENCY_ROLE only

- oracle: No oracle dependencies


```solidity
function unpause() external onlyRole(EMERGENCY_ROLE);
```

### emergencyWithdraw

Emergency withdrawal of all tokens (only in extreme circumstances)

*Emergency function to withdraw all tokens to treasury in case of critical issues*

*Only emergency role can call this function*

**Notes:**
- security: Protected by EMERGENCY_ROLE

- validation: Validates that contract has sufficient balance

- state-changes: Transfers all tokens to treasury address

- events: No custom events (uses standard transfer events)

- errors: Throws InsufficientBalance if contract balance is zero

- errors: Throws ETHTransferFailed if ETH transfer fails

- reentrancy: No external calls, safe

- access: Restricted to EMERGENCY_ROLE only

- oracle: No oracle dependencies


```solidity
function emergencyWithdraw(address token) external onlyRole(EMERGENCY_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address to withdraw (address(0) for ETH)|


### getBalance

Returns the current balance of a token

*Returns the current balance of the specified token held by this contract*

**Notes:**
- security: No security implications (view function)

- validation: No validation required

- state-changes: No state changes (view function)

- events: No events (view function)

- errors: No custom errors

- reentrancy: No external calls, safe

- access: Public (anyone can call)

- oracle: No oracle dependencies


```solidity
function getBalance(address token) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address (address(0) for ETH)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Current balance of the token in this contract|


### getFeeStats

Returns fee collection statistics for a token

*Returns comprehensive statistics about fee collection and distribution for a specific token*

**Notes:**
- security: No security implications (view function)

- validation: No validation required

- state-changes: No state changes (view function)

- events: No events (view function)

- errors: No custom errors

- reentrancy: No external calls, safe

- access: Public (anyone can call)

- oracle: No oracle dependencies


```solidity
function getFeeStats(address token)
    external
    view
    returns (uint256 totalCollected, uint256 totalDistributed, uint256 collectionCount, uint256 currentBalance);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address (address(0) for ETH)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalCollected`|`uint256`|Total amount of fees collected for this token|
|`totalDistributed`|`uint256`|Total amount of fees distributed for this token|
|`collectionCount`|`uint256`|Number of fee collection transactions for this token|
|`currentBalance`|`uint256`|Current balance of this token in the contract|


### isAuthorizedFeeSource

Checks if an address is authorized to collect fees

*Returns whether the specified address has permission to collect fees*

**Notes:**
- security: No security implications (view function)

- validation: No validation required

- state-changes: No state changes (view function)

- events: No events (view function)

- errors: No custom errors

- reentrancy: No external calls, safe

- access: Public (anyone can call)

- oracle: No oracle dependencies


```solidity
function isAuthorizedFeeSource(address feeSource) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`feeSource`|`address`|Address to check for authorization|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the address is authorized to collect fees, false otherwise|


### _isAuthorizedFeeSource

Internal function to check if an address is authorized to collect fees

*Internal helper function to check TREASURY_ROLE for fee collection authorization*

**Notes:**
- security: Internal function, no direct security implications

- validation: No validation required

- state-changes: No state changes (view function)

- events: No events (internal function)

- errors: No custom errors

- reentrancy: No external calls, safe

- access: Internal function only

- oracle: No oracle dependencies


```solidity
function _isAuthorizedFeeSource(address feeSource) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`feeSource`|`address`|Address to check for authorization|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the address has TREASURY_ROLE, false otherwise|


### _authorizeUpgrade

Authorizes upgrades (only governance)

*Internal function to authorize contract upgrades via UUPS proxy pattern*

*Only governance role can authorize upgrades*

**Notes:**
- security: Protected by GOVERNANCE_ROLE

- validation: No validation required (OpenZeppelin handles this)

- state-changes: No state changes (authorization only)

- events: No custom events (OpenZeppelin handles upgrade events)

- errors: No custom errors

- reentrancy: No external calls, safe

- access: Restricted to GOVERNANCE_ROLE only

- oracle: No oracle dependencies


```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation contract|


## Events
### FeesCollected
Emitted when fees are collected


```solidity
event FeesCollected(address indexed token, uint256 amount, address indexed source, string indexed sourceType);
```

### FeesDistributed
Emitted when fees are distributed


```solidity
event FeesDistributed(
    address indexed token, uint256 totalAmount, uint256 treasuryAmount, uint256 devFundAmount, uint256 communityAmount
);
```

### FeeRatiosUpdated
Emitted when fee distribution ratios are updated


```solidity
event FeeRatiosUpdated(uint256 treasuryRatio, uint256 devFundRatio, uint256 communityRatio);
```

### FundAddressesUpdated
Emitted when fund addresses are updated


```solidity
event FundAddressesUpdated(address treasury, address devFund, address communityFund);
```

