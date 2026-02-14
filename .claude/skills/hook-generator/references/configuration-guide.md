# Hook Configuration Guide

Detailed JSON structure, matcher patterns, tool restrictions, timeout configuration, and MCP integration for Claude Code hooks.

## Configuration File Locations

### Personal Hooks

**Location:** `~/.claude/settings.json`

**Scope:** Active across all projects

**Use when:**
- Personal preferences and workflows
- Universal security policies
- Individual development setup

### Project Hooks

**Location:** `.claude/settings.json`

**Scope:** Active only in this project

**Use when:**
- Team-wide standards
- Project-specific validation
- Shared automation workflows

**Best Practice:** Commit project hooks to git for team consistency

### Local Hooks

**Location:** `.claude/settings.local.json`

**Scope:** Active only in this project, not committed

**Use when:**
- Personal overrides in a project
- Local development needs
- Sensitive configuration

**Note:** Add `.claude/settings.local.json` to `.gitignore`

---

## Basic JSON Structure

### Minimal Configuration

```json
{
  "hooks": {
    "EventName": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/hook/script.sh"
          }
        ]
      }
    ]
  }
}
```

### Complete Configuration

```json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "ToolName|OtherTool",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/script.sh",
            "timeout": 60000
          }
        ]
      }
    ]
  }
}
```

---

## Matcher Patterns

### Tool Matchers

For tool-based events: PreToolUse, PostToolUse, PermissionRequest

**Single Tool:**
```json
{"matcher": "Bash"}
```

**Multiple Tools (OR):**
```json
{"matcher": "Bash|Write|Edit"}
```

**All Tools from MCP Server:**
```json
{"matcher": "mcp__server-name__.*"}
```

**Specific MCP Tool:**
```json
{"matcher": "mcp__server-name__tool-name"}
```

**All MCP Tools (any server):**
```json
{"matcher": "mcp__.*__.*"}
```

**Regex Pattern:**
```json
{"matcher": ".*__write.*"}
```
Matches: any tool ending in "write"

**Wildcard (use caution):**
```json
{"matcher": "*"}
```
Matches: every tool (broad!)

---

## Lifecycle Matchers

For SessionStart events only:

**Session Types:**
```json
{"matcher": "startup"}   // Fresh session
{"matcher": "resume"}    // Resuming previous session
{"matcher": "clear"}     // Context was cleared
{"matcher": "compact"}   // Context was compacted
```

**Example - Only on fresh start:**
```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/initial-setup.sh"
          }
        ]
      }
    ]
  }
}
```

---

## Hook Types

### Command Hooks

**Type:** `"command"`

**Execution:** Runs shell command

**Configuration:**
```json
{
  "type": "command",
  "command": "/absolute/path/to/script.sh",
  "timeout": 60000
}
```

**Environment Variables Available:**
- `$CLAUDE_PROJECT_DIR`: Project root path
- `$CLAUDE_ENV_FILE`: Environment file path (SessionStart only)
- `$CLAUDE_CODE_REMOTE`: Remote indicator
- All standard system environment

**Best Practices:**
- Use absolute paths or `$CLAUDE_PROJECT_DIR`
- Make script executable: `chmod +x script.sh`
- Include shebang: `#!/bin/bash`

---

### Prompt Hooks

**Type:** `"prompt"`

**Execution:** Sends context to LLM for evaluation

**Configuration:**
```json
{
  "type": "prompt",
  "prompt": "Evaluate if operation should proceed: $ARGUMENTS",
  "timeout": 30
}
```

**Environment:** No environment variables available

**Supported Events:** Stop, SubagentStop, UserPromptSubmit, PreToolUse, PermissionRequest

**Best Practices:**
- Be explicit in prompt about decision criteria
- Include expected response format
- Set appropriate timeout (15-60 seconds)

---

## Timeout Configuration

### Command Hook Timeouts

**Unit:** Milliseconds

**Default:** 60000 (60 seconds)

**Recommended:**
- Quick validation: 5000-10000 (5-10 seconds)
- File operations: 10000-30000 (10-30 seconds)
- Network operations: 30000-60000 (30-60 seconds)

**Example:**
```json
{
  "type": "command",
  "command": "/path/to/script.sh",
  "timeout": 30000  // 30 seconds
}
```

**Best Practices:**
- Set timeout based on expected operation time
- Don't set excessively high timeouts (>120 seconds)
- Consider performance impact for high-frequency hooks

---

### Prompt Hook Timeouts

**Unit:** Seconds

**Default:** 30

**Recommended:**
- Simple decisions: 15-20 seconds
- Complex evaluation: 30-45 seconds
- Maximum recommended: 60 seconds

**Example:**
```json
{
  "type": "prompt",
  "prompt": "Should we continue?",
  "timeout": 45  // 45 seconds
}
```

**Best Practices:**
- Lower timeout = faster response
- Higher timeout = more complex decisions possible
- Balance between speed and decision quality

---

## Environment Variables

### In Command Hooks

**`$CLAUDE_PROJECT_DIR`**
- Absolute path to project root
- Use for project-relative paths
- Always available in command hooks

**`$CLAUDE_ENV_FILE`**
- Path to environment persistence file
- Only available in SessionStart hooks
- Use for setting environment variables that persist

**`$CLAUDE_CODE_REMOTE`**
- Set if running in remote context
- Empty or not set for local
- Use for remote-specific behavior

**Standard Environment:**
- All standard system variables available
- `PATH`, `HOME`, `USER`, etc.

### In Prompt Hooks

**No environment variables available**

Prompt hooks run in LLM context without shell environment.

---

## Tool Restrictions

### Restricting Hook Tool Access

Hooks can specify which tools they can use:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "audit-log.sh",
            "allowedTools": ["Read", "Grep", "Bash"]
          }
        ]
      }
    ]
  }
}
```

**Benefits:**
- Security: Limit hook capabilities
- Clarity: Document hook requirements
- Safety: Prevent accidental system modifications

**Common Patterns:**
```json
// Read-only audit hook
"allowedTools": ["Read", "Grep"]

// Logging hook
"allowedTools": ["Read", "Bash"]

// Validation hook (no modifications)
"allowedTools": ["Read", "Grep", "Glob"]
```

---

## MCP Integration

### Targeting MCP Tools in Hooks

**All MCP tools from server:**
```json
{"matcher": "mcp__memory__.*"}
```

**Specific MCP tool:**
```json
{"matcher": "mcp__memory__store"}
```

**All write operations across MCP:**
```json
{"matcher": "mcp__.*__write.*"}
```

**Multiple MCP servers:**
```json
{"matcher": "mcp__memory__.*|mcp__cache__.*"}
```

### MCP Hook Patterns

**Pattern 1: MCP Tool Validation**
```json
{
  "PreToolUse": [
    {
      "matcher": "mcp__.*__.*",
      "hooks": [
        {
          "type": "command",
          "command": "validate-mcp-tool.sh"
        }
      ]
    }
  ]
}
```

**Pattern 2: MCP Operation Logging**
```json
{
  "PostToolUse": [
    {
      "matcher": "mcp__database__.*",
      "hooks": [
        {
          "type": "command",
          "command": "log-db-operations.sh"
        }
      ]
    }
  ]
}
```

---

## Advanced Patterns

### Multiple Hooks on Same Event

**All hooks execute in parallel:**
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "audit-write.sh"
          },
          {
            "type": "command",
            "command": "format-write.sh"
          }
        ]
      }
    ]
  }
}
```

### Conditional Hook Execution

**Use script logic to conditionally execute:**
```bash
#!/bin/bash
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path":"[^"]*"' | cut -d'"' -f4)

# Only process certain file types
case "$FILE_PATH" in
  *.py|*.js|*.ts)
    # Run hook logic
    ;;
  *)
    # Skip other files
    exit 0
    ;;
esac
```

### SessionStart Environment Persistence

**Use $CLAUDE_ENV_FILE for persistence:**
```bash
#!/bin/bash
# SessionStart hook

ENV_FILE="${CLAUDE_ENV_FILE}"

# Set initial environment
cat > "$ENV_FILE" << EOF
export HOOK_SESSION_ID="$(uuidgen)"
export HOOK_START_TIME="$(date)"
EOF
```

**Access in subsequent hooks:**
```bash
#!/bin/bash
# Source environment from SessionStart
if [[ -f "${CLAUDE_ENV_FILE}" ]]; then
  source "${CLAUDE_ENV_FILE}"
fi

# Use persisted variables
echo "Session ${HOOK_SESSION_ID} started at ${HOOK_START_TIME}"
```

---

## Configuration Examples

### Example 1: File Write Protection

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/protect-writes.sh",
            "timeout": 5000
          }
        ]
      }
    ]
  }
}
```

### Example 2: Auto-Format After Write

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/auto-format.sh",
            "timeout": 30000,
            "allowedTools": ["Read", "Bash"]
          }
        ]
      }
    ]
  }
}
```

### Example 3: Intelligent Stop Decision

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Should Claude stop? Context: $ARGUMENTS\n\nCheck: tasks complete? errors fixed? user satisfied?\n\nRespond: {\"decision\": \"approve\" (stop) or \"block\" (continue), \"reason\": \"...\"}",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

### Example 4: Multi-Event Setup

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/setup.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/audit.sh"
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/cleanup.sh"
          }
        ]
      }
    ]
  }
}
```

---

## Validation Checklist

Before deploying hook configuration:

**Structure:**
- [ ] Valid JSON syntax
- [ ] Correct event type name
- [ ] Hooks array properly structured

**Matchers:**
- [ ] Matcher present for tool-based events
- [ ] Matcher pattern appropriate for target
- [ ] No overly broad wildcards

**Paths:**
- [ ] Use `$CLAUDE_PROJECT_DIR` for project-relative paths
- [ ] Use absolute paths for external tools
- [ ] No hardcoded user-specific paths

**Timeouts:**
- [ ] Command timeout in milliseconds
- [ ] Prompt timeout in seconds
- [ ] Timeout appropriate for operation

**Tool Access:**
- [ ] `allowedTools` specified if needed
- [ ] Minimal permissions for hook's purpose
