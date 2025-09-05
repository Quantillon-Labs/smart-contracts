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
     * @dev Sets up the vault with initial configuration and assigns roles to admin
     * @param admin Admin address receiving roles
     * @param _qeuro QEURO token address
     * @param _usdc USDC token address
     * @param _oracle Oracle contract address
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function initialize(address admin, address _qeuro, address _usdc, address _oracle) external;

    /**
     * @notice Mints QEURO by swapping USDC
     * @dev Converts USDC to QEURO using current oracle price with slippage protection
     * @param usdcAmount Amount of USDC to swap
     * @param minQeuroOut Minimum QEURO expected (slippage protection)
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function mintQEURO(uint256 usdcAmount, uint256 minQeuroOut) external;

    /**
     * @notice Redeems QEURO for USDC
     * @dev Converts QEURO (18 decimals) to USDC (6 decimals) using oracle price
     * @param qeuroAmount Amount of QEURO to swap
     * @param minUsdcOut Minimum USDC expected
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function redeemQEURO(uint256 qeuroAmount, uint256 minUsdcOut) external;

    /**
     * @notice Retrieves the vault's global metrics
     * @dev Provides comprehensive vault statistics for monitoring and analysis
     * @return totalUsdcHeld_ Total USDC held in the vault
     * @return totalMinted_ Total QEURO minted
     * @return totalDebtValue Total debt value in USD
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getVaultMetrics() external view returns (
        uint256 totalUsdcHeld_,
        uint256 totalMinted_,
        uint256 totalDebtValue
    );

    /**
     * @notice Computes QEURO mint amount for a USDC swap
     * @dev Uses current oracle price to calculate QEURO equivalent without executing swap
     * @param usdcAmount USDC to swap
     * @return qeuroAmount Expected QEURO to mint (after fees)
     * @return fee Protocol fee
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function calculateMintAmount(uint256 usdcAmount) external view returns (uint256 qeuroAmount, uint256 fee);

    /**
     * @notice Computes USDC redemption amount for a QEURO swap
     * @dev Uses current oracle price to calculate USDC equivalent without executing swap
     * @param qeuroAmount QEURO to swap
     * @return usdcAmount USDC returned after fees
     * @return fee Protocol fee
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function calculateRedeemAmount(uint256 qeuroAmount) external view returns (uint256 usdcAmount, uint256 fee);

    /**
     * @notice Updates vault parameters
     * @dev Allows governance to update fee parameters for minting and redemption
     * @param _mintFee New minting fee
     * @param _redemptionFee New redemption fee
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function updateParameters(uint256 _mintFee, uint256 _redemptionFee) external;

    /**
     * @notice Updates the oracle address
     * @dev Allows governance to update the price oracle used for conversions
     * @param _oracle New oracle address
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function updateOracle(address _oracle) external;

    /**
     * @notice Withdraws accumulated protocol fees
     * @dev Allows governance to withdraw accumulated fees to specified address
     * @param to Recipient address
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function withdrawProtocolFees(address to) external;

    /**
     * @notice Pauses the vault
     * @dev Emergency function to pause all vault operations
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
     * @notice Unpauses the vault
     * @dev Resumes all vault operations after emergency pause
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
     * @notice Recovers ERC20 tokens sent by mistake
     * @dev Allows governance to recover accidentally sent ERC20 tokens
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
     * @notice Recovers ETH sent by mistake
     * @dev Allows governance to recover accidentally sent ETH
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
     * @notice Checks if an account has a specific role
     * @dev Returns true if the account has been granted the role
     * @param role The role to check
     * @param account The account to check
     * @return True if the account has the role
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can check roles
     * @custom:oracle No oracle dependencies
     */
    function hasRole(bytes32 role, address account) external view returns (bool);
    
    /**
     * @notice Gets the admin role for a given role
     * @dev Returns the role that is the admin of the given role
     * @param role The role to get admin for
     * @return The admin role
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query role admin
     * @custom:oracle No oracle dependencies
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    
    /**
     * @notice Grants a role to an account
     * @dev Can only be called by an account with the admin role
     * @param role The role to grant
     * @param account The account to grant the role to
     * @custom:security Validates caller has admin role for the specified role
     * @custom:validation Validates account is not address(0)
     * @custom:state-changes Grants role to account
     * @custom:events Emits RoleGranted event
     * @custom:errors Throws AccessControlUnauthorizedAccount if caller lacks admin role
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to role admin
     * @custom:oracle No oracle dependencies
     */
    function grantRole(bytes32 role, address account) external;
    
    /**
     * @notice Revokes a role from an account
     * @dev Can only be called by an account with the admin role
     * @param role The role to revoke
     * @param account The account to revoke the role from
     * @custom:security Validates caller has admin role for the specified role
     * @custom:validation Validates account is not address(0)
     * @custom:state-changes Revokes role from account
     * @custom:events Emits RoleRevoked event
     * @custom:errors Throws AccessControlUnauthorizedAccount if caller lacks admin role
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to role admin
     * @custom:oracle No oracle dependencies
     */
    function revokeRole(bytes32 role, address account) external;
    
    /**
     * @notice Renounces a role from the caller
     * @dev The caller gives up their own role
     * @param role The role to renounce
     * @param callerConfirmation Confirmation that the caller is renouncing their own role
     * @custom:security Validates caller is renouncing their own role
     * @custom:validation Validates callerConfirmation matches msg.sender
     * @custom:state-changes Revokes role from caller
     * @custom:events Emits RoleRevoked event
     * @custom:errors Throws AccessControlBadConfirmation if callerConfirmation != msg.sender
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Public - anyone can renounce their own roles
     * @custom:oracle No oracle dependencies
     */
    function renounceRole(bytes32 role, address callerConfirmation) external;

    // Pausable functions
    /**
     * @notice Checks if the contract is paused
     * @dev Returns true if the contract is currently paused
     * @return True if paused, false otherwise
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can check pause status
     * @custom:oracle No oracle dependencies
     */
    function paused() external view returns (bool);

    // UUPS functions
    /**
     * @notice Upgrades the contract to a new implementation
     * @dev Can only be called by accounts with UPGRADER_ROLE
     * @param newImplementation Address of the new implementation contract
     * @custom:security Validates caller has UPGRADER_ROLE
     * @custom:validation Validates newImplementation is not address(0)
     * @custom:state-changes Updates implementation address
     * @custom:events Emits Upgraded event
     * @custom:errors Throws AccessControlUnauthorizedAccount if caller lacks UPGRADER_ROLE
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to UPGRADER_ROLE
     * @custom:oracle No oracle dependencies
     */
    function upgradeTo(address newImplementation) external;
    
    /**
     * @notice Upgrades the contract to a new implementation and calls a function
     * @dev Can only be called by accounts with UPGRADER_ROLE
     * @param newImplementation Address of the new implementation contract
     * @param data Encoded function call data
     * @custom:security Validates caller has UPGRADER_ROLE
     * @custom:validation Validates newImplementation is not address(0)
     * @custom:state-changes Updates implementation address and calls initialization
     * @custom:events Emits Upgraded event
     * @custom:errors Throws AccessControlUnauthorizedAccount if caller lacks UPGRADER_ROLE
     * @custom:reentrancy Not protected - no external calls
     * @custom:access Restricted to UPGRADER_ROLE
     * @custom:oracle No oracle dependencies
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;

    // Constants
    /**
     * @notice Returns the governance role identifier
     * @dev Role that can update vault parameters and governance functions
     * @return The governance role bytes32 identifier
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query role identifier
     * @custom:oracle No oracle dependencies
     */
    function GOVERNANCE_ROLE() external view returns (bytes32);

    /**
     * @notice Returns the emergency role identifier
     * @dev Role that can pause the vault and perform emergency operations
     * @return The emergency role bytes32 identifier
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query role identifier
     * @custom:oracle No oracle dependencies
     */
    function EMERGENCY_ROLE() external view returns (bytes32);
    
    /**
     * @notice Returns the upgrader role identifier
     * @dev Role that can upgrade the contract implementation
     * @return The upgrader role bytes32 identifier
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query role identifier
     * @custom:oracle No oracle dependencies
     */
    function UPGRADER_ROLE() external view returns (bytes32);

    // State variables
    /**
     * @notice Returns the QEURO token address
     * @dev The euro-pegged stablecoin token managed by this vault
     * @return Address of the QEURO token contract
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query token address
     * @custom:oracle No oracle dependencies
     */
    function qeuro() external view returns (address);
    
    /**
     * @notice Returns the USDC token address
     * @dev The collateral token used for minting QEURO
     * @return Address of the USDC token contract
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query token address
     * @custom:oracle No oracle dependencies
     */
    function usdc() external view returns (address);
    
    /**
     * @notice Returns the oracle contract address
     * @dev The price oracle used for EUR/USD conversions
     * @return Address of the oracle contract
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query oracle address
     * @custom:oracle No oracle dependencies
     */
    function oracle() external view returns (address);
    
    /**
     * @notice Returns the current minting fee
     * @dev Fee charged when minting QEURO with USDC (in basis points)
     * @return The minting fee in basis points
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query minting fee
     * @custom:oracle No oracle dependencies
     */
    function mintFee() external view returns (uint256);
    
    /**
     * @notice Returns the current redemption fee
     * @dev Fee charged when redeeming QEURO for USDC (in basis points)
     * @return The redemption fee in basis points
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query redemption fee
     * @custom:oracle No oracle dependencies
     */
    function redemptionFee() external view returns (uint256);
    
    /**
     * @notice Returns the total USDC held in the vault
     * @dev Total amount of USDC collateral backing QEURO
     * @return Total USDC amount (6 decimals)
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query total USDC held
     * @custom:oracle No oracle dependencies
     */
    function totalUsdcHeld() external view returns (uint256);
    
    /**
     * @notice Returns the total QEURO minted
     * @dev Total amount of QEURO tokens in circulation
     * @return Total QEURO amount (18 decimals)
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query total QEURO minted
     * @custom:oracle No oracle dependencies
     */
    function totalMinted() external view returns (uint256);
}
