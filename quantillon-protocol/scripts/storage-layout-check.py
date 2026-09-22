#!/usr/bin/env python3
"""Compare complete compiler storage types without unstable AST identifiers."""
import argparse
import json
from pathlib import Path


def canonical_layout(layout):
    types = layout['types']
    def shape(key, stack=()):
        if key in stack:
            return {'recursive': types[key]['label']}
        value = types[key]
        out = {k: value[k] for k in ('encoding', 'label', 'numberOfBytes')}
        for child in ('key', 'value', 'base'):
            if child in value:
                out[child] = shape(value[child], (*stack, key))
        if 'members' in value:
            out['members'] = [{'member': m.get('label', ''), 'slot': str(m['slot']), 'offset': m['offset'],
                               'type': shape(m['type'], (*stack, key))} for m in value['members']]
        return out
    return {f"{entry['slot']}:{entry['offset']}": shape(entry['type']) for entry in layout['storage']}


def compare(before, after):
    return [key for key, value in before.items() if after.get(key) != value]


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('layout', type=Path)
    parser.add_argument('baseline', type=Path)
    parser.add_argument('--update', action='store_true')
    args = parser.parse_args()
    current = canonical_layout(json.loads(args.layout.read_text()))
    if args.update:
        if args.baseline.exists():
            changed = compare(json.loads(args.baseline.read_text()), current)
            if changed:
                raise SystemExit(f'Cannot overwrite incompatible storage baseline: {changed}')
        args.baseline.write_text(json.dumps(current, sort_keys=True, indent=2) + '\n')
    else:
        if not args.baseline.exists():
            raise SystemExit(f'Missing recursive storage baseline: {args.baseline}')
        changed = compare(json.loads(args.baseline.read_text()), current)
        if changed:
            raise SystemExit(f'Nested storage layout changed at {changed}: {args.baseline.name}')
