#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# 20-nginx.sh — nginx ingress configuration
#
# Reads the ingress IP address and port from the HA supervisor API and renders
# the nginx server block from a Go template using tempio.
# ==============================================================================

set -e

# Source the shared logging library
# shellcheck source=/usr/local/lib/ha-log.sh
# shellcheck disable=SC1091
source /usr/local/lib/ha-log.sh

ha::log::init "nginx"

log_info "Configuring nginx ingress..."

# ---------------------------------------------------------------------------
# Obtain ingress coordinates from the HA supervisor
# ---------------------------------------------------------------------------
declare ingress_interface
declare ingress_port
declare app_port

ingress_interface="$(bashio::addon.ip_address)"
ingress_port="$(bashio::addon.ingress_port)"
app_port="${APP_PORT:-5656}"

log_debug "ingress_interface = ${ingress_interface}"
log_debug "ingress_port      = ${ingress_port}"
log_debug "app_port          = ${app_port}"

# ---------------------------------------------------------------------------
# Render the nginx server block from the Go template using tempio.
# ---------------------------------------------------------------------------
log_info "Rendering /etc/nginx/servers/ingress.conf via tempio..."

bashio::var.json \
    ingress_interface "${ingress_interface}" \
    ingress_port      "^${ingress_port}" \
    app_port          "^${app_port}" \
    | tempio \
        -template /etc/nginx/templates/ingress.gtpl \
        -out /etc/nginx/servers/ingress.conf

log_info "Ingress listening on ${ingress_interface}:${ingress_port} -> 127.0.0.1:${app_port}"

# ---------------------------------------------------------------------------
# Validate the nginx configuration before the nginx service starts
# ---------------------------------------------------------------------------
if ! nginx -t 2>&1 | grep -q "syntax is ok"; then
    log_error "nginx configuration test failed — check /etc/nginx/servers/ingress.conf"
    nginx -t 2>&1 || true
    exit 1
fi

log_info "nginx configuration is valid"
log_info "nginx ingress setup complete"
