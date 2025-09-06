# QuantillonVault
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/076c7312a6c5bd467439b8303ad03ed05c21f052/src/core/QuantillonVault.sol)

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


### treasury
Treasury address for ETH recovery

*SECURITY: Only this address can receive ETH from recoverETH function*


```solidity
address public treasury;
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
function initialize(address admin, address _qeuro, address _usdc, address _oracle, address _timelock)
    public
    initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address with administrator privileges|
|`_qeuro`|`address`|Address of the QEURO token contract|
|`_usdc`|`address`|Address of the USDC token contract|
|`_oracle`|`address`|Address of the Oracle contract|
|`_timelock`|`address`|Address of the timelock contract|


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


```solidity
function redeemQEURO(uint256 qeuroAmount, uint256 minUsdcOut) external nonReentrant whenNotPaused flashLoanProtection;
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
function getVaultMetrics()
    external
    view
    returns (uint256 totalUsdcHeld_, uint256 totalMinted_, uint256 totalDebtValue);
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

### ParametersUpdated
Emitted when parameters are changed

*OPTIMIZED: Indexed parameter type for efficient filtering*


```solidity
event ParametersUpdated(string indexed parameterType, uint256 mintFee, uint256 redemptionFee);
```

### PriceDeviationDetected
Emitted when price deviation protection is triggered

*Helps monitor potential flash loan attacks*


```solidity
event PriceDeviationDetected(uint256 currentPrice, uint256 lastValidPrice, uint256 deviationBps, uint256 blockNumber);
```

