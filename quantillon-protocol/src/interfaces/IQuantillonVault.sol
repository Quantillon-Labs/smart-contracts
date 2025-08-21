// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IQuantillonVault
 * @notice Interface for the Quantillon vault managing QEURO mint/redeem against USDC
 * @dev Exposes core actions, liquidation, views, governance, emergency, and recovery
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
interface IQuantillonVault {
    /**
     * @notice Initializes the vault
     * @param admin Admin address receiving roles
     * @param _qeuro QEURO token address
     * @param _usdc USDC token address
     * @param _oracle Oracle contract address
     */
    function initialize(address admin, address _qeuro, address _usdc, address _oracle) external;

    /**
     * @notice Mints QEURO by depositing USDC
     * @param usdcAmount Amount of USDC to deposit
     * @param minQeuroOut Minimum QEURO expected (slippage protection)
     */
    function mintQEURO(uint256 usdcAmount, uint256 minQeuroOut) external;

    /**
     * @notice Redeems QEURO for USDC
     * @param qeuroAmount Amount of QEURO to burn
     * @param minUsdcOut Minimum USDC expected
     */
    function redeemQEURO(uint256 qeuroAmount, uint256 minUsdcOut) external;

    /**
     * @notice Adds USDC collateral
     * @param amount Amount of USDC to add
     */
    function addCollateral(uint256 amount) external;

    /**
     * @notice Removes USDC collateral if safe
     * @param amount Amount of USDC to remove
     */
    function removeCollateral(uint256 amount) external;

    /**
     * @notice Liquidates an undercollateralized user
     * @param user User to liquidate
     * @param debtToCover Amount of debt to cover
     */
    function liquidate(address user, uint256 debtToCover) external;

    /**
     * @notice Returns whether a user can be liquidated
     * @param user Address to query
     * @return True if liquidatable
     */
    function isUserLiquidatable(address user) external view returns (bool);

    /**
     * @notice User collateralization ratio
     * @param user Address to query
     * @return Ratio with 18 decimals
     */
    function getUserCollateralRatio(address user) external view returns (uint256);

    /**
     * @notice Global vault health metrics
     * @return totalCollateralValue Total USDC collateral
     * @return totalDebtValue Total QEURO debt valued in USDC
     * @return globalCollateralRatio Global ratio with 18 decimals
     */
    function getVaultHealth() external view returns (
        uint256 totalCollateralValue,
        uint256 totalDebtValue,
        uint256 globalCollateralRatio
    );

    /**
     * @notice Detailed user info
     * @param user Address to query
     * @return collateral User USDC collateral
     * @return debt User QEURO debt
     * @return collateralRatio Current ratio with 18 decimals
     * @return isLiquidatable Whether the user can be liquidated
     * @return liquidated Liquidation status flag
     */
    function getUserInfo(address user) external view returns (
        uint256 collateral,
        uint256 debt,
        uint256 collateralRatio,
        bool isLiquidatable,
        bool liquidated
    );

    /**
     * @notice Computes QEURO mint amount for a USDC deposit
     * @param usdcAmount USDC to deposit
     * @return qeuroAmount Expected QEURO to mint
     * @return collateralRatio Resulting ratio
     */
    function calculateMintAmount(uint256 usdcAmount) external view returns (uint256 qeuroAmount, uint256 collateralRatio);

    /**
     * @notice Computes USDC redemption amount for a QEURO burn
     * @param qeuroAmount QEURO to redeem
     * @return usdcAmount USDC returned after fees
     * @return fee Protocol fee
     */
    function calculateRedeemAmount(uint256 qeuroAmount) external view returns (uint256 usdcAmount, uint256 fee);

    /**
     * @notice Updates vault parameters
     * @param _minCollateralRatio New minimum ratio (>= 100%)
     * @param _liquidationThreshold New liquidation threshold (<= min)
     * @param _liquidationPenalty New liquidation penalty (<= 20%)
     */
    function updateParameters(uint256 _minCollateralRatio, uint256 _liquidationThreshold, uint256 _liquidationPenalty) external;

    /**
     * @notice Updates the protocol fee
     * @param _protocolFee New fee (e.g., 1e15 = 0.1%)
     */
    function updateProtocolFee(uint256 _protocolFee) external;

    /**
     * @notice Updates the oracle address
     * @param _oracle New oracle address
     */
    function updateOracle(address _oracle) external;

    /**
     * @notice Withdraws accumulated protocol fees
     * @param to Recipient address
     */
    function withdrawProtocolFees(address to) external;

    /**
     * @notice Pauses the vault
     */
    function pause() external;

    /**
     * @notice Unpauses the vault
     */
    function unpause() external;

    /**
     * @notice Emergency liquidation bypassing normal checks
     * @param user User to liquidate
     * @param debtToCover Debt to cover
     */
    function emergencyLiquidate(address user, uint256 debtToCover) external;

    /**
     * @notice Recovers ERC20 tokens sent by mistake
     * @param token Token address
     * @param to Recipient
     * @param amount Amount to transfer
     */
    function recoverToken(address token, address to, uint256 amount) external;

    /**
     * @notice Recovers ETH sent by mistake
     * @param to Recipient
     */
    function recoverETH(address payable to) external;
}
