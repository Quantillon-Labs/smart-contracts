// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {HedgerPool} from "../src/core/HedgerPool.sol";
import {UserPool} from "../src/core/UserPool.sol";
import {QTIToken} from "../src/core/QTIToken.sol";
import {TimelockUpgradeable} from "../src/core/TimelockUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOracle} from "../src/interfaces/IOracle.sol";
import {IQuantillonVault} from "../src/interfaces/IQuantillonVault.sol";

/**
 * @title RaceConditionTests
 * @notice Comprehensive testing for race conditions and concurrent operations
 *
 * @dev This test suite covers:
 *      - Multi-user concurrent operations
 *      - Liquidation race conditions
 *      - Yield distribution timing
 *      - Governance proposal races
 *      - Price update races
 *      - Block timestamp manipulation
 *
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract RaceConditionTests is Test {
    // =============================================================================
    // STATE VARIABLES
    // =============================================================================

    TimeProvider public timeProviderImpl;
    TimeProvider public timeProvider;
    HedgerPool public hedgerPoolImpl;
    HedgerPool public hedgerPool;
    UserPool public userPoolImpl;
    UserPool public userPool;
    QTIToken public qtiTokenImpl;
    QTIToken public qtiToken;
    TimelockUpgradeable public timelockImpl;
    TimelockUpgradeable public timelock;

    // Mock addresses
    address public mockUSDC = address(0x100);
    address public mockOracle = address(0x101);
    address public mockYieldShift = address(0x102);
    address public mockQEURO = address(0x103);
    address public mockstQEURO = address(0x104);
    address public mockVault = address(0x105);
    address public mockTimelock = address(0x106);

    // Test addresses
    address public admin = address(0x1);
    address public treasury = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);
    address public user3 = address(0x5);
    address public liquidator1 = address(0x6);
    address public liquidator2 = address(0x7);
    address public signer1 = address(0x8);

    uint256 constant PRECISION = 1e18;
    uint256 constant USDC_PRECISION = 1e6;

    // =============================================================================
    // SETUP
    // =============================================================================

    function setUp() public {
        // Deploy TimeProvider
        timeProviderImpl = new TimeProvider();
        bytes memory timeProviderInitData = abi.encodeWithSelector(
            TimeProvider.initialize.selector,
            admin,
            admin,
            admin
        );
        ERC1967Proxy timeProviderProxy = new ERC1967Proxy(address(timeProviderImpl), timeProviderInitData);
        timeProvider = TimeProvider(address(timeProviderProxy));

        // Deploy TimelockUpgradeable
        timelockImpl = new TimelockUpgradeable(timeProvider);
        bytes memory timelockInitData = abi.encodeWithSelector(
            TimelockUpgradeable.initialize.selector,
            admin
        );
        ERC1967Proxy timelockProxy = new ERC1967Proxy(address(timelockImpl), timelockInitData);
        timelock = TimelockUpgradeable(address(timelockProxy));

        // Deploy HedgerPool
        hedgerPoolImpl = new HedgerPool(timeProvider);
        bytes memory hedgerPoolInitData = abi.encodeWithSelector(
            HedgerPool.initialize.selector,
            admin,
            mockUSDC,
            mockOracle,
            mockYieldShift,
            address(timelock),
            treasury,
            mockVault
        );
        ERC1967Proxy hedgerPoolProxy = new ERC1967Proxy(address(hedgerPoolImpl), hedgerPoolInitData);
        hedgerPool = HedgerPool(address(hedgerPoolProxy));

        // Deploy UserPool
        userPoolImpl = new UserPool(timeProvider);
        bytes memory userPoolInitData = abi.encodeWithSelector(
            UserPool.initialize.selector,
            admin,
            mockUSDC,
            mockQEURO,
            mockstQEURO,
            mockYieldShift,
            treasury,
            100,
            100,
            86400
        );
        ERC1967Proxy userPoolProxy = new ERC1967Proxy(address(userPoolImpl), userPoolInitData);
        userPool = UserPool(address(userPoolProxy));

        // Deploy QTIToken
        qtiTokenImpl = new QTIToken(timeProvider);
        bytes memory qtiInitData = abi.encodeWithSelector(
            QTIToken.initialize.selector,
            admin,
            treasury,
            address(timelock)
        );
        ERC1967Proxy qtiProxy = new ERC1967Proxy(address(qtiTokenImpl), qtiInitData);
        qtiToken = QTIToken(address(qtiProxy));

        // Setup
        vm.startPrank(admin);
        timelock.addMultisigSigner(signer1);
        vm.stopPrank();

        _setupMocks();
    }

    function _setupMocks() internal {
        // Mock USDC balanceOf and transfer
        vm.mockCall(
            mockUSDC,
            abi.encodeWithSelector(IERC20.balanceOf.selector),
            abi.encode(1000000 * USDC_PRECISION)
        );
        vm.mockCall(
            mockUSDC,
            abi.encodeWithSelector(IERC20.transfer.selector),
            abi.encode(true)
        );
        // HedgerPool calls usdc.transferFrom(hedger, vault, amount); mock exact (user1, mockVault, amount) for each test amount
        vm.mockCall(
            mockUSDC,
            abi.encodeWithSelector(IERC20.transferFrom.selector, user1, mockVault, 5000 * USDC_PRECISION),
            abi.encode(true)
        );
        vm.mockCall(
            mockUSDC,
            abi.encodeWithSelector(IERC20.transferFrom.selector, user1, mockVault, 3000 * USDC_PRECISION),
            abi.encode(true)
        );
        vm.mockCall(
            mockUSDC,
            abi.encodeWithSelector(IERC20.transferFrom.selector, user1, mockVault, 10000 * USDC_PRECISION),
            abi.encode(true)
        );
        vm.mockCall(
            mockUSDC,
            abi.encodeWithSelector(IERC20.transferFrom.selector, user1, mockVault, 2000 * USDC_PRECISION),
            abi.encode(true)
        );
        vm.mockCall(
            mockUSDC,
            abi.encodeWithSelector(IERC20.transferFrom.selector, user1, mockVault, 1000 * USDC_PRECISION),
            abi.encode(true)
        );

        // Mock Oracle
        vm.mockCall(
            mockOracle,
            abi.encodeWithSelector(IOracle.getEurUsdPrice.selector),
            abi.encode(110 * 1e16, true) // 1.10 EUR/USD
        );

        // Mock Vault functions called by HedgerPool
        vm.mockCall(
            mockVault,
            abi.encodeWithSelector(IQuantillonVault.addHedgerDeposit.selector),
            abi.encode()
        );
        vm.mockCall(
            mockVault,
            abi.encodeWithSelector(IQuantillonVault.withdrawHedgerDeposit.selector),
            abi.encode()
        );
        vm.mockCall(
            mockVault,
            abi.encodeWithSelector(IQuantillonVault.isProtocolCollateralized.selector),
            abi.encode(true, 1000000 * USDC_PRECISION) // collateralized with 1M margin
        );
        vm.mockCall(
            mockVault,
            abi.encodeWithSelector(IQuantillonVault.totalMinted.selector),
            abi.encode(uint256(1000000 * 1e18)) // 1M QEURO outstanding
        );
    }

    // =============================================================================
    // MULTI-USER CONCURRENT OPERATIONS TESTS
    // =============================================================================

    /**
     * @notice Test concurrent-like sequence: two operations in sequence, state consistent
     * @dev Simulate two blocks: roll, first action; roll, second action; assert totals
     */
    function test_RaceCondition_ConcurrentDeposits() public {
        vm.prank(admin);
        hedgerPool.setSingleHedger(user1);
        uint256 amount1 = 5_000 * USDC_PRECISION;
        vm.prank(user1);
        uint256 pos1 = hedgerPool.enterHedgePosition(amount1, 5);
        vm.roll(block.number + 1);
        uint256 amount2 = 3_000 * USDC_PRECISION;
        vm.prank(user1);
        hedgerPool.addMargin(pos1, amount2);
        assertGe(hedgerPool.totalMargin(), amount1, "Total margin should be at least first deposit");
        vm.roll(block.number + 600);
        vm.prank(user1);
        hedgerPool.removeMargin(pos1, amount2);
        vm.prank(user1);
        hedgerPool.exitHedgePosition(pos1);
        assertEq(hedgerPool.totalMargin(), 0, "Total margin should be 0 after exit");
    }

    /**
     * @notice Test two users enter then exit in sequence; state consistent after both exits
     * @dev Simulates concurrent-withdrawal scenario with HedgerPool: user1 enter/exit, user2 enter/exit, total margin 0
     */
    function test_RaceCondition_ConcurrentWithdrawals() public {
        vm.mockCall(
            mockUSDC,
            abi.encodeWithSelector(IERC20.transferFrom.selector, user2, mockVault, 3_000 * USDC_PRECISION),
            abi.encode(true)
        );
        uint256 amount1 = 5_000 * USDC_PRECISION;
        uint256 amount2 = 3_000 * USDC_PRECISION;

        vm.prank(admin);
        hedgerPool.setSingleHedger(user1);
        vm.prank(user1);
        uint256 pos1 = hedgerPool.enterHedgePosition(amount1, 5);
        vm.roll(block.number + 600);
        vm.prank(user1);
        hedgerPool.exitHedgePosition(pos1);

        vm.prank(admin);
        hedgerPool.setSingleHedger(user2);
        vm.prank(user2);
        uint256 pos2 = hedgerPool.enterHedgePosition(amount2, 5);
        vm.roll(block.number + 600);
        vm.prank(user2);
        hedgerPool.exitHedgePosition(pos2);

        assertEq(hedgerPool.totalMargin(), 0, "Total margin 0 after both exits");
        assertFalse(hedgerPool.hasActiveHedger(), "No active hedger after exits");
    }

    /**
     * @notice Test pause during operation: user enters position, admin pauses, user exit reverts
     * @dev Verifies whenNotPaused blocks exit/removeMargin after pause
     */
    function test_RaceCondition_PauseDuringOperation_ExitReverts() public {
        vm.prank(admin);
        hedgerPool.setSingleHedger(user1);
        vm.prank(user1);
        uint256 positionId = hedgerPool.enterHedgePosition(10_000 * USDC_PRECISION, 5);
        vm.roll(block.number + 600);

        // admin has EMERGENCY_ROLE from init; prank applies only to next call so use startPrank for pause/unpause
        vm.startPrank(admin);
        hedgerPool.pause();
        vm.stopPrank();
        assertTrue(hedgerPool.paused(), "HedgerPool should be paused");

        vm.prank(user1);
        vm.expectRevert();
        hedgerPool.exitHedgePosition(positionId);

        vm.prank(admin);
        hedgerPool.unpause();
        vm.prank(user1);
        hedgerPool.exitHedgePosition(positionId);
        assertEq(hedgerPool.totalMargin(), 0, "Exit succeeds after unpause");
    }

    /**
     * @notice Test deposit and withdrawal timing with vm.roll
     * @dev HedgerPool: enter position, advance blocks (liquidation cooldown), add/remove margin, exit; assert state
     */
    function test_RaceCondition_DepositWithdrawSimultaneous() public {
        uint256 marginAmount = 10_000 * USDC_PRECISION;
        vm.prank(admin);
        hedgerPool.setSingleHedger(user1);
        vm.prank(user1);
        uint256 positionId = hedgerPool.enterHedgePosition(marginAmount, 5);
        assertTrue(hedgerPool.hasActiveHedger(), "Hedger should be active");
        vm.roll(block.number + 600); // liquidation cooldown
        vm.prank(user1);
        hedgerPool.addMargin(positionId, 2_000 * USDC_PRECISION);
        vm.prank(user1);
        hedgerPool.removeMargin(positionId, 1_000 * USDC_PRECISION);
        vm.prank(user1);
        hedgerPool.exitHedgePosition(positionId);
        assertFalse(hedgerPool.hasActiveHedger(), "Hedger should be inactive after exit");
        assertEq(hedgerPool.totalMargin(), 0, "Total margin should be 0");
    }

    // =============================================================================
    // LIQUIDATION RACE CONDITION TESTS
    // =============================================================================

    /**
     * @notice Test multiple liquidators targeting same position
     * @dev Only one should succeed
     */
    function test_RaceCondition_MultipleLiquidators() public {
        vm.skip(true, "Requires full protocol; see LiquidationScenarios / IntegrationTests");
    }

    /**
     * @notice Test liquidation vs margin addition race
     * @dev User adding margin while being liquidated
     */
    function test_RaceCondition_LiquidationVsMarginAdd() public {
        vm.skip(true, "Requires full protocol; see LiquidationScenarios");
    }

    /**
     * @notice Test partial liquidation race conditions
     */
    function test_RaceCondition_PartialLiquidation() public {
        vm.skip(true, "Requires full protocol; see LiquidationScenarios");
    }

    // =============================================================================
    // YIELD DISTRIBUTION RACE CONDITION TESTS
    // =============================================================================

    /**
     * @notice Test yield claim race conditions
     * @dev Multiple users claiming yield simultaneously
     */
    function test_RaceCondition_YieldClaim() public {
        vm.skip(true, "Requires full protocol; see IntegrationTests / YieldStakingEdgeCases");
    }

    /**
     * @notice Test yield distribution vs new deposit race
     */
    function test_RaceCondition_YieldVsDeposit() public {
        vm.skip(true, "Requires full protocol; see IntegrationTests");
    }

    /**
     * @notice Test yield distribution timing boundary
     */
    function test_RaceCondition_YieldDistributionTiming() public {
        vm.skip(true, "Requires full protocol; see YieldStakingEdgeCases / TimeBlockEdgeCases");
    }

    // =============================================================================
    // GOVERNANCE RACE CONDITION TESTS
    // =============================================================================

    /**
     * @notice Test proposal creation race - multiple proposals can coexist and each is executable
     * @dev Propose two upgrades, approve both, warp past 48h, execute both; no cross-interference
     */
    function test_RaceCondition_ProposalCreation() public {
        address implA = address(0xA1);
        address implB = address(0xB2);
        vm.prank(admin);
        timelock.proposeUpgrade(implA, "Upgrade A", 0);
        vm.prank(admin);
        timelock.proposeUpgrade(implB, "Upgrade B", 0);
        vm.prank(admin);
        timelock.approveUpgrade(implA);
        vm.prank(signer1);
        timelock.approveUpgrade(implA);
        vm.prank(admin);
        timelock.approveUpgrade(implB);
        vm.prank(signer1);
        timelock.approveUpgrade(implB);
        vm.warp(block.timestamp + 48 hours + 1);
        vm.prank(admin);
        timelock.executeUpgrade(implA);
        vm.prank(admin);
        timelock.executeUpgrade(implB);
        // Both proposals executed; no race between multiple proposals
    }

    /**
     * @notice Test voting deadline race - timelock has clear execution cutoff
     * @dev Propose, approve, warp before 48h -> execute reverts; warp past 48h -> execute succeeds
     */
    function test_RaceCondition_VotingDeadline() public {
        address newImpl = address(0x777);
        vm.prank(admin);
        timelock.proposeUpgrade(newImpl, "Deadline test", 0);
        vm.prank(admin);
        timelock.approveUpgrade(newImpl);
        vm.prank(signer1);
        timelock.approveUpgrade(newImpl);
        vm.warp(block.timestamp + 48 hours - 1); // before deadline
        vm.prank(admin);
        vm.expectRevert();
        timelock.executeUpgrade(newImpl);
        vm.warp(block.timestamp + 2); // past 48h
        vm.prank(admin);
        timelock.executeUpgrade(newImpl);
    }

    /**
     * @notice Test proposal execution race - only one execution succeeds
     * @dev Same logic as TimelockExecution: propose, approve, execute once (success), execute again (revert)
     */
    function test_RaceCondition_ProposalExecution() public {
        address newImpl = address(0x888);
        vm.prank(admin);
        timelock.proposeUpgrade(newImpl, "Proposal race test", 0);
        vm.prank(admin);
        timelock.approveUpgrade(newImpl);
        vm.prank(signer1);
        timelock.approveUpgrade(newImpl);
        vm.warp(block.timestamp + 48 hours + 1);
        vm.prank(admin);
        timelock.executeUpgrade(newImpl);
        vm.prank(admin);
        vm.expectRevert();
        timelock.executeUpgrade(newImpl);
    }

    /**
     * @notice Test timelock execution race
     */
    function test_RaceCondition_TimelockExecution() public {
        address newImpl = address(0x999);

        // Propose upgrade
        vm.prank(admin);
        timelock.proposeUpgrade(newImpl, "Test upgrade", 0);

        // Approve
        vm.prank(admin);
        timelock.approveUpgrade(newImpl);
        vm.prank(signer1);
        timelock.approveUpgrade(newImpl);

        // Wait for timelock
        vm.warp(block.timestamp + 48 hours + 1);

        // First execution succeeds
        vm.prank(admin);
        timelock.executeUpgrade(newImpl);

        // Second execution should fail (already executed)
        vm.prank(admin);
        vm.expectRevert();
        timelock.executeUpgrade(newImpl);
    }

    // =============================================================================
    // PRICE UPDATE RACE CONDITION TESTS
    // =============================================================================

    /**
     * @notice Test operations during price update
     * @dev Operations should use consistent price within transaction
     */
    function test_RaceCondition_PriceUpdate() public {
        vm.skip(true, "Requires full protocol with vault/oracle; see CombinedAttackVectors / OracleEdgeCases");
    }

    /**
     * @notice Test front-running price updates
     */
    function test_RaceCondition_PriceFrontrunning() public {
        vm.skip(true, "Requires full protocol; see CombinedAttackVectors");
    }

    // =============================================================================
    // BLOCK TIMESTAMP TESTS
    // =============================================================================

    /**
     * @notice Test block timestamp dependence - timelock enforces 48h delay regardless of warp
     * @dev vm.warp before 48h: execute reverts; warp past 48h: execute succeeds
     */
    function test_RaceCondition_TimestampManipulation() public {
        address newImpl = address(0x715);
        vm.prank(admin);
        timelock.proposeUpgrade(newImpl, "Timestamp test", 0);
        vm.prank(admin);
        timelock.approveUpgrade(newImpl);
        vm.prank(signer1);
        timelock.approveUpgrade(newImpl);
        vm.warp(block.timestamp + 48 hours - 1);
        vm.prank(admin);
        vm.expectRevert();
        timelock.executeUpgrade(newImpl);
        vm.warp(block.timestamp + 2);
        vm.prank(admin);
        timelock.executeUpgrade(newImpl);
    }

    /**
     * @notice Test cooldown period race
     */
    function test_RaceCondition_CooldownPeriod() public {
        vm.skip(true, "Requires full protocol; see UserPool / HedgerPool tests");
    }

    // =============================================================================
    // STAKING RACE CONDITION TESTS
    // =============================================================================

    /**
     * @notice Test stake and unstake race
     */
    function test_RaceCondition_StakeUnstake() public {
        vm.skip(true, "Requires full protocol; see IntegrationTests / stQEUROToken");
    }

    /**
     * @notice Test voting power snapshot race
     */
    function test_RaceCondition_VotingPowerSnapshot() public {
        vm.skip(true, "Requires full protocol; see QTIToken / GovernanceAttackVectors");
    }

    // =============================================================================
    // UPGRADE RACE CONDITION TESTS
    // =============================================================================

    /**
     * @notice Test operations during upgrade
     */
    function test_RaceCondition_DuringUpgrade() public {
        vm.skip(true, "Requires full protocol; see UpgradeTests");
    }

    /**
     * @notice Test approval and upgrade execution race
     */
    function test_RaceCondition_ApprovalExecution() public {
        vm.skip(true, "Requires full protocol; see TimelockUpgradeable tests");
    }

    // =============================================================================
    // EMERGENCY PAUSE RACE CONDITION TESTS
    // =============================================================================

    /**
     * @notice Test pause during active operation
     */
    function test_RaceCondition_PauseDuringOperation() public {
        // Pause the contract - use startPrank to avoid prank being consumed by view call
        vm.startPrank(admin);
        bytes32 emergencyRole = hedgerPool.EMERGENCY_ROLE();
        hedgerPool.grantRole(emergencyRole, admin);

        hedgerPool.pause();

        // Operations should fail when paused
        assertTrue(hedgerPool.paused(), "Should be paused");

        // Unpause
        hedgerPool.unpause();
        vm.stopPrank();

        assertFalse(hedgerPool.paused(), "Should be unpaused");
    }

    /**
     * @notice Test multiple pause/unpause race
     */
    function test_RaceCondition_MultiplePauseUnpause() public {
        vm.startPrank(admin);
        hedgerPool.grantRole(hedgerPool.EMERGENCY_ROLE(), admin);

        // Multiple pause/unpause should result in final state
        hedgerPool.pause();
        assertTrue(hedgerPool.paused(), "Should be paused");

        hedgerPool.unpause();
        assertFalse(hedgerPool.paused(), "Should be unpaused");

        hedgerPool.pause();
        assertTrue(hedgerPool.paused(), "Should be paused again");

        vm.stopPrank();
    }

    // =============================================================================
    // COMPREHENSIVE RACE CONDITION SIMULATION
    // =============================================================================

    /**
     * @notice Simulate complex multi-party race scenario
     */
    function test_RaceCondition_ComplexScenario() public {
        vm.skip(true, "Requires full protocol; see IntegrationTests / LiquidationScenarios");
    }

    /**
     * @notice Test that all critical operations are atomic
     */
    function test_RaceCondition_AtomicityVerification() public {
        vm.skip(true, "Requires full protocol; see IntegrationTests");
    }
}
