#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# ha-dirs.sh — Directory and symlink management for Home Assistant add-ons
#
# USAGE
#   Source this file at the top of any init or service script:
#
#     # shellcheck source=/usr/local/lib/ha-framework/ha-dirs.sh
#     source /usr/local/lib/ha-framework/ha-dirs.sh
#
#   Then call the helper functions:
#
#     ha::dirs::ensure "/config/data" "755"
#     ha::dirs::create_subdirs "/config" "data" "logs" "cache"
#     ha::symlink::create "/data/library" "/romm/library"
#     ha::symlink::update "/data/library" "/romm/library"
#
# DESCRIPTION
#   These utilities provide consistent directory creation, permission setting,
#   and symlink management with proper error handling and logging.
# ==============================================================================

# Guard against double-sourcing
[[ -n "${_HA_DIRS_LOADED:-}" ]] && return 0
readonly _HA_DIRS_LOADED=1

# Internal flag to control whether functions should log
_HA_DIRS_QUIET="${_HA_DIRS_QUIET:-false}"

# ---------------------------------------------------------------------------
# ha::dirs::set_quiet [true|false]
#
# Sets whether directory operations should log messages. Useful for reducing
# log noise when creating many directories.
#
# Example:
#   ha::dirs::set_quiet true
#   ha::dirs::create_subdirs "/config" "data" "logs"
#   ha::dirs::set_quiet false
# ---------------------------------------------------------------------------
ha::dirs::set_quiet() {
    _HA_DIRS_QUIET="${1:-false}"
}

# Internal: log if not quiet
_ha_dirs_log() {
    if [[ "${_HA_DIRS_QUIET}" != "true" ]]; then
        bashio::log.info "${1}"
    fi
}

# ---------------------------------------------------------------------------
# ha::dirs::ensure <path> [permissions] [owner]
#
# Ensures a directory exists, creating it with the specified permissions
# and owner if necessary. Does nothing if the directory already exists.
#
# Examples:
#   ha::dirs::ensure "/config/data"
#   ha::dirs::ensure "/config/data" "755"
#   ha::dirs::ensure "/config/data" "755" "abc:users"
# ---------------------------------------------------------------------------
ha::dirs::ensure() {
    local path="${1:?Path is required}"
    local permissions="${2:-755}"
    local owner="${3:-}"

    if [[ -d "${path}" ]]; then
        return 0
    fi

    _ha_dirs_log "Creating directory: ${path}"

    if ! mkdir -p "${path}"; then
        bashio::exit.nok "Failed to create directory: ${path}"
    fi

    if ! chmod "${permissions}" "${path}"; then
        bashio::exit.nok "Failed to set permissions on ${path}"
    fi

    if [[ -n "${owner}" ]]; then
        if ! chown "${owner}" "${path}"; then
            bashio::exit.nok "Failed to set owner on ${path}"
        fi
    fi
}

# ---------------------------------------------------------------------------
# ha::dirs::create_subdirs <base_path> <dir1> <dir2> ...
#
# Creates multiple subdirectories under a base path with default permissions.
# Uses ha::dirs::ensure internally, so each directory is only created if needed.
#
# Example:
#   ha::dirs::create_subdirs "/config" "data" "logs" "cache" "tmp"
# ---------------------------------------------------------------------------
ha::dirs::create_subdirs() {
    local base_path="${1:?Base path is required}"
    shift

    for subdir in "$@"; do
        ha::dirs::ensure "${base_path}/${subdir}"
    done
}

# ---------------------------------------------------------------------------
# ha::dirs::ensure_file <path> [permissions] [owner]
#
# Ensures a file exists with the specified permissions and owner.
# Creates an empty file if it doesn't exist.
#
# Examples:
#   ha::dirs::ensure_file "/config/config.yml"
#   ha::dirs::ensure_file "/config/.secret" "600"
# ---------------------------------------------------------------------------
ha::dirs::ensure_file() {
    local path="${1:?Path is required}"
    local permissions="${2:-644}"
    local owner="${3:-}"

    if [[ -f "${path}" ]]; then
        return 0
    fi

    _ha_dirs_log "Creating file: ${path}"

    # Ensure parent directory exists
    local parent_dir
    parent_dir="$(dirname "${path}")"
    ha::dirs::ensure "${parent_dir}"

    if ! touch "${path}"; then
        bashio::exit.nok "Failed to create file: ${path}"
    fi

    if ! chmod "${permissions}" "${path}"; then
        bashio::exit.nok "Failed to set permissions on ${path}"
    fi

    if [[ -n "${owner}" ]]; then
        if ! chown "${owner}" "${path}"; then
            bashio::exit.nok "Failed to set owner on ${path}"
        fi
    fi
}

# ---------------------------------------------------------------------------
# ha::dirs::clear <path> [exclude...]
#
# Clears the contents of a directory without removing the directory itself.
# Optionally excludes specific files/patterns from deletion.
#
# Examples:
#   ha::dirs::clear "/tmp"
#   ha::dirs::clear "/config/cache" "*.keep"
# ---------------------------------------------------------------------------
ha::dirs::clear() {
    local path="${1:?Path is required}"
    shift

    if [[ ! -d "${path}" ]]; then
        bashio::exit.nok "Cannot clear non-existent directory: ${path}"
    fi

    _ha_dirs_log "Clearing directory: ${path}"

    # Build find command with optional exclusions
    local find_cmd="find '${path}' -mindepth 1 -maxdepth 1"
    for exclude in "$@"; do
        find_cmd="${find_cmd} ! -name '${exclude}'"
    done
    find_cmd="${find_cmd} -exec rm -rf {} +"

    if ! eval "${find_cmd}"; then
        bashio::exit.nok "Failed to clear directory: ${path}"
    fi
}

# ---------------------------------------------------------------------------
# ha::symlink::create <target> <linkpath> [force]
#
# Creates a symlink from linkpath to target. Removes any existing file/directory
# at linkpath if force is set to true.
#
# Examples:
#   ha::symlink::create "/data/library" "/romm/library"
#   ha::symlink::create "/data/library" "/romm/library" "true"
# ---------------------------------------------------------------------------
ha::symlink::create() {
    local target="${1:?Target is required}"
    local linkpath="${2:?Link path is required}"
    local force="${3:-false}"

    # Check if link already exists and points to correct target
    if [[ -L "${linkpath}" ]]; then
        local current_target
        current_target="$(readlink "${linkpath}")"
        if [[ "${current_target}" == "${target}" ]]; then
            return 0
        fi
    fi

    # Remove existing link/file if force is true
    if [[ "${force}" == "true" && -e "${linkpath}" ]]; then
        _ha_dirs_log "Removing existing ${linkpath}"
        rm -rf "${linkpath}"
    fi

    # Fail if something exists at linkpath
    if [[ -e "${linkpath}" ]]; then
        if [[ -L "${linkpath}" ]]; then
            bashio::exit.nok "Symlink exists but points elsewhere: ${linkpath} -> $(readlink "${linkpath}")"
        else
            bashio::exit.nok "Cannot create symlink: ${linkpath} already exists (and is not a symlink)"
        fi
    fi

    # Ensure parent directory exists
    local parent_dir
    parent_dir="$(dirname "${linkpath}")"
    ha::dirs::ensure "${parent_dir}"

    _ha_dirs_log "Creating symlink: ${linkpath} -> ${target}"

    if ! ln -s "${target}" "${linkpath}"; then
        bashio::exit.nok "Failed to create symlink: ${linkpath} -> ${target}"
    fi
}

# ---------------------------------------------------------------------------
# ha::symlink::update <target> <linkpath>
#
# Updates a symlink to point to the specified target. Removes the existing
# symlink if it points to a different target, or creates it if it doesn't exist.
# This is a safer alternative to ha::symlink::create with force=true.
#
# Example:
#   ha::symlink::update "/data/library" "/romm/library"
# ---------------------------------------------------------------------------
ha::symlink::update() {
    local target="${1:?Target is required}"
    local linkpath="${2:?Link path is required}"

    # Check if symlink exists and points to correct target
    if [[ -L "${linkpath}" ]]; then
        local current_target
        current_target="$(readlink "${linkpath}")"
        if [[ "${current_target}" == "${target}" ]]; then
            return 0
        fi

        # Remove incorrect symlink
        _ha_dirs_log "Updating symlink: ${linkpath} -> ${target} (was: ${current_target})"
        rm -f "${linkpath}"
    elif [[ -e "${linkpath}" ]]; then
        # Something exists that's not a symlink - warn and remove
        bashio::log.warning "${linkpath} exists but is not a symlink, removing..."
        rm -rf "${linkpath}"
    fi

    # Create new symlink
    ha::symlink::create "${target}" "${linkpath}"
}

# ---------------------------------------------------------------------------
# ha::symlink::ensure_relative <target_base> <target_path> <linkpath>
#
# Creates a relative symlink from linkpath to target_path, where both paths
# are relative to target_base. Useful for creating portable symlinks.
#
# Example:
#   ha::symlink::ensure_relative "/romm" "/data/assets" "/var/www/html/assets/romm"
#   # Creates: /var/www/html/assets/romm -> ../../../romm/data/assets
# ---------------------------------------------------------------------------
ha::symlink::ensure_relative() {
    local target_base="${1:?Target base is required}"
    local target_path="${2:?Target path is required}"
    local linkpath="${3:?Link path is required}"

    # Calculate relative path
    local link_dir
    link_dir="$(dirname "${linkpath}")"
    local absolute_target="${target_base}/${target_path}"

    local relative_target
    relative_target="$(realpath --relative-to="${link_dir}" "${absolute_target}" 2>/dev/null || echo "${target_path}")"

    ha::symlink::update "${relative_target}" "${linkpath}"
}

# ---------------------------------------------------------------------------
# ha::dirs::mount_is_readonly <mount_point>
#
# Checks if a mount point is mounted read-only.
# Returns 0 (true) if read-only, 1 (false) if writable.
#
# Example:
#   if ha::dirs::mount_is_readonly "/boot"; then
#       bashio::log.warning "/boot is read-only"
#   fi
# ---------------------------------------------------------------------------
ha::dirs::mount_is_readonly() {
    local mount_point="${1:?Mount point is required}"

    # Try to create a temp file in the mount
    local test_file="${mount_point}/.rw_test_$$"

    if touch "${test_file}" 2>/dev/null; then
        rm -f "${test_file}"
        return 1  # Writable
    else
        return 0  # Read-only
    fi
}

# ---------------------------------------------------------------------------
# ha::dirs::get_size <path>
#
# Gets the size of a directory in human-readable format.
# Outputs the size to stdout.
#
# Example:
#   size="$(ha::dirs::get_size "/config/data")"
#   bashio::log.info "Data directory size: ${size}"
# ---------------------------------------------------------------------------
ha::dirs::get_size() {
    local path="${1:?Path is required}"

    if [[ ! -d "${path}" ]]; then
        echo "unknown"
        return 1
    fi

    # Use du to get size in human-readable format
    local size
    size="$(du -sh "${path}" 2>/dev/null | cut -f1)"

    echo "${size}"
}
