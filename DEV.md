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
