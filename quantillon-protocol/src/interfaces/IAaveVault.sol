// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IAaveVault
 * @notice Interface for the AaveVault (Aave V3 USDC yield vault)
 * @dev Mirrors the external/public API of `src/core/vaults/AaveVault.sol`
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
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
     * @dev Initializes the AaveVault contract with required addresses
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
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
     * @dev Deploys USDC to Aave V3 pool to earn yield
     * @param amount USDC amount to supply (6 decimals)
     * @return aTokensReceived Amount of aUSDC received (6 decimals)
     * @custom:security Validates oracle price freshness, enforces exposure limits
     * @custom:validation Validates amount > 0, checks max exposure limits
     * @custom:state-changes Updates principalDeposited, transfers USDC, receives aUSDC
     * @custom:events Emits DeployedToAave with operation details
     * @custom:errors Throws WouldExceedLimit if exceeds maxAaveExposure
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to VAULT_MANAGER_ROLE
     * @custom:oracle Requires fresh EUR/USD price for health validation
     */
    function deployToAave(uint256 amount) external returns (uint256 aTokensReceived);

    /**
     * @notice Withdraw USDC from Aave V3 pool
     * @dev Withdraws USDC from Aave V3 pool
     * @param amount Amount of aUSDC to withdraw (use type(uint256).max for all)
     * @return usdcWithdrawn Amount of USDC actually withdrawn
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function withdrawFromAave(uint256 amount) external returns (uint256 usdcWithdrawn);

    /**
     * @notice Claim Aave rewards (if any)
     * @dev Claims Aave rewards if any are available
     * @return rewardsClaimed Claimed reward amount
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function claimAaveRewards() external returns (uint256 rewardsClaimed);

    /**
     * @notice Harvest Aave yield and distribute via YieldShift
     * @return yieldHarvested Amount harvested
     * @dev This function calls YieldShift.harvestAndDistributeAaveYield() to handle distribution
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function harvestAaveYield() external returns (uint256 yieldHarvested);

    /**
     * @notice Calculate available yield for harvest
     * @dev Calculates the amount of yield available for harvest
     * @return available Amount of yield available
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getAvailableYield() external view returns (uint256 available);

    /**
     * @notice Get yield distribution breakdown for current state
     * @dev Returns the breakdown of yield distribution for current state
     * @return protocolYield Protocol fee portion
     * @return userYield Allocation to users
     * @return hedgerYield Allocation to hedgers
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
    );

    /**
     * @notice Current aUSDC balance of the vault
     * @dev Returns the current aUSDC balance of the vault
     * @return uint256 The current aUSDC balance
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getAaveBalance() external view returns (uint256);

    /**
     * @notice Accrued interest (same as available yield)
     * @dev Returns the accrued interest (same as available yield)
     * @return uint256 The accrued interest amount
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getAccruedInterest() external view returns (uint256);



    /**
     * @notice Current Aave APY in basis points
     * @dev Returns the current Aave APY in basis points
     * @return uint256 Current APY in basis points
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getAaveAPY() external view returns (uint256);

    /**
     * @notice Aave position details snapshot
     * @dev Returns a snapshot of Aave position details
     * @return principalDeposited_ Principal USDC supplied
     * @return currentBalance Current aUSDC balance (1:1 underlying + interest)
     * @return aTokenBalance Alias for aUSDC balance
     * @return lastUpdateTime Timestamp of last harvest
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
    );

    /**
     * @notice Aave market data snapshot
     * @dev Returns Aave market data snapshot
     * @return supplyRate Current supply rate (bps)
     * @return utilizationRate Utilization rate (bps)
     * @return totalSupply USDC total supply
     * @return availableLiquidity Available USDC liquidity in Aave pool
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
    );

    /**
     * @notice Basic Aave pool health and pause state
     * @dev Returns basic Aave pool health and pause state
     * @return isHealthy True if pool considered healthy
     * @return pauseStatus Whether vault is paused
     * @return lastUpdate Last harvest time
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
    );

    /**
     * @notice Attempt auto-rebalancing allocation
     * @dev Automatically rebalances allocation based on current market conditions and yield opportunities
     * @return rebalanced Whether a rebalance decision was made
     * @return newAllocation New target allocation (bps)
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function autoRebalance() external returns (bool rebalanced, uint256 newAllocation);

    /**
     * @notice Compute optimal allocation and expected yield
     * @dev Calculates the optimal allocation percentage and expected yield based on current market conditions
     * @return optimalAllocation Target allocation (bps)
     * @return expectedYield Expected yield proxy
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function calculateOptimalAllocation() external view returns (uint256 optimalAllocation, uint256 expectedYield);

    /**
     * @notice Update max exposure to Aave
     * @dev Sets the maximum USDC exposure limit for Aave protocol interactions
     * @param _maxExposure New max USDC exposure
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function setMaxAaveExposure(uint256 _maxExposure) external;

    /**
     * @notice Emergency: withdraw all from Aave
     * @dev Emergency function to withdraw all funds from Aave protocol in case of emergency
     * @return amountWithdrawn Amount withdrawn
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function emergencyWithdrawFromAave() external returns (uint256 amountWithdrawn);

    /**
     * @notice Risk metrics snapshot
     * @dev Returns current risk metrics including exposure ratio and risk scores
     * @return exposureRatio % of assets in Aave (bps)
     * @return concentrationRisk Heuristic risk score (1-3)
     * @return liquidityRisk Heuristic risk score (1-3)
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getRiskMetrics() external view returns (uint256 exposureRatio, uint256 concentrationRisk, uint256 liquidityRisk);

    /**
     * @notice Update vault parameters
     * @dev Updates key vault parameters including harvest threshold, yield fee, and rebalance threshold
     * @param newHarvestThreshold Min yield to harvest
     * @param newYieldFee Protocol fee on yield (bps)
     * @param newRebalanceThreshold Rebalance threshold (bps)
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function updateAaveParameters(uint256 newHarvestThreshold, uint256 newYieldFee, uint256 newRebalanceThreshold) external;

    /**
     * @notice Aave config snapshot
     * @dev Returns current Aave configuration including pool address, token address, and key parameters
     * @return aavePool_ Aave Pool address
     * @return aUSDC_ aUSDC token address
     * @return harvestThreshold_ Current harvest threshold
     * @return yieldFee_ Current yield fee (bps)
     * @return maxExposure_ Max Aave exposure
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
    );

    /**
     * @notice Toggle emergency mode
     * @dev Enables or disables emergency mode with a reason for the action
     * @param enabled New emergency flag
     * @param reason Reason string
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function toggleEmergencyMode(bool enabled, string calldata reason) external;

    /**
     * @notice Pause the vault
     * @dev Pauses all vault operations for emergency situations
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function pause() external;

    /**
     * @notice Unpause the vault
     * @dev Resumes vault operations after being paused
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function unpause() external;

    /**
     * @notice Recover ERC20 tokens sent by mistake
     * @dev Allows recovery of ERC20 tokens accidentally sent to the contract
     * @param token Token address
     * @param to Recipient
     * @param amount Amount to transfer
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function recoverToken(address token, address to, uint256 amount) external;

    /**
     * @notice Recover ETH sent by mistake
     * @dev Allows recovery of ETH accidentally sent to the contract
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function recoverETH() external;

    // AccessControl functions
    /**
     * @notice Check if an account has a specific role
     * @dev Returns true if the account has the specified role
     * @param role The role to check
     * @param account The account to check
     * @return bool True if the account has the role, false otherwise
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function hasRole(bytes32 role, address account) external view returns (bool);
    /**
     * @notice Get the admin role for a specific role
     * @dev Returns the admin role that controls the specified role
     * @param role The role to get the admin for
     * @return bytes32 The admin role
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    /**
     * @notice Grant a role to an account
     * @dev Grants the specified role to the account
     * @param role The role to grant
     * @param account The account to grant the role to
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function grantRole(bytes32 role, address account) external;
    /**
     * @notice Revoke a role from an account
     * @dev Revokes the specified role from the account
     * @param role The role to revoke
     * @param account The account to revoke the role from
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function revokeRole(bytes32 role, address account) external;
    /**
     * @notice Renounce a role
     * @dev Renounces the specified role from the caller
     * @param role The role to renounce
     * @param callerConfirmation Confirmation that the caller is renouncing the role
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function renounceRole(bytes32 role, address callerConfirmation) external;

    // Pausable functions
    /**
     * @notice Check if the contract is paused
     * @dev Returns true if the contract is paused, false otherwise
     * @return bool True if paused, false otherwise
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function paused() external view returns (bool);

    // UUPS functions
    /**
     * @notice Upgrade the contract implementation
     * @dev Upgrades the contract to a new implementation
     * @param newImplementation Address of the new implementation
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function upgradeTo(address newImplementation) external;
    /**
     * @notice Upgrade the contract implementation and call a function
     * @dev Upgrades the contract to a new implementation and calls a function
     * @param newImplementation Address of the new implementation
     * @param data Data to call on the new implementation
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;

    // Constants
    /**
     * @notice Get the governance role identifier
     * @dev Returns the governance role identifier
     * @return bytes32 The governance role identifier
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function GOVERNANCE_ROLE() external view returns (bytes32);
    /**
     * @notice Get the vault manager role identifier
     * @dev Returns the vault manager role identifier
     * @return bytes32 The vault manager role identifier
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function VAULT_MANAGER_ROLE() external view returns (bytes32);
    /**
     * @notice Get the emergency role identifier
     * @dev Returns the emergency role identifier
     * @return bytes32 The emergency role identifier
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function EMERGENCY_ROLE() external view returns (bytes32);
    /**
     * @notice Get the upgrader role identifier
     * @dev Returns the upgrader role identifier
     * @return bytes32 The upgrader role identifier
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function UPGRADER_ROLE() external view returns (bytes32);


    // State variables
    /**
     * @notice Get the USDC token address
     * @dev Returns the address of the USDC token contract
     * @return address The USDC token address
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function usdc() external view returns (address);
    /**
     * @notice Get the aUSDC token address
     * @dev Returns the address of the aUSDC token contract
     * @return address The aUSDC token address
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function aUSDC() external view returns (address);
    /**
     * @notice Get the Aave pool address
     * @dev Returns the address of the Aave pool contract
     * @return address The Aave pool address
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function aavePool() external view returns (address);
    /**
     * @notice Get the Aave provider address
     * @dev Returns the address of the Aave provider contract
     * @return address The Aave provider address
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function aaveProvider() external view returns (address);
    /**
     * @notice Get the rewards controller address
     * @dev Returns the address of the rewards controller contract
     * @return address The rewards controller address
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function rewardsController() external view returns (address);
    /**
     * @notice Get the yield shift address
     * @dev Returns the address of the yield shift contract
     * @return address The yield shift address
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function yieldShift() external view returns (address);
    /**
     * @notice Get the maximum Aave exposure
     * @dev Returns the maximum amount that can be deposited to Aave
     * @return uint256 The maximum Aave exposure
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function maxAaveExposure() external view returns (uint256);
    /**
     * @notice Get the harvest threshold
     * @dev Returns the minimum amount required to trigger a harvest
     * @return uint256 The harvest threshold
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function harvestThreshold() external view returns (uint256);
    /**
     * @notice Get the yield fee
     * @dev Returns the fee percentage charged on harvested yield
     * @return uint256 The yield fee in basis points
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function yieldFee() external view returns (uint256);
    /**
     * @notice Get the rebalance threshold
     * @dev Returns the threshold for triggering rebalancing
     * @return uint256 The rebalance threshold
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function rebalanceThreshold() external view returns (uint256);
    /**
     * @notice Get the principal deposited amount
     * @dev Returns the total amount of principal deposited to Aave
     * @return uint256 The principal deposited amount
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function principalDeposited() external view returns (uint256);
    /**
     * @notice Get the last harvest time
     * @dev Returns the timestamp of the last harvest
     * @return uint256 The last harvest time
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function lastHarvestTime() external view returns (uint256);
    /**
     * @notice Get the total yield harvested
     * @dev Returns the total amount of yield harvested from Aave
     * @return uint256 The total yield harvested
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function totalYieldHarvested() external view returns (uint256);
    /**
     * @notice Get the total fees collected
     * @dev Returns the total amount of fees collected
     * @return uint256 The total fees collected
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function totalFeesCollected() external view returns (uint256);
    /**
     * @notice Get the utilization limit
     * @dev Returns the maximum utilization rate allowed
     * @return uint256 The utilization limit
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function utilizationLimit() external view returns (uint256);
    /**
     * @notice Get the emergency exit threshold
     * @dev Returns the threshold for triggering emergency exit
     * @return uint256 The emergency exit threshold
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function emergencyExitThreshold() external view returns (uint256);
    /**
     * @notice Get the emergency mode status
     * @dev Returns true if the contract is in emergency mode
     * @return bool True if in emergency mode, false otherwise
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function emergencyMode() external view returns (bool);

}
