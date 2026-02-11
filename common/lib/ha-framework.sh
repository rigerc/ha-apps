#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# ha-framework.sh — Single entrypoint for the HA add-on framework
#
# USAGE
#   Source this one file to load all framework libraries:
#
#     # shellcheck source=/usr/local/lib/ha-framework/ha-framework.sh
#     source /usr/local/lib/ha-framework/ha-framework.sh
#
# All individual libraries have double-sourcing guards, so this is safe
# even if specific libraries were already sourced.
# ==============================================================================

# Guard against double-sourcing
[[ -n "${_HA_FRAMEWORK_LOADED:-}" ]] && return 0
readonly _HA_FRAMEWORK_LOADED=1

# Resolve the directory this script lives in
_HA_FRAMEWORK_DIR="${_HA_FRAMEWORK_DIR:-/usr/local/lib/ha-framework}"

# Source all library files in the framework directory (except this entrypoint)
for _ha_fw_lib in "${_HA_FRAMEWORK_DIR}"/ha-*.sh; do
    [[ -f "${_ha_fw_lib}" ]] || continue
    [[ "$(basename "${_ha_fw_lib}")" == "ha-framework.sh" ]] && continue
    # shellcheck disable=SC1090
    source "${_ha_fw_lib}"
done
unset _ha_fw_lib
