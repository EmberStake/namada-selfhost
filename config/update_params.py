#!/usr/bin/env python3
import sys
import toml

params_file = sys.argv[1]
public_key = sys.argv[2]

params_toml = toml.load(params_file)
params_toml['pgf_params']['stewards'] = [public_key]
print(toml.dumps(params_toml))