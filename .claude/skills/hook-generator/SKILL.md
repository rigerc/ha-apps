---
name: hook-generator
description: This skill should be used when the user asks to "create a hook", "generate a hook", "build a new hook", "write a hook script", "make a PreToolUse/PostToolUse hook", or wants to create automated Claude Code hooks for validation, logging, security, or workflow automation.
version: 0.1.0
allowed-tools: Read, Grep, Write, Edit, Bash
---

# Hook Generator for Claude Code

This skill provides a systematic approach to creating high-quality Claude Code hooks by fetching the latest official hook documentation and applying security best practices.

## Purpose

Generate well-structured, production-ready Claude Code hooks that follow official standards, enforce security validation, and use appropriate event types. The skill ensures consistency with the latest Claude Code documentation by fetching it at runtime.

## When to Use This Skill

Use this skill when:
- The user requests creation of a new hook ("create a hook for X")
- Generating validation or security hooks
- Building logging or audit trail hooks
- Creating automated workflow hooks
- The user wants hooks that follow current best practices
- Converting manual workflows into automated hooks

## Core Workflow

### Step 1: Latest Documentation

!`curl -s https://code.claude.com/docs/en/hooks-guide.md`

!`curl -s https://code.claude.com/docs/en/hooks.md`

Read and internalize this documentation to ensure the generated hook follows current best practices, event specifications, and security requirements.

### Step 2: Understand Requirements

Gather concrete details about what the hook should accomplish:

**Essential questions:**
- What event should trigger this hook? (PreToolUse, PostToolUse, Stop, SessionStart, etc.)
- What tools or operations should be matched? (specific tools, all tools, lifecycle events)
- What should the hook do? (validate, transform, log, block, notify)
- Should this be a command hook (bash/python) or prompt-based hook (LLM decision)?
- Are there security considerations? (input validation, sensitive data, command injection)

**Example dialogue:**
```
User: "Create a hook that validates bash commands"

Ask: "What validation rules should apply?
For example:
- Block destructive commands (rm, mv, etc.)
- Warn about dangerous flags
- Check for proper quoting
- Validate against allowlist/denylist

What else should it validate?"
```

Ask focused questions. Do not overwhelm with too many at once.

### Step 3: Plan Hook Type and Structure

Analyze requirements to determine hook implementation strategy:

**Command Hooks (`type: "command"`)** - Use when:
- Deterministic validation logic is needed
- File operations or system commands are required
- Performance is critical (frequent events)
- Simple pattern matching suffices
- Example: security checks, audit logging, file validation

**Prompt Hooks (`type: "prompt"`)** - Use when:
- Context-aware decision-making is needed
- Natural language understanding is required
- Complex evaluation criteria exist
- Example: task completion analysis, semantic prompt validation

**Event Type Selection:**

| Event Type | Purpose | Matcher Required |
|------------|---------|-----------------|
| **PreToolUse** | Block/modify before tool execution | Yes |
| **PostToolUse** | Process results after tool | Yes |
| **UserPromptSubmit** | Validate/inject context before prompts | No |
| **SessionStart** | Initialize environment | Optional (startup/resume/clear/compact) |
| **SessionEnd** | Cleanup on termination | No |
| **Stop** | Decide continuation after agent response | No |
| **SubagentStop** | Decide continuation after subagent | No |
| **PermissionRequest** | Allow/deny permission dialogs | No |
| **Notification** | Respond to idle/auth dialogs | Optional |
| **PreCompact** | Prepare for context compaction | No |

Load `hook-types-reference.md` for detailed specifications on each event type.

### Step 4: Design Hook Behavior

Define the hook's input processing, decision logic, and output requirements:

**Input Processing:**
- What data does hook need from stdin JSON? (tool_name, tool_input, file_path, etc.)
- Which fields are required for the hook's logic?
- How should missing or malformed inputs be handled?

**Decision Logic:**
- What conditions trigger hook actions?
- What validation rules apply?
- What patterns should be detected or blocked?
- Should the hook use allowlists, denylists, or regex patterns?

**Output Requirements:**
- Exit code: 0 (success/allow), 2 (block), other (non-blocking error)
- For blocking hooks: Use official response schema with continue, suppressOutput, systemMessage
- For logging hooks: Structure log output appropriately (JSON, key-value, etc.)

**Security Considerations:**
- What inputs need validation? (paths, commands, user data)
- Are file paths sanitized? (prevent traversal attacks like `../../../etc/passwd`)
- Are shell commands properly quoted? (prevent injection)
- Could this hook exfiltrate sensitive data? (API keys, credentials, tokens)

Load `security-checklist.md` now for comprehensive security validation requirements.

### Step 5: Create Hook Configuration

Build the hooks configuration structure appropriate for the chosen event type:

**For Tool-Based Hooks (PreToolUse, PostToolUse, PermissionRequest):**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Write",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/validate-bash.sh",
            "timeout": 60000
          }
        ]
      }
    ]
  }
}
```

**For Lifecycle Hooks (SessionStart, SessionEnd, Stop, etc.):**
```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/setup-env.sh"
          }
        ]
      }
    ]
  }
}
```

**For Prompt-Based Hooks:**
```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Should Claude continue? Check: tasks complete? errors resolved? Respond: {\"decision\": \"approve\"|\"block\", \"reason\": \"...\"}",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

**Matcher Patterns:**
- Single tool: `"Bash"` or `"Write"`
- Multiple tools: `"Bash|Write|Edit"`
- All tools from MCP server: `"mcp__server-name__.*"`
- Specific MCP tool: `"mcp__server__tool-name"`
- Regex pattern: `"mcp__.*__write.*"` (all write tools across MCP)

Load `configuration-guide.md` for detailed JSON structure guidance and advanced patterns.

### Step 6: Write Hook Script

Choose script language (bash or python) and implement with security-first approach:

**Bash Script Template:**
```bash
#!/bin/bash
set -e

# Read JSON input from stdin
INPUT=$(cat)

# Parse required fields (use jq if available, or basic parsing)
TOOL_NAME=$(echo "$INPUT" | grep -o '"tool_name":"[^"]*"' | cut -d'"' -f4)
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path":"[^"]*"' | cut -d'"' -f4)

# Validate inputs (CRITICAL for security)
if [[ -z "$FILE_PATH" ]]; then
  exit 0  # No file path, nothing to validate
fi

# Security: Prevent path traversal
if [[ "$FILE_PATH" == *".."* ]] || [[ "$FILE_PATH" == *"~"* ]]; then
  echo "Path traversal detected: $FILE_PATH" >&2
  exit 2  # Block operation
fi

# Implement hook logic here

# Exit with appropriate code
exit 0  # Success/allow
# exit 2  # Block operation
```

**Python Script Template:**
```python
#!/usr/bin/env python3
import json
import sys
import os
import re

# Read input from stdin
input_data = json.load(sys.stdin)

tool_name = input_data.get("tool_name", "")
tool_input = input_data.get("tool_input", {})
file_path = input_data.get("file_path", "")

# Validate inputs (CRITICAL for security)
if not file_path:
    sys.exit(0)  # Nothing to validate

# Security: Prevent path traversal
if ".." in file_path or file_path.startswith("~/"):
    print(f"Path traversal detected: {file_path}", file=sys.stderr)
    sys.exit(2)  # Block operation

# Implement hook logic here

# Exit appropriately
sys.exit(0)  # Success/allow
# sys.exit(2)  # Block operation
```

**Script Requirements:**
- Shebang line at top (`#!/bin/bash` or `#!/usr/bin/env python3`)
- Read JSON from stdin
- Validate all inputs before use (security critical)
- Quote all variables in bash (`"$VARIABLE"` not `$VARIABLE`)
- Handle missing fields gracefully
- Use absolute paths or environment variables
- Include comprehensive error handling
- Make executable: `chmod +x script-name.sh`

Load `script-examples.md` for complete examples including audit logging, safety validation, and automation patterns.

### Step 7: Security Validation

**Critical Security Checks:**

**Input Validation:**
- Validate all inputs before use
- Check file paths for traversal attempts (`../`, absolute paths)
- Sanitize user-provided strings
- Reject unexpected input patterns

**Command Safety:**
- Quote all variables: `"$VARIABLE"` not `$VARIABLE`
- Use absolute paths for commands
- Avoid `eval` or dynamic command construction
- Validate before executing shell commands

**Data Protection:**
- Never log sensitive data (API keys, passwords, tokens)
- Check if hook could exfiltrate credentials
- Avoid writing sensitive data to files
- Be careful with environment variables

**Path Security:**
- Block path traversal: `../../../etc/passwd`
- Use absolute paths or validated relative paths
- Check file permissions before writing
- Avoid world-writable locations

**Error Handling:**
- Fail safely (don't expose system details)
- Log errors appropriately
- Don't leak sensitive info in error messages

Load `security-checklist.md` now for detailed validation requirements before deploying any hook.

### Step 8: Test and Deploy

**Testing Steps:**
1. Test script independently (provide sample JSON via stdin)
2. Add configuration to appropriate settings file (`~/.claude/settings.json` or `.claude/settings.json`)
3. Restart Claude Code to load hooks
4. Verify registration: `/hooks` command
5. Trigger hook with appropriate action
6. Check behavior and output
7. Enable debug mode: `claude --debug` for detailed logs

**Validation:**
- [ ] Hook appears in `/hooks` output
- [ ] Hook activates on expected triggers
- [ ] Hook blocks operations correctly (if PreToolUse)
- [ ] Hook produces expected output
- [ ] No errors in debug logs
- [ ] Security validation passed
- [ ] Script has execute permissions (`chmod +x`)
- [ ] All inputs are validated before use
- [ ] No path traversal or injection vulnerabilities

**Deployment:**
- Personal hooks: `~/.claude/settings.json` and `~/.claude/hooks/`
- Project hooks: `.claude/settings.json` and `.claude/hooks/` (commit to git)
- Document hook purpose and behavior for team
- Test in development before production use

Load `debugging-guide.md` for troubleshooting common issues.

## Progressive Disclosure Strategy

### What Goes Where

**SKILL.md (always loaded when triggered):**
- Core workflow and overview (400-600 words)
- Essential security requirements (300-400 words)
- Hook type selection guidance (200-300 words)
- Configuration templates (200-300 words)
- **Total: 1,500-2,000 words**

**references/ (loaded as needed by Claude):**
- Detailed event type specifications (1,000+ words)
- Complete security checklist (1,500+ words)
- Advanced configuration patterns (1,000+ words)
- Migration and troubleshooting guides (2,000+ words)

**examples/ (loaded when needed):**
- Complete working hook scripts
- Configuration templates
- Real-world usage examples

**templates/ (used directly, not loaded):**
- Hook script templates
- JSON configuration templates
- Ready-to-customize examples

## Writing Style Rules

### Imperative/Infinitive Form Only

Write direct instructions, not suggestions:

**Correct:**
```
Validate the file path before processing.
Check for path traversal patterns.
Block operations with suspicious input.
```

**Incorrect:**
```
You should validate the file path.
The hook can check for path traversal.
Users might want to block suspicious operations.
```

### Third-Person in Description

Frontmatter description must use third person:

**Correct:**
```yaml
description: This skill should be used when the user asks to "create a hook", "generate a hook", "build a new hook", or wants to create automated Claude Code hooks.
```

**Incorrect:**
```yaml
description: Use this skill when you need to create a hook...
description: Load when creating hooks...
```

## Common Mistakes to Avoid

### Mistake 1: Skipping Security Validation

**Why:** Hooks execute with user permissions and can access/modify sensitive data

**Solution:** Always run through security checklist before deploying:
- Input validation (paths, commands, user data)
- Command safety (quoted variables, no eval)
- Data protection (no logging secrets, no exfiltration)
- Path security (block traversal, validate permissions)

### Mistake 2: Wrong Hook Event Type

**Why:** Each event type has specific purposes and capabilities

**Solution:** Reference hook-types-reference.md and verify:
- Tool-based events need matchers
- Lifecycle events have different behaviors
- Some events support prompt hooks, others don't
- Each event has different input/output schemas

### Mistake 3: Using Second Person

**Why:** Instructions should be direct and actionable

**Solution:** Use imperative form throughout:
- "Validate the input" not "You should validate"
- "Check file permissions" not "You can check"
- "Block dangerous operations" not "Users might want to block"

### Mistake 4: Missing Input Validation

**Why:** Unvalidated inputs are security vulnerabilities

**Solution:** Always validate:
- File paths (traversal, absolute paths)
- Tool inputs (injection, dangerous commands)
- User data (sanitization, encoding)
- Environment variables (unexpected values)

## Validation Checklist

Before finalizing a generated hook:

**Structure:**
- [ ] Directory named appropriately (hook-generator)
- [ ] Hook script created with proper shebang
- [ ] Hook configuration is valid JSON
- [ ] Hook event type is appropriate for use case

**Description Quality:**
- [ ] Uses third person ("This skill should be used when...")
- [ ] Includes specific trigger phrases
- [ ] Trigger phrases are what users would say
- [ ] Mentions hook concepts that should trigger

**Content Quality:**
- [ ] Body uses imperative/infinitive form throughout
- [ ] SKILL.md is 1,500-2,000 words (max 3,000)
- [ ] Security validation is prominent
- [ ] Configuration examples are complete
- [ ] Scripts are executable with proper permissions

**Security:**
- [ ] All inputs validated before use
- [ ] Path traversal protection implemented
- [ ] Command injection protection implemented
- [ ] No sensitive data logging
- [ ] Fail-safe error handling

**Testing:**
- [ ] Hook loads without errors
- [ ] Hook activates on correct triggers
- [ ] Hook behaves as expected
- [ ] Debug logs show no errors
- [ ] Team tested (for project hooks)

## Quick Reference Templates

### Minimal Hook Structure

```
.claude/
├── settings.json
└── hooks/
    └── validate-bash.sh
```

For simple single-hook configurations.

### Standard Hook Structure (Recommended)

```
.claude/
├── settings.json
└── hooks/
    ├── validate-bash.sh
    ├── audit-write.sh
    └── setup-env.sh
```

For most projects with multiple related hooks.

### Complete Hook Structure

```
.claude/
├── settings.json
├── hooks/
│   ├── validate-bash.sh
│   ├── audit-write.sh
│   ├── setup-env.sh
│   └── cleanup-env.sh
└── hook-logs/
    └── audit.log
```

For comprehensive hook setups with multiple event types and logging.

## Implementation Steps Summary

To generate a hook:

1. **Fetch docs**: Run `!curl -s https://code.claude.com/docs/en/hooks-guide.md` and `!curl -s https://code.claude.com/docs/en/hooks.md`
2. **Understand**: Ask about event type, triggers, validation rules, and security requirements
3. **Plan**: Identify hook type (command/prompt), event type, and matcher patterns
4. **Design**: Define input processing, decision logic, output requirements, and security measures
5. **Configure**: Create JSON configuration with appropriate matcher and hook type
6. **Implement**: Write hook script with security-first approach (bash or python)
7. **Validate**: Run security checklist, test script independently, verify permissions
8. **Deploy**: Add to settings file, restart Claude, verify with `/hooks`, test in session

## Additional Resources

### Reference Files

For detailed information, consult:
- **`references/hook-types-reference.md`** - Complete specifications for all 9 hook event types, input/output fields, matchers, and use cases
- **`references/official-response-schema.md`** - Complete official hook response schema with all fields, advanced structured JSON guidance
- **`references/prompt-hooks-guide.md`** - Comprehensive guide to prompt-based hooks, LLM decision making, response schemas, and examples
- **`references/plugin-hooks-guide.md`** - Complete coverage of plugin hook composition, distributed hook systems, and multi-plugin scenarios
- **`references/configuration-guide.md`** - Detailed JSON structure, matcher patterns, tool restrictions, and timeout configuration
- **`references/security-checklist.md`** - Comprehensive security validation requirements, common vulnerabilities, and prevention techniques
- **`references/script-examples.md`** - Complete bash and python examples from Claude cookbooks including audit logging and safety patterns
- **`references/debugging-guide.md`** - Troubleshooting activation issues, using /hooks command, debug mode, and common errors

### Template Files

Ready-to-customize templates in `templates/`:
- **`templates/bash-hook-template.sh`** - Bash script template with security validation
- **`templates/python-hook-template.py`** - Python script template with security validation
- **`templates/hook-config-template.json`** - Hook configuration JSON template
- **`templates/prompt-hook-template.json`** - Prompt-based hook configuration template

### Example Files

Working examples in `examples/`:
- **`examples/pretooluse-validate-bash.sh`** - Bash command validation before execution
- **`examples/posttooluse-audit-write.sh`** - Audit logging after file writes
- **`examples/stop-intelligent-decision.json`** - Prompt-based stop hook with task completion analysis

## Best Practices

**DO:**
- Fetch latest hook docs using `!curl` at start
- Ask clarifying questions about event type and requirements
- Use specific trigger phrases in description
- Validate all inputs before use (security critical)
- Quote all variables in bash (`"$VARIABLE"`)
- Use absolute paths or environment variables
- Fail safely with proper error handling
- Test hooks independently before deploying
- Reference supporting files in SKILL.md
- Run security checklist before deploying

**DON'T:**
- Skip fetching latest hook documentation
- Use vague trigger descriptions
- Write in second person
- Forget to validate inputs (security vulnerability!)
- Use unquoted variables in bash
- Use `eval` or dynamic command construction
- Log sensitive data (API keys, passwords, tokens)
- Deploy without testing
- Assume requirements without asking
