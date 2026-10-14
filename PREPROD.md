# Preproduction deployment

The environment branch is `preprod`; `feat/signed-quotes-preprod` was merged
and activated on 14 October 2026. Preprod uses an isolated Anvil fork of Base on
chain **31338**, RPC `http://127.0.0.1:8550`. External venue execution and bridges
are simulated or disabled. Fork keys and fixtures must never be used on Base.

## Installed signed execution

The shared signed-quotes implementation comes from `435062e9`: Vault 1.6.0,
UserPool 1.3.0, HedgerPool 1.6.0 and ReferenceSettlementLibrary 1.1.0, with the
signed execution and reference modules. This checkout retains preprod's guarded
execution wrapper and RPC alias. Source versions and branch names do not prove
which implementations are installed in the running fork.

The installed checkouts are `/var/www/preprod/smart-contracts` and
`/var/www/preprod/quantillon-dapp`. A complete coordinated reset, signed
settlement/replay tests and simulated hedge recovery were verified on 14 October.
Operational reset and simulation instructions are in
the paired dapp's `ops/preprod/README.md` and
`docs/migrations/preprod-isolated-simulation.md`.

## Execution and reset

From this checkout's `quantillon-protocol` directory, use:

```bash
bash scripts/preprod.sh scripts/YourUpgrade.s.sol:YourUpgrade --broadcast
```

The wrapper checks chain 31338, fixes the loopback RPC, rejects RPC/chain
overrides, and loads `/etc/quantillon/preprod/contracts.env`. It does not grant
the test signer governance authority. Use the local-only Safe/timelock rehearsal
procedure when privileged calls are needed, preserving upgrade order and delays.
Do not use production deployment shortcuts or the tracked `.env.base` default
for preprod. Never submit fork proposals to a mainnet Safe transaction service.

Fork refreshes must use the installed dapp's coordinated `ops/preprod/reset.py`;
an isolated `anvil_reset` leaves database cursors and writer journals inconsistent.
Install the paired candidate deliberately before a reset; a reset is not a branch
promotion. Keep signing configuration, fork state and transaction staging private.

## Deployment records

`quantillon-protocol/deployments/8453/` records Base mainnet, not chain 31338.
Its production-derived entries are not evidence of a preprod upgrade. The private
environment records under `/etc/quantillon/preprod` and observed proxy versions
determine installed fork state. Preserve existing positions, accounting, signers
and capacity counters during a scoped upgrade; do not replace them from a source
manifest.

## Test CI

`quantillon-protocol-tests.yml` runs for pushes to, and pull requests targeting,
`preprod` or `feat/signed-quotes-preprod` only. It retains the common contract
tests and upgrade gates; these do not deploy to the served fork. Manual dispatch
runs the full analysis suite on the selected branch. This branch has no cron:
GitHub schedules execute on the default branch, not on each environment branch.
