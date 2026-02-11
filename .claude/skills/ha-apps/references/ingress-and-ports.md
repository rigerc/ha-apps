# Ingress, Ports, and WebUI Configuration Guide

This reference explains networking configuration options for Home Assistant add-ons: ingress (sidebar panel), ports (host port mapping), and webui (direct browser access button).

## nginx Ingress (Sidebar Panel)

Ingress allows the add-on's web interface to appear as a sidebar panel in Home Assistant, without exposing any host ports. This is the most secure and user-friendly access method.

### How Ingress Traffic Flows

```
User clicks sidebar panel in HA
         ↓
HA's ingress gateway authenticates user
         ↓
Forwards request to container IP:ingress_port
         ↓
(Authorized gateway: 172.30.32.2)
         ↓
nginx receives request with X-Ingress-Path header
         ↓
nginx proxies to backend app on 127.0.0.1:APP_PORT
```

**Authentication:** HA handles it. The backend application does not need to implement login for ingress access — only `172.30.32.2` (the HA ingress gateway) can reach nginx, and the user is already authenticated before the request arrives.

### Automatic nginx Configuration

The scaffold configures nginx automatically using **tempio** (a Go template tool pre-installed in all HA base images). The template at `rootfs/etc/nginx/templates/ingress.gtpl` receives these variables:

| Template variable | Source |
|-------------------|--------|
| `{{ .ingress_interface }}` | `bashio::addon.ip_address` — container IP as seen by HA |
| `{{ .ingress_port }}` | `bashio::addon.ingress_port` — dynamically assigned port |
| `{{ .app_port }}` | `$APP_PORT` — from Dockerfile ENV instruction |

**No manual nginx configuration is needed.** The `proxy_pass` directive uses `{{ .app_port }}` which is automatically injected from the Dockerfile's `ENV APP_PORT` value.

### Supported Protocols

- **HTTP/1.x** — Fully supported
- **Streaming** — Server-sent events and chunked responses work
- **WebSockets** — Supported for real-time communication
- **HTTP/2** — **NOT** supported by the HA ingress gateway

### Ingress Configuration Options

These options in `config.yaml` control ingress behavior:

| Option | Default | When to use |
|--------|---------|-------------|
| `ingress` | `false` | Set to `true` to enable sidebar panel |
| `ingress_port` | Pick unused port (e.g., `8099`) | Must be unique across add-ons; internal container port only |
| `ingress_entry` | `/` | Change URL entry point path (e.g., `/ui` for apps that serve at a sub-path) |
| `ingress_stream` | `false` | Set to `true` for apps with heavy server-sent events (SSE) or chunked streaming — disables nginx buffering at the gateway level |
| `panel_icon` | `mdi:blank` | MDI icon name from https://pictogrammers.com/library/mdi/ |
| `panel_title` | Add-on name | Custom title for sidebar panel |
| `panel_admin` | `true` | Set to `false` to show sidebar panel for non-admin users too |

### Security Score Impact

Enabling `ingress: true` adds **+2** to the add-on's security score (base is 5). This is the largest single boost available and increases user trust in the add-on store.

### Apps with Absolute Paths

Some applications generate HTML with absolute paths like `href="/static/app.js"` and do not support a configurable base URL. Two options exist:

**Preferred:** Configure the app to use its base URL from the `X-Ingress-Path` header or `APP_BASE_URL` environment variable. Write this in `10-app-setup.sh`:

```bash
# Export base URL for apps that support it
export APP_BASE_URL="$(bashio::addon.ingress_entry)"
```

Many modern web apps support a `BASE_URL`, `ROOT_PATH`, or `url_base` config option for exactly this purpose.

**Fallback:** Uncomment `sub_filter` and `proxy_redirect` directives in `ingress.gtpl` — nginx rewrites paths in HTML responses on the fly. This works but is less reliable than native base URL support.

## Ports Configuration

The `ports` and `ports_description` options in `config.yaml` control host-level network access. These are **independent** of ingress — each can be used alone or combined.

### How `ports` Works

`ports` maps container ports to host ports, identical to Docker's `-p` flag. Format: `"container-port/protocol": host-port`.

```yaml
ports:
  8080/tcp: 8080      # exposed on host:8080, user can change in UI
  1883/tcp: null       # disabled by default, user can enable in UI
```

**Rules:**
- Setting host port to a **number** exposes it immediately
- Setting host port to **`null`** disables mapping by default — user sees port in HA Network panel and can choose to enable and remap it
- Omitting `ports` entirely means no host ports are exposed

### How `ports_description` Works

`ports_description` provides human-readable labels for each port, displayed in the HA Network configuration UI where users can change port numbers:

```yaml
ports_description:
  8080/tcp: "Web interface"
  1883/tcp: "MQTT broker (optional)"
```

Keys must exactly match those in `ports`. Alternatively, provide descriptions via `translations/en.yaml` under the `network` key.

## WebUI Configuration

`webui` creates an "Open Web UI" button on the add-on's info page. It opens a new browser tab pointing directly to the host port — completely separate from ingress.

```yaml
webui: http://[HOST]:[PORT:8080]/dashboard
```

**Placeholder syntax:**
- `[HOST]` — Resolves to the HA host's address
- `[PORT:8080]` — Resolves to whatever host port the user has mapped container port 8080 to
- `[PROTO:option_name]` — Switches to `https` when a boolean option is `true`:

```yaml
webui: "[PROTO:ssl]://[HOST]:[PORT:8080]"
```

**Requirements:**
- `webui` requires `ports` — the referenced container port must be listed in the `ports` dict
- Without `ports`, the button has no port to link to

## Decision Guide: Ingress vs Ports vs Both

Choose the access pattern based on what the application needs:

| Pattern | config.yaml | When to use |
|---------|-------------|-------------|
| **Ingress only** | `ingress: true`, no `ports` | Web-only app accessed exclusively through HA sidebar. Most secure (+2 security score). No external access. |
| **Ingress + ports (disabled)** | `ingress: true`, `ports` with `null` values | Sidebar primary, but user can optionally expose a port for external API clients or mobile apps. |
| **Ingress + ports (enabled)** | `ingress: true`, `ports` with number values | Sidebar + direct host access. For apps that external services need to reach (e.g., Sonarr calling an add-on's API). |
| **Ports + webui (no ingress)** | `ports` with number values, `webui` URL | App that cannot run behind a sub-path proxy (no base URL support). "Open Web UI" button on info page. |
| **Ports only (non-web)** | `ports` with number values, no `ingress` | Services with no web UI (syslog receiver, MQTT broker, metrics exporter). |
| **Host network + ingress** | `host_network: true`, `ingress: true`, `ingress_port: 0` | App needing host networking (mDNS, DLNA). `ports` is ignored when `host_network` is `true`. Use `ingress_port: 0` for dynamic port assignment. |

**Default recommendation:** Use **ingress only** (no `ports`). This is the most secure pattern, produces the highest security score, and keeps the user experience clean — the app appears as a sidebar panel with no extra network configuration needed.

Add `ports` only when there is a concrete requirement:
- External services or automation tools need to call the app's API directly
- The app exposes non-HTTP protocols (UDP, raw TCP) that cannot go through ingress
- Users specifically need direct host access (e.g., mobile apps that connect to the service)

### Network Paths Are Independent

**Ingress and ports use separate network paths:**
- Ingress traffic flows through HA's internal Docker network (`172.30.32.2` gateway) and never touches host ports
- Port-mapped traffic flows through Docker's port binding on the host interface

Enabling both does not create conflicts — they operate independently.

### Watchdog Configuration

The `watchdog` option can monitor the add-on's health via either path. For ingress add-ons, use the internal container port:

```yaml
watchdog: http://[HOST]:[PORT:8080]/health
```

The `[PORT:8080]` syntax references the container port and resolves it correctly whether or not it's mapped to a host port.

## Common Patterns by Use Case

### Web Application with Sidebar Access

```yaml
ingress: true
ingress_port: 8099
panel_icon: mdi:web
panel_title: "My App"
# No ports, no webui
```

### API Service with Optional External Access

```yaml
ingress: true
ingress_port: 8099
ports:
  8080/tcp: null  # Disabled by default, user can enable
ports_description:
  8080/tcp: "API server (optional)"
```

### Media Server Requiring Direct Access

```yaml
ingress: true
ingress_port: 8099
ports:
  8080/tcp: 8080  # Enabled by default
  1900/udp: 1900 # Streaming protocol
webui: http://[HOST]:[PORT:8080]/
```

### Background Service with No Web UI

```yaml
# No ingress
ports:
  1883/tcp: 1883  # MQTT broker
  514/tcp: 514   # Syslog receiver
ports_description:
  1883/tcp: "MQTT broker"
  514/tcp: "Syslog receiver"
```

### Host Network Application

For applications requiring host networking (mDNS, DLNA, UDP discovery), use `ingress_port: 0` for dynamic port assignment:

```yaml
host_network: true
ingress: true
ingress_port: 0  # Dynamic port assignment — Supervisor picks available port
ingress_stream: true  # Often needed for media streaming
# ports is ignored when host_network is true — all container ports are on host
```

**Why `ingress_port: 0` matters:**
- When `host_network: true`, the container shares the host's network namespace
- Any hard-coded port number may conflict with services already running on the host
- Setting `0` tells the Supervisor to dynamically assign an available port
- The nginx ingress wrapper automatically reads the assigned port via the Supervisor API

**Real-world example: Jellyfin NAS add-on**

```yaml
name: Jellyfin NAS
host_network: true  # Required for DLNA/UPnP
ingress: true
ingress_port: 0  # Dynamic — avoids conflicts with host services
ingress_stream: true  # Enable for media streaming with SSE/chunked responses
init: false
map:
  - addon_config:rw
  - homeassistant_config:rw  # May access HA config for integration
  - media:rw  # Direct access to media files
  - share:rw
  - ssl
panel_icon: mdi:billiards-rack
panel_admin: false  # Allow all HA users to access
options:
  PGID: 0  # Run as root (or specify media user GID)
  PUID: 0
  data_location: /share/jellyfin
# Note: ports ignored with host_network=true — app binds directly to host ports
# Jellyfin typically uses: 8096 (HTTP), 8920 (HTTPS), 1900 (DLNA), 7359 (discovery)
```

**Common use cases for `host_network + ingress_port: 0`:**
- **Media servers** (Jellyfin, Emby, Plex) — DLNA/UPnP requires host network access
- **Home automation bridges** — mDNS discovery needs raw network access
- **Network utilities** — Tools that need to bind to specific host IPs or broadcast

### Complex Port Configuration with Dynamic Ingress

Even without `host_network`, `ingress_port: 0` is useful when the add-on exposes multiple ports and you want to avoid conflicts with other add-ons' ingress ports:

```yaml
ingress: true
ingress_port: 0  # Let Supervisor assign any available port
ingress_stream: true
ports:
  1900/udp: null      # DLNA (disabled by default)
  7359/udp: null      # Discovery (disabled by default)
  8096/tcp: 8096      # Primary HTTP port
  8920/tcp: 8920      # HTTPS port
ports_description:
  1900/udp: "DLNA (optional)"
  7359/udp: "Client discovery (optional)"
  8096/tcp: "Web interface"
  8920/tcp: "HTTPS web interface"
```

**When to use `ingress_port: 0` without `host_network`:**
- The add-on has many mapped ports (increases conflict risk)
- You're building a generic scaffold/template add-on
- You want to avoid manual port coordination across add-ons in the repo
- The ingress port value itself doesn't matter (it's internal to the container)

**Why `ingress_port: 0` matters:**
- When `host_network: true`, the container shares the host's network namespace
- Any hard-coded port number may conflict with services already running on the host
- Setting `0` tells the Supervisor to dynamically assign an available port
- The nginx ingress wrapper automatically reads the assigned port via the Supervisor API

**Real-world example: Jellyfin NAS add-on**

```yaml
name: Jellyfin NAS
host_network: true  # Required for DLNA/UPnP
ingress: true
ingress_port: 0  # Dynamic — avoids conflicts with host services
ingress_stream: true  # Enable for media streaming with SSE/chunked responses
init: false
map:
  - addon_config:rw
  - homeassistant_config:rw  # May access HA config for integration
  - media:rw  # Direct access to media files
  - share:rw
  - ssl
panel_icon: mdi:billiards-rack
panel_admin: false  # Allow all HA users to access
options:
  PGID: 0  # Run as root (or specify media user GID)
  PUID: 0
  data_location: /share/jellyfin
# Note: ports ignored with host_network=true — app binds directly to host ports
# Jellyfin typically uses: 8096 (HTTP), 8920 (HTTPS), 1900 (DLNA), 7359 (discovery)
```

**Common use cases for `host_network + ingress_port: 0`:**
- **Media servers** (Jellyfin, Emby, Plex) — DLNA/UPnP requires host network access
- **Home automation bridges** — mDNS discovery needs raw network access
- **Network utilities** — Tools that need to bind to specific host IPs or broadcast

## Troubleshooting

### Ingress Shows "502 Bad Gateway"

**Causes:**
1. Backend app not running or crashed
2. Wrong `APP_PORT` in Dockerfile (nginx proxying to wrong port)
3. Backend app binds to `127.0.0.1` but nginx tries to reach container IP

**Fixes:**
- Check add-on logs for backend errors
- Verify `ENV APP_PORT=` matches app's listen port
- Ensure app binds to `0.0.0.0` or `0.0.0.0:8080` (not just `127.0.0.1`)

### Port Mapping Not Working

**Causes:**
1. App not listening on expected port
2. Firewall blocking on host
3. Port already in use on host

**Fixes:**
- Check app's configuration for listen port
- Verify host firewall allows the port
- Try a different host port in HA Network panel

### WebUI Button Not Appearing

**Causes:**
1. `webui` references port not in `ports` dict
2. Syntax error in `webui` URL

**Fixes:**
- Ensure referenced port (e.g., `[PORT:8080]`) exists in `ports:`
- Verify URL format: `http://[HOST]:[PORT:8080]/path`

### WebSocket Connections Dropping

**Causes:**
1. HA ingress gateway does not support HTTP/2
2. Timeout settings too short

**Fixes:**
- Ensure app uses WebSockets over HTTP/1.x
- Set `ingress_stream: true` for SSE-heavy apps
- Check app's WebSocket ping/pong interval
