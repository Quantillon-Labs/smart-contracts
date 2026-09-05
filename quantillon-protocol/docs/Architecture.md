# Quantillon Protocol Architecture

## Overview

The Quantillon Protocol is a sophisticated DeFi ecosystem built around a euro-pegged stablecoin (QEURO) with advanced yield management and risk mitigation systems. The architecture is designed for scalability, security, and efficient capital utilization.

The staking layer now supports a multi-vault model through `stQEUROFactory`: each staking vault has its own non-fungible staking token instance (`stQEURO{vaultName}`).

**Versioning.** Every core contract implements `IVersioned.version()` (a `pure` semver getter reflecting the deployed implementation); linked libraries expose `version()` and inlined libraries carry a `VERSION` constant. Any change to a deployed contract/library must be traced through a semver bump (enforced by `make check-version-bump`); `deployments/{chainId}/versions.json` records the live version + commit per contract. See `Deployment.md` → "Versioning & Provenance".

---

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        SYSTEM ARCHITECTURE                      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   User Layer    │    │ Protocol Layer  │    │  Yield Layer    │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ • Retail Users  │───▶│ • QuantillonVault│    │ • Ext. Vaults   │
│ • Institutional │    │ • QEUROToken    │    │ • YieldShift    │
│ • Liquidity     │    │ • QTIToken      │    └─────────────────┘
│   Providers     │    │ • FeeCollector  │             │
└─────────────────┘    │ • UserPool      │             │
                       │ • HedgerPool    │             │
                       │ • stQEUROToken  │             │
                       └─────────────────┘             │
                                │                      │
                       ┌─────────────────┐             │
                       │Infrastructure   │             │
                       │Layer            │             │
                       ├─────────────────┤             │
                       │ • OracleRouter  │             │
                       │ • TimeProvider  │             │
                       │ • Security Libs │             │
                       └─────────────────┘             │
                                │                      │
                       ┌─────────────────┐             │
                       │External Systems │             │
                       ├─────────────────┤             │
                       │ • Morpho        │◀────────────┘
                       │   (MetaMorpho)  │
                       │ • Hyperliquid   │
                       │ • Chainlink     │
                       │ • Base Network  │
                       └─────────────────┘
```

---

## Core Components

### 1. QuantillonVault

**Purpose**: Central vault managing QEURO minting and redemption against USDC collateral.

**Key Responsibilities**:
- Overcollateralized QEURO minting
- USDC collateral management
- Oracle price validation
- Liquidation-mode redemption when protocol CR is at or below the critical ratio (101%)
- Fee collection and distribution

**Architecture Patterns**:
- **Proxy Pattern**: Upgradeable implementation
- **Access Control**: Role-based permissions
- **Reentrancy Protection**: Secure external calls
- **Circuit Breaker**: Emergency pause mechanisms

### 2. QEUROToken

**Purpose**: Euro-pegged stablecoin with compliance and governance features.

**Key Features**:
- ERC-20 compliant with extensions
- Mint/burn controls via vault
- Compliance features (whitelist/blacklist)
- Rate limiting mechanisms
- Supply cap management

**Architecture Patterns**:
- **Factory Pattern**: Controlled token creation
- **Observer Pattern**: Event-driven compliance
- **State Machine**: Pause/unpause states

### 3. QTIToken

**Purpose**: Governance token with vote-escrow mechanics for protocol governance.

> **Status: dormant.** No mint path is wired in the deployed contract, so total supply is 0 and lock/vote/propose are inactive until a future activation upgrade mints the cap. The features below describe the intended design.

**Key Features**:
- Vote-escrow token mechanics
- Time-weighted voting power
- Governance proposal system
- Delegation capabilities
- Lock period management

**Architecture Patterns**:
- **Escrow Pattern**: Time-locked voting power; topping up an existing lock recomputes voting power over the **full merged position** (not just the added amount)
- **Voting System**: On-chain self-execution — the token holds `GOVERNANCE_ROLE`, so a passed proposal executes its own role-gated calldata after a mandatory post-vote timelock (`PROPOSAL_EXECUTION_DELAY`, 2 days). Activation requires the Safe to grant `GOVERNANCE_ROLE` to the QTI proxy.
- **Decay Function**: Linear voting power decay

### 4. UserPool

**Purpose**: Optional batch front-end for deposits (USDC → QEURO through the vault) and QEURO staking with an unstaking cooldown.

**Key Features**:
- Batched USDC deposit / QEURO withdrawal routed through `QuantillonVault`
- QEURO staking with `requestUnstake` → 7-day cooldown → `unstake`
- Pending-withdrawal escrow when a USDC transfer to the user fails
- User position tracking (`getUserInfo`)
- No reward claim: user yield accrues through stQEURO (ERC-4626 share price)

**Architecture Patterns**:
- **Pool Pattern**: Centralized escrow of staked QEURO
- **Cooldown Gate**: Time-locked unstaking
- **State Tracking**: User position management

### 5. HedgerPool

**Purpose**: Manages leveraged hedging positions for risk management.

**Key Features**:
- EUR/USD hedging positions
- Margin management system
- Liquidation mechanisms
- Position tracking and PnL calculation
- Risk parameter management

**Architecture Patterns**:
- **Position Management**: Individual position tracking
- **Margin System**: Collateral and leverage management
- **Liquidation Engine**: Automated risk management
- **Oracle Integration**: Price feed validation

### 6. stQEUROToken

**Purpose**: Yield-bearing wrapper for QEURO with automatic yield accrual.

**Key Features**:
- Automatic yield distribution via exchange rate
- Exchange rate = `totalAssets() / totalSupply()` (standard ERC-4626 share price; it rises when `QuantillonVault.creditVaultYield` mints QEURO into the token without minting shares)
- No lock-up period — unstake at any time
- Virtual protection against donation attacks

**Architecture Patterns**:
- **Wrapper Pattern**: Enhanced token functionality
- **Yield Distribution**: Exchange rate increases as yield accrues
- **Virtual Protection**: Attack prevention mechanisms

### 6b. stQEUROFactory (Multi-Vault Extension)

**Purpose**: Factory/orchestrator that deploys one `stQEUROToken` proxy per staking vault.

**Key Features**:
- Per-vault token deployment using `ERC1967Proxy` and shared `stQEUROToken` implementation
- Deterministic registry and lookup mappings:
  - `vaultId -> stQEURO token`
  - `vault -> stQEURO token`
  - `stQEURO token -> vaultId`
- Strict vault self-registration model (`msg.sender` is the registered vault)
- Validation and uniqueness guarantees for `vaultId` and `vaultName` (uppercase alphanumeric)
- Governance-controlled factory config (implementation/yieldShift/treasury/token admin)

**Architecture Patterns**:
- **Factory Pattern**: Dynamic deployment of homogeneous staking-token proxies
- **Registry Pattern**: Bi-directional mapping between vaults and staking tokens
- **Role-Gated Self-Registration**: Vault onboarding constrained by governance-granted role + on-chain self-call

### 7. FeeCollector

**Purpose**: Centralized fee collection and distribution across the protocol.

**Key Features**:
- Collects fees from QuantillonVault (mint/redeem fees)
- Distributes to three beneficiaries: treasury (60%), dev fund (25%), community (15%)
- Governance-controlled ratio updates
- Per-token fee accounting

**Architecture Patterns**:
- **Pull Pattern**: Beneficiaries withdraw collected fees
- **Split Pattern**: Configurable fee ratio distribution

### 8. OracleRouter

**Purpose**: Oracle-agnostic price routing — all protocol contracts interact with OracleRouter via `IOracle`.

**Key Features**:
- Holds two EUR/USD oracle slots and routes all `IOracle` reads to the **active** one
- Slot 0 = `ChainlinkOracle` (fallback); slot 1 = `HyperliquidEurUsdOracle` (**active since the governance switch of 2026-06-25**)
- Governance switches sources at runtime via `switchOracle` — no protocol-contract changes
- `updateOracleAddresses` repoints a slot; `OracleSwitched` event on switch

### 9. EUR/USD Oracles (HyperliquidEurUsdOracle · ChainlinkOracle · StorkOracle)

**Purpose**: EUR/USD pricing with freshness checks, price bounds, and deviation circuit breakers. All implement `IOracle`, so the router (and thus the protocol) is source-agnostic.

**Key Features**:
- **HyperliquidEurUsdOracle** (active): mirrors the Hyperliquid `xyz:EUR` perpetual mid — the venue where the protocol's EUR/USD hedge executes — so QEURO mint/redeem aligns with the hedge. Reads the mid from `SlippageStorage` (published on-chain by the off-chain Slippage Monitor) and delegates USDC/USD to the `ChainlinkOracle`. Configurable staleness (default 900s), bounds (0.80–1.40e18), 5% deviation circuit breaker, last-valid fallback.
- **ChainlinkOracle** (fallback): Chainlink AggregatorV3 EUR/USD + USDC/USD; 2-hour EUR/USD staleness (25h for USDC/USD, matching its daily heartbeat), 5% deviation circuit breaker. Also the protocol's USDC/USD validation source.
- **StorkOracle**: Stork Network `TemporalNumericValue` feeds (legacy/parked; the slot-1 position is now occupied by `HyperliquidEurUsdOracle`).
- Mock versions available (`MockChainlinkOracle`, `MockStorkOracle`) for local/testnet.
- Full design: **[Oracle Architecture](Oracle-Architecture.md)**.

### 9b. SlippageStorage

**Purpose**: On-chain store written by the off-chain Slippage Monitor; holds the published Hyperliquid `xyz:EUR` mid per source, which `HyperliquidEurUsdOracle` reads. `WRITER_ROLE`-gated writes with an on-chain minimum-interval rate limit.

### 10. TimeProvider

**Purpose**: Centralized `block.timestamp` wrapper for consistent time management across all contracts.

---

## Yield Management Architecture

### YieldShift System

**Purpose**: Intelligent yield distribution between user and hedger pools.

**Components**:
- **Yield Sources**: external staking vaults (MetaMorpho live via `MetaMorphoStakingVaultAdapter`; Morpho/Aave adapters for localhost), protocol fees, interest differentials
- **Distribution Engine**: Dynamic allocation between pools
- **Performance Metrics**: Yield tracking and optimization
- **Rebalancing Logic**: Automatic pool rebalancing

**Architecture Patterns**:
- **Strategy Pattern**: Multiple yield source strategies
- **Observer Pattern**: Performance monitoring
- **Factory-Routed Distribution**: Yield routed by `vaultId` through `stQEUROFactory` to the correct staking token

### External Staking Vault Integration

**Purpose**: Yield generation by deploying protocol USDC into external yield vaults (MetaMorpho live in production; Morpho/Aave adapters available).

**Features**:
- USDC deployment per `vaultId` via `QuantillonVault.deployUsdcToVault`
- Yield harvesting and distribution via `harvestAndDistributeVaultYield`
- One stQEURO series per vault (isolated yield accounting)
- Governance-gated exposure decisions per vault

**Architecture Patterns**:
- **Adapter Pattern**: thin `IExternalStakingVault` adapters wrap each external vault
- **Factory Registry**: `stQEUROFactory` maps `vaultId` to adapter + stQEURO series
- **Yield Optimization**: Dynamic allocation strategies
- **Vault-Aware Routing**: harvested external-vault yield is split by `QuantillonVault.harvestAndDistributeVaultYield` (hedger funding / stQEURO stakers / treasury); `YieldShift.addYield(vaultId, ...)` stays available for other authorized sources

---

## Security Architecture

### Access Control System

**Role-Based Access Control (RBAC)**:
- `MINTER_ROLE` / `BURNER_ROLE`: QEUROToken — vault-only mint/burn
- `PAUSER_ROLE`: QEUROToken emergency pause and minting killswitch
- `COMPLIANCE_ROLE`: QEUROToken blacklist/whitelist management
- `GOVERNANCE_ROLE`: Parameter updates and contract wiring across all core contracts (on FeeCollector it also gates upgrades)
- `EMERGENCY_ROLE`: Emergency pause and withdrawal across all core contracts; oracle circuit breakers
- `VAULT_OPERATOR_ROLE`: QuantillonVault — `deployUsdcToVault` (USDC deployment into any registered external vault adapter)
- `YIELD_DISTRIBUTOR_ROLE`: QuantillonVault — `harvestAndDistributeVaultYield` / `creditVaultYield`
- Hedging: no dedicated role — HedgerPool uses a single-hedger allowlist (`setSingleHedger`)
- `VAULT_FACTORY_ROLE`: stQEUROFactory — vault self-registration
- `TREASURY_ROLE` / `FEE_SOURCE_ROLE`: FeeCollector — fee distribution / authorized fee sources
- `ORACLE_MANAGER_ROLE`: OracleRouter / ChainlinkOracle / HyperliquidEurUsdOracle / StorkOracle / LighterEurUsdOracle (inert) — feed updates, oracle switching
- `MANAGER_ROLE` / `WRITER_ROLE`: SlippageStorage — store configuration / on-chain mid publishing
- `UPGRADER_ROLE`: the plain-UUPS proxies (oracles, SlippageStorage) — direct Safe upgrades; the `SecureUpgradeable` core proxies are gated by the 12 h TimelockController instead

### Security Patterns

**Reentrancy Protection**:
- `nonReentrant` modifier on all state-changing functions
- Checks-effects-interactions pattern
- External call isolation

**Oracle Security**:
- Multiple price feed validation
- Staleness checks
- Circuit breaker mechanisms
- Price bound validation

**Emergency Systems**:
- Pause/unpause mechanisms
- Emergency withdrawal functions
- Circuit breaker activation
- Recovery procedures

---

## Data Flow Architecture

### QEURO Minting Flow

```
QEURO Minting Flow:
┌─────────┐    ┌──────────────┐    ┌─────────────────┐    ┌─────────────┐
│  User   │    │QuantillonVault│    │ OracleRouter    │    │QEUROToken   │
└────┬────┘    └──────┬───────┘    └────────┬────────┘    └──────┬──────┘
     │                │                      │                    │
     │ approve()      │                      │                    │
     ├───────────────▶│                      │                    │
     │ mintQEURO()    │                      │                    │
     ├───────────────▶│                      │                    │
     │                │ getEurUsdPrice()     │                    │
     │                ├─────────────────────▶│ → active slot      │
     │                │ price, isValid       │ (HyperliquidEurUsdOracle)
     │                │◀─────────────────────┤                    │
     │                │ validatePrice()      │                    │
     │                │ calculateMintAmount()│                    │
     │                │ transferFrom()       │                    │
     │                │ mint()               │                    │
     │                ├─────────────────────────────────────────▶│
     │                │ emit QEUROminted()   │                    │
     │ success        │                      │                    │
     │◀───────────────┤                      │                    │
```

`OracleRouter` forwards `getEurUsdPrice()` to its active slot (HyperliquidEurUsdOracle since 2026-06-25; ChainlinkOracle as fallback). The read is non-`view` — a fresh valid price refreshes the deviation baseline — and `isValid = false` reverts the mint with `InvalidOraclePrice`.

### Yield Distribution Flow

```
Yield Distribution Flow (QuantillonVault.harvestAndDistributeVaultYield):
┌──────────┐  ┌───────────────┐  ┌──────────────┐  ┌───────────┐  ┌───────────────┐
│  Keeper  │  │QuantillonVault│  │ Ext. adapter │  │  stQEURO  │  │ hedger recip. │
│ (YIELD_  │  │               │  │ (MetaMorpho) │  │(per vault)│  │  / treasury   │
│DISTRIB.) │  │               │  │              │  │           │  │               │
└────┬─────┘  └───────┬───────┘  └──────┬───────┘  └─────┬─────┘  └───────┬───────┘
     │ harvestAndDistributeVaultYield(vaultId)      │              │
     ├─────────────▶│                  │            │              │
     │              │ harvestYieldToVault()         │              │
     │              ├─────────────────▶│            │              │
     │              │ realizedYield (USDC above tracked principal) │
     │              │◀─────────────────┤            │              │
     │              │ hedgerShare = fundingRateAnnualBps × principal × Δt (paid first)
     │              ├──────────────────────────────────────────────▶│
     │              │ userShare → _creditVaultYield(): mint QEURO into stQEURO (share price ↑)
     │              ├───────────────────────────────▶│              │
     │              │ treasuryShare (USDC remainder) │              │
     │              ├──────────────────────────────────────────────▶│
     │              │ emit VaultYieldDistributed(vaultId, realizedYield, hedgerShare, userShare, treasuryShare)
```

See the [Staking Yield Distribution](./Staking-Yield-Distribution.md) guide for the split formula and parameters. `YieldShift.addYield(vaultId, ...)` remains the entrypoint for other authorized yield sources; external-vault yield no longer routes through it.

### Governance Flow

Live governance on Base mainnet is the 2-of-3 Safe plus an OpenZeppelin `TimelockController` (12 h `minDelay`, Safe = sole proposer/executor). The QTI on-chain governance path (`lock` → `createProposal` → `vote` → self-execution after `PROPOSAL_EXECUTION_DELAY`) is coded but **dormant**: QTI supply is 0 and the token holds no `GOVERNANCE_ROLE`.

```
Governance Flow (live):
┌────────────┐    ┌───────────────────┐    ┌───────────────────────────┐
│ Safe (2/3) │    │ TimelockController│    │ SecureUpgradeable proxy   │
└─────┬──────┘    └─────────┬─────────┘    └─────────────┬─────────────┘
      │ schedule(upgradeToAndCall)           │
      ├────────────────────▶│                │
      │      ... 12 h minDelay ...           │
      │ execute()           │                │
      ├────────────────────▶│ upgradeToAndCall(newImpl)
      │                     ├───────────────▶│  _authorizeUpgrade: msg.sender == timelock
      │
      │ Parameter changes on every contract, and upgrades of the plain-UUPS proxies
      │ (FeeCollector, oracles, SlippageStorage): one direct Safe transaction on the
      │ target (GOVERNANCE_ROLE / ORACLE_MANAGER_ROLE / UPGRADER_ROLE), no delay
      ├──────────────────────────────────────────────────▶ target contract
```

---

## Scalability Architecture

### Gas Optimization

**Storage Optimization**:
- Packed structs for efficient storage
- Batch operations for multiple updates
- Event-based logging instead of storage
- Minimal state variables

**Computation Optimization**:
- Cached values for repeated calculations
- Efficient algorithms for complex operations
- Minimal external calls
- Optimized loops and iterations

### Upgradeability

**Proxy Pattern Implementation**:
- ERC1967 + UUPS proxies for every upgradeable contract (no transparent proxies)
- Core contracts inherit `SecureUpgradeable`: `_authorizeUpgrade` requires the call to come from the configured `timelock` — on Base mainnet the 12 h OpenZeppelin `TimelockController`
- Oracles, SlippageStorage and FeeCollector are plain UUPS proxies upgraded directly by the governance Safe (no timelock)
- Storage-layout compatibility and ABI additivity are enforced by `make check-upgrade-safety`

**Upgrade Process**:
1. Deploy and verify the new implementation (run `make check-verifiable-bytecode CONTRACT=<Name>` first)
2. Validate compatibility (`make check-upgrade-safety`: size, storage layout, ABI, version bump)
3. `SecureUpgradeable` proxies: the Safe schedules `upgradeToAndCall` on the TimelockController, waits 12 h, then executes; plain-UUPS proxies: the Safe calls `upgradeToAndCall` directly
4. Verify `version()` on the proxy and record it in `deployments/{chainId}/versions.json`

---

## Integration Architecture

### External Integrations

**Oracle System (OracleRouter + HyperliquidEurUsdOracle + ChainlinkOracle)**:
- OracleRouter implements `IOracle` — all protocol contracts use this interface
- Active oracle is switchable by governance (`switchOracle`: Hyperliquid ↔ Chainlink) without contract changes; HyperliquidEurUsdOracle has been the active slot since 2026-06-25
- HyperliquidEurUsdOracle: Hyperliquid `xyz:EUR` perp mid read from SlippageStorage (published on-chain by the off-chain Slippage Monitor); 900 s staleness (1 h hard cap); 5% deviation circuit breaker; USDC/USD delegated to ChainlinkOracle
- ChainlinkOracle: EUR/USD + USDC/USD via Chainlink AggregatorV3; 2 h EUR/USD staleness check (25 h USDC/USD); 5% deviation circuit breaker; Base L2 sequencer-uptime feed check
- StorkOracle: parked (former slot-1 oracle, still deployed). LighterEurUsdOracle: deployed 2026-07-17 and inert — the Lighter venue was not adopted (2026-09-01)
- MockChainlinkOracle + MockStorkOracle available for local/testnet development

**External Yield Vaults (Morpho / Aave)**:
- USDC deployment through `IExternalStakingVault` adapters (MetaMorpho live, vaultId 2)
- Yield harvesting and distribution via `QuantillonVault.harvestAndDistributeVaultYield`
- Governance-gated exposure per `vaultId`
- Emergency withdrawal mechanisms

**ERC-20 Standards**:
- Full ERC-20 compliance
- Extended functionality
- Metadata support

### API Architecture

**Contract Interfaces**:
- Standardized function signatures
- Consistent error handling
- Event emission patterns
- Access control integration

**Integration Patterns**:
- Factory pattern for contract creation
- Registry pattern for contract discovery
- Proxy pattern for upgrades
- Adapter pattern for external integrations

---

## Monitoring and Observability

### Event Architecture

**Core Events**:
- Token transfers and approvals
- Vault operations (mint/redeem)
- Staking and unstaking
- Yield distribution
- Governance actions

**Monitoring Events**:
- System health indicators
- Performance metrics
- Error conditions
- Security events

### Analytics Architecture

**On-Chain Analytics**:
- Transaction volume tracking
- Yield performance metrics
- User behavior analysis
- Risk metrics monitoring

**Off-Chain Analytics**:
- Protocol health dashboards
- Performance reporting
- Risk assessment
- Compliance monitoring

---

## Architecture Principles

### Design Principles

1. **Security First**: All components designed with security as the primary concern
2. **Modularity**: Clear separation of concerns and modular design
3. **Upgradeability**: Future-proof design with upgrade capabilities
4. **Gas Efficiency**: Optimized for cost-effective operations
5. **Transparency**: Open and auditable code and processes

### Development Principles

1. **Test-Driven Development**: Comprehensive test coverage
2. **Documentation**: Complete documentation for all components
3. **Code Review**: Rigorous review process for all changes
4. **Continuous Integration**: Automated testing and deployment
5. **Security Audits**: Regular security assessments

---

*This architecture document is maintained by Quantillon Labs and updated with each protocol version.*
