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


### mintFee
Protocol fee charged on minting QEURO (in basis points)

Example: 10 = 0.1% minting fee

Revenue source for the protocol


```solidity
uint256 public mintFee
```


### redemptionFee
Protocol fee charged on redeeming QEURO (in basis points)

Example: 10 = 0.1% redemption fee

Revenue source for the protocol


```solidity
uint256 public redemptionFee
```


### TAKES_FEES_DURING_LIQUIDATION
Whether fees are taken during liquidation mode redemption

Set to true by default - fees are charged even in liquidation mode

Can be changed by governance if needed


```solidity
bool public constant TAKES_FEES_DURING_LIQUIDATION = true
```


### minCollateralizationRatioForMinting
Minimum collateralization ratio required for minting QEURO (in basis points)

Example: 10500 = 105% collateralization ratio required for minting

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

### _flashLoanProtectionBefore


```solidity
function _flashLoanProtectionBefore() private;
```

### _flashLoanProtectionAfter


```solidity
function _flashLoanProtectionAfter() private view;
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


### _autoDeployToAave

Internal function to auto-deploy USDC to Aave after minting

Silently catches errors to ensure minting always succeeds even if Aave has issues

**Notes:**
- security: Uses try-catch to prevent Aave issues from blocking user mints

- validation: Validates AaveVault is set and amount > 0

- state-changes: Updates totalUsdcHeld and totalUsdcInAave on success

- events: Emits UsdcDeployedToAave on success

- errors: Silently swallows errors to ensure mints always succeed

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


### _executeAaveDeployment

External function to execute Aave deployment (called by _autoDeployToAave via try/catch)

This is external so it can be called via try/catch for error handling

**Notes:**
- security: Only callable from this contract

- validation: Validates sufficient balance

- state-changes: Updates totalUsdcHeld and totalUsdcInAave

- events: Emits UsdcDeployedToAave

- errors: Throws if insufficient balance or Aave deployment fails

- reentrancy: Not protected - internal helper

- access: Internal use only (via try/catch)

- oracle: No oracle dependencies


```solidity
function _executeAaveDeployment(uint256 usdcAmount) external;
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
- Fees are applied if TAKES_FEES_DURING_LIQUIDATION is true
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


### _redeemLiquidationMode

Internal function for liquidation mode redemption (pro-rata based on actual USDC)

Internal function to handle QEURO redemption in liquidation mode (CR ≤ 101%)

Called by redeemQEURO when protocol is in liquidation mode (CR <= 101%)

Key formulas:
- Payout = (qeuroAmount / totalSupply) * totalVaultUsdc (actual USDC, not market value)
- Hedger loss = (qeuroAmount / totalSupply) * hedgerMargin (proportional margin reduction)
- Fees applied if TAKES_FEES_DURING_LIQUIDATION is true

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


### _ensureSufficientUsdcForPayout

Ensures vault has sufficient USDC for payout, withdrawing from Aave if needed

Withdraws from Aave to cover deficit; reverts if totalAvailable < usdcAmount

**Notes:**
- security: Internal; may call Aave withdrawal

- validation: totalAvailable >= usdcAmount after withdrawal

- state-changes: totalUsdcHeld, totalUsdcInAave via _withdrawUsdcFromAave

- events: Via _withdrawUsdcFromAave

- errors: InsufficientBalance if cannot meet usdcAmount

- reentrancy: External call to Aave; caller in CEI context

- access: Internal

- oracle: None


```solidity
function _ensureSufficientUsdcForPayout(uint256 usdcAmount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC needed|


### _calculateLiquidationFees

Calculates liquidation fees if enabled

fee = usdcPayout * redemptionFee / 1e18 when TAKES_FEES_DURING_LIQUIDATION; else 0

**Notes:**
- security: View only

- validation: Uses redemptionFee and TAKES_FEES_DURING_LIQUIDATION

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
|`fee`|`uint256`|Fee amount (0 if fees disabled)|
|`netPayout`|`uint256`|Net payout after fees|


### _notifyHedgerPoolLiquidation

Notifies hedger pool of liquidation redemption for margin adjustment

Calls hedgerPool.recordLiquidationRedeem(qeuroAmount, totalSupply); no-op if hedgerPool zero or no margin

**Notes:**
- security: Try/catch; failure does not revert redemption

- validation: Skips if hedgerPool is zero or totalMargin is 0

- state-changes: HedgerPool state via recordLiquidationRedeem

- events: Via HedgerPool

- errors: Swallowed by try/catch

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

- validation: TAKES_FEES_DURING_LIQUIDATION and fee > 0

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
- Fees applied if TAKES_FEES_DURING_LIQUIDATION is true

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

Calculates mint amount based on current oracle price and protocol fees

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: No state changes

- events: No events emitted

- errors: No errors thrown

- reentrancy: No reentrancy protection needed

- access: No access restrictions

- oracle: Requires fresh oracle price data


```solidity
function calculateMintAmount(uint256 usdcAmount) external returns (uint256 qeuroAmount, uint256 fee);
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

Calculates redeem amount based on current oracle price and protocol fees

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: No state changes

- events: No events emitted

- errors: No errors thrown

- reentrancy: No reentrancy protection needed

- access: No access restrictions

- oracle: Requires fresh oracle price data


```solidity
function calculateRedeemAmount(uint256 qeuroAmount) external returns (uint256 usdcAmount, uint256 fee);
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
|`_mintFee`|`uint256`|New minting fee|
|`_redemptionFee`|`uint256`|New redemption fee|


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


### getProtocolCollateralizationRatio

Calculates the current protocol collateralization ratio

Formula: CR = (TotalVaultUSDC / BackingRequirement) × 100
Where:
- TotalVaultUSDC = totalUsdcHeld + totalUsdcInAave (raw USDC, not effective margin)
- BackingRequirement = QEUROSupply × OraclePrice / 1e30 (USDC value of all QEURO)
Returns ratio in 18 decimals:
- 100% = 1e20 (100000000000000000000)
- 101% = 1.01e20 (101000000000000000000)
Liquidation mode is triggered when CR <= 101% (10100 bps).
In liquidation mode, redemptions use pro-rata USDC distribution instead of fair value.

**Notes:**
- security: View function that reads state and oracle - safe for external calls

- validation: Validates hedgerPool and userPool are set, oracle price is valid

- state-changes: Updates oracle timestamp (via getEurUsdPrice call)

- events: None - view function

- errors: Reverts with InvalidOraclePrice if oracle data is invalid

- reentrancy: Not applicable - no state changes, only reads

- access: Public - anyone can check collateralization ratio

- oracle: Requires fresh oracle price data


```solidity
function getProtocolCollateralizationRatio() public returns (uint256 ratio);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ratio`|`uint256`|Current collateralization ratio in 18 decimals|


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
function canMint() public returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|canMint Whether minting is currently allowed|


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
function shouldTriggerLiquidation() public returns (bool shouldLiquidate);
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

### _syncMintWithHedgers

Internal helper to notify HedgerPool about user mints

Attempts to update hedger fills but swallows failures to avoid blocking users

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
function _syncMintWithHedgers(uint256 amount, uint256 fillPrice, uint256 qeuroAmount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Net USDC amount minted into QEURO (6 decimals)|
|`fillPrice`|`uint256`|EUR/USD oracle price used for the mint (18 decimals)|
|`qeuroAmount`|`uint256`|QEURO amount that was minted (18 decimals)|


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


### setDevMode

Toggles dev mode to disable price caching requirements

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
function setDevMode(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`enabled`|`bool`|True to enable dev mode, false to disable|


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

