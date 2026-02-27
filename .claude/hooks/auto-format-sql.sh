#!/usr/bin/env bash
# =============================================================================
# auto-format-sql.sh - SQL Auto-Format Hook for Claude Code
# =============================================================================
# This hook runs as a PostToolUse hook after file edits. If the edited file
# is a SQL file, it runs sqlfluff fix to auto-format it.
#
# Input: Reads a JSON object from stdin (Claude Code hook protocol).
#        The JSON contains tool_name and tool_input fields.
#
# Output: Prints a JSON object to stdout with:
#   - "decision": "approve" (always -- this hook never blocks)
#   - "reason": description of what was done (optional)
#
# Dependencies: sqlfluff (optional -- skips gracefully if not installed)
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Check dependencies
# -----------------------------------------------------------------------------
if ! command -v jq &> /dev/null; then
    echo '{"decision": "approve", "reason": "jq not installed; skipping SQL formatting"}'
    exit 0
fi

# -----------------------------------------------------------------------------
# Read hook input from stdin
# -----------------------------------------------------------------------------
INPUT="$(cat)"

TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty')"
TOOL_INPUT="$(echo "$INPUT" | jq -r '.tool_input // empty')"

# -----------------------------------------------------------------------------
# Only run after file-editing tools
# -----------------------------------------------------------------------------
case "$TOOL_NAME" in
    Edit|Write|edit_file|write_file|create_file)
        ;;
    *)
        # Not a file-editing tool; nothing to format.
        echo '{"decision": "approve"}'
        exit 0
        ;;
esac

# -----------------------------------------------------------------------------
# Extract the file path from the tool input
# -----------------------------------------------------------------------------
FILE_PATH=""

if echo "$TOOL_INPUT" | jq -e '.file_path' &> /dev/null 2>&1; then
    FILE_PATH="$(echo "$TOOL_INPUT" | jq -r '.file_path // empty')"
elif echo "$TOOL_INPUT" | jq -e '.path' &> /dev/null 2>&1; then
    FILE_PATH="$(echo "$TOOL_INPUT" | jq -r '.path // empty')"
fi

# If we could not determine the file path, skip.
if [ -z "$FILE_PATH" ]; then
    echo '{"decision": "approve"}'
    exit 0
fi

# -----------------------------------------------------------------------------
# Only format SQL files
# -----------------------------------------------------------------------------
if [[ "$FILE_PATH" != *.sql ]]; then
    echo '{"decision": "approve"}'
    exit 0
fi

# Verify the file actually exists.
if [ ! -f "$FILE_PATH" ]; then
    echo '{"decision": "approve", "reason": "File not found: '"$FILE_PATH"'; skipping formatting"}'
    exit 0
fi

# -----------------------------------------------------------------------------
# Check if sqlfluff is installed
# -----------------------------------------------------------------------------
if ! command -v sqlfluff &> /dev/null; then
    REASON="sqlfluff is not installed; skipping auto-format for ${FILE_PATH}. "
    REASON+="Install with: pip install sqlfluff"

    echo "{\"decision\": \"approve\", \"reason\": $(echo "$REASON" | jq -Rs '.')}"
    exit 0
fi

# -----------------------------------------------------------------------------
# Run sqlfluff fix
# -----------------------------------------------------------------------------
# Capture output and exit code. We never block the workflow, even on failure.
SQLFLUFF_OUTPUT=""
SQLFLUFF_EXIT=0

# Use a temp file to capture stderr as well.
TMPFILE="$(mktemp)"
trap 'rm -f "$TMPFILE"' EXIT

SQLFLUFF_OUTPUT="$(sqlfluff fix "$FILE_PATH" --force --no-color 2>"$TMPFILE")" || SQLFLUFF_EXIT=$?
SQLFLUFF_STDERR="$(cat "$TMPFILE")"

# -----------------------------------------------------------------------------
# Report results
# -----------------------------------------------------------------------------
if [ "$SQLFLUFF_EXIT" -eq 0 ]; then
    # Check if any fixes were applied by looking at the output.
    if echo "$SQLFLUFF_OUTPUT" | grep -qi "fix"; then
        REASON="sqlfluff formatted ${FILE_PATH}. ${SQLFLUFF_OUTPUT}"
    else
        REASON="No formatting changes needed for ${FILE_PATH}."
    fi
elif [ "$SQLFLUFF_EXIT" -eq 1 ]; then
    # Exit code 1 from sqlfluff typically means fixes were applied but
    # some violations remain (unfixable). This is still a success for us.
    REASON="sqlfluff applied partial fixes to ${FILE_PATH}. Some violations may remain. ${SQLFLUFF_OUTPUT}"
else
    # sqlfluff encountered an error. Log it but do not block.
    REASON="sqlfluff encountered an error on ${FILE_PATH} (exit code ${SQLFLUFF_EXIT}). "
    REASON+="This does not block your workflow. Error: ${SQLFLUFF_STDERR}"
fi

echo "{\"decision\": \"approve\", \"reason\": $(echo "$REASON" | jq -Rs '.')}"
exit 0
