// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IQuantillonVault
 * @notice Interface for the Quantillon vault managing QEURO mint/redeem against USDC
 * @dev Exposes core swap functions, views, governance, emergency, and recovery
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
     * @notice Mints QEURO by swapping USDC
     * @param usdcAmount Amount of USDC to swap
     * @param minQeuroOut Minimum QEURO expected (slippage protection)
     */
    function mintQEURO(uint256 usdcAmount, uint256 minQeuroOut) external;

    /**
     * @notice Redeems QEURO for USDC
     * @param qeuroAmount Amount of QEURO to swap
     * @param minUsdcOut Minimum USDC expected
     */
    function redeemQEURO(uint256 qeuroAmount, uint256 minUsdcOut) external;

    /**
     * @notice Retrieves the vault's global metrics
     * @return totalUsdcHeld_ Total USDC held in the vault
     * @return totalMinted_ Total QEURO minted
     * @return totalDebtValue Total debt value in USD
     */
    function getVaultMetrics() external view returns (
        uint256 totalUsdcHeld_,
        uint256 totalMinted_,
        uint256 totalDebtValue
    );

    /**
     * @notice Computes QEURO mint amount for a USDC swap
     * @param usdcAmount USDC to swap
     * @return qeuroAmount Expected QEURO to mint (after fees)
     * @return fee Protocol fee
     */
    function calculateMintAmount(uint256 usdcAmount) external view returns (uint256 qeuroAmount, uint256 fee);

    /**
     * @notice Computes USDC redemption amount for a QEURO swap
     * @param qeuroAmount QEURO to swap
     * @return usdcAmount USDC returned after fees
     * @return fee Protocol fee
     */
    function calculateRedeemAmount(uint256 qeuroAmount) external view returns (uint256 usdcAmount, uint256 fee);

    /**
     * @notice Updates vault parameters
     * @param _mintFee New minting fee
     * @param _redemptionFee New redemption fee
     */
    function updateParameters(uint256 _mintFee, uint256 _redemptionFee) external;

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

    function EMERGENCY_ROLE() external view returns (bytes32);
    function UPGRADER_ROLE() external view returns (bytes32);

    // State variables
    function qeuro() external view returns (address);
    function usdc() external view returns (address);
    function oracle() external view returns (address);
    function mintFee() external view returns (uint256);
    function redemptionFee() external view returns (uint256);
    function totalUsdcHeld() external view returns (uint256);
    function totalMinted() external view returns (uint256);
}
