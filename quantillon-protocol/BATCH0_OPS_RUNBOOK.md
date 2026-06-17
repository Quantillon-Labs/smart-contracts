# Batch 0 — Trust-Model Operational Runbook (Base mainnet, chainId 8453)

> **Why this exists.** Today **every privileged role on the live protocol is held by the deployer
> EOA** (`0x8DAD…098d1`), which is also wired in as each upgradeable proxy's `timelock` pointer.
> One key = full protocol takeover (upgrade any implementation, switch the oracle, change fees,
> drain via a malicious impl). This runbook moves all of that to a Gnosis Safe + an upgrade
> timelock, with **no protocol redeployment** — every existing proxy stays put and is only
> re-pointed / re-roled. It is the **single highest-priority** item in the remediation program.
>
> Do every EOA step from the hardware-backed deployer wallet (MetaMask); never paste its key into a
> shell. Do every Safe step through the Safe UI / Safe Transaction Builder, signed by both owners.

- **Status:** ready to execute. The deploy script + a full fork dry-run exist and pass (see §8).
- **Verified live (read-only, Base @ block ~47.37M):** no Timelock has ever been deployed (all 7
  SecureUpgradeable proxies have `timelock = deployer EOA`); the deployer is an **EIP-7702 smart
  account** (delegate `0x63c0…32b`); **TimeProvider is ownerless & immutable** (initializers
  permanently disabled — nothing to migrate); QTI `totalSupply = 0`; QEURO `MINTER` is on the
  Vault, not the EOA.

---

## 1. Target architecture (decided)

- **`MULTISIG` = Gnosis Safe** `0x1d7fF432a93d0085Fb69474c7E567f859829e6cd` — 2-of-2, both signers
  hardware Ledgers (`0x1a07…905c` + Toni's Ledger). Holds **all privileged protocol roles** and is
  the everyday governance + the upgrade initiator/executor.
- **`TIMELOCK` = OpenZeppelin `TimelockController`** (deployed in Step 1) — `minDelay = 12h`,
  `proposers = [Safe]`, `executors = [Safe]`, `admin = 0` (self-administered, no backdoor). It is
  each SecureUpgradeable proxy's new `timelock`. Upgrades run: **Safe `schedule` → wait 12h → Safe
  `execute`** (the controller calls `proxy.executeUpgrade` as the timelock).
  - Chosen over the protocol's native `TimelockUpgradeable` because that contract hard-codes
    `MIN_MULTISIG_APPROVALS = 2` distinct signers (a single Safe can't satisfy it). The proxies'
    `executeUpgrade` is gated purely by `msg.sender == timelock`, so any timelock contract works.
- **Deployer EOA** `0x8DAD…098d1` — executes the migration txs (it is still admin), then
  **renounces every role** and exits the trust model.
- **TimeProvider** `0x5202…56E7` — ownerless/immutable; **do nothing**.

> **F-5 caveat (interim):** until the F-5 fix is deployed, whoever holds `DEFAULT_ADMIN` (after this,
> the Safe) can still `toggleSecureUpgrades(false)` → `emergencyUpgrade` and skip the 12h delay. The
> delay is honest-path-only until F-5 ships — make F-5 an early upgrade *through* the new controller.
> It is never a single-key hole (the Safe is 2-of-2).

---

## 2. Role matrix (verified on-chain — the exact set to move)

`✅ → Safe` = currently on the EOA, move to the Safe.  `stays` = correctly held elsewhere, **do not touch**.

| Contract | Type | Roles on EOA → **Safe** | Stays put (not on EOA) |
|---|---|---|---|
| **QEUROToken** | Secure | `DEFAULT_ADMIN`, `UPGRADER`, `PAUSER`, `COMPLIANCE` | `MINTER`,`BURNER` → Vault |
| **QuantillonVault** | Secure | `DEFAULT_ADMIN`, `GOVERNANCE`, `EMERGENCY` | `VAULT_OPERATOR`,`YIELD_DISTRIBUTOR` |
| **QTIToken** | Secure | `DEFAULT_ADMIN`, `GOVERNANCE`, `EMERGENCY` | — |
| **UserPool** | Secure | `DEFAULT_ADMIN`, `GOVERNANCE`, `EMERGENCY` | — |
| **HedgerPool** | Secure | `DEFAULT_ADMIN`, `GOVERNANCE`, `EMERGENCY` | — |
| **stQEUROFactory** | Secure | `DEFAULT_ADMIN`, `GOVERNANCE`, `VAULT_FACTORY` | — |
| **YieldShift** | Secure | `DEFAULT_ADMIN`, `GOVERNANCE`, `EMERGENCY`, `YIELD_MANAGER` | — |
| **FeeCollector** | Plain-UUPS | `DEFAULT_ADMIN`, `GOVERNANCE`, `EMERGENCY`, `TREASURY` ⚠️ | `FEE_SOURCE` → fee-source contracts |
| **OracleRouter** | Plain-UUPS | `DEFAULT_ADMIN`, `EMERGENCY`, `UPGRADER`, `ORACLE_MANAGER` | — |
| **ChainlinkOracle** | Plain-UUPS | `DEFAULT_ADMIN`, `EMERGENCY`, `UPGRADER`, `ORACLE_MANAGER` | — |
| **StorkOracle** | Plain-UUPS | `DEFAULT_ADMIN`, `EMERGENCY`, `UPGRADER`, `ORACLE_MANAGER` | — |
| **SlippageStorage** | Plain-UUPS | `DEFAULT_ADMIN`, `EMERGENCY`, `UPGRADER`, `MANAGER` → Safe | **`WRITER` stays on Wallet_Metamask** (deployer EOA) |
| **MetaMorphoStakingVaultAdapter** | Non-upgr. | `DEFAULT_ADMIN`, `GOVERNANCE` → Safe; renounce EOA's `VAULT_MANAGER` | `VAULT_MANAGER` stays on **QuantillonVault** (operates deposit/withdraw/harvest) |
| **TimeProvider** | immutable | — (ownerless) | everything |

**Two flags (decided):**
- ✅ **FeeCollector `TREASURY_ROLE`** → **Safe** (the Safe becomes the fee treasury controller).
- ✅ **SlippageStorage `WRITER_ROLE`** → **stays on Wallet_Metamask** (the deployer EOA `0x8DAD…098d1`).
  It is the low-privilege slippage-publisher role; the `slippage-monitor` backend signs writes with it
  on a ~60s timer, which a Safe/Ledger cannot autosign. After Batch 0 the EOA holds **only** this role
  (every powerful role renounced), demoting the old deployer key to a dedicated publisher. The role is
  not a takeover vector but is not zero-privilege (a leak lets someone push false slippage data).
  Note: the publisher is currently **disabled** (`PUBLISHER_ENABLED=false`) and unkeyed — enable it and
  set `PUBLISHER_PRIVATE_KEY` to this wallet to publish. If you later fully retire this wallet, move
  `WRITER` to a fresh publisher key then.

**Secure vs Plain-UUPS:** only the 7 *Secure* contracts get `setTimelock(controller)` and the 12h
delayed-upgrade path. The 5 *Plain-UUPS* contracts have no timelock; their upgrades stay role-gated
(`UPGRADER`/`GOVERNANCE`/`ORACLE_MANAGER`) held by the Safe — instant, no delay (known F-2 limit).

---

## 3. Addresses

```
SAFE      = 0x1d7fF432a93d0085Fb69474c7E567f859829e6cd   # Gnosis Safe 2-of-2 (Ledgers)
DEPLOYER  = 0x8DAD1B6c1A40e2649d50952977b5af1992f098d1   # current all-roles EOA (signs Step 1–4,6)
TIMELOCK  = 0x7Ade8f3Bf1FdaF0785efE9Ea5C6339D1aD6B8342   # deployed Step 1 (tx 0x36057886…, block 47372581; 12h, Safe proposer/executor, admin=0)

# SecureUpgradeable (get setTimelock)
QEURO=0x69aD4e6c49d6275D0e11b5515D98a89f029869AA   VAULT=0x833E5Ba510a241b21F1C60c987D1c49eB52E4a07
QTI=0x246c6F441c0f8Fc6A71Db0F12dB5665D373Df271      USER_POOL=0x712bCc77e7aa53C79870A40d044D440Ad2901bF2
HEDGER=0xff5D7cE5c7671B2EA805Ee752B4f8eC9Ecf2975A   STQ_FACTORY=0x0382B0b9FB6Ff737209C3B31D727BB9d2E2bcb53
YIELD_SHIFT=0xdcd66568F8623bDa3387287c31F14b43e49665b1
# Plain-UUPS (no setTimelock)
FEE_COLLECTOR=0x0A33F72683cfC2303639d5cB9A45D77fF16d9FAD  ORACLE_ROUTER=0x7ED6aaEd83Db69509A88CAe5C247ef8fA44056E0
CHAINLINK=0xaEE3c9c298051ef7242882AbCaE2Fd12d29443E7      STORK=0x41FcE00E33Ca4f0d8E5528c343FAC98BA178EebC
SLIPPAGE=0x0fde0ff2566be3c24af6d654012dddb4f1da099b
# non-upgradeable yield adapter (AccessControl; role migration only, no setTimelock)
META_ADAPTER=0x103aEBD0059AAA3DcCaa9ab0cCb901382Bd48978
# immutable / leave alone
TIME_PROVIDER=0x520236487CBD0a6958B4EefC7853cd7C3F5C56E7
```
Role ids: `DEFAULT_ADMIN_ROLE = 0x00…00`; all others = `cast keccak "<ROLE_NAME>"`.

---

## 4. Pre-flight (read-only) — confirm scope hasn't drifted

Re-run the EOA role audit and confirm it matches §2 (membership can change between now and execution):
```bash
for C in $QEURO $VAULT $QTI $USER_POOL $HEDGER $STQ_FACTORY $YIELD_SHIFT \
         $FEE_COLLECTOR $ORACLE_ROUTER $CHAINLINK $STORK $SLIPPAGE; do
  for R in DEFAULT_ADMIN_ROLE GOVERNANCE_ROLE EMERGENCY_ROLE UPGRADER_ROLE PAUSER_ROLE \
           COMPLIANCE_ROLE ORACLE_MANAGER_ROLE YIELD_MANAGER_ROLE VAULT_FACTORY_ROLE \
           MANAGER_ROLE TREASURY_ROLE WRITER_ROLE; do
    H=$([ "$R" = DEFAULT_ADMIN_ROLE ] && echo 0x00...0 || cast keccak "$R")
    [ "$(cast call $C "hasRole(bytes32,address)(bool)" $H $DEPLOYER --rpc-url $RPC)" = true ] && echo "$C $R"
  done
done
```
Also: `cast call $VAULT "timelock()(address)"` should still return `$DEPLOYER` on all 7 Secure proxies.

---

## 5. Execution sequence

### Step 1 — Deploy the TimelockController (EOA; no protocol state touched)
```bash
SAFE_ADDRESS=$SAFE TIMELOCK_MIN_DELAY=43200 PRIVATE_KEY=<deployer> \
  forge script scripts/deployment/DeployTimelockController.s.sol:DeployTimelockController \
    --rpc-url $RPC --broadcast
```
Record the printed address as `TIMELOCK`. (Dry-run first on a fork — §8.)

### Step 2 — Repoint `timelock` → controller on the 7 Secure proxies (EOA)
> **Must precede any renounce.** `timelock` is a separate variable from the roles; if you renounce
> first, the EOA stays the timelock and keeps upgrade power.
```bash
for C in $QEURO $VAULT $QTI $USER_POOL $HEDGER $STQ_FACTORY $YIELD_SHIFT; do
  cast send $C "setTimelock(address)" $TIMELOCK --rpc-url $RPC --account deployer
  cast call $C "timelock()(address)" --rpc-url $RPC   # expect $TIMELOCK
done
```

### Step 3 — Grant every EOA-held role to the Safe (EOA) — per the §2 matrix
Grant exactly the roles listed in §2 for each contract. Example (QEURO + Vault shown; repeat per row):
```bash
ADMIN=0x0000000000000000000000000000000000000000000000000000000000000000
cast send $QEURO "grantRole(bytes32,address)" $ADMIN $SAFE --rpc-url $RPC --account deployer
cast send $QEURO "grantRole(bytes32,address)" $(cast keccak "UPGRADER_ROLE")   $SAFE --rpc-url $RPC --account deployer
cast send $QEURO "grantRole(bytes32,address)" $(cast keccak "PAUSER_ROLE")     $SAFE --rpc-url $RPC --account deployer
cast send $QEURO "grantRole(bytes32,address)" $(cast keccak "COMPLIANCE_ROLE") $SAFE --rpc-url $RPC --account deployer
cast send $VAULT "grantRole(bytes32,address)" $ADMIN $SAFE --rpc-url $RPC --account deployer
cast send $VAULT "grantRole(bytes32,address)" $(cast keccak "GOVERNANCE_ROLE") $SAFE --rpc-url $RPC --account deployer
cast send $VAULT "grantRole(bytes32,address)" $(cast keccak "EMERGENCY_ROLE")  $SAFE --rpc-url $RPC --account deployer
# … continue for QTI, UserPool, HedgerPool, stQEUROFactory(+VAULT_FACTORY_ROLE),
#    YieldShift(+YIELD_MANAGER_ROLE), FeeCollector(+TREASURY_ROLE), the 3 oracles(+ORACLE_MANAGER_ROLE),
#    SlippageStorage(+MANAGER_ROLE).  Do NOT grant WRITER_ROLE to the Safe (see Step 6).
```

### Step 4 — Verify + exercise the Safe (read + 1 Safe tx)
```bash
# every granted role now true for the Safe:
cast call $VAULT "hasRole(bytes32,address)(bool)" $(cast keccak "GOVERNANCE_ROLE") $SAFE --rpc-url $RPC
```
Then execute **one** harmless admin action **from the Safe** (e.g. re-`grantRole` a role it already
holds, or re-`setTimelock($TIMELOCK)` on one Secure proxy) to prove 2-of-2 control **before** the EOA
gives anything up.

### Step 5 — Renounce every role from the EOA (EOA) — `DEFAULT_ADMIN_ROLE` LAST per contract
```bash
# For each contract, renounce the non-admin roles first, then DEFAULT_ADMIN last:
cast send $VAULT "renounceRole(bytes32,address)" $(cast keccak "GOVERNANCE_ROLE") $DEPLOYER --rpc-url $RPC --account deployer
cast send $VAULT "renounceRole(bytes32,address)" $(cast keccak "EMERGENCY_ROLE")  $DEPLOYER --rpc-url $RPC --account deployer
cast send $VAULT "renounceRole(bytes32,address)" $ADMIN $DEPLOYER --rpc-url $RPC --account deployer   # LAST
# … repeat for every contract, matching the §2 set.
```
Then re-run §4 audit and confirm **every line returns false for `$DEPLOYER`**.

### Step 6 — SlippageStorage `WRITER_ROLE` (keep on the deployer wallet)
`WRITER` stays on **Wallet_Metamask** (`$DEPLOYER`) — the low-privilege slippage-publisher role.
**Do nothing here, and do NOT renounce it in Step 5.** After Batch 0 the EOA holds *only* `WRITER` on
SlippageStorage (every powerful role renounced). To publish, enable the backend
(`PUBLISHER_ENABLED=true`) and set `PUBLISHER_PRIVATE_KEY` to this wallet's key. (If you later want to
fully retire this wallet, move `WRITER` to a fresh publisher key then and renounce it here.)

### Step 7 — Oracle hardening (Safe, now `ORACLE_MANAGER`)
```bash
# F-9: set Base's sequencer-uptime feed (verify the canonical address from Chainlink docs first):
#   ChainlinkOracle.setSequencerUptimeFeed(0xBCF85224fc0756B9Fa45aA7892530B47e10b6433, 3600)  — Safe tx (feed, gracePeriod secs); confirm the feed addr from Chainlink docs
# F-7: confirm the production feeds:
cast call 0xc91D87E81faB8f93699ECf7Ee9B44D11e1D53F0F "description()(string)" --rpc-url $RPC   # "EUR / USD"
cast call 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B "description()(string)" --rpc-url $RPC   # "USDC / USD"
```

### Step 8 — Record
Add `Timelock` (controller) + `Multisig` (Safe) to `deployments/8453/addresses.json`. Add `SlippageStorage`
(`0x0fde…099b`) too — it is currently missing from that file.

---

## 6. How upgrades work afterwards (Secure proxies)
```
Safe → TimelockController.schedule(proxy, 0, executeUpgrade(newImpl)-calldata, 0, salt, 12h)
        … wait 12h …
Safe → TimelockController.execute(proxy, 0, same calldata, 0, salt)
        → controller calls proxy.executeUpgrade(newImpl)  (msg.sender == timelock)  → upgradeToAndCall
```
Deploy `newImpl` first (permissionless); only `schedule`/`execute` are gated (Safe). Plain-UUPS
contracts instead upgrade via the Safe calling their `upgradeToAndCall` directly (no delay).

---

## 7. Done-when checklist
- [ ] `TIMELOCK` (OZ controller, 12h, proposer+executor = Safe, admin = 0) deployed & recorded.
- [ ] All 7 Secure proxies: `timelock() == TIMELOCK`.
- [ ] Every role in the §2 matrix held by the **Safe**; **deployer EOA returns `false` for every role on every contract**.
- [ ] QEURO `MINTER`/`BURNER` still on the Vault; FeeCollector `FEE_SOURCE` unchanged.
- [ ] MetaMorpho adapter (`0x103aEBD…`): `DEFAULT_ADMIN`/`GOVERNANCE` → Safe; EOA's `VAULT_MANAGER` renounced; Vault keeps `VAULT_MANAGER`. (Basescan source: on-chain build is pre-CEI-fix — verify from deploy commit `d4d6d61`, or fold into the adapter redeploy+rewire.)
- [ ] `WRITER_ROLE` left on Wallet_Metamask (`0x8DAD…098d1`); every *other* SlippageStorage role moved to the Safe + renounced from the EOA.
- [ ] `ChainlinkOracle.sequencerUptimeFeed` set; EUR/USD + USDC/USD feed descriptions confirmed.
- [ ] `Timelock`, `Multisig`, `SlippageStorage` recorded in `addresses.json`.
- [ ] (Follow-up) deploy F-5 through the new controller to make the 12h delay non-bypassable.

## 8. Dry-run (already passing)
A full fork simulation of Steps 1–5 + a real 12h-delayed upgrade is in
`scripts/deployment/SimulateBatch0Migration.s.sol`; run it before touching mainnet:
```bash
FORK_RPC=$RPC forge script scripts/deployment/SimulateBatch0Migration.s.sol:SimulateBatch0Migration -vv
```
It deploys the controller, repoints/migrates/renounces across all 11 contracts, asserts the EOA ends
with no admin, and exercises schedule → warp 12h → execute. Last run: **PASS** on Base @ 47,370,756.
