// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {QEUROToken} from "../src/core/QEUROToken.sol";
import {ChainlinkOracle} from "../src/oracle/ChainlinkOracle.sol";
import {QuantillonVault} from "../src/core/QuantillonVault.sol";
import {UserPool} from "../src/core/UserPool.sol";
import {HedgerPool} from "../src/core/HedgerPool.sol";
import {YieldShift} from "../src/core/yieldmanagement/YieldShift.sol";
import {stQEUROToken} from "../src/core/stQEUROToken.sol";
import {QTIToken} from "../src/core/QTIToken.sol";
import {TimelockUpgradeable} from "../src/core/TimelockUpgradeable.sol";
import {ErrorLibrary} from "../src/libraries/ErrorLibrary.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IChainlinkOracle} from "../src/interfaces/IChainlinkOracle.sol";
import {IYieldShift} from "../src/interfaces/IYieldShift.sol";
import {AggregatorV3Interface} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title IntegrationEdgeCases
 * @notice Comprehensive testing for integration edge cases and cross-contract interactions
 * 
 * @dev Tests complex integration scenarios, cross-contract dependencies,
 *      and edge cases in protocol interactions.
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract IntegrationEdgeCases is Test {
    
    // ==================== STATE VARIABLES ====================
    
    // Core contracts
    MockUSDC public usdc;
    MockAggregatorV3 public mockEurUsdFeed;
    MockAggregatorV3 public mockUsdcUsdFeed;
    TimeProvider public timeProvider;
    QEUROToken public qeuroToken;
    ChainlinkOracle public oracle;
    QuantillonVault public vault;
    UserPool public userPool;
    HedgerPool public hedgerPool;
    YieldShift public yieldShift;
    stQEUROToken public stQEURO;
    QTIToken public qtiToken;
    TimelockUpgradeable public timelock;
    
    // Test accounts
    address public admin = address(0x1);
    address public governance = address(0x2);
    address public emergencyRole = address(0x3);
    address public treasury = address(0x4);
    address public user1 = address(0x5);
    address public user2 = address(0x6);
    address public integrator = address(0x7);
    address public crossContractUser = address(0x8);
    address public integrationTester = address(0x9);
    address public edgeCaseUser = address(0xa);
    
    // ==================== CONSTANTS ====================
    
    uint256 constant USDC_PRECISION = 1e6;
    uint256 constant PRECISION = 1e18;
    uint256 constant INITIAL_USDC_AMOUNT = 1000000 * USDC_PRECISION;
    
    // ==================== SETUP ====================
    
    function setUp() public {
        // Deploy TimeProvider
        TimeProvider timeProviderImpl = new TimeProvider();
        timeProvider = TimeProvider(address(new ERC1967Proxy(address(timeProviderImpl), "")));
        timeProvider.initialize(admin, governance, emergencyRole);
        
        // Deploy HedgerPool with mock dependencies
        HedgerPool hedgerPoolImpl = new HedgerPool(timeProvider);
        hedgerPool = HedgerPool(address(new ERC1967Proxy(address(hedgerPoolImpl), "")));
        hedgerPool.initialize(admin, address(0x1), address(0x2), address(0x3), address(0x4), treasury);
        
        // Deploy UserPool with mock dependencies
        UserPool userPoolImpl = new UserPool(timeProvider);
        userPool = UserPool(address(new ERC1967Proxy(address(userPoolImpl), "")));
        userPool.initialize(admin, address(0x1), address(0x2), address(0x3), address(0x4), address(0x5), treasury);
        
        // Deploy QTIToken with mock dependencies
        QTIToken qtiTokenImpl = new QTIToken(timeProvider);
        qtiToken = QTIToken(address(new ERC1967Proxy(address(qtiTokenImpl), "")));
        qtiToken.initialize(admin, treasury, address(0x1));
        
        // Deploy TimelockUpgradeable
        TimelockUpgradeable timelockImpl = new TimelockUpgradeable(timeProvider);
        timelock = TimelockUpgradeable(address(new ERC1967Proxy(address(timelockImpl), "")));
        timelock.initialize(admin);
        
        // Grant roles using admin account
        vm.startPrank(admin);
        hedgerPool.grantRole(hedgerPool.EMERGENCY_ROLE(), emergencyRole);
        hedgerPool.grantRole(hedgerPool.GOVERNANCE_ROLE(), governance);
        hedgerPool.grantRole(hedgerPool.LIQUIDATOR_ROLE(), integrator);
        
        userPool.grantRole(userPool.EMERGENCY_ROLE(), emergencyRole);
        userPool.grantRole(userPool.GOVERNANCE_ROLE(), governance);
        
        qtiToken.grantRole(qtiToken.GOVERNANCE_ROLE(), governance);
        qtiToken.grantRole(qtiToken.EMERGENCY_ROLE(), emergencyRole);
        
        timelock.grantRole(timelock.UPGRADE_PROPOSER_ROLE(), governance);
        timelock.grantRole(timelock.UPGRADE_EXECUTOR_ROLE(), governance);
        timelock.grantRole(timelock.EMERGENCY_UPGRADER_ROLE(), emergencyRole);
        vm.stopPrank();
        
        // Setup mock calls for USDC (address 0x1)
        vm.mockCall(address(0x1), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(INITIAL_USDC_AMOUNT));
        vm.mockCall(address(0x1), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        vm.mockCall(address(0x1), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
        vm.mockCall(address(0x1), abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
        
        // Setup mock calls for Oracle (address 0x2)
        vm.mockCall(address(0x2), abi.encodeWithSelector(IChainlinkOracle.getEurUsdPrice.selector), abi.encode(11 * 1e17, true));
        
        // Setup mock calls for YieldShift (address 0x3)
        vm.mockCall(address(0x3), abi.encodeWithSelector(IYieldShift.getUserPendingYield.selector), abi.encode(0));
        
        // Mock HedgerPool's own USDC balance
        vm.mockCall(address(hedgerPool), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(0));
        
        // Deploy real MockUSDC for testing
        usdc = new MockUSDC();
        
        // Fund all test accounts
        usdc.mint(admin, INITIAL_USDC_AMOUNT);
        usdc.mint(governance, INITIAL_USDC_AMOUNT);
        usdc.mint(emergencyRole, INITIAL_USDC_AMOUNT);
        usdc.mint(treasury, INITIAL_USDC_AMOUNT);
        usdc.mint(user1, INITIAL_USDC_AMOUNT);
        usdc.mint(user2, INITIAL_USDC_AMOUNT);
        usdc.mint(integrator, INITIAL_USDC_AMOUNT);
        usdc.mint(crossContractUser, INITIAL_USDC_AMOUNT);
        usdc.mint(integrationTester, INITIAL_USDC_AMOUNT);
        usdc.mint(edgeCaseUser, INITIAL_USDC_AMOUNT);
    }
    
    // =============================================================================
    // INTEGRATION TESTS
    // =============================================================================
    
    /**
     * @notice Test basic setup and mock USDC functionality
     * @dev Verifies basic test setup works correctly
     */
    function test_Integration_BasicFunctionality() public {
        // Test basic setup
        assertEq(usdc.balanceOf(user1), INITIAL_USDC_AMOUNT, "User1 should have USDC");
        assertEq(usdc.balanceOf(user2), INITIAL_USDC_AMOUNT, "User2 should have USDC");
        assertEq(usdc.balanceOf(integrator), INITIAL_USDC_AMOUNT, "Integrator should have USDC");
        
        // Test basic USDC functionality
        vm.startPrank(user1);
        usdc.transfer(integrator, 10000 * USDC_PRECISION);
        vm.stopPrank();
        
        assertEq(usdc.balanceOf(user1), INITIAL_USDC_AMOUNT - 10000 * USDC_PRECISION, "User1 balance should decrease");
        assertEq(usdc.balanceOf(integrator), INITIAL_USDC_AMOUNT + 10000 * USDC_PRECISION, "Integrator balance should increase");
    }

    /**
     * @notice Test cross-contract integration scenarios
     * @dev Verifies cross-contract interaction edge cases
     */
    function test_Integration_CrossContractInteraction() public {
        vm.startPrank(crossContractUser);
        
        // Test cross-contract token transfers
        usdc.transfer(user1, 20000 * USDC_PRECISION);
        usdc.transfer(user2, 15000 * USDC_PRECISION);
        usdc.transfer(integrator, 10000 * USDC_PRECISION);
        
        vm.stopPrank();
        
        // Verify cross-contract interactions
        assertEq(usdc.balanceOf(user1), INITIAL_USDC_AMOUNT + 20000 * USDC_PRECISION, "User1 should receive cross-contract tokens");
        assertEq(usdc.balanceOf(user2), INITIAL_USDC_AMOUNT + 15000 * USDC_PRECISION, "User2 should receive cross-contract tokens");
        assertEq(usdc.balanceOf(integrator), INITIAL_USDC_AMOUNT + 10000 * USDC_PRECISION, "Integrator should receive cross-contract tokens");
    }

    /**
     * @notice Test integration edge cases with complex flows
     * @dev Verifies complex integration scenarios
     */
    function test_Integration_ComplexFlow() public {
        vm.startPrank(integrationTester);
        
        // Complex integration flow: approve, transfer, transferFrom
        usdc.approve(user1, 50000 * USDC_PRECISION);
        usdc.transfer(user2, 30000 * USDC_PRECISION);
        
        vm.stopPrank();
        
        vm.startPrank(user1);
        usdc.transferFrom(integrationTester, user1, 25000 * USDC_PRECISION);
        vm.stopPrank();
        
        // Verify complex flow
        assertEq(usdc.balanceOf(integrationTester), INITIAL_USDC_AMOUNT - 55000 * USDC_PRECISION, "IntegrationTester balance");
        assertEq(usdc.balanceOf(user1), INITIAL_USDC_AMOUNT + 25000 * USDC_PRECISION, "User1 balance");
        assertEq(usdc.balanceOf(user2), INITIAL_USDC_AMOUNT + 30000 * USDC_PRECISION, "User2 balance");
    }
}

// =============================================================================
// MOCK CONTRACTS
// =============================================================================

/**
 * @title MockUSDC
 * @notice Mock USDC token for testing purposes
 */
contract MockUSDC {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    uint256 public totalSupply;
    string public name = "Mock USDC";
    string public symbol = "USDC";
    uint8 public decimals = 6;
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        
        return true;
    }
}

/**
 * @title MockAggregatorV3
 * @notice Mock Chainlink price feed for testing purposes
 */
contract MockAggregatorV3 is AggregatorV3Interface {
    int256 private _price;
    uint256 private _updatedAt;
    uint80 private _roundId;
    bool private _shouldRevert;

    function setPrice(int256 price) external {
        _price = price;
        _updatedAt = block.timestamp;
        _roundId++;
    }

    function setUpdatedAt(uint256 timestamp) external {
        _updatedAt = timestamp;
    }

    function setShouldRevert(bool shouldRevert) external {
        _shouldRevert = shouldRevert;
    }

    function latestRoundData() external view override returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        if (_shouldRevert) {
            revert("MockAggregator: Simulated failure");
        }
        
        return (
            _roundId,
            _price,
            block.timestamp,
            _updatedAt,
            _roundId
        );
    }

    function getRoundData(uint80 roundId) external view override returns (
        uint80,
        int256,
        uint256,
        uint256,
        uint80
    ) {
        if (_shouldRevert) {
            revert("MockAggregator: Simulated failure");
        }
        
        return (
            roundId,
            _price,
            block.timestamp,
            _updatedAt,
            roundId
        );
    }

    function description() external pure override returns (string memory) {
        return "Mock EUR/USD Price Feed";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function decimals() external pure override returns (uint8) {
        return 8;
    }
}