// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {HedgerPool} from "../../src/core/HedgerPool.sol";
import {HedgerPoolAccountingLibrary as Accounting} from "../../src/libraries/HedgerPoolAccountingLibrary.sol";
import {TimeProvider} from "../../src/libraries/TimeProviderLibrary.sol";
import {IQuantillonVault} from "../../src/interfaces/IQuantillonVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Opt-in archive-fork regression for the fixed July 2026 correction.
contract HedgerLegacyCorrectionTest is Test {
    HedgerPool private constant POOL = HedgerPool(0xff5D7cE5c7671B2EA805Ee752B4f8eC9Ecf2975A);
    address private constant SAFE = 0x1d7fF432a93d0085Fb69474c7E567f859829e6cd;
    uint256 private constant CREDIT = 388448;
    IQuantillonVault private vault;

    function setUp() public {
        string memory rpc = vm.envOr("LEGACY_CORRECTION_FORK_URL", string(""));
        if (bytes(rpc).length == 0) { vm.skip(true); return; }
        vm.createSelectFork(rpc, 51514404);
        HedgerPool implementation = new HedgerPool(POOL.TIME_PROVIDER());
        vm.prank(address(POOL.timelock()));
        POOL.upgradeToAndCall(address(implementation), "");
        vault = POOL.vault();
        vm.prank(SAFE);
        POOL.pause();
    }

    function _position() private view returns (HedgerPool.HedgePosition memory p) {
        (bool ok, bytes memory data) = address(POOL).staticcall(abi.encodeWithSignature("positions(uint256)", 1));
        assertTrue(ok);
        return abi.decode(data, (HedgerPool.HedgePosition));
    }

    function _apply() private { vm.prank(SAFE); POOL.correctLegacyMargin(); }

    function test_ExactCreditReconcilesAllBackingWithoutTransfers() public {
        HedgerPool.HedgePosition memory beforePosition = _position();
        uint256 backing = vault.getTotalUsdcAvailable();
        uint256 supply = IERC20(vault.qeuro()).totalSupply();
        uint256 safeCash = POOL.usdc().balanceOf(SAFE);
        uint256 vaultCash = POOL.usdc().balanceOf(address(vault));
        _apply();
        HedgerPool.HedgePosition memory afterPosition = _position();
        beforePosition.margin += uint96(CREDIT);
        beforePosition.positionSize = beforePosition.margin * beforePosition.leverage;
        assertEq(abi.encode(afterPosition), abi.encode(beforePosition), "only margin and size change");
        assertEq(POOL.totalMargin(), afterPosition.margin);
        assertEq(POOL.totalExposure(), afterPosition.positionSize);
        assertEq(POOL.totalFilledExposure(), afterPosition.filledVolume);
        assertEq(uint256(afterPosition.margin) + afterPosition.filledVolume, backing, "no legacy residue");
        assertEq(vault.getTotalUsdcAvailable(), backing);
        assertEq(IERC20(vault.qeuro()).totalSupply(), supply);
        assertEq(POOL.usdc().balanceOf(SAFE), safeCash);
        assertEq(POOL.usdc().balanceOf(address(vault)), vaultCash);
    }

    function test_CannotReplayEvenIfSurplusReappears() public {
        _apply();
        vm.mockCall(address(vault), abi.encodeCall(vault.getTotalUsdcAvailable, ()),
            abi.encode(vault.getTotalUsdcAvailable() + CREDIT));
        vm.expectRevert(Accounting.LegacyCorrectionAlreadyApplied.selector);
        _apply();
    }

    function test_UnauthorizedCallerRejected() public {
        vm.expectRevert(Accounting.LegacyCorrectionUnauthorized.selector);
        POOL.correctLegacyMargin();
    }

    function test_RequiresPause() public {
        vm.prank(SAFE); POOL.unpause();
        vm.expectRevert(Accounting.LegacyCorrectionStateMismatch.selector);
        _apply();
    }

    function test_WrongChainRejected() public {
        vm.chainId(84532);
        vm.expectRevert(Accounting.LegacyCorrectionStateMismatch.selector);
        _apply();
    }

    function test_ChangedOwnerRejected() public {
        vm.mockCall(address(POOL), abi.encodeCall(POOL.singleHedger, ()), abi.encode(address(0x123)));
        vm.expectRevert(Accounting.LegacyCorrectionStateMismatch.selector);
        _apply();
    }

    function test_MismatchedTotalsRejected() public {
        vm.mockCall(address(POOL), abi.encodeCall(POOL.totalExposure, ()), abi.encode(POOL.totalExposure() + 1));
        vm.expectRevert(Accounting.LegacyCorrectionStateMismatch.selector);
        _apply();
    }

    function test_ChangedSurplusRejected() public {
        vm.mockCall(address(vault), abi.encodeCall(vault.getTotalUsdcAvailable, ()), abi.encode(vault.getTotalUsdcAvailable() + 1));
        vm.expectRevert(Accounting.LegacyCorrectionStateMismatch.selector);
        _apply();
    }

    function test_UnbackedSupplyRejected() public {
        vm.mockCall(vault.qeuro(), abi.encodeCall(IERC20.totalSupply, ()), abi.encode(uint256(_position().qeuroBacked) + 1e12 + 1));
        vm.expectRevert(Accounting.LegacyCorrectionStateMismatch.selector);
        _apply();
    }
    function test_ReopenedPositionCannotReceiveHistoricalCorrection() public {
        // Frozen deployed layout: positions mapping at slot 19, openBlock at byte 19 of word 4.
        bytes32 word = bytes32(uint256(keccak256(abi.encode(uint256(1), uint256(19)))) + 4);
        uint256 packed = uint256(vm.load(address(POOL), word));
        uint256 mask = uint256(type(uint64).max) << 152;
        vm.store(address(POOL), word, bytes32((packed & ~mask) | (uint256(51514405) << 152)));
        assertEq(_position().openBlock, 51514405);
        vm.expectRevert(Accounting.LegacyCorrectionStateMismatch.selector);
        _apply();
    }
}
