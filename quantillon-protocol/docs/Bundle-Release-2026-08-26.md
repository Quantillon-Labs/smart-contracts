# 2026-08-26 Bundle Release Runbook

## Scope

This Base-mainnet release synchronizes eight deployed proxies and the linked YieldShift calculation
library with their current source versions:

| Contract | Live | Target | Governance flow | Logic impact |
|---|---:|---:|---|---|
| QEUROToken | 1.0.5 | 1.0.6 | 12-hour timelock | Version/NatSpec only |
| UserPool | 1.0.2 | 1.0.3 | 12-hour timelock | Version/NatSpec only |
| FeeCollector | 1.0.0 | 1.0.2 | Safe direct UUPS | Version/NatSpec only |
| YieldShift | 1.0.3 | 1.0.5 | 12-hour timelock | Version/NatSpec only |
| YieldShiftCalculationLibrary | 1.0.1 | 1.0.2 | Deploy and relink YieldShift | Version/comment only; the functional direction fix is already live in 1.0.1 |
| ChainlinkOracle | 1.0.2 | 1.0.4 | Safe direct UUPS | Version/NatSpec only |
| OracleRouter | 1.1.0 | 1.1.1 | Safe direct UUPS | Version/NatSpec only |
| SlippageStorage | 1.0.1 | 1.0.2 | Safe direct UUPS | Version/NatSpec only |
| LighterEurUsdOracle | 1.0.0 | 1.0.1 | Safe direct UUPS | Governance baseline and fail-safe read hardening |

The five direct upgrades and the secure-upgrade schedule are atomic in Safe phase 1. The three
secure upgrades execute atomically through `TimelockController.executeBatch` in phase 2.

This runbook prepares transactions; it does not authorize bypassing the governance Safe or the
12-hour timelock.

## 1. Freeze and validate the release commit

Work from a committed, clean release commit. The commit recorded in `GIT_COMMIT` must contain the
exact source being compiled.

```bash
make check-upgrade-safety
FOUNDRY_PROFILE=test forge test
make slither

for contract in QEUROToken UserPool FeeCollector YieldShift ChainlinkOracle OracleRouter SlippageStorage LighterEurUsdOracle; do
  make check-verifiable-bytecode CONTRACT="$contract"
done
make check-verifiable-bytecode CONTRACT=YieldShiftCalculationLibrary
```

Every verifiability check must complete. If a contract diverges, deploy that contract with
`build-verifiable-impl.sh` and construct the candidate manifest from the resulting addresses instead
of using the all-in-one deploy script.

## 2. Deploy and verify the relinked library

The July `YieldShiftCalculationLibrary` deployment is `1.0.1`; source is `1.0.2`. Deploy the inert
`1.0.2` library first and export the returned address. It has no proxy and becomes active only when
the YieldShift proxy is upgraded to an implementation linked to it.

```bash
forge create src/libraries/YieldShiftCalculationLibrary.sol:YieldShiftCalculationLibrary \
  --rpc-url "$BASE_RPC_URL" --private-key "$PRIVATE_KEY" --broadcast --verify

export YieldShiftCalculationLibrary=<new-1.0.2-library-address>
cast call "$YieldShiftCalculationLibrary" "version()(string)" --rpc-url "$BASE_RPC_URL"
```

## 3. Rehearse candidate deployment on a Base fork

Load the reviewed, already-deployed library set:

```bash
set -a
source deployments/8453/audit-remediation/deployed-libraries.env
set +a

# Override the July 1.0.1 address with the freshly verified 1.0.2 deployment.
export YieldShiftCalculationLibrary=<new-1.0.2-library-address>

PRIVATE_KEY=1 \
GIT_COMMIT="$(git rev-parse HEAD)" \
BUNDLE_RELEASE=2026-08-26-drift-sync \
forge script scripts/deployment/DeployBundleRelease.s.sol:DeployBundleRelease \
  --fork-url "$BASE_RPC_URL" --skip-simulation -vv \
  --libraries "src/libraries/TreasuryRecoveryLibrary.sol:TreasuryRecoveryLibrary:$TreasuryRecoveryLibrary" \
  --libraries "src/libraries/AdminFunctionsLibrary.sol:AdminFunctionsLibrary:$AdminFunctionsLibrary" \
  --libraries "src/libraries/UserPoolStakingLibrary.sol:UserPoolStakingLibrary:$UserPoolStakingLibrary" \
  --libraries "src/libraries/YieldShiftCalculationLibrary.sol:YieldShiftCalculationLibrary:$YieldShiftCalculationLibrary" \
  --libraries "src/libraries/YieldShiftOptimizationLibrary.sol:YieldShiftOptimizationLibrary:$YieldShiftOptimizationLibrary"
```

This deploys only inert implementation contracts in the fork. It does not call any proxy.

## 4. Deploy and verify inert candidates

Use the production deployment key only for implementation deployment. Proxy authority stays with
the governance Safe and timelock.

```bash
PRIVATE_KEY="$PRIVATE_KEY" \
GIT_COMMIT="$(git rev-parse HEAD)" \
BUNDLE_RELEASE=2026-08-26-drift-sync \
forge script scripts/deployment/DeployBundleRelease.s.sol:DeployBundleRelease \
  --rpc-url "$BASE_RPC_URL" --broadcast --verify \
  --libraries "src/libraries/TreasuryRecoveryLibrary.sol:TreasuryRecoveryLibrary:$TreasuryRecoveryLibrary" \
  --libraries "src/libraries/AdminFunctionsLibrary.sol:AdminFunctionsLibrary:$AdminFunctionsLibrary" \
  --libraries "src/libraries/UserPoolStakingLibrary.sol:UserPoolStakingLibrary:$UserPoolStakingLibrary" \
  --libraries "src/libraries/YieldShiftCalculationLibrary.sol:YieldShiftCalculationLibrary:$YieldShiftCalculationLibrary" \
  --libraries "src/libraries/YieldShiftOptimizationLibrary.sol:YieldShiftOptimizationLibrary:$YieldShiftOptimizationLibrary"
```

The broadcast writes `deployments/8453/bundle-release-candidates.json`. Before continuing, confirm
all eight implementations are verified and their runtime bytecode matches the linked artifacts.
The candidate manifest records all five library addresses and the payload generator checks every
runtime link slot, including the new YieldShift calculation library.

## 5. Build and review Safe payloads

```bash
RPC_URL="$BASE_RPC_URL" \
scripts/deployment/build-bundle-release-safe-txs.sh \
  deployments/8453/bundle-release-candidates.json \
  2026-08-26-drift-sync
```

The generator performs read-only validation of:

- chain ID, release commit, proxy addresses, and current implementation slots;
- candidate code, `version()`, UUPS UUID, and `TimeProvider` immutables;
- all five linked-library versions and every candidate runtime link address;
- the Safe's upgrade-authority role on all five plain proxies (`GOVERNANCE_ROLE` for FeeCollector,
  `UPGRADER_ROLE` for the four oracle/storage proxies);
- the TimelockController address, delay, Safe proposer/executor roles, and secure-upgrade status.

It writes:

- `safe-tx-1-bundle-2026-08-26-drift-sync.json`;
- `safe-tx-2-bundle-2026-08-26-drift-sync.json`;
- matching rollback phase-1 and phase-2 JSON files; and
- `bundle-release-2026-08-26-drift-sync.json`, including both timelock operation IDs.

Review every target, candidate address, calldata, operation ID, and transaction order independently
before submitting to the Safe.

## 6. Execute phase 1

Import `safe-tx-1-bundle-2026-08-26-drift-sync.json` into the Safe Transaction Builder. It contains
six calls executed atomically by MultiSend:

1. FeeCollector `upgradeToAndCall`;
2. ChainlinkOracle `upgradeToAndCall`;
3. OracleRouter `upgradeToAndCall`;
4. SlippageStorage `upgradeToAndCall`;
5. LighterEurUsdOracle `upgradeToAndCall`;
6. TimelockController `scheduleBatch` for QEUROToken, UserPool, and YieldShift.

After the 2-of-3 Safe transaction is mined, verify the five direct proxy slots and versions. Confirm
the recorded operation is pending and its timestamp matches the 12-hour delay:

```bash
cast call 0x7Ade8f3Bf1FdaF0785efE9Ea5C6339D1aD6B8342 \
  "isOperationPending(bytes32)(bool)" <operation-id> --rpc-url "$BASE_RPC_URL"
cast call 0x7Ade8f3Bf1FdaF0785efE9Ea5C6339D1aD6B8342 \
  "getTimestamp(bytes32)(uint256)" <operation-id> --rpc-url "$BASE_RPC_URL"
```

## 7. Execute phase 2 after 12 hours

Once `isOperationReady(operationId)` is true, import and execute
`safe-tx-2-bundle-2026-08-26-drift-sync.json`. The TimelockController atomically upgrades
QEUROToken, UserPool, and YieldShift.

Do not edit or regenerate phase 2 between schedule and execution: targets, values, calldata,
predecessor, and salt must exactly match the scheduled batch.

## 8. Validate and record completion

```bash
RECORD_ACTION=validate \
RPC_URL="$BASE_RPC_URL" \
scripts/deployment/record-bundle-release.sh \
  deployments/8453/bundle-release-2026-08-26-drift-sync.json

PHASE1_TX_HASH=<safe-phase-1-hash> \
PHASE2_TX_HASH=<safe-phase-2-hash> \
RPC_URL="$BASE_RPC_URL" \
scripts/deployment/record-bundle-release.sh \
  deployments/8453/bundle-release-2026-08-26-drift-sync.json

make check-deployed-versions
```

The read-only pass validates the release without touching local records. The recording pass requires
both successful on-chain transactions to target the governance Safe. It also verifies the timelock
operation is complete and validates all eight live implementation slots, versions, and five linked
libraries before atomically updating `versions.json`. The new YieldShift calculation library is also
recorded for future drift checks. Both modes require a nonzero, healthy, valid Lighter baseline/read.
Commit the final release manifest and `versions.json`.

## Rollback

The payload generator captures every pre-release implementation and emits matching rollback JSON.
Use rollback files only after independently confirming the desired state:

- rollback phase 1 immediately restores the five plain proxies and schedules the three secure
  rollbacks;
- rollback phase 2 executes the secure rollbacks after the same 12-hour delay.

Before phase 2 of the release, cancel the pending timelock operation instead of scheduling a secure
rollback. A Safe rejection or any failed subcall reverts the entire MultiSend transaction.
