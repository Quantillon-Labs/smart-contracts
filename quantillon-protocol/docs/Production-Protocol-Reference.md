# Production Deployment Status

Verified on **30 September 2026**, using finalized Base block **51,985,907** for contract settings. These are dated observations, not immutable defaults. Governance can change settings; read the contracts and obtain a fresh quote before transacting.

## Deployment and availability

Contracts are deployed on **Base mainnet (8453)**. The public application is at [app.quantillon.money](https://app.quantillon.money); the public launch remains a **Q4 2026 target**, not a confirmed opening date. There is no Ethereum-mainnet deployment. Development and preproduction use separate Base forks; the former public testnet is retired.

QTI is deployed but has **zero supply**. Its vote-escrow and proposal machinery is dormant. Quantillon Rewards is deployed, but the public program state is **off** and enrollment is not open. QP points promise neither monetary value nor a token allocation.

## User flows and backing

* Users mint QEURO with USDC through QuantillonVault. Normal mint/redeem amounts use directional **execution quotes**, including depth, spread and buffer constraints, rather than simply multiplying by the oracle mid. Zero protocol fees do not mean zero execution cost.
* The dapp stakes QEURO directly into an ERC-4626 stQEURO series. The optional UserPool batch contract has separate accounting and a cooldown; these are not the direct stQEURO staking rules.
* The current external strategy is the MetaMorpho USDC vault, registered as **vaultId 2**. QEURO backing can be deployed there; hedger margin is not part of its yield-bearing principal. External backing is counted conservatively, capped by tracked principal and current underlying value; the execution-spread reserve is excluded from backing.
* Minting has a **102.5% collateralization floor**, plus oracle, execution-capacity, token, pause and liquidity checks. Protocol liquidation mode applies when the computed ratio is **positive and at or below 101%**. A zero ratio is not an automatic liquidation signal. Redemptions remain subject to validation and available liquidity.

See [Execution Pricing](Architecture.md), [Liquidation Mode](Architecture.md) and [External Staking Vaults](Architecture.md).

## Yield and fees

| Setting | Verified value / meaning |
| --- | --- |
| Vault mint and redemption fee | 0; each configurable up to 5% |
| Morpho allocation | Harvest-time staked-QEURO fraction to stakers; unstaked fraction to treasury |
| Hedger staking-yield haircut | 0 bps; no base allocation for hedger collateral |
| stQEURO vesting | 24 hours; allocation remains snapshot-weighted |
| Legacy stQEURO yield fee | Ignored by the vault 1.5.0 credit path |
| Vault `hedgerRewardFeeSplit` | 20% of collected vault fees routed to the hedger reward reserve; not a reward-claim tax |
| HedgerPool entry / exit / margin fees | 0 |
| HedgerPool `rewardFeeSplit` | 0; separate routing setting for fees collected by HedgerPool |
| FeeCollector distribution | 60% treasury / 25% development / 15% community, for receipts reaching FeeCollector |
| Optional UserPool configuration | 8% staking / 4% deposit accounting APY; minimum stake 100 QEURO; 7-day cooldown; performance fee 0 |

UserPool's configured accounting rates are not Morpho's realized return or the direct stQEURO APY. The displayed Morpho rate is an underlying provider metric, not a guaranteed QEURO return. See [Yield Distribution](Yield-Distribution-1.5.0.md) for the allocation formula and conversion costs. YieldShift remains a separate authorized-source ledger.

## Hedge and oracle

The single designated hedger maintains a Base HedgerPool position and a Hyperliquid `xyz:EUR` position. HedgerPool's minimum margin is **2.5%** and its configured maximum leverage is **40x**. Configured EUR/USD annual interest inputs are **3.5% / 4.5%**; they are not promises of realized hedger profit. Order preparation inside Hyperliquid and movement of capital between venues are distinct operations.

OracleRouter slot **1** uses HyperliquidEurUsdOracle; slot **0** is the manually selected Chainlink fallback. The market oracle also checks an independent Chainlink reference on-chain. A stale reference can block operations even when the venue is trading. Switching to Chainlink does not by itself restore minting: execution pricing also checks source compatibility and admitted hedge capacity.

## Governance and security

The governance Safe requires **2 of 3** signers. The **12-hour TimelockController holds DEFAULT_ADMIN_ROLE on the eight core contracts**, including the stQEURO series. Core role grants and revocations therefore use that controller. The Safe retains direct operational, governance and emergency permissions according to each contract's roles; it holds the peripheral admin roles.

Core upgrades use the timelock while secure upgrades are enabled. SecureUpgradeable also contains a separate emergency-disable procedure with a 24-hour delay and two distinct admin approvals; it is not an ordinary pause operation. Peripheral upgrades can be executed directly by the Safe. See [Quantillon DAO](Architecture.md) for the control boundaries.

**No professional security audit has been performed.** Review to date is internal and AI-assisted. This does not establish that the contracts are free of defects. See [Risks and Mitigation](Security.md).

## Token guardrails and references

QEURO has an adjustable administrative supply ceiling of **100 million**, and global mint and burn limits of **10 million per 300-block window**. These are controls, not a fixed tokenomic issuance promise. Whitelist mode and the minting killswitch were off at the verification block.

The [contract inventory](API-Reference.md) records addresses and versions. [Core Mechanisms](Architecture.md) explains the flows. The roadmap and planned QTI allocations describe future intentions, not current issuance or guaranteed dates.

## Evidence and maintenance

This reference describes the current deployment, not an audit certification. Contract versions, settings and core role bindings were read at finalized Base block 51,985,907. User flows were checked against contract source and deployed ABIs. Runtime routing and Rewards availability were checked separately on 30 September 2026. Future launch, distribution and entity plans remain organizational intentions.

Deployment manifests record upgrade history and can lag live state; use `version()`, role reads and the active vault bindings for current integration. Do not infer the active implementation from a historical release section alone.
