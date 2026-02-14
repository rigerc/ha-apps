#!/bin/bash
set -e

################################################################################
# Hook: PostToolUse Write Audit
# Purpose: Audit log all file write operations
# Event: PostToolUse
################################################################################

# Read JSON input from stdin
INPUT=$(cat)

# Extract fields
TOOL_NAME=$(echo "$INPUT" | grep -o '"tool_name":"[^"]*"' | cut -d'"' -f4 || echo "")
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")

################################################################################
# MAIN LOGIC
################################################################################

# Only audit Write/Edit operations
if [[ "$TOOL_NAME" != "Write" ]] && [[ "$TOOL_NAME" != "Edit" ]]; then
  exit 0  # Not a write operation, skip
fi

# Skip if no file path
if [[ -z "$FILE_PATH" ]]; then
  exit 0  # No file path, skip
fi

# Setup audit log
AUDIT_DIR="${CLAUDE_PROJECT_DIR}/.claude/hooks"
AUDIT_LOG="${AUDIT_DIR}/audit-write.log"
mkdir -p "$AUDIT_DIR"

# Log the operation (without sensitive content)
{
  echo "[$(date -Iseconds)] tool=$TOOL_NAME file=$FILE_PATH"
} >> "$AUDIT_LOG"

# Also log to stderr for immediate visibility
echo "[$(date +'%H:%M:%S')] AUDIT: $TOOL_NAME $FILE_PATH" >&2

exit 0  # Success
