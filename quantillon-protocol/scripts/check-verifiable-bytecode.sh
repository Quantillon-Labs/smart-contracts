#!/usr/bin/env bash
#
# Pre-deploy gate: will Basescan/Etherscan reproduce this contract's bytecode from the
# pruned standard-json that `forge verify-contract` submits?
#
# Under via_ir the optimized bytecode can depend on the FULL compilation unit. Forge
# prunes the unit to the contract's dependency closure at verification time, so the
# deploy-time compile (full unit, cached by `forge build`) and the verification-time
# compile (pruned unit, run by Etherscan) can diverge — seen on QuantillonVault v1.1.1
# (2026-07-04): ~67 bytes of drift, every verification attempt rejected. Other contracts
# (HedgerPool v1.0.2, QEUROToken v1.0.1) happened to be byte-stable; it is per-compile
# luck, so check every impl BEFORE deploying it:
#
#   ok   -> deploy normally; standard `forge verify-contract` will match.
#   FAIL -> deploy via scripts/deployment/build-verifiable-impl.sh instead, which
#           deploys the pruned-unit bytecode so verification matches by construction.
#
# Comparison is placeholder-to-placeholder (both sides unlinked), so library addresses
# play no part. Requires the project's pinned solc under ~/.svm (foundry installs it).
#
# Usage: scripts/check-verifiable-bytecode.sh <ContractName> [src-path]
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="${1:?usage: check-verifiable-bytecode.sh <ContractName> [src-path]}"
SRC="${2:-$(find src -name "$NAME.sol" -not -path '*/mocks/*' | head -1)}"
[[ -n "$SRC" && -f "$SRC" ]] || { echo "FAIL source file not found for $NAME"; exit 1; }

forge build >/dev/null 2>&1
ART="out/$(basename "$SRC")/$NAME.json"
[[ -f "$ART" ]] || { echo "FAIL artifact missing: $ART"; exit 1; }

PRUNED_JSON="$(mktemp --suffix=.json)"
trap 'rm -f "$PRUNED_JSON"' EXIT
forge verify-contract 0x0000000000000000000000000000000000000001 "$SRC:$NAME" \
  --show-standard-json-input > "$PRUNED_JSON" 2>/dev/null

python3 - "$ART" "$PRUNED_JSON" "$SRC" "$NAME" <<'PY'
import json, subprocess, sys, os
art_path, pruned_path, src, name = sys.argv[1:5]

art = json.load(open(art_path))
build_code = art["bytecode"]["object"].removeprefix("0x").lower()
solc_ver = art["metadata"]["compiler"]["version"]          # e.g. 0.8.24+commit.e11b9ed9
short = solc_ver.split("+")[0]
solc = os.path.expanduser(f"~/.svm/{short}/solc-{short}")
if not os.path.exists(solc):
    print(f"FAIL pinned solc not found at {solc}"); sys.exit(1)

inp = json.load(open(pruned_path))
inp["settings"]["outputSelection"] = {"*": {"*": ["evm.bytecode.object"]}}
out = subprocess.run([solc, "--standard-json"], input=json.dumps(inp),
                     capture_output=True, text=True)
res = json.loads(out.stdout)
errs = [e for e in res.get("errors", []) if e.get("severity") == "error"]
if errs:
    print("FAIL pruned-unit compile error:", errs[0].get("formattedMessage", errs[0])); sys.exit(1)

pruned_code = res["contracts"][src][name]["evm"]["bytecode"]["object"].lower()
n_sources = len(inp["sources"])

if build_code == pruned_code:
    print(f"ok   {name}: pruned verification unit ({n_sources} sources) byte-matches the "
          f"build artifact — deploy normally, standard verification will succeed")
    sys.exit(0)

n = min(len(build_code), len(pruned_code))
div = next((i for i in range(n) if build_code[i] != pruned_code[i]), n)
print(f"FAIL {name}: pruned verification unit ({n_sources} sources) DIVERGES from the "
      f"build artifact (first divergence at hex-char {div}; lengths "
      f"{len(build_code)} vs {len(pruned_code)}).")
print(f"     Deploying the build artifact would make Basescan verification impossible.")
print(f"     Deploy with: scripts/deployment/build-verifiable-impl.sh {name} "
      f"[--lib <FQN>=<addr>]... [--ctor-args <hex>] --deploy")
sys.exit(1)
PY
