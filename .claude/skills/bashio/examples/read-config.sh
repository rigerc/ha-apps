#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# Example: Reading add-on configuration with bashio

# ==============================================================================
# Read basic configuration values
# ==============================================================================

# Read string value with default
server_port=$(bashio::config 'server_port' '8095')
log_level=$(bashio::config 'log_level' 'info')

# Read boolean value
ssl_enabled=$(bashio::config 'ssl' 'false')

bashio::log.info "=== Configuration ==="
bashio::log.info "Server port: ${server_port}"
bashio::log.info "Log level: ${log_level}"
bashio::log.info "SSL enabled: ${ssl_enabled}"

# ==============================================================================
# Check boolean values
# ==============================================================================

if bashio::config.true 'ssl'; then
    bashio::log.info "SSL is enabled"
    certfile=$(bashio::config 'certfile')
    keyfile=$(bashio::config 'keyfile')
    bashio::log.info "Certificate: ${certfile}"
    bashio::log.info "Key: ${keyfile}"
else
    bashio::log.notice "SSL is disabled"
fi

# ==============================================================================
# Check for optional values
# ==============================================================================

if bashio::config.has_value 'api_key'; then
    api_key=$(bashio::config 'api_key')
    bashio::log.info "API key is configured"
else
    bashio::log.notice "No API key configured, running in public mode"
fi

# ==============================================================================
# Require critical configuration
# ==============================================================================

# This will exit with error if not set
bashio::config.require 'server_address'
server_address=$(bashio::config 'server_address')
bashio::log.info "Server address: ${server_address}"

# ==============================================================================
# Set log level from config
# ==============================================================================

bashio::log.level "${log_level}"
bashio::log.debug "Debug logging enabled"
bashio::log.info "Configuration loaded successfully"
