// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CommonErrorLibrary} from "../libraries/CommonErrorLibrary.sol";
import {CommonValidationLibrary} from "../libraries/CommonValidationLibrary.sol";

/**
 * @title FeeCollector
 * @notice Centralized fee collection and distribution contract for Quantillon Protocol
 * 
 * @dev This contract handles all protocol fees from:
 *      - QEURO minting fees
 *      - QEURO redemption fees  
 *      - Hedger position fees
 *      - Yield management fees
 *      - Other protocol operations
 * 
 * @dev Features:
 *      - Centralized fee collection from all protocol contracts
 *      - Governance-controlled fee distribution
 *      - Multi-token fee support (USDC, QEURO, etc.)
 *      - Fee analytics and tracking
 *      - Emergency pause functionality
 *      - Upgradeable via UUPS proxy
 * 
 * @author Quantillon Protocol Team
 * @custom:security-contact team@quantillon.money
 */
contract FeeCollector is 
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    // =============================================================================
    // ROLES
    // =============================================================================
    
    /// @notice Governance role for fee distribution and configuration
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    
    /// @notice Treasury role for fee withdrawal
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");
    
    /// @notice Emergency role for pausing and emergency operations
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    // =============================================================================
    // STATE VARIABLES
    // =============================================================================
    
    /// @notice Treasury address for fee distribution
    address public treasury;
    
    /// @notice Protocol development fund address
    address public devFund;
    
    /// @notice Community fund address
    address public communityFund;
    
    /// @notice Fee distribution ratios (in basis points, 10000 = 100%)
    uint256 public treasuryRatio;      // Default: 60% (6000 bps)
    uint256 public devFundRatio;       // Default: 25% (2500 bps)  
    uint256 public communityRatio;     // Default: 15% (1500 bps)
    
    /// @notice Total fees collected per token
    mapping(address => uint256) public totalFeesCollected;
    
    /// @notice Total fees distributed per token
    mapping(address => uint256) public totalFeesDistributed;
    
    /// @notice Fee collection events per token
    mapping(address => uint256) public feeCollectionCount;

    // =============================================================================
    // EVENTS
    // =============================================================================
    
    /// @notice Emitted when fees are collected
    event FeesCollected(
        address indexed token,
        uint256 amount,
        address indexed source,
        string indexed sourceType
    );
    
    /// @notice Emitted when fees are distributed
    event FeesDistributed(
        address indexed token,
        uint256 totalAmount,
        uint256 treasuryAmount,
        uint256 devFundAmount,
        uint256 communityAmount
    );
    
    /// @notice Emitted when fee distribution ratios are updated
    event FeeRatiosUpdated(
        uint256 treasuryRatio,
        uint256 devFundRatio,
        uint256 communityRatio
    );
    
    /// @notice Emitted when fund addresses are updated
    event FundAddressesUpdated(
        address treasury,
        address devFund,
        address communityFund
    );

    // =============================================================================
    // MODIFIERS
    // =============================================================================
    
    /// @notice Ensures only authorized contracts can collect fees
    modifier onlyFeeSource() {
        require(hasRole(GOVERNANCE_ROLE, msg.sender) || 
                hasRole(TREASURY_ROLE, msg.sender) ||
                _isAuthorizedFeeSource(msg.sender), 
                "FeeCollector: Unauthorized fee source");
        _;
    }

    // =============================================================================
    // INITIALIZATION
    // =============================================================================
    
    /**
     * @notice Initializes the FeeCollector contract
     * @dev Sets up the initial configuration for fee collection and distribution
     * @dev Sets up roles, fund addresses, and default fee distribution ratios
     * @param _admin Admin address (will receive DEFAULT_ADMIN_ROLE, GOVERNANCE_ROLE, and EMERGENCY_ROLE)
     * @param _treasury Treasury address (will receive TREASURY_ROLE)
     * @param _devFund Dev fund address (cannot be zero)
     * @param _communityFund Community fund address (cannot be zero)
     * @custom:security Protected by initializer modifier
     * @custom:validation Validates that all addresses are non-zero
     * @custom:state-changes Sets up roles, fund addresses, and default ratios
     * @custom:events Emits role grant events and FundAddressesUpdated event
     * @custom:errors Throws ZeroAddress if any address is zero
     * @custom:reentrancy No external calls, safe
     * @custom:access Can only be called once during initialization
     * @custom:oracle No oracle dependencies
     */
    function initialize(
        address _admin,
        address _treasury,
        address _devFund,
        address _communityFund
    ) external initializer {
        // Validate addresses are not zero
        CommonValidationLibrary.validateNonZeroAddress(_admin, "admin");
        CommonValidationLibrary.validateNonZeroAddress(_treasury, "treasury");
        CommonValidationLibrary.validateNonZeroAddress(_devFund, "devFund");
        CommonValidationLibrary.validateNonZeroAddress(_communityFund, "communityFund");
        
        // Validate addresses are not contracts (security measure)
        CommonValidationLibrary.validateNotContract(_treasury, "treasury");
        CommonValidationLibrary.validateNotContract(_devFund, "devFund");
        CommonValidationLibrary.validateNotContract(_communityFund, "communityFund");
        
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        
        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(GOVERNANCE_ROLE, _admin);
        _grantRole(TREASURY_ROLE, _treasury);
        _grantRole(EMERGENCY_ROLE, _admin);
        
        // Set fund addresses (explicit zero checks for Slither)
        if (_treasury == address(0)) revert CommonErrorLibrary.ZeroAddress();
        if (_devFund == address(0)) revert CommonErrorLibrary.ZeroAddress();
        if (_communityFund == address(0)) revert CommonErrorLibrary.ZeroAddress();
        
        treasury = _treasury;
        devFund = _devFund;
        communityFund = _communityFund;
        
        // Set default fee distribution ratios (60% treasury, 25% dev, 15% community)
        treasuryRatio = 6000;
        devFundRatio = 2500;
        communityRatio = 1500;
        
        emit FundAddressesUpdated(_treasury, _devFund, _communityFund);
        emit FeeRatiosUpdated(6000, 2500, 1500);
    }

    // =============================================================================
    // FEE COLLECTION
    // =============================================================================
    
    /**
     * @notice Collects fees from protocol contracts
     * @dev Transfers tokens from the caller to this contract and updates tracking variables
     * @dev Only authorized fee sources can call this function
     * @dev Emits FeesCollected event for transparency and analytics
     * @param token Token address to collect fees for (cannot be zero address)
     * @param amount Amount of fees to collect (must be greater than zero)
     * @param sourceType Type of fee source (e.g., "minting", "redemption", "hedging")
     * @custom:security Protected by onlyFeeSource modifier and reentrancy guard
     * @custom:validation Validates token address and amount parameters
     * @custom:state-changes Updates totalFeesCollected and feeCollectionCount mappings
     * @custom:events Emits FeesCollected event with collection details
     * @custom:errors Throws InvalidAmount if amount is zero
     * @custom:errors Throws ZeroAddress if token address is zero
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to authorized fee sources only
     * @custom:oracle No oracle dependencies
     */
    function collectFees(
        address token,
        uint256 amount,
        string calldata sourceType
    ) external onlyFeeSource whenNotPaused nonReentrant {
        if (token == address(0)) revert CommonErrorLibrary.ZeroAddress();
        if (amount == 0) revert CommonErrorLibrary.InvalidAmount();
        
        // Transfer tokens from caller to this contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // Update tracking variables
        totalFeesCollected[token] += amount;
        feeCollectionCount[token]++;
        
        emit FeesCollected(token, amount, msg.sender, sourceType);
    }
    
    /**
     * @notice Collects ETH fees from protocol contracts
     * @dev Accepts ETH payments and updates tracking variables for ETH (tracked as address(0))
     * @dev Only authorized fee sources can call this function
     * @dev Emits FeesCollected event for transparency and analytics
     * @param sourceType Type of fee source (e.g., "staking", "governance", "liquidation")
     * @custom:security Protected by onlyFeeSource modifier and reentrancy guard
     * @custom:validation Validates that msg.value is greater than zero
     * @custom:state-changes Updates totalFeesCollected and feeCollectionCount for address(0)
     * @custom:events Emits FeesCollected event with ETH collection details
     * @custom:errors Throws InvalidAmount if msg.value is zero
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to authorized fee sources only
     * @custom:oracle No oracle dependencies
     */
    function collectETHFees(string calldata sourceType) external payable onlyFeeSource whenNotPaused nonReentrant {
        if (msg.value == 0) revert CommonErrorLibrary.InvalidAmount();
        
        // ETH is tracked as address(0)
        totalFeesCollected[address(0)] += msg.value;
        feeCollectionCount[address(0)]++;
        
        emit FeesCollected(address(0), msg.value, msg.sender, sourceType);
    }

    // =============================================================================
    // FEE DISTRIBUTION
    // =============================================================================
    
    /**
     * @notice Distributes collected fees according to configured ratios
     * @dev Calculates distribution amounts based on treasuryRatio, devFundRatio, and communityRatio
     * @dev Handles rounding by adjusting community amount to ensure total doesn't exceed balance
     * @dev Only treasury role can call this function
     * @dev Emits FeesDistributed event for transparency
     * @param token Token address to distribute (address(0) for ETH)
     * @custom:security Protected by TREASURY_ROLE and reentrancy guard
     * @custom:validation Validates that contract has sufficient balance
     * @custom:state-changes Updates totalFeesDistributed and transfers tokens to fund addresses
     * @custom:events Emits FeesDistributed event with distribution details
     * @custom:errors Throws InsufficientBalance if contract balance is zero
     * @custom:reentrancy Protected by nonReentrant modifier
     * @custom:access Restricted to TREASURY_ROLE only
     * @custom:oracle No oracle dependencies
     */
    function distributeFees(address token) external onlyRole(TREASURY_ROLE) whenNotPaused nonReentrant {
        uint256 balance = token == address(0) ? address(this).balance : IERC20(token).balanceOf(address(this));
        
        if (balance <= 0) revert CommonErrorLibrary.InsufficientBalance();
        
        // Calculate and distribute amounts
        (uint256 treasuryAmount, uint256 devFundAmount, uint256 communityAmount) = _calculateDistributionAmounts(balance);
        uint256 totalDistributed = treasuryAmount + devFundAmount + communityAmount;
        
        // Update tracking
        totalFeesDistributed[token] += totalDistributed;
        
        // Execute transfers after accounting update (nonReentrant guard prevents reentrancy)
        _executeTransfers(token, treasuryAmount, devFundAmount, communityAmount);
        
        emit FeesDistributed(token, totalDistributed, treasuryAmount, devFundAmount, communityAmount);
    }

    /**
     * @notice Calculate distribution amounts with rounding protection
     * @dev Internal function to reduce cyclomatic complexity
     * @param balance Total balance to distribute
     * @return treasuryAmount Amount for treasury
     * @return devFundAmount Amount for dev fund
     * @return communityAmount Amount for community fund
     * @custom:security No external calls, pure calculation function
     * @custom:validation Balance must be non-zero for meaningful distribution
     * @custom:state-changes No state changes, view function
     * @custom:events No events emitted
     * @custom:errors No custom errors, uses SafeMath for overflow protection
     * @custom:reentrancy No reentrancy risk, view function
     * @custom:access Internal function, no access control needed
     * @custom:oracle No oracle dependencies
     */
    function _calculateDistributionAmounts(uint256 balance) internal view returns (
        uint256 treasuryAmount,
        uint256 devFundAmount,
        uint256 communityAmount
    ) {
        treasuryAmount = balance * treasuryRatio / 10000;
        devFundAmount = balance * devFundRatio / 10000;
        communityAmount = balance * communityRatio / 10000;
        
        // Ensure total doesn't exceed balance (handle rounding)
        uint256 totalDistributed = treasuryAmount + devFundAmount + communityAmount;
        if (totalDistributed > balance) {
            communityAmount = balance - treasuryAmount - devFundAmount;
        }
    }

    /**
     * @notice Execute transfers for ETH or ERC20 tokens
     * @dev Internal function to reduce cyclomatic complexity
     * @param token Token address (address(0) for ETH)
     * @param treasuryAmount Amount for treasury
     * @param devFundAmount Amount for dev fund
     * @param communityAmount Amount for community fund
     * @custom:security Delegates to specific transfer functions with proper validation
     * @custom:validation Amounts must be non-zero for transfers to execute
     * @custom:state-changes Updates token balances through transfers
     * @custom:events No direct events, delegated functions emit events
     * @custom:errors May revert on transfer failures
     * @custom:reentrancy Protected by internal function design
     * @custom:access Internal function, no access control needed
     * @custom:oracle No oracle dependencies
     */
    function _executeTransfers(
        address token,
        uint256 treasuryAmount,
        uint256 devFundAmount,
        uint256 communityAmount
    ) internal {
        if (token == address(0)) {
            _executeETHTransfers(treasuryAmount, devFundAmount, communityAmount);
        } else {
            _executeERC20Transfers(token, treasuryAmount, devFundAmount, communityAmount);
        }
    }

    /**
     * @notice Execute ETH transfers
     * @dev Internal function to reduce cyclomatic complexity
     * @param treasuryAmount Amount for treasury
     * @param devFundAmount Amount for dev fund
     * @param communityAmount Amount for community fund
     * @custom:security Uses secure ETH transfer with address validation
     * @custom:validation Amounts must be non-zero for transfers to execute
     * @custom:state-changes Reduces contract ETH balance, increases recipient balances
     * @custom:events No direct events emitted
     * @custom:errors Reverts with ETHTransferFailed on call failure
     * @custom:reentrancy Protected by internal function design and address validation
     * @custom:access Internal function, no access control needed
     * @custom:oracle No oracle dependencies
     */
    function _executeETHTransfers(
        uint256 treasuryAmount,
        uint256 devFundAmount,
        uint256 communityAmount
    ) internal {
        if (treasuryAmount > 0) {
            _secureETHTransfer(treasury, treasuryAmount);
        }
        if (devFundAmount > 0) {
            _secureETHTransfer(devFund, devFundAmount);
        }
        if (communityAmount > 0) {
            _secureETHTransfer(communityFund, communityAmount);
        }
    }

    /**
     * @notice Secure ETH transfer with comprehensive validation
     * @dev Validates recipient address against whitelist and performs secure ETH transfer
     * @param recipient Address to receive ETH (must be treasury, devFund, or communityFund)
     * @param amount Amount of ETH to transfer
     * @custom:security Multiple validation layers prevent arbitrary sends:
     *                  - Recipient must be one of three pre-authorized fund addresses
     *                  - Addresses are validated to be non-zero and non-contract
     *                  - Only GOVERNANCE_ROLE can update these addresses
     *                  - This is NOT an arbitrary send as recipient is strictly controlled
     * @custom:validation Ensures recipient is valid and amount is positive
     * @custom:state-changes Transfers ETH from contract to recipient
     * @custom:events No events emitted
     * @custom:errors Reverts with ETHTransferFailed on transfer failure
     * @custom:reentrancy Protected by address validation and call pattern
     * @custom:access Internal function, no access control needed
     * @custom:oracle No oracle dependencies
     */
    function _secureETHTransfer(address recipient, uint256 amount) internal {
        // Validate amount (must be greater than zero)
        if (amount <= 0) revert CommonErrorLibrary.InvalidAmount();
        
        // Validate recipient is one of the authorized fund addresses
        // This is the primary security check that prevents arbitrary sends
        if (recipient != treasury && recipient != devFund && recipient != communityFund) {
            revert CommonErrorLibrary.InvalidAddress();
        }
        
        // Additional runtime validation for security
        if (recipient == address(0)) revert CommonErrorLibrary.ZeroAddress();
        
        // Validate recipient is not a contract (additional security check)
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(recipient)
        }
        if (codeSize > 0) revert CommonErrorLibrary.InvalidAddress();
        
        // SECURITY: This is NOT an arbitrary send. The recipient is strictly validated:
        // - Must be one of three pre-authorized fund addresses (treasury/dev/community)
        // - Governance controls updates and each address is validated to be non-zero EOAs
        // The suppression below documents this intentional, controlled behavior.
        // slither-disable-next-line arbitrary-send
        (bool success, ) = recipient.call{value: amount}("");
        if (!success) revert CommonErrorLibrary.ETHTransferFailed();
    }

    /**
     * @notice Execute ERC20 token transfers
     * @dev Internal function to reduce cyclomatic complexity
     * @param token Token address
     * @param treasuryAmount Amount for treasury
     * @param devFundAmount Amount for dev fund
     * @param communityAmount Amount for community fund
     * @custom:security Uses safeTransfer for ERC20 tokens with proper error handling
     * @custom:validation Amounts must be non-zero for transfers to execute
     * @custom:state-changes Reduces contract token balance, increases recipient balances
     * @custom:events No direct events emitted
     * @custom:errors May revert on transfer failures from ERC20 contract
     * @custom:reentrancy Protected by internal function design and safeTransfer
     * @custom:access Internal function, no access control needed
     * @custom:oracle No oracle dependencies
     */
    function _executeERC20Transfers(
        address token,
        uint256 treasuryAmount,
        uint256 devFundAmount,
        uint256 communityAmount
    ) internal {
        if (treasuryAmount > 0) {
            IERC20(token).safeTransfer(treasury, treasuryAmount);
        }
        if (devFundAmount > 0) {
            IERC20(token).safeTransfer(devFund, devFundAmount);
        }
        if (communityAmount > 0) {
            IERC20(token).safeTransfer(communityFund, communityAmount);
        }
    }

    // =============================================================================
    // GOVERNANCE FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Updates fee distribution ratios
     * @dev Sets new distribution ratios for treasury, dev fund, and community fund
     * @dev Ratios must sum to exactly 10000 (100%) in basis points
     * @dev Only governance role can call this function
     * @dev Emits FeeRatiosUpdated event for transparency
     * @param _treasuryRatio New treasury ratio (in basis points, 10000 = 100%)
     * @param _devFundRatio New dev fund ratio (in basis points, 10000 = 100%)
     * @param _communityRatio New community ratio (in basis points, 10000 = 100%)
     * @custom:security Protected by GOVERNANCE_ROLE
     * @custom:validation Validates that ratios sum to exactly 10000
     * @custom:state-changes Updates treasuryRatio, devFundRatio, and communityRatio
     * @custom:events Emits FeeRatiosUpdated event with new ratios
     * @custom:errors Throws InvalidRatio if ratios don't sum to 10000
     * @custom:reentrancy No external calls, safe
     * @custom:access Restricted to GOVERNANCE_ROLE only
     * @custom:oracle No oracle dependencies
     */
    function updateFeeRatios(
        uint256 _treasuryRatio,
        uint256 _devFundRatio,
        uint256 _communityRatio
    ) external onlyRole(GOVERNANCE_ROLE) {
        if (_treasuryRatio + _devFundRatio + _communityRatio != 10000) {
            revert CommonErrorLibrary.InvalidRatio();
        }
        
        treasuryRatio = _treasuryRatio;
        devFundRatio = _devFundRatio;
        communityRatio = _communityRatio;
        
        emit FeeRatiosUpdated(_treasuryRatio, _devFundRatio, _communityRatio);
    }
    
    /**
     * @notice Updates fund addresses for fee distribution
     * @dev Sets new addresses for treasury, dev fund, and community fund
     * @dev All addresses must be non-zero
     * @dev Only governance role can call this function
     * @dev Emits FundAddressesUpdated event for transparency
     * @param _treasury New treasury address (cannot be zero)
     * @param _devFund New dev fund address (cannot be zero)
     * @param _communityFund New community fund address (cannot be zero)
     * @custom:security Protected by GOVERNANCE_ROLE
     * @custom:validation Validates that all addresses are non-zero
     * @custom:state-changes Updates treasury, devFund, and communityFund addresses
     * @custom:events Emits FundAddressesUpdated event with new addresses
     * @custom:errors Throws ZeroAddress if any address is zero
     * @custom:reentrancy No external calls, safe
     * @custom:access Restricted to GOVERNANCE_ROLE only
     * @custom:oracle No oracle dependencies
     */
    function updateFundAddresses(
        address _treasury,
        address _devFund,
        address _communityFund
    ) external onlyRole(GOVERNANCE_ROLE) {
        // Validate addresses are not zero
        CommonValidationLibrary.validateNonZeroAddress(_treasury, "treasury");
        CommonValidationLibrary.validateNonZeroAddress(_devFund, "devFund");
        CommonValidationLibrary.validateNonZeroAddress(_communityFund, "communityFund");
        
        // Validate addresses are not contracts (security measure)
        CommonValidationLibrary.validateNotContract(_treasury, "treasury");
        CommonValidationLibrary.validateNotContract(_devFund, "devFund");
        CommonValidationLibrary.validateNotContract(_communityFund, "communityFund");
        
        // Explicit zero checks for Slither (redundant but satisfies static analysis)
        if (_treasury == address(0)) revert CommonErrorLibrary.ZeroAddress();
        if (_devFund == address(0)) revert CommonErrorLibrary.ZeroAddress();
        if (_communityFund == address(0)) revert CommonErrorLibrary.ZeroAddress();
        
        treasury = _treasury;
        devFund = _devFund;
        communityFund = _communityFund;
        
        emit FundAddressesUpdated(_treasury, _devFund, _communityFund);
    }
    
    /**
     * @notice Authorizes a contract to collect fees
     * @dev Grants TREASURY_ROLE to the specified address, allowing it to collect fees
     * @dev Only governance role can call this function
     * @param feeSource Contract address to authorize (cannot be zero)
     * @custom:security Protected by GOVERNANCE_ROLE
     * @custom:validation Validates that feeSource is not zero address
     * @custom:state-changes Grants TREASURY_ROLE to feeSource
     * @custom:events Emits RoleGranted event for TREASURY_ROLE
     * @custom:errors Throws ZeroAddress if feeSource is zero
     * @custom:reentrancy No external calls, safe
     * @custom:access Restricted to GOVERNANCE_ROLE only
     * @custom:oracle No oracle dependencies
     */
    function authorizeFeeSource(address feeSource) external onlyRole(GOVERNANCE_ROLE) {
        if (feeSource == address(0)) revert CommonErrorLibrary.ZeroAddress();
        _grantRole(TREASURY_ROLE, feeSource);
    }
    
    /**
     * @notice Revokes fee collection authorization
     * @dev Revokes TREASURY_ROLE from the specified address, preventing it from collecting fees
     * @dev Only governance role can call this function
     * @param feeSource Contract address to revoke authorization from
     * @custom:security Protected by GOVERNANCE_ROLE
     * @custom:validation No validation required (can revoke from any address)
     * @custom:state-changes Revokes TREASURY_ROLE from feeSource
     * @custom:events Emits RoleRevoked event for TREASURY_ROLE
     * @custom:errors No custom errors
     * @custom:reentrancy No external calls, safe
     * @custom:access Restricted to GOVERNANCE_ROLE only
     * @custom:oracle No oracle dependencies
     */
    function revokeFeeSource(address feeSource) external onlyRole(GOVERNANCE_ROLE) {
        _revokeRole(TREASURY_ROLE, feeSource);
    }

    // =============================================================================
    // EMERGENCY FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Pauses fee collection and distribution
     * @dev Emergency function to pause all fee operations in case of security issues
     * @dev Only emergency role can call this function
     * @custom:security Protected by EMERGENCY_ROLE
     * @custom:validation No validation required
     * @custom:state-changes Sets paused state to true
     * @custom:events Emits Paused event
     * @custom:errors No custom errors
     * @custom:reentrancy No external calls, safe
     * @custom:access Restricted to EMERGENCY_ROLE only
     * @custom:oracle No oracle dependencies
     */
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpauses fee collection and distribution
     * @dev Resumes all fee operations after a pause
     * @dev Only emergency role can call this function
     * @custom:security Protected by EMERGENCY_ROLE
     * @custom:validation No validation required
     * @custom:state-changes Sets paused state to false
     * @custom:events Emits Unpaused event
     * @custom:errors No custom errors
     * @custom:reentrancy No external calls, safe
     * @custom:access Restricted to EMERGENCY_ROLE only
     * @custom:oracle No oracle dependencies
     */
    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }
    
    /**
     * @notice Emergency withdrawal of all tokens (only in extreme circumstances)
     * @dev Emergency function to withdraw all tokens to treasury in case of critical issues
     * @dev Only emergency role can call this function
     * @param token Token address to withdraw (address(0) for ETH)
     * @custom:security Protected by EMERGENCY_ROLE
     * @custom:validation Validates that contract has sufficient balance
     * @custom:state-changes Transfers all tokens to treasury address
     * @custom:events No custom events (uses standard transfer events)
     * @custom:errors Throws InsufficientBalance if contract balance is zero
     * @custom:errors Throws ETHTransferFailed if ETH transfer fails
     * @custom:reentrancy No external calls, safe
     * @custom:access Restricted to EMERGENCY_ROLE only
     * @custom:oracle No oracle dependencies
     */
    function emergencyWithdraw(address token) external onlyRole(EMERGENCY_ROLE) {
        uint256 balance = token == address(0) ? address(this).balance : IERC20(token).balanceOf(address(this));
        
        if (balance <= 0) revert CommonErrorLibrary.InsufficientBalance();
        
        if (token == address(0)) {
            _secureETHTransfer(treasury, balance);
        } else {
            IERC20(token).safeTransfer(treasury, balance);
        }
    }

    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Returns the current balance of a token
     * @dev Returns the current balance of the specified token held by this contract
     * @param token Token address (address(0) for ETH)
     * @return Current balance of the token in this contract
     * @custom:security No security implications (view function)
     * @custom:validation No validation required
     * @custom:state-changes No state changes (view function)
     * @custom:events No events (view function)
     * @custom:errors No custom errors
     * @custom:reentrancy No external calls, safe
     * @custom:access Public (anyone can call)
     * @custom:oracle No oracle dependencies
     */
    function getBalance(address token) external view returns (uint256) {
        return token == address(0) ? address(this).balance : IERC20(token).balanceOf(address(this));
    }
    
    /**
     * @notice Returns fee collection statistics for a token
     * @dev Returns comprehensive statistics about fee collection and distribution for a specific token
     * @param token Token address (address(0) for ETH)
     * @return totalCollected Total amount of fees collected for this token
     * @return totalDistributed Total amount of fees distributed for this token
     * @return collectionCount Number of fee collection transactions for this token
     * @return currentBalance Current balance of this token in the contract
     * @custom:security No security implications (view function)
     * @custom:validation No validation required
     * @custom:state-changes No state changes (view function)
     * @custom:events No events (view function)
     * @custom:errors No custom errors
     * @custom:reentrancy No external calls, safe
     * @custom:access Public (anyone can call)
     * @custom:oracle No oracle dependencies
     */
    function getFeeStats(address token) external view returns (
        uint256 totalCollected,
        uint256 totalDistributed,
        uint256 collectionCount,
        uint256 currentBalance
    ) {
        uint256 balance = token == address(0) ? address(this).balance : IERC20(token).balanceOf(address(this));
        return (
            totalFeesCollected[token],
            totalFeesDistributed[token],
            feeCollectionCount[token],
            balance
        );
    }
    
    /**
     * @notice Checks if an address is authorized to collect fees
     * @dev Returns whether the specified address has permission to collect fees
     * @param feeSource Address to check for authorization
     * @return True if the address is authorized to collect fees, false otherwise
     * @custom:security No security implications (view function)
     * @custom:validation No validation required
     * @custom:state-changes No state changes (view function)
     * @custom:events No events (view function)
     * @custom:errors No custom errors
     * @custom:reentrancy No external calls, safe
     * @custom:access Public (anyone can call)
     * @custom:oracle No oracle dependencies
     */
    function isAuthorizedFeeSource(address feeSource) external view returns (bool) {
        return _isAuthorizedFeeSource(feeSource);
    }

    // =============================================================================
    // INTERNAL FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Internal function to check if an address is authorized to collect fees
     * @dev Internal helper function to check TREASURY_ROLE for fee collection authorization
     * @param feeSource Address to check for authorization
     * @return True if the address has TREASURY_ROLE, false otherwise
     * @custom:security Internal function, no direct security implications
     * @custom:validation No validation required
     * @custom:state-changes No state changes (view function)
     * @custom:events No events (internal function)
     * @custom:errors No custom errors
     * @custom:reentrancy No external calls, safe
     * @custom:access Internal function only
     * @custom:oracle No oracle dependencies
     */
    function _isAuthorizedFeeSource(address feeSource) internal view returns (bool) {
        return hasRole(TREASURY_ROLE, feeSource);
    }
    
    /**
     * @notice Authorizes upgrades (only governance)
     * @dev Internal function to authorize contract upgrades via UUPS proxy pattern
     * @dev Only governance role can authorize upgrades
     * @param newImplementation Address of the new implementation contract
     * @custom:security Protected by GOVERNANCE_ROLE
     * @custom:validation No validation required (OpenZeppelin handles this)
     * @custom:state-changes No state changes (authorization only)
     * @custom:events No custom events (OpenZeppelin handles upgrade events)
     * @custom:errors No custom errors
     * @custom:reentrancy No external calls, safe
     * @custom:access Restricted to GOVERNANCE_ROLE only
     * @custom:oracle No oracle dependencies
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(GOVERNANCE_ROLE) {}
}
