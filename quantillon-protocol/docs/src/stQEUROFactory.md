# Technical Upgrade: stQEURO Multi-Vault with `stQEUROFactory`

## Context

The protocol originally used a single `stQEURO` staking token for a single staking vault.  
The architecture has been extended to support multiple vaults (identified by `vaultId`), with one dedicated token per vault:

- `vaultId = 1` -> `stQEURO<VAULT_NAME_1>`
- `vaultId = 2` -> `stQEURO<VAULT_NAME_2>`
- ...

These tokens are not fungible with each other (distinct ERC20 addresses, distinct metadata, and distinct yield accounting).

---

## Upgrade objective

1. Replace the "single stQEURO token" model with an upgradeable factory.
2. Keep `stQEUROToken` as the vault-level staking token implementation.
3. Route yield (`YieldShift`) through `vaultId`.
4. Enforce strict vault registration through an on-chain self-call.
5. Update deployment flows, interfaces, and tests.

---

## Updated components

## 1) New contract: `stQEUROFactory`

This contract introduces an orchestration layer to deploy and register one `stQEURO` token per vault dynamically.

### Responsibilities

- Deploy one `ERC1967Proxy` per vault pointing to the `stQEUROToken` implementation.
- Keep resolution indexes `vaultId <-> vault <-> token`.
- Store vault metadata (`vaultName`).
- Provide resolution getters for `YieldShift`, scripts, and indexers.

### Upgradeability and access control

- Pattern: `Initializable + AccessControlUpgradeable + SecureUpgradeable` (UUPS via `SecureUpgradeable`).
- Roles:
  - `GOVERNANCE_ROLE`: factory reconfiguration (implementation, yieldShift, treasury, etc.)
  - `VAULT_FACTORY_ROLE`: permission to register vaults

### Main storage

- `stQEUROByVaultId[vaultId] -> token`
- `stQEUROByVault[vault] -> token`
- `vaultById[vaultId] -> vault`
- `vaultIdByStQEURO[token] -> vaultId`
- `_vaultNamesById[vaultId] -> vaultName`
- `_vaultNameHashUsed[keccak256(vaultName)] -> bool`

### Strict registration: `registerVault(uint256 vaultId, string vaultName)`

Applied constraints:

- `onlyRole(VAULT_FACTORY_ROLE)`
- caller vault derived from `msg.sender` (no `vault` parameter): strict self-register
- `vaultId > 0`
- uniqueness:
  - `vaultId` not already used
  - `vault` not already registered
  - `vaultName` not already used
- `vaultName` format:
  - length `1..12`
  - allowed characters: `A-Z`, `0-9`

Token creation:

- Name: `Staked Quantillon Euro {vaultName}`
- Symbol: `stQEURO{vaultName}`
- Deploy an `ERC1967Proxy` pointing to the `stQEUROToken` implementation
- Initialize the proxy with dynamic metadata (`tokenName`, `tokenSymbol`, `vaultName`)

### Events

- `VaultRegistered(vaultId, vault, stQEUROToken, vaultName)`
- `FactoryConfigUpdated(key, oldValue, newValue)`

### Governance reconfiguration

- `updateYieldShift(address)`
- `updateTokenImplementation(address)`
- `updateOracle(address)`
- `updateTreasury(address)`
- `updateTokenAdmin(address)`

---

## 2) `stQEUROToken` evolution

`stQEUROToken` remains the vault-level token (stake/unstake/yield logic preserved), but can now be initialized with dynamic metadata.

### Key changes

- Added `string public vaultName`.
- Added an overloaded `initialize(...)` supporting:
  - `_tokenName`
  - `_tokenSymbol`
  - `_vaultName`
- Kept the legacy initializer (default metadata).
- Centralized initialization in `_initializeStQEURO(InitConfig memory cfg)`.

### Roles

At initialization:

- `DEFAULT_ADMIN_ROLE`, `GOVERNANCE_ROLE`, `EMERGENCY_ROLE` -> `admin`
- `YIELD_MANAGER_ROLE` -> `admin`
- `YIELD_MANAGER_ROLE` -> `yieldShift` (explicit grant)

---

## 3) `QuantillonVault` evolution (self-registration)

Additions:

- `stQEUROFactory` (linked factory address)
- `stQEUROToken` (token deployed for this vault)
- `stQEUROVaultId` (registered vault id)
- event `StQEURORegistered(...)`

New function:

- `selfRegisterStQEURO(address factory, uint256 vaultId, string vaultName)`
  - `onlyRole(GOVERNANCE_ROLE)`
  - local anti double-registration (`stQEUROToken == address(0)`)
  - factory call originates from the vault itself, enforcing `msg.sender == vault` on the factory side
  - persists local references for factory/token/vaultId

---

## 4) `YieldShift` evolution (multi-vault routing)

### Dependency change

- Old model: direct reference to a single `stQEURO`.
- New model: reference to `stQEUROFactory`.

`YieldDependencyConfig` field replacement:

- `stQEURO` -> `stQEUROFactory`

### New signature

- `addYield(uint256 vaultId, uint256 yieldAmount, bytes32 source)`

### Routing flow

1. Verify global source authorization (`authorizedYieldSources` + `sourceToYieldType`).
2. Pull USDC from source to `YieldShift`.
3. Compute `userAllocation` / `hedgerAllocation`.
4. Resolve target token through `stQEUROFactory.getStQEUROByVaultId(vaultId)`.
5. Revert if vault is not registered (`address(0)`).
6. Keep coherent pull flow toward token:
   - `safeIncreaseAllowance(stQEURO, userAllocation)`
   - `IstQEURO(stQEURO).distributeYield(userAllocation)`

Source policy:

- remains global (no strict `source -> vaultId` binding).

---

## 5) `AaveVault` evolution

Additions:

- `uint256 public yieldVaultId` (governance config)
- `setYieldVaultId(uint256)` (reverts if `0`)
- `updateYieldShift(address)` (explicit rewiring)

Change in `harvestAaveYield()`:

- validate `yieldVaultId != 0`
- routing call:
  - `yieldShift.addYield(yieldVaultId, netYield, bytes32("aave"))`

---

## 6) Impacted interfaces

- New: `IStQEUROFactory`
  - `registerVault(vaultId, vaultName)`
  - resolution getters (`vaultId -> token`, `token -> vaultId`, etc.)
- `IYieldShift`
  - `addYield` becomes `addYield(vaultId, yieldAmount, source)`
  - dependency config: `stQEUROFactory`
- `IAaveVault`
  - `setYieldVaultId(uint256)`
  - `updateYieldShift(address)`
  - `yieldVaultId()`
- `IQuantillonVault`
  - `selfRegisterStQEURO(...)`
  - getters `stQEUROFactory`, `stQEUROToken`, `stQEUROVaultId`
- `IstQEURO`
  - overloaded `initialize(...)` with dynamic metadata

---

## 7) Deployment scripts and wiring

`DeployQuantillon.s.sol` is updated to:

1. Deploy `YieldShift`.
2. Deploy `stQEUROToken` implementation.
3. Deploy `stQEUROFactory` (proxy) while injecting token implementation.
4. Configure `YieldShift` with `stQEUROFactory`.
5. Rewire `AaveVault` to `YieldShift`.
6. Leave `AaveVault.yieldVaultId` unset until governance/core-team vault decision.
7. Do not register any stQEURO vault token during bootstrap deployment.
8. Register vaults later via explicit core-team governance flow.

At bootstrap, no vault-name environment variable is consumed by `DeployQuantillon.s.sol`.

Exports:

- addresses and ABIs now include `stQEUROFactory`.

---

## 8) Breaking changes

Breaking changes assumed for this iteration:

1. `YieldShift.addYield(...)` now requires `vaultId`.
2. `YieldShift` dependency points to the factory instead of a single token.
3. Deployment flows must explicitly register vaults.
4. Integrations calling the old API `addYield(yieldAmount, source)` must be updated.

No on-chain legacy migration is included in this pass.

---

## 9) Validation and test coverage

### New test

- `test/stQEUROFactory.t.sol`
  - registration OK
  - duplicate `vaultId`
  - duplicate vault address
  - invalid/duplicate `vaultName`
  - unauthorized caller

### Updated tests

- `YieldShift.t.sol` (`vaultId` routing, factory dependency)
- `AaveVault.t.sol` (`yieldVaultId`, new `addYield` signature)
- `DeploymentSmoke.t.sol`, `IntegrationTests.t.sol`, `QuantillonInvariants.t.sol`, `LiquidationScenarios.t.sol`, `stQEUROToken.t.sol` (initializer/signature alignment)

### Result

- `forge build --skip test` passes
- targeted suites pass
- `forge test -q` passes

---

## 10) Runbook: adding a new staking vault

To onboard `vaultId = N`:

1. Deploy/configure the new vault (including governance roles).
2. From governance, grant `VAULT_FACTORY_ROLE` to the vault address.
3. Call `vault.selfRegisterStQEURO(factory, N, VAULT_NAME)`.
4. Verify:
   - `factory.getStQEUROByVaultId(N) != 0`
   - `factory.getVaultById(N) == vault`
   - `factory.getVaultName(N) == VAULT_NAME`
5. If the vault receives yield through `YieldShift`, route `addYield(N, ...)` calls from the relevant source.
6. Update address/ABI exports and the off-chain integration layer.

---

## 11) Attention points for next steps

1. Add multi-vault integration tests (2+ active vaults simultaneously).
2. Evaluate an optional `source -> vaultId` binding policy if stricter controls are needed later.
3. Document a `stQEUROToken` implementation rotation procedure via `updateTokenImplementation`.
4. Add on-chain monitoring for:
   - `VaultRegistered` events
   - `vaultId/token` consistency in indexers

---

## 12) Executive summary

This upgrade introduces a robust factory layer that enables QEURO staking to scale across multiple vaults without mixing staking positions.

- One vault = one dedicated stQEURO token.
- Yield routing becomes explicitly keyed by `vaultId`.
- Self-registration guarantees strict and auditable registration semantics.
- Deployment/wiring is automated for the first instance (`vaultId = 1`) and ready for the next vaults.
