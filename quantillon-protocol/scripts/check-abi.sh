#!/usr/bin/env bash
#
# ABI / selector safety gate for the deployed (storage-frozen) contracts.
#
# Consumers (the dApp, indexers, integrators) depend on stable function selectors
# and event/error signatures. An upgrade may ADD functions/events/errors, but
# removing or changing the signature of an existing one silently breaks callers.
# This script baselines each contract's selectors + event/error signatures and
# fails CI if any existing one disappears or changes. Additions are allowed.
#
# Usage:
#   scripts/check-abi.sh            # check against committed baseline (CI)
#   scripts/check-abi.sh --update   # re-baseline after an intentional, reviewed add
#
set -euo pipefail

cd "$(dirname "$0")/.."

BASELINE_DIR="abi-baseline"
UPDATE=0
[[ "${1:-}" == "--update" ]] && UPDATE=1

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
  "src/oracle/ChainlinkOracle.sol:ChainlinkOracle"
  "src/oracle/StorkOracle.sol:StorkOracle"
  "src/oracle/OracleRouter.sol:OracleRouter"
  "src/oracle/SlippageStorage.sol:SlippageStorage"
  "src/oracle/HyperliquidEurUsdOracle.sol:HyperliquidEurUsdOracle"
  "src/oracle/LighterEurUsdOracle.sol:LighterEurUsdOracle"
)

mkdir -p "$BASELINE_DIR"

# Emit stable, sorted fingerprint lines for a contract:
#   fn <4byte-selector> <signature>   (exact ABI selector, from methodIdentifiers)
#   ev <signature>                    (event)
#   er <signature>                    (custom error)
fingerprint() {
  forge inspect "$1" methodIdentifiers 2>/dev/null \
    | awk -F'|' 'NF>=4 {
        sig=$2; sel=$3;
        gsub(/^[ \t]+|[ \t]+$/, "", sig);
        gsub(/^[ \t]+|[ \t]+$/, "", sel);
        if (sel ~ /^[0-9a-fA-F]+$/) printf "fn %s %s\n", sel, sig;
      }'
  forge inspect "$1" abi --json 2>/dev/null \
    | jq -r '
        .[] | select(.type=="event" or .type=="error") |
        (if .type=="event" then "ev " else "er " end)
        + .name + "(" + ([.inputs[].type] | join(",")) + ")"'
}

fail=0
for c in "${CONTRACTS[@]}"; do
  name="${c##*:}"
  # NB: extension is .abisig (not .abi) — the repo .gitignore has `*.abi` for
  # generated Foundry artifacts, which would otherwise exclude these baselines.
  baseline="$BASELINE_DIR/$name.abisig"
  new="$(mktemp)"
  fingerprint "$c" | sort -u > "$new"

  if [[ ! -s "$new" ]]; then
    echo "ERROR: could not read ABI for $c (build first with: make build)"
    fail=1; rm -f "$new"; continue
  fi

  if [[ "$UPDATE" == "1" ]]; then
    cp "$new" "$baseline"
    echo "updated $baseline ($(wc -l < "$baseline") entries)"
    rm -f "$new"; continue
  fi

  if [[ ! -f "$baseline" ]]; then
    echo "ERROR: no baseline for $name. Run: scripts/check-abi.sh --update"
    fail=1; rm -f "$new"; continue
  fi

  removed="$(comm -23 <(sort "$baseline") <(sort "$new") || true)"
  if [[ -n "$removed" ]]; then
    echo "ABI VIOLATION in $name (existing selector/signature removed or changed):"
    echo "$removed" | sed 's/^/    - /'
    fail=1
  else
    echo "ok   $name ($(wc -l < "$baseline") entries)"
  fi
  rm -f "$new"
done

if [[ "$fail" != "0" && "$UPDATE" != "1" ]]; then
  echo ""
  echo "ABI changed for a deployed contract. Removing/changing a selector or event"
  echo "breaks integrators. If intentional and additive only, re-baseline with:"
  echo "    scripts/check-abi.sh --update"
  exit 1
fi
exit 0
