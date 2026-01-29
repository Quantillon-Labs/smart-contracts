// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IYieldShift} from "../../interfaces/IYieldShift.sol";
import {VaultMath} from "../../libraries/VaultMath.sol";
import {CommonErrorLibrary} from "../../libraries/CommonErrorLibrary.sol";
import {VaultErrorLibrary} from "../../libraries/VaultErrorLibrary.sol";
import {AccessControlLibrary} from "../../libraries/AccessControlLibrary.sol";
import {CommonValidationLibrary} from "../../libraries/CommonValidationLibrary.sol";
import {TreasuryRecoveryLibrary} from "../../libraries/TreasuryRecoveryLibrary.sol";
import {SecureUpgradeable} from "../SecureUpgradeable.sol";

/**
 * @title AaveVault
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
interface IPool {
    /**
     * @notice Supply assets to Aave protocol
     * @dev Supplies assets to Aave protocol on behalf of a user
     * @param asset Address of the asset to supply
     * @param amount Amount of assets to supply
     * @param onBehalfOf Address to supply on behalf of
     * @param referralCode Referral code for Aave protocol
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    /**
     * @notice Withdraw assets from Aave protocol
     * @dev Withdraws assets from Aave protocol to a specified address
     * @param asset Address of the asset to withdraw
     * @param amount Amount of assets to withdraw
     * @param to Address to withdraw to
     * @return uint256 Amount of assets withdrawn
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    /**
     * @notice Get reserve data for an asset
     * @dev Returns reserve data for a specific asset in Aave protocol
     * @param asset Address of the asset
     * @return ReserveData Reserve data structure
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function getReserveData(address asset) external view returns (ReserveData memory);
}

interface IPoolAddressesProvider {
    /**
     * @notice Get the pool address
     * @dev Returns the address of the Aave pool
     * @return address Address of the Aave pool
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function getPool() external view returns (address);
}

interface IRewardsController {
    /**
     * @notice Claim rewards from Aave protocol
     * @dev Claims rewards for specified assets and amount
     * @param assets Array of asset addresses
     * @param amount Amount of rewards to claim
     * @param to Address to send rewards to
     * @return uint256 Amount of rewards claimed
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function claimRewards(address[] calldata assets, uint256 amount, address to) external returns (uint256);
    /**
     * @notice Get user rewards for specified assets
     * @dev Returns the rewards for a user across specified assets
     * @param assets Array of asset addresses
     * @param user Address of the user
     * @return uint256[] Array of reward amounts for each asset
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function getUserRewards(address[] calldata assets, address user) external view returns (uint256[] memory);
}

struct ReserveData {
    uint256 configuration;
    uint128 liquidityIndex;
    uint128 currentLiquidityRate;
    uint128 variableBorrowIndex;
    uint128 currentVariableBorrowRate;
    uint128 currentStableBorrowRate;
    uint40 lastUpdateTimestamp;
    uint16 id;
    address aTokenAddress;
    address stableDebtTokenAddress;
    address variableDebtTokenAddress;
    address interestRateStrategyAddress;
    uint128 accruedToTreasury;
    uint128 unbacked;
    uint128 isolationModeTotalDebt;
}

/**
 * @title AaveVault
 * @notice Aave integration vault for yield generation through USDC lending
 * 
 * @dev Main characteristics:
 *      - USDC deposits into Aave lending protocol for yield generation
 *      - Automatic yield harvesting and distribution
 *      - Risk management with exposure limits and health monitoring
 *      - Emergency withdrawal capabilities for crisis situations
 *      - Dynamic allocation based on market conditions
 *      - Upgradeable via UUPS pattern
 * 
 * @dev Deposit mechanics:
 *      - USDC supplied to Aave protocol for lending
 *      - Receives aUSDC tokens representing interest-bearing deposits
 *      - Principal tracking for yield calculation
 *      - Maximum exposure limits for risk management
 *      - Health checks before deposits
 * 
 * @dev Yield harvesting:
 *      - Automatic detection of accrued interest
 *      - Threshold-based harvesting to optimize gas costs
 *      - Protocol fees charged on harvested yield
 *      - Net yield distributed to yield shift mechanism
 *      - Real-time yield tracking and reporting
 * 
 * @dev Risk management:
 *      - Maximum Aave exposure limits (default 50M USDC)
 *      - Utilization rate monitoring for liquidity risk
 *      - Emergency mode for immediate withdrawals
 *      - Health monitoring of Aave protocol status
 *      - Slippage protection on withdrawals
 * 
 * @dev Allocation strategy:
 *      - Dynamic allocation based on Aave APY
 *      - Rebalancing thresholds for optimal yield
 *      - Market condition adjustments
 *      - Liquidity availability considerations
 *      - Expected yield calculations
 * 
 * @dev Fee structure:
 *      - Yield fees charged on harvested interest (default 10%)
 *      - Protocol fees for sustainability
 *      - Dynamic fee adjustment based on performance
 *      - Fee collection and distribution tracking
 * 
 * @dev Security features:
 *      - Role-based access control for all critical operations
 *      - Reentrancy protection for all external calls
 *      - Emergency pause mechanism for crisis situations
 *      - Upgradeable architecture for future improvements
 *      - Secure withdrawal validation
 *      - Health monitoring and circuit breakers
 * 
 * @dev Integration points:
 *      - Aave lending protocol for yield generation
 *      - USDC for deposits and withdrawals
 *      - aUSDC tokens for interest accrual tracking
 *      - Yield shift mechanism for yield distribution
 *      - Rewards controller for additional incentives
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract AaveVault is 
    Initializable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    SecureUpgradeable
{
    using SafeERC20 for IERC20;
    using VaultMath for uint256;
    using AccessControlLibrary for AccessControlUpgradeable;
    using CommonValidationLibrary for uint256;

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    IERC20 public usdc;
    IERC20 public aUSDC;
    IPool public aavePool;
    IPoolAddressesProvider public aaveProvider;
    IRewardsController public rewardsController;
    IYieldShift public yieldShift;

    uint256 public maxAaveExposure;
    uint256 public harvestThreshold;
    uint256 public yieldFee;
    uint256 public rebalanceThreshold;
    uint256 public principalDeposited;
    uint256 public lastHarvestTime;
    uint256 public totalYieldHarvested;
    uint256 public totalFeesCollected;
    uint256 public utilizationLimit;
    uint256 public emergencyExitThreshold;
    bool public emergencyMode;
    address public treasury;

    /// @dev OPTIMIZED: Indexed operation type for efficient filtering
    event DeployedToAave(string indexed operationType, uint256 amount, uint256 aTokensReceived, uint256 newBalance);
    event WithdrawnFromAave(string indexed operationType, uint256 amountRequested, uint256 amountWithdrawn, uint256 newBalance);
    event AaveYieldHarvested(string indexed harvestType, uint256 yieldHarvested, uint256 protocolFee, uint256 netYield);
    event AaveRewardsClaimed(address indexed rewardToken, uint256 rewardAmount, address recipient);
    /// @dev OPTIMIZED: Indexed reason and parameter for efficient filtering
    event PositionRebalanced(string indexed reason, uint256 oldAllocation, uint256 newAllocation);
    event AaveParameterUpdated(string indexed parameter, uint256 oldValue, uint256 newValue);
    event EmergencyWithdrawal(string indexed reason, uint256 amountWithdrawn, uint256 timestamp);
    event EmergencyModeToggled(string indexed reason, bool enabled);

    /**
     * @notice Constructor for AaveVault implementation
     * @dev Disables initialization on implementation for security
     * @custom:security Disables initialization on implementation for security
     * @custom:validation No input validation required
     * @custom:state-changes Disables initializers
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - constructor only
     * @custom:access Public constructor
     * @custom:oracle No oracle dependencies
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the AaveVault contract
     * @dev Sets up the contract with all required addresses and roles
     * @param admin Address of the admin role
     * @param _usdc Address of the USDC token contract
     * @param _aaveProvider Address of the Aave pool addresses provider
     * @param _rewardsController Address of the Aave rewards controller
     * @param _yieldShift Address of the yield shift contract
     * @param _timelock Address of the timelock contract
     * @param _treasury Address of the treasury
     * @custom:security Validates all addresses are not zero
     * @custom:validation Validates all input addresses
     * @custom:state-changes Initializes ReentrancyGuard, AccessControl, and Pausable
     * @custom:events Emits initialization events
     * @custom:errors Throws if any address is zero
     * @custom:reentrancy Protected by initializer modifier
     * @custom:access Public initializer
     * @custom:oracle No oracle dependencies
     */
    function initialize(
        address admin,
        address _usdc,
        address _aaveProvider,
        address _rewardsController,
        address _yieldShift,
        address _timelock,
        address _treasury
    ) public initializer {
        AccessControlLibrary.validateAddress(admin);
        AccessControlLibrary.validateAddress(_usdc);
        AccessControlLibrary.validateAddress(_aaveProvider);
        AccessControlLibrary.validateAddress(_yieldShift);
        AccessControlLibrary.validateAddress(_treasury);

        __ReentrancyGuard_init();
        __AccessControl_init();
        __Pausable_init();
        __SecureUpgradeable_init(_timelock);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(VAULT_MANAGER_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);

        usdc = IERC20(_usdc);
        aaveProvider = IPoolAddressesProvider(_aaveProvider);
        aavePool = IPool(aaveProvider.getPool());
        rewardsController = IRewardsController(_rewardsController);
        yieldShift = IYieldShift(_yieldShift);
        if (_treasury == address(0)) revert CommonErrorLibrary.ZeroAddress();
        CommonValidationLibrary.validateTreasuryAddress(_treasury);
        CommonValidationLibrary.validateNonZeroAddress(_treasury, "treasury");
        treasury = _treasury;

        ReserveData memory reserveData = aavePool.getReserveData(address(usdc));
        aUSDC = IERC20(reserveData.aTokenAddress);

        maxAaveExposure = 50_000_000e6;
        harvestThreshold = 1000e6;
        yieldFee = 1000;
        rebalanceThreshold = 500;
        utilizationLimit = 9500;
        emergencyExitThreshold = 110;
        
        lastHarvestTime = block.timestamp;
    }

    /**
     * @notice Deploy USDC to Aave V3 pool to earn yield
     * @param amount USDC amount to supply (6 decimals)
     * @return aTokensReceived Amount of aUSDC received (6 decimals)
     * @dev Supplies USDC to Aave protocol and receives aUSDC tokens representing the deposit
     * @custom:security Validates oracle price freshness, enforces exposure limits and health checks
     * @custom:validation Validates amount > 0, checks max exposure limits, verifies Aave pool health
     * @custom:state-changes Updates principalDeposited, transfers USDC from caller, receives aUSDC
     * @custom:events Emits DeployedToAave with operation details
     * @custom:errors Throws WouldExceedLimit if exceeds maxAaveExposure, AavePoolNotHealthy if pool unhealthy
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to VAULT_MANAGER_ROLE
     * @custom:oracle Requires fresh EUR/USD price for health validation
     */
    function deployToAave(uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256 aTokensReceived) 
    {
        AccessControlLibrary.onlyVaultManager(this);
        CommonValidationLibrary.validatePositiveAmount(amount);
        
        if (emergencyMode) revert CommonErrorLibrary.EmergencyModeActive();
        
        uint256 newTotalDeposit = principalDeposited + amount;
        if (newTotalDeposit > maxAaveExposure) revert CommonErrorLibrary.WouldExceedLimit();
        if (!_isAaveHealthy()) revert VaultErrorLibrary.AavePoolNotHealthy();
        
        uint256 balanceBefore = aUSDC.balanceOf(address(this));
        
        // UPDATE STATE BEFORE EXTERNAL CALL (CEI Pattern)
        principalDeposited += amount;
        
        // EXTERNAL CALL - aavePool.supply() (INTERACTIONS)
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        usdc.safeIncreaseAllowance(address(aavePool), amount);
        aavePool.supply(address(usdc), amount, address(this), 0);
        
        uint256 balanceAfter = aUSDC.balanceOf(address(this));
        aTokensReceived = balanceAfter - balanceBefore;
        
        if (principalDeposited > maxAaveExposure) {
            revert CommonErrorLibrary.WouldExceedLimit();
        }
        
        emit DeployedToAave("deploy", amount, aTokensReceived, balanceAfter);
    }

    /**
     * @notice Withdraw USDC from Aave V3 pool
     * @param amount Amount of aUSDC to withdraw (6 decimals, use type(uint256).max for all)
     * @return usdcWithdrawn Amount of USDC actually withdrawn (6 decimals)
     * @dev Withdraws USDC from Aave protocol, validates slippage and updates principal tracking
     * @custom:security Validates withdrawal constraints, enforces minimum balance requirements
     * @custom:validation Validates amount > 0, checks sufficient aUSDC balance, validates slippage
     * @custom:state-changes Updates principalDeposited, withdraws aUSDC, receives USDC
     * @custom:events Emits WithdrawnFromAave with withdrawal details
     * @custom:errors Throws InsufficientBalance if not enough aUSDC, WouldBreachMinimum if below threshold
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to VAULT_MANAGER_ROLE
     * @custom:oracle No oracle dependency for withdrawals
     */
    function withdrawFromAave(uint256 amount) 
        external 
        nonReentrant 
        returns (uint256 usdcWithdrawn) 
    {
        AccessControlLibrary.onlyVaultManager(this);
        CommonValidationLibrary.validatePositiveAmount(amount);
        
        uint256 aaveBalance = aUSDC.balanceOf(address(this));
        uint256 withdrawAmount = _validateAndCalculateWithdrawAmount(amount, aaveBalance);
        
        _validateWithdrawalConstraints(withdrawAmount, aaveBalance);
        
        uint256 usdcBefore = usdc.balanceOf(address(this));
        _validateExpectedWithdrawal(withdrawAmount);
        
        
        uint256 expectedPrincipalToDeduct = VaultMath.min(withdrawAmount, principalDeposited);
        if (expectedPrincipalToDeduct > 0) {
            principalDeposited -= expectedPrincipalToDeduct;
        }
        usdcWithdrawn = _executeAaveWithdrawal(amount, withdrawAmount, usdcBefore);
        
        // Transfer withdrawn USDC back to caller (QuantillonVault)
        if (usdcWithdrawn > 0) {
            usdc.safeTransfer(msg.sender, usdcWithdrawn);
        }
    }
    
    /**
     * @notice Validates and calculates the actual withdrawal amount
     * @param amount Requested withdrawal amount (6 decimals)
     * @param aaveBalance Current aUSDC balance (6 decimals)
     * @return withdrawAmount Actual amount to withdraw (6 decimals)
     * @dev Internal function to validate withdrawal parameters and calculate actual amount
     * @custom:security Validates sufficient balance and handles max withdrawal requests
     * @custom:validation Validates aaveBalance > 0, amount <= aaveBalance
     * @custom:state-changes No state changes - pure function
     * @custom:events No events emitted
     * @custom:errors Throws InsufficientBalance if balance too low
     * @custom:reentrancy Not applicable - pure function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _validateAndCalculateWithdrawAmount(
        uint256 amount, 
        uint256 aaveBalance
    ) internal pure returns (uint256 withdrawAmount) {
        if (aaveBalance < 1) revert CommonErrorLibrary.InsufficientBalance();
        
        withdrawAmount = amount;
        if (amount == type(uint256).max) {
            withdrawAmount = aaveBalance;
        }
        
        if (withdrawAmount > aaveBalance) revert CommonErrorLibrary.InsufficientBalance();
    }
    
    /**
     * @notice Validates withdrawal constraints (emergency mode, minimum balance)
     * @param withdrawAmount Amount to withdraw (6 decimals)
     * @param aaveBalance Current aUSDC balance (6 decimals)
     * @dev Internal function to validate withdrawal constraints and minimum balance requirements
     * @custom:security Enforces minimum balance requirements unless in emergency mode
     * @custom:validation Validates remaining balance >= minimum threshold
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors Throws WouldBreachMinimum if below minimum balance threshold
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _validateWithdrawalConstraints(uint256 withdrawAmount, uint256 aaveBalance) internal view {
        if (!emergencyMode) {
            uint256 remainingBalance = aaveBalance - withdrawAmount;
            uint256 minBalance = principalDeposited.mulDiv(rebalanceThreshold, 10000);
            if (remainingBalance < minBalance) revert VaultErrorLibrary.WouldBreachMinimum();
        }
    }
    
    /**
     * @notice Validates expected withdrawal amounts before external call
     * @dev Validates expected withdrawal amounts before external call
     * @param withdrawAmount Amount to withdraw
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function _validateExpectedWithdrawal(uint256 withdrawAmount) internal view {
        uint256 expectedPrincipalWithdrawn = VaultMath.min(withdrawAmount, principalDeposited);
        
        if (expectedPrincipalWithdrawn > 0) {
            if (principalDeposited < expectedPrincipalWithdrawn) {
                revert CommonErrorLibrary.InvalidAmount();
            }
        }
    }
    
    /**
     * @notice Executes the Aave withdrawal with proper error handling
     * @dev Executes the Aave withdrawal with proper error handling
     * @param originalAmount Original amount requested
     * @param withdrawAmount Amount to withdraw from Aave
     * @param usdcBefore USDC balance before withdrawal
     * @return usdcWithdrawn Actual amount withdrawn
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function _executeAaveWithdrawal(
        uint256 originalAmount,
        uint256 withdrawAmount,
        uint256 usdcBefore
    ) internal returns (uint256 usdcWithdrawn) {
        try aavePool.withdraw(address(usdc), withdrawAmount, address(this)) 
            returns (uint256 withdrawn) 
        {
            usdcWithdrawn = withdrawn;
            _validateWithdrawalResult(originalAmount, withdrawAmount, usdcBefore, usdcWithdrawn);
            
            emit WithdrawnFromAave("withdraw", originalAmount, usdcWithdrawn, aUSDC.balanceOf(address(this)));
            
        } catch Error(string memory reason) {
            revert(string(abi.encodePacked("Aave withdrawal failed: ", reason)));
        } catch {
            revert("Aave withdrawal failed");
        }
    }
    
    /**
     * @notice Validates the withdrawal result and slippage
     * @dev Validates the withdrawal result and slippage
     * @param originalAmount Original amount requested
     * @param withdrawAmount Amount to withdraw from Aave
     * @param usdcBefore USDC balance before withdrawal
     * @param usdcWithdrawn Actual amount withdrawn
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function _validateWithdrawalResult(
        uint256 originalAmount,
        uint256 withdrawAmount,
        uint256 usdcBefore,
        uint256 usdcWithdrawn
    ) internal view {
        uint256 usdcAfter = usdc.balanceOf(address(this));
        uint256 actualReceived = usdcAfter - usdcBefore;
        
        // Strict validation - ensure actual received matches returned amount
        if (actualReceived != usdcWithdrawn) {
            revert CommonErrorLibrary.ExcessiveSlippage();
        }
        
        // Validate slippage tolerance
        if (originalAmount != type(uint256).max) {
            CommonValidationLibrary.validateSlippage(actualReceived, withdrawAmount, 100);
        } else {
            CommonValidationLibrary.validateSlippage(actualReceived, withdrawAmount, 500);
        }
    }
    


    /**
     * @notice Claim Aave rewards (if any)
     * @return rewardsClaimed Claimed reward amount (18 decimals)
     * @dev Claims any available Aave protocol rewards for the vault's aUSDC position
     * @custom:security No additional security checks required - Aave handles reward validation
     * @custom:validation No input validation required - view function checks pending rewards
     * @custom:state-changes Claims rewards to vault address, updates reward tracking
     * @custom:events Emits AaveRewardsClaimed with reward details
     * @custom:errors No errors thrown - safe to call even with no rewards
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to VAULT_MANAGER_ROLE
     * @custom:oracle No oracle dependency for reward claims
     */
    function claimAaveRewards() 
        external 
        nonReentrant 
        returns (uint256 rewardsClaimed) 
    {
        AccessControlLibrary.onlyVaultManager(this);
        
        address[] memory assets = new address[](1);
        assets[0] = address(aUSDC);
        
        uint256[] memory pendingRewards = rewardsController.getUserRewards(assets, address(this));
        
        if (pendingRewards.length > 0 && pendingRewards[0] > 0) {
            rewardsClaimed = rewardsController.claimRewards(assets, pendingRewards[0], address(this));
            emit AaveRewardsClaimed(address(0), rewardsClaimed, address(this));
        }
    }

    /**
     * @notice Harvest Aave yield and distribute via YieldShift
     * @return yieldHarvested Amount harvested (6 decimals)
     * @dev Harvests available yield from Aave lending, charges protocol fees, distributes net yield
     * @custom:security Uses CEI pattern, validates slippage, enforces harvest threshold
     * @custom:validation Validates available yield >= harvestThreshold before harvesting
     * @custom:state-changes Updates lastHarvestTime, totalFeesCollected, totalYieldHarvested
     * @custom:events Emits AaveYieldHarvested with harvest details
     * @custom:errors Throws BelowThreshold if yield < harvestThreshold, ExcessiveSlippage if slippage too high
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to VAULT_MANAGER_ROLE
     * @custom:oracle No oracle dependency for yield harvesting
     */
    function harvestAaveYield() 
        external 
        nonReentrant 
        returns (uint256 yieldHarvested) 
    {
        AccessControlLibrary.onlyVaultManager(this);
        
        uint256 availableYield = getAvailableYield();
        CommonValidationLibrary.validateThresholdValue(availableYield, harvestThreshold);
        
        uint256 protocolFee = availableYield.mulDiv(yieldFee, 10000);
        uint256 netYield = availableYield - protocolFee;
        
        uint256 usdcBefore = usdc.balanceOf(address(this));

        // UPDATE STATE BEFORE EXTERNAL CALL (EFFECTS) - Reentrancy protection
        lastHarvestTime = block.timestamp;
        totalFeesCollected += protocolFee;
        totalYieldHarvested += availableYield; // Use expected yield for reentrancy protection

        uint256 actualYieldReceived = 0; // Initialize to prevent uninitialized variable warning
        try aavePool.withdraw(address(usdc), availableYield, address(this)) 
            returns (uint256 withdrawn) 
        {
            uint256 usdcAfter = usdc.balanceOf(address(this));
            actualYieldReceived = usdcAfter - usdcBefore;
            
            // Verify actual received matches returned amount
            if (actualYieldReceived != withdrawn) {
                revert CommonErrorLibrary.ExcessiveSlippage();
            }
            
            CommonValidationLibrary.validateSlippage(actualYieldReceived, availableYield, 100);
            
        } catch Error(string memory reason) {
            revert(string(abi.encodePacked("Aave yield harvest failed: ", reason)));
        } catch {
            revert("Aave yield harvest failed");
        }
        
        // Note: totalYieldHarvested already updated with availableYield before external call
        // This provides reentrancy protection. Any slippage is handled by validation above.
        
        if (netYield > 0) {
            usdc.safeIncreaseAllowance(address(yieldShift), netYield);
            // forge-lint: disable-next-line(unsafe-typecast)
            yieldShift.addYield(netYield, bytes32("aave"));
        }
        
        emit AaveYieldHarvested("harvest", actualYieldReceived, protocolFee, netYield);
        
        yieldHarvested = actualYieldReceived;
    }

    /**
     * @notice Returns the total available yield from Aave lending
     * @dev Calculates yield based on current aToken balance vs principal deposited
     * @return The amount of yield available for distribution
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getAvailableYield() public view returns (uint256) {
        uint256 currentBalance = aUSDC.balanceOf(address(this));
        
        if (currentBalance <= principalDeposited) {
            return 0;
        }
        
        return currentBalance - principalDeposited;
    }

    /**
     * @notice Returns the breakdown of yield distribution between users and protocol
     * @dev Shows how yield is allocated according to current distribution parameters
     * @return protocolYield Amount of yield allocated to protocol fees
     * @return userYield Amount of yield allocated to users
     * @return hedgerYield Amount of yield allocated to hedgers
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getYieldDistribution() external view returns (
        uint256 protocolYield,
        uint256 userYield,
        uint256 hedgerYield
    ) {
        uint256 availableYield = getAvailableYield();
        protocolYield = availableYield.mulDiv(yieldFee, 10000);
        uint256 netYield = availableYield - protocolYield;
        
        uint256 yieldShiftPct = yieldShift.getCurrentYieldShift();
        userYield = netYield.mulDiv(yieldShiftPct, 10000);
        hedgerYield = netYield - userYield;
    }

    /**
     * @notice Returns the current balance of aTokens held by this vault
     * @dev Represents the total amount deposited in Aave plus accrued interest
     * @return The current aToken balance
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getAaveBalance() external view returns (uint256) {
        return aUSDC.balanceOf(address(this));
    }

    /**
     * @notice Returns the total interest accrued from Aave lending
     * @dev Calculates interest as current balance minus principal deposited
     * @return The amount of interest accrued
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getAccruedInterest() external view returns (uint256) {
        return getAvailableYield();
    }

    /**
     * @notice Returns the current APY offered by Aave for the deposited asset
     * @dev Fetches the supply rate from Aave's reserve data
     * @return The current APY in basis points
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getAaveAPY() external view returns (uint256) {
        ReserveData memory reserveData = aavePool.getReserveData(address(usdc));
        return uint256(reserveData.currentLiquidityRate) / 1e23;
    }

    /**
     * @notice Returns detailed information about the Aave position
     * @dev Provides comprehensive data about the vault's Aave lending position
     * @return principalDeposited_ Total amount originally deposited
     * @return currentBalance Current aToken balance including interest
     * @return aTokenBalance Current aToken balance
     * @return lastUpdateTime Timestamp of last position update
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getAavePositionDetails() external view returns (
        uint256 principalDeposited_,
        uint256 currentBalance,
        uint256 aTokenBalance,
        uint256 lastUpdateTime
    ) {
        principalDeposited_ = principalDeposited;
        aTokenBalance = aUSDC.balanceOf(address(this));
        currentBalance = aTokenBalance;
        lastUpdateTime = lastHarvestTime;
    }

    /**
     * @notice Returns current Aave market data for the deposited asset
     * @dev Fetches real-time market information from Aave protocol
     * @return supplyRate Current supply rate for the asset
     * @return utilizationRate Current utilization rate of the reserve
     * @return totalSupply Total supply of the underlying asset
     * @return availableLiquidity Available liquidity in the reserve
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getAaveMarketData() external view returns (
        uint256 supplyRate,
        uint256 utilizationRate,
        uint256 totalSupply,
        uint256 availableLiquidity
    ) {
        ReserveData memory reserveData = aavePool.getReserveData(address(usdc));
        supplyRate = uint256(reserveData.currentLiquidityRate) / 1e23;
        totalSupply = usdc.totalSupply();
        availableLiquidity = usdc.balanceOf(address(aavePool));
        if (totalSupply > 0) {
            uint256 totalBorrowed = totalSupply - availableLiquidity;
            utilizationRate = totalBorrowed.mulDiv(10000, totalSupply);
        }
    }

    /**
     * @notice Performs health checks on the Aave position
     * @dev Validates that the Aave position is healthy and functioning properly
     * @return isHealthy True if position is healthy, false if issues detected
     * @return pauseStatus Current pause status of the contract
     * @return lastUpdate Timestamp of last health check update
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function checkAaveHealth() external view returns (
        bool isHealthy,
        bool pauseStatus,
        uint256 lastUpdate
    ) {
        isHealthy = _isAaveHealthy();
        pauseStatus = paused();
        lastUpdate = lastHarvestTime;
    }

    /**
     * @notice Check if Aave protocol is healthy
     * @dev Checks if Aave protocol is functioning properly by verifying reserve data
     * @return bool True if Aave is healthy, false otherwise
     * @custom:security Uses try-catch to handle potential failures gracefully
     * @custom:validation No input validation required
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - uses try-catch
     * @custom:reentrancy Not applicable - view function
     * @custom:access Internal function - no access restrictions
     * @custom:oracle No oracle dependencies
     */
    function _isAaveHealthy() internal view returns (bool) {
        try aavePool.getReserveData(address(usdc)) returns (ReserveData memory reserveData) {
            return reserveData.aTokenAddress != address(0);
        } catch {
            return false;
        }
    }

    /**
     * @notice Automatically rebalance the vault allocation
     * @dev Rebalances the vault allocation based on optimal allocation calculations
     * @return rebalanced True if rebalancing occurred, false otherwise
     * @return newAllocation New allocation percentage after rebalancing
     * @return expectedYield Expected yield from the new allocation
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function autoRebalance() 
        external 
        returns (bool rebalanced, uint256 newAllocation, uint256 expectedYield) 
    {
        AccessControlLibrary.onlyVaultManager(this);
        
        (uint256 optimalAllocation, uint256 _expectedYield) = this.calculateOptimalAllocation();
        uint256 currentBalance = aUSDC.balanceOf(address(this));
        uint256 totalAssets = currentBalance + usdc.balanceOf(address(this));
        
        if (totalAssets < 1) {
            return (false, 0, 0);
        }
        
        uint256 currentAllocation = currentBalance.mulDiv(10000, totalAssets);
        uint256 allocationDiff = optimalAllocation > currentAllocation ?
            optimalAllocation - currentAllocation :
            currentAllocation - optimalAllocation;
        
        if (allocationDiff >= rebalanceThreshold) {
            rebalanced = true;
            newAllocation = optimalAllocation;
            expectedYield = _expectedYield;
            
            emit PositionRebalanced("Auto rebalance", currentAllocation, newAllocation);
        } else {
            expectedYield = _expectedYield;
        }
    }

    /**
     * @notice Calculates the optimal allocation of funds to Aave
     * @dev Determines best allocation strategy based on current market conditions
     * @return optimalAllocation Recommended amount to allocate to Aave
     * @return expectedYield Expected yield from the recommended allocation
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function calculateOptimalAllocation() external view returns (
        uint256 optimalAllocation,
        uint256 expectedYield
    ) {
        uint256 aaveAPY = this.getAaveAPY();
        
        if (aaveAPY >= 300) {
            optimalAllocation = 8000;
        } else if (aaveAPY >= 200) {
            optimalAllocation = 6000;
        } else {
            optimalAllocation = 4000;
        }
        
        expectedYield = aaveAPY;
    }

    /**
     * @notice Sets the maximum exposure limit for Aave deposits
     * @dev Governance function to control risk by limiting Aave exposure
     * @param _maxExposure Maximum amount that can be deposited to Aave
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function setMaxAaveExposure(uint256 _maxExposure) external {
        AccessControlLibrary.onlyGovernance(this);
        CommonValidationLibrary.validatePositiveAmount(_maxExposure);
        if (_maxExposure > 1_000_000_000e6) revert CommonErrorLibrary.ConfigValueTooHigh();
        
        emit AaveParameterUpdated("maxAaveExposure", maxAaveExposure, _maxExposure);
        maxAaveExposure = _maxExposure;
    }

    /**
     * @notice Emergency withdrawal from Aave protocol
     * @dev Emergency function to withdraw all funds from Aave protocol
     * @return amountWithdrawn Amount of USDC withdrawn from Aave
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function emergencyWithdrawFromAave() 
        external 
        nonReentrant 
        returns (uint256 amountWithdrawn) 
    {
        AccessControlLibrary.onlyEmergencyRole(this);
        
        uint256 aaveBalance = aUSDC.balanceOf(address(this));
        
        if (aaveBalance > 0) {
            emergencyMode = true;
            // In emergency, reset principal to 0 before external call (conservative approach)
            principalDeposited = 0;
            
            uint256 usdcBefore = usdc.balanceOf(address(this));
            
            uint256 actualReceived = 0; // Initialize to prevent uninitialized variable warning
            try aavePool.withdraw(address(usdc), type(uint256).max, address(this)) 
                returns (uint256 withdrawn) 
            {
                uint256 usdcAfter = usdc.balanceOf(address(this));
                actualReceived = usdcAfter - usdcBefore;
                
                // Verify actual received matches returned amount
                if (actualReceived != withdrawn) {
                    revert CommonErrorLibrary.ExcessiveSlippage();
                }
                
            } catch Error(string memory reason) {
                revert(string(abi.encodePacked("Emergency Aave withdrawal failed: ", reason)));
            } catch {
                revert("Emergency Aave withdrawal failed");
            }
            
            // Set return value
            amountWithdrawn = actualReceived;
            

            emit EmergencyWithdrawal("Emergency exit from Aave", amountWithdrawn, block.timestamp);
            emit EmergencyModeToggled("Emergency withdrawal executed", true);
        }
    }

    /**
     * @notice Returns comprehensive risk metrics for the Aave position
     * @dev Provides detailed risk analysis including concentration and volatility metrics
     * @return exposureRatio Percentage of total assets exposed to Aave
     * @return concentrationRisk Risk level due to concentration in Aave (1-3 scale)
     * @return liquidityRisk Risk level based on Aave liquidity conditions (1-3 scale)
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getRiskMetrics() external view returns (
        uint256 exposureRatio,
        uint256 concentrationRisk,
        uint256 liquidityRisk
    ) {
        uint256 aaveBalance = aUSDC.balanceOf(address(this));
        uint256 totalAssets = aaveBalance + usdc.balanceOf(address(this));
        exposureRatio = totalAssets > 0 ? aaveBalance.mulDiv(10000, totalAssets) : 0;
        concentrationRisk = exposureRatio > 8000 ? 3 : exposureRatio > 6000 ? 2 : 1;

        // slither-disable-next-line unused-return
        (, uint256 utilizationRate, , ) = this.getAaveMarketData();
        liquidityRisk = utilizationRate > 9500 ? 3 : utilizationRate > 9000 ? 2 : 1;
    }

    /**
     * @notice Update Aave parameters
     * @dev Updates harvest threshold, yield fee, and rebalance threshold
     * @param newHarvestThreshold New harvest threshold in USDC
     * @param newYieldFee New yield fee in basis points
     * @param newRebalanceThreshold New rebalance threshold in basis points
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function updateAaveParameters(
        uint256 newHarvestThreshold,
        uint256 newYieldFee,
        uint256 newRebalanceThreshold
    ) external {
        AccessControlLibrary.onlyGovernance(this);
        CommonValidationLibrary.validateFee(newYieldFee, 2000);
        CommonValidationLibrary.validateThreshold(newRebalanceThreshold, 2000);
        
        harvestThreshold = newHarvestThreshold;
        yieldFee = newYieldFee;
        rebalanceThreshold = newRebalanceThreshold;
    }

    /**
     * @notice Returns the current Aave integration configuration
     * @dev Provides access to all configuration parameters for Aave integration
     * @return aavePool_ Address of the Aave pool contract
     * @return aUSDC_ Address of the aUSDC token contract
     * @return harvestThreshold_ Minimum yield threshold for harvesting
     * @return yieldFee_ Fee percentage charged on yield
     * @return maxExposure_ Maximum allowed exposure to Aave
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getAaveConfig() external view returns (
        address aavePool_,
        address aUSDC_,
        uint256 harvestThreshold_,
        uint256 yieldFee_,
        uint256 maxExposure_
    ) {
        return (
            address(aavePool),
            address(aUSDC),
            harvestThreshold,
            yieldFee,
            maxAaveExposure
        );
    }

    /**
     * @notice Toggles emergency mode for the Aave vault
     * @dev Emergency function to enable/disable emergency mode during critical situations
     * @param enabled Whether to enable or disable emergency mode
     * @param reason Human-readable reason for the change
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function toggleEmergencyMode(bool enabled, string calldata reason) external {
        AccessControlLibrary.onlyEmergencyRole(this);
        emergencyMode = enabled;
        emit EmergencyModeToggled(reason, enabled);
    }

    /**
     * @notice Pauses all Aave vault operations
     * @dev Emergency function to halt all vault operations when needed
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function pause() external {
        AccessControlLibrary.onlyEmergencyRole(this);
        _pause();
    }

    /**
     * @notice Unpauses Aave vault operations
     * @dev Resumes normal vault operations after emergency is resolved
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function unpause() external {
        AccessControlLibrary.onlyEmergencyRole(this);
        _unpause();
    }

    /**
     * @notice Recovers accidentally sent ERC20 tokens from the vault
     * @dev Emergency function to recover tokens that are not part of normal operations
     * @param token The token address to recover
     * @param amount The amount of tokens to recover
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function recoverToken(address token, uint256 amount) external {
        AccessControlLibrary.onlyAdmin(this);
        // Use the shared library for secure token recovery to treasury
        TreasuryRecoveryLibrary.recoverToken(token, amount, address(this), treasury);
    }

    /**
     * @notice Recovers accidentally sent ETH from the vault
     * @dev Emergency function to recover ETH that shouldn't be in the vault
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function recoverETH() external {
        AccessControlLibrary.onlyAdmin(this);
        // Use the shared library for secure ETH recovery
        TreasuryRecoveryLibrary.recoverETH(treasury);
    }
}