# Home Assistant Add-on Common Framework

Shared helper scripts and utilities for Home Assistant add-ons. This framework provides consistent, tested functions for logging, configuration, environment management, and common setup patterns.

## Installation

In your add-on's Dockerfile, add the framework installation after copying rootfs:

```dockerfile
# Download and install common framework
RUN apk add --no-cache curl && \
    FRAMEWORK_VERSION=$(curl -s https://raw.githubusercontent.com/rigerc/ha-apps/main/common/version.txt) && \
    curl -fsSL "https://raw.githubusercontent.com/rigerc/ha-apps/main/common/scripts/install-framework.sh" -o /tmp/install.sh && \
    bash /tmp/install.sh "${FRAMEWORK_VERSION}" && \
    rm -f /tmp/install.sh
```

## Usage

Source individual libraries in your init or service scripts:

```bash
# Source logging library
# shellcheck source=/usr/local/lib/ha-framework/ha-log.sh
source /usr/local/lib/ha-framework/ha-log.sh

# Source environment helpers
# shellcheck source=/usr/local/lib/ha-framework/ha-env.sh
source /usr/local/lib/ha-framework/ha-env.sh

# Source configuration helpers
# shellcheck source=/usr/local/lib/ha-framework/ha-config.sh
source /usr/local/lib/ha-framework/ha-config.sh

# Source template helpers
# shellcheck source=/usr/local/lib/ha-framework/ha-template.sh
source /usr/local/lib/ha-framework/ha-template.sh
```

## Library Modules

### ha-log.sh
Structured logging with component scoping and log level control.

```bash
ha::log::init "myapp"  # Creates log_info, log_debug, etc.
log_info "Application starting"
ha::log::section "Database setup"
ha::log::banner "My App" "1.0.0"
```

### ha-env.sh
Environment variable export to both shell and s6-overlay.

```bash
ha::env::export "MY_VAR" "some_value"
ha::env::export_config "my_option" "MY_VAR"
ha::env::export_required "required_option" "REQUIRED_VAR"
```

### ha-config.sh
Configuration reading and validation helpers.

```bash
ha::config::require "database.host"
ha::config::get "log_level" "info"
ha::config::validate_port "web_port"
ha::config::validate_url "api_url"
```

### ha-dirs.sh
Directory creation and symlink management.

```bash
ha::dirs::ensure "/config/data" "755"
ha::dirs::create_subdirs "/config" "data" "logs" "cache"
ha::symlink::create "/data/library" "/romm/library"
ha::symlink::update "/data/library" "/romm/library"
```

### ha-secret.sh
Secret generation and management.

```bash
ha::secret::generate "/data/.secret_key"
ha::secret::ensure "auth_secret" "/data/.auth_secret"
```

### ha-validate.sh
Common validation functions.

```bash
ha::validate::port "8080"
ha::validate::url "https://api.example.com"
ha::validate::not_empty "${value}" "API_KEY"
```

### ha-template.sh
Template rendering utilities for tempio (Go templates) and sed-style substitutions.

```bash
# Render tempio Go template with variables
ha::template::render ingress.gtpl /etc/nginx/servers/ingress.conf \
    ingress_interface="${ingress_interface}" \
    ingress_port="^${ingress_port}" \
    app_port="^${APP_PORT}"

# Find template file in standard search paths
template_path=$(ha::template::find "config.gtpl")

# Check if template exists
if ha::template::exists "ingress.gtpl"; then
    ha::template::render "ingress.gtpl" /etc/nginx/ingress.conf port="8080"
fi

# Sed-style substitution for simple templates
ha::template::substitute /etc/nginx.conf.template /etc/nginx/conf \
    port="8080" host="0.0.0.0"

# Render with JSON data
ha::template::render_json template.gtpl /etc/output.conf '{"key": "value"}'

# Validate nginx config
ha::template::validate_nginx /etc/nginx/servers/ingress.conf
```

## Version

Current version: 1.1.0
