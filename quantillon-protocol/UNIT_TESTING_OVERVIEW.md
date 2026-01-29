## Scope

This document describes the **current state of testing** for the `quantillon-protocol` Solidity smart contracts as implemented in this repository.

It is **purely descriptive** and does **not** contain recommendations or future plans.

The content has been updated to reflect the test suite state **after** the latest round of improvements including: CI wiring, integration test refactors, new fuzz suites, dedicated library tests, deployment smoke tests, action-based invariant tests, and decimal scaling fixes.

---

## Testing Summary

| Metric | Value |
|--------|-------|
| Total test functions | 1,045 |
| Total tests passing | 1,169 (including fuzz runs) |
| Disabled tests (xtest_) | 0 |
| Test files | 41 |
| Fuzz test suites | 6 |
| Invariant functions | 15 |

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
    - assertion helpers (`assertEq`, `assertGt`, `assertTrue`, `assertGe`, `assertLe`, `assertFalse`, `assertApproxEqRel`, etc.)
    - logging via `console` in some tests

- **Security and analysis tooling**
  - **Slither** - Configured via `slither.config.json`, invoked via `make slither`
  - **Mythril** - Invoked via `make mythril`
  - **NatSpec validation** - `make validate-natspec` runs `scripts/validate-natspec.js`
  - **Gas analysis** - `make gas-analysis` and `make benchmark-gas`
  - **Contract size and warning analysis** - `make analyze-contract-sizes` and `make analyze-warnings`

- **Makefile integration**
  - `make test` wraps `forge test`
  - `make coverage` wraps `FOUNDRY_PROFILE=coverage forge coverage --report lcov --ir-minimum`
  - `make all` runs: `build`, `test`, `coverage`, `slither`, `docs`, `gas-analysis`, `analyze-warnings`, `analyze-contract-sizes`
  - `make ci` runs: `build`, `test`, `slither`, `validate-natspec`, `gas-analysis`, `analyze-warnings`, `analyze-contract-sizes`

---

## Test Types and Locations

All Solidity tests live under `test/` and use Foundry's Forge test runner.

### High-level categories

- **Unit tests**
  - Located primarily in:
    - `test/QEUROToken.t.sol`, `test/QEUROTokenBasic.t.sol`
    - `test/QTIToken.t.sol`
    - `test/stQEUROToken.t.sol`
    - `test/FeeCollector.t.sol`
    - `test/TimeProvider.t.sol`
    - `test/ChainlinkOracle.t.sol`, `test/StorkOracle.t.sol`, `test/OracleRouter.t.sol`
    - `test/VaultMath.t.sol`, `test/LibraryTests.t.sol`
    - `test/SecureUpgradeable.t.sol`, `test/TimelockUpgradeable.t.sol`
    - `test/AaveVault.t.sol`
  - Dedicated library test suites:
    - `test/FlashLoanProtectionLibrary.t.sol`
    - `test/TreasuryRecoveryLibrary.t.sol`
    - `test/AccessControlLibrary.t.sol`
    - `test/PriceValidationLibrary.t.sol`
    - `test/YieldValidationLibrary.t.sol`
    - `test/TokenValidationLibrary.t.sol`
  - These focus on single contracts or libraries with direct calls and assertions on state changes, events, error selectors, and boundary cases.

- **Integration / system workflow tests**
  - **Active and fully enabled** integration suites:
    - `test/IntegrationTests.t.sol` - Deploys real contracts via `ERC1967Proxy`, wires all dependencies, and executes complete protocol workflows including:
      - `test_CompleteProtocolWorkflow` - Full deposit → mint → stake → unstake → redeem flow
      - `test_BatchOperationsWorkflow` - Multiple users performing concurrent operations
    - `test/DeploymentSmoke.t.sol` - 4-phase deployment smoke tests:
      - `test_DeploymentSmoke_AllContractsDeployed` - Verifies all contracts deploy successfully
      - `test_DeploymentSmoke_ContractWiring` - Validates contract references and role assignments
      - `test_DeploymentSmoke_BasicMintRedeem` - End-to-end mint/redeem flow
      - `test_DeploymentSmoke_StakingRoundtrip` - Stake/unstake operations
      - `test_DeploymentSmoke_GovernanceSanity` - QTI governance parameter checks
      - `test_DeploymentSmoke_OraclePrices` - Oracle price retrieval verification
      - `test_DeploymentSmoke_EmergencyPause` - Pause/unpause functionality
      - `test_DeploymentSmoke_MultiUserMint` - Multiple user minting and supply tracking
  - Additional integration suites:
    - `test/IntegrationEdgeCases.t.sol`
    - `test/HedgerVaultIntegration.t.sol`, `test/HedgerVaultRegression.t.sol`
    - `test/AaveIntegration.t.sol`
    - `test/YieldStakingEdgeCases.t.sol`, `test/TimeBlockEdgeCases.t.sol`, `test/GasResourceEdgeCases.t.sol`

- **Security-focused tests**
  - `test/ReentrancyTests.t.sol` - Reentrancy scenarios with concrete attack simulations using `MaliciousToken` and `MaliciousQEURO` contracts
  - `test/EconomicAttackVectors.t.sol` - Economic attack scenarios (oracle manipulation, under-collateralization, yield abuse)
  - `test/GovernanceAttackVectors.t.sol` - Governance-related attacks (voting power abuse, threshold implications)
  - `test/RaceConditionTests.t.sol` - Race conditions and concurrent action patterns
  - `test/UpgradeTests.t.sol` - Upgrade paths and proxy-based upgrades

- **Fuzz / property-based tests**
  - `test/VaultMathFuzz.t.sol` - Fuzzing for `mulDiv`, `percentageOf`, `scaleDecimals`, min/max helpers
  - `test/PriceValidationFuzz.t.sol` - Price deviation checks and bounds
  - `test/YieldValidationFuzz.t.sol` - Yield shift, adjustment speed, target ratio, slippage parameters
  - `test/UserPoolStakingFuzz.t.sol` - Staking rewards, cooldowns, and penalties
  - Library fuzz tests in:
    - `test/FlashLoanProtectionLibrary.t.sol`
    - `test/PriceValidationLibrary.t.sol`

- **Invariant-style tests**
  - `test/QuantillonInvariants.t.sol` - Comprehensive invariant testing (wired for Foundry invariant mode via `StdInvariant`, `targetContract(handler)`, `targetSelector`):
    - **15 invariant functions** covering:
      - Supply consistency (`invariant_totalSupplyConsistency`, `invariant_supplyCapRespect`)
      - Collateralization (`invariant_collateralizationRatio`, `invariant_liquidationThresholds`)
      - Yield distribution (`invariant_yieldDistributionIntegrity`, `invariant_yieldShiftParameters`)
      - Governance (`invariant_governancePowerConsistency`, `invariant_governanceParameters`)
      - Emergency state (`invariant_emergencyStateConsistency`, `invariant_pauseStateConsistency`)
      - Access control (`invariant_accessControlConsistency`)
      - Math (`invariant_mathematicalConsistency`)
      - Integration (`invariant_crossContractIntegration`, `invariant_gasOptimization`)
      - Liquidation (`invariant_liquidationStateConsistency`)
    - **Action-based stateful tests**:
      - `test_ActionSequence_MintStakeUnstakeRedeem` - Full protocol action sequence
      - `test_EmergencyPauseIntegrity` - Emergency pause behaviour
    - **Fuzz tests**:
      - `testFuzz_MintMaintainsSupplyConsistency` - Randomized mint amounts
      - `testFuzz_StakeUnstakeRoundtrip` - Stake/unstake with randomized fractions
    - **InvariantActionHandler contract** - Exposes `actionMint`, `actionRedeem`, `actionStake`, `actionUnstake` for fuzzed sequences

---

## Code Areas Covered by Tests

### Core protocol contracts (`src/core/`)

| Contract | Primary Test Files |
|----------|-------------------|
| `QEUROToken.sol` | `QEUROToken.t.sol`, `QEUROTokenBasic.t.sol` |
| `QTIToken.sol` | `QTIToken.t.sol` |
| `stQEUROToken.sol` | `stQEUROToken.t.sol` |
| `QuantillonVault.sol` | `QuantillonVault.t.sol`, `IntegrationTests.t.sol`, `HedgerVaultIntegration.t.sol` |
| `UserPool.sol` | `UserPool.t.sol`, `IntegrationEdgeCases.t.sol`, `YieldStakingEdgeCases.t.sol` |
| `HedgerPool.sol` | `HedgerPool.t.sol`, `HedgerVaultIntegration.t.sol`, `HedgerVaultRegression.t.sol` |
| `AaveVault.sol` | `AaveVault.t.sol`, `AaveIntegration.t.sol` |
| `YieldShift.sol` | `YieldShift.t.sol`, `IntegrationTests.t.sol` |
| `FeeCollector.sol` | `FeeCollector.t.sol` |

### Oracle layer (`src/oracle/`)

| Contract | Primary Test Files |
|----------|-------------------|
| `ChainlinkOracle.sol` | `ChainlinkOracle.t.sol`, `OracleEdgeCases.t.sol` |
| `StorkOracle.sol` | `StorkOracle.t.sol` |
| `OracleRouter.sol` | `OracleRouter.t.sol`, `OracleEdgeCases.t.sol` |

### Libraries (`src/libraries/`)

| Library | Primary Test Files |
|---------|-------------------|
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

- **Global test run**
  ```bash
  make test  # or: forge test
  ```

- **Coverage**
  ```bash
  make coverage
  ```

- **Selective / targeted runs**
  ```bash
  forge test --match-contract QuantillonVault
  forge test --match-test testFuzz_
  forge test --match-contract IntegrationTests -vvv
  ```

- **Security and auxiliary checks**
  ```bash
  make slither
  make mythril
  make validate-natspec
  make gas-analysis
  ```

---

## How Tests Are Executed in CI

- **GitHub Actions workflows**
  - `quantillon-protocol-tests.yml`:
    - **Triggers**: Push to `main`, PRs targeting `main`, nightly cron
    - **test job**: Runs `make build` + `make test` on every push/PR
    - **ci-heavy job** (nightly): Runs full `make ci` including Slither, NatSpec validation, gas analysis
  - `forge-docs.yml`: Documentation generation only (no test execution)

- **CI commands**
  - Light path (every push/PR): `make build && make test`
  - Heavy path (nightly): `make ci`

---

## Existing Testing Conventions and Patterns

- **Naming conventions**
  - Test files: `<ContractOrDomainName>.t.sol`
  - Test functions: `test_<Description>`, `testFuzz_<Description>`, `invariant_<Description>`
  - All tests use standard `test_` prefix (no disabled `xtest_` functions remain)

- **Test structure**
  - `contract <Name> is Test { ... }`
  - `setUp()` deploys implementations, proxies, mocks, and wires roles
  - Deployment helpers: `_deployEssentialContracts`, `_setupEssentialRoles`, `deployFullProtocol`
  - Section groupings with comment banners

- **Assertion and logging style**
  - Assertions: `assertEq`, `assertGt`, `assertGe`, `assertLe`, `assertTrue`, `assertFalse`, `assertApproxEqRel`
  - Logging: `console.log` for step-by-step tracing in integration tests

- **Proxy and upgradeability patterns**
  - Tests deploy `ERC1967Proxy` with initialization calldata
  - Validate role assignments, initializer restrictions, upgrade paths

- **Security test conventions**
  - Mock attacker contracts (`ReentrancyAttacker`, `MaliciousToken`, `MaliciousQEURO`)
  - `vm.mockCall` for external token simulation
  - Scenarios grouped by attack class

- **Fuzz and invariant conventions**
  - Fuzz tests use `testFuzz_*` with typed parameters and `vm.assume` constraints
  - Invariant tests use `invariant_*` naming
  - `test_allInvariants()` runs all invariant checks in sequence
  - `InvariantActionHandler` provides action-based fuzz testing interface
