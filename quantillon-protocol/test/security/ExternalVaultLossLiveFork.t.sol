// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {IExternalStakingVault} from "../../src/interfaces/IExternalStakingVault.sol";

interface IQuantillonVaultLossProbe {
    function version() external pure returns (string memory);
    function getVaultExposure(uint256 vaultId)
        external
        view
        returns (address adapter, bool active, uint256 principalTracked, uint256 currentUnderlying);
    function getTotalUsdcAvailable() external view returns (uint256);
}

/// @title ExternalVaultLossLiveFork
/// @notice Deployed-state marker for QNT-EXTERNAL-LOSS-PHANTOM-COLLATERAL.
/// @dev Documents that the QuantillonVault implementation deployed on Base at the pinned block
///      (v1.1.10, pre-fix) counts external principal regardless of the adapter's reported
///      underlying. The source fix in this repo (loss-aware min(principal, underlying), from
///      v1.1.11) changes local behavior but does NOT change already-deployed bytecode, so this
///      test keeps passing until the fixed implementation is deployed and this block/expectation is
///      updated. It reads pinned mainnet state read-only (no transaction is broadcast) and skips
///      gracefully when no Base RPC is reachable (e.g. offline CI).
contract ExternalVaultLossLiveForkTest is Test {
    uint256 internal constant FORK_BLOCK = 49_998_029;
    uint256 internal constant VAULT_ID = 2;

    address internal constant QUANTILLON_VAULT = 0x833E5Ba510a241b21F1C60c987D1c49eB52E4a07;
    address internal constant EXPECTED_ADAPTER = 0xb2f253Cd74ebfa16894339438B467396De9e8EA3;

    IQuantillonVaultLossProbe internal constant vault = IQuantillonVaultLossProbe(QUANTILLON_VAULT);

    function _selectForkOrSkip() internal returns (bool ok) {
        try vm.createSelectFork("https://mainnet.base.org", FORK_BLOCK) {
            return true;
        } catch {
            emit log("Base RPC unavailable; skipping deployed-state fork check");
            vm.skip(true);
            return false;
        }
    }

    /// @notice The deployed (pre-fix) v1.1.10 leaves reported collateral unchanged even when the
    ///         adapter's totalUnderlying() is forced to zero — the phantom-collateral behavior this
    ///         repo's source fix removes going forward.
    function test_deployedV1110CountsPrincipalWhenAdapterReportsZeroUnderlying() public {
        if (!_selectForkOrSkip()) return;

        assertEq(vault.version(), "1.1.10", "unexpected deployed QuantillonVault version at pinned block");

        (address adapter, bool active, uint256 principal, uint256 underlyingBefore) = vault.getVaultExposure(VAULT_ID);
        uint256 collateralBefore = vault.getTotalUsdcAvailable();

        assertEq(adapter, EXPECTED_ADAPTER, "unexpected live adapter");
        assertTrue(active, "vault id 2 is not active");
        assertEq(principal, 1_388_449, "unexpected pinned principal");
        assertEq(underlyingBefore, 1_388_499, "unexpected pinned underlying");

        vm.mockCall(
            adapter, abi.encodeWithSelector(IExternalStakingVault.totalUnderlying.selector), abi.encode(uint256(0))
        );

        (,, uint256 principalAfter, uint256 mockedUnderlying) = vault.getVaultExposure(VAULT_ID);
        uint256 collateralAfter = vault.getTotalUsdcAvailable();

        emit log_named_uint("live principal tracked (USDC 6d)", principalAfter);
        emit log_named_uint("mocked adapter underlying (USDC 6d)", mockedUnderlying);
        emit log_named_uint("reported collateral before (USDC 6d)", collateralBefore);
        emit log_named_uint("reported collateral after (USDC 6d)", collateralAfter);

        assertEq(mockedUnderlying, 0, "adapter loss probe did not take effect");
        assertEq(principalAfter, principal, "probe must not change Quantillon principal state");
        assertEq(collateralAfter, collateralBefore, "deployed v1.1.10 collateral accounting ignores adapter underlying");
    }
}

/// @title ExternalVaultLossFixedLiveFork
/// @notice Deployed-state marker for the FIX: QuantillonVault v1.1.11 live on Base.
/// @dev Counterpart to `ExternalVaultLossLiveForkTest` (which pins the pre-fix v1.1.10 behavior at
///      an earlier block). At this pinned block the proxy runs v1.1.11
///      (0x6Cd5446DD0293757C01B7B6685E101138B0F4C56, upgraded via the timelocked executeUpgrade at
///      block 50172739), so external positions are valued loss-aware and the adapter read fails
///      closed. Reads pinned mainnet state read-only and skips gracefully when no Base RPC is
///      reachable (e.g. offline CI).
contract ExternalVaultLossFixedLiveForkTest is Test {
    uint256 internal constant FORK_BLOCK = 50_174_108;
    uint256 internal constant VAULT_ID = 2;
    uint256 internal constant PINNED_PRINCIPAL = 1_388_449;
    uint256 internal constant PINNED_UNDERLYING = 1_388_510;
    uint256 internal constant PINNED_COLLATERAL = 26_388_449;

    address internal constant QUANTILLON_VAULT = 0x833E5Ba510a241b21F1C60c987D1c49eB52E4a07;
    address internal constant EXPECTED_ADAPTER = 0xb2f253Cd74ebfa16894339438B467396De9e8EA3;

    IQuantillonVaultLossProbe internal constant vault = IQuantillonVaultLossProbe(QUANTILLON_VAULT);

    function _selectForkOrSkip() internal returns (bool ok) {
        try vm.createSelectFork("https://mainnet.base.org", FORK_BLOCK) {
            return true;
        } catch {
            emit log("Base RPC unavailable; skipping deployed-state fork check");
            vm.skip(true);
            return false;
        }
    }

    /// @notice On deployed v1.1.11, forcing the adapter underlying to zero removes the position's
    ///         principal from reported collateral (loss-aware min(principal, underlying)).
    function test_deployedV1111ValuesExternalCollateralLossAware() public {
        if (!_selectForkOrSkip()) return;

        assertEq(vault.version(), "1.1.11", "unexpected deployed QuantillonVault version at pinned block");

        (address adapter, bool active, uint256 principal, uint256 underlying) = vault.getVaultExposure(VAULT_ID);
        assertEq(adapter, EXPECTED_ADAPTER, "unexpected live adapter");
        assertTrue(active, "vault id 2 is not active");
        assertEq(principal, PINNED_PRINCIPAL, "unexpected pinned principal");
        assertEq(underlying, PINNED_UNDERLYING, "unexpected pinned underlying");
        assertEq(vault.getTotalUsdcAvailable(), PINNED_COLLATERAL, "unexpected pinned collateral");

        vm.mockCall(
            adapter, abi.encodeWithSelector(IExternalStakingVault.totalUnderlying.selector), abi.encode(uint256(0))
        );
        assertEq(
            vault.getTotalUsdcAvailable(),
            PINNED_COLLATERAL - PINNED_PRINCIPAL,
            "v1.1.11 must drop the full principal from collateral when the adapter reports zero underlying"
        );
        vm.clearMockedCalls();
        assertEq(vault.getTotalUsdcAvailable(), PINNED_COLLATERAL, "collateral must restore after clearing the mock");
    }

    /// @notice On deployed v1.1.11 the adapter read fails closed: a reverting totalUnderlying()
    ///         propagates instead of being masked by a principal fallback.
    function test_deployedV1111FailsClosedOnAdapterReadFailure() public {
        if (!_selectForkOrSkip()) return;

        vm.mockCallRevert(
            EXPECTED_ADAPTER, abi.encodeWithSelector(IExternalStakingVault.totalUnderlying.selector), "adapter down"
        );
        (bool okAvail,) =
            QUANTILLON_VAULT.staticcall(abi.encodeWithSelector(IQuantillonVaultLossProbe.getTotalUsdcAvailable.selector));
        (bool okExpo,) = QUANTILLON_VAULT.staticcall(
            abi.encodeWithSelector(IQuantillonVaultLossProbe.getVaultExposure.selector, VAULT_ID)
        );
        vm.clearMockedCalls();
        assertFalse(okAvail, "getTotalUsdcAvailable must fail closed on adapter revert");
        assertFalse(okExpo, "getVaultExposure must fail closed on adapter revert");
    }
}
