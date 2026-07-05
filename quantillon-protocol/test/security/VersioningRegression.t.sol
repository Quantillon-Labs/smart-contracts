// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {DeploymentSmokeTest} from "../DeploymentSmoke.t.sol";
import {IVersioned} from "../../src/interfaces/IVersioned.sol";

/**
 * @title VersioningRegression
 * @notice Verifies the IVersioned versioning system: every deployed core contract returns a
 *         non-empty semver via version(), readable through the proxy and via the IVersioned
 *         interface. (Audit follow-up: on-chain version provenance.)
 */
contract VersioningRegression is DeploymentSmokeTest {
    function _assertVersioned(address proxy, string memory label, string memory expected) private view {
        string memory v = IVersioned(proxy).version();
        assertGt(bytes(v).length, 0, string.concat(label, ": version() must be non-empty"));
        assertEq(v, expected, string.concat(label, ": unexpected version"));
    }

    /// @notice Every deployed core contract in the harness exposes version() through its proxy.
    /// @dev QuantillonVault is at 1.1.0 (harvestAndDistributeVaultYield / stQEURO yield distribution).
    function test_AllCoreContractsExposeVersion() public {
        deployFullProtocol();
        _assertVersioned(address(qeuroToken), "QEUROToken", "1.0.5");
        _assertVersioned(address(qtiToken), "QTIToken", "1.0.2");
        _assertVersioned(address(vault), "QuantillonVault", "1.1.6");
        _assertVersioned(address(userPool), "UserPool", "1.0.2");
        _assertVersioned(address(hedgerPool), "HedgerPool", "1.0.4");
        _assertVersioned(address(stQEURO), "stQEUROToken", "1.0.1");
        _assertVersioned(address(feeCollector), "FeeCollector", "1.0.0");
        _assertVersioned(address(yieldShift), "YieldShift", "1.0.3");
        _assertVersioned(address(timeProvider), "TimeProvider", "1.0.0");
    }

    /// @notice version() is a pure getter callable directly (reflects the implementation code).
    function test_VersionIsCallableDirectly() public {
        deployFullProtocol();
        assertEq(vault.version(), "1.1.6", "direct call returns semver");
    }
}
