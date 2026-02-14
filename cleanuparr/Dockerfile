# syntax=docker/dockerfile:1
ARG BUILD_FROM
ARG BUILD_VERSION
FROM ghcr.io/cleanuparr/cleanuparr:2.5.1 AS app-source

# Stage 2: Build on Home Assistant base
FROM ${BUILD_FROM}

# Copy Cleanuparr binary with executable permissions
COPY --from=app-source /app/Cleanuparr /usr/bin/cleanuparr
RUN chmod +x /usr/bin/cleanuparr

# Copy dependency libraries (.NET self-contained app)
COPY --from=app-source /app/libMono.Unix.so /usr/lib/libMono.Unix.so
COPY --from=app-source /app/libe_sqlite3.so /usr/lib/libe_sqlite3.so

# Copy web UI assets (wwwroot directory) - consolidate in one layer
COPY --from=app-source /app /app

# Install runtime dependencies (Debian)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    bash \
    tzdata \
    curl \
    libicu-dev \
    && rm -rf /var/lib/apt/lists/*

# Create application directories
RUN mkdir -p /config /data && \
    chmod 755 /config /data

# Copy S6-overlay configuration (v3 format)
COPY rootfs /

# Set permissions for S6 v3 scripts
RUN find /etc/s6-overlay/s6-rc.d -type f -exec chmod +x {} \;

WORKDIR /

# Environment variables
ENV DOTNET_USE_POLLING_FILE_WATCHER=true \
    HTTP_PORTS=11011 \
    CONFIG_DIR=/config \
    PUID=1000 \
    PGID=1000 \
    UMASK=022

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:11011/health || exit 1

# Labels
LABEL \
  io.hass.type="addon" \
  io.hass.arch="${BUILD_ARCH}"
