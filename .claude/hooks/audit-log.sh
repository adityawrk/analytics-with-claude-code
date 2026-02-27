#!/usr/bin/env bash
# audit-log.sh — PostToolUse hook for analytics query audit trail
#
# Logs every SQL query Claude runs to .analytics/audit_log.md.
# Reads PostToolUse JSON from stdin. Never blocks — always exits 0.

set -euo pipefail

AUDIT_DIR=".analytics"
AUDIT_FILE="${AUDIT_DIR}/audit_log.md"

# Safety: this is a logging hook, never block the user.
trap 'exit 0' ERR

# 1. Read the PostToolUse JSON from stdin
INPUT="$(cat)"
if [ -z "$INPUT" ]; then exit 0; fi

# 2. Check if jq is available; if not, exit silently.
if ! command -v jq &>/dev/null; then exit 0; fi

# 3. Extract tool name and command — only process Bash invocations
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)" || exit 0
if [ "$TOOL_NAME" != "Bash" ]; then exit 0; fi

COMMAND="$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)" || exit 0
if [ -z "$COMMAND" ]; then exit 0; fi

# 4. Detect SQL client invocations in the command
SQL_PATTERN='(psql|duckdb|sqlite3|bq[[:space:]]+query|snowsql|mysql|clickhouse-client|trino|presto|usql)'
if ! echo "$COMMAND" | grep -qE "$SQL_PATTERN"; then exit 0; fi

SQL_CLIENT="$(echo "$COMMAND" | grep -oE "$SQL_PATTERN" | head -n1)" || SQL_CLIENT="unknown"

# 5. Extract the SQL query text
QUERY=""

# Try: -c 'query' or -e 'query' or --query 'query'
QUERY="$(echo "$COMMAND" | sed -n "s/.*\(-c\|-e\|--query\)[[:space:]]*[\"']\(.*\)[\"'].*/\2/p" | head -n1)" || true

# Try: heredoc (<<EOF ... EOF)
if [ -z "$QUERY" ]; then
    QUERY="$(echo "$COMMAND" | sed -n '/<<.*EOF/,/EOF/p' | grep -v 'EOF' | head -20)" || true
fi

# Try: piped input (echo "SELECT ..." | psql)
if [ -z "$QUERY" ]; then
    QUERY="$(echo "$COMMAND" | sed -n "s/.*echo[[:space:]]*[\"']\(.*\)[\"'][[:space:]]*|.*/\1/p" | head -n1)" || true
fi

# Last resort: log the full command
if [ -z "$QUERY" ]; then
    QUERY="$COMMAND"
fi

# 6. Write the audit log entry
mkdir -p "$AUDIT_DIR"

if [ ! -f "$AUDIT_FILE" ]; then
    cat > "$AUDIT_FILE" <<'HEADER'
# Analytics Audit Log

All SQL queries executed by Claude are recorded here automatically.
Each entry includes a timestamp, the SQL client used, and the query text.

---

HEADER
fi

TIMESTAMP="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

cat >> "$AUDIT_FILE" <<ENTRY
### ${TIMESTAMP}

- **Client:** \`${SQL_CLIENT}\`

\`\`\`sql
${QUERY}
\`\`\`

---

ENTRY

exit 0
