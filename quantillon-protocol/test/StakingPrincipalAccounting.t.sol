// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IExternalStakingVault} from "../src/interfaces/IExternalStakingVault.sol";
import {StakingYieldLibrary} from "../src/libraries/StakingYieldLibrary.sol";
import {CommonErrorLibrary} from "../src/libraries/CommonErrorLibrary.sol";

contract PrincipalAsset is ERC20 {
    constructor() ERC20("Collateral", "COL") {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

contract PrincipalAdapter is IExternalStakingVault {
    IERC20 immutable asset;
    uint256 public shortfall;
    uint256 public reportExcess;
    constructor(IERC20 asset_) { asset = asset_; }
    function setReturnBehavior(uint256 shortfall_, uint256 reportExcess_) external {
        shortfall = shortfall_;
        reportExcess = reportExcess_;
    }
    function depositUnderlying(uint256 amount) external returns (uint256) {
        asset.transferFrom(msg.sender, address(this), amount);
        return amount;
    }
    function withdrawUnderlying(uint256 amount) external returns (uint256) {
        asset.transfer(msg.sender, amount - shortfall);
        return amount - shortfall + reportExcess;
    }
    function totalUnderlying() external view returns (uint256) { return asset.balanceOf(address(this)); }
    function harvestYieldToVault() external pure returns (uint256) { return 0; }
}

// Storage-owning harness exercises the same delegatecall and balance-delta
// boundaries as QuantillonVault, without bypassing library validation.
contract PrincipalHarness {
    mapping(uint256 => IExternalStakingVault) public adapters;
    mapping(uint256 => bool) public active;
    mapping(uint256 => uint256) public principal;
    IERC20 immutable asset;
    constructor(IERC20 asset_) { asset = asset_; }
    function seed(uint256 id, IExternalStakingVault adapter, uint256 amount) external {
        adapters[id] = adapter;
        active[id] = true;
        principal[id] = amount;
    }
    function configure(uint256 id, address adapter, bool enabled, bool paused) external {
        StakingYieldLibrary.configureAdapter(adapters, active, principal, id, adapter, enabled, paused);
    }
    function withdraw(uint256[] memory priority, uint256 amount) external returns (uint256) {
        return StakingYieldLibrary.withdrawPrincipal(adapters, active, principal, priority, amount, asset);
    }
    function realizeLoss(uint256 id) external returns (uint256) {
        return StakingYieldLibrary.realizeLoss(adapters, principal, id);
    }
}

contract StakingPrincipalAccountingTest is Test {
    PrincipalAsset asset;
    PrincipalHarness harness;
    PrincipalAdapter first;
    PrincipalAdapter second;

    function setUp() public {
        asset = new PrincipalAsset();
        harness = new PrincipalHarness(asset);
        first = new PrincipalAdapter(asset);
        second = new PrincipalAdapter(asset);
        asset.mint(address(first), 100);
        asset.mint(address(second), 100);
        harness.seed(1, first, 100);
        harness.seed(2, second, 100);
    }

    function _priority() private pure returns (uint256[] memory ids) {
        ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
    }

    function test_ExactWithdrawalsPreservePrincipalSum() public {
        assertEq(harness.withdraw(_priority(), 150), 150);
        assertEq(asset.balanceOf(address(harness)), 150);
        assertEq(harness.principal(1), 0);
        assertEq(harness.principal(2), 50);
        assertEq(first.totalUnderlying() + second.totalUnderlying(), 50);
    }

    function test_OneUnitShortfallRevertsAllTransfersEvenWithSecondAdapter() public {
        first.setReturnBehavior(1, 0);
        vm.expectRevert(CommonErrorLibrary.InvalidAmount.selector);
        harness.withdraw(_priority(), 150);
        assertEq(asset.balanceOf(address(harness)), 0);
        assertEq(harness.principal(1), 100);
        assertEq(harness.principal(2), 100);
        assertEq(first.totalUnderlying(), 100);
    }

    function test_ReportedAmountMustMatchActualTransfer() public {
        first.setReturnBehavior(1, 1);
        vm.expectRevert(CommonErrorLibrary.InvalidAmount.selector);
        harness.withdraw(_priority(), 100);
        assertEq(asset.balanceOf(address(harness)), 0);
        assertEq(harness.principal(1), 100);
    }

    function test_FundedAdapterCannotBeDisabled() public {
        vm.expectRevert(CommonErrorLibrary.InvalidCondition.selector);
        harness.configure(1, address(first), false, true);
        assertTrue(harness.active(1));
    }

    function test_FundedReplacementRequiresPauseAndEmptyOldAdapter() public {
        vm.expectRevert(CommonErrorLibrary.InvalidCondition.selector);
        harness.configure(1, address(second), true, false);
        vm.expectRevert(CommonErrorLibrary.InvalidCondition.selector);
        harness.configure(1, address(second), true, true);
        assertEq(address(harness.adapters(1)), address(first));
    }

    function test_FundedReplacementRequiresBackingAndPreservesPrincipal() public {
        first.withdrawUnderlying(100);
        second.withdrawUnderlying(1);
        vm.expectRevert(CommonErrorLibrary.InvalidCondition.selector);
        harness.configure(1, address(second), true, true);
        asset.mint(address(second), 1);
        harness.configure(1, address(second), true, true);
        assertEq(address(harness.adapters(1)), address(second));
        assertEq(harness.principal(1), 100);
        assertTrue(harness.active(1));
    }

    function test_LossRecognitionReducesOnlyAffectedPrincipal() public {
        first.withdrawUnderlying(20);
        assertEq(harness.realizeLoss(1), 20);
        assertEq(harness.principal(1), 80);
        assertEq(harness.principal(2), 100);
        assertEq(asset.balanceOf(address(harness)), 0);
        vm.expectRevert(CommonErrorLibrary.InvalidCondition.selector);
        harness.realizeLoss(1);
    }
}
