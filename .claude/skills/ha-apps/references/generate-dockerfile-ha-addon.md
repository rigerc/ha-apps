---
name: generate-dockerfile-ha-addon
description: Generate or improve a Dockerfile for wrapping an existing Docker image as a Home Assistant add-on in this repo
category: development
---

# Generate HA Add-on Dockerfile

Generate or improve a Dockerfile that wraps an existing upstream Docker image as a Home Assistant add-on, following the patterns used in this repository.

## Critical Principles

### This Is a Wrapper, Not a Build

Add-on Dockerfiles in this repo do NOT build an application from source. They:
1. Pull an existing upstream Docker image as a reference stage
2. Build on the HA base image (`${BUILD_FROM}`)
3. Copy only what's needed from the upstream into the HA base

**The goal**: Get the upstream app running under HA's process supervision (s6-overlay) with ingress support.

### Verify Before Adding

Before adding any `RUN`, `COPY`, or `ENV` instruction:
- Pull and inspect the upstream image to know what's already there
- Check what the HA base image already provides (bashio, s6-overlay, common tools)
- Only copy what's actually needed at runtime - not the entire upstream filesystem

### First FROM Line Is Tracked by manifest.sh

The first `FROM ... AS` line in the Dockerfile determines which upstream image version manifest.sh tracks. It must follow this exact pattern:

```dockerfile
FROM upstream-image:version AS stage-name
```

Never use `FROM ${BUILD_FROM}` as the first line.

---

## Step 0: Gather Context

Before writing a single line, read these files:

1. **`config.yaml`** - What ports, ingress config, and options are defined?
2. **`build.yaml`** - Which HA base images are used (Alpine vs Debian)?
3. **Upstream image docs/GitHub** - What does the app expose? What env vars does it need?

If any of these files don't exist yet, create them first (they determine what the Dockerfile must do).

---

## Step 1: Choose HA Base Image Type

The base image is defined in `build.yaml`, not the Dockerfile. The Dockerfile only uses `${BUILD_FROM}`.

**Choose Alpine** (`ghcr.io/home-assistant/{arch}-base:3.23`) when:
- Upstream is Alpine-based
- App has minimal system dependencies
- No apt/deb packages required

**Choose Debian** (`ghcr.io/home-assistant/{arch}-base-debian:trixie`) when:
- Upstream is Debian/Ubuntu-based
- App requires apt packages or `.so` libraries built against glibc
- App is a compiled binary (Go, .NET, Rust) that links against glibc

**`build.yaml` template:**
```yaml
build_from:
  aarch64: ghcr.io/home-assistant/aarch64-base-debian:trixie
  amd64: ghcr.io/home-assistant/amd64-base-debian:trixie
labels:
  project: https://github.com/upstream/repo
```

**What HA base images already include** (don't reinstall):
- s6-overlay v2 (init system via `/etc/cont-init.d/` and `/etc/services.d/`)
- bashio (helper functions)
- bash, curl, jq, tzdata (Alpine base)
- bash, curl, jq, tzdata (Debian base)

---

## Step 2: Analyze the Upstream Image

Run the discovery script to extract key information from the upstream image or its GitHub repository:

```bash
# Analyze a Docker image
bash .claude/skills/ha-apps/scripts/discover.sh upstream-image:version

# Examples:
bash .claude/skills/ha-apps/scripts/discover.sh ghcr.io/cleanuparr/cleanuparr:2.5.1
bash .claude/skills/ha-apps/scripts/discover.sh plexguide/huntarr:9.1.1
bash .claude/skills/ha-apps/scripts/discover.sh https://github.com/rommapp/romm
```

### Mapping Discovery Output to Decisions

| Output Section | What It Informs |
|----------------|-----------------|
| **Base OS Detection** | Alpine (apk) → use Alpine HA base; Debian/Ubuntu (apt) → use Debian HA base |
| **Exposed Ports** | Ports to `EXPOSE` in Dockerfile; add to `config.yaml ports:` or `ingress_port:` |
| **Environment Variables** | Candidate `options:` + `schema:` in `config.yaml`; env vars to pass via `cont-init.d` |
| **Volumes** | `map:` entries in `config.yaml` (`share`, `addon_config`, etc.) |
| **ENTRYPOINT/CMD** | The upstream start command - replicate its logic in the s6 `services.d/app/run` script |
| **Package Installations** | Runtime dependencies to install in the `FROM ${BUILD_FROM}` stage |
| **Architecture Support** | Which archs to list in `config.yaml arch:` and `build.yaml build_from:` |
| **Recommendations** | Summary of suggested `config.yaml`, Dockerfile, and service setup |

### Supplementary: Manual Filesystem Exploration

For questions the script can't answer (exact file paths, library dependencies, entrypoint logic):

```bash
# Examine the actual filesystem layout
docker run --rm upstream-image:version find /app -type f | head -30

# Read the entrypoint script
docker run --rm upstream-image:version cat /entrypoint.sh

# Check shared library dependencies of a binary
docker run --rm upstream-image:version ldd /usr/bin/myapp
```

Key things to confirm:
- **Application binary/entrypoint**: Where does the main executable live?
- **Runtime files**: Static assets, web UI (`/app/wwwroot`, `/var/www/html`, etc.)
- **Shared libraries**: Any `.so` files that aren't standard system libs (ldd them)
- **Virtual environments**: Python venvs (e.g., `/src/.venv`, `/app/.venv`)

**The upstream `ENTRYPOINT`/`CMD` is replaced by s6 service scripts** in `rootfs/` - understand what it does so you can replicate the startup logic.

---

## Step 3: Generate the Dockerfile

### Standard Two-Stage Wrapper Pattern

```dockerfile
ARG BUILD_FROM
ARG BUILD_VERSION

# Stage 1: Reference the upstream image (manifest.sh tracks this line)
FROM upstream-image:X.Y.Z AS app-source

# Stage 2: Build on HA base image
FROM ${BUILD_FROM}

# Copy application from upstream
COPY --from=app-source /app /app

# Install runtime dependencies
# Debian:
RUN apt-get update && apt-get install -y --no-install-recommends \
    dependency1 \
    dependency2 \
    && rm -rf /var/lib/apt/lists/*
# Alpine:
# RUN apk add --no-cache dependency1 dependency2

# Copy s6 service scripts and config overlays
COPY rootfs /

# Make s6 scripts executable
RUN find /etc/services.d -type f -name "run" -exec chmod +x {} \; && \
    find /etc/services.d -type f -name "finish" -exec chmod +x {} \; && \
    find /etc/cont-init.d -type f -exec chmod +x {} \;
```

### Checklist

**Header:**
- [ ] `ARG BUILD_FROM` and `ARG BUILD_VERSION` before any FROM
- [ ] First FROM is the upstream image with a pinned version tag, named with `AS`
- [ ] Second FROM is `${BUILD_FROM}` only

**Copying from upstream:**
- [ ] Copy only what's needed at runtime (not entire `/` or large unused dirs)
- [ ] For binaries: copy the executable and required `.so` libraries
- [ ] For Python apps: copy the venv + app code, not build artifacts

**Runtime dependencies:**
- [ ] Use correct package manager for chosen base (apk vs apt-get)
- [ ] Clean package manager cache in the same RUN layer
- [ ] Use `--no-install-recommends` for apt-get
- [ ] Don't install packages already in the HA base image

**Architecture-aware downloads** (when fetching binaries outside the package manager):
```dockerfile
ARG BUILD_ARCH
RUN ARCH=$([ "${BUILD_ARCH}" = "amd64" ] && echo "amd64" || echo "arm64") && \
    curl -fsSL "https://example.com/release-${ARCH}.tar.gz" -o /tmp/app.tar.gz && \
    tar -xzf /tmp/app.tar.gz -C /usr/local/bin && \
    rm /tmp/app.tar.gz
```

**rootfs overlay:**
- [ ] `COPY rootfs /` is present
- [ ] s6 script permissions are set (chmod the run/finish scripts)

**What NOT to add:**
- Do not set `ENTRYPOINT` or `CMD` - s6 handles process start via service scripts
- Do not create non-root users - HA base handles this; use `s6-setuidgid` in service scripts if needed
- Do not add `HEALTHCHECK` unless the app has a verified health endpoint and you've tested it
- Do not use `COPY . .` - always be explicit about what's copied

---

## Step 4: Create rootfs Structure

### Directory Layout

```
rootfs/
├── etc/
│   ├── cont-init.d/          # Init scripts (run once at startup, in numeric order)
│   │   ├── 00-banner.sh      # Optional: log startup banner
│   │   └── 01-setup.sh       # Setup config dirs, env vars
│   └── services.d/           # Long-running supervised services
│       ├── app/
│       │   ├── run           # Start the application (must run in foreground)
│       │   └── finish        # Optional: cleanup on exit
│       └── nginx/            # Only if using ingress with nginx
│           └── run
```

### Init Script Pattern (`cont-init.d/`)

```bash
#!/usr/bin/with-contenv bashio
# shellcheck shell=bash

bashio::log.info "Configuring App..."

# Read add-on options
PORT=$(bashio::config 'port')
LOG_LEVEL=$(bashio::config 'log_level')

# Set env vars for the service process
# (s6 v2: write to /var/run/s6/container_environment/)
printf "%s" "${PORT}" > /var/run/s6/container_environment/APP_PORT
printf "%s" "${LOG_LEVEL}" > /var/run/s6/container_environment/LOG_LEVEL

# Ensure config directory exists
mkdir -p /config/app
chmod 755 /config/app
```

### Service Script Pattern (`services.d/app/run`)

```bash
#!/usr/bin/with-contenv bashio
# shellcheck shell=bash

bashio::log.info "Starting App..."

# Set ingress base URL if ingress is enabled
if bashio::addon.ingress; then
    export BASE_URL="$(bashio::addon.ingress_entry)"
fi

cd /app || bashio::exit.nok "Could not change to /app"

# IMPORTANT: Must use exec and run in foreground (never daemon mode, never &)
exec /usr/bin/myapp --config /config/app.conf
```

### Ingress Nginx Pattern

When `ingress: true` is set in `config.yaml`, add an nginx service that proxies to the app:

**`rootfs/etc/services.d/nginx/run`:**
```bash
#!/usr/bin/with-contenv bashio
# shellcheck shell=bash

# Wait for app backend to be ready before starting nginx
bashio::net.wait_for 8080 localhost 300

exec nginx
```

**`rootfs/etc/nginx/servers/ingress.conf`:**
```nginx
server {
    listen 8099;

    location / {
        allow 172.30.32.2;
        deny all;

        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

**`cont-init.d/20-nginx.sh`** (when ingress port is dynamic):
```bash
#!/usr/bin/with-contenv bashio
# shellcheck shell=bash

INGRESS_PORT=$(bashio::addon.ingress_port)
sed -i "s/listen 8099/listen ${INGRESS_PORT}/g" /etc/nginx/servers/ingress.conf
```

---

## Step 5: Align config.yaml with Dockerfile

After writing the Dockerfile, verify `config.yaml` is consistent:

| Dockerfile | config.yaml |
|------------|-------------|
| `EXPOSE 8080` | `ports: 8080/tcp: 8080` |
| Nginx listening on 8099 | `ingress_port: 8099` |
| `ENV` defaults | `options:` defaults |
| Mounts `/config` | `map: - addon_config:rw` |
| Mounts `/share` | `map: - share:rw` |

**Never set `EXPOSE` for the ingress port** - only for ports exposed to the host.

---

## Step 6: Test the Build

```bash
# From the add-on directory (e.g., huntarr/)
docker build \
    --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:trixie \
    --build-arg BUILD_ARCH=amd64 \
    -t test-addon .

# Run and check logs
docker run --rm test-addon
```

If using the CI builder:
```bash
docker build --build-arg BUILD_FROM=base-image:tag -t test-addon .
```

---

## Real Examples in This Repo

| Add-on | Base | Copy Strategy | Notes |
|--------|------|---------------|-------|
| **romm** | Alpine | Python runtime + venv + app code + nginx | Complex copy due to Python version pinning |
| **profilarr** | Debian | `/app` directory only | Reinstalls Python deps via pip |
| **huntarr** | Debian | `/app` directory only | Uses Python venv |
| **cleanuparr** | Debian | Binary + `.so` libs + `wwwroot` | .NET self-contained binary |

---

## Common Mistakes

**Wrong first FROM:**
```dockerfile
# WRONG - manifest.sh won't track upstream version
ARG BUILD_FROM
FROM ${BUILD_FROM}
FROM upstream:1.0 AS source
```
```dockerfile
# CORRECT
ARG BUILD_FROM
FROM upstream:1.0 AS source
FROM ${BUILD_FROM}
```

**Copying too much:**
```dockerfile
# WRONG - copies everything including build artifacts, tests, docs
COPY --from=app-source / /

# CORRECT - copy only what's needed at runtime
COPY --from=app-source /app /app
COPY --from=app-source /usr/bin/myapp /usr/bin/myapp
```

**Daemon mode in service scripts:**
```bash
# WRONG - s6 can't supervise a daemon
/usr/bin/myapp --daemon &

# CORRECT - exec in foreground
exec /usr/bin/myapp
```

**Skipping rootfs permissions:**
```dockerfile
# WRONG - s6 scripts won't be executable
COPY rootfs /

# CORRECT
COPY rootfs /
RUN find /etc/services.d -type f -name "run" -exec chmod +x {} \; && \
    find /etc/services.d -type f -name "finish" -exec chmod +x {} \; && \
    find /etc/cont-init.d -type f -exec chmod +x {} \;
```
