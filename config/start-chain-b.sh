#!/bin/bash

# clean up the http server when the script exits
cleanup() {
    pkill -f "python3 -m http.server --directory /root/.local/share/namada"
}

export PUBLIC_IP=$(ip a | grep -oE 'inet ([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2} brd ([0-9]{1,3}\.){3}[0-9]{1,3}' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d '/' -f1)
export ALIAS=$(hostname)
export TX_FILE_PATH="/root/.local/share/namada/pre-genesis/transactions.toml"

if [ ! -f "/root/.namada-shared/chain-b.config" ]; then
  # generate validator keys
  WALLET_KEY="$ALIAS-wallet"
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
    --self-bond-amount 5000000 \
    --email "$ALIAS@namada.net" \
    --path $TX_FILE_PATH \
    --unsafe-dont-encrypt
  # add `namada-x-validator` alias to wallets
  namadaw --pre-genesis add --alias "$ALIAS-validator" --value $ESTABLISHED_ACCOUNT_ADDRESS
  mkdir -p /root/.namada-chain-b/$ALIAS

  # Sign validators transactions file
  namadac utils sign-genesis-txs \
    --path $TX_FILE_PATH \
    --output /root/.local/share/namada/pre-genesis/signed-transactions.toml \
    --alias $ALIAS
  cp -a /root/.local/share/namada/pre-genesis/signed-transactions.toml /root/.namada-chain-b/$ALIAS/transactions.toml

  echo "Validator configs found. Generating chain configs..."

    # create a relayer account
    RELAYER_ALIAS="relayer"
    namadaw --pre-genesis gen --alias $RELAYER_ALIAS --unsafe-dont-encrypt
    mkdir /root/.namada-chain-b/$RELAYER_ALIAS
    namadac utils init-genesis-established-account --path /root/.namada-chain-b/$RELAYER_ALIAS/transactions.toml --aliases $RELAYER_ALIAS

  # create directory for genesis toml files
  mkdir -p /root/.namada-chain-b/genesis
  # copy genesis templates from mounted files
  cp /genesis/tokens.toml /root/.namada-chain-b/genesis/tokens.toml
  cp /genesis/validity-predicates.toml /root/.namada-chain-b/genesis/validity-predicates.toml
  cp /genesis/transactions.toml /root/.namada-chain-b/genesis/transactions.toml
  cp /genesis/parameters.toml /root/.namada-chain-b/genesis/parameters.toml

  # add genesis transactions to transactions.toml
  cat /root/.namada-chain-b/chain-b/transactions.toml >>/root/.namada-chain-b/genesis/transactions.toml

  python3 /scripts/make_balances.py /root/.namada-chain-b /genesis/balances.toml /root/.namada-chain-b/genesis/balances.toml

  genesis_time=$(date -d "+${GENESIS_DELAY} seconds" +"%Y-%m-%dT%H:%M:%SZ")

  INIT_OUTPUT=$(namadac utils init-network \
    --genesis-time "$genesis_time" \
    --wasm-checksums-path /wasm/checksums.json \
    --chain-prefix local-b \
    --templates-path /root/.namada-chain-b/genesis \
    --consensus-timeout-commit 10s)

  echo "$INIT_OUTPUT"
  CHAIN_ID=$(echo "$INIT_OUTPUT" |
    grep 'Derived chain ID:' |
    awk '{print $4}')
  echo "Chain id: $CHAIN_ID"
  # write config server info to shared volume
  printf "%s\n" "$CHAIN_ID" | tee /root/.namada-shared/chain.config


  export CHAIN_ID=$(awk 'NR==1' /root/.namada-shared/chain.config)
  export NAMADA_NETWORK_CONFIGS_DIR=$(pwd)
  namadac utils join-network \
    --chain-id $CHAIN_ID \
    --genesis-validator $ALIAS \
    --allow-duplicate-ip \
    --add-persistent-peers \
    --dont-prefetch-wasm

  sed -i "s#external_address = \".*\"#external_address = \"$EXTERNAL_IP:${P2P_PORT:-26656}\"#g" /root/.local/share/namada/$CHAIN_ID/config.toml

  sed -i "s#proxy_app = \"tcp://.*:26658\"#laddr = \"tcp://0.0.0.0:26658\"#g" /root/.local/share/namada/$CHAIN_ID/config.toml
  sed -i "s#laddr = \"tcp://.*:26657\"#laddr = \"tcp://0.0.0.0:26657\"#g" /root/.local/share/namada/$CHAIN_ID/config.toml
  sed -i "s#cors_allowed_origins = .*#cors_allowed_origins = [\"*\"]#g" /root/.local/share/namada/$CHAIN_ID/config.toml
  sed -i "s#prometheus = .*#prometheus = true#g" /root/.local/share/namada/$CHAIN_ID/config.toml
  sed -i "s#namespace = .*#namespace = \"tendermint\"#g" /root/.local/share/namada/$CHAIN_ID/config.toml
  sed -i "s#indexer = .*#indexer = \"kv\"#g" /root/.local/share/namada/$CHAIN_ID/config.toml

  rm -f /root/.namada-shared/chain-b-token-addrs
  namadaw find --alias nam | grep -o 'tnam[^ ]*' >>/root/.namada-shared/chain-b-token-addrs
  namadaw find --alias eth | grep -o 'tnam[^ ]*' >>/root/.namada-shared/chain-b-token-addrs
fi
  export CHAIN_ID=$(awk 'NR==1' /root/.namada-shared/chain.config)
  trap cleanup EXIT
  nohup bash -c "python3 -m http.server --directory /root/.local/share/namada/$CHAIN_ID/ 31222 &"
# start node
NAMADA_LOG=info CMT_LOG_LEVEL=p2p:none,pex:error NAMADA_CMT_STDOUT=true namada node ledger run
