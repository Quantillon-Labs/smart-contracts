#!/usr/bin/env bash
#
# Reports which deployed contracts are out of date relative to the current source version().
# Reads deployments/{chainId}/versions.json (the deployed-version manifest, maintained by the
# UpgradeBase scripts) and compares each recorded version against the version() literal in source.
#
# This is the automated answer to "which contracts need an upgrade?". It is a REPORT, not a hard
# gate (exit 0), unless --strict is passed (exit 1 when anything is out of date).
#
# Usage:
#   scripts/check-deployed-versions.sh [chainId] [--strict]   # default chainId 8453
#
set -euo pipefail
cd "$(dirname "$0")/.."

CHAIN_ID="8453"
STRICT=0
for a in "$@"; do
  case "$a" in
    --strict) STRICT=1 ;;
    [0-9]*) CHAIN_ID="$a" ;;
  esac
done

MANIFEST="deployments/$CHAIN_ID/versions.json"
if [[ ! -f "$MANIFEST" ]]; then
  echo "No manifest at $MANIFEST. Backfill it with scripts/deployment/backfill-versions.sh first."
  exit 0
fi

# name:sourcePath for the deployable contracts (must match check-version-bump.sh targets).
TARGETS=(
  "QEUROToken:src/core/QEUROToken.sol"
  "QuantillonVault:src/core/QuantillonVault.sol"
  "QTIToken:src/core/QTIToken.sol"
  "UserPool:src/core/UserPool.sol"
  "HedgerPool:src/core/HedgerPool.sol"
  "stQEUROToken:src/core/stQEUROToken.sol"
  "stQEUROFactory:src/core/stQEUROFactory.sol"
  "FeeCollector:src/core/FeeCollector.sol"
  "YieldShift:src/core/yieldmanagement/YieldShift.sol"
  "ChainlinkOracle:src/oracle/ChainlinkOracle.sol"
  "StorkOracle:src/oracle/StorkOracle.sol"
  "OracleRouter:src/oracle/OracleRouter.sol"
  "SlippageStorage:src/oracle/SlippageStorage.sol"
  "TimeProvider:src/libraries/TimeProviderLibrary.sol"
  "TimelockUpgradeable:src/core/TimelockUpgradeable.sol"
)

extract_version() { grep -oE '"[0-9]+\.[0-9]+\.[0-9]+[^"]*"' "$1" 2>/dev/null | head -1 | tr -d '"'; }

outdated=0
printf '%-22s %-14s %-14s %s\n' "CONTRACT" "DEPLOYED" "SOURCE" "STATUS"
for t in "${TARGETS[@]}"; do
  name="${t%%:*}"; path="${t##*:}"
  src_ver="$(extract_version "$path")"
  dep_ver="$(jq -r --arg n "$name" '.[$n].version // empty' "$MANIFEST")"
  if [[ -z "$dep_ver" ]]; then
    printf '%-22s %-14s %-14s %s\n' "$name" "-" "$src_ver" "no deployment record"
  elif [[ "$dep_ver" == "$src_ver" ]]; then
    printf '%-22s %-14s %-14s %s\n' "$name" "$dep_ver" "$src_ver" "up to date"
  else
    printf '%-22s %-14s %-14s %s\n' "$name" "$dep_ver" "$src_ver" "OUT OF DATE -> needs upgrade"
    outdated=1
  fi
done

if [[ "$STRICT" == "1" && "$outdated" == "1" ]]; then exit 1; fi
exit 0
