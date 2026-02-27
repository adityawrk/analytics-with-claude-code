#!/usr/bin/env bash
# ============================================================================
# Analytics with Claude Code — Setup Wizard
#
# Configures Claude Code for any analytics project. Run with:
#   bash setup.sh
# ============================================================================

set -euo pipefail


# ---------------------------------------------------------------------------
# Colors and symbols
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # no color

check="${GREEN}[ok]${NC}"
arrow="${BLUE}==>${NC}"
warn="${YELLOW}[!]${NC}"
fail="${RED}[x]${NC}"

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
print_header() {
    echo ""
    echo -e "${BOLD}${CYAN}============================================${NC}"
    echo -e "${BOLD}${CYAN}  Analytics with Claude Code — Setup Wizard ${NC}"
    echo -e "${BOLD}${CYAN}============================================${NC}"
    echo ""
}

prompt_choice() {
    local prompt="$1"
    shift
    local options=("$@")
    echo -e "\n${arrow} ${BOLD}${prompt}${NC}"
    for i in "${!options[@]}"; do
        echo -e "   ${BOLD}$((i+1)))${NC} ${options[$i]}"
    done
    while true; do
        read -rp "   Enter choice [1-${#options[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
            REPLY=$choice
            return
        fi
        echo -e "   ${warn} Please enter a number between 1 and ${#options[@]}"
    done
}

# ---------------------------------------------------------------------------
# Step 1: Check prerequisites
# ---------------------------------------------------------------------------
print_header

echo -e "${arrow} ${BOLD}Checking prerequisites...${NC}"

if command -v claude &>/dev/null; then
    echo -e "   ${check} Claude Code CLI found"
else
    echo -e "   ${fail} Claude Code CLI not found"
    echo -e "   ${warn} Install it first: ${BOLD}npm install -g @anthropic-ai/claude-code${NC}"
    echo -e "   ${warn} Continuing anyway — you can install it later."
fi

if command -v git &>/dev/null; then
    echo -e "   ${check} git found"
else
    echo -e "   ${fail} git not found — some features may not work"
fi

if command -v python3 &>/dev/null; then
    echo -e "   ${check} python3 found"
elif command -v python &>/dev/null; then
    echo -e "   ${check} python found"
else
    echo -e "   ${warn} python not found — needed for the demo dataset"
fi

# ---------------------------------------------------------------------------
# Step 2: Choose data stack
# ---------------------------------------------------------------------------
prompt_choice "What is your primary data stack?" \
    "PostgreSQL" \
    "Snowflake" \
    "BigQuery" \
    "DuckDB" \
    "CSV / Parquet files"
STACK_CHOICE=$REPLY
STACK_NAMES=("postgres" "snowflake" "bigquery" "duckdb" "csv")
STACK="${STACK_NAMES[$((STACK_CHOICE-1))]}"
echo -e "   ${check} Selected: ${BOLD}${STACK}${NC}"

# ---------------------------------------------------------------------------
# Step 3: Choose role
# ---------------------------------------------------------------------------
prompt_choice "What best describes your role?" \
    "Data Analyst" \
    "Analytics Engineer" \
    "Data Scientist"
ROLE_CHOICE=$REPLY
ROLE_NAMES=("analyst" "engineer" "scientist")
ROLE="${ROLE_NAMES[$((ROLE_CHOICE-1))]}"
echo -e "   ${check} Selected: ${BOLD}${ROLE}${NC}"

# ---------------------------------------------------------------------------
# Step 4: Choose target directory
# ---------------------------------------------------------------------------
prompt_choice "Where should we set up Claude Code?" \
    "Current directory ($(pwd))" \
    "Specify a path"
if [[ $REPLY -eq 2 ]]; then
    read -rp "   Enter the full path: " TARGET_DIR
    TARGET_DIR="${TARGET_DIR/#\~/$HOME}"
else
    TARGET_DIR="$(pwd)"
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    echo -e "   ${warn} Directory does not exist. Creating ${TARGET_DIR}..."
    mkdir -p "$TARGET_DIR"
fi

echo -e "   ${check} Target: ${BOLD}${TARGET_DIR}${NC}"

# ---------------------------------------------------------------------------
# Step 5: Check for existing .claude/ directory
# ---------------------------------------------------------------------------
CLAUDE_DIR="${TARGET_DIR}/.claude"
if [[ -d "$CLAUDE_DIR" ]]; then
    echo -e "\n   ${warn} A ${BOLD}.claude/${NC} directory already exists at ${TARGET_DIR}"
    read -rp "   Overwrite it? [y/N]: " overwrite
    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
        echo -e "   Aborting. Your existing configuration is untouched."
        exit 0
    fi
    rm -rf "$CLAUDE_DIR"
fi

# ---------------------------------------------------------------------------
# Step 6: Create directory structure
# ---------------------------------------------------------------------------
echo -e "\n${arrow} ${BOLD}Creating .claude/ directory structure...${NC}"

mkdir -p "${CLAUDE_DIR}/skills"
mkdir -p "${CLAUDE_DIR}/rules"
mkdir -p "${CLAUDE_DIR}/hooks"
mkdir -p "${CLAUDE_DIR}/agents"
echo -e "   ${check} Created .claude/{skills,rules,hooks,agents}"

# ---------------------------------------------------------------------------
# Step 7: Copy skills based on role
# ---------------------------------------------------------------------------
echo -e "\n${arrow} ${BOLD}Installing skills for ${ROLE}...${NC}"

SKILLS_SRC="${REPO_DIR}/.claude/skills"
if [[ -d "$SKILLS_SRC" ]]; then
    # Everyone gets core skills
    for skill in eda data-quality explain-sql systematic-debug; do
        if [[ -d "${SKILLS_SRC}/${skill}" ]]; then
            mkdir -p "${CLAUDE_DIR}/skills/${skill}"
            cp "${SKILLS_SRC}/${skill}/SKILL.md" "${CLAUDE_DIR}/skills/${skill}/"
            echo -e "   ${check} ${skill}"
        fi
    done

    # Role-specific skills
    if [[ "$ROLE" == "engineer" ]]; then
        for skill in sql-optimizer metric-reconciler weekly-report; do
            if [[ -d "${SKILLS_SRC}/${skill}" ]]; then
                mkdir -p "${CLAUDE_DIR}/skills/${skill}"
                cp "${SKILLS_SRC}/${skill}/SKILL.md" "${CLAUDE_DIR}/skills/${skill}/"
                echo -e "   ${check} ${skill}"
            fi
        done
    fi

    if [[ "$ROLE" == "scientist" ]]; then
        for skill in ab-test metric-calculator report-generator; do
            if [[ -d "${SKILLS_SRC}/${skill}" ]]; then
                mkdir -p "${CLAUDE_DIR}/skills/${skill}"
                cp "${SKILLS_SRC}/${skill}/SKILL.md" "${CLAUDE_DIR}/skills/${skill}/"
                echo -e "   ${check} ${skill}"
            fi
        done
    fi
else
    echo -e "   ${warn} Skills source not found at ${SKILLS_SRC}"
fi

# ---------------------------------------------------------------------------
# Step 8: Copy MCP config template
# ---------------------------------------------------------------------------
echo -e "\n${arrow} ${BOLD}Setting up MCP configuration for ${STACK}...${NC}"

MCP_SRC="${REPO_DIR}/templates/mcp"
if [[ -f "${MCP_SRC}/${STACK}.json" ]]; then
    cp "${MCP_SRC}/${STACK}.json" "${CLAUDE_DIR}/mcp.json"
    echo -e "   ${check} Copied ${STACK}.json to .claude/mcp.json"
elif [[ -f "${MCP_SRC}/mcp-config.json" ]]; then
    cp "${MCP_SRC}/mcp-config.json" "${CLAUDE_DIR}/mcp.json"
    echo -e "   ${check} Copied default MCP config (edit for your ${STACK} credentials)"
else
    echo -e "   ${warn} No MCP template found for ${STACK}"
    echo -e "   ${warn} You can configure MCP manually later — see guides/mcp-setup.md"
fi

# ---------------------------------------------------------------------------
# Step 9: Copy CLAUDE.md (the product)
# ---------------------------------------------------------------------------
echo -e "\n${arrow} ${BOLD}Copying CLAUDE.md...${NC}"

CLAUDE_MD="${TARGET_DIR}/CLAUDE.md"
cp "${REPO_DIR}/CLAUDE.md" "$CLAUDE_MD"

echo -e "   ${check} Copied CLAUDE.md to ${CLAUDE_MD}"
echo -e "   ${arrow} Open Claude Code, paste your top 5 queries, and Claude learns your data model."

# ---------------------------------------------------------------------------
# Step 10: Copy rules
# ---------------------------------------------------------------------------
echo -e "\n${arrow} ${BOLD}Installing rules...${NC}"

# Copy all agents (they're essential for the orchestration model)
AGENTS_SRC="${REPO_DIR}/.claude/agents"
if [[ -d "$AGENTS_SRC" ]]; then
    for agent_file in "${AGENTS_SRC}"/*.md; do
        if [[ -f "$agent_file" ]]; then
            cp "$agent_file" "${CLAUDE_DIR}/agents/"
            echo -e "   ${check} $(basename "$agent_file" .md)"
        fi
    done
fi

# Copy rules
RULES_SRC="${REPO_DIR}/.claude/rules"
if [[ -d "$RULES_SRC" ]]; then
    for rule in sql-conventions data-privacy; do
        if [[ -f "${RULES_SRC}/${rule}.md" ]]; then
            cp "${RULES_SRC}/${rule}.md" "${CLAUDE_DIR}/rules/"
            echo -e "   ${check} ${rule}"
        fi
    done

    if [[ "$ROLE" == "engineer" ]]; then
        if [[ -f "${RULES_SRC}/metric-definitions.md" ]]; then
            cp "${RULES_SRC}/metric-definitions.md" "${CLAUDE_DIR}/rules/"
            echo -e "   ${check} metric-definitions"
        fi
    fi
else
    echo -e "   ${warn} Rules source not found at ${RULES_SRC}"
fi

# ---------------------------------------------------------------------------
# Step 11: Copy hooks and settings
# ---------------------------------------------------------------------------
echo -e "\n${arrow} ${BOLD}Configuring hooks and settings...${NC}"

HOOKS_SRC="${REPO_DIR}/.claude/hooks"
if [[ -d "$HOOKS_SRC" ]]; then
    for hook_file in "${HOOKS_SRC}"/*.sh; do
        if [[ -f "$hook_file" ]]; then
            cp "$hook_file" "${CLAUDE_DIR}/hooks/"
            chmod +x "${CLAUDE_DIR}/hooks/$(basename "$hook_file")"
            echo -e "   ${check} $(basename "$hook_file")"
        fi
    done
fi

SETTINGS_SRC="${REPO_DIR}/templates/settings.json.template"
if [[ -f "$SETTINGS_SRC" ]]; then
    cp "$SETTINGS_SRC" "${CLAUDE_DIR}/settings.json"
    echo -e "   ${check} settings.json"
else
    cp "${REPO_DIR}/.claude/settings.json" "${CLAUDE_DIR}/settings.json" 2>/dev/null || true
    echo -e "   ${check} settings.json"
fi

# ---------------------------------------------------------------------------
# Done!
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}${GREEN}============================================${NC}"
echo -e "${BOLD}${GREEN}  Setup complete!${NC}"
echo -e "${BOLD}${GREEN}============================================${NC}"
echo ""
echo -e "  ${BOLD}What was created:${NC}"
echo -e "    ${TARGET_DIR}/CLAUDE.md"
echo -e "    ${TARGET_DIR}/.claude/skills/"
echo -e "    ${TARGET_DIR}/.claude/rules/"
echo -e "    ${TARGET_DIR}/.claude/hooks/"
echo -e "    ${TARGET_DIR}/.claude/mcp.json"
echo -e "    ${TARGET_DIR}/.claude/settings.json"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo ""
echo -e "    ${CYAN}cd ${TARGET_DIR}${NC}"
echo -e "    ${CYAN}claude${NC}"
echo ""

# Suggest a first command based on stack
case "$STACK" in
    duckdb|csv)
        echo -e "  ${BOLD}Try this first:${NC}"
        echo -e "    ${CYAN}/eda${NC}  — Run exploratory data analysis on your files"
        ;;
    postgres|snowflake|bigquery)
        echo -e "  ${BOLD}Try this first:${NC}"
        echo -e "    ${CYAN}List all tables in the database${NC}"
        echo ""
        echo -e "  ${warn} Make sure your database credentials are configured in"
        echo -e "     ${TARGET_DIR}/.claude/mcp.json"
        ;;
esac

echo ""
echo -e "  For the interactive demo with sample data, run:"
echo -e "    ${CYAN}cd ${REPO_DIR}/demo && pip install duckdb && python setup_demo_data.py${NC}"
echo ""
