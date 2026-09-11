// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {StQEUROYieldAndExternalCollateralTest} from "../StQEUROYieldAndExternalCollateral.t.sol";
import {ExecutionPricing} from "../../src/oracle/ExecutionPricing.sol";
import {TokenErrorLibrary} from "../../src/libraries/TokenErrorLibrary.sol";
import {CommonErrorLibrary as Errors} from "../../src/libraries/CommonErrorLibrary.sol";

/// @dev An adversarial module checks callback boundaries while a yield mint is in progress.
contract YieldReentryProbe {
    address public immutable vault;
    uint256 private immutable vaultId;
    bool public callbacksChecked;

    constructor(address vault_, uint256 vaultId_) { vault = vault_; vaultId = vaultId_; }

    function consumeMint(uint256 budget, uint256 ref) external returns (uint256 q, uint256 backing) {
        require(msg.sender == vault);
        bytes4 guarded = bytes4(keccak256("ReentrancyGuardReentrantCall()"));
        _reject(abi.encodeWithSignature("creditVaultYield(uint256,uint256)", vaultId, 1e6), guarded);
        _reject(abi.encodeWithSignature("harvestAndDistributeVaultYield(uint256)", vaultId), guarded);
        _reject(abi.encodeWithSignature("mintQEUROToVault(uint256,uint256,uint256)", 1e6, 0, 0), guarded);
        _reject(
            abi.encodeWithSignature("initializePriceCache(uint256)", ref),
            bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)"))
        );
        callbacksChecked = true;
        return (budget * 1e30 / ref, budget);
    }

    function _reject(bytes memory data, bytes4 expected) private {
        (bool ok, bytes memory result) = vault.call(data);
        require(!ok && result.length >= 4 && bytes4(result) == expected, "unexpected callback outcome");
    }
}

/// @notice Regression coverage for public mint routes and yield execution admission.
/// @dev Real vault, token, UserPool, stQEURO and pricing module; mocked oracle, venue and hedger integration.
contract MintExecutionBoundaryAuditTest is StQEUROYieldAndExternalCollateralTest {
    ExecutionPricing internal pricing;
    address internal outsider = address(0xBADCAFE);

    function _prepare(uint256 capacity) internal {
        vm.warp(100_000);
        _setUpStQEURO();
        vm.startPrank(user);
        usdc.approve(address(vault), 1080e6);
        vault.mintAndStakeQEURO(1080e6, 0, VAULT_ID, 1);
        vm.stopPrank();
        vm.roll(block.number + 1);
        pricing = new ExecutionPricing(
            [address(vault), address(0x1234), admin, address(this), address(this), treasury],
            [uint256(60), uint256(500), uint256(0), uint256(1000e18)]
        );
        vm.mockCall(address(oracle), abi.encodeWithSignature("activeOracle()"), abi.encode(uint8(1)));
        vm.mockCall(address(oracle), abi.encodeWithSignature("marketOracle()"), abi.encode(address(0x1234)));
        vm.mockCall(address(oracle), abi.encodeWithSignature("getEurUsdDetails()"), abi.encode(1.08e18,1.08e18,block.timestamp,false,true));
        ExecutionPricing.Level[] memory asks = new ExecutionPricing.Level[](2);
        ExecutionPricing.Level[] memory bids = new ExecutionPricing.Level[](2);
        asks[0] = ExecutionPricing.Level(1.09e18, 100e18);
        asks[1] = ExecutionPricing.Level(1.10e18, 100e18);
        bids[0] = ExecutionPricing.Level(1.07e18, 100e18);
        bids[1] = ExecutionPricing.Level(1.06e18, 100e18);
        pricing.publish(block.timestamp, asks, bids);
        pricing.acknowledge(0, 0, capacity, block.timestamp);
        vm.startPrank(admin);
        vault.pause();
        vault.configureExecutionPricing(address(pricing));
        vault.unpause();
        vm.stopPrank();
        usdc.mint(outsider, 100_000e6);
        vm.startPrank(outsider);
        usdc.approve(address(vault), type(uint256).max);
        usdc.approve(address(userPool), type(uint256).max);
        vm.stopPrank();
    }

    function _assertRoutesRevert(bytes4 expected) internal {
        uint256 balance = usdc.balanceOf(outsider);
        uint256 supply = qeuro.totalSupply();
        vm.startPrank(outsider);
        vm.expectRevert(expected);
        vault.mintQEURO(1000e6, 0);
        vm.expectRevert(expected);
        vault.mintQEUROToVault(1000e6, 0, 0);
        vm.expectRevert(expected);
        vault.mintQEUROToVault(1000e6, 0, VAULT_ID);
        vm.expectRevert(expected);
        vault.mintAndStakeQEURO(1000e6, 0, VAULT_ID, 0);
        uint256[] memory inputs = new uint256[](1);
        uint256[] memory minimums = new uint256[](1);
        inputs[0] = 1000e6;
        vm.expectRevert(expected);
        userPool.deposit(inputs, minimums);
        vm.stopPrank();
        assertEq(usdc.balanceOf(outsider), balance);
        assertEq(qeuro.totalSupply(), supply);
        assertEq(pricing.outstanding(), 0);
    }

    function test_Audit_AllPublicMintRoutesRejectOversizedBookWithZeroMinimum() public {
        _prepare(1000e18);
        _assertRoutesRevert(Errors.InsufficientBalance.selector);
    }

    function test_Audit_AllPublicMintRoutesRejectStaleBookWithZeroMinimum() public {
        _prepare(1000e18);
        vm.warp(block.timestamp + 61);
        _assertRoutesRevert(Errors.InvalidOraclePrice.selector);
    }

    function test_Audit_AllPublicMintRoutesRejectZeroCapacity() public {
        _prepare(0);
        _assertRoutesRevert(Errors.InsufficientBalance.selector);
    }

    function test_Audit_DifferentWalletsShareConsumedDepth() public {
        _prepare(1000e18);
        vm.prank(outsider);
        vault.mintQEUROToVault(109e6, 0, 0);
        assertEq(qeuro.balanceOf(outsider), 100e18);
        address second = address(0xB0B);
        usdc.mint(second, 110e6);
        vm.startPrank(second);
        usdc.approve(address(vault), 110e6);
        vault.mintQEUROToVault(110e6, 0, 0);
        vm.stopPrank();
        assertEq(qeuro.balanceOf(second), 100e18);
        assertEq(pricing.usedBuy(), 200e18);
        assertEq(pricing.outstanding(), 200e18);
        vm.prank(outsider);
        vm.expectRevert(Errors.InsufficientBalance.selector);
        vault.mintQEUROToVault(1e6, 0, 0);
    }

    function test_Audit_OutsiderCannotUsePrivilegedMintOrConfigurationPaths() public {
        _prepare(1000e18);
        bytes4 denied = bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)"));
        vm.startPrank(outsider);
        vm.expectPartialRevert(denied);
        qeuro.mint(outsider, 1000e18);
        address[] memory recipients = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        recipients[0] = outsider; amounts[0] = 1000e18;
        vm.expectPartialRevert(denied);
        qeuro.batchMint(recipients, amounts);
        vm.expectPartialRevert(denied);
        vault.creditVaultYield(VAULT_ID, 1080e6);
        vm.expectPartialRevert(denied);
        vault.harvestAndDistributeVaultYield(VAULT_ID);
        vm.expectPartialRevert(denied);
        vault.configureExecutionPricing(address(0));
        vm.expectRevert(Errors.NotAuthorized.selector);
        pricing.consumeMint(1e6, 1.08e18);
        vm.expectPartialRevert(denied);
        pricing.acknowledge(0, 0, 1000e18, block.timestamp);
        vm.expectRevert();
        vault._mintQEUROCommit(outsider,outsider,1e6,0,1e6,1e18,1.08e18,true,0);
        vm.stopPrank();
    }

    function _fundYield(uint256 amount) internal {
        vm.startPrank(admin);
        usdc.mint(admin, amount);
        usdc.approve(address(vault), amount);
        vm.stopPrank();
    }

    function _assertCreditReverts(uint256 amount, bytes4 expected) internal {
        _fundYield(amount);
        uint256 supply = qeuro.totalSupply();
        uint256 held = vault.totalUsdcHeld();
        uint256 beforeBalance = usdc.balanceOf(admin);
        uint256 stAssets = stToken.totalAssets();
        vm.prank(admin);
        vm.expectRevert(expected);
        vault.creditVaultYield(VAULT_ID, amount);
        assertEq(qeuro.totalSupply(), supply);
        assertEq(vault.totalUsdcHeld(), held);
        assertEq(usdc.balanceOf(admin), beforeBalance);
        assertEq(stToken.totalAssets(), stAssets);
        assertEq(pricing.admittedBuy(), 0);
        assertEq(pricing.outstanding(), 0);
    }

    function test_Audit_YieldRejectsZeroExecutionCapacity() public {
        _prepare(0);
        _assertCreditReverts(109e6, Errors.InsufficientBalance.selector);
    }

    function test_Audit_YieldPreservesFeeBoundValidation() public {
        _prepare(200e18);
        vm.mockCall(address(stToken), abi.encodeWithSignature("yieldFee()"), abi.encode(uint256(10_001)));
        _assertCreditReverts(109e6, Errors.PercentageTooHigh.selector);
    }

    function test_Audit_YieldRejectsStaleExecutionBook() public {
        _prepare(1000e18);
        vm.warp(block.timestamp + 61);
        _assertCreditReverts(109e6, Errors.InvalidOraclePrice.selector);
    }

    function test_Audit_YieldRejectsInsufficientExecutionCapacity() public {
        _prepare(100e18);
        _assertCreditReverts(110e6, Errors.InsufficientBalance.selector);
    }

    function test_Audit_YieldRejectsInsufficientOrderBookDepth() public {
        _prepare(1000e18);
        _assertCreditReverts(220e6, Errors.InsufficientBalance.selector);
    }

    function test_Audit_YieldReservesCapacityAndPaysExecutionSpread() public {
        _prepare(200e18);
        _fundYield(109e6);
        uint256 supply = qeuro.totalSupply();
        uint256 held = vault.totalUsdcHeld();
        uint256 backingBalance = usdc.balanceOf(address(vault));
        uint256 assets = stToken.totalAssets();
        vm.prank(admin);
        uint256 credited = vault.creditVaultYield(VAULT_ID, 109e6);
        assertEq(credited, 100e18);
        assertEq(qeuro.totalSupply() - supply, credited);
        assertEq(stToken.totalAssets() - assets, credited);
        assertEq(vault.totalUsdcHeld() - held, 108e6);
        assertEq(usdc.balanceOf(address(vault)) - backingBalance, 108e6);
        assertEq(usdc.balanceOf(address(pricing)), 1e6);
        assertEq(pricing.admittedBuy(), credited);
        assertEq(pricing.outstanding(), credited);
        (uint256 capacity,) = pricing.availableCapacity();
        assertEq(capacity, 100e18);
        // A public minter must pay the next, more expensive level after yield consumed the first.
        vm.prank(outsider);
        vault.mintQEUROToVault(110e6, 0, 0);
        assertEq(qeuro.balanceOf(outsider), 100e18);
        assertEq(pricing.outstanding(), 200e18);
    }

    function test_Audit_YieldUsesRemainingDepthAfterPublicMint() public {
        _prepare(200e18);
        vm.prank(outsider);
        vault.mintQEUROToVault(109e6, 0, 0);
        _fundYield(110e6);
        vm.prank(admin);
        assertEq(vault.creditVaultYield(VAULT_ID, 110e6), 100e18);
        assertEq(pricing.usedBuy(), 200e18);
        assertEq(usdc.balanceOf(address(pricing)), 3e6);
    }

    function test_Audit_YieldFeeAndExecutionSpreadConserveFundsWithoutMintFee() public {
        _prepare(200e18);
        vm.startPrank(admin);
        stToken.updateYieldParameters(2000); // 20% yield fee, independently of the public mint fee.
        vault.updateParameters(5e16, 0);
        vm.stopPrank();
        _fundYield(136_250_000);
        uint256 treasuryBefore = usdc.balanceOf(treasury);
        uint256 backingBefore = usdc.balanceOf(address(vault));
        uint256 heldBefore = vault.totalUsdcHeld();
        vm.prank(admin);
        uint256 credited = vault.creditVaultYield(VAULT_ID, 136_250_000);
        assertEq(credited, 100e18);
        assertEq(usdc.balanceOf(treasury) - treasuryBefore, 27_250_000);
        assertEq(usdc.balanceOf(address(pricing)), 1e6);
        assertEq(usdc.balanceOf(address(vault)) - backingBefore, 108e6);
        assertEq(vault.totalUsdcHeld() - heldBefore, 108e6);
        assertEq(
            usdc.balanceOf(treasury) - treasuryBefore + usdc.balanceOf(address(pricing))
                + usdc.balanceOf(address(vault)) - backingBefore,
            136_250_000
        );
    }

    function test_Audit_FailedYieldTokenMintRollsBackAdmissionFeeAndSpread() public {
        _prepare(200e18);
        vm.startPrank(admin);
        stToken.updateYieldParameters(2000);
        qeuro.setMintingKillswitch(true);
        vm.stopPrank();
        uint256 treasuryBefore = usdc.balanceOf(treasury);
        _assertCreditReverts(136_250_000, TokenErrorLibrary.MintingDisabled.selector);
        assertEq(usdc.balanceOf(treasury), treasuryBefore);
        assertEq(usdc.balanceOf(address(pricing)), 0);
        assertEq(pricing.usedBuy(), 0);
    }

    function test_Audit_HarvestRejectsZeroCapacityAndRollsBackExternalWithdrawal() public {
        _prepare(0);
        mockAaveVault.setAccruedYield(109e6);
        uint256 externalBalance = usdc.balanceOf(address(mockAaveVault));
        uint256 supply = qeuro.totalSupply();
        (,,uint256 principal,) = vault.getVaultExposure(VAULT_ID);
        (,,uint256 lastHarvest) = vault.harvestConfig(VAULT_ID);
        vm.prank(admin);
        vm.expectRevert(Errors.InsufficientBalance.selector);
        vault.harvestAndDistributeVaultYield(VAULT_ID);
        assertEq(usdc.balanceOf(address(mockAaveVault)), externalBalance);
        assertEq(qeuro.totalSupply(), supply);
        (,,uint256 principalAfter,) = vault.getVaultExposure(VAULT_ID);
        assertEq(principalAfter, principal);
        (,,uint256 lastAfter) = vault.harvestConfig(VAULT_ID);
        assertEq(lastAfter, lastHarvest);
        assertEq(pricing.outstanding(), 0);
    }

    function test_Audit_HarvestConsumesExecutionCapacity() public {
        _prepare(200e18);
        mockAaveVault.setAccruedYield(109e6);
        uint256 supply = qeuro.totalSupply();
        uint256 assets = stToken.totalAssets();
        vm.prank(admin);
        vault.harvestAndDistributeVaultYield(VAULT_ID);
        assertEq(qeuro.totalSupply() - supply, 100e18);
        assertEq(stToken.totalAssets() - assets, 100e18);
        assertEq(pricing.admittedBuy(), 100e18);
        assertEq(usdc.balanceOf(address(pricing)), 1e6);
    }

    function _probeYieldReentry(bool harvest) internal {
        _prepare(200e18);
        YieldReentryProbe probe = new YieldReentryProbe(address(vault), VAULT_ID);
        vm.startPrank(admin);
        vault.pause();
        vault.configureExecutionPricing(address(probe));
        vault.unpause();
        vm.stopPrank();
        if (harvest) {
            mockAaveVault.setAccruedYield(108e6);
            vm.prank(admin);
            vault.harvestAndDistributeVaultYield(VAULT_ID);
        } else {
            _fundYield(108e6);
            vm.prank(admin);
            vault.creditVaultYield(VAULT_ID, 108e6);
        }
        assertTrue(probe.callbacksChecked());
    }

    function test_Audit_YieldAdmissionCannotReenterVault() public { _probeYieldReentry(false); }
    function test_Audit_HarvestAdmissionCannotReenterVault() public { _probeYieldReentry(true); }
}
