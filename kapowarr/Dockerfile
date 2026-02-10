ARG BUILD_FROM
ARG BUILD_VERSION

# Stage 1: Copy application from upstream image
FROM mrcas/kapowarr:v1.2.0 AS app-source

# Stage 2: Build on Home Assistant base
FROM ${BUILD_FROM}

# Copy application from upstream
COPY --from=app-source /app /app

# Install runtime dependencies (Alpine)
RUN apk add --no-cache \
    python3 \
    py3-pip \
    bash \
    tzdata \
    curl \
    nginx

# Copy S6-overlay configuration
COPY rootfs /

# Set permissions for S6 scripts
RUN find /etc/services.d -type f -name "run" -exec chmod +x {} \; && \
    find /etc/services.d -type f -name "finish" -exec chmod +x {} \; && \
    find /etc/cont-init.d -type f -exec chmod +x {} \;

WORKDIR /app

# Environment variables
ENV KAPOWARR_PORT=5656 \
    KAPOWARR_HOST=0.0.0.0

# Health check on nginx ingress port
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:8099/health || exit 1

# Labels
ARG BUILD_ARCH
LABEL \
  io.hass.type="addon" \
  io.hass.arch="${BUILD_ARCH}"
