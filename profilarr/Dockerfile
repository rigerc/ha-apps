# syntax=docker/dockerfile:1

ARG BUILD_FROM
ARG BUILD_VERSION

# Stage 1: Copy application from upstream image
# manifest.sh tracks this FROM line for version updates
FROM santiagosayshey/profilarr:v1.1.4 AS app-source

# Stage 2: Build on Home Assistant base
FROM ${BUILD_FROM}

# Copy application from upstream
# Note: Upstream runs Python 3.9, but we're installing with HA's Python 3.13
COPY --from=app-source /app /app

# Install runtime dependencies
# HA base already includes: bash, curl, tzdata, ca-certificates, s6-overlay, bashio
# We only need: python3, pip, and git (for Profilarr's git sync feature)
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies in a single layer for optimal caching
# Using --break-system-packages is safe here as this is a dedicated container
# and we control the entire Python environment
RUN pip3 install --no-cache-dir --break-system-packages \
    Flask==3.1.0 \
    Flask-CORS==5.0.0 \
    PyYAML==6.0.2 \
    requests==2.32.3 \
    Werkzeug==3.1.3 \
    GitPython==3.1.24 \
    regex==2024.11.6 \
    APScheduler==3.11.0 \
    gunicorn==23.0.0 \
    aiohttp==3.11.11

# Copy rootfs and set permissions in a single layer
COPY rootfs /
RUN chmod +x \
    /etc/services.d/profilarr/run \
    /etc/services.d/profilarr/finish \
    /etc/services.d/nginx/run \
    /etc/services.d/nginx/finish \
    /etc/cont-init.d/*.sh

WORKDIR /app

# Environment variables
ENV PORT=6868 \
    HOST=0.0.0.0

# Health check using nginx ingress port (8019) not the backend port
# This properly tests the full ingress path
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8019/ || exit 1

# Labels
ARG BUILD_ARCH
LABEL \
  io.hass.type="addon" \
  io.hass.arch="${BUILD_ARCH}"
