FROM debian:trixie-slim AS runtime
ARG HERMES_TAG
RUN apt-get update && apt-get install unzip wget libcurl4-openssl-dev curl nano jq iproute2 procps bash-completion -y && apt-get clean

RUN wget https://github.com/informalsystems/hermes/releases/download/${HERMES_TAG}/hermes-${HERMES_TAG}-x86_64-unknown-linux-gnu.zip -O /tmp/hermes.zip && \
    unzip /tmp/hermes.zip -d /tmp && \
    mv /tmp/hermes /usr/local/bin/ && \
    rm -rf /tmp/hermes* && \
    chmod +x /usr/local/bin/hermes

# Set up bash completion
RUN hermes completions --shell bash > /usr/share/bash-completion/completions/hermes.bash
RUN echo 'if ! shopt -oq posix; then\n  if [ -f /usr/share/bash-completion/bash_completion ]; then\n    . /usr/share/bash-completion/bash_completion\n  fi\nfi' >> /etc/bash.bashrc
