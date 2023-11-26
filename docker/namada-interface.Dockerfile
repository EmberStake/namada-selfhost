#FROM rust:slim-bookworm
FROM node:lts-bookworm-slim

RUN apt-get update && apt-get install -y \
    curl \
    clang \
    pkg-config \
    git \
    libssl-dev \
    protobuf-compiler \
    libudev-dev \
    nano \
    jq \
    && apt-get clean

# Install rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

ENV PATH="/root/.cargo/bin:${PATH}"

# Add WASM target & wasm-pack
RUN rustup target add wasm32-unknown-unknown \
    && curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh

# Install web-ext
RUN yarn global add web-ext

RUN git clone --branch main https://github.com/anoma/namada-interface.git
WORKDIR namada-interface
RUN git reset --hard d58c0f4
RUN yarn

