#!/usr/bin/env python3
import sys
import toml
import os
import re

network_config = toml.load(sys.argv[2])

validator_configs = []
validator_directory = sys.argv[1]

# iterate over each validator config in the base directory
for subdir in os.listdir(validator_directory):
  alias = subdir
  subdir_path = os.path.join(validator_directory, subdir)

  if os.path.isdir(subdir_path):
    toml_files = [f for f in os.listdir(subdir_path) if f.endswith(".toml")]
    if len(toml_files) == 1:
      toml_file_path = os.path.join(subdir_path, toml_files[0])
      validator_config = toml.load(toml_file_path)
      validator_config['validator'][alias]['tokens'] = 100000
      validator_config['validator'][alias]['non_staked_balance'] = 100000
      validator_config['validator'][alias]['validator_vp'] = 'vp_validator'
      validator_config['validator'][alias]['staking_reward_vp'] = 'vp_user'
      validator_configs.append(validator_config['validator'])

# add each validator config to the genesis toml
network_config['validator'] = {}
for validator_config in validator_configs:
    network_config['validator'].update(validator_config)

# replace the public key references in NAM.balances to match aliases
key_replacements = {
    "validator-1.public_key": "namada-1.public_key",
    "validator-2.public_key": "namada-2.public_key",
    "validator-3.public_key": "namada-3.public_key"
}

for key in key_replacements:
    value = network_config['token']['NAM']['balances'].get(key)

    if value is not None:
        del network_config['token']['NAM']['balances'][key]
        network_config['token']['NAM']['balances'][key_replacements[key]] = value

# populate tx and vp whitelists from the wasm folder
wasm_dir = "/wasm"
vp_whitelist = []
tx_whitelist = []

# iterate over the files in the wasm directory
for filename in os.listdir(wasm_dir):
    file_path = os.path.join(wasm_dir, filename)

    if os.path.isfile(file_path):
        file_name, file_ext = os.path.splitext(filename)
        checksum = re.search(r'\.([a-f0-9]+)\.', filename)

        if checksum:
            checksum = checksum.group(1)

            if file_name.startswith("vp_"):
                vp_whitelist.append(checksum)
            elif file_name.startswith("tx_"):
                tx_whitelist.append(checksum)

# update the whitelist arrays
network_config['parameters']['vp_whitelist'] = vp_whitelist
network_config['parameters']['tx_whitelist'] = tx_whitelist

print(toml.dumps(network_config))
