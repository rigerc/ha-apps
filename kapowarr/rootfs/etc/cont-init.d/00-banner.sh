#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# 00-banner.sh — Startup banner
#
# This is the very first cont-init.d script to run.  It prints the add-on name
# and version so the log makes it obvious when a new start/restart occurred.
#
# Runs ONCE during container initialisation, before any services start.
# Numbering: 00 — runs first among all init scripts.
# ==============================================================================

# CUSTOMIZE: update the display name to match your add-on
readonly ADDON_DISPLAY_NAME="kapowarr"

# Source the shared logging library
# shellcheck source=/usr/local/lib/ha-log.sh
source /usr/local/lib/ha-log.sh

# Print startup banner
ha::log::banner "${ADDON_DISPLAY_NAME}"

# Log the configured log level so it is visible near the top of every log
_configured_level="$(bashio::config 'log_level' 'info')"
bashio::log.info "Log level: ${_configured_level}"
