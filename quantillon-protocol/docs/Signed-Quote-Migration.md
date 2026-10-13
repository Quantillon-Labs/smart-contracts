# Signed quote migration (candidate)

This page describes the candidate implementation on `feat/signed-quotes-migration`. On 12 October 2026, the candidate was installed in preproduction only using the dedicated `feat/signed-quotes-preprod` integration branch. The isolated fork runs vault 1.6.0, UserPool 1.3.0 and HedgerPool 1.5.0, with signed execution and reference modules. Dev and Base mainnet remain unchanged. The production publisher remains necessary until its consumers and release gates have migrated. This preproduction installation is not a production activation record.

## Three separate responsibilities

| Data | Candidate authority | Onchain consumer |
| --- | --- | --- |
| Exact execution amounts | Execution quote signer | `SignedExecutionPricing` and the existing vault accounting |
| EUR/USD valuation | Reference signer, checked against an independent reference | `SignedReferenceSource`, market oracle and router |
| Hedge admission | Capacity signer, after venue and canonical Base reconciliation | Cumulative admission and acknowledgment counters |

A trade's size-dependent execution rate must never revalue all outstanding QEURO. Signing `amountOut` does not bypass collateralization, protocol fees, execution spread, route validation or hedge-capacity limits.

Normal minting buys EUR exposure using asks. Redemption reduces that exposure using bids. The quote engine retains the reference clamps, walks the book with integer arithmetic and includes the configured execution buffer. The venue hedge follows Base settlement and remains non-atomic.

## Candidate contracts

`SignedExecutionPricing` and `SignedReferenceSource` are new non-upgradeable modules. QuantillonVault, UserPool and HedgerPool require governed implementation upgrades. Linked settlement libraries must be included in deployment verification and bytecode-size checks.

The vault's existing `configureExecutionPricing(address)` detects the signed module. It still requires a paused vault, correct vault binding and no outstanding exposure in the previous module. The appended `signedExecutionEnabled` flag closes the old unquoted conversion paths. UserPool adds an appended route guard; existing deposit and withdrawal accounting runs with the original user.

| Entrypoint | Purpose |
| --- | --- |
| `QuantillonVault.executeWithQuote(bytes,bytes)` | One permitted vault operation with a signed authorization |
| `UserPool.executeWithQuote(bytes,bytes)` | One pool deposit or withdrawal, retaining user tracking |
| `HedgerPool.executeWithReference(bytes,bytes)` | Atomic reference delivery with enter, exit, remove-margin or emergency-close |
| `QuantillonVault.emergencyRedeemQEURO(uint256,uint256)` | Explicitly governed, budgeted emergency redemption |

The HedgerPool wrapper does not change ownership or roles. Add-margin stays available directly without a quote or reference signer. Safe and Zodiac policies must explicitly support the bounded wrapper before callers switch; generic arbitrary-call permission is not a substitute.

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

The candidate counts unresolved buys plus unresolved sells toward its gross admission limit. They do not cancel each other merely because their net exposure is zero. This is more conservative than the previous directional policy and must be included in capacity calibration.

Offchain reservations serialize all quote workers sharing a deployment. Reserved public order-book depth represents Quantillon's risk budget; it does not reserve liquidity on Hyperliquid. Release requires canonical nonce, epoch, time and settlement evidence. Unknown consumed nonces and reorganized settlements retain their budget.

## Expiration and failure behavior

The API targets twenty seconds from the original market observation, while the contract enforces a maximum of thirty seconds. Issue age is bounded; the interface requires enough remaining time before opening the wallet. A quote can still expire during wallet interaction or inclusion. Approval precedes executable quote issuance.

Normal signed settlement fails closed on stale market data, invalid reference, exhausted capacity, bad signatures, expired authorization or pause. Emergency redemption is a separate mode, with a non-renewing budget and independent-reference checks. Switching modes alone does not replenish that budget. The existing market adapter's freshness policy also applies; emergency behavior must be rehearsed against the actual router and adapter.

Keeper yield conversion uses a distinct bounded-rate authorization because the exact harvested amount is known only during the transaction. The signed maximum must not be exceeded. Zero-harvest behavior, role checks, staking allocation and vesting must remain unchanged. Public quote issuance does not grant keeper authority.

## Release and rollback requirements

Complete keeper, margin/Safe, liquidation, indexer, rewards, dashboard, watchdog and reset integrations before retiring the periodic writer. Test operations after inactivity beyond every former freshness window. Dev and preproduction resets must restore candidate implementations, links, roles, bindings and isolated durable state.

Updated user decision (13 October 2026): validate the preprod-to-production candidate before scheduling the upgrade. There is no mandatory seven-day shadow window or minimum real-hedge sample quota. Finish code, real-fill attribution, permissions, review, rehearsal and staging first. After the requested 12-hour governance delay, execute the governed activation and coordinate the prepared Dapp/backend switch against confirmed onchain bindings in the same cutover. Elapsed timelock time does not execute the upgrade automatically. Brief admission pause, reconciliation and immediate validation remain part of cutover; no additional observation period is imposed. Stop the recurring publisher once its replaced consumers pass those checks. Keep admissions closed if versions or bindings do not match. Dev rollout is separate. Update deployment addresses and versions from actual receipts, never from planned values. Generate contract reference pages from NatSpec with `make docs`.

Before any signed settlement, rollback may restore verified legacy bindings with fresh reports. After signed settlements, stop issuance, invalidate outstanding quotes and reconcile real venue fills and onchain admission before replacing the module. Restoring an old database does not undo a settlement.

Eliminating idle periodic publication removes its recurring gas expense. User settlement, governance, emergency actions and necessary operational acknowledgments still require transactions. No cross-chain fill guarantee is created by a signature.

## Inactive module deployment

`scripts/deployment/DeploySignedQuoteModules.s.sol` deploys the reference and execution modules without changing any proxy, oracle binding or active pricing module. It requires the explicit environment/chain pair (`dev`/31337, `preprod`/31338, `prod`/8453), existing vault and independent-reference contracts, governance, reserve recipient and all risk bounds. Both modules are owned by governance from construction; the broadcaster receives no role. Execution remains paused and there are no authorized signing keys until governance configures them.

Before activation, governance must grant the reference signer on the source, grant the execution module the source's emergency-controller role, and grant separate execution and capacity signers on the pricing module. Bind the oracle adapter to the new reference source, upgrade the required vault/UserPool/HedgerPool implementations with their verified linked libraries, and check all bindings and roles against the release receipt. These operations belong to the governed cutover after old exposure is reconciled; module deployment alone does not satisfy that cutover.

The deployment script logs module addresses, not public Safe import payloads. Keep broadcaster receipts and any governed transaction staging artifacts in private operator storage. Do not run `--broadcast` as part of unit tests or documentation builds.

## Preproduction validation

The integration passed direct mint/redemption, UserPool deposit/withdrawal, mint-and-stake share issuance, replay rejection, expiry rejection, signed keeper harvesting and a coordinated reset with fresh quote domains. Reference-backed dashboard and keeper previews use read-only simulation. A 70-second idle check confirmed no publisher transaction and no persistent reference update while valuation remained available. Hedge capacity remains simulated; no real Hyperliquid fill or production risk calibration is implied. Private installation receipts and keys are not published.
