# Unit Testing Overview — Quantillon Protocol

## Scope

This document describes the **current state of testing** for the `quantillon-protocol` Solidity smart contracts as implemented in this repository.

It is **purely descriptive** and does **not** contain recommendations or future plans.

The content reflects the test suite state **after** the latest round of improvements, including: integration and deployment smoke tests, combined attack vector tests, liquidation scenario tests (partial, same-block, CR boundary), invariant handler wiring for Foundry invariant mode, placeholder replacement with executable assertions or explicit `vm.skip` and rationale, CI workflow, and Foundry config alignment.

---

## Testing Summary

| Metric | Value |
|--------|-------|
| Total test functions (test_ + testFuzz_ + invariant_) | ~1,109 |
| Test files (`.t.sol`) | 43 |
| Disabled tests (xtest_) | 0 |
| Dedicated fuzz test file | `VaultMathFuzz.t.sol` |
| Invariant test file | `QuantillonInvariants.t.sol` (15 invariant functions) |
| Fuzz tests | In `VaultMathFuzz.t.sol`, `QuantillonInvariants.t.sol`, `TimeProvider.t.sol`, `YieldValidationLibrary.t.sol`, `TokenValidationLibrary.t.sol`, and library test files |

*Note: `forge test` may report a higher number of tests run due to fuzz iterations.*

---

## Testing Frameworks, Tools, and Configuration

- **Core test framework**
  - **Foundry / Forge**
    - Configured via `foundry.toml` with:
      - `src = "src"`, `test = "test"`, `out = "out"`, `libs = ["lib"]`
      - `solc_version = "0.8.24"`, `evm_version = "paris"`
      - Optimizer enabled with `optimizer_runs = 200` and `via_ir = true` for the default profile
      - `[profile.coverage]` for coverage runs
      - `[profile.test]` with `optimizer = false`, `via_ir = false`
    - Fuzzing and invariant:
      - `[profile.default.fuzz]` with `runs = 1000`
      - `[profile.default.invariant]` with `runs = 256`, `depth = 15`, `fail_on_revert = false`
    - Lint and doc: `[lint]` with `exclude_lints`; `[doc]` with `out` and `ignore` (per Foundry schema)

- **Assertion / utility library**
  - `forge-std/Test.sol` used across tests for:
    - `vm` cheatcodes
    - Assertion helpers (`assertEq`, `assertGt`, `assertTrue`, `assertGe`, `assertLe`, `assertFalse`, `assertApproxEqRel`, etc.)
    - Logging via `console` where needed

- **Security and analysis tooling**
  - **Slither** — configured via `slither.config.json`, invoked via `make slither`
  - **Mythril** — invoked via `make mythril`
  - **NatSpec validation** — `make validate-natspec` runs `scripts/validate-natspec.js`
  - **Gas analysis** — `make gas-analysis`, `make benchmark-gas`
  - **Contract size and warnings** — `make analyze-contract-sizes`, `make analyze-warnings`

- **Makefile integration**
  - `make test` — runs `forge test`
  - `make coverage` — runs `FOUNDRY_PROFILE=coverage forge coverage --report lcov --ir-minimum`
  - `make all` — build, test, coverage, slither, docs, gas-analysis, analyze-warnings, analyze-contract-sizes
  - `make ci` — build, test, slither, validate-natspec, gas-analysis, analyze-warnings, analyze-contract-sizes

---

## Test Types and Locations

All Solidity tests live under `test/` and use Foundry’s Forge test runner.

### Unit tests

- **Core tokens and fee**
  - `test/QEUROToken.t.sol`, `test/QEUROTokenBasic.t.sol`
  - `test/QTIToken.t.sol`
  - `test/stQEUROToken.t.sol`
  - `test/FeeCollector.t.sol`
- **Time and oracles**
  - `test/TimeProvider.t.sol`
  - `test/ChainlinkOracle.t.sol`, `test/StorkOracle.t.sol`, `test/OracleRouter.t.sol`, `test/OracleEdgeCases.t.sol`
- **Vault and math**
  - `test/VaultMath.t.sol`, `test/LibraryTests.t.sol`
  - `test/QuantillonVault.t.sol`
- **Upgradeability**
  - `test/SecureUpgradeable.t.sol`, `test/TimelockUpgradeable.t.sol`
- **Pools and yield**
  - `test/UserPool.t.sol`, `test/HedgerPool.t.sol`
  - `test/YieldShift.t.sol`
  - `test/AaveVault.t.sol`
- **Libraries (dedicated suites)**
  - `test/FlashLoanProtectionLibrary.t.sol`
  - `test/TreasuryRecoveryLibrary.t.sol`
  - `test/AccessControlLibrary.t.sol`
  - `test/PriceValidationLibrary.t.sol`
  - `test/YieldValidationLibrary.t.sol`
  - `test/TokenValidationLibrary.t.sol`

These focus on single contracts or libraries with direct calls and assertions on state, events, errors, and boundary cases.

### Integration / system workflow tests

- **Full workflow**
  - `test/IntegrationTests.t.sol` — deploys via `ERC1967Proxy`, wires dependencies, runs full flows (e.g. deposit → mint → stake → unstake → redeem, batch operations).
- **Deployment smoke**
  - `test/DeploymentSmoke.t.sol` — 4-phase deployment smoke tests: all contracts deployed, wiring, basic mint/redeem, staking roundtrip, governance sanity, oracle prices, emergency pause, multi-user mint.
- **Edge and integration**
  - `test/IntegrationEdgeCases.t.sol`
  - `test/HedgerVaultIntegration.t.sol`, `test/HedgerVaultRegression.t.sol`
  - `test/AaveIntegration.t.sol`
  - `test/YieldStakingEdgeCases.t.sol`, `test/TimeBlockEdgeCases.t.sol`, `test/GasResourceEdgeCases.t.sol`
- **Liquidation**
  - `test/LiquidationScenarios.t.sol` — end-to-end liquidation mode (CR ≤ 101%), pro-rata redemption, HedgerPool state, pause revert.
- **Combined attacks**
  - `test/CombinedAttackVectors.t.sol` — multi-step scenarios: flash loan + oracle manipulation blocked, governance-only param updates, yield extraction during volatility with bounded redemption.

### Security-focused tests

- `test/ReentrancyTests.t.sol` — reentrancy scenarios with attacker contracts
- `test/EconomicAttackVectors.t.sol` — economic attack scenarios
- `test/GovernanceAttackVectors.t.sol` — governance attack scenarios
- `test/RaceConditionTests.t.sol` — race conditions and concurrent patterns
- `test/UpgradeTests.t.sol` — upgrade paths and proxy upgrades

### Fuzz / property-based tests

- **Dedicated fuzz file**
  - `test/VaultMathFuzz.t.sol` — fuzzing `mulDiv`, `percentageOf`, `scaleDecimals`, min/max, EUR/USD helpers, collateral ratio, yield distribution.
- **Fuzz inside other suites**
  - `test/QuantillonInvariants.t.sol` — `testFuzz_MintMaintainsSupplyConsistency`, `testFuzz_StakeUnstakeRoundtrip`
  - `test/TimeProvider.t.sol` — time offset and advance fuzz
  - `test/YieldValidationLibrary.t.sol`, `test/TokenValidationLibrary.t.sol` — validation fuzz
  - Library test files (e.g. `FlashLoanProtectionLibrary.t.sol`, `PriceValidationLibrary.t.sol`) where applicable

### Invariant tests

- **`test/QuantillonInvariants.t.sol`**
  - **Wired for Foundry invariant mode**: `setUp()` calls `targetContract(address(handler))` and `targetSelector(FuzzSelector({...}))` so Forge can drive randomized action sequences.
  - **InvariantActionHandler** exposes `actionMint`, `actionRedeem`, `actionStake`, `actionUnstake` for fuzzed sequences.
  - **15 invariant functions** covering: supply consistency, supply cap, collateralization, liquidation thresholds, yield distribution, yield shift params, governance power/params, emergency/pause state, access control, math consistency, cross-contract integration, gas, liquidation state. One invariant (`invariant_gasOptimization`) uses `vm.skip` with rationale; `test_allInvariants()` is non-view so it can call it.
  - **Action-based / fuzz**: `test_ActionSequence_*`, `test_EmergencyPauseIntegrity`, `testFuzz_MintMaintainsSupplyConsistency`, `testFuzz_StakeUnstakeRoundtrip`.

---

## Code Areas Covered by Tests

### Core protocol contracts (`src/core/`)

| Contract | Primary Test Files |
|----------|--------------------|
| `QEUROToken.sol` | `QEUROToken.t.sol`, `QEUROTokenBasic.t.sol` |
| `QTIToken.sol` | `QTIToken.t.sol` |
| `stQEUROToken.sol` | `stQEUROToken.t.sol` |
| `QuantillonVault.sol` | `QuantillonVault.t.sol`, `IntegrationTests.t.sol`, `HedgerVaultIntegration.t.sol`, `LiquidationScenarios.t.sol`, `CombinedAttackVectors.t.sol` |
| `UserPool.sol` | `UserPool.t.sol`, `IntegrationEdgeCases.t.sol`, `YieldStakingEdgeCases.t.sol` |
| `HedgerPool.sol` | `HedgerPool.t.sol`, `HedgerVaultIntegration.t.sol`, `HedgerVaultRegression.t.sol`, `LiquidationScenarios.t.sol` |
| `AaveVault.sol` | `AaveVault.t.sol`, `AaveIntegration.t.sol` |
| `YieldShift.sol` | `YieldShift.t.sol`, `IntegrationTests.t.sol` |
| `FeeCollector.sol` | `FeeCollector.t.sol` |

### Oracle layer (`src/oracle/`)

| Contract | Primary Test Files |
|----------|--------------------|
| `ChainlinkOracle.sol` | `ChainlinkOracle.t.sol`, `OracleEdgeCases.t.sol` |
| `StorkOracle.sol` | `StorkOracle.t.sol` |
| `OracleRouter.sol` | `OracleRouter.t.sol`, `OracleEdgeCases.t.sol` |

### Libraries (`src/libraries/`)

| Library | Primary Test Files |
|---------|--------------------|
| `VaultMath.sol` | `VaultMath.t.sol`, `VaultMathFuzz.t.sol` |
| `FlashLoanProtectionLibrary.sol` | `FlashLoanProtectionLibrary.t.sol` |
| `TreasuryRecoveryLibrary.sol` | `TreasuryRecoveryLibrary.t.sol` |
| `AccessControlLibrary.sol` | `AccessControlLibrary.t.sol` |
| `PriceValidationLibrary.sol` | `PriceValidationLibrary.t.sol` |
| `YieldValidationLibrary.sol` | `YieldValidationLibrary.t.sol` |
| `TokenValidationLibrary.sol` | `TokenValidationLibrary.t.sol` |

Other libraries are exercised indirectly via core contract tests.

---

## How Tests Are Executed Locally

- **Full test run**
  ```bash
  make test   # or: forge test
  ```

- **Coverage**
  ```bash
  make coverage
  ```

- **Targeted runs**
  ```bash
  forge test --match-contract QuantillonVault
  forge test --match-test testFuzz_
  forge test --match-contract IntegrationTests -vvv
  ```

- **Security and auxiliary**
  ```bash
  make slither
  make mythril
  make validate-natspec
  make gas-analysis
  ```

---

## How Tests Are Executed in CI

- **Makefile**
  - Light path: `make build && make test`
  - Full CI: `make ci` (build, test, slither, validate-natspec, gas-analysis, analyze-warnings, analyze-contract-sizes)

- **GitHub Actions**
  - `.github/workflows/tests.yml` runs on push and pull_request to `main` and `master`: installs Foundry (`foundry-rs/foundry-toolchain@v1`), then `make build` and `make test`. Full checks (`make ci`) can be run locally or in a separate workflow.

---

## Testing Conventions and Patterns

- **Naming**
  - Test files: `<ContractOrDomainName>.t.sol`
  - Test functions: `test_<Description>`, `testFuzz_<Description>`, `invariant_<Description>`
  - No disabled `xtest_` functions in the suite

- **Structure**
  - Test contracts inherit `Test` from `forge-std/Test.sol`
  - `setUp()` deploys implementations, proxies, mocks, and assigns roles
  - Helpers such as `_deployEssentialContracts`, `_setupEssentialRoles`, `deployFullProtocol` are used where appropriate
  - Section comments used to group tests

- **Assertions and logging**
  - Assertions: `assertEq`, `assertGt`, `assertGe`, `assertLe`, `assertTrue`, `assertFalse`, `assertApproxEqRel`
  - `console.log` used for step-by-step tracing in integration tests when useful

- **Proxy and upgradeability**
  - Tests deploy `ERC1967Proxy` with initializer calldata and validate roles, initializer restrictions, and upgrade paths

- **Security tests**
  - Mock attacker contracts (e.g. reentrancy attacker, malicious tokens) and `vm.mockCall` for external simulations; scenarios grouped by attack class. Some scenarios use `vm.skip(true, "…")` with a short rationale when the test requires full protocol deployment or a harness that is not available; no bare `assertTrue(true, …)` placeholders remain.

- **Fuzz and invariants**
  - Fuzz: `testFuzz_*` with typed parameters and `vm.assume` where needed
  - Invariants: `invariant_*` naming; `InvariantActionHandler` used as the target for Foundry invariant fuzzing with `targetContract` and `targetSelector` in `setUp()`
