#!/bin/bash

# Function to replace hardcoded token address
replace_token_address() {
  local file="$1"
  local old_address="$2"
  local new_address="$3"

  # Use sed to replace the address
  sed -i "s/$old_address/$new_address/g" "$file"
}

original_dir=$(pwd)
  # wait until chain id to be generated
  while [ ! -f "/root/.namada-shared/chain.config" ]; do
    echo "Chain id not ready. Sleeping for 5s..."
    sleep 5
  done

export NAMADA_INTERFACE_NAMADA_CHAIN_ID=$(awk 'NR==2' /root/.namada-shared/chain.config)
export NAM_ADDR=$(awk 'NR==1' /root/.namada-shared/tokens-addresses)
export ETH_ADDR=$(awk 'NR==2' /root/.namada-shared/tokens-addresses)


# Update hard coded token addresses in the specified file
replace_token_address "packages/types/src/tx/tokens/types/index.ts" \
  "tnam1q9mjvqd45u7w54kee2aquugtv7vn7h3xrcrau7xy" \
  "$NAM_ADDR"

replace_token_address "packages/types/src/tx/tokens/types/index.ts" \
  "tnam1q9anasrx0gqeuxrc22a0uefe82kw08avhcasevng" \
  "$ETH_ADDR"

echo "Chain id is $NAMADA_INTERFACE_NAMADA_CHAIN_ID"
env > "$original_dir/apps/namada-interface/.env"

  if [ ! -d "apps/namada-interface/node_modules" ]; then
    echo "Building shared dependencies, this gonna takes a long time"
    yarn

    echo "Building Interface"
    cd "$original_dir/apps/namada-interface"
    yarn wasm:build

    echo "Building extensions"
    cd "$original_dir/apps/extension"

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