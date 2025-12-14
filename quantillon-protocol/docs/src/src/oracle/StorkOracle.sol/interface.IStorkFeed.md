# IStorkFeed
Stork Network oracle feed interface

*This interface is based on Stork's EVM contract API
VERIFICATION STATUS:
✅ Function getTemporalNumericValueV1 - Verified matches Stork's contract
✅ Struct TemporalNumericValue - Verified matches Stork's contract
✅ Decimals handling - Stork feeds use 18 decimals (constant, no function needed)
NOTE: Stork's official SDK uses interface name "IStork" instead of "IStorkFeed",
but the function signatures are identical. This interface should work correctly.
IMPORTANT: Stork's contract does NOT have a decimals() function.
Stork feeds use 18 decimals precision (value is multiplied by 10^18).
We use constant STORK_FEED_DECIMALS = 18 instead of calling decimals().
See docs/STORK_INTERFACE_VERIFICATION.md for detailed verification
Resources:
- Documentation: https://docs.storkengine.com/contract-apis/evm
- Contract Addresses: https://docs.stork.network/resources/contract-addresses/evm
- Asset ID Registry: https://docs.stork.network/resources/asset-id-registry
- GitHub: https://github.com/Stork-Oracle/stork-external
- Official SDK: storknetwork/stork-evm-sdk (npm package)
NOTE: Stork also provides Chainlink and Pyth adapters that may be easier to integrate.
Consider using StorkChainlinkAdapter if you want to use Chainlink's familiar interface.*

**Note:**
team@quantillon.money


## Functions
### getTemporalNumericValueV1

Gets the latest temporal numeric value for a given feed ID

*Feed IDs are specific to each price pair (e.g., EUR/USD, USDC/USD)
Obtain feed IDs from Stork's Asset ID Registry: https://docs.stork.network/resources/asset-id-registry
✅ Verified: Function signature matches Stork's contract*

**Notes:**
- Interface function - no security implications

- No validation - interface definition

- No state changes - view function

- No events emitted

- No errors thrown

- Not protected - view function

- Public - no access restrictions

- Interface for Stork feed contract


```solidity
function getTemporalNumericValueV1(bytes32 id) external view returns (TemporalNumericValue memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`bytes32`|The feed ID (bytes32 identifier for the price feed)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`TemporalNumericValue`|The temporal numeric value containing price and timestamp|


## Structs
### TemporalNumericValue
Temporal numeric value structure returned by Stork feeds

*Verified to match Stork's StorkStructs.TemporalNumericValue*


```solidity
struct TemporalNumericValue {
    int256 value;
    uint256 timestamp;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`value`|`int256`|The price value (can be negative for some feeds)|
|`timestamp`|`uint256`|The timestamp when the value was last updated|

