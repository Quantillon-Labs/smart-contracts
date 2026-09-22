#!/usr/bin/env python3
"""Keep assembly-backed storage anchors and schemas in an append-only registry."""
import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / 'storage-layout/namespaces.json'

def compact(value):
    return re.sub(r'\s+', ' ', value).strip()

def inventory():
    result = {}
    paths = [*ROOT.glob('src/**/*.sol'), *ROOT.glob('lib/openzeppelin-contracts-upgradeable/contracts/**/*.sol')]
    for path in paths:
        if 'mocks' in path.parts:
            continue
        code = re.sub(r'/\*.*?\*/|//[^\n]*', '', path.read_text(), flags=re.S)
        if not re.search(r'\.slot\s*:=|\bsload\s*\(|\bsstore\s*\(', code):
            continue
        prefix = path.relative_to(ROOT).as_posix()
        anchors = re.findall(r'bytes32\s+(?:(?:private|public|internal|constant)\s+)+(\w+)\s*=\s*(.*?);', code, re.S)
        anchors = [(name, compact(expr)) for name, expr in anchors if re.search(r'slot|storage', name, re.I)]
        if not anchors:
            raise ValueError(f'Assembly storage needs an explicit reviewed anchor: {prefix}')
        for name, expr in anchors:
            result[f'{prefix}:anchor:{name}'] = expr
        for name, fields in re.findall(r'\bstruct\s+(\w+)\s*\{([^}]+)\}', code, re.S):
            result[f'{prefix}:struct:{name}'] = compact(fields)
        # Preserve each local slot binding, as well as the structs and constants it selects.
        for index, binding in enumerate(re.findall(r'bytes32\s+\w+\s*=\s*\w+\s*;', code)):
            result[f'{prefix}:binding:{index}'] = compact(binding)
        for index, expression in enumerate(re.findall(r'[\w$]+\.slot\s*:=\s*[^\n}]+|\b(?:sload|sstore)\s*\([^\n}]+', code)):
            result[f'{prefix}:assembly:{index}'] = compact(expression)
    return result

def violations(old, current):
    return [key for key, value in old.items() if current.get(key) != value]

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--update', action='store_true')
    args = parser.parse_args()
    current = inventory()
    old = json.loads(REGISTRY.read_text()) if REGISTRY.exists() else {}
    changed = violations(old, current)
    if changed:
        raise SystemExit('Reserved storage definitions cannot change or disappear: '+', '.join(changed))
    if args.update:
        REGISTRY.write_text(json.dumps(current, sort_keys=True, indent=2)+'\n')
    elif current != old:
        raise SystemExit('New storage definitions require reviewed registry additions (--update)')
    print(f'Assembly storage registry: {len(current)} definitions preserved')
