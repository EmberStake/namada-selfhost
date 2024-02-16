FROM rust:1.73.0-bullseye AS builder
ARG HERMES_TAG
ARG HERMES_ARCH="x86_64-unknown-linux-gnu"
WORKDIR /root
# The version should be matching the version set above
RUN rustup toolchain install 1.73.0 --profile minimal
RUN apt-get update && apt-get install -y \
    build-essential \
    clang-tools-11 \
    git \
    libssl-dev \
    pkg-config \
    protobuf-compiler \
    libudev-dev \
    && apt-get clean

RUN git clone https://github.com/heliaxdev/hermes.git
WORKDIR /root/hermes
RUN git checkout ${HERMES_TAG}

RUN cargo build --release --bin hermes

FROM debian:bullseye-slim AS runtime

RUN apt-get update && apt-get install libcurl4-openssl-dev curl nano jq iproute2 procps -y && apt-get clean

COPY --from=builder /root/hermes/target/release/hermes /usr/local/bin/