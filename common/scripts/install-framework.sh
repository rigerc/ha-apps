#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# install-framework.sh — Home Assistant Add-on Framework Installer
#
# This script installs the HA common framework into the container at
# /usr/local/lib/ha-framework/. It is intended to be run during
# the Docker build process or at container initialization.
#
# USAGE
#   During Docker build (from common/ directory):
#     COPY common/lib /usr/local/lib/ha-framework
#     COPY common/scripts/install-framework.sh /tmp/install.sh
#     RUN chmod +x /usr/local/lib/ha-framework/*.sh /tmp/install.sh && \
#         /tmp/install.sh && rm -f /tmp/install.sh
#
#   During container init (downloading from GitHub):
#     RUN apk add --no-cache curl && \
#         curl -fsSL "https://raw.githubusercontent.com/rigerc/ha-apps/main/common/scripts/install-framework.sh" -o /tmp/install.sh && \
#         bash /tmp/install.sh && rm -f /tmp/install.sh
#
#   To install from local copy during build:
#     RUN bash /tmp/install.sh --local
# ==============================================================================

set -e

# Installation directory
readonly FRAMEWORK_DIR="/usr/local/lib/ha-framework"
readonly VERSION_FILE="${FRAMEWORK_DIR}/version.txt"

# Colors for output (disabled in container, but useful for local testing)
readonly COLOR_RESET=""
readonly COLOR_GREEN=""
readonly COLOR_YELLOW=""
readonly COLOR_RED=""

# ---------------------------------------------------------------------------
# Logging functions
# ---------------------------------------------------------------------------
log_info() {
    echo "${COLOR_GREEN}[install-framework]${COLOR_RESET} $*"
}

log_warn() {
    echo "${COLOR_YELLOW}[install-framework]${COLOR_RESET} WARNING: $*" >&2
}

log_error() {
    echo "${COLOR_RED}[install-framework]${COLOR_RESET} ERROR: $*" >&2
}

# ---------------------------------------------------------------------------
# install_framework_from_local <source_dir>
#
# Installs framework from a local directory (typically during Docker build).
# ---------------------------------------------------------------------------
install_framework_from_local() {
    local source_dir="${1:-/usr/local/lib/ha-framework}"

    log_info "Installing framework from local copy: ${source_dir}"

    # Create framework directory
    mkdir -p "${FRAMEWORK_DIR}"

    # Copy all library files
    if [[ -d "${source_dir}" ]]; then
        cp -f "${source_dir}"/*.sh "${FRAMEWORK_DIR}/" 2>/dev/null || true
        log_info "Copied library files to ${FRAMEWORK_DIR}"
    else
        log_error "Source directory not found: ${source_dir}"
        return 1
    fi

    # Set permissions
    chmod +x "${FRAMEWORK_DIR}"/*.sh 2>/dev/null || true

    # Create version file
    echo "local-build" > "${VERSION_FILE}"

    log_info "Framework installed successfully from local copy"
    return 0
}

# ---------------------------------------------------------------------------
# install_framework_from_github <version>
#
# Downloads and installs framework from GitHub.
# ---------------------------------------------------------------------------
install_framework_from_github() {
    local version="${1:-main}"
    local base_url="https://raw.githubusercontent.com/rigerc/ha-apps/${version}/common"

    log_info "Installing framework from GitHub (branch: ${version})"

    # Create framework directory
    mkdir -p "${FRAMEWORK_DIR}"

    # List of library files to download
    local libraries=(
        "ha-log.sh"
        "ha-env.sh"
        "ha-config.sh"
        "ha-dirs.sh"
        "ha-secret.sh"
        "ha-validate.sh"
    )

    # Download each library file
    for lib in "${libraries[@]}"; do
        local url="${base_url}/lib/${lib}"
        local output="${FRAMEWORK_DIR}/${lib}"

        log_info "Downloading ${lib}..."

        if ! curl -fsSL "${url}" -o "${output}"; then
            log_error "Failed to download ${lib} from ${url}"
            return 1
        fi

        chmod +x "${output}"
    done

    # Create version file
    echo "${version}" > "${VERSION_FILE}"

    log_info "Framework version ${version} installed successfully"
    return 0
}

# ---------------------------------------------------------------------------
# verify_installation
#
# Verifies that all expected library files are present and executable.
# ---------------------------------------------------------------------------
verify_installation() {
    log_info "Verifying framework installation..."

    local required_libs=(
        "ha-log.sh"
        "ha-env.sh"
        "ha-config.sh"
        "ha-dirs.sh"
        "ha-secret.sh"
        "ha-validate.sh"
    )

    local missing=0
    for lib in "${required_libs[@]}"; do
        local path="${FRAMEWORK_DIR}/${lib}"
        if [[ ! -f "${path}" ]]; then
            log_error "Missing library: ${lib}"
            missing=1
        elif [[ ! -x "${path}" ]]; then
            log_warn "Library not executable: ${lib} (fixing...)"
            chmod +x "${path}"
        fi
    done

    if [[ ${missing} -eq 1 ]]; then
        log_error "Framework installation incomplete!"
        return 1
    fi

    # Show version if available
    if [[ -f "${VERSION_FILE}" ]]; then
        local version
        version="$(cat "${VERSION_FILE}")"
        log_info "Framework version: ${version}"
    fi

    log_info "Framework installation verified"
    return 0
}

# ---------------------------------------------------------------------------
# create_compat_symlinks
#
# Creates compatibility symlinks for old import paths.
# This helps with backward compatibility if add-ons source from legacy paths.
# ---------------------------------------------------------------------------
create_compat_symlinks() {
    local compat_dir="/usr/local/lib"
    local framework_dir="/usr/local/lib/ha-framework"

    # Create symlink for ha-log.sh (most common legacy path)
    if [[ ! -L "${compat_dir}/ha-log.sh" && ! -f "${compat_dir}/ha-log.sh" ]]; then
        ln -s "${framework_dir}/ha-log.sh" "${compat_dir}/ha-log.sh"
        log_info "Created compatibility symlink: ${compat_dir}/ha-log.sh"
    fi

    return 0
}

# ---------------------------------------------------------------------------
# show_usage
#
# Displays usage information.
# ---------------------------------------------------------------------------
show_usage() {
    cat <<EOF
Home Assistant Add-on Framework Installer

Usage:
    install-framework.sh [OPTIONS]

Options:
    --local              Install from local /usr/local/lib/ha-framework directory
    --github [branch]    Install from GitHub (default: main)
    --version            Show framework version and exit
    --help               Show this help message

Examples:
    # Install from local copy (during Docker build)
    install-framework.sh --local

    # Install from GitHub main branch
    install-framework.sh --github

    # Install from specific version tag
    install-framework.sh --github v1.0.0

EOF
}

# ---------------------------------------------------------------------------
# Main script logic
# ---------------------------------------------------------------------------
main() {
    local install_mode="auto"
    local github_version="main"

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --local)
                install_mode="local"
                shift
                ;;
            --github)
                install_mode="github"
                if [[ -n "${2:-}" && ! "${2}" =~ ^- ]]; then
                    github_version="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            --version)
                if [[ -f "${VERSION_FILE}" ]]; then
                    echo "HA Framework version: $(cat "${VERSION_FILE}")"
                else
                    echo "HA Framework not installed"
                fi
                return 0
                ;;
            --help|-h)
                show_usage
                return 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                return 1
                ;;
        esac
    done

    # Auto-detect mode if not specified
    if [[ "${install_mode}" == "auto" ]]; then
        if [[ -d "/usr/local/lib/ha-framework" ]] && \
           ls /usr/local/lib/ha-framework/*.sh >/dev/null 2>&1; then
            install_mode="local"
        else
            install_mode="github"
        fi
    fi

    # Execute installation based on mode
    case "${install_mode}" in
        local)
            install_framework_from_local "${FRAMEWORK_DIR}"
            ;;
        github)
            install_framework_from_github "${github_version}"
            ;;
        *)
            log_error "Invalid install mode: ${install_mode}"
            return 1
            ;;
    esac

    # Verify installation
    verify_installation

    # Create compatibility symlinks
    create_compat_symlinks

    return 0
}

# Run main if script is executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
