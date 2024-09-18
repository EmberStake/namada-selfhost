#!/usr/bin/env python3
import os
import sys
import toml
import json

validator_directory = sys.argv[1]
balances_toml = sys.argv[2]
output_toml_path = sys.argv[3]

balances_config = {}

# iterate over each validator config in the base directory
for subdir in os.listdir(validator_directory):
    alias = subdir
    subdir_path = os.path.join(validator_directory, subdir)

    if os.path.isdir(subdir_path):
        toml_files = [f for f in os.listdir(subdir_path) if f.endswith(".toml")]
        if len(toml_files) == 1:
            toml_file_path = os.path.join(subdir_path, toml_files[0])
            transactions_toml = toml.load(toml_file_path)
            try:
                address = transactions_toml['validator_account'][0]['address']
                balances_config[alias]= address
            except (KeyError, IndexError) as e:
                pass


with open(validator_directory + '/namada_addresses.json', 'r') as f:
    namada_addresses = json.load(f)
for account, address in namada_addresses.items():
    if account.endswith("validator"):
        continue
    balances_config[account] = address

output_toml = toml.load(balances_toml)
ACCOUNT_AMOUNT = "220000000000"
FAUCET_AMOUNT = "9123372036854000000"

for entry in balances_config:
    for token in output_toml['token']:
        if entry == 'faucet-1':
            output_toml['token'][token][balances_config[entry]] = FAUCET_AMOUNT
        else:
            output_toml['token'][token][balances_config[entry]] = ACCOUNT_AMOUNT

toml_content = toml.dumps(output_toml)
# Write the TOML content to the file
with open(output_toml_path, 'w') as file:
    file.write(toml_content)
