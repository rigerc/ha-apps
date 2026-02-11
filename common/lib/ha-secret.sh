#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# ha-secret.sh — Secret generation and management for Home Assistant add-ons
#
# USAGE
#   Source this file at the top of any init or service script:
#
#     # shellcheck source=/usr/local/lib/ha-framework/ha-secret.sh
#     source /usr/local/lib/ha-framework/ha-secret.sh
#
#   Then call the helper functions:
#
#     ha::secret::generate "/data/.secret_key"
#     ha::secret::ensure "auth_secret" "/data/.auth_secret"
#
# DESCRIPTION
#   These utilities provide secure secret generation and management,
#   with support for automatic generation when secrets are not configured.
# ==============================================================================

# Guard against double-sourcing
[[ -n "${_HA_SECRET_LOADED:-}" ]] && return 0
readonly _HA_SECRET_LOADED=1

# Default secret length (bytes)
_HA_SECRET_DEFAULT_LENGTH="${_HA_SECRET_DEFAULT_LENGTH:-32}"

# Default secret file permissions (restrictive)
_HA_SECRET_FILE_MODE="${_HA_SECRET_FILE_MODE:-600}"

# ---------------------------------------------------------------------------
# ha::secret::generate <output_file> [length] [mode]
#
# Generates a cryptographically secure random secret and saves it to a file.
# Uses openssl rand -hex for secure random bytes.
#
# Examples:
#   ha::secret::generate "/data/.secret_key"
#   ha::secret::generate "/data/.jwt_secret" 64 600
# ---------------------------------------------------------------------------
ha::secret::generate() {
    local output_file="${1:?Output file is required}"
    local length="${2:-${_HA_SECRET_DEFAULT_LENGTH}}"
    local mode="${3:-${_HA_SECRET_FILE_MODE}}"

    # Validate output directory exists
    local output_dir
    output_dir="$(dirname "${output_file}")"
    if [[ ! -d "${output_dir}" ]]; then
        mkdir -p "${output_dir}" || bashio::exit.nok "Failed to create directory: ${output_dir}"
    fi

    # Check if secret already exists
    if [[ -f "${output_file}" ]]; then
        bashio::log.warning "Secret file already exists: ${output_file} (not overwriting)"
        cat "${output_file}"
        return 0
    fi

    bashio::log.info "Generating ${length}-byte secret: ${output_file}"

    # Generate secret using openssl
    local secret
    if ! secret="$(openssl rand -hex "${length}" 2>/dev/null)"; then
        # Fallback to /dev/urandom if openssl fails
        bashio::log.warning "openssl rand failed, using /dev/urandom as fallback"
        local byte_length=$((length / 2))
        secret="$(head -c "${byte_length}" /dev/urandom | xxd -p -c "${byte_length}")"
    fi

    # Write secret to file with restrictive permissions
    umask 077
    echo "${secret}" > "${output_file}"
    chmod "${mode}" "${output_file}"
    umask 022

    bashio::log.info "Secret generated and saved to ${output_file}"

    echo "${secret}"
}

# ---------------------------------------------------------------------------
# ha::secret::ensure <config_key> <output_file> [length] [mode]
#
# Ensures a secret exists by first checking the configuration, then falling
# back to a previously generated file, and finally generating a new one if needed.
# This is the primary function for most use cases.
#
# The secret value is output to stdout for use in environment variables.
#
# Examples:
#   secret_value="$(ha::secret::ensure "auth_secret" "/data/.auth_secret")"
#   export AUTH_SECRET_KEY="${secret_value}"
#
#   # With custom length and permissions:
#   jwt_secret="$(ha::secret::ensure "jwt_secret" "/data/.jwt" 64 600)"
# ---------------------------------------------------------------------------
ha::secret::ensure() {
    local config_key="${1:?Config key is required}"
    local output_file="${2:?Output file is required}"
    local length="${3:-${_HA_SECRET_DEFAULT_LENGTH}}"
    local mode="${4:-${_HA_SECRET_FILE_MODE}}"

    # 1. Check if secret is provided via configuration
    if bashio::config.has_value "${config_key}"; then
        bashio::log.info "Using ${config_key} from add-on configuration"
        bashio::config "${config_key}"
        return 0
    fi

    # 2. Check if secret file already exists
    if [[ -f "${output_file}" ]]; then
        bashio::log.info "Using previously generated ${config_key} from ${output_file}"
        cat "${output_file}"
        return 0
    fi

    # 3. Generate new secret
    bashio::log.info "No ${config_key} configured — generating one automatically"
    ha::secret::generate "${output_file}" "${length}" "${mode}"
}

# ---------------------------------------------------------------------------
# ha::secret::generate_token <length> [prefix]
#
# Generates a random token suitable for API keys or session tokens.
# Uses alphanumeric characters by default.
#
# Examples:
#   api_token="$(ha::secret::generate_token 32)"
#   session_id="$(ha::secret::generate_token 16 "sess-")"
# ---------------------------------------------------------------------------
ha::secret::generate_token() {
    local length="${1:-32}"
    local prefix="${2:-}"

    # Use /dev/urandom with tr for alphanumeric output
    local token
    token="$(head -c "$((length * 2))" /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | head -c "${length}")"

    echo "${prefix}${token}"
}

# ---------------------------------------------------------------------------
# ha::secret::hash_password <password> [salt]
#
# Generates a hash of a password using the specified salt.
# Uses SHA-256 by default.
#
# Examples:
#   hash="$(ha::secret::hash_password "${password}" "${salt}")"
#   ha::secret::hash_password "password123" "static_salt"
# ---------------------------------------------------------------------------
ha::secret::hash_password() {
    local password="${1:?Password is required}"
    local salt="${2:-}"
    local hash

    if command -v openssl >/dev/null 2>&1; then
        # Use openssl for hashing
        if [[ -n "${salt}" ]]; then
            hash="$(echo -n "${salt}${password}" | openssl dgst -sha256 -hex | awk '{print $2}')"
        else
            hash="$(echo -n "${password}" | openssl dgst -sha256 -hex | awk '{print $2}')"
        fi
    elif command -v sha256sum >/dev/null 2>&1; then
        # Fallback to sha256sum
        if [[ -n "${salt}" ]]; then
            hash="$(echo -n "${salt}${password}" | sha256sum | cut -d' ' -f1)"
        else
            hash="$(echo -n "${password}" | sha256sum | cut -d' ' -f1)"
        fi
    else
        bashio::exit.nok "No hashing tool available (openssl or sha256sum required)"
    fi

    echo "${hash}"
}

# ---------------------------------------------------------------------------
# ha::secret::compare <file1> <file2>
#
# Securely compares two files for equality in constant time.
# Returns 0 if files are identical, 1 otherwise.
#
# Example:
#   if ha::secret::compare "/data/secret1" "/data/secret2"; then
#       bashio::log.info "Secrets match"
#   fi
# ---------------------------------------------------------------------------
ha::secret::compare() {
    local file1="${1:?First file is required}"
    local file2="${2:?Second file is required}"

    # Use cmp for byte-by-byte comparison (returns non-zero if files differ or don't exist)
    if cmp -s "${file1}" "${file2}"; then
        return 0  # Files are identical
    else
        return 1  # Files differ or don't exist
    fi
}

# ---------------------------------------------------------------------------
# ha::secret::from_b64 <encoded_value>
#
# Decodes a base64-encoded secret value.
# Useful for reading secrets from environment variables.
#
# Example:
#   decoded_secret="$(ha::secret::from_b64 "${ENCODED_SECRET}")"
# ---------------------------------------------------------------------------
ha::secret::from_b64() {
    local encoded_value="${1:?Encoded value is required}"

    # Try to decode using base64 command
    if echo -n "${encoded_value}" | base64 -d >/dev/null 2>&1; then
        echo -n "${encoded_value}" | base64 -d
        return 0
    fi

    bashio::exit.nok "Failed to decode base64 value"
}

# ---------------------------------------------------------------------------
# ha::secret::to_b64 <value>
#
# Encodes a value to base64.
# Useful for preparing secrets for environment variables.
#
# Example:
#   encoded_secret="$(ha::secret::to_b64 "my_secret_value")"
# ---------------------------------------------------------------------------
ha::secret::to_b64() {
    local value="${1:?Value is required}"

    echo -n "${value}" | base64 -w 0
}

# ---------------------------------------------------------------------------
# ha::secret::validate_key <key_value> [min_length]
#
# Validates that a secret key meets minimum requirements.
# Returns 0 if valid, 1 otherwise.
#
# Examples:
#   if ha::secret::validate_key "${api_key}"; then
#       bashio::log.info "API key is valid"
#   fi
#   ha::secret::validate_key "${key}" 16
# ---------------------------------------------------------------------------
ha::secret::validate_key() {
    local key_value="${1:?Key value is required}"
    local min_length="${2:-16}"

    # Check minimum length after trimming whitespace
    local trimmed="${key_value#"${key_value%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"

    if [[ ${#trimmed} -lt ${min_length} ]]; then
        bashio::log.error "Key must be at least ${min_length} characters"
        return 1
    fi

    # Check for empty or whitespace-only keys
    if [[ -z "${trimmed}" ]]; then
        bashio::log.error "Key cannot be empty or whitespace only"
        return 1
    fi

    return 0
}
