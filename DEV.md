# Development deployment

Dev also installs a local Safe 1.4.1 and Zodiac Roles 2.1.1 with its dedicated `hedge-ops-dev` role. Delegated margin addition and typed `removeMarginWithReference` are available for the local position; missing or stale bindings fail closed. The reset reinstalls these permissions. Dev synthetic capacity does not reproduce preprod’s persistent order/fill scenarios. See the [dev Dapp runbook](https://github.com/Quantillon-Labs/frontend-dapp/blob/dev/ops/dev/README.md).

Current signed interface and cross-environment status: [Signed Quote Migration](quantillon-protocol/docs/Signed-Quote-Migration.md). Both local environments use a 30-second quote lifetime and two-second empty-block mining alongside immediate transaction mining. Production remains legacy.

The `dev` branch is deployed only to the isolated local Anvil chain 31337 at
127.0.0.1:8549. Operational reset/deployment tooling is maintained in the dapp
repository's `ops/dev` directory. Run `/var/www/dev/redeploy-cycle.sh` as root;
never use a standalone Anvil reset beneath the running applications.

The deployment uses fresh private local test keys, mock USDC/reference feeds and a
mock staking adapter. `DEV_INITIAL_EUR_USD_PRICE` may override the mock bootstrap
price only on chain 31337; the coordinator obtains a fresh public EUR market
observation so normal deviation checks remain active when signed reference delivery begins.
Automatic resets deploy the selected checkout and never pull another branch.

Credentials, detailed deployment receipts and test wallet keys are private. The
local `.env` symlink and generated deployment files are not source changes.

## Signed quotes activated — 14 October 2026

`feat/signed-quotes-dev` is merged into `dev` in both contracts and dapp.
The served checkouts are `/var/www/dev/smart-contracts` and
`/var/www/dev/quantillon-dapp`. The coordinated reset deploys Vault 1.6.0,
UserPool 1.3.0, HedgerPool 1.6.0 and the signed pricing/reference modules.

The dapp reset now installs Multicall3 for browser reads, the real ChainlinkOracle
implementation over explicit local mock feeds, new signing keys and dev-only
quote API/signer configuration. It disables the legacy periodic publisher, checks
runtime provenance and signed readiness, and tests direct and UserPool settlement,
replay refusal, mint-and-stake and unstaking before reopening the instance.
The signed emergency haircut covers the inherited maximum impact (500 bps).

Dev capacity is synthetic; fixture feed refreshes retain the public observation's
original timestamp. These are local tests, not real exchange fills or independent
production reference data. See the dapp's `ops/dev/README.md` for reset, isolation
and monitoring details. Automatic resets use installed commits without pulling.

## Deployment records

`quantillon-protocol/deployments/8453/` contains historical Base records, not the
dev chain's deployment inventory. Actual chain-31337 addresses, fixtures, reset
status and deployment receipts are private under `/etc/quantillon/dev`.

## Test CI

`quantillon-protocol-tests.yml` runs for pushes to, and pull requests targeting,
`dev` or `feat/signed-quotes-dev` only. It retains the common contract tests and
upgrade gates; these do not reset the served dev instance. Manual dispatch runs
the full analysis suite on the selected branch. This branch has no cron:
GitHub schedules execute on the default branch, not on each environment branch.
