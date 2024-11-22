FROM rust:1.81.0-bookworm AS builder
ARG HERMES_TAG
ARG HERMES_ARCH="x86_64-unknown-linux-gnu"
WORKDIR /root
# The version should be matching the version set above
RUN rustup toolchain install 1.81.0 --profile minimal
RUN apt-get update && apt-get install -y \
    build-essential \
    clang-tools-14 \
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

FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install libcurl4-openssl-dev curl nano jq iproute2 procps bash-completion -y && apt-get clean

COPY --from=builder /root/hermes/target/release/hermes /usr/local/bin/

# Set up bash completion
RUN hermes completions --shell bash > /usr/share/bash-completion/completions/hermes.bash
RUN echo 'if ! shopt -oq posix; then\n  if [ -f /usr/share/bash-completion/bash_completion ]; then\n    . /usr/share/bash-completion/bash_completion\n  fi\nfi' >> /etc/bash.bashrc
