// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {QEUROToken} from "../src/core/QEUROToken.sol";
import {QTIToken} from "../src/core/QTIToken.sol";
import {TimelockUpgradeable} from "../src/core/TimelockUpgradeable.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";

/**
 * @title MockQEUROTokenV2
 * @notice Mock V2 implementation of QEUROToken for upgrade testing
 */
contract MockQEUROTokenV2 is QEUROToken {
    uint256 public newVariable;

    function setNewVariable(uint256 value) external {
        newVariable = value;
    }

    function getNewVariable() external view returns (uint256) {
        return newVariable;
    }

    function version() external pure returns (uint256) {
        return 2;
    }
}

/**
 * @title MockQTITokenV2
 * @notice Mock V2 implementation of QTIToken for upgrade testing
 */
contract MockQTITokenV2 is QTIToken {
    uint256 public newFeature;

    constructor(TimeProvider _timeProvider) QTIToken(_timeProvider) {}

    function setNewFeature(uint256 value) external {
        newFeature = value;
    }

    function version() external pure returns (uint256) {
        return 2;
    }
}

/**
 * @title UpgradeTests
 * @notice Comprehensive testing for UUPS upgrade patterns and storage compatibility
 *
 * @dev This test suite covers:
 *      - UUPS proxy upgrade mechanics
 *      - Storage layout preservation
 *      - State migration scenarios
 *      - Upgrade authorization
 *      - Rollback scenarios
 *      - Version tracking
 *
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract UpgradeTests is Test {
    // =============================================================================
    // STATE VARIABLES
    // =============================================================================

    QEUROToken public qeuroImpl;
    QEUROToken public qeuroToken;
    MockQEUROTokenV2 public qeuroV2Impl;

    QTIToken public qtiImpl;
    QTIToken public qtiToken;
    MockQTITokenV2 public qtiV2Impl;

    TimelockUpgradeable public timelockImpl;
    TimelockUpgradeable public timelock;

    TimeProvider public timeProviderImpl;
    TimeProvider public timeProvider;

    // Test addresses
    address public admin = address(0x1);
    address public treasury = address(0x2);
    address public user1 = address(0x3);
    address public signer1 = address(0x4);
    address public attacker = address(0x5);
    address public mockTimelock = address(0x6);
    address public feeCollector = address(0x7);

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

        // Deploy QEUROToken
        qeuroImpl = new QEUROToken();
        bytes memory qeuroInitData = abi.encodeWithSelector(
            QEUROToken.initialize.selector,
            admin,
            treasury,
            address(timelock),
            treasury,
            feeCollector
        );
        ERC1967Proxy qeuroProxy = new ERC1967Proxy(address(qeuroImpl), qeuroInitData);
        qeuroToken = QEUROToken(address(qeuroProxy));

        // Deploy QTIToken
        qtiImpl = new QTIToken(timeProvider);
        bytes memory qtiInitData = abi.encodeWithSelector(
            QTIToken.initialize.selector,
            admin,
            treasury,
            address(timelock)
        );
        ERC1967Proxy qtiProxy = new ERC1967Proxy(address(qtiImpl), qtiInitData);
        qtiToken = QTIToken(address(qtiProxy));

        // Deploy V2 implementations
        qeuroV2Impl = new MockQEUROTokenV2();
        qtiV2Impl = new MockQTITokenV2(timeProvider);

        // Setup roles and signers
        vm.startPrank(admin);
        timelock.addMultisigSigner(signer1);
        timelock.grantRole(timelock.UPGRADE_PROPOSER_ROLE(), admin);
        timelock.grantRole(timelock.UPGRADE_EXECUTOR_ROLE(), admin);
        vm.stopPrank();
    }

    // =============================================================================
    // QEURO TOKEN UPGRADE TESTS
    // =============================================================================

    /**
     * @notice Test that QEURO proxy is properly initialized
     */
    function test_QEURO_ProxyInitialization() public view {
        assertEq(qeuroToken.name(), "Quantillon Euro", "Name should be set");
        assertEq(qeuroToken.symbol(), "QEURO", "Symbol should be set");
        assertEq(qeuroToken.decimals(), 18, "Decimals should be 18");
        assertTrue(qeuroToken.hasRole(qeuroToken.DEFAULT_ADMIN_ROLE(), admin), "Admin should have admin role");
    }

    /**
     * @notice Test QEURO state preservation after upgrade
     */
    function test_QEURO_StatePreservation_AfterUpgrade() public {
        // Create some state
        vm.startPrank(admin);
        qeuroToken.grantRole(qeuroToken.MINTER_ROLE(), admin);
        vm.stopPrank();

        vm.prank(admin);
        qeuroToken.mint(user1, 1000 ether);

        uint256 balanceBefore = qeuroToken.balanceOf(user1);
        uint256 totalSupplyBefore = qeuroToken.totalSupply();

        // Disable secure upgrades for testing
        vm.prank(admin);
        qeuroToken.emergencyDisableSecureUpgrades();

        // Grant upgrader role
        vm.prank(admin);
        qeuroToken.grantRole(qeuroToken.UPGRADER_ROLE(), admin);

        // Perform upgrade
        vm.prank(admin);
        qeuroToken.upgradeToAndCall(address(qeuroV2Impl), "");

        // Verify state is preserved
        assertEq(qeuroToken.balanceOf(user1), balanceBefore, "Balance should be preserved");
        assertEq(qeuroToken.totalSupply(), totalSupplyBefore, "Total supply should be preserved");
        assertEq(qeuroToken.name(), "Quantillon Euro", "Name should be preserved");
        assertEq(qeuroToken.symbol(), "QEURO", "Symbol should be preserved");
    }

    /**
     * @notice Test QEURO V2 new functionality after upgrade
     */
    function test_QEURO_V2_NewFunctionality() public {
        // Disable secure upgrades and perform upgrade
        vm.startPrank(admin);
        qeuroToken.emergencyDisableSecureUpgrades();
        qeuroToken.grantRole(qeuroToken.UPGRADER_ROLE(), admin);
        qeuroToken.upgradeToAndCall(address(qeuroV2Impl), "");
        vm.stopPrank();

        // Cast to V2 and test new functionality
        MockQEUROTokenV2 qeuroV2 = MockQEUROTokenV2(address(qeuroToken));

        qeuroV2.setNewVariable(12345);
        assertEq(qeuroV2.getNewVariable(), 12345, "New variable should be set");
        assertEq(qeuroV2.version(), 2, "Version should be 2");
    }

    /**
     * @notice Test unauthorized upgrade attempt fails
     */
    function test_QEURO_UnauthorizedUpgrade_Reverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        qeuroToken.upgradeToAndCall(address(qeuroV2Impl), "");
    }

    // =============================================================================
    // QTI TOKEN UPGRADE TESTS
    // =============================================================================

    /**
     * @notice Test QTI proxy initialization
     */
    function test_QTI_ProxyInitialization() public view {
        assertEq(qtiToken.name(), "Quantillon Governance Token", "Name should be set");
        assertEq(qtiToken.symbol(), "QTI", "Symbol should be set");
        assertTrue(qtiToken.hasRole(qtiToken.DEFAULT_ADMIN_ROLE(), admin), "Admin should have admin role");
    }

    /**
     * @notice Test QTI state preservation after upgrade
     */
    function test_QTI_StatePreservation_AfterUpgrade() public {
        // Check initial state
        uint256 supplyCap = qtiToken.TOTAL_SUPPLY_CAP();

        // Disable secure upgrades for testing
        vm.prank(admin);
        qtiToken.emergencyDisableSecureUpgrades();

        // Grant upgrader role
        vm.prank(admin);
        qtiToken.grantRole(qtiToken.UPGRADER_ROLE(), admin);

        // Perform upgrade
        vm.prank(admin);
        qtiToken.upgradeToAndCall(address(qtiV2Impl), "");

        // Verify state is preserved
        assertEq(qtiToken.TOTAL_SUPPLY_CAP(), supplyCap, "Supply cap should be preserved");
        assertEq(qtiToken.name(), "Quantillon Governance Token", "Name should be preserved");
    }

    /**
     * @notice Test QTI V2 new functionality after upgrade
     */
    function test_QTI_V2_NewFunctionality() public {
        // Disable secure upgrades and perform upgrade
        vm.startPrank(admin);
        qtiToken.emergencyDisableSecureUpgrades();
        qtiToken.grantRole(qtiToken.UPGRADER_ROLE(), admin);
        qtiToken.upgradeToAndCall(address(qtiV2Impl), "");
        vm.stopPrank();

        // Cast to V2 and test new functionality
        MockQTITokenV2 qtiV2 = MockQTITokenV2(address(qtiToken));

        qtiV2.setNewFeature(99999);
        assertEq(qtiV2.newFeature(), 99999, "New feature should be set");
        assertEq(qtiV2.version(), 2, "Version should be 2");
    }

    // =============================================================================
    // TIMELOCK UPGRADE FLOW TESTS
    // =============================================================================

    /**
     * @notice Test full upgrade flow through timelock
     */
    function test_FullUpgradeFlow_ThroughTimelock() public {
        // Create some state first
        vm.startPrank(admin);
        qeuroToken.grantRole(qeuroToken.MINTER_ROLE(), admin);
        vm.stopPrank();

        vm.prank(admin);
        qeuroToken.mint(user1, 1000 ether);

        uint256 balanceBefore = qeuroToken.balanceOf(user1);

        // Propose upgrade through timelock
        vm.prank(admin);
        timelock.proposeUpgrade(address(qeuroV2Impl), "Upgrade QEURO to V2", 0);

        // Approve with signers
        vm.prank(admin);
        timelock.approveUpgrade(address(qeuroV2Impl));

        vm.prank(signer1);
        timelock.approveUpgrade(address(qeuroV2Impl));

        // Wait for timelock
        vm.warp(block.timestamp + 48 hours + 1);

        // Execute upgrade
        vm.prank(admin);
        timelock.executeUpgrade(address(qeuroV2Impl));

        // Verify state preserved after timelock upgrade
        assertEq(qeuroToken.balanceOf(user1), balanceBefore, "Balance should be preserved after timelock upgrade");
    }

    /**
     * @notice Test upgrade cancelled clears pending state
     */
    function test_UpgradeCancellation_ClearsPendingState() public {
        // Propose upgrade
        vm.prank(admin);
        timelock.proposeUpgrade(address(qeuroV2Impl), "Upgrade to cancel", 0);

        // Verify pending
        assertTrue(
            timelock.getPendingUpgrade(address(qeuroV2Impl)).implementation != address(0),
            "Upgrade should be pending"
        );

        // Cancel
        vm.prank(admin);
        timelock.cancelUpgrade(address(qeuroV2Impl));

        // Verify cleared
        assertEq(
            timelock.getPendingUpgrade(address(qeuroV2Impl)).implementation,
            address(0),
            "Pending upgrade should be cleared"
        );
    }

    // =============================================================================
    // STORAGE LAYOUT TESTS
    // =============================================================================

    /**
     * @notice Test that storage slots are correctly maintained
     */
    function test_StorageSlots_Maintained() public {
        // Store some data
        vm.startPrank(admin);
        qeuroToken.grantRole(qeuroToken.MINTER_ROLE(), admin);
        vm.stopPrank();

        vm.prank(admin);
        qeuroToken.mint(user1, 500 ether);
        vm.prank(admin);
        qeuroToken.mint(treasury, 500 ether);

        // Record storage values
        uint256 user1Balance = qeuroToken.balanceOf(user1);
        uint256 treasuryBalance = qeuroToken.balanceOf(treasury);
        uint256 totalSupply = qeuroToken.totalSupply();
        bool hasAdminRole = qeuroToken.hasRole(qeuroToken.DEFAULT_ADMIN_ROLE(), admin);

        // Perform upgrade
        vm.startPrank(admin);
        qeuroToken.emergencyDisableSecureUpgrades();
        qeuroToken.grantRole(qeuroToken.UPGRADER_ROLE(), admin);
        qeuroToken.upgradeToAndCall(address(qeuroV2Impl), "");
        vm.stopPrank();

        // Verify all storage is preserved
        assertEq(qeuroToken.balanceOf(user1), user1Balance, "User1 balance preserved");
        assertEq(qeuroToken.balanceOf(treasury), treasuryBalance, "Treasury balance preserved");
        assertEq(qeuroToken.totalSupply(), totalSupply, "Total supply preserved");
        assertEq(
            qeuroToken.hasRole(qeuroToken.DEFAULT_ADMIN_ROLE(), admin),
            hasAdminRole,
            "Admin role preserved"
        );
    }

    // =============================================================================
    // SECURITY TESTS
    // =============================================================================

    /**
     * @notice Test that only authorized addresses can upgrade
     */
    function test_Security_OnlyAuthorizedCanUpgrade() public {
        // Attacker without role cannot upgrade
        vm.prank(attacker);
        vm.expectRevert();
        qeuroToken.upgradeToAndCall(address(qeuroV2Impl), "");

        // Regular user cannot upgrade
        vm.prank(user1);
        vm.expectRevert();
        qeuroToken.upgradeToAndCall(address(qeuroV2Impl), "");
    }

    /**
     * @notice Test that upgrade to zero address fails
     */
    function test_Security_UpgradeToZeroAddress_Fails() public {
        vm.startPrank(admin);
        qeuroToken.emergencyDisableSecureUpgrades();
        qeuroToken.grantRole(qeuroToken.UPGRADER_ROLE(), admin);

        vm.expectRevert();
        qeuroToken.upgradeToAndCall(address(0), "");
        vm.stopPrank();
    }

    /**
     * @notice Test double initialization is prevented
     */
    function test_Security_DoubleInitialization_Prevented() public {
        vm.expectRevert();
        qeuroToken.initialize(attacker, attacker, address(0), attacker, attacker);
    }

    /**
     * @notice Test emergency upgrade requires secure upgrades disabled
     */
    function test_Security_EmergencyUpgrade_RequiresDisabled() public {
        // With secure upgrades enabled, emergency upgrade should fail
        vm.prank(admin);
        qeuroToken.grantRole(qeuroToken.UPGRADER_ROLE(), admin);

        vm.prank(admin);
        vm.expectRevert(CommonErrorLibrary.NotAuthorized.selector);
        qeuroToken.emergencyUpgrade(address(qeuroV2Impl), "Emergency");
    }

    // =============================================================================
    // PROXY PATTERN TESTS
    // =============================================================================

    /**
     * @notice Test implementation address changes after upgrade
     */
    function test_ImplementationAddress_Changes() public {
        // Get current implementation (using low-level storage read)
        bytes32 implSlot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        bytes32 implBefore = vm.load(address(qeuroToken), implSlot);

        // Perform upgrade
        vm.startPrank(admin);
        qeuroToken.emergencyDisableSecureUpgrades();
        qeuroToken.grantRole(qeuroToken.UPGRADER_ROLE(), admin);
        qeuroToken.upgradeToAndCall(address(qeuroV2Impl), "");
        vm.stopPrank();

        // Get new implementation
        bytes32 implAfter = vm.load(address(qeuroToken), implSlot);

        // Verify implementation changed
        assertTrue(implBefore != implAfter, "Implementation address should change");
        assertEq(address(uint160(uint256(implAfter))), address(qeuroV2Impl), "New impl should be V2");
    }

    /**
     * @notice Test proxy delegatecall pattern works correctly
     */
    function test_ProxyDelegatecall_Works() public {
        // Perform upgrade
        vm.startPrank(admin);
        qeuroToken.emergencyDisableSecureUpgrades();
        qeuroToken.grantRole(qeuroToken.UPGRADER_ROLE(), admin);
        qeuroToken.upgradeToAndCall(address(qeuroV2Impl), "");
        vm.stopPrank();

        // Call V2 function through proxy
        MockQEUROTokenV2 qeuroV2 = MockQEUROTokenV2(address(qeuroToken));

        // This call goes through proxy via delegatecall
        qeuroV2.setNewVariable(42);
        assertEq(qeuroV2.getNewVariable(), 42, "Delegatecall should work correctly");

        // Verify state is in proxy, not implementation
        assertEq(qeuroV2Impl.newVariable(), 0, "Implementation should not have state");
    }
}
