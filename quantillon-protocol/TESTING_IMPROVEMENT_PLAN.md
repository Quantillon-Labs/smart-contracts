## Scope and Purpose

This document identifies **remaining gaps and risks** in the test suite for the `quantillon-protocol` smart contracts after the latest round of improvements.

This is an **iterative post-improvement review** that focuses only on what still needs work. Previously addressed items have been removed.

---

## Implementation Status Summary

The following priorities have been **fully addressed**:

| Priority | Status | Summary |
|----------|--------|---------|
| P1 | **Complete** | Integration tests (`IntegrationTests.t.sol`) and deployment smoke tests (`DeploymentSmoke.t.sol`) are fully enabled and running in CI |
| P2 | **Partial** | Reentrancy tests have concrete attack simulations, but other security tests retain placeholder assertions |
| P3 | **Complete** | `QuantillonInvariants.t.sol` now has action-based stateful tests and fuzz tests exercising mint/redeem/stake/unstake |
| P5 | **Complete** | Library test files have dedicated fuzz and edge case coverage |
| P6 | **Complete** | Deployment smoke tests verify 4-phase deployment, wiring, roles, and basic flows |

---

## Remaining Gaps

### 1. Placeholder Assertions in Security Tests

Several security-focused test files contain `assertTrue(true, "...")` placeholder assertions that document scenarios without fully executing them.

**Current counts:**

| File | Placeholder Count |
|------|-------------------|
| `EconomicAttackVectors.t.sol` | 26 |
| `RaceConditionTests.t.sol` | 22 |
| `QuantillonInvariants.t.sol` | 6 |
| `ReentrancyTests.t.sol` | 2 |
| `GovernanceAttackVectors.t.sol` | 1 |

**Risk**: The test names suggest comprehensive security coverage, but many scenarios only validate that "protection exists" conceptually without executing the attack path.

---

### 2. Invariant Harness Not Using Foundry's Full Invariant Runner

- `QuantillonInvariants.t.sol` defines 15 `invariant_*` functions and provides an `InvariantActionHandler` contract
- The handler exposes `actionMint`, `actionRedeem`, `actionStake`, `actionUnstake` functions
- However, **the harness is not wired as a Foundry invariant target** - tests run as standard unit tests rather than using Foundry's invariant fuzzing mode with randomized action sequences

**Risk**: Invariants are not stress-tested under many randomized sequences of state transitions.

---

### 3. Flash Loan + Oracle Manipulation Combined Attack Scenarios

- `FlashLoanProtectionLibrary.t.sol` covers isolated flash loan detection
- Oracle edge case tests exist in `OracleEdgeCases.t.sol`
- **Missing**: Multi-step protocol-level tests that combine flash loans with oracle manipulation and governance timing attacks

**Risk**: Sophisticated attack vectors that chain multiple vulnerabilities are not explicitly tested.

---

### 4. Liquidation Path Coverage

- Liquidation thresholds and parameters are validated
- `HedgerPool.t.sol` tests hedger operations
- **Missing**: End-to-end liquidation scenarios where:
  - Positions become under-collateralized due to price movements
  - Liquidator executes liquidation
  - Protocol state (balances, supply, collateral) is verified post-liquidation

**Risk**: Liquidation edge cases (partial liquidations, liquidation during high volatility, MEV-style front-running) are not fully exercised.

---

## Prioritized Recommendations

### Priority 1 — Convert Placeholder Security Tests to Executable Assertions

**Goal**: Ensure security test names accurately reflect what is being verified.

**Actions**:
- For `EconomicAttackVectors.t.sol` (26 placeholders):
  - Identify the 5-10 highest-risk scenarios
  - Convert to executable tests with:
    - Real contract deployments
    - State mutations that trigger the attack vector
    - Assertions that would fail if protection were removed
  - Move remaining scenarios to a separate documentation file or convert to `skip` tests with clear rationale

- For `RaceConditionTests.t.sol` (22 placeholders):
  - Implement at least 3-5 concrete race condition simulations using `vm.warp`, `vm.roll`, and interleaved transactions
  - Focus on: deposit/withdrawal timing, oracle update timing, yield distribution timing

- For remaining files:
  - Either implement concrete tests or document why automation is not feasible

**Example transformation**:
```solidity
// Before (placeholder)
function test_OracleManipulation_Protected() public {
    assertTrue(true, "Oracle manipulation protection exists");
}

// After (executable)
function test_OracleManipulation_Protected() public {
    // Setup: User has position, oracle at normal price
    // Action: Manipulate oracle to extreme value
    // Assert: Protocol rejects operations or triggers circuit breaker
    vm.prank(admin);
    oracle.setPrices(100e18, 1e18); // 100x price spike

    vm.startPrank(user);
    vm.expectRevert(); // Should revert due to price deviation check
    vault.mintQEURO(1000e6, 0);
    vm.stopPrank();
}
```

---

### Priority 2 — Wire Invariant Handler for Foundry Invariant Mode

**Goal**: Leverage Foundry's invariant testing to exercise protocol under randomized action sequences.

**Actions**:
- In `QuantillonInvariants.t.sol`:
  - Add `targetContract(address(handler))` in `setUp()`
  - Expose handler functions as external targets
  - Ensure invariant functions run after each fuzzed action sequence

- Verify via:
  ```bash
  forge test --match-contract QuantillonInvariants --mt invariant_
  ```

**Expected outcome**: Foundry will call random combinations of `actionMint`, `actionRedeem`, `actionStake`, `actionUnstake` and verify invariants hold after each sequence.

---

### Priority 3 — Add Combined Attack Vector Tests

**Goal**: Test multi-step attack scenarios that chain vulnerabilities.

**Actions**:
- Create a new test file `test/CombinedAttackVectors.t.sol` with scenarios:
  1. **Flash loan + oracle manipulation**: Borrow large amount → manipulate oracle → exploit → repay
  2. **Governance timing attack**: Propose change → exploit window before execution → front-run
  3. **Yield extraction during volatility**: Stake → oracle drops → claim yield → unstake before rebalance

**Example scenario**:
```solidity
function test_FlashLoanOracleManipulationBlocked() public {
    // 1. Attacker takes flash loan of 10M USDC
    // 2. Attacker attempts to manipulate oracle
    // 3. Attacker attempts to mint QEURO at manipulated price
    // 4. Assert: Either oracle rejects, mint reverts, or flash loan check triggers
}
```

---

### Priority 4 — Add End-to-End Liquidation Tests

**Goal**: Verify liquidation mechanics work correctly under realistic conditions.

**Actions**:
- In `HedgerPool.t.sol` or new `test/LiquidationScenarios.t.sol`:
  - Test: Position becomes under-collateralized → liquidation succeeds → balances correct
  - Test: Partial liquidation leaves position healthy
  - Test: Multiple liquidations in same block
  - Test: Liquidation during paused state (should revert)
  - Test: Liquidation reward/penalty calculations

---

## Summary

The test suite is now in a strong state with:
- 1,169 tests passing
- Full integration and deployment smoke tests enabled
- Action-based invariant tests with fuzz coverage

**Remaining work focuses on**:
1. Converting ~57 placeholder assertions to executable security tests
2. Wiring the invariant handler for Foundry's invariant mode
3. Adding combined attack vector scenarios
4. Expanding liquidation path coverage

These improvements would further strengthen confidence in protocol security and correctness.
