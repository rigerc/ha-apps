#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# ha-validate.sh — Validation utilities for Home Assistant add-ons
#
# USAGE
#   Source this file at the top of any init or service script:
#
#     # shellcheck source=/usr/local/lib/ha-framework/ha-validate.sh
#     source /usr/local/lib/ha-framework/ha-validate.sh
#
#   Then call the helper functions:
#
#     ha::validate::port "8080"
#     ha::validate::url "https://api.example.com"
#     ha::validate::not_empty "${value}" "API_KEY"
#
# DESCRIPTION
#   These utilities provide common validation functions with consistent
#   error messaging and exit handling.
# ==============================================================================

# Guard against double-sourcing
[[ -n "${_HA_VALIDATE_LOADED:-}" ]] && return 0
readonly _HA_VALIDATE_LOADED=1

# Internal: error message prefix
_HA_VALIDATE_ERROR_PREFIX="${_HA_VALIDATE_ERROR_PREFIX:-Validation error}"

# ---------------------------------------------------------------------------
# ha::validate::port <port> [min_port] [max_port]
#
# Validates that a value is a valid port number (1-65535 by default).
# Returns 0 if valid, exits with error otherwise.
#
# Examples:
#   ha::validate::port "8080"
#   ha::validate::port "8080" 1024 65535
#   port="8080"; ha::validate::port "${port}" || return 1
# ---------------------------------------------------------------------------
ha::validate::port() {
    local port="${1:?Port value is required}"
    local min_port="${2:-1}"
    local max_port="${3:-65535}"

    # Check if port is a number
    if ! [[ "${port}" =~ ^[0-9]+$ ]]; then
        bashio::exit.nok "${_HA_VALIDATE_ERROR_PREFIX}: '${port}' is not a valid port number"
    fi

    # Check port range
    if (( port < min_port || port > max_port )); then
        bashio::exit.nok "${_HA_VALIDATE_ERROR_PREFIX}: '${port}' is out of range (${min_port}-${max_port})"
    fi

    return 0
}

# ---------------------------------------------------------------------------
# ha::validate::url <url> [require_https] [allow_localhost]
#
# Validates that a value is a valid URL.
# Returns 0 if valid, exits with error otherwise.
#
# Examples:
#   ha::validate::url "https://api.example.com"
#   ha::validate::url "https://api.example.com" "true"
#   ha::validate::url "http://localhost:8080" "false" "true"
# ---------------------------------------------------------------------------
ha::validate::url() {
    local url="${1:?URL is required}"
    local require_https="${2:-false}"
    local allow_localhost="${3:-false}"

    # Check if URL starts with http:// or https://
    if [[ ! "${url}" =~ ^https?:// ]]; then
        bashio::exit.nok "${_HA_VALIDATE_ERROR_PREFIX}: '${url}' must start with http:// or https://"
    fi

    # Require HTTPS if specified
    if [[ "${require_https}" == "true" && ! "${url}" =~ ^https:// ]]; then
        bashio::exit.nok "${_HA_VALIDATE_ERROR_PREFIX}: '${url}' must use HTTPS"
    fi

    # Disallow localhost unless allowed
    if [[ "${allow_localhost}" != "true" ]]; then
        if [[ "${url}" =~ (localhost|127\.0\.0\.1|::1) ]]; then
            bashio::exit.nok "${_HA_VALIDATE_ERROR_PREFIX}: '${url}' cannot use localhost"
        fi
    fi

    # Check for characters after protocol
    local url_without_protocol="${url#*://}"
    if [[ -z "${url_without_protocol}" ]]; then
        bashio::exit.nok "${_HA_VALIDATE_ERROR_PREFIX}: '${url}' is not a valid URL"
    fi

    return 0
}

# ---------------------------------------------------------------------------
# ha::validate::not_empty <value> <name>
#
# Validates that a value is not empty or whitespace-only.
# Returns 0 if valid, exits with error otherwise.
#
# Examples:
#   ha::validate::not_empty "${api_key}" "API_KEY"
#   value="test"; ha::validate::not_empty "${value}" "VALUE" || return 1
# ---------------------------------------------------------------------------
ha::validate::not_empty() {
    local value="${1:?Value is required}"
    local name="${2:?Name is required}"

    # Remove whitespace and check if empty
    local trimmed="${value// /}"
    if [[ -z "${trimmed}" ]]; then
        bashio::exit.nok "${_HA_VALIDATE_ERROR_PREFIX}: ${name} cannot be empty"
    fi

    return 0
}

# ---------------------------------------------------------------------------
# ha::validate::email <email>
#
# Validates that a value is a valid email address format.
# Returns 0 if valid, exits with error otherwise.
#
# Example:
#   ha::validate::email "user@example.com"
# ---------------------------------------------------------------------------
ha::validate::email() {
    local email="${1:?Email is required}"

    # Basic email validation regex (RFC 5322 simplified)
    local email_regex='^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'

    if [[ ! "${email}" =~ ${email_regex} ]]; then
        bashio::exit.nok "${_HA_VALIDATE_ERROR_PREFIX}: '${email}' is not a valid email address"
    fi

    return 0
}

# ---------------------------------------------------------------------------
# ha::validate::in_range <value> <min> <max> [name]
#
# Validates that a numeric value is within the specified range.
# Returns 0 if valid, exits with error otherwise.
#
# Examples:
#   ha::validate::in_range "50" 0 100 "Percentage"
#   ha::validate::in_range "${timeout}" 1 300
# ---------------------------------------------------------------------------
ha::validate::in_range() {
    local value="${1:?Value is required}"
    local min="${2:?Minimum value is required}"
    local max="${3:?Maximum value is required}"
    local name="${4:-Value}"

    # Check if value is a number
    if ! [[ "${value}" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        bashio::exit.nok "${_HA_VALIDATE_ERROR_PREFIX}: ${name} must be numeric, got: ${value}"
    fi

    # Check range
    if (( $(echo "${value} < ${min}" | bc -l 2>/dev/null || echo "0") )); then
        bashio::exit.nok "${_HA_VALIDATE_ERROR_PREFIX}: ${name} must be at least ${min}, got: ${value}"
    fi

    if (( $(echo "${value} > ${max}" | bc -l 2>/dev/null || echo "0") )); then
        bashio::exit.nok "${_HA_VALIDATE_ERROR_PREFIX}: ${name} must be at most ${max}, got: ${value}"
    fi

    return 0
}

# ---------------------------------------------------------------------------
# ha::validate::min_length <value> <min_length> [name]
#
# Validates that a string value meets minimum length requirements.
# Returns 0 if valid, exits with error otherwise.
#
# Examples:
#   ha::validate::min_length "${password}" 8 "Password"
#   ha::validate::min_length "${api_key}" 32
# ---------------------------------------------------------------------------
ha::validate::min_length() {
    local value="${1:?Value is required}"
    local min_length="${2:?Minimum length is required}"
    local name="${3:-Value}"

    if [[ ${#value} -lt ${min_length} ]]; then
        bashio::exit.nok "${_HA_VALIDATE_ERROR_PREFIX}: ${name} must be at least ${min_length} characters"
    fi

    return 0
}

# ---------------------------------------------------------------------------
# ha::validate::max_length <value> <max_length> [name]
#
# Validates that a string value does not exceed maximum length.
# Returns 0 if valid, exits with error otherwise.
#
# Examples:
#   ha::validate::max_length "${username}" 32 "Username"
# ---------------------------------------------------------------------------
ha::validate::max_length() {
    local value="${1:?Value is required}"
    local max_length="${2:?Maximum length is required}"
    local name="${3:-Value}"

    if [[ ${#value} -gt ${max_length} ]]; then
        bashio::exit.nok "${_HA_VALIDATE_ERROR_PREFIX}: ${name} must be at most ${max_length} characters"
    fi

    return 0
}

# ---------------------------------------------------------------------------
# ha::validate::matches_regex <value> <regex> [name] [error_message]
#
# Validates that a value matches the specified regex pattern.
# Returns 0 if valid, exits with error otherwise.
#
# Examples:
#   ha::validate::matches_regex "${value}" "^[a-z0-9_]+$" "Field name"
#   ha::validate::matches_regex "${port}" "^[0-9]+$" "Port" "Must be numeric"
# ---------------------------------------------------------------------------
ha::validate::matches_regex() {
    local value="${1:?Value is required}"
    local regex="${2:?Regex pattern is required}"
    local name="${3:-Value}"
    local error_message="${4:-must match pattern ${regex}}"

    if [[ ! "${value}" =~ ${regex} ]]; then
        bashio::exit.nok "${_HA_VALIDATE_ERROR_PREFIX}: ${name} ${error_message}"
    fi

    return 0
}

# ---------------------------------------------------------------------------
# ha::validate::file_exists <path> [required]
#
# Validates that a file exists at the specified path.
# Returns 0 if valid, exits with error otherwise.
#
# Examples:
#   ha::validate::file_exists "/config/config.yml"
#   ha::validate::file_exists "/config/optional.yml" "false"
# ---------------------------------------------------------------------------
ha::validate::file_exists() {
    local path="${1:?Path is required}"
    local required="${2:-true}"

    if [[ ! -f "${path}" ]]; then
        if [[ "${required}" == "true" ]]; then
            bashio::exit.nok "${_HA_VALIDATE_ERROR_PREFIX}: Required file not found: ${path}"
        else
            return 1
        fi
    fi

    return 0
}

# ---------------------------------------------------------------------------
# ha::validate::dir_exists <path> [required]
#
# Validates that a directory exists at the specified path.
# Returns 0 if valid, exits with error otherwise.
#
# Examples:
#   ha::validate::dir_exists "/config/data"
#   ha::validate::dir_exists "/config/optional" "false"
# ---------------------------------------------------------------------------
ha::validate::dir_exists() {
    local path="${1:?Path is required}"
    local required="${2:-true}"

    if [[ ! -d "${path}" ]]; then
        if [[ "${required}" == "true" ]]; then
            bashio::exit.nok "${_HA_VALIDATE_ERROR_PREFIX}: Required directory not found: ${path}"
        else
            return 1
        fi
    fi

    return 0
}

# ---------------------------------------------------------------------------
# ha::validate::one_of <value> <allowed1> <allowed2> ... [name]
#
# Validates that a value is one of the allowed options.
# Returns 0 if valid, exits with error otherwise.
#
# Examples:
#   ha::validate::one_of "info" "trace" "debug" "info" "warning" "error"
#   ha::validate::one_of "${level}" "trace" "debug" "info" "Log level"
# ---------------------------------------------------------------------------
ha::validate::one_of() {
    local value="${1:?Value is required}"
    shift
    local name="${1:-Value}"
    shift

    for allowed in "$@"; do
        if [[ "${value}" == "${allowed}" ]]; then
            return 0
        fi
    done

    # Build error message with allowed values
    local allowed_list
    allowed_list="$(IFS=', '; echo "$*")"
    bashio::exit.nok "${_HA_VALIDATE_ERROR_PREFIX}: ${name} must be one of: ${allowed_list}. Got: ${value}"
}

# ---------------------------------------------------------------------------
# ha::validate::is_true <value>
#
# Validates that a value represents a boolean "true".
# Returns 0 if true, 1 otherwise.
#
# Example:
#   if ha::validate::is_true "${enabled}"; then
#       bashio::log.info "Feature is enabled"
#   fi
# ---------------------------------------------------------------------------
ha::validate::is_true() {
    local value="${1:-}"

    case "${value,,}" in
        true|yes|on|1|enabled)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# ha::validate::is_false <value>
#
# Validates that a value represents a boolean "false".
# Returns 0 if false, 1 otherwise.
#
# Example:
#   if ha::validate::is_false "${debug}"; then
#       bashio::log.info "Debug is disabled"
#   fi
# ---------------------------------------------------------------------------
ha::validate::is_false() {
    local value="${1:-}"

    case "${value,,}" in
        false|no|off|0|disabled|"")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# ha::validate::ip_address <ip>
#
# Validates that a value is a valid IPv4 address.
# Returns 0 if valid, exits with error otherwise.
#
# Example:
#   ha::validate::ip_address "192.168.1.1"
# ---------------------------------------------------------------------------
ha::validate::ip_address() {
    local ip="${1:?IP address is required}"

    # IPv4 validation regex - strictly checks format and valid octet range
    local ip_regex='^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$'

    if [[ ! "${ip}" =~ ${ip_regex} ]]; then
        bashio::exit.nok "${_HA_VALIDATE_ERROR_PREFIX}: '${ip}' is not a valid IPv4 address"
    fi

    return 0
}
