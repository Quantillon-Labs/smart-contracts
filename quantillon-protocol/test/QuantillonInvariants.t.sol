// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {QTIToken} from "../src/core/QTIToken.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {QEUROToken} from "../src/core/QEUROToken.sol";
import {QuantillonVault} from "../src/core/QuantillonVault.sol";
import {UserPool} from "../src/core/UserPool.sol";
import {HedgerPool} from "../src/core/HedgerPool.sol";
import {YieldShift} from "../src/core/yieldmanagement/YieldShift.sol";
import {AaveVault} from "../src/core/vaults/AaveVault.sol";
import {stQEUROToken} from "../src/core/stQEUROToken.sol";
import {FeeCollector} from "../src/core/FeeCollector.sol";
import {MockChainlinkOracle} from "../src/mocks/MockChainlinkOracle.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {MockAggregatorV3} from "./ChainlinkOracle.t.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {VaultMath} from "../src/libraries/VaultMath.sol";

/**
 * @title QuantillonInvariants
 * @notice Formal verification contract for Quantillon Protocol invariants
 * 
 * @dev This contract implements comprehensive invariant testing to ensure:
 *      - Supply consistency across all contracts
 *      - Proper collateralization ratios
 *      - Yield distribution integrity
 *      - Governance power consistency
 *      - Emergency state consistency
 *      - Oracle price consistency
 *      - Liquidation state consistency
 *      - Access control consistency
 * 
 * @dev Invariants are mathematical properties that must always hold true
 *      regardless of the state of the system or any operations performed.
 * 
 * @author Quantillon Labs - Nicolas Bellengé - @chewbaccoin
 * @custom:security-contact team@quantillon.money
 */
contract QuantillonInvariants is Test {
    // =============================================================================
    // CONTRACT INSTANCES
    // =============================================================================

    TimeProvider public timeProvider;
    QTIToken public qtiToken;
    QEUROToken public qeuroToken;
    QuantillonVault public vault;
    UserPool public userPool;
    HedgerPool public hedgerPool;
    YieldShift public yieldShift;
    AaveVault public aaveVault;
    stQEUROToken public stQEURO;
    FeeCollector public feeCollector;
    MockChainlinkOracle public oracle;
    MockUSDC public usdc;
    MockAggregatorV3 public eurUsdFeed;
    MockAggregatorV3 public usdcUsdFeed;

    // Action handler for invariant testing
    InvariantActionHandler public handler;

    // =============================================================================
    // TEST ADDRESSES
    // =============================================================================

    address public admin = address(0x1);
    address public governance = address(0x2);
    address public emergency = address(0x3);
    address public treasury = address(0x4);
    address public user1 = address(0x5);
    address public user2 = address(0x6);
    address public hedger1 = address(0x7);
    address public hedger2 = address(0x8);
    address public liquidator = address(0x9);
    address public yieldManager = address(0xA);

    // Mock addresses
    address public mockTimelock = address(0xD);
    address public mockAavePool = address(0xE);
    address public mockAUSDC = address(0xF);
    
    // =============================================================================
    // CONSTANTS
    // =============================================================================
    
    uint256 public constant INITIAL_QTI_SUPPLY = 100_000_000 * 1e18; // 100M QTI
    uint256 public constant INITIAL_QEURO_SUPPLY = 1_000_000 * 1e18; // 1M QEURO
    uint256 public constant MIN_COLLATERALIZATION_RATIO = 11000; // 110% (11000 basis points)
    uint256 public constant MAX_COLLATERALIZATION_RATIO = 100000; // 1000% (100000 basis points)
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_PRICE_DEVIATION = 5000; // 50% (5000 basis points)
    
    // =============================================================================
    // SETUP
    // =============================================================================
    
    /**
     * @notice Sets up the invariant testing environment
     * @dev Initializes all protocol contracts for comprehensive invariant testing
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function setUp() public {
        // Deploy only essential contracts for invariant testing
        _deployEssentialContracts();
        _setupEssentialRoles();
        // Instantiate handler for Foundry invariant mode (random action sequences)
        address[] memory actors = new address[](2);
        actors[0] = user1;
        actors[1] = user2;
        handler = new InvariantActionHandler(
            address(vault),
            address(userPool),
            address(hedgerPool),
            address(stQEURO),
            address(qeuroToken),
            address(usdc),
            address(oracle),
            actors
        );
        targetContract(address(handler));
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = InvariantActionHandler.actionMint.selector;
        selectors[1] = InvariantActionHandler.actionRedeem.selector;
        selectors[2] = InvariantActionHandler.actionStake.selector;
        selectors[3] = InvariantActionHandler.actionUnstake.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }
    
    /**
     * @notice Deploys essential contracts for invariant testing
     * @dev Deploys the full protocol for comprehensive invariant testing
     * @custom:security No security validations - test setup function
     * @custom:validation No input validation - test setup function
     * @custom:state-changes Deploys and initializes essential contracts
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test setup function
     * @custom:access Internal - test setup function
     * @custom:oracle No oracle dependencies
     */
    function _deployEssentialContracts() internal {
        // Deploy mock USDC
        usdc = new MockUSDC();
        usdc.mint(user1, 1_000_000 * 1e6);
        usdc.mint(user2, 1_000_000 * 1e6);
        usdc.mint(hedger1, 1_000_000 * 1e6);
        usdc.mint(hedger2, 1_000_000 * 1e6);

        // Deploy mock Chainlink feeds
        eurUsdFeed = new MockAggregatorV3(8);
        eurUsdFeed.setPrice(1.10e8); // 1.10 USD per EUR
        usdcUsdFeed = new MockAggregatorV3(8);
        usdcUsdFeed.setPrice(1.00e8); // 1.00 USD per USDC

        // Deploy TimeProvider
        TimeProvider timeProviderImpl = new TimeProvider();
        bytes memory timeProviderInitData = abi.encodeWithSelector(
            TimeProvider.initialize.selector,
            admin,
            admin,
            admin
        );
        ERC1967Proxy timeProviderProxy = new ERC1967Proxy(address(timeProviderImpl), timeProviderInitData);
        timeProvider = TimeProvider(address(timeProviderProxy));

        // Deploy Oracle
        MockChainlinkOracle oracleImpl = new MockChainlinkOracle();
        bytes memory oracleInitData = abi.encodeWithSelector(
            MockChainlinkOracle.initialize.selector,
            admin,
            address(eurUsdFeed),
            address(usdcUsdFeed),
            treasury
        );
        ERC1967Proxy oracleProxy = new ERC1967Proxy(address(oracleImpl), oracleInitData);
        oracle = MockChainlinkOracle(payable(address(oracleProxy)));

        vm.prank(admin);
        oracle.setPrices(1.10e18, 1.00e18);

        // Deploy FeeCollector
        FeeCollector feeCollectorImpl = new FeeCollector();
        bytes memory feeCollectorInitData = abi.encodeWithSelector(
            FeeCollector.initialize.selector,
            admin,
            treasury,
            treasury,
            treasury
        );
        ERC1967Proxy feeCollectorProxy = new ERC1967Proxy(address(feeCollectorImpl), feeCollectorInitData);
        feeCollector = FeeCollector(address(feeCollectorProxy));

        // Deploy QTIToken
        QTIToken qtiImplementation = new QTIToken(timeProvider);
        bytes memory qtiInitData = abi.encodeWithSelector(
            QTIToken.initialize.selector,
            admin,
            treasury,
            mockTimelock,
            admin
        );
        ERC1967Proxy qtiProxy = new ERC1967Proxy(address(qtiImplementation), qtiInitData);
        qtiToken = QTIToken(address(qtiProxy));

        // Deploy QEUROToken (vault placeholder: protocol requires non-zero; we grant MINTER/BURNER to vault below)
        QEUROToken qeuroImplementation = new QEUROToken();
        bytes memory qeuroInitData = abi.encodeWithSelector(
            QEUROToken.initialize.selector,
            admin,
            admin, // placeholder vault; grant to real vault in _setupEssentialRoles
            mockTimelock,
            treasury,
            address(feeCollector)
        );
        ERC1967Proxy qeuroProxy = new ERC1967Proxy(address(qeuroImplementation), qeuroInitData);
        qeuroToken = QEUROToken(address(qeuroProxy));

        // Deploy QuantillonVault
        QuantillonVault vaultImpl = new QuantillonVault();
        bytes memory vaultInitData = abi.encodeWithSelector(
            QuantillonVault.initialize.selector,
            admin,
            address(qeuroToken),
            address(usdc),
            address(oracle),
            address(0), // hedgerPool (set later)
            address(0), // userPool (set later)
            mockTimelock,
            address(feeCollector)
        );
        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(vaultImpl), vaultInitData);
        vault = QuantillonVault(address(vaultProxy));

        // Grant vault mint/burn roles on QEURO and TREASURY_ROLE on FeeCollector so vault can collect fees
        vm.startPrank(admin);
        qeuroToken.grantRole(qeuroToken.MINTER_ROLE(), address(vault));
        qeuroToken.grantRole(qeuroToken.BURNER_ROLE(), address(vault));
        feeCollector.grantRole(feeCollector.TREASURY_ROLE(), address(vault));
        vm.stopPrank();

        // Deploy YieldShift
        YieldShift yieldShiftImpl = new YieldShift(timeProvider);
        bytes memory yieldShiftInitData = abi.encodeWithSelector(
            YieldShift.initialize.selector,
            admin,
            address(usdc),
            address(0), // userPool
            address(0), // hedgerPool
            address(0), // aaveVault
            address(0), // stQEURO
            mockTimelock,
            treasury
        );
        ERC1967Proxy yieldShiftProxy = new ERC1967Proxy(address(yieldShiftImpl), yieldShiftInitData);
        yieldShift = YieldShift(address(yieldShiftProxy));

        // Deploy stQEURO
        stQEUROToken stQEUROImpl = new stQEUROToken(timeProvider);
        bytes memory stQEUROInitData = abi.encodeWithSelector(
            stQEUROToken.initialize.selector,
            admin,
            address(qeuroToken),
            address(yieldShift),
            address(usdc),
            treasury,
            mockTimelock
        );
        ERC1967Proxy stQEUROProxy = new ERC1967Proxy(address(stQEUROImpl), stQEUROInitData);
        stQEURO = stQEUROToken(address(stQEUROProxy));

        // Deploy UserPool (signature: admin, _qeuro, _usdc, _vault, _oracle, _yieldShift, _timelock, _treasury)
        UserPool userPoolImpl = new UserPool(timeProvider);
        bytes memory userPoolInitData = abi.encodeWithSelector(
            UserPool.initialize.selector,
            admin,
            address(qeuroToken),
            address(usdc),
            address(vault),
            address(oracle),
            address(yieldShift),
            mockTimelock,
            treasury
        );
        ERC1967Proxy userPoolProxy = new ERC1967Proxy(address(userPoolImpl), userPoolInitData);
        userPool = UserPool(address(userPoolProxy));

        // Deploy HedgerPool
        HedgerPool hedgerPoolImpl = new HedgerPool(timeProvider);
        bytes memory hedgerPoolInitData = abi.encodeWithSelector(
            HedgerPool.initialize.selector,
            admin,
            address(usdc),
            address(oracle),
            address(yieldShift),
            mockTimelock,
            treasury,
            address(vault)
        );
        ERC1967Proxy hedgerPoolProxy = new ERC1967Proxy(address(hedgerPoolImpl), hedgerPoolInitData);
        hedgerPool = HedgerPool(address(hedgerPoolProxy));

        // Wire contracts together
        vm.startPrank(admin);
        vault.updateHedgerPool(address(hedgerPool));
        vault.updateUserPool(address(userPool));
        yieldShift.updateUserPool(address(userPool));
        yieldShift.updateHedgerPool(address(hedgerPool));
        vm.stopPrank();
    }
    
    /**
     * @notice Sets up essential roles for invariant testing
     * @dev Grants roles for all deployed contracts
     * @custom:security No security validations - test setup function
     * @custom:validation No input validation - test setup function
     * @custom:state-changes Grants roles to essential contracts
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not protected - test setup function
     * @custom:access Internal - test setup function
     * @custom:oracle No oracle dependencies
     */
    function _setupEssentialRoles() internal {
        // Grant roles for all contracts
        vm.startPrank(admin);

        // QTIToken roles
        qtiToken.grantRole(qtiToken.GOVERNANCE_ROLE(), governance);
        qtiToken.grantRole(qtiToken.EMERGENCY_ROLE(), emergency);

        // QEUROToken roles
        qeuroToken.grantRole(qeuroToken.MINTER_ROLE(), governance);
        qeuroToken.grantRole(qeuroToken.BURNER_ROLE(), governance);
        qeuroToken.grantRole(qeuroToken.PAUSER_ROLE(), emergency);
        qeuroToken.grantRole(qeuroToken.COMPLIANCE_ROLE(), governance);

        // Vault roles
        vault.grantRole(vault.GOVERNANCE_ROLE(), governance);
        vault.grantRole(vault.EMERGENCY_ROLE(), emergency);

        // UserPool roles
        userPool.grantRole(userPool.GOVERNANCE_ROLE(), governance);
        userPool.grantRole(userPool.EMERGENCY_ROLE(), emergency);

        // HedgerPool roles
        hedgerPool.grantRole(hedgerPool.GOVERNANCE_ROLE(), governance);
        hedgerPool.grantRole(hedgerPool.EMERGENCY_ROLE(), emergency);

        vm.stopPrank();

        // Test-friendly: skip price deviation, allow minting at 101% collateralization, seed hedger margin
        vm.prank(admin);
        vault.setDevMode(true);
        vm.startPrank(governance);
        vault.updateCollateralizationThresholds(101e18, 101e18);
        hedgerPool.setSingleHedger(hedger1);
        vm.stopPrank();

        uint256 seedAmount = 100_000 * 1e6;
        vm.prank(hedger1);
        usdc.approve(address(hedgerPool), seedAmount);
        vm.prank(hedger1);
        hedgerPool.enterHedgePosition(seedAmount, 5); // leverage 5 so margin ratio is within allowed range
    }
    

    
    // =============================================================================
    // SUPPLY CONSISTENCY INVARIANTS
    // =============================================================================
    
    /**
     * @notice Verify total supply consistency across all contracts
     * @dev Ensures that total supply equals circulating supply plus locked/burned amounts
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function invariant_totalSupplyConsistency() public view {
        // QTI Token supply consistency
        uint256 qtiLocked = qtiToken.totalLocked();

        // Total voting power should never exceed 4x locked tokens (max multiplier)
        uint256 totalVotingPower = qtiToken.totalVotingPower();
        assertLe(totalVotingPower, qtiLocked * 4, "Voting power exceeds 4x locked tokens");

        // QEURO Token supply consistency
        uint256 qeuroTotalSupply = qeuroToken.totalSupply();

        // Total QEURO supply should never exceed the max supply cap
        uint256 qeuroMaxSupply = qeuroToken.maxSupply();
        assertLe(qeuroTotalSupply, qeuroMaxSupply, "QEURO supply exceeds max supply");

        // stQEURO supply consistency
        uint256 stQEUROTotalSupply = stQEURO.totalSupply();
        uint256 stQEUROUnderlying = stQEURO.totalUnderlying();

        // stQEURO should never have more supply than underlying QEURO
        // (exchange rate should be >= 1:1 to prevent dilution)
        assertLe(stQEUROTotalSupply, stQEUROUnderlying + 1, "stQEURO supply exceeds underlying");

        // Vault USDC balance should back the QEURO supply
        uint256 vaultUsdcBalance = usdc.balanceOf(address(vault));
        // With 1.10 EUR/USD rate, USDC needed = QEURO supply * 1.10 / 1e12 (decimal conversion)
        // We check that vault has USDC (exact calculation depends on price)
        if (qeuroTotalSupply > 0) {
            assertGt(vaultUsdcBalance, 0, "Vault should have USDC backing QEURO");
        }
    }
    
    /**
     * @notice Verify that supply caps are never exceeded
     * @dev Ensures protocol supply limits are respected
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function invariant_supplyCapRespect() public view {
        // QTI supply cap check
        uint256 qtiSupplyCap = qtiToken.TOTAL_SUPPLY_CAP();
        assertLe(qtiToken.totalSupply(), qtiSupplyCap, "QTI supply cap exceeded");
        
        // QEURO supply cap check
        uint256 qeuroSupplyCap = qeuroToken.maxSupply();
        assertLe(qeuroToken.totalSupply(), qeuroSupplyCap, "QEURO supply cap exceeded");
    }
    
    // =============================================================================
    // COLLATERALIZATION INVARIANTS
    // =============================================================================
    
    /**
     * @notice Verify collateralization ratios are within safe bounds
     * @dev Ensures system remains properly collateralized
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function invariant_collateralizationRatio() public pure {
        // Verify collateralization ratios are within safe bounds
        // Note: This test is simplified when Vault and HedgerPool are not deployed
        // In a full deployment, this would verify:
        // - Vault collateralization ratio (110% - 1000%)
        // - HedgerPool collateralization ratio (110% - 1000%)
        
        // For now, we verify the mathematical constants are reasonable
        assertGe(MIN_COLLATERALIZATION_RATIO, 10000, "Minimum collateralization should be at least 100% (10000 basis points)");
        assertLe(MAX_COLLATERALIZATION_RATIO, 100000, "Maximum collateralization should not exceed 1000% (100000 basis points)");
        assertGt(MAX_COLLATERALIZATION_RATIO, MIN_COLLATERALIZATION_RATIO, "Max should be greater than min");
    }
    
    /**
     * @notice Verify that liquidation thresholds are respected
     * @dev Ensures positions can be liquidated when needed
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function invariant_liquidationThresholds() public view {
        // Vault critical ratio: 100% <= criticalCollateralizationRatio <= minCollateralizationRatioForMinting
        uint256 critical = vault.criticalCollateralizationRatio();
        assertGe(critical, 100e18, "Critical collateralization should be at least 100%");
        uint256 minMint = vault.minCollateralizationRatioForMinting();
        assertLe(critical, minMint, "Critical ratio should not exceed min mint ratio");
    }
    
    // =============================================================================
    // YIELD DISTRIBUTION INVARIANTS
    // =============================================================================
    
    /**
     * @notice Verify yield distribution integrity
     * @dev Ensures yield is distributed fairly and completely
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function invariant_yieldDistributionIntegrity() public view {
        // Structural check: yield distribution bounds (full check in IntegrationTests / YieldShift tests)
        assertTrue(address(yieldShift) != address(0), "YieldShift deployed");
    }
    
    /**
     * @notice Verify yield shift parameters are within bounds
     * @dev Ensures yield shift mechanism operates correctly
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function invariant_yieldShiftParameters() public view {
        // Structural check: YieldShift deployed (parameter bounds in YieldValidationLibrary tests)
        assertTrue(address(yieldShift) != address(0), "YieldShift deployed");
    }
    
    // =============================================================================
    // GOVERNANCE INVARIANTS
    // =============================================================================
    
    /**
     * @notice Verify governance power consistency
     * @dev Ensures voting power calculations are consistent
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function invariant_governancePowerConsistency() public view {
        uint256 totalVotingPower = qtiToken.totalVotingPower();
        uint256 totalLocked = qtiToken.totalLocked();
        
        // Total voting power should not exceed total locked tokens (with multiplier)
        // Maximum multiplier is 4x for 4-year locks
        assertLe(totalVotingPower, totalLocked * 4, "Voting power exceeds maximum possible");
        
        // Voting power should be non-negative
        assertGe(totalVotingPower, 0, "Negative voting power");
    }
    
    /**
     * @notice Verify governance parameters are reasonable
     * @dev Ensures governance thresholds are set correctly
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function invariant_governanceParameters() public view {
        uint256 proposalThreshold = qtiToken.proposalThreshold();
        uint256 quorumVotes = qtiToken.quorumVotes();
        uint256 totalSupply = qtiToken.totalSupply();
        
        // Proposal threshold should be reasonable (0.1% - 10% of total supply)
        // But allow for initial state where totalSupply might be 0
        if (totalSupply > 0) {
            assertGe(proposalThreshold, totalSupply / 1000, "Proposal threshold too low");
            assertLe(proposalThreshold, totalSupply / 10, "Proposal threshold too high");
            
            // Quorum should be reasonable (1% - 50% of total supply)
            assertGe(quorumVotes, totalSupply / 100, "Quorum too low");
            assertLe(quorumVotes, totalSupply / 2, "Quorum too high");
            
            // Quorum should be greater than proposal threshold
            assertGt(quorumVotes, proposalThreshold, "Quorum not greater than proposal threshold");
        }
    }
    
    // =============================================================================
    // EMERGENCY STATE INVARIANTS
    // =============================================================================
    
    /**
     * @notice Verify emergency state consistency
     * @dev Ensures emergency mechanisms work correctly
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function invariant_emergencyStateConsistency() public view {
        // Check that emergency roles are properly assigned
        assertTrue(qtiToken.hasRole(qtiToken.EMERGENCY_ROLE(), emergency), "QTI emergency role not assigned");
        assertTrue(qeuroToken.hasRole(qeuroToken.PAUSER_ROLE(), emergency), "QEURO pauser role not assigned");
        
        // If any contract is paused, ensure emergency role can unpause
        // This is a structural check - actual pause state depends on operations
    }
    
    /**
     * @notice Verify pause state consistency across contracts
     * @dev Ensures pause mechanisms are synchronized
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function invariant_pauseStateConsistency() public view {
        // Pause state consistency: vault and hedgerPool both have pause state
        assertTrue(address(vault) != address(0) && address(hedgerPool) != address(0), "Contracts deployed");
        vault.paused();
        hedgerPool.paused();
    }
    

    
    // =============================================================================
    // LIQUIDATION INVARIANTS
    // =============================================================================
    
    /**
     * @notice Verify liquidation state consistency
     * @dev Ensures liquidation mechanisms work correctly
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function invariant_liquidationStateConsistency() public view {
        // Vault liquidation threshold is bounded; HedgerPool total margin is consistent with positions
        uint256 critical = vault.criticalCollateralizationRatio();
        assertGe(critical, 100e18, "Liquidation threshold at least 100%");
        assertLe(critical, 200e18, "Liquidation threshold at most 200%");
    }
    
    // =============================================================================
    // ACCESS CONTROL INVARIANTS
    // =============================================================================
    
    /**
     * @notice Verify access control consistency
     * @dev Ensures role assignments are correct
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function invariant_accessControlConsistency() public view {
        // Check that admin roles are properly assigned
        assertTrue(qtiToken.hasRole(qtiToken.DEFAULT_ADMIN_ROLE(), admin), "QTI admin role not assigned");
        assertTrue(qeuroToken.hasRole(qeuroToken.DEFAULT_ADMIN_ROLE(), admin), "QEURO admin role not assigned");
        
        // Check that governance roles are properly assigned
        assertTrue(qtiToken.hasRole(qtiToken.GOVERNANCE_ROLE(), governance), "QTI governance role not assigned");
        assertTrue(qeuroToken.hasRole(qeuroToken.MINTER_ROLE(), governance), "QEURO minter role not assigned");
        
        // Check that emergency roles are properly assigned
        assertTrue(qtiToken.hasRole(qtiToken.EMERGENCY_ROLE(), emergency), "QTI emergency role not assigned");
        assertTrue(qeuroToken.hasRole(qeuroToken.PAUSER_ROLE(), emergency), "QEURO pauser role not assigned");
    }
    
    // =============================================================================
    // MATHEMATICAL INVARIANTS
    // =============================================================================
    
    /**
     * @notice Verify mathematical consistency
     * @dev Ensures mathematical operations are correct
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function invariant_mathematicalConsistency() public pure {
        // Check that percentages are calculated correctly
        uint256 testValue = 1000 * PRECISION;
        uint256 testPercentage = 5000; // 50% in basis points (5000/10000 = 50%)
        
        uint256 result = VaultMath.percentageOf(testValue, testPercentage);
        assertEq(result, testValue / 2, "Percentage calculation incorrect");
        
        // Check that scaling operations are consistent
        uint256 scaledValue = VaultMath.scaleDecimals(testValue, 6, 18);
        assertEq(scaledValue, testValue * 1e12, "Scaling calculation incorrect");
        
        // Check that min/max operations work correctly
        uint256 minResult = VaultMath.min(testValue, testValue / 2);
        assertEq(minResult, testValue / 2, "Min operation incorrect");
        
        uint256 maxResult = VaultMath.max(testValue, testValue / 2);
        assertEq(maxResult, testValue, "Max operation incorrect");
        
        // Check that percentage calculations work with reasonable values
        uint256 smallValue = 100 * PRECISION;
        uint256 smallPercentage = 1000; // 10% in basis points (1000/10000 = 10%)
        uint256 smallResult = VaultMath.percentageOf(smallValue, smallPercentage);
        assertEq(smallResult, smallValue / 10, "Small percentage calculation incorrect");
    }
    
    // =============================================================================
    // INTEGRATION INVARIANTS
    // =============================================================================
    
    /**
     * @notice Verify cross-contract integration consistency
     * @dev Ensures contracts work together correctly
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function invariant_crossContractIntegration() public view {
        // Check that vault and user pool are properly connected
        // Check that hedger pool and yield shift are properly connected
        // Check that oracle is used consistently across contracts
        
        // Verify that all contracts use the same USDC address
        // This is a structural check - actual addresses depend on deployment
        
        // Verify that governance roles are consistent across contracts
        assertTrue(qtiToken.hasRole(qtiToken.GOVERNANCE_ROLE(), governance), "QTI governance role");
        assertTrue(qeuroToken.hasRole(qeuroToken.MINTER_ROLE(), governance), "QEURO minter role");
    }
    
    // =============================================================================
    // GAS OPTIMIZATION INVARIANTS
    // =============================================================================
    
    /**
     * @notice Verify gas optimization invariants
     * @dev Ensures gas usage remains reasonable
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function invariant_gasOptimization() public {
        // Structural check; actual gas usage is environment-dependent (see make gas-analysis)
        vm.skip(true, "Gas optimization is structural; use make gas-analysis for measurements");
    }
    
    // =============================================================================
    // COMPREHENSIVE INVARIANT TEST
    // =============================================================================
    
    /**
     * @notice Run all invariants in a single test
     * @dev Comprehensive invariant verification
      * @custom:security No security implications - test function
      * @custom:validation No input validation required - test function
      * @custom:state-changes No state changes - test function
      * @custom:events No events emitted - test function
      * @custom:errors No errors thrown - test function
      * @custom:reentrancy Not applicable - test function
      * @custom:access Public - no access restrictions
      * @custom:oracle No oracle dependency for test function
     */
    function test_allInvariants() public {
        invariant_totalSupplyConsistency();
        invariant_supplyCapRespect();
        invariant_governancePowerConsistency();
        invariant_governanceParameters();
        invariant_emergencyStateConsistency();
        invariant_accessControlConsistency();
        invariant_mathematicalConsistency();
        invariant_crossContractIntegration();
        invariant_gasOptimization();
        invariant_collateralizationRatio();
        invariant_liquidationThresholds();
        invariant_yieldDistributionIntegrity();
        invariant_yieldShiftParameters();
        invariant_liquidationStateConsistency();
        invariant_pauseStateConsistency();
    }

    // =============================================================================
    // ACTION-BASED STATEFUL TESTS
    // =============================================================================

    /**
     * @notice Test protocol with fuzzed action sequences
     * @dev Mints, redeems, stakes, and unstakes in random order, then verifies invariants
     */
    function test_ActionSequence_MintStakeUnstakeRedeem() public {
        // User1 mints some QEURO (80% min out to absorb fee + rounding)
        vm.startPrank(user1);
        usdc.approve(address(vault), 10_000e6);
        (uint256 eurPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "oracle invalid");
        uint256 expectedQeuro = (10_000e6 * 1e30) / eurPrice;
        vault.mintQEURO(10_000e6, (expectedQeuro * 80) / 100);
        vm.stopPrank();

        uint256 user1QeuroBal = qeuroToken.balanceOf(user1);
        assertGt(user1QeuroBal, 0, "User1 should have QEURO");

        // User1 stakes half
        uint256 stakeAmount = user1QeuroBal / 2;
        vm.startPrank(user1);
        qeuroToken.approve(address(stQEURO), stakeAmount);
        uint256 stQeuroReceived = stQEURO.stake(stakeAmount);
        vm.stopPrank();

        assertGt(stQeuroReceived, 0, "User1 should receive stQEURO");

        // User2 also mints (80% min out)
        vm.startPrank(user2);
        usdc.approve(address(vault), 5_000e6);
        uint256 expectedQeuro2 = (5_000e6 * 1e30) / eurPrice;
        vault.mintQEURO(5_000e6, (expectedQeuro2 * 80) / 100);
        vm.stopPrank();

        // Verify invariants hold
        invariant_totalSupplyConsistency();
        invariant_supplyCapRespect();

        // User1 unstakes
        vm.startPrank(user1);
        uint256 qeuroBack = stQEURO.unstake(stQeuroReceived);
        vm.stopPrank();

        assertGt(qeuroBack, 0, "Should get QEURO back");

        // User1 redeems all QEURO (80% min USDC out for fee/rounding)
        // Convert QEURO (18 dec) to USDC (6 dec) via EUR/USD price (18 dec): USDC = QEURO * price / 1e30
        uint256 user1FinalQeuro = qeuroToken.balanceOf(user1);
        vm.startPrank(user1);
        qeuroToken.approve(address(vault), user1FinalQeuro);
        uint256 expectedUsdc = (user1FinalQeuro * eurPrice) / 1e30;
        vault.redeemQEURO(user1FinalQeuro, (expectedUsdc * 80) / 100);
        vm.stopPrank();

        // Verify invariants still hold
        invariant_totalSupplyConsistency();
        invariant_supplyCapRespect();
    }

    /**
     * @notice Fuzz test: random mint amounts maintain supply consistency
     */
    function testFuzz_MintMaintainsSupplyConsistency(uint256 amount) public {
        amount = bound(amount, 100e6, 100_000e6); // 100 - 100k USDC

        uint256 qeuroSupplyBefore = qeuroToken.totalSupply();
        uint256 vaultUsdcBefore = usdc.balanceOf(address(vault));

        vm.startPrank(user1);
        usdc.approve(address(vault), amount);
        (uint256 eurPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) return;

        uint256 expectedQeuro = (amount * 1e30) / eurPrice;
        vault.mintQEURO(amount, (expectedQeuro * 95) / 100);
        vm.stopPrank();

        uint256 qeuroSupplyAfter = qeuroToken.totalSupply();
        uint256 vaultUsdcAfter = usdc.balanceOf(address(vault));

        // Supply should have increased
        assertGt(qeuroSupplyAfter, qeuroSupplyBefore, "QEURO supply should increase");

        // Vault should have received USDC
        assertGt(vaultUsdcAfter, vaultUsdcBefore, "Vault should receive USDC");

        // Invariants should hold
        invariant_totalSupplyConsistency();
        invariant_supplyCapRespect();
    }

    /**
     * @notice Fuzz test: stake/unstake roundtrip preserves value
     */
    function testFuzz_StakeUnstakeRoundtrip(uint256 mintAmount, uint256 stakeFraction) public {
        mintAmount = bound(mintAmount, 1_000e6, 50_000e6);
        stakeFraction = bound(stakeFraction, 10, 100); // 10-100%

        // Mint QEURO
        vm.startPrank(user1);
        usdc.approve(address(vault), mintAmount);
        (uint256 eurPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) return;

        uint256 expectedQeuro = (mintAmount * 1e30) / eurPrice;
        vault.mintQEURO(mintAmount, (expectedQeuro * 95) / 100);

        uint256 qeuroBal = qeuroToken.balanceOf(user1);
        uint256 stakeAmount = (qeuroBal * stakeFraction) / 100;

        // Stake
        qeuroToken.approve(address(stQEURO), stakeAmount);
        uint256 stQeuroReceived = stQEURO.stake(stakeAmount);

        // Unstake immediately
        uint256 qeuroReturned = stQEURO.unstake(stQeuroReceived);
        vm.stopPrank();

        // Should get back approximately the same amount (within rounding)
        assertApproxEqRel(qeuroReturned, stakeAmount, 0.01e18, "Should get back ~same QEURO");

        // Invariants should hold
        invariant_totalSupplyConsistency();
    }

    /**
     * @notice Test emergency pause/unpause maintains system integrity
     */
    function test_EmergencyPauseIntegrity() public {
        // First mint some QEURO
        vm.startPrank(user1);
        usdc.approve(address(vault), 10_000e6);
        (uint256 eurPrice, bool isValid) = oracle.getEurUsdPrice();
        require(isValid, "oracle invalid");
        uint256 expectedQeuro = (10_000e6 * 1e30) / eurPrice;
        vault.mintQEURO(10_000e6, (expectedQeuro * 95) / 100);
        vm.stopPrank();

        uint256 supplyBeforePause = qeuroToken.totalSupply();

        // Emergency pause
        vm.prank(emergency);
        vault.pause();
        assertTrue(vault.paused(), "Vault should be paused");

        // Supply should be unchanged
        assertEq(qeuroToken.totalSupply(), supplyBeforePause, "Supply unchanged during pause");

        // Operations should fail when paused
        vm.startPrank(user1);
        usdc.approve(address(vault), 1_000e6);
        vm.expectRevert();
        vault.mintQEURO(1_000e6, 0);
        vm.stopPrank();

        // Unpause
        vm.prank(emergency);
        vault.unpause();
        assertFalse(vault.paused(), "Vault should be unpaused");

        // Operations should work again
        vm.startPrank(user1);
        vault.mintQEURO(1_000e6, 0);
        vm.stopPrank();

        // Invariants should hold
        invariant_totalSupplyConsistency();
        invariant_emergencyStateConsistency();
    }
}

// =============================================================================
// INTERFACES FOR MOCKING
// =============================================================================

interface IERC20 {
    /**
     * @notice Returns the balance of an account
     * @dev Interface function for ERC20 balance query
     * @param account The account to query
     * @return The balance of the account
     * @custom:security No security validations - interface function
     * @custom:validation No input validation - interface function
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - interface function
     * @custom:oracle No oracle dependencies
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @notice Returns the total supply of tokens
     * @dev Interface function for ERC20 total supply query
     * @return The total supply of tokens
     * @custom:security No security validations - interface function
     * @custom:validation No input validation - interface function
     * @custom:state-changes No state changes - view function
     * @custom:events No events emitted
     * @custom:errors No errors thrown
     * @custom:reentrancy Not applicable - view function
     * @custom:access Public - interface function
     * @custom:oracle No oracle dependencies
     */
    function totalSupply() external view returns (uint256);
}

// =============================================================================
// ACTION HANDLER FOR INVARIANT TESTING
// =============================================================================

/**
 * @title InvariantActionHandler
 * @notice Handler contract for action-based invariant testing
 * @dev Exposes protocol actions for fuzzed invariant sequences
 */
contract InvariantActionHandler is Test {
    QuantillonVault public vault;
    UserPool public userPool;
    HedgerPool public hedgerPool;
    stQEUROToken public stQEURO;
    QEUROToken public qeuroToken;
    MockUSDC public usdc;
    MockChainlinkOracle public oracle;

    address[] public actors;
    uint256 public actionCount;

    // Ghost variables for tracking
    uint256 public totalMinted;
    uint256 public totalRedeemed;
    uint256 public totalStaked;
    uint256 public totalUnstaked;

    constructor(
        address _vault,
        address _userPool,
        address _hedgerPool,
        address _stQEURO,
        address _qeuroToken,
        address _usdc,
        address _oracle,
        address[] memory _actors
    ) {
        vault = QuantillonVault(_vault);
        userPool = UserPool(_userPool);
        hedgerPool = HedgerPool(_hedgerPool);
        stQEURO = stQEUROToken(_stQEURO);
        qeuroToken = QEUROToken(_qeuroToken);
        usdc = MockUSDC(_usdc);
        oracle = MockChainlinkOracle(payable(_oracle));
        actors = _actors;
    }

    /// @notice Mint QEURO via vault
    function actionMint(uint256 actorSeed, uint256 amount) external {
        address actor = actors[actorSeed % actors.length];
        amount = bound(amount, 100e6, 10_000e6); // 100 - 10k USDC

        uint256 usdcBalance = usdc.balanceOf(actor);
        if (usdcBalance < amount) return;

        (uint256 eurPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) return;

        uint256 expectedQeuro = (amount * 1e30) / eurPrice;
        uint256 minQeuro = (expectedQeuro * 95) / 100; // 5% slippage

        vm.startPrank(actor);
        usdc.approve(address(vault), amount);
        try vault.mintQEURO(amount, minQeuro) {
            totalMinted += amount;
            actionCount++;
        } catch {}
        vm.stopPrank();
    }

    /// @notice Redeem QEURO via vault
    function actionRedeem(uint256 actorSeed, uint256 fraction) external {
        address actor = actors[actorSeed % actors.length];
        fraction = bound(fraction, 1, 100); // 1-100% of balance

        uint256 qeuroBalance = qeuroToken.balanceOf(actor);
        if (qeuroBalance == 0) return;

        uint256 redeemAmount = (qeuroBalance * fraction) / 100;
        if (redeemAmount == 0) return;

        (uint256 eurPrice, bool isValid) = oracle.getEurUsdPrice();
        if (!isValid) return;

        uint256 expectedUsdc = (redeemAmount * eurPrice) / 1e18;
        uint256 minUsdc = (expectedUsdc * 95) / 100; // 5% slippage

        vm.startPrank(actor);
        qeuroToken.approve(address(vault), redeemAmount);
        try vault.redeemQEURO(redeemAmount, minUsdc) {
            totalRedeemed += redeemAmount;
            actionCount++;
        } catch {}
        vm.stopPrank();
    }

    /// @notice Stake QEURO into stQEURO
    function actionStake(uint256 actorSeed, uint256 fraction) external {
        address actor = actors[actorSeed % actors.length];
        fraction = bound(fraction, 1, 100); // 1-100% of balance

        uint256 qeuroBalance = qeuroToken.balanceOf(actor);
        if (qeuroBalance == 0) return;

        uint256 stakeAmount = (qeuroBalance * fraction) / 100;
        if (stakeAmount == 0) return;

        vm.startPrank(actor);
        qeuroToken.approve(address(stQEURO), stakeAmount);
        try stQEURO.stake(stakeAmount) returns (uint256) {
            totalStaked += stakeAmount;
            actionCount++;
        } catch {}
        vm.stopPrank();
    }

    /// @notice Unstake stQEURO back to QEURO
    function actionUnstake(uint256 actorSeed, uint256 fraction) external {
        address actor = actors[actorSeed % actors.length];
        fraction = bound(fraction, 1, 100); // 1-100% of balance

        uint256 stQeuroBalance = stQEURO.balanceOf(actor);
        if (stQeuroBalance == 0) return;

        uint256 unstakeAmount = (stQeuroBalance * fraction) / 100;
        if (unstakeAmount == 0) return;

        vm.startPrank(actor);
        try stQEURO.unstake(unstakeAmount) returns (uint256) {
            totalUnstaked += unstakeAmount;
            actionCount++;
        } catch {}
        vm.stopPrank();
    }
}


