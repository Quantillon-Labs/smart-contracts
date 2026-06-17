#!/usr/bin/env python3
"""Verify a Base contract on Etherscan/Basescan via the exact standard-json forge compiled with.
Needed because bytecode_hash="none" makes flattened/auto verification mismatch.
Usage: verify_stdjson.py <address> <source-substring> <ContractName> <ctorArgsHexNo0x>
Picks the build-info whose settings match the deploy profile (optimizer runs=0, viaIR, bytecodeHash none).
"""
import json, glob, sys, time, urllib.request, urllib.parse

addr, src_sub, cname, cargs = sys.argv[1], sys.argv[2], sys.argv[3], (sys.argv[4] if len(sys.argv) > 4 else "")

key = None
for line in open('.env'):
    line = line.strip()
    if line.startswith('ETHERSCAN_API_KEY='):
        key = line.split('=', 1)[1].strip().strip('"').strip("'"); break
if not key:
    sys.exit('no ETHERSCAN_API_KEY in .env')

chosen = None
for f in sorted(glob.glob('out/build-info/*.json')):
    try:
        d = json.load(open(f))
    except Exception:
        continue
    inp = d.get('input', {}); s = inp.get('settings', {})
    keys = [k for k in inp.get('sources', {}) if src_sub in k]
    if not keys:
        continue
    if s.get('optimizer', {}).get('runs') == 0 and s.get('viaIR') and s.get('metadata', {}).get('bytecodeHash') == 'none':
        chosen = (f, d, keys[0]); break
if not chosen:
    sys.exit('no matching build-info (runs=0/viaIR/bytecodeHash=none) containing ' + src_sub)

f, d, srckey = chosen
compiler = 'v' + d['solcLongVersion']
full_cname = srckey + ':' + cname
print('build-info:', f)
print('compiler  :', compiler)
print('contract  :', full_cname)
print('sources   :', len(d['input']['sources']))

payload = urllib.parse.urlencode({
    'apikey': key, 'module': 'contract', 'action': 'verifysourcecode',
    'contractaddress': addr, 'sourceCode': json.dumps(d['input']),
    'codeformat': 'solidity-standard-json-input', 'contractname': full_cname,
    'compilerversion': compiler, 'constructorArguements': cargs,
}).encode()
r = json.load(urllib.request.urlopen(urllib.request.Request('https://api.etherscan.io/v2/api?chainid=8453', data=payload), timeout=60))
print('submit    :', r)
if str(r.get('status')) != '1':
    sys.exit('submit failed: ' + str(r.get('result')))
guid = r['result']
for _ in range(20):
    time.sleep(8)
    q = urllib.parse.urlencode({'apikey': key, 'module': 'contract', 'action': 'checkverifystatus', 'guid': guid})
    res = json.load(urllib.request.urlopen('https://api.etherscan.io/v2/api?chainid=8453&' + q, timeout=30)).get('result', '')
    print('  status  :', res)
    if 'Pending' not in res:
        break
