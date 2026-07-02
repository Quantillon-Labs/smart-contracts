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
#   * We key each entry on "slot:offset" and compare "type|bytes" (the readable
#     type from `forge inspect`, which is stable across recompiles, unlike the
#     JSON `astId`-suffixed encoding). We deliberately do NOT key on the variable
#     NAME, so renaming a now-dead variable to `__deprecated_*` (which preserves
#     the slot) passes the gate.
#   * Appends (new slot:offset pairs) are allowed. Any baseline slot:offset whose
#     type/bytes changed, or that disappeared, is a violation. A struct that grows
#     internally is caught via the shifted following slots and the changed `bytes`.
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
)

mkdir -p "$BASELINE_DIR"

# Normalize `forge inspect <C> storage-layout --json` into stable, sorted
# "slot:offset<TAB>type<TAB>bytes" lines (one per storage variable).
# We resolve each entry's type through the JSON `types` map to its readable
# `label` + `numberOfBytes`. Those come straight from solc's storageLayout
# (solc 0.8.24 is pinned), so they are stable across forge versions AND across
# unrelated source edits — unlike the raw `t_...` type strings, which carry
# astId suffixes that shift, or the ASCII-table rendering, which is forge's.
normalize() {
  forge inspect "$1" storage-layout --json 2>/dev/null \
    | jq -r '.types as $t | .storage[]
             | "\(.slot):\(.offset)\t\($t[.type].label)\t\($t[.type].numberOfBytes)"' \
    | sort
}

fail=0
for c in "${CONTRACTS[@]}"; do
  name="${c##*:}"
  baseline="$BASELINE_DIR/$name.layout"
  new="$(mktemp)"
  normalize "$c" > "$new"

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

if [[ "$fail" != "0" && "$UPDATE" != "1" ]]; then
  echo ""
  echo "Storage layout changed for a deployed proxy. Upgrades must be APPEND-ONLY."
  echo "If this change is intentional and append-only, re-baseline with:"
  echo "    scripts/check-storage-layout.sh --update"
  exit 1
fi
exit 0
