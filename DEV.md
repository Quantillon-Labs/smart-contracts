# Development deployment

The `dev` branch is deployed only to the isolated local Anvil chain 31337 at
127.0.0.1:8549. Operational reset/deployment tooling is maintained in the dapp
repository's `ops/dev` directory. Run `/var/www/dev/redeploy-cycle.sh` as root;
never use a standalone Anvil reset beneath the running applications.

The deployment uses fresh private local test keys, mock USDC/reference feeds and a
mock staking adapter. `DEV_INITIAL_EUR_USD_PRICE` may override the mock bootstrap
price only on chain 31337; the coordinator obtains a fresh public EUR market
observation so normal deviation checks remain active when publication begins.
Automatic resets deploy the selected checkout and never pull another branch.

Credentials, detailed deployment receipts and test wallet keys are private. The
local `.env` symlink and generated deployment files are not source changes.

## Signed-quotes candidate — 14 October 2026

`feat/signed-quotes-dev` is the dedicated candidate in both `smart-contracts`
and `frontend-dapp`. The contracts candidate starts from dev `f3765f67` and
merges the shared signed-quotes candidate `435062e9`. Its contract source,
interfaces and tests match that candidate; it preserves dev's mock-price
bootstrap, Anvil endpoint, private configuration symlink and recorded deployment
inventory. Contract versions remain those of the shared candidate.

The paired worktrees are `/var/www/quantillon-signed-quotes/dev-contracts` and
`/var/www/quantillon-signed-quotes/dev-dapp`. Pushes to the candidate branches run
their test workflows. Creating these branches does not install the candidate in
the running dev environment. Activation still requires the coordinated dev
deployment/reset procedure and environment-specific signed-quote bindings.
