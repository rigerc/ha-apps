# Hook Debugging Guide

Troubleshooting activation issues, using /hooks command, debug mode, common errors, and solutions.

## Verifying Hook Registration

### Use /hooks Command

Run `/hooks` to list all registered hooks:

```
/hooks
```

**Expected Output:**
```
User Hooks (~/.claude/settings.json):
  PreToolUse[Write]: validate-write.sh
  PostToolUse[Write|Edit]: audit-operations.sh

Project Hooks (.claude/settings.json):
  SessionStart[startup]: setup-env.sh
  Stop: intelligent-stop.sh
```

**If Hook Missing:**
1. Check settings file exists and has valid JSON
2. Restart Claude Code: `claude --restart`
3. Check for JSON syntax errors
4. Verify hook configuration structure

---

## Debug Mode

### Enable Debug Logging

Run Claude Code with debug flag:

```bash
claude --debug
```

**What Debug Shows:**
- Hook loading errors
- Hook execution attempts
- Hook input/output data
- Exit codes and responses
- Timeout events

**Analyze Debug Output:**

```
[DEBUG] Loading hooks from ~/.claude/settings.json
[DEBUG] Registering hook: PreToolUse[Write]
[DEBUG] Hook script path: /project/.claude/hooks/validate.sh
[DEBUG] Executing hook with input: {"tool_name":"Write"...}
[DEBUG] Hook exited with code: 2
[DEBUG] Hook blocked operation
```

---

## Common Issues and Solutions

### Issue 1: Hook Not Firing

**Symptoms:**
- Hook configured but never executes
- `/hooks` shows hook registered
- No errors in debug logs

**Debug Steps:**
1. Verify event type is correct
2. Check matcher pattern matches expected tools
3. Trigger appropriate action to match hook
4. Look for "No matching hooks" in debug

**Solution:**
```bash
# Check event type
# If expecting Write operations to trigger:
# Use: PreToolUse or PostToolUse with matcher "Write"
# NOT: SessionStart or other lifecycle events

# Check matcher
# Matcher must match tool being called
# "Write|Edit" matches Write or Edit tools
# "Bash" only matches Bash tool
```

### Issue 2: Permission Denied

**Symptoms:**
- Hook script has execute permission
- Debug shows "Permission denied" error

**Solution:**
```bash
# Ensure script is executable
chmod +x /path/to/hook/script.sh

# Verify shebang line exists
head -1 /path/to/hook/script.sh
# Should show: #!/bin/bash or #!/usr/bin/env python3

# Check file owner
ls -la /path/to/hook/script.sh
# Should be executable by current user
```

### Issue 3: JSON Parse Error

**Symptoms:**
- Hook fails immediately
- Debug shows "Invalid JSON" or parse error

**Solution:**
```bash
# Validate JSON syntax
cat ~/.claude/settings.json | jq .

# Common JSON errors:
# - Missing comma after array item
# - Trailing comma in array/object
# - Unquoted strings
# - Single quotes instead of double quotes
```

### Issue 4: Script Not Found

**Symptoms:**
- Hook registered but script fails to run
- Debug shows "No such file or directory"

**Solution:**
```bash
# Use absolute paths or $CLAUDE_PROJECT_DIR
# DON'T: "hooks/script.sh" (relative)
# DO: "$CLAUDE_PROJECT_DIR/.claude/hooks/script.sh"

# Verify file exists
ls -la "$CLAUDE_PROJECT_DIR/.claude/hooks/script.sh"
```

### Issue 5: Hook Timeout

**Symptoms:**
- Hook takes too long to execute
- Debug shows timeout error

**Solution:**
```bash
# Increase timeout in configuration
{
  "type": "command",
  "command": "/path/to/script.sh",
  "timeout": 120000  # Increase from default 60000
}

# Or optimize script performance
# - Add early exit conditions
# - Cache expensive operations
# - Use more efficient tools (jq vs grep)
```

### Issue 6: Wrong Exit Code

**Symptoms:**
- Hook doesn't behave as expected
- Blocking doesn't work, or allows when should block

**Solution:**
```bash
# Verify exit codes
# 0 = Success / Allow
# 2 = Block (for PreToolUse, Stop, etc.)
# Other = Non-blocking error

# Test exit code
echo "test" | /path/to/hook/script.sh
echo "Exit code: $?"

# For blocking hooks, ensure explicit exit 2
if [[ "$BLOCK_CONDITION" ]]; then
  exit 2  # Block
fi
exit 0  # Allow
```

### Issue 7: Input Not Being Read

**Symptoms:**
- Hook script doesn't process input
- Variables are empty

**Solution:**
```bash
# Hooks receive JSON via stdin
# MUST read from stdin

# DON'T: Use command line arguments
# DO: Read from stdin

INPUT=$(cat)

# Or use jq for robust parsing
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name')
```

### Issue 8: Prompt Hook Fails

**Symptoms:**
- Prompt-based hook returns "invalid JSON"
- LLM doesn't return expected format

**Solution:**
```json
{
  "type": "prompt",
  "prompt": "Return ONLY valid JSON. No explanation.\n\nEvaluate: $ARGUMENTS\n\nRespond: {\"decision\": \"approve\" or \"block\", \"reason\": \"...\"}"
}
```

Be more explicit about response format.

---

## Testing Hooks

### Test Hook Independently

**Method 1: Echo JSON**
```bash
# Create test input
echo '{"tool_name":"Write","file_path":"/project/test.txt"}' | /path/to/hook/script.sh
echo "Exit code: $?"
```

**Method 2: From File**
```bash
# Save test input to file
cat > test-input.json << EOF
{"tool_name":"Write","file_path":"/project/test.txt"}
EOF

# Test hook
cat test-input.json | /path/to/hook/script.sh
echo "Exit code: $?"
```

**Method 3: Interactive**
```bash
# Run hook and paste input
/path/to/hook/script.sh
# Paste JSON input
# Press Ctrl+D to send
```

### Test Scenarios

**Test 1: Valid Input**
```json
{"tool_name":"Write","file_path":"/project/src/main.ts"}
```

**Test 2: Invalid Input (Path Traversal)**
```json
{"tool_name":"Write","file_path":"../../../etc/passwd"}
```

**Test 3: Missing Fields**
```json
{"tool_name":"Bash"}
```

---

## Hook-Specific Debugging

### PreToolUse Hook

**Debug Questions:**
1. Does hook fire before tool? (check debug logs)
2. Is exit code 2 blocking the tool?
3. Is tool_input being read correctly?

**Common Issue:**
- Hook not reading tool_input fields correctly

**Verify:**
```bash
# Test with actual tool input
echo '{"tool_name":"Write","tool_input":{"file_path":"test.txt"}}' | /path/to/hook/script.sh
```

### PostToolUse Hook

**Debug Questions:**
1. Does hook fire after tool? (check debug logs)
2. Is tool_response available in input?
3. Is logging working correctly?

**Common Issue:**
- Trying to block (can't block, operation complete)

**Remember:** PostToolUse cannot block operations

### Stop Hook

**Debug Questions:**
1. Does hook fire after each response?
2. Is exit code 2 causing continuation?
3. Is decision logic working?

**Common Issue:**
- Infinite loop (hook always exits 2)

**Prevent Loops:**
```bash
#!/bin/bash
INPUT=$(cat)

# Check if already continuing to prevent loops
CURRENT=$(echo "$INPUT" | grep -o '"stop_hook_active":true' || echo "")
if [[ -n "$CURRENT" ]]; then
  exit 0  # Allow stop (we're in a loop)
fi
```

### UserPromptSubmit Hook

**Debug Questions:**
1. Does hook fire before prompt processing?
2. Is prompt field available in input?
3. Is validation working correctly?

**Common Issue:**
- Accidentally blocking all prompts

**Verify:**
```bash
# Test with prompt
echo '{"prompt":"test prompt"}' | /path/to/hook/script.sh
# Should exit 0 for valid prompt
```

---

## Performance Debugging

### Slow Session

**Symptoms:**
- Claude Code feels sluggish
- Delay after each operation

**Debug Steps:**
1. Check `/hooks` for high-frequency hooks
2. Look for hooks on common events:
   - PreToolUse on all tools (`"*"` matcher)
   - Stop hook with expensive LLM decision
   - PostToolUse on every write

**Solution:**
```bash
# Make matchers more specific
# DON'T: {"matcher": "*"}
# DO: {"matcher": "Write|Edit"}

# Optimize expensive operations
# Cache results, use faster tools, simplify logic
```

### High Resource Usage

**Symptoms:**
- High CPU during hook execution
- Memory usage growing

**Debug Steps:**
1. Profile hook script
2. Check for inefficient operations
3. Look for memory leaks (accumulating data)

**Solution:**
```bash
# Profile bash script
time /path/to/hook/script.sh < test-input.json

# Profile Python script
python -m cProfile /path/to/hook/script.py < test-input.json
```

---

## Getting Help

### Collect Information

When seeking help, collect:

1. **Hook Configuration:**
   ```bash
   cat ~/.claude/settings.json
   # or
   cat .claude/settings.json
   ```

2. **Hook Script:**
   ```bash
   cat /path/to/hook/script.sh
   ```

3. **Debug Output:**
   ```bash
   claude --debug 2>&1 | tee hook-debug.log
   ```

4. **Test Results:**
   ```bash
   echo '{"test":"input"}' | /path/to/hook/script.sh
   echo "Exit code: $?"
   ```

5. **System Info:**
   ```bash
   uname -a
   claude --version
   ```

### Common Questions

**Q: Why doesn't my hook fire?**
A: Check event type, matcher, and that appropriate action triggers it. Use `/hooks` and `--debug`.

**Q: Why does my hook crash?**
A: Check script syntax, execute permissions, and JSON parsing. Debug logs show exact error.

**Q: Why does blocking not work?**
A: Verify exit code 2 for blocking events. PostToolUse cannot block. Check decision logic.

**Q: Why is my session slow?**
A: Check for high-frequency hooks (Stop, PreToolUse). Optimize or make matchers more specific.
