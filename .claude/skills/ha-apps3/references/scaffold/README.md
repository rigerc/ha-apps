# APP_NAME Add-on Scaffold

<!-- CUSTOMIZE: Replace APP_NAME throughout this file with your add-on's actual name. -->

This is a **Home Assistant add-on** that wraps APP_NAME with ingress support,
allowing you to access the web interface directly from the Home Assistant sidebar.

## How to Use This Scaffold

This directory is a **reusable template** for wrapping any web-based Docker
application as a Home Assistant add-on.  Every file that needs editing is
marked with `# CUSTOMIZE:` comments.

### Quick-start checklist

1. Copy this directory to `<repo-root>/<your-addon-slug>/`
2. Rename the `rootfs/etc/services.d/APP_NAME/` directory to your slug
3. Run a global search-and-replace:
   - `APP_NAME` → your add-on's human-readable name (e.g., `My App`)
   - `app_name` → your add-on's slug (e.g., `my_app`, lowercase + underscores)
   - `APP_PORT` → the internal port your application listens on (e.g., `8080`)
   - `APP_INGRESS_PORT` → the ingress port from `config.yaml` (e.g., `8099`)
4. Update `config.yaml`: slug, version, arch, options/schema, ingress_port
5. Update `build.yaml`: base images, project URL, labels
6. Update `Dockerfile`: upstream image, packages, exec command
7. Update `DOCS.md`: application description, options table, links
8. Run `.github/scripts/manifest.sh` to regenerate auto-generated files

### File reference

| File | Purpose |
|------|---------|
| `config.yaml` | Add-on manifest: name, version, options, ingress config |
| `build.yaml` | Base images per architecture, OCI labels |
| `Dockerfile` | Multi-stage build: copy from upstream, install deps |
| `DOCS.md` | User-facing documentation |
| `translations/en.yaml` | UI labels for config options |
| `rootfs/etc/cont-init.d/00-banner.sh` | Startup banner log line |
| `rootfs/etc/cont-init.d/10-app-setup.sh` | Read options, create dirs, export env vars |
| `rootfs/etc/cont-init.d/20-nginx.sh` | Patch nginx with ingress IP/port from HA |
| `rootfs/etc/services.d/APP_NAME/run` | Start the application (foreground) |
| `rootfs/etc/services.d/APP_NAME/finish` | Handle application exit/crash |
| `rootfs/etc/services.d/nginx/run` | Wait for backend, start nginx |
| `rootfs/etc/services.d/nginx/finish` | Handle nginx exit/crash |
| `rootfs/etc/nginx/nginx.conf` | Main nginx configuration |
| `rootfs/etc/nginx/servers/ingress.conf` | Ingress proxy server block |
| `rootfs/etc/nginx/includes/proxy_params.conf` | Forwarded headers |
| `rootfs/etc/nginx/includes/server_params.conf` | Security headers |
| `rootfs/etc/nginx/includes/resolver.conf` | Docker DNS resolver |
| `rootfs/etc/nginx/includes/mime.types` | MIME type map |
| `rootfs/usr/local/lib/ha-log.sh` | Shared logging library |

## Logging Framework

The scaffold includes a shared logging library (`ha-log.sh`) that provides:

- **Log levels**: trace, debug, info, warning, error — controlled by the `log_level` option
- **Timestamps**: ISO 8601 format on every message
- **Component prefixes**: `[setup]`, `[nginx]`, `[APP_NAME]` etc.
- **File logging**: opt-in via `HA_LOG_FILE` environment variable with automatic rotation
- **Short-form helpers**: call `ha::log::init "component"` once, then use `log_info`, `log_debug`, etc.

### Usage in scripts

```bash
#!/usr/bin/with-contenv bashio

source /usr/local/lib/ha-log.sh

# One-time init — generates log_info, log_debug, log_warn, log_error shortcuts
ha::log::init "my-component"

log_info  "Server started on port 8080"
log_debug "Processing request: GET /"
log_warn  "Config not found, using defaults"
log_error "Failed to connect to database"

# Or use the full API with explicit component name
ha::log::info  "nginx" "Proxy started"
ha::log::error "APP_NAME" "Fatal startup error"
```

## Architecture

```
HA Supervisor
    |
    | (ingress request to /api/hassio_ingress/<addon>/)
    v
nginx (services.d/nginx)
    |  listening on %%interface%%:%%port%%
    |  only allows 172.30.32.2 (HA supervisor)
    |
    | proxy_pass http://127.0.0.1:APP_PORT
    v
APP_NAME (services.d/APP_NAME)
    |  listening on 0.0.0.0:APP_PORT
    |
    v
  /config, /share (persistent volumes)
```

### Startup sequence

1. s6-overlay runs `cont-init.d/` scripts in filename order:
   - `00-banner.sh` — print add-on name to log
   - `10-app-setup.sh` — read options, create dirs, write env vars
   - `20-nginx.sh` — query HA for ingress IP/port, patch nginx config
2. s6-overlay starts all `services.d/` services in parallel:
   - `APP_NAME/run` — start the application
   - `nginx/run` — wait for backend TCP port, then start nginx
3. nginx proxies all `172.30.32.2` ingress requests to the app's internal port

### s6-overlay v3 key points

- `init: false` in `config.yaml` is REQUIRED for s6-overlay v3 base images
- Service `run` scripts MUST use `exec` as the last command (replaces the shell)
- Service `finish` scripts receive the exit code as `$1`
- `with-contenv` in the shebang injects env vars from `/var/run/s6/container_environment/`
- To pass variables from `cont-init.d` to services, write to `/var/run/s6/container_environment/`

## Local Development

```bash
# Build the add-on image (from the add-on directory)
docker build \
  --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base:3.21 \
  --build-arg BUILD_ARCH=amd64 \
  -t local/app-name-test .

# Run locally to inspect the container
docker run --rm -it \
  -e SUPERVISOR_TOKEN=test-token \
  -p 8099:8099 \
  local/app-name-test

# Test the health endpoint
curl -f http://localhost:8099/health
```

## Repository integration

After copying and customising the scaffold, integrate it with the repo tooling:

```bash
# Regenerate manifest.json, dependabot.yml, release-please.yaml, and CI
.github/scripts/manifest.sh -g -d -r -c

# Add the new add-on to release-please config
# Edit .github/release-please-config.json and add:
#   "packages": { "app_name": { ... } }
```
