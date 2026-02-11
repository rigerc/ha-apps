---
name: ha-apps3
description: >-
  This skill should be used when the user asks to "create a Home Assistant add-on",
  "wrap a Docker image for HA", "create an HA add-on", "scaffold an add-on",
  "add ingress to an add-on", "make a sidebar panel in Home Assistant",
  "convert a Docker app to Home Assistant", "wrap an application for Supervisor",
  "analyze a Docker image for add-on creation", or mentions add-on, addon,
  Home Assistant Supervisor, ingress, bashio, or s6-overlay in the context of
  building or wrapping applications.
version: 1.0.0
---

# Home Assistant Add-on Creator

Skill for creating production-quality Home Assistant add-ons that wrap existing Docker images with ingress (embedded sidebar web UI) support. Uses the opinionated scaffold in `references/scaffold/` which targets s6-overlay v3 base images with nginx reverse proxy.

## Purpose

Wrap any containerized application as a Home Assistant add-on that:
- Appears as a sidebar panel (ingress) without exposing host ports
- Runs under s6-overlay v3 process supervision
- Reads configuration through the HA add-on options UI
- Persists data to `/config` (addon_config mount)
- Supports aarch64 and amd64 architectures

## Workflow Overview

1. **Discover** — analyze the source image or repository
2. **Scaffold** — copy the template and rename placeholders
3. **Configure** — customize the five key files
4. **Test** — build and run locally, then install in HA

---

## Step 1: Discover the Source Application

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

If discovery fails (network error, private image, etc.) the script prints the reason and suggests next steps. Read the output, address the issue, and re-run. For private images, pull them locally with `docker pull` first.

---

## Step 1.5: Analyze Source Code Architecture

After the initial discovery, analyze the upstream source code to understand how the application works internally. This deeper analysis reveals runtime requirements, configuration patterns, and integration points that automated discovery cannot detect.

### When to Perform Source Code Analysis

Perform source code analysis when:
- The application has complex startup sequences or initialization requirements
- The upstream documentation is incomplete or unclear
- The app requires specific environment variables or configuration files
- Need to understand how the app handles data persistence, logging, or networking
- The app has multiple processes, services, or background workers

### Source Code Analysis Checklist

**1. Locate and read the main entry point**
- Find `main()`, `app.py`, `index.js`, `Go()` function, or equivalent entry point
- Identify command-line flags, environment variable parsing, and config file loading
- Note required vs optional configuration parameters
- Check for default values and sensible fallbacks

**2. Understand configuration loading**
- Search for `config`, `settings`, `env`, `getenv` patterns in the codebase
- Identify configuration file formats (YAML, JSON, TOML, INI, environment-only)
- Map config keys to the code paths that use them
- Check for config validation and error handling

**3. Trace data storage patterns**
- Search for database connections, file I/O, volume mount points
- Identify where the app stores persistent data (`/data`, `/config`, `/var/lib`)
- Check for database migrations or schema initialization
- Note required directory structures and permissions

**4. Examine logging and monitoring**
- Find log output statements (`print`, `log.Info`, `console.log`, etc.)
- Identify log levels and destinations (stdout, file, syslog)
- Check for health check endpoints (`/health`, `/ping`, `/status`)
- Note any metrics or monitoring integration points

**5. Analyze networking and ports**
- Find the port binding or server start code
- Check for multiple ports (UI port, API port, metrics port)
- Identify hostname/interface binding (0.0.0.0, 127.0.0.1, localhost)
- Look for WebSocket, SSE, or other protocol-specific requirements

**6. Identify background processes**
- Search for thread spawning, goroutines, child processes, or cron jobs
- Check for separate worker processes or services
- Note process supervision requirements and restart policies
- Identify inter-process communication mechanisms

### Common Implementation Patterns by Language

**Go applications:**
- Look for `cobra`, `viper`, or `flag` packages for CLI/config
- Check `main.go` for service initialization sequence
- Find `http.ListenAndServe` or similar for the web server start
- Note `context` usage for graceful shutdown patterns

**Python applications:**
- Check for `click`, `argparse`, `typer` for CLI arguments
- Look for `python-dotenv`, `pydantic`, or `configparser` for config
- Find `uvicorn`, `gunicorn`, or `Flask.run()` for server startup
- Examine `requirements.txt` or `pyproject.toml` for dependencies

**Node.js applications:**
- Look for `commander`, `yargs`, or `minimist` for CLI parsing
- Check `dotenv`, `config`, or `convict` for configuration
- Find `express.listen()`, `http.createServer`, or framework startup
- Examine `package.json` for scripts and dependencies

**Rust applications:**
- Look for `clap` or `structopt` for CLI argument parsing
- Check for `config`, `dotenv`, or `serde` for configuration
- Find `tokio::runtime` or `actix_web::HttpServer` for async runtime
- Examine `Cargo.toml` for features and dependencies

### Mapping Analysis to Scaffold Configuration

After completing the source code analysis:

**config.yaml options/schema:**
- Add entries for each required environment variable
- Set sensible defaults matching the application's built-in defaults
- Group related options logically (database, logging, networking)
- Add validation for required vs optional values

**10-app-setup.sh:**
- Export discovered environment variables to `/var/run/s6/container_environment/`
- Create required directories with proper ownership
- Generate configuration files from templates if needed
- Validate configuration before services start

**myapp/run script:**
- Construct the command-line arguments based on the analysis
- Set required environment variables before exec
- Configure logging output for capture by s6
- Ensure the app runs in the foreground (no daemon mode)

**Dockerfile:**
- Install runtime dependencies discovered during analysis
- Copy configuration templates or default files
- Set build-time `ARG` values for version tracking
- Configure health checks based on discovered endpoints

### Analysis Tools and Techniques

**Static analysis without cloning:**
- Use GitHub's code search (`code?q=repo:user/repo+main`)
- Browse key files directly on GitHub web interface
- Review CI/CD workflows (`.github/workflows/`) for runtime commands
- Check Dockerfiles or docker-compose for environment patterns

**Local cloning when needed:**
```bash
git clone --depth 1 https://github.com/user/repo.git /tmp/repo-analysis
cd /tmp/repo-analysis

# Search for configuration patterns
grep -r "getenv\|getenv\|os.Getenv" --include="*.py" --include="*.go" .
grep -r "config\|settings" --include="*.yaml" --include="*.json" .

# Find the main entry point
find . -name "main.go" -o -name "app.py" -o -name "index.js" -o -name "main.rs"
```

**Container inspection:**
```bash
# Run the upstream image and explore
docker run --rm --entrypoint sh UPSTREAM_IMAGE:TAG
# Inside: inspect /app, examine processes, check environment
```

---

## Step 2: Copy and Rename the Scaffold

Copy the scaffold into the target add-on directory:

```bash
# Destination is the add-on's directory inside the monorepo
cp -r .claude/skills/ha-apps3/references/scaffold/ myapp/
```

The scaffold uses `APP_NAME` as a placeholder throughout. Replace every occurrence with the actual add-on slug/name (e.g., `myapp`):

```bash
# Rename the services.d directory
mv myapp/rootfs/etc/services.d/APP_NAME myapp/rootfs/etc/services.d/myapp

# Replace the placeholder string in all text files
grep -rl APP_NAME myapp/ | xargs sed -i 's/APP_NAME/myapp/g'

# Replace the port placeholder in the Dockerfile ENV line only.
# The ${APP_PORT} variable references in run scripts are correct as-is.
sed -i '/^ENV APP_PORT=/s/APP_PORT/8080/g' myapp/Dockerfile
```

---

## Step 3: Customize the Five Key Files

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

Choose the base image family based on the upstream OS detected during discovery:

```yaml
# Alpine-based (preferred — smaller, faster)
build_from:
  aarch64: ghcr.io/home-assistant/aarch64-base:3.21
  amd64: ghcr.io/home-assistant/amd64-base:3.21

# Debian-based (when upstream requires glibc)
build_from:
  aarch64: ghcr.io/home-assistant/aarch64-base-debian:bookworm
  amd64: ghcr.io/home-assistant/amd64-base-debian:bookworm

# Alpine + Python (for Python apps)
build_from:
  aarch64: ghcr.io/home-assistant/aarch64-base-python:3.13-alpine3.21
  amd64: ghcr.io/home-assistant/amd64-base-python:3.13-alpine3.21
```

All HA base images include: s6-overlay v3, bashio, curl, ca-certificates, tzdata. Set `labels.project` to the upstream GitHub URL — this is required by the repository's `manifest.sh` to track upstream versions.

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
    /etc/cont-init.d/*.sh \
    /etc/services.d/myapp/run \
    /etc/services.d/myapp/finish \
    /etc/services.d/nginx/run \
    /etc/services.d/nginx/finish \
    /usr/local/lib/ha-log.sh

ENV APP_PORT=8080 APP_HOST=0.0.0.0

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8099/health || exit 1

ARG BUILD_ARCH
LABEL io.hass.type="addon" io.hass.arch="${BUILD_ARCH}"
```

The first `FROM ... AS app-source` line must be on a single line — `manifest.sh` parses it to track the upstream version. If the upstream application is not distributed as a Docker image, install it directly in stage 2 using `apk`/`apt-get`/`pip`/`wget`.

For Debian base images, replace `apk add` with `apt-get`:
```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    && rm -rf /var/lib/apt/lists/*
```

### 3d. `rootfs/etc/cont-init.d/10-app-setup.sh` — App Configuration

This init script runs once at container start, before any services. Customize it to:

1. Read add-on options using `bashio::config`:
   ```bash
   my_option="$(bashio::config 'my_option' 'default_value')"
   ```

2. Export values to the s6 environment so service scripts can read them:
   ```bash
   printf '%s' "${my_option}" > /var/run/s6/container_environment/MY_OPTION
   ```

3. Create directories the application needs at startup.

All logging uses the shared `ha-log.sh` library (already sourced at the top of the script). Use `log_info`, `log_debug`, `log_warn`, `log_error` — no bashio calls needed for logging.

### 3e. `rootfs/etc/services.d/myapp/run` — Service Start Script

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

The nginx server block is rendered at container start by `20-nginx.sh` using **tempio** (a Go template tool pre-installed in all HA base images). The template at `rootfs/etc/nginx/templates/ingress.gtpl` receives these variables:

| Template variable | Source |
|-------------------|--------|
| `{{ .ingress_interface }}` | `bashio::addon.ip_address` — container IP as seen by HA |
| `{{ .ingress_port }}` | `bashio::addon.ingress_port` — dynamically assigned port |
| `{{ .app_port }}` | `$APP_PORT` — from Dockerfile ENV instruction |

**No manual nginx configuration is needed.** The `proxy_pass` directive uses `{{ .app_port }}` which is automatically injected from the Dockerfile's `ENV APP_PORT` value.

**How ingress traffic flows:**
1. The user clicks the sidebar panel in HA.
2. HA's ingress gateway authenticates the user and forwards the request to `{{ .ingress_interface }}:{{ .ingress_port }}` inside the container, adding an `X-Ingress-Path` header with the full path prefix (e.g. `/api/hassio_ingress/<token>`).
3. nginx proxies the request to the backend on `127.0.0.1:{{ .app_port }}`, forwarding `X-Ingress-Path` to the backend (already set in `proxy_params.conf`).

**Authentication:** HA handles it. The backend application does not need to implement login for ingress access — only `172.30.32.2` (the HA ingress gateway) can reach nginx, and the user is already authenticated before the request arrives.

**Supported protocols:** HTTP/1.x, streaming, and WebSockets. HTTP/2 is **not** supported by the HA ingress gateway.

**Security score:** Enabling `ingress: true` adds +2 to the add-on security score (base is 5). This is the largest single boost available and increases user trust in the add-on store.

**Apps that embed absolute paths:** If the app generates HTML with absolute paths like `href="/static/app.js"` and does not support a configurable base URL, two options exist:

- **Preferred:** Configure the app to use its base URL from the `X-Ingress-Path` header or the `APP_BASE_URL` environment variable (written by `10-app-setup.sh` via `bashio::addon.ingress_entry`). Many modern web apps support a `BASE_URL` / `ROOT_PATH` config option for exactly this purpose.
- **Fallback:** Uncomment the `sub_filter` and `proxy_redirect` directives in `ingress.gtpl` — nginx rewrites the paths in HTML responses on the fly.

**Additional ingress config options** (add to `config.yaml` when needed):

| Option | Default | When to use |
|--------|---------|-------------|
| `ingress_entry` | `/` | Change the URL entry point path (e.g. `/ui` for apps that serve at a sub-path) |
| `ingress_stream` | `false` | Set to `true` for apps with heavy server-sent events (SSE) or chunked streaming — disables nginx buffering at the gateway level |
| `panel_admin` | `true` | Set to `false` to show the sidebar panel for non-admin users too |

---

## Step 4: Update `translations/en.yaml`

Add an entry for every option added to `config.yaml schema`:

```yaml
configuration:
  my_option:
    name: "My Option"
    description: "One-sentence description shown in the HA UI."
```

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
- **`tempio` is pre-installed** — do not add it to Dockerfile `apk add`; it's in all HA base images
- **Port configuration via `ENV APP_PORT`** — the Dockerfile `ENV APP_PORT` is the single source of truth; `20-nginx.sh` reads it via `$APP_PORT` and passes it to tempio

---

## Reference Files

Consult these files for detailed information:

**Scaffold templates** (`references/scaffold/`):
- `config.yaml` — fully annotated add-on manifest with all common options
- `build.yaml` — base image selection with available flavours
- `Dockerfile` — multi-stage pattern with inline comments
- `rootfs/etc/cont-init.d/` — three annotated init scripts (banner, app setup, nginx)
- `rootfs/etc/services.d/` — app and nginx service run/finish scripts
- `rootfs/etc/nginx/templates/ingress.gtpl` — Go template for nginx server block, rendered by tempio
- `rootfs/etc/nginx/includes/` — shared nginx configuration snippets (proxy params, server params)
- `rootfs/usr/local/lib/ha-log.sh` — shared logging library API

**HA add-on documentation** (`references/`):
- **`configuration.md`** — complete `config.yaml` option reference with all keys
- **`bashio-reference.md`** — all bashio helper functions with examples
- **`s6-overlay.md`** — s6-overlay v3 init stages, service scripting, environment
- **`security.md`** — AppArmor profiles, privilege levels, network isolation
- **`testing.md`** — local testing, integration testing, CI setup
- **`publishing.md`** — publishing to the community add-on store
- **`repository.md`** — setting up a custom add-on repository
- **`communication.md`** — inter-add-on communication, service discovery
- **`presentation.md`** — icons, logos, panel customization
- **`tutorial.md`** — official HA add-on development tutorial

**Discovery script** (`scripts/discover.sh`):
- Analyzes Docker images and GitHub repos — run this first to understand the upstream
