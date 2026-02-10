---
name: ha-apps
version: 1.0.0
description: This skill should be used when the user asks to "wrap a Docker app for HA", "create HA add-on from Docker image", "analyze Docker image for add-on", "make ingress add-on", "generate Dockerfile for add-on", "scaffold add-on", "update add-on Dockerfile", or wants to convert existing containerized applications into Home Assistant add-ons with web UI integration.
---

# Home Assistant Add-on Creator (from Docker Images)

Specialized skill for creating Home Assistant add-ons that wrap existing upstream Docker images with ingress (embedded web UI) support and s6-overlay process supervision.

Add-on Dockerfiles in this repo are **wrappers, not source builds** - they pull an upstream Docker image, copy only runtime files into the HA base image (`${BUILD_FROM}`), and run the app under s6-overlay process supervision. See `references/generate-dockerfile-ha-addon.md` for the full rationale and patterns.

## Core Workflow

### Step 1: Discover Docker Image Configuration

Run the discovery script to analyze the target Docker image:

```bash
bash .claude/skills/ha-apps/scripts/discover.sh <docker-image-or-github-url>

# Examples:
bash .claude/skills/ha-apps/scripts/discover.sh ghcr.io/user/myapp:v1.0
bash .claude/skills/ha-apps/scripts/discover.sh https://github.com/user/repo
```

The discovery script extracts: base OS, exposed ports, environment variables, volumes, entrypoint/CMD, package installations, and architecture support.

Map the output to decisions:

| Output Section | Informs |
|----------------|---------|
| **Base OS** | Alpine (apk) -> Alpine HA base; Debian/Ubuntu (apt) -> Debian HA base |
| **Exposed Ports** | `config.yaml` ports or `ingress_port` |
| **Environment Variables** | `config.yaml` options + schema |
| **Volumes** | `config.yaml` map entries |
| **ENTRYPOINT/CMD** | Logic to replicate in `services.d/app/run` |
| **Package Installations** | Runtime dependencies for the `FROM ${BUILD_FROM}` stage |
| **Architecture** | `config.yaml` arch array and `build.yaml` build_from entries |

For deeper exploration beyond what the script provides:

```bash
docker run --rm upstream-image:version find /app -type f | head -30
docker run --rm upstream-image:version cat /entrypoint.sh
docker run --rm upstream-image:version ldd /usr/bin/myapp
```

### Step 2: Create Add-on Directory Structure

Scaffold the add-on directory:

```bash
# For ingress-enabled add-on:
cp -r .claude/skills/ha-apps/templates/ingress-nginx-s6-v3/ myapp/

# For basic add-on:
cp -r .claude/skills/ha-apps/scaffold/ myapp/
```

Required files: `config.yaml`, `build.yaml`, `Dockerfile`, `DOCS.md`, and `rootfs/`.

### Step 3: Choose HA Base Image and Generate Dockerfile

Define the base image in `build.yaml` (not the Dockerfile):
- **Alpine** (`ghcr.io/home-assistant/{arch}-base:3.23`) for Alpine-based upstreams with minimal dependencies
- **Debian** (`ghcr.io/home-assistant/{arch}-base-debian:trixie`) for Debian/Ubuntu-based upstreams or glibc-linked binaries

HA base images already include: s6-overlay, bashio, bash, curl, jq, tzdata. Do not reinstall these.

Follow the **two-stage wrapper pattern** for the Dockerfile. The first `FROM ... AS` line determines which upstream image version `manifest.sh` tracks:

```dockerfile
ARG BUILD_FROM
ARG BUILD_VERSION

# Stage 1: Reference upstream (manifest.sh tracks this line)
FROM upstream-image:X.Y.Z AS app-source

# Stage 2: Build on HA base
FROM ${BUILD_FROM}

COPY --from=app-source /app /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    dependency1 \
    && rm -rf /var/lib/apt/lists/*

COPY rootfs /

RUN find /etc/services.d -type f -name "run" -exec chmod +x {} \; && \
    find /etc/services.d -type f -name "finish" -exec chmod +x {} \; && \
    find /etc/cont-init.d -type f -exec chmod +x {} \;
```

**Critical rules:**
- Never use `FROM ${BUILD_FROM}` as the first FROM line
- Copy only runtime files from upstream, not the entire filesystem
- Do not set `ENTRYPOINT` or `CMD` - s6 handles process start via service scripts
- Clean package manager caches in the same RUN layer

See `references/generate-dockerfile-ha-addon.md` for complete checklists, rootfs structure patterns, ingress nginx setup, config.yaml alignment, architecture-aware downloads, and common mistakes.

### Step 4: Create rootfs Structure

```
rootfs/
├── etc/
│   ├── cont-init.d/          # Init scripts (run once, numeric order)
│   │   ├── 00-banner.sh      # Optional startup banner
│   │   └── 01-setup.sh       # Config dirs, env vars
│   └── services.d/           # Long-running supervised services
│       ├── app/
│       │   ├── run           # Start app (must run in foreground)
│       │   └── finish        # Optional cleanup on exit
│       └── nginx/            # Only if using ingress
│           └── run
```

**Init script pattern** (`cont-init.d/01-setup.sh`):
```bash
#!/usr/bin/with-contenv bashio
# shellcheck shell=bash

PORT=$(bashio::config 'port')
printf "%s" "${PORT}" > /var/run/s6/container_environment/APP_PORT
mkdir -p /config/app && chmod 755 /config/app
```

**Service script pattern** (`services.d/app/run`):
```bash
#!/usr/bin/with-contenv bashio
# shellcheck shell=bash

bashio::log.info "Starting App..."
cd /app || bashio::exit.nok "Could not change to /app"
exec /usr/bin/myapp --config /config/app.conf
```

Services must run in the foreground via `exec`. Never use daemon mode or `&`.

### Step 5: Configure Ingress (if needed)

For add-ons with a web UI, set `ingress: true` and `ingress_port: 8099` in `config.yaml`, then add nginx as a reverse proxy. See `references/generate-dockerfile-ha-addon.md` Step 4 for the complete nginx ingress configuration pattern including `ingress.conf`, the `20-nginx.sh` init script, and the nginx service run script.

### Step 6: Test and Finalize

```bash
# Test the build
docker build \
    --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:trixie \
    --build-arg BUILD_ARCH=amd64 \
    -t test-addon .

docker run --rm test-addon

# Regenerate manifests after creating/modifying add-on files
.github/scripts/manifest.sh -g -d -r -c
```

Verify consistency: nginx listen port matches `ingress_port`, ENV defaults match `options`, volume mounts match `map` entries. Never set `EXPOSE` for the ingress port.

## Existing Add-ons in This Repo

| Add-on | Base | Copy Strategy |
|--------|------|---------------|
| **romm** | Alpine | Python runtime + venv + app code + nginx |
| **profilarr** | Debian | `/app` directory, reinstalls Python deps |
| **huntarr** | Debian | `/app` directory, uses Python venv |
| **cleanuparr** | Debian | Binary + `.so` libs + `wwwroot` |

## Additional Resources

### Reference Files

- **`references/generate-dockerfile-ha-addon.md`** - Complete Dockerfile generation guide with two-stage wrapper pattern, checklists, rootfs patterns, ingress setup, common mistakes, and real examples from this repo
- **`references/bashio-reference.md`** - Bashio API reference (logging, config, API calls)
- **`references/config-reference.md`** - Full config.yaml schema reference (options, schema types, permissions)
- **`references/s6-overlay.md`** - s6-overlay process supervision documentation

### Scripts

- **`scripts/discover.sh`** - Analyzes Docker images and GitHub repos to extract add-on configuration data

### Templates

- **`templates/ingress-nginx-s6-v3/`** - Full ingress-enabled add-on template with nginx and s6
- **`scaffold/`** - Basic add-on scaffold without ingress
