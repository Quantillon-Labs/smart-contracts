// /test/AccessControlLibrary.t.sol
// Unit tests for AccessControlLibrary role and address validation helpers.
// This file exists to validate access-control semantics in isolation.

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {AccessControlLibrary} from "../src/libraries/AccessControlLibrary.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";

contract AccessControlHarness is AccessControlUpgradeable {
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    bytes32 public constant YIELD_MANAGER_ROLE = keccak256("YIELD_MANAGER_ROLE");

    function initialize(address admin) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function grantAllRoles(
        address governance,
        address vaultManager,
        address emergency,
        address liquidator,
        address yieldManager
    ) external {
        _grantRole(GOVERNANCE_ROLE, governance);
        _grantRole(VAULT_MANAGER_ROLE, vaultManager);
        _grantRole(EMERGENCY_ROLE, emergency);
        _grantRole(LIQUIDATOR_ROLE, liquidator);
        _grantRole(YIELD_MANAGER_ROLE, yieldManager);
    }

    function checkOnlyGovernance() external view {
        AccessControlLibrary.onlyGovernance(this);
    }

    function checkOnlyVaultManager() external view {
        AccessControlLibrary.onlyVaultManager(this);
    }

    function checkOnlyEmergencyRole() external view {
        AccessControlLibrary.onlyEmergencyRole(this);
    }

    function checkOnlyLiquidator() external view {
        AccessControlLibrary.onlyLiquidatorRole(this);
    }

    function checkOnlyYieldManager() external view {
        AccessControlLibrary.onlyYieldManager(this);
    }

    function checkOnlyAdmin() external view {
        AccessControlLibrary.onlyAdmin(this);
    }

    function validateAddressWrapper(address addr) external pure {
        AccessControlLibrary.validateAddress(addr);
    }
}

contract AccessControlLibraryTest is Test {
    AccessControlHarness private harness;

    address private admin = address(0xA1);
    address private governance = address(0xB1);
    address private vaultManager = address(0xC1);
    address private emergency = address(0xD1);
    address private liquidator = address(0xE1);
    address private yieldManager = address(0xF1);

    function setUp() public {
        harness = new AccessControlHarness();
        harness.initialize(admin);
        harness.grantAllRoles(governance, vaultManager, emergency, liquidator, yieldManager);
    }

    // ----------------- onlyGovernance -----------------

    function test_OnlyGovernance_AllowsGovernance() public {
        vm.prank(governance);
        harness.checkOnlyGovernance();
    }

    function test_OnlyGovernance_RevertsForNonGovernance() public {
        vm.prank(admin);
        vm.expectRevert(CommonErrorLibrary.NotGovernance.selector);
        harness.checkOnlyGovernance();
    }

    // ----------------- onlyVaultManager -----------------

    function test_OnlyVaultManager_AllowsVaultManager() public {
        vm.prank(vaultManager);
        harness.checkOnlyVaultManager();
    }

    function test_OnlyVaultManager_RevertsForNonManager() public {
        vm.prank(admin);
        vm.expectRevert(CommonErrorLibrary.NotVaultManager.selector);
        harness.checkOnlyVaultManager();
    }

    // ----------------- onlyEmergencyRole -----------------

    function test_OnlyEmergency_AllowsEmergency() public {
        vm.prank(emergency);
        harness.checkOnlyEmergencyRole();
    }

    function test_OnlyEmergency_RevertsForNonEmergency() public {
        vm.prank(admin);
        vm.expectRevert(CommonErrorLibrary.NotEmergencyRole.selector);
        harness.checkOnlyEmergencyRole();
    }

    // ----------------- onlyLiquidatorRole -----------------

    function test_OnlyLiquidator_AllowsLiquidator() public {
        vm.prank(liquidator);
        harness.checkOnlyLiquidator();
    }

    function test_OnlyLiquidator_RevertsForNonLiquidator() public {
        vm.prank(admin);
        vm.expectRevert(CommonErrorLibrary.NotLiquidatorRole.selector);
        harness.checkOnlyLiquidator();
    }

    // ----------------- onlyYieldManager -----------------

    function test_OnlyYieldManager_AllowsYieldManager() public {
        vm.prank(yieldManager);
        harness.checkOnlyYieldManager();
    }

    function test_OnlyYieldManager_RevertsForNonYieldManager() public {
        vm.prank(admin);
        vm.expectRevert(CommonErrorLibrary.NotYieldManager.selector);
        harness.checkOnlyYieldManager();
    }

    // ----------------- onlyAdmin -----------------

    function test_OnlyAdmin_AllowsAdmin() public {
        vm.prank(admin);
        harness.checkOnlyAdmin();
    }

    function test_OnlyAdmin_RevertsForNonAdmin() public {
        vm.prank(governance);
        vm.expectRevert(CommonErrorLibrary.NotAdmin.selector);
        harness.checkOnlyAdmin();
    }

    // ----------------- validateAddress -----------------

    function test_ValidateAddress_AcceptsNonZero() public pure {
        AccessControlLibrary.validateAddress(address(0x1234));
    }

    function test_ValidateAddress_RevertsForZero() public {
        vm.expectRevert(CommonErrorLibrary.InvalidAddress.selector);
        harness.validateAddressWrapper(address(0));
    }
}

