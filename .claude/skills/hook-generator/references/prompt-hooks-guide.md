# Prompt-Based Hooks Guide

Comprehensive guide to prompt-based hooks (type: "prompt"), LLM decision making, response schemas, examples, and use cases for intelligent decision-making.

## Overview

**What Are Prompt-Based Hooks?**

Prompt-based hooks send hook context to an LLM (Claude Haiku) for intelligent evaluation. Instead of writing complex bash/python logic, write a natural language prompt that describes the decision criteria.

**Example Use Cases:**
- Decide if Claude should stop based on conversation analysis
- Validate user prompts with semantic understanding
- Make context-aware permission decisions
- Evaluate subagent task completion with full context

**Key Advantages Over Command Hooks:**
| Aspect | Command Hooks | Prompt Hooks |
|--------|---|---|
| Decision Logic | Deterministic (pattern matching) | Contextual (LLM evaluation) |
| Implementation | Requires scripting | Just write a prompt |
| Flexibility | Limited to programmed patterns | Adapts to context |
| Complexity | Simple rules work well | Better for nuanced decisions |
| Speed | Very fast (local) | Slower (API call) |

## Supported Hook Events

Prompt-based hooks work with these event types:

**Primary Use Cases (recommended):**
- **Stop**: Decide whether Claude should continue working
- **SubagentStop**: Evaluate if subagent completed its task
- **UserPromptSubmit**: Validate user input with semantic analysis
- **PreToolUse**: Make context-aware tool permission decisions
- **PermissionRequest**: Intelligently allow/deny permission dialogs

**Less Common:**
- Other events support prompt-based hooks but are less typical

## Configuration

### Basic Structure

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Your prompt here describing the decision to make",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

### Configuration Fields

- **type**: Must be `"prompt"`
- **prompt**: The prompt text sent to LLM
  - Can include `$ARGUMENTS` placeholder (replaced with hook input JSON)
  - If no `$ARGUMENTS`, hook input JSON appended to prompt
- **timeout**: Maximum seconds to wait for LLM response (default: 30, max recommended: 60)

## Prompt Writing

### Best Practices for Prompt-Based Hook Prompts

**1. Be Specific:**
```
# Good
Evaluate if Claude should continue. Check: 1) all tasks complete, 2) no errors, 3) no follow-up needed. Respond: {"decision": "approve"}.

# Bad
Should we continue?
```

**2. List Decision Criteria:**
```
Evaluate task completion:
1. Has user's stated request been completed?
2. Are there errors mentioned but not fixed?
3. Is there work mentioned but not started?
```

**3. Include Response Format:**
```
Respond with JSON: {"decision": "approve" or "block", "reason": "explanation"}
```

**4. Reference `$ARGUMENTS`:**
```
Hook context: $ARGUMENTS
Evaluate the above context and decide if...
```

## Response Schema

### Standard Response Fields

All prompt-based hooks expect JSON response with:

```json
{
  "decision": "approve" | "block",
  "reason": "explanation of the decision"
}
```

- **decision**: "approve" allows action, "block" prevents it
- **reason**: Explanation shown to Claude (when decision is "block")

### Advanced Response Fields (Optional)

```json
{
  "decision": "approve" | "block",
  "reason": "Explanation",
  "continue": false,              // Stop entire Claude execution
  "stopReason": "message",        // Reason shown to user (with continue: false)
  "systemMessage": "warning"      // Additional message shown to user
}
```

## Common Decision Patterns

### Pattern 1: Task Completion Analysis

**Use For:** Stop hook - decide if Claude should continue

**Prompt:**
```
Evaluate whether Claude should stop working.

Context: $ARGUMENTS

Questions:
1. What did the user ask for?
2. Has that been completed?
3. Are there unresolved errors?
4. Did the user indicate satisfaction?

Decision rules:
- Approve (stop) if: Task complete AND no errors AND user satisfied
- Block (continue) if: Task incomplete OR errors present OR follow-up needed

Respond: {"decision": "approve" or "block", "reason": "..."}
```

### Pattern 2: Semantic Prompt Validation

**Use For:** UserPromptSubmit hook - validate user intent

**Prompt:**
```
Evaluate this user prompt for validity.

Context: $ARGUMENTS

Checks:
1. Is the request clear and actionable?
2. Does it violate security policies? (no secrets, credentials, harmful actions)
3. Is it relevant to current project context?

Respond: {"decision": "approve" or "block", "reason": "..."}
```

### Pattern 3: Context-Aware Permission

**Use For:** PreToolUse hook - intelligent tool decisions

**Prompt:**
```
Determine if this tool call is appropriate.

Context: $ARGUMENTS

Consider:
1. What tool is being called?
2. What's the input?
3. Is it safe for current context?
4. Any security concerns?

Respond: {"decision": "approve" or "block", "reason": "..."}
```

### Pattern 4: Subagent Task Verification

**Use For:** SubagentStop hook - evaluate subagent completion

**Prompt:**
```
Did the subagent complete its assigned task?

Context: $ARGUMENTS

Evaluate:
1. What was the subagent asked to do?
2. What did the subagent produce?
3. Does output satisfy requirements?
4. Is additional work needed?

Respond: {"decision": "approve" (done) or "block" (needs work), "reason": "..."}
```

## Step-by-Step Examples

### Example 1: Intelligent Stop Hook

Create `.claude/settings.json` with:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Evaluate if Claude should stop or continue working.\n\nContext: $ARGUMENTS\n\nCheck:\n1. What did the user ask for?\n2. Has that been completed?\n3. Are there unresolved errors?\n4. Did user indicate satisfaction?\n\nRules:\n- Stop (approve) if: Task complete AND no errors AND user satisfied\n- Continue (block) if: Task incomplete OR errors present\n\nRespond: {\"decision\": \"approve\" or \"block\", \"reason\": \"brief explanation\"}",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

### Example 2: Secure Prompt Validation

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Validate this user prompt.\n\nContext: $ARGUMENTS\n\nSecurity checks:\n1. No sensitive info (API keys, passwords, credentials)\n2. No malicious intent\n3. Clear and actionable request\n\nBlock if: Contains secrets OR suspicious intent\nApprove if: Valid request\n\nRespond: {\"decision\": \"approve\" or \"block\", \"reason\": \"...\"}",
            "timeout": 20
          }
        ]
      }
    ]
  }
}
```

### Example 3: MCP Tool Permission

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "mcp__.*__.*",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Should this MCP tool call be allowed?\n\nContext: $ARGUMENTS\n\nEvaluate:\n1. Is the tool safe and appropriate?\n2. Does the input look reasonable?\n3. Any security concerns?\n\nRespond: {\"decision\": \"approve\" or \"block\", \"reason\": \"...\"}",
            "timeout": 25
          }
        ]
      }
    ]
  }
}
```

## Best Practices

### 1. Write Clear, Unambiguous Prompts

**Good:**
```
Evaluate if the user's request has been completely fulfilled.
"Completely fulfilled" means:
- All specific tasks mentioned are done
- No errors remain
- User indicated satisfaction
```

**Bad:**
```
Is the task done?
```

### 2. Include Context Analysis in Prompt

**Good:** Analyze the conversation, identify requests, evaluate completion
**Bad:** Just ask a yes/no question without context

### 3. Be Specific About Decision Criteria

**Good:** List 3-5 specific criteria that determine the decision
**Bad:** Leave decision criteria vague or implicit

### 4. Test Decisions Before Deploying

Test prompt hook decisions in isolation before using in production:
```
Mock hook input: {"key": "value"}
My prompt: "Make decision about X"
Expected: "approve" | "block"
Actual: [run and verify]
```

## Performance Considerations

### Timeout Tuning

- **Default**: 30 seconds
- **Recommended Range**: 20-45 seconds
- **Quick Decisions**: 15-20 seconds (simple criteria)
- **Complex Decisions**: 30-45 seconds (multi-step analysis)

### Cost Implications

Each prompt hook makes an API call to Claude Haiku:
- **Stop Hook**: Called every time Claude finishes (frequent)
- **UserPromptSubmit**: Called for every user input (frequent)
- **PreToolUse**: Called for every tool use (very frequent)

**Optimization:**
- Use command hooks for simple pattern matching
- Reserve prompt hooks for decisions requiring context
- Don't use prompt hooks on high-frequency events unless necessary

## Comparison with Command Hooks

| Feature | Command Hooks | Prompt-Based Hooks |
|---------|--------------|-------------------|
| Execution | Runs bash script | Queries LLM |
| Decision Logic | You implement in code | LLM evaluates context |
| Setup Complexity | Requires script file | Configure prompt |
| Context Awareness | Limited to script logic | Natural language understanding |
| Performance | Fast (local) | Slower (API call) |
| Use Case | Deterministic rules | Context-aware decisions |

### When to Use Prompt Hooks

- Decisions require understanding context
- Multiple criteria to evaluate
- Natural language understanding needed
- Conversation analysis required
- Complex conditionals would be messy in bash

### When to Use Command Hooks

- Simple pattern matching
- File operations or system commands
- Deterministic rules
- Performance-critical
- No network/API calls desired

## Troubleshooting

### Invalid JSON Response

**Symptoms:** "Hook failed with invalid JSON" error

**Fix:**
- Be more explicit: "Return ONLY valid JSON, no explanation"
- Show exact format: `{"decision": "approve", "reason": "explanation"}`
- Add validation: "Ensure JSON is valid and parseable"

### Timeout Exceeded

**Symptoms:** Prompt hook times out before LLM responds

**Solutions:**
- Increase timeout: `"timeout": 45`
- Simplify prompt (shorter = faster)
- Reduce decision criteria
- Check network connectivity

### LLM Making Wrong Decisions

**Symptoms:** Prompt hook approves/blocks incorrectly

**Debugging:**
1. Check prompt clarity - is it unambiguous?
2. Provide examples: "Example input: X → decision should be: Y"
3. Add explicit decision rules
4. Test prompt separately before deploying
5. Refine based on actual behavior
