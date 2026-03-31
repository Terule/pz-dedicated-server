# Project Zomboid Dedicated Server by Terule
# Maintained by Terule (@aguiar_fael)
# Using Official SteamCMD Image (Ubuntu-based)
FROM steamcmd/steamcmd:ubuntu-22

# Metadata Labels
LABEL maintainer="Terule <https://github.com/Terule>" \
      org.opencontainers.image.authors="Terule" \
      org.opencontainers.image.source="https://github.com/Terule/pz-dedicated-server" \
      org.opencontainers.image.description="Project Zomboid Dedicated Server by Terule - High performance Docker image" \
      instagram="@aguiar_fael"

# Install essential dependencies
# Added ca-certificates and gzip to fix the rcon-cli download error
RUN apt-get update && apt-get install -y --no-install-recommends \
    gettext-base \
    procps \
    jq \
    curl \
    ca-certificates \
    gzip \
    netcat-openbsd \
    openjdk-17-jre-headless \
    lib32gcc-s1 \
    lib32stdc++6 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Download rcon-cli directly
# Added --fail to curl to ensure it stops if the download fails
RUN curl -fsSL https://github.com/gorcon/rcon-cli/releases/download/v0.10.3/rcon-0.10.3-amd64_linux.tar.gz | tar xzvf - -C /usr/local/bin --strip-components=1

# Define base environment variables
ENV CONFIG_DIR=/project-zomboid-config \
    GAME_DIR=/project-zomboid \
    SERVER_NAME=pzserver \
    MEMORY_XMX_GB=8 \
    UPDATE_ON_START=true \
    RCON_PORT=27015 \
    STEAMCMD_PATH=/usr/bin/steamcmd

# Create steam user
RUN useradd -m steam

# Setup directories and copy scripts
RUN mkdir -p /project-zomboid /project-zomboid-config /home/steam/server/scripts
COPY ./scripts/*.scmd /home/steam/server/scripts/
COPY entrypoint.sh /home/steam/server/entrypoint.sh
COPY branding /home/steam/server/branding

# Set final permissions
RUN chmod +x /home/steam/server/entrypoint.sh && \
    chown -R steam:steam /home/steam/ /project-zomboid /project-zomboid-config

WORKDIR /home/steam/server

# Health Check
HEALTHCHECK --interval=1m --timeout=10s --start-period=5m --retries=3 \
    CMD pgrep "ProjectZomboid" > /dev/null || exit 1

ENTRYPOINT ["/home/steam/server/entrypoint.sh"]