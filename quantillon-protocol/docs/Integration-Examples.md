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
        
        // 2. Calculate expected output (calculateMintAmount returns (qeuroAmount, fee); 18 decimals)
        const [expectedQeuro] = await vault.calculateMintAmount(usdcAmount);
        const minQeuroOut = expectedQeuro.mul(100 - slippage * 100).div(100);
        
        // 3. Approve USDC spending
        const approveTx = await usdc.approve(VAULT_ADDRESS, usdcAmount);
        await approveTx.wait();
        
        // 4. Mint QEURO
        const mintTx = await vault.mintQEURO(usdcAmount, minQeuroOut);
        const receipt = await mintTx.wait();
        
        // 5. Parse events
        const mintEvent = receipt.events.find(e => e.event === 'QEUROminted'); // note the lowercase m
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
        // 1. Calculate expected output (calculateRedeemAmount returns (usdcAmount, fee))
        const [expectedUsdc] = await vault.calculateRedeemAmount(qeuroAmount);
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
        // 1. Check minimum stake amount (settable via updateStakingParameters; 100 QEURO live)
        const minStakeAmount = await userPool.minStakeAmount();
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
        
        // 4. Stake QEURO (UserPool functions take arrays; one element for a single stake)
        const stakeTx = await userPool.stake([qeuroAmount]);
        const receipt = await stakeTx.wait();
        
        console.log(`Staked ${qeuroAmount} QEURO successfully`);
        return receipt;
    } catch (error) {
        console.error('Staking failed:', error.message);
        throw error;
    }
}
```

### Staking Rewards — removed

There is no `claimStakingRewards` call. The UserPool staking-reward path has been removed. Protocol yield for users accrues **automatically** through the **stQEURO** wrapper — its exchange rate rises as yield is credited, so simply holding stQEURO earns yield. See *Staking in stQEURO Token* below.

### Staking in stQEURO Token

`stQEUROToken` is a standard ERC-4626 vault over QEURO, deployed once per staking vault by `stQEUROFactory` (live: `stQEUROMORPHO1`, `vaultId = 2`). Stake with `deposit(assets, receiver)`, unstake with `redeem(shares, receiver, owner)`; there is no `stake` / `getExchangeRate` API.

```javascript
async function stakeInStQEURO(qeuroAmount, vaultId = 2) {
    const factory = new ethers.Contract(ST_QEURO_FACTORY_ADDRESS, ST_QEURO_FACTORY_ABI, signer);
    const qeuro = new ethers.Contract(QEURO_ADDRESS, QEURO_ABI, signer);

    try {
        // 1. Resolve the per-vault stQEURO token
        const stQeuroAddress = await factory.getStQEUROByVaultId(vaultId);
        if (stQeuroAddress === ethers.constants.AddressZero) {
            throw new Error(`No stQEURO registered for vaultId ${vaultId}`);
        }
        const stQeuro = new ethers.Contract(stQeuroAddress, ST_QEURO_ABI, signer);

        // 2. Quote shares (share price = totalAssets / totalSupply, rises as yield is credited)
        const expectedShares = await stQeuro.previewDeposit(qeuroAmount);
        const sharePrice = await stQeuro.convertToAssets(ethers.utils.parseEther('1'));

        // 3. Approve QEURO spending by the stQEURO proxy
        const approveTx = await qeuro.approve(stQeuroAddress, qeuroAmount);
        await approveTx.wait();

        // 4. Deposit (ERC-4626)
        const depositTx = await stQeuro.deposit(qeuroAmount, signer.address);
        const receipt = await depositTx.wait();

        console.log(`Deposited ${ethers.utils.formatEther(qeuroAmount)} QEURO for ~${ethers.utils.formatEther(expectedShares)} stQEURO (share price ${ethers.utils.formatEther(sharePrice)})`);
        return receipt;
    } catch (error) {
        console.error('stQEURO deposit failed:', error.message);
        throw error;
    }
}

// Unstake: redeem shares back to QEURO (no cooldown)
async function unstakeFromStQEURO(stQeuro, shares) {
    const expectedQeuro = await stQeuro.previewRedeem(shares);
    const tx = await stQeuro.redeem(shares, signer.address, signer.address);
    await tx.wait();
    console.log(`Redeemed ${ethers.utils.formatEther(shares)} stQEURO for ~${ethers.utils.formatEther(expectedQeuro)} QEURO`);
}
```

---

## Governance Participation

> **QTI is dormant.** No mint path is wired in the deployed `QTIToken`, so the total supply is 0 and `lock` / `createProposal` / `vote` cannot be exercised on Base mainnet today. The examples below describe the as-coded governance surface and become functional only after an activation upgrade mints the token.

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
        const minProposalPower = await qti.proposalThreshold(); // 100,000 QTI
        
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

> **Single-hedger model.** `enterHedgePosition` reverts with `NotAuthorized` unless `signer` is the address configured via `setSingleHedger` (the protocol's hedging engine). The example is shown for completeness / for the operator; arbitrary wallets cannot open positions.

```javascript
async function openHedgePosition(marginAmount, leverage) {
    const hedgerPool = new ethers.Contract(HEDGER_POOL_ADDRESS, HEDGER_POOL_ABI, signer);
    const usdc = new ethers.Contract(USDC_ADDRESS, USDC_ABI, signer);
    
    try {
        // 1. Validate leverage (there is no maxLeverage() getter: read coreParams())
        const maxLeverage = (await hedgerPool.coreParams()).maxLeverage; // 20 live
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
        // 1. Get position info (public mapping getter)
        const positionInfo = await hedgerPool.positions(positionId);
        
        // 2. Calculate margin ratio in basis points
        const marginRatio = positionInfo.margin.mul(10000).div(positionInfo.positionSize);
        const minMarginRatioBps = (await hedgerPool.coreParams()).minMarginRatio; // bps, governance-set: 250 = 2.5% live (since 2026-09-02); 500 at launch
        
        // 3. Check if position is healthy
        // Note: protocol-level liquidation mode triggers at vault CR <= 101%
        // (QuantillonVault.criticalCollateralizationRatio), independent of this check.
        const isHealthy = marginRatio.gt(minMarginRatioBps);
        
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
        // 1. Check position ownership (public mapping getter)
        const positionInfo = await hedgerPool.positions(positionId);
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
                positions,
                totalUsdcHeld,
                totalUsdcInExternalVaults,
                totalMinted,
                collateralizationRatio
            ] = await Promise.all([
                this.qeuro.balanceOf(address),
                this.userPool.getUserInfo(address),
                this.getUserPositions(),
                this.vault.totalUsdcHeld(),
                this.vault.totalUsdcInExternalVaults(),
                this.vault.totalMinted(),
                this.vault.getProtocolCollateralizationRatio() // 18-decimal percent: 1e20 == 100%
            ]);

            return {
                balances: {
                    qeuro: ethers.utils.formatEther(qeuroBalance),
                    staked: ethers.utils.formatEther(userInfo.stakedAmount),
                    pendingUnstake: ethers.utils.formatEther(userInfo.unstakeAmount),
                    depositedHistory: ethers.utils.formatUnits(userInfo.depositHistory, 6)
                },
                // No claimable staking rewards exist: user yield accrues in the stQEURO share price
                positions: positions,
                vault: {
                    usdcHeld: ethers.utils.formatUnits(totalUsdcHeld, 6),
                    usdcInExternalVaults: ethers.utils.formatUnits(totalUsdcInExternalVaults, 6),
                    qeuroMinted: ethers.utils.formatEther(totalMinted),
                    collateralizationRatioPct: Number(ethers.utils.formatEther(collateralizationRatio)) // 1e20 -> 100
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
            const userPoolAPY = await this.userPool.stakingAPY(); // bps
            // No APY getter on HedgerPool - use the interest-rate differential
            const params = await this.hedgerPool.coreParams();
            const hedgerCarryBps = params.usdInterestRate - params.eurInterestRate;
            
            console.log(`User Pool APY: ${userPoolAPY.toNumber() / 100}%`);
            console.log(`Hedger carry (rate differential): ${hedgerCarryBps / 100}%`);
            
            if (userPoolAPY.gte(hedgerCarryBps)) {
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

### Automated Yield Management (keeper)

External-vault yield is realized and split by one vault call, `QuantillonVault.harvestAndDistributeVaultYield(vaultId)` (hedger funding first, residual to stQEURO stakers via `creditVaultYield`, remainder to treasury — see the Staking Yield Distribution guide). The caller must hold `YIELD_DISTRIBUTOR_ROLE` on the vault. The former Aave-based vault contract no longer exists in the protocol and YieldShift has no `distributeYield` / `rebalanceThreshold` entrypoints.

```javascript
class VaultYieldKeeper {
    constructor(signer) {
        // signer must hold YIELD_DISTRIBUTOR_ROLE on QuantillonVault
        this.vault = new ethers.Contract(VAULT_ADDRESS, VAULT_ABI, signer);
    }

    async inspect(vaultId) {
        const [adapter, active, principalTracked, currentUnderlying] = await this.vault.getVaultExposure(vaultId);
        const [fundingRateBps, hedgerRecipient, lastHarvest] = await this.vault.harvestConfig(vaultId);
        return { adapter, active, principalTracked, currentUnderlying, fundingRateBps, hedgerRecipient, lastHarvest };
    }

    async harvest(vaultId) {
        try {
            const exposure = await this.inspect(vaultId);
            if (!exposure.active) throw new Error(`vault ${vaultId} is not active`);

            // Nothing to realize when the adapter holds no more than the tracked principal.
            // Note: the very first call for a vault id only anchors the hedger funding clock.
            if (exposure.currentUnderlying.lte(exposure.principalTracked)) {
                console.log(`vault ${vaultId}: no yield above principal`);
                return null;
            }

            const tx = await this.vault.harvestAndDistributeVaultYield(vaultId);
            const receipt = await tx.wait();
            const ev = receipt.events.find(e => e.event === 'VaultYieldDistributed');
            const f = (x) => ethers.utils.formatUnits(x, 6);
            console.log(`vault ${vaultId}: realized ${f(ev.args.realizedYield)} USDC -> hedger ${f(ev.args.hedgerShare)}, stakers ${f(ev.args.userShare)}, treasury ${f(ev.args.treasuryShare)}`);
            return ev.args;
        } catch (error) {
            console.error('Yield harvest failed:', error.message);
            throw error;
        }
    }
}

// Usage: run on a schedule for every registered vault id (live: vaultId 2 = MORPHO1)
const keeper = new VaultYieldKeeper(signer);
await keeper.harvest(2);
```

---

## Error Handling and Recovery

### Comprehensive Error Handling

```javascript
class QuantillonErrorHandler {
    // Reverts surface as custom errors (see API-Reference "Error Handling"); ethers puts the
    // decoded name in error.message / error.reason when the ABI is loaded.
    static handleError(error) {
        const errorMessage = (error.reason || error.message || '').toLowerCase();

        if (errorMessage.includes('erc20insufficientbalance') || errorMessage.includes('insufficientbalance')) {
            return {
                type: 'INSUFFICIENT_BALANCE',
                message: 'Insufficient token balance for this operation',
                action: 'Check your token balance and try again'
            };
        } else if (errorMessage.includes('erc20insufficientallowance')) {
            return {
                type: 'INSUFFICIENT_ALLOWANCE',
                message: 'Token allowance is insufficient',
                action: 'Approve token spending before calling this function'
            };
        } else if (errorMessage.includes('invalidoracleprice') || errorMessage.includes('invalidprice')) {
            return {
                type: 'INVALID_ORACLE_PRICE',
                message: 'Oracle price is stale or invalid (InvalidOraclePrice / InvalidPrice)',
                action: 'Wait for the oracle to update or check OracleRouter.getOracleHealth()'
            };
        } else if (errorMessage.includes('enforcedpause')) {
            return {
                type: 'CONTRACT_PAUSED',
                message: 'Contract is currently paused (EnforcedPause)',
                action: 'Wait for contract to be unpaused'
            };
        } else if (errorMessage.includes('notauthorized') || errorMessage.includes('accesscontrolunauthorizedaccount')) {
            return {
                type: 'UNAUTHORIZED',
                message: 'Caller lacks the required role or is not the configured hedger',
                action: 'Check your permissions and try again'
            };
        } else if (errorMessage.includes('excessiveslippage')) {
            return {
                type: 'EXCESSIVE_SLIPPAGE',
                message: 'Output fell below the minimum you passed (ExcessiveSlippage)',
                action: 'Re-quote with calculateMintAmount / calculateRedeemAmount and retry'
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
            const estimator = contract.estimateGas[method];
            const gasEstimate = await estimator(...params);
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
