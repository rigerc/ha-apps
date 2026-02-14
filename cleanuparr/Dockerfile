# syntax=docker/dockerfile:1
ARG BUILD_FROM
ARG BUILD_VERSION
FROM ghcr.io/cleanuparr/cleanuparr:2.6.1 AS app-source

FROM ${BUILD_FROM}

COPY --from=app-source /app/Cleanuparr /usr/bin/cleanuparr
RUN chmod +x /usr/bin/cleanuparr

COPY --from=app-source /app/libMono.Unix.so /usr/lib/libMono.Unix.so
COPY --from=app-source /app/libe_sqlite3.so /usr/lib/libe_sqlite3.so

COPY --from=app-source /app /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    libicu-dev \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /config /data /etc/nginx/servers && \
    chmod 755 /config /data

COPY rootfs /

RUN chmod +x \
    /etc/s6-overlay/scripts/banner \
    /etc/s6-overlay/scripts/cleanuparr-setup \
    /etc/s6-overlay/scripts/nginx-setup \
    /etc/s6-overlay/s6-rc.d/cleanuparr/run \
    /etc/s6-overlay/s6-rc.d/cleanuparr/finish \
    /etc/s6-overlay/s6-rc.d/nginx/run \
    /etc/s6-overlay/s6-rc.d/nginx/finish

WORKDIR /

ENV DOTNET_USE_POLLING_FILE_WATCHER=true \
    HTTP_PORTS=11011 \
    CONFIG_DIR=/config \
    PUID=1000 \
    PGID=1000 \
    UMASK=022

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:11011/health || exit 1

ARG BUILD_ARCH
LABEL \
  io.hass.type="addon" \
  io.hass.arch="${BUILD_ARCH}"
