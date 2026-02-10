#!/bin/bash
#
# Build Home Assistant add-on for local testing
#
# This script builds a Home Assistant add-on Docker image locally for testing
# before publishing. It auto-detects architecture, reads build.yaml for the
# correct base image, and tags the image appropriately.
#
# Usage: bash .claude/skills/ha-apps/scripts/build.sh <addon-directory> [options]

set -euo pipefail

#######################################
# Error handler
#######################################
err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: ERROR: $*" >&2
}

#######################################
# Log info message
#######################################
info() {
  echo "==> $*" >&2
}

#######################################
# Display usage information
#######################################
usage() {
  cat <<'EOF'
Usage: build.sh <addon-directory> [OPTIONS]

Build a Home Assistant add-on Docker image for local testing.

ARGUMENTS:
  <addon-directory>    Path to the add-on directory (e.g., "romm", "profilarr")

OPTIONS:
  -p, --platform PLATFORM    Override platform detection (amd64, aarch64, armv7)
  -t, --tag TAG              Custom image tag (default: "local/<slug>:test")
  -r, --run                  Run container after successful build
  -s, --shell                Run container with shell after build for debugging
  --build-arg KEY=VALUE      Pass build arguments to Docker
  -n, --no-cache             Build without using cache
  -h, --help                 Display this help message

EXAMPLES:
  # Build romm add-on for current architecture
  build.sh romm

  # Build for specific architecture
  build.sh romm --platform aarch64

  # Build and run immediately
  build.sh romm --run

  # Build with custom tag and no cache
  build.sh romm --tag my-test:latest --no-cache

  # Build and start shell for debugging
  build.sh romm --shell

ARCHITECTURES:
  amd64     - x86_64 systems (most desktop PCs)
  aarch64   - ARM 64-bit (RPi 4, Apple Silicon)
  armv7     - ARM 32-bit (RPi 3 and older)

EOF
}

#######################################
# Detect system architecture
# Returns:
#   Home Assistant architecture name
#######################################
detect_arch() {
  local machine
  machine="$(uname -m)"

  case "${machine}" in
    x86_64|x86_32|i686|i386)
      echo "amd64"
      ;;
    aarch64|arm64)
      echo "aarch64"
      ;;
    armv7l|armv6l)
      echo "armv7"
      ;;
    *)
      err "Unsupported architecture: ${machine}"
      return 1
      ;;
  esac
}

#######################################
# Check if required tools are installed
#######################################
check_dependencies() {
  local missing_deps=()

  if ! command -v docker &>/dev/null; then
    missing_deps+=("docker")
  fi

  if ! command -v yq &>/dev/null; then
    missing_deps+=("yq")
  fi

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    err "Missing required dependencies: ${missing_deps[*]}"
    echo "  Install with:" >&2
    for dep in "${missing_deps[@]}"; do
      case "${dep}" in
        docker)
          echo "    - Visit https://docs.docker.com/get-docker/" >&2
          ;;
        yq)
          echo "    - Visit https://github.com/mikefarah/yq#install" >&2
          ;;
      esac
    done
    return 1
  fi

  return 0
}

#######################################
# Validate addon directory structure
# Arguments:
#   addon_dir - Path to add-on directory
# Returns:
#   0 if valid, 1 otherwise
#######################################
validate_addon_dir() {
  local addon_dir="$1"

  if [[ ! -d "${addon_dir}" ]]; then
    err "Add-on directory not found: ${addon_dir}"
    return 1
  fi

  local required_files=("config.yaml" "Dockerfile" "build.yaml")
  for file in "${required_files[@]}"; do
    if [[ ! -f "${addon_dir}/${file}" ]]; then
      err "Required file not found: ${addon_dir}/${file}"
      return 1
    fi
  done

  return 0
}

#######################################
# Get base image from build.yaml for architecture
# Arguments:
#   build_yaml - Path to build.yaml
#   arch       - Architecture (amd64, aarch64, armv7)
# Returns:
#   Base image for the architecture
#######################################
get_base_image() {
  local build_yaml="$1"
  local arch="$2"

  local base_image
  base_image="$(yq -r ".build_from.${arch}" "${build_yaml}")"

  if [[ "${base_image}" == "null" ]] || [[ -z "${base_image}" ]]; then
    err "No base image found for architecture '${arch}' in ${build_yaml}"
    echo "Available architectures:" >&2
    yq -r '.build_from | keys[]' "${build_yaml}" | sed 's/^/  - /' >&2
    return 1
  fi

  echo "${base_image}"
}

#######################################
# Get slug from config.yaml
# Arguments:
#   config_yaml - Path to config.yaml
# Returns:
#   Add-on slug
#######################################
get_slug() {
  local config_yaml="$1"
  yq -r '.slug' "${config_yaml}"
}

#######################################
# Build the Docker image
# Arguments:
#   addon_dir      - Path to add-on directory
#   platform       - Architecture
#   base_image     - Base Docker image
#   tag            - Image tag
#   build_args     - Array of additional build args
#   no_cache       - Whether to disable cache
# Returns:
#   0 on success, 1 on error
#######################################
build_image() {
  local addon_dir="$1"
  local platform="$2"
  local base_image="$3"
  local tag="$4"
  local -a build_args=("${@:5}")
  local no_cache="${build_args[-1]}"
  unset 'build_args[-1]'  # Remove no_cache from array

  info "Building add-on: ${addon_dir}"
  info "  Platform: ${platform}"
  info "  Base image: ${base_image}"
  info "  Target tag: ${tag}"

  local -a docker_cmd=(docker build)

  # Add --no-cache if requested
  if [[ "${no_cache}" == "true" ]]; then
    docker_cmd+=(--no-cache)
  fi

  # Add build args
  docker_cmd+=(--build-arg "BUILD_FROM=${base_image}")
  docker_cmd+=(--platform "linux/${platform}")

  # Add custom build args
  for arg in "${build_args[@]}"; do
    docker_cmd+=(--build-arg "${arg}")
  done

  # Add tag and context
  docker_cmd+=(-t "${tag}" "${addon_dir}")

  # Execute build
  info "Running Docker build..."
  if ! "${docker_cmd[@]}"; then
    err "Docker build failed"
    return 1
  fi

  info "Build successful: ${tag}"
  return 0
}

#######################################
# Run the built container
# Arguments:
#   addon_dir  - Path to add-on directory
#   image_tag  - Docker image tag
#   start_shell - Start shell instead of normal entrypoint
# Returns:
#   0 on success, 1 on error
#######################################
run_container() {
  local addon_dir="$1"
  local image_tag="$2"
  local start_shell="$3"

  local config_yaml="${addon_dir}/config.yaml"
  local slug
  slug="$(get_slug "${config_yaml}")"

  # Get exposed ports from config.yaml
  local -a ports=()
  while IFS= read -r port_mapping; do
    # Parse port mapping like "5999/tcp: 5999"
    local container_port
    container_port="$(echo "${port_mapping}" | cut -d: -f1 | tr -d ' ')"
    ports+=("-p" "${container_port}:${container_port}")
  done < <(yq -r '.ports // {} | to_entries[] | "\(.key): \(.value)"' "${config_yaml}")

  # Get ingress port if configured
  if yq -e '.ingress // false' "${config_yaml}" &>/dev/null; then
    local ingress_port
    ingress_port="$(yq -r '.ingress_port' "${config_yaml}")"
    if [[ "${ingress_port}" != "null" ]]; then
      ports+=("-p" "${ingress_port}:${ingress_port}")
    fi
  fi

  # Build volume mappings based on config.yaml map section
  local -a volumes=()
  local share_dir="${PWD}/${slug}-share"
  local config_dir="${PWD}/${slug}-config"

  # Create test directories
  mkdir -p "${share_dir}" "${config_dir}"

  # Map addon_config if defined
  if yq -e '.map[] | select(.type == "addon_config")' "${config_yaml}" &>/dev/null; then
    local map_path
    map_path="$(yq -r '.map[] | select(.type == "addon_config") | .path // "/config"' "${config_yaml}")"
    volumes+=("-v" "${config_dir}:${map_path}")
  fi

  # Map share if defined
  if yq -e '.map[] | select(. == "share" or .type == "share")' "${config_yaml}" &>/dev/null; then
    volumes+=("-v" "${share_dir}:/share")
  fi

  info "Starting container..."
  info "  Test directories created:"
  info "    ${config_dir} (mounted to /config)"
  info "    ${share_dir} (mounted to /share)"

  if [[ ${#ports[@]} -gt 0 ]]; then
    info "  Mapped ports: ${ports[*]}"
  fi

  local -a run_cmd=(docker run --rm -it)

  # Add ports
  run_cmd+=("${ports[@]}")

  # Add volumes
  run_cmd+=("${volumes[@]}")

  # Override entrypoint for shell mode
  if [[ "${start_shell}" == "true" ]]; then
    info "  Starting with shell (override entrypoint)..."
    run_cmd+=(--entrypoint sh)
  fi

  run_cmd+=("${image_tag}")

  info "Executing: ${run_cmd[*]}"
  exec "${run_cmd[@]}"
}

#######################################
# Main script logic
#######################################
main() {
  # Check dependencies
  check_dependencies || exit 1

  local platform=""
  local tag=""
  local run_after_build=false
  local start_shell=false
  local no_cache=false
  local -a build_args=()

  # Parse arguments - handle help first
  for arg in "$@"; do
    if [[ "${arg}" == "-h" ]] || [[ "${arg}" == "--help" ]]; then
      usage
      exit 0
    fi
  done

  # Check for required add-on directory argument
  if [[ $# -eq 0 ]]; then
    err "Missing required argument: <addon-directory>"
    usage
    exit 1
  fi

  local addon_dir="$1"
  shift

  # Parse options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--platform)
        platform="$2"
        shift 2
        ;;
      -t|--tag)
        tag="$2"
        shift 2
        ;;
      -r|--run)
        run_after_build=true
        shift
        ;;
      -s|--shell)
        start_shell=true
        run_after_build=true
        shift
        ;;
      --build-arg)
        build_args+=("$2")
        shift 2
        ;;
      -n|--no-cache)
        no_cache=true
        shift
        ;;
      *)
        err "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done

  # Validate addon directory
  if ! validate_addon_dir "${addon_dir}"; then
    exit 1
  fi

  # Detect platform if not specified
  if [[ -z "${platform}" ]]; then
    platform="$(detect_arch)" || exit 1
  fi

  # Read config files
  local config_yaml="${addon_dir}/config.yaml"
  local build_yaml="${addon_dir}/build.yaml"

  # Get base image
  local base_image
  base_image="$(get_base_image "${build_yaml}" "${platform}")" || exit 1

  # Generate default tag if not specified
  if [[ -z "${tag}" ]]; then
    local slug
    slug="$(get_slug "${config_yaml}")"
    tag="local/${slug}:test"
  fi

  # Build image
  if ! build_image "${addon_dir}" "${platform}" "${base_image}" "${tag}" "${build_args[@]}" "${no_cache}"; then
    exit 1
  fi

  # Run container if requested
  if [[ "${run_after_build}" == "true" ]]; then
    run_container "${addon_dir}" "${tag}" "${start_shell}"
  fi

  info "Done! Image '${tag}' is ready to use."
  info ""
  info "To run manually:"
  info "  docker run --rm -it ${tag}"
  info ""
  info "Or with volume mounts:"
  info "  docker run --rm -it -v \$(pwd)/${slug}-config:/config ${tag}"
}

main "$@"
