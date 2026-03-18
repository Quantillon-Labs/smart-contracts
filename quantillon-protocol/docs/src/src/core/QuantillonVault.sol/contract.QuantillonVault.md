# QuantillonVault
**Inherits:**
Initializable, ReentrancyGuardUpgradeable, AccessControlUpgradeable, PausableUpgradeable, [SecureUpgradeable](/src/core/SecureUpgradeable.sol/abstract.SecureUpgradeable.md)

**Title:**
QuantillonVault

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Main vault managing QEURO minting against USDC collateral

Main characteristics:
- Simple USDC to QEURO swap mechanism
- USDC as input for QEURO minting
- Real-time EUR/USD price oracle integration
- Dynamic fee structure for protocol sustainability
- Emergency pause mechanism for crisis situations
- Upgradeable via UUPS pattern

Minting mechanics:
- Users swap USDC for QEURO
- QEURO is minted based on EUR/USD exchange rate
- Minting fees charged for protocol revenue
- Simple 1:1 exchange with price conversion
- Price deviation protection prevents flash loan manipulation
- Block-based validation ensures price freshness

Redemption mechanics:
- Users can redeem QEURO back to USDC
- Redemption based on current EUR/USD exchange rate
- Protocol fees charged on redemptions
- USDC returned to user after fee deduction
- Same price deviation protection as minting
- Consistent security across all operations

Risk management:
- Real-time price monitoring
- Emergency pause capabilities
- Slippage protection on swaps
- Flash loan attack prevention via price deviation checks
- Block-based price manipulation detection
- Comprehensive oracle validation and fallback mechanisms

Fee structure:
- Minting fees for creating QEURO
- Redemption fees for converting QEURO back to USDC
- Dynamic fee adjustment based on market conditions

Security features:
- Role-based access control for all critical operations
- Reentrancy protection for all external calls
- Emergency pause mechanism for crisis situations
- Upgradeable architecture for future improvements
- Secure collateral management
- Oracle price validation
- Flash loan protection through price deviation checks
- Block-based price update validation
- Comprehensive price manipulation attack prevention

Integration points:
- QEURO token for minting and burning
- USDC for collateral deposits and withdrawals
- Chainlink oracle for EUR/USD price feeds
- Vault math library for precise calculations

**Note:**
security-contact: team@quantillon.money


## State Variables
### GOVERNANCE_ROLE
Role for governance operations (parameter updates, emergency actions)

keccak256 hash avoids role collisions with other contracts

Should be assigned to governance multisig or DAO


```solidity
bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE")
```


### EMERGENCY_ROLE
Role for emergency operations (pause)

keccak256 hash avoids role collisions with other contracts

Should be assigned to emergency multisig


```solidity
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE")
```


### VAULT_OPERATOR_ROLE
Role for vault operators (UserPool) to trigger Aave deployments

keccak256 hash avoids role collisions with other contracts

Should be assigned to UserPool contract


```solidity
bytes32 public constant VAULT_OPERATOR_ROLE = keccak256("VAULT_OPERATOR_ROLE")
```


### MAX_PRICE_DEVIATION
Maximum allowed price deviation between consecutive price updates (in basis points)

Prevents flash loan price manipulation attacks

200 basis points = 2% maximum deviation


```solidity
uint256 private constant MAX_PRICE_DEVIATION = 200
```


### MIN_BLOCKS_BETWEEN_UPDATES
Minimum number of blocks required between price updates for deviation checks

Prevents manipulation within the same block


```solidity
uint256 private constant MIN_BLOCKS_BETWEEN_UPDATES = 1
```


### MIN_COLLATERALIZATION_RATIO_FOR_MINTING

```solidity
uint256 private constant MIN_COLLATERALIZATION_RATIO_FOR_MINTING = 105e18
```


### CRITICAL_COLLATERALIZATION_RATIO_BPS

```solidity
uint256 private constant CRITICAL_COLLATERALIZATION_RATIO_BPS = 10100
```


### MIN_ALLOWED_COLLATERALIZATION_RATIO

```solidity
uint256 private constant MIN_ALLOWED_COLLATERALIZATION_RATIO = 101e18
```


### MIN_ALLOWED_CRITICAL_RATIO

```solidity
uint256 private constant MIN_ALLOWED_CRITICAL_RATIO = 100e18
```


### qeuro
QEURO token contract for minting and burning

Used for all QEURO minting and burning operations

Should be the official QEURO token contract


```solidity
IQEUROToken public qeuro
```


### usdc
USDC token used as collateral

Used for all collateral deposits, withdrawals, and fee payments

Should be the official USDC contract on the target network


```solidity
IERC20 public usdc
```


### oracle
Oracle contract for EUR/USD price feeds (Chainlink or Stork via router)

Provides real-time EUR/USD exchange rates for minting and redemption

Used for price calculations in swap operations


```solidity
IOracle public oracle
```


### hedgerPool
HedgerPool contract for collateralization checks

Used to verify protocol has sufficient hedging positions before minting QEURO

Ensures protocol is properly collateralized by hedgers


```solidity
IHedgerPool public hedgerPool
```


### userPool
UserPool contract for user deposit tracking

Used to get total user deposits for collateralization ratio calculations

Required for accurate protocol collateralization assessment


```solidity
IUserPool public userPool
```


### treasury
Treasury address for ETH recovery

SECURITY: Only this address can receive ETH from recoverETH function


```solidity
address public treasury
```


### feeCollector
Fee collector contract for protocol fees

Centralized fee collection and distribution


```solidity
address public feeCollector
```


### _flashLoanBalanceBefore
USDC balance before flash loan check (used by flashLoanProtection modifier)


```solidity
uint256 private _flashLoanBalanceBefore
```


### aaveVault
AaveVault contract for USDC yield generation

Used to deploy idle USDC to Aave lending pool


```solidity
IAaveVault public aaveVault
```


### totalUsdcInAave
Total USDC deployed to Aave for yield generation

Tracks USDC that has been sent to AaveVault


```solidity
uint256 public totalUsdcInAave
```


### stQEUROFactory
stQEURO factory used to register this vault's staking token.


```solidity
address public stQEUROFactory
```


### stQEUROToken
stQEURO token address registered for this vault.


```solidity
address public stQEUROToken
```


### stQEUROVaultId
Registry id used when creating this vault's stQEURO token.


```solidity
uint256 public stQEUROVaultId
```


### mintFee
Protocol fee charged on minting QEURO

INFO-7: Fee denominated in 1e18 precision — 1e16 = 1%, 1e18 = 100% (NOT basis points)

Revenue source for the protocol


```solidity
uint256 public mintFee
```


### redemptionFee
Protocol fee charged on redeeming QEURO

INFO-7: Fee denominated in 1e18 precision — 1e16 = 1%, 1e18 = 100% (NOT basis points)

Revenue source for the protocol


```solidity
uint256 public redemptionFee
```


### hedgerRewardFeeSplit
Share of protocol fees routed to HedgerPool reward reserve (1e18 = 100%)


```solidity
uint256 public hedgerRewardFeeSplit
```


### MAX_HEDGER_REWARD_FEE_SPLIT
Maximum value allowed for hedgerRewardFeeSplit


```solidity
uint256 public constant MAX_HEDGER_REWARD_FEE_SPLIT = 1e18
```


### minCollateralizationRatioForMinting
Minimum collateralization ratio required for minting QEURO (in 1e18 precision, NOT basis points)

INFO-7: Example: 105000000000000000000 = 105% collateralization ratio required for minting

When protocol collateralization >= this threshold, minting is allowed

When protocol collateralization < this threshold, minting is halted

Can be updated by governance to adjust protocol risk parameters

Stored in 18 decimals format (e.g., 105000000000000000000 = 105.000000%)


```solidity
uint256 public minCollateralizationRatioForMinting
```


### criticalCollateralizationRatio
Critical collateralization ratio that triggers liquidation (in 18 decimals)

Example: 101000000000000000000 = 101.000000% collateralization ratio triggers liquidation

When protocol collateralization < this threshold, hedgers start being liquidated

Emergency threshold to protect protocol solvency

Can be updated by governance to adjust liquidation triggers

Stored in 18 decimals format (e.g., 101000000000000000000 = 101.000000%)


```solidity
uint256 public criticalCollateralizationRatio
```


### totalUsdcHeld
Total USDC held in the vault

Used for vault analytics and risk management


```solidity
uint256 public totalUsdcHeld
```


### totalMinted
Total QEURO in circulation (minted by this vault)


```solidity
uint256 public totalMinted
```


### lastValidEurUsdPrice
Last valid EUR/USD price used in operations

Used for price deviation checks to prevent manipulation


```solidity
uint256 private lastValidEurUsdPrice
```


### lastPriceUpdateBlock
Block number of the last price update

Used to ensure minimum blocks between updates for deviation checks


```solidity
uint256 private lastPriceUpdateBlock
```


### devModeEnabled
Dev mode flag to disable price caching requirements

When enabled, price deviation checks and caching requirements are skipped (dev/testing only)


```solidity
bool public devModeEnabled
```


### DEV_MODE_DELAY
MED-1: Minimum delay before a proposed dev-mode change takes effect


```solidity
uint256 public constant DEV_MODE_DELAY = 48 hours
```


### DEV_MODE_DELAY_BLOCKS
MED-1: Canonical block delay for dev-mode proposals (12s block target)


```solidity
uint256 public constant DEV_MODE_DELAY_BLOCKS = DEV_MODE_DELAY / 12
```


### pendingDevMode
MED-1: Pending dev-mode value awaiting the timelock delay


```solidity
bool public pendingDevMode
```


### devModePendingAt
MED-1: Block at which pendingDevMode may be applied (0 = no pending proposal)


```solidity
uint256 public devModePendingAt
```


### lastPriceUpdateTime
Variable to store the timestamp of the last valid price update


```solidity
uint256 private lastPriceUpdateTime
```


## Functions
### flashLoanProtection

Modifier to protect against flash loan attacks

Uses the FlashLoanProtectionLibrary to check USDC balance consistency


```solidity
modifier flashLoanProtection() ;
```

### onlySelf


```solidity
modifier onlySelf() ;
```

### _flashLoanProtectionBefore


```solidity
function _flashLoanProtectionBefore() private;
```

### _flashLoanProtectionAfter


```solidity
function _flashLoanProtectionAfter() private view;
```

### _onlySelf

Reverts unless caller is this contract

Used to gate commit-phase functions invoked through explicit self-calls.

**Notes:**
- security: Prevents external callers from invoking internal commit entrypoints directly

- validation: Reverts when `msg.sender != address(this)`

- state-changes: None

- events: None

- errors: Reverts with `NotAuthorized` if caller is not self

- reentrancy: No external calls

- access: Internal helper

- oracle: No oracle dependencies


```solidity
function _onlySelf() internal view;
```

### constructor

Constructor for QuantillonVault contract

Disables initializers for security

**Notes:**
- security: Disables initializers for security

- validation: No validation needed

- state-changes: Disables initializers

- events: No events emitted

- errors: No errors thrown

- reentrancy: No reentrancy protection needed

- access: No access restrictions

- oracle: No oracle dependencies

- oz-upgrades-unsafe-allow: constructor


```solidity
constructor() ;
```

### initialize

Initializes the vault with contracts and parameters

This function configures:
1. Access roles
2. References to external contracts
3. Default protocol parameters
4. Security (pause, reentrancy, upgrades)

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Initializes all contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to initializer modifier

- oracle: No oracle dependencies


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
) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address with administrator privileges|
|`_qeuro`|`address`|Address of the QEURO token contract|
|`_usdc`|`address`|Address of the USDC token contract|
|`_oracle`|`address`|Address of the Oracle contract|
|`_hedgerPool`|`address`|Address of the HedgerPool contract|
|`_userPool`|`address`|Address of the UserPool contract|
|`_timelock`|`address`|Address of the timelock contract|
|`_feeCollector`|`address`|Address of the fee collector contract|


### mintQEURO

Mints QEURO tokens by swapping USDC

Minting process:
1. Fetch EUR/USD price from oracle
2. Calculate amount of QEURO to mint
3. Transfer USDC from user
4. Update vault balances
5. Mint QEURO to user

Example: 1100 USDC → ~1000 QEURO (if EUR/USD = 1.10)
Simple swap with protocol fee applied

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: No access restrictions

- oracle: Requires fresh oracle price data


```solidity
function mintQEURO(uint256 usdcAmount, uint256 minQeuroOut)
    external
    nonReentrant
    whenNotPaused
    flashLoanProtection;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC to swap for QEURO|
|`minQeuroOut`|`uint256`|Minimum amount of QEURO expected (slippage protection)|


### _mintQEUROCommit

Commits mint flow effects/interactions after validation phase

Called via explicit self-call from `mintQEURO` to separate validation and commit phases.

**Notes:**
- security: Restricted by `onlySelf`; executed from `nonReentrant` parent flow

- validation: Assumes caller already validated collateralization and oracle constraints

- state-changes: Updates vault accounting, oracle cache timestamps, and optional Aave principal tracker

- events: Emits `QEUROminted` and potentially downstream fee/yield events

- errors: Token, hedger sync, fee routing, and Aave operations may revert

- reentrancy: Structured CEI commit path called from guarded parent

- access: External self-call entrypoint only

- oracle: Uses pre-validated oracle price input


```solidity
function _mintQEUROCommit(
    address minter,
    uint256 usdcAmount,
    uint256 fee,
    uint256 netAmount,
    uint256 qeuroToMint,
    uint256 eurUsdPrice,
    bool isValidPrice
) external onlySelf;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minter`|`address`|User receiving freshly minted QEURO|
|`usdcAmount`|`uint256`|Gross USDC transferred in|
|`fee`|`uint256`|Protocol fee portion from `usdcAmount`|
|`netAmount`|`uint256`|Net USDC credited to collateral after fees|
|`qeuroToMint`|`uint256`|QEURO amount to mint for `minter`|
|`eurUsdPrice`|`uint256`|Validated EUR/USD price used for accounting cache|
|`isValidPrice`|`bool`|Whether oracle read used for cache timestamp was valid|


### _autoDeployToAave

Internal function to auto-deploy USDC to Aave after minting

Uses strict CEI ordering and lets failures revert to preserve accounting integrity

**Notes:**
- security: Updates accounting before external interaction to remove reentrancy windows

- validation: Validates AaveVault is set and amount > 0

- state-changes: Updates totalUsdcHeld and totalUsdcInAave before calling AaveVault

- events: Emits UsdcDeployedToAave on success

- errors: Reverts on failed deployment or invalid Aave return value

- reentrancy: Not protected - internal function only

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function _autoDeployToAave(uint256 usdcAmount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC to deploy (6 decimals)|


### redeemQEURO

Redeems QEURO for USDC - automatically routes to normal or liquidation mode

Redeem process:
1. Check if protocol is in liquidation mode (CR <= 101%)
2. If liquidation mode: use pro-rata distribution based on actual USDC in vault
- Payout = (qeuroAmount / totalSupply) * totalVaultUsdc
- Hedger loses margin proportionally: (qeuroAmount / totalSupply) * hedgerMargin
- Fees are always applied using `redemptionFee`
3. If normal mode: use oracle price with standard fees
4. Burn QEURO and transfer USDC

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits QEURORedeemed or LiquidationRedeemed based on mode

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: No access restrictions

- oracle: Requires fresh oracle price data

- security: No flash loan protection needed - legitimate redemption operation


```solidity
function redeemQEURO(uint256 qeuroAmount, uint256 minUsdcOut) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount of QEURO to swap for USDC|
|`minUsdcOut`|`uint256`|Minimum amount of USDC expected|


### _redeemQEUROCommit

Commits normal-mode redemption effects/interactions after validation

Called via explicit self-call from `redeemQEURO`.

**Notes:**
- security: Restricted by `onlySelf`; called from `nonReentrant` parent flow

- validation: Reverts if held liquidity is insufficient or mint tracker underflows

- state-changes: Updates collateral/mint trackers and price cache

- events: Emits `QEURORedeemed` and downstream fee routing events

- errors: Reverts on insufficient balances, token failures, or downstream integration failures

- reentrancy: CEI commit path invoked from guarded parent

- access: External self-call entrypoint only

- oracle: Uses pre-validated oracle price input


```solidity
function _redeemQEUROCommit(
    address redeemer,
    uint256 qeuroAmount,
    uint256 usdcToReturn,
    uint256 netUsdcToReturn,
    uint256 fee,
    uint256 eurUsdPrice,
    bool isValidPrice,
    uint256 aaveWithdrawalAmount
) external onlySelf;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`redeemer`|`address`|User redeeming QEURO|
|`qeuroAmount`|`uint256`|QEURO amount burned from `redeemer`|
|`usdcToReturn`|`uint256`|Gross USDC redemption amount before fee transfer split|
|`netUsdcToReturn`|`uint256`|Net USDC transferred to the redeemer|
|`fee`|`uint256`|Protocol fee amount from redemption|
|`eurUsdPrice`|`uint256`|Validated EUR/USD price used for cache update|
|`isValidPrice`|`bool`|Whether oracle read used for cache timestamp was valid|
|`aaveWithdrawalAmount`|`uint256`|Planned USDC amount to source from Aave (if needed)|


### _redeemLiquidationMode

Internal function for liquidation mode redemption (pro-rata based on actual USDC)

Internal function to handle QEURO redemption in liquidation mode (CR ≤ 101%)

Called by redeemQEURO when protocol is in liquidation mode (CR <= 101%)

Key formulas:
- Payout = (qeuroAmount / totalSupply) * totalVaultUsdc (actual USDC, not market value)
- Hedger loss = (qeuroAmount / totalSupply) * hedgerMargin (proportional margin reduction)
- Fees applied using `redemptionFee`

Called by redeemQEURO when protocol enters liquidation mode
Liquidation Mode Formulas:
1. userPayout = (qeuroAmount / totalQEUROSupply) × totalVaultUSDC
- Pro-rata distribution based on actual USDC, NOT fair value
- If CR < 100%, users take a haircut
- If CR > 100%, users receive a small premium
2. hedgerLoss = (qeuroAmount / totalQEUROSupply) × hedgerMargin
- Hedger absorbs proportional margin loss
- Recorded via hedgerPool.recordLiquidationRedeem()
In liquidation mode, hedger's unrealizedPnL = -margin (all margin at risk).

**Notes:**
- security: Internal function - handles liquidation redemptions with pro-rata distribution

- validation: Validates totalSupply > 0, oracle price valid, usdcPayout >= minUsdcOut, sufficient balance

- state-changes: Reduces totalUsdcHeld, totalMinted, calls hedgerPool.recordLiquidationRedeem

- events: Emits LiquidationRedeemed

- errors: Reverts with InvalidAmount, InvalidOraclePrice, ExcessiveSlippage, InsufficientBalance

- reentrancy: Protected by CEI pattern - state changes before external calls

- access: Internal function - called by redeemQEURO

- oracle: Requires valid EUR/USD price from oracle


```solidity
function _redeemLiquidationMode(uint256 qeuroAmount, uint256 minUsdcOut, uint256 collateralizationRatioBps)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount of QEURO to redeem (18 decimals)|
|`minUsdcOut`|`uint256`|Minimum USDC expected (slippage protection)|
|`collateralizationRatioBps`|`uint256`|Current CR in basis points (for event emission)|


### _redeemLiquidationCommit

Commits liquidation-mode redemption effects/interactions

Called via explicit self-call from `_redeemLiquidationMode`.

**Notes:**
- security: Restricted by `onlySelf`; called from guarded liquidation flow

- validation: Reverts on insufficient balances or mint tracker underflow

- state-changes: Updates collateral/mint trackers and notifies hedger pool liquidation accounting

- events: Emits `LiquidationRedeemed` and downstream fee routing events

- errors: Reverts on balance/transfer/integration failures

- reentrancy: CEI commit path invoked from `nonReentrant` parent

- access: External self-call entrypoint only

- oracle: No direct oracle reads (uses precomputed inputs)


```solidity
function _redeemLiquidationCommit(
    address redeemer,
    uint256 qeuroAmount,
    uint256 totalSupply,
    uint256 usdcPayout,
    uint256 netUsdcPayout,
    uint256 fee,
    uint256 collateralizationRatioBps,
    bool isPremium,
    uint256 aaveWithdrawalAmount
) external onlySelf;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`redeemer`|`address`|User redeeming in liquidation mode|
|`qeuroAmount`|`uint256`|QEURO amount burned|
|`totalSupply`|`uint256`|Total QEURO supply used for proportional hedger adjustment|
|`usdcPayout`|`uint256`|Gross pro-rata USDC payout|
|`netUsdcPayout`|`uint256`|Net payout transferred to user after fees|
|`fee`|`uint256`|Protocol fee amount|
|`collateralizationRatioBps`|`uint256`|Protocol collateralization ratio (bps) for event metadata|
|`isPremium`|`bool`|Whether gross payout is at/above fair value|
|`aaveWithdrawalAmount`|`uint256`|Planned Aave withdrawal amount needed for payout|


### _planAaveWithdrawal

Calculates required Aave withdrawal to satisfy a USDC payout

Returns zero when vault-held USDC already covers `requiredUsdc`.

**Notes:**
- security: Enforces that Aave vault is configured before planning an Aave-backed withdrawal

- validation: Reverts with `InsufficientBalance` when deficit exists and Aave is not configured

- state-changes: None

- events: None

- errors: Reverts with `InsufficientBalance` when no Aave source exists for deficit

- reentrancy: No external calls

- access: Internal helper

- oracle: No oracle dependencies


```solidity
function _planAaveWithdrawal(uint256 requiredUsdc) internal view returns (uint256 aaveWithdrawalAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requiredUsdc`|`uint256`|Target USDC amount that must be available in vault balance|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`aaveWithdrawalAmount`|`uint256`|Additional USDC that should be sourced from Aave|


### _calculateLiquidationFees

Calculates liquidation fees from gross liquidation payout.

Fees are always applied in liquidation mode: `fee = usdcPayout * redemptionFee / 1e18`.

**Notes:**
- security: View only

- validation: Uses current `redemptionFee` in 1e18 precision

- state-changes: None

- events: None

- errors: None

- reentrancy: None

- access: Internal

- oracle: None


```solidity
function _calculateLiquidationFees(uint256 usdcPayout) internal view returns (uint256 fee, uint256 netPayout);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcPayout`|`uint256`|Gross payout amount|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`fee`|`uint256`|Fee amount|
|`netPayout`|`uint256`|Net payout after fees|


### _notifyHedgerPoolLiquidation

Notifies hedger pool of liquidation redemption for margin adjustment.

LOW-3 hardening: when hedger collateral exists, this call is atomic and must succeed.
It is skipped only when HedgerPool is unset or has zero collateral.

**Notes:**
- security: Reverts liquidation flow if HedgerPool call fails while collateral exists

- validation: Skips only when HedgerPool is zero or totalMargin is 0

- state-changes: HedgerPool state via recordLiquidationRedeem

- events: Via HedgerPool

- errors: Bubbles HedgerPool errors in atomic path

- reentrancy: External call to HedgerPool

- access: Internal

- oracle: None


```solidity
function _notifyHedgerPoolLiquidation(uint256 qeuroAmount, uint256 totalSupply) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount of QEURO being redeemed|
|`totalSupply`|`uint256`|Total QEURO supply for pro-rata calculation|


### _transferLiquidationFees

Transfers liquidation fees to fee collector if applicable

Approves USDC to FeeCollector and calls collectFees; no-op if fees disabled or fee is 0

**Notes:**
- security: Requires approve and collectFees to succeed

- validation: `fee > 0`

- state-changes: USDC balance of feeCollector

- events: Via FeeCollector

- errors: TokenTransferFailed if approve fails

- reentrancy: External call to FeeCollector

- access: Internal

- oracle: None


```solidity
function _transferLiquidationFees(uint256 fee) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fee`|`uint256`|Fee amount to transfer|


### redeemQEUROLiquidation

Redeems QEURO for USDC using pro-rata distribution in liquidation mode

Only callable when protocol is in liquidation mode (CR <= 101%)

Key formulas:
- Payout = (qeuroAmount / totalSupply) * totalVaultUsdc (actual USDC in vault)
- Hedger loss = (qeuroAmount / totalSupply) * hedgerMargin (realized as negative P&L)
- Fees always applied using `redemptionFee`

Premium if CR > 100%, haircut if CR < 100%

**Notes:**
- security: Protected by nonReentrant, requires liquidation mode

- validation: Validates qeuroAmount > 0, minUsdcOut slippage, liquidation mode

- state-changes: Burns QEURO, transfers USDC pro-rata, reduces hedger margin proportionally

- events: Emits LiquidationRedeemed

- errors: Reverts if not in liquidation mode or slippage exceeded

- reentrancy: Protected by nonReentrant modifier

- access: Public - anyone with QEURO can redeem

- oracle: Requires oracle price for fair value calculation


```solidity
function redeemQEUROLiquidation(uint256 qeuroAmount, uint256 minUsdcOut) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount of QEURO to redeem (18 decimals)|
|`minUsdcOut`|`uint256`|Minimum USDC expected (slippage protection)|


### getVaultMetrics

Retrieves the vault's global metrics

Returns comprehensive vault metrics for monitoring and analytics

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: No state changes

- events: No events emitted

- errors: No errors thrown

- reentrancy: No reentrancy protection needed

- access: No access restrictions

- oracle: No oracle dependencies


```solidity
function getVaultMetrics()
    external
    view
    returns (
        uint256 totalUsdcHeld_,
        uint256 totalMinted_,
        uint256 totalDebtValue,
        uint256 totalUsdcInAave_,
        uint256 totalUsdcAvailable_
    );
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalUsdcHeld_`|`uint256`|Total USDC held directly in the vault|
|`totalMinted_`|`uint256`|Total QEURO minted|
|`totalDebtValue`|`uint256`|Total debt value in USD|
|`totalUsdcInAave_`|`uint256`|Total USDC deployed to Aave for yield|
|`totalUsdcAvailable_`|`uint256`|Total USDC available (vault + Aave)|


### calculateMintAmount

Calculates the amount of QEURO that can be minted for a given USDC amount

Calculates mint amount based on cached oracle price and protocol fees

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: No state changes

- events: No events emitted

- errors: No errors thrown

- reentrancy: No reentrancy protection needed

- access: No access restrictions

- oracle: Uses cached oracle price (`lastValidEurUsdPrice`)


```solidity
function calculateMintAmount(uint256 usdcAmount) external view returns (uint256 qeuroAmount, uint256 fee);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC to swap|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount of QEURO that will be minted (after fees)|
|`fee`|`uint256`|Protocol fee|


### calculateRedeemAmount

Calculates the amount of USDC received for a QEURO redemption

Calculates redeem amount based on cached oracle price and protocol fees

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: No state changes

- events: No events emitted

- errors: No errors thrown

- reentrancy: No reentrancy protection needed

- access: No access restrictions

- oracle: Uses cached oracle price (`lastValidEurUsdPrice`)


```solidity
function calculateRedeemAmount(uint256 qeuroAmount) external view returns (uint256 usdcAmount, uint256 fee);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount of QEURO to redeem|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|USDC received (after fees)|
|`fee`|`uint256`|Protocol fee|


### isProtocolCollateralized

Checks if the protocol is properly collateralized by hedgers

Public view function to check collateralization status

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can check collateralization status

- oracle: No oracle dependencies


```solidity
function isProtocolCollateralized() external view returns (bool isCollateralized, uint256 totalMargin);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isCollateralized`|`bool`|True if protocol has active hedging positions|
|`totalMargin`|`uint256`|Total margin in HedgerPool (0 if not set)|


### updateParameters

Updates the vault parameters (governance only)

Safety constraints:
- Fees <= 5% (user protection)

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to GOVERNANCE_ROLE

- oracle: No oracle dependencies


```solidity
function updateParameters(uint256 _mintFee, uint256 _redemptionFee) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_mintFee`|`uint256`|New minting fee (1e18 precision, 1e18 = 100%)|
|`_redemptionFee`|`uint256`|New redemption fee (1e18 precision, 1e18 = 100%)|


### updateHedgerRewardFeeSplit

Updates the fee share routed to HedgerPool reward reserve.

Governance-controlled split applied in `_routeProtocolFees`.

**Notes:**
- security: Restricted to governance and bounded by max split constant.

- validation: Reverts when `newSplit` exceeds `MAX_HEDGER_REWARD_FEE_SPLIT`.

- state-changes: Updates `hedgerRewardFeeSplit`.

- events: Emits `HedgerRewardFeeSplitUpdated`.

- errors: Reverts with `ConfigValueTooHigh` on invalid split.

- reentrancy: Not applicable - simple state update.

- access: Restricted to `GOVERNANCE_ROLE`.

- oracle: No oracle interaction.


```solidity
function updateHedgerRewardFeeSplit(uint256 newSplit) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newSplit`|`uint256`|Share in 1e18 precision (1e18 = 100%).|


### updateCollateralizationThresholds

Updates the collateralization thresholds (governance only)

Safety constraints:
- minCollateralizationRatioForMinting >= 101000000000000000000 (101.000000% minimum = 101 * 1e18)
- criticalCollateralizationRatio <= minCollateralizationRatioForMinting
- criticalCollateralizationRatio >= 100000000000000000000 (100.000000% minimum = 100 * 1e18)

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to GOVERNANCE_ROLE

- oracle: No oracle dependencies


```solidity
function updateCollateralizationThresholds(
    uint256 _minCollateralizationRatioForMinting,
    uint256 _criticalCollateralizationRatio
) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_minCollateralizationRatioForMinting`|`uint256`|New minimum collateralization ratio for minting (in 18 decimals)|
|`_criticalCollateralizationRatio`|`uint256`|New critical collateralization ratio for liquidation (in 18 decimals)|


### updateOracle

Updates the oracle address

Updates the oracle contract address for price feeds

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function updateOracle(address _oracle) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_oracle`|`address`|New oracle address|


### updateHedgerPool

Updates the HedgerPool address

Updates the HedgerPool contract address for collateralization checks

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to GOVERNANCE_ROLE

- oracle: No oracle dependencies


```solidity
function updateHedgerPool(address _hedgerPool) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_hedgerPool`|`address`|New HedgerPool address|


### updateUserPool

Updates the UserPool address

Updates the UserPool contract address for user deposit tracking

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to GOVERNANCE_ROLE

- oracle: No oracle dependencies


```solidity
function updateUserPool(address _userPool) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_userPool`|`address`|New UserPool address|


### updateFeeCollector

Updates the fee collector address

Only governance role can update the fee collector address

**Notes:**
- security: Validates address is not zero before updating

- validation: Ensures _feeCollector is not address(0)

- state-changes: Updates feeCollector state variable

- events: Emits ParametersUpdated event

- errors: Reverts if _feeCollector is address(0)

- reentrancy: No reentrancy risk, simple state update

- access: Restricted to GOVERNANCE_ROLE

- oracle: No oracle dependencies


```solidity
function updateFeeCollector(address _feeCollector) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_feeCollector`|`address`|New fee collector address|


### updateAaveVault

Updates the AaveVault address for USDC yield generation

Only governance role can update the AaveVault address

**Notes:**
- security: Validates address is not zero before updating

- validation: Ensures _aaveVault is not address(0)

- state-changes: Updates aaveVault state variable

- events: Emits AaveVaultUpdated event

- errors: Reverts if _aaveVault is address(0)

- reentrancy: No reentrancy risk, simple state update

- access: Restricted to GOVERNANCE_ROLE

- oracle: No oracle dependencies


```solidity
function updateAaveVault(address _aaveVault) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_aaveVault`|`address`|New AaveVault address|


### selfRegisterStQEURO

Registers this vault in stQEUROFactory using strict self-call semantics.

Previews deterministic token address, binds local state, then executes factory registration and verifies match.

**Notes:**
- security: Restricted to governance and protected by `nonReentrant`.

- validation: Requires non-zero factory address, non-zero vault id, and uninitialized local stQEURO state.

- state-changes: Sets `stQEUROFactory`, `stQEUROToken`, and `stQEUROVaultId` for this vault.

- events: Emits `StQEURORegistered` after successful factory registration.

- errors: Reverts on invalid inputs, duplicate initialization, or mismatched preview/registered token address.

- reentrancy: Guarded by `nonReentrant`; state binding follows CEI before external registration call.

- access: Restricted to `GOVERNANCE_ROLE`.

- oracle: No oracle dependencies.


```solidity
function selfRegisterStQEURO(address factory, uint256 vaultId, string calldata vaultName)
    external
    onlyRole(GOVERNANCE_ROLE)
    nonReentrant
    returns (address token);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`factory`|`address`|Address of stQEUROFactory.|
|`vaultId`|`uint256`|Desired vault id in the factory registry.|
|`vaultName`|`string`|Uppercase alphanumeric vault name.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Newly deployed stQEURO token address.|


### harvestAaveInterest

Harvests accrued Aave interest through AaveVault and routes yield via YieldShift.

HIGH-2 / NEW-1 remediation entrypoint for explicit yield synchronization.

**Notes:**
- security: Restricted to governance and guarded by `nonReentrant`.

- validation: Requires configured AaveVault address.

- state-changes: May update Aave-side accounting and emits local harvest event.

- events: Emits `AaveInterestHarvested`.

- errors: Reverts when AaveVault is unset or downstream harvest call fails.

- reentrancy: Protected by `nonReentrant`.

- access: Restricted to `GOVERNANCE_ROLE`.

- oracle: No direct oracle interaction.


```solidity
function harvestAaveInterest() external onlyRole(GOVERNANCE_ROLE) nonReentrant returns (uint256 harvestedYield);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`harvestedYield`|`uint256`|Amount harvested by AaveVault (USDC 6 decimals).|


### deployUsdcToAave

Deploys USDC from the vault to Aave for yield generation

Called by UserPool after minting QEURO to automatically deploy USDC to Aave

**Notes:**
- security: Only callable by VAULT_OPERATOR_ROLE (UserPool)

- validation: Validates amount > 0, AaveVault is set, and sufficient USDC balance

- state-changes: Updates totalUsdcHeld (decreases) and totalUsdcInAave (increases)

- events: Emits UsdcDeployedToAave event

- errors: Reverts if amount is 0, AaveVault not set, or insufficient USDC

- reentrancy: Protected by nonReentrant modifier

- access: Restricted to VAULT_OPERATOR_ROLE

- oracle: No oracle dependencies


```solidity
function deployUsdcToAave(uint256 usdcAmount) external nonReentrant onlyRole(VAULT_OPERATOR_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC to deploy to Aave (6 decimals)|


### _withdrawUsdcFromAave

Withdraws USDC from Aave back to the vault

Called internally when redemptions require more USDC than available in vault

**Notes:**
- security: Internal function, called during redemption flow

- validation: Validates amount > 0 and AaveVault is set

- state-changes: Updates totalUsdcHeld (increases) and totalUsdcInAave (decreases)

- events: Emits UsdcWithdrawnFromAave event

- errors: Reverts if amount is 0 or AaveVault not set

- reentrancy: Not protected - internal function only

- access: Internal function - called by redeemQEURO

- oracle: No oracle dependencies


```solidity
function _withdrawUsdcFromAave(uint256 usdcAmount) internal returns (uint256 usdcWithdrawn);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC to withdraw from Aave (6 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`usdcWithdrawn`|`uint256`|Actual amount of USDC withdrawn|


### withdrawProtocolFees

Withdraws accumulated protocol fees

Fees accumulate during minting and redemptions

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function withdrawProtocolFees(address to) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Destination address for the fees|


### addHedgerDeposit

Adds hedger USDC deposit to vault's total USDC reserves

Called by HedgerPool when hedgers open positions to unify USDC liquidity

**Notes:**
- security: Validates caller is HedgerPool contract and amount is positive

- validation: Validates amount > 0 and caller is authorized HedgerPool

- state-changes: Updates totalUsdcHeld with hedger deposit amount

- events: Emits HedgerDepositAdded with deposit details

- errors: Throws "Vault: Only HedgerPool can call" if caller is not HedgerPool

- errors: Throws "Vault: Amount must be positive" if amount is zero

- reentrancy: Protected by nonReentrant modifier

- access: Restricted to HedgerPool contract only

- oracle: No oracle dependencies


```solidity
function addHedgerDeposit(uint256 usdcAmount) external nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC deposited by hedger (6 decimals)|


### withdrawHedgerDeposit

Withdraws hedger USDC deposit from vault's reserves

Called by HedgerPool when hedgers close positions to return their deposits

**Notes:**
- security: Validates caller is HedgerPool, amount is positive, and sufficient reserves

- validation: Validates amount > 0, caller is authorized, and totalUsdcHeld >= amount

- state-changes: Updates totalUsdcHeld and transfers USDC to hedger

- events: Emits HedgerDepositWithdrawn with withdrawal details

- errors: Throws "Vault: Only HedgerPool can call" if caller is not HedgerPool

- errors: Throws "Vault: Amount must be positive" if amount is zero

- errors: Throws "Vault: Insufficient USDC reserves" if not enough USDC available

- reentrancy: Protected by nonReentrant modifier

- access: Restricted to HedgerPool contract only

- oracle: No oracle dependencies


```solidity
function withdrawHedgerDeposit(address hedger, uint256 usdcAmount) external nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger receiving the USDC|
|`usdcAmount`|`uint256`|Amount of USDC to withdraw (6 decimals)|


### getTotalUsdcAvailable

Gets the total USDC available (vault + Aave)

Returns total USDC that can be used for withdrawals/redemptions

**Notes:**
- security: No security validations required - view function

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not applicable - view function

- access: Public access - anyone can query total USDC available

- oracle: No oracle dependencies


```solidity
function getTotalUsdcAvailable() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Total USDC available (vault + Aave) (6 decimals)|


### updatePriceCache

Updates the price cache with the current oracle price

Allows governance to manually refresh the price cache to prevent deviation check failures

Useful when price has moved significantly and cache needs to be updated

**Notes:**
- security: Only callable by governance role

- validation: Validates oracle price is valid before updating cache

- state-changes: Updates lastValidEurUsdPrice, lastPriceUpdateBlock, and lastPriceUpdateTime

- events: Emits PriceCacheUpdated event

- errors: Reverts if oracle price is invalid

- reentrancy: Not applicable - no external calls after state changes

- access: Restricted to GOVERNANCE_ROLE

- oracle: Requires valid oracle price


```solidity
function updatePriceCache() external onlyRole(GOVERNANCE_ROLE) nonReentrant;
```

### _applyPriceCacheUpdate

Applies a validated price cache update

Commit-phase helper called via explicit self-call from `updatePriceCache`.

**Notes:**
- security: Restricted by `onlySelf`

- validation: Assumes caller already validated oracle output

- state-changes: Updates `lastValidEurUsdPrice`, `lastPriceUpdateBlock`, and `lastPriceUpdateTime`

- events: Emits `PriceCacheUpdated`

- errors: None

- reentrancy: No external calls

- access: External self-call entrypoint only

- oracle: No direct oracle reads (uses pre-validated input)


```solidity
function _applyPriceCacheUpdate(uint256 oldPrice, uint256 eurUsdPrice) external onlySelf;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldPrice`|`uint256`|Previous cached EUR/USD price|
|`eurUsdPrice`|`uint256`|New validated EUR/USD price|


### _updatePriceTimestamp

Updates the last valid price timestamp when a valid price is fetched

Internal function to track price update timing for monitoring

**Notes:**
- security: Updates timestamp only for valid price fetches

- validation: No input validation required

- state-changes: Updates lastPriceUpdateTime if price is valid

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not protected - internal function only

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function _updatePriceTimestamp(bool isValid) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`isValid`|`bool`|Whether the current price fetch was valid|


### _getAaveCollateralBalance

Returns current Aave collateral balance including accrued yield when available.

Falls back to tracked principal if the external balance query is unavailable.

**Notes:**
- security: View helper with defensive fallback path.

- validation: Returns tracked principal when Aave balance query reverts.

- state-changes: None - view function.

- events: None.

- errors: None - errors are caught via try/catch fallback.

- reentrancy: Not applicable - view function.

- access: Internal helper.

- oracle: No oracle interaction.


```solidity
function _getAaveCollateralBalance() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|collateralBalance Aave-side collateral balance in USDC units (6 decimals).|


### _getTotalCollateralWithAccruedYield

HIGH-2/NEW-1: total protocol collateral including accrued Aave interest.

Uses on-chain Aave balance (principal + yield) with a principal fallback path.

**Notes:**
- security: View helper used by CR calculations and withdrawal checks.

- validation: Relies on `_getAaveCollateralBalance` fallback behavior.

- state-changes: None - view function.

- events: None.

- errors: None.

- reentrancy: Not applicable - view function.

- access: Internal helper.

- oracle: No oracle interaction.


```solidity
function _getTotalCollateralWithAccruedYield() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|totalCollateral Combined vault-held + Aave-held collateral in USDC units (6 decimals).|


### _routeProtocolFees

MED-2: routes protocol fees between HedgerPool reserve and FeeCollector at source.

Splits fee flow using `hedgerRewardFeeSplit` and transfers shares to each destination.

**Notes:**
- security: Validates required dependency addresses before routing each share.

- validation: No-op when `fee == 0`; reverts on unset required destinations.

- state-changes: Increases allowances and forwards fee shares to HedgerPool/FeeCollector.

- events: Emits `ProtocolFeeRouted`.

- errors: Reverts when HedgerPool/FeeCollector dependencies are unset for non-zero shares.

- reentrancy: Internal function; external calls are to configured protocol dependencies.

- access: Internal helper.

- oracle: No oracle interaction.


```solidity
function _routeProtocolFees(uint256 fee, string memory sourceType) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fee`|`uint256`|Total fee amount in USDC (6 decimals).|
|`sourceType`|`string`|Source tag passed through to FeeCollector accounting.|


### getProtocolCollateralizationRatio

Calculates the current protocol collateralization ratio.

Formula: `CR = (TotalCollateral / BackingRequirement) * 1e20`
Where:
- `TotalCollateral = totalUsdcHeld + currentAaveCollateral` (includes accrued Aave yield when available)
- `BackingRequirement = QEUROSupply * cachedEurUsdPrice / 1e30` (USDC value of outstanding debt)
Returns ratio in 18-decimal percentage format:
- `100% = 1e20`
- `101% = 1.01e20`

**Notes:**
- security: View function using cached price and current collateral state

- validation: Returns 0 if pools are unset, supply is 0, or price cache is uninitialized

- state-changes: None

- events: None

- errors: None

- reentrancy: Not applicable - view function

- access: Public - anyone can check collateralization ratio

- oracle: Uses cached oracle price (`lastValidEurUsdPrice`)


```solidity
function getProtocolCollateralizationRatio() public view returns (uint256 ratio);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ratio`|`uint256`|Current collateralization ratio in 18-decimal percentage format|


### canMint

Checks if minting is allowed based on current collateralization ratio

Returns true if collateralization ratio >= minCollateralizationRatioForMinting

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: No state changes - view function

- events: No events emitted - view function

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can check minting status

- oracle: No oracle dependencies


```solidity
function canMint() public view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|canMint Whether minting is currently allowed|


### getProtocolCollateralizationRatioView

LOW-4: Pure view variant of getProtocolCollateralizationRatio using cached oracle price.

Delegates to `getProtocolCollateralizationRatio()` and performs no state refresh.

**Notes:**
- security: View-only wrapper.

- validation: Inherits validation/fallback behavior from delegated function.

- state-changes: None - view function.

- events: None.

- errors: None.

- reentrancy: Not applicable - view function.

- access: Public.

- oracle: Uses cached oracle price.


```solidity
function getProtocolCollateralizationRatioView() public view returns (uint256 ratio);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ratio`|`uint256`|Current collateralization ratio in 1e18-scaled percentage format.|


### canMintView

LOW-4: Pure view variant of canMint using cached oracle price.

Delegates to `canMint()` and performs no state refresh.

**Notes:**
- security: View-only wrapper.

- validation: Inherits price-cache and hedger-liveness checks from delegated function.

- state-changes: None - view function.

- events: None.

- errors: None.

- reentrancy: Not applicable - view function.

- access: Public.

- oracle: Uses cached oracle price.


```solidity
function canMintView() public view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|mintAllowed True when mint preconditions currently pass.|


### initializePriceCache

LOW-5: Seeds the oracle price cache so minting checks have a baseline.

Governance MUST call this once immediately after deployment, before any user mints.
Uses an explicit bootstrap price to avoid external oracle interaction in this state-changing call.

**Notes:**
- security: Restricted to governance.

- validation: Requires `initialEurUsdPrice > 0`.

- state-changes: Sets `lastValidEurUsdPrice`, `lastPriceUpdateBlock`, and `lastPriceUpdateTime`.

- events: Emits `PriceCacheUpdated`.

- errors: Reverts when price is zero or cache is already initialized.

- reentrancy: Not applicable - no external callbacks.

- access: Restricted to `GOVERNANCE_ROLE`.

- oracle: Bootstrap input should come from governance/oracle process.


```solidity
function initializePriceCache(uint256 initialEurUsdPrice) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`initialEurUsdPrice`|`uint256`|Initial EUR/USD price in 18 decimals.|


### shouldTriggerLiquidation

Checks if liquidation should be triggered based on current collateralization ratio

Returns true if collateralization ratio < criticalCollateralizationRatio

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: No state changes - view function

- events: No events emitted - view function

- errors: No errors thrown - safe view function

- reentrancy: Not applicable - view function

- access: Public - anyone can check liquidation status

- oracle: No oracle dependencies


```solidity
function shouldTriggerLiquidation() public view returns (bool shouldLiquidate);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shouldLiquidate`|`bool`|Whether liquidation should be triggered|


### getLiquidationStatus

Returns liquidation status and key metrics for pro-rata redemption

Protocol enters liquidation mode when CR <= 101%. In this mode, users can redeem pro-rata.

**Notes:**
- security: View function - no state changes

- validation: No input validation required

- state-changes: None - view function

- events: None

- errors: None

- reentrancy: Not applicable - view function

- access: Public - anyone can check liquidation status

- oracle: Requires oracle price for collateral calculation


```solidity
function getLiquidationStatus()
    external
    view
    returns (
        bool isInLiquidation,
        uint256 collateralizationRatioBps,
        uint256 totalCollateralUsdc,
        uint256 totalQeuroSupply
    );
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isInLiquidation`|`bool`|True if protocol is in liquidation mode (CR <= 101%)|
|`collateralizationRatioBps`|`uint256`|Current collateralization ratio in basis points (e.g., 10100 = 101%)|
|`totalCollateralUsdc`|`uint256`|Total protocol collateral in USDC (6 decimals)|
|`totalQeuroSupply`|`uint256`|Total QEURO supply (18 decimals)|


### calculateLiquidationPayout

Calculates pro-rata payout for liquidation mode redemption

Formula: payout = (qeuroAmount / totalSupply) * totalCollateral

Premium if CR > 100%, haircut if CR < 100%

**Notes:**
- security: View function - no state changes

- validation: Validates qeuroAmount > 0

- state-changes: None - view function

- events: None

- errors: Throws InvalidAmount if qeuroAmount is 0

- reentrancy: Not applicable - view function

- access: Public - anyone can calculate payout

- oracle: Requires oracle price for fair value calculation


```solidity
function calculateLiquidationPayout(uint256 qeuroAmount)
    external
    view
    returns (uint256 usdcPayout, bool isPremium, uint256 premiumOrDiscountBps);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount of QEURO to redeem (18 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`usdcPayout`|`uint256`|Amount of USDC the user would receive (6 decimals)|
|`isPremium`|`bool`|True if payout > fair value (CR > 100%), false if haircut (CR < 100%)|
|`premiumOrDiscountBps`|`uint256`|Premium or discount in basis points (e.g., 50 = 0.5%)|


### getPriceProtectionStatus

Returns the current price protection status

Useful for monitoring and debugging price protection

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function getPriceProtectionStatus()
    external
    view
    returns (uint256 lastValidPrice, uint256 lastUpdateBlock, uint256 maxDeviation, uint256 minBlocks);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`lastValidPrice`|`uint256`|Last valid EUR/USD price used|
|`lastUpdateBlock`|`uint256`|Block number of last price update|
|`maxDeviation`|`uint256`|Maximum allowed price deviation in basis points|
|`minBlocks`|`uint256`|Minimum blocks required between updates|


### pause

Pauses all vault operations

When paused:
- No mint/redeem possible
- Read functions still active

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function pause() external onlyRole(EMERGENCY_ROLE);
```

### unpause

Unpauses and resumes operations

Resumes all vault operations after emergency pause

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function unpause() external onlyRole(EMERGENCY_ROLE);
```

### recoverToken

Recovers tokens accidentally sent to the vault to treasury only

Protections:
- Cannot recover own vault tokens
- Tokens are sent to treasury address only
- Only third-party tokens can be recovered

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to DEFAULT_ADMIN_ROLE

- oracle: No oracle dependencies


```solidity
function recoverToken(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token contract address|
|`amount`|`uint256`|Amount to recover|


### recoverETH

Recover ETH to treasury address only

SECURITY: Restricted to treasury to prevent arbitrary ETH transfers

Security considerations:
- Only DEFAULT_ADMIN_ROLE can recover
- Prevents sending to zero address
- Validates balance before attempting transfer
- Uses call() for reliable ETH transfers to any contract

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function recoverETH() external onlyRole(DEFAULT_ADMIN_ROLE);
```

### _syncMintWithHedgersOrRevert

Internal helper to notify HedgerPool about user mints.

LOW-5 / INFO-2: mint path must fail if hedger synchronization fails.

**Notes:**
- security: Internal hard-fail synchronization helper.

- validation: No-op on zero amount; otherwise requires downstream HedgerPool success.

- state-changes: No direct state changes in vault; delegates accounting updates to HedgerPool.

- events: None in vault.

- errors: Propagates HedgerPool reverts to preserve atomicity.

- reentrancy: Not applicable - internal helper.

- access: Internal helper.

- oracle: Uses provided cached/fetched fill price from caller context.


```solidity
function _syncMintWithHedgersOrRevert(uint256 amount, uint256 fillPrice, uint256 qeuroAmount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Gross USDC amount allocated to hedger fills (6 decimals).|
|`fillPrice`|`uint256`|EUR/USD price used for fill accounting (18 decimals).|
|`qeuroAmount`|`uint256`|QEURO minted amount to track against hedger exposure (18 decimals).|


### _syncRedeemWithHedgers

Internal helper to notify HedgerPool about user redeems

Attempts to release hedger fills but swallows failures to avoid blocking users

**Notes:**
- security: Internal helper; relies on HedgerPool access control

- validation: No additional validation beyond non-zero guard

- state-changes: None inside the vault; delegates to HedgerPool

- events: None

- errors: Silently ignores downstream errors

- reentrancy: Not applicable

- access: Internal helper

- oracle: Not applicable


```solidity
function _syncRedeemWithHedgers(uint256 amount, uint256 redeemPrice, uint256 qeuroAmount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Gross USDC returned to the user (6 decimals)|
|`redeemPrice`|`uint256`|EUR/USD oracle price used for the redeem (18 decimals)|
|`qeuroAmount`|`uint256`|QEURO amount that was redeemed (18 decimals)|


### proposeDevMode

Toggles dev mode to disable price caching requirements

MED-1: Propose a dev-mode change; enforces a 48-hour timelock before it can be applied

DEV ONLY: When enabled, price deviation checks are skipped for testing

**Notes:**
- security: Only callable by DEFAULT_ADMIN_ROLE

- validation: No input validation required

- state-changes: Updates devModeEnabled flag

- events: Emits DevModeToggled event

- errors: No errors thrown

- reentrancy: Not protected - simple state change

- access: Restricted to DEFAULT_ADMIN_ROLE

- oracle: No oracle dependencies


```solidity
function proposeDevMode(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`enabled`|`bool`|True to enable dev mode, false to disable|


### applyDevMode

MED-1: Apply a previously proposed dev-mode change after the timelock has elapsed.

Finalizes the pending proposal created by `proposeDevMode`.

**Notes:**
- security: Restricted to default admin and time-locked via `DEV_MODE_DELAY`.

- validation: Requires active pending proposal and elapsed delay.

- state-changes: Updates `devModeEnabled` and clears `devModePendingAt`.

- events: Emits `DevModeToggled`.

- errors: Reverts when no proposal is pending or delay is not satisfied.

- reentrancy: Not applicable - simple state transition.

- access: Restricted to `DEFAULT_ADMIN_ROLE`.

- oracle: No oracle interaction.


```solidity
function applyDevMode() external onlyRole(DEFAULT_ADMIN_ROLE);
```

## Events
### QEUROminted
Emitted when QEURO is minted


```solidity
event QEUROminted(address indexed user, uint256 usdcAmount, uint256 qeuroAmount);
```

### QEURORedeemed
Emitted when QEURO is redeemed


```solidity
event QEURORedeemed(address indexed user, uint256 qeuroAmount, uint256 usdcAmount);
```

### LiquidationRedeemed
Emitted when QEURO is redeemed in liquidation mode (pro-rata)


```solidity
event LiquidationRedeemed(
    address indexed user, uint256 qeuroAmount, uint256 usdcPayout, uint256 collateralizationRatioBps, bool isPremium
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user redeeming QEURO|
|`qeuroAmount`|`uint256`|Amount of QEURO redeemed (18 decimals)|
|`usdcPayout`|`uint256`|Amount of USDC received (6 decimals)|
|`collateralizationRatioBps`|`uint256`|Protocol CR at redemption time (basis points)|
|`isPremium`|`bool`|True if user received more than fair value (CR > 100%)|

### HedgerPoolNotificationFailed
LOW-3: Emitted when notifying HedgerPool of a liquidation redemption fails


```solidity
event HedgerPoolNotificationFailed(uint256 qeuroAmount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount of QEURO that was being redeemed|

### HedgerDepositAdded
Emitted when hedger deposits USDC to vault for unified liquidity


```solidity
event HedgerDepositAdded(address indexed hedgerPool, uint256 usdcAmount, uint256 totalUsdcHeld);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedgerPool`|`address`|Address of the HedgerPool contract that made the deposit|
|`usdcAmount`|`uint256`|Amount of USDC deposited (6 decimals)|
|`totalUsdcHeld`|`uint256`|New total USDC held in vault after deposit (6 decimals)|

### HedgerDepositWithdrawn
Emitted when hedger withdraws USDC from vault


```solidity
event HedgerDepositWithdrawn(address indexed hedger, uint256 usdcAmount, uint256 totalUsdcHeld);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger receiving the USDC|
|`usdcAmount`|`uint256`|Amount of USDC withdrawn (6 decimals)|
|`totalUsdcHeld`|`uint256`|New total USDC held in vault after withdrawal (6 decimals)|

### ParametersUpdated
Emitted when parameters are changed

OPTIMIZED: Indexed parameter type for efficient filtering


```solidity
event ParametersUpdated(string indexed parameterType, uint256 mintFee, uint256 redemptionFee);
```

### CollateralizationThresholdsUpdated
Emitted when price deviation protection is triggered

Emitted when collateralization thresholds are updated by governance

Helps monitor potential flash loan attacks


```solidity
event CollateralizationThresholdsUpdated(
    uint256 indexed minCollateralizationRatioForMinting,
    uint256 indexed criticalCollateralizationRatio,
    address indexed caller
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minCollateralizationRatioForMinting`|`uint256`|New minimum collateralization ratio for minting (in 18 decimals)|
|`criticalCollateralizationRatio`|`uint256`|New critical collateralization ratio for liquidation (in 18 decimals)|
|`caller`|`address`|Address of the governance role holder who updated the thresholds|

### CollateralizationStatusChanged
Emitted when protocol collateralization status changes


```solidity
event CollateralizationStatusChanged(
    uint256 indexed currentRatio, bool indexed canMint, bool indexed shouldLiquidate
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currentRatio`|`uint256`|Current protocol collateralization ratio (in basis points)|
|`canMint`|`bool`|Whether minting is currently allowed based on collateralization|
|`shouldLiquidate`|`bool`|Whether liquidation should be triggered based on collateralization|

### PriceDeviationDetected

```solidity
event PriceDeviationDetected(
    uint256 currentPrice, uint256 lastValidPrice, uint256 deviationBps, uint256 blockNumber
);
```

### PriceCacheUpdated
Emitted when price cache is manually updated by governance


```solidity
event PriceCacheUpdated(uint256 oldPrice, uint256 newPrice, uint256 blockNumber);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldPrice`|`uint256`|Previous cached price|
|`newPrice`|`uint256`|New cached price|
|`blockNumber`|`uint256`|Block number when cache was updated|

### DevModeToggled
Emitted when dev mode is toggled


```solidity
event DevModeToggled(bool enabled, address indexed caller);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`enabled`|`bool`|Whether dev mode is enabled or disabled|
|`caller`|`address`|Address that triggered the toggle|

### DevModeProposed
MED-1: Emitted when a dev-mode change is proposed


```solidity
event DevModeProposed(bool pending, uint256 activatesAt);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pending`|`bool`|The proposed dev-mode value|
|`activatesAt`|`uint256`|Timestamp at which the change can be applied|

### AaveVaultUpdated
Emitted when AaveVault address is updated


```solidity
event AaveVaultUpdated(address indexed oldAaveVault, address indexed newAaveVault);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldAaveVault`|`address`|Previous AaveVault address|
|`newAaveVault`|`address`|New AaveVault address|

### StQEURORegistered

```solidity
event StQEURORegistered(
    address indexed factory, uint256 indexed vaultId, address indexed stQEUROToken, string vaultName
);
```

### UsdcDeployedToAave
Emitted when USDC is deployed to Aave for yield generation


```solidity
event UsdcDeployedToAave(uint256 indexed usdcAmount, uint256 totalUsdcInAave);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC deployed to Aave|
|`totalUsdcInAave`|`uint256`|New total USDC in Aave after deployment|

### AaveDeploymentFailed

```solidity
event AaveDeploymentFailed(uint256 amount, bytes reason);
```

### HedgerSyncFailed

```solidity
event HedgerSyncFailed(string operation, uint256 amount, uint256 price, bytes reason);
```

### UsdcWithdrawnFromAave
Emitted when USDC is withdrawn from Aave


```solidity
event UsdcWithdrawnFromAave(uint256 indexed usdcAmount, uint256 totalUsdcInAave);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC withdrawn from Aave|
|`totalUsdcInAave`|`uint256`|New total USDC in Aave after withdrawal|

### HedgerRewardFeeSplitUpdated

```solidity
event HedgerRewardFeeSplitUpdated(uint256 previousSplit, uint256 newSplit);
```

### AaveInterestHarvested

```solidity
event AaveInterestHarvested(uint256 harvestedYield);
```

### ProtocolFeeRouted

```solidity
event ProtocolFeeRouted(string sourceType, uint256 totalFee, uint256 hedgerReserveShare, uint256 collectorShare);
```

