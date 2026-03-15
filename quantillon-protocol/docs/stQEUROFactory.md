# Upgrade Technique: stQEURO Multi-Vault avec `stQEUROFactory`

## Contexte

Le protocole utilisait initialement un seul token de staking `stQEURO` pour un seul vault de staking.  
L'architecture a ete etendue pour supporter plusieurs vaults (identifies par `vaultId`), avec un token dedie par vault:

- `vaultId = 1` -> `stQEURO<VAULT_NAME_1>`
- `vaultId = 2` -> `stQEURO<VAULT_NAME_2>`
- ...

Ces tokens ne sont pas fongibles entre eux (adresses ERC20 distinctes, metadata distinctes, comptabilite de rendement distincte).

---

## Objectif de l'upgrade

1. Remplacer le modele "single stQEURO token" par une factory upgradeable.
2. Conserver `stQEUROToken` comme implementation de token de staking par vault.
3. Router le rendement (`YieldShift`) via `vaultId`.
4. Imposer un enregistrement strict du vault via self-call on-chain.
5. Mettre a jour le deploiement, les interfaces et les tests.

---

## Composants modifies

## 1) Nouveau contrat `stQEUROFactory`

Le contrat introduit une couche d'orchestration pour deployer et enregistrer dynamiquement un token `stQEURO` par vault.

### Responsibilities

- Deployer un proxy `ERC1967Proxy` par vault vers l'implementation `stQEUROToken`.
- Conserver les index de resolution `vaultId <-> vault <-> token`.
- Conserver la metadata de vault (`vaultName`).
- Fournir des getters de resolution pour `YieldShift`, scripts et indexers.

### Upgradeability et access control

- Pattern: `Initializable + AccessControlUpgradeable + SecureUpgradeable` (UUPS via `SecureUpgradeable`).
- Roles:
  - `GOVERNANCE_ROLE`: reconfiguration factory (impl, yieldShift, treasury, etc.)
  - `VAULT_FACTORY_ROLE`: permission d'enregistrement des vaults

### Stockage principal

- `stQEUROByVaultId[vaultId] -> token`
- `stQEUROByVault[vault] -> token`
- `vaultById[vaultId] -> vault`
- `vaultIdByStQEURO[token] -> vaultId`
- `_vaultNamesById[vaultId] -> vaultName`
- `_vaultNameHashUsed[keccak256(vaultName)] -> bool`

### Enregistrement strict: `registerVault(uint256 vaultId, string vaultName)`

Contraintes appliquees:

- `onlyRole(VAULT_FACTORY_ROLE)`
- vault appeleur derive de `msg.sender` (pas de parametre `vault`): self-register strict
- `vaultId > 0`
- unicite:
  - `vaultId` non deja utilise
  - `vault` non deja enregistre
  - `vaultName` non deja utilise
- format `vaultName`:
  - longueur `1..12`
  - caracteres autorises: `A-Z`, `0-9`

Creation du token:

- Name: `Staked Quantillon Euro {vaultName}`
- Symbol: `stQEURO{vaultName}`
- Deploiement d'un `ERC1967Proxy` pointant vers `stQEUROToken` implementation
- Initialisation du proxy avec metadata dynamique (`tokenName`, `tokenSymbol`, `vaultName`)

### Evenements

- `VaultRegistered(vaultId, vault, stQEUROToken, vaultName)`
- `FactoryConfigUpdated(key, oldValue, newValue)`

### Reconfiguration gouvernance

- `updateYieldShift(address)`
- `updateTokenImplementation(address)`
- `updateOracle(address)`
- `updateTreasury(address)`
- `updateTokenAdmin(address)`

---

## 2) Evolution de `stQEUROToken`

`stQEUROToken` reste le token vault-level (logique stake/unstake/yield conservee), mais peut maintenant etre initialise avec metadata dynamique.

### Changements cles

- Ajout de `string public vaultName`.
- Ajout d'un overload `initialize(...)` supportant:
  - `_tokenName`
  - `_tokenSymbol`
  - `_vaultName`
- Conservation de l'initializer legacy (metadata par defaut).
- Centralisation de l'init dans `_initializeStQEURO(InitConfig memory cfg)`.

### Roles

Lors de l'initialisation:

- `DEFAULT_ADMIN_ROLE`, `GOVERNANCE_ROLE`, `EMERGENCY_ROLE` -> `admin`
- `YIELD_MANAGER_ROLE` -> `admin`
- `YIELD_MANAGER_ROLE` -> `yieldShift` (grant explicite)

---

## 3) Evolution de `QuantillonVault` (self-registration)

Ajouts:

- `stQEUROFactory` (adresse factory associee)
- `stQEUROToken` (token deploye pour ce vault)
- `stQEUROVaultId` (vault id enregistre)
- event `StQEURORegistered(...)`

Nouvelle fonction:

- `selfRegisterStQEURO(address factory, uint256 vaultId, string vaultName)`
  - `onlyRole(GOVERNANCE_ROLE)`
  - anti double-enregistrement local (`stQEUROToken == address(0)`)
  - appel factory depuis le vault lui-meme, ce qui force `msg.sender == vault` cote factory
  - persistance des references locales factory/token/vaultId

---

## 4) Evolution de `YieldShift` (routing multi-vault)

### Changement de dependance

- Ancien modele: reference directe a un unique `stQEURO`.
- Nouveau modele: reference a `stQEUROFactory`.

`YieldDependencyConfig` remplace le champ:

- `stQEURO` -> `stQEUROFactory`

### Nouvelle signature

- `addYield(uint256 vaultId, uint256 yieldAmount, bytes32 source)`

### Flux de routage

1. Verifier l'autorisation globale de la source (`authorizedYieldSources` + `sourceToYieldType`).
2. Pull USDC depuis la source vers `YieldShift`.
3. Calculer `userAllocation` / `hedgerAllocation`.
4. Resoudre le token cible via `stQEUROFactory.getStQEUROByVaultId(vaultId)`.
5. Revert si vault non enregistre (`address(0)`).
6. Flux pull coherent vers token:
   - `safeIncreaseAllowance(stQEURO, userAllocation)`
   - `IstQEURO(stQEURO).distributeYield(userAllocation)`

Politique source:

- conservee globale (pas de binding strict `source -> vaultId`).

---

## 5) Evolution de `AaveVault`

Ajouts:

- `uint256 public yieldVaultId` (config governance)
- `setYieldVaultId(uint256)` (revert si `0`)
- `updateYieldShift(address)` (rewiring explicite)

Changement dans `harvestAaveYield()`:

- Validation `yieldVaultId != 0`
- Appel de routage:
  - `yieldShift.addYield(yieldVaultId, netYield, bytes32("aave"))`

---

## 6) Interfaces impactees

- Nouveau: `IStQEUROFactory`
  - `registerVault(vaultId, vaultName)`
  - getters de resolution (`vaultId -> token`, `token -> vaultId`, etc.)
- `IYieldShift`
  - `addYield` devient `addYield(vaultId, yieldAmount, source)`
  - config dependency: `stQEUROFactory`
- `IAaveVault`
  - `setYieldVaultId(uint256)`
  - `updateYieldShift(address)`
  - `yieldVaultId()`
- `IQuantillonVault`
  - `selfRegisterStQEURO(...)`
  - getters `stQEUROFactory`, `stQEUROToken`, `stQEUROVaultId`
- `IstQEURO`
  - overload `initialize(...)` avec metadata dynamique

---

## 7) Scripts de deploiement et wiring

`DeployQuantillon.s.sol` est mis a jour pour:

1. Deployer `YieldShift`.
2. Deployer l'implementation `stQEUROToken`.
3. Deployer `stQEUROFactory` (proxy) en lui injectant l'implementation token.
4. Configurer `YieldShift` avec `stQEUROFactory`.
5. Rewirer `AaveVault` vers `YieldShift`.
6. Configurer `AaveVault.setYieldVaultId(1)`.
7. Accorder `VAULT_FACTORY_ROLE` au `QuantillonVault`.
8. Enregistrer le vault 1 via `quantillonVault.selfRegisterStQEURO(...)`.
9. Recuperer le token du vault 1 via factory et finaliser son wiring (oracle).

Variable d'environnement ajoutee:

- `STQEURO_VAULT_NAME` (defaut: `CORE`)

Exports:

- adresses et ABIs incluent maintenant `stQEUROFactory`.

---

## 8) Breaking changes

Breaking changes assumes pour cette iteration:

1. `YieldShift.addYield(...)` requiert maintenant `vaultId`.
2. La dependency `YieldShift` pointe vers la factory et non vers un token unique.
3. Les flows de deploiement doivent enregistrer explicitement les vaults.
4. Les integrations qui appelaient directement l'ancien API `addYield(yieldAmount, source)` doivent etre adaptees.

Pas de migration legacy on-chain incluse dans cette passe.

---

## 9) Validation et couverture de tests

### Nouveau test

- `test/stQEUROFactory.t.sol`
  - registration OK
  - duplicate `vaultId`
  - duplicate vault address
  - invalid/duplicate `vaultName`
  - unauthorized caller

### Tests adaptes

- `YieldShift.t.sol` (routing par `vaultId`, dependency factory)
- `AaveVault.t.sol` (`yieldVaultId`, nouvelle signature `addYield`)
- `DeploymentSmoke.t.sol`, `IntegrationTests.t.sol`, `QuantillonInvariants.t.sol`, `LiquidationScenarios.t.sol`, `stQEUROToken.t.sol` (alignement des initializers/signatures)

### Resultat

- `forge build --skip test` passe
- suites ciblees passees
- `forge test -q` passe

---

## 10) Runbook: ajout d'un nouveau vault de staking

Pour onboarder `vaultId = N`:

1. Deployer/configurer le nouveau vault (roles governance inclus).
2. Depuis governance, accorder `VAULT_FACTORY_ROLE` a l'adresse du vault.
3. Appeler `vault.selfRegisterStQEURO(factory, N, VAULT_NAME)`.
4. Verifier:
   - `factory.getStQEUROByVaultId(N) != 0`
   - `factory.getVaultById(N) == vault`
   - `factory.getVaultName(N) == VAULT_NAME`
5. Si le vault recoit du yield via `YieldShift`, router les appels `addYield(N, ...)` depuis la source concernee.
6. Mettre a jour les exports d'adresses/ABI et la couche d'integration off-chain.

---

## 11) Points d'attention pour la suite

1. Ajouter des tests d'integration multi-vault (2+ vaults actifs simultanement).
2. Evaluer une politique optionnelle de binding `source -> vaultId` si besoin de durcissement futur.
3. Documenter une procedure de rotation d'implementation `stQEUROToken` via `updateTokenImplementation`.
4. Ajouter monitoring on-chain:
   - events `VaultRegistered`
   - coherence `vaultId/token` dans les indexers

---

## 12) Resume executif

Cet upgrade introduit une couche factory robuste qui permet de scaler le staking QEURO a plusieurs vaults sans melanger les positions de staking.

- Un vault = un token stQEURO dedie.
- Le routage de yield devient explicite par `vaultId`.
- Le self-register garantit une semantique d'enregistrement stricte et auditable.
- Le deploiement/wiring est automatise pour la premiere instance (`vaultId = 1`) et pret pour les vaults suivants.
