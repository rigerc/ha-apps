#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# Example: SSL certificate validation and usage

# ==============================================================================
# Validate SSL configuration
# ==============================================================================

if bashio::config.true 'ssl'; then
    bashio::log.info "SSL is enabled, validating certificates..."

    # This will exit with error if certificates are missing
    bashio::config.require.ssl 'ssl' 'certfile' 'keyfile'

    # Get certificate paths
    certfile=$(bashio::config 'certfile')
    keyfile=$(bashio::config 'keyfile')

    cert_path="/ssl/${certfile}"
    key_path="/ssl/${keyfile}"

    # Verify files exist
    if ! bashio::fs.file_exists "${cert_path}"; then
        bashio::log.fatal "Certificate file not found: ${cert_path}"
        bashio::exit.nok
    fi

    if ! bashio::fs.file_exists "${key_path}"; then
        bashio::log.fatal "Key file not found: ${key_path}"
        bashio::exit.nok
    fi

    bashio::log.info "SSL certificates validated"
    bashio::log.info "Certificate: ${cert_path}"
    bashio::log.info "Key: ${key_path}"

    # Application can now use SSL
    ssl_options="--cert ${cert_path} --key ${key_path}"
else
    bashio::log.info "SSL is disabled, using plain HTTP"
    ssl_options=""
fi

# ==============================================================================
# Start application with or without SSL
# ==============================================================================

bashio::log.info "Starting application..."
exec /app/my-application ${ssl_options}
