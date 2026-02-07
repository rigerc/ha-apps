#!/bin/bash
# Validate gomplate templates with sample data

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
readonly PROJECT_ROOT

# Sample data for testing
SAMPLE_MANIFEST='[
  {
    "slug": "test-addon",
    "version": "1.0.0",
    "name": "Test Addon",
    "description": "Test description",
    "arch": ["amd64", "aarch64"],
    "image": "test/image",
    "tag": "latest",
    "project": "https://github.com/test/project",
    "has_icon": true
  }
]'

# Create temporary manifest with .json extension so gomplate auto-parses it
temp_manifest=$(mktemp --suffix=.json)
echo "${SAMPLE_MANIFEST}" > "${temp_manifest}"

echo "Validating root README template..."
if REPOSITORY="test/repo" \
   REPOSITORY_URL="https://github.com/test/repo" \
   AUTHOR_NAME="test" \
   gomplate \
     --datasource addons="${temp_manifest}" \
     --file="${PROJECT_ROOT}/.github/templates/.README.tmpl" \
     --out=/dev/null; then
  echo "✓ Root README template is valid"
else
  echo "✗ Root README template has errors"
  rm -f "${temp_manifest}"
  exit 1
fi

echo "Validating addon README template..."

# Create test translations file
temp_translations_dir=$(mktemp -d)
mkdir -p "${temp_translations_dir}/test-addon/translations"
cat > "${temp_translations_dir}/test-addon/translations/en.yaml" <<'TRANS_EOF'
---
configuration:
  test_option:
    name: "Test Option"
    description: "This is a test configuration option."
TRANS_EOF

# Change to temp directory for file.Exists to work correctly
cd "${temp_translations_dir}"

if REPOSITORY="test/repo" \
   REPOSITORY_URL="https://github.com/test/repo" \
   ADDON_SLUG="test-addon" \
   gomplate \
     --datasource addons="${temp_manifest}" \
     --file="${PROJECT_ROOT}/.github/templates/.README_ADDON.tmpl" \
     --out=/dev/null; then
  echo "✓ Addon README template is valid"
else
  echo "✗ Addon README template has errors"
  rm -f "${temp_manifest}"
  rm -rf "${temp_translations_dir}"
  exit 1
fi

# Clean up
cd "${PROJECT_ROOT}"
rm -f "${temp_manifest}"
rm -rf "${temp_translations_dir}"
echo "All templates validated successfully!"
