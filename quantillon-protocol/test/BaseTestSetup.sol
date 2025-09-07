// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {QuantillonVault} from "../src/core/QuantillonVault.sol";
import {UserPool} from "../src/core/UserPool.sol";
import {HedgerPool} from "../src/core/HedgerPool.sol";
import {QEUROToken} from "../src/core/QEUROToken.sol";
import {QTIToken} from "../src/core/QTIToken.sol";
import {stQEUROToken} from "../src/core/stQEUROToken.sol";
import {ChainlinkOracle} from "../src/oracle/ChainlinkOracle.sol";
import {YieldShift} from "../src/core/yieldmanagement/YieldShift.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {TimelockUpgradeable} from "../src/core/TimelockUpgradeable.sol";
import {ErrorLibrary} from "../src/libraries/ErrorLibrary.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title BaseTestSetup
 * @notice Base test setup contract with proper dependency management
 * 
 * @dev Provides a standardized setup for all edge case tests with:
 *      - Proper TimeProvider integration
 *      - Correct contract initialization
 *      - Mock dependencies
 *      - Standard test accounts
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract BaseTestSetup is Test {
    
    // ==================== STATE VARIABLES ====================
    
    // Core contracts
    QuantillonVault public vault;
    UserPool public userPool;
    HedgerPool public hedgerPool;
    QEUROToken public qeuroToken;
    QTIToken public qtiToken;
    stQEUROToken public stQEURO;
    ChainlinkOracle public oracle;
    YieldShift public yieldShift;
    TimeProvider public timeProvider;
    TimelockUpgradeable public timelock;
    
    // Mock contracts
    MockUSDC public usdc;
    
    // Test accounts
    address public admin = address(0x1);
    address public governance = address(0x2);
    address public liquidator = address(0x3);
    address public user1 = address(0x4);
    address public user2 = address(0x5);
    address public attacker = address(0x6);
    address public treasury = address(0x7);
    
    // ==================== CONSTANTS ====================
    
    uint256 constant PRECISION = 1e18;
    uint256 constant USDC_PRECISION = 1e6;
    uint256 constant INITIAL_USDC = 10000000 * USDC_PRECISION;
    uint256 constant INITIAL_QEURO = 10000000 * PRECISION;
    uint256 constant INITIAL_QTI = 100000000 * PRECISION;
    
    // ==================== SETUP ====================
    
    function setUp() public virtual {
        // Deploy mock USDC
        usdc = new MockUSDC();
        
        // Deploy TimeProvider
        TimeProvider timeProviderImpl = new TimeProvider();
        bytes memory timeProviderInitData = abi.encodeWithSelector(
            TimeProvider.initialize.selector,
            admin,
            governance,
            admin // emergency role
        );
        ERC1967Proxy timeProviderProxy = new ERC1967Proxy(address(timeProviderImpl), timeProviderInitData);
        timeProvider = TimeProvider(address(timeProviderProxy));
        
        // Deploy Timelock
        TimelockUpgradeable timelockImpl = new TimelockUpgradeable(timeProvider);
        bytes memory timelockInitData = abi.encodeWithSelector(
            TimelockUpgradeable.initialize.selector,
            admin
        );
        ERC1967Proxy timelockProxy = new ERC1967Proxy(address(timelockImpl), timelockInitData);
        timelock = TimelockUpgradeable(address(timelockProxy));
        
        // Deploy QTI token
        QTIToken qtiImpl = new QTIToken(timeProvider);
        bytes memory qtiInitData = abi.encodeWithSelector(
            QTIToken.initialize.selector,
            admin,
            treasury,
            address(timelock)
        );
        ERC1967Proxy qtiProxy = new ERC1967Proxy(address(qtiImpl), qtiInitData);
        qtiToken = QTIToken(address(qtiProxy));
        
        // Deploy oracle
        ChainlinkOracle oracleImpl = new ChainlinkOracle(timeProvider);
        bytes memory oracleInitData = abi.encodeWithSelector(
            ChainlinkOracle.initialize.selector,
            admin,
            address(0), // Mock feeds will be set later
            address(0),
            1 * PRECISION,
            1000 * PRECISION,
            500
        );
        ERC1967Proxy oracleProxy = new ERC1967Proxy(address(oracleImpl), oracleInitData);
        oracle = ChainlinkOracle(address(oracleProxy));
        
        // Deploy QEURO token first (needed for vault)
        QEUROToken qeuroImpl = new QEUROToken();
        bytes memory qeuroInitData = abi.encodeWithSelector(
            QEUROToken.initialize.selector,
            admin,
            address(0), // vault will be set later
            address(timelock),
            treasury
        );
        ERC1967Proxy qeuroProxy = new ERC1967Proxy(address(qeuroImpl), qeuroInitData);
        qeuroToken = QEUROToken(address(qeuroProxy));
        
        // Deploy QuantillonVault with QEURO token
        QuantillonVault vaultImpl = new QuantillonVault();
        bytes memory vaultInitData = abi.encodeWithSelector(
            QuantillonVault.initialize.selector,
            admin,
            address(qeuroToken),
            address(usdc),
            address(oracle),
            address(timelock)
        );
        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(vaultImpl), vaultInitData);
        vault = QuantillonVault(address(vaultProxy));
        
        // Deploy UserPool
        UserPool userPoolImpl = new UserPool(timeProvider);
        bytes memory userPoolInitData = abi.encodeWithSelector(
            UserPool.initialize.selector,
            admin,
            address(qeuroToken),
            address(usdc),
            address(vault),
            address(0), // yieldShift will be set later
            address(timelock),
            treasury
        );
        ERC1967Proxy userPoolProxy = new ERC1967Proxy(address(userPoolImpl), userPoolInitData);
        userPool = UserPool(address(userPoolProxy));
        
        // Deploy HedgerPool
        HedgerPool hedgerImpl = new HedgerPool(timeProvider);
        bytes memory hedgerInitData = abi.encodeWithSelector(
            HedgerPool.initialize.selector,
            admin,
            address(usdc),
            address(oracle),
            address(0), // yieldShift will be set later
            address(timelock),
            treasury
        );
        ERC1967Proxy hedgerProxy = new ERC1967Proxy(address(hedgerImpl), hedgerInitData);
        hedgerPool = HedgerPool(address(hedgerProxy));
        
        // Deploy stQEURO token
        stQEUROToken stQEUROImpl = new stQEUROToken(timeProvider);
        bytes memory stQEUROInitData = abi.encodeWithSelector(
            stQEUROToken.initialize.selector,
            admin,
            address(qeuroToken),
            address(0), // yieldShift will be set later
            address(usdc),
            treasury,
            address(timelock)
        );
        ERC1967Proxy stQEUROProxy = new ERC1967Proxy(address(stQEUROImpl), stQEUROInitData);
        stQEURO = stQEUROToken(address(stQEUROProxy));
        
        // Deploy YieldShift with all contract addresses
        YieldShift yieldShiftImpl = new YieldShift(timeProvider);
        bytes memory yieldShiftInitData = abi.encodeWithSelector(
            YieldShift.initialize.selector,
            admin,
            address(usdc),
            address(userPool),
            address(hedgerPool),
            address(0), // aaveVault - not needed for basic tests
            address(stQEURO),
            address(timelock),
            treasury
        );
        ERC1967Proxy yieldShiftProxy = new ERC1967Proxy(address(yieldShiftImpl), yieldShiftInitData);
        yieldShift = YieldShift(address(yieldShiftProxy));
        
        // Setup roles
        vm.startPrank(admin);
        hedgerPool.grantRole(hedgerPool.LIQUIDATOR_ROLE(), liquidator);
        hedgerPool.grantRole(hedgerPool.GOVERNANCE_ROLE(), governance);
        vm.stopPrank();
        
        // Fund accounts
        usdc.mint(user1, 1000000 * USDC_PRECISION);
        usdc.mint(user2, 1000000 * USDC_PRECISION);
        usdc.mint(attacker, 1000000 * USDC_PRECISION);
        
        // Fund vault with USDC
        usdc.mint(address(vault), INITIAL_USDC);
    }
}

// =============================================================================
// MOCK CONTRACTS
// =============================================================================

/**
 * @title MockUSDC
 * @notice Mock USDC token for testing
 */
contract MockUSDC {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    uint256 public totalSupply;
    string public name = "USD Coin";
    string public symbol = "USDC";
    uint8 public decimals = 6;
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
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
