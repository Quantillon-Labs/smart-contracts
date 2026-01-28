## Scope

This document describes the **current state of testing** for the `quantillon-protocol` Solidity smart contracts as implemented in this repository.

It is **purely descriptive** and does **not** contain recommendations or future plans.

The content has been updated to reflect the test suite and CI state **after** the recent testing improvements (CI wiring, new fuzz/library tests, deployment smoke tests, and refactored integration/security tests).

---

## Testing Frameworks, Tools, and Configuration

- **Core test framework**
  - **Foundry / Forge**
    - Configured via `foundry.toml` with:
      - `src = "src"`, `test = "test"`, `out = "out"`, `libs = ["lib"]`
      - `solc_version = "0.8.24"`, `evm_version = "paris"`
      - Optimizer enabled with `optimizer_runs = 200` and `via_ir = true` for the default profile  
      - `FOUNDRY_PROFILE=coverage` profile defined for coverage runs with dedicated settings  
      - `FOUNDRY_PROFILE=test` profile defined with `optimizer = false`, `via_ir = false`
    - Fuzzing and invariant profiles:
      - `[profile.default.fuzz]` with `runs = 1000`
      - `[profile.default.invariant]` with `runs = 256`, `depth = 15`, `fail_on_revert = false`

- **Assertion / utility library**
  - `forge-std/Test.sol` used across tests for:
    - `vm` cheatcodes
    - assertion helpers (`assertEq`, `assertGt`, `assertTrue`, `assertGe`, `assertLe`, `assertFalse`, etc.)
    - logging via `console` in some tests

- **Security and analysis tooling**
  - **Slither**
    - Configured via `slither.config.json` (not detailed here; invoked from `Makefile`).
    - Executed through `make slither`, which calls `./scripts/run-slither.sh`.
  - **Mythril**
    - Invoked from `Makefile` via `make mythril`, which calls `./scripts/run-mythril.sh`.
  - **NatSpec validation**
    - `make validate-natspec` runs `scripts/validate-natspec.js` after installing JS dependencies.
  - **Gas analysis**
    - `make gas-analysis` runs `./scripts/analyze-gas.sh`.
    - `make benchmark-gas` runs `./scripts/benchmark-gas.sh`.
  - **Contract size and warning analysis**
    - `make analyze-contract-sizes` and `make analyze-warnings` both run dedicated shell scripts under `scripts/`.

-- **Makefile integration**
  - `make test` wraps `forge test`.
  - `make coverage` wraps `FOUNDRY_PROFILE=coverage forge coverage --report lcov --ir-minimum`.
  - `make all` runs: `build`, `test`, `coverage`, `slither`, `docs`, `gas-analysis`, `analyze-warnings`, `analyze-contract-sizes`.
  - `make ci` runs: `build`, `test`, `slither`, `validate-natspec`, `gas-analysis`, `analyze-warnings`, `analyze-contract-sizes`.

---

## Test Types and Locations

All Solidity tests live under `test/` and use Foundry’s Forge test runner.

### High-level categories

- **Unit tests**
  - Located primarily in:
    - `test/QEUROToken.t.sol`
    - `test/QEUROTokenBasic.t.sol`
    - `test/QTIToken.t.sol`
    - `test/stQEUROToken.t.sol`
    - `test/FeeCollector.t.sol`
    - `test/TimeProvider.t.sol`
    - `test/ChainlinkOracle.t.sol`
    - `test/StorkOracle.t.sol`
    - `test/OracleRouter.t.sol`
    - `test/VaultMath.t.sol`
    - `test/LibraryTests.t.sol`
    - `test/SecureUpgradeable.t.sol`
    - `test/TimelockUpgradeable.t.sol`
    - `test/AaveVault.t.sol`
    - New, focused unit suites for validation and helper libraries:
      - `test/FlashLoanProtectionLibrary.t.sol`
      - `test/TreasuryRecoveryLibrary.t.sol`
      - `test/AccessControlLibrary.t.sol`
      - `test/PriceValidationLibrary.t.sol`
      - `test/YieldValidationLibrary.t.sol`
      - `test/TokenValidationLibrary.t.sol`
  - These focus on single contracts or libraries with direct calls and assertions on state changes, events, error selectors, and boundary cases.

-- **Integration / system workflow tests**
  - Files that describe or simulate multi-contract flows include:
    - `test/IntegrationTests.t.sol`
    - `test/IntegrationEdgeCases.t.sol`
    - `test/HedgerVaultIntegration.t.sol`
    - `test/HedgerVaultRegression.t.sol`
    - `test/AaveIntegration.t.sol`
    - `test/YieldStakingEdgeCases.t.sol`
    - `test/TimeBlockEdgeCases.t.sol`
    - `test/GasResourceEdgeCases.t.sol`
    - `test/DeploymentSmoke.t.sol`
  - `IntegrationTests.t.sol` has been refactored to deploy real contracts (via `ERC1967Proxy`) and wire `TimeProvider`, `MockChainlinkOracle`, `MockUSDC`, `QEUROToken`, `QuantillonVault`, `stQEUROToken`, `UserPool`, and `HedgerPool`.  
    - The contract now has a realistic `setUp()` that performs these deployments and role assignments.
    - The original end-to-end tests (`test_CompleteProtocolWorkflow`, `test_BatchOperationsWorkflow`) have been **temporarily disabled** by renaming them to `xtest_*` so they do not run in the default Forge suite until Aave mocks and wiring are more complete.
  - `DeploymentSmoke.t.sol` introduces a **4-phase deployment smoke test** that mirrors the documented deployment strategy (TimeProvider, oracles, QEURO, FeeCollector, Vault, QTI, YieldShift, stQEURO, UserPool, HedgerPool).  
    - The main smoke test has also been temporarily disabled by renaming `test_DeploymentSmoke_BasicFlows` to `xtest_DeploymentSmoke_BasicFlows_DisabledForNow`.
  - Other integration and edge-case suites continue to use `console.log`-based narrative flows plus assertions on live contract state.

-- **Security-focused tests**
  - Focused on specific risk classes:
    - `test/ReentrancyTests.t.sol` — reentrancy scenarios, presence of `ReentrancyGuard`, and structural checks around deposit/withdraw, staking, liquidation, oracle callbacks, and pause mechanisms.
      - A subset of tests deploy attacker-style mocks (e.g. `MaliciousToken`, `MaliciousQEURO`) and attempt concrete reentrancy on specific flows.
      - Several higher-level scenarios remain **documented but not fully simulated**, using `assertTrue(true, "...")` style placeholders (including some yield and withdrawal scenarios that were recently simplified back to narrative tests).
    - `test/EconomicAttackVectors.t.sol` — economic attack scenarios (e.g. oracle manipulation, under-collateralization, yield abuse).
    - `test/GovernanceAttackVectors.t.sol` — governance-related attacks (e.g. voting power abuse, threshold and quorum implications).
    - `test/RaceConditionTests.t.sol` — race conditions and concurrent action patterns.
    - `test/UpgradeTests.t.sol` — behaviour of upgrade paths and proxy-based upgrades.
    - `test/SecureUpgradeable.t.sol` and `test/TimelockUpgradeable.t.sol` — tests concerning upgradeability patterns and timelock behaviour.

-- **Fuzz / property-based tests**
  - `test/VaultMathFuzz.t.sol`
    - Uses fuzzing heavily with function signatures such as `testFuzz_MulDiv_BasicOperation(uint128 a, uint128 b, uint128 c)` and others.
    - Exercises:
      - `mulDiv`
      - `percentageOf`
      - `scaleDecimals`
      - min/max helpers and related relationships.
    - Uses `vm.assume` to constrain input domains and checks algebraic properties (identity, commutativity, round-trip scaling, etc.).
  - New fuzz/property suites for validation and staking logic:
    - `test/PriceValidationFuzz.t.sol` — properties around price deviation checks and bounds.
    - `test/YieldValidationFuzz.t.sol` — properties around yield shift, adjustment speed, target ratio, and slippage parameters.
    - `test/UserPoolStakingFuzz.t.sol` — properties around staking rewards calculation, stake/unstake validation, cooldowns, and penalties.

-- **Invariant-style tests**
  - `test/QuantillonInvariants.t.sol`
    - Declares a suite of `invariant_*` functions such as:
      - `invariant_totalSupplyConsistency`
      - `invariant_supplyCapRespect`
      - `invariant_collateralizationRatio`
      - `invariant_liquidationThresholds`
      - `invariant_yieldDistributionIntegrity`
      - `invariant_yieldShiftParameters`
      - `invariant_governancePowerConsistency`
      - `invariant_governanceParameters`
      - `invariant_emergencyStateConsistency`
      - `invariant_accessControlConsistency`
      - `invariant_mathematicalConsistency`
      - `invariant_crossContractIntegration`
      - `invariant_gasOptimization`
      - `invariant_liquidationStateConsistency`
      - `invariant_pauseStateConsistency`
    - Also provides a `test_allInvariants()` helper that calls these `invariant_*` functions in a single run.
    - Some invariants now deploy and wire a minimal subset of contracts using an internal harness; others still focus on structural or parameter relationships rather than full stateful sequences.

- **Oracle and integration edge-case tests**
  - `test/OracleEdgeCases.t.sol` covers oracle-specific edge cases (e.g. stale prices, extreme price movements, and deviation thresholds).
  - `test/StorkOracle.t.sol` and `test/ChainlinkOracle.t.sol` focus on specific oracle implementations and their interaction patterns.

---

## Code Areas Covered by Tests

This section maps major implementation areas under `src/` to the tests that exercise them, based on file names and imports in the test files.

### Core protocol contracts (`src/core/`)

- **`QEUROToken.sol`**
  - Covered by:
    - `test/QEUROToken.t.sol` (comprehensive suite around initialization, minting/burning, rate limits, compliance, emergency functions, admin functions, and edge/security scenarios).
    - `test/QEUROTokenBasic.t.sol` (basic or focused tests).
  - Tests use proxy deployment via `ERC1967Proxy` and validate role assignments, initialization constraints, and mint/burn permissions.

- **`QTIToken.sol`**
  - Covered by:
    - `test/QTIToken.t.sol` (governance token behaviour, locking, voting power, supply cap and governance parameters).

- **`stQEUROToken.sol`**
  - Covered by:
    - `test/stQEUROToken.t.sol` (yield-bearing wrapper behaviour, exchange rate mechanics, staking/unstaking flows in combination with other components).

- **`QuantillonVault.sol`**
  - Covered by:
    - `test/QuantillonVault.t.sol` (vault behaviour, collateralization, mint/redeem flows).
    - `test/IntegrationTests.t.sol`, `test/IntegrationEdgeCases.t.sol`, `test/HedgerVaultIntegration.t.sol`, `test/HedgerVaultRegression.t.sol` (system-level flows including interactions with UserPool, HedgerPool, AaveVault, and oracles).

- **`UserPool.sol`**
  - Covered by:
    - `test/UserPool.t.sol` (user deposit/withdrawal, staking, unstaking, yield distribution, and fees).
    - `test/IntegrationEdgeCases.t.sol`, `test/YieldStakingEdgeCases.t.sol`, and other integration suites where user deposit and staking flows are simulated.
    - `test/ReentrancyTests.t.sol`, `test/RaceConditionTests.t.sol`, `test/EconomicAttackVectors.t.sol` for security-related aspects.

- **`HedgerPool.sol`**
  - Covered by:
    - `test/HedgerPool.t.sol` (hedger operations, margin management, liquidation logic).
    - `test/HedgerVaultIntegration.t.sol` and `test/HedgerVaultRegression.t.sol` (interaction with vault and yield distribution).
    - `test/ReentrancyTests.t.sol`, `test/EconomicAttackVectors.t.sol` and `test/RaceConditionTests.t.sol` (attack and race-condition scenarios).

-- **`AaveVault.sol` (`src/core/vaults/AaveVault.sol`)**
  - Covered by:
    - `test/AaveVault.t.sol`
    - `test/AaveIntegration.t.sol`
  - Focus areas include integration with external Aave pool and emergency / risk-control mechanisms.

-- **`YieldShift.sol` (`src/core/yieldmanagement/YieldShift.sol`)**
  - Covered by:
    - `test/YieldShift.t.sol`
    - Additional coverage from `test/IntegrationTests.t.sol`, `test/YieldStakingEdgeCases.t.sol`, and yield-related edge case suites.

- **`FeeCollector.sol`**
  - Covered by:
    - `test/FeeCollector.t.sol` (fee collection and distribution behaviour).

- **Upgradeability and security utilities (`SecureUpgradeable.sol`, `TimelockUpgradeable.sol`)**
  - Covered by:
    - `test/SecureUpgradeable.t.sol`
    - `test/TimelockUpgradeable.t.sol`
    - `test/UpgradeTests.t.sol`

### Oracle layer (`src/oracle/` and related mocks)

- **`ChainlinkOracle.sol`**
  - Covered by `test/ChainlinkOracle.t.sol` and oracle-focused edge-case tests.

- **`StorkOracle.sol`**
  - Covered by `test/StorkOracle.t.sol`.

- **`OracleRouter.sol`**
  - Covered by `test/OracleRouter.t.sol` and `test/OracleEdgeCases.t.sol`.

- **Mocks (`MockChainlinkOracle.sol`, `MockStorkOracle.sol`)**
  - Used within various tests (especially integration and edge-case suites) to simulate price feed behaviour.

### Libraries (`src/libraries/`)

- **`VaultMath.sol`**
  - Covered by:
    - `test/VaultMath.t.sol` (deterministic, example-based unit tests).
    - `test/VaultMathFuzz.t.sol` (property-based fuzz tests for arithmetic and conversion helpers).

-- **Other libraries**
  - Several libraries such as:
    - `CommonValidationLibrary.sol`
    - `CommonErrorLibrary.sol`
    - `HedgerPoolLogicLibrary.sol`
    - `HedgerPoolValidationLibrary.sol`
    - `HedgerPoolErrorLibrary.sol`
    - `VaultErrorLibrary.sol`
    - `YieldShiftCalculationLibrary.sol`
    - `YieldShiftOptimizationLibrary.sol`
    - `UserPoolStakingLibrary.sol`
    - `YieldValidationLibrary.sol`
    - `TokenErrorLibrary.sol`
    - `GovernanceErrorLibrary.sol`
    - `AdminFunctionsLibrary.sol`
    - `TokenValidationLibrary.sol`
    - `QTITokenGovernanceLibrary.sol`
    - `PriceValidationLibrary.sol`
    - `TokenLibrary.sol`
    - `TimeProviderLibrary.sol`
    - `HedgerPoolOptimizationLibrary.sol`
    - `AccessControlLibrary.sol`
    - `TreasuryRecoveryLibrary.sol`
    - `FlashLoanProtectionLibrary.sol`
  - Are used indirectly via the core contracts they support.
  - Direct library-level coverage is now concentrated in:
    - `test/VaultMath.t.sol`
    - `test/VaultMathFuzz.t.sol`
    - `test/LibraryTests.t.sol`
    - `test/FlashLoanProtectionLibrary.t.sol`
    - `test/TreasuryRecoveryLibrary.t.sol`
    - `test/AccessControlLibrary.t.sol`
    - `test/PriceValidationLibrary.t.sol`
    - `test/YieldValidationLibrary.t.sol`
    - `test/TokenValidationLibrary.t.sol`
  - Additional coverage occurs from higher-level contract tests that rely on these libraries’ logic.

### Interfaces (`src/interfaces/`)

Interfaces such as:

- `IUserPool.sol`
- `IHedgerPool.sol`
- `IQuantillonVault.sol`
- `IChainlinkOracle.sol`
- `IStorkOracle.sol`
- `IOracle.sol`
- `ITimelockUpgradeable.sol`
- `IstQEURO.sol`
- `ISecureUpgradeable.sol`
- `IQTIToken.sol`
- `IYieldShift.sol`
- `IAaveVault.sol`

are used as type contracts and dependency surfaces in both contracts and tests.

They do not have dedicated interface-only test files, but their behaviour is exercised through the concrete contracts that implement them (e.g. `QEUROToken`, `QTIToken`, `UserPool`, `HedgerPool`, `QuantillonVault`, `AaveVault`, `YieldShift`, the oracle contracts, and upgradeability helpers).

---

## How Tests Are Executed Locally

- **Global test run**
  - From the `quantillon-protocol` directory:
    - `make test`  
      - Runs `forge test` with the default Foundry profile.

- **Coverage**
  - `make coverage`
    - Runs `FOUNDRY_PROFILE=coverage forge coverage --report lcov --ir-minimum`.
    - Cleans up `lcov.info` afterwards.

- **Selective / targeted Forge runs**
  - The top-level `README.md` documents examples such as:
    - `forge test --match-contract QuantillonVault`
    - `forge test --match-contract IntegrationTests`
    - `forge test --match-contract SecurityTests`
  - Additional documentation under `docs/` includes more examples, for instance:
    - `forge test`
    - `forge test --match-contract QEUROToken`

- **Security and auxiliary checks**
  - `make slither`, `make mythril`, `make validate-natspec`, `make gas-analysis`, `make analyze-warnings`, and `make analyze-contract-sizes` are available for extended validation, analysis, and documentation support.

---

## How Tests Are Executed in CI

- **GitHub Actions workflows in this repository (`/../.github/workflows/`)**
  - `forge-docs.yml`
    - Triggered on:
      - `push` to `main`
      - Manual `workflow_dispatch`
    - Steps relevant to this codebase:
      - Checks out the repository.
      - Installs Foundry.
      - Runs:
        - `cd quantillon-protocol`
        - `forge build --sizes`
      - Generates documentation using `forge doc` and post-processes HTML artifacts.
    - This workflow uses `forge build` but does **not** invoke `forge test`, `make test`, or `make ci`.
  - `Telegram Notifications.yml`
    - Sends a Telegram notification on pushes to `main` or `dev`.
    - Does not build or test the smart contracts.
  - `quantillon-protocol-tests.yml` (new)
    - Lives under `smart-contracts/.github/workflows/quantillon-protocol-tests.yml`.
    - **Triggers**:
      - `push` to `main` affecting `quantillon-protocol/**`.
      - `pull_request` targeting `main` affecting `quantillon-protocol/**`.
      - A scheduled nightly cron job for a heavier CI run.
    - **Jobs**:
      - `test` job:
        - Checks out the repository.
        - Installs Foundry.
        - Changes directory to `quantillon-protocol`.
        - Runs:
          - `make build`
          - `make test`
        - This ensures all Forge tests (including fuzz tests) pass on each push/PR to `main` for this subproject.
      - `ci-heavy` job (nightly):
        - Installs Foundry, Python, and Node.js.
        - Changes directory to `quantillon-protocol`.
        - Runs:
          - `make ci` (chaining `build`, `test`, `slither`, `validate-natspec`, `gas-analysis`, `analyze-warnings`, `analyze-contract-sizes`).

- **CI commands declared and wired**
  - The `Makefile` `ci` target described earlier is now **invoked by CI** for nightly runs via `quantillon-protocol-tests.yml`.
  - The lighter `make build` + `make test` path is enforced on every `main` push and PR.

---

## Existing Testing Conventions and Patterns

-- **Naming conventions**
  - Test files are named `<ContractOrDomainName>.t.sol`, e.g.:
    - `QEUROToken.t.sol`, `QTIToken.t.sol`, `UserPool.t.sol`, `HedgerPool.t.sol`, `QuantillonVault.t.sol`, `YieldShift.t.sol`.
    - Thematic suites: `IntegrationTests.t.sol`, `IntegrationEdgeCases.t.sol`, `EconomicAttackVectors.t.sol`, `GovernanceAttackVectors.t.sol`, `RaceConditionTests.t.sol`, `ReentrancyTests.t.sol`, `DeploymentSmoke.t.sol`.
    - Fuzz suites: `VaultMathFuzz.t.sol`, `PriceValidationFuzz.t.sol`, `YieldValidationFuzz.t.sol`, `UserPoolStakingFuzz.t.sol`.
    - Invariant-like suite: `QuantillonInvariants.t.sol`.
  - Tests that are temporarily disabled are prefixed with `xtest_...` (e.g. `xtest_CompleteProtocolWorkflow_DisabledForNow`, `xtest_DeploymentSmoke_BasicFlows_DisabledForNow`), which prevents Forge from picking them up as test functions while keeping the scenarios documented in code.

-- **Test structure**
  - Most tests follow the pattern:
    - `contract <Name> is Test { ... }`
  - Common patterns:
    - `setUp()` to deploy implementations, proxies (`ERC1967Proxy`), mocks, and wire roles.
    - Deployment helpers (e.g., `_deployEssentialContracts`, `_setupEssentialRoles` in `QuantillonInvariants`).
    - Use of constants for parameters and amounts.
    - Grouping by sections using large comment banners (`// =============================================================================`).
    - Frequent and detailed NatSpec-style comments on test functions and test contracts.

- **Assertion and logging style**
  - Assertions use `forge-std` helpers:
    - `assertEq`, `assertGt`, `assertGe`, `assertLe`, `assertTrue`, `assertFalse`.
  - Some tests use `console.log` extensively (especially narrative integration tests) to:
    - Print step-by-step descriptions.
    - Log intermediate values (e.g. amounts minted, redeemed, yields).

- **Proxy and upgradeability patterns in tests**
  - Tests for upgradeable contracts create implementations, then deploy `ERC1967Proxy` with initialization calldata.
  - Tests frequently validate:
    - Role assignments after initialization.
    - Correct behaviour of initializers (e.g. prohibition of re-initialization).
    - Governance and admin roles for upgrade and timelock-related contracts.

-- **Security test conventions**
  - Security-oriented tests often:
    - Use descriptive comments to enumerate the scenarios they conceptually cover.
    - Introduce mock attacker contracts (e.g. `ReentrancyAttacker`, `MaliciousToken`, `MaliciousQEURO`).
    - Use `vm.mockCall` or custom harness contracts to simulate external token behaviour or balances where necessary.
    - Group scenarios by attack class (reentrancy, economic attacks, governance attacks, race conditions).
  - Some scenarios are still recorded as **narrative placeholders** with `assertTrue(true, "...")` while others are fully executable attack simulations.

-- **Fuzz and invariant conventions**
  - Fuzz tests:
    - Use `testFuzz_*` naming, with typed parameters and `vm.assume` constraints.
    - Focus on deterministic math properties in `VaultMath` and validation/staking libraries (price and yield validation, staking reward calculations).
  - Invariant-style tests:
    - Use `invariant_*` naming and are grouped by domain (supply, collateralization, yield, governance, emergency, liquidation, access control, math, integration, gas).
    - Provide a single `test_allInvariants()` helper to run all invariant checks in one call.
    - Use Foundry’s invariant configuration from `foundry.toml`, but still rely largely on deterministic checks rather than a full action-based invariant harness.

