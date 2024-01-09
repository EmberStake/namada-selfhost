FROM node:lts-bookworm
ARG REPO_TAG="v0.1.0-2bf3a75"

RUN apt-get update && \
    apt-get install -y \
        curl \
        clang \
        pkg-config \
        git \
        libssl-dev \
        protobuf-compiler \
        libudev-dev &&\
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN rustup target add wasm32-unknown-unknown && \
    curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh
RUN  yarn global add web-ext

WORKDIR /root
RUN git clone --branch main https://github.com/anoma/namada-interface.git
WORKDIR /root/namada-interface
RUN git checkout ${REPO_TAG}

