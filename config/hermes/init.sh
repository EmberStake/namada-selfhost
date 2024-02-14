#!/bin/bash
#mkdir -p ~/.namada-shared/chain-a && mkdir -p ~/.namada-shared/chain-b

export CHAIN_A_ID=$(curl -s namada-1:26657/status | jq '.result.node_info.network' | sed 's/"//g')
export CHAIN_B_ID=$(curl -s chain-b:26657/status | jq '.result.node_info.network' | sed 's/"//g')
export CHAIN_A_NAM_ADDR=$(awk 'NR==1' /root/.namada-shared/tokens-addresses)
export CHAIN_B_NAM_ADDR=$(awk 'NR==1' /root/.namada-shared/chain-b-token-addrs)
export HERMES_CONFIG=/root/.hermes/config.toml

if [ ! -f "/root/.hermes_channel" ]; then

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