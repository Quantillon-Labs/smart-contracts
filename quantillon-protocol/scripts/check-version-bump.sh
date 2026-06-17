#!/usr/bin/env bash
#
# Version-bump gate for deployed contracts and linked libraries.
#
# RULE: any change to a deployed contract/library — correction, bug fix, update, or upgrade —
# MUST be traced through a semver bump of its on-chain version() (or, for linked libraries, the
# version() / VERSION constant). This gate enforces that: it hashes each artifact's
# metadata-free runtime bytecode (foundry runs with bytecode_hash="none" / cbor_metadata=false,
# so the hash is insensitive to comments and reflects real code changes only) and fails CI if the
# bytecode changed while the source version string did not.
#
# Usage:
#   scripts/check-version-bump.sh           # check against committed baseline (CI)
#   scripts/check-version-bump.sh --update  # re-baseline after an intentional, reviewed bump
#
set -euo pipefail
cd "$(dirname "$0")/.."

BASELINE_DIR="version-baseline"
UPDATE=0
[[ "${1:-}" == "--update" ]] && UPDATE=1

# Deployed contracts (15) + linked libraries (10). Inlined/internal-only libraries have no
# standalone bytecode; their changes alter the consuming contract's bytecode and are caught there.
TARGETS=(
  "src/core/QEUROToken.sol:QEUROToken"
  "src/core/QuantillonVault.sol:QuantillonVault"
  "src/core/QTIToken.sol:QTIToken"
  "src/core/UserPool.sol:UserPool"
  "src/core/HedgerPool.sol:HedgerPool"
  "src/core/stQEUROToken.sol:stQEUROToken"
  "src/core/stQEUROFactory.sol:stQEUROFactory"
  "src/core/FeeCollector.sol:FeeCollector"
  "src/core/yieldmanagement/YieldShift.sol:YieldShift"
  "src/oracle/ChainlinkOracle.sol:ChainlinkOracle"
  "src/oracle/StorkOracle.sol:StorkOracle"
  "src/oracle/OracleRouter.sol:OracleRouter"
  "src/oracle/SlippageStorage.sol:SlippageStorage"
  "src/libraries/TimeProviderLibrary.sol:TimeProvider"
  "src/core/TimelockUpgradeable.sol:TimelockUpgradeable"
  "src/libraries/AdminFunctionsLibrary.sol:AdminFunctionsLibrary"
  "src/libraries/HedgerPoolLogicLibrary.sol:HedgerPoolLogicLibrary"
  "src/libraries/HedgerPoolOptimizationLibrary.sol:HedgerPoolOptimizationLibrary"
  "src/libraries/HedgerPoolRedeemMathLibrary.sol:HedgerPoolRedeemMathLibrary"
  "src/libraries/QTITokenGovernanceLibrary.sol:QTITokenGovernanceLibrary"
  "src/libraries/TreasuryRecoveryLibrary.sol:TreasuryRecoveryLibrary"
  "src/libraries/UserPoolStakingLibrary.sol:UserPoolStakingLibrary"
  "src/libraries/VaultMath.sol:VaultMath"
  "src/libraries/YieldShiftCalculationLibrary.sol:YieldShiftCalculationLibrary"
  "src/libraries/YieldShiftOptimizationLibrary.sol:YieldShiftOptimizationLibrary"
)

mkdir -p "$BASELINE_DIR"

# First semver string literal in the file = the version() return / VERSION constant.
extract_version() {
  grep -oE '"[0-9]+\.[0-9]+\.[0-9]+[^"]*"' "$1" 2>/dev/null | head -1 | tr -d '"'
}

fail=0
for t in "${TARGETS[@]}"; do
  path="${t%%:*}"; name="${t##*:}"
  baseline="$BASELINE_DIR/$name.version"

  bytecode="$(forge inspect "$t" deployedBytecode 2>/dev/null || true)"
  if [[ -z "$bytecode" || "$bytecode" == "0x" ]]; then
    echo "ERROR: could not read deployedBytecode for $t (build first with: make build)"
    fail=1; continue
  fi
  new_hash="$(printf '%s' "$bytecode" | sha256sum | cut -d' ' -f1)"
  new_ver="$(extract_version "$path")"
  if [[ -z "$new_ver" ]]; then
    echo "ERROR: $name has no semver version() literal in $path"
    fail=1; continue
  fi

  if [[ "$UPDATE" == "1" ]]; then
    printf '%s\n%s\n' "$new_hash" "$new_ver" > "$baseline"
    echo "updated $baseline ($new_ver)"
    continue
  fi

  if [[ ! -f "$baseline" ]]; then
    echo "ERROR: no version baseline for $name. Run: scripts/check-version-bump.sh --update"
    fail=1; continue
  fi

  base_hash="$(sed -n '1p' "$baseline")"
  base_ver="$(sed -n '2p' "$baseline")"

  if [[ "$new_hash" == "$base_hash" ]]; then
    echo "ok   $name ($new_ver, unchanged)"
  elif [[ "$new_ver" != "$base_ver" ]]; then
    echo "ok   $name (bytecode changed; version bumped $base_ver -> $new_ver)"
  else
    echo "VERSION VIOLATION in $name: bytecode changed but version() is still $base_ver"
    echo "    -> bump the semver in $path (PATCH=fix/internal, MINOR=new behavior) per the"
    echo "       'every change is traced through a version bump' rule."
    fail=1
  fi
done

if [[ "$fail" != "0" && "$UPDATE" != "1" ]]; then
  echo ""
  echo "A deployed contract/library changed without a version bump. After bumping version(),"
  echo "re-baseline with: scripts/check-version-bump.sh --update"
  exit 1
fi
exit 0
