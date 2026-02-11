#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# ha-init.sh — Example initialization script for Home Assistant add-ons
#
# This is a TEMPLATE/EXAMPLE script showing common initialization patterns.
# Copy this file to your add-on's rootfs/etc/cont-init.d/ directory and
# customize it for your needs.
#
# USAGE
#   Copy to your add-on:
#     cp /usr/local/lib/ha-framework/examples/ha-init.sh /etc/cont-init.d/10-init.sh
#
#   Or use the functions directly in your own init scripts.
#
# DESCRIPTION
#   This script demonstrates standard initialization patterns using the
#   ha-framework libraries. It shows how to:
#   - Display a startup banner
#   - Configure timezone and log level
#   - Create required directories
#   - Export configuration as environment variables
#   - Set up ingress
#   - Discover optional services
# ==============================================================================

set -e

# ---------------------------------------------------------------------------
# Source the framework libraries
# ---------------------------------------------------------------------------
# shellcheck source=ha-log.sh
source /usr/local/lib/ha-framework/ha-log.sh

# shellcheck source=ha-env.sh
source /usr/local/lib/ha-framework/ha-env.sh

# shellcheck source=ha-config.sh
source /usr/local/lib/ha-framework/ha-config.sh

# shellcheck source=ha-dirs.sh
source /usr/local/lib/ha-framework/ha-dirs.sh

# ---------------------------------------------------------------------------
# CUSTOMIZE: Set your add-on name here
# ---------------------------------------------------------------------------
readonly ADDON_NAME="My Addon"
readonly ADDON_SLUG="my_addon"

# ---------------------------------------------------------------------------
# Initialize short-form logging helpers
# ---------------------------------------------------------------------------
ha::log::init "init"

# ---------------------------------------------------------------------------
# 1. Display startup banner
# ---------------------------------------------------------------------------
ha::log::section "Startup"
ha::log::banner "${ADDON_NAME}"

# Log the configured log level for visibility
_configured_level="$(bashio::config 'log_level' 'info')"
bashio::log.info "Log level: ${_configured_level}"

# ---------------------------------------------------------------------------
# 2. Configure environment
# ---------------------------------------------------------------------------
ha::log::section "Environment"

# Timezone - reads from "timezone" option, defaults to UTC
ha::env::timezone

# Log level - reads from "log_level" option, defaults to info
ha::env::log_level "log_level" "info" "LOG_LEVEL"

# ---------------------------------------------------------------------------
# 3. Create required directories
# ---------------------------------------------------------------------------
ha::log::section "Directories"

# Ensure /config exists
ha::dirs::ensure "/config"

# Create application-specific subdirectories
# CUSTOMIZE: Adjust these paths for your application
ha::dirs::create_subdirs "/config" "data" "logs" "cache"

# Create share directory if needed
# ha::dirs::ensure "/share/${ADDON_SLUG}"

log_debug "All directories ready"

# ---------------------------------------------------------------------------
# 4. Export configuration as environment variables
# ---------------------------------------------------------------------------
ha::log::section "Configuration"

# CUSTOMIZE: Add your configuration options here
# Examples:
ha::env::export_config "web_port" "WEB_PORT"
ha::env::export_if_set "api_key" "API_KEY"
ha::env::export_required "database.host" "DB_HOST"

# Export secrets without logging
if bashio::config.has_value "database.password"; then
    _password="$(bashio::config "database.password")"
    ha::env::export "DB_PASSWORD" "${_password}"
    unset _password
fi

# ---------------------------------------------------------------------------
# 5. Ingress setup (if enabled)
# ---------------------------------------------------------------------------
if bashio::addon.ingress; then
    ha::log::section "Ingress"
    ha::env::ingress "BASE_URL"
fi

# ---------------------------------------------------------------------------
# 6. Optional service discovery
# ---------------------------------------------------------------------------
ha::log::section "Services"

# MariaDB/MySQL is optional
if ha::env::service_discovery "mysql"; then
    log_info "Using MySQL service"
    # MySQL connection details are now available as:
    # MYSQL_HOST, MYSQL_PORT, MYSQL_USERNAME, MYSQL_PASSWORD, MYSQL_DATABASE
else
    log_notice "No MySQL service found, using SQLite"
fi

# Redis is optional
if ha::env::service_discovery "redis"; then
    log_info "Using Redis service"
    # Redis connection details are now available as:
    # REDIS_HOST, REDIS_PORT, etc.
fi

# ---------------------------------------------------------------------------
# 7. Clean up deprecated options
# ---------------------------------------------------------------------------
ha::log::section "Cleanup"

# CUSTOMIZE: Remove deprecated options from previous versions
# ha::config::remove_deprecated "old_option"
# ha::config::remove_deprecated "deprecated_feature"

# ---------------------------------------------------------------------------
# Complete
# ---------------------------------------------------------------------------
ha::log::section "Ready"
log_info "${ADDON_NAME} initialization complete"
