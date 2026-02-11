#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# 10-app-setup.sh — Kapowarr environment setup
#
# Reads add-on options, prepares directories, and exports environment variables
# that the Kapowarr service will consume.
# ==============================================================================

set -e

# Source the shared logging library
# shellcheck source=/usr/local/lib/ha-log.sh
# shellcheck disable=SC1091
source /usr/local/lib/ha-log.sh

# Initialise short-form logging helpers
ha::log::init "setup"

log_info "Setting up Kapowarr..."

# ---------------------------------------------------------------------------
# Read add-on options
# ---------------------------------------------------------------------------
declare log_level
declare timezone

log_level="$(bashio::config 'log_level' 'info')"
timezone="$(bashio::config 'timezone' 'UTC')"

log_debug "log_level = ${log_level}"
log_debug "timezone  = ${timezone}"

# ---------------------------------------------------------------------------
# Persist environment variables for service scripts
# ---------------------------------------------------------------------------
declare env_dir="/var/run/s6/container_environment"

# Timezone
printf '%s' "${timezone}" > "${env_dir}/TZ"
log_debug "TZ persisted: ${timezone}"

# ---------------------------------------------------------------------------
# Prepare persistent data directories
# ---------------------------------------------------------------------------
ha::log::section "Directory setup"

# /config is the addon_config mount (persistent)
if [[ ! -d "/config" ]]; then
    log_warn "/config directory not found — creating it"
    mkdir -p /config
fi

# Create application-specific subdirectories
mkdir -p /config/data
mkdir -p /config/logs

log_debug "Data directories ready"

# /share is the shared storage mount
mkdir -p /share/kapowarr

log_info "Kapowarr setup complete"
