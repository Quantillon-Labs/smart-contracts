// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockAUSDC
 * @notice Mock aUSDC token for local Aave simulation
 * @dev Mintable/burnable by MockAavePool to simulate Aave's aToken mechanics
 */
contract MockAUSDC is ERC20 {
    address public pool;
    
    constructor() ERC20("Mock Aave USDC", "aUSDC") {}
    
    function setPool(address _pool) external {
        require(pool == address(0), "Pool already set");
        pool = _pool;
    }
    
    function mint(address to, uint256 amount) external {
        require(msg.sender == pool, "Only pool can mint");
        _mint(to, amount);
    }
    
    function burn(address from, uint256 amount) external {
        require(msg.sender == pool, "Only pool can burn");
        _burn(from, amount);
    }
    
    function decimals() public pure override returns (uint8) {
        return 6; // Same as USDC
    }
}

/**
 * @title MockAavePool
 * @notice Mock Aave Pool for deployment
 */
contract MockAavePool {
    address public usdc;
    MockAUSDC public aUSDCToken;
    
    // Track balances for mock aToken minting
    mapping(address => uint256) public deposits;
    
    constructor(address _usdc) {
        usdc = _usdc;
        // Deploy mock aUSDC token
        aUSDCToken = new MockAUSDC();
        aUSDCToken.setPool(address(this));
    }
    
    function aUSDC() external view returns (address) {
        return address(aUSDCToken);
    }
    
    function getPool() external view returns (address) {
        return address(this);
    }
    
    /**
     * @notice Mock supply function - simulates Aave deposit
     * @dev Transfers USDC from caller and mints equivalent aUSDC (1:1 for mock)
     */
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 /* referralCode */
    ) external {
        // Transfer USDC from caller to this pool
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        // Track deposit
        deposits[onBehalfOf] += amount;
        // Mint aUSDC to depositor (simulates Aave's aToken minting)
        aUSDCToken.mint(onBehalfOf, amount);
    }
    
    /**
     * @notice Mock withdraw function - simulates Aave withdrawal
     * @dev Burns aUSDC from caller and returns USDC
     */
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256) {
        uint256 withdrawAmount = amount > deposits[msg.sender] ? deposits[msg.sender] : amount;
        if (withdrawAmount > 0) {
            deposits[msg.sender] -= withdrawAmount;
            // Burn aUSDC from caller
            aUSDCToken.burn(msg.sender, withdrawAmount);
            // Transfer USDC back
            IERC20(asset).transfer(to, withdrawAmount);
        }
        return withdrawAmount;
    }
    
    function getReserveData(address /* asset */) external view returns (
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
            address(aUSDCToken), // aTokenAddress - the mock aUSDC we deployed
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
        address /* user */
    ) external view returns (uint256[] memory) {
        uint256[] memory rewards = new uint256[](assets.length);
        for (uint256 i = 0; i < assets.length; i++) {
            rewards[i] = pendingRewards[assets[i]];
        }
        return rewards;
    }
}
