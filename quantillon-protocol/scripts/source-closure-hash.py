#!/usr/bin/env python3
"""Deterministic Solidity import-closure digest, including remapped dependencies."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
IMPORT = re.compile(r'\bimport\s+(?:[^;]*?\sfrom\s*)?["\']([^"\']+)["\']\s*;', re.S)

def digest(source, ref=None):
    remappings = []
    for line in subprocess.check_output(['forge', 'remappings'], cwd=ROOT, text=True).splitlines():
        prefix, target = line.split('=', 1)
        # Foundry context-qualified remappings use context:prefix=target.
        context, _, prefix = prefix.rpartition(':')
        remappings.append((context, prefix, target))
    seen = {}
    pending = [(ROOT / source).resolve()]
    while pending:
        path = pending.pop()
        if path in seen:
            continue
        if not path.is_relative_to(ROOT):
            raise ValueError(f'import leaves project: {path}')
        relative = path.relative_to(ROOT).as_posix()
        if ref and relative.startswith('src/'):
            data = subprocess.check_output(['git', 'show', f'{ref}:quantillon-protocol/{relative}'], cwd=ROOT)
        else:
            data = path.read_bytes()
        seen[path] = hashlib.sha256(data).hexdigest()
        # Remove comments before parsing imports; import forms may span multiple lines.
        content = re.sub(r'/\*.*?\*/|//[^\n]*', '', data.decode(), flags=re.S)
        for imported in IMPORT.findall(content):
            if imported.startswith('.'):
                dependency = path.parent / imported
            else:
                matches = [(len(prefix), prefix, target) for context, prefix, target in remappings
                           if imported.startswith(prefix) and (not context or relative.startswith(context))]
                if matches:
                    _, prefix, target = max(matches)
                    dependency = ROOT / target / imported[len(prefix):]
                else:
                    dependency = ROOT / imported
            pending.append(dependency.resolve())
    manifest = {p.relative_to(ROOT).as_posix(): value for p, value in seen.items()}
    return hashlib.sha256(json.dumps(manifest, sort_keys=True, separators=(',', ':')).encode()).hexdigest()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source')
    parser.add_argument('--git-ref')
    args = parser.parse_args()
    print('closure-v1:' + digest(args.source, args.git_ref))
