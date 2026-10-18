FROM mcr.microsoft.com/dotnet/aspnet:9.0-bookworm-slim

ARG JACKETT_VERSION=latest

ENV XDG_CONFIG_HOME=/config \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
        tar \
        unzip \
        coreutils && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt

RUN if [ "$JACKETT_VERSION" = "latest" ]; then \
        DOWNLOAD_URL="https://github.com/Jackett/Jackett/releases/latest/download/Jackett.Binaries.LinuxAMDx64.tar.gz"; \
    else \
        DOWNLOAD_URL="https://github.com/Jackett/Jackett/releases/download/${JACKETT_VERSION}/Jackett.Binaries.LinuxAMDx64.tar.gz"; \
    fi && \
    curl -sSL "$DOWNLOAD_URL" | tar -xz -C /opt && \
    mkdir -p /config && \
    chmod -R 777 /config

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 9117

ENTRYPOINT ["/entrypoint.sh"]
