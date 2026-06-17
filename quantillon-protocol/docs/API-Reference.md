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

| Contract | Address |
|----------|---------|
| OracleRouter | `0x7ED6aaEd83Db69509A88CAe5C247ef8fA44056E0` |
| ChainlinkOracle | `0xaEE3c9c298051ef7242882AbCaE2Fd12d29443E7` |
| StorkOracle | `0x41FcE00E33Ca4f0d8E5528c343FAC98BA178EebC` |
| SlippageStorage | `0x0fde0ff2566be3c24af6d654012dddb4f1da099b` |
| TimeProvider | `0x520236487CBD0a6958B4EefC7853cd7C3F5C56E7` |

> Protocol contracts depend only on `OracleRouter` (which implements `IOracle`). `OracleRouter` routes to either `ChainlinkOracle` or `StorkOracle`, switchable by governance.

### Governance & infrastructure

| Contract | Address | Notes |
|----------|---------|-------|
| Gnosis Safe (governance) | `0x1d7fF432a93d0085Fb69474c7E567f859829e6cd` | 2-of-2; holds all privileged roles |
| TimelockController | `0x7Ade8f3Bf1FdaF0785efE9Ea5C6339D1aD6B8342` | 12h delay; gates UUPS upgrades |

### External vault adapters (onboarded post-core)

External staking adapters are onboarded after core deployment via `setup-external-vaults.sh` and are tracked per `vaultId`, not in `addresses.json`. Currently live:

| Adapter | Address | `vaultId` |
|---------|---------|-----------|
| MetaMorphoStakingVaultAdapter | `0x103aEBD0059AAA3DcCaa9ab0cCb901382Bd48978` | 2 |

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

#### `getVaultMetrics() → (uint256, uint256, uint256, uint256, uint256)`
```solidity
function getVaultMetrics() external view returns (
    uint256 totalUsdcHeld_,
    uint256 totalMinted_,
    uint256 totalDebtValue,
    uint256 totalUsdcInExternalVaults_,
    uint256 totalUsdcAvailable_
)
```

**Returns**:
- `totalUsdcHeld_`: USDC held directly by vault
- `totalMinted_`: QEURO minted by vault tracker
- `totalDebtValue`: USD debt value using live token supply and cached EUR/USD
- `totalUsdcInExternalVaults_`: Principal tracker across all configured external vault adapters
- `totalUsdcAvailable_`: Total collateral available — held USDC plus tracked external-vault **principal** (unharvested adapter yield is excluded)

#### `getProtocolCollateralizationRatio() → (uint256)`
```solidity
function getProtocolCollateralizationRatio() public view returns (uint256 ratio)
```

**Returns**: Current protocol collateralization ratio in 18-decimal percentage format (`100% = 1e20`)

**Description**: Calculates `CR = (TotalCollateral / BackingRequirement) * 1e20` where:
- `TotalCollateral` = `totalUsdcHeld + tracked external-vault principal` (unharvested adapter yield is excluded; it accrues to stQEURO holders via `harvestVaultYield`/`creditVaultYield`)
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

#### `harvestVaultYield(uint256 vaultId) → (uint256 harvestedYield)`
Governance entrypoint that triggers yield harvest for a specific adapter.

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

#### `harvestYield() → (uint256)`
```solidity
function harvestYield() external returns (uint256 harvestedYield)
```

Harvests accrued yield. Routed to `YieldShift` via `QuantillonVault.harvestVaultYield(vaultId)`, which calls `yieldShift.addYield(vaultId, netYield, source)`.

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

---

## ChainlinkOracle

**Contract**: `ChainlinkOracle.sol`  
**Interface**: `IChainlinkOracle.sol`  
**Inherits**: `SecureUpgradeable`, `PausableUpgradeable`

### Function Signatures

#### `getEurUsdPrice() → (uint256, bool)`
```solidity
function getEurUsdPrice() external view returns (uint256 price, bool isValid)
```

**Returns**:
- `price`: EUR/USD price (8 decimals)
- `isValid`: Whether price is fresh and valid

#### `getUsdcUsdPrice() → (uint256, bool)`
```solidity
function getUsdcUsdPrice() external view returns (uint256 price, bool isValid)
```

**Returns**:
- `price`: USDC/USD price (8 decimals)
- `isValid`: Whether price is fresh and valid

#### `updatePriceFeeds(address eurUsdFeed, address usdcUsdFeed)`
```solidity
function updatePriceFeeds(address eurUsdFeed, address usdcUsdFeed) external
```

**Modifiers**: `onlyRole(ADMIN_ROLE)`  
**Events**: `PriceFeedsUpdated(address eurUsdFeed, address usdcUsdFeed)`  
**Requirements**:
- `eurUsdFeed != address(0)`
- `usdcUsdFeed != address(0)`

#### `updatePriceBounds(uint256 minPrice, uint256 maxPrice)`
```solidity
function updatePriceBounds(uint256 minPrice, uint256 maxPrice) external
```

**Modifiers**: `onlyRole(ADMIN_ROLE)`  
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

**Modifiers**: `onlyRole(ADMIN_ROLE)`  
**Events**: `CircuitBreakerReset(uint256 timestamp)`

---

## Access Control Roles

| Role | Description | Key Functions |
|------|-------------|---------------|
| `DEFAULT_ADMIN_ROLE` | Super admin | All administrative functions |
| `EMERGENCY_ROLE` | Emergency operations | Pause/unpause, circuit breaker |
| `GOVERNANCE_ROLE` | Governance operations | Parameter updates, proposals |
| `VAULT_ROLE` | Vault operations | Mint/burn QEURO |
| `YIELD_MANAGER_ROLE` | Yield management | Distribute yield, manage Aave |
| `COMPLIANCE_ROLE` | Compliance operations | Whitelist/blacklist addresses |
| `LIQUIDATOR_ROLE` | Liquidation operations | Liquidate positions |
| `TIME_MANAGER_ROLE` | Time management | Set time offsets |

---

## Constants and Limits

### QuantillonVault
- `MAX_MINT_AMOUNT`: 1,000,000 USDC
- `MIN_MINT_AMOUNT`: 1 USDC
- `MAX_REDEEM_AMOUNT`: 1,000,000 QEURO
- `MIN_REDEEM_AMOUNT`: 1 QEURO

### QEUROToken
- `MAX_SUPPLY`: 1,000,000,000 QEURO (1B tokens)
- `MIN_PRICE_PRECISION`: 2 decimals
- `MAX_PRICE_PRECISION`: 8 decimals

### QTIToken
- `MIN_LOCK_TIME`: 1 week (604,800 seconds)
- `MAX_LOCK_TIME`: 4 years (126,144,000 seconds)
- `MIN_PROPOSAL_POWER`: 1,000 veQTI
- `VOTING_PERIOD`: 7 days (604,800 seconds)

### UserPool
- `MIN_STAKE_AMOUNT`: 100 QEURO
- `MAX_STAKE_AMOUNT`: 10,000,000 QEURO
- `UNSTAKE_COOLDOWN`: 7 days (604,800 seconds)

### HedgerPool
- `MAX_LEVERAGE`: 10x
- `MIN_LEVERAGE`: 1x
- `MIN_MARGIN_RATIO`: 110% (1.1)
- `LIQUIDATION_THRESHOLD`: 105% (1.05)
- `MAX_POSITIONS_PER_HEDGER`: 50

### External Vault Adapters
- No fixed exposure/rebalance constants — adapters are thin pass-throughs to the wrapped vault.
- USDC is deployed/withdrawn per `vaultId` under governance control via `QuantillonVault.deployUsdcToVault` / `harvestVaultYield`.

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
const result = await contract.methods.getVaultMetrics().call();

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

*This technical reference is maintained by Quantillon Labs and updated with each protocol version.*
