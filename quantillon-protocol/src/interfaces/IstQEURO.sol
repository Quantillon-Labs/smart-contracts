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
     * @param admin Admin address
     * @param _qeuro QEURO token address
     * @param _yieldShift YieldShift contract address
     * @param _usdc USDC token address
     * @param _treasury Treasury address
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
     */
    function updateYieldParameters(
        uint256 _yieldFee,
        uint256 _minYieldThreshold,
        uint256 _maxUpdateFrequency
    ) external;

    /**
     * @notice Update treasury address
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
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);

    // ERC20 functions
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

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
    function YIELD_MANAGER_ROLE() external view returns (bytes32);
    function EMERGENCY_ROLE() external view returns (bytes32);
    function UPGRADER_ROLE() external view returns (bytes32);

    // State variables
    function qeuro() external view returns (address);
    function yieldShift() external view returns (address);
    function usdc() external view returns (address);
    function treasury() external view returns (address);
    function exchangeRate() external view returns (uint256);
    function lastUpdateTime() external view returns (uint256);
    function totalUnderlying() external view returns (uint256);
    function totalYieldEarned() external view returns (uint256);
    function yieldFee() external view returns (uint256);
    function minYieldThreshold() external view returns (uint256);
    function maxUpdateFrequency() external view returns (uint256);
}
