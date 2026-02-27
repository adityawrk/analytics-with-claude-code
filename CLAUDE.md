# Analytics with Claude Code

This is a public educational repository teaching analytics practitioners how to use Claude Code effectively.

## Project Structure
- `guides/` - Markdown conceptual guides (no executable code)
- `.claude/skills/` - Reusable Claude Code skills for analytics tasks
- `.claude/agents/` - Custom subagent definitions for analytics workflows
- `.claude/rules/` - Modular rules (SQL conventions, data privacy, metrics)
- `.claude/hooks/` - Hook scripts (SQL validation, auto-formatting)
- `examples/` - Complete working examples with sample data
- `templates/` - Copy-paste starter templates for analytics projects

## Conventions
- All skills use YAML frontmatter with name, description, and allowed-tools
- Agent definitions use standard Claude Code subagent frontmatter
- Guides are numbered (01-, 02-) to suggest reading order
- Example directories are self-contained with their own README and data
- Use snake_case for file names, kebab-case for directory names

## Writing Style
- Write for analytics practitioners (data analysts, analytics engineers, data scientists)
- Assume familiarity with SQL, Python, and basic statistics
- Assume NO prior familiarity with Claude Code
- Every guide should be actionable - include copy-paste examples
- Skills and agents should be production-ready, not toy examples
