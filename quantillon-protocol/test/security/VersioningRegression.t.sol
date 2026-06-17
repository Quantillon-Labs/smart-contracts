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
    function _assertVersioned(address proxy, string memory label) private view {
        string memory v = IVersioned(proxy).version();
        assertGt(bytes(v).length, 0, string.concat(label, ": version() must be non-empty"));
        assertEq(v, "1.0.0", string.concat(label, ": initial version should be 1.0.0"));
    }

    /// @notice Every deployed core contract in the harness exposes version() through its proxy.
    function test_AllCoreContractsExposeVersion() public {
        deployFullProtocol();
        _assertVersioned(address(qeuroToken), "QEUROToken");
        _assertVersioned(address(qtiToken), "QTIToken");
        _assertVersioned(address(vault), "QuantillonVault");
        _assertVersioned(address(userPool), "UserPool");
        _assertVersioned(address(hedgerPool), "HedgerPool");
        _assertVersioned(address(stQEURO), "stQEUROToken");
        _assertVersioned(address(feeCollector), "FeeCollector");
        _assertVersioned(address(yieldShift), "YieldShift");
        _assertVersioned(address(timeProvider), "TimeProvider");
    }

    /// @notice version() is a pure getter callable directly (reflects the implementation code).
    function test_VersionIsCallableDirectly() public {
        deployFullProtocol();
        assertEq(vault.version(), "1.0.0", "direct call returns semver");
    }
}
