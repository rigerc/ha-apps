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

# Install nginx for ingress
RUN apk add --no-cache nginx

# Copy the application from the upstream image
COPY --from=app-source /app /app

# Copy the rootfs overlay
COPY rootfs /

# Create the nginx servers directory
RUN mkdir -p /etc/nginx/servers

# Set execute permissions on all s6 and init scripts
RUN chmod +x \
    /etc/cont-init.d/*.sh \
    /etc/services.d/kapowarr/run \
    /etc/services.d/kapowarr/finish \
    /etc/services.d/nginx/run \
    /etc/services.d/nginx/finish \
    /usr/local/lib/ha-log.sh

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
