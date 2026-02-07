#!/bin/bash
# Test gomplate template with sample data
# Usage: ./test-template.sh template.tmpl [sample-data.json]

set -euo pipefail

TEMPLATE_FILE="${1:-}"
DATA_FILE="${2:-}"

if [[ -z "$TEMPLATE_FILE" ]]; then
  echo "Usage: $0 <template-file> [data-file]" >&2
  echo "" >&2
  echo "Test gomplate template rendering with optional sample data." >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  $0 template.tmpl" >&2
  echo "  $0 template.tmpl sample-data.json" >&2
  echo "  $0 template.tmpl sample-data.yaml" >&2
  exit 1
fi

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "Error: Template file not found: $TEMPLATE_FILE" >&2
  exit 1
fi

if [[ -n "$DATA_FILE" && ! -f "$DATA_FILE" ]]; then
  echo "Error: Data file not found: $DATA_FILE" >&2
  exit 1
fi

echo "Testing template: $TEMPLATE_FILE"

if [[ -n "$DATA_FILE" ]]; then
  echo "Using data file: $DATA_FILE"
  echo "---"
  gomplate -d config="$DATA_FILE" -f "$TEMPLATE_FILE"
else
  echo "Using environment variables only"
  echo "---"
  gomplate -f "$TEMPLATE_FILE"
fi

echo "---"
echo "✓ Template rendered successfully"
