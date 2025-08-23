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
        address _treasury
    ) external;

    /**
     * @notice Stake QEURO to receive stQEURO
     * @param qeuroAmount Amount of QEURO to stake
     * @return stQEUROAmount Amount of stQEURO received
     */
    function stake(uint256 qeuroAmount) external returns (uint256 stQEUROAmount);

    /**
     * @notice Unstake QEURO by burning stQEURO
     * @param stQEUROAmount Amount of stQEURO to burn
     * @return qeuroAmount Amount of QEURO received
     */
    function unstake(uint256 stQEUROAmount) external returns (uint256 qeuroAmount);

    /**
     * @notice Distribute yield to stQEURO holders (increases exchange rate)
     * @param yieldAmount Amount of yield in USDC
     */
    function distributeYield(uint256 yieldAmount) external;

    /**
     * @notice Claim accumulated yield for a user (in USDC)
     * @return yieldAmount Amount of yield claimed
     */
    function claimYield() external returns (uint256 yieldAmount);

    /**
     * @notice Get pending yield for a user (in USDC)
     * @param user User address
     * @return yieldAmount Pending yield amount
     */
    function getPendingYield(address user) external view returns (uint256 yieldAmount);

    /**
     * @notice Get current exchange rate between QEURO and stQEURO
     */
    function getExchangeRate() external view returns (uint256);

    /**
     * @notice Get total value locked in stQEURO
     */
    function getTVL() external view returns (uint256);

    /**
     * @notice Get user's QEURO equivalent balance
     * @param user User address
     * @return qeuroEquivalent QEURO equivalent of stQEURO balance
     */
    function getQEUROEquivalent(address user) external view returns (uint256 qeuroEquivalent);

    /**
     * @notice Get staking statistics
     */
    function getStakingStats() external view returns (
        uint256 totalStQEUROSupply,
        uint256 totalQEUROUnderlying,
        uint256 currentExchangeRate,
        uint256 totalYieldEarned,
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
     */
    function updateTreasury(address _treasury) external;

    /**
     * @notice Pause the contract
     */
    function pause() external;

    /**
     * @notice Unpause the contract
     */
    function unpause() external;

    /**
     * @notice Emergency withdrawal of QEURO
     */
    function emergencyWithdraw(address user) external;

    /**
     * @notice Recover accidentally sent tokens
     */
    function recoverToken(address token, address to, uint256 amount) external;

    /**
     * @notice Recover accidentally sent ETH
     */
    function recoverETH(address payable to) external;

    // View functions for token metadata
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}
