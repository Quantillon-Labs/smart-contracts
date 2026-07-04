# Quantillon Protocol API Reference

## Technical API Reference

This document provides detailed technical specifications for all Quantillon Protocol smart contract interfaces.

---

## Contract Addresses

Deployed addresses for **Base Mainnet (chain ID `8453`)**. The canonical, machine-readable source is [`deployments/8453/addresses.json`](https://github.com/Quantillon-Labs/smart-contracts/blob/main/quantillon-protocol/deployments/8453/addresses.json); the table below mirrors it. All core contracts are UUPS proxies — the addresses are the stable proxy addresses that integrators should use.

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
| SlippageStorage | `0x0fde0ff2566be3c24af6d654012dddb4f1da099b` | on-chain price store feeding HyperliquidEurUsdOracle |
| TimeProvider | `0x520236487CBD0a6958B4EefC7853cd7C3F5C56E7` | timestamp wrapper (deployed directly, not proxied) |

> Protocol contracts depend only on `OracleRouter` (which implements `IOracle`). The router has two slots — `enum OracleType { CHAINLINK, STORK }` — switchable in one governance transaction via `switchOracle`. Slot 1 keeps its historical `STORK` enum name for ABI stability but currently hosts **`HyperliquidEurUsdOracle`, the active production oracle** (`activeOracle = 1`). Slot 0 (`ChainlinkOracle`) is the fallback and remains the USDC/USD source.

### Governance & infrastructure

| Contract | Address | Notes |
|----------|---------|-------|
| Gnosis Safe (governance) | `0x1d7fF432a93d0085Fb69474c7E567f859829e6cd` | 2-of-3; holds all privileged roles |
| TimelockController | `0x7Ade8f3Bf1FdaF0785efE9Ea5C6339D1aD6B8342` | 12h delay; gates UUPS upgrades |

### External vault adapters (onboarded post-core)

External staking adapters are onboarded after core deployment via `setup-external-vaults.sh` and are tracked per `vaultId`, not in `addresses.json`. Currently live:

| Adapter | Address | `vaultId` |
|---------|---------|-----------|
| MetaMorphoStakingVaultAdapter | `0xb2f253Cd74ebfa16894339438B467396De9e8EA3` | 2 |

> The previous vaultId-2 adapter (`0x103aEBD0059AAA3DcCaa9ab0cCb901382Bd48978`) was migrated to the address above on 2026-07-01; migration details live in [`deployments/8453/metamorpho-adapter.json`](https://github.com/Quantillon-Labs/smart-contracts/blob/main/quantillon-protocol/deployments/8453/metamorpho-adapter.json).

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
- The aggregated `getVaultMetrics()` helper was removed in the external
  multi-vault refactor (EIP-170 headroom); read the three public trackers
  directly, and use `getProtocolCollateralizationRatio()` for debt/collateral
  ratio math. Total available collateral = `totalUsdcHeld +
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

#### `getProtocolCollateralizationRatioView() / canMintView()`
View-safe aliases exposing the same logic for off-chain tooling.

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
**Inherits**: `ERC20Upgradeable`, `AccessControlUpgradeable`, `PausableUpgradeable`

### Function Signatures

#### `mint(address to, uint256 amount)`
```solidity
function mint(address to, uint256 amount) external
```

**Modifiers**: `onlyRole(VAULT_ROLE)`  
**Events**: `TokensMinted(address indexed to, uint256 amount)`

#### `burn(uint256 amount)`
```solidity
function burn(uint256 amount) external
```

**Modifiers**: `onlyRole(VAULT_ROLE)`  
**Events**: `TokensBurned(address indexed from, uint256 amount)`

#### `whitelistAddress(address account)`
```solidity
function whitelistAddress(address account) external
```

**Modifiers**: `onlyRole(COMPLIANCE_ROLE)`  
**Events**: `AddressWhitelisted(address indexed account)`

#### `blacklistAddress(address account)`
```solidity
function blacklistAddress(address account) external
```

**Modifiers**: `onlyRole(COMPLIANCE_ROLE)`  
**Events**: `AddressBlacklisted(address indexed account)`

#### `updateMaxSupply(uint256 newMaxSupply)`
```solidity
function updateMaxSupply(uint256 newMaxSupply) external
```

**Modifiers**: `onlyRole(ADMIN_ROLE)`  
**Events**: `MaxSupplyUpdated(uint256 oldMaxSupply, uint256 newMaxSupply)`

#### `getTokenInfo() → (uint256, uint256, uint256, bool, bool)`
```solidity
function getTokenInfo() external view returns (
    uint256 totalSupply,
    uint256 maxSupply,
    uint256 supplyUtilization,
    bool whitelistMode,
    bool isPaused
)
```

### Events

```solidity
event TokensMinted(address indexed to, uint256 amount);
event TokensBurned(address indexed from, uint256 amount);
event AddressWhitelisted(address indexed account);
event AddressBlacklisted(address indexed account);
event MaxSupplyUpdated(uint256 oldMaxSupply, uint256 newMaxSupply);
```

---

## QTIToken

**Contract**: `QTIToken.sol`  
**Interface**: `IQTIToken.sol`  
**Inherits**: `ERC20Upgradeable`, `AccessControlUpgradeable`, `PausableUpgradeable`

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
**Inherits**: `SecureUpgradeable`, `PausableUpgradeable`

### Function Signatures

#### `deposit(uint256 usdcAmount)`
```solidity
function deposit(uint256 usdcAmount) external
```

**Modifiers**: `whenNotPaused`, `nonReentrant`  
**Events**: `USDCDeposited(address indexed user, uint256 amount)`  
**Requirements**:
- `usdcAmount > 0`
- Sufficient USDC balance and allowance

#### `withdraw(uint256 usdcAmount)`
```solidity
function withdraw(uint256 usdcAmount) external
```

**Modifiers**: `whenNotPaused`, `nonReentrant`  
**Events**: `USDCWithdrawn(address indexed user, uint256 amount)`  
**Requirements**:
- `usdcAmount > 0`
- Sufficient balance

#### `stake(uint256 qeuroAmount)`
```solidity
function stake(uint256 qeuroAmount) external
```

**Modifiers**: `whenNotPaused`, `nonReentrant`  
**Events**: `QEUROStaked(address indexed user, uint256 amount)`  
**Requirements**:
- `qeuroAmount >= MIN_STAKE_AMOUNT`
- Sufficient QEURO balance and allowance

#### `unstake(uint256 qeuroAmount)`
```solidity
function unstake(uint256 qeuroAmount) external
```

**Modifiers**: `whenNotPaused`, `nonReentrant`  
**Events**: `QEUROUnstaked(address indexed user, uint256 amount)`  
**Requirements**:
- `qeuroAmount > 0`
- Sufficient staked balance
- Cooldown period completed

#### `claimStakingRewards()` — ⚠️ REMOVED
> Removed in the post-audit cleanup: it minted unbacked QEURO and was non-functional on the live deployment (UserPool holds no `MINTER_ROLE`). User yield now accrues automatically through the **stQEURO** wrapper (rising exchange rate); there is no staking-reward claim call.

#### `getUserInfo(address user) → (uint256, uint256, uint256, uint256, uint256)`
```solidity
function getUserInfo(address user) external view returns (
    uint256 depositedUsdc,
    uint256 stakedQeuro,
    uint256 lastStakeTime,
    uint256 pendingRewards,
    uint256 totalRewardsClaimed
)
```

#### `getPoolMetrics() → (uint256, uint256, uint256, uint256)`
```solidity
function getPoolMetrics() external view returns (
    uint256 totalUsers,
    uint256 totalStakes,
    uint256 totalDeposits,
    uint256 totalRewards
)
```

### Events

```solidity
event USDCDeposited(address indexed user, uint256 amount);
event USDCWithdrawn(address indexed user, uint256 amount);
event QEUROStaked(address indexed user, uint256 amount);
event QEUROUnstaked(address indexed user, uint256 amount);
event RewardsClaimed(address indexed user, uint256 amount);
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
**Events**: `HedgePositionOpened(address indexed hedger, uint256 indexed positionId, bytes32 positionData)`  
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
**Events**: `HedgingRewardsClaimed(address indexed hedger, bytes32 packedData)`  
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
Governance entrypoint for bootstrap/rotation proposal.  
If no hedger is currently configured, assignment is immediate. Otherwise it creates a delayed pending rotation.

#### `applySingleHedgerRotation()`
Executes a pending single-hedger rotation after delay.

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
**Inherits**: `ERC20Upgradeable`, `AccessControlUpgradeable`, `PausableUpgradeable`

### Function Signatures

#### `stake(uint256 qeuroAmount)`
```solidity
function stake(uint256 qeuroAmount) external
```

**Modifiers**: `whenNotPaused`, `nonReentrant`  
**Events**: `QEUROStaked(address indexed user, uint256 qeuroAmount, uint256 stQeuroAmount)`  
**Requirements**:
- `qeuroAmount > 0`
- Sufficient QEURO balance and allowance

#### `unstake(uint256 stQeuroAmount)`
```solidity
function unstake(uint256 stQeuroAmount) external
```

**Modifiers**: `whenNotPaused`, `nonReentrant`  
**Events**: `QEUROUnstaked(address indexed user, uint256 stQeuroAmount, uint256 qeuroAmount)`  
**Requirements**:
- `stQeuroAmount > 0`
- Sufficient stQEURO balance

#### `claimYield() → (uint256)`
```solidity
function claimYield() external returns (uint256 yieldAmount)
```

**Modifiers**: `whenNotPaused`, `nonReentrant`  
**Events**: `YieldClaimed(address indexed user, uint256 amount)`

#### `getExchangeRate() → (uint256)`
```solidity
function getExchangeRate() external view returns (uint256 rate)
```

**Returns**: Exchange rate between stQEURO and QEURO (18 decimals)

#### `getQEUROEquivalent(uint256 stQeuroAmount) → (uint256)`
```solidity
function getQEUROEquivalent(uint256 stQeuroAmount) external view returns (uint256 qeuroAmount)
```

#### `distributeYield(uint256 qeuroAmount)`
```solidity
function distributeYield(uint256 qeuroAmount) external
```

**Modifiers**: `onlyRole(YIELD_MANAGER_ROLE)`  
**Events**: `YieldDistributed(uint256 totalAmount, uint256 timestamp)`  
**Requirements**:
- `qeuroAmount > 0`
- Sufficient QEURO balance

#### `initialize(...)` (metadata overload for factory)
`stQEUROToken` now supports an overloaded initializer that accepts:
- `tokenName`
- `tokenSymbol`
- `vaultName`

This overload is used by `stQEUROFactory` when deploying a dedicated proxy per vault.

### Events

```solidity
event QEUROStaked(address indexed user, uint256 qeuroAmount, uint256 stQeuroAmount);
event QEUROUnstaked(address indexed user, uint256 stQeuroAmount, uint256 qeuroAmount);
event YieldClaimed(address indexed user, uint256 amount);
event YieldDistributed(uint256 totalAmount, uint256 timestamp);
```

---

## External Vault Adapters

> The monolithic `AaveVault` was removed in the multi-vault refactor. External yield is now provided by lightweight, **non-upgradeable** adapters that all implement the same `IExternalStakingVault` interface and are onboarded per `vaultId` via `setup-external-vaults.sh`. Current adapters: `AaveStakingVaultAdapter`, `MorphoStakingVaultAdapter`, `MetaMorphoStakingVaultAdapter` (the deployed mainnet adapter — see [Contract Addresses](#contract-addresses)).

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

**Modifiers**: `onlyAuthorizedYieldSource`, `whenNotPaused`, `nonReentrant`  
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
**Events**: `YieldDistributionUpdated(uint256 userPoolYield, uint256 hedgerPoolYield, uint256 currentShift)`

#### `claimUserYield(address user)` — ⚠️ REMOVED
> Removed in the post-audit cleanup: the `userYieldPool` it spent was never funded by `addYield` (the user share routes via `creditVaultYield` → stQEURO), so it always reverted. User yield now accrues automatically through the **stQEURO** wrapper. (Hedger yield via `claimHedgerYield` is unaffected.)

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
- `aaveVault`
- `stQEUROFactory`
- `treasury`

#### `setYieldSourceAuthorization(address source, bytes32 yieldType, bool authorized)`
Governance setter to authorize/revoke a yield source and bind source type.

#### `currentYieldShift()`, `userPendingYield(address)`, `hedgerPendingYield(address)`, `paused()`
Direct state getters used by integrations and indexers.

### Events

```solidity
event YieldDistributionUpdated(uint256 userPoolYield, uint256 hedgerPoolYield, uint256 currentShift);
event YieldAdded(uint256 yieldAmount, string indexed source, uint256 indexed timestamp);
event UserYieldClaimed(address indexed user, uint256 yieldAmount, uint256 timestamp);
event HedgerYieldClaimed(address indexed hedger, uint256 yieldAmount, uint256 timestamp);
```

---

## OracleRouter

**Contract**: `OracleRouter.sol`
**Interface**: `IOracle.sol`
**Inherits**: `SecureUpgradeable`, `PausableUpgradeable`

Single oracle entry point for the protocol. All protocol contracts read prices only through `OracleRouter`; the underlying source can be switched by governance without touching consumers.

Routing slots (`enum OracleType { CHAINLINK, STORK }`):
- Slot `0` (`CHAINLINK`) — `ChainlinkOracle`, the fallback.
- Slot `1` (`STORK`) — historically `StorkOracle`; **currently hosts `HyperliquidEurUsdOracle`, the active production oracle** (`activeOracle = 1`). The enum name is retained for ABI stability.

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

#### `getOracleAddresses() → (address chainlinkAddress, address storkAddress)`
Returns both slot addresses (the "stork" slot currently returns the `HyperliquidEurUsdOracle` address).

#### `switchOracle(OracleType newOracle)`
```solidity
function switchOracle(OracleType newOracle) external
```

**Modifiers**: `onlyRole(ORACLE_MANAGER_ROLE)`
**Events**: `OracleSwitched(uint8 oldOracle, uint8 newOracle, address caller)`

One-transaction failover between slot 0 and slot 1 (e.g. `switchOracle(0)` falls back to Chainlink).

#### `updateOracleAddresses(address chainlink, address stork)`
**Modifiers**: `onlyRole(ORACLE_MANAGER_ROLE)`
**Events**: `OracleAddressesUpdated`

Points a slot at a new oracle contract — this is how `HyperliquidEurUsdOracle` was installed into slot 1.

Health and config views (`getOracleHealth`, `getEurUsdDetails`, `getOracleConfig`, `getPriceFeedAddresses`, `checkPriceFeedConnectivity`) and manager passthroughs (`updatePriceBounds`, `updateUsdcTolerance`, `updatePriceFeeds`, `triggerCircuitBreaker`, `resetCircuitBreaker`) forward to the active oracle.

---

## ChainlinkOracle

**Contract**: `ChainlinkOracle.sol`
**Interface**: `IChainlinkOracle.sol`
**Inherits**: `SecureUpgradeable`, `PausableUpgradeable`

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
**Inherits**: `SecureUpgradeable`, `PausableUpgradeable`

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
**Inherits**: `SecureUpgradeable`, `PausableUpgradeable`

EUR/USD and USDC/USD feeds via the Stork Network, exposing the same `IOracle` surface as `ChainlinkOracle`. **Parked**: it previously occupied router slot 1 and was replaced there by `HyperliquidEurUsdOracle` on 2026-06-25. The contract remains deployed and can be re-installed via `OracleRouter.updateOracleAddresses` if needed.

---

## FeeCollector

**Contract**: `FeeCollector.sol`
**Inherits**: `SecureUpgradeable`, `PausableUpgradeable`

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

| Role | Description | Key Functions |
|------|-------------|---------------|
| `DEFAULT_ADMIN_ROLE` | Super admin | Treasury updates, token/ETH recovery |
| `GOVERNANCE_ROLE` | Governance operations | Parameter updates, fee ratios, time offsets |
| `EMERGENCY_ROLE` | Emergency operations | Pause/unpause, circuit breakers |
| `UPGRADER_ROLE` | UUPS upgrades | Upgrade authorization (gated by the 12h Timelock) |
| `MINTER_ROLE` / `BURNER_ROLE` | QEURO supply | Mint/burn QEURO (held by `QuantillonVault`) |
| `COMPLIANCE_ROLE` | Compliance operations | Whitelist/blacklist addresses (QEUROToken) |
| `ORACLE_MANAGER_ROLE` | Oracle management | `switchOracle`, feed/bounds/staleness config |
| `YIELD_MANAGER_ROLE` | Yield management | Yield distribution and external-vault yield ops |
| `TREASURY_ROLE` | Fee distribution | `FeeCollector.distributeFees` |

> On Base mainnet all privileged roles are held by the 2-of-3 governance Safe; there is no liquidator role — liquidation mode is a protocol-level state (vault CR ≤ 101%), not a per-position keeper action.

---

## Constants and Limits

Verified against deployed contracts on Base mainnet (2026-07-04). Values marked *settable* are current live values that governance can change, not immutable constants.

### QuantillonVault
- `mintFee`: 0 (*settable*, max 5% = `5e16`)
- `redemptionFee`: 0 (*settable*, max 5%; also applied to liquidation-mode redemptions)
- `MIN_COLLATERALIZATION_RATIO_FOR_MINTING`: 105% (`105e18`)
- `criticalCollateralizationRatio`: 101% (`101e18`) — liquidation mode at or below this protocol CR
- `MAX_PRICE_DEVIATION`: 200 bps (2%) between cached and live oracle price
- `MAX_FUNDING_RATE_ANNUAL_BPS`: 5000 (50%) cap on the hedger funding rate

### QEUROToken
- `maxSupply`: 100,000,000 QEURO (`DEFAULT_MAX_SUPPLY` = 100M, *settable*)
- Decimals: 18
- Mint rate limiting: max 10,000,000 QEURO per 300-second window (`MAX_RATE_LIMIT` / `RATE_LIMIT_RESET_PERIOD`)

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
- `maxLeverage`: 20× — minimum margin ratio 5% (`DEFAULT_MIN_MARGIN_RATIO_BPS` = 500)
- `MAX_MARGIN_RATIO`: 5000 bps (50%, i.e. 2× minimum leverage)
- `minMarginAmount`: 100 USDC
- `entryFee` / `exitFee` / `marginFee`: 0 (*settable*)
- `eurInterestRate` / `usdInterestRate`: 350 / 450 bps (*settable*)
- `rewardFeeSplit`: 20% (`2e17`) of protocol fees routed to the hedger reward reserve (*settable*)
- Single-hedger model (`setSingleHedger` + rotation); liquidation is driven by the vault-level critical CR (≤ 101%), not a per-position threshold constant

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

All functions use custom errors for gas efficiency. Common error patterns:

```solidity
// Revert with custom error
if (condition) revert CustomError();

// Emit event and revert
emit EventName();
revert CustomError();
```

### Error Categories

1. **Access Control Errors**
   - `UnauthorizedAccess()`
   - `InsufficientRole()`
   - `InvalidRole()`

2. **Validation Errors**
   - `InvalidAmount()`
   - `InvalidAddress()`
   - `InvalidParameter()`
   - `InvalidTime()`

3. **Business Logic Errors**
   - `InsufficientBalance()`
   - `InsufficientAllowance()`
   - `ExceedsLimit()`
   - `BelowMinimum()`

4. **Oracle Errors**
   - `StalePrice()`
   - `InvalidPrice()`
   - `CircuitBreakerActive()`

5. **Emergency Errors**
   - `ContractPaused()`
   - `EmergencyMode()`

---

## Gas Optimization

### Best Practices

1. **Use `view` functions** for read-only operations
2. **Batch operations** when possible
3. **Cache storage reads** in loops
4. **Use events** instead of storage for logging
5. **Implement proper access control** to prevent unauthorized calls

### Gas Estimates

| Function | Gas Cost (approx.) |
|----------|-------------------|
| `mintQEURO` | 150,000 |
| `redeemQEURO` | 140,000 |
| `stake` | 120,000 |
| `enterHedgePosition` | 200,000 |
| `exitHedgePosition` | 180,000 |
| `lock` | 160,000 |
| `vote` | 100,000 |

*Gas costs are estimates and may vary based on network conditions.*

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
result = contract.functions.getVaultMetrics().call()

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

// 2. Mint QEURO with slippage protection
uint256 minQeuroOut = (usdcAmount * 95) / 100; // 5% slippage tolerance
vault.mintQEURO(usdcAmount, minQeuroOut);
```

### Staking QEURO

```solidity
// 1. Approve QEURO spending
qeuro.approve(userPoolAddress, qeuroAmount);

// 2. Stake QEURO
userPool.stake(qeuroAmount);

// There is no staking-reward claim. Protocol yield for users accrues automatically
// through the stQEURO wrapper (rising exchange rate) — wrap QEURO into stQEURO to earn it.
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
