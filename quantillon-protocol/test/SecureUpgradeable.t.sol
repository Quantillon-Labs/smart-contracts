// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {SecureUpgradeable} from "../src/core/SecureUpgradeable.sol";
import {TimelockUpgradeable} from "../src/core/TimelockUpgradeable.sol";
import {TimeProvider} from "../src/libraries/TimeProviderLibrary.sol";
import {ITimelockUpgradeable} from "../src/interfaces/ITimelockUpgradeable.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title MockSecureUpgradeable
 * @notice Concrete implementation of SecureUpgradeable for testing
 * @dev Since SecureUpgradeable is abstract, we need a concrete implementation
 */
contract MockSecureUpgradeable is SecureUpgradeable {
    uint256 public version;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address _timelock) external initializer {
        __SecureUpgradeable_init(_timelock);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        version = 1;
    }

    function getVersion() external view returns (uint256) {
        return version;
    }
}

/**
 * @title MockSecureUpgradeableV2
 * @notice Version 2 of the mock contract for upgrade testing
 */
contract MockSecureUpgradeableV2 is SecureUpgradeable {
    uint256 public version;
    uint256 public newFeature;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address _timelock) external initializer {
        __SecureUpgradeable_init(_timelock);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        version = 2;
    }

    function reinitialize() external reinitializer(2) {
        version = 2;
        newFeature = 100;
    }

    function getVersion() external view returns (uint256) {
        return version;
    }
}

/**
 * @title SecureUpgradeableTest
 * @notice Comprehensive test suite for the SecureUpgradeable contract
 *
 * @dev This test suite covers:
 *      - Initialization and setup
 *      - Timelock configuration
 *      - Secure upgrade toggle functionality
 *      - Upgrade proposal flow
 *      - Upgrade execution through timelock
 *      - Emergency upgrade scenarios
 *      - Access control validations
 *      - Edge cases and security scenarios
 *
 * @author Quantillon Labs
 * @custom:security-contact team@quantillon.money
 */
contract SecureUpgradeableTest is Test {
    // =============================================================================
    // TEST CONTRACTS AND ADDRESSES
    // =============================================================================

    MockSecureUpgradeable public implementation;
    MockSecureUpgradeable public secureContract;
    MockSecureUpgradeableV2 public implementationV2;

    TimelockUpgradeable public timelockImpl;
    TimelockUpgradeable public timelock;

    TimeProvider public timeProviderImpl;
    TimeProvider public timeProvider;

    // Test addresses
    address public admin = address(0x1);
    address public upgrader = address(0x2);
    address public attacker = address(0x3);
    address public signer1 = address(0x4);
    address public signer2 = address(0x5);
    address public signer3 = address(0x6);

    // =============================================================================
    // EVENTS FOR TESTING
    // =============================================================================

    event TimelockSet(address indexed timelock);
    event SecureUpgradesToggled(bool enabled);
    event SecureUpgradeAuthorized(address indexed newImplementation, address indexed authorizedBy, string description);

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

        // Deploy MockSecureUpgradeable
        implementation = new MockSecureUpgradeable();
        bytes memory initData = abi.encodeWithSelector(
            MockSecureUpgradeable.initialize.selector,
            admin,
            address(timelock)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        secureContract = MockSecureUpgradeable(address(proxy));

        // Deploy V2 implementation for upgrade tests
        implementationV2 = new MockSecureUpgradeableV2();

        // Setup roles
        vm.startPrank(admin);
        secureContract.grantRole(secureContract.UPGRADER_ROLE(), upgrader);

        // Add multi-sig signers to timelock
        timelock.addMultisigSigner(signer1);
        timelock.addMultisigSigner(signer2);

        // Grant timelock roles
        timelock.grantRole(timelock.UPGRADE_PROPOSER_ROLE(), address(secureContract));
        timelock.grantRole(timelock.UPGRADE_EXECUTOR_ROLE(), admin);
        vm.stopPrank();
    }

    // =============================================================================
    // INITIALIZATION TESTS
    // =============================================================================

    function test_Initialization_Success() public view {
        assertEq(secureContract.getVersion(), 1, "Version should be 1");
        assertTrue(secureContract.secureUpgradesEnabled(), "Secure upgrades should be enabled");
        assertEq(address(secureContract.timelock()), address(timelock), "Timelock should be set");
        assertTrue(secureContract.hasRole(secureContract.DEFAULT_ADMIN_ROLE(), admin), "Admin should have admin role");
        assertTrue(secureContract.hasRole(secureContract.UPGRADER_ROLE(), admin), "Admin should have upgrader role");
        assertTrue(secureContract.hasRole(secureContract.UPGRADER_ROLE(), upgrader), "Upgrader should have upgrader role");
    }

    function test_Initialization_EmitsEvents() public {
        MockSecureUpgradeable newImpl = new MockSecureUpgradeable();

        vm.expectEmit(true, false, false, false);
        emit TimelockSet(address(timelock));

        vm.expectEmit(false, false, false, true);
        emit SecureUpgradesToggled(true);

        bytes memory initData = abi.encodeWithSelector(
            MockSecureUpgradeable.initialize.selector,
            admin,
            address(timelock)
        );
        new ERC1967Proxy(address(newImpl), initData);
    }

    // =============================================================================
    // SET TIMELOCK TESTS
    // =============================================================================

    function test_SetTimelock_Success() public {
        address newTimelock = address(0x999);

        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit TimelockSet(newTimelock);
        secureContract.setTimelock(newTimelock);

        assertEq(address(secureContract.timelock()), newTimelock, "Timelock should be updated");
    }

    function test_SetTimelock_RevertZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        secureContract.setTimelock(address(0));
    }

    function test_SetTimelock_RevertNotAdmin() public {
        vm.prank(attacker);
        vm.expectRevert();
        secureContract.setTimelock(address(0x999));
    }

    // =============================================================================
    // TOGGLE SECURE UPGRADES TESTS
    // =============================================================================

    function test_ToggleSecureUpgrades_Disable() public {
        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit SecureUpgradesToggled(false);
        secureContract.toggleSecureUpgrades(false);

        assertFalse(secureContract.secureUpgradesEnabled(), "Secure upgrades should be disabled");
    }

    function test_ToggleSecureUpgrades_Enable() public {
        // First disable
        vm.prank(admin);
        secureContract.toggleSecureUpgrades(false);

        // Then enable
        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit SecureUpgradesToggled(true);
        secureContract.toggleSecureUpgrades(true);

        assertTrue(secureContract.secureUpgradesEnabled(), "Secure upgrades should be enabled");
    }

    function test_ToggleSecureUpgrades_RevertNotAdmin() public {
        vm.prank(attacker);
        vm.expectRevert();
        secureContract.toggleSecureUpgrades(false);
    }

    // =============================================================================
    // PROPOSE UPGRADE TESTS
    // =============================================================================

    function test_ProposeUpgrade_Success() public {
        vm.prank(upgrader);
        secureContract.proposeUpgrade(
            address(implementationV2),
            "Upgrade to V2",
            0 // Use default delay
        );

        assertTrue(secureContract.isUpgradePending(address(implementationV2)), "Upgrade should be pending");
    }

    function test_ProposeUpgrade_RevertWhenDisabled() public {
        vm.prank(admin);
        secureContract.toggleSecureUpgrades(false);

        vm.prank(upgrader);
        vm.expectRevert(CommonErrorLibrary.NotActive.selector);
        secureContract.proposeUpgrade(
            address(implementationV2),
            "Upgrade to V2",
            0
        );
    }

    function test_ProposeUpgrade_RevertNoTimelock() public {
        // Deploy a new contract without timelock
        MockSecureUpgradeable newImpl = new MockSecureUpgradeable();
        bytes memory initData = abi.encodeWithSelector(
            MockSecureUpgradeable.initialize.selector,
            admin,
            address(0) // No timelock
        );

        // This will fail during initialization because timelock is not set
        // but secureUpgradesEnabled will be true, so we need to deploy properly first
        ERC1967Proxy proxy = new ERC1967Proxy(address(newImpl), initData);
        MockSecureUpgradeable noTimelockContract = MockSecureUpgradeable(address(proxy));

        vm.prank(admin);
        noTimelockContract.grantRole(noTimelockContract.UPGRADER_ROLE(), upgrader);

        vm.prank(upgrader);
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        noTimelockContract.proposeUpgrade(
            address(implementationV2),
            "Upgrade to V2",
            0
        );
    }

    function test_ProposeUpgrade_RevertNotUpgrader() public {
        vm.prank(attacker);
        vm.expectRevert();
        secureContract.proposeUpgrade(
            address(implementationV2),
            "Upgrade to V2",
            0
        );
    }

    function test_ProposeUpgrade_WithCustomDelay() public {
        uint256 customDelay = 3 days;

        vm.prank(upgrader);
        secureContract.proposeUpgrade(
            address(implementationV2),
            "Upgrade to V2 with custom delay",
            customDelay
        );

        ITimelockUpgradeable.PendingUpgrade memory upgrade = secureContract.getPendingUpgrade(address(implementationV2));
        assertEq(upgrade.executableAt, upgrade.proposedAt + customDelay, "Custom delay should be applied");
    }

    // =============================================================================
    // EXECUTE UPGRADE TESTS
    // =============================================================================

    function test_ExecuteUpgrade_Success() public {
        // First propose the upgrade through the proper channel
        vm.prank(admin);
        timelock.grantRole(timelock.UPGRADE_PROPOSER_ROLE(), admin);

        vm.prank(admin);
        timelock.proposeUpgrade(address(implementationV2), "Upgrade to V2", 0);

        // Approve with multi-sig
        vm.prank(admin); // admin is already a signer from initialization
        timelock.approveUpgrade(address(implementationV2));

        vm.prank(signer1);
        timelock.approveUpgrade(address(implementationV2));

        // Wait for timelock
        vm.warp(block.timestamp + 48 hours + 1);

        // Execute upgrade - this should work through timelock
        vm.prank(admin);
        timelock.executeUpgrade(address(implementationV2));
    }

    function test_ExecuteUpgrade_RevertNotTimelock() public {
        vm.prank(attacker);
        vm.expectRevert(CommonErrorLibrary.NotAuthorized.selector);
        secureContract.executeUpgrade(address(implementationV2));
    }

    function test_ExecuteUpgrade_RevertZeroAddress() public {
        // Simulate call from timelock
        vm.prank(address(timelock));
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        secureContract.executeUpgrade(address(0));
    }

    // =============================================================================
    // EMERGENCY UPGRADE TESTS
    // =============================================================================

    function test_EmergencyUpgrade_SuccessWhenSecureUpgradesDisabled() public {
        // Disable secure upgrades
        vm.prank(admin);
        secureContract.toggleSecureUpgrades(false);

        // Perform emergency upgrade
        vm.prank(upgrader);
        vm.expectEmit(true, true, false, true);
        emit SecureUpgradeAuthorized(address(implementationV2), upgrader, "Emergency upgrade");
        secureContract.emergencyUpgrade(address(implementationV2), "Emergency upgrade");
    }

    function test_EmergencyUpgrade_SuccessWhenNoTimelock() public {
        // Deploy a contract with no timelock set
        MockSecureUpgradeable newImpl = new MockSecureUpgradeable();
        bytes memory initData = abi.encodeWithSelector(
            MockSecureUpgradeable.initialize.selector,
            admin,
            address(0)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(newImpl), initData);
        MockSecureUpgradeable noTimelockContract = MockSecureUpgradeable(address(proxy));

        vm.prank(admin);
        noTimelockContract.grantRole(noTimelockContract.UPGRADER_ROLE(), upgrader);

        // Perform emergency upgrade - should succeed since no timelock
        vm.prank(upgrader);
        noTimelockContract.emergencyUpgrade(address(implementationV2), "Emergency upgrade");
    }

    function test_EmergencyUpgrade_RevertWhenSecureUpgradesEnabled() public {
        // Secure upgrades are enabled by default with timelock set
        vm.prank(upgrader);
        vm.expectRevert(CommonErrorLibrary.NotAuthorized.selector);
        secureContract.emergencyUpgrade(address(implementationV2), "Emergency upgrade");
    }

    function test_EmergencyUpgrade_RevertNotUpgrader() public {
        vm.prank(admin);
        secureContract.toggleSecureUpgrades(false);

        vm.prank(attacker);
        vm.expectRevert();
        secureContract.emergencyUpgrade(address(implementationV2), "Emergency upgrade");
    }

    // =============================================================================
    // EMERGENCY DISABLE/ENABLE TESTS
    // =============================================================================

    function test_EmergencyDisableSecureUpgrades_Success() public {
        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit SecureUpgradesToggled(false);
        secureContract.emergencyDisableSecureUpgrades();

        assertFalse(secureContract.secureUpgradesEnabled(), "Secure upgrades should be disabled");
    }

    function test_EmergencyDisableSecureUpgrades_RevertNotAdmin() public {
        vm.prank(attacker);
        vm.expectRevert();
        secureContract.emergencyDisableSecureUpgrades();
    }

    function test_EnableSecureUpgrades_Success() public {
        // First disable
        vm.prank(admin);
        secureContract.emergencyDisableSecureUpgrades();

        // Then enable
        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit SecureUpgradesToggled(true);
        secureContract.enableSecureUpgrades();

        assertTrue(secureContract.secureUpgradesEnabled(), "Secure upgrades should be enabled");
    }

    function test_EnableSecureUpgrades_RevertNoTimelock() public {
        MockSecureUpgradeable newImpl = new MockSecureUpgradeable();
        bytes memory initData = abi.encodeWithSelector(
            MockSecureUpgradeable.initialize.selector,
            admin,
            address(0)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(newImpl), initData);
        MockSecureUpgradeable noTimelockContract = MockSecureUpgradeable(address(proxy));

        vm.prank(admin);
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        noTimelockContract.enableSecureUpgrades();
    }

    function test_EnableSecureUpgrades_RevertNotAdmin() public {
        vm.prank(admin);
        secureContract.emergencyDisableSecureUpgrades();

        vm.prank(attacker);
        vm.expectRevert();
        secureContract.enableSecureUpgrades();
    }

    // =============================================================================
    // VIEW FUNCTIONS TESTS
    // =============================================================================

    function test_IsUpgradePending_True() public {
        vm.prank(upgrader);
        secureContract.proposeUpgrade(address(implementationV2), "Upgrade to V2", 0);

        assertTrue(secureContract.isUpgradePending(address(implementationV2)), "Upgrade should be pending");
    }

    function test_IsUpgradePending_FalseNoTimelock() public {
        MockSecureUpgradeable newImpl = new MockSecureUpgradeable();
        bytes memory initData = abi.encodeWithSelector(
            MockSecureUpgradeable.initialize.selector,
            admin,
            address(0)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(newImpl), initData);
        MockSecureUpgradeable noTimelockContract = MockSecureUpgradeable(address(proxy));

        assertFalse(noTimelockContract.isUpgradePending(address(implementationV2)), "Should return false when no timelock");
    }

    function test_IsUpgradePending_FalseNoPending() public view {
        assertFalse(secureContract.isUpgradePending(address(implementationV2)), "Should return false when no pending upgrade");
    }

    function test_GetPendingUpgrade_WithTimelock() public {
        vm.prank(upgrader);
        secureContract.proposeUpgrade(address(implementationV2), "Upgrade to V2", 0);

        ITimelockUpgradeable.PendingUpgrade memory upgrade = secureContract.getPendingUpgrade(address(implementationV2));
        assertEq(upgrade.implementation, address(implementationV2), "Implementation should match");
        assertEq(upgrade.description, "Upgrade to V2", "Description should match");
        assertEq(upgrade.proposer, address(secureContract), "Proposer should be the contract");
    }

    function test_GetPendingUpgrade_NoTimelock() public {
        MockSecureUpgradeable newImpl = new MockSecureUpgradeable();
        bytes memory initData = abi.encodeWithSelector(
            MockSecureUpgradeable.initialize.selector,
            admin,
            address(0)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(newImpl), initData);
        MockSecureUpgradeable noTimelockContract = MockSecureUpgradeable(address(proxy));

        ITimelockUpgradeable.PendingUpgrade memory upgrade = noTimelockContract.getPendingUpgrade(address(implementationV2));
        assertEq(upgrade.implementation, address(0), "Implementation should be zero");
    }

    function test_CanExecuteUpgrade_True() public {
        // Setup: propose and approve upgrade
        vm.prank(upgrader);
        secureContract.proposeUpgrade(address(implementationV2), "Upgrade to V2", 0);

        // Approve with multi-sig
        vm.prank(admin);
        timelock.approveUpgrade(address(implementationV2));

        vm.prank(signer1);
        timelock.approveUpgrade(address(implementationV2));

        // Wait for timelock
        vm.warp(block.timestamp + 48 hours + 1);

        assertTrue(secureContract.canExecuteUpgrade(address(implementationV2)), "Should be executable");
    }

    function test_CanExecuteUpgrade_FalseNoTimelock() public {
        MockSecureUpgradeable newImpl = new MockSecureUpgradeable();
        bytes memory initData = abi.encodeWithSelector(
            MockSecureUpgradeable.initialize.selector,
            admin,
            address(0)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(newImpl), initData);
        MockSecureUpgradeable noTimelockContract = MockSecureUpgradeable(address(proxy));

        assertFalse(noTimelockContract.canExecuteUpgrade(address(implementationV2)), "Should return false when no timelock");
    }

    function test_GetUpgradeSecurityStatus() public view {
        (address timelockAddress, bool enabled, bool hasTimelock) = secureContract.getUpgradeSecurityStatus();

        assertEq(timelockAddress, address(timelock), "Timelock address should match");
        assertTrue(enabled, "Secure upgrades should be enabled");
        assertTrue(hasTimelock, "Should have timelock");
    }

    function test_GetUpgradeSecurityStatus_NoTimelock() public {
        MockSecureUpgradeable newImpl = new MockSecureUpgradeable();
        bytes memory initData = abi.encodeWithSelector(
            MockSecureUpgradeable.initialize.selector,
            admin,
            address(0)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(newImpl), initData);
        MockSecureUpgradeable noTimelockContract = MockSecureUpgradeable(address(proxy));

        (address timelockAddress, bool enabled, bool hasTimelock) = noTimelockContract.getUpgradeSecurityStatus();

        assertEq(timelockAddress, address(0), "Timelock address should be zero");
        assertTrue(enabled, "Secure upgrades should be enabled by default");
        assertFalse(hasTimelock, "Should not have timelock");
    }

    // =============================================================================
    // SECURITY TESTS
    // =============================================================================

    function test_Security_CannotBypassTimelockWithDirectUpgrade() public {
        // Try to call upgradeToAndCall directly - should be blocked by _authorizeUpgrade
        // This test verifies that the contract correctly blocks unauthorized upgrade attempts

        vm.prank(attacker);
        vm.expectRevert(CommonErrorLibrary.NotAuthorized.selector);
        secureContract.upgradeToAndCall(address(implementationV2), "");
    }

    function test_Security_UpgraderCannotDirectlyUpgradeWithSecureEnabled() public {
        // Even the upgrader cannot directly upgrade when secure upgrades are enabled
        vm.prank(upgrader);
        vm.expectRevert(CommonErrorLibrary.NotAuthorized.selector);
        secureContract.upgradeToAndCall(address(implementationV2), "");
    }

    function test_Security_AdminCannotDirectlyUpgradeWithSecureEnabled() public {
        // Even the admin cannot directly upgrade when secure upgrades are enabled
        vm.prank(admin);
        vm.expectRevert(CommonErrorLibrary.NotAuthorized.selector);
        secureContract.upgradeToAndCall(address(implementationV2), "");
    }

    function test_Security_UpgraderCanDirectlyUpgradeWhenSecureDisabled() public {
        // Disable secure upgrades
        vm.prank(admin);
        secureContract.toggleSecureUpgrades(false);

        // Now upgrader can upgrade directly
        vm.prank(upgrader);
        secureContract.upgradeToAndCall(address(implementationV2), "");
    }

    function test_Security_NonUpgraderCannotUpgradeEvenWhenSecureDisabled() public {
        // Disable secure upgrades
        vm.prank(admin);
        secureContract.toggleSecureUpgrades(false);

        // Attacker still cannot upgrade
        vm.prank(attacker);
        vm.expectRevert(CommonErrorLibrary.NotAuthorized.selector);
        secureContract.upgradeToAndCall(address(implementationV2), "");
    }

    function test_Security_CannotUpgradeToZeroAddress() public {
        vm.prank(admin);
        secureContract.toggleSecureUpgrades(false);

        vm.prank(upgrader);
        vm.expectRevert(CommonErrorLibrary.ZeroAddress.selector);
        secureContract.upgradeToAndCall(address(0), "");
    }

    // =============================================================================
    // FULL UPGRADE FLOW TEST
    // =============================================================================

    function test_FullUpgradeFlow_ThroughTimelock() public {
        // Step 1: Propose upgrade
        vm.prank(upgrader);
        secureContract.proposeUpgrade(address(implementationV2), "Upgrade to V2", 0);

        // Verify pending
        assertTrue(secureContract.isUpgradePending(address(implementationV2)), "Upgrade should be pending");

        // Step 2: Multi-sig approval
        vm.prank(admin);
        timelock.approveUpgrade(address(implementationV2));

        vm.prank(signer1);
        timelock.approveUpgrade(address(implementationV2));

        // Step 3: Wait for timelock
        vm.warp(block.timestamp + 48 hours + 1);

        // Verify can execute
        assertTrue(secureContract.canExecuteUpgrade(address(implementationV2)), "Should be executable");

        // Step 4: Execute upgrade
        vm.prank(admin);
        timelock.executeUpgrade(address(implementationV2));
    }

    function test_FullUpgradeFlow_EmergencyPath() public {
        // Verify initial version
        assertEq(secureContract.getVersion(), 1, "Should start at version 1");

        // Step 1: Disable secure upgrades (emergency)
        vm.prank(admin);
        secureContract.emergencyDisableSecureUpgrades();

        // Step 2: Perform emergency upgrade
        vm.prank(upgrader);
        secureContract.emergencyUpgrade(address(implementationV2), "Emergency security patch");

        // Note: After upgrade, the proxy points to V2 but state is preserved
        // The version getter would need to be re-initialized to show V2
    }
}
