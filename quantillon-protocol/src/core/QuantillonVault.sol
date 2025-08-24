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
 * @dev Main features:
 *      - Mint QEURO against USDC (minimum ratio 101%)
 *      - Redeem QEURO back to USDC
 *      - Per-user collateral management
 *      - Automatic liquidations if undercollateralized
 *      - EUR/USD oracle integration for price calculations
 *      - Security mechanisms and emergency pause
 * 
 * @dev Security architecture:
 *      - ReentrancyGuard: Protection against reentrancy attacks
 *      - AccessControl: Role management (admin, liquidator, etc.)
 *      - Pausable: Emergency stop of operations
 *      - Upgradeable: Protocol evolution through governance
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
    
    /// @notice Role for governance actions
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    
    /// @notice Role to perform liquidations
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    
    /// @notice Role for emergency actions
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    /// @notice Role for contract upgrades
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // =============================================================================
    // STATE VARIABLES - Contract state variables
    // =============================================================================
    
    /// @notice QEURO token contract
    IQEURO public qeuro;
    
    /// @notice USDC token used as collateral
    IERC20 public usdc;
    
    /// @notice Oracle for EUR/USD prices
    IChainlinkOracle public oracle;

    // Protocol parameters (configurable by governance)
    
    /// @notice Minimum collateralization ratio (e.g., 101% = 101e16)
    uint256 public minCollateralRatio;
    
    /// @notice Liquidation threshold (e.g., 100% = 100e16)
    uint256 public liquidationThreshold;
    
    /// @notice Liquidation penalty paid to the liquidator (e.g., 5% = 5e16)
    uint256 public liquidationPenalty;
    
    /// @notice Protocol fee on redemptions (e.g., 0.1% = 1e15)
    uint256 public protocolFee;
    
    /// @notice Mint fee (e.g., 0.1% = 1e15)
    uint256 public mintFee;

    // Global vault state
    
    /// @notice Total USDC held as collateral
    uint256 public totalCollateral;
    
    /// @notice Total QEURO in circulation (minted by this vault)
    uint256 public totalMinted;

    // Per-user state
    
    /// @notice USDC collateral of each user
    mapping(address => uint256) public userCollateral;
    
    /// @notice QEURO debt of each user
    mapping(address => uint256) public userDebt;
    
    /// @notice Liquidation status per user
    mapping(address => bool) public isLiquidated;

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
    
    /// @notice Emitted when collateral is added
    event CollateralAdded(
        address indexed user, 
        uint256 amount
    );
    
    /// @notice Emitted when collateral is removed
    event CollateralRemoved(
        address indexed user, 
        uint256 amount
    );
    
    /// @notice Emitted when a liquidation occurs
    event UserLiquidated(
        address indexed user, 
        address indexed liquidator, 
        uint256 collateralLiquidated, 
        uint256 debtCovered
    );
    
    /// @notice Emitted when parameters are changed
    event ParametersUpdated(
        uint256 minCollateralRatio, 
        uint256 liquidationThreshold, 
        uint256 liquidationPenalty
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
        minCollateralRatio = 101e16;    // 101% minimum
        liquidationThreshold = 100e16;   // 100% liquidation threshold
        liquidationPenalty = 5e16;      // 5% liquidator bonus
        protocolFee = 1e15;             // 0.1% protocol fee on redemptions
        mintFee = 1e15;                 // 0.1% mint fee
    }


    // =============================================================================
    // CORE FUNCTIONS - Main mint/redeem functions
    // =============================================================================

    /**
     * @notice Mints QEURO tokens by depositing USDC collateral
     * 
     * @param usdcAmount Amount of USDC to deposit as collateral
     * @param minQeuroOut Minimum amount of QEURO expected (slippage protection)
     * 
     * @dev Minting process:
     *      1. Fetch EUR/USD price from oracle
     *      2. Calculate amount of QEURO to mint
     *      3. Verify minimum collateralization ratio
     *      4. Transfer USDC from user
     *      5. Update balances
     *      6. Mint QEURO to user
     * 
     * @dev Example: 1100 USDC → ~1000 QEURO (if EUR/USD = 1.10)
     *      Collateralization ratio = 110% > 101% minimum ✓
     */
    function mintQEURO(
        uint256 usdcAmount,
        uint256 minQeuroOut
    ) external nonReentrant whenNotPaused {
        // Input validations
        require(usdcAmount > 0, "Vault: Amount must be positive");
        require(!isLiquidated[msg.sender], "Vault: User is liquidated");

        // Fetch EUR/USD price from oracle
        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "Vault: Invalid EUR/USD price");

        // Calculate mint fee
        uint256 fee = usdcAmount.mulDiv(mintFee, 1e18);
        uint256 netAmount = usdcAmount - fee;
        
        // Calculate amount of QEURO to mint
        // Formula: USDC / (EUR/USD) = QEURO
        // Ex: 1100 USDC / 1.10 = 1000 QEURO
        uint256 qeuroToMint = netAmount.mulDiv(1e18, eurUsdPrice);
        
        // Slippage protection
        require(qeuroToMint >= minQeuroOut, "Vault: Insufficient output amount");

        // Verify minimum collateralization ratio
        uint256 newTotalCollateral = userCollateral[msg.sender] + netAmount;
        uint256 newTotalDebt = userDebt[msg.sender] + qeuroToMint;
        
        require(
            _isValidCollateralRatio(msg.sender, newTotalCollateral, newTotalDebt),
            "Vault: Insufficient collateral ratio"
        );

        // Transfer USDC from user to the vault
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);

        // Update user balances
        userCollateral[msg.sender] = newTotalCollateral;
        userDebt[msg.sender] = newTotalDebt;

        // Update global balances
        totalCollateral += netAmount;
        totalMinted += qeuroToMint;

        // Mint QEURO tokens to the user
        qeuro.mint(msg.sender, qeuroToMint);

        // Tracking event
        emit QEUROminted(msg.sender, usdcAmount, qeuroToMint);
    }

    /**
     * @notice Redeems QEURO for USDC collateral
     * 
     * @param qeuroAmount Amount of QEURO to burn
     * @param minUsdcOut Minimum amount of USDC expected
     * 
     * @dev Redeem process:
     *      1. Verify the user has enough debt
     *      2. Calculate USDC to return based on EUR/USD price
     *      3. Apply protocol fees
     *      4. Burn QEURO
     *      5. Update balances
     *      6. Transfer USDC to user
     */
    function redeemQEURO(
        uint256 qeuroAmount,
        uint256 minUsdcOut
    ) external nonReentrant whenNotPaused {
        // Input validations
        require(qeuroAmount > 0, "Vault: Amount must be positive");
        require(userDebt[msg.sender] >= qeuroAmount, "Vault: Insufficient debt");

        // Fetch EUR/USD price
        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "Vault: Invalid EUR/USD price");

        // Calculate USDC to return
        // Formula: QEURO * (EUR/USD) = USDC
        // Ex: 1000 QEURO * 1.10 = 1100 USDC
        uint256 usdcToReturn = qeuroAmount.mulDiv(eurUsdPrice, 1e18);
        
        // Slippage protection
        require(usdcToReturn >= minUsdcOut, "Vault: Insufficient output amount");

        // Apply protocol fees
        uint256 fee = usdcToReturn.mulDiv(protocolFee, 1e18);
        uint256 netUsdcToReturn = usdcToReturn - fee;

        // Verify the user has enough collateral
        require(
            userCollateral[msg.sender] >= usdcToReturn, 
            "Vault: Insufficient collateral"
        );

        // Burn QEURO from the user
        qeuro.burn(msg.sender, qeuroAmount);

        // Update user balances
        userCollateral[msg.sender] -= usdcToReturn;
        userDebt[msg.sender] -= qeuroAmount;

        // Update global balances
        totalCollateral -= usdcToReturn;
        totalMinted -= qeuroAmount;

        // Transfer net USDC to the user (fees kept in the vault)
        usdc.safeTransfer(msg.sender, netUsdcToReturn);

        // Tracking event
        emit QEURORedeemed(msg.sender, qeuroAmount, netUsdcToReturn);
    }

    // =============================================================================
    // COLLATERAL MANAGEMENT - Collateral management
    // =============================================================================

    /**
     * @notice Adds additional USDC collateral
     * 
     * @param amount Amount of USDC to add
     * 
     * @dev Used for:
     *      - Improving the collateralization ratio
     *      - Avoiding liquidation
     *      - Preparing for a new mint
     */
    function addCollateral(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Vault: Amount must be positive");
        require(!isLiquidated[msg.sender], "Vault: User is liquidated");

        // Transfer USDC from user
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        // Update balances
        userCollateral[msg.sender] += amount;
        totalCollateral += amount;

        emit CollateralAdded(msg.sender, amount);
    }

    /**
     * @notice Removes excess USDC collateral
     * 
     * @param amount Amount of USDC to remove
     * 
     * @dev Safeguards:
     *      - Maintain minimum ratio after withdrawal
     *      - User not liquidated
     *      - Sufficient collateral available
     */
    function removeCollateral(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Vault: Amount must be positive");
        require(userCollateral[msg.sender] >= amount, "Vault: Insufficient collateral");
        require(!isLiquidated[msg.sender], "Vault: User is liquidated");

        // Compute new collateral after withdrawal
        uint256 newCollateral = userCollateral[msg.sender] - amount;
        
        // Verify that the minimum ratio is maintained
        require(
            _isValidCollateralRatio(msg.sender, newCollateral, userDebt[msg.sender]), 
            "Vault: Would breach minimum collateral ratio"
        );

        // Update balances
        userCollateral[msg.sender] = newCollateral;
        totalCollateral -= amount;

        // Transfer USDC to the user
        usdc.safeTransfer(msg.sender, amount);

        emit CollateralRemoved(msg.sender, amount);
    }

    // =============================================================================
    // LIQUIDATION SYSTEM - Liquidation system
    // =============================================================================

    /**
     * @notice Liquidates an undercollateralized position
     * 
     * @param user Address of the user to liquidate
     * @param debtToCover Amount of debt to cover
     * 
     * @dev Liquidation process:
     *      1. Verify that the position is liquidatable
     *      2. Calculate collateral to seize (with bonus)
     *      3. Burn QEURO from liquidator
     *      4. Transfer collateral to liquidator
     *      5. Update balances
     * 
     * @dev Liquidator incentives:
     *      - 5% bonus on seized collateral
     *      - Protects the protocol against risky positions
     */
    function liquidate(
        address user,
        uint256 debtToCover
    ) external onlyRole(LIQUIDATOR_ROLE) nonReentrant whenNotPaused {
        require(user != address(0), "Vault: Invalid user address");
        require(debtToCover > 0, "Vault: Debt amount must be positive");
        require(userDebt[user] >= debtToCover, "Vault: Debt amount too high");

        // Verify that the user is indeed liquidatable
        require(_isLiquidatable(user), "Vault: User not liquidatable");

        // Fetch current EUR/USD price
        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "Vault: Invalid EUR/USD price");

        // Calculate collateral to seize
        // 1. USD value of the covered debt
        uint256 collateralValue = debtToCover.mulDiv(eurUsdPrice, 1e18);
        
        // 2. Add liquidation bonus (e.g., +5%)
        uint256 collateralToSeize = collateralValue.mulDiv(
            1e18 + liquidationPenalty, 
            1e18
        );
        
        // Verify the user has enough collateral
        require(
            userCollateral[user] >= collateralToSeize, 
            "Vault: Insufficient collateral to seize"
        );

        // The liquidator must burn their QEURO to cover the debt
        qeuro.burn(msg.sender, debtToCover);

        // Update the liquidated user's balances
        userCollateral[user] -= collateralToSeize;
        userDebt[user] -= debtToCover;

        // Update global balances
        totalCollateral -= collateralToSeize;
        totalMinted -= debtToCover;

        // Transfer seized collateral to the liquidator
        usdc.safeTransfer(msg.sender, collateralToSeize);

        // Reset liquidation status if debt fully repaid
        if (userDebt[user] == 0) {
            isLiquidated[user] = false;
        }

        emit UserLiquidated(user, msg.sender, collateralToSeize, debtToCover);
    }

    // =============================================================================
    // VIEW FUNCTIONS - Read functions for monitoring
    // =============================================================================

    /**
     * @notice Checks if a user can be liquidated
     * @param user User address
     * @return true if liquidatable
     */
    function isUserLiquidatable(address user) external view returns (bool) {
        return _isLiquidatable(user);
    }

    /**
     * @notice Calculates a user's collateralization ratio
     * 
     * @param user User address
     * @return Ratio with 18 decimals (e.g., 1.5e18 = 150%)
     * 
     * @dev Formula: (USDC Collateral * 1e18) / (QEURO Debt * EUR/USD Price)
     */
    function getUserCollateralRatio(address user) external view returns (uint256) {
        if (userDebt[user] == 0) return type(uint256).max;

        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) return 0;

        uint256 debtValue = userDebt[user].mulDiv(eurUsdPrice, 1e18);
        return userCollateral[user].mulDiv(1e18, debtValue);
    }

    /**
     * @notice Retrieves the vault's global health metrics
     * 
     * @return totalCollateralValue Total collateral value in USD
     * @return totalDebtValue Total debt value in USD
     * @return globalCollateralRatio Global collateralization ratio
     */
    function getVaultHealth() 
        external 
        view 
        returns (
            uint256 totalCollateralValue,
            uint256 totalDebtValue,
            uint256 globalCollateralRatio
        ) 
    {
        totalCollateralValue = totalCollateral;

        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        if (isValid && totalMinted > 0) {
            totalDebtValue = totalMinted.mulDiv(eurUsdPrice, 1e18);
            globalCollateralRatio = totalCollateralValue.mulDiv(1e18, totalDebtValue);
        } else {
            totalDebtValue = 0;
            globalCollateralRatio = type(uint256).max;
        }
    }

    /**
     * @notice Retrieves detailed information for a user
     * 
     * @param user User address
     * @return collateral User's USDC collateral
     * @return debt User's QEURO debt
     * @return collateralRatio Current collateralization ratio
     * @return isLiquidatable true if can be liquidated
     * @return liquidated Liquidation status
     */
    function getUserInfo(address user) 
        external 
        view 
        returns (
            uint256 collateral,
            uint256 debt,
            uint256 collateralRatio,
            bool isLiquidatable,
            bool liquidated
        ) 
    {
        collateral = userCollateral[user];
        debt = userDebt[user];
        collateralRatio = this.getUserCollateralRatio(user);
        isLiquidatable = _isLiquidatable(user);
        liquidated = isLiquidated[user];
    }

    /**
     * @notice Calculates the amount of QEURO that can be minted for a given USDC amount
     * 
     * @param usdcAmount Amount of USDC to deposit
     * @return qeuroAmount Amount of QEURO that will be minted
     * @return collateralRatio Resulting collateralization ratio
     */
    function calculateMintAmount(uint256 usdcAmount) 
        external 
        view 
        returns (uint256 qeuroAmount, uint256 collateralRatio) 
    {
        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) return (0, 0);

        qeuroAmount = usdcAmount.mulDiv(1e18, eurUsdPrice);
        
        if (qeuroAmount > 0) {
            uint256 debtValue = qeuroAmount.mulDiv(eurUsdPrice, 1e18);
            collateralRatio = usdcAmount.mulDiv(1e18, debtValue);
        }
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

        uint256 grossUsdcAmount = qeuroAmount.mulDiv(eurUsdPrice, 1e18);
        fee = grossUsdcAmount.mulDiv(protocolFee, 1e18);
        usdcAmount = grossUsdcAmount - fee;
    }


    // =============================================================================
    // GOVERNANCE FUNCTIONS - Governance functions
    // =============================================================================

    /**
     * @notice Updates the vault parameters (governance only)
     * 
     * @param _minCollateralRatio New minimum ratio (e.g., 105e16 = 105%)
     * @param _liquidationThreshold New liquidation threshold
     * @param _liquidationPenalty New liquidation penalty
     * 
     * @dev Safety constraints:
     *      - Minimum ratio >= 100%
     *      - Liquidation threshold <= minimum ratio
     *      - Penalty <= 20% (liquidator protection)
     */
    function updateParameters(
        uint256 _minCollateralRatio,
        uint256 _liquidationThreshold,
        uint256 _liquidationPenalty
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(_minCollateralRatio >= 1e18, "Vault: Min ratio must be >= 100%");
        require(_liquidationThreshold <= _minCollateralRatio, "Vault: Liquidation threshold too high");
        require(_liquidationPenalty <= 20e16, "Vault: Penalty too high (max 20%)");

        minCollateralRatio = _minCollateralRatio;
        liquidationThreshold = _liquidationThreshold;
        liquidationPenalty = _liquidationPenalty;

        emit ParametersUpdated(_minCollateralRatio, _liquidationThreshold, _liquidationPenalty);
    }

    /**
     * @notice Updates the protocol fee
     * @param _protocolFee New fee percentage (e.g., 2e15 = 0.2%)
     */
    function updateProtocolFee(uint256 _protocolFee) external onlyRole(GOVERNANCE_ROLE) {
        require(_protocolFee <= 10e15, "Vault: Fee too high (max 1%)");
        protocolFee = _protocolFee;
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
     * @dev Fees accumulate during redemptions
     *      Only the excess over required collateral can be withdrawn
     */
    function withdrawProtocolFees(address to) external onlyRole(GOVERNANCE_ROLE) {
        require(to != address(0), "Vault: Invalid recipient");
        
        // Calculate available fees
        uint256 contractBalance = usdc.balanceOf(address(this));
        require(contractBalance > totalCollateral, "Vault: No fees to withdraw");
        
        uint256 feesToWithdraw = contractBalance - totalCollateral;
        usdc.safeTransfer(to, feesToWithdraw);
    }

    // =============================================================================
    // INTERNAL FUNCTIONS - Internal validation functions
    // =============================================================================

    /**
     * @notice Checks if a user can be liquidated
     * 
     * @param user User address
     * @return true if the collateralization ratio < liquidation threshold
     * 
     * @dev Liquidation conditions:
     *      1. User has debt > 0
     *      2. Oracle working (valid price)
     *      3. Ratio < liquidation threshold (e.g., 100%)
     */
    function _isLiquidatable(address user) internal view returns (bool) {
        if (userDebt[user] == 0) return false;

        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) return false;

        uint256 debtValue = userDebt[user].mulDiv(eurUsdPrice, 1e18);
        uint256 collateralRatio = userCollateral[user].mulDiv(1e18, debtValue);

        return collateralRatio < liquidationThreshold;
    }

    /**
     * @notice Validates that a collateralization ratio is sufficient
     * 
     * @param user User address (for future logs)
     * @param collateralAmount USDC collateral amount
     * @param debtAmount QEURO debt amount
     * @return true if the ratio >= required minimum
     */
    function _isValidCollateralRatio(
        address user,
        uint256 collateralAmount,
        uint256 debtAmount
    ) internal view returns (bool) {
        // If no debt, ratio is always valid
        if (debtAmount == 0) return true;

        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) return false;

        uint256 debtValue = debtAmount.mulDiv(eurUsdPrice, 1e18);
        uint256 collateralRatio = collateralAmount.mulDiv(1e18, debtValue);

        return collateralRatio >= minCollateralRatio;
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

    /**
     * @notice Emergency liquidation (bypasses normal checks)
     * 
     * @param user User to liquidate
     * @param debtToCover Debt to cover
     * 
     * @dev Only used in major crises
     *      Allows liquidation even if the oracle is down
     */
    function emergencyLiquidate(
        address user,
        uint256 debtToCover
    ) external onlyRole(EMERGENCY_ROLE) {
        require(userDebt[user] >= debtToCover, "Vault: Insufficient debt");
        
        // Liquidation with last known price
        uint256 collateralToSeize = debtToCover.mulDiv(
            lastValidEurUsdPrice,
            1e18
        );
        
        // Apply liquidation bonus
        collateralToSeize = collateralToSeize.mulDiv(
            1e18 + liquidationPenalty,
            1e18
        );

        require(userCollateral[user] >= collateralToSeize, "Vault: Insufficient collateral");

        // Execute liquidation
        qeuro.burn(msg.sender, debtToCover);
        
        userCollateral[user] -= collateralToSeize;
        userDebt[user] -= debtToCover;
        
        totalCollateral -= collateralToSeize;
        totalMinted -= debtToCover;
        
        usdc.safeTransfer(msg.sender, collateralToSeize);

        emit UserLiquidated(user, msg.sender, collateralToSeize, debtToCover);
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
     */
    function recoverETH(address payable to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(to != address(0), "Vault: Cannot send to zero address");
        require(address(this).balance > 0, "Vault: No ETH to recover");
        
        to.transfer(address(this).balance);
    }

    // =============================================================================
    // ADVANCED VIEW FUNCTIONS - Advanced read functions
    // =============================================================================

    /**
     * @notice Retrieves the list of liquidatable users
     * 
     * @param maxUsers Maximum number of users to return
     * @return liquidatableUsers Addresses of liquidatable users
     * @return debtAmounts Corresponding debts
     * 
     * @dev Gas-expensive function, use off-chain only
     */
    function getLiquidatableUsers(uint256 maxUsers) 
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

    /**
     * @notice Simulates a liquidation and returns the amounts
     * 
     * @param user User to simulate
     * @param debtToCover Debt to cover
     * @return collateralToSeize Collateral that would be seized
     * @return liquidatorProfit Profit for the liquidator
     * @return isValidLiquidation true if the liquidation is valid
     */
    function simulateLiquidation(address user, uint256 debtToCover)
        external
        view
        returns (
            uint256 collateralToSeize,
            uint256 liquidatorProfit,
            bool isValidLiquidation
        )
    {
        // Basic checks
        if (!_isLiquidatable(user) || userDebt[user] < debtToCover) {
            return (0, 0, false);
        }

        (uint256 eurUsdPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) return (0, 0, false);

        // Calculations
        uint256 collateralValue = debtToCover.mulDiv(eurUsdPrice, 1e18);
        collateralToSeize = collateralValue.mulDiv(1e18 + liquidationPenalty, 1e18);
        
        if (userCollateral[user] >= collateralToSeize) {
            liquidatorProfit = collateralToSeize - collateralValue;
            isValidLiquidation = true;
        }
    }

    /**
     * @notice Retrieves current vault parameters
     * 
     * @return minCollateralRatio_ Minimum collateral ratio
     * @return liquidationThreshold_ Liquidation threshold
     * @return liquidationPenalty_ Liquidation penalty
     * @return protocolFee_ Protocol fee
     * @return qeuroAddress QEURO token address
     * @return usdcAddress USDC token address
     * @return oracleAddress Oracle address
     */
    function getVaultParameters() 
        external 
        view 
        returns (
            uint256 minCollateralRatio_,
            uint256 liquidationThreshold_,
            uint256 liquidationPenalty_,
            uint256 protocolFee_,
            address qeuroAddress,
            address usdcAddress,
            address oracleAddress
        ) 
    {
        return (
            minCollateralRatio,
            liquidationThreshold,
            liquidationPenalty,
            protocolFee,
            address(qeuro),
            address(usdc),
            address(oracle)
        );
    }

    /// @notice Variable to store the last valid EUR/USD price (emergency state)
    uint256 private lastValidEurUsdPrice;
}

// =============================================================================
// END OF QUANTILLONVAULT CONTRACT
// =============================================================================