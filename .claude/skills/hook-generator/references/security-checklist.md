# Hook Security Checklist

Comprehensive security validation requirements, common vulnerabilities, and prevention techniques for Claude Code hooks.

**CRITICAL:** Hooks execute with user permissions and can access/modify system resources. Always validate security before deploying.

## Input Validation

### File Path Validation

**Required Checks:**
- [ ] Path traversal detection: `../`, `..\`, absolute paths outside project
- [ ] Null byte injection: `\0` in paths
- [ ] Symbolic link handling: Validate symlink targets
- [ ] Path length limits: Prevent buffer overflow
- [ ] Character encoding: Validate UTF-8 encoding

**Validation Code (Bash):**
```bash
#!/bin/bash
# Block path traversal
if [[ "$FILE_PATH" == *".."* ]] || [[ "$FILE_PATH" == *"~"* ]]; then
  echo "Path traversal detected: $FILE_PATH" >&2
  exit 2
fi

# Validate path is within project
PROJECT_ROOT="${CLAUDE_PROJECT_DIR}"
REAL_PATH=$(realpath "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")

if [[ "$REAL_PATH" != "$PROJECT_ROOT"* ]]; then
  echo "Path outside project: $REAL_PATH" >&2
  exit 2
fi
```

**Validation Code (Python):**
```python
#!/usr/bin/env python3
import os
import sys

def validate_path(file_path, project_root):
    """Validate file path is safe and within project."""
    # Block path traversal
    if ".." in file_path or file_path.startswith("~/"):
        return False

    # Get absolute paths
    abs_path = os.path.abspath(file_path)
    abs_root = os.path.abspath(project_root)

    # Verify within project
    try:
        abs_path.relative_to(abs_root)
    except ValueError:
        return False

    return True
```

### Command Validation

**Required Checks:**
- [ ] Command injection: `;`, `|`, `&`, `` ` ``, `$()`, `\``
- [ ] Dangerous commands: `rm`, `mv`, `dd`, `mkfs`, `>`, `>>`
- [ ] Flag validation: Check for dangerous flags (`-rf`, `--force`)
- [ ] Argument sanitization: Validate all arguments

**Dangerous Pattern Detection:**
```bash
#!/bin/bash
COMMAND=$(echo "$INPUT" | grep -o '"command":"[^"]*"' | cut -d'"' -f4)

# Block dangerous commands
DANGEROUS="rm|mkfs|dd|:>chmod\ -f|chmod\ -R"
if [[ "$COMMAND" =~ $DANGEROUS ]]; then
  echo "Dangerous command blocked: $COMMAND" >&2
  exit 2
fi

# Block command injection
if [[ "$COMMAND" == *';'* ]] || [[ "$COMMAND" == *'|'* ]]; then
  echo "Command injection detected: $COMMAND" >&2
  exit 2
fi
```

### User Input Validation

**Required Checks:**
- [ ] Length limits: Prevent buffer overflows
- [ ] Character validation: Allowlist expected characters
- [ ] Encoding validation: Proper UTF-8
- [ ] Special characters: Escape or reject dangerous chars

```bash
#!/bin/bash
# Validate user input contains only safe characters
SAFE_PATTERN="^[a-zA-Z0-9_\-./:space:]+$"

if ! [[ "$USER_INPUT" =~ $SAFE_PATTERN ]]; then
  echo "Invalid characters in input" >&2
  exit 2
fi
```

## Command Safety

### Variable Quoting

**ALWAYS quote variables:**

**Vulnerable:**
```bash
#!/bin/bash
# DON'T DO THIS
rm -rf $TEMP_DIR/*  # If TEMP_DIR is empty, deletes root!
```

**Secure:**
```bash
#!/bin/bash
# DO THIS
rm -rf "${TEMP_DIR:?}"/*  # Fails if empty, prevents disaster
```

**Quoting Rules:**
- [ ] All variables expanded: `"$VARIABLE"`
- [ ] Use `${VARIABLE:?}` for required vars
- [ ] Use `"${VARIABLE:-default}"` for defaults
- [ ] Never use `$VARIABLE` without quotes

### Command Construction

**NEVER construct commands dynamically:**

**Vulnerable:**
```bash
#!/bin/bash
# DON'T DO THIS
CMD="rm -rf $TARGET_DIR"
eval "$CMD"  # Arbitrary code execution
```

**Secure:**
```bash
#!/bin/bash
# DO THIS
case "$OPERATION" in
  delete)
    rm -rf -- "${TARGET_DIR:?}"
    ;;
  copy)
    cp -r -- "${SOURCE:?}" "${TARGET:?}"
    ;;
esac
```

### Use Absolute Paths

**Vulnerable:**
```bash
#!/bin/bash
python script.py  # Could run malicious python
```

**Secure:**
```bash
#!/bin/bash
/usr/bin/python3 /path/to/script.py  # Specific binary
```

## Data Protection

### No Sensitive Logging

**PROHIBITED in logs:**
- API keys and tokens
- Passwords and credentials
- Session tokens
- Personal data (PII)
- Proprietary information
- Encryption keys

**Safe Logging:**
```bash
#!/bin/bash
# DON'T log this
echo "API_KEY: $API_KEY" >> log.log

# DO this instead
echo "API_KEY: ${API_KEY:0:8}..." >> log.log  # Only first 8 chars
# Or use hash
echo "API_KEY_HASH: $(echo "$API_KEY" | sha256sum)" >> log.log
```

### Secure File Operations

**File Creation:**
```bash
#!/bin/bash
# DON'T create world-writable files
echo "data" > /tmp/output.log

# DO set restrictive permissions
echo "data" > /tmp/output.log
chmod 600 /tmp/output.log
```

**Temporary Files:**
```bash
#!/bin/bash
# DON'T use predictable temp files
TEMP_FILE="/tmp/my-hook-data.tmp"

# DO use secure temp file creation
TEMP_FILE=$(mktemp) || exit 1
trap "rm -f '$TEMP_FILE'" EXIT
```

## Error Handling

### Fail Securely

**Principles:**
- Default to deny, not allow
- Explicit failures over implicit successes
- Don't expose system details in errors
- Log errors without sensitive data

**Secure Error Handling:**
```bash
#!/bin/bash
set -e  # Exit on error

# Safe error message
error_exit() {
  echo "Operation failed: $1" >&2
  # Don't reveal: paths, system details, internals
  exit 2
}

# Usage
if ! validate_input "$INPUT"; then
  error_exit "Invalid input format"
fi
```

## Environment Variable Security

### Validate Environment Variables

**Never trust environment variables:**
```bash
#!/bin/bash
# DON'T assume safe values
cd "$USER_PROVIDED_DIR"

# DO validate first
if [[ -z "$USER_PROVIDED_DIR" ]]; then
  echo "Directory not provided" >&2
  exit 2
fi

if [[ "$USER_PROVIDED_DIR" == *".."* ]]; then
  echo "Unsafe directory path" >&2
  exit 2
fi

cd "$USER_PROVIDED_DIR"
```

### Use Secure Defaults

```bash
#!/bin/bash
# Use defaults with validation
TIMEOUT="${HOOK_TIMEOUT:-30}"  # Default 30 seconds
if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]]; then
  TIMEOUT=30  # Fallback to safe default
fi
```

## Hook-Specific Considerations

### PreToolUse Security

**Special risks:**
- Hook runs before tool executes
- Can block any operation
- Input is tool parameters

**Required:**
- [ ] Validate tool_name is expected
- [ ] Sanitize all tool_input fields
- [ ] Check file_path in tool_input
- [ ] Verify command in tool_input (Bash tool)

### PostToolUse Security

**Special risks:**
- Has access to tool output
- Cannot block (operation complete)
- May log sensitive information

**Required:**
- [ ] Don't log sensitive tool_response data
- [ ] Be careful with file_path in response
- [ ] Sanitize logs before writing
- [ ] Don't exfiltrate data via logs

### UserPromptSubmit Security

**Special risks:**
- Has access to user prompt text
- Can block or modify user input
- May see sensitive information in prompt

**Required:**
- [ ] Don't log full prompt text
- [ ] Detect and redact sensitive patterns
- [ ] Be careful with blocking logic
- [ ] Document what triggers blocking

## Common Vulnerabilities

### Vulnerability 1: Path Traversal

**Attack:** Pass file paths like `../../../../etc/passwd` to access files outside project

**Prevention:**
- Validate paths don't contain `..`
- Resolve paths and verify within project root
- Use allowlist of safe directories

### Vulnerability 2: Command Injection

**Attack:** Inject commands via unquoted variables or eval

**Prevention:**
- Quote all variables
- Never use eval
- Use explicit command lists (case statements)
- Validate against allowlist

### Vulnerability 3: Log Injection

**Attack:** Inject control characters into logs to mislead parsing or hide attacks

**Prevention:**
- Sanitize log output
- Use structured logging (JSON)
- Escape control characters
- Validate log input length

### Vulnerability 4: Time-Based Attacks

**Attack:** Expensive operations in hooks cause denial-of-service

**Prevention:**
- Set appropriate timeouts
- Avoid expensive operations in high-frequency hooks
- Cache results when possible
- Use matchers to reduce frequency

## Validation Checklist

Before deploying any hook:

**Input Validation:**
- [ ] All file paths validated for traversal
- [ ] All commands validated for injection
- [ ] All user input sanitized
- [ ] Length limits enforced
- [ ] Character encoding validated

**Command Safety:**
- [ ] All variables quoted
- [ ] No eval or dynamic construction
- [ ] Absolute paths used for commands
- [ ] No dangerous patterns allowed

**Data Protection:**
- [ ] No sensitive data logged
- [ ] No credentials in output
- [ ] Secure file permissions set
- [ ] Temp files created securely

**Error Handling:**
- [ ] Fail-safe behavior
- [ ] No system details in errors
- [ ] Sensitive data excluded from errors
- [ ] Proper exit codes used

**Hook-Specific:**
- [ ] Tool inputs validated (PreToolUse)
- [ ] Tool responses not logged (PostToolUse)
- [ ] Prompts not fully logged (UserPromptSubmit)
- [ ] Appropriate timeouts set

## Security Testing

### Test Cases

**Path Traversal Tests:**
```
../../../etc/passwd
../../.hidden/secret
~/../etc/passwd
/absolute/path/outside/project
```

**Command Injection Tests:**
```
file.txt; rm -rf /
file.txt && malicious
file.txt | malicious
file.txt`malicious`
file.txt$(malicious)
```

**Log Injection Tests:**
```
Normal text
\n[ERROR] Fake error
\x1b[31mRed text\x1b[0m
Very long string to cause buffer overflow...
```

### Test Command

```bash
# Test hook with malicious input
echo '{"file_path":"../../../etc/passwd"}' | ./hook-script.sh
# Should exit 2 (block)

echo '{"command":"file.txt; rm -rf /"}' | ./hook-script.sh
# Should exit 2 (block)

echo '{"prompt":"My API key is sk-1234567890"}' | ./hook-script.sh
# Should not log the API key
```

## Resources

For complete hook security guidance:
- **SKILL.md**: Main workflow and security overview
- **script-examples.md**: Secure hook script examples
- **debugging-guide.md**: Troubleshooting security issues
