// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IQuantillonVault
 * @notice Interface for the Quantillon vault managing QEURO mint/redeem against USDC
 * @dev Exposes core swap functions, views, governance, emergency, and recovery
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
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
     * @param _hedgerPool HedgerPool contract address
     * @param _userPool UserPool contract address
     * @param _timelock Timelock contract address
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     * @param admin Address that receives admin and governance roles
     * @param _qeuro QEURO token contract address
     * @param _usdc USDC token contract address
     * @param _oracle Chainlink oracle contract address
     * @param _hedgerPool HedgerPool contract address
     * @param _userPool UserPool contract address
     * @param _timelock Timelock contract address for secure upgrades
     * @param _feeCollector FeeCollector contract address
     */
    function initialize(address admin, address _qeuro, address _usdc, address _oracle, address _hedgerPool, address _userPool, address _timelock, address _feeCollector) external;

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
     * @return totalUsdcHeld_ Total USDC held directly in the vault
     * @return totalMinted_ Total QEURO minted
     * @return totalDebtValue Total debt value in USD
     * @return totalUsdcInAave_ Total USDC deployed to Aave for yield
     * @return totalUsdcAvailable_ Total USDC available (vault + Aave)
      * @custom:security Read-only helper
      * @custom:validation None
      * @custom:state-changes None
      * @custom:events None
      * @custom:errors None
      * @custom:reentrancy Not applicable
      * @custom:access Public
      * @custom:oracle Uses cached oracle price for debt-value conversion
     */
    function getVaultMetrics() external view returns (
        uint256 totalUsdcHeld_,
        uint256 totalMinted_,
        uint256 totalDebtValue,
        uint256 totalUsdcInAave_,
        uint256 totalUsdcAvailable_
    );

    /**
     * @notice Computes QEURO mint amount for a USDC swap
     * @dev Uses cached oracle price to calculate QEURO equivalent without executing swap
     * @param usdcAmount USDC to swap
     * @return qeuroAmount Expected QEURO to mint (after fees)
     * @return fee Protocol fee
      * @custom:security Read-only helper
      * @custom:validation Returns zeroes when price cache is uninitialized
      * @custom:state-changes None
      * @custom:events None
      * @custom:errors None
      * @custom:reentrancy Not applicable
      * @custom:access Public
      * @custom:oracle Uses cached oracle price only
     */
    function calculateMintAmount(uint256 usdcAmount) external view returns (uint256 qeuroAmount, uint256 fee);

    /**
     * @notice Computes USDC redemption amount for a QEURO swap
     * @dev Uses cached oracle price to calculate USDC equivalent without executing swap
     * @param qeuroAmount QEURO to swap
     * @return usdcAmount USDC returned after fees
     * @return fee Protocol fee
      * @custom:security Read-only helper
      * @custom:validation Returns zeroes when price cache is uninitialized
      * @custom:state-changes None
      * @custom:events None
      * @custom:errors None
      * @custom:reentrancy Not applicable
      * @custom:access Public
      * @custom:oracle Uses cached oracle price only
     */
    function calculateRedeemAmount(uint256 qeuroAmount) external view returns (uint256 usdcAmount, uint256 fee);

    /**
     * @notice Updates vault parameters
     * @dev Allows governance to update fee parameters for minting and redemption
     * @param _mintFee New minting fee (1e18-scaled, where 1e18 = 100%)
     * @param _redemptionFee New redemption fee (1e18-scaled, where 1e18 = 100%)
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
     * @dev Allows governance to recover accidentally sent ERC20 tokens to treasury
     * @param token Token address
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
    function recoverToken(address token, uint256 amount) external;

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
     * @dev Fee charged when minting QEURO with USDC (1e18-scaled, where 1e16 = 1%)
     * @return The minting fee as a 1e18-scaled percentage
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
     * @dev Fee charged when redeeming QEURO for USDC (1e18-scaled, where 1e16 = 1%)
     * @return The redemption fee as a 1e18-scaled percentage
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

    /**
     * @notice Checks if the protocol is properly collateralized by hedgers
     * @dev Public view function to check collateralization status
     * @return isCollateralized True if protocol has active hedging positions
     * @return totalMargin Total margin in HedgerPool (0 if not set)
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can check collateralization status
     * @custom:oracle No oracle dependencies
     */
    function isProtocolCollateralized() external view returns (bool isCollateralized, uint256 totalMargin);

    /**
     * @notice Returns the minimum collateralization ratio for minting
     * @dev Minimum ratio required for QEURO minting (1e18-scaled percentage format)
     * @return The minimum collateralization ratio in 1e18-scaled percentage format
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query minimum ratio
     * @custom:oracle No oracle dependencies
     */
    function minCollateralizationRatioForMinting() external view returns (uint256);

    /**
     * @notice Returns the UserPool contract address
     * @dev The user pool contract managing user deposits
     * @return Address of the UserPool contract
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query user pool address
     * @custom:oracle No oracle dependencies
     */
    function userPool() external view returns (address);

    // =============================================================================
    // HEDGER POOL INTEGRATION - Functions for unified USDC liquidity management
    // =============================================================================

    /**
     * @notice Adds hedger USDC deposit to vault's total USDC reserves
     * @dev Called by HedgerPool when hedgers open positions to unify USDC liquidity
     * @param usdcAmount Amount of USDC deposited by hedger (6 decimals)
     * @custom:security Validates caller is HedgerPool contract and amount is positive
     * @custom:validation Validates amount > 0 and caller is authorized HedgerPool
     * @custom:state-changes Updates totalUsdcHeld with hedger deposit amount
     * @custom:events Emits HedgerDepositAdded with deposit details
     * @custom:errors Throws "Vault: Only HedgerPool can call" if caller is not HedgerPool
     * @custom:errors Throws "Vault: Amount must be positive" if amount is zero
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to HedgerPool contract only
     * @custom:oracle No oracle dependencies
     */
    function addHedgerDeposit(uint256 usdcAmount) external;

    /**
     * @notice Withdraws hedger USDC deposit from vault's reserves
     * @dev Called by HedgerPool when hedgers close positions to return their deposits
     * @param hedger Address of the hedger receiving the USDC
     * @param usdcAmount Amount of USDC to withdraw (6 decimals)
     * @custom:security Validates caller is HedgerPool, amount is positive, and sufficient reserves
     * @custom:validation Validates amount > 0, caller is authorized, and totalUsdcHeld >= amount
     * @custom:state-changes Updates totalUsdcHeld and transfers USDC to hedger
     * @custom:events Emits HedgerDepositWithdrawn with withdrawal details
     * @custom:errors Throws "Vault: Only HedgerPool can call" if caller is not HedgerPool
     * @custom:errors Throws "Vault: Amount must be positive" if amount is zero
     * @custom:errors Throws "Vault: Insufficient USDC reserves" if not enough USDC available
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to HedgerPool contract only
     * @custom:oracle No oracle dependencies
     */
    function withdrawHedgerDeposit(address hedger, uint256 usdcAmount) external;

    /**
     * @notice Gets the total USDC available for hedger deposits
     * @dev Returns the current total USDC held in the vault for transparency
     * @return uint256 Total USDC held in vault (6 decimals)
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public access - anyone can query total USDC held
     * @custom:oracle No oracle dependencies
     */
    function getTotalUsdcAvailable() external view returns (uint256);

    /**
     * @notice Updates the HedgerPool address
     * @dev Updates the HedgerPool contract address for hedger operations
     * @param _hedgerPool New HedgerPool address
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function updateHedgerPool(address _hedgerPool) external;

    /**
     * @notice Updates the UserPool address
     * @dev Updates the UserPool contract address for user deposit tracking
     * @param _userPool New UserPool address
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function updateUserPool(address _userPool) external;

    /**
     * @notice Gets the price protection status and parameters
     * @dev Returns price protection configuration for monitoring
     * @return lastValidPrice Last valid EUR/USD price
     * @return lastUpdateBlock Block number of last price update
     * @return maxDeviation Maximum allowed price deviation
     * @return minBlocks Minimum blocks between price updates
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public access - anyone can query price protection status
     * @custom:oracle No oracle dependencies
     */
    function getPriceProtectionStatus() external view returns (
        uint256 lastValidPrice,
        uint256 lastUpdateBlock,
        uint256 maxDeviation,
        uint256 minBlocks
    );

    /**
     * @notice Updates the fee collector address
     * @dev Updates the fee collector contract address
     * @param _feeCollector New fee collector address
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function updateFeeCollector(address _feeCollector) external;

    /**
     * @notice Updates the collateralization thresholds
     * @dev Updates minimum and critical collateralization ratios
     * @param _minCollateralizationRatioForMinting New minimum collateralization ratio for minting (1e18-scaled percentage)
     * @param _criticalCollateralizationRatio New critical collateralization ratio for liquidation (1e18-scaled percentage)
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function updateCollateralizationThresholds(
        uint256 _minCollateralizationRatioForMinting,
        uint256 _criticalCollateralizationRatio
    ) external;

    /**
     * @notice Checks if minting is allowed based on current collateralization ratio
     * @dev Returns true if collateralization ratio >= minCollateralizationRatioForMinting
     * @return canMint Whether minting is currently allowed
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted - view function
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can check minting status
     * @custom:oracle No oracle dependencies
     */
    function canMint() external view returns (bool);

    /**
     * @notice Checks if liquidation should be triggered based on current collateralization ratio
     * @dev Returns true if collateralization ratio < criticalCollateralizationRatio
     * @return shouldLiquidate Whether liquidation should be triggered
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted - view function
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can check liquidation status
     * @custom:oracle No oracle dependencies
     */
    function shouldTriggerLiquidation() external view returns (bool);

    /**
     * @notice Returns liquidation status and key metrics for pro-rata redemption
     * @dev Protocol enters liquidation mode when CR <= 101%
     * @return isInLiquidation True if protocol is in liquidation mode
     * @return collateralizationRatioBps Current CR in basis points
     * @return totalCollateralUsdc Total protocol collateral in USDC (6 decimals)
     * @return totalQeuroSupply Total QEURO supply (18 decimals)
     * @custom:security View function - no state changes
     * @custom:validation No input validation required
     * @custom:state-changes None - view function
     * @custom:events None
     * @custom:errors None
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can check liquidation status
     * @custom:oracle Requires oracle price for collateral calculation
     */
    function getLiquidationStatus() external view returns (
        bool isInLiquidation,
        uint256 collateralizationRatioBps,
        uint256 totalCollateralUsdc,
        uint256 totalQeuroSupply
    );

    /**
     * @notice Calculates pro-rata payout for liquidation mode redemption
     * @dev Formula: payout = (qeuroAmount / totalSupply) * totalCollateral
     * @param qeuroAmount Amount of QEURO to redeem (18 decimals)
     * @return usdcPayout Amount of USDC the user would receive (6 decimals)
     * @return isPremium True if payout > fair value (CR > 100%)
     * @return premiumOrDiscountBps Premium or discount in basis points
     * @custom:security View function - no state changes
     * @custom:validation Validates qeuroAmount > 0
     * @custom:state-changes None - view function
     * @custom:events None
     * @custom:errors Throws InvalidAmount if qeuroAmount is 0
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can calculate payout
     * @custom:oracle Requires oracle price for fair value calculation
     */
    function calculateLiquidationPayout(uint256 qeuroAmount) external view returns (
        uint256 usdcPayout,
        bool isPremium,
        uint256 premiumOrDiscountBps
    );

    /**
     * @notice Redeems QEURO for USDC using pro-rata distribution in liquidation mode
     * @dev Only callable when protocol is in liquidation mode (CR <= 101%)
     * @param qeuroAmount Amount of QEURO to redeem (18 decimals)
     * @param minUsdcOut Minimum USDC expected (slippage protection)
     * @custom:security Protected by nonReentrant, requires liquidation mode
     * @custom:validation Validates qeuroAmount > 0, minUsdcOut slippage, liquidation mode
     * @custom:state-changes Burns QEURO, transfers USDC pro-rata
     * @custom:events Emits LiquidationRedeemed
     * @custom:errors Reverts if not in liquidation mode or slippage exceeded
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Public - anyone with QEURO can redeem
     * @custom:oracle Requires oracle price for collateral calculation
     */
    function redeemQEUROLiquidation(uint256 qeuroAmount, uint256 minUsdcOut) external;

    /**
     * @notice Calculates the current protocol collateralization ratio
     * @dev Returns ratio in 1e18-scaled percentage format (100% = 1e20)
     * @return ratio Current collateralization ratio in 1e18-scaled percentage format
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted - view function
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can check collateralization ratio
     * @custom:oracle Requires fresh oracle price data (via HedgerPool)
     */
    function getProtocolCollateralizationRatio() external view returns (uint256);

    /**
     * @notice View-only collateralization ratio using cached price.
     * @dev Returns the same units as `getProtocolCollateralizationRatio()` but relies solely
     *      on the cached EUR/USD price to remain view-safe (no external oracle calls).
     * @return ratio Cached collateralization ratio in 1e18‑scaled percentage format.
     * @custom:security View helper; does not mutate state or touch external oracles.
     * @custom:validation Returns a stale or sentinel value if the cache is uninitialized.
     * @custom:state-changes None – pure view over cached pricing and vault balances.
     * @custom:events None.
     * @custom:errors None – callers must handle edge cases (e.g. 0 collateral).
     * @custom:reentrancy Not applicable – view function only.
     * @custom:access Public – intended for dashboards and off‑chain monitoring.
     * @custom:oracle Uses only the last cached price maintained on-chain.
     */
    function getProtocolCollateralizationRatioView() external view returns (uint256);

    /**
     * @notice View-only mintability check using cached price and current hedger status.
     * @dev Equivalent to `canMint()` but guaranteed not to perform fresh oracle reads,
     *      making it safe for off‑chain calls that must not revert due to oracle issues.
     * @return canMintCached True if, based on cached price and current hedger state, minting would be allowed.
     * @custom:security Read‑only helper; never mutates state or external dependencies.
     * @custom:validation Returns false on uninitialized cache or missing hedger configuration.
     * @custom:state-changes None – pure read of cached price and protocol state.
     * @custom:events None.
     * @custom:errors None – callers interpret the boolean.
     * @custom:reentrancy Not applicable – view function only.
     * @custom:access Public – anyone can pre‑check mint conditions.
     * @custom:oracle Uses cached price only; no live oracle reads.
     */
    function canMintView() external view returns (bool);

    /**
     * @notice Updates the price cache with the current oracle price
     * @dev Allows governance to manually refresh the price cache
     * @custom:security Only callable by governance role
     * @custom:validation Validates oracle price is valid before updating cache
     * @custom:state-changes Updates lastValidEurUsdPrice, lastPriceUpdateBlock, and lastPriceUpdateTime
     * @custom:events Emits PriceCacheUpdated event
     * @custom:errors Reverts if oracle price is invalid
     * @custom:reentrancy Not applicable - no external calls after state changes
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle Requires valid oracle price
     */
    function updatePriceCache() external;

    /**
     * @notice Initializes the cached EUR/USD price used by view-safe query paths.
     * @dev Seeds the internal cache with an explicit bootstrap price so view paths
     *      have a baseline without performing external oracle reads in this mutating call.
     * @param initialEurUsdPrice Initial EUR/USD price in 18 decimals.
     * @custom:security Restricted to governance.
     * @custom:validation Reverts if `initialEurUsdPrice` is zero.
     * @custom:state-changes Writes the initial cached price and associated timestamp/blocks.
     * @custom:events Emits a price-cache initialization event in the implementation.
     * @custom:errors Reverts when cache is already initialized or input is invalid.
     * @custom:reentrancy Not applicable.
     * @custom:access Restricted to `GOVERNANCE_ROLE`.
     * @custom:oracle Bootstrap input should come from governance/oracle operations.
     */
    function initializePriceCache(uint256 initialEurUsdPrice) external;

    // =============================================================================
    // AAVE INTEGRATION - Functions for USDC yield generation via Aave
    // =============================================================================

    /**
     * @notice Deploys USDC from the vault to Aave for yield generation
     * @dev Called by UserPool after minting QEURO to automatically deploy USDC to Aave
     * @param usdcAmount Amount of USDC to deploy to Aave (6 decimals)
     * @custom:security Only callable by VAULT_OPERATOR_ROLE (UserPool)
     * @custom:validation Validates amount > 0, AaveVault is set, and sufficient USDC balance
     * @custom:state-changes Updates totalUsdcHeld (decreases) and totalUsdcInAave (increases)
     * @custom:events Emits UsdcDeployedToAave event
     * @custom:errors Reverts if amount is 0, AaveVault not set, or insufficient USDC
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to VAULT_OPERATOR_ROLE
     * @custom:oracle No oracle dependencies
     */
    function deployUsdcToAave(uint256 usdcAmount) external;

    /**
     * @notice Updates the AaveVault address for USDC yield generation
     * @dev Only governance role can update the AaveVault address
     * @param _aaveVault New AaveVault address
     * @custom:security Validates address is not zero before updating
     * @custom:validation Ensures _aaveVault is not address(0)
     * @custom:state-changes Updates aaveVault state variable
     * @custom:events Emits AaveVaultUpdated event
     * @custom:errors Reverts if _aaveVault is address(0)
     * @custom:reentrancy No reentrancy risk, simple state update
     * @custom:access Restricted to GOVERNANCE_ROLE
     * @custom:oracle No oracle dependencies
     */
    function updateAaveVault(address _aaveVault) external;

    /**
     * @notice Registers this vault into stQEUROFactory and deploys its dedicated token.
     * @dev Binds the vault to a deterministic stQEURO token address and records factory linkage.
     * @param factory Address of stQEUROFactory.
     * @param vaultId Target vault id.
     * @param vaultName Uppercase alphanumeric vault name.
     * @return token Newly deployed stQEURO token address.
     * @custom:security Intended for governance-only execution in implementation.
     * @custom:validation Implementations must validate factory address, vault id, and registration uniqueness.
     * @custom:state-changes Updates factory/token/vault-id bindings on successful registration.
     * @custom:events Emits registration event in implementation.
     * @custom:errors Reverts for invalid input, duplicate initialization, or registration mismatch.
     * @custom:reentrancy Implementation protects external registration flow with reentrancy guard.
     * @custom:access Access controlled by implementation (governance role).
     * @custom:oracle No oracle dependencies.
     */
    function selfRegisterStQEURO(address factory, uint256 vaultId, string calldata vaultName)
        external
        returns (address token);

    /**
     * @notice Updates the protocol‑fee share routed to HedgerPool reward reserve.
     * @dev Sets the fraction of protocol fees (scaled by 1e18 where 1e18 = 100%)
     *      that is forwarded to HedgerPool’s reward reserve instead of remaining in the vault.
     * @param newSplit New fee‑share value (1e18‑scaled, 0–1e18 allowed by implementation).
     * @custom:security Only callable by governance; misconfiguration can starve protocol or hedgers.
     * @custom:validation Implementation validates that `newSplit` is within acceptable bounds.
     * @custom:state-changes Updates internal accounting for how fees are split on collection.
     * @custom:events Emits an event in the implementation describing the new split.
     * @custom:errors Reverts on invalid split values as defined by implementation.
     * @custom:reentrancy Not applicable – configuration only, no external transfers.
     * @custom:access Restricted to `GOVERNANCE_ROLE`.
     * @custom:oracle No direct oracle dependency.
     */
    function updateHedgerRewardFeeSplit(uint256 newSplit) external;

    /**
     * @notice Harvests accrued Aave interest through the configured AaveVault.
     * @dev Pulls pending yield from `AaveVault` back into the vault and routes it
     *      according to the protocol’s fee and reward‑sharing rules.
     * @return harvestedYield Net USDC yield amount harvested from Aave (6 decimals).
     * @custom:security Only callable by governance or a dedicated operator role (per implementation).
     * @custom:validation Requires a configured AaveVault and sufficient accrued interest.
     * @custom:state-changes Updates vault balances and internal yield‑accounting fields.
     * @custom:events Emits a harvest event with the realized yield amount.
     * @custom:errors Reverts if AaveVault is unset or harvest conditions are not met.
     * @custom:reentrancy Protected by nonReentrant modifier in implementation.
     * @custom:access Access control enforced by implementation (typically GOVERNANCE_ROLE).
     * @custom:oracle No direct oracle dependency; operates on Aave position balances.
     */
    function harvestAaveInterest() external returns (uint256 harvestedYield);

    /**
     * @notice Returns the AaveVault contract address
     * @dev The AaveVault contract for USDC yield generation
     * @return Address of the AaveVault contract
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query aaveVault address
     * @custom:oracle No oracle dependencies
     */
    function aaveVault() external view returns (address);

    /**
     * @notice Returns the total USDC deployed to Aave
     * @dev Tracks USDC that has been sent to AaveVault for yield generation
     * @return Total USDC in Aave (6 decimals)
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query total USDC in Aave
     * @custom:oracle No oracle dependencies
     */
    function totalUsdcInAave() external view returns (uint256);

    /**
     * @notice Returns configured stQEUROFactory address.
     * @dev Read-only accessor for the factory bound to this vault instance.
     * @custom:security Read-only accessor.
     * @custom:validation No input validation required.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors No errors expected.
     * @custom:reentrancy Not applicable for view function.
     * @custom:access Public view.
     * @custom:oracle No oracle dependencies.
     */
    function stQEUROFactory() external view returns (address);

    /**
     * @notice Returns the stQEURO token address registered for this vault.
     * @dev Read-only accessor for the vault-specific stQEURO token.
     * @custom:security Read-only accessor.
     * @custom:validation No input validation required.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors No errors expected.
     * @custom:reentrancy Not applicable for view function.
     * @custom:access Public view.
     * @custom:oracle No oracle dependencies.
     */
    function stQEUROToken() external view returns (address);

    /**
     * @notice Returns the factory vault id bound to this vault.
     * @dev Read-only accessor for the registered stQEURO factory vault id.
     * @custom:security Read-only accessor.
     * @custom:validation No input validation required.
     * @custom:state-changes No state changes.
     * @custom:events No events emitted.
     * @custom:errors No errors expected.
     * @custom:reentrancy Not applicable for view function.
     * @custom:access Public view.
     * @custom:oracle No oracle dependencies.
     */
    function stQEUROVaultId() external view returns (uint256);

    /**
     * @notice Returns the vault operator role identifier
     * @dev Role that can trigger Aave deployments (assigned to UserPool)
     * @return The vault operator role bytes32 identifier
     * @custom:security No security validations required - view function
     * @custom:validation No input validation required - view function
     * @custom:state-changes No state changes - view function only
     * @custom:events No events emitted
     * @custom:errors No errors thrown - safe view function
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - anyone can query role identifier
     * @custom:oracle No oracle dependencies
     */
    function VAULT_OPERATOR_ROLE() external view returns (bytes32);
}
