# Quantillon Protocol Integration Examples

This document provides practical integration examples for common use cases with the Quantillon Protocol.

---

## Table of Contents

1. [Basic QEURO Operations](#basic-qeuro-operations)
2. [Staking and Yield Generation](#staking-and-yield-generation)
3. [Governance Participation](#governance-participation)
4. [Hedging Operations](#hedging-operations)
5. [Advanced Integration Patterns](#advanced-integration-patterns)
6. [Error Handling and Recovery](#error-handling-and-recovery)

---

## Basic QEURO Operations

### Minting QEURO from USDC

```javascript
const { ethers } = require('ethers');

async function mintQEURO(usdcAmount, slippage = 0.05) {
    // Initialize contracts
    const vault = new ethers.Contract(VAULT_ADDRESS, VAULT_ABI, signer);
    const usdc = new ethers.Contract(USDC_ADDRESS, USDC_ABI, signer);
    
    try {
        // 1. Check vault state
        const isPaused = await vault.paused();
        if (isPaused) {
            throw new Error('Vault is paused');
        }
        
        // 2. Calculate expected output
        const expectedQeuro = await vault.calculateMintAmount(usdcAmount);
        const minQeuroOut = expectedQeuro.mul(100 - slippage * 100).div(100);
        
        // 3. Approve USDC spending
        const approveTx = await usdc.approve(VAULT_ADDRESS, usdcAmount);
        await approveTx.wait();
        
        // 4. Mint QEURO
        const mintTx = await vault.mintQEURO(usdcAmount, minQeuroOut);
        const receipt = await mintTx.wait();
        
        // 5. Parse events
        const mintEvent = receipt.events.find(e => e.event === 'QEUROMinted');
        console.log(`Minted ${mintEvent.args.qeuroAmount} QEURO for ${mintEvent.args.usdcAmount} USDC`);
        
        return receipt;
    } catch (error) {
        console.error('Minting failed:', error.message);
        throw error;
    }
}

// Usage
const usdcAmount = ethers.utils.parseUnits('1000', 6); // 1000 USDC
await mintQEURO(usdcAmount, 0.05); // 5% slippage tolerance
```

### Redeeming QEURO for USDC

```javascript
async function redeemQEURO(qeuroAmount, slippage = 0.05) {
    const vault = new ethers.Contract(VAULT_ADDRESS, VAULT_ABI, signer);
    const qeuro = new ethers.Contract(QEURO_ADDRESS, QEURO_ABI, signer);
    
    try {
        // 1. Calculate expected output
        const expectedUsdc = await vault.calculateRedeemAmount(qeuroAmount);
        const minUsdcOut = expectedUsdc.mul(100 - slippage * 100).div(100);
        
        // 2. Approve QEURO spending
        const approveTx = await qeuro.approve(VAULT_ADDRESS, qeuroAmount);
        await approveTx.wait();
        
        // 3. Redeem QEURO
        const redeemTx = await vault.redeemQEURO(qeuroAmount, minUsdcOut);
        const receipt = await redeemTx.wait();
        
        // 4. Parse events
        const redeemEvent = receipt.events.find(e => e.event === 'QEURORedeemed');
        console.log(`Redeemed ${redeemEvent.args.qeuroAmount} QEURO for ${redeemEvent.args.usdcAmount} USDC`);
        
        return receipt;
    } catch (error) {
        console.error('Redemption failed:', error.message);
        throw error;
    }
}
```

---

## Staking and Yield Generation

### Staking QEURO in User Pool

```javascript
async function stakeQEURO(qeuroAmount) {
    const userPool = new ethers.Contract(USER_POOL_ADDRESS, USER_POOL_ABI, signer);
    const qeuro = new ethers.Contract(QEURO_ADDRESS, QEURO_ABI, signer);
    
    try {
        // 1. Check minimum stake amount
        const minStakeAmount = await userPool.MIN_STAKE_AMOUNT();
        if (qeuroAmount.lt(minStakeAmount)) {
            throw new Error(`Amount below minimum stake: ${minStakeAmount}`);
        }
        
        // 2. Check user's QEURO balance
        const balance = await qeuro.balanceOf(signer.address);
        if (balance.lt(qeuroAmount)) {
            throw new Error('Insufficient QEURO balance');
        }
        
        // 3. Approve QEURO spending
        const approveTx = await qeuro.approve(USER_POOL_ADDRESS, qeuroAmount);
        await approveTx.wait();
        
        // 4. Stake QEURO
        const stakeTx = await userPool.stake(qeuroAmount);
        const receipt = await stakeTx.wait();
        
        console.log(`Staked ${qeuroAmount} QEURO successfully`);
        return receipt;
    } catch (error) {
        console.error('Staking failed:', error.message);
        throw error;
    }
}
```

### Claiming Staking Rewards

```javascript
async function claimStakingRewards() {
    const userPool = new ethers.Contract(USER_POOL_ADDRESS, USER_POOL_ABI, signer);
    
    try {
        // 1. Check pending rewards
        const userInfo = await userPool.getUserInfo(signer.address);
        const pendingRewards = userInfo.pendingRewards;
        
        if (pendingRewards.eq(0)) {
            console.log('No rewards to claim');
            return null;
        }
        
        // 2. Claim rewards
        const claimTx = await userPool.claimStakingRewards();
        const receipt = await claimTx.wait();
        
        // 3. Parse events
        const claimEvent = receipt.events.find(e => e.event === 'RewardsClaimed');
        console.log(`Claimed ${claimEvent.args.amount} QEURO rewards`);
        
        return receipt;
    } catch (error) {
        console.error('Claiming rewards failed:', error.message);
        throw error;
    }
}
```

### Staking in stQEURO Token

```javascript
async function stakeInStQEURO(qeuroAmount) {
    const stQeuro = new ethers.Contract(ST_QEURO_ADDRESS, ST_QEURO_ABI, signer);
    const qeuro = new ethers.Contract(QEURO_ADDRESS, QEURO_ABI, signer);
    
    try {
        // 1. Get current exchange rate
        const exchangeRate = await stQeuro.getExchangeRate();
        const expectedStQeuro = qeuroAmount.mul(ethers.utils.parseEther('1')).div(exchangeRate);
        
        // 2. Approve QEURO spending
        const approveTx = await qeuro.approve(ST_QEURO_ADDRESS, qeuroAmount);
        await approveTx.wait();
        
        // 3. Stake QEURO
        const stakeTx = await stQeuro.stake(qeuroAmount);
        const receipt = await stakeTx.wait();
        
        console.log(`Staked ${qeuroAmount} QEURO, received ${expectedStQeuro} stQEURO`);
        return receipt;
    } catch (error) {
        console.error('stQEURO staking failed:', error.message);
        throw error;
    }
}
```

---

## Governance Participation

### Locking QTI for Voting Power

```javascript
async function lockQTI(amount, lockDuration) {
    const qti = new ethers.Contract(QTI_ADDRESS, QTI_ABI, signer);
    
    try {
        // 1. Check lock duration limits
        const minLockTime = await qti.MIN_LOCK_TIME();
        const maxLockTime = await qti.MAX_LOCK_TIME();
        
        if (lockDuration.lt(minLockTime) || lockDuration.gt(maxLockTime)) {
            throw new Error(`Lock duration must be between ${minLockTime} and ${maxLockTime} seconds`);
        }
        
        // 2. Check QTI balance
        const balance = await qti.balanceOf(signer.address);
        if (balance.lt(amount)) {
            throw new Error('Insufficient QTI balance');
        }
        
        // 3. Lock QTI
        const lockTx = await qti.lock(amount, lockDuration);
        const receipt = await lockTx.wait();
        
        // 4. Parse events
        const lockEvent = receipt.events.find(e => e.event === 'TokensLocked');
        console.log(`Locked ${amount} QTI for ${lockDuration} seconds, received ${lockEvent.args.votingPower} veQTI`);
        
        return receipt;
    } catch (error) {
        console.error('QTI locking failed:', error.message);
        throw error;
    }
}
```

### Creating a Governance Proposal

```javascript
async function createProposal(description, startTime, endTime) {
    const qti = new ethers.Contract(QTI_ADDRESS, QTI_ABI, signer);
    
    try {
        // 1. Check voting power
        const votingPower = await qti.getVotingPower(signer.address);
        const minProposalPower = await qti.MIN_PROPOSAL_POWER();
        
        if (votingPower.lt(minProposalPower)) {
            throw new Error(`Insufficient voting power. Required: ${minProposalPower}, Current: ${votingPower}`);
        }
        
        // 2. Validate time parameters
        const currentTime = Math.floor(Date.now() / 1000);
        if (startTime <= currentTime || endTime <= startTime) {
            throw new Error('Invalid time parameters');
        }
        
        // 3. Create proposal
        const proposalTx = await qti.createProposal(description, startTime, endTime);
        const receipt = await proposalTx.wait();
        
        // 4. Parse events
        const proposalEvent = receipt.events.find(e => e.event === 'ProposalCreated');
        console.log(`Created proposal ${proposalEvent.args.proposalId}: ${description}`);
        
        return proposalEvent.args.proposalId;
    } catch (error) {
        console.error('Proposal creation failed:', error.message);
        throw error;
    }
}
```

### Voting on Proposals

```javascript
async function voteOnProposal(proposalId, support) {
    const qti = new ethers.Contract(QTI_ADDRESS, QTI_ABI, signer);
    
    try {
        // 1. Check voting power
        const votingPower = await qti.getVotingPower(signer.address);
        if (votingPower.eq(0)) {
            throw new Error('No voting power available');
        }
        
        // 2. Check if already voted
        const hasVoted = await qti.hasVoted(proposalId, signer.address);
        if (hasVoted) {
            throw new Error('Already voted on this proposal');
        }
        
        // 3. Vote
        const voteTx = await qti.vote(proposalId, support);
        const receipt = await voteTx.wait();
        
        // 4. Parse events
        const voteEvent = receipt.events.find(e => e.event === 'VoteCast');
        console.log(`Voted ${support ? 'YES' : 'NO'} on proposal ${proposalId} with ${voteEvent.args.votingPower} voting power`);
        
        return receipt;
    } catch (error) {
        console.error('Voting failed:', error.message);
        throw error;
    }
}
```

---

## Hedging Operations

### Opening a Hedge Position

```javascript
async function openHedgePosition(marginAmount, leverage) {
    const hedgerPool = new ethers.Contract(HEDGER_POOL_ADDRESS, HEDGER_POOL_ABI, signer);
    const usdc = new ethers.Contract(USDC_ADDRESS, USDC_ABI, signer);
    
    try {
        // 1. Validate leverage
        const maxLeverage = await hedgerPool.maxLeverage();
        if (leverage.lt(1) || leverage.gt(maxLeverage)) {
            throw new Error(`Leverage must be between 1 and ${maxLeverage}`);
        }
        
        // 2. Check USDC balance
        const balance = await usdc.balanceOf(signer.address);
        if (balance.lt(marginAmount)) {
            throw new Error('Insufficient USDC balance');
        }
        
        // 3. Approve USDC spending
        const approveTx = await usdc.approve(HEDGER_POOL_ADDRESS, marginAmount);
        await approveTx.wait();
        
        // 4. Open position
        const openTx = await hedgerPool.enterHedgePosition(marginAmount, leverage);
        const receipt = await openTx.wait();
        
        // 5. Parse events
        const openEvent = receipt.events.find(e => e.event === 'HedgePositionOpened');
        console.log(`Opened position ${openEvent.args.positionId} with ${marginAmount} USDC margin and ${leverage}x leverage`);
        
        return openEvent.args.positionId;
    } catch (error) {
        console.error('Opening position failed:', error.message);
        throw error;
    }
}
```

### Monitoring Position Health

```javascript
async function monitorPosition(positionId) {
    const hedgerPool = new ethers.Contract(HEDGER_POOL_ADDRESS, HEDGER_POOL_ABI, signer);
    
    try {
        // 1. Get position info
        const positionInfo = await hedgerPool.getPositionInfo(positionId);
        
        // 2. Calculate margin ratio
        const marginRatio = positionInfo.margin.mul(10000).div(positionInfo.positionSize);
        const liquidationThreshold = await hedgerPool.liquidationThreshold();
        
        // 3. Check if position is healthy
        const isHealthy = marginRatio.gt(liquidationThreshold);
        
        console.log(`Position ${positionId}:`);
        console.log(`  Margin: ${ethers.utils.formatUnits(positionInfo.margin, 6)} USDC`);
        console.log(`  Position Size: ${ethers.utils.formatUnits(positionInfo.positionSize, 6)} USDC`);
        console.log(`  Margin Ratio: ${marginRatio.toNumber() / 100}%`);
        console.log(`  Unrealized PnL: ${ethers.utils.formatEther(positionInfo.unrealizedPnL)} QEURO`);
        console.log(`  Status: ${isHealthy ? 'HEALTHY' : 'AT RISK'}`);
        
        return {
            positionInfo,
            marginRatio,
            isHealthy
        };
    } catch (error) {
        console.error('Position monitoring failed:', error.message);
        throw error;
    }
}
```

### Adding Margin to Position

```javascript
async function addMargin(positionId, additionalMargin) {
    const hedgerPool = new ethers.Contract(HEDGER_POOL_ADDRESS, HEDGER_POOL_ABI, signer);
    const usdc = new ethers.Contract(USDC_ADDRESS, USDC_ABI, signer);
    
    try {
        // 1. Check position ownership
        const positionInfo = await hedgerPool.getPositionInfo(positionId);
        if (positionInfo.hedger !== signer.address) {
            throw new Error('Not the owner of this position');
        }
        
        // 2. Check USDC balance
        const balance = await usdc.balanceOf(signer.address);
        if (balance.lt(additionalMargin)) {
            throw new Error('Insufficient USDC balance');
        }
        
        // 3. Approve USDC spending
        const approveTx = await usdc.approve(HEDGER_POOL_ADDRESS, additionalMargin);
        await approveTx.wait();
        
        // 4. Add margin
        const addMarginTx = await hedgerPool.addMargin(positionId, additionalMargin);
        const receipt = await addMarginTx.wait();
        
        console.log(`Added ${ethers.utils.formatUnits(additionalMargin, 6)} USDC margin to position ${positionId}`);
        return receipt;
    } catch (error) {
        console.error('Adding margin failed:', error.message);
        throw error;
    }
}
```

---

## Advanced Integration Patterns

### Portfolio Management

```javascript
class QuantillonPortfolio {
    constructor(provider, signer) {
        this.provider = provider;
        this.signer = signer;
        this.vault = new ethers.Contract(VAULT_ADDRESS, VAULT_ABI, signer);
        this.qeuro = new ethers.Contract(QEURO_ADDRESS, QEURO_ABI, signer);
        this.userPool = new ethers.Contract(USER_POOL_ADDRESS, USER_POOL_ABI, signer);
        this.hedgerPool = new ethers.Contract(HEDGER_POOL_ADDRESS, HEDGER_POOL_ABI, signer);
    }
    
    async getPortfolioOverview() {
        const address = this.signer.address;
        
        try {
            const [
                qeuroBalance,
                userInfo,
                vaultMetrics,
                positions
            ] = await Promise.all([
                this.qeuro.balanceOf(address),
                this.userPool.getUserInfo(address),
                this.vault.getVaultMetrics(),
                this.getUserPositions()
            ]);
            
            return {
                balances: {
                    qeuro: ethers.utils.formatEther(qeuroBalance),
                    staked: ethers.utils.formatEther(userInfo.stakedQeuro),
                    deposited: ethers.utils.formatUnits(userInfo.depositedUsdc, 6)
                },
                rewards: {
                    pending: ethers.utils.formatEther(userInfo.pendingRewards),
                    claimed: ethers.utils.formatEther(userInfo.totalRewardsClaimed)
                },
                positions: positions,
                vault: {
                    totalReserves: ethers.utils.formatUnits(vaultMetrics.totalUsdcReserves, 6),
                    totalSupply: ethers.utils.formatEther(vaultMetrics.totalQeuroSupply),
                    collateralizationRatio: vaultMetrics.collateralizationRatio.toNumber() / 100
                }
            };
        } catch (error) {
            console.error('Failed to get portfolio overview:', error.message);
            throw error;
        }
    }
    
    async getUserPositions() {
        // Implementation to get user's hedge positions
        // This would require tracking position IDs or using events
        return [];
    }
    
    async optimizeYield() {
        try {
            const userPoolAPY = await this.userPool.getStakingAPY();
            const hedgerPoolAPY = await this.hedgerPool.getHedgingAPY();
            
            console.log(`User Pool APY: ${userPoolAPY.toNumber() / 100}%`);
            console.log(`Hedger Pool APY: ${hedgerPoolAPY.toNumber() / 100}%`);
            
            if (userPoolAPY.gt(hedgerPoolAPY)) {
                console.log('Recommendation: Stake in User Pool for higher yield');
            } else {
                console.log('Recommendation: Consider hedging for higher yield');
            }
        } catch (error) {
            console.error('Yield optimization failed:', error.message);
            throw error;
        }
    }
}

// Usage
const portfolio = new QuantillonPortfolio(provider, signer);
const overview = await portfolio.getPortfolioOverview();
console.log('Portfolio Overview:', overview);
await portfolio.optimizeYield();
```

### Automated Yield Management

```javascript
class YieldManager {
    constructor(provider, signer) {
        this.provider = provider;
        this.signer = signer;
        this.yieldShift = new ethers.Contract(YIELD_SHIFT_ADDRESS, YIELD_SHIFT_ABI, signer);
        this.aaveVault = new ethers.Contract(AAVE_VAULT_ADDRESS, AAVE_VAULT_ABI, signer);
    }
    
    async checkAndDistributeYield() {
        try {
            // 1. Check if yield distribution is needed
            const poolMetrics = await this.yieldShift.getPoolMetrics();
            const targetRatio = await this.yieldShift.targetPoolRatio();
            
            const currentRatio = poolMetrics.userPoolSize.mul(10000).div(poolMetrics.hedgerPoolSize);
            const deviation = currentRatio.sub(targetRatio).abs();
            const threshold = await this.yieldShift.rebalanceThreshold();
            
            if (deviation.gt(threshold)) {
                console.log('Pool ratio deviation detected, distributing yield...');
                await this.yieldShift.distributeYield();
            }
        } catch (error) {
            console.error('Yield distribution failed:', error.message);
            throw error;
        }
    }
    
    async harvestAaveYield() {
        try {
            const yieldAmount = await this.aaveVault.harvestAaveYield();
            console.log(`Harvested ${ethers.utils.formatEther(yieldAmount)} QEURO from Aave`);
            return yieldAmount;
        } catch (error) {
            console.error('Aave yield harvest failed:', error.message);
            throw error;
        }
    }
    
    async autoRebalance() {
        try {
            const [rebalanced, newAllocation, expectedYield] = await this.aaveVault.autoRebalance();
            
            if (rebalanced) {
                console.log(`Rebalanced to ${newAllocation.toNumber() / 100}% allocation`);
                console.log(`Expected yield: ${ethers.utils.formatEther(expectedYield)} QEURO`);
            } else {
                console.log('No rebalancing needed');
            }
            
            return { rebalanced, newAllocation, expectedYield };
        } catch (error) {
            console.error('Auto rebalancing failed:', error.message);
            throw error;
        }
    }
}
```

---

## Error Handling and Recovery

### Comprehensive Error Handling

```javascript
class QuantillonErrorHandler {
    static handleError(error) {
        const errorMessage = error.message.toLowerCase();
        
        if (errorMessage.includes('insufficient balance')) {
            return {
                type: 'INSUFFICIENT_BALANCE',
                message: 'Insufficient token balance for this operation',
                action: 'Check your token balance and try again'
            };
        } else if (errorMessage.includes('insufficient allowance')) {
            return {
                type: 'INSUFFICIENT_ALLOWANCE',
                message: 'Token allowance is insufficient',
                action: 'Approve token spending before calling this function'
            };
        } else if (errorMessage.includes('stale price')) {
            return {
                type: 'STALE_PRICE',
                message: 'Oracle price is stale',
                action: 'Wait for oracle to update or contact support'
            };
        } else if (errorMessage.includes('contract paused')) {
            return {
                type: 'CONTRACT_PAUSED',
                message: 'Contract is currently paused',
                action: 'Wait for contract to be unpaused'
            };
        } else if (errorMessage.includes('unauthorized')) {
            return {
                type: 'UNAUTHORIZED',
                message: 'Unauthorized access',
                action: 'Check your permissions and try again'
            };
        } else {
            return {
                type: 'UNKNOWN',
                message: error.message,
                action: 'Contact support if the issue persists'
            };
        }
    }
    
    static async retryOperation(operation, maxRetries = 3, delay = 1000) {
        for (let i = 0; i < maxRetries; i++) {
            try {
                return await operation();
            } catch (error) {
                const errorInfo = this.handleError(error);
                
                if (i === maxRetries - 1) {
                    throw new Error(`${errorInfo.type}: ${errorInfo.message}. ${errorInfo.action}`);
                }
                
                console.log(`Attempt ${i + 1} failed: ${errorInfo.message}. Retrying in ${delay}ms...`);
                await new Promise(resolve => setTimeout(resolve, delay));
                delay *= 2; // Exponential backoff
            }
        }
    }
}

// Usage
try {
    await QuantillonErrorHandler.retryOperation(async () => {
        return await vault.mintQEURO(usdcAmount, minQeuroOut);
    });
} catch (error) {
    console.error('Operation failed after retries:', error.message);
}
```

### Transaction Monitoring

```javascript
class TransactionMonitor {
    static async waitForConfirmation(tx, confirmations = 1) {
        try {
            console.log(`Transaction submitted: ${tx.hash}`);
            const receipt = await tx.wait(confirmations);
            console.log(`Transaction confirmed in block ${receipt.blockNumber}`);
            return receipt;
        } catch (error) {
            console.error(`Transaction failed: ${error.message}`);
            throw error;
        }
    }
    
    static async monitorGasPrice(provider, maxGasPrice) {
        const gasPrice = await provider.getGasPrice();
        if (gasPrice.gt(maxGasPrice)) {
            console.warn(`Gas price ${ethers.utils.formatUnits(gasPrice, 'gwei')} Gwei exceeds maximum ${ethers.utils.formatUnits(maxGasPrice, 'gwei')} Gwei`);
            return false;
        }
        return true;
    }
    
    static async estimateGasWithBuffer(contract, method, params, buffer = 1.2) {
        try {
            const gasEstimate = await contract.estimateGas[method](...params);
            return gasEstimate.mul(Math.floor(buffer * 100)).div(100);
        } catch (error) {
            console.error('Gas estimation failed:', error.message);
            throw error;
        }
    }
}
```

---

## Best Practices

### 1. Always Check Contract State
```javascript
// Check if contract is paused before any operation
const isPaused = await contract.paused();
if (isPaused) {
    throw new Error('Contract is paused');
}
```

### 2. Use Slippage Protection
```javascript
// Always use slippage protection for swaps
const slippage = 0.05; // 5%
const minOutput = expectedOutput.mul(100 - slippage * 100).div(100);
```

### 3. Implement Proper Error Handling
```javascript
// Use try-catch blocks and handle specific errors
try {
    await contract.function();
} catch (error) {
    const errorInfo = QuantillonErrorHandler.handleError(error);
    console.error(`${errorInfo.type}: ${errorInfo.message}`);
}
```

### 4. Monitor Events
```javascript
// Listen for important events
contract.on('EventName', (param1, param2) => {
    console.log('Event received:', param1, param2);
});
```

### 5. Gas Optimization
```javascript
// Estimate gas and add buffer
const gasEstimate = await contract.estimateGas.function(params);
const gasLimit = gasEstimate.mul(120).div(100); // 20% buffer
```

---

*This integration examples guide is maintained by Quantillon Labs and updated regularly.*
