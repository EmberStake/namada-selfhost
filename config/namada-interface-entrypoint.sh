#!/bin/bash
original_dir=$(pwd)
  # wait until chain id to be generated
  while [ ! -f "/root/.namada-shared/chain.config" ]; do
    echo "Chain id not ready. Sleeping for 5s..."
    sleep 5
  done
export REACT_APP_NAMADA_CHAIN_ID=$(awk 'NR==2' /root/.namada-shared/chain.config)
echo "Chain id is $REACT_APP_NAMADA_CHAIN_ID"

  if [ ! -d "apps/namada-interface/node_modules" ]; then
    echo "Building shared dependencies, this gonna takes a long time"
    yarn

    echo "Building Interface"
    cd "$original_dir/apps/namada-interface"
    yarn wasm:build
    yarn dev:local

    echo "Building extensions"
    cd "$original_dir/apps/extension"
    yarn clean

    yarn wasm:build # This needs to be run initially to ensure wasm dependencies are available
    if [ -n "$EXTENSION_TARGET" ]; then
        yarn build:"$EXTENSION_TARGET"
    else
        yarn build
    fi
    rm -rf /build/chrome /build/firefox
    cp -r build/. /build/
  fi
echo "starting server..."
cd "$original_dir/apps/namada-interface"

yarn dev:local