FROM ghcr.io/openclaw/openclaw:latest

# Install GitHub CLI as root
USER root
RUN apt-get update && \
    apt-get install -y curl gpg && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# Remap the node user to the host user's UID/GID so bind-mount directories
# are accessible without chown or ACLs. Defaults match the original node uid.
ARG NODE_UID=1000
ARG NODE_GID=1000
RUN groupmod -g "${NODE_GID}" node && \
    usermod  -u "${NODE_UID}" -g "${NODE_GID}" node && \
    chown -R node:node /home/node

# Switch back to the node user
USER node
