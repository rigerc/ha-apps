#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# 10-app-setup.sh — Application environment setup
#
# Reads add-on options, prepares directories, and exports environment variables
# that the application service (services.d/APP_NAME/run) will consume.
#
# Runs ONCE during container initialisation, before any services start.
# Numbering: 10 — runs after the banner (00) but before nginx (20).
#
# CUSTOMIZE: Adapt this script to the configuration requirements of the
#            application you are wrapping.
# ==============================================================================

set -e

# Source the shared logging library from HA framework
# shellcheck source=/usr/local/lib/ha-framework/ha-log.sh
source /usr/local/lib/ha-framework/ha-log.sh

# Initialise short-form logging helpers (log_info, log_debug, log_warn, log_error)
ha::log::init "setup"

log_info "Setting up APP_NAME..."

# ---------------------------------------------------------------------------
# Read add-on options
# CUSTOMIZE: add or remove bashio::config calls to match your config.yaml options
# ---------------------------------------------------------------------------
declare log_level
declare timezone

log_level="$(bashio::config 'log_level' 'info')"
timezone="$(bashio::config 'timezone' 'UTC')"

log_debug "log_level = ${log_level}"
log_debug "timezone  = ${timezone}"

# ---------------------------------------------------------------------------
# Persist environment variables for service scripts
#
# s6-overlay v3 reads /var/run/s6/container_environment/* and makes those
# variables available via "with-contenv" (the shebang in service run scripts).
#
# Write ONLY variables that the service script needs but that are not already
# available from the HA base image.
# ---------------------------------------------------------------------------
declare env_dir="/var/run/s6/container_environment"

# Timezone
printf '%s' "${timezone}" > "${env_dir}/TZ"
log_debug "TZ persisted: ${timezone}"

# Application log level (normalised to uppercase for apps that expect it)
printf '%s' "${log_level}" > "${env_dir}/APP_LOG_LEVEL"

# CUSTOMIZE: export additional environment variables here, for example:
# printf '%s' "$(bashio::config 'username')" > "${env_dir}/APP_USERNAME"
# printf '%s' "$(bashio::config 'password')" > "${env_dir}/APP_PASSWORD"

# ---------------------------------------------------------------------------
# Prepare persistent data directories
# CUSTOMIZE: create any directories the application needs to exist at startup
# ---------------------------------------------------------------------------
ha::log::section "Directory setup"

# /config is the addon_config mount (persistent, survives restarts and updates)
if [[ ! -d "/config" ]]; then
    log_warn "/config directory not found — creating it"
    mkdir -p /config
fi

# Create application-specific subdirectories inside /config
# CUSTOMIZE: adjust these paths to match what your application expects
mkdir -p /config/data
mkdir -p /config/logs

log_debug "Data directories ready"

# /share is the shared storage mount
# CUSTOMIZE: uncomment if the app needs to write to /share
# mkdir -p /share/APP_NAME

# ---------------------------------------------------------------------------
# Ingress: export the base URL so the app can construct correct URLs
# ---------------------------------------------------------------------------
if bashio::addon.ingress; then
    declare ingress_entry
    ingress_entry="$(bashio::addon.ingress_entry)"
    printf '%s' "${ingress_entry}" > "${env_dir}/APP_BASE_URL"
    log_info "Ingress base URL: ${ingress_entry}"
fi

log_info "APP_NAME setup complete"
