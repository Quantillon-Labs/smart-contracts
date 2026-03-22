# Quantillon Protocol — Deployment Guide

## Overview

This guide covers deploying and configuring the Quantillon Protocol smart contracts using Foundry. Core contracts are deployed in a single `forge script` invocation via `DeployQuantillon.s.sol`, which writes the deployed addresses to `deployments/{chainId}/addresses.json`.

---

## Prerequisites

### Required Tools

- **Foundry** (forge, cast, anvil): `curl -L https://foundry.paradigm.xyz | bash && foundryup`
- **jq**: for post-deployment address parsing (`sudo apt install jq` or `brew install jq`)
- **Node.js 18+** (for NatSpec validation and size analysis scripts)

### Environment File

Copy the appropriate template and fill in your values:

```bash
# Localhost development
cp .env.localhost .env

# Base Sepolia testnet
cp .env.base-sepolia .env

# Base mainnet production
cp .env.base .env
```

**Required variables:**

| Variable | Description |
|----------|-------------|
| `PRIVATE_KEY` | Deployer private key |
| `ETHERSCAN_API_KEY` | BaseScan API key (needed for `--verify`) |

**Optional variables (default to deployer address if not set):**

| Variable | Description |
|----------|-------------|
| `TREASURY` | FeeCollector treasury wallet |
| `DEV_FUND` | FeeCollector dev fund wallet |
| `COMMUNITY_FUND` | FeeCollector community fund wallet |
| `SINGLE_HEDGER` | Initial single hedger address on HedgerPool |
| `USDC` | USDC address override (auto-selected by network if not set) |
| `STORK_CONTRACT_ADDRESS` | Stork oracle contract override |

---

## Deployment Architecture

`DeployQuantillon.s.sol` deploys all contracts in this dependency order within a single broadcast session:

```
TimeProvider
    └── ChainlinkOracle (or MockChainlinkOracle) + ERC1967Proxy
    └── StorkOracle (or MockStorkOracle) + ERC1967Proxy
    └── OracleRouter + ERC1967Proxy
            │
            ├── FeeCollector + ERC1967Proxy
            │       └── QEUROToken + ERC1967Proxy
            │               └── QuantillonVault + ERC1967Proxy
            │
            ├── QTIToken + ERC1967Proxy
            │
            ├── UserPool + ERC1967Proxy
            ├── HedgerPool + ERC1967Proxy
            ├── YieldShift + ERC1967Proxy
            ├── stQEUROToken (implementation)
            └── stQEUROFactory + ERC1967Proxy
                    └── _wireContracts() — configures dependencies/roles and enforces required post-deploy wiring (no vault registration)
```

After deployment, addresses are written to `deployments/{chainId}/addresses.json`.

Required post-deploy wiring now enforced in-script (deployment reverts if any check fails):
- `quantillonVault.initializePriceCache()`
- `yieldShift.configureDependencies(...)`
- `yieldShift.bootstrapDefaults()`
- `hedgerPool.configureDependencies(...)` (includes `feeCollector`)
- `feeCollector.authorizeFeeSource(quantillonVault)`
- `feeCollector.authorizeFeeSource(hedgerPool)`

Vault registration is intentionally deferred: `DeployQuantillon.s.sol` does not register any stQEURO vault token or adapter on initialization.
Use `scripts/deployment/setup-external-vaults.sh` for post-core onboarding.

### Network Configuration

| Network | Chain ID | USDC | Stork | Chainlink EUR/USD |
|---------|----------|------|-------|-------------------|
| Localhost (Anvil) | 31337 | Base mainnet USDC or MockUSDC | Mock | Mock (or real on fork) |
| Base Sepolia | 84532 | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` | Mock | `0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165` |
| Base Mainnet | 8453 | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` | `0x647DFd812BC1e116c6992CB2bC353b2112176fD6` | `0xc91D87E81faB8f93699ECf7Ee9B44D11e1D53F0F` |

---

## Localhost Deployment

### Start Anvil

```bash
# Plain local node (all mocks required)
anvil --host 0.0.0.0 --port 8545 --accounts 10 --balance 10000

# Or fork Base mainnet (allows using real oracle feeds without mocks)
anvil --host 0.0.0.0 --port 8545 --fork-url https://mainnet.base.org --chain-id 31337
```

### Deploy

```bash
# All mocks (MockUSDC + MockChainlinkOracle + MockStorkOracle)
./scripts/deployment/deploy.sh localhost --with-mocks

# Mock oracle only (real USDC from fork)
./scripts/deployment/deploy.sh localhost --with-mock-oracle

# No mocks (assumes Base mainnet fork with real contracts)
./scripts/deployment/deploy.sh localhost
```

### Output

```
deployments/31337/addresses.json
```

---

## Testnet Deployment (Base Sepolia)

```bash
# With mock contracts (recommended for testing)
./scripts/deployment/deploy.sh base-sepolia --with-mocks --verify

# With real Chainlink feeds + real USDC
./scripts/deployment/deploy.sh base-sepolia --verify
```

The script automatically:
- Sets gas price to 2 gwei
- Uses `--slow` to send transactions one-at-a-time (avoids nonce desync with public RPCs)
- Polls for stable nonce before broadcasting

### Output

```
deployments/84532/addresses.json
```

---

## Mainnet Deployment (Base)

### Pre-Deployment Checklist

Before deploying to Base mainnet:

- [ ] Set `TREASURY`, `DEV_FUND`, `COMMUNITY_FUND` to governance-controlled multisig addresses in `.env.base`
- [ ] Set `SINGLE_HEDGER` to the authorized hedger address
- [ ] Verify `PRIVATE_KEY` belongs to a dedicated deployment wallet with sufficient ETH
- [ ] Set `ETHERSCAN_API_KEY` for contract verification
- [ ] Run a dry-run first: `./scripts/deployment/deploy.sh base --dry-run`
- [ ] Test on Base Sepolia with the same configuration

### Deploy

```bash
# Production deployment with verification and 1M optimizer runs
./scripts/deployment/deploy.sh base --verify --production
```

The `--production` flag sets `FOUNDRY_PROFILE=production` which uses 1,000,000 optimizer runs (defined in `foundry.toml`).

### Output

```
deployments/8453/addresses.json
```

---

## Dry Run

Test the deployment without broadcasting any transactions:

```bash
./scripts/deployment/deploy.sh localhost --dry-run
./scripts/deployment/deploy.sh base-sepolia --dry-run
./scripts/deployment/deploy.sh base --dry-run
```

---

## Post-Deployment

`deploy.sh` automatically runs these after a successful deployment:

### 1. Copy ABIs to Frontend

```bash
./scripts/deployment/copy-abis.sh localhost
```

Copies all contract JSON artifacts from `out/` to the path specified in `FRONTEND_ABI_DIR`.

### 2. Update Frontend Addresses

```bash
./scripts/deployment/update-frontend-addresses.sh localhost
```

Reads `deployments/{chainId}/addresses.json` and writes the frontend `addresses.json` to `FRONTEND_ADDRESSES_FILE`.

### 3. Onboard External Vaults (Required for Multi-Vault Staking)

Core deploy does not set adapter routing/defaults. Onboard vaults with:

```bash
./scripts/deployment/setup-external-vaults.sh \
  --rpc-url http://localhost:8545 \
  --private-key "$PRIVATE_KEY" \
  --quantillon-vault 0xQuantillonVault \
  --factory 0xStQEUROFactory \
  --yield-shift 0xYieldShift \
  --vault 1:AAVE1:0xMockAaveAdapter \
  --vault 2:MORPHO1:0xMorphoAdapter \
  --default-vault-id 2 \
  --enforce-source-bindings
```

See the dedicated runbook: `docs/External-Vault-Onboarding-Runbook.md`.

---

## Accessing Deployed Addresses

### Programmatically (shell)

```bash
jq '.qeuroToken' deployments/31337/addresses.json
# "0x..."
```

### Frontend format (`addresses.json`)

```json
{
  "31337": {
    "name": "Anvil Localhost",
    "isTestnet": true,
    "contracts": {
      "timeProvider": "0x...",
      "chainlinkOracle": "0x...",
      "storkOracle": "0x...",
      "oracleRouter": "0x...",
      "feeCollector": "0x...",
      "qeuroToken": "0x...",
      "quantillonVault": "0x...",
      "qtiToken": "0x...",
      "stQEUROFactory": "0x...",
      "stQeuroToken": "0x...",
      "userPool": "0x...",
      "hedgerPool": "0x...",
      "yieldShift": "0x..."
    }
  }
}
```

---

## Contract Verification

Contracts are verified automatically when `--verify` is passed. For manual re-verification:

```bash
# Example: re-verify QEUROToken proxy on Base Sepolia
forge verify-contract \
  <PROXY_ADDRESS> \
  lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy \
  --chain-id 84532 \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

---

## Troubleshooting

### Anvil not running
```bash
anvil --host 0.0.0.0 --port 8545 --accounts 10 --balance 10000
```

### Missing environment file
```bash
cp .env.localhost .env
# or
cp .env.base-sepolia .env
```

### Nonce desync on testnet
The deploy script polls for a stable nonce before broadcasting. If it keeps failing, try a different RPC URL (the default `https://sepolia.base.org` can occasionally lag). You can override by editing the `NETWORKS` map in `deploy.sh`.

### Verification failed
Ensure `ETHERSCAN_API_KEY` is set and valid. If automatic verification fails, contracts can be re-verified using `forge verify-contract` after deployment.

### USDC address is zero on localhost
Set `USDC=<mock_address>` in `.env.localhost` after deploying MockUSDC, or let deploy.sh handle it automatically with `--with-mock-usdc`.

---

## Security Considerations

### Private Key Management
- Use a **dedicated deployment wallet** — never your main wallet
- For production, use a hardware wallet or a cloud HSM
- Rotate deployment keys after production deployment

### Production Role Configuration
- `TREASURY`, `DEV_FUND`, and `COMMUNITY_FUND` should be multisig wallets (e.g., Safe)
- `SINGLE_HEDGER` should be an audited, authorized hedger address
- After deployment, transfer admin roles to the governance multisig

### Never Commit Secrets
- All `.env*` files are in `.gitignore`
- Use a secret manager (AWS Secrets Manager, HashiCorp Vault) for production CI/CD

---

*Maintained by Quantillon Labs. See [scripts/README.md](../scripts/README.md) for the complete deployment script reference.*
