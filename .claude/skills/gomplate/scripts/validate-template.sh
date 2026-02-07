#!/bin/bash
# Validate gomplate template syntax
# Usage: ./validate-template.sh template.tmpl

set -euo pipefail

TEMPLATE_FILE="${1:-}"

if [[ -z "$TEMPLATE_FILE" ]]; then
  echo "Usage: $0 <template-file>" >&2
  echo "" >&2
  echo "Validates gomplate template syntax without rendering." >&2
  exit 1
fi

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "Error: Template file not found: $TEMPLATE_FILE" >&2
  exit 1
fi

echo "Validating template: $TEMPLATE_FILE"

# Try to render with minimal context to check syntax
# Use --missing-key=zero to avoid errors from missing datasources
if gomplate --missing-key=zero -f "$TEMPLATE_FILE" -o /dev/null 2>&1; then
  echo "✓ Template syntax is valid"
  exit 0
else
  echo "✗ Template syntax has errors" >&2
  exit 1
fi
