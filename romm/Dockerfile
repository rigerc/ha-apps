ARG BUILD_FROM
ARG BUILD_VERSION
ARG BUILD_ARCH
FROM rommapp/romm:4.6.1 AS romm-base
FROM ${BUILD_FROM} AS final

LABEL \
  io.hass.type="addon" \
  io.hass.arch="${BUILD_ARCH}"

# Copy Python runtime from Romm image (ensures compatibility with venv)
# NOTE: The python3.13 path must be verified when bumping the upstream version
COPY --from=romm-base /usr/local/bin/python* /usr/local/bin/
COPY --from=romm-base /usr/local/lib/libpython* /usr/local/lib/
COPY --from=romm-base /usr/local/lib/python3.13 /usr/local/lib/python3.13

# Install runtime dependencies
# - mariadb-connector-c: MySQL/MariaDB client library
# - libpq: PostgreSQL client library
# - p7zip: 7zip archive support
# - valkey: Redis-compatible in-memory data store (for background jobs)
# - pcre2: PCRE library for nginx regex support
# - zlib: Compression library (needed by Python and nginx)
# Python runtime dependencies:
# - libffi: Foreign Function Interface library (needed by Python ctypes)
# - libgcc: GCC runtime library (needed by Python)
# - readline: Command line editing (needed by Python)
# - sqlite-libs: SQLite database (needed by Python sqlite3 module)
# - ncurses-libs: Terminal handling (needed by Python)
# - libbz2: bzip2 compression (needed by Python)
# - xz-libs: LZMA compression (needed by Python)
RUN apk add --no-cache \
    mariadb-connector-c \
    libpq \
    p7zip \
    libmagic \
    valkey \
    pcre2 \
    gettext \
    zlib \
    libffi \
    libgcc \
    readline \
    sqlite-libs \
    ncurses-libs \
    libbz2 \
    xz-libs

# Copy Python virtual environment from Romm image
COPY --from=romm-base /src/.venv /src/.venv

# Copy backend application code
COPY --from=romm-base /backend /backend

# Copy RAHasher binary for RetroAchievements support
COPY --from=romm-base /usr/bin/RAHasher /usr/bin/RAHasher

# Copy nginx and frontend files from base image
COPY --from=romm-base /var/www/html /var/www/html
COPY --from=romm-base /etc/nginx /tmp/nginx-etc
COPY --from=romm-base /usr/lib/nginx /usr/lib/nginx
COPY --from=romm-base /usr/sbin/nginx /usr/sbin/nginx

# Setup nginx and create required directories
# NOTE: nginx user/group created because upstream nginx.conf contains "user nginx;" directive
RUN mkdir -p /run/nginx /var/log/nginx /var/cache/nginx /etc/nginx /romm /redis-data && \
    cp -r /tmp/nginx-etc/* /etc/nginx/ && \
    rm -rf /tmp/nginx-etc && \
    chmod 755 /romm /redis-data && \
    if ! id nginx >/dev/null 2>&1; then \
        addgroup -S nginx && \
        adduser -S -D -H -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx; \
    fi

# Copy rootfs (s6 service scripts)
COPY rootfs /

# Set permissions
RUN find /etc/services.d -type f -name "run" -exec chmod +x {} \; && \
    find /etc/services.d -type f -name "finish" -exec chmod +x {} \; && \
    find /etc/cont-init.d -type f -exec chmod +x {} \;

# Set environment for Python
ENV PATH="/src/.venv/bin:${PATH}"
ENV PYTHONPATH=/backend
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /romm
EXPOSE 5999

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:5999/health || exit 1
