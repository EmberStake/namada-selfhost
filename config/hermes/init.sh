#!/bin/bash
#export CHAIN_A_ID="local.2888d38c45da22f49f06177e"
#export CHAIN_B_ID="local.eebaeaba77a3dc28f6a5d48f"

mkdir -p ~/.namada-shared/chain-a && mkdir -p ~/.namada-shared/chain-b

export CHAIN_A_ID=$(awk 'NR==2' /root/.namada-shared/chain.config)
export CHAIN_B_ID=$(awk 'NR==2' /root/.namada-shared/chain-b.config)
export HERMES_CONFIG=/root/.hermes/config.toml
# TODO : make relayer account on each chain init script
# TODO : share each chain wallet.toml for hermes e.g:
namadaw gen --alias relayer --unsafe-dont-encrypt
cp ~/.local/share/namada/$CHAIN_A_ID/wallet.toml ~/.namada-shared/chain-a/wallet.toml

namadaw gen --alias relayer --unsafe-dont-encrypt
cp ~/.local/share/namada/$CHAIN_B_ID/wallet.toml ~/.namada-shared/chain-b/wallet.toml

# TODO : fund relayer accounts
namadac transfer --source namada-1-wallet --target relayer --amount 500 --token NAM
namadac transfer --source chain-b-wallet --target relayer --amount 500 --token NAM


echo $CHAIN_A_ID
echo $CHAIN_B_ID

hermes --config $HERMES_CONFIG keys add --chain "$CHAIN_A_ID" --key-file /root/.namada-shared/chain-a/wallet.toml
hermes --config $HERMES_CONFIG keys add --chain "$CHAIN_B_ID" --key-file /root/.namada-shared/chain-b/wallet.toml
# TODO : update chain ids
# TODO : update nam address

hermes --config $HERMES_CONFIG start


hermes --config $HERMES_CONFIG \
  create channel \
  --a-chain $CHAIN_A_ID \
  --b-chain $CHAIN_B_ID \
  --a-port transfer \
  --b-port transfer \
  --new-client-connection --yes