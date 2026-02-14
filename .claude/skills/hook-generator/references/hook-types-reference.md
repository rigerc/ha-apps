# Hook Types Reference

Complete specifications for all 9 hook event types, including input/output fields, matcher behaviors, and use cases.

## Event Type Categories

### Tool-Based Events

These events relate to tool usage and require matchers to specify which tools trigger the hook.

#### PreToolUse

**Purpose:** Block or modify tool calls before execution

**Input Fields:**
- `tool_name`: Name of the tool being called
- `tool_input`: Object containing the tool's parameters
- `session_id`: Current session identifier
- `cwd`: Current working directory

**Use Cases:**
- Security validation before dangerous operations
- Input sanitization and validation
- Permission enforcement
- Rate limiting or quota checking
- Command safety checks

**Blocking Behavior:** Exit code 2 blocks the tool call from executing

**Matcher Required:** Yes

**Example Matcher:** `"Bash"`, `"Write|Edit"`, `"mcp__.*__.*"`

---

#### PostToolUse

**Purpose:** Process results after tool completion

**Input Fields:**
- `tool_name`: Name of the tool that was called
- `tool_input`: Object containing the tool's parameters
- `tool_response`: The tool's response/output
- `session_id`: Current session identifier
- `cwd`: Current working directory

**Use Cases:**
- Audit logging of tool usage
- Automatic formatting after file writes
- Result validation or transformation
- Notification on specific operations
- Compliance tracking

**Blocking Behavior:** Cannot block (operation already completed)

**Matcher Required:** Yes

**Example Matcher:** `"Write"`, `"Bash|Write|Edit"`, `"Read"`

---

#### PermissionRequest

**Purpose:** Allow or deny permission dialogs

**Input Fields:**
- `permission_type`: Type of permission requested
- `permission_details`: Details about what's being requested
- `session_id`: Current session identifier

**Use Cases:**
- Context-aware permission decisions
- Automatic approval for safe operations
- Policy-based permission enforcement
- Permission audit logging

**Blocking Behavior:** Exit code 2 denies the permission request

**Matcher Required:** No (event-specific)

---

### Lifecycle Events

These events relate to session lifecycle and have special behaviors.

#### SessionStart

**Purpose:** Initialize environment at session start

**Input Fields:**
- `session_id`: Current session identifier
- `cwd`: Current working directory
- `CLAUDE_ENV_FILE`: Path to environment persistence file (unique to SessionStart)

**Use Cases:**
- Environment setup and validation
- Dependency checking
- Configuration loading
- Initial status display
- Environment variable initialization

**Matcher Support:** Optional (startup/resume/clear/compact)

**Matcher Types:**
- `"startup"`: Session starting fresh
- `"resume"`: Session resuming from previous
- `"clear"`: Context was cleared before start
- `"compact"`: Context was compacted before start

**Special Variable:** `$CLAUDE_ENV_FILE` for environment persistence

---

#### SessionEnd

**Purpose:** Cleanup at session termination

**Input Fields:**
- `session_id`: Current session identifier
- `cwd`: Current working directory

**Use Cases:**
- Environment cleanup
- Session summary generation
- Final audit reports
- Resource release
- State persistence

**Matcher Support:** No

**Note:** Fires when session ends normally or abnormally

---

### Agent Events

These events relate to agent execution flow.

#### Stop

**Purpose:** Decide whether to continue after agent response

**Input Fields:**
- `session_id`: Current session identifier
- `cwd`: Current working directory
- `hook_event_name`: Always "Stop"

**Use Cases:**
- Task completion detection
- Automatic continuation decision
- Workflow progression control
- Stop-loop prevention

**Blocking Behavior:** Exit code 2 causes Claude to continue working

**Matcher Support:** No

**Note:** Very high frequency event - careful with expensive operations

---

#### SubagentStop

**Purpose:** Control continuation after subagent tasks

**Input Fields:**
- `session_id`: Current session identifier
- `cwd`: Current working directory
- `agent_id`: ID of the subagent that stopped
- `agent_response`: Response from the subagent

**Use Cases:**
- Subagent task completion validation
- Multi-agent workflow coordination
- Subagent result verification

**Blocking Behavior:** Exit code 2 continues to next subagent or returns

**Matcher Support:** No

---

### Context Events

These events relate to context management and user interaction.

#### UserPromptSubmit

**Purpose:** Validate or inject context before processing prompts

**Input Fields:**
- `prompt`: The user's submitted prompt text
- `session_id`: Current session identifier
- `cwd`: Current working directory

**Use Cases:**
- Prompt validation and sanitization
- Automatic context injection
- Prompt enrichment
- Security policy enforcement
- Prompt audit logging

**Blocking Behavior:** Exit code 2 prevents prompt from being processed

**Matcher Support:** No

---

#### Notification

**Purpose:** Respond to permission requests or waiting messages

**Input Fields:**
- `notification_type`: Type of notification
- `notification_details`: Details about the notification
- `session_id`: Current session identifier

**Use Cases:**
- Automatic handling of idle prompts
- Auth success handling
- Custom notification responses

**Matcher Support:** Optional (permission_prompt/idle_prompt/auth_success/elicitation_dialog)

---

#### PreCompact

**Purpose:** Prepare for context compaction

**Input Fields:**
- `session_id`: Current session identifier
- `cwd`: Current working directory
- `current_token_count`: Current context token count
- `target_token_count`: Target token count after compaction

**Use Cases:**
- Custom compaction strategies
- Priority marking for content
- Compaction preparation

**Matcher Support:** No

---

## Matcher Reference

### Tool Matchers

For tool-based events (PreToolUse, PostToolUse, PermissionRequest):

**Simple Matcher:**
```json
{"matcher": "Bash"}
```

**Multiple Tools:**
```json
{"matcher": "Bash|Write|Edit"}
```

**MCP Server Tools:**
```json
{"matcher": "mcp__server-name__.*"}
```

**Specific MCP Tool:**
```json
{"matcher": "mcp__server-name__tool-name"}
```

**Regex Pattern:**
```json
{"matcher": "mcp__.*__write.*"}
```

**Wildcard:**
```json
{"matcher": "*"}
```

**Note:** Wildcard matches everything - use with caution

---

## Response Schema by Event Type

### PreToolUse Response

```json
{
  "continue": true,
  "suppressOutput": false,
  "systemMessage": "Optional message to user",
  "additionalContext": {
    "key": "value"
  }
}
```

### PostToolUse Response

Cannot block - only logging/side effects

### Stop/SubagentStop Response

```json
{
  "continue": false,
  "stopReason": "Message shown to user"
}
```

### UserPromptSubmit Response

```json
{
  "continue": false,
  "suppressOriginalPrompt": true,
  "injectPrompts": ["Additional context to add"]
}
```

---

## Quick Selection Guide

**Need to block operations?** → PreToolUse

**Need to log/audit?** → PostToolUse

**Need to validate user input?** → UserPromptSubmit

**Need to auto-continue?** → Stop

**Need setup/teardown?** → SessionStart/SessionEnd

**Need context-aware decisions?** → Consider prompt-based hooks

**Need subagent coordination?** → SubagentStop
