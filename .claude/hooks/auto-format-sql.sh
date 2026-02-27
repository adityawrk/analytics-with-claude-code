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
# Output (PostToolUse protocol):
#   - This hook never blocks. It exits 0 with no JSON output on success.
#   - Formatting is a side effect; results appear in verbose mode only.
#
# Dependencies: sqlfluff (optional -- skips gracefully if not installed)
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Check dependencies
# -----------------------------------------------------------------------------
if ! command -v jq &> /dev/null; then
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
    exit 0
fi

# -----------------------------------------------------------------------------
# Only format SQL files
# -----------------------------------------------------------------------------
if [[ "$FILE_PATH" != *.sql ]]; then
    exit 0
fi

# Verify the file actually exists.
if [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

# -----------------------------------------------------------------------------
# Check if sqlfluff is installed
# -----------------------------------------------------------------------------
if ! command -v sqlfluff &> /dev/null; then
    exit 0
fi

# -----------------------------------------------------------------------------
# Run sqlfluff fix
# -----------------------------------------------------------------------------
# Capture output and exit code. We never block the workflow, even on failure.
TMPFILE="$(mktemp)"
trap 'rm -f "$TMPFILE"' EXIT

sqlfluff fix "$FILE_PATH" --force --no-color >"$TMPFILE" 2>&1 || true

exit 0
