# Dapp compatibility

Contract releases are accepted only after the frontend contract-drift check and dapp tests pass.

1. Build Solidity artifacts and run `scripts/deployment/copy-abis.sh` against a private dapp checkout.
2. Run `npm run check:contract-drift`, `npm run test:run`, and `npm run build` in `quantillon-dapp`.
3. Read `minCollateralizationRatioForMinting` from the deployed vault at runtime; source defaults and UI fallbacks are not authoritative.
4. Treat a reverted `harvestAndDistributeVaultYield` as retryable. The transaction is atomic and adapter yield remains available.
5. Verify generated ABI selectors for changed oracle, pricing, vault, and stQEURO contracts before deployment.

The dapp does not need to call the new oracle probe or yield gate directly. It must display the live mint floor and avoid assuming a failed harvest consumed yield.
