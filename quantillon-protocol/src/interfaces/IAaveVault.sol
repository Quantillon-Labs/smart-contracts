// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IAaveVault
 * @notice Interface for the AaveVault (Aave V3 USDC yield vault)
 * @dev Mirrors the external/public API of `src/core/vaults/AaveVault.sol`
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
interface IAaveVault {
    /**
     * @notice Initializes the Aave vault
     * @param admin Admin address
     * @param _usdc USDC token address
     * @param _aaveProvider Aave PoolAddressesProvider
     * @param _rewardsController Aave RewardsController address
     * @param _yieldShift YieldShift contract address
     */
    function initialize(
        address admin,
        address _usdc,
        address _aaveProvider,
        address _rewardsController,
        address _yieldShift
    ) external;

    /**
     * @notice Deploy USDC to Aave V3 pool to earn yield
     * @param amount USDC amount to supply
     * @return aTokensReceived Amount of aUSDC received
     */
    function deployToAave(uint256 amount) external returns (uint256 aTokensReceived);

    /**
     * @notice Withdraw USDC from Aave V3 pool
     * @param amount Amount of aUSDC to withdraw (use type(uint256).max for all)
     * @return usdcWithdrawn Amount of USDC actually withdrawn
     */
    function withdrawFromAave(uint256 amount) external returns (uint256 usdcWithdrawn);

    /**
     * @notice Claim Aave rewards (if any)
     * @return rewardsClaimed Claimed reward amount
     */
    function claimAaveRewards() external returns (uint256 rewardsClaimed);

    /**
     * @notice Harvest Aave yield and distribute via YieldShift
     * @return yieldHarvested Amount harvested
     */
    function harvestAaveYield() external returns (uint256 yieldHarvested);

    /**
     * @notice Calculate available yield for harvest
     * @return available Amount of yield available
     */
    function getAvailableYield() external view returns (uint256 available);

    /**
     * @notice Get yield distribution breakdown for current state
     * @return protocolYield Protocol fee portion
     * @return userYield Allocation to users
     * @return hedgerYield Allocation to hedgers
     */
    function getYieldDistribution() external view returns (
        uint256 protocolYield,
        uint256 userYield,
        uint256 hedgerYield
    );

    /**
     * @notice Current aUSDC balance of the vault
     */
    function getAaveBalance() external view returns (uint256);

    /**
     * @notice Accrued interest (same as available yield)
     */
    function getAccruedInterest() external view returns (uint256);

    /**
     * @notice Historical yield data for a given period
     * @param period Time period in seconds
     * @return totalYield Total yield generated over period
     * @return averageAPY Average APY over period
     * @return maxAPY Maximum APY over period
     * @return minAPY Minimum APY over period
     */
    function getHistoricalYield(uint256 period) external view returns (
        uint256 totalYield,
        uint256 averageAPY,
        uint256 maxAPY,
        uint256 minAPY
    );

    /**
     * @notice Current Aave APY in basis points
     */
    function getAaveAPY() external view returns (uint256);

    /**
     * @notice Aave position details snapshot
     * @return principalDeposited_ Principal USDC supplied
     * @return currentBalance Current aUSDC balance (1:1 underlying + interest)
     * @return aTokenBalance Alias for aUSDC balance
     * @return lastUpdateTime Timestamp of last harvest
     */
    function getAavePositionDetails() external view returns (
        uint256 principalDeposited_,
        uint256 currentBalance,
        uint256 aTokenBalance,
        uint256 lastUpdateTime
    );

    /**
     * @notice Aave market data snapshot
     * @return supplyRate Current supply rate (bps)
     * @return utilizationRate Utilization rate (bps)
     * @return totalSupply USDC total supply
     * @return availableLiquidity Available USDC liquidity in Aave pool
     */
    function getAaveMarketData() external view returns (
        uint256 supplyRate,
        uint256 utilizationRate,
        uint256 totalSupply,
        uint256 availableLiquidity
    );

    /**
     * @notice Basic Aave pool health and pause state
     * @return isHealthy True if pool considered healthy
     * @return pauseStatus Whether vault is paused
     * @return lastUpdate Last harvest time
     */
    function checkAaveHealth() external view returns (
        bool isHealthy,
        bool pauseStatus,
        uint256 lastUpdate
    );

    /**
     * @notice Attempt auto-rebalancing allocation
     * @return rebalanced Whether a rebalance decision was made
     * @return newAllocation New target allocation (bps)
     */
    function autoRebalance() external returns (bool rebalanced, uint256 newAllocation);

    /**
     * @notice Compute optimal allocation and expected yield
     * @return optimalAllocation Target allocation (bps)
     * @return expectedYield Expected yield proxy
     */
    function calculateOptimalAllocation() external view returns (uint256 optimalAllocation, uint256 expectedYield);

    /**
     * @notice Update max exposure to Aave
     * @param _maxExposure New max USDC exposure
     */
    function setMaxAaveExposure(uint256 _maxExposure) external;

    /**
     * @notice Emergency: withdraw all from Aave
     * @return amountWithdrawn Amount withdrawn
     */
    function emergencyWithdrawFromAave() external returns (uint256 amountWithdrawn);

    /**
     * @notice Risk metrics snapshot
     * @return exposureRatio % of assets in Aave (bps)
     * @return concentrationRisk Heuristic risk score (1-3)
     * @return liquidityRisk Heuristic risk score (1-3)
     */
    function getRiskMetrics() external view returns (uint256 exposureRatio, uint256 concentrationRisk, uint256 liquidityRisk);

    /**
     * @notice Update vault parameters
     * @param newHarvestThreshold Min yield to harvest
     * @param newYieldFee Protocol fee on yield (bps)
     * @param newRebalanceThreshold Rebalance threshold (bps)
     */
    function updateAaveParameters(uint256 newHarvestThreshold, uint256 newYieldFee, uint256 newRebalanceThreshold) external;

    /**
     * @notice Aave config snapshot
     * @return aavePool_ Aave Pool address
     * @return aUSDC_ aUSDC token address
     * @return harvestThreshold_ Current harvest threshold
     * @return yieldFee_ Current yield fee (bps)
     * @return maxExposure_ Max Aave exposure
     */
    function getAaveConfig() external view returns (
        address aavePool_,
        address aUSDC_,
        uint256 harvestThreshold_,
        uint256 yieldFee_,
        uint256 maxExposure_
    );

    /**
     * @notice Toggle emergency mode
     * @param enabled New emergency flag
     * @param reason Reason string
     */
    function toggleEmergencyMode(bool enabled, string calldata reason) external;

    /**
     * @notice Pause the vault
     */
    function pause() external;

    /**
     * @notice Unpause the vault
     */
    function unpause() external;

    /**
     * @notice Recover ERC20 tokens sent by mistake
     * @param token Token address
     * @param to Recipient
     * @param amount Amount to transfer
     */
    function recoverToken(address token, address to, uint256 amount) external;

    /**
     * @notice Recover ETH sent by mistake
     * @param to Recipient
     */
    function recoverETH(address payable to) external;

    // AccessControl functions
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address callerConfirmation) external;

    // Pausable functions
    function paused() external view returns (bool);

    // UUPS functions
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;

    // Constants
    function GOVERNANCE_ROLE() external view returns (bytes32);
    function VAULT_MANAGER_ROLE() external view returns (bytes32);
    function EMERGENCY_ROLE() external view returns (bytes32);
    function UPGRADER_ROLE() external view returns (bytes32);
    function MAX_YIELD_HISTORY() external view returns (uint256);
    function MAX_TIME_ELAPSED() external view returns (uint256);

    // State variables
    function usdc() external view returns (address);
    function aUSDC() external view returns (address);
    function aavePool() external view returns (address);
    function aaveProvider() external view returns (address);
    function rewardsController() external view returns (address);
    function yieldShift() external view returns (address);
    function maxAaveExposure() external view returns (uint256);
    function harvestThreshold() external view returns (uint256);
    function yieldFee() external view returns (uint256);
    function rebalanceThreshold() external view returns (uint256);
    function principalDeposited() external view returns (uint256);
    function lastHarvestTime() external view returns (uint256);
    function totalYieldHarvested() external view returns (uint256);
    function totalFeesCollected() external view returns (uint256);
    function utilizationLimit() external view returns (uint256);
    function emergencyExitThreshold() external view returns (uint256);
    function emergencyMode() external view returns (bool);
    function yieldHistory(uint256) external view returns (
        uint256 timestamp,
        uint256 aaveBalance,
        uint256 yieldEarned,
        uint256 aaveAPY
    );
}
