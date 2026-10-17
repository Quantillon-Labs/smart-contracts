# Signed Quotes in Production

Signed quotes were activated on **Base mainnet (8453) on 17 October 2026**. The [confirmed governance execution](https://basescan.org/tx/0xd2945ee2bc1357ec6503e1a374cca9adf841168d4c78739ff6a78a0088aa06f7) is recorded at block **52,720,621**. The production dapp reopened at **10:08 UTC** after the coordinated contract and service cutover. The recurring market publisher is retired.

Versions and active bindings below were read at finalized Base block **52,727,379** on 17 October. These are dated observations; read the live contracts before integration.

| Contract | Proxy or direct module address | Version |
| --- | --- | --- |
| QuantillonVault | `0x833E5Ba510a241b21F1C60c987D1c49eB52E4a07` | 1.6.0 |
| UserPool | `0x712bCc77e7aa53C79870A40d044D440Ad2901bF2` | 1.3.0 |
| HedgerPool | `0xff5D7cE5c7671B2EA805Ee752B4f8eC9Ecf2975A` | 1.6.0 |
| HyperliquidEurUsdOracle | `0x0B58aBB57775E0fCEDfd4460e00dD9D9610C2C43` | 1.0.7 |
| SignedExecutionPricing | `0x076F86a591258957665b65c04F04B706D00EaEBa` | 1.1.0 |
| SignedReferenceSource | `0xFd059ed44959a6a7979e1485a825CE36Dc95cCB1` | 1.0.0 |

`QuantillonVault.executionPricing()` points to SignedExecutionPricing and `signedExecutionEnabled()` is true. The pricing module's `referenceSource()` and the market adapter's legacy-named `slippageStorage()` getter both point to SignedReferenceSource. OracleRouter still selects market slot 1. The pricing mode is **NORMAL** and the non-renewing **emergency budget is 0 QEURO**. The pricing module's `active()` getter describes a temporary settlement context, not whether signed execution is enabled.

See [Production Protocol Reference](Production-Protocol-Reference.md) for dated economic settings and [Quick Start](Quick-Start.md) for the current integration path.

## Three separate responsibilities

| Data | Authority | Onchain consumer |
| --- | --- | --- |
| Exact execution amounts | Execution quote signer | `SignedExecutionPricing` and the existing vault accounting |
| EUR/USD valuation | Reference signer, checked against an independent reference | `SignedReferenceSource`, market oracle and router |
| Hedge admission | Capacity signer, after venue and canonical Base reconciliation | Cumulative admission and acknowledgment counters |

A trade's size-dependent execution rate must never revalue all outstanding QEURO. Signing `amountOut` does not bypass collateralization, protocol fees, execution spread, route validation or hedge-capacity limits.

Normal minting buys EUR exposure using asks. Redemption reduces that exposure using bids. The quote engine retains the reference clamps, walks the book with integer arithmetic and includes the configured execution buffer. The venue hedge follows Base settlement and remains non-atomic.

## Contracts and entrypoints

`SignedExecutionPricing` and `SignedReferenceSource` are new non-upgradeable modules. QuantillonVault, UserPool and HedgerPool received governed implementation upgrades in this release. Linked settlement libraries must be included in deployment verification and bytecode-size checks.

The vault's existing `configureExecutionPricing(address)` detects the signed module. It still requires a paused vault, correct vault binding and no outstanding exposure in the previous module. The appended `signedExecutionEnabled` flag closes the old unquoted conversion paths. UserPool adds an appended route guard; existing deposit and withdrawal accounting runs with the original user.

| Entrypoint | Purpose |
| --- | --- |
| `QuantillonVault.executeWithQuote(bytes,bytes)` | One permitted vault operation with a signed authorization |
| `UserPool.executeWithQuote(bytes,bytes)` | One pool deposit or withdrawal, retaining user tracking |
| `HedgerPool.executeWithReference(bytes,bytes)` | Atomic reference delivery with enter, exit, remove-margin or emergency-close |
| `QuantillonVault.emergencyRedeemQEURO(uint256,uint256)` | Explicitly governed, budgeted emergency redemption |

The HedgerPool wrapper does not change ownership or roles. Add-margin stays available directly without a quote or reference signer. Delegated Safe/Zodiac callers use the typed `removeMarginWithReference(uint256,uint256,bytes)` route with scoped permissions. A signature does not grant caller authority.

## Signature and calldata binding

Execution EIP-712 uses name `Quantillon Execution`, version `1`, the deployment chain ID and the execution module as verifying contract. The quote includes:

```solidity
address user;
address caller;
uint8 action;
uint256 amountIn;
uint256 amountOut;
uint256 observedAt;
uint256 validAfter;
uint256 validUntil;
uint256 nonce;
uint256 epoch;
bytes32 callHash;
bytes32 referenceHash;
```

`callHash` binds the complete inner calldata, including the route, vault ID and minimum shares when staking. Pool settlement binds `caller` to UserPool and `user` to the original wallet. Nonces are consumed per original user. Epoch changes invalidate outstanding execution authorizations; revoking a signer invalidates its signatures at settlement.

The authorization is ABI-encoded as `(Quote,bytes,ReferenceReport,bytes,CapacityReport,bytes)` inside the shared `Authorization` struct. Reference-only authorization is `abi.encode(ReferenceReport, signature)`. The fixed wire vector is tested in both Node and Solidity for exact tuple encoding, signature recovery and chain-domain separation.

Reference signatures use domain name `Quantillon Reference` and the reference-source address. They carry price, original observation time, sequence and source epoch. Exact replay is idempotent; it cannot refresh the observation timestamp. An authenticated older report may accompany a still-valid quote, but it cannot replace a newer cached reference. Capacity reports carry cumulative acknowledged buys and sells, margin capacity, observation time, sequence, execution epoch and the canonical Base block/hash inspected by the signer.

## Accounting and concurrency

For a mint, received USDC is split into protocol fees, reference-valued backing and execution spread. Token transfers, hedger synchronization, quote consumption and admission occur atomically. Failure rolls back all of them, including UserPool tracking and any report updates.

Out-of-order capacity delivery retains the latest accepted margin limit, original observation time and cumulative acknowledgments. All delivered signatures still require the authorized signer, current epoch, valid age and canonical block. Conflicting reports with the same sequence revert.

Exact output stays signed, while backing and reference-valued fees use the latest accepted reference. A quote can therefore fail current collateral or impact checks before its deadline; the deadline is an expiry bound, not an unconditional execution guarantee.

The signed module counts unresolved buys plus unresolved sells toward its gross admission limit. They do not cancel each other merely because their net exposure is zero. This is more conservative than the previous directional policy and must be included in capacity calibration.

Offchain reservations serialize all quote workers sharing a deployment. Reserved public order-book depth represents Quantillon's risk budget; it does not reserve liquidity on Hyperliquid. Release requires canonical nonce, epoch, time and settlement evidence. Unknown consumed nonces and reorganized settlements retain their budget.

## Expiration and failure behavior

SignedExecutionPricing 1.1.0 enforces a forty-five-second maximum, measured from the original market observation. The matching API defaults to forty-five seconds. Production uses this forty-five-second limit. The module and reference source separately enforce a 60-second report-age limit; that does not extend a quote deadline. Issue age is bounded; the interface requires enough remaining time before opening the wallet. A quote can still expire during wallet interaction or inclusion. Approval precedes executable quote issuance.

Normal signed settlement fails closed on stale market data, invalid reference, exhausted capacity, bad signatures, expired authorization or pause. Emergency redemption is a separate mode, with a non-renewing budget and independent-reference checks. Switching modes alone does not replenish that budget. The existing market adapter's freshness policy also applies; emergency behavior must be rehearsed against the actual router and adapter.

Keeper yield conversion uses a distinct bounded-rate authorization because the exact harvested amount is known only during the transaction. The signed maximum must not be exceeded. Zero-harvest behavior, role checks, staking allocation and vesting must remain unchanged. Public quote issuance does not grant keeper authority.

## Operations after activation

The paired dapp, quote/reference/capacity services, hedging engine, watchdog, dashboard and keeper consumers use the signed deployment. Required backend migrations and the reconciliation baseline were applied during maintenance before reopening. Fresh signed delivery is checked with read-only simulations; an idle cache alone does not require a paid publication transaction.

For a future upgrade, stage against actual deployed addresses, respect the controller's 12-hour delay and pause admission for binding changes and reconciliation. Timelock expiry does not execute an upgrade automatically. Keep admission closed if versions, signer authorization, references or hedge readiness do not match the reviewed release.

After signed settlements, a rollback must preserve transaction journals and reconcile real venue fills, consumed quotes and cumulative onchain admission. Restoring an old database or pointing to a legacy pricing module does not undo settlement.

Eliminating idle periodic publication removes its recurring gas expense. User settlement, governance, emergency actions and necessary operational acknowledgments still require transactions. No cross-chain fill guarantee is created by a signature.

## Deploying a future inactive module

`scripts/deployment/DeploySignedQuoteModules.s.sol` deploys the reference and execution modules without changing any proxy, oracle binding or active pricing module. It requires the explicit environment/chain pair (`dev`/31337, `preprod`/31338, `prod`/8453), existing vault and independent-reference contracts, governance, reserve recipient and all risk bounds. Both modules are owned by governance from construction; the broadcaster receives no role. Execution remains paused and there are no authorized signing keys until governance configures them.

Before activation, governance must grant the reference signer on the source, grant the execution module the source's emergency-controller role, and grant separate execution and capacity signers on the pricing module. Bind the oracle adapter to the new reference source, upgrade the required vault/UserPool/HedgerPool implementations with their verified linked libraries, and check all bindings and roles against the release receipt. These operations belong to the governed cutover after old exposure is reconciled; module deployment alone does not satisfy that cutover.

The deployment script logs module addresses, not public Safe import payloads. Keep broadcaster receipts and any governed transaction staging artifacts in private operator storage. Do not run `--broadcast` as part of unit tests or documentation builds.

## Historical preproduction validation (12 October 2026)

The integration passed direct mint/redemption, UserPool deposit/withdrawal, mint-and-stake share issuance, replay rejection, expiry rejection, signed keeper harvesting and a coordinated reset with fresh quote domains. Reference-backed dashboard and keeper previews use read-only simulation. A 70-second idle check confirmed no publisher transaction and no persistent reference update while valuation remained available. Hedge capacity remains simulated; no real Hyperliquid fill or production risk calibration is implied. Private installation receipts and keys are not published.


## Historical production rehearsal and authority

The dedicated production candidate was rehearsed on a private Base fork pinned
to block 52,554,188. The deployed TimelockController requires 43,200 seconds;
execution before this delay was rejected. Vault 1.6.0, UserPool 1.3.0 and HedgerPool
1.6.0 were activated with their linked libraries, the signed reference source and
signed pricing module. This is a migration rehearsal, not live deployment or a
real Hyperliquid execution test.

The existing proxies assign operational GOVERNANCE_ROLE and EMERGENCY_ROLE to
the Safe, while the timelock executes upgrades. Keep that division in the
transaction plan. Initialize UserPool pending liabilities only when its explicit
initialization flag is false. Preserve hedger cost-basis accounting.

The typed production Roles permission restricts `removeMarginWithReference` to
position 1, a positive amount and CALL with no ETH. Dynamic reference bytes still
require the pool's normal authorization checks. The paired backend verifies the
exact permission event, storage and condition runtime; no generic reference-call
permission is granted.

Before reopening admission, install the paired Dapp/services/watchdog release,
initialize the immutable real-venue reconciliation baseline during the pause,
and check the active module, source, signing authorities and signed readiness.
There is no mandatory seven-day shadow window or completed-hedge quota. After
activation, a software rollback must not silently replace contract bindings or
discard signed settlements, journaled transactions or executed venue fills.

### Public CI and private deployment entrypoint

The encrypted `scripts/deployment/DeploySignedQuoteModules.s.sol` entrypoint inherits the secret-free implementation in `scripts/utils/SignedQuoteDeployment.s.sol`. Tests import that implementation so an ordinary GitHub checkout can compile and validate environment guards and inactive deployments without the git-crypt key. No deployment credentials or transaction payloads are published.


## Emergency freshness compatibility

The production release includes HyperliquidEurUsdOracle **1.0.7**. Its ordinary
market snapshot window is unchanged. In the governed signed source's explicit
emergency mode it accepts that source's independent-reference age policy up to
8100 seconds. Original observation timestamps are preserved. Invalid or expired
independent rounds still fail at the source; adapter bounds, reference comparison,
USDC checks and circuit breakers still apply. A legacy source lacking the signed
emergency getters cannot extend its snapshot window.

The configured emergency reference-age ceiling is 8100 seconds, subject to the independent oracle's own validity checks. This does not enable emergency redemption: the current emergency budget is zero. Any future activation requires governed configuration and validation through the source, adapter, router and vault. Normal quotes do not use this extended emergency window.
