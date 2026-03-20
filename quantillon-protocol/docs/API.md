# Quantillon Protocol API Documentation

## Overview

The Quantillon Protocol is a comprehensive DeFi ecosystem built on Base, featuring a euro-pegged stablecoin (QEURO), governance token (QTI), and advanced yield management system. This document provides detailed API documentation for all public interfaces.

## Table of Contents

1. [Core Contracts](#core-contracts)
   - [QuantillonVault](#quantillonvault)
   - [QEUROToken](#qeurotoken)
   - [QTIToken](#qtitoken)
   - [FeeCollector](#feecollector)
   - [UserPool](#userpool)
   - [HedgerPool](#hedgerpool)
   - [stQEUROFactory](#stqeurofactory)
   - [stQEUROToken](#stqeurotoken)
2. [Vault Contracts](#vault-contracts)
   - [AaveVault](#aavevault)
3. [Yield Management](#yield-management)
   - [YieldShift](#yieldshift)
4. [Oracle System](#oracle-system)
   - [OracleRouter](#oraclerouter)
   - [ChainlinkOracle](#chainlinkoracle)
   - [StorkOracle](#storkoracle)
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

##### `initialize(address admin, address _qeuro, address _usdc, address _oracle, address _hedgerPool, address _userPool, address _timelock, address _feeCollector)`
Initializes the vault with initial configuration.

**Parameters:**
- `admin` (address): Admin address receiving roles
- `_qeuro` (address): QEURO token address
- `_usdc` (address): USDC token address
- `_oracle` (address): Oracle contract address
- `_hedgerPool` (address): HedgerPool address (can be set later)
- `_userPool` (address): UserPool address (can be set later)
- `_timelock` (address): Timelock/treasury address
- `_feeCollector` (address): FeeCollector address

**Access:** Public (only callable once)

##### `mintQEURO(uint256 usdcAmount, uint256 minQeuroOut)`
Mints QEURO by swapping USDC.

**Parameters:**
- `usdcAmount` (uint256): Amount of USDC to swap (6 decimals)
- `minQeuroOut` (uint256): Minimum QEURO expected (18 decimals, slippage protection)

**Access:** Public

**Requirements:**
- Contract not paused
- Valid oracle price and initialized price cache (`initializePriceCache`)
- Active hedger (`hedgerPool.hasActiveHedger()`)
- Sufficient USDC balance and allowance

##### `redeemQEURO(uint256 qeuroAmount, uint256 minUsdcOut)`
Redeems QEURO for USDC.

**Parameters:**
- `qeuroAmount` (uint256): Amount of QEURO to swap (18 decimals)
- `minUsdcOut` (uint256): Minimum USDC expected (6 decimals, slippage protection)

**Access:** Public

**Requirements:**
- Contract not paused
- Valid oracle price (normal mode)
- Sufficient QEURO balance and allowance
- Automatically routes to liquidation redemption when protocol CR is at or below critical threshold

##### `calculateMintAmount(uint256 usdcAmount) → (uint256, uint256)`
Calculates quoted mint output using cached price.

**Parameters:**
- `usdcAmount` (uint256): Amount of USDC (6 decimals)

**Returns:**
- `uint256`: Amount of QEURO that would be minted (18 decimals)
- `uint256`: Mint fee (USDC, 6 decimals)

**Access:** Public view

##### `calculateRedeemAmount(uint256 qeuroAmount) → (uint256, uint256)`
Calculates quoted redeem output using cached price.

**Parameters:**
- `qeuroAmount` (uint256): Amount of QEURO (18 decimals)

**Returns:**
- `uint256`: Amount of USDC that would be received (6 decimals)
- `uint256`: Redemption fee (USDC, 6 decimals)

**Access:** Public view

##### `getVaultMetrics() → (uint256, uint256, uint256, uint256, uint256)`
Retrieves comprehensive vault metrics.

**Returns:**
- `uint256`: `totalUsdcHeld` (USDC in vault, 6 decimals)
- `uint256`: `totalMinted` (QEURO tracked by vault, 18 decimals)
- `uint256`: `totalDebtValue` (USD value from live supply and cached EUR/USD)
- `uint256`: `totalUsdcInExternalVaults` (tracked principal across external adapters)
- `uint256`: `totalUsdcAvailable` (vault + external vault balances including accrued yield)

**Access:** Public view

##### `getProtocolCollateralizationRatio() → (uint256)`
Returns collateralization ratio in 18-decimal percentage format (`100% = 1e20`).

##### `canMint() → (bool)`
Returns whether minting is currently allowed.

##### `getProtocolCollateralizationRatioView() → (uint256)` / `canMintView() → (bool)`
View-safe aliases that use cached price path (no state refresh side effects).

##### `initializePriceCache()`
Seeds the cached EUR/USD price after deployment (required before first mint).

##### `updateHedgerRewardFeeSplit(uint256 newSplit)`
Updates the fee share routed to HedgerPool reserve (`1e18 = 100%`).

##### `mintQEUROToVault(uint256 usdcAmount, uint256 minQeuroOut, uint256 vaultId)`
Mints QEURO and routes collateral to a specific external vault adapter.

##### `mintAndStakeQEURO(uint256 usdcAmount, uint256 minQeuroOut, uint256 vaultId, uint256 minStQEUROOut) → (uint256, uint256)`
One-step flow: mint QEURO and immediately stake into `stQEURO{vaultName}` for the selected `vaultId`.

##### `harvestVaultYield(uint256 vaultId) → (uint256)`
Triggers yield harvest for a specific external vault adapter.

##### `deployUsdcToVault(uint256 vaultId, uint256 usdcAmount)`
Operator function to manually deploy vault-held USDC into a selected external vault adapter.

#### Events

```solidity
event QEUROminted(address indexed user, uint256 usdcAmount, uint256 qeuroAmount);
event QEURORedeemed(address indexed user, uint256 qeuroAmount, uint256 usdcAmount);
event LiquidationRedeemed(address indexed user, uint256 qeuroAmount, uint256 usdcPayout, uint256 collateralizationRatioBps, bool isPremium);
event ProtocolFeeRouted(string sourceType, uint256 totalFee, uint256 hedgerReserveShare, uint256 collectorShare);
event StakingVaultConfigured(uint256 indexed vaultId, address indexed adapter, bool active);
event UsdcDeployedToExternalVault(uint256 indexed vaultId, uint256 indexed usdcAmount, uint256 principalInVault);
event UsdcWithdrawnFromExternalVault(uint256 indexed vaultId, uint256 indexed usdcAmount, uint256 principalInVault);
event ExternalVaultYieldHarvested(uint256 indexed vaultId, uint256 harvestedYield);
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

Manages the protocol’s single-hedger leveraged position and hedger reward settlement.

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
- Caller must be the configured `singleHedger`
- Valid leverage amount
- Sufficient USDC balance and allowance
- Fresh oracle price

##### `exitHedgePosition(uint256 positionId) → (int256)`
Closes the active hedge position.

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

##### `claimHedgingRewards() → (uint256, uint256, uint256)`
Claims hedger rewards.

**Returns:**
- `uint256`: Interest differential paid/escrowed by HedgerPool reserve
- `uint256`: YieldShift rewards claimed via YieldShift
- `uint256`: Total rewards for reporting (`interest + yieldShift`)

**Access:** Restricted to configured `singleHedger`

##### `withdrawPendingRewards(address recipient)`
Withdraws reward amounts escrowed after failed push-transfer in `claimHedgingRewards`.

##### `hasActiveHedger() → (bool)`
Returns whether a configured single hedger currently has an active position.

##### `setSingleHedger(address hedger)`
Bootstrap/rotation entrypoint for single hedger configuration (governance-only).  
If no hedger is configured yet, assignment is immediate. Otherwise it creates a delayed pending rotation.

##### `applySingleHedgerRotation()`
Applies a previously proposed single-hedger rotation after delay (governance-only).

##### `fundRewardReserve(uint256 amount)`
Permissionless reserve top-up path for hedger rewards.

##### `configureRiskAndFees((...))`
Batch governance update for:
- margin ratio / leverage limits
- hold blocks / minimum margin
- EUR/USD interest rates
- entry / exit / margin fees
- `rewardFeeSplit` (`1e18 = 100%`)

##### `configureDependencies((...))`
Batch governance update for:
- `treasury`
- `vault`
- `oracle`
- `yieldShift`
- `feeCollector`

#### Events

```solidity
event HedgePositionOpened(address indexed hedger, uint256 indexed positionId, bytes32 positionData);
event HedgePositionClosed(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
event MarginUpdated(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
event HedgingRewardsClaimed(address indexed hedger, bytes32 packedData);
event HedgerFillUpdated(uint256 indexed positionId, uint256 previousFilled, uint256 newFilled);
event RewardReserveFunded(address indexed funder, uint256 amount);
event SingleHedgerRotationProposed(address indexed currentHedger, address indexed pendingHedger, uint256 activatesAt);
event SingleHedgerRotationApplied(address indexed previousHedger, address indexed newHedger);
```

---

### stQEUROFactory

Factory contract for vault-scoped staking tokens.

#### Functions

##### `registerVault(uint256 vaultId, string vaultName) -> (address)`
Registers the calling vault and deploys a dedicated stQEURO token proxy.

**Parameters:**
- `vaultId` (uint256): Non-zero vault id
- `vaultName` (string): Uppercase alphanumeric vault suffix (length `1..12`)

**Returns:**
- `address`: Newly deployed stQEURO token for the vault

**Access:** `VAULT_FACTORY_ROLE` only, strict self-registration semantics (`msg.sender` is the vault)

##### `getStQEUROByVaultId(uint256 vaultId) -> (address)`
Resolves stQEURO token address for a given vault id.

##### `getStQEUROByVault(address vault) -> (address)`
Resolves stQEURO token address for a given vault address.

##### `getVaultById(uint256 vaultId) -> (address)`
Returns vault address for a registered vault id.

##### `getVaultIdByStQEURO(address stQEUROToken) -> (uint256)`
Returns vault id mapped to an stQEURO token address.

##### `getVaultName(uint256 vaultId) -> (string)`
Returns vault name suffix stored at registration.

##### `updateYieldShift(address newYieldShift)`
Governance setter for YieldShift dependency used for newly deployed stQEURO tokens.

##### `updateTokenImplementation(address newImplementation)`
Governance setter for stQEURO token implementation address used by future proxies.

##### `updateTreasury(address newTreasury)` / `updateTokenAdmin(address newAdmin)` / `updateOracle(address newOracle)`
Governance setters for factory-level defaults used during vault token deployment.

#### Events

```solidity
event VaultRegistered(uint256 indexed vaultId, address indexed vault, address indexed stQEUROToken, string vaultName);
event FactoryConfigUpdated(string indexed key, address oldValue, address newValue);
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

##### `initialize(...)` (dynamic metadata overload)
Supports per-vault metadata (`tokenName`, `tokenSymbol`, `vaultName`) when deployed through `stQEUROFactory`.

#### Events

```solidity
event QEUROStaked(address indexed user, uint256 qeuroAmount, uint256 stQeuroAmount);
event QEUROUnstaked(address indexed user, uint256 stQeuroAmount, uint256 qeuroAmount);
event YieldClaimed(address indexed user, uint256 amount);
event YieldDistributed(uint256 totalAmount, uint256 timestamp);
```

---

---

## Fee Management

### FeeCollector

Centralized protocol fee collection and distribution.

#### Functions

##### `collectFee(address token, uint256 amount)`
Records a collected fee from a protocol contract.

**Parameters:**
- `token` (address): Token address (e.g. USDC)
- `amount` (uint256): Fee amount collected

**Access:** Authorized protocol contracts only

##### `distributeFees(address token)`
Distributes collected fees to treasury, dev fund, and community fund according to configured ratios.

**Parameters:**
- `token` (address): Token to distribute

**Access:** `GOVERNANCE_ROLE`

##### `updateFeeRatios(uint256 treasury, uint256 dev, uint256 community)`
Updates fee distribution ratios.

**Parameters:**
- `treasury` (uint256): Treasury ratio (basis points, default 6000 = 60%)
- `dev` (uint256): Dev fund ratio (basis points, default 2500 = 25%)
- `community` (uint256): Community fund ratio (basis points, default 1500 = 15%)

**Access:** `GOVERNANCE_ROLE`

**Requirements:**
- `treasury + dev + community == 10000`

##### `withdrawFees(address token)`
Withdraws collected fees to the caller's role-permitted address.

**Access:** `TREASURY_ROLE`

#### Events

```solidity
event FeeCollected(address indexed token, uint256 amount);
event FeesDistributed(address indexed token, uint256 treasury, uint256 dev, uint256 community);
event FeeRatiosUpdated(uint256 treasury, uint256 dev, uint256 community);
```

---

## Vault Contracts

### AaveVault

Manages yield generation through Aave v3 protocol integration.

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

**Notes:**
- Reverts if `yieldVaultId` is not configured (`yieldVaultId == 0`)
- Routes harvested yield to `YieldShift.addYield(yieldVaultId, ...)`

##### `setYieldVaultId(uint256 newYieldVaultId)`
Sets the destination vault id used when routing harvested Aave yield to YieldShift.

**Access:** Governance role only

##### `updateYieldShift(address newYieldShift)`
Updates the YieldShift dependency used by AaveVault for yield routing.

**Access:** Governance role only

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

##### `addYield(uint256 vaultId, uint256 yieldAmount, bytes32 source)`
Adds yield to the distribution system.

**Parameters:**
- `vaultId` (uint256): Registered staking vault id receiving user-allocation yield
- `yieldAmount` (uint256): Amount of USDC yield to add (6 decimals)
- `source` (bytes32): Source key (`"aave"`, `"fees"`, `"interest_differential"`, etc.)

**Access:** Authorized yield sources only

##### `updateYieldDistribution()`
Refreshes and applies current distribution between user and hedger pools.

**Access:** Public (`whenNotPaused`)

##### `claimUserYield(address user) → (uint256)`
Claims yield for user pool.

**Returns:**
- `uint256`: Amount of yield claimed

**Access:** `YIELD_MANAGER_ROLE`

##### `claimHedgerYield(address hedger) → (uint256)`
Claims yield for hedger pool.

**Returns:**
- `uint256`: Amount of yield claimed

**Access:** `YIELD_MANAGER_ROLE`

##### `configureYieldModel((...))`
Batch governance update for:
- `baseYieldShift`
- `maxYieldShift`
- `adjustmentSpeed`
- `targetPoolRatio`

##### `configureDependencies((...))`
Batch governance update for:
- `userPool`
- `hedgerPool`
- `aaveVault`
- `stQEUROFactory`
- `treasury`

##### `setYieldSourceAuthorization(address source, bytes32 yieldType, bool authorized)`
Adds/removes an authorized yield source with explicit yield type mapping.

##### `currentYieldShift() → (uint256)`
Direct state getter for current shift (`1e4` precision).

##### `userPendingYield(address user) → (uint256)` / `hedgerPendingYield(address hedger) → (uint256)`
Direct state getters for pending yield balances.

##### `paused() → (bool)`
Pausable state getter. Yield distribution is active when `paused() == false`.

##### `getPoolMetrics() → (uint256, uint256, uint256, uint256)`
Gets pool metrics for yield calculation.

**Returns:**
- `uint256`: User pool size
- `uint256`: Hedger pool size
- `uint256`: Pool ratio
- `uint256`: Target ratio

**Access:** Public view

##### `calculateOptimalYieldShift() → (uint256, uint256)`
Calculates optimal yield distribution.

**Returns:**
- `uint256`: Optimal shift
- `uint256`: Current deviation from optimal

**Access:** Public view

#### Events

```solidity
event YieldDistributionUpdated(uint256 userPoolYield, uint256 hedgerPoolYield, uint256 currentShift);
event YieldAdded(uint256 yieldAmount, string indexed source, uint256 indexed timestamp);
event UserYieldClaimed(address indexed user, uint256 yieldAmount, uint256 timestamp);
event HedgerYieldClaimed(address indexed hedger, uint256 yieldAmount, uint256 timestamp);
```

---

## Oracle System

The oracle system consists of three contracts. All protocol contracts interact only with **OracleRouter** via the `IOracle` interface — the underlying oracle source can be switched by governance without any changes to the protocol.

### OracleRouter

Routes price requests to the currently active oracle (ChainlinkOracle or StorkOracle).

#### Functions

##### `getLatestPrice() → (uint256, bool)`
Gets the current EUR/USD price from the active oracle.

**Returns:**
- `uint256`: EUR/USD price (18 decimals)
- `bool`: Whether price is valid and fresh

**Access:** Public view

##### `switchOracle(uint8 newOracleType)`
Switches the active oracle between Chainlink (0) and Stork (1).

**Parameters:**
- `newOracleType` (uint8): `0` = Chainlink, `1` = Stork

**Access:** `ORACLE_MANAGER_ROLE`

##### `setOracleAddresses(address chainlink, address stork)`
Updates the underlying oracle contract addresses.

**Parameters:**
- `chainlink` (address): ChainlinkOracle proxy address
- `stork` (address): StorkOracle proxy address

**Access:** `ORACLE_MANAGER_ROLE`

#### Events

```solidity
event OracleSwitched(uint8 oldOracle, uint8 newOracle, address caller);
event OracleAddressesUpdated(address newChainlink, address newStork);
```

---

### ChainlinkOracle

EUR/USD and USDC/USD price feeds via Chainlink AggregatorV3.

**Validation rules:**
- Max staleness: 3600 seconds (1 hour)
- Max deviation: 500 basis points (5%)
- Timestamp drift detection: 900 seconds (15 minutes)

#### Functions

##### `getLatestPrice() → (uint256, bool)`
Gets current EUR/USD price from Chainlink.

**Returns:**
- `uint256`: EUR/USD price (18 decimals)
- `bool`: Whether price is valid and fresh

**Access:** Public view

##### `updatePriceFeeds(address eurUsdFeed, address usdcUsdFeed)`
Updates Chainlink price feed addresses.

**Parameters:**
- `eurUsdFeed` (address): EUR/USD Chainlink aggregator address
- `usdcUsdFeed` (address): USDC/USD Chainlink aggregator address

**Access:** `ORACLE_MANAGER_ROLE`

#### Events

```solidity
event PriceFeedsUpdated(address eurUsdFeed, address usdcUsdFeed);
event CircuitBreakerTriggered(uint256 timestamp);
event CircuitBreakerReset(uint256 timestamp);
```

---

### StorkOracle

EUR/USD and USDC/USD price feeds via Stork Network. Same `IOracle` interface as ChainlinkOracle.

**Validation rules:** identical to ChainlinkOracle (staleness, deviation, timestamp drift).

#### Functions

##### `getLatestPrice() → (uint256, bool)`
Gets current EUR/USD price from Stork Network.

**Returns:**
- `uint256`: EUR/USD price (18 decimals)
- `bool`: Whether price is valid and fresh

**Access:** Public view

##### `updateFeedIds(bytes32 eurUsdId, bytes32 usdcUsdId)`
Updates Stork feed IDs.

**Parameters:**
- `eurUsdId` (bytes32): EUR/USD Stork feed ID (default: `keccak256("EURUSD")`)
- `usdcUsdId` (bytes32): USDC/USD Stork feed ID (default: `keccak256("USDCUSD")`)

**Access:** `ORACLE_MANAGER_ROLE`

#### Events

```solidity
event FeedIdsUpdated(bytes32 eurUsdId, bytes32 usdcUsdId);
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

// 3. Monitor hedger activity / claim rewards
bool hedgerActive = hedgerPool.hasActiveHedger();
(uint256 interestDiff, uint256 ysRewards, uint256 total) = hedgerPool.claimHedgingRewards();
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

*This documentation is maintained by Quantillon Labs and updated regularly. Last updated: March 2026*
