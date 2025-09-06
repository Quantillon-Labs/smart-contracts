# Quantillon Protocol API Reference

## Technical API Reference

This document provides detailed technical specifications for all Quantillon Protocol smart contract interfaces.

---

## Contract Addresses

*Note: These are example addresses for documentation. Use actual deployed addresses in production.*

| Contract | Address | Network |
|----------|---------|---------|
| QuantillonVault | `0x...` | Base Mainnet |
| QEUROToken | `0x...` | Base Mainnet |
| QTIToken | `0x...` | Base Mainnet |
| UserPool | `0x...` | Base Mainnet |
| HedgerPool | `0x...` | Base Mainnet |
| stQEUROToken | `0x...` | Base Mainnet |
| AaveVault | `0x...` | Base Mainnet |
| YieldShift | `0x...` | Base Mainnet |
| ChainlinkOracle | `0x...` | Base Mainnet |

---

## QuantillonVault

**Contract**: `QuantillonVault.sol`  
**Interface**: `IQuantillonVault.sol`  
**Inherits**: `SecureUpgradeable`, `PausableUpgradeable`

### Function Signatures

#### `initialize(address admin, address _qeuro, address _usdc, address _oracle)`
```solidity
function initialize(
    address admin,
    address _qeuro,
    address _usdc,
    address _oracle
) external
```

**Modifiers**: `initializer`  
**Events**: `VaultInitialized(address admin, address qeuro, address usdc, address oracle)`

#### `mintQEURO(uint256 usdcAmount, uint256 minQeuroOut)`
```solidity
function mintQEURO(
    uint256 usdcAmount,
    uint256 minQeuroOut
) external
```

**Modifiers**: `whenNotPaused`, `nonReentrant`  
**Events**: `QEUROMinted(address indexed user, uint256 usdcAmount, uint256 qeuroAmount, uint256 price)`  
**Requirements**:
- `usdcAmount > 0`
- `minQeuroOut > 0`
- Oracle price is fresh
- Sufficient USDC balance and allowance

#### `redeemQEURO(uint256 qeuroAmount, uint256 minUsdcOut)`
```solidity
function redeemQEURO(
    uint256 qeuroAmount,
    uint256 minUsdcOut
) external
```

**Modifiers**: `whenNotPaused`, `nonReentrant`  
**Events**: `QEURORedeemed(address indexed user, uint256 qeuroAmount, uint256 usdcAmount, uint256 price)`  
**Requirements**:
- `qeuroAmount > 0`
- `minUsdcOut > 0`
- Oracle price is fresh
- Sufficient QEURO balance and allowance

#### `calculateMintAmount(uint256 usdcAmount) → (uint256)`
```solidity
function calculateMintAmount(uint256 usdcAmount) external view returns (uint256)
```

**Returns**: Amount of QEURO that would be minted (18 decimals)

#### `calculateRedeemAmount(uint256 qeuroAmount) → (uint256)`
```solidity
function calculateRedeemAmount(uint256 qeuroAmount) external view returns (uint256)
```

**Returns**: Amount of USDC that would be received (6 decimals)

#### `getVaultMetrics() → (uint256, uint256, uint256, uint256, uint256, uint256)`
```solidity
function getVaultMetrics() external view returns (
    uint256 totalUsdcReserves,
    uint256 totalQeuroSupply,
    uint256 collateralizationRatio,
    uint256 protocolFees,
    uint256 lastUpdateTime,
    uint256 utilizationRate
)
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

#### `claimStakingRewards() → (uint256)`
```solidity
function claimStakingRewards() external returns (uint256 rewardAmount)
```

**Modifiers**: `whenNotPaused`, `nonReentrant`  
**Events**: `RewardsClaimed(address indexed user, uint256 amount)`

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

**Modifiers**: `secureNonReentrant`  
**Events**: `HedgePositionOpened(address indexed hedger, uint256 indexed positionId, bytes32 positionData)`  
**Requirements**:
- `usdcAmount > 0`
- `leverage >= 1 && leverage <= maxLeverage`
- Fresh oracle price
- Sufficient USDC balance and allowance

#### `closeHedgePosition(uint256 positionId) → (int256)`
```solidity
function closeHedgePosition(uint256 positionId) external returns (int256 pnl)
```

**Modifiers**: `secureNonReentrant`  
**Events**: `HedgePositionClosed(address indexed hedger, uint256 indexed positionId, int256 pnl)`  
**Requirements**:
- Position exists and is active
- Caller owns the position

#### `addMargin(uint256 positionId, uint256 usdcAmount)`
```solidity
function addMargin(uint256 positionId, uint256 usdcAmount) external
```

**Modifiers**: `secureNonReentrant`  
**Events**: `MarginAdded(address indexed hedger, uint256 indexed positionId, uint256 amount)`  
**Requirements**:
- Position exists and is active
- Caller owns the position
- `usdcAmount > 0`

#### `removeMargin(uint256 positionId, uint256 usdcAmount)`
```solidity
function removeMargin(uint256 positionId, uint256 usdcAmount) external
```

**Modifiers**: `secureNonReentrant`  
**Events**: `MarginRemoved(address indexed hedger, uint256 indexed positionId, uint256 amount)`  
**Requirements**:
- Position exists and is active
- Caller owns the position
- Maintains minimum margin ratio

#### `getPositionInfo(uint256 positionId) → (address, uint256, uint256, uint256, uint256, uint256, int256, bool)`
```solidity
function getPositionInfo(uint256 positionId) external view returns (
    address hedger,
    uint256 positionSize,
    uint256 margin,
    uint256 entryPrice,
    uint256 entryTime,
    uint256 leverage,
    int256 unrealizedPnL,
    bool isActive
)
```

#### `liquidatePosition(uint256 positionId)`
```solidity
function liquidatePosition(uint256 positionId) external
```

**Modifiers**: `onlyRole(LIQUIDATOR_ROLE)`  
**Events**: `PositionLiquidated(address indexed liquidator, uint256 indexed positionId, int256 pnl)`  
**Requirements**:
- Position is undercollateralized
- Fresh oracle price

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

---

## AaveVault

**Contract**: `AaveVault.sol`  
**Interface**: `IAaveVault.sol`  
**Inherits**: `SecureUpgradeable`, `PausableUpgradeable`

### Function Signatures

#### `deployToAave(uint256 usdcAmount)`
```solidity
function deployToAave(uint256 usdcAmount) external
```

**Modifiers**: `onlyRole(YIELD_MANAGER_ROLE)`, `whenNotPaused`, `nonReentrant`  
**Events**: `USDCDepositedToAave(uint256 amount)`  
**Requirements**:
- `usdcAmount > 0`
- Within exposure limits
- Sufficient USDC balance

#### `withdrawFromAave(uint256 usdcAmount)`
```solidity
function withdrawFromAave(uint256 usdcAmount) external
```

**Modifiers**: `onlyRole(YIELD_MANAGER_ROLE)`, `whenNotPaused`, `nonReentrant`  
**Events**: `USDCWithdrawnFromAave(uint256 amount)`

#### `harvestAaveYield() → (uint256)`
```solidity
function harvestAaveYield() external returns (uint256 yieldAmount)
```

**Modifiers**: `onlyRole(YIELD_MANAGER_ROLE)`, `whenNotPaused`, `nonReentrant`  
**Events**: `AaveYieldHarvested(uint256 amount)`

#### `getAaveBalance() → (uint256)`
```solidity
function getAaveBalance() external view returns (uint256 balance)
```

#### `getAaveAPY() → (uint256)`
```solidity
function getAaveAPY() external view returns (uint256 apy)
```

**Returns**: APY in basis points

#### `autoRebalance() → (bool, uint256, uint256)`
```solidity
function autoRebalance() external returns (
    bool rebalanced,
    uint256 newAllocation,
    uint256 expectedYield
)
```

---

## YieldShift

**Contract**: `YieldShift.sol`  
**Interface**: `IYieldShift.sol`  
**Inherits**: `SecureUpgradeable`, `PausableUpgradeable`

### Function Signatures

#### `addYield(uint256 qeuroAmount)`
```solidity
function addYield(uint256 qeuroAmount) external
```

**Modifiers**: `onlyAuthorizedYieldSource`, `whenNotPaused`, `nonReentrant`  
**Events**: `YieldAdded(address indexed source, uint256 amount)`  
**Requirements**:
- `qeuroAmount > 0`
- Sufficient QEURO balance and allowance

#### `distributeYield()`
```solidity
function distributeYield() external
```

**Modifiers**: `onlyRole(YIELD_MANAGER_ROLE)`, `whenNotPaused`, `nonReentrant`  
**Events**: `YieldDistributed(uint256 userPoolAmount, uint256 hedgerPoolAmount)`

#### `claimUserYield() → (uint256)`
```solidity
function claimUserYield() external returns (uint256 yieldAmount)
```

**Modifiers**: `onlyUserPool`, `whenNotPaused`, `nonReentrant`  
**Events**: `UserYieldClaimed(uint256 amount)`

#### `claimHedgerYield() → (uint256)`
```solidity
function claimHedgerYield() external returns (uint256 yieldAmount)
```

**Modifiers**: `onlyHedgerPool`, `whenNotPaused`, `nonReentrant`  
**Events**: `HedgerYieldClaimed(uint256 amount)`

#### `getPoolMetrics() → (uint256, uint256, uint256, uint256)`
```solidity
function getPoolMetrics() external view returns (
    uint256 userPoolSize,
    uint256 hedgerPoolSize,
    uint256 poolRatio,
    uint256 targetRatio
)
```

#### `calculateOptimalYieldShift() → (uint256, uint256, uint256)`
```solidity
function calculateOptimalYieldShift() external view returns (
    uint256 userPoolAllocation,
    uint256 hedgerPoolAllocation,
    uint256 shiftAmount
)
```

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

### AaveVault
- `MAX_AAVE_EXPOSURE`: 80% of total USDC
- `MIN_AAVE_EXPOSURE`: 0%
- `REBALANCE_THRESHOLD`: 5% deviation

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
| `closeHedgePosition` | 180,000 |
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
