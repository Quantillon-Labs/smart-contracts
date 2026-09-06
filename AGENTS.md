## Documentation site

The docs site (https://smartcontracts.quantillon.money) is an mdBook built via `make docs` (`forge doc --build`). Most of `docs/` is generated — do not hand-edit generated files; they are overwritten on every build.

- **Generated (do not edit):** `docs/book.toml`, `docs/src/README.md` (the site homepage — `forge doc` copies `quantillon-protocol/README.md`, not the repo-root README), `docs/src/SUMMARY.md`, and all of `docs/src/src/**` (contract reference from NatSpec). The `docs/src/*.md` guide copies are stale build artifacts.
- **Source (edit these):** `quantillon-protocol/README.md` (becomes the site homepage — link guides with absolute `https://smartcontracts.quantillon.money/<Name>.html` URLs, not relative `./docs/X.md` which 404 on the published book), the repo-root `README.md` (GitHub landing page only), `docs/SUMMARY.md` (guide nav), `docs/README.md`, and the top-level guides `docs/*.md` (e.g. `API-Reference.md`, `Deployment.md`, `External-Vault-Onboarding-Runbook.md`).
- **Sync:** `docs/API-Reference.md` addresses must match `deployments/8453/addresses.json`.

See `CLAUDE.md` → "Documentation Site" for full details.

## Contract versioning (traceability)

Every core contract implements `IVersioned.version()` (a `pure` semver getter) and linked libraries expose `version()`; inlined libraries carry a `VERSION` constant.

**Rule: ANY change to a deployed contract or library — correction, bug fix, update, or upgrade — MUST be traced through a semver bump of its `version()`** (PATCH = bugfix/internal, MINOR = new function/behavior). This is enforced in CI by `make check-version-bump` (it fails if a contract's deployed bytecode changes without a version bump). Deployed versions are recorded in `deployments/{chainId}/versions.json` by the `UpgradeBase` upgrade scripts; `make check-deployed-versions` lists which contracts are out of date vs source. See `CLAUDE.md` → "Architecture Patterns" #8 and `docs/Deployment.md`.
