#!/bin/bash

namada --version

# clean up the http server when the script exits
cleanup() {
  pkill -f "/serve"
  pkill -f "python3 -m http.server --directory /root/.local/share/namada"
}
generate_chain_configs() {
  # check if configs are already generated, prevent running them again if containers are restarted
    if [ ! -f "/root/.namada-shared/chain.config" ]; then
      # wait until all validator configs have been written
      while [ ! -d "/root/.namada-shared/namada-1" ] || [ ! -d "/root/.namada-shared/namada-2" ] || [ ! -d "/root/.namada-shared/namada-3" ]; do
        echo "Validator configs not ready. Sleeping for 5s..."
        sleep 5
      done

      echo "Validator configs found. Generating chain configs..."

      # create a pgf steward account with alias 'steward-1' and generate signed toml
      STEWARD_ALIAS="steward-1"
      namadaw --pre-genesis gen --alias $STEWARD_ALIAS --unsafe-dont-encrypt

      # generate established account for steward-1
      mkdir -p /root/.namada-shared/$STEWARD_ALIAS

      STEWARD_ESTABLISHED=$(namadac utils init-genesis-established-account --path /root/.namada-shared/$STEWARD_ALIAS/transactions.toml --aliases $STEWARD_ALIAS)
      STEWARD_TNAM=$(echo "$STEWARD_ESTABLISHED" | grep -o 'tnam[[:alnum:]]*')

      # create a faucet account
      FAUCET_ALIAS="faucet-1"
      namadaw --pre-genesis gen --alias $FAUCET_ALIAS --unsafe-dont-encrypt
      mkdir /root/.namada-shared/$FAUCET_ALIAS
      namadac utils init-genesis-established-account --path /root/.namada-shared/$FAUCET_ALIAS/transactions.toml --aliases $FAUCET_ALIAS

      # create a relayer account
      RELAYER_ALIAS="relayer"
      namadaw --pre-genesis gen --alias $RELAYER_ALIAS --unsafe-dont-encrypt
      mkdir /root/.namada-shared/$RELAYER_ALIAS
      namadac utils init-genesis-established-account --path /root/.namada-shared/$RELAYER_ALIAS/transactions.toml --aliases $RELAYER_ALIAS

      # create directory for genesis toml files
      mkdir -p /root/.namada-shared/genesis
      # copy genesis templates from mounted files
      cp /genesis/tokens.toml /root/.namada-shared/genesis/tokens.toml
      cp /genesis/validity-predicates.toml /root/.namada-shared/genesis/validity-predicates.toml
      cp /genesis/transactions.toml /root/.namada-shared/genesis/transactions.toml

      # make a copy of wallet to namada folder for convenience (access to faucet account keys)
      cp -a /root/.local/share/namada/pre-genesis/wallet.toml /root/.local/share/namada/wallet.toml
      # add all signed genesis transactions to a final transactions.toml
      # TODO: move to python script
      cat /root/.namada-shared/namada-1/transactions.toml >>/root/.namada-shared/genesis/transactions.toml
      cat /root/.namada-shared/namada-2/transactions.toml >>/root/.namada-shared/genesis/transactions.toml
      cat /root/.namada-shared/namada-3/transactions.toml >>/root/.namada-shared/genesis/transactions.toml
      cat /root/.namada-shared/$STEWARD_ALIAS/transactions.toml >>/root/.namada-shared/genesis/transactions.toml
      cat /root/.namada-shared/$FAUCET_ALIAS/transactions.toml >>/root/.namada-shared/genesis/transactions.toml
      cat /root/.namada-shared/$RELAYER_ALIAS/transactions.toml >>/root/.namada-shared/genesis/transactions.toml

      python3 /scripts/make_balances.py /root/.namada-shared /genesis/balances.toml /root/.namada-shared/genesis/balances.toml
      python3 /scripts/update_params.py /genesis/parameters.toml "$STEWARD_TNAM" /root/.namada-shared/genesis/parameters.toml


      genesis_time=$(date -d "+${GENESIS_DELAY} seconds" +"%Y-%m-%dT%H:%M:%SZ")

      INIT_OUTPUT=$(namadac utils init-network \
        --genesis-time "$genesis_time" \
        --wasm-checksums-path /wasm/checksums.json \
        --chain-prefix local \
        --templates-path /root/.namada-shared/genesis \
        --consensus-timeout-commit 10s)

      echo "$INIT_OUTPUT"
      CHAIN_ID=$(echo "$INIT_OUTPUT" |
        grep 'Derived chain ID:' |
        awk '{print $4}')
      echo "Chain id: $CHAIN_ID"

      #
      sleep 3
      # write config server info to shared volume
      printf "%s\n" "$CHAIN_ID" | tee /root/.namada-shared/chain.config

    fi

    # serve config tar over http
    echo "Serving configs..."
    mkdir -p /serve
    cp *.tar.gz /serve
    trap cleanup EXIT
    nohup bash -c "python3 -m http.server --directory /serve 8123 &"
}

export PUBLIC_IP=$(ip a | grep -oE 'inet ([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2} brd ([0-9]{1,3}\.){3}[0-9]{1,3}' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d '/' -f1)
export ALIAS=$(hostname)
export TX_FILE_PATH="/root/.local/share/namada/pre-genesis/transactions.toml"

if [ ! -f "/root/.namada-shared/chain.config" ]; then
  # generate validator keys
  WALLET_KEY="$ALIAS-wallet"
  BOND_AMOUNT=1000000
  if [ $(hostname) = "namada-1" ]; then
    BOND_AMOUNT=1500000
  fi

  # generate account
  namadaw --pre-genesis gen --alias $WALLET_KEY --unsafe-dont-encrypt

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
    --self-bond-amount $BOND_AMOUNT \
    --email "$ALIAS@namada.net" \
    --path $TX_FILE_PATH \
    --unsafe-dont-encrypt
  # add `namada-x-validator` alias to wallets
  namadaw --pre-genesis add --alias "$ALIAS-validator" --value $ESTABLISHED_ACCOUNT_ADDRESS
  mkdir -p /root/.namada-shared/$ALIAS
  # these directories will be used by hermes
  mkdir -p ~/.namada-shared/chain-a && mkdir -p ~/.namada-shared/chain-b
  # Sign validators transactions file
  namadac utils sign-genesis-txs \
    --path $TX_FILE_PATH \
    --output /root/.local/share/namada/pre-genesis/signed-transactions.toml \
    --alias $ALIAS
  # copy this validators signed transactions to a shared volume to be accessible by other containers
  cp -a /root/.local/share/namada/pre-genesis/signed-transactions.toml /root/.namada-shared/$ALIAS/transactions.toml
fi

if [ $(hostname) = "namada-1" ]; then
# generating chain configs, this should be executed only on namada-1
    generate_chain_configs
else
# other nodes should pause here until chain configs are ready ###
  while [ ! -f "/root/.namada-shared/chain.config" ]; do
    echo "Configs server info not ready. Sleeping for 2s..."
    sleep 2
  done

  echo "Configs server info found, proceeding with network setup"
fi

############ all nodes resume here ############
# From here, the script is idempotent, meaning i can be executed on each start and nothing bad happens

# one last sleep to make sure configs server has been given time to start
sleep 3

# get chain config server info
export CHAIN_ID=$(awk 'NR==1' /root/.namada-shared/chain.config)
export NAMADA_NETWORK_CONFIGS_SERVER="http://namada-1:8123"
namadac utils join-network \
  --chain-id $CHAIN_ID \
  --genesis-validator $ALIAS \
  --allow-duplicate-ip \
  --add-persistent-peers \
  --dont-prefetch-wasm

sed -i "s#proxy_app = \"tcp://.*:26658\"#laddr = \"tcp://0.0.0.0:26658\"#g" /root/.local/share/namada/$CHAIN_ID/config.toml
sed -i "s#laddr = \"tcp://.*:26657\"#laddr = \"tcp://0.0.0.0:26657\"#g" /root/.local/share/namada/$CHAIN_ID/config.toml
sed -i "s#cors_allowed_origins = .*#cors_allowed_origins = [\"*\"]#g" /root/.local/share/namada/$CHAIN_ID/config.toml
sed -i "s#prometheus = .*#prometheus = true#g" /root/.local/share/namada/$CHAIN_ID/config.toml
sed -i "s#namespace = .*#namespace = \"tendermint\"#g" /root/.local/share/namada/$CHAIN_ID/config.toml

if [ $(hostname) = "namada-1" ]; then
  # configure namada-1 node to advertise host public ip to outside peers if provided
  echo "Advertising public ip $EXTERNAL_IP"
  sed -i "s#external_address = \".*\"#external_address = \"$EXTERNAL_IP:${P2P_PORT:-26656}\"#g" /root/.local/share/namada/$CHAIN_ID/config.toml
  sed -i "s#indexer = .*#indexer = \"kv\"#g" /root/.local/share/namada/$CHAIN_ID/config.toml
  rm -f /root/.namada-shared/tokens-addresses
  namadaw find --alias nam | grep -o 'tnam[^ ]*' >>/root/.namada-shared/tokens-addresses
  namadaw find --alias eth | grep -o 'tnam[^ ]*' >>/root/.namada-shared/tokens-addresses

  nohup bash -c "python3 -m http.server --directory /root/.local/share/namada/$CHAIN_ID/ 31222 &"

fi
# start node
NAMADA_LOG=info CMT_LOG_LEVEL=p2p:none,pex:error NAMADA_CMT_STDOUT=true namada node ledger run
