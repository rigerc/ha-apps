#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# ha-config.sh — Configuration utilities for Home Assistant add-ons
#
# USAGE
#   Source this file at the top of any init or service script:
#
#     # shellcheck source=/usr/local/lib/ha-framework/ha-config.sh
#     source /usr/local/lib/ha-framework/ha-config.sh
#
#   Then call the helper functions:
#
#     ha::config::require "database.host"
#     ha::config::get "log_level" "info"
#     ha::config::validate_port "web_port"
#     ha::config::validate_url "api_url"
#     ha::config::remove_deprecated "old_option"
#
# DESCRIPTION
#   These utilities provide wrappers around bashio::config with consistent
#   error handling and validation for common configuration patterns.
# ==============================================================================

# Guard against double-sourcing
[[ -n "${_HA_CONFIG_LOADED:-}" ]] && return 0
readonly _HA_CONFIG_LOADED=1

# ---------------------------------------------------------------------------
# ha::config::require <key>
#
# Validates that a required configuration value exists. Exits with an error
# if the configuration is missing.
#
# Example:
#   ha::config::require "database.host"
# ---------------------------------------------------------------------------
ha::config::require() {
    local key="${1:?Config key is required}"

    if ! bashio::config.has_value "${key}"; then
        bashio::exit.nok "Required configuration '${key}' is missing!"
    fi
}

# ---------------------------------------------------------------------------
# ha::config::require_any <key1> [key2] ...
#
# Validates that at least one of the specified configuration values exists.
# Exits with an error if all are missing.
#
# Example:
#   ha::config::require_any "api_key" "api_token" "api_password"
# ---------------------------------------------------------------------------
ha::config::require_any() {
    for key in "$@"; do
        if bashio::config.has_value "${key}"; then
            return 0
        fi
    done

    # Join keys with ", " for error message
    local keys_list
    keys_list="$(IFS=', '; echo "$*")"
    bashio::exit.nok "At least one of these configurations is required: ${keys_list}"
}

# ---------------------------------------------------------------------------
# ha::config::get <key> [default_value]
#
# Gets a configuration value with an optional default. Returns the value
# to stdout and sets the global variable _HA_CONFIG_GET_VALUE.
#
# Examples:
#   ha::config::get "log_level" "info"
#   log_level="$(ha::config::get "log_level" "info")"
# ---------------------------------------------------------------------------
ha::config::get() {
    local key="${1:?Config key is required}"
    local default_value="${2:-}"

    _HA_CONFIG_GET_VALUE="$(bashio::config "${key}" "${default_value}")"
    echo "${_HA_CONFIG_GET_VALUE}"
}

# ---------------------------------------------------------------------------
# ha::config::get_bool <key> [default_value]
#
# Gets a boolean configuration value, normalizing various truthy/falsy inputs.
# Returns "true" or "false".
#
# Examples:
#   ha::config::get_bool "enable_feature" "false"
#   if [[ "$(ha::config::get_bool "debug")" == "true" ]]; then ...
# ---------------------------------------------------------------------------
ha::config::get_bool() {
    local key="${1:?Config key is required}"
    local default_value="${2:-false}"
    local value

    value="$(bashio::config "${key}" "${default_value}")"

    # Normalize various boolean representations
    case "${value,,}" in
        true|yes|on|1|enabled)
            echo "true"
            ;;
        false|no|off|0|disabled|"")
            echo "false"
            ;;
        *)
            echo "${default_value}"
            ;;
    esac
}

# ---------------------------------------------------------------------------
# ha::config::get_list <key> [separator]
#
# Gets a configuration value as a list, splitting by the specified separator.
# Returns an array in the global variable _HA_CONFIG_GET_LIST.
#
# Examples:
#   ha::config::get_list "allowed_ips" ","
#   ha::config::get_list "paths" " "
# ---------------------------------------------------------------------------
ha::config::get_list() {
    local key="${1:?Config key is required}"
    local separator="${2:-,}"

    local value
    value="$(bashio::config "${key}" "")"

    # Split by separator into array
    IFS="${separator}" read -ra _HA_CONFIG_GET_LIST <<< "${value}"

    # Trim whitespace from each element using sed
    # shellcheck disable=SC2004
    for i in "${!_HA_CONFIG_GET_LIST[@]}"; do
        _HA_CONFIG_GET_LIST[$i]="$(echo "${_HA_CONFIG_GET_LIST[$i]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    done
}

# ---------------------------------------------------------------------------
# ha::config::validate_port <key> [min_port] [max_port]
#
# Validates that a configuration value is a valid port number.
# Exits with an error if validation fails.
#
# Examples:
#   ha::config::validate_port "web_port"
#   ha::config::validate_port "web_port" "1024" "65535"
# ---------------------------------------------------------------------------
ha::config::validate_port() {
    local key="${1:?Config key is required}"
    local min_port="${2:-1}"
    local max_port="${3:-65535}"
    local port

    port="$(bashio::config "${key}" "")"

    if [[ ! "${port}" =~ ^[0-9]+$ ]]; then
        bashio::exit.nok "Configuration '${key}' must be a number, got: ${port}"
    fi

    if (( port < min_port || port > max_port )); then
        bashio::exit.nok "Configuration '${key}' must be between ${min_port} and ${max_port}, got: ${port}"
    fi
}

# ---------------------------------------------------------------------------
# ha::config::validate_url <key> [require_https]
#
# Validates that a configuration value is a valid URL.
# Exits with an error if validation fails.
#
# Examples:
#   ha::config::validate_url "api_url"
#   ha::config::validate_url "api_url" "true"
# ---------------------------------------------------------------------------
ha::config::validate_url() {
    local key="${1:?Config key is required}"
    local require_https="${2:-false}"
    local url

    url="$(bashio::config "${key}" "")"

    # Check if it starts with http:// or https://
    if [[ ! "${url}" =~ ^https?:// ]]; then
        bashio::exit.nok "Configuration '${key}' must be a valid URL (starting with http:// or https://), got: ${url}"
    fi

    # Require HTTPS if specified
    if [[ "${require_https}" == "true" && ! "${url}" =~ ^https:// ]]; then
        bashio::exit.nok "Configuration '${key}' must use HTTPS, got: ${url}"
    fi
}

# ---------------------------------------------------------------------------
# ha::config::validate_email <key>
#
# Validates that a configuration value is a valid email address.
# Exits with an error if validation fails.
#
# Example:
#   ha::config::validate_email "admin_email"
# ---------------------------------------------------------------------------
ha::config::validate_email() {
    local key="${1:?Config key is required}"
    local email

    email="$(bashio::config "${key}" "")"

    # Basic email validation regex
    if [[ ! "${email}" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        bashio::exit.nok "Configuration '${key}' must be a valid email address, got: ${email}"
    fi
}

# ---------------------------------------------------------------------------
# ha::config::validate_choice <key> <allowed_values...>
#
# Validates that a configuration value is one of the allowed choices.
# Exits with an error if validation fails.
#
# Example:
#   ha::config::validate_choice "log_level" "trace" "debug" "info" "warning" "error"
# ---------------------------------------------------------------------------
ha::config::validate_choice() {
    local key="${1:?Config key is required}"
    shift
    local value

    value="$(bashio::config "${key}" "")"

    # Check if value is in the allowed list
    for allowed in "$@"; do
        if [[ "${value}" == "${allowed}" ]]; then
            return 0
        fi
    done

    # Build error message with allowed values
    local allowed_list
    allowed_list="$(IFS=', '; echo "$*")"
    bashio::exit.nok "Configuration '${key}' must be one of: ${allowed_list}. Got: ${value}"
}

# ---------------------------------------------------------------------------
# ha::config::validate_path <key> [must_exist]
#
# Validates that a configuration value is a valid filesystem path.
# Optionally checks that the path exists.
#
# Examples:
#   ha::config::validate_path "data_dir"
#   ha::config::validate_path "config_file" "true"
# ---------------------------------------------------------------------------
ha::config::validate_path() {
    local key="${1:?Config key is required}"
    local must_exist="${2:-false}"
    local path

    path="$(bashio::config "${key}" "")"

    # Check if path is empty
    if [[ -z "${path}" ]]; then
        bashio::exit.nok "Configuration '${key}' cannot be empty"
    fi

    # Check if path contains invalid characters
    if [[ "${path}" =~ [[:cntrl:]] ]]; then
        bashio::exit.nok "Configuration '${key}' contains invalid characters"
    fi

    # Optionally check if path exists
    if [[ "${must_exist}" == "true" && ! -e "${path}" ]]; then
        bashio::exit.nok "Path specified in '${key}' does not exist: ${path}"
    fi
}

# ---------------------------------------------------------------------------
# ha::config::map_to_env <config_key> <env_name> <transform_func>
#
# Maps a configuration value to an environment variable with optional transformation.
# The transform function receives the raw config value and should echo
# the transformed value.
#
# Example:
#   to_upper() { echo "${1^^}"; }
#   ha::config::map_to_env "log_level" "LOG_LEVEL" "to_upper"
# ---------------------------------------------------------------------------
ha::config::map_to_env() {
    local config_key="${1:?Config key is required}"
    local env_name="${2:?Environment variable name is required}"
    local transform_func="${3:-cat}"

    if ! bashio::config.has_value "${config_key}"; then
        return 0
    fi

    local value
    value="$(bashio::config "${config_key}")"
    local transformed
    transformed="$(${transform_func} "${value}")"

    export "${env_name}=${transformed}"
    printf '%s' "${transformed}" > "/var/run/s6/container_environment/${env_name}"
}

# ---------------------------------------------------------------------------
# ha::config::remove_deprecated <key>
#
# Removes a deprecated configuration option from the Supervisor's stored options.
# This prevents warnings about options that no longer exist in the schema.
#
# Use this function when removing configuration options from already-deployed
# add-ons to clean up stale options and avoid Supervisor warnings like:
#   "Option '<key>' does not exist in the schema for <App Name>"
#
# Example:
#   ha::config::remove_deprecated "old_option"
#   ha::config::remove_deprecated "deprecated_feature_flag"
# ---------------------------------------------------------------------------
ha::config::remove_deprecated() {
    local key="${1:?Config key is required}"
    local options

    options="$(bashio::addon.options)"

    if bashio::jq.exists "${options}" ".${key}"; then
        bashio::log.info "Removing deprecated configuration option: ${key}"
        bashio::addon.option "${key}"
    fi
}
