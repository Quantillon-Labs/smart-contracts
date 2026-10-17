# Production deployment

The environment branch is `main`; this signed-quotes candidate is
`feat/signed-quotes-migration`. Production runs on Base, chain **8453**.
This candidate is source for a governed upgrade, not an activation receipt.

## Candidate and installed state

The shared candidate implements Vault 1.6.0, UserPool 1.3.0, HedgerPool 1.6.0 and
ReferenceSettlementLibrary 1.1.0, plus signed execution and reference modules.
The candidate checkout is `/var/www/quantillon-signed-quotes/smart-contracts`;
the paired dapp is `/var/www/quantillon-signed-quotes/quantillon-dapp`.
The installed production checkouts live under `/var/www/prod`.

Follow `quantillon-protocol/docs/Signed-Quote-Migration.md` and the paired dapp's
`docs/migrations/signed-quotes-production-preparation.md` for the governed cutover.
Inactive module deployment does not upgrade proxies or activate signed settlement.
The Safe retains operational roles; the timelock executes upgrades after its
43,200-second delay. Preserve pending liabilities, hedger accounting and reconciled
settlements. Do not use dev resets, fork impersonation, mock keys or fixture state
on Base. Keep transaction staging and deployment credentials private.

## Deployment records

`quantillon-protocol/deployments/8453/` records confirmed Base deployments.
Compare recorded addresses and versions with observed chain state before an
upgrade. Update records only from confirmed deployment and activation receipts;
source version changes do not establish live deployment.

## Test CI

`quantillon-protocol-tests.yml` runs for pushes to, and pull requests targeting,
`main` or `feat/signed-quotes-migration` only. It retains the common tests and
upgrade gates. Manual dispatch runs the full analysis suite on the selected
branch. The 03:00 UTC schedule runs the default branch; it does not run dev or
preprod or deploy any environment.
