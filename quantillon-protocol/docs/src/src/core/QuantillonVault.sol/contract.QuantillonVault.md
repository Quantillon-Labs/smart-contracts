# QuantillonVault
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/996f4133ba7998f0eb28738b06e228de221fcf63/src/core/QuantillonVault.sol)

**Inherits:**
Initializable, ReentrancyGuardUpgradeable, AccessControlUpgradeable, PausableUpgradeable, [SecureUpgradeable](/src/core/SecureUpgradeable.sol/abstract.SecureUpgradeable.md)

**Authors:**
Quantillon Labs, Quantillon Labs

Main vault managing QEURO minting against USDC collateral

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
- Simple 1:1 exchange with price conversion*

*Redemption mechanics:
- Users can redeem QEURO back to USDC
- Redemption based on current EUR/USD exchange rate
- Protocol fees charged on redemptions
- USDC returned to user after fee deduction*

*Risk management:
- Real-time price monitoring
- Emergency pause capabilities
- Slippage protection on swaps*

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
- Oracle price validation*

*Integration points:
- QEURO token for minting and burning
- USDC for collateral deposits and withdrawals
- Chainlink oracle for EUR/USD price feeds
- Vault math library for precise calculations*

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
- Simple 1:1 exchange with price conversion*

*Redemption mechanics:
- Users can redeem QEURO back to USDC
- Redemption based on current EUR/USD exchange rate
- Protocol fees charged on redemptions
- USDC returned to user after fee deduction*

*Risk management:
- Real-time price monitoring
- Emergency pause capabilities
- Slippage protection on swaps*

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
- Oracle price validation*

*Integration points:
- QEURO token for minting and burning
- USDC for collateral deposits and withdrawals
- Chainlink oracle for EUR/USD price feeds
- Vault math library for precise calculations*

**Notes:**
- team@quantillon.money

- team@quantillon.money


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
Variable to store the last valid EUR/USD price (emergency state)


```solidity
uint256 private lastValidEurUsdPrice;
```


### lastPriceUpdateTime
Variable to store the timestamp of the last valid price update


```solidity
uint256 private lastPriceUpdateTime;
```


## Functions
### constructor

**Note:**
constructor


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


```solidity
function initialize(address admin, address _qeuro, address _usdc, address _oracle, address timelock)
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
|`timelock`|`address`||


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


```solidity
function mintQEURO(uint256 usdcAmount, uint256 minQeuroOut) external nonReentrant whenNotPaused;
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


```solidity
function updateOracle(address _oracle) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_oracle`|`address`|New oracle address|


### withdrawProtocolFees

Withdraws accumulated protocol fees

*Fees accumulate during minting and redemptions*


```solidity
function withdrawProtocolFees(address to) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Destination address for the fees|


### _updatePriceTimestamp

Updates the last valid price timestamp when a valid price is fetched


```solidity
function _updatePriceTimestamp(bool isValid) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`isValid`|`bool`|Whether the current price fetch was valid|


### pause

Pauses all vault operations

*When paused:
- No mint/redeem possible
- Read functions still active*


```solidity
function pause() external onlyRole(EMERGENCY_ROLE);
```

### unpause

Unpauses and resumes operations


```solidity
function unpause() external onlyRole(EMERGENCY_ROLE);
```

### recoverToken

Recovers tokens accidentally sent to the vault

*Protections:
- Cannot recover USDC collateral
- Cannot recover QEURO
- Only third-party tokens can be recovered*


```solidity
function recoverToken(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token contract address|
|`to`|`address`|Recipient|
|`amount`|`uint256`|Amount to recover|


### recoverETH

Recovers ETH accidentally sent

*Security considerations:
- Only DEFAULT_ADMIN_ROLE can recover
- Prevents sending to zero address
- Validates balance before attempting transfer
- Uses call() for reliable ETH transfers to any contract*


```solidity
function recoverETH(address payable to) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address payable`|ETH recipient|


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


```solidity
event ParametersUpdated(uint256 mintFee, uint256 redemptionFee);
```

