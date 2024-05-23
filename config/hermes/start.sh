#!/bin/bash
#mkdir -p ~/.namada-shared/chain-a && mkdir -p ~/.namada-shared/chain-b

# Function to perform curl and extract network info
get_network_info() {
    curl_response=$(curl -s $1)
    network_info=$(echo "$curl_response" | jq -r '.result.node_info.network // empty' | sed 's/"//g')
    echo "$network_info"
}

# Attempt to get network info for both chains until both succeed
while true; do
    export CHAIN_A_ID=$(get_network_info "namada-1:26657/status")
    export CHAIN_B_ID=$(get_network_info "chain-b:26657/status")

    if [ -n "$CHAIN_A_ID" ] && [ -n "$CHAIN_B_ID" ]; then
        echo "Network info received for both chains:"
        echo "Chain A: $CHAIN_A_ID"
        echo "Chain B: $CHAIN_B_ID"
        break
    else
        echo "Waiting to get chain id of Chain A and Chain B..."
        sleep 5
    fi
done
export CHAIN_A_NAM_ADDR=$(awk 'NR==1' /root/.namada-shared/tokens-addresses)
export CHAIN_B_NAM_ADDR=$(awk 'NR==1' /root/.namada-shared/chain-b-token-addrs)
export HERMES_CONFIG=/root/.hermes/config.toml

if [ ! -f "/root/.hermes_channel" ]; then
   echo "Waiting for 30 seconds to make sure both chains are up"
   sleep 30
  # share each chain wallet.toml for hermes
  mkdir -p /root/wallets/wallet-a && mkdir -p /root/wallets/wallet-b
  curl -o /root/wallets/wallet-a/wallet.toml http://namada-1:31222/wallet.toml
  curl -o /root/wallets/wallet-b/wallet.toml http://chain-b:31222/wallet.toml

  sed -e "s/_CHAIN_A_ID_/$CHAIN_A_ID/g" \
    -e "s/_CHAIN_B_ID_/$CHAIN_B_ID/g" \
    -e "s/_NAM_A_ADDR_/$CHAIN_A_NAM_ADDR/g" \
    -e "s/_NAM_B_ADDR_/$CHAIN_B_NAM_ADDR/g" \
    /root/config-template.toml >"$HERMES_CONFIG"

  hermes --config $HERMES_CONFIG keys add --chain "$CHAIN_A_ID" --key-file /root/wallets/wallet-a/wallet.toml
  hermes --config $HERMES_CONFIG keys add --chain "$CHAIN_B_ID" --key-file /root/wallets/wallet-b/wallet.toml

  CHANNEL_CREATING_LOG=$(hermes --config $HERMES_CONFIG \
    create channel \
    --a-chain $CHAIN_A_ID \
    --b-chain $CHAIN_B_ID \
    --a-port transfer \
    --b-port transfer \
    --new-client-connection --yes)
  echo $CHANNEL_CREATING_LOG
  echo $CHANNEL_CREATING_LOG >>/root/.hermes_channel

fi
hermes --config $HERMES_CONFIG start