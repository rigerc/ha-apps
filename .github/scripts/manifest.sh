#!/bin/bash
#
# Generate manifest.json and update dependabot.yml for Home Assistant addons
#
# This script scans addon directories for config.yaml, build.yaml, and Dockerfile
# files to generate a manifest.json file. It can also update .github/dependabot.yml
# with the discovered addon directories. Can also generate README.md files using gomplate.

set -euo pipefail

# Constants
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
readonly PROJECT_ROOT
readonly MANIFEST_OUTPUT="${PROJECT_ROOT}/manifest.json"
readonly DEPENDABOT_CONFIG="${PROJECT_ROOT}/.github/dependabot.yml"
readonly DEPLOYER_V3_WORKFLOW="${PROJECT_ROOT}/.github/workflows/addon-build.yaml"
readonly RELEASE_PLEASE_MANIFEST="${PROJECT_ROOT}/.release-please-manifest.json"

# Options
UPDATE_DEPENDABOT=false
UPDATE_WORKFLOW_DISPATCH=false
GENERATE_README=false
UPDATE_RELEASE_PLEASE=false

# Error handling
err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

#######################################
# Get latest version from Docker Hub registry
# Globals:
#   None
# Arguments:
#   image - Docker image name (e.g., "rommapp/romm")
# Returns:
#   Latest version tag, or empty string on failure
#######################################
get_docker_hub_latest() {
  local image="$1"
  local latest_version=""

  # Query Docker Hub API - get tags that start with digit or 'v' followed by digit
  latest_version="$(curl -s "https://registry.hub.docker.com/v2/repositories/${image}/tags?page_size=100" \
    | jq -r '.results | map(select(.name | test("^v?[0-9]"))) | map(.name) | sort | reverse | .[0]' 2>/dev/null || echo "")"

  # Handle null result
  if [[ "${latest_version}" == "null" ]]; then
    latest_version=""
  fi

  echo "${latest_version}"
}

#######################################
# Get latest version from GHCR registry
# Globals:
#   None
# Arguments:
#   image - Full GHCR image name (e.g., "ghcr.io/owner/repo")
# Returns:
#   Latest version tag, or empty string on failure
#######################################
get_ghcr_latest() {
  local image="$1"
  local repo_path="${image#ghcr.io/}"
  local latest_version=""

  # Try to get tags from GHCR (may require auth, so we'll handle failures gracefully)
  latest_version="$(curl -s "https://ghcr.io/v2/${repo_path}/tags/list" \
    | jq -r '.tags | map(select(. | test("^v?[0-9]"))) | sort | reverse | .[0]' 2>/dev/null || echo "")"

  # Handle null result
  if [[ "${latest_version}" == "null" ]]; then
    latest_version=""
  fi

  echo "${latest_version}"
}

#######################################
# Get latest release tag from GitHub API
# Globals:
#   None
# Arguments:
#   project_url - GitHub project URL (e.g., "https://github.com/owner/repo")
# Returns:
#   Latest release tag, or empty string on failure
#######################################
get_github_release_latest() {
  local project_url="$1"
  local latest_version=""
  local owner_repo=""

  # Parse owner/repo from GitHub URL
  # Handles: https://github.com/owner/repo, http://github.com/owner/repo, github.com/owner/repo
  owner_repo="${project_url#*://github.com/}"
  owner_repo="${owner_repo#*github.com/}"
  owner_repo="${owner_repo%.git}"

  # Validate we got owner/repo format
  if [[ ! "${owner_repo}" =~ ^[^/]+/[^/]+$ ]]; then
    return 1
  fi

  # Query GitHub Releases API for latest release
  latest_version="$(curl -s "https://api.github.com/repos/${owner_repo}/releases/latest" \
    | jq -r '.tag_name // ""' 2>/dev/null || echo "")"

  echo "${latest_version}"
}

#######################################
# Get latest version from registry based on image prefix
# Globals:
#   None
# Arguments:
#   image - Docker image name
#   project_url - Optional GitHub project URL for release API fallback
# Returns:
#   Latest version tag, or empty string on failure
#######################################
get_latest_version() {
  local image="$1"
  local project_url="${2:-}"
  local latest=""

  # Prefer GitHub Release API when project URL is available
  if [[ -n "${project_url}" && "${project_url}" == *github.com/* ]]; then
    latest="$(get_github_release_latest "${project_url}")"
  fi

  # Fall back to registry APIs if GitHub API didn't return a version
  if [[ -z "${latest}" ]]; then
    if [[ "${image}" == ghcr.io/* ]]; then
      latest="$(get_ghcr_latest "${image}")"
    elif [[ "${image}" == docker.io/* ]]; then
      # Remove docker.io/ prefix for Docker Hub
      latest="$(get_docker_hub_latest "${image#docker.io/}")"
    else
      # Assume Docker Hub (default registry)
      latest="$(get_docker_hub_latest "${image}")"
    fi
  fi

  echo "${latest}"
}

#######################################
# Check if gomplate is installed
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   0 if gomplate is available, 1 otherwise
#######################################
check_gomplate() {
  if ! command -v gomplate &>/dev/null; then
    err "Error: gomplate is required but not installed"
    err "Install from: https://github.com/hairyhenderson/gomplate/releases"
    err "Or run: curl -o /usr/local/bin/gomplate -sSL https://github.com/hairyhenderson/gomplate/releases/download/v4.5.0/gomplate_linux-amd64 && chmod +x /usr/local/bin/gomplate"
    return 1
  fi
  return 0
}

#######################################
# Get repository info from git remote
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   Echoes "owner/repo" format, empty if not in git repo
#######################################
get_repo_info() {
  local remote_url
  remote_url="$(git remote get-url origin 2>/dev/null || echo "")"

  # Parse different URL formats:
  # SSH: git@github.com:owner/repo.git → owner/repo
  # HTTPS: https://github.com/owner/repo → owner/repo
  # HTTPS with .git: https://github.com/owner/repo.git → owner/repo

  local repo_path="${remote_url}"
  repo_path="${repo_path#git@github.com:}"      # Remove SSH prefix
  repo_path="${repo_path#https://github.com/}" # Remove HTTPS prefix
  repo_path="${repo_path%.git}"                # Remove .git suffix

  echo "${repo_path}"
}

#######################################
# Generate root README.md from template
# Globals:
#   PROJECT_ROOT
#   MANIFEST_OUTPUT
# Arguments:
#   None
# Returns:
#   0 on success, 1 on error
#######################################
generate_root_readme() {
  local template_file="${PROJECT_ROOT}/.github/templates/.README.tmpl"
  local output_file="${PROJECT_ROOT}/README.md"
  local repo_slug
  repo_slug="$(get_repo_info)"

  [[ -z "${repo_slug}" ]] && repo_slug="rigerc/ha-apps"

  # Check template exists
  if [[ ! -f "${template_file}" ]]; then
    err "Error: Template not found: ${template_file}"
    return 1
  fi

  # Check manifest exists
  if [[ ! -f "${MANIFEST_OUTPUT}" ]]; then
    err "Error: manifest.json not found. Generate it first."
    return 1
  fi

  # Generate README using datasources instead of env vars
  echo "Generating root README.md..." >&2
  if ! REPOSITORY="${repo_slug}" \
       REPOSITORY_URL="https://github.com/${repo_slug}" \
       AUTHOR_NAME="${repo_slug%%/*}" \
       gomplate \
         --datasource addons="${MANIFEST_OUTPUT}" \
         --file="${template_file}" \
         --out="${output_file}"; then
    err "Error: Failed to generate README.md"
    return 1
  fi

  echo "Generated ${output_file}" >&2
  return 0
}

#######################################
# Generate individual addon READMEs from template
# Globals:
#   PROJECT_ROOT
#   MANIFEST_OUTPUT
# Arguments:
#   slugs - Optional specific addon slugs (if empty, generates all)
# Returns:
#   0 on success, 1 on error
#######################################
# shellcheck disable=SC2120
generate_addon_readmes() {
  local -a specific_slugs=("$@")
  local template_file="${PROJECT_ROOT}/.github/templates/.README_ADDON.tmpl"
  local repo_slug
  repo_slug="$(get_repo_info)"

  [[ -z "${repo_slug}" ]] && repo_slug="rigerc/ha-apps"

  # Check template exists
  if [[ ! -f "${template_file}" ]]; then
    err "Error: Template not found: ${template_file}"
    return 1
  fi

  # Check manifest exists
  if [[ ! -f "${MANIFEST_OUTPUT}" ]]; then
    err "Error: manifest.json not found. Generate it first."
    return 1
  fi

  # Get list of addons to process
  local -a slugs=()
  if [[ ${#specific_slugs[@]} -gt 0 ]]; then
    slugs=("${specific_slugs[@]}")
  else
    # Read all slugs from manifest
    while IFS= read -r slug; do
      slugs+=("${slug}")
    done < <(jq -r '.[].slug' "${MANIFEST_OUTPUT}")
  fi

  # Generate README for each addon
  for slug in "${slugs[@]}"; do
    local addon_dir="${PROJECT_ROOT}/${slug}"
    local output_file="${addon_dir}/README.md"

    # Skip if addon directory doesn't exist
    if [[ ! -d "${addon_dir}" ]]; then
      err "Warning: Addon directory not found: ${addon_dir}"
      continue
    fi

    echo "Generating README for ${slug}..." >&2

    if ! REPOSITORY="${repo_slug}" \
         REPOSITORY_URL="https://github.com/${repo_slug}" \
         ADDON_SLUG="${slug}" \
         gomplate \
           --datasource addons="${MANIFEST_OUTPUT}" \
           --file="${template_file}" \
           --out="${output_file}"; then
      err "Error: Failed to generate README for ${slug}"
      continue
    fi
  done

  echo "Generated addon README files" >&2
  return 0
}

#######################################
# Display usage information
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
usage() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [OPTIONS]

Generate manifest.json for Home Assistant addons.

OPTIONS:
  -d, --update-dependabot     Update .github/dependabot.yml with addon directories
  -w, --update-workflow       Update addon-build.yaml workflow_dispatch inputs
  -r, --update-release-please Update .release-please-manifest.json with addon packages
  -g, --generate-readme       Generate README.md files using gomplate templates
  -h, --help                  Display this help message

EXAMPLES:
  $(basename "${BASH_SOURCE[0]}")                      # Generate manifest.json only
  $(basename "${BASH_SOURCE[0]}") -d                  # Generate manifest.json and update dependabot.yml
  $(basename "${BASH_SOURCE[0]}") -w                  # Generate manifest.json and update workflow inputs
  $(basename "${BASH_SOURCE[0]}") -r                  # Generate manifest.json and update release-please manifest
  $(basename "${BASH_SOURCE[0]}") -g                  # Generate manifest.json and README files
  $(basename "${BASH_SOURCE[0]}") -d -w -r -g         # Generate manifest.json and update all configs and READMEs

EOF
}

#######################################
# Parse command line arguments
# Globals:
#   UPDATE_DEPENDABOT
#   UPDATE_WORKFLOW_DISPATCH
#   UPDATE_RELEASE_PLEASE
#   GENERATE_README
# Arguments:
#   All script arguments
# Returns:
#   None
#######################################
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--update-dependabot)
        UPDATE_DEPENDABOT=true
        shift
        ;;
      -w|--update-workflow)
        UPDATE_WORKFLOW_DISPATCH=true
        shift
        ;;
      -r|--update-release-please)
        UPDATE_RELEASE_PLEASE=true
        shift
        ;;
      -g|--generate-readme)
        GENERATE_README=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        err "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done
}

#######################################
# Extract addon information from config files
# Globals:
#   None
# Arguments:
#   config_file - Path to config.yaml
# Returns:
#   0 on success, 1 on error
#######################################
extract_addon_info() {
  local config_file="$1"
  local dir
  local dockerfile
  local build_yaml
  local icon_file
  local slug
  local version
  local name
  local description
  local architectures
  local project
  local from_line
  local image_tag
  local image
  local tag
  local has_icon

  dir="$(dirname "${config_file}")"
  dockerfile="${dir}/Dockerfile"
  build_yaml="${dir}/build.yaml"
  icon_file="${dir}/icon.png"

  # Dockerfile must exist
  [[ -f "${dockerfile}" ]] || return 1

  # Extract values from config.yaml
  slug="$(yq -r '.slug' "${config_file}")"
  version="$(yq -r '.version' "${config_file}")"
  name="$(yq -r '.name' "${config_file}")"
  description="$(yq -r '.description' "${config_file}")"
  architectures="$(yq -r '.arch | @json' "${config_file}")"

  # Extract project from build.yaml if it exists
  project=""
  if [[ -f "${build_yaml}" ]]; then
    project="$(yq -r '.labels.project // ""' "${build_yaml}")"
  fi

  # Check if icon.png exists
  has_icon="false"
  if [[ -f "${icon_file}" ]]; then
    has_icon="true"
  fi

  # Check ingress support (convert null to false for JSON)
  ingress="false"
  if [[ -f "${config_file}" ]]; then
    ingress_value="$(yq -r '.ingress // "null"' "${config_file}" 2>/dev/null)"
    if [[ "${ingress_value}" == "true" ]]; then
      ingress="true"
    fi
  fi

  # Validate required fields
  [[ -n "${slug}" && -n "${version}" ]] || return 1

  # Extract first FROM ... AS line from Dockerfile
  from_line="$(grep -iE '^FROM .* AS ' "${dockerfile}" | head -n1 || true)"
  [[ -n "${from_line}" ]] || return 1

  image_tag="$(awk '{print $2}' <<< "${from_line}")"
  image="${image_tag%%:*}"
  tag="${image_tag#*:}"

  # Get latest version from registry and compare
  latest_tag=""
  is_up_to_date="null"

  if [[ -n "${image}" && -n "${tag}" ]]; then
    echo "Checking latest version for ${image}..." >&2
    latest_tag="$(get_latest_version "${image}" "${project}")"

    if [[ -n "${latest_tag}" ]]; then
      # Remove 'v' prefix if present for comparison
      current_clean="${tag#v}"
      latest_clean="${latest_tag#v}"

      if [[ "${current_clean}" == "${latest_clean}" ]]; then
        is_up_to_date="true"
      else
        is_up_to_date="false"
      fi
      echo "  Current: ${tag}, Latest: ${latest_tag}, Up to date: ${is_up_to_date}" >&2
    else
      echo "  Could not fetch latest version from registry" >&2
    fi
  fi

  # Output JSON object for this addon
  jq -n \
    --arg slug "${slug}" \
    --arg version "${version}" \
    --arg name "${name}" \
    --arg description "${description}" \
    --argjson architectures "${architectures}" \
    --arg image "${image}" \
    --arg tag "${tag}" \
    --arg latest_tag "${latest_tag}" \
    --arg project "${project}" \
    --argjson has_icon "${has_icon}" \
    --argjson ingress "${ingress}" \
    --argjson is_up_to_date "${is_up_to_date}" \
    '{
      slug: $slug,
      version: $version,
      name: $name,
      description: $description,
      arch: $architectures,
      image: $image,
      tag: $tag,
      latest_tag: $latest_tag,
      project: $project,
      has_icon: $has_icon,
      ingress: $ingress,
      is_up_to_date: $is_up_to_date
    }'
}

#######################################
# Generate manifest.json from addon directories
# Globals:
#   PROJECT_ROOT
#   MANIFEST_OUTPUT
# Arguments:
#   None
# Returns:
#   0 on success, 1 on error
#   Outputs: Array of addon slugs
#######################################
generate_manifest() {
  local manifest="[]"
  local config_file
  local addon_info
  local -a slugs=()

  cd "${PROJECT_ROOT}"

  while IFS= read -r config_file; do
    if addon_info="$(extract_addon_info "${config_file}" 2>/dev/null)"; then
      manifest="$(jq --argjson addon "${addon_info}" '. + [$addon]' <<< "${manifest}")"

      # Extract slug for dependabot update
      local slug
      slug="$(jq -r '.slug' <<< "${addon_info}")"
      slugs+=("${slug}")
    fi
  done < <(find . -mindepth 2 -maxdepth 2 -type f \( -name "config.yaml" -o -name "config.yml" \))

  # Write manifest atomically
  echo "${manifest}" | jq '.' > "${MANIFEST_OUTPUT}"
  echo "Generated ${MANIFEST_OUTPUT}" >&2

  # Return slugs as newline-separated output to stdout (for dependabot update)
  printf '%s\n' "${slugs[@]}"
}

#######################################
# Update dependabot.yml with addon directories
# Globals:
#   DEPENDABOT_CONFIG
# Arguments:
#   slugs - Array of addon slugs (one per line via stdin)
# Returns:
#   0 on success, 1 on error
#######################################
update_dependabot() {
  local -a slugs
  readarray -t slugs

  [[ "${#slugs[@]}" -gt 0 ]] || {
    err "No addon slugs found for dependabot update"
    return 1
  }

  [[ -f "${DEPENDABOT_CONFIG}" ]] || {
    err "Dependabot config not found: ${DEPENDABOT_CONFIG}"
    return 1
  }

  # Check if yq supports the update operation
  if ! command -v yq &>/dev/null; then
    err "yq is required for dependabot.yml updates"
    return 1
  fi

  # Create temporary file with updated config
  local temp_file
  temp_file="$(mktemp)"

  # Build directories array with proper quoting
  local -a dir_paths=()
  for slug in "${slugs[@]}"; do
    dir_paths+=("\"/${slug}\"")
  done

  # Join paths with comma for yq expression
  local dirs_string
  dirs_string="$(IFS=,; echo "${dir_paths[*]}")"

  # Update the docker ecosystem directories with quoted paths
  yq eval \
    "(.updates[] | select(.[\"package-ecosystem\"] == \"docker\") | .directories) = [${dirs_string}]" \
    "${DEPENDABOT_CONFIG}" > "${temp_file}"

  # Post-process: add quotes around directory paths
  sed -i 's/^- \(\/\)/- "\1/g' "${temp_file}"
  sed -i 's/\(^[[:space:]]*\)- \(\/[^"]*\)$/\1- "\2"/g' "${temp_file}"

  # Verify the update is valid YAML
  if ! yq eval . "${temp_file}" >/dev/null 2>&1; then
    err "Generated invalid YAML for dependabot config"
    rm -f "${temp_file}"
    return 1
  fi

  # Replace original file (mv removes the temp file)
  mv "${temp_file}" "${DEPENDABOT_CONFIG}"
  echo "Updated ${DEPENDABOT_CONFIG} with ${#slugs[@]} addon directories" >&2
}

#######################################
# Update workflow_dispatch boolean inputs in addon-build.yaml
# Globals:
#   DEPLOYER_V3_WORKFLOW
# Arguments:
#   slugs - Array of addon slugs (one per line via stdin)
# Returns:
#   0 on success, 1 on error
#######################################
update_workflow_dispatch_v3() {
  local -a slugs
  readarray -t slugs

  [[ "${#slugs[@]}" -gt 0 ]] || {
    err "No addon slugs found for addon-build workflow update"
    return 1
  }

  [[ -f "${DEPLOYER_V3_WORKFLOW}" ]] || {
    err "Addon build workflow not found: ${DEPLOYER_V3_WORKFLOW}"
    return 1
  }

  # Check if yq is available
  if ! command -v yq &>/dev/null; then
    err "yq is required for addon-build workflow updates"
    return 1
  fi

  # Sort slugs alphabetically for consistent output
  local sorted_slugs
  sorted_slugs="$(printf '%s\n' "${slugs[@]}" | sort)"
  mapfile -t slugs <<< "${sorted_slugs}"

  local updated_yaml
  updated_yaml="$(mktemp)"

  # Clear existing workflow_dispatch inputs first
  yq eval '.on.workflow_dispatch.inputs = {}' "${DEPLOYER_V3_WORKFLOW}" > "${updated_yaml}"

  # Add each slug as a boolean input with checkbox emoji
  for slug in "${slugs[@]}"; do
    local next_temp
    next_temp="$(mktemp)"

    # Build input block with description (including checkbox emoji), type, and default
    yq eval \
      ".on.workflow_dispatch.inputs.${slug} = {\"description\": \"☑️ Release ${slug}\", \"type\": \"boolean\", \"default\": false}" \
      "${updated_yaml}" > "${next_temp}"

    rm -f "${updated_yaml}"
    updated_yaml="${next_temp}"
  done

  # Verify the update is valid YAML
  if ! yq eval . "${updated_yaml}" >/dev/null 2>&1; then
    err "Generated invalid YAML for addon-build workflow file"
    rm -f "${updated_yaml}"
    return 1
  fi

  # Replace original file
  mv "${updated_yaml}" "${DEPLOYER_V3_WORKFLOW}"
  echo "Updated ${DEPLOYER_V3_WORKFLOW} with ${#slugs[@]} boolean inputs" >&2
}

#######################################
# Update .release-please-manifest.json with addon packages
# Preserves existing version numbers, adds new packages
# Globals:
#   RELEASE_PLEASE_MANIFEST
# Arguments:
#   slugs - Array of addon slugs (one per line via stdin)
# Returns:
#   0 on success, 1 on error
#######################################
update_release_please_manifest() {
  local -a slugs
  readarray -t slugs

  [[ "${#slugs[@]}" -gt 0 ]] || {
    err "No addon slugs found for release-please manifest update"
    return 1
  }

  local temp_file
  temp_file="$(mktemp)"

  # Create new manifest or update existing one
  if [[ -f "${RELEASE_PLEASE_MANIFEST}" ]]; then
    # Read existing manifest to preserve versions
    cp "${RELEASE_PLEASE_MANIFEST}" "${temp_file}"
  else
    # Create new empty manifest
    echo "{}" > "${temp_file}"
  fi

  # Add each slug as a package (preserve existing version, default to 0.1.0 for new)
  for slug in "${slugs[@]}"; do
    local current_version
    current_version="$(jq -r ".[\"${slug}\"] // \"0.1.0\"" "${temp_file}")"

    # Update the manifest entry
    local next_temp
    next_temp="$(mktemp)"
    jq ".[\"${slug}\"] = \"${current_version}\"" "${temp_file}" > "${next_temp}"
    rm -f "${temp_file}"
    temp_file="${next_temp}"
  done

  # Verify the output is valid JSON
  if ! jq . "${temp_file}" >/dev/null 2>&1; then
    err "Generated invalid JSON for release-please manifest"
    rm -f "${temp_file}"
    return 1
  fi

  # Replace original file
  mv "${temp_file}" "${RELEASE_PLEASE_MANIFEST}"
  echo "Updated ${RELEASE_PLEASE_MANIFEST} with ${#slugs[@]} packages" >&2
}

#######################################
# Main script logic
# Globals:
#   UPDATE_DEPENDABOT
#   UPDATE_WORKFLOW_DISPATCH
#   UPDATE_RELEASE_PLEASE
#   GENERATE_README
# Arguments:
#   All script arguments
# Returns:
#   0 on success, non-zero on error
#######################################
main() {
  parse_args "$@"

  # Generate manifest and capture slugs
  local slugs_output
  slugs_output="$(generate_manifest)"

  # Update dependabot if requested
  if [[ "${UPDATE_DEPENDABOT}" == "true" ]]; then
    update_dependabot <<< "${slugs_output}"
  fi

  # Update workflow_dispatch if requested (addon-build.yaml)
  if [[ "${UPDATE_WORKFLOW_DISPATCH}" == "true" ]]; then
    if [[ -f "${DEPLOYER_V3_WORKFLOW}" ]]; then
      update_workflow_dispatch_v3 <<< "${slugs_output}"
    fi
  fi

  # Update release-please manifest if requested
  if [[ "${UPDATE_RELEASE_PLEASE}" == "true" ]]; then
    update_release_please_manifest <<< "${slugs_output}"
  fi

  # Generate README files if requested
  if [[ "${GENERATE_README}" == "true" ]]; then
    # Check gomplate is available
    if ! check_gomplate; then
      exit 1
    fi

    # Generate root README
    if ! generate_root_readme; then
      exit 1
    fi

    # Generate addon READMEs (all addons by default)
    # shellcheck disable=SC2119
    if ! generate_addon_readmes; then
      exit 1
    fi
  fi
}

main "$@"
