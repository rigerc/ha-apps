#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# 20-nginx.sh — nginx ingress configuration
#
# Reads the ingress IP address and port from the HA supervisor API and patches
# the nginx server block template (servers/ingress.conf) with the real values.
#
# Runs ONCE during container initialisation, after app setup (10) but before
# services start.
# Numbering: 20 — depends on the env vars written by 10-app-setup.sh.
# ==============================================================================

set -e

# Source the shared logging library
# shellcheck source=/usr/local/lib/ha-log.sh
source /usr/local/lib/ha-log.sh

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

# ---------------------------------------------------------------------------
# Patch the ingress.conf template
#
# The template uses two placeholders that are replaced here:
#   %%interface%% — replaced with the container IP address
#   %%port%%      — replaced with the dynamically assigned ingress port
#
# Using sed in-place (-i) is intentional: the file lives only inside the
# container and is recreated on every start.
# ---------------------------------------------------------------------------
sed -i "s/%%interface%%/${ingress_interface}/g" /etc/nginx/servers/ingress.conf
sed -i "s/%%port%%/${ingress_port}/g"           /etc/nginx/servers/ingress.conf

log_info "Ingress listening on ${ingress_interface}:${ingress_port}"

# ---------------------------------------------------------------------------
# Validate the nginx configuration before the nginx service starts
# ---------------------------------------------------------------------------
if ! nginx -t 2>&1 | grep -q "syntax is ok"; then
    log_error "nginx configuration test failed — check /etc/nginx/servers/ingress.conf"
    # Print the test output to the log
    nginx -t 2>&1 || true
    exit 1
fi

log_info "nginx configuration is valid"
log_info "nginx ingress setup complete"
