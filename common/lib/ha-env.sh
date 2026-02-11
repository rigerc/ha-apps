#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# ha-env.sh — Environment variable export utilities for Home Assistant add-ons
#
# USAGE
#   Source this file at the top of any init or service script:
#
#     # shellcheck source=/usr/local/lib/ha-framework/ha-env.sh
#     source /usr/local/lib/ha-framework/ha-env.sh
#
#   Then call the helper functions:
#
#     ha::env::export "MY_VAR" "some_value"
#     ha::env::export_config "my_option" "MY_VAR"
#     ha::env::export_required "required_option" "REQUIRED_VAR"
#
# DESCRIPTION
#   These utilities export environment variables to both the shell environment
#   and to /var/run/s6/container_environment/ so they are available to
#   s6-overlay services using the with-contenv shebang.
# ==============================================================================

# Guard against double-sourcing
[[ -n "${_HA_ENV_LOADED:-}" ]] && return 0
readonly _HA_ENV_LOADED=1

# Environment directory for s6-overlay
readonly _HA_ENV_DIR="/var/run/s6/container_environment"

# ---------------------------------------------------------------------------
# ha::env::export <name> <value>
#
# Exports an environment variable to both the shell environment and
# to the s6-overlay container environment directory.
#
# Example:
#   ha::env::export "DATABASE_URL" "postgresql://localhost/db"
# ---------------------------------------------------------------------------
ha::env::export() {
    local name="${1:?Variable name is required}"
    local value="${2:-}"

    # Use eval to export variable with dynamic name (quotes prevent expansion)
    eval "export ${name}=\${value}"
    printf '%s' "${value}" > "${_HA_ENV_DIR}/${name}"
}

# ---------------------------------------------------------------------------
# ha::env::export_config <config_key> [env_name]
#
# Reads a value from the add-on configuration and exports it as an environment
# variable. The environment variable name defaults to the config key (uppercase),
# but can be overridden.
#
# Examples:
#   ha::env::export_config "log_level"              # exports LOG_LEVEL
#   ha::env::export_config "database.host" "DB_HOST"  # exports DB_HOST
# ---------------------------------------------------------------------------
ha::env::export_config() {
    local config_key="${1:?Config key is required}"
    local env_name="${2:-${config_key^^}}"
    local value

    # Convert dot notation to bashio-compatible format
    value="$(bashio::config "${config_key}" "")"
    ha::env::export "${env_name}" "${value}"
}

# ---------------------------------------------------------------------------
# ha::env::export_required <config_key> [env_name]
#
# Reads a required value from the add-on configuration and exports it as an
# environment variable. Exits with an error if the configuration value is missing.
#
# Examples:
#   ha::env::export_required "database.host"
#   ha::env::export_required "database.host" "DB_HOST"
# ---------------------------------------------------------------------------
ha::env::export_required() {
    local config_key="${1:?Config key is required}"
    local env_name="${2:-${config_key^^}}"

    if ! bashio::config.has_value "${config_key}"; then
        bashio::exit.nok "Required configuration '${config_key}' is missing!"
    fi

    ha::env::export_config "${config_key}" "${env_name}"
}

# ---------------------------------------------------------------------------
# ha::env::export_if_set <config_key> [env_name]
#
# Conditionally exports an environment variable only if the configuration value is set.
# Useful for optional configuration options.
#
# Examples:
#   ha::env::export_if_set "api_key"
#   ha::env::export_if_set "api_key" "API_KEY"
# ---------------------------------------------------------------------------
ha::env::export_if_set() {
    local config_key="${1:?Config key is required}"
    local env_name="${2:-${config_key^^}}"

    if bashio::config.has_value "${config_key}"; then
        ha::env::export_config "${config_key}" "${env_name}"
    fi
}

# ---------------------------------------------------------------------------
# ha::env::export_default <name> <value>
#
# Exports an environment variable with a default value, only if not already
# set in the environment. Useful for providing fallback values.
#
# Example:
#   ha::env::export_default "APP_PORT" "8080"
# ---------------------------------------------------------------------------
ha::env::export_default() {
    local name="${1:?Variable name is required}"
    local value="${2:-}"

    # Only set if not already defined
    if [[ -z "${!name:-}" ]]; then
        ha::env::export "${name}" "${value}"
    fi
}

# ---------------------------------------------------------------------------
# ha::env::export_from_file <name> <file_path>
#
# Reads a value from a file and exports it as an environment variable.
# Useful for secrets or values generated at runtime.
#
# Example:
#   ha::env::export_from_file "AUTH_SECRET" "/data/.secret_key"
# ---------------------------------------------------------------------------
ha::env::export_from_file() {
    local name="${1:?Variable name is required}"
    local file_path="${2:?File path is required}"

    if [[ ! -f "${file_path}" ]]; then
        bashio::exit.nok "Cannot export ${name}: file not found: ${file_path}"
    fi

    ha::env::export "${name}" "$(cat "${file_path}")"
}

# ---------------------------------------------------------------------------
# ha::env::export_multi <prefix> [config_key1] [config_key2] ...
#
# Exports multiple environment variables from a configuration section.
# The config keys are joined with the prefix to form environment variable names.
#
# Example (given config: metadata_providers.api_key=abc):
#   ha::env::export_multi "METADATA" "metadata_providers.api_key"
#   # exports: METADATA_PROVIDERS_API_KEY=abc
# ---------------------------------------------------------------------------
ha::env::export_multi() {
    local prefix="${1:?Prefix is required}"
    shift

    for config_key in "$@"; do
        # Convert config key to env name: metadata_providers.api_key -> METADATA_PROVIDERS_API_KEY
        local env_name="${prefix^^}_${config_key^^}"
        # Replace dots with underscores
        env_name="${env_name//./_}"

        if bashio::config.has_value "${config_key}"; then
            ha::env::export_config "${config_key}" "${env_name}"
        fi
    done
}

# ---------------------------------------------------------------------------
# ha::env::timezone [config_key] [default]
#
# Reads timezone configuration and exports it to the environment.
# Default config key is "timezone" and default value is "UTC".
#
# Examples:
#   ha::env::timezone
#   ha::env::timezone "tz" "America/New_York"
# ---------------------------------------------------------------------------
ha::env::timezone() {
    local config_key="${1:-timezone}"
    local default_value="${2:-UTC}"
    local timezone

    timezone="$(bashio::config "${config_key}" "${default_value}")"

    ha::env::export "TZ" "${timezone}"
    bashio::log.info "Timezone: ${timezone}"
}

# ---------------------------------------------------------------------------
# ha::env::log_level [config_key] [default] [env_name]
#
# Reads log level configuration and exports it as an environment variable.
# Default config key is "log_level", default is "info", env_name is "LOG_LEVEL".
#
# Examples:
#   ha::env::log_level
#   ha::env::log_level "log_level" "debug" "APP_LOG_LEVEL"
# ---------------------------------------------------------------------------
ha::env::log_level() {
    local config_key="${1:-log_level}"
    local default_value="${2:-info}"
    local env_name="${3:-LOG_LEVEL}"
    local log_level

    log_level="$(bashio::config "${config_key}" "${default_value}")"

    ha::env::export "${env_name}" "${log_level}"
    bashio::log.info "Log level: ${log_level}"
}

# ---------------------------------------------------------------------------
# ha::env::ingress [env_name]
#
# Exports the ingress base URL to an environment variable.
# Only exports if ingress is enabled for this add-on.
# Default env_name is "INGRESS_ENTRY".
#
# Examples:
#   ha::env::ingress
#   ha::env::ingress "BASE_URL"
#   ha::env::ingress "APP_BASE_URL"
# ---------------------------------------------------------------------------
ha::env::ingress() {
    local env_name="${1:-INGRESS_ENTRY}"
    local ingress_entry

    if ! bashio::addon.ingress; then
        bashio::log.debug "Ingress is not enabled"
        return 0
    fi

    ingress_entry="$(bashio::addon.ingress_entry)"
    ha::env::export "${env_name}" "${ingress_entry}"
    bashio::log.info "Ingress base URL: ${ingress_entry}"
}

# ---------------------------------------------------------------------------
# ha::env::service_discovery <service_name>
#
# Checks if a service is available and exports connection details as
# environment variables with the service name prefix.
#
# Returns 0 if service is available, 1 otherwise.
#
# Examples:
#   if ha::env::service_discovery "mysql"; then
#       echo "Using MySQL service"
#   fi
# ---------------------------------------------------------------------------
ha::env::service_discovery() {
    local service_name="${1:?Service name is required}"
    local prefix
    prefix="$(echo "${service_name}" | tr '[:lower:]' '[:upper:]')"

    if ! bashio::services.available "${service_name}"; then
        bashio::log.debug "Service '${service_name}' is not available"
        return 1
    fi

    # Export service connection details
    local host port username password database

    host="$(bashio::services "${service_name}" "host")"
    port="$(bashio::services "${service_name}" "port")"
    username="$(bashio::services "${service_name}" "username")"
    password="$(bashio::services "${service_name}" "password")"
    database="$(bashio::services "${service_name}" "database")"

    ha::env::export "${prefix}_HOST" "${host}"
    ha::env::export "${prefix}_PORT" "${port}"
    ha::env::export "${prefix}_USERNAME" "${username}"
    ha::env::export "${prefix}_PASSWORD" "${password}"
    ha::env::export "${prefix}_DATABASE" "${database}"

    bashio::log.info "Using ${service_name} service at ${host}:${port}"
    return 0
}
