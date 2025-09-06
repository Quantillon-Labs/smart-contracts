# Quantillon Protocol Quick Start Guide

## Getting Started

This guide will help you quickly integrate with the Quantillon Protocol smart contracts.

---

## Prerequisites

- Node.js 16+ and npm/yarn
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

// Contract ABIs (you'll need to import these from the compiled contracts)
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

// Mint QEURO with slippage protection
const minQeuroOut = usdcAmount * 0.95; // 5% slippage tolerance
await vault.mintQEURO(usdcAmount, minQeuroOut);
```

### 3. Stake QEURO for Rewards

```javascript
// Approve QEURO spending
await qeuro.approve(userPoolAddress, qeuroAmount);

// Stake QEURO
await userPool.stake(qeuroAmount);

// Claim rewards later
const rewards = await userPool.claimStakingRewards();
```

### 4. Participate in Governance

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
    if (error.message.includes('InsufficientBalance')) {
        console.log('Insufficient USDC balance');
    } else if (error.message.includes('StalePrice')) {
        console.log('Oracle price is stale');
    } else {
        console.log('Transaction failed:', error.message);
    }
}
```

### Event Listening

```javascript
// Listen for mint events
vault.on('QEUROMinted', (user, usdcAmount, qeuroAmount, price) => {
    console.log(`User ${user} minted ${qeuroAmount} QEURO for ${usdcAmount} USDC`);
});

// Listen for stake events
userPool.on('QEUROStaked', (user, amount) => {
    console.log(`User ${user} staked ${amount} QEURO`);
});
```

### Batch Operations

```javascript
// Batch multiple operations
const batch = [
    usdc.approve(vaultAddress, usdcAmount),
    vault.mintQEURO(usdcAmount, minQeuroOut),
    qeuro.approve(userPoolAddress, qeuroAmount),
    userPool.stake(qeuroAmount)
];

await Promise.all(batch);
```

---

## Testing

### Local Development

```bash
# Clone the repository
git clone https://github.com/Quantillon-Labs/smart-contracts.git
cd smart-contracts/quantillon-protocol

# Install dependencies
npm install

# Run tests
npm test

# Run specific test
npm test -- --grep "mintQEURO"
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

// Check oracle price freshness
const [price, isValid] = await oracle.getEurUsdPrice();
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

---

## Advanced Features

### Yield Optimization

```javascript
// Check yield opportunities
const userPoolAPY = await userPool.getStakingAPY();
const hedgerPoolAPY = await hedgerPool.getHedgingAPY();

if (userPoolAPY > hedgerPoolAPY) {
    // Stake in user pool
    await userPool.stake(qeuroAmount);
} else {
    // Open hedge position
    await hedgerPool.enterHedgePosition(marginAmount, leverage);
}
```

### Risk Management

```javascript
// Monitor position health
const positionInfo = await hedgerPool.getPositionInfo(positionId);
const marginRatio = positionInfo.margin / positionInfo.positionSize;

if (marginRatio < 1.1) {
    console.warn('Position is near liquidation threshold');
    // Add margin or close position
}
```

### Governance Participation

```javascript
// Check voting power
const votingPower = await qti.getVotingPower(userAddress);
const minPower = await qti.MIN_PROPOSAL_POWER();

if (votingPower >= minPower) {
    // Can create proposals
    const proposalId = await qti.createProposal(description, startTime, endTime);
}
```

---

## Troubleshooting

### Common Issues

1. **"Insufficient allowance"**
   - Solution: Approve token spending before calling functions

2. **"Contract paused"**
   - Solution: Wait for contract to be unpaused or check with protocol team

3. **"Stale oracle price"**
   - Solution: Wait for oracle to update or check oracle configuration

4. **"Gas estimation failed"**
   - Solution: Increase gas limit or check transaction parameters

### Debug Mode

```javascript
// Enable debug logging
const vault = new QuantillonVault(vaultAddress, provider, { debug: true });

// Check transaction details
const tx = await vault.mintQEURO(usdcAmount, minQeuroOut);
console.log('Transaction hash:', tx.hash);
console.log('Gas used:', tx.gasUsed);
```

---

## Support

### Resources

- **Documentation**: [docs.quantillon.money](https://docs.quantillon.money)
- **GitHub**: [github.com/Quantillon-Labs](https://github.com/Quantillon-Labs)
- **Discord**: [discord.gg/uk8T9GqdE5](https://discord.gg/uk8T9GqdE5)
- **Email**: team@quantillon.money

### Community

- **Telegram**: [t.me/quantillon](https://t.me/quantillon)
- **Twitter**: [@QuantillonLabs](https://twitter.com/QuantillonLabs)
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

            // Calculate minimum output
            const expectedQeuro = await this.vault.calculateMintAmount(usdcAmount);
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

            // Stake QEURO
            const tx = await this.userPool.stake(qeuroAmount);
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
            const [vaultMetrics, userInfo, qeuroBalance] = await Promise.all([
                this.vault.getVaultMetrics(),
                this.userPool.getUserInfo(userAddress),
                this.qeuro.balanceOf(userAddress)
            ]);

            return {
                qeuroBalance: qeuroBalance.toString(),
                stakedAmount: userInfo.stakedQeuro.toString(),
                pendingRewards: userInfo.pendingRewards.toString(),
                totalDeposits: userInfo.depositedUsdc.toString(),
                vaultMetrics: {
                    totalReserves: vaultMetrics.totalUsdcReserves.toString(),
                    totalSupply: vaultMetrics.totalQeuroSupply.toString(),
                    collateralizationRatio: vaultMetrics.collateralizationRatio.toString()
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
