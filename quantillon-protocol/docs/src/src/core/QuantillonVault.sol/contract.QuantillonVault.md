# QuantillonVault
**Inherits:**
Initializable, ReentrancyGuardUpgradeable, AccessControlUpgradeable, PausableUpgradeable, [SecureUpgradeable](/src/core/SecureUpgradeable.sol/abstract.SecureUpgradeable.md)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Main vault managing QEURO minting against USDC collateral

*Main characteristics:
- Simple USDC to QEURO swap mechanism
- USDC as input for QEURO minting
- Real-time EUR/USD price oracle integration
- Dynamic fee structure for protocol sustainability
- Emergency pause mechanism for crisis situations
- Upgradeable via UUPS pattern*

*Minting mechanics:
- Users swap USDC for QEURO
- QEURO is minted based on EUR/USD exchange rate
- Minting fees charged for protocol revenue
- Simple 1:1 exchange with price conversion
- Price deviation protection prevents flash loan manipulation
- Block-based validation ensures price freshness*

*Redemption mechanics:
- Users can redeem QEURO back to USDC
- Redemption based on current EUR/USD exchange rate
- Protocol fees charged on redemptions
- USDC returned to user after fee deduction
- Same price deviation protection as minting
- Consistent security across all operations*

*Risk management:
- Real-time price monitoring
- Emergency pause capabilities
- Slippage protection on swaps
- Flash loan attack prevention via price deviation checks
- Block-based price manipulation detection
- Comprehensive oracle validation and fallback mechanisms*

*Fee structure:
- Minting fees for creating QEURO
- Redemption fees for converting QEURO back to USDC
- Dynamic fee adjustment based on market conditions*

*Security features:
- Role-based access control for all critical operations
- Reentrancy protection for all external calls
- Emergency pause mechanism for crisis situations
- Upgradeable architecture for future improvements
- Secure collateral management
- Oracle price validation
- Flash loan protection through price deviation checks
- Block-based price update validation
- Comprehensive price manipulation attack prevention*

*Integration points:
- QEURO token for minting and burning
- USDC for collateral deposits and withdrawals
- Chainlink oracle for EUR/USD price feeds
- Vault math library for precise calculations*

**Note:**
team@quantillon.money


## State Variables
### GOVERNANCE_ROLE
Role for governance operations (parameter updates, emergency actions)

*keccak256 hash avoids role collisions with other contracts*

*Should be assigned to governance multisig or DAO*


```solidity
bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
```


### EMERGENCY_ROLE
Role for emergency operations (pause)

*keccak256 hash avoids role collisions with other contracts*

*Should be assigned to emergency multisig*


```solidity
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
```


### MAX_PRICE_DEVIATION
Maximum allowed price deviation between consecutive price updates (in basis points)

*Prevents flash loan price manipulation attacks*

*200 basis points = 2% maximum deviation*


```solidity
uint256 private constant MAX_PRICE_DEVIATION = 200;
```


### MIN_BLOCKS_BETWEEN_UPDATES
Minimum number of blocks required between price updates for deviation checks

*Prevents manipulation within the same block*


```solidity
uint256 private constant MIN_BLOCKS_BETWEEN_UPDATES = 1;
```


### qeuro
QEURO token contract for minting and burning

*Used for all QEURO minting and burning operations*

*Should be the official QEURO token contract*


```solidity
IQEUROToken public qeuro;
```


### usdc
USDC token used as collateral

*Used for all collateral deposits, withdrawals, and fee payments*

*Should be the official USDC contract on the target network*


```solidity
IERC20 public usdc;
```


### oracle
Chainlink oracle contract for EUR/USD price feeds

*Provides real-time EUR/USD exchange rates for minting and redemption*

*Used for price calculations in swap operations*


```solidity
IChainlinkOracle public oracle;
```


### hedgerPool
HedgerPool contract for collateralization checks

*Used to verify protocol has sufficient hedging positions before minting QEURO*

*Ensures protocol is properly collateralized by hedgers*


```solidity
IHedgerPool public hedgerPool;
```


### userPool
UserPool contract for user deposit tracking

*Used to get total user deposits for collateralization ratio calculations*

*Required for accurate protocol collateralization assessment*


```solidity
IUserPool public userPool;
```


### treasury
Treasury address for ETH recovery

*SECURITY: Only this address can receive ETH from recoverETH function*


```solidity
address public treasury;
```


### feeCollector
Fee collector contract for protocol fees

*Centralized fee collection and distribution*


```solidity
address public feeCollector;
```


### mintFee
Protocol fee charged on minting QEURO (in basis points)

*Example: 10 = 0.1% minting fee*

*Revenue source for the protocol*


```solidity
uint256 public mintFee;
```


### redemptionFee
Protocol fee charged on redeeming QEURO (in basis points)

*Example: 10 = 0.1% redemption fee*

*Revenue source for the protocol*


```solidity
uint256 public redemptionFee;
```


### minCollateralizationRatioForMinting
Minimum collateralization ratio required for minting QEURO (in basis points)

*Example: 10500 = 105% collateralization ratio required for minting*

*When protocol collateralization >= this threshold, minting is allowed*

*When protocol collateralization < this threshold, minting is halted*

*Can be updated by governance to adjust protocol risk parameters*


```solidity
uint256 public minCollateralizationRatioForMinting;
```


### criticalCollateralizationRatio
Critical collateralization ratio that triggers liquidation (in basis points)

*Example: 10100 = 101% collateralization ratio triggers liquidation*

*When protocol collateralization < this threshold, hedgers start being liquidated*

*Emergency threshold to protect protocol solvency*

*Can be updated by governance to adjust liquidation triggers*


```solidity
uint256 public criticalCollateralizationRatio;
```


### totalUsdcHeld
Total USDC held in the vault

*Used for vault analytics and risk management*


```solidity
uint256 public totalUsdcHeld;
```


### totalMinted
Total QEURO in circulation (minted by this vault)


```solidity
uint256 public totalMinted;
```


### lastValidEurUsdPrice
Last valid EUR/USD price used in operations

*Used for price deviation checks to prevent manipulation*


```solidity
uint256 private lastValidEurUsdPrice;
```


### lastPriceUpdateBlock
Block number of the last price update

*Used to ensure minimum blocks between updates for deviation checks*


```solidity
uint256 private lastPriceUpdateBlock;
```


### lastPriceUpdateTime
Variable to store the timestamp of the last valid price update


```solidity
uint256 private lastPriceUpdateTime;
```


## Functions
### flashLoanProtection

Modifier to protect against flash loan attacks

*Uses the FlashLoanProtectionLibrary to check USDC balance consistency*


```solidity
modifier flashLoanProtection();
```

### constructor

Constructor for QuantillonVault contract

*Disables initializers for security*

**Notes:**
- Disables initializers for security

- No validation needed

- Disables initializers

- No events emitted

- No errors thrown

- No reentrancy protection needed

- No access restrictions

- No oracle dependencies

- constructor


```solidity
constructor();
```

### initialize

Initializes the vault with contracts and parameters

*This function configures:
1. Access roles
2. References to external contracts
3. Default protocol parameters
4. Security (pause, reentrancy, upgrades)*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Initializes all contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to initializer modifier

- No oracle dependencies


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

*Minting process:
1. Fetch EUR/USD price from oracle
2. Calculate amount of QEURO to mint
3. Transfer USDC from user
4. Update vault balances
5. Mint QEURO to user*

*Example: 1100 USDC → ~1000 QEURO (if EUR/USD = 1.10)
Simple swap with protocol fee applied*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- No access restrictions

- Requires fresh oracle price data


```solidity
function mintQEURO(uint256 usdcAmount, uint256 minQeuroOut) external nonReentrant whenNotPaused flashLoanProtection;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC to swap for QEURO|
|`minQeuroOut`|`uint256`|Minimum amount of QEURO expected (slippage protection)|


### redeemQEURO

Redeems QEURO for USDC

*Redeem process:
1. Calculate USDC to return based on EUR/USD price
2. Apply protocol fees
3. Burn QEURO
4. Update vault balances
5. Transfer USDC to user*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- No access restrictions

- Requires fresh oracle price data

- No flash loan protection needed - legitimate redemption operation


```solidity
function redeemQEURO(uint256 qeuroAmount, uint256 minUsdcOut) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount of QEURO to swap for USDC|
|`minUsdcOut`|`uint256`|Minimum amount of USDC expected|


### getVaultMetrics

Retrieves the vault's global metrics

*Returns comprehensive vault metrics for monitoring and analytics*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- No state changes

- No events emitted

- No errors thrown

- No reentrancy protection needed

- No access restrictions

- No oracle dependencies


```solidity
function getVaultMetrics() external returns (uint256 totalUsdcHeld_, uint256 totalMinted_, uint256 totalDebtValue);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalUsdcHeld_`|`uint256`|Total USDC held in the vault|
|`totalMinted_`|`uint256`|Total QEURO minted|
|`totalDebtValue`|`uint256`|Total debt value in USD|


### calculateMintAmount

Calculates the amount of QEURO that can be minted for a given USDC amount

*Calculates mint amount based on current oracle price and protocol fees*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- No state changes

- No events emitted

- No errors thrown

- No reentrancy protection needed

- No access restrictions

- Requires fresh oracle price data


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

*Calculates redeem amount based on current oracle price and protocol fees*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- No state changes

- No events emitted

- No errors thrown

- No reentrancy protection needed

- No access restrictions

- Requires fresh oracle price data


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

*Public view function to check collateralization status*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can check collateralization status

- No oracle dependencies


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

*Safety constraints:
- Fees <= 5% (user protection)*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to GOVERNANCE_ROLE

- No oracle dependencies


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

*Safety constraints:
- minCollateralizationRatioForMinting >= 10100 (101% minimum)
- criticalCollateralizationRatio <= minCollateralizationRatioForMinting
- criticalCollateralizationRatio >= 10000 (100% minimum)*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to GOVERNANCE_ROLE

- No oracle dependencies


```solidity
function updateCollateralizationThresholds(
    uint256 _minCollateralizationRatioForMinting,
    uint256 _criticalCollateralizationRatio
) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_minCollateralizationRatioForMinting`|`uint256`|New minimum collateralization ratio for minting (in basis points)|
|`_criticalCollateralizationRatio`|`uint256`|New critical collateralization ratio for liquidation (in basis points)|


### updateOracle

Updates the oracle address

*Updates the oracle contract address for price feeds*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function updateOracle(address _oracle) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_oracle`|`address`|New oracle address|


### updateHedgerPool

Updates the HedgerPool address

*Updates the HedgerPool contract address for collateralization checks*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to GOVERNANCE_ROLE

- No oracle dependencies


```solidity
function updateHedgerPool(address _hedgerPool) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_hedgerPool`|`address`|New HedgerPool address|


### updateUserPool

Updates the UserPool address

*Updates the UserPool contract address for user deposit tracking*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to GOVERNANCE_ROLE

- No oracle dependencies


```solidity
function updateUserPool(address _userPool) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_userPool`|`address`|New UserPool address|


### updateFeeCollector

Updates the fee collector address

*Only governance role can update the fee collector address*

**Notes:**
- Validates address is not zero before updating

- Ensures _feeCollector is not address(0)

- Updates feeCollector state variable

- Emits ParametersUpdated event

- Reverts if _feeCollector is address(0)

- No reentrancy risk, simple state update

- Restricted to GOVERNANCE_ROLE

- No oracle dependencies


```solidity
function updateFeeCollector(address _feeCollector) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_feeCollector`|`address`|New fee collector address|


### updatePriceProtectionParams

Updates price deviation protection parameters

*Only governance can update these security parameters*

*Note: This function requires converting constants to state variables
for full implementation. Currently a placeholder for future governance control.*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to GOVERNANCE_ROLE

- No oracle dependencies


```solidity
function updatePriceProtectionParams(uint256 _maxPriceDeviation, uint256 _minBlocksBetweenUpdates)
    external
    onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_maxPriceDeviation`|`uint256`|New maximum price deviation in basis points|
|`_minBlocksBetweenUpdates`|`uint256`|New minimum blocks between updates|


### withdrawProtocolFees

Withdraws accumulated protocol fees

*Fees accumulate during minting and redemptions*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function withdrawProtocolFees(address to) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Destination address for the fees|


### addHedgerDeposit

Adds hedger USDC deposit to vault's total USDC reserves

*Called by HedgerPool when hedgers open positions to unify USDC liquidity*

**Notes:**
- Validates caller is HedgerPool contract and amount is positive

- Validates amount > 0 and caller is authorized HedgerPool

- Updates totalUsdcHeld with hedger deposit amount

- Emits HedgerDepositAdded with deposit details

- Throws "Vault: Only HedgerPool can call" if caller is not HedgerPool

- Throws "Vault: Amount must be positive" if amount is zero

- Protected by nonReentrant modifier

- Restricted to HedgerPool contract only

- No oracle dependencies


```solidity
function addHedgerDeposit(uint256 usdcAmount) external nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC deposited by hedger (6 decimals)|


### withdrawHedgerDeposit

Withdraws hedger USDC deposit from vault's reserves

*Called by HedgerPool when hedgers close positions to return their deposits*

**Notes:**
- Validates caller is HedgerPool, amount is positive, and sufficient reserves

- Validates amount > 0, caller is authorized, and totalUsdcHeld >= amount

- Updates totalUsdcHeld and transfers USDC to hedger

- Emits HedgerDepositWithdrawn with withdrawal details

- Throws "Vault: Only HedgerPool can call" if caller is not HedgerPool

- Throws "Vault: Amount must be positive" if amount is zero

- Throws "Vault: Insufficient USDC reserves" if not enough USDC available

- Protected by nonReentrant modifier

- Restricted to HedgerPool contract only

- No oracle dependencies


```solidity
function withdrawHedgerDeposit(address hedger, uint256 usdcAmount) external nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hedger`|`address`|Address of the hedger receiving the USDC|
|`usdcAmount`|`uint256`|Amount of USDC to withdraw (6 decimals)|


### getTotalUsdcAvailable

Gets the total USDC available for hedger deposits

*Returns the current total USDC held in the vault for transparency*

**Notes:**
- No security validations required - view function

- No input validation required - view function

- No state changes - view function only

- No events emitted

- No errors thrown

- Not applicable - view function

- Public access - anyone can query total USDC held

- No oracle dependencies


```solidity
function getTotalUsdcAvailable() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Total USDC held in vault (6 decimals)|


### _updatePriceTimestamp

Updates the last valid price timestamp when a valid price is fetched

*Internal function to track price update timing for monitoring*

**Notes:**
- Updates timestamp only for valid price fetches

- No input validation required

- Updates lastPriceUpdateTime if price is valid

- No events emitted

- No errors thrown

- Not protected - internal function only

- Internal function - no access restrictions

- No oracle dependencies


```solidity
function _updatePriceTimestamp(bool isValid) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`isValid`|`bool`|Whether the current price fetch was valid|


### getProtocolCollateralizationRatio

Calculates the current protocol collateralization ratio

*Formula: ((A + B) / A) * 100 where A = user deposits, B = hedger effective collateral (deposits + P&L)*

*Returns ratio in basis points (e.g., 10500 = 105%)*

*Uses hedger effective collateral instead of raw deposits to account for P&L*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- No state changes - view function

- No events emitted - view function

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can check collateralization ratio

- Requires fresh oracle price data (via HedgerPool)


```solidity
function getProtocolCollateralizationRatio() public returns (uint256 ratio);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ratio`|`uint256`|Current collateralization ratio in basis points|


### canMint

Checks if minting is allowed based on current collateralization ratio

*Returns true if collateralization ratio >= minCollateralizationRatioForMinting*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- No state changes - view function

- No events emitted - view function

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can check minting status

- No oracle dependencies


```solidity
function canMint() public returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|canMint Whether minting is currently allowed|


### shouldTriggerLiquidation

Checks if liquidation should be triggered based on current collateralization ratio

*Returns true if collateralization ratio < criticalCollateralizationRatio*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- No state changes - view function

- No events emitted - view function

- No errors thrown - safe view function

- Not applicable - view function

- Public - anyone can check liquidation status

- No oracle dependencies


```solidity
function shouldTriggerLiquidation() public returns (bool shouldLiquidate);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shouldLiquidate`|`bool`|Whether liquidation should be triggered|


### getPriceProtectionStatus

Returns the current price protection status

*Useful for monitoring and debugging price protection*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


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

*When paused:
- No mint/redeem possible
- Read functions still active*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function pause() external onlyRole(EMERGENCY_ROLE);
```

### unpause

Unpauses and resumes operations

*Resumes all vault operations after emergency pause*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function unpause() external onlyRole(EMERGENCY_ROLE);
```

### recoverToken

Recovers tokens accidentally sent to the vault to treasury only

*Protections:
- Cannot recover own vault tokens
- Tokens are sent to treasury address only
- Only third-party tokens can be recovered*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to DEFAULT_ADMIN_ROLE

- No oracle dependencies


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

*SECURITY: Restricted to treasury to prevent arbitrary ETH transfers*

*Security considerations:
- Only DEFAULT_ADMIN_ROLE can recover
- Prevents sending to zero address
- Validates balance before attempting transfer
- Uses call() for reliable ETH transfers to any contract*

**Notes:**
- Validates input parameters and enforces security checks

- Validates input parameters and business logic constraints

- Updates contract state variables

- Emits relevant events for state changes

- Throws custom errors for invalid conditions

- Protected by reentrancy guard

- Restricted to authorized roles

- Requires fresh oracle price data


```solidity
function recoverETH() external onlyRole(DEFAULT_ADMIN_ROLE);
```

### _syncMintWithHedgers

Internal helper to notify HedgerPool about user mints

*Attempts to update hedger fills but swallows failures to avoid blocking users*

**Notes:**
- Internal helper; relies on HedgerPool access control

- No additional validation beyond non-zero guard

- None inside the vault; delegates to HedgerPool

- None

- Silently ignores downstream errors

- Not applicable

- Internal helper

- Not applicable


```solidity
function _syncMintWithHedgers(uint256 amount, uint256 fillPrice) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Net USDC amount minted into QEURO (6 decimals)|
|`fillPrice`|`uint256`|EUR/USD oracle price used for the mint (18 decimals)|


### _syncRedeemWithHedgers

Internal helper to notify HedgerPool about user redeems

*Attempts to release hedger fills but swallows failures to avoid blocking users*

**Notes:**
- Internal helper; relies on HedgerPool access control

- No additional validation beyond non-zero guard

- None inside the vault; delegates to HedgerPool

- None

- Silently ignores downstream errors

- Not applicable

- Internal helper

- Not applicable


```solidity
function _syncRedeemWithHedgers(uint256 amount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Gross USDC returned to the user (6 decimals)|


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

*OPTIMIZED: Indexed parameter type for efficient filtering*


```solidity
event ParametersUpdated(string indexed parameterType, uint256 mintFee, uint256 redemptionFee);
```

### CollateralizationThresholdsUpdated
Emitted when price deviation protection is triggered

Emitted when collateralization thresholds are updated by governance

*Helps monitor potential flash loan attacks*


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
|`minCollateralizationRatioForMinting`|`uint256`|New minimum collateralization ratio for minting (in basis points)|
|`criticalCollateralizationRatio`|`uint256`|New critical collateralization ratio for liquidation (in basis points)|
|`caller`|`address`|Address of the governance role holder who updated the thresholds|

### CollateralizationStatusChanged
Emitted when protocol collateralization status changes


```solidity
event CollateralizationStatusChanged(uint256 indexed currentRatio, bool indexed canMint, bool indexed shouldLiquidate);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currentRatio`|`uint256`|Current protocol collateralization ratio (in basis points)|
|`canMint`|`bool`|Whether minting is currently allowed based on collateralization|
|`shouldLiquidate`|`bool`|Whether liquidation should be triggered based on collateralization|

### PriceDeviationDetected

```solidity
event PriceDeviationDetected(uint256 currentPrice, uint256 lastValidPrice, uint256 deviationBps, uint256 blockNumber);
```

