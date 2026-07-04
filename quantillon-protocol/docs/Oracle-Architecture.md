# Oracle Architecture

How QEURO mint/redeem is priced on-chain: a dual-source `OracleRouter` whose **active** EUR/USD source
is the Hyperliquid `xyz:EUR` perpetual mid (the venue where the protocol hedge executes), with the
`ChainlinkOracle` retained as a one-transaction fallback. Live on Base mainnet since 2026-06-25.

## Why hedge-aligned pricing

The protocol neutralizes the EUR/USD leg with a hedge on Hyperliquid. Pricing QEURO mint/redeem off a
generic *spot* feed while the hedge fills at the *venue* price leaves a persistent basis between the
QEURO liability and its hedge. Reading the venue mid on-chain removes that basis by construction.
Chainlink spot is kept as a safety reference and fallback, not as the primary valuation source.

## Components

| Contract | Source | Role |
|---|---|---|
| `OracleRouter` | `src/oracle/OracleRouter.sol` | Routes `IOracle` reads to the active oracle; `switchOracle` |
| `HyperliquidEurUsdOracle` | `src/oracle/HyperliquidEurUsdOracle.sol` | **Active** EUR/USD source (router slot 1) |
| `ChainlinkOracle` | `src/oracle/ChainlinkOracle.sol` | Fallback EUR/USD (slot 0) + USDC/USD validation |
| `StorkOracle` | `src/oracle/StorkOracle.sol` | Legacy/parked (slot 1 now holds the Hyperliquid oracle) |
| `SlippageStorage` | `src/oracle/SlippageStorage.sol` | On-chain store the off-chain publisher writes the mid into |
| `IOracle` / `IHyperliquidOracle` | `src/interfaces/` | Oracle-agnostic interface + adapter extensions |

### Live addresses (Base, chain 8453)

```
OracleRouter             0x7ED6aaEd83Db69509A88CAe5C247ef8fA44056E0
HyperliquidEurUsdOracle  0x0B58aBB57775E0fCEDfd4460e00dD9D9610C2C43  (impl 0xc86e06F293Cc25dFBb4D252b044C7ca0af80B3CC)
ChainlinkOracle          0xaEE3c9c298051ef7242882AbCaE2Fd12d29443E7
SlippageStorage          0x0fde0ff2566be3c24af6d654012dddb4f1da099b
TimeProvider             0x520236487CBD0a6958B4EefC7853cd7C3F5C56E7
QuantillonVault          0x833E5Ba510a241b21F1C60c987D1c49eB52E4a07
Safe (Multisig)          0x1d7fF432a93d0085Fb69474c7E567f859829e6cd
```

All contracts are verified on Basescan.

## Data flow

```
Hyperliquid info API (allMids xyz:EUR)
   │  off-chain Slippage Monitor (separate backend repo)
   ▼
SlippageStorage.getSlippageBySource(SOURCE_HYPERLIQUID=1) → { midPrice (1e18), timestamp }
   │  on-chain read
   ▼
HyperliquidEurUsdOracle   (EUR/USD ← SlippageStorage; USDC/USD ← ChainlinkOracle)
   │  slot 1 of the router
   ▼
OracleRouter (activeOracle = 1)   ◄── ChainlinkOracle (slot 0, fallback)
   │  IOracle.getEurUsdPrice()
   ▼
QuantillonVault (mint/redeem)   +   off-server watchdog (freezes on stale / breaker / basis blow-out)
```

## HyperliquidEurUsdOracle

`is IOracle` (interface `IHyperliquidOracle`), modelled on `StorkOracle`. UUPS, `AccessControl`,
`Pausable`, `TimeProvider`-based time.

- **EUR/USD**: `slippageStorage.getSlippageBySource(sourceId)` → `midPrice` (already 18 decimals) +
  `timestamp` (on-chain write time = staleness anchor). No scaling.
- **USDC/USD**: delegated to `usdcSource` (the `ChainlinkOracle`) via `getUsdcUsdPrice()`, in a
  try/catch so a USDC-feed failure can never block an EUR/USD read (falls back to `(1e18, false)`).
- **Validation**: `maxPriceStaleness` (state var, default 900s, ≤ 3600 hard cap), bounds
  `minEurUsdPrice`/`maxEurUsdPrice` (default 0.80–1.40e18), `MAX_PRICE_DEVIATION` 5% circuit breaker,
  `lastValidEurUsdPrice` fallback, pausable.
- **`getEurUsdPrice()`** returns `(price, isValid)`. On circuit-breaker / paused / stale / out-of-bounds
  / over-deviation it returns `(lastValidEurUsdPrice, false)`; a valid read advances the baseline. A
  `false` flag is a hard stop for the vault (mint/redeem revert) — never a stale price used for valuation.
- **Router compatibility**: implements the four management selectors the router delegates to the active
  oracle (`updatePriceBounds`, `updateUsdcTolerance`, `resetCircuitBreaker`, `triggerCircuitBreaker`), so
  it slots into the (formerly Stork) slot 1 with **no `OracleRouter` change**.
- **Source swap-ready**: `updateSlippageSource(addr, sourceId)` (ORACLE_MANAGER) repoints the EUR/USD
  source — e.g. to a SEDA-backed store later — without touching the vault or router.

## OracleRouter

Two slots: `OracleType.CHAINLINK = 0`, `OracleType.MARKET = 1` (slot 1 = the swappable market oracle, currently Hyperliquid). Slot 1 was named `STORK` before router v1.1.0; the old `storkOracle()` getter remains as a deprecated alias of `marketOracle()`.
`_getActiveOracle()` casts the active slot to `IOracle` and delegates all reads. Management:
`switchOracle(type)` and `updateOracleAddresses(chainlink, slot1)` — both `ORACLE_MANAGER_ROLE`.
`QuantillonVault.oracle` is the router, so the vault prices off whichever slot is active.

## Role model

The Safe holds **every** role on each oracle; the router and the deployer hold **none**. Admin
operations (bounds, staleness, circuit breaker, upgrades) are done by the Safe **directly on the
oracle**, not through the router's delegation functions.

| Holder | DEFAULT_ADMIN | ORACLE_MANAGER | EMERGENCY | UPGRADER |
|---|---|---|---|---|
| Safe `0x1d7f…` | ✓ | ✓ | ✓ | ✓ |
| OracleRouter | — | — | — | — |
| Deployer `0x8DAD…` | — | — | — | — |

`SlippageStorage`: Safe holds `DEFAULT_ADMIN_ROLE`/`MANAGER_ROLE`; the publisher wallet holds
`WRITER_ROLE`. Treasury on all oracles + vault is `0x8DAD…098d1` (used only by emergency recovery).

## Deployment & wiring

`scripts/deployment/DeployHyperliquidOracle.s.sol`:

- `HL_ORACLE_ACTION=deploy-only` deploys the impl + ERC1967 proxy and runs `initialize(admin,
  slippageStorage, sourceId, usdcSource, treasury)`. Set `ORACLE_ADMIN` to the Safe so the new oracle
  matches the existing oracles' governance (Safe = all roles). `SLIPPAGE_STORAGE` is required.
- Go-live (Safe txs): `updateOracleAddresses(chainlink, hlOracle)` to set slot 1, then `switchOracle(1)`.
- Fallback any time: Safe `switchOracle(0)` → ChainlinkOracle.

Verification (forge 1.7.1 + Etherscan v2) needs the chainid in the verifier URL:
`forge verify-contract <impl> src/oracle/HyperliquidEurUsdOracle.sol:HyperliquidEurUsdOracle --chain 8453
--verifier-url "https://api.etherscan.io/v2/api?chainid=8453" --etherscan-api-key $ETHERSCAN_API_KEY
--constructor-args $(cast abi-encode "constructor(address)" <TimeProvider>)`.

## Tests

- `test/HyperliquidEurUsdOracle.t.sol` — unit (read, staleness, bounds, deviation, circuit breaker,
  pause, USDC delegation, source-revert fail-safe, config/access control).
- `test/HyperliquidOracleRouterIntegration.t.sol` — proves the adapter drops into the router's slot 1
  unchanged (routing, bounds/circuit-breaker delegation, USDC pass-through, Chainlink fallback).

## Safety summary

Every failure mode is fail-safe: a stale/invalid/out-of-band read returns `isValid=false` (vault
reverts), the off-server watchdog pauses the vault on staleness / circuit-break / a basis blow-out vs
Chainlink, and governance can fall back to Chainlink with one `switchOracle(0)`.
