#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# 20-nginx.sh — nginx ingress configuration
#
# Reads the ingress IP address and port from the HA supervisor API and renders
# the nginx server block from a Go template using tempio.
#
# tempio is pre-installed in all HA base images. It accepts a JSON object on
# stdin (built by bashio::var.json) and renders a Go template file to an output
# file. This approach avoids fragile sed substitutions.
#
# Runs ONCE during container initialisation, after app setup (10) but before
# services start.
# Numbering: 20 — depends on the env vars written by 10-app-setup.sh.
# ==============================================================================

set -e

# Source the shared logging library from HA framework
# shellcheck source=/usr/local/lib/ha-framework/ha-log.sh
source /usr/local/lib/ha-framework/ha-log.sh

ha::log::init "nginx"

log_info "Configuring nginx ingress..."

# ---------------------------------------------------------------------------
# Obtain ingress coordinates from the HA supervisor
# ---------------------------------------------------------------------------
declare ingress_interface
declare ingress_port

# bashio::addon.ip_address — the container's IP address as seen by HA ingress
# bashio::addon.ingress_port — the dynamically assigned ingress port
ingress_interface="$(bashio::addon.ip_address)"
ingress_port="$(bashio::addon.ingress_port)"

log_debug "ingress_interface = ${ingress_interface}"
log_debug "ingress_port      = ${ingress_port}"
log_debug "app_port          = ${APP_PORT}"

# ---------------------------------------------------------------------------
# Render the nginx server block from the Go template using tempio.
#
# bashio::var.json builds a JSON object from key/value pairs.
# The ^ prefix passes a value as a raw number rather than a quoted string,
# which is required for port numbers used in numeric nginx directives.
#
# Template: /etc/nginx/templates/ingress.gtpl
# Output:   /etc/nginx/servers/ingress.conf  (directory created in Dockerfile)
# ---------------------------------------------------------------------------
log_info "Rendering /etc/nginx/servers/ingress.conf via tempio..."

bashio::var.json \
    ingress_interface "${ingress_interface}" \
    ingress_port      "^${ingress_port}" \
    app_port          "^${APP_PORT}" \
    | tempio \
        -template /etc/nginx/templates/ingress.gtpl \
        -out /etc/nginx/servers/ingress.conf

log_info "Ingress listening on ${ingress_interface}:${ingress_port} -> 127.0.0.1:${APP_PORT}"

# ---------------------------------------------------------------------------
# Validate the nginx configuration before the nginx service starts
# ---------------------------------------------------------------------------
if ! nginx -t >/dev/null 2>&1; then
    log_error "nginx configuration test failed — check /etc/nginx/servers/ingress.conf"
    # Print the test output to the log
    nginx -t 2>&1 || true
    exit 1
fi

log_info "nginx configuration is valid"
log_info "nginx ingress setup complete"
