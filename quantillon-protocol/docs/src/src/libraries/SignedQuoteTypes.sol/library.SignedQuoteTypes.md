# SignedQuoteTypes
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/083874330beb67c980851f48832ef5faa68973d3/src/libraries/SignedQuoteTypes.sol)

**Title:**
SignedQuoteTypes

Wire types shared by the vault, signers and report consumers.


## Constants
### VERSION

```solidity
string internal constant VERSION = "1.0.0"
```


## Structs
### Quote
Exact public settlement, or bounded yield conversion. Calldata binds the complete route.

Yield amountIn is a maximum and amountOut is the output at that maximum.


```solidity
struct Quote {
    address user;
    address caller;
    Action action;
    uint256 amountIn;
    uint256 amountOut;
    uint256 observedAt;
    uint256 validAfter;
    uint256 validUntil;
    uint256 nonce;
    uint256 epoch;
    bytes32 callHash;
    bytes32 referenceHash;
}
```

### ReferenceReport
Original market observation, never timestamped at submission.


```solidity
struct ReferenceReport {
    uint256 price;
    uint256 observedAt;
    uint256 sequence;
    uint256 epoch;
}
```

### CapacityReport
Lifetime fill acknowledgments and additional venue margin capacity.

canonicalBlock/hash identify the Base state actually reconciled by the reporter.


```solidity
struct CapacityReport {
    uint256 acknowledgedBuy;
    uint256 acknowledgedSell;
    uint256 capacity;
    uint256 observedAt;
    uint256 sequence;
    uint256 epoch;
    uint256 canonicalBlock;
    bytes32 canonicalBlockHash;
}
```

### Authorization
Reports carried atomically with a settlement.


```solidity
struct Authorization {
    Quote quote;
    bytes signature;
    ReferenceReport referenceReport;
    bytes referenceSignature;
    CapacityReport capacityReport;
    bytes capacitySignature;
}
```

## Enums
### Action

```solidity
enum Action {
    Mint,
    Redeem,
    Yield
}
```

### Mode

```solidity
enum Mode {
    Paused,
    Signed,
    EmergencyRedeem
}
```
