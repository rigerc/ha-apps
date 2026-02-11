#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# ha-template.sh — Template rendering utilities for Home Assistant add-ons
#
# USAGE
#   Source this file at the top of any init or service script:
#
#     # shellcheck source=/usr/local/lib/ha-framework/ha-template.sh
#     source /usr/local/lib/ha-framework/ha-template.sh
#
#   Then call the helper functions:
#
#     ha::template::render <template> <output> var1=value1 var2=value2
#     ha::template::substitute <template> <output> placeholder1=value1
#     ha::template::find <filename> [search_path1] [search_path2]
#
# DESCRIPTION
#   These utilities provide unified template rendering for both tempio (Go templates)
#   and sed-style substitutions. They integrate with ha-log.sh for consistent
#   logging and include proper error handling.
# ==============================================================================

# Guard against double-sourcing
[[ -n "${_HA_TEMPLATE_LOADED:-}" ]] && return 0
readonly _HA_TEMPLATE_LOADED=1

# Internal flag to control logging (inherit from ha-log.sh if available)
_HA_TEMPLATE_QUIET="${_HA_TEMPLATE_QUIET:-false}"

# Internal: log if not quiet (use ha-log.sh if available, else bashio)
_ha_template_log() {
    if [[ "${_HA_TEMPLATE_QUIET}" == "true" ]]; then
        return 0
    fi

    if declare -F log_info >/dev/null 2>&1; then
        log_info "$1"
    else
        bashio::log.info "$1"
    fi
}

# Internal: log error (use ha-log.sh if available, else bashio)
_ha_template_error() {
    if declare -F log_error >/dev/null 2>&1; then
        log_error "$1"
    else
        bashio::log.error "$1"
    fi
}

# Internal: log debug (use ha-log.sh if available, else bashio)
_ha_template_debug() {
    if [[ "${_HA_TEMPLATE_QUIET}" == "true" ]]; then
        return 0
    fi

    if declare -F log_debug >/dev/null 2>&1; then
        log_debug "$1"
    else
        bashio::log.debug "$1"
    fi
}

# ---------------------------------------------------------------------------
# ha::template::set_quiet [true|false]
#
# Sets whether template operations should log messages.
# Useful for reducing log noise when rendering multiple templates.
#
# Example:
#   ha::template::set_quiet true
#   ha::template::render ...
#   ha::template::set_quiet false
# ---------------------------------------------------------------------------
ha::template::set_quiet() {
    _HA_TEMPLATE_QUIET="${1:-false}"
}

# ---------------------------------------------------------------------------
# _ha_template_build_vars [var1=value1] [var2=value2] ...
#
# Internal: Builds bashio::var.json command line from key=value pairs.
# Handles raw numeric values (with ^ prefix) and quoted strings.
# ---------------------------------------------------------------------------
_ha_template_build_vars() {
    local args=("$@")
    local json_vars=()

    for arg in "${args[@]}"; do
        [[ -z "${arg}" ]] && continue

        if [[ "${arg}" =~ ^([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # Check if value should be raw (numeric, starts with ^)
            if [[ "${value}" =~ \^([0-9]+)$ ]]; then
                json_vars+=("${key} ^${value}")
            else
                # Quote string values
                json_vars+=("${key} ${value}")
            fi
        fi
    done

    # Build bashio::var.json command
    if [[ ${#json_vars[@]} -eq 0 ]]; then
        bashio::var.json | tempio -template /dev/stdin -out /dev/stdout
    else
        bashio::var.json "${json_vars[@]}" | tempio -template /dev/stdin -out /dev/stdout
    fi
}

# ---------------------------------------------------------------------------
# _ha_template_validate_nginx <config_file>
#
# Internal: Validates nginx configuration by running nginx -t.
# Exits with error if validation fails.
# ---------------------------------------------------------------------------
_ha_template_validate_nginx() {
    local config_file="${1:?Config file is required}"

    _ha_template_log "Validating nginx configuration: ${config_file}"

    if ! nginx -t "${config_file}" >/dev/null 2>&1; then
        _ha_template_error "nginx configuration test failed — check ${config_file}"
        nginx -t "${config_file}" 2>&1 | head -20 || true
        return 1
    fi

    _ha_template_debug "nginx configuration is valid"
    return 0
}

# ---------------------------------------------------------------------------
# _ha_template_tempio_available
#
# Internal: Checks if tempio command is available.
# Returns 0 if available, 1 otherwise.
# ---------------------------------------------------------------------------
_ha_template_tempio_available() {
    if command -v tempio >/dev/null 2>&1; then
        return 0
    else
        _ha_template_error "tempio command not found. Cannot render Go templates."
        return 1
    fi
}

# ---------------------------------------------------------------------------
# ha::template::find <filename> [search_path1] [search_path2] ...
#
# Searches for a template file in standard locations.
# Returns the path to the first match found, or exits with error.
#
# Search order (first match wins):
#   1. /config/<addon>/templates/           (user override)
#   2. /etc/<app>/templates/              (app-specific)
#   3. /etc/nginx/templates/              (nginx-specific)
#   4. /usr/local/lib/ha-framework/templates/ (framework defaults)
#
# Examples:
#   ha::template::find "ingress.gtpl"
#   ha::template::find "config.yml" "/config/myapp/templates"
# ---------------------------------------------------------------------------
ha::template::find() {
    local filename="${1:?Filename is required}"
    shift
    local search_paths=("$@")

    # Default search paths if none provided
    if [[ ${#search_paths[@]} -eq 0 ]]; then
        search_paths=(
            "/config/${HOSTNAME:-addon}/templates/"
            "/etc/${HOSTNAME:-addon}/templates/"
            "/etc/nginx/templates/"
            "/usr/local/lib/ha-framework/templates/"
        )
    fi

    # Search for the template file
    for search_path in "${search_paths[@]}"; do
        local full_path="${search_path}${filename}"
        if [[ -f "${full_path}" ]]; then
            _ha_template_debug "Found template: ${full_path}"
            echo "${full_path}"
            return 0
        fi
    done

    _ha_template_error "Template not found: ${filename} (searched: ${search_paths[*]})"
    return 1
}

# ---------------------------------------------------------------------------
# ha::template::render <template_file> <output_file> var1=value1 [var2=value2] ...
#
# Renders a Go template using tempio.
#
# The template_file can be:
#   - An absolute path
#   - A filename to be found via ha::template::find
#
# Variables are provided as key=value pairs. Numeric values should be prefixed
# with ^ to be passed as raw numbers (required for nginx directives).
#
# Examples:
#   ha::template::render ingress.gtpl /etc/nginx/servers/ingress.conf \
#       ingress_interface="${ingress_interface}" \
#       ingress_port="^${ingress_port}" \
#       app_port="^${APP_PORT}"
#
#   # Using template from file search:
#   template=$(ha::template::find "config.gtpl")
#   ha::template::render "$template" /config/app/config.yml \
#       db_host="$(bashio::config 'db.host')" \
#       db_port="^$(bashio::config 'db.port')"
# ---------------------------------------------------------------------------
ha::template::render() {
    local template_file="${1:?Template file is required}"
    local output_file="${2:?Output file is required}"
    shift
    local vars=("$@")

    # If template_file is not absolute, search for it
    if [[ "${template_file}" != /* ]]; then
        template_file="$(ha::template::find "${template_file}")" || return 1
    fi

    _ha_template_log "Rendering ${template_file} -> ${output_file}"

    # Ensure output directory exists
    local output_dir
    output_dir="$(dirname "${output_file}")"
    if [[ ! -d "${output_dir}" ]]; then
        mkdir -p "${output_dir}" || {
            _ha_template_error "Failed to create output directory: ${output_dir}"
            return 1
        }
    fi

    # Check if tempio is available
    _ha_template_tempio_available || return 1

    # Build and execute tempio command
    local tempio_cmd="tempio -template ${template_file} -out ${output_file}"

    if [[ ${#vars[@]} -gt 0 ]]; then
        _ha_template_debug "Variables: ${vars[*]}"

        # Add variables to tempio command
        tempio_cmd="$(_ha_template_build_vars "${vars[@]}" | tempio -template /dev/stdin -out /dev/stdout) $tempio_cmd"
    fi

    # Execute render command
    if eval "${tempio_cmd}"; then
        _ha_template_log "Template rendered successfully: ${output_file}"

        # Validate nginx config if output is .conf
        if [[ "${output_file}" == *.conf ]]; then
            _ha_template_validate_nginx "${output_file}" || return 1
        fi

        return 0
    else
        _ha_template_error "Failed to render template: ${template_file}"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# ha::template::render_json <template_file> <output_file> <json_data>
#
# Renders a Go template using tempio with JSON data input.
# Use this when you have complex nested data structures.
#
# The json_data should be a JSON object string.
#
# Example:
#   json_data="$(bashio::var.json key1='value1' key2='value2')"
#   ha::template::render_json template.gtpl /etc/output.conf "${json_data}"
# ---------------------------------------------------------------------------
ha::template::render_json() {
    local template_file="${1:?Template file is required}"
    local output_file="${2:?Output file is required}"
    local json_data="${3:?JSON data is required}"

    # If template_file is not absolute, search for it
    if [[ "${template_file}" != /* ]]; then
        template_file="$(ha::template::find "${template_file}")" || return 1
    fi

    _ha_template_log "Rendering ${template_file} -> ${output_file} (from JSON)"

    # Ensure output directory exists
    local output_dir
    output_dir="$(dirname "${output_file}")"
    if [[ ! -d "${output_dir}" ]]; then
        mkdir -p "${output_dir}" || {
            _ha_template_error "Failed to create output directory: ${output_dir}"
            return 1
        }
    fi

    # Check if tempio is available
    _ha_template_tempio_available || return 1

    # Execute tempio with JSON input
    if echo "${json_data}" | tempio -template "${template_file}" -out "${output_file}"; then
        _ha_template_log "Template rendered successfully: ${output_file}"

        # Validate nginx config if output is .conf
        if [[ "${output_file}" == *.conf ]]; then
            _ha_template_validate_nginx "${output_file}" || return 1
        fi

        return 0
    else
        _ha_template_error "Failed to render template: ${template_file}"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# ha::template::substitute <template_file> <output_file> placeholder1=value1 ...
#
# Performs sed-style placeholder substitution in a template file.
# Uses %%placeholder%% format (double percent delimiters).
#
# This is useful for simple templates where Go templates are overkill.
#
# Placeholders in template should use %%name%% format.
#
# Examples:
#   ha::template::substitute /etc/nginx/nginx.conf.template /etc/nginx/nginx.conf \
#       port="8080" host="0.0.0.0"
#
#   # With %%delimited%% template:
#   # Template has: listen %%port%%;
#   ha::template::substitute template.conf /etc/nginx/nginx.conf port="8080"
# ---------------------------------------------------------------------------
ha::template::substitute() {
    local template_file="${1:?Template file is required}"
    local output_file="${2:?Output file is required}"
    shift
    local substitutions=("$@")

    # If template_file is not absolute, search for it
    if [[ "${template_file}" != /* ]]; then
        template_file="$(ha::template::find "${template_file}")" || return 1
    fi

    _ha_template_log "Substituting in ${template_file} -> ${output_file}"

    # Ensure output directory exists
    local output_dir
    output_dir="$(dirname "${output_file}")"
    if [[ ! -d "${output_dir}" ]]; then
        mkdir -p "${output_dir}" || {
            _ha_template_error "Failed to create output directory: ${output_dir}"
            return 1
        }
    fi

    # Copy template to output location
    if ! cp "${template_file}" "${output_file}"; then
        _ha_template_error "Failed to copy template: ${template_file}"
        return 1
    fi

    # Perform substitutions
    for substitution in "${substitutions[@]}"; do
        if [[ "${substitution}" =~ ^([^=]+)=(.*)$ ]]; then
            local placeholder="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # Escape special characters in replacement value for sed
            local escaped_value
            escaped_value="$(printf '%s\n' "${value}" | sed 's/[[\.*&]/\\&/g; s/]/\\]/g; s/\//\\\//g')"

            # Perform substitution (in-place on output file)
            if ! sed -i "s/%%${placeholder}%%/${escaped_value}/g" "${output_file}"; then
                _ha_template_error "Failed to substitute placeholder: %%${placeholder}%%"
                return 1
            fi

            _ha_template_debug "Substituted %%${placeholder}%% = ${value}"
        else
            _ha_template_error "Invalid substitution format: ${substitution} (expected key=value)"
            return 1
        fi
    done

    _ha_template_log "Substitution complete: ${output_file}"

    # Validate nginx config if output is .conf
    if [[ "${output_file}" == *.conf ]]; then
        _ha_template_validate_nginx "${output_file}" || return 1
    fi

    return 0
}

# ---------------------------------------------------------------------------
# ha::template::validate_nginx <config_file>
#
# Validates an nginx configuration file by running nginx -t.
# Returns 0 if valid, 1 otherwise.
#
# Example:
#   ha::template::validate_nginx /etc/nginx/servers/ingress.conf
# ---------------------------------------------------------------------------
ha::template::validate_nginx() {
    local config_file="${1:?Config file is required}"

    _ha_template_validate_nginx "${config_file}"
}

# ---------------------------------------------------------------------------
# ha::template::exists <filename> [search_path1] [search_path2] ...
#
# Checks if a template file exists without returning the path.
# Returns 0 (true) if found, 1 (false) otherwise.
#
# Uses the same search order as ha::template::find.
#
# Example:
#   if ha::template::exists "ingress.gtpl"; then
#       ha::template::render "ingress.gtpl" /etc/nginx/ingress.conf
#   fi
# ---------------------------------------------------------------------------
ha::template::exists() {
    local filename="${1:?Filename is required}"
    shift
    local search_paths=("$@")

    # Default search paths if none provided
    if [[ ${#search_paths[@]} -eq 0 ]]; then
        search_paths=(
            "/config/${HOSTNAME:-addon}/templates/"
            "/etc/${HOSTNAME:-addon}/templates/"
            "/etc/nginx/templates/"
            "/usr/local/lib/ha-framework/templates/"
        )
    fi

    # Search for the template file
    for search_path in "${search_paths[@]}"; do
        local full_path="${search_path}${filename}"
        if [[ -f "${full_path}" ]]; then
            return 0
        fi
    done

    return 1
}
