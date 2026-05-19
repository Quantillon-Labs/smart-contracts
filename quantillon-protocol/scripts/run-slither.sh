#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

source "$(dirname "${BASH_SOURCE[0]}")/utils/load-env.sh"
setup_environment --allow-missing

if [ ! -d "venv" ]; then
    python3 -m venv venv
fi

source venv/bin/activate
pip install -r requirements.txt >/dev/null

if [[ "$RESULTS_DIR" = /* ]]; then
    RESULTS_DIR_ABS="$RESULTS_DIR"
else
    RESULTS_DIR_ABS="$ROOT_DIR/$RESULTS_DIR"
fi

SLITHER_DIR="$RESULTS_DIR_ABS/slither"
mkdir -p "$SLITHER_DIR"

CHECKLIST_FILE="$SLITHER_DIR/slither-checklist.txt"
IGNORED_FILE="$SLITHER_DIR/slither-ignored-checklist.txt"
REPORT_JSON="$SLITHER_DIR/slither-report.json"
REPORT_IGNORED_JSON="$SLITHER_DIR/slither-report-ignored.json"
IGNORED_ONLY_JSON="$SLITHER_DIR/slither-ignored.json"
REPORT_SARIF="$SLITHER_DIR/slither-report.sarif"
ANALYSIS_FILE="$SLITHER_DIR/slither-analysis.json"
UNRESOLVED_FILE="$SLITHER_DIR/slither-unresolved.json"
EXCLUDED_FILE="$SLITHER_DIR/slither-excluded.json"
SUPPRESSED_FILE="$SLITHER_DIR/slither-suppressed.txt"
REPORT_TXT="$SLITHER_DIR/slither-report.txt"

IN_SCOPE_JSON='["arbitrary-send-eth","reentrancy-no-eth","unused-return","missing-zero-check","reentrancy-benign","timestamp","low-level-calls","costly-loop","cyclomatic-complexity"]'
IN_SCOPE_DETECTORS="arbitrary-send-eth,reentrancy-no-eth,unused-return,missing-zero-check,reentrancy-benign,timestamp,low-level-calls,costly-loop,cyclomatic-complexity"
SLITHER_SCOPE_ARGS=(--config-file slither.config.json --exclude-dependencies --detect "$IN_SCOPE_DETECTORS")

# Slither refuses to overwrite existing report files; ensure a fresh run each time.
rm -f "$CHECKLIST_FILE" "$IGNORED_FILE" "$REPORT_JSON" "$REPORT_IGNORED_JSON" "$IGNORED_ONLY_JSON" "$REPORT_SARIF" \
      "$ANALYSIS_FILE" "$UNRESOLVED_FILE" "$EXCLUDED_FILE" "$SUPPRESSED_FILE" "$REPORT_TXT"

echo "[slither] running checklist (main scope)..."
MAIN_CHECKLIST_EXIT=0
slither . "${SLITHER_SCOPE_ARGS[@]}" --checklist 2>&1 | tee "$CHECKLIST_FILE" || MAIN_CHECKLIST_EXIT=$?

# Main machine-readable outputs use non-ignored findings.
JSON_EXIT=0
mkdir -p "$SLITHER_DIR"
slither . "${SLITHER_SCOPE_ARGS[@]}" --json "$REPORT_JSON" || JSON_EXIT=$?
if [ ! -s "$REPORT_JSON" ]; then
    echo "[slither] failed to produce JSON report: $REPORT_JSON"
    deactivate
    exit 2
fi

SARIF_EXIT=0
mkdir -p "$SLITHER_DIR"
slither . "${SLITHER_SCOPE_ARGS[@]}" --sarif "$REPORT_SARIF" || SARIF_EXIT=$?

# Optional appendix with ignored findings (for auditability only, never used for gating).
IGNORED_JSON_EXIT=0
mkdir -p "$SLITHER_DIR"
slither . "${SLITHER_SCOPE_ARGS[@]}" --show-ignored-findings --json "$REPORT_IGNORED_JSON" || IGNORED_JSON_EXIT=$?
if [ ! -s "$REPORT_IGNORED_JSON" ]; then
    mkdir -p "$SLITHER_DIR"
    echo '{"results":{"detectors":[]}}' > "$REPORT_IGNORED_JSON"
fi

jq --argjson in_scope "$IN_SCOPE_JSON" '
[
  (.results.detectors // [])[]
  | select((.check as $c | $in_scope | index($c)) != null)
  | {
      id: .id,
      check: .check,
      impact: .impact,
      confidence: .confidence,
      description: (.description | split("\\n")[0]),
      location: (.first_markdown_element // ""),
      file: ((.first_markdown_element // "" | split("#")[0]))
    }
]
' "$REPORT_JSON" > "$ANALYSIS_FILE"

jq -n \
  --slurpfile all "$REPORT_IGNORED_JSON" \
  --slurpfile visible "$REPORT_JSON" '
def flatten($doc):
  [
    (($doc.results.detectors // [])[])
    | {
        check: .check,
        impact: .impact,
        confidence: .confidence,
        description: (.description | split("\\n")[0]),
        location: (.first_markdown_element // ""),
        file: ((.first_markdown_element // "" | split("#")[0])),
        key: (.check + "|" + (.first_markdown_element // "") + "|" + (.description | split("\\n")[0]))
      }
  ];
(flatten($all[0])) as $all_entries
| (flatten($visible[0]) | map(.key)) as $visible_keys
| [
    $all_entries[]
    | . as $entry
    | select(($visible_keys | index($entry.key)) == null)
    | del(.key)
  ]
' > "$IGNORED_ONLY_JSON"

jq '[.[] | select(.file | startswith("src/")) | select(.file | startswith("src/mocks/") | not)]' "$ANALYSIS_FILE" > "$UNRESOLVED_FILE"
jq '[.[] | select((.file | startswith("lib/")) or (.file | startswith("src/mocks/")) or (.file | startswith("src/") | not))]' "$ANALYSIS_FILE" > "$EXCLUDED_FILE"
jq '[.[] | select(.file | startswith("src/")) | select(.file | startswith("src/mocks/") | not)]' "$IGNORED_ONLY_JSON" > "$IGNORED_ONLY_JSON.tmp" && mv "$IGNORED_ONLY_JSON.tmp" "$IGNORED_ONLY_JSON"

rg -n "slither-disable-(start|next-line) (arbitrary-send-eth|reentrancy-no-eth|unused-return|missing-zero-check|reentrancy-benign|timestamp|low-level-calls|costly-loop|cyclomatic-complexity)" src > "$SUPPRESSED_FILE" || true

UNRESOLVED_COUNT=$(jq 'length' "$UNRESOLVED_FILE")
EXCLUDED_COUNT=$(jq 'length' "$EXCLUDED_FILE")
IGNORED_COUNT=$(jq 'length' "$IGNORED_ONLY_JSON")
SUPPRESSED_COUNT=$(wc -l < "$SUPPRESSED_FILE" | tr -d ' ')

UNRESOLVED_HIGH=$(jq '[.[] | select(.impact == "High")] | length' "$UNRESOLVED_FILE")
UNRESOLVED_MEDIUM=$(jq '[.[] | select(.impact == "Medium")] | length' "$UNRESOLVED_FILE")
UNRESOLVED_LOW=$(jq '[.[] | select(.impact == "Low")] | length' "$UNRESOLVED_FILE")
UNRESOLVED_INFO=$(jq '[.[] | select(.impact == "Informational")] | length' "$UNRESOLVED_FILE")

{
    echo "SLITHER SECURITY ANALYSIS REPORT"
    echo "Generated: $(date -Iseconds)"
    echo "Configuration: slither.config.json"
    echo
    echo "EXECUTIVE SUMMARY"
    echo "Unresolved (in-scope, production src/*): $UNRESOLVED_COUNT"
    echo "- High: $UNRESOLVED_HIGH"
    echo "- Medium: $UNRESOLVED_MEDIUM"
    echo "- Low: $UNRESOLVED_LOW"
    echo "- Informational: $UNRESOLVED_INFO"
    echo "Suppressed (source annotations): $SUPPRESSED_COUNT"
    echo "Excluded (dependencies/mocks/non-src): $EXCLUDED_COUNT"
    echo "Ignored (show-ignored delta, production src/*): $IGNORED_COUNT"
    echo
    echo "UNRESOLVED"
    if [ "$UNRESOLVED_COUNT" -eq 0 ]; then
        echo "- none"
    else
        jq -r '.[] | "- [" + .check + "] (" + .impact + "/" + .confidence + ") " + .description + " @ " + .location' "$UNRESOLVED_FILE"
    fi
    echo
    echo "SUPPRESSED"
    if [ "$SUPPRESSED_COUNT" -eq 0 ]; then
        echo "- none"
    else
        sed 's/^/- /' "$SUPPRESSED_FILE"
    fi
    echo
    echo "IGNORED"
    if [ "$IGNORED_COUNT" -eq 0 ]; then
        echo "- none"
    else
        jq -r '.[] | "- [" + .check + "] (" + .impact + "/" + .confidence + ") " + .description + " @ " + .location' "$IGNORED_ONLY_JSON"
    fi
    echo
    echo "EXCLUDED"
    if [ "$EXCLUDED_COUNT" -eq 0 ]; then
        echo "- none"
    else
        jq -r '.[] | "- [" + .check + "] (" + .impact + "/" + .confidence + ") " + .description + " @ " + .location' "$EXCLUDED_FILE"
    fi
    echo
    echo "APPENDIX"
    echo "- Checklist output: $CHECKLIST_FILE"
    echo "- Ignored findings checklist: $IGNORED_FILE"
    echo "- Ignored findings delta JSON: $IGNORED_ONLY_JSON"
    echo "- Raw show-ignored JSON: $REPORT_IGNORED_JSON"
    echo "- JSON report: $REPORT_JSON"
    echo "- SARIF report: $REPORT_SARIF"
} > "$REPORT_TXT"

{
    echo "SLITHER IGNORED FINDINGS CHECKLIST"
    echo "Generated: $(date -Iseconds)"
    echo "Scope: in-scope detectors only, production src/* (excluding src/mocks/*)"
    echo
    if [ "$IGNORED_COUNT" -eq 0 ]; then
        echo "- none"
    else
        jq -r '.[] | "- [" + .check + "] (" + .impact + "/" + .confidence + ") " + .description + " @ " + .location' "$IGNORED_ONLY_JSON"
    fi
    echo
    echo "Raw show-ignored JSON: $REPORT_IGNORED_JSON"
    echo "Visible JSON: $REPORT_JSON"
} > "$IGNORED_FILE"

cat "$REPORT_TXT"

# Gate CI only on unresolved in-scope production findings.
if [ "$UNRESOLVED_COUNT" -gt 0 ]; then
    echo "[slither] unresolved in-scope findings detected: $UNRESOLVED_COUNT"
    deactivate
    exit 1
fi

# Keep informational visibility from checklist exit code without failing when scope is clean.
if [ "$MAIN_CHECKLIST_EXIT" -ne 0 ]; then
    echo "[slither] checklist produced findings outside unresolved scope"
fi
if [ "$JSON_EXIT" -ne 0 ]; then
    echo "[slither] json export returned non-zero (findings present), report still generated"
fi
if [ "$SARIF_EXIT" -ne 0 ]; then
    echo "[slither] sarif export returned non-zero (findings present), report still generated"
fi
if [ "$IGNORED_JSON_EXIT" -ne 0 ]; then
    echo "[slither] show-ignored json export returned non-zero (findings present), report still generated"
fi

deactivate
echo "[slither] completed: no unresolved in-scope production findings"
