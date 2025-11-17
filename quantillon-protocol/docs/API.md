# Quantillon Protocol API Documentation

## Overview

The Quantillon Protocol is a comprehensive DeFi ecosystem built on Ethereum, featuring a euro-pegged stablecoin (QEURO), governance token (QTI), and advanced yield management system. This document provides detailed API documentation for all public interfaces.

## Table of Contents

1. [Core Contracts](#core-contracts)
   - [QuantillonVault](#quantillonvault)
   - [QEUROToken](#qeurotoken)
   - [QTIToken](#qtitoken)
   - [UserPool](#userpool)
   - [HedgerPool](#hedgerpool)
   - [stQEUROToken](#stqeurotoken)
2. [Vault Contracts](#vault-contracts)
   - [AaveVault](#aavevault)
3. [Yield Management](#yield-management)
   - [YieldShift](#yieldshift)
4. [Oracle](#oracle)
   - [ChainlinkOracle](#chainlinkoracle)
5. [Utilities](#utilities)
   - [TimeProvider](#timeprovider)
6. [Error Codes](#error-codes)
7. [Events](#events)
8. [Integration Examples](#integration-examples)

---

## Core Contracts

### QuantillonVault

The main vault contract that manages QEURO minting and redemption against USDC.

#### Functions

##### `initialize(address admin, address _qeuro, address _usdc, address _oracle)`
Initializes the vault with initial configuration.

**Parameters:**
- `admin` (address): Admin address receiving roles
- `_qeuro` (address): QEURO token address
- `_usdc` (address): USDC token address
- `_oracle` (address): Oracle contract address

**Access:** Public (only callable once)

##### `mintQEURO(uint256 usdcAmount, uint256 minQeuroOut)`
Mints QEURO by swapping USDC.

**Parameters:**
- `usdcAmount` (uint256): Amount of USDC to swap (6 decimals)
- `minQeuroOut` (uint256): Minimum QEURO expected (18 decimals, slippage protection)

**Access:** Public

**Requirements:**
- Contract not paused
- Valid oracle price
- Sufficient USDC balance and allowance

##### `redeemQEURO(uint256 qeuroAmount, uint256 minUsdcOut)`
Redeems QEURO for USDC.

**Parameters:**
- `qeuroAmount` (uint256): Amount of QEURO to swap (18 decimals)
- `minUsdcOut` (uint256): Minimum USDC expected (6 decimals, slippage protection)

**Access:** Public

**Requirements:**
- Contract not paused
- Valid oracle price
- Sufficient QEURO balance and allowance

##### `calculateMintAmount(uint256 usdcAmount) → (uint256)`
Calculates the amount of QEURO that would be minted for a given USDC amount.

**Parameters:**
- `usdcAmount` (uint256): Amount of USDC (6 decimals)

**Returns:**
- `uint256`: Amount of QEURO that would be minted (18 decimals)

**Access:** Public view

##### `calculateRedeemAmount(uint256 qeuroAmount) → (uint256)`
Calculates the amount of USDC that would be received for a given QEURO amount.

**Parameters:**
- `qeuroAmount` (uint256): Amount of QEURO (18 decimals)

**Returns:**
- `uint256`: Amount of USDC that would be received (6 decimals)

**Access:** Public view

##### `getVaultMetrics() → (uint256, uint256, uint256, uint256, uint256, uint256)`
Retrieves comprehensive vault metrics.

**Returns:**
- `uint256`: Total USDC reserves
- `uint256`: Total QEURO supply
- `uint256`: Collateralization ratio (basis points)
- `uint256`: Protocol fees collected
- `uint256`: Last update timestamp
- `uint256`: Vault utilization rate

**Access:** Public view

#### Events

```solidity
event QEUROMinted(address indexed user, uint256 usdcAmount, uint256 qeuroAmount, uint256 price);
event QEURORedeemed(address indexed user, uint256 qeuroAmount, uint256 usdcAmount, uint256 price);
event VaultPaused(address indexed admin);
event VaultUnpaused(address indexed admin);
```

---

### QEUROToken

The euro-pegged stablecoin token with compliance features.

#### Functions

##### `mint(address to, uint256 amount)`
Mints QEURO tokens to a specified address.

**Parameters:**
- `to` (address): Recipient address
- `amount` (uint256): Amount to mint (18 decimals)

**Access:** Vault role only

##### `burn(uint256 amount)`
Burns QEURO tokens from the caller's balance.

**Parameters:**
- `amount` (uint256): Amount to burn (18 decimals)

**Access:** Vault role only

##### `whitelistAddress(address account)`
Adds an address to the whitelist.

**Parameters:**
- `account` (address): Address to whitelist

**Access:** Compliance role only

##### `blacklistAddress(address account)`
Adds an address to the blacklist.

**Parameters:**
- `account` (address): Address to blacklist

**Access:** Compliance role only

##### `updateMaxSupply(uint256 newMaxSupply)`
Updates the maximum supply cap.

**Parameters:**
- `newMaxSupply` (uint256): New maximum supply (18 decimals)

**Access:** Admin role only

##### `getTokenInfo() → (uint256, uint256, uint256, bool, bool)`
Retrieves comprehensive token information.

**Returns:**
- `uint256`: Total supply
- `uint256`: Maximum supply
- `uint256`: Supply utilization percentage
- `bool`: Whitelist mode enabled
- `bool`: Contract paused

**Access:** Public view

#### Events

```solidity
event TokensMinted(address indexed to, uint256 amount);
event TokensBurned(address indexed from, uint256 amount);
event AddressWhitelisted(address indexed account);
event AddressBlacklisted(address indexed account);
event MaxSupplyUpdated(uint256 oldMaxSupply, uint256 newMaxSupply);
```

---

### QTIToken

The governance token with vote-escrow mechanics.

#### Functions

##### `lock(uint256 amount, uint256 lockTime) → (uint256)`
Locks QTI tokens for voting power.

**Parameters:**
- `amount` (uint256): Amount of QTI to lock (18 decimals)
- `lockTime` (uint256): Duration to lock (seconds)

**Returns:**
- `uint256`: Voting power received (18 decimals)

**Access:** Public

**Requirements:**
- Sufficient QTI balance
- Lock time between minimum and maximum duration

##### `unlock() → (uint256)`
Unlocks QTI tokens after lock period expires.

**Returns:**
- `uint256`: Amount of QTI unlocked

**Access:** Public

**Requirements:**
- Lock period has expired

##### `getVotingPower(address user) → (uint256)`
Gets current voting power for an address.

**Parameters:**
- `user` (address): User address

**Returns:**
- `uint256`: Current voting power (18 decimals)

**Access:** Public view

##### `getLockInfo(address user) → (uint256, uint256, uint256, uint256)`
Gets lock information for an address.

**Parameters:**
- `user` (address): User address

**Returns:**
- `uint256`: Locked amount
- `uint256`: Lock time
- `uint256`: Unlock time
- `uint256`: Current voting power

**Access:** Public view

##### `createProposal(string memory description, uint256 startTime, uint256 endTime) → (uint256)`
Creates a new governance proposal.

**Parameters:**
- `description` (string): Proposal description
- `startTime` (uint256): Voting start time
- `endTime` (uint256): Voting end time

**Returns:**
- `uint256`: Proposal ID

**Access:** Public

**Requirements:**
- Sufficient voting power
- Valid time parameters

##### `vote(uint256 proposalId, bool support)`
Votes on a governance proposal.

**Parameters:**
- `proposalId` (uint256): Proposal ID
- `support` (bool): True for yes, false for no

**Access:** Public

**Requirements:**
- Voting period active
- Sufficient voting power
- Not already voted

#### Events

```solidity
event TokensLocked(address indexed user, uint256 amount, uint256 lockTime, uint256 votingPower);
event TokensUnlocked(address indexed user, uint256 amount);
event ProposalCreated(uint256 indexed proposalId, string description, uint256 startTime, uint256 endTime);
event VoteCast(address indexed voter, uint256 indexed proposalId, bool support, uint256 votingPower);
```

---

### UserPool

Manages user deposits, staking, and yield distribution.

#### Functions

##### `deposit(uint256 usdcAmount)`
Deposits USDC into the user pool.

**Parameters:**
- `usdcAmount` (uint256): Amount of USDC to deposit (6 decimals)

**Access:** Public

**Requirements:**
- Contract not paused
- Sufficient USDC balance and allowance

##### `withdraw(uint256 usdcAmount)`
Withdraws USDC from the user pool.

**Parameters:**
- `usdcAmount` (uint256): Amount of USDC to withdraw (6 decimals)

**Access:** Public

**Requirements:**
- Sufficient balance
- Contract not paused

##### `stake(uint256 qeuroAmount)`
Stakes QEURO tokens for rewards.

**Parameters:**
- `qeuroAmount` (uint256): Amount of QEURO to stake (18 decimals)

**Access:** Public

**Requirements:**
- Sufficient QEURO balance and allowance
- Above minimum stake amount

##### `unstake(uint256 qeuroAmount)`
Unstakes QEURO tokens.

**Parameters:**
- `qeuroAmount` (uint256): Amount of QEURO to unstake (18 decimals)

**Access:** Public

**Requirements:**
- Sufficient staked balance
- Cooldown period completed

##### `claimStakingRewards() → (uint256)`
Claims accumulated staking rewards.

**Returns:**
- `uint256`: Amount of rewards claimed

**Access:** Public

##### `getUserInfo(address user) → (uint256, uint256, uint256, uint256, uint256)`
Gets comprehensive user information.

**Parameters:**
- `user` (address): User address

**Returns:**
- `uint256`: Deposited USDC amount
- `uint256`: Staked QEURO amount
- `uint256`: Last stake time
- `uint256`: Pending rewards
- `uint256`: Total rewards claimed

**Access:** Public view

##### `getPoolMetrics() → (uint256, uint256, uint256, uint256)`
Gets pool metrics.

**Returns:**
- `uint256`: Total users
- `uint256`: Total stakes
- `uint256`: Total deposits
- `uint256`: Total rewards distributed

**Access:** Public view

#### Events

```solidity
event USDCDeposited(address indexed user, uint256 amount);
event USDCWithdrawn(address indexed user, uint256 amount);
event QEUROStaked(address indexed user, uint256 amount);
event QEUROUnstaked(address indexed user, uint256 amount);
event RewardsClaimed(address indexed user, uint256 amount);
```

---

### HedgerPool

Manages leveraged hedging positions for risk management.

#### Functions

##### `enterHedgePosition(uint256 usdcAmount, uint256 leverage) → (uint256)`
Opens a new hedge position.

**Parameters:**
- `usdcAmount` (uint256): USDC margin amount (6 decimals)
- `leverage` (uint256): Leverage multiplier (1-10x)

**Returns:**
- `uint256`: Position ID

**Access:** Public

**Requirements:**
- Valid leverage amount
- Sufficient USDC balance and allowance
- Fresh oracle price

##### `closeHedgePosition(uint256 positionId) → (int256)`
Closes a hedge position.

**Parameters:**
- `positionId` (uint256): Position ID to close

**Returns:**
- `int256`: Profit or loss (positive = profit, negative = loss)

**Access:** Public

**Requirements:**
- Position exists and is active
- Caller owns the position

##### `addMargin(uint256 positionId, uint256 usdcAmount)`
Adds margin to an existing position.

**Parameters:**
- `positionId` (uint256): Position ID
- `usdcAmount` (uint256): Additional USDC margin (6 decimals)

**Access:** Public

**Requirements:**
- Position exists and is active
- Caller owns the position

##### `removeMargin(uint256 positionId, uint256 usdcAmount)`
Removes margin from a position.

**Parameters:**
- `positionId` (uint256): Position ID
- `usdcAmount` (uint256): USDC amount to remove (6 decimals)

**Access:** Public

**Requirements:**
- Position exists and is active
- Caller owns the position
- Maintains minimum margin ratio

##### `getPositionInfo(uint256 positionId) → (address, uint256, uint256, uint256, uint256, uint256, int256, bool)`
Gets position information.

**Parameters:**
- `positionId` (uint256): Position ID

**Returns:**
- `address`: Position owner
- `uint256`: Position size
- `uint256`: Margin amount
- `uint256`: Entry price
- `uint256`: Entry time
- `uint256`: Leverage
- `int256`: Unrealized PnL
- `bool`: Is active

**Access:** Public view

##### `getActivePositionIds() → (uint256[])`
Returns the list of all currently active hedger positions.

**Returns:**
- `uint256[]`: Array of active position IDs

**Access:** Public view

##### `getFillMetrics() → (uint256, uint256)`
Provides aggregate hedger fill information.

**Returns:**
- `uint256`: Total hedge exposure requested by active positions
- `uint256`: Total matched exposure currently filled by user activity

**Access:** Public view

##### `liquidatePosition(uint256 positionId)`
Liquidates an undercollateralized position.

**Parameters:**
- `positionId` (uint256): Position ID to liquidate

**Access:** Liquidator role only

**Requirements:**
- Position is undercollateralized
- Fresh oracle price

#### Events

```solidity
event HedgePositionOpened(address indexed hedger, uint256 indexed positionId, bytes32 positionData);
event HedgePositionClosed(address indexed hedger, uint256 indexed positionId, int256 pnl);
event MarginAdded(address indexed hedger, uint256 indexed positionId, uint256 amount);
event MarginRemoved(address indexed hedger, uint256 indexed positionId, uint256 amount);
event PositionLiquidated(address indexed liquidator, uint256 indexed positionId, int256 pnl);
event HedgerFillUpdated(uint256 indexed positionId, uint256 previousFilled, uint256 newFilled);
```

---

### stQEUROToken

Staked QEURO token with yield distribution.

#### Functions

##### `stake(uint256 qeuroAmount)`
Stakes QEURO tokens to receive stQEURO.

**Parameters:**
- `qeuroAmount` (uint256): Amount of QEURO to stake (18 decimals)

**Access:** Public

**Requirements:**
- Sufficient QEURO balance and allowance

##### `unstake(uint256 stQeuroAmount)`
Unstakes stQEURO tokens to receive QEURO.

**Parameters:**
- `stQeuroAmount` (uint256): Amount of stQEURO to unstake (18 decimals)

**Access:** Public

**Requirements:**
- Sufficient stQEURO balance

##### `claimYield() → (uint256)`
Claims accumulated yield.

**Returns:**
- `uint256`: Amount of yield claimed

**Access:** Public

##### `getExchangeRate() → (uint256)`
Gets current exchange rate between stQEURO and QEURO.

**Returns:**
- `uint256`: Exchange rate (18 decimals)

**Access:** Public view

##### `getQEUROEquivalent(uint256 stQeuroAmount) → (uint256)`
Calculates QEURO equivalent for stQEURO amount.

**Parameters:**
- `stQeuroAmount` (uint256): Amount of stQEURO (18 decimals)

**Returns:**
- `uint256`: Equivalent QEURO amount (18 decimals)

**Access:** Public view

##### `distributeYield(uint256 qeuroAmount)`
Distributes yield to stakers.

**Parameters:**
- `qeuroAmount` (uint256): Amount of QEURO to distribute (18 decimals)

**Access:** Yield manager role only

#### Events

```solidity
event QEUROStaked(address indexed user, uint256 qeuroAmount, uint256 stQeuroAmount);
event QEUROUnstaked(address indexed user, uint256 stQeuroAmount, uint256 qeuroAmount);
event YieldClaimed(address indexed user, uint256 amount);
event YieldDistributed(uint256 totalAmount, uint256 timestamp);
```

---

## Vault Contracts

### AaveVault

Manages yield generation through Aave protocol integration.

#### Functions

##### `deployToAave(uint256 usdcAmount)`
Deploys USDC to Aave for yield generation.

**Parameters:**
- `usdcAmount` (uint256): Amount of USDC to deploy (6 decimals)

**Access:** Yield manager role only

**Requirements:**
- Sufficient USDC balance
- Within exposure limits

##### `withdrawFromAave(uint256 usdcAmount)`
Withdraws USDC from Aave.

**Parameters:**
- `usdcAmount` (uint256): Amount of USDC to withdraw (6 decimals)

**Access:** Yield manager role only

##### `harvestAaveYield() → (uint256)`
Harvests accumulated yield from Aave.

**Returns:**
- `uint256`: Amount of yield harvested

**Access:** Yield manager role only

##### `getAaveBalance() → (uint256)`
Gets current USDC balance in Aave.

**Returns:**
- `uint256`: USDC balance in Aave (6 decimals)

**Access:** Public view

##### `getAaveAPY() → (uint256)`
Gets current Aave APY.

**Returns:**
- `uint256`: APY in basis points

**Access:** Public view

##### `autoRebalance() → (bool, uint256, uint256)`
Automatically rebalances Aave position.

**Returns:**
- `bool`: Whether rebalancing occurred
- `uint256`: New allocation percentage
- `uint256`: Expected yield

**Access:** Public

#### Events

```solidity
event USDCDepositedToAave(uint256 amount);
event USDCWithdrawnFromAave(uint256 amount);
event AaveYieldHarvested(uint256 amount);
event AavePositionRebalanced(uint256 newAllocation, uint256 expectedYield);
```

---

## Yield Management

### YieldShift

Manages yield distribution between user and hedger pools.

#### Functions

##### `addYield(uint256 qeuroAmount)`
Adds yield to the distribution system.

**Parameters:**
- `qeuroAmount` (uint256): Amount of QEURO yield to add (18 decimals)

**Access:** Authorized yield sources only

##### `distributeYield()`
Distributes accumulated yield between pools.

**Access:** Yield manager role only

##### `claimUserYield() → (uint256)`
Claims yield for user pool.

**Returns:**
- `uint256`: Amount of yield claimed

**Access:** User pool contract only

##### `claimHedgerYield() → (uint256)`
Claims yield for hedger pool.

**Returns:**
- `uint256`: Amount of yield claimed

**Access:** Hedger pool contract only

##### `getPoolMetrics() → (uint256, uint256, uint256, uint256)`
Gets pool metrics for yield calculation.

**Returns:**
- `uint256`: User pool size
- `uint256`: Hedger pool size
- `uint256`: Pool ratio
- `uint256`: Target ratio

**Access:** Public view

##### `calculateOptimalYieldShift() → (uint256, uint256, uint256)`
Calculates optimal yield distribution.

**Returns:**
- `uint256`: User pool allocation
- `uint256`: Hedger pool allocation
- `uint256`: Shift amount

**Access:** Public view

#### Events

```solidity
event YieldAdded(address indexed source, uint256 amount);
event YieldDistributed(uint256 userPoolAmount, uint256 hedgerPoolAmount);
event UserYieldClaimed(uint256 amount);
event HedgerYieldClaimed(uint256 amount);
```

---

## Oracle

### ChainlinkOracle

Provides price feeds for EUR/USD and USDC/USD.

#### Functions

##### `getEurUsdPrice() → (uint256, bool)`
Gets current EUR/USD price.

**Returns:**
- `uint256`: Price (8 decimals)
- `bool`: Whether price is valid and fresh

**Access:** Public view

##### `getUsdcUsdPrice() → (uint256, bool)`
Gets current USDC/USD price.

**Returns:**
- `uint256`: Price (8 decimals)
- `bool`: Whether price is valid and fresh

**Access:** Public view

##### `updatePriceFeeds(address eurUsdFeed, address usdcUsdFeed)`
Updates Chainlink price feed addresses.

**Parameters:**
- `eurUsdFeed` (address): EUR/USD price feed address
- `usdcUsdFeed` (address): USDC/USD price feed address

**Access:** Admin role only

##### `updatePriceBounds(uint256 minPrice, uint256 maxPrice)`
Updates price bounds for validation.

**Parameters:**
- `minPrice` (uint256): Minimum acceptable price
- `maxPrice` (uint256): Maximum acceptable price

**Access:** Admin role only

##### `triggerCircuitBreaker()`
Triggers circuit breaker for emergency price protection.

**Access:** Emergency role only

##### `resetCircuitBreaker()`
Resets circuit breaker.

**Access:** Admin role only

#### Events

```solidity
event PriceFeedsUpdated(address eurUsdFeed, address usdcUsdFeed);
event PriceBoundsUpdated(uint256 minPrice, uint256 maxPrice);
event CircuitBreakerTriggered(uint256 timestamp);
event CircuitBreakerReset(uint256 timestamp);
```

---

## Utilities

### TimeProvider

Provides time utilities with offset capabilities.

#### Functions

##### `currentTime() → (uint256)`
Gets current time with offset.

**Returns:**
- `uint256`: Current timestamp

**Access:** Public view

##### `setTimeOffset(int256 offset)`
Sets time offset.

**Parameters:**
- `offset` (int256): Time offset in seconds

**Access:** Time manager role only

##### `advanceTime(uint256 amount)`
Advances time by specified amount.

**Parameters:**
- `amount` (uint256): Time to advance in seconds

**Access:** Time manager role only

##### `isFuture(uint256 timestamp) → (bool)`
Checks if timestamp is in the future.

**Parameters:**
- `timestamp` (uint256): Timestamp to check

**Returns:**
- `bool`: True if timestamp is in the future

**Access:** Public view

#### Events

```solidity
event TimeOffsetSet(int256 oldOffset, int256 newOffset);
event TimeAdvanced(uint256 amount);
```

---

## Error Codes

The protocol uses custom errors for gas efficiency. Common error codes include:

```solidity
// Access Control
error UnauthorizedAccess();
error InsufficientRole();

// Validation
error InvalidAmount();
error InvalidAddress();
error InvalidParameter();
error InvalidTime();

// Business Logic
error InsufficientBalance();
error InsufficientAllowance();
error ExceedsLimit();
error BelowMinimum();

// Oracle
error StalePrice();
error InvalidPrice();
error CircuitBreakerActive();

// Emergency
error ContractPaused();
error EmergencyMode();

// Liquidation
error PositionHealthy();
error InsufficientMargin();
```

---

## Events

All contracts emit comprehensive events for state changes. Key event categories:

### Core Events
- Token transfers and approvals
- Deposits and withdrawals
- Staking and unstaking
- Yield distribution

### Governance Events
- Proposal creation and execution
- Voting and delegation
- Parameter updates

### Risk Management Events
- Position opening and closing
- Liquidations
- Circuit breaker activations

### Emergency Events
- Pause and unpause
- Emergency withdrawals
- Recovery operations

---

## Integration Examples

### Basic QEURO Minting

```solidity
// 1. Approve USDC spending
usdc.approve(vaultAddress, usdcAmount);

// 2. Mint QEURO with slippage protection
uint256 minQeuroOut = (usdcAmount * 95) / 100; // 5% slippage tolerance
vault.mintQEURO(usdcAmount, minQeuroOut);
```

### Staking QEURO for Rewards

```solidity
// 1. Approve QEURO spending
qeuro.approve(userPoolAddress, qeuroAmount);

// 2. Stake QEURO
userPool.stake(qeuroAmount);

// 3. Claim rewards later
uint256 rewards = userPool.claimStakingRewards();
```

### Opening a Hedge Position

```solidity
// 1. Approve USDC spending
usdc.approve(hedgerPoolAddress, marginAmount);

// 2. Open position with 5x leverage
uint256 positionId = hedgerPool.enterHedgePosition(marginAmount, 5);

// 3. Monitor position
(bool isActive, int256 pnl) = hedgerPool.getPositionInfo(positionId);
```

### Governance Participation

```solidity
// 1. Lock QTI for voting power
qti.lock(lockAmount, lockDuration);

// 2. Create proposal
uint256 proposalId = qti.createProposal(
    "Update protocol parameters",
    block.timestamp + 1 days,
    block.timestamp + 7 days
);

// 3. Vote on proposal
qti.vote(proposalId, true); // Vote yes
```

---

## Security Considerations

1. **Always validate return values** from view functions
2. **Check contract state** before making transactions
3. **Use slippage protection** for all swaps
4. **Monitor oracle prices** for freshness
5. **Implement proper error handling** for all interactions
6. **Use events** for transaction monitoring
7. **Follow access control patterns** for role-based operations

---

## Support

For technical support and questions:
- **Email**: team@quantillon.money
- **Documentation**: [Quantillon Protocol Docs](https://docs.quantillon.money)
- **GitHub**: [Quantillon Labs](https://github.com/Quantillon-Labs)

---

*This documentation is maintained by Quantillon Labs and updated regularly. Last updated: January 2025*
