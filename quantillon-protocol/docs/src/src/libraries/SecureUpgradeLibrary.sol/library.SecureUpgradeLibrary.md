# SecureUpgradeLibrary
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/54366a1075ba6db39540a3d83709a310c26d1723/src/libraries/SecureUpgradeLibrary.sol)

**Title:**
SecureUpgradeLibrary

Linked compatibility helpers for the protocol's custom timelock interface.

The production OZ controller is scheduled directly using operation ids.


## Functions
### version

Semantic version of this linked library.

Preserves custom-controller compatibility through delegatecall.

**Notes:**
- security: Caller enforces proposal authorization.

- validation: The configured controller validates proposals.

- state-changes: Only propose modifies controller state.

- events: Controller proposal events when applicable.

- errors: Propagates controller errors.

- reentrancy: Calls only the configured controller.

- access: Linked helper.

- oracle: None.


```solidity
function version() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Semantic version.|


### propose

Forwards a proposal to a custom timelock.

Preserves custom-controller compatibility through delegatecall.

**Notes:**
- security: Caller enforces proposal authorization.

- validation: The configured controller validates proposals.

- state-changes: Only propose modifies controller state.

- events: Controller proposal events when applicable.

- errors: Propagates controller errors.

- reentrancy: Calls only the configured controller.

- access: Linked helper.

- oracle: None.


```solidity
function propose(
    ITimelockUpgradeable controller,
    address implementation,
    string calldata description,
    uint256 delay
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`controller`|`ITimelockUpgradeable`|Configured custom timelock.|
|`implementation`|`address`|Proposed implementation.|
|`description`|`string`|Proposal description.|
|`delay`|`uint256`|Requested delay.|


### pending

Returns custom timelock proposal details.

Preserves custom-controller compatibility through delegatecall.

**Notes:**
- security: Caller enforces proposal authorization.

- validation: The configured controller validates proposals.

- state-changes: Only propose modifies controller state.

- events: Controller proposal events when applicable.

- errors: Propagates controller errors.

- reentrancy: Calls only the configured controller.

- access: Linked helper.

- oracle: None.


```solidity
function pending(ITimelockUpgradeable controller, address implementation)
    external
    view
    returns (ITimelockUpgradeable.PendingUpgrade memory proposal);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`controller`|`ITimelockUpgradeable`|Configured custom timelock.|
|`implementation`|`address`|Proposed implementation.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`proposal`|`ITimelockUpgradeable.PendingUpgrade`|Proposal details or an empty record.|


### isPending

Reports whether a custom proposal exists.

Preserves custom-controller compatibility through delegatecall.

**Notes:**
- security: Caller enforces proposal authorization.

- validation: The configured controller validates proposals.

- state-changes: Only propose modifies controller state.

- events: Controller proposal events when applicable.

- errors: Propagates controller errors.

- reentrancy: Calls only the configured controller.

- access: Linked helper.

- oracle: None.


```solidity
function isPending(ITimelockUpgradeable controller, address implementation) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`controller`|`ITimelockUpgradeable`|Configured custom timelock.|
|`implementation`|`address`|Proposed implementation.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether a proposal exists.|


### canExecute

Reports whether a custom proposal is executable.

Preserves custom-controller compatibility through delegatecall.

**Notes:**
- security: Caller enforces proposal authorization.

- validation: The configured controller validates proposals.

- state-changes: Only propose modifies controller state.

- events: Controller proposal events when applicable.

- errors: Propagates controller errors.

- reentrancy: Calls only the configured controller.

- access: Linked helper.

- oracle: None.


```solidity
function canExecute(ITimelockUpgradeable controller, address implementation) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`controller`|`ITimelockUpgradeable`|Configured custom timelock.|
|`implementation`|`address`|Proposed implementation.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the controller permits execution.|
