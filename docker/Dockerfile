FROM rust:1.76.0-bullseye AS builder
WORKDIR /__w/namada
# The version should be matching the version set above
RUN rustup toolchain install 1.76.0 --profile minimal
RUN rustup target add wasm32-unknown-unknown

RUN apt-get update && apt-get install -y \
    build-essential \
    clang-tools-11 \
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

FROM golang:1.18.0 as tendermint-builder
WORKDIR /app

RUN git clone -b v0.37.2 --single-branch https://github.com/cometbft/cometbft.git && cd cometbft && make build

FROM debian:bullseye-slim AS runtime
#ENV NAMADA_BASE_DIR=/.namada
#ENV NAMADA_LOG_COLOR=false

RUN apt-get update && apt-get install libcurl4-openssl-dev curl nano jq iproute2 procps python3 python3-pip expect -y && apt-get clean
RUN pip install toml

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