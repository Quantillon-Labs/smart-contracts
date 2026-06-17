// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IVersioned
 * @notice Standard semantic-version getter implemented by every core Quantillon contract.
 * @dev Read through a proxy, `version()` reflects the deployed IMPLEMENTATION (it is a `pure`
 *      getter returning a compile-time constant, so it occupies no storage slot and is safe to add
 *      to storage-frozen upgradeable contracts). It pairs with the off-chain provenance manifest
 *      `deployments/{chainId}/versions.json` (impl address + commit) so the deployed version of any
 *      contract is answerable from a single on-chain call. Bump per semver on any change to the
 *      implementing contract; enforced by `make check-version-bump`.
 */
interface IVersioned {
    /**
     * @notice Returns the semantic version of the implementation.
     * @dev Semver convention: PATCH = bugfix/internal logic, MINOR = new function or
     *      externally-observable behavior (ABI-additive), MAJOR = reserved (storage/ABI breaks are
     *      disallowed by the upgrade-safety gates).
     * @return Semantic version string, e.g. "1.0.0".
     * @custom:security No security implications - returns a compile-time constant.
     * @custom:validation No input validation required.
     * @custom:state-changes None - pure function.
     * @custom:events None.
     * @custom:errors None.
     * @custom:reentrancy Not applicable - pure function.
     * @custom:access Public - anyone can read the version.
     * @custom:oracle No oracle dependencies.
     */
    function version() external pure returns (string memory);
}
