# Quantillon Protocol Quick Start Guide

## Getting Started

This guide will help you quickly integrate with the Quantillon Protocol smart contracts.

---

## Prerequisites

- Node.js 18+ and npm/yarn
- Web3 library (web3.js, ethers.js, or web3.py)
- Ethereum wallet (MetaMask, WalletConnect, etc.)
- USDC tokens for testing

---

## Installation

### JavaScript/TypeScript

```bash
npm install ethers
# or
yarn add ethers
```

### Python

```bash
pip install web3
```

---

## Basic Integration

### 1. Connect to the Protocol

```javascript
import { ethers } from 'ethers';

// Contract ABIs: build the repo (`forge build`) and read `out/<Contract>.sol/<Contract>.json`,
// or use the committed signature baselines in `abi-baseline/*.abisig`.
import QuantillonVaultABI from './abis/QuantillonVault.json';
import QEUROTokenABI from './abis/QEUROToken.json';
import UserPoolABI from './abis/UserPool.json';

// Initialize contracts
const vault = new ethers.Contract(vaultAddress, QuantillonVaultABI, provider);
const qeuro = new ethers.Contract(qeuroAddress, QEUROTokenABI, provider);
const userPool = new ethers.Contract(userPoolAddress, UserPoolABI, provider);
```

### 2. Mint QEURO

```javascript
// Approve USDC spending
await usdc.approve(vaultAddress, usdcAmount);

// Mint QEURO with slippage protection. QEURO is 18 decimals and USDC 6 decimals,
// so quote with calculateMintAmount instead of scaling usdcAmount.
const [expectedQeuro] = await vault.calculateMintAmount(usdcAmount);
const minQeuroOut = expectedQeuro.mul(95).div(100); // 5% slippage tolerance
await vault.mintQEURO(usdcAmount, minQeuroOut);
```

### 3. Stake QEURO for Rewards

```javascript
// Approve QEURO spending
await qeuro.approve(userPoolAddress, qeuroAmount);

// Stake QEURO (UserPool functions take arrays; one element for a single stake)
await userPool.stake([qeuroAmount]);

// Note: there is no staking-reward claim. Protocol yield accrues automatically
// through the stQEURO wrapper (its exchange rate rises) — wrap QEURO into stQEURO to earn it.
```

### 4. Participate in Governance

> QTI is dormant on Base mainnet: no mint path is wired, so the supply is 0 and these calls cannot be exercised until an activation upgrade. Shown for the as-coded API.

```javascript
// Lock QTI for voting power
await qti.lock(lockAmount, lockDuration);

// Create a proposal
const proposalId = await qti.createProposal(
    "Update protocol parameters",
    startTime,
    endTime
);

// Vote on proposal
await qti.vote(proposalId, true); // Vote yes
```

---

## Common Patterns

### Error Handling

```javascript
try {
    await vault.mintQEURO(usdcAmount, minQeuroOut);
} catch (error) {
    // Reverts are custom errors (see API-Reference "Error Handling")
    const msg = error.reason || error.message;
    if (msg.includes('ERC20InsufficientBalance') || msg.includes('InsufficientBalance')) {
        console.log('Insufficient USDC balance');
    } else if (msg.includes('InvalidOraclePrice')) {
        console.log('Oracle price is stale or invalid');
    } else if (msg.includes('ExcessiveSlippage')) {
        console.log('Output below minQeuroOut; re-quote and retry');
    } else {
        console.log('Transaction failed:', msg);
    }
}
```

### Event Listening

```javascript
// Listen for mint events (event name is QEUROminted — lowercase m — with 3 arguments)
vault.on('QEUROminted', (user, usdcAmount, qeuroAmount) => {
    console.log(`User ${user} minted ${qeuroAmount} QEURO for ${usdcAmount} USDC`);
});

// Listen for stake events (3 arguments)
userPool.on('QEUROStaked', (user, qeuroAmount, timestamp) => {
    console.log(`User ${user} staked ${qeuroAmount} QEURO at ${timestamp}`);
});
```

### Batch Operations

Dependent transactions must be sent sequentially (an approval has to be mined before the transfer that consumes it). Native batching exists where it matters: `UserPool.deposit` / `withdraw` / `stake` accept arrays.

```javascript
// Sequential: approve -> mint -> approve -> stake
await (await usdc.approve(vaultAddress, usdcAmount)).wait();
await (await vault.mintQEURO(usdcAmount, minQeuroOut)).wait();
await (await qeuro.approve(userPoolAddress, qeuroAmountA.add(qeuroAmountB))).wait();

// One transaction, two stakes (each entry must be >= userPool.minStakeAmount())
await (await userPool.stake([qeuroAmountA, qeuroAmountB])).wait();
```

---

## Testing

### Local Development

```bash
# Clone the repository
git clone https://github.com/Quantillon-Labs/smart-contracts.git
cd smart-contracts/quantillon-protocol

# Install dependencies
forge install

# Build contracts
forge build

# Run tests
forge test

# Run specific test
forge test --match-contract QEUROToken

# Run security analysis
make security  # Runs both Slither and Mythril
```

---

## Security Best Practices

### 1. Always Validate Inputs

```javascript
// Validate amounts
if (usdcAmount <= 0) {
    throw new Error('Invalid USDC amount');
}

// Validate addresses
if (!ethers.utils.isAddress(userAddress)) {
    throw new Error('Invalid address');
}
```

### 2. Use Slippage Protection

```javascript
// Calculate minimum output with slippage
const slippage = 0.05; // 5%
const minQeuroOut = expectedQeuro * (1 - slippage);
```

### 3. Check Contract State

```javascript
// Check if contract is paused
const isPaused = await vault.paused();
if (isPaused) {
    throw new Error('Contract is paused');
}

// Check oracle price freshness. OracleRouter.getEurUsdPrice() is NOT a view (a fresh read
// updates the deviation baseline), so simulate it instead of sending a transaction.
const [price, isValid] = await oracleRouter.callStatic.getEurUsdPrice();
if (!isValid) {
    throw new Error('Oracle price is invalid');
}
```

### 4. Implement Proper Error Handling

```javascript
// Retry mechanism for failed transactions
async function retryTransaction(txFunction, maxRetries = 3) {
    for (let i = 0; i < maxRetries; i++) {
        try {
            return await txFunction();
        } catch (error) {
            if (i === maxRetries - 1) throw error;
            await new Promise(resolve => setTimeout(resolve, 1000 * (i + 1)));
        }
    }
}
```

### 5. Security Analysis

```bash
# Run comprehensive security analysis
make security

# Run individual tools
make slither    # Static analysis
make mythril    # Symbolic execution analysis

# Check security reports
ls scripts/results/mythril-reports/   # Mythril reports
ls scripts/results/slither/           # Slither reports
cat scripts/results/natspec-validation-report.txt
cat scripts/results/contract-sizes/contract-sizes-summary.txt
```

---

## Advanced Features

### Yield Optimization

```javascript
// Check yield opportunities
const userPoolAPY = await userPool.stakingAPY(); // bps, e.g. 800 = 8%

// Hedger economics derive from the EUR/USD interest-rate differential
// (there is no APY getter on HedgerPool)
const params = await hedgerPool.coreParams();
const hedgerCarryBps = params.usdInterestRate - params.eurInterestRate; // bps

if (userPoolAPY > hedgerCarryBps) {
    // Stake in user pool (array argument)
    await userPool.stake([qeuroAmount]);
} else {
    // Open hedge position (single-hedger model: caller must be the configured hedger)
    await hedgerPool.enterHedgePosition(marginAmount, leverage);
}
```

### Risk Management

```javascript
// Monitor position health
const positionInfo = await hedgerPool.positions(positionId);
const marginRatioBps = positionInfo.margin.mul(10000).div(positionInfo.positionSize);
const minMarginRatioBps = (await hedgerPool.coreParams()).minMarginRatio; // bps, governance-set: 250 = 2.5% live (since 2026-09-02); 500 at launch

if (marginRatioBps.lt(minMarginRatioBps.add(100))) {
    console.warn('Position is near the minimum margin ratio');
    // Add margin or close position
}
// Note: protocol-level liquidation mode triggers at vault CR <= 101%
// (QuantillonVault.criticalCollateralizationRatio), independent of per-position margin.
```

### Governance Participation

> QTI is dormant on Base mainnet (supply 0, no mint path wired): these calls become functional only after an activation upgrade.

```javascript
// Check voting power
const votingPower = await qti.getVotingPower(userAddress);
const minPower = await qti.proposalThreshold(); // 100,000 QTI

if (votingPower >= minPower) {
    // Can create proposals
    const proposalId = await qti.createProposal(description, startTime, endTime);
}
```

---

## Troubleshooting

### Common Issues

1. **`ERC20InsufficientAllowance` revert**
   - Solution: Approve token spending before calling functions

2. **`EnforcedPause` revert**
   - Solution: the contract is paused; wait for it to be unpaused or check with the protocol team

3. **`InvalidOraclePrice` revert**
   - Solution: the active oracle returned `isValid = false` (stale, out of bounds or circuit breaker). Check `OracleRouter.getOracleHealth()` and wait for a fresh publish

4. **"Gas estimation failed"**
   - Solution: Increase gas limit or check transaction parameters

---

## Support

### Resources

- **Documentation**: [docs.quantillon.money](https://docs.quantillon.money)
- **GitHub**: [github.com/Quantillon-Labs](https://github.com/Quantillon-Labs)
- **Discord**: [discord.gg/uk8T9GqdE5](https://discord.gg/uk8T9GqdE5)
- **Email**: team@quantillon.money

### Community

- **Telegram**: [t.me/QuantillonLabs](https://t.me/QuantillonLabs)
- **X (Twitter)**: [@QuantillonLabs](https://x.com/QuantillonLabs)
- **Medium**: [medium.com/@quantillonlabs](https://medium.com/@quantillonlabs)

---

## Examples

### Complete Integration Example

```javascript
import { ethers } from 'ethers';

class QuantillonIntegration {
    constructor(provider, signer) {
        this.provider = provider;
        this.signer = signer;
        this.vault = new ethers.Contract(VAULT_ADDRESS, QuantillonVaultABI, signer);
        this.qeuro = new ethers.Contract(QEURO_ADDRESS, QEUROTokenABI, signer);
        this.userPool = new ethers.Contract(USER_POOL_ADDRESS, UserPoolABI, signer);
    }

    async mintQEURO(usdcAmount, slippage = 0.05) {
        try {
            // Check contract state
            if (await this.vault.paused()) {
                throw new Error('Contract is paused');
            }

            // Calculate minimum output (calculateMintAmount returns (qeuroAmount, fee))
            const [expectedQeuro] = await this.vault.calculateMintAmount(usdcAmount);
            const minQeuroOut = expectedQeuro.mul(100 - slippage * 100).div(100);

            // Approve USDC spending
            const usdc = new ethers.Contract(USDC_ADDRESS, USDC_ABI, this.signer);
            await usdc.approve(VAULT_ADDRESS, usdcAmount);

            // Mint QEURO
            const tx = await this.vault.mintQEURO(usdcAmount, minQeuroOut);
            await tx.wait();

            console.log('QEURO minted successfully');
            return tx;
        } catch (error) {
            console.error('Minting failed:', error.message);
            throw error;
        }
    }

    async stakeQEURO(qeuroAmount) {
        try {
            // Approve QEURO spending
            await this.qeuro.approve(USER_POOL_ADDRESS, qeuroAmount);

            // Stake QEURO (array argument; one element for a single stake)
            const tx = await this.userPool.stake([qeuroAmount]);
            await tx.wait();

            console.log('QEURO staked successfully');
            return tx;
        } catch (error) {
            console.error('Staking failed:', error.message);
            throw error;
        }
    }

    async getPortfolio(userAddress) {
        try {
            const [collateralizationRatio, totalUsdcHeld, totalMinted, userInfo, qeuroBalance] = await Promise.all([
                this.vault.getProtocolCollateralizationRatio(), // 1e20 == 100%
                this.vault.totalUsdcHeld(),
                this.vault.totalMinted(),
                this.userPool.getUserInfo(userAddress),
                this.qeuro.balanceOf(userAddress)
            ]);

            return {
                qeuroBalance: qeuroBalance.toString(),
                stakedAmount: userInfo.stakedAmount.toString(),
                pendingUnstake: userInfo.unstakeAmount.toString(),
                depositHistoryUsdc: userInfo.depositHistory.toString(),
                vault: {
                    usdcHeld: totalUsdcHeld.toString(),
                    qeuroMinted: totalMinted.toString(),
                    collateralizationRatioPct: ethers.utils.formatEther(collateralizationRatio)
                }
            };
        } catch (error) {
            console.error('Failed to get portfolio:', error.message);
            throw error;
        }
    }
}

// Usage
const integration = new QuantillonIntegration(provider, signer);
await integration.mintQEURO(ethers.utils.parseUnits('1000', 6)); // 1000 USDC
await integration.stakeQEURO(ethers.utils.parseUnits('500', 18)); // 500 QEURO
const portfolio = await integration.getPortfolio(userAddress);
```

---

*This quick start guide is maintained by Quantillon Labs and updated regularly.*
