// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../interfaces/IYieldShift.sol";
import "../../libraries/VaultMath.sol";

/**
 * @title AaveVault
 * @notice Manages Aave V3 integration for yield-bearing USDC deposits
 * @dev Implements the aQEURO variant - QEURO backed by yield-bearing Aave deposits
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */

// Aave V3 interfaces
interface IPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function getReserveData(address asset) external view returns (ReserveData memory);
    function getUserAccountData(address user) external view returns (
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 availableBorrowsBase,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    );
}

interface IPoolAddressesProvider {
    function getPool() external view returns (address);
    function getPriceOracle() external view returns (address);
}

interface IRewardsController {
    function claimRewards(
        address[] calldata assets,
        uint256 amount,
        address to
    ) external returns (uint256);
    
    function getUserRewards(
        address[] calldata assets,
        address user
    ) external view returns (uint256[] memory);
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


contract AaveVault is 
    Initializable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;
    using VaultMath for uint256;

    // =============================================================================
    // CONSTANTS AND ROLES
    // =============================================================================
    
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // =============================================================================
    // STATE VARIABLES
    // =============================================================================
    
    /// @notice USDC token contract
    IERC20 public usdc;
    
    /// @notice aUSDC token contract (Aave interest-bearing USDC)
    IERC20 public aUSDC;
    
    /// @notice Aave V3 Pool contract
    IPool public aavePool;
    
    /// @notice Aave V3 Pool Addresses Provider
    IPoolAddressesProvider public aaveProvider;
    
    /// @notice Aave Rewards Controller
    IRewardsController public rewardsController;
    
    /// @notice Yield Shift mechanism
    IYieldShift public yieldShift;

    // Vault configuration
    uint256 public maxAaveExposure;         // Maximum USDC that can be deployed to Aave
    uint256 public harvestThreshold;        // Minimum yield to trigger harvest
    uint256 public yieldFee;                // Protocol fee on yield (basis points)
    uint256 public rebalanceThreshold;      // Threshold for automatic rebalancing
    
    // Position tracking
    uint256 public principalDeposited;      // Original USDC deposited to Aave
    uint256 public lastHarvestTime;         // Last yield harvest timestamp
    uint256 public totalYieldHarvested;     // Cumulative yield harvested
    uint256 public totalFeesCollected;      // Cumulative protocol fees
    
    // Risk management
    uint256 public utilizationLimit;        // Max utilization rate to maintain (95%)
    uint256 public emergencyExitThreshold;  // Health factor below which to exit
    bool public emergencyMode;              // Emergency mode flag
    
    // Historical tracking for analytics
    struct YieldSnapshot {
        uint256 timestamp;
        uint256 aaveBalance;
        uint256 yieldEarned;
        uint256 aaveAPY;
    }
    
    YieldSnapshot[] public yieldHistory;
    uint256 public constant MAX_YIELD_HISTORY = 365; // 1 year of daily snapshots
    uint256 public constant MAX_TIME_ELAPSED = 365 days; // Maximum time elapsed for calculations

    // =============================================================================
    // EVENTS
    // =============================================================================
    
    event DeployedToAave(uint256 amount, uint256 aTokensReceived, uint256 newBalance);
    event WithdrawnFromAave(uint256 amountRequested, uint256 amountWithdrawn, uint256 newBalance);
    event AaveYieldHarvested(uint256 yieldHarvested, uint256 protocolFee, uint256 netYield);
    event AaveRewardsClaimed(address indexed rewardToken, uint256 rewardAmount, address recipient);
    event PositionRebalanced(uint256 oldAllocation, uint256 newAllocation, string reason);
    event AaveParameterUpdated(string parameter, uint256 oldValue, uint256 newValue);
    event EmergencyWithdrawal(uint256 amountWithdrawn, string reason, uint256 timestamp);
    event EmergencyModeToggled(bool enabled, string reason);

    // =============================================================================
    // INITIALIZER
    // =============================================================================

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin,
        address _usdc,
        address _aaveProvider,
        address _rewardsController,
        address _yieldShift
    ) public initializer {
        require(admin != address(0), "AaveVault: Admin cannot be zero");
        require(_usdc != address(0), "AaveVault: USDC cannot be zero");
        require(_aaveProvider != address(0), "AaveVault: Aave provider cannot be zero");
        require(_yieldShift != address(0), "AaveVault: YieldShift cannot be zero");

        __ReentrancyGuard_init();
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(VAULT_MANAGER_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        usdc = IERC20(_usdc);
        aaveProvider = IPoolAddressesProvider(_aaveProvider);
        aavePool = IPool(aaveProvider.getPool());
        rewardsController = IRewardsController(_rewardsController);
        yieldShift = IYieldShift(_yieldShift);

        // Get aUSDC token address from Aave
        ReserveData memory reserveData = aavePool.getReserveData(address(usdc));
        aUSDC = IERC20(reserveData.aTokenAddress);

        // Default configuration
        maxAaveExposure = 50_000_000e6;     // 50M USDC max exposure
        harvestThreshold = 1000e6;          // 1000 USDC minimum to harvest
        yieldFee = 1000;                    // 10% protocol fee on yield
        rebalanceThreshold = 500;           // 5% threshold for rebalancing
        utilizationLimit = 9500;            // 95% max utilization
        emergencyExitThreshold = 110;       // Exit if health factor < 1.1
        
        lastHarvestTime = block.timestamp;
    }

    // =============================================================================
    // CORE AAVE INTEGRATION FUNCTIONS
    // =============================================================================

    /**
     * @notice Deploy USDC to Aave V3 pool to earn yield
     */
    function deployToAave(uint256 amount) 
        external 
        onlyRole(VAULT_MANAGER_ROLE) 
        nonReentrant 
        whenNotPaused 
        returns (uint256 aTokensReceived) 
    {
        require(amount > 0, "AaveVault: Amount must be positive");
        require(!emergencyMode, "AaveVault: Emergency mode active");
        
        // Check exposure limits
        uint256 newTotalDeposit = principalDeposited + amount;
        require(newTotalDeposit <= maxAaveExposure, "AaveVault: Would exceed max exposure");
        
        // Check Aave pool health
        require(_isAaveHealthy(), "AaveVault: Aave pool not healthy");
        
        uint256 balanceBefore = aUSDC.balanceOf(address(this));
        
        // Transfer USDC from sender
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        
        // Approve Aave pool to spend USDC
        usdc.safeIncreaseAllowance(address(aavePool), amount);
        
        // Supply USDC to Aave pool
        aavePool.supply(address(usdc), amount, address(this), 0);
        
        uint256 balanceAfter = aUSDC.balanceOf(address(this));
        aTokensReceived = balanceAfter - balanceBefore;
        
        // Update tracking
        principalDeposited += amount;
        
        // Record snapshot
        _recordYieldSnapshot();
        
        emit DeployedToAave(amount, aTokensReceived, balanceAfter);
    }

    /**
     * @notice Withdraw USDC from Aave V3 pool
     * @dev Includes comprehensive validation and proper accounting of actual amounts received
     * 

     */
    function withdrawFromAave(uint256 amount) 
        external 
        onlyRole(VAULT_MANAGER_ROLE) 
        nonReentrant 
        returns (uint256 usdcWithdrawn) 
    {
        require(amount > 0, "AaveVault: Amount must be positive");
        
        uint256 aaveBalance = aUSDC.balanceOf(address(this));
        require(aaveBalance > 0, "AaveVault: No Aave balance");
        
        // Determine actual withdrawal amount
        uint256 withdrawAmount = amount;
        if (amount == type(uint256).max) {
            withdrawAmount = aaveBalance;
        }
        
        require(withdrawAmount <= aaveBalance, "AaveVault: Insufficient Aave balance");
        
        // Check if withdrawal maintains minimum liquidity
        if (!emergencyMode) {
            uint256 remainingBalance = aaveBalance - withdrawAmount;
            uint256 minBalance = principalDeposited.mulDiv(rebalanceThreshold, 10000);
            require(remainingBalance >= minBalance, "AaveVault: Would breach minimum balance");
        }
        
        uint256 usdcBefore = usdc.balanceOf(address(this));
        
        // Calculate expected amount (accounting for potential slippage)
        uint256 expectedAmount = withdrawAmount;
        
        // Withdraw from Aave
        usdcWithdrawn = aavePool.withdraw(address(usdc), withdrawAmount, address(this));
        
        uint256 usdcAfter = usdc.balanceOf(address(this));
        uint256 actualWithdrawn = usdcAfter - usdcBefore;
        
        // SECURITY FIX: Validate withdrawal amount based on request type
        if (amount != type(uint256).max) {
            // For specific amounts, ensure we got what we asked for (99% minimum)
            require(
                actualWithdrawn >= withdrawAmount.mulDiv(9900, 10000),
                "AaveVault: Insufficient withdrawal - received less than requested"
            );
        } else {
            // For max withdrawals, only check for reasonable slippage (95% minimum)
            require(
                actualWithdrawn >= expectedAmount.mulDiv(9500, 10000),
                "AaveVault: Excessive slippage on max withdrawal"
            );
        }
        
        // Update tracking based on actual amount received, not requested amount
        uint256 principalWithdrawn = VaultMath.min(actualWithdrawn, principalDeposited);
        principalDeposited -= principalWithdrawn;
        
        // Record snapshot
        _recordYieldSnapshot();
        
        emit WithdrawnFromAave(amount, actualWithdrawn, aUSDC.balanceOf(address(this)));
    }

    /**
     * @notice Claim Aave rewards (if any)
     */
    function claimAaveRewards() 
        external 
        onlyRole(VAULT_MANAGER_ROLE) 
        nonReentrant 
        returns (uint256 rewardsClaimed) 
    {
        address[] memory assets = new address[](1);
        assets[0] = address(aUSDC);
        
        // Get pending rewards
        uint256[] memory pendingRewards = rewardsController.getUserRewards(assets, address(this));
        
        if (pendingRewards.length > 0 && pendingRewards[0] > 0) {
            // Claim rewards
            rewardsClaimed = rewardsController.claimRewards(assets, pendingRewards[0], address(this));
            
            emit AaveRewardsClaimed(address(0), rewardsClaimed, address(this)); // Generic reward token
        }
    }

    // =============================================================================
    // YIELD MANAGEMENT
    // =============================================================================

    /**
     * @notice Harvest Aave yield and distribute to protocol
     * @dev Includes slippage protection for yield withdrawals
     * 

     */
    function harvestAaveYield() 
        external 
        onlyRole(VAULT_MANAGER_ROLE) 
        nonReentrant 
        returns (uint256 yieldHarvested) 
    {
        uint256 availableYield = getAvailableYield();
        require(availableYield >= harvestThreshold, "AaveVault: Yield below threshold");
        
        // Calculate protocol fee
        uint256 protocolFee = availableYield.mulDiv(yieldFee, 10000);
        uint256 netYield = availableYield - protocolFee;
        
        // SECURITY FIX: Track actual withdrawn amount for slippage protection
        uint256 usdcBefore = usdc.balanceOf(address(this));
        
        // Withdraw yield from Aave
        aavePool.withdraw(address(usdc), availableYield, address(this));
        
        uint256 usdcAfter = usdc.balanceOf(address(this));
        uint256 actualYieldReceived = usdcAfter - usdcBefore;
        
        // SECURITY FIX: Verify yield withdrawal with slippage protection (99% minimum)
        require(
            actualYieldReceived >= availableYield.mulDiv(9900, 10000),
            "AaveVault: Excessive yield slippage"
        );
        
        // Update tracking based on actual amount received
        totalYieldHarvested += actualYieldReceived;
        totalFeesCollected += protocolFee;
        lastHarvestTime = block.timestamp;
        
        // Distribute yield via YieldShift (based on actual yield received)
        if (netYield > 0) {
            usdc.safeIncreaseAllowance(address(yieldShift), netYield);
            yieldShift.addYield(netYield, "aave");
        }
        
        // Record snapshot
        _recordYieldSnapshot();
        
        emit AaveYieldHarvested(actualYieldReceived, protocolFee, netYield);
        
        yieldHarvested = actualYieldReceived;
    }

    /**
     * @notice Calculate available yield for harvest
     */
    function getAvailableYield() public view returns (uint256) {
        uint256 currentBalance = aUSDC.balanceOf(address(this));
        
        if (currentBalance <= principalDeposited) {
            return 0; // No yield if balance <= principal
        }
        
        return currentBalance - principalDeposited;
    }

    /**
     * @notice Get yield distribution breakdown
     */
    function getYieldDistribution() external view returns (
        uint256 protocolYield,
        uint256 userYield,
        uint256 hedgerYield
    ) {
        uint256 availableYield = getAvailableYield();
        protocolYield = availableYield.mulDiv(yieldFee, 10000);
        uint256 netYield = availableYield - protocolYield;
        
        // Get current yield shift to determine user vs hedger allocation
        uint256 yieldShiftPct = yieldShift.getCurrentYieldShift();
        userYield = netYield.mulDiv(yieldShiftPct, 10000);
        hedgerYield = netYield - userYield;
    }

    // =============================================================================
    // AAVE POSITION INFORMATION
    // =============================================================================

    function getAaveBalance() external view returns (uint256) {
        return aUSDC.balanceOf(address(this));
    }

    function getAccruedInterest() external view returns (uint256) {
        return getAvailableYield();
    }

    function getAaveAPY() external view returns (uint256) {
        ReserveData memory reserveData = aavePool.getReserveData(address(usdc));
        
        // Convert Aave rate to APY in basis points
        // Aave rate is in ray (27 decimals), convert to basis points
        return uint256(reserveData.currentLiquidityRate) / 1e23; // 27 - 4 = 23 decimals
    }

    function getAavePositionDetails() external view returns (
        uint256 principalDeposited_,
        uint256 currentBalance,
        uint256 aTokenBalance,
        uint256 lastUpdateTime
    ) {
        principalDeposited_ = principalDeposited;
        aTokenBalance = aUSDC.balanceOf(address(this));
        currentBalance = aTokenBalance; // aTokens are 1:1 redeemable for underlying + interest
        lastUpdateTime = lastHarvestTime;
    }

    // =============================================================================
    // AAVE MARKET INFORMATION
    // =============================================================================

    function getAaveMarketData() external view returns (
        uint256 supplyRate,
        uint256 utilizationRate,
        uint256 totalSupply,
        uint256 availableLiquidity
    ) {
        ReserveData memory reserveData = aavePool.getReserveData(address(usdc));
        
        supplyRate = uint256(reserveData.currentLiquidityRate) / 1e23;
        
        // Get total supply and available liquidity from USDC contract
        totalSupply = usdc.totalSupply();
        availableLiquidity = usdc.balanceOf(address(aavePool));
        
        // Calculate utilization rate
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
            // Check if reserve is active and not frozen
            // This is a simplified check - in production, decode configuration properly
            return reserveData.aTokenAddress != address(0);
        } catch {
            return false;
        }
    }

    // =============================================================================
    // AUTOMATIC STRATEGIES
    // =============================================================================

    function autoRebalance() 
        external 
        onlyRole(VAULT_MANAGER_ROLE) 
        returns (bool rebalanced, uint256 newAllocation) 
    {
        (uint256 optimalAllocation, ) = this.calculateOptimalAllocation();
        uint256 currentBalance = aUSDC.balanceOf(address(this));
        uint256 totalAssets = currentBalance + usdc.balanceOf(address(this));
        
        if (totalAssets == 0) return (false, 0);
        
        uint256 currentAllocation = currentBalance.mulDiv(10000, totalAssets);
        uint256 allocationDiff = optimalAllocation > currentAllocation ?
            optimalAllocation - currentAllocation :
            currentAllocation - optimalAllocation;
        
        // Only rebalance if difference is significant
        if (allocationDiff >= rebalanceThreshold) {
            // Implementation would depend on specific rebalancing logic
            rebalanced = true;
            newAllocation = optimalAllocation;
            
            emit PositionRebalanced(currentAllocation, newAllocation, "Auto rebalance");
        }
    }

    function calculateOptimalAllocation() external view returns (
        uint256 optimalAllocation,
        uint256 expectedYield
    ) {
        // Get current Aave APY
        uint256 aaveAPY = this.getAaveAPY();
        
        // Get market utilization (only need APY for calculation)
        this.getAaveMarketData();
        
        // Calculate optimal allocation based on:
        // 1. Aave APY (higher = more allocation)
        // 2. Utilization rate (lower = safer, more allocation)
        // 3. Available liquidity (higher = more allocation possible)
        
        // Simple heuristic: allocate more when APY is high
        if (aaveAPY >= 300) { // 3% APY
            optimalAllocation = 8000; // 80% allocation
        } else if (aaveAPY >= 200) { // 2% APY
            optimalAllocation = 6000; // 60% allocation
        } else {
            optimalAllocation = 4000; // 40% allocation (conservative)
        }
        
        expectedYield = aaveAPY;
    }

    // =============================================================================
    // RISK MANAGEMENT
    // =============================================================================

    function setMaxAaveExposure(uint256 _maxExposure) 
        external 
        onlyRole(GOVERNANCE_ROLE) 
    {
        require(_maxExposure > 0, "AaveVault: Max exposure must be positive");
        require(_maxExposure <= 1_000_000_000e6, "AaveVault: Max exposure too high"); // 1B USDC max
        
        emit AaveParameterUpdated("maxAaveExposure", maxAaveExposure, _maxExposure);
        maxAaveExposure = _maxExposure;
    }

    /**
     * @notice Emergency withdrawal from Aave
     * @dev Includes proper accounting of actual amounts received during emergency
     */
    function emergencyWithdrawFromAave() 
        external 
        onlyRole(EMERGENCY_ROLE) 
        returns (uint256 amountWithdrawn) 
    {
        uint256 aaveBalance = aUSDC.balanceOf(address(this));
        
        if (aaveBalance > 0) {
            emergencyMode = true;
            
            uint256 usdcBefore = usdc.balanceOf(address(this));
            
            // Withdraw everything from Aave
            aavePool.withdraw(address(usdc), type(uint256).max, address(this));
            
            uint256 usdcAfter = usdc.balanceOf(address(this));
            amountWithdrawn = usdcAfter - usdcBefore;
            
            // Update tracking based on actual amount received
            uint256 principalWithdrawn = VaultMath.min(amountWithdrawn, principalDeposited);
            principalDeposited -= principalWithdrawn;
            
            emit EmergencyWithdrawal(amountWithdrawn, "Emergency exit from Aave", block.timestamp);
            emit EmergencyModeToggled(true, "Emergency withdrawal executed");
        }
    }

    function getRiskMetrics() external view returns (
        uint256 exposureRatio,
        uint256 concentrationRisk,
        uint256 liquidityRisk
    ) {
        uint256 aaveBalance = aUSDC.balanceOf(address(this));
        uint256 totalAssets = aaveBalance + usdc.balanceOf(address(this));
        
        // Exposure ratio: percentage of assets in Aave
        exposureRatio = totalAssets > 0 ? aaveBalance.mulDiv(10000, totalAssets) : 0;
        
        // Concentration risk: high if too much in Aave
        concentrationRisk = exposureRatio > 8000 ? 3 : exposureRatio > 6000 ? 2 : 1; // 1=low, 2=medium, 3=high
        
        // Liquidity risk: based on Aave utilization
        (, uint256 utilizationRate, , ) = this.getAaveMarketData();
        liquidityRisk = utilizationRate > 9500 ? 3 : utilizationRate > 9000 ? 2 : 1;
    }

    // =============================================================================
    // CONFIGURATION
    // =============================================================================

    function updateAaveParameters(
        uint256 newHarvestThreshold,
        uint256 newYieldFee,
        uint256 newRebalanceThreshold
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(newYieldFee <= 2000, "AaveVault: Yield fee too high"); // Max 20%
        require(newRebalanceThreshold <= 2000, "AaveVault: Rebalance threshold too high"); // Max 20%
        
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

    function toggleEmergencyMode(bool enabled, string calldata reason) 
        external 
        onlyRole(EMERGENCY_ROLE) 
    {
        emergencyMode = enabled;
        emit EmergencyModeToggled(enabled, reason);
    }

    // =============================================================================
    // HISTORICAL DATA
    // =============================================================================

    function _recordYieldSnapshot() internal {
        uint256 aaveBalance = aUSDC.balanceOf(address(this));
        uint256 yieldEarned = getAvailableYield();
        uint256 currentAPY = this.getAaveAPY();
        
        uint256 length = yieldHistory.length; // Cache length
        
        // Remove oldest snapshot if at capacity
        if (length >= MAX_YIELD_HISTORY) {
            for (uint256 i = 0; i < length - 1; i++) {
                yieldHistory[i] = yieldHistory[i + 1];
            }
            yieldHistory.pop();
        }
        
        yieldHistory.push(YieldSnapshot({
            timestamp: block.timestamp,
            aaveBalance: aaveBalance,
            yieldEarned: yieldEarned,
            aaveAPY: currentAPY
        }));
    }

    function getHistoricalYield(uint256 period) external view returns (
        uint256 averageYield,
        uint256 maxYield,
        uint256 minYield,
        uint256 yieldVolatility
    ) {
        uint256 length = yieldHistory.length; // Cache length
        if (length == 0) {
            return (0, 0, 0, 0);
        }
        
        uint256 cutoffTime = block.timestamp - period;
        
        // Bounds check: prevent manipulation by ensuring reasonable cutoff time
        if (cutoffTime > block.timestamp) {
            cutoffTime = 0; // Prevent underflow
        }
        
        // Additional bounds check: cap period to prevent excessive calculations
        if (period > MAX_TIME_ELAPSED) {
            cutoffTime = block.timestamp - MAX_TIME_ELAPSED;
        }
        
        // SECURITY FIX: Gas Optimization - Batch Data Loading
        // First, collect valid snapshots in memory to reduce storage reads
        uint256[] memory validYields = new uint256[](length);
        uint256 validCount = 0;
        
        for (uint256 i = 0; i < length; i++) {
            YieldSnapshot memory snapshot = yieldHistory[i]; // Load once
            if (snapshot.timestamp >= cutoffTime) {
                validYields[validCount] = snapshot.aaveAPY;
                validCount++;
            }
        }
        
        if (validCount == 0) {
            return (0, 0, 0, 0);
        }
        
        // Process in memory to avoid repeated storage reads
        uint256 sumYield = 0;
        maxYield = 0;
        minYield = type(uint256).max;
        
        for (uint256 i = 0; i < validCount; i++) {
            uint256 yield = validYields[i];
            sumYield += yield;
            if (yield > maxYield) maxYield = yield;
            if (yield < minYield) minYield = yield;
        }
        
        averageYield = sumYield / validCount;
        
        // Calculate volatility (simplified standard deviation) using cached data
        uint256 sumSquaredDeviations = 0;
        for (uint256 i = 0; i < validCount; i++) {
            uint256 yield = validYields[i];
            uint256 deviation = yield > averageYield ? 
                yield - averageYield : averageYield - yield;
            sumSquaredDeviations += deviation * deviation;
        }
        
        yieldVolatility = validCount > 1 ? 
            sumSquaredDeviations / (validCount - 1) : 0;
    }

    // =============================================================================
    // EMERGENCY AND ADMIN
    // =============================================================================

    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) 
        internal 
        override 
        onlyRole(UPGRADER_ROLE) 
    {}

    /**
     * @notice Recover accidentally sent tokens
     */
    function recoverToken(address token, address to, uint256 amount) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(token != address(usdc), "AaveVault: Cannot recover USDC");
        require(token != address(aUSDC), "AaveVault: Cannot recover aUSDC");
        require(to != address(0), "AaveVault: Cannot send to zero address");
        
        IERC20(token).safeTransfer(to, amount);
    }
}