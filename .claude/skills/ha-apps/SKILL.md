---
name: ha-apps
description: This skill should be used when user asks to "create a Home Assistant add-on", "scaffold an add-on", "wrap a Docker image for HA", "convert a Docker app to Home Assistant", "configure ingress for an add-on", "add ports to an add-on", "choose a base image for an HA add-on", "set up a sidebar panel in Home Assistant", "should I use ingress or ports", "add a webui button", "test an add-on locally", or "analyze a Docker image for add-on creation". Also activates when user mentions config.yaml, build.yaml, ingress_port, ports_description, s6-overlay, or bashio in the context of Home Assistant add-on development.
---

# Home Assistant Add-on Creator

Skill for creating production-quality Home Assistant add-ons that wrap existing Docker images with ingress (embedded sidebar web UI) support. Uses opinionated scaffold in `references/scaffold/` which targets s6-overlay v3 base images with nginx reverse proxy.

## Purpose

Wrap any containerized application as a Home Assistant add-on that:
- Appears as a sidebar panel (ingress) without exposing host ports
- Runs under s6-overlay v3 process supervision
- Reads configuration through HA add-on options UI
- Persists data to `/config` (addon_config mount)
- Supports aarch64 and amd64 architectures

## Workflow Overview

1. **Discover** — analyze source image or repository
2. **Scaffold** — copy template and rename placeholders
3. **Configure** — customize five key files
4. **Test** — build and run locally, then install in HA

**Docker requirement:** Steps 1 and 5 require a working `docker` CLI. Before running either step, check that `docker` is available (e.g., `command -v docker`). If Docker is not installed or not accessible (common in WSL without Docker Desktop integration), inform the user that Docker is unavailable and wait for instructions. Do not skip discovery or fabricate results — the user may provide information manually, run commands elsewhere, or fix Docker setup first.

---

## Step 1: Discover Source Application

Run the discovery script against a Docker image or GitHub repository:

```bash
bash .claude/skills/ha-apps3/scripts/discover.sh <docker-image-or-github-url>

# Examples
bash .claude/skills/ha-apps3/scripts/discover.sh ghcr.io/someuser/myapp:latest
bash .claude/skills/ha-apps3/scripts/discover.sh https://github.com/someuser/myapp
```

Record from the output:
- **Upstream image + tag** — goes in the first `FROM` line of the Dockerfile
- **Internal port** — the port the app listens on; nginx proxies ingress to this
- **Environment variables** — become `options`/`schema` entries in `config.yaml`
- **Volumes** — become `map:` entries
- **Base OS** — determines which HA base image to use (Alpine vs Debian)
- **Multi-arch support** — determines which architectures to list in `config.yaml`

If discovery fails (network error, private image, etc.), the script prints the reason and suggests next steps. Read the output, address the issue, and re-run. For private images, pull them locally with `docker pull` first.

---

## Step 1.5: Analyze Source Code Architecture

After initial discovery, analyze upstream source code to understand runtime requirements, configuration patterns, and integration points that automated discovery cannot detect.

This is especially important for applications with complex startup sequences or incomplete documentation.

**MUST read:** Before customizing the scaffold, you MUST read `references/source-code-analysis.md` to understand how to analyze the upstream application's source code for configuration patterns, data storage, logging, networking, and background processes.

---

## Step 2: Copy and Rename Scaffold

Copy the scaffold into the target add-on directory:

```bash
# Destination is the add-on's directory inside the monorepo
cp -r .claude/skills/ha-apps3/references/scaffold/ myapp/
```

The scaffold uses `APP_NAME` as a placeholder throughout. Replace every occurrence with the actual add-on slug/name (e.g., `myapp`):

```bash
# Rename all files and directories that contain APP_NAME in their name.
# -depth processes children before parents, so directory renames are safe.
find myapp/rootfs -depth -name '*APP_NAME*' | while read -r f; do
    mv "$f" "${f//APP_NAME/myapp}"
done

# Replace APP_NAME in all text file contents
grep -rl 'APP_NAME' myapp/ | xargs sed -i 's/APP_NAME/myapp/g'

# Replace the port placeholder in Dockerfile ENV line only.
# The ${APP_PORT} variable references in run scripts are correct as-is.
sed -i '/^ENV APP_PORT=/s/APP_PORT/8080/g' myapp/Dockerfile
```

---

## Step 3: Customize Five Key Files

### 3a. `config.yaml` — Add-on Manifest

Open `references/scaffold/config.yaml` as a reference. Update these fields:

| Field | What to set |
|-------|-------------|
| `name` | Human-readable display name |
| `version` | `<upstream_version>-1` (e.g., `2.5.1-1`) |
| `slug` | Lowercase, underscores only (e.g., `my_app`) |
| `description` | One-line description |
| `arch` | Remove architectures not supported by upstream |
| `ingress_port` | Pick an unused port (default `8099`); unique across add-ons |
| `panel_icon` | MDI icon name from https://pictogrammers.com/library/mdi/ |
| `options` / `schema` | Add entries for each upstream environment variable to expose |

Keep `init: false` — this is required for s6-overlay v3 base images.

For `map:`, `addon_config:rw` gives the app a persistent `/config` directory. Add `share:rw` only if the app needs access to shared storage.

### 3b. `build.yaml` — Base Images

Choose the base image family based on the upstream OS detected during discovery. Set `labels.project` to the upstream GitHub URL — this is required by the repository's `manifest.sh` to track upstream versions.

**All three base image families share a common foundation:**
- **s6-overlay v3** (3.1.6.2) — process supervision and init system
- **bashio** (0.17.5) — bash library for HA Supervisor API interaction
- **tempio** (2024.11.2) — Go template engine for rendering config files at startup
- **bash**, **curl**, **jq**, **ca-certificates**, **tzdata**
- **Entrypoint:** `/init` (s6-overlay)

#### Quick Selection Guide

| Base Image | When to use | Image Tag |
|-------------|---------------|------------|
| **Alpine** | Upstream is Alpine-based, static binary (Go/Rust), or musl-compatible | `ghcr.io/home-assistant/{arch}-base:3.21` |
| **Alpine + Python** | Python app that doesn't need glibc-linked C extensions | `ghcr.io/home-assistant/{arch}-base-python:3.13-alpine3.21` |
| **Debian** | Requires glibc (.NET, Java, Node.js native modules) | `ghcr.io/home-assistant/{arch}-base-debian:bookworm` |

**MUST read:** Before choosing a base image for `build.yaml`, you MUST read `references/base-images.md` to understand the differences between Alpine, Debian, and Alpine+Python base images — their package managers, included tools, and when to use each variant.

### 3c. `Dockerfile` — Multi-Stage Build

The scaffold uses a multi-stage pattern:

```dockerfile
# Stage 1: upstream image (tracked by manifest.sh — keep on ONE line)
FROM UPSTREAM_IMAGE:UPSTREAM_VERSION AS app-source

# Stage 2: HA wrapper
FROM ${BUILD_FROM}

RUN apk add --no-cache nginx

# Copy the application binary/files from stage 1
COPY --from=app-source /app /app

# Overlay rootfs (init scripts, service definitions, nginx config)
COPY rootfs /

# Make all scripts executable in a single layer
RUN chmod +x \
    /etc/s6-overlay/scripts/banner \
    /etc/s6-overlay/scripts/myapp-setup \
    /etc/s6-overlay/scripts/nginx-setup \
    /etc/s6-overlay/s6-rc.d/myapp/run \
    /etc/s6-overlay/s6-rc.d/myapp/finish \
    /etc/s6-overlay/s6-rc.d/nginx/run \
    /etc/s6-overlay/s6-rc.d/nginx/finish

ENV APP_PORT=8080 APP_HOST=0.0.0.0

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8099/health || exit 1

ARG BUILD_ARCH
LABEL io.hass.type="addon" io.hass.arch="${BUILD_ARCH}"
```

The first `FROM ... AS app-source` line must be on a single line — `manifest.sh` parses it to track the upstream version. If the upstream application is not distributed as a Docker image, install it directly in stage 2 using `apk`/`apt-get`/`pip`/`wget`.

For Debian base images, replace `apk add` with:
```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    && rm -rf /var/lib/apt/lists/*
```

### 3d. `rootfs/etc/s6-overlay/scripts/APP_NAME-setup` — App Configuration

This oneshot init script runs once at container start, before any services. Customize it to:

1. Read add-on options using `bashio::config`:
   ```bash
   my_option="$(bashio::config 'my_option' 'default_value')"
   ```

2. Export values to the s6 environment so service scripts can read them:
   ```bash
   printf '%s' "${my_option}" > /var/run/s6/container_environment/MY_OPTION
   ```

3. Create directories the application needs at startup.

All logging uses bashio directly: `bashio::log.info`, `bashio::log.debug`, `bashio::log.warning`, `bashio::log.error`

### 3e. `rootfs/etc/s6-overlay/s6-rc.d/myapp/run` — Service Start Script

Replace the `exec` line at the bottom with the application's foreground start command. The script **must not** background the process — s6 supervises the PID directly:

```bash
# Replace the placeholder exec line with, e.g.:
exec /app/myapp \
    --host 0.0.0.0 \
    --port "${APP_PORT}" \
    --config /config
```

Use `exec` (not just calling the binary) so the app replaces the shell process and receives signals correctly.

### nginx ingress (automatic)

The nginx server block is rendered at container start by the `nginx-setup` oneshot using **tempio** (a Go template tool pre-installed in all HA base images). The scaffold handles this automatically — no manual nginx configuration needed.

Traffic flows: User clicks sidebar panel → HA ingress gateway → nginx → backend app.

**MUST read:** Before configuring ingress, ports, or webui, you MUST read `references/ingress-and-ports.md` to understand the traffic flow, decision guide for ingress vs ports, supported protocols, and security score implications.

---

## Step 4: Update `translations/en.yaml`

Add an entry for every option in `config.yaml` schema under `configuration`, and for every port in `ports` under `network`:

```yaml
configuration:
  my_option:
    name: "My Option"
    description: "One-sentence description shown in the HA UI."
network:
  8080/tcp: "Web interface"
  1883/tcp: "MQTT broker (optional)"
```

The `network` key provides the same function as `ports_description` in `config.yaml`. Use one or the other — if both are present, `translations/en.yaml` takes precedence. Translations support localization (create `de.yaml`, `fr.yaml`, etc.), while `ports_description` does not.

---

## Step 5: Test Locally

Build the add-on (substitute the correct base image):

```bash
docker build \
  --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base:3.21 \
  --build-arg BUILD_ARCH=amd64 \
  -t local/myapp:test \
  myapp/
```

Run it:

```bash
docker run --rm \
  -v "$(pwd)/test-data:/config" \
  -p 8099:8099 \
  local/myapp:test
```

Check that nginx starts, the backend becomes ready, and the ingress health endpoint responds:

```bash
curl -f http://localhost:8099/health
```

---

## Critical Gotchas

- **`init: false` is required** — s6-overlay v3 base images will not start without this
- **First `FROM` line must be single-line** — `manifest.sh` parses it with a regex
- **`build.yaml labels.project`** — must be the upstream GitHub URL for version tracking
- **nginx `daemon off;`** — already set in `nginx.conf`; do not remove it
- **Services run in foreground** — never use `&` or daemon flags in `run` scripts
- **`armv7`/`armhf`/`i386` are NOT supported** — only `aarch64` and `amd64`
- **After changing `config.yaml` or `Dockerfile`** — run `.github/scripts/manifest.sh`
- **`tempio` is pre-installed** — do not add it to the Dockerfile `apk add`; it's in all HA base images
- **Port configuration via `ENV APP_PORT`** — Dockerfile `ENV APP_PORT` is the single source of truth; `nginx-setup` reads it via `$APP_PORT` and passes it to tempio

---

## Reference Files

Consult these files for detailed information:

**Scaffold templates** (`references/scaffold/`):
- `config.yaml` — fully annotated add-on manifest with all common options
- `build.yaml` — base image selection with available flavours
- `Dockerfile` — multi-stage pattern with inline comments
- `rootfs/etc/s6-overlay/scripts/` — three annotated init oneshots (banner, app setup, nginx)
- `rootfs/etc/s6-overlay/s6-rc.d/` — app and nginx service longruns with dependency declarations
- `rootfs/etc/nginx/templates/ingress.gtpl` — Go template for nginx server block, rendered by tempio
- `rootfs/etc/nginx/includes/` — shared nginx configuration snippets (proxy params, server params)
- `rootfs/usr/local/lib/ha-log.sh` — shared logging library API

**HA add-on documentation** (`references/`):
- **`base-images.md`** — detailed base image selection guide (Alpine, Debian, Alpine+Python)
- **`bashio-reference.md`** — all bashio helper functions with examples
- **`configuration.md`** — complete `config.yaml` option reference with all keys
- **`ingress-and-ports.md`** — ingress, ports, and webUI configuration with decision guide
- **`s6-overlay.md`** — s6-overlay v3 init stages, service scripting, environment
- **`security.md`** — AppArmor profiles, privilege levels, network isolation
- **`source-code-analysis.md`** — source code analysis patterns by language (Go, Python, Node.js, Rust)
- **`testing.md`** — local testing, integration testing, CI setup
- **`publishing.md`** — publishing to the community add-on store
- **`repository.md`** — setting up a custom add-on repository
- **`communication.md`** — inter-add-on communication, service discovery
- **`presentation.md`** — icons, logos, panel customization
- **`tutorial.md`** — official HA add-on development tutorial

**Discovery script** (`scripts/discover.sh`):
- Analyzes Docker images and GitHub repos — run this first to understand the upstream
