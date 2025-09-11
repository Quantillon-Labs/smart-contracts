// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title MockAavePool
 * @notice Mock Aave Pool for deployment
 */
contract MockAavePool {
    address public usdc;
    address public aUSDC;
    
    constructor(address _usdc, address _aUSDC) {
        usdc = _usdc;
        aUSDC = _aUSDC;
    }
    
    function getPool() external view returns (address) {
        return address(this);
    }
    
    function getReserveData(address asset) external view returns (
        uint256 configuration,
        uint128 liquidityIndex,
        uint128 currentLiquidityRate,
        uint128 variableBorrowIndex,
        uint128 currentVariableBorrowRate,
        uint128 currentStableBorrowRate,
        uint40 lastUpdateTimestamp,
        uint16 id,
        address aTokenAddress,
        address stableDebtTokenAddress,
        address variableDebtTokenAddress,
        address interestRateStrategyAddress,
        uint128 accruedToTreasury,
        uint128 unbacked,
        uint128 isolationModeTotalDebt
    ) {
        // Return mock data for any asset
        return (
            0, // configuration
            1e27, // liquidityIndex (1.0 in ray)
            0, // currentLiquidityRate
            1e27, // variableBorrowIndex (1.0 in ray)
            0, // currentVariableBorrowRate
            0, // currentStableBorrowRate
            uint40(block.timestamp), // lastUpdateTimestamp
            0, // id
            aUSDC, // aTokenAddress
            address(0), // stableDebtTokenAddress
            address(0), // variableDebtTokenAddress
            address(0), // interestRateStrategyAddress
            0, // accruedToTreasury
            0, // unbacked
            0 // isolationModeTotalDebt
        );
    }
}

/**
 * @title MockPoolAddressesProvider
 * @notice Mock Aave Pool Addresses Provider for deployment
 */
contract MockPoolAddressesProvider {
    address public poolAddress;
    
    constructor(address _poolAddress) {
        poolAddress = _poolAddress;
    }
    
    function getPool() external view returns (address) {
        return poolAddress;
    }
    
    function getPriceOracle() external view returns (address) {
        return address(this);
    }
}

/**
 * @title MockRewardsController
 * @notice Mock Aave Rewards Controller for deployment
 */
contract MockRewardsController {
    mapping(address => uint256) public pendingRewards;
    
    function claimRewards(
        address[] calldata assets,
        uint256 /* amount */,
        address /* to */
    ) external returns (uint256) {
        uint256 totalClaimed = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 reward = pendingRewards[assets[i]];
            if (reward > 0) {
                totalClaimed += reward;
                pendingRewards[assets[i]] = 0;
            }
        }
        return totalClaimed;
    }
    
    function getUserRewards(
        address[] calldata assets,
        address user
    ) external view returns (uint256[] memory) {
        uint256[] memory rewards = new uint256[](assets.length);
        for (uint256 i = 0; i < assets.length; i++) {
            rewards[i] = pendingRewards[assets[i]];
        }
        return rewards;
    }
}
