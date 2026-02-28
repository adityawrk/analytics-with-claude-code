# Automating Analytics Workflows with Hooks

## What Hooks Are

Hooks are scripts that run automatically at specific points in the Claude Code lifecycle. They intercept events -- a file being written, a command about to run, a session starting -- and can modify behavior, validate actions, or trigger side effects.

For analytics teams, hooks are guardrails and automations. They prevent dangerous queries from running, enforce formatting standards, and notify you when long analyses finish.

## Lifecycle Events

| Event | When It Fires | Common Use |
|-------|--------------|------------|
| `PreToolUse` | Before any tool executes | Validate, block, or modify tool calls |
| `PostToolUse` | After any tool executes | Format output, log actions, trigger follow-ups |
| `Notification` | When Claude Code wants to notify the user | Custom alerts (Slack, email, sound) |
| `Stop` | When Claude Code finishes a response turn | Post-processing, cleanup |
| `SubagentStop` | When a subagent completes | Collect and process agent results |

## The Hook Execution Model

Hooks are external scripts (Bash, Python, Node, etc.) that receive JSON on stdin and communicate via exit codes and stdout.

### Input (stdin)

Every hook receives a JSON payload describing the event:

```json
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "psql -c 'DROP TABLE users;'",
    "description": "Drop the users table"
  },
  "session_id": "abc123"
}
```

### Exit Codes and Output Protocol

| Exit Code | Meaning |
|-----------|---------|
| 0 | Success. For PreToolUse, stdout JSON controls the decision (see below). For PostToolUse, no stdout needed. |
| 1 | Hook error (action proceeds, error is logged) |
| 2 | Block the action (PreToolUse only, legacy alternative — prefer JSON protocol below) |

**PreToolUse hooks** communicate decisions via JSON on stdout with `exit 0`:

**To block an action** (preferred pattern):
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Query contains DROP TABLE. Not allowed in analytics sessions."
  }
}
```

**To add a warning without blocking:**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "Warning: query targets a large table. Consider adding a date filter."
  }
}
```

**To allow silently:** exit 0 with no stdout.

**PostToolUse hooks** should exit 0 with no stdout. They run for side effects only (formatting, logging).

## Analytics Use Cases

### Use Case 1: SQL Validation Before Execution

Block dangerous SQL queries before they reach your database.

Create `.claude/hooks/validate-sql.sh`:

```bash
#!/bin/bash
# Reads the tool input from stdin and checks for dangerous SQL patterns
# Uses the hookSpecificOutput JSON protocol for PreToolUse hooks.

set -euo pipefail

input=$(cat)

# Helper: deny with reason (exits 0 with JSON)
deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# Helper: warn without blocking
warn() {
  jq -n --arg ctx "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      additionalContext: $ctx
    }
  }'
  exit 0
}

# Only check Bash commands
tool_name=$(echo "$input" | jq -r '.tool_name')
if [ "$tool_name" != "Bash" ]; then
  exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command')

# Block destructive operations
dangerous_patterns=(
  "DROP TABLE"
  "DROP DATABASE"
  "TRUNCATE"
  "DELETE FROM.*WHERE 1=1"
  "DELETE FROM[^W]*$"
  "UPDATE.*SET.*WHERE 1=1"
  "ALTER TABLE.*DROP"
  "GRANT "
  "REVOKE "
)

upper_command=$(echo "$command" | tr '[:lower:]' '[:upper:]')

for pattern in "${dangerous_patterns[@]}"; do
  if echo "$upper_command" | grep -qE "$pattern"; then
    deny "Detected dangerous SQL pattern: $pattern. Run this directly in your database client."
  fi
done

# Block queries without WHERE clause on large tables
if echo "$upper_command" | grep -qE "^(SELECT|UPDATE|DELETE).*FROM.*(EVENTS|LOGS|CLICKS)" && \
   ! echo "$upper_command" | grep -q "WHERE"; then
  deny "Query on large table without WHERE clause. Add a date filter or LIMIT clause."
fi

# Warn about SELECT * on production tables
if echo "$upper_command" | grep -qE "SELECT \*.*FROM.*(PROD|RAW)" && \
   ! echo "$upper_command" | grep -q "LIMIT"; then
  warn "SELECT * on production/raw table without LIMIT. Consider adding LIMIT or selecting specific columns."
fi

exit 0
```

Make it executable:

```bash
chmod +x .claude/hooks/validate-sql.sh
```

### Use Case 2: Auto-Format SQL After Edits

Automatically format SQL files after Claude Code writes or edits them.

Create `.claude/hooks/auto-format-sql.sh`:

```bash
#!/bin/bash
# Auto-format SQL files after they are written or edited

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name')

# Only run after Write or Edit tools
if [ "$tool_name" != "Write" ] && [ "$tool_name" != "Edit" ]; then
  exit 0
fi

file_path=$(echo "$input" | jq -r '.tool_input.file_path')

# Only format SQL files
if [[ ! "$file_path" =~ \.(sql|SQL)$ ]]; then
  exit 0
fi

# Format with sqlfluff (if installed)
if command -v sqlfluff &> /dev/null; then
  sqlfluff fix "$file_path" --dialect bigquery --force 2>/dev/null
fi

exit 0
```

### Use Case 3: Data Freshness Check on Session Start

Check that your data sources are fresh when you start a Claude Code session.

Create `.claude/hooks/check-freshness.sh`:

```bash
#!/bin/bash
# Check data freshness at session start
# This runs as a Notification hook -- it prints warnings but does not block

input=$(cat)

# Check if this is a session start notification
# (We use a file flag to run only once per session)
flag_file="/tmp/claude_freshness_checked_$$"
if [ -f "$flag_file" ]; then
  exit 0
fi
touch "$flag_file"

echo "Checking data freshness..."

# Check dbt source freshness (if dbt is available)
if command -v dbt &> /dev/null && [ -f "dbt_project.yml" ]; then
  freshness_output=$(dbt source freshness 2>&1)
  stale_sources=$(echo "$freshness_output" | grep -c "ERROR")

  if [ "$stale_sources" -gt 0 ]; then
    echo "WARNING: $stale_sources data sources are stale."
    echo "Run 'dbt source freshness' for details."
  else
    echo "All data sources are fresh."
  fi
fi

exit 0
```

### Use Case 4: Notification When Long Analysis Completes

Get a system notification (or Slack message) when Claude Code finishes a long-running task.

Create `.claude/hooks/notify-complete.sh`:

```bash
#!/bin/bash
# Send a notification when Claude Code finishes a task

input=$(cat)

# On macOS, use osascript for a system notification
if [[ "$OSTYPE" == "darwin"* ]]; then
  osascript -e 'display notification "Claude Code has finished your analysis" with title "Analysis Complete"'
fi

# On Linux, use notify-send
if command -v notify-send &> /dev/null; then
  notify-send "Analysis Complete" "Claude Code has finished your analysis"
fi

# Optional: send to Slack via webhook
# SLACK_WEBHOOK="${SLACK_WEBHOOK_URL}"
# if [ -n "$SLACK_WEBHOOK" ]; then
#   curl -s -X POST "$SLACK_WEBHOOK" \
#     -H 'Content-type: application/json' \
#     -d '{"text":"Claude Code has finished the analysis."}'
# fi

exit 0
```

## Hook Configuration

Hooks are configured in `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-sql.sh"
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
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/auto-format-sql.sh"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/notify-complete.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/notify-complete.sh"
          }
        ]
      }
    ]
  }
}
```

### Matcher Syntax

The `matcher` field filters which tools trigger the hook:

| Matcher | Matches |
|---------|---------|
| `"Bash"` | Only Bash tool calls |
| `"Write\|Edit"` | Write or Edit tool calls |
| `""` | All tool calls (or all events for non-tool hooks) |
| `"mcp__postgres"` | Only MCP tools from the postgres server |

## Step-by-Step: Setting Up SQL Validation

This walks through the complete setup from scratch.

### 1. Create the hooks directory

```bash
mkdir -p .claude/hooks
```

### 2. Write the validation script

Save the SQL validation script from Use Case 1 above as `.claude/hooks/validate-sql.sh`.

### 3. Make it executable

```bash
chmod +x .claude/hooks/validate-sql.sh
```

### 4. Test the script manually

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"psql -c \"DROP TABLE users;\""}}' | bash .claude/hooks/validate-sql.sh
echo "Exit code: $?"
```

Expected output (JSON deny decision, exit code 0):

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Detected dangerous SQL pattern: DROP TABLE. Run this directly in your database client."
  }
}
Exit code: 0
```

Test a safe query:

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"psql -c \"SELECT * FROM users LIMIT 10;\""}}' | bash .claude/hooks/validate-sql.sh
echo "Exit code: $?"
```

Expected output (no stdout, exit code 0):

```
Exit code: 0
```

### 5. Configure in settings.json

Create or update `.claude/settings.json`:

```bash
mkdir -p .claude
```

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-sql.sh"
          }
        ]
      }
    ]
  }
}
```

### 6. Test in a Claude Code session

```bash
claude "Run this SQL: DROP TABLE users;"
```

Claude Code will attempt to run the command, the hook will block it, and Claude Code will see the block message and explain to you that the query was blocked for safety.

## Testing and Debugging Hooks

### Manual Testing

Always test hooks outside of Claude Code first:

```bash
# Pipe a sample payload to the hook
echo '{"tool_name":"Bash","tool_input":{"command":"SELECT * FROM events"}}' | bash .claude/hooks/validate-sql.sh
echo "Exit: $?"
```

### Logging

Add logging to your hooks for debugging:

```bash
#!/bin/bash
LOG_FILE=".claude/hooks/hook.log"

input=$(cat)
echo "$(date): Received: $input" >> "$LOG_FILE"

# ... hook logic ...

echo "$(date): Result: allowed" >> "$LOG_FILE"
exit 0
```

### Common Issues

| Problem | Cause | Fix |
|---------|-------|-----|
| Hook never fires | Matcher does not match the tool name | Check exact tool name spelling |
| Hook blocks everything | Exit code logic is wrong | Ensure safe queries return exit 0 |
| Hook is slow | Script does expensive operations | Cache results, use fast tools |
| JSON parsing fails | `jq` not installed | Install jq: `brew install jq` |
| Permission denied | Script not executable | Run `chmod +x .claude/hooks/your-hook.sh` |

### Performance

Hooks run synchronously. A slow hook blocks Claude Code. Keep hooks under 1 second. If you need to do something slow (like running dbt source freshness), do it asynchronously:

```bash
#!/bin/bash
# Run the slow check in the background
nohup bash .claude/hooks/slow-check.sh &>/dev/null &
exit 0
```
