#!/usr/bin/env bash
# =============================================================================
# validate-sql.sh - SQL Validation Hook for Claude Code
# =============================================================================
# This hook runs as a PreToolUse hook to intercept SQL queries before they are
# executed. It blocks destructive statements, warns on risky patterns, and
# enforces safety guardrails for analytics workflows.
#
# Input: Reads a JSON object from stdin (Claude Code hook protocol).
#        The JSON contains tool_name and tool_input fields.
#
# Output: Prints a JSON object to stdout with:
#   - "decision": "block" | "approve" | "warn"
#   - "reason": explanation string (for block/warn)
#
# Dependencies: jq (for JSON parsing)
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Check dependencies
# -----------------------------------------------------------------------------
if ! command -v jq &> /dev/null; then
    # If jq is not installed, approve by default rather than blocking all work.
    echo '{"decision": "approve", "reason": "jq not installed; skipping SQL validation"}'
    exit 0
fi

# -----------------------------------------------------------------------------
# Read hook input from stdin
# -----------------------------------------------------------------------------
INPUT="$(cat)"

# Extract the tool name and input content from the hook payload.
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty')"
TOOL_INPUT="$(echo "$INPUT" | jq -r '.tool_input // empty')"

# -----------------------------------------------------------------------------
# Only validate relevant tools
# -----------------------------------------------------------------------------
# This hook should only fire for tools that execute or write SQL.
# Adjust these tool names to match your Claude Code configuration.
case "$TOOL_NAME" in
    Bash|execute_sql|run_query|sql_query)
        ;;
    *)
        # Not a SQL-related tool; approve and exit.
        echo '{"decision": "approve"}'
        exit 0
        ;;
esac

# -----------------------------------------------------------------------------
# Extract SQL content
# -----------------------------------------------------------------------------
# Try to get SQL from common field names in the tool input.
SQL=""

if echo "$TOOL_INPUT" | jq -e '.query' &> /dev/null 2>&1; then
    SQL="$(echo "$TOOL_INPUT" | jq -r '.query // empty')"
elif echo "$TOOL_INPUT" | jq -e '.sql' &> /dev/null 2>&1; then
    SQL="$(echo "$TOOL_INPUT" | jq -r '.sql // empty')"
elif echo "$TOOL_INPUT" | jq -e '.command' &> /dev/null 2>&1; then
    SQL="$(echo "$TOOL_INPUT" | jq -r '.command // empty')"
fi

# For the Bash tool, check if the command contains SQL-like content.
if [ -z "$SQL" ] && [ "$TOOL_NAME" = "Bash" ]; then
    COMMAND="$(echo "$TOOL_INPUT" | jq -r '.command // empty')"
    # Only analyze if it looks like it might contain SQL
    if echo "$COMMAND" | grep -qiE '(psql|mysql|bq |bigquery|snowsql|dbt run|sqlite3|clickhouse)'; then
        SQL="$COMMAND"
    else
        # Not a SQL command; approve.
        echo '{"decision": "approve"}'
        exit 0
    fi
fi

# If we still have no SQL to validate, approve.
if [ -z "$SQL" ]; then
    echo '{"decision": "approve"}'
    exit 0
fi

# -----------------------------------------------------------------------------
# Normalize SQL for pattern matching
# -----------------------------------------------------------------------------
# Convert to uppercase for case-insensitive matching. Strip extra whitespace.
SQL_UPPER="$(echo "$SQL" | tr '[:lower:]' '[:upper:]' | tr -s '[:space:]' ' ')"

# -----------------------------------------------------------------------------
# BLOCK: Destructive statements targeting production
# -----------------------------------------------------------------------------
# These statements are blocked unless they explicitly reference dev or staging
# schemas/databases.

DESTRUCTIVE_PATTERNS=(
    "INSERT INTO"
    "UPDATE .* SET"
    "DELETE FROM"
    "DROP TABLE"
    "DROP VIEW"
    "DROP SCHEMA"
    "DROP DATABASE"
    "TRUNCATE"
    "ALTER TABLE .* DROP"
    "ALTER TABLE .* RENAME"
    "CREATE OR REPLACE TABLE"
    "MERGE INTO"
)

# Patterns that indicate dev/staging (safe targets)
SAFE_TARGET_PATTERN="(DEV[_.]|STAGING[_.]|SANDBOX[_.]|_DEV |_STAGING |_SCRATCH[_.]|DBT_|TEMP[_.]|TMP[_.])"

for PATTERN in "${DESTRUCTIVE_PATTERNS[@]}"; do
    if echo "$SQL_UPPER" | grep -qE "$PATTERN"; then
        # Check if the target is a dev/staging environment
        if echo "$SQL_UPPER" | grep -qE "$SAFE_TARGET_PATTERN"; then
            # Targeting dev/staging is allowed; continue checking other rules.
            continue
        fi

        # Extract the specific statement for a clear error message.
        MATCHED_STMT="$(echo "$PATTERN" | sed 's/\.\*/.../' | tr '[:upper:]' '[:lower:]')"

        REASON="Blocked destructive SQL statement: '${MATCHED_STMT}'. "
        REASON+="This query modifies or deletes data and does not appear to target a "
        REASON+="dev/staging/sandbox environment. If this is intentional, rewrite the "
        REASON+="query to explicitly reference a dev or staging schema."

        echo "{\"decision\": \"block\", \"reason\": $(echo "$REASON" | jq -Rs '.')}"
        exit 0
    fi
done

# -----------------------------------------------------------------------------
# BLOCK: Queries referencing production write endpoints
# -----------------------------------------------------------------------------
# Block queries that reference known production write endpoints or admin schemas.
PROD_WRITE_PATTERNS=(
    "PROD\.WRITE"
    "PRODUCTION\.ADMIN"
    "PROD_MASTER"
    "REPLICA_WRITE"
)

for PATTERN in "${PROD_WRITE_PATTERNS[@]}"; do
    if echo "$SQL_UPPER" | grep -qE "$PATTERN"; then
        REASON="Blocked: query references a production write endpoint (matched pattern: '${PATTERN}'). "
        REASON+="Analytics queries should only read from read replicas or warehouse tables."

        echo "{\"decision\": \"block\", \"reason\": $(echo "$REASON" | jq -Rs '.')}"
        exit 0
    fi
done

# -----------------------------------------------------------------------------
# WARN: SELECT * from potentially large tables
# -----------------------------------------------------------------------------
# Warn when using SELECT * without a LIMIT clause, as this can be expensive.
if echo "$SQL_UPPER" | grep -qE "SELECT \*" && \
   ! echo "$SQL_UPPER" | grep -qE "LIMIT [0-9]"; then
    # Allow SELECT * inside CTEs (common in dbt staging models).
    # Only warn if it looks like a standalone query.
    if ! echo "$SQL_UPPER" | grep -qE "^WITH "; then
        REASON="Warning: SELECT * detected without a LIMIT clause. "
        REASON+="This may scan a large amount of data. Consider selecting only "
        REASON+="the columns you need, or add a LIMIT for exploratory queries."

        echo "{\"decision\": \"warn\", \"reason\": $(echo "$REASON" | jq -Rs '.')}"
        exit 0
    fi
fi

# -----------------------------------------------------------------------------
# WARN: Missing WHERE clause on large tables
# -----------------------------------------------------------------------------
# Warn on SELECT/DELETE/UPDATE without WHERE, but not for CTE-based queries.
if echo "$SQL_UPPER" | grep -qE "(SELECT .* FROM|DELETE FROM|UPDATE )" && \
   ! echo "$SQL_UPPER" | grep -qE "WHERE " && \
   ! echo "$SQL_UPPER" | grep -qE "^WITH "; then
    # Exclude simple metadata queries (SHOW, DESCRIBE, INFORMATION_SCHEMA).
    if ! echo "$SQL_UPPER" | grep -qE "(SHOW |DESCRIBE |INFORMATION_SCHEMA|EXPLAIN )"; then
        REASON="Warning: query has no WHERE clause. This will scan the entire table. "
        REASON+="If this is intentional (e.g., full table aggregation), this is fine. "
        REASON+="Otherwise, consider adding filters to reduce data scanned."

        echo "{\"decision\": \"warn\", \"reason\": $(echo "$REASON" | jq -Rs '.')}"
        exit 0
    fi
fi

# -----------------------------------------------------------------------------
# APPROVE: Query passed all checks
# -----------------------------------------------------------------------------
echo '{"decision": "approve"}'
exit 0
