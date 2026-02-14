# Official Hook Response Schema

Complete official Claude Code hook response schema with all fields, advanced structured JSON in additionalContext, field purposes, and migration guide.

## Standard Response Fields

All hooks can return these fields via JSON to stdout:

```json
{
  "continue": true,
  "suppressOutput": false,
  "systemMessage": "Optional message shown to user",
  "additionalContext": {
    "key": "value"
  }
}
```

### Field Definitions

**`continue`** (boolean, default: true)
- `true`: Allow operation to proceed (for blocking hooks, this means don't block)
- `false`: Stop entire Claude execution (only works for specific event types)
- **Use in:** Stop, SubagentStop, UserPromptSubmit

**`suppressOutput`** (boolean, default: false)
- `true`: Hide the original tool response from user
- `false`: Show normal output
- **Use in:** PreToolUse, PostToolUse, Stop, SubagentStop

**`systemMessage`** (string, optional)
- Message shown to user in system notification
- Does not affect operation flow
- **Use in:** All event types

**`additionalContext`** (object, optional)
- Structured data provided to Claude in subsequent turns
- Used for rich, structured communication
- **Use in:** All event types

## Event-Specific Response Behavior

### PreToolUse Response

**Can block:** Yes (exit code 2)

**Response schema affects:**
- Whether tool executes (block)
- What Claude sees from tool (suppressOutput)
- What Claude knows in subsequent turns (additionalContext)

**Example blocking response:**
```bash
#!/bin/bash
# Block Write operations to sensitive files
INPUT=$(cat)
FILE=$(echo "$INPUT" | grep -o '"file_path":"[^"]*"' | cut -d'"' -f4)

if [[ "$FILE" == *".env" ]] || [[ "$FILE" == *"secrets"* ]]; then
  echo "BLOCK: Writing to sensitive file: $FILE" >&2
  exit 2
fi

exit 0
```

**Example with additionalContext:**
```bash
#!/bin/bash
# Provide context to Claude about file operations
INPUT=$(cat)
FILE=$(echo "$INPUT" | grep -o '"file_path":"[^"]*"' | cut -d'"' -f4)

# Respond with structured context
cat << EOF
{
  "systemMessage": "File operation logged",
  "additionalContext": {
    "last_operation": "write",
    "last_file": "$FILE",
    "operation_timestamp": "$(date -Iseconds)"
  }
}
EOF
```

---

### PostToolUse Response

**Can block:** No (operation already complete)

**Response schema affects:**
- What Claude sees from tool (suppressOutput)
- What Claude knows in subsequent turns (additionalContext)
- Cannot stop the operation (already happened)

**Use cases:**
- Transform tool output before Claude sees it
- Add structured metadata for subsequent turns
- Log operations without affecting flow

---

### Stop Response

**Can block:** Yes (exit code 2 means continue)

**Response schema affects:**
- Whether Claude stops (exit code 2 vs 0)
- What user sees (stopReason with continue:false)
- What Claude knows (additionalContext)

**Example - Block (continue working):**
```bash
#!/bin/bash
# Continue if tasks not complete
exit 2  # Block the stop, so Claude continues
```

**Example - Stop with reason:**
```bash
#!/bin/bash
# Stop and show message to user
cat << EOF
{
  "continue": false,
  "stopReason": "All requested tasks completed successfully"
}
EOF
```

---

### UserPromptSubmit Response

**Can block:** Yes (exit code 2)

**Response schema affects:**
- Whether prompt is processed
- Whether original prompt is shown
- Additional prompts to inject

**Example - Inject context:**
```bash
#!/bin/bash
# Add project context to user prompts
cat << EOF
{
  "suppressOriginalPrompt": false,
  "injectPrompts": [
    "Project context: Node.js project with TypeScript",
    "Current task: Implementing user authentication"
  ]
}
EOF
```

**Example - Block harmful prompts:**
```bash
#!/bin/bash
INPUT=$(cat)
PROMPT=$(echo "$INPUT" | grep -o '"prompt":"[^"]*"' | cut -d'"' -f4)

# Block harmful requests
if [[ "$PROMPT" == *"exfiltrate"* ]] || [[ "$PROMPT" == *"credentials"* ]]; then
  exit 2  # Block prompt
fi

exit 0
```

---

## Structured JSON in additionalContext

For complex scenarios, use structured JSON to provide rich context to Claude:

### Example: File Operation Tracking

```json
{
  "additionalContext": {
    "operation": {
      "type": "file_write",
      "path": "/project/src/main.ts",
      "size": 1024,
      "timestamp": "2024-01-15T10:30:00Z"
    },
    "validation": {
      "status": "passed",
      "checks": ["syntax", "style", "security"],
      "warnings": []
    }
  }
}
```

### Example: Security Decision Context

```json
{
  "additionalContext": {
    "security": {
      "decision": "blocked",
      "reason": "Path traversal attempt detected",
      "pattern": "../",
      "severity": "high"
    },
    "remediation": {
      "suggested": "Use project-relative paths only",
      "example": "src/config.json instead of ../../src/config.json"
    }
  }
}
```

### Example: Task Completion State

```json
{
  "additionalContext": {
    "tasks": [
      {"id": "1", "description": "Setup database", "status": "complete"},
      {"id": "2", "description": "Create API endpoints", "status": "complete"},
      {"id": "3", "description": "Write tests", "status": "in_progress"}
    ],
    "completion": 0.67,
    "recommendation": "Continue with test implementation"
  }
}
```

---

## Migration Guide

### Old Format (Implicit)

Before: Hooks used only exit codes
```bash
#!/bin/bash
# Old way - unclear intent
exit 0  # What does 0 mean?
exit 2  # What does 2 mean?
```

### New Format (Explicit)

Now: Hooks can provide structured JSON
```bash
#!/bin/bash
# New way - explicit intent
cat << 'EOF'
{
  "continue": false,
  "stopReason": "Task completed: user confirmed satisfaction",
  "systemMessage": "Session ending"
}
EOF
```

---

## Best Practices

### 1. Use Explicit Messages

**Bad:**
```bash
exit 2  # Why blocked?
```

**Good:**
```bash
cat << 'EOF'
{
  "systemMessage": "Blocked: Write operation to .env file is not allowed"
}
EOF
exit 2
```

### 2. Provide Context for Decisions

**Bad:**
```bash
# Claude doesn't know why
exit 2
```

**Good:**
```bash
cat << 'EOF'
{
  "systemMessage": "Continuing: Test file src/test.spec.ts is failing",
  "additionalContext": {
    "failing_test": "src/test.spec.ts",
    "error_count": 3
  }
}
EOF
exit 2
```

### 3. Use Structured Data for Complex State

**Bad:**
```bash
echo "Tasks: 1 done, 2 in progress, 3 pending" >&2
```

**Good:**
```bash
cat << 'EOF'
{
  "additionalContext": {
    "tasks": {
      "complete": ["setup"],
      "in_progress": ["implementation"],
      "pending": ["testing"]
    }
  }
}
EOF
```

---

## Quick Reference

| Field | Type | Events | Purpose |
|------|------|--------|---------|
| `continue` | boolean | Stop, SubagentStop, UserPromptSubmit | Control flow |
| `suppressOutput` | boolean | PreToolUse, PostToolUse, Stop, SubagentStop | Hide tool response |
| `systemMessage` | string | All | Show message to user |
| `additionalContext` | object | All | Provide structured context |
| `stopReason` | string | Stop, SubagentStop | Message when stopping |
| `suppressOriginalPrompt` | boolean | UserPromptSubmit | Hide original prompt |
| `injectPrompts` | array | UserPromptSubmit | Add context prompts |

---

## Complete Example: Smart Stop Hook

```bash
#!/bin/bash
# Analyze conversation and decide if Claude should stop

INPUT=$(cat)

# Check for completion indicators
COMPLETED=$(echo "$INPUT" | grep -o '"completed":[^}]*' | cut -d']' -f2)
PENDING=$(echo "$INPUT" | grep -o '"pending":[^}]*' | cut -d']' -f2)

# If tasks pending, continue working
if [[ "$PENDING" != *"[]"* ]]; then
  cat << 'EOF'
{
  "systemMessage": "Continuing: Pending tasks remain",
  "additionalContext": {
    "pending_tasks": $PENDING
  }
}
EOF
  exit 2  # Block stop (continue)
fi

# If all complete, stop
cat << 'EOF'
{
  "continue": false,
  "stopReason": "All requested tasks completed"
}
EOF
```
