#!/bin/bash
#
# Generate manifest.json for Home Assistant addons
#
# This script scans addon directories for config.yaml, build.yaml, and Dockerfile
# files to generate a manifest.json file. Can also generate README.md files using gomplate.

set -euo pipefail

# Constants
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
readonly PROJECT_ROOT
readonly MANIFEST_OUTPUT="${PROJECT_ROOT}/manifest.json"

# Options
GENERATE_README=false
UPDATE_DEPENDABOT=false
UPDATE_RELEASE_PLEASE=false
UPDATE_CI_WORKFLOW=false

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
# Get latest release tag from current repo matching {slug}-*
# Globals:
#   None
# Arguments:
#   slug - Add-on slug to match in tag pattern (e.g., "romm")
# Returns:
#   Latest matching tag name, or empty string if none found
#######################################
get_latest_release_for_slug() {
  local slug="$1"
  local owner_repo=""

  # Get current repository info from git remote
  owner_repo="$(get_repo_info)"

  # Validate we got owner/repo format
  if [[ ! "${owner_repo}" =~ ^[^/]+/[^/]+$ ]]; then
    echo ""
    return 1
  fi

  # Query GitHub Releases API for all releases, get latest tag matching {slug}-*
  # Sort by published_at date descending and take the first match
  local latest_tag
  latest_tag="$(curl -s "https://api.github.com/repos/${owner_repo}/releases?per_page=100" \
    | jq -r --arg slug "${slug}" '[.[] | select(.tag_name | startswith($slug + "-"))] | sort_by(.published_at) | reverse | .[0].tag_name // ""' 2>/dev/null || echo "")"

  echo "${latest_tag}"
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
# Check if jq is installed
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   0 if jq is available, 1 otherwise
#######################################
check_jq() {
  if ! command -v jq &>/dev/null; then
    err "Error: jq is required but not installed"
    err "Install from: https://github.com/stedolan/jq"
    return 1
  fi
  return 0
}

#######################################
# Check if yq is installed
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   0 if yq is available, 1 otherwise
#######################################
check_yq() {
  if ! command -v yq &>/dev/null; then
    err "Error: yq is required but not installed"
    err "Install from: https://github.com/mikefarah/yq"
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
         --template partials="${PROJECT_ROOT}/.github/templates/partials" \
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
           --template partials="${PROJECT_ROOT}/.github/templates/partials" \
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
  -g, --generate-readme         Generate README.md files using gomplate templates
  -d, --update-dependabot       Update .github/dependabot.yml with all found slugs
  -r, --update-release-please   Update .github/workflows/release-please.yaml and release-please-config.json
  -c, --update-ci               Update .github/workflows/ci.yaml with all found slugs
  -h, --help                    Display this help message

EXAMPLES:
  $(basename "${BASH_SOURCE[0]}")                      # Generate manifest.json only
  $(basename "${BASH_SOURCE[0]}") -g                  # Generate manifest.json and README files
  $(basename "${BASH_SOURCE[0]}") -d                  # Generate manifest.json and update dependabot.yml
  $(basename "${BASH_SOURCE[0]}") -r                  # Generate manifest.json and update release-please configs
  $(basename "${BASH_SOURCE[0]}") -c                  # Generate manifest.json and update ci.yaml
  $(basename "${BASH_SOURCE[0]}") -d -r -c            # Update dependabot.yml, release-please configs, and ci.yaml

EOF
}

#######################################
# Parse command line arguments
# Globals:
#   GENERATE_README
#   UPDATE_DEPENDABOT
#   UPDATE_RELEASE_PLEASE
#   UPDATE_CI_WORKFLOW
# Arguments:
#   All script arguments
# Returns:
#   None
#######################################
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -g|--generate-readme)
        GENERATE_README=true
        shift
        ;;
      -d|--update-dependabot)
        UPDATE_DEPENDABOT=true
        shift
        ;;
      -r|--update-release-please)
        UPDATE_RELEASE_PLEASE=true
        shift
        ;;
      -c|--update-ci)
        UPDATE_CI_WORKFLOW=true
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
  local upstream_image
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

  # Build packages array from config.yaml image template (e.g., "ghcr.io/rigerc/ha-apps-huntarr-{arch}")
  image_template="$(yq -r '.image // ""' "${config_file}")"
  image_template="${image_template#ghcr.io/rigerc/}"
  packages="[]"
  if [[ -n "${image_template}" && "${image_template}" == *"{arch}"* ]]; then
    while IFS= read -r arch_val; do
      package_name="${image_template//\{arch\}/${arch_val}}"
      packages="$(jq --arg pkg "${package_name}" '. + [$pkg]' <<< "${packages}")"
    done < <(echo "${architectures}" | jq -r '.[]')
  fi

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
  upstream_image="${image_tag%%:*}"
  tag="${image_tag#*:}"

  # Get latest version from registry and compare
  latest_upstream_tag=""
  is_up_to_date="null"

  if [[ -n "${upstream_image}" && -n "${tag}" ]]; then
    echo "Checking latest version for ${upstream_image}..." >&2
    latest_upstream_tag="$(get_latest_version "${upstream_image}" "${project}")"

    if [[ -n "${latest_upstream_tag}" ]]; then
      # Remove 'v' prefix if present for comparison
      current_clean="${tag#v}"
      latest_clean="${latest_upstream_tag#v}"

      # Use version-aware sort for comparison
      highest_version=$(printf '%s\n' "${current_clean}" "${latest_clean}" | sort -V | tail -n 1)

      if [[ "${current_clean}" == "${latest_clean}" ]]; then
        is_up_to_date="true"
      elif [[ "${current_clean}" == "${highest_version}" ]]; then
        # Current version is newer than latest_upstream_tag
        is_up_to_date="true"
      else
        is_up_to_date="false"
      fi
      echo "  Current: ${tag}, Latest: ${latest_upstream_tag}, Up to date: ${is_up_to_date}" >&2
    else
      echo "  Could not fetch latest version from registry" >&2
    fi
  fi

  # Check if add-on has a public release on GitHub (tag matching {slug}-*)
  last_release=""
  echo "Checking for public releases with tag '${slug}-*'..." >&2
  last_release="$(get_latest_release_for_slug "${slug}")"
  if [[ -n "${last_release}" ]]; then
    echo "  Last release: ${last_release}" >&2
  else
    echo "  No public release found" >&2
  fi

  # Output JSON object for this addon
  jq -n \
    --arg slug "${slug}" \
    --arg version "${version}" \
    --arg name "${name}" \
    --arg description "${description}" \
    --argjson architectures "${architectures}" \
    --arg upstream_image "${upstream_image}" \
    --arg tag "${tag}" \
    --arg latest_upstream_tag "${latest_upstream_tag}" \
    --arg project "${project}" \
    --argjson has_icon "${has_icon}" \
    --argjson ingress "${ingress}" \
    --argjson is_up_to_date "${is_up_to_date}" \
    --arg last_release "${last_release}" \
    --argjson packages "${packages}" \
    '{
      slug: $slug,
      version: $version,
      name: $name,
      description: $description,
      arch: $architectures,
      upstream_image: $upstream_image,
      tag: $tag,
      latest_upstream_tag: $latest_upstream_tag,
      project: $project,
      has_icon: $has_icon,
      ingress: $ingress,
      is_up_to_date: $is_up_to_date,
      last_release: $last_release,
      packages: $packages
    }'
}

#######################################
# Update dependabot.yml with all found slugs
# Globals:
#   PROJECT_ROOT
#   MANIFEST_OUTPUT
# Arguments:
#   None
# Returns:
#   0 on success, 1 on error
#######################################
update_dependabot() {
  local dependabot_file="${PROJECT_ROOT}/.github/dependabot.yml"

  # Check dependabot.yml exists
  if [[ ! -f "${dependabot_file}" ]]; then
    err "Error: dependabot.yml not found: ${dependabot_file}"
    return 1
  fi

  # Check manifest exists
  if [[ ! -f "${MANIFEST_OUTPUT}" ]]; then
    err "Error: manifest.json not found. Generate it first."
    return 1
  fi

  # Check yq is available
  check_yq || return 1

  # Extract all slugs from manifest and format as "/slug"
  local -a directories=()
  while IFS= read -r slug; do
    directories+=("/${slug}")
  done < <(jq -r '.[].slug' "${MANIFEST_OUTPUT}")

  if [[ ${#directories[@]} -eq 0 ]]; then
    err "Error: No slugs found in manifest"
    return 1
  fi

  echo "Updating dependabot.yml with ${#directories[@]} directories..." >&2

  # Build the directories array as JSON for yq
  local dirs_json="["
  local first=true
  for dir in "${directories[@]}"; do
    if [[ "${first}" == "true" ]]; then
      dirs_json+="\"${dir}\""
      first=false
    else
      dirs_json+=", \"${dir}\""
    fi
  done
  dirs_json+="]"

  # Apply the update using yq with double-quoted style
  # The | .updates[0].directories[] style="double" forces quoted output
  if ! yq eval ".updates[0].directories = ${dirs_json} | .updates[0].directories[] style=\"double\"" -i "${dependabot_file}"; then
    err "Error: Failed to update dependabot.yml"
    return 1
  fi

  echo "Updated ${dependabot_file}" >&2
  return 0
}

#######################################
# Update release-please.yaml with all found slugs
# Globals:
#   PROJECT_ROOT
#   MANIFEST_OUTPUT
# Arguments:
#   None
# Returns:
#   0 on success, 1 on error
#######################################
update_release_please() {
  local release_please_file="${PROJECT_ROOT}/.github/workflows/release-please.yaml"

  # Check release-please.yaml exists
  if [[ ! -f "${release_please_file}" ]]; then
    err "Error: release-please.yaml not found: ${release_please_file}"
    return 1
  fi

  # Check manifest exists
  if [[ ! -f "${MANIFEST_OUTPUT}" ]]; then
    err "Error: manifest.json not found. Generate it first."
    return 1
  fi

  # Check yq is available
  check_yq || return 1

  # Extract all slugs from manifest and format as "slug/**"
  local -a paths=()
  while IFS= read -r slug; do
    paths+=("${slug}/**")
  done < <(jq -r '.[].slug' "${MANIFEST_OUTPUT}")

  if [[ ${#paths[@]} -eq 0 ]]; then
    err "Error: No slugs found in manifest"
    return 1
  fi

  echo "Updating release-please.yaml with ${#paths[@]} addon paths..." >&2

  # Build the paths array as JSON for yq, sorted alphabetically
  local paths_json="["
  local first=true
  while IFS= read -r path; do
    if [[ "${first}" == "true" ]]; then
      paths_json+="\"${path}\""
      first=false
    else
      paths_json+=", \"${path}\""
    fi
  done < <(printf '%s\n' "${paths[@]}" | sort)
  paths_json+="]"

  # Append the release-please-config.json path
  paths_json="${paths_json%]}"
  paths_json+=", \".github/release-please-config.json\"]"

  # Apply the update using yq with double-quoted style
  # Need to use .\"on\" because 'on' is a reserved keyword in yq
  if ! yq eval ".\"on\".push.paths = ${paths_json} | .\"on\".push.paths[] style=\"double\"" -i "${release_please_file}"; then
    err "Error: Failed to update release-please.yaml"
    return 1
  fi

  echo "Updated ${release_please_file}" >&2

  update_release_please_config
  update_release_please_manifest
}

#######################################
# Update .release-please-manifest.json with all add-on slugs and versions
# Globals:
#   PROJECT_ROOT
#   MANIFEST_OUTPUT
# Arguments:
#   None
# Returns:
#   0 on success, 1 on error
#######################################
update_release_please_manifest() {
  local manifest_file="${PROJECT_ROOT}/.github/.release-please-manifest.json"

  if [[ ! -f "${MANIFEST_OUTPUT}" ]]; then
    err "Error: manifest.json not found. Generate it first."
    return 1
  fi

  check_jq || return 1

  echo "Updating .release-please-manifest.json..." >&2

  # Build new manifest from addon slugs and versions
  local new_manifest="{}"
  local slug
  local version

  while IFS= read -r addon; do
    slug="$(echo "${addon}" | jq -r '.slug')"
    version="$(echo "${addon}" | jq -r '.version')"
    new_manifest="$(echo "${new_manifest}" | jq --arg slug "${slug}" --arg version "${version}" '. + {($slug): $version}')"
  done < <(jq -c '.[]' "${MANIFEST_OUTPUT}")

  # Write to file with proper formatting
  echo "${new_manifest}" | jq '.' > "${manifest_file}"

  echo "Updated ${manifest_file}" >&2
  return 0
}

#######################################
# Update release-please-config.json with all found add-ons
# Globals:
#   PROJECT_ROOT
#   MANIFEST_OUTPUT
# Arguments:
#   None
# Returns:
#   0 on success, 1 on error
#######################################
update_release_please_config() {
  local config_file="${PROJECT_ROOT}/.github/release-please-config.json"

  if [[ ! -f "${config_file}" ]]; then
    err "Error: release-please-config.json not found: ${config_file}"
    return 1
  fi

  if [[ ! -f "${MANIFEST_OUTPUT}" ]]; then
    err "Error: manifest.json not found. Generate it first."
    return 1
  fi

  check_jq || return 1

  echo "Updating release-please-config.json packages..." >&2

  local config
  config="$(cat "${config_file}")"

  local new_packages="{}"
  local slug
  local name
  local package_entry

  while IFS= read -r addon; do
    slug="$(echo "${addon}" | jq -r '.slug')"
    name="$(echo "${addon}" | jq -r '.name')"

    package_entry="$(jq -n \
      --arg name "${name}" \
      --arg slug "${slug}" \
      '{
        "release-type": "simple",
        "package-name": $name,
        "component": $slug,
        "changelog-path": "CHANGELOG.md",
        "exclude-paths": ["README.md"],
        "extra-files": [
          {
            "type": "yaml",
            "path": "config.yaml",
            "jsonpath": "$.version"
          },
          {
            "type": "yaml",
            "path": "build.yaml",
            "jsonpath": "$.labels['\''org.opencontainers.image.version'\'']"
          }
        ]
      }')"

    new_packages="$(echo "${new_packages}" | jq --arg slug "${slug}" --argjson entry "${package_entry}" '. + {($slug): $entry}')"
  done < <(jq -c '.[]' "${MANIFEST_OUTPUT}" | sort -t'"' -k4)

  local updated_config
  updated_config="$(echo "${config}" | jq --argjson packages "${new_packages}" '.packages = $packages')"

  echo "${updated_config}" | jq '.' > "${config_file}"

  echo "Updated ${config_file}" >&2
  return 0
}

#######################################
# Update ci.yaml with all found slugs
# Globals:
#   PROJECT_ROOT
#   MANIFEST_OUTPUT
# Arguments:
#   None
# Returns:
#   0 on success, 1 on error
#######################################
update_ci_workflow() {
  local ci_file="${PROJECT_ROOT}/.github/workflows/ci.yaml"

  # Check ci.yaml exists
  if [[ ! -f "${ci_file}" ]]; then
    err "Error: ci.yaml not found: ${ci_file}"
    return 1
  fi

  # Check manifest exists
  if [[ ! -f "${MANIFEST_OUTPUT}" ]]; then
    err "Error: manifest.json not found. Generate it first."
    return 1
  fi

  # Check yq is available
  check_yq || return 1

  # Extract all slugs from manifest and format as "slug/**"
  local -a paths=()
  while IFS= read -r slug; do
    paths+=("${slug}/**")
  done < <(jq -r '.[].slug' "${MANIFEST_OUTPUT}")

  if [[ ${#paths[@]} -eq 0 ]]; then
    err "Error: No slugs found in manifest"
    return 1
  fi

  echo "Updating ci.yaml with ${#paths[@]} addon paths..." >&2

  # Build the paths array as JSON for yq, sorted alphabetically
  local paths_json="["
  local first=true
  while IFS= read -r path; do
    if [[ "${first}" == "true" ]]; then
      paths_json+="\"${path}\""
      first=false
    else
      paths_json+=", \"${path}\""
    fi
  done < <(printf '%s\n' "${paths[@]}" | sort)
  paths_json+="]"

  # Apply the update using yq with double-quoted style
  # Need to use .\"on\" because 'on' is a reserved keyword in yq
  if ! yq eval ".\"on\".pull_request.paths = ${paths_json} | .\"on\".pull_request.paths[] style=\"double\"" -i "${ci_file}"; then
    err "Error: Failed to update ci.yaml"
    return 1
  fi

  echo "Updated ${ci_file}" >&2
  return 0
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
#######################################
generate_manifest() {
  local manifest="[]"
  local config_file
  local addon_info

  cd "${PROJECT_ROOT}"

  while IFS= read -r config_file; do
    if addon_info="$(extract_addon_info "${config_file}" 2>/dev/null)"; then
      manifest="$(jq --argjson addon "${addon_info}" '. + [$addon]' <<< "${manifest}")"
    fi
  done < <(find . -mindepth 2 -maxdepth 2 -type f \( -name "config.yaml" -o -name "config.yml" \) | sort)

  # Write manifest atomically
  echo "${manifest}" | jq '.' > "${MANIFEST_OUTPUT}"
  echo "Generated ${MANIFEST_OUTPUT}" >&2
}

#######################################
# Main script logic
# Globals:
#   GENERATE_README
#   UPDATE_DEPENDABOT
#   UPDATE_RELEASE_PLEASE
#   UPDATE_CI_WORKFLOW
# Arguments:
#   All script arguments
# Returns:
#   0 on success, non-zero on error
#######################################
main() {
  parse_args "$@"

  # Generate manifest
  generate_manifest

  # Update dependabot.yml if requested
  if [[ "${UPDATE_DEPENDABOT}" == "true" ]]; then
    if ! update_dependabot; then
      exit 1
    fi
  fi

  # Update release-please.yaml if requested
  if [[ "${UPDATE_RELEASE_PLEASE}" == "true" ]]; then
    if ! update_release_please; then
      exit 1
    fi
  fi

  # Update ci.yaml if requested
  if [[ "${UPDATE_CI_WORKFLOW}" == "true" ]]; then
    if ! update_ci_workflow; then
      exit 1
    fi
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
