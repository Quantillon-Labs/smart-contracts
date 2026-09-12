#!/usr/bin/env bash
# Split the complete test-file list deterministically across CI runners. Foundry
# 1.7.1 limits code generation to matching tests and their dependencies.
set -euo pipefail
cd "$(dirname "$0")/.."

index="${1:-}"
count="${2:-}"
if [[ ! "$index" =~ ^[0-9]+$ || ! "$count" =~ ^[1-9][0-9]*$ ]] || (( index >= count )); then
    echo "Usage: bash scripts/ci-test-shard.sh INDEX COUNT [FORGE_ARGS...] (0 <= INDEX < COUNT)" >&2
    exit 2
fi
shift 2

mapfile -t files < <(find test -type f -name '*.t.sol' | LC_ALL=C sort)
selected=()
for i in "${!files[@]}"; do
    if (( i % count == index )); then
        selected+=("${files[$i]}")
    fi
done
if (( ${#selected[@]} == 0 )); then
    echo "Shard $index/$count has no test files" >&2
    exit 2
fi

printf 'Shard %s/%s: %s of %s test files\n' "$index" "$count" "${#selected[@]}" "${#files[@]}"
printf '  %s\n' "${selected[@]}"
pattern=$(IFS=,; echo "${selected[*]}")
if (( ${#selected[@]} > 1 )); then
    pattern="{$pattern}"
fi
FOUNDRY_PROFILE=test forge test --match-path "$pattern" "$@"
