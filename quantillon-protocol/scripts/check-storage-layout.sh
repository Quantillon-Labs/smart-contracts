#!/usr/bin/env bash
#
# Storage-layout safety gate for the upgradeable (storage-frozen) contracts.
#
# The protocol is live and UUPS-upgradeable, so every deployed proxy's storage
# layout is frozen: an upgrade may only APPEND new variables. It may never move,
# remove, resize, or retype an existing slot. This script captures a committed
# baseline of each contract's layout and fails CI if any existing slot changes.
#
# Design notes:
#   * We recursively compare mapping keys/values, array elements and struct members,
#     including their slots, offsets, encodings and widths. Readable type labels
#     stay stable across recompiles; compiler AST identifiers do not. Top-level
#     variable names may change, while struct member names are frozen to catch
#     same-width member reordering.
#   * Appends (new slot:offset pairs) are allowed. Any baseline slot:offset whose
#     type/bytes changed, or that disappeared, is a violation. A struct that grows
#     internally is rejected even when its outer slot and size do not change.
#
# Usage:
#   scripts/check-storage-layout.sh            # check against committed baseline (CI)
#   scripts/check-storage-layout.sh --update   # (re)generate the baseline after an
#                                               # intentional, reviewed append
#
set -euo pipefail

cd "$(dirname "$0")/.."

BASELINE_DIR="storage-layout"
UPDATE=0
[[ "${1:-}" == "--update" ]] && UPDATE=1

# The storage-frozen upgradeable contracts (UUPS proxies). Keep in sync with
# deployments/8453/addresses.json.
CONTRACTS=(
  "src/core/QEUROToken.sol:QEUROToken"
  "src/core/QuantillonVault.sol:QuantillonVault"
  "src/core/QTIToken.sol:QTIToken"
  "src/core/UserPool.sol:UserPool"
  "src/core/HedgerPool.sol:HedgerPool"
  "src/core/stQEUROToken.sol:stQEUROToken"
  "src/core/stQEUROFactory.sol:stQEUROFactory"
  "src/core/FeeCollector.sol:FeeCollector"
  "src/core/yieldmanagement/YieldShift.sol:YieldShift"
  "src/core/TimelockUpgradeable.sol:TimelockUpgradeable"
  "src/libraries/TimeProviderLibrary.sol:TimeProvider"
  "src/oracle/ChainlinkOracle.sol:ChainlinkOracle"
  "src/oracle/StorkOracle.sol:StorkOracle"
  "src/oracle/OracleRouter.sol:OracleRouter"
  "src/oracle/SlippageStorage.sol:SlippageStorage"
  "src/oracle/HyperliquidEurUsdOracle.sol:HyperliquidEurUsdOracle"
  "src/oracle/LighterEurUsdOracle.sol:LighterEurUsdOracle"
)

mkdir -p "$BASELINE_DIR"
namespace_args=()
[[ "$UPDATE" == "1" ]] && namespace_args+=(--update)
python3 scripts/check-storage-namespaces.py "${namespace_args[@]}"


fail=0
for c in "${CONTRACTS[@]}"; do
  name="${c##*:}"
  baseline="$BASELINE_DIR/$name.layout"
  new="$(mktemp)"
  raw="$(mktemp)"
  forge inspect "$c" storage-layout --json > "$raw"
  jq -r '.types as $t | .storage[] | "\(.slot):\(.offset)\t\($t[.type].label)\t\($t[.type].numberOfBytes)"' "$raw" | sort > "$new"
  type_args=()
  [[ "$UPDATE" == "1" ]] && type_args+=(--update)
  if ! python3 scripts/storage-layout-check.py "$raw" "$BASELINE_DIR/$name.types.json" "${type_args[@]}"; then
    fail=1; rm -f "$raw" "$new"; continue
  fi
  rm -f "$raw"

  if [[ ! -s "$new" ]]; then
    echo "ERROR: could not read storage layout for $c (build first with: make build)"
    fail=1; rm -f "$new"; continue
  fi

  if [[ "$UPDATE" == "1" ]]; then
    cp "$new" "$baseline"
    echo "updated $baseline ($(wc -l < "$baseline") slots)"
    rm -f "$new"; continue
  fi

  if [[ ! -f "$baseline" ]]; then
    echo "ERROR: no baseline for $name. Run: scripts/check-storage-layout.sh --update"
    fail=1; rm -f "$new"; continue
  fi

  # Baseline entries missing/changed in the new layout = forbidden mutations.
  violations="$(comm -23 <(sort "$baseline") <(sort "$new") || true)"
  if [[ -n "$violations" ]]; then
    echo "STORAGE-LAYOUT VIOLATION in $name (existing slot moved/removed/retyped):"
    echo "$violations" | sed 's/^/    - /'
    fail=1
  else
    echo "ok   $name ($(wc -l < "$baseline") baselined slots)"
  fi
  rm -f "$new"
done

if [[ "$fail" != "0" ]]; then
  echo ""
  echo "Storage layout changed for a deployed proxy. Upgrades must be APPEND-ONLY."
  echo "If this change is intentional and append-only, re-baseline with:"
  echo "    scripts/check-storage-layout.sh --update"
  exit 1
fi
exit 0
