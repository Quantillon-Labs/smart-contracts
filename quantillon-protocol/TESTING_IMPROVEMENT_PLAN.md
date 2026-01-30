# Testing Improvement Plan — Quantillon Protocol

## Scope and Purpose

This document is an **iterative post-improvement review**. It records only **remaining gaps**, **newly identified risks**, and **updated priorities**. Issues that have been fully addressed are not restated.

---

## Completed This Cycle

Placeholder assertions were replaced with executable tests or explicit `vm.skip(true, "…")` and rationale across EconomicAttackVectors, RaceConditionTests, QuantillonVault, ReentrancyTests, QuantillonInvariants, VaultMathFuzz, QTIToken, ChainlinkOracle, AaveVault, UserPool, YieldShift, and LiquidationScenarios. Combined attack and liquidation scenarios were expanded (e.g. redeem with extreme price, partial redemption, same-block redemptions, CR boundary). CI workflow (`.github/workflows/tests.yml`), README testing conventions, and Foundry config alignment ([lint], [doc], remappings) are in place. There are **no remaining bare `assertTrue(true, …)` placeholders** in the suite.

---

## Remaining Gaps

### 1. Explicit skips (~59 tests)

Roughly **57 tests** across 11 files use `vm.skip(true, "…")` with a short rationale. These document intent but do **not** run the scenario (e.g. full protocol deployment or a dedicated harness is not available). Files include: EconomicAttackVectors (21), RaceConditionTests (15), ReentrancyTests (2), QuantillonInvariants (1), LiquidationScenarios (1), VaultMathFuzz (3), QTIToken (3), ChainlinkOracle (2), AaveVault (4), UserPool (2), YieldShift (3). *Recent conversion: 2 more race tests made executable — ProposalCreation (multiple proposals coexist and execute), TimestampManipulation (timelock 48h enforced with vm.warp).*

**Gap:** Coverage for those code paths relies on integration tests, other executable tests, or manual review. Converting high-value skipped scenarios to executable tests (when harnesses or full deployment exist) would strengthen regression coverage.

### 2. Optional depth

- **Combined / liquidation:** Current combined-attack and liquidation tests (including partial, same-block, CR boundary) are sufficient for main flows. Further variants (e.g. governance timing + front-run, liquidation fee consistency) are optional.
- **Race / economic:** Many race and economic tests are skipped. Concrete tests using `vm.warp`, `vm.roll`, and interleaved calls would add depth but require stable harnesses or full protocol.

---

## Newly Identified Risks

1. **Skipped tests do not run the scenario.** A regression in a code path that is only referenced by a skipped test will not be caught by that test. Risk is mitigated by integration tests, other executable security tests, and the fact that skips document the missing setup (full protocol or harness).
2. **Invariant mutability.** `test_allInvariants()` was changed from `view` to non-view because `invariant_gasOptimization()` uses `vm.skip`, which modifies state. Future invariant helpers that use `vm` cheatcodes must be non-view and callers (e.g. `test_allInvariants`) must not be declared `view`.

---

## Updated Priorities

| Priority | Focus | Action |
|----------|--------|--------|
| **Optional** | Skipped scenarios | Convert high-value skipped tests to executable when harnesses or full protocol deployment are available (e.g. EconomicAttackVectors, RaceConditionTests). Prefer one clear assertion per scenario; avoid new placeholders. |
| **Ongoing** | Conventions and CI | Keep naming and structure aligned with `UNIT_TESTING_OVERVIEW.md`; run `make test` before push and `make ci` for full checks; ensure CI runs `make build && make test` on push/PR (see `.github/workflows/tests.yml`). |

---

## Skip policy

- **Use `vm.skip(true, "…")` when:** The scenario requires full protocol deployment, a dedicated harness not present in the repo, or heavy mocks (e.g. multi-contract integration with oracles/vaults we do not mock in that file). Prefer a short, precise rationale (e.g. "Requires full protocol; see IntegrationTests").
- **Prefer converting to an executable test when:** Only time/block manipulation (`vm.warp`, `vm.roll`) and existing deployed contracts in that file are needed, or when a small, stable harness can be added without over-engineering. One clear assertion per scenario; no new placeholders.

---

## Maturity assessment

The suite has reached a **satisfactory level of maturity** for the 80/20 rule: no bare placeholders, executable integration and security tests where setup exists, explicit skips with rationale elsewhere, and CI and conventions in place. Optional next steps: (1) convert further high-value skips to executable when harnesses or full deployment become available; (2) keep conventions and CI aligned with `UNIT_TESTING_OVERVIEW.md` and `.github/workflows/tests.yml`.

---

## Summary

The suite is in a **strong state**: no bare placeholders, executable integration and security tests where setup exists, explicit skips with rationale elsewhere, and CI and conventions in place. Remaining work is **optional** (convert high-value skips to executable when feasible) and **ongoing** (conventions and CI).
