FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install nemoclaw dependencies
RUN apt-get update \
    && apt-get install -y \
      ca-certificates \
      curl \
      git \
      gnupg \
      lsb-release \
      openssh-client \
      python3 \
      supervisor \
    && rm -rf /var/lib/apt/lists/*

# Docker CLI (using host Docker via mounted socket)
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
       https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
       > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Install nemoclaw
RUN curl -fsSL https://www.nvidia.com/nemoclaw.sh | \
    NEMOCLAW_NON_INTERACTIVE=1 \
    NEMOCLAW_ACCEPT_THIRD_PARTY_SOFTWARE=1 \
    bash
