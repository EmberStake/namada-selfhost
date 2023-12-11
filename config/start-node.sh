#!/bin/bash

# TODO: set chain-prefix by env var

namada --version

# clean up the http server when the script exits
cleanup() {
    pkill -f "/serve"
}

export PUBLIC_IP=$(ip a | grep -oE 'inet ([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2} brd ([0-9]{1,3}\.){3}[0-9]{1,3}' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d '/' -f1)
export ALIAS=$(hostname)
export TX_FILE_PATH="/root/.local/share/namada/pre-genesis/transactions.toml"

if [ ! -f "/root/.namada-shared/chain.config" ]; then
  # generate validator keys
  WALLET_KEY="$ALIAS-wallet"
  # generate account
  namadaw --pre-genesis key gen --alias $WALLET_KEY --unsafe-dont-encrypt
  # generate established account
  ESTABLISHED_ACC_OUTPUT=$(namadac utils init-genesis-established-account --path $TX_FILE_PATH --aliases $WALLET_KEY)
  echo "$ESTABLISHED_ACC_OUTPUT"
  ESTABLISHED_ACCOUNT_ADDRESS=$(echo "$ESTABLISHED_ACC_OUTPUT" | grep -o 'tnam[[:alnum:]]*')

  namadac utils init-genesis-validator \
    --address $ESTABLISHED_ACCOUNT_ADDRESS \
    --alias $ALIAS \
    --net-address "${PUBLIC_IP}:26656" \
    --commission-rate 0.05 \
    --max-commission-rate-change 0.01 \
    --self-bond-amount 1000000 \
    --email "$ALIAS@namada.net" \
    --path $TX_FILE_PATH \
    --unsafe-dont-encrypt

  # Pre-genesis toml is written to /root/.local/share/namada/pre-genesis/namada-x/transactions.toml
  mkdir -p /root/.namada-shared/$ALIAS

  # Sign validators transactions file
  namadac utils sign-genesis-txs \
      --path $TX_FILE_PATH \
      --output /root/.local/share/namada/pre-genesis/signed-transactions.toml \
      --alias $ALIAS

  cp -a /root/.local/share/namada/pre-genesis/signed-transactions.toml /root/.namada-shared/$ALIAS/transactions.toml
fi

############  generating chain configs, done on host namada-1 only ############
if [ $(hostname) = "namada-1" ]; then

  if [ ! -f "/root/.namada-shared/chain.config" ]; then
    # wait until all validator configs have been written
    while [ ! -d "/root/.namada-shared/namada-1" ] || [ ! -d "/root/.namada-shared/namada-2" ] || [ ! -d "/root/.namada-shared/namada-3" ]; do
      echo "Validator configs not ready. Sleeping for 5s..."
      sleep 5
    done

    echo "Validator configs found. Generating chain configs..."

    # create a pgf steward account with alias 'steward-1' and generate signed toml
    STEWARD_ALIAS="steward-1"
    namadaw --pre-genesis key gen --alias $STEWARD_ALIAS --unsafe-dont-encrypt
#
#    STEWARD_PK=$(namadaw --pre-genesis key find --alias $STEWARD_ALIAS | awk -F ' ' 'NR == 2 {print $3}')
#    mkdir /root/.namada-shared/$STEWARD_ALIAS
#    cp /genesis/blank_account.toml /root/.namada-shared/$STEWARD_ALIAS/unsigned.toml
#    sed -i "s#ALIAS#$STEWARD_ALIAS#g" /root/.namada-shared/$STEWARD_ALIAS/unsigned.toml
#    sed -i "s#AMOUNT#1000000000#g" /root/.namada-shared/$STEWARD_ALIAS/unsigned.toml
#    sed -i "s#PUBLIC_KEY#$STEWARD_PK#g" /root/.namada-shared/$STEWARD_ALIAS/unsigned.toml
#    namadac utils sign-genesis-txs --path /root/.namada-shared/$STEWARD_ALIAS/unsigned.toml --output /root/.namada-shared/$STEWARD_ALIAS/transactions.toml
#    rm /root/.namada-shared/$STEWARD_ALIAS/unsigned.toml

    # create a pgf steward account with alias 'steward-1' and generate signed toml
    FAUCET_ALIAS="faucet-1"
    namadaw --pre-genesis key gen --alias $FAUCET_ALIAS --unsafe-dont-encrypt
#
#    FAUCET_PK=$(namadaw --pre-genesis key find --alias $FAUCET_ALIAS | awk -F ' ' 'NR == 2 {print $3}')
#    mkdir /root/.namada-shared/$FAUCET_ALIAS
#    cp /genesis/blank_account.toml /root/.namada-shared/$FAUCET_ALIAS/unsigned.toml
#    sed -i "s#ALIAS#$FAUCET_ALIAS#g" /root/.namada-shared/$FAUCET_ALIAS/unsigned.toml
#    sed -i "s#AMOUNT#9123372036854000000#g" /root/.namada-shared/$FAUCET_ALIAS/unsigned.toml
#    sed -i "s#PUBLIC_KEY#$FAUCET_PK#g" /root/.namada-shared/$FAUCET_ALIAS/unsigned.toml
#    namadac utils sign-genesis-txs --path /root/.namada-shared/$FAUCET_ALIAS/unsigned.toml --output /root/.namada-shared/$FAUCET_ALIAS/transactions.toml
#    rm /root/.namada-shared/$FAUCET_ALIAS/unsigned.toml

    # create directory for genesis toml files
    mkdir -p /root/.namada-shared/genesis
    cp /genesis/parameters.toml /root/.namada-shared/genesis/parameters.toml
    cp /genesis/tokens.toml /root/.namada-shared/genesis/tokens.toml
    cp /genesis/validity-predicates.toml /root/.namada-shared/genesis/validity-predicates.toml
    cp /genesis/transactions.toml /root/.namada-shared/genesis/transactions.toml
    # TODO arash: remove this line, this should be populated in python script
    cp /genesis/balances.toml /root/.namada-shared/genesis/balances.toml

    # add genesis transactions to transactions.toml
    # TODO: move to python script
    cat /root/.namada-shared/namada-1/transactions.toml >> /root/.namada-shared/genesis/transactions.toml
    cat /root/.namada-shared/namada-2/transactions.toml >> /root/.namada-shared/genesis/transactions.toml
    cat /root/.namada-shared/namada-3/transactions.toml >> /root/.namada-shared/genesis/transactions.toml
#    cat /root/.namada-shared/$STEWARD_ALIAS/transactions.toml >> /root/.namada-shared/genesis/transactions.toml
#    cat /root/.namada-shared/$FAUCET_ALIAS/transactions.toml >> /root/.namada-shared/genesis/transactions.toml

    # python script to read validator/bertha pk's from their toml files, and add them to the balances.toml
    python3 /scripts/make_balances.py /root/.namada-shared /genesis/balances.toml > /root/.namada-shared/genesis/balances.toml

    INIT_OUTPUT=$(namadac utils init-network \
      --genesis-time "2023-12-11T00:00:00Z" \
      --wasm-checksums-path /wasm/checksums.json \
      --chain-prefix local \
      --templates-path /root/.namada-shared/genesis \
      --consensus-timeout-commit 10s)

    echo "$INIT_OUTPUT"
    CHAIN_ID=$(echo "$INIT_OUTPUT" \
      | grep 'Derived chain ID:' \
      | awk '{print $4}')
    echo "Chain id: $CHAIN_ID"
  fi

  # serve config tar over http
  echo "Serving configs..."
  mkdir -p /serve
  cp *.tar.gz /serve
  trap cleanup EXIT
  nohup bash -c "python3 -m http.server --directory /serve 8123 &"

  if [ ! -f "/root/.namada-shared/chain.config" ]; then
    # write config server info to shared volume
    sleep 2
    printf "%b\n%b" "$PUBLIC_IP" "$CHAIN_ID" | tee /root/.namada-shared/chain.config
  fi

### end namada-1 specific prep ###

### other nodes should pause here until chain configs are ready ###
else
  while [ ! -f "/root/.namada-shared/chain.config" ]; do
    echo "Configs server info not ready. Sleeping for 5s..."
    sleep 5
  done

  echo "Configs server info found, proceeding with network setup"
fi

############ all nodes resume here ############

# one last sleep to make sure configs server has been given time to start
sleep 5

# get chain config server info
CONFIG_IP=$(awk 'NR==1' /root/.namada-shared/chain.config)
export CHAIN_ID=$(awk 'NR==2' /root/.namada-shared/chain.config)
export NAMADA_NETWORK_CONFIGS_SERVER="http://namada-1:8123"
curl $NAMADA_NETWORK_CONFIGS_SERVER
rm -rf /root/.local/share/namada/$CHAIN_ID
namadac utils join-network \
  --chain-id $CHAIN_ID --genesis-validator $ALIAS --dont-prefetch-wasm

# copy wasm to namada dir
cp -a /wasm/*.wasm /root/.local/share/namada/$CHAIN_ID/wasm
cp -a /wasm/checksums.json /root/.local/share/namada/$CHAIN_ID/wasm

# configure namada-1 node to advertise host public ip to outside peers if provided
EXTIP=${EXTIP:-''}
if [ -n "$EXTIP" ]; then
echo "Advertising public ip $EXTIP"
  sed -i "s#external_address = \".*\"#external_address = \"$EXTIP:${P2P_PORT:-26656}\"#g" /root/.local/share/namada/$CHAIN_ID/config.toml
fi

  sed -i "s#laddr = \"tcp://.*:26657\"#laddr = \"tcp://0.0.0.0:26657\"#g" /root/.local/share/namada/$CHAIN_ID/config.toml
  sed -i "s#cors_allowed_origins = .*#cors_allowed_origins = [\"*\"]#g" /root/.local/share/namada/$CHAIN_ID/config.toml
  sed -i "s#prometheus = .*#prometheus = true#g" /root/.local/share/namada/$CHAIN_ID/config.toml
  sed -i "s#namespace = .*#namespace = \"tendermint\"#g" /root/.local/share/namada/$CHAIN_ID/config.toml


if [ $(hostname) = "namada-1" ]; then
rm -f /root/.namada-shared/tokens-addresses
namadaw --pre-genesis address find --alias nam | grep -o 'tnam[^ ]*' >> /root/.namada-shared/tokens-addresses
namadaw --pre-genesis address find --alias eth | grep -o 'tnam[^ ]*' >> /root/.namada-shared/tokens-addresses
fi
# start node
NAMADA_LOG=info CMT_LOG_LEVEL=p2p:none,pex:error NAMADA_CMT_STDOUT=true namada node ledger run
