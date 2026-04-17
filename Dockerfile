FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates git gnupg && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends gh && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt /app/requirements.txt
RUN uv pip install --system --no-cache -r /app/requirements.txt

RUN mkdir -p /data/.hermes

COPY server.py /app/server.py
COPY templates/ /app/templates/
COPY docker-bin/ /usr/local/bin/
COPY install_hermes.sh /app/install_hermes.sh
COPY install_github_tools.sh /app/install_github_tools.sh
COPY start.sh /app/start.sh
RUN chmod +x /app/install_hermes.sh /app/install_github_tools.sh /app/start.sh /usr/local/bin/hermes /usr/local/bin/copilot

ENV HOME=/data
ENV HERMES_HOME=/data/.hermes
ENV GH_CONFIG_DIR=/data/.config/gh
ENV PATH=${PATH}:/data/.hermes/bin

CMD ["/app/start.sh"]
