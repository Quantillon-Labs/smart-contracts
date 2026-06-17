# QTI Governance Activation Checklist

> Status: **QTI is dormant.** There is no mint path wired, so `QTIToken.totalSupply() == 0` and
> lock / vote / propose / execute are all inactive. This checklist captures everything that must be
> verified or changed **at the activation upgrade** — deliberately kept out of the live dormant
> proxy now (audit decision F-7) so all QTI changes land together and the storage-frozen proxy is
> touched only once, under review.

Reference: `SECURITY_AUDIT_FINDINGS.md` → F-7.

## 1. Roles & wiring (Safe actions at activation)
- [ ] Confirm the Safe grants `GOVERNANCE_ROLE` to the **QTI proxy itself** (`grantRole(GOVERNANCE_ROLE, <QTI proxy>)`). The `initialize` self-grant only runs for a fresh proxy; an already-initialized proxy needs this one-time grant so a passed proposal's self-call (`executeProposal` → `Address.functionCall(address(this), data)`) can run role-gated governance actions. (See `QTIToken.initialize`.)
- [ ] **Audit the blast radius of self-execution.** With `GOVERNANCE_ROLE` on itself, a passed proposal can call any `GOVERNANCE_ROLE`-gated function on QTIToken. Enumerate those functions and confirm none can brick governance or escalate beyond intent.
- [ ] Decide and document which **cross-contract** roles (if any) QTI receives on other protocol contracts (Vault, HedgerPool, etc.). Each such grant widens what governance can do; grant the minimum needed and document it.

## 2. Code changes to land in the activation upgrade
- [ ] **Add a proposal execution-expiry window.** Today `executeProposal` enforces only a lower bound (`currentTime >= proposalExecutionTime`, where `proposalExecutionTime = endTime + PROPOSAL_EXECUTION_DELAY`). There is **no upper bound**, so a passed proposal is executable forever. Add a `PROPOSAL_EXECUTION_GRACE` (e.g. 30 days) `constant` and, in `executeProposal`, revert when `currentTime > proposalExecutionTime + PROPOSAL_EXECUTION_GRACE`. This is storage-safe (a `constant`, no new storage slot) and ABI-additive (no signature change; optionally add a view getter).
- [ ] **Review merged-lock voting-power on top-up.** `lock()` / `batchLock()` recompute voting power over the full merged position at the merged remaining duration via `_effectiveLockDuration` (clamped to `[MIN_LOCK_TIME, MAX_LOCK_TIME]`). Before enabling any mint path, model a top-up that extends `unlockTime` and confirm it cannot inflate voting power beyond the intended ve-curve (e.g. tiny long lock + huge late top-up). Add fuzz/property tests.
- [ ] Re-run `make check-storage-layout` and `make check-abi` against the QTI baselines after the changes (expect: storage append-only / unchanged; ABI additive).

## 3. Mint path (do this last, deliberately)
- [ ] Confirm **no mint path** is wired until activation is explicitly intended. Once a mint path exists and the cap is minted, lock/vote/propose/execute become live — everything above must already be in place.
- [ ] After enabling, verify `proposalThreshold` / `quorumVotes` are sane relative to the freshly-minted supply.

## 4. Post-activation verification
- [ ] Create a no-op proposal end-to-end on a fork: lock → vote → wait `endTime` → wait `PROPOSAL_EXECUTION_DELAY` → `executeProposal` succeeds; and confirm it **reverts** before the delay and **after** the new grace window.
- [ ] Confirm `executeProposal` re-execution is blocked (`proposal.executed`) and canceled proposals cannot execute.
