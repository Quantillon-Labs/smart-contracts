# Dapp compatibility

> Signed quotes are active on Base since 17 October 2026. See [Signed Quotes in Production](Signed-Quote-Migration.md) for verified bindings, transaction wrappers and emergency-mode limits.

Contract releases are accepted only after the frontend contract-drift check and dapp tests pass.

1. Build Solidity artifacts and run `scripts/deployment/copy-abis.sh` against a private dapp checkout.
2. Run `npm run check:contract-drift`, `npm run test:run`, and `npm run build` in `quantillon-dapp`.
3. Read `minCollateralizationRatioForMinting` from the deployed vault at runtime; source defaults and UI fallbacks are not authoritative.
4. Treat a reverted `harvestAndDistributeVaultYield` as retryable. The transaction is atomic and adapter yield remains available.
5. Verify generated ABI selectors for changed oracle, pricing, vault, and stQEURO contracts before deployment.

Normal conversions must use the signed wrapper on the authorized Vault or UserPool target. Complete token approval before requesting an executable quote. Validate chain, wallet, module, target, exact inner calldata, amounts and expiry; require user review again if output changes. Bare legacy mint/redeem calls are rejected in signed mode.

Test approval followed by issuance, 45-second expiry, replay rejection, wallet/chain changes, capacity exhaustion, stale reference, pause, and ambiguous transaction recovery. Simulate the exact wrapper call. Dashboard and keeper valuation must obtain a fresh signed reference in read-only simulation rather than equating an idle cache with unavailable delivery. A failed harvest remains atomic. The current emergency budget is zero; no automatic reference-only fallback should be offered.

Admin compatibility is part of release acceptance. Simulate each generated action
from the Safe against current state. If the target's admin is the configured
controller, simulate from the controller and generate matching schedule and execute
transactions using its live minimum delay and a unique salt. Ordinary Safe actions
remain direct. Do not turn a failed business-logic check into an unchecked proposal.
Test both pre-handover and post-handover authority, rejected calls, role grants,
and the retained immediate pause/resume controls. Keep generated transaction files
local; they are never public application assets.
