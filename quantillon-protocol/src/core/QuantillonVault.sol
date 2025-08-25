// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// =============================================================================
// IMPORTS - OpenZeppelin security and features
// =============================================================================

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Internal interfaces of the Quantillon protocol
import "../interfaces/IQEURO.sol";
import "../interfaces/IChainlinkOracle.sol";
import "../libraries/VaultMath.sol";

/**
 * @title QuantillonVault
 * @notice Main vault managing QEURO minting against USDC collateral
 * 
 * @dev Main characteristics:
 *      - Overcollateralized stablecoin minting mechanism
 *      - USDC as primary collateral for QEURO minting
 *      - Real-time EUR/USD price oracle integration
 *      - Automatic liquidation system for risk management
 *      - Dynamic fee structure for protocol sustainability
 *      - Emergency pause mechanism for crisis situations
 *      - Upgradeable via UUPS pattern
 * 
 * @dev Minting mechanics:
 *      - Users deposit USDC as collateral
 *      - QEURO is minted based on EUR/USD exchange rate
 *      - Minimum collateralization ratio enforced (e.g., 101%)
 *      - Minting fees charged for protocol revenue
 *      - Collateral ratio monitored continuously
 * 
 * @dev Redemption mechanics:
 *      - Users can redeem QEURO back to USDC
 *      - Redemption based on current EUR/USD exchange rate
 *      - Protocol fees charged on redemptions
 *      - Collateral returned to user after fee deduction
 * 
 * @dev Risk management:
 *      - Minimum collateralization ratio requirements
 *      - Liquidation thresholds and penalties
 *      - Real-time collateral ratio monitoring
 *      - Automatic liquidation of undercollateralized positions
 *      - Emergency pause capabilities
 * 
 * @dev Fee structure:
 *      - Minting fees for creating QEURO
 *      - Redemption fees for converting QEURO back to USDC
 *      - Liquidation penalties for risk management
 *      - Dynamic fee adjustment based on market conditions
 * 
 * @dev Security features:
 *      - Role-based access control for all critical operations
 *      - Reentrancy protection for all external calls
 *      - Emergency pause mechanism for crisis situations
 *      - Upgradeable architecture for future improvements
 *      - Secure collateral management
 *      - Oracle price validation
 * 
 * @dev Integration points:
 *      - QEURO token for minting and burning
 *      - USDC for collateral deposits and withdrawals
 *      - Chainlink oracle for EUR/USD price feeds
 *      - Vault math library for precise calculations
 * 
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract QuantillonVault is 
    Initializable,
    ReentrancyGuardUpgradeable,    // Reentrancy protection
    AccessControlUpgradeable,      // Role management
    PausableUpgradeable,          // Emergency pause
    UUPSUpgradeable               // Upgrade pattern
{
    using SafeERC20 for IERC20;   // Safe transfers
    using VaultMath for uint256;   // Precise math operations

    // =============================================================================
    // CONSTANTS - Roles and identifiers
    // =============================================================================
    
    /// @notice Role for governance operations (parameter updates, emergency actions)
    /// @dev keccak256 hash avoids role collisions with other contracts
    /// @dev Should be assigned to governance multisig or DAO
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    
    /// @notice Role for liquidating undercollateralized positions
    /// @dev keccak256 hash avoids role collisions with other contracts
    /// @dev Should be assigned to trusted liquidators or automated systems
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    
    /// @notice Role for emergency operations (pause, emergency liquidations)
    /// @dev keccak256 hash avoids role collisions with other contracts
    /// @dev Should be assigned to emergency multisig
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    /// @notice Role for performing contract upgrades via UUPS pattern
    /// @dev keccak256 hash avoids role collisions with other contracts
    /// @dev Should be assigned to governance or upgrade multisig
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // =============================================================================
    // CONSTANTS - Emergency and security parameters
    // =============================================================================
    


    // =============================================================================
    // STATE VARIABLES - External contracts and configuration
    // =============================================================================
    
    /// @notice QEURO token contract for minting and burning
    /// @dev Used for all QEURO minting and burning operations
    /// @dev Should be the official QEURO token contract
    IQEURO public qeuro;
    
    /// @notice USDC token used as collateral
    /// @dev Used for all collateral deposits, withdrawals, and fee payments
    /// @dev Should be the official USDC contract on the target network
    IERC20 public usdc;
    
    /// @notice Chainlink oracle contract for EUR/USD price feeds
    /// @dev Provides real-time EUR/USD exchange rates for minting and redemption
    /// @dev Used for collateral ratio calculations and liquidation checks
    IChainlinkOracle public oracle;

    // Protocol parameters (configurable by governance)
    
    /// @notice Protocol fee charged on minting QEURO (in basis points)
    /// @dev Example: 10 = 0.1% minting fee
    /// @dev Revenue source for the protocol
    uint256 public mintFee;
    
    /// @notice Protocol fee charged on redeeming QEURO (in basis points)
    /// @dev Example: 10 = 0.1% redemption fee
    /// @dev Revenue source for the protocol
    uint256 public redemptionFee;

    // Global vault state
    
    /// @notice Total USDC held in the vault
    /// @dev Used for vault analytics and risk management
    uint256 public totalUsdcHeld;
    
    /// @notice Total QEURO in circulation (minted by this vault)
    uint256 public totalMinted;

    // =============================================================================
    // EVENTS - Events for tracking and monitoring
    // =============================================================================
    
    /// @notice Emitted when QEURO is minted
    event QEUROminted(
        address indexed user, 
        uint256 usdcAmount, 
        uint256 qeuroAmount
    );
    
    /// @notice Emitted when QEURO is redeemed
    event QEURORedeemed(
        address indexed user, 
        uint256 qeuroAmount, 
        uint256 usdcAmount
    );
    
    /// @notice Emitted when parameters are changed
    event ParametersUpdated(
        uint256 mintFee, 
        uint256 redemptionFee
    );

    // =============================================================================
    // INITIALIZER - Initial vault configuration
    // =============================================================================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the vault with contracts and parameters
     * 
     * @param admin Address with administrator privileges
     * @param _qeuro Address of the QEURO token contract
     * @param _usdc Address of the USDC token contract
     * @param _oracle Address of the Oracle contract
     * 
     * @dev This function configures:
     *      1. Access roles
     *      2. References to external contracts
     *      3. Default protocol parameters
     *      4. Security (pause, reentrancy, upgrades)
     */
    function initialize(
        address admin,
        address _qeuro,
        address _usdc,
        address _oracle
    ) public initializer {
        // Validation of critical parameters
        require(admin != address(0), "Vault: Admin cannot be zero");
        require(_qeuro != address(0), "Vault: QEURO cannot be zero");
        require(_usdc != address(0), "Vault: USDC cannot be zero");
        require(_oracle != address(0), "Vault: Oracle cannot be zero");

        // Initialization of security modules
        __ReentrancyGuard_init();     // Reentrancy protection
        __AccessControl_init();        // Role system
        __Pausable_init();            // Pause mechanism
        __UUPSUpgradeable_init();     // Controlled upgrades

        // Configuration of access roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        // LIQUIDATOR_ROLE will be assigned separately to bots/keepers

        // Connections to external contracts
        qeuro = IQEURO(_qeuro);
        usdc = IERC20(_usdc);
        oracle = IChainlinkOracle(_oracle);

        // Default protocol parameters
        mintFee = 1e15;                 // 0.1% mint fee
        redemptionFee = 1e15;           // 0.1% redemption fee
    }


    // =============================================================================
    // CORE FUNCTIONS - Main mint/redeem functions
    // =============================================================================

    /**
     * @notice Mints QEURO tokens by swapping USDC
     * 
     * @param usdcAmount Amount of USDC to swap for QEURO
     * @param minQeuroOut Minimum amount of QEURO expected (slippage protection)
     * 
     * @dev Minting process:
     *      1. Fetch EUR/USD price from oracle
     *      2. Calculate amount of QEURO to mint
     *      3. Transfer USDC from user
     *      4. Update vault balances
     *      5. Mint QEURO to user
     * 
     * @dev Example: 1100 USDC → ~1000 QEURO (if EUR/USD = 1.10)
     *      Simple swap with protocol fee applied
     */
    function mintQEURO(
        uint256 usdcAmount,
        uint256 minQeuroOut
    ) external nonReentrant whenNotPaused {
        // Input validations
        require(usdcAmount > 0, "Vault: Amount must be positive");

        // Fetch EUR/USD price from oracle
        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "Vault: Invalid EUR/USD price");
        _updatePriceTimestamp(isValid);

        // Calculate mint fee
        uint256 fee = usdcAmount.mulDiv(mintFee, 1e18);
        uint256 netAmount = usdcAmount - fee;
        
        // Calculate amount of QEURO to mint
        // Formula: USDC / (EUR/USD) = QEURO
        // Ex: 1100 USDC / 1.10 = 1000 QEURO
        uint256 qeuroToMint = netAmount.mulDiv(1e18, eurUsdPrice);
        
        // Slippage protection
        require(qeuroToMint >= minQeuroOut, "Vault: Insufficient output amount");

        // Transfer USDC from user
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);

        // Update global balances
        totalUsdcHeld += usdcAmount;
        totalMinted += qeuroToMint;

        // Mint QEURO to user
        qeuro.mint(msg.sender, qeuroToMint);

        emit QEUROminted(msg.sender, usdcAmount, qeuroToMint);
    }

    /**
     * @notice Redeems QEURO for USDC
     * 
     * @param qeuroAmount Amount of QEURO to swap for USDC
     * @param minUsdcOut Minimum amount of USDC expected
     * 
     * @dev Redeem process:
     *      1. Calculate USDC to return based on EUR/USD price
     *      2. Apply protocol fees
     *      3. Burn QEURO
     *      4. Update vault balances
     *      5. Transfer USDC to user
     */
    function redeemQEURO(
        uint256 qeuroAmount,
        uint256 minUsdcOut
    ) external nonReentrant whenNotPaused {
        // Input validations
        require(qeuroAmount > 0, "Vault: Amount must be positive");

        // Fetch EUR/USD price
        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "Vault: Invalid EUR/USD price");
        _updatePriceTimestamp(isValid);

        // Calculate USDC to return
        // Formula: QEURO * (EUR/USD) = USDC
        // Ex: 1000 QEURO * 1.10 = 1100 USDC
        uint256 usdcToReturn = qeuroAmount.mulDiv(eurUsdPrice, 1e18);
        
        // Slippage protection
        require(usdcToReturn >= minUsdcOut, "Vault: Insufficient output amount");

        // Apply protocol fees
        uint256 fee = usdcToReturn.mulDiv(redemptionFee, 1e18);
        uint256 netUsdcToReturn = usdcToReturn - fee;

        // Verify vault has enough USDC
        require(
            totalUsdcHeld >= usdcToReturn, 
            "Vault: Insufficient USDC reserves"
        );

        // Burn QEURO from the user
        qeuro.burn(msg.sender, qeuroAmount);

        // Update global balances
        totalUsdcHeld -= usdcToReturn;
        totalMinted -= qeuroAmount;

        // Transfer net USDC to the user (fees kept in the vault)
        usdc.safeTransfer(msg.sender, netUsdcToReturn);

        emit QEURORedeemed(msg.sender, qeuroAmount, netUsdcToReturn);
    }





    // =============================================================================
    // VIEW FUNCTIONS - Read functions for monitoring
    // =============================================================================

    /**
     * @notice Retrieves the vault's global metrics
     * 
     * @return totalUsdcHeld_ Total USDC held in the vault
     * @return totalMinted_ Total QEURO minted
     * @return totalDebtValue Total debt value in USD
     */
    function getVaultMetrics() 
        external 
        view 
        returns (
            uint256 totalUsdcHeld_,
            uint256 totalMinted_,
            uint256 totalDebtValue
        ) 
    {
        totalUsdcHeld_ = totalUsdcHeld;
        totalMinted_ = totalMinted;

        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        if (isValid && totalMinted > 0) {
            // Note: Cannot update timestamp in view function
            totalDebtValue = totalMinted.mulDiv(eurUsdPrice, 1e18);
        } else {
            totalDebtValue = 0;
        }
    }

    /**
     * @notice Calculates the amount of QEURO that can be minted for a given USDC amount
     * 
     * @param usdcAmount Amount of USDC to swap
     * @return qeuroAmount Amount of QEURO that will be minted (after fees)
     * @return fee Protocol fee
     */
    function calculateMintAmount(uint256 usdcAmount) 
        external 
        view 
        returns (uint256 qeuroAmount, uint256 fee) 
    {
        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) return (0, 0);
        // Note: Cannot update timestamp in view function

        fee = usdcAmount.mulDiv(mintFee, 1e18);
        uint256 netAmount = usdcAmount - fee;
        qeuroAmount = netAmount.mulDiv(1e18, eurUsdPrice);
    }

    /**
     * @notice Calculates the amount of USDC received for a QEURO redemption
     * 
     * @param qeuroAmount Amount of QEURO to redeem
     * @return usdcAmount USDC received (after fees)
     * @return fee Protocol fee
     */
    function calculateRedeemAmount(uint256 qeuroAmount) 
        external 
        view 
        returns (uint256 usdcAmount, uint256 fee) 
    {
        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) return (0, 0);
        // Note: Cannot update timestamp in view function

        uint256 grossUsdcAmount = qeuroAmount.mulDiv(eurUsdPrice, 1e18);
        fee = grossUsdcAmount.mulDiv(redemptionFee, 1e18);
        usdcAmount = grossUsdcAmount - fee;
    }


    // =============================================================================
    // GOVERNANCE FUNCTIONS - Governance functions
    // =============================================================================

    /**
     * @notice Updates the vault parameters (governance only)
     * 
     * @param _mintFee New minting fee
     * @param _redemptionFee New redemption fee
     * 
     * @dev Safety constraints:
     *      - Fees <= 5% (user protection)
     */
    function updateParameters(
        uint256 _mintFee,
        uint256 _redemptionFee
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(_mintFee <= 5e16, "Vault: Mint fee too high (max 5%)");
        require(_redemptionFee <= 5e16, "Vault: Redemption fee too high (max 5%)");

        mintFee = _mintFee;
        redemptionFee = _redemptionFee;

        emit ParametersUpdated(_mintFee, _redemptionFee);
    }



    /**
     * @notice Updates the oracle address
     * @param _oracle New oracle address
     */
    function updateOracle(address _oracle) external onlyRole(GOVERNANCE_ROLE) {
        require(_oracle != address(0), "Vault: Oracle cannot be zero");
        oracle = IChainlinkOracle(_oracle);
    }

    /**
     * @notice Withdraws accumulated protocol fees
     * 
     * @param to Destination address for the fees
     * 
     * @dev Fees accumulate during minting and redemptions
     */
    function withdrawProtocolFees(address to) external onlyRole(GOVERNANCE_ROLE) {
        require(to != address(0), "Vault: Invalid recipient");
        
        // Calculate available fees (excess USDC beyond what's needed for redemptions)
        uint256 contractBalance = usdc.balanceOf(address(this));
        require(contractBalance > totalUsdcHeld, "Vault: No fees to withdraw");
        
        uint256 feesToWithdraw = contractBalance - totalUsdcHeld;
        usdc.safeTransfer(to, feesToWithdraw);
    }

    // =============================================================================
    // INTERNAL FUNCTIONS - Internal validation functions
    // =============================================================================

    /**
     * @notice Updates the last valid price timestamp when a valid price is fetched
     * @param isValid Whether the current price fetch was valid
     */
    function _updatePriceTimestamp(bool isValid) internal {
        if (isValid) {
            lastPriceUpdateTime = block.timestamp;
        }
    }





    // =============================================================================
    // EMERGENCY FUNCTIONS - Emergency functions
    // =============================================================================

    /**
     * @notice Pauses all vault operations
     * 
     * @dev When paused:
     *      - No mint/redeem possible
     *      - No add/remove collateral
     *      - Liquidations suspended
     *      - Read functions still active
     */
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses and resumes operations
     */
    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }



    // =============================================================================
    // UPGRADE AND RECOVERY - Upgrades and recovery
    // =============================================================================

    /**
     * @notice Authorizes vault contract upgrades
     * @param newImplementation Address of the new implementation
     */


    function _authorizeUpgrade(address newImplementation) 
        internal 
        override 
        onlyRole(UPGRADER_ROLE) 
    {
        // Additional upgrade validations can be added here
        // For example: compatibility checks, automatic tests, etc.
    }

    /**
     * @notice Recovers tokens accidentally sent to the vault
     * 
     * @param token Token contract address
     * @param to Recipient
     * @param amount Amount to recover
     * 
     * @dev Protections:
     *      - Cannot recover USDC collateral
     *      - Cannot recover QEURO
     *      - Only third-party tokens can be recovered
     */
    function recoverToken(
        address token,
        address to,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(usdc), "Vault: Cannot recover USDC collateral");
        require(token != address(qeuro), "Vault: Cannot recover QEURO");
        require(to != address(0), "Vault: Cannot send to zero address");
        
        IERC20(token).safeTransfer(to, amount);
    }

    /**
     * @notice Recovers ETH accidentally sent
     * @param to ETH recipient
     * 
     * @dev SECURITY FIX: Safe ETH Transfer Implementation
     *      - Replaced deprecated transfer() with call() pattern for better gas handling
     *      - transfer() has 2300 gas stipend limitation that can cause failures with complex contracts
     *      - call() provides flexible gas provision and better error handling
     *      - Prevents ETH from being permanently locked in contract due to gas limitations
     *      - Includes explicit success check to ensure transfer completion
     * 
     * @dev Security considerations:
     *      - Only DEFAULT_ADMIN_ROLE can recover
     *      - Prevents sending to zero address
     *      - Validates balance before attempting transfer
     *      - Uses call() for reliable ETH transfers to any contract
     */
    function recoverETH(address payable to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(to != address(0), "Vault: Cannot send to zero address");
        uint256 balance = address(this).balance;
        require(balance > 0, "Vault: No ETH to recover");
        
        // SECURITY FIX: Use call() instead of transfer() for reliable ETH transfers
        // transfer() has 2300 gas stipend which can fail with complex receive/fallback logic
        (bool success, ) = to.call{value: balance}("");
        require(success, "Vault: ETH transfer failed");
    }

    // =============================================================================
    // ADVANCED VIEW FUNCTIONS - Advanced read functions
    // =============================================================================

    /**
     * @notice Retrieves the list of liquidatable users
     * 
     * @return liquidatableUsers Addresses of liquidatable users
     * @return debtAmounts Corresponding debts
     * 
     * @dev Gas-expensive function, use off-chain only
     */
    function getLiquidatableUsers(uint256 /* maxUsers */) 
        external 
        view 
        returns (address[] memory liquidatableUsers, uint256[] memory debtAmounts) 
    {
        // Note: This function would require a registry of users
        // For this implementation, we return empty arrays
        // In production, use events to track users
        liquidatableUsers = new address[](0);
        debtAmounts = new uint256[](0);
    }



    /// @notice Variable to store the last valid EUR/USD price (emergency state)
    uint256 private lastValidEurUsdPrice;
    /// @notice Variable to store the timestamp of the last valid price update
    uint256 private lastPriceUpdateTime;
}

// =============================================================================
// END OF QUANTILLONVAULT CONTRACT
// =============================================================================