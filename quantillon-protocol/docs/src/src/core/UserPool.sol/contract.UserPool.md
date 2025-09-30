# UserPool
[Git Source](https://github.com/Quantillon-Labs/smart-contracts/quantillon-protocol/blob/d4ff9dd61a04d59de40a8b136ac832356918d46a/src/core/UserPool.sol)

**Inherits:**
Initializable, ReentrancyGuardUpgradeable, AccessControlUpgradeable, PausableUpgradeable, [SecureUpgradeable](/src/core/SecureUpgradeable.sol/abstract.SecureUpgradeable.md)

**Author:**
Quantillon Labs - Nicolas Bellengé - @chewbaccoin

Manages QEURO user deposits, staking, and yield distribution

*Main characteristics:
- User deposit and withdrawal management
- QEURO staking mechanism with rewards
- Yield distribution system
- Fee structure for protocol sustainability
- Emergency pause mechanism for crisis situations
- Upgradeable via UUPS pattern*

*Deposit mechanics:
- Users deposit USDC to receive QEURO
- QEURO is minted based on current EUR/USD exchange rate
- Deposit fees charged for protocol revenue
- Deposits are tracked per user for analytics*

*Staking mechanics:
- Users can stake their QEURO for additional rewards
- Staking APY provides yield on staked QEURO
- Unstaking has a cooldown period to prevent abuse
- Rewards are distributed based on staking duration and amount*

*Withdrawal mechanics:
- Users can withdraw their QEURO back to USDC
- Withdrawal fees charged for protocol revenue
- Withdrawals are processed based on current EUR/USD rate
- Staked QEURO must be unstaked before withdrawal*

*Yield distribution:
- Yield is distributed to stakers based on their stake amount
- Performance fees charged on yield distributions
- Yield sources include protocol fees and yield shift mechanisms
- Real-time yield tracking and distribution*

*Fee structure:
- Deposit fees for creating QEURO from USDC
- Withdrawal fees for converting QEURO back to USDC
- Performance fees on yield distributions
- Dynamic fee adjustment based on market conditions*

*Security features:
- Role-based access control for all critical operations
- Reentrancy protection for all external calls
- Emergency pause mechanism for crisis situations
- Upgradeable architecture for future improvements
- Secure deposit and withdrawal management
- Staking cooldown mechanisms
- Batch size limits to prevent DoS attacks
- Gas optimization through storage read caching*

*Integration points:
- QEURO token for minting and burning
- USDC for deposits and withdrawals
- QuantillonVault for QEURO minting/burning
- Yield shift mechanism for yield management
- Vault math library for calculations*

**Note:**
security-contact: team@quantillon.money


## State Variables
### GOVERNANCE_ROLE
Role for governance operations (parameter updates, emergency actions)

*keccak256 hash avoids role collisions with other contracts*

*Should be assigned to governance multisig or DAO*


```solidity
bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
```


### EMERGENCY_ROLE
Role for emergency operations (pause, emergency withdrawals)

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
USDC token contract for deposits and withdrawals

*Used for all USDC deposits and withdrawals*

*Should be the official USDC contract on the target network*


```solidity
IERC20 public usdc;
```


### vault
Main Quantillon vault for QEURO operations

*Used for QEURO minting and burning operations*

*Should be the official QuantillonVault contract*


```solidity
IQuantillonVault public vault;
```


### oracle
Chainlink Oracle for EUR/USD price feeds

*Used for converting QEURO supply to USDC equivalent in analytics*


```solidity
IChainlinkOracle public oracle;
```


### yieldShift
Yield shift mechanism for yield management

*Handles yield distribution and management*

*Used for yield calculations and distributions*


```solidity
IYieldShift public yieldShift;
```


### treasury
Treasury address for ETH recovery

*SECURITY: Only this address can receive ETH from recoverETH function*


```solidity
address public treasury;
```


### TIME_PROVIDER
TimeProvider contract for centralized time management

*Used to replace direct block.timestamp usage for testability and consistency*


```solidity
TimeProvider public immutable TIME_PROVIDER;
```


### stakingAPY
Staking APY in basis points

*Example: 500 = 5% staking APY*

*Used for calculating staking rewards*


```solidity
uint256 public stakingAPY;
```


### depositAPY
Base deposit APY in basis points

*Example: 200 = 2% base deposit APY*

*Used for calculating deposit rewards*


```solidity
uint256 public depositAPY;
```


### minStakeAmount
Minimum amount required for staking (in QEURO)

*Example: 100 * 1e18 = 100 QEURO minimum stake*

*Prevents dust staking and reduces gas costs*


```solidity
uint256 public minStakeAmount;
```


### unstakingCooldown
Cooldown period for unstaking (in seconds)

*Example: 7 days = 604,800 seconds*

*Prevents rapid staking/unstaking cycles*


```solidity
uint256 public unstakingCooldown;
```


### depositFee
Fee charged on deposits (in basis points)

*Example: 10 = 0.1% deposit fee*

*Revenue source for the protocol*


```solidity
uint256 public depositFee;
```


### withdrawalFee
Fee charged on withdrawals (in basis points)

*Example: 10 = 0.1% withdrawal fee*

*Revenue source for the protocol*


```solidity
uint256 public withdrawalFee;
```


### performanceFee
Fee charged on yield distributions (in basis points)

*Example: 200 = 2% performance fee*

*Revenue source for the protocol*


```solidity
uint256 public performanceFee;
```


### totalStakes
Total QEURO staked across all users

*Sum of all staked QEURO amounts*

*Used for yield distribution calculations*


```solidity
uint256 public totalStakes;
```


### totalUsers
Number of unique users who have deposited

*Count of unique addresses that have made deposits*

*Used for protocol analytics and governance*


```solidity
uint256 public totalUsers;
```


### userInfo
User information by address

*Maps user addresses to their detailed information*

*Used to track user deposits, stakes, and rewards*


```solidity
mapping(address => UserInfo) public userInfo;
```


### hasDeposited
Whether a user has ever deposited

*Maps user addresses to their deposit status*

*Used to track unique users and prevent double counting*


```solidity
mapping(address => bool) public hasDeposited;
```


### accumulatedYieldPerShare
Accumulated yield per staked QEURO share

*Used for calculating user rewards based on their stake amount*

*Increases over time as yield is distributed*


```solidity
uint256 public accumulatedYieldPerShare;
```


### lastYieldDistribution
Timestamp of last yield distribution

*Used to track when yield was last distributed*

*Used for yield calculation intervals*


```solidity
uint256 public lastYieldDistribution;
```


### totalYieldDistributed
Total yield distributed to users

*Sum of all yield distributed to users*

*Used for protocol analytics and governance*


```solidity
uint256 public totalYieldDistributed;
```


### totalUserDeposits
Total USDC deposits across all users (in USDC decimals - 6)

*Tracks the sum of all USDC deposits made by users*

*Used for protocol analytics and collateralization calculations*


```solidity
uint256 public totalUserDeposits;
```


### totalUserWithdrawals
Total QEURO withdrawals across all users (in QEURO decimals - 18)

*Tracks the sum of all QEURO withdrawals made by users*

*Used for protocol analytics and supply tracking*


```solidity
uint256 public totalUserWithdrawals;
```


### userDeposits
User deposit tracking with oracle ratios

*Maps user addresses to their deposit history with oracle ratios*

*Used for detailed analytics and audit trails*


```solidity
mapping(address => UserDepositInfo[]) public userDeposits;
```


### userWithdrawals
User withdrawal tracking with oracle ratios

*Maps user addresses to their withdrawal history with oracle ratios*

*Used for detailed analytics and audit trails*


```solidity
mapping(address => UserWithdrawalInfo[]) public userWithdrawals;
```


### userLastRewardBlock

```solidity
mapping(address => uint256) public userLastRewardBlock;
```


### BLOCKS_PER_DAY

```solidity
uint256 public constant BLOCKS_PER_DAY = 7200;
```


### MAX_REWARD_PERIOD

```solidity
uint256 public constant MAX_REWARD_PERIOD = 365 days;
```


### MAX_BATCH_SIZE
Maximum batch size for deposit operations to prevent DoS

*Prevents out-of-gas attacks through large arrays*


```solidity
uint256 public constant MAX_BATCH_SIZE = 100;
```


### MAX_REWARD_BATCH_SIZE
Maximum batch size for reward claim operations to prevent DoS

*Prevents out-of-gas attacks through large user arrays*


```solidity
uint256 public constant MAX_REWARD_BATCH_SIZE = 50;
```


## Functions
### flashLoanProtection

Modifier to protect against flash loan attacks

*Uses the FlashLoanProtectionLibrary to check USDC balance consistency*


```solidity
modifier flashLoanProtection();
```

### constructor

Constructor for UserPool contract

*Sets up the time provider and disables initializers for security*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Disables initializers

- events: No events emitted

- errors: Throws custom errors for invalid conditions

- reentrancy: No reentrancy protection needed

- access: No access restrictions

- oracle: No oracle dependencies


```solidity
constructor(TimeProvider _TIME_PROVIDER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_TIME_PROVIDER`|`TimeProvider`|TimeProvider contract for centralized time management|


### initialize

Initializes the UserPool contract

*Initializes the UserPool with all required contracts and default parameters*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Initializes all contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to initializer modifier

- oracle: Requires oracle for analytics functions


```solidity
function initialize(
    address admin,
    address _qeuro,
    address _usdc,
    address _vault,
    address _oracle,
    address _yieldShift,
    address _timelock,
    address _treasury
) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address that receives admin and governance roles|
|`_qeuro`|`address`|Address of the QEURO token contract|
|`_usdc`|`address`|Address of the USDC token contract|
|`_vault`|`address`|Address of the QuantillonVault contract|
|`_oracle`|`address`|Address of the Chainlink Oracle contract|
|`_yieldShift`|`address`|Address of the YieldShift contract|
|`_timelock`|`address`|Address of the timelock contract|
|`_treasury`|`address`|Address of the treasury contract|


### deposit

Deposit USDC to mint QEURO (unified single/batch function)

*Handles both single deposits and batch deposits in one function*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by nonReentrant modifier

- access: Public access

- oracle: No oracle dependencies


```solidity
function deposit(uint256[] calldata usdcAmounts, uint256[] calldata minQeuroOuts)
    external
    nonReentrant
    whenNotPaused
    flashLoanProtection
    returns (uint256[] memory qeuroMintedAmounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmounts`|`uint256[]`|Array of USDC amounts to deposit (6 decimals) - use [amount] for single|
|`minQeuroOuts`|`uint256[]`|Array of minimum QEURO amounts to receive (18 decimals) - use [amount] for single|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`qeuroMintedAmounts`|`uint256[]`|Array of QEURO amounts minted (18 decimals)|


### _validateAndTransferTokens

Internal function to validate amounts and transfer tokens (unified validation)

*Unified validation and transfer function to reduce code duplication*

**Notes:**
- security: Validates all amounts > 0 before transfer

- validation: Validates each amount in array is positive

- state-changes: Transfers tokens from/to msg.sender

- events: No events emitted - handled by calling function

- errors: Throws if any amount is 0

- reentrancy: Not protected - internal function only

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function _validateAndTransferTokens(uint256[] calldata amounts, IERC20 token, bool isFromUser)
    internal
    returns (uint256 totalAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amounts`|`uint256[]`|Array of amounts to validate and transfer|
|`token`|`IERC20`|Token to transfer (usdc or qeuro)|
|`isFromUser`|`bool`|Whether to transfer from user (true) or to user (false)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalAmount`|`uint256`|Total amount transferred|


### _initializeUserIfNeeded

Internal function to initialize user if needed (consolidated)

*Initializes user tracking if they haven't deposited before*

**Notes:**
- security: Updates hasDeposited mapping and totalUsers counter

- validation: No input validation required

- state-changes: Updates hasDeposited[msg.sender] and totalUsers

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not protected - internal function only

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function _initializeUserIfNeeded() internal;
```

### _calculateNetAmounts

Internal function to calculate net amounts after fees

*Calculates net amounts by subtracting deposit fees from each USDC amount*

**Notes:**
- security: Uses cached depositFee to prevent reentrancy

- validation: No input validation required - view function

- state-changes: No state changes - view function only

- events: No events emitted

- errors: No errors thrown

- reentrancy: Not applicable - view function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function _calculateNetAmounts(uint256[] calldata usdcAmounts)
    internal
    view
    returns (uint256[] memory netAmounts, uint256 totalNetAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmounts`|`uint256[]`|Array of USDC amounts (6 decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`netAmounts`|`uint256[]`|Array of net amounts after fees (6 decimals)|
|`totalNetAmount`|`uint256`|Total net amount (6 decimals)|


### _processVaultMinting

Internal function to process vault minting operations

*Processes vault minting operations with single vault call to avoid external calls in loop*

**Notes:**
- security: Uses single approval and single vault call to minimize external calls

- validation: No input validation required - parameters pre-validated

- state-changes: Updates qeuroMintedAmounts array with minted amounts

- events: No events emitted - handled by calling function

- errors: Throws if vault.mintQEURO fails

- reentrancy: Protected by nonReentrant modifier on calling function

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function _processVaultMinting(
    uint256[] memory netAmounts,
    uint256[] calldata minQeuroOuts,
    uint256[] memory qeuroMintedAmounts
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`netAmounts`|`uint256[]`|Array of net amounts to mint (6 decimals)|
|`minQeuroOuts`|`uint256[]`|Array of minimum QEURO outputs (18 decimals)|
|`qeuroMintedAmounts`|`uint256[]`|Array to store minted amounts (18 decimals)|


### _updateUserAndPoolState

Internal function to update user and pool state

*Updates user and pool state before external calls for reentrancy protection*

**Notes:**
- security: Updates state before external calls (CEI pattern)

- validation: No input validation required - parameters pre-validated

- state-changes: Updates user.depositHistory, totalDeposits

- events: No events emitted - handled by calling function

- errors: No errors thrown

- reentrancy: Not protected - internal function only

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function _updateUserAndPoolState(uint256[] calldata usdcAmounts, uint256[] calldata minQeuroOuts, uint256) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmounts`|`uint256[]`|Array of USDC amounts (6 decimals)|
|`minQeuroOuts`|`uint256[]`|Array of minimum QEURO outputs (18 decimals)|
|`<none>`|`uint256`||


### _transferQeuroAndEmitEvents

Internal function to transfer QEURO and emit events

*Transfers QEURO to users and emits UserDeposit events*

**Notes:**
- security: Uses SafeERC20 for secure token transfers

- validation: No input validation required - parameters pre-validated

- state-changes: Transfers QEURO tokens to msg.sender

- events: Emits UserDeposit event for each transfer

- errors: Throws if QEURO transfer fails

- reentrancy: Not protected - internal function only

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function _transferQeuroAndEmitEvents(
    uint256[] calldata usdcAmounts,
    uint256[] memory qeuroMintedAmounts,
    uint256 currentTime
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`usdcAmounts`|`uint256[]`|Array of USDC amounts (6 decimals)|
|`qeuroMintedAmounts`|`uint256[]`|Array of minted QEURO amounts (18 decimals)|
|`currentTime`|`uint256`|Current timestamp|


### withdraw

Withdraw USDC by burning QEURO (unified single/batch function)

*Handles both single withdrawals and batch withdrawals in one function*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by nonReentrant modifier

- access: Public access

- oracle: No oracle dependencies


```solidity
function withdraw(uint256[] calldata qeuroAmounts, uint256[] calldata minUsdcOuts)
    external
    nonReentrant
    whenNotPaused
    returns (uint256[] memory usdcReceivedAmounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmounts`|`uint256[]`|Array of QEURO amounts to burn (18 decimals) - use [amount] for single|
|`minUsdcOuts`|`uint256[]`|Array of minimum USDC amounts to receive (6 decimals) - use [amount] for single|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`usdcReceivedAmounts`|`uint256[]`|Array of USDC amounts received (6 decimals)|


### _validateAndProcessBatchWithdrawal

Validates and processes batch withdrawal

*Internal helper to reduce stack depth*

**Notes:**
- security: Validates amounts and user balances to prevent over-withdrawal

- validation: Validates all amounts are positive and user has sufficient balance

- state-changes: Updates user balance and processes withdrawal calculations

- events: No events emitted - internal helper function

- errors: Throws "Amount must be positive" if any amount is zero

- reentrancy: Not protected - internal function only

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function _validateAndProcessBatchWithdrawal(
    uint256[] calldata qeuroAmounts,
    uint256[] calldata minUsdcOuts,
    uint256[] memory usdcReceivedAmounts
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmounts`|`uint256[]`|Array of QEURO amounts to withdraw|
|`minUsdcOuts`|`uint256[]`|Array of minimum USDC amounts expected|
|`usdcReceivedAmounts`|`uint256[]`|Array to store received USDC amounts|


### _processVaultRedemptions

Processes vault redemptions for batch withdrawal

*Internal helper to reduce stack depth*

*OPTIMIZATION: Uses single vault call with total amounts to avoid external calls in loop*

**Notes:**
- security: Validates vault redemption amounts and minimum outputs

- validation: Validates all amounts are positive and within limits

- state-changes: Processes vault redemptions and updates received amounts

- events: No events emitted - internal helper function

- errors: Throws validation errors if amounts are invalid

- reentrancy: Not protected - internal function only

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function _processVaultRedemptions(
    uint256[] calldata qeuroAmounts,
    uint256[] calldata minUsdcOuts,
    uint256[] memory usdcReceivedAmounts,
    uint256 withdrawalFee_
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmounts`|`uint256[]`|Array of QEURO amounts to redeem|
|`minUsdcOuts`|`uint256[]`|Array of minimum USDC amounts expected|
|`usdcReceivedAmounts`|`uint256[]`|Array to store received USDC amounts|
|`withdrawalFee_`|`uint256`|Cached withdrawal fee percentage|


### _executeBatchTransfers

Executes final transfers and emits events for batch withdrawal

*Internal helper to reduce stack depth*

**Notes:**
- security: Executes final token transfers and emits withdrawal events

- validation: Validates all amounts are positive before transfer

- state-changes: Burns QEURO tokens and transfers USDC to user

- events: Emits Withdrawal event for each withdrawal

- errors: Throws transfer errors if token operations fail

- reentrancy: Not protected - internal function only

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function _executeBatchTransfers(
    uint256[] calldata qeuroAmounts,
    uint256[] memory usdcReceivedAmounts,
    uint256 currentTime
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmounts`|`uint256[]`|Array of QEURO amounts withdrawn|
|`usdcReceivedAmounts`|`uint256[]`|Array of USDC amounts received|
|`currentTime`|`uint256`|Current timestamp for events|


### stake

Stakes QEURO tokens (unified single/batch function)

*Handles both single stakes and batch stakes in one function*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by nonReentrant modifier

- access: Public access

- oracle: No oracle dependencies


```solidity
function stake(uint256[] calldata qeuroAmounts) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmounts`|`uint256[]`|Array of QEURO amounts to stake (18 decimals) - use [amount] for single|


### requestUnstake

Requests to unstake QEURO tokens (starts unstaking cooldown period)

*Begins the unstaking process with a cooldown period before tokens can be withdrawn*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by nonReentrant modifier

- access: Public access

- oracle: No oracle dependencies


```solidity
function requestUnstake(uint256 qeuroAmount) external nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|The amount of staked QEURO tokens to unstake (18 decimals)|


### unstake

Complete unstaking after cooldown period

*This function allows users to complete their unstaking request
after the cooldown period has passed.*

**Notes:**
- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by nonReentrant modifier

- access: Public access

- oracle: No oracle dependencies


```solidity
function unstake() external nonReentrant whenNotPaused;
```

### claimStakingRewards

Claim staking rewards

*This function allows users to claim their pending staking rewards.
It calculates and transfers the rewards based on their staked amount.*

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
function claimStakingRewards() external nonReentrant returns (uint256 rewardAmount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rewardAmount`|`uint256`|Amount of QEURO rewards claimed (18 decimals)|


### batchRewardClaim

Batch claim staking rewards for multiple users (admin function)

*This function allows admins to claim rewards for multiple users in one transaction.
Useful for protocol-wide reward distributions or automated reward processing.*

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
function batchRewardClaim(address[] calldata users)
    external
    nonReentrant
    onlyRole(GOVERNANCE_ROLE)
    returns (uint256[] memory rewardAmounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`users`|`address[]`|Array of user addresses to claim rewards for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rewardAmounts`|`uint256[]`|Array of reward amounts claimed for each user (18 decimals)|


### distributeYield

Distribute yield to stakers (called by YieldShift contract)

*This function is deprecated - yield now goes to stQEURO*

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
function distributeYield(uint256 yieldAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`yieldAmount`|`uint256`|Amount of yield to distribute (18 decimals)|


### _updatePendingRewards

Update pending rewards for a user

*This internal function calculates and updates the pending rewards
for a given user based on their staked amount and the current APY.
Uses block-based calculations to prevent timestamp manipulation.*

**Notes:**
- security: Uses block-based calculations to prevent timestamp manipulation

- validation: Validates user has staked amount > 0

- state-changes: Updates user.pendingRewards, user.lastStakeTime, userLastRewardBlock

- events: No events emitted - handled by calling function

- errors: No errors thrown - safe arithmetic used

- reentrancy: Not protected - internal function only

- access: Internal function - no access restrictions

- oracle: No oracle dependencies


```solidity
function _updatePendingRewards(address user, uint256 currentTime) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user to update|
|`currentTime`|`uint256`|Current timestamp for reward calculations|


### getUserInfo

Get comprehensive user information (consolidated view function)

*Returns all user-related data in one call to reduce contract size*

**Notes:**
- security: No security implications (view function)

- validation: No validation required

- state-changes: No state changes (view function)

- events: No events (view function)

- errors: No custom errors

- reentrancy: No external calls, safe

- access: Public (anyone can call)

- oracle: No oracle dependencies


```solidity
function getUserInfo(address user)
    external
    view
    returns (
        uint256 qeuroBalance,
        uint256 stakedAmount,
        uint256 pendingRewards,
        uint256 depositHistory,
        uint256 lastStakeTime,
        uint256 unstakeAmount,
        uint256 unstakeRequestTime
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`qeuroBalance`|`uint256`|QEURO balance of the user (18 decimals)|
|`stakedAmount`|`uint256`|Current staked amount of the user (18 decimals)|
|`pendingRewards`|`uint256`|Total pending rewards of the user (18 decimals)|
|`depositHistory`|`uint256`|Total historical deposits of the user (6 decimals)|
|`lastStakeTime`|`uint256`|Timestamp of the user's last staking action|
|`unstakeAmount`|`uint256`|Amount being unstaked (18 decimals)|
|`unstakeRequestTime`|`uint256`|Timestamp when unstaking was requested|


### getPoolTotals

Get comprehensive pool totals (consolidated view function)

*Returns all pool totals in one call to reduce contract size*

**Notes:**
- security: No security implications (view function)

- validation: No validation required

- state-changes: No state changes (view function)

- events: No events (view function)

- errors: No custom errors

- reentrancy: No external calls, safe

- access: Public (anyone can call)

- oracle: No oracle dependencies


```solidity
function getPoolTotals()
    external
    view
    returns (uint256 totalDeposits, uint256 totalWithdrawals, uint256 totalStakes_, uint256 totalUsers_);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalDeposits`|`uint256`|Total USDC deposits (6 decimals)|
|`totalWithdrawals`|`uint256`|Total QEURO withdrawals (18 decimals)|
|`totalStakes_`|`uint256`|Total QEURO staked (18 decimals)|
|`totalUsers_`|`uint256`|Total number of users|


### getUserDepositHistory

Get user deposit history with oracle ratios

*Used for detailed analytics and audit trails*

*Returns complete deposit history with oracle ratios*

**Notes:**
- security: No security implications (view function)

- validation: No validation required

- state-changes: No state changes (view function)

- events: No events (view function)

- errors: No custom errors

- reentrancy: No external calls, safe

- access: Public (anyone can call)

- oracle: No oracle dependencies


```solidity
function getUserDepositHistory(address user) external view returns (UserDepositInfo[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`UserDepositInfo[]`|Array of UserDepositInfo structs containing deposit history|


### getUserWithdrawals

Get user withdrawal history with oracle ratios

*Used for detailed analytics and audit trails*

*Returns complete withdrawal history with oracle ratios*

**Notes:**
- security: No security implications (view function)

- validation: No validation required

- state-changes: No state changes (view function)

- events: No events (view function)

- errors: No custom errors

- reentrancy: No external calls, safe

- access: Public (anyone can call)

- oracle: No oracle dependencies


```solidity
function getUserWithdrawals(address user) external view returns (UserWithdrawalInfo[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`UserWithdrawalInfo[]`|Array of UserWithdrawalInfo structs containing withdrawal history|


### _getOracleRatioScaled

Get current oracle ratio scaled by 1e6 for storage efficiency

*Used internally for tracking oracle ratios in deposit/withdrawal records*

*Scaled to fit in uint32 for gas efficiency*

**Notes:**
- security: No security implications (view function)

- validation: No validation required

- state-changes: No state changes (view function)

- events: No events (view function)

- errors: No custom errors

- reentrancy: No external calls, safe

- access: Internal function

- oracle: Depends on oracle for current EUR/USD rate


```solidity
function _getOracleRatioScaled() internal returns (uint32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32`|Oracle ratio scaled by 1e6 (e.g., 1.08 becomes 1080000)|


### getTotalStakes

Get the total USDC equivalent withdrawals across all users

Get the total QEURO staked across all users

*Used for analytics and cash flow monitoring*

*Returns the total amount of QEURO currently staked in the pool*

**Notes:**
- access: Public access

- oracle: No oracle dependencies

- security: Validates input parameters and enforces security checks

- validation: Validates input parameters and business logic constraints

- state-changes: Updates contract state variables

- events: Emits relevant events for state changes

- errors: Throws custom errors for invalid conditions

- reentrancy: Protected by reentrancy guard

- access: Restricted to authorized roles

- oracle: Requires fresh oracle price data


```solidity
function getTotalStakes() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total withdrawals in USDC equivalent (6 decimals)|


### getPoolMetrics

Get various metrics about the user pool

*Returns comprehensive pool statistics including user count, averages, and ratios*

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
function getPoolMetrics()
    external
    view
    returns (uint256 totalUsers_, uint256 averageDeposit, uint256 stakingRatio, uint256 poolTVL);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalUsers_`|`uint256`|Number of unique users|
|`averageDeposit`|`uint256`|Average deposit amount per user (6 decimals)|
|`stakingRatio`|`uint256`|Ratio of total staked QEURO to total deposits (basis points)|
|`poolTVL`|`uint256`|Total value locked in the pool (6 decimals)|


### getPoolAnalytics

Get comprehensive pool analytics using QEURO total supply

*Uses QEURO total supply for accurate analytics instead of misleading USDC tracking*

**Notes:**
- security: No external calls except oracle, read-only function

- validation: Oracle price validation with fallback to zero

- state-changes: No state changes, view-like function

- events: No events emitted

- errors: No custom errors, handles oracle failures gracefully

- reentrancy: No reentrancy risk, read-only operations

- access: Public access

- oracle: Requires fresh oracle price data for USDC equivalent


```solidity
function getPoolAnalytics()
    external
    returns (uint256 currentQeuroSupply, uint256 usdcEquivalentAtCurrentRate, uint256 totalUsers_, uint256 totalStakes_);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`currentQeuroSupply`|`uint256`|Current QEURO total supply (net minted QEURO)|
|`usdcEquivalentAtCurrentRate`|`uint256`|Current USDC equivalent of QEURO supply|
|`totalUsers_`|`uint256`|Total number of users|
|`totalStakes_`|`uint256`|Total QEURO staked|


### getPoolConfiguration

Get comprehensive pool configuration (consolidated view function)

*Returns all pool configuration parameters in one call to reduce contract size*

**Notes:**
- security: No security implications (view function)

- validation: No validation required

- state-changes: No state changes (view function)

- events: No events (view function)

- errors: No custom errors

- reentrancy: No external calls, safe

- access: Public (anyone can call)

- oracle: No oracle dependencies


```solidity
function getPoolConfiguration()
    external
    view
    returns (
        uint256 stakingAPY_,
        uint256 depositAPY_,
        uint256 minStakeAmount_,
        uint256 unstakingCooldown_,
        uint256 depositFee_,
        uint256 withdrawalFee_,
        uint256 performanceFee_
    );
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`stakingAPY_`|`uint256`|Current staking APY in basis points|
|`depositAPY_`|`uint256`|Current deposit APY in basis points|
|`minStakeAmount_`|`uint256`|Current minimum stake amount (18 decimals)|
|`unstakingCooldown_`|`uint256`|Current unstaking cooldown period (seconds)|
|`depositFee_`|`uint256`|Current deposit fee (basis points)|
|`withdrawalFee_`|`uint256`|Current withdrawal fee (basis points)|
|`performanceFee_`|`uint256`|Current performance fee (basis points)|


### calculateProjectedRewards

Calculate projected rewards for a given QEURO amount and duration

*Calculates the expected rewards for staking a specific amount for a given duration*

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
function calculateProjectedRewards(uint256 qeuroAmount, uint256 duration) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`qeuroAmount`|`uint256`|Amount of QEURO to calculate rewards for (18 decimals)|
|`duration`|`uint256`|Duration in seconds|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 Calculated rewards (18 decimals)|


### updateStakingParameters

Update the parameters for staking (APY, min stake, cooldown)

*This function is restricted to governance roles.*

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
function updateStakingParameters(uint256 newStakingAPY, uint256 newMinStakeAmount, uint256 newUnstakingCooldown)
    external
    onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newStakingAPY`|`uint256`|New Staking APY in basis points|
|`newMinStakeAmount`|`uint256`|New Minimum stake amount (18 decimals)|
|`newUnstakingCooldown`|`uint256`|New unstaking cooldown period (seconds)|


### setPoolFees

Set the fees for deposits, withdrawals, and performance

*This function is restricted to governance roles.*

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
function setPoolFees(uint256 _depositFee, uint256 _withdrawalFee, uint256 _performanceFee)
    external
    onlyRole(GOVERNANCE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_depositFee`|`uint256`|New deposit fee in basis points|
|`_withdrawalFee`|`uint256`|New withdrawal fee in basis points|
|`_performanceFee`|`uint256`|New performance fee in basis points|


### emergencyUnstake

Emergency unstake for a specific user (restricted to emergency roles)

*This function is intended for emergency situations where a user's
staked QEURO needs to be forcibly unstaked.*

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
function emergencyUnstake(address user) external onlyRole(EMERGENCY_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user to unstake|


### pause

Pause the user pool (restricted to emergency roles)

*This function is used to pause critical operations in case of
a protocol-wide emergency or vulnerability.*

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

Unpause the user pool (restricted to emergency roles)

*This function is used to re-enable critical operations after
an emergency pause.*

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

### isPoolActive

Check if the user pool is currently active (not paused)

*Returns the current pause status of the pool*

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
function isPoolActive() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if the pool is active, false otherwise|


### recoverToken

Recover accidentally sent tokens to treasury only

*Recovers accidentally sent ERC20 tokens to the treasury address*

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
function recoverToken(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address to recover|
|`amount`|`uint256`|Amount to recover|


### recoverETH

Recover ETH to treasury address only

*SECURITY: Restricted to treasury to prevent arbitrary ETH transfers*

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

## Events
### UserDeposit
Emitted when a user deposits USDC and receives QEURO

*Indexed parameters allow efficient filtering of events*


```solidity
event UserDeposit(address indexed user, uint256 usdcAmount, uint256 qeuroMinted, uint256 timestamp);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user who deposited|
|`usdcAmount`|`uint256`|Amount of USDC deposited (6 decimals)|
|`qeuroMinted`|`uint256`|Amount of QEURO minted (18 decimals)|
|`timestamp`|`uint256`|Timestamp of the deposit|

### UserWithdrawal
Emitted when a user withdraws QEURO and receives USDC

*Indexed parameters allow efficient filtering of events*


```solidity
event UserWithdrawal(address indexed user, uint256 qeuroBurned, uint256 usdcReceived, uint256 timestamp);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user who withdrew|
|`qeuroBurned`|`uint256`|Amount of QEURO burned (18 decimals)|
|`usdcReceived`|`uint256`|Amount of USDC received (6 decimals)|
|`timestamp`|`uint256`|Timestamp of the withdrawal|

### UserDepositTracked
Emitted when a user deposit is tracked with oracle ratio


```solidity
event UserDepositTracked(
    address indexed user,
    uint256 usdcAmount,
    uint256 qeuroReceived,
    uint256 oracleRatio,
    uint256 timestamp,
    uint256 blockNumber
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user who deposited|
|`usdcAmount`|`uint256`|USDC amount deposited (6 decimals)|
|`qeuroReceived`|`uint256`|QEURO amount received (18 decimals)|
|`oracleRatio`|`uint256`|Oracle ratio at time of deposit (scaled by 1e6)|
|`timestamp`|`uint256`|Block timestamp when deposit was made|
|`blockNumber`|`uint256`|Block number when deposit was made|

### UserWithdrawalTracked
Emitted when a user withdrawal is tracked with oracle ratio


```solidity
event UserWithdrawalTracked(
    address indexed user,
    uint256 qeuroAmount,
    uint256 usdcReceived,
    uint256 oracleRatio,
    uint256 timestamp,
    uint256 blockNumber
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user who withdrew|
|`qeuroAmount`|`uint256`|QEURO amount withdrawn (18 decimals)|
|`usdcReceived`|`uint256`|USDC amount received (6 decimals)|
|`oracleRatio`|`uint256`|Oracle ratio at time of withdrawal (scaled by 1e6)|
|`timestamp`|`uint256`|Block timestamp when withdrawal was made|
|`blockNumber`|`uint256`|Block number when withdrawal was made|

### QEUROStaked
Emitted when a user stakes QEURO

*Indexed parameters allow efficient filtering of events*


```solidity
event QEUROStaked(address indexed user, uint256 qeuroAmount, uint256 timestamp);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user who staked|
|`qeuroAmount`|`uint256`|Amount of QEURO staked (18 decimals)|
|`timestamp`|`uint256`|Timestamp of the staking action|

### QEUROUnstaked
Emitted when a user unstakes QEURO

*Indexed parameters allow efficient filtering of events*


```solidity
event QEUROUnstaked(address indexed user, uint256 qeuroAmount, uint256 timestamp);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user who unstaked|
|`qeuroAmount`|`uint256`|Amount of QEURO unstaked (18 decimals)|
|`timestamp`|`uint256`|Timestamp of the unstaking action|

### StakingRewardsClaimed
Emitted when staking rewards are claimed by a user

*Indexed parameters allow efficient filtering of events*


```solidity
event StakingRewardsClaimed(address indexed user, uint256 rewardAmount, uint256 timestamp);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user who claimed rewards|
|`rewardAmount`|`uint256`|Amount of QEURO rewards claimed (18 decimals)|
|`timestamp`|`uint256`|Timestamp of the reward claim|

### YieldDistributed
Emitted when yield is distributed to stakers

*OPTIMIZED: Indexed timestamp for efficient time-based filtering*


```solidity
event YieldDistributed(uint256 totalYield, uint256 yieldPerShare, uint256 indexed timestamp);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`totalYield`|`uint256`|Total amount of yield distributed (18 decimals)|
|`yieldPerShare`|`uint256`|Amount of yield per staked QEURO share (18 decimals)|
|`timestamp`|`uint256`|Timestamp of the yield distribution|

### PoolParameterUpdated
Emitted when pool parameters are updated

*OPTIMIZED: Indexed parameter name for efficient filtering by parameter type*


```solidity
event PoolParameterUpdated(string indexed parameter, uint256 oldValue, uint256 newValue);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`parameter`|`string`|Name of the parameter updated|
|`oldValue`|`uint256`|Original value of the parameter|
|`newValue`|`uint256`|New value of the parameter|

### ETHRecovered
Emitted when ETH is recovered to the treasury


```solidity
event ETHRecovered(address indexed to, uint256 indexed amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Recipient address|
|`amount`|`uint256`|Amount of ETH recovered|

## Structs
### UserInfo
User information data structure

*Stores all information about a user's deposits, stakes, and rewards*

*Used for user management and reward calculations*

*OPTIMIZED: Timestamps and amounts packed for gas efficiency*


```solidity
struct UserInfo {
    uint128 qeuroBalance;
    uint128 stakedAmount;
    uint128 pendingRewards;
    uint128 unstakeAmount;
    uint96 depositHistory;
    uint64 lastStakeTime;
    uint64 unstakeRequestTime;
}
```

### UserDepositInfo
User deposit information with oracle ratio tracking

*Stores individual deposit records with oracle ratios for detailed analytics*

*Used for audit trails and historical analysis*


```solidity
struct UserDepositInfo {
    uint128 usdcAmount;
    uint128 qeuroReceived;
    uint64 timestamp;
    uint32 oracleRatio;
    uint32 blockNumber;
}
```

### UserWithdrawalInfo
User withdrawal information with oracle ratio tracking

*Stores individual withdrawal records with oracle ratios for detailed analytics*

*Used for audit trails and historical analysis*


```solidity
struct UserWithdrawalInfo {
    uint128 qeuroAmount;
    uint128 usdcReceived;
    uint64 timestamp;
    uint32 oracleRatio;
    uint32 blockNumber;
}
```

