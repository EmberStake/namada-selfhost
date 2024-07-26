FROM rust:1.78.0-bookworm AS builder
WORKDIR /__w/namada
# The version should be matching the version set above
RUN rustup toolchain install 1.78.0 --profile minimal
RUN rustup target add wasm32-unknown-unknown

RUN apt-get update && apt-get install -y \
    build-essential \
    clang-tools-14 \
    git \
    libssl-dev \
    pkg-config \
    protobuf-compiler \
    libudev-dev \
    && apt-get clean

# Download binaryen and extract wasm-opt
ADD https://github.com/WebAssembly/binaryen/releases/download/version_113/binaryen-version_113-x86_64-linux.tar.gz /tmp/binaryen.tar.gz
RUN tar -xf /tmp/binaryen.tar.gz
RUN mv binaryen-version_*/bin/wasm-opt /usr/local/bin

ARG NAMADA_TAG=main
RUN git clone https://github.com/anoma/namada.git
WORKDIR /__w/namada/namada
RUN git checkout ${NAMADA_TAG}

RUN make build-release
RUN make build-wasm-scripts

FROM golang:1.19.0 as tendermint-builder
WORKDIR /app

RUN git clone https://github.com/cometbft/cometbft.git
WORKDIR cometbft
RUN git checkout v0.37.9
RUN make build

FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install libcurl4-openssl-dev curl nano jq iproute2 procps python3 python3-pip python3-toml expect -y && apt-get clean

COPY --from=builder /__w/namada/namada/wasm/*.wasm /__w/namada/namada/wasm/*.json /wasm/

COPY --from=builder /__w/namada/namada/target/release/namada /usr/local/bin
COPY --from=builder /__w/namada/namada/target/release/namadan /usr/local/bin
COPY --from=builder /__w/namada/namada/target/release/namadaw /usr/local/bin
COPY --from=builder /__w/namada/namada/target/release/namadac /usr/local/bin
COPY --from=tendermint-builder /app/cometbft/build/cometbft /usr/local/bin

EXPOSE 26656
EXPOSE 26660
EXPOSE 26659
EXPOSE 26657

ENTRYPOINT ["/usr/local/bin/namada"]
CMD ["--help"]