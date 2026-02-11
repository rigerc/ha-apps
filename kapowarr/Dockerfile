# syntax=docker/dockerfile:1
# ==============================================================================
# Dockerfile — Kapowarr Home Assistant Add-on
#
# Pattern: multi-stage build
#   Stage 1 (app-source): copy binaries / assets from the upstream image
#   Stage 2 (final):      build on the HA base image, install runtime deps
#
# The first FROM ... AS line is parsed by manifest.sh to track the upstream
# version. Keep it on a single line.
# ==============================================================================

ARG BUILD_FROM
ARG BUILD_VERSION

# ------------------------------------------------------------------------------
# Stage 1 — upstream application source
# manifest.sh tracks this FROM line for upstream version updates
# ------------------------------------------------------------------------------
FROM mrcas/kapowarr:v1.2.0 AS app-source

# ------------------------------------------------------------------------------
# Stage 2 — Home Assistant add-on wrapper
# ------------------------------------------------------------------------------
FROM ${BUILD_FROM}

# Install nginx for ingress and sqlite3 for database management
RUN apk add --no-cache \
    nginx \
    sqlite

# Copy the application from the upstream image
COPY --from=app-source /app /app

# Copy the rootfs overlay
COPY rootfs /

# Install common HA framework from GitHub
RUN curl -fsSL "https://raw.githubusercontent.com/rigerc/ha-apps/main/common/scripts/install-framework.sh" -o /tmp/install-framework.sh && \
    chmod +x /tmp/install-framework.sh && \
    /tmp/install-framework.sh --github main && \
    rm -f /tmp/install-framework.sh

# Install Python dependencies, create the nginx servers directory,
# and set execute permissions on all s6-overlay v3 scripts
RUN mkdir -p /etc/nginx/servers && \
    pip install --no-cache-dir -r /app/requirements.txt && \
    chmod +x \
        /etc/s6-overlay/scripts/banner \
        /etc/s6-overlay/scripts/kapowarr-setup \
        /etc/s6-overlay/scripts/nginx-setup \
        /etc/s6-overlay/s6-rc.d/kapowarr/run \
        /etc/s6-overlay/s6-rc.d/kapowarr/finish \
        /etc/s6-overlay/s6-rc.d/nginx/run \
        /etc/s6-overlay/s6-rc.d/nginx/finish

# Set the working directory
WORKDIR /app

# Application environment variables
# Kapowarr listens on port 5656 by default
ENV APP_PORT=5656 \
    APP_HOST=0.0.0.0

# Health check — tests the nginx ingress endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:9919/health || exit 1

# OCI labels
ARG BUILD_ARCH
LABEL \
    io.hass.type="addon" \
    io.hass.arch="${BUILD_ARCH}"
