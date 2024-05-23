#!/usr/bin/env python3
import sys
import toml

params_file = sys.argv[1]
public_key = sys.argv[2]
output_toml_path = sys.argv[3]

params_toml = toml.load(params_file)
params_toml['pgf_params']['stewards'] = [public_key]

toml_content = toml.dumps(params_toml)
# Write the TOML content to the file
with open(output_toml_path, 'w') as file:
    file.write(toml_content)
print(toml_content)