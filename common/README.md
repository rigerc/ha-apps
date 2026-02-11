# Home Assistant Add-on Common Framework

Shared helper scripts for Home Assistant add-ons in this repository. Provides consistent logging, configuration reading, environment variable export, directory management, secret handling, and validation — all built on top of bashio.

**Installed at:** `/usr/local/lib/ha-framework/`
**Current version:** 1.1.0

---

## Installation

Add the following to your add-on's `Dockerfile` after copying `rootfs`:

```dockerfile
RUN apk add --no-cache curl && \
    curl -fsSL "https://raw.githubusercontent.com/rigerc/ha-apps/main/common/scripts/install-framework.sh" \
        -o /tmp/install.sh && \
    chmod +x /tmp/install.sh && \
    /tmp/install.sh --github main && \
    rm -f /tmp/install.sh
```

To pin to a specific version tag instead of `main`:

```dockerfile
/tmp/install.sh --github v1.1.0
```

---

## Usage

Source the libraries you need at the top of any `cont-init.d` or service script:

```bash
#!/usr/bin/with-contenv bashio
# shellcheck shell=bash

# shellcheck source=/usr/local/lib/ha-framework/ha-log.sh
source /usr/local/lib/ha-framework/ha-log.sh

# shellcheck source=/usr/local/lib/ha-framework/ha-env.sh
source /usr/local/lib/ha-framework/ha-env.sh

# shellcheck source=/usr/local/lib/ha-framework/ha-config.sh
source /usr/local/lib/ha-framework/ha-config.sh

# shellcheck source=/usr/local/lib/ha-framework/ha-dirs.sh
source /usr/local/lib/ha-framework/ha-dirs.sh

# shellcheck source=/usr/local/lib/ha-framework/ha-secret.sh
source /usr/local/lib/ha-framework/ha-secret.sh

# shellcheck source=/usr/local/lib/ha-framework/ha-validate.sh
source /usr/local/lib/ha-framework/ha-validate.sh
```

Each library is idempotent — sourcing it multiple times is safe.

---

## Libraries

- [ha-log.sh](#ha-logsh) — Structured logging with level control and optional file output
- [ha-env.sh](#ha-envsh) — Export variables to shell and s6-overlay container environment
- [ha-config.sh](#ha-configsh) — Read and validate add-on configuration options
- [ha-dirs.sh](#ha-dirssh) — Create directories, manage symlinks
- [ha-secret.sh](#ha-secretsh) — Generate and persist cryptographic secrets
- [ha-validate.sh](#ha-validatesh) — Validate values (ports, URLs, emails, ranges, etc.)
- [ha-template.sh](#ha-templatesh) — Render Go templates (tempio) and sed-style substitutions

---

## ha-log.sh

Structured logging built on top of bashio. All output goes to stdout/stderr and appears in the Home Assistant add-on log panel.

### Log levels

| Level     | When to use |
|-----------|-------------|
| `trace`   | Every function call, variable values — maximum verbosity |
| `debug`   | Diagnostic messages useful during development |
| `info`    | Normal operational messages (default) |
| `warning` | Non-fatal issues that may need attention |
| `error`   | Fatal errors — service will likely stop |

Level is read from the `log_level` option in `/data/options.json`. Override via the `HA_LOG_LEVEL` environment variable.

### Short-form helpers (recommended)

Call `ha::log::init` once per script to get `log_info`, `log_debug`, etc. scoped to a component name:

```bash
ha::log::init "myapp"

log_info  "Server started on port 8080"
log_debug "Request received: GET /"
log_warn  "Config file not found, using defaults"
log_error "Failed to connect to database"
log_trace "Entering function foo with args: $*"
```

Output format: `[2024-01-15T10:30:00+0000] [INFO] [myapp] Server started on port 8080`

### Direct API

Use when you need per-call component control:

```bash
ha::log::info    "nginx" "Starting nginx"
ha::log::debug   "nginx" "Config reloaded"
ha::log::warn    "nginx" "Worker process restarted"
ha::log::error   "nginx" "Failed to bind port 80"
ha::log::trace   "nginx" "Entering upstream block"
ha::log::warning "nginx" "Alias for warn"
```

Errors are always emitted regardless of the configured log level.

### Banners and sections

```bash
# Startup banner — use in your first cont-init.d script
ha::log::banner "My App" "2.1.0"
# Output:
# ---
# My App v2.1.0
# Initializing add-on...
# ---

# Section separator — groups related log lines during long init sequences
ha::log::section "Database migration"
# Output: --- Database migration ---
```

### File logging (optional)

Set environment variables before sourcing to enable file logging:

```bash
export HA_LOG_FILE="/data/myapp.log"
export HA_LOG_MAX_SIZE=2097152   # 2 MiB (default: 1 MiB)
export HA_LOG_BACKUPS=5          # rotated files to keep (default: 3)
```

Log messages are written to stdout/stderr **and** the file. The file rotates automatically when `HA_LOG_MAX_SIZE` is exceeded.

### Force level re-read

```bash
# If options may have changed since the script started:
ha::log::reload_level
```

---

## ha-env.sh

Exports environment variables to both the shell and to `/var/run/s6/container_environment/`, making them available to all s6-overlay services that use `#!/usr/bin/with-contenv bashio`.

### Export a literal value

```bash
ha::env::export "APP_PORT" "8080"
ha::env::export "DATABASE_URL" "postgresql://localhost/myapp"
```

### Export from add-on configuration

Reads from `/data/options.json` via bashio:

```bash
# Config key becomes env name (uppercased): log_level -> LOG_LEVEL
ha::env::export_config "log_level"

# Explicit env name
ha::env::export_config "database.host" "DB_HOST"
ha::env::export_config "database.port" "DB_PORT"
```

### Required configuration

Exits with an error if the option is missing:

```bash
ha::env::export_required "database.host"
ha::env::export_required "api_key" "API_KEY"
```

### Optional configuration

Only exports if the option has a value:

```bash
ha::env::export_if_set "smtp_host"
ha::env::export_if_set "smtp_host" "SMTP_HOST"
```

### Default fallback

Only sets the variable if it is not already defined in the environment:

```bash
ha::env::export_default "APP_PORT" "8080"
ha::env::export_default "LOG_LEVEL" "info"
```

### Export from a file

Useful for secrets or values generated at runtime:

```bash
ha::env::export_from_file "AUTH_SECRET" "/data/.secret_key"
```

Exits with error if the file does not exist.

### Export multiple config keys with a prefix

```bash
# Config: metadata_providers.api_key=abc, metadata_providers.url=https://...
ha::env::export_multi "METADATA" "metadata_providers.api_key" "metadata_providers.url"
# Exports: METADATA_METADATA_PROVIDERS_API_KEY, METADATA_METADATA_PROVIDERS_URL
```

### Built-in convenience functions

```bash
# Reads "timezone" config key (default: UTC), exports TZ, logs the value
ha::env::timezone
ha::env::timezone "tz" "America/New_York"   # custom key and default

# Reads "log_level" config key (default: info), exports LOG_LEVEL
ha::env::log_level
ha::env::log_level "log_level" "debug" "APP_LOG_LEVEL"  # custom key, default, env name

# Exports ingress entry URL — does nothing if ingress is not enabled
ha::env::ingress                  # exports INGRESS_ENTRY
ha::env::ingress "BASE_URL"       # custom env name
```

### Service discovery

Checks if an add-on service is available and exports its connection details:

```bash
if ha::env::service_discovery "mysql"; then
    # Now available: MYSQL_HOST, MYSQL_PORT, MYSQL_USERNAME, MYSQL_PASSWORD, MYSQL_DATABASE
    log_info "Using MySQL"
else
    log_info "MySQL not available, falling back to SQLite"
fi

ha::env::service_discovery "redis"
# Exports: REDIS_HOST, REDIS_PORT, REDIS_USERNAME, REDIS_PASSWORD, REDIS_DATABASE
```

---

## ha-config.sh

Wrappers around `bashio::config` with consistent error handling and validation.

### Require a value exists

```bash
ha::config::require "database.host"

# At least one of these must exist:
ha::config::require_any "api_key" "api_token" "api_password"
```

Both exit with an error message if the requirement is not met.

### Read values

```bash
# Returns the value; sets global $_HA_CONFIG_GET_VALUE
log_level="$(ha::config::get "log_level" "info")"

# Normalizes true/yes/on/1/enabled -> "true", false/no/off/0/disabled/"" -> "false"
enabled="$(ha::config::get_bool "feature_enabled" "false")"
if [[ "${enabled}" == "true" ]]; then
    log_info "Feature is enabled"
fi

# Splits a config value into an array (global: $_HA_CONFIG_GET_LIST)
ha::config::get_list "allowed_ips" ","
for ip in "${_HA_CONFIG_GET_LIST[@]}"; do
    log_info "Allowing IP: ${ip}"
done
```

### Validate option values

All validation functions exit with an error message on failure:

```bash
# Port number (default range: 1-65535)
ha::config::validate_port "web_port"
ha::config::validate_port "web_port" 1024 65535   # custom range

# URL format
ha::config::validate_url "api_url"
ha::config::validate_url "api_url" "true"          # require HTTPS

# Email address format
ha::config::validate_email "admin_email"

# One of a set of allowed values
ha::config::validate_choice "log_level" "trace" "debug" "info" "warning" "error"

# File system path (optionally require it to exist)
ha::config::validate_path "data_dir"
ha::config::validate_path "config_file" "true"     # must exist
```

### Map config value to env variable with transformation

```bash
to_upper() { echo "${1^^}"; }
ha::config::map_to_env "log_level" "LOG_LEVEL" "to_upper"
```

The transform function receives the raw config value on `$1` and should echo the transformed value. Defaults to `cat` (no transformation).

### Remove deprecated options

Prevents Supervisor warnings when you remove a config option from an existing add-on:

```bash
ha::config::remove_deprecated "old_option"
ha::config::remove_deprecated "deprecated_feature_flag"
```

Call these at the start of your init script, before any other config reads. They silently do nothing if the key doesn't exist.

---

## ha-dirs.sh

Directory creation, permission management, and symlink handling.

### Create directories

```bash
# Creates the directory if it doesn't exist (idempotent)
ha::dirs::ensure "/config/data"
ha::dirs::ensure "/config/data" "755"
ha::dirs::ensure "/config/data" "755" "abc:users"   # set owner

# Create multiple subdirectories under a base path
ha::dirs::create_subdirs "/config" "data" "logs" "cache" "tmp"
# Creates: /config/data, /config/logs, /config/cache, /config/tmp
```

### Create files

```bash
# Creates an empty file if it doesn't exist (creates parent dirs if needed)
ha::dirs::ensure_file "/config/config.yml"
ha::dirs::ensure_file "/config/.secret" "600"
ha::dirs::ensure_file "/config/.secret" "600" "abc:users"
```

### Clear directory contents

```bash
# Removes everything inside the directory, keeping the directory itself
ha::dirs::clear "/tmp"

# Exclude specific files from deletion
ha::dirs::clear "/config/cache" "*.keep" ".gitkeep"
```

### Symlinks

```bash
# Create a symlink (fails if something already exists at the link path)
ha::symlink::create "/data/library" "/romm/library"

# Force creation — removes whatever exists at the link path first
ha::symlink::create "/data/library" "/romm/library" "true"

# Update a symlink — safe alternative to force create
# Removes and recreates if target changed; warns and removes if not a symlink
ha::symlink::update "/data/library" "/romm/library"

# Create a relative symlink (portable)
ha::symlink::ensure_relative "/romm" "/data/assets" "/var/www/html/assets/romm"
```

`ha::symlink::create` is idempotent: if the symlink already points to the correct target it does nothing.

### Utilities

```bash
# Check if a mount point is read-only (returns 0 if read-only)
if ha::dirs::mount_is_readonly "/boot"; then
    log_warn "/boot is read-only, skipping write"
fi

# Get human-readable directory size
size="$(ha::dirs::get_size "/config/data")"
log_info "Data directory size: ${size}"
```

### Suppress log output

```bash
ha::dirs::set_quiet true
ha::dirs::create_subdirs "/config" "a" "b" "c" "d"   # no log lines
ha::dirs::set_quiet false
```

---

## ha-secret.sh

Cryptographically secure secret generation and persistence. Secrets default to 32-byte hex strings using `openssl rand -hex` (falls back to `/dev/urandom`).

### Ensure a secret exists (primary function)

Checks for the secret in this order: add-on config → existing file → generate new. Returns the secret value on stdout:

```bash
# Secret is stored in /data/.secret_key; config option is "auth_secret"
secret="$(ha::secret::ensure "auth_secret" "/data/.secret_key")"
ha::env::export "AUTH_SECRET" "${secret}"

# Custom length (bytes) and file permissions
jwt_secret="$(ha::secret::ensure "jwt_secret" "/data/.jwt_secret" 64 600)"
```

### Generate a new secret file

Generates and saves a secret, printing the value to stdout. Does nothing if the file already exists:

```bash
ha::secret::generate "/data/.secret_key"
ha::secret::generate "/data/.jwt_secret" 64 600   # 64 bytes, mode 600
```

### Generate a token (alphanumeric)

```bash
api_token="$(ha::secret::generate_token 32)"
session_id="$(ha::secret::generate_token 16 "sess-")"
```

### Hash a password

```bash
hash="$(ha::secret::hash_password "${password}" "${salt}")"
```

Uses `openssl dgst -sha256` (falls back to `sha256sum`). Not suitable as a standalone password storage mechanism — use bcrypt/argon2 for that.

### Base64 encoding/decoding

```bash
encoded="$(ha::secret::to_b64 "my_secret_value")"
decoded="$(ha::secret::from_b64 "${encoded}")"
```

### Validate a key meets minimum requirements

```bash
if ! ha::secret::validate_key "${api_key}" 32; then
    bashio::exit.nok "API key is too short"
fi
```

Returns 1 (does not exit) if the key is too short or empty.

### Compare two secret files (constant-time)

```bash
if ha::secret::compare "/data/secret1" "/data/secret2"; then
    log_info "Secrets match"
fi
```

---

## ha-validate.sh

Standalone validation functions that operate on values directly (not config keys). All functions exit with an error on failure unless noted.

### Port numbers

```bash
ha::validate::port "8080"
ha::validate::port "8080" 1024 65535   # custom range
```

### URLs

```bash
ha::validate::url "https://api.example.com"
ha::validate::url "https://api.example.com" "true"              # require HTTPS
ha::validate::url "http://localhost:8080" "false" "true"         # allow localhost
```

### Non-empty strings

```bash
ha::validate::not_empty "${api_key}" "API_KEY"
```

### Email addresses

```bash
ha::validate::email "user@example.com"
```

### Numeric range

```bash
ha::validate::in_range "50" 0 100 "Percentage"
ha::validate::in_range "${timeout}" 1 300
```

### String length

```bash
ha::validate::min_length "${password}" 8 "Password"
ha::validate::max_length "${username}" 32 "Username"
```

### Regex pattern

```bash
ha::validate::matches_regex "${value}" "^[a-z0-9_]+$" "Field name"
ha::validate::matches_regex "${port}" "^[0-9]+$" "Port" "Must be numeric"
```

### File and directory existence

```bash
ha::validate::file_exists "/config/config.yml"
ha::validate::file_exists "/config/optional.yml" "false"   # returns 1 instead of exiting

ha::validate::dir_exists "/config/data"
ha::validate::dir_exists "/config/optional" "false"
```

### Allowed values

```bash
ha::validate::one_of "info" "Log level" "trace" "debug" "info" "warning" "error"
```

Note the argument order: `value`, `name`, then `allowed1`, `allowed2`, ...

### Boolean checks (return-only, no exit)

```bash
if ha::validate::is_true "${enabled}"; then
    log_info "Feature is enabled"
fi

if ha::validate::is_false "${debug}"; then
    log_info "Debug is off"
fi
```

Recognizes: `true/yes/on/1/enabled` as true, `false/no/off/0/disabled/""` as false.

### IPv4 address

```bash
ha::validate::ip_address "192.168.1.1"
```

---

## ha-template.sh

Template rendering for Go templates (via `tempio`) and sed-style substitutions. Requires `tempio` to be installed in the container for Go template rendering — sed substitution has no extra dependencies.

### Find a template file

Searches standard locations in order, returning the first match:

1. `/config/${HOSTNAME}/templates/`
2. `/etc/${HOSTNAME}/templates/`
3. `/etc/nginx/templates/`
4. `/usr/local/lib/ha-framework/templates/`

```bash
# Returns the full path, or exits with error if not found
template_path="$(ha::template::find "ingress.gtpl")"

# Search custom paths instead (first match wins)
template_path="$(ha::template::find "config.gtpl" "/etc/myapp/templates/" "/config/myapp/")"
```

### Check if a template exists

Returns 0/1 without exiting — useful for optional templates:

```bash
if ha::template::exists "ingress.gtpl"; then
    ha::template::render "ingress.gtpl" /etc/nginx/servers/ingress.conf \
        port="^8080"
fi
```

Uses the same search order as `ha::template::find`.

### Render a Go template (tempio)

Renders a `.gtpl` file using `tempio`. The template file can be an absolute path or a name to be found via `ha::template::find`.

Variables are passed as `key=value` pairs. Prefix numeric values with `^` to pass them as raw numbers rather than quoted strings — this is required for nginx port directives:

```bash
ha::template::render ingress.gtpl /etc/nginx/servers/ingress.conf \
    ingress_interface="${ingress_interface}" \
    ingress_port="^${ingress_port}" \
    app_port="^${APP_PORT}"

# Absolute path also works
ha::template::render /etc/myapp/templates/config.gtpl /etc/myapp/config.yml \
    db_host="${DB_HOST}" \
    db_port="^${DB_PORT}" \
    app_name="myapp"
```

If the output file ends in `.conf`, nginx configuration is validated automatically with `nginx -t` after rendering.

### Render a Go template with JSON data

Use when you have complex or nested data that is easier to pass as a JSON object:

```bash
json_data="$(bashio::var.json key1='value1' key2='value2' port='^8080')"
ha::template::render_json template.gtpl /etc/output.conf "${json_data}"
```

### Sed-style substitution

For simple templates where Go templates are overkill. Placeholders in the template file use `%%name%%` format:

```
# Template file content:
listen %%port%%;
server_name %%hostname%%;
```

```bash
ha::template::substitute /etc/nginx/nginx.conf.template /etc/nginx/nginx.conf \
    port="8080" \
    hostname="myapp.local"
```

Substitution is performed in-place on a copy of the template — the original is not modified. Files ending in `.conf` are nginx-validated after substitution.

### Validate nginx configuration

```bash
ha::template::validate_nginx /etc/nginx/servers/ingress.conf
```

Returns 0 if valid, 1 on failure (logs the nginx error output). Called automatically by `render`, `render_json`, and `substitute` when the output file ends in `.conf`.

### Suppress log output

```bash
ha::template::set_quiet true
ha::template::render "config.gtpl" /etc/myapp/config.yml key="value"
ha::template::set_quiet false
```

---

## Complete example: cont-init.d script

```bash
#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# 10-app-setup.sh — Main initialization for My App

set -e

source /usr/local/lib/ha-framework/ha-log.sh
source /usr/local/lib/ha-framework/ha-env.sh
source /usr/local/lib/ha-framework/ha-config.sh
source /usr/local/lib/ha-framework/ha-dirs.sh
source /usr/local/lib/ha-framework/ha-secret.sh

ha::log::init "myapp"

# --- Startup ---
ha::log::banner "$(bashio::addon.name)" "$(bashio::addon.version)"

# --- Validate required config ---
ha::log::section "Config validation"
ha::config::require "api.url"
ha::config::validate_url "api.url"
ha::config::validate_port "web_port"

# --- Directories ---
ha::log::section "Directories"
ha::dirs::create_subdirs "/config" "data" "logs" "cache"
ha::dirs::ensure "/share/myapp" "775"

# --- Environment ---
ha::log::section "Environment"
ha::env::timezone
ha::env::log_level
ha::env::export_required "api.url" "API_URL"
ha::env::export_config   "web_port" "WEB_PORT"
ha::env::export_if_set   "api.token" "API_TOKEN"
ha::env::export_default  "APP_ENV" "production"

# Export ingress URL if enabled
ha::env::ingress "BASE_URL"

# --- Secrets ---
ha::log::section "Secrets"
secret="$(ha::secret::ensure "secret_key" "/data/.secret_key")"
ha::env::export "SECRET_KEY" "${secret}"

# --- Service discovery ---
ha::log::section "Services"
if ha::env::service_discovery "mysql"; then
    log_info "Using MySQL at ${MYSQL_HOST}:${MYSQL_PORT}"
else
    log_info "No MySQL service found, using SQLite"
fi

# --- Remove deprecated options ---
ha::config::remove_deprecated "old_api_url"
ha::config::remove_deprecated "legacy_flag"

log_info "Initialization complete"
```
