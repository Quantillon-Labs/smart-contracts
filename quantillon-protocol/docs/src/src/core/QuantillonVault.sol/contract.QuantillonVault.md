# QuantillonVault
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/blob/fe414bc17d9f44041055fc158bb99f01c5c5476e/src/core/QuantillonVault.sol)

**Inherits:**
Initializable, ReentrancyGuardUpgradeable, AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable

**Author:**
Quantillon Labs

Main vault managing QEURO minting against USDC collateral

*Main characteristics:
- Overcollateralized stablecoin minting mechanism
- USDC as primary collateral for QEURO minting
- Real-time EUR/USD price oracle integration
- Automatic liquidation system for risk management
- Dynamic fee structure for protocol sustainability
- Emergency pause mechanism for crisis situations
- Upgradeable via UUPS pattern*

*Minting mechanics:
- Users deposit USDC as collateral
- QEURO is minted based on EUR/USD exchange rate
- Minimum collateralization ratio enforced (e.g., 101%)
- Minting fees charged for protocol revenue
- Collateral ratio monitored continuously*

*Redemption mechanics:
- Users can redeem QEURO back to USDC
- Redemption based on current EUR/USD exchange rate
- Protocol fees charged on redemptions
- Collateral returned to user after fee deduction*

*Risk management:
- Minimum collateralization ratio requirements
- Liquidation thresholds and penalties
- Real-time collateral ratio monitoring
- Automatic liquidation of undercollateralized positions
- Emergency pause capabilities*

*Fee structure:
- Minting fees for creating QEURO
- Redemption fees for converting QEURO back to USDC
- Liquidation penalties for risk management
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


### LIQUIDATOR_ROLE
Role for liquidating undercollateralized positions

*keccak256 hash avoids role collisions with other contracts*

*Should be assigned to trusted liquidators or automated systems*


```solidity
bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
```


### EMERGENCY_ROLE
Role for emergency operations (pause, emergency liquidations)

*keccak256 hash avoids role collisions with other contracts*

*Should be assigned to emergency multisig*


```solidity
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
```


### UPGRADER_ROLE
Role for performing contract upgrades via UUPS pattern

*keccak256 hash avoids role collisions with other contracts*

*Should be assigned to governance or upgrade multisig*


```solidity
bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
```


### qeuro
QEURO token contract for minting and burning

*Used for all QEURO minting and burning operations*

*Should be the official QEURO token contract*


```solidity
IQEURO public qeuro;
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

*Used for collateral ratio calculations and liquidation checks*


```solidity
IChainlinkOracle public oracle;
```


### minCollateralRatio
Minimum collateralization ratio required (in basis points)

*Example: 10100 = 101% minimum collateralization*

*Used to prevent excessive leverage and manage risk*


```solidity
uint256 public minCollateralRatio;
```


### liquidationThreshold
Liquidation threshold below which positions can be liquidated (in basis points)

*Example: 10000 = 100% liquidation threshold*

*Must be lower than minCollateralRatio to provide buffer*


```solidity
uint256 public liquidationThreshold;
```


### liquidationPenalty
Penalty charged during liquidations (in basis points)

*Example: 500 = 5% liquidation penalty*

*Incentivizes users to maintain adequate collateralization*


```solidity
uint256 public liquidationPenalty;
```


### protocolFee
Protocol fee charged on redemptions (in basis points)

*Example: 10 = 0.1% redemption fee*

*Revenue source for the protocol*


```solidity
uint256 public protocolFee;
```


### mintFee
Fee charged when minting QEURO (in basis points)

*Example: 10 = 0.1% minting fee*

*Revenue source for the protocol*


```solidity
uint256 public mintFee;
```


### totalCollateral
Total USDC held as collateral across all users

*Sum of all collateral deposits across all users*

*Used for vault analytics and risk management*


```solidity
uint256 public totalCollateral;
```


### totalMinted
Total QEURO in circulation (minted by this vault)


```solidity
uint256 public totalMinted;
```


### userCollateral
USDC collateral of each user


```solidity
mapping(address => uint256) public userCollateral;
```


### userDebt
QEURO debt of each user


```solidity
mapping(address => uint256) public userDebt;
```


### isLiquidated
Liquidation status per user


```solidity
mapping(address => bool) public isLiquidated;
```


### lastValidEurUsdPrice
Variable to store the last valid EUR/USD price (emergency state)


```solidity
uint256 private lastValidEurUsdPrice;
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
function initialize(address admin, address _qeuro, address _usdc, address _oracle) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address with administrator privileges|
|`_qeuro`|`address`|Address of the QEURO token contract|
|`_usdc`|`address`|Address of the USDC token contract|
|`_oracle`|`address`|Address of the Oracle contract|


### mintQEURO

Mints QEURO tokens by depositing USDC collateral

*Minting process:
1. Fetch EUR/USD price from oracle
2. Calculate amount of QEURO to mint
3. Verify minimum collateralization ratio
4. Transfer USDC from user
5. Update balances
6. Mint QEURO to user*

*Example: 1100 USDC → ~1000 QEURO (if EUR/USD = 1.10)
Collateralization ratio = 110% > 101% minimum ✓*


```solidity
function mintQEURO(uint256 usdcAmount, uint256 minQeuroOut) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC to deposit as collateral|
|`minQeuroOut`|`uint256`|Minimum amount of QEURO expected (slippage protection)|


### redeemQEURO

Redeems QEURO for USDC collateral

*Redeem process:
1. Verify the user has enough debt
2. Calculate USDC to return based on EUR/USD price
3. Apply protocol fees
4. Burn QEURO
5. Update balances
6. Transfer USDC to user*


```solidity
function redeemQEURO(uint256 qeuroAmount, uint256 minUsdcOut) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount of QEURO to burn|
|`minUsdcOut`|`uint256`|Minimum amount of USDC expected|


### addCollateral

Adds additional USDC collateral

*Used for:
- Improving the collateralization ratio
- Avoiding liquidation
- Preparing for a new mint*


```solidity
function addCollateral(uint256 amount) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of USDC to add|


### removeCollateral

Removes excess USDC collateral

*Safeguards:
- Maintain minimum ratio after withdrawal
- User not liquidated
- Sufficient collateral available*


```solidity
function removeCollateral(uint256 amount) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of USDC to remove|


### liquidate

Liquidates an undercollateralized position

*Liquidation process:
1. Verify that the position is liquidatable
2. Calculate collateral to seize (with bonus)
3. Burn QEURO from liquidator
4. Transfer collateral to liquidator
5. Update balances*

*Liquidator incentives:
- 5% bonus on seized collateral
- Protects the protocol against risky positions*


```solidity
function liquidate(address user, uint256 debtToCover) external onlyRole(LIQUIDATOR_ROLE) nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user to liquidate|
|`debtToCover`|`uint256`|Amount of debt to cover|


### isUserLiquidatable

Checks if a user can be liquidated


```solidity
function isUserLiquidatable(address user) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if liquidatable|


### getUserCollateralRatio

Calculates a user's collateralization ratio

*Formula: (USDC Collateral * 1e18) / (QEURO Debt * EUR/USD Price)*


```solidity
function getUserCollateralRatio(address user) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Ratio with 18 decimals (e.g., 1.5e18 = 150%)|


### getVaultHealth

Retrieves the vault's global health metrics


```solidity
function getVaultHealth()
    external
    view
    returns (uint256 totalCollateralValue, uint256 totalDebtValue, uint256 globalCollateralRatio);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalCollateralValue`|`uint256`|Total collateral value in USD|
|`totalDebtValue`|`uint256`|Total debt value in USD|
|`globalCollateralRatio`|`uint256`|Global collateralization ratio|


### getUserInfo

Retrieves detailed information for a user


```solidity
function getUserInfo(address user)
    external
    view
    returns (uint256 collateral, uint256 debt, uint256 collateralRatio, bool isLiquidatable, bool liquidated);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`collateral`|`uint256`|User's USDC collateral|
|`debt`|`uint256`|User's QEURO debt|
|`collateralRatio`|`uint256`|Current collateralization ratio|
|`isLiquidatable`|`bool`|true if can be liquidated|
|`liquidated`|`bool`|Liquidation status|


### calculateMintAmount

Calculates the amount of QEURO that can be minted for a given USDC amount


```solidity
function calculateMintAmount(uint256 usdcAmount) external view returns (uint256 qeuroAmount, uint256 collateralRatio);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmount`|`uint256`|Amount of USDC to deposit|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount of QEURO that will be minted|
|`collateralRatio`|`uint256`|Resulting collateralization ratio|


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
- Minimum ratio >= 100%
- Liquidation threshold <= minimum ratio
- Penalty <= 20% (liquidator protection)*


```solidity
function updateParameters(uint256 _minCollateralRatio, uint256 _liquidationThreshold, uint256 _liquidationPenalty)
    external
    onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_minCollateralRatio`|`uint256`|New minimum ratio (e.g., 105e16 = 105%)|
|`_liquidationThreshold`|`uint256`|New liquidation threshold|
|`_liquidationPenalty`|`uint256`|New liquidation penalty|


### updateProtocolFee

Updates the protocol fee


```solidity
function updateProtocolFee(uint256 _protocolFee) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_protocolFee`|`uint256`|New fee percentage (e.g., 2e15 = 0.2%)|


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

*Fees accumulate during redemptions
Only the excess over required collateral can be withdrawn*


```solidity
function withdrawProtocolFees(address to) external onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Destination address for the fees|


### _isLiquidatable

Checks if a user can be liquidated

*Liquidation conditions:
1. User has debt > 0
2. Oracle working (valid price)
3. Ratio < liquidation threshold (e.g., 100%)*


```solidity
function _isLiquidatable(address user) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if the collateralization ratio < liquidation threshold|


### _isValidCollateralRatio

Validates that a collateralization ratio is sufficient


```solidity
function _isValidCollateralRatio(address user, uint256 collateralAmount, uint256 debtAmount)
    internal
    view
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address (for future logs)|
|`collateralAmount`|`uint256`|USDC collateral amount|
|`debtAmount`|`uint256`|QEURO debt amount|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if the ratio >= required minimum|


### pause

Pauses all vault operations

*When paused:
- No mint/redeem possible
- No add/remove collateral
- Liquidations suspended
- Read functions still active*


```solidity
function pause() external onlyRole(EMERGENCY_ROLE);
```

### unpause

Unpauses and resumes operations


```solidity
function unpause() external onlyRole(EMERGENCY_ROLE);
```

### emergencyLiquidate

Emergency liquidation (bypasses normal checks)

*Only used in major crises
Allows liquidation even if the oracle is down*


```solidity
function emergencyLiquidate(address user, uint256 debtToCover) external onlyRole(EMERGENCY_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User to liquidate|
|`debtToCover`|`uint256`|Debt to cover|


### _authorizeUpgrade

Authorizes vault contract upgrades


```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|


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


```solidity
function recoverETH(address payable to) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address payable`|ETH recipient|


### getLiquidatableUsers

Retrieves the list of liquidatable users

*Gas-expensive function, use off-chain only*


```solidity
function getLiquidatableUsers(uint256 maxUsers)
    external
    view
    returns (address[] memory liquidatableUsers, uint256[] memory debtAmounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`maxUsers`|`uint256`|Maximum number of users to return|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`liquidatableUsers`|`address[]`|Addresses of liquidatable users|
|`debtAmounts`|`uint256[]`|Corresponding debts|


### simulateLiquidation

Simulates a liquidation and returns the amounts


```solidity
function simulateLiquidation(address user, uint256 debtToCover)
    external
    view
    returns (uint256 collateralToSeize, uint256 liquidatorProfit, bool isValidLiquidation);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User to simulate|
|`debtToCover`|`uint256`|Debt to cover|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`collateralToSeize`|`uint256`|Collateral that would be seized|
|`liquidatorProfit`|`uint256`|Profit for the liquidator|
|`isValidLiquidation`|`bool`|true if the liquidation is valid|


### getVaultParameters

Retrieves current vault parameters


```solidity
function getVaultParameters()
    external
    view
    returns (
        uint256 minCollateralRatio_,
        uint256 liquidationThreshold_,
        uint256 liquidationPenalty_,
        uint256 protocolFee_,
        address qeuroAddress,
        address usdcAddress,
        address oracleAddress
    );
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`minCollateralRatio_`|`uint256`|Minimum collateral ratio|
|`liquidationThreshold_`|`uint256`|Liquidation threshold|
|`liquidationPenalty_`|`uint256`|Liquidation penalty|
|`protocolFee_`|`uint256`|Protocol fee|
|`qeuroAddress`|`address`|QEURO token address|
|`usdcAddress`|`address`|USDC token address|
|`oracleAddress`|`address`|Oracle address|


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

### CollateralAdded
Emitted when collateral is added


```solidity
event CollateralAdded(address indexed user, uint256 amount);
```

### CollateralRemoved
Emitted when collateral is removed


```solidity
event CollateralRemoved(address indexed user, uint256 amount);
```

### UserLiquidated
Emitted when a liquidation occurs


```solidity
event UserLiquidated(
    address indexed user, address indexed liquidator, uint256 collateralLiquidated, uint256 debtCovered
);
```

### ParametersUpdated
Emitted when parameters are changed


```solidity
event ParametersUpdated(uint256 minCollateralRatio, uint256 liquidationThreshold, uint256 liquidationPenalty);
```

