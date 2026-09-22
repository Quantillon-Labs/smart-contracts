# Dapp compatibility

Contract releases are accepted only after the frontend contract-drift check and dapp tests pass.

1. Build Solidity artifacts and run `scripts/deployment/copy-abis.sh` against a private dapp checkout.
2. Run `npm run check:contract-drift`, `npm run test:run`, and `npm run build` in `quantillon-dapp`.
3. Read `minCollateralizationRatioForMinting` from the deployed vault at runtime; source defaults and UI fallbacks are not authoritative.
4. Treat a reverted `harvestAndDistributeVaultYield` as retryable. The transaction is atomic and adapter yield remains available.
5. Verify generated ABI selectors for changed oracle, pricing, vault, and stQEURO contracts before deployment.

The dapp does not need to call the new oracle probe or yield gate directly. It must display the live mint floor and avoid assuming a failed harvest consumed yield.

Admin compatibility is part of release acceptance. Simulate each generated action
from the Safe against current state. If the target's admin is the configured
controller, simulate from the controller and generate matching schedule and execute
transactions using its live minimum delay and a unique salt. Ordinary Safe actions
remain direct. Do not turn a failed business-logic check into an unchecked proposal.
Test both pre-handover and post-handover authority, rejected calls, role grants,
and the retained immediate pause/resume controls. Keep generated transaction files
local; they are never public application assets.
