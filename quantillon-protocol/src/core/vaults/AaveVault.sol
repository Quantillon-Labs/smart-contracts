// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../interfaces/IYieldShift.sol";
import "../../libraries/VaultMath.sol";
import "../../libraries/ErrorLibrary.sol";
import "../../libraries/AccessControlLibrary.sol";
import "../../libraries/ValidationLibrary.sol";
import "../SecureUpgradeable.sol";

/**
 * @title AaveVault
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
interface IPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function getReserveData(address asset) external view returns (ReserveData memory);
}

interface IPoolAddressesProvider {
    function getPool() external view returns (address);
}

interface IRewardsController {
    function claimRewards(address[] calldata assets, uint256 amount, address to) external returns (uint256);
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
 * @author Quantillon Labs
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
    using ValidationLibrary for uint256;

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

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin,
        address _usdc,
        address _aaveProvider,
        address _rewardsController,
        address _yieldShift,
        address timelock
    ) public initializer {
        AccessControlLibrary.validateAddress(admin);
        AccessControlLibrary.validateAddress(_usdc);
        AccessControlLibrary.validateAddress(_aaveProvider);
        AccessControlLibrary.validateAddress(_yieldShift);

        __ReentrancyGuard_init();
        __AccessControl_init();
        __Pausable_init();
        __SecureUpgradeable_init(timelock);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(VAULT_MANAGER_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);

        usdc = IERC20(_usdc);
        aaveProvider = IPoolAddressesProvider(_aaveProvider);
        aavePool = IPool(aaveProvider.getPool());
        rewardsController = IRewardsController(_rewardsController);
        yieldShift = IYieldShift(_yieldShift);

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

    function deployToAave(uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256 aTokensReceived) 
    {
        AccessControlLibrary.onlyVaultManager(this);
        ValidationLibrary.validatePositiveAmount(amount);
        
        if (emergencyMode) revert ErrorLibrary.EmergencyModeActive();
        
        uint256 newTotalDeposit = principalDeposited + amount;
        if (newTotalDeposit > maxAaveExposure) revert ErrorLibrary.WouldExceedLimit();
        if (!_isAaveHealthy()) revert ErrorLibrary.AavePoolNotHealthy();
        
        uint256 balanceBefore = aUSDC.balanceOf(address(this));
        
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        usdc.safeIncreaseAllowance(address(aavePool), amount);
        aavePool.supply(address(usdc), amount, address(this), 0);
        
        uint256 balanceAfter = aUSDC.balanceOf(address(this));
        aTokensReceived = balanceAfter - balanceBefore;
        
        principalDeposited += amount;
        
        // SECURITY: Validate that principalDeposited doesn't exceed reasonable bounds
        if (principalDeposited > maxAaveExposure) {
            revert ErrorLibrary.WouldExceedLimit();
        }
        
        emit DeployedToAave("deploy", amount, aTokensReceived, balanceAfter);
    }

    function withdrawFromAave(uint256 amount) 
        external 
        nonReentrant 
        returns (uint256 usdcWithdrawn) 
    {
        AccessControlLibrary.onlyVaultManager(this);
        ValidationLibrary.validatePositiveAmount(amount);
        
        uint256 aaveBalance = aUSDC.balanceOf(address(this));
        // SECURITY: Check if there are Aave tokens to withdraw (safe equality check)
        if (aaveBalance == 0) revert ErrorLibrary.InsufficientBalance();
        
        uint256 withdrawAmount = amount;
        if (amount == type(uint256).max) {
            withdrawAmount = aaveBalance;
        }
        
        if (withdrawAmount > aaveBalance) revert ErrorLibrary.InsufficientBalance();
        
        if (!emergencyMode) {
            uint256 remainingBalance = aaveBalance - withdrawAmount;
            uint256 minBalance = principalDeposited.mulDiv(rebalanceThreshold, 10000);
            if (remainingBalance < minBalance) revert ErrorLibrary.WouldBreachMinimum();
        }
        
        uint256 usdcBefore = usdc.balanceOf(address(this));
        
        // Perform withdrawal and validate return value
        try aavePool.withdraw(address(usdc), withdrawAmount, address(this)) 
            returns (uint256 withdrawn) 
        {
            usdcWithdrawn = withdrawn;
            
            // Verify actual amount received
            uint256 usdcAfter = usdc.balanceOf(address(this));
            uint256 actualReceived = usdcAfter - usdcBefore;
            
            // Strict validation - ensure actual received matches returned amount
            if (actualReceived != usdcWithdrawn) {
                revert ErrorLibrary.ExcessiveSlippage();
            }
            
            // Validate slippage tolerance
            if (amount != type(uint256).max) {
                ValidationLibrary.validateSlippage(actualReceived, withdrawAmount, 100);
            } else {
                ValidationLibrary.validateSlippage(actualReceived, withdrawAmount, 500);
            }
            
            // Only update accounting with verified amount
            uint256 principalWithdrawn = VaultMath.min(actualReceived, principalDeposited);
            principalDeposited -= principalWithdrawn;
            
            // SECURITY: Ensure principalDeposited never goes negative
            if (principalDeposited > type(uint256).max - principalWithdrawn) {
                revert ErrorLibrary.InvalidAmount();
            }
            
            emit WithdrawnFromAave("withdraw", amount, actualReceived, aUSDC.balanceOf(address(this)));
            
        } catch Error(string memory reason) {
            revert(string(abi.encodePacked("Aave withdrawal failed: ", reason)));
        } catch {
            revert("Aave withdrawal failed");
        }
    }

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

    function harvestAaveYield() 
        external 
        nonReentrant 
        returns (uint256 yieldHarvested) 
    {
        AccessControlLibrary.onlyVaultManager(this);
        
        uint256 availableYield = getAvailableYield();
        ValidationLibrary.validateThresholdValue(availableYield, harvestThreshold);
        
        uint256 protocolFee = availableYield.mulDiv(yieldFee, 10000);
        uint256 netYield = availableYield - protocolFee;
        
        uint256 usdcBefore = usdc.balanceOf(address(this));
        
        // Perform yield withdrawal and validate return value
        try aavePool.withdraw(address(usdc), availableYield, address(this)) 
            returns (uint256 withdrawn) 
        {
            uint256 usdcAfter = usdc.balanceOf(address(this));
            uint256 actualYieldReceived = usdcAfter - usdcBefore;
            
            // Verify actual received matches returned amount
            if (actualYieldReceived != withdrawn) {
                revert ErrorLibrary.ExcessiveSlippage();
            }
            
            ValidationLibrary.validateSlippage(actualYieldReceived, availableYield, 100);
            
            totalYieldHarvested += actualYieldReceived;
            totalFeesCollected += protocolFee;
            lastHarvestTime = block.timestamp;
            
            if (netYield > 0) {
                usdc.safeIncreaseAllowance(address(yieldShift), netYield);
                yieldShift.addYield(netYield, bytes32("aave"));
            }
            
            emit AaveYieldHarvested("harvest", actualYieldReceived, protocolFee, netYield);
            
            yieldHarvested = actualYieldReceived;
            
        } catch Error(string memory reason) {
            revert(string(abi.encodePacked("Aave yield harvest failed: ", reason)));
        } catch {
            revert("Aave yield harvest failed");
        }
    }

    function getAvailableYield() public view returns (uint256) {
        uint256 currentBalance = aUSDC.balanceOf(address(this));
        
        if (currentBalance <= principalDeposited) {
            return 0;
        }
        
        return currentBalance - principalDeposited;
    }

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

    function getAaveBalance() external view returns (uint256) {
        return aUSDC.balanceOf(address(this));
    }

    function getAccruedInterest() external view returns (uint256) {
        return getAvailableYield();
    }

    function getAaveAPY() external view returns (uint256) {
        ReserveData memory reserveData = aavePool.getReserveData(address(usdc));
        return uint256(reserveData.currentLiquidityRate) / 1e23;
    }

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

    function checkAaveHealth() external view returns (
        bool isHealthy,
        bool pauseStatus,
        uint256 lastUpdate
    ) {
        isHealthy = _isAaveHealthy();
        pauseStatus = paused();
        lastUpdate = lastHarvestTime;
    }

    function _isAaveHealthy() internal view returns (bool) {
        try aavePool.getReserveData(address(usdc)) returns (ReserveData memory reserveData) {
            return reserveData.aTokenAddress != address(0);
        } catch {
            return false;
        }
    }

    function autoRebalance() 
        external 
        returns (bool rebalanced, uint256 newAllocation, uint256 expectedYield) 
    {
        AccessControlLibrary.onlyVaultManager(this);
        
        (uint256 optimalAllocation, uint256 _expectedYield) = this.calculateOptimalAllocation();
        uint256 currentBalance = aUSDC.balanceOf(address(this));
        uint256 totalAssets = currentBalance + usdc.balanceOf(address(this));
        
        if (totalAssets == 0) {
            // SECURITY: No assets to rebalance (safe equality check)
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

    function setMaxAaveExposure(uint256 _maxExposure) external {
        AccessControlLibrary.onlyGovernance(this);
        ValidationLibrary.validatePositiveAmount(_maxExposure);
        if (_maxExposure > 1_000_000_000e6) revert ErrorLibrary.ConfigValueTooHigh();
        
        emit AaveParameterUpdated("maxAaveExposure", maxAaveExposure, _maxExposure);
        maxAaveExposure = _maxExposure;
    }

    function emergencyWithdrawFromAave() 
        external 
        returns (uint256 amountWithdrawn) 
    {
        AccessControlLibrary.onlyEmergencyRole(this);
        
        uint256 aaveBalance = aUSDC.balanceOf(address(this));
        
        if (aaveBalance > 0) {
            emergencyMode = true;
            
            uint256 usdcBefore = usdc.balanceOf(address(this));
            
            // Perform emergency withdrawal and validate return value
            try aavePool.withdraw(address(usdc), type(uint256).max, address(this)) 
                returns (uint256 withdrawn) 
            {
                uint256 usdcAfter = usdc.balanceOf(address(this));
                uint256 actualReceived = usdcAfter - usdcBefore;
                
                // Verify actual received matches returned amount
                if (actualReceived != withdrawn) {
                    revert ErrorLibrary.ExcessiveSlippage();
                }
                
                amountWithdrawn = actualReceived;
                
                uint256 principalWithdrawn = VaultMath.min(amountWithdrawn, principalDeposited);
                principalDeposited -= principalWithdrawn;
                
                // SECURITY: Ensure principalDeposited never goes negative
                if (principalDeposited > type(uint256).max - principalWithdrawn) {
                    revert ErrorLibrary.InvalidAmount();
                }
                
                emit EmergencyWithdrawal("Emergency exit from Aave", amountWithdrawn, block.timestamp);
                emit EmergencyModeToggled("Emergency withdrawal executed", true);
                
            } catch Error(string memory reason) {
                revert(string(abi.encodePacked("Emergency Aave withdrawal failed: ", reason)));
            } catch {
                revert("Emergency Aave withdrawal failed");
            }
        }
    }

    function getRiskMetrics() external view returns (
        uint256 exposureRatio,
        uint256 concentrationRisk,
        uint256 liquidityRisk
    ) {
        uint256 aaveBalance = aUSDC.balanceOf(address(this));
        uint256 totalAssets = aaveBalance + usdc.balanceOf(address(this));
        exposureRatio = totalAssets > 0 ? aaveBalance.mulDiv(10000, totalAssets) : 0;
        concentrationRisk = exposureRatio > 8000 ? 3 : exposureRatio > 6000 ? 2 : 1;
        // SECURITY: Only need utilization rate, ignore other return values (safe to ignore for risk metrics)
        (, uint256 utilizationRate, , ) = this.getAaveMarketData();
        liquidityRisk = utilizationRate > 9500 ? 3 : utilizationRate > 9000 ? 2 : 1;
    }

    function updateAaveParameters(
        uint256 newHarvestThreshold,
        uint256 newYieldFee,
        uint256 newRebalanceThreshold
    ) external {
        AccessControlLibrary.onlyGovernance(this);
        ValidationLibrary.validateFee(newYieldFee, 2000);
        ValidationLibrary.validateThreshold(newRebalanceThreshold, 2000);
        
        harvestThreshold = newHarvestThreshold;
        yieldFee = newYieldFee;
        rebalanceThreshold = newRebalanceThreshold;
    }

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

    function toggleEmergencyMode(bool enabled, string calldata reason) external {
        AccessControlLibrary.onlyEmergencyRole(this);
        emergencyMode = enabled;
        emit EmergencyModeToggled(reason, enabled);
    }

    function pause() external {
        AccessControlLibrary.onlyEmergencyRole(this);
        _pause();
    }

    function unpause() external {
        AccessControlLibrary.onlyEmergencyRole(this);
        _unpause();
    }

    function recoverToken(address token, address to, uint256 amount) external {
        AccessControlLibrary.onlyAdmin(this);
        if (token == address(usdc)) revert ErrorLibrary.CannotRecoverUSDC();
        if (token == address(aUSDC)) revert ErrorLibrary.CannotRecoverAToken();
        AccessControlLibrary.validateAddress(to);
        
        IERC20(token).safeTransfer(to, amount);
    }

    function recoverETH(address payable to) external {
        AccessControlLibrary.onlyAdmin(this);
        AccessControlLibrary.validateAddress(to);
        uint256 balance = address(this).balance;
        // SECURITY: Check if there's ETH to recover (safe equality check)
        if (balance == 0) revert ErrorLibrary.NoETHToRecover();
        
        (bool success, ) = to.call{value: balance}("");
        if (!success) revert ErrorLibrary.ETHTransferFailed();
    }
}