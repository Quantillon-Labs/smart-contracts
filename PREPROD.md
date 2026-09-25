Preprod uses branch `preprod` and a local Anvil fork of Base mainnet, chain **31338**, RPC `http://127.0.0.1:8550`.

This checkout starts from production commit `9fa4f05aba88198cd9338fcddd3ec9cd7d35102c`. The fork retains deployed proxies, balances and storage. Source HEAD does not imply every contract implementation is already deployed: compare the private baseline and observed versions before rehearsing an upgrade.

Run a rehearsal from `quantillon-protocol` with:

```bash
bash scripts/preprod.sh scripts/YourUpgrade.s.sol:YourUpgrade --broadcast
```

The wrapper refuses RPC/chain overrides and loads only the dedicated preprod test signer. It does not grant that signer governance authority: use local-only Safe/timelock impersonation when the scenario requires privileged calls, preserving the real upgrade and delay sequence. Never submit fork proposals to a mainnet Safe transaction service. Version bumps and existing storage/ABI/size checks still apply to candidate contract changes.

The live environment record, fork block/hash, observed versions and fixture changes are private under `/etc/quantillon/preprod`. The paired dapp checkout and complete operations runbook are at `/var/www/preprod/quantillon-dapp/ops/preprod/README.md`.

Fork refreshes must use the dapp's coordinated `ops/preprod/reset.py`; an isolated `anvil_reset` leaves index cursors and writer journals inconsistent. Mainnet history before the fork is not imported into the preprod database. External hedging and bridges are simulated or disabled.

Promote reviewed changes from dev to preprod, validate the paired dapp/contract commits, then promote the validated changes to main. Keep deployment secrets, signed transactions, audit artifacts and fork state outside Git.
