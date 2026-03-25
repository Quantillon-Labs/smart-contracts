// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockAaveVault} from "../src/mocks/MockAaveVault.sol";
import {AaveStakingVaultAdapter} from "../src/core/vaults/AaveStakingVaultAdapter.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";

/**
 * @title MockUSDCForAdapter
 * @notice Minimal ERC-20 mock for AaveStakingVaultAdapter tests.
 */
contract MockUSDCForAdapter {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint8 public decimals = 6;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
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

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

/**
 * @title MockYieldShiftForAdapter
 * @notice Minimal YieldShift mock that records addYield calls.
 */
contract MockYieldShiftForAdapter {
    uint256 public lastVaultId;
    uint256 public lastAmount;
    bytes32 public lastSource;
    uint256 public totalYieldAdded;

    function addYield(uint256 vaultId, uint256 amount, bytes32 source) external {
        lastVaultId  = vaultId;
        lastAmount   = amount;
        lastSource   = source;
        totalYieldAdded += amount;
    }

    function currentYieldShift() external pure returns (uint256) {
        return 5000;
    }
}

/**
 * @title AaveStakingVaultAdapterTest
 * @notice Unit tests for AaveStakingVaultAdapter.
 * @dev Covers deposit, withdraw, harvestYield, totalUnderlying, and governance functions.
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract AaveStakingVaultAdapterTest is Test {
    // =============================================================================
    // STATE
    // =============================================================================

    AaveStakingVaultAdapter public adapter;
    MockAaveVault public mockVault;
    MockUSDCForAdapter public usdc;
    MockYieldShiftForAdapter public yieldShift;

    address public admin       = address(0x1);
    // admin is granted VAULT_MANAGER_ROLE in constructor; vaultMgr mirrors it for clarity
    address public vaultMgr    = address(0x1);
    address public yieldSource = address(0x3);
    address public other       = address(0x9);

    uint256 public constant VAULT_ID      = 1;
    uint256 public constant DEPOSIT_AMT   = 1000e6; // 1000 USDC
    uint256 public constant YIELD_AMT     = 100e6;  //  100 USDC

    // =============================================================================
    // SETUP
    // =============================================================================

    function setUp() public {
        usdc       = new MockUSDCForAdapter();
        mockVault  = new MockAaveVault(address(usdc));
        yieldShift = new MockYieldShiftForAdapter();
        adapter    = new AaveStakingVaultAdapter(admin, address(usdc), address(mockVault), address(yieldShift), VAULT_ID);

        // Fund vaultMgr
        usdc.mint(vaultMgr,    10_000e6);
        usdc.mint(yieldSource, 10_000e6);

        // Approvals
        vm.prank(vaultMgr);
        usdc.approve(address(adapter), type(uint256).max);

        vm.prank(yieldSource);
        usdc.approve(address(mockVault), type(uint256).max);
    }

    // =============================================================================
    // CONSTRUCTOR TESTS
    // =============================================================================

    /**
     * @notice Constructor reverts on zero admin address.
     * @custom:security Validates constructor zero-address guard
     * @custom:validation Reverts with ZeroAddress
     * @custom:state-changes No state changes
     * @custom:events No events
     * @custom:errors ZeroAddress
     * @custom:reentrancy Not applicable
     * @custom:access No restrictions
     * @custom:oracle No dependency
     */
    function test_Constructor_ZeroAdmin_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        new AaveStakingVaultAdapter(address(0), address(usdc), address(mockVault), address(yieldShift), VAULT_ID);
    }

    /**
     * @notice Constructor reverts on zero vault id.
     * @custom:security Validates constructor vault id guard
     * @custom:validation Reverts with InvalidVault
     * @custom:state-changes No state changes
     * @custom:events No events
     * @custom:errors InvalidVault
     * @custom:reentrancy Not applicable
     * @custom:access No restrictions
     * @custom:oracle No dependency
     */
    function test_Constructor_ZeroVaultId_Reverts() public {
        vm.expectRevert(CommonErrorLibrary.InvalidVault.selector);
        new AaveStakingVaultAdapter(admin, address(usdc), address(mockVault), address(yieldShift), 0);
    }

    // =============================================================================
    // DEPOSIT TESTS
    // =============================================================================

    /**
     * @notice depositUnderlying transfers USDC into underlying vault and tracks principal.
     * @custom:security No security implications - unit test
     * @custom:validation Verifies deposit round-trip
     * @custom:state-changes Increases principalDeposited
     * @custom:events Downstream Deposited event
     * @custom:errors No errors expected
     * @custom:reentrancy Not applicable
     * @custom:access VAULT_MANAGER_ROLE
     * @custom:oracle No dependency
     */
    function test_DepositUnderlying_Success() public {
        vm.prank(vaultMgr);
        uint256 shares = adapter.depositUnderlying(DEPOSIT_AMT);

        assertGt(shares, 0, "Should receive shares");
        assertEq(adapter.principalDeposited(), DEPOSIT_AMT);
        assertEq(adapter.totalUnderlying(), DEPOSIT_AMT);
    }

    /**
     * @notice depositUnderlying reverts when caller lacks VAULT_MANAGER_ROLE.
     * @custom:security Validates role guard
     * @custom:validation Reverts on unauthorized caller
     * @custom:state-changes No state changes
     * @custom:events No events
     * @custom:errors AccessControl error
     * @custom:reentrancy Not applicable
     * @custom:access VAULT_MANAGER_ROLE required
     * @custom:oracle No dependency
     */
    function test_DepositUnderlying_UnauthorizedCaller_Reverts() public {
        vm.prank(other);
        vm.expectRevert();
        adapter.depositUnderlying(DEPOSIT_AMT);
    }

    /**
     * @notice depositUnderlying reverts on zero amount.
     * @custom:security No security implications - unit test
     * @custom:validation Reverts with InvalidAmount
     * @custom:state-changes No state changes
     * @custom:events No events
     * @custom:errors InvalidAmount
     * @custom:reentrancy Not applicable
     * @custom:access VAULT_MANAGER_ROLE
     * @custom:oracle No dependency
     */
    function test_DepositUnderlying_ZeroAmount_Reverts() public {
        vm.prank(vaultMgr);
        vm.expectRevert(CommonErrorLibrary.InvalidAmount.selector);
        adapter.depositUnderlying(0);
    }

    // =============================================================================
    // WITHDRAW TESTS
    // =============================================================================

    /**
     * @notice withdrawUnderlying returns deposited USDC to caller.
     * @custom:security No security implications - unit test
     * @custom:validation Verifies withdrawal round-trip
     * @custom:state-changes Decreases principalDeposited
     * @custom:events Downstream Withdrawn event
     * @custom:errors No errors expected
     * @custom:reentrancy Not applicable
     * @custom:access VAULT_MANAGER_ROLE
     * @custom:oracle No dependency
     */
    function test_WithdrawUnderlying_Success() public {
        vm.prank(vaultMgr);
        adapter.depositUnderlying(DEPOSIT_AMT);

        uint256 balBefore = usdc.balanceOf(vaultMgr);

        vm.prank(vaultMgr);
        uint256 withdrawn = adapter.withdrawUnderlying(DEPOSIT_AMT);

        assertEq(withdrawn, DEPOSIT_AMT);
        assertEq(usdc.balanceOf(vaultMgr) - balBefore, DEPOSIT_AMT);
        assertEq(adapter.principalDeposited(), 0);
    }

    /**
     * @notice withdrawUnderlying reverts when no principal is deposited.
     * @custom:security No security implications - unit test
     * @custom:validation Reverts with InsufficientBalance
     * @custom:state-changes No state changes
     * @custom:events No events
     * @custom:errors InsufficientBalance
     * @custom:reentrancy Not applicable
     * @custom:access VAULT_MANAGER_ROLE
     * @custom:oracle No dependency
     */
    function test_WithdrawUnderlying_NoPrincipal_Reverts() public {
        vm.prank(vaultMgr);
        vm.expectRevert(CommonErrorLibrary.InsufficientBalance.selector);
        adapter.withdrawUnderlying(DEPOSIT_AMT);
    }

    // =============================================================================
    // HARVEST YIELD TESTS
    // =============================================================================

    /**
     * @notice harvestYield routes excess beyond principal to YieldShift.
     * @custom:security No security implications - unit test
     * @custom:validation Verifies yield is routed correctly
     * @custom:state-changes Principal unchanged; yield sent to YieldShift
     * @custom:events addYield called on YieldShift
     * @custom:errors No errors expected
     * @custom:reentrancy Not applicable
     * @custom:access VAULT_MANAGER_ROLE
     * @custom:oracle No dependency
     */
    function test_HarvestYield_RoutesToYieldShift() public {
        vm.prank(vaultMgr);
        adapter.depositUnderlying(DEPOSIT_AMT);

        // Inject yield directly into the underlying vault
        vm.prank(yieldSource);
        mockVault.injectYield(YIELD_AMT);

        vm.prank(vaultMgr);
        uint256 harvested = adapter.harvestYield();

        assertEq(harvested, YIELD_AMT, "Should harvest injected yield");
        assertEq(yieldShift.totalYieldAdded(), YIELD_AMT, "YieldShift should receive yield");
        assertEq(yieldShift.lastSource(), bytes32("aave"), "Source should be 'aave'");
        assertEq(yieldShift.lastVaultId(), VAULT_ID);
    }

    /**
     * @notice harvestYield returns zero when no yield is available.
     * @custom:security No security implications - unit test
     * @custom:validation Verifies no-yield return value
     * @custom:state-changes No state changes
     * @custom:events No events
     * @custom:errors No errors
     * @custom:reentrancy Not applicable
     * @custom:access VAULT_MANAGER_ROLE
     * @custom:oracle No dependency
     */
    function test_HarvestYield_NoYield_ReturnsZero() public {
        vm.prank(vaultMgr);
        adapter.depositUnderlying(DEPOSIT_AMT);

        vm.prank(vaultMgr);
        uint256 harvested = adapter.harvestYield();

        assertEq(harvested, 0);
        assertEq(yieldShift.totalYieldAdded(), 0);
    }

    // =============================================================================
    // TOTAL UNDERLYING TESTS
    // =============================================================================

    /**
     * @notice totalUnderlying returns correct balance after deposit and yield.
     * @custom:security No security implications - unit test
     * @custom:validation Verifies totalUnderlying accounting
     * @custom:state-changes No state changes (view test)
     * @custom:events No events
     * @custom:errors No errors
     * @custom:reentrancy Not applicable
     * @custom:access Public view
     * @custom:oracle No dependency
     */
    function test_TotalUnderlying_ReflectsDepositAndYield() public {
        vm.prank(vaultMgr);
        adapter.depositUnderlying(DEPOSIT_AMT);

        assertEq(adapter.totalUnderlying(), DEPOSIT_AMT);

        vm.prank(yieldSource);
        mockVault.injectYield(YIELD_AMT);

        assertEq(adapter.totalUnderlying(), DEPOSIT_AMT + YIELD_AMT);
    }

    // =============================================================================
    // GOVERNANCE TESTS
    // =============================================================================

    /**
     * @notice setAaveVault updates vault pointer.
     * @custom:security Validates governance role
     * @custom:validation Updates vault
     * @custom:state-changes Updates aaveVault
     * @custom:events AaveVaultUpdated
     * @custom:errors No errors expected
     * @custom:reentrancy Not applicable
     * @custom:access GOVERNANCE_ROLE
     * @custom:oracle No dependency
     */
    function test_SetAaveVault_Success() public {
        MockAaveVault newVault = new MockAaveVault(address(usdc));

        vm.prank(admin);
        adapter.setAaveVault(address(newVault));

        assertEq(address(adapter.aaveVault()), address(newVault));
    }

    /**
     * @notice setAaveVault reverts on zero address.
     * @custom:security Validates zero-address guard
     * @custom:validation Reverts with ZeroAddress
     * @custom:state-changes No state changes
     * @custom:events No events
     * @custom:errors ZeroAddress
     * @custom:reentrancy Not applicable
     * @custom:access GOVERNANCE_ROLE
     * @custom:oracle No dependency
     */
    function test_SetAaveVault_ZeroAddress_Reverts() public {
        vm.prank(admin);
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        adapter.setAaveVault(address(0));
    }

    /**
     * @notice setYieldVaultId updates vault id.
     * @custom:security Validates governance role
     * @custom:validation Updates yieldVaultId
     * @custom:state-changes Updates yieldVaultId
     * @custom:events YieldVaultIdUpdated
     * @custom:errors No errors expected
     * @custom:reentrancy Not applicable
     * @custom:access GOVERNANCE_ROLE
     * @custom:oracle No dependency
     */
    function test_SetYieldVaultId_Success() public {
        vm.prank(admin);
        adapter.setYieldVaultId(42);
        assertEq(adapter.yieldVaultId(), 42);
    }

    /**
     * @notice setYieldVaultId reverts on zero id.
     * @custom:security Validates zero-id guard
     * @custom:validation Reverts with InvalidVault
     * @custom:state-changes No state changes
     * @custom:events No events
     * @custom:errors InvalidVault
     * @custom:reentrancy Not applicable
     * @custom:access GOVERNANCE_ROLE
     * @custom:oracle No dependency
     */
    function test_SetYieldVaultId_Zero_Reverts() public {
        vm.prank(admin);
        vm.expectRevert(CommonErrorLibrary.InvalidVault.selector);
        adapter.setYieldVaultId(0);
    }
}
