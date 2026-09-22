#!/usr/bin/env python3
"""Derive a signer address from PRIVATE_KEY in the environment, never argv."""
import os
import sys
try:
    from eth_account import Account
except ImportError:
    sys.exit('Install the project Python requirements or use a Foundry keystore account.')
try:
    address = Account.from_key(os.environ['PRIVATE_KEY'].strip().strip('\"\'')).address
except Exception:
    sys.exit('PRIVATE_KEY is missing or invalid.')
print(address)
