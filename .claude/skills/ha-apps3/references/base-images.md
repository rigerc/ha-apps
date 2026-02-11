# Home Assistant Add-on Base Images Reference

This reference provides detailed information about the Home Assistant base images available for add-on development. All base images share a common foundation but differ in OS, package managers, and included tools.

## Common Foundation (All Variants)

Every HA base image includes:

| Component | Version | Purpose |
|-----------|---------|---------|
| **s6-overlay** | 3.1.6.2 | Process supervision and init system |
| **bashio** | 0.17.5 | Bash library for HA Supervisor API interaction |
| **tempio** | 2024.11.2 | Go template engine for rendering config files at startup |
| **bash** | — | Shell (bash version varies by base) |
| **curl** | — | HTTP client for API calls and health checks |
| **jq** | — | JSON parsing for configuration handling |
| **ca-certificates** | — | SSL certificates for HTTPS connections |
| **tzdata** | — | Timezone database |

**Entrypoint:** `/init` (s6-overlay) — all base images use s6-overlay as PID 1

## Choosing the Right Base Image

The choice of base image depends primarily on:
1. **Upstream application's OS** — What OS is the upstream Docker image based on?
2. **C library requirements** — Does the app need glibc or is musl compatible?
3. **Package dependencies** — What package manager does the app use (apk, apt, pip)?
4. **Image size preference** — Is smallest size important or is compatibility preferred?

### Quick Decision Tree

```
Is upstream image Alpine-based?
├── Yes ──→ Use Alpine base (smallest)
└── No
    ├── Is it Debian/Ubuntu-based?
    │   └── Use Debian base
    ├── Is it a Python app?
    │   ├── Can use musl wheels? ──→ Use Alpine+Python base
    │   └── Needs glibc wheels? ──→ Use Debian base + install Python
    └── Does it require glibc (.NET, Java)?
        └── Use Debian base
```

## Alpine Base

**Image tags:**
```
ghcr.io/home-assistant/aarch64-base:3.21
ghcr.io/home-assistant/amd64-base:3.21
```

Built on `alpine:3.21`. Smallest image size. Use for Go binaries, Rust binaries, static applications, or anything that runs on musl libc.

| Component | Detail |
|-----------|--------|
| **C library** | **musl libc** — binaries compiled against glibc will not run |
| **Shell** | `/bin/ash` (BusyBox) — bash is installed but ash is the default `SHELL` |
| **Package manager** | `apk` (Alpine Package Keeper) |
| **Extra packages** | `bind-tools` (dig, nslookup, host), `libstdc++`, `xz` |
| **Extra tools** | **jemalloc 5.3.0** (memory allocator, compiled from source) |
| **Env vars** | `LANG=C.UTF-8`, `UV_EXTRA_INDEX_URL=...musllinux-index/`, s6 tuning vars |
| **Available tags** | `3.13` through `3.21` |

### When to Choose Alpine

The upstream image is Alpine-based, the app is a static binary (Go, Rust), or the app has no glibc-specific dependencies.

**Typical use cases:**
- Go applications (Prometheus exporters, Go-based web services)
- Rust applications (most CLIs, network tools)
- Static binaries with no external dependencies
- Apps that only need Alpine packages from `apk`

**Image size benefit:** Typically 30–80 MB smaller than Debian equivalents

### Dockerfile Pattern (Alpine)

```dockerfile
RUN apk add --no-cache \
    nginx \
    curl \
    jq
```

## Debian Base

**Image tags:**
```
ghcr.io/home-assistant/aarch64-base-debian:bookworm
ghcr.io/home-assistant/amd64-base-debian:bookworm
```

Built on `debian:bookworm-slim`. Use when the upstream application requires glibc, links to Debian-specific shared libraries, or ships pre-compiled `.deb` packages.

| Component | Detail |
|-----------|--------|
| **C library** | **glibc** — full GNU C library compatibility |
| **Shell** | `/bin/bash` (set as default `SHELL`) |
| **Package manager** | `apt-get` (Debian APT) |
| **Extra packages** | `xz-utils` |
| **NOT included** | `bind-tools`, `libstdc++`, jemalloc (install via `apt-get` if needed) |
| **Env vars** | `LANG=C.UTF-8`, `DEBIAN_FRONTEND=noninteractive`, `CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt`, s6 tuning vars |
| **Available tags** | `bookworm`, `trixie` (+ dated versions like `bookworm-2026.02.0`) |

### When to Choose Debian

The upstream image is Debian/Ubuntu-based, the app requires glibc (e.g., .NET, Java, Node.js native modules), or the app uses Debian packages for installation.

**Typical use cases:**
- .NET applications
- Java applications (JAR files, JVM-based services)
- Node.js apps with native modules (sharp, bcrypt, etc.)
- Apps requiring Debian-specific system libraries
- Apps that install `.deb` packages

**Existing add-ons using Debian base:** huntarr, profilarr, cleanuparr (all use `trixie`)

### Dockerfile Pattern (Debian)

Replace `apk add --no-cache` with:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*
```

## Alpine + Python Base

**Image tags:**
```
ghcr.io/home-assistant/aarch64-base-python:3.13-alpine3.21
ghcr.io/home-assistant/amd64-base-python:3.13-alpine3.21
```

Built on top of the Alpine base with CPython compiled from source with full optimizations (`--enable-optimizations`, `--with-lto`).

| Component | Detail |
|-----------|--------|
| **Everything from Alpine** | musl libc, jemalloc, bind-tools, libstdc++, etc. |
| **Python** | **3.13.2** compiled from source with LTO and PGO |
| **pip** | **25.3** (via `ensurepip`) |
| **Symlinks** | `python → python3`, `idle → idle3`, `pydoc → pydoc3` |
| **pip.conf** | `extra-index-url = wheels.home-assistant.io/musllinux-index/`, `prefer-binary = true` |
| **Available tags** | `3.12-alpine3.{16..21}`, `3.13-alpine3.21`, `3.14-alpine3.21` |

### When to Choose Alpine + Python

The upstream is a Python application (Flask, FastAPI, Django, etc.) that does not require glibc-linked C extensions.

**Typical use cases:**
- Pure Python web applications
- Python scripts and tools
- Apps using only Python packages with musl wheels available

The pre-configured `pip.conf` points to HA's musl wheel index, so common scientific/compiled packages install without building from source.

### No Debian + Python Variant Exists

If a Python app requires glibc (e.g., for numpy, scipy, or other C extensions that lack musl wheels), use the Debian base and install Python separately:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*
```

## Version Tags and Updates

### Base Image Versioning

HA base images follow semantic versioning tied to the underlying Alpine/Debian releases:

**Alpine:**
- `3.13` — Latest stable (Alpine 3.13 series)
- `3.14` — Latest stable (Alpine 3.14 series)
- `3.15` through `3.21` — Available Alpine versions

**Debian:**
- `bookworm` — Debian 12 (stable)
- `trixie` — Debian 13 (testing)
- `bookworm-YYYY.MM.DD` — Dated builds for specific rollbacks

**Python:**
- `3.12-alpine3.XX` — Python 3.12 on Alpine
- `3.13-alpine3.XX` — Python 3.13 on Alpine (recommended)
- `3.14-alpine3.XX` — Python 3.14 on Alpine (latest)

### Updating Base Images

When updating the base image in an add-on's `build.yaml`:

1. Update the image tag (e.g., `:3.21` → `:3.22`)
2. Run the add-on locally to verify compatibility
3. Test all functionality before committing

HA base images are updated regularly with security patches and dependency updates. Subscribe to the [Home Assistant blog](https://www.home-assistant.io/blog/) for release announcements.

## Package Installation by Base

| Package | Alpine (apk) | Debian (apt-get) | Python (pip) |
|----------|-----------------|---------------------|---------------|
| **HTTP client** | `curl` | `curl` | — |
| **JSON parser** | `jq` | `jq` | — |
| **DNS tools** | `bind-tools` | `dnsutils` `bind9-dnsutils` | — |
| **Compression** | `xz` | `xz-utils` | — |
| **Process tools** | `procps` | `procps` | — |
| **Network tools** | `iproute2` | `iproute2` | — |
| **Git** | `git` | `git` | — |
| **Build tools** | `build-base` | `build-essential` | — |
| **Python packages** | Use `pip` | Use `pip` | `pip` (wheels on musl index) |

## Architecture Support

All HA base images are available for:

| Architecture | Docker `TARGETARCH` | HA Base Image Suffix |
|-------------|---------------------|----------------------|
| **aarch64** | arm64 | `aarch64-base` |
| **amd64** | amd64 | `amd64-base` |
| **armv7** | arm/v7 | **NOT SUPPORTED** |
| **armhf** | arm/v6 | **NOT SUPPORTED** |
| **i386** | 386 | **NOT SUPPORTED** |

**Only `aarch64` and `amd64` are supported for HA add-ons.**

## Health Checks

All base images support Docker `HEALTHCHECK` directive. Use in `Dockerfile`:

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8099/health || exit 1
```

For Python apps without `curl` installed:

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8099/health')" || exit 1
```

## Common Pitfalls

### Wrong Base Image for App Requirements

**Symptom:** Add-on fails to start with "cannot execute binary file" or "command not found"

**Cause:** App requires glibc but Alpine base was used (or vice versa)

**Fix:** Switch to appropriate base image (Debian for glibc, Alpine for musl)

### Missing Build Dependencies

**Symptom:** Build fails during `pip install` or native module compilation

**Cause:** Base image lacks build tools (gcc, make, etc.)

**Fix:** Add build dependencies in Dockerfile, then remove in final layer (multi-stage build):

```dockerfile
# Build stage
FROM ghcr.io/home-assistant/amd64-base:3.21 AS builder
RUN apk add --no-cache build-base python3-dev
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# Runtime stage
FROM ghcr.io/home-assistant/amd64-base:3.21
COPY --from=builder /usr/local/lib/python3.13/site-packages /usr/local/lib/python3.13/site-packages
```

### Python Wheel Not Available

**Symptom:** `pip install` tries to compile C extension from source and fails

**Cause:** Package lacks musl wheel, using Alpine+Python base

**Fix:** Switch to Debian base and install Python separately, or use `--only-binary :all:` with pip (may not work for all packages)

### Conflicting Package Managers

**Symptom:** `apk` and `apt-get` both used, causing conflicts

**Cause:** Mixing Alpine and Debian base images or patterns

**Fix:** Use only one package manager based on chosen base image
