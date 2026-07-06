# IVersioned
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/9c66decc017650bbed0d0184c123aef0af402eaf/src/interfaces/IVersioned.sol)

**Title:**
IVersioned

Standard semantic-version getter implemented by every core Quantillon contract.

Read through a proxy, `version()` reflects the deployed IMPLEMENTATION (it is a `pure`
getter returning a compile-time constant, so it occupies no storage slot and is safe to add
to storage-frozen upgradeable contracts). It pairs with the off-chain provenance manifest
`deployments/{chainId}/versions.json` (impl address + commit) so the deployed version of any
contract is answerable from a single on-chain call. Bump per semver on any change to the
implementing contract; enforced by `make check-version-bump`.


## Functions
### version

Returns the semantic version of the implementation.

Semver convention: PATCH = bugfix/internal logic, MINOR = new function or
externally-observable behavior (ABI-additive), MAJOR = reserved (storage/ABI breaks are
disallowed by the upgrade-safety gates).

**Notes:**
- security: No security implications - returns a compile-time constant.

- validation: No input validation required.

- state-changes: None - pure function.

- events: None.

- errors: None.

- reentrancy: Not applicable - pure function.

- access: Public - anyone can read the version.

- oracle: No oracle dependencies.


```solidity
function version() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Semantic version string, e.g. "1.0.0".|


