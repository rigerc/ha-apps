# syntax=docker/dockerfile:1
# ==============================================================================
# Dockerfile — APP_NAME Home Assistant Add-on
#
# Pattern: multi-stage build
#   Stage 1 (app-source): copy binaries / assets from the upstream image
#   Stage 2 (final):      build on the HA base image, install runtime deps
#
# The first FROM ... AS line is parsed by manifest.sh to track the upstream
# version.  Keep it on a single line and do NOT reorder it.
#
# Build arguments injected by the HA supervisor build system:
#   BUILD_FROM   — the base image URI (from build.yaml build_from)
#   BUILD_ARCH   — target architecture string (amd64, aarch64, armv7)
#   BUILD_VERSION — add-on version string from config.yaml
# ==============================================================================

ARG BUILD_FROM
ARG BUILD_VERSION

# ------------------------------------------------------------------------------
# Stage 1 — upstream application source
# CUSTOMIZE: Replace with the actual upstream Docker image and tag.
#            This line is parsed by manifest.sh; keep the comment below it.
# ------------------------------------------------------------------------------
# manifest.sh tracks this FROM line for upstream version updates
FROM UPSTREAM_IMAGE:UPSTREAM_VERSION AS app-source

# ------------------------------------------------------------------------------
# Stage 2 — Home Assistant add-on wrapper
# ------------------------------------------------------------------------------
FROM ${BUILD_FROM}

# CUSTOMIZE: Install the runtime packages your application needs.
# The HA base image already provides: bash, curl, tzdata, ca-certificates,
# s6-overlay v3, and bashio.
#
# Alpine package manager:
RUN apk add --no-cache \
    nginx \
    # CUSTOMIZE: add or remove packages as needed
    # python3 \
    # sqlite \
    # openssl \
    && true

# CUSTOMIZE: If using a Debian base image, replace the apk command above with:
# RUN apt-get update && apt-get install -y --no-install-recommends \
#     nginx \
#     && rm -rf /var/lib/apt/lists/*

# Copy the application from the upstream image.
# CUSTOMIZE: Adjust the source path to match where the upstream image installs
#            the application (inspect with: docker inspect <image>).
COPY --from=app-source /app /app

# Copy the rootfs overlay — this overlays /etc and /usr/local inside the container
COPY rootfs /

# Create the nginx servers directory and set execute permissions on all
# s6-overlay v3 scripts in a single layer.
# ingress.conf is not shipped as a static file; it is rendered at container start
# by the nginx-setup oneshot using tempio from the template in nginx/templates/.
RUN mkdir -p /etc/nginx/servers && \
    chmod +x \
        /etc/s6-overlay/scripts/banner \
        /etc/s6-overlay/scripts/APP_NAME-setup \
        /etc/s6-overlay/scripts/nginx-setup \
        /etc/s6-overlay/s6-rc.d/APP_NAME/run \
        /etc/s6-overlay/s6-rc.d/APP_NAME/finish \
        /etc/s6-overlay/s6-rc.d/nginx/run \
        /etc/s6-overlay/s6-rc.d/nginx/finish

# Set the working directory to the application root
WORKDIR /app

# CUSTOMIZE: Define application-specific environment variables.
# APP_PORT is the internal port your application listens on.
# Nginx will proxy ingress traffic to this port.
ENV APP_PORT=APP_PORT \
    APP_HOST=0.0.0.0

# Health check — tests the nginx ingress endpoint (not the backend port).
# CUSTOMIZE: Replace APP_INGRESS_PORT with the ingress_port from config.yaml,
#            and adjust the health path if the app uses something other than /health.
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:APP_INGRESS_PORT/health || exit 1

# OCI labels — BUILD_ARCH is injected by the HA build system
ARG BUILD_ARCH
LABEL \
    io.hass.type="addon" \
    io.hass.arch="${BUILD_ARCH}"
