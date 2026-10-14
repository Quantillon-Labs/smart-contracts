#!/usr/bin/env bash
# Rehearse a Forge script only against the isolated, running preprod fork.
set -euo pipefail
cd "$(dirname "$0")/.."
for arg in "$@"; do
  case "$arg" in
    --rpc-url*|--fork-url*|--chain*|-r) echo "Preprod RPC and chain cannot be overridden" >&2; exit 1 ;;
  esac
done
test "$(cast chain-id --rpc-url http://127.0.0.1:8550)" = 31338
set -a
source /etc/quantillon/preprod/contracts.env
set +a
exec forge script "$@" --rpc-url http://127.0.0.1:8550 --chain 31338
