# Graph Report - quantillon-protocol/src+docs+test  (2026-04-07)

## Corpus Check
- 116 files · ~376,179 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 306 nodes · 455 edges · 22 communities detected
- Extraction: 68% EXTRACTED · 31% INFERRED · 0% AMBIGUOUS · INFERRED: 143 edges (avg confidence: 0.63)
- Token cost: 18,500 input · 2,800 output

## God Nodes (most connected - your core abstractions)
1. `Quantillon Protocol Architecture` - 18 edges
2. `c()` - 13 edges
3. `QuantillonVault Contract` - 13 edges
4. `m()` - 12 edges
5. `Quantillon Protocol Documentation Index` - 11 edges
6. `Documentation Summary / Table of Contents` - 10 edges
7. `stQEUROFactory Contract` - 10 edges
8. `e()` - 9 edges
9. `u()` - 8 edges
10. `Multi-Vault Staking Runtime Flow` - 8 edges

## Surprising Connections (you probably didn't know these)
- `External Vault Onboarding Runbook (src mirror)` --semantically_similar_to--> `External Vault Onboarding Runbook`  [INFERRED] [semantically similar]
  quantillon-protocol/docs/src/External-Vault-Onboarding-Runbook.md → quantillon-protocol/docs/External-Vault-Onboarding-Runbook.md
- `Multi-Vault Staking Flow (src mirror)` --semantically_similar_to--> `Multi-Vault Staking Runtime Flow`  [INFERRED] [semantically similar]
  quantillon-protocol/docs/src/Multi-Vault-Staking-Flow.md → quantillon-protocol/docs/Multi-Vault-Staking-Flow.md
- `stQEUROFactory Upgrade Note (src mirror)` --semantically_similar_to--> `stQEUROFactory Multi-Vault Technical Upgrade Note`  [INFERRED] [semantically similar]
  quantillon-protocol/docs/src/stQEUROFactory.md → quantillon-protocol/docs/stQEUROFactory.md
- `Dev Mode 48-Hour Timelock (proposeDevMode/applyDevMode)` --semantically_similar_to--> `UUPS Upgradeable Proxy Pattern`  [INFERRED] [semantically similar]
  quantillon-protocol/docs/src/src/oracle/ChainlinkOracle.sol/contract.ChainlinkOracle.md → quantillon-protocol/docs/Architecture.md
- `TimelockUpgradeable` --conceptually_related_to--> `AaveVault`  [INFERRED]
  quantillon-protocol/docs/src/src/core/TimelockUpgradeable.sol/contract.TimelockUpgradeable.md → quantillon-protocol/docs/src/src/core/vaults/AaveVault.sol/contract.AaveVault.md

## Hyperedges (group relationships)
- **Oracle Abstraction: OracleRouter routes IOracle calls to ChainlinkOracle or StorkOracle** — concept_oracle_router, concept_chainlink_oracle, concept_stork_oracle, concept_ioracle_interface [EXTRACTED 1.00]
- **Multi-Vault Staking Registration: stQEUROFactory deploys stQEUROToken proxy per vaultId with self-registration from QuantillonVault** — concept_stqeuro_factory, concept_stqeuro_token, concept_quantillon_vault, concept_vault_id [EXTRACTED 1.00]
- **Yield Distribution Pipeline: AaveVault harvests to YieldShift which routes to stQEURO token per vaultId** — concept_aave_vault, concept_yield_shift, concept_stqeuro_factory, concept_yield_routing_vault_id [EXTRACTED 0.95]
- **Domain-Specific Error Libraries Pattern** — commonerrorlibrary_lib, hedgerpoolerrorlibrary_lib, vaulterrorlibrary_lib, governanceerrorlibrary_lib [EXTRACTED 0.95]
- **HedgerPool Logic, Validation, and Error Libraries Trio** — hedgerpoollogic_lib, hedgerpoolvalidation_lib, hedgerpoolerrorlibrary_lib [INFERRED 0.85]
- **Oracle Contracts Using TimeProvider Pattern** — storkoracle_contract, slippagestorage_contract, timeprovider_contract [EXTRACTED 0.95]
- **Symmetric Vault Adapters Implementing IExternalStakingVault** — contract_aavestakingvaultadapter, contract_morphostakingvaultadapter, contract_aavevault, concept_iexternalstakingvault [EXTRACTED 1.00]
- **Yield Distribution Subsystem (TWAP + Holding Period + Validation)** — contract_yieldshift, lib_yieldshiftoptimizationlibrary, lib_yieldvalidationlibrary, concept_twap_mechanism, concept_holding_period, struct_poolsnapshot, struct_yieldshiftsnapshot [INFERRED 0.90]
- **Flash Attack Defense Subsystem** — lib_flashloanprotection, lib_pricevalidationlibrary, concept_holding_period, concept_flash_loan_defense [INFERRED 0.85]
- **Core Protocol Contracts System** — core_userpool, core_quantillonvault, core_hedgerpool, core_stqeurofactory, core_feecollector, core_secureupgradeable [INFERRED 0.90]
- **Mock Contracts Test Harness System** — mock_mockaavevault, mock_mockmorphovault, mock_mockstorkoracle, mock_mockusdc, mock_mockchainlinkoracle [EXTRACTED 1.00]
- **Interface Layer Decoupling Core Contracts** — iface_ioracle, iface_ihedgerpool, iface_iuserpool, iface_iyieldshift, iface_istqeuro, iface_iaavevault [INFERRED 0.85]
- **Oracle Abstraction Layer: IOracle, IChainlinkOracle, IStorkOracle** — interface_ioracle, interface_ichainlinkoracle, interface_istorkoracle [EXTRACTED 1.00]
- **Secure Upgrade Subsystem: ISecureUpgradeable + ITimelockUpgradeable + multi-sig** — interface_isecureupgradeable, interface_itimelockupgradeable, concept_multisig_timelock, concept_uups_upgrade_pattern [EXTRACTED 0.95]
- **Quantillon Protocol Branding Assets** — docs_banner_png, docs_favicon_png, book_favicon_svg, book_favicon_png [INFERRED 0.85]

## Communities

### Community 0 - "Highlight.js Syntax Library"
Cohesion: 0.09
Nodes (17): a(), b(), c(), d(), e(), I(), l(), m() (+9 more)

### Community 1 - "Protocol Documentation & Deployment"
Cohesion: 0.09
Nodes (43): Quantillon Protocol API Reference, Quantillon Protocol Architecture, AaveVault Contract, Protocol Collateralization Ratio (>=105%, liquidation at 101%), Deployment Dependency Order, DeployQuantillon.s.sol Deployment Script, ERC1967Proxy, FeeCollector Contract (+35 more)

### Community 2 - "Core Architecture & Design Decisions"
Cohesion: 0.09
Nodes (33): Overcollateralization 105% Minting / 101% Liquidation, CREATE2 Deterministic Proxy Deployment, Dual-Pool Architecture (UserPool + HedgerPool), Emergency Disable 24h Timelock with Quorum, FEE_SOURCE_ROLE Depositor/Withdrawer Separation, Fee Distribution 60/25/15 Split (Treasury/Dev/Community), Hedgers Are SHORT EUR P&L Model, Interface Segregation Design (+25 more)

### Community 3 - "Vault Adapters & EIP-170 Pattern"
Cohesion: 0.09
Nodes (31): AaveStakingVaultAdapter Contract, EIP-170 Bytecode Size Reduction via Libraries, Flash Loan Attack Defense, 7-Day Holding Period Flash Attack Defense, IExternalStakingVault Interface, MorphoStakingVaultAdapter Contract, Rationale: Symmetric Adapter Pattern for Aave/Morpho, Symmetric Adapter Pattern (Aave vs Morpho) (+23 more)

### Community 4 - "Error & Validation Libraries"
Cohesion: 0.08
Nodes (31): AdminFunctionsLibrary, CommonErrorLibrary, CommonValidationLibrary, ErrorLibrary, FlashLoanProtectionLibrary, GovernanceErrorLibrary, HedgerPoolErrorLibrary, HedgerPoolLogicLibrary (+23 more)

### Community 5 - "Oracle System & Circuit Breaker"
Cohesion: 0.08
Nodes (30): ChainlinkOracle Contract Reference, ChainlinkOracle Contract, Oracle Circuit Breaker, Dev Mode 48-Hour Timelock (proposeDevMode/applyDevMode), External Yield Adapter Pattern (IExternalStakingVault), IOracle Interface, MAX_PRICE_DEVIATION (5% / 500 bps), MAX_PRICE_STALENESS (3600s) (+22 more)

### Community 6 - "mdBook UI Theme & Sidebar"
Cohesion: 0.12
Nodes (13): fetch_with_timeout(), get_saved_theme(), get_theme(), handle_crate_list_update(), hideSidebar(), playground_text(), resize(), run_rust_code() (+5 more)

### Community 7 - "mdBook Search Engine"
Cohesion: 0.22
Nodes (19): doSearch(), doSearchOrMarkFromUrl(), formatSearchMetric(), formatSearchResult(), globalKeyHandler(), hasFocus(), init(), initSearchInteractions() (+11 more)

### Community 8 - "Custom Documentation JS"
Cohesion: 0.25
Nodes (2): addSearchHighlighting(), highlightSearchTerm()

### Community 9 - "Clipboard.js Library"
Cohesion: 0.29
Nodes (0): 

### Community 10 - "Secure Upgrade & Timelock"
Cohesion: 0.33
Nodes (6): Multi-Sig Timelock Upgrade Pattern, PendingUpgrade Struct, UUPS Secure Upgrade Pattern, TimelockUpgradeable, ISecureUpgradeable Interface, ITimelockUpgradeable Interface

### Community 11 - "Solidity Syntax Highlighter"
Cohesion: 0.5
Nodes (2): e(), x()

### Community 12 - "Quantillon Branding Assets"
Cohesion: 0.4
Nodes (5): mdBook Favicon PNG, mdBook Favicon SVG (Q letter mark), Quantillon Protocol Banner Image, Quantillon Protocol Favicon (docs root), Quantillon Protocol Brand Identity

### Community 13 - "mdBook TOC Component"
Cohesion: 0.5
Nodes (1): MDBookSidebarScrollbox

### Community 14 - "Documentation Typography"
Cohesion: 0.5
Nodes (4): Documentation Assets README, Font Awesome Webfont SVG, Open Sans Font, Source Code Pro Font

### Community 15 - "Mark.js Text Highlighter"
Cohesion: 0.67
Nodes (0): 

### Community 16 - "ElasticLunr Search Index"
Cohesion: 1.0
Nodes (0): 

### Community 17 - "Search Index Data"
Cohesion: 1.0
Nodes (0): 

### Community 18 - "Docs Source README"
Cohesion: 1.0
Nodes (1): Quantillon Protocol Docs src README

### Community 19 - "Documentation Summary"
Cohesion: 1.0
Nodes (1): Documentation SUMMARY (src mirror)

### Community 20 - "Protocol Source README"
Cohesion: 1.0
Nodes (1): Quantillon Protocol src/src README

### Community 21 - "Oracle Module README"
Cohesion: 1.0
Nodes (1): Oracle Module README

## Ambiguous Edges - Review These
- `Fee Distribution 60/25/15 Split (Treasury/Dev/Community)` → `Interface Segregation Design`  [AMBIGUOUS]
  quantillon-protocol/docs/src/src/core/FeeCollector.sol/contract.FeeCollector.md · relation: conceptually_related_to

## Knowledge Gaps
- **70 isolated node(s):** `Contributing to Quantillon Protocol Documentation`, `External Vault Onboarding Runbook (src mirror)`, `Quantillon Protocol Docs src README`, `Multi-Vault Staking Flow (src mirror)`, `Documentation SUMMARY (src mirror)` (+65 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `ElasticLunr Search Index`** (2 nodes): `elasticlunr.min.js`, `e()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Search Index Data`** (1 nodes): `searchindex.js`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Docs Source README`** (1 nodes): `Quantillon Protocol Docs src README`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Documentation Summary`** (1 nodes): `Documentation SUMMARY (src mirror)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Protocol Source README`** (1 nodes): `Quantillon Protocol src/src README`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Oracle Module README`** (1 nodes): `Oracle Module README`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Fee Distribution 60/25/15 Split (Treasury/Dev/Community)` and `Interface Segregation Design`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `IMockAaveVault` connect `Vault Adapters & EIP-170 Pattern` to `Core Architecture & Design Decisions`?**
  _High betweenness centrality (0.026) - this node is a cross-community bridge._
- **Why does `MockAaveVault Contract` connect `Core Architecture & Design Decisions` to `Vault Adapters & EIP-170 Pattern`?**
  _High betweenness centrality (0.026) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `c()` (e.g. with `a()` and `t()`) actually correct?**
  _`c()` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Are the 11 inferred relationships involving `m()` (e.g. with `b()` and `t()`) actually correct?**
  _`m()` has 11 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Contributing to Quantillon Protocol Documentation`, `External Vault Onboarding Runbook (src mirror)`, `Quantillon Protocol Docs src README` to the rest of the system?**
  _70 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Highlight.js Syntax Library` be split into smaller, more focused modules?**
  _Cohesion score 0.09 - nodes in this community are weakly interconnected._