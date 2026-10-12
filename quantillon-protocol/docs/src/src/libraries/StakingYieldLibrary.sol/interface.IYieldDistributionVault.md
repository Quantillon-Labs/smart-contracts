# IYieldDistributionVault
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/54366a1075ba6db39540a3d83709a310c26d1723/src/libraries/StakingYieldLibrary.sol)

**Inherits:**
[IQuantillonVault](/src/interfaces/IQuantillonVault.sol/interface.IQuantillonVault.md)

Vault getters used by linked distribution code to keep proxy runtime compact.


## Functions
### hedgerPool

Configured hedger accounting contract.

Read from the calling vault during library delegatecall.

**Notes:**
- security: Read-only vault getter.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: View only.

- access: Public.

- oracle: None.


```solidity
function hedgerPool() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Configured address.|


### treasury

Protocol treasury recipient.

Read from the calling vault during library delegatecall.

**Notes:**
- security: Read-only vault getter.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: View only.

- access: Public.

- oracle: None.


```solidity
function treasury() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Configured address.|


### yieldDistributionConfig

Capital distribution haircut, recipient and last harvest.

Read from the calling vault during library delegatecall.

**Notes:**
- security: Read-only vault getter.

- validation: None.

- state-changes: None.

- events: None.

- errors: None.

- reentrancy: View only.

- access: Public.

- oracle: None.


```solidity
function yieldDistributionConfig(uint256 vaultId) external view returns (uint256, address, uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vaultId`|`uint256`|Selected strategy.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Haircut basis points.|
|`<none>`|`address`|Hedger recipient.|
|`<none>`|`uint256`|Last successful harvest timestamp.|
