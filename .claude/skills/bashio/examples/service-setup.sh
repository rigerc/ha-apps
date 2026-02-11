#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# Example: s6-overlay service setup script
# Place in: /etc/services.d/myapp/run

# ==============================================================================
# Wait for dependencies
# ==============================================================================

bashio::log.info "Starting service..."

# Wait for database (example using service discovery)
if bashio::services.available 'mariadb'; then
    db_host=$(bashio::services 'mariadb' 'host')
    db_port=$(bashio::services 'mariadb' 'port')
    bashio::log.info "Waiting for MariaDB at ${db_host}:${db_port}"
    bashio::net.wait_for "${db_host}" "${db_port}"
fi

# Wait for another service on localhost
bashio::log.info "Waiting for application port..."
app_port=$(bashio::config 'app_port' '8080')
bashio::net.wait_for "${app_port}"

# ==============================================================================
# Read configuration
# ==============================================================================

# Read all configuration
log_level=$(bashio::config 'log_level' 'info')
bashio::log.level "${log_level}"

# Check if debug mode
if bashio::config.true 'debug'; then
    bashio::log.notice "Debug mode is enabled"
    set -x  # Enable bash debug mode
fi

# ==============================================================================
# Start the application
# ==============================================================================

bashio::log.info "Starting application on port ${app_port}"

# Use exec to replace the shell with the application
# This ensures proper signal handling
exec /app/my-application \
    --port "${app_port}" \
    --config /data/config.yaml
