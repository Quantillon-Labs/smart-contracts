# Quantillon Protocol API Reference

## Technical API Reference

This document provides detailed technical specifications for all Quantillon Protocol smart contract interfaces.

---

## Contract Addresses

Deployed addresses for **Base Mainnet (chain ID `8453`)**. The machine-readable registry `deployments/8453/addresses.json` is a local deployment artifact (gitignored, not published); the tracked [`deployments/8453/versions.json`](https://github.com/Quantillon-Labs/smart-contracts/blob/main/quantillon-protocol/deployments/8453/versions.json) carries the proxy and implementation address plus the live `version()` of every upgradeable contract. All core contracts are UUPS proxies — the addresses below are the stable proxy addresses that integrators should use.

### Core protocol

| Contract | Address |
|----------|---------|
| QuantillonVault | `0x833E5Ba510a241b21F1C60c987D1c49eB52E4a07` |
| QEUROToken | `0x69aD4e6c49d6275D0e11b5515D98a89f029869AA` |
| QTIToken | `0x246c6F441c0f8Fc6A71Db0F12dB5665D373Df271` |
| UserPool | `0x712bCc77e7aa53C79870A40d044D440Ad2901bF2` |
| HedgerPool | `0xff5D7cE5c7671B2EA805Ee752B4f8eC9Ecf2975A` |
| FeeCollector | `0x0A33F72683cfC2303639d5cB9A45D77fF16d9FAD` |
| YieldShift | `0xdcd66568F8623bDa3387287c31F14b43e49665b1` |
| stQEUROFactory | `0x0382B0b9FB6Ff737209C3B31D727BB9d2E2bcb53` |
| stQEUROToken | per-vault — deployed by `stQEUROFactory`, resolve via `getStQEUROByVaultId(vaultId)` |

### Oracles

| Contract | Address | Status |
|----------|---------|--------|
| OracleRouter | `0x7ED6aaEd83Db69509A88CAe5C247ef8fA44056E0` | entry point for all protocol price reads |
| HyperliquidEurUsdOracle | `0x0B58aBB57775E0fCEDfd4460e00dD9D9610C2C43` | **ACTIVE** (router slot 1) |
| ChainlinkOracle | `0xaEE3c9c298051ef7242882AbCaE2Fd12d29443E7` | fallback (router slot 0); USDC/USD source |
| StorkOracle | `0x41FcE00E33Ca4f0d8E5528c343FAC98BA178EebC` | parked (replaced in slot 1 by HyperliquidEurUsdOracle) |
| LighterEurUsdOracle | `0xcd53182a430d48Be0f414CCA022ABA5d05903536` | deployed 2026-07-17, inert: holds no router slot and the Lighter venue was not adopted (decision of 2026-09-01) |
| SlippageStorage | `0x0fde0ff2566be3c24af6d654012dddb4f1da099b` | on-chain price store feeding HyperliquidEurUsdOracle |
| TimeProvider | `0x520236487CBD0a6958B4EefC7853cd7C3F5C56E7` | timestamp wrapper (deployed directly, not proxied) |

> Protocol contracts depend only on `OracleRouter` (which implements `IOracle`). The router has two slots — `enum OracleType { CHAINLINK, MARKET }` (slot 1 was named `STORK` before router v1.1.0; the live router is v1.1.1) — switchable in one governance transaction via `switchOracle`. Slot 1 currently hosts **`HyperliquidEurUsdOracle`, the active production oracle** (`activeOracle = 1`); read it via `marketOracle()` (the pre-1.1.0 `storkOracle()` getter remains as a deprecated alias). Slot 0 (`ChainlinkOracle`) is the fallback and remains the USDC/USD source.

### Governance & infrastructure

| Contract | Address | Notes |
|----------|---------|-------|
| Gnosis Safe (governance) | `0x1d7fF432a93d0085Fb69474c7E567f859829e6cd` | 2-of-3; holds all privileged roles |
| TimelockController | `0x7Ade8f3Bf1FdaF0785efE9Ea5C6339D1aD6B8342` | OpenZeppelin `TimelockController`, 12 h delay, Safe = sole proposer/executor. Gates upgrades of the eight `SecureUpgradeable` proxies (QuantillonVault, QEUROToken, QTIToken, UserPool, HedgerPool, YieldShift, stQEUROFactory, per-vault stQEUROToken). FeeCollector, OracleRouter, ChainlinkOracle, HyperliquidEurUsdOracle, LighterEurUsdOracle (inert), StorkOracle and SlippageStorage are plain UUPS proxies whose upgrade role is held by the Safe: they upgrade in a single Safe transaction, with no timelock |

### External vault adapters (onboarded post-core)

External staking adapters are onboarded after core deployment via `setup-external-vaults.sh` and are tracked per `vaultId`, not in `addresses.json`. Currently live:

| Adapter | Address | `vaultId` |
|---------|---------|-----------|
| MetaMorphoStakingVaultAdapter | `0xb2f253Cd74ebfa16894339438B467396De9e8EA3` | 2 |

> The previous vaultId-2 adapter (`0x103aEBD0059AAA3DcCaa9ab0cCb901382Bd48978`) was migrated to the address above on 2026-07-01. Per-vault adapter records (`deployments/8453/*-adapter.json`) are local deployment artifacts and are not tracked in this repository; the live binding is readable on-chain via `QuantillonVault.getVaultExposure(2)`.

### Per-vault stQEURO tokens

`addresses.json` intentionally lists `stQEUROToken` as the zero address: stQEURO is deployed **per external vault** by `stQEUROFactory` and must be resolved at runtime via `getStQEUROByVaultId(vaultId)`. Currently live:

| Vault | `vaultId` | stQEURO proxy | Underlying vault |
|-------|-----------|---------------|------------------|
| MORPHO1 (MetaMorpho) | 2 | `0x17CD8ed967d17072297CcAe3D379C9e86aeBEb1d` | `0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2` |

### External dependencies

| Token / Feed | Address |
|--------------|---------|
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| Chainlink EUR/USD feed | `0xc91D87E81faB8f93699ECf7Ee9B44D11e1D53F0F` |
| Chainlink USDC/USD feed | `0x7e860098F58bBFC8648a4311b374B1D669a2bc6B` |

---

## QuantillonVault

**Contract**: `QuantillonVault.sol`  
**Interface**: `IQuantillonVault.sol`  
**Inherits**: `SecureUpgradeable`, `PausableUpgradeable`

### Function Signatures

#### `initialize(address admin, address _qeuro, address _usdc, address _oracle, address _hedgerPool, address _userPool, address _timelock, address _feeCollector)`
```solidity
function initialize(
    address admin,
    address _qeuro,
    address _usdc,
    address _oracle,
    address _hedgerPool,
    address _userPool,
    address _timelock,
    address _feeCollector
) external
```

**Modifiers**: `initializer`  
**Notes**:
- `_hedgerPool` and `_userPool` can be wired later through governance setters.
- `_timelock` is also used as treasury destination for recovery flows.

#### `mintQEURO(uint256 usdcAmount, uint256 minQeuroOut)`
```solidity
function mintQEURO(
    uint256 usdcAmount,
    uint256 minQeuroOut
) external
```

**Modifiers**: `whenNotPaused`, `nonReentrant`  
**Events**: `QEUROminted(address indexed user, uint256 usdcAmount, uint256 qeuroAmount)`  
**Requirements**:
- `usdcAmount > 0`
- Price cache initialized (`initializePriceCache`)
- Active hedger configured (`hedgerPool.hasActiveHedger()`)
- Sufficient USDC balance and allowance
- Projected post-mint collateralization ratio must remain above threshold

#### `redeemQEURO(uint256 qeuroAmount, uint256 minUsdcOut)`
```solidity
function redeemQEURO(
    uint256 qeuroAmount,
    uint256 minUsdcOut
) external
```

**Modifiers**: `whenNotPaused`, `nonReentrant`  
**Events**: `QEURORedeemed(address indexed user, uint256 qeuroAmount, uint256 usdcAmount)`  
**Requirements**:
- `qeuroAmount > 0`
- Sufficient QEURO balance and allowance
- Automatically routes to liquidation mode when protocol CR is at or below critical threshold
- Pulls liquidity from external vault adapters when needed (tracked principal only; unharvested adapter yield is not used as redemption collateral)

#### `calculateMintAmount(uint256 usdcAmount) → (uint256, uint256)`
```solidity
function calculateMintAmount(uint256 usdcAmount) external view returns (uint256 qeuroAmount, uint256 fee)
```

**Returns**:
- `qeuroAmount`: Amount of QEURO that would be minted (18 decimals)
- `fee`: Mint fee amount (USDC, 6 decimals)

**Notes**:
- Uses cached EUR/USD price path (`lastValidEurUsdPrice`).

#### `calculateRedeemAmount(uint256 qeuroAmount) → (uint256, uint256)`
```solidity
function calculateRedeemAmount(uint256 qeuroAmount) external view returns (uint256 usdcAmount, uint256 fee)
```

**Returns**:
- `usdcAmount`: Amount of USDC that would be received (6 decimals)
- `fee`: Redemption fee amount (USDC, 6 decimals)

**Notes**:
- Uses cached EUR/USD price path (`lastValidEurUsdPrice`).

#### Vault balance getters (public state)
```solidity
uint256 public totalUsdcHeld;              // USDC held directly by the vault
uint256 public totalMinted;                // QEURO minted by vault tracker
uint256 public totalUsdcInExternalVaults;  // Principal tracked across external vault adapters
```

**Notes**:
- The aggregated `getVaultMetrics()` helper was retired in the external
  multi-vault refactor (EIP-170 headroom); read the three public trackers
  directly, and use `getProtocolCollateralizationRatio()` for debt/collateral
  ratio math (`1e20` = 100%). Total available collateral = `totalUsdcHeld +
  totalUsdcInExternalVaults` (unharvested adapter yield is excluded).

#### `getProtocolCollateralizationRatio() → (uint256)`
```solidity
function getProtocolCollateralizationRatio() public view returns (uint256 ratio)
```

**Returns**: Current protocol collateralization ratio in 18-decimal percentage format (`100% = 1e20`)

**Description**: Calculates `CR = (TotalCollateral / BackingRequirement) * 1e20` where:
- `TotalCollateral` = `totalUsdcHeld + tracked external-vault principal` (unharvested adapter yield is excluded; it accrues to stQEURO holders via `harvestAndDistributeVaultYield`/`creditVaultYield`)
- `BackingRequirement` = `QEUROSupply * cachedEurUsdPrice / 1e30`

**Note**: This function uses cached price and returns `0` when required wiring/cache prerequisites are not met.

**Requirements**:
- Both HedgerPool and UserPool must be set
- Initialized cached price
- QEURO supply > 0

#### `canMint() → (bool)`
```solidity
function canMint() public view returns (bool)
```

**Returns**: `true` if minting is allowed, `false` otherwise

**Description**: Checks if minting is allowed under current safeguards:
- Cached price must be initialized.
- Active hedger must exist.
- Collateralization ratio must be >= `minCollateralizationRatioForMinting`.

#### `initializePriceCache()`
Governance-only bootstrap step required after deployment and before first user mint.

#### `updateHedgerRewardFeeSplit(uint256 newSplit)`
Governance setter for fee routing share to HedgerPool reserve (`1e18 = 100%`).

#### `mintQEUROToVault(uint256 usdcAmount, uint256 minQeuroOut, uint256 vaultId)`
User entrypoint for minting QEURO and routing collateral to a specific external vault adapter.

#### `mintAndStakeQEURO(uint256 usdcAmount, uint256 minQeuroOut, uint256 vaultId, uint256 minStQEUROOut) → (uint256 qeuroMinted, uint256 stQEUROMinted)`
One-step user entrypoint to mint QEURO and stake into the vault-specific stQEURO token.

#### `deployUsdcToVault(uint256 vaultId, uint256 usdcAmount)`
Vault-operator entrypoint for manual collateral deployment to a specific adapter.

#### `harvestAndDistributeVaultYield(uint256 vaultId)`
Keeper entrypoint (`YIELD_DISTRIBUTOR_ROLE`) that realizes a vault's external yield and splits it: hedger funding first (time-prorated `fundingRateAnnualBps` on tracked principal, capped at realized yield), residual to stQEURO stakers as QEURO backing, remainder to treasury. Emits `VaultYieldDistributed(vaultId, realizedYield, hedgerShare, userShare, treasuryShare)`. See the Staking Yield Distribution guide.

#### `creditVaultYield(uint256 vaultId, uint256 usdcAmount) → (uint256 qeuroMinted)`
`YIELD_DISTRIBUTOR_ROLE` entrypoint crediting externally realized USDC yield into a vault's stQEURO backing.

#### `harvestConfig(uint256 vaultId) → (uint256 fundingRateBps, address hedgerRecipient, uint256 lastHarvest)`
Read-only view of the distribution parameters and the vault's last-harvest timestamp.

#### `setFundingRateAnnualBps(uint256 newRateBps)` / `setHedgerYieldRecipient(address newRecipient)`
Governance setters for the hedger funding carve-out and its recipient. Emit `FundingRateUpdated` /
`HedgerYieldRecipientUpdated` (restored in v1.1.1).

### Events

```solidity
event QEUROminted(address indexed user, uint256 usdcAmount, uint256 qeuroAmount);
event QEURORedeemed(address indexed user, uint256 qeuroAmount, uint256 usdcAmount);
event LiquidationRedeemed(address indexed user, uint256 qeuroAmount, uint256 usdcPayout, uint256 collateralizationRatioBps, bool isPremium);
event ProtocolFeeRouted(string sourceType, uint256 totalFee, uint256 hedgerReserveShare, uint256 collectorShare);
event StakingVaultConfigured(uint256 indexed vaultId, address indexed adapter, bool active);
event UsdcDeployedToExternalVault(uint256 indexed vaultId, uint256 indexed usdcAmount, uint256 principalInVault);
event UsdcWithdrawnFromExternalVault(uint256 indexed vaultId, uint256 indexed usdcAmount, uint256 principalInVault);
event VaultYieldDistributed(uint256 indexed vaultId, uint256 realizedYield, uint256 hedgerShare, uint256 userShare, uint256 treasuryShare);
```

---

## QEUROToken

**Contract**: `QEUROToken.sol`  
**Interface**: `IQEUROToken.sol`  
**Inherits**: `ERC20Upgradeable`, `AccessControlUpgradeable`, `PausableUpgradeable`, `SecureUpgradeable` (timelock-gated upgrades)

### Function Signatures

#### `mint(address to, uint256 amount)`
```solidity
function mint(address to, uint256 amount) external
```

**Modifiers**: `onlyRole(MINTER_ROLE)` (held by `QuantillonVault`), `whenNotPaused`
**Events**: `TokensMinted(address indexed to, uint256 indexed amount, address indexed minter)`
**Requirements**:
- Minting killswitch off (`mintingKillswitch() == false`, else `MintingDisabled`)
- `amount > 0`; `to` passes the compliance checks (`BlacklistedAddress`; `NotWhitelisted` while whitelist mode is on)
- `totalSupply() + amount <= maxSupply()` (`WouldExceedLimit`)
- Within the mint rate limit (`rateLimitCaps().mint` per 300-block window, else `RateLimitExceeded`)

#### `burn(address from, uint256 amount)`
```solidity
function burn(address from, uint256 amount) external
```

**Modifiers**: `onlyRole(BURNER_ROLE)` (held by `QuantillonVault`), `whenNotPaused`
**Events**: `TokensBurned(address indexed from, uint256 indexed amount, address indexed burner)`
**Requirements**:
- `amount > 0` and `balanceOf(from) >= amount`
- Within the burn rate limit (`rateLimitCaps().burn` per 300-block window, else `RateLimitExceeded`)

#### `batchMint(address[] recipients, uint256[] amounts)` / `batchBurn(address[] froms, uint256[] amounts)`
Batched variants of `mint` / `burn` (same roles and checks; at most `MAX_BATCH_SIZE = 100` entries).

#### `whitelistAddress(address account)` / `unwhitelistAddress(address account)`
**Modifiers**: `onlyRole(COMPLIANCE_ROLE)`
**Events**: `AddressWhitelisted(address indexed account)` / `AddressUnwhitelisted(address indexed account)`

#### `blacklistAddress(address account, string reason)` / `unblacklistAddress(address account)`
**Modifiers**: `onlyRole(COMPLIANCE_ROLE)`
**Events**: `AddressBlacklisted(address indexed account, string indexed reason)` / `AddressUnblacklisted(address indexed account)`

Batched variants: `batchWhitelistAddresses`, `batchUnwhitelistAddresses`, `batchBlacklistAddresses(address[] accounts, string[] reasons)`, `batchUnblacklistAddresses` (`MAX_COMPLIANCE_BATCH_SIZE = 50`). `toggleWhitelistMode(bool enabled)` (`COMPLIANCE_ROLE`) emits `WhitelistModeToggled(bool enabled)`.

#### `updateMaxSupply(uint256 newMaxSupply)`
```solidity
function updateMaxSupply(uint256 newMaxSupply) external
```

**Modifiers**: `onlyRole(DEFAULT_ADMIN_ROLE)`
**Events**: `SupplyCapUpdated(uint256 oldCap, uint256 newCap)`
**Requirements**: `newMaxSupply >= totalSupply()` (otherwise `NewCapBelowCurrentSupply`)

#### `updateRateLimits(uint256 newMintLimit, uint256 newBurnLimit)`
**Modifiers**: `onlyRole(DEFAULT_ADMIN_ROLE)` — each limit must be `<= MAX_RATE_LIMIT` (10M QEURO), else `RateLimitTooHigh`
**Events**: `RateLimitsUpdated(string indexed limitType, uint256 mintLimit, uint256 burnLimit)`

#### `setMintingKillswitch(bool enabled)`
**Modifiers**: `onlyRole(PAUSER_ROLE)`
**Events**: `MintingKillswitchToggled(bool enabled, address indexed caller)`

#### `getTokenInfo() → (string, string, uint8, uint256, uint256, bool, bool, uint256, uint256)`
```solidity
function getTokenInfo() external view returns (
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    uint256 totalSupply_,
    uint256 maxSupply_,
    bool isPaused_,
    bool whitelistEnabled_,
    uint256 mintRateLimit_,
    uint256 burnRateLimit_
)
```

#### State getters
`maxSupply()`, `getSupplyUtilization()`, `rateLimitCaps() → (uint128 mint, uint128 burn)`, `mintRateLimit()`, `burnRateLimit()`, `rateLimitInfo() → (uint96 currentHourMinted, uint96 currentHourBurned, uint64 lastRateLimitReset)`, `mintingKillswitch()`, `whitelistEnabled()`, `isWhitelisted(address)`, `isBlacklisted(address)`, `isMinter(address)`, `isBurner(address)`.

### Events

```solidity
event TokensMinted(address indexed to, uint256 indexed amount, address indexed minter);
event TokensBurned(address indexed from, uint256 indexed amount, address indexed burner);
event AddressWhitelisted(address indexed account);
event AddressUnwhitelisted(address indexed account);
event AddressBlacklisted(address indexed account, string indexed reason);
event AddressUnblacklisted(address indexed account);
event WhitelistModeToggled(bool enabled);
event SupplyCapUpdated(uint256 oldCap, uint256 newCap);
event RateLimitsUpdated(string indexed limitType, uint256 mintLimit, uint256 burnLimit);
event RateLimitReset(uint256 indexed blockNumber);
event MintingKillswitchToggled(bool enabled, address indexed caller);
```

---

## QTIToken

**Contract**: `QTIToken.sol`  
**Inherits**: `ERC20Upgradeable`, `AccessControlUpgradeable`, `PausableUpgradeable`, `SecureUpgradeable` (timelock-gated upgrades)

### Function Signatures

#### `lock(uint256 amount, uint256 lockTime) → (uint256)`
```solidity
function lock(uint256 amount, uint256 lockTime) external returns (uint256 veQTI)
```

**Modifiers**: `whenNotPaused`, `nonReentrant`  
**Events**: `TokensLocked(address indexed user, uint256 amount, uint256 lockTime, uint256 votingPower)`  
**Requirements**:
- `amount > 0`
- `lockTime >= MIN_LOCK_TIME && lockTime <= MAX_LOCK_TIME`
- Sufficient QTI balance

#### `unlock() → (uint256)`
```solidity
function unlock() external returns (uint256 amount)
```

**Modifiers**: `whenNotPaused`, `nonReentrant`  
**Events**: `TokensUnlocked(address indexed user, uint256 amount)`  
**Requirements**: Lock period has expired

#### `getVotingPower(address user) → (uint256)`
```solidity
function getVotingPower(address user) external view returns (uint256 votingPower)
```

#### `getLockInfo(address user) → (uint256, uint256, uint256, uint256)`
```solidity
function getLockInfo(address user) external view returns (
    uint256 lockedAmount,
    uint256 lockTime,
    uint256 unlockTime,
    uint256 currentVotingPower
)
```

#### `createProposal(string memory description, uint256 startTime, uint256 endTime) → (uint256)`
```solidity
function createProposal(
    string memory description,
    uint256 startTime,
    uint256 endTime
) external returns (uint256 proposalId)
```

**Modifiers**: `whenNotPaused`  
**Events**: `ProposalCreated(uint256 indexed proposalId, string description, uint256 startTime, uint256 endTime)`  
**Requirements**:
- Sufficient voting power
- Valid time parameters

#### `vote(uint256 proposalId, bool support)`
```solidity
function vote(uint256 proposalId, bool support) external
```

**Modifiers**: `whenNotPaused`  
**Events**: `VoteCast(address indexed voter, uint256 indexed proposalId, bool support, uint256 votingPower)`  
**Requirements**:
- Voting period active
- Sufficient voting power
- Not already voted

### Events

```solidity
event TokensLocked(address indexed user, uint256 amount, uint256 lockTime, uint256 votingPower);
event TokensUnlocked(address indexed user, uint256 amount);
event ProposalCreated(uint256 indexed proposalId, string description, uint256 startTime, uint256 endTime);
event VoteCast(address indexed voter, uint256 indexed proposalId, bool support, uint256 votingPower);
```

---

## UserPool

**Contract**: `UserPool.sol`
**Interface**: `IUserPool.sol`
**Inherits**: `SecureUpgradeable`, `PausableUpgradeable`, `ReentrancyGuardUpgradeable`

Optional batch front-end over the vault: `deposit` mints QEURO through `QuantillonVault.mintQEURO` and sends it to the caller's wallet, `withdraw` pulls QEURO from the caller's wallet and redeems it through `QuantillonVault.redeemQEURO`, and `stake` / `requestUnstake` / `unstake` escrow QEURO behind a cooldown. User yield does **not** accrue here — it accrues through the per-vault **stQEURO** ERC-4626 token (see [stQEUROToken](#stqeurotoken)); the former staking-reward claim path was removed. Every user-facing amount function takes arrays (use a one-element array for a single operation); batches are capped at `MAX_BATCH_SIZE = 100`.

### Function Signatures

#### `deposit(uint256[] usdcAmounts, uint256[] minQeuroOuts) → (uint256[] qeuroMintedAmounts)`
```solidity
function deposit(uint256[] calldata usdcAmounts, uint256[] calldata minQeuroOuts)
    external returns (uint256[] memory qeuroMintedAmounts)
```

**Modifiers**: `nonReentrant`, `whenNotPaused`
**Events**: `UserDeposit(address indexed user, uint256 usdcAmount, uint256 qeuroMinted, uint256 timestamp)` and `UserDepositTracked(...)` per entry
**Requirements**:
- `usdcAmounts.length == minQeuroOuts.length`, non-empty, at most `MAX_BATCH_SIZE` (`ArrayLengthMismatch` / `EmptyArray` / `BatchSizeTooLarge`)
- each `usdcAmounts[i] > 0` (6 decimals); `minQeuroOuts[i]` is the per-entry slippage floor (18 decimals)
- Sufficient USDC balance and allowance to the UserPool; the vault must accept the mint (`QuantillonVault.canMint()`)

#### `withdraw(uint256[] qeuroAmounts, uint256[] minUsdcOuts) → (uint256[] usdcReceivedAmounts)`
```solidity
function withdraw(uint256[] calldata qeuroAmounts, uint256[] calldata minUsdcOuts)
    external returns (uint256[] memory usdcReceivedAmounts)
```

**Modifiers**: `nonReentrant`, `whenNotPaused`
**Events**: `UserWithdrawal(address indexed user, uint256 qeuroBurned, uint256 usdcReceived, uint256 timestamp)` and `UserWithdrawalTracked(...)` per entry; `WithdrawalPending(user, amount)` when the USDC transfer to the user fails (e.g. USDC blacklist)
**Requirements**:
- array lengths match, non-empty, at most `MAX_BATCH_SIZE`; each `qeuroAmounts[i] > 0` (18 decimals)
- Sufficient QEURO balance in the caller's wallet and allowance to the UserPool; `minUsdcOuts[i]` is the per-entry slippage floor (6 decimals)

#### `claimPendingWithdrawal()`
Pulls USDC that was queued in `pendingUsdcWithdrawals(user)` after a failed transfer during `withdraw`. `nonReentrant`, `whenNotPaused`; emits `PendingWithdrawalClaimed(address indexed user, uint256 amount)`; reverts `InsufficientBalance` when nothing is pending.

#### `stake(uint256[] qeuroAmounts)`
```solidity
function stake(uint256[] calldata qeuroAmounts) external
```

**Modifiers**: `nonReentrant`, `whenNotPaused`
**Events**: `QEUROStaked(address indexed user, uint256 qeuroAmount, uint256 timestamp)` per entry
**Requirements**:
- non-empty, at most `MAX_BATCH_SIZE` entries; each `qeuroAmounts[i] >= minStakeAmount()` (*settable*; 100 QEURO live)
- Sufficient QEURO balance and allowance to the UserPool

#### `requestUnstake(uint256 qeuroAmount)`
```solidity
function requestUnstake(uint256 qeuroAmount) external
```

**Modifiers**: `nonReentrant`
Starts the unstaking cooldown (`unstakingCooldown()`, 7 days live) for `qeuroAmount` of the caller's staked balance; recorded in `getUserInfo(user).unstakeAmount` / `.unstakeRequestTime`.

#### `unstake()`
```solidity
function unstake() external
```

**Modifiers**: `nonReentrant`, `whenNotPaused`
**Events**: `QEUROUnstaked(address indexed user, uint256 qeuroAmount, uint256 timestamp)`
**Requirements**: a pending `requestUnstake` whose cooldown has elapsed. Transfers the requested QEURO back to the caller.

#### `getUserInfo(address user) → (uint256 × 7)`
```solidity
function getUserInfo(address user) external view returns (
    uint256 qeuroBalance,        // legacy field, never written: deposited QEURO goes to the user's wallet
    uint256 stakedAmount,        // QEURO currently staked (18 decimals)
    uint256 pendingRewards,      // always 0: the staking-reward path was removed
    uint256 depositHistory,      // cumulative USDC deposited (6 decimals)
    uint256 lastStakeTime,
    uint256 unstakeAmount,       // QEURO in a pending unstake request
    uint256 unstakeRequestTime
)
```

#### Pool views
```solidity
function getPoolTotals() external view returns (uint256 totalDeposits, uint256 totalWithdrawals, uint256 totalStakes_, uint256 totalUsers_);
function getPoolMetrics() external view returns (uint256 totalUsers_, uint256 averageDeposit, uint256 stakingRatio, uint256 poolTVL);
function getPoolConfiguration() external view returns (uint256 stakingAPY_, uint256 depositAPY_, uint256 minStakeAmount_, uint256 unstakingCooldown_, uint256 performanceFee_);
function getTotalDeposits() external view returns (uint256);
function getTotalStakes() external view returns (uint256);
function isPoolActive() external view returns (bool);
function getUserDepositHistory(address user) external view returns (UserDepositInfo[] memory);
function getUserWithdrawals(address user) external view returns (UserWithdrawalInfo[] memory);
```
Public state getters: `stakingAPY()`, `depositAPY()`, `minStakeAmount()`, `unstakingCooldown()`, `performanceFee()`, `totalStakes()`, `totalUsers()`, `totalUserDeposits()`, `totalUserWithdrawals()`, `pendingUsdcWithdrawals(address)`, `hasDeposited(address)`, `userInfo(address)`.

#### Governance / emergency
- `updateStakingParameters(uint256 newStakingAPY, uint256 newMinStakeAmount, uint256 newUnstakingCooldown)` — `GOVERNANCE_ROLE`; APY capped at 5000 bps. Emits `PoolParameterUpdated(string indexed parameter, uint256 oldValue, uint256 newValue)` for each field.
- `setPerformanceFee(uint256 _performanceFee)` — `GOVERNANCE_ROLE`; max 2000 bps. Mint / redemption fees live in `QuantillonVault`, not here.
- `emergencyUnstake(address user, address recipient)` — `EMERGENCY_ROLE`; force-unstakes a user's full staked balance to `recipient` (defaults to `user`).

### Events

```solidity
event UserDeposit(address indexed user, uint256 usdcAmount, uint256 qeuroMinted, uint256 timestamp);
event UserWithdrawal(address indexed user, uint256 qeuroBurned, uint256 usdcReceived, uint256 timestamp);
event UserDepositTracked(address indexed user, uint256 usdcAmount, uint256 qeuroReceived, uint256 oracleRatio, uint256 timestamp, uint256 blockNumber);
event UserWithdrawalTracked(address indexed user, uint256 qeuroAmount, uint256 usdcReceived, uint256 oracleRatio, uint256 timestamp, uint256 blockNumber);
event WithdrawalPending(address indexed user, uint256 amount);
event PendingWithdrawalClaimed(address indexed user, uint256 amount);
event QEUROStaked(address indexed user, uint256 qeuroAmount, uint256 timestamp);
event QEUROUnstaked(address indexed user, uint256 qeuroAmount, uint256 timestamp);
event PoolParameterUpdated(string indexed parameter, uint256 oldValue, uint256 newValue);
```

---

## HedgerPool

**Contract**: `HedgerPool.sol`  
**Interface**: `IHedgerPool.sol`  
**Inherits**: `SecureUpgradeable`, `PausableUpgradeable`

### Function Signatures

#### `enterHedgePosition(uint256 usdcAmount, uint256 leverage) → (uint256)`
```solidity
function enterHedgePosition(
    uint256 usdcAmount,
    uint256 leverage
) external returns (uint256 positionId)
```

**Modifiers**: `whenNotPaused`, `nonReentrant`  
**Events**: `HedgePositionOpened(address indexed hedger, uint256 indexed positionId, bytes32 packedData)`  
**Requirements**:
- `usdcAmount > 0`
- `leverage >= 1 && leverage <= maxLeverage`
- Caller must be configured `singleHedger`
- Fresh oracle price
- Sufficient USDC balance and allowance

#### `exitHedgePosition(uint256 positionId) → (int256)`
```solidity
function exitHedgePosition(uint256 positionId) external returns (int256 pnl)
```

**Modifiers**: `whenNotPaused`, `nonReentrant`  
**Events**: `HedgePositionClosed(address indexed hedger, uint256 indexed positionId, bytes32 packedData)`  
**Requirements**:
- Position exists and is active
- Caller owns the position

#### `addMargin(uint256 positionId, uint256 usdcAmount)`
```solidity
function addMargin(uint256 positionId, uint256 usdcAmount) external
```

**Modifiers**: `whenNotPaused`, `nonReentrant`  
**Events**: `MarginUpdated(address indexed hedger, uint256 indexed positionId, bytes32 packedData)`  
**Requirements**:
- Position exists and is active
- Caller owns the position
- `usdcAmount > 0`
- Margin fee is split between local reward reserve and FeeCollector

#### `removeMargin(uint256 positionId, uint256 usdcAmount)`
```solidity
function removeMargin(uint256 positionId, uint256 usdcAmount) external
```

**Modifiers**: `whenNotPaused`, `nonReentrant`  
**Events**: `MarginUpdated(address indexed hedger, uint256 indexed positionId, bytes32 packedData)`  
**Requirements**:
- Position exists and is active
- Caller owns the position
- Maintains minimum margin ratio

#### `claimHedgingRewards() → (uint256, uint256, uint256)`
```solidity
function claimHedgingRewards() external returns (uint256 interestDifferential, uint256 yieldShiftRewards, uint256 totalRewards)
```

**Modifiers**: `nonReentrant`
**Events**: none (the former `HedgingRewardsClaimed` event was removed in v1.0.1; watch `RewardReserveFunded` and USDC transfers instead)
**Requirements**:
- Caller must be configured `singleHedger`
- YieldShift reward component is settled once through YieldShift

#### `withdrawPendingRewards(address recipient)`
```solidity
function withdrawPendingRewards(address recipient) external
```

Pull-based fallback for pending reward escrow after failed push-transfer.

#### `hasActiveHedger() → (bool)`
```solidity
function hasActiveHedger() external view returns (bool)
```

Returns true when the configured single hedger has an active position.

#### `getTotalEffectiveHedgerCollateral(uint256 currentPrice) → (uint256)`
```solidity
function getTotalEffectiveHedgerCollateral(uint256 currentPrice) external view returns (uint256 totalEffectiveCollateral)
```

**Returns**: Total effective hedger collateral in USDC (6 decimals)  
**Requirements**:
- `currentPrice > 0`

#### `setSingleHedger(address hedger)`
Governance entrypoint for bootstrap/reassignment. Assignment is synchronous: it succeeds only while the backing position (positionId 1) is inactive, and reverts otherwise. (The former delayed `applySingleHedgerRotation` path was removed as dead code — it could overwrite a live backing position.)

#### `fundRewardReserve(uint256 amount)`
Permissionless reserve top-up path for hedger rewards.

#### `configureRiskAndFees(HedgerRiskConfig cfg)`
Batch governance setter for risk + fee parameters:
- `minMarginRatio`
- `maxLeverage`
- `minPositionHoldBlocks`
- `minMarginAmount`
- `eurInterestRate`
- `usdInterestRate`
- `entryFee`
- `exitFee`
- `marginFee`
- `rewardFeeSplit` (`1e18 = 100%`)

#### `configureDependencies(HedgerDependencyConfig cfg)`
Batch governance setter for:
- `treasury`
- `vault`
- `oracle`
- `yieldShift`
- `feeCollector`

### Events

```solidity
event HedgePositionOpened(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
event HedgePositionClosed(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
event MarginUpdated(address indexed hedger, uint256 indexed positionId, bytes32 packedData);
event RewardReserveFunded(address indexed funder, uint256 amount);
event SingleHedgerRotationApplied(address indexed previousHedger, address indexed newHedger);
event EmergencyPositionClosed(address indexed hedger, uint256 indexed positionId, uint256 marginReturned, uint256 exposureRemoved);
```

---

## stQEUROFactory

**Contract**: `stQEUROFactory.sol`  
**Interface**: `IStQEUROFactory.sol`  
**Inherits**: `AccessControlUpgradeable`, `SecureUpgradeable`

### Function Signatures

#### `registerVault(uint256 vaultId, string vaultName) -> (address stQEUROToken_)`
```solidity
function registerVault(uint256 vaultId, string calldata vaultName) external returns (address stQEUROToken_);
```

**Modifiers**: `onlyRole(VAULT_FACTORY_ROLE)`  
**Events**: `VaultRegistered(uint256 indexed vaultId, address indexed vault, address indexed stQEUROToken, string vaultName)`  
**Requirements**:
- `vaultId > 0`
- `vaultName` uppercase alphanumeric with length `1..12`
- unique `vaultId`, unique caller vault, unique `vaultName`
- strict self-registration semantics: caller vault is inferred from `msg.sender`

#### `getStQEUROByVaultId(uint256 vaultId) -> (address)`
```solidity
function getStQEUROByVaultId(uint256 vaultId) external view returns (address stQEUROToken_);
```

#### `getStQEUROByVault(address vault) -> (address)`
```solidity
function getStQEUROByVault(address vault) external view returns (address stQEUROToken_);
```

#### `getVaultById(uint256 vaultId) -> (address)`
```solidity
function getVaultById(uint256 vaultId) external view returns (address vault);
```

#### `getVaultIdByStQEURO(address stQEUROToken_) -> (uint256)`
```solidity
function getVaultIdByStQEURO(address stQEUROToken_) external view returns (uint256 vaultId);
```

#### `getVaultName(uint256 vaultId) -> (string)`
```solidity
function getVaultName(uint256 vaultId) external view returns (string memory vaultName);
```

#### `updateYieldShift(address)` / `updateTokenImplementation(address)` / `updateOracle(address)` / `updateTreasury(address)` / `updateTokenAdmin(address)`
Governance configuration setters affecting future vault token deployments and defaults.

### Events

```solidity
event VaultRegistered(uint256 indexed vaultId, address indexed vault, address indexed stQEUROToken, string vaultName);
event FactoryConfigUpdated(string indexed key, address oldValue, address newValue);
```

---

## stQEUROToken

**Contract**: `stQEUROToken.sol`
**Interface**: `IstQEURO.sol`
**Inherits**: `ERC4626Upgradeable`, `AccessControlUpgradeable`, `PausableUpgradeable`, `ReentrancyGuardUpgradeable`, `SecureUpgradeable`

Per-vault, yield-bearing **ERC-4626** vault whose underlying `asset()` is QEURO. One proxy is deployed per staking vault by `stQEUROFactory` (live: `stQEUROMORPHO1`, `vaultId = 2`). There is **no rebasing and no claim call**: the share price `totalAssets() / totalSupply()` rises when `QuantillonVault.creditVaultYield` mints QEURO into the token without minting shares (see the [Staking Yield Distribution](./Staking-Yield-Distribution.md) guide). Roles are `GOVERNANCE_ROLE` and `EMERGENCY_ROLE` (plus `DEFAULT_ADMIN_ROLE` and the `SecureUpgradeable` upgrade gate); there is no yield-manager role on this contract.

### Function Signatures

Standard OpenZeppelin ERC-4626 surface; the four mutators are `nonReentrant` and `whenNotPaused`:

```solidity
function deposit(uint256 assets, address receiver) external returns (uint256 shares);            // stake QEURO
function mint(uint256 shares, address receiver) external returns (uint256 assets);
function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets); // unstake
function totalAssets() external view returns (uint256);                                             // QEURO held by the token
function convertToAssets(uint256 shares) external view returns (uint256);
function convertToShares(uint256 assets) external view returns (uint256);
function previewDeposit(uint256 assets) / previewMint(uint256 shares) / previewWithdraw(uint256 assets) / previewRedeem(uint256 shares)
function maxDeposit(address) / maxMint(address) / maxWithdraw(address owner) / maxRedeem(address owner)
function asset() external view returns (address);                                                   // QEURO
```

Notes:
- `deposit` needs a prior QEURO approval to the stQEURO proxy; `withdraw` / `redeem` by a third party need share allowance from `owner`.
- Redeeming the last outstanding shares also sweeps the rounding residual left by ERC-4626 round-down to that final exiter (`ResidualSwept`).
- Current share price: `convertToAssets(1e18)`. A holder's redeemable QEURO: `previewRedeem(balanceOf(holder))`.

#### `yieldFee()` / `updateYieldParameters(uint256 _yieldFee)`
`yieldFee` (bps; **0 live**, max 2000 = 20%) is deducted by `QuantillonVault.creditVaultYield` before yield is credited. Setter: `GOVERNANCE_ROLE`; emits `YieldParametersUpdated(uint256 yieldFee)`.

#### `updateTreasury(address _treasury)`
`GOVERNANCE_ROLE`; emits `TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury, address indexed caller)`.

#### `emergencyWithdraw(address user)`
`EMERGENCY_ROLE`, `nonReentrant`: burns all of `user`'s shares and transfers the redeemable QEURO to that user.

#### Metadata / wiring views
`vaultName()` (e.g. `"MORPHO1"`), `qeuro()`, `treasury()`, `TIME_PROVIDER()`, `version()`.

#### `initialize(...)`
Two initializers exist:
- `initialize(address admin, address _qeuro, address _treasury, address _timelock, string _vaultName)` — used by `stQEUROFactory`; name / symbol become `Staked Quantillon Euro {vaultName}` / `stQEURO{vaultName}`.
- `initialize(address admin, address _qeuro, address, address, address _treasury, address _timelock)` — legacy default-metadata initializer (`"Staked Quantillon Euro"` / `"stQEURO"`).

### Events

```solidity
event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);                              // ERC-4626
event Withdraw(address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);  // ERC-4626
event YieldParametersUpdated(uint256 yieldFee);
event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury, address indexed caller);
event ResidualSwept(address indexed receiver, uint256 amount);
```

---

## External Vault Adapters

> The monolithic `AaveVault` contract was retired in the multi-vault refactor. External yield is provided by lightweight, **non-upgradeable** adapters that all implement the same `IExternalStakingVault` interface and are onboarded per `vaultId` via `setup-external-vaults.sh`. Adapters in `src/core/vaults/`: `MetaMorphoStakingVaultAdapter` (the **live** mainnet adapter, vaultId 2 — see [Contract Addresses](#contract-addresses)); `AaveStakingVaultAdapter` and `MorphoStakingVaultAdapter` wrap the `MockAaveVault` / `MockMorphoVault` mocks and exist for localhost / testnet only.

**Interface**: `IExternalStakingVault.sol`

### Function Signatures

#### `depositUnderlying(uint256 usdcAmount) → (uint256)`
```solidity
function depositUnderlying(uint256 usdcAmount) external returns (uint256 sharesReceived)
```

Deposits USDC into the wrapped third-party vault. Called by `QuantillonVault.deployUsdcToVault(vaultId, usdcAmount)`.

#### `withdrawUnderlying(uint256 usdcAmount) → (uint256)`
```solidity
function withdrawUnderlying(uint256 usdcAmount) external returns (uint256 usdcWithdrawn)
```

Withdraws USDC from the wrapped vault back to the protocol.

#### `harvestYieldToVault() → (uint256)`
```solidity
function harvestYieldToVault() external returns (uint256 realizedYield)
```

Realizes accrued yield and transfers it to the calling vault (`VAULT_MANAGER_ROLE`). Invoked by `QuantillonVault.harvestAndDistributeVaultYield(vaultId)`, which then splits the realized USDC between hedger funding, stQEURO stakers, and treasury.

#### `totalUnderlying() → (uint256)`
```solidity
function totalUnderlying() external view returns (uint256 underlyingBalance)
```

Returns the adapter's current USDC-equivalent balance held in the wrapped vault.

---

## YieldShift

**Contract**: `YieldShift.sol`  
**Interface**: `IYieldShift.sol`  
**Inherits**: `SecureUpgradeable`, `PausableUpgradeable`

### Function Signatures

#### `addYield(uint256 vaultId, uint256 yieldAmount, bytes32 source)`
```solidity
function addYield(uint256 vaultId, uint256 yieldAmount, bytes32 source) external
```

**Modifiers**: `nonReentrant`; the caller must be authorized for `source` via `setYieldSourceAuthorization` (otherwise `NotAuthorized`), and with strict binding enabled `sourceToVaultId(msg.sender)` must equal `vaultId`  
**Events**: `YieldAdded(uint256 yieldAmount, string indexed source, uint256 indexed timestamp)`  
**Requirements**:
- `vaultId > 0` and vault must be registered in `stQEUROFactory`
- `yieldAmount > 0`
- Sufficient USDC balance and allowance

#### `updateYieldDistribution()`
```solidity
function updateYieldDistribution() external
```

**Modifiers**: `whenNotPaused`, `nonReentrant`  
**Events**: `YieldDistributionUpdated(uint256 newYieldShift, uint256 userYieldAllocation, uint256 hedgerYieldAllocation, uint256 indexed timestamp)`

#### `claimUserYield(address user)` — ⚠️ REMOVED
> This function has been removed. User yield accrues automatically through the **stQEURO** wrapper (the user share routes via `creditVaultYield` → stQEURO). (Hedger yield via `claimHedgerYield` is unaffected.)

#### `claimHedgerYield(address hedger) → (uint256)`
```solidity
function claimHedgerYield(address hedger) external returns (uint256 yieldAmount)
```

**Modifiers**: `whenNotPaused`, `nonReentrant`  
**Events**: `HedgerYieldClaimed(address indexed hedger, uint256 yieldAmount, uint256 timestamp)`

#### `getPoolMetrics() → (uint256, uint256, uint256, uint256)`
```solidity
function getPoolMetrics() external view returns (
    uint256 userPoolSize,
    uint256 hedgerPoolSize,
    uint256 poolRatio,
    uint256 targetRatio
)
```

#### `calculateOptimalYieldShift() → (uint256, uint256)`
```solidity
function calculateOptimalYieldShift() external view returns (
    uint256 optimalShift,
    uint256 currentDeviation
)
```

#### `configureYieldModel(YieldModelConfig cfg)`
Batch governance setter for:
- `baseYieldShift`
- `maxYieldShift`
- `adjustmentSpeed`
- `targetPoolRatio`

#### `configureDependencies(YieldDependencyConfig cfg)`
Batch governance setter for:
- `userPool`
- `hedgerPool`
- `mockAaveVault` (vestigial: never read by YieldShift; pass `address(0)`)
- `stQEUROFactory`
- `treasury`

#### `setYieldSourceAuthorization(address source, bytes32 yieldType, bool authorized)`
Governance setter to authorize/revoke a yield source and bind source type.

#### `currentYieldShift()`, `userPendingYield(address)`, `hedgerPendingYield(address)`, `paused()`
Direct state getters used by integrations and indexers.

### Events

```solidity
event YieldDistributionUpdated(uint256 newYieldShift, uint256 userYieldAllocation, uint256 hedgerYieldAllocation, uint256 indexed timestamp);
event YieldAdded(uint256 yieldAmount, string indexed source, uint256 indexed timestamp);
event HedgerYieldClaimed(address indexed hedger, uint256 yieldAmount, uint256 timestamp);
event SourceVaultBindingUpdated(address indexed source, uint256 indexed vaultId);
event SourceVaultBindingModeUpdated(bool enabled);

---

## OracleRouter

**Contract**: `OracleRouter.sol`
**Interface**: `IOracle.sol`
**Inherits**: `UUPSUpgradeable`, `AccessControlUpgradeable`, `PausableUpgradeable` — plain UUPS proxy (not `SecureUpgradeable`): `_authorizeUpgrade` is gated by `UPGRADER_ROLE`, held by the governance Safe, so upgrades execute in one Safe transaction with **no timelock**

Single oracle entry point for the protocol. All protocol contracts read prices only through `OracleRouter`; the underlying source can be switched by governance without touching consumers.

Routing slots (`enum OracleType { CHAINLINK, MARKET }`; live router version 1.1.1):
- Slot `0` (`CHAINLINK`) — `ChainlinkOracle`, the fallback.
- Slot `1` (`MARKET`) — the swappable market-price oracle: `StorkOracle` historically, **currently `HyperliquidEurUsdOracle`, the active production oracle** (`activeOracle = 1`). Named `STORK` before v1.1.0; the old `storkOracle()` getter is a deprecated alias of `marketOracle()`.

### Function Signatures

#### `getEurUsdPrice() → (uint256, bool)`
```solidity
function getEurUsdPrice() external returns (uint256 price, bool isValid)
```
Proxies to the active oracle. **Non-`view` by design** — a fresh valid read commits the price into the deviation-baseline cache and emits `PriceUpdated`; integrators that only need a cheap read should use the cached getters.

**Returns**:
- `price`: EUR/USD price (18 decimals)
- `isValid`: Whether price is fresh and valid

#### `getUsdcUsdPrice() → (uint256, bool)`
```solidity
function getUsdcUsdPrice() external view returns (uint256 price, bool isValid)
```

#### `getActiveOracle() → (OracleType)`
Returns the currently active slot (`1` on Base mainnet).

#### `getOracleAddresses() → (address chainlinkAddress, address marketAddress)`
Returns both slot addresses (the market slot currently returns the `HyperliquidEurUsdOracle` address).

#### `marketOracle() → (IOracle)` / `storkOracle() → (IStorkOracle)`
`marketOracle()` is the slot-1 getter (v1.1.0+). `storkOracle()` is the pre-1.1.0 name, kept as a deprecated ABI-compatible alias returning the same address.

#### `switchOracle(OracleType newOracle)`
```solidity
function switchOracle(OracleType newOracle) external
```

**Modifiers**: `onlyRole(ORACLE_MANAGER_ROLE)`
**Events**: `OracleSwitched(uint8 oldOracle, uint8 newOracle, address caller)`

One-transaction failover between slot 0 and slot 1 (e.g. `switchOracle(0)` falls back to Chainlink).

#### `updateOracleAddresses(address _chainlinkOracle, address _marketOracle)`
**Modifiers**: `onlyRole(ORACLE_MANAGER_ROLE)`
**Events**: `OracleAddressesUpdated`

Points a slot at a new oracle contract — this is how `HyperliquidEurUsdOracle` was installed into slot 1.

Health and config views (`getOracleHealth`, `getEurUsdDetails`, `getOracleConfig`, `getPriceFeedAddresses`, `checkPriceFeedConnectivity`) and manager passthroughs (`updatePriceBounds`, `updateUsdcTolerance`, `updatePriceFeeds`, `triggerCircuitBreaker`, `resetCircuitBreaker`) forward to the active oracle.

---

## ChainlinkOracle

**Contract**: `ChainlinkOracle.sol`
**Interface**: `IChainlinkOracle.sol`
**Inherits**: `UUPSUpgradeable`, `AccessControlUpgradeable`, `PausableUpgradeable` — plain UUPS proxy (not `SecureUpgradeable`): `_authorizeUpgrade` is gated by `UPGRADER_ROLE`, held by the governance Safe, so upgrades execute in one Safe transaction with **no timelock**

Fallback EUR/USD oracle (router slot 0) and the protocol's USDC/USD source, reading Chainlink AggregatorV3 feeds.

**Validation rules**:
- `MAX_PRICE_STALENESS` (EUR/USD): 2 hours
- `MAX_USDC_PRICE_STALENESS`: 25 hours
- `MAX_PRICE_DEVIATION`: 500 basis points (5%) circuit breaker
- `MAX_TIMESTAMP_DRIFT`: 900 seconds (15 minutes)
- EUR/USD price bounds: 0.80 – 1.40 (18 decimals)
- USDC tolerance: 200 bps (2%), falls back to $1.00 outside tolerance

### Function Signatures

#### `getEurUsdPrice() → (uint256, bool)`
```solidity
function getEurUsdPrice() external view returns (uint256 price, bool isValid)
```

**Returns**:
- `price`: EUR/USD price (18 decimals, normalized from the 8-decimal feed)
- `isValid`: Whether price is fresh and valid

#### `getUsdcUsdPrice() → (uint256, bool)`
```solidity
function getUsdcUsdPrice() external view returns (uint256 price, bool isValid)
```

**Returns**:
- `price`: USDC/USD price (18 decimals, normalized from the 8-decimal feed)
- `isValid`: Whether price is fresh and valid

#### `updatePriceFeeds(address eurUsdFeed, address usdcUsdFeed)`
```solidity
function updatePriceFeeds(address eurUsdFeed, address usdcUsdFeed) external
```

**Modifiers**: `onlyRole(ORACLE_MANAGER_ROLE)`  
**Events**: `PriceFeedsUpdated(address eurUsdFeed, address usdcUsdFeed)`  
**Requirements**:
- `eurUsdFeed != address(0)`
- `usdcUsdFeed != address(0)`

#### `updatePriceBounds(uint256 minPrice, uint256 maxPrice)`
```solidity
function updatePriceBounds(uint256 minPrice, uint256 maxPrice) external
```

**Modifiers**: `onlyRole(ORACLE_MANAGER_ROLE)`  
**Events**: `PriceBoundsUpdated(uint256 minPrice, uint256 maxPrice)`  
**Requirements**:
- `minPrice < maxPrice`

#### `triggerCircuitBreaker()`
```solidity
function triggerCircuitBreaker() external
```

**Modifiers**: `onlyRole(EMERGENCY_ROLE)`  
**Events**: `CircuitBreakerTriggered(uint256 timestamp)`

#### `resetCircuitBreaker()`
```solidity
function resetCircuitBreaker() external
```

**Modifiers**: `onlyRole(EMERGENCY_ROLE)`  
**Events**: `CircuitBreakerReset(uint256 timestamp)`

---

## HyperliquidEurUsdOracle

**Contract**: `HyperliquidEurUsdOracle.sol`
**Interface**: `IHyperliquidOracle.sol` (IOracle-compatible)
**Inherits**: `UUPSUpgradeable`, `AccessControlUpgradeable`, `PausableUpgradeable` — plain UUPS proxy (not `SecureUpgradeable`): `_authorizeUpgrade` is gated by `UPGRADER_ROLE`, held by the governance Safe, so upgrades execute in one Safe transaction with **no timelock**

**The ACTIVE production EUR/USD oracle** (router slot 1, live since 2026-06-25). EUR/USD is the Hyperliquid `EUR` perpetual mid-price, published on-chain into `SlippageStorage` by the off-chain publisher and read via `getSlippageBySource(sourceId).midPrice` (18 decimals). USDC/USD is delegated to `ChainlinkOracle`.

**Validation rules**:
- `maxPriceStaleness`: 900 seconds default (15 min), hard-capped by `HARD_MAX_STALENESS` = 3600 seconds
- EUR/USD price bounds: 0.80 – 1.40 (18 decimals)
- `MAX_PRICE_DEVIATION`: 500 basis points (5%) circuit breaker vs last valid price
- USDC tolerance: 200 bps (2%), falls back to $1.00
- Stale or out-of-bounds price → `isValid = false` → dependent mint/redeem revert

### Function Signatures

#### `getEurUsdPrice() → (uint256, bool)`
```solidity
function getEurUsdPrice() external returns (uint256 price, bool isValid)
```
Non-`view`: a fresh valid read updates the deviation-baseline cache and emits `PriceUpdated`.

#### `getUsdcUsdPrice() → (uint256, bool)`
```solidity
function getUsdcUsdPrice() external view returns (uint256 price, bool isValid)
```
Delegated to the configured USDC source (`ChainlinkOracle`).

#### `setMaxPriceStaleness(uint256 newMaxStaleness)`
**Modifiers**: `onlyRole(ORACLE_MANAGER_ROLE)` — must be ≤ 3600 seconds.
**Events**: `MaxStalenessUpdated(uint256 oldStaleness, uint256 newStaleness)`

#### `updateSlippageSource(address _slippageStorage, uint8 _sourceId)` / `updateUsdcSource(address _usdcSource)`
**Modifiers**: `onlyRole(ORACLE_MANAGER_ROLE)`

#### `updatePriceBounds(uint256 minPrice, uint256 maxPrice)` / `updateUsdcTolerance(uint256 newToleranceBps)`
**Modifiers**: `onlyRole(ORACLE_MANAGER_ROLE)`

#### `triggerCircuitBreaker()` / `resetCircuitBreaker()`
**Modifiers**: `onlyRole(EMERGENCY_ROLE)`

Health and config views: `getOracleHealth`, `getEurUsdDetails`, `getOracleConfig`, `getPriceFeedAddresses`, `checkPriceFeedConnectivity`.

### Events

```solidity
event PriceUpdated(uint256 eurUsdPrice, uint256 usdcUsdPrice, uint256 indexed timestamp);
event CircuitBreakerTriggered(uint256 attemptedPrice, uint256 lastValidPrice, string indexed reason);
event CircuitBreakerReset(address indexed admin);
event PriceBoundsUpdated(string indexed boundType, uint256 newMinPrice, uint256 newMaxPrice);
event SlippageSourceUpdated(address indexed newSlippageStorage, uint8 newSourceId);
event UsdcSourceUpdated(address indexed newUsdcSource);
event MaxStalenessUpdated(uint256 oldStaleness, uint256 newStaleness);
```

---

## StorkOracle

**Contract**: `StorkOracle.sol`
**Inherits**: `UUPSUpgradeable`, `AccessControlUpgradeable`, `PausableUpgradeable` — plain UUPS proxy (not `SecureUpgradeable`): `_authorizeUpgrade` is gated by `UPGRADER_ROLE`, held by the governance Safe, so upgrades execute in one Safe transaction with **no timelock**

EUR/USD and USDC/USD feeds via the Stork Network, exposing the same `IOracle` surface as `ChainlinkOracle`. **Parked**: it previously occupied router slot 1 and was replaced there by `HyperliquidEurUsdOracle` on 2026-06-25. The contract remains deployed and can be re-installed via `OracleRouter.updateOracleAddresses` if needed.

---

## FeeCollector

**Contract**: `FeeCollector.sol`
**Inherits**: `UUPSUpgradeable`, `AccessControlUpgradeable`, `ReentrancyGuardUpgradeable`, `PausableUpgradeable` — plain UUPS proxy (not `SecureUpgradeable`): `_authorizeUpgrade` is gated by `GOVERNANCE_ROLE`, held by the governance Safe, so upgrades execute in one Safe transaction with **no timelock**

Centralized protocol fee collection and distribution. Distribution ratios (initializer defaults, governance-adjustable, must sum to 10000 bps): **treasury 60% / dev fund 25% / community 15%**.

### Function Signatures

#### `collectFees(address token, uint256 amount, string sourceType)`
Records fees pulled from an authorized protocol contract.

**Modifiers**: `onlyFeeSource`, `whenNotPaused`, `nonReentrant`

#### `collectETHFees(string sourceType)`
Payable ETH-fee variant.

**Modifiers**: `onlyFeeSource`, `whenNotPaused`, `nonReentrant`

#### `distributeFees(address token)`
Distributes collected fees to treasury, dev fund, and community fund according to configured ratios.

**Modifiers**: `onlyRole(TREASURY_ROLE)`, `whenNotPaused`, `nonReentrant`

#### `updateFeeRatios(uint256 _treasuryRatio, uint256 _devFundRatio, uint256 _communityRatio)`
**Modifiers**: `onlyRole(GOVERNANCE_ROLE)`
**Requirements**: `_treasuryRatio + _devFundRatio + _communityRatio == 10000`

#### `updateFundAddresses(...)`
Updates treasury / dev fund / community fund destinations.

**Modifiers**: `onlyRole(GOVERNANCE_ROLE)`

#### `authorizeFeeSource(address feeSource)` / `revokeFeeSource(address feeSource)`
**Modifiers**: `onlyRole(GOVERNANCE_ROLE)`

### Events

```solidity
event FeesCollected(address indexed token, uint256 amount, address indexed source, string indexed sourceType);
event FeesDistributed(address indexed token, uint256 totalAmount, uint256 treasuryAmount, uint256 devFundAmount, uint256 communityAmount);
event FeeRatiosUpdated(uint256 treasuryRatio, uint256 devFundRatio, uint256 communityRatio);
event FundAddressesUpdated(address treasury, address devFund, address communityFund);
```

---

## TimeProvider

**Contract**: `TimeProvider` (in `src/libraries/TimeProviderLibrary.sol`) — deployed directly, not behind a proxy

Centralized `block.timestamp` wrapper used across core contracts, with governance-controlled offset support for test environments.

### Function Signatures

#### `currentTime() → (uint256)` / `rawTimestamp() → (uint256)`
Public views: offset-adjusted time and raw block timestamp.

#### `setTimeOffset(int256 newOffset, string reason)`
**Modifiers**: `onlyRole(GOVERNANCE_ROLE)` — offset bounded (max 7 days) to prevent abuse.

#### `advanceTime(uint256 amount)` / `resetTime()`
**Modifiers**: `onlyRole(GOVERNANCE_ROLE)`

#### `setEmergencyMode(bool enabled)` / `emergencyResetTime()`
**Modifiers**: `onlyRole(EMERGENCY_ROLE)`

#### `getTimeInfo()` / `timeDiff(uint256 t1, uint256 t2)`
Public views.

### Events

```solidity
event TimeOffsetChanged(address indexed changer, int256 oldOffset, int256 newOffset, string reason, uint256 timestamp);
event EmergencyModeChanged(bool enabled, address indexed changer, uint256 timestamp);
event TimeReset(address indexed resetter, uint256 timestamp);
```

---

## Access Control Roles

| Role | Where | Description / key functions |
|------|-------|-----------------------------|
| `DEFAULT_ADMIN_ROLE` | all contracts | Role administration; QEURO supply cap and rate limits (`updateMaxSupply`, `updateRateLimits`); treasury / fee-collector wiring; token/ETH recovery; `SecureUpgradeable.setTimelock` |
| `GOVERNANCE_ROLE` | QuantillonVault, QEUROToken-adjacent core (QTIToken, UserPool, HedgerPool, YieldShift, stQEUROFactory, stQEUROToken), FeeCollector, TimeProvider | Parameter updates, dependency wiring, fee ratios, time offsets; on FeeCollector it also gates `_authorizeUpgrade` |
| `EMERGENCY_ROLE` | core contracts, FeeCollector, oracles, SlippageStorage, TimeProvider | Pause/unpause, emergency position close / unstake / withdraw, circuit breakers |
| `UPGRADER_ROLE` | OracleRouter, ChainlinkOracle, HyperliquidEurUsdOracle, LighterEurUsdOracle (inert), StorkOracle, SlippageStorage, TimeProvider | `_authorizeUpgrade` on the plain-UUPS proxies — held by the Safe and effective immediately (**no timelock**). The eight `SecureUpgradeable` proxies (QuantillonVault, QEUROToken, QTIToken, UserPool, HedgerPool, YieldShift, stQEUROFactory, stQEUROToken) are instead gated by their `timelock` pointer, the 12 h OpenZeppelin `TimelockController` |
| `MINTER_ROLE` / `BURNER_ROLE` | QEUROToken | Mint / burn QEURO (held by `QuantillonVault`) |
| `PAUSER_ROLE` | QEUROToken | `pause` / `unpause`, `setMintingKillswitch` |
| `COMPLIANCE_ROLE` | QEUROToken | Whitelist / blacklist management, whitelist mode |
| `VAULT_OPERATOR_ROLE` | QuantillonVault | `deployUsdcToVault` (move idle USDC into an external vault adapter) |
| `YIELD_DISTRIBUTOR_ROLE` | QuantillonVault | `harvestAndDistributeVaultYield`, `creditVaultYield` |
| `VAULT_FACTORY_ROLE` | stQEUROFactory | `registerVault` (granted to `QuantillonVault` for self-registration) |
| `VAULT_MANAGER_ROLE` | external vault adapters | `depositUnderlying` / `withdrawUnderlying` / `harvestYieldToVault` (held by `QuantillonVault`) |
| `ORACLE_MANAGER_ROLE` | OracleRouter, ChainlinkOracle, HyperliquidEurUsdOracle, LighterEurUsdOracle (inert), StorkOracle | `switchOracle`, `updateOracleAddresses`, feed / bounds / staleness / source configuration |
| `MANAGER_ROLE` / `WRITER_ROLE` | SlippageStorage | Store configuration (`MANAGER_ROLE`) / publishing the venue mid on-chain (`WRITER_ROLE`) |
| `TREASURY_ROLE` / `FEE_SOURCE_ROLE` | FeeCollector | `distributeFees` / contracts allowed to push fees (`QuantillonVault`, `HedgerPool`) |
| `YIELD_MANAGER_ROLE` | YieldShift | Granted to the admin by the initializer; no YieldShift entrypoint is gated by it today (vestigial) |

> On Base mainnet the 2-of-3 governance Safe holds the admin, governance, upgrade, emergency and oracle-manager roles on every contract. Operational roles are delegated to dedicated service wallets: `VAULT_OPERATOR_ROLE` and `YIELD_DISTRIBUTOR_ROLE` to keeper wallets, an additional `EMERGENCY_ROLE` grant on the vault to the hedging watchdog, and SlippageStorage `WRITER_ROLE` to the off-chain price publisher (currently also held by the deployer EOA). `OracleRouter` itself holds `ORACLE_MANAGER_ROLE` and `EMERGENCY_ROLE` on the market oracle so that its admin passthroughs work. There is no liquidator role — liquidation mode is a protocol-level state (vault CR <= 101%), not a per-position keeper action.

---

## Constants and Limits

Verified against the deployed contracts on Base mainnet with `cast` on 2026-09-05. Values marked *settable* are current live values that governance can change, not immutable constants.

### QuantillonVault
- `mintFee`: 0 (*settable*, max 5% = `5e16`)
- `redemptionFee`: 0 (*settable*, max 5%; also applied to liquidation-mode redemptions)
- `minCollateralizationRatioForMinting`: **102.5% live (`1.025e20`, since 2026-09-02)** — governance-settable (initializer default 105% = `105e18`; hard floor 101%)
- `criticalCollateralizationRatio`: 101% (`101e18`) — liquidation mode at or below this protocol CR
- `MAX_PRICE_DEVIATION`: 200 bps (2%) between cached and live oracle price
- `MAX_FUNDING_RATE_ANNUAL_BPS`: 5000 (50%) cap on the hedger funding rate

### QEUROToken
- Supply model: **no fixed tokenomic supply cap** — supply is economically bounded by hedging capacity (minting requires the protocol CR to stay above the governance-set minting floor)
- `maxSupply`: administrative safety ceiling, currently 100,000,000 QEURO (`DEFAULT_MAX_SUPPLY`; governance-raisable at any time via `updateMaxSupply`, only constrained to ≥ current supply)
- Decimals: 18
- **Mint and burn rate limiting** (supply-abuse guardrail, global): each capped at 10,000,000 QEURO per 300-**block** window (~10 min on Base) — `rateLimitCaps()` returns `(mint, burn)`, both initialised to `MAX_RATE_LIMIT` and live at 10M / 10M; adjustable downward by `updateRateLimits` (`DEFAULT_ADMIN_ROLE`). `RATE_LIMIT_RESET_PERIOD` = 300 blocks.

### QTIToken
- `TOTAL_SUPPLY_CAP`: 100,000,000 QTI — **current supply is 0 (dormant: no mint path is wired)**
- `MIN_LOCK_TIME`: 7 days · `MAX_LOCK_TIME`: 365 days
- `MAX_VE_QTI_MULTIPLIER`: 4× voting power
- `proposalThreshold`: 100,000 QTI · `quorumVotes`: 1,000,000 QTI (*settable*)
- Voting period: 3 days minimum, 14 days maximum · `PROPOSAL_EXECUTION_DELAY`: 2 days

### UserPool
- `stakingAPY`: 800 bps (8%) · `depositAPY`: 400 bps (4%) (*settable*)
- `minStakeAmount`: 100 QEURO (*settable*)
- `unstakingCooldown`: 7 days (*settable*)
- `performanceFee`: 0 (*settable*)

### HedgerPool
- `coreParams().maxLeverage`: 20× (*settable* via `configureRiskAndFees`; the `MAX_LEVERAGE` constant = 65535 is only the `uint16` upper bound of the setter) · `coreParams().minMarginRatio`: **250 bps (2.5%) live since 2026-09-02** — governance-set via `configureRiskAndFees`: 500 bps at launch, hard floor `DEFAULT_MIN_MARGIN_RATIO_BPS` = 250 bps since v1.0.8
- `MAX_MARGIN_RATIO`: 5000 bps (50%, i.e. 2× minimum leverage)
- `minMarginAmount`: **0 live** (*settable*; initializer default 100 USDC) · `minPositionHoldBlocks`: **0 live** (*settable*; initializer default 5 blocks)
- `entryFee` / `exitFee` / `marginFee`: 0 (*settable*)
- `eurInterestRate` / `usdInterestRate`: 350 / 450 bps (*settable*)
- `rewardFeeSplit`: 20% (`2e17`) of protocol fees routed to the hedger reward reserve (*settable*)
- Single-hedger model (`setSingleHedger`; the delayed rotation path was removed, see `setSingleHedger` above); liquidation is driven by the vault-level critical CR (<= 101%), not a per-position threshold constant

### stQEURO
- `yieldFee`: 0 (*settable*, max 20% = 2000 bps)

### YieldShift
- `baseYieldShift`: 50% · `maxYieldShift`: 90% (*settable*)
- `MIN_HOLDING_PERIOD`: 7 days · `TWAP_PERIOD`: 24 hours · `MAX_HISTORY_LENGTH`: 1000

### Oracles
- ChainlinkOracle: EUR/USD staleness 2 h · USDC/USD staleness 25 h · 5% deviation breaker · bounds 0.80–1.40 · USDC tolerance 2%
- HyperliquidEurUsdOracle: staleness 900 s (hard cap 3600 s) · same bounds, breaker, and tolerance

### External Vault Adapters
- No fixed exposure/rebalance constants — adapters are thin pass-throughs to the wrapped vault.
- USDC is deployed/withdrawn per `vaultId` under governance control via `QuantillonVault.deployUsdcToVault` / `harvestAndDistributeVaultYield`.

---

## Error Handling

All functions revert with custom errors (no `require` strings). Errors are declared in the domain error libraries under `src/libraries/` and are part of each contract's ABI, so they decode with the contract ABI or with the library ABI. OpenZeppelin errors (`AccessControlUnauthorizedAccount`, `EnforcedPause`, `ReentrancyGuardReentrantCall`, `ERC20Insufficient*`, `ERC4626ExceededMax*`, `UUPSUnauthorizedCallContext`, ...) surface unchanged.

```solidity
// Revert with a library error
if (amount == 0) revert CommonErrorLibrary.InvalidAmount();
```

### Error Catalogue (from `src/libraries/*ErrorLibrary.sol`)

**`CommonErrorLibrary`** (shared by all contracts)

| Group | Errors |
|-------|--------|
| Input / validation | `InvalidAmount`, `ZeroAddress`, `InvalidAddress`, `InvalidParameter`, `InvalidCondition`, `InvalidRatio`, `InvalidTime`, `InvalidThreshold`, `InvalidShiftRange`, `ArrayLengthMismatch`, `BatchSizeTooLarge`, `EmptyArray`, `DivisionByZero`, `PercentageTooHigh`, `ConfigValueTooHigh`, `ConfigValueTooLow`, `RateLimitTooHigh` |
| Access | `NotAuthorized`, `NotAdmin`, `InvalidAdmin`, `NotGovernance`, `NotEmergencyRole`, `NotLiquidatorRole`, `NotVaultManager`, `NotYieldManager`, `NotWhitelisted` |
| Wiring / state | `InvalidTreasury`, `InvalidToken`, `InvalidOracle`, `InvalidVault`, `AlreadyInitialized`, `NotInitialized`, `NotActive`, `NoChangeDetected`, `EmergencyModeActive` |
| Balances / limits | `InsufficientBalance`, `AboveLimit`, `WouldExceedLimit`, `BelowThreshold`, `ExcessiveSlippage`, `InsufficientCollateralization`, `HoldingPeriodNotMet`, `TooManyPositions`, `PositionNotActive`, `LiquidationCooldown` |
| Oracle | `InvalidPrice`, `InvalidOraclePrice` (an invalid / stale oracle read reverts `mintQEURO` / `redeemQEURO` with `InvalidOraclePrice`) |
| Yield | `InsufficientYield`, `YieldCalculationError`, `YieldClaimFailed` |
| Governance (QTI) | `VotingPeriodTooShort`, `VotingPeriodTooLong`, `VotingNotStarted`, `VotingEnded`, `VotingNotEnded`, `AlreadyVoted`, `NoVotingPower`, `InsufficientVotingPower`, `ProposalAlreadyExecuted`, `ProposalCanceled`, `ProposalAlreadyCanceled`, `ProposalFailed`, `QuorumNotMet`, `ExecutionTimeNotReached`, `LockTimeTooShort`, `LockTimeTooLong` |
| Recovery | `ETHTransferFailed`, `NoETHToRecover`, `CannotRecoverOwnToken` |

**`TokenErrorLibrary`** (QEUROToken / QTIToken): `MintingDisabled`, `BlacklistedAddress`, `NewCapBelowCurrentSupply`, `LockNotExpired`, `NothingToUnlock`, `RateLimitExceeded`, `AlreadyBlacklisted`, `NotBlacklisted`, `AlreadyWhitelisted`, `PrecisionTooHigh`, `TooManyDecimals`

**`HedgerPoolErrorLibrary`** (HedgerPool): `FlashLoanAttackDetected`, `InvalidPosition`, `InvalidHedger`, `OnlyVault`, `RewardOverflow`, `InsufficientMargin`, `MarginExceedsMaximum`, `PositionSizeExceedsMaximum`, `EntryPriceExceedsMaximum`, `LeverageExceedsMaximum`, `TimestampOverflow`, `TotalMarginExceedsMaximum`, `TotalExposureExceedsMaximum`, `NewMarginExceedsMaximum`, `InvalidLeverage`, `LeverageTooHigh`, `MarginRatioTooLow`, `MarginRatioTooHigh`, `PositionOwnerMismatch`, `PositionClosureRestricted`, `InsufficientHedgerCapacity`, `NoActiveHedgerLiquidity`, `HedgerHasActivePosition`, `MinHoldPeriodNotElapsed`

**`VaultErrorLibrary`** (QuantillonVault): `FeeTooHigh`

All of these are parameterless (`error Name();`), so matching on the 4-byte selector (`keccak256("Name()")[:4]`) is sufficient. Pausing surfaces as OpenZeppelin `EnforcedPause()`.

---

## Gas Optimization

### Best Practices

1. **Use `view` functions** for read-only operations
2. **Batch operations** when possible
3. **Cache storage reads** in loops
4. **Use events** instead of storage for logging
5. **Implement proper access control** to prevent unauthorized calls

### Gas Figures

No static gas table is maintained here: figures drift with every implementation upgrade. Generate them from the current source with `make gas-analysis` (outputs under `scripts/results/gas-analysis/`) or `forge test --gas-report`.

---

## Integration Patterns

### Frontend Integration

```javascript
// Web3.js example
const contract = new web3.eth.Contract(abi, address);

// Call view function
const result = await contract.methods.getProtocolCollateralizationRatio().call();

// Send transaction
const tx = await contract.methods.mintQEURO(usdcAmount, minQeuroOut)
    .send({ from: userAddress });
```

### Backend Integration

```python
# Web3.py example
from web3 import Web3

w3 = Web3(Web3.HTTPProvider(rpc_url))
contract = w3.eth.contract(address=contract_address, abi=abi)

# Call view function
result = contract.functions.getProtocolCollateralizationRatio().call()  # 1e20 == 100%

# Send transaction
tx_hash = contract.functions.mintQEURO(usdc_amount, min_qeuro_out).transact({
    'from': user_address
})
```

---

## Solidity Integration Examples

### Basic QEURO Minting

```solidity
// 1. Approve USDC spending
usdc.approve(vaultAddress, usdcAmount);

// 2. Quote the mint (QEURO is 18 decimals, USDC is 6 — never derive the floor from usdcAmount)
(uint256 expectedQeuro, ) = vault.calculateMintAmount(usdcAmount);
uint256 minQeuroOut = (expectedQeuro * 95) / 100; // 5% slippage tolerance

// 3. Mint QEURO with slippage protection
vault.mintQEURO(usdcAmount, minQeuroOut);
```

### Staking QEURO

```solidity
// 1. Approve QEURO spending
qeuro.approve(userPoolAddress, qeuroAmount);

// 2. Stake QEURO — UserPool functions take arrays (one element for a single stake)
uint256[] memory amounts = new uint256[] (1);
amounts[0] = qeuroAmount; // must be >= userPool.minStakeAmount()
userPool.stake(amounts);

// There is no staking-reward claim. Protocol yield for users accrues automatically
// through the stQEURO ERC-4626 token (rising share price) — deposit QEURO into the
// per-vault stQEURO (stQEUROFactory.getStQEUROByVaultId(vaultId)) to earn it.
```

### Opening a Hedge Position

```solidity
// 1. Approve USDC spending (caller must be the configured single hedger)
usdc.approve(hedgerPoolAddress, marginAmount);

// 2. Open position with 5x leverage (max leverage: 20x)
uint256 positionId = hedgerPool.enterHedgePosition(marginAmount, 5);

// 3. Monitor hedger activity / claim rewards
bool hedgerActive = hedgerPool.hasActiveHedger();
(uint256 interestDiff, uint256 ysRewards, uint256 total) = hedgerPool.claimHedgingRewards();
```

### Governance Participation

> **Note**: QTI is currently dormant (supply 0, no mint path wired) — these calls become functional after the activation upgrade.

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

*This technical reference is maintained by Quantillon Labs and updated with each protocol version.*
