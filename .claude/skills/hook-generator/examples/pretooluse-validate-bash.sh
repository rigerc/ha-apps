#!/bin/bash
set -e

################################################################################
# Hook: PreToolUse Bash Validation
# Purpose: Validate Bash commands before execution
# Event: PreToolUse
################################################################################

# Read JSON input from stdin
INPUT=$(cat)

# Extract fields
TOOL_NAME=$(echo "$INPUT" | grep -o '"tool_name":"[^"]*"' | cut -d'"' -f4 || echo "")
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

################################################################################
# SECURITY VALIDATION
################################################################################

# Function to validate command safety
validate_command() {
  local cmd="$1"

  # Exit if no command to validate
  if [[ -z "$cmd" ]]; then
    return 0
  fi

  # Block command injection patterns
  if [[ "$cmd" == *';'* ]] || [[ "$cmd" == *'|'* ]] || [[ "$cmd" == *'&&'* ]]; then
    echo "SECURITY: Command injection detected" >&2
    return 1
  fi

  # Block dangerous commands
  local dangerous="rm -rf|rm -f|mkfs|dd if=|chmod -f|chmod -R"
  if [[ "$cmd" =~ $dangerous ]]; then
    echo "BLOCKED: Dangerous command: $cmd" >&2
    return 1
  fi

  return 0
}

################################################################################
# MAIN LOGIC
################################################################################

# Only validate Bash tool calls
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0  # Not Bash, allow
fi

# Validate the command
if ! validate_command "$COMMAND"; then
  exit 2  # Block operation
fi

# Warn about suspicious but not blocked patterns
if [[ "$COMMAND" == *"curl"* ]] && [[ "$COMMAND" != *"&>"* ]]; then
  echo "WARNING: curl without output redirection" >&2
fi

exit 0  # Allow operation
