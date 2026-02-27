# Contributor Guide

The root CLAUDE.md is the product -- the analytics configuration users copy to their projects. This file is for working on the repo itself.

## Architecture

- `CLAUDE.md` -- THE PRODUCT. What users copy. Make it better, not bigger.
- `.claude/skills/` -- Skills. YAML frontmatter: `name`, `description`.
- `.claude/agents/` -- Agents. YAML frontmatter: `name`, `description`, `model`, `tools`.
- `.claude/rules/` -- Rules. YAML frontmatter: `description`, `globs`.
- `.claude/hooks/` -- Bash scripts, JSON from stdin, exit code 2 to block.
- `demo/` -- DuckDB demo. Zero external deps beyond duckdb.
- `challenges/` -- Analytics challenges.

## Quality Bar

- Skills MUST handle nulls, empty datasets, division by zero.
- Agents MUST be self-contained -- they get a task and execute it completely in their own context.
- SQL uses CTEs, trailing commas, snake_case, inclusive-start/exclusive-end dates.
- NEVER fabricate data or results. NEVER hardcode paths or credentials.

## Philosophy

Users should NEVER have to write CLAUDE.md by hand. They paste their top 5 queries and Claude learns everything. The CLAUDE.md instructs Claude to auto-delegate to agents, auto-review with analytics-reviewer, and never hallucinate. Every change must serve this philosophy.
