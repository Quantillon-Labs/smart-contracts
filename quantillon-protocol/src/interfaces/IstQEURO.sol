// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IstQEURO
 * @notice Interface for the stQEURO yield-bearing wrapper token (yield accrual mechanism)
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
interface IstQEURO {
    /**
     * @notice Initializes the stQEURO token
     * @dev Sets up the stQEURO token with initial configuration and assigns roles to admin
     * @param admin Admin address
     * @param _qeuro QEURO token address
     * @param _yieldShift YieldShift contract address
     * @param _usdc USDC token address
     * @param _treasury Treasury address
     * @param timelock Timelock contract address
     */
    function initialize(
        address admin,
        address _qeuro,
        address _yieldShift,
        address _usdc,
        address _treasury,
        address timelock
    ) external;

    /**
     * @notice Stake QEURO to receive stQEURO
     * @dev Converts QEURO to stQEURO at current exchange rate with yield accrual
     * @param qeuroAmount Amount of QEURO to stake
     * @return stQEUROAmount Amount of stQEURO received
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function stake(uint256 qeuroAmount) external returns (uint256 stQEUROAmount);

    /**
     * @notice Unstake QEURO by burning stQEURO
     * @dev Converts stQEURO back to QEURO at current exchange rate
     * @param stQEUROAmount Amount of stQEURO to burn
     * @return qeuroAmount Amount of QEURO received
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function unstake(uint256 stQEUROAmount) external returns (uint256 qeuroAmount);

    /**
     * @notice Batch stake QEURO amounts
     * @dev Efficiently stakes multiple QEURO amounts in a single transaction
     * @param qeuroAmounts Array of QEURO amounts
     * @return stQEUROAmounts Array of stQEURO minted
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function batchStake(uint256[] calldata qeuroAmounts) external returns (uint256[] memory stQEUROAmounts);

    /**
     * @notice Batch unstake stQEURO amounts
     * @dev Efficiently unstakes multiple stQEURO amounts in a single transaction
     * @param stQEUROAmounts Array of stQEURO amounts
     * @return qeuroAmounts Array of QEURO returned
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function batchUnstake(uint256[] calldata stQEUROAmounts) external returns (uint256[] memory qeuroAmounts);

    /**
     * @notice Batch transfer stQEURO to multiple recipients
     * @dev Efficiently transfers stQEURO to multiple recipients in a single transaction
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts to transfer
     * @return success True if all transfers succeeded
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) external returns (bool);

    /**
     * @notice Distribute yield to stQEURO holders (increases exchange rate)
     * @dev Distributes yield by increasing the exchange rate for all stQEURO holders
     * @param yieldAmount Amount of yield in USDC
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function distributeYield(uint256 yieldAmount) external;

    /**
     * @notice Claim accumulated yield for a user (in USDC)
     * @dev Claims the user's accumulated yield and transfers it to their address
     * @return yieldAmount Amount of yield claimed
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function claimYield() external returns (uint256 yieldAmount);

    /**
     * @notice Get pending yield for a user (in USDC)
     * @dev Returns the amount of yield available for a specific user to claim
     * @param user User address
     * @return yieldAmount Pending yield amount
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getPendingYield(address user) external view returns (uint256 yieldAmount);

    /**
     * @notice Get current exchange rate between QEURO and stQEURO
     * @dev Returns the current exchange rate used for staking/unstaking operations
     * @return exchangeRate Current exchange rate (18 decimals)
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getExchangeRate() external view returns (uint256);

    /**
     * @notice Get total value locked in stQEURO
     * @dev Returns the total value locked in the stQEURO system
     * @return tvl Total value locked (18 decimals)
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getTVL() external view returns (uint256);

    /**
     * @notice Get user's QEURO equivalent balance
     * @dev Returns the QEURO equivalent value of a user's stQEURO balance
     * @param user User address
     * @return qeuroEquivalent QEURO equivalent of stQEURO balance
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getQEUROEquivalent(address user) external view returns (uint256 qeuroEquivalent);

    /**
     * @notice Get staking statistics
     * @dev Returns comprehensive staking statistics and metrics
     * @return totalStQEUROSupply Total stQEURO supply
     * @return totalQEUROUnderlying Total QEURO underlying
     * @return currentExchangeRate Current exchange rate
     * @return _totalYieldEarned Total yield earned
     * @return apy Annual percentage yield
      * @custom:security Validates input parameters and enforces security checks
      * @custom:validation Validates input parameters and business logic constraints
      * @custom:state-changes Updates contract state variables
      * @custom:events Emits relevant events for state changes
      * @custom:errors Throws custom errors for invalid conditions
      * @custom:reentrancy Protected by reentrancy guard
      * @custom:access Restricted to authorized roles
      * @custom:oracle Requires fresh oracle price data
     */
    function getStakingStats() external view returns (
        uint256 totalStQEUROSupply,
        uint256 totalQEUROUnderlying,
        uint256 currentExchangeRate,
        uint256 _totalYieldEarned,
        uint256 apy
    );

    /**
     * @notice Update yield parameters
     * @dev Updates yield-related parameters with security checks
     * @param _yieldFee New yield fee percentage
     * @param _minYieldThreshold New minimum yield threshold
     * @param _maxUpdateFrequency New maximum update frequency
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function updateYieldParameters(
        uint256 _yieldFee,
        uint256 _minYieldThreshold,
        uint256 _maxUpdateFrequency
    ) external;

    /**
     * @notice Update treasury address
     * @dev Updates the treasury address for yield distribution
     * @param _treasury New treasury address
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function updateTreasury(address _treasury) external;

    /**
     * @notice Pause the contract
     * @dev Pauses all stQEURO operations for emergency situations
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
     * @notice Unpause the contract
     * @dev Resumes all stQEURO operations after being paused
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
     * @notice Emergency withdrawal of QEURO
     * @dev Allows emergency withdrawal of QEURO for a specific user
     * @param user User address to withdraw for
     * @custom:security Validates input parameters and enforces security checks
     * @custom:validation Validates input parameters and business logic constraints
     * @custom:state-changes Updates contract state variables
     * @custom:events Emits relevant events for state changes
     * @custom:errors Throws custom errors for invalid conditions
     * @custom:reentrancy Protected by reentrancy guard
     * @custom:access Restricted to authorized roles
     * @custom:oracle Requires fresh oracle price data
     */
    function emergencyWithdraw(address user) external;

    /**
     * @notice Recover accidentally sent tokens
     * @dev Allows recovery of ERC20 tokens accidentally sent to the contract
     * @param token Token address to recover
     * @param to Recipient address
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
     * @notice Recover accidentally sent ETH
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

    // View functions for token metadata
    /**
     * @notice Returns the name of the token
     * @dev Returns the token name for display purposes
     * @return The token name
     */
    function name() external view returns (string memory);
    
    /**
     * @notice Returns the symbol of the token
     * @dev Returns the token symbol for display purposes
     * @return The token symbol
     */
    function symbol() external view returns (string memory);
    
    /**
     * @notice Returns the decimals of the token
     * @dev Returns the number of decimals used for token amounts
     * @return The number of decimals
     */
    function decimals() external view returns (uint8);
    
    /**
     * @notice Returns the total supply of the token
     * @dev Returns the total amount of tokens in existence
     * @return The total supply
     */
    function totalSupply() external view returns (uint256);
    
    /**
     * @notice Returns the balance of an account
     * @dev Returns the token balance of the specified account
     * @param account The account to check
     * @return The balance of the account
     */
    function balanceOf(address account) external view returns (uint256);

    // ERC20 functions
    /**
     * @notice Transfers tokens to a recipient
     * @dev Transfers the specified amount of tokens to the recipient
     * @param to The recipient address
     * @param amount The amount to transfer
     * @return True if the transfer succeeded
     */
    function transfer(address to, uint256 amount) external returns (bool);
    
    /**
     * @notice Returns the allowance for a spender
     * @dev Returns the amount of tokens that the spender is allowed to spend
     * @param owner The owner address
     * @param spender The spender address
     * @return The allowance amount
     */
    function allowance(address owner, address spender) external view returns (uint256);
    
    /**
     * @notice Approves a spender to spend tokens
     * @dev Sets the allowance for the spender to spend tokens on behalf of the caller
     * @param spender The spender address
     * @param amount The amount to approve
     * @return True if the approval succeeded
     */
    function approve(address spender, uint256 amount) external returns (bool);
    
    /**
     * @notice Transfers tokens from one account to another
     * @dev Transfers tokens from the from account to the to account
     * @param from The sender address
     * @param to The recipient address
     * @param amount The amount to transfer
     * @return True if the transfer succeeded
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    // AccessControl functions
    /**
     * @notice Checks if an account has a specific role
     * @dev Returns true if the account has been granted the role
     * @param role The role to check
     * @param account The account to check
     * @return True if the account has the role
     */
    function hasRole(bytes32 role, address account) external view returns (bool);
    
    /**
     * @notice Returns the admin role for a role
     * @dev Returns the role that is the admin of the given role
     * @param role The role to check
     * @return The admin role
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    
    /**
     * @notice Grants a role to an account
     * @dev Grants the specified role to the account
     * @param role The role to grant
     * @param account The account to grant the role to
     */
    function grantRole(bytes32 role, address account) external;
    
    /**
     * @notice Revokes a role from an account
     * @dev Revokes the specified role from the account
     * @param role The role to revoke
     * @param account The account to revoke the role from
     */
    function revokeRole(bytes32 role, address account) external;
    
    /**
     * @notice Renounces a role
     * @dev Renounces the specified role from the caller
     * @param role The role to renounce
     * @param callerConfirmation The caller confirmation
     */
    function renounceRole(bytes32 role, address callerConfirmation) external;

    // Pausable functions
    /**
     * @notice Returns the paused state
     * @dev Returns true if the contract is paused
     * @return True if paused
     */
    function paused() external view returns (bool);

    // UUPS functions
    /**
     * @notice Upgrades the implementation
     * @dev Upgrades the contract to a new implementation
     * @param newImplementation The new implementation address
     */
    function upgradeTo(address newImplementation) external;
    
    /**
     * @notice Upgrades the implementation and calls a function
     * @dev Upgrades the contract and calls a function on the new implementation
     * @param newImplementation The new implementation address
     * @param data The function call data
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;

    // Constants
    /**
     * @notice Returns the governance role
     * @dev Returns the role identifier for governance functions
     * @return The governance role
     */
    function GOVERNANCE_ROLE() external view returns (bytes32);
    
    /**
     * @notice Returns the yield manager role
     * @dev Returns the role identifier for yield management functions
     * @return The yield manager role
     */
    function YIELD_MANAGER_ROLE() external view returns (bytes32);
    
    /**
     * @notice Returns the emergency role
     * @dev Returns the role identifier for emergency functions
     * @return The emergency role
     */
    function EMERGENCY_ROLE() external view returns (bytes32);
    
    /**
     * @notice Returns the upgrader role
     * @dev Returns the role identifier for upgrade functions
     * @return The upgrader role
     */
    function UPGRADER_ROLE() external view returns (bytes32);

    // State variables
    /**
     * @notice Returns the QEURO token address
     * @dev Returns the address of the underlying QEURO token
     * @return The QEURO token address
     */
    function qeuro() external view returns (address);
    
    /**
     * @notice Returns the YieldShift contract address
     * @dev Returns the address of the YieldShift contract
     * @return The YieldShift contract address
     */
    function yieldShift() external view returns (address);
    
    /**
     * @notice Returns the USDC token address
     * @dev Returns the address of the USDC token
     * @return The USDC token address
     */
    function usdc() external view returns (address);
    
    /**
     * @notice Returns the treasury address
     * @dev Returns the address of the treasury contract
     * @return The treasury address
     */
    function treasury() external view returns (address);
    
    /**
     * @notice Returns the current exchange rate
     * @dev Returns the current exchange rate between QEURO and stQEURO
     * @return The current exchange rate
     */
    function exchangeRate() external view returns (uint256);
    
    /**
     * @notice Returns the last update time
     * @dev Returns the timestamp of the last exchange rate update
     * @return The last update time
     */
    function lastUpdateTime() external view returns (uint256);
    
    /**
     * @notice Returns the total underlying QEURO
     * @dev Returns the total amount of QEURO underlying all stQEURO
     * @return The total underlying QEURO
     */
    function totalUnderlying() external view returns (uint256);
    
    /**
     * @notice Returns the total yield earned
     * @dev Returns the total amount of yield earned by all stQEURO holders
     * @return The total yield earned
     */
    function totalYieldEarned() external view returns (uint256);
    
    /**
     * @notice Returns the yield fee percentage
     * @dev Returns the percentage of yield that goes to the treasury
     * @return The yield fee percentage
     */
    function yieldFee() external view returns (uint256);
    
    /**
     * @notice Returns the minimum yield threshold
     * @dev Returns the minimum yield amount required for distribution
     * @return The minimum yield threshold
     */
    function minYieldThreshold() external view returns (uint256);
    
    /**
     * @notice Returns the maximum update frequency
     * @dev Returns the maximum frequency for exchange rate updates
     * @return The maximum update frequency
     */
    function maxUpdateFrequency() external view returns (uint256);
}
